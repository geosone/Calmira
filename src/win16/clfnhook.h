/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef CALMIRA_LFN_HOOK_H
#define CALMIRA_LFN_HOOK_H
#include <windows.h>
#define CLFN_LIST_ID 0x6f10
BOOL WINAPI StartFileDialogHook(void);
BOOL WINAPI StopFileDialogHook(void);
WORD WINAPI FileDialogHookCount(void);
DWORD WINAPI FileDialogHookDiagnostics(void);
WORD WINAPI PollFileDialogSaves(void);
WORD WINAPI PendingFileDialogSaves(void);
/* The resident owner must poll periodically. Stop refuses pending work;
 * it must not unload the DLL simply because a file dialog has closed. */
#endif
