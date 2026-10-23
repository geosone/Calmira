"""Ownership contracts and source migration guards; runtime checks are native."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def active_source(path, fpc=True):
    text = (ROOT / path).read_text()
    text = re.sub(r'\{(?!\$).*?\}|\(\*.*?\*\)|//[^\r\n]*', '', text, flags=re.S)
    pieces = re.split(r'(\{\$(?:IFDEF|IFNDEF)\s+\w+\}|\{\$(?:ELSE|ENDIF)\})', text, flags=re.I)
    defined = {'WIN16', 'WINDOWS'} | ({'FPC'} if fpc else set())
    stack, active, output = [], True, []
    for piece in pieces:
        match = re.fullmatch(r'\{\$(IFDEF|IFNDEF)\s+(\w+)\}', piece, re.I)
        if match:
            condition = match[2].upper() in defined
            if match[1].upper() == 'IFNDEF':
                condition = not condition
            stack.append((active, condition))
            active = active and condition
        elif piece.upper() == '{$ELSE}':
            parent, condition = stack[-1]
            active = parent and not condition
        elif piece.upper() == '{$ENDIF}':
            active = stack.pop()[0]
        elif active:
            output.append(piece)
    if stack:
        raise AssertionError(f'unbalanced conditional directives in {path}')
    return ''.join(output)


class Win16HandleTests(unittest.TestCase):
    def test_shared_loadicon_results_are_not_adopted_in_fpc_sources(self):
        for path in ('src/resource.pas', 'src/askdrop.pas', 'src/replace.pas', 'src/logon.pas'):
            fpc = active_source(path)
            self.assertNotRegex(fpc, r'\.Handle\s*:=\s*LoadIcon\(')
            self.assertIn('.LoadFromResource(', fpc)
            self.assertRegex(active_source(path, False), r'\.Handle\s*:=\s*LoadIcon\(')
        self.assertIn('ic.CopyFromHandle(h)', active_source('src/deskprop.pas'))

    def test_borrowed_shrink_bitmap_uses_exception_safe_copy_in_fpc(self):
        source = active_source('vcl/miscutil.pas')
        body = source[source.index('procedure ShrinkBitmap(H: HBitmap;', source.index('implementation')):]
        body = body[:body.index('procedure ShadeIcon')]
        self.assertIn('try\n', body)
        self.assertIn('bmp.CopyFromHandle(H)', body)
        self.assertLess(body.index('try'), body.index('bmp.CopyFromHandle(H)'))
        self.assertNotIn('bmp.Handle := H', body)
        self.assertNotIn('bmp.Handle := 0', body)
        old = active_source('vcl/miscutil.pas', False)
        self.assertIn('bmp.Handle := H', old)
        self.assertIn('bmp.Handle := 0', old)

    def test_native_probe_covers_transfer_failure_detach_and_borrowed_lifetime(self):
        source = (ROOT / 'tests/pascal/test_win16_handles.pas').read_text()
        for text in ('Bitmap.Handle := RawBitmap', 'Bitmap.ReleaseHandle',
                     'Bitmap.CopyFromHandle(RawBitmap)', 'failed bitmap transfer preserves',
                     'bitmap destructor deletes adopted handle', 'Icon.ReleaseHandle',
                     'CopyIconObject.Handle := 1', 'GFSR_GDIRESOURCES', 'GFSR_USERRESOURCES'):
            self.assertIn(text, source)

    def test_extracted_error_values_are_not_assigned_by_unguarded_sources(self):
        self.assertIn('if h > 1 then Icon.Handle := h', active_source('src/iconic.pas'))
        self.assertIn('if h > 1 then ic.Handle := h', active_source('src/fileprop.pas'))
        source = active_source('src/directry.pas')
        self.assertRegex(source, r'h := ExtractIcon\(HInstance,@_s\[0\],i\);\s*if h > 1 then')

    def test_task_glyph_distinguishes_class_icons_from_private_extractions(self):
        source = active_source('src/task.pas')
        body = source[source.index('procedure TTaskButton.AssignGlyph;'):]
        body = body[:body.index('function TTaskButton.MinimizeCaption')]
        self.assertIn('OwnIcon := False', body)
        self.assertIn('OwnIcon := h > 1', body)
        self.assertIn('finally if OwnIcon then DestroyIcon(h)', body)
        self.assertIn('else ShrinkIcon(ProgIcon.Handle, Glyph, Color)', body)
