# FireRed map-aware pipeline research

## Public reference sources

- [pret/pokefirered source](https://github.com/pret/pokefirered), current master cloned at `/home/ubuntu/pokefirered-reference`.
- [pret/pokefirered symbols branch](https://github.com/pret/pokefirered/tree/symbols), cloned at `/home/ubuntu/pokefirered-symbols-reference`.
- [Porymap map-tiles documentation](https://huderlem.github.io/porymap/manual/editing-map-tiles.html), a general Gen III map-editor reference.

No external code has been executed. The source and symbols were inspected as reference data only.

## Format facts

FireRed `struct MapLayout` is declared in `include/global.fieldmap.h`:

| Offset | Field |
|---:|---|
| `0x00` | `s32 width` |
| `0x04` | `s32 height` |
| `0x08` | border pointer |
| `0x0C` | map block-data pointer |
| `0x10` | primary tileset pointer |
| `0x14` | secondary tileset pointer |
| `0x18` | border width |
| `0x19` | border height |

`struct MapHeader` begins with the MapLayout pointer at offset `0x00`; it is 28 bytes in the v1.0 symbol data.

`include/global.fieldmap.h` defines:

- `MAPGRID_METATILE_ID_MASK = 0x03FF` (bits 0–9)
- `MAPGRID_COLLISION_MASK = 0x0C00` (bits 10–11)

FireRed `src/fieldmap.c` reads the metatile ID as `block & 0x03FF`. The source declares `NUM_METATILES_IN_PRIMARY = 640` and `NUM_METATILES_TOTAL = 1024`, so IDs `0–639` use the primary tileset; IDs `640–1023` use the secondary tileset at index `id - 640`.

## Pallet Town reference data

FireRed `data/layouts/layouts.json`:

| FireRed layout | Width × height | Primary | Secondary |
|---|---:|---|---|
| `PalletTown_Layout` | 24 × 20 | `gTileset_General` | `gTileset_PalletTown` |
| `PalletTown_PlayersHouse_1F_Layout` | 13 × 10 | `gTileset_Building` | `gTileset_GenericBuilding1` |
| `PalletTown_PlayersHouse_2F_Layout` | 12 × 9 | `gTileset_Building` | `gTileset_GenericBuilding1` |

Gen 1 Red `PALLET_TOWN` is 10 × 9 native 32px map blocks, whereas FireRed Pallet Town is 24 × 20 native 16px metatiles. The two layouts are not a simple numeric or integer one-to-one conversion. Gen 1 `REDS_HOUSE_1F` is 4 × 4 blocks; FireRed Player’s House 1F is 13 × 10 metatiles.

## FireRed v1.0 symbols from `pokefirered.sym`

| Record | ROM address |
|---|---:|
| `gTileset_General` | `0x082D4A94` |
| `gTileset_PalletTown` | `0x082D4AAC` |
| `gTileset_Building` | `0x082D4BB4` |
| `gTileset_GenericBuilding1` | `0x082D4C74` |
| `PalletTown_PlayersHouse_1F_Layout_Blockdata` | `0x082D50FC` |
| `PalletTown_PlayersHouse_1F_Layout` | `0x082D5200` |
| `PalletTown_Layout_Blockdata` | `0x082DD100` |
| `PalletTown_Layout` | `0x082DD4C0` |
| `PalletTown` map header | `0x08350618` |
| `PalletTown_PlayersHouse_1F` map header | `0x08350D50` |
| `PalletTown_PlayersHouse_2F` map header | `0x08350D6C` |

Public source map-layout binary sizes agree with dimensions: Pallet Town `24 * 20 * 2 = 960` bytes; Player’s House 1F `13 * 10 * 2 = 260` bytes.

## Implication for the importer

The original numeric strategy (`Gen1 block n -> FireRed General metatile n`) cannot be repaired by scaling pixels. It paints semantically unrelated FireRed visuals—for example, a Pokémon Center-like block onto Red’s House—over unchanged Gen 1 collision and warp cells.

A correct pipeline must:

1. Decode bounded map-layout and tileset data directly from the user’s already verified FireRed v1.0 import at runtime.
2. Decode primary and secondary tileset atlases/metatile tables.
3. Use explicit, per-location semantic correspondence profiles—not numeric IDs—to select FireRed visual blocks for Gen 1 map-block roles.
4. Preserve Gen 1 collision, warp, ledge, encounter, and script data; the profile changes visual blocks only.
5. Begin with a small Pallet Town / Red’s House profile and expand only after screenshot/video verification.

## User-provided design advice assessed

The provided design note correctly identifies the needed change: this must be a **tile-semantic conversion pipeline**, not an image-resize pipeline. Its applicable requirements are now part of the implementation plan:

| Advice | Pipeline decision |
|---|---|
| Target grid is fixed at 8×8 tiles | Adopt. Every generated engine tile remains 8×8 pixels, and every generated map block remains exactly a 4×4 grid of 8×8 target tiles (32×32 pixels). |
| Preserve the target game’s map coordinates, collision, warps, objects, ledges, and footprints | Adopt. Gen 1 map records and gameplay fields remain untouched; only the selected map’s visual tileset is changed. |
| Decompose FireRed assets into native tiles / metatiles / palette / map layout before conversion | Adopt. The runtime reader will decode the verified local ROM’s tileset headers, tile data, palettes, metatile entries, and map-layout cells. |
| Use categories such as grass edges/corners, ledges, and building footprints | Adopt. Semantic profiles will define visual roles and footprint masks instead of numerical block-ID substitution. |
| Add a tile-lock validator | Adopt. The decoder will reject non-8×8 target tiles, non-16-entry blocks, non-integral atlas dimensions, invalid map-profile dimensions, and out-of-range source metatiles before registration. |
| Intermediate debug outputs such as tile grids/collision overlays | Adopt as local diagnostic data only. Debug renderings must not be packaged if they contain ROM-derived art. |
| Use AI to reinterpret or generate FireRed-derived art | Not used in the public importer. The player-provided ROM remains the sole local source; deterministic code chooses, composes, and validates visual cells. The public release contains no FireRed-derived images or cached intermediates. |

The correct high-level flow is therefore:

`verified local FireRed ROM → bounded asset/layout reader → semantic profile + tile-lock validation → importer-owned generated atlas in memory → map-specific Gen 1 visual tileset`

The output remains a visual-only layer. FireRed map data is read locally as a reference for visual semantics; Gen 1 map geometry and all gameplay data remain authoritative.

## Comparative importer references

The user authorized a non-copying comparison with two public Gen1Recomp mods:

- [Crystal 251](https://github.com/Deftones565/gen1recomp-mod-crystal-251)
- [Stadium Battle FX](https://github.com/anxiousintrovert/StadiumBattleFX)

### Relevant conclusions

| Reference pattern | FireRed importer decision |
|---|---|
| Crystal 251 is one self-contained overhaul with an internal `lib/` importer stack, data catalogues, runtime bridge, tests, and explicit ROM checks. | Adopt the **single user-facing package with internal layers** pattern. The FireRed reader, semantic converter, validator, and profile applicator remain modules inside this mod. |
| Stadium Battle FX uses launcher-managed imported files, validates accepted ROM revisions, creates versioned local derived caches, and keeps the public release free of ROM content/caches. | Retain the current required-import MD5 gate. Add a versioned in-memory/profile cache only if it never stores source assets in the release or crosses mod boundaries. |
| Stadium Battle FX exposes a documented versioned API only for independent presentation providers. | Do not split the first FireRed pipeline into three packages. A future profile-pack interface should be designed only after the core pipeline has a stable, documented, read-only API; no other mod should need raw ROM bytes or mutable cache access. |
| Both projects isolate optional/failing advanced functionality behind guarded fallbacks. | A bad or incomplete map profile must fail closed to the native Gen 1 tileset, not fall back to numeric FireRed block substitution. |

### Mod API constraint verified

`src/mods/Sandbox.lua` gives each mod its own global environment. `src/mods/Storage.lua` scopes storage under `mod_storage/<game version>/<playthrough>/<mod id>`. Separate mods therefore do not have a supported shared runtime-memory or common storage namespace for decoded ROM data. Duplicating reader/converter/applicator into three installed packages would require every package to independently read/import data or depend on an unsafe/private sharing workaround.

The importer will therefore remain one package with three internal layers. This directly follows the sound architecture recommendation while preserving privacy, reproducibility, required-import validation, package-update behavior, and load-order reliability.
