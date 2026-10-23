# Calmira Reloaded Branding and Source Paths

## Name and Provenance

The maintained integration is named **Calmira Reloaded**. Its graphics replace
the former Reborn wording without inventing a release number. The executable
and default installation directory remain DOS-safe `CALMIRA.EXE` and `CALMIRA`.
Historical authorship, upstream source comments and license notices are not
renamed; OpenLFN Loader remains a separately branded component.

The title and start-menu banner were produced with the built-in Imagegen tool,
using the old bitmap layout as reference. The final prompt briefs were:

- Title: exact text “Calmira Reloaded”, bold black Calmira with a restrained navy
  shadow, smaller navy Reloaded, pure white background, classic 1990s styling.
- Banner: exact text “Calmira Reloaded”, white bottom-to-top lettering inside a
  solid narrow navy stripe, empty navy area above, no version or extra artwork.

Master PNGs live in `assets/branding/`; runtime assets are `bmp/title.bmp`
(241×36) and `bmp/banner.bmp` (24×256). Both are uncompressed Windows 3.x
4-bit BMPs. Only the latter two are relevant to floppy/resource size.

`help/banner.bmp` is the same start-menu artwork rotated clockwise for the
horizontal sample in the help topic. It remains 256×24 pixels and 4-bit BMP;
its documented menu size is 24×256. The help project is titled
“Calmira Reloaded Help”. Keep this sample synchronized with `bmp/banner.bmp`.

`make help` rebuilds the complete WinHelp manual, including embedded images,
with the pinned Open386MAX Python compiler and local table fixes. The verified
`help/calmira.hlp` now contains the Reloaded banner and updated RTF text.
OpenWatcom WHC's incomplete attempt was not used. See [help.md](help.md) for
rebuild commands, coverage and native Windows 3.11 checks.

## Rebuilding Resources

The shell loads `TITLE` and `BANNER` from `src/bitmaps.res`; replacing standalone
BMPs alone does not update those embedded images. To prepare an updated bundle:

```sh
python3 tools/bitmap_resources.py src/bitmaps.res \
  --bitmap TITLE=bmp/title.bmp --bitmap BANNER=bmp/banner.bmp \
  --output build/branding/new-bitmaps.res
```

The output must be a new file. Inspect it before copying it to
`src/bitmaps.res`. The tool preserves unrelated records and rejects changed
dimensions/depth, compressed BMPs, duplicate targets and truncated input.
`make test` checks embedded images against their BMPs and verifies that the
other twelve original records remain byte-identical. The complete shell still
requires the unfinished VCL port; resource checks are not GUI acceptance.

## Filename Policy

Owned source files, resource files, documents and directories use lowercase.
GNU Make discovers `makefile` normally. `AGENTS.md` retains its mandated name
and original contents. Historical `vendor/` and `archives/` trees, external
submodule paths, and generated DOS package filenames are explicit exceptions.
Case-sensitive resource identifiers such as `TITLE` are not filenames.

`python3 tools/lowercase_paths.py` previews owned path renames; `--apply`
performs the mechanical migration after collision checks. It preserves binary
contents and original text encodings/line endings. Tests enforce the lowercase
policy and protect external paths and generated license names.
