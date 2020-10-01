if SERVER and not GetConVar("sv_lan"):GetBool() then
	BlockCSLuaFile()
	return
end

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
		if self:IsBot() then
			-- https://developer.valvesoftware.com/wiki/SteamID
			-- STEAM_4 - Universe 4 is the "dev" universe. Won't collide.
			return "STEAM_4:0:"..self:EntIndex()
		end
		return self:GetNW2String("SteamID", self:OldSteamID())
	end

	_P.OldSteamID64  = _P.OldSteamID64 or _P.SteamID64
	function _P:SteamID64()
		if self:IsBot() then
			return util.SteamIDTo64(self:SteamID()) 
		end
		return self:GetNW2String("SteamID64", self:OldSteamID64())
	end
end
