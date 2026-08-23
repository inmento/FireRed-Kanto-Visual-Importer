local engine = "/home/ubuntu/reference_gen1recomp023_source"
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local Manifest = require("src.mods.Manifest")
local raw = {
  id = "FIRERED_KANTO_VISUALS",
  name = "FireRed Kanto Visual Importer",
  version = "0.1.5",
  api = 2,
  entry = "main.lua",
  profile = "overhaul",
  category = "GRAPHICS",
  game_version = ">=0.2.3 <1.0.0",
  priority = 160,
  permissions = { "engine_internals" },
  github = "inmento/FireRed-Kanto-Visual-Importer",
  dependencies = {},
  optional_dependencies = {},
  conflicts = {},
  description = "Visual-only FireRed battle-visual importer with explicit diagnostic terrain preview.",
  required_imports = {
    {
      id = "firered_rom",
      name = "Pokémon FireRed (English) ROM",
      description = "English FireRed v1.0 only.",
      file = "firered.gba",
      format = "raw",
      size = 16777216,
      md5 = {
        "e26ee0d44e809351c8ce2d73c7400cdd",
      },
    },
  },
}

local parsed = Manifest.validate(raw, "/test/FIRERED_KANTO_VISUALS")
assert(parsed.id == "FIRERED_KANTO_VISUALS")
assert(parsed.profile == "overhaul")
assert(parsed.permissionSet.engine_internals)
assert(#parsed.required_imports == 1)
assert(parsed.required_imports[1].size == 16777216)
assert(#parsed.required_imports[1].md5 == 1)
assert(parsed.games and #parsed.games > 0)
print("FireRed Kanto Visual Importer manifest passed the engine validator")
