-- Follow native PvE/PvP roles when another player applies or queues
-- for the party. Keep this small native bridge available before Group/UI load.
local events = CreateFrame("Frame")
local active, timer

local function SelectedRoles()
    if not IsInGroup() or UnitIsGroupLeader("player") or InCombatLockdown() then return end
    local checking, _, _, _, _, battleground = GetLFGRoleUpdate()
    local tank, healer, damage, kind
    if battleground then
        if not checking or not GetPVPRoles then return end
        tank, healer, damage = GetPVPRoles()
        kind = "pvp"
    else
        if not C_LFGList.GetRoleCheckInfo or not C_LFGList.GetRoleCheckInfo() or not GetLFGRoles then return end
        _, tank, healer, damage = GetLFGRoles()
        kind = "premade"
    end
    if not tank and not healer and not damage then return end
    local canTank, canHeal, canDamage = C_LFGList.GetAvailableRoles()
    if tank and not canTank or healer and not canHeal or damage and not canDamage then return end
    return tank, healer, damage, kind
end

local function Stop()
    active = nil
    if timer then timer:Cancel(); timer = nil end
    events:UnregisterEvent("LFG_ROLE_CHECK_HIDE")
end

local function RoleEnabled(selected, button)
    return not selected or button and button:IsEnabled()
end

local function Confirm()
    timer = nil
    if not active then return end
    local tank, healer, damage, kind = SelectedRoles()
    if tank == nil or kind ~= active then return end
    local popup = LFDRoleCheckPopup
    if not popup or not popup:IsShown() then return end
    if not RoleEnabled(tank, LFDRoleCheckPopupRoleButtonTank)
        or not RoleEnabled(healer, LFDRoleCheckPopupRoleButtonHealer)
        or not RoleEnabled(damage, LFDRoleCheckPopupRoleButtonDPS) then return end
    if not LFDPopupCheckRoleSelectionValid or not LFDPopupCheckRoleSelectionValid(tank, healer, damage) then return end
    if not CompleteLFGRoleCheck or not StaticPopupSpecial_Hide then return end
    local ok, accepted = pcall(CompleteLFGRoleCheck, true)
    if ok and accepted then
        StaticPopupSpecial_Hide(popup)
    end
end

events:SetScript("OnEvent", function(_, event)
    if event == "LFG_ROLE_CHECK_HIDE" then Stop(); return end
    if active then return end
    local tank, _, _, kind = SelectedRoles()
    if tank == nil then return end
    active = kind
    events:RegisterEvent("LFG_ROLE_CHECK_HIDE")
    -- The native SHOW handler must finish building and validating its popup first.
    -- One cancellable next-frame callback, with no polling or delayed retry.
    timer = C_Timer.NewTimer(0, Confirm)
end)
events:RegisterEvent("LFG_ROLE_CHECK_SHOW")
