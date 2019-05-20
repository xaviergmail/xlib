if not CREDENTIALS.sentry then return end

require("xlib_sentry")
if not sentry then
	XLIB.Warn("Sentry did not require() correctly")
	return
end

local options = {}
-- Make a copy so we can modify it
for k, v in pairs(CREDENTIALS.sentry.options or {}) do
	options[k] = v
end

if options.auto and (options.auto:lower() ~= "true" or options.auto ~= "1") then
	print('XLIB Sentry automatic loading disabled. Either unset CREDENTIAL_STORE.sentry.auto or set to "auto" or "1" to re-enable.)')
	return
end

options.no_detour = (options.no_detour or ""):Split(" ")

sentry.Setup(CREDENTIALS.sentry.dsn, options)
