-- Group 包行为:搜索代次与结果、申请状态、招募/申请者、大秘境历史、团长收藏。
local Stubs = TestStubs
Stubs.Install({ locale = "zhCN", realm = "晨风号角" })
_G.GetInspectSpecialization = nil -- 目标客户端只依赖当前 C_SpecializationInfo 接口。
Stubs.SetUnit("player", { name = "本人", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-0" })

Load.addon("LycheeGroup", "Locale.lua")
Load.addon("LycheeGroup", "Core.lua")
LycheeGroup:LoadDB() -- Core ADDON_LOADED precedes every LoD package.
Load.addon("LycheeGroup", "Specializations.lua")

-- ---------------------------------------------------------------- LFG/秘境替身

local S = {
	-- 搜索
	searchCalls = {},
	failSearch = false,
	results = {},          -- resultID -> GetSearchResultInfo 表
	resultIDs = {},        -- GetFilteredSearchResults 返回
	resultReads = 0,
	players = {}, counts = {}, encounters = {}, friends = {}, playerReads = 0, memberCountReads = 0,
	-- 申请
	applications = {},     -- 原生仍存在的申请 ID
	appStatus = {},        -- id -> status
	appPending = {},       -- id -> pending status
	applyCalls = {},
	-- 招募
	activeEntry = nil,
	createDataHistory = {},
	removeCalls = 0,
	-- 申请者
	applicants = {},       -- applicantID -> GetApplicantInfo 表
	applicantMembers = {}, -- applicantID -> 成员返回值数组
	applicantPvp = {}, applicantPvpCalls = {}, -- activityID -> applicantID -> memberIndex -> native rating
	inviteCalls = {},
	-- 秘境
	activeMap = nil,
	keystoneLevel = 0,
	social = { friends = {}, bnet = {}, guild = {} },
	guidNames = {},
}

S.now=100
_G.GetTime=function() return S.now end
_G.InCombatLockdown=function() return false end
_G.CanInspect=function(unit) return UnitExists(unit) end
local specCallbacks={}
local specLibrary={RegisterGroup=function(owner,callback) specCallbacks[owner]=callback end,UnregisterGroup=function(owner) specCallbacks[owner]=nil end}
_G.LibStub=function(name) assert(name=="LibSpecialization");return specLibrary end
_G.SOUNDKIT={UI_GROUP_FINDER_RECEIVE_APPLICATION=47615}
_G.PlaySound=function(id,channel,_,finish) S.soundCalls=(S.soundCalls or 0)+1;S.soundKit=id;S.soundChannel=channel;S.soundFinish=finish;return true,7 end
_G.StopSound=function() end
C_SpecializationInfo.GetSpecialization=function() return nil end
_G.GetAverageItemLevel=function() return 0,0 end
_G.C_PaperDollInfo={GetInspectItemLevel=function() return nil end}
_G.C_PlayerInfo={GetPlayerMythicPlusRatingSummary=function() return nil end}
_G.BNET_CLIENT_WOW="WoW"
_G.WOW_PROJECT_ID=1
_G.BNGetNumFriends=function() return #S.social.bnet end
_G.C_BattleNet={
 GetFriendNumGameAccounts=function(index) return #S.social.bnet[index].accounts end,
 GetFriendGameAccountInfo=function(index,account) return S.social.bnet[index].accounts[account] end,
}
_G.C_FriendList={
 IsLegacyFriendSystemEnabled=function() return true end,
 GetNumFriends=function() S.socialReads=(S.socialReads or 0)+1;return #S.social.friends end,
 GetFriendInfoByIndex=function(index) return S.social.friends[index] end,
 ShowFriends=function() S.friendRequests=(S.friendRequests or 0)+1 end,
}
_G.C_Club={
 GetGuildClubId=function() return S.social.guildID end,
 GetClubMembers=function() local ids={};for i=1,#S.social.guild do ids[i]=i end;return ids end,
 GetMemberInfo=function(_,index) return S.social.guild[index] end,
}
_G.C_GuildInfo={GuildRoster=function() S.guildRequests=(S.guildRequests or 0)+1 end}
_G.IsInGuild=function() return S.social.guildID~=nil end
_G.GetPlayerInfoByGUID=function(guid)
 local info=S.guidNames[guid]
 if info then return "战士","WARRIOR","人类","Human",2,info.name,info.realm end
end
_G.Enum={LFGListFilter={CurrentSeason=64,NotCurrentSeason=128,Recommended=1,NotRecommended=2,PvE=4}}
local function Bits(a,b,union)
 local result,power=0,1
 while a>0 or b>0 do
  local x,y=a%2,b%2
  if union and (x==1 or y==1) or not union and x==1 and y==1 then result=result+power end
  a,b,power=math.floor(a/2),math.floor(b/2),power*2
 end
 return result
end
_G.bit={bor=function(a,b) return Bits(a,b,true) end,band=function(a,b) return Bits(a,b,false) end}
_G.C_EncounterJournal={GetInstanceForGameMap=function() return nil end}
_G.LE_PARTY_CATEGORY_HOME=1
_G.UnitIsGroupAssistant=function() return false end
_G.EJ_GetCurrentTier=function() return 1 end
_G.EJ_GetNumTiers=function() return 1 end
_G.EJ_GetTierInfo=function() return "Test expansion" end
_G.EJ_SelectTier=function() end
_G.EJ_GetInstanceByIndex=function() return nil end
local ACTIVITY = {
	[501] = { fullName = "黑翼之巢", shortName = "黑翼", categoryID = 3, isCurrentRaidActivity = true, maxNumPlayers = 30 },
	[502] = { mapID=111,groupFinderActivityGroupID=20, fullName = "旋云之巅", shortName = "旋云", categoryID = 2, isMythicPlusActivity = true, maxNumPlayers = 5 },
	[503] = { fullName = "通灵战潮", shortName = "通灵", categoryID = 2, isMythicPlusActivity = true, maxNumPlayers = 5 },
	[504] = { mapID=111,groupFinderActivityGroupID=20, fullName = "其他地城", shortName = "其他", categoryID = 2, isMythicPlusActivity = false, maxNumPlayers = 5 },
}

_G.C_LFGList = {
 ClearSearchTextFields=function() S.nativeSearchText="" end,
	Search = function(categoryID, filter, preferred, language, crossFaction, advanced, activityFilter)
		if S.failSearch then error("protected", 0) end
		S.searchCalls[#S.searchCalls + 1] = { categoryID = categoryID, activityFilter = activityFilter, nativeSearchText=S.nativeSearchText }
		if S.syncSearch == "results" then Stubs.FireEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED") end
		if S.syncSearch == "failed" then Stubs.FireEvent("LFG_LIST_SEARCH_FAILED", "throttled") end
	end,
	GetFilteredSearchResults = function()
		return #S.resultIDs, S.resultIDs
	end,
	GetSearchResultInfo = function(id) S.resultReads = S.resultReads + 1; return S.results[id] end,
	GetSearchResultPlayerInfo = function(id,index) S.playerReads=S.playerReads+1;return S.players[id] and S.players[id][index] end,
	GetSearchResultFriends = function(id) local f=S.friends[id] or {};return f.bnet or {},f.character or {},f.guild or {} end,
	GetSearchResultMemberCounts = function(id) S.memberCountReads=S.memberCountReads+1;return S.counts[id] end,
	GetSearchResultEncounterInfo = function(id) S.encounterReads=(S.encounterReads or 0)+1;return S.encounters[id] end,
	GetActivityInfoTable = function(id) return ACTIVITY[id] end,
	RequestAvailableActivities = function() S.availabilityRequests = (S.availabilityRequests or 0) + 1 end,
	GetAvailableCategories=function() return {2,3} end,
 GetLfgCategoryInfo=function(id) return {name=id==2 and "Dungeons" or "Raids"} end,
 GetAvailableActivityGroups=function(id) return {id==2 and 20 or 10} end,
 GetActivityGroupInfo=function(id) return "Group "..id end,
 GetAvailableActivities = function(categoryID,groupID,flags)
		local ids = {}
		for id, info in pairs(ACTIVITY) do
			if info.categoryID == categoryID  then ids[#ids + 1] = id end
		end
		table.sort(ids)
		return ids
	end,
	GetLanguageSearchFilter = function() return nil end,
	GetApplications = function() return S.applications end,
	GetApplicationInfo = function(id) return id, S.appStatus[id], S.appPending[id], 120 end,
	ApplyToGroup = function(id, tank, healer, damage)
		S.applyCalls[#S.applyCalls + 1] = { id = id, tank = tank, healer = healer, damage = damage }
		S.appStatus[id] = "applied"
		S.applications[#S.applications + 1] = id
	end,
	CancelApplication = function(id)
		for i, v in ipairs(S.applications) do
			if v == id then table.remove(S.applications, i) break end
		end
		S.appStatus[id] = "cancelled"
	end,
	AcceptInvite = function(id) S.appStatus[id] = "inviteaccepted" end,
	DeclineInvite = function(id) S.appStatus[id] = "invitedeclined" end,
	HasActiveEntryInfo = function() return S.activeEntry ~= nil end,
	GetActiveEntryInfo = function() return S.activeEntry end,
	CreateListing = function(createData)
		S.createDataHistory[#S.createDataHistory + 1] = { op = "create", data = createData }
		S.activeEntry = {
			activityIDs = createData.activityIDs,
			name = "原生标题", comment = "原生说明",
			requiredItemLevel = createData.requiredItemLevel or 0,
			requiredDungeonScore = createData.requiredDungeonScore,
			autoAccept = createData.isAutoAccept,
			privateGroup = createData.isPrivateGroup,
			isCrossFactionListing = createData.isCrossFactionListing,
			newPlayerFriendly = createData.newPlayerFriendly,
			playstyle = createData.playstyle,
			generalPlaystyle = createData.generalPlaystyle,
			requiredPvpRating = createData.requiredPvpRating,
			questID = createData.questID,
			duration = 0,
		}
		return true
	end,
	UpdateListing = function(createData)
		S.createDataHistory[#S.createDataHistory + 1] = { op = "update", data = createData }
		S.activeEntry.activityIDs = createData.activityIDs
		S.activeEntry.requiredItemLevel = createData.requiredItemLevel or 0
		S.activeEntry.isCrossFactionListing = createData.isCrossFactionListing
		return true
	end,
	RemoveListing = function()
		S.removeCalls = S.removeCalls + 1
		S.activeEntry = nil
	end,
	GetApplicants = function()
		S.applicantListReads=(S.applicantListReads or 0)+1
		local ids = {}
		for id in pairs(S.applicants) do ids[#ids + 1] = id end
		table.sort(ids)
		return ids
	end,
	GetApplicantInfo = function(id) S.applicantInfoReads=(S.applicantInfoReads or 0)+1;return S.applicants[id] end,
	DoesEntryTitleMatchPrebuiltTitle = function() error("Saved settings must not inspect protected listing titles") end,
	RefreshApplicants = function() S.applicantRefreshCalls=(S.applicantRefreshCalls or 0)+1 end,
	GetApplicantMemberInfo = function(id, index)
		local members = S.applicantMembers[id]
		local m = members and members[index] or nil
		if not m then return nil end
		return m.name, m.class, m.localizedClass, m.level, m.itemLevel, m.honorLevel,
			m.tank, m.healer, m.damage, m.assignedRole, m.relationship,
			m.dungeonScore, m.pvpItemLevel, m.factionGroup, m.raceID, m.specID, m.isLeaver
	end,
	GetApplicantPvpRatingInfoForListing = function(id,index,activityID)
		S.applicantPvpCalls[#S.applicantPvpCalls+1]={id,index,activityID}
		local activity=S.applicantPvp[activityID]
		return activity and activity[id] and activity[id][index]
	end,
	InviteApplicant = function(id) S.inviteCalls[#S.inviteCalls + 1] = id end,
	DeclineApplicant = function(id) S.declineCalls=(S.declineCalls or 0)+1;S.lastDeclined=id end,
}

_G.C_ChallengeMode = {
	GetActiveChallengeMapID = function() return S.activeMap end,
	IsChallengeModeActive = function()
		if S.challengeActive ~= nil then return S.challengeActive end
		return S.activeMap ~= nil
	end,
	GetMapUIInfo = function(mapID) return "测试秘境·" .. mapID, mapID, 1800, nil, nil, mapID end,
	GetActiveKeystoneInfo = function() return S.keystoneLevel, {}, false end,
}

Load.addon("LycheeGroup_Group", "Locale.lua")
Load.addon("LycheeGroup_Group", "Group.lua")
local publicBeforeResults=_G.LycheeGroup.Group.Public
T.eq(type(publicBeforeResults),"function","native value reads are available before any result service loads")
T.eq(publicBeforeResults("public"),"public")
Load.addon("LycheeGroup_Group", "RaidBuffs.lua")
Load.addon("LycheeGroup_Group", "Relations.lua")
Load.addon("LycheeGroup_Group", "Roster.lua")
Load.addon("LycheeGroup_Group", "Game.lua")
Load.addon("LycheeGroup_Group", "Catalog.lua")
Load.addon("LycheeGroup", "Presentation.lua")
Load.addon("LycheeGroup_Group", "Search.lua")
Load.addon("LycheeGroup_Group", "Results.lua")
T.eq(_G.LycheeGroup.Group.Public,publicBeforeResults,"loading Results does not replace the shared native value reader")
Load.addon("LycheeGroup_Group", "Applications.lua")
Load.addon("LycheeGroup_Group", "CreationPresets.lua")
Load.addon("LycheeGroup_Group", "Listing.lua")
Load.addon("LycheeGroup_Group", "Alerts.lua")
Load.addon("LycheeGroup_Group", "Applicants.lua")
Load.addon("LycheeGroup_Group", "History.lua")

local A = _G.LycheeGroup
local G = A.Group
local legacyFind={category="seasonDungeon",categoryPrefs={seasonDungeon={groupKeys={"dungeon-1"},sort="rating",tankPresence="missing"}},filters={sort="rating"}}
_G.LycheeGroupGroupDB={prefs={find=legacyFind}}
G:Initialize()
T.eq(type(G.prefs), "table", "搜索页面偏好由角色存档入口初始化")
do
 local first=G.prefs
 T.eq(first,A.charPrefs);T.eq(first,_G.LycheeGroupPrefsDB)
 T.same(first.find,legacyFind,"the first character inherits the complete saved filters")
 T.ok(first.find~=legacyFind);T.ok(first.find.categoryPrefs.seasonDungeon.groupKeys~=legacyFind.categoryPrefs.seasonDungeon.groupKeys)
 first.find.categoryPrefs.seasonDungeon.groupKeys[1]="dungeon-2"
 first.find.categoryPrefs.seasonDungeon.sort="members"
 _G.LycheeGroupPrefsDB={};A.db=nil;G:Initialize()
 local second=G.prefs
 T.eq(second.find.categoryPrefs.seasonDungeon.groupKeys[1],"dungeon-1","another character inherits the untouched account seed")
 second.find.categoryPrefs.seasonDungeon.sort="itemLevel"
 _G.LycheeGroupPrefsDB=first;A.db=nil;G:Initialize()
 T.eq(G.prefs,first);T.eq(first.find.categoryPrefs.seasonDungeon.sort,"members","returning to a character never overwrites its filters")
 T.eq(first.find.categoryPrefs.seasonDungeon.groupKeys[1],"dungeon-2")
 T.eq(second.find.categoryPrefs.seasonDungeon.sort,"itemLevel")
 T.eq(legacyFind.categoryPrefs.seasonDungeon.sort,"rating")
 G.prefs.find={};G.db.prefs=nil
end

local searchView, listingView = {}, {}
T.eq(#Stubs.FramesWithEvent("LFG_LIST_UPDATE_SEARCH_RESULTS"), 0, "无浏览时不监听搜索更新")
G:Attach(listingView, "listing")
T.eq(#Stubs.FramesWithEvent("LFG_LIST_AVAILABILITY_UPDATE"), 1, "创建页只消费活动目录")
T.eq(#Stubs.FramesWithEvent("LFG_LIST_UPDATE_SEARCH_RESULTS"), 0, "创建页不建立搜索监听")
G:Detach(listingView)
G:Attach(searchView, "search")
T.eq(#Stubs.FramesWithEvent("LFG_LIST_UPDATE_SEARCH_RESULTS"), 1, "搜索页建立搜索监听")

local notifications = {}
local unsubscribe = G:Subscribe(function(kind)
	notifications[kind] = (notifications[kind] or 0) + 1
end)

local function Fire(event, ...)
	local delivered = Stubs.FireEvent(event, ...)
	-- 帧未注册的唤醒事件经 Core 交接路径同样要可达:测试直接走 G:OnEvent。
	if delivered == 0 then
		G:OnEvent(event, ...)
	end
end

do
	local refresh=G.Game.RefreshRelations
	local calls=0
	G.Game.RefreshRelations=function(self) calls=calls+1;return refresh(self) end
	local before=notifications.applications or 0
	G:Notify("applications")
	T.eq(notifications.applications,before+1,"Notify still delivers the requested change")
	T.eq(calls,0,"publishing a notification alone never starts or stops a business service")
	G.Game.RefreshRelations=refresh
end

-- ---------------------------------------------------------------- 搜索与结果

do
	S.results[11] = {
		searchResultID = 11, activityIDs = { 501 }, name = "黑翼速通", comment = "来敏锐",
		leaderName = "团长甲-晨风号角", numMembers = 5, age = 100,
		requiredItemLevel = 200, leaderOverallDungeonScore = 2400, autoAccept = false, isDelisted = false,
	}
	S.results[12] = {
		searchResultID = 12, activityIDs = { 502 }, name = "+10 旋云", comment = "限时",
		leaderName = "团长乙-晨风号角", numMembers = 4, age = 50,
		requiredItemLevel = 180, leaderOverallDungeonScore = 1800, autoAccept = true, isDelisted = false,
	}
	S.results[13] = {
		searchResultID = 13, activityIDs = { 502 }, name = "+7 通灵 补坦", comment = "",
		leaderName = nil, numMembers = 3, age = 20, requiredItemLevel = 0,
		leaderOverallDungeonScore = nil, autoAccept = false, isDelisted = false,
	}
	S.resultIDs = { 11, 12, 13 }

	S.nativeSearchText="毒牙祭坛（史诗钥石）"
	local ok = G.Search:Search("3", nil)
	T.ok(ok, "团本搜索提交成功")
 T.eq(S.searchCalls[#S.searchCalls].nativeSearchText,"","独立分类请求清掉其他界面遗留的注册搜索文本与活动token")
	T.eq(S.searchCalls[#S.searchCalls].categoryID, 3, "原生分类 3")
	T.eq(G.Search:GetState(), "searching")
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	T.eq(G.Search:GetState(), "done")
	T.eq(G.Results:GetCount(), 3, "完整合法结果不截断")
	T.ok(notifications.results and notifications.search, "真实搜索链通知订阅者")
	T.eq(#S.createDataHistory, 0, "业务通知不会转成发布招募")

	-- newest 排序:age 升序 → 13,12,11。
	local ids = G.Results:GetResults()
	T.eq(table.concat(ids, ","), "13,12,11", "默认最新在前")
	do
		S.results[12].leaderOverallDungeonScore=0;G.Results:OnResultUpdated(12)
		local reads,players,counts,searches=S.resultReads,S.playerReads,S.memberCountReads,#S.searchCalls
		G.Search:SetFilters({category="seasonDungeon",hideZeroScore=true})
		T.same(G.Results:GetResults(),{},"zero and missing leader scores are excluded like MeetingStone")
		T.eq(S.resultReads,reads);T.eq(S.playerReads,players);T.eq(S.memberCountReads,counts);T.eq(#S.searchCalls,searches,"score filtering uses the existing result snapshot")
		S.results[12].leaderOverallDungeonScore=1;G.Results:OnResultUpdated(12)
		T.same(G.Results:GetResults(),{12},"the threshold includes a leader with exactly one point and responds to updates")
		G.Search:SetFilters({category="seasonDungeon",hideZeroScore=true,maxMembers=3})
		T.same(G.Results:GetResults(),{},"score filtering combines with the other conditions")
		G.Search:SetFilters({category="seasonDungeon"})
		T.same(G.Results:GetResults(),{13,12},"turning score filtering off restores unknown scores")
		S.results[12].leaderOverallDungeonScore=1800;G.Results:OnResultUpdated(12);G.Search:SetFilters({})
	end

	-- 队长姓名是可公开读取的普通字符串，可以由统一搜索文本本地匹配。
	local nativeTitle=setmetatable({}, {__index=function() error("native result text must not be parsed") end})
	S.results[12].name,S.results[12].comment=nativeTitle,nativeTitle
	G.Results:OnResultUpdated(12)
	G.Search:SetFilters({text="限时",minLevel=8,maxLevel=15})
	T.eq(table.concat(G.Results:GetResults(),","),"13,12,11","legacy local text and level filters do not hide native search results")
	T.eq(G.Results:GetResult(12).name,nativeTitle,"native display text is retained without parsing")
	T.eq(G.Results:GetResult(12).level,nil,"key level is not guessed from the title")
	T.ok(G.Results:BlockTitle(nativeTitle))
	T.eq(table.concat(G.Results:GetResults(),","),"13,11","exact native title keys are matched without inspecting or converting them")
	G.Results:ClearBlockedTitles()
	S.results[12].name,S.results[12].comment="+10 旋云","限时"
	G.Results:OnResultUpdated(12)
	G.Search:SetFilters({})
	G.Search:SetFilters({leaderText="团长甲"})
	T.eq(table.concat(G.Results:GetResults(),","),"11","leader search matches the public captain name")
	local originalLeaderName=S.results[11].leaderName
	S.results[11].leaderName="灵止光-晨风号角"
	G.Results:OnResultUpdated(11)
	G.Search:SetFilters({leaderText="灵止光"})
	T.eq(table.concat(G.Results:GetResults(),","),"11","leader search matches a captain's character name")
	S.results[11].leaderName="Captain-Home"
	G.Results:OnResultUpdated(11)
	G.Search:SetFilters({leaderText="  CAPTAIN  "})
	T.eq(table.concat(G.Results:GetResults(),","),"11","leader search trims the query and ignores English case")
	G.Search:SetFilters({leaderText=" \t "})
	T.eq(table.concat(G.Results:GetResults(),","),"13,12,11","blank leader query retains every result including an unknown leader")
	G.Search:SetFilters({leaderText=42})
	T.eq(table.concat(G.Results:GetResults(),","),"13,12,11","non-string leader query retains the established unfiltered behavior")
	S.results[11].leaderName=originalLeaderName
	G.Results:OnResultUpdated(11)
	S.results[13].comment="没有团长名时仍可按备注筛选"
	G.Results:OnResultUpdated(13)
	G.Search:SetFilters({leaderText="仍可按备注"})
	T.eq(table.concat(G.Results:GetResults(),","),"","leader mode ignores descriptions when leaderName is nil")
	G.Search:SetFilters({})

	do
		local title=S.results[12].name
		local original=S.results[11].name
		S.results[11].name=title;G.Results:OnResultUpdated(11)
		local reads,memberReads,searches=S.resultReads,S.memberCountReads,#S.searchCalls
		local notices=notifications.results
		T.ok(G.Results:BlockTitle(title))
		T.same(G.Results:GetResults(),{13},"blocking one title hides every exact match")
		T.eq(G.Results:GetCount(),3,"title blocking keeps the complete result snapshot")
		T.eq(G.Results:BlockTitle(title),false);T.eq(G.Results:BlockTitle(nil),false)
		T.eq(G.Results:GetBlockedTitleCount(),1);T.eq(notifications.results,notices+1,"one new title invalidates the view once")
		T.eq(S.resultReads,reads);T.eq(S.memberCountReads,memberReads);T.eq(#S.searchCalls,searches,"blocking only filters existing records")
		G.Search:SetFilters({leaderText="团长甲"})
		T.ok(G.Results:ClearBlockedTitles());T.same(G.Results:GetResults(),{11},"clearing title blocks preserves the other filters")
		T.eq(S.resultReads,reads);T.eq(S.memberCountReads,memberReads)
		G.Search:SetFilters({});G.Results:BlockTitle(title)
		S.results[14]={searchResultID=14,activityIDs={502},name=title,numMembers=1,age=1}
		S.resultIDs={11,12,13,14}
		G.Results:BeginSearch(G.Results.gen);G.Results:CommitResults(G.Results.gen)
		T.same(G.Results:GetResults(),{13},"new searches also hide newly received groups with a blocked title")
		S.results[14].name=title.." ";G.Results:OnResultUpdated(14)
		T.same(G.Results:GetResults(),{14,13},"title blocking uses the full exact title, including spaces")
		G.Results:ClearBlockedTitles();notices=notifications.results
		T.eq(G.Results:ClearBlockedTitles(),false);T.eq(notifications.results,notices,"clearing an empty set does not refresh the view")
		T.eq(G.Results:GetBlockedTitleCount(),0)
		S.results[11].name=original;S.results[14]=nil;S.resultIDs={11,12,13}
		G.Results:BeginSearch(G.Results.gen);G.Results:CommitResults(G.Results.gen)
	end

	-- 好友优先作为所有常用排序的第一关键字。
	do
		S.results[11].numBNetFriends=1;S.results[12].numCharFriends=1;S.results[13].numGuildMates=1
		for id=11,13 do G.Results:OnResultUpdated(id) end
		local reads,memberReads,playerReads=S.resultReads,S.memberCountReads,S.playerReads
		for sort,expected in pairs({newest={12,11,13},rating={11,12,13},itemLevel={11,12,13},members={11,12,13}}) do
			G.Search:SetFilters({sort=sort})
			T.same(G.Results:GetResults(),expected,"friend groups precede other groups while retaining the chosen sort within both sets")
		end
		T.eq(S.resultReads,reads);T.eq(S.memberCountReads,memberReads);T.eq(S.playerReads,playerReads,"friend priority uses aggregate counts without looking up leaders or members")
		S.results[11].numBNetFriends=0;S.results[12].numCharFriends=0
		G.Results:OnResultUpdated(11);G.Results:OnResultUpdated(12);G.Search:SetFilters({})
		T.same(G.Results:GetResults(),{13,12,11},"native friend-count changes update priority, and guild membership alone gives no priority")
		S.results[13].numGuildMates=0;G.Results:OnResultUpdated(13)
	end

	-- 规范化字段与身份。
	local record = G.Results:GetResult(11)
	T.eq(record.activityName, "黑翼之巢")
	T.eq(record.leaderKey, "团长甲-晨风号角")
	T.eq(G.Results:GetResult(13).leaderKey, nil, "leaderName 缺失时键为 nil")
	T.eq(record.bnetFriends, 0)
	S.players[12]={{name="治疗者-晨风号角",classFilename="PRIEST",className="牧师",assignedRole="HEALER",specName="神圣",isLeader=true}}
	S.counts[12]={TANK=0,HEALER=1,DAMAGER=3}
	S.counts[13]={TANK=1,HEALER=0,DAMAGER=2}
	S.encounters[12]={"已击败的首领"}
	local countReads,encounterReads=S.memberCountReads,S.encounterReads or 0
	local details=G:GetResultDetails(12)
	T.eq(S.memberCountReads,countReads,"individual party avatars do not fetch the unused native class/spec count maps")
	T.eq(details.members[1].nameKey,"治疗者-晨风号角","成员身份与姓名来自原生数据")
	T.eq(details.members[1].specName,"神圣")
	T.eq(details.members[1].class,"PRIEST")
	T.eq(S.encounterReads or 0,encounterReads,"party details never request unused raid encounter progress")
	T.eq(details.encounters,nil,"party details do not retain encounter progress")
	S.results[12].numCharFriends=1;S.results[12].numBNetFriends=1;S.results[12].numGuildMates=1
	S.friends[12]={character={"治疗者-晨风号角"},bnet={"战网昵称"},guild={"治疗者-晨风号角"}}
	G.Results:OnResultUpdated(12);details=G:GetResultDetails(12)
	T.eq(details.members[1].isCharFriend,nil,"寻队角色好友名单不归因给成员或队长")
	T.eq(details.members[1].isGuildMate,nil,"寻队公会名单也不归因给成员")
	T.eq(details.members[1].isBNetFriend,nil,"寻队成员不附带战网关系标记")
	T.same(details.relationships,{bnet={"战网昵称"},character={"治疗者-晨风号角"},guild={"治疗者-晨风号角"}},"三类原生关系姓名独立保留")
	T.eq(G:GetResult(12).bnetFriends,1);T.eq(G:GetResult(12).charFriends,1);T.eq(G:GetResult(12).guildMates,1)
	local relationshipReads=S.playerReads
	G.Search:SetFilters({friends=true});T.same(G:GetResults(),{12},"原生好友聚合计数保留好友筛选")
	S.results[12].numBNetFriends=0;G.Results:OnResultUpdated(12)
	T.same(G:GetResults(),{12},"只有角色好友计数时仍命中好友筛选")
	S.results[12].numCharFriends=0;S.results[12].numBNetFriends=1;G.Results:OnResultUpdated(12)
	T.same(G:GetResults(),{12},"只有战网好友计数时仍命中好友筛选")
	G.Search:SetFilters({guild=true});T.same(G:GetResults(),{12},"原生公会聚合计数保留公会筛选")
	T.eq(S.playerReads,relationshipReads,"原生关系筛选无需扫描成员名单")
	S.results[12].numCharFriends=0;S.results[12].numBNetFriends=0;S.results[12].numGuildMates=0
	G.Results:OnResultUpdated(12);details=G:GetResultDetails(12)
	T.eq(details.members[1].isCharFriend,nil,"名单变化不生成成员关系标记")
	T.eq(details.relationships,nil)
	local reads=S.playerReads
	T.eq(G:GetResultDetails(12),details,"行与提示共用成员快照")
	T.eq(S.playerReads,reads,"重复显示不重读成员")
	G.Search:SetFilters({neededRole="TANK"})
	T.eq(table.concat(G.Results:GetResults(),","),"12","仅五人队伍的实际空缺命中职责筛选")
	G.Search:SetFilters({neededRole="HEALER"})
	T.eq(table.concat(G.Results:GetResults(),","),"13")
	G.Search:SetFilters({tankPresence="missing",healerPresence="present"})
	T.eq(table.concat(G.Results:GetResults(),","),"12","缺坦克与已有治疗可组合")
	G.Search:SetFilters({tankPresence="present",healerPresence="missing",damagePresence="missing"})
	T.eq(table.concat(G.Results:GetResults(),","),"13","已有坦克、缺治疗、缺输出共同过滤")
	G.Search:SetFilters({healerPresence="present",damagePresence="missing"})
	T.eq(#G.Results:GetResults(),0,"已有三名输出的队伍不命中缺输出")
	G.Search:SetFilters({damagePresence="present"})
	T.same(G.Results:GetResults(),{12},"恰好三名输出命中已齐，两名输出不命中")
	S.counts[13].DAMAGER=0;G.Results:OnResultUpdated(13)
	G.Search:SetFilters({damagePresence="missing"})
	T.same(G.Results:GetResults(),{13},"零名输出仍命中缺少")
	S.counts[13].DAMAGER=4;G.Results:OnResultUpdated(13)
	G.Search:SetFilters({damagePresence="present"})
	T.same(G.Results:GetResults(),{13,12},"三名以上输出也命中已齐")
	G.Search:SetFilters({tankPresence="present",healerPresence="missing",damagePresence="present"})
	T.same(G.Results:GetResults(),{13},"已有坦克、缺治疗、输出已齐仍按 AND 合并")
	S.counts[13]={TANK=1,DAMAGER=2};G.Results:OnResultUpdated(13)
	G.Search:SetFilters({healerPresence="missing"})
	T.eq(#G.Results:GetResults(),0,"未知职责人数不当成缺少该职责")
	S.counts[13]={TANK=1,HEALER=0,DAMAGER=2};G.Results:OnResultUpdated(13)
	S.results[13].activityIDs={503};G.Results:OnResultUpdated(13)
	G.Search:SetFilters({category="seasonDungeon",groupKeys={[20]=true}})
	T.same(G.Results:GetResults(),{12},"副本集合只保留所选副本的结果")
	G.Search:SetFilters({category="seasonDungeon",groupKeys={[20]=true,[-503]=true}})
	T.same(G.Results:GetResults(),{13,12},"多个副本合并结果并保留统一排序")
	G.Search:SetFilters({category="seasonDungeon",groupKeys={[-503]=true},damagePresence="missing"})
	T.same(G.Results:GetResults(),{13},"副本多选与职责条件组合")
	S.results[13].activityIDs={502};G.Results:OnResultUpdated(13)
	local previousNotes=A.Notes
	A.Notes=nil;G.Search:SetFilters({notes="noCaution"})
	T.same(G.Results:GetResults(),{13,12,11},"排除拉黑记录在没有笔记时保留所有队伍")
	local members12,members13,count12,leader12=S.players[12],S.players[13],S.results[12].numMembers,S.results[12].leaderName
	S.players[12]={{name=leader12,classFilename="WARRIOR",isLeader=true},{name="治疗者-晨风号角",classFilename="PRIEST"}}
	S.players[13]={{name="身份未公开的队长-银松森林",classFilename="MAGE",isLeader=true}}
	S.results[12].numMembers=2;G.Results:OnResultUpdated(12);G.Results:OnResultUpdated(13)
	local noteRecords={["治疗者-晨风号角"]={type="positive"},["身份未公开的队长-银松森林"]={type="positive"}}
	local noteQueries={}
	A.Notes={Find=function(_,key) noteQueries[key]=(noteQueries[key] or 0)+1;return noteRecords[key] end}
	local noteMemberReads=S.playerReads
	G.Search:SetFilters({notes="positive"})
	T.same(G.Results:GetResults(),{},"只有非队长的推荐笔记不能命中寻队筛选，队长完整身份缺失也不借用成员身份")
	G.Search:SetFilters({notes="any"});T.same(G.Results:GetResults(),{},"任意笔记筛选也只查询完整身份的队长")
	noteRecords["治疗者-晨风号角"].type="caution"
	G.Search:SetFilters({notes="noCaution"});T.same(G.Results:GetResults(),{13,12,11},"非队长拉黑记录不在入队前排除整队")
	noteRecords["团长甲-晨风号角"]={type="caution"};G.Results:InvalidateView()
	T.same(G.Results:GetResults(),{13,12},"不含拉黑记录仍排除完整身份命中的拉黑队长")
	noteRecords[leader12]={type="positive"};G.Search:SetFilters({notes="positive"})
	T.same(G.Results:GetResults(),{12},"完整身份的推荐队长命中，同行的拉黑记录不改变队长结果")
	noteRecords[leader12].type="neutral";G.Search:SetFilters({notes="neutral"})
	T.same(G.Results:GetResults(),{12},"中性笔记使用同一队长范围")
	G.Search:SetFilters({notes="any"});T.same(G.Results:GetResults(),{12,11},"任意笔记保留不同类型的已知队长")
	S.results[12].leaderName="团长乙";G.Results:OnResultUpdated(12)
	G.Search:SetFilters({notes="neutral"});T.same(G.Results:GetResults(),{},"裸名队长不被当成本服完整身份，也不扫描名单补猜")
	T.eq(S.playerReads,noteMemberReads,"笔记筛选不读取队员详情")
	T.eq(noteQueries["治疗者-晨风号角"],nil,"寻队不查询非队长的笔记")
	T.eq(noteQueries["身份未公开的队长-银松森林"],nil,"不使用成员名单推断结果未提供的队长身份")
	S.players[12],S.players[13],S.results[12].numMembers,S.results[12].leaderName=members12,members13,count12,leader12
	G.Results:OnResultUpdated(12);G.Results:OnResultUpdated(13)
	A.Notes=previousNotes
	G.Search:SetFilters({})
end

do
	-- 代次守卫:旧代次迟到结果不覆盖新查询。
	local oldGen = G.Search:GetGeneration()
	G.Search:Search("seasonDungeon", nil)
	T.eq(#S.searchCalls[#S.searchCalls].activityFilter, 3, "赛季地图搜索包含其原生全部难度")
	G.Results:CommitResults(oldGen)
	T.eq(G.Results:GetCount(), 0, "旧代次结果被拒绝")
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	T.eq(G.Results:GetCount(), 3, "新代次正常提交")

	-- 单条更新与下架移除。
	S.results[12].numMembers = 5
	Fire("LFG_LIST_SEARCH_RESULT_UPDATED", 12)
	G.Game.frame:GetScript("OnUpdate")()
	T.eq(G.Results:GetResult(12).numMembers, 5, "单条更新生效")
	S.players[12][1].specName="戒律"
	T.eq(G:GetResultDetails(12).members[1].specName,"戒律","成员快照随队伍更新失效")
	S.results[11].isDelisted = true
	Fire("LFG_LIST_SEARCH_RESULT_UPDATED", 11)
	G.Game.frame:GetScript("OnUpdate")()
	T.eq(G.Results:GetResult(11), nil, "下架结果移除")
	S.results[11].isDelisted = false
end

do
	-- 搜索失败:受保护拒绝回到 idle,发布失败状态。
	S.failSearch = true
	local ok, err = G.Search:Search("3", nil)
	T.eq(ok, false)
	T.ok(err)
	T.eq(G.Search:GetState(), "failed")
	T.eq(G.Search:GetSearchError(), err, "提交受限保留实际失败状态")
	S.failSearch = false
	-- 失败后的流式更新事件被忽略,不伪造新结果。
	local before = G.Results:GetCount()
	S.resultIDs = { 11 }
	Fire("LFG_LIST_UPDATE_SEARCH_RESULTS")
	T.eq(G.Results:GetCount(), before, "idle 状态忽略流式更新")
	S.resultIDs = { 11, 12, 13 }
end

do
	-- 同步事件发生在 Search 返回前时,仓库必须已经归属本次请求。
	S.syncSearch = "results"
	T.ok(G.Search:Search("3"))
	T.eq(G.Search:GetState(), "done", "同步完成事件不被提交后的初始化覆盖")
	T.eq(G:GetResultCount(), 3, "同步返回的完整结果不会随后被清空")
	S.syncSearch = "failed"
	G.Search:Search("3")
	T.eq(G.Search:GetState(), "waiting", "同步节流进入等待恢复状态")
	T.eq(G:GetSearchError(), G.L.searchThrottled:format(5), "节流原因本地化并说明自动恢复")
	T.eq(G:GetResultCount(), 0)
	S.syncSearch = nil
	G.Search:EndBrowse()
end

-- ---------------------------------------------------------------- 申请状态

do
	G.Search:Search("3", nil)
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")

	local published={}
	local refresh=G.Game.RefreshRelations
	G.Game.RefreshRelations=function(self) published[#published+1]="relations";return refresh(self) end
	local stopWatching=G:Subscribe(function(kind) if kind=="applications" then published[#published+1]="applications" end end)
	local ok = G.Applications:Apply(11, { tank = true, damage = true })
	stopWatching();G.Game.RefreshRelations=refresh
	T.same(published,{"applications"},"application changes notify consumers without refreshing an unrelated relationship service")
	T.ok(ok, "申请提交")
	T.eq(S.applyCalls[#S.applyCalls].tank, true)
	T.eq(S.applyCalls[#S.applyCalls].damage, true)
	T.eq(G.Applications:GetApplication(11).status, "applied", "提交后读回状态")
	T.ok(notifications.applications, "真实申请链通知订阅者")

	local dup = G.Applications:Apply(11, { tank = true })
	T.eq(dup, false, "重复申请被拒绝")

	-- 邀请到达 → 可接受。
	Fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 11, "invited", "applied", "黑翼速通")
	T.eq(G.Applications:GetApplication(11).status, "invited")
	T.eq(G.Applications:GetApplication(11).name, "黑翼速通", "事件 groupName 记录名称")
	T.ok(G.Applications:AcceptInvite(11), "接受邀请")
	Fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 11, "inviteaccepted", "invited", "黑翼速通")
	T.eq(G.Applications:GetApplication(11).status, "inviteaccepted")
	T.eq(G.Applications:GetActiveCount(), 0, "接受成功是申请终态")

	-- 原生已结束的申请在下一次同步时移除。
	table.remove(S.applications, 1)
	S.appStatus[11] = "timedout"
	Fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 11, "timedout", "inviteaccepted", "黑翼速通")
	T.eq(G.Applications:GetApplication(11).status, "timedout")
end

-- A native failure during submission must never be replaced with a fake pending application.
do
 local apply,cancel=C_LFGList.ApplyToGroup,C_LFGList.CancelApplication
 local cancelled,updates=0,0
 local unsub=G:Subscribe(function(kind) if kind=="applications" then updates=updates+1 end end)
 C_LFGList.CancelApplication=function(id) cancelled=cancelled+1;cancel(id) end
 C_LFGList.ApplyToGroup=function(id)
  S.appStatus[id]="failed"
  G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",id,"failed","none")
 end
 T.ok(G:Apply(21,{damage=true}),"a submission request can finish without a Lua exception")
 T.eq(G.Applications:IsActive(21),false,"a synchronous terminal event with no native ID must not be resurrected as pending")
 T.eq(G:GetApplication(21),nil,"native-absent terminal entries are removed even while browsing")
 C_LFGList.ApplyToGroup=function() end
 T.ok(G:Apply(22,{damage=true}))
 T.eq(G:GetApplication(22),nil,"a void request without native data never manufactures an application")
 S.applications={22};S.appStatus[22]="none";S.appPending[22]="applied"
 G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",22,"none","none")
 T.ok(G.Applications:IsActive(22),"a later native pending event still becomes an active submission")
 T.eq(G.Applications:CanCancel(22),false,"role-check or submission pending entries cannot be cancelled")
 T.eq(G:Cancel(22),false);T.eq(cancelled,0,"a stale pending button does not call the cancellation API")
 S.appStatus[22]="applied";S.appPending[22]="cancelled"
 G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",22,"applied","none")
 T.eq(G.Applications:IsActive(22),false,"a pending cancellation stops occupying an active slot")
 T.eq(G.Applications:GetActiveCount(),0)
 S.appStatus[22]="timedout";S.appPending[22]="applied"
 G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",22,"timedout","applied")
 T.eq(G.Applications:IsActive(22),false,"a terminal event wins over a stale pending-applied field")
 S.applications={};G.Applications:SyncAll()
 T.eq(G:GetApplication(22),nil,"synchronization removes an absent ended entry while its page stays open")

 C_LFGList.ApplyToGroup=apply
 T.ok(G:Apply(23,{damage=true}));T.ok(G.Applications:CanCancel(23))
 local notified=updates
 T.ok(G:Cancel(23))
 T.eq(G:GetApplication(23),nil,"synchronous native cancellation without an event is read back")
 T.eq(G.Applications:GetActiveCount(),0)
 T.ok(updates>notified,"the page receives cancellation state even without a native event")

 T.ok(G:Apply(24,{damage=true}))
 C_LFGList.CancelApplication=function(id) cancelled=cancelled+1;S.appPending[id]="cancelled" end
 local before=cancelled
 T.ok(G:Cancel(24));T.eq(G:GetApplication(24).status,"applied","the native current status is not optimistically rewritten")
 T.eq(G:GetApplication(24).pendingStatus,"cancelled")
 T.eq(G.Applications:IsActive(24),false);T.eq(G:Cancel(24),false)
 T.eq(cancelled,before+1,"pending cancellation cannot submit a second request")
 local applied=#S.applyCalls
 local allowed,reason=G:Apply(24,{damage=true})
 T.eq(allowed,false,"reapplying while native cancellation is pending is rejected")
 T.eq(reason,A.GroupLocale.actionBusy);T.eq(#S.applyCalls,applied,"pending cancellation never reaches ApplyToGroup")
 local cancellationEvents=0
 local cancelUnsub=G:Subscribe(function(kind,id) if kind=="applicationCancelled" and id==24 then cancellationEvents=cancellationEvents+1 end end)
 S.appStatus[24],S.appPending[24]="cancelled",nil
 Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",24,"cancelled","applied")
 T.eq(cancellationEvents,1,"a confirmed cancellation requests one browse refresh")
 G.Applications:SyncAll();Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",24,"cancelled","cancelled")
 T.eq(cancellationEvents,1,"duplicate native cancellation snapshots never request another search")
 allowed,reason=G:Apply(24,{damage=true})
 T.eq(allowed,false,"a cancelled native search result cannot be reported as a new application")
 T.eq(reason,A.GroupLocale.applicationCancelled);T.eq(#S.applyCalls,applied)
 local cancelledClock=S.now;S.now=S.now+5;Stubs.AdvanceClock(5)
 T.eq(G:GetApplication(24),nil,"the finished local display record retires normally")
 T.eq(G:Apply(24,{damage=true}),false,"retiring the local record does not make the cancelled native result reusable")
 T.eq(#S.applyCalls,applied);S.now=cancelledClock;cancelUnsub()
 S.applications={};G.Applications:SyncAll()

 T.ok(G:Apply(25,{damage=true}))
 C_LFGList.CancelApplication=function() cancelled=cancelled+1 end
 T.ok(G:Cancel(25));T.ok(G.Applications:IsActive(25),"an unchanged native snapshot stays active until confirmation")
 S.applications={};S.appStatus[25]="none"
 T.ok(G:Cancel(25));T.eq(G:GetApplication(25),nil,"a native-absent stale row disappears after a no-op cancellation")

 T.ok(G:Apply(26,{damage=true}))
 C_LFGList.CancelApplication=function(id) cancelled=cancelled+1;cancel(id);G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",id,"cancelled","applied") end
 before=cancelled
 T.ok(G:Cancel(26));T.eq(cancelled,before+1);T.eq(G:GetApplication(26),nil,"synchronous events and cancellation readback converge without resurrecting a row")

 T.ok(G:Apply(27,{damage=true}))
 local clock=S.now;before=cancelled;S.now=clock+121
 T.ok(G.Applications:IsActive(27),"the local display deadline never fabricates a terminal native status")
 T.eq(cancelled,before,"elapsed display time does not automatically submit a cancellation")
 S.now=clock;C_LFGList.CancelApplication=cancel
 T.ok(G:Cancel(27));T.eq(G.Applications:GetActiveCount(),0)
 unsub()
end

-- ---------------------------------------------------------------- 招募/申请者

do
 local create,getNum=C_LFGList.CreateListing,C_LFGList.GetNumApplications
 local activeApplications=1
 C_LFGList.CreateListing=function() return false end
 C_LFGList.GetNumApplications=function() return 3,activeApplications end
 local ok,reason=G:Publish({activityID=501})
 T.eq(#G.Presets:Get(),0,"a refused publish does not create a favorite")
 T.eq(ok,false,"native creation refusal is not reported as a successful listing")
 T.eq(reason,"你还有有效的组队申请，处理完成后才能发布组队。","active applications receive a specific creation refusal")
 T.eq(G:GetListing(),nil,"a refused listing does not create a local snapshot")
 activeApplications=0
 ok,reason=G:Publish({activityID=501})
 T.eq(ok,false);T.eq(reason,A.GroupLocale.publishFailed,"historical applications do not explain an unrelated native creation failure")
 C_LFGList.CreateListing,C_LFGList.GetNumApplications=create,getNum
end

do
	local favorite=G.Presets:ToggleFavorite({activityID=501,requiredItemLevel=175})
	local ok, err = G.Listing:Publish({
		activityID = 501, requiredItemLevel = 200, isAutoAccept = false,
		isPrivateGroup = false, isCrossFactionListing = false,
	})
	T.ok(ok, "发布组队")
	T.ok(notifications.listing, "招募发布后通知订阅者,动作门面与通知分开")
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_APPLICANT_UPDATED"), 1, "真实招募期间监听申请者")
	local listing = G.Listing:GetListing()
	T.ok(listing, "发布后存在招募快照")
	T.eq(listing.activityName, "黑翼之巢")
	T.eq(listing.name, "原生标题", "标题来自原生快照(不可编程提交)")
	T.eq(#G.Presets:Get(),1,"publishing never creates another favorite")
	T.eq(G.Presets:Get()[1],favorite);T.eq(favorite.requiredItemLevel,175,"publishing does not change saved requirements")

	-- 同阵营更新走 UpdateListing。
	S.activeEntry.generalPlaystyle = 2
 G.Listing:OnEntryUpdate()
	S.activeEntry.questID = 12345
 G.Listing:OnEntryUpdate()
	ok = G.Listing:Update({ activityID = 501, requiredItemLevel = 220, isCrossFactionListing = false })
	T.ok(ok, "同阵营更新组队")
	T.eq(S.createDataHistory[#S.createDataHistory].op, "update", "同阵营走 Update")
	T.eq(G.Listing:GetListing().requiredItemLevel, 220)
	T.eq(#G.Presets:Get(),1);T.eq(favorite.requiredItemLevel,175,"native entry events and successful updates do not alter favorites")
	local updateData = S.createDataHistory[#S.createDataHistory].data
	T.eq(updateData.generalPlaystyle, 2, "未编辑的原生玩法字段保留")
	T.eq(updateData.questID, 12345, "未编辑的原生任务字段保留")

	-- 跨阵营变更走先下架再创建。
	ok = G.Listing:Update({ activityID = 501, isCrossFactionListing = true })
	T.ok(ok, "跨阵营更新组队")
	T.eq(S.createDataHistory[#S.createDataHistory].op, "create", "跨阵营变更 Remove 后 Create")
	T.ok(S.removeCalls >= 1, "跨阵营变更触发下架")
	T.ok(S.activeEntry ~= nil, "更新后仍有招募")

	-- 申请者列表。
	S.applicants[701] = {
		applicantID = 701, applicationStatus = "applied", pendingApplicationStatus = nil,
		numMembers = 2, isNew = true, comment = "带朋友", displayOrderID = 2,
	}
	S.applicants[702] = {
		applicantID = 702, applicationStatus = "applied", pendingApplicationStatus = nil,
		numMembers = 1, isNew = false, comment = "", displayOrderID = 1,
	}
	S.applicantMembers[701] = {
		{ name = "申请甲-晨风号角", class = "DEATHKNIGHT", localizedClass = "死亡骑士", level = 80, itemLevel = 210, tank = true, damage = true, assignedRole = "DAMAGER", specID = 252 },
		{ name = "申请乙-银松森林", class = "PALADIN", localizedClass = "圣骑士", level = 80, itemLevel = 205, healer = true },
	}
	S.applicantMembers[702] = {
		{ name = "申请丙-晨风号角", class = "MAGE", localizedClass = "法师", level = 80, itemLevel = 220, damage = true, dungeonScore = 2600 },
	}
	Fire("LFG_LIST_APPLICANT_LIST_UPDATED")
	local ids = G.Applicants:GetApplicants()
	T.eq(table.concat(ids, ","), "702,701", "非新申请在前,再按 displayOrderID")
	local applicant = G.Applicants:GetApplicant(701)
	T.eq(#applicant.members, 2, "多成员申请成组")
	T.eq(applicant.members[1].nameKey, "申请甲-晨风号角")
	T.eq(applicant.members[2].nameKey, "申请乙-银松森林")
	local dk=applicant.members[1]
	T.eq(dk.requestedRoles.TANK,true,"邪恶专精申请者保留报名坦克")
	T.eq(dk.requestedRoles.DAMAGER,true,"同一申请同时保留报名输出")
	T.eq(dk.requestedRoles.HEALER,false)
	T.eq(dk.specID,252,"报名职责不改写当前邪恶专精")
	T.eq(dk.assignedRole,"DAMAGER","原生分配职责与报名职责分别保留")
	local requested=dk.requestedRoles
	S.applicantMembers[701][1].tank=false
	Fire("LFG_LIST_APPLICANT_UPDATED",701)
	T.eq(dk.requestedRoles,requested,"刷新复用报名职责集合")
	T.eq(dk.requestedRoles.TANK,false,"取消的报名职责不会残留")
	T.eq(dk.requestedRoles.DAMAGER,true)

	-- 邀请防重入。
	T.ok(G.Applicants:Invite(701), "邀请提交")
	T.eq(G.Applicants:Invite(701), false, "在途动作防重入")
	Fire("LFG_LIST_APPLICANT_UPDATED", 701)
	T.eq(G.Applicants:Invite(701), false, "重复原生事件不恢复在途动作")
 S.applicants[701].applicationStatus="invited";Fire("LFG_LIST_APPLICANT_UPDATED",701)
 T.eq(G.Applicants:GetApplicant(701).status,"invited","原生状态确认邀请")

	-- 结束招募:下架后由原生事件确认并清空申请者。
	T.ok(G.Listing:RemoveListing(), "结束招募")
	Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE", nil)
	T.eq(G.Listing:GetListing(), nil)
	T.eq(G.Applicants:GetCount(), 0, "招募结束清空申请者")
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_APPLICANT_UPDATED"), 0, "招募结束停止申请者监听")
	G.Presets:Remove(favorite);T.eq(#G.Presets:Get(),0)
end

-- ---------------------------------------------------------------- 大秘境历史

do
 -- Confirmed terminal rows retire while the same creation view remains open.
 local clock=S.now
 local function Advance(seconds) S.now=S.now+seconds;Stubs.AdvanceClock(seconds) end
 local getInfo=C_LFGList.GetApplicantInfo;local reads,updates,missingInfo=0,0,nil
 local availabilityRequests=S.availabilityRequests
 C_LFGList.GetApplicantInfo=function(id) reads=reads+1;if id~=missingInfo then return getInfo(id) end end
 local savedApplicants,savedMembers=S.applicants,S.applicantMembers
 S.applicants={};S.applicantMembers={};S.activeEntry={activityIDs={501},name="Retirement test"}
 Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",true)
 local view={};G:Attach(view,"create")
 for _,id in ipairs({8501,8502,8503}) do
  S.applicants[id]={applicationStatus=id==8503 and "invited" or "applied",numMembers=1,displayOrderID=id}
  S.applicantMembers[id]={{name="Retirement"..id.."-Away",class="MAGE",damage=true}}
 end
 G.Applicants:RefreshList(true)
 local unsubscribe=G:Subscribe(function(kind) if kind=="applicants" then updates=updates+1;G:GetApplicants() end end)
 for id,status in pairs({[8501]="cancelled",[8502]="declined"}) do S.applicants[id].applicationStatus=status;Fire("LFG_LIST_APPLICANT_UPDATED",id) end
 T.eq(#G:GetApplicants(),3,"confirmed applicant results remain briefly visible")
 Stubs.AdvanceClock(0) -- Flush the display task before counting expiry work.
 local expiryTimers=Stubs.PendingTimers()
 Advance(4);Fire("LFG_LIST_APPLICANT_UPDATED",8501);G.Applicants:RefreshList(true)
 Stubs.AdvanceClock(0)
 local before,readBefore=updates,reads
 Advance(1)
 T.eq(G:GetApplicant(8501),nil,"a cancelled applicant disappears after five seconds without leaving the page")
 T.eq(expiryTimers,1,"multiple finished applicant rows share one expiry timer")
 T.eq(G:GetApplicant(8502),nil,"a declined applicant expires in the same batch")
 T.eq(updates,before+1,"one expiry batch produces one applicant notification")
 T.eq(reads,readBefore,"expiry only removes local rows, without polling native applicants")
 T.same(G:GetApplicants(),{8503});T.eq(Stubs.PendingTimers(),0)
 G.Applicants:RefreshList(true);Fire("LFG_LIST_APPLICANT_UPDATED",8501)
 T.eq(G:GetApplicant(8501),nil,"a repeated terminal native snapshot does not resurrect an expired row")
 missingInfo=8502;Fire("LFG_LIST_APPLICANT_UPDATED",8502);missingInfo=nil;G.Applicants:RefreshList(true)
 T.eq(G:GetApplicant(8502),nil,"temporarily unavailable details do not end an ID still present in the native applicant list")
 S.applicants[8501].applicationStatus="applied";Fire("LFG_LIST_APPLICANT_UPDATED",8501);G.Alerts:Stop()
 T.eq(G:GetApplicant(8501).status,"applied","a new applied round can reuse a retired applicant ID")
 S.applicants[8501].pendingApplicationStatus="cancelled";Fire("LFG_LIST_APPLICANT_UPDATED",8501)
 Advance(6)
 T.ok(G:GetApplicant(8501),"pending cancellation is not a confirmed terminal state")
 T.eq(G:GetApplicant(8503).status,"invited","an invitation is never retired by the five-second display deadline")
 S.applicants[8501].applicationStatus="cancelled";S.applicants[8501].pendingApplicationStatus=nil;Fire("LFG_LIST_APPLICANT_UPDATED",8501)
 Advance(2);S.applicants[8502].applicationStatus="applied";Fire("LFG_LIST_APPLICANT_UPDATED",8502);G.Alerts:Stop()
 S.applicants[8502].applicationStatus="declined";Fire("LFG_LIST_APPLICANT_UPDATED",8502)
 Advance(3)
 T.eq(G:GetApplicant(8501),nil);T.ok(G:GetApplicant(8502),"the next deadline keeps its own remaining retention time")
 T.eq(Stubs.PendingTimers(),1,"only the next applicant expiry remains scheduled")
 S.applicants[8502]=nil;G.Applicants:RefreshList(true)
 Stubs.AdvanceClock(0)
 T.eq(G:GetApplicant(8502),nil,"native absence removes an ended applicant before five seconds")
 T.eq(Stubs.PendingTimers(),0,"removing the last finished native ID cancels expiry")
 S.applicants[8504]={applicationStatus="failed",numMembers=1,displayOrderID=8504};S.applicantMembers[8504]={{name="Failed-Away",class="MAGE"}}
 Fire("LFG_LIST_APPLICANT_UPDATED",8504);Stubs.AdvanceClock(0);T.eq(Stubs.PendingTimers(),1)
 S.activeEntry=nil;Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 T.eq(Stubs.PendingTimers(),0,"ending the listing cancels applicant retirement")
 Advance(5);T.eq(#G:GetApplicants(),0)
 unsubscribe();G:Detach(view);C_LFGList.GetApplicantInfo=getInfo
 S.applicants,S.applicantMembers=savedApplicants,savedMembers;S.now=clock;S.availabilityRequests=availabilityRequests
end

do
 -- My applications still release active slots immediately; only retained records expire.
 local clock=S.now;local function Advance(seconds) S.now=S.now+seconds;Stubs.AdvanceClock(seconds) end
 local getInfo=C_LFGList.GetApplicationInfo;local reads,updates=0,0
 C_LFGList.GetApplicationInfo=function(id) reads=reads+1;return getInfo(id) end
 S.applications={8601,8602,8603,8604}
 for _,id in ipairs(S.applications) do S.appStatus[id]="applied";S.appPending[id]=nil end
 S.appStatus[8603]="invited";S.appPending[8604]="cancelled"
 G.Applications:SyncAll()
 local unsubscribe=G:Subscribe(function(kind) if kind=="applications" then updates=updates+1;G:GetApplications() end end)
 for id,status in pairs({[8601]="cancelled",[8602]="declined"}) do S.appStatus[id]=status;Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",id,status,"applied") end
 T.eq(G.Applications:GetActiveCount(),1,"confirmed terminals immediately stop occupying application slots")
 T.eq(Stubs.PendingTimers(),1,"finished applications share one expiry timer")
 Advance(4);Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",8601,"cancelled","cancelled");G.Applications:SyncAll()
 local before,readBefore=updates,reads
 Advance(1)
 T.eq(G:GetApplication(8601),nil,"finished applications are released while the browse view remains open")
 T.eq(G:GetApplication(8602),nil);T.eq(updates,before+1,"application expiry emits one batched notification")
 T.eq(reads,readBefore,"retiring applications never polls native state")
 T.eq(Stubs.PendingTimers(),0)
 G.Applications:SyncAll();Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",8601,"cancelled","cancelled")
 T.eq(G:GetApplication(8601),nil,"a repeated terminal application snapshot cannot resurrect a retired record")
 S.appPending[8602]="applied";G.Applications:SyncAll()
 T.eq(G:GetApplication(8602),nil,"stale pending-applied data cannot revive a confirmed terminal")
 S.appStatus[8601]="applied";Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",8601,"applied","cancelled")
 T.ok(G.Applications:IsActive(8601),"a new applied round reuses the original application ID")
 Advance(6)
 T.eq(G:GetApplication(8603).status,"invited","invited applications do not expire on a local retirement deadline")
 T.ok(G:GetApplication(8604),"pending cancellation remains until a native confirmation or native removal")
 T.ok(G.Applications:IsActive(8601))
 S.appStatus[8601]="failed";Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",8601,"failed","applied")
 T.eq(Stubs.PendingTimers(),1)
 S.applications={};G.Applications:SyncAll()
 T.eq(Stubs.PendingTimers(),0,"native absence cancels the final application expiry")
 T.eq(#G:GetApplications(),0)
 unsubscribe();C_LFGList.GetApplicationInfo=getInfo;S.now=clock
end

do
	-- 进行中的秘境:开始 → 采集 → 完成 → 写入。
	Stubs.SetUnit("party1", { name = "队友甲", realm = "晨风号角", class = "PALADIN", classID = 2, guid = "P-1" })
	Stubs.SetUnit("party2", { name = "队友乙", realm = "银松森林", class = "MAGE", classID = 1, guid = "P-2" })
	Stubs.SetInspectSpec("party1", 66)
	Stubs.SetInspectSpec("party2", 0)
	S.activeMap = 502
	S.keystoneLevel = 10

	Fire("CHALLENGE_MODE_START", 502)
	local active = G.History:GetActiveRun()
	T.ok(active, "run 开始")
	T.eq(active.mapName, "测试秘境·502")
	T.eq(active.level, 10, "层数来自钥石信息")
	T.eq(#active.members, 3, "含自己在内 3 名成员")
	T.eq(G.charDB.activeRun.id, active.id, "进行中基线直接持久到角色存档")
	Stubs.SetTime(active.startedAt + 60)
	Fire("CHALLENGE_MODE_START", 502)
	T.eq(G.History:GetActiveRun().id, active.id, "同一次 START 交接不重建run")
	T.eq(G.History:GetActiveRun().startedAt, active.startedAt, "重复开始保留原开始时间")
	local selfMember
	for _, m in ipairs(active.members) do
		if m.isSelf then selfMember = m end
	end
	T.eq(selfMember and selfMember.name, "本人", "成员含自己并标注")

	-- 中途加入的成员在队伍事件中补录。
	Stubs.SetUnit("party3", { name = "队友丙", realm = "晨风号角", class = "WARRIOR", classID = 1, guid = "P-3" })
	Fire("GROUP_ROSTER_UPDATE")
	T.eq(#G.History:GetActiveRun().members, 4, "中途加入成员补录")
	-- 重复队伍事件不重复记录。
	Fire("GROUP_ROSTER_UPDATE")
	T.eq(#G.History:GetActiveRun().members, 4, "按 key 去重")

	-- 只重载 History 文件模拟 /reload 后的局部内存丢失,角色存档保持。
	local beforeReload = G.History:GetActiveRun()
	Stubs.SetUnit("party3", nil)
	Load.addon("LycheeGroup_Group", "History.lua")
	G.History:Restore()
	local afterReload = G.History:GetActiveRun()
	T.eq(afterReload.id, beforeReload.id, "恢复复用同一个run身份")
	T.eq(afterReload.startedAt, beforeReload.startedAt, "恢复保留原开始时间")
	T.eq(#afterReload.members, 4, "重载后仍保留此前离队成员")
	T.eq(afterReload.members[4].name, "队友丙")
	G.History:Restore()
	T.eq(G.History:GetActiveRun().id, beforeReload.id, "重复恢复不生成新run")

	Fire("CHALLENGE_MODE_COMPLETED")
	T.eq(G.History:GetActiveRun(), nil, "完成后无进行中 run")
	T.eq(G.charDB.activeRun, nil, "完成后清理持久待定基线")
	T.eq(#G.charDB.runs, 1, "完成 run 写入历史")
	local run = G.History:GetHistory()[1]
	T.eq(run.completedAt >= run.startedAt, true)
	local memberA, memberSelf
	for _, m in ipairs(run.members) do
		if m.name == "队友甲" then memberA = m end
		if m.isSelf then memberSelf = m end
	end
	T.eq(memberA and memberA.specID, 66, "已有专精数据的成员记录专精")
	T.eq(memberSelf and memberSelf.specID, nil, "无专精数据的成员存 nil,不猜测")
	T.eq(#Stubs.FramesWithEvent("CHALLENGE_MODE_COMPLETED"), 0, "run 结束退订监听")
	T.eq(#Stubs.FramesWithEvent("GROUP_ROSTER_UPDATE"), 1, "run结束后可见页面仍持有队伍监听")
	S.challengeActive = false -- 地图信息仍可用,但挑战已经结束。
	G.History:Restore()
	Fire("CHALLENGE_MODE_COMPLETED")
	T.eq(#G.charDB.runs, 1, "完成后重开与重复完成不写入第二条run")
	S.challengeActive = nil

	-- 未完成即离开:丢弃,不写入。
	S.activeMap = 503
	Fire("CHALLENGE_MODE_START", 503)
	T.ok(G.History:GetActiveRun(), "第二个 run 开始")
	S.activeMap = nil
	Fire("GROUP_ROSTER_UPDATE")
	Fire("PLAYER_ENTERING_WORLD")
	T.eq(G.History:GetActiveRun(), nil, "离开秘境丢弃待定 run")
	T.eq(#G.charDB.runs, 1, "未完成 run 不写入历史")

	-- 活动中重登:Restore 恢复基线(party3 已离场)。
	S.activeMap = 502
	Stubs.SetUnit("party3", nil)
	G.History:Restore()
	local restored = G.History:GetActiveRun()
	T.ok(restored, "重登恢复进行中 run")
	T.eq(#restored.members, 3, "恢复时采集当前在场成员")
	S.activeMap = nil
	Fire("CHALLENGE_MODE_COMPLETED")
	T.eq(#G.charDB.runs, 2, "恢复后的完成同样写入")
	T.eq(G.charDB.activeRun, nil)

	-- 重置后的相同地图/层数是新run,不能沿用上一次基线。
	S.activeMap = 502
	Fire("CHALLENGE_MODE_START", 502)
	local resetID = G.History:GetActiveRun().id
	Fire("CHALLENGE_MODE_RESET", 502)
	T.eq(G.charDB.activeRun, nil, "RESET 清理未完成基线")
	Fire("CHALLENGE_MODE_START", 502)
	T.ok(G.History:GetActiveRun().id ~= resetID, "同地图重新开钥匙建立新run")
	S.activeMap = nil
	Fire("PLAYER_ENTERING_WORLD")
	S.activeMap, S.challengeActive = 504, false
	Fire("CHALLENGE_MODE_START", 504)
	T.eq(G.History:GetActiveRun(), nil, "非进行中挑战不采集无关场景")
	S.activeMap, S.challengeActive = nil, nil

	local history = G.History:GetHistory()
	T.eq(history[1].id ~= history[2].id, true, "run id 唯一")
	T.eq(history[1].completedAt >= history[2].completedAt, true, "完成时间倒序")

	Stubs.SetUnit("party1", nil)
	Stubs.SetUnit("party2", nil)
	Stubs.SetUnit("party3", nil)
	Stubs.SetTime(nil)
end

-- ---------------------------------------------------------------- 公开门面

do
	local completed=#G:GetHistory()
	S.activeMap=502
	A:SetSetting("history",false)
	A:SetSetting("history",true)
	T.ok(G:GetActiveRun(),"enabling history restores an ongoing native run through the loaded Group")
	A:SetSetting("history",false)
	T.eq(G:GetActiveRun(),nil,"disabling history discards the pending run immediately")
	T.eq(G.charDB.activeRun,nil,"disabling history also clears the saved pending baseline")
	T.eq(#Stubs.FramesWithEvent("CHALLENGE_MODE_COMPLETED"),0,"disabling history releases the run events")
	T.eq(#G:GetHistory(),completed,"changing history preferences never writes an unfinished run")
	S.activeMap=nil
	A:SetSetting("history",true)
end

do
	-- UI 平铺合同:GetActivities 目录与各所有者方法的委托。
	local raids = G:GetActivities("3")
	T.eq(#raids, 1, "团本目录含分类 3 活动")
	T.eq(raids[1].name, "黑翼之巢", "活动显示副本完整名称，不只显示难度")
	local mplus = G:GetActivities("seasonDungeon")
	T.eq(#mplus, 3, "赛季地图目录包含原生全部难度")
	T.eq(#G:GetActivities("nope"), 0, "未知分类返回空表")

	for _, name in ipairs({ "SetFilters", "GetResults", "GetResult", "GetApplications",
		"Apply", "Cancel", "AcceptInvite", "DeclineInvite", "GetListing", "Publish", "Update",
		"RemoveListing", "GetApplicants", "GetApplicant", "Invite", "Decline", "GetHistory",
		"GetActiveRun", "Subscribe" }) do
		T.eq(type(G[name]), "function", "门面方法 " .. name)
	end
	T.eq(type(G.Search), "table", "搜索服务保持表(门面无同名方法)")
	T.eq(type(G.Search.Search), "function", "搜索经服务调用")

	-- 门面委托链路:搜索 → 事件 → 结果。
	S.nativeSearchText="毒牙祭坛（史诗钥石）"
	local ok = G.Search:Search("3", nil)
	T.ok(ok)
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	T.ok(#G:GetResults() >= 1, "门面搜索→结果链路通")

	-- 流式更新:搜索会话建立后,引擎持续增删结果,按代次全量重读。
	S.results[14] = {
		searchResultID = 14, activityIDs = { 501 }, name = "新出现的队伍", comment = "",
		leaderName = "新团长-晨风号角", numMembers = 2, age = 5,
		requiredItemLevel = 0, autoAccept = false, isDelisted = false,
	}
	S.resultIDs[#S.resultIDs + 1] = 14
	Fire("LFG_LIST_UPDATE_SEARCH_RESULTS")
	S.now=S.now+.2
	G.Game.frame:GetScript("OnUpdate")()
	T.eq(G.Results:GetCount(), 4, "流式更新提交新增结果")
	T.ok(G.Results:GetResult(14) ~= nil, "新队伍可见")
end

-- ---------------------------------------------------------------- 可用性刷新

do
	-- 同次会话的视图共享目录请求，读目录与处理可用性事件都不重复请求。
	T.eq(S.availabilityRequests, 1, "all views share one activity request per session")
	T.eq(#G:GetActivities("3"), 1, "缓存命中不重复请求")
	T.eq(S.availabilityRequests, 1, "缓存命中不再请求")

	-- 可用性事件清缓存，后续读取按最新原生数据重建目录。
	ACTIVITY[105] = { orderIndex=20, fullName = "旧团本（普通）", shortName = "普通", categoryID = 3, isCurrentRaidActivity = false, maxNumPlayers = 30 }
	Fire("LFG_LIST_AVAILABILITY_UPDATE")
	T.eq(#G:GetActivities("3"), 2, "刷新后目录重建")
	T.eq(G:GetActivities("3")[1].id, 501, "当前团本排在较小 ID 的旧团本之前")
	T.eq(G:GetActivities("3")[2].name, "旧团本（普通）")
	T.eq(S.availabilityRequests, 1, "可用性事件重建不产生请求循环")
	ACTIVITY[105] = nil
	Fire("LFG_LIST_AVAILABILITY_UPDATE")
end

-- ---------------------------------------------------------------- 浏览与后台业务生命周期

do
	local ok = G:Apply(11, { tank = true })
	T.ok(ok, "关闭前存在真实活动申请")
	local app = G:GetApplication(11)
	T.eq(app.name, "黑翼速通", "申请独立保存必要队伍摘要")
	local secondView = {}
	G:Attach(secondView, "search")
	G:Detach(searchView)
	T.ok(G:GetResultCount() > 0, "另一个浏览消费者仍在时保留完整结果")
	G:Detach(secondView)
	local requested=S.availabilityRequests
	local cached=G.Catalog:GetActivities("3")
	T.eq(Stubs.FireEvent("LFG_LIST_AVAILABILITY_UPDATE"),1,"native activity changes remain observed while the window is closed")
	T.ok(G.Catalog:GetActivities("3")~=cached,"a hidden native update invalidates the existing catalog")
	T.eq(#Stubs.FramesWithEvent("GROUP_ROSTER_UPDATE"),0,"无页面且无进行中run时释放队伍监听")
	T.eq(G:GetResultCount(), 0, "最后一个浏览消费者离开后释放全部搜索结果")
	T.eq(G.Search:GetState(), "idle", "关闭结束搜索会话")
	T.eq(G:GetApplication(11), app, "清搜索结果不取消或复制申请")
	T.eq(app.comment, nil, "申请不保留整条搜索说明")
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_UPDATE_SEARCH_RESULTS"), 0, "隐藏后停止搜索流式监听")
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_SEARCH_RESULT_UPDATED"), 1, "隐藏后只为活动申请保留单条结果监听")
	local reads = S.resultReads
	T.eq(Stubs.FireEvent("LFG_LIST_UPDATE_SEARCH_RESULTS"), 0, "原生更新不再触达搜索处理器")
	G:OnEvent("LFG_LIST_UPDATE_SEARCH_RESULTS")
	T.eq(S.resultReads, reads, "直接迟到事件也不读取隐藏结果")
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_APPLICATION_STATUS_UPDATED"), 1, "活动申请仍由最小业务入口推进")
	Fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 11, "invited", "applied", "黑翼速通")
	T.eq(G:GetApplication(11).status, "invited", "隐藏后继续收到邀请")
	T.ok(G:AcceptInvite(11), "独立申请不依赖结果仓库即可接受邀请")
	Fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 11, "inviteaccepted", "invited", "黑翼速通")
	T.eq(G:GetApplication(11), nil, "隐藏时终态申请释放摘要")
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_SEARCH_RESULT_UPDATED"), 0, "最后一条活动申请结束后释放单条结果监听")
	S.applications = {}

	-- 本窗口关闭后在原生界面重新发布,最小入口仍能接管申请者。
	S.activeEntry = { activityIDs = { 501 }, name = "原生新队伍" }
	Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE", true)
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_APPLICANT_UPDATED"), 1, "原生招募唤醒申请者业务")
	S.activeEntry = nil
	Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE", false)
	T.eq(#Stubs.FramesWithEvent("LFG_LIST_APPLICANT_UPDATED"), 0, "原生招募结束后重新退订")
	T.eq(G.Applicants:GetCount(), 0)

	G:Attach(searchView, "search")
	T.eq(S.availabilityRequests,requested,"reopening uses the native activity cache without another global refresh request")
	T.ok(G.Search:Search("3"), "重开可发起下一轮真实搜索")
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	T.ok(G:GetResultCount() > 0, "重新建立事件和完整结果")
	G:Detach(searchView)
	T.eq(G:GetResultCount(), 0)
end

-- Current-group display reads the full roster without recording or inspecting it.
Stubs.SetUnit("party1",{name="当前治疗",realm="晨风号角",class="PRIEST",role="HEALER",leader=true})
local roster=G:GetRoster()
T.eq(#roster,2)
T.eq(roster[2].nameKey,"当前治疗-晨风号角")
T.eq(roster[2].assignedRole,"HEALER")
T.eq(roster[2].isLeader,true)
Stubs.SetUnit("party1",nil)
do
 -- Native raid aliases still identify the local player; inspect data is not self data.
 local player={name="本人",realm="晨风号角",class="PALADIN",classID=2,guid="P-0",role="NONE",subgroup=5}
 local selected,reads,inspectReads=1,0,{}
 local getSpec,getInfo,getInspect=C_SpecializationInfo.GetSpecialization,C_SpecializationInfo.GetSpecializationInfo,C_SpecializationInfo.GetInspectSpecialization
 local groupCount,averageLevel=GetNumGroupMembers,GetAverageItemLevel
 Stubs.SetUnit("player",player);Stubs.SetUnit("raid2",player)
 Stubs.SetUnit("raid1",{name="未检视队友",realm="晨风号角",class="PRIEST",classID=5,guid="P-1"})
 GetNumGroupMembers=function() return 2 end
 GetAverageItemLevel=function() return 250,248 end
 C_SpecializationInfo.GetSpecialization=function() reads=reads+1;return selected end
 C_SpecializationInfo.GetSpecializationInfo=function(index)
  if index==1 then return 65,"神圣",nil,135920,"HEALER" end
  if index==2 then return 66,"防护",nil,236264,"TANK" end
 end
 C_SpecializationInfo.GetInspectSpecialization=function(unit) inspectReads[#inspectReads+1]=unit;return 0 end
 local view={};G:Attach(view,"create")
 local members=G:GetRoster()
 T.eq(#members,2);T.eq(members[2].unit,"raid2")
 T.eq(members[2].specID,65,"the player raid alias uses the actual selected player specialization")
 T.eq(members[2].assignedRole,"HEALER","an unassigned player uses the current specialization role")
 T.eq(members[2].subgroup,5,"roster subgroup comes from the native raid slot, not the member index")
 T.eq(members[2].itemLevel,248,"the player raid alias also uses equipped player item level")
 T.eq(members[1].specID,nil,"another member without inspect data remains unknown")
 T.same(inspectReads,{"raid1"},"the local raid alias never goes through inspect")
 T.eq(G:GetRoster(),members);T.eq(reads,1,"unchanged roster reuses its specialization snapshot")
 local refreshed
 local unsubscribe=G:Subscribe(function(kind) if kind=="roster" then refreshed=G:GetRoster() end end)
 selected=2;Fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
 T.eq(refreshed and refreshed[2].specID,66,"the native active-player specialization event refreshes visible roster consumers")
 T.eq(refreshed[2].assignedRole,"TANK","an unassigned role follows specialization changes")
 T.eq(refreshed[1].specID,nil,"self specialization never fills another member's missing data")
 selected=1;player.role="DAMAGER";Fire("PLAYER_SPECIALIZATION_CHANGED","player")
 T.eq(refreshed[2].specID,65,"the unit specialization event also refreshes the raid-alias player")
 T.eq(refreshed[2].assignedRole,"DAMAGER","an explicitly assigned role remains authoritative")
 T.eq(#Stubs.FramesWithEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED"),1)
 unsubscribe();G:Detach(view)
 T.eq(#Stubs.FramesWithEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED"),0,"self specialization tracking stops when the create view leaves")
 C_SpecializationInfo.GetSpecialization,C_SpecializationInfo.GetSpecializationInfo,C_SpecializationInfo.GetInspectSpecialization=getSpec,getInfo,getInspect
 GetNumGroupMembers,GetAverageItemLevel=groupCount,averageLevel
 Stubs.SetUnit("raid1",nil);Stubs.SetUnit("raid2",nil)
 Stubs.SetUnit("player",{name="本人",realm="晨风号角",class="WARRIOR",classID=1,guid="P-0"})
 G:InvalidateRoster()
end

-- A fresh teammate has no inspect cache: prefer LibSpecialization, then inspect.
do
 local view={}
 local function sync(spec,name) for _,callback in pairs(specCallbacks) do callback(spec,"HEALER","MELEE",name,"unused talents") end end
 local function advance(seconds) S.now=S.now+seconds;Stubs.AdvanceClock(seconds) end
 Stubs.SetUnit("party1",{name="同步队友",realm="晨风号角",class="PALADIN",classID=2,guid="LIB-1"})
 Stubs.SetUnit("party2",{name="检视队友",realm="晨风号角",class="PALADIN",classID=2,guid="NATIVE-2"})
 Stubs.SetInspectSpec("party1",0);Stubs.SetInspectSpec("party2",0)
 local start=#Stubs.InspectRequests()
 G:Attach(view,"create")
 G:GetRoster()
 sync(65,"同步队友")
 local members=G:GetRoster()
 T.eq(members[2].specID,65,"LibSpecialization fills a teammate with no native inspect cache")
 advance(1)
 T.eq(#Stubs.InspectRequests(),start+1,"only the teammate missing library data receives an inspect request")
 T.eq(Stubs.InspectRequests()[start+1],"party2")
 Stubs.SetInspectSpec("party2",66);Fire("INSPECT_READY","NATIVE-2")
 members=G:GetRoster()
 T.eq(members[3].specID,66,"matching INSPECT_READY fills the missing specialization")
 Stubs.SetInspectSpec("party1",70);G:InvalidateRoster()
 T.eq(G:GetRoster()[2].specID,65,"library data has priority over native inspect data")
 sync(70,"同步队友")
 T.eq(G:GetRoster()[2].specID,70,"a library specialization event refreshes existing rows")
 sync(257,"不在队里的名字")
 T.eq(#G:GetRoster(),3,"messages from outside the current roster are ignored")
 Stubs.SetInspectSpec("party2",0)
 Fire("PLAYER_SPECIALIZATION_CHANGED","party2")
 T.eq(G:GetRoster()[3].specID,nil,"a specialization change invalidates the old native value")
 advance(2)
 T.eq(#Stubs.InspectRequests(),start+2,"the changed teammate is queried once")
 local pending,rosterUpdates=G.Roster.pending,0
 local unsubscribe=G:Subscribe(function(kind) if kind=="roster" then rosterUpdates=rosterUpdates+1;G:GetRoster() end end)
 Fire("INSPECT_READY","OLD-GUID")
 T.eq(rosterUpdates,0,"an unrelated inspect response does not notify or rebuild the current roster")
 T.eq(G.Roster.pending,pending,"an unrelated response does not release the current inspect request")
 T.eq(G:GetRoster()[3].specID,nil,"an unrelated inspect response cannot complete this teammate")
 Fire("INSPECT_READY","LIB-1")
 T.eq(rosterUpdates,1,"a current teammate inspected by another consumer still updates the roster")
 T.eq(G.Roster.pending,pending,"another teammate's response keeps the current request intact")
 Stubs.SetUnit("party2",nil);Fire("INSPECT_READY","NATIVE-2")
 T.eq(G.Roster.pending,nil,"the owned response still releases its request after the member has left")
 T.eq(#G:GetRoster(),2)
 unsubscribe()
 G:Detach(view)
 local afterClose=#Stubs.InspectRequests()
 advance(10)
 T.eq(#Stubs.InspectRequests(),afterClose,"closing the view cancels pending inspect work")
 T.eq(#Stubs.FramesWithEvent("INSPECT_READY"),0)
 Stubs.SetUnit("party1",nil);Stubs.SetUnit("party2",nil)
 G:InvalidateRoster()
end

-- A raid's same-frame library messages publish one fresh, complete roster.
do
 local view={}
 local groupCount,ratingSummary=GetNumGroupMembers,C_PlayerInfo.GetPlayerMythicPlusRatingSummary
 local reads,updates=0,0
 GetNumGroupMembers=function() return 40 end
 C_PlayerInfo.GetPlayerMythicPlusRatingSummary=function() reads=reads+1;return {currentSeasonScore=3000} end
 Stubs.SetUnit("raid1",{name="本人",realm="晨风号角",class="WARRIOR",guid="P-0"})
 for i=2,40 do Stubs.SetUnit("raid"..i,{name="广播队友"..i,realm="晨风号角",class="PALADIN",guid="BURST-"..i}) end
 G:Attach(view,"create");G:GetRoster();reads=0
 local unsubscribe=G:Subscribe(function(kind) if kind=="roster" then updates=updates+1;G:GetRoster() end end)
 local function sync(index,spec) for _,callback in pairs(specCallbacks) do callback(spec,"HEALER","MELEE","广播队友"..index) end end
 for i=2,40 do sync(i,65) end
 T.eq(G.Roster:GetCachedSpec("BURST-40"),65,"library GUID data is immediately available to non-visual consumers")
 T.eq(updates,0);T.eq(reads,0,"a burst does not rebuild the roster for each message")
 Stubs.AdvanceClock(0)
 T.eq(updates,1);T.eq(reads,40,"39 messages share one complete forty-member refresh")
 T.eq(G:GetRoster()[40].specID,65)
 sync(40,70)
 T.eq(G:GetRoster()[40].specID,70,"an explicit read sees new data before the queued notification")
 local afterRead=reads;Stubs.AdvanceClock(0)
 T.eq(reads,afterRead,"publishing an already-read snapshot does not rebuild it again")
 sync(40,66);local afterUpdate=updates
 G:Detach(view)
 T.eq(G.Roster.refreshTimer,nil,"leaving the create view cancels the queued broadcast refresh")
 Stubs.AdvanceClock(0);T.eq(updates,afterUpdate,"a cancelled refresh cannot notify the hidden view")
 T.eq(G.Roster:GetCachedSpec("BURST-40"),66,"closing preserves the latest teammate specialization")
 unsubscribe()
 for i=1,40 do Stubs.SetUnit("raid"..i,nil) end
 GetNumGroupMembers,C_PlayerInfo.GetPlayerMythicPlusRatingSummary=groupCount,ratingSummary
 G:InvalidateRoster()
end

-- Visiting many rows retains a small detail cache while preserving every result.
S.results={};S.resultIDs={}
for id=101,165 do S.results[id]={activityIDs={502},name="Group "..id,numMembers=1};S.resultIDs[#S.resultIDs+1]=id end
G.Results:BeginSearch(900);G.Results:CommitResults(900)
S.players[165]={{name="Cached-Away",classFilename="PRIEST",className="牧师",assignedRole="HEALER",specName="神圣",isLeader=true}}
S.counts[165]={TANK=0,HEALER=1,DAMAGER=0};S.encounters[165]={"Boss A"}
S.results[165].activityIDs={501};G.Results:OnResultUpdated(165)
for id=101,165 do G:GetResultDetails(id) end
T.eq(G:GetResultCount(),65)
T.eq(G:GetResult(101).details,nil,"old member snapshots leave the cache without dropping groups")
T.ok(G:GetResult(165).details,"recently displayed detail remains reusable")
local recentlyRead=G:GetResultDetails(102)
G:GetResultDetails(101)
T.eq(G:GetResult(102).details,recentlyRead,"a clean detail cache hit refreshes its LRU position")
T.eq(G:GetResult(103).details,nil,"the least recently read snapshot is evicted instead of the recent cache hit")
do
 G.Results:OnResultUpdated(165)
 local native=S.counts[165]
 native.classesByRole={HEALER={PRIEST=1}};native.NOROLE=0
 local weak=setmetatable({native},{__mode="v"})
 local reads=S.memberCountReads
 local counts=G.Results:GetMemberCounts(G:GetResult(165))
 T.same(counts,{TANK=0,HEALER=1,DAMAGER=0},"role views retain only their three consumed counts")
 T.eq(G.Results:GetMemberCounts(G:GetResult(165)),counts)
 T.eq(S.memberCountReads,reads+1,"the reduced role snapshot still reuses its first native read")
 T.eq(native.classesByRole.HEALER.PRIEST,1,"normalization leaves the native response untouched")
 S.counts[165]=nil;native=nil;collectgarbage("collect")
 T.eq(weak[1],nil,"the original native table and its nested class statistics can be collected")
 S.counts[165]={TANK=0,HEALER=1,DAMAGER=0}
end
do
	local details=G:GetResultDetails(165);local counts=G:GetResult(165).memberCounts;local reads=S.playerReads
	local infoReads=S.resultReads
	G.Results:CommitResults(900)
	T.eq(S.resultReads,infoReads,"bulk notifications in the same frame reuse normalized records")
	T.eq(G:GetResultDetails(165),details,"an unchanged bulk snapshot retains member and encounter details")
	T.eq(G:GetResult(165).memberCounts,counts);T.eq(S.playerReads,reads,"bulk refresh does not reread unchanged cached members")
	local resultEvents=notifications.result or 0;local resultsEvents=notifications.results or 0
	S.players[165][1].specName="戒律";S.encounters[165]={"Boss A","Boss B"}
	G.Results:OnResultUpdated(165)
	local changed=G:GetResultDetails(165)
	T.eq(changed,details,"specific updates refill the cached detail container")
	T.eq(changed.members[1].specName,"戒律","a specific update refreshes members even when their count is unchanged")
	T.eq(#changed.encounters,2,"a specific update refreshes native encounter progress")
	T.eq(notifications.result,resultEvents+1);T.eq(notifications.results or 0,resultsEvents,"one result update publishes only one refresh notification")
	S.results[164].numMembers=2;S.now=S.now+.02;G.Results:CommitResults(900)
	T.eq(G:GetResult(164).detailsDirty,true,"bulk membership changes mark the existing detail container for refill")
	T.eq(G:GetResultDetails(165),changed,"other results retain their cached details")
	G:GetResultDetails(103)
	T.eq(G:GetResult(104).details,nil,"the same sixty-four-entry LRU survives bulk refreshes")
	local retained=0;for id=101,165 do if G:GetResult(id).details then retained=retained+1 end end
	T.ok(retained<=64,"preserving snapshots never increases the detail cache bound")
	T.eq(G:GetResultCount(),65,"cache reuse preserves the complete native result set")
end
G.Results:BeginSearch(901)
do
 S.results[165].name="Before burst";S.resultIDs={165}
 G.Results:CommitResults(901)
 local before=S.resultReads
 for i=1,8 do S.results[165].name="Latest "..i;G:OnEvent("LFG_LIST_SEARCH_RESULT_UPDATED",165);G.Results:QueueUpdate() end
 T.eq(S.resultReads,before,"native event bursts queue work without repeated info allocations")
 local flush=G.Game.frame:GetScript("OnUpdate");T.ok(flush)
 S.now=S.now+.2;flush()
 T.eq(S.resultReads,before+1,"bulk and per-result notifications share one final native read")
 T.eq(G:GetResult(165).name,"Latest 8","the merged update reads the final native metadata")
 T.eq(G.Game.frame:GetScript("OnUpdate"),nil,"the event frame has no idle refresh callback")
 G.Results:QueueUpdate(165);G.Results:BeginSearch(902)
 T.eq(G.Game.frame:GetScript("OnUpdate"),nil,"a new search or browse close cancels queued result work")
 T.eq(G.Results.updatePending,nil)
end
do
 -- Completion consumes only already queued changes; later updates stay live.
 local savedResults,savedIDs=S.results,S.resultIDs
 local view={};G:Attach(view,"search");G.Search:EndBrowse()
 local function Player(spec)
  return {name="Boundary-Away",classFilename="PRIEST",className="牧师",assignedRole="HEALER",specName=spec,isLeader=true}
 end
 S.results={};S.resultIDs={93001,93002,93003}
 for _,id in ipairs(S.resultIDs) do
  S.results[id]={activityIDs={501},name="Before "..id,leaderName="Boundary-Away",numMembers=1}
  S.players[id]={Player("神圣")}
 end
 S.encounters[93001]={"Boss A"}
 T.ok(G.Search:Search("seasonRaid",501))
 G:OnEvent("LFG_LIST_UPDATE_SEARCH_RESULTS");G.Game.frame:GetScript("OnUpdate")()
 local details=G:GetResultDetails(93001)
 S.now=S.now+.02;S.players[93001]={Player("戒律")};S.encounters[93001]={"Boss A","Boss B"}
 G:OnEvent("LFG_LIST_UPDATE_SEARCH_RESULTS");G:OnEvent("LFG_LIST_SEARCH_RESULT_UPDATED",93001)
 local nativeList=C_LFGList.GetFilteredSearchResults;local lists=0
 C_LFGList.GetFilteredSearchResults=function() lists=lists+1;return nativeList() end
 local reads=S.resultReads
 Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
 T.eq(S.resultReads,reads+3,"completion reads the full native result set once")
 T.eq(G:GetResultDetails(93001),details)
 T.eq(details.members[1].specName,"戒律","completion preserves a queued same-count member invalidation")
 T.eq(#details.encounters,2,"completion preserves queued raid progress invalidation")
 T.eq(G.Results.updatePending,nil,"completion consumes its preexisting update queue")
 T.eq(G.Game.frame:GetScript("OnUpdate"),nil,"completion leaves no duplicate deferred full read")
 Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
 T.eq(S.resultReads,reads+3,"a duplicate completion event does not reread a finished search")
 T.eq(lists,1,"queued bulk and completion share one native ID array")

 S.results[93001].name="After completion";G:OnEvent("LFG_LIST_SEARCH_RESULT_UPDATED",93001)
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(S.resultReads,reads+4,"a genuine later update in the same frame still reads native data")
 T.eq(G:GetResult(93001).name,"After completion")

 local nativeInfo=C_LFGList.GetSearchResultInfo;local reentered=false
 C_LFGList.GetSearchResultInfo=function(id)
  local info=nativeInfo(id)
  if id==93003 and not reentered then
   reentered=true;S.results[93001].name="During commit";S.players[93001]={Player("暗影")};S.encounters[93001]={"Boss C"}
   G:OnEvent("LFG_LIST_SEARCH_RESULT_UPDATED",93001);G:OnEvent("LFG_LIST_UPDATE_SEARCH_RESULTS")
  end
  return info
 end
 S.now=S.now+.02;G:OnEvent("LFG_LIST_SEARCH_RESULT_UPDATED",93002);reads=S.resultReads
 G.Results:CommitResults(G.Results.gen)
 C_LFGList.GetSearchResultInfo=nativeInfo
 T.eq(S.resultReads,reads+3);T.ok(G.Results.updatePending,"events arriving during a commit remain queued")
 S.now=S.now+.2
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(S.resultReads,reads+6,"a reentrant bulk still refreshes every result")
 T.eq(G:GetResult(93001).name,"During commit")
 T.eq(G:GetResultDetails(93001).members[1].specName,"暗影")
 T.eq(G:GetResultDetails(93001).encounters[1],"Boss C")
 T.eq(G.Results.updatePending,nil)

 local changed=false;local unsubscribe=G:Subscribe(function(kind)
  if kind=="results" and not changed then changed=true;S.results[93002].name="During notification";G.Results:QueueUpdate(93002) end
 end)
 S.now=S.now+.02;G.Results:CommitResults(G.Results.gen);unsubscribe();reads=S.resultReads
 T.ok(G.Results.updatePending,"a subscriber's new result event is not consumed by the completed commit")
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(S.resultReads,reads+1);T.eq(G:GetResult(93002).name,"During notification")

 local closed=false
 C_LFGList.GetSearchResultInfo=function(id)
  local info=nativeInfo(id)
  if id==93002 and not closed then closed=true;G.Search:EndBrowse() end
  return info
 end
 S.now=S.now+.02;G.Results:QueueUpdate(93001);G.Results:CommitResults(G.Results.gen)
 C_LFGList.GetSearchResultInfo=nativeInfo
 T.eq(G:GetResultCount(),0,"closing during a native read prevents stale results from repopulating the cleared generation")
 T.eq(G.Results.updatePending,nil);T.eq(G.Game.frame:GetScript("OnUpdate"),nil)
 S.resultIDs={93003};T.ok(G.Search:Search("seasonRaid",501))
 local initialUpdate=false
 C_LFGList.GetSearchResultInfo=function(id)
  local info=nativeInfo(id);local snapshot={};for key,value in pairs(info) do snapshot[key]=value end
  if not initialUpdate then
   initialUpdate=true;S.results[id].name="During first read";G:OnEvent("LFG_LIST_SEARCH_RESULT_UPDATED",id)
  end
  return snapshot
 end
 Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");C_LFGList.GetSearchResultInfo=nativeInfo
 T.eq(G:GetResultCount(),1);T.eq(G:GetResult(93001),nil,"the next generation contains only its own native IDs")
 T.ok(G.Results.updatePending,"an update during a new result's first read survives before that record is installed")
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(G:GetResult(93003).name,"During first read","first-read updates are not hidden by the same-frame sample time")
 C_LFGList.GetFilteredSearchResults=nativeList
 G:Detach(view)
 for id=93001,93003 do S.players[id],S.encounters[id]=nil,nil end
 S.results,S.resultIDs=savedResults,savedIDs
end
S.now=100
do
 -- Bulk notifications share a fixed 200ms window; new events do not move its
 -- deadline, while individual changes stay prompt inside the window.
 local savedResults,savedIDs=S.results,S.resultIDs
 S.resultIDs={93901,93902}
 S.results={
  [93901]={activityIDs={502},name="Before A",numMembers=1},
  [93902]={activityIDs={502},name="Before B",numMembers=2},
 }
 G.Results:BeginSearch(939);G.Results:CommitResults(939)
 local reads=S.resultReads
 for step=1,9 do
  S.now=100+step*.02
  S.results[93902].name="Latest bulk "..step;G.Results:QueueUpdate()
  if step==3 then
   S.results[93901].name="Urgent single"
   for _=1,8 do G.Results:QueueUpdate(93901) end
  end
  G.Game.frame:GetScript("OnUpdate")()
  T.eq(S.resultReads-reads,step>=3 and 1 or 0,"waiting bulk events never reread the whole list")
  T.eq(G:GetResult(93902).name,"Before B","bulk-only metadata waits for the fixed window")
  T.ok(G.Results.updatePending,"processing single IDs preserves the pending bulk snapshot")
 end
 T.eq(G:GetResult(93901).name,"Urgent single","single-ID events do not wait for the bulk window")
 S.now=100.2;G.Game.frame:GetScript("OnUpdate")()
 T.eq(S.resultReads-reads,3,"the deadline performs exactly one complete two-record read")
 T.eq(G:GetResult(93902).name,"Latest bulk 9","the deadline includes the latest event without postponing")
 T.eq(G.Results.updatePending,nil);T.eq(G.Game.frame:GetScript("OnUpdate"),nil)
 G.Results:QueueUpdate();G.Results:BeginSearch(9391)
 reads=S.resultReads;G.Results:QueueUpdate();G.Game.frame:GetScript("OnUpdate")()
 T.eq(S.resultReads-reads,2,"a new search starts immediately without the old throttle deadline")
 T.eq(G.Results.updatePending,nil)
 S.results,S.resultIDs=savedResults,savedIDs;S.now=100
end
do
 -- Dirty events are merged into one complete refresh, never a partially
 -- visible scan. Once the throttle opens, subscribers see the whole batch.
 local savedResults,savedIDs=S.results,S.resultIDs
 S.results={};S.resultIDs={}
 for id=94001,94100 do
  S.resultIDs[#S.resultIDs+1]=id
  S.results[id]={activityIDs={502},name="Before "..id,numMembers=1,age=id-94000}
 end
 G.Results:BeginSearch(940);G.Results:CommitResults(940)
 for _,id in ipairs(S.resultIDs) do S.results[id].name="After "..id end
 S.results[94001].age=900
 S.results[94099].name="Urgent";S.results[94099].numMembers=4
 table.remove(S.resultIDs,50)
 S.resultIDs[#S.resultIDs+1]=94101
 S.results[94101]={activityIDs={502},name="Added",numMembers=2,age=1}
 local publications,partial=0,false
 local unsubscribe=G:Subscribe(function(kind)
  if kind~="results" and kind~="result" then return end
  publications=publications+1
  if G:GetResultCount()~=#S.resultIDs or G:GetResult(94050) then partial=true end
  for _,id in ipairs(S.resultIDs) do
   local record=G:GetResult(id)
   if not record or record.name~=S.results[id].name then partial=true end
  end
 end)
 local reads=S.resultReads
 for _=1,8 do G.Results:QueueUpdate();G.Results:QueueUpdate(94099) end
 T.eq(S.resultReads,reads,"dirty marking alone does not read native records")
 S.now=S.now+.2;G.Game.frame:GetScript("OnUpdate")()
 T.eq(S.resultReads-reads,100,"one flush reads each native ID once, including specifically dirty IDs")
 T.eq(G.Results.updatePending,nil,"one complete flush consumes the batch without a delayed continuation")
 T.eq(publications,1,"bulk and single-ID events publish one completed view update")
 T.eq(partial,false,"subscribers cannot observe a half-refreshed batch")
 T.eq(G:GetResultCount(),#S.resultIDs)
 T.eq(G:GetResult(94050),nil,"the final native snapshot removes missing IDs")
 for _,id in ipairs(S.resultIDs) do
  local result,native=G:GetResult(id),S.results[id]
  T.ok(result,"all native results remain available")
  T.eq(result.name,native.name);T.eq(result.age,native.age);T.eq(result.numMembers,native.numMembers)
 end
 -- An explicit full commit still consumes later bulk-only metadata changes,
 -- even if the clock reports the same rendered frame.
 S.results[94001].name="Later bulk metadata";reads=S.resultReads
 G.Results:QueueUpdate();G.Results:CommitResults(G.Results.gen)
 T.eq(S.resultReads-reads,100,"a new bulk event invalidates same-frame metadata")
 T.eq(G:GetResult(94001).name,"Later bulk metadata")
 T.eq(G.Results.updatePending,nil,"an explicit complete commit consumes the pending window immediately")

 S.results[94001].name="Single A";S.results[94099].name="Single B"
 publications,partial,reads=0,false,S.resultReads
 for _=1,8 do G.Results:QueueUpdate(94001);G.Results:QueueUpdate(94099) end
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(S.resultReads-reads,2,"a specific dirty batch reads only its two distinct IDs")
 T.eq(publications,1,"specific dirty IDs also publish only after the complete batch")
 T.eq(partial,false,"every subscriber sees both updated records together")
 unsubscribe()

 reads=S.resultReads
 G.Search:SetFilters({maxMembers=3,sort="newest"})
 local expected={}
 for _,id in ipairs(S.resultIDs) do if S.results[id].numMembers<=3 then expected[#expected+1]=id end end
 table.sort(expected,function(a,b) if S.results[a].age~=S.results[b].age then return S.results[a].age<S.results[b].age end;return a<b end)
 T.same(G:GetResults(),expected,"dirty refresh preserves the independently computed filtered order")
 T.eq(S.resultReads,reads,"local filtering and sorting do not reread native base metadata")
 G.Results:QueueUpdate();G.Results:QueueUpdate(94001)
 G.Results:BeginSearch(941)
 T.eq(G:GetResultCount(),0);T.eq(G.Game.frame:GetScript("OnUpdate"),nil,"a new search cancels the complete pending dirty batch")
 S.results,S.resultIDs=savedResults,savedIDs
 S.now=100
end
unsubscribe()
T.eq(Stubs.PendingTimers(), 0, "Group 包不产生任何常驻计时器")

-- The global five-application limit counts all categories and native deadlines.
S.applications={11,12,13,14,15};S.appStatus={}
for _,id in ipairs(S.applications) do S.appStatus[id]="applied" end
G.Applications:Restore()
T.eq(G.Applications:GetActiveCount(),5)
T.eq(G:Apply(16,{damage=true}),false,"a sixth application cannot be submitted")
T.eq(G:GetApplication(11).expiresAt,220,"deadline uses native remaining seconds")
S.appStatus[11]="cancelled";G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",11,"cancelled")
T.eq(G.Applications:GetActiveCount(),4,"native cancellation frees a global slot")
T.ok(G:Apply(16,{damage=true}));T.eq(G.Applications:GetActiveCount(),5)
A.db.autoJoin=false
S.appStatus[12]="invited";S.appStatus[13]="invited";G.Applications:SyncAll()
local accepts=0;C_LFGList.AcceptInvite=function() accepts=accepts+1 end
A:SetSetting("autoJoin",true);T.eq(accepts,1,"enable accepts only one pending invitation")
G.Applications:TryAutoJoin();G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",12,"invited")
T.eq(accepts,1,"duplicate events cannot accept another invitation while one is inflight")
S.appStatus[15]="none";S.appPending[15]="applied";G.Applications:SyncAll()
S.appStatus[12]="inviteaccepted";G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",12,"inviteaccepted")
T.eq(accepts,1,"successful acceptance stops automatic acceptance of other groups")
G.Applications:SyncAll();G.Applications:TryAutoJoin()
T.eq(accepts,1,"passive refreshes of old applied and pending-applied entries preserve the completed-round lock")
G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",14,"applied","applied")
G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",15,"none","none")
T.eq(accepts,1,"duplicate application events do not accept a second old invitation after joining")
S.applications={};S.appStatus={};S.appPending={};G.Applications:SyncAll();G.Applications:ReleaseFinished()
C_LFGList.ApplyToGroup(18,false,true,false)
G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",18,"applied","none")
S.appStatus[18]="invited";G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",18,"invited","applied")
T.eq(accepts,2,"an application submitted through the native entry starts a new auto-join round")
S.appStatus[18]="inviteaccepted";G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",18,"inviteaccepted","invited")
S.applications={};S.appStatus={};G.Applications:SyncAll();G.Applications:ReleaseFinished()
C_LFGList.ApplyToGroup(19,false,false,true)
S.appStatus[19]="none";S.appPending[19]="applied"
G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",19,"none","none")
S.appStatus[19]="invited";S.appPending[19]=nil;G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",19,"invited","none")
T.eq(accepts,3,"a new pending-applied event also starts a native application round")
S.appStatus[19]="inviteaccepted";G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",19,"inviteaccepted","invited")
S.applications={};S.appStatus={};G.Applications:SyncAll();G.Applications:ReleaseFinished()
T.ok(G:Apply(17,{healer=true}),"a later application round uses the same business entry")
S.appStatus[17]="invited";G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",17,"invited","applied")
T.eq(accepts,4,"the new application round can auto-accept after the previous round joined")
S.appStatus[17]="inviteaccepted";G:OnEvent("LFG_LIST_APPLICATION_STATUS_UPDATED",17,"inviteaccepted","invited")
A.db.autoJoin=false
-- New applicant audio coalesces a batch and finishes without a ticker.
S.activeEntry={activityIDs={501},name="Sound test"};G.Listing:OnEntryUpdate()
G.Applicants:Clear();S.applicants={[801]={applicationStatus="applied",numMembers=1,displayOrderID=1}}
S.applicantMembers={[801]={{name="Sound-Away",class="MAGE",itemLevel=250,dungeonScore=2400}}}
local sounds=S.soundCalls or 0
G.Applicants:RefreshList();G.Applicants:RefreshList();Stubs.AdvanceClock(.13)
T.eq(S.soundCalls,sounds+1,"one sound for a new applicant batch")
G.Applicants:OnApplicantUpdated(801);Stubs.AdvanceClock(.13)
T.eq(S.soundCalls,sounds+1,"sorting and duplicate member updates stay silent")
T.eq(S.soundKit,47615);T.eq(S.soundChannel,"Master");T.eq(S.soundFinish,true)
Stubs.FireEvent("SOUNDKIT_FINISHED",7);T.eq(G.Alerts.handle,nil);T.eq(#Stubs.FramesWithEvent("SOUNDKIT_FINISHED"),0);T.eq(Stubs.PendingTimers(),0,"native audio completion has no idle timer")
G.Applicants:Clear();S.activeEntry=nil

-- Lightweight specialization resolution stays within the member's native class.
do
 local shared,getClass=A.Specializations,GetClassInfo
 local reads,ready=0,false
 GetClassInfo=function(index)
  reads=reads+1
  if index==2 and not ready then return end
  return getClass(index)
 end
 Load.addon("LycheeGroup", "Specializations.lua")
 local metadata=A.Specializations
 T.eq(reads,0,"defining shared specialization queries does not read the class directory")
 T.eq(metadata:Class("UNKNOWN"),nil);T.eq(reads,2)
 ready=true
 T.eq(metadata:Class("PALADIN"),2,"a previously incomplete class directory is retried and recovers")
 T.eq(reads,4)
 for _=1,30 do metadata:Class("UNKNOWN");metadata:Class("WARRIOR");metadata:Class("PALADIN") end
 T.eq(reads,4,"known and unknown tokens reuse a complete class directory without rescanning")
 A.Specializations,GetClassInfo=shared,getClass
end
local resolvedID,resolvedName=G:ResolveMemberSpec({class="WARRIOR",specName="武器"})
T.eq(resolvedID,71);T.eq(resolvedName,"武器")
T.eq(G:ResolveMemberSpec({class="PALADIN",specName="武器"}),nil,"the same spec label is not guessed across classes")
do
 local getID,getClass=GetSpecializationInfoByID,GetSpecializationInfoForClassID
 local idReads,nameReads,idReady,nameReady=0,0,false,false
 GetSpecializationInfoByID=function(id)
  idReads=idReads+1
  return id,"Shared ID",nil,(id~=910102 or idReady) and 1910101 or nil
 end
 GetSpecializationInfoForClassID=function(classID,index)
  nameReads=nameReads+1
  if index==1 then return 920000+classID,"Shared name",nil,1920000+classID end
  return 930000+classID,"Late name",nil,nameReady and 1930000+classID or nil
 end
 for _=1,30 do G:ResolveMemberSpec({class="WARRIOR",specID=910101}) end
 T.eq(idReads,1,"lightweight consumers share complete ID metadata across members")
 local id,name,icon,class=G:ResolveMemberSpec({class="WARRIOR",specID=910102,specName="Shared name",localizedClass="Provided class"})
 T.eq(id,910102);T.eq(name,"Shared ID");T.eq(icon,nil);T.eq(class,"Provided class")
 T.eq(nameReads,0,"an explicit ID never changes to a name-inferred specialization when metadata is incomplete")
 G:ResolveMemberSpec({class="WARRIOR",specID=910102});T.eq(idReads,3,"incomplete ID metadata remains retryable")
 idReady=true;G:ResolveMemberSpec({class="WARRIOR",specID=910102});G:ResolveMemberSpec({class="WARRIOR",specID=910102})
 T.eq(idReads,4,"recovered ID metadata is retained")
 T.eq(G:ResolveMemberSpec({class="WARRIOR",specName="Shared name"}),920001)
 T.eq(G:ResolveMemberSpec({class="PALADIN",specName="Shared name"}),920002,"identical labels resolve within each member's own class")
 for _=1,30 do G:ResolveMemberSpec({class="WARRIOR",specName="Shared name"}) end
 T.eq(nameReads,2,"successful class-name matches reuse the shared directory")
 T.eq(A.Specializations:Get(920001),"Shared name");T.eq(idReads,4,"name discovery also supplies subsequent ID consumers")
 local _,_,missing=G:ResolveMemberSpec({class="WARRIOR",specName="Late name"});T.eq(missing,nil)
 local before=nameReads;nameReady=true
 local _,_,recovered=G:ResolveMemberSpec({class="WARRIOR",specName="Late name"});T.eq(recovered,1930001)
 T.ok(nameReads>before,"incomplete name metadata is retried on the next consumer")
 before=nameReads;G:ResolveMemberSpec({class="WARRIOR",specName="Late name"});T.eq(nameReads,before)
 GetSpecializationInfoByID,GetSpecializationInfoForClassID=getID,getClass
end

-- The last journal tier is the observed season subset, not another expansion.
local nativeAvailable=C_LFGList.GetAvailableActivities
local raidIDs={105,106,501,505,506,507,508,509,510,511,512,513}
local selectedTier=2
local raidJournals={{8101},{8102,8111,8112,8113,8199},{8199,8111,8112,8113}}
local journalByMap={[4101]=8101,[4102]=8102,[4111]=8111,[4112]=8112,[4113]=8113,[0]=1206}
local journalMapCalls={}
EJ_GetCurrentTier=function() return selectedTier end
EJ_GetNumTiers=function() return #raidJournals end
EJ_GetTierInfo=function(id) return ({"The War Within","Midnight","Test season"})[id] end
EJ_SelectTier=function(id) selectedTier=id end
EJ_GetInstanceByIndex=function(index,isRaid) return isRaid and raidJournals[selectedTier][index] or nil end
EJ_GetInstanceInfo=function() return nil end
C_EncounterJournal.GetInstanceForGameMap=function(mapID) journalMapCalls[mapID]=(journalMapCalls[mapID] or 0)+1;return journalByMap[mapID] end
C_LFGList.GetAvailableActivities=function(category,group,flags)
 if category==3 then
  if flags==68 then return {} end -- Real client behavior: raids do not use the dungeon season bit.
  if flags==4 then return raidIDs end
  if flags==5 then local ids={};for _,id in ipairs(raidIDs) do if id~=105 then ids[#ids+1]=id end end;return ids end
  if flags==6 then return {105} end
 end
 if category==2 then if flags==68 then return {502,504} elseif flags==4 then return {502,504} else return {504} end end
 if category==121 then return {601,602,603} end
 return {}
end
ACTIVITY[105]={fullName="Previous expansion raid",shortName="Previous",categoryID=3,mapID=4101,groupFinderActivityGroupID=105,maxNumPlayers=30}
ACTIVITY[106]={fullName="Earlier current expansion raid",shortName="Earlier",categoryID=3,mapID=4102,groupFinderActivityGroupID=106,maxNumPlayers=30,isCurrentRaidActivity=true}
for groupIndex,ids in ipairs({{501,505,506},{507,508,509},{510,511,512}}) do
 for difficultyIndex,id in ipairs(ids) do
  ACTIVITY[id]={fullName="Season raid "..groupIndex,shortName="Season "..groupIndex,categoryID=3,mapID=4110+groupIndex,
   groupFinderActivityGroupID=110+groupIndex,difficultyID=({14,15,16})[difficultyIndex],maxNumPlayers=30,isCurrentRaidActivity=true}
 end
end
ACTIVITY[513]={fullName="World boss",shortName="World",categoryID=3,mapID=0,groupFinderActivityGroupID=513,maxNumPlayers=40,isCurrentRaidActivity=true}
ACTIVITY[601]={fullName="First delve",shortName="First",categoryID=121,mapID=2664,groupFinderActivityGroupID=601}
ACTIVITY[602]={fullName="Second delve",shortName="Second",categoryID=121,mapID=2933,groupFinderActivityGroupID=602}
ACTIVITY[603]={fullName="New unknown delve",shortName="Unknown",categoryID=121,mapID=99999,groupFinderActivityGroupID=603}
C_LFGList.GetAvailableCategories=function() return {2,3,121} end
EXPANSION_NAME10="The War Within";EXPANSION_NAME11="Midnight"
G.Catalog:Invalidate()
local seasonRaids=G.Catalog:GetGroups("seasonRaid")
T.eq(#seasonRaids,3,"season raids follow the last journal tier, excluding older current-expansion raids and world bosses")
T.eq(#G:GetActivities("seasonRaid"),9,"season raids retain every native difficulty variant")
for _,group in ipairs(seasonRaids) do
 T.eq(#group.variants,3);T.eq(group.tier,2,"season membership does not overwrite the original expansion")
end
T.eq(selectedTier,2,"catalog enumeration restores the selected adventure-journal tier")
local tiers=G.Catalog:GetTiers()
T.eq(#tiers,2,"the season pseudo-tier is omitted from the expansion menu")
T.eq(tiers[1].id,1);T.eq(tiers[2].id,2)
T.eq(G.Catalog:GetTierName(2),"Midnight","labels use catalog tier identities")
T.eq(G.Catalog:GetTierName(3),nil,"the season pseudo-tier is not an expansion label")
T.eq(#G:GetActivities("3"),#raidIDs,"ordinary raid browsing includes the complete native PvE catalog")
T.eq(G.Catalog:GetGroup("3",106).tier,2,"earlier raids remain selectable in the current expansion")
T.eq(G.Catalog:GetGroup("3",111).tier,2,"current season raids also remain in their original expansion")
T.eq(G.Catalog:GetGroup("3",105).tier,1)
T.eq(G.Catalog:GetSearchFilter("seasonRaid"),4,"season raid search uses PvE plus explicit native activity IDs")
T.ok(G.Catalog:Matches(G.Catalog:GetActivity(505),"seasonRaid",111,15),"season heroic selection retains its native activity")
T.eq(G.Catalog:Matches(G.Catalog:GetActivity(106),"seasonRaid"),false,"isCurrentRaidActivity does not admit earlier raids")
T.eq(G.Catalog:Matches(G.Catalog:GetActivity(513),"seasonRaid"),false,"map-zero world bosses are not season raid instances")
T.eq(G.Catalog:GetActivity(513).journalID,nil,"map-zero world boss cannot acquire a fake Encounter Journal instance")
T.eq(journalMapCalls[0],nil,"map-zero activity never reaches GetInstanceForGameMap")
T.eq(G.Catalog:GetActivity(501).journalID,8111,"positive raid maps still resolve their real Encounter Journal instance")
-- Raid recruitment checks class coverage within the selected raid size.
do
 local buffs=A.RaidBuffs
 local members={{class="MAGE",subgroup=1},{class="ROGUE",subgroup=4},{class="ROGUE",subgroup=5},{class="WARRIOR",subgroup=6},{class="MONK",subgroup=7},{subgroup=2}}
 local report=buffs.Get(G.Catalog,506,members)
 T.eq(report.maxGroup,4);T.eq(report.memberCount,3);T.eq(report.unknown,1)
 T.eq(report.counts.ROGUE,1);T.eq(report.counts.MONK,nil,"bench groups never cover a missing raid buff")
 local function Missing(key) for _,entry in ipairs(report.missing) do if entry.key==key then return true end end;return false end
 T.ok(Missing("poisons"),"one rogue retains the second-poison reminder");T.eq(Missing("intellect"),false)
 local same=buffs.Get(G.Catalog,505,members,report)
 T.eq(same,report,"roster refreshes reuse the report");T.eq(report.maxGroup,6);T.eq(report.memberCount,5)
 T.eq(report.counts.ROGUE,2);T.eq(Missing("poisons"),false);T.eq(Missing("attackPower"),false)
 T.ok(Missing("physical"),"group seven is excluded from flexible raids too")
 T.eq(buffs.Get(G.Catalog,106,members,report),nil,"earlier raids in this expansion have no coverage panel")
 T.eq(buffs.Get(G.Catalog,513,members,report),nil,"world bosses have no coverage panel")
 T.eq(buffs.Get(G.Catalog,502,members,report),nil,"seasonal dungeons have no coverage panel")
 T.eq(buffs.Get(G.Catalog,nil,members,report),nil)
 local complete={}
 for _,class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","MONK","DRUID","DEMONHUNTER","EVOKER"}) do complete[#complete+1]={class=class} end
 buffs.Get(G.Catalog,501,complete,report);T.eq(#report.missing,0);T.eq(report.unknown,0)
 buffs.Get(G.Catalog,501,{},report);T.eq(#report.missing,13);T.eq(next(report.counts),nil,"departed classes do not survive in a reused report")
 T.eq(report.combatRes,nil);T.eq(report.bloodlust,nil,"coverage has no resurrection or bloodlust counters")
 local getRoster=G.Roster.Get
 G.Roster.Get=function() return complete end
 T.eq(#G:GetRaidBuffs(506).missing,0,"the public service uses the same coverage model")
 G.Roster.Get=getRoster
end
do
 local activities=G.Catalog:GetActivities("seasonRaid")
 local originals,reads={},0
 for index,activity in ipairs(activities) do
  originals[index]=activity
  activities[index]=setmetatable({},{__index=function(_,key) if key=="id" then reads=reads+1 end;return activity[key] end})
 end
 for index=1,4 do T.ok(G.Catalog:Matches(G.Catalog:GetActivity(505),"seasonRaid",111,15)) end
 for index,activity in ipairs(originals) do activities[index]=activity end
 T.eq(reads,0,"repeated result matching does not rescan the cached activity array")
end
raidJournals[3][4]=8102
G.Catalog:Invalidate()
T.ok(G.Catalog:GetGroup("seasonRaid",106),"activity invalidation refreshes the journal season subset")
T.eq(G.Catalog:GetGroup("seasonRaid",113),nil,"old season membership is released on invalidation")
T.ok(G.Catalog:Matches(G.Catalog:GetActivity(106),"seasonRaid"),"new season membership is admitted after invalidation")
T.eq(G.Catalog:Matches(G.Catalog:GetActivity(510),"seasonRaid"),false,"removed season membership cannot survive invalidation")
T.eq(G.Catalog:GetActivityTier(G.Catalog:GetActivity(106)),2,"refreshed season duplicates still preserve expansion ownership")
raidJournals[3][4]=8113
G.Catalog:Invalidate()
local seasonal=G:GetActivities("seasonDungeon")
T.eq(#seasonal,2,"season maps restore all native available difficulty variants")
T.eq(G.Catalog:GetGroups("seasonDungeon")[1].key,20,"season group keeps the native current-season context")
T.eq(#G.Catalog:GetGroups("seasonDungeon")[1].variants,2,"all native available difficulties remain in the season context")
T.eq(G.Catalog:GetGroupKey("2",G.Catalog:GetActivity(504)),20,"the original expansion keeps the same native group under its separate category context")
T.eq(G.Catalog:GetSearchFilter("seasonDungeon"),4,"season search does not filter normal activities out with the season bit")
T.ok(G.Catalog:Matches(G.Catalog:GetActivity(502),"seasonDungeon"))
T.eq(G.Catalog:Matches(G.Catalog:GetActivity(502),"2"),false,"membership is scoped to the category, including overlapping seasonal activities")
T.ok(G.Catalog:Matches(G.Catalog:GetActivity(504),"2"))
T.ok(G.Catalog:Matches(G.Catalog:GetActivity(504),"seasonDungeon"),"the same native group retains all variants in each eligible context")
do
 local group=G.Catalog:GetGroup("seasonDungeon",20)
 local map,locale=group.activity.mapID,A.locale
 group.activity.mapID=2993;A.locale="zhCN"
 T.eq(G.Catalog:GetGroupShortName("seasonDungeon",20),"毒牙","Chinese multi-dungeon labels use the requested short names")
 A.locale="enUS"
 T.eq(G.Catalog:GetGroupShortName("seasonDungeon",20),"AoF","English addon language uses an English abbreviation independently of the client")
 group.activity.mapID=2521
 T.eq(G.Catalog:GetGroupShortName("seasonDungeon",20),"RLP")
 group.activity.mapID=map;A.locale=locale
 T.eq(G.Catalog:GetGroupShortName("seasonDungeon",20),group.name,"unmapped future dungeons retain their actual catalog name")
end

do
	-- Native input changes distinguish requests without inspecting restricted text.
	local view={};G:Attach(view,"search");G.Search:EndBrowse()
	local lease={revision=1};G.Search:BindInput(lease)
	local calls=#S.searchCalls
	G.Search:Search("seasonRaid",501)
	lease.revision=2;G.Search:Search("seasonRaid",501)
	T.eq(#S.searchCalls,calls+1,"changed native input waits for the current request")
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");Stubs.AdvanceClock(0)
	T.eq(#S.searchCalls,calls+2,"the same activity with newer native input is searched again")
	T.eq(S.searchCalls[#S.searchCalls].activityFilter[1],501)
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");G.Search:ReleaseInput(lease);G:Detach(view)
end

do
	-- Queued input must still belong to the current native lease at submission.
	local view={};G:Attach(view,"search");G.Search:EndBrowse()
	local first={revision=1};G.Search:BindInput(first)
	local calls=#S.searchCalls
	T.ok(G.Search:Search("seasonRaid",501,"group"))
	T.ok(G.Search:Search("seasonRaid",nil,"group"))
	G.Search:ReleaseInput(first)
	local second={revision=1};G.Search:BindInput(second)
	G.Search:ReleaseInput(first)
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");Stubs.AdvanceClock(0)
	T.eq(#S.searchCalls,calls+1,"reacquiring the same revision never authorizes the previous lease's queued request")
	T.eq(G.Search:GetState(),"failed")
	T.ok(G.Search:Search("seasonRaid",501,"group"),"a late old-lease release keeps the replacement input usable")
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	G.Search:EndBrowse()
	T.ok(G.Search:Search("seasonRaid",501,"group"),"ending a browse keeps a still-owned input available for the next category")
	T.eq(#S.searchCalls,calls+3)
	T.ok(G.Search:Search("seasonRaid",nil,"group"))
	second.revision=2
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");Stubs.AdvanceClock(0)
	T.eq(#S.searchCalls,calls+3,"editing without resubmitting invalidates the old queued input revision")
	T.eq(G.Search:GetState(),"failed")
	T.ok(G.Search:Search("seasonRaid",501,"group"))
	T.ok(G.Search:Search("seasonRaid",nil,"group"))
	G.Search:ReleaseInput(second)
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");Stubs.AdvanceClock(0)
	T.eq(#S.searchCalls,calls+4,"releasing the current lease prevents its queued request from reaching the native search")
	T.eq(G.Search:GetState(),"failed")
	G:Detach(view)
end

do
	-- Leader searches clear native title tokens before asking for a broad result set.
	local view={};G:Attach(view,"search");G.Search:EndBrowse()
	S.nativeSearchText="title-only token"
	local calls=#S.searchCalls
	T.ok(G.Search:Search("seasonRaid",501,"leader","灵止光"))
	T.eq(S.nativeSearchText,"","leader search clears native text before filtering public leader names")
	T.eq(#S.searchCalls,calls+1)
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");G:Detach(view)
end

do
	-- Rapid category changes keep one latest request; confirmed throttling backs off.
	local view={};G:Attach(view,"search");G.Search:EndBrowse()
	local oldTime=GetTime;local now=1000;GetTime=function() return now end
	local function Advance(seconds) now=now+seconds;Stubs.AdvanceClock(seconds) end
	local calls=#S.searchCalls;local applications=#G:GetApplications()
	local lease={};G.Search:BindInput(lease);S.nativeSearchText="12-15"
	T.ok(G.Search:Search("seasonRaid"))
	T.eq(S.searchCalls[#S.searchCalls].nativeSearchText,"12-15","an active native search lease preserves registered search text")
	G.Search:ReleaseInput(lease)
	T.ok(G.Search:Search("seasonDungeon"),"a selection made during search is accepted for later")
	T.ok(G.Search:Search("3",105),"only the latest selection remains queued")
	T.eq(#S.searchCalls,calls+1,"inflight searches never overlap")
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");Advance(0)
	T.eq(#S.searchCalls,calls+2)
	T.eq(S.searchCalls[#S.searchCalls].activityFilter[1],105,"completion submits the latest native activity")
	Fire("LFG_LIST_SEARCH_FAILED","throttled")
	T.eq(G.Search:GetState(),"waiting")
	T.ok(G:GetSearchError():find("自动",1,true),"waiting explains automatic recovery in Chinese")
	T.ok(G.Search:Search("seasonRaid",501),"a newer selection replaces the throttled request")
	Advance(4);T.eq(#S.searchCalls,calls+2,"throttling waits instead of immediately retrying")
	Advance(1);T.eq(#S.searchCalls,calls+3);T.eq(S.searchCalls[#S.searchCalls].activityFilter[1],501)
	Fire("LFG_LIST_SEARCH_FAILED","throttled")
	Advance(9);T.eq(#S.searchCalls,calls+3,"repeated throttling extends the wait")
	Advance(1);T.eq(#S.searchCalls,calls+4)
	Fire("LFG_LIST_SEARCH_RESULTS_RECEIVED");T.eq(G.Search:GetState(),"done")
	G.Search:Search("seasonRaid");Fire("LFG_LIST_SEARCH_FAILED","timeout")
	T.eq(G.Search:GetState(),"failed","other failures do not enter an automatic retry loop")
	Advance(60);T.eq(#S.searchCalls,calls+5)
	G.Search:Search("seasonRaid");Fire("LFG_LIST_SEARCH_FAILED","throttled")
	local timer=G.Search.timer;T.ok(timer,"a throttled request owns one cancelable timer")
	G:Detach(view);T.eq(timer.cancelled,true,"closing cancels the queued search")
	Advance(60);T.eq(#S.searchCalls,calls+6,"a closed page never restarts its queued search")
	T.eq(#G:GetApplications(),applications,"search scheduling does not change applications")
	GetTime=oldTime
end
T.eq(G:GetActivities("2")[1].id,504,"original difficulty context uses non-season flags")
local delves=G.Catalog:GetGroups("121")
T.eq(#delves,3,"new unmapped delves remain visible")
T.eq(delves[1].tier,1,"TWW tier comes from verified map expansion metadata")
T.eq(delves[2].tier,2,"Midnight tier comes from verified map expansion metadata")
T.eq(delves[3].tier,nil,"unknown map expansion is not inferred")
do
 local tierInfo=EJ_GetTierInfo
 EJ_GetTierInfo=function(id) return id==2 and "Different journal label" or tierInfo(id) end
 G.Catalog:Invalidate()
 T.eq(G.Catalog:GetActivityTier(G.Catalog:GetActivity(602)),"exp11","verified delve expansion remains usable without a matching journal label")
 T.eq(G.Catalog:GetTierName("exp11"),"Midnight","synthetic expansion IDs resolve through the catalog, not EJ_GetTierInfo")
 EJ_GetTierInfo=tierInfo;G.Catalog:Invalidate()
end

do
 ACTIVITY[999]={fullName="评级战场",shortName="评级",categoryID=9,isPvpActivity=true,isRatedPvpActivity=true,maxNumPlayers=0}
 S.results[999]={activityIDs={999},name="Rated",numMembers=8,age=0,leaderOverallDungeonScore=3123,requiredDungeonScore=2500,requiredPvpRating=1800,leaderPvpRatingInfo={{bracket=4,rating=1620,activityName="评级战场",tier=3},{bracket=1,rating=2400,activityName="2v2",tier=4}}}
 local r=G.Results:Capture(999)
 T.eq(r.maxNumPlayers,10,"rated battlegrounds recover the native ten-player team size when the activity reports zero")
 T.eq(r.leaderRating,1620,"评级PvP跟随原生首项赛制评分，不取最高竞技分或大秘境分")
 T.eq(r.requiredRating,1800,"PvP要求独立于大秘境要求")
 T.eq(r.pvpRatingActivity,"评级战场")
 T.eq(#r.pvpRatings,2,"队长所有原生赛制评分保留给详情")
 S.results[999].leaderPvpRatingInfo[3]={bracket=3,rating=1550,activityName="5v5",tier=2}
 r=G.Results:Capture(999);T.eq(r.pvpRatings[3].activityName,"5v5","尊重API真返回的旧赛制，不制造新活动")
 S.results[999].leaderPvpRatingInfo[1].rating=0;r=G.Results:Capture(999);T.eq(r.leaderRating,0,"零分仍是有效评级")
 S.results[999].leaderPvpRatingInfo={};r=G.Results:Capture(999);T.eq(r.leaderRating,nil,"缺少PvP评分不回退大秘境分")
 ACTIVITY[999].isRatedPvpActivity=false;S.results[999].leaderPvpRatingInfo={{rating=1620}};r=G.Results:Capture(999);T.eq(r.leaderRating,nil,"非评级PvP不展示无关评分")
 T.eq(r.pvpRatings,nil,"非评级结果不保留无关赛制列表")
end

do
 ACTIVITY[997]={fullName="2v2",shortName="2v2",categoryID=4,isRatedPvpActivity=true,maxNumPlayers=2}
 ACTIVITY[998]={fullName="3v3",shortName="3v3",categoryID=4,isPvpActivity=true,isRatedPvpActivity=true,maxNumPlayers=3}
 S.results[997]={activityIDs={997},name="2v2 team",numMembers=1,age=1,leaderOverallDungeonScore=3900,leaderPvpRatingInfo={{bracket=1,rating=1450,activityName="2v2"},{bracket=2,rating=2400,activityName="3v3"}}}
 S.results[998]={activityIDs={998},name="3v3 team",numMembers=1,age=2,leaderOverallDungeonScore=2100,leaderPvpRatingInfo={{bracket=2,rating=1900,activityName="3v3"},{bracket=1,rating=1200,activityName="2v2"}}}
 S.players[997]={{name="ArenaLeader-Away",isLeader=true,classFilename="MAGE",dungeonScore=3900}}
 S.resultIDs={997,998};G.Results:BeginSearch(990);G.Results:CommitResults(990);G.Search:SetFilters({sort="rating"})
 T.same(G.Results:GetResults(),{998,997},"竞技场排序使用每条原生首列评级，不取最高赛制或M+评分")
 local r=G.Results:GetResult(997);T.eq(r.ratingKind,"pvp");T.eq(r.leaderRating,1450);T.eq(r.pvpRatingActivity,"2v2")
 local member=G.Results:GetDetails(r).members[1]
 T.eq(member.rating,1450,"已知队长身份的成员详情使用同一原生PvP首列评分");T.eq(member.ratingKind,"pvp")
 S.results[997].leaderPvpRatingInfo[1].rating=0;S.results[997].age=5
 S.results[998].leaderPvpRatingInfo={};S.results[998].age=1
 G.Results:OnResultUpdated(997);G.Results:OnResultUpdated(998)
 T.same(G.Results:GetResults(),{997,998},"有效PvP零分排在缺失评分之前")

 S.activeEntry={activityIDs={997},name="Arena listing"}
 S.applicants={[950]={applicationStatus="applied",numMembers=2,displayOrderID=1}}
 S.applicantMembers={[950]={{name="ArenaOne-Away",class="MAGE",itemLevel=250,pvpItemLevel=288,dungeonScore=3900},{name="ArenaTwo-Away",class="PRIEST",itemLevel=260,pvpItemLevel=285,dungeonScore=4100}}}
 S.applicantPvp[997]={[950]={{bracket=1,rating=1500,activityName="2v2",tier=2}}}
 S.applicantPvp[998]={[950]={{bracket=2,rating=1820,activityName="3v3",tier=3},{bracket=2,rating=1740,activityName="3v3",tier=2}}}
 Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 local app=G.Applicants:GetApplicant(950);local first=app.members[1]
 T.same(S.applicantPvpCalls[#S.applicantPvpCalls],{950,2,997},"申请者API使用招募activityIDs[1]与真实成员索引")
 T.eq(first.rating,1500);T.eq(first.ratingKind,"pvp");T.eq(first.itemLevel,288,"PvP申请者使用PvP装等")
 T.eq(app.members[2].rating,nil,"缺少当前竞技场赛制评分不回退M+分")
 S.applicantPvp[997][950][1].rating=0;Fire("LFG_LIST_APPLICANT_UPDATED",950);T.eq(first.rating,0,"申请者零分保留")
 S.activeEntry.activityIDs={998};Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 T.eq(app.members[1],first,"活动切换原地更新申请者");T.eq(first.rating,1820,"非新建的招募活动变更也重取新赛制")
 T.eq(first.pvpRatingInfo.activityName,"3v3");T.eq(app.members[2].rating,1740)
 local calls=#S.applicantPvpCalls
 S.activeEntry.activityIDs={501};Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 T.eq(first.ratingKind,"dungeon");T.eq(first.rating,3900);T.eq(first.itemLevel,250)
 T.eq(first.pvpRatingInfo,nil,"切回PvE不残留旧竞技场赛制");T.eq(#S.applicantPvpCalls,calls,"PvE不请求PvP申请者评分")
 S.activeEntry=nil;Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
end

-- Recruitment data stays readable; only the native action owners enforce roles.
do
 local inGroup,isLeader,isAssistant=IsInGroup,UnitIsGroupLeader,UnitIsGroupAssistant
 local role,grouped="member",true
 IsInGroup=function(category) return grouped end
 UnitIsGroupLeader=function(unit,category) return category~=LE_PARTY_CATEGORY_HOME or role=="leader" end
 UnitIsGroupAssistant=function(unit,category) return category==LE_PARTY_CATEGORY_HOME and role=="assistant" end
 local permissionChanges=0
 local unsubscribe=G:Subscribe(function(kind) if kind=="permissions" then permissionChanges=permissionChanges+1 end end)
 S.activeEntry={activityIDs={501},name="Shared listing",isCrossFactionListing=false}
 S.applicants={
  [981]={applicationStatus="applied",numMembers=2,displayOrderID=1,comment="One shared comment"},
  [982]={applicationStatus="applied",numMembers=1,displayOrderID=2}}
 S.applicantMembers={
  [981]={{name="First-Away",class="MAGE"},{name="Second-Away",class="PRIEST"}},
  [982]={{name="Third-Away",class="WARRIOR"}}}
 Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",true);Fire("GROUP_ROSTER_UPDATE")
 T.eq(G:HasViews(),false,"permission events remain active after every page closes")
 T.eq(#Stubs.FramesWithEvent("PARTY_LEADER_CHANGED"),1,"an active listing observes leadership changes without a page")
 T.eq(G:CanManageApplicants(),false,"instance leadership does not grant home-group applicant management")
 T.eq(G:CanManageListing(),false,"ordinary home-group members cannot change the listing")
 local refreshes,reads,infoReads=S.applicantRefreshCalls or 0,S.applicantListReads,S.applicantInfoReads
 T.ok(G:RefreshApplicants(),"ordinary members may request the native applicant refresh")
 T.eq(S.applicantRefreshCalls,refreshes+1)
 T.eq(S.applicantListReads,reads+1,"read-only viewers still read the native full ID list")
 T.eq(S.applicantInfoReads,infoReads+2,"every returned applicant is read regardless of the viewer role")
 T.same(G:GetApplicants(),{981,982});T.eq(#G:GetApplicant(981).members,2)
 T.eq(G:GetApplicant(981).comment,"One shared comment")
 local invites,declines,changes,removes=#S.inviteCalls,S.declineCalls or 0,#S.createDataHistory,S.removeCalls
 T.eq(G:Invite(981),false);T.eq(G:Decline(982),false)
 T.eq(#S.inviteCalls,invites);T.eq(S.declineCalls or 0,declines)
 T.eq(G:GetApplicant(981).acting,nil,"a rejected read-only action does not enter a pending state")
 T.eq(G:Publish({activityID=501}),false);T.eq(G:Update({activityID=501,isCrossFactionListing=true}),false);T.eq(G:RemoveListing(),false)
 T.eq(#S.createDataHistory,changes);T.eq(S.removeCalls,removes,"read-only and stale delist calls never reach native APIs")
 local before=permissionChanges
 Fire("GROUP_ROSTER_UPDATE");T.eq(permissionChanges,before,"unchanged permissions do not rebuild applicant controls")
 role="assistant";Fire("GROUP_ROSTER_UPDATE")
 T.eq(permissionChanges,before+1,"promotion updates permission consumers")
 T.ok(G:CanManageApplicants());T.eq(G:CanManageListing(),false,"assistants manage applicants but cannot edit the listing")
 T.ok(G:Invite(981));T.ok(G:Decline(982));T.eq(#S.inviteCalls,invites+1);T.eq(S.declineCalls,declines+1)
 T.eq(G:Update({activityID=501}),false);T.eq(G:RemoveListing(),false);T.eq(S.removeCalls,removes)
 local staleInvite,staleDecline=G.Invite,G.Decline
 role="member";Fire("GROUP_ROSTER_UPDATE")
 local ok,reason=staleInvite(G,981)
 T.eq(ok,false);T.eq(reason,G.L.applicantPermission,"lost permissions win over an older button's pending record")
 T.eq(staleDecline(G,982),false);T.eq(#S.inviteCalls,invites+1);T.eq(S.declineCalls,declines+1)
 T.same(G:GetApplicants(),{981,982},"losing management rights preserves all returned applicant records")
 role="leader";Fire("PARTY_LEADER_CHANGED")
 T.ok(G:CanManageApplicants());T.ok(G:CanManageListing())
 T.ok(G:RemoveListing());Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 T.ok(G:Publish({activityID=501,isCrossFactionListing=false}),"the home-group leader can publish")
 T.ok(G:Update({activityID=501,requiredItemLevel=222,isCrossFactionListing=false}))
 T.eq(S.createDataHistory[#S.createDataHistory].op,"update")
 T.eq(G:GetListing().requiredItemLevel,222)
 T.ok(G:RemoveListing());Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 T.eq(#Stubs.FramesWithEvent("PARTY_LEADER_CHANGED"),0,"finished recruitment releases its leadership listener")
 grouped=false;role="member"
 T.ok(G:CanManageApplicants(),"solo publishers retain applicant ownership before anyone joins")
 T.ok(G:CanManageListing());T.ok(G:Publish({activityID=501}),"solo publishing remains available")
 T.ok(G:RemoveListing());Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 local requested=S.applicantRefreshCalls
 T.eq(G:RefreshApplicants(),false);T.eq(S.applicantRefreshCalls,requested,"no listing means no native applicant refresh request")
 unsubscribe();IsInGroup,UnitIsGroupLeader,UnitIsGroupAssistant=inGroup,isLeader,isAssistant
 G:RefreshPermissions();S.applicants={};S.applicantMembers={}
end

-- Native applicant bursts update business state now and publish one display refresh.
do
 local applicants,members=S.applicants,S.applicantMembers
 S.activeEntry={activityIDs={501},name="Burst listing"};S.applicants={};S.applicantMembers={}
 Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",true)
 for id=1,50 do
  S.applicants[id]={applicationStatus="applied",numMembers=5,displayOrderID=id}
  S.applicantMembers[id]={}
  for index=1,5 do S.applicantMembers[id][index]={name="Burst"..id.."_"..index.."-Away",class="WARRIOR",dungeonScore=2000} end
 end
 G:RefreshApplicants();G:GetApplicants()
 local updates,sorts=0,0
 local sort=table.sort
 table.sort=function(...)
  if debug.getinfo(2,"S").short_src:find("LycheeGroup_Group/Applicants.lua",1,true) then sorts=sorts+1 end
  return sort(...)
 end
 local unsubscribe=G:Subscribe(function(kind) if kind=="applicants" then updates=updates+1;G:GetApplicants() end end)
 for id=1,50 do
  S.applicants[id].displayOrderID=51-id
  if id==1 then S.applicants[id].pendingApplicationStatus="invited" end
  if id==2 then S.applicantMembers[id][1].specID=71 end
  Fire("LFG_LIST_APPLICANT_UPDATED",id)
 end
 Fire("LFG_LIST_APPLICANT_LIST_UPDATED")
 T.eq(G:GetApplicant(1).pendingStatus,"invited","pending state is readable before the display task runs")
 T.eq(G:GetApplicant(2).members[1].specID,71,"member metadata is immediately current")
 T.eq(G:Invite(1),false,"a queued repaint never permits another action during native pending state")
 T.eq(updates,0,"a same-frame event burst defers display notifications")
 T.eq(Stubs.PendingTimers(),1,"the entire burst owns one pending display task")
 Stubs.AdvanceClock(0)
 T.eq(updates,1);T.eq(sorts,1,"the consumer sorts the full applicant list once for the burst")
 local expected={};for id=50,1,-1 do expected[#expected+1]=id end
 T.eq(table.concat(G:GetApplicants(),","),table.concat(expected,","),"all fifty batches retain the native display order")
 T.eq(#G:GetApplicant(50).members,5,"all members of the final batch remain present")
 local invite=C_LFGList.InviteApplicant
 C_LFGList.InviteApplicant=function(id)
  invite(id);S.applicants[id].pendingApplicationStatus="invited";Fire("LFG_LIST_APPLICANT_UPDATED",id)
 end
 Fire("LFG_LIST_APPLICANT_UPDATED",2);local before=updates
 T.ok(G:Invite(2));T.eq(updates,before+1,"inviting publishes the resulting state synchronously")
 T.eq(G:GetApplicant(2).pendingStatus,"invited","a synchronous native response is retained")
 T.eq(Stubs.PendingTimers(),0,"the action consumes any pending display task")
 Stubs.AdvanceClock(0);T.eq(updates,before+1,"no stale repaint follows the synchronous action")
 C_LFGList.InviteApplicant=invite
 Fire("LFG_LIST_APPLICANT_UPDATED",3);before=updates
 T.ok(G:Decline(3));T.eq(updates,before+1,"declining also publishes synchronously")
 T.eq(Stubs.PendingTimers(),0)
 Fire("LFG_LIST_APPLICANT_UPDATED",4);before=updates
 G.Applicants:Clear();T.eq(updates,before+1,"clear publishes the empty state synchronously")
 T.eq(Stubs.PendingTimers(),0,"clear cancels the pending display task")
 Stubs.AdvanceClock(0);T.eq(updates,before+1);T.eq(#G:GetApplicants(),0)
 unsubscribe();table.sort=sort
 S.activeEntry=nil;Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE",false)
 S.applicants,S.applicantMembers=applicants,members
end

-- Hidden applications reuse their containers while every native refresh stays fresh.
do
 A.db.autoJoin=false
 ACTIVITY[9002]={fullName="Private application",shortName="",categoryID=2,mapID=0,maxNumPlayers=5,groupFinderActivityGroupID=9002,difficultyID=0}
 S.results[9003]={activityIDs={9002},name="Before refresh",leaderName="PrivateLeader-Away",numMembers=2}
 S.players[9003]={
  {name="PrivateLeader-Away",classFilename="WARRIOR",specName="Arms",isLeader=true},
  {name="PrivateMember-Away",classFilename="PALADIN",specName="Retribution"}}
 S.applications={9003};S.appStatus={[9003]="applied"};S.appPending={}
 G.Results:BeginSearch(20000);G.Applications:SyncAll()
 local app=G:GetApplication(9003);local result,details=app.result,app.result.details
 local members,reads=details.members,S.playerReads
 T.eq(G:GetResult(9003),nil,"the application owns its snapshot after the browse store is cleared")
 S.results[9003].name="After refresh"
 S.players[9003][1]={name="PrivateLeader-Away",classFilename="PALADIN",specName="Holy",isLeader=true}
 S.players[9003][2]={name="Replacement-Away",classFilename="WARRIOR",specName="Fury"}
 G.Applications:SyncAll()
 T.eq(app.result,result,"an application without a search-store record reuses its result container")
 T.eq(app.result.details,details,"private refreshes reuse the detail container")
 T.eq(app.result.details.members,members,"private refreshes reuse the members array")
 T.eq(S.playerReads,reads+2,"container reuse still reads every native member, even in the same frame")
 T.eq(app.name,"After refresh");T.eq(app.leaderClass,"PALADIN")
 T.eq(members[1].specName,"Holy");T.eq(members[2].name,"Replacement-Away")
 local nativeApplicationInfo=C_LFGList.GetApplicationInfo
 local applicationReads,updates=0,0
 C_LFGList.GetApplicationInfo=function(...) applicationReads=applicationReads+1;return nativeApplicationInfo(...) end
 local stop=G:Subscribe(function(kind) if kind=="applications" then updates=updates+1 end end)
 S.results[9003].name="Updated by result event";S.results[9003].leaderName="ReplacementLeader-Away"
 S.players[9003][1]={name="ReplacementLeader-Away",classFilename="MAGE",specName="Fire",isLeader=true}
 local resultReads=S.resultReads
 T.eq(Stubs.FireEvent("LFG_LIST_SEARCH_RESULT_UPDATED",9003),1,"hidden active applications still receive their native result updates")
 G.Results:BeginSearch(20001)
 T.ok(G.Results.updatePending,"ending a browse preserves queued updates owned by an active application")
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(app.name,"Updated by result event");T.eq(app.leaderName,"ReplacementLeader-Away");T.eq(app.leaderClass,"MAGE")
 T.eq(app.result,result);T.eq(app.status,"applied","metadata refresh does not alter application state")
 T.eq(G:GetResultCount(),0,"a private update never adds a result to the closed browser")
 T.eq(S.resultReads,resultReads+1);T.eq(applicationReads,0,"metadata updates do not reread all native application statuses")
 T.eq(updates,1,"the floating window receives one application notification")
 local oldIDs=S.resultIDs;S.resultIDs={}
 S.results[9003].name="Other-category update"
 Stubs.FireEvent("LFG_LIST_SEARCH_RESULT_UPDATED",9003);G.Results:QueueUpdate()
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(app.name,"Other-category update","a bulk snapshot cannot consume another category's application update without reading it")
 T.eq(updates,2);T.eq(G:GetResultCount(),0)
 S.resultIDs={9003}
 G.Results:CommitResults(20001)
 T.eq(app.result,G:GetResult(9003),"a new browse adopts its current result object for the existing application")
 T.ok(app.result~=result);T.eq(updates,3,"a result batch publishes application metadata once")
 result,details=app.result,app.result.details;members=details.members
 S.results[9003].name="Visible result update"
 Stubs.FireEvent("LFG_LIST_SEARCH_RESULT_UPDATED",9003);G.Game.frame:GetScript("OnUpdate")()
 T.eq(app.name,"Visible result update");T.eq(updates,4);T.eq(applicationReads,0)
 stop();C_LFGList.GetApplicationInfo=nativeApplicationInfo;S.resultIDs=oldIDs
 G.Results:BeginSearch(20002)
 reads=S.playerReads;S.players[9003][2].specName="Arms"
 Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",9003,"applied","applied")
 T.eq(S.playerReads,reads+2,"application status events also refresh all same-count member details")
 T.eq(members[2].specName,"Arms")
 S.players[9003][1].isLeader=false
 G.Applications:SyncAll()
 T.eq(app.leaderClass,nil,"an unavailable leader class cannot retain the previous snapshot's color")
 S.applications={};G.Applications:SyncAll();G.Applications:ReleaseFinished()
 G.Results:BeginSearch(20002)
 G.Results:QueueUpdate(9003)
 T.eq(G.Results.updatePending,nil,"a finished private application cannot be revived by a late result update")
 S.results[9003],S.players[9003],ACTIVITY[9002]=nil,nil,nil
end

-- A burst of application metadata changes publishes one complete snapshot.
do
 local applicationIDs={9011,9012,9013,9014,9015}
 S.applications=applicationIDs;S.appStatus={};S.appPending={}
 for _,id in ipairs(applicationIDs) do S.appStatus[id]="applied";S.results[id]={activityIDs={502},name="Before burst",leaderName="Leader-Away",numMembers=1} end
 G.Results:BeginSearch(20100);G.Applications:SyncAll()
 local updates=0;local stop=G:Subscribe(function(kind) if kind=="applications" then updates=updates+1 end end)
 local reads=S.resultReads
 for _=1,6 do for _,id in ipairs(applicationIDs) do S.results[id].name="After burst "..id;Stubs.FireEvent("LFG_LIST_SEARCH_RESULT_UPDATED",id) end end
 T.eq(updates,0);T.eq(S.resultReads,reads,"the native burst remains queued")
 G.Game.frame:GetScript("OnUpdate")()
 T.eq(updates,1,"all application result IDs in one frame publish one complete application snapshot")
 T.eq(S.resultReads,reads+5,"every changed application is still refreshed once")
 for _,id in ipairs(applicationIDs) do T.eq(G:GetApplication(id).name,"After burst "..id);T.eq(G:GetApplication(id).status,"applied") end
 T.eq(G.Game.frame:GetScript("OnUpdate"),nil);T.eq(G:GetResultCount(),0)
 stop();S.applications={};G.Applications:SyncAll();G.Applications:ReleaseFinished()
 for _,id in ipairs(applicationIDs) do S.results[id]=nil end
end

-- Confirmed terminal events still advance status without rebuilding discarded data.
do
 ACTIVITY[9901]={categoryID=3,fullName="Terminal audit",maxNumPlayers=30,mapID=0}
 S.results[9901]={activityIDs={9901},name="Terminal",leaderName="Leader-Away",numMembers=30}
 S.players[9901]={}
 for i=1,30 do S.players[9901][i]={name=(i==1 and "Leader" or "Member"..i).."-Away",classFilename="WARRIOR",assignedRole="DAMAGER",isLeader=i==1} end
 G.Results:BeginSearch(22001);S.applications={9901};S.appStatus[9901]="applied"
 G.Applications:SyncAll();local record=G:GetApplication(9901)
 local results,members,counts=S.resultReads,S.playerReads,S.memberCountReads
 local cancelled=0;local unsub=G:Subscribe(function(kind,id) if kind=="applicationCancelled" and id==9901 then cancelled=cancelled+1 end end)
 S.appStatus[9901]="cancelled";Fire("LFG_LIST_APPLICATION_STATUS_UPDATED",9901,"cancelled","applied")
 T.eq(S.resultReads,results,"a confirmed terminal never rereads discarded result metadata")
 T.eq(S.playerReads,members,"a confirmed terminal never rereads the discarded full roster")
 T.eq(S.memberCountReads,counts)
 T.eq(record.status,"cancelled");T.eq(cancelled,1)
 T.eq(G:GetApplication(9901),nil);T.eq(G.Applications:GetActiveCount(),0)
 unsub();S.applications={};G.Applications:SyncAll()
 S.results[9901],S.players[9901],S.appStatus[9901],ACTIVITY[9901]=nil,nil,nil,nil
end

-- Reuse only a known identity at the same position; tooltip-held identities stay stable.
do
 ACTIVITY[9004]={fullName="Identity arena",shortName="",categoryID=7,mapID=0,maxNumPlayers=5,isPvpActivity=true,isRatedPvpActivity=true}
 ACTIVITY[9005]={fullName="Identity dungeon",shortName="",categoryID=2,mapID=0,maxNumPlayers=5}
 S.results[9004]={activityIDs={9004},name="Identity snapshot",leaderName="Stable-Away",numMembers=2,numCharFriends=1,leaderPvpRatingInfo={{bracket=2,rating=1400,activityName="3v3"}}}
 S.players[9004]={
  {name="Stable-Away",classFilename="WARRIOR",className="Warrior",specName="Arms",assignedRole="DAMAGER",isLeader=true,areaName="Before",lfgRoles=4,isLeaver=true},
  {name="Second-Away",classFilename="PRIEST",className="Priest",specName="Holy",assignedRole="HEALER"}}
 S.friends[9004]={character={"Stable-Away"}}
 G.Results:BeginSearch(20001);S.resultIDs={9004};G.Results:CommitResults(20001)
 local details=G:GetResultDetails(9004);local held,second=details.members[1],details.members[2]
 T.eq(held.rating,1400);T.eq(held.isCharFriend,nil,"a full leader identity retains rating data without search relationship attribution")
 S.results[9004].activityIDs={9005};S.results[9004].numCharFriends=0
 S.players[9004]={
  {name="Stable-Away",classFilename="WARRIOR",className="Warrior",specName="Fury",assignedRole="DAMAGER",isLeader=true,lfgRoles=4},
  {name="Second-Away",classFilename="PRIEST",className="Priest",specName="Discipline",assignedRole="HEALER"}}
 G.Results:OnResultUpdated(9004);G:GetResultDetails(9004)
 T.ok(details.members[1]==held,"fresh native tables reuse the same explicit identity at the same position")
 T.eq(held.specName,"Fury");T.eq(held.lfgRoles,4,"all native fields survive the copy")
 T.eq(held.areaName,nil,"native fields that disappear do not survive in the reused member")
 T.eq(held.isLeaver,nil);T.eq(held.isCharFriend,nil);T.eq(held.ratingKind,"dungeon")
 T.eq(held.rating,nil);T.eq(held.pvpRatingInfo,nil,"old PvP metadata is cleared when the activity changes")
 S.players[9004][1]=held -- Existing fixtures may return the already normalized object.
 G.Results:OnResultUpdated(9004);G:GetResultDetails(9004)
 T.eq(held.name,"Stable-Away");T.eq(held.classFilename,"WARRIOR","a native object aliased to the cached member is never wiped before copying itself")
 S.players[9004]={
  {name="Second-Away",classFilename="PRIEST",specName="Discipline"},
  {name="Stable-Away",classFilename="WARRIOR",specName="Protection"}}
 G.Results:OnResultUpdated(9004);G:GetResultDetails(9004)
 T.ok(details.members[1]~=held and details.members[2]~=second,"reordering replaces slots instead of changing their previous identities")
 T.eq(held.name,"Stable-Away");T.eq(held.specName,"Fury","a tooltip-held member is not rewritten as a different slot's player")
 S.players[9004]={{name="Unknown",classFilename="MAGE",specName="Frost"}}
 S.results[9004].numMembers=1;G.Results:OnResultUpdated(9004);G:GetResultDetails(9004)
 local unknown=details.members[1];T.eq(#details.members,1,"a smaller native roster truncates the reused array")
 S.players[9004]={{name="Unknown",classFilename="MAGE",specName="Fire"}}
 G.Results:OnResultUpdated(9004);G:GetResultDetails(9004)
 T.ok(details.members[1]~=unknown,"an incomplete player identity cannot authorize object reuse")
 T.eq(unknown.specName,"Frost");T.eq(details.members[1].specName,"Fire")
 G.Results:BeginSearch(20002)
 S.results[9004],S.players[9004],S.friends[9004],ACTIVITY[9004],ACTIVITY[9005]=nil,nil,nil,nil,nil
end

-- Creation settings are saved only by an explicit favorite action.
do
 local store,changes={},0
 local presets=A.CreationPresets.New(store,function() changes=changes+1 end)
 local data={activityID=502,name="+18 friends",comment="Keep full text",requiredItemLevel=320,requiredDungeonScore=3500,privateGroup=true,isCrossFactionListing=true,autoAccept=false,questID=900,playstyle=2,generalPlaystyle=3,newPlayerFriendly=true}
 T.eq(presets:Get(),store,"the saved favorites array is the only list")
 local first=presets:ToggleFavorite(data)
 T.ok(first);T.eq(changes,1)
 T.eq(first.favorite,true);T.eq(first.name,nil);T.eq(first.comment,nil);T.eq(first.autoTitle,nil)
 T.eq(first.privateGroup,true);T.eq(first.questID,900);T.eq(first.generalPlaystyle,3)
 local form={activityID=502,requiredItemLevel=320,requiredDungeonScore=3500,requiredPvpRating=0,isPrivateGroup=true,isAutoAccept=false,isCrossFactionListing=true,questID=900,playstyle=2,generalPlaystyle=3,newPlayerFriendly=true}
 T.eq(presets:Find(form),first,"form flags match the normalized listing flags")
 T.eq(changes,1,"matching does not write or notify")
 local second=presets:ToggleFavorite({activityID=503})
 T.eq(presets:Get()[1],second,"a new user favorite is inserted first")
 data.name="|Ku1|k";data.comment="A different description"
 T.eq(presets:Find(data),first,"protected or custom text is irrelevant to favorite identity")
 T.eq(presets:Get()[1],second);T.eq(changes,2,"matching never reorders favorites")
 T.eq(presets:ToggleFavorite(form),nil,"the same settings cancel the existing favorite")
 T.eq(#store,1);T.eq(first.favorite,nil)
 form.requiredItemLevel=325
 local changed=presets:ToggleFavorite(form)
 T.eq(presets:Get()[1],changed);T.eq(presets:Find(data),nil,"changed requirements are a different favorite")
 local basic=presets:ToggleFavorite({activityID=501})
 local explicitDefaults={activityID=501,requiredItemLevel=0,requiredDungeonScore=0,requiredPvpRating=0,isAutoAccept=false,isPrivateGroup=false,isCrossFactionListing=false,newPlayerFriendly=false,playstyle=0,generalPlaystyle=0,questID=0}
 T.eq(presets:Find(explicitDefaults),basic,"missing requirements and flags match form defaults")
 T.eq(presets:ToggleFavorite(explicitDefaults),nil);T.eq(presets:Find({activityID=501}),nil)
 local restored=A.CreationPresets.New(store,function() end)
 T.eq(restored:Get()[1],changed);T.eq(restored:Get()[1].requiredItemLevel,325,"favorite order and settings survive a reload")
 presets:Remove(second);T.eq(#store,1);T.eq(second.favorite,nil)
 local notified=changes;presets:Remove(second);T.eq(changes,notified,"removing an absent favorite does not notify")
 T.eq(presets.Record,nil,"there is no automatic recording API")
 T.eq(presets:ToggleFavorite({activityID=0}),nil)
 T.eq(presets:ToggleFavorite({activityID=99999999}),nil,"unknown activities cannot be saved")
 T.eq(changes,notified);T.eq(#store,1)
 local oldest={activityID=502,name="Old name",comment="Old description",requiredItemLevel=320,favorite=true,inHistory=true,usedAt=1,autoTitle=true}
 local newest={activityID=502,name="|Ku1|k",comment="|Ku1|k",requiredItemLevel=320,requiredDungeonScore=0,isAutoAccept=false,isPrivateGroup=false,favorite=true,usedAt=7}
 local other={activityID=503,name="Other activity",favorite=true,inHistory=true,usedAt=6}
 local legacy={
  {activityID=501,name="History only",inHistory=true,usedAt=9},oldest,other,newest,
  {activityID=504,inHistory=true,favorite=false,usedAt=8},
 }
 local migrated=A.CreationPresets.New(legacy,function() error("construction must not notify before service registration") end)
 T.eq(#legacy,2);T.eq(migrated:Get()[1],newest,"migration keeps the newest equivalent favorite")
 T.eq(migrated:Get()[2],other,"history-only entries are discarded")
 for _,entry in ipairs(legacy) do
  T.eq(entry.favorite,true);T.eq(entry.name,nil);T.eq(entry.comment,nil);T.eq(entry.autoTitle,nil);T.eq(entry.inHistory,nil);T.eq(entry.usedAt,nil)
 end
 A.CreationPresets.New(legacy,function() end);T.eq(legacy[1],newest);T.eq(legacy[2],other,"migration is stable after timestamps are removed")
 local secret,wasSecret={},issecretvalue
 _G.issecretvalue=function(value) return value==secret end
 T.eq(presets:ToggleFavorite({activityID=secret}),nil,"a secret activity is not saved")
 local public=presets:ToggleFavorite({activityID=504,requiredItemLevel=secret,name=secret,comment=secret})
 T.ok(public);T.eq(public.requiredItemLevel,0);T.eq(public.name,nil);T.eq(public.comment,nil)
 _G.issecretvalue=wasSecret
end
-- Remote search members do not inherit their leader's faction.
do
 S.results[8011]={activityIDs={502},name="Faction party",leaderName="Leader-Away",leaderFactionGroup=0,numMembers=2}
 S.players[8011]={{name="Leader-Away",classFilename="MAGE",isLeader=true},{name="Guest-Away",classFilename="WARRIOR"}}
 local record=G.Results:Capture(8011)
 local details=G.Results:GetDetails(record)
 T.eq(details.members[1].factionGroup,0);T.eq(details.members[2].factionGroup,nil,"a cross-faction party's other member is not assumed to match its leader")
 S.results[8011].leaderFactionGroup=1;S.now=S.now+1;G.Results:Capture(8011,record)
 T.eq(G.Results:GetDetails(record).members[1].factionGroup,1,"a changed native leader faction invalidates cached member details")
 S.results[8011],S.players[8011]=nil,nil
end
-- Native Mythic+ summaries are lazy, event-invalidated and tied to the exact applicant member.
do
 local entry,applicants,members=S.activeEntry,S.applicants,S.applicantMembers
 local best,current=C_LFGList.GetApplicantBestDungeonScore,C_LFGList.GetApplicantDungeonScoreForListing
 local reads=0
 C_LFGList.GetApplicantBestDungeonScore=function(id,index) reads=reads+1;T.eq(id,8001);T.eq(index,1);return {mapName="Best dungeon",bestRunLevel=19,finishedSuccess=false} end
 C_LFGList.GetApplicantDungeonScoreForListing=function(id,index,activity) reads=reads+1;T.eq(id,8001);T.eq(index,1);T.eq(activity,502);return {mapName="Current dungeon",bestRunLevel=18,finishedSuccess=true} end
 S.activeEntry={activityIDs={502},name="Mythic listing"};S.applicants={[8001]={applicationStatus="applied",numMembers=2}};S.applicantMembers={[8001]={{name="Alliance-Away",class="MAGE",factionGroup=1},{name="Horde-Away",class="WARRIOR",factionGroup=0}}}
 G.Listing:OnEntryUpdate();G:RefreshApplicants()
 local member=G:GetApplicant(8001).members[1]
 T.eq(member.factionGroup,1);T.eq(G:GetApplicant(8001).members[2].factionGroup,0)
 T.eq(reads,0,"list refresh does not query dungeon detail APIs")
 local scores=G:GetApplicantDungeonScores(member)
 T.eq(reads,2);T.eq(scores.current.level,18);T.eq(scores.current.timed,true);T.eq(scores.best.level,19);T.eq(scores.best.timed,false)
 T.eq(G:GetApplicantDungeonScores(member),scores);T.eq(reads,2,"reopening unchanged details reuses the snapshot")
 S.applicantMembers[8001][1].factionGroup=nil;G.Applicants:OnApplicantUpdated(8001)
 T.eq(member.factionGroup,nil,"missing native faction clears the previous marker")
 T.ok(G:GetApplicantDungeonScores(member)~=scores);T.eq(reads,4)
 C_LFGList.GetApplicantBestDungeonScore=function() return nil end
 C_LFGList.GetApplicantDungeonScoreForListing=function() return {bestRunLevel=0,mapName="Current dungeon"} end
 G.Applicants:OnApplicantUpdated(8001);scores=G:GetApplicantDungeonScores(member)
 T.eq(scores.best,nil);T.eq(scores.current,nil,"empty native results remain unavailable, not fabricated level zero")
 S.activeEntry.activityIDs={501};G.Listing:OnEntryUpdate();G:RefreshApplicants();T.eq(G:GetApplicantDungeonScores(member),nil,"non-key activities do not show Mythic+ summaries")
 G.Applicants:Clear();T.eq(G:GetApplicantDungeonScores(member),nil,"a retired member cannot query another applicant")
 C_LFGList.GetApplicantBestDungeonScore,C_LFGList.GetApplicantDungeonScoreForListing=best,current
 S.activeEntry,S.applicants,S.applicantMembers=entry,applicants,members;G.Listing:OnEntryUpdate()
end

-- Search relationships stay group-level even when local character identities
-- are complete. Name-only members still do not acquire guessed player keys.
do
 local view={};G:Attach(view,"search")
 S.social.bnet={{accountName="晴昼秋岚",accounts={
  {clientProgram="WoW",wowProjectID=1,isOnline=true,isInCurrentRegion=true,characterName="浅墨影",realmName="白银之手",playerGuid="Player-Shallow"},
 }}}
 S.results[8720]={activityIDs={501},name="H56",leaderName="Lauren-凤凰之神",numMembers=2,numBNetFriends=1,numCharFriends=0,numGuildMates=0}
 S.players[8720]={{name="Lauren",classFilename="DRUID",specName="恢复",isLeader=true},{name="浅墨影-白银之手",classFilename="ROGUE",specName="敏锐"}}
 S.friends[8720]={bnet={"晴昼秋岚"}}
 Fire("BN_FRIEND_INFO_CHANGED",1)
 G.Results:BeginSearch(23000);S.resultIDs={8720};G.Results:CommitResults(23000)
 local record=G:GetResult(8720);local details=G:GetResultDetails(8720)
 T.eq(record.bnetFriends,1,"the result summary knows that this group contains a Battle.net friend")
 T.eq(details.members[1].nameKey,"Lauren-凤凰之神","the native leader flag uses the full leader identity already supplied by the search result")
 T.eq(details.members[2].name,"浅墨影-白银之手","the full native name is preserved for the search tooltip")
 T.eq(details.members[2].nameKey,"浅墨影-白银之手");T.eq(details.members[2].isBNetFriend,nil,"even a known full character identity is not attributed a search relationship")
 T.same(details.relationships,{bnet={"晴昼秋岚"},character={},guild={}},"the native Battle.net name stays separate from the character roster")
 S.players[8720][2].name="浅墨影";G.Results:OnResultUpdated(8720);details=G:GetResultDetails(8720)
 T.eq(details.members[2].nameKey,nil,"name-only data does not acquire a guessed canonical identity")
 T.eq(details.members[2].isBNetFriend,nil,"name-only search data also has no member relationship attribution")
 T.eq(details.members[1].isBNetFriend,nil,"the leader has no search relationship attribution either")
 S.social.bnet[1].accounts[2]={clientProgram="WoW",wowProjectID=1,isOnline=true,isInCurrentRegion=true,characterName="浅墨影",realmName="燃烧之刃"}
 Fire("BN_FRIEND_INFO_CHANGED",1)
 T.eq(G:GetResultDetails(8720).members[2].isBNetFriend,nil,"local same-name relationships do not change search member data")
 S.social.bnet[1].accounts[2]=nil;Fire("BN_FRIEND_INFO_CHANGED",1)
 S.players[8720][2].name="浅墨影-无关服务器";G.Results:OnResultUpdated(8720)
 T.eq(G:GetResultDetails(8720).members[2].isBNetFriend,nil,"a different realm also leaves the search member unclassified")
 S.players[8720][2].name="浅墨影";S.players[8720][3]={name="浅墨影-白银之手",classFilename="ROGUE"};S.results[8720].numMembers=3
 G.Results:OnResultUpdated(8720);details=G:GetResultDetails(8720)
 T.eq(details.members[2].isBNetFriend,nil,"duplicate short names do not cause search member attribution")
 T.eq(details.members[3].isBNetFriend,nil,"a second fully named search member stays unclassified")
 S.players[8720][3]=nil;S.results[8720].numMembers=2;G.Results:OnResultUpdated(8720)
 T.eq(G:GetResultDetails(8720).members[2].isBNetFriend,nil,"a new member batch retains no relationship markers")
 local reads=S.playerReads;S.social.bnet={};Fire("BN_FRIEND_INFO_CHANGED",1)
 T.eq(G:GetResultDetails(8720).members[2].isBNetFriend,nil,"observer changes do not attribute cached search members")
 T.eq(S.playerReads,reads,"a relationship update reuses the existing native member snapshot")
 T.eq(G:GetResult(8720).bnetFriends,1,"native aggregate evidence is preserved independently of local indexes")
 T.eq(G:GetResultDetails(8720).relationships.bnet[1],"晴昼秋岚","the native name list remains available until the search result changes")
 S.social.bnet={};S.results[8720],S.players[8720],S.friends[8720]=nil,nil,nil;Fire("BN_FRIEND_INFO_CHANGED",1);G:Detach(view)
end

-- Relationships belong to the observer, including non-manager applicants.
do
 local entry,applicants,applicantMembers=S.activeEntry,S.applicants,S.applicantMembers
 S.activeEntry=nil;G.Listing:OnEntryUpdate()
 local friendRequests,guildRequests=S.friendRequests or 0,S.guildRequests or 0
 local view={};G:Attach(view,"search")
 T.eq(#Stubs.FramesWithEvent("BN_FRIEND_INFO_CHANGED"),0,"searching uses native relationship aggregates without local social listeners")
 local applications,status,pending=S.applications,S.appStatus,S.appPending
 S.applications={8703};S.appStatus={[8703]="applied"};S.appPending={}
 G.Applications:Restore();T.ok(G.Applications:IsActive(8703))
 G:Detach(view)
 T.eq(#Stubs.FramesWithEvent("BN_FRIEND_INFO_CHANGED"),0,"a background application does not own a local relationship subscription")
 T.eq(Stubs.FireEvent("FRIENDLIST_UPDATE"),0,"unused social changes cannot schedule background relationship work")
 T.eq(G.Relations.timer,nil)
 G:Attach(view,"search")
 T.eq(S.friendRequests or 0,friendRequests,"search and application transitions never request a character friend refresh")
 T.eq(S.guildRequests or 0,guildRequests,"search and application transitions never request a guild refresh")
 S.applications,S.appStatus,S.appPending=applications,status,pending;G.Applications:Restore()
 S.social.bnet={{displayName="浅墨影",accounts={
  {clientProgram="WoW",wowProjectID=1,isOnline=true,isInCurrentRegion=true,characterName="Other",realmName="Away"},
  {clientProgram="WoW",wowProjectID=1,isOnline=true,isInCurrentRegion=true,characterName="晴昼秋岚",realmName="燃烧之刃",playerGuid="Player-Bnet"},
  {clientProgram="WoW",wowProjectID=2,isOnline=true,isInCurrentRegion=true,characterName="Classic",realmName="Away"},
 }}}
 S.social.friends={{name="RoleFriend-Away",guid="Player-Friend"}}
 S.social.guildID=7;S.social.guild={{name="晴昼秋岚-燃烧之刃",guid="Player-Bnet"}}
 S.results[8701]={activityIDs={502},name="Observer friends",leaderName="Leader-Away",numMembers=3,numBNetFriends=0,numCharFriends=0,numGuildMates=0}
 S.players[8701]={
  {name="Leader-Away",classFilename="WARRIOR",isLeader=true},
  {name="晴昼秋岚-燃烧之刃",classFilename="PRIEST"},
  {name="浅墨影-Away",classFilename="MAGE"},
 }
 G.Results:BeginSearch(23001);S.resultIDs={8701};G.Results:CommitResults(23001)
 G.Search:SetFilters({friends=true})
 T.eq(table.concat(G:GetResults(),","),"","search relationship filters use native aggregate evidence without attributing local members")
 local record=G:GetResult(8701);local details=G:GetResultDetails(8701)
 T.eq(record.bnetFriends,0,"observer evidence does not rewrite native aggregate counts")
 T.eq(details.members[2].isBNetFriend,nil,"local Battle.net identities are not attached to search members")
 T.eq(details.members[2].isGuildMate,nil,"local guild identities are not attached to search members")
 T.eq(details.members[3].isBNetFriend,nil,"Battle.net nicknames never identify a search roster member")
 local reads=S.playerReads;G.Search:SetFilters({guild=true});T.eq(table.concat(G:GetResults(),","),"")
 T.eq(S.playerReads,reads,"relationship filters do not read native members")
 local createView={};G:Attach(createView,"create")
 T.eq(#Stubs.FramesWithEvent("BN_FRIEND_INFO_CHANGED"),1,"the current-roster view owns live observer relationships")
 T.eq(S.friendRequests,friendRequests+1);T.eq(S.guildRequests,guildRequests+1)
 local notifications=0;local unsub=G:Subscribe(function(kind) if kind=="relations" then notifications=notifications+1 end end)
 local sort,sorts=table.sort,0
 table.sort=function(values,compare) sorts=sorts+1;return sort(values,compare) end
 S.social.bnet[1].accounts={};S.social.guild={};Fire("BN_FRIEND_INFO_CHANGED",1);Fire("GUILD_ROSTER_UPDATE",true)
 T.eq(table.concat(G:GetResults(),","),"","local observer changes preserve native relationship filter results")
 T.eq(G:GetResultDetails(8701).members[2].isBNetFriend,nil);T.eq(details.members[2].isGuildMate,nil)
 T.eq(S.playerReads,reads,"observer changes do not reread unchanged native search members")
 T.eq(notifications,0);Stubs.AdvanceClock(0)
 T.eq(notifications,1,"a burst of relationship events produces one display notification")
 T.eq(sorts,0,"local relationship changes never invalidate the native search order")
 table.sort=sort
 S.social.bnet[1].accounts={{clientProgram="WoW",wowProjectID=1,isOnline=true,isInCurrentRegion=true,characterName="晴昼秋岚",realmName="燃烧之刃"}}
 Fire("BN_FRIEND_INFO_CHANGED",1)
 local leader,assistant,inGroup=_G.UnitIsGroupLeader,_G.UnitIsGroupAssistant,_G.IsInGroup
 _G.UnitIsGroupLeader=function() return false end;_G.UnitIsGroupAssistant=function() return false end
 _G.IsInGroup=function() return true end
 S.activeEntry={activityIDs={502}};G.Listing:OnEntryUpdate()
 G:Detach(createView)
 T.eq(#Stubs.FramesWithEvent("BN_FRIEND_INFO_CHANGED"),1,"an active listing retains observer relationships after the roster view closes")
 S.applicants={[8702]={applicationStatus="applied",numMembers=3,displayOrderID=1}}
 S.applicantMembers={[8702]={
  {name="晴昼秋岚",class="PRIEST"},
  {name="RoleFriend-Away",class="MAGE"},
  {name="Unknown-Away",class="WARRIOR",relationship="friend"},
 }}
 G:RefreshApplicants();local app=G:GetApplicant(8702)
 T.eq(app.members[1].isBNetFriend,true,"ordinary members get relationships relative to their own Battle.net friends")
 T.eq(app.members[2].isCharFriend,true)
 T.eq(app.members[3].isFriend,true,"native generic friendship remains usable without claiming Battle.net attribution")
 T.eq(app.members[3].isBNetFriend,false);T.eq(app.members[3].isCharFriend,false)
 local inviteCalls=#S.inviteCalls;T.eq(G:Invite(8702),false);T.eq(#S.inviteCalls,inviteCalls,"relationship display does not grant management permission")
 local applicantReads=S.applicantInfoReads
 S.social.bnet[1].accounts={};Fire("BN_FRIEND_INFO_CHANGED",1)
 T.eq(G:GetApplicant(8702).members[1].isBNetFriend,false,"cached name-only applicants lose a removed Battle.net relationship")
 S.social.friends={};Fire("FRIENDLIST_UPDATE")
 T.eq(G:GetApplicant(8702).members[2].isCharFriend,false,"cached applicants lose a removed local relationship")
 T.eq(S.applicantInfoReads,applicantReads,"relationship changes do not refetch applicant data")
 local bare={name="RoleFriend",guid="Player-Friend"};S.guidNames["Player-Friend"]={name="RoleFriend",realm="Away"}
 S.social.friends={{name="RoleFriend",guid="Player-Friend"}};Fire("FRIENDLIST_UPDATE")
 G.Relations:Apply(bare);T.eq(bare.isCharFriend,true,"a GUID resolves a native bare friend name to its complete realm identity")
 local sameName={nameKey="RoleFriend-Elsewhere"};G.Relations:Apply(sameName);T.eq(sameName.isCharFriend,false,"a matching bare name on another realm is unrelated")
 local indexed=S.socialReads;for i=1,20 do G.Relations:Apply(bare) end;T.eq(S.socialReads,indexed,"a stable observer index is shared by every member binding")
 local fallback={nameKey="Unlisted-Away",relationship="guild"};G.Relations:Apply(fallback);T.eq(fallback.isGuildMate,true,"native guild evidence remains a fallback")
 S.social.friends[#S.social.friends+1]={name="Unqualified-晨风号角"};Fire("FRIENDLIST_UPDATE")
 local incomplete={name="Unqualified",realm=""};G.Relations:Apply(incomplete)
 T.eq(incomplete.isCharFriend,false,"an empty remote realm does not guess a local character identity")
 G.Search:SetFilters({friends=true});T.eq(#G:GetResults(),0)
 S.results[8701].numBNetFriends=1;S.friends[8701]={bnet={"浅墨影"}}
 G.Results:OnResultUpdated(8701)
 T.eq(table.concat(G:GetResults(),","),"8701","unattributable native aggregate evidence remains valid for filtering")
 details=G:GetResultDetails(8701)
 T.eq(details.members[3].isBNetFriend,nil,"a native Battle.net display name cannot attribute a same-named unrelated character")
 local inRaid,partyCount=_G.IsInRaid,_G.GetNumSubgroupMembers
 _G.IsInRaid=function() return false end;_G.GetNumSubgroupMembers=function() return 1 end
 Stubs.SetUnit("party1",{name="RoleFriend",realm="Away",class="MAGE",guid="Player-Friend"})
 G:InvalidateRoster("group")
 local rosterFriend;for _,member in ipairs(G:GetRoster()) do if member.guid=="Player-Friend" then rosterFriend=member end end
 T.ok(rosterFriend and rosterFriend.isCharFriend,"the current roster consumes the same observer relationship index")
 S.social.guild[#S.social.guild+1]={name="本人-晨风号角",guid="P-0"};Fire("GUILD_ROSTER_UPDATE",true)
 local ownMember;for _,member in ipairs(G:GetRoster()) do if member.isSelf then ownMember=member;break end end
 T.ok(ownMember and ownMember.isSelf)
 T.eq(ownMember.isGuildMate,false,"the observer is not shown as their own guildmate")
 T.eq(ownMember.isBNetFriend,false);T.eq(ownMember.isCharFriend,false);T.eq(ownMember.isFriend,false)
 Stubs.SetUnit("party1",nil);_G.IsInRaid,_G.GetNumSubgroupMembers=inRaid,partyCount
 local social=S.social;S.social={friends={},bnet={},guild={}}
 Fire("FRIENDLIST_UPDATE");S.results[8701].numBNetFriends=0
 G.Results:BeginSearch(23002);G.Results:CommitResults(23002)
 local emptyReads=S.playerReads
 G.Search:SetFilters({friends=true});T.eq(#G:GetResults(),0)
 T.eq(S.playerReads,emptyReads,"zero native aggregate counts never fetch members to infer a relationship")
 S.social=social
 unsub();_G.UnitIsGroupLeader,_G.UnitIsGroupAssistant,_G.IsInGroup=leader,assistant,inGroup
 S.activeEntry=nil;G.Listing:OnEntryUpdate();G.Applicants:Clear();G:Detach(view)
 T.eq(#Stubs.FramesWithEvent("BN_FRIEND_INFO_CHANGED"),0,"the final consumer releases relationship events")
 T.eq(next(G.Relations.names),nil);T.eq(next(G.Relations.guids),nil);T.eq(next(G.Relations.shortNames),nil,"inactive indexes do not retain former friend records or short names")
 T.eq(G.Relations.timer,nil,"the final consumer cancels a queued relationship repaint")
 G.Relations:Apply({guid="Player-Friend"});T.ok(next(G.Relations.guids),"a one-off hidden reader can obtain current relationships")
 Stubs.AdvanceClock(0);T.eq(next(G.Relations.guids),nil);T.eq(G.Relations.timer,nil,"a one-off hidden read releases its index after that frame")
 S.social={friends={},bnet={},guild={}};S.guidNames={};S.results[8701],S.players[8701],S.friends[8701]=nil,nil,nil
 S.activeEntry,S.applicants,S.applicantMembers=entry,applicants,applicantMembers;G.Listing:OnEntryUpdate()
end

-- The search-only note policy does not narrow joined-roster reminders. Use the
-- production reminder owner and native roster events with a local note lookup.
do
 local previousNotes,previousLocale,reminders=A.Notes,A.NotesLocale,A.db.reminders
 Load.addon("LycheeGroup_Notes","Locale.lua")
 local noteRecords={
  ["团长乙-晨风号角"]={name="团长乙",server="晨风号角",reason="队长记录",type="positive"},
  ["治疗者-银松森林"]={name="治疗者",server="银松森林",reason="同行记录",type="caution"},
 }
 A.Notes={L=A.NotesLocale,Records={Find=function(key) return noteRecords[key] end}}
 Load.addon("LycheeGroup_Notes","RosterReminder.lua")
 local reminder=A.Notes.RosterReminder
 local chatBefore=#Stubs.ChatMessages()
 A.db.reminders="all";reminder.Start()
 Stubs.SetUnit("party1",{name="团长乙",realm="晨风号角",class="WARRIOR",classID=1,guid="Reminder-Leader"})
 Stubs.SetUnit("party2",{name="治疗者",realm="银松森林",class="PRIEST",classID=5,guid="Reminder-Member"})
 Stubs.FireEvent("GROUP_JOINED")
 T.eq(#Stubs.ChatMessages()-chatBefore,2,"入队后核对全队记录，普通队员不受寻队队长范围限制")
 local messages=table.concat(Stubs.ChatMessages(),"\n")
 T.ok(messages:find("团长乙-晨风号角",1,true));T.ok(messages:find("治疗者-银松森林",1,true))
 T.ok(messages:find("同行记录",1,true),"非队长的提醒仍包含其真实记录理由")
 G:InvalidateRoster("group")
 local joinedMember
 for _,member in ipairs(G:GetRoster()) do if member.nameKey=="治疗者-银松森林" then joinedMember=member end end
 T.ok(joinedMember,"已入队名单保留非队长完整身份供笔记和详情读取")
 Stubs.FireEvent("GROUP_ROSTER_UPDATE")
 T.eq(#Stubs.ChatMessages()-chatBefore,2,"重复队伍事件不重复播报")
 reminder.Stop();A.db.reminders="positive";reminder.Start()
 T.eq(#Stubs.ChatMessages()-chatBefore,3,"入队后的全队核对仍遵循原有提醒类型设置")
 T.ok(Stubs.ChatMessages()[#Stubs.ChatMessages()]:find("团长乙-晨风号角",1,true))
 reminder.Stop();Stubs.SetUnit("party1",nil);Stubs.SetUnit("party2",nil);G:InvalidateRoster("group")
 A.Notes,A.NotesLocale,A.db.reminders=previousNotes,previousLocale,reminders
end

_G.LycheeGroupDB = nil
_G.LycheeGroupGroupDB = nil
_G.LycheeGroupCharacterDB = nil
_G.LycheeGroup = nil
_G.C_LFGList = nil
_G.C_ChallengeMode = nil
