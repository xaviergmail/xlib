local buffer = ""
function SPrintTable(t, indent, done)

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

		if  (istable(value) && !done[ value ]) then

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
