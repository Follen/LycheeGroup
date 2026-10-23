-- Real heroic raid results: normal activity selection, six native searches,
-- animated wheel reversals, group/member tips, then local filtering/sorting.
-- Natural GC throughout the workload; one diagnostic collection after closing.
local probe=...
local A=_G.LycheeGroup
if not A or not A.db then return probe:Fail("addon_not_ready") end
if A.UI and (A.UI:IsShown() or A.UI.hiding or A.UI.preview) then return probe:Fail("requires_closed_ui") end
if InCombatLockdown() or C_ChallengeMode.IsChallengeModeActive() or C_LFGList.HasActiveEntryInfo() or #C_LFGList.GetApplications()>0 then return probe:Fail("requires_idle_business") end
if LFGListFrame and LFGListFrame.EntryCreation then
 local entry=LFGListFrame.EntryCreation
 for _,box in ipairs({entry.Name,entry.Description.EditBox}) do
  local value=box:GetText()
  if issecretvalue and issecretvalue(value) or value~="" then return probe:Fail("native_creation_draft_present") end
 end
end
local packages={"LycheeGroup","LycheeGroup_Group","LycheeGroup_Notes","LycheeGroup_UI"}
local started=GetTime()
local version,build,_,interface=GetBuildInfo()
local report={schema="lycheegroup.heroic-memory.v1",packages=packages,units="KB",client={version=version,build=build,interface=interface},
 scenario={requestedRaid="烈毒之渊",difficultyID=15,nativeHeroicSearches=6,minimumSearchSpacingSeconds=8,
  scrollIntervalSeconds=.15,sampleIntervalSeconds=.5,gcPolicy="natural until closed_final; one separate diagnostic collection",
  input="normal page/list/tooltip controllers; no hardware hit-testing claim"},
 settings={reduceMotion=A:GetSetting("reduceMotion"),rememberFilters=A:GetSetting("rememberFilters"),raidMembers=A:GetSetting("raidMembers"),scriptProfile=GetCVar("scriptProfile")},
 samples={},queries={},peaks={},checks={},operations={wheel=0,reversals=0,scrollableTicks=0,groupTips=0,memberTips=0,tipWheel=0,filterSort=0},
 nativeEvents={bulk=0,result=0},maximum={results=0,filtered=0,scrollOffset=0,members=0},peakBytes=0}
for i=1,256 do
 local row={addonKB={},loaded={}}
 for packageIndex=1,#packages do row.addonKB[packageIndex],row.loaded[packageIndex]=0,false end
 report.samples[i]={addonKB=row.addonKB,loaded=row.loaded}
end
local used,ui,g,page,ticker,eventFrame,cleaned=0
local oldPage=A.UI and A.UI.page
local oldMain=A.UI and A.UI.mainPage
local config=A.API.Configuration
local oldRemember=config:Get("settings.rememberFilters")
local rememberSource=config:GetSource("settings.rememberFilters")
local oldShown,oldFilters={},{}
if A.UI then for key,p in pairs(A.UI.pages) do oldShown[key]=p.frame and p.frame:IsShown() or false end end
local oldPrefs,prefsSaved
local function Cleanup()
 if cleaned then return end;cleaned=true
 if ticker then ticker:Cancel();ticker=nil end
 if eventFrame then eventFrame:UnregisterAllEvents();eventFrame:SetScript("OnEvent",nil);eventFrame:Hide() end
 if ui then
  ui:Hide(true);ui.Motion:StopAll()
  if prefsSaved then g.Search:SetFilters(oldFilters);g.prefs.find=oldPrefs;page.loaded=nil;page.restoredInitial=nil end
  for key,p in pairs(ui.pages) do if p.frame then p.frame:SetShown(oldShown[key]==true) end end
  ui.page,ui.mainPage=oldPage,oldMain
 end
 if rememberSource.kind=="user" and rememberSource.storage=="session" then
  assert(config:Set({["settings.rememberFilters"]=oldRemember}))
 else assert(config:Reset("settings.rememberFilters")) end
end
assert(probe:Async(115));assert(probe:OnCleanup(Cleanup))
assert(probe:Guard(function() return not InCombatLockdown() and not C_ChallengeMode.IsChallengeModeActive() and not C_LFGList.HasActiveEntryInfo() and #C_LFGList.GetApplications()==0 end,
 {"PLAYER_REGEN_DISABLED","CHALLENGE_MODE_START","LFG_LIST_ACTIVE_ENTRY_UPDATE","LFG_LIST_APPLICATION_STATUS_UPDATED"},"scene_or_business_changed"))
local phase="startup"
local function Sample(tag,collected)
 used=used+1;local row=assert(report.samples[used],"sample_capacity")
 row.tag,row.phase,row.atSeconds=tag,phase,GetTime()-started
 row.gcMs=0
 if collected then local t=debugprofilestop();collectgarbage("collect");row.gcMs=debugprofilestop()-t end
 row.luaHeapKB=collectgarbage("count")
 local t=debugprofilestop();UpdateAddOnMemoryUsage();row.counterRefreshMs=debugprofilestop()-t
 local total=0
 for i,name in ipairs(packages) do
  local _,loaded=C_AddOns.IsAddOnLoaded(name);row.loaded[i]=loaded==true
  row.addonKB[i]=GetAddOnMemoryUsage(name);total=total+row.addonKB[i]
 end
 row.addonTotalKB=total;row.realResults=g and g:GetResultCount() or 0
 row.filteredResults=g and #g:GetResults() or 0;row.scrollOffset=page and page.results and page.results.pixelOffset or 0
 if not collected then
  report.peakBytes=math.max(report.peakBytes,total*1024)
  report.peaks[phase]=math.max(report.peaks[phase] or 0,total*1024)
 end
 return row
end
Sample("before_any_business_load")
local ok,why=A:Ensure("Group");if not ok then return probe:Fail("load_group_"..tostring(why)) end
g=A.Group;oldPrefs=g.prefs.find;prefsSaved=true
for key,value in pairs(g.Search:GetFilters()) do oldFilters[key]=value end
local target
for _,activity in ipairs(g.Catalog:GetActivities("seasonRaid")) do
 if activity.difficultyID==15 and activity.name:find("烈毒之渊",1,true) then target=activity;break end
end
if not target then return probe:Fail("heroic_raid_not_in_current_catalog") end
report.target={id=target.id,name=target.name,groupKey=target.groupKey,difficultyID=target.difficultyID,mapID=target.mapID,maxNumPlayers=target.maxNumPlayers}
for _,key in ipairs({"settings","notes","create"}) do
 local opened,err=A:Open(key);if not opened then return probe:Fail("warm_"..key.."_"..tostring(err)) end
 ui=A.UI;page=ui.pages.find;Sample("first_"..key);ui:Hide(true)
end
assert(config:Set({["settings.rememberFilters"]=true}))
g.prefs.find={category="seasonRaid",categoryPrefs={seasonRaid={difficultyID=15}}}
page.loaded=nil;page.restoredInitial=nil
local opened,err=A:Open("find");if not opened then return probe:Fail("open_find_"..tostring(err)) end
report.firstSearchGeneration=g.Search:GetGeneration()
local lastSearchAt=GetTime()
local round,completed,phaseAt,direction,nextWork,lastSample=0,0,GetTime(),-1,GetTime(),GetTime()
local originalFrame,originalPool=page.frame,#page.results.rows
local tipStep,filterStep=0,0
local sortNames={"newest","rating","itemLevel","members"}
local filters={category="seasonRaid",groupKey=target.groupKey,difficultyID=15,sort="newest"}
local function StartHeroic(first)
 round=round+1
 if first then
  page:RefreshPicker();page.picker:Show();page.activities:Select(target.groupKey,true)
  local selected=false
  for _,row in ipairs(page.activities.rows) do
   if row.key==target.groupKey then row:GetScript("OnClick")(row,"LeftButton");selected=true;break end
  end
  if not selected then return probe:Fail("heroic_activity_row_missing") end
 else page:DoSearch() end
 lastSearchAt=GetTime()
 local request=g.Search.request
 if not request or request.activityID~=target.id then return probe:Fail("wrong_native_activity") end
 report.queries[round]={generation=g.Search:GetGeneration(),activityID=request.activityID,startedAt=lastSearchAt-started}
 phase="scroll_refresh";Sample("heroic_search_started")
end
local function Scroll()
 local list=page.results;local ids=g:GetResults()
 local maximum=math.max(0,#ids*list.rowHeight-list:GetHeight())
 report.maximum.results=math.max(report.maximum.results,g:GetResultCount())
 report.maximum.filtered=math.max(report.maximum.filtered,#ids)
 report.maximum.scrollOffset=math.max(report.maximum.scrollOffset,list.pixelOffset)
 if maximum>0 then
  report.operations.scrollableTicks=report.operations.scrollableTicks+1
  local position=list.scrollTarget or list.pixelOffset
  if direction==-1 and position>=maximum-.5 or direction==1 and position<=.5 then direction=-direction;report.operations.reversals=report.operations.reversals+1 end
 end
 list:GetScript("OnMouseWheel")(list,direction);report.operations.wheel=report.operations.wheel+1
end
local function Tips()
 tipStep=tipStep+1
 local ids=g:GetResults();if #ids==0 then return end
 local row=page.results.rows[(math.floor((tipStep-1)/4)%#page.results.rows)+1]
 local record=row.key and g:GetResult(row.key)
 if not record then record=g:GetResult(ids[(math.floor((tipStep-1)/4)%#ids)+1]);row=page.results.rows[1] end
 local tip=ui.Tooltip
 if tipStep%4==1 then
  tip:Hide();tip:ShowGroup(row,record);tip.expanded=true;tip:RenderGroup()
  report.operations.groupTips=report.operations.groupTips+1
  report.maximum.members=math.max(report.maximum.members,#(tip.details and tip.details.members or {}))
 elseif tipStep%4==2 and tip.interactive and tip.record then
  local scroll=tip.interactive.scroll;scroll:GetScript("OnMouseWheel")(scroll,tipStep%8==2 and -5 or 5)
  report.operations.tipWheel=report.operations.tipWheel+1
 elseif tipStep%4==3 and tip.details and #tip.details.members>0 then
  tip:RenderPlayer(tip.details.members[(math.floor(tipStep/4)%#tip.details.members)+1],true,true)
  report.operations.memberTips=report.operations.memberTips+1
 else tip:Hide();Scroll() end
end
local function Finish()
 Cleanup();phase="closed";Sample("closed_final");report.retainedKB=Sample("closed_after_diagnostic_gc",true).addonTotalKB
 report.checks.correctActivity=completed==6
 report.checks.realScrollable=report.operations.scrollableTicks>0 and report.maximum.scrollOffset>0
 report.checks.pageAndPoolReused=page.frame==originalFrame and #page.results.rows==originalPool
 report.checks.knownOwnersIdle=not ui:IsShown() and not g:HasViews() and g:GetResultCount()==0 and not g.Results.updatePending
  and g.Game.frame:GetScript("OnUpdate")==nil and not g.Search.timer and not g.Search.pending and next(ui.Motion.jobs)==nil
 report.checks.allPackagesLoaded=true;for i=1,#packages do if not report.samples[used].loaded[i] then report.checks.allPackagesLoaded=false end end
 report.checks.under20MB=report.peakBytes<=20000000
 report.ok=report.checks.correctActivity and report.checks.realScrollable and report.checks.pageAndPoolReused and report.checks.knownOwnersIdle and report.checks.allPackagesLoaded and report.checks.under20MB
 report.elapsedSeconds,report.sampleCount=GetTime()-started,used
 for i=used+1,#report.samples do report.samples[i]=nil end
 return probe:Finish(report)
end
local function Tick()
 if probe:IsCancelled() then return end
 local now=GetTime()
 if now-started>110 then return probe:Fail("heroic_memory_deadline") end
 if g:GetSearchState()=="failed" then return probe:Fail("native_search_failed") end
 if now-lastSample>=.5 then Sample("periodic");lastSample=GetTime() end
 if phase=="startup" then
  if g:GetSearchState()=="done" and now-lastSearchAt>=8 then StartHeroic(true) end
 elseif phase=="scroll_refresh" then
  if g:GetSearchState()=="done" and completed<round then
   local query=report.queries[round]
   query.completedAt=now-started;query.results=g:GetResultCount();query.filtered=#g:GetResults();query.generationWhenDone=g.Search:GetGeneration()
   completed=round;Sample("heroic_search_complete")
  end
  if now>=nextWork and completed==round then Scroll();nextWork=GetTime()+.15 end
  if completed==round and now-lastSearchAt>=8 then
   if round<6 then StartHeroic(false) else phase="real_raid_tooltips";phaseAt=now;Sample("begin_tips") end
  end
 elseif phase=="real_raid_tooltips" then
  if now>=nextWork then Tips();nextWork=GetTime()+.15 end
  if now-phaseAt>=16 then ui.Tooltip:Hide();phase="real_filter_sort";phaseAt=now;Sample("begin_filter_sort") end
 elseif phase=="real_filter_sort" then
  if now>=nextWork then
   filterStep=filterStep+1;filters.sort=sortNames[(filterStep-1)%4+1];filters.maxMembers=filterStep%2==0 and 20 or nil
   g.Search:SetFilters(filters);Scroll();report.operations.filterSort=report.operations.filterSort+1;nextWork=GetTime()+.15
  end
  if now-phaseAt>=12 then Finish() end
 end
end
eventFrame=CreateFrame("Frame")
eventFrame:SetScript("OnEvent",assert(probe:Callback(function(_,event)
 if event=="PLAYER_LEAVING_WORLD" then return probe:Fail("world_changed") end
 if event=="LFG_LIST_UPDATE_SEARCH_RESULTS" then report.nativeEvents.bulk=report.nativeEvents.bulk+1
 elseif event=="LFG_LIST_SEARCH_RESULT_UPDATED" then report.nativeEvents.result=report.nativeEvents.result+1 end
end)))
for _,event in ipairs({"PLAYER_LEAVING_WORLD","LFG_LIST_UPDATE_SEARCH_RESULTS","LFG_LIST_SEARCH_RESULT_UPDATED"}) do eventFrame:RegisterEvent(event) end
ticker=C_Timer.NewTicker(.1,assert(probe:Callback(Tick)))
