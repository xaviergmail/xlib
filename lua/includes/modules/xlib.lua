--- Xavier's Library
--
-- This documentation is a work-in-progress. Feel free to submit a pull
-- request if you'd like to contribute to it! The documentation uses LDoc.
-- @module XLIB


AddCSLuaFile()
_MODULES.xlib = true

require "xloader"
xloader("xlib", function(f) include(f) end)

if SERVER then
	require "credentialstore"
end

local extended = "xlib/xlib_extended.lua"
if SERVER or file.Exists(extended, "LUA") then
	include(extended)
end
