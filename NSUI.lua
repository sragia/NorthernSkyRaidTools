local _, NSI = ... -- Internal namespace
local DF = _G["DetailsFramework"]
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LDB and LibStub("LibDBIcon-1.0")
local WA = _G["WeakAuras"]

local window_width = 800
local window_height = 515
local expressway = [[Interface\AddOns\NorthernSkyRaidTools\Media\Fonts\Expressway.TTF]]

local options_text_template = DF:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
local options_dropdown_template = DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
local options_switch_template = DF:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
local options_slider_template = DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
local options_button_template = DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

local NSUI_panel_options = {
    UseStatusBar = true
}
local NSUI = DF:CreateSimplePanel(UIParent, window_width, window_height, "|cFF00FFFFNorthern Sky|r Raid Tools", "NSUI",
    NSUI_panel_options)
NSUI:SetPoint("CENTER")
NSUI:SetFrameStrata("HIGH")
local statusbar_text = DF:CreateLabel(NSUI.StatusBar, "Northern Sky x |cFF00FFFFbird|r")
statusbar_text:SetPoint("left", NSUI.StatusBar, "left", 2, 0)
-- DF:BuildStatusbarAuthorInfo(NSUI.StatusBar, _, "Reloe & Rav :)")

NSUI.OptionsChanged = {
    ["general"] = {},
    ["nicknames"] = {},
    ["externals"] = {},
    ["versions"] = {},
}

-- need to run this code on settings change
local function PASelfPingChanged()
    local macrocount = 0
    local pafound = false
    for i = 1, 120 do
        local macroname = C_Macro.GetMacroName(i)
        if not macroname then break end
        macrocount = i
        if macroname == "NS PA Macro" then
            pafound = true
            local macrotext = "/run WeakAuras.ScanEvents(\"NS_PA_MACRO\", true);"
            if NSRT.Settings["PASelfPing"] then
                 macrotext = macrotext.."\n/ping [@player] Warning;"
             end
            if NSRT.Settings["PAExtraAction"] then
                macrotext = macrotext.."\n/click ExtraActionButton1"
            end
             EditMacro(i, "NS PA Macro", 132288, macrotext, false)
            break
        end
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
end

-- need to run this code on settings change
local function ExternalSelfPingChanged()
    local macrocount = 0
    local extfound = false
    for i = 1, 120 do
        local macroname = C_Macro.GetMacroName(i)
        if not macroname then break end
        macrocount = i
        if macroname == "NS Ext Macro" then
            extfound = true
            local macrotext = NSRT.Settings["ExternalSelfPing"] and "/run NSAPI.ExternalRequest();\n/ping [@player] Assist;" or
                "/run NSAPI.ExternalRequest();"
            EditMacro(i, "NS Ext Macro", 135966, macrotext, false)
            extfound = true
            break
        end
    end
    if macrocount >= 120 then 
        print("You reached the global Macro cap so the External Macro could not be created")
    elseif not extfound then
        macrocount = macrocount+1
        local macrotext = NSRT.Settings["ExternalSelfPing"] and "/run NSAPI.ExternalRequest();\n/ping [@player] Assist;" or "/run NSAPI.ExternalRequest();"
        CreateMacro("NS Ext Macro", 135966, macrotext, false)
    end
end

-- version check ui
local component_type = "WA"
local checkable_components = { "WA", "Addon", "Note" }
local function build_checkable_components_options()
    local t = {}
    for i = 1, #checkable_components do
        tinsert(t, {
            label = checkable_components[i],
            value = checkable_components[i],
            onclick = function(_, _, value)
                print("Checkable type selected: " .. value)
                component_type = value
            end
        })
    end
    return t
end

local component_name = ""
local function BuildVersionCheckUI(parent)
    local component_type_label = DF:CreateLabel(parent, "Component Type", 9.5, "white")
    component_type_label:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -100)
    
    local component_type_dropdown = DF:CreateDropDown(parent, function() return build_checkable_components_options() end, checkable_components[1])
    component_type_dropdown:SetTemplate(options_dropdown_template)
    component_type_dropdown:SetPoint("LEFT", component_type_label, "RIGHT", 5, 0)

    local component_name_label = DF:CreateLabel(parent, "WeakAura/Addon Name", 9.5, "white")
    component_name_label:SetPoint("LEFT", component_type_dropdown, "RIGHT", 10, 0)

    local component_name_entry = DF:CreateTextEntry(parent, function(_, _, value) component_name = value end, 250, 18)
    component_name_entry:SetTemplate(options_button_template)
    component_name_entry:SetPoint("LEFT", component_name_label, "RIGHT", 5, 0)

    local version_check_button = DF:CreateButton(parent, function()
        print("Version check button clicked") -- replace with actual callback
    end, 120, 18, "Check Versions")
    version_check_button:SetTemplate(options_button_template)
    version_check_button:SetPoint("LEFT", component_name_entry, "RIGHT", 20, 0)

    local character_name_header = DF:CreateLabel(parent, "Character Name", 11)
    character_name_header:SetPoint("TOPLEFT", component_type_label, "BOTTOMLEFT", 10, -20)

    local version_number_header = DF:CreateLabel(parent, "Version Number", 11)
    version_number_header:SetPoint("LEFT", character_name_header, "RIGHT", 120, 0)

    local duplicate_header = DF:CreateLabel(parent, "Duplicate", 11)
    duplicate_header:SetPoint("LEFT", version_number_header, "RIGHT", 50, 0)

    local function refresh(self, data, offset, totalLines)
        for i = 1, totalLines do
            local index = i + offset
            local thisData = data[index]
            if thisData then
                local line = self:GetLine(i)
                local name = thisData.name
                local version = thisData.version
                local duplicate = thisData.duplicate
                local nickname = NSAPI:Shorten(name)
                line.name:SetText(nickname)
                line.version:SetText(version)
                line.duplicates:SetText(duplicate and "Yes" or "No")

                -- version number color
                if version and data[1] and data[1].version and version == data[1].version then
                    line.version:SetTextColor(0, 1, 0, 1)
                else
                    line.version:SetTextColor(1, 0, 0, 1)
                end

                -- duplicates color
                if duplicate then
                    line.duplicates:SetTextColor(1, 0, 0, 1)
                else
                    line.duplicates:SetTextColor(0, 1, 0, 1)
                end
                
                line:SetScript("OnClick", function(self)
                    SendChatMessage("UPDATE YOUR SHIT NOOB", "WHISPER", nil, name)
                end)
            end
        end
    end

    local function createLineFunc(self, index)
        local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
        line:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index-1) * (self.LineHeight+1)) - 1)
        line:SetSize(self:GetWidth() - 2, self.LineHeight)
        DF:ApplyStandardBackdrop(line)
        DF:CreateHighlightTexture(line)
        line.index = index

        local name = line:CreateFontString(nil, "OVERLAY")
        name:SetWidth(100)
        name:SetJustifyH("LEFT")
        name:SetFont(expressway, 12, "OUTLINE")
        name:SetPoint("LEFT", line, "LEFT", 5, 0)
        line.name = name

        local version = line:CreateFontString(nil, "OVERLAY")
        version:SetWidth(100)
        version:SetJustifyH("LEFT")
        version:SetFont(expressway, 12, "OUTLINE")
        version:SetPoint("LEFT", name, "RIGHT", 110, 0)
        line.version = version

        local duplicates = line:CreateFontString(nil, "OVERLAY")
        duplicates:SetWidth(100)
        duplicates:SetJustifyH("LEFT")
        duplicates:SetFont(expressway, 12, "OUTLINE")
        duplicates:SetPoint("LEFT", version, "RIGHT", 30, 0)
        line.duplicates = duplicates

        return line
    end

    local scrollLines = 20
    local version_check_scrollbox = DF:CreateScrollBox(parent, "VersionCheckScrollBox", refresh, {}, window_width - 40,
        window_height - 180, scrollLines, 20, createLineFunc)
    DF:ReskinSlider(version_check_scrollbox)
    version_check_scrollbox.ReajustNumFrames = true
    version_check_scrollbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -150)
    for i = 1, scrollLines do
        version_check_scrollbox:CreateLine(createLineFunc)
    end
    version_check_scrollbox:Refresh()
    local addData = function(self, data)
        local currentData = self:GetData()
        tinsert(currentData, data)
        self:SetData(currentData)
        self:Refresh()
    end

    local wipeData = function(self)
        self:SetData({})
        self:Refresh()
    end

    version_check_scrollbox.AddData = addData
    version_check_scrollbox.WipeData = wipeData

    version_check_button:SetScript("OnClick", function(self)
        version_check_scrollbox:WipeData()
        local userData = NSI:RequestVersionNumber(component_type, component_name)
        if userData then
            version_check_scrollbox:AddData(userData)
        end
    end)

    return version_check_scrollbox
end


function NSUI:Init()
    -- Create the tab container
    local tabContainer = DF:CreateTabContainer(NSUI, "Northern Sky", "NSUI_TabsTemplate", {
        { name = "General",   text = "General" },
        { name = "Nicknames", text = "Nicknames" },
        { name = "Externals", text = "Externals" },
        { name = "Versions",  text = "Versions" }
    }, {
        width = window_width,
        height = window_height - 5,
        backdrop_color = { 0, 0, 0, 0.2 },
        backdrop_border_color = { 0.1, 0.1, 0.1, 0.4 }
    })
    -- Position the tab container within the main frame
    -- tabContainer:SetPoint("TOP", NSUI, "TOP", 0, 0)
    tabContainer:SetPoint("CENTER", NSUI, "CENTER", 0, 0)

    local general_tab = tabContainer:GetTabFrameByName("General")
    local nicknames_tab = tabContainer:GetTabFrameByName("Nicknames")
    local externals_tab = tabContainer:GetTabFrameByName("Externals")
    local versions_tab = tabContainer:GetTabFrameByName("Versions")

    -- externals anchor frame
    local externals_anchor_panel_options = {
        NoCloseButton = true,
        NoTitleBar = true,
        DontRightClickClose = true
    }
    local externals_anchor = CreateFrame("Frame", "ExternalsAnchor", UIParent, "BackdropTemplate")
    NSUI.externals_anchor = externals_anchor
    externals_anchor:SetClampedToScreen(true)
    externals_anchor:SetMovable(true)
    externals_anchor:SetBackdrop({
        bgFile = "interface/editmode/editmodeuihighlightbackground",
        edgeFile = "interface/buttons/white8x8",
        edgeSize = 2,
        tile = true,
        tileSize = 16,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0
        }
    })
    externals_anchor:SetBackdropBorderColor(1, 0, 0, 1)
    NSUI:LoadExternalsAnchorPosition()

    local externals_anchor_text = externals_anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    externals_anchor_text:SetPoint("CENTER", externals_anchor, "CENTER", 0, 0)
    externals_anchor_text:SetText("NS_EXT")
    externals_anchor.text = externals_anchor_text

    externals_anchor:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        elseif button == "RightButton" then
            NSUI:ResetExternalsAnchorPosition()
        end
    end)
    externals_anchor:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        NSUI:SaveExternalsAnchorPosition()
    end)
    externals_anchor:Hide()

    local external_frame = CreateFrame("Frame", "ExternalsFrame", UIParent)
    external_frame:SetPoint("BOTTOMLEFT", NSUI.externals_anchor, "BOTTOMLEFT", 0, 0)
    external_frame:SetPoint("TOPRIGHT", NSUI.externals_anchor, "TOPRIGHT", 0, 0)
    local external_frame_text = external_frame:CreateFontString(nil, "OVERLAY")
    external_frame_text:SetFont([[Interface\AddOns\NorthernSkyRaidTools\Media\Fonts\Expressway.TTF]], 20, "OUTLINE")
    external_frame_text:SetTextColor(1, 1, 1, 1)
    external_frame_text:SetPoint("CENTER", external_frame, "TOP", 0, 10)
    external_frame_text:SetText("NS_EXT")
    external_frame.text = external_frame_text
    local external_frame_texture = external_frame:CreateTexture("ExternalsFrameTexture", "OVERLAY")
    external_frame_texture:SetPoint("TOPLEFT", external_frame, "TOPLEFT", 0, 0)
    external_frame_texture:SetPoint("BOTTOMRIGHT", external_frame, "BOTTOMRIGHT", 0, 0)
    external_frame_texture:SetColorTexture(1, 0, 1, 0.5)
    external_frame.texture = external_frame_texture
    external_frame:Hide()
    NSUI.external_frame = external_frame

    -- dummy default variables until cvars are implemented
    local enableSUFNicknames = false
    -- TTS voice preview
    local tts_text_preview = ""

    -- keybinding logic
    local function getMacroKeybind(macroName)
        local binding = GetBindingKey(macroName)
        if binding then
            return binding
        else
            return "Unbound"
        end
    end

    local function bindKeybind(keyCombo, macroName)
        keyCombo = keyCombo:gsub("LeftButton", "BUTTON1")
            :gsub("RightButton", "BUTTON2")
            :gsub("MiddleButton", "BUTTON3")

        local existingBinding = GetBindingAction(keyCombo)
        print("existingBinding" .. existingBinding)
        if existingBinding and existingBinding ~= macroName then
            SetBinding(keyCombo, nil)
        end
        local ok = SetBinding(keyCombo, macroName)
        if ok then
            print("Keybind " .. macroName .. " set to: " .. keyCombo)
            SaveBindings(GetCurrentBindingSet())
        else
            print("Failed to set keybind.")
        end
    end

    local listening = false

    local function GetModifiedKeyString(key)
        local modifier = ""
        if IsControlKeyDown() then modifier = modifier .. "CTRL-" end
        if IsShiftKeyDown() then modifier = modifier .. "SHIFT-" end
        if IsAltKeyDown() then modifier = modifier .. "ALT-" end

        return modifier .. key
    end

    local registerKeybinding = function(self, macroName, keybindName)
        if not listening then
            print("Press a key (with optional modifiers) to bind...")
            listening = true
        else
            return
        end

        local keybindingFrame = DF:CreateSimplePanel(NSUI, 300, 75, "Keybinding: " .. macroName, "KeybindingFrame", {
            DontRightClickClose = true
        })
        keybindingFrame:SetPoint("CENTER", NSUI, "CENTER", 0, 0)
        keybindingFrame:SetFrameStrata("DIALOG")
        local keybindingFrame_text = keybindingFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        keybindingFrame_text:SetPoint("CENTER", keybindingFrame, "CENTER", 0, 0)
        keybindingFrame_text:SetText([[Press a key or click here
    (with optional modifiers) to bind...]])


        local function OnKeyDown(self, key)
            if listening then
                if key == "ESCAPE" then
                    print("Keybind aborted")
                    listening = false
                    self:SetScript("OnKeyDown", nil)
                    self:SetPropagateKeyboardInput(false)
                    self:Hide()
                    NSUI:Show()
                    return
                end

                key = key:gsub("^LCTRL$", "CTRL")
                    :gsub("^RCTRL$", "CTRL")
                    :gsub("^LSHIFT$", "SHIFT")
                    :gsub("^RSHIFT$", "SHIFT")
                    :gsub("^LALT$", "ALT")
                    :gsub("^RALT$", "ALT")

                if key == "CTRL" or key == "SHIFT" or key == "ALT" then
                    return nil -- Don't register this as a full keybind yet
                end
                local keyCombo = GetModifiedKeyString(key)
                print("Key bound to:", keyCombo)

                -- Bind keybind
                bindKeybind(keyCombo, macroName)

                listening = false
                self:SetScript("OnKeyDown", nil)
                self:SetPropagateKeyboardInput(false)
                self:Hide()
                NSUI:Show()

                if general_tab:GetWidgetById(macroName) ~= nil then
                    general_tab:GetWidgetById(macroName):SetText(keyCombo)
                elseif externals_tab:GetWidgetById(macroName) ~= nil then
                    externals_tab:GetWidgetById(macroName):SetText(keyCombo)
                end
            end
        end

        keybindingFrame:SetScript("OnKeyDown", OnKeyDown)
        keybindingFrame:SetScript("OnMouseDown", OnKeyDown)
        keybindingFrame:SetScript("OnHide", function()
            listening = false
        end)
    end
    -- end of keybinding logic

    -- nickname logic
    local nickname_share_options = { "Raid", "Guild", "Both", "None" }
    local build_nickname_share_options = function()
        local t = {}
        for i = 1, #nickname_share_options do
            tinsert(t, {
                label = nickname_share_options[i],
                value = i,
                onclick = function(_, _, value)
                    NSUI.OptionsChanged.nicknames["NICKNAME_SHARE"] = true
                    NSRT.Settings["Share"] = value
                end

            })
        end
        return t
    end
    local function WipeNickNames()
        local popup = DF:CreateSimplePanel(UIParent, 300, 150, "Confirm Wipe Nicknames", "NSRTWipeNicknamesPopup")
        popup:SetFrameStrata("DIALOG")
        popup:SetPoint("CENTER", UIParent, "CENTER")

        local text = DF:CreateLabel(popup,
            "Are you sure you want to wipe all nicknames?", 12, "orange")
        text:SetPoint("TOP", popup, "TOP", 0, -30)
        text:SetJustifyH("CENTER")

        local confirmButton = DF:CreateButton(popup, function()
            NSI:WipeNickNames()
            popup:Hide()
        end, 100, 30, "Confirm")
        confirmButton:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 5, 10)
        confirmButton:SetTemplate(DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

        local cancelButton = DF:CreateButton(popup, function()
            popup:Hide()
        end, 100, 30, "Cancel")
        cancelButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -5, 10)
        cancelButton:SetTemplate(DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
        popup:Show()
    end
    -- end of nickname logic

    -- WeakAuras imports
    local function ImportWeakAura(name)
        if WA and WA.Import then
            WA.Import(NSI:GetWeakAura(name))
        else
            print("Error:WeakAuras not found")
        end
    end
    -- when any setting is changed, call these respective callback function
    local general_callback = function()
        print("General callback")
        DevTools_Dump(NSUI.OptionsChanged.general)

        if NSUI.OptionsChanged.general["TTS_ENABLED"] then
            print("TTS enabled")
        end

        if NSUI.OptionsChanged.general["TTS_VOICE"] then
            print("TTS voice")
        end

        if NSUI.OptionsChanged.general["PA_MACRO"] then
            PASelfPingChanged()
        end

        if NSUI.OptionsChanged.general["MRT_NOTE_COMPARISON"] then
            print("MRT note comparison")
        end
        wipe(NSUI.OptionsChanged["general"])
        DevTools_Dump(NSUI.OptionsChanged.general)
    end
    local nicknames_callback = function()
        print("Nicknames callback")
        DevTools_Dump(NSUI.OptionsChanged.nicknames)

        if NSUI.OptionsChanged.nicknames["NICKNAME"] then
            print("Nickname")
            NSI:NickNameUpdated(NSRT.Settings["MyNickName"])
        end

        if NSUI.OptionsChanged.nicknames["GLOBAL_NICKNAMES"] then
            print("Global nicknames")
            NSI:GlobalNickNameUpdate()
        end

        if NSUI.OptionsChanged.nicknames["BLIZZARD_NICKNAMES"] then
            print("Blizzard nicknames")
            NSI:BlizzardNickNameUpdated()
        end

        if NSUI.OptionsChanged.nicknames["CELL_NICKNAMES"] then
            print("Cell nicknames")
            NSI:CellNickNameUpdated(true)
        end

        if NSUI.OptionsChanged.nicknames["ELVUI_NICKNAMES"] then
            print("Elvui nicknames")
            NSI:ElvUINickNameUpdated()
        end

        if NSUI.OptionsChanged.nicknames["GRID2_NICKNAMES"] then
            print("Grid2 nicknames")
            NSI:Grid2NickNameUpdated()
        end
        -- no need for WA function

        if NSUI.OptionsChanged.nicknames["UNHALTED_NICKNAMES"] then
            print("Unhalted nicknames")
            NSI:UnhaltedNickNameUpdated()
        end

        wipe(NSUI.OptionsChanged["nicknames"])
    end

    local externals_callback = function()
        print("Externals callback")
        DevTools_Dump(NSUI.OptionsChanged.externals)

        if NSUI.OptionsChanged.externals["EXTERNAL_MACRO"] then
            print("External macro")
            ExternalSelfPingChanged()
        end

        wipe(NSUI.OptionsChanged["externals"])
    end

    local versions_callback = function()
        print("Versions callback")
        wipe(NSUI.OptionsChanged["versions"])
    end

    -- options
    local general_options1_table = {
        { type = "label", get = function() return "General Options" end, text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "toggle",
            boxfirst = true,
            name = "Disable Minimap Button",
            desc = "Hide the minimap button.",
            get = function() return NSRT.Settings["Minimap"].hide end,
            set = function(self, fixedparam, value)
                NSRT.Settings["Minimap"].hide = value

                LDBIcon:Refresh("NSRT", NSRT.Settings["Minimap"])
            end,
        },
        {
            type = "blank",
        },
        { type = "label", get = function() return "TTS Options" end,     text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "range",
            name = "TTS Voice",
            desc = "Voice to use for TTS",
            get = function() return NSRT.Settings["TTSVoice"] end,
            set = function(self, fixedparam, value) 
                NSUI.OptionsChanged.general["TTS_VOICE"] = true
                NSRT.Settings["TTSVoice"] = value 
            end,
            min = 1,
            max = 5,
        },
        {
            type = "range",
            name = "TTS Volume",
            desc = "Volume of the TTS",
            get = function() return NSRT.Settings["TTSVolume"] end,
            set = function(self, fixedparam, value)
                NSRT.Settings["TTSVolume"] = value
            end,
            min = 0,
            max = 100,
        },
        {
            type = "textentry",
            name = "TTS Preview",
            desc = [[Enter any text to preview TTS

Press 'Enter' to hear the TTS]],
            get = function() return tts_text_preview end,
            set = function(self, fixedparam, value)
                tts_text_preview = value
            end,
            hooks = {
                OnEnterPressed = function(self)
                    NSAPI:TTS(tts_text_preview, NSRT.Settings["TTSVoice"])
                end
            }
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable TTS",
            desc = "Enable TTS",
            get = function() return NSRT.Settings["TTS"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.general["TTS_ENABLED"] = true
                NSRT.Settings["TTS"] = value
            end,
        },
        {
            type = "blank"
        },
        {
            type = "label",
            get = function() return "Private Aura Macro" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable @player Ping",
            desc = "Enable a @player ping when the private aura macro is used.",
            get = function() return NSRT.Settings["PASelfPing"] end,
            set = function(self, fixedparam, value) 
                NSUI.OptionsChanged.general["PA_MACRO"] = true
                NSRT.Settings["PASelfPing"] = value 
            end,
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Combine Extra Action Button",
            desc = "Combine the extra action button with the private aura macro.",
            get = function() return NSRT.Settings["PAExtraAction"] end,
            set = function(self, fixedparam, value) 
                NSUI.OptionsChanged.general["PA_MACRO"] = true
                NSRT.Settings["PAExtraAction"] = value 
            end,
            nocombat = true
        },
        {
            type = "label",
            get = function() return "Private Aura Keybind:" end,
        },
        {
            type = "button",
            name = getMacroKeybind("MACRO NS PA Macro"),
            desc = "Set the keybind for the private aura macro",
            param1 = "MACRO NS PA Macro",
            param2 = "Private Aura Keybind", -- whatever reloe names the keybind to be in Bindings.xml
            func = function(self, _, param1, param2)
                registerKeybinding(self, param1, param2)
            end,
            id = "MACRO NS PA Macro",
        },
        {
            type = "blank"
        },
        {
            type = "label",
            get = function() return "MRT Options" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable MRT Note Comparison",
            desc = "Enables MRT note comparison on ready check.",
            get = function() return NSRT.Settings["MRTNoteComparison"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.general["MRT_NOTE_COMPARISON"] = true
                NSRT.Settings["MRTNoteComparison"] = value
            end,
            nocombat = true
        },
        {
            type = "breakline"
        },
        {
            type = "label",
            get = function() return "WeakAuras Imports" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },
        {
            type = "button",
            name = "Import Anchors",
            desc = "Import WeakAura Anchors required for all Northern Sky WeakAuras.",
            func = function(self)
                ImportWeakAura("anchor_weakaura")
            end,
            nocombat = true,
            spacement = true
        },
        {
            type = "button",
            name = "Import External Alert",
            desc = "Import WeakAura External Alert required for the external macro.",
            func = function(self)
                ImportWeakAura("external_weakaura")
            end,
            nocombat = true
        }
    }

    local nicknames_options1_table = {
        {
            type = "button",
            name = "Wipe Nicknames",
            desc = "Wipe all nicknames from the database.",
            func = function(self)
                WipeNickNames()
            end,
            nocombat = true
        },
        {
            type = "blank"
        },
        { type = "label", get = function() return "Nicknames Options" end, text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "textentry",
            name = "Nickname",
            desc = "Set your nickname to be seen by others and used in assignments",
            get = function() return NSRT.Settings["MyNickName"] end,
            set = function(self, fixedparam, value) 
                NSUI.OptionsChanged.nicknames["NICKNAME"] = true
                NSRT.Settings["MyNickName"] = string.sub(value, 1, 12)
            end,
            hooks = {
                OnEditFocusLost = function(self)
                    self:SetText(NSRT.Settings["MyNickName"])
                end,
                OnEnterPressed = function(self) return end
            },
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable Nicknames",
            desc = "Globaly enable nicknames.",
            get = function() return NSRT.Settings["GlobalNickNames"] end,
            set = function(self, fixedparam, value) 
                NSUI.OptionsChanged.nicknames["GLOBAL_NICKNAMES"] = true
                NSRT.Settings["GlobalNickNames"] = value 
            end,
            nocombat = true
        },
        {
            type = "select",
            get = function() return NSRT.Settings["Share"] end,
            values = function() return build_nickname_share_options() end,
            name = "Nickname Share",
            desc = "Choose who you share your nickname with.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable Incoming Nicknames",
            desc = "Toggle the ability to recieve updated nicknames from others.",
            get = function() return NSRT.Settings["IncomingNickNames"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["INCOMING_NICKNAMES"] = true
                NSRT.Settings["IncomingNickNames"] = value
            end,
            nocombat = true
        },
        {
            type = "blank",
        },
        {
            type = "label",
            get = function() return "Unit Frame compatibility" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["Blizzard"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["BLIZZARD_NICKNAMES"] = true
                NSRT.Settings["Blizzard"] = value
            end,
            name = "Enable Blizzard Nicknames",
            desc = "Enable Nicknames to be used with Blizzard unit frames.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["Cell"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["CELL_NICKNAMES"] = true
                NSRT.Settings["Cell"] = value
            end,
            name = "Enable Cell Nicknames",
            desc = "Enable Nicknames to be used with Cell unit frames.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["Grid2"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["GRID2_NICKNAMES"] = true
                NSRT.Settings["Grid2"] = value
            end,
            name = "Enable Grid2 Nicknames",
            desc = "Enable Nicknames to be used with Grid2 unit frames.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["ElvUI"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["ELVUI_NICKNAMES"] = true
                NSRT.Settings["ElvUI"] = value
            end,
            name = "Enable ElvUI Nicknames",
            desc = "Enable Nicknames to be used with ElvUI unit frames.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["SuF"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["SUF_NICKNAMES"] = true
                NSRT.Settings["SuF"] = value
            end,
            name = "Enable SUF Nicknames",
            desc = "Enable Nicknames to be used with SUF unit frames.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["WA"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["WA_NICKNAMES"] = true
                NSRT.Settings["WA"] = value
            end,
            name = "Enable WeakAuras Nicknames",
            desc = "Enable Nicknames to be used with WeakAuras.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["MRT"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["MRT_NICKNAMES"] = true
                NSRT.Settings["MRT"] = value
            end,
            name = "Enable MRT Nicknames",
            desc = "Enable Nicknames to be used with MRT.",
            nocombat = true
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return NSRT.Settings["Unhalted"] end,
            set = function(self, fixedparam, value)
                NSUI.OptionsChanged.nicknames["UNHALTED_NICKNAMES"] = true
                NSRT.Settings["Unhalted"] = value
            end,
            name = "Enable Unhalted UI Nicknames",
            desc = "Enable Nicknames to be used with Unhalted UI.",
            nocombat = true
        },
    }

    local externals_options1_table = {
        {
            type = "button",
            name = "Test External",
            desc = "Simulate recieving an external.",
            func = function(self)
                NSI:DisplayExternal(237554, GetUnitName("player"))
            end,
            nocombat = true
        },
        {
            type = "blank",
        },
        {
            type = "button",
            name = "Toggle External Anchor",
            desc = "Toggle the external anchor frame.",
            func = function(self)
                if NSUI.externals_anchor:IsShown() then
                    NSUI.externals_anchor:Hide()
                else
                    NSUI.externals_anchor:Show()
                end
            end,
            nocombat = true
        },
        {
            type = "blank",
        },
        { type = "label", get = function() return "Externals Options" end, text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable @player Ping",
            desc = "Enable a @player ping when the external macro is used.",
            get = function() return NSRT.Settings["ExternalSelfPing"] end,
            set = function(self, fixedparam, value) 
                NSUI.OptionsChanged.externals["EXTERNAL_MACRO"] = true
                NSRT.Settings["ExternalSelfPing"] = value 
            end,
            nocombat = true
        },
        {
            type = "label",
            get = function() return "External Macro Keybind:" end,
        },
        {
            type = "button",
            name = getMacroKeybind("MACRO NS Ext Macro"),
            desc = "Set the keybind for the external macro",
            param1 = "MACRO NS Ext Macro",
            param2 = "External Macro Keybind",
            func = function(self, _, param1, param2)
                registerKeybinding(self, param1, param2)
            end,
            id = "MACRO NS Ext Macro",
        }
    }

    -- Build options menu for each tab
    DF:BuildMenu(general_tab, general_options1_table, 10, -100, window_height - 10, false, options_text_template,
        options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template,
        general_callback)
    DF:BuildMenu(nicknames_tab, nicknames_options1_table, 10, -100, window_height - 10, false, options_text_template,
        options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template,
        nicknames_callback)
    DF:BuildMenu(externals_tab, externals_options1_table, 10, -100, window_height - 10, false, options_text_template,
        options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template,
        externals_callback)

    NSUI.version_scrollbox = BuildVersionCheckUI(versions_tab)
end

function NSI:DisplayExternal(spellId, unit)
    local text = ""
    if spellId then
        local spellIcon = C_Spell.GetSpellInfo(spellId).iconID
        NSUI.external_frame.texture:SetTexture(spellIcon)
        local giver = NSAPI:Shorten(unit, 8)
        text = "From: " .. giver
    else
        NSUI.external_frame.texture:SetTexture(237555)
        text = "|cffff0000NO EXTERNAL|r"
    end

    NSUI.external_frame.text:SetText(text)
    NSUI.external_frame:Show()

    C_Timer.After(4, function()
        NSUI.external_frame:Hide()
    end)
end

function NSUI:LoadExternalsAnchorPosition()
    NSRT.NSUI.externals_anchor.settings = NSRT.NSUI.externals_anchor.settings or {
        anchorPoint = {
            "CENTER", UIParent, "CENTER", 0, 150
        },
        width = 70,
        height = 70
    }
    if not NSRT.NSUI.externals_anchor.settings.anchorPoint or not NSRT.NSUI.externals_anchor.settings.width or not NSRT.NSUI.externals_anchor.settings.height then
        print("No externals anchor settings found.... THIS SHOULD NOT HAPPEN")
        return
    end
    NSUI.externals_anchor:SetPoint(unpack(NSRT.NSUI.externals_anchor.settings.anchorPoint))
    NSUI.externals_anchor:SetSize(NSRT.NSUI.externals_anchor.settings.width, NSRT.NSUI.externals_anchor.settings.height)
end

function NSUI:SaveExternalsAnchorPosition()
    local anchorPoint = { NSUI.externals_anchor:GetPoint() }
    anchorPoint[2] = "UIParent"

    local width, height = NSUI.externals_anchor:GetSize()
    NSRT.NSUI.externals_anchor.settings = {
        anchorPoint = anchorPoint,
        width = width,
        height = height
    }
    print("Saving externals anchor position")
    DevTools_Dump(NSRT.NSUI.externals_anchor.settings)
end

function NSUI:ResetExternalsAnchorPosition()
    NSUI.externals_anchor:ClearAllPoints()
    NSUI.externals_anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    NSUI.externals_anchor:SetSize(70, 70)
    NSRT.NSUI.externals_anchor.settings.anchorPoint = { "CENTER", UIParent, "CENTER", 0, 150 }
end
function NSUI:ToggleOptions()
    if NSUI:IsShown() then
        NSUI:Hide()
    else
        NSUI:Show()
    end
end
NSI.NSUI = NSUI

SLASH_NSUI1 = "/ns"
SlashCmdList["NSUI"] = function(msg)
    if msg == "anchor" then
        if NSUI.externals_anchor:IsShown() then
            NSUI.externals_anchor:Hide()
        else
            NSUI.externals_anchor:Show()
        end
    elseif msg == "test" then
        NSI:DisplayExternal(nil, GetUnitName("player"))
    else
        NSUI:ToggleOptions()
    end
end
