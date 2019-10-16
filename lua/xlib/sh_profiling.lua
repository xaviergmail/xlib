local time = {}
local nf = util.NiceFloat

local EVENT = 1
local PRINT = 2

function time:Start()
	self.start = SysTime()
	self.finished = nil
	self.events = {}
	self.prints = {}
	return self
end

function time:Log(event)
	if not self.start then
		self:Start()
	end

	-- Print later so as to not induce too much blocking I/O
	table.insert(self.events, {EVENT, event, SysTime()})
end

function time:Finish()
	self.finished = SysTime()

	local last = self.start
	for k, v in ipairs(self.events) do
		if v[1] == EVENT then
			self:Print(v[2], "took", nf(v[3]-last), " - T+"..nf(v[3]-self.start))
			last = v[3]
		elseif v[1] == PRINT then
			self:Print(table.UnpackNil(v[2]))
		end
	end

	self:Print("Finished in ", nf(self.finished-self.start))

	self.start = nil
end

function time:Print(...)
	if self.finished then
		MsgC(Color(31, 255, 150), SPrint("["..self.name.."] ", ...).."\n")
	else
		table.insert(self.events, {PRINT, table.PackNil(...)})
	end
end

function XLIB.Time(name)
	if not name or not tostring(name) then
		XLIB.WarnTrace("XLIB.Time needs a stringable identifier!!!")
		name = SysTime()
	end
	return setmetatable({name=tostring(name)}, {__index=time, __call=time.Log})
end
