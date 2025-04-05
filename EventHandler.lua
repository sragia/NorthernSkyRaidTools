local _, NSI = ... -- Internal namespace
local f = CreateFrame("Frame")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("READY_CHECK")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, e, ...)
    NSI:EventHandler(e, false, ...)
end)

function NSI:EventHandler(e, internal, ...) -- internal checks whether the event comes from addon comms. We don't want to allow blizzard events to be fired manually
    if e == "ADDON_LOADED" and not internal then
        local name = ...
        if name == "NorthernSkyRaidTools" then
            if not NSRT then NSRT = {} end
            if not NSRT.NSUI then NSRT.NSUI = {} end
            if not NSRT.NSUI.externals_anchor then NSRT.NSUI.externals_anchor = {} end
            -- if not NSRT.NSUI.main_frame then NSRT.NSUI.main_frame = {} end
            -- if not NSRT.NSUI.external_frame then NSRT.NSUI.external_frame = {} end
            if not NSRT.NickNames then NSRT.NickNames = {} end
            if not NSRT.Settings then NSRT.Settings = {} end
            NSRT.Settings["MyNickName"] = NSRT.Settings["MyNickName"] or ""
            NSRT.Settings["GlobalNickNames"] = NSRT.Settings["GlobalNickNames"] or false
            NSRT.Settings["Blizzard"] = NSRT.Settings["Blizzard"] or false
            NSRT.Settings["WA"] = NSRT.Settings["WA"] or false
            NSRT.Settings["MRT"] = NSRT.Settings["MRT"] or false
            NSRT.Settings["Cell"] = NSRT.Settings["Cell"] or false
            NSRT.Settings["Grid2"] = NSRT.Settings["Grid2"] or false
            NSRT.Settings["OmniCD"] = NSRT.Settings["OmniCD"] or false
            NSRT.Settings["ElvUI"] = NSRT.Settings["ElvUI"] or false
            NSRT.Settings["SuF"] = NSRT.Settings["SuF"] or false
            NSRT.Settings["Unhalted"] = NSRT.Settings["Unhalted"] or false
            NSRT.Settings["ShareNickNames"] = NSRT.Settings["ShareNickNames"] or 4
            NSRT.Settings["AcceptNickNames"] = NSRT.Settings["AcceptNickNames"] or 4
            NSRT.Settings["PAExtraAction"] = NSRT.Settings["PAExtraAction"] or false
            NSRT.Settings["PASelfPing"] = NSRT.Settings["PASelfPing"] or false
            NSRT.Settings["ExternalSelfPing"] = NSRT.Settings["ExternalSelfPing"] or false
            NSRT.Settings["MRTNoteComparison"] = NSRT.Settings["MRTNoteComparison"] or false
            NSRT.Settings["TTS"] = NSRT.Settings["TTS"] or true
            NSRT.Settings["TTSVolume"] = NSRT.Settings["TTSVolume"] or 50
            NSRT.Settings["TTSVoice"] = NSRT.Settings["TTSVoice"] or 2
            NSRT.Settings["Minimap"] = NSRT.Settings["Minimap"] or {hide = false}
            NSRT.BlizzardNickNamesHook = false
            NSRT.MRTNickNamesHook = false
            NSRT.OmniCDNickNamesHook = false
            NSI:InitNickNames()
        end
    elseif e == "PLAYER_LOGIN" and not internal then
        local pafound = false
        local extfound = false
        local macrocount = 0    
        for i=1, 120 do
            local macroname = C_Macro.GetMacroName(i)
            if not macroname then break end
            macrocount = i
            if macroname == "NS PA Macro" then
                local macrotext = "/run WeakAuras.ScanEvents(\"NS_PA_MACRO\", true);"
                if NSRT.Settings["PASelfPing"] then
                    macrotext = macrotext.."\n/ping [@player] Warning;"
                end
                if NSRT.Settings["PAExtraAction"] then
                    macrotext = macrotext.."\n/click ExtraActionButton1"
                end
                EditMacro(i, "NS PA Macro", 132288, macrotext, false)
                pafound = true
            elseif macroname == "NS Ext Macro" then
                local macrotext = NSRT.Settings["ExternalSelfPing"] and "/run NSAPI.ExternalRequest();\n/ping [@player] Assist;" or "/run NSAPI.ExternalRequest();"
                EditMacro(i, "NS Ext Macro", 135966, macrotext, false)
                extfound = true
            end
            if pafound and extfound then break end
        end
        if macrocount >= 120 then
            print("You reached the global Macro cap so the Private Aura Macro could not be created")
        elseif not pafound then
            macrocount = macrocount+1            
            local macrotext = "/run WeakAuras.ScanEvents(\"NS_PA_MACRO\", true);"
            if NSRT.Settings["PASelfPing"] then
                macrotext = macrotext.."\n/ping [@player] Warning;"
            end
            if NSRT.Settings["PAExtraAction"] then
                macrotext = macrotext.."\n/click ExtraActionButton1"
            end
            CreateMacro("NS PA Macro", 132288, macrotext, false)
        end
        if macrocount >= 120 then 
            print("You reached the global Macro cap so the External Macro could not be created")
        elseif not extfound then
            macrocount = macrocount+1
            local macrotext = NSRT.Settings["ExternalSelfPing"] and "/run NSAPI.ExternalRequest();\n/ping [@player] Assist;" or "/run NSAPI.ExternalRequest();"
            CreateMacro("NS Ext Macro", 135966, macrotext, false)
        end
        NSI:SendNickName()
        if NSRT.Settings["GlobalNickNames"] then -- add own nickname if not already in database (for new characters)
            local name, realm = UnitName("player")
            if not realm then
                realm = GetNormalizedRealmName()
            end
            if not NSRT.NickNames[name.."-"..realm] then
                NSI:NewNickName("player", NSRT.Settings["MyNickName"], name, realm)
            end
        end
        NSI.NSUI:Init()
        NSI:InitLDB()
        if WeakAuras.GetData("Northern Sky Externals") then
            print("Please uninstall the Northern Sky Externals Weakaura to prevent conflicts with the Northern Sky Raid Tools Addon.")
        end
    elseif e == "READY_CHECK" and not internal then
        if WeakAuras.CurrentEncounter then return end
        NSI:SendNickName()
        local hashed = C_AddOns.IsAddOnLoaded("MRT") and NSAPI:GetHash(NSAPI:GetNote()) or ""        
        NSAPI:Broadcast("MRT_NOTE", "RAID", hashed)
    elseif e == "MRT_NOTE" and NSRT.Settings["MRTNoteComparison"] and internal then
        if WeakAuras.CurrentEncounter then return end
        local hashed = ...        
        if hashed ~= "" then
            local note = C_AddOns.IsAddOnLoaded("MRT") and NSAPI:GetHash(NSAPI:GetNote()) or ""    
            if note ~= "" then
                -- Display text that tells the user the MRT note is different
            end
        end
    elseif e == "COMBAT_LOG_EVENT_UNFILTERED" and not internal then
        local _, subevent, _, _, _, _, _, _, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_APPLIED" and NSI.Externals and NSI.Externals.Automated[spellID] then
            local unit = destName
            if unit and UnitExists(unit) and UnitInRaid(unit) then
                unit = "raid"..UnitInRaid(unit)
                local key = NSI.Externals.Automated[spellID]
                NSI:EventHandler("NS_EXTERNAL_REQ", unit, key, NSI.Externals.Amount[key..spellID], false, "skip")
            end
        end
    elseif e == "NS_VERSION_CHECK" and internal then
        if WeakAuras.CurrentEncounter then return end
        local unit, ver, duplicate = ...        
        NSI:VersionResponse({name = UnitName(unit), version = ver, duplicate = duplicate})
    elseif e == "NS_VERSION_REQUEST" and internal then
        if WeakAuras.CurrentEncounter then return end
        local unit, type, name = ...        
        if UnitExists(unit) and UnitIsUnit("player", unit) then return end -- don't send to yourself
        if UnitExists(unit) and (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)) then
            local u, ver, duplicate = NSI:GetVersionNumber(type, name, unit)
            NSAPI:Broadcast("NS_VERSION_CHECK", "WHISPER", unit, ver, duplicate)
        end
    elseif e == "NSAPI_NICKNAMES_COMMS" and internal then
        if WeakAuras.CurrentEncounter then return end
        local unit, nickname, name, realm, channel = ...
        if UnitExists(unit) and UnitIsUnit("player", unit) then return end -- don't add new nickname if it's yourself because already adding it to the database when you edit it
        NSI:NewNickName(unit, nickname, name, realm, channel)
    elseif e == "NSAPI_SPEC" and internal then
        local unit, spec = ...
        NSI.specs = NSI.specs or {}
        NSI.specs[unit] = tonumber(spec)
    elseif (e == "NSAPI_SPEC_REQUEST" and internal) or (e == "ENCOUNTER_START" and not internal) then
        NSI.specs = {}

        for u in NSI:IterateGroupMembers() do
            if UnitIsVisible(u) then
                NSI.specs[u] = WeakAuras.SpecForUnit(u)
            end
        end
        -- broadcast spec info
        local specid = GetSpecializationInfo(GetSpecialization())
        NSAPI:Broadcast("NSAPI_SPEC", "RAID", specid)
        if e == "ENCOUNTER_START" then
            C_Timer.After(3, function()
                WeakAuras.ScanEvents("NSAPI_ENCOUNTER_START", true)
            end)
            NSI.Externals.target = "raid1"
            NSI.Externals.pull = GetTime()

            for u in NSI:IterateGroupMembers() do
                if UnitIsVisible(u) and (UnitIsGroupLeader(u) or UnitIsGroupAssistant(u)) then
                    NSI.Externals.target = u
                    break
                end
            end
            if UnitIsUnit("player", NSI.Externals.target) then
                NSI.Externals.UpdateExternals()
                local note = NSAPI:GetNote()
                local list = false
                local key = ""
                local spell = 0
                NSI.Externals.customprio = {}
                NSI.Externals.Automated = {}
                NSI.Externals.Amount = {}
                if note == "" then return end
                for line in note:gmatch('[^\r\n]+') do
                    --check for start/end of the name list
                    if strlower(line) == "nsexternalstart" then
                        list = true
                        key = ""
                    elseif strlower(line) == "nsexternalend" then
                        list = false
                        NSI.Externalss.Amount[key] = NSI.Externals.Amount[key] or 1
                        key = ""
                    end
                    if list then
                        for k in line:gmatch("key:(%S+)") do
                            if k ~= "default" then
                                NSI.Externals.customprio[k] = NSI.Externals.customprio[k] or {}
                            end
                            key = k
                        end
                        if key ~= "" then
                            for spellID in line:gmatch("automated:(%d+)") do
                                NSI.Externals.Automated[tonumber(spellID)] = key
                                spell = tonumber(spellID)
                            end
                            if spell ~= 0 then
                                for num in line:gmatch("amount:(%d+)") do
                                    NSI.Externals.Amount[key..spell] = tonumber(num)
                                end
                            end
                        end
                        for name, id in line:gmatch("(%S+):(%d+)") do --
                            if UnitInRaid(name) and key ~= "" then
                                if key == "default" then-- only make a default custom prio if the user actually provides one, otherwise we keep the initial default prio
                                    NSI.Externals.customprio[key] = NSI.Externals.customprio[key] or {}
                                end
                                local u = "raid"..UnitInRaid(name)
                                table.insert(NSI.Externals.customprio[key], {u, id})
                            end
                        end
                    end
                end
            end
        end
    elseif e == "NS_EXTERNAL_REQ" and ... and UnitIsUnit(NSI.Externals.target, "player") and internal then -- only accept scanevent if you are the "server"
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
            key = NSI.Externals:getprio(unitID)
        end
        NSI.Externals.assigned = {}
        local sender = realm and name.."-"..realm or name
        local found = 0
        if NSI.Externals.check[key] then -- see if an immunity or other assigned self cd's are available first
            for i, spellID in ipairs(NSI.Externals.check[key]) do
                if (spellID ~= 1022 and spellID ~= 204018 and spellID ~= 633 and spellID ~= 204018) or not C_UnitAuras.GetAuraDataBySpellName(unitID, C_Spell.GetSpellInfo(25771).name) then -- check forebearance
                    local check = unitID..spellID
                    if NSI.Externals.ready[check] then
                        return true
                    end
                end
            end
        end
        local count = 0
        if NSI.Externals.customprio[key] then
            for i, v in ipairs(NSI.Externals.customprio[key]) do
                local assigned = NSI.Externals:AssignExternal(unitID, key, num, req, range, v[1], v[2], sender)
                if assigned then
                    count = count+1
                end
                if count >= num or NSI.Externals.AllSpells[assigned] == 1 then return end -- end loop if we found enough externals or found an immunity
            end
        else
            for i, spellID in ipairs(NSI.Externals.prio[key]) do -- go through spellid's in prio order
                if NSI.Externals.known[spellID] then
                    for unit, _ in pairs(NSI.Externals.known[spellID]) do -- check each person who knows that spell if it's available and not already requested
                        if num > count then
                            local assigned = NSI.Externals:AssignExternal(unitID, key, num, req, range, unit, spellID, sender)
                            if assigned then
                                count = count+1
                            end
                            if count >= num or NSI.Externals.AllSpells[assigned] == 1 then return end -- end loop if we found enough externals or found an immunity
                        end
                    end
                end
            end
        end
        -- No External Left
        NSAPI:Broadcast("NS_EXTERNAL_NO", "WHISPER", unitID, "nilcheck")
    elseif e == "NS_EXTERNAL_YES" and internal then
        NSI.Externals.lastrequest = GetTime()
        local _, unit, spellID = ...
        NSI:DisplayExternal(spellID, unit)
    elseif e == "NS_EXTERNAL_NO" and internal then
        NSI.Externals.lastrequest = GetTime()
        NSI:DisplayExternal(nil, ...)
    elseif e == "NS_EXTERNAL_GIVE" and ... and internal then
        local _, unit, spellID = ...
        local hyperlink = C_Spell.GetSpellLink(spellID)
        WeakAuras.ScanEvents("CHAT_MSG_WHISPER", hyperlink, unit)
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