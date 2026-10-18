#!/usr/bin/env python3
"""Compare the imported Calmira source trees without modifying them."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "vendor" / "upstream"
SOURCE_ROOTS = {
    "1.0": "calmira-1.0/SOURCE",
    "2.0": "calmira-2.0/SOURCE",
    "2.2": "calmira-2.2/SOURCE",
    "3.02": "calmira-3.02",
    "3.1b3": "calmira-3.1b3",
    "3.2": "calmira-3.2",
    "3.3": "calmira-3.3",
    "3.3-de": "calmira-de-3.3",
    "3.3-fr": "calmira-fr-3.3",
    "lfn-3.3": "calmira-lfn-3.3",
    "lfn-de": "calmira-lfn-de",
    "xp-3.33": "calmira-xp-3.33/SOURCE",
    "reborn": "calmira-reborn",
}
SOURCE_SUFFIXES = {
    ".asm", ".bat", ".c", ".dfm", ".dpr", ".h", ".inc", ".ini",
    ".iss", ".pas", ".rc", ".txt",
}


def normalized_digest(path: Path) -> str:
    data = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return hashlib.sha256(data).hexdigest()


def inventory(name: str) -> dict[str, tuple[str, str]]:
    root = UPSTREAM / SOURCE_ROOTS[name]
    files: dict[str, tuple[str, str]] = {}
    for path in root.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix.lower() not in SOURCE_SUFFIXES:
            continue
        relative = path.relative_to(root).as_posix()
        key = relative.casefold()
        if key in files:
            raise RuntimeError(f"case-insensitive path collision in {name}: {relative}")
        files[key] = (relative, normalized_digest(path))
    return files


def compare(base: dict[str, tuple[str, str]], other: dict[str, tuple[str, str]]):
    shared = base.keys() & other.keys()
    same = sum(base[key][1] == other[key][1] for key in shared)
    changed = len(shared) - same
    return same, changed, len(other.keys() - base.keys()), len(base.keys() - other.keys())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", choices=SOURCE_ROOTS, default="reborn")
    parser.add_argument("--details", choices=SOURCE_ROOTS)
    args = parser.parse_args()

    base = inventory(args.base)
    print(f"Base: {args.base} ({len(base)} source/text files)\n")
    print("| Version | Files | Identical | Changed | Only version | Only base |")
    print("|---|---:|---:|---:|---:|---:|")
    for name in SOURCE_ROOTS:
        if name == args.base:
            continue
        other = inventory(name)
        same, changed, only_other, only_base = compare(base, other)
        print(f"| {name} | {len(other)} | {same} | {changed} | {only_other} | {only_base} |")

    if args.details:
        other = inventory(args.details)
        print(f"\nFiles unique to {args.details}:")
        for key in sorted(other.keys() - base.keys()):
            print(other[key][0])
        print(f"\nFiles unique to {args.base}:")
        for key in sorted(base.keys() - other.keys()):
            print(base[key][0])
        print(f"\nFiles changed in {args.details}:")
        for key in sorted(base.keys() & other.keys()):
            if base[key][1] != other[key][1]:
                print(other[key][0])


if __name__ == "__main__":
    main()
