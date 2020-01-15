if CLIENT then return end
local succ, mobdebug = pcall(require, "mobdebug")
if not succ then
    XLIB.Warn("MobDebug failed loading:", mobdebug)
end

function DEBUG()
    if mobdebug then
        mobdebug.start('127.0.0.1', SERVER and 9000 or 9005)
    else
        error("Attempt to set breakpoint but mobdebug did not load!")
    end
end
