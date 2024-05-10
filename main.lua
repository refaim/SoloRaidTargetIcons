---@return boolean
local function IsSuperWoWLoaded()
    -- https://github.com/balakethelock/SuperWoW/wiki/Features
    return SetAutoloot ~= nil
end

---@return boolean
local function IsPlayerInPartyOrRaid()
    return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
end

---@return boolean
local function IsOpeningDropdownForTargetUnitFrame()
    local dropdown = getglobal(UIDROPDOWNMENU_INIT_MENU)
    return dropdown ~= nil and dropdown.unit == "target"
end

local function AddPlayerToFakeParty()
    GetNumPartyMembers = function() return 2 end
    IsPartyLeader = function() return true end
end

local Blizzard_GetNumPartyMembers = GetNumPartyMembers
local Blizzard_IsPartyLeader = IsPartyLeader

local function RemovePlayerFromFakeParty()
    GetNumPartyMembers = Blizzard_GetNumPartyMembers
    IsPartyLeader = Blizzard_IsPartyLeader
end

local Blizzard_UnitPopup_HideButtons = UnitPopup_HideButtons
UnitPopup_HideButtons = function()
    if IsSuperWoWLoaded() and IsOpeningDropdownForTargetUnitFrame() and not IsPlayerInPartyOrRaid() then
        AddPlayerToFakeParty()
    end
    Blizzard_UnitPopup_HideButtons()
    RemovePlayerFromFakeParty()
end

-- https://github.com/refaim/Turtle-WoW-UI-Source/blob/d6137c2ebd291f10ce284e586a5733dd5141bef2/Interface/FrameXML/TargetFrame.lua#L665
Blizzard_SetRaidTargetIcon = SetRaidTargetIcon
SetRaidTargetIcon = function(unit, index)
    local cur_index = GetRaidTargetIndex(unit)
    local new_index = index
    if cur_index and cur_index == index then
        new_index = 0
    end

    -- https://github.com/balakethelock/SuperWoW/wiki/Features
    local target_locally = IsSuperWoWLoaded() and not IsPlayerInPartyOrRaid()
    SetRaidTarget(unit, new_index, target_locally);
end
