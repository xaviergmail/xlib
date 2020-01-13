local clfile = "xlib/xlib_autorun_cl.lua"

if SERVER then
    AddCSLuaFile()
    if file.Exists("XLIB_AUTOLOAD", "MOD") then
        AddCSLuaFile(clfile)
        print("Found XLIB_AUTOLOAD - including xlib from autorun")
        include("includes/modules/xlib.lua")
    end
else
    if file.Exists(clfile, "LUA") then
        include("includes/modules/xlib.lua")
    end
end