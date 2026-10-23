#!/usr/bin/env python3
"""Conservative DGROUP/stack/local-heap budget guard for our Win16 probes."""
from pathlib import Path
import struct


def check_budget(data):
    if len(data) < 64 or data[:2] != b'MZ':
        raise ValueError('expected an MZ/NE executable')
    ne = struct.unpack_from('<I', data, 60)[0]
    if ne + 64 > len(data) or data[ne:ne + 2] != b'NE':
        raise ValueError('missing NE header')
    index, heap, stack = struct.unpack_from('<HHH', data, ne + 14)
    count = struct.unpack_from('<H', data, ne + 28)[0]
    table = ne + struct.unpack_from('<H', data, ne + 34)[0]
    if not 1 <= index <= count or table < ne + 64 or table + count * 8 > len(data):
        raise ValueError('invalid automatic-data segment table')
    _, size, _, minimum = struct.unpack_from('<HHHH', data, table + (index - 1) * 8)
    allocated = max(size or 65536, minimum or 65536)
    total = allocated + heap + stack
    if total > 65536:
        raise ValueError(f'Win16 data budget exceeded: {allocated} data + {stack} stack + {heap} heap = {total}')
    return total


if __name__ == '__main__':
    import sys
    try:
        print(f'Win16 data budget: {check_budget(Path(sys.argv[1]).read_bytes())}/65536 bytes')
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
