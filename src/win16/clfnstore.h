/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef CALMIRA_WIN16_LFN_STORE_H
#define CALMIRA_WIN16_LFN_STORE_H
#include <windows.h>
int ClfnReserveSave(LPCSTR name, LPSTR alias);
void ClfnAcceptSave(int slot);
void ClfnCancelSave(int slot);
WORD ClfnPollSaves(void);
WORD ClfnPendingSaves(void);
#endif
