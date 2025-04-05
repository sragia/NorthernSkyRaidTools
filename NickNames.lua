local _, NSI = ... -- Internal namespace
local Grid2Status
local fullCharList = {}
local sortedCharList = {}

function NSAPI:GetCharacters(str) -- Returns table of all Characters from Nickname or Character Name
    if not str then
        error("NSAPI:GetCharacters(str), str is nil")
        return
    end
    return sortedCharList[str] and CopyTable(sortedCharList[str])
end

function NSAPI:GetAllCharacters()
    return CopyTable(fullCharList)
end

function NSAPI:GetName(str, AddonName) -- Returns Nickname
    if not NSRT.Settings["GlobalNickNames"] then
        return UnitExists(str) and UnitName(str) or str
    end
    if AddonName == "MRT" and not NSRT.Settings["MRT"] then
        return UnitExists(str) and UnitName(str) or str
    end    
    if AddonName == "WA" and not NSRT.Settings["WA"] then
        return UnitExists(str) and UnitName(str) or str
    end
    if AddonName == "Grid2" and not NSRT.Settings["Grid2"] then
        return UnitExists(str) and UnitName(str) or str
    end
    if AddonName == "ElvUI" and not NSRT.Settings["ElvUI"] then
        return UnitExists(str) and UnitName(str) or str
    end    
    if AddonName == "SuF" and not NSRT.Settings["SuF"] then
        return UnitExists(str) and UnitName(str) or str
    end    
    if AddonName == "Unhalted" and not NSRT.Settings["Unhalted"] then
        return UnitExists(str) and UnitName(str) or str
    end
    if AddonName == "Blizzard" and not NSRT.Settings["Blizzard"] then
        return UnitExists(str) and UnitName(str) or str
    end
    if AddonName == "OmniCD" and not NSRT.Settings["OmniCD"] then
        return UnitExists(str) and UnitName(str) or str
    end

    if not str then
        error("NSAPI:GetName(str), str is nil")
        return
    end
    if UnitExists(str) then
        local name, realm = UnitFullName(str)
        if not realm then
            realm = GetNormalizedRealmName()
        end
        return name and realm and fullCharList[name.."-"..realm] or name
    else
        return fullCharList[str] or str
    end
end

function NSAPI:GetChar(name, nick) -- Returns Char in Raid from Nickname or Character Name with nick = true
    name = nick and NSAPI:GetName(name) or name
    if UnitExists(name) and UnitIsConnected(name) then return name end
    local chars = NSAPI:GetCharacters(name)
    if chars then
        for k, _ in pairs(chars) do
            local name = strsplit("-", k)
            local i = UnitInRaid(k)
            if UnitIsVisible(name) or (i and select(3, GetRaidRosterInfo(i)) <= 4)  then
                return k
            end
        end
    end
    return name -- Return input if nothing was found
end

-- Own NickName Change
function NSI:NickNameUpdated(nickname)
    local name, realm = UnitFullName("player")
    if not realm then
        realm = GetNormalizedRealmName()
    end
    local oldnick = NSRT.NickNames[name .. "-" .. realm]
    if (not oldnick) or oldnick ~= nickname then
        NSI:SendNickName()
        NSI:NewNickName("player", nickname, name, realm)
    end
end

-- Grid2 Option Change
function NSI:Grid2NickNameUpdated(all, unit)
    if Grid2 then
        if all then
            for u in NSI:IterateGroupMembers() do
                Grid2Status:UpdateIndicators(u)
            end
        else
            for u in NSI:IterateGroupMembers() do -- if unit is in group refresh grid2 display, could be a guild message instead
                if unit then
                    if UnitExists(unit) and UnitIsUnit(u, unit) then
                        Grid2Status:UpdateIndicators(u)
                        break
                    end
                else
                    Grid2Status:UpdateIndicators(u)
                end    
            end
        end
     end
end

-- Wipe NickName Database
function NSI:WipeNickNames()
    NSI:WipeCellDB()
    NSRT.NickNames = {}
    fullCharList = {}
    sortedCharList = {}
    -- all addons that need a display update, which is basically all but WA
    NSI:UpdateNickNameDisplay(true)
end

function NSI:WipeCellDB()
    if CellDB then
        for name, nickname in pairs(NSRT.NickNames) do -- wipe cell database
            print(name, nickname)
            local i = tIndexOf(CellDB.nicknames.list, name..":"..nickname)
            if i then
                print("removing", name, nickname)
                local charname = strsplit("-", name)
                Cell.Fire("UpdateNicknames", "list-update", name, charname)
                table.remove(CellDB.nicknames.list, i)
            end
        end
    end
end

function NSI:BlizzardNickNameUpdated()
    if C_AddOns.IsAddOnLoaded("Blizzard_CompactRaidFrames") and NSRT.Settings["Blizzard"] and not NSRT.BlizzardNickNamesHook then
        NSRT.BlizzardNickNamesHook = true
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            if frame:IsForbidden() or not frame.unit then
                return
            end
            frame.name:SetText(NSAPI:GetName(frame.unit, "Blizzard"))
        end)
    end
end

function NSI:MRTNickNameUpdated()
    if NSRT.Settings["MRT"] and C_AddOns.IsAddOnLoaded("MRT") and GMRT and GMRT.F and not NSRT.MRTNickNamesHook then
        NSRT.MRTNickNamesHook = true
        GMRT.F:RegisterCallback(
            "RaidCooldowns_Bar_TextName",
            function(event, bar, data)
                if data and data.name then
                    data.name = NSAPI:GetName(data.name, "MRT")
                end
            end
        )
    end
end

function NSI:OmniCDNickNameUpdated()
    if NSRT.Settings["OmniCD"] and C_AddOns.IsAddOnLoaded("OmniCD") and not NSRT.OmniCDNickNamesHook then
        NSRT.OmniCDNickNamesHook = true
        -- Add OmniCD Hook
    end
end

-- Cell Option Change
function NSI:CellNickNameUpdated(all, unit, name, realm, oldnick, nickname)
    if CellDB then
        if NSRT.Settings["Cell"] and NSRT.Settings["GlobalNickNames"] then
            if all then -- update all units
                for u in NSI:IterateGroupMembers() do
                    local name, realm = UnitFullName(u)
                    if not realm then
                        realm = GetNormalizedRealmName()
                    end
                    if NSRT.NickNames[name.."-"..realm] then
                        local nick = NSRT.NickNames[name.."-"..realm]
                        local i = tIndexOf(CellDB.nicknames.list, name.."-"..realm..":"..nick)
                        if i then -- update nickame if it already exists
                            CellDB.nicknames.list[i] = name.."-"..realm..":"..nick
                            Cell.Fire("UpdateNicknames", "list-update", name.."-"..realm, nick)
                        else -- insert if it doesn't exist yet
                            NSI:CellInsertName(name, realm, nick, true)
                        end
                    end
                end
                return
            elseif nickname == "" then -- newnick is an empty string so remove any old nick we still have
                if oldnick then -- if there is an oldnick, remove it 
                    local i = tIndexOf(CellDB.nicknames.list, name.."-"..realm..":"..oldnick)
                    if i then
                        table.remove(CellDB.nicknames.list, i)
                        Cell.Fire("UpdateNicknames", "list-update", name.."-"..realm, name)
                    end
                end
            elseif unit then -- if the function was called for a sepcific unit
                local ingroup = false
                for u in NSI:IterateGroupMembers() do -- if unit is in group refresh cell display, could be a guild message instead
                    if UnitExists(unit) and UnitIsUnit(u, unit) then
                        ingroup = true
                        break
                    end
                end
                if oldnick then -- check if oldnick exists in database already and overwrite it if it does, otherwise insert
                    local i = tIndexOf(CellDB.nicknames.list, name.."-"..realm..":"..oldnick)
                    if i then
                        CellDB.nicknames.list[i] = name.."-"..realm..":"..nickname
                        if ingroup then
                            Cell.Fire("UpdateNicknames", "list-update", name.."-"..realm, nickname)
                        end
                    else
                        NSI:CellInsertName(name, realm, nickname, ingroup)
                    end
                else -- if no old nickname, just insert the new one
                    NSI:CellInsertName(name, realm, nickname, ingroup)
                end
            end
        else
            NSI:WipeCellDB()
        end
    end
end

function NSI:CellInsertName(name, realm, nickname, ingroup)
    if tInsertUnique(CellDB.nicknames.list, name.."-"..realm..":"..nickname) and ingroup then
        Cell.Fire("UpdateNicknames", "list-update", name.."-"..realm, nickname)
    end
end



-- ElvUI Option Change
function NSI:ElvUINickNameUpdated()
    if ElvUF and ElvUF.Tags then
        ElvUF.Tags:RefreshMethods("NSNickName")
        for i=1, 12 do
            ElvUF.Tags:RefreshMethods("NSNickName:"..i)
        end
    end    
end

-- UUFG Option Change
function NSI:UnhaltedNickNameUpdated()
    if UUFG then
        UUFG:UpdateAllTags() 
    end    
end

-- Global NickName Option Change
function NSI:GlobalNickNameUpdate()
    fullCharList = {}
    sortedCharList = {}
    if NSRT.Settings["GlobalNickNames"] then
        for name, nickname in pairs(NSRT.NickNames) do
            fullCharList[name] = nickname
            if not sortedCharList[nickname] then
                sortedCharList[nickname] = {}
            end
            sortedCharList[nickname][name] = true
        end
    end
    
    -- instant display update for all addons
    NSI:UpdateNickNameDisplay(true)
end



function NSI:UpdateNickNameDisplay(all, unit, name, realm, oldnick, nickname)    
    NSI:CellNickNameUpdated(all, unit, name, realm, oldnick, nickname) -- always have to do cell before doing any changes to the nickname database
    if nickname == ""  and NSRT.NickNames[name.."-"..realm] then
        NSRT.NickNames[name.."-"..realm] = nil
        fullCharList[name.."-"..realm] = nil
        sortedCharList[nickname] = nil
    end     
    NSI:Grid2NickNameUpdated(unit)
    NSI:ElvUINickNameUpdated()
    NSI:UnhaltedNickNameUpdated()
    NSI:BlizzardNickNameUpdated()
    NSI:MRTNickNameUpdated()
    NSI:OmniCDNickNameUpdated()
end

function NSI:InitNickNames()
    if not C_AddOns.IsAddOnLoaded("CustomNames") then
        function WeakAuras.GetName(name)
            return NSAPI:GetName(name, "WA")
        end

        function WeakAuras.UnitName(unit)
            local _, realm = UnitName(unit)
            return NSAPI:GetName(unit, "WA"), realm
        end

        function WeakAuras.GetUnitName(unit, server)
            local name = NSAPI:GetName(unit, "WA")
            if server then
                local _, realm = UnitFullName(unit)
                if not realm then
                    realm = GetNormalizedRealmName()
                end
                name = name.."-"..realm
            end
            return name
        end

        function WeakAuras.UnitFullName(unit)
            local name, realm = UnitFullName(unit)
            return NSAPI:GetName(name, "WA"), realm
        end
    end

    NSI:BlizzardNickNameUpdated()
    NSI:MRTNickNameUpdated()
    NSI:OmniCDNickNameUpdated()

    if NSRT.Settings["GlobalNickNames"] then
        for name, nickname in pairs(NSRT.NickNames) do
            fullCharList[name] = nickname
            if not sortedCharList[nickname] then
                sortedCharList[nickname] = {}
            end
            sortedCharList[nickname][name] = true
        end
    end

    if Grid2 then
        Grid2Status = Grid2.statusPrototype:new("NSNickName")

        Grid2Status.IsActive = Grid2.statusLibrary.IsActive

        function Grid2Status:UNIT_NAME_UPDATE(_, unit)
            self:UpdateIndicators(unit)
        end

        function Grid2Status:OnEnable()
            self:RegisterEvent("UNIT_NAME_UPDATE")
        end

        function Grid2Status:OnDisable()
            self:UnregisterEvent("UNIT_NAME_UPDATE")
        end

        function Grid2Status:GetText(unit)
            local name = UnitName(unit)
            return name and NSAPI and NSAPI:GetName(name, "Grid2") or name
        end

        local function Create(baseKey, dbx)
            Grid2:RegisterStatus(Grid2Status, {"text"}, baseKey, dbx)
            return Grid2Status
        end

        Grid2.setupFunc["NSNickName"] = Create

        Grid2:DbSetStatusDefaultValue( "NSNickName", {type = "NSNickName"})        
        end

    if ElvUF and ElvUF.Tags then
        ElvUF.Tags.Events['NSNickName'] = 'UNIT_NAME_UPDATE'
        ElvUF.Tags.Methods['NSNickName'] = function(unit)
            local name = UnitName(unit)
            return name and NSAPI and NSAPI:GetName(name, "ElvUI") or name
        end
        for i=1, 12 do
            ElvUF.Tags.Events['NSNickName:'..i] = 'UNIT_NAME_UPDATE'
            ElvUF.Tags.Methods['NSNickName:'..i] = function(unit)
                local name = UnitName(unit)
                name = name and NSAPI and NSAPI:GetName(name, "ElvUI") or name
                return string.sub(name, 1, i)
            end
        end
    end

    if UUFG and UUFG.Tags then
        UUFG.Tags.Events['NSNickName'] = 'UNIT_NAME_UPDATE'
        UUFG.Tags.Methods['NSNickName'] = function(unit)
            local name = UnitName(unit)
            return name and NSAPI and NSAPI:GetName(name, "Unhalted") or name
        end
        for i=1, 12 do
            UUFG.Tags.Events['NSNickName:'..i] = 'UNIT_NAME_UPDATE'
            UUFG.Tags.Methods['NSNickName:'..i] = function(unit)
                local name = UnitName(unit)
                name = name and NSAPI and NSAPI:GetName(name, "Unhalted") or name
                return string.sub(name, 1, i)
            end
        end
    end


    if CellDB and NSRT.Settings["Cell"] then
        for name, nickname in pairs(NSRT.NickNames) do
            if tInsertUnique(CellDB.nicknames.list, name..":"..nickname) then
                Cell.Fire("UpdateNicknames", "list-update", name, nickname)
            end
        end
    end
end

function NSI:SendNickName(channel)
    local nickname = NSRT.Settings["MyNickName"]
    if (not nickname) or WeakAuras.CurrentEncounter then return end
    local name, realm = UnitFullName("player")
    if not realm then
        realm = GetNormalizedRealmName()
    end
    if nickname then
        if UnitInRaid("player") and (NSRT.Settings["ShareNickNames"] == 1 or NSRT.Settings["ShareNickNames"] == 3) then
            NSI:Broadcast("NSI_NICKNAMES_COMMS", "RAID", nickname, name, realm, "RAID")
        end
        if NSRT.Settings["ShareNickNames"] == 2 or NSRT.Settings["ShareNickNames"] == 3 then
            NSI:Broadcast("NSI_NICKNAMES_COMMS", "GUILD", nickname, name, realm, "GUILD") -- channel is either GUILD or RAID
        end
    end
end

function NSI:NewNickName(unit, nickname, name, realm, channel)
    if WeakAuras.CurrentEncounter then return end
    if unit ~= "player" and NSRT.Settings["AcceptNickNames"] ~= 3 then
        if channel == "GUILD" and NSRT.Settings["AcceptNickNames"] ~= 2 then return end
        if channel == "RAID" and NSRT.Settings["AcceptNickNames"] ~= 1 then return end
    end
    print("new nickanme:", unit, nickname, name, realm)
    if not nickname or not name or not realm then return end   
    local oldnick = NSRT.NickNames[name.."-"..realm]      
    if oldnick and oldnick == nickname then return end -- stop early if we already have this exact nickname  
    if nickname == "" then
        NSI:UpdateNickNameDisplay(false, unit, name, realm, oldnick, nickname)
        return
    end
    if string.len(nickname) > 12 then
        nickname = string.sub(nickname, 1, 12)
    end
    NSRT.NickNames[name.."-"..realm] = nickname
    if NSRT.Settings["GlobalNickNames"] then
        fullCharList[name.."-"..realm] = nickname
        if not sortedCharList[nickname] then
            sortedCharList[nickname] = {}
        end
        sortedCharList[nickname][name.."-"..realm] = true
        NSI:UpdateNickNameDisplay(false, unit, name, realm, oldnick, nickname)
    end
end


function NSI:ImportNickNames(string) -- string format is charactername-realm:nickname;charactername-realm:nickname;...
    if string ~= "" then
        for _, str in pairs({strsplit(";", string)}) do
            local namewithrealm, nickname = strsplit(":", str)
            if namewithrealm and nickname then
                local name, realm = strsplit("-", namewithrealm)
                local unit
                if not NSRT.NickNames[name.."-"..realm] then
                    NSRT.NickNames[name.."-"..realm] = nickname
                end
            else
                error("Error parsing names", str, namewithrealm, nickname)
            end
        end
        NSI:GlobalNickNameUpdate()
    end
end

function NSI:SynchNickNames(channel)
    NSI:Broadcast("NSI_NICKNAMES_SYNCH", channel, NSRT.NickNames)
end

function NSI:SynchNickNamesAccept(nicknametable)
    for name, nickname in pairs(nicknametable) do
        if not NSRT.NickNames[k] then
            NSRT.NickNames[name] = nickname
        end
    end
    NSI:GlobalNickNameUpdate()
end
