local mobdebug = dofile("../lua/includes/modules/mobdebug.lua")

local realm = string.lower(select(1, ...) or "")

local realms = {
	server = 9000,
	client = 9005,
}

if not realms[realm] then
	print("Please pass in argument 'realm' <client / server>")
	return
end

local port = realms[realm]

print("Listening on port", port)
mobdebug.listen('0.0.0.0', port)
