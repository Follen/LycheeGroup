-- 大秘境历史(每角色):开始/完成事件驱动;活动期间才监听队伍变化,结束即退订,无周期扫描。
-- activeRun 基线与已完成 runs 都由角色存档持有;成员含自己并标注 isSelf。
local A = _G.LycheeGroup
local G = A.Group
local History = {}
G.History = History

local pending -- 指向 charDB.activeRun,不另留一份可丢失的内存基线。

local UNITS = { "player", "party1", "party2", "party3", "party4" }

local function Specialization(unit)
	local guid = G.Public(UnitGUID(unit))
	return G.Roster:GetUnitSpec(unit, guid, unit == "player")
end

-- 采集 player+party1..4;按 key 去重,已记录成员只补齐先前未取得的专精。
local function CollectMembers(members, order)
	for _, unit in ipairs(UNITS) do
		local key, name, realm = A:UnitIdentity(unit)
		if key then
			local member = members[key]
			if member then
				if member.specID == nil then member.specID = Specialization(unit) end
			else
				local class = UnitClassBase(unit)
				if issecretvalue and issecretvalue(class) then class = nil end
				members[key] = {
					key = key,
					name = name,
					realm = realm,
					class = class,
					specID = Specialization(unit),
					isSelf = unit == "player",
				}
				order[#order + 1] = key
			end
		end
	end
end

local function MapName(mapID)
	if not mapID then return nil end
	local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
	return ok and name or nil
end

local function KeyLevel()
	if not C_ChallengeMode.GetActiveKeystoneInfo then return nil end
	local ok, level = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
	if ok and level and level > 0 then return level end
	return nil -- 取不到层数记 nil,不猜测
end

local function MembersArray(source)
	local members = {}
	for index, key in ipairs(source.order) do
		members[index] = source.members[key]
	end
	return members
end

local function RunID()
	return ("%d-%06d"):format(time(), math.random(100000, 999999))
end

local function StartRun(mapID, startedAt)
	pending = {
		id = RunID(),
		startedAt = startedAt,
		mapChallengeModeID = mapID,
		mapName = MapName(mapID),
		level = KeyLevel(),
		members = {},
		order = {},
	}
	G.charDB.activeRun = pending
	CollectMembers(pending.members, pending.order)
	G.Game:EnableRunTracking()
	G:Notify("history")
end

-- 未完成即离开(无完成事件):丢弃待定 run,不写入历史。
function History:Discard()
	if not pending and not G.charDB.activeRun then return end
	pending = nil
	G.charDB.activeRun = nil
	G.Game:DisableRunTracking()
	G:Notify("history")
end

-- START 接管当前秘境;同一次冷启动交接幂等,重置由 RESET 清理旧基线。
function History:OnStart()
	if not A:GetSetting("history") then return end
	-- 事件的 mapID 不是历史存储合同;以当前活动秘境的 challenge map 身份为准。
	if not C_ChallengeMode.IsChallengeModeActive() then return end
	local activeID = C_ChallengeMode.GetActiveChallengeMapID()
	if not activeID then return end
	local level = KeyLevel()
	-- 冷启动 Restore 与首次 START 交接指向同一 run;RESET 已清理的下一轮才重建。
	if pending and pending.mapChallengeModeID == activeID
		and (pending.level == nil or level == nil or pending.level == level) then
		if pending.level == nil then pending.level = level end
		CollectMembers(pending.members, pending.order)
		return
	end
	StartRun(activeID, time())
end

function History:OnRosterUpdate()
	if not pending then return end
	-- 完成/切图中的队伍事件不把其他场景的成员写入本次 run。
	if not C_ChallengeMode.IsChallengeModeActive()
		or C_ChallengeMode.GetActiveChallengeMapID() ~= pending.mapChallengeModeID then return end
	CollectMembers(pending.members, pending.order)
end

-- Late library/inspect data may arrive while the run is still active. Fill only
-- the matching member's missing snapshot; completed runs remain immutable.
function History:OnSpecUpdate(key, specID)
	if not pending or not key then return end
	specID = G.Public(specID)
	if type(specID) ~= "number" or specID <= 0 then return end
	local member = pending.members[key]
	if member and member.specID == nil then member.specID = specID end
end

function History:OnWorldEntered()
	if not pending then return end
	if not C_ChallengeMode.IsChallengeModeActive()
		or C_ChallengeMode.GetActiveChallengeMapID() ~= pending.mapChallengeModeID then
		self:Discard()
		return
	end
	CollectMembers(pending.members, pending.order)
end

-- CHALLENGE_MODE_COMPLETED(无载荷):终态前最后采集一次,写入历史。
function History:OnCompleted()
	if not pending then return end
	CollectMembers(pending.members, pending.order)
	local run = {
		id = pending.id,
		startedAt = pending.startedAt,
		completedAt = time(),
		mapChallengeModeID = pending.mapChallengeModeID,
		mapName = pending.mapName,
		level = pending.level,
		members = MembersArray(pending),
	}
	G.charDB.runs[#G.charDB.runs + 1] = run
	pending = nil
	G.charDB.activeRun = nil
	G.Game:DisableRunTracking()
	G:Notify("history")
end

-- 活动中重登复用持久基线;首次接管的原生 run 才以接管时刻建立记录。
function History:Restore()
	if not A:GetSetting("history") then self:Discard(); return end
	local activeID = C_ChallengeMode.GetActiveChallengeMapID()
	if not C_ChallengeMode.IsChallengeModeActive() or not activeID then
		self:Discard()
		return
	end
	local saved = G.charDB.activeRun
	local level = KeyLevel()
	if saved and saved.mapChallengeModeID == activeID
		and (saved.level == nil or level == nil or saved.level == level) then
		pending = saved
		if pending.level == nil then pending.level = level end
		CollectMembers(pending.members, pending.order)
		G.Game:EnableRunTracking()
		return
	end
	StartRun(activeID, time())
end

-- GetHistory() → run 数组(完成时间倒序);追加序即完成序,倒序即最新在前。
function History:GetHistory()
	local runs = G.charDB.runs
	local list = {}
	for index = #runs, 1, -1 do
		list[#list + 1] = runs[index]
	end
	return list
end

-- 进行中的 run 快照(只读);无活动时为 nil。
function History:GetActiveRun()
	if not pending then return nil end
	return {
		id = pending.id,
		startedAt = pending.startedAt,
		mapChallengeModeID = pending.mapChallengeModeID,
		mapName = pending.mapName,
		level = pending.level,
		members = MembersArray(pending),
	}
end
