@echo off
if "%TempScript%"=="" goto scripterr
if "%1"=="" goto help
if "%1"=="/?" goto help

echo Start > %TempScript%
cd >> %TempScript%
echo %1 %2 %3 %4 %5 %6 %7 %8 %9 >> %TempScript%
ren %TempScript% calmira.run
goto end

:help
echo.
echo START executes a command using Windows.  You can type the name of a 
echo Windows program, an MS-DOS program (to run it in a new DOS window), 
echo or a document file.  You can omit the full pathname of files 
echo in the current directory.
echo.
echo Syntax:  START filename [parameter1] [parameter2] ...
echo.
echo Example: START notepad c:\autoexec.bat /p
goto end

:scripterr
echo.
echo There is no temporary script filename in the environment.
echo You need to set the Tempscript environment variable to point
echo to a suitable file.  See the Calmira help file topic on
echo Using Script Files for more details.

:end
echo.

