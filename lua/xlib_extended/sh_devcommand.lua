getmetatable(NULL).ChatPrint = function(_, ...)
	print(...)
end

local function concat(...)
	local s = ""
	for i=1, select("#", ...) do
		s = s .. " " .. tostring(select(i, ...))
	end

	return s:Trim()
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
		MsgC(color_white, s:sub(i, i+incr-1))
	end

	Msg("\n")
end

local function luacmd(ply, cmd, args, argstr)
	local env = { print = longprint }
	if IsValid(ply) then
		env.me = ply
		env.metr = ply:GetEyeTrace()
		env.metrent = env.metr.Entity
		if SERVER then
			env.print = function(...)
				net.Start("luaoutput")
				net.WriteCompressed(concat(...))
				net.Send(ply)
			end
		end
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
	local fn, err = CompileString("return " .. argstr, id, false)
	if not isfunction(fn) then
		fn, err = CompileString(argstr, id, false)
		if not isfunction(fn) then
			env.print("Could not compile:", err)
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
				env.print(r, ": PrintTable v\n", SPrintTable(r, 0, r, false))
			else
				env.print(r)
			end
		end
	end
end

function DevCommand(cmd, fn, realm)
	realm = realm or SERVER
	concommand.Remove(cmd)
	if realm ~= nil and not realm then return end

	concommand.Add(cmd, function(ply, cmd, args, argstr)
		local override = hook.Run("CanRunDevCommand", ply, cmd, args, argstr) == true
		if override or not IsValid(ply) or (ply.IsDeveloper and ply:IsDeveloper()) then
			fn(ply, cmd, args, argstr)
		end
	end)
end

if SERVER then
	util.AddNetworkString("luaoutput")
else
	net.Receive("luaoutput", function()
		longprint(net.ReadCompressed())
	end)
end


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

DevCommand("lua", luacmd)
DevCommand("luacl", luacmd, CLIENT)

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
