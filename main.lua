local _G = _G or getfenv(0)

-- SuperWoW is required. Skip hooking if it's missing.
if _G.SUPERWOW_VERSION == nil then
    DEFAULT_CHAT_FRAME:AddMessage("SoloRaidTargetIcons: SuperWoW is not loaded (or very outdated).")
    return
end

local function IsOpeningDropdownForTargetUnitFrame()
    local dropdown = _G[UIDROPDOWNMENU_INIT_MENU]
    return dropdown ~= nil and dropdown.unit == "target"
end

local Original_GetNumPartyMembers = GetNumPartyMembers
local Original_GetNumRaidMembers = GetNumRaidMembers
local Original_IsPartyLeader = IsPartyLeader

local function FakeParty_GetNumPartyMembers()
    return 2
end

local function FakeParty_IsPartyLeader()
    return true
end

local fakeparty_hooked = false

local function AddPlayerToFakeParty()
    if not fakeparty_hooked then
        _G.GetNumPartyMembers = FakeParty_GetNumPartyMembers
        _G.IsPartyLeader = FakeParty_IsPartyLeader
        fakeparty_hooked = true
    end
end

local function RemovePlayerFromFakeParty()
    if fakeparty_hooked then
        _G.GetNumPartyMembers = Original_GetNumPartyMembers
        _G.IsPartyLeader = Original_IsPartyLeader
        fakeparty_hooked = false
    end
end

-- Checks if we're actually in a party/raid (not a fake party).
local function IsPlayerInPartyOrRaid()
    return Original_GetNumPartyMembers() > 0 or Original_GetNumRaidMembers() > 0
end

-- Briefly hook the party member lookup functions when right-clicking the target
-- unitframe, to fool Blizzard's menu code into displaying the raid target icons.
local Original_UnitPopup_HideButtons = UnitPopup_HideButtons
UnitPopup_HideButtons = function()
    if IsOpeningDropdownForTargetUnitFrame() and not IsPlayerInPartyOrRaid() then
        AddPlayerToFakeParty()
    end
    Original_UnitPopup_HideButtons()
    RemovePlayerFromFakeParty()
end

-- Automatically inject SuperWoW's "local target icon" feature flag when other
-- addons or Blizzard's own code calls it without that argument. That flag makes
-- SuperWoW set a target on the local game client, without syncing it to party
-- members, so we should only auto-inject the flag when we are solo.
--
-- SEE: https://github.com/balakethelock/SuperWoW/wiki/Features
-- "SetRaidTarget now accepts 3rd argument 'local icon' flag to assign a mark
-- to your own client. This allows using target markers while solo."
--
-- NOTE: "SetRaidTarget" is the actual API. Blizzard also uses a wrapper named
-- "SetRaidTargetIcon", which auto-toggles icons off when the same is set twice:
-- https://github.com/refaim/Turtle-WoW-UI-Source/blob/d6137c2ebd291f10ce284e586a5733dd5141bef2/Interface/FrameXML/TargetFrame.lua#L665
local Original_SetRaidTarget = SetRaidTarget
_G.SetRaidTarget = function(unit, index, self_only)
    if self_only == nil then
        self_only = not IsPlayerInPartyOrRaid()
        --DEFAULT_CHAT_FRAME:AddMessage("Injecting, local icon: "..(self_only and "yes" or "no"))
    end

    Original_SetRaidTarget(unit, index, self_only)
end
