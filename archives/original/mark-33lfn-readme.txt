 If you unzip calmira.zip using pkunzip.exe, be sure to use -d
option to preserve directory structure. If you use Winzip be sure to check
"Use Folder Names" checkbox in extract dialog. 
  In the "calmira" directory are two files, calmira.exe and lfnlib.dll.
Place both of these files in your local calmira directory (but first save
your "calmira.exe"). The dll will not work unless it's in calmira directory.
The "intxlate" directory contains files for installing the VxD. Follow
instructions in "Readme.txt" file (except for part about unzipping
intxlate.zip -- it's already unzipped).
   After installing VxD and restarting Windows, run calmira. Then go to
start menu, and choose settings\file system and in file system dialog choose
"4 DOS/LFN" tab. Then check checkbox labeled "Enable Long Filenames."
(Ignore message about enabling long file names per drive. This does not
work). Click "OK" button and if everything is working, long file names will
be enabled. If something goes wrong, a message box will come up with error
message.
   The following LFN features have been tested:

   1. Display and Navigate files and directories in Calmira Explorer and My
Computer windows. This should show LFNs with any FAT12, FAT16, or FAT32
partition and any Joliet format CDs.
   2. Open a file by double clicking or pressing <enter> on a selected
executable or document file (try an .exe or maybe a .txt file [will bring up
notepad]). This should work with any FAT12, FAT16, or FAT32 partition. It
will NOT work with LFNs on a Joliet format CD, because I have not
straightened out the mapping from LFN to short path names for CDs (I'll soon
fix that).
   3. Find Files Dialog. If you do not use the "Containing Text" feature,
this should work with any FAT12, FAT16,or FAT32 partition or Joliet format
CD. The "Containing Text" feature will work with LFNs but not on a Joliet
format CD because I have not corrected the mapping from LFN to short path
names for CDs.
   4. Rename File or directory. This should work with any FAT12, FAT16, or
FAT32 partition. 

New features in current version:

-   Cut/Copy/Paste/Drag and Drop now work with long file names.
-   Recycle Bin Delete/Restore now works with long file names.
-   Create new folder now works properly with long file names.
-   File/Directory properties dialog works correctly with long file name
    files and directories.
-   Icons from EXEs are displayed properly in explorer and My Computer
    windows, even when EXEs or directories they are in have long file names.

All features of old version should work properly now.
Some features which are not yet working properly with long file names:

   Run dialog
   Open file/Copy/Paste/Drag and drop/Find Files containing text from joliet
format CDs work SOME of the time, but not in general. All CD features work
fine with ISO9660 format CDs.


   Never enable/disable LFNs with File System settings dialog while Find
Files dialog is actively searching for a file. This could have very bad
consequences.

The included intxlate.zip (which contains the VxD installation files
and instructions) is required for long filename support. 

