"""CALMIRA.EXE links every form loader and the resources Delphi bound."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Debug (TConsole) is not used by any unit of the shell.
UNUSED_FORMS = {'debug'}


def make_variable(name):
    text = (ROOT / 'makefile').read_text()
    match = re.search(rf'^{name} := ((?:.*\\\n)*.*)$', text, re.M)
    return match.group(1).replace('\\\n', ' ').split()


class CalmiraBuildTests(unittest.TestCase):
    def test_every_used_form_has_a_linked_loader(self):
        forms = {path.stem for path in (ROOT / 'src').glob('*.dfm')} - UNUSED_FORMS
        self.assertEqual(set(make_variable('CALMIRA_FORMS')), forms)
        unit = (ROOT / 'src/win16/calmira_forms.pas').read_text()
        linked = set(re.findall(r'(\w+)_dfm', unit))
        self.assertEqual(linked, forms | {'icondlg'})
        program = (ROOT / 'src/calmira.dpr').read_bytes()
        self.assertIn(b'{$IFDEF FPC}calmira_forms, ', program)
        self.assertIn(b'\r\n', program)
        self.assertNotIn(b'\n', program.replace(b'\r\n', b''))

    def test_resources_follow_the_original_directives(self):
        resources = make_variable('CALMIRA_RES')
        for name in ('src/calmira.res', 'src/locale.res', 'src/icons.res', 'src/bitmaps.res',
                     'src/cursors.res', 'src/capbtns.res', 'vcl/chklist.res', 'vcl/sorthdr.res'):
            self.assertIn(name, resources)
            self.assertTrue((ROOT / name).is_file())
        target = (ROOT / 'makefile').read_text().split('\ncalmira:', 1)[1].split('\n\n', 1)[0]
        self.assertIn('-koption -kstack=16k', target)
        self.assertIn('--renumber-images $(CALMIRA_RES)', target)
        self.assertIn('wrc -q -bt=windows', target)


if __name__ == '__main__':
    unittest.main()
