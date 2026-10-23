-- Live comparison driver. Change only targetName for the second trial.
-- Actual list controllers and native searches; no applications or recruitment.
local targetName = "lychee"
local probe = ...
local A = assert(LycheeGroup, "lychee_missing")
local M = LibStub("AceAddon-3.0"):GetAddon("MeetingStone")
local main,browse,service,profile = M:GetModule("MainPanel"),M:GetModule("BrowsePanel"),M:GetModule("LfgService"),M:GetModule("Profile")
local env = getfenv(M.OnInitialize)
assert(GetCVar("scriptProfile")=="1", "cpu_profile_requires_reload")
assert(not (A.UI and A.UI:IsShown()) and not main:IsShown(), "requires_closed_windows")
assert(browse.SearchBox:GetText()=="", "requires_empty_search")
local function Idle()
 return not InCombatLockdown() and not IsInGroup() and not C_ChallengeMode.IsChallengeModeActive() and not C_LFGList.HasActiveEntryInfo() and #C_LFGList.GetApplications()==0
end
assert(Idle(), "requires_idle_business")
local packages={"LycheeGroup","LycheeGroup_Group","LycheeGroup_Notes","LycheeGroup_UI","MeetingStone"}
local config=A.API.Configuration
local saved={fps=GetCVar("maxFPS"),fpsBk=GetCVar("maxFPSBk"),remember=config:Get("settings.rememberFilters"),rememberSource=config:GetSource("settings.rememberFilters"),
 page=A.UI and A.UI.page,returnPage=A.UI and A.UI.settingsReturnPage,
 msItem=browse.ActivityDropdown:GetItem(),msLast=profile.cdb.profile.lastSearchCode,
 msHistory=profile.cdb.profile.searchHistoryList,msPanel=main:GetSelectedPanel(),
 msInSet=browse.inSet,msFilter=profile.gdb.global.filters[3]}
local deal=M:GetModule("DealBrowsePanel",true)
saved.dealItem=deal and deal.ActivityDropdown:GetItem()
saved.pageShown={}
if A.UI then for key,page in pairs(A.UI.pages) do saved.pageShown[key]=page.frame and page.frame:IsShown() or false end end
local report={schema="lycheegroup.live-comparison.v1",target=targetName,packages=packages,
 client={version=select(1,GetBuildInfo()),build=select(2,GetBuildInfo()),interface=select(4,GetBuildInfo()),locale=GetLocale(),uiScale=UIParent:GetScale()},
 versions={},scenario={activityID=1956,name="烈毒之渊（英雄）",seconds=60,warmupMinimumSeconds=10,searches=6,searchIntervalSeconds=10,wheelCalls=120,wheelIntervalSeconds=.5,memorySampleSeconds=1,fpsLimit=60},
 measurement={cpu="UpdateAddOnCPUUsage + GetAddOnCPUUsage end minus start (ms)",memory="refreshed GetAddOnMemoryUsage per package, simultaneous sum; KB*1024/1000000 MB",gc="natural, no explicit collection",scriptProfile=GetCVar("scriptProfile")},
 samples={},queries={},events={received=0,failed=0,updated=0},wheelCalls=0,searches=0,peakKB=0,observer={memoryMs=0,cpuMs=0},checks={}}
for _,name in ipairs(packages) do report.versions[name]=C_AddOns.GetAddOnMetadata(name,"Version") end
local ui,g,page,list,timer,frame,cleaned
local started,measuredAt,nextMemory,nextWheel,direction=GetTime(),nil,1,.25,-1
local function Copy(t) local out={} for k,v in pairs(t or {}) do out[k]=v end return out end
local function LycheeActivity()
 local activities=g and g.Search.request and g.Search.request.activityIDs
 return activities and #activities==1 and activities[1] or nil
end
local function Cleanup()
 if cleaned then return end;cleaned=true
 if timer then timer:Cancel();timer=nil end
 if frame then frame:UnregisterAllEvents();frame:SetScript("OnEvent",nil);frame:Hide() end
 -- Opening Find can fail after its preferences have already been isolated.
 -- Use the existing/partially constructed host and restore Group independently.
 ui=ui or (g and A.UI and A.UI.frame and A.UI)
 if ui then
  ui:Hide(true);ui.Motion:StopAll()
 end
 if g then
  g.prefs.find=saved.findPrefs
  g.Search:SetFilters(saved.findFilters)
 end
 if ui then
  ui.pages.find.loaded=nil;ui.pages.find.restoredInitial=nil
  for key,p in pairs(ui.pages) do if p.frame then p.frame:SetShown(saved.pageShown[key]==true) end end
  ui.page,ui.settingsReturnPage=saved.page,saved.returnPage
  ui:UpdateNav();ui.Motion:FinishRect(ui.underline)
 end
 if targetName=="meetingstone" then
  main:Hide()
  browse:StartSet();browse.ActivityDropdown:SetItem(saved.msItem)
  if deal and saved.dealItem then deal.ActivityDropdown:SetItem(saved.dealItem) end
  browse.inSet=saved.msInSet
  profile.cdb.profile.lastSearchCode=saved.msLast
  profile.cdb.profile.searchHistoryList=saved.msHistory
  profile.gdb.global.filters[3]=saved.msFilter
  env.RefreshHistoryMenuTable(env.ACTIVITY_FILTER_BROWSE)
  browse:UpdateFilters()
  if saved.msPanel then main:SelectPanel(saved.msPanel) end
 end
 if saved.rememberSource.kind=="user" and saved.rememberSource.storage=="session" then
  assert(config:Set({["settings.rememberFilters"]=saved.remember}))
 else assert(config:Reset("settings.rememberFilters")) end
 C_LFGList.ClearSearchTextFields()
 SetCVar("maxFPS",saved.fps);SetCVar("maxFPSBk",saved.fpsBk)
end
assert(probe:Async(90));assert(probe:OnCleanup(Cleanup))
assert(probe:Guard(Idle,{"PLAYER_REGEN_DISABLED","GROUP_ROSTER_UPDATE","CHALLENGE_MODE_START","LFG_LIST_ACTIVE_ENTRY_UPDATE","LFG_LIST_APPLICATION_STATUS_UPDATED"},"scene_changed"))
SetCVar("maxFPS",60);SetCVar("maxFPSBk",60)
if targetName=="lychee" then
 assert(A:Ensure("Group"))
 g=A.Group;saved.findPrefs=g.prefs.find;saved.findFilters=Copy(g.Search:GetFilters())
 assert(config:Set({["settings.rememberFilters"]=true}))
 g.prefs.find={category="3",categoryPrefs={["3"]={groupKey=424,difficultyID=15}},filters={sort="newest"}}
 if A.UI and A.UI.pages.find then A.UI.pages.find.loaded=nil;A.UI.pages.find.restoredInitial=nil end
 assert(A:Open("find"));ui=A.UI;page=ui.pages.find;list=page.results
 assert(LycheeActivity()==1956,"lychee_wrong_activity")
else
 profile.cdb.profile.searchHistoryList=Copy(saved.msHistory)
 profile.gdb.global.filters[3]={}
 main:SelectPanel(browse);main:Show()
 browse:StartSet();browse.ActivityDropdown:SetValue("3-424-1956-0")
 C_LFGList.SetSearchToActivity(1956)
 browse:EndSet()
 assert(service.activityId==1956,"meetingstone_wrong_activity")
 list=browse.ActivityList
end
local function Count()
 local nativeCount,nativeIDs=C_LFGList.GetSearchResults()
 if targetName=="lychee" then return g:GetResultCount(),#g:GetResults(),nativeCount,#nativeIDs end
 return service:GetActivityCount(),list:GetItemCount(),nativeCount,#nativeIDs
end
local function CPU()
 local at=debugprofilestop();UpdateAddOnCPUUsage()
 local values={};for i,name in ipairs(packages) do values[i]=GetAddOnCPUUsage(name) end
 report.observer.cpuMs=report.observer.cpuMs+debugprofilestop()-at
 return values
end
local function Total(values)
 if targetName=="meetingstone" then return values[5] end
 return values[1]+values[2]+values[3]+values[4]
end
local function Sample(at)
 local tick=debugprofilestop();UpdateAddOnMemoryUsage()
 local values={};for i,name in ipairs(packages) do values[i]=GetAddOnMemoryUsage(name) end
 local observerMs=debugprofilestop()-tick
 report.observer.memoryMs=report.observer.memoryMs+observerMs
 local raw,shown,native,nativeIDs=Count()
 local row={at=at,packageKB=values,totalKB=Total(values),observerMs=observerMs,results=raw,shown=shown,nativeResults=native,nativeIDs=nativeIDs,fps=GetFramerate()}
 if targetName=="lychee" then row.offset=list.pixelOffset else row.offset=list:GetOffset() end
 report.samples[#report.samples+1]=row
 if row.totalKB>report.peakKB then report.peakKB=row.totalKB;report.peakSample=#report.samples end
end
local function Search()
 local query={at=GetTime()-measuredAt}
 if targetName=="lychee" then page:DoSearch();query.activityID=LycheeActivity()
 else browse:DoSearch();query.activityID=service.activityId end
 assert(query.activityID==1956,"search_activity_changed")
 report.searches=report.searches+1;report.queries[report.searches]=query
end
frame=CreateFrame("Frame")
frame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED");frame:RegisterEvent("LFG_LIST_SEARCH_FAILED");frame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
frame:SetScript("OnEvent",assert(probe:Callback(function(_,event)
 if not measuredAt then return end
 if event=="LFG_LIST_SEARCH_FAILED" then report.events.failed=report.events.failed+1
 elseif event=="LFG_LIST_SEARCH_RESULTS_RECEIVED" then
  report.events.received=report.events.received+1
  local q=report.queries[report.searches]
  if q then q.completedAt=GetTime()-measuredAt;q.results,q.shown,q.nativeResults,q.nativeIDs=Count() end
 else report.events.updated=report.events.updated+1 end
end)))
local function Finish()
 report.cpuEnd=CPU();report.duration=GetTime()-measuredAt
 report.cpuPackageMs={};for i=1,#packages do report.cpuPackageMs[i]=report.cpuEnd[i]-report.cpuStart[i] end
 report.cpuMs=Total(report.cpuPackageMs)
 Sample(report.duration)
 report.peakMB=report.peakKB*1024/1000000
 report.warmupSeconds=measuredAt-started
 report.checks.sixSearches=report.searches==6 and report.events.received==6 and report.events.failed==0
 report.checks.wheelCalls=report.wheelCalls==120
 report.checks.nonempty=true;for _,q in ipairs(report.queries) do if not q.results or q.results==0 then report.checks.nonempty=false end end
 Cleanup()
 report.checks.closed=not main:IsShown() and not (A.UI and A.UI:IsShown())
 report.checks.preferencesRestored=A:GetSetting("rememberFilters")==saved.remember and profile.cdb.profile.lastSearchCode==saved.msLast and profile.cdb.profile.searchHistoryList==saved.msHistory
 report.checks.fpsRestored=GetCVar("maxFPS")==saved.fps and GetCVar("maxFPSBk")==saved.fpsBk
 report.checks.businessUnchanged=Idle()
 report.ok=true;for _,v in pairs(report.checks) do if v~=true then report.ok=false end end
 probe:Finish(report)
end
timer=C_Timer.NewTicker(.05,assert(probe:Callback(function()
 local now=GetTime()
 if not measuredAt then
  if now-started>=10 then
   local ready=targetName=="lychee" and g:GetSearchState()=="done" or targetName=="meetingstone" and not service.inSearch
   local count=Count()
   if ready and count>0 then
    Sample(0);report.cpuStart=CPU();measuredAt=GetTime();Search()
   elseif now-started>24 then probe:Fail("warmup_search_not_ready") end
  end
  return
 end
 local elapsed=now-measuredAt
 if elapsed>=60 then return Finish() end
 if report.searches<6 and elapsed>=report.searches*10 then Search() end
 if report.wheelCalls<120 and elapsed>=nextWheel then
  if targetName=="lychee" then
   local max=math.max(0,#g:GetResults()*list.rowHeight-list:GetHeight())
   local pos=list.scrollTarget or list.pixelOffset
   if direction==-1 and pos>=max-.5 or direction==1 and pos<=.5 then direction=-direction end
  else
   if direction==-1 and list:AtBottom() or direction==1 and list:AtTop() then direction=-direction end
  end
  list:GetScript("OnMouseWheel")(list,direction)
  report.wheelCalls=report.wheelCalls+1;nextWheel=.25+report.wheelCalls*.5
 end
 if elapsed>=nextMemory then Sample(elapsed);nextMemory=nextMemory+1 end
end)))
