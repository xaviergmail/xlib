-- You'll need to require() this shared
if SERVER then
	AddCSLuaFile()
	return
end


module("xui", package.seeall)

function H()
	return math.min(ScrH(), 768)
end

function W()
	return math.min(ScrW(), 1366)
end

function ScrW43()
	return 4 / 3 * ScrH()
end

function ScreenScaleX(x)
	return math.Round(x / 640 * ScrW43())
end

function ScreenScaleY(y)
	return math.Round(y / 480 * H())
end

function ScreenScale1080X(x)
	return math.Round(x / 1920 * W())
end

function ScreenScale1080Y(y)
	return math.Round(y / 1080 * H())
end

function ScreenScale1600XR(x)
	return math.Round(x / 1600 * ScrW())
end

function ScreenScale1600YR(y)
	return math.Round(y / 600 * ScrH())
end

function ScreenScale1600X(x)
	return math.Round(x / 1600 * W())
end

function ScreenScale1600Y(y)
	return math.Round(y / 600 * H())
end

function ScaleX(pct)
	return pct/100*ScrW43()
end

function ScaleY(pct)
	return pct/100*ScrH()
end

function OffsetX(pct)
	return (ScrW() - ScaleX(pct))/2
end

function OffsetY(pct)
	return (ScrH() - ScaleY(pct))/2
end

local padding = 1 -- Initialized in GM:ResolutionChanged()
function Padding(x)
	return (x or 1) * padding
end

hook.Add("ResolutionChanged", "ResolutionChanged_UIUtil_Padding", function()
	padding = ScreenScale(5)
end)
hook.Run("ResolutionChanged")