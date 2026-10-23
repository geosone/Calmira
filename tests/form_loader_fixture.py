"""Build the test-only binary DFM for the form loader; never change original resources."""
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.dfm_loader import compile_loader


class Ident(str):
    pass


class Set(tuple):
    pass


def text(value):
    raw = value.encode('cp1252')
    return bytes([len(raw)]) + raw


def value(item):
    if isinstance(item, bool):
        return b'\x09' if item else b'\x08'
    if isinstance(item, int):
        if -128 <= item <= 127:
            return b'\x02' + struct.pack('<b', item)
        if -32768 <= item <= 32767:
            return b'\x03' + struct.pack('<h', item)
        return b'\x04' + struct.pack('<i', item)
    if isinstance(item, Ident):
        return b'\x07' + text(item)
    if isinstance(item, Set):
        return b'\x0b' + b''.join(text(name) for name in item) + b'\0'
    if isinstance(item, list):
        return b'\x01' + b''.join(value(entry) for entry in item) + b'\0'
    if isinstance(item, str):
        return b'\x06' + text(item)
    raise TypeError(item)


def component(cls, name, properties, children=()):
    return (text(cls) + text(name) + b''.join(text(key) + value(item) for key, item in properties)
            + b'\0' + b''.join(children) + b'\0')


def fixture():
    page0 = component('TPage', '', [('Left', 0), ('Top', 0), ('Caption', 'First')], [
        component('TEdit', 'PageEdit', [('Left', 4), ('Top', 4), ('Width', 100), ('Height', 22),
                                         ('TabOrder', 0)])])
    page1 = component('TPage', '', [('Left', 0), ('Top', 0), ('Caption', 'Second')], [
        component('TCheckBox', 'PageCheck', [('Left', 4), ('Top', 4), ('Width', 100), ('Height', 18),
                                              ('Caption', 'On page two'), ('TabOrder', 0)])])
    sub = component('TMenuItem', 'SubItem', [('Caption', 'Sub'), ('OnClick', Ident('OkClick'))])
    menu = component('TPopupMenu', 'Popup', [('Left', 200), ('Top', 8)], [
        component('TMenuItem', 'OpenItem', [('Caption', '&Open')], [sub])])
    children = [
        component('TLabel', 'Title', [('Left', 8), ('Top', 8), ('Width', 60), ('Height', 13),
                                      ('Caption', '&Name:'), ('FocusControl', Ident('NameEdit'))]),
        # Tab orders arrive out of stream order; they are applied sorted.
        component('TEdit', 'NameEdit', [('Left', 72), ('Top', 4), ('Width', 120), ('Height', 22),
                                         ('MaxLength', 20), ('TabOrder', 1), ('Text', 'Calmira'),
                                         ('OnChange', Ident('NameChange'))]),
        component('TButton', 'OkButton', [('Left', 200), ('Top', 4), ('Width', 75), ('Height', 25),
                                           ('Caption', 'OK'), ('Default', True), ('ModalResult', 1),
                                           ('TabOrder', 0), ('OnClick', Ident('OkClick'))]),
        component('TCheckBox', 'Agree', [('Left', 8), ('Top', 36), ('Width', 120), ('Height', 18),
                                          ('Caption', 'Agree'), ('Checked', True), ('Font.Color', Ident('clRed')),
                                          ('Font.Style', Set(('fsBold',))), ('ParentFont', False),
                                          ('TabOrder', 2)]),
        component('TListBox', 'Choices', [('Left', 8), ('Top', 60), ('Width', 120), ('Height', 60),
                                           ('Items.Strings', ['Alpha', 'Beta', 'Gamma']), ('TabOrder', 3),
                                           ('PopupMenu', Ident('Popup'))]),
        component('TBevel', 'Line', [('Left', 8), ('Top', 124), ('Width', 280), ('Height', 4),
                                      ('Shape', Ident('bsBottomLine'))]),
        component('TNotebook', 'Book', [('Left', 136), ('Top', 36), ('Width', 150), ('Height', 84),
                                         ('PageIndex', 1), ('TabOrder', 4)], [page0, page1]),
        component('TProbeBox', 'Box', [('Left', 8), ('Top', 132), ('Width', 40), ('Height', 20),
                                        ('Value', 7), ('TabOrder', 5)]),
        menu,
    ]
    return b'TPF0' + component('TProbeForm', 'ProbeForm', [
        ('Left', 40), ('Top', 30), ('BorderStyle', Ident('bsDialog')), ('Caption', 'Loader probe'),
        ('ClientHeight', 160), ('ClientWidth', 300), ('Font.Height', -11), ('Font.Name', 'MS Sans Serif'),
        ('ActiveControl', Ident('NameEdit')), ('PixelsPerInch', 96), ('OnCreate', Ident('FormCreate')),
        ('OnDestroy', Ident('FormDestroy')), ('TextHeight', 13)], children)


if __name__ == '__main__':
    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    source = (ROOT / 'tests/pascal/form_loader_probe.pas').read_text()
    output.write_text(compile_loader(fixture(), source)[0], encoding='ascii')
