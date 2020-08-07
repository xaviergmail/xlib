--- @module xlib.utils
--
-- A set of useful utility functions that don't fit into a category of their own.


--- Freezes an entity in place
--
-- This sets the entity's movetype to `MOVETYPE_NONE` and disables
-- motion on its physics object in order to avoid clientside prediction errors.
-- @tparam Entity ent Entity to freeze
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

--- Serializes a Color object into an integer
--
-- This is a useful way to store a Color object in binary format
-- as it only uses one double, opposed to 4 (Or god forbid a String)
-- @tparam Color color Color to convert to an int
-- @treturn number The color object represented as an integer
function XLIB.ColorToInt(color)
	return bit.bor(
		bit.lshift(color.a, ashift),
		bit.lshift(color.r, rshift),
		bit.lshift(color.g, gshift),
		bit.lshift(color.b, bshift)
	)
end

--- Deserializes an integer into a Color object
--
-- @see XLIB.ColorToInt
-- @tparam number int Integer to convert to a Color object
-- @treturn Color
function XLIB.IntToColor(int)
	local a, r, g, b =
		bit.rshift(bit.band(int, amask), ashift),
		bit.rshift(bit.band(int, rmask), rshift),
		bit.rshift(bit.band(int, gmask), gshift),
		bit.rshift(bit.band(int, bmask), bshift)

	return Color(r, g, b, a)
end

--- Clamps all values of a color object between 0-255
--
-- @warn This modifies the color object passed to it rather than creating a copy!
-- @tparam Color color The color object to clamp
-- @tparam bool[opt=false] noalpha Forces the alpha channel to 255 if true
-- @treturn Color The color object passed as the first argument
function XLIB.SafeColor(color, noalpha)
	color.r = math.Clamp(color.r, 0, 255)
	color.g = math.Clamp(color.g, 0, 255)
	color.b = math.Clamp(color.b, 0, 255)
	color.a = noalpha and 255 or math.Clamp(color.a, 0, 255)
	return color
end

--- Shortcut for XLIB.SafeColor(..., true)
--
-- Clamps all the values of a color object between 0-255 and forces the alpha to 255
-- @warn This modifies the color object passed to it rather than creating a copy!
-- @tparam Color color The color object to clamp
-- @see XLIB.SafeColor
function XLIB.SafeColorNoAlpha(color)
	return XLIB.SafeColor(color, true)
end
