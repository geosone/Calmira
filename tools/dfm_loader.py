#!/usr/bin/env python3
"""Generate a Win16 form-loader unit from a Delphi 1 binary DFM.

The loader replaces Delphi's runtime DFM streaming for Forms.TForm
descendants. It creates every component as the form's field, assigns values
in stream order and wires references and events afterwards. Property names
and values are passed through to Pascal, so the Free Pascal compiler checks
them against the ported classes: a property the port lacks is a compile
error, never a silent omission.
"""
import argparse
import hashlib
from pathlib import Path
import re
import struct
import sys

if __package__:
    from .compile_dfm import DfmError, header_sections, identifier, literal, parse, write_generated
    from .dfm_bitmaps import BitmapResources, bitmap_payload
else:
    from compile_dfm import DfmError, header_sections, identifier, literal, parse, write_generated
    from dfm_bitmaps import BitmapResources, bitmap_payload

# Designer metadata with no run-time meaning.
DESIGN_ONLY = {'textheight', 'iscontrol', 'scaled'}
BOUNDS = ('left', 'top', 'width', 'height')
TRANSLATED = {'caption', 'hint'}
MENUS = {'tpopupmenu', 'tmainmenu'}


def strip_source(text):
    """Remove comments, keeping {$IFDEF FPC}-style branches for FPC on Win16."""
    defined = {'FPC', 'WIN16'}
    result = []
    stack = []
    active = True
    pos = 0
    token = re.compile(r"\{\$(\w+)\s*(\w*)[^}]*\}|\{[^}]*\}|\(\*.*?\*\)|//[^\n]*|'(?:[^']|'')*'", re.S)
    while True:
        match = token.search(text, pos)
        chunk = text[pos:match.start() if match else len(text)]
        if active:
            result.append(chunk)
        if not match:
            break
        pos = match.end()
        directive = (match.group(1) or '').upper()
        name = (match.group(2) or '').upper()
        if directive in ('IFDEF', 'IFNDEF'):
            stack.append(active)
            active = active and ((name in defined) == (directive == 'IFDEF'))
        elif directive == 'ELSE':
            if not stack:
                raise DfmError('unbalanced {$ELSE} in form unit')
            active = stack[-1] and not active
        elif directive == 'ENDIF':
            if not stack:
                raise DfmError('unbalanced {$ENDIF} in form unit')
            active = stack.pop()
        elif match.group(0).startswith("'") and active:
            result.append("''")
        else:
            result.append(' ')
    if stack:
        raise DfmError('unterminated conditional in form unit')
    return ''.join(result)


def unit_uses(text):
    """Every unit a form unit names in its uses clauses, in order."""
    source = strip_source(text)
    result = []
    for clause in re.findall(r'\buses\b(.*?);', source, re.S | re.I):
        for item in clause.split(','):
            name = item.split()[0] if item.split() else ''
            identifier(name)
            if name.casefold() not in {n.casefold() for n in result}:
                result.append(name)
    unit = re.search(r'^\s*unit\s+(\w+)\s*;', source, re.I | re.M)
    if unit is None:
        raise DfmError('form source is not a unit')
    return unit.group(1), result


class Loader:
    def __init__(self, root):
        self.root = root
        self.lines = []
        self.resources = BitmapResources()
        self.components = {}
        self.references = []
        self.events = []
        self.orders = {}
        self.pages = 0
        self.collect(root)

    def fail(self, node, prop, reason):
        raise DfmError(f'{node.name or node.cls}.{prop}: {reason}')

    def collect(self, parent):
        for node in parent.children:
            if node.name:
                if node.name.casefold() in self.components or node.name.casefold() == self.root.name.casefold():
                    self.fail(node, 'Name', 'duplicate name')
                self.components[node.name.casefold()] = node
            self.collect(node)

    def emit(self, text):
        self.lines.append('  ' + text)

    def scalar(self, node, prop, value):
        if value.kind == 'integer':
            if not -2147483648 <= value.data <= 2147483647:
                self.fail(node, prop, 'integer outside 32-bit range')
            return str(value.data)
        if value.kind == 'boolean':
            return 'True' if value.data else 'False'
        if value.kind == 'string':
            return literal(value.data)
        if value.kind == 'ident':
            return identifier(value.data)
        if value.kind == 'set':
            return '[' + ', '.join(value.data) + ']'
        if value.kind == 'nil':
            return 'nil'
        self.fail(node, prop, f'unsupported {value.kind} value')

    def text(self, node, key, value):
        if value.kind != 'string':
            self.fail(node, key, 'expected ANSI string')
        if not node.name:
            return literal(value.data)
        return (f'FormText({literal(self.root.cls)}, {literal(node.name)}, '
                f'{literal(node.spelling[key])}, {literal(value.data)})')

    def target(self, node):
        return 'F' if node is self.root else 'F.' + node.name

    def is_reference(self, value):
        return value.kind == 'ident' and value.data.casefold() in self.components

    def properties(self, node, target):
        for key, value in node.properties.items():
            spelled = node.spelling[key]
            if key in BOUNDS and node is not self.root or key in DESIGN_ONLY:
                continue
            if key == 'pixelsperinch':
                if node is not self.root or value.kind != 'integer' or value.data != 96:
                    self.fail(node, spelled, 'only unscaled 96-DPI resources are supported')
                continue
            if key.startswith('on'):
                if value.kind == 'nil':
                    continue
                if value.kind != 'ident':
                    self.fail(node, spelled, 'expected event method name')
                self.events.append(f'{target}.{spelled} := F.{identifier(value.data)};')
            elif key == 'taborder':
                if value.kind != 'integer' or not 0 <= value.data <= 255:
                    self.fail(node, spelled, 'expected tab order 0..255')
                self.orders.setdefault(id(self.parent_of[id(node)]), []).append((value.data, node))
            elif key == 'visible' and node is self.root:
                # Delphi shows the form only after OnCreate.
                if value.kind != 'boolean':
                    self.fail(node, spelled, 'expected Boolean')
                if value.data:
                    self.events.append('ShowAfterCreate(F);')
            elif key == 'activecontrol' and node is self.root:
                if not self.is_reference(value):
                    self.fail(node, spelled, 'expected a component name')
                self.references.append(f'F.InitialControl := F.{self.components[value.data.casefold()].name};')
            elif self.is_reference(value):
                self.references.append(f'{target}.{spelled} := F.{self.components[value.data.casefold()].name};')
            elif key in TRANSLATED:
                self.emit(f'{target}.{spelled} := {self.text(node, key, value)};')
            elif key.endswith('.strings'):
                if value.kind != 'list' or any(item.kind != 'string' for item in value.data):
                    self.fail(node, spelled, 'expected a string list')
                owner = spelled.rsplit('.', 1)[0]
                self.emit(f'{target}.{owner}.Clear;')
                for index, item in enumerate(value.data):
                    text = literal(item.data) if not node.name else (
                        f'FormText({literal(self.root.cls)}, {literal(node.name)}, '
                        f"{literal(f'{spelled}.{index}')}, {literal(item.data)})")
                    self.emit(f'{target}.{owner}.Add({text});')
            elif key == 'sections.sections':
                try:
                    sections = header_sections(value)
                except DfmError as error:
                    self.fail(node, spelled, str(error))
                self.emit(f'{target}.Sections.Clear;')
                for index, (width, text) in enumerate(sections):
                    self.emit(f'{target}.Sections.Add({literal(text)}); {target}.SectionWidth[{index}] := {width};')
            elif key == 'linkinfo':
                # TDdeClientConv's DefineProperties list: 'Service X', 'Topic Y'.
                if value.kind != 'list' or any(item.kind != 'string' for item in value.data):
                    self.fail(node, spelled, 'expected a string list')
                for item in value.data:
                    field, _, text = item.data.partition(' ')
                    if field not in ('Service', 'Topic'):
                        self.fail(node, spelled, f'unsupported link entry {item.data!r}')
                    self.emit(f'{target}.Dde{field} := {literal(text)};')
            elif key == 'data' and value.kind == 'binary':
                # TOutline's DefineProperties data; 1F alone is an empty outline.
                if value.data != b'\x1f':
                    self.fail(node, spelled, 'only empty outline data is supported')
            elif key.endswith('.data') and value.kind == 'binary':
                picture = key == 'picture.data'
                try:
                    payload = bitmap_payload(value.data, picture=picture)
                except ValueError as error:
                    self.fail(node, spelled, str(error))
                field = 'Picture.Bitmap' if picture else spelled.rsplit('.', 1)[0]
                if payload is not None:
                    name = self.resources.add(payload)
                    self.emit(f"{target}.{field}.LoadFromResourceName(HInstance, '{name}');")
            else:
                self.emit(f'{target}.{spelled} := {self.scalar(node, spelled, value)};')

    def create(self, parent, node, parent_target):
        cls = node.cls.casefold()
        if not node.name:
            if cls != 'tpage' or parent.cls.casefold() != 'tnotebook':
                self.fail(node, 'Name', f'unnamed {node.cls} is not supported')
            if set(node.properties) - {'left', 'top', 'caption'}:
                self.fail(node, 'Page', 'only a caption is supported on notebook pages')
            caption = node.properties.get('caption')
            text = self.scalar(node, 'Caption', caption) if caption is not None else "''"
            target = f'TPage({parent_target}.Pages.Objects[{parent_target}.Pages.Add({text})])'
            self.pages += 1
            page = f'DfmPage{self.pages}'
            self.locals.append(page)
            self.emit(f'{page} := {target};')
            return page
        target = 'F.' + node.name
        self.emit(f'{target} := {identifier(node.cls)}.Create(F);')
        self.emit(f'ComponentLoading({target}); {target}.Name := {literal(node.name)};')
        if cls == 'tmenuitem':
            if parent.cls.casefold() in MENUS:
                self.emit(f'{parent_target}.Items.Add({target});')
            elif parent.cls.casefold() == 'tmenuitem':
                self.emit(f'{parent_target}.Add({target});')
            else:
                self.fail(node, 'Parent', 'menu items belong to a menu')
        elif 'width' in node.properties or 'height' in node.properties:
            self.emit(f'{target}.Parent := {parent_target};')
            bounds = []
            for key in BOUNDS:
                value = node.properties.get(key)
                if value is None:
                    bounds.append(f'{target}.{key.capitalize()}')
                elif value.kind != 'integer' or not -32768 <= value.data <= 32767:
                    self.fail(node, key, 'expected a 16-bit coordinate')
                else:
                    bounds.append(str(value.data))
            self.emit(f'{target}.SetBounds({", ".join(bounds)});')
            # Delphi's TNotebook.ReadState drops the default page first.
            if cls == 'tnotebook' and any(not child.name for child in node.children):
                self.emit(f'{target}.Pages.Clear;')
        elif node.children and cls not in MENUS:
            self.fail(node, 'Children', 'only controls and menus contain components')
        return target

    def walk(self, parent, parent_target):
        for node in parent.children:
            self.parent_of[id(node)] = parent
            target = self.create(parent, node, parent_target)
            if node.name:
                self.properties(node, target)
            self.walk(node, target)

    def compile(self, digest, form_unit, uses):
        root = self.root
        self.parent_of = {}
        self.locals = []
        self.lines = []
        self.emit('F := ' + identifier(root.cls) + '(Form);')
        self.emit(f'SetLoadedName(F, {literal(identifier(root.name))});')
        self.properties(root, 'F')
        self.walk(root, 'F')
        self.lines.extend('  ' + line for line in self.references)
        for orders in self.orders.values():
            if len({order for order, _ in orders}) != len(orders):
                self.fail(root, 'TabOrder', 'duplicate sibling tab order')
            for order, node in sorted(orders, key=lambda item: item[0]):
                self.emit(f'F.{node.name}.TabOrder := {order};')
        self.lines.extend('  ' + line for line in self.events)
        names = [form_unit] + [u for u in uses if u.casefold() not in ('forms', 'form_text', form_unit.casefold())]
        unit = form_unit.lower() + '_dfm'
        head = [f'{{ Generated from binary DFM; SHA256 {digest}. Do not edit. }}',
                f'unit {unit};', '{$mode delphi}{$H-}', 'interface', 'implementation',
                'uses ' + ', '.join(names[1:] + ['Forms', 'form_text', form_unit]) + ';',
                'procedure Load(Form: TForm);',
                f'var F: {root.cls};' + ''.join(f' {page}: TPage;' for page in self.locals),
                'begin']
        tail = ['end;', 'initialization', f'  RegisterFormLoader({root.cls}, Load);', 'end.', '']
        return '\n'.join(head + self.lines + tail)


def compile_loader(data, form_source):
    form_unit, uses = unit_uses(form_source)
    loader = Loader(parse(data))
    text = loader.compile(hashlib.sha256(data).hexdigest(), form_unit, uses)
    return text, loader.resources.encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='binary DFM')
    parser.add_argument('--unit', type=Path, required=True, help='Pascal unit declaring the form class')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--resources', type=Path, help='Win16 .RES sidecar, required for embedded images')
    args = parser.parse_args()
    try:
        if args.output.resolve() in (args.source.resolve(), args.unit.resolve()):
            raise DfmError('output must not overwrite an input')
        text, resources = compile_loader(args.source.read_bytes(), args.unit.read_text(encoding='cp1252'))
        if resources and args.resources is None:
            raise DfmError('embedded bitmaps require --resources OUTPUT.res')
        if args.resources is not None:
            write_generated(args.resources, resources)
        write_generated(args.output, text.encode('ascii'))
    except (OSError, ValueError, UnicodeError) as error:
        parser.exit(1, f'{args.source}: {error}\n')


if __name__ == '__main__':
    main()
