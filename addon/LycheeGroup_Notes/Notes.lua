-- 玩家记录服务:存档装载与迁移、生命周期入口。
-- 记录数据唯一真源在 Records.lua(records[playerKey]);本文件不直接管理记录内容。
local A = _G.LycheeGroup

local Notes = {}
A.Notes = Notes
Notes.L = A.NotesLocale

local SCHEMA = 3

local function Trim(value)
	if type(value) ~= "string" then return "" end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 旧记录清洗(语义对齐 LycheeNote NormalizeRecord):
-- 名字/服务器拆分经统一身份入口;空理由存语义空串;classSpec 保留原值不猜测(空串=尚未获取);
-- 无法解析身份的条目丢弃,不静默改写。时间戳缺失记 0,由迁移按时间合并同键。
local function NormalizeRecord(key, data)
	if type(data) ~= "table" then return nil end
	local name = type(data.name) == "string" and data.name or tostring(key)
	local server = type(data.server) == "string" and data.server or nil
	local recordKey, cleanName, cleanServer = A:PlayerKey(name, server)
	if not recordKey then return nil end
	local reason = Trim(data.reason)
	local classSpec = Trim(data.classSpec)
	return {
		name = cleanName,
		server = cleanServer,
		timestamp = type(data.timestamp) == "number" and data.timestamp or 0,
		reason = reason,
		classSpec = classSpec,
		type = data.type == "positive" and "positive" or data.type == "caution" and "caution" or "neutral",
		class = type(data.class) == "string" and data.class or nil,
		specID = type(data.specID) == "number" and data.specID or nil,
	}
end

-- Initialize():装载 LycheeGroupNotesDB,旧结构迁移到 schema=3,核对 Core 摘要并启动提醒。
function Notes:Initialize()
	if self.db then return end
	A:LoadDB()
	local raw = _G.LycheeGroupNotesDB
	if type(raw) ~= "table" then
		raw = {}
		_G.LycheeGroupNotesDB = raw
	end
	local source = type(raw.records) == "table" and raw.records or {}
	if raw.schema == 2 then
		for _, record in pairs(source) do record.type = record.type or "neutral" end
		raw.schema = SCHEMA
	elseif raw.schema ~= SCHEMA then
		local migrated = {}
		for key, data in pairs(source) do
			local record = NormalizeRecord(key, data)
			if record then
				local newKey = record.name .. "-" .. record.server
				local existing = migrated[newKey]
				if not existing or record.timestamp >= (existing.timestamp or 0) then
					migrated[newKey] = record
				end
			end
		end
		raw.records = migrated
		raw.schema = SCHEMA
	end
	self.db = raw
	self.Records.Bind(raw)
	A.db.notesHasRecords = (next(raw.records) ~= nil)
	self:SyncEnabled()
end

-- SyncEnabled():开/停提醒订阅;记录管理与导入导出不受此开关影响。
function Notes:SyncEnabled()
	local reminder = self.RosterReminder
	if not reminder then return end
	if A.db.notesEnabled and A.db.reminders ~= "off" and A.db.notesHasRecords then
		reminder.Start()
	else
		reminder.Stop()
	end
end

-- Core 命令入口合同:notes:Add(name, realm, reason, unit) -> true, record | false, errText。
-- preClassSpec 为可选的调用方已取得职业专精串;给出时不再查询。
function Notes:Add(name, realm, reason, unit, preClassSpec, details)
	return self.Records.Add(name, realm, reason, unit, preClassSpec, details)
end
