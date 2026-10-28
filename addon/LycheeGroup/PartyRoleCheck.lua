-- Follow the current native LFG roles when another player applies
-- for the party. Keep this small native bridge available before Group/UI load.
local events = CreateFrame("Frame")
local active, timer

local function SelectedRoles()
    if not IsInGroup() or UnitIsGroupLeader("player") or InCombatLockdown() then return end
    if not C_LFGList.GetRoleCheckInfo or not C_LFGList.GetRoleCheckInfo() then return end
    if not GetLFGRoles then return end
    local _, tank, healer, damage = GetLFGRoles()
    if not tank and not healer and not damage then return end
    local canTank, canHeal, canDamage = C_LFGList.GetAvailableRoles()
    if tank and not canTank or healer and not canHeal or damage and not canDamage then return end
    return tank, healer, damage
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
    local tank, healer, damage = SelectedRoles()
    if tank == nil then return end
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
    if active or SelectedRoles() == nil then return end
    active = true
    events:RegisterEvent("LFG_ROLE_CHECK_HIDE")
    -- The native SHOW handler must finish building and validating its popup first.
    -- One cancellable next-frame callback, with no polling or delayed retry.
    timer = C_Timer.NewTimer(0, Confirm)
end)
events:RegisterEvent("LFG_ROLE_CHECK_SHOW")
