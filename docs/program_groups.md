# Program Manager Group Synchronization

Calmira imports the Windows 3.x Program Manager groups listed in
`%WINDIR%\PROGMAN.INI`. The portable parser validates each binary `.GRP` file's
`PMCC` signature, checksum, record offsets, strings, and extensions before any
menu data is changed.

Each group becomes a Start menu of its own under `Start\&Programs`, as on
Windows 95. The first synchronisation replaces the English stand-ins of a fresh
`START.INI` (Accessories, Games, Main, Network, Startup) and the
`Program Manager` submenu that versions up to 5.0.91 filled. `CALMIRA.INI`
lists the menus that came from groups under `[Program Groups]`; the next
synchronisation rewrites only those, so menus of the user stay. Captions,
commands, working directories, icons, icon indexes, and show modes are
preserved; duplicate captions receive a numeric suffix. Afterwards the submenus
of Programs stand above its programs, in alphabetical order.

Calmira runs the startup group when it is the Windows shell. Unless
`StartupGroup=` is set under `[Start Menu]`, the synchronisation sets it to
the group that `PROGMAN.INI` names with `Startup=`, or to the group called
Startup, Autostart, Démarrage, Opstarten, Esecuzione automatica or Inicio.

Synchronization runs during each Calmira start. A content signature avoids
rewriting unchanged menus, but they are recreated if one was removed.
If any source group is invalid or unreadable, the previous menus are
kept intact. Set `SyncProgramGroups=False` under `[Start Menu]` in
`CALMIRA.INI` to disable automatic synchronization.

Whenever the tree is rewritten, the Start menu's image cache `BMPCACHE.BMP` is
deleted, as the Start menu editor does, so the icons are read again for the
changed menu.

Choose **Settings > Sync Program Manager Groups** to force a manual refresh.
The same action is available to custom menus as `$SyncProgramGroups`.

Run `make fpc-test` for portable parser tests. Optional paths passed to
`build/fpc/test_program_groups` audit real `.GRP` files without modifying them.
