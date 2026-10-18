from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SourceContractTests(unittest.TestCase):
    def test_patched_omf_sources_are_vendored(self):
        lock = (ROOT / "vendor/build-deps/LOCK").read_text(encoding="utf-8")
        self.assertIn("e9462f17b86dbe04a27ecdd4e56329096ba9831e", lock)
        self.assertIn("c3f7e93777bdffa36ba8d9e2e538510481179002", lock)
        self.assertTrue((ROOT / "vendor/build-deps/geosone-jwasm/GccUnix.mak").is_file())
        self.assertTrue((ROOT / "vendor/build-deps/geosone-jwlink/GccUnix.mak").is_file())
        self.assertFalse((ROOT / "vendor/build-deps/geosone-jwasm/.git").exists())
        self.assertFalse((ROOT / "vendor/build-deps/geosone-jwlink/.git").exists())

    def test_winfile_fork_is_the_hotplug_submodule(self):
        modules = (ROOT / ".gitmodules").read_text(encoding="utf-8")
        self.assertIn("https://github.com/geosone/winfile.git", modules)
        self.assertIn("branch = calmira-hotplug", modules)

    def test_native_winfile16_has_drive_polling(self):
        source = (ROOT / "src/win16/winfile16.pas").read_text(encoding="utf-8")
        self.assertIn("GetDriveType", source)
        self.assertIn("WM_TIMER", source)
        self.assertIn("PollIntervalMs", source)

    def test_no_inno_setup_in_active_package(self):
        self.assertFalse((ROOT / "CALMIRA.ISS").exists())
        descriptor = (ROOT / "install" / "INSTALL.INI").read_text()
        self.assertNotIn("Inno", descriptor)

    def test_generic_media_logic_has_no_gui_dependency(self):
        source = (ROOT / "src" / "portable" / "drivechange.pas").read_text()
        for forbidden in ("Forms", "WinProcs", "WinTypes", "Controls"):
            self.assertNotIn(forbidden, source)

    def test_virtual_lfn_core_is_portable_and_description_based(self):
        source = (ROOT / "src" / "portable" / "virtual_lfn.pas").read_text()
        self.assertIn("DESCRIPT.ION", source)
        self.assertIn("MakeDosAlias", source)
        for forbidden in ("Forms", "WinProcs", "WinTypes", "Controls"):
            self.assertNotIn(forbidden, source)

    def test_toolchain_sources_are_pinned_clones(self):
        for name in ("freepascal", "open-watcom-v2", "jwasm", "jwlink"):
            self.assertTrue((ROOT / "vendor" / "reference" / name / ".git").exists())


if __name__ == "__main__":
    unittest.main()
