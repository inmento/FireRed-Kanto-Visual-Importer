# Selective Pallet Overlay Findings

No user media is retained in this repository; this note records only conclusions from the latest supplied runtime clip.

## Runtime classification

The v0.3.0-rc.1 full-layout reconstruction now renders a coherent, smaller FireRed-style Pallet outdoor scene. The user wants this terrain benefit—especially FireRed grass and ground/path texture—but does not want it to replace the original Gen 1 large trees or small stone landmarks. The current full-scene approach also produces visually misleading building-door and Oak’s Lab entrance art because the FireRed visual location cannot move the Gen 1 warp coordinate.

## Policy

Use a declared **block-ID mask** instead of a broad collision heuristic. For Pallet, copy only the original Gen 1 block pixels that form the large-tree envelope and the requested small-rock block into the generated profile atlas. All other target blocks continue to use the bounded FireRed layout reconstruction, so FireRed grass, ground, paths, water, and buildings remain present. The existing four-cell semantic tile lock remains mandatory for every generated block.

A second declared layer repaints only the three FireRed doorway samples for Red’s House, Blue’s House, and Oak’s Lab after the whole-layout fit. This aligns the visual entries with the existing Gen 1 warp coordinates without moving any map data. It requires no Nintendo source content in the package: the base Gen 1 tileset image is loaded from the user’s already-installed game at runtime and copied only into the in-memory generated atlas.
