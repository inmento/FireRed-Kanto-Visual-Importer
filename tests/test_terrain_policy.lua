local ROOT = "/home/ubuntu/firered-kanto-visual-importer"

local function check(condition, message)
  if not condition then error(message or "check failed", 2) end
end

local function run(playing, terrainPreview)
  local calls = {
    cacheInstall = 0,
    cachePuts = {},
    terrainDecode = 0,
    terrainApply = 0,
    spriteDecode = 0,
    spriteApply = 0,
    reads = 0,
  }

  package.loaded["src.core.GameVersion"] = nil
  package.loaded["mods.FIRERED_KANTO_VISUALS.lib.cache"] = nil
  package.loaded["mods.FIRERED_KANTO_VISUALS.lib.general_tileset"] = nil
  package.loaded["mods.FIRERED_KANTO_VISUALS.lib.visual_profile"] = nil
  package.loaded["mods.FIRERED_KANTO_VISUALS.lib.visual_sprites"] = nil
  package.loaded["mods.FIRERED_KANTO_VISUALS.lib.visual_sprite_profile"] = nil

  package.preload["src.core.GameVersion"] = function()
    return { get = function() return playing end }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.cache"] = function()
    return {
      installAssetBridge = function() calls.cacheInstall = calls.cacheInstall + 1 end,
      putAtlas = function(path) calls.cachePuts[#calls.cachePuts + 1] = path end,
    }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.general_tileset"] = function()
    return {
      decode = function(rom)
        calls.terrainDecode = calls.terrainDecode + 1
        check(rom == "verified-rom", "terrain decoder received wrong ROM")
        return { atlas = { imageWidth = 1, imageHeight = 1, tilesPerRow = 1, blocks = {} } }
      end,
    }
  end
  package.preload["mods.FIRERED_KANTO_VISUALS.lib.visual_profile"] = function()
    return {
      applyGen1Outdoor = function(_, imported)
        calls.terrainApply = calls.terrainApply + 1
        check(imported and imported.atlas, "terrain profile received no atlas")
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
        check(sprites and sprites.revision, "sprite profile received no decoded data")
      end,
    }
  end

  local entry = assert(loadfile(ROOT .. "/main.lua"))()
  local defined
  local ready
  local mod = {
    options = {
      define = function(_, rows) defined = rows end,
      get = function(_, key)
        check(key == "terrain_preview", "unexpected option key")
        return terrainPreview
      end,
    },
    read = function(_, path)
      calls.reads = calls.reads + 1
      check(path == "baseroms/firered.gba", "unexpected source path")
      return "verified-rom"
    end,
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

-- The default is intentionally safe: imported battle artwork stays enabled,
-- while the incompatible numeric terrain substitution is not applied.
do
  local calls, defined, ready = run("red", false)
  check(defined and #defined == 1 and defined[1].key == "terrain_preview",
    "terrain preview option was not defined")
  check(defined[1].default == false, "terrain preview must default off")
  check(calls.reads == 1 and calls.spriteDecode == 1 and calls.spriteApply == 1,
    "safe mode must still import FireRed battle visuals")
  check(calls.terrainDecode == 0 and calls.terrainApply == 0,
    "safe mode must not replace collision-aligned Gen 1 terrain")
  check(calls.cacheInstall == 1 and #calls.cachePuts == 1,
    "safe mode must install only the battle-asset cache entry")
  local game = {}
  ready({ game = game })
  check(game.fireredKantoVisuals and game.fireredKantoVisuals.terrainPreview == false,
    "safe mode status marker is incorrect")
end

-- The original terrain profile remains available only to users who explicitly
-- turn on its diagnostic preview option.
do
  local calls, _, ready = run("yellow", true)
  check(calls.terrainDecode == 1 and calls.terrainApply == 1,
    "enabled terrain preview did not apply the diagnostic terrain profile")
  check(#calls.cachePuts == 2,
    "enabled terrain preview must cache terrain and battle assets")
  local game = {}
  ready({ game = game })
  check(game.fireredKantoVisuals and game.fireredKantoVisuals.terrainPreview == true,
    "preview mode status marker is incorrect")
end

-- Non-Gen 1 targets stay entirely inert and must not request source data.
do
  local calls, defined = run("gold", false)
  check(defined == nil and calls.reads == 0 and calls.spriteDecode == 0,
    "Gold must remain outside the importer scope")
end

print("FireRed Kanto Visual Importer terrain-policy tests passed")
