AddCSLuaFile()

local green = Color(0, 255, 150)
local function log(...)
	local s = "XLoader: "
	for k, v in pairs({...}) do
		s = s .. tostring(v) .. " "
	end

	MsgC(green, s .. "\n")
end

local t = {}
local function reset()
	t.cl = {}
	t.sh = {}
	t.sv = {}
end

local function doFile(dir, f)
	local realm = f:sub(1, 3)

	f = dir..'/'..f

	if realm == "sh_" then
		table.insert(t.sh, f)
	elseif realm == "sv_" then
		table.insert(t.sv, f)
	elseif realm == "cl_" then
		table.insert(t.cl, f)
	end
end

local function iterDir(dir)
	local files, dirs = file.Find(dir..'/*.lua', 'LUA')
	log("Checking", dir)

	for _, f in ipairs(files) do
		doFile(dir, f)
	end

	for _, d in ipairs(dirs) do
		iterDir(dir..'/'..d)
	end
end

function xloader(dir, _include)
	log("Loading directory", dir)
	reset()
	iterDir(dir)

	for k, v in ipairs(t.sh) do
		AddCSLuaFile(v)
		_include(v)
	end

	if SERVER then
		for k, v in ipairs(t.sv) do
			_include(v)
		end
	end

	for k, v in ipairs(t.cl) do
		if CLIENT then
			_include(v)
		else
			AddCSLuaFile(v)
		end
	end
end
