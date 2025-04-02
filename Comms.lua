local _, NSI = ... -- Internal namespace
local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
-- Libraries are included in WeakAuras which is a dependancy

local del = ":"
function NSAPI:Broadcast(event, channel, ...)
    local message = event
    local argTable = {...}
    local target = ""

    local argCount = #argTable

    -- Always send unitID as second argument after event
    local unitID = UnitInRaid("player") and "raid"..UnitInRaid("player") or UnitName("player")
    message = string.format("%s"..del.."%s(%s)", message, unitID, "string")


    for i = 1, argCount do
        local functionArg = argTable[i]
        local argType = type(functionArg)

        if argType == "table" then
            functionArg = LibSerialize:Serialize(functionArg)
            functionArg = LibDeflate:CompressDeflate(functionArg)
            functionArg = LibDeflate:EncodeForWoWAddonChannel(functionArg)
            message = string.format("%s"..del.."%s(%s)", message, tostring(functionArg), argType)
        else
            if argType ~= "string" and argType ~= "number" and argType ~= "boolean" then
                functionArg = ""
                argType = "string"
            end
            message = string.format("%s"..del.."%s(%s)", message, tostring(functionArg), argType)
        end
    end
    if channel == "WHISPER" then -- create "fake" whisper addon msg that actually just uses RAID instead and will be checked on receive
        AceComm:SendCommMessage("NSWA_MSG2", message, "RAID")
    else
        AceComm:SendCommMessage("NSWA_MSG", message, channel)
    end
end

local function ReceiveComm(text, chan, sender, whisper)
    local argTable = {strsplit(del, text)}
    local event = argTable[1]
    if (UnitExists(sender) and (UnitInRaid(sender) or UnitInParty(sender))) or (chan == "GUILD" and event == "NSAPI_NICKNAMES_COMMS") then -- block addon msg's from outside the raid
        local formattedArgTable = {}
        table.remove(argTable, 1)
        if whisper then
            local target, argType = argTable[2]:match("(.*)%((%a+)%)") -- initially first entry is event, 2nd the unitid of the sender and 3rd the whisper target but we already removed first table entry
            if not (UnitIsUnit("player", target)) then
                return
            end
            table.remove(argTable, 2)
        end

        local tonext = ""
        for i, functionArg in ipairs(argTable) do
            local argValue, argType = functionArg:match("(.*)%((%a+)%)")
            if argType == "number" then
                argValue = tonumber(argValue)
                tonext = ""
            elseif argType == "boolean" then
                argValue = argValue == "true"
                tonext = ""
            elseif argType == "table" then
                argValue = tonext..argValue
                argValue = LibDeflate:DecodeForWoWAddonChannel(argValue)
                argValue = LibDeflate:DecompressDeflate(argValue)
                local success, table = LibSerialize:Deserialize(argValue)
                if success then
                    argValue = table
                else
                    argValue = ""
                end
                tonext = ""
            end
            if argValue == "" then
                table.insert(formattedArgTable, false)
            else
                table.insert(formattedArgTable, argValue)
            end
            if not argType then
                tonext = tonext..functionArg..del -- if argtype wasn't given then this is part of a table that was falsely split by the delimeter so we're stitching it back together
            end
        end
        NSI:EventHandler(event, true, unpack(formattedArgTable))
        WeakAuras.ScanEvents(event, unpack(formattedArgTable))
    end
end



AceComm:RegisterComm("NSWA_MSG", function(_, text, chan, sender) ReceiveComm(text, chan, sender, false) end)
AceComm:RegisterComm("NSWA_MSG2", function(_, text, chan, sender) ReceiveComm(text, chan, sender, true) end)
-- NSAPI:Broadcast("NS_EVENTNAME", channel, targetunitID if whisper, arg1, arg2, arg3)