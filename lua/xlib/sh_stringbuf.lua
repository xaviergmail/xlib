stringbuf = {}
stringbuf.mt = {__index=stringbuf}

local function u(format)
	return function(data)
		return struct.unpack(format, data)
	end
end

local function b(num, data)
	return string.byte(data, 1, num)
end

-- These are all little-endian by default. Use stringbuf:Unpack for more flexibility
local Int8 =   function(d) return struct.unpack("b", d) end
local UInt8 =  function(d) return struct.unpack("B", d) end
local Int16 =  function(d) return struct.unpack("h", d) end
local UInt16 = function(d) return struct.unpack("H", d) end
local Int32 =  function(d) return struct.unpack("i", d) end
local UInt32 = function(d) return struct.unpack("I", d) end
local Int64 =  function(d) return struct.unpack("l", d) end
local UInt64 = function(d) return struct.unpack("L", d) end
local Float =  function(d) return struct.unpack("f", d) end
local Double = function(d) return struct.unpack("d", d) end
local MUserdata = {}

local sizes = {
	[Int8] = 8, [UInt8] = 8,
	[Int16] = 16, [UInt16] = 16,
	[Int32] = 32, [UInt32] = 32,
	[Int64] = 64, [UInt64] = 64,
	[Float] = 32, [Double] = 64,
	[Vector] = 32*3,    -- 3 floats
	[Color] = 4*8,      -- 4 bytes
	[MUserdata] = 32*4, -- 4 floats
}

function sizeof(type)
	return sizes[type]
end

function stringbuf.New(str)
	local self = {}
	self.data = str
	self.pos = 0
	self.size = #str

	return setmetatable(self, stringbuf.mt)
end

function stringbuf:Seek(pos)
	-- Operate on zero-based index
	self.pos = pos-1
end

function stringbuf:Advance(move)
	self.pos = self.pos + move
end

function stringbuf:Tell()
	return self.pos
end

function stringbuf:EOF()
	return self.pos+1 == self.size
end

function stringbuf:Read(numbytes)
	local ret = self.data:sub(self.pos+1, self.pos+numbytes)
	self:Advance(numbytes)
	return ret
end

function stringbuf:Unpack(format, len)
	local data = self:Read(len)
	return struct.unpack(format, data)
end

function stringbuf:ReadInt8() return Int8(self:Read(1)) end
function stringbuf:ReadUInt8() return UInt8(self:Read(1)) end

function stringbuf:ReadInt16() return Int16(self:Read(2)) end
function stringbuf:ReadUInt16() return UInt16(self:Read(2)) end

function stringbuf:ReadInt32() return Int32(self:Read(4)) end
function stringbuf:ReadUInt32() return UInt32(self:Read(4)) end

function stringbuf:ReadInt64() return Int64(self:Read(8)) end
function stringbuf:ReadUInt64() return UInt64(self:Read(8)) end

function stringbuf:ReadFloat() return Float(self:Read(4)) end
function stringbuf:ReadDouble() return Double(self:Read(8)) end

-- Redundant?
function stringbuf:ReadString(count)
	return self:Read(count)
end

function stringbuf:ReadStringZ()
	local c = 0
	local str = ""
	repeat
		local char = self:Read(1)
		str = str .. char
		c = string.byte(char)
	until c == 0

	return str
end


function stringbuf:ReadVector()
	local x, z, y = self:Unpack("fff", sizeof(Vector)/8)
	return Vector(x, y, z)
end

function stringbuf:ReadColor()
	local r, g, b, a = self:Unpack("BBB", sizeof(Color)/8)
	return Color(r, g, b, a)
end

function stringbuf:ReadMUserdata()
	return {self:Unpack("ffff", sizeof(MUserdata)/8)}
end

print("stringbuf loaded"..CurTime())
