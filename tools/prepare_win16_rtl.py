#!/usr/bin/env python3
"""Stage tracked RTL sources and scoped Win16 patches without changing the pin."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PATCHES = [ROOT / 'tools/patches' / name for name in (
    'fpc-win16-message-dispatch.patch', 'fpc-win16-exception-tailcall.patch',
    'fpc-win16-gui-stdio.patch', 'fpc-win16-gui-error-buffer.patch',
    'fpc-win16-realloc-bounds.patch', 'fpc-win16-dos-no-strings.patch',
    'fpc-win16-delphi1-strings.patch', 'fpc-win16-huge-startup.patch')]
OVERLAYS = {Path('rtl/win16/calmira_guierr.inc'): ROOT / 'src/win16/rtl_gui_error.inc'}
STAGING_SCHEMA = 2


def prepare(source, output):
    source, output = Path(source).resolve(), Path(output).resolve()
    names = subprocess.check_output(['git', '-C', str(source), 'ls-files', '-z', '--', 'rtl']).split(b'\0')
    paths = [Path(name.decode()) for name in names if name]
    if Path('rtl/inc/objpas.inc') not in paths:
        raise ValueError('FPC source must be a checkout containing the tracked RTL')
    if output == source or source in output.parents:
        raise ValueError('staging output must be outside the source checkout')
    digest = hashlib.sha256()
    digest.update(f'calmira-win16-rtl-stage-{STAGING_SCHEMA}\0'.encode())
    for patch in PATCHES:
        digest.update(patch.name.encode() + b'\0' + patch.read_bytes())
    for destination, origin in OVERLAYS.items():
        digest.update(str(destination).encode() + b'\0' + origin.read_bytes())
    for path in paths:
        digest.update(str(path).encode() + b'\0' + (source / path).read_bytes())
    fingerprint = digest.hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    target = output / ('source-' + fingerprint[:20])
    stamp = target / 'calmira-rtl.json'
    if stamp.exists():
        if json.loads(stamp.read_text())['fingerprint'] != fingerprint:
            raise ValueError('unexpected RTL staging fingerprint')
        return target
    if target.exists():
        raise ValueError(f'incomplete RTL staging directory: {target}')
    with tempfile.TemporaryDirectory(prefix='prepare-', dir=output) as directory:
        stage = Path(directory) / 'source'
        for path in paths:
            destination = stage / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / path, destination)
        for patch in PATCHES:
            subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch)],
                           cwd=stage, check=True, stdout=subprocess.DEVNULL)
        for destination, origin in OVERLAYS.items():
            shutil.copy2(origin, stage / destination)
        revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
        (stage / 'calmira-rtl.json').write_text(json.dumps(
            dict(schema=STAGING_SCHEMA, fingerprint=fingerprint, revision=revision, patches=[p.name for p in PATCHES],
                 overlays={str(path): hashlib.sha256(origin.read_bytes()).hexdigest()
                           for path, origin in OVERLAYS.items()}), indent=2) + '\n')
        stage.rename(target)
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(prepare(args.source, args.output))
