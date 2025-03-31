-- code for on nickname change
local function NickNameUpdated(nickname)
    local name, realm = UnitFullName("player")
    if not realm then
        realm = GetNormalizedRealmName()
    end
    local oldnick = NSRT.NickNames[name.."-"..realm]
    if (not oldnick) or oldnick ~= nickname then
        NSRT.MyNickName = nickname
        NSAPI:SendNickName("GUILD")
        NSAPI:SendNickName("RAID")
        NSAPI:NewNickName("player", nickname, name, realm)
    end
end

-- code for Grid2 Nickname option change
local function Grid2NickNameUpdated(enabled)
    NSRT.Grid2NickNames = enabled
    if enabled and Grid2 then
            for u in NSAPI:IterateGroupMembers() do -- if unit is in group refresh grid2 display, could be a guild message instead
                Grid2Status:UpdateIndicators(u)
                break
            end
    end
end
-- code for Cell Nickname option change
local function CellNickNameUpdated(enabled)
    NSRT.CellNickNames = enabled
    if CellDB then
        if enabled then
            CellDB.nicknames.custom = enabled
            for name, nickname in pairs(NSRT.NickNames) do
                if tInsertUnique(CellDB.nicknames.list, name..":"..nickname) then
                    Cell.Fire("UpdateNicknames", "list-update", name, nickname)
                end
            end
        else
            for name, nickname in pairs(NSRT.NickNames) do -- wipe cell database
                local i = tIndexOf(CellDB.nicknames.list, name.."-"..realm..":"..oldnick)
                if i then
                    table.remove(CellDB.nicknames.list, i)
                end
                local unit = strsplit("-", name)
                if UnitExists(unit) then
                    Cell.Fire("UpdateNicknames", "list-update", name, nickname)    -- idk if this actually removes on wiping the table
                end
            end
        end
    end
end

-- code for MRT nickname option change
local function MRTNickNameUpdated(enabled)
    NSRT.MRTNickNames = enabled
    if enabled then
        GMRT.F:RegisterCallback(
                "RaidCooldowns_Bar_TextName",
                function(_, _, data)
                    if data and data.name then
                        data.name = NSAPI:GetName(data.name)
                    end
                end
        )
    else
        GMRT.F:UnregisterCallBack("RaidCooldowns_Bar_textName")
    end

end


-- code for WA nickname option change
local function WANickNameUpdated(enabled)
    WANickNamesDisplay(enabled)
    NSRT.WANickNames = enabled
end

-- code for global nickname disable
local function GlobalNickNameUpdated(enabled)
    NSRT.GlobalNickNames = enabled
    if enabled then
        NSAPI:InitNickNames()
    else
        fullCharList = {}
        sortedCharList = {}
        if Grid2 then
            for u in NSAPI:IterateGroupMembers() do -- if unit is in group refresh grid2 display, could be a guild message instead
                Grid2Status:UpdateIndicators(u)
                break
            end
        end
        if CellDB then
            CellDB.nicknames.custom = false
        end
    end
end


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


function NSAPI:GetName(str) -- Returns Nickname
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

local function WANickNamesDisplay(enabled)
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
    end
end



function NSAPI:InitNickNames()
    WANickNamesDisplay(NSRT.WANickNames)
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
        ElvUF.Tags.Events['NSNickName:Short'] = 'UNIT_NAME_UPDATE'
        ElvUF.Tags.Events['NSNickName:Medium'] = 'UNIT_NAME_UPDATE'
        ElvUF.Tags.Methods['NSNickName'] = function(unit)
            local name = UnitName(unit)
            return name and NSAPI and NSAPI:GetName(name) or name
        end

        ElvUF.Tags.Methods['NSNickName:veryshort'] = function(unit)
            local name = UnitName(unit)
            name = name and NSAPI and NSAPI:GetName(name) or name
            return string.sub(name, 1, 5)
        end

        ElvUF.Tags.Methods['NSNickName:short'] = function(unit)
            local name = UnitName(unit)
            name = name and NSAPI and NSAPI:GetName(name) or name
            return string.sub(name, 1, 8)
        end

        ElvUF.Tags.Methods['NSNickName:medium'] = function(unit)
            local name = UnitName(unit)
            name = name and NSAPI and NSAPI:GetName(name) or name
            return string.sub(name, 1, 10)
        end
    end

    if C_AddOns.IsAddOnLoaded("MRT") and GMRT and GMRT.F and NSRT.MRTNickNames then
        GMRT.F:RegisterCallback(
                "RaidCooldowns_Bar_TextName",
                function(_, _, data)
                    if data and data.name then
                        data.name = NSAPI:GetName(data.name)
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
    local oldnick = NSRT.NickNames[name.."-"..realm]
    if oldnick and oldnick == nickname then return end -- stop early if we already have this exact nickname
    if CellDB --[[and NSRT.Cell]] then -- have to do cell before updating name in database as old nickname may have to be overwritten in cell's own database
        local ingroup = false
        for u in NSAPI:IterateGroupMembers() do -- if unit is in group refresh cell display, could be a guild message instead
            if UnitIsUnit(u, unit) then
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
    if NSRT.GlobalNickName then
        fullCharList[name.."-"..realm] = nickname
        if not sortedCharList[nickname] then
            sortedCharList[nickname] = {}
        end
        sortedCharList[nickname][name.."-"..realm] = true
    end
    if UUFG then -- update display of Unhalted Unit Frames
        UUFG:UpdateAllTags()
    end
    if Grid2 then
        for u in NSAPI:IterateGroupMembers() do -- if unit is in group refresh grid2 display, could be a guild message instead
            if UnitIsUnit(u, unit) then
                Grid2Status:UpdateIndicators(u)
                break
            end
        end
    end
end

