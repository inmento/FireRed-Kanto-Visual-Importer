local ROOT = "/home/ubuntu/firered-kanto-visual-importer"

local function check(condition, message)
  if not condition then error(message or "check failed", 2) end
end

local function run(playing, enabled, failingProfile)
  local calls = {
    cacheInstall = 0,
    cachePuts = {},
    spriteDecode = 0,
    spriteApply = 0,
    build = {},
    apply = {},
    reads = 0,
  }

  local moduleNames = {
    "src.core.GameVersion",
    "mods.FIRERED_KANTO_VISUALS.lib.cache",
    "mods.FIRERED_KANTO_VISUALS.lib.semantic_profiles",
    "mods.FIRERED_KANTO_VISUALS.lib.semantic_converter",
    "mods.FIRERED_KANTO_VISUALS.lib.semantic_profile",
    "mods.FIRERED_KANTO_VISUALS.lib.visual_sprites",
    "mods.FIRERED_KANTO_VISUALS.lib.visual_sprite_profile",
  }
  for _, name in ipairs(moduleNames) do package.loaded[name] = nil end

  local profiles = {
    {
      id = "FIRERED_PALLET_TOWN", map = "PALLET_TOWN",
      expectedTarget = { tileset = "OVERWORLD" },
    },
    {
      id = "FIRERED_REDS_HOUSE_1F", map = "REDS_HOUSE_1F",
      expectedTarget = { tileset = "REDS_HOUSE_1" },
    },
  }

  package.preload["src.core.GameVersion"] = function()
    return { get = function() return playing end }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.cache"] = function()
    return {
      installAssetBridge = function() calls.cacheInstall = calls.cacheInstall + 1 end,
      putAtlas = function(path) calls.cachePuts[#calls.cachePuts + 1] = path end,
    }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.semantic_profiles"] = function()
    return { each = function() return ipairs(profiles) end }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.semantic_converter"] = function()
    return {
      build = function(profile, rom, map, tileset)
        calls.build[#calls.build + 1] = { id = profile.id, rom = rom, map = map, tileset = tileset }
        if profile.id == failingProfile then error("profile checksum mismatch") end
        return { imageData = {}, profile = profile }
      end,
    }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.semantic_profile"] = function()
    return {
      apply = function(_, profile, converted)
        check(converted and converted.profile == profile, "profile apply received wrong conversion")
        calls.apply[#calls.apply + 1] = profile.id
      end,
    }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.visual_sprites"] = function()
    return {
      decode = function(rom)
        calls.spriteDecode = calls.spriteDecode + 1
        check(rom == "verified-rom", "sprite decoder received wrong ROM")
        return {
          revision = { id = "firered_en_v10", label = "FireRed English v1.0" },
          assets = { ["firered/generated/battle/front/test.png"] = {} },
          pokemon = {}, trainers = {},
        }
      end,
    }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.visual_sprite_profile"] = function()
    return {
      applyGen1 = function(_, sprites)
        calls.spriteApply = calls.spriteApply + 1
        check(sprites and sprites.revision, "sprite profile received no data")
      end,
    }
  end

  local entry = assert(loadfile(ROOT .. "/main.lua"))()
  local defined, ready
  local maps = {
    PALLET_TOWN = { id = "PALLET_TOWN" },
    REDS_HOUSE_1F = { id = "REDS_HOUSE_1F" },
  }
  local tilesets = {
    OVERWORLD = { id = "OVERWORLD" },
    REDS_HOUSE_1 = { id = "REDS_HOUSE_1" },
  }
  local mod = {
    options = {
      define = function(_, rows) defined = rows end,
      get = function(_, key)
        check(key == "map_visuals", "unexpected option key")
        return enabled
      end,
    },
    read = function(_, path)
      calls.reads = calls.reads + 1
      check(path == "baseroms/firered.gba", "unexpected ROM path")
      return "verified-rom"
    end,
    content = {
      maps = { get = function(_, id) return maps[id] end },
      tilesets = { get = function(_, id) return tilesets[id] end },
    },
    events = {
      on = function(_, name, callback)
        check(name == "game.ready", "unexpected event")
        ready = callback
      end,
    },
  }
  entry(mod)
  return calls, defined, ready
end

-- The standard configuration applies the two explicit semantic profiles and
-- leaves the normal FireRed battle-art import active.
do
  local calls, defined, ready = run("red", true)
  check(defined and #defined == 1 and defined[1].key == "map_visuals",
    "map-visual option was not defined")
  check(defined[1].default == true, "map visuals must default on")
  check(calls.reads == 1 and calls.spriteDecode == 1 and calls.spriteApply == 1,
    "standard import must retain the FireRed battle-art path")
  check(#calls.build == 2 and calls.build[1].id == "FIRERED_PALLET_TOWN"
      and calls.build[2].id == "FIRERED_REDS_HOUSE_1F",
    "standard import did not build both initial semantic profiles")
  check(#calls.apply == 2, "both completed semantic profiles must be applied")
  local game = {}
  ready({ game = game })
  check(game.fireredKantoVisuals and game.fireredKantoVisuals.mapVisuals == true,
    "map-visual status marker is incorrect")
  check(#game.fireredKantoVisuals.profiles == 2 and #game.fireredKantoVisuals.profileErrors == 0,
    "successful profiles were not recorded accurately")
end

-- Players may turn off map visuals without disabling imported battle art.
do
  local calls, _, ready = run("yellow", false)
  check(calls.spriteDecode == 1 and calls.spriteApply == 1,
    "disabling maps must not disable battle visuals")
  check(#calls.build == 0 and #calls.apply == 0,
    "disabled map visuals must not build or apply profiles")
  local game = {}
  ready({ game = game })
  check(game.fireredKantoVisuals.mapVisuals == false,
    "disabled map-visual status marker is incorrect")
end

-- A bad profile must fail closed: that map remains native while independent
-- validated profiles continue. It must never restore numeric block substitution.
do
  local calls, _, ready = run("blue", true, "FIRERED_REDS_HOUSE_1F")
  check(#calls.build == 2 and #calls.apply == 1 and calls.apply[1] == "FIRERED_PALLET_TOWN",
    "failed profile did not leave only the independent valid profile active")
  local game = {}
  ready({ game = game })
  check(#game.fireredKantoVisuals.profiles == 1 and #game.fireredKantoVisuals.profileErrors == 1,
    "failure-closed diagnostics are incorrect")
end

-- Gen 2 remains entirely outside this Gen 1 terrain pipeline.
do
  local calls, defined = run("gold", true)
  check(defined == nil and calls.reads == 0 and calls.spriteDecode == 0,
    "Gold must remain outside the Gen 1 map pipeline")
end

print("FireRed Kanto Visual Importer map-pipeline tests passed")
