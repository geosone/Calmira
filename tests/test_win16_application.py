"""Explicit application lifecycle and integration boundaries; native tests run in Win3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeApplicationTests(unittest.TestCase):
    def test_application_is_explicit_task_affine_and_not_a_forms_placeholder(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn('TNativeApplication = class(TNativeFormHost)', source)
        self.assertIn('IFNDEF WIN16', source)
        self.assertIn('GetCurrentTask <> FTask', source)
        self.assertIn('ActiveApplication <> Self', source)
        self.assertIn('if not FInitialized', source)
        self.assertNotIn('unit Forms;', source)
        self.assertNotIn('var Application:', source)

    def test_registration_is_weak_bounded_and_detaches_before_owned_teardown(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        for text in ('FForms.IndexOf(Value) < 0', 'Value.FreeNotification(Self)',
                     '(Value.LifecycleHost <> nil) and (Value.LifecycleHost <> Self)',
                     '(Index < 0) or (Index >= FForms.Count)',
                     'FForms.Remove(AComponent)', 'FMainForm := nil'):
            self.assertIn(text, source)
        destroy = source.split('destructor TNativeApplication.Destroy;', 1)[1]
        self.assertLess(destroy.index('DetachForm(Form)'), destroy.index('inherited Destroy'))
        self.assertLess(destroy.index('FShuttingDown := True'), destroy.index('FForms.Free'))
        self.assertNotIn('Form.Free;', destroy)

    def test_form_close_host_is_not_a_replacement_for_user_events(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        close = source.split('function TNativeForm.TryClose: Boolean;', 1)[1]
        close = close.split('procedure TNativeForm.Close;', 1)[0]
        for text in ('if not CloseQuery then Exit', 'Action := ncaHide; DoClose(Action)',
                     'Result := False', 'Result := True', 'FHost.FormClosed(Self)'):
            self.assertIn(text, close)
        self.assertLess(close.index('finally FChangingForm := False'), close.index('FHost.FormClosed(Self)'))
        app = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertNotRegex(app, r'\b(?:Value|Form|FMainForm)\.OnClose\s*:=')
        self.assertNotIn('.OnHide :=', app)
        self.assertIn('Result := FMainForm.TryClose', app)

    def test_startup_occurs_inside_the_root_guard_and_cleanup_region(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        run = source.split('function TNativeMessageLoop.Run: SmallInt;', 1)[1]
        run = run.split('function TNativeMessageLoop.ProcessMessages', 1)[0]
        self.assertLess(run.index('EnterPump'), run.index('try'))
        self.assertLess(run.index('try'), run.index('FOnStart(Self)'))
        self.assertLess(run.index('FOnStart(Self)'), run.index('GetMessage('))
        self.assertIn('if not FTerminated and Assigned(FOnStart)', run)
        self.assertIn('finally ActiveLoop := nil', run)

    def test_application_routing_does_not_continue_after_user_activation(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        filter_ = source.split('function TNativeApplication.Filter', 1)[1].split('function TNativeApplication.Run', 1)[0]
        self.assertLess(filter_.index('FOnMessage(Message)'), filter_.index('Form.FindControl(Message.hwnd)'))
        self.assertIn('Result := Form.ProcessDialogMessage(Message); Exit', filter_)
        self.assertIn('FLoop.OnStart := Start', source)
        self.assertIn('finally FRunning := False; FPumping := False', source)
        self.assertIn('if FQuitRequested or FLoop.Terminated then Exit', source)

    def test_native_profiles_cover_lifetime_quit_routing_and_modal_startup(self):
        core = (ROOT / 'tests/pascal/test_win16_application.pas').read_text()
        dialogs = (ROOT / 'tests/pascal/test_win16_application_dialog.pas').read_text()
        for text in ('one application per task', 'nonowned form survives application',
                     'owned forms destroyed once', 'main close veto remains running',
                     'sent system close destroys main HWND', 'main removal ends active application',
                     'startup exception releases pump', 'filter exception releases pump'):
            self.assertIn(text, core)
        for text in ('secondary scoped default and registry mutation', 'application mnemonic routing',
                     'quit bypasses client filter', 'startup modal signed quit reaches root',
                     'modal startup failure restores application', 'modal startup recovery'):
            self.assertIn(text, dialogs)
        for source in (core, dialogs):
            self.assertIn('{$M 4096,2048}', source)
            self.assertIn('Check(StackGuardIntact', source)
        make = (ROOT / 'makefile').read_text()
        for name in ('application', 'application-dialog'):
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', make)
            self.assertIn(f'$(BUILD_DIR)/tests/win16-{name}/units', make)

    def test_factory_publishes_before_virtual_construction_and_registers_after(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        factory = source.split('procedure TNativeApplication.CreateForm(', 1)[1]
        factory = factory.split('procedure TNativeApplication.RegisterForm', 1)[0]
        self.assertIn('FormClass: TNativeFormClass; var Reference', factory)
        self.assertLess(factory.index('CheckReady;'), factory.index('FormClass.NewInstance'))
        self.assertLess(factory.index('TNativeForm(Reference) := Instance'), factory.index('Instance.Create(Self)'))
        self.assertLess(factory.index('Instance.Create(Self)'), factory.index('RegisterForm(Instance, FMainForm = nil)'))
        self.assertIn('(TNativeForm(Reference) <> nil)', factory)
        self.assertIn('(FormClass = nil)', factory)
        self.assertIn('TNativeFormClass = class of TNativeForm', (ROOT / 'src/win16/native_form.pas').read_text())

    def test_factory_resets_reference_and_guard_without_double_destroy(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        factory = source.split('procedure TNativeApplication.CreateForm(', 1)[1]
        factory = factory.split('procedure TNativeApplication.RegisterForm', 1)[0]
        self.assertIn('Instance.Create(Self); Constructed := True', factory)
        self.assertLess(factory.index('TNativeForm(Reference) := nil'), factory.index('if Constructed then Instance.Free'))
        self.assertIn('finally FCreatingForm := False', factory)
        self.assertIn('(FPumping and (FMainForm = nil))', factory)
        self.assertEqual(source.count('if FPumping or FCreatingForm or FWindow.Dispatching or FHandlingException or FHelping then raise'), 2)

    def test_hidden_main_policy_defaults_to_visible_but_skips_show(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn('FShowMainForm := True', source)
        self.assertIn('if FShowMainForm then FMainForm.Show', source)
        setter = source.split('procedure TNativeApplication.SetShowMainForm(', 1)[1]
        setter = setter.split('procedure TNativeApplication.CreateForm', 1)[0]
        self.assertIn('if FPumping or FCreatingForm then', setter)
        self.assertIn('CheckReady;', setter)

    def test_factory_native_profiles_cover_failure_and_original_dfm_integration(self):
        factory = (ROOT / 'tests/pascal/test_win16_application_factory.pas').read_text()
        original = (ROOT / 'tests/pascal/test_win16_application_original.pas').read_text()
        for text in ('reference published before virtual constructor', 'early constructor cleanup once',
                     'owned constructor cleanup once', 'post-constructor registration failure cleanup once',
                     'allocation failure does not destroy unallocated object', 'live reference is never overwritten',
                     'hidden main stays uncreated during run', 'factory recovers after allocation or constructor failure',
                     'after-construction failure cleanup once'):
            self.assertIn(text, factory)
        for text in ('App.CreateForm(TIncSearchDlg, Dialog)', 'original DFM lazy controls',
                     'Dialog.ShowModal(Main.Handle)', 'secondary keeps task alive',
                     'original search and Enter', 'recreated search and Escape'):
            self.assertIn(text, original)
        make = (ROOT / 'makefile').read_text()
        for name, source in (('factory', factory), ('original', original)):
            self.assertIn('{$M 4096,2048}', source)
            self.assertIn('Check(StackGuardIntact', source)
            self.assertIn(f'win16-application-{name}-runtime-test: win16-application-{name}', make)
            self.assertIn(f'$(BUILD_DIR)/tests/win16-application-{name}/units', make)


if __name__ == '__main__':
    unittest.main()
