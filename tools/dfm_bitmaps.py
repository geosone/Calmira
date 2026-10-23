"""Bounded Delphi bitmap payloads -> native Win16 bitmap resources.

The cancellation glyph below is an original two-frame cross, not a bitmap
extracted from proprietary Delphi resources. Other button kinds fail closed.
"""
import hashlib
import struct

if __package__:
    from .bitmap_resources import dib
else:
    from bitmap_resources import dib


def bitmap_payload(data, picture=False):
    if picture:
        if data == b'\0':
            return None
        if not data.startswith(b'\7TBitmap'):
            raise ValueError('only TBitmap picture data is supported')
        data = data[8:]
    if not data:
        return None
    if len(data) < 4 or struct.unpack_from('<I', data)[0] != len(data) - 4:
        raise ValueError('invalid Delphi bitmap stream length')
    bitmap = data[4:]
    if not bitmap:
        return None
    # Some original Delphi glyphs (notably select.DeselectBtn) include a small
    # declared all-zero trailer after the complete pixel array. Preserve pixels
    # while omitting only this bounded, nonsemantic legacy padding from RT_BITMAP.
    if len(bitmap) >= 54 and bitmap[:2] == b'BM':
        length, offset = struct.unpack_from('<IxxxxI', bitmap, 2)
        header, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', bitmap, 14)
        if (length == len(bitmap) and offset == 118 and header == 40 and
                width > 0 and height > 0 and planes == 1 and bits == 4 and compression == 0):
            end = offset + ((width * bits + 31) // 32) * 4 * height
            if 0 < len(bitmap) - end <= 64 and not any(bitmap[end:]):
                normalized = bytearray(bitmap[:end])
                struct.pack_into('<I', normalized, 2, end)
                bitmap = bytes(normalized)
    payload = dib(bitmap)
    width, height = struct.unpack_from('<ii', payload, 4)
    image_size = struct.unpack_from('<I', payload, 20)[0]
    colors_used, colors_important = struct.unpack_from('<II', payload, 32)
    if (bitmap[6:10] != bytes(4) or image_size not in (0, len(payload) - 104) or
            colors_used not in (0, 16) or colors_important > 16 or
            any(payload[43:104:4])):
        raise ValueError('inconsistent bitmap header or palette')
    if width > 32767 or height > 32767 or len(payload) > 65535:
        raise ValueError('bitmap exceeds the native resource bounds')
    return payload


def cancellation_glyph():
    """32x16, 4-bit BMP DIB: red cross and supplied grey disabled frame."""
    pixels = bytearray()
    for y in range(15, -1, -1):
        row = []
        for x in range(32):
            local = x % 16
            cross = 3 <= local <= 12 and 3 <= y <= 12 and (
                abs(local - y) <= 1 or abs(local + y - 15) <= 1)
            row.append((1 if x < 16 else 2) if cross else 0)
        pixels.extend((row[x] << 4) | row[x + 1] for x in range(0, 32, 2))
    palette = bytes((255, 255, 255, 0, 0, 0, 160, 0, 128, 128, 128, 0)) + bytes(13 * 4)
    return struct.pack('<IiiHHIIiiII', 40, 32, 16, 1, 4, 0, len(pixels), 0, 0, 16, 0) + palette + pixels


class BitmapResources:
    def __init__(self):
        self.entries = {}

    def add(self, payload):
        name = 'DFM_' + hashlib.sha256(payload).hexdigest()[:20].upper()
        if name in self.entries and self.entries[name] != payload:
            raise ValueError('bitmap resource name collision')
        self.entries[name] = payload
        return name

    def encode(self):
        result = bytearray()
        for name, payload in sorted(self.entries.items()):
            result += b'\xff\x02\0' + name.encode('ascii') + b'\0'
            result += struct.pack('<HI', 0x1030, len(payload)) + payload
        return bytes(result)
