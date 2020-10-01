_P.OldSteamIDBot  = _P.OldSteamIDBot or _P.SteamID
function _P:SteamID()
	if self:IsBot() then
		-- https://developer.valvesoftware.com/wiki/SteamID
		-- STEAM_4 - Universe 4 is the "dev" universe. Won't collide.
		return "STEAM_4:0:"..self:UserID()
	end
	return self:OldSteamIDBot()
end

_P.OldSteamID64Bot  = _P.OldSteamID64Bot or _P.SteamID64
function _P:SteamID64()
	if self:IsBot() then
		return util.SteamIDTo64(self:SteamID()) 
	end
	return self:OldSteamID64Bot()
end

_P.OldNameBot = _P.OldNameBot or _P.Name
function _P:Name()
	if self:IsBot() then return "Bot"..self:UserID() end
	return self:OldNameBot()
end

_P.OldNickBot = _P.OldNickBot or _P.Nick
function _P:Nick()
	if self:IsBot() then return self:Name() end
	return self:OldNickBot()
end