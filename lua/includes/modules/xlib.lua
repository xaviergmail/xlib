AddCSLuaFile()
_MODULES.xlib = true

require "xloader"
xloader("xlib", function(f) include(f) end)

if SERVER then
	require "credentialstore"
end

if SERVER or file.Exists("includes/modules/xlib_extended.lua", "LUA") then
	require "xlib_extended"
end
