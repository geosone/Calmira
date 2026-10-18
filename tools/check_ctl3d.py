#!/usr/bin/env python3
"""Verify the built Win16 CTL3D module's identity and export ordinals."""

import re
import struct
import sys
from pathlib import Path


def verify(path):
    data = path.read_bytes()
    ne = struct.unpack_from('<I', data, 0x3C)[0]
    if data[:2] != b'MZ' or data[ne:ne + 2] != b'NE':
        raise ValueError('expected an MZ/NE module')
    flags = struct.unpack_from('<H', data, ne + 0x0C)[0]
    if not flags & 0x8000 or flags & 3 != 1:
        raise ValueError('expected a DLL with single shared automatic data')
    resident = ne + struct.unpack_from('<H', data, ne + 0x26)[0]
    nonresident = struct.unpack_from('<I', data, ne + 0x2C)[0]
    names = {}
    module = None
    for table in (resident, nonresident):
        pos = table
        while data[pos]:
            length = data[pos]
            name = data[pos + 1:pos + 1 + length].decode('ascii')
            ordinal = struct.unpack_from('<H', data, pos + 1 + length)[0]
            if table == resident and pos == resident:
                module = name
            if ordinal:
                names[name] = ordinal
            pos += length + 3
    if module != 'CTL3DV2':
        raise ValueError(f'unexpected module identity: {module}')
    definition = (Path(__file__).resolve().parents[1] /
                  'vendor/build-deps/open386max-ctl3d/CTL3DV2.DEF')
    exports = re.findall(r'^\s+(\w+)\s+@(\d+)', definition.read_text(), re.M)
    for name, ordinal in exports:
        if names.get(name) != int(ordinal):
            raise ValueError(f'wrong or missing export: {name} @{ordinal}')
    print(f'CTL3DV2 Win16 DLL: {len(exports)} export ordinals verified')


if __name__ == '__main__':
    verify(Path(sys.argv[1]))
