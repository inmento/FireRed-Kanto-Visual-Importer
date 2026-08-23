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
  resolve = function(path) return "base-resolve:" .. path end,
}
package.preload["src.render.Assets"] = function() return assets end
local PaletteFX = { mode = "gbc" }
package.preload["src.render.PaletteFX"] = function() return PaletteFX end

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
  check(assets.resolve("firered/generated/semantic/probe.png") == probe,
    "cache bridge did not expose generated ImageData to resolver-based UI")
  check(love.graphics.newImage(assets.resolve("firered/generated/semantic/probe.png")).source == probe,
    "resolver-based UI could not construct an image from generated ImageData")
  check(assets.resolve("external.png") == "base-resolve:external.png",
    "cache bridge intercepted a non-owned resolver path")
  check(assets.image("external.png") == "base-image:external.png",
    "cache bridge intercepted non-owned image path")

  -- PaletteFX applies a saved COLORS value after mod content has initialized.
  -- A map reload must therefore select the private redpp atlas variant without
  -- changing sprite/title/Oak paths or writing any file.
  local advancedProbe = ImageData.new(1, 1)
  Cache.putAtlas("firered/generated/semantic/mode-probe.png", {
    imageData = probe,
    variants = { redpp = advancedProbe },
  })
  check(assets.imageData("firered/generated/semantic/mode-probe.png") == probe,
    "default palette mode selected an unexpected generated atlas variant")
  check(assets.image("firered/generated/semantic/mode-probe.png").source == probe,
    "default palette mode built the wrong generated image")
  PaletteFX.mode = "redpp"
  check(assets.imageData("firered/generated/semantic/mode-probe.png") == advancedProbe,
    "ADVANCED palette mode did not select the generated redpp atlas variant")
  check(assets.resolve("firered/generated/semantic/mode-probe.png") == advancedProbe,
    "resolver bridge did not select the generated redpp atlas variant")
  check(assets.image("firered/generated/semantic/mode-probe.png").source == advancedProbe,
    "ADVANCED palette mode did not rebuild the generated map image")
  PaletteFX.mode = "gbc"

  -- A renderer module can outlive an in-process mod replacement. A fresh
  -- cache module must update the installed bridge so new profile paths read
  -- only the new generated atlas cache, not prior-version content.
  local FreshCache = load("lib/cache.lua")
  local freshProbe = ImageData.new(1, 1)
  FreshCache.putAtlas("firered/generated/v024/semantic/probe.png", { imageData = freshProbe })
  FreshCache.installAssetBridge()
  check(assets.imageData("firered/generated/v024/semantic/probe.png") == freshProbe,
    "cache bridge did not refresh after importer reload")
  check(assets.resolve("firered/generated/v024/semantic/probe.png") == freshProbe,
    "resolver bridge did not refresh after importer reload")
end

print("FireRed Kanto Visual Importer foundation tests passed")
