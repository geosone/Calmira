"""Archive add-on packaging without a compiler, VM, network or private media."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('stage_archive', ROOT / 'tools/stage_archive.py')
STAGER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STAGER)


def section(path, name):
    active = False
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith('['):
            active = line.lower() == f'[{name.lower()}]'
        elif active and line and not line.startswith(';'):
            yield line


class ArchivePackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='archive-package-')
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        self.build = self.work / 'build'
        for source in STAGER.PAYLOAD.values():
            path = self.build / source
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(('fixture: ' + source).encode())
        self.installer = self.work / 'gdi/INSTALL.EXE'
        self.installer.parent.mkdir()
        self.installer.write_bytes(b'GDI fixture - not executable')
        self.output = self.work / 'package'

    def test_standalone_descriptor_has_complete_payload_and_licenses(self):
        files = STAGER.stage_archive(self.build, self.output, self.installer)
        self.assertEqual(len(files), 11)
        for line in section(self.output / 'INSTALL.INI', 'Files'):
            self.assertTrue((self.output / line.replace('\\', '/')).is_file(), line)
        setup = dict(line.split('=', 1) for line in section(self.output / 'INSTALL.INI', 'Setup'))
        numbers = setup['License'].split(',')
        self.assertLessEqual(len(numbers), 9)
        for number in numbers:
            path = setup['License' + number].split('|')[-1]
            self.assertTrue((self.output / path.replace('\\', '/')).is_file())
        self.assertEqual((self.output / 'INSTALL.EXE').read_bytes(), self.installer.read_bytes())

    def test_payload_is_byte_identical_and_uses_dos_83_names(self):
        STAGER.stage_archive(self.build, self.output)
        for name, source in STAGER.PAYLOAD.items():
            self.assertEqual((self.output / name).read_bytes(), (self.build / source).read_bytes())
        for path in self.output.rglob('*'):
            self.assertRegex(path.name, r'^[A-Z0-9_]{1,8}(\.[A-Z0-9_]{1,3})?$')

    def test_missing_payload_preserves_existing_package(self):
        self.output.mkdir()
        sentinel = self.output / 'OLFNHOOK.DLL'
        sentinel.write_bytes(b'older valid package')
        (self.build / STAGER.PAYLOAD['OLFNLIST.EXE']).unlink()
        with self.assertRaises(FileNotFoundError):
            STAGER.stage_archive(self.build, self.output, self.installer)
        self.assertEqual(sentinel.read_bytes(), b'older valid package')
        self.assertEqual(list(self.output.iterdir()), [sentinel])

    def test_missing_installer_creates_no_output(self):
        with self.assertRaises(FileNotFoundError):
            STAGER.stage_archive(self.build, self.output, self.work / 'missing.exe')
        self.assertFalse(self.output.exists())

    def test_output_cannot_contain_build_inputs(self):
        with self.assertRaises(ValueError):
            STAGER.stage_archive(self.build, self.build)

    def test_symlink_output_cannot_overwrite_foreign_file(self):
        self.output.mkdir()
        foreign = self.work / 'foreign'
        foreign.write_bytes(b'keep me')
        (self.output / 'OLFNHOOK.DLL').symlink_to(foreign)
        with self.assertRaises(ValueError):
            STAGER.stage_archive(self.build, self.output)
        self.assertEqual(foreign.read_bytes(), b'keep me')

    def test_symlink_license_directory_is_rejected_before_copying(self):
        self.output.mkdir()
        foreign = self.work / 'licenses'
        foreign.mkdir()
        (self.output / 'LICENSES').symlink_to(foreign, target_is_directory=True)
        with self.assertRaises(ValueError):
            STAGER.stage_archive(self.build, self.output)
        self.assertEqual(list(foreign.iterdir()), [])
        self.assertFalse((self.output / 'OLFNHOOK.DLL').exists())

    def test_main_installer_component_is_opt_in_and_does_not_autostart(self):
        descriptor = ROOT / 'install/install.ini'
        options = list(section(descriptor, 'Options'))
        self.assertTrue(options[4].startswith('Option=off|'))
        files = list(section(descriptor, 'Files'))
        for name in ('OLFNHOOK.DLL', 'OLFNLOAD.EXE', 'OLFNVIEW.EXE', 'OLFNLIST.EXE', 'ARCINFO.TXT'):
            self.assertIn('5|' + name, files)
        for name in ('Run', 'Autoexec.bat', 'System.ini'):
            self.assertFalse(any('OLFNLOAD' in line for line in section(descriptor, name)))

    def test_standalone_installer_makes_no_host_configuration_changes(self):
        descriptor = ROOT / 'install/archive.ini'
        for name in ('Run', 'Autoexec.bat', 'Config.sys', 'System.ini', 'HexPatch'):
            self.assertEqual(list(section(descriptor, name)), [])
        self.assertIn('This product uses DOS/32 Advanced DOS Extender technology.',
                      (ROOT / 'install/archive.txt').read_text())

    def test_standalone_product_has_independent_branding(self):
        for name in ('archive.ini', 'archive.txt'):
            text = (ROOT / 'install' / name).read_text()
            self.assertNotIn('calmira', text.lower())
            self.assertIn('OPENLFN', text.upper())
        self.assertEqual({name for name in STAGER.PAYLOAD if '/' not in name},
                         {'OLFNHOOK.DLL', 'OLFNLOAD.EXE', 'OLFNVIEW.EXE', 'OLFNLIST.EXE'})

    def test_distribution_is_reproducible_and_contains_only_manifest_files(self):
        files = STAGER.stage_archive(self.build, self.output, self.installer)
        (self.output / 'PRIVATE.TXT').write_text('must not ship')
        first = self.work / 'first/OPENLFN.ZIP'
        second = self.work / 'second/OPENLFN.ZIP'
        self.assertEqual(STAGER.archive_package(files, first), STAGER.archive_package(files, second))
        self.assertEqual(first.read_bytes(), second.read_bytes())
        with zipfile.ZipFile(first) as bundle:
            self.assertIsNone(bundle.testzip())
            self.assertEqual(set(bundle.namelist()), {'OPENLFN/' + name for name in files})
            for name, source in files.items():
                self.assertEqual(bundle.read('OPENLFN/' + name), source.read_bytes())

    def test_distribution_cannot_overwrite_input(self):
        files = STAGER.stage_archive(self.build, self.output, self.installer)
        original = files['INSTALL.EXE'].read_bytes()
        with self.assertRaises(ValueError):
            STAGER.archive_package(files, files['INSTALL.EXE'])
        self.assertEqual(files['INSTALL.EXE'].read_bytes(), original)

    def test_failed_distribution_preserves_existing_archive(self):
        files = STAGER.stage_archive(self.build, self.output, self.installer)
        archive = self.work / 'OPENLFN.ZIP'
        STAGER.archive_package(files, archive)
        original = archive.read_bytes()
        files['INSTALL.EXE'].unlink()
        with self.assertRaises(FileNotFoundError):
            STAGER.archive_package(files, archive)
        self.assertEqual(archive.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
