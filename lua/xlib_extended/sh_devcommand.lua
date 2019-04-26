local function luacmd(ply, cmd, args, argstr)
	local env = {}
	env.me = ply
	env.metr = ply:GetEyeTrace()
	env.metrent = env.metr.Entity
	if SERVER then
		env.print = function(...)
			local s = ""
			local t = {...}
			for k, v in pairs(t) do
				s = s .. " " .. tostring(v)
			end
			s = s:Trim()
			net.Start("luaoutput")
			net.WriteString(s)
			net.Send(ply)
		end
	else
		env.print = print
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

	local fn, err = CompileString(argstr, ply:SteamID()..".lua", false)
	if not isfunction(fn) then
		env.print(fn)
		env.print(err)
		return
	end
	fn = setfenv(fn, env)

	local succ, err = pcall(fn)

	if not succ then
		env.print(err)
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
		print(net.ReadString())
	end)
end

DevCommand("lua", luacmd)
DevCommand("luacl", luacmd, CLIENT)