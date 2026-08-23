-- Private generated-asset cache for FireRed Kanto Visual Importer.
--
-- This bridge intentionally recognizes only the importer-owned generated path
-- namespace. Every other renderer request delegates to Gen1Recomp unchanged.

local Cache = {}

local PREFIX = "firered/generated/"
local atlasCache = {}
local imageCache = {}

local function owns(path)
  return type(path) == "string" and path:sub(1, #PREFIX) == PREFIX
end

-- Map profiles may carry a second atlas in the same private record. The normal
-- image keeps its prior appearance in non-ADVANCED modes; the `redpp` variant
-- contains only the copied Gen 1 pixels pre-baked through the same per-tile GBC
-- palettes that TileRenderer normally applies. FireRed source pixels remain
-- identical true-colour data in both variants.
local function modeForVariant()
  local ok, palette = pcall(require, "src.render.PaletteFX")
  if not ok or type(palette) ~= "table" then return nil end
  return palette.mode
end

local function imageDataFor(cache, path)
  local atlas = cache[path]
  assert(atlas and atlas.imageData, "FireRed importer: missing generated image " .. tostring(path))
  local mode = modeForVariant()
  return (atlas.variants and atlas.variants[mode]) or atlas.imageData, mode
end

function Cache.putAtlas(path, atlas)
  assert(owns(path), "FireRed importer: generated atlas path is outside its namespace")
  assert(type(atlas) == "table" and atlas.imageData,
    "FireRed importer: generated atlas is missing ImageData")
  if atlas.variants ~= nil then
    assert(type(atlas.variants) == "table",
      "FireRed importer: generated atlas variants must be a table")
    for mode, imageData in pairs(atlas.variants) do
      assert(type(mode) == "string" and imageData,
        "FireRed importer: generated atlas has an invalid palette variant")
    end
  end
  atlasCache[path] = atlas
  imageCache[path] = nil
end

function Cache.has(path)
  return owns(path) and atlasCache[path] ~= nil
end

function Cache.installAssetBridge()
  local Assets = require("src.render.Assets")
  local bridge = Assets._fireredKantoVisualsBridge
  if bridge then
    -- Mods can be replaced while the renderer module remains resident. Refresh
    -- the bridge's backing tables so newly generated profile atlases cannot be
    -- looked up in an earlier install's private cache.
    bridge.atlasCache = atlasCache
    bridge.imageCache = imageCache
    return
  end
  bridge = { atlasCache = atlasCache, imageCache = imageCache }
  Assets._fireredKantoVisualsBridge = bridge

  local oldImage = Assets.image
  local oldImageData = Assets.imageData
  local oldExists = Assets.exists
  local oldResolve = Assets.resolve

  Assets.imageData = function(path)
    if owns(path) then return imageDataFor(bridge.atlasCache, path) end
    return oldImageData(path)
  end

  -- Some Gen1Recomp UI states resolve a sprite path and call
  -- love.graphics.newImage directly instead of Assets.image. LÖVE accepts
  -- ImageData as a constructor input, so return our in-memory ImageData only
  -- for the importer-owned namespace. This makes title/Oak/menu consumers see
  -- the exact same private generated asset as the battle renderer without
  -- writing FireRed-derived files or changing any engine/UI code.
  Assets.resolve = function(path)
    if owns(path) then return imageDataFor(bridge.atlasCache, path) end
    return oldResolve(path)
  end

  Assets.image = function(path)
    if owns(path) then
      local imageData, mode = imageDataFor(bridge.atlasCache, path)
      local cached = bridge.imageCache[path]
      -- PaletteFX.setMode invalidates and reloads the current map. Rebuild only
      -- when that reload asks this path for a different private variant; battle
      -- and UI assets have no variants and retain the original one-image path.
      if not cached or cached.imageData ~= imageData or cached.mode ~= mode then
        local image = love.graphics.newImage(imageData)
        image:setFilter("nearest", "nearest")
        cached = { image = image, imageData = imageData, mode = mode }
        bridge.imageCache[path] = cached
      end
      return cached.image
    end
    return oldImage(path)
  end

  Assets.exists = function(path)
    if owns(path) then return bridge.atlasCache[path] ~= nil end
    return oldExists(path)
  end
end

return Cache
