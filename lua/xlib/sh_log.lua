local red = Color(255, 0, 0)
--- Outputs a red warning message to the console.
function XLIB.Warn(...)
	MsgC(red, SPrint("WARNING:", ...).."\n")
end

function XLIB.WarnTrace(...)
	MsgC(red, SPrint("WARNING:", ...).."\n"..debug.traceback().."\n")
end

function XLIB.Implement(...)
	ErrorNoHalt(SPrint("NOT IMPLEMENTED:", ...).."\n"..debug.traceback().."\n")
end
