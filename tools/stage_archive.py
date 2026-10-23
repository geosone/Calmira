#!/usr/bin/env python3
"""Stage the independent OpenLFN Loader payload using DOS-safe filenames."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PAYLOAD = {
    'OLFNHOOK.DLL': 'win16/clfnhook/OLFNHOOK.DLL',
    'OLFNLOAD.EXE': 'win16/clfnhook/OLFNLOAD.EXE',
    'OLFNVIEW.EXE': 'win16/archive/OLFNVIEW.EXE',
    'OLFNLIST.EXE': 'win16/archive/OLFNLIST.EXE',
    'LICENSES/GPL3.TXT': 'win16/archive/GPL-3.0.txt',
    'LICENSES/7ZIP.TXT': 'win16/archive/7ZIP-LICENSE.txt',
    'LICENSES/LGPL21.TXT': 'win16/archive/7ZIP-LGPL.txt',
    'LICENSES/DOS32A.TXT': 'win16/archive/DOS32A-LICENSE.txt',
}


def stage_archive(build, output, installer=None, root=ROOT):
    """Preflight every input before writing; never replace a build artifact."""
    sources = {name: build / source for name, source in PAYLOAD.items()}
    sources['ARCINFO.TXT'] = root / 'install/archive.txt'
    if installer is not None:
        sources['INSTALL.EXE'] = installer
        sources['INSTALL.INI'] = root / 'install/archive.ini'
    output = output.resolve()
    for source in sources.values():
        if not source.is_file():
            raise FileNotFoundError(f'Missing {source}; build archive-viewer clfn-hook and GDI first')
        # Reject output trees containing any inputs, including symlink aliases.
        if source.resolve().is_relative_to(output):
            raise ValueError('package output must be separate from its inputs')
    destinations = {name: output / name for name in sources}
    for destination in destinations.values():
        # A pre-existing package symlink must not redirect a write elsewhere.
        if destination.resolve() != destination:
            raise ValueError(f'package symlinks are not supported: {destination}')
        if destination.exists() and not destination.is_file():
            raise ValueError(f'not a regular output file: {destination}')
    for name, source in sources.items():
        destination = destinations[name]
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    return destinations


def archive_package(files, output):
    """Create a deterministic binary bundle from the explicit staged manifest."""
    output = output.absolute()
    if output.is_symlink() or any(path.resolve() == output.resolve() for path in files.values()):
        raise ValueError('archive must not overwrite a symlink or package input')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='openlfn-dist-', dir=output.parent) as temporary:
        candidate = Path(temporary) / output.name
        with zipfile.ZipFile(candidate, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
            for name, path in sorted(files.items()):
                info = zipfile.ZipInfo('OPENLFN/' + name, date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 0
                info.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(info, path.read_bytes())
        digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
        candidate.replace(output)
    return digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, default=ROOT / 'build')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--installer', type=Path)
    parser.add_argument('--archive', type=Path, help='also create a deterministic standalone ZIP')
    args = parser.parse_args()
    if args.archive and not args.installer:
        parser.error('--archive requires --installer')
    try:
        files = stage_archive(args.build, args.output, args.installer)
        if args.archive:
            digest = archive_package(files, args.archive)
            print(f'{digest}  {args.archive.name}')
    except (OSError, ValueError) as error:
        parser.exit(1, f'{error}\n')
    print(f'OpenLFN Loader payload: {len(files)} files in {args.output}')


if __name__ == '__main__':
    main()
