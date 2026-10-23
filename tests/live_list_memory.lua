-- LycheeDev bounded real-list measurement; execute only through the owning driver.
-- Closed UI; existing applications remain active. Exactly one native search. No requests inside workload rounds,
-- no injected Blizzard API, no applications/listing edits, no GC-policy changes.
local probe=...
local A=_G.LycheeGroup
if not A or not A.db then return probe:Fail("lycheegroup_not_ready") end
if InCombatLockdown() then return probe:Fail("combat_active") end
if A.UI and (A.UI:IsShown() or A.UI.hiding or A.UI.preview) then return probe:Fail("close_ui_and_preview_before_test") end
if A.Group and A.Group.Search:GetState()=="searching" then return probe:Fail("search_already_running") end
if C_ChallengeMode.IsChallengeModeActive() then return probe:Fail("challenge_active") end
local observerStartHeap=collectgarbage("count")
local PACKAGES={"LycheeGroup","LycheeGroup_Group","LycheeGroup_Notes","LycheeGroup_UI"}
local LIMIT,STEPS,RETAINED_STEPS,INTERVAL=115,1024,256,.10
local BATCH,SAMPLE_EVERY,SAMPLE_CAPACITY=16,4,336
local started=GetTime()
local version,build,date,interface=GetBuildInfo()
local report={schema="lycheegroup.list-memory.v2",units="KB",packages=PACKAGES,
 client={version=version,build=build,date=date,interface=interface},
 scenario={nativeSearches=1,naturalSteps=STEPS,retainedSteps=RETAINED_STEPS,
  tickIntervalSeconds=INTERVAL,operationsPerTick=BATCH,sampleEveryOperations=SAMPLE_EVERY,timeoutSeconds=LIMIT,
  operations={"native_bulk_event","eight_native_result_events","local_filter_sort","refresh_scroll"},
  gcPolicy="natural phase first; first explicit collection follows all natural steps; collect only, never stop/restart GC",
  nativeObjects="known product UI roots; Frame/region/animation counts, no engine-byte attribution"},
 settings={reduceMotion=A:GetSetting("reduceMotion"),noteMarks=A:GetSetting("noteMarks"),scriptProfile=GetCVar("scriptProfile")},
 observer={preallocatedSamples=SAMPLE_CAPACITY,periodicDrivers=1,wrappedCallbacks=2},
 samples={},checks={},summary={naturalPeakKB=0,naturalHeapPeakKB=0,sampledUncollectedPeakKB=0,retainedWorkloadPeakKB=0},
 operations={},frameCounts={}}
for i=1,SAMPLE_CAPACITY do
 local sample={addonKB={},loaded={}}
 for packageIndex=1,#PACKAGES do sample.addonKB[packageIndex],sample.loaded[packageIndex]=0,false end
 report.samples[i]={addonKB=sample.addonKB,loaded=sample.loaded,
 tag="",phase="",step=0,atSeconds=0,gcMs=0,luaHeapKB=0,counterRefreshMs=0,addonTotalKB=0,
 luaHeapAfterRefreshKB=0,realResults=0,filteredResults=0,visiblePool=0,scrollOffset=0}
end
report.initialNativeApplications=#C_LFGList.GetApplications()
report.initialActiveListing=C_LFGList.HasActiveEntryInfo()
for i=1,4 do report.operations[i]={calls=0,inclusiveMs=0,maxInclusiveMs=0,heapNetKB=0,recordsUpdated=0} end
local sampleCount=0
local ui,page,g,ticker,eventFrame,expectedGeneration,originalFilters
local oldPage=A.UI and A.UI.page
local oldMain=A.UI and A.UI.mainPage
local savedPrefs
local oldPageShown={}
if A.UI then for key,p in pairs(A.UI.pages) do oldPageShown[key]=p.frame and p.frame:IsShown() or false end end
local closed=false
local function Cleanup()
 if closed then return end
 closed=true
 if ticker then ticker:Cancel();ticker=nil end
 if eventFrame then eventFrame:UnregisterAllEvents();eventFrame:SetScript("OnEvent",nil);eventFrame:Hide() end
 if ui then
  ui:Hide(true);ui.Motion:StopAll()
  if originalFilters then g.Search:SetFilters(originalFilters) end
  if savedPrefs then g.prefs.find=savedPrefs.value;page.loaded=nil;page.restoredInitial=nil end
  for key,p in pairs(ui.pages) do if p.frame then p.frame:SetShown(oldPageShown[key]==true) end end
  ui.page,ui.mainPage=oldPage,oldMain
 end
end
assert(probe:Async(LIMIT))
assert(probe:OnCleanup(Cleanup))
assert(probe:Guard(function() return not InCombatLockdown() and not C_ChallengeMode.IsChallengeModeActive() end,{"PLAYER_REGEN_DISABLED","CHALLENGE_MODE_START"},"combat_or_challenge_started"))
local function Sample(tag,phase,step,collect)
 sampleCount=sampleCount+1
 local row=assert(report.samples[sampleCount],"sample_capacity")
 row.tag,row.phase,row.step,row.atSeconds=tag,phase,step,GetTime()-started
 row.gcMs=0
 if collect then local at=debugprofilestop();collectgarbage("collect");row.gcMs=debugprofilestop()-at end
 row.luaHeapKB=collectgarbage("count")
 local at=debugprofilestop();UpdateAddOnMemoryUsage();row.counterRefreshMs=debugprofilestop()-at
 local total=0
 for i,name in ipairs(PACKAGES) do
  local _,loaded=C_AddOns.IsAddOnLoaded(name);row.loaded[i]=loaded==true
  row.addonKB[i]=GetAddOnMemoryUsage(name);total=total+row.addonKB[i]
 end
 row.addonTotalKB=total
 row.luaHeapAfterRefreshKB=collectgarbage("count")
 row.realResults=g and g:GetResultCount() or 0
 row.filteredResults=g and #g:GetResults() or 0
 row.visiblePool=page and #page.results.rows or 0
 row.scrollOffset=page and page.results.pixelOffset or 0
 if not collect then report.summary.sampledUncollectedPeakKB=math.max(report.summary.sampledUncollectedPeakKB,total) end
 if phase=="retained" and not collect then report.summary.retainedWorkloadPeakKB=math.max(report.summary.retainedWorkloadPeakKB,total) end
 if phase=="natural" and not collect then
  report.summary.naturalPeakKB=math.max(report.summary.naturalPeakKB,total)
  report.summary.naturalHeapPeakKB=math.max(report.summary.naturalHeapPeakKB,row.luaHeapKB)
 end
 return sampleCount
end
-- Traverse only owned roots, deduplicating shared children. The same scratch
-- set is cleared between the two structural observations.
local visited,warmRegions={},{}
local function ObjectCounts()
 wipe(visited)
 local counts={frames=0,regions=0,animationGroups=0,truncated=false}
 local function Visit(root,depth,path)
  if not root or visited[root] then return end
  if depth>32 or counts.frames>=6000 then counts.truncated=true;return end
  visited[root]=true;counts.frames=counts.frames+1
  local regions=select("#",root:GetRegions())
  counts.regions=counts.regions+regions
  if not report.frameCounts.warm then warmRegions[root]=regions
  elseif warmRegions[root]~=regions then
   counts.regionChanges=counts.regionChanges or {}
   counts.regionChanges[#counts.regionChanges+1]={name=root:GetName() or path,before=warmRegions[root] or 0,after=regions}
  end
  counts.animationGroups=counts.animationGroups+select("#",root:GetAnimationGroups())
  for i=1,select("#",root:GetChildren()) do Visit(select(i,root:GetChildren()),depth+1,path.."/"..i) end
 end
 Visit(ui.frame,0,"main");Visit(ui.Tooltip.frame,0,"tooltip");Visit(ui.Tooltip.interactive,0,"interactiveTooltip")
 local menu=ui.context.menu
 Visit(menu,0,"menu");Visit(menu and menu.catcher,0,"menuCatcher")
 if A.Floating then Visit(A.Floating.frame,0,"floating") end
 wipe(visited)
 return counts
end
local function ClosedOwners()
 local m=ui.Motion
 local jobs=0;for _ in pairs(m.jobs) do jobs=jobs+1 end
 local state={uiShown=ui:IsShown(),uiHiding=ui.hiding==true,motionJobs=jobs,
  motionOnUpdate=m.driver:GetScript("OnUpdate")~=nil,searchViews=g:HasViews("search"),allGroupViews=g:HasViews(),
  results=g:GetResultCount(),searchState=g:GetSearchState(),
  nativeBorrowed=ui.Native.owner~=nil or ui.Native.searchLease~=nil,
  pendingSearch=g.Search.pending~=nil,searchTimer=g.Search.timer~=nil,
  resultUpdatePending=g.Results.updatePending==true,resultOnUpdate=g.Game.frame:GetScript("OnUpdate")~=nil}
 state.knownOwnersIdle=not state.uiShown and not state.uiHiding and jobs==0 and not state.motionOnUpdate
  and not state.searchViews and state.results==0 and state.searchState=="idle" and not state.nativeBorrowed
  and not state.pendingSearch and not state.searchTimer and not state.resultUpdatePending and not state.resultOnUpdate
 return state
end
local ids,filters={},{}
local sortNames={"newest","rating","itemLevel","members"}
local phase,step,updateCursor,cycles="wait_search",0,1,0
local lastCount,stableAt,nextAt=-1,0,GetTime()
local baselineGC,finalGC
Sample("before_warm","natural",0,false)
-- Warm all business packages and normal pages before the list workload.
-- Creation only borrows inputs when no draft or live listing would be disturbed.
if C_LFGList.HasActiveEntryInfo() or #C_LFGList.GetApplications()>0 then return probe:Fail("warmup_requires_idle_group_business") end
if LFGListFrame and LFGListFrame.EntryCreation then
 local entry=LFGListFrame.EntryCreation
 for _,box in ipairs({entry.Name,entry.Description.EditBox}) do
  local value=box:GetText()
  if issecretvalue and issecretvalue(value) or value~="" then return probe:Fail("native_creation_draft_present") end
 end
end
for _,key in ipairs({"settings","notes","create"}) do
 local opened,why=A:Open(key);if not opened then return probe:Fail("warm_"..key.."_"..tostring(why)) end
 ui,g=A.UI,A.Group
 Sample("warm_"..key,"natural",0,false);ui:Hide(true)
end
g=A.Group;page=ui.pages.find
savedPrefs={value=g.prefs.find}
g.prefs.find={category="seasonDungeon"}
page.loaded=nil;page.restoredInitial=nil
local generationBefore=A.Group and A.Group.Search:GetGeneration() or 0
local ok,err=A:Open("find")
if not ok then return probe:Fail("open_find_failed_"..tostring(err)) end
ui,g,page=A.UI,A.Group,A.UI.pages.find
-- The fixture starts without a confirmed activity. Confirm the category's
-- all-activities choice before issuing the only native search.
page:CommitChoice();page:DoSearch()
expectedGeneration=g.Search:GetGeneration()
report.category=g.Search.categoryKey
report.generationAtOpen,report.generationBeforeOpen=expectedGeneration,generationBefore
if g.Search:GetState()=="failed" then return probe:Fail("native_search_failed") end
local function BeginWorkload()
 for key,value in pairs(g.Search:GetFilters()) do originalFilters[key]=value end
 filters.category=g.Search.categoryKey;filters.sort="newest"
 g.Search:SetFilters(filters)
 local current=g:GetResults();for i,id in ipairs(current) do ids[i]=id end
 report.initialRealResults=g:GetResultCount();report.initialFilteredResults=#current
 report.initialBoundResults=#page.results.ids
 assert(report.initialRealResults>0,"real_results_empty")
 assert(report.initialBoundResults==#current and page.results.rows[1].key and not page.emptyPanel:IsShown(),"real_results_not_bound")
 local _,nativeIDs=C_LFGList.GetFilteredSearchResults();report.initialNativeFilteredResults=#(nativeIDs or {})
 -- Visit the existing pool at different rows once, accounting for lazy native
 -- text/texture resources before checking steady-state reuse.
 for index=0,#current,page.results.capacity do page.results:SetPixelOffset(index*page.results.rowHeight,false) end
 page.results:SetPixelOffset(0,false)
 report.frameCounts.warm=ObjectCounts()
 report.resultPoolAtStart=#page.results.rows
 report.initialDetailCount=0
 for _,id in ipairs(ids) do local r=g:GetResult(id);if r and r.details then report.initialDetailCount=report.initialDetailCount+1 end end
 Sample("stable_real_list","natural",0,false)
 phase,step="natural",0
end
originalFilters={}
local function Work()
 step=step+1
 local operation=(step-1)%4+1
 local stat=report.operations[operation]
 local heap,at=collectgarbage("count"),debugprofilestop()
 if operation==1 then
  g:OnEvent("LFG_LIST_UPDATE_SEARCH_RESULTS")
 elseif operation==2 then
  for i=1,math.min(8,#ids) do
   local id=ids[updateCursor];updateCursor=updateCursor%#ids+1
   if g:GetResult(id) then g:OnEvent("LFG_LIST_SEARCH_RESULT_UPDATED",id);stat.recordsUpdated=stat.recordsUpdated+1 end
  end
 elseif operation==3 then
  cycles=cycles+1;filters.sort=sortNames[(cycles-1)%4+1]
  filters.maxMembers=cycles%2==0 and 4 or nil
  g.Search:SetFilters(filters)
 elseif operation==4 then
  page:RefreshResults()
  local list=page.results
  local maximum=math.max(0,#g:GetResults()*list.rowHeight-list:GetHeight())
  local position=cycles%3==0 and 0 or cycles%3==1 and maximum/2 or maximum
  list:SetPixelOffset(position,true)
 end
 local elapsed=debugprofilestop()-at
 stat.calls=stat.calls+1;stat.inclusiveMs=stat.inclusiveMs+elapsed;stat.maxInclusiveMs=math.max(stat.maxInclusiveMs,elapsed)
 stat.heapNetKB=stat.heapNetKB+collectgarbage("count")-heap
 if step%SAMPLE_EVERY==0 then Sample("refresh_cycle",phase,step,false) end
 if step==(phase=="natural" and STEPS or RETAINED_STEPS) then
  if phase=="natural" then phase="natural_settle" else phase="retained_settle" end
 end
end
local function Finish()
 report.closedOwnersAfterCleanup=ClosedOwners()
 report.checks.knownOwnersIdle=report.closedOwnersBeforeCleanup.knownOwnersIdle
 report.checks.knownOwnersIdleAfterCleanup=report.closedOwnersAfterCleanup.knownOwnersIdle
 report.checks.searchGenerationUnchanged=g.Search:GetGeneration()==expectedGeneration+1 -- EndBrowse on hide
 report.checks.resultPoolStable=report.resultPoolAtStart==#page.results.rows
 local before,after=report.frameCounts.warm,report.frameCounts.final
 report.checks.nativeObjectsStable=not before.truncated and not after.truncated
  and before.frames==after.frames and before.regions==after.regions and before.animationGroups==after.animationGroups
 report.checks.allPackagesLoaded=true
 for i=1,#PACKAGES do if not report.samples[finalGC].loaded[i] then report.checks.allPackagesLoaded=false end end
 report.checks.noProbeDrivers=ticker==nil and eventFrame:GetScript("OnEvent")==nil
 local baseline,final=report.samples[baselineGC],report.samples[finalGC]
 report.summary.retainedBaselineSample,report.summary.retainedFinalSample=baselineGC,finalGC
 report.summary.retainedDeltaKB=final.addonTotalKB-baseline.addonTotalKB
 report.summary.wholeHeapRetainedDeltaKB=final.luaHeapKB-baseline.luaHeapKB
 report.summary.retainedPackageDeltaKB={}
 for i=1,#PACKAGES do report.summary.retainedPackageDeltaKB[i]=final.addonKB[i]-baseline.addonKB[i] end
 report.summary.budgetBytes=20000000
 report.summary.naturalPeakBytes=report.summary.naturalPeakKB*1024
 report.summary.sampledUncollectedPeakBytes=report.summary.sampledUncollectedPeakKB*1024
 report.summary.finalOpenRetainedBytes=final.addonTotalKB*1024
 report.checks.naturalPackageBudget=report.summary.sampledUncollectedPeakBytes<=report.summary.budgetBytes
 report.checks.retainedPackageBudget=report.summary.finalOpenRetainedBytes<=report.summary.budgetBytes
 report.finalNativeApplications=#C_LFGList.GetApplications()
 report.finalActiveListing=C_LFGList.HasActiveEntryInfo()
 report.checks.engineResourceAttribution=false
 report.elapsedSeconds,report.sampleCount=GetTime()-started,sampleCount
 report.ok=report.checks.knownOwnersIdle and report.checks.resultPoolStable
  and report.checks.searchGenerationUnchanged and report.checks.naturalPackageBudget and report.checks.retainedPackageBudget
  and report.checks.nativeObjectsStable and report.checks.allPackagesLoaded
 for i=sampleCount+1,#report.samples do report.samples[i]=nil end
 return probe:Finish(report)
end
local function Tick()
 if probe:IsCancelled() or GetTime()<nextAt then return end
 if GetTime()-started>110 then return probe:Fail("list_measurement_deadline") end
 if phase~="wait_search" and phase~="closed_settle" and g.Search:GetGeneration()~=expectedGeneration then return probe:Fail("another_search_started") end
 if phase=="wait_search" then
  local status,n=g.Search:GetState(),g:GetResultCount()
  if status=="failed" then return probe:Fail("native_search_failed") end
  if n~=lastCount then lastCount,stableAt=n,GetTime() end
  if status=="done" and GetTime()-stableAt>=1.5 then
   expectedGeneration=g.Search:GetGeneration();report.generationWhenDone=expectedGeneration
   BeginWorkload()
  elseif GetTime()-started>35 then return probe:Fail("real_results_not_stable") end
 elseif phase=="natural" or phase=="retained" then
  for _=1,BATCH do Work();if phase~="natural" and phase~="retained" then break end end
 elseif phase=="natural_settle" then
  if g.Results.updatePending then return end
  -- The first explicit GC happens only AFTER the entire natural workload.
  Sample("natural_end_before_gc","natural",step,false)
  baselineGC=Sample("open_retained_baseline","gc",step,true)
  phase,step="retained",0
 elseif phase=="retained_settle" then
  if g.Results.updatePending then return end
  Sample("repeat_end_before_gc","retained",step,false)
  finalGC=Sample("open_retained_final","gc",step,true)
  report.frameCounts.final=ObjectCounts()
  report.finalRealResults=g:GetResultCount();report.finalFilteredResults=#g:GetResults()
  ui:Hide();phase="closed_settle"
 elseif phase=="closed_settle" then
  report.closedOwnersBeforeCleanup=ClosedOwners()
  Cleanup();Sample("closed_after_gc","closed",step,true);Finish()
 end
 nextAt=GetTime()+((phase=="natural_settle" or phase=="retained_settle" or phase=="closed_settle") and .6 or INTERVAL)
end
eventFrame=CreateFrame("Frame")
eventFrame:SetScript("OnEvent",assert(probe:Callback(function(_,event)
 if event=="PLAYER_LEAVING_WORLD" then probe:Fail("scene_changed_"..event) end
end)))
for _,event in ipairs({"PLAYER_LEAVING_WORLD"}) do eventFrame:RegisterEvent(event) end
report.observer.setupHeapKB=collectgarbage("count")
report.observer.setupHeapDeltaKB=report.observer.setupHeapKB-observerStartHeap
ticker=C_Timer.NewTicker(.1,assert(probe:Callback(Tick)))
