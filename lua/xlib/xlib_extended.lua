XLIB.Extended = true

if SERVER then
	if XLIB.Extended then
		AddCSLuaFile()
		SetGlobalBool("development_mode", CREDENTIALS.environment == "development")
	else
		return
	end
end

xloader("xlib_extended", function(f) include(f) end)

function IsTestServer()
	return GetGlobalBool("development_mode")
end

DevCommand("testserver.toggle", function(ply)
	if CREDENTIALS.environment == "production" then
		ply:ChatPrint("You cannot change the test server status on a live production server! Edit CREDENTIAL_STORE.txt")
		return
	end

	if IsValid(ply) then
		ply:ChatPrint("You can only run this from console")
		return
	end

	SetGlobalBool("development_mode", !GetGlobalBool("development_mode", false))
	print("Dev mode is ", GetGlobalBool("development_mode") and "Enabled" or "Disabled")
end)
