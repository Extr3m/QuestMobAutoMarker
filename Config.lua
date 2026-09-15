---@diagnostic disable: undefined-global

local addonName, addon = ...
addon.Config = {}

-- Default database settings
addon.Config.defaultDB = {
    enabled = true, -- Master toggle
    disableInInstances = true,
    disableInParty = false,
    disableInCombat = false,
 
    -- New Tab 2 Defaults
    bossTargetEnabled = false,
    bossTargetName = "",
    bossTargetMarker = 8,

    enabledMarkers = {
        [8] = true, -- Skull
        [7] = true, -- Cross
        [6] = true, -- Square
        [5] = true, -- Moon
        [4] = true, -- Triangle
        [3] = true, -- Diamond
        [2] = true, -- Circle
        [1] = true, -- Star
    },

    minimap = {
    hide = false,
    minimapPos = 220,
    },
}

-- Marker definitions for the UI list
addon.Config.MARKER_INFO = {
    { id = 8, name = "Skull", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    { id = 7, name = "Cross", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
    { id = 6, name = "Square", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
    { id = 5, name = "Moon", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
    { id = 4, name = "Triangle", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    { id = 3, name = "Diamond", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
    { id = 2, name = "Circle", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
    { id = 1, name = "Star", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
}

-- Returns an array of active marker IDs
function addon.Config.GetActiveMarkers()
    local active = {}
    if not QuestMobAutoMarkerDB or not QuestMobAutoMarkerDB.enabledMarkers then
        return {8, 7, 6, 5, 4, 3, 2, 1}
    end
    for _, info in ipairs(addon.Config.MARKER_INFO) do
        if QuestMobAutoMarkerDB.enabledMarkers[info.id] then
            table.insert(active, info.id)
        end
    end
    return active
end