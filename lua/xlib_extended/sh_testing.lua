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
	local s = "XLib Tests: "
	for k, v in ipairs({...}) do
		s = s .. tostring(v) .. " "
	end

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

function XLIB.Test(name, test)
	local testData = {id = name, test=test, status=XLIB.Tests.QUEUED}

	local function callback(reason, success, strb)
		-- Be careful, as soon as the first assertion callback is called,
		-- the entire test is considered "complete" in the eyes of
		-- the player connection denial gate.
		local stra
		if isstring(success) then
			stra = success
			success = stra == strb
		end

		local fmt = ('[ %s ] -> [ %s ]'):format(name, reason)

		if success then
			testData.status = XLIB.Tests.SUCCESS

			XLIB.Tests.Errored[fmt] = nil
			XLIB.Tests.Succeeded[fmt] = testData

			Log("Passed - ", fmt)
		else
			testData.status = XLIB.Tests.FAILED

			XLIB.Tests.Succeeded[fmt] = nil
			XLIB.Tests.Errored[fmt] = testData

			testData.failReason = reason
			Err("Failed - ", fmt)

			if stra then
				local stralen, strblen = stra:len(), strb:len()

				local len = math.min(stralen, strblen)

				if stralen != strblen then
					Err(("String lenghts differed A: %d B: %d"):format(stralen, strblen))
				end

				for i=1, len do
					if stra[i] != strb[i] then
						local inspectLen = 30
						local back = math.min(i, inspectLen)
						Err("A:", stra:sub((i-back + 1), i+inspectLen))
						Err((" "):rep(back+2).."|")
						Err("B:", strb:sub((i-back + 1), i+inspectLen))
						break
					end
				end
			end
		end
	end

	local function done()
		table.RemoveByValue(XLIB.Tests.Queue, testData)
	end

	function testData.run()
		Log("Running test", name)
		testData.status = XLIB.Tests.RUNNING
		test(callback, Log, Err)
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

XLIB.Test("Make sure the test suite works", function(assert)
	assert("This works", true)
	-- assert("String Comparison", "0123456789qwertyuiopasd?ghjklzxcvbnm,/;'[]-=`~!@#$%^&*()_+", "0123456789qwertyuiopasdfghjklzxcvbnm,/;'[]-=`~!@#$%^&*()_+")
end)
