# FireRed Kanto Visual Importer

**Test build: 0.1.1**

FireRed Kanto Visual Importer is a visual-only overhaul for Gen1Recomp. It reads terrain graphics, Pokémon front/back battle art, and trainer battle portraits from a player-provided, launcher-verified English Pokémon FireRed v1.0 ROM and applies them to the existing Kanto game.

> This mod does **not** import or replace FireRed maps, collision, warps, NPCs, scripts, encounters, items, story progression, saves, or game mechanics. It preserves the current game’s Kanto map layouts and gameplay while replacing selected terrain visuals.

## Supported source ROMs

The launcher accepts only an exact 16 MiB English FireRed ROM whose MD5 is one of the following values.

| Revision | MD5 |
|---|---|
| FireRed English v1.0 | `e26ee0d44e809351c8ce2d73c7400cdd` |

The source ROM is selected through Gen1Recomp’s standard **Imported Files** flow. This release contains no FireRed ROM data, extracted art, or generated FireRed-derived files.

## Initial test scope

Version 0.1.1 is an initial visual-import test. It replaces the original 0.1.0 ZIP, whose incorrect 4×4 metatile-atlas placement could fail during startup with an out-of-range pixel write. The 0.1.1 terrain decoder places each metatile on the correct 64-tile-wide atlas grid; no visual scope or gameplay behavior changed beyond that bounds correction. It decodes the FireRed **General** primary terrain tileset, normal-colour Pokémon front and back pictures for the existing 151 species, and mapped Kanto trainer battle portraits into private true-colour assets. It patches only the base game’s Gen 1 `OVERWORLD` tileset plus the visual image fields of existing Pokémon and trainer records. It retains the original Kanto map block grid, map dimensions, collisions, ledges, doors, warps, scripts, events, object placement, Pokémon data, and trainer battle data.

The first profile is deliberately a **pipeline prototype**, not the final terrain-semantic remap. It preserves every Gen1 map and gameplay field, but maps the stable Gen1 Overworld block range onto the FireRed General metatile range numerically. That proves the verified import, GBA decoder, private renderer bridge, true-colour atlas, map draw path, movement, collision, and saves without pretending that every block is already semantically matched. Visual mismatches are expected in this build and are useful test evidence for the later grass/path/water/tree/ledge/building mapping table.

## Installation and test procedure

Import the mod ZIP through Gen1Recomp, enable **FireRed Kanto Visual Importer**, select one of the supported FireRed ROMs when the launcher requests it, and start or continue a Gen 1 game. Do not test this release on Gold.

Please test the following areas after import: Pallet Town, Route 1, Viridian City, Route 2, Viridian Forest, Pewter City, a route with tall grass, a water route, an outdoor ledge, an outdoor building entrance, a wild battle, a trainer battle, a Gym Leader battle, and at least one save/continue cycle. Confirm that Pokémon front sprites, player-side back sprites, trainer portraits, movement, grass encounters, ledge jumps, door warps, NPC interaction, map connections, save/load, and disabling the mod remain normal.

## Current limitations

FireRed and Gen1Recomp use different metatile systems. A pixel-perfect FireRed map port is not the target of this mod. The intended result is a FireRed-style visual layer over existing Kanto geometry. Later test versions can add purpose-built compatibility profiles for routes/towns, forests, caves, interiors, gyms, ships, and map-specific locations.

## Credits and source policy

The importer architecture is informed by Gen1Recomp’s supported required-import system and the user-provided-ROM cache patterns demonstrated by Crystal 251 and StadiumBattleFX. FireRed graphics are read from the player’s verified local ROM at runtime and are never included in this project’s public release package.
