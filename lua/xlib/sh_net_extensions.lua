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

net.WriteRawVars = 
{
	[TYPE_STRING]		= function ( t, v )	net.WriteString( v )		end,
	[TYPE_NUMBER]		= function ( t, v )	net.WriteDouble( v )		end,
	[TYPE_TABLE]		= function ( t, v )	net.WriteTable( v )			end,
	[TYPE_BOOL]			= function ( t, v )	net.WriteBool( v )			end,
	[TYPE_ENTITY]		= function ( t, v )	net.WriteEntity( v )		end,
	[TYPE_VECTOR]		= function ( t, v )	net.WriteVector( v )		end,
	[TYPE_ANGLE]		= function ( t, v )	net.WriteAngle( v )			end,
	[TYPE_MATRIX]		= function ( t, v ) net.WriteMatrix( v )		end,
	[TYPE_COLOR]		= function ( t, v ) net.WriteColor( v )			end,
	[TYPE_DATA]			= net.WriteVars[TYPE_DATA],
}

function net.WriteRawType( v )
	local typeid = nil

	if IsColor( v ) then
		typeid = TYPE_COLOR
	else
		typeid = TypeID( v )
	end

	local wv = net.WriteRawVars[ typeid ]
	if ( wv ) then return wv( typeid, v ) end
	
	error( "net.WriteRawTypeRaw: Couldn't write " .. type( v ) .. " (type " .. typeid .. ")" )
end

-- Inspired by Dash
-- net.Ping(plys | msgname, [plys], ...values)
-- Nasty hack to maintain backwards compat of net.Ping(msg, plys)
-- Preferred use: net.Ping([plys], msgname, ...values)
function net.Ping(msg, ...)
	local plys = select(1, ...)
	if type(msg) == "Player" then
		msg, plys = plys, msg
	end

	net.Start(msg)

	local start = 1
	local cnt = select('#', ...)
	if type(plys) == "Player" or istable(plys) and #f.filter(f.pipe(type, f.apply(f.neq, "Player"))) > 0 then
		start = 2
	elseif SERVER then
		plys = nil
	end

	if cnt >= start then
		for i=start, cnt do
			net.WriteRawType(select(i, ...))
		end
	end


	if CLIENT then
		net.SendToServer()
	else
		if plys then
			net.Send(plys)
		else
			net.Broadcast()
		end
	end
end