-- 离线测试替身:仅覆盖 LycheeGroup 业务包实际使用的 API 面。
-- 不模拟渲染;Frame 只保留事件与脚本语义,便于用 FireEvent 驱动状态机。
local Stubs = {}

local function wipe(t)
	for k in pairs(t) do t[k] = nil end
end

local frames = {}

local FrameStub = {}
function FrameStub:RegisterEvent(event)
	self.events[event] = true
end

function FrameStub:UnregisterEvent(event)
	self.events[event] = nil
end

function FrameStub:SetScript(name, script)
	self.scripts[name] = script
end

function FrameStub:GetScript(name)
	return self.scripts[name]
end

function FrameStub:Show() self.shown = true end
function FrameStub:Hide() self.shown = false end
function FrameStub:IsShown() return self.shown end

-- 构造/布局类方法一律允许链式 no-op;业务测试不依赖几何。
local allowed = {
	SetSize = true, SetPoint = true, ClearAllPoints = true, SetAlpha = true,
	SetWidth = true, SetHeight = true, SetTextColor = true, SetText = true,
	SetFont = true, SetMaxLetters = true, SetMultiLine = true, SetAutoFocus = true,
	SetBackdrop = true, SetBackdropColor = true, SetBackdropBorderColor = true,
	SetScrollChild = true, SetVerticalScroll = true, SetMinMaxValues = true,
	SetValueStep = true, SetObeyStepOnDrag = true, SetValue = true, SetOrientation = true,
	SetThumbTexture = true, SetTexCoord = true, SetVertexColor = true, SetTexture = true,
	SetWordWrap = true, SetJustifyH = true, SetShown = true, RegisterForClicks = true,
	EnableMouseWheel = true, SetHitRectInsets = true, SetFrameStrata = true,
	SetFrameLevel = true, SetID = true, SetAllPoints = true, EnableMouse = true,
}

FrameStub.__index = function(table, key)
	local method = FrameStub[key]
	if method ~= nil then return method end
	if allowed[key] then return function() end end
	error("FrameStub: 未支持的方法 " .. tostring(key), 2)
end

local function CreateFrame(kind, name, parent, template)
	local f = {
		kind = kind, name = name, parent = parent, template = template,
		events = {}, scripts = {}, shown = false,
	}
	setmetatable(f, FrameStub)
	frames[#frames + 1] = f
	if name then _G[name] = f end
	return f
end

-- 把事件分发给所有注册了该事件的帧,返回触达的处理器数量。
function Stubs.FireEvent(event, ...)
	local count = 0
	for _, f in ipairs(frames) do
		if f.events[event] then
			local handler = f.scripts.OnEvent
			if handler then
				count = count + 1
				handler(f, event, ...)
			end
		end
	end
	return count
end

-- 找出当前注册了某事件的帧(断言事件生命周期用)。
function Stubs.FramesWithEvent(event)
	local out = {}
	for _, f in ipairs(frames) do
		if f.events[event] then out[#out + 1] = f end
	end
	return out
end

-- ---------------------------------------------------------------- 计时器

local timers = {}
local clock = 0

local C_Timer = {}
function C_Timer.After(delay, func)
	timers[#timers + 1] = { at = clock + delay, func = func }
end
function C_Timer.NewTimer(delay, func)
	local handle = { cancelled = false }
	function handle:Cancel() self.cancelled = true end
	timers[#timers + 1] = { at = clock + delay, func = func, handle = handle }
	return handle
end
function C_Timer.NewTicker(interval, func)
	local handle = { cancelled = false }
	function handle:Cancel() self.cancelled = true end
	timers[#timers + 1] = { at = clock + interval, func = func, interval = interval, handle = handle }
	return handle
end

function Stubs.AdvanceClock(seconds)
	clock = clock + seconds
	local due = {}
	for i = #timers, 1, -1 do
		if timers[i].at <= clock then
			due[#due + 1] = table.remove(timers, i)
		end
	end
	for _, t in ipairs(due) do
		if t.handle and t.handle.cancelled then
			-- 已取消:跳过执行。
		else
			t.func()
			if t.interval and not (t.handle and t.handle.cancelled) then
				t.at = clock + t.interval
				timers[#timers + 1] = t
			end
		end
	end
end

function Stubs.PendingTimers()
	local n = 0
	for _, t in ipairs(timers) do
		if not (t.handle and t.handle.cancelled) then n = n + 1 end
	end
	return n
end

-- ---------------------------------------------------------------- 单位与身份

local units = {}

local function UnitExists(unit) return units[unit] ~= nil end
local function UnitFullName(unit)
	local u = units[unit]
	if not u then return nil end
	return u.name, u.realm
end
local function UnitName(unit)
	local u = units[unit]
	if not u then return nil end
	return u.name
end
local function GetUnitName(unit, showServer)
	local u = units[unit]
	if not u then return nil end
	if showServer and u.realm and u.realm ~= "" then return u.name .. "-" .. u.realm end
	return u.name
end
local function UnitIsUnit(a, b)
	return units[a] ~= nil and units[a] == units[b]
end
local function UnitClassBase(unit)
	local u = units[unit]
	return u and u.class or nil, u and u.localizedClass or nil
end
local function UnitGUID(unit)
	local u = units[unit]
	return u and u.guid or nil
end
local function GetNumGroupMembers()
	local n = 0
	for name in pairs(units) do
		if name == "player" or name:match("^party%d+$") or name:match("^raid%d+$") then n = n + 1 end
	end
	return n
end

local function IsInRaid()
	return units["raid1"] ~= nil
end

local function IsInGroup()
	if units["player"] == nil then return false end
	return IsInRaid() or units["party1"] ~= nil
end

local function UnitIsPlayer(unit)
	local u = units[unit]
	return u ~= nil and u.isPlayer ~= false
end

-- 职业目录:两职业×两专精的最小目录,覆盖 PlayerInfo 的"职业-专精"拼接。
local CLASS_CATALOG = {
	[1] = { name = "战士", file = "WARRIOR", specs = { [71] = "武器", [72] = "狂怒" } },
	[2] = { name = "圣骑士", file = "PALADIN", specs = { [66] = "神圣", [70] = "惩戒" } },
}

local function GetNumClasses()
	return #CLASS_CATALOG
end

local function GetClassInfo(index)
	local entry = CLASS_CATALOG[index]
	if not entry then return nil end
	return entry.name, entry.file, index
end

local function UnitClass(unit)
	local u = units[unit]
	if not u or not u.classID then return nil end
	local entry = CLASS_CATALOG[u.classID]
	if not entry then return nil end
	return entry.name, entry.file, u.classID
end

local C_SpecializationInfo = {}
function C_SpecializationInfo.GetNumSpecializationsForClassID(classID)
	local entry = CLASS_CATALOG[classID]
	return entry and 2 or 0
end

local function GetSpecializationInfoForClassID(classID, index)
	local entry = CLASS_CATALOG[classID]
	if not entry then return nil end
	local count = 0
	for specID, specName in pairs(entry.specs) do
		count = count + 1
		if count == index then
			return specID, specName, nil, 100000 + specID
		end
	end
	return nil
end

function Stubs.SetUnit(unit, info) units[unit] = info end
function Stubs.ClearUnits() wipe(units) end

-- ---------------------------------------------------------------- 检视

local inspectSpecs = {}
local inspectRequests = {}

local function GetInspectSpecialization(unit)
	return inspectSpecs[unit] or 0
end
C_SpecializationInfo.GetInspectSpecialization = GetInspectSpecialization

local function NotifyInspect(unit)
	inspectRequests[#inspectRequests + 1] = unit
	return true
end

function Stubs.SetInspectSpec(unit, specID) inspectSpecs[unit] = specID end
function Stubs.InspectRequests() return inspectRequests end

-- ---------------------------------------------------------------- 环境安装

function Stubs.Reset()
	wipe(frames)
	wipe(timers)
	clock = 0
end

function Stubs.Install(overrides)
	Stubs.Reset()
	wipe(units)
	wipe(inspectSpecs)
	wipe(inspectRequests)
	_G.LycheeGroup = nil
	_G.LycheeGroupDB = nil
	_G.LycheeGroupPrefsDB = nil
	_G.LycheeGroupGroupDB = nil
	_G.LycheeGroupCharacterDB = nil
	_G.LycheeGroupNotesDB = nil
	local locale = (overrides and overrides.locale) or "zhCN"
	local realm = (overrides and overrides.realm) or "测试服"

	local fakeTime = nil
	local function Now()
		return fakeTime or os.time()
	end
	Stubs.SetTime = function(t) fakeTime = t end

	local chatLog = {}
	local chatFrame = {
		AddMessage = function(_, message)
			chatLog[#chatLog + 1] = message
		end,
	}
	local partyInvites = {}
	Stubs.PartyInvites = function() return partyInvites end
	local function Pack(...) return {n=select("#",...),...} end

	local env = {
		CONQUEST_SIZES = {1,1,2,3,10},
		MAX_RAID_MEMBERS = 40,
		GetLocale = function() return locale end,
		GetRealmName = function() return realm end,
		GetNormalizedRealmName = function() return (realm:gsub("%s+", "")) end,
		CreateFrame = CreateFrame,
		C_Timer = C_Timer,
		C_SpecializationInfo = C_SpecializationInfo,
		UnitExists = UnitExists,
		UnitFullName = UnitFullName,
		UnitName = UnitName,
		GetUnitName = GetUnitName,
		UnitIsUnit = UnitIsUnit,
		UnitIsPlayer = UnitIsPlayer,
		UnitClassBase = UnitClassBase,
		UnitFactionGroup = function(unit) return units[unit] and units[unit].faction or "Alliance" end,
		PLAYER_FACTION_GROUP = { [0]="Horde",[1]="Alliance",Horde=0,Alliance=1 },
		C_CreatureInfo = {
			GetRaceInfo = function(id)
				local race = ({[1]={"人类","Human"},[2]={"兽人","Orc"},[24]={"熊猫人","Pandaren"}})[id]
				return race and {raceID=id,raceName=race[locale=="zhCN" and 1 or 2]}
			end,
			GetFactionInfo = function(id)
				local tag = ({[1]="Alliance",[2]="Horde",[24]="Neutral"})[id]
				return tag and {groupTag=tag}
			end,
		},
		UnitGroupRolesAssigned = function(unit) return units[unit] and units[unit].role or "NONE" end,
		UnitIsGroupLeader = function(unit) return units[unit] and units[unit].leader == true end,
		GetNumSubgroupMembers = function() local n=0;for key in pairs(units) do if key:match("^party%d+$") then n=n+1 end end;return n end,
		UnitClass = UnitClass,
		UnitGUID = UnitGUID,
		GetPlayerInfoByGUID = function(guid)
			for _, info in pairs(units) do
				if info.guid == guid then return nil, nil, nil, nil, nil, info.name, info.realm end
			end
		end,
		GetNumGroupMembers = GetNumGroupMembers,
		GetRaidRosterInfo = function(index) local unit=units["raid"..index];if unit then return unit.name,0,unit.subgroup or 1 end end,
		IsInGroup = IsInGroup,
		IsInRaid = IsInRaid,
		GetNumClasses = GetNumClasses,
		GetClassInfo = GetClassInfo,
		GetSpecializationInfoForClassID = GetSpecializationInfoForClassID,
		GetSpecializationInfoByID = function(id)
			local roles={[65]="HEALER",[66]="TANK",[70]="DAMAGER",[71]="DAMAGER",[72]="DAMAGER",[73]="TANK"}
			return id,"Specialization",nil,100000+id,roles[id]
		end,
		GetInspectSpecialization = GetInspectSpecialization,
		NotifyInspect = NotifyInspect,
		time = Now,
		wipe = wipe,
		IsAddOnLoaded = function() return false end,
		LoadAddOn = function() return false end,
		C_AddOns = {
			IsAddOnLoaded = function() return false, false end,
			LoadAddOn = function() return false end,
		},
		C_PartyInfo = { InviteUnit = function(name) partyInvites[#partyInvites + 1] = name end },
		hooksecurefunc = function(owner, method, callback)
			local original = owner[method]
			owner[method] = function(...)
				local results = Pack(original(...))
				callback(...)
				return unpack(results,1,results.n)
			end
		end,
		SlashCmdList = {},
		C_LFGList = {
			HasActiveEntryInfo = function() return false end,
			GetApplications = function() return {} end,
		},
		C_ChallengeMode = { IsChallengeModeActive = function() return false end },
		LinkUtil = {
			RegisterLinkHandler = function() end,
		},
		DEFAULT_CHAT_FRAME = chatFrame,
	}
	for k, v in pairs(env) do _G[k] = v end
	Stubs.ChatMessages = function() return chatLog end
	return env
end

_G.TestStubs = Stubs
return Stubs
