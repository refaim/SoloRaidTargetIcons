-- SoloRaidTargetIcons (community-extended build)
-- Original addon: https://github.com/refaim/SoloRaidTargetIcons (MIT, refaim)
--
-- This build adds detection for a handful of popular 1.12 client mods and,
-- where one of them actually offers something relevant, a small feature on
-- top. It does NOT fake integrations that don't exist -- see the nampower
-- note below.
--
--   SuperWoW      https://github.com/balakethelock/SuperWoW/wiki
--                 Primary requirement. Its SetRaidTarget(unit, index, true)
--                 "local" flag is what makes solo marking possible. If it's
--                 not present, the brues-code nampower fork below can serve
--                 as a fallback backend for the same job.
--   UnitXP_SP3    https://codeberg.org/konaka/UnitXP_SP3/wiki
--                 Optional. Adds UnitXP("target","nextMarkedEnemyInCycle"),
--                 which this build wires up to /srti next|prev so you can
--                 tab between your own solo marks.
--   ClassicAPI    https://github.com/brues-code/ClassicAPI
--                 Optional. Registers itself as a synthetic addon
--                 ("!!!ClassicAPI"). Detected for /srti status only --
--                 nothing it backports is raid-icon related.
--   VanillaHelpers https://github.com/isfir/VanillaHelpers
--                 Optional. Textures/models/file-IO helper library.
--                 Detected for /srti status only -- nothing applicable here.
--   nampower (namreeb original)  https://github.com/namreeb/nampower
--                 A pure client-binary patch for spell-cast latency. It
--                 exposes no Lua globals or functions whatsoever, so there
--                 is nothing for an addon to detect or call.
--   nampower (brues-code fork, v4.6.1+)  https://github.com/brues-code/nampower
--                 A much larger fork -- spell queuing plus a big Lua API.
--                 Relevant here: it ships its own client-local raid marker
--                 table (GetRaidTargets / SetLocalRaidTargetIndex) and a
--                 CVar (NP_EnableLocalSetRaidTarget, default on) that makes
--                 plain SetRaidTarget() fall back to local marking when
--                 solo. That means THIS fork can back the actual marking
--                 without SuperWoW at all. SuperWoW is still used as the
--                 primary backend when present (its 3rd-arg SetRaidTarget
--                 flag is simpler and well-tested); this nampower fork is
--                 used as a fallback backend, and either one enables the
--                 fake-party trick that makes the UI dropdown show marking
--                 options while solo in the first place.

SoloRaidTargetIcons = SoloRaidTargetIcons or {}
local SRTI = SoloRaidTargetIcons

-- ---------------------------------------------------------------------
-- Companion mod detection
-- ---------------------------------------------------------------------

---@return boolean
function SRTI.IsSuperWoWLoaded()
	-- SUPERWOW_VERSION / SUPERWOW_STRING are the globals SuperWoW documents
	-- for addon detection. More specific than the old SetAutoloot~=nil check,
	-- which could collide with any other mod that happens to define it.
	-- https://github.com/balakethelock/SuperWoW/wiki/Features
	return SUPERWOW_VERSION ~= nil
end

---@return boolean
function SRTI.IsBruesNampowerLoaded()
	-- These two functions are specific to the brues-code/nampower fork and
	-- don't exist in namreeb's original or in vanilla -- a reliable marker
	-- for "this particular build is loaded".
	return type(SetLocalRaidTargetIndex) == "function" and type(GetRaidTargets) == "function"
end

---@return boolean
function SRTI.IsNampowerLocalMarkingEnabled()
	if not SRTI.IsBruesNampowerLoaded() then
		return false
	end
	if type(GetCVar) ~= "function" then
		return true -- can't check, assume the documented default (on)
	end
	local val = GetCVar("NP_EnableLocalSetRaidTarget")
	return val == nil or val == "1"
end

---@return boolean
function SRTI.IsClassicAPILoaded()
	return type(IsAddOnLoaded) == "function" and IsAddOnLoaded("!!!ClassicAPI") == 1
end

---@return boolean
function SRTI.IsVanillaHelpersLoaded()
	-- VanillaHelpers doesn't publish a version global, so presence of a
	-- couple of its distinctive registered functions is the best proxy.
	return type(WriteFile) == "function" and type(ReadFile) == "function"
end

---@return boolean
function SRTI.IsUnitXPLoaded()
	-- This is the exact detection idiom UnitXP_SP3's own wiki recommends.
	local ok = pcall(UnitXP, "nop", "nop")
	return ok == true
end

-- ---------------------------------------------------------------------
-- Original core logic (refaim/SoloRaidTargetIcons), unchanged in behavior
-- ---------------------------------------------------------------------

local function IsPlayerInPartyOrRaid()
	return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
end

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

-- True if any backend capable of client-local marking is available.
local function HasLocalMarkingBackend()
	return SRTI.IsSuperWoWLoaded() or SRTI.IsNampowerLocalMarkingEnabled()
end

local Blizzard_UnitPopup_HideButtons = UnitPopup_HideButtons
UnitPopup_HideButtons = function()
	if HasLocalMarkingBackend() and IsOpeningDropdownForTargetUnitFrame() and not IsPlayerInPartyOrRaid() then
		AddPlayerToFakeParty()
	end
	Blizzard_UnitPopup_HideButtons()
	RemovePlayerFromFakeParty()
end

-- Resolve a unit token to a GUID using whichever backend is loaded, so we
-- can read back nampower's local marker table (which is keyed by GUID).
local function ResolveUnitGUID(unit)
	if type(GetUnitGUID) == "function" then
		return GetUnitGUID(unit) -- brues-code/nampower
	end
	if type(UnitExists) == "function" then
		local exists, guid = UnitExists(unit) -- SuperWoW extends UnitExists to return a GUID
		if exists then
			return guid
		end
	end
	return nil
end

-- Look up the current local mark on a unit from nampower's own marker
-- table (GetRaidTargets), since GetRaidTargetIndex only reflects
-- server-known raid marks.
local function GetLocalMarkIndex(unit)
	local guid = ResolveUnitGUID(unit)
	if not guid then
		return nil
	end
	local marks = GetRaidTargets()
	for i = 1, 8 do
		if marks[i] == guid then
			return i
		end
	end
	return nil
end

-- https://github.com/refaim/Turtle-WoW-UI-Source/blob/d6137c2ebd291f10ce284e586a5733dd5141bef2/Interface/FrameXML/TargetFrame.lua#L665
Blizzard_SetRaidTargetIcon = SetRaidTargetIcon
SetRaidTargetIcon = function(unit, index)
	local solo = not IsPlayerInPartyOrRaid()
	local use_superwow = SRTI.IsSuperWoWLoaded()
	local use_nampower_local = (not use_superwow) and solo and SRTI.IsNampowerLocalMarkingEnabled()

	local cur_index
	if use_nampower_local then
		cur_index = GetLocalMarkIndex(unit)
	else
		cur_index = GetRaidTargetIndex(unit)
	end

	local new_index = index
	if cur_index and cur_index == index then
		new_index = 0
	end

	if use_superwow then
		-- https://github.com/balakethelock/SuperWoW/wiki/Features
		SetRaidTarget(unit, new_index, solo)
	elseif use_nampower_local then
		-- brues-code/nampower resolves the unit to a GUID and writes its
		-- own client-local marker table directly -- no 3rd arg needed.
		SetLocalRaidTargetIndex(unit, new_index)
	else
		SetRaidTarget(unit, new_index)
	end
end

-- ---------------------------------------------------------------------
-- New: solo mark-cycling (needs UnitXP_SP3) + a status command
-- ---------------------------------------------------------------------

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffSoloRaidTargetIcons|r: " .. msg)
end

local function StatusLine(name, loaded, extra)
	local state = loaded and "|cff00ff00loaded|r" or "|cffff0000not loaded|r"
	Print(name .. ": " .. state .. (extra and (" " .. extra) or ""))
end

local function CycleMarkedTarget(direction)
	if not SRTI.IsUnitXPLoaded() then
		Print("mark cycling needs UnitXP_SP3, which wasn't detected.")
		return
	end
	local mode = (direction == "prev") and "previousMarkedEnemyInCycle" or "nextMarkedEnemyInCycle"
	local found = UnitXP("target", mode)
	if not found then
		Print("no marked enemies in range.")
	end
end

SLASH_SOLORAIDTARGETICONS1 = "/srti"
SlashCmdList["SOLORAIDTARGETICONS"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "next" then
		CycleMarkedTarget("next")
	elseif msg == "prev" or msg == "previous" then
		CycleMarkedTarget("prev")
	else
		StatusLine("SuperWoW", SRTI.IsSuperWoWLoaded(), "(primary local-marking backend)")
		local np_loaded = SRTI.IsBruesNampowerLoaded()
		local np_extra
		if not np_loaded then
			np_extra = "(fallback local-marking backend; namreeb's original build has no Lua API)"
		elseif not SRTI.IsNampowerLocalMarkingEnabled() then
			np_extra = "|cffffaa00loaded, but NP_EnableLocalSetRaidTarget is 0|r"
		else
			np_extra = "(fallback local-marking backend)"
		end
		StatusLine("nampower (brues-code fork)", np_loaded, np_extra)
		StatusLine("UnitXP_SP3", SRTI.IsUnitXPLoaded(), "(enables /srti next|prev)")
		StatusLine("ClassicAPI", SRTI.IsClassicAPILoaded())
		StatusLine("VanillaHelpers", SRTI.IsVanillaHelpersLoaded())
		if not HasLocalMarkingBackend() then
			Print("|cffff0000No local-marking backend detected -- solo marking won't work.|r Install SuperWoW or the brues-code nampower fork.")
		end
		Print("Commands: /srti (status), /srti next, /srti prev")
	end
end
