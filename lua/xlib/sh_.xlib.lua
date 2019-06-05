XLIB = XLIB or {}

function XLIB.PostInitialize(fn)
	if GAMEMODE then
		fn()
	else
		hook.Add("Initialize", "XLIB.PostInitialize"..tostring(fn), fn)
	end
end
_R = debug.getregistry()
_P = _R.Player
_E = _R.Entity
