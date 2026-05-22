-- Imports
local core_mainmenu = require("core_mainmenu")
local cfg = require("XpBar.configuration")
-- TODO move to options
local optionsLoaded, options = pcall(require, "XpBar.options")

local optionsFileName = "addons/XpBar/options.lua"

-- Constants
local _PlayerArray = 0x00A94254
local _PlayerMyIndex = 0x00A9C4F4
local _PLTPointer = 0x00A94878

-- Helpers in solylib
local function _getMenuState()
    local offsets = {
        0x00A98478,
        0x00000010,
        0x0000001E,
    }
    local address = 0
    local value = -1
    for _, v in ipairs(offsets) do
        if address ~= -1 then
            address = pso.read_u32(address + v)
            if address == 0 then
                address = -1
            end
        end
    end
    if address ~= -1 then
        value = bit.band(address, 0xFFFF)
    end
    return value
end
local function IsMenuOpen()
    local menuOpen = 0x43
    local menuState = _getMenuState()
    return menuState == menuOpen
end
local function IsSymbolChatOpen()
    local wordSelectOpen = 0x40
    local menuState = _getMenuState()
    return menuState == wordSelectOpen
end
local function IsMenuUnavailable()
    local menuState = _getMenuState()
    return menuState == -1
end
-- End of helpers in solylib

-- Global variable to store stats for text window
local StatsWindow = {
    currentLevel = 0,
    currentExp = 0,
    expToNextLevel = 0,
    xpPerSecond = 0,
    etaSeconds = -1,
}

-- Sliding-window XP rate tracker (per-second precision)
local XpTracker = {
    samples = {},
    windowSeconds = 60,
}

local function UpdateXpTracker(currentExp)
    local now = os.time()
    local samples = XpTracker.samples

    -- Character switch (exp went backwards): drop history
    if #samples > 0 and currentExp < samples[#samples].exp then
        XpTracker.samples = {}
        samples = XpTracker.samples
    end

    if #samples > 0 and samples[#samples].time == now then
        samples[#samples].exp = currentExp
    else
        samples[#samples + 1] = { time = now, exp = currentExp }
    end

    local cutoff = now - XpTracker.windowSeconds
    while #samples > 1 and samples[1].time < cutoff do
        table.remove(samples, 1)
    end
end

local function GetXpPerSecond()
    local samples = XpTracker.samples
    if #samples < 2 then
        return 0
    end
    local oldest = samples[1]
    local newest = samples[#samples]
    local dt = newest.time - oldest.time
    if dt <= 0 then
        return 0
    end
    return (newest.exp - oldest.exp) / dt
end

local function FormatComma(n)
    local s = string.format("%d", math.floor(n))
    local sign = ""
    if s:sub(1, 1) == "-" then
        sign = "-"
        s = s:sub(2)
    end
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    s = s:gsub("^,", "")
    return sign .. s
end

local function FormatDuration(seconds)
    seconds = math.floor(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    elseif seconds < 86400 then
        return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
    else
        return string.format("%dd %dh", math.floor(seconds / 86400), math.floor((seconds % 86400) / 3600))
    end
end

local DEFAULTS = {
    configurationEnableWindow = true,
    enable = true,

    xpEnableWindow = true,
    xpHideWhenMenu = true,
    xpHideWhenSymbolChat = true,
    xpHideWhenMenuUnavailable = true,
    xpShowDefaultNotError = false,
    xpNoTitleBar = "",
    xpNoResize = "",
    xpNoMove = "",
    xpTransparent = false,
    xpEnableInfoLevel = true,
    xpEnableInfoTotal = true,
    xpEnableInfoTNL = true,
    xpEnableInfoRate = false,
    xpEnableInfoETA = false,
    xpRatePerHour = false,
    xpBarNoOverlay = false,
    xpBarColor = 0xFFE6B300,
    xpBarPercentColor = 0xFFFFFFFF,
    xpBarX = 50,
    xpBarY = 50,
    xpBarWidth = -1,
    xpBarHeight = 0,
    xpVerticalBar = false,

    textwindow_enable = false,
    textwindow_splitWindows = false,
    textwindow_hideWhenMenuOpen = true,
    textwindow_hideWhenSymbolChatOpen = true,
    textwindow_hideWhenMenuNotAvailable = true,
    textwindow_noTitleBar = "",
    textwindow_noResize = "",
    textwindow_noMove = "",
    textwindow_transparent = false,
    textwindow_x = 200,
    textwindow_y = 50,
    textwindow_percentColor = 0xFFFFFFFF,

    stat_level_x = 200, stat_level_y = 50,
    stat_total_x = 200, stat_total_y = 70,
    stat_tnl_x   = 200, stat_tnl_y   = 90,
    stat_rate_x  = 200, stat_rate_y  = 110,
    stat_eta_x   = 200, stat_eta_y   = 130,
}

if not optionsLoaded then
    options = {}
end
for k, v in pairs(DEFAULTS) do
    if options[k] == nil then
        options[k] = v
    end
end

local SAVE_FIELDS = {
    { "configurationEnableWindow",            "bool"  },
    { "enable",                               "bool"  },
    { nil,                                    "blank" },
    { "xpEnableWindow",                       "bool"  },
    { "xpHideWhenMenu",                       "bool"  },
    { "xpHideWhenSymbolChat",                 "bool"  },
    { "xpHideWhenMenuUnavailable",            "bool"  },
    { "xpShowDefaultNotError",                "bool"  },
    { "xpNoTitleBar",                         "str"   },
    { "xpNoResize",                           "str"   },
    { "xpNoMove",                             "str"   },
    { "xpTransparent",                        "bool"  },
    { "xpEnableInfoLevel",                    "bool"  },
    { "xpEnableInfoTotal",                    "bool"  },
    { "xpEnableInfoTNL",                      "bool"  },
    { "xpEnableInfoRate",                     "bool"  },
    { "xpEnableInfoETA",                      "bool"  },
    { "xpRatePerHour",                        "bool"  },
    { "xpBarNoOverlay",                       "bool"  },
    { "xpBarColor",                           "color" },
    { "xpBarPercentColor",                    "color" },
    { "xpBarX",                               "num"   },
    { "xpBarY",                               "num"   },
    { "xpBarWidth",                           "num"   },
    { "xpBarHeight",                          "num"   },
    { "xpVerticalBar",                        "bool"  },
    { "textwindow_enable",                    "bool"  },
    { "textwindow_splitWindows",              "bool"  },
    { "textwindow_hideWhenMenuOpen",          "bool"  },
    { "textwindow_hideWhenSymbolChatOpen",    "bool"  },
    { "textwindow_hideWhenMenuNotAvailable",  "bool"  },
    { "textwindow_noTitleBar",                "str"   },
    { "textwindow_noResize",                  "str"   },
    { "textwindow_noMove",                    "str"   },
    { "textwindow_transparent",               "bool"  },
    { "textwindow_x",                         "num"   },
    { "textwindow_y",                         "num"   },
    { "textwindow_percentColor",              "color" },
    { "stat_level_x",                         "num"   },
    { "stat_level_y",                         "num"   },
    { "stat_total_x",                         "num"   },
    { "stat_total_y",                         "num"   },
    { "stat_tnl_x",                           "num"   },
    { "stat_tnl_y",                           "num"   },
    { "stat_rate_x",                          "num"   },
    { "stat_rate_y",                          "num"   },
    { "stat_eta_x",                           "num"   },
    { "stat_eta_y",                           "num"   },
}

local function SaveOptions(options)
    local file = io.open(optionsFileName, "w")
    if file == nil then
        return
    end

    file:write("return {\n")
    for _, field in ipairs(SAVE_FIELDS) do
        local name, kind = field[1], field[2]
        if kind == "blank" then
            file:write("\n")
        elseif kind == "bool" then
            file:write(string.format("%s = %s,\n", name, tostring(options[name])))
        elseif kind == "str" then
            file:write(string.format("%s = %q,\n", name, options[name]))
        elseif kind == "color" then
            file:write(string.format("%s = 0x%08X,\n", name, options[name]))
        elseif kind == "num" then
            file:write(string.format("%s = %f,\n", name, options[name]))
        end
    end
    file:write("}\n")
    file:close()
end

local function GetColorAsFloats(color)
    color = color or 0xFFFFFFFF

    local a = bit.band(bit.rshift(color, 24), 0xFF) / 255;
    local r = bit.band(bit.rshift(color, 16), 0xFF) / 255;
    local g = bit.band(bit.rshift(color, 8), 0xFF) / 255;
    local b = bit.band(color, 0xFF) / 255;

    return { r = r, g = g, b = b, a = a }
end

local imguiProgressBar = function(progress, color, percentColor)
    color = color or 0xFFE6B300
    percentColor = percentColor or 0xFFFFFFFF

    if progress == nil then
        imgui.Text("imguiProgressBar() Invalid progress")
        return
    end

    local overlay = nil
    if options.xpBarNoOverlay then
        overlay = ""
    end

    local c = GetColorAsFloats(color)

    if options.xpVerticalBar then
        local barWidth = options.xpBarWidth > 0 and options.xpBarWidth or 20
        local barHeight = options.xpBarHeight > 0 and options.xpBarHeight or 100

        local filledHeight = barHeight * progress
        local emptyHeight = barHeight - filledHeight

        imgui.BeginChild("VertBar", barWidth, barHeight, false)

        imgui.PushStyleColor("PlotHistogram", c.r, c.g, c.b, c.a)
        imgui.PushStyleVar_2("ItemSpacing", 0, 0)
        imgui.PushStyleVar_2("FramePadding", 0, 0)

        if emptyHeight >= 1 then
            imgui.SetCursorPos(0, 0)
            imgui.ProgressBar(0, barWidth, emptyHeight, "")
        end
        if filledHeight >= 1 then
            imgui.SetCursorPos(0, emptyHeight)
            imgui.ProgressBar(1, barWidth, filledHeight, "")
        end

        imgui.PopStyleVar(2)
        imgui.PopStyleColor()

        if not options.xpBarNoOverlay then
            local percentText = string.format("%d%%", math.floor(progress * 100))
            local pc = GetColorAsFloats(percentColor)
            imgui.PushStyleColor("Text", pc.r, pc.g, pc.b, pc.a)

            local charHeight = 14
            local totalTextHeight = #percentText * charHeight
            local startY = (barHeight - totalTextHeight) / 2

            for i = 1, #percentText do
                local char = string.sub(percentText, i, i)
                local charWidth = imgui.CalcTextSize(char)
                local xPos = (barWidth - charWidth) / 2
                local yPos = startY + ((i - 1) * charHeight)
                imgui.SetCursorPos(xPos, yPos)
                imgui.Text(char)
            end

            imgui.PopStyleColor()
        end

        imgui.EndChild()
    else
        -- Original horizontal progress bar
        imgui.PushStyleColor("PlotHistogram", c.r, c.g, c.b, c.a)
        
        -- Apply custom percentage text color if we're showing percentage
        if not options.xpBarNoOverlay and overlay == nil then
            local pc = GetColorAsFloats(percentColor)
            imgui.PushStyleColor("Text", pc.r, pc.g, pc.b, pc.a)
            imgui.ProgressBar(progress, options.xpBarWidth, options.xpBarHeight, overlay)
            imgui.PopStyleColor() -- Pop text color
        else
            imgui.ProgressBar(progress, options.xpBarWidth, options.xpBarHeight, overlay)
        end
        
        imgui.PopStyleColor() -- Pop progress bar color
    end
end

local STAT_VALUE_COLUMN = 60

local function StatRow(label, value)
    imgui.Text(label)
    imgui.SameLine(STAT_VALUE_COLUMN)
    imgui.Text(value)
end

-- Function to render stats text (used by both main window and separate text window)
local function RenderStatsText(currentLevel, currentExp, expToNextLevel, xpPerSecond, etaSeconds)
    if options.xpEnableInfoLevel then
        StatRow("Lv", string.format("%i", currentLevel + 1))
    end

    if options.xpEnableInfoTotal then
        StatRow("Total", FormatComma(currentExp))
    end

    if options.xpEnableInfoTNL then
        StatRow("TNL", FormatComma(expToNextLevel))
    end

    if options.xpEnableInfoRate then
        local label, multiplier
        if options.xpRatePerHour then
            label, multiplier = "XP/hr", 3600
        else
            label, multiplier = "XP/min", 60
        end
        StatRow(label, FormatComma((xpPerSecond or 0) * multiplier))
    end

    if options.xpEnableInfoETA then
        if etaSeconds and etaSeconds > 0 then
            StatRow("ETA", FormatDuration(etaSeconds))
        else
            StatRow("ETA", "--")
        end
    end
end

-- Validate and render the bar given the pre-determined values
local renderBarAndText = function(currentLevel, currentExp, expToNextLevel, progressAsFraction, xpPerSecond, etaSeconds)
    if options.xpVerticalBar then
        -- For vertical layout, put the bar on the left and text on the right
        imguiProgressBar(progressAsFraction, options.xpBarColor, options.xpBarPercentColor)

        -- Only show text in main window if not using separate text window
        if not options.textwindow_enable then
            imgui.SameLine()

            imgui.BeginGroup()
            RenderStatsText(currentLevel, currentExp, expToNextLevel, xpPerSecond, etaSeconds)
            imgui.EndGroup()
        end
    else
        -- Original horizontal layout
        imguiProgressBar(progressAsFraction, options.xpBarColor, options.xpBarPercentColor)

        -- Only show text in main window if not using separate text window
        if not options.textwindow_enable then
            RenderStatsText(currentLevel, currentExp, expToNextLevel, xpPerSecond, etaSeconds)
        end
    end
end

local renderError = function(errorMsg)
    if (options.xpShowDefaultNotError == false) then
        imgui.Text(errorMsg)
    else
        renderBarAndText(0, 0, 50, 0, 0, -1)
    end
end

local DrawStuff = function()
    local currentPlayerIndex = pso.read_u32(_PlayerMyIndex)
    local characterMemAddress = pso.read_u32(_PlayerArray + 4 * currentPlayerIndex)
    local pltData = pso.read_u32(_PLTPointer)

    -- Check the player has selected a character
    if characterMemAddress == 0 then
        renderError("Player data not found")
        return
    end

    -- Check that our player data is available
    if pltData == 0 then
        renderError("PLT data not found")
        return
    end

    local myClass = pso.read_u8(characterMemAddress + 0x961)
    local charCurrentLevel = pso.read_u32(characterMemAddress + 0xE44)
    local charTotalExp = pso.read_u32(characterMemAddress + 0xE48)

    local pltLevels = pso.read_u32(pltData)
    local pltClass = pso.read_u32(pltLevels + 4 * myClass)

    local thisMaxLevelExp = pso.read_u32(pltClass + 0x0C * charCurrentLevel + 0x08)
    local nextMaxLevelexp

    if charCurrentLevel < 199 then
        nextMaxLevelexp = pso.read_u32(pltClass + 0x0C * (charCurrentLevel + 1) + 0x08)
    else
        nextMaxLevelexp = thisMaxLevelExp
    end

    local thisLevelExp = charTotalExp - thisMaxLevelExp
    local nextLevelexp = nextMaxLevelexp - thisMaxLevelExp
    -- In case a server patches max exp displayed in the menu to be uncapped,
    -- ensure the progress bar shows 100%.
    local expToNextLevel = math.max(0, nextMaxLevelexp - charTotalExp)
    local progressAsFraction = 1
    if nextLevelexp ~= 0 then
        progressAsFraction = thisLevelExp / nextLevelexp
    end

    UpdateXpTracker(charTotalExp)
    local xpPerSecond = GetXpPerSecond()
    local etaSeconds = -1
    if xpPerSecond > 0 and expToNextLevel > 0 then
        etaSeconds = expToNextLevel / xpPerSecond
    end

    -- Store the stats for the separate text window
    StatsWindow.currentLevel = charCurrentLevel
    StatsWindow.currentExp = charTotalExp
    StatsWindow.expToNextLevel = expToNextLevel
    StatsWindow.xpPerSecond = xpPerSecond
    StatsWindow.etaSeconds = etaSeconds

    renderBarAndText(charCurrentLevel, charTotalExp, expToNextLevel, progressAsFraction, xpPerSecond, etaSeconds)
end

-- Drawing
local function present()
    local changedOptions = false
    -- If the addon has never been used, open the config window
    -- and disable the config window setting
    if options.configurationEnableWindow then
        ConfigurationWindow.open = true
        options.configurationEnableWindow = false
        SaveOptions(options)
    end

    ConfigurationWindow.Update()
    if ConfigurationWindow.changed then
        changedOptions = true
        ConfigurationWindow.changed = false
        SaveOptions(options)
    end

    -- Global enable here to let the configuration window work
    if options.enable == false then
        return
    end

    -- Create the separate text window(s) if enabled
    if options.textwindow_enable
        and (options.textwindow_hideWhenMenuOpen == false or IsMenuOpen() == false)
        and (options.textwindow_hideWhenSymbolChatOpen == false or IsSymbolChatOpen() == false)
        and (options.textwindow_hideWhenMenuNotAvailable == false or IsMenuUnavailable() == false)
    then
        local tc = GetColorAsFloats(options.textwindow_percentColor)
        local winFlags = { options.textwindow_noTitleBar, options.textwindow_noResize, options.textwindow_noMove, "AlwaysAutoResize" }

        if options.textwindow_splitWindows then
            local rateLabel, rateMultiplier
            if options.xpRatePerHour then
                rateLabel, rateMultiplier = "XP/hr", 3600
            else
                rateLabel, rateMultiplier = "XP/min", 60
            end

            local etaValue
            if StatsWindow.etaSeconds and StatsWindow.etaSeconds > 0 then
                etaValue = FormatDuration(StatsWindow.etaSeconds)
            else
                etaValue = "--"
            end

            local rows = {
                { show = options.xpEnableInfoLevel, title = "Level##xpbar",            x = options.stat_level_x, y = options.stat_level_y, label = "Lv",      value = string.format("%i", StatsWindow.currentLevel + 1) },
                { show = options.xpEnableInfoTotal, title = "Total##xpbar",            x = options.stat_total_x, y = options.stat_total_y, label = "Total",   value = FormatComma(StatsWindow.currentExp) },
                { show = options.xpEnableInfoTNL,   title = "TNL##xpbar",              x = options.stat_tnl_x,   y = options.stat_tnl_y,   label = "TNL",     value = FormatComma(StatsWindow.expToNextLevel) },
                { show = options.xpEnableInfoRate,  title = rateLabel .. "##xpbar",    x = options.stat_rate_x,  y = options.stat_rate_y,  label = rateLabel, value = FormatComma((StatsWindow.xpPerSecond or 0) * rateMultiplier) },
                { show = options.xpEnableInfoETA,   title = "ETA##xpbar",              x = options.stat_eta_x,   y = options.stat_eta_y,   label = "ETA",     value = etaValue },
            }

            for _, row in ipairs(rows) do
                if row.show then
                    if options.textwindow_transparent then
                        imgui.PushStyleColor("WindowBg", 0, 0, 0, 0)
                    end
                    if changedOptions == true then
                        imgui.SetNextWindowPos(row.x, row.y, "Always")
                    end
                    imgui.Begin(row.title, nil, winFlags)
                    imgui.PushStyleColor("Text", tc.r, tc.g, tc.b, tc.a)
                    StatRow(row.label, row.value)
                    imgui.PopStyleColor()
                    imgui.End()
                    if options.textwindow_transparent then
                        imgui.PopStyleColor(1)
                    end
                end
            end
        else
            if options.textwindow_transparent then
                imgui.PushStyleColor("WindowBg", 0, 0, 0, 0)
            end

            if changedOptions == true then
                imgui.SetNextWindowPos(options.textwindow_x, options.textwindow_y, "Always");
            end

            imgui.Begin("XP Stats", nil, winFlags)
            imgui.PushStyleColor("Text", tc.r, tc.g, tc.b, tc.a)
            RenderStatsText(StatsWindow.currentLevel, StatsWindow.currentExp, StatsWindow.expToNextLevel, StatsWindow.xpPerSecond, StatsWindow.etaSeconds)
            imgui.PopStyleColor()
            imgui.End()

            if options.textwindow_transparent then
                imgui.PopStyleColor(1)
            end
        end
    end

    -- Main progress bar window
    if options.xpEnableWindow
        and (options.xpHideWhenMenu == false or IsMenuOpen() == false)
        and (options.xpHideWhenSymbolChat == false or IsSymbolChatOpen() == false)
        and (options.xpHideWhenMenuUnavailable == false or IsMenuUnavailable() == false)
    then
        if options.xpTransparent then
            imgui.PushStyleColor("WindowBg", 0, 0, 0, 0)
        end

        if changedOptions == true then
            changedOptions = false
            imgui.SetNextWindowPos(options.xpBarX, options.xpBarY, "Always");
        end

        imgui.Begin("Experience Bar", nil, { options.xpNoTitleBar, options.xpNoResize, options.xpNoMove, "AlwaysAutoResize" })
        DrawStuff();
        imgui.End()

        if options.xpTransparent then
            imgui.PopStyleColor(1)
        end
    end
end

-- Init
local function init()
    ConfigurationWindow = cfg.ConfigurationWindow(options, DEFAULTS)

    local function mainMenuButtonHandler()
        ConfigurationWindow.open = not ConfigurationWindow.open
    end

    core_mainmenu.add_button("XP Bar", mainMenuButtonHandler)

    return
    {
        name = "Experience Bar",
        version = "1.4.1",
        author = "tornupgaming",
        description = "Displays your current character experience in a handy visual bar.",
        present = present,
    }
end

-- Exports for other modules
return
{
    __addon =
    {
        init = init
    }
}
