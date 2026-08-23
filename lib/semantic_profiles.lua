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
    primaryTileset = 0x082D4A94, -- gTileset_General
    secondaryTileset = 0x082D4AAC, -- gTileset_PalletTown
    -- Pallet's playable town grid begins after the 1-cell decorative source
    -- border. Two source metatiles fill one Gen 1 target block on each axis.
    -- The profile deliberately samples the source map coordinate system, never
    -- matches unrelated Gen 1/FireRed block IDs.
    originX = 1,
    originY = 2,
    -- The original games place Oak's Lab one source cell farther east than its
    -- Gen 1 block footprint. Keep the real Gen 1 Oak-Lab warp block at (6,5)
    -- while sampling the FireRed Lab doorway at source cells 15..16, 12..13.
    overrides = {
      ["6,5"] = { x = 15, y = 12 },
    },
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
