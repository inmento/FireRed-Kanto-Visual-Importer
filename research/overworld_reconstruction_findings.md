# Overworld Reconstruction Findings

This note contains only design conclusions and public/source metadata; it contains no user media, ROM bytes, extracted images, or generated source-ROM cache.

## Private local input classification

The user-authorized local file was inspected without execution or redistribution. It is exactly 16,777,216 bytes and its MD5 is `e26ee0d44e809351c8ce2d73c7400cdd`, the importer’s existing expected FireRed English v1.0 checksum. It is therefore handled strictly as a private local FireRed source input; it must never be committed, uploaded, packaged, or used as a public artifact.

The current public `pret/pokefirered` checkout follows its documented source-build workflow: its ordinary build produces `pokefirered.gba` from the decompilation project and does not declare a `baserom.gba` extraction prerequisite in the tracked build rules. Its `MapLayout` source model remains useful as a layout/tileset/map-grid reference, but it does not itself convert a private ROM into Gen1Recomp Lua data.

## New runtime evidence

The user’s newest gameplay clip shows that the active experimental pipeline can render a FireRed-style Pallet Town outdoors: FireRed-style grass, stone boundaries, paths, flower beds, and building facades appear after exiting the house. The present outdoor defect is therefore not total profile absence. The user nevertheless reports that the earlier pre-release predecessor had a populated but oversized overworld and wants the old outdoor coverage recovered at the correct footprint.

## Design consequence

The current `composeProfileBlock` already preserves the intended 32px Gen1 block footprint by placing a 2×2 group of native 16px FireRed metatiles into a 4×4 target-tile block. Reintroducing the retired numeric/global preview would repeat the prior semantic error. The next correction must be profile-specific: construct Pallet’s source-to-target map transformation from declared source/target landmarks and full grid anchors, while retaining all Gen1 target coordinates and four-cell semantic locks. No global scale change or block-ID substitution is acceptable.

## Full-layout decoder correction

The first full-layout validation exposed a previously hidden converter defect: some valid FireRed primary metatiles reference global background tile IDs at or above 640. The public FireRed field-map loader copies the primary tileset into VRAM range 0..639 and the active secondary tileset into range 640..1023. A metatile entry therefore uses a combined global tile index, regardless of whether the metatile itself comes from the primary or secondary metatile table.

The previous converter incorrectly indexed every metatile-entry tile number into the metatile’s own decoded tile sheet. That worked for the small initial crops but failed when Pallet cells referenced global tile 641, producing an invalid 76-tile primary-sheet lookup. The converter now resolves global tile IDs below 640 from the primary sheet and IDs 640..1023 from the secondary sheet. It also reads secondary palettes as their full 16-slot table and resolves each metatile palette ID against the primary 0..6 or secondary 7..15 palette bank, matching the public loader contract.

After this correction, the local-only in-memory Pallet profile built successfully from the private verified source: a 512×240 transient atlas, 91 generated blocks (90 target blocks plus border), and 357 semantic lock tiles. No extracted graphics, ROM bytes, or generated atlas was written to the repository or release tree.
