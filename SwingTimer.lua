local addonName = "SwingTimer"

-- Wait for the addon to be fully loaded
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        
        local _, class = UnitClass("player")

        -- Default settings
        local defaults = {
            color = RAID_CLASS_COLORS[class],
            position = { x = -107.5556945800781, y = -0.4321538805961609 },
            opacity = 0.8,
            barHeight = 151,
            fontSize = 9,
            iconHeight = 24,
            iconWidth = 24,
            scale = 1.2,
            space = 3,
            showOffHandSwingBar = true
        }

        print(addonName,"was successfully loaded.")

        -- === VARIABLES ===
        
            -- Load saved settings or use defaults
            if not SwingTimerSettings then
                SwingTimerSettings = {}
            end
            
            local settingsData = SwingTimerSettings or {}
            SwingTimerSettings = settingsData
            settingsData.position = settingsData.position or {}

            for k, v in pairs(defaults.position) do
                if settingsData.position[k] == nil then
                    settingsData.position[k] = v
                end
            end

            local stagedOpacity = settingsData.opacity or defaults.opacity
            local stagedScale = settingsData.scale or defaults.scale
            if settingsData.showOffHandSwingBar ~= nil then
                stagedShowOffHandSwingBar = settingsData.showOffHandSwingBar
            else
                stagedShowOffHandSwingBar = defaults.showOffHandSwingBar
            end

            -- Spell que variables
            local queuedSpellName = nil
            local queuedSpellTexture = nil
            local isQueuedSpellActive = false

            -- Off-hand weapon detection
            local offHandWeaponEquipped = false

            -- Power variables (Rage, Mana, Energy)
            local powerType = UnitPowerType("player") -- returns 0 for mana, 1 for rage, 3 for energy
            local currentPower = UnitPower("player", powerType)
            local maxPower = UnitPowerMax("player", powerType)
            
            -- Pause variable
            local paused = false

            -- Variable for values at the time of opening the settings and temporary settings values
            local settingsTemporaryValues, settingsSessionValues = {}, {}

            -- Spell IDs by class
            local swingReplacingSpells = {}

            -- Create hidden tooltip for scanning
            local scanTip = CreateFrame("GameTooltip", "SwingScanTooltip", nil, "GameTooltipTemplate")
            scanTip:SetOwner(UIParent, "ANCHOR_NONE")

            local function ScanSwingReplacingSpells()

                wipe(swingReplacingSpells) -- clear table in case of reload

                local keyword = "next melee" -- change if localized

                local i = 1
                while true do
                    local spellName, spellSubName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                    if not spellName then break end -- no more spells in spellbook

                    -- Load tooltip for this spell
                    scanTip:ClearLines()
                    scanTip:SetSpellBookItem(i, BOOKTYPE_SPELL)

                    local found = false
                    for lineIndex = 1, scanTip:NumLines() do
                        local line = _G["SwingScanTooltipTextLeft" .. lineIndex]:GetText()
                        if line and string.find(string.lower(line), keyword) then
                            swingReplacingSpells[spellName] = true
                            found = true
                            break
                        end
                    end

                    i = i + 1
                end

                --[[
                print("Swing-replacing spells detected:")
                for name in pairs(swingReplacingSpells) do
                    print(" - " .. name)
                end--]]

            end

            -- Run after player logs in (spellbook is ready)
            local spellInspector = CreateFrame("Frame")
            spellInspector:RegisterEvent("PLAYER_LOGIN")
            spellInspector:RegisterEvent("LEARNED_SPELL_IN_TAB") -- new spell learned
            spellInspector:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") -- spec change (Retail)
            spellInspector:RegisterEvent("PLAYER_TALENT_UPDATE") -- talents/forms may change spells
            spellInspector:RegisterEvent("SPELLS_CHANGED") -- covers most spellbook updates
            spellInspector:SetScript("OnEvent", function()
                -- Delay slightly in case the spellbook hasn't fully updated yet
                C_Timer.After(0.2, ScanSwingReplacingSpells)
            end)

            -- Frames defined

            local mainHandSwingBar -- MAIN HAND SWING BAR
            local offHandSwingBar -- OFF HAND SWING BAR
            local enemyHealthBar -- ENEMY HEALTH BAR
            local debuffBar -- DEBUFF BAR
            local resourceBar -- RESOURCE BAR
            local events -- EVENT TRACKING
            local settings -- SETTINGS PANEL
            local minimapIcon -- MINIMAP ICON

            -- Swing variables
            local mainHandSpeed, offHandSpeed = UnitAttackSpeed("player")
            if mainHandSpeed == nil then
                mainHandSpeed = 0
            end
            if offHandSpeed == nil then
                offHandSpeed = 0
            end
            local mainHandMaxTime, offHandMaxTime = 0, 0
            local mainHandTimer, offHandTimer = 0, 0
            local offhandSwinging = false

            local function IsOffHandWeaponEquipped()
                local offHandSlot = GetInventoryItemID("player", 17)

                if not offHandSlot then
                    offHandWeaponEquipped = false
                    return
                end

                local itemName, _, _, _, _, itemType, itemSubType = GetItemInfo(offHandSlot)
                offHandWeaponEquipped = (itemType == "Weapon")
            end

            local function GetOffHandType()

                local itemName, _, _, _, _, itemType, itemSubType = GetItemInfo(offHandSlot)
                return itemType, itemSubType, itemName
            end

             -- Run after player logs in (spellbook is ready)
            local offHandInspector = CreateFrame("Frame")
            offHandInspector:RegisterEvent("PLAYER_LOGIN")
            offHandInspector:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

            offHandInspector:SetScript("OnEvent", function()
                IsOffHandWeaponEquipped()
                mainHandSpeed, offHandSpeed = UnitAttackSpeed("player")
                if offHandSpeed == nil then
                    offHandSpeed = 0
                end
                mainHandSwingBar.text:SetText(string.format("%.2f", mainHandSpeed))
                offHandSwingBar.text:SetText(string.format("%.2f", offHandSpeed))
            end)

        -- === MAIN HAND SWING BAR ===
            mainHandSwingBar = CreateFrame("Frame", "SwingTimerFrame", UIParent, "BackdropTemplate")
            mainHandSwingBar:SetMovable(true)
            mainHandSwingBar:EnableMouse(true)
            mainHandSwingBar:RegisterForDrag("LeftButton")
            mainHandSwingBar:SetScript("OnDragStart", mainHandSwingBar.StartMoving)
            mainHandSwingBar:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
            end)
            mainHandSwingBar:SetSize((defaults.iconWidth * stagedScale), (defaults.barHeight*stagedScale))
            mainHandSwingBar:SetPoint("CENTER", UIParent, "CENTER", settingsData.position.x, settingsData.position.y)
            --mainHandSwingBar:Show()
            mainHandSwingBar:Hide()

            -- Texture for filling swing bar
            mainHandSwingBar.texture = mainHandSwingBar:CreateTexture(nil, "BACKGROUND")
            mainHandSwingBar.texture:SetColorTexture(defaults.color.r, defaults.color.g, defaults.color.b)
            mainHandSwingBar.texture:SetPoint("BOTTOM", mainHandSwingBar, "BOTTOM", -2, 1)
            mainHandSwingBar.texture:SetPoint("LEFT", mainHandSwingBar, "LEFT", 2, -2)
            mainHandSwingBar.texture:SetPoint("RIGHT", mainHandSwingBar, "RIGHT", -2, 2)
            mainHandSwingBar.texture:SetHeight(0)
            
            -- Backdrop for visibility
            mainHandSwingBar.bg = mainHandSwingBar:CreateTexture(nil, "BACKGROUND")
            mainHandSwingBar.bg:SetAllPoints(true)
            mainHandSwingBar.bg:SetColorTexture(0, 0, 0, 0.2)

            -- Icon of casted spell above the bar
            mainHandSwingBar.icon = mainHandSwingBar:CreateTexture(nil, "ARTWORK")
            mainHandSwingBar.icon:SetSize(defaults.iconWidth * stagedScale, defaults.iconHeight * stagedScale)
            mainHandSwingBar.icon:SetPoint("BOTTOM", mainHandSwingBar, "TOP", 0, defaults.space * stagedScale)
            mainHandSwingBar.icon:Hide()

            -- Position text below the bar
            mainHandSwingBar.text = mainHandSwingBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            mainHandSwingBar.text:ClearAllPoints()
            mainHandSwingBar.text:SetPoint("TOP", mainHandSwingBar, "BOTTOM", 0, -defaults.space*stagedScale)
            mainHandSwingBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * stagedScale, "OUTLINE")
            mainHandSwingBar.text:SetText(string.format("%.2f", mainHandSpeed))

            -- Create a mainHandSwingBar to act as border container
            mainHandSwingBar.border = CreateFrame("Frame", nil, mainHandSwingBar, "BackdropTemplate")
            mainHandSwingBar.border:SetPoint("TOPLEFT", mainHandSwingBar, "TOPLEFT", -1 * stagedScale, 1 * stagedScale)
            mainHandSwingBar.border:SetPoint("BOTTOMRIGHT", mainHandSwingBar, "BOTTOMRIGHT", 1 * stagedScale, -1 * stagedScale)

            mainHandSwingBar.border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10 * stagedScale
            })
            mainHandSwingBar.border:SetBackdropBorderColor(1, 1, 1)

            local function OnUpdate(self, elapsed)
                if paused then return end
                mainHandTimer = mainHandTimer + elapsed
                if mainHandTimer >= mainHandMaxTime then
                    if not UnitAffectingCombat("player") then
                        self:Hide()
                    else
                        mainHandSwingBar.texture:SetHeight(0)
                        mainHandSwingBar.text:SetText(string.format("%.2f", mainHandSpeed))
                    end
                else
                    local remaining = mainHandMaxTime - mainHandTimer
                    local progress = remaining / mainHandMaxTime
                    mainHandSwingBar.texture:SetHeight((defaults.barHeight * stagedScale) * progress)
                    mainHandSwingBar.text:SetText(string.format("%.2f", remaining))
                end
            end

            mainHandSwingBar:SetScript("OnUpdate", OnUpdate)
            
            local function StartSwingTimer()
                mainHandMaxTime = mainHandSpeed
                mainHandTimer = 0
                paused = false
                mainHandSwingBar:SetSize(defaults.iconWidth * stagedScale, defaults.barHeight * stagedScale)
                mainHandSwingBar.texture:SetHeight(defaults.barHeight * stagedScale)
                mainHandSwingBar.texture:SetColorTexture(defaults.color.r, defaults.color.g, defaults.color.b)
                mainHandSwingBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * stagedScale, "OUTLINE")
                mainHandSwingBar:Show()
                resourceBar:Show()
            end

            local function HideBar()
                paused = false
                mainHandSwingBar:Hide()
                offHandSwingBar:Hide()
                enemyHealthBar:Hide()
                resourceBar:Hide()
                mainHandSwingBar.icon:Hide()
                mainHandSwingBar.icon:SetTexture(nil)
                mainHandSwingBar.texture:SetHeight(0)
                offHandSwingBar.texture:SetHeight(0)
                enemyHealthBar.texture:SetHeight(0)
                resourceBar:SetValue(currentPower)
                
            end

        -- === OFF HAND SWING BAR === -

            offHandSwingBar = CreateFrame("Frame", "SwingTimerFrame", mainHandSwingBar, "BackdropTemplate")
            offHandSwingBar:SetMovable(true)
            offHandSwingBar:EnableMouse(true)
            offHandSwingBar:RegisterForDrag("LeftButton")
            offHandSwingBar:SetScript("OnDragStart", offHandSwingBar.StartMoving)
            offHandSwingBar:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
            end)
            offHandSwingBar:SetSize((defaults.iconWidth * stagedScale), (defaults.barHeight * stagedScale))
            offHandSwingBar:SetPoint("LEFT", mainHandSwingBar, "RIGHT", 0, 0)
            offHandSwingBar:Hide()

            -- Texture for filling swing bar
            offHandSwingBar.texture = offHandSwingBar:CreateTexture(nil, "BACKGROUND")
            offHandSwingBar.texture:SetColorTexture(defaults.color.r, defaults.color.g, defaults.color.b)
            offHandSwingBar.texture:SetPoint("BOTTOM", offHandSwingBar, "BOTTOM", -2, 1)
            offHandSwingBar.texture:SetPoint("LEFT", offHandSwingBar, "LEFT", 2, -2)
            offHandSwingBar.texture:SetPoint("RIGHT", offHandSwingBar, "RIGHT", -2, 2)
            offHandSwingBar.texture:SetHeight(0)
            
            -- Backdrop for visibility
            offHandSwingBar.bg = offHandSwingBar:CreateTexture(nil, "BACKGROUND")
            offHandSwingBar.bg:SetAllPoints(true)
            offHandSwingBar.bg:SetColorTexture(0, 0, 0, 0.2)

            -- Icon of casted spell above the bar
            offHandSwingBar.icon = offHandSwingBar:CreateTexture(nil, "ARTWORK")
            offHandSwingBar.icon:SetSize(defaults.iconWidth * stagedScale, defaults.iconHeight * stagedScale)
            offHandSwingBar.icon:SetPoint("BOTTOM", offHandSwingBar, "TOP", 0, defaults.space * stagedScale)
            offHandSwingBar.icon:Hide()

            -- Position text below the bar
            offHandSwingBar.text = offHandSwingBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            offHandSwingBar.text:ClearAllPoints()
            offHandSwingBar.text:SetPoint("TOP", offHandSwingBar, "BOTTOM", 0, -defaults.space * stagedScale)
            offHandSwingBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * stagedScale, "OUTLINE")
            offHandSwingBar.text:SetText(string.format("%.2f", offHandSpeed))

            -- Create a offHandSwingBar to act as border container
            offHandSwingBar.border = CreateFrame("Frame", nil, offHandSwingBar, "BackdropTemplate")
            offHandSwingBar.border:SetPoint("TOPLEFT", offHandSwingBar, "TOPLEFT", -1 * stagedScale, 1 * stagedScale)
            offHandSwingBar.border:SetPoint("BOTTOMRIGHT", offHandSwingBar, "BOTTOMRIGHT", 1 * stagedScale, -1 * stagedScale)

            offHandSwingBar.border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10 * stagedScale
            })
            offHandSwingBar.border:SetBackdropBorderColor(1, 1, 1)

            local _, ohSpeed = UnitAttackSpeed("player") -- second return = off-hand
            local ohTimer = ohSpeed

            local function StartOffhandSwing()
                if stagedShowOffHandSwingBar == false then return end
                offhandSwinging = true
                offHandMaxTime = offHandSpeed
                offHandTimer = 0
                paused = false
                offHandSwingBar:SetSize(defaults.iconWidth * stagedScale, defaults.barHeight * stagedScale)
                offHandSwingBar.texture:SetHeight(defaults.barHeight * stagedScale)
                offHandSwingBar.texture:SetColorTexture(defaults.color.r, defaults.color.g, defaults.color.b)
                offHandSwingBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize*stagedScale, "OUTLINE")
                offHandSwingBar:Show()
            end

            local function StopOffhandSwing()
                ohTimer = ohSpeed
                offhandSwinging = false
                offHandSwingBar.texture:SetHeight(0)
                offHandSwingBar:Hide()
            end


            offHandSwingBar:SetScript("OnUpdate", function(self, elapsed)     
                if paused then return end

                offHandTimer = offHandTimer + elapsed

                if offhandSwinging then
                    if offHandTimer >= offHandMaxTime then
                        if not UnitAffectingCombat("player") then
                            self:Hide()
                        else
                            offHandSwingBar.texture:SetHeight(0)
                            offHandSwingBar.text:SetText(string.format("%.2f", offHandSpeed))
                        end
                    else
                        local remaining = offHandMaxTime - offHandTimer
                        local progress = remaining / offHandMaxTime
                        offHandSwingBar.texture:SetHeight((defaults.barHeight * stagedScale) * progress)
                        offHandSwingBar.text:SetText(string.format("%.2f", remaining))
                    end
                end
            end)
        
        -- === ENEMY HEALTH BAR ===

            enemyHealthBar = CreateFrame("Frame", "SwingTimerEnemyHealthBar", UIParent)
            enemyHealthBar:SetSize(defaults.iconWidth * stagedScale, defaults.barHeight * stagedScale)
            enemyHealthBar:SetPoint("RIGHT", mainHandSwingBar, "LEFT", -defaults.space * stagedScale, 0) -- Left side of enemy health bar
            enemyHealthBar:Hide()

            -- Backdrop for visibility
            enemyHealthBar.bg = enemyHealthBar:CreateTexture(nil, "BACKGROUND")
            enemyHealthBar.bg:SetAllPoints(true)
            enemyHealthBar.bg:SetColorTexture(0, 0, 0, 0.2)

            -- Create a enemyHealthBar to act as border container
            enemyHealthBar.border = CreateFrame("Frame", nil, enemyHealthBar, "BackdropTemplate")
            enemyHealthBar.border:SetPoint("TOPLEFT", enemyHealthBar, "TOPLEFT", -1 * stagedScale, 1 * stagedScale)
            enemyHealthBar.border:SetPoint("BOTTOMRIGHT", enemyHealthBar, "BOTTOMRIGHT", 1 * stagedScale, -1 * stagedScale)

            enemyHealthBar.border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10 * stagedScale
            })
            enemyHealthBar.border:SetBackdropBorderColor(1, 1, 1)

            -- Health texture (fills vertically)
            enemyHealthBar.texture = enemyHealthBar:CreateTexture(nil, "ARTWORK")
            enemyHealthBar.texture:SetColorTexture(0, 1, 0, 1) -- default green
            enemyHealthBar.texture:SetPoint("BOTTOM", enemyHealthBar, "BOTTOM", -2, 1)
            enemyHealthBar.texture:SetPoint("LEFT", enemyHealthBar, "LEFT", 2, -2)
            enemyHealthBar.texture:SetPoint("RIGHT", enemyHealthBar, "RIGHT", -2, 2)
            enemyHealthBar.texture:SetHeight(0)

            -- Position text below the bar
            enemyHealthBar.text = enemyHealthBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            enemyHealthBar.text:ClearAllPoints()
            enemyHealthBar.text:SetPoint("TOP", enemyHealthBar, "BOTTOM", 0 + stagedScale, -defaults.space * stagedScale)
            enemyHealthBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * stagedScale, "OUTLINE")
            enemyHealthBar.text:SetText(string.format("%d%%", 0))

            -- Update function
            local function UpdateEnemyHealth()
                if not UnitAffectingCombat("player") then return end

                if UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target") then
                    local hp, maxHp = UnitHealth("target"), UnitHealthMax("target")
                    local percent = 0
                    if maxHp > 0 then
                        percent = hp / maxHp
                    end

                    -- Update texture height
                    local height = enemyHealthBar:GetHeight() * percent
                    enemyHealthBar.texture:SetSize(enemyHealthBar:GetWidth(), height)

                    -- Update percenatege under the bar
                    enemyHealthBar.text:SetText(string.format("%d%%", math.floor((percent*100)+0.5)))

                    -- Reposition so it drains downward
                    enemyHealthBar.texture:ClearAllPoints()
                    enemyHealthBar.texture:SetPoint("BOTTOM", enemyHealthBar, "BOTTOM", -2, 1)
                    enemyHealthBar.texture:SetPoint("LEFT", enemyHealthBar, "LEFT", 2, -2)
                    enemyHealthBar.texture:SetPoint("RIGHT", enemyHealthBar, "RIGHT", -2, 2)

                    -- Class color if target is player
                    if UnitIsPlayer("target") then
                        local _, class = UnitClass("target")
                        local color = RAID_CLASS_COLORS[class]
                        if color then
                            enemyHealthBar.texture:SetColorTexture(color.r, color.g, color.b, 1)
                        end
                    else
                        enemyHealthBar.texture:SetColorTexture(0, 1, 0, 1) -- green for NPC
                    end

                    enemyHealthBar:Show()
                else
                    enemyHealthBar.text:SetText(string.format("%d%%", 0))
                    enemyHealthBar:Hide()
                end
            end

            -- Events
            enemyHealthBar:RegisterEvent("UNIT_HEALTH")
            enemyHealthBar:RegisterEvent("UNIT_MAXHEALTH")
            enemyHealthBar:RegisterEvent("PLAYER_TARGET_CHANGED")
            enemyHealthBar:SetScript("OnEvent", function(_, event, unit)
                if event == "PLAYER_TARGET_CHANGED" or unit == "target" then
                    UpdateEnemyHealth()
                end
            end)

        -- === DEBUFF BAR ===

            debuffBar = CreateFrame("Frame", "SwingTimerDebuffBar", mainHandSwingBar)
            debuffBar:SetSize(defaults.iconWidth * stagedScale, defaults.barHeight * stagedScale)
            debuffBar:SetPoint("RIGHT", enemyHealthBar, "LEFT", -defaults.space * stagedScale, 0) -- Left side of enemy health bar
            debuffBar:SetAlpha(stagedOpacity)
            debuffBar.icons = {}

            local function UpdateDebuffBar()
                if paused then return end
                if not UnitExists("target") or not UnitCanAttack("player", "target") then
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
                                count = count,
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
                        icon:SetSize(defaults.iconWidth * stagedScale, defaults.iconHeight * stagedScale)
                        icon.texture = icon:CreateTexture(nil, "ARTWORK")
                        icon.texture:SetAllPoints()
                        icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        icon.text:SetPoint("BOTTOM", icon, "BOTTOM", 0 + stagedScale, 1 * stagedScale)
                        icon.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize*stagedScale, "OUTLINE")
                        icon.stackText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        debuffBar.icons[i] = icon
                    end

                    if not i == 6 then
                        icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * ((defaults.iconHeight * stagedScale) + 0)))    
                    else
                        icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * ((defaults.iconHeight * stagedScale) + (1.5 * stagedScale))))
                    end

                    -- Stack count text
                    icon.stackText:SetPoint("RIGHT", icon, "LEFT", -(defaults.fontSize * stagedScale / 2), 0)
                    icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * stagedScale, "OUTLINE")
                    icon.stackText:SetTextColor(1, 1, 1) -- white text

                    if data.count and data.count > 0 then
                        icon.stackText:SetText(data.count)
                    else
                        icon.stackText:SetText("")
                    end

                    -- Icon texture and duration
                    icon.texture:SetTexture(data.icon)
                    icon.text:SetText(string.format("%.1f", data.remaining))
                    icon:Show()
                end

                -- Hide unused icons
                for i = #debuffs + 1, #debuffBar.icons do
                    debuffBar.icons[i]:Hide()
                end
            end

            debuffBar:SetScript("OnUpdate", function(self, elapsed)
                UpdateDebuffBar()
            end)

            local function ShowTemporaryDebuffs()

                for i = 1, 6 do
                    local icon = debuffBar.icons[i]

                    if not icon then
                        icon = CreateFrame("Frame", nil, debuffBar)
                        icon:SetSize(defaults.iconWidth * stagedScale, defaults.iconHeight * stagedScale)
                        icon.texture = icon:CreateTexture(nil, "ARTWORK")
                        icon.texture:SetAllPoints()
                        icon.text = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        icon.text:SetPoint("BOTTOM", icon, "BOTTOM", 0 + stagedScale, 1 * stagedScale)
                        icon.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * stagedScale, "OUTLINE")
                        icon.stackText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        debuffBar.icons[i] = icon
                    end

                    if not i == 6 then
                        icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * ((defaults.iconHeight * stagedScale) + 0)))    
                    else
                        icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * ((defaults.iconHeight * stagedScale) + (1.5 * stagedScale))))
                    end

                    -- Stack count text
                    icon.stackText:SetPoint("RIGHT", icon, "LEFT", -(defaults.fontSize * stagedScale / 2), 0)
                    icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * stagedScale, "OUTLINE")
                    icon.stackText:SetTextColor(1, 1, 1) -- white text
                    icon.stackText:SetText("0")

                    -- Icon texture and duration
                    icon.texture:SetTexture(select(3, GetSpellInfo(772)))
                    icon.text:SetText(string.format("%.1f", 0))
                    icon:Show()
                end
            end

        -- === RESOURCE BAR ===

            resourceBar = CreateFrame("StatusBar", nil, mainHandSwingBar)
            resourceBar:SetSize((defaults.iconWidth * 3 + defaults.space * 2) * stagedScale, defaults.iconHeight / 2 * stagedScale)
            resourceBar:SetPoint("TOP", mainHandSwingBar.text, "BOTTOM", 0, -defaults.space * stagedScale)
            resourceBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
            resourceBar:SetMinMaxValues(0, maxPower)
            resourceBar:SetValue(currentPower)
            resourceBar:SetAlpha(stagedOpacity)
            resourceBar:SetOrientation("HORIZONTAL")

            if powerType == 0 then
                resourceBar:SetStatusBarColor(0, 0, 1) -- blue
            elseif powerType == 1 then
                resourceBar:SetStatusBarColor(1, 0, 0) -- red
            elseif powerType == 3 then
                resourceBar:SetStatusBarColor(1, 1, 0) -- yellow
            end

            -- Backdrop for visibility
            resourceBar.bg = resourceBar:CreateTexture(nil, "BACKGROUND")
            resourceBar.bg:SetAllPoints(true)
            resourceBar.bg:SetColorTexture(0, 0, 0, 0.2)

            -- Border
            resourceBar.border = CreateFrame("Frame", nil, resourceBar, BackdropTemplateMixin and "BackdropTemplate")
            resourceBar.border:SetPoint("TOPLEFT", resourceBar, "TOPLEFT", -1 * stagedScale , 1 * stagedScale)
            resourceBar.border:SetPoint("BOTTOMRIGHT", resourceBar, "BOTTOMRIGHT", 1 * stagedScale, -1 * stagedScale)
            resourceBar.border:SetBackdrop({
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10 * stagedScale,
            })
            resourceBar.border:SetBackdropBorderColor(1, 1, 1) -- white border

            -- Position text below the bar
            resourceBar.text = mainHandSwingBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            resourceBar.text:ClearAllPoints()
            resourceBar.text:SetPoint("TOP", resourceBar, "BOTTOM", 0, -defaults.space*stagedScale)
            resourceBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize*stagedScale, "OUTLINE")
            resourceBar.text:SetText(string.format("%d / %d", currentPower, maxPower))
            
            -- Update function
            local function UpdateResourceBar()
                currentPower = UnitPower("player", powerType)
                maxPower = UnitPowerMax("player", powerType)
                resourceBar.text:SetText(string.format("%d / %d", currentPower, maxPower))
                resourceBar:SetValue(currentPower)
            end

            -- Event handler
            local function OnEvent(self, event, unit)
                if paused then return end
                if unit ~= "player" then return end
                powerType = UnitPowerType("player")
                currentPower = UnitPower("player", powerType)
                maxPower = UnitPowerMax("player", powerType)
                resourceBar:SetMinMaxValues(0, maxPower)
                UpdateResourceBar()
            end

            resourceBar:SetScript("OnEvent", OnEvent)
            resourceBar:RegisterEvent("PLAYER_ENTERING_WORLD")
            resourceBar:RegisterEvent("UNIT_DISPLAYPOWER")
            resourceBar:RegisterEvent("UNIT_POWER_UPDATE")

            -- Initialize
            UpdateResourceBar()

        -- === EVENT TRACKING ===
            events = CreateFrame("Frame")

            -- Register all relevant events
            events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
            events:RegisterEvent("PLAYER_REGEN_DISABLED")
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

                        if spellName == "Throw" then return end

                        if swingReplacingSpells[spellName] then
                            queuedSpellName = spellName
                            queuedSpellTexture = select(3, GetSpellInfo(spellID))
                            mainHandSwingBar.icon:SetTexture(queuedSpellTexture)
                            mainHandSwingBar.icon:Show()
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

                        if spellName == "Throw" then return end

                        if swingReplacingSpells[spellName] then
                            queuedSpellName = spellName
                            queuedSpellTexture = select(3, GetSpellInfo(spellID))
                            mainHandSwingBar.icon:SetTexture(queuedSpellTexture)
                            mainHandSwingBar.icon:Show()
                            isQueuedSpellActive = true
                        end
                        UpdateDebuffBar()
                    end

                elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                    
                    local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, _, _, _, _, _, _, _, isOffHand = CombatLogGetCurrentEventInfo()

                    if sourceGUID == UnitGUID("player") then

                        if subevent == "SWING_DAMAGE" then

                            local timestamp, subEvent, hideCaster,
                            sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
                            destGUID, destName, destFlags, destRaidFlags,
                            amount,        -- damage done
                            overkill,      -- excess damage (can be -1 if none)
                            school,        -- damage school (1 = physical, 4 = fire, etc.)
                            resisted,      -- damage resisted
                            blocked,       -- damage blocked
                            absorbed,      -- damage absorbed
                            critical,      -- true if crit
                            glancing,      -- true if glancing blow
                            crushing,      -- true if crushing blow
                            isOffHand      -- true if this was an off-hand swing
                            = CombatLogGetCurrentEventInfo()

                            if not UnitExists("target") or not UnitCanAttack("player", "target") then return end

                            local spellName = GetSpellInfo(spellID)
                            if spellName == "Throw" then return end

                            queuedSpellName = nil
                            queuedSpellTexture = nil
                            mainHandSwingBar.icon:Hide()
                            isQueuedSpellActive = false

                            local speedMain, speedOff = UnitAttackSpeed("player")

                            if speedMain and isOffHand == false then
                                StartSwingTimer()
                            end

                            if speedOff and isOffHand == true then
                                StartOffhandSwing()
                            end
                            
                        
                        elseif subevent == "SWING_MISSED" then

                            local timestamp, subEvent, hideCaster,
                            sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
                            destGUID, destName, destFlags, destRaidFlags,
                            missType,      -- "DODGE", "PARRY", "MISS", "BLOCK", etc.
                            isOffHand,     -- true if this was an off-hand swing
                            amountMissed   -- only set for "BLOCK" or "ABSORB"
                            = CombatLogGetCurrentEventInfo()

                            if not UnitExists("target") or not UnitCanAttack("player", "target") then return end

                            local spellName = GetSpellInfo(spellID)
                            if spellName == "Throw" then return end

                            queuedSpellName = nil
                            queuedSpellTexture = nil
                            mainHandSwingBar.icon:Hide()
                            isQueuedSpellActive = false

                            local speedMain, speedOff = UnitAttackSpeed("player")

                            if speedMain and isOffHand == false then
                                StartSwingTimer()
                            end

                            if speedOff and isOffHand == true then
                                StartOffhandSwing()
                            end


                        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" then

                            if not UnitExists("target") or not UnitCanAttack("player", "target") then return end

                            local spellName = GetSpellInfo(spellID)
                            if spellName == "Throw" then return end

                            if swingReplacingSpells[spellName] then
                                queuedSpellName = nil
                                queuedSpellTexture = nil
                                mainHandSwingBar.icon:Hide()
                                isQueuedSpellActive = false

                                StartSwingTimer()
                            else
                                -- Do nothing: a non-swing-replacing spell like Rend was used
                            end
                        
                        elseif subevent == "PARTY_KILL" then
                            local destGUID = select(8, CombatLogGetCurrentEventInfo())

                            local spellName = GetSpellInfo(spellID)
                            if spellName == "Throw" then return end

                            if destGUID == UnitGUID("target") then
                                if UnitAffectingCombat("player") then return end
                                HideBar()
                                queuedSpellName = nil
                                queuedSpellTexture = nil
                                mainHandSwingBar.icon:Hide()
                                isQueuedSpellActive = false
                            end
                        end
                        UpdateDebuffBar()
                    end
                
                -- Player is out of combat
                elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
                    mainHandMaxTime=0
                    offHandMaxTime=0
                    mainHandSwingBar:Hide()
                    mainHandSwingBar.icon:Hide()
                    queuedSpellName = nil
                    queuedSpellTexture = nil
                    isQueuedSpellActive = false
                    UpdateResourceBar()
                    UpdateDebuffBar()

                -- Player is in combat    
                elseif event == "PLAYER_REGEN_DISABLED" then
                    if not UnitExists("target") or not UnitCanAttack("player", "target") then return end
                    paused=false
                    settings:Hide()
                    mainHandSwingBar.text:SetText(string.format("%.2f", mainHandSpeed))
                    UpdateResourceBar()
                    UpdateDebuffBar()
                    UpdateEnemyHealth()
                    mainHandSwingBar:Show()
                    enemyHealthBar:Show()
                    if stagedShowOffHandSwingBar and offHandWeaponEquipped then
                        mainHandSwingBar.text:SetText(string.format("%.2f", offHandSpeed))
                        offHandSwingBar:Show()
                    end
                    resourceBar:Show()

                elseif event == "PLAYER_TARGET_CHANGED" then
                    if not UnitAffectingCombat("player") then
                        -- Player not in combat, ignore target changes
                        return
                    elseif not UnitExists("target") then
                        HideBar()
                        queuedSpellName = nil
                        queuedSpellTexture = nil
                        mainHandSwingBar.icon:Hide()
                        isQueuedSpellActive = false
                    elseif UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
                        -- New hostile target — reset timer
                        mainHandMaxTime=0
                        offHandMaxTime=0
                        --HideBar()
                    end
                    UpdateDebuffBar()
                end
            end)

        -- === SETTINGS PANEL ===

            local function ShowPausedBar()
                local speed = UnitAttackSpeed("player") or 1
                mainHandMaxTime = speed
                mainHandTimer = 0
                paused = true
                mainHandSwingBar:SetSize(defaults.iconWidth * stagedScale, defaults.barHeight * stagedScale)
                mainHandSwingBar.texture:SetHeight((defaults.barHeight / 2) * stagedScale)
                mainHandSwingBar.text:SetText(string.format("%.2f", mainHandSpeed))
                mainHandSwingBar.icon:SetTexture(select(3, GetSpellInfo(78)))
                mainHandSwingBar.icon:Show()
                mainHandSwingBar:Show()
                enemyHealthBar:SetSize(defaults.iconWidth * stagedScale, defaults.barHeight * stagedScale)
                enemyHealthBar.texture:SetHeight((defaults.barHeight / 2) * stagedScale)
                enemyHealthBar.text:SetText(string.format("%d%%", 50))
                enemyHealthBar:Show()
                resourceBar:SetMinMaxValues(0,100)
                resourceBar.text:SetText(string.format("%d / %d", 0, 100))
                resourceBar:SetValue(50)
                resourceBar:Show()
                ShowTemporaryDebuffs()
                if(stagedShowOffHandSwingBar and offHandWeaponEquipped) then
                    offHandSwingBar.texture:SetHeight((defaults.barHeight / 2) * stagedScale)
                    offHandSwingBar.text:SetText(string.format("%.2f", offHandSpeed))
                    offHandSwingBar:Show()
                end
            end

            local function ReloadOpacity(opacityVal)
                mainHandSwingBar:SetAlpha(opacityVal)
                offHandSwingBar:SetAlpha(opacityVal)
                enemyHealthBar:SetAlpha(opacityVal)
                debuffBar:SetAlpha(opacityVal)
                resourceBar:SetAlpha(opacityVal)
            end

            -- Frame for prevent mouse and keys actions on the background
            local modalFrame = CreateFrame("Frame", "MyAddonModal", UIParent)
            modalFrame:SetAllPoints(UIParent)  -- covers whole screen
            modalFrame:EnableMouse(true)       -- capture mouse events
            modalFrame:SetFrameStrata("FULLSCREEN_DIALOG") -- topmost layer
            modalFrame:Hide()

            -- Settings Frame
            settings = CreateFrame("Frame", "SwingTimerSettingsFrame", modalFrame, "BasicFrameTemplateWithInset")
            settings:SetSize(300, 235)
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

            -- Bar Opacity Slider
            local opacitySlider = CreateFrame("Slider", "SwingTimerBarOpacitySlider", settings, "OptionsSliderTemplate")
            opacitySlider:SetWidth(250)
            opacitySlider:SetMinMaxValues(0.5, 1)
            opacitySlider:SetValueStep(0.01)
            opacitySlider:SetObeyStepOnDrag(true)
            opacitySlider:SetPoint("TOP", settings, "TOP", 0, -50)
            _G[opacitySlider:GetName() .. "Low"]:ClearAllPoints()
            _G[opacitySlider:GetName() .. "Low"]:SetPoint("BOTTOMLEFT", opacitySlider, "TOP", -(opacitySlider:GetWidth()/2)+5, -30)
            _G[opacitySlider:GetName() .. "Low"]:SetText("50%")
            
            _G[opacitySlider:GetName() .. "High"]:ClearAllPoints()
            _G[opacitySlider:GetName() .. "High"]:SetPoint("BOTTOMRIGHT", opacitySlider, "TOP", (opacitySlider:GetWidth()/2), -30)
            _G[opacitySlider:GetName() .. "High"]:SetText("100%")
            
            _G[opacitySlider:GetName() .. "Text"]:SetText("Opacity")

            opacitySlider:SetValue(stagedOpacity)

            opacitySlider:SetScript("OnValueChanged", function(self, value)
                settingsTemporaryValues.opacity = value
                ReloadOpacity(settingsTemporaryValues.opacity)
            end)

            -- Scale Slider
            local scaleSlider = CreateFrame("Slider", "SwingTimerScaleSlider", settings, "OptionsSliderTemplate")
            scaleSlider:SetWidth(250)
            scaleSlider:SetMinMaxValues(1, 2.0)
            scaleSlider:SetValueStep(0.1)
            scaleSlider:SetObeyStepOnDrag(true)
            scaleSlider:SetPoint("TOP", settings, "TOP", 0, -95)
            
            _G[scaleSlider:GetName() .. "Low"]:ClearAllPoints()
            _G[scaleSlider:GetName() .. "Low"]:SetPoint("BOTTOMLEFT", scaleSlider, "TOP", -(scaleSlider:GetWidth()/2)+5, -30)
            _G[scaleSlider:GetName() .. "Low"]:SetText("1")
            
            _G[scaleSlider:GetName() .. "High"]:ClearAllPoints()
            _G[scaleSlider:GetName() .. "High"]:SetPoint("BOTTOMRIGHT", scaleSlider, "TOP", (scaleSlider:GetWidth()/2)-5, -30)
            _G[scaleSlider:GetName() .. "High"]:SetText("2.0")
            
            _G[scaleSlider:GetName() .. "Text"]:SetText("Scale")

            scaleSlider:SetValue(stagedScale)

            scaleSlider:SetScript("OnValueChanged", function(self, value)
                
                -- Components scale change when slider value is changed 

                settingsTemporaryValues.scale = value
                
                mainHandSwingBar:SetSize((defaults.iconWidth * settingsTemporaryValues.scale), (defaults.barHeight * settingsTemporaryValues.scale))
                
                mainHandSwingBar.texture:SetHeight((defaults.barHeight / 2) * settingsTemporaryValues.scale)

                mainHandSwingBar.border:SetPoint("TOPLEFT", mainHandSwingBar, "TOPLEFT", -1 * settingsTemporaryValues.scale, 1 * settingsTemporaryValues.scale)
                mainHandSwingBar.border:SetPoint("BOTTOMRIGHT", mainHandSwingBar, "BOTTOMRIGHT", 1 * settingsTemporaryValues.scale, -1 * settingsTemporaryValues.scale)
                mainHandSwingBar.border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 * settingsTemporaryValues.scale})
                
                mainHandSwingBar.icon:SetSize(defaults.iconWidth * settingsTemporaryValues.scale, defaults.iconHeight*settingsTemporaryValues.scale)
                mainHandSwingBar.icon:SetPoint("BOTTOM", mainHandSwingBar, "TOP", 0, defaults.space * settingsTemporaryValues.scale)

                mainHandSwingBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * settingsTemporaryValues.scale, "OUTLINE")
                mainHandSwingBar.text:SetPoint("TOP", mainHandSwingBar, "BOTTOM", 0, -defaults.space * settingsTemporaryValues.scale)

                offHandSwingBar:SetSize((defaults.iconWidth * settingsTemporaryValues.scale), (defaults.barHeight * settingsTemporaryValues.scale))
                offHandSwingBar:SetPoint("LEFT", mainHandSwingBar, "RIGHT", 0, 0)

                offHandSwingBar.texture:SetHeight((defaults.barHeight / 2) * settingsTemporaryValues.scale)
                
                offHandSwingBar.border:SetPoint("TOPLEFT", offHandSwingBar, "TOPLEFT", -1 * settingsTemporaryValues.scale, 1 * settingsTemporaryValues.scale)
                offHandSwingBar.border:SetPoint("BOTTOMRIGHT", offHandSwingBar, "BOTTOMRIGHT", 1 * settingsTemporaryValues.scale, -1 * settingsTemporaryValues.scale)
                offHandSwingBar.border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 * settingsTemporaryValues.scale})

                offHandSwingBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * settingsTemporaryValues.scale, "OUTLINE")
                offHandSwingBar.text:SetPoint("TOP", offHandSwingBar, "BOTTOM", 0, -defaults.space * settingsTemporaryValues.scale)

                enemyHealthBar:SetSize((defaults.iconWidth * settingsTemporaryValues.scale), (defaults.barHeight * settingsTemporaryValues.scale))
                enemyHealthBar:SetPoint("RIGHT", mainHandSwingBar, "LEFT", -defaults.space * settingsTemporaryValues.scale, 0)

                enemyHealthBar.texture:SetHeight((defaults.barHeight / 2) * settingsTemporaryValues.scale)
                
                enemyHealthBar.border:SetPoint("TOPLEFT", enemyHealthBar, "TOPLEFT", -1 * settingsTemporaryValues.scale, 1 * settingsTemporaryValues.scale)
                enemyHealthBar.border:SetPoint("BOTTOMRIGHT", enemyHealthBar, "BOTTOMRIGHT", 1 * settingsTemporaryValues.scale, -1 * settingsTemporaryValues.scale)
                enemyHealthBar.border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 * settingsTemporaryValues.scale})

                enemyHealthBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * settingsTemporaryValues.scale, "OUTLINE")
                enemyHealthBar.text:SetPoint("TOP", enemyHealthBar, "BOTTOM", 0 + settingsTemporaryValues.scale, -defaults.space * settingsTemporaryValues.scale)
                
                debuffBar:SetSize(defaults.iconWidth * settingsTemporaryValues.scale, defaults.barHeight * settingsTemporaryValues.scale)
                debuffBar:SetPoint("RIGHT", enemyHealthBar, "LEFT", -defaults.space * settingsTemporaryValues.scale, 0)
                
                for i=1, 6 do
                    local icon = debuffBar.icons[i]
                    icon:SetSize(defaults.iconWidth * settingsTemporaryValues.scale, defaults.iconHeight * settingsTemporaryValues.scale)
                    icon.texture:SetAllPoints()
                    if not i == 6 then
                        icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * ((defaults.iconHeight * settingsTemporaryValues.scale) + 0)))    
                    else
                        icon:SetPoint("TOP", debuffBar, "TOP", 0, -((i - 1) * ((defaults.iconHeight * settingsTemporaryValues.scale) + (1.5 * settingsTemporaryValues.scale))))
                    end

                    icon.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * settingsTemporaryValues.scale, "OUTLINE")
                    icon.text:SetPoint("BOTTOM", icon, "BOTTOM", 0 + settingsTemporaryValues.scale, 1 * settingsTemporaryValues.scale)

                    icon.stackText:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * settingsTemporaryValues.scale, "OUTLINE")
                    icon.stackText:SetPoint("RIGHT", icon, "LEFT", -(defaults.fontSize * settingsTemporaryValues.scale / 2), 0)

                    debuffBar.icons[i] = icon
                end

                resourceBar:SetSize((defaults.iconWidth * 3 + defaults.space * 2) * settingsTemporaryValues.scale, defaults.iconHeight / 2 * settingsTemporaryValues.scale)
                resourceBar:SetPoint("TOP", mainHandSwingBar.text, "BOTTOM", 0, -defaults.space * settingsTemporaryValues.scale)

                resourceBar.border:SetPoint("TOPLEFT", resourceBar, "TOPLEFT", -1 * settingsTemporaryValues.scale , 1 * settingsTemporaryValues.scale)
                resourceBar.border:SetPoint("BOTTOMRIGHT", resourceBar, "BOTTOMRIGHT", 1 * settingsTemporaryValues.scale, -1 * settingsTemporaryValues.scale)
                resourceBar.border:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 * settingsTemporaryValues.scale})

                resourceBar.text:SetPoint("TOP", resourceBar, "BOTTOM", 0, -defaults.space * settingsTemporaryValues.scale)
                resourceBar.text:SetFont("Fonts\\FRIZQT__.TTF", defaults.fontSize * settingsTemporaryValues.scale, "OUTLINE")

            end)

            -- Off-Hand Swing Bar Checkbox
            local offhandCheckbox = CreateFrame("CheckButton", "SwingTimer_OffhandCheckbox", settings, "ChatConfigCheckButtonTemplate")
            offhandCheckbox:SetPoint("TOPLEFT", settings, "TOPLEFT", 20, -135)
            offhandCheckbox.Text:SetText("Show Off-Hand Swing Bar")
            offhandCheckbox.tooltip = "Enable or disable the off-hand swing timer bar.\n\nOnly when the off hand weapon is equipped."

            offhandCheckbox:SetChecked(stagedShowOffHandSwingBar)

            function offhandCheckbox:CheckboxChange(isChecked)
                if isChecked then
                    self:SetChecked(true)
                    if offHandWeaponEquipped then offHandSwingBar:Show() end
                else
                    self:SetChecked(false)
                    if offHandWeaponEquipped then offHandSwingBar:Hide() end
                end
            end

            offhandCheckbox:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                settingsTemporaryValues.showOffHandSwingBar = checked
                self:CheckboxChange(checked)
            end)

            -- Load saved values button
            local resetBtn = CreateFrame("Button", nil, settings, "GameMenuButtonTemplate")
            resetBtn:SetPoint("BOTTOMLEFT", settings, "BOTTOMLEFT", 15, 45)
            resetBtn:SetSize(120, 25)
            resetBtn:SetText("Reset")
            resetBtn:SetNormalFontObject("GameFontNormal")
            resetBtn:SetHighlightFontObject("GameFontHighlight")

            resetBtn:SetScript("OnClick", function()

                opacitySlider:SetValue(settingsSessionValues.opacity)
                scaleSlider:SetValue(settingsSessionValues.scale)
                offhandCheckbox:CheckboxChange(settingsSessionValues.showOffHandSwingBar)

            end)

            -- Set default values button
            local defaultBtn = CreateFrame("Button", nil, settings, "GameMenuButtonTemplate")
            defaultBtn:SetPoint("BOTTOMRIGHT", settings, "BOTTOMRIGHT", -15, 45)
            defaultBtn:SetSize(120, 25)
            defaultBtn:SetText("Default")
            defaultBtn:SetNormalFontObject("GameFontNormal")
            defaultBtn:SetHighlightFontObject("GameFontHighlight")

            defaultBtn:SetScript("OnClick", function()

                -- Reset staged to defaults
                settingsTemporaryValues.opacity = defaults.opacity
                settingsTemporaryValues.scale = defaults.scale
                settingsTemporaryValues.showOffHandSwingBar = defaults.showOffHandSwingBar

                offhandCheckbox:CheckboxChange(settingsTemporaryValues.showOffHandSwingBar)
                opacitySlider:SetValue(settingsTemporaryValues.opacity)
                scaleSlider:SetValue(settingsTemporaryValues.scale)

            end)

            -- Apply Button
            local applyBtn = CreateFrame("Button", nil, settings, "GameMenuButtonTemplate")
            applyBtn:SetPoint("BOTTOMLEFT", settings, "BOTTOMLEFT", 15, 15)
            applyBtn:SetSize(270, 25)
            applyBtn:SetText("Apply")
            applyBtn:SetNormalFontObject("GameFontNormal")
            applyBtn:SetHighlightFontObject("GameFontHighlight")

            applyBtn:SetScript("OnClick", function()

                settingsData.opacity = settingsTemporaryValues.opacity
                settingsData.scale = settingsTemporaryValues.scale
                settingsData.showOffHandSwingBar = settingsTemporaryValues.showOffHandSwingBar

                stagedOpacity = settingsTemporaryValues.opacity
                stagedScale = settingsTemporaryValues.scale
                stagedShowOffHandSwingBar = settingsTemporaryValues.showOffHandSwingBar

                settingsSessionValues.opacity = settingsTemporaryValues.opacity
                settingsSessionValues.scale = settingsTemporaryValues.scale
                settingsSessionValues.showOffHandSwingBar = settingsTemporaryValues.showOffHandSwingBar

                -- Save position
                local point, relativeTo, relativePoint, xOfs, yOfs = mainHandSwingBar:GetPoint()
                settingsData.position.x = xOfs or 0
                settingsData.position.y = yOfs or 0

                -- Hide settings
                settings:Hide()

            end)

            local function ShowSwingTimerSettings()
                if InCombatLockdown() then
                    UIErrorsFrame:AddMessage("Cannot open settings while in combat.", 1, 0, 0, 1, 53)
                    return
                end
                modalFrame:Show()
                settings:Show()
                ShowPausedBar()
            end

            SwingTimerSettingsFrame:SetScript("OnHide", function(self)
                modalFrame:Hide()
                HideBar()
            end)

            -- Slash command to toggle settings
            SLASH_SWINGTIMER1 = "/swingtimer"
            SlashCmdList["SWINGTIMER"] = function()
                if settings:IsShown() then
                    modalFrame:Hide()
                    settings:Hide()
                else
                    
                    -- Set temporary values for opened season

                    settingsTemporaryValues = {
                        opacity = stagedOpacity,
                        scale = stagedScale,
                        showOffHandSwingBar = stagedShowOffHandSwingBar
                    }

                    settingsSessionValues = {
                        opacity = stagedOpacity,
                        scale = stagedScale,
                        showOffHandSwingBar = stagedShowOffHandSwingBar
                    }

                    -- Update sliders to staged values before showing
                    opacitySlider:SetValue(stagedOpacity)
                    scaleSlider:SetValue(stagedScale)
                    -- Show settings and show bar fully loaded and paused
                    ShowSwingTimerSettings()
                end
            end

            -- Add settings to UISpecialFrames to be closed on ESC press
            tinsert(UISpecialFrames, settings:GetName())
            tinsert(UISpecialFrames, modalFrame:GetName())

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


