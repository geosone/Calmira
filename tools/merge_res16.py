#!/usr/bin/env python3
"""Merge Win16 .RES inputs without silently replacing conflicting resources."""
import argparse
from pathlib import Path
import struct

if __package__:
    from .bitmap_resources import parse
    from .compile_dfm import write_generated
else:
    from bitmap_resources import parse
    from compile_dfm import write_generated


# Icon and cursor images (RT_ICON, RT_CURSOR) and the group directories
# (RT_GROUP_ICON, RT_GROUP_CURSOR) whose 14-byte entries end in their ordinals.
IMAGES = {3: 14, 1: 12}


def header(kind, name, flags):
    def identifier(value):
        return b'\xff' + struct.pack('<H', value) if isinstance(value, int) else value.encode('ascii') + b'\0'
    return identifier(kind) + identifier(name) + struct.pack('<H', flags)


def renumbered(records, next_ordinal):
    """Give one input's icon and cursor images fresh ordinals, as a linker does
    when several resource files each number their images from 1."""
    mapping = {}
    for kind, name, flags, payload, prefix in records:
        if kind in IMAGES:
            if not isinstance(name, int) or (kind, name) in mapping:
                raise ValueError(f'invalid image resource: {kind!r}/{name!r}')
            mapping[kind, name] = next_ordinal[kind]
            next_ordinal[kind] += 1
    groups = {group: image for image, group in IMAGES.items()}
    result = []
    for kind, name, flags, payload, prefix in records:
        if kind in IMAGES:
            name = mapping[kind, name]
            prefix = header(kind, name, flags)
        elif kind in groups:
            if len(payload) < 6:
                raise ValueError(f'truncated group resource: {kind!r}/{name!r}')
            count = struct.unpack_from('<H', payload, 4)[0]
            if len(payload) != 6 + 14 * count:
                raise ValueError(f'invalid group resource: {kind!r}/{name!r}')
            payload = bytearray(payload)
            for index in range(count):
                position = 6 + 14 * index + 12
                old = struct.unpack_from('<H', payload, position)[0]
                if (groups[kind], old) not in mapping:
                    raise ValueError(f'group {name!r} names a missing image {old}')
                struct.pack_into('<H', payload, position, mapping[groups[kind], old])
            payload = bytes(payload)
        result.append((kind, name, flags, payload, prefix))
    return result


def merge(inputs, renumber_images=False):
    records = {}
    output = bytearray()
    next_ordinal = {kind: 1 for kind in IMAGES}
    for data in inputs:
        if len(data) > 4 * 1024 * 1024:
            raise ValueError('resource input exceeds 4 MiB')
        parsed = parse(data)
        if renumber_images:
            parsed = renumbered(parsed, next_ordinal)
        for kind, name, flags, payload, prefix in parsed:
            key = tuple(part.casefold() if isinstance(part, str) else part for part in (kind, name))
            value = flags, payload
            if key in records:
                if records[key] != value:
                    raise ValueError(f'conflicting resource: {kind!r}/{name!r}')
                continue
            records[key] = value
            output += prefix + struct.pack('<I', len(payload)) + payload
    return bytes(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', type=Path, nargs='+')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renumber-images', action='store_true',
                        help='renumber icon and cursor images across inputs and fix their groups')
    args = parser.parse_args()
    try:
        if args.output.resolve() in {path.resolve() for path in args.inputs}:
            raise ValueError('output must be separate from all inputs')
        result = merge([path.read_bytes() for path in args.inputs], args.renumber_images)
        write_generated(args.output, result)
    except (ValueError, OSError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
