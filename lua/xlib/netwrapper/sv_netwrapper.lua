--[[ -------------------------------------------------------------------------
--	File name:
--		sv_netwrapper.lua
--
--	Authors:
--		Mista-Tea ([IJWTB] Thomas)
--		xaviergmail (Xavier Bergeron)
--
--	License:
--		The MIT License (copy/modify/distribute freely!)
--
--	Changelog:
--		- March 9th,   2014:    Created
--		- April 5th,   2014:    Added to GitHub
--		- August 15th, 2014:    Added Net Requests
--		- April  25th, 2019:	Added Net Hooks, Global Vars, Client Vars, Persistence
----------------------------------------------------------------------------]]

--[[ -------------------------------------------------------------------------
-- 	Namespace Tables
--------------------------------------------------------------------------]]--

netwrapper                 = netwrapper                 or {}
netwrapper.ents            = netwrapper.ents            or {}
netwrapper.clients         = netwrapper.clients         or {}
netwrapper.requests        = netwrapper.requests        or {}
netwrapper.persistentvars  = netwrapper.persistentvars  or {}
netwrapper.plypersistence  = netwrapper.plypersistence  or {}

--[[ -------------------------------------------------------------------------
-- 	Localized Functions & Variables
--------------------------------------------------------------------------]]--

local net = net
local util = util
local pairs = pairs
local IsEntity = IsEntity
local CreateConVar = CreateConVar
local FindMetaTable = FindMetaTable

util.AddNetworkString( "NetWrapperVar" )
util.AddNetworkString( "NetWrapperRequest" )
util.AddNetworkString( "NetWrapperClear" )
util.AddNetworkString( "NetWrapperClearAll" )

local ENTITY = FindMetaTable( "Entity" )

--[[ -------------------------------------------------------------------------
-- 	Namespace Functions
--------------------------------------------------------------------------]]--

--[[ -------------------------------------------------------------------------
--	NET VARS
--------------------------------------------------------------------------]]--

--[[ -------------------------------------------------------------------------
--
--	Net - NetWrapperVar
--
--	Received when a player fully initializes with the InitPostEntity hook.
--	 This will sync all currently networked entities to the client.
--]]--
net.Receive( "NetWrapperVar", function( len, ply )
	netwrapper.SyncClient( ply )
end )

--[[ -------------------------------------------------------------------------
--
--	netwrapper.SyncClient( player )
--
--	Loops through every entity currently networked and sends the networked
--	 data to the client. This will also network any persistent ClientVars.
--
--	While looping, any values that are NULL (disconnected players, removed entities)
--	 will automatically be removed from the table and not synced to the client.
--]]--
function netwrapper.SyncClient( ply )
	for id, values in pairs( netwrapper.ents ) do
		for key, value in pairs( values ) do
			if ( IsEntity( value ) and !value:IsValid() ) then
				netwrapper.ents[ id ][ key ] = nil
				continue;
			end

			netwrapper.SendNetVar( ply, id, key, value )
		end
	end

	for key, value in pairs( netwrapper.GetClientVars( ply:NWIndex() ) ) do
		if ( IsEntity( value ) and !value:IsValid() ) then
			netwrapper.clients[ ply:NWIndex() ][ key ] = nil
			continue;
		end

		netwrapper.SendNetVar( ply, ply:NWIndex(), key, value, true )
	end
end

--[[ -------------------------------------------------------------------------
--
--	netwrapper.BroadcastNetVar( int, string, * )
--
--	Sends a net message to all connectect clients containing the
--	 key/value pair to assign on the associated entity.
--]]--
function netwrapper.BroadcastNetVar( id, key, value )
	net.Start( "NetWrapperVar" )
		net.WriteUInt( id, 32 )
		net.WriteString( key )
		net.WriteType( value )
		net.WriteBool( false )
	net.Broadcast()
end

--[[ -------------------------------------------------------------------------
--
--	netwrapper.SendNetVar( player, int, string, *, boolean )
--
--	Sends a net message to the specified client containing the
--	 key/value pair to assign on the associated entity.
--]]--
function netwrapper.SendNetVar( ply, id, key, value, clientvar )
	net.Start( "NetWrapperVar" )
		net.WriteUInt( id, 32 )
		net.WriteString( key )
		net.WriteType( value )
		net.WriteBool( clientvar )
	net.Send( ply )
end



--[[ -------------------------------------------------------------------------
--	NET REQUESTS
--------------------------------------------------------------------------]]--

--[[ -------------------------------------------------------------------------
--
--	Net - NetWrapperRequest
--
--	Received from a client when they are requesting a certain key on an entity
--	 that was set using ENTITY:SetNetRequest().
--
--	**UNLIKE the NetVars portion of the netwrapper library, Net Requests are stored
--	 on the server and are ONLY networked when the client sends a request for it.
--	 This can be incredibly helpful in reducing network traffic for connecting clients
--	 when you have data that doesn't need to be networked instantly.
--
--	For example, if you wanted to network the owner's name of a prop to clients, but
--	 fear you may be sending too much network traffic to connecting clients because there
--	 are hundreds or thousands of props out, you can use ENTITY:SetNetRequest() instead.
--	 When the client looks at a prop, you can add a check to see if ENTITY:GetNetRequest()
--	 doesn't return anything and then use ENTITY:SendNetRequest() to request the prop owner's
--	 name from the server.
--]]--
net.Receive( "NetWrapperRequest", function( bits, ply )
	local id  = net.ReadUInt( 32 )
	local ent = netwrapper.Entity( id )
	local key = net.ReadString()

	if ( ent:GetNetRequest( key ) ~= nil ) then
		netwrapper.SendNetRequest( ply, id, key, ent:GetNetRequest( key ) )
	end
end )

--[[ -------------------------------------------------------------------------
--
--	netwrapper.SendNetRequest( player, number, string, * )
--
--	Called when a client is asking the server to network a stored value on entity
--	 with the given key. In combination with ENTITY:SendNetRequest() on the client,
--	 these functions give you control of when a client asks for entity values to be
--	 networked to them, unlike the netwrapper.SendNetVar() function.
--]]--
function netwrapper.SendNetRequest( ply, id, key, value )
	net.Start( "NetWrapperRequest" )
		net.WriteUInt( id, 32 )
		net.WriteString( key )
		net.WriteType( value )
	net.Send( ply )
end


--[[ -------------------------------------------------------------------------
--
--	netwrapper.DefinePersistentVar( string )
--
--	Marks a specific NetVar / NetRequest key to be saved upon a player disconnecting to be restored
--   in the future upon reconnection.
--
--  NOTE: This persistence is only for the current game session and should only be used
--   for VOLATILE data. An example use would be to store a player's score for the current
--   round. NetWrapper will handle restoring this data for you if a player reconnects.
--
--  ** Any level change or server restart will wipe this stored data. **
--]]--
function netwrapper.DefinePersistentVar( key )
	netwrapper.persistentvars[ key ] = true
end

--[[ -------------------------------------------------------------------------
--
--	netwrapper.UndefinePersistentVar( string )
--
--	Removes a specific NetVar / NetRequest key from the player disconnection persistence list
--]]--
function netwrapper.UndefinePersistentVar( key )
	netwrapper.persistentvars[ key ] = true
end

--[[ -------------------------------------------------------------------------
--
--	netwrapper.FilterPersistentVars( table )
--
--	Modifies the input table to remove any keyvalue pairs whose key does not
--   appear in the variable persistence list
--
--  Returns: The modified input table
--]]--
function netwrapper.FilterPersistentVars( tbl )
	tbl = tbl or {}
	for k, v in pairs( tbl ) do
		if not netwrapper.persistentvars[ k ] then
			tbl[ k ] = nil
		end
	end

	return tbl
end

--[[ -------------------------------------------------------------------------
--
-- 	Hook - EntityRemoved( entity )
--
-- 	Called when an entity has been removed. This will automatically remove the
-- 	 data at the entity's index if any was being networked. This will prevent
-- 	 data corruption where a future entity may be using the data from a previous
--	 entity that used the same NWIndex
--
--  If the entity being removed is a player (upon disconnecting), the player's
--   NetVars / NetRequests that have been marked for persistence using
--   netwrapper.DefinePersistentVar will be stored (saved by Steam ID)
--   for re-assignment in case the player reconnects.
--]]--
hook.Add( "EntityRemoved", "NetWrapperClear", function( ent )
	-- TODO: Batch this to send once per tick rather than several times for batch removals
	if ( ent:IsPlayer() ) then
		netwrapper.plypersistence[ ent:SteamID() ] = {
			netwrapper.FilterPersistentVars( netwrapper.ents[ ent:NWIndex() ] ),
			netwrapper.FilterPersistentVars( netwrapper.requests[ ent:NWIndex() ] ),
			netwrapper.FilterPersistentVars( netwrapper.clients[ ent:NWIndex() ] ),
		}
	end

	netwrapper.ClearData( ent:NWIndex() )
end )

--[[ -------------------------------------------------------------------------
--
-- 	Hook - OnEntityCreated( entity )
--
-- 	Called when an entity has been created. This will automatically restore any
--   NetVars / NetRequests on players whose keys were saved by
--   netwrapper.DefinePersistentVar when the player disconnected.
--]]--
hook.Add( "OnEntityCreated", "NetWrapperRestore", function ( ent )
	if ( not ent:IsPlayer() ) then return end

	local stored = netwrapper.plypersistence[ ent:SteamID() ]

	if ( stored ) then
		netwrapper.ents[ ent:NWIndex() ]     = stored[ 1 ]
		netwrapper.requests[ ent:NWIndex() ] = stored[ 2 ]
		netwrapper.clients[ ent:NWIndex() ]  = stored[ 3 ]
	end
end )
