function _P:RateLimit(key, rate)
	rate = rate or 0.25

	if not self.RateLimits then self.RateLimits = {} end

	local nextAllow = self.RateLimits[key] or 0

	local allow = CurTime() >= nextAllow
	if allow then
		self.RateLimits[key] = CurTime() + rate
	end

	return not allow
end
