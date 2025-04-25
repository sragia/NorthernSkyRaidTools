local _, NSI = ... -- Internal namespace
local f = CreateFrame("Frame")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:SetScript("OnEvent", function(self, e, ...)
    NSI:ArrangeGroups()
end)
NSI.Groups = {}
NSI.Groups.Processing = false

local meleetable = { -- ignoring tanks for this
    [263]  = true, -- Shaman: Enhancement
    [255]  = true, -- Hunter: Survival
    [259]  = true, -- Rogue: Assassination  
    [260]  = true, -- Rogue: Outlaw  
    [261]  = true, -- Rogue: Subtlety
    [71]   = true, -- Warrior: Arms  
    [72]   = true, -- Warrior: Fury 
    [251]  = true, -- Death Knight: Frost
    [252]  = true, -- Death Knight: Unholy
    [103]  = true, -- Druid: Feral 
    [70]   = true, -- Paladin: Retribution
    [269]  = true, -- Monk: Windwalker
    [577]  = true, -- Demon Hunter: Havoc
    [65]   = true, -- Paladin: Holy
    [270]  = true, -- Monk: Mistweaver
}

local lusttable = {
    [263]  = true, -- Shaman: Enhancement
    [255]  = true, -- Hunter: Survival
    [1473] = true, -- Evoker: Augmentation
    [1467] = true, -- Evoker: Devastation
    [253]  = true, -- Hunter: Beast Mastery
    [254]  = true, -- Hunter: Marksmanship
    [262]  = true, -- Shaman: Elemental 
    [64]   = true, -- Mage: Frost
    [62]   = true, -- Mage: Arcane
    [63]   = true, -- Mage: Fire
    [1468] = true, -- Evoker: Preservation
    [264]  = true, -- Shaman: Restoration
}

local resstable = {    
    [66]   =  true, -- Prot Pally
    [104]  =  true, -- Guardian Druid
    [250]  =  true, -- Blood DK
    [251]  = true, -- Death Knight: Frost
    [252]  = true, -- Death Knight: Unholy
    [103]  = true, -- Druid: Feral 
    [70]   = true, -- Paladin: Retribution
    [102]  = true, -- Druid: Balance
    [265]  = true, -- Warlock: Affliction 
    [266]  = true, -- Warlock: Demonology  
    [267]  = true, -- Warlock: Destruction    
    [65]   = true, -- Paladin: Holy
    [105]  = true, -- Druid: Restoration
}

local spectable = {    
    -- Tanks
    [268]  =  1, -- Brewmaster
    [66]   =  2, -- Prot Pally
    [104]  =  3, -- Guardian Druid
    [73]   =  4, -- Prot Warrior
    [581]  =  5, -- Veng DH
    [250]  =  6, -- Blood DK

    -- Melee
    [263]  = 7, -- Shaman: Enhancement
    [255]  = 8, -- Hunter: Survival
    [259]  = 9, -- Rogue: Assassination  
    [260]  = 10, -- Rogue: Outlaw  
    [261]  = 11, -- Rogue: Subtlety
    [71]   = 12, -- Warrior: Arms  
    [72]   = 13, -- Warrior: Fury 
    [251]  = 14, -- Death Knight: Frost
    [252]  = 15, -- Death Knight: Unholy
    [103]  = 16, -- Druid: Feral 
    [70]   = 17, -- Paladin: Retribution
    [269]  = 18, -- Monk: Windwalker
    [577]  = 19, -- Demon Hunter: Havoc

    -- Ranged
    [1473] = 20, -- Evoker: Augmentation
    [1467] = 21, -- Evoker: Devastation
    [253]  = 22, -- Hunter: Beast Mastery
    [254]  = 23, -- Hunter: Marksmanship
    [262]  = 24, -- Shaman: Elemental 
    [258]  = 25, -- Priest: Shadow
    [102]  = 26, -- Druid: Balance
    [64]   = 27, -- Mage: Frost
    [62]   = 28, -- Mage: Arcane
    [63]   = 29, -- Mage: Fire
    [265]  = 30, -- Warlock: Affliction 
    [266]  = 31, -- Warlock: Demonology  
    [267]  = 32, -- Warlock: Destruction    
    
    -- Healers
    [65]   = 33, -- Paladin: Holy
    [270]  = 34, -- Monk: Mistweaver
    [1468] = 35, -- Evoker: Preservation
    [105]  = 36, -- Druid: Restoration
    [264]  = 37, -- Shaman: Restoration
    [256]  = 38, -- Priest: Discipline 
    [257]  = 39, -- Priest: Holy
}


-- for testing default: /run NSAPI:SplitGroupInit(false, true, false)
-- for testing split: /run NSAPI:SplitGroupInit(false, false, false)
function NSI:SortGroup(Heroic, default, odds) -- default == tank, melee, ranged, healer
    local units = {}
    local lastgroup = Heroic and 6 or 4
    local total = {["ALL"] = 0, ["TANK"] = 0, ["HEALER"] = 0, ["DAMAGER"] = 0}
    local poscount = {0, 0, 0, 0, 0}
    local groupSize = {}
    for i=1, 40 do
        local subgroup = select(3, GetRaidRosterInfo(i))
        local unit = "raid"..i
        if not UnitExists(unit) then break end
        local specid = NSAPI:GetSpecs(unit) or 0
        local class = select(3, UnitClass(unit))
        local role = UnitGroupRolesAssigned(unit)
        if subgroup <= lastgroup then
            total[role] = total[role]+1
            total["ALL"] = total["ALL"]+1
            local melee = meleetable[specid]
            local pos = 0
            pos = (role == "TANK" and 5) or (melee and (role == "DAMAGER" and 1 or 2)) or (role == "DAMAGER" and 3) or 4 -- different counting for melee dps and melee healers
            poscount[pos] = poscount[pos]+1
            table.insert(units, {name = UnitName(unit), processed = false, unitid = unit, specid = specid, index = i, role = role, class = class, pos = pos, canlust = lusttable[class], canress = resstable[class], GUID = UnitGUID(unit)})
        end
    end    
    table.sort(units, -- default sorting with tanks - melee - ranged - healer
    function(a, b)
        if a.specid == b.specid then
            return a.GUID < b.GUID
        else
            return spectable[a.specid] < spectable[b.specid]
        end
    end) -- a < b low first, a > b high first
    NSI.Groups.total = total["ALL"]
    if default then
        NSI.Groups.units = units
        NSI:ArrangeGroups(true)
    else
        local sides = {left = {}, right = {}}
        local classes = {left = {}, right = {}}
        local specs = {left = {}, right = {}}
        local pos = {left = {0, 0, 0, 0, 0}, right = {0, 0, 0, 0, 0}}
        local roles = {left = {}, right = {}}
        local lust = {left = false, right = false}
        local bress = {left = 0, right = 0}
        for i=1, 3 do
            local role = i == 1 and "TANK" or i == 2 and "DAMAGER" or i == 3 and "HEALER"
            roles.left.role = 0
            roles.right.role = 0
            for _, v in ipairs(units) do
                if v.role == role then
                    local side = ""
                    if role == "TANK" then side = roles.left.role <= roles.right.role and "left" or "right" -- for tanks doing a simple left/right split not caring about specs
                    elseif #sides.left >= total["ALL"]/2 then side = "right" -- if left side is already filled, everyone else goes to the right side
                    elseif roles.left.role >= total[role]/2 then side = "right" -- if left side already has half of the total players of that role, rest goes to right side
                    elseif pos.left[v.pos] >= poscount[v.pos]/2 then side = "right" -- if one side already has enough melee, insert to the other side
                    elseif pos.right[v.pos]  >= poscount[v.pos]/2 then side = "left" -- same as last                       
                    elseif not classes.left[v.class] then side = "left" -- if one side doesn't have this class yet, insert to that side
                    elseif not classes.right[v.class] then side = "right" -- same as last
                    elseif v.canress and (bress.left <= 1 or bress.right <= 1) then side = (bress.left <= 1 and bress.left <= bress.right and "left") or "right" -- give each side up to 2 bresses
                    elseif v.canlust and ((not lust.left) or (not lust.right)) then side = ((not lust.left) and "left") or "right" -- give each side a lust
                    elseif (not specs.left[v.specid]) or (specs.right[v.specid] and specs.left[v.specid] <= specs.right[v.specid]) then side = "left" -- evenly split specs
                    else side = "right"
                    end

                    if side == "left" then
                        table.insert(sides.left, v) 
                        classes.left[v.class] = true 
                        pos.left[v.pos] = pos.left[v.pos]+1
                        if v.canlust then lust.left = lust.left+1 end
                        if v.canress then bress.left = bress.left+1 end
                        specs.left[v.specid] = (specs.left[v.specid] and specs.left[v.specid]+1) or 1
                        roles.left.role = roles.left.role+1
                    else 
                        table.insert(sides.right, v) 
                        classes.right[v.class] = true 
                        pos.right[v.pos] = pos.right[v.pos]+1
                        if v.canlust then lust.right = lust.right+1 end
                        if v.canress then bress.right = bress.right+1 end
                        specs.right[v.specid] = (specs.right[v.specid] and specs.right[v.specid]+1) or 1
                        roles.right.role = roles.right.role+1
                    end
                end
            end
        end       
        table.sort(sides.left, -- sort again within each table with tanks - melee - ranged - healer
        function(a, b)
            if a.specid == b.specid then
                return a.GUID < b.GUID
            else
                return spectable[a.specid] < spectable[b.specid]
            end
        end) -- a < b low first, a > b high first        
        table.sort(sides.right, -- sort again within each table with tanks - melee - ranged - healer
        function(a, b)
            if a.specid == b.specid then
                return a.GUID < b.GUID
            else
                return spectable[a.specid] < spectable[b.specid]
            end
        end) -- a < b low first, a > b high first
        if NSI.Groups.Odds then
            units = {}
            local count = 1
            for i, v in ipairs(sides.left) do
                units[count] = v
                count = count+1
                if count > 5 then count = 11 end
                if count > 15 then count = 21 end
            end
            count = 6            
            for i, v in ipairs(sides.right) do
                units[count] = v
                count = count+1
                if count > 10 then count = 16 end
                if count > 20 then count = 26 end
            end
            NSI.Groups.units = units
            NSI:ArrangeGroups(true)
        else            
            units = {}
            local count = 1
            for i, v in ipairs(sides.left) do
                units[count] = v
                count = count+1
            end
            if total["ALL"] > 20 then count = 16 
            elseif total["ALL"] > 10 then count = 11
            else count = 6
            end
            for i, v in ipairs(sides.right) do
                units[count] = v
                count = count+1
            end
            NSI.Groups.units = units
            NSI:ArrangeGroups(true)
        end
        
    end    
end

function NSI:ArrangeGroups(firstcall)
    if not firstcall and not NSI.Groups.Processing then return end
    local now = GetTime()
    if firstcall then NSI.Groups.Processing = true NSI.Groups.Processed = 0 NSI.Groups.ProcessStart = now end
    if NSI.Groups.ProcessStart and now > NSI.Groups.ProcessStart+10 then NSI.Groups.Processing = false return end -- backup stop if it takes super long we're probably in a loop somehow
    DevTool:AddData(NSI.Groups.units, "Split Table Data:")
    local groupSize = {0, 0, 0, 0, 0, 0, 0, 0}
    local postoindex = {}
    local indextosubgroup = {}
    local indextosubgroupposition = {}
    for i=1, 40 do
        local subgroup = select(3, GetRaidRosterInfo(i))
        if not subgroup then break end
        groupSize[subgroup] = groupSize[subgroup]+1
        postoindex[((subgroup-1)*5)+groupSize[subgroup]] = i 
        indextosubgroup[i] = subgroup
        indextosubgroupposition[i] = groupSize[subgroup]
    end

    for i=1, 40 do -- position in table is where the player should end up in, v.index is their current position.
        local v = NSI.Groups.units[i]    
        if NSI.Groups.Processed >= NSI.Groups.total then NSI.Groups.Processing = false break end
        if v and not v.processed then 
            local group = Round((i+4)/5)
            local subgroupposition = i % 5 == 0 and 5 or i % 5
            local position = ((group-1)*5)+subgroupposition
            local index = UnitInRaid(v.name)
            NSI:Print(v.name, "belongs into group", group, "at position", subgroupposition, "index:", index)
            if position ~= ((indextosubgroup[index]-1)*5)+indextosubgroupposition[index] then -- check if player is already in correct spot
                if groupSize[group] < subgroupposition and indextosubgroup[index] ~= group then
                    NSI:Print("putting", v.name, "into group", group)
                    SetRaidSubgroup(index, group)
                    v.processed = true
                    NSI.Groups.Processed = NSI.Groups.Processed+1
                    break
            
                elseif postoindex[position] ~= index then
                    if indextosubgroup[index] ~= indextosubgroup[postoindex[position]]  then
                        NSI:Print("swapping position", postoindex[position], "and", v.name)
                        SwapRaidSubgroup(postoindex[position], index)
                        v.processed = true
                        NSI.Groups.Processed = NSI.Groups.Processed+1
                        break
                    else -- the 2 players to swap are in the same group so we instead swap with someone random that hasn't been processed yet
                        local found = false
                        for j=1, 40 do
                            local u = NSI.Groups.units[j]
                            if u and not u.processed and not UnitIsUnit(v.name, u.name) then
                                if group ~= Round((j+4)/5) then
                                    NSI:Print("backup swap", u.name, "with", v.name)
                                    SwapRaidSubgroup(UnitInRaid(u.name), index)
                                    found = true
                                    break
                                end
                            end
                        end             
                        if not found then -- if we were somehow unable to find anyone we can swap this person with, try to put him into an empty group at the end instead                    
                            for j = 8, 1, -1 do
                                if groupSize[j] < 5 then
                                    NSI:Print("backup group", v.name, "into", j)
                                    SetRaidSubgroup(index, j)
                                    break
                                end
                            end
                        end
                    end  
                end
            else -- character is already in the correct position
                NSI:Print(v.name, "already in correct position")
                v.processed = true
                NSI.Groups.Processed = NSI.Groups.Processed+1
                NSI:ArrangeGroups()
            end
                
        end        
    end
end

-- Change to NSI once integrated into the UI
function NSAPI:SplitGroupInit(Heroic, default, odds)
    NSI:Broadcast("NSAPI_SPEC_REQUEST", "RAID", "nilcheck")
    C_Timer.After(2, function() NSI:SortGroup(Heroic, default, odds) end)
end