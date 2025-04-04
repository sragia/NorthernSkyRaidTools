local _, NSI = ... -- Internal namespace

function NSI:RequestVersionNumber(type, name) -- type == "Addon" or "WA" or "Note"
    if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        local unit, ver, duplicate, url = NSI:GetVersionNumber(type, name, unit)
        NSI:VersionResponse({name = UnitName("player"), version = "No Response", duplicate = false})
        NSAPI:Broadcast("NS_VERSION_REQUEST", "RAID", type, name)
        for unit in NSI:IterateGroupMembers() do
            if not UnitIsUnit("player", unit) then
                NSI:VersionResponse({name = UnitName(unit), version = "No Response", duplicate = false})
            end
        end
        return {name = UnitName("player"), version = ver, duplicate = duplicate}, url
    end
end
function NSI:VersionResponse(data)
    NSI.NSUI.version_scrollbox:AddData(data)
end


function NSI:GetVersionNumber(type, name, unit)    
    if type == "Addon" then
        local ver = C_AddOns.GetAddOnMetadata(name, "Version") or "0"
        return unit, ver, false, ""
    elseif type == "WA" then
        local waData = WeakAuras.GetData(name)
        local ver = -1
        local url = ""
        if waData then
            ver = 0
            if waData["url"] then
                url = waData["url"]
                ver = tonumber(waData["url"]:match('.*/(%d+)$'))
            end
        end
        local duplicate = false
        for i=2, 10 do -- check for duplicates of the Weakaura
            waData = WeakAuras.GetData(name.." "..i)
            if waData then duplicate = true break end
        end
        return unit, ver, duplicate, url
    elseif type == "Note" then
        local note = NSAPI:GetNote()
        local hashed = C_AddOns.IsAddOnLoaded("MRT") and NSAPI:GetHash(note) or ""
        return unit, hashed, false, ""
    end
end