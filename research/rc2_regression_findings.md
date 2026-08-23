# rc.2 Regression Findings

No user media is retained in this repository. This note records only diagnostic conclusions from the supplied gameplay recording.

## Direct frame evidence

The rc.2 Pallet visual result is not a narrow grass/buildings facelift. An outdoor frame shows a FireRed house facade composited with unrelated room/furniture and facade fragments inside its building footprint. The roof, upper windows, lower doorway, and interior-like table/floor fragments do not form one coherent exterior. This confirms that the full-layout-fit output has been sampled across incompatible source regions after compression into the smaller Gen 1 footprint; a post-fit 32px doorway repaint cannot repair a building whose surrounding source pixels came from different FireRed landmarks.

A separately inspected indoor frame shows a room-like scene with a table, chairs, and a bottom doorway. It is visually more coherent than the outdoor composite, but it does not establish that the underlying exit transition is safe. The user reports an Oak’s Lab exit failure, so all exit/doorway profiles must continue to be treated as gameplay-critical regardless of a single static frame.

The video-analysis timestamp labels conflict with direct frame extraction for the later timestamp. The direct image evidence, not automatic timestamp labeling, will govern the repair design.

## Root-cause direction

The whole-Pallet proportional layout-fit mode is unsuitable for buildings. It blends source geometry that cannot retain its structure at the fixed 10×9 Gen 1 block footprint and can make visual entry placement ambiguous. The next architecture must remove full-scene fitting from building regions. It should preserve the base Gen 1 map everywhere by default, layer only explicitly declared grass/ground visual regions, and paint each building exterior/interior from a dedicated compact source crop anchored to the fixed Gen 1 door/warp block. No visual overlay may replace the four original movement-cell semantic tiles.

## Additional frame observations

The Oak’s Lab/Pallet exterior frame visibly confirms the user’s report: the laboratory-like building is composed from mismatched layers—roof/window rows, indoor wall/furniture fragments, and the visual doorway do not belong to one coherent façade. It is therefore unsafe to interpret its apparent doorway as proof that the fixed Gen 1 exit/entry is usable.

The extracted early 1F frame contains a compact FireRed-style room crop with a table/chairs and bottom visual door, but it covers only part of the displayed map. This static frame does not disprove the reported later 1F jumble or transition failure. The only safe conclusion is that the current profile’s broad 4×4 source crop must be replaced by an explicitly composed room profile before its appearance or exit behavior can be trusted.

## Source-layout reconciliation

Public FireRed map records confirm that map grid entries identify a 10-bit metatile, while collision and elevation are separate fields. FireRed metatile attributes encode behavior in bits 0–8 and terrain in bits 9–13; therefore a visual importer may use source metatiles as declared visual samples without importing FireRed collision. The public General and Pallet Town tile sheets also separate generic outdoor motifs from Pallet-specific building fragments. This reinforces the required architecture: grass/ground samples must be sourced independently from each compact building composition.

The existing `layout-fit` mode fails because it proportionally projects FireRed’s 24×20 grid onto Gen 1’s 10×9 grid. No scale-preserving transform can keep the spatial geometry of FireRed’s buildings coherent under that compression. The repair must replace `layout-fit` rather than append further source-pixel overrides to it.

## Compact source-crop validation

A temporary, in-memory native-grouped rendering of the authorized local FireRed Player’s House 1F layout shows a coherent room rather than a candidate for proportional fitting: kitchen fixtures occupy the top row, the dining area is central, the visual front door is at the lower source edge, and the stairs are at the upper-right. These align with the known FireRed event geometry (front exits around source cells 4–5,8 and stairs around 10,2). The new interior strategy should map this coherent compact room directly to the fixed Gen 1 4×4 footprint with declared overrides for the Gen 1 front exits at cells (2,7)/(3,7) and stair at (7,1). It must not apply the Pallet whole-layout transform to interiors.

## Corrective profile validation

The live Pallet profile has been redesigned as a **base-overrides** profile. It copies the installed Gen 1 map block pixels by default and overlays only a declared FireRed grass/ground sample plus three compact source rectangles for Red’s House, Blue’s House, and Oak’s Lab. This removes the disproven whole-layout transform entirely from Pallet’s active profile. The revised Pallet profile completed an in-memory build against the authorized local source with a 512×240 atlas, 91 generated blocks, and 357 locked semantic tiles.

A public-data-guided local structure check also identified the FireRed Player’s House 2F layout/header and verified a separate compact Red’s House 2F profile against the authorized local source. This profile remains independent of the Pallet overlay and anchors the visual stair to Gen 1’s existing upstairs return warp. The layout and source rendering artifacts used to reach these conclusions are temporary diagnostics only and are removed before source control or release packaging.
