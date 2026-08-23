# Changelog

## 0.3.0-rc.6 — Experimental intro-image resolver correction

> **Pre-release branch:** this isolated corrective build follows rc.5. Stable **v0.2.4** remains the rollback release and the personal index is not modified.

The rc.5 recording showed that FireRed battle art can decode, scale, and render successfully while the title screen and Oak’s "this is a Pokémon" demonstration remain blank. This was not a missing species front-sprite mapping: Gen1Recomp’s title and Oak screens resolve the same patched species `spriteFront` path used by battle, then construct a LÖVE image directly after resolution. The importer had held those source-derived images only in its private in-memory cache; resolver-based UI consumers therefore received a string path with no disk file behind it and rendered nothing.

rc.6 extends the existing importer-owned asset bridge. For the `firered/generated/` namespace only, `Assets.resolve` returns the registered in-memory ImageData, which LÖVE accepts as an image constructor input. Title and Oak screens can therefore render the exact already-decoded FireRed asset without writing a ROM-derived PNG, changing engine/UI code, modifying intro text or sequencing, or touching battle mechanics. External paths and all non-importer assets continue through the normal resolver unchanged. This also covers any compatible starter-selection UI that resolves species fronts through the engine asset resolver.

The recording confirmed that the compact Red’s House stairs are nearly aligned. rc.6 deliberately leaves their declared source crop and Gen 1 stair warp unchanged rather than making an unverified one-cell adjustment. It also retains rc.5’s coordinate-scoped Pallet policy: FireRed is limited to declared grass and compact building samples, while requested Gen 1 structures remain present. The palette-coherence path remains responsible only for eliminating an unintended monochrome layer when advanced colours are active.

New coverage proves resolver-based direct image construction uses only the importer’s in-memory generated ImageData and that a fresh in-process mod reload refreshes this resolver bridge. The full active-branch suite, syntax checks, archive integrity, and protected-content scan passed. No source ROM, extracted art, generated source atlas, user media, or external code is committed or packaged.

## 0.3.0-rc.5 — Experimental battle-scale and palette-coherence correction

> **Pre-release branch:** this isolated corrective build follows rc.4. Stable **v0.2.4** remains the rollback release and the personal index is not modified.

The rc.4 gameplay recording confirmed that FireRed battle-art decoding works, but it also exposed a renderer-scale mismatch. FireRed Pokémon sheets are 64×64 pixels; Gen 1 normally draws 32×32 player back pictures at 2×, so using that default made imported player-side art 128×128 and allowed it to cover the classic HP and text areas. rc.5 leaves ROM decoding, LZ77 handling, palettes, trainer portraits, battle rules, and Pokémon data unchanged. It registers documented `battle_sprite_scales` records for every generated image path: 0.875× for a 64×64 enemy front image to fit Gen 1’s 56px front slot, and 1.0× for a player back image to retain Gen 1’s 64px on-screen footprint instead of applying its 2× default.

The recording also clarified why the constrained Pallet overlay looked like three unrelated visual languages. Generated profile maps require a true-colour atlas for FireRed pixels; copied raw Gen 1 grayscale base pixels inside that atlas bypass the renderer’s usual advanced-colour bake, while maps not using the profile continue through the ordinary base tileset. rc.5 optionally pre-bakes copied base tiles using the same base tileset palette-group resolver used by the renderer, but only when the player’s advanced-colour pack is active. Normal monochrome mode is left monochrome by design. This changes pixels only; it does not alter blocks, map coordinates, collisions, doors, warps, events, scripts, saves, or the four-cell semantic lock.

The visual-sprite test root was also corrected from an outdated main-branch clone to this active experimental checkout. The complete regression suite now executes against the code being packaged. New tests cover front/back scale-record registration, active game palette-data forwarding, and palette-aware copied-base-pixel output. No source ROM, extracted art, generated source atlas, user media, or external code is committed or packaged.

## 0.3.0-rc.4 — Experimental Pallet target-footprint correction

> **Pre-release branch:** this map-only corrective build follows rc.3. Stable **v0.2.4** remains the rollback release and the personal index is not modified.

The rc.3 recording confirmed that FireRed battle sprites and trainer art import correctly; rc.4 deliberately leaves that proven path untouched. It also exposed two Pallet-profile errors. First, Gen 1 base block ID 1 is reused across more than one visual context, so applying one FireRed ground sample through a global block-ID override spread it into unintended town space. Second, the declared Red’s House, Blue’s House, and Oak’s Lab rectangles were one target block too wide, producing clean but oversized FireRed exteriors over adjacent fixed Gen 1 terrain.

rc.4 removes the global target-block override. FireRed grass/ground is now selected only by an explicit Pallet coordinate mask, while all other terrain defaults to the installed Gen 1 block pixels. Red’s House and Blue’s House each use their actual 2×2 Gen 1 block footprint, and Oak’s Lab uses its actual 2×2 structural footprint; the neighboring Gen 1 ground blocks are no longer treated as laboratory art. Each lower-left building block is sampled from the FireRed 2×2 source group containing its visual doorway, while the existing Gen 1 entrance warp and every original movement-cell semantic remains authoritative.

The compact Red’s House 1F and 2F profiles are retained unchanged. The generated-atlas cache revision advances again so rc.4 cannot reuse rc.3 output. Profile/converter tests, full syntax checks, a private in-memory revised-Pallet build, and entrance-semantic checks pass. No battle-art module, ROM, extracted image, generated source atlas, temporary validation fixture, or user media is included in source control or the package.

## 0.3.0-rc.3 — Experimental constrained Gen 1 facelift

> **Pre-release branch:** this corrective build supersedes the rc.2 whole-layout experiment. Stable **v0.2.4** remains the rollback release and the personal index is not modified.

The rc.2 recording exposed a structural failure: fitting FireRed’s 24×20 Pallet layout into Gen 1’s fixed 10×9 town footprint compressed unrelated source regions into the same visual blocks. That produced doubled/composited building textures and made the visible laboratory doorway untrustworthy. rc.3 removes that whole-layout fit from the live Pallet profile. It starts every block with its already-installed Gen 1 pixel data, then overlays only one declared FireRed grass/ground source sample and three explicit, unscaled six-by-four-source-cell exterior rectangles for Red’s House, Blue’s House, and Oak’s Lab. Trees, stones, water, ledges, fences, paths, and every undeclared region remain Gen 1 visuals.

The three building rectangles include the FireRed visual door samples at the corresponding fixed Gen 1 door blocks, but the original Gen 1 four-cell movement, door, warp, grass, water, counter, object, script, save, and connection semantics remain locked. The pre-existing compact Red’s House 1F profile remains independent of Pallet. A new dedicated Red’s House 2F profile uses the verified FireRed Player’s House 2F layout and aligns its stair visual to Gen 1’s unchanged upstairs return warp. The revised Pallet and 2F profiles both passed private in-memory builds against the authorized local source, and the full Lua test suite verifies the new default-Gen-1 explicit-overlay mode, crop bounds, and semantic locks.

The generated-atlas cache namespace is revised again so rc.3 cannot reuse rc.2’s invalid Pallet atlas. No ROM, extracted graphics, generated atlas, validation fixture, or user video frame is committed or packaged.

## 0.3.0-rc.2 — Experimental Pallet selective terrain overlay

> **Pre-release branch:** this remains an opt-in overworld reconstruction build. Stable **v0.2.4** remains the rollback release and is not modified.

The first full-layout Pallet test was much closer visually, but it over-converted the town: the user wanted FireRed-derived grass, ground, and paths while retaining the distinctive Gen 1 large trees and small stones. This refinement introduces an explicit, auditable Gen 1 target-block mask. During the in-memory generated-atlas build, only the declared tree-envelope blocks and the requested small-rock block copy their pixels from the player’s already-installed Gen 1 base tileset; all other Pallet blocks continue to use the bounded FireRed layout reconstruction. No Gen 1 or FireRed asset is added to the repository or package.

The profile also repaints the FireRed 2×2 source samples for Red’s House, Blue’s House, and Oak’s Lab after the whole-layout fit. Their visible doorway cells now target the FireRed source locations that correspond to the fixed Gen 1 house/laboratory warp blocks. The Gen 1 warps themselves, as well as all four semantic movement cells per generated block, remain unchanged. A cache namespace revision prevents a v0.3.0-rc.1 full-layout atlas from being reused by this selective-overlay build. New regressions cover base-atlas copying, post-fit landmark override precedence, invalid visual-policy rejection, the exact retained block set, and all four movement-cell semantic locks.

## 0.3.0-rc.1 — Experimental Pallet full-layout reconstruction

> **Pre-release branch:** this opt-in overworld reconstruction build is separate from the earlier house-composition experiments. Stable **v0.2.4** remains the rollback release and is not modified.

The user supplied a private FireRed English v1.0 source input for local analysis. Its map grid was verified against the public FireRed decompilation’s `PalletTown/map.bin` without exporting any source graphics or ROM bytes. The prior converter was exposed to have two limitations that initial small crops did not reveal. First, it indexed every metatile tile number into its own tileset sheet, but FireRed field metatiles address the combined 0–1023 background tile space: primary tiles occupy 0–639 and secondary tiles occupy 640–1023. It also required the secondary palette-slot table for global palette IDs 7–15. Second, the outdoor profile mixed a broad crop with one local doorway override rather than reconstructing one coherent town scene.

This pre-release corrects the combined primary/secondary tile-bank and palette routing, then fits the verified complete 24×20 FireRed Pallet layout into the unchanged 10×9 Gen 1 Pallet footprint using a bounded nearest-neighbor coordinate transform. The generated map still restores every original Gen 1 movement, grass, door, warp, water, shore, counter, object, script, save, and connection semantic at its existing coordinate. A private in-memory build completed successfully after the correction; no GBA file, extracted art, generated source cache, or media is included in source control or the package.

## 0.2.4 — Generated-atlas cache isolation

The v0.2.3 recording confirmed that Red’s House 1F can now exit safely, but Pallet Town displayed FireRed **interior** visuals—yellow floor, dining table, and furniture—while retaining its outdoor NPC/script context. The FireRed Pallet source layout and tile declarations are distinct from the Player’s House profile, so this was treated as a generated-atlas cache-lifetime issue rather than as a coordinate or collision change.

Map-profile atlas paths are now namespaced by the pipeline revision, ensuring that the renderer requests fresh Pallet and Red’s House images after an update. The private asset bridge also refreshes its backing atlas and image caches when the importer is reloaded while the renderer remains resident. A regression covers this in-process replacement path. This update does not alter map geometry, tile-lock semantics, exits, warps, grass, or any other gameplay behavior.

## 0.2.3 — Four-cell collision and warp tile lock

The v0.2.2 recording exposed a gameplay-critical fault: after entering Red’s House 1F, attempting the downstairs exit could leave the player unable to move or return to Pallet Town. The semantic converter had copied the original collision role only from tile 13—the lower-left 8×8 tile of a 4×4 Gen 1 block. A Gen1Recomp map block contains **four** 16×16 movement cells, each checked from its own bottom-left tile: block tile indices 5, 7, 13, and 15. A door, stair, grass, warp, or passable cell at any of the other three positions could therefore inherit an unrelated role.

This release locks and remaps all four movement-cell tiles in every generated map and border block. It retains the exact original Gen 1 walkable, door, warp, counter, water, shore, and grass semantics for each cell while continuing to source only the visual pixels from FireRed. The targeted regression fixture now asserts distinct walkable, door, grass, and warp roles within one generated block.

## 0.2.2 — Dedicated FireRed layout-border rendering

The first v0.2.1 gameplay evidence confirmed that the map profiles now build at the intended Gen 1 footprint. It also exposed a small-interior presentation error: Red’s House 1F reused the top-left **room** sample as its generated map border. Gen1Recomp repeats that border outside a compact 4×4 house map, so the room wall/floor texture filled most of the camera beyond the actual room.

This update reads the verified FireRed `MapLayout` border pointer and its declared 2×2 dimensions, validates them against the profile, and builds the generated Gen 1 border row from FireRed’s dedicated border entries. The original Gen 1 border block still supplies its semantic collision tile, so this is visual-only: map dimensions, exits, stairs, objects, scripts, saves, and progression remain unchanged.

## 0.2.1 — Variable-size FireRed tileset repair

This hotfix corrects the reason v0.2.0 could silently leave both initial map profiles on native Gen 1 artwork even after a verified FireRed v1.0 import and a full restart. The converter incorrectly treated every compressed FireRed secondary tileset as an exact 384-tile sheet. FireRed’s Pallet Town and Generic Building 1 sheets declare their real, smaller 4bpp size inside their LZ77 headers. The fixed-length check rejected those valid sheets before either profile could be registered.

The reader now accepts the exact LZ77-declared tile count for compressed tilesets, while retaining strict 8×8 tile alignment and bounded source reads. It continues to validate source metatile references before rendering them. A new regression fixture proves that a compressed one-tile sheet can build a complete semantic profile without being rejected for not reaching the old fixed primary/secondary maximum.

If **FR MAP VISUALS** is enabled and every requested profile is rejected, the importer now fails visibly in the Mod Manager with the first bounded-reader/converter diagnostic instead of silently displaying native terrain as if map visuals were active. A single rejected profile still fails closed independently while any valid profile remains usable.

## 0.2.0 — Map-aware Pallet and Red’s House visual profiles

This release replaces the unsafe numeric FireRed terrain-preview experiment with the importer’s first proper **map-aware semantic conversion pipeline**. The pipeline reads only bounded FireRed English v1.0 layout/tileset ranges from the player’s verified local ROM, decodes the source into native 8×8 tiles and 16×16 metatiles, then rebuilds those visuals into fixed 4×4 Gen 1 tile blocks for explicit target maps.

The first profiles support **Pallet Town** and **Red’s House 1F**. They map FireRed visual cells onto each existing Gen 1 map block’s exact footprint; Pallet’s Red’s House, Blue’s House, Oak’s Lab, and Red’s House 1F door/stair blocks use profile coordinate overrides where the two games position equivalent visual landmarks differently. The Gen 1 target maps retain their original dimensions, collision classes, grass, water, doors, warps, counters, events, objects, scripts, encounters, saves, and progression. A visible FireRed doorway can no longer create, move, or hide the underlying Gen 1 exit warp.

The old **FR TERRAIN PREVIEW** option and its number-for-number General-terrain substitution are removed. **FR MAP VISUALS** is now enabled by default and applies only profiles that pass the converter’s layout, tileset, crop-bound, block-size, and semantic tile-lock validation. An invalid profile fails closed to the native Gen 1 map instead of showing mismatched FireRed terrain. Maps outside the two validated profiles remain normal Gen 1 artwork until their own semantic profiles are authored and tested.

The release also adds regression coverage for bounded profile reads, 8×8 tile locking, 4×4 target block construction, original collision-class remapping, map-position remapping, per-profile failure containment, and the preserved FireRed battle-art path.

## 0.1.5 — Collision-aligned terrain default

This release fixes the unsafe default terrain presentation exposed by testing. The previous prototype correctly expanded FireRed 16×16 metatiles into Gen1Recomp's 32×32 map-block geometry, but then substituted FireRed and Gen 1 blocks by matching numeric ID alone. Their block IDs do not share the same meanings. As a result, the visible FireRed door, road, water, ledge, or building could disagree with the retained Gen 1 collision and warp cell; the player could become unable to leave a house by walking to the displayed doorway.

FireRed terrain substitution is now disabled by default. Pokémon battle art and trainer portraits still import from the verified player-local FireRed ROM, while base Gen 1 terrain remains collision-aligned so houses, doors, warps, ledges, grass, and map transitions work normally. The prior terrain prototype remains available only through the short **FR TERRAIN PREVIEW** toggle for diagnostic screenshots, with an explicit restart requirement and warning that it is not navigation-safe.

This is not a simple image-scaling correction. A future FireRed-style terrain layer must use authored semantic profiles that map FireRed art to the meaning of each Gen 1 terrain block and map category; it cannot safely rely on universal metatile resizing or numeric block pairing.

## 0.1.4 — Outdoor transition rendering correction

This release fixes the white, fragmented outdoor screen that could appear when leaving an interior such as the player’s house. The importer had replaced the `OVERWORLD` atlas with FireRed true-colour tiles while retaining the vanilla `OVERWORLD` renderer identity. Gen1Recomp therefore attempted to apply its vanilla per-tile GBC palette bake to FireRed tile IDs that have no vanilla palette assignment.

The imported atlas now uses a distinct renderer-only visual identity. Maps retain their original `OVERWORLD` key and all native collision, warps, outdoor behavior, encounters, and save data remain unchanged, but the renderer correctly treats the FireRed atlas as true-colour rather than as vanilla GBC artwork.

## 0.1.3 — Restored package identity for updates

This release restores the importer’s original package ID, `FIRERED_KANTO_VISUALS`. Gen1Recomp identifies an installed mod by that manifest ID and installs it in a matching folder, so restoring the original identity allows installations from 0.1.0 and 0.1.1 to receive this update through the personal index. All Lua runtime module paths and regression coverage now use the restored uppercase identity.

> **Migration note:** If you manually installed the 0.1.2 lowercase package, remove that copy and install `FIRERED_KANTO_VISUALS-0.1.3.zip` once. Installations from 0.1.0 or 0.1.1 can update normally through the personal index.

## 0.1.2 — Launcher-compatible package identity

This release corrects the importer’s package ID from uppercase `FIRERED_KANTO_VISUALS` to launcher-compatible lowercase `firered_kanto_visuals`. The code’s internal module paths and validation coverage now use that same identity, so the archive can be installed and updated through the personal index without a package-ID mismatch. The visual importer logic, required FireRed ROM verification, and corrected terrain-atlas bounds behavior are unchanged.

> If you installed either earlier test ZIP manually, remove that test copy and install `firered_kanto_visuals-0.1.2.zip` once. Future updates use the corrected identity.

## 0.1.1 — Terrain-atlas bounds correction

This update replaces the original test archive that could fail at startup with `Attempt to set out-of-range pixel!` in `lib/general_tileset.lua`. FireRed metatiles contain a 4×4 destination region, but the first archive treated their sixteen output tile IDs as though they formed one contiguous row. The generated atlas therefore advanced its Y coordinate incorrectly and could write past the image bounds.

The importer now places each 4×4 metatile explicitly on the correct 64-tile-wide grid before constructing its block references. The source-ROM validation, imported visual scope, map and gameplay preservation, and all other importer behavior are unchanged. The local importer, manifest, and visual-sprite regression suite pass with this corrected arithmetic.

## 0.1.0

Initial private test build of **FireRed Kanto Visual Importer**.

**Corrected test archive:** The originally shared 0.1.0 test ZIP calculated its generated terrain atlas as though each 4×4 metatile occupied sixteen consecutive tile IDs. That produced an out-of-range image write during startup. The replacement 0.1.0 archive lays every metatile onto the correct 64-tile-wide grid and includes a bounds-enforcing regression test for the final generated block.

This release accepts only a launcher-verified English FireRed v1.0 source ROM (`e26ee0d44e809351c8ce2d73c7400cdd`), checks the imported data against the expected revision layout, decodes the FireRed General outdoor terrain tileset, normal-colour front/back images for the existing 151 Pokémon, and mapped Kanto trainer battle portraits into private runtime assets, and exposes visual-only Gen 1 patches. Its initial terrain mapping is a controlled numeric block-to-metatile pipeline test; a terrain-semantic grass/path/water/tree/ledge/building mapping will follow after visual and gameplay validation.

The mod deliberately preserves the existing Kanto map layouts, collisions, ledges, warps, scripts, events, object placement, encounters, saves, and mechanics. It is an importer and visual layer, not a FireRed map or gameplay port.
