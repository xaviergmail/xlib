--[[--------------------------------------------------------------------------
	File name:
		cl_netwrapper.lua
	
	Authors:
		Mista-Tea ([IJWTB] Thomas)
		xaviergmail (Xavier Bergeron)
	
	License:
		The MIT License (copy/modify/distribute freely!)
		
	Changelog:
		- March 9th,   2014:    Created
		- April 5th,   2014:    Added to GitHub
		- August 15th, 2014:    Added Net Requests
		- April  25th, 2019:	Added Net Hooks, Global Vars, Client Vars, Persistence
----------------------------------------------------------------------------]]

--[[--------------------------------------------------------------------------
--		Namespace Tables 
--------------------------------------------------------------------------]]--

netwrapper          = netwrapper          or {}
netwrapper.requests = netwrapper.requests or {}

--[[--------------------------------------------------------------------------
-- 	Localized Functions & Variables
--------------------------------------------------------------------------]]--

local net  = net
local hook = hook
local pairs = pairs
local CurTime = CurTime
local FindMetaTable = FindMetaTable
local GetConVarNumber = GetConVarNumber

local ENTITY = FindMetaTable( "Entity" )

--[[--------------------------------------------------------------------------
--		Namespace Functions
--------------------------------------------------------------------------]]--

--[[--------------------------------------------------------------------------
--	NET VARS
--------------------------------------------------------------------------]]--

--[[--------------------------------------------------------------------------
--
--	Net - NetWrapperVar( entity, string, uint, * )
--
--	Retrieves a networked key/value pair from the server to assign on the entity.
--	 The value is written on the server using WriteType, so ReadType is used
--	 on the client to automatically retrieve the value for us without relying
--	 on multiple functions (like ReadEntity, ReadString, etc).
--]]--

local function store( entid, key, value, client )
	if client then
		netwrapper.StoreClientVar( entid, key, value )
	else
		netwrapper.StoreNetVar( entid, key, value )
	end
end

net.Receive( "NetWrapperVar", function( len )
	local entid  = net.ReadUInt( 16 )
	local key    = net.ReadString()
	local typeid = net.ReadUInt( 8 )      -- read the prepended type ID that was written automatically by net.WriteType(*)

	local value, ventid
	if typeid == TYPE_ENTITY then
		ventid = net.ReadUInt( 16 )
		if ventid then
			value = Entity(ventid)
		end
	else
		value = net.ReadType( typeid ) -- read the data using the corresponding type ID
	end

	local client = net.ReadBool() -- whether this variable is client-specific

	if value == NULL then
		local hkName = "NetWrapper_EntVar_"..entid.."_"..key
		hook.Add( "OnEntityCreated", hkName, function( ent )
			if ent:EntIndex() == ventid then
				hook.Remove( "OnEntityCreated", hkName )
				store( entid, key, ent, client )
			end
		end)
	else
		store( entid, key, value, client )
	end
end )

--[[--------------------------------------------------------------------------
--
--	Hook - InitPostEntity
--
--	When the client has fully initialized in the server, this will send a
--	 request to retrieve all currently networked values from the server.
--]]--
hook.Add( "InitPostEntity", "NetWrapperSync", function()
	net.Start( "NetWrapperVar" )
	net.SendToServer()
end )

--[[--------------------------------------------------------------------------
--
--	Hook - OnEntityCreated
--
--	This hook is called every time an entity is created. This will automatically
--	 assign any networked values that are associated with the entity's EntIndex.
--	 This saves us the trouble of polling the server to retrieve the values.
--]]--
hook.Add( "OnEntityCreated", "NetWrapperSync", function( ent )
	local id = ent:EntIndex()
	
	for key, value in pairs( netwrapper.GetNetVars( id ) ) do
		ent:SetNetVar( key, value, true )
	end

	for key, value in pairs( netwrapper.GetClientVars( id ) ) do
		ent:SetClientVar( key, value, true )
	end
end )



--[[--------------------------------------------------------------------------
--	NET REQUESTS
--------------------------------------------------------------------------]]--

--[[--------------------------------------------------------------------------
--
--	ENTITY:SendNetRequest( key )
--
--	Wrapper function for netwrapper.SendNetRequest().
--
--]]--
function ENTITY:SendNetRequest( key )
	netwrapper.SendNetRequest( self:EntIndex(), key )
end

--[[--------------------------------------------------------------------------
--
--	netwrapper.SendNetRequest( number, string )
--
--	Sends a request to the server asking for a value stored on the entity with the given key.
--
--	This function allows you to determine exactly when a client asks the server for a networked
--	 variable, unlike with netwrapper NetVars which are automatically networked when a client connects to
--	 the server or the value is broadcasted to all connected clients.
--
--	You can think of Net Requests as a 'need-to-know' networking scheme, where the client only 
--	 asks for the networked variable when they need it (i.e., when you use this function).
--
--	Two cvars can help limit this function's potential for networking spamming:
--		- netwrapper_request_delay: the amount of seconds that must elapse in between each request
--		- netwrapper_max_requests:  the max amount of requests the client can send on a failed value request before stopping
--
--	To prevent clients from sending multiple requests for a value before the server has a chance to respond, you can use netwrapper_request_delay to determine
--	 the amount of time that must elapse before another request can be sent. The default is 5 seconds.
--
--	If a request fails because the server hasn't set any data on the entity at the given key, you can send another request for the value. However,
--	 if the client keeps requesting the same key from an entity that will never have data set on it, you can use netwrapper_max_requests to limit the number
--	 of allowed requests before the client ultimately stops sending requests for the value altogether. The default is -1 (unlimited retries).
--]]--
function netwrapper.SendNetRequest( id, key )
	
	local requests = netwrapper.requests

	if ( !requests[ id ] )                  then requests[ id ] = {} end
	if ( !requests[ id ][ "NumRequests" ] ) then requests[ id ][ "NumRequests" ] = 0 end
	if ( !requests[ id ][ "NextRequest" ] ) then requests[ id ][ "NextRequest" ] = CurTime() end
	
	local maxRetries = netwrapper.MaxRequests:GetInt()
	
	-- if the client tries to send another request when they have already hit the maximum number of requests, just ignore it
	if ( maxRetries >= 0 and requests[ id ][ "NumRequests" ] >= maxRetries ) then return end
	
	-- if the client tries to send another request before the netwrapper_request_delay time has passed, just ignore it
	if ( requests[ id ][ "NextRequest" ] > CurTime() ) then return end
	
	net.Start( "NetWrapperRequest" )
		net.WriteUInt( id, 16 )
		net.WriteString( key )
	net.SendToServer()
	
	requests[ id ][ "NextRequest" ] = CurTime() + netwrapper.Delay:GetInt()
	requests[ id ][ "NumRequests" ] = requests[ id ][ "NumRequests" ] + 1
end

--[[--------------------------------------------------------------------------
--
--	Net - NetWrapperRequest
--
--	Received from the server when a value request has been answered. This 
--	 will only occur when the client has send a value request and the server 
--	 actually has a value stored at the given key.
--]]--
net.Receive( "NetWrapperRequest", function( bits )
	local id     = net.ReadUInt( 16 )
	local key    = net.ReadString()
	local typeid = net.ReadUInt( 8 )
	local value  = net.ReadType( typeid )
	
	Entity( id ):SetNetRequest( key, value )
end )


--[[--------------------------------------------------------------------------
--
--	Net - NetWrapperClear
--
--	Removes any data stored at the entity index. When a player disconnects or
--	 an entity is removed, its index in the table will be removed to ensure that
--	 the next entity to use the same index does not use the first entity's data
--	 and become corrupted.
--]]--
net.Receive( "NetWrapperClear", function( bits )
	local id = net.ReadUInt( 16 )
	netwrapper.ClearData( id )
end )


--[[--------------------------------------------------------------------------
--	CLIENT VARS WRAPPER
--------------------------------------------------------------------------]]--

--[[--------------------------------------------------------------------------
--
--	netwrapper.SetClientVar( string, *, boolean [optional] )
--
--	Functionally identical to LocalPlayer():SetClientVar( ... )
--]]--
function netwrapper.SetClientVar( key, value, force )
	LocalPlayer():SetClientVar( key, value, force )
end

--[[--------------------------------------------------------------------------
--
--	netwrapper.GetClientVar( string, * )
--
--	Functionally identical to LocalPlayer():GetClientVar( ... )
--]]--
function netwrapper.GetClientVar( key, default )
	return LocalPlayer():GetClientVar( key, default )
end

--[[--------------------------------------------------------------------------
--
--	netwrapper.AddCLNetHook( string, string, function )
--
--	Functionally identical to LocalPlayer():AddCLNetHook( ... )
--]]--
function netwrapper.AddCLNetHook( key, name, fn )
	LocalPlayer():AddCLNetHook( key, name, fn )
end

--[[--------------------------------------------------------------------------
--
--	netwrapper.RemoveCLNetHook( string, string )
--
--	Functionally identical to LocalPlayer():RemoveCLNetHook( ... )
--]]--
function netwrapper.RemoveCLNetHook( key, name )
	LocalPlayer():RemoveCLNetHook( key, name )
end