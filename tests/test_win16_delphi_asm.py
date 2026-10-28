"""Delphi 1 assembler routines keep the pascal convention, and LFNFUNCS.DLL
builds from the original lfn_fns.pas with minimal Free Pascal branches."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(name, encoding='utf-8'):
    return (ROOT / name).read_text(encoding=encoding)


class Win16DelphiAssemblerTests(unittest.TestCase):
    def test_delphi_mode_does_not_switch_i8086_assembler_to_register(self):
        patch = read('tools/patches/fpc-i8086-delphi-assembler-pascal.patch')
        self.assertIn('+++ b/compiler/pstatmnt.pas', patch)
        self.assertIn('+{$ifndef i8086}', patch)
        self.assertIn("'tools/patches/fpc-i8086-delphi-assembler-pascal.patch'",
                      read('tools/prepare_fpc_compiler.py'))
        # The routines that depend on it: declared in the interface, assembler below.
        self.assertIn('function Min(a, b: Integer): Integer; assembler;', read('vcl/miscutil.pas', 'latin-1'))

    def test_native_suite_is_in_the_regression(self):
        make = read('makefile')
        self.assertIn('win16-delphi-asm-runtime-test: win16-delphi-asm', make)
        self.assertIn('win16-far-imports-runtime-test win16-delphi-asm-runtime-test \\', make)
        native = read('tests/pascal/test_win16_delphi_asm.pas')
        for check in ('an interface-declared assembler routine reads its stack parameters',
                      'MiscUtil Min, Max, Range and Sign', 'repeated calls leave the stack balanced'):
            self.assertIn(check, native)

    def test_lfn_functions_keep_the_original_with_fpc_branches(self):
        source = (ROOT / 'src/lfn_fns.pas').read_bytes().decode('latin-1')
        for text in ("procedure Dos3Call; far; external 'KERNEL' index 102;",
                     'procedure IsWS; assembler;{$IFDEF FPC} nostackframe;{$ENDIF}',
                     '\t call\tOneItem\t\t{a far routine, maybe in another segment}',
                     'uses {$IFNDEF FPC}dialogs,{$ENDIF}'):
            self.assertIn(text, source)
        self.assertIn('\r\n', source)
        make = read('makefile')
        self.assertIn('-FE$(BUILD_DIR)/lfnfuncs -oLFNFUNCS.DLL src/lfnfuncs.dpr', make)
        self.assertIn("GDI_EXTRA_FILES='$(abspath $(BUILD_DIR)/lfnfuncs/LFNFUNCS.DLL)'", make)
        self.assertIn('for extra in ${GDI_EXTRA_FILES:-}; do', read('tests/dos/test_win16_gdi.sh'))


if __name__ == '__main__':
    unittest.main()
