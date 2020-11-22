getmetatable(NULL).ChatPrint = function(_, ...)
	MsgN("NULL:ChatPrint() ", ...)
end

local function concat(...)
	local s = ""
	for i=1, select("#", ...) do
		s = s .. " " .. tostring(select(i, ...))
	end

	return s:Trim()
end


local REALM = { CLIENT = 1, SERVER = 2, OTHER = 3 }
local state = (LocalPlayer == nil) and REALM.SERVER or REALM.CLIENT
local colors = {
	[REALM.SERVER] = Color(209, 247, 255),
	[REALM.CLIENT] = Color(255, 251, 209),
	[REALM.OTHER] = Color(250, 224, 255),
}

local ctx = state

requested = {}

local function plid(ply)
	return IsValid(ply) and ply:UserID() or 0
end

local function allowRequests(requesterid, senderid)
	requested[requesterid] = requested[requesterid] or {}
	requested[requesterid][senderid] = CurTime() + 60
end

local function isAllowed(requesterid, senderid)
	local t = requested[requesterid][senderid] or math.huge
	return requested[requesterid] and CurTime() <= (requested[requesterid][senderid] or math.huge)
end

function longprint(...)
	local s = ""
	if select("#", ...) > 1 then
		s = concat(...)
	else
		s = select(1, ...)
	end

	s = tostring(s)

	local len = #s
	local incr = 1024
	for i=1, len, incr do
		MsgC(colors[ctx], s:sub(i, i+incr-1))
	end

	Msg("\n")
end

function dir(obj)
	local mt = getmetatable(obj)

	local build, seen, tmp = f.list{}, {}, {}
	local function add(k)
		if not seen[k] then
			table.insert(tmp, k)
			seen[k] = true
		end
	end

	local function process(name, tbl)
		tmp = {}
		f.map(add, f.keys(tbl))

		if #tmp > 0 then
			table.sort(tmp)
			table.insert(build, ("%s:"):format(name))
			table.insert(build, "-  "..tostring(f.list(tmp)))
		end
	end

	if istable(obj) then
		process("table", obj)
	end

	if mt then
		if istable(mt.__index) then
			process("__index", mt.__index)
		end

		-- Some userdata put their indices directly on their metatable
		process("metatable", mt)
	end

	return unpack(build)	
end


-- Add these suffixes to do different things
local shortcuts = {
	["?"] = "return dir(%s)",
	["!"] = "return PrintTable((%s))",
}


local function run_lua(ply, lua, requester)
	local env = { }

	-- Global shorthands
	env.dir = dir
	env.plys = all(player.GetAll())

	if IsValid(ply) then
		-- More global shorthands
		env.me = ply
		env.metr = ply:GetEyeTrace()
		env.metrent = env.metr.Entity
		env.wep = ply:GetActiveWeapon()
		env.veh = IsValid(ply:GetVehicle()) and ply:GetVehicle() or nil

		env.xlib_lua_running = true
		if SERVER then
			env.print = function(...)
				net.Start("luaoutput")
				net.WriteUInt(REALM.SERVER, 4)
				net.WriteUInt(plid(ply), 16)
				net.WriteCompressed(concat(...))
				net.Send(ply)
			end
		else
			if requester and requester != LocalPlayer():UserID() then
				env.print = function(...)
					net.Start("luaoutput")
					net.WriteUInt(REALM.OTHER, 4)
					net.WriteUInt(requester, 16)
					net.WriteCompressed(concat(...))
					net.SendToServer()
				end
			else
				ctx = REALM.CLIENT
				env.print = longprint
			end
		end
	else
		ctx = REALM.SERVER
		env.print = longprint
	end

	env.Msg = env.print
	env.MsgC = env.print
	env.PrintTable = function(tbl)
		env.print(SPrintTable(tbl))
	end

	-- For some reason __index = _G doesn't work here.
	setmetatable(env, {
		__index = function(t, k) return rawget(_G, k) end,
		__newindex = function(t, k, v) rawset(_G, k, v) end,
	})

	local id = (IsValid(ply) and ply:SteamID() or "CONSOLE")..".lua"

	lua = lua:Trim()
	local inspect = false
	local fn
	for k, v in pairs(shortcuts) do
		if lua:EndsWith(k) then
			lua = lua:sub(1, -(k:len()+1))
			fn = CompileString(v:format(lua), id, false)
		end
	end

	if not isfunction(fn) then
		fn = CompileString("return " .. lua, id, false)
	end
	if not isfunction(fn) then
		fn = CompileString(lua, id, false)
		if not isfunction(fn) then
			env.print("Could not compile:", fn)
			return
		end
	end
	fn = setfenv(fn, env)

	local ret = table.PackNil(xpcall(fn, debug.traceback))

	if not table.remove(ret, 1) then
		env.print(table.UnpackNil(ret))
	else
		for _, r in ipairs(ret) do
			if r == table.NIL then
				env.print('nil')
			elseif istable(r) and not f.islist(r) then
				env.print(r, ": PrintTable v\n"..SPrintTable(r, 0, r, false))
			else
				env.print(r)
			end
		end
	end
end

local function luacmd(ply, cmd, args, argstr)
	run_lua(ply, argstr)
end

function DevCommand(cmd, fn, realm)
	realm = realm or SERVER
	concommand.Remove(cmd)
	if realm ~= nil and not realm then return end

	concommand.Add(cmd, function(ply, cmd, args, argstr)
		if XLIB.IsDeveloper(ply) then
			fn(ply, cmd, args, argstr)
		end
	end)
end

function XLIB.IsDeveloper(ply)
	if not IsValid(ply) then return true end
	local override = hook.Run("CanRunDevCommand", ply, cmd, args, argstr) == true
	return override or (ply.IsDeveloper and ply:IsDeveloper())
end


if SERVER then
	util.AddNetworkString("luaoutput")
	util.AddNetworkString("lua_run")
else
	net.Receive("lua_run", function()
		local requester = net.ReadUInt(16)	
		local code = net.ReadCompressed()
		run_lua(LocalPlayer(), code, requester)
	end)
end

net.Receive("luaoutput", function(l, ply)
	local realm = net.ReadUInt(4)
	local requester_id = net.ReadUInt(16)

	local str = net.ReadCompressed()
	local requester = Player(requester_id)

	if SERVER and not isAllowed(requester_id, plid(ply)) or not XLIB.IsDeveloper(requester) then
		local msg = SPrint(ply, "sent lua_output of length", l, "to requester who didn't request:", requester_id, requester, "IsDev", XLIB.IsDeveloper(requester))
		XLIB.Warn(msg)
		hook.Run("Log::Report", { text = msg, ply = ply })
		return
	end

	local pstr = "Lua output for "..tostring(ply)..":\n"..str

	if CLIENT or requester_id == 0 then
		ctx = realm
		longprint(CLIENT and str or pstr)
	elseif SERVER then
		net.Start("luaoutput")
		net.WriteUInt(REALM.OTHER, 4)
		net.WriteUInt(requester_id, 16)
		net.WriteCompressed(pstr)
		net.Send(requester)
	end
end)


local mt = {}
mt.__index = function(t, k)
	local build = {}
	local items = rawget(t, 'items')

	local fn = false
	for id, item in pairs(items) do
		local v = item[k]
		if isfunction(v) then
			fn = true
		else
			build[id] = v
		end
	end

	if fn then
		return function(this, ...)
			local isSelf = this == t
			for id, item in pairs(items) do
				local ret
				if isSelf then
					ret = item[k](item, ...)
				else
					ret = item[k](...)
				end
				build[id] = ret
			end

			return build
		end
	else
		return build
	end
end

mt.__newindex = function(t, k, v)
	local items = rawget(t, "items")
	for id, item in pairs(items) do
		item[k] = v
	end
end

function all(tbl)
	return setmetatable({items=tbl}, mt)
end

local function run_lua_ply(ply, code, requester)
	if not code then return end

	local rqid = plid(requester)
	net.Start("lua_run")
	net.WriteUInt(rqid, 16)
	net.WriteCompressed(code)

	if IsValid(ply) then
		allowRequests(rqid, plid(ply))
		net.Send(ply)
	else
		for k, v in pairs(player.GetAll()) do
			allowRequests(rqid, plid(v))
		end
		net.Broadcast()
	end
end

DevCommand("lua", luacmd)
DevCommand("luacl", luacmd, CLIENT)

DevCommand("luash", function(ply, cmd, args, argstr)
	run_lua(ply, argstr)
	run_lua_ply(ply, argstr, ply)
end)

DevCommand("luashall", function(ply, cmd, args, argstr)
	run_lua(ply, argstr)
	run_lua_ply(nil, argstr, ply)
end)

DevCommand("luaplall", function(ply, cmd, args, argstr)
	run_lua_ply(nil, argstr, ply)
end)

DevCommand("luapl", function(ply, cmd, args, argstr)
	local targetid = args[1]
	local target = Player(targetid)
	if not IsValid(target) then
		ply:ChatPrint("Please specify a UserID() as the first argument")
		return
	end

	argstr = argstr:sub(argstr:find(" ") + 1)

	run_lua_ply(target, argstr, ply)
end)

DevCommand("luashpl", function(ply, cmd, args, argstr)
	local targetid = args[1]
	local target = Player(targetid)
	if not IsValid(target) then
		ply:ChatPrint("Please specify a UserID() as the first argument")
		return
	end

	argstr = argstr:sub(argstr:find(" ") + 1)

	run_lua_ply(target, argstr, ply)
	run_lua(ply, argstr)
end)


DevCommand("manybots", function()
	for i=0, 10 do
		RunConsoleCommand("bot")
	end
end)

DevCommand("nobots", function()
	for k, v in pairs(player.GetBots()) do
		v:Kick()
	end
end)

DevCommand("reloadmap", function(ply)
	if IsValid(ply) then return end
	RunConsoleCommand("changelevel", game.GetMap())
end)