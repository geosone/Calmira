#!/usr/bin/env python3
"""Read-only mtools comparison of DOS/Windows files in two private raw images."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

FILES = (
    'IO.SYS', 'MSDOS.SYS', 'COMMAND.COM', 'HIMEM.SYS',
    'WINDOWS/SYSTEM.INI', 'WINDOWS/WIN.COM', 'WINDOWS/SYSTEM/WIN386.EXE',
    'WINDOWS/SYSTEM/WINOA386.MOD', 'WINDOWS/SYSTEM/KRNL386.EXE',
    'WINDOWS/SYSTEM/DOSX.EXE', 'WINDOWS/SYSTEM/SYSTEM.DRV',
    'WINDOWS/SYSTEM/VGA.3GR', 'WINDOWS/SYSTEM/IFSMGR.386',
    'WINDOWS/SYSTEM/VCACHE.386', 'WINDOWS/SYSTEM/VSHARE.386',
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('first', type=Path)
    parser.add_argument('second', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--offset', default=32256, type=int)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    results = {}
    for name in FILES:
        row = []
        for number, source in enumerate((args.first, args.second)):
            output = args.output / str(number) / name
            output.parent.mkdir(parents=True, exist_ok=True)
            result = subprocess.run(['mcopy', '-i', f'{source}@@{args.offset}',
                                     '::/' + name, str(output)], capture_output=True)
            if result.returncode:
                row.append(None)
            else:
                data = output.read_bytes()
                row.append({'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        results[name] = {'first': row[0], 'second': row[1], 'equal': row[0] is not None and row[0] == row[1]}
        state = 'same ' if results[name]['equal'] else ('absent' if row == [None, None] else 'DIFF ')
        print(state, name)
    (args.output / 'comparison.json').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
