local _, NSI = ... -- Internal namespace

-- Function from WeakAuras, thanks rivers
function NSI:IterateGroupMembers(reversed, forceParty)
    local unit = (not forceParty and IsInRaid()) and 'raid' or 'party'
    local numGroupMembers = unit == 'party' and GetNumSubgroupMembers() or GetNumGroupMembers()
    local i = reversed and numGroupMembers or (unit == 'party' and 0 or 1)
    return function()
        local ret
        if i == 0 and unit == 'party' then
            ret = 'player'
        elseif i <= numGroupMembers and i > 0 then
            ret = unit .. i
        end
        i = i + (reversed and -1 or 1)
        return ret
    end
end

function NSAPI:Version() -- old version check function from the database WA, for compatibility reasons
    return 14
end

function NSI:Print(...)
    if NSRT.Settings["Debug"] then
        print(...)
    end
end

function NSAPI:Shorten(unit, num, role, AddonName) -- Returns color coded Name/Nickname
    local classFilename = unit and select(2, UnitClass(unit))
    if role then -- create role icon if requested
        role = UnitGroupRolesAssigned(unit)
        if role ~= "NONE" then
            role = CreateAtlasMarkup(GetIconForRole(role), 0, 0)
        else
            role = nil
        end
    end
    if classFilename then -- basically "if unit found"
        local name = UnitName(unit)
        local color = GetClassColorObj(classFilename)
        name = num and WeakAuras.WA_Utf8Sub(NSAPI:GetName(name, AddonName), num) or NSAPI:GetName(name, AddonName) -- shorten name before wrapping in color
        if color then -- should always be true anyway?
            return color:WrapTextInColorCode(name), role
        else
            return name, role
        end
    else
        return unit, "" -- return input if nothing was found
    end
end

function NSAPI:GetSpecs(unit)
    if unit then
        return NSI.specs[unit] or false -- return false if no information available for that unit so it goes to the next fallback
    else
        return NSI.specs -- if no unit is given then entire table is requested
    end
end


function NSAPI:GetNote() -- Get rid of extra spaces and color coding. Also converts nicknames for Northern Sky/velocity.
    if not C_AddOns.IsAddOnLoaded("MRT") then
        error("Addon MRT is disabled, can't read the note")
        return ""
    end
    if not VMRT.Note.Text1 then
        error("No MRT Note found")
        return ""
    end
    local note = _G.VMRT.Note.Text1
    local now = GetTime()
    if (not NSI.RawNote) or NSI.RawNote ~= note or NSI.disable then -- only do this if it's been at least 1 second since the last time this was done or the note has changed within that small time to prevent running it multiple times on the same encounter if there are multiple assignment auras
        NSI.RawNote = note

        -- only return the relevant part of the note as the user might change stuff on their own end

        local newnote = ""
        local list = false
        local disable = false
        for line in note:gmatch('[^\r\n]+') do
            if line == "nsdisable" then -- global disable all NS Auras for everyone in the raid
                disable = true
            end
            --check for start/end of the name list
            if string.match(line, "ns.*start") or line == "intstart" then -- match any string that starts with "ns" and ends with "start" as well as the interrupt WA
                list = true
            elseif string.match(line, "ns.*end") or line == "intend" then
                list = false
                newnote = newnote..line.."\n"
            end
            if list then
                newnote = newnote..line.."\n"
            end
        end
        NSAPI.disable = disable
        note = newnote
        note = strtrim(note) --trim whitespace
        note = note:gsub("||r", "") -- clean colorcode
        note = note:gsub("||c%x%x%x%x%x%x%x%x", "") -- clean colorcode
            local namelist = {}
            for name in note:gmatch("%S+") do -- finding all strings
                local charname = (UnitIsVisible(name) and name) or NSAPI:GetChar(name, true)
                if name ~= charname and not namelist[name] then
                    namelist[name] = charname
                end
            end
            for nickname, charname in pairs(namelist) do
                note = note:gsub("(%f[%w])"..nickname.."(%f[%W])", "%1"..charname.."%2")
            end
        NSI.Note = note
    end
    NSI.Note = NSI.Note or ""
    return NSI.Note
end


function NSAPI:GetHash(text)
    local counter = 1
    local len = string.len(text)
    for i = 1, len, 3 do
        counter = math.fmod(counter*8161, 4294967279) +  -- 2^32 - 17: Prime!
                (string.byte(text,i)*16776193) +
                ((string.byte(text,i+1) or (len-i+256))*8372226) +
                ((string.byte(text,i+2) or (len-i+256))*3932164)
    end
    return math.fmod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)
end


function NSAPI:TTS(sound, voice)
  if NSRT.Settings["TTS"] then
      local num = voice or NSRT.Settings["TTSVoice"]
        C_VoiceChat.SpeakText(
                num,
                sound,
                Enum.VoiceTtsDestination.LocalPlayback,
                C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0,
                NSRT.Settings["TTSVolume"]
        )
     end
end
-- NSAPI:TTS("Bait Frontal", NSRT.TTSVoice)