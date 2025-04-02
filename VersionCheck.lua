local _, NSI = ... -- Internal namespace
function NSI:RequestAddonVersion(AddonName)
    local ver = C_AddOns.GetAddOnMetadata(AddonName, "Version")
    NSAPI:Broadcast("NS_ADDON_CHECK", "RAID", ver)
end

function NSI:RequestVersionNumber(type, name) -- type == "Addon" or "WA"
    if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        NSAPI:Broadcast("NS_VERSION_REQUEST", "RAID", type, name)
        -- Build UI for response with type&name saved in it
    end
end