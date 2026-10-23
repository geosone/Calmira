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
        self.assertIn('if (Parent <> 0) or (Style and WS_CHILD <> 0)', source)
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
