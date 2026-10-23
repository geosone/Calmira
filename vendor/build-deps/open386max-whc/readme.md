# Open386MAX WinHelp compiler snapshot

Origin, revision, original source SHA-256 and license are recorded in
`origin.json` and the parent `LOCK`. `LICENSE` is copied from that revision.
This is a source snapshot, not a binary dependency or a sibling-checkout link.

Local changes to `whc.py`:

- Preserve Word RTF `trowd`, `cellx`, `trgaph`, `intbl`, `cell` and `row`
  structure, including empty paragraphs and inherited row templates.
- Emit native WinHelp 0x23 table records, retaining per-cell formatting,
  bitmap placement, links and text.
- Encode each cell's text-stream offset and format-body size. Microsoft
  WinHelp 3.1 needs the offsets even when a sequential decoder can read the
  file without them. A zero offset for later cells hides their text.
- Decode and validate compressed paragraph text offsets instead of treating
  their first two bytes as unknown fields.
- Close input/output files deterministically with `pathlib` helpers.

The compiler's regular display-record path is otherwise unchanged. Native
acceptance and regression coverage are described in `docs/help.md` at the
repository root. The DOS QuickHelp tool was not imported: it uses a different
format and does not build this Windows manual.
