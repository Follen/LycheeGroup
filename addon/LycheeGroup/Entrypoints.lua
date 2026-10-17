-- 一次性启动、最小业务唤醒与用户入口；领域包加载后自行管理活动事件。
local A = _G.LycheeGroup
local events = CreateFrame("Frame")
local groupReady = false
local WAKE_EVENTS = {
    "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "LFG_LIST_ACTIVE_ENTRY_UPDATE",
    "CHALLENGE_MODE_START",
}

-- Only the premade-group branch of the minimap eye is redirected. The stock
-- callback still owns battleground clicks, other queues and the right menu.
local nativeLFGHooked = false
function A:SyncNativeLFGEntry()
    if nativeLFGHooked then return end
    if not self.db.nativeLFGEntry then events:UnregisterEvent("ADDON_LOADED"); return end
    local button = QueueStatusButton
    if not button then events:RegisterEvent("ADDON_LOADED"); return end
    local original = button:GetScript("OnClick")
    button:SetScript("OnClick", function(eye, mouseButton, ...)
        if A.db.nativeLFGEntry and mouseButton == "LeftButton"
            and not QueueStatus_InActiveBattlefield() and not IsInLFDBattlefield() then
            local page
            if C_LFGList.HasActiveEntryInfo() then
                page = "create"
            else
                for _, id in ipairs(C_LFGList.GetApplications()) do
                    local _, status = C_LFGList.GetApplicationInfo(id)
                    if status == "applied" or status == "invited" then page = "find"; break end
                end
            end
            if page and A:Open(page) then
                eye.angerVal = eye.angerVal + LFG_ANGER_INC_VAL
                return
            end
        end
        return original(eye, mouseButton, ...)
    end)
    nativeLFGHooked = true
    events:UnregisterEvent("ADDON_LOADED")
end

local function StopGroupWake()
    for _, event in ipairs(WAKE_EVENTS) do events:UnregisterEvent(event) end
end

function A:OnModuleReady(module)
    if module == "Group" then
        groupReady = true
        StopGroupWake()
    end
end

local function HasActiveLFGBusiness()
    if C_LFGList.HasActiveEntryInfo() then return true end
    for _, id in ipairs(C_LFGList.GetApplications()) do
        local _, status, pending = C_LFGList.GetApplicationInfo(id)
        if status == "applied" or status == "invited" or pending ~= nil then return true end
    end
    return false
end

local function HasActiveChallengeRun()
    return C_ChallengeMode.IsChallengeModeActive()
end

local function HandOffToGroup(event, ...)
    local group, err = A:Ensure("Group")
    if not group then
        A:Print(A.L.loadFailed:format(tostring(err)))
        return
    end
    group:OnEvent(event, ...)
end

-- 原生头像菜单和命令共用同一记录意图；实际写入仍归 Notes。
function A:RecordPlayer(name, realm, unit, reason)
    self:LoadDB()
    local key, cleanName, cleanRealm = self:PlayerKey(name, realm)
    if not key then self:NoteMessage(self.L.invalidName); return false end
    reason = type(reason) == "string" and reason:match("^%s*(.-)%s*$") or ""
    if self.db.askReason and reason == "" then
        return self:Open("notes", {add = {name = cleanName, realm = cleanRealm, unit = unit}})
    end
    local notes, err = self:Ensure("Notes")
    if not notes then self:NoteMessage(self.L.loadFailed:format(tostring(err))); return false end
    local function Commit(spec, details)
        local ok, record = notes:Add(cleanName, cleanRealm, reason, unit, spec, details)
        if ok then
            self:NoteMessage(self.L.recorded:format(cleanName .. "-" .. cleanRealm))
        else
            self:NoteMessage(self.L.recordFailed:format(tostring(record)))
        end
        return ok
    end
    if unit and self:UnitIdentity(unit) == key then
        notes.PlayerInfo.Request(unit, function(spec, details) Commit(spec or "", details) end)
        return true
    end
    return Commit("")
end

local menusRegistered = false
local function RegisterPlayerMenus()
    if menusRegistered or not (Menu and Menu.ModifyMenu) then return end
    local function AddNoteActions(_, root, context)
        if not A.db.notesEnabled or not context then return end
        local unit = context.unit
        local key, name, realm
        if type(unit) == "string" and not (issecretvalue and issecretvalue(unit)) then
            key, name, realm = A:UnitIdentity(unit)
        else
            key, name, realm = A:PlayerKey(context.name, context.server)
            unit = nil
        end
        if not key or key == A:UnitIdentity("player") then return end
        local record = A.Notes and A.Notes:Find(key)
        root:CreateDivider()
        root:CreateTitle(A.L.brand)
        root:CreateButton(record and A.L.removeRecord or A.L.recordPlayer, function()
            if not A.db.notesEnabled then return end
            if record then
                if A.Notes:Remove(key) then A:NoteMessage(A.L.removed:format(name .. "-" .. realm)) end
            else
                A:RecordPlayer(name, realm, unit)
            end
        end)
    end
    for _, tag in ipairs({"ARENAENEMY", "ENEMY_PLAYER", "FOCUS", "PARTY", "PLAYER", "RAID", "RAID_PLAYER", "TARGET"}) do
        Menu.ModifyMenu("MENU_UNIT_" .. tag, AddNoteActions)
    end
    menusRegistered = true
end

local function OnPlayerLogin()
    A:LoadDB()
    A.Minimap:Initialize()
    A:SyncNativeLFGEntry()
    RegisterPlayerMenus()
    if A.db.notesEnabled and A.db.notesHasRecords then
        local notes, err = A:Ensure("Notes")
        if not notes then A:NoteMessage(A.L.loadFailed:format(tostring(err))) end
    end
    if groupReady then return end
    if HasActiveLFGBusiness() or HasActiveChallengeRun() then
        local group, err = A:Ensure("Group")
        if not group then A:Print(A.L.loadFailed:format(tostring(err))) end
    else
        for _, event in ipairs(WAKE_EVENTS) do events:RegisterEvent(event) end
    end
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "LycheeGroup" then
            A:LoadDB()
            events:UnregisterEvent(event)
        elseif name == "Blizzard_QueueStatusFrame" then
            A:SyncNativeLFGEntry()
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        events:UnregisterEvent(event)
        OnPlayerLogin()
        return
    end
    HandOffToGroup(event, ...)
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

-- 链接带完整玩家身份，点击时读取当前记录，不维护跳转历史。
LinkUtil.RegisterLinkHandler("lycheegroup", function(link, _, data, context)
    if issecretvalue and issecretvalue(link) then return end
    if context and context.button and context.button ~= "LeftButton" then return end
    if data.options then
        local key = data.options:match("^note:(.+)$")
        if key then A:Open("notes", {playerKey = key}) end
    end
end)

local function SlashNote(rest)
    local name, reason = rest:match("^(%S+)%s*(.-)$")
    if name then A:RecordPlayer(name, nil, nil, reason); return end
    local key, cleanName, realm = A:UnitIdentity("target")
    if not key then A:NoteMessage(A.L.invalidName); return end
    A:RecordPlayer(cleanName, realm, "target")
end

SLASH_LYCHEEGROUP1 = "/lycheegroup"
SLASH_LYCHEEGROUP2 = "/lg"
SlashCmdList.LYCHEEGROUP = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)$")
    if command == "test" then
        local ok,err=A:Preview(rest~="" and rest or "applications");if not ok then A:Print(err) end
    elseif command == "note" then
        SlashNote(rest)
    elseif command == "" or command == "find" then
        local ui = A.UI
        if ui and ui:IsShown() then ui:Hide() else A:Open("find") end
    elseif command == "create" or command == "notes" or command == "settings" then
        A:Open(command)
    else
        A:Print(A.L.cmdUsage)
    end
end
