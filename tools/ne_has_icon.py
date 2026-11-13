#!/usr/bin/env python3
"""Fail unless a Win16 NE program carries an icon group resource."""
import struct
import sys


def resource_types(data):
    header = struct.unpack_from('<I', data, 0x3c)[0]
    if data[header:header + 2] != b'NE':
        return set()
    table = header + struct.unpack_from('<H', data, header + 0x24)[0]
    names = header + struct.unpack_from('<H', data, header + 0x26)[0]
    types, offset = set(), table + 2
    while table != names and struct.unpack_from('<H', data, offset)[0]:
        kind, count = struct.unpack_from('<HH', data, offset)
        types.add(kind & 0x7fff)
        offset += 8 + 12 * count
    return types


def main():
    for path in sys.argv[1:]:
        with open(path, 'rb') as stream:
            if 14 not in resource_types(stream.read()):
                sys.exit(f'{path} has no icon')


if __name__ == '__main__':
    main()
