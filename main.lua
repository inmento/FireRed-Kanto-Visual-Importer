-- FireRed Kanto Visual Importer 0.1.5
--
-- This layer imports player-provided FireRed visual assets without changing
-- maps, collision, warps, events, NPCs, scripts, encounters, saves, or game
-- mechanics. FireRed terrain previews are opt-in until semantic Gen 1 block
-- profiles can align visible doors, paths, ledges, and water with live maps.

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

  -- FireRed's 16×16 metatiles become 32×32 Gen1Recomp blocks. A simple numeric
  -- block substitution cannot preserve the meaning of Gen 1's block grid, so
  -- visible FireRed doors and paths can disagree with preserved Gen 1 warps and
  -- collision. Keep that prototype available for diagnostics only; new and
  -- updated installs default to collision-aligned base terrain.
  mod.options:define({
    {
      key = "terrain_preview",
      label = "FR TERRAIN PREVIEW",
      type = "toggle",
      default = false,
    },
  })

  local rom = assert(mod:read("baseroms/firered.gba"),
    "FireRed source ROM is unavailable. Import a supported ROM in Gen1Recomp's Imported Files panel.")

  local terrainPreview = mod.options:get("terrain_preview") == true
  local imported
  if terrainPreview then
    imported = GeneralTileset.decode(rom)
  end
  local visualSprites = VisualSprites.decode(rom)

  Cache.installAssetBridge()
  if imported then
    Cache.putAtlas("firered/generated/tilesets/general.png", imported.atlas)
    VisualProfile.applyGen1Outdoor(mod, imported)
  end
  for assetPath, imageData in pairs(visualSprites.assets) do
    Cache.putAtlas(assetPath, { imageData = imageData })
  end
  VisualSpriteProfile.applyGen1(mod, visualSprites)

  mod.events:on("game.ready", function(ev)
    -- Content changes occur during the merge phase. This record is only a
    -- user-facing status marker that is safe after game services initialize.
    if ev and ev.game then
      ev.game.fireredKantoVisuals = {
        revision = visualSprites.revision.id,
        label = visualSprites.revision.label,
        terrainPreview = terrainPreview,
      }
    end
  end)
end
