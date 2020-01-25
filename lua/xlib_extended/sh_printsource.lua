-- Credits to: https://github.com/aStonedPenguin
-- Shared in a public chatroom some time in 2014-2015

fileColors = fileColors or {}
fileAbbrev = fileAbbrev or {}

OldPrint = OldPrint or print

local incr = SERVER and 20 or 75
function print(...)
    local info = debug.getinfo(2)
    if not info then
        OldPrint(...)
        return
    end

    local fname = info.short_src
    if fileAbbrev[fname] then
        fname = fileAbbrev[fname]
    else
        local oldfname = fname
        fname = string.Explode('/', fname)
        fname = fname[#fname]
        fileAbbrev[oldfname] = fname
    end

    if not fileColors[fname] then
        fileColors[fname] = HSVToColor(incr*60%360, SERVER and (game.IsDedicated() and 1 or 0.5) or 1, 0.8)
        incr = incr + 1
    end

    if info.what != "C" then
        MsgC(fileColors[fname], fname..':'..info.currentline.."/"..info.linedefined, "\t")
    end
    OldPrint(...)
end
