MKDIR RELEASE
CD RELEASE
COPY ..\src\CALMIRA.EXE .
COPY ..\help\calmira.hlp .
COPY ..\src\calmira.ini .
TPC ..\src\counttip.pas
COPY ..\src\COUNTTIP.EXE .
COPY ..\src\CTASKMAN.EXE .
TPC ..\src\direxist.pas
COPY ..\src\DIREXIST.EXE .
TPC ..\src\dosrun.pas
COPY ..\src\DOSRUN.EXE .
COPY ..\src\EXPLORER.EXE .
COPY ..\LICENSE LICENSE.TXT
COPY ..\README.MD README.TXT
COPY ..\src\SCRNSAVE.EXE .
COPY ..\src\SHOWDESK.EXE .
COPY ..\bmp\shutdown.bmp .
COPY ..\src\start.bat .
COPY ..\src\start.ini .
COPY ..\src\tips.txt .
COPY ..\src\WNDHOOKS.DLL .
MKDIR SYSTEM
COPY ..\build\win16\ctl3d\CTL3DV2.DLL SYSTEM
MKDIR LICENSES
COPY ..\vendor\build-deps\open386max-ctl3d\LICENSE LICENSES\CTL3D.TXT
COPY ..\src\LFNFUNCS.DLL SYSTEM
MKDIR TRAY
COPY ..\src\tray\explorer.als TRAY
COPY ..\src\tray\notepad.als TRAY
COPY ..\src\tray\showdesk.als TRAY
CD ..
