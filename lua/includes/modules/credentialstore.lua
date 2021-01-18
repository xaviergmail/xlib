if CLIENT then return end

local credential_store = "CREDENTIAL_STORE.txt"

local function fmterr(str)
	return "CREDENTIAL STORE: " .. str
end

if not file.Exists(credential_store, "GAME") then
	credential_store = credential_store:gsub("%.txt$", "")
end

if not file.Exists(credential_store, "GAME") then
	ErrorNoHalt(fmterr("You should add and configure CREDENTIAL_STORE.txt inside the garrysmod folder!"))
end

local defaults = {
	production = true,
	development_mode = false,
	extended = false,
	environment = "production",
}

local mt = {
	__index = function(t, k)
		if defaults[k] ~= nil then
			return defaults[k]
		end
		MsgC(Color(255, 255, 0), fmterr("A script is referencing `"..(tostring(k))
			         .."` which is not configured! Functionality likely disabled.\n"))
	end
}

local creds
local function load()
	creds = util.KeyValuesToTable(file.Read(credential_store, "GAME") or "")

	if creds.CHECK then
		error('"CHECK" is a reserved path in '..credential_store..'. Please rename your configuration to something else.')
	end

	-- Use CREDENTIALS.CHECK to quietly check if a feature is enabled or disabled
	-- without printing a warning message to the console when it isn't set.
	creds.CHECK = setmetatable({}, {__index=creds})

	_G.CREDENTIALS = setmetatable(creds, mt)
	if CREDENTIALS.CHECK.environment then
		CREDENTIALS.production = CREDENTIALS.environment == "production"
		CREDENTIALS.development_mode = CREDENTIALS.environment == "development"
	else
		if CREDENTIALS.CHECK.production then
			creds.environment = "production"
		elseif CREDENTIALS.CHECK.development_mode then
			creds.environment = "development"
		end
	end
end

load()

if creds.extended then
	XLIB.Extended = true
	SetGlobalBool("xlib_extended", CREDENTIALS.extended == 1)
	XLIB.PostInitialize(function()
		DevCommand("credentialstore.reload", load)
	end)
end