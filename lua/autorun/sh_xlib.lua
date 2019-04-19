local buffer = ""
function SPrintTable(t, indent, done)

	done = done or {}
	indent = indent or 0
	local keys = table.GetKeys(t)

	table.sort(keys, function(a, b)
		if (isnumber(a) && isnumber(b)) then return a < b end
		return tostring(a) < tostring(b)
	end)

	for i = 1, #keys do
		key = keys[ i ]
		value = t[ key ]
		buffer = buffer..(string.rep("\t", indent))

		if  (istable(value) && !done[ value ]) then

			done[ value ] = true
			buffer = buffer..(tostring(key) .. ":" .. "\n")
			SPrintTable (value, indent + 2, done)

		else

			buffer = buffer..(tostring(key) .. "\t=\t")
			buffer = buffer..(tostring(value) .. "\n")

		end

	end
	if indent == 0 then
		local ret = buffer
		buffer = ""
		return ret
	end
end

require "credentialstore"

if not CREDENTIALS.extended then return end

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

	setmetatable(env, {__index = _G, __newindex = _G})

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
	if not realm then return end

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