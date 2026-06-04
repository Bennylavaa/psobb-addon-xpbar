local function PresentColorEditor(label, col, col_d)
    local i =
    {
        bit.band(bit.rshift(col, 16), 0xFF),
        bit.band(bit.rshift(col, 8), 0xFF),
        bit.band(col, 0xFF),
        bit.band(bit.rshift(col, 24), 0xFF),
    }

    local ids = { "##X", "##Y", "##Z", "##W" }
    local fmt = { "R:%3.0f", "G:%3.0f", "B:%3.0f", "A:%3.0f" }

    imgui.BeginGroup()
    imgui.PushID(label)

    imgui.PushItemWidth(50)
    for n = 1, 4, 1 do
        local changedDragInt = false
        if n ~= 1 then
            imgui.SameLine(0, 5)
        end

        changedDragInt, i[n] = imgui.DragInt(ids[n], i[n], 1.0, 0, 255, fmt[n])
    end
    imgui.PopItemWidth()

    imgui.SameLine(0, 5)
    imgui.ColorButton(i[1] / 255, i[2] / 255, i[3] / 255, 1.0)
    if imgui.IsItemHovered() then
        imgui.SetTooltip(
            string.format(
                "Color:\n#%02X%02X%02X%02X",
                i[1], i[2], i[3], i[4]
            )
        )
    end

    imgui.SameLine(0, 5)
    imgui.Text(label)

    col = bit.lshift(i[4], 24) + bit.lshift(i[1], 16) +  bit.lshift(i[2], 8) +  i[3]

    imgui.SameLine(0, 5)
    if imgui.Button("Reset") then
        col = col_d
    end

    imgui.PopID()
    imgui.EndGroup()

    return col
end

local function ConfigurationWindow(configuration, defaults)
    local this =
    {
        title = "Experience Bar - Configuration",
        fontScale = 1.0,
        open = false,
        changed = false,
    }

    local _configuration = configuration
    local _defaults = defaults or {}
    local _resetConfirm = false

    local function applyTooltip(tooltip)
        if tooltip and imgui.IsItemHovered() then
            imgui.SetTooltip(tooltip)
        end
    end

    local function boolCheckbox(label, key, tooltip)
        if imgui.Checkbox(label, _configuration[key]) then
            _configuration[key] = not _configuration[key]
            this.changed = true
        end
        applyTooltip(tooltip)
    end

    local function flagCheckbox(label, key, flagValue, tooltip)
        local isOn = _configuration[key] == flagValue
        if imgui.Checkbox(label, isOn) then
            _configuration[key] = isOn and "" or flagValue
            this.changed = true
        end
        applyTooltip(tooltip)
    end

    local function dragInt(id, key, min, max, format)
        local changed, value = imgui.DragInt(id, _configuration[key], 1.0, min, max, format)
        if changed then
            _configuration[key] = value
            this.changed = true
        end
    end

    local function colorEditor(label, key, default)
        local newColor = PresentColorEditor(label, _configuration[key], default)
        if newColor ~= _configuration[key] then
            _configuration[key] = newColor
            this.changed = true
        end
    end

    local function section(label, body)
        if imgui.TreeNodeEx(label, "DefaultOpen") then
            body()
            imgui.TreePop()
        end
    end

    local _showWindowSettings = function()
        section("XP Bar", function()
            boolCheckbox("Enable XP Bar Window", "xpEnableWindow")

            section("Bar Window Settings", function()
                flagCheckbox("Disable the title bar", "xpNoTitleBar", "NoTitleBar")
                flagCheckbox("Disable resizing the window", "xpNoResize", "NoResize")
                flagCheckbox("Disable moving the window", "xpNoMove", "NoMove")
                boolCheckbox("Transparent Background", "xpTransparent")
            end)

            section("Hide when", function()
                boolCheckbox("Menus are open", "xpHideWhenMenu")
                boolCheckbox("Symbol chat/word select is open", "xpHideWhenSymbolChat")
                boolCheckbox("The menu is unavailable", "xpHideWhenMenuUnavailable",
                    "Hides the bar in places where the in-game menu can't be opened (e.g., lobbies, character select).")
            end)

            section("Styling", function()
                colorEditor("Bar fill color", "xpBarColor", 0xFFE6B300)
                colorEditor("Percentage text color", "xpBarPercentColor", 0xFFFFFFFF)
                boolCheckbox("Disable percentage text", "xpBarNoOverlay")
                boolCheckbox("Display as a vertical bar", "xpVerticalBar")
            end)

            section("Positioning", function()
                imgui.PushItemWidth(110)
                dragInt("##X", "xpBarX", 0, 0, "Position X: %4.0f")
                imgui.SameLine(0, 5)
                dragInt("##Y", "xpBarY", 0, 0, "Position Y: %4.0f")
                dragInt("##W", "xpBarWidth", -1, 1920, "Width: %4.0f")
                imgui.SameLine(0, 5)
                dragInt("##H", "xpBarHeight", 0, 1080, "Height: %4.0f")
                imgui.PopItemWidth()
            end)

            section("Advanced", function()
                boolCheckbox("Show default instead of error", "xpShowDefaultNotError",
                    "When character data isn't loaded yet (e.g., on the title screen), show a 0% bar instead of an error message.")
            end)
        end)

        section("Text Stats", function()
            imgui.Text("Stats can appear inside the bar window, or in their")
            imgui.Text("own separate window(s) when 'Enable Text Window' is on.")
            imgui.Dummy(1, 4)
            boolCheckbox("Enable Text Window", "textwindow_enable")

            section("Stats to Show", function()
                boolCheckbox("Level", "xpEnableInfoLevel")
                boolCheckbox("Total Exp", "xpEnableInfoTotal")
                boolCheckbox("To Next Level Exp", "xpEnableInfoTNL")
                boolCheckbox(
                    _configuration.xpRatePerHour and "XP per hour (60s avg)" or "XP per minute (60s avg)",
                    "xpEnableInfoRate"
                )
                if _configuration.xpEnableInfoRate then
                    imgui.Dummy(20, 1)
                    imgui.SameLine(0, 0)
                    boolCheckbox("Show rate as per hour (otherwise per minute)", "xpRatePerHour",
                        "Always averaged over the last 60 seconds; this toggle only changes the display unit.")
                end
                boolCheckbox("ETA to next level", "xpEnableInfoETA")
            end)

            if _configuration.textwindow_enable then
                section("Text Window Appearance", function()
                    flagCheckbox("No title bar", "textwindow_noTitleBar", "NoTitleBar")
                    flagCheckbox("No resize", "textwindow_noResize", "NoResize")
                    flagCheckbox("No move", "textwindow_noMove", "NoMove")
                    boolCheckbox("Transparent background", "textwindow_transparent")
                    colorEditor("Text color", "textwindow_percentColor", 0xFFFFFFFF)
                end)

                section("Hide text when", function()
                    boolCheckbox("Menus are open", "textwindow_hideWhenMenuOpen")
                    boolCheckbox("Symbol chat/word select is open", "textwindow_hideWhenSymbolChatOpen")
                    boolCheckbox("The menu is unavailable", "textwindow_hideWhenMenuNotAvailable",
                        "Hides the text in places where the in-game menu can't be opened (e.g., lobbies, character select).")
                end)

                section("Text Positioning", function()
                    boolCheckbox("Split each stat into its own window", "textwindow_splitWindows",
                        "When on, each enabled stat gets its own moveable window so you can scatter them around the screen.")
                    imgui.PushItemWidth(110)
                    if _configuration.textwindow_splitWindows then
                        imgui.Text("Level")
                        dragInt("##LvX", "stat_level_x", 0, 0, "X: %4.0f")
                        imgui.SameLine(0, 5)
                        dragInt("##LvY", "stat_level_y", 0, 0, "Y: %4.0f")

                        imgui.Text("Total Exp")
                        dragInt("##TotX", "stat_total_x", 0, 0, "X: %4.0f")
                        imgui.SameLine(0, 5)
                        dragInt("##TotY", "stat_total_y", 0, 0, "Y: %4.0f")

                        imgui.Text("TNL")
                        dragInt("##TnlX", "stat_tnl_x", 0, 0, "X: %4.0f")
                        imgui.SameLine(0, 5)
                        dragInt("##TnlY", "stat_tnl_y", 0, 0, "Y: %4.0f")

                        imgui.Text("XP/min")
                        dragInt("##RtX", "stat_rate_x", 0, 0, "X: %4.0f")
                        imgui.SameLine(0, 5)
                        dragInt("##RtY", "stat_rate_y", 0, 0, "Y: %4.0f")

                        imgui.Text("ETA")
                        dragInt("##EtaX", "stat_eta_x", 0, 0, "X: %4.0f")
                        imgui.SameLine(0, 5)
                        dragInt("##EtaY", "stat_eta_y", 0, 0, "Y: %4.0f")
                    else
                        dragInt("##TextX", "textwindow_x", 0, 0, "Position X: %4.0f")
                        imgui.SameLine(0, 5)
                        dragInt("##TextY", "textwindow_y", 0, 0, "Position Y: %4.0f")
                    end
                    imgui.PopItemWidth()
                end)
            end
        end)

        imgui.Dummy(1, 8)
        imgui.Separator()
        imgui.Dummy(1, 4)

        if _resetConfirm then
            imgui.Text("Reset all settings to defaults?")
            imgui.SameLine(0, 8)
            if imgui.Button("Confirm") then
                for k, v in pairs(_defaults) do
                    if k ~= "configurationEnableWindow" then
                        _configuration[k] = v
                    end
                end
                this.changed = true
                _resetConfirm = false
            end
            imgui.SameLine(0, 4)
            if imgui.Button("Cancel") then
                _resetConfirm = false
            end
        else
            if imgui.Button("Reset to Defaults") then
                _resetConfirm = true
            end
        end
    end

    this.Update = function()
        if this.open == false then
            return
        end

        imgui.SetNextWindowSize(500, 400, 'FirstUseEver')
        local visible
        visible, this.open = imgui.Begin(this.title, this.open)
        imgui.SetWindowFontScale(this.fontScale)

        if visible then
            _showWindowSettings()
        end

        imgui.End()
    end

    return this
end

return
{
    ConfigurationWindow = ConfigurationWindow,
}
