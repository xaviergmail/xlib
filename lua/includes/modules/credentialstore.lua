if CLIENT then return end

local credential_store = "CREDENTIAL_STORE.txt"

local function fmterr(str)
	return "CREDENTIAL STORE: " .. str
end

if not file.Exists(credential_store, "GAME") then
	credential_store = credential_store:gsub("%.txt$", "")
end

if not file.Exists(credential_store, "GAME") then
	error(fmterr("You need CREDENTIAL_STORE.txt inside the garrysmod folder!"))
end

local defaults = {
	production = false,
	development_mode = false,
	extended = false,
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

local creds = util.KeyValuesToTable(file.Read(credential_store, "GAME"))

if creds.CHECK then
	error('"CHECK" is a reserved path in '..credential_store..'. Please rename your configuration to something else.')
end

-- Use CREDENTIALS.CHECK to quietly check if a feature is enabled or disabled
-- without printing a warning message to the console when it isn't set.

creds.CHECK = creds
_G.CREDENTIALS = setmetatable(creds, mt)

if creds.extended then
	SetGlobalBool("development_mode", CREDENTIALS.development_mode == 1)
	SetGlobalBool("xlib_extended", CREDENTIALS.extended == 1)
	XLIB.Extended = true
end

module ("credentialstore")
credentials = creds
