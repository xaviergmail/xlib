--[[
This is to address thirdparty scripts and/or legacy code making HTTP calls too early
https://github.com/Facepunch/garrysmod-issues/issues/1010#issuecomment-53056089

This implementation works by detouring any HTTP / http.* calls and
delaying their invocation until the first tick.

This implementation makes an attempt to keep compatibility with other
scripts that may already be detouring these functions.
]]

XLIB.HTTP = XLIB.HTTP or {}

local detour = XLIB.HTTP
detour.requests = detour.requests or {}

detour.OFetch = detour.OFetch or http.Fetch
detour.OPost = detour.OPost or http.Post
detour.OHTTP = detour.OHTTP or HTTP

detour.ready = false


for key, tbl in pairs { Fetch = http, Post = http, HTTP = _G} do
	tbl[key] = function(...)
		local orig = detour["O"..key]
		if not detour.ready then
			local extra = ""

			if key == "HTTP" then
				extra = "Unable to get return value for detoured HTTP() call at this point!"..
					    " Returning true by default.\n"..
					    " Consider fixing your code to manually delay the call to HTTP()"
			end

			XLIB.WarnTrace(("Delaying http call to first game tick (%s)"..extra):format(key))

			table.insert(detour.requests, {
				func = orig,
				args = table.PackNil(...),
			})

			if key == "HTTP" then
				return true
			end
		else
			return orig(...)
		end
	end
end

local function process()
	detour.ready = true

	local requests = detour.requests
	detour.requests = {}

	for _, cb in ipairs(requests) do
		cb.func(table.UnpackNil(cb.args))
	end
end

hook.Add("Tick", "xlib.delayhttprequests", function()
	hook.Remove("Tick", "xlib.delayhttprequests")
	process()
end)
