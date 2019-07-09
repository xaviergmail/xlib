function XLIB.FreezeProp(ent)
	ent:SetMoveType(MOVETYPE_NONE)
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end
end