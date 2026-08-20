local VisualSpriteProfile = {}

local function fail(message)
  error("FireRed importer: " .. message, 2)
end

function VisualSpriteProfile.applyGen1(mod, decoded)
  assert(decoded and type(decoded.pokemon) == "table" and type(decoded.trainers) == "table",
    "FireRed importer: decoded visual sprites are missing")

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
