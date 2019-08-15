function net.WriteCompressed(str)
	local compressed = util.Compress(str)
	local len = #(compressed or {})

	if not compressed or not len then
		compressed, len = "", 0
	end

	net.WriteUInt(len, 32)
	net.WriteData(compressed, len)
end

function net.ReadCompressed()
	local len = net.ReadUInt(32)
	local data = net.ReadData(len)

	return util.Decompress(data)
end
