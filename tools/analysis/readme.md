# Local Win16 Binary Inspection

`inspectwin16.java` is a Ghidra post-analysis script, tested with Ghidra 12.1.4
and Java 21. It inventories imported libraries, external symbols and all
recognized functions, then attempts to decompile selected hook/LFN entry
points. It skips external/thunk memory. It does not recover original source
or trustworthy C prototypes automatically.

Keep legally supplied binaries, project databases, inventories and generated
decompiler output under ignored `build/`. Do not commit proprietary binaries,
registration information or generated proprietary pseudocode as project code.

For a new local project (create the parent directories first):

```sh
bash /usr/share/ghidra/support/analyzeHeadless build/analysis/project Reference \
  -import /path/to/local/IFALFN.DLL -analysisTimeoutPerFile 120 -max-cpu 2 \
  -scriptPath tools/analysis -postScript inspectwin16.java "$PWD/build/analysis/output"
```

The installed Gentoo headless script is not executable; invoking it through
`bash` avoids changing system permissions. Open the resulting `.gpr` project
with Ghidra for manual inspection. Win16 far pointers, segment registers,
import stubs and Pascal argument cleanup need manual validation. Failed
decompilations are recorded as warnings, not silently presented as source.

The public [IFA findings](../../docs/ifa_analysis.md) describe behavior and
module boundaries for an independent implementation.

For native UI observation without decompilation, `make window-inventory`
builds `build/win16/diagnostics/WININV.EXE`. Run it with an optional application
command in a disposable VM. It periodically replaces `C:\WINTREE.LOG` with
visible classes, module paths, control IDs, coordinates, captions and direct
WM_GETTEXT results. It does not send private control messages or modify the
application. The log can contain document names and edit contents: retain it
under ignored `build/`, not in commits. See [Office observations](../../docs/office_dialog_tests.md).
