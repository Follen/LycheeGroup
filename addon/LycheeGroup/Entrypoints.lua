-- 一次性启动、最小业务唤醒与用户入口；领域包加载后自行管理活动事件。
local A = _G.LycheeGroup
local events = CreateFrame("Frame")
local groupReady = false
local WAKE_EVENTS = {
    "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "LFG_LIST_ACTIVE_ENTRY_UPDATE",
}

-- Keep the stock animation running: its OnLoop owns applicant sounds.
local nativeLFGHooked = false
local nativeLFGClickBound = false
local nativeLFGState
local function OpenNativePremadeGroup()
    local page, applicationID
    if C_LFGList.HasActiveEntryInfo() then
        page = "create"
    else
        for _, id in ipairs(C_LFGList.GetApplications()) do
            local _, status = C_LFGList.GetApplicationInfo(id)
            if status == "applied" or status == "invited" then
                page, applicationID = "find", id
                break
            end
        end
    end
    if not page then return false end
    local nativeShown = PVEFrame and PVEFrame:IsShown()
    if nativeShown then HideUIPanel(PVEFrame) end
    if A.UI and A.UI.preview then A.UI:StopPreview(false) end
    if not A:Open(page, applicationID and {applicationID = applicationID}) and nativeShown then
        ShowUIPanel(PVEFrame)
    end
    return true
end

local function ShouldConcealNativeLFGEntry()
    if not A:GetSetting("nativeLFGEntry") then return false end
    -- Match QueueStatusFrame's dungeon/raid entries, including role checks,
    -- proposals and in-instance teleport actions, not just the queued phase.
    for category = 1, NUM_LE_LFG_CATEGORYS do
        local mode, submode = GetLFGMode(category)
        if mode and submode ~= "noteleport" then return false end
    end
    return true
end

local function UpdateNativeLFGEntry(button)
    if ShouldConcealNativeLFGEntry() then
        if not nativeLFGState then
            nativeLFGState = {alpha = button:GetAlpha(), mouse = button:IsMouseEnabled()}
        end
        button:SetAlpha(0)
        button:EnableMouse(false)
        QueueStatusFrame:Hide()
    elseif nativeLFGState then
        local state = nativeLFGState
        nativeLFGState = nil
        button:SetAlpha(state.alpha)
        button:EnableMouse(state.mouse)
    end
end

function A:SyncNativeLFGEntry()
    local button = QueueStatusButton
    if not button then
        events:RegisterEvent("ADDON_LOADED")
        return
    end
    events:UnregisterEvent("ADDON_LOADED")
    if not nativeLFGClickBound then
        nativeLFGClickBound = true
        local original = button:GetScript("OnClick")
        button:SetScript("OnClick", function(eye, key, ...)
            if key == "LeftButton" and OpenNativePremadeGroup() then return end
            -- Other clicks keep the native queue menu and battlefield actions.
            if original then return original(eye, key, ...) end
        end)
    end
    if not nativeLFGHooked and self:GetSetting("nativeLFGEntry") then
        nativeLFGHooked = true
        button:HookScript("OnShow", UpdateNativeLFGEntry)
        hooksecurefunc(button, "SetAlpha", function(eye, alpha)
            if nativeLFGState and alpha ~= 0 then eye:SetAlpha(0) end
        end)
        hooksecurefunc(QueueStatusFrame, "Update", function()
            UpdateNativeLFGEntry(button)
        end)
    end
    UpdateNativeLFGEntry(button)
end

local function StopGroupWake()
    for _, event in ipairs(WAKE_EVENTS) do events:UnregisterEvent(event) end
    events:UnregisterEvent("CHALLENGE_MODE_START")
end

function A:OnModuleReady(module)
    if module == "Group" then
        groupReady = true
        StopGroupWake()
        if self.UI and self.UI.OnGroupReady then self.UI:OnGroupReady() end
    elseif module == "Notes" and self.UI and self.UI.OnNotesReady then
        self.UI:OnNotesReady()
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

function A:SyncHistoryWake(enabledNow)
    if groupReady or not self:GetSetting("history") then
        events:UnregisterEvent("CHALLENGE_MODE_START")
        return
    end
    events:RegisterEvent("CHALLENGE_MODE_START")
    if C_ChallengeMode.IsChallengeModeActive() then
        local group, err = self:Ensure("Group")
        if not group then self:Print(self.L.loadFailed:format(tostring(err)))
        elseif enabledNow then group.History:Discard();group.History:Restore() end
    end
end

local function HandOffToGroup(event, ...)
    local newRun = not groupReady and event == "CHALLENGE_MODE_START"
    local group, err = A:Ensure("Group")
    if not group then
        A:Print(A.L.loadFailed:format(tostring(err)))
        return
    end
    -- Loading on START means a new run, not recovery of an older LoD save.
    if newRun then group.History:Discard() end
    group:OnEvent(event, ...)
end

-- 原生头像菜单与界面共用同一记录意图；实际写入仍归 Notes。
function A:RecordPlayer(name, realm, unit, reason)
    self:LoadDB()
    local key, cleanName, cleanRealm = self:PlayerKey(name, realm)
    if not key then self:NoteMessage(self.L.invalidName); return false end
    reason = type(reason) == "string" and reason:match("^%s*(.-)%s*$") or ""
    if self:GetSetting("askReason") and reason == "" then
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
        if not A:GetSetting("notesEnabled") or not context then return end
        local unit = context.unit
        local key, name, realm
        if type(unit) == "string" and not (issecretvalue and issecretvalue(unit)) then
            key, name, realm = A:UnitIdentity(unit)
        else
            key, name, realm = A:PlayerKey(context.name, context.server)
            unit = nil
        end
        if not key or key == A:UnitIdentity("player") then return end
        if not A.Notes and A.db.notesHasRecords then
            local notes, err = A:Ensure("Notes")
            if not notes then A:NoteMessage(A.L.loadFailed:format(tostring(err))); return end
        end
        local record = A.Notes and A.Notes:Find(key)
        root:CreateDivider()
        root:CreateTitle(A.L.brand)
        root:CreateButton(record and A.L.removeRecord or A.L.recordPlayer, function()
            if not A:GetSetting("notesEnabled") then return end
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
    if A:GetSetting("notesEnabled") and A.db.notesHasRecords and A:GetSetting("reminders") ~= "off" then
        local notes, err = A:Ensure("Notes")
        if not notes then A:NoteMessage(A.L.loadFailed:format(tostring(err))) end
    end
    if groupReady then return end
    if HasActiveLFGBusiness() then
        local group, err = A:Ensure("Group")
        if not group then A:Print(A.L.loadFailed:format(tostring(err))) end
    else
        for _, event in ipairs(WAKE_EVENTS) do events:RegisterEvent(event) end
        A:SyncHistoryWake()
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

-- Optional developer tools register their own handler and usage here.
A.DevCommands=A.DevCommands or {}
A.DevCommands.test={usage="/lg dev test [applications|create|applicants|off]",run=function(rest)
    local ok,err=A:Preview(rest~="" and rest or "applications");if not ok then A:Print(err) end
end}
A.DevCommands.floattest={usage="/lg dev floattest",run=function(rest)
    if rest~="" then A:Print(A.DevCommands.floattest.usage);return end
    A:Print(A.Floating:ToggleStandaloneTest() and A.L.floatingTestOn or A.L.floatingTestOff)
end}
local function DeveloperCommand(message)
    local command,rest=message:match("^%s*(%S*)%s*(.-)%s*$")
    local entry=A.DevCommands[command]
    if entry then return entry.run(rest) end
    local names={};for name in pairs(A.DevCommands) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do A:Print(A.DevCommands[name].usage) end
end

SLASH_LYCHEEGROUP1 = "/lg"
SlashCmdList.LYCHEEGROUP = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    if command == "dev" then
        DeveloperCommand(rest)
    elseif command == "" then
        A:ToggleWindow()
    else
        A:Print(A.L.cmdUsage)
    end
end
