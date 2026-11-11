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
                       'CALMIRA_WIN16_DELPHI1_TYPES', 'CALMIRA_WIN16_DELPHI1_RESOURCES',
                       'CALMIRA_WIN16_DELPHI1_INTL', 'CALMIRA_WIN16_DELPHI1_DOSERROR'):
            self.assertIn(define, script)

    def test_rtl_patches_are_staged(self):
        prepare = (ROOT / 'tools/prepare_win16_rtl.py').read_text()
        for name in ('fpc-win16-huge-startup.patch', 'fpc-win16-dos-no-strings.patch',
                     'fpc-win16-delphi1-strings.patch', 'fpc-win16-delphi1-types.patch',
                     'fpc-win16-delphi1-resources.patch', 'fpc-win16-delphi1-intl.patch',
                     'fpc-win16-delphi1-doserror.patch'):
            self.assertIn(name, prepare)
            self.assertTrue((ROOT / 'tools/patches' / name).is_file(), name)

    def test_points_reach_user_packed_in_a_long(self):
        # USER takes POINT by value as one dword; FPC passed the TPoint record
        # otherwise, so WindowFromPoint found nothing and Calmira's drop
        # server never saw the desktop under a dragged file.
        patch = (ROOT / 'tools/patches/fpc-win16-delphi1-types.patch').read_text()
        for text in ("+function PackedWindowFromPoint(pt: LONG): HWND; external 'USER' name 'WINDOWFROMPOINT';",
                     "+function PackedChildWindowFromPoint(hwndParent: HWND; pt: LONG): HWND; external 'USER' name 'CHILDWINDOWFROMPOINT';",
                     '+  WindowFromPoint := PackedWindowFromPoint(MAKELONG(Word(pt.x), Word(pt.y)));'):
            self.assertIn(text, patch)
        probe = (ROOT / 'tests/pascal/test_win16_hints.pas').read_text()
        self.assertIn('WindowFromPoint finds the window under a point', probe)
        self.assertIn('ChildWindowFromPoint finds the child under a client point', probe)

    def test_a_dragged_control_still_sees_the_mouse(self):
        # Delphi dispatches mouse messages to the dragged control after
        # DragMouseMsg; Calmira asks its drop server in OnMouseMove.
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('procedure TNativeDragManager.PassMouse(Source: TControl; Msg, Keys: Word);', controls)
        self.assertIn('NativeDragManager.PassMouse(DragSource, WM_MOUSEMOVE, Message.WParam);', controls)
        self.assertIn('NativeDragManager.PassMouse(NativeDragManager.FMouseSource, WM_LBUTTONUP, Message.WParam);', controls)
        probe = (ROOT / 'tests/pascal/test_win16_drag.pas').read_text()
        self.assertIn('the dragged control sees mouse moves in its own coordinates', probe)
        self.assertIn('the dragged control sees the button go up after the drag ends', probe)

    def test_controls_erase_their_background_as_delphi(self):
        # Without it a window just shown kept showing what was below until
        # its first paint: the Explorer's panes showed the desktop.
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('procedure WMEraseBkgnd(var M: TMessage); message WM_ERASEBKGND;', controls)
        self.assertIn('procedure TCustomControl.WMEraseBkgnd(var M: TMessage);\nbegin EraseWithColor(M); end;', controls)
        probe = (ROOT / 'tests/pascal/test_win16_canvas_context.pas').read_text()
        self.assertIn('a control just shown is filled with its colour', probe)

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

    def test_program_group_sync_marks_missing_keys_printably(self):
        # Windows 3.1 trims a #1 default to '', which gave every imported
        # group and program a " (99)" suffix and rewrote START.INI each start.
        source = (ROOT / 'src/grpsync.pas').read_text()
        self.assertIn("NoKey = '<no key>';", source)
        self.assertNotIn(', #1)', source)
        probe = (ROOT / 'tests/pascal/test_win16_inifiles.pas').read_text()
        self.assertIn('Windows trims a control-character default', probe)
        start = (ROOT / 'tests/pascal/test_win16_calmira_start.pas').read_text()
        self.assertIn('group names keep their captions, without a (99) suffix', start)

    def test_program_group_sync_drops_the_start_menu_image_cache(self):
        # The cache is read item by item; after the sync rewrote START.INI
        # every icon behind the change showed the previous item's icon.
        source = (ROOT / 'src/grpsync.pas').read_text()
        body = source.split('function SyncProgramGroups(Force: Boolean;', 2)[2]
        self.assertLess(body.index("'ProgramGroupsSignature', Signature"),
                        body.index("DeleteFile(FileWritePath + 'BMPCACHE.BMP');"))
        start = (ROOT / 'tests/pascal/test_win16_calmira_start.pas').read_text()
        self.assertIn('the Start menu image cache is rebuilt after the groups are synchronised', start)

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
