# Changelog

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
