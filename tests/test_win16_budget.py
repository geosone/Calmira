import struct
import unittest
from tools.check_win16_budget import check_budget


def executable(minimum=53696, heap=4096, stack=4096):
    data = bytearray(136)
    data[:2] = b'MZ'
    struct.pack_into('<I', data, 60, 64)
    data[64:66] = b'NE'
    struct.pack_into('<HHH', data, 78, 1, heap, stack)
    struct.pack_into('<H', data, 92, 1)
    struct.pack_into('<H', data, 98, 64)
    struct.pack_into('<HHHH', data, 128, 0, 47164, 1, minimum)
    return data


class Win16BudgetTests(unittest.TestCase):
    def test_probe_fits_with_explicit_local_heap(self):
        self.assertEqual(check_budget(executable()), 61888)

    def test_previous_native_loader_failure_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'budget exceeded'):
            check_budget(executable(heap=8192))

    def test_zero_allocation_means_full_segment_not_zero_bytes(self):
        with self.assertRaisesRegex(ValueError, 'budget exceeded'):
            check_budget(executable(minimum=0))

    def test_exact_budget_boundary(self):
        self.assertEqual(check_budget(executable(minimum=57344)), 65536)
        with self.assertRaises(ValueError):
            check_budget(executable(minimum=57345))

    def test_malformed_headers_and_segment_table(self):
        for data in (b'', b'MZ', bytes(64), executable()[:130]):
            with self.assertRaises(ValueError):
                check_budget(data)
        data = executable()
        struct.pack_into('<H', data, 78, 2)
        with self.assertRaises(ValueError):
            check_budget(data)
