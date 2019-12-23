SScale = ScreenScale  -- Alias
hook.Add("Initialize", "Resolution / Change", function()
	vgui.CreateFromTable {
		Base = "Panel",

		PerformLayout = function()

			hook.Run("ResolutionChanged", ScrW(), ScrH())
		end

	} : ParentToHUD()

	local mat = CreateMaterial("mat_hook_reload", "VertexLitGeneric", {["$baseTexture"] = 0})
	hook.Add("PreRender", "Materials Reloaded", function()
		if (mat:GetInt("$baseTexture") != 1) then
			hook.Run("MaterialsInvalidated")
			mat:SetInt("$baseTexture", 1)
		end
	end)
end)

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

local progressCols = {}
local hue = {val=0}
local tween = tween.new(100, hue, {val=150}, 'inCirc')
for i=0, 100 do
	tween:set(i)
	progressCols[i] = HSVToColor(math.min(120, hue.val), 1, 1)
end

function ProgressColor(scalar)
	return progressCols[math.floor(math.Clamp(scalar, 0, 1)*100)]
end
