--[[

This module's goal is to provide a single interface to map-specific settings
It has support for default sane values
"Why not just save it as JSON?" - Functions!
You can run any arbitrary code anywhere, add hooks, etc

Usage:
require "mapmanager"
MAP:Add("uniquename_mapconfig")
OR
MAP:Load("uniquename_mapconfig")  -- Autorefresh-aware

Structure:
lua/uniquename_mapconfig/
- cl_registers.lua  ( registers are the default / fallback config options for (sv|cl|sh)_settings.lua )
- sv_registers.lua
- sh_registers.lua
- map_name/ ( without _v[%d%w]+" eg: rp_evocity_v2p  = "rp_evocity" )
  - resources.lua ( runs serverside. Useful for resource.Add* )
  - (sv|cl|sh)_settings.lua
  - (sv|cl|sh)_settings_preinit.lua  -- Runs after gamemode/Lua initialization, but before Initialize
  - (sv|cl|sh)_hooks.lua

]]

AddCSLuaFile()

local directories = MAP and MAP.Directories or {}

_G.MAP = {}
_G.mapmanager = MAP

MAP.__settings = {}

MAP.__defaults = {}

MAP.Directories = {}

function MAP:Register(key, default)
	if self.__defaults[key] != nil then
		ErrorNoHalt("Warning: Registering key twice: "..tostring(key).."\n")
	end

	self.__defaults[key] = default
end

function MAP:Get(key)
	return self.__settings[key] or self.__defaults[key]
end

function MAP:Set(key, value)
	if self.__defaults[key] == nil then
		ErrorNoHalt("Warning: Setting non-registered key: "..tostring(key).."\n")
	end

	self.__settings[key] = value
end

function MAP:GetName()
	return string.lower(game.GetMap()):gsub("_v[%d%w]+", "")
end

function MAP:Is(map)
	return map:lower() == self:GetName()
end


local vars = {}

local global = _G
local mt = setmetatable({},
{
	__index = function(t, k)
		if rawget(vars, k) then return rawget(vars, k) end
		if k == "TODO" then
			XLIB.WarnTrace("MapManager needs to implement:")
			return nil
		end
		return rawget(global, k)
	end,

	__newindex = function(t, k, v)
		rawset(vars, k, v)
	end,
})

local _include = function(fname)
	local fn = CompileFile(fname)
	setfenv(fn, mt)
	fn()
end

function MAP:Add(dir)
	if not self.Directories[dir] then
		self:Load(dir)
	end
	self.Directories[dir] = true
end

function MAP:Load(dir)
	dir = dir or ""

	local dirbase = dir .. "/"..MAP:GetName().."/"

	local function tryServer(name)
		if SERVER and file.Exists(dirbase..name, "LUA") then
			_include(dirbase..name)
		end
	end

	local function tryClient(name)
		if file.Exists(dirbase..name, "LUA") then
			if SERVER then
				AddCSLuaFile(dirbase..name)
			else
				_include(dirbase..name)
			end
		end
	end

	local function tryShared(name)
		if file.Exists(dirbase..name, "LUA") then
			AddCSLuaFile(dirbase..name)
			_include(dirbase..name)
		end
	end

	tryServer "resources.lua"

	local function reset()
		vars = {}
		return vars
	end

	local registers = reset()

	if CLIENT then
		_include(dir..'/cl_registers.lua')
	else
		AddCSLuaFile(dir..'/cl_registers.lua')
		AddCSLuaFile(dir..'/sh_registers.lua')

		_include(dir..'/sv_registers.lua')
	end

	_include(dir..'/sh_registers.lua')

	for k, v in pairs(registers) do
		MAP:Register(k, v)
	end

	local settings = reset()

	tryServer "sv_settings.lua"
	tryShared "sh_settings.lua"
	tryClient "cl_settings.lua"

	for k, v in pairs(settings) do
		MAP:Set(k, v)
	end

	XLIB.PreInitialize(function()
		local settings = reset()

		tryServer "sv_settings_preinit.lua"
		tryShared "sh_settings_preinit.lua"
		tryClient "cl_settings_preinit.lua"

		for k, v in pairs(settings) do
			MAP:Set(k, v)
		end
	end)

	local hooks = reset()

	tryServer "sv_hooks.lua"
	tryShared "sh_hooks.lua"
	tryClient "cl_hooks.lua"

	if GAMEMODE then
		ProtectedCall(hooks.Initialize)
		ProtectedCall(hooks.InitPostEntity)
	end

	for k, v in pairs(hooks) do
		hook.Add(k, "HK_Map_"..MAP:GetName().."_"..k, v)
	end
end

function MAP:LoadAll()
	for k in pairs(self.Directories) do
		self:Load(k)
	end
end

DevCommand("loadmapconfig", function()
	MAP:LoadAll()
end)
