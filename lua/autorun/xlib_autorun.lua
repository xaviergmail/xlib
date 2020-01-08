local clfile = "xlib/xlib_autorun.lua"

if SERVER then
    AddCSLuaFile()
    if file.Exists("XLIB_AUTORUN", "MOD") then
        AddCSLuaFile(clfile)
        include("includes/modules/xlib.lua")
    end
else
    if file.Exists(clfile, "LUA") then
        include("includes/modules/xlib.lua")
    end
end