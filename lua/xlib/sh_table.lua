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

-- The following allows you to safely pack varargs while retaining nil values
table.NIL = table.NIL or setmetatable({}, {__tostring=function() return "nil" end})
function table.PackNil(...)
	local t = {}
	for i=1, select("#", ...) do
		local v = select(i, ...)

		if v == nil then v = table.NIL end

		table.insert(t, v)
	end

	return t
end

function table.UnpackNil(t, nocopy)
	if #t == 0 then return end

	if not nocopy then
		t = table.Copy(t)
	end

	local v = table.remove(t, 1)
	if v == table.NIL then v = nil end

	return v, table.UnpackNil(t, true)
end

-- Only works on sequential tables. The other implementation of table randomness is complete jank.
function table.TrueRandom(tbl)
	local n = random.RandomInt(1, #tbl)
	return tbl[n]
end
