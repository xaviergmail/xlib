function XLIB.FreezeProp(ent)
	ent:SetMoveType(MOVETYPE_NONE)
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end
end

local ashift, rshift, gshift, bshift = 8*4, 8*3, 8*2, 8*1

local amask = bit.lshift(0xFF, ashift)
local rmask = bit.lshift(0xFF, rshift)
local gmask = bit.lshift(0xFF, gshift)
local bmask = bit.lshift(0xFF, bshift)

function XLIB.ColorToInt(color)
	return bit.bor(
		bit.lshift(color.a, ashift),
		bit.lshift(color.r, rshift),
		bit.lshift(color.g, gshift),
		bit.lshift(color.b, bshift)
	)
end

function XLIB.IntToColor(int)
	local a, r, g, b =
		bit.rshift(bit.band(int, amask), ashift),
		bit.rshift(bit.band(int, rmask), rshift),
		bit.rshift(bit.band(int, gmask), gshift),
		bit.rshift(bit.band(int, bmask), bshift)

	return Color(r, g, b, a)
end

function XLIB.SafeColor(color, noalpha)
	color.r = math.Clamp(color.r, 0, 255)
	color.g = math.Clamp(color.g, 0, 255)
	color.b = math.Clamp(color.b, 0, 255)
	color.a = noalpha and 255 or math.Clamp(color.a, 0, 255)
	return color
end

function XLIB.SafeColorNoAlpha(color)
	return XLIB.SafeColor(color, true)
end
