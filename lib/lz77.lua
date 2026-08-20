local Lz77 = {}

local function fail(message)
  error("FireRed importer: invalid LZ77 stream: " .. message, 2)
end

-- Decodes the standard GBA type-0x10 stream at a zero-based ROM offset.
-- Returns the decompressed bytes and the offset immediately after the stream.
function Lz77.decode(reader, offset, label)
  label = label or "compressed graphics"
  if reader:u8(offset, label .. " header") ~= 0x10 then
    fail(label .. " does not have a type-0x10 header")
  end

  local outputSize = reader:u24(offset + 1, label .. " output size")
  if outputSize < 1 or outputSize > 0x20000 then
    fail(label .. " declares an unsafe output size")
  end

  local out = {}
  local outLength = 0
  local cursor = offset + 4

  local function emit(byte)
    outLength = outLength + 1
    if outLength > outputSize then
      fail(label .. " expands beyond its declared size")
    end
    out[outLength] = string.char(byte)
  end

  while outLength < outputSize do
    local flags = reader:u8(cursor, label .. " flag byte")
    cursor = cursor + 1
    for bit = 7, 0, -1 do
      if outLength >= outputSize then break end
      if math.floor(flags / (2 ^ bit)) % 2 == 0 then
        emit(reader:u8(cursor, label .. " literal"))
        cursor = cursor + 1
      else
        local a = reader:u8(cursor, label .. " copy length")
        local b = reader:u8(cursor + 1, label .. " copy distance")
        cursor = cursor + 2
        local length = math.floor(a / 16) + 3
        local distance = (a % 16) * 0x100 + b + 1
        if distance > outLength then
          fail(label .. " references bytes before the output begins")
        end
        for _ = 1, length do
          local sourceIndex = outLength - distance + 1
          local source = out[sourceIndex]
          if not source then fail(label .. " has an invalid copy source") end
          emit(source:byte())
          if outLength >= outputSize then break end
        end
      end
    end
  end

  if outLength ~= outputSize then
    fail(label .. " ended at an unexpected output length")
  end
  return table.concat(out), cursor
end

return Lz77
