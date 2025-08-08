
local addonName = "SwingTimer"

print(addonName)

-- Default settings
local defaults = {
    color = { r = 1, g = 0.5, b = 0 },
    position = { x = -107.5556945800781, y = -0.4321538805961609 },
    opacity = 0.8,
    barWidth = 22,
    barHeight = 151,
    fontSize = 9,
    iconHeight = 24,
    iconWidth = 24,
    scale = 1.2,
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

            -- Staged settings (live sliders)
            local stagedColor = {
                r = settingsData.color.r,
                g = settingsData.color.g,
                b = settingsData.color.b
            }
            local stagedOpacity = settingsData.opacity or defaults.opacity
            local stagedBarWidth = defaults.barWidth
            local stagedBarHeight = defaults.barHeight
            local stagedFontSize = defaults.fontSize
            local stagedIconHeight = defaults.iconHeight
            local stagedIconWidth = defaults.iconWidth
            local stagedScale = settingsData.scale or defaults.scale

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
            
            local frame -- SWING BAR
            local borderFrame -- SWING BAR BORDER
            local debuffBar -- DEBUFF BAR
            local events -- EVENT TRACKING
            local settings -- SETTINGS PANEL
            local minimapIcon -- MINIMAP ICON

        -- === SWING BAR ===
        frame = CreateFrame("Frame", "SwingTimerFrame", UIParent, "BackdropTemplate")
        frame:SetSize((stagedBarWidth*stagedScale), (stagedBarHeight*stagedScale))
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
        frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedOpacity)
        frame.texture:SetPoint("BOTTOM", frame, "BOTTOM")
        frame.texture:SetPoint("LEFT", frame, "LEFT")
        frame.texture:SetPoint("RIGHT", frame, "RIGHT")
        frame.texture:SetHeight(stagedBarHeight*stagedScale)

        -- Icon of casted spell above the bar
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetSize(stagedIconWidth*stagedScale, stagedIconHeight*stagedScale)
        frame.icon:SetPoint("BOTTOM", frame, "TOP", 0, 5)
        frame.icon:SetAlpha(stagedOpacity)
        frame.icon:Hide()

        -- Position text below the bar
        frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.text:ClearAllPoints()
        frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -5)
        frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize*stagedScale, "OUTLINE")
        frame.text:SetTextColor(1, 1, 1, stagedOpacity)

        -- Create a frame to act as border container
        borderFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)    -- slightly bigger than bar
        borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)

        borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        borderFrame:SetBackdropBorderColor(1, 1, 1, stagedOpacity)

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
                frame.texture:SetHeight((stagedBarHeight*stagedScale) * progress)
                frame.text:SetText(string.format("%.2f", remaining))
            end
        end

        frame:SetScript("OnUpdate", OnUpdate)
        
        local function StartSwingTimer(speed)
            maxTime = speed
            elapsedTime = 0
            paused = false
            frame:SetSize(stagedBarWidth*stagedScale, stagedBarHeight*stagedScale)
            frame.texture:SetHeight(stagedBarHeight*stagedScale)
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedOpacity)
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize*stagedScale, "OUTLINE")
            frame:Show()
        end

        local function ShowPausedBar()
            local speed = UnitAttackSpeed("player") or 1
            maxTime = speed
            elapsedTime = 0
            paused = true
            frame:SetSize(stagedBarWidth*stagedScale, stagedBarHeight*stagedScale)
            frame.texture:SetHeight(stagedBarHeight*stagedScale)
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedOpacity)
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize*stagedScale, "OUTLINE")
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

        -- === DEBUFF BAR ===
        debuffBar = CreateFrame("Frame", "SwingTimerDebuffBar", UIParent)
        debuffBar:SetSize(stagedBarWidth * stagedScale, stagedBarHeight * stagedScale)
        debuffBar:SetPoint("RIGHT", frame, "LEFT", -5, 0) -- Left side of swing bar
        debuffBar:SetAlpha(stagedOpacity)
        debuffBar.icons = {}

        local function UpdateDebuffBar()
            if not settings:IsShown() then
                if not UnitExists("target") or not UnitCanAttack("player", "target") then
                    --print("Hiding icons...")
                    for _, icon in ipairs(debuffBar.icons) do
                        icon:Hide()
                    end
                    return
                end

                local debuffs = {}
                for i = 1, 40 do
                    local name, iconTexture, count, debuffType, duration, expirationTime, source, _, _, spellId = UnitDebuff("target", i)
                    if not name then break end
                    if source == "player" and duration and expirationTime then
                        local remaining = expirationTime - GetTime()
                        if remaining > 0 then
                            table.insert(debuffs, {
                                name = name,
                                icon = iconTexture,
                                duration = duration,
                                expirationTime = expirationTime,
                                remaining = remaining,
                                spellId = spellId,
                            })
                        end
                    end
                end

                table.sort(debuffs, function(a, b)
                    return a.remaining < b.remaining
                end)

                -- Show debuff icons
                for i = 1, #debuffs do
                    local data = debuffs[i]
                    local icon = debuffBar.icons[i]

                    if not icon then
                        icon = CreateFrame("Frame", nil, debuffBar)
                        icon:SetSize(stagedIconWidth * stagedScale, stagedIconHeight * stagedScale)
                        icon.texture = icon:CreateTexture(nil, "ARTWORK")
                        icon.texture:SetAllPoints()
                        icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        icon.text:SetPoint("BOTTOM", icon, "BOTTOM", 0, -1)
                        icon.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize * stagedScale, "OUTLINE")
                        debuffBar.icons[i] = icon
                    end

                    icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * (stagedIconHeight * stagedScale + 2)))
                    icon.texture:SetTexture(data.icon)
                    icon.text:SetText(string.format("%.1f", data.remaining))
                    icon:Show()
                end

                -- Hide unused icons
                for i = #debuffs + 1, #debuffBar.icons do
                    debuffBar.icons[i]:Hide()
                end
            end
        end

        debuffBar:SetScript("OnUpdate", function(self, elapsed)
            UpdateDebuffBar()
        end)

        local function ShowTemporaryDebuffs()
            --print("Show temp debuffs")
            for i = 1, 6 do
                local icon = debuffBar.icons[i]

                if not icon then
                    icon = CreateFrame("Frame", nil, debuffBar)
                    icon:SetSize(stagedIconWidth * stagedScale, stagedIconHeight * stagedScale)
                    icon.texture = icon:CreateTexture(nil, "ARTWORK")
                    icon.texture:SetAllPoints()
                    icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    icon.text:SetPoint("BOTTOM", icon, "BOTTOM", 0, -1)
                    icon.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize * stagedScale, "OUTLINE")
                    debuffBar.icons[i] = icon
                    --print("Create icon", i)
                end

                icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * (stagedIconHeight * stagedScale + 2)))
                icon.texture:SetTexture(select(3, GetSpellInfo(772)))
                icon.text:SetText(string.format("%.1f", 0))
                icon:Show()
            end
        end

        local function ReloadOpacity()
            frame.icon:SetAlpha(stagedOpacity)
            frame.text:SetTextColor(1, 1, 1, stagedOpacity)
            borderFrame:SetBackdropBorderColor(1, 1, 1, stagedOpacity)
            debuffBar:SetAlpha(stagedOpacity)
        end

        -- === EVENT TRACKING ===
        events = CreateFrame("Frame")

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
                    UpdateDebuffBar()
                else
                    UpdateDebuffBar()
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
                    UpdateDebuffBar()
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
                    UpdateDebuffBar()
                end
            elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
                --print("Resetting on event:", event)
                frame.icon:Hide()
                queuedSpellName = nil
                queuedSpellTexture = nil
                isQueuedSpellActive = false
                UpdateDebuffBar()
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
                UpdateDebuffBar()
            end
        end)

        -- === SETTINGS PANEL ===

        settings = CreateFrame("Frame", "SwingTimerSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
        settings:SetSize(300, 270)
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
                UIErrorsFrame:AddMessage("Cannot open settings while in combat.", 1, 0, 0, 1, 53)
                return
            end

            -- Show your settings frame here
            settings:Show()
            ShowPausedBar()
            ShowTemporaryDebuffs()
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
                frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedOpacity)
            end)

            return slider
        end

        local redSlider = CreateColorSlider("SwingTimerRedSlider", "Red", -50, "r")
        local greenSlider = CreateColorSlider("SwingTimerGreenSlider", "Green", -80, "g")
        local blueSlider = CreateColorSlider("SwingTimerBlueSlider", "Blue", -110, "b")

        -- Bar Opacity Slider
        local opacitySlider = CreateFrame("Slider", "SwingTimerBarOpacitySlider", settings, "OptionsSliderTemplate")
        opacitySlider:SetWidth(220)
        opacitySlider:SetMinMaxValues(0.1, 1)
        opacitySlider:SetValueStep(0.01)
        opacitySlider:SetObeyStepOnDrag(true)
        opacitySlider:SetPoint("TOP", settings, "TOP", 0, -140)
        _G[opacitySlider:GetName() .. "Low"]:SetText("10%")
        _G[opacitySlider:GetName() .. "High"]:SetText("100%")
        _G[opacitySlider:GetName() .. "Text"]:SetText("Opacity")

        opacitySlider:SetValue(stagedOpacity)

        opacitySlider:SetScript("OnValueChanged", function(self, value)
            stagedOpacity = value
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedOpacity)
            ReloadOpacity()
        end)

        -- Scale Slider
        local scaleSlider = CreateFrame("Slider", "SwingTimerScaleSlider", settings, "OptionsSliderTemplate")
        scaleSlider:SetWidth(220)
        scaleSlider:SetMinMaxValues(0.5, 2)
        scaleSlider:SetValueStep(0.1)
        scaleSlider:SetObeyStepOnDrag(true)
        scaleSlider:SetPoint("TOP", settings, "TOP", 0, -170)
        _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
        _G[scaleSlider:GetName() .. "High"]:SetText("2")
        _G[scaleSlider:GetName() .. "Text"]:SetText("Scale")

        scaleSlider:SetValue(stagedScale)

        scaleSlider:SetScript("OnValueChanged", function(self, value)
            stagedScale = value
            frame:SetSize((stagedBarWidth*stagedScale), (stagedBarHeight*stagedScale))
            frame.texture:SetHeight(stagedBarHeight*stagedScale)
            frame.icon:SetSize(stagedIconWidth*stagedScale, stagedIconHeight*stagedScale)
            frame.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize*stagedScale, "OUTLINE")
            debuffBar:SetSize(stagedBarWidth * stagedScale, stagedBarHeight * stagedScale)
            for i=1, 6 do
                local icon = debuffBar.icons[i]
                icon:SetSize(stagedIconWidth * stagedScale, stagedIconHeight * stagedScale)
                icon.texture:SetAllPoints()
                icon.text:SetPoint("BOTTOM", icon, "BOTTOM", 0, -1)
                icon.text:SetFont("Fonts\\FRIZQT__.TTF", stagedFontSize * stagedScale, "OUTLINE")
                icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * (stagedIconHeight * stagedScale + 2)))
                debuffBar.icons[i] = icon
            end
        end)

        -- Apply Button
        local applyBtn = CreateFrame("Button", nil, settings, "GameMenuButtonTemplate")
        applyBtn:SetPoint("BOTTOMLEFT", settings, "BOTTOMLEFT", 15, 15)
        applyBtn:SetSize(120, 25)
        applyBtn:SetText("Apply")
        applyBtn:SetNormalFontObject("GameFontNormal")
        applyBtn:SetHighlightFontObject("GameFontHighlight")

        applyBtn:SetScript("OnClick", function()
            -- Save current staged settings
            settingsData.color.r = stagedColor.r
            settingsData.color.g = stagedColor.g
            settingsData.color.b = stagedColor.b
            settingsData.opacity = stagedOpacity
            settingsData.scale = stagedScale

            -- Apply settings
            frame.texture:SetColorTexture(stagedColor.r, stagedColor.g, stagedColor.b, stagedOpacity)

            -- Save position
            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
            settingsData.position.x = xOfs or 0
            settingsData.position.y = yOfs or 0

            -- Hide settings
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
            stagedOpacity = defaults.opacity
            stagedScale = defaults.scale

            redSlider:SetValue(stagedColor.r)
            greenSlider:SetValue(stagedColor.g)
            blueSlider:SetValue(stagedColor.b)
            opacitySlider:SetValue(stagedOpacity)
            scaleSlider:SetValue(stagedScale)

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
                opacitySlider:SetValue(stagedOpacity)
                scaleSlider:SetValue(stagedScale)

                -- Show settings and show bar fully loaded and paused
                ShowSwingTimerSettings()
            end
        end

        -- === MINIMAP ICON ===
        minimapIcon = CreateFrame("Button", "SwingTimerMinimapButton", Minimap)
        minimapIcon:SetSize(25, 25)
        minimapIcon:SetFrameStrata("MEDIUM")
        minimapIcon:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 0, 0)

        -- Icon texture (sword)
        local iconTexture = minimapIcon:CreateTexture(nil, "BACKGROUND")
        iconTexture:SetPoint("CENTER")
        iconTexture:SetSize(minimapIcon:GetWidth() * 0.7, minimapIcon:GetHeight() * 0.7) -- smaller so fits border hole
        iconTexture:SetTexture(GetSpellTexture(78))
        iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- optional zoom for better fit

        -- Apply circular mask (Retail + Classic support)
        local mask = minimapIcon:CreateMaskTexture()
        mask:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        mask:SetAllPoints(iconTexture)
        iconTexture:AddMaskTexture(mask)

        local border = minimapIcon:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetTexCoord(0.05, 0.95, 0.05, 0.95) -- crop out transparent edges
        border:SetSize(minimapIcon:GetWidth() + 22, minimapIcon:GetHeight() + 22)
        border:SetPoint("CENTER", minimapIcon, "CENTER", 10, -10)

        minimapIcon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")    
        local highlight = minimapIcon:GetHighlightTexture()
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER", minimapIcon, "CENTER", 0, 0)
        highlight:SetSize(minimapIcon:GetWidth() + 5, minimapIcon:GetHeight() + 5) -- match border size
        highlight:SetTexCoord(0.05, 0.95, 0.05, 0.95) -- crop padding like border

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

        minimapIcon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
            GameTooltip:SetText("Swing Timer Settings", 1, 1, 1 , wrap, font, 15, flags)
            GameTooltip:AddLine("Left-click to toggle.", true)
            GameTooltip:Show()
        end)

        minimapIcon:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
end)


