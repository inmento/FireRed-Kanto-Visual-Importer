# FireRed Kanto Visual Importer

**Test build: 0.1.5**

FireRed Kanto Visual Importer reads **player-provided** visual data from a launcher-verified English Pokémon FireRed v1.0 ROM. It imports FireRed-style Pokémon front/back battle pictures and mapped trainer battle portraits for the existing Gen 1 Kanto games. It never distributes the FireRed ROM, extracted FireRed artwork, or generated FireRed-derived files.

> **Version 0.1.5 makes collision-aligned Gen 1 terrain the safe default.** The former numeric FireRed terrain substitution is retained only as an explicit diagnostic preview because it cannot make FireRed doors, paths, ledges, water, and buildings line up with Gen 1’s unchanged map block grid.

| Component | Default behavior in v0.1.5 | Gameplay effect |
|---|---|---|
| Pokémon battle art | Imported from the verified FireRed ROM. | Visual only. |
| Trainer battle portraits | Imported from the verified FireRed ROM. | Visual only. |
| Overworld terrain, houses, doors, paths, and map blocks | Uses normal Gen 1 terrain geometry. | Doors, collision, warps, ledges, grass, and map transitions stay aligned and usable. |
| **FR TERRAIN PREVIEW** option | Off by default; restores the old numeric FireRed General-terrain prototype after restart. | Experimental only; its visible structures do not reliably identify Gen 1 collision or warp cells. |

## Why the old terrain looked too large and blocked the visible exit

FireRed uses **16×16 metatiles**, while Gen1Recomp renders every map block as a **32×32** region built from sixteen 8×8 tiles. The original prototype correctly converted each FireRed metatile into one 32×32 Gen1Recomp block. The apparent “too large” scale therefore was not a display zoom bug that can safely be halved.

The actual defect was the prototype’s **numeric block substitution**: it replaced Gen 1 block `n` with unrelated FireRed metatile `n`, while intentionally retaining Gen 1 maps, collision, and warps. A FireRed-looking door could therefore appear somewhere different from the Gen 1 warp tile that actually changes maps. Walking to the visible front door could leave the player unable to exit even though the base-game warp still existed elsewhere in the preserved block geometry.

Version 0.1.5 removes that unsafe terrain swap from the default path. It also includes the v0.1.4 true-colour renderer correction for the earlier white/fragmented outdoor transition seen on leaving interiors. A real FireRed terrain layer requires deliberately authored **semantic compatibility profiles** for each relevant Gen 1 tileset/map category; it cannot be produced by a universal resize operation.

## Supported source ROM

The launcher accepts only the following exact source file through its standard **Imported Files** flow.

| Revision | MD5 |
|---|---|
| FireRed English v1.0 | `e26ee0d44e809351c8ce2d73c7400cdd` |

## Installation and update

Install or update **FireRed Kanto Visual Importer** through the personal index, enable it, and select the verified FireRed ROM when the launcher requests it. The stable package identity remains `FIRERED_KANTO_VISUALS`, so installations from the original uppercase releases can update normally.

For the safe v0.1.5 configuration, leave **FR TERRAIN PREVIEW** disabled. If it was enabled on an existing installation, turn it off and restart the game before testing the player’s house exit. You should be able to leave the house, enter buildings, use doors, walk on paths, trigger grass, use ledges, and change maps using their normal Gen 1 behavior.

The preview option is for diagnostic screenshots only. Do not rely on a previewed building entrance, path, or ledge to represent the real collision/warp location until a future map-semantic profile explicitly supports that location.

## Scope and limitations

This mod does **not** import or replace FireRed maps, collision, warps, NPCs, scripts, encounters, items, story progression, saves, or gameplay mechanics. It preserves the current Red, Blue, or Yellow Kanto map layouts and gameplay.

A pixel-perfect FireRed map port is not the purpose of this importer. Future visual work must map FireRed art to the **meaning** of specific Gen 1 terrain blocks—such as grass, road, water, tree, ledge, building exterior, door, and interior—rather than assuming that the two games use matching numeric metatile IDs.

## Credits and source policy

The importer architecture follows Gen1Recomp’s supported required-import system and uses player-local verified-ROM data at runtime. FireRed source graphics are never included in this public project or its release ZIP.
