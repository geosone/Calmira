"""Lossless Win16 resource linking, including original icon groups."""
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

from tools.bitmap_resources import parse
from tools.merge_res16 import merge

ROOT = Path(__file__).resolve().parents[1]


def record(kind=2, name='Probe', flags=0x1030, payload=b'pixels'):
    def identifier(value):
        return b'\xff' + struct.pack('<H', value) if isinstance(value, int) else value.encode('ascii') + b'\0'
    return identifier(kind) + identifier(name) + struct.pack('<HI', flags, len(payload)) + payload


class ResourceMergeTests(unittest.TestCase):
    def test_original_library_is_byte_preserved(self):
        original = (ROOT / 'src/icons.res').read_bytes()
        self.assertEqual(merge([original]), original)
        self.assertEqual(len(parse(original)), 66)
        self.assertIn((14, 'MULTIFILEICON'), [(r[0], r[1]) for r in parse(original)])
        extra = record()
        self.assertEqual(merge([original, extra]), original + extra)

    def test_identical_case_insensitive_duplicates_keep_first_encoding(self):
        first = record(name='Probe')
        self.assertEqual(merge([first, record(name='PROBE')]), first)
        self.assertEqual(merge([record(kind='BITMAP'), record(kind='bitmap')]), record(kind='BITMAP'))

    def test_renumbered_icon_images_keep_their_groups(self):
        def group(*ordinals):
            return struct.pack('<HHH', 0, 1, len(ordinals)) + b''.join(
                bytes(12) + struct.pack('<H', ordinal) for ordinal in ordinals)
        first = record(3, 1, 0x1010, b'a1') + record(3, 2, 0x1010, b'a2') + record(14, 'A', 0x1030, group(1, 2))
        second = record(3, 1, 0x1010, b'b1') + record(14, 'B', 0x1030, group(1))
        cursor = record(1, 1, 0x1010, b'c1') + record(12, 'C', 0x1030, group(1))
        with self.assertRaisesRegex(ValueError, 'conflicting resource'):
            merge([first, second])
        records = {(r[0], r[1]): r[3] for r in parse(merge([first, second, cursor], renumber_images=True))}
        self.assertEqual([records[3, n] for n in (1, 2, 3)], [b'a1', b'a2', b'b1'])
        self.assertEqual(records[14, 'A'], group(1, 2))
        self.assertEqual(records[14, 'B'], group(3))
        self.assertEqual((records[1, 1], records[12, 'C']), (b'c1', group(1)))
        # Calmira's own resources link without conflicts.
        originals = [(ROOT / name).read_bytes() for name in ('src/calmira.res', 'src/icons.res', 'src/cursors.res')]
        merged = parse(merge(originals, renumber_images=True))
        self.assertEqual(len(merged), sum(len(parse(data)) for data in originals))

    def test_renumbering_rejects_dangling_and_named_images(self):
        for data in (record(14, 'G', 0x1030, struct.pack('<HHH', 0, 1, 1) + bytes(12) + struct.pack('<H', 7)),
                     record(3, 'NAMED', 0x1010, b'x'),
                     record(14, 'G', 0x1030, b'\0\0\1\0\2\0')):
            with self.subTest(data=data), self.assertRaises(ValueError):
                merge([data], renumber_images=True)

    def test_conflicts_are_never_silently_replaced(self):
        for second in (record(payload=b'other'), record(flags=0)):
            with self.assertRaisesRegex(ValueError, 'conflicting resource'):
                merge([record(), second])

    def test_ordinals_and_strings_are_distinct(self):
        records = [record(name=1), record(name='1'), record(kind='2', name=1)]
        self.assertEqual(len(parse(merge(records))), 3)

    def test_all_partial_records_and_oversized_inputs_fail(self):
        complete = record()
        for length in range(1, len(complete)):
            with self.subTest(length=length), self.assertRaises(ValueError):
                merge([complete[:length]])
        with self.assertRaisesRegex(ValueError, '4 MiB'):
            merge([bytes(4 * 1024 * 1024 + 1)])

    def test_cli_is_atomic_idempotent_and_protects_inputs(self):
        with tempfile.TemporaryDirectory() as folder:
            first, second, output = [Path(folder) / name for name in ('a.res', 'b.res', 'out.res')]
            first.write_bytes(record()); second.write_bytes(record(name='Other'))
            command = [sys.executable, str(ROOT / 'tools/merge_res16.py'), str(first), str(second), '--output']
            subprocess.run(command + [str(output)], check=True, capture_output=True)
            stamp = output.stat().st_mtime_ns
            subprocess.run(command + [str(output)], check=True, capture_output=True)
            self.assertEqual(output.stat().st_mtime_ns, stamp)
            saved = output.read_bytes()
            second.write_bytes(record(payload=b'conflict'))
            self.assertNotEqual(subprocess.run(command + [str(output)], capture_output=True).returncode, 0)
            self.assertEqual(output.read_bytes(), saved)
            self.assertNotEqual(subprocess.run(command + [str(first)], capture_output=True).returncode, 0)
            self.assertEqual(first.read_bytes(), record())
