pcall(require, "luaerror")

if not luaerror then return end

luaerror.EnableRuntimeDetour(true)

XLIB.StartupErrors = {}
XLIB.StartupErrorCount = 0
local function OnLuaError(is_runtime, rawErr, file, lineno, err, stack)
	if not XLIB.StartupErrors[rawErr] then
		XLIB.StartupErrorCount = XLIB.StartupErrorCount + 1
	end
	XLIB.StartupErrors[rawErr] = true
end

function XLIB.BlockStartup(reason)
	OnLuaError(nil, reason)
	XLIB.WarnTrace("Server startup join was blocked: "..reason)
end

hook.Add("LuaError", "XLib Error Blocker", OnLuaError)

hook.Add("InitPostEntity", "XLib Error Blocker", function()
	hook.Remove("LuaError", "XLib Error Blocker")
end)

hook.Add("CheckPassword", "XLib Error Blocker", function()
	if XLIB.StartupErrorCount > 0 and not XLIB.StartupErrorBypass then
		return false, ""
	end
end)

DevCommand("xlib_clearstartuperrors", function()
	XLIB.StartupErrorBypass = true
	print("Bypassing startup errors")
end)

DevCommand("xlib_startuperrors", function()
	for k, v in pairs(XLIB.StartupErrors) do
		MsgN("-----")
		MsgC(Color(0, 255, 255), k)
		Msg("\n\n")
	end
end)
