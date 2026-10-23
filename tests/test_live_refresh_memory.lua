-- Probe control flow with real Find and Search; substitute results/counters are not memory evidence.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
for _,mode in ipairs({"complete","remember_off","cancel","observer_error","empty_results","stale_results","no_request"}) do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{rememberFilters=mode~="remember_off"})
 local A,U,G=f.A,f.U,f.G
 local now=0
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
 local nativeCalls,reads=0,0
 local testing=false
 function G.Results:CommitResults(generation)
  self.gen=testing and mode=="stale_results" and generation-1 or generation
  if not (testing and mode=="empty_results") then
   G.records[1]={id=1,name="Fixture result",activity=G.Catalog:GetActivity(2),activityID=2,categoryID=2,maxNumPlayers=5,numMembers=1,leaderName="Fixture-Home",leaderKey="Fixture-Home",age=0,requiredItemLevel=0,bnetFriends=0,charFriends=0,guildMates=0,ratingKind="dungeon"}
  end
  G:Notify("results")
 end
 C_LFGList.GetApplications=function() return {} end
 C_ChallengeMode.IsChallengeModeActive=function() return false end
 C_LFGList.GetLanguageSearchFilter=function() return {} end
 C_LFGList.Search=function()
  nativeCalls=nativeCalls+1
  C_Timer.NewTimer(.3,function() G.Search:OnResultsReceived() end)
 end
 GetBuildInfo=function() return "fixture","fixture",nil,0 end
 GetCVar=function() return "0" end
 debugprofilestop=function() return 0 end
 UpdateAddOnMemoryUsage=function()
  reads=reads+1
  if testing and mode=="observer_error" and reads==4 then error("simulated observer failure") end
 end
 GetAddOnMemoryUsage=function() return 1000 end
 C_AddOns.IsAddOnLoaded=function() return true,true end
 -- The prerequisite includes an already populated pool and all four pages.
 for _,key in ipairs({"settings","notes","create","find"}) do A:Open(key) end
 local page=U.pages.find
 page:CommitChoice();page:DoSearch();f.base.AdvanceClock(.5);U:Hide(true)
 Check(nativeCalls==1 and G:GetResultCount()==0,"warm request and normal close release results")
 A:Open("create");A:Open("settings");U:Hide(true)
 local oldPrefs,oldPage,oldReturn=G.prefs.find,U.page,U.settingsReturnPage
 local oldRemember=A:GetSetting("rememberFilters")
 local oldFilters={sort="rating"};G.Search:SetFilters(oldFilters)
 if mode=="no_request" then page.DoSearch=function() end end
 nativeCalls,reads=0,0;testing=true
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
 local ok,err=pcall(assert(loadfile("tests/live_refresh_memory.lua")),probe)
 if not ok then probe:Fail(err) end
 for tick=1,460 do
  if mode=="cancel" and tick==3 then probe:Close() end
  now=now+.25
  f.base.AdvanceClock(.25);U.Motion:Tick(.25)
  if not probe.active then break end
 end
 Check(not probe.active,mode.." bounded completion")
 if mode=="complete" or mode=="remember_off" then
  Check(probe.result and probe.result.ok,tostring(probe.error or "report failed"))
  Check(nativeCalls==6 and #probe.result.queries==6,"six native requests, with no duplicate reopen search")
  local expected={"reopen","refresh","reopen","refresh","reopen","refresh"}
  for i,query in ipairs(probe.result.queries) do
   Check(query.action==expected[i] and query.generationAtRequest>query.generationBefore,"fresh request generation and alternating action")
   Check(query.finalGeneration>=query.generationAtRequest and query.resultCount>0 and query.boundResults>0,"completed generation has populated rows")
  end
 elseif mode=="empty_results" then Check(probe.error=="native_results_empty",tostring(probe.error))
 elseif mode=="stale_results" then Check(probe.error=="native_result_generation_mismatch",tostring(probe.error))
 elseif mode=="no_request" then Check(probe.error=="native_search_not_started",tostring(probe.error))
 elseif mode=="observer_error" then Check(probe.error and probe.error:find("simulated observer failure",1,true),tostring(probe.error))
 else Check(probe.result==nil,"cancellation cannot report completion") end
 Check(G.prefs.find==oldPrefs and G.Search:GetFilters().sort==oldFilters.sort,mode.." original preferences and filters restored")
 Check(A:GetSetting("rememberFilters")==oldRemember,mode.." remember preference preserved")
 Check(not U:IsShown() and U.page==oldPage and U.settingsReturnPage==oldReturn and not U.Native.searchLease and U.Motion:Count()==0,mode.." navigation and UI owners restored")
 Check(U._nav==oldPage and U.settingsButton.active==(oldPage=="settings"),mode.." navigation presentation restored")
 local finalReads=reads
 for tick=1,12 do f.base.AdvanceClock(.25) end
 Check(reads==finalReads and G:GetResultCount()==0 and not G:HasViews(),mode.." late callbacks do not resume observation or business views")
 assert(A:Open(oldPage))
 for key,page in pairs(U.pages) do if page.frame then Check(page.frame:IsVisible()==(key==oldPage),mode.." reopen shows only original page: "..key) end end
 U.settingsButton:Fire("OnClick","LeftButton");Check(U.page==oldReturn,mode.." settings button returns to the original source");U:Hide(true)
end
print("Refresh memory probe lifecycle: "..checks.." checks passed")
