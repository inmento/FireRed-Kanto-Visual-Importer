-- FireRed Kanto Visual Importer: apply one map-aware visual profile.

local Cache = require("mods.FIRERED_KANTO_VISUALS.lib.cache")

local Profile = {}

local function fail(message)
  error("FireRed importer: " .. message, 2)
end

local function generatedPath(profile)
  return "firered/generated/semantic/" .. profile.id:lower() .. ".png"
end

function Profile.apply(mod, profile, converted)
  if not (profile and converted and converted.imageData) then
    fail("a complete semantic profile is required")
  end
  local path = generatedPath(profile)
  Cache.putAtlas(path, { imageData = converted.imageData })

  -- The registered tileset is a self-contained visual/collision projection of
  -- one unchanged Gen 1 target map. Its rows are exactly 4×4 tiles; its
  -- collision tile classes were copied from the target tileset while the pixel
  -- data came from the profile's bounded FireRed layout/tileset readers.
  mod.content.tilesets:register(profile.id, {
    id = profile.id,
    image = path,
    imageWidth = converted.imageWidth,
    imageHeight = converted.imageHeight,
    tilesPerRow = converted.tilesPerRow,
    trueColor = true,
    blocks = converted.blocks,
    walkable = converted.walkable,
    doorTiles = converted.doorTiles,
    warpTiles = converted.warpTiles,
    counterTiles = converted.counterTiles,
    grassTile = converted.grassTile,
    waterTiles = converted.waterTiles,
    shoreTiles = converted.shoreTiles,
  })

  -- Map dimensions, events, objects, collision decisions, warps, encounters,
  -- scripts and save data all remain base-game-owned. The blocks merely become
  -- one visual row per original map position, so an image cannot move an exit
  -- or make an unrelated visual door behave as a warp.
  mod.content.maps:patch(profile.map, {
    tileset = profile.id,
    blocks = converted.mapBlocks,
    borderBlock = converted.borderBlock,
    outdoor = profile.outdoor,
  })
end

return Profile
