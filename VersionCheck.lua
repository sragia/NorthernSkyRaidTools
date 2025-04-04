local _, NSI = ... -- Internal namespace

function NSI:RequestVersionNumber(type, name) -- type == "Addon" or "WA" or "Note"
    if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        if type == "Addon" then
            local ver = C_AddOns.GetAddOnMetadata(name, "Version") or "0"
            return {name = NSAPI:GetName("player"), version = ver, duplicate = false}, ""
        elseif type == "WA" then
            local waData = WeakAuras.GetData(name)
            local ver = -1
            NSAPI:Broadcast("NS_VERSION_REQUEST", "RAID", type, name)
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
            return {name = NSAPI:GetName("player"), version = ver, duplicate = duplicate}, url
        elseif type == "Note" then
            local note = NSAPI:GetNote()
            local hashed = C_AddOns.IsAddOnLoaded("MRT") and NSAPI:GetHash(note) or ""
            return {name = NSAPI:GetName("player"), version = hashed, duplicate = false}, ""
        end
    end
end