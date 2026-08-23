-- FireRed Kanto Visual Importer: explicit map-semantic profile catalogue.
--
-- A profile never changes a Gen 1 map's dimensions, collision, warps, object
-- positions, ledges, grass, or scripts. It defines where to sample a 2×2 group
-- of native FireRed 16px metatiles for each existing Gen 1 32px map block.
-- The sampler reassembles those four 2×2 FireRed tile cells into one locked
-- 4×4 Gen 1 tile block. No image-wide or fractional scaling is permitted.

local Profiles = {}

Profiles.PALLET_TOWN = {
  id = "FIRERED_PALLET_TOWN",
  map = "PALLET_TOWN",
  expectedTarget = { width = 10, height = 9, tileset = "OVERWORLD" },
  source = {
    -- FireRed English v1.0, pret/pokefirered symbols branch.
    layout = 0x082DD4C0,
    header = 0x08350618,
    width = 24,
    height = 20,
    borderWidth = 2,
    borderHeight = 2,
    primaryTileset = 0x082D4A94, -- gTileset_General
    secondaryTileset = 0x082D4AAC, -- gTileset_PalletTown
    -- Reconstruct the complete verified 24×20 FireRed town layout into the
    -- fixed 10×9 Gen 1 town footprint. This keeps Pallet's outdoor landmarks
    -- in one bounded transform instead of mixing a broad crop with door-only
    -- overrides. Collision, warps, grass, and all map coordinates remain Gen 1-owned.
    originX = 1,
    originY = 2,
    visualMode = "layout-fit",
  },
  outdoor = true,
}

Profiles.REDS_HOUSE_1F = {
  id = "FIRERED_REDS_HOUSE_1F",
  map = "REDS_HOUSE_1F",
  expectedTarget = { width = 4, height = 4, tileset = "REDS_HOUSE_1" },
  source = {
    layout = 0x082D5200,
    header = 0x08350D50,
    width = 13,
    height = 10,
    borderWidth = 2,
    borderHeight = 2,
    primaryTileset = 0x082D4BB4, -- gTileset_Building
    secondaryTileset = 0x082D4C74, -- gTileset_GenericBuilding1
    -- This crop keeps the FireRed 1F room and front-door row locked to Red's
    -- existing four-by-four house footprint. The native Gen 1 warp at the
    -- lower doorway retains its exact map coordinate and gameplay behavior.
    originX = 2,
    originY = 2,
    -- The Gen 1 upstairs trigger occupies target block (3,0); FireRed places
    -- its stair tile one source cell farther east. This keeps the original
    -- Gen 1 staircase/warp coordinate and collision class intact.
    overrides = {
      ["3,0"] = { x = 9, y = 2 },
    },
  },
  outdoor = false,
}

function Profiles.each()
  return ipairs({ Profiles.PALLET_TOWN, Profiles.REDS_HOUSE_1F })
end

return Profiles
