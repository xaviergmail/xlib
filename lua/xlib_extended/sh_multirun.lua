local lan = GetConVar("sv_lan")

if lan:GetBool() then
	if SERVER then
		util.AddNetworkString("xlib_multirun")
		net.Receive("xlib_multirun", function(len, ply)
			net.Start("xlib_multirun")
			net.WriteString(ply:SteamID())
			net.WriteUInt(ply:SteamID64(), 64)
			net.Send(ply)
		end)
	else
		XLIB.EnsureLocalPlayer(function()
			net.Start("xlib_multirun")
			net.SendToServer()
		end)

		net.Receive("xlib_multirun", function()
			local steamid = net.ReadString()
			if steamid != LocalPlayer():SteamID() then
				_P.OldSteamID  = _P.OldSteamID or _P.SteamID
				function _P:SteamID()
					if self == LocalPlayer() then
						return steamid
					end
					return self:OldSteamID()
				end
			end

			local steamid64 = net.ReadUInt(64)
			if steamid64 != LocalPlayer():SteamID() then
				_P.OldSteamID64  = _P.OldSteamID64 or _P.SteamID64
				function _P:SteamID64()
					if self == LocalPlayer() then
						return steamid64
					end
					return self:OldSteamID64()
				end
			end
		end)
	end
end
