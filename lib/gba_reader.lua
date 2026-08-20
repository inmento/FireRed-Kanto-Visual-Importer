local Reader = {}
Reader.__index = Reader

local function fail(message, level)
  error("FireRed importer: " .. message, (level or 1) + 1)
end

function Reader.new(data, romBase)
  assert(type(data) == "string", "FireRed importer: ROM data must be a string")
  return setmetatable({
    data = data,
    size = #data,
    romBase = romBase or 0x08000000,
  }, Reader)
end

function Reader:check(offset, count, label)
  offset = assert(tonumber(offset), "FireRed importer: invalid ROM offset")
  count = assert(tonumber(count), "FireRed importer: invalid byte count")
  if offset < 0 or count < 0 or offset + count > self.size then
    fail((label or "read") .. " is outside the verified ROM", 2)
  end
  return offset
end

function Reader:offsetFromAddress(address, label)
  address = assert(tonumber(address), "FireRed importer: invalid GBA address")
  local offset = address - self.romBase
  self:check(offset, 1, label or "GBA address")
  return offset
end

function Reader:u8(offset, label)
  self:check(offset, 1, label)
  return self.data:byte(offset + 1)
end

function Reader:u16(offset, label)
  self:check(offset, 2, label)
  local lo, hi = self.data:byte(offset + 1, offset + 2)
  return lo + hi * 0x100
end

function Reader:u24(offset, label)
  self:check(offset, 3, label)
  local a, b, c = self.data:byte(offset + 1, offset + 3)
  return a + b * 0x100 + c * 0x10000
end

function Reader:u32(offset, label)
  self:check(offset, 4, label)
  local a, b, c, d = self.data:byte(offset + 1, offset + 4)
  return a + b * 0x100 + c * 0x10000 + d * 0x1000000
end

function Reader:bytes(offset, count, label)
  self:check(offset, count, label)
  return self.data:sub(offset + 1, offset + count)
end

function Reader:addressBytes(address, count, label)
  return self:bytes(self:offsetFromAddress(address, label), count, label)
end

return Reader
