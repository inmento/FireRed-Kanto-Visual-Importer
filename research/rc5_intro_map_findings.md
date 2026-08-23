# RC.5 Intro, Stair, and Pallet Findings

This note records observations from the user-supplied rc.5 gameplay recording. It contains no extracted source graphics, ROM bytes, or retained user media.

## Confirmed working path

The recording continues to show coherent FireRed battle art. This establishes that the FireRed front/back battle asset decoder and its new path-specific scale route are independent of the missing introductory and starter-selection images. Any repair for those screens must therefore add only their dedicated UI/intro asset registrations and must not alter the battle-art decoder or battle record patches.

## Introductory and starter image gaps

The current importer patches species `spriteFront`, `spriteBack`, and trainer `pic` fields. The title/intro demonstration and starter-selection portrait slots are not the battle renderer. They use separate engine screens and paths, so they remain unregistered and appear blank even when battle sprites are available. The short introductory flow supplied by the user’s Brief Oak mod makes this absence especially visible but does not cause it.

## House stair observation

Red’s House displays a recognisable, nearly aligned FireRed stair composition. This confirms that the dedicated compact interior profile preserves the fixed Gen 1 stair warp while sourcing a coherent local FireRed region. The remaining difference is a small crop/origin refinement rather than an atlas-size or movement-semantic failure.

## Pallet observation

Pallet still combines FireRed replacements with retained Gen 1 visual material. The current `base-overrides` design begins from copied Gen 1 block pixels, so visual coherence cannot be achieved by changing source-ROM primary/secondary tileset addresses or reducing FireRed content to a four-colour palette. The next design must decide target coordinates deliberately: retain only explicit Gen 1 structural blocks, render declared grass/building regions with FireRed samples, and avoid any repeated-block-ID or whole-layout transform.

All generated media used for this diagnosis remains temporary and must be deleted before any commit or release.

## Resolver-based non-battle asset root cause

The Gen 1 title and Oak speech screens both resolve a species front-sprite path and then call `love.graphics.newImage` directly. Battle rendering uses the importer’s `Assets.image` bridge, but the resolver-based screens received the importer-owned `firered/generated/...` string as though it were a disk path. No generated file exists by design, so those screens silently rendered no image despite the correct patched species `spriteFront` record. The repair is confined to the importer-owned asset namespace: `Assets.resolve` now returns the cached in-memory ImageData for generated paths. LÖVE accepts ImageData in `newImage`, so title and Oak screens can load the same private in-memory asset as battles without a filesystem write or engine patch. External resolver paths remain untouched.

## Stair decision

Both house floors currently declare a dedicated override at target block `(3,0)` that samples the FireRed stair at source `(9,2)`, while retaining the original Gen 1 stair semantics and warp. The recording confirms this is close enough to avoid speculative adjustment. The source origin and override will remain unchanged in the next correction; a stair move requires a new focused visual mismatch, not a broad coordinate guess.

## Pallet policy decision

The active Pallet profile remains coordinate-scoped. The desired Gen 1 facelift is FireRed grass and compact building samples alongside intentionally retained Gen 1 trees, stones, water, ledges, fences, and gameplay geometry. The palette-coherence correction is intended to eliminate the unintended grayscale third layer under advanced-colour mode; it does not broaden the scope into a full FireRed town replacement.
