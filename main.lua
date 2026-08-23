-- FireRed Kanto Visual Importer 0.3.0-rc.7
--
-- One self-contained visual pipeline:
--   1. verified local FireRed ROM reader;
--   2. deterministic semantic tile converter and tile-lock validator;
--   3. map-specific Gen 1 visual profile applicator.
--
-- No FireRed ROM, extracted art, generated atlas, map layout, collision, warp,
-- event, NPC, script, encounter, save, or gameplay data is included in this
-- public mod. Runtime profiles change visual tiles only and retain the exact
-- existing Gen 1 map geometry and gameplay semantics.

local GameVersion = require("src.core.GameVersion")
local Cache = require("mods.FIRERED_KANTO_VISUALS.lib.cache")
local Profiles = require("mods.FIRERED_KANTO_VISUALS.lib.semantic_profiles")
local Converter = require("mods.FIRERED_KANTO_VISUALS.lib.semantic_converter")
local SemanticProfile = require("mods.FIRERED_KANTO_VISUALS.lib.semantic_profile")
local VisualSprites = require("mods.FIRERED_KANTO_VISUALS.lib.visual_sprites")
local VisualSpriteProfile = require("mods.FIRERED_KANTO_VISUALS.lib.visual_sprite_profile")

local function buildProfileVariants(profile, rom, baseMap, baseTileset, gameData)
  local converted = Converter.build(profile, rom, baseMap, baseTileset, { gameData = gameData })
  local variants = profile.source.paletteVariants or {}
  for _, mode in ipairs(variants) do
    local variant = Converter.build(profile, rom, baseMap, baseTileset, {
      gameData = gameData,
      basePaletteMode = mode,
    })
    if variant.imageWidth ~= converted.imageWidth or variant.imageHeight ~= converted.imageHeight
       or variant.tilesPerRow ~= converted.tilesPerRow or #variant.blocks ~= #converted.blocks
       or #variant.mapBlocks ~= #converted.mapBlocks then
      error("FireRed importer: palette variant changed the semantic profile projection", 0)
    end
    converted.imageVariants = converted.imageVariants or {}
    converted.imageVariants[mode] = variant.imageData
  end
  return converted
end

return function(mod)
  local playing = GameVersion.get()
  if playing ~= "red" and playing ~= "blue" and playing ~= "yellow" then
    -- Gold has a different world-rendering contract. This Gen 1 map-profile
    -- pipeline remains inert rather than applying a partial compatibility shim.
    return
  end

  mod.options:define({
    {
      key = "map_visuals",
      label = "FR MAP VISUALS",
      type = "toggle",
      default = true,
    },
  })

  local rom = assert(mod:read("baseroms/firered.gba"),
    "FireRed source ROM is unavailable. Import a supported ROM in Gen1Recomp's Imported Files panel.")
  local mapVisualsEnabled = mod.options:get("map_visuals") ~= false
  local visualSprites = VisualSprites.decode(rom)
  local appliedProfiles, profileErrors = {}, {}

  Cache.installAssetBridge()
  if mapVisualsEnabled then
    for _, profile in Profiles.each() do
      local baseMap = mod.content.maps:get(profile.map)
      local baseTileset = mod.content.tilesets:get(profile.expectedTarget.tileset)
      -- Generated profile atlases contain both FireRed true-colour pixels and
      -- copied Gen 1 base pixels. Supply live game data when it is already
      -- available so the converter can pre-bake base tiles with the same GBC
      -- palette groups the renderer would normally apply to OVERWORLD.
      local game = mod.game
      local ok, converted = pcall(buildProfileVariants, profile, rom, baseMap, baseTileset,
        game and game.data)
      if ok then
        SemanticProfile.apply(mod, profile, converted)
        appliedProfiles[#appliedProfiles + 1] = profile.id
      else
        -- Fail closed. A malformed/unsupported profile leaves that native map
        -- completely unchanged instead of falling back to numeric block swaps.
        profileErrors[#profileErrors + 1] = profile.id .. ": " .. tostring(converted)
        print("FireRed importer: skipped semantic profile " .. profile.id .. " — " .. tostring(converted))
      end
    end
  end

  -- A map-visual request that produced no profiles is not a harmless native
  -- fallback: it means every requested profile was rejected. Surface the first
  -- bounded-reader/converter reason in the Mod Manager instead of silently
  -- presenting native terrain as though FireRed map visuals were active.
  if mapVisualsEnabled and #appliedProfiles == 0 and #profileErrors > 0 then
    error("FireRed importer: no map visual profiles were applied. "
      .. "First diagnostic: " .. profileErrors[1], 0)
  end

  for assetPath, imageData in pairs(visualSprites.assets) do
    Cache.putAtlas(assetPath, { imageData = imageData })
  end
  VisualSpriteProfile.applyGen1(mod, visualSprites)

  mod.events:on("game.ready", function(ev)
    -- Content changes occur during the merge phase. This is a diagnostic status
    -- marker only; it is safe after game services initialize.
    if ev and ev.game then
      ev.game.fireredKantoVisuals = {
        revision = visualSprites.revision.id,
        label = visualSprites.revision.label,
        mapVisuals = mapVisualsEnabled,
        profiles = appliedProfiles,
        profileErrors = profileErrors,
      }
    end
  end)
end
