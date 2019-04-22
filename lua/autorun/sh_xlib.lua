XLib = XLib or {}

if SERVER then
	require "credentialstore"
end

require "xloader"

xloader("xlib", function(f) include(f) end)
