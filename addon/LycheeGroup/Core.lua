-- Lychee Group 微核心:命名空间、小设置、加载器、统一玩家身份与输出入口。
-- 本文件不实现组队或笔记业务;业务由按需包在 Ensure 后接入。
local A = _G.LycheeGroup
if not A then
	A = {}
	_G.LycheeGroup = A
end

A.MODULES = {
	Group = "LycheeGroup_Group",
	Notes = "LycheeGroup_Notes",
	UI = "LycheeGroup_UI",
}

-- 页面 → 进入页面前必须就绪的业务模块。
local PAGE_BUSINESS = {
	find = "Group",
	create = "Group",
	notes = "Notes",
	settings = nil,
}

local DEFAULTS = {
	schema = 1,
	notesEnabled = true,
	notesHasRecords = false,
	askReason = true,
	reduceMotion = false,
	nativeLFGEntry = false,
	minimap = true,
	minimapAngle = 225,
	font = "default",
	fontScale = 100,
	showImportantFilters = false,
	language = "auto",
	autoJoin = false,
	relations = true,
	noteMarks = true,
	defaultNote = "neutral",
	reminders = "all",
	history = true,
	raidMembers = "shift",
	floating = true,
	floatingCompatibility = true,
	floatingLocked = false,
	floatingScale = 130,
	uiScale = 100,
	memberIconShape = "circle",
	memberClassBorder = true,
	memberLeaderMark = true,
	memberIconScale = 100,
}

local CHARACTER_DEFAULTS = { rememberFilters = true, defaultSort = "newest" }

local function FontScale(value)
 value=tonumber(value)
 if not value or value~=value then return 100 end
 return math.max(70,math.min(130,math.floor(value+.5)))
end

-- Core owns setting defaults and lifecycle effects; Configuration owns provenance.
function A:RegisterConfigurationSettings()
 local definitions={}
 local choices={language={"auto","zhCN","enUS"},defaultNote={"positive","neutral","caution"},reminders={"all","positive","caution","off"},raidMembers={"shift","alt","ctrl","always"},memberIconShape={"circle","square"},defaultSort={"newest","rating","itemLevel","members"}}
 local ranges={fontScale={70,130},uiScale={75,125},floatingScale={50,150},memberIconScale={75,175},minimapAngle={0,360}}
 local function Add(key,value,storage)
  local definition={default=value,storage=storage,type=type(value),legacy={storage=storage,key=key},enum=choices[key]}
  local range=ranges[key];if range then definition.min,definition.max=range[1],range[2];definition.integer=key~="minimapAngle" end
  if key=="font" then definition.validate=function(path) return path~="","font path must not be empty" end end
  if key=="fontScale" then definition.import=function(account)
   if account.fontScale~=nil then return FontScale(account.fontScale),true end
  end end
  if storage=="character" then definition.import=function(account,character)
   if character[key]~=nil then return character[key],true end
   if account[key]~=nil then return account[key],true end
  end end
  definitions["settings."..key]=definition
 end
 for key,value in pairs(DEFAULTS) do if key~="schema" and key~="notesHasRecords" then Add(key,value,"account") end end
 for key,value in pairs(CHARACTER_DEFAULTS) do Add(key,value,"character") end
 return self.Configuration:RegisterDefinitions(definitions)
end

local initialized = {}
local loading = {}

-- ---------------------------------------------------------------- 存档

function A:LoadDB()
	if self.db then return end
	local raw = _G.LycheeGroupDB
	if type(raw) ~= "table" then
		raw = {}
		_G.LycheeGroupDB = raw
	end
	self.db = raw
	local prefs = _G.LycheeGroupPrefsDB
	if type(prefs) ~= "table" then
		prefs = {}
		_G.LycheeGroupPrefsDB = prefs
	end
	self.charPrefs = prefs
	-- Bind captures real legacy presence before the compatibility fields are filled.
	self.Configuration:Bind(raw,prefs)
	for key, value in pairs(DEFAULTS) do
		if raw[key] == nil then raw[key] = value end
	end
	raw.applicantSound, raw.applicantTone, raw.soundVolume = nil, nil, nil
	raw.schema = DEFAULTS.schema
	raw.keywordFilters = nil
	raw.fontScale = FontScale(raw.fontScale)
	self:InitializeLocale()
	for key, default in pairs(CHARACTER_DEFAULTS) do
		if prefs[key] == nil then
			local value = raw[key]
			if value == nil then value = default end
			prefs[key] = value
		end
	end
	prefs.schema = 1
	self.charPrefs = prefs
end

-- ---------------------------------------------------------------- 加载器

-- Ensure('Group'|'Notes'|'UI') -> module | nil, errorText
-- 加载成功后调用模块 Initialize() 一次;失败说明原因,不重试。
function A:Ensure(module)
	local name = self.MODULES[module]
	if not name then
		return nil, self.L.unknownModule:format(tostring(module))
	end
	local m = self[module]
	if initialized[module] then
		return m
	end
	if loading[module] then return nil, self.L.moduleLoading:format(name) end
	loading[module] = true
	local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(name)
	if loadedOrLoading and not loaded then
		loading[module] = nil
		return nil, self.L.moduleLoading:format(name)
	end
	if not loaded then
		local ok, reason = C_AddOns.LoadAddOn(name)
		if not ok then
			loading[module] = nil
			local detail = reason and (_G["ADDON_" .. reason] or reason)
			return nil, detail and (name .. ": " .. detail) or name
		end
	end
	m = self[module]
	if type(m) ~= "table" then
		loading[module] = nil
		return nil, self.L.moduleMissing:format(name)
	end
	if type(m.Initialize) == "function" then
		local ok, err = pcall(m.Initialize, m)
		if not ok then
			loading[module] = nil
			return nil, tostring(err)
		end
	end
	initialized[module] = true
 if module=="Group" and self.Floating then self.Floating:Bind(m) end
	loading[module] = nil
	if self.OnModuleReady then self:OnModuleReady(module) end
	return m
end

-- Resolve ordinary entry clicks from native state, including a member's listing.
function A:GetDefaultPage()
	return C_LFGList.HasActiveEntryInfo() and "create" or "find"
end

-- A:Open('find'|'create'|'notes'|'settings'|nil, context)
function A:Open(page, context)
	page = page or self:GetDefaultPage()
	self:LoadDB()
	local function Failed(message)
		if page == "notes" then self:NoteMessage(message) else self:Print(message) end
		return false, message
	end
	local business = PAGE_BUSINESS[page]
	if business then
		local m, err = self:Ensure(business)
		if not m then
			return Failed(self.L.openFailed:format(tostring(err)))
		end
	end
	local ui, err = self:Ensure("UI")
	if not ui then
		return Failed(self.L.openFailed:format(tostring(err)))
	end
	ui:Show(page, context)
	return true
end

function A:ToggleWindow()
	if self.UI and self.UI:IsShown() and not self.UI.hiding then self.UI:Hide() else return self:Open(self:GetDefaultPage()) end
end

-- Explicit, session-only UI previews. No preview provider replaces the real Group.
function A:Preview(scenario)
 scenario=scenario or "applications"
 if scenario=="off" then if self.UI and self.UI.StopPreview then return self.UI:StopPreview(true) end;return true end
 self:LoadDB()
 local group,err=self:Ensure("Group");if not group then return false,err end
 local ui,reason=self:Ensure("UI");if not ui then return false,reason end
 return ui:StartPreview(scenario)
end

-- ---------------------------------------------------------------- 身份

-- A:PlayerKey(name, realm) -> key, cleanName, realm
-- 名字与服务器共同确定身份。name 可携带 "名字-服务器";显式 realm 优先。
-- 无法取得服务器时返回 nil,调用方按未知身份处理,不猜测命中。
local ownRealm

local function LocalRealm()
	if ownRealm then return ownRealm end
	local value = GetNormalizedRealmName and GetNormalizedRealmName()
	if issecretvalue and issecretvalue(value) then return nil end
	if value == nil and GetRealmName then value = GetRealmName() end
	if issecretvalue and issecretvalue(value) then return nil end
	if type(value) ~= "string" then return nil end
	value = value:gsub("%s+", "")
	if value ~= "" then ownRealm = value end
	return ownRealm
end

function A:PlayerKey(name, realm)
	if issecretvalue and (issecretvalue(name) or issecretvalue(realm)) then return nil end
	if type(name) ~= "string" then return nil end
	if realm ~= nil and type(realm) ~= "string" then return nil end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil end
	local clean, embedded = name:match("^([^%-]+)%-(.+)$")
	if clean then
		name = clean
		if realm == nil or realm == "" then realm = embedded end
	end
	-- 键内服务器统一去空格:同一名玩家无论显示名还是规范化名都得到同一键。
	if realm ~= nil and realm ~= "" then
		realm = (realm:gsub("%s+", ""))
		if realm == "" then realm = nil end
	end
	if realm == nil or realm == "" then
		realm = LocalRealm()
	end
	if not realm then return nil end
	return name .. "-" .. realm, name, realm
end

-- 单位身份只在原生读取边界解析；未知或受限身份不流入记录、菜单和队伍状态。
function A:UnitIdentity(unit)
	if issecretvalue and issecretvalue(unit) then return nil end
	if type(unit) ~= "string" then return nil end
	local exists = UnitExists(unit)
	if issecretvalue and issecretvalue(exists) then return nil end
	if not exists then return nil end
	local player = UnitIsPlayer(unit)
	if issecretvalue and issecretvalue(player) then return nil end
	if not player then return nil end
	local name, realm = UnitFullName(unit)
	return self:PlayerKey(name, realm)
end

-- ---------------------------------------------------------------- 设置

function A:GetSetting(key)
	if self.Configuration.definitions["settings."..key] then return self.Configuration:Get("settings."..key) end
	if CHARACTER_DEFAULTS[key] ~= nil then return self.charPrefs[key] end
	return self.db[key]
end

-- A:SetSetting(key, value) 同步配置与生命周期。
function A:SetSetting(key, value)
	if key == "fontScale" then value = FontScale(value) end
	if type(key)~="string" or value==nil then return false,"a setting key and value are required; use Configuration:Reset to clear an override" end
	local path="settings."..key;local definition=self.Configuration.definitions[path]
	if not definition then return false,"unknown setting: "..key end
	return self.Configuration:Set({[path]=value},{storage=definition.storage})
end

function A:ApplyConfigurationChanges(changes)
	local function Changed(key) return changes["settings."..key]~=nil end
	local function Value(key) return self:GetSetting(key) end
	if Changed("nativeLFGEntry") and self.SyncNativeLFGEntry then self:SyncNativeLFGEntry() end
	if (Changed("minimap") or Changed("minimapAngle")) and self.Minimap then self.Minimap:UpdateSettings() end
	if (Changed("font") or Changed("fontScale")) and self.Fonts then self.Fonts:Apply() end
	for _,key in ipairs({"history","autoJoin"}) do
		if Changed(key) then
			if self.Group then self.Group:OnSettingChanged(key,Value(key))
			elseif key=="history" and self.SyncHistoryWake then self:SyncHistoryWake(Value(key)) end
		end
	end
	local floating=Changed("floating") or Changed("floatingCompatibility") or Changed("floatingLocked") or Changed("floatingScale")
	if self.Floating then
		if Changed("reduceMotion") and Value("reduceMotion") and self.Floating.running then self.Floating:Tick(1) end
		if floating then self.Floating:UpdateSettings()
		elseif Changed("reduceMotion") then self.Floating:Update() end
	end
	if Changed("reduceMotion") and self.UI and self.UI.SetReducedMotion then self.UI:SetReducedMotion(Value("reduceMotion")) end
	if Changed("notesEnabled") or Changed("reminders") then
		if Value("notesEnabled") and Value("reminders")~="off" and self.db.notesHasRecords then
			-- 重新启用提醒属于真实后台需求,允许此刻加载 Notes。
			local notes, err = self:Ensure("Notes")
			if not notes then self:NoteMessage(self.L.loadFailed:format(tostring(err))) end
		end
		if self.Notes and type(self.Notes.SyncEnabled) == "function" then
			self.Notes:SyncEnabled()
		end
	end
	if self.UI and self.UI.OnSettingChanged then
		local keys={};for path in pairs(changes) do if path:sub(1,9)=="settings." then keys[#keys+1]=path:sub(10) end end;table.sort(keys)
		for _,key in ipairs(keys) do self.UI:OnSettingChanged(key,Value(key)) end
	end
	if self.OnConfigurationChanged then self:OnConfigurationChanged(changes) end
end

-- ---------------------------------------------------------------- 输出

local function Prefixed(prefix, text)
	return prefix .. " " .. tostring(text)
end

function A:Print(text)
	local frame = DEFAULT_CHAT_FRAME
	if frame then
		frame:AddMessage(Prefixed(self.L.brand, text), 0.940, 0.932, 0.910)
	end
end

function A:NoteMessage(text)
	local frame = DEFAULT_CHAT_FRAME
	if frame then
		frame:AddMessage(Prefixed(self.L.brand, text), 0.940, 0.932, 0.910)
	end
end

-- A:RecordLink(playerKey, text) -> 聊天链接文本
-- 链接携带完整身份,由轻量处理器按需打开笔记页;不建随聊天历史增长的索引。
function A:RecordLink(playerKey, text)
	return ("|Hlycheegroup:note:%s|h|cffD53C49[%s]|r|h"):format(playerKey, text or self.L.viewNote)
end
