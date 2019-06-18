SScale = ScreenScale  -- Alias
local hook, math, ScrW, ScrH, ScreenScale
	= hook, math, ScrW, ScrH, ScreenScale

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

module("xui")

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