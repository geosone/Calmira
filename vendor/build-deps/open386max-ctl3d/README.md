# Open386MAX CTL3D source snapshot

Source: https://github.com/geosone/Open386MAX
Branch: `main`
Commit: `60a751c48ae4c33ade202d4ad35893c6629bd040`
License: GNU GPL version 3; see `LICENSE` and the source header.

Imported files:

- `CTL3D/CTL3D.C` → `CTL3D.C`
- `CTL3D/CTL3DV2.DEF` → `CTL3DV2.DEF`
- `INCLUDE/CTL3D.H` → `ctl3d.h` (lowercase name for its existing include)
- `LICENSE` → `LICENSE`

File contents are unchanged. Calmira's root Makefile supplies the standalone
OpenWatcom/JWlink build. Upstream `_export` records and explicit DEF ordinals
both describe the same functions; linker diagnostic 1121 is disabled as in
the upstream build. The resulting module's name and ordinals are checked
from its NE tables after linking.
