local ROOT = "/home/ubuntu/FireRed-Kanto-Visual-Importer"

local function load(relative)
  return assert(loadfile(ROOT .. "/" .. relative))()
end

package.preload["mods.FIRERED_KANTO_VISUALS.lib.addresses"] = function() return load("lib/addresses.lua") end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.gba_reader"] = function() return load("lib/gba_reader.lua") end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.lz77"] = function() return load("lib/lz77.lua") end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.visual_targets"] = function() return load("lib/visual_targets.lua") end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.visual_sprites"] = function() return load("lib/visual_sprites.lua") end
package.preload["mods.FIRERED_KANTO_VISUALS.lib.visual_sprite_profile"] = function() return load("lib/visual_sprite_profile.lua") end

local ImageData = {}
ImageData.__index = ImageData
function ImageData.new(width, height)
  return setmetatable({ width = width, height = height, writes = 0 }, ImageData)
end
function ImageData:setPixel()
  self.writes = self.writes + 1
end
function ImageData:getPixel()
  return 0, 0, 0, 0
end

love = { image = { newImageData = ImageData.new } }

local Addresses = require("mods.FIRERED_KANTO_VISUALS.lib.addresses")
local VisualSprites = require("mods.FIRERED_KANTO_VISUALS.lib.visual_sprites")
local VisualSpriteProfile = require("mods.FIRERED_KANTO_VISUALS.lib.visual_sprite_profile")

local function check(condition, message)
  if not condition then error(message or "check failed", 2) end
end

local function lz77Zeros(size)
  local bytes = { string.char(0x10, size % 0x100, math.floor(size / 0x100) % 0x100,
    math.floor(size / 0x10000) % 0x100) }
  local produced = 0
  while produced < size do
    local actions, flag = {}, 0
    for bit = 7, 0, -1 do
      if produced >= size then break end
      local remaining = size - produced
      if produced > 0 and remaining >= 3 then
        local count = math.min(18, remaining)
        flag = flag + 2 ^ bit
        actions[#actions + 1] = string.char((count - 3) * 16, 0)
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

local function le16(value)
  return string.char(value % 0x100, math.floor(value / 0x100) % 0x100)
end

local function le32(value)
  return string.char(value % 0x100, math.floor(value / 0x100) % 0x100,
    math.floor(value / 0x10000) % 0x100, math.floor(value / 0x1000000) % 0x100)
end

local function replace(blob, offset, value)
  return blob:sub(1, offset) .. value .. blob:sub(offset + #value + 1)
end

local function tableRecords(count, pointer, size)
  return string.rep(le32(pointer) .. le16(size) .. le16(0), count)
end

local function syntheticRom()
  local spec = Addresses.revisions["e26ee0d44e809351c8ce2d73c7400cdd"].visuals
  local rom = string.rep("\0", Addresses.ROM_SIZE)
  rom = replace(rom, 0xBC, string.char(0))
  local gfxAddress = 0x08FF0000
  local paletteAddress = 0x08FF1000
  local gfx = lz77Zeros(0x800)
  local palette = lz77Zeros(32)
  local function put(address, value)
    rom = replace(rom, address - Addresses.ROM_BASE, value)
  end
  put(gfxAddress, gfx)
  put(paletteAddress, palette)
  put(spec.monFrontTable, tableRecords(440, gfxAddress, 0x800))
  put(spec.monBackTable, tableRecords(440, gfxAddress, 0x800))
  put(spec.monPaletteTable, tableRecords(440, paletteAddress, 0))
  put(spec.trainerFrontTable, tableRecords(148, gfxAddress, 0x800))
  put(spec.trainerPaletteTable, tableRecords(148, paletteAddress, 0))
  return rom
end

local decoded = VisualSprites.decode(syntheticRom())
check(decoded.revision.id == "firered_en_v10", "wrong visual source revision")
check(#decoded.pokemon == 151, "expected 151 imported Pokémon targets")
check(#decoded.trainers == 41, "expected 41 imported trainer targets")
check(decoded.assets["firered/generated/battle/front/bulbasaur.png"], "Bulbasaur front asset missing")
check(decoded.assets["firered/generated/battle/back/mew.png"], "Mew back asset missing")
check(decoded.assets["firered/generated/battle/trainers/opp_brock.png"], "Brock trainer asset missing")
check(decoded.assets["firered/generated/battle/front/bulbasaur.png"].width == 64,
  "imported Pokémon image has incorrect dimensions")

-- Visual patches must contain only asset paths and true-colour state, leaving
-- all Pokémon and trainer gameplay records unmodified.
do
  local pokemonBase = { baseStats = { hp = 45 }, types = { "GRASS", "POISON" }, spriteFront = "old-front" }
  local trainerBase = { name = "BROCK", parties = { {} }, pic = "old-trainer" }
  local pokemonPatches, trainerPatches = {}, {}
  local mod = {
    content = {
      pokemon = {
        get = function(_, id) return id == "BULBASAUR" and pokemonBase or { spriteFront = "base" } end,
        patch = function(_, id, patch) pokemonPatches[id] = patch end,
      },
      trainers = {
        get = function(_, id) return id == "OPP_BROCK" and trainerBase or nil end,
        patch = function(_, id, patch) trainerPatches[id] = patch end,
      },
    },
  }
  VisualSpriteProfile.applyGen1(mod, {
    pokemon = { { id = "BULBASAUR", front = "front.png", back = "back.png" } },
    trainers = { { id = "OPP_BROCK", pic = "brock.png" }, { id = "MISSING", pic = "skip.png" } },
  })
  check(pokemonPatches.BULBASAUR.spriteFront == "front.png"
    and pokemonPatches.BULBASAUR.spriteBack == "back.png"
    and pokemonPatches.BULBASAUR.trueColor == true,
    "Pokémon visual patch is incomplete")
  check(pokemonPatches.BULBASAUR.baseStats == nil and pokemonBase.baseStats.hp == 45,
    "Pokémon gameplay fields were changed")
  check(trainerPatches.OPP_BROCK.pic == "brock.png" and trainerPatches.OPP_BROCK.trueColor == true,
    "trainer visual patch is incomplete")
  check(trainerPatches.MISSING == nil and trainerBase.parties[1] ~= nil,
    "trainer gameplay fields were changed")
end

print("FireRed Kanto Visual Importer visual-sprite tests passed")
