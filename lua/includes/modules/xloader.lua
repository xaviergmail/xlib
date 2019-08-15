AddCSLuaFile()

local AddCS = AddCSLuaFile
local AddCSLuaFileRenetwork = AddCS

local force_addcslua = false

_R = debug.getregistry()
_E = _R.Entity
_P = _R.Player

local loadpaths = {}

local green = Color(0, 255, 150)
local function log(...)
	local s = "XLoader: "
	for k, v in pairs({...}) do
		s = s .. tostring(v) .. " "
	end

	MsgC(green, s .. "\n")
end

local function iterDir(dir, _include, topdir, done)
	if not topdir then
		local gmfolder = "gamemodes/"..(GM or GAMEMODE).FolderName.."/gamemode/"
		local done = { cl_={}, sv_={}, sh_={}}

		local _, dirs = file.Find("addons/*", "MOD")
		for _, addondir in ipairs(dirs) do
			local luadir = "addons/"..addondir.."/lua/"
			if file.IsDir(luadir..dir, "MOD") then
				iterDir(luadir..dir, _include, luadir, done)
			end
		end

		if file.IsDir(gmfolder..dir, "MOD") then
			iterDir(gmfolder..dir, _include, gmfolder, done)
		end

		if file.IsDir("lua/"..dir, "MOD") then
			iterDir("lua/"..dir, _include, "lua/", done)
		end

		return
	end

	local files, dirs = file.Find(dir..'/*', "MOD")
	log(" - Checking", dir)

	local cl, sv, sh = {}, {}, {}
	local realms = { cl_=cl, sv_=sv, sh_=sh }

	local luadir = dir:sub(topdir:len()+1)

	for _, f in ipairs(files) do
		if f:match(".*%.lua$") then
			local realm = f:sub(1, 3)
			if realms[realm] then
				local tf = luadir..'/'..f
				if not done[realm][tf] then
					done[realm][tf] = true
					table.insert(realms[realm], tf)
				end
			end
		end
	end

	for _, v in ipairs(sh) do
		_include(v)
		AddCS(v, topdir)
	end

	if SERVER then
		for _, v in ipairs(sv) do
			_include(v)
		end
	end

	for _, v in ipairs(cl) do
		if SERVER then
			AddCS(v, topdir)
		else
			_include(v)
		end
	end

	for _, d in ipairs(dirs) do
		iterDir(dir..'/'..d, _include, topdir, done)
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
	loadpaths[dir] = _include
	iterDir(dir, include_print(_include))
end

xloader("xlib", include)

if SERVER then
	util.AddNetworkString("xloader_Reload")

	local extended_init = false
	local CSLuaFiles = {}
	local client_lua_files
	concommand.Add("xloader", function(ply, cmd, args)
		if IsValid(ply) and not (ply.IsDeveloper and ply:IsDeveloper()) then return end

		if not extended_init then
			exented_init = true

			if XLIB.Extended and GetGlobalBool("development_mode") then
				pcall(require, "sourcenet")
				pcall(require, "stringtable")

				if not sourcenet then
					ply:ChatPrint("sourcenet serverside module required!")
					return
				end

				if not stringtable then
					ply:ChatPrint("stringtable serverside modulet required!")
					return
				end

				client_lua_files = stringtable.Find("client_lua_files")
				for id, f in ipairs(client_lua_files:GetStrings()) do
					CSLuaFiles[f] = id
				end

				AddCSLuaFileRenetwork = function(fname, topdir)
					AddCSLuaFile(fname)

					local fullfname = (topdir..fname):lower()
					local fid = CSLuaFiles[fullfname]
					if not fid then
						for id, f in ipairs(client_lua_files:GetStrings()) do
							if f:lower() == fullfname:lower() then
								fid = id
								CSLuaFiles[fullfname] = fid
								break
							end
						end
					end

					if fid then
						local data = file.Read(fullfname, "MOD")
						for k, v in pairs(player.GetAll()) do
							print("Sending lua file", fid, fullfname)
							SendLuaFile(v:EntIndex(), fid, fname, true)
						end
					end
				end
			end
		end

		local action = args[1] or "all"
		local all = action == "all"

		if action == "list" then
			for dir in pairs(loadpaths) do
				ply:ChatPrint(dir)
			end
			return
		end

		AddCS = AddCSLuaFileRenetwork

		local network = false
		if all then
			for path, incl in pairs(loadpaths) do
				xloader(path, incl)
			end
		else
			local incl = loadpaths[incl] or include
			xloader(action, include)
		end

		AddCS = AddCSLuaFile

		-- No reliable way to check datapack was received on clients
		-- so we use a weakly little timer instead.
		-- Good enough for local machine development.
		timer.Simple(2, function()
			net.Start("xloader_reload")
			net.WriteBool(action == "all")
			if not all then
				net.WriteString(action)
			end
			net.Broadcast()
		end)
	end)
else
	net.Receive("xloader_reload", function()
		local all = net.ReadBool()
		if all then
			for path, incl in pairs(loadpaths) do
				xloader(path, incl)
			end
		else
			local path = net.ReadString()
			local incl = loadpaths[path] or include
			xloader(path, incl)
		end
	end)
end
