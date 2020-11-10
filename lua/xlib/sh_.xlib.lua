XLIB = XLIB or {}

if CLIENT then XLIB.Extended = file.Exists("lua/xlib/xlib_extended.lua", "LUA") end

function XLIB.PostInitialize(fn)
	if GAMEMODE then
		fn()
	else
		hook.Add("Initialize", "XLIB.PostInitialize:"..tostring(fn), fn)
	end
end

function XLIB.PreInitialize(fn)
	if GAMEMODE then
		fn()
	else
		hook.Add("PostGamemodeLoaded", "XLIB.PreInitialize:"..tostring(fn), fn)
	end
end

XLIB.DidInitPostEntity = XLIB.DidInitPostEntity or false
function XLIB.PostInitEntity(fn)
	if XLIB.DidInitPostEntity then
		fn()
	else
		hook.Add("InitPostEntity", "XLIB.PostInitialize:"..tostring(fn), fn)
	end
end

hook.Add("InitPostEntity", "XLIB.PostInitEntity", function()
	XLIB.DidInitPostEntity = true
end)

function XLIB.OnFirstTick(fn)
	if GAMEMODE then
		fn()
	else
		local id = "XLIB.OnFirstTick:"..tostring(fn)
		hook.Add("Tick", id, function()
			hook.Remove("Tick", id)
			fn()
		end)
	end
end

function XLIB.EnsureHTTP(fn)
	if GAMEMODE then
		fn()
	else
		local id = "XLIB.EnsureHTTP:"..tostring(fn)
		hook.Add("Tick", id, function()
			hook.Remove("Tick", id)
			fn()
		end)
	end
end

if CLIENT then
	function XLIB.EnsureLocalPlayer(fn)
		if IsValid(LocalPlayer()) then
			fn()
		else
			local hkName = "XLIB.EnsureLocalPlayer"..tostring(fn)
			hook.Add("InitPostEntity", hkName, function()
				hook.Remove("InitPostEntity", hkName)
				fn()
			end)
		end
	end
end


_R = debug.getregistry()
_P = _R.Player
_E = _R.Entity
PLAYER = _P
ENTITY = _E

NOOP = function() end
TRUE = function() return true end
FALSE = function() return false end
