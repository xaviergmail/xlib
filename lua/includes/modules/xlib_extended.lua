if SERVER then
	if XLIB.Extended then
		AddCSLuaFile()
	else
		return
	end
end
xloader("xlib_extended", function(f) include(f) end)

function IsTestServer()
	return GetGlobalBool("development_mode") and game.GetIPAddress():Split(":")[2] == "13337"
end
