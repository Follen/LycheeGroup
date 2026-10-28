-- 组队业务包根:存档装载、事件分发入口、视图登记与订阅通知。
-- 每项业务一个所有者;本文件只做装配与转发,不持有业务状态。
local A = _G.LycheeGroup
local G = {}
A.Group = G

local L = A.GroupLocale
G.L = L

function G.Public(value)
 if issecretvalue and issecretvalue(value) then return nil end
 return value
end

local views = {}
local subscribers = {}
local applicantPermission, listingPermission

-- ---------------------------------------------------------------- 存档与生命周期

local function CopyPreferences(source)
 local copy={}
 for key,value in pairs(source) do copy[key]=type(value)=="table" and CopyPreferences(value) or value end
 return copy
end

-- Invalid saved values retain their original references outside live consumers.
function G:RetainInvalidStorage(root,path,value,reason)
 local recovery=root.storageRecovery
 if type(recovery)~="table" then
  root.storageRecovery={}
  if recovery~=nil then root.storageRecovery.previous={value=recovery,error="storageRecovery must be a table"} end
  recovery=root.storageRecovery
 end
 recovery[path]={value=value,error=reason,previous=recovery[path]}
end
local function Number(value)
 return type(value)=="number" and value==value and value>=0 and value<math.huge
end
local function Key(value)
 return type(value)=="string" and value~="" or Number(value) and value%1==0 and value~=0 or type(value)=="number" and value<0 and value>-math.huge and value%1==0
end
local function CategoryKey(value)
 return type(value)=="string" and (value=="seasonDungeon" or value=="seasonRaid" or value:match("^%d+$") and tonumber(value)>0)
end
local function Retain(root,path,value,reason,character)
 if character then A.Configuration:RetainInvalid(root,path,value,reason)
 else G:RetainInvalidStorage(root,path,value,reason) end
end
local function BindTable(root,owner,key,path,character)
 local value=owner[key]
 if type(value)=="table" then return value end
 if value~=nil then Retain(root,path,value,"expected a table",character) end
 owner[key]={};return owner[key]
end
local filterNumbers={minRating=true,maxRating=true,minItemLevel=true,maxItemLevel=true,minMembers=true,maxMembers=true}
local filterFlags={selected=true,needsDamage=true,hideZeroScore=true,hideSameSpec=true,hideSameClass=true,hideSameClassRole=true,requireBloodlust=true,roleMatchAny=true,friends=true,guild=true}
local enumValues={sort={newest=true,rating=true,itemLevel=true,members=true},social={friend=true,guild=true,any=true,positive=true,noCaution=true,caution=true},neededRole={TANK=true,HEALER=true,DAMAGER=true},tankPresence={present=true,missing=true},healerPresence={present=true,missing=true},damagePresence={present=true,missing=true},searchMode={group=true,leader=true}}
local function CheckChoice(root,choice,path,character)
 for key,value in pairs(choice) do
  local valid=true
  if filterNumbers[key] then
   valid=Number(value) and value%1==0 and value<=99999
   if key=="minMembers" or key=="maxMembers" then valid=Number(value) and value%1==0 and value>=1 and value<=40 end
  elseif filterFlags[key] then valid=type(value)=="boolean"
  elseif enumValues[key] then valid=value==false or type(value)=="string" and enumValues[key][value]==true
  elseif key=="tier" then valid=value==false or Number(value) and value%1==0 or value=="exp10" or value=="exp11"
  elseif key=="difficultyID" then valid=value==false or Number(value) and value%1==0
  elseif key=="groupKey" then valid=value==false or Key(value)
  elseif key=="category" then valid=CategoryKey(value)
  elseif key=="text" or key=="leaderText" or key=="personKey" then valid=type(value)=="string"
  elseif key=="groupKeys" then
   valid=value==false or type(value)=="table"
   if type(value)=="table" then
    for groupKey,selected in pairs(value) do
     if not Key(groupKey) or type(selected)~="boolean" then
      Retain(root,path..".groupKeys["..type(groupKey)..":"..tostring(groupKey).."]",selected,"expected an activity group key and boolean",character)
      value[groupKey]=nil
     end
    end
   end
  end
  if not valid then Retain(root,path.."."..key,value,"invalid saved search choice",character);choice[key]=nil end
 end
end
local function BindFind(root,owner,path,character)
 local find=BindTable(root,owner,"find",path,character)
 CheckChoice(root,find,path,character)
 if find.railCollapsed~=nil and type(find.railCollapsed)~="boolean" then Retain(root,path..".railCollapsed",find.railCollapsed,"expected a boolean",character);find.railCollapsed=nil end
 local filters=BindTable(root,find,"filters",path..".filters",character)
 CheckChoice(root,filters,path..".filters",character)
 local categories=BindTable(root,find,"categoryPrefs",path..".categoryPrefs",character)
 for key,choice in pairs(categories) do
  local itemPath=path..".categoryPrefs["..type(key)..":"..tostring(key).."]"
  if not CategoryKey(key) or type(choice)~="table" then Retain(root,itemPath,choice,"expected a category search choice",character);categories[key]=nil
  else CheckChoice(root,choice,itemPath,character) end
 end
 return find
end
function G:BindSavedPreferences(db,prefs)
 local legacy=BindTable(db,db,"prefs","prefs")
 local seed=BindFind(db,legacy,"prefs.find")
 -- First-use character migration clones only the already validated seed.
 if prefs.find==nil then prefs.find=CopyPreferences(seed) end
 BindFind(prefs,prefs,"find",true)
 prefs.applicationRoles,legacy.applicationRoles=nil,nil
 local blocked=BindTable(db,db,"blockedLeaders","blockedLeaders")
 for key,value in pairs(blocked) do
  if type(key)~="string" or key=="" or value~=true then
   Retain(db,"blockedLeaders["..type(key)..":"..tostring(key).."]",value,"expected a player key and true");blocked[key]=nil
  end
 end
 self.Results:BindBlockedLeaders()
end

-- Initialize 由微核心 Ensure 调用一次;LoD 包此刻两份存档必然已装载。
function G:Initialize()
 A:LoadDB()
	local db = _G.LycheeGroupGroupDB
	if type(db) ~= "table" then
  local invalid=db
		db = {}
		_G.LycheeGroupGroupDB = db
  if invalid~=nil then self:RetainInvalidStorage(db,"$root",invalid,"expected an account group table") end
	end
	db.schema = 1

	self.db = db
 self.prefs=A.charPrefs
 self:BindSavedPreferences(db,self.prefs)
 if db.creationPresets==nil then db.creationPresets={}
 elseif type(db.creationPresets)~="table" then db.creationPresets={invalidContainer=db.creationPresets} end
 self.Presets=A.CreationPresets.New(db.creationPresets,function() G:Notify("creationPresets") end)

	local charDB = _G.LycheeGroupCharacterDB
	if type(charDB) ~= "table" then
  local invalid=charDB
		charDB = {}
		_G.LycheeGroupCharacterDB = charDB
  if invalid~=nil then self:RetainInvalidStorage(charDB,"$root",invalid,"expected a character history table") end
	end
	charDB.schema = 1
	self.charDB = charDB
 self.History:InitializeStorage(charDB)
 -- One-time migration of the retired favorites list into recommended notes.
 -- Existing player notes remain authoritative; malformed legacy entries remain
 -- saved for recovery instead of being silently discarded.
 if type(db.favorites)=="table" and next(db.favorites) then
  local notes,err=A:Ensure("Notes")
  if notes then
   local records,keys={},{}
   for key,record in pairs(db.favorites) do
    local valid=type(record)=="table" and (record.note==nil or type(record.note)=="string") and (record.favAt==nil or type(record.favAt)=="number" and record.favAt==record.favAt and record.favAt>=0 and record.favAt<math.huge)
    local identity,name,realm
    if valid then identity,name,realm=A:PlayerKey(record.name,record.realm) end
    if identity then
     if not notes:Find(identity) then records[#records+1]={name=name,server=realm,reason=record.note or "",timestamp=record.favAt or 0,type="positive",classSpec=""} end
     keys[#keys+1]=key
    end
   end
   notes:Merge(records);for _,key in ipairs(keys) do db.favorites[key]=nil end
   if not next(db.favorites) then db.favorites=nil end
  else A:NoteMessage(A.L.loadFailed:format(tostring(err))) end
 end

	G.Game:Init()
	G.Roster:Init()
	self:Restore()
end

-- 冷启动恢复:接管原生仍存在的申请、招募、申请者与进行中的大秘境。可重复调用。
function G:Restore()
	G.Applications:Restore()
	G.Listing:Restore()
	G.Applicants:Restore()
	G.History:Restore()
	G.Game:RefreshSubscriptions()
	self:RefreshPermissions()
end

function G:OnSettingChanged(key,value)
 if key=="applicantAlertSound" then self.Alerts:OnSettingChanged() end
 if key=="history" then
  if value then self.History:Restore() else self.History:Discard() end
 end
 if key=="autoJoin" then
  self.Game:RefreshApplicationSubscriptions()
  if value then self.Applications:TryAutoJoin() end
 end
end

-- ---------------------------------------------------------------- 事件分发

-- 微核心唤醒交接与本包事件帧的共同入口;按事件名转发给具名所有者。
local function CharacterFriendsChanged(g) g.Relations:OnChanged("character") end
local function BnetFriendsChanged(g) g.Relations:OnChanged("bnet") end
local function BnetFriendChanged(g,index) g.Relations:OnChanged("bnet",index) end
local function GuildChanged(g) g.Relations:OnChanged("guild") end
local function ClubChanged(g,id) g.Relations:OnClubChanged(id) end
local DISPATCH = {
	FRIENDLIST_UPDATE = CharacterFriendsChanged,
	BN_FRIEND_LIST_SIZE_CHANGED = BnetFriendsChanged,
	BN_FRIEND_INFO_CHANGED = BnetFriendChanged,
	BN_FRIEND_ACCOUNT_ONLINE = BnetFriendsChanged,
	BN_FRIEND_ACCOUNT_OFFLINE = BnetFriendsChanged,
	BN_DISCONNECTED = BnetFriendsChanged,
	GUILD_ROSTER_UPDATE = GuildChanged,
	PLAYER_GUILD_UPDATE = function(g,unit) if G.Public(UnitIsUnit(unit,"player")) then g.Relations:OnChanged("guild");if IsInGuild() then C_GuildInfo.GuildRoster() end end end,
	CLUB_ADDED = ClubChanged,
	CLUB_MEMBER_ADDED = ClubChanged,
	CLUB_MEMBER_REMOVED = ClubChanged,
	CLUB_MEMBER_UPDATED = ClubChanged,
	CLUB_MEMBERS_UPDATED = ClubChanged,
	LFG_LIST_SEARCH_RESULTS_RECEIVED = function(g) g.Search:OnResultsReceived() end,
	LFG_LIST_SEARCH_RESULT_UPDATED = function(g, resultID) g.Results:QueueUpdate(resultID) end,
	LFG_LIST_UPDATE_SEARCH_RESULTS = function(g) g.Search:OnResultsUpdated() end,
	LFG_LIST_SEARCH_FAILED = function(g, reason) g.Search:OnSearchFailed(reason) end,
	LFG_LIST_AVAILABILITY_UPDATE = function(g) g.Search:OnAvailabilityUpdated() end,
	LFG_LIST_APPLICATION_STATUS_UPDATED = function(g, resultID, newStatus, oldStatus, groupName)
		g.Applications:OnStatusUpdated(resultID, newStatus, oldStatus, groupName)
	end,
	LFG_LIST_ACTIVE_ENTRY_UPDATE = function(g, created)
		g.Listing:OnEntryUpdate(created)
		g.Applicants:OnEntryUpdate(created)
	end,
	LFG_LIST_APPLICANT_LIST_UPDATED = function(g) g.Applicants:RefreshList() end,
	LFG_LIST_APPLICANT_UPDATED = function(g, applicantID) g.Applicants:OnApplicantUpdated(applicantID) end,
	CHALLENGE_MODE_START = function(g) g.History:OnStart() end,
	GROUP_ROSTER_UPDATE = function(g) g.History:OnRosterUpdate(); g:RefreshPermissions(); g:InvalidateRoster("group"); g.Applicants:TryAutoInvite(); g.Applications:TryAutoJoin(); g.Game:RefreshApplicationSubscriptions() end,
	PARTY_LEADER_CHANGED = function(g)
		g.Listing:OnEntryUpdate()
		g.Applicants:RefreshList(true)
		g:RefreshPermissions()
		g.Applications:TryAutoJoin()
	end,
	CHALLENGE_MODE_COMPLETED = function(g) g.History:OnCompleted() end,
	CHALLENGE_MODE_RESET = function(g) g.History:Discard() end,
	ACTIVE_PLAYER_SPECIALIZATION_CHANGED = function(g)
		g:InvalidateRoster()
		local filters=g.Search:GetFilters()
		if g:HasViews("search") and (filters.hideSameSpec or filters.hideSameClassRole) then g.Results:InvalidateView();g:Notify("results") end
	end,
	PLAYER_SPECIALIZATION_CHANGED = function(g,unit) g:InvalidateRoster("spec",unit) end,
	PLAYER_EQUIPMENT_CHANGED = function(g) g:InvalidateRoster() end,
	PLAYER_ROLES_ASSIGNED = function(g) g:InvalidateRoster() end,
	INSPECT_READY = function(g,guid) g.Roster:OnInspectReady(guid) end,
	PLAYER_REGEN_ENABLED = function(g) g:InvalidateRoster("available") end,
	UNIT_CONNECTION = function(g) g:InvalidateRoster("available") end,
	PLAYER_ENTERING_WORLD = function(g) g.History:OnWorldEntered() end,
}

function G:OnEvent(event, ...)
	local handler = DISPATCH[event]
	if handler then
		handler(self, ...)
	end
end

-- ---------------------------------------------------------------- 视图与订阅

-- 视图只拥有浏览消费;已提交申请、当前招募与秘境 run 独立存活。
function G:Attach(view, kind)
	kind = kind or "search"
	if views[view] == kind then return end
	views[view] = kind
	self.Game:RefreshSubscriptions()
	self:RefreshPermissions()
	self.Search:RequestActivities()
	self:InvalidateRoster()
end

function G:Detach(view)
	local kind = views[view]
	if kind == nil then return end
	views[view] = nil
	if kind == "search" and not self:HasViews("search") then
		self.Search:EndBrowse()
		self.Applications:ReleaseFinished()
	end
	self.Game:RefreshSubscriptions()
end

function G:HasViews(kind)
	for _, owner in pairs(views) do
		if kind == nil or owner == kind then return true end
	end
	return false
end

-- Subscribe(callback(kind, id)) -> unsubscribe
-- kind: "search"|"results"|"result"|"activities"|"applications"|"application"|"applicationCancelled"|"listing"|"applicants"|"applicant"|"permissions"|"history"|"relations"
-- A "results" notification may carry the changed ID set; consume it during the
-- callback because the Results owner reuses it after synchronous dispatch.
function G:Subscribe(callback)
	if type(callback) ~= "function" then
		return function() end
	end
	local token={}
	subscribers[callback] = token
	return function()
		if subscribers[callback]==token then subscribers[callback] = nil end
	end
end

-- Notify 只分发状态变化;Publish 留给招募动作,两者不共用名称。
function G:Notify(kind, id)
	for callback in pairs(subscribers) do
		local ok, err = pcall(callback, kind, id)
		if not ok then
			A:Print(L.callbackError:format(tostring(err)))
		end
	end
end

-- Home-party permissions match the native listing controls. A solo publisher
-- keeps ownership before the first applicant joins; assistants manage applicants.
function G:CanManageListing()
	local home = LE_PARTY_CATEGORY_HOME
	if not IsInGroup(home) or UnitIsGroupLeader("player", home) then return true end
	return false, L.listingPermission
end

function G:CanManageApplicants()
	local home = LE_PARTY_CATEGORY_HOME
	if not IsInGroup(home) or UnitIsGroupLeader("player", home) or UnitIsGroupAssistant("player", home) then return true end
	return false, L.applicantPermission
end

function G:RefreshPermissions()
	local applicants, listing = self:CanManageApplicants(), self:CanManageListing()
	if applicantPermission == applicants and listingPermission == listing then return end
	applicantPermission, listingPermission = applicants, listing
	self.Alerts:Sync()
	self:Notify("permissions")
end

-- ---------------------------------------------------------------- 公开门面

-- UI 消费的平铺合同:业务方法直接挂在 A.Group 上;内部组织仍分属各所有者文件,
-- 门面只做转发,不持有状态。修改所有者接口时同步此处与 UI 调用方。
-- 例外:搜索服务直接以 G.Search 暴露(服务表与同名门面方法冲突),UI 调用 G.Search:Search。

function G:GetActivities(categoryKey) return self.Search:GetActivities(categoryKey) end
function G:SetFilters(filters) return self.Search:SetFilters(filters) end
function G:GetSearchState() return self.Search:GetState() end
function G:GetSearchError() return self.Search:GetSearchError() end
function G:GetResults() return self.Results:GetResults() end
function G:GetResult(id) return self.Results:GetResult(id) end
function G:GetResultDetails(id) return self.Results:GetDetails(id) end
function G:GetResultCount() return self.Results:GetCount() end
function G:GetApplications() return self.Applications:GetApplications() end
function G:GetApplication(id) return self.Applications:GetApplication(id) end
function G:Apply(id, roles) return self.Applications:Apply(id, roles) end
function G:Cancel(id) return self.Applications:Cancel(id) end
function G:AcceptInvite(id) return self.Applications:AcceptInvite(id) end
function G:DeclineInvite(id) return self.Applications:DeclineInvite(id) end
function G:GetListing() return self.Listing:GetListing() end
function G:Publish(data) return self.Listing:Publish(data) end
function G:Update(data) return self.Listing:Update(data) end
function G:RemoveListing() return self.Listing:RemoveListing() end
function G:GetApplicants() return self.Applicants:GetApplicants() end
function G:SetApplicantView(owner,visible) self.Alerts:SetViewed(owner,visible) end
function G:RefreshApplicants() return self.Applicants:RequestRefresh() end
function G:GetApplicant(id) return self.Applicants:GetApplicant(id) end
function G:GetApplicantDungeonScores(member) return self.Applicants:GetDungeonScores(member) end
function G:GetApplicantTimeMargin(member) return self.Applicants:GetTimeMargin(member) end
function G:GetApplicantMapScore(member)
 local scores=self.Applicants:GetDungeonScores(member,true)
 return scores and scores.mapScore
end
function G:Invite(id) return self.Applicants:Invite(id) end
function G:Decline(id) return self.Applicants:Decline(id) end
function G:GetHistory() return self.History:GetHistory() end
function G:GetActiveRun() return self.History:GetActiveRun() end
function G:InvalidateRoster(reason,unit) self.Roster:Invalidate(reason,unit) end
function G:GetRoster() return self.Roster:Get() end
function G:GetRaidBuffs(activityID) return self.Roster:GetRaidBuffs(activityID) end

-- LFG remote names without a realm do not establish a complete player identity.
function G:RemotePlayerKey(name)
 if type(name)~="string" or not name:find("-",1,true) then return nil end
 return A:PlayerKey(name)
end

-- Small native specialization resolver shared by lightweight consumers. It never
-- infers a specialization from a role or matches a name across other classes.
function G:ResolveMemberSpec(member)
 local classID,className
 local class=G.Public(member.class) or G.Public(member.classFilename)
 if class then classID,className=A.Specializations:Class(class) end
 local specID=G.Public(member.specID)
 local nativeName=G.Public(member.specName)
 local specName,icon
 if specID and specID>0 then specName,icon=A.Specializations:Get(specID)
 elseif classID and nativeName then
  local id,name,image=A.Specializations:Find(class,nativeName)
  if name then specID,specName,icon=id,name,image end
 end
 return specID,specName,icon,member.localizedClass or className
end
