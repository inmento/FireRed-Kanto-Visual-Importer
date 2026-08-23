local ROOT = "/home/ubuntu/firered-kanto-visual-importer"

local function load(relative)
  return assert(loadfile(ROOT .. "/" .. relative))()
end

package.loaded["mods.FIRERED_KANTO_VISUALS.lib.addresses"] = nil
package.loaded["mods.FIRERED_KANTO_VISUALS.lib.gba_reader"] = nil
package.loaded["mods.FIRERED_KANTO_VISUALS.lib.lz77"] = nil
package.loaded["mods.FIRERED_KANTO_VISUALS.lib.cache"] = nil
package.preload["mods.FIRERED_KANTO_VISUALS.lib.addresses"] = function()
  return load("lib/addresses.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.gba_reader"] = function()
  return load("lib/gba_reader.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.lz77"] = function()
  return load("lib/lz77.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.cache"] = function()
  return load("lib/cache.lua")
end

local function check(condition, message)
  if not condition then error(message or "check failed", 2) end
end

local function expectError(fn, label)
  local ok = pcall(fn)
  check(not ok, label or "expected failure")
end

local ImageData = {}
ImageData.__index = ImageData
function ImageData.new(width, height)
  return setmetatable({ width = width, height = height, pixels = {} }, ImageData)
end
function ImageData:setPixel(x, y, r, g, b, a)
  check(x >= 0 and x < self.width and y >= 0 and y < self.height,
    "cache test made an out-of-range image write")
  self.pixels[y * self.width + x] = { r, g, b, a }
end
function ImageData:getPixel(x, y)
  local p = self.pixels[y * self.width + x] or { 0, 0, 0, 0 }
  return p[1], p[2], p[3], p[4]
end

love = {
  image = { newImageData = ImageData.new },
  graphics = {
    newImage = function(imageData)
      return { source = imageData, setFilter = function() end }
    end,
  },
}

local assets = {
  image = function(path) return "base-image:" .. path end,
  imageData = function(path) return "base-data:" .. path end,
  exists = function() return false end,
}
package.preload["src.render.Assets"] = function() return assets end

local Reader = require("mods.FIRERED_KANTO_VISUALS.lib.gba_reader")
local Lz77 = require("mods.FIRERED_KANTO_VISUALS.lib.lz77")
local Addresses = require("mods.FIRERED_KANTO_VISUALS.lib.addresses")
local Cache = require("mods.FIRERED_KANTO_VISUALS.lib.cache")

-- The bounded reader and LZ77 decoder remain shared foundations for all
-- semantic profiles. Invalid source data must fail before atlas generation.
do
  local reader = Reader.new(string.char(0x10, 6, 0, 0, 0x10, 65, 66, 67, 0, 2))
  check(Lz77.decode(reader, 0, "synthetic") == "ABCABC", "LZ77 literal/copy decode failed")
  expectError(function() Reader.new("abc"):u16(2, "past end") end,
    "reader must reject out-of-range reads")
  expectError(function()
    Lz77.decode(Reader.new(string.char(0, 1, 0, 0)), 0, "bad header")
  end, "LZ77 must reject wrong header")
  check(Addresses.forMd5("e26ee0d44e809351c8ce2d73c7400cdd") ~= nil,
    "supported FireRed v1.0 layout is missing")
end

-- The private asset cache intercepts only importer-owned generated paths.
do
  local probe = ImageData.new(1, 1)
  Cache.putAtlas("firered/generated/semantic/probe.png", { imageData = probe })
  Cache.installAssetBridge()
  check(assets.exists("firered/generated/semantic/probe.png"),
    "cache bridge did not expose generated path")
  check(assets.imageData("firered/generated/semantic/probe.png") == probe,
    "cache bridge returned wrong generated ImageData")
  check(assets.image("external.png") == "base-image:external.png",
    "cache bridge intercepted non-owned image path")
end

print("FireRed Kanto Visual Importer foundation tests passed")
