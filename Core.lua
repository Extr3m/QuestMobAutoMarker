---@diagnostic disable: undefined-global

local addonName, addon = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("QUEST_LOG_UPDATE")

local currentMarkerIndex = 1
local markedGUIDs = {}
local lastProcessedGUID = nil

-- Common quest objective filler words to strip out
local STRIP_PATTERNS = {
    -- Verbs and prefixes
    "^Kill%s+", "^Slay%s+", "^Defeat%s+", "^Collect%s+", "^Obtain%s+", "^Bring%s+",
    -- Suffixes and progress indicators
    "%s+slain$", "%s+killed$", "%s+defeated$",
    "'s%s+Head$", "'s%s+Claw$", "'s%s+Heart$", "'s%s+Tusk$", "'s%s+Horn$",
    "%s*:%s*%d+/%d+$", -- Removes ": 0/1" style progress counters
}

function addon.ResetMarkerIndex()
    currentMarkerIndex = 1
    lastProcessedGUID = nil
end

local activeNpcCache = {}

-- Safely retrieve Questie modules through QuestieLoader or global scope
local function GetQuestieModule(moduleName)
    if QuestieLoader and QuestieLoader.ImportModule then
        local success, module = pcall(QuestieLoader.ImportModule, QuestieLoader, moduleName)
        if success and module then return module end
    end
    return _G[moduleName]
end

-- Register NPC ID into cache
local function RegisterNpcId(npcId)
    local id = tonumber(npcId)
    if id and id > 0 then
        activeNpcCache[id] = true
    end
end

-- Rebuild quest mob cache using Questie's active quest log
local function RebuildQuestNpcCache()
    wipe(activeNpcCache)

    local QuestiePlayer = GetQuestieModule("QuestiePlayer")
    local QuestieDB = GetQuestieModule("QuestieDB")

    if not QuestiePlayer or not QuestiePlayer.currentQuestlog then return end

    for questId, quest in pairs(QuestiePlayer.currentQuestlog) do
        if quest then
            local objectives = quest.Objectives or quest.ObjectiveData or quest.objectives
            if type(objectives) == "table" then
                for _, objective in pairs(objectives) do
                    -- Check boolean completion status
                    local isCompleted = objective.Completed or objective.completed

                    -- Explicitly verify numeric objective progress (e.g., 4/4)
                    if not isCompleted and objective.Needed and objective.Collected then
                        local needed = tonumber(objective.Needed)
                        local collected = tonumber(objective.Collected)
                        if needed and collected and needed > 0 and collected >= needed then
                            isCompleted = true
                        end
                    end

                    if isCompleted == nil and objective.IsComplete then
                        isCompleted = objective:IsComplete()
                    end

                    -- Only register unfinished objectives into the active cache
                    if not isCompleted then
                        local objType = objective.Type or objective.type
                        local objId = objective.Id or objective.id

                        -- 1. Direct Kill Objectives
                        if objType == "monster" then
                            RegisterNpcId(objId)

                            -- Register secondary spawn IDs for this monster
                            if type(objective.spawnList) == "table" then
                                for spawnNpcId, _ in pairs(objective.spawnList) do
                                    RegisterNpcId(spawnNpcId)
                                end
                            end

                            if type(objective.monsterList) == "table" then
                                for k, v in pairs(objective.monsterList) do
                                    RegisterNpcId(v)
                                    RegisterNpcId(k)
                                end
                            end
                        end

                        -- 2. Item/Loot Objectives
                        if objType == "item" and objId then
                            local itemData = nil
                            if QuestieDB and QuestieDB.GetItem then
                                itemData = QuestieDB:GetItem(objId)
                            elseif QuestieDB and QuestieDB.itemData then
                                itemData = QuestieDB.itemData[objId]
                            end

                            if itemData then
                                local npcDrops = itemData.npcDrops or itemData.NpcDrops
                                if not npcDrops and QuestieDB and QuestieDB.itemKeys then
                                    local dropKey = QuestieDB.itemKeys.npcDrops or 2
                                    npcDrops = itemData[dropKey]
                                elseif not npcDrops and type(itemData) == "table" then
                                    npcDrops = itemData[2]
                                end

                                if type(npcDrops) == "table" then
                                    for _, dropNpcId in ipairs(npcDrops) do
                                        RegisterNpcId(dropNpcId)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Checks if targeted NPC is an active, incomplete quest target
local function IsActiveQuestieMob(unit, guid, npcId)
    -- Fast $O(1)$ Cache Lookup (Strictly controlled by RebuildQuestNpcCache)
    if npcId and activeNpcCache[npcId] then
        return true
    end
    return false
end

-- Extract NPC ID directly from unit GUID
local function GetNpcIdFromGUID(guid)
    if not guid then return nil end
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if (unitType == "Creature" or unitType == "Vehicle") and npcId then
        return tonumber(npcId)
    end
    return nil
end

-- Evaluation and marking logic
local function EvaluateAndMarkUnit(unit)
    if QuestMobAutoMarkerDB and not QuestMobAutoMarkerDB.enabled then return end

    if QuestMobAutoMarkerDB.disableInCombat and UnitAffectingCombat("player") then return end

    if QuestMobAutoMarkerDB.disableInInstances then
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "party" or instanceType == "raid") then return end
    end

    if QuestMobAutoMarkerDB.disableInParty and (IsInGroup() or IsInRaid()) then return end

    if not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then return end

    local guid = UnitGUID(unit)
    if not guid or guid == lastProcessedGUID then return end

    -- Skip if unit already has a raid target icon
    if GetRaidTargetIndex(unit) ~= nil then
        markedGUIDs[guid] = true
        lastProcessedGUID = guid
        return
    end

    local activeMarkers = addon.Config.GetActiveMarkers()
    if #activeMarkers == 0 then return end

    local npcId = GetNpcIdFromGUID(guid)
    if IsActiveQuestieMob(unit, guid, npcId) then
        lastProcessedGUID = guid

        if currentMarkerIndex > #activeMarkers then
            currentMarkerIndex = 1
        end

        local selectedMarker = activeMarkers[currentMarkerIndex]
        SetRaidTarget(unit, selectedMarker)
        markedGUIDs[guid] = true

        currentMarkerIndex = (currentMarkerIndex % #activeMarkers) + 1
    end
end

-- Clear marker tracking on mob death
local function HandleUnitDeath()
    local _, subEvent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()

    if subEvent == "UNIT_DIED" and destGUID then
        markedGUIDs[destGUID] = nil

        if destGUID == lastProcessedGUID then
            lastProcessedGUID = nil
        end

        if UnitGUID("target") == destGUID then
            SetRaidTarget("target", 0)
        elseif UnitGUID("mouseover") == destGUID then
            SetRaidTarget("mouseover", 0)
        end
    end
end

-- Boss / Rare Scanning Ticker
local scannerTicker = nil

local function CheckAndMarkBossUnit(unit)
    if not UnitExists(unit) or UnitIsDead(unit) then return false end

    local targetName = QuestMobAutoMarkerDB.bossTargetName
    if not targetName or targetName == "" then return false end

    -- Case-insensitive match check
    local unitName = UnitName(unit)
    if unitName and unitName:lower():find(targetName:lower(), 1, true) then
        local markerID = QuestMobAutoMarkerDB.bossTargetMarker or 8
        
        -- Mark if it doesn't already have this marker applied
        if GetRaidTargetIndex(unit) ~= markerID then
            SetRaidTarget(unit, markerID)
            return true
        end
    end
    return false
end

local function ScanForBossTarget()
    -- Guard checks
    if not QuestMobAutoMarkerDB or not QuestMobAutoMarkerDB.bossTargetEnabled then return end
    if not QuestMobAutoMarkerDB.bossTargetName or QuestMobAutoMarkerDB.bossTargetName == "" then return end

    -- Check current Target, Focus, Mouseover
    if CheckAndMarkBossUnit("target") then return end
    if CheckAndMarkBossUnit("focus") then return end
    if CheckAndMarkBossUnit("mouseover") then return end

    -- Check active visible Nameplates
    local nameplates = C_NamePlate.GetNamePlates()
    for _, nameplate in ipairs(nameplates) do
        local unit = nameplate.namePlateUnitToken or (nameplate.UnitFrame and nameplate.UnitFrame["unit"])
        if unit then
            if CheckAndMarkBossUnit(unit) then return end
        end
    end
end

-- Start a light ticker running every 0.5 seconds
local function StartBossScanner()
    if not scannerTicker then
        scannerTicker = C_Timer.NewTicker(0.5, ScanForBossTarget)
    end
end

StartBossScanner()

local function CleanMobNameFromObjective(text)
    if type(text) ~= "string" or text == "" then return nil end
    
    local cleanText = text
    
    -- Strip progress counters like ": 0/1" or " 0/1"
    cleanText = cleanText:gsub("%s*:%s*%d+/%d+$", "")
    cleanText = cleanText:gsub("%s+%d+/%d+$", "")
    
    -- Strip common verbs and suffixes
    for _, pattern in ipairs(STRIP_PATTERNS) do
        cleanText = cleanText:gsub(pattern, "")
    end
    
    -- Trim trailing/leading whitespace
    cleanText = cleanText:match("^%s*(.-)%s*$")
    
    return (cleanText and cleanText ~= "") and cleanText or nil
end

function addon.GetAutoBossTargetFromQuestLog()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then return nil end

    local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
    if numEntries == 0 then return nil end
    
    for i = 1, numEntries do
        local questInfo = C_QuestLog.GetInfo(i)
        if questInfo and not questInfo.isHeader and questInfo.questID then
            local objectives = C_QuestLog.GetQuestObjectives(questInfo.questID)
            
            if type(objectives) == "table" then
                for _, obj in ipairs(objectives) do
                    if obj and not obj.finished and type(obj.text) == "string" and obj.text ~= "" then
                        local extractedName = CleanMobNameFromObjective(obj.text)
                        if extractedName then
                            return extractedName
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Minimap Icon Integration using LibDBIcon
local LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)

if LDB and LDBIcon then
    local minimapBroker = LDB:NewDataObject("QuestMobAutoMarkerForever", {
        type = "data source",
        text = "QuestMobAutoMarkerForever",
        icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
        OnClick = function(self, button)
            if button == "LeftButton" then
                if QuestMobAutoMarkerConfigFrame then
                    if QuestMobAutoMarkerConfigFrame:IsShown() then
                        QuestMobAutoMarkerConfigFrame:Hide()
                    else
                        if type(ToggleConfigWindow) == "function" then
                            ToggleConfigWindow()
                        else
                            QuestMobAutoMarkerConfigFrame:Show()
                        end
                    end
                end
            elseif button == "RightButton" then
                if QuestMobAutoMarkerDB then
                    QuestMobAutoMarkerDB.enabled = not QuestMobAutoMarkerDB.enabled
                    local status = QuestMobAutoMarkerDB.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
                    print("|cff00ff00[QuestMobAutoMarkerForever]|r Status: " .. status)
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("QuestMobAutoMarkerForever")
            tooltip:AddLine("|cff00ff00Left-Click:|r Toggle Options Panel", 0.8, 0.8, 0.8)
            tooltip:AddLine("|cff00ff00Right-Click:|r Toggle Addon On/Off", 0.8, 0.8, 0.8)
        end,
    })

    -- Register after saved variables load safely
    local minimapFrame = CreateFrame("Frame")
    minimapFrame:RegisterEvent("ADDON_LOADED")
    minimapFrame:SetScript("OnEvent", function(self, event, loadedAddon)
        if loadedAddon == addonName then
            if not QuestMobAutoMarkerDB then
                QuestMobAutoMarkerDB = {}
            end
            if not QuestMobAutoMarkerDB.minimap then
                QuestMobAutoMarkerDB.minimap = { hide = false }
            end
            LDBIcon:Register("QuestMobAutoMarkerForever", minimapBroker, QuestMobAutoMarkerDB.minimap)
        end
    end)
end

-- Main Event Handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            if not QuestMobAutoMarkerDB then
                QuestMobAutoMarkerDB = addon.Config.defaultDB
            else
                if QuestMobAutoMarkerDB.enabled == nil then
                    QuestMobAutoMarkerDB.enabled = true
                end

                for key, value in pairs(addon.Config.defaultDB) do
                    if key ~= "enabledMarkers" and QuestMobAutoMarkerDB[key] == nil then
                        QuestMobAutoMarkerDB[key] = value
                    end
                end
                
                for k, v in pairs(addon.Config.defaultDB.enabledMarkers) do
                    if QuestMobAutoMarkerDB.enabledMarkers[k] == nil then
                        QuestMobAutoMarkerDB.enabledMarkers[k] = v
                    end
                end
            end

            -- Allow Questie to initialize before building cache
            if C_Timer and C_Timer.After then
                C_Timer.After(3, RebuildQuestNpcCache)
            else
                RebuildQuestNpcCache()
            end

            print("|cFF00FF00[QuestMobAutoMarker]|r Loaded! Type |cFFFFD100/automark|r or |cFFFFD100/am|r for options.")
        end
    elseif event == "QUEST_LOG_UPDATE" then
        RebuildQuestNpcCache()
    elseif event == "PLAYER_TARGET_CHANGED" then
        lastProcessedGUID = nil
        EvaluateAndMarkUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        EvaluateAndMarkUnit("mouseover")
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleUnitDeath()
    end
end)

SLASH_QUESTMOBAUTOMARKER1 = "/qmamdebug"
SlashCmdList["QUESTMOBAUTOMARKER"] = function()
    RebuildQuestNpcCache()
    local count = 0
    for _ in pairs(activeNpcCache) do count = count + 1 end
    
    local qPlayer = GetQuestieModule("QuestiePlayer") ~= nil
    print(string.format("|cFF00FF00[QMAM Debug]|r Questie Log Access: %s | Cached Mobs: %d", 
        qPlayer and "OK" or "FAIL", count))
end