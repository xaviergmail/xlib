function table.Invert(src, key, idnum)
	local ret = {}

	if not istable(src) then return end

	for k, v in pairs(src) do
		if key and istable(v) then
			if v[key] then
				ret[v[key]] = v
				if idnum then
					v.IDNUM = k
				end
			end
		else
			ret[v] = k
		end
	end

	return ret
end

function table.StoreKeys(src, key)
	key = key or "IDNUM"

	for k, v in pairs(src) do
		if istable(v) then
			v[key] = k
		end
	end
	return src
end
