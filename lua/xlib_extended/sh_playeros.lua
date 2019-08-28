local function GetOSName()
	if (system.IsWindows()) then
		return "Windows"
	elseif (system.IsOSX()) then
		return "macOS"
	elseif (system.IsLinux()) then
		return "Linux"
	end
	return "Unknown"
end


local allowed = {
	Windows = true,
	macOS = true,
	Linux = true,
	Unknown = true,
}
-- This is only used for Sentry error reporting. We don't care about skids spoofing this.
if SERVER then
	util.AddNetworkString("xlib_playeros")
	net.Receive("xlib_playeros", function(l, ply)
		if ply.XLIB_OS then return end
		local _os = net.ReadString():sub(1, 10)

		if not allowed[_os] then
			_os = "Spoofed"
		end

		ply.XLIB_OS = _os
	end)
else
	XLIB.PostInitEntity(function()
		net.Start("xlib_playeros")
		net.WriteString(GetOSName())
		net.SendToServer()
	end)
end
