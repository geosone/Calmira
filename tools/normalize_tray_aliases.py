#!/usr/bin/env python3
"""Remove obsolete icon-library references from Calmira's bundled aliases."""

import argparse
import struct
from pathlib import Path


def normalize(data):
    if data[:5] != b'\x04CMSR' or len(data) < 11:
        raise ValueError('expected a Calmira CMSR alias')
    # Signature, then Win16 Left/Top/Kind integers, followed by the three
    # length-prefixed Target, Caption and IconFile strings (REFERENC.PAS).
    pos = 11
    for _ in range(2):
        if pos >= len(data) or pos + 1 + data[pos] > len(data):
            raise ValueError('truncated alias string')
        pos += 1 + data[pos]
    if pos >= len(data):
        raise ValueError('missing icon source')
    end = pos + 1 + data[pos]
    if end + 2 > len(data):
        raise ValueError('truncated icon source/index')
    source = data[pos + 1:end].decode('cp1252').replace('/', '\\').lower()
    if source.rsplit('\\', 1)[-1] != 'w95icons.dll':
        return data
    # Empty IconFile selects the normal owned Calmira icon via AssignDefault.
    # Retain all other reference fields and the cached bitmap unchanged.
    return data[:pos] + b'\0' + struct.pack('<h', 0) + data[end + 2:]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    for path in sorted(path for path in args.directory.iterdir() if path.suffix.lower() == '.als'):
        before = path.read_bytes()
        after = normalize(before)
        if after != before:
            path.write_bytes(after)
            print(f'Normalized {path}')
