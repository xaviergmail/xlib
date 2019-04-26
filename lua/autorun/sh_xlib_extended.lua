if SERVER then
	if GetGlobalBool("xlib_extended") then
		AddCSLuaFile()
	else
		return
	end
end

require "xloader"

xloader("xlib_extended", function(f) include(f) end)