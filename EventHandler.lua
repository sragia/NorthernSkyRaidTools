local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("READY_CHECK")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, e, ...)
        NSAPI:EventHandler(e, false, ...)
end)

function NSAPI:EventHandler(e, internal, ...) -- internal checks whether the event comes from addon comms. We don't want to allow blizzard events to be fired manually
    if e == "ADDON_LOADED" and not internal then
        local name = ...
        if name == "NorthernSkyRaidTools" then
            if not NSRT then NSRT = {} end
            if not NSRT.Nicknames then NSRT.Nicknames = {} end
            NSAPI:InitNickNames()
            NSAPI:SendNickName("GUILD")
        end
    elseif e == "READY_CHECK" and not internal then
        if UnitInRaid("player") then
            NSAPI:SendNickName("RAID")
        end
    elseif e == "COMBAT_LOG_EVENT_UNFILTERED" and not internal then
        local _, subevent, _, _, _, _, _, _, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_APPLIED" and NSExternals and NSExternals.Automated[spellID] then
            local unit = destName
            if unit and UnitExists(unit) and UnitInRaid(unit) then
                unit = "raid"..UnitInRaid(unit)
                local key = NSExternals.Automated[spellID]
                NSAPI:EventHandler("NS_EXTERNAL_REQ", unit, key, NSExternals.Amount[key..spellID], false, "skip")
            end
        end
    elseif e == "NS_VERSION_CHECK" and internal then
        local unit, ver, type, name = ...
        -- build reponse UI, matching type & name
    elseif e == "NS_VERSION_REQUEST" and internal then
        local unit, type, name = ...
        if UnitExists(unit) and (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)) then
            if type == "Addon" then
                local ver = C_AddOns.GetAddOnMetadata(name, "Version") or "0"
                NSAPI:Broadcast("NS_VERSION_CHECK", "RAID", ver)
            elseif type == "WA" then
                local waData = WeakAuras.GetData(name)
                local ver = -1
                if waData then
                    ver = 0
                    if waData["url"] then
                        ver = tonumber(waData["url"]:match('.*/(%d+)$'))
                    end
                end
                NSAPI:Broadcast("NS_VERSION_CHECK", "RAID", ver, type, name)
            end
        end
    elseif e == "NSAPI_NICKNAMES_COMMS" and internal then
        local unit, nickname, name, realm = ...
        if UnitExists(unit) and UnitIsUnit("player", unit) then return end -- don't add new nickname if it's yourself because already adding it to the database when you edit it
        NSAPI:NewNickName(unit, nickname, name, realm)
    elseif e == "NSAPI_SPEC" and internal then
        local unit, spec = ...
        NSAPI.specs = NSAPI.specs or {}
        NSAPI.specs[unit] = tonumber(spec)
    elseif (e == "NSAPI_SPEC_REQUEST" and internal) or (e == "ENCOUNTER_START" and not internal) then
        NSAPI.specs = {}

        for u in NSAPI:IterateGroupMembers() do
            if UnitIsVisible(u) then
                NSAPI.specs[u] = WeakAuras.SpecForUnit(u)
            end
        end
        -- broadcast spec info
        local specid = GetSpecializationInfo(GetSpecialization())
        NSAPI:Broadcast("NSAPI_SPEC", "RAID", specid)
        if e == "ENCOUNTER_START" then
            C_Timer.After(3, function()
                WeakAuras.ScanEvents("NSAPI_ENCOUNTER_START", true)
            end)
            NSExternals.target = "raid1"
            NSExternals.pull = GetTime()

            for u in NSAPI:IterateGroupMembers() do
                if UnitIsVisible(u) and (UnitIsGroupLeader(u) or UnitIsGroupAssistant(u)) then
                    NSExternals.target = u
                    break
                end
            end
            if UnitIsUnit("player", NSExternals.target) then
                NSExternals.UpdateExternals()
                local note = NSAPI:GetNote()
                local list = false
                local key = ""
                local spell = 0
                NSExternals.customprio = {}
                NSExternals.Automated = {}
                NSExternals.Amount = {}
                if note == "" then return end
                for line in note:gmatch('[^\r\n]+') do
                    --check for start/end of the name list
                    if strlower(line) == "nsexternalstart" then
                        list = true
                        key = ""
                    elseif strlower(line) == "nsexternalend" then
                        list = false
                        NSExternals.Amount[key] = NSExternals.Amount[key] or 1
                        key = ""
                    end
                    if list then
                        for k in line:gmatch("key:(%S+)") do
                            if k ~= "default" then
                                NSExternals.customprio[k] = NSExternals.customprio[k] or {}
                            end
                            key = k
                        end
                        if key ~= "" then
                            for spellID in line:gmatch("automated:(%d+)") do
                                NSExternals.Automated[tonumber(spellID)] = key
                                spell = tonumber(spellID)
                            end
                            if spell ~= 0 then
                                for num in line:gmatch("amount:(%d+)") do
                                    NSExternals.Amount[key..spell] = tonumber(num)
                                end
                            end
                        end
                        for name, id in line:gmatch("(%S+):(%d+)") do --
                            if UnitInRaid(name) and key ~= "" then
                                if key == "default" then-- only make a default custom prio if the user actually provides one, otherwise we keep the initial default prio
                                    NSExternals.customprio[key] = NSExternals.customprio[key] or {}
                                end
                                local u = "raid"..UnitInRaid(name)
                                table.insert(NSExternals.customprio[key], {u, id})
                            end
                        end
                    end
                end
            end
        end
    elseif e == "NS_EXTERNAL_REQ" and ... and UnitIsUnit(NSExternals.target, "player") and internal then -- only accept scanevent if you are the "server"
        -- unitID = player that requested
        -- unit = player that shall give the external
        local unitID, key, num, req, range = ...
        if UnitIsDead(unitID) or C_UnitAuras.GetAuraDataBySpellName(unitID, C_Spell.GetSpellInfo(27827).name) then  -- block incoming requests from dead people
            return
        end
        num = num or 1
        local now = GetTime()
        local name, realm = UnitName(unitID)
        if key == "default" then
            key = NSExternals:getprio(unitID)
        end
        NSExternals.assigned = {}
        local sender = realm and name.."-"..realm or name
        local found = 0
        if NSExternals.check[key] then -- see if an immunity or other assigned self cd's are available first
            for i, spellID in ipairs(NSExternals.check[key]) do
                if (spellID ~= 1022 and spellID ~= 204018 and spellID ~= 633 and spellID ~= 204018) or not C_UnitAuras.GetAuraDataBySpellName(unitID, C_Spell.GetSpellInfo(25771).name) then -- check forebearance
                    local check = unitID..spellID
                    if NSExternals.ready[check] then
                        return true
                    end
                end
            end
        end
        local count = 0
        if NSExternals.customprio[key] then
            for i, v in ipairs(NSExternals.customprio[key]) do
                local assigned = NSExternals:AssignExternal(unitID, key, num, req, range, v[1], v[2], sender)
                if assigned then
                    count = count+1
                end
                if count >= num or NSExternals.AllSpells[assigned] == 1 then return end -- end loop if we found enough externals or found an immunity
            end
        else
            for i, spellID in ipairs(NSExternals.prio[key]) do -- go through spellid's in prio order
                if NSExternals.known[spellID] then
                    for unit, _ in pairs(NSExternals.known[spellID]) do -- check each person who knows that spell if it's available and not already requested
                        if num > count then
                            local assigned = NSExternals:AssignExternal(unitID, key, num, req, range, unit, spellID, sender)
                            if assigned then
                                count = count+1
                            end
                            if count >= num or NSExternals.AllSpells[assigned] == 1 then return end -- end loop if we found enough externals or found an immunity
                        end
                    end
                end
            end
        end
        -- No External Left
        NSAPI:Broadcast("NS_EXTERNAL_NO", "WHISPER", unitID, "nilcheck")
    end
end


--[[ add debug config
elseif e == "NSAPI_MACRO_RECEIVE" and aura_env.config.debug then
local unit = ...
local cname = NSAPI:Shorten(unit, 8)
print(cname, "pressed Macro")
DebugPrint(cname, "pressed Macro", GetTime())
-- WeakAuras.ScanEvents("NS_MACRO_RECEIVE", unit) add this to another aura    ]]

    --[[ add custom option for this
elseif e == "MRT_NOTE_UPDATE" then
    if aura_env.config.mrtcheck and ((not aura_env.last) or aura_env.last < GetTime()-1) and VMRT.Note.Text1 and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and not WeakAuras.CurrentEncounter then -- cap at max once per second because MRT sends this event multiple times on large notes. Also only check if you are group leader or assist
        local diff = select(3, GetInstanceInfo()) or 0
        if diff == 16 then -- Mythic only
            aura_env.last = GetTime()
            C_Timer.After(1, function() -- doing this delayed because the note is sent in multiple batches so need to wait until the entire note is there
                WeakAuras.ScanEvents("NSAPI_MRT_NOTE_CHECK", true)
            end)
        end
    end]]
    --[[
        elseif e == "NS_IMPORT_RECEIVE" and not aura_env.config.blocknicknames then
            local unit, table, guildname, wipe = ...
            local guild, _, rank = GetGuildInfo(unit)
            local myguild = GetGuildInfo("player")
            if guild == myguild and rank <= 2 then -- only do this if player is in same guild as the sender and the sender is guildmaster or officer (this assumes there are 2 officer ranks after guildmaster - worst case it would allow members to do it as well which isn't too bad
                if table or guildname or wipe then
                    NSAPI:ImportNicknames(table, guildname, wipe, unit)
                end
            else
                if guild ~= myguild then
                    print("requested import from "..NSAPI:Shorten(unit, 8).." failed because you aren't in the same guild.")
                elseif rank > 2 then
                    print("requested import from "..NSAPI:Shorten(unit, 8).." failed because their guildrank isn't high enough.")
                end
            end]]
    --[[
        elseif e == "NSAPI_MRT_NOTE_CHECK" and ... then
            local text = _G.VMRT.Note.Text1
            local list = false
            local startline = ""
            for line in text:gmatch('[^\r\n]+') do
                line = strtrim(line) --trim whitespace
                --check for start/end of the name list
                local charlist = {}
                local missing = {}
                local count = 0
                if string.match(line, "ns.*start") or line == "intstart" then -- match any string that starts with "ns" and ends with "start" as well as the interrupt WA
                    charlist = {}
                    missing = {}
                    count = 0
                    list = true
                    startline = line
                elseif string.match(line, "ns.*end") or line == "intend" then
                    list = false
                    local endline = line
                    if #missing >= 1 then
                        print("|cffff4040The following players between the lines |r|cff3ffc3f'"..startline.."'|r|cffff4040 and |r'|cff3ffc3f"..endline.."'|r |cffff4040are in the note but not in the raid:|r")
                        local s = ""
                        for _, v in ipairs(missing) do
                            s = s..v.." "
                        end
                        print(s)
                        local t = ""
                        for unit in WA_IterateGroupMembers() do
                            local i = UnitInRaid(unit)
                            if select(3, GetRaidRosterInfo(i)) <= 4 and not charlist[unit] then
                                if startline == "nsdispelstart" then -- only consider healers for the default dispel naming convention
                                    if UnitGroupRolesAssigned(unit) == "HEALER" then
                                        t = t..WA_ClassColorName(UnitName(unit)).." "
                                    end
                                else
                                    t = t..WA_ClassColorName(UnitName(unit)).." "
                                end
                            end
                        end
                        if t ~= "" then
                            print("|cff409fffThe following players are missing from this note:|r")
                            print(t)
                        end
                    end
                end
                if list then
                    line = line:gsub("{.-}", "") -- cleaning markers from line
                    for name in line:gmatch("%S+") do -- finding all remaining strings
                        local name2 = name:gsub("||r", "") -- clean colorcode
                        name2 = name2:gsub("||c%x%x%x%x%x%x%x%x", "") -- clean colorcode
                            name2 = NSAPI:GetChar(name2, true) -- first converts from character name to nickname and then back to a character name that's actually in the raid. This allows checking for any character of the player
                        local i = UnitInRaid(name2)
                        if i and select(3, GetRaidRosterInfo(i)) <= 4 then
                            charlist["raid"..i] = true
                        elseif name2 ~= name and not tIndexOf(missing, name2) then -- only check if string was color coded, this should ensure we're not counting things that aren't actually character names
                            name = name:gsub("||r", "") -- clean colorcode
                            name = name:gsub("||c%x%x%x%x%x%x%x%x", "") -- clean colorcode
                            table.insert(missing, name)
                        end
                    end
                end
            end
        end]]