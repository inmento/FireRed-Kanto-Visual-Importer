local Addresses = require("mods.FIRERED_KANTO_VISUALS.lib.addresses")
local Reader = require("mods.FIRERED_KANTO_VISUALS.lib.gba_reader")
local Lz77 = require("mods.FIRERED_KANTO_VISUALS.lib.lz77")

local GeneralTileset = {}

local TILE_SIZE = 8
local SOURCE_TILES = 640
local SOURCE_METATILES = 640
local SOURCE_PALETTES = 7
local OUTPUT_SCALE = 2
local OUTPUT_METATILE_SIZE = 32
local OUTPUT_TILES_PER_METATILE = 16
local OUTPUT_TILES_PER_ROW = 64
local OUTPUT_METATILES_PER_ROW = OUTPUT_TILES_PER_ROW / 4

local function fail(message)
  error("FireRed importer: " .. message, 2)
end

local function copyTable(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function revisionFromHeader(rom)
  -- The required-import MD5 allowlist is the authoritative compatibility gate.
  -- This test build intentionally supports only the confirmed FireRed v1.0
  -- layout, whose Game Pak header revision byte is zero.
  local revision = rom:byte(0xBD) -- zero-based GBA header offset 0xBC
  if revision ~= 0 then
    fail("this build supports FireRed English v1.0 only")
  end
  return assert(Addresses.forMd5("e26ee0d44e809351c8ce2d73c7400cdd"),
    "FireRed importer: v1.0 layout is missing")
end

local function color15(value)
  local r = value % 32
  local g = math.floor(value / 32) % 32
  local b = math.floor(value / 1024) % 32
  return r / 31, g / 31, b / 31
end

local function decodePalettes(reader, address)
  local offset = reader:offsetFromAddress(address, "General palette table")
  local palettes = {}
  for palette = 0, SOURCE_PALETTES - 1 do
    local colors = {}
    for index = 0, 15 do
      colors[index] = { color15(reader:u16(offset + (palette * 16 + index) * 2,
        "General palette color")) }
    end
    palettes[palette] = colors
  end
  return palettes
end

local function tilePixel(tiles, tile, x, y)
  if tile < 0 or tile >= SOURCE_TILES then return 0 end
  local byteIndex = tile * 32 + y * 4 + math.floor(x / 2) + 1
  local byte = tiles:byte(byteIndex) or 0
  if x % 2 == 0 then return byte % 16 end
  return math.floor(byte / 16) % 16
end

local function entryParts(entry)
  return {
    tile = entry % 0x400,
    hflip = math.floor(entry / 0x400) % 2 == 1,
    vflip = math.floor(entry / 0x800) % 2 == 1,
    palette = math.floor(entry / 0x1000) % 16,
  }
end

local function decodeMetatileEntries(reader, address)
  local offset = reader:offsetFromAddress(address, "General metatile table")
  local entries = {}
  for metatile = 0, SOURCE_METATILES - 1 do
    local row = {}
    for index = 0, 7 do
      row[index + 1] = entryParts(reader:u16(offset + (metatile * 8 + index) * 2,
        "General metatile entry"))
    end
    entries[metatile] = row
  end
  return entries
end

local function decodeAttributes(reader, address)
  local offset = reader:offsetFromAddress(address, "General metatile attributes")
  local attributes = {}
  for metatile = 0, SOURCE_METATILES - 1 do
    attributes[metatile] = reader:u32(offset + metatile * 4,
      "General metatile attribute")
  end
  return attributes
end

local function composeMetatile(imageData, tiles, palettes, entries, metatileIndex)
  -- FireRed metatiles contain two 2x2 layers. Drawing layer 0 then layer 1
  -- respects transparent colour-0 pixels without importing FireRed gameplay
  -- behavior, collision, or elevation into the target game.
  -- A FireRed metatile becomes a 4×4 region in the generated 8px tile grid.
  -- The old arithmetic treated its sixteen tile IDs as one contiguous row,
  -- which advanced the image Y coordinate after every four metatiles and
  -- eventually wrote below the atlas. Place each 4×4 region explicitly.
  local metatileX = metatileIndex % OUTPUT_METATILES_PER_ROW
  local metatileY = math.floor(metatileIndex / OUTPUT_METATILES_PER_ROW)
  local tileBaseX = metatileX * OUTPUT_METATILE_SIZE
  local tileBaseY = metatileY * OUTPUT_METATILE_SIZE

  for layer = 0, 1 do
    for cell = 0, 3 do
      local entry = entries[layer * 4 + cell + 1]
      local palette = palettes[entry.palette] or palettes[0]
      for sy = 0, 7 do
        for sx = 0, 7 do
          local sourceX = entry.hflip and (7 - sx) or sx
          local sourceY = entry.vflip and (7 - sy) or sy
          local index = tilePixel(tiles, entry.tile, sourceX, sourceY)
          -- Colour zero on the upper layer is transparent. The lower layer is
          -- painted first, so the visible result keeps FireRed's terrain edges.
          if layer == 0 or index ~= 0 then
            local color = palette[index] or palette[0]
            local outX = (cell % 2) * 16 + sx * OUTPUT_SCALE
            local outY = math.floor(cell / 2) * 16 + sy * OUTPUT_SCALE
            for yy = 0, OUTPUT_SCALE - 1 do
              for xx = 0, OUTPUT_SCALE - 1 do
                imageData:setPixel(tileBaseX + outX + xx, tileBaseY + outY + yy,
                  color[1], color[2], color[3], 1)
              end
            end
          end
        end
      end
    end
  end
end

local function buildAtlas(tiles, palettes, metatiles)
  local rows = math.ceil(SOURCE_METATILES / OUTPUT_METATILES_PER_ROW) * 4
  local width = OUTPUT_TILES_PER_ROW * TILE_SIZE
  local height = rows * TILE_SIZE
  local imageData = love.image.newImageData(width, height)
  imageData:mapPixel(function() return 0, 0, 0, 1 end)

  local blocks = {}
  for metatile = 0, SOURCE_METATILES - 1 do
    composeMetatile(imageData, tiles, palettes, metatiles[metatile], metatile)
    local metatileX = metatile % OUTPUT_METATILES_PER_ROW
    local metatileY = math.floor(metatile / OUTPUT_METATILES_PER_ROW)
    local tileBaseX = metatileX * 4
    local tileBaseY = metatileY * 4
    local block = {}
    for cell = 0, OUTPUT_TILES_PER_METATILE - 1 do
      local cellX = cell % 4
      local cellY = math.floor(cell / 4)
      block[cell + 1] = (tileBaseY + cellY) * OUTPUT_TILES_PER_ROW + tileBaseX + cellX
    end
    blocks[metatile] = block
  end

  return {
    imageData = imageData,
    imageWidth = width,
    imageHeight = height,
    tilesPerRow = OUTPUT_TILES_PER_ROW,
    blocks = blocks,
  }
end

function GeneralTileset.decode(rom)
  if type(rom) ~= "string" or #rom ~= Addresses.ROM_SIZE then
    fail("the imported FireRed file does not have the expected 16 MiB size")
  end
  if not (love and love.image and love.image.newImageData) then
    fail("the image runtime is unavailable; restart Gen1Recomp and retry the import")
  end

  local revision = revisionFromHeader(rom)
  local reader = Reader.new(rom, Addresses.ROM_BASE)
  local spec = assert(revision.general, "FireRed importer: missing General tileset revision layout")

  local tilesOffset = reader:offsetFromAddress(spec.tiles, "General compressed tiles")
  local tiles = Lz77.decode(reader, tilesOffset, "General tiles")
  if #tiles ~= SOURCE_TILES * 32 then
    fail("General tiles decompressed to an unexpected size")
  end

  local palettes = decodePalettes(reader, spec.palettes)
  local metatiles = decodeMetatileEntries(reader, spec.metatiles)
  local attributes = decodeAttributes(reader, spec.attributes)
  local atlas = buildAtlas(tiles, palettes, metatiles)

  atlas.revision = copyTable(revision)
  atlas.sourceMetatileAttributes = attributes
  atlas.sourceMetatileCount = SOURCE_METATILES
  return { revision = revision, atlas = atlas }
end

return GeneralTileset
