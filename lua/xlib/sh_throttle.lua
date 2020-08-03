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

	timer.Create("xlib.throttle."..identifier, throttle.time - SysTime(), 1, function()
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

local Test = XLIB.Test or NOOP
Test("XLIB.Throttle", function(assert, Log, Err)
	RunConsoleCommand("sv_hibernate_think", "1")

	local n = 10

	local counter = 0
	local collector = {}

	local start = SysTime()
	local delay = 2

	local j = util.TableToJSON
	local function make_callback()
		counter = counter + 1
		return function()
			table.insert(collector, counter)
			assert("Callback only called once", j(collector), j{n})

			local delta = SysTime() - start
			local variance = math.abs(delay - delta)
			local tolerance = engine.TickInterval() * 5
			Log("Variance", variance, "Delta", delta)
			assert("Delayed by "..delay.."s within tolerance", variance < tolerance)
		end
	end

	for i=1, n do
		XLIB.Throttle("throttle_test", delay, make_callback())
	end
end)