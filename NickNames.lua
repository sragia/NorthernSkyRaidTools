local Grid2Status
local fullCharList = {}
local sortedCharList = {}
local nicknames = {}
NSAPI.nicknames = nicknames

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

function NSAPI:GetName(str, MRT) -- Returns Nickname
    if MRT and not NSRT.MRTNickNames then
        return str
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

function nicknames:WANickNamesDisplay(enabled)
    if NSRT.WANickNames then
        function WeakAuras.GetName(name)
            return NSAPI:GetName(name)
        end

        function WeakAuras.UnitName(unit)
            local _, realm = UnitName(unit)
            return NSAPI:GetName(unit), realm
        end

        function WeakAuras.GetUnitName(unit, server)
            local name = NSAPI:GetName(unit)
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
            return NSAPI:GetName(name), realm
        end
    else
        WeakAuras.GetName = GetName
        WeakAuras.UnitName = UnitName
        WeakAuras.GetUnitName = GetUnitName
        WeakAuras.UnitFullName = UnitFullName
    end
end

function NSAPI:GlobalNickNameUpdate()
    fullCharList = {}
    sortedCharList = {}
    if NSRT.GlobalNickNames then
        for name, nickname in pairs(NSRT.NickNames) do
            fullCharList[name] = nickname
            if not sortedCharList[nickname] then
                sortedCharList[nickname] = {}
            end
            sortedCharList[nickname][name] = true
        end
    end

    
    -- instant display update for all addons
    if Grid2 then
        for u in NSAPI:IterateGroupMembers() do -- if unit is in group refresh grid2 display, could be a guild message instead
            Grid2Status:UpdateIndicators(u)
        end
     end
     if CellDB then
         if NSRT.GlobalNickNames and NSRT.CellNickNames then
            CellDB.nicknames.custom = true
            for name, nickname in pairs(NSRT.NickNames) do
                if tInsertUnique(CellDB.nicknames.list, name .. ":" .. nickname) then
                    Cell.Fire("UpdateNicknames", "list-update", name, nickname)
                end
            end
        else
            NSAPI:WipeCellDB()
        end
    end
    if ElvUF and ElvUF.Tags then
        ElvUF.Tags:RefreshMethods("NSNickName")
        for i=1, 12 do
            ElvUF.Tags:RefreshMethods("NSNickName:"..i)
        end
    end    
    if UUFG then
        UUFG:UpdateAllTags() 
    end    
    -- Missing: SuF, MRT
end

function NSAPI:WipeCellDB()
    if CellDB then
        for name, nickname in pairs(NSRT.NickNames) do -- wipe cell database
            local i = tIndexOf(CellDB.nicknames.list, name..":"..nickname)
            if i then
                local charname = strsplit("-", name)
                Cell.Fire("UpdateNicknames", "list-update", name, charname)
                table.remove(CellDB.nicknames.list, i)
            end
        end
    end
end

function NSAPI:InitNickNames()
    NSAPI.nicknames:WANickNamesDisplay(NSRT.WANickNames)
    if NSRT.GlobalNickNames then
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
            return name and NSAPI and NSAPI:GetName(name) or name
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
            return name and NSAPI and NSAPI:GetName(name) or name
        end
        for i=1, 12 do
            ElvUF.Tags.Events['NSNickName:'..i] = 'UNIT_NAME_UPDATE'
            ElvUF.Tags.Methods['NSNickName:'..i] = function(unit)
                local name = UnitName(unit)
                name = name and NSAPI and NSAPI:GetName(name) or name
                return string.sub(name, 1, i)
            end
        end
    end

    if C_AddOns.IsAddOnLoaded("MRT") and GMRT and GMRT.F then
        GMRT.F:RegisterCallback(
            "RaidCooldowns_Bar_TextName",
            function(_, _, data)
                if data and data.name then
                    data.name = NSAPI:GetName(data.name, true)
                end
            end
        )
    end

    if CellDB and NSRT.CellNickNames then
        for name, nickname in pairs(NSRT.NickNames) do
            if tInsertUnique(CellDB.nicknames.list, name..":"..nickname) then
                Cell.Fire("UpdateNicknames", "list-update", name, nickname)
            end
        end
    end
end

function NSAPI:SendNickName(channel)
    local nickname = NSRT.MyNickName
    local name, realm = UnitFullName("player")
    if not realm then
        realm = GetNormalizedRealmName()
    end
    if nickname then
        NSAPI:Broadcast("NSAPI_NICKNAMES_COMMS", channel, nickname, name, realm) -- channel is either GUILD or RAID
    end
end


function NSAPI:NewNickName(unit, nickname, name, realm)
    print("new nickanme:", unit, nickname, name, realm)
    if not nickname then return end           
    if string.len(nickname) > 12 then
        nickname = string.sub(nickname, 1, 12)
    end
    local oldnick = NSRT.NickNames[name.."-"..realm]
    if oldnick and oldnick == nickname then return end -- stop early if we already have this exact nickname
    if CellDB and NSRT.CellNickNames and NSRT.GlobalNickNames then -- have to do cell before updating name in database as old nickname may have to be overwritten in cell's own database
        local ingroup = false
        for u in NSAPI:IterateGroupMembers() do -- if unit is in group refresh cell display, could be a guild message instead
            if UnitExists(unit) and UnitIsUnit(u, unit) then
                ingroup = true
                break
            end
        end
        if oldnick then
            local i = tIndexOf(CellDB.nicknames.list, name.."-"..realm..":"..oldnick)
            if i then
                CellDB.nicknames.list[i] = name..":"..nickname
                if ingroup then
                    Cell.Fire("UpdateNicknames", "list-update", name.."-"..realm, nickname)
                end
            else
                if tInsertUnique(CellDB.nicknames.list, name.."-"..realm..":"..nickname) and ingroup then
                    Cell.Fire("UpdateNicknames", "list-update", name.."-"..realm, nickname)
                end
            end
        else
            if tInsertUnique(CellDB.nicknames.list, name.."-"..realm..":"..nickname) and ingroup then
                Cell.Fire("UpdateNicknames", "list-update", name.."-"..realm, nickname)
            end
        end
    end


    NSRT.NickNames[name.."-"..realm] = nickname
    if NSRT.GlobalNickNames then
        fullCharList[name.."-"..realm] = nickname
        if not sortedCharList[nickname] then
            sortedCharList[nickname] = {}
        end
        sortedCharList[nickname][name.."-"..realm] = true
        if UUFG then -- update display of Unhalted Unit Frames
            UUFG:UpdateAllTags()
        end
        if Grid2 then
            for u in NSAPI:IterateGroupMembers() do -- if unit is in group refresh grid2 display, could be a guild message instead
                if UnitExists(unit) and UnitIsUnit(u, unit) then
                    Grid2Status:UpdateIndicators(u)
                    break
                end
            end
        end    
        if ElvUF and ElvUF.Tags then
            ElvUF.Tags:RefreshMethods("NSNickName")
            for i=1, 12 do
                ElvUF.Tags:RefreshMethods("NSNickName:"..i)
            end
        end  
        if UUFG then
         UUFG:UpdateAllTags() 
        end    
    end
end

