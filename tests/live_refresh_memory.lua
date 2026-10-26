-- Six real searches through the normal refresh/reopen actions, with natural GC.
-- Run after live_list_memory.lua has warmed the four business packages and closed the UI.
-- Guide remains load-on-demand; include its retained cost if it was used earlier.
local probe=...
local A=_G.LycheeGroup
local ui,g=A and A.UI,A and A.Group
if not ui or not g or ui:IsShown() or ui.hiding or ui.preview then return probe:Fail("requires_warmed_closed_ui") end
if InCombatLockdown() or C_ChallengeMode.IsChallengeModeActive() or C_LFGList.HasActiveEntryInfo() or #C_LFGList.GetApplications()>0 then return probe:Fail("requires_idle_group_business") end
if g:GetSearchState()=="searching" or g:GetSearchState()=="waiting" then return probe:Fail("search_already_running") end
local packages={"LycheeGroup","LycheeGroup_Group","LycheeGroup_Notes","LycheeGroup_UI","LycheeGroup_Guide"}
local page=ui.pages.find
if not page or not page.frame or not page.results then return probe:Fail("requires_warmed_find_page") end
local oldPage,oldReturn,oldPrefs=ui.page,ui.settingsReturnPage,g.prefs.find
local oldShown,oldFilters={},{}
for key,p in pairs(ui.pages) do oldShown[key]=p.frame and p.frame:IsShown() or false end
for key,value in pairs(g.Search:GetFilters()) do oldFilters[key]=value end
local started=GetTime()
local version,build,_,interface=GetBuildInfo()
local report={schema="lycheegroup.refresh-memory.v1",packages=packages,client={version=version,build=build,interface=interface},
 scenario={rounds=6,minimumSearchSpacingSeconds=8,gcPolicy="natural; no explicit collection",samplePolicy="each phase boundary and each second while waiting"},
 settings={reduceMotion=A:GetSetting("reduceMotion"),scriptProfile=GetCVar("scriptProfile")},samples={},queries={},checks={},peakBytes=0}
for i=1,128 do
 local row={addonKB={},loaded={}}
 for packageIndex=1,#packages do row.addonKB[packageIndex],row.loaded[packageIndex]=0,false end
 report.samples[i]={addonKB=row.addonKB,loaded=row.loaded}
end
local used,round,ticker,eventFrame,cleaned=0,0
local function Cleanup()
 if cleaned then return end
 cleaned=true
 if ticker then ticker:Cancel();ticker=nil end
 if eventFrame then eventFrame:UnregisterAllEvents();eventFrame:SetScript("OnEvent",nil);eventFrame:Hide() end
 ui:Hide(true);ui.Motion:StopAll()
 g.Search:SetFilters(oldFilters);g.prefs.find=oldPrefs;page.loaded=nil;page.restoredInitial=nil
 for key,p in pairs(ui.pages) do if p.frame then p.frame:SetShown(oldShown[key]) end end
 ui.page,ui.settingsReturnPage=oldPage,oldReturn
 ui:UpdateNav();ui.Motion:FinishRect(ui.underline)
end
assert(probe:Async(115));assert(probe:OnCleanup(Cleanup))
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
local function Sample(tag)
 used=used+1
 local row=assert(report.samples[used],"sample_capacity")
 row.tag,row.round,row.atSeconds=tag,round,GetTime()-started
 local at=debugprofilestop();UpdateAddOnMemoryUsage();row.counterRefreshMs=debugprofilestop()-at
 local total=0
 for i,name in ipairs(packages) do
  local _,loaded=C_AddOns.IsAddOnLoaded(name);row.loaded[i]=loaded==true
  row.addonKB[i]=GetAddOnMemoryUsage(name);total=total+row.addonKB[i]
 end
 row.addonTotalKB=total;row.realResults=g:GetResultCount();row.searchState=g:GetSearchState()
 report.peakBytes=math.max(report.peakBytes,total*1024)
end
Sample("before")
g.prefs.find={category="seasonDungeon"};page.loaded=nil;page.restoredInitial=nil
local phase,nextAt,lastSample="open",GetTime(),GetTime()
local originalFrame,originalPool=page.frame,#page.results.rows
report.checks.reusedPage=true;report.checks.closedResultsReleased=true
local function StartQuery(reopen)
 round=round+1
 local before=g.Search:GetGeneration()
 if reopen then
  local ok,err=A:Open("find");if not ok then return probe:Fail("open_failed_"..tostring(err)) end
  -- A fresh preference table has no confirmed activity. Reopening only
  -- searches automatically when the current selection has already been saved.
  if g.Search:GetGeneration()==before then page:CommitChoice();page:DoSearch() end
 else page:DoSearch() end
 local generation=g.Search:GetGeneration()
 if generation<=before then return probe:Fail("native_search_not_started") end
 report.queries[round]={action=reopen and "reopen" or "refresh",generationBefore=before,generationAtRequest=generation,startedAt=GetTime()-started}
 report.checks.reusedPage=report.checks.reusedPage and page.frame==originalFrame and #page.results.rows==originalPool
 phase="searching";nextAt=GetTime()+8;lastSample=GetTime();Sample("search_started")
end
local function Tick()
 if probe:IsCancelled() then return end
 if GetTime()-started>110 then return probe:Fail("native_refresh_deadline") end
 if phase=="open" then StartQuery(true)
 elseif phase=="searching" then
  local status=g:GetSearchState()
  if status=="failed" then return probe:Fail("native_search_failed_"..tostring(g:GetSearchError())) end
  if GetTime()-lastSample>=1 then Sample("waiting");lastSample=GetTime() end
  if status=="done" then phase="settle";lastSample=GetTime()+.8 end
 elseif phase=="settle" and GetTime()>=lastSample then
  Sample("search_complete")
  local query=report.queries[round]
  query.finalGeneration=g.Search:GetGeneration();query.resultCount=g:GetResultCount();query.completedAt=GetTime()-started
  if g:GetSearchState()~="done" or query.finalGeneration<query.generationAtRequest or g.Results.gen~=query.finalGeneration then return probe:Fail("native_result_generation_mismatch") end
  if query.resultCount==0 then return probe:Fail("native_results_empty") end
  query.filteredResults=#g:GetResults()
  query.boundResults=#page.results.ids
  if query.filteredResults==0 or query.boundResults~=query.filteredResults or not page.results.rows[1].key or page.emptyPanel:IsShown() then return probe:Fail("native_results_not_bound") end
  page.results:SetPixelOffset(math.max(0,#g:GetResults()*page.results.rowHeight-page.results:GetHeight()),false)
  phase=round==6 and "finish" or "interval"
 elseif phase=="interval" and GetTime()>=nextAt then
  if round%2==0 then
   ui:Hide(true);Sample("closed_between_searches")
   report.checks.closedResultsReleased=report.checks.closedResultsReleased and g:GetResultCount()==0 and not g.Results.updatePending and g.Game.frame:GetScript("OnUpdate")==nil
   phase="reopen";nextAt=GetTime()+.6
  else StartQuery(false) end
 elseif phase=="reopen" and GetTime()>=nextAt then StartQuery(true)
 elseif phase=="finish" then
  Cleanup();Sample("closed_final")
  report.checks.knownOwnersIdle=not ui:IsShown() and not g:HasViews() and g:GetResultCount()==0 and not g.Results.updatePending
   and g.Game.frame:GetScript("OnUpdate")==nil and not g.Search.timer and not g.Search.pending and next(ui.Motion.jobs)==nil
  report.checks.allPackagesLoaded=true
  for i,name in ipairs(packages) do
   if name~="LycheeGroup_Guide" and not report.samples[used].loaded[i] then report.checks.allPackagesLoaded=false end
  end
  report.checks.budget=report.peakBytes<=20000000
  report.checks.sixNonemptySearches=#report.queries==6
  report.ok=report.checks.budget and report.checks.knownOwnersIdle and report.checks.reusedPage and report.checks.closedResultsReleased and report.checks.allPackagesLoaded and report.checks.sixNonemptySearches
  report.elapsedSeconds,report.sampleCount=GetTime()-started,used
  for i=used+1,#report.samples do report.samples[i]=nil end
  return probe:Finish(report)
 end
end
eventFrame=CreateFrame("Frame")
eventFrame:SetScript("OnEvent",assert(probe:Callback(function(_,event) probe:Fail("scene_or_business_changed_"..event) end)))
for _,event in ipairs({"PLAYER_LEAVING_WORLD","CHALLENGE_MODE_START","LFG_LIST_ACTIVE_ENTRY_UPDATE","LFG_LIST_APPLICATION_STATUS_UPDATED"}) do eventFrame:RegisterEvent(event) end
ticker=C_Timer.NewTicker(.1,assert(probe:Callback(Tick)))
