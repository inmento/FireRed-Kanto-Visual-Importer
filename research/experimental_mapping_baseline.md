# Experimental Landmark-Mapping Branch Baseline

Branch: `experimental/landmark-mapping-v025`

Stable rollback release: `v0.2.4` at `57561e5`.

## Stable behavior retained before experimentation

- The FireRed import is verified and the semantic profiles construct at the intended Gen 1 footprint.
- Red’s House 1F is reachable from the native upstairs room.
- The Red’s House 1F downstairs exit returns to the overworld; the v0.2.3 four-cell semantic lock fixed the reported movement soft lock.
- The first-floor movement boundary is now safe to explore.

## Remaining visual defects to research

- In Red’s House 1F, the kitchen sink, window, television, and related wall furniture render too high for their intended Red footprint; the upstairs stair visual resembles a banner rather than a staircase.
- The profile’s compact-map background/wall composition still needs landmark-level tuning, but must not change exits, collision, or warps.
- Pallet Town’s intended FireRed outdoor visual conversion needs independent verification and landmark mapping. The user’s latest clip is the reference evidence for distinguishing its actual appearance from the first-floor profile.

## Experimental policy

This branch may use public FireRed/Red gameplay, open-source decompilation layout metadata, and public ROM-hack/source techniques only to understand map semantics and coordinate-mapping methods. It must not copy third-party code, package Nintendo assets, store ROM-derived atlases, or change Gen 1 gameplay coordinates. All experimental releases remain pre-releases until in-game evidence supports promotion.

## Post-baseline runtime clarification

Inspection of the supplied v0.2.4 recording at approximately 34 seconds shows FireRed-style outdoor visual content: saturated FireRed grass, flower clusters, large gray stone boundary pieces, and a FireRed building facade. The visual profile is therefore active on the outside path later in the clip. The user’s report that Pallet appeared unchanged remains important evidence for the house-exit/early-overworld transition and for landmark composition, but it should not be modeled as a total failure to construct the Pallet profile.

Experimental research must compare named map positions and transition timing rather than treat any single early frame as proof that the outdoor profile did not apply.

## v0.2.5-rc.1 review and next correction

The user supplied side-by-side Red/Yellow and FireRed 1F/2F house references and asked that the still images not be reopened; this branch relies on their visible landmark arrangement plus the new gameplay video and existing public event metadata.

The v0.2.5-rc.1 contact sheet shows the four-cell movement safety behavior remains intact: the player traverses 1F and exits to the FireRed-style outdoor Pallet scene. The house visual alignment improved but remains imperfect.

A concrete coordinate error was identified in the experimental mapping: FireRed’s public 1F metadata places the TV interaction at source cell `(6,1)`. A 32px target block samples a 2×2 source-cell square. The target upper-left block `(0,0)` must therefore sample source base `(5,0)` to contain `(6,1)`. The prior experimental override incorrectly placed `(5,0)` at target block `(1,0)` and assigned `(0,0)` source base `(2,0)`, shifting the TV/kitchen zone one 32px target block. The next RC should set `(0,0) -> (5,0)` and move the adjacent top-row continuation to `(1,0) -> (7,0)`; keep the tested stair, Mom/table, and front-exit mappings unchanged.

The user described Pallet as unaffected, but the latest experimental recording contains a later outdoor sequence with FireRed-style grass, flowers, large stone borders, and FireRed building facades. Treat Pallet as profile-active but still subject to future landmark tuning; do not make a blind Pallet cache or source-address change in the next focused RC.

## v0.2.5-rc.2 three-way composition review

The user clarified that the black-and-white still is the original Red 1F composition and the colored still is the FireRed 1F composition, and requested direct comparison to the rc.2 video. The supplied still images were not reopened. The runtime contact sheet confirms that rc.2 has an active FireRed visual room and keeps the player mobile, but its composition is still a patchwork: individually corrected upper-wall samples do not make the whole 4×4 Red room read as one coherent translation of either reference arrangement.

The next revision must be a complete 4×4 target-block composition table, not another isolated shift. Its hard role constraints are: target `(0,0)` contains the Red upper-left TV/kitchen role and samples FireRed `(5,0)` so it includes the documented FireRed TV at `(6,1)`; target `(3,0)` contains the stair role and samples FireRed `(9,1)` around the documented stair `(10,2)`; target `(2,2)` contains the Mom/table role and samples FireRed `(7,3)` around the documented Mom/table center `(8,4)`; target `(1,3)` contains the front-exit role and samples FireRed `(4,7)` around the documented FireRed exits `(4,8)`/`(5,8)`. Every other target block should be assigned explicitly as supporting wall/floor/furniture context for these roles. The original Gen 1 target map, four-cell semantics, and warps remain immutable.
