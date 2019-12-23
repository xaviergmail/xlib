-- https://github.com/DerekSM/Garrys-Mod-Source/blob/6d8256d3e16e28d67ac4e22005a2165848b8a947/engine/lua/autorun/random.lua
random = {}

local NTAB = 32
local IA = 16807
local IM = 2147483647
local IQ = 127773
local IR = 2836
local NDIV = math.floor(1+(IM-1)/NTAB)
local MAX_RANDOM_RANGE = 0x7FFFFFFF

// fran1 -- return a random floating-point number on the interval [0,1)

local AM = (1.0/IM)
local EPS = 1.2e-7
local RNMX = (1.0-EPS)

local idum = 0
local iy = 0
local iv = {}

function random.SetSeed( iSeed )
	idum = ( ( iSeed < 0 ) and iSeed or -iSeed )
	iy = 0
end

random.SetSeed( os.clock() )

function random.GenerateRandomNumber()
	local j = 0
	local k = 0

	if ( idum <= 0 or not iy ) then
		if ( -(idum) < 1 ) then
			idum = 1
		else
			idum = -(idum)
		end

		for j = NTAB + 7, 0, -1 do
			-- Have to round because k is predicted to be an int
			k = math.floor( idum/IQ )
			idum = IA * (idum - k * IQ) - IR * k
			if ( idum < 0 ) then
				idum = idum + IM
			end
			if ( j < NTAB ) then
				iv[j] = idum
			end
		end

		iy = iv[0]
	end
	k = math.floor( idum/IQ )
	idum = IA * (idum - k * IQ) - IR * k
	if ( idum < 0 ) then
		idum = idum + IM
	end
	j = math.floor( iy/NDIV )

	-- Fix; temporary
	if ( j >= NTAB or j < 0 ) then
		error( "CUniformRandomStream had an array overrun: tried to write to element " .. j .. " of 0..31." )
	end

	iy=iv[j]
	iv[j] = idum

	return iy
end

function random.RandomFloat( flLow, flHigh )
	-- Replicate standard math.random implementation
	flLow = flLow or 0
	flHigh = flHigh or 1

	// float in [0,1)
	local fl = AM * random.GenerateRandomNumber()
	if ( fl > RNMX ) then
		fl = RNMX
	end
	return ( fl * ( flHigh - flLow ) ) + flLow // float in [low,high)
end

function random.RandomFloatExp( flMinVal, flMaxVal, flExponent )
	flMinVal = flMinVal or 0
	flMaxVal = flMaxVal or 1

	// float in [0,1)
	local fl = AM * random.GenerateRandomNumber()
	if ( fl > RNMX ) then
		fl = RNMX
	end
	if ( flExponent ~= 1.0 ) then
		fl = math.pow( fl, flExponent )
	end
	return ( fl * ( flMaxVal - flMinVal ) ) + flMinVal -- float in [low,high)
end

function random.RandomInt( iLow, iHigh )
	//ASSERT(lLow <= lHigh);
	local maxAcceptable
	local x = iHigh - iLow + 1
	local n = 0
	if ( x <= 1 or MAX_RANDOM_RANGE < x-1 ) then
		return iLow
	end

	// The following maps a uniform distribution on the interval [0,MAX_RANDOM_RANGE]
	// to a smaller, client-specified range of [0,x-1] in a way that doesn't bias
	// the uniform distribution unfavorably. Even for a worst case x, the loop is
	// guaranteed to be taken no more than half the time, so for that worst case x,
	// the average number of times through the loop is 2. For cases where x is
	// much smaller than MAX_RANDOM_RANGE, the average number of times through the
	// loop is very close to 1.
	maxAcceptable = MAX_RANDOM_RANGE - ((MAX_RANDOM_RANGE+1) % x )
	repeat
		n = random.GenerateRandomNumber()
	until (n <= maxAcceptable)
	return iLow + (n % x)
end
//-----------------------------------------------------------------------------
//
// Implementation of the gaussian random number stream
// We're gonna use the Box-Muller method (which actually generates 2
// gaussian-distributed numbers at once)
//
//-----------------------------------------------------------------------------
local bHaveValue = false
local flRandomValue = 0

function random.RandomGaussianFloat( flMean, flStdDev )
	local fac, rsq, v1, v2 = 0, 0, 0, 0

	if ( not bHaveValue ) then
		// Pick 2 random #s from -1 to 1
		// Make sure they lie inside the unit circle. If they don't, try again
		repeat
			v1 = 2.0 * random.RandomFloat() - 1.0
			v2 = 2.0 * random.RandomFloat() - 1.0
			rsq = v1 * v1 + v2 * v2
		until ( ( rsq <= 1.0 ) and ( rsq ~= 0.0 ) )
		// The box-muller transformation to get the two gaussian numbers
		fac = math.sqrt( -2.0 * math.log(rsq) / rsq )
		// Store off one value for later use
		flRandomValue = v1 * fac
		bHaveValue = true
		return flStdDev * (v2 * fac) + flMean
	else
		bHaveValue = false
		return flStdDev * flRandomValue + flMean
	end
end
