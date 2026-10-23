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


def merge(inputs):
    records = {}
    output = bytearray()
    for data in inputs:
        if len(data) > 4 * 1024 * 1024:
            raise ValueError('resource input exceeds 4 MiB')
        for kind, name, flags, payload, prefix in parse(data):
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
    args = parser.parse_args()
    try:
        if args.output.resolve() in {path.resolve() for path in args.inputs}:
            raise ValueError('output must be separate from all inputs')
        result = merge([path.read_bytes() for path in args.inputs])
        write_generated(args.output, result)
    except (ValueError, OSError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
