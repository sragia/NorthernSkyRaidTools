local DF = _G["DetailsFramework"]

local window_width = 800
local window_height = 515

local options_text_template = DF:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
local options_dropdown_template = DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
local options_switch_template = DF:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
local options_slider_template = DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
local options_button_template = DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

local NSUI_panel_options = {
    UseStatusBar = true
}
local NSUI = DF:CreateSimplePanel(UIParent, window_width, window_height, "|cFF00FFFFNorthern Sky|r Utilities", "NSUI",
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
local function PASelfPingChanged(enabled)
    NSRT.PASelfPing = enabled
    for i = 1, 120 do
        local macroname = C_Macro.GetMacroName(i)
        if not macroname then break end
        if macroname == "NS PA Macro" then
            NSRT.PAMacro = i
            local macrotext = enabled and "/run WeakAuras.ScanEvents(\"NS_PA_MACRO\", true);\n/ping [@player] Warning;" or
                "/run WeakAuras.ScanEvents(\"NS_PA_MACRO\", true);"
            EditMacro(i, "NS PA Macro", 132288, macrotext, false)
            pafound = true
            break
        end
    end
    if not NSRT.PAMacro then
        local macrotext = NSRT.PASelfPing and
            "/run WeakAuras.ScanEvents(\"NS_PA_MACRO\", true);\n/ping [@player] Warning;" or
            "/run WeakAuras.ScanEvents(\"NS_PA_MACRO\", true);"
        NSRT.PAMacro = CreateMacro("NS PA Macro", 132288, macrotext, false)
    end
end

-- need to run this code on settings change
local function ExternalSelfPingChanged(enabled)
    NSRT.ExternalSelfPing = enabled
    for i = 1, 120 do
        local macroname = C_Macro.GetMacroName(i)
        if not macroname then break end
        if macroname == "NS Ext Macro" then
            NSRT.ExternalMacro = i
            local macrotext = NSRT.ExternalSelfPing and "/run NSExternals:Request();\n/ping [@player] Assist;" or
                "/run NSExternals:Request();"
            EditMacro(i, "NS Ext Macro", 135966, macrotext, false)
            extfound = true
            break
        end
    end
    if not NSRT.ExternalMacro then
        local macrotext = NSRT.ExternalSelfPing and "/run NSExternals:Request();\n/ping [@player] Assist;" or
            "/run NSExternals:Request();"
        NSRT.ExternalMacro = CreateMacro("NS Ext Macro", 135966, macrotext, false)
    end
end

-- nickname change callbacks
local function NickNameUpdated(nickname)
    local name, realm = UnitFullName("player")
    if not realm then
        realm = GetNormalizedRealmName()
    end
    local oldnick = NSRT.NickNames[name .. "-" .. realm]
    if (not oldnick) or oldnick ~= nickname then
        NSRT.MyNickName = nickname
        NSAPI:SendNickName("GUILD")
        NSAPI:SendNickName("RAID")
        NSAPI:NewNickName("player", nickname, name, realm)
    end
end

function NSUI:Init()
    -- when any setting is changed, call these respective callback function
    local general_callback = function()
        print("General callback")

        PASelfPingChanged(NSRT.PASelfPing)

        wipe(NSUI.OptionsChanged["general"])
    end
    local nicknames_callback = function()
        print("Nicknames callback")

        NickNameUpdated(NSRT.MyNickName)
        wipe(NSUI.OptionsChanged["nicknames"])
    end

    local externals_callback = function()
        print("Externals callback")
        ExternalSelfPingChanged(NSRT.ExternalSelfPing)
        wipe(NSUI.OptionsChanged["externals"])
    end

    local versions_callback = function()
        print("Versions callback")
        wipe(NSUI.OptionsChanged["versions"])
    end

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
    local externals_anchor = DF:CreateSimplePanel(UIParent, 64, 64, "", "ExternalsAnchor", externals_anchor_panel_options)
    externals_anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    externals_anchor:SetClampedToScreen(true)
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
    local externals_text = externals_anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    externals_text:SetPoint("CENTER", externals_anchor, "CENTER", 0, 0)
    externals_text:SetText("NS_EXT")


    -- dummy default variables until cvars are implemented
    local enableTTS = false
    local ttsVoice = 2
    local nickname = ""
    local enableNicknames = false
    local enableCellNicknames = false
    local enableGrid2Nicknames = false
    local enableElvUINicknames = false
    local enableSUFNicknames = false
    local enablePlayerPingForPAMacro = false
    local enablePlayerPingForExternalMacro = false
    -- end of dummy variables

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

    local general_options1_table = {
        { type = "label", get = function() return "General Options" end, text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "range",
            name = "TTS Voice",
            desc = "Voice to use for TTS",
            get = function() return NSRT.TTSVoice end,
            set = function(self, fixedparam, value) NSRT.TTSVoice = value end,
            min = 1,
            max = 5,
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable TTS",
            desc = "Enable TTS",
            get = function() return NSRT.TTS end,
            set = function(self, fixedparam, value)
                NSRT.TTS = value
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
            get = function() return NSRT.PASelfPing end,
            set = function(self, fixedparam, value) NSRT.PASelfPing = value end,
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Combine Extra Action Button",
            desc = "Combine the extra action button with the private aura macro.",
            get = function() return NSRT.PAExtraAction end,
            set = function(self, fixedparam, value) NSRT.PAExtraAction = value end,
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

    }

    local nicknames_options1_table = {
        { type = "label", get = function() return "Nicknames Options" end, text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "textentry",
            name = "Nickname",
            desc = "Set your nickname to be seen by others and used in assignments",
            get = function() return NSRT.MyNickName end,
            set = function(self, fixedparam, value) NSRT.MyNickName = value end,
        },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable Nicknames",
            desc = "Globaly enable nicknames.",
            get = function() return NSRT.GlobalNickNames end,
            set = function(self, fixedparam, value) NSRT.GlobalNickNames = value end,
        },
        {
            type = "blank"
        },
        {
            type = "label",
            get = function() return "Unit Frame compatibility" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return enableCellNicknames end,
            set = function(self, fixedparam, value)
                enableCellNicknames = value
            end,
            name = "Enable Cell Nicknames",
            desc = "Enable Nicknames to be used with Cell unit frames.",
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return enableGrid2Nicknames end,
            set = function(self, fixedparam, value)
                enableGrid2Nicknames = value
            end,
            name = "Enable Grid2 Nicknames",
            desc = "Enable Nicknames to be used with Grid2 unit frames.",
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return enableElvUINicknames end,
            set = function(self, fixedparam, value)
                enableElvUINicknames = value
            end,
            name = "Enable ElvUI Nicknames",
            desc = "Enable Nicknames to be used with ElvUI unit frames.",
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return enableSUFNicknames end,
            set = function(self, fixedparam, value)
                enableSUFNicknames = value
            end,
            name = "Enable SUF Nicknames",
            desc = "Enable Nicknames to be used with SUF unit frames.",
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return enableSUFNicknames end,
            set = function(self, fixedparam, value)
                enableSUFNicknames = value
            end,
            name = "Enable WeakAuras Nicknames",
            desc = "Enable Nicknames to be used with WeakAuras.",
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return enableSUFNicknames end,
            set = function(self, fixedparam, value)
                enableSUFNicknames = value
            end,
            name = "Enable MRT Nicknames",
            desc = "Enable Nicknames to be used with MRT.",
        },
        {
            type = "toggle",
            boxfirst = true,
            get = function() return enableSUFNicknames end,
            set = function(self, fixedparam, value)
                enableSUFNicknames = value
            end,
            name = "Enable Unhalted UI Nicknames",
            desc = "Enable Nicknames to be used with Unhalted UI.",
        },
    }

    local externals_options1_table = {
        { type = "label", get = function() return "Externals Options" end, text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable @player Ping",
            desc = "Enable a @player ping when the external macro is used.",
            get = function() return NSRT.ExternalSelfPing end,
            set = function(self, fixedparam, value) NSRT.ExternalSelfPing = value end,
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
end

NSAPI.NSUI = NSUI

SLASH_NSUITEST1 = "/ns"
SlashCmdList["NSUITEST"] = function(msg)
    if msg == "anchor" then
        if externals_anchor:IsShown() then
            externals_anchor:Hide()
        else
            externals_anchor:Show()
        end
    else
        if NSUI:IsShown() then
            NSUI:Hide()
        else
            NSUI:Show()
        end
    end
end
