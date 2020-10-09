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

function Setup(baseX, baseY, opt)
	opt = opt or {}

	local data
	local fenv
	if not opt.nofenv then
		data = {}
		fenv = getfenv(1)
		setmetatable(data, {__index=fenv})
		setfenv(1, data)
	end

	function ScrW43()
		return 4/3 * ScrH()
	end

	function PctXF(x)
		return x * ScrW()
	end

	function PctX(x)
		return x * ScrW43()
	end

	function PctY(y)
		return y * ScrH()
	end

	function ScaleXF(x)
		return x/baseX * ScrW()
	end

	function ScaleX(x)
		return x/baseX * ScrW43()
	end

	function ScaleY(x)
		return x/baseY * ScrH()
	end

	-- Temporary hack for relative font sizing
	function UnscaleXF(x)
		return x/ScrW() * baseX
	end

	function UnscaleX(x)
		return x/ScrW43() * baseX
	end

	function UnscaleY(x)
		return x/ScrH() * baseY
	end


	function Padding(x)
		return ScaleY((x or 1) * 5)
	end

	function Left(x) return ScaleX(x) end
	function Right(x) return ScrW() - ScaleX(x) end

	function Left43(x) return math.floor(ScrW43()/2) + ScaleX43(x) end
	function Right43(x) return ScrW() - math.floor(ScrW43()/2) - ScaleX43(x) end

	function Top(y) return ScaleY(y) end
	function Bottom(x) return ScrH() - ScaleY(x) end

	function PctLeft(x) return PctXF(x) end
	function PctRight(x) return ScrW() - PctXF(x) end

	function PctLeft43(x) return math.floor(ScrW43()/2) + PctX(x) end
	function PctRight43(x) return ScrW() - math.floor(ScrW43()/2) - PctX(x) end

	function PctTop(y) return PctY(y) end
	function PctBottom(x) return ScrH() - PctY(x) end

	if opt and opt.extensions then
		setfenv(opt.extensions, getfenv(1))
		opt.extensions()
	end

	if fenv then
		setfenv(1, fenv)
		return data
	end
end

-- We're already in the "xui" module fenv, don't create a new one
Setup(1920, 1080, {nofenv=true})

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

_R.Panel.OPrepare = _R.Panel.OPrepare or _R.Panel.Prepare
function _R.Panel:Prepare(...)
	_R.Panel.OPrepare(self, ...)

	hook.Run("VGUIPanelCreated", self)
end

function _R.Panel:Resize()
	if isfunction(self.OnScreenSizeChanged) then
		self:OnScreenSizeChanged(ScrW(), ScrH())
	end
end

hook.Add("VGUIPanelCreated", "xlib.onpanelcreated", function(panel)
	if isfunction(panel.OnScreenSizeChanged) then
		panel:OnScreenSizeChanged(ScrW(), ScrH())
		if not panel.Resize then
			panel.Resize = panel.OnScreenSizeChanged
		end
	end
end)

if XLIB.Extended then
	DevCommand("rmpanel", function()
		local pan = vgui.GetHoveredPanel()
		if pan and pan:IsValid() then
			pan:Remove()
		end
	end, CLIENT)
end