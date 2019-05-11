XLIB = XLIB or {}

function XLIB.PostInitialize(fn)
	if GAMEMODE then
		fn()
	else
		hook.Add("Initialize", "XLIB.PostInitialize"..tostring(fn), fn)
	end
end