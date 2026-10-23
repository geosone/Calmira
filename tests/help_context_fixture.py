"""Build a test-only binary DFM; never change original Calmira resources."""
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.compile_dfm import compile_dfm


def ident(value):
    raw = value.encode('ascii')
    return bytes([len(raw)]) + raw


def component(cls, name, properties, children=()):
    return ident(cls) + ident(name) + b''.join(
        ident(key) + b'\x04' + struct.pack('<i', value) for key, value in properties
    ) + b'\0' + b''.join(children) + b'\0'


def fixture():
    inner = component('TEdit', 'Inner', [('Width', 120), ('Height', 20), ('HelpContext', 0)])
    panel = component('TCustomControl', 'Panel', [('Top', 30), ('Width', 160),
                      ('Height', 50), ('HelpContext', 65536)], [inner])
    edit = component('TEdit', 'Edit', [('Width', 120), ('Height', 20), ('HelpContext', 901)])
    return b'TPF0' + component('TContextForm', 'ContextForm', [('ClientWidth', 240),
        ('ClientHeight', 130), ('HelpContext', 900)], [edit, panel])


if __name__ == '__main__':
    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(compile_dfm(fixture()), encoding='ascii')
