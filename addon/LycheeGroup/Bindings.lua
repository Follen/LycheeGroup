-- Bindings.xml registers the action. Defaults never replace an existing key.
local A = _G.LycheeGroup
local B = { action = "LYCHEEGROUP_TOGGLE", defaultKey = ";" }
A.Bindings = B
local events = CreateFrame("Frame")

function B:Context()
    return C_KeyBindings.GetBindingContextForAction(self.action)
end

function B:Keys()
    return GetBindingKey(self.action, nil, self:Context())
end

function B:Text()
    local first, second = self:Keys()
    if not first then return A.L.bindingUnbound end
    return GetBindingText(first) .. (second and (" / " .. GetBindingText(second)) or "")
end

function B:Conflict(key)
    local action = GetBindingAction(key, nil, self:Context())
    if action ~= "" and action ~= self.action then return action end
end

-- Change the primary key, preserving a secondary key configured in Blizzard UI.
-- confirmedAction names the conflict actually accepted by the player.
function B:SetKey(key, confirmedAction)
    if InCombatLockdown() then return false, "combat" end
    local conflict = self:Conflict(key)
    if conflict and conflict ~= confirmedAction then return false, "conflict", conflict end
    local first, second = self:Keys()
    if first == key then return true end
    local context = self:Context()
    if not SetBinding(key, self.action, context) then return false, "failed" end
    if first and first ~= key then SetBinding(first, nil, context) end
    if second and second ~= key then
        SetBinding(second, nil, context)
        SetBinding(second, self.action, context)
    end
    SaveBindings(GetCurrentBindingSet())
    return true
end

function B:InitializeDefault()
    A:LoadDB()
    if InCombatLockdown() then events:RegisterEvent("PLAYER_REGEN_ENABLED"); return end
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local scope = GetCurrentBindingSet()
    local scopeKey = scope == 2 and ("character:" .. UnitGUID("player")) or "account"
    local initialized = A.db.bindingDefaultScopes
    if not initialized then initialized = {}; A.db.bindingDefaultScopes = initialized end
    if initialized[scopeKey] then return end
    initialized[scopeKey] = true
    if self:Keys() or self:Conflict(self.defaultKey) then return end
    local ok = self:SetKey(self.defaultKey)
    if not ok then A:Print(A.L.bindingFailed) end
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then events:UnregisterEvent(event) end
    B:InitializeDefault()
end)
events:RegisterEvent("PLAYER_LOGIN")
