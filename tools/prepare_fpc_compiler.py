#!/usr/bin/env python3
"""Stage the pinned compiler and bootstrap RTL without modifying the checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PATCHES = (ROOT / 'tools/patches/fpc-i8086-class-pointer-compare.patch',
           ROOT / 'tools/patches/fpc-i8086-huge-resourcestrings.patch',
           ROOT / 'tools/patches/fpc-i8086-far-external-wrapper.patch',
           ROOT / 'tools/patches/fpc-i8086-delphi-assembler-pascal.patch',
           ROOT / 'tools/patches/fpc-win16-dll-startup-object.patch',
           ROOT / 'tools/patches/fpc-win16-export-names-upper.patch')
BUILDER = ROOT / 'tools/build_fpc_class_pointer.sh'


def prepare(source, output, build_id):
    source, output = Path(source).resolve(), Path(output).resolve()
    if output == source or source in output.parents:
        raise ValueError('compiler staging output must be outside the source checkout')
    names = subprocess.check_output([
        'git', '-C', str(source), 'ls-files', '-z', '--',
        'compiler', 'rtl', 'Makefile', 'Makefile.fpc', 'LICENSE']).split(b'\0')
    paths = [Path(name.decode()) for name in names if name]
    for required in ('compiler/i8086/n8086add.pas', 'compiler/i8086/n8086ld.pas',
                     'compiler/i8086/hlcgcpu.pas', 'compiler/pstatmnt.pas',
                     'compiler/systems/t_win16.pas', 'compiler/Makefile',
                     'rtl/Makefile', 'Makefile', 'LICENSE'):
        if Path(required) not in paths:
            raise ValueError('incomplete tracked Free Pascal source checkout')
    digest = hashlib.sha256(b'calmira-fpc-compiler-stage-2\0')
    digest.update(build_id.encode() + b'\0' + BUILDER.read_bytes())
    for patch in PATCHES:
        digest.update(b'\0' + patch.name.encode() + b'\0' + patch.read_bytes())
    for path in paths:
        digest.update(str(path).encode() + b'\0' + (source / path).read_bytes())
    fingerprint = digest.hexdigest()
    output.mkdir(parents=True, exist_ok=True)
    target = output / ('source-' + fingerprint[:20])
    marker = target / 'calmira-compiler.json'
    if marker.exists():
        if json.loads(marker.read_text())['fingerprint'] != fingerprint:
            raise ValueError('unexpected compiler staging fingerprint')
        return target
    if target.exists():
        raise ValueError('incomplete compiler staging directory')
    with tempfile.TemporaryDirectory(prefix='prepare-', dir=output) as directory:
        stage = Path(directory) / 'source'
        for path in paths:
            destination = stage / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / path, destination)
        for patch in PATCHES:
            subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(patch)],
                           cwd=stage, check=True, stdout=subprocess.DEVNULL)
        revision = subprocess.check_output(
            ['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
        (stage / marker.name).write_text(json.dumps(dict(
            schema=2, fingerprint=fingerprint, revision=revision, build_id=build_id,
            patches={patch.name: hashlib.sha256(patch.read_bytes()).hexdigest() for patch in PATCHES},
            builder_sha256=hashlib.sha256(BUILDER.read_bytes()).hexdigest()), indent=2) + '\n')
        stage.rename(target)
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--build-id', required=True)
    args = parser.parse_args()
    print(prepare(args.source, args.output, args.build_id))
