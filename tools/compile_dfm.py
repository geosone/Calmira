#!/usr/bin/env python3
"""Strict Delphi-1 binary DFM frontend for the supported native Win16 subset.

This is a build-time compiler, not a general VCL streamer. Unsupported behavior
is an error: the original DFM remains the source of layout, values and events.
"""
import argparse
from dataclasses import dataclass, field
import hashlib
import json
from pathlib import Path
import re
import struct
import tempfile

if __package__:
    from .dfm_bitmaps import BitmapResources, bitmap_payload, cancellation_glyph
else:
    from dfm_bitmaps import BitmapResources, bitmap_payload, cancellation_glyph


class DfmError(ValueError):
    pass


@dataclass(frozen=True)
class Value:
    kind: str
    data: object


@dataclass
class Component:
    cls: str
    name: str
    properties: dict = field(default_factory=dict)
    children: list = field(default_factory=list)


IDENT = re.compile(r'[A-Za-z_][A-Za-z_0-9]{0,62}\Z')
RESERVED = frozenset(('and array asm begin case class const constructor destructor div do downto '
                      'else end except exports file finalization finally for function goto if '
                      'implementation in inherited initialization inline interface is label library '
                      'mod nil not object of or packed procedure program property raise record repeat '
                      'set shl shr string then threadvar to try type unit until uses var while with xor '
                      'self aowner acomponent operation dfmarea dfmcreateevent').split())


def identifier(text):
    if not IDENT.fullmatch(text) or text.casefold() in RESERVED:
        raise DfmError(f'invalid Pascal identifier: {text!r}')
    return text


class Reader:
    def __init__(self, data):
        if len(data) > 4 * 1024 * 1024:
            raise DfmError('DFM exceeds 4 MiB')
        self.resource_name = None
        self.data = data
        self.pos = 0
        if not data.startswith(b'TPF0'):
            resource_type = self.resource_id()
            self.resource_name = self.resource_id()
            self.take(2)  # Win16 memory flags, not an arbitrary TPF0 search.
            size = self.number('<I')
            if resource_type != 10 or size != len(data) - self.pos:
                raise DfmError('expected one complete Win16 RCDATA resource')
        if self.take(4) != b'TPF0':
            raise DfmError('missing TPF0 signature')
        self.nodes = self.props = self.values = 0
        self.names = set()

    def take(self, count):
        if count < 0 or count > len(self.data) - self.pos:
            raise DfmError('truncated DFM')
        result = self.data[self.pos:self.pos + count]
        self.pos += count
        return result

    def byte(self):
        return self.take(1)[0]

    def number(self, fmt):
        return struct.unpack(fmt, self.take(struct.calcsize(fmt)))[0]

    def text(self):
        return self.decode(self.take(self.byte()))

    @staticmethod
    def decode(data):
        try:
            result = data.decode('cp1252')
        except UnicodeError as error:
            raise DfmError('invalid Windows-1252 text') from error
        if '\0' in result:
            raise DfmError('embedded NUL in DFM text')
        return result

    def resource_id(self):
        first = self.byte()
        if first == 255:
            return self.number('<H')
        result = bytearray()
        while first:
            result.append(first)
            if len(result) > 255:
                raise DfmError('resource name too long')
            first = self.byte()
        return self.decode(bytes(result))

    def value(self, depth=0):
        self.values += 1
        if depth > 32 or self.values > 4096:
            raise DfmError('DFM value limit exceeded')
        kind = self.byte()
        if kind in (2, 3, 4, 19):
            return Value('integer', self.number({2: '<b', 3: '<h', 4: '<i', 19: '<q'}[kind]))
        if kind in (6, 7):
            return Value('string' if kind == 6 else 'ident', self.text())
        if kind in (8, 9):
            return Value('boolean', kind == 9)
        if kind == 13:
            return Value('nil', None)
        if kind == 11:
            items = []
            while True:
                item = self.text()
                if not item:
                    break
                if len(items) >= 64 or item.casefold() in {s.casefold() for s in items}:
                    raise DfmError('invalid DFM set')
                items.append(identifier(item))
            return Value('set', tuple(items))
        if kind == 1:
            items = []
            while self.data[self.pos:self.pos + 1] != b'\0':
                items.append(self.value(depth + 1))
            self.take(1)
            return Value('list', tuple(items))
        if kind in (10, 12):
            count = self.number('<I')
            if count > 2 * 1024 * 1024:
                raise DfmError('DFM value too large')
            data = self.take(count)
            return Value('binary' if kind == 10 else 'string', data if kind == 10 else self.decode(data))
        if kind in (5, 15, 16, 17):
            return Value('numeric', self.take({5: 10, 15: 4, 16: 8, 17: 8}[kind]))
        raise DfmError(f'unsupported DFM value tag {kind}')

    def component(self, depth=0):
        self.nodes += 1
        if depth > 32 or self.nodes > 256:
            raise DfmError('DFM component limit exceeded')
        cls = identifier(self.text())
        name = identifier(self.text())
        if name.casefold() in self.names:
            raise DfmError(f'duplicate component name: {name}')
        self.names.add(name.casefold())
        result = Component(cls, name)
        while True:
            prop = self.text()
            if not prop:
                break
            for part in prop.split('.'):
                identifier(part)
            key = prop.casefold()
            if key in result.properties:
                raise DfmError(f'duplicate property: {name}.{prop}')
            self.props += 1
            if self.props > 1024:
                raise DfmError('DFM property limit exceeded')
            result.properties[key] = self.value()
        while self.data[self.pos:self.pos + 1] != b'\0':
            result.children.append(self.component(depth + 1))
        self.take(1)
        return result

    def read(self):
        root = self.component()
        if self.pos != len(self.data):
            raise DfmError('trailing DFM data')
        if isinstance(self.resource_name, str) and self.resource_name.casefold() != root.cls.casefold():
            raise DfmError('resource name does not match root class')
        return root


def parse(data):
    return Reader(data).read()


def literal(text):
    raw = text.encode('cp1252')
    if len(raw) > 255 or b'\0' in raw:
        raise DfmError('text exceeds the native 255-byte interface or contains NUL')
    result = []
    run = ''
    for char in raw:
        if 32 <= char <= 126:
            run += chr(char).replace("'", "''")
        else:
            if run:
                result.append("'" + run + "'")
                run = ''
            result.append(f'#{char}')
    if run:
        result.append("'" + run + "'")
    return ''.join(result) or "''"


COMMON = {'left', 'top', 'width', 'height', 'visible', 'enabled', 'taborder', 'tabstop', 'helpcontext',
          'font.name', 'font.height', 'font.color', 'font.style'}
EVENTS = {'tedit': {'onchange', 'onkeydown', 'onkeyup', 'onkeypress', 'onenter', 'onexit'},
          'tbutton': {'onclick'}, 'tcheckbox': {'onclick'}, 'tlabel': set(),
          'tcustomcontrol': {'onkeydown', 'onkeyup', 'onkeypress', 'onenter', 'onexit'}}
PROPERTIES = {'tedit': {'text', 'maxlength', 'readonly', 'passwordchar', 'charcase', 'autoselect'},
              'tbutton': {'caption', 'default', 'cancel', 'modalresult'},
              'tcheckbox': {'caption', 'checked', 'state', 'allowgrayed'},
              'tlabel': {'caption', 'alignment', 'wordwrap', 'showaccelchar', 'color', 'focuscontrol'},
              'tcustomcontrol': {'color'}}
PROPERTIES['tbitbtn'] = PROPERTIES['tbutton'] | {'glyph.data', 'margin', 'spacing', 'numglyphs', 'layout', 'style', 'kind', 'iscontrol'}
PROPERTIES['tpicbtn'] = PROPERTIES['tbitbtn']
PROPERTIES['timage'] = {'picture.data', 'stretch', 'center', 'autosize', 'color'}
EVENTS.update({'tbitbtn': {'onclick'}, 'tpicbtn': {'onclick'}, 'timage': set()})
PROP_NAMES = {p.casefold(): p for p in (
    'Caption', 'Text', 'MaxLength', 'ReadOnly', 'PasswordChar', 'CharCase', 'Default', 'Cancel',
    'ModalResult', 'Checked', 'State', 'AllowGrayed', 'Alignment', 'WordWrap', 'ShowAccelChar',
    'Color', 'Visible', 'Enabled', 'TabStop', 'TabOrder', 'HelpContext', 'OnShow', 'OnHide', 'OnClose',
    'OnCloseQuery', 'OnClick', 'OnChange', 'OnKeyDown', 'OnKeyUp', 'OnKeyPress', 'OnEnter', 'OnExit',
    'Stretch', 'Center', 'AutoSize', 'Margin', 'Spacing', 'NumGlyphs', 'Layout')}
COLORS = frozenset(('clBlack clMaroon clGreen clOlive clNavy clPurple clTeal clGray clSilver clRed '
                    'clLime clYellow clBlue clFuchsia clAqua clWhite clWindow clWindowText '
                    'clBtnFace clBtnText clGrayText clHighlight clHighlightText').split())
ENUMS = {'charcase': {'ecNormal', 'ecUpperCase', 'ecLowerCase'},
         'state': {'cbUnchecked', 'cbChecked', 'cbGrayed'},
         'alignment': {'taLeftJustify', 'taRightJustify', 'taCenter'}}
ENUMS['layout'] = {'blGlyphLeft', 'blGlyphRight', 'blGlyphTop', 'blGlyphBottom'}
ROOT_PROPERTIES = {'left', 'top', 'clientwidth', 'clientheight', 'caption', 'color',
                   'borderstyle', 'bordericons', 'position', 'activecontrol', 'pixelsperinch',
                   'textheight', 'font.name', 'font.height', 'font.color', 'font.style',
                   'oncreate', 'onshow', 'onhide', 'onclose', 'onclosequery', 'helpcontext'}


class Compiler:
    def __init__(self, root):
        self.root = root
        self.lines = []
        self.components = {root.name.casefold(): root}
        self.parents = {}
        self.resources = BitmapResources()
        self.walk(root)

    def fail(self, node, prop, reason='unsupported property'):
        raise DfmError(f'{node.name}.{prop}: {reason}')

    def walk(self, parent):
        for node in parent.children:
            if node.name.casefold() in self.components:
                self.fail(node, 'Name', 'duplicate name')
            self.components[node.name.casefold()] = node
            self.parents[node.name.casefold()] = parent
            if node.cls.casefold() not in PROPERTIES:
                self.fail(node, 'Class', f'unsupported component {node.cls}')
            if node.children and node.cls.casefold() != 'tcustomcontrol':
                self.fail(node, 'Children', 'only TCustomControl containers are supported')
            self.walk(node)

    def typed(self, node, prop, kind, default=None):
        value = node.properties.get(prop)
        if value is None:
            return default
        if value.kind != kind:
            self.fail(node, prop, f'expected {kind}, got {value.kind}')
        return value.data

    def integer(self, node, prop, default=0, minimum=-32768, maximum=32767):
        result = self.typed(node, prop, 'integer', default)
        if not minimum <= result <= maximum:
            self.fail(node, prop, 'integer outside supported bounds')
        return result

    def emit(self, text):
        self.lines.append('  ' + text)

    def value(self, node, prop, value):
        if prop in ENUMS:
            if value.kind != 'ident' or value.data not in ENUMS[prop]:
                self.fail(node, prop, 'unsupported enumeration')
            return value.data
        if prop in ('color', 'font.color'):
            if value.kind == 'ident' and value.data in COLORS:
                return value.data
            if value.kind == 'integer' and -2147483648 <= value.data <= 2147483647:
                return f'Graphics.TColor({value.data})'
            self.fail(node, prop, 'unsupported color')
        if prop in ('caption', 'text', 'font.name', 'passwordchar'):
            if value.kind != 'string':
                self.fail(node, prop, 'expected ANSI string')
            if prop == 'passwordchar' and len(value.data.encode('cp1252')) != 1:
                self.fail(node, prop, 'expected one ANSI character')
            return literal(value.data)
        if prop == 'font.style':
            if value.kind != 'set' or not set(value.data) <= {'fsBold', 'fsItalic', 'fsUnderline', 'fsStrikeOut'}:
                self.fail(node, prop, 'unsupported font style')
            return '[' + ', '.join(value.data) + ']'
        if prop.startswith('on'):
            if value.kind == 'nil':
                return 'nil'
            if value.kind != 'ident':
                self.fail(node, prop, 'expected event method name')
            return identifier(value.data)
        if prop in ('visible', 'enabled', 'tabstop', 'readonly', 'default', 'cancel', 'checked',
                    'allowgrayed', 'wordwrap', 'showaccelchar', 'stretch', 'center', 'autosize'):
            if value.kind != 'boolean':
                self.fail(node, prop, 'expected Boolean')
            return 'True' if value.data else 'False'
        limits = {'maxlength': (1, 255), 'modalresult': (0, 32767), 'taborder': (0, 255),
                  'helpcontext': (0, 2147483647),
                  'font.height': (-32767, 32767), 'margin': (-1, 32767),
                  'spacing': (-1, 32767), 'numglyphs': (1, 4)}
        if prop in limits:
            self.integer(node, prop, minimum=limits[prop][0], maximum=limits[prop][1])
            return str(value.data)
        self.fail(node, prop)

    def caption(self, target, node, value):
        self.emit(f'{target}Caption := FormText({literal(self.root.cls)}, {literal(node.name)}, '
                  f"'Caption', {self.value(node, 'caption', value)});")

    def font(self, target, node):
        for prop in ('font.name', 'font.height', 'font.style', 'font.color'):
            if prop in node.properties:
                self.emit(f'{target}.{prop.split(".")[1].capitalize()} := '
                          f'{self.value(node, prop, node.properties[prop])};')

    def validate(self):
        for node in self.components.values():
            allowed = ROOT_PROPERTIES if node is self.root else COMMON | PROPERTIES[node.cls.casefold()] | EVENTS[node.cls.casefold()]
            if node.cls.casefold() in ('tlabel', 'timage'):
                allowed = allowed - {'taborder', 'tabstop', 'helpcontext'}
            if node.cls.casefold() == 'timage':
                allowed = allowed - {'font.name', 'font.height', 'font.color', 'font.style'}
            for prop in node.properties:
                if prop not in allowed:
                    self.fail(node, prop)
            if self.typed(node, 'autoselect', 'boolean', False):
                self.fail(node, 'AutoSelect', 'automatic selection is not implemented')
            if node.cls.casefold() in ('tbitbtn', 'tpicbtn'):
                if self.typed(node, 'kind', 'ident', 'bkCustom') not in ('bkCustom', 'bkCancel'):
                    self.fail(node, 'Kind', 'only bkCustom and bkCancel are implemented')
                if self.typed(node, 'style', 'ident', 'bsNew') != 'bsNew':
                    self.fail(node, 'Style', 'only native bsNew rendering is supported')
                if not self.typed(node, 'iscontrol', 'boolean', True):
                    self.fail(node, 'IsControl', 'expected control design metadata')
            if node is not self.root:
                if 'width' not in node.properties or 'height' not in node.properties:
                    self.fail(node, 'Bounds', 'explicit width and height required')
                x = self.integer(node, 'left')
                y = self.integer(node, 'top')
                w = self.integer(node, 'width', minimum=0)
                h = self.integer(node, 'height', minimum=0)
                if x + w > 32767 or y + h > 32767:
                    self.fail(node, 'Bounds', 'native coordinate overflow')
        if self.integer(self.root, 'pixelsperinch', 96) != 96:
            self.fail(self.root, 'PixelsPerInch', 'only unscaled 96-DPI resources are supported')
        self.integer(self.root, 'textheight', 13, minimum=1)

    def compile(self, digest):
        self.validate()
        root = self.root
        style = self.typed(root, 'borderstyle', 'ident', 'bsSizeable')
        styles = {'bsDialog': 'WS_POPUP or WS_CAPTION or WS_DLGFRAME',
                  'bsSingle': 'WS_POPUP or WS_CAPTION or WS_BORDER',
                  'bsNone': 'WS_POPUP',
                  'bsSizeable': 'WS_POPUP or WS_CAPTION or WS_THICKFRAME'}
        if style not in styles:
            self.fail(root, 'BorderStyle', 'unsupported border style')
        icons = self.typed(root, 'bordericons', 'set', ('biSystemMenu', 'biMinimize', 'biMaximize'))
        if not set(icons) <= {'biSystemMenu', 'biMinimize', 'biMaximize'}:
            self.fail(root, 'BorderIcons', 'unsupported border icons')
        # Dialog frames never acquire sizing/minimize/maximize controls merely
        # because the designer omitted the inherited BorderIcons default.
        if style == 'bsDialog':
            icons = tuple(icon for icon in icons if icon == 'biSystemMenu')
        flags = styles[style] + ''.join(' or ' + flag for icon, flag in
                                       (('biSystemMenu', 'WS_SYSMENU'), ('biMinimize', 'WS_MINIMIZEBOX'),
                                        ('biMaximize', 'WS_MAXIMIZEBOX')) if icon in icons)
        position = self.typed(root, 'position', 'ident', 'poDesigned')
        if position not in ('poDesigned', 'poScreenCenter'):
            self.fail(root, 'Position', 'unsupported position')
        width = self.integer(root, 'clientwidth', minimum=0)
        height = self.integer(root, 'clientheight', minimum=0)
        if 'clientwidth' not in root.properties or 'clientheight' not in root.properties:
            self.fail(root, 'ClientSize', 'explicit client dimensions required')
        self.lines = [f'{{ Generated from binary DFM; SHA256 {digest}. Do not edit. }}',
                      f'const DfmStyle_{root.cls} = {flags};',
                      f'constructor {root.cls}.Create(AOwner: TComponent);',
                      'var DfmArea: WinTypes.TRect;' + (' DfmCreateEvent: TNotifyEvent;' if 'oncreate' in root.properties else ''),
                      'begin', '  inherited Create(AOwner);']
        self.emit(f'Name := {literal(root.name)};')
        if 'caption' in root.properties:
            self.caption('', root, root.properties['caption'])
        if 'color' in root.properties:
            self.emit(f'Color := {self.value(root, "color", root.properties["color"])};')
        if 'helpcontext' in root.properties:
            self.emit(f'HelpContext := {self.value(root, "helpcontext", root.properties["helpcontext"])};')
        self.font('Canvas.Font', root)
        self.emit(f'DfmArea := Graphics.Rect(0, 0, {width}, {height});')
        self.emit(f'AdjustWindowRect(DfmArea, DfmStyle_{root.cls}, False);')
        if position == 'poScreenCenter':
            left = '(GetSystemMetrics(SM_CXSCREEN) - (DfmArea.Right - DfmArea.Left)) div 2'
            top = '(GetSystemMetrics(SM_CYSCREEN) - (DfmArea.Bottom - DfmArea.Top)) div 2'
        else:
            left = str(self.integer(root, 'left'))
            top = str(self.integer(root, 'top'))
        self.emit(f'SetBounds({left}, {top}, DfmArea.Right - DfmArea.Left, DfmArea.Bottom - DfmArea.Top);')
        for node in list(self.components.values())[1:]:
            target = node.name
            parent = self.parents[target.casefold()]
            parent_target = 'Self' if parent is root else parent.name
            cls = {'tlabel': 'TLabel', 'tedit': 'TEdit', 'tbutton': 'TButton',
                   'tcheckbox': 'TCheckBox', 'tcustomcontrol': 'TCustomControl',
                   'tbitbtn': 'TBitBtn', 'tpicbtn': 'TPicBtn', 'timage': 'TImage'}[node.cls.casefold()]
            self.emit(f'{target} := {cls}.Create(Self);')
            self.emit(f'{target}.Name := {literal(target)}; {target}.Parent := {parent_target};')
            bounds = ', '.join(str(self.integer(node, p, minimum=0 if p in ('width', 'height') else -32768))
                               for p in ('left', 'top', 'width', 'height'))
            self.emit(f'{target}.SetBounds({bounds});')
            if cls != 'TImage':
                font = target + '.Canvas.Font' if cls == 'TCustomControl' else target + '.Font'
                self.emit(f'{font}.Assign({"Canvas.Font" if parent is root else parent.name + ".Canvas.Font"});')
                self.font(font, node)
            if self.typed(node, 'kind', 'ident', 'bkCustom') == 'bkCancel':
                self.emit(f'{target}.Default := False; {target}.Cancel := True; {target}.ModalResult := mrCancel;')
                if 'caption' not in node.properties:
                    self.emit(f"{target}.Caption := FormText({literal(root.cls)}, {literal(target)}, 'Caption', "
                              "FormText('TStandardButtons', 'Cancel', 'Caption', 'Cancel'));")
                self.emit(f'{target}.NumGlyphs := 2;')
                name = self.resources.add(cancellation_glyph())
                self.emit(f"{target}.Glyph.LoadFromResourceName(HInstance, '{name}');")
            # Values precede event assignment: construction must not fire user changes.
            for prop in sorted(node.properties):
                if prop in {'left', 'top', 'width', 'height', 'autoselect', 'taborder', 'kind', 'style', 'iscontrol', 'glyph.data', 'picture.data', 'numglyphs', 'autosize', 'focuscontrol'} or prop.startswith(('font.', 'on')):
                    continue
                if prop == 'caption':
                    self.caption(target + '.', node, node.properties[prop])
                else:
                    self.emit(f'{target}.{PROP_NAMES[prop]} := {self.value(node, prop, node.properties[prop])};')
            # Native loading needs the actual strip before validating frame count.
            for prop, field in (('glyph.data', 'Glyph'), ('picture.data', 'Picture.Bitmap')):
                if prop not in node.properties:
                    continue
                try:
                    payload = bitmap_payload(self.typed(node, prop, 'binary'), picture=prop == 'picture.data')
                except ValueError as error:
                    self.fail(node, prop, str(error))
                if payload is None:
                    self.emit(f'{target}.{"Glyph := nil" if prop == "glyph.data" else "Picture.Graphic := nil"};')
                else:
                    if prop == 'glyph.data':
                        frames = self.integer(node, 'numglyphs', 2 if self.typed(node, 'kind', 'ident', 'bkCustom') == 'bkCancel' else 1, 1, 4)
                        if struct.unpack_from('<i', payload, 4)[0] % frames:
                            self.fail(node, prop, 'strip width is not divisible by NumGlyphs')
                    name = self.resources.add(payload)
                    self.emit(f"{target}.{field}.LoadFromResourceName(HInstance, '{name}');")
            if 'numglyphs' in node.properties:
                self.emit(f'{target}.NumGlyphs := {self.value(node, "numglyphs", node.properties["numglyphs"])};')
            if 'autosize' in node.properties:
                self.emit(f'{target}.AutoSize := {self.value(node, "autosize", node.properties["autosize"])};')
            if cls == 'TPicBtn':
                self.emit(f'{target}.FinishLoading;')
        # Resolve references only after every target, including forward targets.
        for node in self.components.values():
            if 'focuscontrol' not in node.properties:
                continue
            value = node.properties['focuscontrol']
            if value.kind == 'nil':
                target = 'nil'
            else:
                name = self.typed(node, 'focuscontrol', 'ident')
                child = self.components.get(name.casefold())
                if child is None or child is root or child.cls.casefold() in ('tlabel', 'timage'):
                    self.fail(node, 'FocusControl', 'expected windowed descendant')
                target = child.name
            self.emit(f'{node.name}.FocusControl := {target};')
        # Final ordering is independent of object order in the DFM.
        for parent in self.components.values():
            orders = [(self.integer(n, 'taborder', minimum=0, maximum=255), n)
                      for n in parent.children if 'taborder' in n.properties]
            if len({order for order, _ in orders}) != len(orders):
                self.fail(parent, 'TabOrder', 'duplicate sibling tab order')
            for order, node in sorted(orders, key=lambda item: item[0]):
                self.emit(f'{node.name}.TabOrder := {order};')
        active = self.typed(root, 'activecontrol', 'ident')
        if active is not None:
            node = self.components.get(active.casefold())
            if node is None or node is root or node.cls.casefold() in ('tlabel', 'timage'):
                self.fail(root, 'ActiveControl', 'expected windowed descendant')
            self.emit(f'InitialControl := {node.name};')
        for node in self.components.values():
            for prop, value in sorted(node.properties.items()):
                if prop.startswith('on') and prop != 'oncreate':
                    target = '' if node is root else node.name + '.'
                    self.emit(f'{target}{PROP_NAMES[prop]} := {self.value(node, prop, value)};')
        if 'oncreate' in root.properties:
            self.emit(f'DfmCreateEvent := {self.value(root, "oncreate", root.properties["oncreate"])};')
            self.emit('if Assigned(DfmCreateEvent) then DfmCreateEvent(Self);')
        self.lines.extend(['end;', f'procedure {root.cls}.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;',
                           '  X, Y, Width, Height: SmallInt);', 'begin',
                           f'  inherited CreateHandle(Parent, Caption, (Style and not DWORD(WS_OVERLAPPEDWINDOW)) or DfmStyle_{root.cls},',
                           '    X, Y, Width, Height);', 'end;',
                           f'procedure {root.cls}.Notification(AComponent: TComponent; Operation: TOperation);',
                           'begin', '  if Operation = opRemove then', '  begin'])
        for node in list(self.components.values())[1:]:
            self.emit(f'  if AComponent = {node.name} then {node.name} := nil;')
        self.lines.extend(['  end;', '  inherited Notification(AComponent, Operation);', 'end;', ''])
        return '\n'.join(self.lines)


def compile_bundle(data):
    compiler = Compiler(parse(data))
    text = compiler.compile(hashlib.sha256(data).hexdigest())
    return text, compiler.resources.encode()


def compile_dfm(data):
    return compile_bundle(data)[0]


def inventory(directory):
    if not directory.is_dir():
        raise DfmError('inventory source must be an existing directory')
    result = {'supported': [], 'blocked': {}}
    for path in sorted(directory.glob('*.dfm')):
        try:
            compile_dfm(path.read_bytes())
            result['supported'].append(path.name)
        except (OSError, ValueError) as error:
            result['blocked'][path.name] = str(error)
    return result


def write_generated(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() == data:
        return
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name + '.', delete=False) as output:
            temporary = Path(output.name)
            output.write(data)
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--resources', type=Path, help='generated Win16 .RES bitmap sidecar, required for embedded images')
    parser.add_argument('--inventory', action='store_true', help='report supported/rejected files in a directory')
    args = parser.parse_args()
    try:
        if args.output.resolve() == args.source.resolve():
            raise DfmError('output must not overwrite the input resource')
        if args.resources is not None:
            if args.inventory or args.resources.resolve() in (args.source.resolve(), args.output.resolve()):
                raise DfmError('resources must be separate from input/output and require a DFM file')
        if args.inventory:
            text = json.dumps(inventory(args.source), indent=2, sort_keys=True) + '\n'
            resources = b''
        else:
            text, resources = compile_bundle(args.source.read_bytes())
        if resources and args.resources is None:
            raise DfmError('embedded bitmaps require --resources OUTPUT.res and native resource binding')
        encoded = text.encode('ascii')
        if args.resources is not None:
            write_generated(args.resources, resources)
        write_generated(args.output, encoded)
    except (OSError, ValueError, UnicodeError) as error:
        parser.exit(1, f'{args.source}: {error}\n')


if __name__ == '__main__':
    main()
