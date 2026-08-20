-- FireRed Kanto Visual Importer 0.1.0
--
-- This is deliberately a visual-only layer. It does not patch maps, collision,
-- warp data, events, NPCs, scripts, encounters, saves, or base-game mechanics.

local GameVersion = require("src.core.GameVersion")
local Cache = require("mods.FIRERED_KANTO_VISUALS.lib.cache")
local GeneralTileset = require("mods.FIRERED_KANTO_VISUALS.lib.general_tileset")
local VisualProfile = require("mods.FIRERED_KANTO_VISUALS.lib.visual_profile")
local VisualSprites = require("mods.FIRERED_KANTO_VISUALS.lib.visual_sprites")
local VisualSpriteProfile = require("mods.FIRERED_KANTO_VISUALS.lib.visual_sprite_profile")

return function(mod)
  local playing = GameVersion.get()
  if playing ~= "red" and playing ~= "blue" and playing ~= "yellow" then
    -- Gold has a distinct tileset and world-rendering contract. The importer
    -- stays inert rather than trying to apply a Gen 1 compatibility profile.
    return
  end

  local rom = assert(mod:read("baseroms/firered.gba"),
    "FireRed source ROM is unavailable. Import a supported ROM in Gen1Recomp's Imported Files panel.")

  local imported = GeneralTileset.decode(rom)
  local visualSprites = VisualSprites.decode(rom)

  Cache.installAssetBridge()
  Cache.putAtlas("firered/generated/tilesets/general.png", imported.atlas)
  for assetPath, imageData in pairs(visualSprites.assets) do
    Cache.putAtlas(assetPath, { imageData = imageData })
  end

  VisualProfile.applyGen1Outdoor(mod, imported)
  VisualSpriteProfile.applyGen1(mod, visualSprites)

  mod.events:on("game.ready", function(ev)
    -- The tileset override was applied during the merge phase. The event is
    -- retained only for a user-facing status record that is safe after game
    -- services initialize.
    if ev and ev.game then
      ev.game.fireredKantoVisuals = {
        revision = imported.revision.id,
        label = imported.revision.label,
      }
    end
  end)
end
