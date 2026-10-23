"""Owned source names are lowercase; historical and runtime names are exempt."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('lowercase_paths', ROOT / 'tools/lowercase_paths.py')
NORMALIZE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NORMALIZE)


class RepositoryPathsTests(unittest.TestCase):
    def test_owned_source_tree_is_lowercase(self):
        for directory in NORMALIZE.OWNED:
            for path in (ROOT / directory).rglob('*'):
                if '__pycache__' not in path.parts:
                    self.assertEqual(path.name, path.name.lower(), str(path))

    def test_protected_trees_and_agent_instructions_are_not_owned(self):
        for name in ('vendor/reference/README.md', 'archives/SHA256SUMS',
                     'build/CALMIRA.EXE', 'AGENTS.md'):
            self.assertFalse(NORMALIZE.owned(Path(name)))

    def test_case_collision_is_rejected_before_renaming(self):
        with self.assertRaises(ValueError):
            NORMALIZE.plan([Path('src/EXAMPLE.PAS'), Path('src/example.pas')])

    def test_binary_contents_are_never_rewritten(self):
        before = b'\x00src/EXAMPLE.PAS'
        self.assertEqual(NORMALIZE.rewrite(before, Path('src/picture.dfm'),
                         {'src/EXAMPLE.PAS': 'src/example.pas'}, set()), before)

    def test_generated_license_names_are_not_substring_replacements(self):
        before = b'LICENSES DOS32A-LICENSE.txt LICENSED'
        self.assertEqual(NORMALIZE.rewrite(before, Path('tools/example.py'),
                         {'LICENSE': 'license'}, set()), before)

    def test_vendor_pathlib_expressions_keep_original_case(self):
        before = b'ROOT / "vendor/build-deps/LOCK"'
        self.assertEqual(NORMALIZE.rewrite(before, Path('tests/example.py'),
                         {}, {'vendor/build-deps/LOCK'}), before)

    def test_pascal_resources_and_source_paths_are_lowercase(self):
        before = b"{$R *.DFM}\r\nExample in 'EXAMPLE.PAS'; src/EXAMPLE.PAS"
        after = NORMALIZE.rewrite(before, Path('src/main.dpr'),
                                  {'src/EXAMPLE.PAS': 'src/example.pas'}, set())
        self.assertEqual(after, b"{$R *.dfm}\r\nExample in 'example.pas'; src/example.pas")
