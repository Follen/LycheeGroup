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
-- 无法解析身份的条目隔离。缺失、非有限或无法显示的时间记 0,由迁移按时间合并同键。
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
		timestamp = Notes.Records.TimestampOf(data),
		reason = reason,
		classSpec = classSpec,
		type = data.type == "positive" and "positive" or data.type == "caution" and "caution" or "neutral",
		class = type(data.class) == "string" and data.class or nil,
		specID = type(data.specID) == "number" and data.specID or nil,
	}
end

-- 损坏项移出活动名单，保留原值和来源键供恢复；正常记录不复制。
local function Quarantine(raw, key, value, reason)
	if type(raw.invalidRecords) ~= "table" then raw.invalidRecords = { previous = raw.invalidRecords } end
	local invalid = raw.invalidRecords
	invalid[#invalid + 1] = { key = key, value = value, error = reason }
end

local function IsStoredRecord(key, record)
	if type(key) ~= "string" or type(record) ~= "table"
		or type(record.name) ~= "string" or type(record.server) ~= "string"
		or (record.reason ~= nil and type(record.reason) ~= "string")
		or (record.classSpec ~= nil and type(record.classSpec) ~= "string") then return false end
	return A:PlayerKey(record.name, record.server) == key
end

-- Initialize():装载 LycheeGroupNotesDB,旧结构迁移到 schema=3,核对 Core 摘要并启动提醒。
function Notes:Initialize()
	if self.db then return end
	A:LoadDB()
	local raw = _G.LycheeGroupNotesDB
	if type(raw) ~= "table" then
		local original = raw
		raw = {}
		_G.LycheeGroupNotesDB = raw
		if original ~= nil then Quarantine(raw,"$root",original,"LycheeGroupNotesDB must be a table") end
	end
	local source = raw.records
	if type(source) ~= "table" then
		if source ~= nil then Quarantine(raw, "records", source) end
		source = {}
		raw.records = source
	end
	if raw.schema == 2 or raw.schema == SCHEMA then
		-- 仅装载时扫描一次；schema=3 也需修复旧版本已存入的异常时间。
		for key, record in pairs(source) do
			if IsStoredRecord(key, record) then
				record.timestamp = self.Records.TimestampOf(record)
				record.type = record.type or "neutral"
				record.reason = record.reason or ""
				record.classSpec = record.classSpec or ""
			else
				Quarantine(raw, key, record)
				source[key] = nil
			end
		end
		raw.schema = SCHEMA
	else
		local migrated = {}
		for key, data in pairs(source) do
			local record = NormalizeRecord(key, data)
			if record then
				local newKey = record.name .. "-" .. record.server
				local existing = migrated[newKey]
				if not existing or record.timestamp >= (existing.timestamp or 0) then
					migrated[newKey] = record
				end
			else
				Quarantine(raw, key, data)
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
	if A:GetSetting("notesEnabled") and A:GetSetting("reminders") ~= "off" and A.db.notesHasRecords then
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
