-- The Lychee branch runs real Find/Search; MeetingStone and native counters are substitutes.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
for _,mode in ipairs({"complete","cancel","open_failure","partial_open_failure"}) do
 local f=dofile("tests/ui_fixture.lua")("enUS")
 local A,U,G=f.A,f.U,f.G
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 local now,nativeCalls=0,0
 GetTime=function() return now end
 dofile("addon/LycheeGroup_Group/Search.lua")
 G.Game={frame=CreateFrame("Frame"),RefreshSubscriptions=function() end}
 function G:GetSearchState() return self.Search:GetState() end
 function G:GetSearchError() return self.Search:GetSearchError() end
 function G:HasViews(kind) for _,value in pairs(self.views) do if not kind or value==kind then return true end end;return false end
 function G:Detach(view) self.views[view]=nil;if not self:HasViews("search") then self.Search:EndBrowse() end end
 function G:SetFilters(filters) self.Search:SetFilters(filters) end
 function G.Results:BeginSearch(generation) self.gen=generation;wipe(G.records) end
 function G.Results:FailSearch() wipe(G.records) end
 function G.Results:CommitResults(generation)
  self.gen=generation
  for id=1,24 do
   G.records[id]={id=id,name="Fixture raid "..id,activity=G.Catalog:GetActivity(1956),activityID=1956,categoryID=3,maxNumPlayers=30,numMembers=20,leaderName="Fixture-Home",leaderKey="Fixture-Home",age=0,requiredItemLevel=0,bnetFriends=0,charFriends=0,guildMates=0,ratingKind="raid"}
  end
  G:Notify("results")
 end
 local activity=C_LFGList.GetActivityInfoTable(1)
 activity.difficultyID,activity.groupFinderActivityGroupID=15,424
 local nativeActivity,nativeActivities=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities
 C_LFGList.GetActivityInfoTable=function(id) if id==1956 then return activity end;return nativeActivity(id) end
 C_LFGList.GetAvailableActivities=function(category,...) if category==3 then return {1956} end;return nativeActivities(category,...) end
 EJ_GetDifficulty=function() return 15 end;EJ_SetDifficulty=function() end
 EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
 C_LFGList.GetApplications=function() return {} end
 C_ChallengeMode.IsChallengeModeActive=function() return false end
 IsInGroup=function() return false end
 C_LFGList.GetLanguageSearchFilter=function() return {} end
 C_LFGList.GetSearchResults=function() local ids=G:GetResults();return #ids,ids end
 C_LFGList.Search=function(_,_,_,_,_,_,ids)
  nativeCalls=nativeCalls+1
  Check(ids and #ids==1 and ids[1]==1956,"actual Search sends the target activity array")
  Check(G.Search.request.activityID==nil,"real Search supplies no obsolete scalar activity field")
  C_Timer.NewTimer(.3,function()
   G.Search:OnResultsReceived()
   for _,node in ipairs(f.S.nodes) do if node.events.LFG_LIST_SEARCH_RESULTS_RECEIVED then node:Fire("OnEvent","LFG_LIST_SEARCH_RESULTS_RECEIVED") end end
  end)
 end
 local cvars={scriptProfile="1",maxFPS="120",maxFPSBk="30"}
 GetCVar=function(key) return cvars[key] end
 SetCVar=function(key,value) cvars[key]=tostring(value) end
 GetBuildInfo=function() return "fixture","fixture",nil,0 end
 GetFramerate=function() return 60 end
 debugprofilestop=function() return 0 end
 UpdateAddOnMemoryUsage=function() end;UpdateAddOnCPUUsage=function() end
 GetAddOnMemoryUsage=function() return 1000 end;GetAddOnCPUUsage=function() return 0 end
 local main=f.S.New("Frame",nil,UIParent);main:Hide()
 function main:GetSelectedPanel() return nil end
 local profile={cdb={profile={lastSearchCode="original",searchHistoryList={}}},gdb={global={filters={[3]={}}}}}
 local browse={SearchBox={GetText=function() return "" end},ActivityDropdown={GetItem=function() return "original" end}}
 local modules={MainPanel=main,BrowsePanel=browse,LfgService={},Profile=profile}
 local meeting={OnInitialize=function() end,GetModule=function(_,name) return modules[name] end}
 A:Open("create");A:Open("settings");U:Hide(true)
 local originalLibStub=LibStub
 LibStub=function(name,...)
  if name=="AceAddon-3.0" then return {GetAddon=function() return meeting end} end
  if originalLibStub then return originalLibStub(name,...) end
 end
 assert(A.API.Configuration:Set({["settings.rememberFilters"]=false}))
 local oldPrefs=G.prefs.find
 G.Search:SetFilters({sort="rating"})
 local oldPage,oldReturn=U.page,U.settingsReturnPage
 local oldShown={};for key,page in pairs(U.pages) do oldShown[key]=page.frame and page.frame:IsShown() or false end
 local probe={active=true,cleanup={}}
 function probe:Async() return true end
 function probe:Guard(check) return check() end
 function probe:OnCleanup(fn) self.cleanup[#self.cleanup+1]=fn;return true end
 function probe:Close()
  if not self.active then return end
  self.active=false
  for i=#self.cleanup,1,-1 do self.cleanup[i]() end
 end
 function probe:Finish(result) self.result=result;self:Close() end
 function probe:Fail(reason) self.error=reason;self:Close() end
 function probe:Callback(fn)
  return function(...)
   if not self.active then return end
   local ok,err=pcall(fn,...);if not ok then self:Fail(err) end
  end
 end
 local open=A.Open
 if mode=="open_failure" or mode=="partial_open_failure" then
  A.Open=function(self,page,...)
   if mode=="open_failure" and page=="find" then error("simulated open failure") end
   local result=open(self,page,...)
   if page=="find" then error("simulated open failure") end
   return result
  end
 end
 local ok,err=pcall(assert(loadfile("tests/live_compare.lua")),probe)
 if not ok then probe:Fail(err) end
 A.Open=open
 Check(nativeCalls==(mode=="open_failure" and 0 or 1),"startup request count: "..tostring(probe.error))
 if mode=="open_failure" or mode=="partial_open_failure" then Check(probe.error and probe.error:find("simulated open failure",1,true),"preparation failure is reported") end
 for tick=1,360 do
  if mode=="cancel" and tick==3 then probe:Close() end
  now=now+.25;f.base.AdvanceClock(.25);U.Motion:Tick(.25)
  if not probe.active then break end
 end
 Check(not probe.active,mode.." bounded completion")
 if mode=="complete" then
  if probe.result then for name,value in pairs(probe.result.checks) do Check(value,"complete report check: "..name) end end
  Check(probe.result and probe.result.ok,tostring(probe.error or "report failed"))
  Check(nativeCalls==7 and #probe.result.queries==6,"one warmup and six measured real requests")
  for _,query in ipairs(probe.result.queries) do Check(query.activityID==1956 and query.results==24,"measured target identity and populated result event") end
 else Check(probe.result==nil,"cancellation cannot report completion") end
 Check(G.prefs.find==oldPrefs and G.Search:GetFilters().sort=="rating",mode.." preferences and filters restored")
 Check(A:GetSetting("rememberFilters")==false and cvars.maxFPS=="120" and cvars.maxFPSBk=="30",mode.." configuration and FPS restored")
 Check(not U:IsShown() and U.page==oldPage and U.settingsReturnPage==oldReturn and not U.Native.searchLease and U.Motion:Count()==0,mode.." navigation and UI owners restored")
 for key,page in pairs(U.pages) do Check((page.frame and page.frame:IsShown() or false)==oldShown[key],mode.." hidden page frame restored: "..key) end
 Check(U._nav==oldPage and U.settingsButton.active==(oldPage=="settings"),mode.." navigation presentation restored")
 local finalCalls=nativeCalls
 for tick=1,12 do f.base.AdvanceClock(.25) end
 Check(nativeCalls==finalCalls and G:GetResultCount()==0 and not G:HasViews(),mode.." cleanup prevents further requests and result ownership")
 assert(A:Open(oldPage))
 for key,page in pairs(U.pages) do if page.frame then Check(page.frame:IsVisible()==(key==oldPage),mode.." reopen shows only original page: "..key) end end
 U.settingsButton:Fire("OnClick","LeftButton");Check(U.page==oldReturn,mode.." settings button returns to the original source");U:Hide(true)
end
print("Live comparison Lychee control flow: "..checks.." checks passed")
