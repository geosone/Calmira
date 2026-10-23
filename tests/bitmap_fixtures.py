"""Tiny bottom-up BMPs with independently known pixels for native GDI tests."""
from pathlib import Path
import struct


def bitmap(depth):
    width, height = 2, 2
    if depth == 1:
        palette = bytes((0, 0, 0, 0, 255, 255, 255, 0))
        pixels = b'\x80\0\0\0\x40\0\0\0'  # bottom white/black, top black/white
    elif depth == 24:
        palette = b''
        # BGR triples, bottom blue/white, top red/green, DWORD-padded rows.
        pixels = bytes((255, 0, 0, 255, 255, 255, 0, 0,
                        0, 0, 255, 0, 255, 0, 0, 0))
    elif depth == 8:
        width, height = 256, 300
        palette = bytes((0, 0, 0, 0, 0, 0, 255, 0,
                         0, 255, 0, 0, 255, 0, 0, 0)) + bytes(252 * 4)
        # Bottom-up rows: upper half red/green, lower half blue/black.
        pixels = b''.join(bytes((3 if y < 150 else 1,)) * 128
                          + bytes((0 if y < 150 else 2,)) * 128
                          for y in range(height))
    else:
        raise ValueError(depth)
    offset = 54 + len(palette)
    return (struct.pack('<2sIHHI', b'BM', offset + len(pixels), 0, 0, offset)
            + struct.pack('<IiiHHIIiiII', 40, width, height, 1, depth, 0, len(pixels), 0, 0, 0, 0)
            + palette + pixels)


if __name__ == '__main__':
    import sys
    output = Path(sys.argv[1])
    for depth in (1, 8, 24):
        (output / f'BITS{depth}.BMP').write_bytes(bitmap(depth))
    bad = bytearray(bitmap(24))
    struct.pack_into('<I', bad, 10, len(bad) - 1)
    (output / 'SHORT.BMP').write_bytes(bad)
    # Monochrome icon: vertical transparent / white / black / invert stripes.
    xor = bytes((0, 255, 0, 255)) * 32
    mask = bytes((255, 0, 0, 255)) * 32
    dib = (struct.pack('<IiiHHIIiiII', 40, 32, 64, 1, 1, 0, 256, 0, 0, 0, 0)
           + bytes((0, 0, 0, 0, 255, 255, 255, 0)) + xor + mask)
    icon = (struct.pack('<HHH', 0, 1, 1)
            + struct.pack('<BBBBHHII', 32, 32, 2, 0, 1, 1, len(dib), 22) + dib)
    (output / 'icontest.ico').write_bytes(icon)
