# Changelog

## 0.1.1 — Terrain-atlas bounds correction

This update replaces the original test archive that could fail at startup with `Attempt to set out-of-range pixel!` in `lib/general_tileset.lua`. FireRed metatiles contain a 4×4 destination region, but the first archive treated their sixteen output tile IDs as though they formed one contiguous row. The generated atlas therefore advanced its Y coordinate incorrectly and could write past the image bounds.

The importer now places each 4×4 metatile explicitly on the correct 64-tile-wide grid before constructing its block references. The source-ROM validation, imported visual scope, map and gameplay preservation, and all other importer behavior are unchanged. The local importer, manifest, and visual-sprite regression suite pass with this corrected arithmetic.

## 0.1.0

Initial private test build of **FireRed Kanto Visual Importer**.

**Corrected test archive:** The originally shared 0.1.0 test ZIP calculated its generated terrain atlas as though each 4×4 metatile occupied sixteen consecutive tile IDs. That produced an out-of-range image write during startup. The replacement 0.1.0 archive lays every metatile onto the correct 64-tile-wide grid and includes a bounds-enforcing regression test for the final generated block.

This release accepts only a launcher-verified English FireRed v1.0 source ROM (`e26ee0d44e809351c8ce2d73c7400cdd`), checks the imported data against the expected revision layout, decodes the FireRed General outdoor terrain tileset, normal-colour front/back images for the existing 151 Pokémon, and mapped Kanto trainer battle portraits into private runtime assets, and exposes visual-only Gen 1 patches. Its initial terrain mapping is a controlled numeric block-to-metatile pipeline test; a terrain-semantic grass/path/water/tree/ledge/building mapping will follow after visual and gameplay validation.

The mod deliberately preserves the existing Kanto map layouts, collisions, ledges, warps, scripts, events, object placement, encounters, saves, and mechanics. It is an importer and visual layer, not a FireRed map or gameplay port.
