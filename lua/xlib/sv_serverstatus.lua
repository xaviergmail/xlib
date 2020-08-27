--- @module xlib.serverstatus
local numPlayers = 0
local visibleMax = GetConVar("sv_visiblemaxplayers")

gameevent.Listen("player_disconnect")
hook.Add("player_disconnect", "xmod.serverstatus", function(data)
    numPlayers = numPlayers - 1
end)

gameevent.Listen("player_connect")
hook.Add("player_connect", "xmod.serverstatus", function(data)
    numPlayers = numPlayers + 1
end)

--- Number of connected clients
--
-- This differs from `#player.GetAll()` in the sense that it
-- also accounts for players who currently are not fully authenticated
-- or spawned in yet.
function XLIB.GetNumPlayers()
    return numPlayers
end

--- Maximum amount of visible connected clients
--
-- Returns the value of sv_visiblemaxplayers or game.MaxPlayers(),
-- depending on which would be most appropriate.
function XLIB.VisibleMaxPlayers()
    local visible = visibleMax:GetInt() 
    return visible > 0 and visible or game.MaxPlayers()
end