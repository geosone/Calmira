"""Form-loader generator: Delphi DFM semantics and original-resource coverage."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.compile_dfm import DfmError
from tools.dfm_loader import compile_loader, unit_uses
from tests.form_loader_fixture import Ident, component, fixture

PROBE = (ROOT / 'tests/pascal/form_loader_probe.pas').read_text()
UNIT = 'unit probe;\ninterface\nuses Forms;\ntype TP = class(TForm) end;\nimplementation\nend.\n'


def form(children=(), **root):
    props = [('ClientWidth', 100), ('ClientHeight', 50)] + list(root.items())
    return b'TPF0' + component('TP', 'P', props, list(children))


class DfmLoaderTests(unittest.TestCase):
    def test_uses_follow_fpc_conditionals_and_skip_comments(self):
        source = ('unit Demo; {$IFDEF FPC}{$mode delphi}{$ENDIF}\ninterface\n'
                  'uses {$IFDEF FPC}native_form,{$ELSE}Forms,{$ENDIF} Classes { Hidden, };\n'
                  "implementation\n(* uses Gone; *)\nuses SysUtils // , Lost\n, Classes;\nconst S = 'uses X;';\nend.\n")
        self.assertEqual(unit_uses(source), ('Demo', ['native_form', 'Classes', 'SysUtils']))

    def test_loader_always_uses_graphics_and_controls_first(self):
        text = compile_loader(fixture(), UNIT)[0]
        self.assertIn('uses Graphics, Controls, Forms, form_text, probe;', text)

    def test_probe_loader_order(self):
        text = compile_loader(fixture(), PROBE)[0]
        self.assertIn('uses Classes, Graphics, Controls, StdCtrls, ExtCtrls, Menus, Forms, form_text, form_loader_probe;', text)
        self.assertIn("F.Choices.Items.Add(FormText('TProbeForm', 'Choices', 'Items.Strings.1', 'Beta'));", text)
        self.assertIn('F.Book.Pages.Clear;', text)
        self.assertIn("RegisterFormLoader(TProbeForm, Load);", text)
        # References and events only after every component exists; tab order sorted.
        last_create = text.rindex('.Create(F);')
        for line in ('F.Title.FocusControl := F.NameEdit;', 'F.InitialControl := F.NameEdit;',
                     'F.OkButton.OnClick := F.OkClick;', 'F.OnCreate := F.FormCreate;'):
            self.assertGreater(text.index(line), last_create)
        self.assertLess(text.index('F.OkButton.TabOrder := 0;'), text.index('F.NameEdit.TabOrder := 1;'))
        self.assertNotIn('TextHeight', text)
        self.assertNotIn('PixelsPerInch', text)

    def test_root_visible_waits_for_on_create(self):
        text = compile_loader(form(Visible=True), UNIT)[0]
        self.assertIn('ShowAfterCreate(F);', text)
        self.assertNotIn('F.Visible', text)

    def test_strict_failures(self):
        cases = {
            'only unscaled 96-DPI': form(PixelsPerInch=120),
            'unnamed TLabel': form([component('TLabel', '', [('Width', 1), ('Height', 1)])]),
            'expected event method name': form(OnCreate='text'),
            'duplicate sibling tab order': form([
                component('TEdit', 'A', [('Width', 1), ('Height', 1), ('TabOrder', 0)]),
                component('TEdit', 'B', [('Width', 1), ('Height', 1), ('TabOrder', 0)])]),
            'only controls and menus contain': form([component('TTimer', 'T', [], [
                component('TLabel', 'L', [('Width', 1), ('Height', 1)])])]),
            'menu items belong to a menu': form([component('TMenuItem', 'M', [])]),
        }
        for reason, data in cases.items():
            with self.subTest(reason), self.assertRaisesRegex(DfmError, reason):
                compile_loader(data, UNIT)

    def test_original_forms_generate(self):
        blocked = {}
        for path in sorted((ROOT / 'src').glob('*.dfm')):
            source = (ROOT / 'src' / (path.stem + '.pas')).read_text(encoding='cp1252')
            try:
                compile_loader(path.read_bytes(), source)
            except DfmError as error:
                blocked[path.stem] = str(error)
        # Icon pictures are not provided yet.
        self.assertEqual(blocked, {
            'tips': 'Image1.Picture.Data: only TBitmap picture data is supported'})

    def test_dde_link_info_sets_service_and_topic(self):
        link = lambda *entries: form([component('TDdeClientConv', 'Link', [('LinkInfo', list(entries))])])
        text = compile_loader(link('Service PROGMAN', 'Topic PROGMAN'), UNIT)[0]
        self.assertIn("F.Link.DdeService := 'PROGMAN';", text)
        self.assertIn("F.Link.DdeTopic := 'PROGMAN';", text)
        with self.assertRaisesRegex(DfmError, 'unsupported link entry'):
            compile_loader(link('Item Groups'), UNIT)

    def test_outline_data_must_be_empty(self):
        tree = lambda data: form([component('TScrollTree', 'T', [('Width', 1), ('Height', 1)])])
        empty = form([component('TScrollTree', 'T', [('Width', 1), ('Height', 1)])])
        # The fixture writer has no binary values; patch one in.
        def with_data(payload):
            marker = b'\x06Height\x02\x01'
            return empty.replace(marker, marker + b'\x04Data\x0a' + len(payload).to_bytes(4, 'little') + payload)
        self.assertNotIn('Data', compile_loader(with_data(b'\x1f'), UNIT)[0])
        with self.assertRaisesRegex(DfmError, 'only empty outline data'):
            compile_loader(with_data(b'A\x1f'), UNIT)

    def test_forms_runs_loaders_like_delphi_streaming(self):
        source = (ROOT / 'src/win16/forms.pas').read_text()
        for text in ('procedure RegisterFormLoader(FormClass: TFormClass; Loader: TFormLoader);',
                     "raise EResNotFound.CreateFmt('Resource %s not found', [ClassName]);",
                     'constructor CreateNew(AOwner: TComponent);', 'Result := RunLoaders(Form, AClass.ClassParent);',
                     'if FVisibleAfterCreate then Visible := True;'):
            self.assertIn(text, source)
        notebook = (ROOT / 'src/win16/native_notebook.pas').read_text()
        self.assertIn('if csLoading in ComponentState then begin FLoadingPageIndex := Value; Exit; end;', notebook)
        probe = (ROOT / 'tests/pascal/test_win16_form_loader.pas').read_text()
        for text in ('PageIndex read before the pages applies after loading', 'component references are resolved',
                     'OnCreate runs after the components are loaded', 'a descendant uses its ancestor',
                     'a form class without a loader raises EResNotFound', 'unique name'):
            self.assertIn(text, probe)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-form-loader-runtime-test',
                      makefile.split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0])


if __name__ == '__main__':
    unittest.main()
