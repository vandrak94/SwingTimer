
local addonName = "SwingTimer"

print(addonName)

-- Default settings
local defaults = {
    color = { r = 1, g = 0.5, b = 0 },
    position = { x = -107.5556945800781, y = -0.4321538805961609 },
    barOpacity = 0.5,
    barWidth = 10,
    barHeight = 143,
    fontSize = 10,
}

-- Wait for the addon to be fully loaded
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then

        print(addonName,"was successfully loaded.")
        -- Load saved settings or use defaults
            if not SwingTimerSettings then
                SwingTimerSettings = {}
            end
            
            local settingsData = SwingTimerSettings or {}
            SwingTimerSettings = settingsData
            settingsData.color = settingsData.color or {}
            settingsData.position = settingsData.position or {}

            for k, v in pairs(defaults.color) do
                if settingsData.color[k] == nil then
                    settingsData.color[k] = v
                end
            end

            for k, v in pairs(defaults.position) do
                if settingsData.position[k] == nil then
                    settingsData.position[k] = v
                end
            end

            settingsData.barOpacity = settingsData.barOpacity or defaults.barOpacity
            settingsData.barWidth = settingsData.barWidth or defaults.barWidth
            settingsData.barHeight = settingsData.barHeight or defaults.barHeight
            settingsData.fontSize = settingsData.fontSize or defaults.fontSize

            -- Staged settings (live sliders)
            local stagedColor = {
                r = settingsData.color.r,
                g = settingsData.color.g,
                b = settingsData.color.b
            }
            local stagedBarOpacity = settingsData.barOpacity
            local stagedBarWidth = settingsData.barWidth
            local stagedBarHeight = settingsData.barHeight
            local stagedFontSize = settingsData.fontSize

            local queuedSpellName = nil
            local queuedSpellTexture = nil
            local isQueuedSpellActive = false

            local swingReplacingSpells = {}

            -- Spell IDs by class
            local spellIDs = {}
            local _, playerClass = UnitClass("player")
            if playerClass == "WARRIOR" then
                spellIDs = {78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 845, 7369, 11608, 11609, 20569, 1464} -- Heroic Strike, Cleave, Slam
            elseif playerClass == "DRUID" then
                spellIDs = {6807} -- Maul
            end

            for _, id in ipairs(spellIDs) do
                local name = GetSpellInfo(id)
                if name then
                    swingReplacingSpells[name] = true
                    --print("Registered swing-replacing spell:", name)
                end
            end

        -- === SWING BAR ===
        local frame = CreateFrame("Frame", "SwingTimerFrame", UIParent, "BackdropTemplate")
        frame:SetSize(stagedBarWidth, stagedBarHeight)
        frame:SetPoint("CENTER", UIParent, "CENTER", settingsData.position.x, settingsData.position.y)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        frame:Hide()

        frame.texture = frame:CreateTexture(nil, "BACKGROUND")
        frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedBarOpacity)
        frame.texture:SetPoint("BOTTOM", frame, "BOTTOM")
        frame.texture:SetPoint("LEFT", frame, "LEFT")
        frame.texture:SetPoint("RIGHT", frame, "RIGHT")
        frame.texture:SetHeight(stagedBarHeight)

        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- Position text below the bar
        frame.text:ClearAllPoints()
        frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -5)
        frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize, "OUTLINE")
        frame.text:SetTextColor(1, 1, 1, stagedBarOpacity)

        -- Icon of casted spell above the bar
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetSize(24, 24)
        frame.icon:SetPoint("BOTTOM", frame, "TOP", 0, 10)
        frame.icon:SetAlpha(stagedBarOpacity)
        frame.icon:Hide()

        -- Create a frame to act as border container
        local borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)    -- slightly bigger than bar
        borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)

        borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        borderFrame:SetBackdropBorderColor(1, 1, 1, stagedBarOpacity)

        local function ReloadOpacity()
            frame.icon:SetAlpha(stagedBarOpacity)
            frame.text:SetTextColor(1, 1, 1, stagedBarOpacity)
            borderFrame:SetBackdropBorderColor(1, 1, 1, stagedBarOpacity)
        end

        local maxTime = 0
        local elapsedTime = 0
        local paused = false

        local function OnUpdate(self, elapsed)
            if paused then return end
            elapsedTime = elapsedTime + elapsed
            if elapsedTime >= maxTime then
                self:Hide()
            else
                local remaining = maxTime - elapsedTime
                local progress = remaining / maxTime
                frame.texture:SetHeight(stagedBarHeight * progress)
                frame.text:SetText(string.format("%.2f", remaining))
            end
        end

        frame:SetScript("OnUpdate", OnUpdate)

        local function StartSwingTimer(speed)
            maxTime = speed
            elapsedTime = 0
            paused = false
            frame:SetSize(stagedBarWidth, stagedBarHeight)
            frame.texture:SetHeight(stagedBarHeight)
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedBarOpacity)
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize, "OUTLINE")
            frame:Show()
        end

        local function ShowPausedBar()
            local speed = UnitAttackSpeed("player") or 1
            maxTime = speed
            elapsedTime = 0
            paused = true
            frame:SetSize(stagedBarWidth, stagedBarHeight)
            frame.texture:SetHeight(stagedBarHeight)
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedBarOpacity)
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize, "OUTLINE")
            frame.text:SetText(string.format("%.2f", maxTime))
            frame:Show()
            frame.icon:SetTexture(select(3, GetSpellInfo(78)))
            frame.icon:Show()
        end

        local function HideBar()
            frame:Hide()
            frame.icon:Hide()
            frame.icon:SetTexture(nil)
            paused = false
        end

        -- === EVENT TRACKING ===
        local events = CreateFrame("Frame")

        -- Register all relevant events
        events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_LOGIN")
        events:RegisterEvent("PLAYER_STARTED_MOVING")
        events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        events:RegisterEvent("UNIT_SPELLCAST_SENT")
        events:RegisterEvent("PLAYER_TARGET_CHANGED")

        -- Event handler function
        events:SetScript("OnEvent", function(self, event, ...)
            if event == "UNIT_SPELLCAST_SENT" then
                local unit, target, castGUID, spellID = ...
                if unit == "player" then
                    local spellName = GetSpellInfo(spellID)
                    if swingReplacingSpells[spellName] then
                        --print("Spell SENT (queued):", spellName)
                        queuedSpellName = spellName
                        queuedSpellTexture = select(3, GetSpellInfo(spellID))
                        frame.icon:SetTexture(queuedSpellTexture)
                        frame.icon:Show()
                        isQueuedSpellActive = true
                    end
                else
                    -- Do nothing: a non-swing-replacing spell like Rend was used
                    --print("Non-swing-replacing spell used:", spellName)
                end
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                local unit, castGUID, spellID = ...
                if unit == "player" then
                    local spellName = GetSpellInfo(spellID)
                    if swingReplacingSpells[spellName] then
                        --print("Swing-replacing spell cast succeeded:", spellName)
                        queuedSpellName = spellName
                        queuedSpellTexture = select(3, GetSpellInfo(spellID))
                        frame.icon:SetTexture(queuedSpellTexture)
                        frame.icon:Show()
                        isQueuedSpellActive = true
                    end
                end
            elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                local timestamp, subevent, _, sourceGUID, _, _, _, _, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()

                if sourceGUID == UnitGUID("player") then
                    --print("Combat event:", subevent, spellName or "")

                    if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
                        --print("Auto attack swing fired")
                        queuedSpellName = nil
                        queuedSpellTexture = nil
                        frame.icon:Hide()
                        isQueuedSpellActive = false

                        local speed = UnitAttackSpeed("player")
                        if speed then
                            --print("Starting swing timer with speed:", speed)
                            StartSwingTimer(speed)
                        end

                    elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then
                        if swingReplacingSpells[spellName] then
                            --print("Swing-replacing spell fired:", spellName)
                            queuedSpellName = nil
                            queuedSpellTexture = nil
                            frame.icon:Hide()
                            isQueuedSpellActive = false

                            local speed = UnitAttackSpeed("player")
                            if speed then
                                --print("Starting swing timer with spell:", speed)
                                StartSwingTimer(speed)
                            end
                        else
                            -- Do nothing: a non-swing-replacing spell like Rend was used
                            --print("Non-swing-replacing spell used:", spellName)
                        end
                    
                    elseif subevent == "PARTY_KILL" then
                        local destGUID = select(8, CombatLogGetCurrentEventInfo())
                        if destGUID == UnitGUID("target") then
                            --print("Your target has died. Hiding swing timer.")
                            HideBar()
                            queuedSpellName = nil
                            queuedSpellTexture = nil
                            frame.icon:Hide()
                            isQueuedSpellActive = false
                        end
                    end
                end
            elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
                --print("Resetting on event:", event)
                frame.icon:Hide()
                queuedSpellName = nil
                queuedSpellTexture = nil
                isQueuedSpellActive = false
            elseif event == "PLAYER_TARGET_CHANGED" then
                if not UnitAffectingCombat("player") then
                    -- Player not in combat, ignore target changes
                    return
                elseif not UnitExists("target") then
                    --print("Target cleared. Hiding swing timer.")
                    HideBar()
                    queuedSpellName = nil
                    queuedSpellTexture = nil
                    frame.icon:Hide()
                    isQueuedSpellActive = false
                elseif UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
                    -- New hostile target — reset timer
                    HideBar()
                    local speed = UnitAttackSpeed("player")
                    if speed then
                        --print("Starting swing timer with speed:", speed)
                        StartSwingTimer(speed)
                    end
                end
            end
        end)


        -- === SETTINGS PANEL ===

        local settings = CreateFrame("Frame", "SwingTimerSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
        settings:SetSize(300, 350)
        settings:SetPoint("CENTER")
        settings:SetMovable(true)
        settings:EnableMouse(true)
        settings:RegisterForDrag("LeftButton")
        settings:SetScript("OnDragStart", settings.StartMoving)
        settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
        settings:Hide()
        settings:SetAlpha(1)

        settings.title = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        settings.title:SetPoint("TOP", settings, "TOP", 0, -5)
        settings.title:SetText("Swing Timer Settings")

        local function ShowSwingTimerSettings()
            if InCombatLockdown() then
                print("Cannot open settings while in combat.")
                return
            end

            -- Show your settings frame here
            settings:Show()
            ShowPausedBar()
        end

        SwingTimerSettingsFrame:SetScript("OnHide", function(self)
            ReloadOpacity()
            HideBar()
        end)

        -- Color sliders factory
        local function CreateColorSlider(name, label, yOffset, colorKey)
            local slider = CreateFrame("Slider", name, settings, "OptionsSliderTemplate")
            slider:SetWidth(220)
            slider:SetMinMaxValues(0, 1)
            slider:SetValueStep(0.01)
            slider:SetObeyStepOnDrag(true)
            slider:SetPoint("TOP", settings, "TOP", 0, yOffset)
            _G[slider:GetName() .. "Low"]:SetText("0")
            _G[slider:GetName() .. "High"]:SetText("1")
            _G[slider:GetName() .. "Text"]:SetText(label)

            slider:SetValue(stagedColor[colorKey])

            slider:SetScript("OnValueChanged", function(self, value)
                stagedColor[colorKey] = value
                frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedBarOpacity)
            end)

            return slider
        end

        local redSlider = CreateColorSlider("SwingTimerRedSlider", "Red", -40, "r")
        local greenSlider = CreateColorSlider("SwingTimerGreenSlider", "Green", -70, "g")
        local blueSlider = CreateColorSlider("SwingTimerBlueSlider", "Blue", -100, "b")

        -- Bar Opacity Slider
        local opacitySlider = CreateFrame("Slider", "SwingTimerBarOpacitySlider", settings, "OptionsSliderTemplate")
        opacitySlider:SetWidth(220)
        opacitySlider:SetMinMaxValues(0.1, 1)
        opacitySlider:SetValueStep(0.01)
        opacitySlider:SetObeyStepOnDrag(true)
        opacitySlider:SetPoint("TOP", settings, "TOP", 0, -140)
        _G[opacitySlider:GetName() .. "Low"]:SetText("10%")
        _G[opacitySlider:GetName() .. "High"]:SetText("100%")
        _G[opacitySlider:GetName() .. "Text"]:SetText("Bar Opacity")

        opacitySlider:SetValue(stagedBarOpacity)

        opacitySlider:SetScript("OnValueChanged", function(self, value)
            stagedBarOpacity = value
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedBarOpacity)
            ReloadOpacity()
        end)

        -- Bar Width Slider
        local widthSlider = CreateFrame("Slider", "SwingTimerBarWidthSlider", settings, "OptionsSliderTemplate")
        widthSlider:SetWidth(220)
        widthSlider:SetMinMaxValues(10, 100)
        widthSlider:SetValueStep(1)
        widthSlider:SetObeyStepOnDrag(true)
        widthSlider:SetPoint("TOP", settings, "TOP", 0, -180)
        _G[widthSlider:GetName() .. "Low"]:SetText("10")
        _G[widthSlider:GetName() .. "High"]:SetText("100")
        _G[widthSlider:GetName() .. "Text"]:SetText("Bar Width")

        widthSlider:SetValue(stagedBarWidth)

        widthSlider:SetScript("OnValueChanged", function(self, value)
            stagedBarWidth = value
            frame:SetWidth(stagedBarWidth)
        end)

        -- Bar Height Slider
        local heightSlider = CreateFrame("Slider", "SwingTimerBarHeightSlider", settings, "OptionsSliderTemplate")
        heightSlider:SetWidth(220)
        heightSlider:SetMinMaxValues(50, 400)
        heightSlider:SetValueStep(1)
        heightSlider:SetObeyStepOnDrag(true)
        heightSlider:SetPoint("TOP", settings, "TOP", 0, -220)
        _G[heightSlider:GetName() .. "Low"]:SetText("50")
        _G[heightSlider:GetName() .. "High"]:SetText("400")
        _G[heightSlider:GetName() .. "Text"]:SetText("Bar Height")

        heightSlider:SetValue(stagedBarHeight)

        heightSlider:SetScript("OnValueChanged", function(self, value)
            stagedBarHeight = value
            frame:SetHeight(stagedBarHeight)
            frame.texture:SetHeight(stagedBarHeight)
        end)

        -- Font Size Slider
        local fontSizeSlider = CreateFrame("Slider", "SwingTimerFontSizeSlider", settings, "OptionsSliderTemplate")
        fontSizeSlider:SetWidth(220)
        fontSizeSlider:SetMinMaxValues(8, 30)
        fontSizeSlider:SetValueStep(1)
        fontSizeSlider:SetObeyStepOnDrag(true)
        fontSizeSlider:SetPoint("TOP", settings, "TOP", 0, -260)
        _G[fontSizeSlider:GetName() .. "Low"]:SetText("8")
        _G[fontSizeSlider:GetName() .. "High"]:SetText("30")
        _G[fontSizeSlider:GetName() .. "Text"]:SetText("Font Size")

        fontSizeSlider:SetValue(stagedFontSize)

        fontSizeSlider:SetScript("OnValueChanged", function(self, value)
            stagedFontSize = value
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize, "OUTLINE")
        end)

        -- Save Button
        local saveBtn = CreateFrame("Button", nil, settings, "GameMenuButtonTemplate")
        saveBtn:SetPoint("BOTTOMLEFT", settings, "BOTTOMLEFT", 15, 15)
        saveBtn:SetSize(120, 25)
        saveBtn:SetText("Save")
        saveBtn:SetNormalFontObject("GameFontNormal")
        saveBtn:SetHighlightFontObject("GameFontHighlight")

        saveBtn:SetScript("OnClick", function()
            -- Save current staged settings
            settingsData.color.r = stagedColor.r
            settingsData.color.g = stagedColor.g
            settingsData.color.b = stagedColor.b
            settingsData.barOpacity = stagedBarOpacity
            settingsData.barWidth = stagedBarWidth
            settingsData.barHeight = stagedBarHeight
            settingsData.fontSize = stagedFontSize

            -- Apply settings
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedBarOpacity)
            frame:SetSize(stagedBarWidth, stagedBarHeight)
            frame.texture:SetHeight(stagedBarHeight)
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize, "OUTLINE")

            -- Save position
            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
            settingsData.position.x = xOfs or 0
            settingsData.position.y = yOfs or 0

            settings:Hide()
        end)

        -- Reset Button
        local resetBtn = CreateFrame("Button", nil, settings, "GameMenuButtonTemplate")
        resetBtn:SetPoint("BOTTOMRIGHT", settings, "BOTTOMRIGHT", -15, 15)
        resetBtn:SetSize(120, 25)
        resetBtn:SetText("Reset to Default")
        resetBtn:SetNormalFontObject("GameFontNormal")
        resetBtn:SetHighlightFontObject("GameFontHighlight")

        resetBtn:SetScript("OnClick", function()
            -- Reset staged to defaults
            stagedColor.r = defaults.color.r
            stagedColor.g = defaults.color.g
            stagedColor.b = defaults.color.b
            stagedBarOpacity = defaults.barOpacity
            stagedBarWidth = defaults.barWidth
            stagedBarHeight = defaults.barHeight
            stagedFontSize = defaults.fontSize

            redSlider:SetValue(stagedColor.r)
            greenSlider:SetValue(stagedColor.g)
            blueSlider:SetValue(stagedColor.b)
            opacitySlider:SetValue(stagedBarOpacity)
            widthSlider:SetValue(stagedBarWidth)
            heightSlider:SetValue(stagedBarHeight)
            fontSizeSlider:SetValue(stagedFontSize)

            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedBarOpacity)
            frame:SetSize(stagedBarWidth, stagedBarHeight)
            frame.texture:SetHeight(stagedBarHeight)
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize, "OUTLINE")
            ReloadOpacity()
        end)

        -- Slash command to toggle settings
        SLASH_SWINGTIMER1 = "/swingtimer"
        SlashCmdList["SWINGTIMER"] = function()
            if settings:IsShown() then
                settings:Hide()
            else
                -- Update sliders to staged values before showing
                redSlider:SetValue(stagedColor.r)
                greenSlider:SetValue(stagedColor.g)
                blueSlider:SetValue(stagedColor.b)
                opacitySlider:SetValue(stagedBarOpacity)
                widthSlider:SetValue(stagedBarWidth)
                heightSlider:SetValue(stagedBarHeight)
                fontSizeSlider:SetValue(stagedFontSize)

                -- Show settings and show bar fully loaded and paused
                ShowSwingTimerSettings()
            end
        end

        -- === MINIMAP ICON ===
        local minimapIcon = CreateFrame("Button", "SwingTimerMinimapButton", Minimap)
        minimapIcon:SetSize(25, 25) -- smaller icon size
        minimapIcon:SetFrameStrata("MEDIUM")
        minimapIcon:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -5, -5)

        -- Icon texture (sword)
        local iconTexture = minimapIcon:CreateTexture(nil, "BACKGROUND")
        iconTexture:SetAllPoints()
        iconTexture:SetTexture("Interface\\Icons\\INV_Sword_04")

        minimapIcon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        minimapIcon:RegisterForClicks("LeftButtonUp")
        minimapIcon:SetScript("OnClick", function(self, button)
            if not (IsShiftKeyDown() and button == "LeftButton") then
                -- Open/close settings on normal click (no drag)
                if settings:IsShown() then
                    settings:Hide()
                else
                    SlashCmdList["SWINGTIMER"]()
                end
            end
        end)

        -- Make minimap icon draggable only with Shift+LeftButton
        minimapIcon:SetScript("OnMouseDown", function(self, button)
            if IsShiftKeyDown() and button == "LeftButton" then
                self.isDragging = true
                self:StartMoving()
            end
        end)

        minimapIcon:SetScript("OnMouseUp", function(self, button)
            if self.isDragging then
                self.isDragging = false
                self:StopMovingOrSizing()

                local mx, my = Minimap:GetCenter()
                local px, py = self:GetCenter()
                local dx, dy = px - mx, py - my
                local radius = Minimap:GetWidth() / 2 + 10

                local angle = math.atan2(dy, dx)
                local clampedX = radius * math.cos(angle)
                local clampedY = radius * math.sin(angle)

                self:ClearAllPoints()
                self:SetPoint("CENTER", Minimap, "CENTER", clampedX, clampedY)
            end
        end)

        minimapIcon:SetMovable(true)
        minimapIcon:EnableMouse(true)

        -- Prevent minimap icon from blocking Minimap clicks when dragging
        minimapIcon:SetScript("OnHide", function()
            if minimapIcon.isDragging then
                minimapIcon.isDragging = false
                minimapIcon:StopMovingOrSizing()
            end
        end)
    end
end)


