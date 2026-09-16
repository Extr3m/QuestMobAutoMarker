---@diagnostic disable: undefined-global

local addonName, addon = ...
addon.GUI = {}

-- Main Configuration Window Frame
local configFrame = CreateFrame("Frame", "QuestMobAutoMarkerConfigFrame", UIParent, "DialogBoxFrame")
configFrame:SetSize(460, 480)
configFrame:SetPoint("CENTER")
configFrame:SetMovable(true)
configFrame:EnableMouse(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", configFrame.StartMoving)
configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
configFrame:Hide()

-- Header Title
local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", configFrame, "TOP", 0, -12)
title:SetText("QuestMobAutoMarker")

-- Close Button
local closeBtn = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)

local tabs = {}
local tabPanels = {}
local rightCheckboxes = {}

local function SelectTab(tabIndex)
    for index, panel in ipairs(tabPanels) do
        if index == tabIndex then
            panel:Show()
            PanelTemplates_SelectTab(tabs[index])
        else
            panel:Hide()
            PanelTemplates_DeselectTab(tabs[index])
        end
    end
end

-- Tabs Setup
local tabNames = { "Configuration", "Boss / Rare", "TBD" }

for i, name in ipairs(tabNames) do
    local tab = CreateFrame("Button", "QuestMobAutoMarkerTab" .. i, configFrame, "OptionsFrameTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(name)
    tab:SetScript("OnClick", function(self)
        SelectTab(self:GetID())
    end)

    if i == 1 then
        tab:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 15, -35)
    else
        tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", -5, 0)
    end

    table.insert(tabs, tab)
end

PanelTemplates_SetNumTabs(configFrame, #tabs)

-- TAB 1: CONFIGURATION
local configPanel = CreateFrame("Frame", nil, configFrame)
configPanel:SetSize(420, 350)
configPanel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -70)
table.insert(tabPanels, configPanel)

-- Master Enable Checkbox
local masterCB = CreateFrame("CheckButton", "QMAM_MasterEnable_CB", configPanel, "UICheckButtonTemplate")
masterCB:SetPoint("TOPLEFT", 5, 0)

local masterLabel = masterCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
masterLabel:SetPoint("LEFT", masterCB, "RIGHT", 5, 0)
masterLabel:SetText("Enable Automarking")

masterCB:SetScript("OnClick", function(self)
    if QuestMobAutoMarkerDB then
        QuestMobAutoMarkerDB.enabled = self:GetChecked()
    end
end)

-- Horizontal Separator Line
local line = configPanel:CreateTexture(nil, "ARTWORK")
line:SetSize(420, 1)
line:SetPoint("TOPLEFT", 5, -32)
line:SetColorTexture(0.3, 0.3, 0.3, 0.8)

-- Subheader for Raid Icons
local subheader = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subheader:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 5, -42)
subheader:SetText("Select Active Raid Markers:")

local checkboxes = {}
local topOffset = -62

for _, info in ipairs(addon.Config.MARKER_INFO) do
    local cb = CreateFrame("CheckButton", "QMAM_CB_" .. info.id, configPanel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 5, topOffset)
    
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    label:SetText(info.name)

    local icon = cb:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture(info.icon)
    icon:SetPoint("LEFT", label, "RIGHT", 14, 0)

    cb:SetScript("OnClick", function(self)
        if QuestMobAutoMarkerDB and QuestMobAutoMarkerDB.enabledMarkers then
            QuestMobAutoMarkerDB.enabledMarkers[info.id] = self:GetChecked()
            addon.ResetMarkerIndex()
        end
    end)

    checkboxes[info.id] = cb
    topOffset = topOffset - 35
end

-- Vertical Separator Line
local vertLine = configPanel:CreateTexture(nil, "ARTWORK")
vertLine:SetSize(1, 260)
vertLine:SetPoint("TOPLEFT", 180, -42)
vertLine:SetColorTexture(0.3, 0.3, 0.3, 0.8)

-- Subheader for General Settings
local rightSubheader = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
rightSubheader:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 195, -42)
rightSubheader:SetText("Rules & Conditions:")

-- Right Side Options Definition Table
local rightOptions = {
    { key = "disableInInstances", text = "Disable in Dungeons/Raids" },
    { key = "disableInParty",     text = "Disable in Parties" },
    { key = "disableInCombat",    text = "Disable in Combat" },
}

local rightOffset = -62

for _, opt in ipairs(rightOptions) do
    local cb = CreateFrame("CheckButton", "QMAM_Option_" .. opt.key, configPanel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 195, rightOffset)

    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    label:SetText(opt.text)

    cb:SetScript("OnClick", function(self)
        if QuestMobAutoMarkerDB then
            QuestMobAutoMarkerDB[opt.key] = self:GetChecked()
        end
    end)

    rightCheckboxes[opt.key] = cb
    rightOffset = rightOffset - 32
end

-- TAB 2: TBD PANEL 1
-- TAB 2: BOSS / RARE TARGET PANEL
local tbd1Panel = CreateFrame("Frame", nil, configFrame)
tbd1Panel:SetSize(420, 350)
tbd1Panel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -70)
tbd1Panel:Hide()
table.insert(tabPanels, tbd1Panel)

-- 1. Enable Boss Target Scanner Checkbox
local bossCB = CreateFrame("CheckButton", "QMAM_BossEnable_CB", tbd1Panel, "UICheckButtonTemplate")
bossCB:SetPoint("TOPLEFT", 5, 0)

local bossLabel = bossCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bossLabel:SetPoint("LEFT", bossCB, "RIGHT", 5, 0)
bossLabel:SetText("Enable Priority Boss/Rare Marking")

bossCB:SetScript("OnClick", function(self)
    if QuestMobAutoMarkerDB then
        QuestMobAutoMarkerDB.bossTargetEnabled = self:GetChecked()
    end
end)

-- 2. Target Name Input Box Label
local inputLabel = tbd1Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
inputLabel:SetPoint("TOPLEFT", 5, -45)
inputLabel:SetText("Target Mob Name:")

-- 3. EditBox (Input Field)
local nameInput = CreateFrame("EditBox", "QMAM_BossName_Input", tbd1Panel, "InputBoxTemplate")
nameInput:SetSize(220, 24)
nameInput:SetPoint("TOPLEFT", 10, -65)
nameInput:SetAutoFocus(false)

nameInput:SetScript("OnTextChanged", function(self)
    if QuestMobAutoMarkerDB then
        QuestMobAutoMarkerDB.bossTargetName = self:GetText()
    end
end)
nameInput:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
end)

-- Auto-Detect Button (Matched styling & fixed variable reference)
local autoBtn = CreateFrame("Button", nil, tbd1Panel, "UIPanelButtonTemplate")
autoBtn:SetSize(90, 22)
autoBtn:SetPoint("LEFT", nameInput, "RIGHT", 8, 0)
autoBtn:SetText("Auto-Detect")

autoBtn:SetScript("OnClick", function()
    if type(addon.GetAutoBossTargetFromQuestLog) ~= "function" then
        print("|cffff0000[QuestMobAutoMarker]|r Core logic not loaded yet.")
        return
    end

    local detectedName = addon.GetAutoBossTargetFromQuestLog()
    if detectedName then
        nameInput:SetText(detectedName)
        if QuestMobAutoMarkerDB then
            QuestMobAutoMarkerDB.bossTargetName = detectedName
        end
        print("|cff00ff00[QuestMobAutoMarker]|r Detected target: " .. detectedName)
    else
        print("|cffff0000[QuestMobAutoMarker]|r No target name found in quest log.")
    end
end)

-- 4. Marker Dropdown Selection Label
local dropdownLabel = tbd1Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dropdownLabel:SetPoint("TOPLEFT", 5, -105)
dropdownLabel:SetText("Priority Marker:")

-- 5. Marker Dropdown Menu (Redesigned Native Style)
local markerDropdown = CreateFrame("Button", "QMAM_BossMarker_Dropdown", tbd1Panel, "BackdropTemplate")
markerDropdown:SetSize(170, 24)
markerDropdown:SetPoint("TOPLEFT", 10, -125)
markerDropdown:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
markerDropdown:SetBackdropColor(0, 0, 0, 0.6)
markerDropdown:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

-- Dropdown Button Text
local dropdownText = markerDropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dropdownText:SetPoint("LEFT", markerDropdown, "LEFT", 10, 0)
dropdownText:SetPoint("RIGHT", markerDropdown, "RIGHT", -25, 0)
dropdownText:SetJustifyH("LEFT")

-- Arrow Icon
local arrow = markerDropdown:CreateTexture(nil, "OVERLAY")
arrow:SetSize(16, 16)
arrow:SetPoint("RIGHT", markerDropdown, "RIGHT", -5, 0)
arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

-- Helper to set button text
local function SetDropdownSelectedMarker(markerID)
    for _, info in ipairs(addon.Config.MARKER_INFO) do
        if info.id == markerID then
            dropdownText:SetText(info.name)
            return
        end
    end
end

-- Custom Popout Menu Frame
local dropdownMenuFrame = CreateFrame("Frame", nil, markerDropdown, "BackdropTemplate")
dropdownMenuFrame:SetPoint("TOPLEFT", markerDropdown, "BOTTOMLEFT", 0, -2)
dropdownMenuFrame:SetSize(170, #addon.Config.MARKER_INFO * 22 + 10)
dropdownMenuFrame:SetFrameStrata("DIALOG")
dropdownMenuFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
dropdownMenuFrame:SetBackdropColor(0, 0, 0, 0.95)
dropdownMenuFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
dropdownMenuFrame:Hide()

-- Populate Popout List Items
local yOffset = -5
for _, markerInfo in ipairs(addon.Config.MARKER_INFO) do
    local btn = CreateFrame("Button", nil, dropdownMenuFrame)
    btn:SetSize(160, 20)
    btn:SetPoint("TOPLEFT", dropdownMenuFrame, "TOPLEFT", 5, yOffset)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetTexture(markerInfo.icon)
    icon:SetPoint("RIGHT", btn, "RIGHT", -6, 0)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", btn, "LEFT", 8, 0)
    label:SetText(markerInfo.name)

    -- Hover effect
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0, 0.2) -- Gold highlight on hover

    btn:SetScript("OnClick", function()
        if QuestMobAutoMarkerDB then
            QuestMobAutoMarkerDB.bossTargetMarker = markerInfo.id
        end
        dropdownText:SetText(markerInfo.name)
        dropdownMenuFrame:Hide()
    end)

    yOffset = yOffset - 22
end

markerDropdown:SetScript("OnClick", function()
    if dropdownMenuFrame:IsShown() then
        dropdownMenuFrame:Hide()
    else
        dropdownMenuFrame:Show()
    end
end)

-- TAB 3: TBD PANEL 2
local tbd2Panel = CreateFrame("Frame", nil, configFrame)
tbd2Panel:SetSize(420, 350)
tbd2Panel:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, -70)
tbd2Panel:Hide()
table.insert(tabPanels, tbd2Panel)

local tbd2Text = tbd2Panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
tbd2Text:SetPoint("CENTER", tbd2Panel, "CENTER", 0, 20)
tbd2Text:SetText("TBD")

-- Refresh and Toggle Functions
local function RefreshUI()
    if not QuestMobAutoMarkerDB then return end
    
    masterCB:SetChecked(QuestMobAutoMarkerDB.enabled)
    
    for id, cb in pairs(checkboxes) do
        cb:SetChecked(QuestMobAutoMarkerDB.enabledMarkers[id])
    end

    for key, cb in pairs(rightCheckboxes) do
        if QuestMobAutoMarkerDB[key] ~= nil then
            cb:SetChecked(QuestMobAutoMarkerDB[key])
        end
    end

    -- Refresh Tab 2 Controls
    bossCB:SetChecked(QuestMobAutoMarkerDB.bossTargetEnabled)
    nameInput:SetText(QuestMobAutoMarkerDB.bossTargetName or "")
    SetDropdownSelectedMarker(QuestMobAutoMarkerDB.bossTargetMarker or 8)
end

local function ToggleConfigWindow()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        RefreshUI()
        configFrame:Show()
    end
end

-- Force an initial background refresh so checkboxes match saved variables immediately on login
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    RefreshUI()
    SelectTab(1)
end)

-- Slash Commands Registration
SLASH_AUTOMARK1 = "/automark"
SLASH_AUTOMARK2 = "/am"
SlashCmdList["AUTOMARK"] = ToggleConfigWindow