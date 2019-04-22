AddCSLuaFile()

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
	log("Checking", dir)

	for _, f in ipairs(files) do
		if f:match(".*%.lua$") then
			doFile(dir, f, _include)
		end
	end

	for _, d in ipairs(dirs) do
		iterDir(dir..'/'..d, _include)
	end
end

function xloader(dir, _include)
	log("Loading directory", dir)
	iterDir(dir, _include)
end

xloader("xlib", include)