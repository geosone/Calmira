#!/usr/bin/env python3
"""Check downloaded Calmira add-on checksums and inventory their ZIP sources."""

import argparse
import hashlib
from pathlib import Path, PurePosixPath
from zipfile import ZipFile


def audit(directory):
    manifest = Path(__file__).resolve().parents[1] / 'docs/addons/sha256sums'
    for line in manifest.read_text().splitlines():
        digest, name = line.split()
        path = directory / name
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError(f'checksum mismatch: {name}')
        if path.suffix != '.zip':
            print(f'{name}: checksum verified; installer not executed')
            continue
        with ZipFile(path) as archive:
            for item in archive.namelist():
                item = item.replace('\\', '/')
                if '..' in PurePosixPath(item).parts or item.startswith('/') or ':' in item:
                    raise ValueError(f'unsafe archive member: {name}: {item}')
            bad = archive.testzip()
            if bad:
                raise ValueError(f'ZIP CRC failure: {name}: {bad}')
            sources = [n for n in archive.namelist()
                       if Path(n).suffix.lower() in ('.pas', '.dpr', '.c', '.asm', '.86')]
            print(f'{name}: checksum/CRC verified, {len(sources)} source file(s)')
            for source in sources:
                print(f'  {source}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    audit(parser.parse_args().directory)
