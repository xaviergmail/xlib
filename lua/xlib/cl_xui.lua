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
hook.Run("ResolutionChanged")

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

_R.Panel.RxPanelMeta = _R.Panel.RxPanelMeta or {}

local function IsRxSubscriptions(tbl)
	return tbl and istable(tbl) and getmetatable(tbl) == _R.Panel.RxPanelMeta
end

function _R.Panel:SetupRx(tbl)
	self:CleanupRx()
	self.Subscriptions = setmetatable(tbl or {}, _R.Panel.RxPanelMeta)

	if self.OnRemove and not self._RxOnRemove then
		self._RxOnRemove = self.OnRemove
	end

	self.OnRemove = function(this)
		this.OnRemove = nil

		if this._RxRemoved then return end
		this._RxRemoved = true

		if IsRxSubscriptions(this.Subscriptions) then
			this:CleanupRx()
		end

		local onRemove = this._RxOnRemove
		if onRemove then
			this._RxOnRemove = nil
			onRemove(this)
		end
	end
end

function _R.Panel:CleanupRx()
	if self.Subscriptions then
		for k, v in ipairs(self.Subscriptions) do
			v:unsubscribe()
		end
	end
end
