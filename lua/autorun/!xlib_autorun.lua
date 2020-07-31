-- If you want to modify XLib itself with autorefresh support,
-- Create an empty `XLIB_AUTOLOAD` file in the garry's mod directory

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
