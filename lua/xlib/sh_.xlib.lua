XLIB = XLIB or {}

function XLIB.PostInitialize(fn)
	if GAMEMODE then
		fn()
	else
		hook.Add("Initialize", "XLIB.PostInitialize"..tostring(fn), fn)
	end
end

XLIB.DidInitPostEntity = XLIB.DidInitPostEntity or false
function XLIB.PostInitEntity(fn)
	if XLIB.DidInitPostEntity then
		fn()
	else
		hook.Add("InitPostEntity", "XLIB.PostInitialize"..tostring(fn), fn)
	end
end

hook.Add("InitPostEntity", "XLIB.PostInitEntity", function()
	XLIB.DidInitPostEntity = true
end)

_R = debug.getregistry()
_P = _R.Player
_E = _R.Entity