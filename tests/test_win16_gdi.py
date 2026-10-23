"""Scope and ABI guards; drawing behavior is checked by the native GDI probe."""
from pathlib import Path
import os
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16GDITests(unittest.TestCase):
    def test_invalid_native_time_budgets_fail_before_image_access(self):
        for value in ('0', '61', 'abc', '-1', '9999999999999999999999999'):
            result = subprocess.run(['sh', str(ROOT / 'tests/dos/test_win16_gdi.sh')],
                                    env={**os.environ, 'WIN311_IMAGE': '/missing/gdi-test.img',
                                         'GDI_TEST_SECONDS': value},
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn('GDI_TEST_SECONDS must be 1..60', result.stderr)

    def test_port_is_explicitly_a_win16_foundation_not_a_placeholder_graphics_unit(self):
        source = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        self.assertIn('{$IFNDEF WIN16}{$FATAL', source)
        for name in ('TGDIResource', 'TGDIPen', 'TGDIBrush', 'TGDIFont', 'TGDICanvas'):
            self.assertIn(name + ' = class', source)
        facade = (ROOT / 'src/win16/graphics.pas').read_text()
        self.assertIn('Tested Win16 Graphics compatibility subset', facade)
        self.assertIn('TBitmap = class(TGDIBitmap)', facade)
        self.assertIn('TIcon = class(TGDIIcon)', facade)
        self.assertNotIn('DeleteDC(FHandle)', source)
        self.assertIn('SaveDC(DC)', source)
        self.assertIn('RestoreDC(DC, State)', source)

    def test_pen_and_hatch_enums_keep_the_win16_api_order(self):
        source = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        def members(name):
            return re.findall(r'\w+', re.search(name + r' = \((.*?)\);', source, re.S)[1])
        self.assertEqual(members('TPenStyle'), ['psSolid', 'psDash', 'psDot', 'psDashDot',
                                              'psDashDotDot', 'psClear', 'psInsideFrame'])
        self.assertEqual(members('TBrushStyle'), ['bsSolid', 'bsClear', 'bsHorizontal',
                                                'bsVertical', 'bsFDiagonal', 'bsBDiagonal',
                                                'bsCross', 'bsDiagCross'])
        self.assertIn('CreateHatchBrush(Ord(FStyle) - 2', source)
        self.assertIn('CreatePen(Ord(FStyle)', source)

    def test_native_probe_checks_pixels_dc_state_resource_changes_and_error_paths(self):
        source = (ROOT / 'tests/pascal/test_win16_gdi.pas').read_text()
        for text in ('CreateCompatibleBitmap', 'Canvas.Pixels[', 'GetTextColor', 'GetBkMode',
                     'CheckSelectedObjects', 'GetFreeSystemResources', '1 to 300',
                     'except on EGDIError', 'CopyCanvas.Font.Assign'):
            self.assertIn(text, source)
        runner = (ROOT / 'tests/dos/test_win16_gdi.sh').read_text()
        self.assertIn('cp --reflink=auto "$WIN311_IMAGE"', runner)
        self.assertIn('::/GDITEST.LOG', runner)
        self.assertIn('^RESULT PASS', runner)

    def test_bitmap_probe_covers_file_resource_pixels_and_transactional_failures(self):
        source = (ROOT / 'tests/pascal/test_win16_gdi.pas').read_text()
        for text in ('LoadFromResource', 'LoadFromFile', 'Image.Handle = SavedImage',
                     'ResourceImage.Canvas.Pixels', 'BITS1.BMP', 'BITS8.BMP',
                     'BITS24.BMP', 'LARGE.BMP', 'SHORT.BMP', 'Image.Clear'):
            self.assertIn(text, source)
        adapter = (ROOT / 'src/win16/gdi_bitmap.pas').read_text()
        self.assertIn('Stream.ReadBuffer(Row^, Layout.RowBytes)', adapter)
        self.assertIn('SelectObject(FDC, FOldBitmap)', adapter)
        self.assertIn('DeleteDC(FDC)', adapter)
        self.assertIn('ReadBMPLayout', adapter)

    def test_bitmap_editing_has_native_independence_resize_and_copy_guards(self):
        adapter = (ROOT / 'src/win16/gdi_bitmap.pas').read_text()
        self.assertIn('TGDIBitmap = class(TGDIGraphic)', adapter)
        self.assertIn('procedure Assign(Source: TPersistent); override', adapter)
        self.assertIn('property Width: SmallInt read FWidth write SetWidth', adapter)
        self.assertIn('property Height: SmallInt read FHeight write SetHeight', adapter)
        source = (ROOT / 'tests/pascal/test_win16_gdi.pas').read_text()
        for text in ('Assign copies pixels into independent handle',
                     'growth preserves overlap and canvas object',
                     'shrink crops discarded pixels', 'invalid resize preserves bitmap',
                     'incompatible Assign preserves bitmap', 'Assign copies pending empty dimensions',
                     'scaled CopyRect produces expected color quadrants',
                     'overlapping same-size self-copy', 'rectangle width validated in 32 bits',
                     'start-menu style strip growth retains earlier icons'):
            self.assertIn(text, source)


    def test_graphic_dispatch_and_icon_ownership_have_native_coverage(self):
        icon = (ROOT / 'src/win16/gdi_icon.pas').read_text()
        self.assertIn('TGDIIcon = class(TGDIGraphic)', icon)
        self.assertIn('CopyIcon(HInstance, Value)', icon)
        self.assertIn('DestroyIcon(FHandle)', icon)
        self.assertIn('RestoreDC(Destination, State)', icon)
        probe = (ROOT / 'tests/pascal/test_win16_gdi.pas').read_text()
        for text in ('all generic icon pixels match direct native DrawIcon',
                     'clearing copied icon does not destroy shared resource',
                     'missing icon resource preserves previous icon',
                     'generic icon Draw restores caller DC state'):
            self.assertIn(text, probe)

    def test_color_key_compositor_does_not_rewrite_the_source(self):
        helper = (ROOT / 'src/win16/gdi_colorkey.pas').read_text()
        self.assertIn('FreeScratch(Output); FreeScratch(Mask); FreeScratch(Image)', helper)
        self.assertNotIn('SetBkColor(Source,', helper)
        self.assertNotIn('TransparentBlt(', helper)
        probe = (ROOT / 'tests/pascal/test_win16_gdi.pas').read_text()
        for text in ('generic bitmap Draw preserves background under color key',
                     'BrushCopy scales source and replaces key with brush color',
                     'transparent drawing leaves source pixels and DC unchanged',
                     'clipped source pixels remain transparent rather than uninitialized',
                     'BrushCopy hatch aligns with caller brush origin',
                     'repeated icon and color-key drawing does not drain GDI pool'):
            self.assertIn(text, probe)


if __name__ == '__main__':
    unittest.main()
