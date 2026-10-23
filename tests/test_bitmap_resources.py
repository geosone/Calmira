"""Branding BMPs must match the Win16 resources actually loaded by the shell."""
import importlib.util
import hashlib
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('bitmap_resources', ROOT / 'tools/bitmap_resources.py')
BITMAPS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BITMAPS)


def bitmap(pixel=0):
    dib = struct.pack('<IiiHHIIiiII', 40, 2, 1, 1, 4, 0, 4, 0, 0, 16, 16)
    dib += bytes(64) + bytes([pixel, 0, 0, 0])
    return struct.pack('<2sIHHI', b'BM', 14 + len(dib), 0, 0, 118) + dib


def record(name, data):
    return b'\xff\x02\x00' + name.encode() + b'\0' + struct.pack('<HI', 0x30, len(data)) + data


class BitmapResourceTests(unittest.TestCase):
    def test_help_project_and_banner_documentation_match_reloaded_sources(self):
        project = (ROOT / 'help/calmira.hpj').read_text()
        self.assertIn('TITLE=Calmira Reloaded Help', project)
        self.assertIn('calmira0.rtf', project)
        text = (ROOT / 'help/calmira.rtf').read_bytes()
        self.assertIn(b'\\{bmc banner.bmp\\}', text)
        self.assertIn(b'{\\b Size}: 24 x 256 pixels', text)

    def test_help_banner_is_the_same_artwork_rotated_clockwise(self):
        def pixels(path):
            data = BITMAPS.dib(path.read_bytes())
            width, height = struct.unpack_from('<ii', data, 4)
            palette = [data[40 + index * 4:43 + index * 4] for index in range(16)]
            stride = ((width * 4 + 31) // 32) * 4
            rows = []
            for y in range(height):
                row = data[104 + (height - 1 - y) * stride:]
                rows.append([palette[(row[x // 2] >> (4 if x % 2 == 0 else 0)) & 15]
                             for x in range(width)])
            return width, height, rows

        width, height, source = pixels(ROOT / 'bmp/banner.bmp')
        help_width, help_height, target = pixels(ROOT / 'help/banner.bmp')
        self.assertEqual((help_width, help_height), (height, width))
        self.assertEqual(target, [[source[height - 1 - x][y]
                                  for x in range(height)] for y in range(width)])

    def test_embedded_branding_matches_supplied_four_bit_bitmaps(self):
        records = {name: data for kind, name, flags, data, prefix in
                   BITMAPS.parse((ROOT / 'src/bitmaps.res').read_bytes()) if kind == 2}
        for name, size in (('TITLE', (241, 36)), ('BANNER', (24, 256))):
            with self.subTest(resource=name):
                dib = BITMAPS.dib((ROOT / f'bmp/{name.lower()}.bmp').read_bytes())
                self.assertEqual(records[name], dib)
                self.assertEqual(struct.unpack_from('<ii', dib, 4), size)

    def test_unrelated_historical_resources_remain_byte_identical(self):
        after = BITMAPS.parse((ROOT / 'src/bitmaps.res').read_bytes())
        self.assertEqual(len(after), 14)
        preserved = b''.join(prefix + struct.pack('<I', len(data)) + data
                             for kind, name, flags, data, prefix in after
                             if name not in ('TITLE', 'BANNER'))
        self.assertEqual(hashlib.sha256(preserved).hexdigest(),
                         'ee2bd8265d70192fa5c4335c538e058b916adf149e75402dac962757d381c2f4')

    def test_replacement_preserves_other_records_and_flags(self):
        before = record('TITLE', bitmap()[14:]) + record('OTHER', b'unchanged')
        after = BITMAPS.replace(before, {'TITLE': bitmap(0x12)})
        self.assertEqual(after, record('TITLE', bitmap(0x12)[14:]) + record('OTHER', b'unchanged'))

    def test_rejects_truncated_records(self):
        for data in (b'\xff', b'\xff\x02\x00TITLE', record('TITLE', b'x')[:-1]):
            with self.subTest(data=data), self.assertRaises(ValueError):
                BITMAPS.parse(data)

    def test_rejects_compressed_or_non_four_bit_bmp(self):
        for offset, value in ((28, 8), (30, 1)):
            data = bytearray(bitmap())
            data[offset] = value
            with self.assertRaises(ValueError):
                BITMAPS.dib(data)

    def test_rejects_missing_duplicate_or_resized_target(self):
        original = record('TITLE', bitmap()[14:])
        changed = bytearray(bitmap())
        struct.pack_into('<i', changed, 18, 3)
        for source, replacements in ((original, {'MISSING': bitmap()}),
                                     (original + original, {'TITLE': bitmap()}),
                                     (original, {'TITLE': bytes(changed)})):
            with self.assertRaises(ValueError):
                BITMAPS.replace(source, replacements)
