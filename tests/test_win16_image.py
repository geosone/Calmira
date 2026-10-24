"""Image/update scope guards; behavior and composition run under Win3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16ImageTests(unittest.TestCase):
    def test_graphic_updates_flush_parent_and_reject_reentry(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('procedure TCustomControl.Update', 'UpdateWindow(Handle)',
                     'FChanging or Painting or FCompositing or (Canvas.Handle <> 0)',
                     'procedure TGraphicControl.Show', 'procedure TGraphicControl.Hide',
                     'procedure TGraphicControl.Update', 'FParent.Update',
                     'procedure TGraphicControl.Repaint', 'begin Invalidate; Update; end'):
            self.assertIn(text, source)

    def test_image_owns_picture_and_exposes_bitmap_canvas_not_paint_canvas(self):
        source = (ROOT / 'src/win16/extctrls.pas').read_text()
        for text in ('TImage = class(TGraphicControl)', 'IFNDEF WIN16',
                     'FPicture := TPicture.Create', 'FPicture.OnChange := PictureChanged',
                     'FPicture.OnChange := nil; FPicture.Free', 'FPicture.Assign(Value)',
                     'property Canvas: TCanvas read GetPictureCanvas',
                     'FPicture.Bitmap.SetSize(Width, Height)',
                     'if not (FPicture.Graphic is TBitmap) then',
                     'Painter := TGraphicControl(Self).Canvas'):
            self.assertIn(text, source)

    def test_auto_size_center_and_icon_scaling_are_explicit(self):
        source = (ROOT / 'src/win16/extctrls.pas').read_text()
        for text in ('if Value and not FPicture.Empty then SetBounds',
                     'if FAutoSize and not FPicture.Empty then',
                     '(Width - FPicture.Width) div 2', '(Height - FPicture.Height) div 2',
                     'FPicture.Graphic is TIcon', 'Surface.SetSize(FPicture.Width, FPicture.Height)',
                     'Surface.Canvas.Brush.Color := Color', 'finally Surface.Free',
                     'Painter.StretchDraw'):
            self.assertIn(text, source)

    def test_native_probe_exercises_ownership_pixels_update_and_cleanup(self):
        source = (ROOT / 'tests/pascal/test_win16_image.pas').read_text()
        for text in ('center moves native image and clears old position',
                     'oversized centered bitmap clips negative origin',
                     'clearing an auto-sized picture retains its box',
                     'stretch fills image bounds with scaled bitmap quadrants',
                     'public image Canvas draws into persistent owned bitmap',
                     'transparent bitmap key preserves opaque image background',
                     'Hide plus Update clears old graphic region',
                     'overflowing AutoSize enable leaves flag and bounds unchanged',
                     'scaled icon matches native masked icon',
                     'icon Canvas access is rejected without converting',
                     'nested graphic and parent Update reject paint reentry',
                     'repeated icon replacement and scaled rendering retain GDI and USER resources'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-image: fpc-win16-gui-rtl', makefile)
        self.assertIn('win16-image-runtime-test: win16-image', makefile)

    def test_combined_progress_probe_is_not_a_replacement_dialog(self):
        source = (ROOT / 'tests/pascal/progress_ui_probe.inc').read_text()
        for text in ('TProgressProbe = class(TNativeForm)',
                     'TWin95Gauge.Create(Self)', 'TLabel.Create(Self)', 'TImage.Create(Self)',
                     'Gauge.Update; Status.Update',
                     'native Cancel stops progress at step 5',
                     'recreated progress completes 20 steps',
                     'Escape cancels progress at step 3'):
            self.assertIn(text, source)
        self.assertIn('win16-progress-ui-runtime-test: win16-progress-ui',
                      (ROOT / 'makefile').read_text())

    def test_ui_batch_contains_all_control_acceptance_targets(self):
        source = (ROOT / 'makefile').read_text()
        build = source.split('win16-ui:', 1)[1].split('\n\n', 1)[0]
        runtime = source.split('win16-ui-runtime-test:', 1)[1].split('\n\n', 1)[0]
        for name in ('image', 'progress-ui', 'label', 'graphic', 'gauge', 'slider', 'form', 'hierarchy',
                     'button', 'bitbtn', 'progress-button'):
            self.assertIn('win16-' + name, build)
            self.assertIn('win16-' + name + '-runtime-test', runtime)
