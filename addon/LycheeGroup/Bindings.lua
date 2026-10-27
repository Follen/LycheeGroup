-- Blizzard owns the bindings. Configuration supplies defaults; observed player
-- choices and legacy initialized scopes retain their existing bindings.
local A = _G.LycheeGroup
local PATH = "settings.toggleBinding"
local B = { action = "LYCHEEGROUP_TOGGLE", defaultKey = ";" }
A.Bindings = B
local events = CreateFrame("Frame")
local legacyObserved = {}
local function ValidKey(value)
    return value==false or type(value)=="string" and value~="" and not value:find("[%s%c]")
end

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
    if not key then return end
    local action = GetBindingAction(key, nil, self:Context())
    if action ~= "" and action ~= self.action then return action end
end

local function Scope()
    local scope = GetCurrentBindingSet()
    return scope, scope==2 and ("character:"..UnitGUID("player")) or "account", scope==2 and "character" or "account"
end

local function Matches(record, first, second)
    return record.first==(first or false) and record.second==(second or false)
end

local function Record(mode, requested, first, second)
    return {mode=mode,requested=requested,first=first or false,second=second or false}
end

function B:Scopes()
    A:LoadDB()
    return A.Configuration:BindTable(A.db, A.db, "bindingDefaultScopes", "bindingDefaultScopes")
end

-- Defaults do not pass through SetKey, which records explicit user intent.
-- Keep native writes and synchronous SaveBindings events under one guard.
function B:WritePrimary(key, confirmedAction)
    if InCombatLockdown() then return false, "combat" end
    local conflict = self:Conflict(key)
    if conflict and conflict ~= confirmedAction then return false, "conflict", conflict end
    local first, second = self:Keys()
    if first==key or not first and key==false then return true end
    local context = self:Context()
    local previousAction = key and GetBindingAction(key,nil,context)
    self.writing = true
    local ok = true
    if key then ok=SetBinding(key,self.action,context)==true end
    if ok and first and first~=key then ok=SetBinding(first,nil,context)==true end
    if ok and second and second~=key then
        ok=SetBinding(second,nil,context)==true
        if ok then ok=SetBinding(second,self.action,context)==true end
    end
    if ok then ok=SaveBindings(GetCurrentBindingSet())~=false end
    if not ok then
        if key and key~=first and key~=second then SetBinding(key,previousAction~="" and previousAction or nil,context) end
        if first then SetBinding(first,self.action,context) end
        if second then SetBinding(second,nil,context);SetBinding(second,self.action,context) end
    end
    self.writing = nil
    if not ok then return false,"failed" end
    return true
end

function B:RememberUser(first, second)
    local _,scopeKey,storage = Scope()
    self.syncing = true
    local ok,reason = A.Configuration:Set({[PATH]=first or false},{storage=storage})
    self.syncing = nil
    if not ok then return false,reason end
    self:Scopes()[scopeKey] = Record("user",first or false,first,second)
    return true
end

-- Change the primary key while retaining a second key configured in Blizzard.
-- confirmedAction names the conflict actually accepted by the player.
function B:SetKey(key, confirmedAction)
    if not ValidKey(key) then return false,"invalid" end
    local ok,reason,conflict = self:WritePrimary(key,confirmedAction)
    if not ok then return false,reason,conflict end
    local first,second = self:Keys()
    return self:RememberUser(first,second)
end

function B:InitializeDefault(configurationChanged)
    if self.writing or self.syncing then return end
    self.ready = true
    local scopes = self:Scopes()
    local _,scopeKey = Scope()
    local desired = A.Configuration:Get(PATH)
    local source = A.Configuration:GetSource(PATH)
    self.defaultKey = desired
    if InCombatLockdown() then
        self.pendingConfiguration = self.pendingConfiguration or configurationChanged
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false,"combat"
    end
    configurationChanged = configurationChanged or self.pendingConfiguration
    self.pendingConfiguration = nil
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local first,second = self:Keys()
    local record = scopes[scopeKey]
    local observed = type(record)=="table" and record or legacyObserved[scopeKey]
    if record and observed and (type(record)=="table" or observed.scopes==scopes) and not Matches(observed,first,second) then
        if observed.first~=(first or false) then return self:RememberUser(first,second) end
        -- Editing only the secondary key leaves an automatically owned primary
        -- eligible for a later default update.
        observed.second=second or false
    end
    local explicitUser = configurationChanged and source.kind=="user"
    if record==true then
        legacyObserved[scopeKey]={scopes=scopes,first=first or false,second=second or false}
        if not explicitUser then return true end
    elseif record and type(record)~="table" then
        A.Configuration:RetainInvalid(A.db,"bindingDefaultScopes."..scopeKey,record,"invalid binding scope state")
        scopes[scopeKey]=true
        return true
    elseif record then
        if record.mode=="external" and not explicitUser then return true end
        if record.mode=="user" and source.kind=="user" and not explicitUser then return true end
        if record.requested==desired and (record.mode=="user")==(source.kind=="user") then return true end
    elseif first and not explicitUser then
        scopes[scopeKey]=Record("external",nil,first,second)
        return true
    end
    local ok,reason = self:WritePrimary(desired)
    if not ok then return false,reason end
    first,second = self:Keys()
    scopes[scopeKey]=Record(source.kind=="user" and "user" or "default",desired,first,second)
    return true
end

function B:OnConfigurationChanged()
    self.defaultKey = A.Configuration:Get(PATH)
    if self.syncing or self.writing then return end
    if not self.ready then self.pendingConfiguration=true;return end
    return self:InitializeDefault(true)
end

if not A.Configuration.definitions[PATH] then
    assert(A.Configuration:RegisterDefinitions({[PATH]={
        default=";", storage="account", type={"string","boolean"},
        validate=function(value)
            return ValidKey(value), "expected a binding key or false"
        end,
    }}))
end

events:SetScript("OnEvent", function(_, event)
    if event=="PLAYER_LOGIN" then events:UnregisterEvent(event)
    elseif not B.ready or B.writing or B.syncing then return end
    B:InitializeDefault()
end)
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UPDATE_BINDINGS")
