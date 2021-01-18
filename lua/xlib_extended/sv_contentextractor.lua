local tried_filesystem = false
local function saveFile(outdir, fname, warn)
    if not filesystem and not tried_filesystem then
        tried_filesystem = true
        pcall(require, "filesystem")
    end

    local target = XLIB.Join(outdir, fname)

    -- warn needs to be true explicitly, not just truthy.
    if warn != true or file.Exists(fname, "GAME") then
        file.CreateDir(XLIB.BaseDir(target))
        local path = XLIB.Join("data", target)
        local data = file.Read(fname, "GAME")

        if not data or data:len() == 0 then
            return
        end

        if filesystem then
            local f = filesystem.Open(target, "wb", "DATA")
            f:Write(data)
            f:Close()
        else
            path = path..".dat"
            file.Write(target..".dat", data)
        end

        print("Wrote", path)
    else
        print("File not found:", fname)
    end
end

function XLIB.DumpModel(mdl, outdir, decompile)
    mdl = mdl:gsub("\\", "/")
    outdir = outdir or mdl:gsub("/", "-")

    if not mdl:lower():match("%.mdl$") then
        mdl = mdl .. ".mdl"
    end

    if not mdl:lower():match("^models/") then
        mdl = XLIB.Join("models", mdl)
    end

    local mdlname = mdl:GetFileFromFilename()
    local mdlbase = mdl:StripExtension()
    local mdldir = XLIB.BaseDir(mdl)
    for _, fname in pairs(file.Find(mdlbase..".*", "GAME")) do
        saveFile(outdir, XLIB.Join(mdldir, fname))
    end

    print("decompiling?", decompile)
    if decompile then
        local d_data = XLIB.Join("data", outdir)
        local d_path = XLIB.Join(d_data, mdldir, mdlname)
        local d_outdir = XLIB.Join(outdir, "src")
        file.CreateDir(d_outdir)
        XLIB.DecompileModel(d_path, XLIB.Join("data", d_outdir))
    end

    local ent = ents.Create("base_anim")
    ent:SetModel(mdl)
    SafeRemoveEntityDelayed(ent, 0)

    for k, v in pairs(ent:GetMaterials()) do
        XLIB.DumpMaterial(v, outdir)
    end
end

function XLIB.DumpMaterial(_mat, outdir)
    _mat = _mat:gsub("\\", "/")

    if not _mat:lower():match("%.vmt$") then
        _mat = _mat .. ".vmt"
    end

    outdir = outdir or _mat:gsub("/", "-")

    local blacklist = {
        ["effects/flashlight001.vtf"] = true,
        ["models/albedotint.vtf"] = true,
    }

    local files = {}
    local function add(f, check)
        if not blacklist[f] then
            files[XLIB.Join("materials", f)] = tobool(check)
        end
    end

    local mat = Material(_mat)
    add(mat:GetName()..".vmt")

    for k, v in pairs(mat:GetKeyValues()) do
        local _type = type(v)
        if _type == "string" then
            v = v:gsub("\\", "/")
            if v:find("/") then
                add(v:StripExtension()..".vmt")
                add(v:StripExtension()..".vtf")
            end
        elseif _type == "Material" then
            add(v:GetName()..".vmt", true)
        elseif _type == "ITexture" then
            if v:GetName() != mat:GetString(k) then
                print("SKIPPING POTENTIAL AUTO-GENERATED TEXTURE:", k, mat:GetString(k), "Found as:", v:GetName())
            else
                add(v:GetName()..".vtf", true)
            end
        end
    end

    for fname, check in pairs(files) do
        saveFile(outdir, fname, check)
    end
end

function XLIB.DecompileModel(mdl, outdir)
    if not file.Exists("CrowbarCommandLineDecomp.exe", "EXECUTABLE_PATH") then
        print([[Install https://github.com/UltraTechX/Crowbar-Command-Line/releases/ and os.execute to add model decompilation!]])
        return
    end

    if not os.execute then
        pcall(require, "os.exec")
        if not os.execute then
            print("os.execute not found. Install a module that provides it and name the dll gmsv_os.exec_*")
            return
        end
    end

    if not filesystem then
        pcall(require, "filesystem")
        if not filesystem then
            print("gm_filesystem not found. Install it from here: https://github.com/danielga/gm_filesystem/releases")
            return
        end
    end

    local gmod_basepath = filesystem.GetSearchPaths().BASE_PATH[1]
    local function quote(s) return '"'..s:gsub("/", "\\")..'"' end
    local outdirabs = quote(XLIB.Join(gmod_basepath, "garrysmod", outdir))

	local function exec(args)
		local argstr = table.concat(args, " ")
		print("Running", argstr)
		local ret, err = os.execute(argstr)
		if not err and not ret then
			XLIB.Warn(ret)
		else
			print(ret)
		end
	end

    exec { "mkdir", outdirabs }
    exec {
        "start /B cmd /k call",
        quote(XLIB.Join(gmod_basepath, "bin", "CrowbarCommandLineDecomp.exe")),
        "-p", quote(XLIB.Join(gmod_basepath, "garrysmod", mdl)),
        "-o", outdirabs,
    }
    exec { "explorer.exe", outdirabs }
end

DevCommand("dumpmodel", function(ply, cmd, args)
    if not args[1] then
        ply:ChatPrint("Usage: dumpcontent <mdlname> [datadir]. Extracts all required model and material+texture files for the model from the game's current search paths.")
        return
    end

    tried_filesystem = false
    XLIB.DumpModel(args[1], args[2], args[3])
end)

DevCommand("dumpmaterial", function(ply, cmd, args)
    if not args[1] then
        ply:ChatPrint("Usage: dumpmaterial <matname> [datadir]. Extracts all required material+texture files for the material from the game's current search paths.")
        return
    end

    tried_filesystem = false
    XLIB.DumpMaterial(args[1], args[2])
end)