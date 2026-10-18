{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.2                                                    }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
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

Version 2.2 contains an enhanced taskbar, a built-in task manager
and cut-and-paste file operations, amongst many other improvements.

Once you get used to the new look and feel of your Windows 3.1,
you'll never want to turn back...


System requirements
-------------------

o  386 processor or higher
o  Microsoft Windows 3.1 or Windows for Workgroups 3.11
o  At least 4 megabytes (MB) of memory, 8MB recommended
o  A VGA monitor or better
o  A mouse


Installation
------------

Full installation instructions are contained in the help file.
For a quick start, unzip the main ZIP file you received into a
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


============================================================================
                            Last minute notes
============================================================================


Tip colour -- you can change this by setting HintColor in the [Calmira]
section.  The default is the hexadecimal number $00F0FBFF.

Desktop activation -- in previous versions, all Calmira windows are
brought forward if you do a left+right click on the desktop.  Now, if
the "Treat Calmira windows as separate tasks" checkbox is turned on
in the Desktop Properties dialog, then only shortcut icons are exposed.
You can now also double click on the taskbar panel to activate the desktop.

Bitmaps -- some of the graphics have been updated.  They are stored
in the RES files with the source, but I can send you copies of the
bitmaps by email if you don't have a suitable extraction tool.

Explorer tree bug fix -- previous versions raised a GPF if the tree
window is open when Calmira shuts down.

Tile vertical -- there are reports of problems on a few systems.

Volume labels -- if your volume label has more than 8 characters and
does not contain a dot ".", Calmira will not display it correctly.
For example, "ABCDEFGH_123" could be shown as "ABCDEFGH._12".

Windows 95 colours -- when you first run Calmira, it installs a new
colour scheme called "Windows 95 Standard" into your Control Panel.
You can choose this scheme in the usual way.

Restricting access to settings -- if you use Calmira in a school or
other multi-user environment, you can now prevent the options,
shortcuts, and Start Menu from being changed.  In the [Calmira]
section of CALMIRA.INI, add CanEditingSettings=0.  This causes the
OK button and tab pages to be disabled in property sheets, and
does not allow shortcuts to be created, edited or removed.

Alt+Tab side effects -- all grid and tree components used by Calmira
are affected by task switching with Alt+Tab.  The focus moves to the
next item along, which causes the Explorer tree to change directory.

Switching between Explorer tree and file pane -- press Alt+W.

Toggling selections with the keyboard -- press the Spacebar.

Windows NT 3.51 -- if you are interested in a patched version of
Calmira which does not cause General Protection Faults under NT,
then let me know.  This just involves disabling low-level hooks
that are causing problems but will, of course, disable some of
the features.  The program remains the same, i.e. a 16-bit one,
and there are no plans for a 32-bit version.

Changes since Beta 2 -- mainly minor bug fixes.  You can now cycle
through tabbed pages using the arrow keys, after focusing a tab
first.

Hiding the Computer and Bin icons -- assign empty captions to these
objects, and they will not appear the next time you run Calmira.
The trick of giving negative icon positions does not seem to work
any more.

Source code changes -- there is a summary in the help file, but it
might be incomplete due to last minute fixes.  Do a grep on { 2.2 }
to make sure.  The TabPanel component has definitely been updated.
