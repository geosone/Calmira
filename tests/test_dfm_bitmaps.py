"""Original embedded glyph provenance, typed resource emission and safe CLI."""
import copy
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

from tools.bitmap_resources import parse as parse_resources
from tools.compile_dfm import Compiler, Component, DfmError, Value, compile_bundle, parse
from tools.dfm_bitmaps import BitmapResources, bitmap_payload, cancellation_glyph

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / 'src/askdrop.dfm'


class DfmBitmapTests(unittest.TestCase):
    def setUp(self):
        self.data = ORIGINAL.read_bytes()
        self.root = parse(self.data)
        self.button = self.root.children[2]
        self.stream = self.button.properties['glyph.data'].data

    def emit(self):
        return Compiler(self.root).compile('fixture')

    def test_original_select_padding_is_removed_without_altering_pixels(self):
        data = (ROOT / 'src/select.dfm').read_bytes()
        root = parse(data)
        node = next(n for n in root.children if n.name == 'DeselectBtn')
        stream = node.properties['glyph.data'].data
        bitmap = stream[4:]
        self.assertEqual(bitmap[-26:], bytes(26))
        payload = bitmap_payload(stream)
        self.assertEqual(payload, bitmap[14:-26])
        source, resources = compile_bundle(data)
        self.assertIn('Label1.FocusControl := Edit;', source)
        self.assertIn(payload, [r[3] for r in parse_resources(resources)])

    def test_only_bounded_declared_zero_padding_is_accepted(self):
        bitmap = self.stream[4:]
        def wrapped(tail, declared_delta=0):
            modified = bytearray(bitmap + tail)
            struct.pack_into('<I', modified, 2, len(modified) + declared_delta)
            return struct.pack('<I', len(modified)) + modified
        for count in (1, 26, 64):
            self.assertEqual(bitmap_payload(wrapped(bytes(count))), bitmap_payload(self.stream))
        for stream in (wrapped(bytes(65)), wrapped(b'\1'), wrapped(bytes(26), -1)):
            with self.assertRaises(ValueError):
                bitmap_payload(stream)

    def test_original_glyphs_are_preserved_as_native_bitmap_resources(self):
        source, resources = compile_bundle(self.data)
        records = parse_resources(resources)
        self.assertEqual(len(records), 3)
        payloads = {row[3] for row in records}
        self.assertIn(bitmap_payload(self.stream), payloads)
        self.assertIn(bitmap_payload(self.root.children[3].properties['glyph.data'].data), payloads)
        for kind, name, flags, payload, _ in records:
            self.assertEqual(kind, 2)
            self.assertEqual(flags, 0x1030)
            self.assertIn(name, source)
            self.assertLess(len(payload), 65536)
        self.assertNotIn('array[0..', source)

    def test_resource_deduplication_and_deterministic_order(self):
        first, second = BitmapResources(), BitmapResources()
        a, b = bitmap_payload(self.stream), cancellation_glyph()
        self.assertEqual(first.add(a), first.add(a))
        first.add(b); second.add(b); second.add(a)
        self.assertEqual(first.encode(), second.encode())
        self.assertEqual(compile_bundle(self.data), compile_bundle(self.data))

    def test_owned_cancellation_glyph_has_normal_and_disabled_frames(self):
        data = cancellation_glyph()
        header, width, height, planes, bits = struct.unpack_from('<IiiHH', data)
        self.assertEqual((header, width, height, planes, bits), (40, 32, 16, 1, 4))
        self.assertEqual(len(data), 40 + 64 + 16 * 16)
        self.assertEqual(data[40:44], b'\xff\xff\xff\0')
        source = self.emit()
        self.assertIn('BitBtn3.Cancel := True; BitBtn3.ModalResult := mrCancel;', source)
        self.assertIn('BitBtn3.NumGlyphs := 2;', source)
        self.assertIn("FormText('TStandardButtons', 'Cancel', 'Caption', 'Cancel')", source)

    def test_explicit_cancel_caption_wins_over_standard_caption(self):
        self.root.children[4].properties['caption'] = Value('string', '&Stop')
        output = self.emit()
        self.assertIn("'Caption', '&Stop'", output)
        self.assertNotIn('TStandardButtons', output)

    def test_empty_bitmap_streams_clear_owned_containers(self):
        for stream in (b'', b'\0\0\0\0'):
            self.button.properties['glyph.data'] = Value('binary', stream)
            self.assertIn('BitBtn1.Glyph := nil;', self.emit())
        image = self.root.children[1]
        image.properties['picture.data'] = Value('binary', b'\0')
        self.assertIn('Icon.Picture.Graphic := nil;', self.emit())

    def test_bitmap_picture_is_loaded_before_autosizing_without_a_canvas_side_effect(self):
        image = self.root.children[1]
        image.properties['picture.data'] = Value('binary', b'\7TBitmap' + self.stream)
        image.properties['autosize'] = Value('boolean', True)
        output = self.emit()
        self.assertLess(output.index('Icon.Picture.Bitmap.LoadFromResourceName'), output.index('Icon.AutoSize := True'))
        self.assertNotIn('Icon.Font', output)
        self.assertNotIn('Icon.Canvas', output)

    def test_wrong_picture_classes_and_malformed_stream_lengths_are_rejected(self):
        for stream in (b'', b'\5TIcon', b'junkBM', b'\7TBitmap\0', b'\7TBitmap' + self.stream[:-1]):
            self.root.children[1].properties['picture.data'] = Value('binary', stream)
            with self.subTest(stream=stream[:10]), self.assertRaises(DfmError):
                self.emit()

    def test_all_bitmap_stream_truncations_are_rejected(self):
        # Empty data is the deliberate clear operation, not a damaged BMP.
        for size in range(1, len(self.stream)):
            with self.subTest(size=size), self.assertRaises(ValueError):
                bitmap_payload(self.stream[:size])

    def test_bitmap_header_and_pixel_bounds_are_checked_before_resource_emission(self):
        for offset, replacement in ((4, b'NO'), (4 + 10, struct.pack('<I', 54)),
                                    (4 + 28, struct.pack('<H', 24)),
                                    (4 + 18, struct.pack('<i', 32768))):
            damaged = bytearray(self.stream)
            damaged[offset:offset + len(replacement)] = replacement
            self.button.properties['glyph.data'] = Value('binary', bytes(damaged))
            with self.subTest(offset=offset), self.assertRaises(DfmError):
                self.emit()

    def test_invalid_palette_and_image_size_metadata_is_rejected(self):
        for offset, replacement in ((4 + 6, b'\1'),
                                    (4 + 14 + 20, struct.pack('<I', 999)),
                                    (4 + 14 + 32, struct.pack('<I', 17)),
                                    (4 + 14 + 36, struct.pack('<I', 17)),
                                    (4 + 14 + 43, b'\1')):
            damaged = bytearray(self.stream)
            damaged[offset:offset + len(replacement)] = replacement
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                bitmap_payload(bytes(damaged))

    def test_numglyphs_divisibility_range_and_loading_order(self):
        self.button.properties['numglyphs'] = Value('integer', 2)
        output = self.emit()
        self.assertLess(output.index('BitBtn1.Glyph.LoadFromResourceName'), output.index('BitBtn1.NumGlyphs := 2'))
        self.assertLess(output.index('BitBtn1.NumGlyphs := 2'), output.index('BitBtn1.FinishLoading'))
        for count in (0, 3, 5):
            self.button.properties['numglyphs'] = Value('integer', count)
            with self.subTest(count=count), self.assertRaises(DfmError):
                self.emit()

    def test_design_metadata_and_unimplemented_button_kinds_are_not_silently_ignored(self):
        for prop, value in (('kind', Value('ident', 'bkHelp')),
                            ('style', Value('ident', 'bsWin31')),
                            ('iscontrol', Value('boolean', False)),
                            ('glyph.data', Value('string', 'BM')),
                            ('spacing', Value('integer', -2))):
            root = copy.deepcopy(self.root)
            root.children[2].properties[prop] = value
            with self.subTest(prop=prop), self.assertRaises(DfmError):
                Compiler(root).compile('fixture')

    def test_windowless_image_cannot_be_used_as_initial_focus_or_container(self):
        self.root.properties['activecontrol'] = Value('ident', 'Icon')
        with self.assertRaises(DfmError):
            self.emit()
        self.root.properties.pop('activecontrol')
        self.root.children[1].children.append(Component('TEdit', 'Nested'))
        with self.assertRaises(DfmError):
            self.emit()

    def test_image_rejects_windowed_and_font_properties(self):
        for prop, value in [('font.name', Value('string', 'System')),
                            ('taborder', Value('integer', 0))]:
            root = copy.deepcopy(self.root)
            root.children[1].properties[prop] = value
            with self.subTest(prop=prop), self.assertRaises(DfmError):
                Compiler(root).compile('fixture')

    def test_original_loaded_finishes_before_original_oncreate(self):
        source = self.emit()
        self.assertLess(source.index('BitBtn3.FinishLoading'), source.index('DfmCreateEvent := FormCreate'))
        self.assertLess(source.index('BitBtn3.FinishLoading'), source.index('OnShow := FormShow'))
        self.assertNotIn('WS_MINIMIZEBOX', source)
        self.assertNotIn('WS_MAXIMIZEBOX', source)

    def test_cli_requires_sidecar_and_preserves_outputs_on_compile_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source.dfm'
            output = Path(directory) / 'form.inc'
            resources = Path(directory) / 'form.res'
            source.write_bytes(self.data)
            command = [sys.executable, str(ROOT / 'tools/compile_dfm.py'), str(source), '--output', str(output)]
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
            self.assertFalse(output.exists())
            subprocess.run(command + ['--resources', str(resources)], check=True, capture_output=True)
            stamps = (output.stat().st_mtime_ns, resources.stat().st_mtime_ns)
            subprocess.run(command + ['--resources', str(resources)], check=True, capture_output=True)
            self.assertEqual(stamps, (output.stat().st_mtime_ns, resources.stat().st_mtime_ns))
            before = output.read_bytes(), resources.read_bytes()
            source.write_bytes(b'broken')
            self.assertNotEqual(subprocess.run(command + ['--resources', str(resources)], capture_output=True).returncode, 0)
            self.assertEqual(before, (output.read_bytes(), resources.read_bytes()))

    def test_cli_sidecar_cannot_overwrite_source_or_pascal_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source.dfm'
            output = Path(directory) / 'form.inc'
            source.write_bytes(self.data)
            for sidecar in (source, output):
                command = [sys.executable, str(ROOT / 'tools/compile_dfm.py'), str(source),
                           '--output', str(output), '--resources', str(sidecar)]
                self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
                self.assertEqual(source.read_bytes(), self.data)
                self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
