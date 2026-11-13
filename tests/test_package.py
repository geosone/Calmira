"""Guards for the release package script and the GDI descriptor."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def section(text, name):
    body = text.split(f'[{name}]\n', 1)[1]
    return [line for line in body.split('\n[', 1)[0].splitlines() if line and not line.startswith(';')]


class PackageTests(unittest.TestCase):
    def test_package_takes_every_payload_from_one_build_tree(self):
        script = (ROOT / 'tools/package.sh').read_text()
        self.assertIn('build=${BUILD_DIR:-build}', script)
        self.assertNotIn('$root/build/', script)
        self.assertNotIn('$root/src/', script.replace('$root/src/calmira.ini', '')
                         .replace('$root/src/start.bat', '').replace('$root/src/start.ini', '')
                         .replace('$root/src/tips.txt', '').replace('$root/src/tray/', ''))
        self.assertIn('"$gdi/build/gdicheck" "$stage/INSTALL.INI"', script)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('package: calmira dos-helpers lfnfuncs wndhooks', makefile)
        self.assertIn("sh tests/dos/test_package.sh", makefile)

    def test_release_number_matches_installer_about_box_and_catalogues(self):
        self.assertIn('Version=5.0.90\n', (ROOT / 'install/install.ini').read_text())
        self.assertIn(b'\x06\x1bVersion 5.0.90 (Prerelease)', (ROOT / 'src/about.dfm').read_bytes())
        self.assertIn(b'\x06\x19Version 5.0.90 Prerelease', (ROOT / 'src/splash.dfm').read_bytes())
        for path in (ROOT / 'locales/translated').glob('*.json'):
            text = path.read_text(encoding='utf-8')
            self.assertEqual(text.count(' 5.0.90 '), 2, path.name)
            self.assertNotIn(' 5.0 ', text)

    def test_descriptor_lists_files_without_archive_wildcards(self):
        descriptor = (ROOT / 'install/install.ini').read_text()
        self.assertNotIn('Archive=', descriptor)
        for line in section(descriptor, 'Files'):
            self.assertNotIn('*', line)

    def test_dlls_go_where_windows_finds_them_without_replacing_shared_ones(self):
        files = section((ROOT / 'install/install.ini').read_text(), 'Files')
        self.assertIn('SYSTEM\\LFNFUNCS.DLL=%WINDIR%\\SYSTEM\\LFNFUNCS.DLL', files)
        self.assertIn('!?%WINDIR%\\SYSTEM\\CTL3DV2.DLL|SYSTEM\\CTL3DV2.DLL=%WINDIR%\\SYSTEM\\CTL3DV2.DLL', files)
        dirs = section((ROOT / 'install/install.ini').read_text(), 'Dirs')
        self.assertNotIn('%DIR%\\SYSTEM', dirs)

    def test_runtime_test_covers_install_start_and_uninstall(self):
        test = (ROOT / 'tests/dos/test_package.sh').read_text()
        for text in ('INSTALL.EXE /S', 'COUNTRY=049', 'Selected=de',
                     "shell=C:\\\\CALMIRA\\\\CALMIRA.EXE", 'LFNFUNCS.DLL is not in the Windows system directory',
                     'the existing CTL3DV2.DLL was replaced', 'PASS Windows starts with the installed Calmira shell',
                     'INSTALL.EXE /U', "SYSTEM.INI was not restored", 'BMPCACHE.BMP IMGINDEX.DAT'):
            self.assertIn(text, test)


if __name__ == '__main__':
    unittest.main()
