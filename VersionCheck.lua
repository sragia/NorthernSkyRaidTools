local _, NSI = ... -- Internal namespace

function NSI:RequestVersionNumber(type, name) -- type == "Addon" or "WA" or "Note"
    if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        NSAPI:Broadcast("NS_VERSION_REQUEST", "RAID", type, name)
        -- Build UI for response with type&name saved in it
    end
end