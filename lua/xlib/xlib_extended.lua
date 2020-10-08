XLIB.Extended = true

if SERVER then
	if XLIB.Extended then
		AddCSLuaFile()
		SetGlobalBool("development_mode", CREDENTIALS.CHECK.development_mode == 1)
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

DevCommand("testserver.toggle", function(ply)
	if not devports[game.GetIPAddress():Split(":")[2]] or CREDENTIALS.CHECK.production then
		ply:ChatPrint("You cannot change the test server status on a production server! (Check hostport)")
		return
	end

	if IsValid(ply) then
		ply:ChatPrint("You can only run this from console")
		return
	end

	SetGlobalBool("development_mode", !GetGlobalBool("development_mode", false))
	print("Dev mode is ", GetGlobalBool("development_mode") and "Enabled" or "Disabled")
end)
