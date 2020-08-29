TYPE_DATA = 105  -- Random magic number
TYPE_DATAMT = TYPE_DATAMT or { __tostring = function(t) return t.str end }

function net.MakeData(str)
	return setmetatable({str=str}, TYPE_DATAMT)
end

local genv = _G
local fenv = setmetatable({
	TypeID = function(val)
		if getmetatable(val) == TYPE_DATAMT then
			return TYPE_DATA
		end

		return genv.TypeID(val)
	end,
}, {__index=_G, __newindex=_G})

XLIB.PostInitialize(function()
	setfenv(net.WriteType, fenv)
	setfenv(net.ReadType, fenv)
end)

function net.WriteCompressed(str)
	if getmetatable(str) == TYPE_DATAMT then
		str = tostring(str)
	end

	local compressed = util.Compress(str)
	local len = #(compressed or {})

	if not compressed or not len then
		compressed, len = "", 0
	end

	net.WriteUInt(len, 32)
	net.WriteData(compressed, len)
end

function net.ReadCompressed()
	local len = net.ReadUInt(32)
	local data = net.ReadData(len)

	return util.Decompress(data)
end

net.WriteVars[TYPE_DATA] = function(t, v) net.WriteUInt(t, 8) net.WriteCompressed(v) end
net.ReadVars[TYPE_DATA] = function() return net.ReadCompressed() end

-- Inspired by Dash
function net.Ping(msg, plys)
	net.Start(msg)
	if CLIENT then
		net.SendToServer()
	else
		net.Send(plys)
	end
end