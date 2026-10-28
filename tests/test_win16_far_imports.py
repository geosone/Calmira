"""DLL imports bound in a unit's implementation, and ParamStr in Delphi mode:
the two toolchain fixes that let CALMIRA.EXE link."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16FarImportTests(unittest.TestCase):
    def test_external_wrappers_jump_far(self):
        patch = (ROOT / 'tools/patches/fpc-i8086-far-external-wrapper.patch').read_text()
        self.assertIn('+++ b/compiler/i8086/hlcgcpu.pas', patch)
        self.assertIn('+      list.concat(taicpu.op_sym(A_JMP,S_FAR,', patch)
        stage = (ROOT / 'tools/prepare_fpc_compiler.py').read_text()
        self.assertIn("'tools/patches/fpc-i8086-far-external-wrapper.patch'", stage)
        # LFNFUNCS.DLL is bound exactly this way.
        self.assertIn(" external 'LFNFUNCS';", (ROOT / 'vcl/lfnutils.pas').read_text(encoding='latin-1'))

    def test_delphi_mode_paramstr_is_provided_with_objpas_parameter_size(self):
        patch = (ROOT / 'tools/patches/fpc-win16-paramstra.patch').read_text()
        self.assertIn("+function paramstr_a(l : smallint) : ansistring; [public,alias:'_FPC_ParamStrA'];", patch)
        self.assertIn("'fpc-win16-paramstra.patch'", (ROOT / 'tools/prepare_win16_rtl.py').read_text())
        self.assertIn('-dCALMIRA_WIN16_PARAMSTRA', (ROOT / 'tools/build_win16_rtl.sh').read_text())

    def test_native_suite_is_in_the_regression(self):
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-far-imports-runtime-test: win16-far-imports', make)
        self.assertIn('win16-loader-props-runtime-test win16-far-imports-runtime-test', make)
        native = (ROOT / 'tests/pascal/test_win16_far_imports.pas').read_text()
        for check in ('a wrapped USER import is reached with a far jump', 'ParamStr links in Delphi mode'):
            self.assertIn(check, native)
        probe = (ROOT / 'tests/pascal/far_import_probe.pas').read_text()
        self.assertIn("function ProbeTickCount: LongInt; external 'USER' name 'GetTickCount';", probe)

    def test_calmira_program_skips_the_delphi_resource_directive(self):
        program = (ROOT / 'src/calmira.dpr').read_bytes()
        self.assertIn(b'{$IFNDEF FPC}{$R *.res}{$ENDIF}\r\n', program)


if __name__ == '__main__':
    unittest.main()
