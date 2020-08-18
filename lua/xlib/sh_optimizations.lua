XLIB.ModelBoneCache = XLIB.ModelBoneCache or {}
function XLIB.LookupBone(ent, bone)
	local mdl = ent:GetModel()

	local cache = XLIB.ModelBoneCache[mdl]
	if not cache then
		cache = {}
		XLIB.ModelBoneCache[mdl] = cache
	end

	local cached = cache[bone]
	if cached then
		return cached
	end

	local boneid = ent:LookupBone(bone)
	cache[bone] = boneid

	return boneid
end

-- ACT IDs can unfortunately differ between models, so referring to them by the enum is not guaranteed to work!
-- Couldn't find much information on this, but it seems that any ACT that isn't hardcoded is also only available server-side?
-- https://github.com/VSES/SourceEngine2007/blob/43a5c90a5ada1e69ca044595383be67f40b33c61/src_main/game/shared/animation.cpp#L153-L164

XLIB.ActivityCache = XLIB.ActivityCache or {}
function XLIB.BuildActivityCache(ent, globals)
	local mdl = ent:GetModel()
	if not mdl then return end  -- Point entities usually don't have models

	local seqs = ent:GetSequenceList()
	if not seqs then return end  -- Brush entities don't have an idle sequence

	local cache = {}
	XLIB.ActivityCache[mdl] = cache

	for seqid, seqname in pairs(seqs) do
		local actid = ent:GetSequenceActivity(seqid)
		local actname = ent:GetSequenceActivityName(seqid)

		cache[actname] = actid
	end

	return cache
end

function XLIB.GetActivityByName(ent, act_name)
	local mdl = ent:GetModel()

	local cache = XLIB.ActivitmCache[mdl] or XLIB.BuildActivityCache(ent)

	if not cache[actname] then
		XLIB.WarnTrace(act_name, "not found in", mdl)
		return -1
	end

	return cache[actname]
end