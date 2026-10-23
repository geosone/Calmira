"""Help follows the same original-executable directory as language data."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HelpPathsTests(unittest.TestCase):
    def test_app_holder_uses_wrapper_aware_path_only_in_fpc_branch(self):
        source = (ROOT / 'vcl/apholder.pas').read_text()
        implementation = source.split('implementation', 1)[1]
        self.assertIn('{$IFDEF FPC}\nuses runtime_paths, help_service;\n{$ENDIF}', implementation)
        assignment = implementation.split("if FHelpFile > '' then", 1)[1].split('{$ENDIF}', 1)[0]
        fpc, legacy = assignment.split('{$ELSE}', 1)
        self.assertIn('HelpFile := RuntimeDirectory + FHelpFile;', fpc)
        self.assertNotIn('ExtractFilePath(ExeName)', fpc)
        self.assertIn('HelpFile := ExtractFilePath(ExeName) + FHelpFile;', legacy)

    def test_native_probe_uses_real_runtime_paths_and_winhelp(self):
        source = (ROOT / 'tests/pascal/test_help_path_win16.pas').read_text()
        self.assertIn('SysUtils, runtime_paths, help_service, language_catalog;', source)
        self.assertIn('Directory := RuntimeDirectory;', source)
        self.assertIn("HelpPath := Directory + 'CALMIRA.HLP';", source)
        self.assertIn('LaunchHelp(Window, HelpPath, HELP_CONTENTS, 0)', source)

    def test_native_runner_checks_actual_packed_module_and_installed_help(self):
        runner = (ROOT / 'tests/dos/test_help_path_win311.sh').read_text()
        self.assertIn('for profile in plain packed missing;', runner)
        self.assertIn('tools/pack_executables.py', runner)
        self.assertIn('::/HELPPKG/CALMIRA.HLP', runner)
        self.assertIn('SET TEMP=C:', runner)
        self.assertIn('~?UPX', runner)
        self.assertIn('cp --reflink=auto "$WIN311_IMAGE"', runner)
        self.assertNotIn('-accel kvm', runner)

    def test_help_bridge_preserves_custom_handlers_and_suppresses_duplicate_dispatch(self):
        source = (ROOT / 'vcl/apholder.pas').read_text()
        handler = source.split('function TAppHolder.HandleHelp', 1)[1].split('constructor TAppHolder.Create', 1)[0]
        self.assertLess(handler.index('FOnHelp(Command, Data, CallHelp)'), handler.index('LaunchHelp('))
        self.assertIn('if not CallHelp then Exit;', handler)
        self.assertLess(handler.rindex('CallHelp := False;'), handler.index('LaunchHelp('))
        self.assertIn('finally\n    FHelpActive := False;', handler)
        self.assertIn('if FHelpActive then', handler)


if __name__ == '__main__':
    unittest.main()
