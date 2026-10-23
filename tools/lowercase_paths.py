#!/usr/bin/env python3
"""Normalize owned source paths; vendor, archives, build and AGENTS stay intact.

Run without arguments to review the plan, then with --apply. Binary contents
are never rewritten. Runtime resource identifiers and generated payload names
are not filename-normalization targets.
"""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OWNED = {'src', 'vcl', 'bmp', 'help', 'docs', 'install', 'tests', 'tools', 'locales', 'assets'}
ROOT_FILES = {'makefile', 'readme.md', 'license', 'release.bat'}


def owned(path):
    return path.parts[0].lower() in OWNED or path.as_posix().lower() in ROOT_FILES


def plan(paths):
    result = {}
    occupied = {}
    for path in paths:
        if not owned(path):
            continue
        target = Path(path.as_posix().lower())
        if target in occupied and occupied[target] != path:
            raise ValueError(f'case collision: {path} and {occupied[target]}')
        occupied[target] = path
        if path != target:
            result[path.as_posix()] = target.as_posix()
    return result


def rewrite(data, relative, mapping, inventory):
    if b'\0' in data:
        return data
    # Latin-1 is a byte-preserving transport, including original CRLF/ANSI.
    text = data.decode('latin1')
    keys = sorted(mapping, key=len, reverse=True)
    if keys:
        pattern = re.compile(r'(?<![A-Za-z0-9_.-])(?:' +
                             '|'.join(re.escape(key) for key in keys) +
                             r')(?![A-Za-z0-9_.-])')

        def replace(match):
            prefix = re.split(r'[\s\"\'`<>]', text[:match.start()])[-1]
            if any(part in prefix.replace('\\', '/') for part in ('vendor/', 'archives/', 'build/')):
                return match[0]
            if '/' not in match[0] and prefix.endswith(('/', '\\')) and not prefix.endswith(('$root/', '$root\\')):
                return match[0]
            return mapping[match[0]]

        text = pattern.sub(replace, text)
        # DOS batch paths use the same names with backslash separators.
        for old, new in mapping.items():
            if '/' in old:
                text = text.replace(old.replace('/', '\\'), new.replace('/', '\\'))
    # Split pathlib expressions such as ROOT / "src" / "locale.pas".
    def pathlib_expression(match):
        expression = match[0]
        names = re.findall(r'[\"\']([^\"\']+)[\"\']', expression)
        path = '/'.join(names)
        if owned(Path(path)) and (path in inventory or path in mapping or names[0] in ('VCL', 'BMP', 'HELP')):
            return re.sub(r'([\"\'])([^\"\']+)([\"\'])',
                          lambda item: item[1] + item[2].lower() + item[3], expression)
        return expression
    text = re.sub(r'ROOT\s*/\s*[\"\'][^\"\']+[\"\'](?:\s*/\s*[\"\'][^\"\']+[\"\'])*',
                  pathlib_expression, text)
    for directory in ('VCL', 'BMP', 'HELP'):
        text = text.replace('-Fu' + directory, '-Fu' + directory.lower())
        text = text.replace('-Fu./' + directory, '-Fu./' + directory.lower())
    if relative.suffix.lower() in ('.pas', '.dpr'):
        text = re.sub(r'(\{\$[RI]\s+)([^}]+)(\})',
                      lambda item: item[1] + item[2].lower() + item[3], text,
                      flags=re.IGNORECASE)
        text = re.sub(r'(\bin\s+\')([^\']+\.pas)(\')',
                      lambda item: item[1] + item[2].lower() + item[3], text,
                      flags=re.IGNORECASE)
    # Relative Markdown links resolve against their owning document.
    text = re.sub(r'\]\(([^)]+)\)', lambda item: '](' +
                  (item[1].lower() if (relative.parent / item[1]).as_posix() in inventory else item[1]) + ')', text)
    return text.encode('latin1')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    raw = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT)
    paths = sorted({Path(name.decode()) for name in raw.split(b'\0') if name})
    paths = [path for path in paths if (ROOT / path).is_file() and not (ROOT / path).is_symlink()]
    mapping = plan(paths)
    for old, new in mapping.items():
        if (ROOT / new).exists() and old != new:
            raise ValueError(f'target already exists: {new}')
        print(f'{old} -> {new}')
    print(f'{len(mapping)} path renames; vendor/archive/build/AGENTS excluded')
    if not args.apply:
        return
    inventory = {path.as_posix() for path in paths}
    for relative in paths:
        if not owned(relative):
            continue
        path = ROOT / relative
        before = path.read_bytes()
        after = rewrite(before, relative, mapping, inventory)
        if before != after:
            path.write_bytes(after)
    for old, new in mapping.items():
        target = ROOT / new
        target.parent.mkdir(parents=True, exist_ok=True)
        (ROOT / old).rename(target)
    directories = {parent for old in mapping for parent in Path(old).parents if parent != Path('.')}
    for directory in sorted(directories, key=lambda path: len(path.parts), reverse=True):
        absolute = ROOT / directory
        if absolute.is_dir() and not any(absolute.iterdir()):
            absolute.rmdir()


if __name__ == '__main__':
    main()
