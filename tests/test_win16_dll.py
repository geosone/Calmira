"""Free Pascal Win16 libraries: their own entry code, WEP and upper-case
export names, as LFNFUNCS.DLL and WNDHOOKS.DLL need them."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return (ROOT / name).read_text()


class Win16DllTests(unittest.TestCase):
    def test_rtl_has_library_startup_code(self):
        patch = read('tools/patches/fpc-win16-dll-startup.patch')
        for model in 'smclh':
            self.assertIn(f'+++ b/rtl/win16/dllprt0{model}.asm', patch)
        for text in ('+%ifdef __DLL__', '+                call far LocalInit',
                     '+                set_unit_var __fpc_PrefixSeg, 0, 0',
                     '+                export WEP WEP resident', '+                call far FPC_LIB_EXIT',
                     '+                retf 2', '+  IsLibrary := PrefixSeg = 0;',
                     'dllprt0s dllprt0m dllprt0c dllprt0l dllprt0h'):
            self.assertIn(text, patch)
        # The task startup stays for programs.
        self.assertIn('+%endif ; __DLL__', patch)
        self.assertIn("'fpc-win16-dll-startup.patch'", read('tools/prepare_win16_rtl.py'))
        self.assertIn('-dCALMIRA_WIN16_DLL', read('tools/build_win16_rtl.sh'))

    def test_compiler_links_libraries_with_it_and_upper_case_exports(self):
        compiler = read('tools/prepare_fpc_compiler.py')
        for name in ('fpc-win16-dll-startup-object.patch', 'fpc-win16-export-names-upper.patch'):
            self.assertIn(f"'tools/patches/{name}'", compiler)
        self.assertIn('+function StartupObjectName(isdll: boolean): string;',
                      read('tools/patches/fpc-win16-dll-startup-object.patch'))
        self.assertIn('+      DllExport_COMENT_EXPDEF.ExportedName:=upper(hp.name^);',
                      read('tools/patches/fpc-win16-export-names-upper.patch'))

    def test_native_suites_are_in_the_regression(self):
        make = read('makefile')
        self.assertIn('win16-dll-runtime-test win16-lfnfuncs-runtime-test', make)
        self.assertIn('-o$$name.DLL tests/pascal/dll_probe.pas', make)
        native = read('tests/pascal/test_win16_dll.pas')
        for check in ("the library''s units were initialized", 'IsLibrary is set in the library',
                      'a static import returns its result', 'heap, strings and exceptions inside the library',
                      'GetProcAddress by name', 'FreeLibrary finalizes the library through WEP'):
            self.assertIn(check, native)
        lfn = read('tests/pascal/test_win16_lfnfuncs.pas')
        for check in ('NextItem keeps quoted separators', 'LFindFirst without long names finds a file'):
            self.assertIn(check, lfn)


    def test_volume_info_keeps_ds_and_sets_carry(self):
        # LDS put the caller's stack segment in DS, and DosError was then read
        # and written there: a GPF in LFNFUNCS.DLL at Windows start. Without
        # STC, DOS without long names reported success for every drive.
        source = (ROOT / 'src/lfn_fns.pas').read_text(encoding='utf-8').replace('\r\n', '\n')
        start = source.index('function __getvolinfo')
        body = source[start:source.index('function LGetVolumeInfo', start)]
        order = [body.index(text) for text in
                 ('push\tds', 'lds\tdx, [rootname]', 'stc', 'call Dos3Call', 'pop\tds', 'mov\tDosError, ax')]
        self.assertEqual(order, sorted(order))
        test = (ROOT / 'tests/pascal/test_win16_lfnfuncs.pas').read_text()
        for text in ('LGetVolumeInfo fails on a drive that does not exist',
                     'LGetVolumeInfo keeps the data segment of its caller'):
            self.assertIn(text, test)

if __name__ == '__main__':
    unittest.main()
