if CLIENT then return end
require "credentialstore"
if CREDENTIALS.production then return end

local succ, err = pcall(require, "mobdebug")
if not succ then
    XLIB.Warn("MobDebug failed loading:", err)
end
