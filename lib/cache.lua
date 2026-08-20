-- Private generated-asset cache for FireRed Kanto Visual Importer.
--
-- This bridge intentionally recognizes only the importer-owned generated path
-- namespace. Every other renderer request delegates to Gen1Recomp unchanged.

local Cache = {}

local PREFIX = "firered/generated/"
local imageDataCache = {}
local imageCache = {}

local function owns(path)
  return type(path) == "string" and path:sub(1, #PREFIX) == PREFIX
end

function Cache.putAtlas(path, atlas)
  assert(owns(path), "FireRed importer: generated atlas path is outside its namespace")
  assert(type(atlas) == "table" and atlas.imageData,
    "FireRed importer: generated atlas is missing ImageData")
  imageDataCache[path] = atlas.imageData
  imageCache[path] = nil
end

function Cache.has(path)
  return owns(path) and imageDataCache[path] ~= nil
end

function Cache.installAssetBridge()
  local Assets = require("src.render.Assets")
  if Assets._fireredKantoVisualsBridge then return end
  Assets._fireredKantoVisualsBridge = true

  local oldImage = Assets.image
  local oldImageData = Assets.imageData
  local oldExists = Assets.exists

  Assets.imageData = function(path)
    if owns(path) then
      local imageData = imageDataCache[path]
      assert(imageData, "FireRed importer: missing generated image " .. path)
      return imageData
    end
    return oldImageData(path)
  end

  Assets.image = function(path)
    if owns(path) then
      local image = imageCache[path]
      if not image then
        local imageData = imageDataCache[path]
        assert(imageData, "FireRed importer: missing generated image " .. path)
        image = love.graphics.newImage(imageData)
        image:setFilter("nearest", "nearest")
        imageCache[path] = image
      end
      return image
    end
    return oldImage(path)
  end

  Assets.exists = function(path)
    if owns(path) then return imageDataCache[path] ~= nil end
    return oldExists(path)
  end
end

return Cache
