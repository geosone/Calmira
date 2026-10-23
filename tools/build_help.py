#!/usr/bin/env python3
"""Build and audit Calmira's Windows 3.1 WinHelp from maintained RTF sources."""
import argparse
import importlib.util
import io
import json
import os
import re
from pathlib import Path
import shutil
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('calmira_whc', ROOT / 'vendor/build-deps/open386max-whc/whc.py')
WHC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(WHC)
LANG_SPEC = importlib.util.spec_from_file_location('help_dfm', ROOT / 'tools/build_languages.py')
LANG = importlib.util.module_from_spec(LANG_SPEC)
LANG_SPEC.loader.exec_module(LANG)


def literal_help_jumps(text):
    # Keep strings atomic so examples in comments or quoted text are not calls.
    tokens = re.findall(r"\{.*?\}|\(\*.*?\*\)|//[^\r\n]*|'(?:''|[^'])*'|[A-Za-z_]\w*|[^\s]",
                        text, re.S)
    tokens = [token for token in tokens if not token.startswith(('{', '(*', '//'))]
    for index in range(len(tokens) - 5):
        call = tokens[index:index + 6]
        if ([value.lower() for value in call[:4]] == ['application', '.', 'helpjump', '(']
                and call[4].startswith("'") and call[5] == ')'):
            yield call[4][1:-1].replace("''", "'")


def audit_help_calls(data, directory=ROOT / 'src'):
    """Validate explicit form contexts/files and literal Application.HelpJump calls.

    Inherited context zero and runtime-computed exception contexts are not
    statically resolvable; this is not full-shell GUI acceptance.
    """
    helpfile = WHC.HelpFile(data)
    maps = helpfile.file('|CTXOMAP')
    numbers = {struct.unpack_from('<i', maps, 2 + index * 8)[0]
               for index in range(struct.unpack_from('<H', maps)[0])}
    hashes = {key for key, offset in WHC.read_btree(
        helpfile.file('|CONTEXT'), WHC.Reader.s32, WHC.Reader.u32)}
    counts = dict(form_help_contexts=0, form_help_files=0, literal_help_jumps=0)
    for path in sorted(directory.glob('*.dfm')):
        values = {}
        LANG.DfmReader(path.read_bytes(), ('HelpContext', 'HelpFile')).component(values)
        for key, value in values.items():
            if key.endswith('.HelpContext'):
                if not isinstance(value, int) or (value != 0 and value not in numbers):
                    raise ValueError(f'{path.name}: unmapped {key}={value}')
                counts['form_help_contexts'] += 1
            elif key.endswith('.HelpFile') and value:
                if not isinstance(value, str) or value.lower() != 'calmira.hlp':
                    raise ValueError(f'{path.name}: unexpected help filename {value}')
                counts['form_help_files'] += 1
    for path in sorted(directory.glob('*.pas')):
        text = path.read_text(encoding='cp1252')
        for target in literal_help_jumps(text):
            if WHC.ctxhash(target) not in hashes:
                raise ValueError(f'{path.name}: undefined HelpJump target {target}')
            counts['literal_help_jumps'] += 1
    return counts


def check_navigation(graph, contents):
    """Every real topic must be reachable through in-file jumps from Contents."""
    if contents not in graph:
        raise ValueError('contents topic is not defined')
    visited = set()
    pending = [contents]
    while pending:
        topic = pending.pop()
        if topic in visited:
            continue
        if topic not in graph:
            raise ValueError('navigation points outside the topic set')
        visited.add(topic)
        pending.extend(graph[topic] - visited)
    if visited != graph.keys():
        raise ValueError(f'{len(graph.keys() - visited)} help topics unreachable from Contents')
    return len(visited)


def audit(data):
    helpfile = WHC.HelpFile(data)
    records = WHC.read_topics(helpfile.file('|TOPIC'))
    headers = [(index, record) for index, record in enumerate(records) if record[2] == 2]
    offsets = {records[index + 1][1] for index, record in headers[:-1]}
    contexts = WHC.read_btree(helpfile.file('|CONTEXT'), WHC.Reader.s32, WHC.Reader.u32)
    if any(offset not in offsets for key, offset in contexts):
        raise ValueError('context points outside the topic set')
    hashes = {key & 0xffffffff for key, offset in contexts}
    destinations = {key & 0xffffffff: offset for key, offset in contexts}
    graph = {offset: set() for offset in offsets}
    jumps = 0
    current = None
    for index, (pos, off, kind, record) in enumerate(records):
        if kind == 2:
            current = records[index + 1][1] if index + 1 < len(records) else None
        if kind in (0x20, 0x23):
            for item in record[1]:
                if item[0] == 'cmd' and item[1].startswith('jump'):
                    jumps += 1
                    if item[2] not in hashes:
                        raise ValueError('unresolved internal help link')
                    graph[current].add(destinations[item[2]])
    system = WHC.read_system(helpfile.file('|SYSTEM'))
    if system['minor'] != 21 or system['flags'] != 0:
        raise ValueError('expected uncompressed Windows 3.1 help')
    contents = next(struct.unpack('<I', value)[0] for kind, value in system['records'] if kind == 3)
    reachable = check_navigation(graph, contents)
    maps = helpfile.file('|CTXOMAP')
    count = struct.unpack_from('<H', maps)[0]
    for index in range(count):
        number, offset = struct.unpack_from('<iI', maps, 2 + index * 8)
        if offset not in offsets:
            raise ValueError(f'missing numeric context {number}')
    keywords = WHC.read_btree(helpfile.file('|KWBTREE'), WHC.Reader.sz,
                              lambda reader: (reader.u16(), reader.u32()))
    kwdata = helpfile.file('|KWDATA')
    for word, (length, offset) in keywords:
        if any(value not in offsets for value in struct.unpack_from(f'<{length}I', kwdata, offset)):
            raise ValueError('keyword points outside the topic set')
    pictures = {name for name in helpfile.files if name.startswith('|bm')}
    referenced = set()
    for pos, off, kind, record in records:
        if kind in (0x20, 0x23):
            for item in record[1]:
                if item[0] == 'cmd' and item[1] in ('bmc', 'bml', 'bmr'):
                    referenced.add('|' + item[2][1])
    if referenced != pictures:
        raise ValueError('missing or unreferenced bitmap streams')
    return dict(topics=len(headers) - 1, reachable_topics=reachable, contexts=len(contexts), maps=count,
                keywords=len(keywords), links=jumps, pictures=len(pictures),
                tables=sum(record[2] == 0x23 for record in records), bytes=len(data))


def build(output, source=ROOT / 'help'):
    output = Path(output)
    if output.is_symlink() or output.resolve() == (source / 'calmira.hlp').resolve():
        raise ValueError('build output must be separate from maintained help sources')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='help-build.', dir=output.parent) as directory:
        stage = Path(directory)
        for path in source.glob('*.bmp'):
            shutil.copyfile(path, stage / path.name)
        shutil.copyfile(source / 'calmira.hpj', stage / 'calmira.hpj')
        shutil.copyfile(source / 'calmira.rtf', stage / 'calmira0.rtf')
        previous = os.environ.get('SOURCE_DATE_EPOCH')
        os.environ['SOURCE_DATE_EPOCH'] = previous or '946684800'
        log = io.StringIO()
        try:
            count = WHC.compile_project(str(stage / 'calmira.hpj'), str(stage / 'calmira.hlp'), log=log)
        finally:
            if previous is None:
                os.environ.pop('SOURCE_DATE_EPOCH', None)
            else:
                os.environ['SOURCE_DATE_EPOCH'] = previous
        if log.getvalue():
            raise ValueError(log.getvalue())
        data = (stage / 'calmira.hlp').read_bytes()
        report = audit(data)
        report.update(audit_help_calls(data))
        if report['topics'] != count:
            raise ValueError('encoded topic count differs from source')
        os.replace(stage / 'calmira.hlp', output)
        output.with_suffix('.json').write_text(json.dumps(report, indent=2) + '\n')
        return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/help/calmira.hlp')
    args = parser.parse_args()
    try:
        print(json.dumps(build(args.output)))
    except (OSError, ValueError) as error:
        parser.exit(1, f'{error}\n')
