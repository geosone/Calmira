"""Write deliberate INI edge cases to a disposable native guest fixture directory."""
from pathlib import Path
import sys


def create(directory):
    (directory / 'PROBE.LNG').write_bytes(
        ('[Language]\r\nCode=probe\r\n[Forms]\r\nProbe.Empty.Caption=\r\n'
         'Probe.Escapes.Caption=a\\nb\\tc\\\\d\\q\r\n'
         'Probe.Marker.Caption=!missing1!\r\nProbe.Marker2.Caption=!missing2!\r\n'
         'Probe.Long.Caption=' + 'x' * 300 + '\r\n'
         'Probe.Expand.Caption=' + '\\n' * 126 + 'abcd\r\n'
         '[Strings]\r\n1201=probe resource\r\n60000=\r\n'
         '60001=a\\nb\\tc\\\\d\\q\r\n60002=!missing1!\r\n60005=!missing2!\r\n'
         '60003=' + 'x' * 300 + '\r\n60004=' + '\\n' * 126 + 'abcd\r\n').encode('ascii'))


if __name__ == '__main__':
    create(Path(sys.argv[1]))
