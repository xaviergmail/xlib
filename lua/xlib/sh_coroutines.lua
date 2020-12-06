local coro_mt = {}
coro_mt.__index = coro_mt

function coro_mt:hook()
    hook.Add("Tick", self.id, function()
        self:step()
    end)
end

function coro_mt:unhook()
    hook.Remove("Tick", self.id)
end

function coro_mt:step(...)
    local ret = { coroutine.resume(self.thread, ...) }
    if coroutine.status(self.thread) == "dead" then
        self:finish(unpack(ret))
        return false
    end

    return true
end

function coro_mt:start()
    if self:step(self) then
        self:resume()
    end
end

function coro_mt:pause()
    self.running = false
    self:unhook()
    coroutine.yield()
end

function coro_mt:resume()
    self.running = true
    if self:step() then
        self:hook()
    end
end

function coro_mt:finish(...)
    self:unhook()
    if isfunction(self.callback) then
        self.callback(...)
    else
        local succ, msg = ...
        if succ == false then
            ErrorNoHalt("Coroutine failed", msg.."\n")
        end
    end
end

XLIB.Coroutine = {
    Start = function(fn, callback, _)
        local id = tostring(fn)
        if isstring(id) then
            fn = callback
            callback = _
        end

        local coro = setmetatable({
            id = "Coro."..id,
            thread = coroutine.create(fn),
            running = true,
            callback = callback
        }, coro_mt)

        coro:start()

        return coro
    end
}
setmetatable(XLIB.Coroutine, { __call=function(t, ...) return XLIB.Coroutine.Start(...) end })

function XLIB.Coroutine.WaitForFile(fname, path, timeout, waitfor)
    timeout = timeout or 10
    waitfor = waitfor or 0.2

    local start = SysTime()
    while not file.Exists(fname, path) do
        if SysTime() - start >= timeout then
            return false
        elseif waitfor <= 0 then
            coroutine.yield()
        else
            coroutine.wait(waitfor)
        end
    end

    return true
end