"""Guards for the release package script and the GDI descriptor."""
import json
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

    def test_release_number_is_set_once_in_the_makefile(self):
        # The number stood in INSTALL.INI, both forms and six catalogues;
        # a release had to change eleven files and a catalogue could lag.
        import re
        makefile = (ROOT / 'makefile').read_text()
        version = re.search(r'^VERSION := (\d+\.\d+\.\d+)$', makefile, re.M).group(1)
        self.assertIn("CalmiraVersion = '%s';", makefile)
        self.assertIn("VERSION='$(VERSION)' sh tools/package.sh", makefile)
        self.assertIn('Version=@VERSION@\n', (ROOT / 'install/install.ini').read_text())
        self.assertIn('s/^Version=@VERSION@\\$/Version=${VERSION:?}/', (ROOT / 'tools/package.sh').read_text())
        self.assertIn(b'\x06\x17Version %s (Prerelease)', (ROOT / 'src/about.dfm').read_bytes())
        self.assertIn(b'\x06\x15Version %s Prerelease', (ROOT / 'src/splash.dfm').read_bytes())
        for name in ('about', 'splash'):
            source = (ROOT / f'src/{name}.pas').read_text()
            self.assertIn('{$I version.inc}', source)
            self.assertIn('VersionLabel.Caption := Format(VersionLabel.Caption, [CalmiraVersion]);', source)
        for path in (ROOT / 'locales/translated').glob('*.json'):
            text = path.read_text(encoding='utf-8')
            catalogue = json.loads(text)
            for form in ('TAboutBox', 'TSplashForm'):
                self.assertIn(' %s', catalogue['Forms'][f'{form}.VersionLabel.Caption'], path.name)
            self.assertNotIn(version, text)
            self.assertNotIn(' 5.0', text)

    def test_descriptor_lists_files_without_archive_wildcards(self):
        descriptor = (ROOT / 'install/install.ini').read_text()
        self.assertNotIn('Archive=', descriptor)
        for line in section(descriptor, 'Files'):
            self.assertNotIn('*', line)

    def test_every_installed_file_has_a_dos_name(self):
        # Setup runs in DOS: RELOAD256.BMP (nine characters) stopped it.
        import re
        descriptor = (ROOT / 'install/install.ini').read_text()
        for line in section(descriptor, 'Files'):
            for path in re.split(r'[|=]', line):
                name = path.replace('/', '\\').split('\\')[-1]
                if not name or name[0].isdigit() and ',' in name or name.isdigit():
                    continue
                if '.' in name or name.isupper():
                    self.assertRegex(name, r'^[^.\s]{1,8}(\.[^.\s]{1,3})?$', line)

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


    def test_helpers_are_not_packed_and_keep_their_icons(self):
        # UPX dropped the resources of the NE helpers: My Computer found no
        # icon in EXPLORER.EXE and showed "Missing icon or destination DC".
        package = (ROOT / 'tools/package.sh').read_text()
        self.assertNotIn('packed/', package)
        self.assertIn('cp "$build/helpers/$helper.EXE" "$stage/"', package)
        self.assertIn('python3 "$root/tools/ne_has_icon.py" "$stage/$helper.EXE"', package)
        makefile = (ROOT / 'makefile').read_text()
        rule = makefile.split('\npackage: ', 1)[1].split('\n', 1)[0]
        self.assertIn('win16-helpers', rule)
        self.assertNotIn('pack-win16', rule)
        checker = (ROOT / 'tools/ne_has_icon.py').read_text()
        self.assertIn('if 14 not in resource_types(stream.read()):', checker)

    def test_setup_chooses_the_windows_95_colours_and_the_wallpaper(self):
        descriptor = (ROOT / 'install/install.ini').read_text(encoding='latin-1')
        options = [line for line in descriptor.splitlines() if line.startswith('Option=')]
        self.assertEqual(options[5], 'Option=on|Use the Windows 95 colour scheme')
        self.assertEqual(options[6], 'Option=on|Use the Calmira Reloaded wallpaper')
        self.assertIn('7|RELOADED.BMP=%WINDIR%\\RELOADED.BMP', descriptor)
        self.assertIn('7|CALM256.BMP=%WINDIR%\\CALM256.BMP', descriptor)
        win_ini = descriptor.split('\n[Win.ini]\n', 1)[1].split('\n[', 1)[0]
        colours = [line for line in win_ini.splitlines() if line.startswith('Set=6|colors|')]
        # All 21 colours of the scheme Calmira adds to CONTROL.INI.
        self.assertEqual(len(colours), 21)
        self.assertIn('Set=6|colors|Background=0 128 128', colours)
        self.assertIn('Set=7|Desktop|Wallpaper=RELOADED.BMP', win_ini)
        self.assertIn('Set=7|Desktop|TileWallpaper=0', win_ini)
        settings = (ROOT / 'src/settings.pas').read_text(encoding='latin-1')
        scheme = settings.split("'Windows 95 standard',", 1)[1].split(');', 1)[0]
        scheme = ''.join(part.strip(" +\r\n'") for part in scheme.split("'"))
        self.assertIn('Set=6|CONTROL.INI|color schemes|Windows 95 standard=' + scheme, descriptor)
        self.assertIn('Set=6|CONTROL.INI|current|color schemes=Windows 95 standard', descriptor)
        package = (ROOT / 'tools/package.sh').read_text()
        self.assertIn('cp "$root/bmp/reloaded.bmp" "$stage/RELOADED.BMP"', package)
        self.assertIn('cp "$root/bmp/calm256.bmp" "$stage/CALM256.BMP"', package)
        # The default is pre-dithered to the 16 VGA colours, which every
        # display shows; Windows maps a 256-colour image on a 16-colour
        # screen to flat areas. Both are uncompressed.
        for name, bits in (('reloaded.bmp', 4), ('calm256.bmp', 8)):
            bitmap = (ROOT / 'bmp' / name).read_bytes()
            self.assertEqual(bitmap[:2], b'BM')
            layout = [int.from_bytes(bitmap[a:b], 'little') for a, b in ((18, 22), (22, 26), (28, 30), (30, 34))]
            self.assertEqual(layout, [1024, 768, bits, 0], name)
        runtime = (ROOT / 'tests/dos/test_package.sh').read_text()
        self.assertIn("fail 'the Windows 95 scheme is not the current one in CONTROL.INI'", runtime)
        self.assertIn('fail "the wallpaper $bitmap remains after uninstall"', runtime)

    def test_shell_is_not_packed_and_shuts_windows_down(self):
        # UPX's NE wrapper runs a temporary ~UPX*.EXE: Calmira did not see
        # itself as the shell, Shut Down ended only Calmira with a GPF.
        package = (ROOT / 'tools/package.sh').read_text()
        self.assertIn('cp "$build/calmira/CALMIRA.EXE" "$stage/"', package)
        self.assertNotIn('packed/shell', package)
        test = (ROOT / 'tests/dos/test_package.sh').read_text()
        for text in ('shot:windows-desktop alt-f4 wait:4 alt-f4 wait:4 ctrl-esc wait:6 shot:windows-ctrl-esc esc wait:4 alt-f4 wait:4 shot:windows-shutdown ret',
                     'ECHO PASS SHUTDOWN>C:\\\\CALSHUT.LOG', "fail 'Shut Down did not return to DOS'"):
            self.assertIn(text, test)

    def test_package_installs_beside_a_grown_system_ini_and_uninstalls_cleanly(self):
        # GDI 1.16.2 ran out of near heap on a 2.5 KB SYSTEM.INI; the DOSLFN
        # line stayed in AUTOEXEC.BAT after INSTALL /U without Remove=.
        ini = (ROOT / 'install/install.ini').read_text()
        self.assertIn('Remove=%DIR%\\DOSLFN\\DOSLFN', ini)
        test = (ROOT / 'tests/dos/test_package.sh').read_text()
        for text in ('Setting%d=a value an update program wrote', "fail 'the DOSLFN line stays in AUTOEXEC.BAT after uninstall'"):
            self.assertIn(text, test)
        self.assertIn('GDI 1.16.3 or newer', (ROOT / 'docs/installer.md').read_text())
    def test_ctrl_esc_opens_the_calmira_task_manager(self):
        # Calmira's help: taskman.exe=CTASKMAN.EXE in [boot]; without it
        # Ctrl+Esc showed the Windows Task List under the Calmira shell.
        ini = (ROOT / 'install/install.ini').read_text()
        system = ini.split('\n[System.ini]\n', 1)[1].split('\n[', 1)[0]
        self.assertIn('Set=4|boot|taskman.exe=%DIR%\\CTASKMAN.EXE', system)
        self.assertIn('CTASKMAN.EXE', section(ini, 'Files'))
        test = (ROOT / 'tests/dos/test_package.sh').read_text()
        for text in ("fail 'Ctrl+Esc does not start the Calmira Task Manager'",
                     "fail 'Ctrl+Esc did not open the Calmira Task Manager'",
                     'sys.exit(0 if longest > 150 else 1)'):
            self.assertIn(text, test)

if __name__ == '__main__':
    unittest.main()
