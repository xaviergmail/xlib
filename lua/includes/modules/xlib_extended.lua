local multirun_file = "xlib_extended/sv_multirun.lua"

if SERVER then
	if XLIB.Extended then
		AddCSLuaFile()
	else
		return
	end

	local lan = GetConVar("sv_lan")
	if lan:GetBool() then
		include(multirun_file)
	end
else
	if file.Exists(multirun_file, "LUA") then
		include(multirun_file)
	end
end

xloader("xlib_extended", function(f) include(f) end)

function IsTestServer()
	return GetGlobalBool("development_mode") and game.GetIPAddress():Split(":")[2] == "13337"
end

XLIB.Extended = true
