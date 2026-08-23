# rc.3 gameplay regression findings

## Scope isolation

The first two supplied gameplay recordings show the FireRed battle-art path functioning correctly: player and opponent battle sprites render, battle animation/turn flow continues, and later interior battle scenes still use the expected imported battle visuals. The user has explicitly deferred the missing proper Red back sprite. No map-profile repair should modify `visual_sprites.lua`, `visual_sprite_profile.lua`, battle targets, or the battle-art cache path.

## Early map observations

The first recording shows gameplay continuing through Route 1 and other unprofiled areas while battle art remains active. Route 1 is not a map profile and should therefore stay Gen 1-owned. The contact sheet does not establish a generated-atlas out-of-bounds failure there; it confirms that any visual fault must be separated from the working battle import path and inspected in the dedicated Pallet/house recordings.

The second recording likewise confirms battle stability before an ordinary Gen 1 interior. The next analysis must focus on the remaining third recording, which is expected to contain the user-reported bedroom/Pallet evidence. Locally extracted frames are diagnostic-only and must be removed before source control or release packaging.

## Pallet exterior frame at approximately 4 seconds

The high-resolution frame confirms that rc.3 does not reproduce the rc.2 whole-layout overlap, but the narrow profile is still not an acceptable Gen 1 facelift. The explicit FireRed house rectangles are visibly much larger and compositionally incompatible with the surrounding Gen 1 Pallet blocks. In addition, the block-ID-wide grass/ground override affects a repeated Gen 1 block used across more than the intended grass region, producing large FireRed ground fields adjacent to unrelated Gen 1 paths, walls, and features. This is a profile-classification/composition defect, not a battle-art failure and not evidence that the converter lacks 2×2 metatile stitching.

The replacement must therefore avoid a global `blockOverrides[1]` rule for Pallet. It needs an explicit coordinate-level grass mask and either smaller, door-anchored building samples or a conservative rollback of exterior buildings until their declared footprint can be verified against the unchanged Gen 1 coordinates.

## Pallet exterior frames at approximately 8 and 12 seconds

The additional frames confirm the earlier observation. The FireRed houses are not blended or corrupted by a missing metatile stitch; each appears as a clean source image, but the declared 3×2 target-block exterior rectangles are too large for the corresponding Gen 1 building footprints and overwrite adjacent Gen 1 town space. The Oak’s Lab rectangle similarly occupies a visually incompatible area. The repeated light FireRed ground is also visibly over-applied because Gen 1 base block ID 1 is not a reliable grass-only category for a map-wide block-ID override.

The next repair should retain the successful 32×32 2×2 source-block assembler and the battle import path, but replace Pallet’s guessed building rectangles with a target-footprint-derived composition. Until each footprint is validated, the conservative safe behavior is to preserve the Gen 1 exterior pixels outside explicitly proven FireRed building cells. Grass must be selected by declared target coordinate positions, not global target block ID.

## Target-footprint reconciliation

The Gen 1 Pallet grid confirms that Red’s House occupies target blocks (2,1), (3,1), (2,2), and (3,2), and Blue’s House occupies (6,1), (7,1), (6,2), and (7,2). Their entrance warps are in the lower-left blocks (2,2) and (6,2), respectively. Oak’s Lab’s structural blocks are (6,4), (7,4), (6,5), and (7,5), with its entrance warp in lower-left block (6,5); the neighboring x=8 blocks are ordinary target-ground blocks, not laboratory structure.

The next profile composition will use only these actual target footprints. It will drop the guessed third column around every exterior, retain FireRed’s verified door-containing 2×2 source samples at the existing Gen 1 entrance blocks, and replace the global `blockOverrides[1]` rule with an explicit coordinate list for the target-ground positions that the user wants to facelift. No maps, events, warps, battle-art targets, sprite profiles, or semantics are part of this change.

## Red’s House 1F early frame

The early frame shows a coherent FireRed dining-room crop, including the table/furnishings and the Gen 1 player/object context, rather than the doubled exterior artifact seen in Pallet. Its visible limitations stem from the fixed Gen 1 4×4-block interior footprint: FireRed Player’s House 1F is larger, so the current profile intentionally uses an unscaled compact crop rather than another whole-room scale transform. The resulting partial-room presentation should be treated as a separate composition-quality issue, not evidence of a broken battle import or of the Pallet profile’s oversized-rectangle fault. The next map-only change should keep this 1F profile unchanged until a dedicated, door-and-stair-anchored interior composition can be authored and tested.
