if CLIENT then return end
local succ, err = pcall(require, "mobdebug")
if not succ then
    XLIB.Warn("MobDebug failed loading:", err)
end
