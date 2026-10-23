#!/usr/bin/env python3
"""Replace named Win16 bitmap resources, preserving unrelated resource bytes."""
import argparse
from pathlib import Path
import struct


def parse(data):
    position = 0
    records = []

    def identifier():
        nonlocal position
        if position >= len(data):
            raise ValueError('truncated resource identifier')
        if data[position] == 255:
            if position + 3 > len(data):
                raise ValueError('truncated ordinal')
            value = struct.unpack_from('<H', data, position + 1)[0]
            position += 3
            return value
        end = data.find(b'\0', position)
        if end < 0:
            raise ValueError('unterminated resource name')
        value = data[position:end].decode('ascii')
        position = end + 1
        return value

    while position < len(data):
        start = position
        kind, name = identifier(), identifier()
        if position + 6 > len(data):
            raise ValueError('truncated resource header')
        flags, size = struct.unpack_from('<HI', data, position)
        position += 6
        if size > len(data) - position:
            raise ValueError('truncated resource payload')
        payload = data[position:position + size]
        records.append((kind, name, flags, payload, data[start:position - 4]))
        position += size
    return records


def dib(bitmap):
    if len(bitmap) < 54 or bitmap[:2] != b'BM':
        raise ValueError('expected Windows BMP')
    length, offset = struct.unpack_from('<IxxxxI', bitmap, 2)
    header, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', bitmap, 14)
    if (length != len(bitmap) or header != 40 or width <= 0 or height <= 0
            or planes != 1 or bits != 4 or compression != 0 or offset != 118):
        raise ValueError('expected uncompressed bottom-up Windows 3.x 4-bit BMP')
    if len(bitmap) != offset + ((width * bits + 31) // 32) * 4 * height:
        raise ValueError('invalid bitmap pixel length')
    return bitmap[14:]


def replace(data, replacements):
    records = parse(data)
    result = bytearray()
    seen = set()
    for kind, name, flags, payload, prefix in records:
        if kind == 2 and name in replacements:
            if name in seen:
                raise ValueError('duplicate target bitmap resource')
            updated = dib(replacements[name])
            if updated[4:16] != payload[4:16]:
                raise ValueError('replacement must preserve bitmap dimensions and depth')
            payload = updated
            seen.add(name)
        result += prefix + struct.pack('<I', len(payload)) + payload
    if seen != set(replacements):
        raise ValueError('target bitmap resource not found')
    return bytes(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--bitmap', action='append', required=True, metavar='NAME=FILE')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve() == args.source.resolve() or args.output.exists() or args.output.is_symlink():
        parser.error('output must be a new file, separate from the source')
    try:
        replacements = {}
        for item in args.bitmap:
            name, filename = item.split('=', 1)
            if name in replacements:
                raise ValueError('duplicate replacement name')
            replacements[name] = Path(filename).read_bytes()
        result = replace(args.source.read_bytes(), replacements)
        with args.output.open('xb') as stream:
            stream.write(result)
    except (ValueError, OSError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
