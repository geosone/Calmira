"""Scope guards for the private Win16 heap shrink correction."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReallocTests(unittest.TestCase):
    def test_copy_is_bounded_by_both_old_and_new_allocation(self):
        patch = (ROOT / 'tools/patches/fpc-win16-realloc-bounds.patch').read_text()
        for text in ('CALMIRA_WIN16_REALLOC_BOUNDS', 'CopySize:=SysGlobalMemSize(p)',
                     'if CopySize>size then', 'CopySize:=size', 'Move(p^,result^,CopySize)'):
            self.assertIn(text, patch)
        self.assertIn('{$else CALMIRA_WIN16_REALLOC_BOUNDS}', patch)
        self.assertIn('Move(p^,result^,SysGlobalMemSize(p))', patch)

    def test_private_preparation_and_builder_enable_the_scoped_patch(self):
        prepare = (ROOT / 'tools/prepare_win16_rtl.py').read_text()
        build = (ROOT / 'tools/build_win16_rtl.sh').read_text()
        self.assertIn('fpc-win16-realloc-bounds.patch', prepare)
        self.assertIn('-dCALMIRA_WIN16_REALLOC_BOUNDS', build)

    def test_native_probe_requires_a_real_adjacent_live_guard(self):
        source = (ROOT / 'tests/pascal/test_win16_realloc.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'Ofs(Guard^) = Ofs(Hole^) + 20', 'Block = HoleAddress',
                     'ReAllocMem(Block, 16)', 'shrink does not overwrite neighboring live allocation',
                     'if Intact then begin FreeMem(Block); FreeMem(Guard); end;'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-realloc-runtime-test \\', make)
        self.assertIn('win16-realloc-runtime-test: win16-realloc', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-realloc/GDITEST.EXE', make)

    def test_native_probe_covers_small_and_direct_global_resize_branches(self):
        source = (ROOT / 'tests/pascal/test_win16_realloc.pas').read_text()
        for text in ('ReAllocMem(Data, 0)', 'ReAllocMem(Data, 31)',
                     'ResizeCase(511, 1)', 'ResizeCase(255, 15)',
                     'ResizeCase(1021, 255)', 'ResizeCase(16, 511)',
                     'ResizeCase(511, 2048)', 'ResizeCase(2048, 32)',
                     'ResizeCase(2048, 4096)', 'if Kept > NewSize then Kept := NewSize',
                     'if DataOkay and NeighborOkay then',
                     'if Intact and PrefixIntact then ResizeBranches'):
            self.assertIn(text, source)
