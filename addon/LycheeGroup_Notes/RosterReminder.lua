-- 入队与邀请记录提醒。成员集合只负责当前队伍去重与重逢,
-- 邀请仅观察原生事件/API，不改变邀请结果。没有 timer/OnUpdate。
local A = _G.LycheeGroup
local Notes = A.Notes
local NL = Notes.L

local Reminder = {}
Notes.RosterReminder = Reminder

local EVENTS = { "GROUP_JOINED", "GROUP_ROSTER_UPDATE", "GROUP_LEFT", "PARTY_INVITE_REQUEST" }
local frame
local active = false
local members = {}
local inviteHooked = false

local function ShowRecord(key, template)
	local record = key and Notes.Records.Find(key)
	if record and (A.db.reminders == "all" or A.db.reminders == record.type) then
		local reason = record.reason ~= "" and record.reason or A.L.noReason
		A:NoteMessage(template:format(record.name .. "-" .. record.server, reason) .. A:RecordLink(key))
	end
end

local function OnInviteRequest(displayName, inviterGUID)
	local key
	if not (issecretvalue and issecretvalue(inviterGUID)) then
		local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(inviterGUID)
		key = A:PlayerKey(name, realm)
	end
	-- The event's realm flag has inconsistent names in the native contract and
	-- caller. Without GUID data, only an already-qualified name proves a realm.
	if not key and not (issecretvalue and issecretvalue(displayName)) and type(displayName) == "string" then
		local name, realm = displayName:match("^([^%-]+)%-(.+)$")
		if name then key = A:PlayerKey(name, realm) end
	end
	ShowRecord(key, NL.inviteReceived)
end

local function OnInviteSent(name)
	if not active then return end
	ShowRecord(A:PlayerKey(name), NL.inviteSent)
end

-- 原生单位只经 Core:UnitIdentity 入口读取身份,不先比较受限字符串。
local function MemberKeys()
	local keys, count = {}, 0
	local grouped = IsInGroup()
	local size = grouped and GetNumGroupMembers() or 0
	local function collect(unit)
		local key = A:UnitIdentity(unit)
		if key then
			keys[key] = true
			count = count + 1
		end
	end
	if IsInRaid() then
		for index = 1, size do collect("raid" .. index) end
	elseif grouped then
		collect("player")
		for index = 1, size - 1 do collect("party" .. index) end
	end
	return keys, count >= size
end

local function OnRosterUpdate()
	local seen, complete = MemberKeys()
	for key in pairs(seen) do
		if not members[key] then
			ShowRecord(key, NL.rosterHit)
		end
	end
	if complete then
		-- 完整花名册才能排除离开成员;离开后重入会再次成为新成员。
		members = seen
	else
		for key in pairs(seen) do members[key] = true end
	end
end

function Reminder.Start()
	if active then return end
	if not frame then
		frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, event, ...)
			if event == "GROUP_LEFT" then
				wipe(members)
			elseif event == "PARTY_INVITE_REQUEST" then
				local name, _, _, _, _, _, inviterGUID = ...
				OnInviteRequest(name, inviterGUID)
			else
				-- 真正入组、登录恢复和新成员就绪走同一路径;重复事件不重置去重。
				OnRosterUpdate()
			end
		end)
	end
	active = true
	if not inviteHooked then
		hooksecurefunc(C_PartyInfo, "InviteUnit", OnInviteSent)
		inviteHooked = true
	end
	for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
	OnRosterUpdate()
end

function Reminder.Stop()
	if not active then return end
	active = false
	for _, event in ipairs(EVENTS) do frame:UnregisterEvent(event) end
	wipe(members)
end
