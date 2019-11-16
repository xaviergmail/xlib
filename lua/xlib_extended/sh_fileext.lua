function _R.File:WriteVector(v)
	self:WriteFloat(v.x)
	self:WriteFloat(v.z)
	self:WriteFloat(v.y)
end

function _R.File:WriteColor(c)
	self:WriteByte(c.r)
	self:WriteByte(c.g)
	self:WriteByte(c.b)
	self:WriteByte(c.a)
end

function _R.File:WriteMUserdata(t)
	for i=1, 4 do
		self:WriteFloat(t[i])
	end
end

function _R.File:ReadVector()
	local x, z, y = self:ReadFloat(), self:ReadFloat(), self:ReadFloat()
	return Vector(x, y, z)
end

function _R.File:ReadColor()
	return Color(self:ReadByte(), self:ReadByte(), self:ReadByte(), self:ReadByte())
end

function _R.File:ReadMUserdata()
	return {self:ReadFloat(), self:ReadFloat(), self:ReadFloat(), self:ReadFloat()}
end
