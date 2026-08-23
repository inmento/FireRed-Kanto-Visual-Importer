local VisualSpriteProfile = {}

local function fail(message)
  error("FireRed importer: " .. message, 2)
end

-- FireRed battle sheets are 64×64 pixels. Gen 1's native front pictures draw
-- at 1× and its 32×32 back pictures draw at 2×, so applying the native back
-- default to a 64×64 FireRed sheet doubles it to 128×128. Use the documented
-- path registry rather than changing decoder pixels or Pokémon mechanics.
local FIRERED_FRONT_SCALE = 0.875 -- fit the classic 7×7 (56px) enemy slot
local FIRERED_BACK_SCALE = 1.0    -- preserve the classic 64px player footprint

local function scaleRecordId(entry, side)
  return "firered_" .. entry.id:lower() .. "_" .. side
end

function VisualSpriteProfile.applyGen1(mod, decoded)
  assert(decoded and type(decoded.pokemon) == "table" and type(decoded.trainers) == "table",
    "FireRed importer: decoded visual sprites are missing")

  local scales = mod.content.battle_sprite_scales
  if not (scales and type(scales.register) == "function") then
    fail("battle sprite scale registry is unavailable; update Gen1Recomp before enabling FireRed battle art")
  end

  for _, entry in ipairs(decoded.pokemon) do
    local base = mod.content.pokemon:get(entry.id)
    if not base then fail("base Pokémon record is unavailable: " .. entry.id) end
    -- This patches visual fields only. Existing base stats, types, moves,
    -- evolutions, cry, icons, catches, encounters, and mechanics remain intact.
    mod.content.pokemon:patch(entry.id, {
      spriteFront = entry.front,
      spriteBack = entry.back,
      trueColor = true,
    })
    scales:register(scaleRecordId(entry, "front"), {
      path = entry.front,
      scale = FIRERED_FRONT_SCALE,
    })
    scales:register(scaleRecordId(entry, "back"), {
      path = entry.back,
      scale = FIRERED_BACK_SCALE,
    })
  end

  for _, entry in ipairs(decoded.trainers) do
    local base = mod.content.trainers:get(entry.id)
    if base then
      -- Some Gen1 trainer records intentionally share an existing portrait. A
      -- missing target is skipped rather than causing the visual layer to alter
      -- any trainer list, party, name, AI, money, text, or battle behavior.
      mod.content.trainers:patch(entry.id, {
        pic = entry.pic,
        trueColor = true,
      })
    end
  end
end

return VisualSpriteProfile
