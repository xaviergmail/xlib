XLIB.ActiveThrottles = XLIB.ActiveThrottles or {}
local active = XLIB.ActiveThrottles

local function concat(t)
	local s = ""
	for _, v in ipairs(t) do
		s = s .. "." .. tostring(t)
	end

	return s:Trim()
end

---
-- Runs the *only* the *latest callback function passed*, after <delay> seconds from the first call (or last execution) based on a unique identifier
-- @param identifier Unique identifier for the throttle action. Will be tostring'ed and concatenated if table.
-- @param delay Time to throttle function call by
-- @param callback Callback function
function XLIB.Throttle(identifier, delay, callback)
	if istable(identifier) then identifier=concat(identifier) end

	local throttle = active[identifier] or { time = SysTime() + delay }
	throttle.callback = callback
	active[identifier] = throttle

	timer.Create("xlib.throttle."..identifier, SysTime() - throttle.time, 1, function()
		XLIB.ExecuteThrottle(identifier)
	end)
end

function XLIB.ExecuteThrottle(identifier, handleErrors)
	local throttle = active[identifier]
	active[identifier] = nil

	if handleErrors then
		local res, err = pcall(throttle.callback)

	else
		throttle.callback()
	end
end

hook.Add("Shutdown", "XLIB.FinishThrottles", function()
	for id, t in pairs(active) do
		XLIB.ExecuteThrottle(identifier)
	end
end)
