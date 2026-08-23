# Public Landmark-Mapping Evidence

This document records text-only layout observations for the experimental mapping branch. It contains no video frames, game graphics, ROM data, or third-party source code.

## FireRed / LeafGreen public walkthrough reference

Public walkthrough analyzed: `https://www.youtube.com/watch?v=phap7cybNjg`.

- Player’s House 1F: stairs are in the upper-right; kitchen/sink occupy the upper-left; a four-chair dining table is central; the television is at lower-left; and the front exit is bottom-center.
- Pallet Town: Player’s House is northwest, Rival’s House northeast, Oak’s Lab southeast, with routes/paths connecting them; northern grass leads toward Route 1 and the southwestern edge contains water.

## Original Red public walkthrough reference

Public walkthrough analyzed: `https://www.youtube.com/watch?v=AP8nlJcjw4I`.

- Red’s House 1F preserves the same coarse semantic arrangement: TV upper-left, kitchen/sink along the top, stair upper-right, table center, and front exit bottom-center.
- Pallet Town retains the same landmark ordering: Player’s House northwest, Rival’s House northeast, Oak’s Lab southeast, connected paths, northern Route 1 grass, and southern/southwestern water.

## FireRed decompilation metadata reference

The local public `pret/pokefirered` reference declares `PalletTown_PlayersHouse_1F` as a 13×10 layout using the Building primary and GenericBuilding1 secondary tilesets. Its event data places the Mom object at source cell `(8,4)`, the TV interaction at `(6,1)`, the upstairs warp at `(10,2)`, and front exit cells at `(4,8)` and `(5,8)`.

## Experimental mapping consequence

The current linear `origin + targetBlock * 2` crop cannot guarantee landmark alignment across two differently shaped games. The experimental branch should express Red’s House 1F and Pallet Town as explicit target-block-to-source-cell mappings for landmark blocks, with an independently validated backdrop/default mapping. It must leave every target-map block coordinate and semantic tile role unchanged.
