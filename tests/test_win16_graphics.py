"""Public subset and ABI guards; behavior is tested by the native API probe."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16GraphicsTests(unittest.TestCase):
    def test_public_rectangles_keep_the_win16_layout(self):
        source = (ROOT / 'src/win16/graphics.pas').read_text()
        self.assertIn('TRect = WinTypes.TRect', source)
        self.assertIn('TPoint = WinTypes.TPoint', source)
        self.assertIn('function Bounds(Left, Top, Width, Height: SmallInt): TRect', source)
        self.assertIn('{$IFNDEF WIN16}{$FATAL', source)

    def test_public_colors_agree_with_the_portable_registry(self):
        graphics = (ROOT / 'src/win16/graphics.pas').read_text()
        portable = (ROOT / 'src/portable/color_names.pas').read_text()
        def colors(text, typename):
            return {name.lower(): int(value.replace('$', '0x'), 0) for name, value in
                    re.findall(r'(cl\w+)\s*=\s*' + typename + r'\((-?\$?[0-9A-Fa-f]+)\)', text)}
        values = colors(graphics, 'TColor')
        self.assertEqual(len(values), 39)
        # Delphi 1 GRAPHICS.INT: clX = TColor(-COLOR_X - 1); no clNone/clDefault.
        self.assertEqual((values['clscrollbar'], values['clbtnface'], values['clbtnhighlight']), (-1, -16, -21))
        self.assertNotIn('clnone', values)
        self.assertEqual(values, colors(portable, 'LongInt'))

    def test_native_probe_uses_public_api_and_real_original_color_unit(self):
        source = (ROOT / 'tests/pascal/test_win16_graphics.pas').read_text()
        self.assertIn('Graphics, CalColor;', source)
        self.assertNotIn('gdi_canvas', source)
        for name in ('bitmap-argument BrushCopy signature', 'Font.Size := 8',
                     'Canvas.Font := Font', 'LoadFromResourceName', 'LoadFromResourceID',
                     'CalColorToString', 'StringToCalColor', 'GetColorValues',
                     'public canvas identity and pixels survive resize'):
            self.assertIn(name, source)
        self.assertNotIn('Forms', source)

    def test_bitmap_canvas_factory_retains_the_public_type(self):
        foundation = (ROOT / 'src/win16/gdi_bitmap.pas').read_text()
        facade = (ROOT / 'src/win16/graphics.pas').read_text()
        self.assertIn('FCanvas := CreateCanvas', foundation)
        self.assertIn('function CreateCanvas: TGDICanvas; virtual', foundation)
        self.assertIn('function TBitmap.CreateCanvas: TGDICanvas', facade)
        self.assertIn('Result := TCanvas.Create', facade)

    def test_public_handles_delegate_to_explicit_ownership_operations(self):
        facade = (ROOT / 'src/win16/graphics.pas').read_text()
        for name in ('gdi_bitmap', 'gdi_icon'):
            base = (ROOT / f'src/win16/{name}.pas').read_text()
            self.assertRegex(base, r'property Handle: H\w+ read FHandle write TakeHandle')
            self.assertIn('function ReleaseHandle:', base)
            self.assertIn('procedure CopyFromHandle(', base)
        self.assertIn('TPicture = class(TPersistent)', facade)
