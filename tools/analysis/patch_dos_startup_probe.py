#!/usr/bin/env python3
"""Instrument a disposable Watcom DOS EXE without moving code or relocations.

The null-assignment error text is replaced by a register-preserving probe.
Never use this diagnostic copy as a product executable.
"""
import argparse
from pathlib import Path
import struct


def instrument(data):
    result = bytearray(data)
    if len(data) < 28 or data[:2] != b'MZ':
        raise ValueError('expected MZ executable')
    count, paragraphs = struct.unpack_from('<HH', data, 6)
    ip, cs = struct.unpack_from('<HH', data, 20)
    table = struct.unpack_from('<H', data, 24)[0]
    entry = paragraphs * 16 + cs * 16 + ip
    if table + count * 4 > paragraphs * 16 or entry + 0x3d > len(data):
        raise ValueError('truncated MZ header, relocation table or startup')
    if data[entry:entry + 2] != b'\xeb\x37' or data[entry + 0x3a] != 0xb9:
        raise ValueError('unrecognized small-model Watcom startup layout')
    fixups = [struct.unpack_from('<HH', data, table + index * 4) for index in range(count)]
    if (ip + 0x3b, cs) not in fixups:
        raise ValueError('DGROUP immediate has no expected relocation')
    # AX/DS-independent before cstart: U=relative operand, R=relocated operand.
    code = bytes.fromhex('9c 50 52 53 8c c8 89 c3 2e a1')
    code += struct.pack('<H', ip + 0x3b)
    code += bytes.fromhex('39 d8 b0 55 72 02 b0 52 ba e9 00 ee 5b 5a 58 9d')
    code += bytes((0xeb, 0x39 - (4 + len(code) + 2)))
    assert len(code) <= 0x39 - 4
    result[entry:entry + 2] = b'\xeb\x02'
    result[entry + 4:entry + 4 + len(code)] = code
    assert result[:entry] == data[:entry]
    assert result[entry + 0x39:] == data[entry + 0x39:]
    return bytes(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve() or args.output.exists() or args.output.is_symlink():
        parser.error('diagnostic output must be a new file, never the input')
    result = instrument(args.input.read_bytes())
    with args.output.open('xb') as stream:
        stream.write(result)


if __name__ == '__main__':
    main()
