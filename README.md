# FireRed Kanto Visual Importer

**Experimental pre-release: 0.3.0-rc.6**

FireRed Kanto Visual Importer reads visual data from a **player-provided**, launcher-verified English Pokémon FireRed v1.0 ROM. It keeps all source data local to the player and never includes a FireRed ROM, extracted FireRed graphics, map data, or generated FireRed-derived atlas in this public repository or its release ZIP.

Version 0.3.0-rc.6 is an **experimental constrained-facelift pre-release**. It retains the map-aware semantic visual pipeline, variable-size compressed-tileset repair, dedicated layout-border handling, four-cell movement semantic lock, corrected FireRed combined tile-bank/palette routing, and the proven FireRed battle-art import path. It registers documented per-path scale overrides for each imported 64×64 FireRed Pokémon front/back sheet, preventing the native Gen 1 2× back-sprite default from enlarging player-side art to 128×128. It also bridges importer-owned in-memory images through the asset resolver used by the title and Oak introductory screens, so those screens can load the already-patched FireRed species front image without writing any source-derived file. It pre-bakes copied Gen 1 base tiles with the active Gen 1 advanced-colour palette groups when that mode is enabled, so a true-colour generated map atlas no longer leaves its preserved Gen 1 regions as an unintended monochrome layer beside FireRed visuals. Pallet remains coordinate-scoped: FireRed supplies only an explicit grass/ground mask and unscaled two-by-two exterior footprints for Red’s House, Blue’s House, and Oak’s Lab. Red’s House 1F remains a dedicated compact interior profile, and a separate Player’s House 2F profile anchors its stair visual to Gen 1’s existing upstairs warp. Stable **v0.2.4** remains the rollback release. The Gen 1 map grid, collision, warps, ledges, grass, objects, scripts, encounters, progression, and saves remain authoritative.

| Component | v0.3.0-rc.6 experimental behavior | Gameplay effect |
|---|---|---|
| Pokémon battle art | Imported locally from the verified FireRed ROM. Each 64×64 front sheet is registered at 0.875× and each back sheet at 1.0×, overriding Gen 1’s 1×/2× defaults by exact generated asset path. | Visual only; player and enemy art stay grounded inside the classic battle slots. |
| Title, Oak intro, and resolver-based menus | Use the same patched species front path as battles. rc.6 returns importer-owned in-memory ImageData through the engine asset resolver, allowing screens that construct their own image after resolving a path to display it. | Visual only; no intro script, text, name flow, or Pokémon data changes. |
| Trainer battle portraits | Imported locally from the verified FireRed ROM; rc.5 does not modify trainer picture placement. | Visual only. |
| **Pallet Town** | Preserves Gen 1 visuals by default. FireRed ground is declared by target coordinate, not a repeated target block ID. Red’s House, Blue’s House, and Oak’s Lab each use only their verified two-by-two Gen 1 exterior footprint. When Gen 1 advanced colours are active, copied base pixels are pre-baked with the same base OVERWORLD palette groups before entering the true-colour atlas. | Existing coordinates, entrance behavior, collision, warps, and map transitions remain Gen 1-owned. |
| **Red’s House 1F** | Uses a dedicated compact FireRed Player’s House 1F crop with a declared stair visual override. | The front exit and stairs retain their original Gen 1 warp coordinates and behavior. |
| **Red’s House 2F** | Uses a separate compact FireRed Player’s House 2F crop with a declared stair visual override. | The existing Gen 1 return-to-1F stair remains authoritative. |
| Other overworld and interior maps | Remain Gen 1 visuals until a dedicated profile is complete. | Safe native behavior. |

## Why the previous terrain preview failed

FireRed has a 16×16 metatile system, while Gen1Recomp draws each Gen 1 map block as a 4×4 grid of 8×8 tiles, or 32×32 pixels. The prior experiment substituted a FireRed metatile for a Gen 1 block with the same number. Those numbers do **not** describe the same thing in the two games.

That is why the prior Pallet Town screenshot could display a FireRed Pokémon Center over Red’s House: the numeric source block happened to be a Pokémon Center graphic, while the unchanged Gen 1 collision and warp were still those of Red’s House. The visual door was therefore not the real exit. Reducing the image scale could not correct that semantic mismatch.

> **v0.3.0-rc.6 rule:** the Gen 1 target map defines every coordinate and gameplay meaning. The constrained Pallet profile starts with the original Gen 1 pixel block and paints FireRed only at explicitly declared target coordinates; the original Gen 1 semantic tile stays locked for every block’s four movement cells.

## The map-aware pipeline

The importer remains a single user-facing mod with three internal layers. Keeping these layers together avoids duplicate ROM imports, cross-mod cache sharing, and load-order conflicts while keeping player-provided source data private.

| Internal layer | Responsibility | Safety boundary |
|---|---|---|
| **Verified ROM reader** | Opens only the launcher-verified FireRed v1.0 source and reads bounded profile-declared layout and tileset ranges. | No source content is bundled or uploaded. |
| **Semantic converter and tile-lock validator** | Decodes FireRed tiles, palettes, metatiles, and source-map cells; then reassembles them into fixed 8×8 target tiles and 4×4 Gen 1 blocks. | Rejects non-integral tile grids, unavailable metatiles, unexpected layouts, invalid crop bounds, and unsupported ROM structure. |
| **Map-profile applicator** | Registers a dedicated generated visual tileset and remaps only the selected Gen 1 map’s visual block rows. | The map’s dimensions, collision class, grass, water, doors, warps, objects, events, scripts, and saves remain Gen 1-owned. |

The map converter gives every existing target map block its own visual row. It copies the original block’s collision-tile category—walkable, grass, water, shore, door, warp, counter, or blocked—onto the generated row. A visible FireRed door can therefore be sampled for the precise Gen 1 block that already owns the real Gen 1 exit warp; it cannot move that warp or create a new one.

## Supported source ROM

The launcher accepts only this exact source file through the standard **Imported Files** flow.

| Revision | MD5 |
|---|---|
| FireRed English v1.0 | `e26ee0d44e809351c8ce2d73c7400cdd` |

## Installation and testing

Install **v0.3.0-rc.6** from its GitHub pre-release ZIP, enable it, and select the verified FireRed ROM when the launcher asks. The personal index remains on stable **v0.2.4** until this experiment is promoted. The package ID remains `FIRERED_KANTO_VISUALS`, so users of older uppercase releases can update normally.

**FR MAP VISUALS** is enabled by default. After installing v0.3.0-rc.6, fully restart the game before testing. This is a pre-release; return to stable v0.2.4 if any map transition, doorway, path, grass, or Route 1 connection becomes less reliable. If map visuals are enabled but **no** requested profile can build, the importer now fails visibly in the Mod Manager with the first precise reader/converter diagnostic instead of silently showing all-native terrain. The first test route should be as follows:

1. Start in **Red’s House 2F**, use the visible stairs to enter **Red’s House 1F**, then return upstairs; both existing Gen 1 stair warps must work.
2. Leave **Red’s House 1F** through the visible downstairs door and re-enter from **Pallet Town**.
3. Check **Blue’s House** and **Oak’s Lab** entrances from Pallet Town, including entering and leaving Oak’s Lab.
4. Before starting a save, wait for a cycling title Pokémon; then begin a new game and confirm Oak’s demo Pokémon is visible during the introductory speech. If a starter-selection mod shows species front portraits through the engine resolver, confirm those portraits are present as well. Start Oak’s Lab’s rival battle and confirm that the enemy front and player back sprite fit within the classic battle frame without touching the HP boxes or text. Then confirm that FireRed grass/ground appears only at its declared Pallet target coordinates, each exterior fits its two-by-two Gen 1 footprint, and preserved Gen 1 regions follow the active advanced-colour setting without an extra monochrome layer.

Please report a screenshot or short clip with the named map and the visible problem if a profile needs further coordinate tuning. Maps outside Pallet Town and Red’s House 1F/2F intentionally remain Gen 1 art until their own semantic profile is validated.

## Scope and source policy

This importer does **not** port FireRed maps or alter Gen 1 collision, warps, NPCs, scripts, encounters, items, story progression, save data, or gameplay mechanics. It changes only a supported map’s generated visual tileset. Its source reader uses the player’s local verified ROM at runtime; no Nintendo asset or ROM-derived cache is included in public releases.

The architecture was informed by the public import and cache-boundary practices of [Crystal 251](https://github.com/Deftones565/gen1recomp-mod-crystal-251) and [Stadium Battle FX](https://github.com/anxiousintrovert/StadiumBattleFX), without using either project’s code or requiring either mod.
