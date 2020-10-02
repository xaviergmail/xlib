XLIB.Tests = XLIB.Tests or {}
XLIB.Tests.Started = XLIB.Tests.Started or false

-- FIXME: Lazy design, I apologize
XLIB.Tests.Queue = XLIB.Tests.Queue or {}
XLIB.Tests.Errored = XLIB.Tests.Errored or {}
XLIB.Tests.Succeeded = XLIB.Tests.Succeeded or {}

-- FIXME: Currently assigned but never used.
XLIB.Tests.QUEUED = 1
XLIB.Tests.RUNNING = 2
XLIB.Tests.SUCCESS = 3
XLIB.Tests.FAILED = 4

local function log(col, ...)
	local s = SPrint("XLib Tests: ", ...)
	MsgC(col, s .. "\n")
end

local Log = f.apply(log, Color(0, 255, 150))
local Err = f.apply(log, Color(255, 0, 0))

XLIB.PostInitEntity(function()
	timer.Create("XLib Start Tests", 0, 1, function()
		XLIB.Tests.Started = true

		while true do
			if #XLIB.Tests.Queue == 0 then break end

			local v = table.remove(XLIB.Tests.Queue, 1)
			if not v then break end

			v.run()
		end
	end)
end)


local function concat(t)
	local s = ""
	for _, v in ipairs(t) do
		s = s .. "][" .. tostring(v)
	end

	return s:Trim()
end

function XLIB.CompareString(cmpa, cmpb)
	if cmpa == cmpb then return true end

	local reason = ""
	local stralen, strblen = cmpa:len(), cmpb:len()

	local len = math.min(stralen, strblen)

	if stralen != strblen then
		reason = ("String lengths differed A: %d B: %d\n"):format(stralen, strblen)
	end

	for i=1, len do
		if cmpa[i] != cmpb[i] then
			local inspectLen = 30
			local back = math.min(i, inspectLen)
			reason = reason ..  "A: "..cmpa:sub((i-back + 1), i+inspectLen).."\n"..
								(" "):rep(back+2).."|\n".. 
								"B: "..cmpb:sub((i-back + 1), i+inspectLen)
			break
		end
	end

	return false, reason
end

local stack
local function ret(val, va, vb, reason)
	if not val and stack and not reason then
		local path = ""
		while stack:Top() do
			path = stack:Pop().."]["..path
		end
		path = "["..path:sub(1, path:len()-1)

		reason = "Differed on index "..path..":".."\n"..
				 "A"..path..": "..tostring(va).."\n"..
				 "B"..path..": "..tostring(vb).."\n"
		stack = nil
	end

	return val, reason
end
function XLIB.Compare(a, b, nometa, visited)
	visited = visited or {}
	if not stack then
		stack = util.Stack()
	end

	if istable(a) then
		if istable(b) and a == b then return ret(true) end
		if visited[a] then return ret(true) end
		visited[a] = true
	end

	if istable(b) then
		if visited[b] then return ret(true) end
		visited[b] = true
	end

	if isstring(a) and isstring(b) and a != b then
		local succ, reason = XLIB.CompareString(a, b)
		if not succ then
			stack = nil
			return ret(false, a, b, "Strings differed:\n"..reason)
		else
			return true
		end
	end


	-- nil and 'no value' are different and won't pass type()
	if a == nil or b == nil then return ret(a == b, a, b) end
	if type(a) != type(b) then return ret(false, a, b) end
	if not istable(a) and not istable(b) then return ret(a == b, a, b) end
	if isfunction((getmetatable(a) or {}).__eq) then return ret(a == b, a, b) end

	local get = nometa and f.index or rawget

	for k, va in pairs(a) do
		local vb = get(b, k)
		stack:Push(k)
		local succ, reason = XLIB.Compare(va, vb, nometa, visited)
		if not succ then return ret(false, va, vb, reason) end
		stack:Pop()
	end


	for k, vb in pairs(b) do
		local va = get(a, k)
		stack:Push(k)
		local succ, reason = XLIB.Compare(va, vb, nometa, visited)
		if not succ then return ret(false, va, vb, reason) end
		stack:Pop()
	end

	return true
end

function XLIB.Test(name, test)
	local testData = {id = name, test=test, status=XLIB.Tests.QUEUED}

	local function callback(reason, cmpa, cmpb)
		-- Be careful, as soon as the first assertion callback is called,
		-- the entire test is considered "complete" in the eyes of
		-- the player connection denial gate.


		local success, err = false
		if isbool(cmpa) and cmpb == nil then
			success = cmpa
		elseif isstring(cmpa) and isstring(cmpb) then
			success, err = XLIB.CompareString(cmpa, cmpb)
		else
			success, err = XLIB.Compare(cmpa, cmpb)
		end

		local fmt = ('[ %s ] -> [ %s ]'):format(name, reason)

		if success then
			testData.status = XLIB.Tests.SUCCESS

			XLIB.Tests.Errored[fmt] = nil
			XLIB.Tests.Succeeded[fmt] = testData

			Log("Passed - ", fmt)
			if err then Log(err) end
		else
			testData.status = XLIB.Tests.FAILED

			XLIB.Tests.Succeeded[fmt] = nil
			XLIB.Tests.Errored[fmt] = testData

			testData.failReason = reason
			Err("Failed - ", fmt)
			if err then Err(err) end

			if sentry then
				sentry.ReportError("Server startup blocked by failed test " .. name .. ": " .. reason, {}, { err=err })
			end
		end
	end

	local function done()
		table.RemoveByValue(XLIB.Tests.Queue, testData)
	end

	function testData.run()
		Log("Running test", name)
		testData.status = XLIB.Tests.RUNNING

		XLIB.Tests.Errored[name] = nil

		local fmt = ('[ %s ] ->'):format(name, reason)
		local _Log = f.apply(Log, "Info   - ", fmt)
		local _Err = f.apply(Err, "Error  - ", fmt)

		local succ, err = xpcall(test, debug.traceback, callback, _Log, _Err)
		if not succ then
			Err("Error occurred while performing test")
			Err(err)
			testData.status = XLIB.Tests.FAILED
			XLIB.Tests.Errored[name] = true

			if sentry then
				sentry.ReportError("Server startup blocked by ERRORED test " .. name, {}, { err=err })
			end
		end
	end


	if XLIB.Tests.Started then
		testData.run()
	else
		table.insert(XLIB.Tests.Queue, testData)
		Log("Queueing test", name)
	end
end

hook.Add("CheckPassword", "XLIB.TestSuite", function()
	if #XLIB.Tests.Queue > 0 then
		return false, "Server is currently performing self-tests"
	end

	for k, v in pairs(XLIB.Tests.Errored) do
		return false, "Server is in errored state"
	end
end)

DevCommand("xlib_teststatus", function()
	Log("Current test status:")

	for k, v in pairs(XLIB.Tests.Queue) do
		Log("Running:", v.name)
	end

	for k, v in pairs(XLIB.Tests.Errored) do
		Err("Failed:", k)
	end

	for k, v in pairs(XLIB.Tests.Succeeded) do
		Log("Succeeded:", k)
	end
end)

DevCommand("xlib_cleartests", function()
	XLIB.Tests.Errored = {}
	XLIB.Tests.Queue   = {}
end)

XLIB.Test("Make sure the test suite works", function(assert)
	assert("This works", true)
	-- assert("String Comparison", "0123456789qwertyuiopasd?ghjklzxcvbnm,/;'[]-=`~!@#$%^&*()_+", "0123456789qwertyuiopasdfghjklzxcvbnm,/;'[]-=`~!@#$%^&*()_+")
end)
