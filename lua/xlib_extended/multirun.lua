AddCSLuaFile()

if SERVER then
	hook.Add("OnEntityCreated", "XLib multirun steamid", function(ent)
		if ent:IsPlayer() then
			ent:SetNW2String("SteamID", ent:SteamID())
			ent:SetNW2String("SteamID64", ent:SteamID64())
		end
	end)
else
	_P.OldSteamID  = _P.OldSteamID or _P.SteamID
	function _P:SteamID()
		return self:GetNW2String("SteamID", self:OldSteamID())
	end

	_P.OldSteamID64  = _P.OldSteamID64 or _P.SteamID64
	function _P:SteamID64()
		return self:GetNW2String("SteamID64", self:OldSteamID64())
	end
end
