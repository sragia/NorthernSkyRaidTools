local _, NSI = ... -- Internal namespace
-- Todo
-- Add self cd's to allspells to possibly check those being available before externals are automatically assigned


local lib = LibStub:GetLibrary("LibOpenRaid-1.0")
NSI.Externals = {}
NSI.Externals.ready = {}
NSI.Externals.known = {}
NSI.Externals.requested = {}
NSI.Externals.Automated = {}
NSI.Externals.Amount = {}
local Sac = 6940
local Bop = 1022
local Spellbop = 204018
local Painsup = 33206
local GS1 = 47788
local GS2 = 255312
local Bark = 102342
local Cocoon = 116849
local TD = 357170
local LoH = 633
local Bubble = 642
local Block = 45438
local Turtle = 186265
local Netherwalk = 196555
local Cloak = 31224
local Icebound = 48792

NSI.Externals.prio = {
    -- Life Cocoon, Time Dilation, Pain Suppression, Ironbark, Sac, Guardian  Spiritx2, Lay on Hands
    ["default"] = {Cocoon, TD, Painsup, Bark, Sac, GS1, GS2, LoH},
    ["DoubleWhammy"] = {Cocoon, TD, Painsup, Bark, GS1, GS2, Sac}, -- Life Cocoon first as it's a one-time dmg event
    ["MugzeeFrontal"] = {Sac, Bark, TD, Painsup, GS1, GS2, LoH, Cocoon}, -- sac first as there is likely a prot pally. Life Cocoon last to not waste it
}

NSI.Externals.AllSpells = { -- 1 = if a mechanic requests multiple externals this bypasses that and stops after finding just this one, has to be in priority list before every other external.
    [Sac] = true, -- Sac
    [Bop] = 1, -- Bop
    [Spellbop] = 1, -- Spellbop
    [Painsup] = true, -- Pain Suppression
    [GS1] = true, -- Guardian Spirit
    [GS2] = true, -- Guardian Spirit 2
    [Bark] = true, -- Ironbark
    [Cocoon] = true, -- Life Cocoon
    [TD] = true, -- Time Dilation
    [LoH] = true, -- Lay on Hands
    [Bubble] = true, -- Divine Shield
    [Block] = true, -- Ice Block
    [Turtle] = true, -- Turtle
    [Netherwalk] = true, -- Netherwalk
    [Cloak] = true, -- Cloak
    [Icebound] = true, -- Icebound Fortitude
}

local callbacks = {
    CooldownListUpdate = function(...) NSI.Externals:UpdateSpell(...) end,
    CooldownListWipe = function(...) NSI.Externals:UpdateExternals() end,
    CooldownUpdate = function(...) NSI.Externals:UpdateSpell(...) end,
    CooldownAdded = function(...) NSI.Externals:UpdateSpell(...) end,
}

lib.RegisterCallback(callbacks, "CooldownListUpdate", "CooldownListUpdate")
lib.RegisterCallback(callbacks, "CooldownListWipe", "CooldownListWipe")
lib.RegisterCallback(callbacks, "CooldownUpdate", "CooldownUpdate")
lib.RegisterCallback(callbacks, "CooldownAdded", "CooldownAdded")

NSI.Externals.target = ""
NSI.Externals.customprio = {}



NSI.Externals.ignorecd = { -- spells in this list ignore their cooldown. This was added on Mug'Zee because an ability happens every 59.5 seconds while sac has a 1minute cd. You still use sac every time but the aura would think it's on CD
    ["MugzeeFrontal"] = {
        [Sac] = true,
    },
}


NSI.Externals.check = { -- check if ready before assigning external
    -- ["Condemnation"] = {31224, 196555, 186265, 45438, 642}, -- spell immunities

    -- example: ["NymueBeam"] = {45438, 642, 48792},
}



NSI.Externals.block = { -- block specific spells from specific players from being used
    ["default"] = {
        -- [633] = {["Shirup"] = true,}
    },

    ["MugzeeFrontal"] = {
        [Sac] = {["Domideus"] = true}
        -- [633] = {["Shirup"] = true,}
    }
}

NSI.Externals.stacks = {
    [Painsup] = true, -- Pain Suppression
    [Bark] = true, -- Ironbark
    [TD] = true, -- Time Dilation
    [Cocoon] = true, -- Life Cocoon

}



NSI.Externals.range = { -- slight variance on +5 yards as a little bit of movement can be expected
    [Sac] = 45, -- Sac
    [Bop] = 45, -- Bop
    [Spellbop] = 45, -- Spellbop
    [Painsup] = 45, -- Pain Suppression
    [GS1] = 45, -- Guardian Spirit
    [GS2] = 45, -- Guardian Spirit 2
    [Bark] = 45, -- Ironbark
    [Cocoon] = 45, -- Life Cocoon
    [TD] = 35, -- Time Dilation
    [LoH] = 45, -- Lay on Hands
}


function NSI.Externals:getprio(unit) -- encounter/phase based priority list
    local enc = WeakAuras.CurrentEncounter and WeakAuras.CurrentEncounter.id
    if enc == 2920 then
        return "Kyveza"
    else
        return "default"
    end
end

function NSI.Externals:extracheck(unit, unitID, key, spellID) -- additional check if the person can actually give the external, like checking if they are in range / on the same side / stunned
    -- unit = giver, unitID = receiver, key = prioname
    local enc = WeakAuras.CurrentEncounter and WeakAuras.CurrentEncounter.id
    if key == "Kyveza" and spellID == Bop and C_UnitAuras.GetAuraDataBySpellName(unitID, C_Spell.GetSpellInfo(437343).name) then -- do not assign BoP if the person already has queensbane because at that point it was requested too late
        return false
    elseif key == "Condemnation" and spellID == sac and C_UnitAuras.GetAuraDataBySpellName(unitID, C_Spell.GetSpellInfo(438974).name) then -- do not assign sac if that pally also has the mechanic
        return false
    else
        return true -- need to return false if it should not be assigned
        --[[ example
    if key == "NymueBeam" then -- no self assign on nymue since player is stunned
        return not (UnitIsUnit(unit, unitID))
    end]]
    end
    return true
end




function NSI.Externals:UpdateSpell(unit, spellID, cooldownInfo)
    if UnitIsUnit("player", NSI.Externals.target) then
        if unit and UnitExists(unit) and spellID and cooldownInfo and NSI.Externals.AllSpells[spellID] then
            if UnitInRaid(unit) then
                unit = "raid"..UnitInRaid(unit)
            end
            if type(spellID) == "table" then
                for id, info in pairs(spellID) do
                    NSI.Externals.known[spellID] = NSI.Externals.known[spellID] or {}
                    NSI.Externals.known[spellID][unit] = true
                    local k = unit..id
                    local ready, _, _, charges = lib.GetCooldownStatusFromCooldownInfo(info)
                    NSI.Externals.ready[k] = ready or charges >= 1
                end
            else
                NSI.Externals.known[spellID] = NSI.Externals.known[spellID] or {}
                NSI.Externals.known[spellID][unit] = true
                local k = unit..spellID
                local ready, _, _, charges = lib.GetCooldownStatusFromCooldownInfo(cooldownInfo)
                NSI.Externals.ready[k] = ready or charges >= 1
                return true
            end
        end
    end
end

function NSI.Externals:UpdateExternals()
    local allUnitsCooldown = lib.GetAllUnitsCooldown()
    NSI.Externals.known = {}
    NSI.Externals.ready = {}
    NSI.Externals.requested = {}
    if allUnitsCooldown then
        for unit, unitCooldowns in pairs(allUnitsCooldown) do
            for spellID, cooldownInfo in pairs(unitCooldowns) do
                if NSI.Externals.AllSpells[spellID] then
                    NSI.Externals:UpdateSpell(unit, spellID, cooldownInfo)
                end
            end
        end
    end
end


function NSI.Externals:AssignExternal(unitID, key, num, req, range, unit, spellID, sender) -- unitID = requester, unit = unit that shall give the external
    local now = GetTime()
    local k = unit..spellID
    local rangecheck = range == "skip" or (range and range[UnitInRaid(unit)] and NSI.Externals.range[spellID] >= range[UnitInRaid(unit)])
    local giver, realm = UnitName(unit)
    local blocked = NSI.Externals.block[key] and NSI.Externals.block[key][spellID] and NSI.Externals.block[key][spellID][giver]
    local self = UnitIsUnit(unit, unitID)
    if
    UnitIsVisible(unit) -- in same instance
            and (NSI.Externals.ready[k] or (NSI.Externals.ignorecd[key] and NSI.Externals.ignorecd[key][spellID])) -- spell is ready or we are ignoring its cd
            and NSI.Externals:extracheck(unit, unitID, key, spellID) -- special case checks
            and rangecheck
            and ((not NSI.Externals.requested[k]) or now > NSI.Externals.requested[k]+10) -- spell isn't already requested and the request hasn't timed out
            and not (spellID == sac and self) -- no self sac
            and not (UnitIsDead(unit))
            and not (self and req) -- don't assign own external if it was specifically requested, only on automation
            and not (C_UnitAuras.GetAuraDataBySpellName(unitID, C_Spell.GetSpellInfo(25771).name) and (spellID == Bop or spellID == Spellbop or spellID == LoH)) --Forebearance check
            and not blocked -- spell isn't specifically blocked in this case
            and not NSI.Externals.assigned[spellID]
    then
        NSI.Externals.requested[k] = now -- set spell to requested
        NSI:Broadcast("NS_EXTERNAL_LIST", "RAID", unit, sender, spellID) -- send List Data
        NSI:Broadcast("NS_EXTERNAL_GIVE", "WHISPER", unit, sender, spellID) -- send External Alert
        NSI:Broadcast("NS_EXTERNAL_YES", "WHISPER", unitID, giver, spellID) -- send Confirmation
        if not NSI.Externals.stacks[spellID] then
            NSI.Externals.assigned[spellID] = true
        end
        return spellID
    else
        return false
    end
end
-- /run NSAPI.External:Request()
function NSAPI:ExternalRequest(key, num) -- optional arguments
    local now = GetTime()
    if UnitIsDead("player") or C_UnitAuras.GetAuraDataBySpellName("player", C_Spell.GetSpellInfo(27827).name) then  -- block incoming requests from dead people
        return
    end
    if not WeakAuras.CurrentEncounter then return end
    if ((not NSI.Externals.lastrequest) or (NSI.Externals.lastrequest < now - 4)) then
        NSI.Externals.lastrequest = now
        key = key or "default"
        num = num or 1
        local range = {}

        for u in NSI:IterateGroupMembers() do
            local _, r = WeakAuras.GetRange(u)
            table.insert(range, r)
        end
        NSI:Broadcast("NS_EXTERNAL_REQ", "WHISPER", NSI.Externals.target, key, num, true, range)    -- request external
    end
end