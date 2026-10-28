#!/usr/bin/env python3
"""Build shared Win16 language files from historical RC and binary DFM sources,
or from the resources of translated CALMIRA.EXE builds."""
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
# Translations published only as binaries: their string table is numbered by
# the LOCALE.PAS of the English release they were translated from.
BINARIES = {
    'nl': (ROOT / 'vendor/upstream/calmira-nl-3.3/CALMIRA.EXE', ROOT / 'vendor/upstream/calmira-3.3/SRC'),
    'pl': (ROOT / 'vendor/upstream/calmira-pl-3.3/CALMIRA.EXE', ROOT / 'vendor/upstream/calmira-3.3/SRC'),
    'it': (ROOT / 'vendor/upstream/calmira-it-3.2/CALMIRA.EXE', ROOT / 'vendor/upstream/calmira-3.2/SRC'),
    'es': (ROOT / 'vendor/upstream/calmira-es-2.3/CALMIRA.EXE', ROOT / 'vendor/upstream/calmira-2.2/SOURCE/SRC'),
}
# Message translations kept only in a compiled resource file: the German 3.3
# translator edited LOCALE.RES and left LOCALE.RC in English (EXPLAIN.TXT).
RESOURCE_STRINGS = {
    'de': (ROOT / 'vendor/upstream/calmira-de-3.3/SRC/LOCALE.RES', ROOT / 'vendor/upstream/calmira-3.3/SRC'),
}
NAMES = {'en': 'English', 'de': 'Deutsch', 'fr': 'Francais', 'nl': 'Nederlands',
         'pl': 'Polski', 'it': 'Italiano', 'es': 'Espa\u00f1ol'}
CODEPAGES = {'pl': 1250}


class DfmReader:
    def __init__(self, data, properties=(), codepage='cp1252'):
        self.data = data
        self.codepage = codepage
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
        return self.take(self.byte()).decode(self.codepage)

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
                'utf-16le' if kind == 18 else 'utf-8' if kind == 20 else self.codepage)
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


def ne_resources(data):
    """Yield (type, name, data) for each resource of a Win16 NE executable."""
    header = struct.unpack_from('<H', data, 0x3c)[0]
    if data[header:header + 2] != b'NE':
        raise ValueError('not a Win16 NE executable')
    table = header + struct.unpack_from('<H', data, header + 0x24)[0]
    shift = struct.unpack_from('<H', data, table)[0]

    def name(value):
        if value & 0x8000:
            return value & 0x7fff
        size = data[table + value]
        return data[table + value + 1:table + value + 1 + size].decode('latin-1')

    pos = table + 2
    while True:
        kind, count = struct.unpack_from('<HH', data, pos)
        if kind == 0:
            return
        pos += 8
        for _ in range(count):
            offset, length, _flags, ident = struct.unpack_from('<HHHH', data, pos)
            pos += 12
            yield name(kind), name(ident), data[offset << shift:(offset << shift) + (length << shift)]


def res_resources(data):
    """Yield (type, name, data) for each resource of a Win16 .RES file."""
    def name(pos):
        if data[pos] == 0xff:
            return struct.unpack_from('<H', data, pos + 1)[0], pos + 3
        end = data.index(b'\0', pos)
        return data[pos:end].decode('latin-1'), end + 1

    pos = 0
    while pos < len(data):
        kind, pos = name(pos)
        ident, pos = name(pos)
        size = struct.unpack_from('<I', data, pos + 2)[0]
        pos += 6
        yield kind, ident, data[pos:pos + size]
        pos += size


def string_names(english):
    """String resource numbers to their names in that release's LOCALE.PAS."""
    locale = next(path for path in english.iterdir() if path.name.lower() == 'locale.pas')
    return {int(number): name for name, number in
            re.findall(r'^\s*(S\w+)\s*=\s*(\d+)\s*;', locale.read_text(encoding='latin-1'), re.M)}


def resource_catalogue(resources, english, codepage):
    """Strings by LOCALE.PAS name and form texts from translated resources."""
    names = string_names(english)
    strings, forms = {}, {}
    for kind, ident, raw in resources:
        if kind == 6:
            pos = 0
            for index in range(16):
                size = raw[pos]
                number = (ident - 1) * 16 + index
                if size and number in names:
                    strings[names[number]] = raw[pos + 1:pos + 1 + size].decode(codepage)
                pos += 1 + size
        elif kind == 10 and raw.startswith(b'TPF0'):
            DfmReader(raw, codepage=codepage).component(forms)
    return strings, forms


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
        if code in RESOURCE_STRINGS:
            resource, english = RESOURCE_STRINGS[code]
            strings.update(resource_catalogue(res_resources(resource.read_bytes()), english, 'cp1252')[0])
        forms = {}
        for path in sorted(path for path in directory.iterdir() if path.suffix.lower() == '.dfm'):
            DfmReader(path.read_bytes()).component(forms)
        catalogues[code] = {'Strings': {ids[k]: v for k, v in strings.items() if k in ids},
                            'Forms': forms}
    for code, (executable, english) in BINARIES.items():
        strings, forms = resource_catalogue(ne_resources(executable.read_bytes()), english,
                                            f'cp{CODEPAGES.get(code, 1252)}')
        catalogues[code] = {'Strings': {ids[k]: v for k, v in strings.items() if k in ids},
                            'Forms': forms}
    extras = json.loads((ROOT / 'locales/extra.json').read_text())
    report = {}
    for code, sections in catalogues.items():
        codepage = CODEPAGES.get(code, 1252)
        for section, entries in extras.get(code, {}).items():
            sections.setdefault(section, {}).update(entries)
        translated = 0
        omitted = []
        lines = ['[Language]', f'Code={code}', f'Name={NAMES[code]}', f'CodePage={codepage}', '']
        for section, values in sections.items():
            lines.append(f'[{section}]')
            baseline = catalogues['en'].get(section, {})
            for key, value in sorted(values.items()):
                if code != 'en' and key in baseline and placeholders(value) != placeholders(baseline[key]):
                    omitted.append(f'{section}.{key}: format mismatch')
                    continue
                line = f'{key}={escape(value)}'
                if (len(line.encode(f'cp{codepage}')) > 250 or
                        len(value.replace('\n', '\r\n').encode(f'cp{codepage}')) > 250):
                    omitted.append(f'{section}.{key}: exceeds Win16 short-string limit')
                    continue
                lines.append(line)
                translated += 1
            lines.append('')
        (output / f'{code}.LNG').write_bytes(('\r\n'.join(lines) + '\r\n').encode(f'cp{codepage}'))
        report[code] = {'entries': translated, 'omitted': omitted}
    (output / 'coverage.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({code: info['entries'] for code, info in report.items()}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/lang')
    build(parser.parse_args().output)
