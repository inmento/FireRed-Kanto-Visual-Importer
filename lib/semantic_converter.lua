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
-- A 4×4 Gen 1 block contains four 16×16 movement cells. Map:cellTile reads
-- the bottom-left 8×8 tile of each cell: rows 2/4 and columns 1/3 (1-based).
-- Lock all four, not just the lower-left block cell, or a door/stair/exit can
-- retain another cell's collision role and trap the player.
local COLLISION_TILE_INDICES = { 5, 7, 13, 15 }

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
  -- Metatile palette IDs are global BG palette slots. Primary owns slots 0..6;
  -- a secondary tileset carries the complete palette-slot table because the
  -- engine loads its visible palettes from slot 7 onward.
  local paletteCount = isPrimary and PRIMARY_PALETTES or 16
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
  local borderAddress = reader:u32(layoutOffset + 8, profile.id .. " border block data")
  local mapAddress = reader:u32(layoutOffset + 12, profile.id .. " map block data")
  local primaryAddress = reader:u32(layoutOffset + 16, profile.id .. " primary tileset")
  local secondaryAddress = reader:u32(layoutOffset + 20, profile.id .. " secondary tileset")
  local borderWidth = reader:u8(layoutOffset + 24, profile.id .. " border width")
  local borderHeight = reader:u8(layoutOffset + 25, profile.id .. " border height")
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
  if borderWidth ~= source.borderWidth or borderHeight ~= source.borderHeight then
    fail(('%s layout border is %dx%d; expected %dx%d'):format(profile.id,
      borderWidth, borderHeight, source.borderWidth, source.borderHeight))
  end
  if borderWidth < 2 or borderHeight < 2 then
    fail(profile.id .. " layout border is too small for a 32px target block")
  end
  local mapOffset = reader:offsetFromAddress(mapAddress, profile.id .. " map block data")
  local borderOffset = reader:offsetFromAddress(borderAddress, profile.id .. " border block data")
  local entries, borderEntries = {}, {}
  for index = 0, width * height - 1 do
    entries[index + 1] = reader:u16(mapOffset + index * 2, profile.id .. " map block")
  end
  for index = 0, borderWidth * borderHeight - 1 do
    borderEntries[index + 1] = reader:u16(borderOffset + index * 2, profile.id .. " border block")
  end
  return {
    width = width, height = height, entries = entries,
    borderWidth = borderWidth, borderHeight = borderHeight, borderEntries = borderEntries,
  }
end

local function sourceCell(layout, x, y, label)
  if x < 0 or y < 0 or x >= layout.width or y >= layout.height then
    fail(('%s sampled source cell (%d,%d) outside %dx%d layout'):format(label,
      x, y, layout.width, layout.height))
  end
  return layout.entries[y * layout.width + x + 1] % 0x400
end

local function tilePixel(primary, secondary, tile, x, y)
  -- FireRed copies the primary sheet to VRAM tiles 0..639 and the active
  -- secondary sheet to tiles 640..1023. Metatile entries refer to that combined
  -- VRAM index space even when the metatile itself belongs to the primary table.
  local bank, localTile, bankLabel
  if tile < PRIMARY_TILES then
    bank, localTile, bankLabel = primary, tile, "primary"
  else
    bank, localTile, bankLabel = secondary, tile - PRIMARY_TILES, "secondary"
  end
  local byteIndex = localTile * 32 + y * 4 + math.floor(x / 2) + 1
  local byte = bank.tiles:byte(byteIndex)
  if not byte then
    fail(("source %s tile %d (global %d) is outside the decoded %d-tile sheet"):format(
      bankLabel, localTile, tile, #bank.tiles / 32))
  end
  if x % 2 == 0 then return byte % 16 end
  return math.floor(byte / 16) % 16
end

local function paintMetatile(imageData, primary, secondary, metatileTileset, metatile, left, top, label)
  local entries = metatileTileset.metatiles[metatile]
  if not entries then fail(label .. " references an unavailable source metatile") end
  -- A Gen III metatile holds two 2×2 layers. The transparent upper layer is
  -- drawn second; each original FireRed 8×8 cell remains exactly 8×8 here.
  for layer = 0, 1 do
    for cell = 0, 3 do
      local entry = entries[layer * 4 + cell + 1]
      local paletteBank = entry.palette < PRIMARY_PALETTES and primary or secondary
      local palette = paletteBank.palettes[entry.palette]
      if not palette then fail(label .. " has no usable palette for global slot " .. entry.palette) end
      for sy = 0, 7 do
        for sx = 0, 7 do
          local sourceX = entry.hflip and (7 - sx) or sx
          local sourceY = entry.vflip and (7 - sy) or sy
          local colorIndex = tilePixel(primary, secondary, entry.tile, sourceX, sourceY)
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
    grassTileForOriginal = {},
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
  -- Gen1Recomp exposes a single grassTile field, so all original grass cells
  -- must share one semantic tile. Other roles may be visually distinct at the
  -- four movement-cell positions of a generated block and therefore receive
  -- their own locked semantic tile.
  local existing = oldTile == state.base.grassTile
    and state.grassTileForOriginal[oldTile] or nil
  if existing then return existing end
  local id = semanticStart + #state.roles
  if oldTile == state.base.grassTile then state.grassTileForOriginal[oldTile] = id end
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

local function paintSourceMetatile(atlas, primary, secondary, mapEntry, left, top, label)
  local tileset, metatile = sourceTilesetFor(primary, secondary, mapEntry)
  paintMetatile(atlas, primary, secondary, tileset, metatile, left, top, label)
end

-- Build a temporary 8px-native visual canvas for one declared FireRed layout.
-- It is used only by profiles that explicitly opt into a whole-layout fit; no
-- source graphics are persisted or exposed outside this in-memory build.
local function paintLayoutCanvas(layout, primary, secondary, profile)
  local width, height = layout.width * 16, layout.height * 16
  local canvas = love.image.newImageData(width, height)
  canvas:mapPixel(function() return 0, 0, 0, 1 end)
  for y = 0, layout.height - 1 do
    for x = 0, layout.width - 1 do
      paintSourceMetatile(canvas, primary, secondary, sourceCell(layout, x, y, profile.id),
        x * 16, y * 16, profile.id .. " layout-fit")
    end
  end
  return canvas
end

local function paintLayoutFitBlock(atlas, canvas, targetMap, targetX, targetY, pixelX, pixelY)
  -- Fit the declared FireRed layout to the fixed Gen 1 target-map footprint.
  -- This is a per-pixel nearest-neighbor coordinate transform, not a global
  -- image resize: output remains tile-aligned and semantic cells are restored
  -- afterwards from the original Gen 1 target block.
  local targetWidth = targetMap.width * 32
  local targetHeight = targetMap.height * 32
  local sourceWidth, sourceHeight = canvas:getWidth(), canvas:getHeight()
  local startX, startY = targetX * 32, targetY * 32
  for dy = 0, 31 do
    local sourceY = math.min(sourceHeight - 1, math.floor((startY + dy) * sourceHeight / targetHeight))
    for dx = 0, 31 do
      local sourceX = math.min(sourceWidth - 1, math.floor((startX + dx) * sourceWidth / targetWidth))
      local r, g, b, a = canvas:getPixel(sourceX, sourceY)
      atlas:setPixel(pixelX + dx, pixelY + dy, r, g, b, a)
    end
  end
end

local function loadBaseAtlas(profile, base)
  if type(base.image) ~= "string" then
    fail(profile.id .. " preserve-base-blocks policy requires the target tileset image")
  end
  local ok, image = pcall(love.image.newImageData, base.image)
  if not ok or not image then
    fail(profile.id .. " could not read the target tileset image for terrain preservation")
  end
  if image:getWidth() % TILE_SIZE ~= 0 or image:getHeight() % TILE_SIZE ~= 0 then
    fail(profile.id .. " target tileset image is not aligned to 8px tiles")
  end
  return image
end

-- A generated profile atlas is true-colour because it also holds decoded
-- FireRed pixels. Copying a raw grayscale Gen 1 tile into that atlas would
-- bypass Gen1Recomp's normal per-tileset GBC bake and leave it monochrome next
-- to FireRed. When the live palette pack is available, pre-bake the copied
-- base tile with the same palette-group data the renderer uses for OVERWORLD.
local function basePaletteContext(profile, base, gameData, paletteMode)
  if not gameData or type(base.id) ~= "string" then return nil end
  local ok, palette = pcall(require, "src.render.PaletteFX")
  -- A generated true-colour atlas cannot receive TileRenderer's later
  -- per-tile ADVANCED bake. Profile generation normally uses the active mode,
  -- but map profiles may also request an explicit `redpp` variant so a saved
  -- ADVANCED selection that initializes after mod content still gets coherent
  -- copied Gen 1 pixels on the engine's normal map reload path.
  if not ok or not palette or not palette.usesGbcPack or not palette.usesGbcPack(paletteMode)
     or not palette.hasWorldTileset(base.id) then return nil end
  local groupColors = palette.worldGroupColors(gameData, base.id, profile.map, nil)
  if type(groupColors) ~= "table" then return nil end
  return { palette = palette, groupColors = groupColors, tilesetId = base.id,
    mapId = profile.map, tileColors = {} }
end

local function colorBasePixel(context, tile, r, g, b, a)
  if not context or a <= 0 then return r, g, b, a end
  local colors = context.tileColors[tile]
  if colors == nil then
    local group = context.palette.worldGroupAt(context.tilesetId, context.mapId, tile)
    colors = group and context.groupColors[group + 1] or false
    context.tileColors[tile] = colors
  end
  if not colors then return r, g, b, a end
  local color = r > 0.83 and colors[1] or r > 0.5 and colors[2]
    or r > 0.17 and colors[3] or colors[4]
  return color[1] / 255, color[2] / 255, color[3] / 255, a
end

local function copyBaseBlock(atlas, baseAtlas, base, baseRow, left, top, label, paletteContext)
  local tilesPerRow = base.tilesPerRow or math.floor(baseAtlas:getWidth() / TILE_SIZE)
  if tilesPerRow < 1 then fail(label .. " target tileset image has no tile columns") end
  for index = 1, BLOCK_TILES do
    local tile = baseRow[index]
    local sourceX = (tile % tilesPerRow) * TILE_SIZE
    local sourceY = math.floor(tile / tilesPerRow) * TILE_SIZE
    if sourceY + TILE_SIZE > baseAtlas:getHeight() then
      fail(label .. " target block references a tile outside its base atlas")
    end
    local destinationX = left + ((index - 1) % 4) * TILE_SIZE
    local destinationY = top + math.floor((index - 1) / 4) * TILE_SIZE
    for y = 0, TILE_SIZE - 1 do
      for x = 0, TILE_SIZE - 1 do
        local r, g, b, a = baseAtlas:getPixel(sourceX + x, sourceY + y)
        r, g, b, a = colorBasePixel(paletteContext, tile, r, g, b, a)
        atlas:setPixel(destinationX + x, destinationY + y, r, g, b, a)
      end
    end
  end
end

local function paintSourceBlock(atlas, layout, primary, secondary, profile, sourceBaseX, sourceBaseY, left, top, label)
  for sourceY = 0, 1 do
    for sourceX = 0, 1 do
      local mapEntry = sourceCell(layout, sourceBaseX + sourceX, sourceBaseY + sourceY, profile.id)
      paintSourceMetatile(atlas, primary, secondary, mapEntry,
        left + sourceX * 16, top + sourceY * 16, label)
    end
  end
end

local function targetBlockPosition(index)
  local tileBaseX = (index % 16) * 4
  local tileBaseY = math.floor(index / 16) * 4
  return tileBaseX * TILE_SIZE, tileBaseY * TILE_SIZE, tileBaseX, tileBaseY
end

local function composeProfileBlock(atlas, layout, primary, secondary, profile, targetMap, layoutCanvas, baseAtlas, basePalette, targetX, targetY,
    blockIndex, oldBlock, base, semanticState, semanticStart)
  local pixelX, pixelY, tileBaseX, tileBaseY = targetBlockPosition(blockIndex)
  local baseRow = base.blocks[(oldBlock or 0) + 1]
  if type(baseRow) ~= "table" or #baseRow ~= BLOCK_TILES then
    fail(profile.id .. " target map references an unavailable Gen 1 block")
  end

  local source = profile.source
  local baseOverrides = source.visualMode == "base-overrides"
  local preserved = source.visualPolicy == "preserve-base-blocks"
    and source.preserveBaseBlocks[oldBlock]
  if baseOverrides or preserved then
    -- The constrained facelift starts with the original Gen 1 block pixels and
    -- paints FireRed only where the profile names a compact source sample. This
    -- deliberately prevents a whole foreign map layout from being compressed
    -- through an unrelated fixed Gen 1 footprint.
    copyBaseBlock(atlas, assert(baseAtlas, profile.id .. " base atlas is missing"), base,
      baseRow, pixelX, pixelY, profile.id, basePalette)
  elseif source.visualMode == "layout-fit" then
    paintLayoutFitBlock(atlas, assert(layoutCanvas, profile.id .. " layout-fit canvas is missing"),
      targetMap, targetX, targetY, pixelX, pixelY)
  else
    local override = (source.overrides or {})[targetX .. "," .. targetY]
    local sourceBaseX = override and override.x or (source.originX + targetX * 2)
    local sourceBaseY = override and override.y or (source.originY + targetY * 2)
    paintSourceBlock(atlas, layout, primary, secondary, profile, sourceBaseX, sourceBaseY,
      pixelX, pixelY, profile.id)
  end

  local override
  if baseOverrides then
    override = (source.overrides or {})[targetX .. "," .. targetY]
      or (source.blockOverrides or {})[oldBlock]
  elseif source.visualMode == "layout-fit" then
    override = (source.layoutFitOverrides or {})[targetX .. "," .. targetY]
  end
  if override then
    paintSourceBlock(atlas, layout, primary, secondary, profile, override.x, override.y,
      pixelX, pixelY, profile.id .. " explicit visual override")
  end

  local block = {}
  for tileY = 0, 3 do
    for tileX = 0, 3 do
      block[tileY * 4 + tileX + 1] = (tileBaseY + tileY) * TILES_PER_ROW + tileBaseX + tileX
    end
  end
  for _, index in ipairs(COLLISION_TILE_INDICES) do
    local oldCollisionTile = baseRow[index]
    local captureX = pixelX + ((index - 1) % 4) * TILE_SIZE
    local captureY = pixelY + math.floor((index - 1) / 4) * TILE_SIZE
    block[index] = semanticTile(atlas, semanticState, oldCollisionTile,
      captureX, captureY, semanticStart)
  end
  return block
end

local function composeBorderBlock(atlas, layout, primary, secondary, profile, blockIndex,
    oldBlock, base, baseAtlas, basePalette, semanticState, semanticStart)
  local pixelX, pixelY, tileBaseX, tileBaseY = targetBlockPosition(blockIndex)
  local baseRow = base.blocks[(oldBlock or 0) + 1]
  if type(baseRow) ~= "table" or #baseRow ~= BLOCK_TILES then
    fail(profile.id .. " target map references an unavailable Gen 1 border block")
  end
  if profile.source.visualMode == "base-overrides" then
    copyBaseBlock(atlas, assert(baseAtlas, profile.id .. " border base atlas is missing"), base,
      baseRow, pixelX, pixelY, profile.id .. " border", basePalette)
  else
    -- A small Gen 1 interior draws its border repeatedly outside the 4×4 map.
    -- Sample FireRed's dedicated MapLayout border (not the room's top-left map
    -- cells) so the repeated edge remains a background frame instead of a wall
    -- texture copied across the whole camera.
    for sourceY = 0, 1 do
      for sourceX = 0, 1 do
        local mapEntry = layout.borderEntries[sourceY * layout.borderWidth + sourceX + 1] % 0x400
        paintSourceMetatile(atlas, primary, secondary, mapEntry,
          pixelX + sourceX * 16, pixelY + sourceY * 16, profile.id .. " border")
      end
    end
  end
  local block = {}
  for tileY = 0, 3 do
    for tileX = 0, 3 do
      block[tileY * 4 + tileX + 1] = (tileBaseY + tileY) * TILES_PER_ROW + tileBaseX + tileX
    end
  end
  for _, index in ipairs(COLLISION_TILE_INDICES) do
    local oldCollisionTile = baseRow[index]
    local captureX = pixelX + ((index - 1) % 4) * TILE_SIZE
    local captureY = pixelY + math.floor((index - 1) / 4) * TILE_SIZE
    block[index] = semanticTile(atlas, semanticState, oldCollisionTile,
      captureX, captureY, semanticStart)
  end
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

function Converter.build(profile, rom, targetMap, targetTileset, options)
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

  local layoutFit = profile.source.visualMode == "layout-fit"
  local baseOverrides = profile.source.visualMode == "base-overrides"
  if profile.source.visualMode and not layoutFit and not baseOverrides then
    fail(profile.id .. " has an unknown visual mode")
  end
  local preserveBaseBlocks = profile.source.visualPolicy == "preserve-base-blocks"
  if profile.source.visualPolicy and not preserveBaseBlocks then
    fail(profile.id .. " has an unknown visual policy")
  end
  if preserveBaseBlocks and type(profile.source.preserveBaseBlocks) ~= "table" then
    fail(profile.id .. " preserve-base-blocks policy requires a block-id set")
  end
  if not layoutFit and not baseOverrides then
    local sourceCellsWide = profile.source.originX + targetMap.width * 2
    local sourceCellsHigh = profile.source.originY + targetMap.height * 2
    if sourceCellsWide > layout.width or sourceCellsHigh > layout.height then
      fail(profile.id .. " profile crop exceeds its FireRed layout")
    end
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
  local maxTiles = semanticStart + totalBlocks * #COLLISION_TILE_INDICES
  local imageHeight = math.ceil(maxTiles / TILES_PER_ROW) * TILE_SIZE
  local atlas = love.image.newImageData(TILES_PER_ROW * TILE_SIZE, imageHeight)
  atlas:mapPixel(function() return 0, 0, 0, 1 end)

  local semanticState = newSemantics(targetTileset)
  local layoutCanvas = layoutFit and paintLayoutCanvas(layout, primary, secondary, profile) or nil
  local baseAtlas = (preserveBaseBlocks or baseOverrides) and loadBaseAtlas(profile, targetTileset) or nil
  local basePalette = baseAtlas and basePaletteContext(profile, targetTileset,
    options and options.gameData, options and options.basePaletteMode) or nil
  local blocks, remappedMapBlocks = {}, {}
  for by = 0, targetMap.height - 1 do
    for bx = 0, targetMap.width - 1 do
      local index = by * targetMap.width + bx
      local oldBlock = targetMap.blocks[index + 1]
      blocks[index + 1] = composeProfileBlock(atlas, layout, primary, secondary, profile,
        targetMap, layoutCanvas, baseAtlas, basePalette, bx, by, index, oldBlock, targetTileset, semanticState, semanticStart)
      remappedMapBlocks[index + 1] = index
    end
  end

  -- The existing border remains a gameplay border. Its appearance uses the
  -- profile's dedicated FireRed layout-border cells, while its collision
  -- semantics stay tied to the original target-map border block.
  blocks[totalBlocks] = composeBorderBlock(atlas, layout, primary, secondary, profile,
    blockCount, targetMap.borderBlock or 0, targetTileset, baseAtlas, basePalette, semanticState, semanticStart)

  if not semanticState.grassTile and targetTileset.grassTile ~= nil then
    fail(profile.id .. " did not encounter the target map's grass collision tile")
  end
  if #semanticState.roles > totalBlocks * #COLLISION_TILE_INDICES then
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
