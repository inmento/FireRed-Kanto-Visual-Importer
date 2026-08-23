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
    -- The player-selected ADVANCED palette is applied after mod content starts.
    -- Keep one private redpp variant so copied Gen 1 terrain is pre-baked with
    -- its normal per-tile colours when the engine reloads this true-colour map.
    -- FireRed pixels and every semantic map role remain identical in both.
    paletteVariants = { "redpp" },
    -- A repeated Gen 1 block ID is not a reliable terrain category. Declare
    -- only the actual Pallet target-ground coordinates that receive the compact
    -- FireRed grass/ground sample; every other undeclared location stays Gen 1.
    overrides = {
      -- Explicit target-ground mask (FireRed compact grass/ground at 2,2).
      ["1,1"] = { x = 2, y = 2 }, ["4,1"] = { x = 2, y = 2 },
      ["5,1"] = { x = 2, y = 2 }, ["8,1"] = { x = 2, y = 2 },
      ["4,2"] = { x = 2, y = 2 }, ["8,2"] = { x = 2, y = 2 },
      ["1,3"] = { x = 2, y = 2 }, ["2,3"] = { x = 2, y = 2 },
      ["3,3"] = { x = 2, y = 2 }, ["4,3"] = { x = 2, y = 2 },
      ["5,3"] = { x = 2, y = 2 }, ["6,3"] = { x = 2, y = 2 },
      ["7,3"] = { x = 2, y = 2 }, ["8,3"] = { x = 2, y = 2 },
      ["1,4"] = { x = 2, y = 2 }, ["4,4"] = { x = 2, y = 2 }, ["8,4"] = { x = 2, y = 2 },
      ["1,5"] = { x = 2, y = 2 }, ["4,5"] = { x = 2, y = 2 }, ["8,5"] = { x = 2, y = 2 },
      ["1,6"] = { x = 2, y = 2 }, ["2,6"] = { x = 2, y = 2 },
      ["3,6"] = { x = 2, y = 2 }, ["4,6"] = { x = 2, y = 2 },

      -- Red's House uses its actual 2×2 Gen 1 footprint. The lower-left block
      -- contains the fixed Gen 1 entry and samples FireRed's visual door cell.
      ["2,1"] = { x = 5, y = 4 }, ["3,1"] = { x = 7, y = 4 },
      ["2,2"] = { x = 5, y = 6 }, ["3,2"] = { x = 7, y = 6 },
      -- Blue's House: same 2×2 target footprint, aligned to its own FireRed door.
      ["6,1"] = { x = 14, y = 4 }, ["7,1"] = { x = 16, y = 4 },
      ["6,2"] = { x = 14, y = 6 }, ["7,2"] = { x = 16, y = 6 },
      -- Oak's Lab uses its actual 2×2 structural target footprint; x=8 remains
      -- target ground rather than an invented third building column.
      ["6,4"] = { x = 15, y = 10 }, ["7,4"] = { x = 17, y = 10 },
      ["6,5"] = { x = 15, y = 12 }, ["7,5"] = { x = 17, y = 12 },
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
