AddCSLuaFile()

_R = debug.getregistry()
_E = _R.Entity
_P = _R.Player

local green = Color(0, 255, 150)
local function log(...)
	local s = "XLoader: "
	for k, v in ipairs({...}) do
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
		if IsTestServer and IsTestServer() and (SERVER or file.Exists("XLIB_LOADPRINT", "MOD")) then
			log("   - Including", ...)
		end
		_include(...)
	end
end

function xloader(dir, _include)
	log("Loading directory", dir)
	iterDir(dir, include_print(_include))
end

hook.Add("Initialize", "xloader", function()
	if not XLIB or not XLIB.Extended then return end
	if SERVER then
		pcall(require, "stringtable")

		if not stringtable then
			return XLIB.Warn("xloader: gm_stringtable not found, you will not get new clientside lua files")
		end

		util.AddNetworkString("xloader_cslua")
		XLIB.CSLua = XLIB.CSLua or {}

		local csfiles = stringtable.Find("client_lua_files")
		if not csfiles then
			return XLIB.Warn("xloader_cslua could not find client_lua_files stringtable")
		end

		for k, v in ipairs(csfiles:GetStrings()) do
			XLIB.CSLua[v] = true
		end


		OAddCSLuaFile = OAddCSLuaFile or AddCSLuaFile
		function AddCSLuaFile(...)
			-- Only run once on the next tick since this is expensive
			timer.Create("xloader_cslua", 0, 1, function()
				local send = {}
				for k, v in ipairs(csfiles:GetStrings()) do
					if not XLIB.CSLua[v] then
						local fn = v:gsub("^lua/", "")
									:gsub("^addons/[^/]*/", "")
							        :gsub("^gamemodes/[^/]*/", "")
						table.insert(send, fn)
						XLIB.CSLua[v] = true
					end
				end

				net.Start("xloader_cslua")
				net.WriteTable(send)
				net.Broadcast()
			end)

			return OAddCSLuaFile(...)
		end
	else
		local ldata = "print('tempfile')"
		local ldatat = ldata..string.char(0)
		local lsize = ldata:len()
		local lcrc = util.CRC(ldata)

		local prefix = "xloader_cslua"
		file.CreateDir(prefix)

		for k, v in pairs(file.Find(prefix.."/*", "DATA")) do
			file.Delete(prefix.."/"..v)
		end

		function xloader_gma(files)
			local data = "GMAD" .. struct.pack(
				"b" ..  -- 1 version
				"L" ..  -- 8 steamid
				"L" ..  -- 8 timestamp
				"b" ..  -- 1 nothing
				"s" ..  -- str Title
				"s" ..  -- str Desc
				"s" ..  -- str author
				"i",    -- 4 Version
				3,
				0,
				os.time(),
				0,
				"testaddon"..CurTime(),
				"testdescription",
				"xlib_xloader",
				1
			)

			for k, v in ipairs(files) do
				data = data .. struct.pack(
					"islI", k, v:lower(), lsize, lcrc
				)
			end

			data = data .. struct.pack("i", 0) .. ldatat:rep(#files)
			data = data .. struct.pack("I", util.CRC(data))

			local fname = prefix.."/xloader_cslua-"..SysTime()..".dat"
			local f = file.Open(fname, "wb", "DATA")
			f:Write(data)
			f:Close()

			local succ, ret = game.MountGMA("data/"..fname)
			if ret then
				PrintTable(ret)
			end
		end

		net.Receive("xloader_cslua", function()
			local files = net.ReadTable()
			local nfiles = {}
			for k, v in ipairs(files) do
				table.insert(nfiles, v)
			end
			xloader_gma(files)
		end)
	end
end)
