-- FireRed v1.0 visual sprite importer.
--
-- This module reads only the launcher-validated source ROM, decodes normal
-- palette artwork into private in-memory ImageData, and returns paths for
-- public content-record patches. It never changes species, trainer, battle,
-- map, or save data.

local Addresses = require("mods.firered_kanto_visuals.lib.addresses")
local Reader = require("mods.firered_kanto_visuals.lib.gba_reader")
local Lz77 = require("mods.firered_kanto_visuals.lib.lz77")
local Targets = require("mods.firered_kanto_visuals.lib.visual_targets")

local VisualSprites = {}

local ROM_BASE = Addresses.ROM_BASE
local MON_COUNT = 440
local TRAINER_COUNT = 148
local SHEET_RECORD_SIZE = 8
local PALETTE_RECORD_SIZE = 8
local MON_SHEET_SIZE = 0x800
local MON_WIDTH, MON_HEIGHT = 64, 64

local function fail(message)
  error("FireRed importer: " .. message, 2)
end

local function color15(value)
  local r = value % 32
  local g = math.floor(value / 32) % 32
  local b = math.floor(value / 1024) % 32
  return r / 31, g / 31, b / 31
end

local function gbaOffset(reader, address, label)
  if address < ROM_BASE or address >= ROM_BASE + reader.size then
    fail((label or "source pointer") .. " is outside the verified FireRed ROM")
  end
  return reader:offsetFromAddress(address, label)
end

local function tablePointer(reader, tableAddress, record, label)
  if record < 0 then fail(label .. " has an invalid record index") end
  local offset = reader:offsetFromAddress(tableAddress, label .. " table")
  return reader:u32(offset + record * SHEET_RECORD_SIZE, label .. " pointer")
end

local function tableSize(reader, tableAddress, record, label)
  local offset = reader:offsetFromAddress(tableAddress, label .. " table")
  return reader:u16(offset + record * SHEET_RECORD_SIZE + 4, label .. " size")
end

local function decodeCompressed(reader, address, expectedSize, label)
  local bytes = Lz77.decode(reader, gbaOffset(reader, address, label), label)
  if #bytes ~= expectedSize then
    fail(label .. " decompressed to " .. #bytes .. " bytes instead of " .. expectedSize)
  end
  return bytes
end

local function decodePalette(reader, tableAddress, record, label)
  local pointer = tablePointer(reader, tableAddress, record, label)
  local bytes = decodeCompressed(reader, pointer, 32, label .. " palette")
  local palette = {}
  for index = 0, 15 do
    local lo, hi = bytes:byte(index * 2 + 1, index * 2 + 2)
    palette[index] = { color15(lo + hi * 0x100) }
  end
  return palette
end

local function pixel4bpp(bytes, x, y, width)
  local tilesPerRow = width / 8
  local tile = math.floor(x / 8) + math.floor(y / 8) * tilesPerRow
  local byteIndex = tile * 32 + (y % 8) * 4 + math.floor((x % 8) / 2) + 1
  local value = bytes:byte(byteIndex) or 0
  if x % 2 == 0 then return value % 16 end
  return math.floor(value / 16) % 16
end

local function imageDataFrom4bpp(bytes, width, height, palette, label)
  local expected = width * height / 2
  if #bytes ~= expected then
    fail(label .. " has an unsupported 4bpp image size")
  end
  local imageData = love.image.newImageData(width, height)
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      local index = pixel4bpp(bytes, x, y, width)
      if index == 0 then
        imageData:setPixel(x, y, 0, 0, 0, 0)
      else
        local color = palette[index]
        imageData:setPixel(x, y, color[1], color[2], color[3], 1)
      end
    end
  end
  return imageData
end

local function path(kind, id)
  return "firered/generated/battle/" .. kind .. "/" .. id:lower() .. ".png"
end

local function readMonImage(reader, tableAddress, paletteAddress, dex, side)
  local picture = tablePointer(reader, tableAddress, dex, "Pokémon " .. side .. " picture")
  local size = tableSize(reader, tableAddress, dex, "Pokémon " .. side .. " picture")
  if size ~= MON_SHEET_SIZE then
    fail("Pokémon " .. side .. " picture " .. dex .. " has unsupported size " .. size)
  end
  local palette = decodePalette(reader, paletteAddress, dex, "Pokémon " .. dex)
  local bytes = decodeCompressed(reader, picture, size, "Pokémon " .. side .. " picture " .. dex)
  return imageDataFrom4bpp(bytes, MON_WIDTH, MON_HEIGHT, palette,
    "Pokémon " .. side .. " picture " .. dex)
end

local function trainerDimensions(size, label)
  -- All selected FireRed Kanto battle portraits are standard 64×64 4bpp
  -- sheets. Rejecting a nonstandard size prevents a bad source pointer from
  -- becoming a huge allocation or an incorrectly shaped target image.
  if size ~= MON_SHEET_SIZE then
    fail(label .. " has unsupported trainer picture size " .. size)
  end
  return MON_WIDTH, MON_HEIGHT
end

local function readTrainerImage(reader, sheetAddress, paletteAddress, picture)
  if picture < 0 or picture >= TRAINER_COUNT then
    fail("mapped trainer picture index is outside FireRed's table")
  end
  local label = "trainer picture " .. picture
  local pointer = tablePointer(reader, sheetAddress, picture, label)
  local size = tableSize(reader, sheetAddress, picture, label)
  local width, height = trainerDimensions(size, label)
  local palette = decodePalette(reader, paletteAddress, picture, label)
  local bytes = decodeCompressed(reader, pointer, size, label)
  return imageDataFrom4bpp(bytes, width, height, palette, label)
end

function VisualSprites.decode(rom)
  if type(rom) ~= "string" or #rom ~= Addresses.ROM_SIZE then
    fail("the imported FireRed file does not have the expected 16 MiB size")
  end
  if not (love and love.image and love.image.newImageData) then
    fail("the image runtime is unavailable; restart Gen1Recomp and retry the import")
  end
  if rom:byte(0xBD) ~= 0 then
    fail("this build supports FireRed English v1.0 only")
  end

  local revision = assert(Addresses.forMd5("e26ee0d44e809351c8ce2d73c7400cdd"),
    "FireRed importer: v1.0 layout is missing")
  local spec = assert(revision.visuals, "FireRed importer: visual source layout is missing")
  local reader = Reader.new(rom, ROM_BASE)
  local assets = {}
  local pokemon = {}
  local trainers = {}

  for _, target in ipairs(Targets.species) do
    if target.dex < 1 or target.dex >= MON_COUNT then
      fail("species target has an invalid FireRed Pokédex index")
    end
    local frontPath = path("front", target.id)
    local backPath = path("back", target.id)
    assets[frontPath] = readMonImage(reader, spec.monFrontTable,
      spec.monPaletteTable, target.dex, "front")
    assets[backPath] = readMonImage(reader, spec.monBackTable,
      spec.monPaletteTable, target.dex, "back")
    pokemon[#pokemon + 1] = {
      id = target.id,
      front = frontPath,
      back = backPath,
    }
  end

  for _, target in ipairs(Targets.trainers) do
    local trainerPath = path("trainers", target.id)
    assets[trainerPath] = readTrainerImage(reader, spec.trainerFrontTable,
      spec.trainerPaletteTable, target.picture)
    trainers[#trainers + 1] = {
      id = target.id,
      pic = trainerPath,
    }
  end

  return {
    revision = revision,
    assets = assets,
    pokemon = pokemon,
    trainers = trainers,
  }
end

return VisualSprites
