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

    def test_long_filename_findfirst_only_passes_the_attribute_byte(self):
        # INT 21h/714Eh takes the attributes a file must have in CH; FPC's
        # faAnyFile ($1FF) put 1 there. With DOSLFN, FindFirst(name, faAnyFile
        # and not faDirectory) found only read-only files: Desktop Properties
        # did not find the current wallpaper and the monitor stayed empty.
        patch = (ROOT / 'tools/patches/fpc-win16-lfn-findattr.patch').read_text()
        self.assertIn('+   dosregs.cx:=attr and $ff and (not 8);', patch)
        self.assertIn('fpc-win16-lfn-findattr.patch', (ROOT / 'tools/prepare_win16_rtl.py').read_text())
        self.assertIn('-dCALMIRA_WIN16_LFN_FINDATTR', (ROOT / 'tools/build_win16_rtl.sh').read_text())
        makefile = (ROOT / 'makefile').read_text()
        rule = makefile.split('\nwin16-desktop-wallpaper-runtime-test:', 1)[1].split('\n\n', 1)[0]
        self.assertIn('doslfn', rule.split('\n', 1)[0])
        self.assertIn('GDI_DOSLFN=1', rule)
        harness = (ROOT / 'tests/dos/test_win16_gdi.sh').read_text()
        self.assertIn('LH C:\\\\DOSLFN.COM', harness)

    def test_lfindclose_frees_the_search_without_long_names(self):
        # With DOSLFN and long names off, FPC's FindFirst holds a driver
        # handle until FindClose; LFindClose did nothing, and after 45
        # searches folders showed nothing.
        source = (ROOT / 'src/lfn_fns.pas').read_bytes().decode('latin-1')
        close = source.split('procedure LFindClose(var SearchRec: TLfnSearchRec);\r\nbegin', 1)[1].split('\r\nend;', 1)[0]
        self.assertIn('FindClose(SearchRec.ShortData)', close)
        probe = (ROOT / 'tests/pascal/test_win16_lfnfuncs.pas').read_text()
        self.assertIn("'LFindClose ends a search, a hundred searches find files'", probe)
        makefile = (ROOT / 'makefile').read_text()
        rule = makefile.split('\nwin16-lfnfuncs-doslfn-runtime-test:', 1)[1].split('\n\n', 1)[0]
        self.assertIn('GDI_DOSLFN=1', rule)

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

    def test_program_groups_become_menus_of_their_own(self):
        # The groups went into a "Program Manager" submenu below the English
        # stand-ins of START.INI, after the programs, and German Windows'
        # Autostart group never ran.
        source = (ROOT / 'src/grpsync.pas').read_text()
        body = source.split('function SyncProgramGroups(Force: Boolean;', 2)[2]
        self.assertIn("GroupSection := ParentSection + '\\' + GroupCaption;", body)
        self.assertIn("DefaultGroups: array[0..4] of string[11] = ('Accessories', 'Games',", source)
        self.assertIn("'Autostart'", source)
        self.assertIn("ini.ReadString('Start Menu', 'StartupGroup', NoKey) = NoKey", body)
        self.assertLess(body.index('PutFoldersFirst(StartProfile, ParentSection);'),
                        body.index("ini.WriteString('Start Menu', 'ProgramGroupsSignature', Signature);"))
        start = (ROOT / 'tests/pascal/test_win16_calmira_start.pas').read_text()
        for text in ('Program Manager groups become menus of their own under Programs',
                     'the English stand-ins of START.INI give way to the real groups',
                     'the groups stand above the programs, in alphabetical order',
                     'the German startup group Autostart is the one Calmira runs'):
            self.assertIn(text, start)

    def test_main_forms_are_not_translated_twice(self):
        # Translating the loaded forms again put the placeholders back over
        # what OnCreate set: My Computer said "0 Objekte" and ignored its
        # caption from CALMIRA.INI.
        dpr = (ROOT / 'src/calmira.dpr').read_text(encoding='latin-1')
        block = dpr.split('{$IFNDEF FPC}\n  { Free Pascal', 1)[1].split('{$ENDIF}', 1)[0]
        self.assertIn('ApplyComponentLanguage(Computer);', block)
        self.assertEqual(dpr.count('ApplyComponentLanguage(Computer);'), 1)
        native = (ROOT / 'tests/pascal/test_win16_computer_window.pas').read_text()
        self.assertIn('the default name My Computer is shown in German as Arbeitsplatz', native)
        self.assertIn('the Recycle Bin keeps the name of the user', native)
        makefile = (ROOT / 'makefile').read_text()
        regression = makefile.split('win16-fixed-regression: fpc-win16-fixed-compiler', 1)[1].split('\n\n', 1)[0]
        self.assertIn('win16-computer-window-runtime-test', regression)

    def test_an_empty_icon_draws_nothing(self):
        # As Delphi's TIcon.Draw; a program without an icon of its own showed
        # "Missing icon or destination DC" in My Computer.
        source = (ROOT / 'src/win16/gdi_icon.pas').read_text(encoding='latin-1')
        body = source.split('procedure TGDIIcon.DrawTo', 1)[1]
        self.assertIn('if FHandle = 0 then Exit;', body)
        self.assertNotIn('(FHandle = 0) then raise', body)
        native = (ROOT / 'tests/pascal/test_win16_computer_window.pas').read_text()
        self.assertIn('a program without an icon shows no error box in My Computer', native)

    def test_desktop_texts_follow_the_catalogue(self):
        # Object counts, drive names and the names of My Computer, the Recycle
        # Bin and the system programs were English in every language.
        settings = (ROOT / 'src/settings.pas').read_text(encoding='latin-1')
        self.assertIn("ShownCaption(ReadString('Computer', 'Caption',", settings)
        self.assertIn("StoredCaption(BinCaption, 'Recycle Bin',", settings)
        for name in ('compsys', 'iconwin', 'wastebin'):
            source = (ROOT / f'src/{name}.pas').read_text(encoding='latin-1')
            self.assertNotIn('Format(SSNumObjects', source)
            self.assertIn('NumObjectsText(', source)
        iconic = (ROOT / 'src/iconic.pas').read_text(encoding='latin-1')
        self.assertIn("LanguageText('Desktop', DriveNameKeys[DriveType],", iconic)
        self.assertIn("if (t[i] = '-') and (t[i + 1] <> ' ') then System.Insert(' ', t, i + 1);", iconic)
        compsys = (ROOT / 'src/compsys.pas').read_text(encoding='latin-1')
        self.assertIn("p.Caption := LanguageText('Menu', p.Caption, p.Caption);", compsys)
        import json
        keys = {'MyComputer', 'RecycleBin', 'OneObject', 'Objects', 'UnknownDrive', 'NoDrive',
                'FloppyDrive', 'FixedDrive', 'NetworkDrive', 'CDROMDrive', 'RAMDrive'}
        extra = json.loads((ROOT / 'locales/extra.json').read_text(encoding='utf-8'))
        self.assertLessEqual(keys, set(extra['en']['Desktop']))
        for path in (ROOT / 'locales/translated').glob('*.json'):
            desktop = json.loads(path.read_text(encoding='utf-8'))['Desktop']
            self.assertLessEqual(keys, set(desktop), path.name)
            self.assertIn('%d', desktop['Objects'])
            self.assertIn('(%s:)', desktop['FixedDrive'])
        for language in ('de', 'fr'):
            menu = extra[language]['Menu']
            for key in ('*2Control Panel', 'Recycle &Bin', '&Taskbar', 'Program Manager', 'Print Manager'):
                self.assertNotEqual(menu[key], key, language)
        self.assertEqual(extra['de']['Menu']['Program Manager'], 'Programm-Manager')

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
