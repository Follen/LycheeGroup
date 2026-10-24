local fixture=dofile("tests/ui_fixture.lua")
local f=fixture("zhCN")
local A,U,G,S=f.A,f.U,f.G,f.S
-- Header toggling starts from an explicitly unsorted table, independent of presets.
A.Configuration:Set({["layout.tables.findResults.sortKey"]=false,["layout.tables.findResults.descending"]=false},{storage="character"})
A:SetSetting("reduceMotion",true);A:Open("find")
local page=U.pages.find
local function Left(region) local point={region:GetPoint()};return point[#point-1] or 0 end
T.eq(Left(page.context),16,"the dungeon heading keeps the shared sixteen-unit content inset")
T.eq(Left(page.context),Left(page.searchIcon),"the dungeon heading aligns with the search icon")
T.eq(Left(page.context),Left(page.resultsHeader.labels.title),"the group header shares the content inset")
T.eq(Left(page.context),Left(page.results.rows[1].title),"the result title shares the left content inset")
T.ok(page.results.rows[1].icon:IsShown(),"result rows retain their activity artwork in the independent activity column")
T.eq(page.results.rows[1].icon:GetWidth(),24);T.eq(page.results.rows[1].icon:GetHeight(),24)
T.near(Left(page.results.rows[1].icon),page.resultsHeader.columns.activity.x+4,.001)
T.eq(Left(page.resultsHeader.labels.activity),34,"the activity heading shares the text inset after the icon")
local activity=G.Catalog:GetActivity(2)
local values={{9,90,300,100},{80,300,1200,9},{12,12,20,80},{5,150,nil,30},{90,400,1400,1}}
for id,v in ipairs(values) do
 G.records[id]={id=id,name="Column group "..id,leaderName="Leader"..id.."-Away",leaderKey="Leader"..id.."-Away",
  activity=activity,activityID=2,activityName=activity.name,categoryID=2,maxNumPlayers=40,partyGUID="party-"..id,
  numMembers=v[1],requiredItemLevel=v[2],leaderRating=v[3],age=v[4],
  details={members={},counts={TANK=1,HEALER=1,DAMAGER=v[1]-2}}}
end
G.declinedParties["party-5"]=1
page:CommitChoice();page:DoSearch()
local function Click(header,key)
 for _,button in ipairs(header.buttons) do if button:IsShown() and button.definition.key==key then button:Fire("OnClick","LeftButton");return end end
 error("no header "..key)
end
local header=page.resultsHeader
Click(header,"members");T.same(page.results.ids,{4,1,3,2,5},"member counts sort numerically, with declined groups in their existing bottom bucket")
Click(header,"members");T.same(page.results.ids,{2,3,1,4,5})
Click(header,"ilvl");T.same(page.results.ids,{3,1,4,2,5})
Click(header,"ilvl");T.same(page.results.ids,{2,4,1,3,5})
Click(header,"rating");T.same(page.results.ids,{3,1,2,4,5},"unknown score stays after known values")
Click(header,"rating");T.same(page.results.ids,{2,1,3,4,5},"unknown score stays last in descending order too")
Click(header,"age");T.same(page.results.ids,{2,4,3,1,5})
Click(header,"age");T.same(page.results.ids,{1,3,4,2,5})
local raw=G:GetResults();T.same(raw,{1,2,3,4,5},"header sorting leaves the result service's array unchanged")
G.records[4].age=80;page:RefreshResults();T.same(page.results.ids,{1,3,4,2,5},"equal values use stable result IDs")
local savedSort=U:GetTablePrefs("findResults");T.eq(savedSort.sortKey,"age");T.eq(savedSort.descending,true)

local oldMouse=IsMouseButtonDown;local pressed=false
IsMouseButtonDown=function(button) return pressed and button=="LeftButton" end
local function Begin(h,index)
 S.cursorX=400;pressed=true;h.handles[index]:Fire("OnMouseDown","LeftButton")
end
local function Move(h,delta)
 S.cursorX=400+delta*h:GetEffectiveScale();h:Fire("OnUpdate",.016)
end
local function Release(h)
 pressed=false;h:Fire("OnUpdate",.016)
end
local cell=header.columns.title;local initial=cell.width
local adjacent=header.columns.activity;local adjacentWidth=adjacent.width
T.eq(header.definitions[1].key,"title");T.eq(header.definitions[2].key,"activity");T.eq(header.definitions[3].key,"leader")
local oldIds=table.concat(page.results.ids,",")
local reads=0;local getDetails=G.Results.GetDetails
local initialWidths=savedSort.widths
local initialWidthValues=initialWidths and {}
for key,value in pairs(initialWidths or {}) do initialWidthValues[key]=value end
G.Results.GetDetails=function(...) reads=reads+1;return getDetails(...) end
header.mouseOver=true;header:Fire("OnEnter");T.ok(header.handles[1].line:IsShown())
local delta=math.min(24,adjacentWidth-adjacent.minimum)
T.ok(delta>0,"the adjacent activity cell has room for a bounded resize")
Begin(header,1);Move(header,delta)
T.near(cell.width,initial+delta,.001);T.near(adjacent.width,adjacentWidth-delta,.001)
T.eq(reads,0,"dragging only changes geometry, without retrieving row details")
T.eq(savedSort.widths,initialWidths,"drag samples do not replace the saved width preferences")
T.same(savedSort.widths,initialWidthValues,"drag samples do not mutate any saved width value")
T.eq(table.concat(page.results.ids,","),oldIds,"resizing does not reorder data")
T.near(page.results.rows[1].title:GetWidth(),cell.width-20,.001)
T.near(page.results.rows[1].tooltipArea:GetWidth(),cell.width,.001,"title tooltip hit area follows its resized column")
Release(header);T.ok(savedSort.widths);T.eq(header:GetScript("OnUpdate"),nil)
local ratios=savedSort.widths;local savedWidth=cell.width
Begin(header,1);Move(header,1000)
T.ok(adjacent.width>=adjacent.minimum-.001)
U:Hide(true);pressed=false
T.eq(header.drag,nil);T.eq(header:GetScript("OnUpdate"),nil);T.eq(savedSort.widths,ratios)
A:Open("find");T.near(header.columns.title.width,savedWidth,.001,"close cancels the unfinished drag and reopens saved widths")
U:SetWindowSize(U.windowWidth+180,U.windowHeight)
T.near(header.columns.title.width/header:GetWidth(),ratios.title,.001,"saved column proportions follow a wider window")
local before=#S.nodes
Begin(header,1);Move(header,-12);Release(header)
T.eq(#S.nodes,before,"repeated drag reuses header and row objects")
header.mouseOver=false;header:Fire("OnLeave");T.ok(not header.handles[1].line:IsShown())
G.Results.GetDetails=getDetails

-- The compact pinned applications have the same resize/sort behavior.
G.apps={
 {id=1,name="First",leaderName="Leader1-Away",categoryID=2,status="applied",expiresAt=200,result=G.records[1]},
 {id=2,name="Second",leaderName="Leader2-Away",categoryID=2,status="applied",expiresAt=90,result=G.records[2]},
 {id=3,name="Third",leaderName="Leader3-Away",categoryID=2,status="invited",result=G.records[3]},
}
page:RefreshApplications()
local apps=page.applicationHeader
T.ok(apps:IsShown())
T.eq(apps.definitions[1].key,"title");T.eq(apps.definitions[2].key,"activity");T.eq(apps.definitions[3].key,"leader")
T.eq(page.appList.rows[1].meta:GetText(),activity.name,"outgoing applications preserve the complete native activity name independently from the group title")
Click(apps,"members");T.same(page.appList.ids,{1,3,2})
Click(apps,"members");T.same(page.appList.ids,{2,3,1})
Click(apps,"status");T.same(page.appList.ids,{2,1,3})
Click(apps,"status");T.same(page.appList.ids,{1,2,3},"applications without a numeric timer remain last")
local w=apps.columns.title.width
Begin(apps,1);Move(apps,15);Release(apps)
T.near(apps.columns.title.width,w+15,.001)
T.near(page.appList.rows[1].title:GetWidth(),apps.columns.title.width-6,.001)
T.eq(Left(page.appList.rows[1].title),0,"application titles start at their list's shared sixteen-unit page inset")
T.ok(page.appList.rows[1].icon:IsShown(),"compact applications retain their activity artwork")
T.eq(page.appList.rows[1].icon:GetWidth(),24);T.eq(page.appList.rows[1].icon:GetHeight(),24)
T.near(Left(page.appList.rows[1].icon),apps.columns.activity.x+6,.001)
T.near(Left(page.appList.rows[1].meta),apps.columns.activity.x+36,.001)
T.eq(Left(apps.labels.activity),36,"the application activity heading starts beside the row text after the icon")
T.near(page.appList.rows[1].tooltipArea:GetWidth(),apps.columns.title.width,.001)
G.apps={};page:RefreshApplications();T.ok(not apps:IsShown())

-- Raid progress is a separate layout with numeric encounter counts, not score.
local getProgress=G.Results.GetProgressCount;local countReads=0
G.Results.GetProgressCount=function(_,record) countReads=countReads+1;return record.testProgress end
G.records[1].testProgress=2;G.records[2].testProgress=10;G.records[3].testProgress=1
page.raidResultColumns=true;page:LayoutResultColumns()
local raidPrefs=header.state;T.ok(raidPrefs~=savedSort)
header:SetSort("rating",false)
T.same(page:SortResultIDs({1,2,3,4}),{3,1,2,4})
header:SetSort("rating",true)
T.same(page:SortResultIDs({1,2,3,4}),{2,1,3,4})
T.eq(countReads,8,"each sort reads one numeric progress value per result")
T.ok(header.columns.description.x<header.columns.rating.x,"raid progress follows the description")
page.raidResultColumns=false;page:LayoutResultColumns()
T.eq(header.state,savedSort);T.ok(header.columns.rating.x<header.columns.description.x)
G.Results.GetProgressCount=getProgress

-- Preview cannot overwrite the character's persisted table state.
local liveWidths=savedSort.widths
U.preview={provider={prefs={}}}
local previewPrefs=U:GetTablePrefs("findResults");T.ok(previewPrefs~=savedSort)
header:SetState(previewPrefs);header:Layout(header:GetWidth())
Begin(header,1);Move(header,18);Release(header);header:SetSort("members",false)
T.eq(savedSort.widths,liveWidths);T.eq(savedSort.sortKey,"age")
U.preview=nil;header:SetState(savedSort)

-- Font and window scale changes keep all cells and numeric values in bounds.
for _,locale in ipairs({"zhCN","enUS"}) do
 local nextF=fixture(locale);A,U,G,S=nextF.A,nextF.U,nextF.G,nextF.S
 A:SetSetting("reduceMotion",true);A:Open("find");page=U.pages.find
 for _,scale in ipairs({70,100,130}) do
  A:SetSetting("fontScale",scale)
  for _,h in ipairs({page.resultsHeader,page.applicationHeader}) do
   local right=0
   for _,def in ipairs(h.definitions) do
    local col=h.columns[def.key]
    T.near(col.x,right,.001);T.ok(col.width>0)
    right=right+col.width
   end
   T.near(right,h:GetWidth(),.001)
   T.ok(h.columns.activity and h.columns.activity.x>=h.columns.title.x+h.columns.title.width-.001,"activity has its own positive-width cell at every supported font scale")
   T.eq(h:GetScript("OnUpdate"),nil)
  end
  T.near(page.resultsHeader:GetWidth(),page.main:GetWidth(),.001,"the result header spans the complete main panel")
  T.near(page.results:GetWidth(),page.main:GetWidth()+14,.001,"the result scrollbar gutter stays outside the row width")
  T.near(page.results.rows[1]:GetWidth(),page.main:GetWidth(),.001,"result backgrounds reach the main panel's right edge")
  T.near(page.applicationHeader:GetWidth(),page.main:GetWidth()-32,.001)
  T.near(page.appList:GetWidth(),page.main:GetWidth()-32+14,.001,"application gutter does not subtract a second time from row width")
  T.near(page.appList.rows[1]:GetWidth(),page.main:GetWidth()-32,.001)
 end
end

-- Old saved proportions have no activity key. Split only the old title's
-- weight between title/activity, retaining the other values and sort.
do
 local oldResult={title=.3,leader=.14,members=.16,ilvl=.08,rating=.1,description=.13,age=.09}
 local oldApplication={title=.4,leader=.2,members=.16,status=.14,actions=.1}
 local preferences={tableLayouts={}}
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local widths={};for key,value in pairs(id=="findApplications" and oldApplication or oldResult) do widths[key]=value end
  preferences.tableLayouts[id]={widths=widths,sortKey="members",descending=true}
 end
 local legacy=fixture("enUS",preferences);A,U,G,S=legacy.A,legacy.U,legacy.G,legacy.S
 IsMouseButtonDown=function(button) return pressed and button=="LeftButton" end
 A:SetSetting("reduceMotion",true);A:Open("find");page=U.pages.find
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local h
  if id=="findApplications" then h=page.applicationHeader else page.raidResultColumns=id=="findRaidResults";page:LayoutResultColumns();h=page.resultsHeader end
  local prefs=U:GetTablePrefs(id);local old=id=="findApplications" and oldApplication or oldResult
  T.eq(h.state,prefs);T.eq(prefs.sortKey,"members");T.eq(prefs.descending,true)
  T.near(prefs.widths.title,old.title*.45,.000001,"the compact title keeps forty-five percent of the old combined title/activity weight")
  T.near(prefs.widths.activity,old.title*.55,.000001,"the activity column receives the remaining old combined weight")
  for key,value in pairs(old) do if key~="title" then T.eq(prefs.widths[key],value,"adding the activity column preserves every other saved weight") end end
  local right=0
  for _,def in ipairs(h.definitions) do
   local c=h.columns[def.key];T.near(c.x,right,.001);T.ok(c.width>0);right=right+c.width
  end
  T.near(right,h:GetWidth(),.001);T.ok(h.columns.activity.width>0,"legacy widths still produce an independent activity column")
  Begin(h,1);Move(h,-4);Release(h)
  T.ok(prefs.widths.activity and prefs.widths.activity>0,"the next completed drag saves the new column with the existing columns")
  T.eq(prefs.sortKey,"members");T.eq(prefs.descending,true)
 end
 local reopened=fixture("enUS",A.charPrefs,A.db);A,U,G,S=reopened.A,reopened.U,reopened.G,reopened.S
 A:SetSetting("reduceMotion",true);A:Open("find");page=U.pages.find
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local prefs=U:GetTablePrefs(id)
  T.ok(prefs.widths.activity and prefs.widths.activity>0,"the new activity proportion survives a real fixture reload")
  T.eq(prefs.sortKey,"members");T.eq(prefs.descending,true)
 end
end

-- Public single-column writes and partial presets use current column keys.
-- An omitted activity column keeps its own default, independently of title.
for _,storage in ipairs({"session","character","account"}) do
 for _,kind in ipairs({"user","preset"}) do
  local current=fixture("enUS");local a,c=current.A,current.A.Configuration
  for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
   local prefix="layout.tables."..id..".widths."
   local activity=c:Get(prefix.."activity")
   local defaults=a.Appearance:GetTableState(id).widths
   local untouched={};for key,value in pairs(defaults) do untouched[key]=value end
   if kind=="user" then T.ok(c:Set({[prefix.."title"]=.4},{storage=storage}))
   else T.ok(c:ApplyPreset("partial-title",1,{[prefix.."title"]=.4},{storage=storage})) end
   local widths=a.Appearance:GetTableState(id).widths
   T.eq(c:Get(prefix.."title"),.4)
   T.eq(widths.title,.4,storage.." "..kind.." title writes retain their current-column meaning")
   T.eq(widths.activity,activity,"an omitted activity width keeps its own default")
   T.eq(c:GetSource(prefix.."activity").kind,"default")
   local captured=c.legacy.character.tableLayouts
   T.eq(captured and captured[id],nil,"new API values do not become captured legacy layouts")
   if storage=="character" and kind=="user" then
    T.eq(a.charPrefs.tableLayouts[id].widths.title,.4,"the compatibility mirror records the explicit current-column value")
    T.eq(a.charPrefs.tableLayouts[id].widths.activity,nil,"the compatibility mirror does not invent an activity choice")
   end
   for key,value in pairs(untouched) do if key~="title" then T.eq(widths[key],value,"a single title value leaves every other column unchanged") end end
  end
  local reloaded=fixture("enUS",a.charPrefs,a.db)
  for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
   local prefix="layout.tables."..id..".widths."
   local nextC=reloaded.A.Configuration
   -- Replacing the same partial preset above leaves only the final table in it.
   local saved=storage~="session" and (kind=="user" or id=="findApplications")
   T.eq(nextC:Get(prefix.."title"),saved and .4 or nextC:GetSchema(prefix.."title")[prefix.."title"].default)
   local widths=reloaded.A.Appearance:GetTableState(id).widths
   T.eq(widths.title,nextC:Get(prefix.."title"),"a compatibility mirror is not split again on reload")
   T.eq(widths.activity,nextC:Get(prefix.."activity"))
   T.eq(nextC:GetSource(prefix.."activity").kind,"default")
  end
 end
end

-- A current saved title can have an older/incomplete activity import marker.
-- Its compatibility mirror is still a current column, not an old combined one.
for _,schema in ipairs({1,2}) do
 local current=fixture("enUS");local a,c=current.A,current.A.Configuration
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local prefix="layout.tables."..id..".widths."
  T.ok(c:Set({[prefix.."title"]=.4},{storage="character"}))
  a.charPrefs.uiConfig.imported[prefix.."activity"]=nil
 end
 a.charPrefs.uiConfig.schema=schema
 local reloaded=fixture("enUS",a.charPrefs,a.db)
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local prefix="layout.tables."..id..".widths."
  local nextC=reloaded.A.Configuration;local widths=reloaded.A.Appearance:GetTableState(id).widths
  T.eq(widths.title,.4)
  T.eq(nextC:GetSource(prefix.."activity").kind,"default","an incomplete marker does not turn a current mirror into old layout data")
  T.eq(widths.activity,nextC:GetSchema(prefix.."activity")[prefix.."activity"].default)
 end
end

-- Captured with the real 23bbdb2 fixture startup from raw title=.4:
-- display=.18/.22; canonical title=.4, activity=default; both imported=true;
-- raw title=.4 and no activity. A current character Set(title=.4) persists the
-- same leaves. Interpret both by canonical values instead of guessing history.
do
 local released={uiConfig={schema=2,user={},presets={},imported={}},tableLayouts={}}
 local modern=fixture("enUS");local c=modern.A.Configuration
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local prefix="layout.tables."..id..".widths."
  released.uiConfig.user[prefix.."title"]=.4
  released.uiConfig.imported[prefix.."title"],released.uiConfig.imported[prefix.."activity"]=true,true
  released.tableLayouts[id]={widths={title=.4}}
  T.ok(c:Set({[prefix.."title"]=.4},{storage="character"}))
  for _,leaf in ipairs({"title","activity"}) do
   T.eq(modern.A.charPrefs.uiConfig.user[prefix..leaf],released.uiConfig.user[prefix..leaf])
   T.eq(modern.A.charPrefs.uiConfig.imported[prefix..leaf],released.uiConfig.imported[prefix..leaf])
   T.eq(modern.A.charPrefs.tableLayouts[id].widths[leaf],released.tableLayouts[id].widths[leaf])
  end
 end
 local upgraded=fixture("enUS",released)
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local prefix="layout.tables."..id..".widths."
  local nextC=upgraded.A.Configuration;local widths=upgraded.A.Appearance:GetTableState(id).widths
  T.eq(widths.title,.4,"already imported 1.2.4 values use their canonical single-column meaning")
  T.eq(widths.title,nextC:Get(prefix.."title"))
  T.eq(nextC:GetSource(prefix.."activity").kind,"default")
  T.eq(widths.activity,nextC:Get(prefix.."activity"))
 end
end

-- Schema 1/2 do not change layout storage priority. Raw tableLayouts belong to
-- characters; account canonical values remain lower priority than a real old
-- character import. Already independent legacy title/activity pairs stay exact.
for _,schema in ipairs({1,2}) do
 for _,independent in ipairs({false,true}) do
  local function Namespace() return {schema=schema,user={},presets={},imported={}} end
  local account={uiConfig=Namespace(),tableLayouts={}}
  local character={uiConfig=Namespace(),tableLayouts={}}
  for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
   local prefix="layout.tables."..id..".widths."
   account.tableLayouts[id]={widths={title=.8}}
   account.uiConfig.user[prefix.."title"]=.7
   character.tableLayouts[id]={widths={title=.4,activity=independent and .2 or nil}}
  end
  local old=fixture("enUS",character,account)
  for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
   local prefix="layout.tables."..id..".widths."
   local c=old.A.Configuration;local widths=old.A.Appearance:GetTableState(id).widths
   T.near(widths.title,independent and .4 or .18,.000001)
   T.near(widths.activity,independent and .2 or .22,.000001)
   T.eq(c:GetSource(prefix.."title").storage,"character")
   T.eq(account.uiConfig.user[prefix.."title"],.7)
  end
 end
 local account={uiConfig={schema=schema,user={},presets={},imported={}},tableLayouts={findResults={widths={title=.8}}}}
 local current=fixture("enUS",{},account);local c=current.A.Configuration
 T.eq(c:GetSource("layout.tables.findResults.widths.title").kind,"default","account raw layouts do not become character preferences")
 T.eq(current.A.Appearance:GetTableState("findResults").widths.title,c:Get("layout.tables.findResults.widths.title"))
end

-- Convert only old raw tableLayouts, once, into canonical independent values.
-- Keeping the original snapshot separate from the compatibility mirror avoids
-- treating later public writes as another migration input.
do
 local preferences={tableLayouts={}}
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  preferences.tableLayouts[id]={widths={title=.4,leader=.2},sortKey="members",descending=true}
 end
 local old=fixture("enUS",preferences)
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local prefix="layout.tables."..id..".widths."
  local c=old.A.Configuration;local widths=old.A.Appearance:GetTableState(id).widths
  T.near(c:Get(prefix.."title"),.18,.000001);T.near(c:Get(prefix.."activity"),.22,.000001)
  T.eq(widths.title,c:Get(prefix.."title"));T.eq(widths.activity,c:Get(prefix.."activity"))
  T.eq(c:Get(prefix.."leader"),.2)
  T.eq(c.legacy.character.tableLayouts[id].widths.title,.4,"the captured legacy value remains the original combined width")
  T.eq(preferences.tableLayouts[id].widths.title,.4,"import leaves the old compatibility data intact until an explicit write")
  T.eq(preferences.tableLayouts[id].widths.activity,nil)
  T.ok(c:Set({[prefix.."title"]=.5},{storage="character"}))
  T.eq(preferences.tableLayouts[id].widths.title,.5)
  T.eq(c.legacy.character.tableLayouts[id].widths.title,.4,"compatibility writes do not change the startup snapshot")
 end
 local reloaded=fixture("enUS",old.A.charPrefs,old.A.db)
 for _,id in ipairs({"findResults","findRaidResults","findApplications"}) do
  local prefix="layout.tables."..id..".widths."
  local c=reloaded.A.Configuration;local widths=reloaded.A.Appearance:GetTableState(id).widths
  T.eq(widths.title,.5);T.eq(c:Get(prefix.."title"),.5)
  T.near(widths.activity,.22,.000001,"migrated activity is not recomputed from a later title write")
  T.eq(widths.activity,c:Get(prefix.."activity"))
 end
end

-- Exercise the real Catalog and page route, including native categories that
-- the small default fixture does not advertise. Keep API records internally
-- consistent instead of replacing Catalog's grouping or matching methods.
do
 local routed=fixture("enUS");local a,u,g=routed.A,routed.U,routed.G
 local oldJournalDifficulty,oldJournalInstance,oldJournalEncounter=EJ_GetDifficulty,EJ_SelectInstance,EJ_GetEncounterInfoByIndex
 EJ_GetDifficulty=function() return 14 end;EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
 local native=C_LFGList
 local oldInfo,oldCategories,oldCategoryInfo=native.GetActivityInfoTable,native.GetAvailableCategories,native.GetLfgCategoryInfo
 local oldActivities,oldGroups,oldGroupName,oldFullName=native.GetAvailableActivities,native.GetAvailableActivityGroups,native.GetActivityGroupInfo,native.GetActivityFullName
 local specs={
  {id=1,name="Quests",capacity=5},{id=4,name="Arenas",capacity=3,pvp=true},
  {id=6,name="Custom",capacity=40},{id=7,name="Arena skirmishes",capacity=3,pvp=true},
  {id=8,name="Battlegrounds",capacity=10,pvp=true},{id=9,name="Rated battlegrounds",capacity=10,pvp=true,rated=true},
  {id=111,name="Other activities",capacity=5},{id=121,name="Delves",capacity=5,mapID=2933},
 }
 local extra,byCategory,groupNames={},{},{}
 for _,spec in ipairs(specs) do
  local id,group=10000+spec.id,20000+spec.id
  extra[id]={id=id,categoryID=spec.id,fullName=spec.name.." activity",shortName=spec.name,groupFinderActivityGroupID=group,
   maxNumPlayers=spec.capacity,difficultyID=0,orderIndex=1,mapID=spec.mapID,isPvpActivity=spec.pvp,isRatedPvpActivity=spec.rated,allowCrossFaction=true}
  byCategory[spec.id]=extra[id];groupNames[group]=spec.name
 end
 native.GetAvailableCategories=function() return {1,2,3,4,6,7,8,9,111,121} end
 native.GetLfgCategoryInfo=function(id)
  local activity=byCategory[id]
  if activity then return {name=activity.shortName,allowCrossFaction=true} end
  return oldCategoryInfo(id)
 end
 native.GetActivityInfoTable=function(id) return extra[id] or oldInfo(id) end
 native.GetAvailableActivities=function(category,...)
  local activity=byCategory[category]
  return activity and {activity.id} or oldActivities(category,...)
 end
 native.GetAvailableActivityGroups=function(category,...)
  local activity=byCategory[category]
  return activity and {activity.groupFinderActivityGroupID} or oldGroups(category,...)
 end
 native.GetActivityGroupInfo=function(id) return groupNames[id] or oldGroupName(id) end
 native.GetActivityFullName=function(id) return extra[id] and extra[id].fullName or oldFullName(id) end
 g.Catalog:Invalidate();a:SetSetting("reduceMotion",true);a:Open("find")
 local p=u.pages.find;local resultObject,applicationObject
 for index,category in ipairs(g.Catalog:GetCategories()) do
  local current=g.Catalog:GetActivities(category.key)[1];T.ok(current,"every advertised fixture category has a real native activity")
  local function Record(id)
   return {id=id,name=category.key.." group",activity=current,activityID=current.id,activityName=current.name,categoryID=category.id,
    leaderName="Leader-Home",leaderKey="Leader-Home",numMembers=1,maxNumPlayers=current.maxNumPlayers,age=10,
    details={members={{name="Leader-Home",nameKey="Leader-Home",class="WARRIOR",specID=71,assignedRole="TANK",isLeader=true}},counts={TANK=1,HEALER=0,DAMAGER=0}}}
  end
  local id=5000+index;g.records={[id]=Record(id)}
  local applied=Record(6000+index)
  g.apps={{id=applied.id,name="Applied "..category.key,categoryID=category.id,status="applied",expiresAt=GetTime()+100,result=applied}}
  p:SelectCategory(category.key)
  if current.difficultyID and current.difficultyID>0 then
   for _,button in ipairs(p.difficultyButtons) do if button:IsShown() and button.value==current.difficultyID then button:Fire("OnClick","LeftButton");break end end
  end
  p:CommitChoice();p:DoSearch()
  T.eq(g.filters.category,category.key);T.eq(g:GetSearchState(),"done")
  local row,app=p.results.rows[1],p.appList.rows[1]
  T.eq(row.key,id);T.eq(app.key,applied.id)
  if resultObject then T.eq(row,resultObject);T.eq(app,applicationObject,"switching categories reuses decorated application rows") end
  resultObject,applicationObject=row,app
  for _,entry in ipairs({{row,p.resultsHeader,p.results},{app,p.applicationHeader,p.appList}}) do
   local item,h,list=entry[1],entry[2],entry[3]
   T.eq(h.definitions[1].key,"title");T.eq(h.definitions[2].key,"activity");T.eq(h.definitions[3].key,"leader")
   T.eq(item.meta:GetText(),current.name,"the activity column preserves the current activity's complete native name")
   local iconInset=entry[1]==row and 4 or 6
   local textInset=iconInset+30
   T.ok(item.icon:IsShown());T.eq(item.icon:GetWidth(),24);T.eq(item.icon:GetHeight(),24)
   T.near(Left(item.icon),h.columns.activity.x+iconInset,.001)
   T.near(Left(item.meta),h.columns.activity.x+textInset,.001)
   T.eq(Left(h.labels.activity),textInset,"each activity header aligns with its independent activity text")
   T.ok(Left(item.meta)>=h.columns.activity.x and Left(item.meta)+item.meta:GetWidth()<=h.columns.activity.x+h.columns.activity.width+.001)
   T.ok(not item.membersExpanded and not item.count:IsShown() and item.roster:IsShown(),"reusing a row drops the previous category's expanded total")
   local height,viewport=list.rowHeight,list:GetHeight()
   item.membersButton:Fire("OnClick","LeftButton")
   if current.maxNumPlayers==5 then
    T.ok(item.isParty and not item.count:IsShown() and item.roster:IsShown(),"five-player categories retain their avatar roster when clicked")
    T.ok(item.roster.slots[1].icon:IsShown(),"the real member avatar survives category reuse")
    T.eq(item.count:GetText(),"","a five-player row cannot inherit another category's total")
   else
    T.ok(item.membersExpanded and item.count:IsShown() and not item.roster:IsShown(),"larger or non-party categories replace roles with their total")
    T.eq(item.count:GetText(),"1/"..current.maxNumPlayers)
   end
   T.eq(list.rowHeight,height);T.eq(list:GetHeight(),viewport,"category member toggles never resize the list")
  end
 end
 native.GetActivityInfoTable,native.GetAvailableCategories,native.GetLfgCategoryInfo=oldInfo,oldCategories,oldCategoryInfo
 native.GetAvailableActivities,native.GetAvailableActivityGroups,native.GetActivityGroupInfo,native.GetActivityFullName=oldActivities,oldGroups,oldGroupName,oldFullName
 EJ_GetDifficulty,EJ_SelectInstance,EJ_GetEncounterInfoByIndex=oldJournalDifficulty,oldJournalInstance,oldJournalEncounter
 u:Hide(true)
end
-- Activity ordering follows the actual activity-menu group order, not names,
-- IDs, difficulty variants or the current numeric filter sort.
do
 local ordered=fixture("enUS",{defaultSort="members"});local a,u,g=ordered.A,ordered.U,ordered.G
 local journalDifficulty,journalInstance,journalEncounter=EJ_GetDifficulty,EJ_SelectInstance,EJ_GetEncounterInfoByIndex
 local native=C_LFGList;local getInfo,getActivities,getGroupName=native.GetActivityInfoTable,native.GetAvailableActivities,native.GetActivityGroupInfo
 local activities={
  [501]={id=501,categoryID=2,fullName="Zulu key",shortName="Zulu",groupFinderActivityGroupID=20,difficultyID=8,isMythicPlusActivity=true,orderIndex=1,maxNumPlayers=5},
  [502]={id=502,categoryID=2,fullName="Alpha heroic",shortName="Alpha",groupFinderActivityGroupID=10,difficultyID=2,orderIndex=2,maxNumPlayers=5},
  [503]={id=503,categoryID=2,fullName="Zulu normal",shortName="Zulu",groupFinderActivityGroupID=20,difficultyID=1,orderIndex=3,maxNumPlayers=5},
  [504]={id=504,categoryID=2,fullName="Middle normal",shortName="Middle",groupFinderActivityGroupID=30,difficultyID=1,orderIndex=4,maxNumPlayers=5},
 }
 native.GetActivityInfoTable=function(id) return activities[id] or getInfo(id) end
 native.GetAvailableActivities=function(category,...)
  if category==2 then return {504,503,502,501} end
  return getActivities(category,...)
 end
 native.GetActivityGroupInfo=function(id) return ({[20]="Zulu",[10]="Alpha",[30]="Middle"})[id] or getGroupName(id) end
 EJ_GetDifficulty=function() return 14 end;EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
 g.Catalog:Invalidate();a:SetSetting("reduceMotion",true);a:Open("find")
 local p=u.pages.find;local h=p.resultsHeader
 p:SelectCategory("seasonDungeon")
 local allDifficulties=false
 for _,button in ipairs(p.difficultyButtons) do
  if button:IsShown() and button.value==false then button:Fire("OnClick","LeftButton");allDifficulties=true;break end
 end
 T.ok(allDifficulties,"the rank test uses the real all-difficulties browse state for its mixed variants")
 local recordActivities={503,502,501,504,999,false,501,504,502,501,503}
 for id,activityID in ipairs(recordActivities) do
  local current=activityID and g.Catalog:GetActivity(activityID)
  g.records[id]={id=id,name="Activity group "..id,activityID=activityID or nil,activity=current,activityName=current and current.name or "Unknown activity",categoryID=2,
   leaderName="Leader"..id.."-Home",leaderKey="Leader"..id.."-Home",numMembers=id,requiredItemLevel=id,leaderRating=id,age=id,maxNumPlayers=40,partyGUID="Activity-sort-"..id,
   details={members={},counts={TANK=1,HEALER=0,DAMAGER=0}}}
 end
 g.records[8].charFriends=1;g.records[9].bnetFriends=1;g.records[10].guildMates=1;g.records[11].guildMates=4
 g.records[7].guildMates=1;g.declinedParties[g.records[7].partyGUID]=1
 p:CommitChoice();p:DoSearch();h:SetSort(nil,false,true);p:OnHeaderSort()
 local groups=g.Catalog:GetGroups("seasonDungeon")
 T.eq(groups[1].key,20);T.eq(groups[2].key,10);T.eq(groups[3].key,30)
 T.eq(#groups[1].variants,2,"the activity menu keeps both difficulty variants in the same group")
 local fallback=g:GetResults();local fallbackText=table.concat(fallback,",")
 local asc={10,11,9,8,1,3,2,4,5,6,7};local desc={8,9,10,11,4,2,1,3,5,6,7}
 T.eq(g.filters.sort,"members")
 Click(h,"activity")
 T.eq(h.state.sortKey,"activity");T.eq(h.state.descending,false);T.same(p.results.ids,asc,"activity ascending preserves relation and declined partitions, variant ties and unknown-last behavior")
 T.eq(g.filters.sort,"members","activity sorting does not replace the selected default numeric filter")
 T.eq(a.Configuration:Get("layout.tables.findResults.sortKey"),"activity","activity is an accepted persisted result sort preference")
 local ranks=p.activitySortRanks;local cachedGroups=p.activitySortGroups
 T.eq(ranks[501],1);T.eq(ranks[503],1,"all variants receive exactly their shared menu rank")
 T.eq(ranks[502],2);T.eq(ranks[504],3);T.eq(ranks[999],nil)
 p:RefreshResults();T.eq(p.activitySortRanks,ranks);T.eq(p.activitySortGroups,cachedGroups,"unchanged results reuse the current category's rank cache")
 Click(h,"activity");T.eq(h.state.descending,true);T.same(p.results.ids,desc,"activity descending reverses menu groups without reversing relations, declines or unknown-last behavior")
 Click(h,"activity");T.eq(h.state.sortKey,nil);T.same(p.results.ids,fallback,"the third click restores the provider's default order")
 T.eq(table.concat(g:GetResults(),","),fallbackText,"header sorting never mutates the provider's result sequence")
 T.eq(g.filters.sort,"members","the activity cycle's default state retains the user's filter sort")
 local appSort=p.applicationHeader.state.sortKey
 p.applicationHeader.buttons[2]:Fire("OnClick","LeftButton")
 T.eq(p.applicationHeader.state.sortKey,appSort,"the application activity header does not acquire result-only sorting")

 -- Every numeric header uses the same relationship partition in both orders.
 for _,key in ipairs({"members","ilvl","rating","age"}) do
  h:SetSort(nil,false);Click(h,key)
  T.same(p.results.ids,{8,9,10,11,1,2,3,4,5,6,7},"ascending numeric headers keep all relationship types together ahead of ordinary results")
  Click(h,key)
  T.same(p.results.ids,{11,10,9,8,6,5,4,3,2,1,7},"descending numeric headers keep relationship priority and place every declined result last")
 end
 Click(h,"activity");T.same(p.results.ids,asc)
 local searchCalls=0;local search=g.Search.Search
 g.Search.Search=function(self,...) searchCalls=searchCalls+1;return search(self,...) end
 g.records[5].bnetFriends=1;g:Notify("relations")
 T.same(p.results.ids,{10,11,9,8,5,1,3,2,4,6,7},"updated native relationship totals move an unknown activity into the relation partition without inventing its rank")
 T.eq(searchCalls,0,"relationship changes repaint and reorder without another search")
 g.records[5].bnetFriends=0;g:Notify("relations");T.same(p.results.ids,asc)

 activities[502].orderIndex=0;g.Catalog:Invalidate();g:Notify("activities")
 T.same(p.results.ids,{9,10,11,8,2,1,3,4,5,6,7},"catalog invalidation rebuilds activity ranks from the new menu order")
 T.ok(p.activitySortGroups~=cachedGroups);T.eq(p.activitySortRanks[502],1);T.eq(p.activitySortRanks[501],2);T.eq(p.activitySortRanks[503],2)
 local dungeonRecords=g.records;local raid=g.Catalog:GetActivity(1)
 g.records={[20]={id=20,name="Raid category",activity=raid,activityID=1,activityName=raid.name,categoryID=3,maxNumPlayers=30,numMembers=3,age=1}}
 p:SelectCategory("seasonRaid");p:CommitChoice();p:DoSearch();Click(h,"activity")
 T.eq(p.activitySortRanks[1],1);T.eq(p.activitySortRanks[501],nil,"switching categories drops the previous category's activity ranks")
 T.eq(p.activitySortGroups,g.Catalog:GetGroups("seasonRaid"));T.eq(a.Configuration:Get("layout.tables.findRaidResults.sortKey"),"activity")
 g.records=dungeonRecords;p:SelectCategory("seasonDungeon");p:CommitChoice();p:DoSearch()
 T.eq(h.state.sortKey,"activity","returning to the category restores its saved activity sort")
 T.eq(p.activitySortRanks[1],nil);T.eq(p.activitySortRanks[502],1)
 a:Open("notes")
 T.eq(p.activitySortGroups,nil);T.ok(not p.activitySortRanks or next(p.activitySortRanks)==nil,"leaving Find releases every cached activity rank")
 native.GetActivityInfoTable,native.GetAvailableActivities,native.GetActivityGroupInfo=getInfo,getActivities,getGroupName
 EJ_GetDifficulty,EJ_SelectInstance,EJ_GetEncounterInfoByIndex=journalDifficulty,journalInstance,journalEncounter
end
IsMouseButtonDown=oldMouse
