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
    overrides = {
      ["2,2"] = { x = 5, y = 6 },
      ["6,2"] = { x = 14, y = 6 },
      ["6,5"] = { x = 15, y = 12 },
    },
  },
  FIRERED_REDS_HOUSE_1F = {
    map = "REDS_HOUSE_1F",
    targetWidth = 4, targetHeight = 4, targetTileset = "REDS_HOUSE_1",
    layout = 0x082D5200, header = 0x08350D50,
    sourceWidth = 13, sourceHeight = 10, borderWidth = 2, borderHeight = 2,
    primary = 0x082D4BB4, secondary = 0x082D4C74,
    overrides = {
      ["0,0"] = { x = 2, y = 0 },
      ["1,0"] = { x = 5, y = 0 },
      ["3,0"] = { x = 9, y = 1 },
      ["2,2"] = { x = 7, y = 3 },
      ["1,3"] = { x = 4, y = 7 },
    },
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

  local source = profile.source
  local target = profile.expectedTarget
  check(source.originX >= 0 and source.originY >= 0,
    profile.id .. " source origin must be non-negative")
  check(source.originX + target.width * 2 <= source.width
      and source.originY + target.height * 2 <= source.height,
    profile.id .. " normal source crop exceeds the declared FireRed layout")

  for key, wantPoint in pairs(want.overrides or {}) do
    local actual = (source.overrides or {})[key]
    check(actual and actual.x == wantPoint.x and actual.y == wantPoint.y,
      profile.id .. " landmark override changed: " .. key)
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
end

for id in pairs(expected) do
  check(seen[id], "missing semantic profile: " .. id)
end

print("FireRed Kanto Visual Importer semantic-profile catalogue tests passed")
