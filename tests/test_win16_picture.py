"""Scope guards for the native picture probe, not a host GUI emulation."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16PictureTests(unittest.TestCase):
    def test_picture_has_copying_properties_and_child_notification_hook(self):
        source = (ROOT / 'src/win16/graphics.pas').read_text()
        for text in ('TPicture = class(TPersistent)', 'Copy.Assign(Value)',
                     'FGraphic.OnChange := GraphicChanged', 'Previous.OnChange := nil',
                     'property Bitmap: TBitmap read GetBitmap write SetBitmap',
                     'property Icon: TIcon read GetIcon write SetIcon',
                     'property Graphic: TGraphic read FGraphic write SetGraphic'):
            self.assertIn(text, source)
        self.assertIn('CheckReplacement', source)
        self.assertIn('FNotifying := False', source)

    def test_canvas_changes_propagate_through_bitmap(self):
        canvas = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        bitmap = (ROOT / 'src/win16/gdi_bitmap.pas').read_text()
        self.assertIn('property OnChange: TNotifyEvent', canvas)
        self.assertIn('FCanvas.OnChange := CanvasChanged', bitmap)
        self.assertIn('procedure TGDIBitmap.CanvasChanged(Sender: TObject)', bitmap)
        self.assertIn('DWORD($FFFFFFFF)', canvas)

    def test_native_picture_probe_checks_lifetimes_and_error_paths(self):
        source = (ROOT / 'tests/pascal/test_win16_picture.pas').read_text()
        for text in ('picture Assign deep-copies contained graphic',
                     'child canvas pixel write forwards picture event',
                     'icon property switch frees old bitmap',
                     'failed file load preserves old picture without event',
                     'notification exception leaves committed replacement owned by picture',
                     'failed release notification does not orphan returned bitmap handle',
                     'picture destructor frees child without teardown callbacks',
                     'GFSR_GDIRESOURCES', 'GFSR_USERRESOURCES'):
            self.assertIn(text, source)

    def test_picture_does_not_fake_unsupported_formats_or_dfm_streaming(self):
        source = (ROOT / 'src/win16/graphics.pas').read_text()
        self.assertIn("EConvertError.Create('Unsupported picture graphic')", source)
        self.assertNotIn('RegisterFileFormat', source)
        self.assertNotIn('procedure TPicture.LoadFromStream', source)
