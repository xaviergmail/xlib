local FCVAR_DEVELOPMENTONLY = bit.lshift(1, 1)
local FCVAR_HIDDEN = bit.lshift(1, 4)
local FCVAR_INTERNAL_USE = bit.lshift(1, 15)


local devonly = bit.bor(FCVAR_DEVELOPMENTONLY, FCVAR_INTERNAL_USE)
local restricted = bit.bor(devonly, FCVAR_HIDDEN, FCVAR_CHEAT, FCVAR_SPONLY)
local bitmask = bit.bnot(restricted)

DevCommand("unblock_cvars", function()
	require "cvarsx"
	for cvar in pairs(cvars.GetAll()) do
		local flags = cvar:GetFlags()
		if bit.bor(flags, devonly) != 0 then
			print("Unblocking", cvar:GetName())
			cvar:SetFlags(bit.band(flags, bitmask))
		end
	end
end, true)
print("hi")