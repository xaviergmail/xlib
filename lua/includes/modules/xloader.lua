module("xloader")

local green = Color(0, 255, 150)
local function log(...)
	local s = "XLoader: "
	for k, v in pairs({...}) do
		s = s .. tostring(v) .. " "
	end

	MsgC(green, s .. "\n")
end

local function doFile(dir, f)
	local realm = f:sub(1, 3)

	f = dir..'/'..f

	if realm == "sh_" then
		include(f)

		if SERVER then
			AddCSLuaFile(f)
		end
	elseif SERVER and realm == "sv_" then
		include(f)
	elseif realm == "cl_" then
		if SERVER then
			AddCSLuaFile(f)
		else
			include(f)
		end
	end
end

local function iterDir(dir)
	local files, dirs = file.Find(dir..'/*.lua', 'LUA')

	for _, f in ipairs(files) do
		doFile(dir, f)
	end

	for _, d in ipairs(dirs) do
		iterDir(dir..'/'..d)
	end
end

function load(dir)
	log("Loading directory", dir)
	iterDir(dir)
end

return load