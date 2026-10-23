"""Actual NE identity stays separate from wrapper-aware package data paths."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RuntimeIdentityTests(unittest.TestCase):
    def test_application_identity_is_read_only_task_affine_and_not_wrapper_derived(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn('property ExeName: string read GetExeName;', source)
        body = source.split('function TNativeApplication.GetExeName:', 1)[1].split(
            'procedure TNativeApplication.SetTitle', 1)[0]
        self.assertIn('CheckReady; Result := RuntimeExecutableName', body)
        for text in ('RuntimeDirectory', 'RuntimePackageExecutableName',
                     'EnsureHandle', 'GetHandle', 'ParamStr', 'FMainForm.Show'):
            self.assertNotIn(text, body)

    def test_module_filename_is_bounded_checked_and_fail_closed(self):
        source = (ROOT / 'src/win16/runtime_paths.pas').read_text()
        body = source.split('function RuntimeExecutableName: string;', 2)[2].split(
            'function RuntimePackageExecutableName:', 1)[0]
        for text in ('array[0..256] of Char', 'FillChar(ModuleName',
                     'Count := GetModuleFileName(HInstance',
                     'DecodeModulePath(@ModuleName[0], Count, SizeOf(ModuleName))',
                     "if Result = '' then raise EInvalidOp"):
            self.assertIn(text, body)
        self.assertNotIn('StrPas', body.split('FillChar', 1)[1])
        helper = (ROOT / 'src/portable/runtime_path_text.pas').read_text()
        for text in ('Buffer = nil', 'Count <= 0', 'Count > 255', 'Count >= Capacity',
                     'Buffer[Count] <> #0', 'SetString(Result, Buffer, Count)',
                     'Pos(#0, Result) <> 0'):
            self.assertIn(text, helper)

    def test_package_resolution_alone_reads_validated_source_sidecar(self):
        source = (ROOT / 'src/win16/runtime_paths.pas').read_text()
        body = source.split('function RuntimePackageExecutableName: string;', 2)[2].split(
            'function RuntimeDirectory:', 1)[0]
        for text in ('Name := RuntimeExecutableName', 'Result := Name',
                     'IsWrapperModuleName(Name)', 'WrapperSidecarFileName(Name)',
                     'IsRootedDriveFileName(Original)', 'ReadableWrapperFile(Original)',
                     'Result := Original'):
            self.assertIn(text, body)
        self.assertIn('Name := RuntimePackageExecutableName;', source)
        self.assertIn('Result := ExecutableDirectory(Name);', source)

    def test_native_probe_covers_module_resource_identity_and_callback_scopes(self):
        source = (ROOT / 'tests/pascal/test_win16_identity.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'ExeName matches current KERNEL module path',
                     'ExeName opens the real loaded NE file',
                     'loaded module retains bound original icon resources',
                     'do not create transport forms or start application',
                     'paths do not follow current directory',
                     'identity queries are safe inside sent transport callbacks',
                     'read only inside help callback', 'read only inside exception callback',
                     'terminated application retains read only executable identity'):
            self.assertIn(text, source)

    def test_packed_runner_uses_actual_wrapper_and_disposable_software_emulation(self):
        runner = (ROOT / 'tests/dos/test_identity_paths_win311.sh').read_text()
        for text in ('for profile in plain packed;', 'tools/pack_executables.py',
                     'cp --reflink=auto "$WIN311_IMAGE"', '::/IDENTPKG/IDENTITY.EXE',
                     'SET TEMP=C:', '-accel "${QEMU_ACCEL:-tcg}"',
                     '~?UPX', 'restored wrapper sidecar'):
            self.assertIn(text, runner)
        self.assertNotIn('-accel kvm', runner)
        source = (ROOT / 'tests/pascal/test_win16_identity.pas').read_text()
        for text in ('drive relative sidecar', 'relative sidecar', 'nonexistent sidecar target',
                     'embedded NUL sidecar', 'empty sidecar', 'missing sidecar',
                     'finally WriteSidecar(PackageName)'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-identity-package-runtime-test: win16-identity upx', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-identity/GDITEST.EXE', make)

    def test_portable_text_boundaries_are_part_of_host_acceptance(self):
        source = (ROOT / 'tests/pascal/test_runtime_path_text.pas').read_text()
        for text in ('nil buffer', 'failed API', 'missing terminator', 'embedded NUL',
                     'maximum complete ShortString', 'overlong name rejected before narrowing',
                     'truncated return count', 'sidecar NUL', 'UNC outside wrapper contract'):
            self.assertIn(text, source)
        self.assertIn('tests/pascal/test_runtime_path_text.pas', (ROOT / 'makefile').read_text())

    def test_wrapper_reader_is_bounded_and_runtime_path_helpers_avoid_managed_temporaries(self):
        source = (ROOT / 'src/win16/runtime_paths.pas').read_text()
        reader = source.split('function ReadWrapperSource(', 1)[1].split(
            'function ReadableWrapperFile(', 1)[0]
        for text in ('array[0..257] of Char', '_lread(Source, @Buffer[0], SizeOf(Buffer))',
                     'finally _lclose(Source)', 'DecodeSourcePath('):
            self.assertIn(text, reader)
        self.assertNotIn('ReadLn(', reader)
        self.assertNotIn('AnsiString', source)


if __name__ == '__main__':
    unittest.main()
