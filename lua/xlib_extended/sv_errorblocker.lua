pcall(require, "luaerror")

if not luaerror then return end

luaerror.EnableRuntimeDetour(true)

XLIB.StartupErrors = XLIB.StartupErrors or {}
XLIB.StartupErrorCount = XLIB.StartupErrorCount or 0
local function OnLuaError(is_runtime, rawErr, file, lineno, err, stack)
	if not XLIB.StartupErrors[rawErr] then
		XLIB.StartupErrorCount = XLIB.StartupErrorCount + 1
	end
	XLIB.StartupErrors[rawErr] = true

	if sentry then
		sentry.ReportError("Server startup blocked by error " .. rawErr, stack, {rawErr=rawErr, file=file, lineno=lineno, err=err, stack=stack})
	end
end

function XLIB.BlockStartup(reason)
	OnLuaError(nil, reason, "", 0, reason, {})
	XLIB.WarnTrace("Server startup join was blocked: "..reason)
end

hook.Add("LuaError", "XLib Error Blocker", OnLuaError)

hook.Add("InitPostEntity", "XLib Error Blocker", function()
	hook.Remove("LuaError", "XLib Error Blocker")
end)

hook.Add("CheckPassword", "XLib Error Blocker", function()
	if XLIB.StartupErrorCount > 0 and not XLIB.StartupErrorBypass then
		return false, "Server errored during startup."
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
