NetWrapper
==========

The NetWrapper library is a simple wrapper over Garry's standard net library to provide lightweight
networking without needing to care about the type of data you are networking (unlike the ENTITY:SetNetworked* library)
and without needing to create dozens of networked strings for net messages.

There are 4 ways to network data with the NetWrapper library:
* Net Vars
* Net Requests
* Client Vars
* Global Vars

## Net Vars
If you are looking to replace your existing scripts' use of the ENTITY:SetNW*/ENTITY:SetDT* functions, Net Vars
are the way to go.

With Net Vars, data set on entities is only networked when the data is added or changed with
ENTITY:SetNetVar( key, value ) from the server. By broadcasting net messages only when
the data changes, this library has a relatively low impact on network traffic.

Once these values have been broadcasted, all connected clients will be able to retrieve the values like you
would with the standard networking libraries.

* Setting networked values:

```lua
-- if run on the server, this key/value pair will be networked to all clients
ENTITY:SetNetVar( key, value )
```

* Getting networked values:

```lua
-- if run on the client, this will attempt to grab the value stored at the key
ENTITY:GetNetVar( key, default )
```

Where 'default' is the default value you would like returned if the key doesn't exist.
If a default value isn't provided and the key doesn't exist, nil will be returned.

### Example:

If you wanted to network a title on a player when they connect, you could do something like the following:
```lua
hook.Add( "PlayerInitialSpawn", "SetPlayerTitle", function( ply )
    local title = ... -- grab the title somewhere
    ply:SetNetVar( "Title", title )
end )
```
As soon as ply:SetNetVar() is called, a net message will be broadcasted to all connected clients with the
key/value pair for the title.

If you wanted to show the player's title in a GM:PostPlayerDraw hook, you could do something like the following:
```lua
hook.Add( "PostPlayerDraw", "ShowPlayerTitle", function( ply )
    -- retrieve the player's title if one has been networked, otherwise returns nil
    -- if a title hasn't been networked yet, don't try drawing it

    local title = ply:GetNetVar( "Title" )
    if ( not title ) then return end

    draw.SimpleText( title, ...  -- etc

end )
```

## Net Requests
Net Requests are a new feature in the NetWrapper library. They allow you to determine exactly when a client asks the server
for a value to be networked to them by using ENTITY:SendNetRequest( key ).

If the server has set data on the entity with ENTITY:SetNetRequest( key, value ), the value will be sent back to the client
when they request it. If the server has not set any data on the entity at the given key, the client will keep sending requests
(as long as you use ENTITY:SendNetRequest( key ) again) until they have either reached the maximum amount of requests that can
be sent per entity+key (netwrapper_max_requests cvar) or the value has been set by the server.

This is especially useful if you have hundreds or thousands of entities spawned out when clients join the server. If you networked
a value using ENTITY:SetNetVar() on every entity, that means that the client will receive hundreds or thousands of net messages to
sync all of the Net Vars when they initialize during GM:InitPostEntity. However, by using Net Requests instead you can network data
to the client only when they ask for it (such as when they look directly at it).

* Setting net requests:

```lua
ENTITY:SetNetRequest( key, value ) -- if run on the server, this key/value pair will be stored in a serverside table that the client can request from
```

* Getting net requests:

```lua
ENTITY:SendNetRequest( key ) -- when run on the client, this will send a net message to the server asking for the value stored on the entity at the given key
ENTITY:GetNetRequest( key, default ) -- once the client has received the value from the server, subsequent calls to ENTITY:GetNetRequest() will return the value
```

Where 'default' is the default value you would like returned if the key doesn't exist.
If a default value isn't provided and the key doesn't exist, nil will be returned.

### Example:

If you want to network the owner's name on props but don't want to flood connecting clients with hundreds of possible net messages,
you can do something like the following:
```lua
-- some serverside function that pairs up the player with the entity they spawned
ent:SetNetRequest( "Owner", ply:Nick() )
```

Now the value has been stored in the netwrapper.requests table and can be accessed by clients when they request it:
```lua
-- somewhere clientside
local owner = ent:GetNetRequest( "Owner" )
if ( not owner ) then ent:SendNetRequest( "Owner" ) end
```

Assuming you use the above in a HUDPaint hook or something that gets repeatedly gets called, this will check to see if the 'Owner' value has
already been requested from the server. If it hasn't (and therefore returns nil), ent:SendNetRequest( "Owner" ) is called which sends a request
to the server asking for the value stored at the 'Owner' key.

Since the 'Owner' was set earlier, the server will reply to the client's request by sending a net message back with the entity and key/value pair.
When the clients receives the message, the value is stored in the netwrapper.requests table and will be retrieved with any subsequent calls to ent:GetNetRequest( "Owner" ).


## Client Vars
Client Vars use the same technology as Net Vars behind the scenes, with the main difference being that the values will only be networked to that specific client.


* Setting client values:

```lua
-- if run on the server, this key/value pair will be networked to the associated player only
PLAYER:SetClientVar( key, value )
```

* Getting client values:

```lua
-- this will attempt to grab the value stored at the key
PLAYER:GetClientVar( key, default )

-- or clientside only
netwrapper.GetClientVar( key, default ) = LocalPlayer():GetClientVar( key, default )

```

Where 'default' is the default value you would like returned if the key doesn't exist.
If a default value isn't provided and the key doesn't exist, nil will be returned.

### Example:

If you wanted to network a player's money, which other players do not need to know about
```lua
hook.Add( "PlayerInitialSpawn", "SetPlayerMoney", function( ply )
    local money = ... -- grab the money somewhere
    ply:SetClientVar( "Money", money )
end )
```
As soon as ply:SetClientVar() is called, a net message will be sent to the respective client with the key/value pair for the money.

If you wanted to show the player's money in a GM:HUDPaint hook, you could do something like the following:
```lua
hook.Add( "HUDPaint", "ShowPlayerMoney", function( )
    local money = netwrapper.GetClientVar( "Money" )
    if ( not money ) then return end

    draw.SimpleText( tostring( money ), ...  -- etc
end )
```


## Global Vars
Global Vars are a wrapper around Net Vars.
Internally, they translate to game.GetWorld():Set/GetNetVar()


* Setting global values:

```lua
-- if run on the server, this key/value pair will be broadcasted to all players
netwrapper.SetGlobalVar( key, value )
```

* Getting global values:

```lua
-- this will attempt to grab the value stored at the key
netwrapper.GetGlobalVar( key, value, default )

```

Where 'default' is the default value you would like returned if the key doesn't exist.
If a default value isn't provided and the key doesn't exist, nil will be returned.



## Net Hooks
NetWrapper also exposes a hook functionality.
This allows you to have callback function be called whenever data changes whether it be Net Vars, Client Vars or Global Vars.
**Net Requests are currently unsupported.**

Hooks require you to specify
1. The key for which you would like to listen to
2. A unique identifier for the hook. This can be of any type you want.

**If the unique identifier is a table with an IsValid method, NetWrapper will call the IsValid function every time before calling the hook, and will automatically remove the hook if IsValid() returns false.**

This makes it easy to add a hook with an entity or panel object as the identifier.

* Adding and removing net hooks:

```lua
-- Add a hook for Global variables
netwrapper.AddGlobalHook( key, name, fn( key, value ) )
netwrapper.RemoveGlobalHook( key, name )

-- Add a hook that gets called whenever ANY entity's <key>'s <value> changes
netwrapper.AddNetHook( key, name, fn( ent, key, value ))
netwrapper.RemoveNetHook( key, name )

-- Add a hook specific to this entity's <key>'s <value> changing
ent:AddNetHook( key, name, fn( ent, key, value ))
ent:RemoveNetHook( key, name )

-- Automatically remove the hook when the entity gets removed
ent:AddNetHook( key, ent, fn( ent, key, value ))

-- Could be useful server-side too
ply:AddCLNetHook( key, name, fn( ent, key, value ) )
ply:RemoveCLnetHook( key, name )

-- Once again automatically remove the hook when the identifier:IsValid() returns false
ply:AddCLNetHook( key, ply, fn( ent, key, value ) )

netwrapper.AddCLNetHook( key, name, fn( ent, key, value ) )
netwrapper.RemoveCLHook( key, name )
```

### Example:
Add a ClientVar NetHook to reflect changes in a panel that gets automatically removed when the panel is removed
```lua
local label = vgui.Create( "DLabel" )

netwrapper.AddCLNetHook( "Money", label, function( ent, key, value )
    -- This hook gets removed if not IsValid( label ) so no need to check here!

    label:SetText( "Money: " .. value )
end)
```


## Persistence
NetWrapper allows you to easily restore a player's data (NetVars, NetRequests, ClientVars) if the player were to reconnect.

This persistence is stored within the lua state. **This means it resets upon map change or server restart**

It is only useful for **VOLATILE** data, such as a player's score or kill count in the current map or round.

When a player disconnects, any NetVars, NetRequests or ClientVars whose key has been defined as a persistent variable will be saved and associated with their Steam ID. When the player reconnects, an attempt is made at restoring those values.

* Defining a persistent value:
```lua
-- This will save any NetVar, NetRequest or GlobalVar with this key when a player disconnects.
netwrapper.DefinePersistentVar( key )


-- If, for whatever reason, you need to prevent a value from being saved for X amount of time,
-- you can unregister it using the following function and netwrapper will discard the values with
-- the associated key when a player disconnects.

-- Note that this does NOT erase values of previously disconnected / pending players.
netwrapper.UndefinePersistenceVar( key )
```

### Example:
Store a player's temporary happiness value and restore it on reconnect
```lua
netwrapper.DefinePersistenceVar( "Happiness" )

ply:SetNetVar( "Happiness", 6 )
ply:Kick()

-- Player reconnects

print( ply:GetNetVar( "Happiness" ) )
-- 6
```


QUESTIONS & ANSWERS
-------------------

### Q: What sort of data can I network with this library?

A: Since this is a wrapper library over the standard net library, all limitations of the net library apply here.
For example, you can't network functions or user data.

What you CAN network:
* nil
* strings
* numbers
* tables
* booleans
* entities
* vectors
* angles

---------------------------------------------------------------------------------------------------------------------------
### Q: How often is the data networked?

A:
##### For Net Vars, Client Vars and Global Vars:
Every time you use ENTITY:SetNetVar( key, value ) from the server, the data will be networked to any clients via net message.

If you set a value on a player and then change that value 5 minutes later, the data will have been broadcasted only 2 times
over the span of that 5 minutes.

However, this does mean that if you use ENTITY:SetNetVar( key value ) in a think hook, it will be broadcasting net messages every frame.

As with any other function, be sure to set networked data only as often as you need to. Think hooks should typically be
avoided if you plan on networking large amounts of data on a large amount of entities/players.

##### For Net Requests:
Whereas Net Vars are automatically broadcasted to connected clients, and synced to connecting clients during GM:InitPostEntity, Net Requests are only networked
on a 'need-to-know' basis, which significantly reduces the amount of network traffic that connecting players receive.

---------------------------------------------------------------------------------------------------------------------------
### Q: What happens when clients connect after the data has already been broadcasted?

A:
##### For Net Vars:
When a client fully initializes on the server (during the GM:InitPostEntity hook, clientside), they will send a net message to
the server that requests any data that is currently being networked on any entities.

This happens automatically so that you don't have to rebroadcast the data yourself.

##### For Net Requests:
Net Requests are not networked to the client unless they specifically ask the server for a value from an entity. You must manually
use ENTITY:SendNetRequest( key ) to network the value.

---------------------------------------------------------------------------------------------------------------------------
### Q: What happens to the networked data on a player that disconnected, or an entity that was removed?

A: When a player disconnects or an entity is removed, the netwrapper library will automatically sanitize its tables by
using the GM:EntityRemoved hook on the server and removing any [non-persistent](#persistence) data it currently has networked with that entity. The server will then send a net message to the client informing them to sanitize their clientside tables.

[Persistent](#persistence) values will be restored when a player reconnects.
