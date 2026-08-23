local ROOT = "/home/ubuntu/firered-kanto-visual-importer"

local function load(relative)
  return assert(loadfile(ROOT .. "/" .. relative))()
end

local function check(condition, message)
  if not condition then error(message or "check failed", 2) end
end

package.loaded["mods.FIRERED_KANTO_VISUALS.lib.addresses"] = nil
package.loaded["mods.FIRERED_KANTO_VISUALS.lib.gba_reader"] = nil
package.loaded["mods.FIRERED_KANTO_VISUALS.lib.lz77"] = nil
package.loaded["mods.FIRERED_KANTO_VISUALS.lib.semantic_converter"] = nil
package.preload["mods.FIRERED_KANTO_VISUALS.lib.addresses"] = function()
  return load("lib/addresses.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.gba_reader"] = function()
  return load("lib/gba_reader.lua")
end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.lz77"] = function()
  return load("lib/lz77.lua")
end

local ImageData = {}
ImageData.__index = ImageData
function ImageData.new(width, height)
  return setmetatable({ width = width, height = height, pixels = {} }, ImageData)
end
function ImageData:setPixel(x, y, r, g, b, a)
  check(x >= 0 and x < self.width and y >= 0 and y < self.height,
    "semantic converter wrote outside its tile-locked atlas")
  self.pixels[y * self.width + x] = { r, g, b, a }
end
function ImageData:getPixel(x, y)
  local pixel = self.pixels[y * self.width + x] or { 0, 0, 0, 0 }
  return pixel[1], pixel[2], pixel[3], pixel[4]
end
function ImageData:getWidth() return self.width end
function ImageData:getHeight() return self.height end
function ImageData:mapPixel(fn)
  for y = 0, self.height - 1 do
    for x = 0, self.width - 1 do
      self:setPixel(x, y, fn(x, y, self:getPixel(x, y)))
    end
  end
end

love = { image = { newImageData = ImageData.new } }

local Addresses = require("mods.FIRERED_KANTO_VISUALS.lib.addresses")
Addresses.ROM_SIZE = 0x40000 -- compact synthetic fixture, not a real ROM.
local Converter = load("lib/semantic_converter.lua")

local function put(blob, offset, bytes)
  return blob:sub(1, offset) .. bytes .. blob:sub(offset + #bytes + 1)
end

local function u32(value)
  return string.char(value % 0x100, math.floor(value / 0x100) % 0x100,
    math.floor(value / 0x10000) % 0x100, math.floor(value / 0x1000000) % 0x100)
end

local function fixtureRom()
  local base = Addresses.ROM_BASE
  local rom = string.rep("\0", Addresses.ROM_SIZE)
  local function pointer(offset) return base + offset end
  local function putU32(offset, value) rom = put(rom, offset, u32(value)) end
  local function putU8(offset, value) rom = put(rom, offset, string.char(value)) end

  local layout, mapHeader, mapData = 0x1000, 0x1800, 0x1900
  local primaryHeader, secondaryHeader = 0x2000, 0x2100
  local primaryTiles, primaryPalettes, primaryMetatiles, primaryAttributes = 0x3000, 0x9000, 0xA000, 0xD000
  local secondaryTiles, secondaryPalettes, secondaryMetatiles, secondaryAttributes = 0xE000, 0x12000, 0x13000, 0x15000

  putU32(layout + 0, 10)
  putU32(layout + 4, 10)
  putU32(layout + 12, pointer(mapData))
  putU32(layout + 16, pointer(primaryHeader))
  putU32(layout + 20, pointer(secondaryHeader))
  putU32(mapHeader, pointer(layout))

  -- Tileset struct: compression/secondary flags followed by four pointers.
  putU8(primaryHeader + 0, 0)
  putU8(primaryHeader + 1, 0)
  putU32(primaryHeader + 4, pointer(primaryTiles))
  putU32(primaryHeader + 8, pointer(primaryPalettes))
  putU32(primaryHeader + 12, pointer(primaryMetatiles))
  putU32(primaryHeader + 20, pointer(primaryAttributes))

  putU8(secondaryHeader + 0, 0)
  putU8(secondaryHeader + 1, 1)
  putU32(secondaryHeader + 4, pointer(secondaryTiles))
  putU32(secondaryHeader + 8, pointer(secondaryPalettes))
  putU32(secondaryHeader + 12, pointer(secondaryMetatiles))
  putU32(secondaryHeader + 20, pointer(secondaryAttributes))
  return rom, pointer(layout), pointer(mapHeader), pointer(primaryHeader), pointer(secondaryHeader),
    primaryTiles, secondaryTiles
end

local rom, layout, mapHeader, primaryHeader, secondaryHeader, primaryTiles, secondaryTiles = fixtureRom()
local profile = {
  id = "SYNTHETIC_PROFILE",
  map = "SYNTHETIC_MAP",
  expectedTarget = { width = 4, height = 4, tileset = "SYNTHETIC_TILESET" },
  source = {
    layout = layout, header = mapHeader, width = 10, height = 10,
    primaryTileset = primaryHeader, secondaryTileset = secondaryHeader,
    originX = 1, originY = 1,
  },
  outdoor = true,
}
local targetMap = {
  id = "SYNTHETIC_MAP", width = 4, height = 4, tileset = "SYNTHETIC_TILESET",
  blocks = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  borderBlock = 0,
}
local baseRow = {}
for index = 1, 16 do baseRow[index] = index - 1 end
local targetTileset = {
  id = "SYNTHETIC_TILESET", blocks = { baseRow },
  walkable = { 12 }, grassTile = 12, doorTiles = {}, warpTiles = {}, counterTiles = {},
}

local converted = Converter.build(profile, rom, targetMap, targetTileset)
check(converted.imageWidth == 512 and converted.imageHeight % 8 == 0,
  "semantic atlas must retain a 64-column integral 8px grid")
check(#converted.blocks == 17 and #converted.mapBlocks == 16,
  "converter must create one target visual block per map block plus a border")
check(converted.mapBlocks[1] == 0 and converted.mapBlocks[16] == 15 and converted.borderBlock == 16,
  "converter must remap map positions rather than numerically pairing source block IDs")
check(#converted.blocks[1] == 16,
  "each generated map block must retain exactly sixteen target 8px cells")
check(converted.blocks[1][13] == converted.grassTile,
  "collision tile must be remapped to the semantic grass tile")
check(converted.walkable[1] == converted.grassTile,
  "walkability must follow the original collision tile class")
check(converted.semanticTileCount == 1,
  "identical original collision classes must share one semantic tile")

-- FireRed secondary sheets are not universally 384 tiles. Exercise the
-- compressed path with one 8x8 tile (32 decoded bytes) in both tilesets; this
-- must use the LZ77 header's actual length instead of a fixed primary/secondary
-- maximum.
local function compressedOneTile(value)
  -- Header declares 32 bytes. Four flag-zero groups then supply eight literal
  -- bytes each, yielding exactly one 8x8 4bpp tile.
  local group = string.char(0) .. string.rep(string.char(value), 8)
  return string.char(0x10, 32, 0, 0) .. string.rep(group, 4)
end
local compressedRom = put(put(rom, primaryTiles, compressedOneTile(0x11)),
  secondaryTiles, compressedOneTile(0x22))
-- Mark both fixture headers as compressed after their raw test has completed.
compressedRom = put(compressedRom, primaryHeader - Addresses.ROM_BASE, string.char(1))
compressedRom = put(compressedRom, secondaryHeader - Addresses.ROM_BASE, string.char(1))
local compressedConverted = Converter.build(profile, compressedRom, targetMap, targetTileset)
check(compressedConverted.tileCount == nil and #compressedConverted.blocks == 17,
  "small compressed profile sheets must build without a fixed tile-count rejection")

local bad = {}
for key, value in pairs(profile) do bad[key] = value end
bad.source = {}
for key, value in pairs(profile.source) do bad.source[key] = value end
bad.source.originX = 3
local ok, err = pcall(Converter.build, bad, rom, targetMap, targetTileset)
check(not ok and tostring(err):find("profile crop exceeds"),
  "out-of-bounds source crops must fail closed before any profile is applied")

print("FireRed Kanto Visual Importer semantic-converter tests passed")
