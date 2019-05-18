function net.WriteCompressed(str)
	local compressed, len = util.Compress(str)
	net.WriteUInt(len, 32)
	net.WriteData(compressed, len)
end

function net.ReadCompressed()
	local len = net.ReadUInt(32)
	local data = net.ReadData(len)

	return util.Decompress(data)
end