-- 记录存储:持久唯一真源 records[playerKey] = {name, server, timestamp, reason, classSpec}。
-- Add/Edit/Remove/Merge 不打印;结果返回调用方,变更发布给订阅者(界面/列表标记),摘要与提醒生命周期经 Notes 同步。
local A = _G.LycheeGroup
local Notes = A.Notes
local NL = Notes.L

local Records = {}
Notes.Records = Records

-- 语义值:记录时未取得职业专精。空串让数据不随界面语言变化;
-- LN- 导入旧端会把空 classSpec 规范化为其自身"尚未获取"文本,互通不受影响。
Records.SPEC_PENDING = ""

local DB -- 由 Notes:Initialize 经 Bind 注入的存档表
local subscribers = {}
-- One stored key per folded identity; only legacy collisions need a key array.
-- Records and their display names stay in the original saved table.
local identities = {}
local totalCount, positiveCount, neutralCount, cautionCount = 0, 0, 0, 0

local function CountType(kind, delta)
	kind = kind or "neutral"
	if kind == "positive" then positiveCount = positiveCount + delta
	elseif kind == "neutral" then neutralCount = neutralCount + delta
	elseif kind == "caution" then cautionCount = cautionCount + delta end
end

local function CountRecord(record, delta)
	if not record then return end
	totalCount = totalCount + delta
	CountType(record.type, delta)
end

local function Trim(value)
	if type(value) ~= "string" then return "" end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function FiniteTimestampOf(record)
	local value = type(record) == "table" and record.timestamp
	if type(value) == "number" and value == value and value > -math.huge and value < math.huge then return value end
	return 0
end
local function TimestampOf(record)
	local value = FiniteTimestampOf(record)
	if value > 0 then
		local ok, text = pcall(date, "%y/%m/%d", value)
		if not ok or type(text) ~= "string" then return 0 end
	end
	return value
end
-- 初始化迁移与合并共用时间边界；非数字、非有限或无法显示的时间记为未知。
Records.TimestampOf = TimestampOf

local function Identity(key)
	if type(key) ~= "string" or issecretvalue and issecretvalue(key) then return nil end
	if C_Intl and C_Intl.FoldCase then
		local ok, folded = pcall(C_Intl.FoldCase, key)
		if ok and type(folded) == "string" and folded ~= "" then return folded end
	end
	return key:lower()
end

local function Precedes(key, other)
	local timestamp, previous = FiniteTimestampOf(DB.records[key]), FiniteTimestampOf(DB.records[other])
	return timestamp > previous or timestamp == previous and key < other
end

local function Preferred(keys)
	local best = keys[1]
	for index = 2, #keys do if Precedes(keys[index], best) then best = keys[index] end end
	return best
end

local function Index(key, isNew)
	local identity = Identity(key)
	local current = identities[identity]
	if not current then identities[identity] = key
	elseif type(current) == "string" then
		if current ~= key then
			local keys = {current, key}
			keys.preferred = Precedes(key, current) and key or current
			identities[identity] = keys
		end
	else
		if isNew then
			current[#current + 1] = key
			if Precedes(key, current.preferred) then current.preferred = key end
		else current.preferred = Preferred(current) end
	end
end

local function DefaultKey(key)
	local identity = Identity(key)
	local indexed = identity and identities[identity]
	return type(indexed) == "table" and indexed.preferred or indexed
end

-- Exact keys keep every legacy collision independently editable/removable.
local function StoredKey(key)
	if type(key) ~= "string" or issecretvalue and issecretvalue(key) then return nil end
	if DB.records[key] then return key end
	return DefaultKey(key)
end

local function Publish(kind, key)
	for _, callback in ipairs(subscribers) do
		callback(kind, key)
	end
end

-- 同步 Core 摘要;有/无记录翻转时驱动提醒启停,其余写入不产生额外工作。
local function SyncSummary()
	local has = next(DB.records) ~= nil
	if A.db.notesHasRecords == has then return end
	A.db.notesHasRecords = has
	Notes:SyncEnabled()
end

-- 存档注入(Initialize 专用;此前本服务不可用)。
function Records.Bind(db)
	DB = db
	identities = {}
	totalCount, positiveCount, neutralCount, cautionCount = 0, 0, 0, 0
	for key, record in pairs(DB.records) do Index(key, true); CountRecord(record, 1) end
end

function Records.GetCounts()
	return totalCount, positiveCount, neutralCount, cautionCount
end

-- Subscribe(fn(kind, keyOrKeys)):add/edit/remove 携带单个 key;
-- merge 携带本批实际变更的唯一 key 数组,无变化不通知。
-- 返回退订函数;订阅者仅为实际消费者(界面页、列表标记)。
function Records.Subscribe(callback)
	if type(callback) ~= "function" then return function() end end
	subscribers[#subscribers + 1] = callback
	local active=true
	return function()
		if not active then return end
		active=false
		for index, fn in ipairs(subscribers) do
			if fn == callback then
				table.remove(subscribers, index)
				return
			end
		end
	end
end

-- Find(playerKey) -> record | nil, storedKey:精确键优先,别名经身份索引点查。
function Records.Find(playerKey)
	local key = StoredKey(playerKey)
	return key and DB.records[key] or nil, key
end

-- List(query) -> playerKey[]:时间倒序,同时间按键升序保持稳定。
-- query={text=名或理由子串(不区分大小写)} 时过滤;排序仅在调用时临时进行,不维护常驻索引。
function Records.List(query)
	local text
	if type(query) == "table" and type(query.text) == "string" then
		text = Trim(query.text):lower()
	end
	local keys = {}
	for key, record in pairs(DB.records) do
		if (not query or not query.type or query.type == record.type) and (text == nil or text == ""
			or record.name:lower():find(text, 1, true)
			or record.reason:lower():find(text, 1, true)
			or record.server:lower():find(text, 1, true)) then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, function(a, b)
		local ta, tb = FiniteTimestampOf(DB.records[a]), FiniteTimestampOf(DB.records[b])
		if ta ~= tb then return ta > tb end
		return a < b
	end)
	return keys
end

-- Add(name, realm, reason, unit, preClassSpec) -> true, record | false, errText。
-- 不记录自己;空理由存空串,展示时本地化;
-- unit 给出且 preClassSpec=nil 时取同步快照;显式空串表示已查询但未知,不重读单位。
function Records.Add(name, realm, reason, unit, preClassSpec, details)
	local key, cleanName, server = A:PlayerKey(name, realm)
	if not key then
		return false, NL.badIdentity
	end
	local selfKey = A:UnitIdentity("player")
	if selfKey and Identity(selfKey) == Identity(key) then
		return false, NL.selfRecord
	end
	-- 名字与 token 可能在等待检视期间分离;写入边界只允许匹配身份的同步快照。
	if unit and Identity(A:UnitIdentity(unit)) ~= Identity(key) then unit = nil end
	key = DefaultKey(key) or key
	local existing = DB.records[key]
	if existing then cleanName, server = existing.name, existing.server end
	local cleanReason = Trim(reason)
	local classSpec = Trim(preClassSpec)
	local captured
	if preClassSpec == nil and unit then
		classSpec, captured = Notes.PlayerInfo.Snapshot(unit)
		classSpec = classSpec or Records.SPEC_PENDING
	end
	local class = details and details.class or captured and captured.class
	local specID
	if details and details.class then specID = details.specID
	else specID = details and details.specID or captured and captured.specID end
	local playerInfo = Notes.PlayerInfo.ResolveRecord({class=class, specID=specID, classSpec=classSpec})
	local record = {
		name = cleanName,
		server = server,
		timestamp = time(),
		reason = cleanReason,
		classSpec = playerInfo.classSpec,
		type = details and details.type or A:GetSetting("defaultNote"),
		class = playerInfo.class,
		specID = playerInfo.specID,
	}
	CountRecord(existing, -1)
	DB.records[key] = record
	CountRecord(record, 1)
	Index(key, existing == nil)
	Publish("add", key)
	SyncSummary()
	return true, record
end

-- Edit(playerKey, reason) -> true | false:改写理由,空理由存语义空串;不改动记录时间。
function Records.Edit(playerKey, reason, details)
	playerKey = StoredKey(playerKey)
	local record = DB.records[playerKey]
	if not record then return false end
	local cleanReason = Trim(reason)
	record.reason = cleanReason
	if details then
		local previousType = record.type
		record.type = details.type
		record.class, record.specID, record.classSpec = details.class, details.specID, details.classSpec or ""
		if previousType ~= record.type then CountType(previousType, -1); CountType(record.type, 1) end
	end
	Publish("edit", playerKey)
	return true
end

-- Remove(playerKey) -> true | false。
function Records.Remove(playerKey)
	playerKey = StoredKey(playerKey)
	local record = DB.records[playerKey]
	if not record then return false end
	DB.records[playerKey] = nil
	CountRecord(record, -1)
	local identity = Identity(playerKey)
	local indexed = identities[identity]
	if type(indexed) == "table" then
		for index, key in ipairs(indexed) do if key == playerKey then table.remove(indexed, index); break end end
		if #indexed == 1 then identities[identity] = indexed[1]
		else indexed.preferred = Preferred(indexed) end
	else identities[identity] = nil end
	Publish("remove", playerKey)
	SyncSummary()
	return true
end

-- Merge(records) -> changed, invalid:LN- 合并语义(与 LycheeNote 互通)。
-- 本地无 → 新增;导入 timestamp 更晚 → 覆盖;相同或更早 → 保留本地(重复导入同一有效记录写入 0);
-- 无效身份与当前角色条目计入 invalid;不静默截断其他合法条目。
function Records.Merge(records)
	if type(records) ~= "table" then return 0, 0 end
	local changed, invalid = 0, 0
	local changedKeys, changedSet = {}, {}
	local selfIdentity = Identity(A:UnitIdentity("player"))
	for _, item in ipairs(records) do
		if type(item) ~= "table" then
			invalid = invalid + 1
		else
			local key, cleanName, cleanServer = A:PlayerKey(item.name, item.server)
			if not key or selfIdentity and Identity(key) == selfIdentity then
				invalid = invalid + 1
			else
				key = DefaultKey(key) or key
				local timestamp = TimestampOf(item)
				-- 旧文本没有时间时保留未知值;每次重导不能把旧记录变成新记录。
				if timestamp <= 0 then timestamp = 0 end
				local current = DB.records[key]
				if current then cleanName, cleanServer = current.name, current.server end
				local currentTimestamp = TimestampOf(current)
				if current then current.timestamp = currentTimestamp end
				if not current or timestamp > currentTimestamp then
					local record = {
						name = cleanName,
						server = cleanServer,
						timestamp = timestamp,
						reason = Trim(item.reason),
						classSpec = Trim(item.classSpec),
						type = item.type == "positive" and "positive" or item.type == "caution" and "caution" or "neutral",
						class = type(item.class) == "string" and item.class or nil,
						specID = type(item.specID) == "number" and item.specID or nil,
					}
					CountRecord(current, -1)
					DB.records[key] = record
					CountRecord(record, 1)
					Index(key, current == nil)
					changed = changed + 1
					if not changedSet[key] then
						changedSet[key] = true
						changedKeys[#changedKeys + 1] = key
					end
				end
			end
		end
	end
	if changed > 0 then
		Publish("merge", changedKeys)
		SyncSummary()
	end
	return changed, invalid
end

-- 公开合同:查询与变更接口直接挂在 A.Notes 上(Architecture 的唯一读写入口),
-- 与 Notes:Add 命令包装共用同一命名层;内部经 Records 表组织实现,此处以冒号方法适配调用方。
function Notes:Find(playerKey) return self.Records.Find(playerKey) end
function Notes:List(query) return self.Records.List(query) end
function Notes:GetCounts() return self.Records.GetCounts() end
function Notes:Edit(key, reason, details) return self.Records.Edit(key, reason, details) end
function Notes:Remove(key) return self.Records.Remove(key) end
function Notes:Merge(records) return self.Records.Merge(records) end
function Notes:Subscribe(callback) return self.Records.Subscribe(callback) end
