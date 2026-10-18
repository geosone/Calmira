@echo off
if "%TempScript%"=="" goto scripterr
if "%1"=="/?" goto help

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
echo FOLDER opens an icon window of the specified directory.  
echo If no directory is specified, the current one is used.  You 
echo can omit the full pathname of folders in the current directory.
echo.
echo Syntax:  FOLDER [directory]
echo.
echo Example: FOLDER c:\windows
goto end

:scripterr
echo.
echo There is no temporary script filename in the environment.
echo You need to set the Tempscript environment variable to point
echo to a suitable file.  See the Calmira help file topic on
echo Using Script Files for more details.

:end
echo.

