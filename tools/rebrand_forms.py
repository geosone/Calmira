"""Replace the remaining Calmira Reborn branding in the binary form files.

The tip dialog embeds its title picture (bmp/tiptit.bmp) in src/tips.dfm, two
captions name the shell and the About box links to the project homepage. Picture size and depth stay unchanged, so only
the pixel array and the two counted strings change. --check reports, without
writing, whether the forms are current.
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TITLE = ROOT / 'bmp/tiptit.bmp'
CAPTIONS = {
    'src/tips.dfm': ('Show this the first time you run Calmira Reborn each day',
                     'Show this the first time you run Calmira Reloaded each day'),
    'src/deskprop.dfm': ('Changes will not take effect until Calmira Reborn is restarted.',
                         'Changes will not take effect until Calmira Reloaded is restarted.'),
    'src/about.dfm': ('http://huntertur.net/calmirar.html',
                      'https://github.com/geosone/Calmira'),
}
VA_STRING = 6


def counted(text):
    data = text.encode('cp1252')
    if len(data) > 255:
        raise ValueError('caption too long for a short string')
    return bytes([VA_STRING, len(data)]) + data


def picture_span(form):
    """Offset and length of the BMP pixel array embedded as Title.Picture."""
    marker = b'\x07TBitmap'
    start = form.index(marker, form.index(b'TImage\x05Title'))
    bmp = start + len(marker) + 4
    if form[bmp:bmp + 2] != b'BM':
        raise ValueError('title picture is not a bitmap')
    size = int.from_bytes(form[bmp + 2:bmp + 6], 'little')
    offset = int.from_bytes(form[bmp + 10:bmp + 14], 'little')
    return bmp, offset, size


def size_field(form):
    """Offset of the size of the single Win16 RCDATA resource (type, name, flags)."""
    if form[:3] != b'\xff\x0a\x00':
        raise ValueError('form file is not one Win16 RCDATA resource')
    return form.index(b'\0', 3) + 3


def payload_span(form):
    size_at = size_field(form)
    if size_at + 4 + int.from_bytes(form[size_at:size_at + 4], 'little') != len(form):
        raise ValueError('incomplete form resource')
    return size_at


def resize(form):
    size_at = size_field(form)
    return form[:size_at] + (len(form) - size_at - 4).to_bytes(4, 'little') + form[size_at + 4:]


def rebrand(check):
    title = TITLE.read_bytes()
    stale = []
    for name, (old, new) in CAPTIONS.items():
        path = ROOT / name
        form = path.read_bytes()
        payload_span(form)
        if counted(old) in form:
            if form.count(counted(old)) != 1:
                raise ValueError(f'{name}: caption is not unique')
            form = form.replace(counted(old), counted(new))
        elif counted(new) not in form:
            raise ValueError(f'{name}: caption not found')
        if name == 'src/tips.dfm':
            bmp, offset, size = picture_span(form)
            embedded = form[bmp:bmp + size]
            if embedded[:offset] != title[:offset] or len(title) != size:
                raise ValueError('bmp/tiptit.bmp changed header, size or depth')
            form = form[:bmp] + title + form[bmp + size:]
        form = resize(form)
        if form != path.read_bytes():
            stale.append(name)
            if not check:
                path.write_bytes(form)
    return stale


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    stale = rebrand(args.check)
    for name in stale:
        print(('stale ' if args.check else 'updated ') + name)
    return 1 if args.check and stale else 0


if __name__ == '__main__':
    sys.exit(main())
