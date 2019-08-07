XLIB.ModelBoneCache = XLIB.ModelBoneCache or {}
function XLIB.LookupBone(ent, bone)
	local mdl = ent:GetModel()

	local mc = XLIB.ModelBoneCache[mdl]
	if not mc then
		mc = {}
		XLIB.ModelBoneCache[mdl] = mc
	end

	local cached = mc[bone]
	if cached then
		return cached
	end

	local boneid = ent:LookupBone(bone)
	mc[bone] = boneid

	return boneid
end
