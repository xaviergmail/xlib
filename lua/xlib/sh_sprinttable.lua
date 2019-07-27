--- Functionally identical to print() but returns the string instead of printing it.
-- The varargs passed are automatically tostring()'d and concatenated by a single space.
function SPrint(...)
	local str = ""

	local args = {...}
	for k, v in ipairs(args) do
		str = str .. " " .. tostring(v)
	end

	return str:Trim()
end
--- Functionally identical to PrintTable() but returns the string instead of printing it.
local buffer = ""
function SPrintTable(t, indent, done, recurse)
	if recurse == nil then
		recurse = true	
	end

	if isbool(indent) then
		recurse = indent
	end

	done = done or {}
	indent = indent or 0
	local keys = table.GetKeys(t)

	table.sort(keys, function(a, b)
		if (isnumber(a) && isnumber(b)) then return a < b end
		return tostring(a) < tostring(b)
	end)

	for i = 1, #keys do
		key = keys[ i ]
		value = t[ key ]
		buffer = buffer..(string.rep("\t", indent))

		if  (recurse && istable(value) && !done[ value ]) then

			done[ value ] = true
			buffer = buffer..(tostring(key) .. ":" .. "\n")
			SPrintTable (value, indent + 2, done)

		else

			buffer = buffer..(tostring(key) .. "\t=\t")
			buffer = buffer..(tostring(value) .. "\n")

		end

	end
	if indent == 0 then
		local ret = buffer
		buffer = ""
		return ret
	end
end
