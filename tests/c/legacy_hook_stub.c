/* SPDX-License-Identifier: GPL-3.0-or-later
 * Inert legacy module identity for the duplicate-hook rejection test. */
#include <windows.h>
int FAR PASCAL LibMain(HINSTANCE instance, WORD data, WORD heap, LPSTR command)
{
    (void)instance; (void)data; (void)heap; (void)command;
    return 1;
}
int FAR PASCAL __export WEP(int reason)
{
    (void)reason;
    return 1;
}
