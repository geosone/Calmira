# Program Manager Group Synchronization

Calmira imports the Windows 3.x Program Manager groups listed in
`%WINDIR%\PROGMAN.INI`. The portable parser validates each binary `.GRP` file's
`PMCC` signature, checksum, record offsets, strings, and extensions before any
menu data is changed.

Imported groups live below the owned subtree
`Start\&Programs\Program Manager` in Calmira's `START.INI`. Existing native
Calmira menu items are not touched. Captions, commands, working directories,
icons, icon indexes, and show modes are preserved; duplicate captions receive
a numeric suffix.

Synchronization runs during each Calmira start. A content signature avoids
rewriting an unchanged tree, but the tree is recreated if it was removed.
If any source group is invalid or unreadable, the previous imported tree is
kept intact. Set `SyncProgramGroups=False` under `[Start Menu]` in
`CALMIRA.INI` to disable automatic synchronization. The destination caption is
configurable with `ProgramGroupsCaption=`.

Choose **Settings > Sync Program Manager Groups** to force a manual refresh.
The same action is available to custom menus as `$SyncProgramGroups`.

Run `make fpc-test` for portable parser tests. Optional paths passed to
`build/fpc/test_program_groups` audit real `.GRP` files without modifying them.
