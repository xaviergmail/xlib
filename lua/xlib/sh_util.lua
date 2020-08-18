--- @module xlib.utils
--
-- A set of useful utility functions that don't fit into a category of their own.

-- https://en.wikipedia.org/wiki/Double-precision_floating-point_format
local double_min = -(2^-53)
local double_max = (2^53)-1

--- Integer-safe tonumber
--
-- This function will return nil if the number to be converted
-- exceeds the integer-definable range of IEEE 754 doubles
-- @tparam string str String to be converted to number
-- @treturn[1] number The converted number, if the conversion is safe
-- @treturn[2] nil Nil if the conversion would lose integer precision
function XLIB.tonumber_s(str)
	local num = tonumber(str)
	if not num then return nil end

	if num < double_min or num > double_max then return nil end
	return num
end

--- Freezes an entity in place
--
-- This sets the entity's movetype to `MOVETYPE_NONE` and disables
-- motion on its physics object in order to avoid clientside prediction errors.
-- @tparam Entity ent Entity to freeze
-- @tparam[opt=false] bool no_children Set to true to *prevent* recursively freezing child entities
function XLIB.FreezeProp(ent, no_children)
	ent:SetMoveType(MOVETYPE_NONE)

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		for i=0, ent:GetPhysicsObjectCount()-1 do
			local phys = ent:GetPhysicsObjectNum(i)
			phys:EnableMotion(false)
		end
	end

	if not no_children then
		for k, v in ipairs(ent:GetChildren()) do
			XLIB.FreezeProp(v)
		end
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
