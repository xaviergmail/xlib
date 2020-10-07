--[[
	Running a client with -multirun, the server sees the steam ID as STEAM_0:0:0.
	However, the clients still see the account owner's original Steam ID.

	This workaround networks the SteamID/SteamID64 to all clients so that the server becomes trusted.
]]

if SERVER then
	hook.Add("OnEntityCreated", "XLib multirun steamid", function(ent)
		if ent:IsPlayer() then
			ent:SetNW2String("SteamID", ent:SteamID())
			ent:SetNW2String("SteamID64", ent:SteamID64())
		end
	end)
else
	_P.OldSteamIDMR  = _P.OldSteamIDMR or _P.SteamID
	function _P:SteamID()
		return self:GetNW2String("SteamID", self:OldSteamIDMR())
	end

	_P.OldSteamID64MR  = _P.OldSteamID64MR or _P.SteamID64
	function _P:SteamID64()
		return self:GetNW2String("SteamID64", self:OldSteamID64MR())
	end
end