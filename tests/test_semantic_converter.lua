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
package.loaded["src.render.PaletteFX"] = nil
package.preload["src.render.PaletteFX"] = function()
  return {
    usesGbcPack = function() return true end,
    hasWorldTileset = function(id) return id == "SYNTHETIC_TILESET" end,
    worldGroupColors = function()
      return { { { 255, 255, 255 }, { 160, 96, 48 }, { 80, 48, 24 }, { 16, 32, 48 } } }
    end,
    worldGroupAt = function() return 0 end,
  }
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

local baseAtlas = ImageData.new(128, 8)
for tile = 0, 15 do
  for y = 0, 7 do
    for x = 0, 7 do
      baseAtlas:setPixel(tile * 8 + x, y, (tile + 1) / 16, 0, 0, 1)
    end
  end
end

local function newImageData(width, height)
  if type(width) == "string" then
    check(width == "synthetic-base.png", "converter requested an unexpected base image")
    return baseAtlas
  end
  return ImageData.new(width, height)
end

love = { image = { newImageData = newImageData } }

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
  local function putU16(offset, value)
    rom = put(rom, offset, string.char(value % 0x100, math.floor(value / 0x100) % 0x100))
  end
  local function putU8(offset, value) rom = put(rom, offset, string.char(value)) end

  local layout, mapHeader, mapData, borderData = 0x1000, 0x1800, 0x1900, 0x1A00
  local primaryHeader, secondaryHeader = 0x2000, 0x2100
  local primaryTiles, primaryPalettes, primaryMetatiles, primaryAttributes = 0x3000, 0x9000, 0xA000, 0xD000
  local secondaryTiles, secondaryPalettes, secondaryMetatiles, secondaryAttributes = 0xE000, 0x12000, 0x13000, 0x15000

  putU32(layout + 0, 10)
  putU32(layout + 4, 10)
  putU32(layout + 8, pointer(borderData))
  putU32(layout + 12, pointer(mapData))
  putU8(layout + 24, 2)
  putU8(layout + 25, 2)
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

  -- FireRed metatile entries address the shared field-background tile space:
  -- primary graphics occupy 0..639 and secondary graphics begin at 640. Make
  -- primary metatile 0 reference secondary tile 0/global tile 640 at palette 7.
  putU16(primaryMetatiles + 0, 0x7000 + 640)
  -- Give source cell (0,0) a visibly distinct primary metatile. A selective
  -- layout-fit override later samples this cell to prove it repaints after the
  -- proportional whole-layout fit.
  putU16(mapData + 0, 1)
  putU16(primaryMetatiles + 16, 1)
  rom = put(rom, primaryTiles + 32, string.rep(string.char(0x11), 32))
  putU16(primaryPalettes + 2, 0x001F)
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
    borderWidth = 2, borderHeight = 2,
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
local secondBaseRow = {}
for index = 1, 16 do secondBaseRow[index] = 15 end
local targetTileset = {
  id = "SYNTHETIC_TILESET", image = "synthetic-base.png", tilesPerRow = 16, blocks = { baseRow, secondBaseRow },
  walkable = { 4, 12 }, grassTile = 12, doorTiles = { 6 }, warpTiles = { 14 }, counterTiles = {},
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
check(converted.blocks[1][5] == converted.walkable[1],
  "top-left movement cell must retain its original walkable semantic tile")
check(converted.blocks[1][7] == converted.doorTiles[1],
  "top-right movement cell must retain its original door semantic tile")
check(converted.blocks[1][13] == converted.grassTile,
  "bottom-left movement cell must retain the semantic grass tile")
check(converted.blocks[1][15] == converted.warpTiles[1],
  "bottom-right movement cell must retain its original warp semantic tile")
check(converted.semanticTileCount > 1,
  "distinct movement cells must receive independent visual-semantic tile locks")
check(converted.blocks[1][1] ~= nil,
  "a primary metatile using global secondary tile 640 must render successfully")

-- Outdoor profiles may fit an entire verified source layout into a smaller Gen 1
-- map footprint, while preserving the exact target-map movement semantics.
local layoutFitProfile = {}
for key, value in pairs(profile) do layoutFitProfile[key] = value end
layoutFitProfile.source = {}
for key, value in pairs(profile.source) do layoutFitProfile.source[key] = value end
layoutFitProfile.source.visualMode = "layout-fit"
local layoutFitConverted = Converter.build(layoutFitProfile, rom, targetMap, targetTileset)
check(layoutFitConverted.blocks[1][5] == layoutFitConverted.walkable[1]
    and layoutFitConverted.blocks[1][7] == layoutFitConverted.doorTiles[1]
    and layoutFitConverted.blocks[1][13] == layoutFitConverted.grassTile
    and layoutFitConverted.blocks[1][15] == layoutFitConverted.warpTiles[1],
  "layout-fit visuals must keep all four original movement-cell roles")

-- Explicitly preserved Gen 1 blocks must clone the base tileset pixels into the
-- generated atlas, while unlisted blocks remain sourced from FireRed. The
-- original four movement-cell semantic roles remain locked in either case.
local selectiveProfile = {}
for key, value in pairs(layoutFitProfile) do selectiveProfile[key] = value end
selectiveProfile.source = {}
for key, value in pairs(layoutFitProfile.source) do selectiveProfile.source[key] = value end
selectiveProfile.source.visualPolicy = "preserve-base-blocks"
selectiveProfile.source.preserveBaseBlocks = { [0] = true }
selectiveProfile.source.layoutFitOverrides = { ["1,0"] = { x = 0, y = 0 } }
local selectiveTargetMap = {}
for key, value in pairs(targetMap) do selectiveTargetMap[key] = value end
selectiveTargetMap.blocks = { 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
local selectiveConverted = Converter.build(selectiveProfile, rom, selectiveTargetMap, targetTileset)
local preservedRed = select(1, selectiveConverted.imageData:getPixel(0, 0))
local convertedRed = select(1, selectiveConverted.imageData:getPixel(32, 0))
check(preservedRed == 1 / 16,
  "preserved target blocks must copy their original Gen 1 base-atlas pixels")
check(convertedRed == 1,
  "a layout-fit landmark override must repaint its explicit FireRed source sample")
check(selectiveConverted.blocks[1][5] == selectiveConverted.walkable[1]
    and selectiveConverted.blocks[1][7] == selectiveConverted.doorTiles[1]
    and selectiveConverted.blocks[1][13] == selectiveConverted.grassTile
    and selectiveConverted.blocks[1][15] == selectiveConverted.warpTiles[1],
  "base-pixel preservation must not weaken the four-cell semantic lock")

-- The constrained facelift defaults every target block to its Gen 1 pixels and
-- overlays FireRed only for declared target coordinates or selected base block
-- ids. It must never reintroduce whole-layout scaling or alter movement roles.
local baseOverrideProfile = {}
for key, value in pairs(profile) do baseOverrideProfile[key] = value end
baseOverrideProfile.source = {}
for key, value in pairs(profile.source) do baseOverrideProfile.source[key] = value end
baseOverrideProfile.source.visualMode = "base-overrides"
baseOverrideProfile.source.overrides = { ["1,0"] = { x = 0, y = 0 } }
baseOverrideProfile.source.blockOverrides = {}
local baseOverrideConverted = Converter.build(baseOverrideProfile, rom, selectiveTargetMap, targetTileset)
local nativeRed = select(1, baseOverrideConverted.imageData:getPixel(0, 0))
local overrideRed = select(1, baseOverrideConverted.imageData:getPixel(32, 0))
check(nativeRed == 1 / 16,
  "base-overrides must begin undeclared map blocks with original Gen 1 pixels")
check(overrideRed == 1,
  "base-overrides must paint only the declared FireRed source rectangle")
check(baseOverrideConverted.blocks[1][5] == baseOverrideConverted.walkable[1]
    and baseOverrideConverted.blocks[1][7] == baseOverrideConverted.doorTiles[1]
    and baseOverrideConverted.blocks[1][13] == baseOverrideConverted.grassTile
    and baseOverrideConverted.blocks[1][15] == baseOverrideConverted.warpTiles[1],
  "base-overrides must retain every original movement-cell semantic role")

-- Generated profile atlases are true-colour because they also contain FireRed
-- pixels. When an active GBC palette context is supplied, copied Gen 1 base
-- pixels must be pre-baked with the same four-shade palette family instead of
-- remaining monochrome inside that true-colour atlas.
local paletteConverted = Converter.build(baseOverrideProfile, rom, selectiveTargetMap,
  targetTileset, { gameData = { maps = {} } })
local pr, pg, pb = paletteConverted.imageData:getPixel(0, 0)
check(pr == 16 / 255 and pg == 32 / 255 and pb == 48 / 255,
  "palette-aware base copying must recolour preserved Gen 1 pixels in the generated atlas")

local unknownMode = {}
for key, value in pairs(layoutFitProfile) do unknownMode[key] = value end
unknownMode.source = {}
for key, value in pairs(layoutFitProfile.source) do unknownMode.source[key] = value end
unknownMode.source.visualMode = "unknown-mode"
local modeOk, modeErr = pcall(Converter.build, unknownMode, rom, targetMap, targetTileset)
check(not modeOk and tostring(modeErr):find("unknown visual mode"),
  "unrecognized profile visual modes must fail closed")

local unknownPolicy = {}
for key, value in pairs(selectiveProfile) do unknownPolicy[key] = value end
unknownPolicy.source = {}
for key, value in pairs(selectiveProfile.source) do unknownPolicy.source[key] = value end
unknownPolicy.source.visualPolicy = "unknown-policy"
local policyOk, policyErr = pcall(Converter.build, unknownPolicy, rom, targetMap, targetTileset)
check(not policyOk and tostring(policyErr):find("unknown visual policy"),
  "unrecognized visual policies must fail closed")

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
