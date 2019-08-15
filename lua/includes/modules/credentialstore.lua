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
		ErrorNoHalt(fmterr("Tried to read credentials for "..(tostring(k))
			         .." but it was not set in the "..credential_store.." file!\n"))
	end
}

local creds = setmetatable(util.KeyValuesToTable(file.Read(credential_store, "GAME")), mt)
_G.CREDENTIALS = creds

if creds.extended then
	SetGlobalBool("development_mode", CREDENTIALS.development_mode == 1)
	SetGlobalBool("xlib_extended", CREDENTIALS.extended == 1)
	XLIB.Extended = true
end

module ("credentialstore")
credentials = creds
