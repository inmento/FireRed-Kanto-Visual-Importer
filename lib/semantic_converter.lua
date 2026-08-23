-- FireRed Kanto Visual Importer: map-aware semantic tile converter.
--
-- This module reads a bounded, profile-declared subset of the verified local
-- FireRed v1.0 ROM. It never changes Gen 1 map geometry or gameplay. Instead
-- it reconstructs a dedicated visual tileset for one existing Gen 1 map:
-- each native FireRed 16×16 metatile remains a 2×2 grid of 8×8 target tiles,
-- and four source metatiles fill one existing Gen 1 32×32 map block.

local Addresses = require("mods.FIRERED_KANTO_VISUALS.lib.addresses")
local Reader = require("mods.FIRERED_KANTO_VISUALS.lib.gba_reader")
local Lz77 = require("mods.FIRERED_KANTO_VISUALS.lib.lz77")

local Converter = {}

local TILE_SIZE = 8
local TILES_PER_ROW = 64
local PRIMARY_TILES = 640
local SECONDARY_TILES = 384
local PRIMARY_METATILES = 640
local SECONDARY_METATILES = 384
local PRIMARY_PALETTES = 7
local SECONDARY_PALETTES = 6
local MAP_METATILE_MASK = 0x03FF
local BLOCK_TILES = 16
local COLLISION_TILE_INDEX = 13 -- 1-based bottom-left tile of a 4×4 Gen 1 block.

local function fail(message)
  error("FireRed importer: " .. message, 2)
end

local function color15(value)
  local r = value % 32
  local g = math.floor(value / 32) % 32
  local b = math.floor(value / 1024) % 32
  return r / 31, g / 31, b / 31
end

local function entryParts(entry)
  return {
    tile = entry % 0x400,
    hflip = math.floor(entry / 0x400) % 2 == 1,
    vflip = math.floor(entry / 0x800) % 2 == 1,
    palette = math.floor(entry / 0x1000) % 16,
  }
end

local function revisionFromHeader(rom)
  if type(rom) ~= "string" or #rom ~= Addresses.ROM_SIZE then
    fail("the imported FireRed file does not have the expected 16 MiB size")
  end
  if rom:byte(0xBD) ~= 0 then
    fail("this build supports FireRed English v1.0 only")
  end
  return assert(Addresses.forMd5("e26ee0d44e809351c8ce2d73c7400cdd"),
    "FireRed importer: v1.0 layout is missing")
end

local function decodeTilesetHeader(reader, address, label)
  local offset = reader:offsetFromAddress(address, label .. " header")
  local tiles = reader:u32(offset + 4, label .. " tile pointer")
  local palettes = reader:u32(offset + 8, label .. " palette pointer")
  local metatiles = reader:u32(offset + 12, label .. " metatile pointer")
  local attributes = reader:u32(offset + 20, label .. " attribute pointer")
  -- Force bounded validation of every pointer now. A profile never follows an
  -- unvalidated pointer obtained from a player-provided source file.
  reader:offsetFromAddress(tiles, label .. " tiles")
  reader:offsetFromAddress(palettes, label .. " palettes")
  reader:offsetFromAddress(metatiles, label .. " metatiles")
  reader:offsetFromAddress(attributes, label .. " attributes")
  return {
    compressed = reader:u8(offset, label .. " compression flag") ~= 0,
    secondary = reader:u8(offset + 1, label .. " secondary flag") ~= 0,
    tiles = tiles,
    palettes = palettes,
    metatiles = metatiles,
    attributes = attributes,
  }
end

local function decodePalettes(reader, address, count, label)
  local offset = reader:offsetFromAddress(address, label .. " palette table")
  local palettes = {}
  for palette = 0, count - 1 do
    local colors = {}
    for index = 0, 15 do
      colors[index] = { color15(reader:u16(offset + (palette * 16 + index) * 2,
        label .. " palette color")) }
    end
    palettes[palette] = colors
  end
  return palettes
end

local function decodeMetatiles(reader, address, count, label)
  local offset = reader:offsetFromAddress(address, label .. " metatile table")
  local metatiles = {}
  for metatile = 0, count - 1 do
    local row = {}
    for index = 0, 7 do
      row[index + 1] = entryParts(reader:u16(offset + (metatile * 8 + index) * 2,
        label .. " metatile entry"))
    end
    metatiles[metatile] = row
  end
  return metatiles
end

local function decodeTiles(reader, header, fallbackCount, label)
  local offset = reader:offsetFromAddress(header.tiles, label .. " tiles")
  local bytes
  if header.compressed then
    -- FireRed does not require every secondary tileset to contain 384 4bpp
    -- tiles. Its LZ77 stream declares the exact source length. In particular,
    -- the Pallet Town and Generic Building 1 secondary sheets are smaller than
    -- the old fixed secondary maximum. Treating 384 as an exact length caused
    -- both first semantic profiles to fail closed after a valid import.
    bytes = Lz77.decode(reader, offset, label .. " compressed tiles")
  else
    -- Raw tilesets have no embedded size header. The fixed count is retained
    -- only for that legacy path; all current semantic profiles are compressed.
    bytes = reader:bytes(offset, fallbackCount * 32, label .. " raw tiles")
  end
  if #bytes < 32 or #bytes % 32 ~= 0 then
    fail(('%s decoded to an invalid %d-byte 4bpp tile sheet'):format(label, #bytes))
  end
  return bytes, #bytes / 32
end

local function decodeTileset(reader, address, kind, label)
  local isPrimary = kind == "primary"
  local expectedSecondary = not isPrimary
  local tileCount = isPrimary and PRIMARY_TILES or SECONDARY_TILES
  local metatileCount = isPrimary and PRIMARY_METATILES or SECONDARY_METATILES
  local paletteCount = isPrimary and PRIMARY_PALETTES or SECONDARY_PALETTES
  local header = decodeTilesetHeader(reader, address, label)
  if header.secondary ~= expectedSecondary then
    fail(('%s has an unexpected primary/secondary tileset flag'):format(label))
  end
  local tiles, decodedTileCount = decodeTiles(reader, header, tileCount, label)
  return {
    header = header,
    tiles = tiles,
    palettes = decodePalettes(reader, header.palettes, paletteCount, label),
    metatiles = decodeMetatiles(reader, header.metatiles, metatileCount, label),
    tileCount = decodedTileCount,
    metatileCount = metatileCount,
  }
end

local function decodeLayout(reader, profile)
  local source = profile.source
  local layoutOffset = reader:offsetFromAddress(source.layout, profile.id .. " layout")
  local width = reader:u32(layoutOffset, profile.id .. " layout width")
  local height = reader:u32(layoutOffset + 4, profile.id .. " layout height")
  local mapAddress = reader:u32(layoutOffset + 12, profile.id .. " map block data")
  local primaryAddress = reader:u32(layoutOffset + 16, profile.id .. " primary tileset")
  local secondaryAddress = reader:u32(layoutOffset + 20, profile.id .. " secondary tileset")
  if width ~= source.width or height ~= source.height then
    fail(('%s layout dimensions are %dx%d; expected %dx%d'):format(profile.id,
      width, height, source.width, source.height))
  end
  if primaryAddress ~= source.primaryTileset or secondaryAddress ~= source.secondaryTileset then
    fail(profile.id .. " layout tilesets do not match this semantic profile")
  end
  local headerOffset = reader:offsetFromAddress(source.header, profile.id .. " map header")
  if reader:u32(headerOffset, profile.id .. " map-header layout pointer") ~= source.layout then
    fail(profile.id .. " map header does not point at the expected layout")
  end
  local mapOffset = reader:offsetFromAddress(mapAddress, profile.id .. " map block data")
  local entries = {}
  for index = 0, width * height - 1 do
    entries[index + 1] = reader:u16(mapOffset + index * 2, profile.id .. " map block")
  end
  return { width = width, height = height, entries = entries }
end

local function sourceCell(layout, x, y, label)
  if x < 0 or y < 0 or x >= layout.width or y >= layout.height then
    fail(('%s sampled source cell (%d,%d) outside %dx%d layout'):format(label,
      x, y, layout.width, layout.height))
  end
  return layout.entries[y * layout.width + x + 1] % 0x400
end

local function tilePixel(tiles, tile, x, y)
  local byteIndex = tile * 32 + y * 4 + math.floor(x / 2) + 1
  local byte = tiles:byte(byteIndex)
  if not byte then fail("source tile index is outside decoded tileset") end
  if x % 2 == 0 then return byte % 16 end
  return math.floor(byte / 16) % 16
end

local function paintMetatile(imageData, tileset, metatile, left, top, label)
  local entries = tileset.metatiles[metatile]
  if not entries then fail(label .. " references an unavailable source metatile") end
  -- A Gen III metatile holds two 2×2 layers. The transparent upper layer is
  -- drawn second; each original FireRed 8×8 cell remains exactly 8×8 here.
  for layer = 0, 1 do
    for cell = 0, 3 do
      local entry = entries[layer * 4 + cell + 1]
      local palette = tileset.palettes[entry.palette] or tileset.palettes[0]
      if not palette then fail(label .. " has no usable palette") end
      for sy = 0, 7 do
        for sx = 0, 7 do
          local sourceX = entry.hflip and (7 - sx) or sx
          local sourceY = entry.vflip and (7 - sy) or sy
          local colorIndex = tilePixel(tileset.tiles, entry.tile, sourceX, sourceY)
          if layer == 0 or colorIndex ~= 0 then
            local color = palette[colorIndex] or palette[0]
            imageData:setPixel(left + (cell % 2) * 8 + sx,
              top + math.floor(cell / 2) * 8 + sy,
              color[1], color[2], color[3], 1)
          end
        end
      end
    end
  end
end

local function copyTile(imageData, fromX, fromY, toX, toY)
  for y = 0, 7 do
    for x = 0, 7 do
      local r, g, b, a = imageData:getPixel(fromX + x, fromY + y)
      imageData:setPixel(toX + x, toY + y, r, g, b, a)
    end
  end
end

local function setFromList(list)
  local out = {}
  for _, value in ipairs(list or {}) do out[value] = true end
  return out
end

local function collisionRole(base, oldTile, sets)
  if oldTile == base.grassTile then return "grass" end
  if sets.door[oldTile] then return "door" end
  if sets.warp[oldTile] then return "warp" end
  if sets.counter[oldTile] then return "counter" end
  if sets.water[oldTile] then return "water" end
  if sets.shore[oldTile] then return "shore" end
  if sets.walkable[oldTile] then return "walkable" end
  return "blocked"
end

local function appendUnique(list, set, value)
  if not set[value] then
    set[value] = true
    list[#list + 1] = value
  end
end

local function newSemantics(base)
  return {
    base = base,
    sets = {
      walkable = setFromList(base.walkable),
      door = setFromList(base.doorTiles),
      warp = setFromList(base.warpTiles),
      counter = setFromList(base.counterTiles),
      water = setFromList(base.waterTiles or { 0x14 }),
      shore = setFromList(base.shoreTiles or { 0x32, 0x48 }),
    },
    tileForOriginal = {},
    roles = {},
    walkable = {}, walkableSet = {},
    doors = {}, doorSet = {},
    warps = {}, warpSet = {},
    counters = {}, counterSet = {},
    waters = {}, waterSet = {},
    shores = {}, shoreSet = {},
    grassTile = nil,
  }
end

local function semanticTile(atlas, state, oldTile, captureX, captureY, semanticStart)
  local existing = state.tileForOriginal[oldTile]
  if existing then return existing end
  local id = semanticStart + #state.roles
  state.tileForOriginal[oldTile] = id
  state.roles[#state.roles + 1] = oldTile
  local tileX = (id % TILES_PER_ROW) * TILE_SIZE
  local tileY = math.floor(id / TILES_PER_ROW) * TILE_SIZE
  copyTile(atlas, captureX, captureY, tileX, tileY)

  local sets = state.sets
  if sets.walkable[oldTile] then appendUnique(state.walkable, state.walkableSet, id) end
  if sets.door[oldTile] then appendUnique(state.doors, state.doorSet, id) end
  if sets.warp[oldTile] then appendUnique(state.warps, state.warpSet, id) end
  if sets.counter[oldTile] then appendUnique(state.counters, state.counterSet, id) end
  if sets.water[oldTile] then appendUnique(state.waters, state.waterSet, id) end
  if sets.shore[oldTile] then appendUnique(state.shores, state.shoreSet, id) end
  if oldTile == state.base.grassTile then state.grassTile = id end
  return id
end

local function sourceTilesetFor(primary, secondary, mapEntry)
  if mapEntry < PRIMARY_METATILES then return primary, mapEntry end
  if mapEntry < PRIMARY_METATILES + SECONDARY_METATILES then
    return secondary, mapEntry - PRIMARY_METATILES
  end
  fail("source map entry references an unavailable FireRed metatile")
end

local function targetBlockPosition(index)
  local tileBaseX = (index % 16) * 4
  local tileBaseY = math.floor(index / 16) * 4
  return tileBaseX * TILE_SIZE, tileBaseY * TILE_SIZE, tileBaseX, tileBaseY
end

local function composeProfileBlock(atlas, layout, primary, secondary, profile, targetX, targetY,
    blockIndex, oldBlock, base, semanticState, semanticStart)
  local pixelX, pixelY, tileBaseX, tileBaseY = targetBlockPosition(blockIndex)
  local overrides = profile.source.overrides or {}
  local override = overrides[targetX .. "," .. targetY]
  local sourceBaseX = override and override.x or (profile.source.originX + targetX * 2)
  local sourceBaseY = override and override.y or (profile.source.originY + targetY * 2)
  for sourceY = 0, 1 do
    for sourceX = 0, 1 do
      local x = sourceBaseX + sourceX
      local y = sourceBaseY + sourceY
      local mapEntry = sourceCell(layout, x, y, profile.id)
      local tileset, metatile = sourceTilesetFor(primary, secondary, mapEntry)
      paintMetatile(atlas, tileset, metatile, pixelX + sourceX * 16, pixelY + sourceY * 16,
        profile.id)
    end
  end

  local baseRow = base.blocks[(oldBlock or 0) + 1]
  if type(baseRow) ~= "table" or #baseRow ~= BLOCK_TILES then
    fail(profile.id .. " target map references an unavailable Gen 1 block")
  end
  local oldCollisionTile = baseRow[COLLISION_TILE_INDEX]
  local newCollisionTile = semanticTile(atlas, semanticState, oldCollisionTile,
    pixelX, pixelY + 24, semanticStart)
  local block = {}
  for tileY = 0, 3 do
    for tileX = 0, 3 do
      block[tileY * 4 + tileX + 1] = (tileBaseY + tileY) * TILES_PER_ROW + tileBaseX + tileX
    end
  end
  block[COLLISION_TILE_INDEX] = newCollisionTile
  return block
end

local function validateTarget(profile, map, base)
  local expect = profile.expectedTarget
  if not map or map.width ~= expect.width or map.height ~= expect.height then
    fail(('%s target map dimensions do not match profile'):format(profile.id))
  end
  if map.tileset ~= expect.tileset then
    fail(('%s target map tileset is %s, expected %s'):format(profile.id,
      tostring(map.tileset), expect.tileset))
  end
  if type(map.blocks) ~= "table" or #map.blocks ~= map.width * map.height then
    fail(profile.id .. " target map has an invalid block grid")
  end
  if not base or type(base.blocks) ~= "table" then
    fail(profile.id .. " target tileset is unavailable")
  end
end

function Converter.build(profile, rom, targetMap, targetTileset)
  local revision = revisionFromHeader(rom)
  if not (love and love.image and love.image.newImageData) then
    fail("the image runtime is unavailable; restart Gen1Recomp and retry the import")
  end
  validateTarget(profile, targetMap, targetTileset)
  local reader = Reader.new(rom, Addresses.ROM_BASE)
  local layout = decodeLayout(reader, profile)
  local primary = decodeTileset(reader, profile.source.primaryTileset, "primary",
    profile.id .. " primary tileset")
  local secondary = decodeTileset(reader, profile.source.secondaryTileset, "secondary",
    profile.id .. " secondary tileset")

  local sourceCellsWide = profile.source.originX + targetMap.width * 2
  local sourceCellsHigh = profile.source.originY + targetMap.height * 2
  if sourceCellsWide > layout.width or sourceCellsHigh > layout.height then
    fail(profile.id .. " profile crop exceeds its FireRed layout")
  end

  -- One visual block per existing target-map block, plus one border block. The
  -- appended semantic tiles preserve the exact original collision-tile classes
  -- used by movement, grass, water, door, warp and counter logic.
  local blockCount = #targetMap.blocks
  local totalBlocks = blockCount + 1
  -- Blocks occupy 4×4 target tiles and are arranged sixteen blocks per atlas
  -- row. Reserve complete rows, not merely `totalBlocks * 16` linear tile IDs:
  -- the seventeenth block begins a new four-tile-high row at tile ID 256.
  local visualTileRows = math.ceil(totalBlocks / 16) * 4
  local semanticStart = visualTileRows * TILES_PER_ROW
  local maxTiles = semanticStart + totalBlocks
  local imageHeight = math.ceil(maxTiles / TILES_PER_ROW) * TILE_SIZE
  local atlas = love.image.newImageData(TILES_PER_ROW * TILE_SIZE, imageHeight)
  atlas:mapPixel(function() return 0, 0, 0, 1 end)

  local semanticState = newSemantics(targetTileset)
  local blocks, remappedMapBlocks = {}, {}
  for by = 0, targetMap.height - 1 do
    for bx = 0, targetMap.width - 1 do
      local index = by * targetMap.width + bx
      local oldBlock = targetMap.blocks[index + 1]
      blocks[index + 1] = composeProfileBlock(atlas, layout, primary, secondary, profile,
        bx, by, index, oldBlock, targetTileset, semanticState, semanticStart)
      remappedMapBlocks[index + 1] = index
    end
  end

  -- The existing border remains a gameplay border. Its appearance uses the
  -- profile's top-left sample, while its collision semantics stay tied to the
  -- original target-map border block.
  blocks[totalBlocks] = composeProfileBlock(atlas, layout, primary, secondary, profile,
    0, 0, blockCount, targetMap.borderBlock or 0, targetTileset, semanticState, semanticStart)

  if not semanticState.grassTile and targetTileset.grassTile ~= nil then
    fail(profile.id .. " did not encounter the target map's grass collision tile")
  end
  if #semanticState.roles > totalBlocks then
    fail(profile.id .. " semantic tile allocation exceeded tile-lock capacity")
  end
  for _, row in ipairs(blocks) do
    if #row ~= BLOCK_TILES then fail(profile.id .. " generated a non-16-tile block") end
  end
  if atlas:getWidth() % TILE_SIZE ~= 0 or atlas:getHeight() % TILE_SIZE ~= 0 then
    fail(profile.id .. " generated a non-integral 8px atlas")
  end

  return {
    revision = revision,
    profile = profile,
    imageData = atlas,
    imageWidth = atlas:getWidth(),
    imageHeight = atlas:getHeight(),
    tilesPerRow = TILES_PER_ROW,
    blocks = blocks,
    mapBlocks = remappedMapBlocks,
    borderBlock = blockCount,
    grassTile = semanticState.grassTile,
    walkable = semanticState.walkable,
    doorTiles = semanticState.doors,
    warpTiles = semanticState.warps,
    counterTiles = semanticState.counters,
    waterTiles = semanticState.waters,
    shoreTiles = semanticState.shores,
    semanticTileCount = #semanticState.roles,
  }
end

return Converter
