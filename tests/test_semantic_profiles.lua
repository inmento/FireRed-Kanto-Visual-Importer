local ROOT = "/home/ubuntu/firered-kanto-visual-importer"

local function load(relative)
  return assert(loadfile(ROOT .. "/" .. relative))()
end

local function check(condition, message)
  if not condition then error(message or "check failed", 2) end
end

local Profiles = load("lib/semantic_profiles.lua")

local expected = {
  FIRERED_PALLET_TOWN = {
    map = "PALLET_TOWN",
    targetWidth = 10, targetHeight = 9, targetTileset = "OVERWORLD",
    layout = 0x082DD4C0, header = 0x08350618,
    sourceWidth = 24, sourceHeight = 20, borderWidth = 2, borderHeight = 2,
    primary = 0x082D4A94, secondary = 0x082D4AAC,
    visualMode = "base-overrides",
    visualPolicy = nil,
    blockOverrides = { [1] = { x = 2, y = 2 } },
    overrides = {
      ["2,2"] = { x = 6, y = 6 },
      ["6,2"] = { x = 15, y = 6 },
      ["6,5"] = { x = 14, y = 12 },
    },
  },
  FIRERED_REDS_HOUSE_2F = {
    map = "REDS_HOUSE_2F",
    targetWidth = 4, targetHeight = 4, targetTileset = "REDS_HOUSE_2",
    layout = 0x082D52FC, header = 0x08350D6C,
    sourceWidth = 12, sourceHeight = 9, borderWidth = 2, borderHeight = 2,
    primary = 0x082D4BB4, secondary = 0x082D4C74,
    visualMode = nil,
    visualPolicy = nil,
    overrides = { ["3,0"] = { x = 9, y = 2 } },
  },
  FIRERED_REDS_HOUSE_1F = {
    map = "REDS_HOUSE_1F",
    targetWidth = 4, targetHeight = 4, targetTileset = "REDS_HOUSE_1",
    layout = 0x082D5200, header = 0x08350D50,
    sourceWidth = 13, sourceHeight = 10, borderWidth = 2, borderHeight = 2,
    primary = 0x082D4BB4, secondary = 0x082D4C74,
    visualMode = nil,
    visualPolicy = nil,
  },
}

local seen = {}
for _, profile in Profiles.each() do
  check(not seen[profile.id], "semantic profile ids must be unique")
  seen[profile.id] = true

  local want = expected[profile.id]
  check(want ~= nil, "unexpected semantic profile: " .. tostring(profile.id))
  check(profile.map == want.map, profile.id .. " target map changed")
  check(profile.expectedTarget.width == want.targetWidth and profile.expectedTarget.height == want.targetHeight,
    profile.id .. " target map dimensions changed")
  check(profile.expectedTarget.tileset == want.targetTileset,
    profile.id .. " target tileset changed")
  check(profile.source.layout == want.layout and profile.source.header == want.header,
    profile.id .. " FireRed layout/header address changed")
  check(profile.source.width == want.sourceWidth and profile.source.height == want.sourceHeight,
    profile.id .. " FireRed layout dimensions changed")
  check(profile.source.borderWidth == want.borderWidth and profile.source.borderHeight == want.borderHeight,
    profile.id .. " FireRed layout border dimensions changed")
  check(profile.source.primaryTileset == want.primary and profile.source.secondaryTileset == want.secondary,
    profile.id .. " FireRed tileset address changed")
  check(profile.source.visualMode == want.visualMode,
    profile.id .. " visual reconstruction mode changed")
  check(profile.source.visualPolicy == want.visualPolicy,
    profile.id .. " visual preservation policy changed")

  local source = profile.source
  if want.blockOverrides then
    for block, expectedPoint in pairs(want.blockOverrides) do
      local point = (source.blockOverrides or {})[block]
      check(point and point.x == expectedPoint.x and point.y == expectedPoint.y,
        profile.id .. " block visual override changed for " .. block)
    end
  end
  if want.overrides then
    for key, expectedPoint in pairs(want.overrides) do
      local point = (source.overrides or {})[key]
      check(point and point.x == expectedPoint.x and point.y == expectedPoint.y,
        profile.id .. " explicit visual override changed at " .. key)
    end
  end
  local target = profile.expectedTarget
  check(source.originX >= 0 and source.originY >= 0,
    profile.id .. " source origin must be non-negative")
  if source.visualMode ~= "layout-fit" and source.visualMode ~= "base-overrides" then
    check(source.originX + target.width * 2 <= source.width
        and source.originY + target.height * 2 <= source.height,
      profile.id .. " normal source crop exceeds the declared FireRed layout")
  end

  for key, point in pairs(source.overrides or {}) do
    local x, y = key:match("^(%-?%d+),(%-?%d+)$")
    x, y = tonumber(x), tonumber(y)
    check(x and y and x >= 0 and y >= 0 and x < target.width and y < target.height,
      profile.id .. " override has an invalid target coordinate")
    check(type(point) == "table" and type(point.x) == "number" and type(point.y) == "number",
      profile.id .. " override must have numeric source coordinates")
    check(point.x >= 0 and point.y >= 0 and point.x + 1 < source.width and point.y + 1 < source.height,
      profile.id .. " override samples outside the declared FireRed layout")
  end
  for block, point in pairs(source.blockOverrides or {}) do
    check(type(block) == "number" and block >= 0 and math.floor(block) == block,
      profile.id .. " block override has an invalid Gen 1 block id")
    check(type(point) == "table" and type(point.x) == "number" and type(point.y) == "number",
      profile.id .. " block override must have numeric source coordinates")
    check(point.x >= 0 and point.y >= 0 and point.x + 1 < source.width and point.y + 1 < source.height,
      profile.id .. " block override samples outside the declared FireRed layout")
  end
end

for id in pairs(expected) do
  check(seen[id], "missing semantic profile: " .. id)
end

print("FireRed Kanto Visual Importer semantic-profile catalogue tests passed")
