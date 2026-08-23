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
    -- Pallet's playable town grid begins after the 1-cell decorative source
    -- border. Two source metatiles fill one Gen 1 target block on each axis.
    -- The profile deliberately samples the source map coordinate system, never
    -- matches unrelated Gen 1/FireRed block IDs.
    originX = 1,
    originY = 2,
    -- Explicit landmark samples are intentionally sparse. They retain each
    -- Gen 1 warp block while sampling the equivalent FireRed entrance cell.
    -- The remainder uses the bounded outdoor crop above.
    overrides = {
      -- Red's House: target doorway (x5,y5) -> FireRed doorway (x6,y7).
      ["2,2"] = { x = 5, y = 6 },
      -- Blue's House: target doorway (x13,y5) -> FireRed doorway (x15,y7).
      ["6,2"] = { x = 14, y = 6 },
      -- Oak's Lab: target doorway (x12,y11) -> FireRed doorway (x16,y13).
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
    borderWidth = 2,
    borderHeight = 2,
    primaryTileset = 0x082D4BB4, -- gTileset_Building
    secondaryTileset = 0x082D4C74, -- gTileset_GenericBuilding1
    -- The room body uses the conservative source crop. Landmark blocks below
    -- use public FireRed/Red warp, sign, and object coordinates so furniture
    -- cannot drift a whole 32px target block while gameplay stays Gen 1-owned.
    originX = 2,
    originY = 2,
    overrides = {
      -- Upper-left kitchen/window zone; source TV interaction is at (6,1).
      ["0,0"] = { x = 2, y = 0 },
      ["1,0"] = { x = 5, y = 0 },
      -- FireRed stair warp is (10,2); Gen 1's is in target block (3,0).
      ["3,0"] = { x = 9, y = 1 },
      -- FireRed Mom/table center (8,4) -> Gen 1 Mom/table block (2,2).
      ["2,2"] = { x = 7, y = 3 },
      -- FireRed front exits (4,8)/(5,8) -> Gen 1 front-exit block (1,3).
      ["1,3"] = { x = 4, y = 7 },
    },
  },
  outdoor = false,
}

function Profiles.each()
  return ipairs({ Profiles.PALLET_TOWN, Profiles.REDS_HOUSE_1F })
end

return Profiles
