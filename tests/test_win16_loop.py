"""Message-loop scope guards; queue behavior is tested under native Win3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16LoopTests(unittest.TestCase):
    def test_loop_is_win16_only_and_not_a_forms_placeholder(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        self.assertIn('IFNDEF WIN16', source)
        self.assertIn('TNativeMessageLoop = class(TObject)', source)
        self.assertNotIn('unit Forms;', source)
        self.assertNotIn('Application:', source)

    def test_dispatch_uses_unfiltered_task_queue_and_native_translation(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        for text in ('GetMessage(Message, 0, 0, 0)',
                     'PeekMessage(Message, 0, 0, 0, PM_REMOVE)',
                     'TranslateMessage(Message)', 'DispatchMessage(Message)',
                     'Result < Limit', 'if Limit = 0 then'):
            self.assertIn(text, source)
        self.assertLess(source.index('TranslateMessage(Message)'),
                        source.index('DispatchMessage(Message)'))
        self.assertNotIn('Sleep(', source)

    def test_quit_state_and_queue_guard_are_explicit(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        for text in ('var ActiveLoop: TNativeMessageLoop',
                     'if ActiveLoop <> nil then', 'FExitCode := SmallInt(Message.wParam)',
                     'FTerminated := True', 'while not FTerminated do',
                     'if not Deliver(Message) then Break'):
            self.assertIn(text, source)
        self.assertEqual(source.count('finally ActiveLoop := nil; end;'), 2)
        self.assertNotIn('PostQuitMessage(', source)

    def test_native_acceptance_and_build_entry_points_exist(self):
        source = (ROOT / 'tests/pascal/test_win16_loop.pas').read_text()
        for text in ('bounded pump leaves excess queued messages untouched',
                     'same and different object nested pumps cannot steal',
                     'native callback exception does not stop queued dispatch',
                     'TranslateMessage produces real ANSI character delivery',
                     'self-posting callback cannot exceed the bounded dispatch budget',
                     'closing one native window does not silently terminate',
                     'blocking loop wakes for timer',
                     'terminated loop never consumes subsequent messages',
                     'WM_QUIT is consumed once rather than reposted'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-loop: fpc-win16-gui-rtl', makefile)
        self.assertIn('win16-loop-runtime-test: win16-loop', makefile)
