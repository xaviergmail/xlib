XLIB.Extended = true

if SERVER then
	if XLIB.Extended then
		AddCSLuaFile()
	else
		return
	end
end

xloader("xlib_extended", function(f) include(f) end)

local devports = {
	["13337"] = true,
	["13338"] = true,
}
function IsTestServer()
	return GetGlobalBool("development_mode") and devports[game.GetIPAddress():Split(":")[2]]
end
