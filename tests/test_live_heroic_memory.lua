-- Real Find/Search control flow; substitute results and counters are not memory evidence.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
for _,mode in ipairs({"complete","cancel","observer_error","no_request","stale_results","empty_results","warm_open_failure"}) do
 local f=dofile("tests/ui_fixture.lua")("enUS")
 local A,U,G=f.A,f.U,f.G
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 local now,reads,nativeCalls=0,0,0
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
  self.gen=mode=="stale_results" and generation-1 or generation
  if mode~="empty_results" then
   for id=1,24 do
    G.records[id]={id=id,name="Fixture raid "..id,activity=G.Catalog:GetActivity(1),activityID=1,categoryID=3,maxNumPlayers=30,numMembers=20,leaderName="Fixture-Home",leaderKey="Fixture-Home",age=0,requiredItemLevel=0,bnetFriends=0,charFriends=0,guildMates=0,ratingKind="raid"}
   end
  end
  G:Notify("results")
 end
 local activity=C_LFGList.GetActivityInfoTable(1)
 activity.fullName,activity.shortName,activity.difficultyID="烈毒之渊（英雄）","烈毒之渊",15
 EJ_GetDifficulty=function() return 15 end;EJ_SetDifficulty=function() end
 EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
 C_LFGList.GetApplications=function() return {} end
 C_ChallengeMode.IsChallengeModeActive=function() return false end
 C_LFGList.GetLanguageSearchFilter=function() return {} end
 C_LFGList.Search=function(_,_,_,_,_,_,ids)
  nativeCalls=nativeCalls+1
  Check(ids and #ids==1 and ids[1]==1,"native request selects only the target activity")
  C_Timer.NewTimer(.3,function() G.Search:OnResultsReceived() end)
 end
 GetBuildInfo=function() return "fixture","fixture",nil,0 end
 GetCVar=function() return "0" end
 debugprofilestop=function() return 0 end
 UpdateAddOnMemoryUsage=function()
  reads=reads+1
  if mode=="observer_error" and reads==9 then error("simulated observer failure") end
 end
 GetAddOnMemoryUsage=function(name) return name=="LycheeGroup_Guide" and 0 or 1000 end
 C_AddOns.IsAddOnLoaded=function(name) return true,name~="LycheeGroup_Guide" end
 -- Preserve a session override, an original preference reference and live filters.
 assert(A.API.Configuration:Set({["settings.rememberFilters"]=false}))
 local oldPrefs=G.prefs.find
 G.Search:SetFilters({sort="rating"})
 A:Open("create");A:Open("settings");U:Hide(true)
 local oldPage,oldReturn=U.page,U.settingsReturnPage
 if mode=="no_request" then U.pages.find.DoSearch=function() end end
 local probe={active=true,cleanup={}}
 function probe:Async() return true end
 function probe:Guard(check) return check() end
 function probe:IsCancelled() return not self.active end
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
 if mode=="warm_open_failure" then
  A.Open=function(self,page,...)
   local result=open(self,page,...)
   if page=="settings" then error("simulated open failure") end
   return result
  end
 end
 local ok,err=pcall(assert(loadfile("tests/live_heroic_memory.lua")),probe)
 if not ok then probe:Fail(err) end
 A.Open=open
 if mode~="no_request" then Check(nativeCalls==(mode=="warm_open_failure" and 0 or 1),"startup target request count: "..tostring(probe.error)) end
 for tick=1,460 do
  if mode=="cancel" and tick==3 then probe:Close() end
  now=now+.25;f.base.AdvanceClock(.25);U.Motion:Tick(.25)
  if not probe.active then break end
 end
 Check(not probe.active,mode.." bounded completion")
 if mode=="complete" then
  if probe.result then for name,value in pairs(probe.result.checks) do Check(value,"complete report check: "..name) end end
  Check(probe.result and probe.result.ok,tostring(probe.error or "report failed"))
  Check(#probe.result.packages==5 and probe.result.packages[5]=="LycheeGroup_Guide","Guide is sampled without becoming a prerequisite")
  for _,sample in ipairs(probe.result.samples) do Check(sample.loaded[5]==false and sample.addonTotalKB==4000,"normal heroic searches leave Guide unloaded") end
  Check(nativeCalls==6 and #probe.result.queries==6,"exactly six real search submissions")
  for index,query in ipairs(probe.result.queries) do
   Check(query.activityID==1 and query.generation>query.generationBefore and query.generationWhenDone==query.generation,"completed result belongs to its requested generation")
   if index>1 then
    Check(query.generation==probe.result.queries[index-1].generation+1,"successive requests use six distinct generations")
    Check(query.startedAt-probe.result.queries[index-1].startedAt>=8,"native request spacing remains at least eight seconds")
   end
  end
 elseif mode=="no_request" then Check(probe.error=="native_search_not_started",tostring(probe.error))
 elseif mode=="stale_results" then Check(probe.error=="native_result_generation_mismatch",tostring(probe.error))
 elseif mode=="empty_results" then Check(probe.error=="native_results_empty",tostring(probe.error))
 elseif mode=="observer_error" then Check(probe.error and probe.error:find("simulated observer failure",1,true),tostring(probe.error))
 elseif mode=="warm_open_failure" then Check(probe.error and probe.error:find("simulated open failure",1,true),tostring(probe.error))
 else Check(probe.result==nil,"cancellation cannot report completion") end
 Check(G.prefs.find==oldPrefs and G.Search:GetFilters().sort=="rating",mode.." original preferences and filters restored")
 Check(A:GetSetting("rememberFilters")==false and A.API.Configuration:GetSource("settings.rememberFilters").storage=="session",mode.." previous session override restored")
 Check(not U:IsShown() and U.page==oldPage and U.settingsReturnPage==oldReturn and not U.Native.searchLease and U.Motion:Count()==0,mode.." navigation and UI owners restored")
 Check(U._nav==oldPage and U.settingsButton.active==(oldPage=="settings"),mode.." navigation presentation restored")
 local finalReads=reads
 for tick=1,12 do f.base.AdvanceClock(.25) end
 Check(reads==finalReads and G:GetResultCount()==0 and not G:HasViews(),mode.." late callbacks remain inactive")
 assert(A:Open(oldPage))
 for key,page in pairs(U.pages) do if page.frame then Check(page.frame:IsVisible()==(key==oldPage),mode.." reopen shows only original page: "..key) end end
 U.settingsButton:Fire("OnClick","LeftButton");Check(U.page==oldReturn,mode.." settings button returns to the original source");U:Hide(true)
end
print("Heroic memory probe lifecycle: "..checks.." checks passed")
