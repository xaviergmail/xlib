if SERVER then
	if XLIB.Extended then
		AddCSLuaFile()
	else
		return
	end
end
xloader("xlib_extended", function(f) include(f) end)