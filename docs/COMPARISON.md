# Initial Source Comparison

Reborn is the integration baseline because its first commit imports LFN 3.32
and its later commits isolate useful fixes: GDI leak reductions, taskbar GPF
prevention, Windows 3.11 version detection, non-English desktop fixes and an
Explorer drive-change correction.

`python3 tools/compare_upstreams.py` compares case-insensitive paths and hashes
text after line-ending normalization. Against Reborn's 149 source/text files:

| Version | Files | Identical | Changed | Only version | Only Reborn |
|---|---:|---:|---:|---:|---:|
| 3.3 | 132 | 53 | 79 | 0 | 17 |
| LFN 3.32 | 146 | 71 | 74 | 1 | 4 |
| LFN German | 183 | 41 | 104 | 38 | 4 |
| XP 3.33 | 137 | 35 | 96 | 6 | 18 |
| French 3.3 | 134 | 5 | 126 | 3 | 18 |

## Merge Candidates

- **Keep now:** Reborn's complete LFN layer (`LFNFUNCS.DLL`, `LFN_FNS.PAS`,
  `LFNUTILS.PAS`) and all post-import bug fixes.
- **Review next:** XP's `CHANGBMP`, `XPPROP` and `XPBUTTON` as optional,
  theme-neutral features; do not replace the baseline UI wholesale.
- **Extract, do not fork:** German/French strings and the French translation
  helper (`TRAD`) into a future locale layer.
- **Audit:** the 3.1 beta `CFS*` units and older `EXPLRWIN` implementation for
  capabilities later removed; port only behavior with tests.
- **Reference only:** Mark Stroberg's binary LFN branch and Microsoft WinFile.

The comparison is intentionally structural first. Each selected feature still
needs a behavioral test in Windows for Workgroups 3.11 before merging.

