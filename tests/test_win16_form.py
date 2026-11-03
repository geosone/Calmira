"""Native modeless-form scope guards; actual lifecycle is tested under Win3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16FormTests(unittest.TestCase):
    def test_initial_focus_is_weak_and_rechecks_descendant_lifetime(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        for text in ('Value.FreeNotification(Self)', 'RemoveFreeNotification(Self)',
                     '(AComponent = FInitialControl) then FInitialControl := nil',
                     'if ContainsControl(FInitialControl) then', 'FInitialControl.CanFocus'):
            self.assertIn(text, source)
        show = source.split('procedure TNativeForm.DoShow;', 1)[1].split('procedure ', 1)[0]
        self.assertLess(show.index('FOnShow(Self)'), show.index('FInitialControl.SetFocus'))
        native = (ROOT / 'tests/pascal/test_win16_form.pas').read_text()
        for text in ('invalid initial focus preserves reference',
                     'initial focus weak reference clears on free',
                     'detached initial control is not focused'):
            self.assertIn(text, native)

    def test_form_is_real_windowed_subset_not_forms_alias(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        self.assertIn('IFNDEF WIN16', source)
        self.assertIn('TNativeForm = class(TCustomControl)', source)
        self.assertIn('WS_OVERLAPPEDWINDOW or WS_CLIPCHILDREN or WS_CLIPSIBLINGS', source)
        # Parent is the owner of a top-level form, never a child window.
        self.assertIn("raise ENativeWindowError.Create('Invalid form parent');", source)
        self.assertIn('if (Style and WS_CHILD <> 0) or ((Parent <> 0) and', source)
        self.assertNotIn('unit Forms;', source)
        self.assertNotIn('ShowModal', source)

    def test_caption_close_actions_and_lifecycle_guards_have_native_effects(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        for text in ('SetWindowText(Handle, Buffer)', 'Pos(#0, Value)',
                     'FChangingForm or Painting or (Canvas.Handle <> 0)',
                     'if not CloseQuery then Exit', 'Action := ncaHide; DoClose(Action)',
                     'ncaHide: begin HideWindow; Result := True; end',
                     'ncaDestroy: begin HideWindow; DestroyHandle; Result := True; end',
                     'procedure TNativeForm.WMClose', 'Close; M.Result := 0'):
            self.assertIn(text, source)
        self.assertEqual(source.count('finally FChangingForm := False; end;'), 4)
        self.assertNotIn('PostQuitMessage', source)
        self.assertNotIn('Self.Free', source)

    def test_hide_releases_descendant_input_without_destroying_objects(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        hide = source.split('procedure TNativeForm.HideWindow;', 1)[1].split(
            'procedure TNativeForm.Hide;', 1)[0]
        for text in ('Current := GetCapture', 'IsChild(Handle, Current) then ReleaseCapture',
                     'Current := GetFocus', 'IsChild(Handle, Current) then WinProcs.SetFocus(0)',
                     'Visible := False', 'DoHide'):
            self.assertIn(text, hide)
        self.assertNotIn('DestroyHandle', hide)
        self.assertNotIn('.Free', hide)

    def test_native_acceptance_and_build_entry_points_exist(self):
        source = (ROOT / 'tests/pascal/test_win16_form.pas').read_text()
        for text in ('queued WM_CLOSE obeys close-query veto',
                     'caption setter updates live native title',
                     'hide preserves HWND subtree and releases descendant focus and capture',
                     'queued query exception is contained at native callback boundary',
                     'destroy close removes HWND subtree but retains model and Pascal objects',
                     'show after destroy recreates titled form and managed descendants',
                     'hide event exception preserves completed visibility transition',
                     'show event exception preserves visible HWND and resets lifecycle guard',
                     'repeated modeless recreation does not drain USER resources'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-form: fpc-win16-gui-rtl', makefile)
        self.assertIn('win16-form-runtime-test: win16-form', makefile)

    def test_stretch_shift_bounds_follow_delphi(self):
        base = (ROOT / 'src/win16/control_base.pas').read_text()
        self.assertIn('procedure SetBounds(X, Y, AWidth, AHeight: Integer); virtual;', base)
        for name in ('Left', 'Top', 'Width', 'Height'):
            self.assertIn(f'property {name}: Integer read Get{name} write Set{name};', base)
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertEqual(controls.count('procedure SetBounds(X, Y, AWidth, AHeight: Integer); override;'), 2)
        forms = (ROOT / 'src/win16/forms.pas').read_text()
        self.assertIn('Area := FrameSize(Self); Result := Width - (Area.Right - Area.Left);', forms)
        native = (ROOT / 'src/win16/native_form.pas').read_text()
        self.assertIn('FPendingState and IsWindowVisible(Handle) then FPendingState := False', native)
        test = (ROOT / 'tests/pascal/test_win16_forms.pas').read_text()
        self.assertIn("'TControl bounds do not touch the form'", test)
        self.assertIn("'a pending state yields to the shown window state'", test)

    def test_header_last_section_reaches_right_edge(self):
        source = (ROOT / 'src/win16/native_header.pas').read_text()
        self.assertIn('then W := ClientWidth - X', source)
        self.assertNotIn('SetBkMode(Canvas.Handle, TRANSPARENT)', source)
        test = (ROOT / 'tests/pascal/test_win16_notebook.pas').read_text()
        self.assertIn("'section captions are drawn on the face colour'", test)

    def test_read_section_values_merges_as_delphi(self):
        source = (ROOT / 'src/win16/inifiles.pas').read_text()
        self.assertIn("Strings.Values[Keys[I]] := ReadString(Section, Keys[I], '');", source)
        test = (ROOT / 'tests/pascal/test_win16_inifiles.pas').read_text()
        self.assertIn('without clearing it, as Delphi 1', test)

    def test_explorer_opens_with_unknown_and_delphi_cursors(self):
        cursors = (ROOT / 'src/win16/native_cursors.pas').read_text()
        self.assertIn("crHSplit: Value := LoadCursor(HInstance, 'HSPLIT');", cursors)
        self.assertIn('Resource := IDC_ARROW;', cursors)
        self.assertNotIn('else Result := False; Exit; end;', cursors)
        rc = (ROOT / 'src/win16/controls.rc').read_text()
        for line in ('DRAG      CURSOR smove.cur', 'MULTIDRAG CURSOR mmove.cur', 'HSPLIT    CURSOR split.cur'):
            self.assertIn(line, rc)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('$(BUILD_DIR)/controls/controls.res \\', makefile)
        self.assertIn('-r -zm -bt=windows -i=$(WINFILE_PORT_SRC)/src', makefile)
        forms = (ROOT / 'src/win16/forms.pas').read_text()
        self.assertIn('if (Wnd = 0) or (UtilityWindows = nil) then Exit;', forms)
        test = (ROOT / 'tests/pascal/test_win16_cursor.pas').read_text()
        self.assertIn("'crHSplit shows the linked splitter cursor, as Delphi'", test)
        self.assertIn("'an unknown control cursor shows the default arrow, as Delphi'", test)

    def test_helpers_build_with_the_calmira_runtime(self):
        makefile = (ROOT / 'makefile').read_text()
        start = makefile.index('win16-helpers: fpc-win16-gui-rtl languages')
        rule = makefile[start:makefile.index('\n\n', start)]
        self.assertIn('-Sh- $(WIN16_GUI_FLAGS) -CX -Fu./$(FPC_WIN16_GUI_RTL)', rule)
        self.assertNotIn('FPC_WIN16_UNITS', rule)

    def test_dos_helpers_build_with_the_msdos_rtl(self):
        patch = (ROOT / 'tools/patches/fpc-msdos-maxheap-resize.patch').read_text()
        self.assertIn('+%ifdef CALMIRA_MSDOS_MAXHEAP', patch)
        self.assertIn('+        add dx, ax', patch)
        prepare = (ROOT / 'tools/prepare_win16_rtl.py').read_text()
        self.assertIn("'fpc-msdos-maxheap-resize.patch'", prepare)
        build = (ROOT / 'tools/build_msdos_rtl.sh').read_text()
        self.assertIn('NASM_OPT=-DCALMIRA_MSDOS_MAXHEAP', build)
        self.assertIn('OS_TARGET=msdos', build)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('-Tmsdos -Pi8086 -WmSmall -Mtp', makefile)
        self.assertIn('dos-helpers-runtime-test \\', makefile)
        for name in ('direxist', 'dosrun'):
            source = (ROOT / f'src/{name}.pas').read_text()
            self.assertIn('{$IFDEF FPC}', source)
        test = (ROOT / 'tests/dos/test_dos_helpers.sh').read_text()
        for text in ('DIREXIST rejects a file', 'COUNTTIP output matches Calmira 3.02',
                     'DOSRUN leaves the started program its memory'):
            self.assertIn(text, test)

    def test_show_activates_as_delphi(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        self.assertIn('(SW_SHOWNORMAL, SW_SHOWMINNOACTIVE, SW_SHOWMAXIMIZED)', source)
        self.assertIn('ShowWindow(Handle, ShowCommands[Requested]);', source)
        test = (ROOT / 'tests/pascal/test_win16_forms.pas').read_text()
        self.assertIn("Show activates a normal form, as Delphi''s SW_SHOWNORMAL", test)
        catalog = (ROOT / 'locales/extra.json').read_text(encoding='utf-8')
        self.assertIn('The Calmira Task Manager is not available because Calmira has terminated abnormally.', catalog)
        taskman = (ROOT / 'src/ctaskman.dpr').read_text(errors='replace')
        self.assertIn("LanguageText('TaskManager', 'Unavailable', DlgMsg)", taskman)

