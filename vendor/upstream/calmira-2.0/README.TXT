{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.0                                                    }
{    Copyright (C) 1997  Li-Hsin Huang                                     }
{                                                                          }
{    This program is free software; you can redistribute it and/or modify  }
{    it under the terms of the GNU General Public License as published by  }
{    the Free Software Foundation; either version 2 of the License, or     }
{    (at your option) any later version.                                   }
{                                                                          }
{    This program is distributed in the hope that it will be useful,       }
{    but WITHOUT ANY WARRANTY; without even the implied warranty of        }
{    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         }
{    GNU General Public License for more details.                          }
{                                                                          }
{    You should have received a copy of the GNU General Public License     }
{    along with this program; if not, write to the Free Software           }
{    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.             }
{                                                                          }
{**************************************************************************}


Calmira is a Windows 95 user interface for Windows 3.1.  It's a fully 
integrated environment for managing your files and programs, and 
is designed to run smoothly on 386 and 486 computers.

Calmira includes:

o  An icon based explorer to manage files in free floating windows
o  Support for 4DOS file descriptions in place of long filenames
o  Desktop and file based shortcuts to any object or URL
o  Explorer tree that lets you navigate faster through disks
o  Taskbar with versatile Start Menu, nested to any level
o  Wastepaper bin to store deleted files and folders
o  Hundreds of easily accessible options and settings
o  80 page on-line manual containing all the help you'll need

Version 2.0 is more stable, has a cleaner display, a more consistent 
and flexible interface, better graphics, extended file handling, and 
command prompt support to control Windows from an MS-DOS box.  

Once you get used to the new look and feel of your Windows 3.1,
you'll never want to turn back...


System requirements
-------------------

o  386 processor or higher
o  Microsoft Windows 3.1 or Windows for Workgroups 3.11
o  At least 4 megabytes (MB) of memory
o  A VGA monitor or better
o  A mouse


Installation
------------

Full installation instructions are contained in the help file.
To dive straight in, unzip the main ZIP file you received into a
directory on your hard disk, and run CALMIRA.EXE.



Contacts
--------

Post  : Li-Hsin Huang
        59 Bromefield
        Stanmore
        Middlesex HA7 1AG
        England, UK

Email : lhh@tribbles.demon.co.uk
Web   : www.tribbles.demon.co.uk/calmira/


Latest information
==================

OPEN batch command
------------------

In addition to START.BAT, FOLDER.BAT and EXPLORE.BAT mentioned in
the Calmira help file, the newer Open.bat replaces both Start and 
Folder commands.  It requires the supplied DIREXIST.EXE utility to 
detect the existence of a directory.

To use Open, copy OPEN.BAT and DIREXIST.EXE into a directory on the
MS-DOS path.  Type Open /? for details.  You can use it to open
folders, programs or documents, and it will determine the most
sensible choice.

DIREXIST.EXE returns an errorlevel of 1 if the directory parameter
exists.  All root directories are considered to exist, even if the
drive is invalid.  The Turbo Pascal source code is included.


Icon caption colour problem
---------------------------

The Known Issues section describes the caption of focused icons
changing to the highlighted text colour.  This has been fixed.


Creating aliases from the Computer window
-----------------------------------------

If the "Confirm new alias" prompt has been turned off, Calmira tries
to create the alias files in the root directory of drive C:.  You can
turn the prompt on to specify the path, or create the alias manually by
choosing Create Alias from an icon window's popup menu.


Taskbar doesn't popup over maximized windows
--------------------------------------------

If this happens, try setting ShowNoActivate=0 in the [Taskbar]
section of the INI file.  This may also prevent other programs from
overlapping and obscuring the taskbar.


"Deleting" files directly to the bin
------------------------------------

In case you missed the note in the help file, this feature currently
works from icon windows, not the Explorer tree or Find Files dialog.


Open Folder command from Desktop menu
-------------------------------------

Some examples of what you can type:

Fully qualified folder name: c:\programs ---> c:\programs
Leading backslash:           \programs   ---> c:\programs
No leading punctuation:      programs    ---> c:\programs

When Calmira needs to fill in the full path, it uses the drive
on which Windows is installed.  This is because the "current directory"
has little meaning since Calmira operates across all drives.

Note that this is different from the Open batch file. If you type
"Open programs" at the DOS prompt, Calmira assumes that you want to
open the "programs" directory in the current directory (which now has
a meaning).


Maximized window movement
-------------------------

The Known Issues section states that maximized windows can still be
moved when they are fitted above the Taskbar.  This has been fixed,
but the fix causes Microsoft Word for Windows 2.0 to open its help
file when you try to move its maximized window, and is due to an
unusual response from Word.  Other applications should to behave
correctly.


Script format has changed since Final Beta
------------------------------------------

The Folder script key word now requires a working directory as the
first parameter, followed by the folder to open.  This allows Calmira
to open sub-directories at the DOS prompt without the full pathname.


Change in [Programs] section format
-----------------------------------

Calmira 1.0 would assume that all programs without a specified
path are in its home directory.  Now, all entries require a path,
which can contain environment variables.


Folder names must not contain trailing spaces
---------------------------------------------

When you use an "open folder" style command from anywhere within
Calmira, make sure that there are no trailing spaces in the folder
name.  For example "c:\games" is OK, but "c:\games " may cause
problems because MS-DOS can find the directory, but the contents
will not be accessible when Calmira appends a filename to the
latter path.


Activating icons in the Computer window
---------------------------------------

When you double click on an icon in the Computer, you should not 
move the cursor out of the window until the program has finished
loading.  If you move the cursor over the desktop during the load,
a shortcut may be created because the program start-up has 
interrupted mouse messages, and Calmira believes that you are
still dragging.


Updating Start Menu bitmaps
---------------------------

In Calmira 1.0, the Start Menu's bitmap cache is updated every
time a menu item is modified.  In Calmira 2.0, the updating is
"smart" so that if you only change the caption, working folder
or show mode, the cache is not refreshed.  If you have changed
icons or bitmaps used for the menu, you must either edit an icon
or command field or click on the Rebuild checkbox (twice if it
is already checked).


Compiled EXE file sizes
-----------------------

When you re-compile the executable files, they may be bigger than
the distributed binaries because the linker optimisation has been
turned off in the project file.


