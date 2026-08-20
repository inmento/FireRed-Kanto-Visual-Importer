local ROOT = "/home/ubuntu/FireRed-Kanto-Visual-Importer"

local function load(relative)
  return assert(loadfile(ROOT .. "/" .. relative))()
end

package.preload["mods.FIRERED_KANTO_VISUALS.lib.addresses"] = function()
  return load("lib/addresses.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.gba_reader"] = function()
  return load("lib/gba_reader.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.lz77"] = function()
  return load("lib/lz77.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.general_tileset"] = function()
  return load("lib/general_tileset.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.cache"] = function()
  return load("lib/cache.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.visual_profile"] = function()
  return load("lib/visual_profile.lua")
end

local ImageData = {}
ImageData.__index = ImageData
function ImageData.new(width, height)
  return setmetatable({ width = width, height = height, pixels = {} }, ImageData)
end
function ImageData:setPixel(x, y, r, g, b, a)
  assert(x >= 0 and x < self.width and y >= 0 and y < self.height,
    ("out-of-range image write at %s,%s for %sx%s atlas"):format(x, y, self.width, self.height))
  self.pixels[y * self.width + x] = { r, g, b, a }
end
function ImageData:getPixel(x, y)
  local p = self.pixels[y * self.width + x] or { 0, 0, 0, 0 }
  return p[1], p[2], p[3], p[4]
end
function ImageData:mapPixel(fn)
  for y = 0, self.height - 1 do
    for x = 0, self.width - 1 do
      local r, g, b, a = fn(x, y, self:getPixel(x, y))
      self:setPixel(x, y, r, g, b, a)
    end
  end
end

love = {
  image = { newImageData = ImageData.new },
  graphics = {
    newImage = function(imageData)
      return {
        source = imageData,
        setFilter = function() end,
      }
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
local General = require("mods.FIRERED_KANTO_VISUALS.lib.general_tileset")
local Cache = require("mods.FIRERED_KANTO_VISUALS.lib.cache")
local VisualProfile = require("mods.FIRERED_KANTO_VISUALS.lib.visual_profile")

local function check(condition, message)
  if not condition then error(message or "check failed", 2) end
end

local function expectError(fn, label)
  local ok = pcall(fn)
  check(not ok, label or "expected failure")
end

local function lz77Zeros(size)
  local bytes = { string.char(0x10, size % 0x100, math.floor(size / 0x100) % 0x100,
    math.floor(size / 0x10000) % 0x100) }
  local produced = 0
  while produced < size do
    local actions = {}
    local flag = 0
    for bit = 7, 0, -1 do
      if produced >= size then break end
      local remaining = size - produced
      if produced > 0 and remaining >= 3 then
        local count = math.min(18, remaining)
        flag = flag + 2 ^ bit
        actions[#actions + 1] = string.char((count - 3) * 16, 0) -- distance = 1
        produced = produced + count
      else
        actions[#actions + 1] = string.char(0)
        produced = produced + 1
      end
    end
    bytes[#bytes + 1] = string.char(flag)
    for _, action in ipairs(actions) do bytes[#bytes + 1] = action end
  end
  return table.concat(bytes)
end

local function replace(blob, offset, value)
  return blob:sub(1, offset) .. value .. blob:sub(offset + #value + 1)
end

-- Reader and LZ77 boundary tests.
do
  local reader = Reader.new(string.char(0x10, 6, 0, 0, 0x10, 65, 66, 67, 0, 2))
  local out = Lz77.decode(reader, 0, "synthetic")
  check(out == "ABCABC", "LZ77 literal/copy decode failed")
  expectError(function() Reader.new("abc"):u16(2, "past end") end,
    "reader must reject out-of-range reads")
  expectError(function()
    Lz77.decode(Reader.new(string.char(0, 1, 0, 0)), 0, "bad header")
  end, "LZ77 must reject wrong header")
end

local function syntheticRom(revision)
  local rom = string.rep("\0", Addresses.ROM_SIZE)
  rom = replace(rom, 0xBC, string.char(revision))
  local spec = Addresses.revisions["e26ee0d44e809351c8ce2d73c7400cdd"]
  local function put(address, value)
    rom = replace(rom, address - Addresses.ROM_BASE, value)
  end
  put(spec.general.tiles, lz77Zeros(640 * 32))
  put(spec.general.palettes, string.rep("\0", 7 * 16 * 2))
  put(spec.general.metatiles, string.rep("\0", 640 * 8 * 2))
  put(spec.general.attributes, string.rep("\0", 640 * 4))
  return rom
end

-- The confirmed v1.0 layout must decode the expected General profile. Other
-- revisions are blocked by the manifest MD5 allowlist and decoder header gate.
for _, revision in ipairs({ 0 }) do
  local decoded = General.decode(syntheticRom(revision))
  check(decoded.revision.id == "firered_en_v10", "wrong revision selected")
  check(decoded.atlas.imageWidth == 512 and decoded.atlas.imageHeight == 1280,
    "unexpected generated atlas dimensions")
  check(#decoded.atlas.blocks[0] == 16, "metatile must produce a 4x4 target block")
  check(decoded.atlas.blocks[0][1] == 0 and decoded.atlas.blocks[0][4] == 3
    and decoded.atlas.blocks[0][5] == 64 and decoded.atlas.blocks[0][16] == 195,
    "first target block has wrong 4x4 tile layout")
  check(decoded.atlas.blocks[639][16] == 10239,
    "last FireRed metatile must remain inside the generated atlas")
end

-- The cache bridge must intercept only importer-owned generated paths.
do
  local probe = ImageData.new(1, 1)
  Cache.putAtlas("firered/generated/tilesets/probe.png", { imageData = probe })
  Cache.installAssetBridge()
  check(assets.exists("firered/generated/tilesets/probe.png"),
    "cache bridge did not expose generated path")
  check(assets.imageData("firered/generated/tilesets/probe.png") == probe,
    "cache bridge returned wrong generated ImageData")
  check(assets.image("external.png") == "base-image:external.png",
    "cache bridge intercepted non-owned image path")
end

-- The profile must patch only visual tileset fields and retain the base record
-- that owns gameplay data such as collision, grass and warp behavior.
do
  local base = {
    image = "base.png",
    blocks = { { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 } },
    walkable = { 0 },
    warpTiles = { 0 },
    grassTile = 0,
  }
  local applied
  local mod = {
    content = {
      tilesets = {
        get = function(_, id) check(id == "OVERWORLD", "wrong tileset lookup"); return base end,
        patch = function(_, id, partial) check(id == "OVERWORLD", "wrong tileset patch"); applied = partial end,
      },
    },
  }
  VisualProfile.applyGen1Outdoor(mod, {
    atlas = {
      imageWidth = 512,
      imageHeight = 1280,
      tilesPerRow = 64,
      blocks = { [0] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 } },
    },
  })
  check(applied and applied.image == "firered/generated/tilesets/general.png",
    "visual profile did not set generated image")
  check(applied.id == "FIRERED_KANTO_GENERAL",
    "visual profile did not isolate the imported atlas from vanilla GBC palette baking")
  check(applied.blocks[1][1] == 0 and applied.blocks[1][16] == 15,
    "visual profile did not map the visual block")
  check(base.walkable[1] == 0 and base.warpTiles[1] == 0 and base.grassTile == 0,
    "visual profile mutated base gameplay fields")
end

print("FireRed Kanto Visual Importer isolated tests passed")
