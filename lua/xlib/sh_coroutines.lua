function XLIB.Coroutine(fn)
    local id = "Coro."..tostring(fn)

    local function finish()
        hook.Remove("Tick", id)
    end

    local coro = coroutine.create(fn)
    hook.Add("Tick", id, function()
        coroutine.resume(coro)
        if coroutine.status(coro) == "dead" then
            finish()
        end
    end)

    return {
        id = id,
        cancel = finish,
    }
end