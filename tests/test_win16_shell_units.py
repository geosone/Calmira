"""Source contract for the huge data model and the ShellAPI/IniFiles/Menus units."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HugeModelTests(unittest.TestCase):
    def test_gui_builds_share_one_memory_model_switch(self):
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('WIN16_MEMORY_MODEL ?= Huge', makefile)
        self.assertIn('FPC_WIN16_GUI_RTL := $(BUILD_DIR)/win16-rtl/units-$(WIN16_MEMORY_MODEL)', makefile)
        self.assertNotIn('-Mdelphi -Wh -CX', makefile)
        script = (ROOT / 'tools/build_win16_rtl.sh').read_text()
        self.assertIn('-Wm$model', script)
        for define in ('CALMIRA_WIN16_DOS_NO_STRINGS', 'CALMIRA_WIN16_DELPHI1_STRINGS',
                       'CALMIRA_WIN16_DELPHI1_TYPES', 'CALMIRA_WIN16_DELPHI1_RESOURCES'):
            self.assertIn(define, script)

    def test_rtl_patches_are_staged(self):
        prepare = (ROOT / 'tools/prepare_win16_rtl.py').read_text()
        for name in ('fpc-win16-huge-startup.patch', 'fpc-win16-dos-no-strings.patch',
                     'fpc-win16-delphi1-strings.patch', 'fpc-win16-delphi1-types.patch',
                     'fpc-win16-delphi1-resources.patch'):
            self.assertIn(name, prepare)
            self.assertTrue((ROOT / 'tools/patches' / name).is_file(), name)

    def test_delphi1_resources_load_the_string_table(self):
        patch = (ROOT / 'tools/patches/fpc-win16-delphi1-resources.patch').read_text()
        self.assertIn('+      constructor CreateRes(Ident: Word);', patch)
        self.assertIn('+      constructor CreateResFmt(Ident: Word; const Args: array of const);', patch)
        self.assertIn('LoadString(HInstance,Word(Ident),@Buffer[0],SizeOf(Buffer))', patch)
        self.assertIn('result:=Format(LoadStr(Ident),Args);', patch)

    def test_huge_startup_writes_system_segment(self):
        patch = (ROOT / 'tools/patches/fpc-win16-huge-startup.patch').read_text()
        self.assertIn('mov cx, seg %1', patch)
        self.assertIn('PAutoDataSegHeader(Ptr(SSeg,0))', patch)

    def test_calmira_units_precede_the_rtl(self):
        makefile = (ROOT / 'makefile').read_text()
        rule = makefile.split('\ncalmira:', 1)[1].split('\n\n', 1)[0]
        self.assertIn('-Sh-', rule)
        self.assertLess(rule.index('-Fuvcl'), rule.index('-Fu./$(FPC_WIN16_GUI_RTL)'))


class ShellUnitTests(unittest.TestCase):
    def test_shellapi_imports_shell_dll(self):
        source = (ROOT / 'src/win16/shellapi.pas').read_text()
        for name in ('RegOpenKey', 'RegQueryValue', 'DragQueryFile', 'ExtractIcon',
                     'ShellExecute', 'FindExecutable'):
            self.assertRegex(source, rf"function {name}\([^;]*(;[^;]*)*?\)[^;]*; external 'SHELL';")

    def test_inifiles_uses_profile_api(self):
        source = (ROOT / 'src/win16/inifiles.pas').read_text()
        self.assertIn('GetPrivateProfileString', source)
        self.assertIn('WritePrivateProfileString', source)
        self.assertIn("UpCase(Text[2]) = 'X'", source)

    def test_menus_update_check_and_enable_in_place(self):
        source = (ROOT / 'src/win16/menus.pas').read_text()
        self.assertIn('CheckMenuItem(FParent.FHandle, FCommand, MF_BYCOMMAND', source)
        self.assertIn('EnableMenuItem(FParent.FHandle, FCommand, MF_BYCOMMAND', source)
        self.assertIn('RemoveMenu(FHandle, 0, MF_BYPOSITION)', source)
        self.assertIn('procedure Click; virtual;', source)

    def test_native_suites_are_part_of_fixed_regression(self):
        makefile = (ROOT / 'makefile').read_text()
        regression = makefile.split('win16-fixed-regression: fpc-win16-fixed-compiler', 1)[1].split('\n\n', 1)[0]
        for target in ('win16-shellapi-runtime-test', 'win16-inifiles-runtime-test',
                       'win16-menus-runtime-test'):
            self.assertIn(target, regression)


if __name__ == '__main__':
    unittest.main()
