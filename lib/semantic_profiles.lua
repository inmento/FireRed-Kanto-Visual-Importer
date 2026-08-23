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
    -- A narrow Gen 1 facelift: begin every target block as its original Gen 1
    -- visual, then overlay only declared FireRed samples. This deliberately
    -- avoids compressing the 24×20 FireRed town through the 10×9 Gen 1 layout.
    -- Trees, stones, water, ledges, fences, paths, and every undeclared target
    -- block remain Gen 1 visuals; collision, warps, grass, and coordinates are
    -- always Gen 1-owned.
    originX = 0,
    originY = 0,
    visualMode = "base-overrides",
    -- Gen 1 block 1 is Pallet's ordinary grass/ground field. This is a compact
    -- unscaled FireRed ground sample, not a town-layout transform.
    blockOverrides = {
      [1] = { x = 2, y = 2 },
    },
    -- Each exterior is a coherent 3×2 target-block rectangle sampled from its
    -- matching 6×4 FireRed building rectangle. The bottom-middle target blocks
    -- remain the exact original Gen 1 entrance/warp blocks.
    overrides = {
      -- Red's House (Gen 1 door block 2,2; FireRed source door at 6,7).
      ["1,1"] = { x = 4, y = 4 }, ["2,1"] = { x = 6, y = 4 }, ["3,1"] = { x = 8, y = 4 },
      ["1,2"] = { x = 4, y = 6 }, ["2,2"] = { x = 6, y = 6 }, ["3,2"] = { x = 8, y = 6 },
      -- Blue's House (Gen 1 door block 6,2; FireRed source door at 15,7).
      ["5,1"] = { x = 13, y = 4 }, ["6,1"] = { x = 15, y = 4 }, ["7,1"] = { x = 17, y = 4 },
      ["5,2"] = { x = 13, y = 6 }, ["6,2"] = { x = 15, y = 6 }, ["7,2"] = { x = 17, y = 6 },
      -- Oak's Lab (Gen 1 door block 6,5; FireRed source door at 16,13).
      ["6,4"] = { x = 14, y = 10 }, ["7,4"] = { x = 16, y = 10 }, ["8,4"] = { x = 18, y = 10 },
      ["6,5"] = { x = 14, y = 12 }, ["7,5"] = { x = 16, y = 12 }, ["8,5"] = { x = 18, y = 12 },
    },
  },
  outdoor = true,
}

Profiles.REDS_HOUSE_2F = {
  id = "FIRERED_REDS_HOUSE_2F",
  map = "REDS_HOUSE_2F",
  expectedTarget = { width = 4, height = 4, tileset = "REDS_HOUSE_2" },
  source = {
    layout = 0x082D52FC,
    header = 0x08350D6C,
    width = 12,
    height = 9,
    borderWidth = 2,
    borderHeight = 2,
    primaryTileset = 0x082D4BB4, -- gTileset_Building
    secondaryTileset = 0x082D4C74, -- gTileset_GenericBuilding1
    -- The compact source crop covers the bedroom. Gen 1's stair warp is at
    -- target block (3,0), while FireRed's visual stair begins one source cell
    -- farther east; retain the real Gen 1 stair semantic and repaint only it.
    originX = 2,
    originY = 1,
    overrides = {
      ["3,0"] = { x = 9, y = 2 },
    },
  },
  outdoor = false,
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
  return ipairs({ Profiles.PALLET_TOWN, Profiles.REDS_HOUSE_1F, Profiles.REDS_HOUSE_2F })
end

return Profiles
