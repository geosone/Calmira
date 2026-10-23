/* Win3.11 acceptance: the same FPC executable loads each selected catalogue. */
#include <windows.h>
#include <stdio.h>
#include <string.h>

static void pump(void)
{
    MSG msg;
    while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    Yield();
}

int PASCAL WinMain(HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show)
{
    FILE *log = fopen("C:\\LANGTEST.LOG", "w");
    char code[9], title[128], button[40];
    const char *expected_title, *expected_button;
    HWND window = NULL;
    DWORD start;
    int okay;
    FILE *config;
    char line[80];
    (void)inst; (void)prev; (void)cmd; (void)show;
    if (!log) return 2;
    strcpy(code, "en");
    config = fopen("C:\\LANGTEST\\CALMIRA.INI", "r");
    if (config) {
        while (fgets(line, sizeof(line), config))
            if (!strncmp(line, "Selected=", 9))
                sscanf(line + 9, "%8s", code);
        fclose(config);
    }
    expected_title = !strcmp(code, "de") ? "Calmira Laufwerkstest" :
        !strcmp(code, "fr") ? "Test des lecteurs Calmira" : "Calmira Drive Probe";
    expected_button = !strcmp(code, "de") ? "Aktualisieren" :
        !strcmp(code, "fr") ? "Actualiser" : "Refresh";
    if (WinExec("C:\\LANGTEST\\DRVPROBE.EXE", SW_SHOW) < 32) {
        fputs("RESULT FAIL: cannot launch language test probe\n", log);
        fclose(log);
        return 1;
    }
    start = GetTickCount();
    while (GetTickCount() - start < 8000UL && !window) {
        pump();
        window = FindWindow("CalmiraDriveProbe", NULL);
    }
    title[0] = button[0] = 0;
    if (window) {
        GetWindowText(window, title, sizeof(title));
        GetWindowText(GetDlgItem(window, 102), button, sizeof(button));
    }
    okay = window && !strcmp(title, expected_title) && !strcmp(button, expected_button);
    fprintf(log, "Language=%s\nTitle=%s\nButton=%s\nRESULT %s\n",
        code, title, button, okay ? "PASS" : "FAIL");
    fflush(log);
    start = GetTickCount();
    while (GetTickCount() - start < 6000UL) pump();
    if (window) PostMessage(window, WM_CLOSE, 0, 0);
    fclose(log);
    return okay ? 0 : 1;
}
