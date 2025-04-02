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
    if AddonName == "MRT" and not NSRT.MRTNickNames then
        return str
    end    
    if AddonName == "WA" and not NSRT.WANickNames then
        return str
    end
    if AddonName == "Grid2" and not NSRT.Grid2NickNames then
        return str
    end
    if AddonName == "ElvUI" and not NSRT.ElvUINickNames then
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

-- Own NickName Change
function NSI:NickNameUpdated(nickname)
    local name, realm = UnitFullName("player")
    if not realm then
        realm = GetNormalizedRealmName()
    end
    local oldnick = NSRT.NickNames[name .. "-" .. realm]
    if (not oldnick) or oldnick ~= nickname then
        NSI:SendNickName("GUILD")
        NSI:SendNickName("RAID")
        NSI:NewNickName("player", nickname, name, realm)
    end
end

-- Grid2 Option Change
function NSI:Grid2NickNameUpdated(unit)
    if Grid2 then
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

-- Cell Option Change
function NSI:CellNickNameUpdated()
    if CellDB then
        if NSRT.CellNickNames and NSRT.GlobalNickNames then
            for name, nickname in pairs(NSRT.NickNames) do
                if tInsertUnique(CellDB.nicknames.list, name .. ":" .. nickname) then
                    Cell.Fire("UpdateNicknames", "list-update", name, nickname)
                end
            end
        else
            NSI:WipeCellDB()
        end
    end
end

-- WA Option Change
function NSI:WANickNameUpdated()
    if NSRT.WANickNames and NSRT.GlobalNickNames then
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
    else
        WeakAuras.GetName = GetName
        WeakAuras.UnitName = UnitName
        WeakAuras.GetUnitName = GetUnitName
        WeakAuras.UnitFullName = UnitFullName
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

-- Wipe NickName Database
function NSI:WipeNickNames()
    NSI:WipeCellDB()
    NSRT.NickNames = {}
    fullCharList = {}
    sortedCharList = {}
    -- all addons that need a display update, which is basically all but WA
    NSI:Grid2NickNameUpdated()
    NSI:CellNickNameUpdated()
    NSI:ElvUINickNameUpdated()
end

-- Global NickName Option Change
function NSI:GlobalNickNameUpdate()
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
    NSI:WANickNameUpdated()
    NSI:Grid2NickNameUpdated()
    NSI:CellNickNameUpdated()
    NSI:ElvUINickNameUpdated()

    if UUFG then
        UUFG:UpdateAllTags() 
    end    
    -- Missing: SuF, MRT, RaidFrames, Chat, Vuhdo
end

function NSI:WipeCellDB()
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

function NSI:InitNickNames()

    NSI:WANickNameUpdated()
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

    if C_AddOns.IsAddOnLoaded("MRT") and GMRT and GMRT.F then
        GMRT.F:RegisterCallback(
            "RaidCooldowns_Bar_TextName",
            function(_, _, data)
                if data and data.name then
                    data.name = NSAPI:GetName(data.name, "MRT")
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

function NSI:SendNickName(channel)
    local nickname = NSRT.MyNickName
    local name, realm = UnitFullName("player")
    if not realm then
        realm = GetNormalizedRealmName()
    end
    if nickname then
        NSAPI:Broadcast("NSAPI_NICKNAMES_COMMS", channel, nickname, name, realm) -- channel is either GUILD or RAID
    end
end


function NSI:NewNickName(unit, nickname, name, realm)
    print("new nickanme:", unit, nickname, name, realm)
    if not nickname then return end           
    if string.len(nickname) > 12 then
        nickname = string.sub(nickname, 1, 12)
    end
    local oldnick = NSRT.NickNames[name.."-"..realm]
    if oldnick and oldnick == nickname then return end -- stop early if we already have this exact nickname
    if CellDB and NSRT.CellNickNames and NSRT.GlobalNickNames then -- have to do cell before updating name in database as old nickname may have to be overwritten in cell's own database
        local ingroup = false
        for u in NSI:IterateGroupMembers() do -- if unit is in group refresh cell display, could be a guild message instead
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
            for u in NSI:IterateGroupMembers() do -- if unit is in group refresh grid2 display, could be a guild message instead
                if UnitExists(unit) and UnitIsUnit(u, unit) then
                    Grid2Status:UpdateIndicators(u)
                    break
                end
            end
        end    
        NSI:Grid2NickNameUpdated(unit)
        NSI:ElvUINickNameUpdated()
        if UUFG then
         UUFG:UpdateAllTags() 
        end    
    end
end

