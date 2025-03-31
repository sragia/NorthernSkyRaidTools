-- Todo
-- Add self cd's to allspells to possibly check those being available before externals are automatically assigned


local lib = LibStub:GetLibrary("LibOpenRaid-1.0")
_G["NSExternals"] = {}
NSExternals.ready = {}
NSExternals.known = {}
NSExternals.requested = {}
NSExternals.Automated = {}
NSExternals.Amount = {}
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

NSExternals.prio = {
    -- Life Cocoon, Time Dilation, Pain Suppression, Ironbark, Sac, Guardian  Spiritx2, Lay on Hands
    ["default"] = {Cocoon, TD, Painsup, Bark, Sac, GS1, GS2, LoH},
    ["DoubleWhammy"] = {Cocoon, TD, Painsup, Bark, GS1, GS2, Sac}, -- Life Cocoon first as it's a one-time dmg event
    ["MugzeeFrontal"] = {Sac, Bark, TD, Painsup, GS1, GS2, LoH, Cocoon}, -- sac first as there is likely a prot pally. Life Cocoon last to not waste it
}

NSExternals.AllSpells = { -- 1 = if a mechanic requests multiple externals this bypasses that and stops after finding just this one, has to be in priority list before every other external.
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
    CooldownListUpdate = function(...) NSExternals:UpdateSpell(...) end,
    CooldownListWipe = function(...) NSExternals:UpdateExternals() end,
    CooldownUpdate = function(...) NSExternals:UpdateSpell(...) end,
    CooldownAdded = function(...) NSExternals:UpdateSpell(...) end,
}

lib.RegisterCallback(callbacks, "CooldownListUpdate", "CooldownListUpdate")
lib.RegisterCallback(callbacks, "CooldownListWipe", "CooldownListWipe")
lib.RegisterCallback(callbacks, "CooldownUpdate", "CooldownUpdate")
lib.RegisterCallback(callbacks, "CooldownAdded", "CooldownAdded")

NSExternals.target = ""
NSExternals.customprio = {}



NSExternals.ignorecd = { -- spells in this list ignore their cooldown. This was added on Mug'Zee because an ability happens every 59.5 seconds while sac has a 1minute cd. You still use sac every time but the aura would think it's on CD
    ["MugzeeFrontal"] = {
        [Sac] = true,
    },
}


NSExternals.check = { -- check if ready before assigning external
    -- ["Condemnation"] = {31224, 196555, 186265, 45438, 642}, -- spell immunities

    -- example: ["NymueBeam"] = {45438, 642, 48792},
}



NSExternals.block = { -- block specific spells from specific players from being used
    ["default"] = {
        -- [633] = {["Shirup"] = true,}
    },

    ["MugzeeFrontal"] = {
        [Sac] = {["Domideus"] = true}
        -- [633] = {["Shirup"] = true,}
    }
}

NSExternals.stacks = {
    [Painsup] = true, -- Pain Suppression
    [Bark] = true, -- Ironbark
    [TD] = true, -- Time Dilation
    [Cocoon] = true, -- Life Cocoon

}



NSExternals.range = { -- slight variance on +5 yards as a little bit of movement can be expected
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


function NSExternals:getprio(unit) -- encounter/phase based priority list
    local enc = WeakAuras.CurrentEncounter and WeakAuras.CurrentEncounter.id
    if enc == 2920 then
        return "Kyveza"
    else
        return "default"
    end
end

function NSExternals:extracheck(unit, unitID, key, spellID) -- additional check if the person can actually give the external, like checking if they are in range / on the same side / stunned
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




function NSExternals:UpdateSpell(unit, spellID, cooldownInfo)
    if UnitIsUnit("player", NSExternals.target) then
        if unit and UnitExists(unit) and spellID and cooldownInfo and NSExternals.AllSpells[spellID] then
            if UnitInRaid(unit) then
                unit = "raid"..UnitInRaid(unit)
            end
            if type(spellID) == "table" then
                for id, info in pairs(spellID) do
                    NSExternals.known[spellID] = NSExternals.known[spellID] or {}
                    NSExternals.known[spellID][unit] = true
                    local k = unit..id
                    local ready, _, _, charges = lib.GetCooldownStatusFromCooldownInfo(info)
                    NSExternals.ready[k] = ready or charges >= 1
                end
            else
                NSExternals.known[spellID] = NSExternals.known[spellID] or {}
                NSExternals.known[spellID][unit] = true
                local k = unit..spellID
                local ready, _, _, charges = lib.GetCooldownStatusFromCooldownInfo(cooldownInfo)
                NSExternals.ready[k] = ready or charges >= 1
                return true
            end
        end
    end
end

function NSExternals:UpdateExternals()
    local allUnitsCooldown = lib.GetAllUnitsCooldown()
    NSExternals.known = {}
    NSExternals.ready = {}
    NSExternals.requested = {}
    if allUnitsCooldown then
        for unit, unitCooldowns in pairs(allUnitsCooldown) do
            for spellID, cooldownInfo in pairs(unitCooldowns) do
                if NSExternals.AllSpells[spellID] then
                    NSExternals:UpdateSpell(unit, spellID, cooldownInfo)
                end
            end
        end
    end
end


function NSExternals:AssignExternal(unitID, key, num, req, range, unit, spellID, sender) -- unitID = requester, unit = unit that shall give the external
    local now = GetTime()
    local k = unit..spellID
    local rangecheck = range == "skip" or (range and range[UnitInRaid(unit)] and NSExternals.range[spellID] >= range[UnitInRaid(unit)])
    local giver, realm = UnitName(unit)
    local blocked = NSExternals.block[key] and NSExternals.block[key][spellID] and NSExternals.block[key][spellID][giver]
    local self = UnitIsUnit(unit, unitID)
    if
    UnitIsVisible(unit) -- in same instance
            and (NSExternals.ready[k] or (NSExternals.ignorecd[key] and NSExternals.ignorecd[key][spellID])) -- spell is ready or we are ignoring its cd
            and NSExternals:extracheck(unit, unitID, key, spellID) -- special case checks
            and rangecheck
            and ((not NSExternals.requested[k]) or now > NSExternals.requested[k]+10) -- spell isn't already requested and the request hasn't timed out
            and not (spellID == sac and self) -- no self sac
            and not (UnitIsDead(unit))
            and not (self and req) -- don't assign own external if it was specifically requested, only on automation
            and not (C_UnitAuras.GetAuraDataBySpellName(unitID, C_Spell.GetSpellInfo(25771).name) and (spellID == Bop or spellID == Spellbop or spellID == LoH)) --Forebearance check
            and not blocked -- spell isn't specifically blocked in this case
            and not NSExternals.assigned[spellID]
    then
        NSExternals.requested[k] = now -- set spell to requested
        NSAPI:Broadcast("NS_EXTERNAL_LIST", "RAID", unit, sender, spellID) -- send List Data
        NSAPI:Broadcast("NS_EXTERNAL_GIVE", "WHISPER", unit, sender, spellID) -- send External Alert
        NSAPI:Broadcast("NS_EXTERNAL_YES", "WHISPER", unitID, giver, spellID) -- send Confirmation
        if not NSExternals.stacks[spellID] then
            NSExternals.assigned[spellID] = true
        end
        return spellID
    else
        return false
    end
end
-- /run NSExternals:Request()
function NSExternals:Request(key, num) -- optional arguments
    local now = GetTime()
    if UnitIsDead("player") or C_UnitAuras.GetAuraDataBySpellName("player", C_Spell.GetSpellInfo(27827).name) then  -- block incoming requests from dead people
        return
    end
    if ((not NSExternals.lastrequest) or (NSExternals.lastrequest < now - 4)) then
        NSExternals.lastrequest = now
        key = key or "default"
        num = num or 1
        local range = {}

        for u in NSAPI:IterateGroupMembers() do
            local _, r = WeakAuras.GetRange(u)
            table.insert(range, r)
        end
        NSAPI:Broadcast("NS_EXTERNAL_REQ", "WHISPER", NSExternals.target, key, num, true, range)    -- request external
    end
end