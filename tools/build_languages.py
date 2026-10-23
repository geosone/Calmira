#!/usr/bin/env python3
"""Build shared Win16 language files from historical RC and binary DFM sources."""
import argparse
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'en': ROOT / 'src',
    'de': ROOT / 'vendor/upstream/calmira-lfn-de/SRC',
    'fr': ROOT / 'vendor/upstream/calmira-fr-3.3/SRC',
}
NAMES = {'en': 'English', 'de': 'Deutsch', 'fr': 'Francais'}


class DfmReader:
    def __init__(self, data, properties=()):
        self.data = data
        self.pos = data.index(b'TPF0') + 4
        self.properties = frozenset(properties)

    def take(self, size):
        result = self.data[self.pos:self.pos + size]
        if len(result) != size:
            raise ValueError('truncated DFM')
        self.pos += size
        return result

    def byte(self):
        return self.take(1)[0]

    def text(self):
        return self.take(self.byte()).decode('cp1252')

    def value(self):
        kind = self.byte()
        if kind in (0, 8, 9, 13):
            return None
        if kind in (2, 3, 4):
            size, fmt = {2: (1, '<b'), 3: (2, '<h'), 4: (4, '<i')}[kind]
            return struct.unpack(fmt, self.take(size))[0]
        if kind in (5, 15, 16, 17, 19):
            self.take({5: 10, 15: 4, 16: 8, 17: 8, 19: 8}[kind])
            return None
        if kind in (6, 7):
            return self.text()
        if kind in (10, 12, 18, 20):
            count = struct.unpack('<I', self.take(4))[0]
            raw = self.take(count * (2 if kind == 18 else 1))
            return None if kind == 10 else raw.decode(
                'utf-16le' if kind == 18 else 'utf-8' if kind == 20 else 'cp1252')
        if kind == 1:
            items = []
            while self.data[self.pos]:
                items.append(self.value())
            self.byte()
            return items
        if kind == 11:
            while self.text():
                pass
            return None
        if kind == 14:
            while self.byte():
                while self.text():
                    self.value()
            return None
        raise ValueError(f'unsupported DFM value type {kind}')

    def component(self, result, root_class=None):
        cls = self.text()
        name = self.text()
        root_class = root_class or cls
        while True:
            prop = self.text()
            if not prop:
                break
            value = self.value()
            key = f'{root_class}.{name}.{prop}'
            if prop in self.properties:
                result[key] = value
            if prop in ('Caption', 'Hint') and isinstance(value, str):
                result[key] = value
            if prop in ('Items.Strings', 'Tabs.Strings', 'Pages.Strings') and isinstance(value, list):
                for index, text in enumerate(value):
                    if isinstance(text, str):
                        result[f'{key}.{index}'] = text
        while self.data[self.pos]:
            self.component(result, root_class)
        self.byte()


def resource_strings(directory):
    resource = next(path for path in directory.iterdir() if path.name.lower() == 'locale.rc')
    raw = resource.read_text(encoding='cp1252')
    result = {}
    entries = list(re.finditer(r'^\s*(S\w+)\s*,', raw, re.M))
    for index, match in enumerate(entries):
        end = entries[index + 1].start() if index + 1 < len(entries) else len(raw)
        parts = re.findall(r'"((?:\\.|[^"\\])*)"', raw[match.end():end])
        result[match[1]] = ''.join(json.loads('"' + part + '"') for part in parts)
    return result


def placeholders(value):
    return re.findall(r'%(?:\d+:)?[-\d.*]*[a-z]', value.lower().replace('%%', ''))


def escape(value):
    return value.replace('\\', '\\\\').replace('\r\n', '\n').replace('\r', '\n').replace('\n', '\\n').replace('\t', '\\t')


def build(output):
    output.mkdir(parents=True, exist_ok=True)
    ids = dict(re.findall(r'^\s*(S\w+)\s*=\s*(\d+)\s*;',
                          (ROOT / 'src/locale.pas').read_text(), re.M))
    catalogues = {}
    for code, directory in SOURCES.items():
        strings = resource_strings(directory)
        forms = {}
        for path in sorted(path for path in directory.iterdir() if path.suffix.lower() == '.dfm'):
            DfmReader(path.read_bytes()).component(forms)
        catalogues[code] = {'Strings': {ids[k]: v for k, v in strings.items() if k in ids},
                            'Forms': forms}
    extras = json.loads((ROOT / 'locales/extra.json').read_text())
    report = {}
    for code, sections in catalogues.items():
        for section, entries in extras[code].items():
            sections.setdefault(section, {}).update(entries)
        translated = 0
        omitted = []
        lines = ['[Language]', f'Code={code}', f'Name={NAMES[code]}', 'CodePage=1252', '']
        for section, values in sections.items():
            lines.append(f'[{section}]')
            baseline = catalogues['en'].get(section, {})
            for key, value in sorted(values.items()):
                if code != 'en' and key in baseline and placeholders(value) != placeholders(baseline[key]):
                    omitted.append(f'{section}.{key}: format mismatch')
                    continue
                line = f'{key}={escape(value)}'
                if len(line.encode('cp1252')) > 250 or len(value.replace('\n', '\r\n').encode('cp1252')) > 250:
                    omitted.append(f'{section}.{key}: exceeds Win16 short-string limit')
                    continue
                lines.append(line)
                translated += 1
            lines.append('')
        (output / f'{code}.LNG').write_bytes(('\r\n'.join(lines) + '\r\n').encode('cp1252'))
        report[code] = {'entries': translated, 'omitted': omitted}
    (output / 'coverage.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({code: info['entries'] for code, info in report.items()}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/lang')
    build(parser.parse_args().output)
