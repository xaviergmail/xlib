local unpack = (unpack or table.unpack)
f = f or {}

f.toFunction = function (func)
	if type (func) == "function" then
		return func
	elseif type (func) == "table" then
		return function (x)
			return func [x]
		end
	elseif type (func) == "string" then
		return f [func]
	end
end

f.toString = function (v)
	local type = type (v)

	if type == "string" then
		return string.format ("%q", v)
	elseif type == "table" then
		if getmetatable (v) == f.mt.list then
			return tostring (v)
		end

		return "{ " .. tostring (v) .. " }"
	end

	-- Default to tostring
	return tostring (v)
end

f.apply  = function (fn, ...)
	local args = {}
	local n1 = select('#', ...)
	for i=1, n1 do
		args[i] = select(i, ...)
	end

	return function (...)
		local t = {}

		local n = 0
		for k, v in ipairs(args) do
			n = n + 1
			t[n] = v
		end

		local n2 = select('#', ...)
		for i=1, n2 do
			t[n + i] = select(i, ...)
		end

		return fn(unpack(t))
	end
end

f.partial = function(func, ...)
    local args = {...}
    return function(...)
        return func(unpack(table.Add( args, {...})))
    end
end

f.call   = function (f, ...) return f (...) end
f.concat = table.concat

f.index = function (t, k)
	if t [k] then
		return t [k]
	elseif type (k) == "number" then
		return t [k]
	elseif type (k) == "table" then
		return f.list (k):map (t)
	end
end

f.newindex = function (t, k, v)
	if type (k) == "number" then
		t [k] = v
	elseif type (k) == "table" then
		if type (v) == "table" then
			for i = 1, #k do
				t [k [i]] = v [i]
			end
		else
			for i = 1, #k do
				t [k [i]] = v
			end
		end
	end
end

f.eq  = function (x, y) return x == y end
f.neq = function (x, y) return x ~= y end
f.neg = function (x) return -x end

f.add = function (x, y) return x + y end
f.mul = function (x, y) return x * y end
f.sub = function (x, y) return x - y end
f.div = function (x, y) return x / y end
f.mod = function (x, y) return x % y end
f.pow = function (x, y) return x ^ y end

f.map    = function (mapF, r, ...)        mapF    = f.toFunction (mapF)    if mapF == print then print (f.concat (f.map (tostring, r), ", ")) return end local rr = f.list () for i = 1, #r do rr [i] = mapF (r [i], ...) end return rr end
f.filter = function (filterF, r, ...)     filterF = f.toFunction (filterF) local rr = f.list () for i = 1, #r do if filterF (r [i], ...) then rr [#rr + 1] = r [i] end end return rr end
f.foldr  = function (x0, binaryF, r, ...) binaryF = f.toFunction (binaryF) for i = #r, 1, -1 do x0 = binaryF (r [i], x0, ...) end return x0 end
f.foldl  = function (x0, binaryF, r, ...) binaryF = f.toFunction (binaryF) for i = 1, #r     do x0 = binaryF (x0, r [i], ...) end return x0 end
f.range  = function (x0, x1, dx) dx = dx or 1 local r = f.list () for i = x0, x1, dx do r [#r + 1] = i end return r end
f.rep    = function (v, n) local r = f.list () for i = 1, n do r [i] = v end return r end
f.sum    = function (r) return foldr (0, f.add, r) end
f.prod   = function (r) return foldr (1, f.mul, r) end

f.keys   = function (t) local r = f.list () for k, _ in pairs (t) do r [#r + 1] = k end return r end
f.values = function (t) local r = f.list () for _, v in pairs (t) do r [#r + 1] = v end return r end

f.mt      = f.mt or {}
f.mt.list = f.mt.list or {}

f.list = function (t)
	t = t or {}

	local list = { array }
	setmetatable (list, f.mt.list)

	for i = 1, #t do
		list [i] = t [i]
	end

	return list
end

f.islist = function(t) return getmetatable(t)  == f.mt.list end
f.mt.list.__index = {}
f.mt.list.methods = {}

f.mt.list.methods.clone = function (self)
	local t = {}
	for k, v in pairs(self) do
		t [k] = v
	end

	return f.list (t)
end

f.mt.list.methods.map    = function (r, mapF, ...)        return f.map    (mapF, r, ...)      end
f.mt.list.methods.filter = function (r, filterF, ...)     return f.filter (filterF, r, ...)      end
f.mt.list.methods.foldr  = function (r, binaryF, x0, ...) return f.foldr  (x0, binaryF, r, ...) end
f.mt.list.methods.foldl  = function (r, binaryF, x0, ...) return f.foldl  (x0, binaryF, r, ...) end
f.mt.list.methods.sum    = f.sum
f.mt.list.methods.prod   = f.prod
f.mt.list.methods.concat = f.concat

f.mt.list.methods.sort = function (self, comparator)
	local t = self:clone ()
	table.sort (t)

	return t
end

f.mt.list.methods.tostring = function (self)
	if #self == 0 then return "{}" end

	return "{ " .. self:map (f.toString):concat (", ") .. " }"
end

f.mt.list.__tostring = f.mt.list.methods.tostring

f.mt.list.__index = function (self, k)
	if f.mt.list.methods [k] then
		return f.mt.list.methods [k]
	elseif type (k) == "number" then
		return rawget (self, k)
	elseif type (k) == "table" then
		return f.list (k):map (self)
	end
end

f.mt.list.__newindex = function (self, k, v)
	if type (k) == "number" then
		rawset (self, k, v)
	elseif type (k) == "table" then
		if type (v) == "table" then
			for i = 1, #k do
				self [k [i]] = v [i]
			end
		else
			for i = 1, #k do
				self [k [i]] = v
			end
		end
	end
end
