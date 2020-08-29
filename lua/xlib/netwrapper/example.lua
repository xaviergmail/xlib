--[[ -------------------------------------------------------------------------
--	File name:
--		example.lua
--
--	Authors:
--		Mista-Tea ([IJWTB] Thomas)
--		xaviergmail (Xavier Bergeron)
--
--	License:
--		The MIT License (copy/modify/distribute freely!)
--
--	Changelog:
--		- March   9th, 2014:    Created
--		- April   5th, 2014:    Added to GitHub
--		- August 16th, 2014:    Rewrote example for Net Vars / Net Requests
--		- April  25th, 2019:	Added examples for Client Vars / Global Vars / Hooks
----------------------------------------------------------------------------]]

-- In this example, we will assign a player's name to the prop they spawn in PlayerSpawnedProp.
-- We'll use Net Vars in the first example to show how they automatically network themselves,
-- and then show how Net Requests can be used to ask for the value to be networked manually.
-- We will also cover global variables as well as client variables which are only sent to
-- the specific client which is useful to reduce network impact.

-- Example usage of hooks has been scattered throughout these examples






--[[ ----------------------------------------- ]]--
--                    Net Vars
--[[ ----------------------------------------- ]]--

-- Helper function for demo
local function fmtHook( ent, key, value )
	local prefix = SERVER and "SERVER: " or "CLIENT: "
	return prefix .. "Entity " .. tostring( ent ) .. " has just had their " ..
	       key .. " NetVar changed to " .. value
end

if ( SERVER ) then

	-- when a player spawns a prop, assign the owner's name to it with ent:SetNetVar()
	hook.Add( "PlayerSpawnedProp", "AssignOwner", function( ply, mdl, ent )

		-- Adds a net hook specific to this entity only. The same can be done clientside.
		ent:AddNetHook( "Owner", "MyHookName", function( ent, key, value )
			PrintMessage( HUD_PRINTTALK, fmtHook( ent, key, value ) )
		end)

		ent:SetNetVar( "Owner", ply:Nick() ) -- stores and networks the value to clients

	end )

elseif ( CLIENT ) then

	-- draw the owner's name of any entity we look at during HUDPaint
	hook.Add( "HUDPaint", "DrawOwner", function()

		if ( !IsValid( LocalPlayer() ) ) then return end

		local ent = LocalPlayer():GetEyeTrace().Entity -- get the entity we're looking at
		if ( !IsValid( ent ) or ent:IsPlayer() ) then return end

		local owner = ent:GetNetVar( "Owner", "N/A" ) -- get the owner's name, but if it hasn't been networked to us yet, use N/A

		surface.SetFont( "default" )
		local w, h = surface.GetTextSize( owner )
		local x = ScrW() - w - 15
		local y = ScrH() / 2.4

		draw.SimpleText( owner, "default", x, y, color_white, 0, 0 )

	end )
	-- As soon as the server called ent:SetNetVar( "Owner", ply:Nick() ), the owner's name would be broadcasted to all clients.
	-- The moment we look at the prop after it has been spawned, we'll be able to get the networked name with ent:GetNetVar( "Owner" ).

	-- Example catch-all NetHook. This will get called any time an entity's Owner NetVar changes
	-- The same can be done serverside.
	netwrapper.AddNetHook("Owner", "MyHookName_cl", function( ent, key, value )
		chat.AddText( fmtHook( ent, key, value ) )
	end)

end






--[[ ----------------------------------------- ]]--
--                 Net Requests
--[[ ----------------------------------------- ]]--

if ( SERVER ) then

	-- when a player spawns a prop, assign the owner's name to it with ent:SetNetRequest()
	hook.Add( "PlayerSpawnedProp", "AssignOwner_req", function( ply, mdl, ent )

		ent:SetNetRequest( "Owner", ply:Nick() ) -- stores the value but does not network it

	end )

elseif ( CLIENT ) then

	-- draw the owner's name of any entity we look at during HUDPaint
	hook.Add( "HUDPaint", "DrawOwner_req", function()

		if ( !IsValid( LocalPlayer() ) ) then return end

		local ent = LocalPlayer():GetEyeTrace().Entity -- get the entity we're looking at
		if ( !IsValid( ent ) or ent:IsPlayer() ) then return end

		local owner = ent:GetNetRequest( "Owner" ) -- get the owner's name
		if ( !owner ) then ent:SendNetRequest( "Owner" ) end -- if the owner's name hasn't been networked to us yet, send a Net Request that asks for it

		owner = owner or "N/A" -- until we have the actual owner's name, we can just use N/A

		surface.SetFont( "default" )
		local w, h = surface.GetTextSize( owner )
		local x = ScrW() - w - 15
		local y = ScrH() / 2.3

		draw.SimpleText( owner, "default", x, y, color_white, 0, 0 )

	end )
	-- when ent:SendNetRequest( "Owner" ) is used on the client, the client will ask the server if it has any data stored on the entity at the key "Owner"
	-- if it does, it will reply with the value and the client will automatically use ent:SetNetRequest( "Owner", value ) so that any
	-- subsequent calls to ent:GetNetRequest( "Owner" ) returns the value

end




--[[ ----------------------------------------- ]]--
--                 Global Variables
--[[ ----------------------------------------- ]]--


if ( SERVER ) then

	local colors = {
		"Blue", "Red", "Green", "Yellow", "Magenta",
		"Cyan", "Burgundy", "Beige", "Orange", "Pink"
	}

	timer.Create(" CycleColors", 3, 0, function()
		netwrapper.SetGlobalVar ("Color", table.Random( colors ) )
	end )

elseif ( CLIENT ) then

	hook.Add( "HUDPaint", "DrawColor", function()

		local color = netwrapper.GetGlobalVar( "Color" )
		color = "Current Color: " .. color

		surface.SetFont( "default" )
		local w, h = surface.GetTextSize( color )
		local x = ScrW() - w - 15
		local y = ScrH() / 2.5

		draw.SimpleText( color, "default", x, y, color_white, 0, 0 )

	end )

	netwrapper.AddGlobalHook( "Color", "MyHookName", function( key, value )
		chat.AddText( "Color was changed to " .. value )
	end )

	-- If you wanted to remove the hook, you could do this:
	-- netwrapper.RemoveGlobalHook( "Color", "MyHookName" )

	-- Alternatively, you can pass any object with an IsValid method (panel, entity, etc)
	-- as the hook name, and it will automatically get removed if IsValid() returns false.
end


--[[ ----------------------------------------- ]]--
--                 ClientVars
--[[ ----------------------------------------- ]]--


if ( SERVER ) then

	local colors = {
		"Blue", "Red", "Green", "Yellow", "Magenta",
		"Cyan", "Burgundy", "Beige", "Orange", "Pink"
	}

	timer.Create( "CycleColors_Ply", 6, 0, function()
		for k, v in pairs( player.GetAll() ) do
			v:SetClientVar( "Color", table.Random( colors ) )
		end
	end )

elseif ( CLIENT ) then

	hook.Add( "HUDPaint", "DrawColor", function()

		local color = netwrapper.GetClientVar("Color")
		color = "Current Client Color: " .. color

		surface.SetFont( "default" )
		local w, h = surface.GetTextSize( color )
		local x = ScrW() - w - 15
		local y = ScrH() / 2.6

		draw.SimpleText( color, "default", x, y, color_white, 0, 0 )

	end )

	netwrapper.AddCLNetHook( "Color", "MyHookName", function( ent, key, value )
		chat.AddText( "Client Color was changed to " .. value )
	end)
end
