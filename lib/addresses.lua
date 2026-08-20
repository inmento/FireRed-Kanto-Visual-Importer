-- FireRed Kanto Visual Importer: revision-specific source layout.
--
-- Every address below is a GBA ROM address. The bounded reader converts it to
-- a zero-based file offset only after checking that it falls inside the source
-- ROM. Values are derived from pret/pokefirered's published symbols branch.

local Addresses = {}

Addresses.ROM_BASE = 0x08000000
Addresses.ROM_SIZE = 0x01000000
Addresses.CACHE_SCHEMA = 1

Addresses.revisions = {
  ["e26ee0d44e809351c8ce2d73c7400cdd"] = {
    id = "firered_en_v10",
    label = "Pokémon FireRed English v1.0",
    general = {
      tiles = 0x08EA1D68,
      palettes = 0x08EA1B68,
      metatiles = 0x0829F6C8,
      attributes = 0x082A1EC8,
      header = 0x082D4A94,
    },
    visuals = {
      monFrontCoords = 0x082349CC,
      monFrontTable = 0x082350AC,
      monBackCoords = 0x08235E6C,
      monBackTable = 0x0823654C,
      monPaletteTable = 0x0823730C,
      trainerFrontTable = 0x0823957C,
      trainerPaletteTable = 0x08239A1C,
    },
  },
}

function Addresses.forMd5(md5)
  return Addresses.revisions[(md5 or ""):lower()]
end

return Addresses
