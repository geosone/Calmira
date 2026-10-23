"""Controlled-fixture tests of our pinned 7-Zip host reference, not a Win16 port.

Run explicitly with make archive-host-test. Ordinary make test stays independent
of C++ toolchains and initialized archive sources. No proprietary media needed.
"""
import gzip
import hashlib
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
import zipfile


class ArchiveHostAcceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.backend = Path(os.environ["SEVENZIP_HOST"]).resolve(strict=True)
        cls.temporary = tempfile.TemporaryDirectory(prefix="archive-reference-", dir="build/tests")
        cls.work = Path(cls.temporary.name).resolve()
        cls.payload = b"Calmira read-only archive reference\r\n"

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def command(self, *args):
        return subprocess.run(
            [str(self.backend), *map(str, args)], cwd=self.work,
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=15, check=False,
        )

    def listing(self, path, expected):
        before = hashlib.sha256(path.read_bytes()).digest()
        files_before = set(self.work.rglob("*"))
        result = self.command("l", "-ba", "-slt", "-sccUTF-8", "-bsp0", "-bd",
                              "-pCalmiraReferenceWrongPassword", "--", path)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertIn(expected.encode("utf-8"), result.stdout)
        self.assertEqual(hashlib.sha256(path.read_bytes()).digest(), before)
        self.assertEqual(set(self.work.rglob("*")), files_before, "listing must not extract entries")

    def test_zip_stored(self):
        path = self.work / "stored.zip"
        with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as archive:
            archive.writestr("stored.txt", self.payload)
        self.listing(path, "Path = stored.txt")

    def test_zip_deflate_unicode(self):
        path = self.work / "unicode.zip"
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("Berichte/Grüße 2026.txt", self.payload)
        self.listing(path, "Path = Berichte/Grüße 2026.txt")

    def test_zip_listing_never_extracts_traversal_names(self):
        path = self.work / "unsafe-names.zip"
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("../outside.txt", self.payload)
            archive.writestr("/absolute.txt", self.payload)
        self.listing(path, "outside.txt")

    def test_tar(self):
        path = self.work / "reference.tar"
        with tarfile.open(path, "w") as archive:
            entry = tarfile.TarInfo("reference.txt")
            entry.size = len(self.payload)
            archive.addfile(entry, io.BytesIO(self.payload))
        self.listing(path, "Path = reference.txt")

    def test_gzip(self):
        path = self.work / "reference.txt.gz"
        path.write_bytes(gzip.compress(self.payload, mtime=0))
        self.listing(path, "Path = reference.txt")

    def test_7z(self):
        source = self.work / "reference.txt"
        source.write_bytes(self.payload)
        path = self.work / "reference.7z"
        result = self.command("a", "-t7z", "-mx1", "-bd", "--", path, source.name)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.listing(path, "Path = reference.txt")

    def test_invalid_archive_fails_without_prompt(self):
        path = self.work / "corrupt.zip"
        path.write_bytes(b"PK\x03\x04not a valid ZIP directory")
        result = self.command("l", "-bd", "-pCalmiraReferenceWrongPassword", "--", path)
        self.assertNotEqual(result.returncode, 0)

    def test_encrypted_headers_fail_without_prompt(self):
        source = self.work / "secret.txt"
        source.write_bytes(self.payload)
        path = self.work / "encrypted.7z"
        result = self.command("a", "-t7z", "-mhe=on", "-pFixturePasswordOnly", "-bd",
                              "--", path, source.name)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        result = self.command("l", "-bd", "-pCalmiraReferenceWrongPassword", "--", path)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
