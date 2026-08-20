local VisualProfile = {}

local GENERATED_GENERAL = "firered/generated/tilesets/general.png"
-- TileRenderer selects the vanilla GBC per-tile palette bake by tileset record
-- id. A FireRed true-colour atlas has no such vanilla tile-id contract, so it
-- needs its own visual identity while maps retain their native OVERWORLD key.
local GENERATED_GENERAL_ID = "FIRERED_KANTO_GENERAL"

local function fail(message)
  error("FireRed importer: " .. message, 2)
end

local function copyBlock(block)
  local out = {}
  for index = 1, 16 do out[index] = block[index] end
  return out
end

local function initialOutdoorBlocks(baseBlocks, importedBlocks)
  local out = {}
  for index = 1, #baseBlocks do
    -- FireRed's General primary tileset has 640 metatiles. The base Gen 1
    -- Overworld tileset uses fewer block slots, so this first profile maps its
    -- stable numeric block range onto the corresponding FireRed General range.
    -- It changes only visual composition; all original collision/warp/grass/
    -- ledge rules remain on the unmodified target tileset record.
    local imported = importedBlocks[index - 1]
    if not imported then
      out[index] = copyBlock(baseBlocks[index])
    else
      out[index] = copyBlock(imported)
    end
  end
  return out
end

function VisualProfile.applyGen1Outdoor(mod, imported)
  assert(imported and imported.atlas, "FireRed importer: missing decoded General atlas")
  local atlas = imported.atlas

  -- `patch` deep-merges only these visual tileset fields during the mod merge
  -- phase. It does not alter any map record, so existing Kanto block grids,
  -- objects, warps, scripts, collision, ledge behavior, encounters, and save
  -- progression remain base-game owned.
  local base = mod.content.tilesets:get("OVERWORLD")
  if not base or type(base.blocks) ~= "table" then
    fail("the Gen 1 Overworld tileset is unavailable")
  end

  mod.content.tilesets:patch("OVERWORLD", {
    id = GENERATED_GENERAL_ID,
    image = GENERATED_GENERAL,
    imageWidth = atlas.imageWidth,
    imageHeight = atlas.imageHeight,
    tilesPerRow = atlas.tilesPerRow,
    trueColor = true,
    blocks = initialOutdoorBlocks(base.blocks, atlas.blocks),
  })
end

return VisualProfile
