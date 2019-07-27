local unpack = (unpack or table.unpack)

local function concat(...)
	local s = ""
	local t = {...}
	for k, v in pairs(t) do
		s = s .. " " .. tostring(v)
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
	for i=1, len, 1000 do
		MsgC(color_white, s:sub(i, len))
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

	local ret = {pcall(fn)}

	if not table.remove(ret, 1) then
		env.print(unpack(ret))
	else
		for _, r in ipairs(ret) do
			if istable(r) and not f.islist(r) then
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
		if not IsValid(ply) or (ply.IsDeveloper and ply:IsDeveloper()) then
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