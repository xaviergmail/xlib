AddCSLuaFile()

_R = debug.getregistry()
_E = _R.Entity
_P = _R.Player

local green = Color(0, 255, 150)
local function log(...)
	local s = "XLoader: "
	for k, v in pairs({...}) do
		s = s .. tostring(v) .. " "
	end

	MsgC(green, s .. "\n")
end

local function doFile(dir, f, _include)
	local realm = f:sub(1, 3)

	f = dir..'/'..f

	if realm == "sh_" then
		AddCSLuaFile(f)
		_include(f)
	elseif SERVER and realm == "sv_" then
		_include(f)
	elseif realm == "cl_" then
		AddCSLuaFile(f)
		if CLIENT then
			_include(f)
		end
	end
end

local function iterDir(dir, _include)
	local files, dirs = file.Find(dir..'/*', 'LUA')
	log(" - Checking", dir)

	local cl, sv, sh = {}, {}, {}
	local realms = { cl_=cl, sv_=sv, sh_=sh }

	for _, f in ipairs(files) do
		if f:match(".*%.lua$") then
			local realm = f:sub(1, 3)
			if realms[realm] then
				table.insert(realms[realm], dir..'/'..f)
			end
					
		end
	end

	for _, v in ipairs(sh) do
		_include(v)
		AddCSLuaFile(v)
	end

	if SERVER then
		for _, v in ipairs(sv) do
			_include(v)
		end
	end

	for _, v in ipairs(cl) do
		if SERVER then
			AddCSLuaFile(v)
		else
			_include(v)
		end
	end

	for _, d in ipairs(dirs) do
		iterDir(dir..'/'..d, _include)
	end
end

local function include_print(_include)
	return function(...)
		log("   - Including", ...)
		_include(...)
	end
end

function xloader(dir, _include)
	log("Loading directory", dir)
	iterDir(dir, include_print(_include))
end

xloader("xlib", include)