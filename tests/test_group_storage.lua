-- Real Group initialization and the existing Notes/Find UI consume the same
-- recovered SavedVariables; these tests never connect to a game client.
local function Fixture(preferences,account,character,active)
 local f=dofile("tests/ui_fixture.lua")("enUS",preferences,{reduceMotion=true})
 local a=f.A
 _G.QueueStatusButton=nil
 _G.LibStub=function(name) if name=="LibSpecialization" then return {RegisterGroup=function() end,UnregisterGroup=function() end} end end
 C_LFGList.GetApplications=function() return {} end
 C_LFGList.GetActiveEntryInfo=function() return nil end
 C_LFGList.GetLanguageSearchFilter=function() return nil end
 C_LFGList.RequestAvailableActivities=function() end
 C_LFGList.Search=function() end
 C_ChallengeMode.IsChallengeModeActive=function() return active==true end
 C_ChallengeMode.GetActiveChallengeMapID=function() return active and 2 or nil end
 C_ChallengeMode.GetActiveKeystoneInfo=function() return nil end
 C_ChallengeMode.GetMapUIInfo=function(id) return "Actual dungeon",id,nil,nil end
 C_SpecializationInfo.GetInspectSpecialization=function() return 0 end
 Load.addon("LycheeGroup_Group","Group.lua")
 for _,file in ipairs({"Game.lua","Catalog.lua","Relations.lua","Roster.lua","Search.lua","Results.lua","Applications.lua","Listing.lua","Alerts.lua","Applicants.lua","History.lua"}) do Load.addon("LycheeGroup_Group",file) end
 local g=a.Group;f.G=g
 _G.LycheeGroupGroupDB=account
 if account==nil then _G.LycheeGroupGroupDB={} end
 _G.LycheeGroupCharacterDB=character
 if character==nil then _G.LycheeGroupCharacterDB={} end
 g:Initialize()
 return f
end
local function Count(source) local count=0;for _ in pairs(source or {}) do count=count+1 end;return count end
local function Member(name) return {name=name or "Recorded",realm="Home",class="MAGE",specID=nil} end
local function Run(id) return {id=id,mapChallengeModeID=2,mapName="Saved dungeon",members={Member()}} end

-- Bad containers do not prevent loading Group or reacquiring the actual run.
do
 local raw={runs=true,activeRun=true,storageRecovery=false}
 local f=Fixture(nil,nil,raw,true);local g=f.G
 T.eq(g.charDB,raw);T.eq(#g:GetHistory(),0)
 T.eq(raw.storageRecovery.previous.value,false)
 T.eq(raw.storageRecovery.runs.value,true);T.eq(raw.storageRecovery.activeRun.value,true)
 T.eq(g:GetActiveRun().mapChallengeModeID,2)
 T.eq(g:GetActiveRun().level,nil,"unknown native level stays unknown")
 local baseline=raw.activeRun;local recovery=raw.storageRecovery
 g:Initialize();T.eq(raw.activeRun,baseline);T.eq(raw.storageRecovery,recovery)
 T.eq(raw.storageRecovery.activeRun.previous,nil,"reinitialization does not quarantine the repaired run again")
 g.History:OnCompleted();T.eq(#g:GetHistory(),1);T.eq(raw.activeRun,nil)
 T.eq(g:GetHistory()[1].level,nil)
 g:Initialize();T.eq(#g:GetHistory(),1,"a completed recovered run survives another initialization")
end

do
 for _,invalid in ipairs({true,false,7}) do
  local f=Fixture(nil,invalid,invalid)
  T.eq(f.G.db.storageRecovery["$root"].value,invalid)
  T.eq(f.G.charDB.storageRecovery["$root"].value,invalid)
 end
 local runs={};for index=1,300 do runs[index]=Run("run-"..index) end
 local first,last=runs[1],runs[300];local f=Fixture(nil,nil,{runs=runs})
 T.eq(f.G.charDB.runs,runs);T.eq(#f.G:GetHistory(),300)
 T.eq(runs[1],first);T.eq(runs[300],last);T.eq(f.G.charDB.storageRecovery,nil)
end

-- Completed valid runs remain the same objects; damaged siblings move intact.
do
 local unknown,known=Run("unknown"),Run("known")
 unknown.mapChallengeModeID,unknown.mapName=nil,nil
 known.startedAt,known.completedAt,known.level=100,180,10
 local badMembers=Run("members");badMembers.members=true
 local badMember=Run("member");badMember.members={true}
 local badTime=Run("time");badTime.startedAt="yesterday"
 local badNumber=Run("number");badNumber.level=math.huge
 local badName=Run("name");badName.mapName={}
 local badSpec=Run("spec");badSpec.members[1].specID=false
 local badOrder={id="active",mapChallengeModeID=2,members={}}
 local runs={unknown,true,badMembers,badMember,badTime,badNumber,badName,badSpec,known}
 local raw={runs=runs,activeRun=badOrder}
 local f=Fixture(nil,nil,raw,true);local g,u,a=f.G,f.U,f.A
 T.eq(raw.runs,runs);T.eq(#runs,2);T.eq(runs[1],unknown);T.eq(runs[2],known)
 T.eq(runs[1].members[1].name,"Recorded");T.eq(runs[1].startedAt,nil);T.eq(runs[1].completedAt,nil);T.eq(runs[1].level,nil)
 T.eq(raw.storageRecovery["runs[number:2]"].value,true)
 T.eq(raw.storageRecovery["runs[number:3]"].value,badMembers)
 T.eq(raw.storageRecovery["runs[number:4]"].value,badMember)
 T.eq(raw.storageRecovery["runs[number:5]"].value,badTime)
 T.eq(raw.storageRecovery["runs[number:8]"].value,badSpec)
 T.eq(raw.storageRecovery.activeRun.value,badOrder);T.ok(raw.activeRun~=badOrder)
 local recoveredCount=Count(raw.storageRecovery);g:Initialize()
 T.eq(Count(raw.storageRecovery),recoveredCount);T.eq(raw.storageRecovery.activeRun.previous,nil)
 g.History:OnCompleted();T.eq(#g:GetHistory(),3)
 T.ok(a:Open("notes"));local notes=u.pages.notes;notes:SelectTab("history")
 T.eq(#notes.runs,3,"the real Notes history page reads every valid completed run")
 for _,sort in ipairs({"level","duration","completed"}) do notes.historyTableState.sortKey=sort;notes:RefreshHistory() end
 for _,run in ipairs(notes.runs) do
  notes:OpenRun(run);T.eq(notes.historyRun,run);notes.historyModal:Close()
 end
 u:Hide()
end

-- A valid active baseline keeps its exact object, prior members and unknowns.
do
 local member=Member();local baseline={id="valid-active",mapChallengeModeID=2,members={["Recorded-Home"]=member},order={"Recorded-Home"}}
 local raw={runs={},activeRun=baseline};local f=Fixture(nil,nil,raw,true);local g=f.G
 T.eq(raw.activeRun,baseline);T.eq(raw.activeRun.members["Recorded-Home"],member)
 T.eq(raw.activeRun.startedAt,nil);T.eq(raw.activeRun.level,nil);T.eq(raw.storageRecovery,nil)
 g:Initialize();T.eq(raw.activeRun,baseline);T.eq(raw.activeRun.members["Recorded-Home"],member)
 g.History:OnCompleted();T.eq(g:GetHistory()[1].members[1],member);T.eq(g:GetHistory()[1].startedAt,nil)
end

-- Nonfinite and unrepresentable numbers cannot reach arithmetic/date/native IDs.
do
 for _,update in ipairs({
  function(run) run.startedAt=0/0 end,
  function(run) run.completedAt=math.huge end,
  function(run) run.completedAt=1e308 end,
  function(run) run.mapChallengeModeID=1e308 end,
  function(run) run.members[1].specID=1e308 end,
 }) do
  local damaged=Run("bad-number");update(damaged)
  local good=Run("good");local raw={runs={damaged,good}}
  local f=Fixture(nil,nil,raw)
  T.eq(#f.G:GetHistory(),1);T.eq(f.G:GetHistory()[1],good)
  T.eq(raw.storageRecovery["runs[number:1]"].value,damaged)
 end
end

-- Every active member is valid and represented exactly once by the saved order.
do
 local key="Recorded-Home";local member=Member()
 for _,baseline in ipairs({
  {mapChallengeModeID=2,members=true,order={}},
  {mapChallengeModeID=2,members={[key]=true},order={key}},
  {mapChallengeModeID=2,members={[key]=member},order=true},
  {mapChallengeModeID=2,members={[key]=member},order={"Missing-Home"}},
  {mapChallengeModeID=2,members={[key]=member},order={key,key}},
  {mapChallengeModeID=2,members={[key]=member},order={}},
 }) do
  local retained=Run("retained");local raw={runs={retained},activeRun=baseline}
  local f=Fixture(nil,nil,raw,true);local g=f.G
  T.eq(raw.storageRecovery.activeRun.value,baseline);T.ok(raw.activeRun~=baseline)
  T.eq(g:GetHistory()[1],retained)
  g:Initialize();T.eq(raw.storageRecovery.activeRun.previous,nil)
  g.History:OnRosterUpdate();g.History:OnCompleted()
  T.eq(#g:GetHistory(),2);T.eq(g:GetHistory()[2],retained,"reacquisition never rewrites an unrelated completed run")
 end
end

-- Account seeds, per-character filters, roles, and blocked names are validated
-- at the same initialization boundary before the real Find page can read them.
do
 for _,account in ipairs({{prefs=true},{prefs={find=true}},{blockedLeaders=true}}) do
  local f=Fixture(nil,account)
  T.ok(f.A:Open("find"));T.eq(type(f.G.prefs.find),"table");T.eq(type(f.G.db.blockedLeaders),"table")
  T.ok(next(account.storageRecovery));f.U:Hide()
 end
 local malformed={
  {find=true},{find={filters=true}},{find={categoryPrefs=true}},
  {find={categoryPrefs={seasonDungeon=true}}},
  {find={categoryPrefs={seasonDungeon={groupKeys=true}}}},
 }
 for _,prefs in ipairs(malformed) do
  local f=Fixture(prefs);T.ok(f.A:Open("find"))
  local count=Count(prefs.uiConfigRecovery);T.ok(count>0)
  f.U:Hide();f.G:Initialize();T.eq(Count(prefs.uiConfigRecovery),count)
 end
end

do
 local groupKeys={[20]=true,[30]=false,broken={}}
 local category={groupKeys=groupKeys,minItemLevel=200,hideSameSpec=true,minRating="200"}
 local validCategory={selected=true,minMembers=2}
 local roles={TANK=true,HEALER=false,DAMAGER={},OTHER=true}
 local filters={minRating=true,maxRating={},minItemLevel="200",maxItemLevel=500,sort="rating"}
 local find={category="seasonDungeon",filters=filters,categoryPrefs={seasonDungeon=category,["3"]=validCategory}}
 local prefs={find=find,applicationRoles=roles}
 local blocked={ [7]=true,["Good-Home"]=true,["Broken-Home"]={},["False-Home"]=false }
 local account={blockedLeaders=blocked}
 local f=Fixture(prefs,account);local g=f.G
 T.eq(prefs.find,find);T.eq(find.filters,filters);T.eq(find.categoryPrefs.seasonDungeon,category)
 T.eq(find.categoryPrefs["3"],validCategory);T.eq(category.groupKeys,groupKeys)
 T.eq(groupKeys[20],true);T.eq(groupKeys[30],false);T.eq(groupKeys.broken,nil)
 T.eq(category.minItemLevel,200);T.eq(category.minRating,nil);T.eq(filters.maxItemLevel,500)
 T.eq(filters.minRating,nil);T.eq(filters.maxRating,nil);T.eq(filters.minItemLevel,nil)
 T.eq(prefs.applicationRoles,nil,"obsolete role preferences are removed instead of repaired")
 T.eq(g.db.blockedLeaders,blocked);T.same(g.Results:GetBlockedLeaders(),{"Good-Home"})
 T.eq(account.storageRecovery["blockedLeaders[number:7]"].value,true)
 T.eq(account.storageRecovery["blockedLeaders[string:False-Home]"].value,false)
 local count=Count(prefs.uiConfigRecovery);local blockCount=Count(account.storageRecovery)
 g:Initialize();T.eq(Count(prefs.uiConfigRecovery),count);T.eq(Count(account.storageRecovery),blockCount)
 T.ok(f.A:Open("find"));T.ok(g.Results:MatchesNumericFilters({requiredItemLevel=250,leaderRating=1000,numMembers=3},g.Search:GetFilters()))
 T.ok(g.Results:BlockTitle("Blocked title","Second-Home"));T.same(g.Results:GetBlockedLeaders(),{"Good-Home","Second-Home"})
 T.ok(f.A:Open("settings",{section="blocks"}));local settings=f.U.pages.settings
 T.eq(#settings.blocksList.ids,2,"the real blocked-leader page displays the valid saved names")
 settings.blocksList.clip.mouseOver=true
 for _,row in ipairs(settings.blocksList.rows) do if row.key=="Good-Home" then row.remove:Fire("OnClick","LeftButton");break end end
 T.same(g.Results:GetBlockedLeaders(),{"Second-Home"})
 settings.blocksClear:Fire("OnClick","LeftButton");T.eq(#g.Results:GetBlockedLeaders(),0)
 T.eq(#settings.blocksList.ids,0,"clear-all refreshes the actual blocked-name list")
 f.U:Hide()
end

for _,key in ipairs({"minRating","maxRating","minItemLevel","maxItemLevel","minMembers","maxMembers"}) do
 for _,bad in ipairs({true,"200",{},0/0,math.huge}) do
  local choice={[key]=bad,selected=true};local prefs={find={categoryPrefs={seasonDungeon=choice}}}
  local f=Fixture(prefs)
  T.eq(choice[key],nil);T.eq(choice.selected,true)
  local retained=prefs.uiConfigRecovery["find.categoryPrefs[string:seasonDungeon]."..key].value
  if type(bad)=="number" and bad~=bad then T.ok(retained~=retained) else T.eq(retained,bad) end
  T.ok(f.A:Open("find"));f.U:Hide()
 end
end

-- Valid persisted controls keep the UI's numeric limits and legacy aliases.
do
 local choice={selected=true,groupKeys={[20]=true},difficultyID=8,tier=1,minRating=200,maxRating=99999,minItemLevel=0,maxItemLevel=99999,minMembers=1,maxMembers=40,neededRole=false,tankPresence="present",healerPresence="missing",roleMatchAny=false,hideSameSpec=false,sort="members",social="caution"}
 local prefs={find={category="seasonDungeon",categoryPrefs={seasonDungeon=choice}}}
 local f=Fixture(prefs);T.eq(prefs.uiConfigRecovery,nil)
 T.eq(prefs.find.categoryPrefs.seasonDungeon,choice);T.eq(choice.maxMembers,40);T.eq(choice.maxRating,99999);T.eq(choice.minItemLevel,0)
 T.ok(f.A:Open("find"));local filters=f.G.Search:GetFilters()
 T.eq(filters.minRating,200);T.eq(filters.maxRating,99999);T.eq(filters.minItemLevel,0);T.eq(filters.maxItemLevel,99999)
 T.eq(filters.minMembers,1);T.eq(filters.maxMembers,5,"the existing category-specific UI capacity clamp remains authoritative")
 T.eq(prefs.uiConfigRecovery,nil);f.U:Hide()
end

-- Catalog-created expansion IDs are persisted unchanged by Find. The EJ fixture
-- has no matching expansion names, so this exercises the real fallback IDs.
do
 local oldTen,oldEleven=EXPANSION_NAME10,EXPANSION_NAME11
 EXPANSION_NAME10,EXPANSION_NAME11="Expansion Ten","Expansion Eleven"
 local f=Fixture();local g=f.G
 g.Catalog:Invalidate()
 local generated={}
 for _,tier in ipairs(g.Catalog:GetTiers()) do if type(tier.id)=="string" then generated[#generated+1]=tier.id end end
 T.eq(#generated,2,"both expansions need the Catalog's generated fallback IDs")
 local accountChoice={tier=generated[1],selected=true}
 local characterChoice={tier=generated[2],selected=true}
 g.db.prefs.find.filters.tier=generated[1]
 g.db.prefs.find.categoryPrefs["121"]=accountChoice
 g.prefs.find.filters.tier=generated[2]
 g.prefs.find.categoryPrefs["121"]=characterChoice
 g:Initialize()
 T.eq(g.db.prefs.find.filters.tier,generated[1],"the legacy account filter preserves the actual Catalog tier")
 T.eq(g.db.prefs.find.categoryPrefs["121"],accountChoice);T.eq(accountChoice.tier,generated[1])
 T.eq(g.prefs.find.filters.tier,generated[2],"the character filter preserves the actual Catalog tier")
 T.eq(g.prefs.find.categoryPrefs["121"],characterChoice);T.eq(characterChoice.tier,generated[2])
 T.eq(g.db.storageRecovery,nil);T.eq(g.prefs.uiConfigRecovery,nil)
 g:Initialize();T.eq(accountChoice.tier,generated[1]);T.eq(characterChoice.tier,generated[2])
 for _,valid in ipairs({false,0,1,2}) do
  characterChoice.tier=valid;g:Initialize();T.eq(characterChoice.tier,valid)
 end
 for _,invalid in ipairs({true,"exp12","exp10broken","10",{},math.huge,0/0,-1,1.5}) do
  characterChoice.tier=invalid;g:Initialize();T.eq(characterChoice.tier,nil)
  local retained=g.prefs.uiConfigRecovery["find.categoryPrefs[string:121].tier"].value
  if type(invalid)=="number" and invalid~=invalid then T.ok(retained~=retained) else T.eq(retained,invalid) end
 end
 EXPANSION_NAME10,EXPANSION_NAME11=oldTen,oldEleven
end

-- Obsolete role values are removed regardless of their former representation.
for _,roles in ipairs({false,{},true,{HEALER=true}}) do
 local prefs={applicationRoles=roles};local f=Fixture(prefs)
 T.eq(prefs.applicationRoles,nil);T.eq(prefs.uiConfigRecovery,nil)
 T.ok(f.A:Open("find"));f.U:Hide()
end
