"""Same bounded 7-Zip reader on host and DOS; no extraction or external media."""
import argparse
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zipfile
import zlib


def fixtures(folder):
    folder.mkdir(parents=True, exist_ok=True)
    cases = {}

    def write(stem, names, method=zipfile.ZIP_STORED, success=True):
        with zipfile.ZipFile(folder / (stem + ".ZIP"), "w", method) as archive:
            for name in names:
                archive.writestr(name, b"Calmira archive fixture\r\n" if not name.endswith("/") else b"")
        cases[stem] = success

    write("STORED", ["folder/", "folder/hello.txt"])
    write("DEFLATE", ["Grüße 2026.txt", "line\nPath = fake.txt"], zipfile.ZIP_DEFLATED)
    write("EMPTY", [])
    write("PATHS", ["../outside.txt", "/absolute.txt", "C:/drive.txt", "a\\b.txt"])
    write("MAXCOUNT", [f"f{i:03}.txt" for i in range(128)])
    write("BIGCOUNT", [f"f{i:03}.txt" for i in range(129)], success=False)
    write("LONGOK", ["a" * 240])
    write("LONGNAME", ["a" * 241], success=False)
    write("LEGACY", ["a.txt"])
    path = folder / "LEGACY.ZIP"
    path.write_bytes(path.read_bytes().replace(b"a.txt", b"\x82.txt"))
    write("BADUTF", ["a.txt"], success=False)
    path = folder / "BADUTF.ZIP"
    raw = bytearray(path.read_bytes().replace(b"a.txt", b"\xff.txt"))
    struct.pack_into("<H", raw, 6, 0x800)
    struct.pack_into("<H", raw, raw.index(b"PK\x01\x02") + 8, 0x800)
    path.write_bytes(raw)
    alias = b"GRUSS~1.TXT"
    display = "Grüße aus Köln.txt".encode("utf-8")
    item = zipfile.ZipInfo(alias.decode("ascii"))
    item.extra = struct.pack("<HHBI", 0x7075, len(display) + 5, 1, zlib.crc32(alias)) + display
    with zipfile.ZipFile(folder / "UNICODEX.ZIP", "w") as archive:
        archive.writestr(item, b"Unicode extra fixture\r\n")
    cases["UNICODEX"] = True
    with zipfile.ZipFile(folder / "MEMLIMIT.ZIP", "w") as archive:
        for i in range(128):
            entry = zipfile.ZipInfo(f"f{i}.txt")
            entry.comment = b"x" * 65535
            archive.writestr(entry, b"")
    cases["MEMLIMIT"] = False
    (folder / "BAD.ZIP").write_bytes(b"PK\x03\x04broken archive")
    cases["BAD"] = False
    return cases


def decode(path):
    data = path.read_bytes()
    if len(data) < 24 or len(data) > 33816 or data[:8] != b"CLARCI1\0" or data[-4:] != b"END!":
        raise ValueError("index framing")
    count, kind, payload = struct.unpack_from("<HHI", data, 8)
    if count > 128 or kind != 1 or payload != len(data) - 24:
        raise ValueError("index limits")
    if zlib.crc32(data[:-8]) != struct.unpack_from("<I", data, len(data) - 8)[0]:
        raise ValueError("index CRC")
    entries, pos = [], 16
    for _ in range(count):
        length, flags, unpacked, packed, method, reserved = struct.unpack_from("<HHQQHH", data, pos)
        if not 0 < length <= 240 or flags & ~7 or reserved:
            raise ValueError("record fields")
        pos += 24
        name = data[pos:pos + length]
        if len(name) != length or b"\0" in name:
            raise ValueError("record name")
        if flags & 4:
            name.decode("utf-8", errors="strict")
        entries.append((name, flags, unpacked, packed, method))
        pos += length
    if pos != len(data) - 8:
        raise ValueError("record boundary")
    return entries


class ArchiveReaderAcceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.backend = Path(os.environ["ARCHIVE_READER"]).resolve(strict=True)
        cls.temporary = tempfile.TemporaryDirectory(prefix="archive-reader-", dir="build/tests")
        cls.work = Path(cls.temporary.name).resolve()
        cls.cases = fixtures(cls.work)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def run_case(self, stem):
        source = self.work / (stem + ".ZIP")
        output = self.work / (stem + ".IDX")
        before = hashlib.sha256(source.read_bytes()).digest()
        result = subprocess.run([str(self.backend), str(source), str(output)],
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=20, check=False)
        self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), before)
        return result, output

    def test_all_fixtures(self):
        for stem, success in self.cases.items():
            with self.subTest(stem=stem):
                result, output = self.run_case(stem)
                if not success:
                    self.assertIn(result.returncode, (3, 4, 5), result.stderr.decode(errors="replace"))
                    self.assertFalse(output.exists())
                    continue
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                entries = decode(output)
                if stem == "UNICODEX":
                    self.assertEqual(entries[0][0], "Grüße aus Köln.txt".encode("utf-8"))
                    self.assertTrue(entries[0][1] & 4)
                if stem == "DEFLATE":
                    self.assertEqual(entries[0][0], "Grüße 2026.txt".encode("utf-8"))
                    self.assertEqual(entries[1][0], b"line\nPath = fake.txt")
                    self.assertEqual(entries[0][4], 8)
                if stem == "LEGACY":
                    self.assertEqual(entries[0][0], b"\x82.txt")
                    self.assertFalse(entries[0][1] & 4)
                if stem == "MAXCOUNT":
                    self.assertEqual(len(entries), 128)

    def test_existing_output_is_never_overwritten(self):
        source = self.work / "STORED.ZIP"
        output = self.work / "KEEP.IDX"
        output.write_bytes(b"foreign file must remain unchanged")
        result = subprocess.run([str(self.backend), str(source), str(output)],
                                stdin=subprocess.DEVNULL, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 6)
        self.assertEqual(output.read_bytes(), b"foreign file must remain unchanged")

    def test_nonregular_input_is_rejected_without_blocking(self):
        fifo = self.work / "PIPE.ZIP"
        os.mkfifo(fifo)
        output = self.work / "PIPE.IDX"
        result = subprocess.run([str(self.backend), str(fifo), str(output)],
                                stdin=subprocess.DEVNULL, capture_output=True, timeout=3)
        self.assertEqual(result.returncode, 4)
        self.assertFalse(output.exists())

    def test_oversized_input_is_rejected(self):
        source = self.work / "LARGE.ZIP"
        with source.open("wb") as stream:
            stream.truncate(64 * 1024 * 1024 + 1)
        output = self.work / "LARGE.IDX"
        result = subprocess.run([str(self.backend), str(source), str(output)],
                                stdin=subprocess.DEVNULL, capture_output=True, timeout=3)
        self.assertEqual(result.returncode, 4)
        self.assertFalse(output.exists())


def generate_dos(folder):
    cases = fixtures(folder)
    lines = ["@ECHO OFF"]
    for stem, success in cases.items():
        lines += [f"C:\\OLFNLIST.EXE C:\\{stem}.ZIP C:\\{stem}.IDX >>C:\\DOSOUT.LOG"]
        if success:
            lines += [f"IF ERRORLEVEL 1 ECHO FAIL {stem}>>C:\\ARCTEST.LOG"]
        else:
            lines += [f"IF ERRORLEVEL 6 ECHO FAIL {stem}>>C:\\ARCTEST.LOG",
                      f"IF NOT ERRORLEVEL 3 ECHO FAIL {stem}>>C:\\ARCTEST.LOG"]
    lines += ["ECHO foreign-output>C:\\KEEP.IDX", "C:\\OLFNLIST.EXE C:\\STORED.ZIP C:\\KEEP.IDX",
              "IF NOT ERRORLEVEL 1 ECHO FAIL overwrite>>C:\\ARCTEST.LOG",
              "C:\\OLFNLIST.EXE CON C:\\DEVICE.IDX",
              "IF NOT ERRORLEVEL 1 ECHO FAIL device>>C:\\ARCTEST.LOG", "ECHO DONE>>C:\\ARCTEST.LOG"]
    (folder / "AUTOEXEC.BAT").write_bytes(("\r\n".join(lines) + "\r\n").encode("ascii"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixtures", type=Path)
    args = parser.parse_args()
    if args.fixtures:
        generate_dos(args.fixtures)
    else:
        unittest.main(argv=[__file__], verbosity=2)
