-- Native role selections follow only a party member's premade-group role check.
local Stubs = TestStubs
local replaced = {
    "LycheeGroup", "C_LFGList", "IsInGroup", "UnitIsGroupLeader", "InCombatLockdown",
    "LFDRoleCheckPopup", "LFDRoleCheckPopupRoleButtonTank", "LFDRoleCheckPopupRoleButtonHealer",
    "LFDRoleCheckPopupRoleButtonDPS", "LFDPopupCheckRoleSelectionValid", "GetLFGRoles",
    "SetLFGRoles", "CompleteLFGRoleCheck", "StaticPopupSpecial_Hide",
}
local original = {}
for _, key in ipairs(replaced) do original[key] = _G[key] end

local function Setup(roles)
    Stubs.Install()
    local state = {
        grouped = true, leader = false, combat = false, premade = true, valid = true,
        available = {true, true, true}, enabled = {true, true, true},
        nativeRoles = {true, type(roles)=="table" and roles.TANK==true, type(roles)=="table" and roles.HEALER==true, type(roles)=="table" and roles.DAMAGER==true}, accepted = true, writes = {}, calls = 0, hides = 0,
    }
    _G.LycheeGroup = {charPrefs = {applicationRoles = roles, autoApply = false}}
    function LycheeGroup:GetSetting(key) return self.charPrefs[key] end
    _G.C_LFGList = {
        GetRoleCheckInfo = function() return state.premade, 123 end,
        GetAvailableRoles = function() return unpack(state.available) end,
    }
    _G.IsInGroup = function() return state.grouped end
    _G.UnitIsGroupLeader = function(unit) T.eq(unit, "player"); return state.leader end
    _G.InCombatLockdown = function() return state.combat end
    _G.LFDRoleCheckPopup = CreateFrame("Frame")
    for index, name in ipairs({"Tank", "Healer", "DPS"}) do
        local roleIndex = index
        _G["LFDRoleCheckPopupRoleButton" .. name] = {IsEnabled = function() return state.enabled[roleIndex] end}
    end
    _G.LFDPopupCheckRoleSelectionValid = function(tank, healer, damage)
        state.validated = {tank, healer, damage}
        return state.valid
    end
    _G.GetLFGRoles = function() return unpack(state.nativeRoles) end
    _G.SetLFGRoles = function(leader, tank, healer, damage)
        state.nativeRoles = {leader, tank, healer, damage}
        state.writes[#state.writes + 1] = state.nativeRoles
    end
    _G.CompleteLFGRoleCheck = function(accept)
        T.eq(accept, true)
        state.calls = state.calls + 1
        if state.throw then error("native submission unavailable") end
        if state.hideDuringSubmit then Stubs.FireEvent("LFG_ROLE_CHECK_HIDE") end
        return state.accepted
    end
    _G.StaticPopupSpecial_Hide = function(popup)
        T.eq(popup, LFDRoleCheckPopup)
        state.hides = state.hides + 1
        popup:Hide()
    end
    Load.addon("LycheeGroup", "PartyRoleCheck.lua")
    function state:Show()
        -- Our event can precede the native handler: popup appears later in the same event.
        Stubs.FireEvent("LFG_ROLE_CHECK_SHOW", false)
        LFDRoleCheckPopup:Show()
    end
    function state:Finish()
        Stubs.FireEvent("LFG_ROLE_CHECK_HIDE")
        LFDRoleCheckPopup:Hide()
        T.eq(#Stubs.FramesWithEvent("LFG_ROLE_CHECK_HIDE"), 0)
        T.eq(Stubs.PendingTimers(), 0)
    end
    return state
end

local ok, err = pcall(function()
    local roles = {TANK = false, HEALER = true, DAMAGER = true}
    local s = Setup(roles)
    T.eq(Stubs.PendingTimers(), 0, "idle has no timer")
    T.eq(#Stubs.FramesWithEvent("LFG_ROLE_CHECK_SHOW"), 1)
    T.eq(#Stubs.FramesWithEvent("LFG_ROLE_CHECK_HIDE"), 0)
    s:Show(); s:Show()
    T.eq(Stubs.PendingTimers(), 1, "duplicate SHOW coalesces")
    T.eq(s.calls, 0, "wait for native popup setup")
    Stubs.AdvanceClock(0)
    T.eq(s.calls, 1)
    T.same(s.nativeRoles, {true, false, true, true}, "preserve leader flag and every native role")
    T.same(s.validated, {false, true, true})
    T.eq(s.hides, 1)
    T.eq(Stubs.PendingTimers(), 0)
    T.eq(LycheeGroup.charPrefs.applicationRoles, roles, "obsolete addon choices are never used or changed")
    T.eq(LycheeGroup.charPrefs.autoApply, false, "member confirmation is independent of self-application automation")
    T.eq(LycheeGroup.Group, nil); T.eq(LycheeGroup.UI, nil, "works without loading either package")
    s:Show(); Stubs.AdvanceClock(0)
    T.eq(s.calls, 1, "one attempt per native role check")
    s:Finish()
    s.nativeRoles = {true,true,false,false}
    s:Show(); Stubs.AdvanceClock(0)
    T.eq(s.calls, 2, "next role check reads current native preferences")
    T.same(s.nativeRoles, {true, true, false, false})
    s:Finish()

    for _, prefs in ipairs({false, {}, {HEALER = false}, {HEALER = "true"}}) do
        s = Setup(prefs)
        s:Show(); Stubs.AdvanceClock(0)
        T.eq(s.calls, 0, "missing or empty native roles require manual confirmation")
        T.eq(#s.writes, 0); T.eq(Stubs.PendingTimers(), 0)
        T.eq(#Stubs.FramesWithEvent("LFG_ROLE_CHECK_HIDE"), 0)
        T.ok(LFDRoleCheckPopup:IsShown())
    end

    for _, blocked in ipairs({"random dungeon", "solo", "leader", "combat", "unavailable role"}) do
        s = Setup({HEALER = true, DAMAGER = true})
        if blocked == "random dungeon" then s.premade = false
        elseif blocked == "solo" then s.grouped = false
        elseif blocked == "leader" then s.leader = true
        elseif blocked == "combat" then s.combat = true
        else s.available[2] = false end
        s:Show(); Stubs.AdvanceClock(0)
        T.eq(s.calls, 0, blocked); T.eq(#s.writes, 0, blocked)
        T.eq(Stubs.PendingTimers(), 0, blocked)
        T.ok(LFDRoleCheckPopup:IsShown(), blocked .. " retains native popup")
    end

    for _, blocked in ipairs({"locked role", "invalid combination", "cancelled", "left party", "new combat", "changed queue", "manual response"}) do
        s = Setup({HEALER = true})
        s:Show()
        if blocked == "locked role" then s.enabled[2] = false
        elseif blocked == "invalid combination" then s.valid = false
        elseif blocked == "cancelled" then s:Finish()
        elseif blocked == "left party" then s.grouped = false
        elseif blocked == "new combat" then s.combat = true
        elseif blocked == "changed queue" then s.premade = false
        else LFDRoleCheckPopup:Hide() end
        Stubs.AdvanceClock(0)
        T.eq(s.calls, 0, blocked .. " before next frame")
        T.eq(#s.writes, 0); T.eq(s.hides, 0)
        s:Finish()
    end

    for _, failure in ipairs({"rejected", "error"}) do
        s = Setup({HEALER = true})
        s.accepted = false; s.throw = failure == "error"
        s:Show(); Stubs.AdvanceClock(0)
        T.eq(s.calls, 1)
        T.eq(s.hides, 0, "failure does not hide manual confirmation")
        T.ok(LFDRoleCheckPopup:IsShown())
        T.same(s.nativeRoles, {true, false, true, false}, "failed request leaves native roles untouched")
        T.eq(#s.writes,0,"confirmation never rewrites native roles")
        s:Show(); Stubs.AdvanceClock(0)
        T.eq(s.calls, 1, "failed request is not retried")
        s:Finish()
    end

    s = Setup({HEALER = true})
    s.hideDuringSubmit = true
    s:Show(); Stubs.AdvanceClock(0)
    T.eq(s.calls, 1); T.eq(s.hides, 1)
    T.eq(#Stubs.FramesWithEvent("LFG_ROLE_CHECK_HIDE"), 0, "synchronous completion clears listener")
    s:Show(); Stubs.AdvanceClock(0)
    T.eq(s.calls, 2)
    s:Finish()

    local file = assert(io.open("addon/LycheeGroup/LycheeGroup.toc", "r"))
    local toc = file:read("*a"); file:close()
    T.ok(toc:find("\nPartyRoleCheck.lua\r?\n"), "bridge is shipped in the core TOC")
end)

for _, key in ipairs(replaced) do _G[key] = original[key] end
if not ok then error(err, 0) end
