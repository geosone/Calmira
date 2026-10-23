"""Build-time resource compiler: reject loss, ambiguity and executable input."""
import copy
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

from tools.compile_dfm import Component, Compiler, DfmError, Value, compile_dfm, inventory, literal, parse

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / 'src/incsrch.dfm'


def text(value):
    raw = value.encode('cp1252')
    return bytes([len(raw)]) + raw


def component(cls='TProbe', name='Probe', props=(), children=()):
    return text(cls) + text(name) + b''.join(text(k) + v for k, v in props) + b'\0' + b''.join(children) + b'\0'


def integer(value):
    return b'\4' + struct.pack('<i', value)


class DfmCompilerTests(unittest.TestCase):
    def setUp(self):
        self.data = ORIGINAL.read_bytes()
        self.root = parse(self.data)

    def emit(self, root=None):
        return Compiler(root or self.root).compile('test')

    def test_forward_focus_reference_is_resolved_before_events(self):
        label = Component('TLabel', 'Prompt', {'width': Value('integer', 40),
                          'height': Value('integer', 16), 'focuscontrol': Value('ident', 'eDiT')})
        self.root.children.insert(0, label)
        output = self.emit()
        self.assertLess(output.index('Edit := TEdit.Create'), output.index('Prompt.FocusControl := Edit;'))
        self.assertLess(output.index('Prompt.FocusControl := Edit;'), output.index('Edit.OnChange :='))
        label.properties['focuscontrol'] = Value('nil', None)
        self.assertIn('Prompt.FocusControl := nil;', self.emit())

    def test_help_context_is_emitted_on_forms_and_windowed_children_without_narrowing(self):
        self.root.properties['helpcontext'] = Value('integer', 2147483647)
        edit = next(node for node in self.root.children if node.cls == 'TEdit')
        edit.properties['helpcontext'] = Value('integer', 65536)
        output = self.emit()
        self.assertIn('HelpContext := 2147483647;', output)
        self.assertIn(f'{edit.name}.HelpContext := 65536;', output)
        self.assertLess(output.index(f'{edit.name}.HelpContext :='), output.index(f'{edit.name}.OnChange :='))

    def test_help_context_rejects_invalid_types_and_ranges(self):
        for value in (Value('integer', -1), Value('integer', 2147483648),
                      Value('boolean', True), Value('string', '900')):
            with self.subTest(value=value), self.assertRaises(DfmError):
                self.root.properties['helpcontext'] = value
                self.emit()

    def test_graphic_help_context_remains_explicitly_unsupported(self):
        label = next(node for node in self.root.children if node.cls == 'TLabel')
        label.properties['helpcontext'] = Value('integer', 900)
        with self.assertRaisesRegex(DfmError, 'unsupported property'):
            self.emit()

    def test_graphic_enabled_is_a_typed_boolean_assignment(self):
        for cls in ('TLabel', 'TImage'):
            with self.subTest(cls=cls):
                root = copy.deepcopy(self.root)
                node = Component(cls, 'Graphic', {'width': Value('integer', 16),
                                 'height': Value('integer', 16), 'enabled': Value('boolean', False)})
                root.children.append(node)
                output = self.emit(root)
                self.assertIn('Graphic.Enabled := False;', output)
                self.assertLess(output.index('Graphic.Enabled := False;'), output.index('Edit.OnChange :='))
                node.properties['enabled'] = Value('integer', 0)
                with self.assertRaises(DfmError):
                    self.emit(root)

    def test_graphics_still_reject_windowed_tab_properties(self):
        for cls in ('TLabel', 'TImage'):
            for prop in ('taborder', 'tabstop'):
                with self.subTest(cls=cls, prop=prop):
                    root = copy.deepcopy(self.root)
                    root.children.append(Component(cls, 'Graphic', {prop: Value('integer', 0)}))
                    with self.assertRaisesRegex(DfmError, 'unsupported property'):
                        self.emit(root)

    def test_native_help_fixture_uses_the_binary_frontend(self):
        from help_context_fixture import fixture
        data = fixture()
        tree = parse(data)
        self.assertEqual(tree.properties['helpcontext'], Value('integer', 900))
        self.assertEqual(tree.children[1].properties['helpcontext'], Value('integer', 65536))
        output = compile_dfm(data)
        for text in ('HelpContext := 900;', 'Edit.HelpContext := 901;',
                     'Panel.HelpContext := 65536;', 'Inner.HelpContext := 0;'):
            self.assertIn(text, output)

    def test_focus_target_must_be_a_windowed_descendant(self):
        label = Component('TLabel', 'Prompt', {'width': Value('integer', 40), 'height': Value('integer', 16)})
        self.root.children.insert(0, label)
        for value in (Value('ident', 'Missing'), Value('ident', self.root.name),
                      Value('ident', 'Prompt'), Value('string', 'Edit'), Value('integer', 1)):
            label.properties['focuscontrol'] = value
            with self.subTest(value=value), self.assertRaises(DfmError):
                self.emit()
        self.root.children.append(Component('TImage', 'Picture', {'width': Value('integer', 16),
                                  'height': Value('integer', 16)}))
        label.properties['focuscontrol'] = Value('ident', 'Picture')
        with self.assertRaises(DfmError):
            self.emit()

    def test_generated_notification_clears_typed_fields_and_calls_inherited(self):
        output = self.emit()
        notification = output[output.index('procedure TIncSearchDlg.Notification'):]
        self.assertIn('if Operation = opRemove then', notification)
        for node in self.root.children:
            self.assertIn(f'if AComponent = {node.name} then {node.name} := nil;', notification)
        self.assertIn('inherited Notification(AComponent, Operation);', notification)

    def test_original_resource_is_deterministic_ascii(self):
        output = compile_dfm(self.data)
        self.assertEqual(output, compile_dfm(self.data))
        output.encode('ascii')
        self.assertIn('InitialControl := Edit;', output)
        self.assertIn('Edit.CharCase := ecLowerCase;', output)
        self.assertIn('Canvas.Font.Height := -11;', output)
        self.assertIn('AdjustWindowRect(', output)

    def test_raw_and_wrapped_resources_have_same_tree(self):
        raw = self.data[self.data.index(b'TPF0'):]
        self.assertEqual(parse(raw), self.root)

    def test_every_truncation_is_rejected(self):
        for data in (self.data, self.data[self.data.index(b'TPF0'):]):
            for length in range(len(data)):
                with self.subTest(length=length), self.assertRaises(DfmError):
                    parse(data[:length])

    def test_seeded_corruptions_never_escape_as_unhandled_parser_errors(self):
        generator = random.Random(311)
        for attempt in range(1000):
            damaged = bytearray(self.data)
            for _ in range(generator.randint(1, 4)):
                damaged[generator.randrange(len(damaged))] = generator.randrange(256)
            with self.subTest(attempt=attempt):
                try:
                    compile_dfm(bytes(damaged)).encode('ascii')
                except DfmError:
                    pass

    def test_trailing_bytes_and_arbitrary_signature_search_are_rejected(self):
        for data in (self.data + b'\0', b'junk' + self.data, b'TPF0' + self.data):
            with self.assertRaises(DfmError):
                parse(data)

    def test_wrong_resource_name_and_type_rejected(self):
        for data in (self.data.replace(b'TINCSEARCHDLG', b'XINCSEARCHDLG'),
                     self.data.replace(b'\xff\x0a\0', b'\xff\x09\0', 1)):
            with self.assertRaises(DfmError):
                parse(data)

    def test_duplicate_names_and_properties_case_insensitive(self):
        samples = [component(children=(component(name='Child'), component(name='cHILD'))),
                   component(props=(('Width', integer(1)), ('WIDTH', integer(2))))]
        for data in samples:
            with self.assertRaises(DfmError):
                parse(b'TPF0' + data)

    def test_unnamed_components_parse_but_do_not_compile_yet(self):
        # Delphi 1 streams TTabbedNotebook/TNotebook pages without names.
        root = parse(b'TPF0' + component(children=(component(name=''), component(name=''))))
        self.assertEqual([child.name for child in root.children], ['', ''])
        self.root.children[0].name = ''
        with self.assertRaisesRegex(DfmError, 'unnamed .* is not supported yet'):
            self.emit()

    def test_identifiers_cannot_inject_pascal_or_shadow_constructor(self):
        for name in ('Self', 'AOwner', 'AComponent', 'Operation', 'begin', 'DfmArea', 'x;halt', 'x.y', 'x' * 64):
            with self.subTest(name=name), self.assertRaises(DfmError):
                parse(b'TPF0' + component(name=name))

    def test_invalid_strings_tags_and_sets_are_rejected(self):
        for value in (b'\6\1\0', b'\6\1\x81', b'\xff', b'\x0b\1A\1a\0'):
            with self.assertRaises(DfmError):
                parse(b'TPF0' + component(props=(('Caption', value),)))

    def test_text_literal_quotes_and_ansi_bytes(self):
        self.assertEqual(literal("a'bä\r\n"), "'a''b'#228#13#10")
        self.assertEqual(literal(''), "''")
        for value in ('a\0b', 'x' * 256):
            with self.assertRaises(DfmError):
                literal(value)

    def test_unknown_properties_and_components_fail_closed(self):
        self.root.properties['align'] = Value('ident', 'alClient')
        with self.assertRaises(DfmError):
            self.emit()
        self.root.properties.pop('align')
        self.root.children[0].cls = 'TUnsupportedWidget'
        with self.assertRaisesRegex(DfmError, 'unsupported component'):
            self.emit()

    def test_property_types_ranges_and_unsupported_semantics(self):
        for prop, value in [('pixelsperinch', Value('integer', 120)),
                            ('clientwidth', Value('integer', 32768)),
                            ('caption', Value('ident', 'Injection')),
                            ('borderstyle', Value('ident', 'bsToolWindow')),
                            ('position', Value('ident', 'poDesktopCenter')),
                            ('onshow', Value('ident', 'Bad;Halt'))]:
            root = copy.deepcopy(self.root)
            root.properties[prop] = value
            with self.subTest(prop=prop), self.assertRaises(DfmError):
                self.emit(root)

    def test_child_bounds_and_auto_selection_are_explicit(self):
        for prop, value in [('width', Value('integer', -1)),
                            ('left', Value('integer', 32767)),
                            ('autoselect', Value('boolean', True)),
                            ('readonly', Value('integer', 1)),
                            ('charcase', Value('ident', 'unknown'))]:
            root = copy.deepcopy(self.root)
            root.children[1].properties[prop] = value
            with self.subTest(prop=prop), self.assertRaises(DfmError):
                self.emit(root)
        self.root.children[1].properties.pop('width')
        with self.assertRaises(DfmError):
            self.emit()

    def test_button_and_checkbox_values_are_typed_before_notifications(self):
        self.root.children = [
            Component('TButton', 'AcceptButton', {
                'width': Value('integer', 70), 'height': Value('integer', 24),
                'caption': Value('string', 'OK'), 'default': Value('boolean', True),
                'modalresult': Value('integer', 1), 'onclick': Value('ident', 'AcceptClick')}),
            Component('TCheckBox', 'Choice', {
                'width': Value('integer', 100), 'height': Value('integer', 24),
                'allowgrayed': Value('boolean', True), 'state': Value('ident', 'cbGrayed'),
                'onclick': Value('ident', 'ChoiceClick')})]
        self.root.properties['activecontrol'] = Value('ident', 'AcceptButton')
        output = self.emit()
        for binding in ('AcceptButton.Default := True;', 'AcceptButton.ModalResult := 1;',
                        'Choice.AllowGrayed := True;', 'Choice.State := cbGrayed;'):
            self.assertLess(output.index(binding), output.index('AcceptButton.OnClick :='))

    def test_large_lengths_are_rejected_without_allocating_payload(self):
        for tag in (10, 12):
            payload = bytes([tag]) + struct.pack('<I', 2 * 1024 * 1024 + 1)
            with self.assertRaisesRegex(DfmError, 'too large'):
                parse(b'TPF0' + component(props=(('Caption', payload),)))

    def test_unsupported_binary_and_list_properties_are_not_dropped(self):
        for value in (Value('binary', b'picture'), Value('list', ())):
            self.root.properties['caption'] = value
            with self.assertRaises(DfmError):
                self.emit()

    def test_active_control_must_reference_windowed_descendant(self):
        for name in ('Missing', 'Label1', self.root.name):
            self.root.properties['activecontrol'] = Value('ident', name)
            with self.subTest(name=name), self.assertRaises(DfmError):
                self.emit()

    def test_initial_values_precede_events_and_oncreate_is_last(self):
        self.root.properties['oncreate'] = Value('ident', 'Created')
        result = self.emit()
        self.assertLess(result.index('Edit.CharCase :='), result.index('Edit.OnChange :='))
        self.assertLess(result.index('InitialControl :='), result.index('OnShow :='))
        self.assertLess(result.index('Edit.OnKeyDown :='), result.index('DfmCreateEvent := Created;'))

    def test_nested_container_parent_and_font_are_generated(self):
        root = copy.deepcopy(self.root)
        root.children = [Component('TCustomControl', 'Area',
                                  {'width': Value('integer', 160), 'height': Value('integer', 30)},
                                  root.children)]
        output = self.emit(root)
        self.assertIn('Edit.Parent := Area;', output)
        self.assertIn('Edit.Font.Assign(Area.Canvas.Font);', output)
        root.children[0].cls = 'TButton'
        with self.assertRaises(DfmError):
            self.emit(root)

    def test_tab_order_is_sorted_independent_of_resource_order(self):
        self.root.children[0].cls = 'TButton'
        self.root.children[0].properties['taborder'] = Value('integer', 1)
        output = self.emit()
        self.assertLess(output.index('Edit.TabOrder := 0'), output.index('Label1.TabOrder := 1'))
        self.root.children[0].properties['taborder'] = Value('integer', 0)
        with self.assertRaisesRegex(DfmError, 'duplicate sibling'):
            self.emit()

    def test_input_and_nesting_limits(self):
        with self.assertRaises(DfmError):
            parse(b'x' * (4 * 1024 * 1024 + 1))
        nested = component(name='Last')
        for i in range(34):
            nested = component(name=f'Node{i}', children=(nested,))
        with self.assertRaises(DfmError):
            parse(b'TPF0' + nested)

    def test_cli_is_atomic_idempotent_and_never_overwrites_input(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'input.dfm'
            output = Path(directory) / 'form.inc'
            source.write_bytes(self.data)
            command = [sys.executable, str(ROOT / 'tools/compile_dfm.py'), str(source), '--output']
            subprocess.run(command + [str(output)], check=True, capture_output=True)
            stamp = output.stat().st_mtime_ns
            subprocess.run(command + [str(output)], check=True, capture_output=True)
            self.assertEqual(output.stat().st_mtime_ns, stamp)
            previous = output.read_bytes()
            source.write_bytes(b'broken')
            self.assertNotEqual(subprocess.run(command + [str(output)], capture_output=True).returncode, 0)
            self.assertEqual(output.read_bytes(), previous)
            self.assertNotEqual(subprocess.run(command + [str(source)], capture_output=True).returncode, 0)
            self.assertEqual(source.read_bytes(), b'broken')

    def test_inventory_reports_blockers_without_silently_skipping_them(self):
        report = inventory(ROOT / 'src')
        self.assertIn('incsrch.dfm', report['supported'])
        self.assertIn('TBevel', report['blocked']['about.dfm'])
        with self.assertRaises(DfmError):
            inventory(ORIGINAL)
        with self.assertRaises(DfmError):
            inventory(ROOT / 'build/no-such-dfm-directory')


if __name__ == '__main__':
    unittest.main()
