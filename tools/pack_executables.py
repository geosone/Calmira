#!/usr/bin/env python3
"""Pack release copies with the pinned UPX fork; verify lossless extraction."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def pack(upx, sources, output):
    upx = str(Path(upx).resolve())
    # Our runners use UPX as a tool path; UPX itself treats it as option text.
    # Explicit CLI options define this reproducible pack/test/unpack workflow.
    environment = os.environ.copy()
    environment.pop('UPX', None)
    output.mkdir(parents=True, exist_ok=True)
    names = [source.name.upper() for source in sources]
    if len(set(names)) != len(names):
        raise ValueError('duplicate executable names')
    report = {}
    for source in sources:
        destination = output / source.name.upper()
        if source.resolve() == destination.resolve():
            raise ValueError('output must not overwrite a compiler artifact')
        if source.suffix.upper() != '.EXE':
            raise ValueError('only EXE files are supported; do not pack Win16 DLLs')
        original = source.read_bytes()
        # Keep an older successful output intact if packing or validation fails.
        with tempfile.TemporaryDirectory(prefix='upx-', dir=output) as temporary:
            candidate = Path(temporary) / destination.name
            shutil.copyfile(source, candidate)
            subprocess.run([upx, '--best', str(candidate)], check=True, env=environment)
            subprocess.run([upx, '-t', str(candidate)], check=True, env=environment)
            restored = Path(temporary) / 'RESTORED.EXE'
            subprocess.run([upx, '-d', '-o', str(restored), str(candidate)], check=True, env=environment)
            if restored.read_bytes() != original:
                raise ValueError(f'UPX round-trip changed {source}')
            packed_size = candidate.stat().st_size
            if packed_size >= len(original):
                raise ValueError(f'UPX did not reduce {source}')
            candidate.replace(destination)
        report[destination.name] = {
            'original_bytes': len(original), 'packed_bytes': packed_size,
            'original_sha256': hashlib.sha256(original).hexdigest(),
            'packed_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        }
    (output / 'compression.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upx', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('sources', type=Path, nargs='+')
    args = parser.parse_args()
    pack(args.upx, args.sources, args.output)
