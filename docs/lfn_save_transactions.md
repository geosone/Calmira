# Virtual Long-name Save Transactions

`src/portable/lfn_store.c` is an allocation-free C core with injected file IO;
it runs on Linux in tests and in the Win16 adapter `src/win16/clfnstore.c`.
It never creates, truncates, renames or deletes the application's document.

## Lifecycle

1. Validate a leaf filename and reserve a free `NAME~n.EXT` alias, checking
   both files and existing description aliases. Exclusively create `CLFN.SAV`
   with a versioned record. Do not create a placeholder document.
2. Pass the alias to native COMMDLG. An application FILEOK veto, validation
   failure or Cancel discards only this reservation. Existing long names
   resolve to their aliases, including files hidden by the current filter.
3. After dialog acceptance, the application creates its ordinary DOS file.
   The resident owner calls `PollFileDialogSaves()` periodically. Missing or
   exclusively unopenable targets wait; they do not acquire a new mapping.
4. Lock cooperating metadata writers with exclusive-create `CLFN.LCK`.
   Copy existing bytes into exclusively created `CLFN.NEW`, append one OEM
   mapping, flush and close. Rename the old map to `CLFN.BAK`, then publish
   the new map without overwriting a destination. Restore the old map if
   publication fails. Remove owned backup/journal/lock only on success.

Unknown lines and Ctrl-D metadata are preserved. Read-only/oversized maps,
foreign sidecars and conflicting mappings are not overwritten. A failed
rollback retains backup, temporary, journal and lock for inspection.

## Operating Limits

- Keep `OLFNLOAD.EXE` resident until saves finish. Stop refuses while a save
  remains pending. If a task exits without creating its file, its unused
  reservation is discarded. Existing journals are never silently adopted.
- First revision: eight pending directories, **one pending save per directory**,
  DOS paths below 80 bytes, display names up to 240 OEM bytes, maps up to
  32,760 bytes. Enter new long names with an explicit extension in the selected
  directory; embedded long directory paths are not translated.
- Cooperative reservations do not prevent unrelated DOS tools racing to
  create an alias. Exclusive-open behavior depends on host sharing support.
  Polling proves file presence/accessibility, not that the application's
  business-level save succeeded. A failed write that leaves a real partial
  file cannot be distinguished from an intentional saved file by this hook.
- FAT rename steps are recoverable, not a power-loss-atomic filesystem
  transaction. Hot removal and crash/reboot recovery are not automatically
  repaired. Do not delete recovery files blindly or retry through a lock.

## Recovery

Stop the applications and preserve copies of `DESCRIPT.ION`, `CLFN.SAV`,
`CLFN.NEW` and `CLFN.BAK` before inspecting a failed transaction. The backup
is the previous map; the temporary contains the candidate map; the journal
records the intended alias/name. Never restore a backup over a newer map
without comparison. A guided recovery tool remains to be implemented.

`make c-test` currently checks 283 behaviors, including injected write,
publication and rollback failures. Native COMMDLG tests additionally cover
collisions, application veto, umlauts, no-create cleanup and pending-unload
protection. See [native results](file_dialog_tests.md).
