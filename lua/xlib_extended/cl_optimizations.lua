
XLIB.EnsureLocalPlayer(function()
    LP = LocalPlayer()	
    hook.Add("Tick", "xlib.EyeTrace", function()
        EyeTrace = LP:GetEyeTrace()
        EyeEnt = EyeTrace.Entity
    end)
end)
