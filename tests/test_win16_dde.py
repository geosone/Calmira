"""DdeMan subset, DDEML bindings and DDE link loading guards."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16DdeTests(unittest.TestCase):
    def test_ddeman_follows_delphi_interface(self):
        source = (ROOT / 'src/win16/ddeman.pas').read_text()
        for text in ('TDataMode = (ddeAutomatic, ddeManual);',
                     'TMacroEvent = procedure(Sender: TObject; Msg: TStrings) of object;',
                     'TDdeClientConv = class(TComponent)', 'TDdeServerConv = class(TComponent)',
                     'function ExecuteMacro(Cmd: PChar; WaitFlg: Boolean): Boolean;',
                     'function RequestData(const Item: string): PChar;',
                     'property ConnectMode: TDataMode read FConnectMode write SetConnectMode default ddeAutomatic;',
                     'property AppName: string read FAppName write SetAppName;',
                     'DdeMgr: TDdeMgr;', 'FCallback := MakeProcInstance(@DdeCallback, HInstance);'):
            self.assertIn(text, source)
        declarations = source.split('implementation', 1)[0].split('}', 1)[1]
        for missing in ('TDdeClientItem', 'TDdeServerItem', 'PasteLink', 'PokeData', 'StartAdvise'):
            self.assertNotIn(missing, declarations)

    def test_ddeml_bindings_use_the_win16_dll(self):
        source = (ROOT / 'src/win16/ddeml.pas').read_text()
        for text in ("external 'DDEML';", 'XTYP_EXECUTE = $0050 or XCLASS_FLAGS;',
                     'XTYP_CONNECT = $0060 or XCLASS_BOOL or XTYPF_NOBLOCK;', 'CP_WINANSI = 1004;'):
            self.assertIn(text, source)

    def test_native_probe_covers_both_sides(self):
        probe = (ROOT / 'tests/pascal/test_win16_dde.pas').read_text()
        for text in ('another task connects to AppName|Name', 'ExecuteMacroLines arrives as one line per string',
                     'an unknown topic is refused', "RequestData returns the server''s text",
                     'OpenLink starts ServiceApplication and connects',
                     'a server that exits ends the link with OnClose'):
            self.assertIn(text, probe)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-dde-runtime-test',
                      makefile.split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0])
        self.assertIn('tests/pascal/dde_sender.pas', makefile)


if __name__ == '__main__':
    unittest.main()
