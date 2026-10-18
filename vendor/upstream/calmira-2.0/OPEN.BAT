@echo off
if "%TempScript%"=="" goto scripterr
if "%1"=="" goto folder
if "%1"=="/?" goto help
direxist %1
if errorlevel 1 goto folder

:start
echo Start > %TempScript%
cd >> %TempScript%
echo %1 %2 %3 %4 %5 %6 %7 %8 %9 >> %TempScript%
ren %TempScript% calmira.run
goto end

:folder
echo Folder > %TempScript%
cd >> %TempScript%
if "%1"=="" goto UseCurrentDir
echo %1 >> %TempScript%
goto Exec

:UseCurrentDir
cd >> %TempScript%

:Exec
ren %TempScript% calmira.run
goto end


:help
echo.
echo The OPEN command can start a program, open a document, or open
echo a folder.  If no parameter is specified, the current directory 
echo is opened.  You can omit the the full pathname of files and 
echo folders that are in the current directory. 
echo.
echo Syntax:  OPEN filename [parameter1] [parameter2] ...
echo          OPEN foldername
echo          OPEN
echo.
echo Example: OPEN notepad c:\autoexec.bat /p
echo          OPEN c:\windows
goto end

:scripterr
echo.
echo There is no temporary script filename in the environment.
echo You need to set the Tempscript environment variable to point
echo to a suitable file.  See the Calmira help file topic on
echo Using Script Files for more details.

:end
echo.

