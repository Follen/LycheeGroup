-- Real Find/Search controllers with substitute results, clock and memory counters.
-- Shared only by probe lifecycle tests; none of its byte counts are game evidence.
return function(options)
 options=options or {}
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{rememberFilters=options.rememberFilters~=false})
 local A,U,G=f.A,f.U,f.G
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 f.now,f.reads,f.nativeCalls=0,0,0
 GetTime=function() return f.now end
 GetBuildInfo=function() return "fixture","fixture",nil,0 end
 GetCVar=function() return "0" end
 debugprofilestop=function() return 0 end
 UpdateAddOnMemoryUsage=function()
  f.reads=f.reads+1
  if f.failRead and f.reads==f.failRead or f.failWhen and f.failWhen() then error("simulated observer failure") end
 end
 GetAddOnMemoryUsage=function() return 1000 end
 C_AddOns.IsAddOnLoaded=function() return true,true end
 C_ChallengeMode.IsChallengeModeActive=function() return false end
 C_LFGList.GetApplications=function() return {} end
 C_LFGList.GetLanguageSearchFilter=function() return {} end
 local nativeIDs={};for id=1,24 do nativeIDs[id]=id end
 C_LFGList.GetFilteredSearchResults=function() return #nativeIDs,nativeIDs end
 C_LFGList.Search=function()
  f.nativeCalls=f.nativeCalls+1
  C_Timer.NewTimer(.3,function() G.Search:OnResultsReceived() end)
 end
 dofile("addon/LycheeGroup_Group/Search.lua")
 G.Game={frame=CreateFrame("Frame"),RefreshSubscriptions=function() end}
 function G:GetSearchState() return self.Search:GetState() end
 function G:GetSearchError() return self.Search:GetSearchError() end
 function G:HasViews(kind) for _,value in pairs(self.views) do if not kind or value==kind then return true end end;return false end
 function G:Detach(view) self.views[view]=nil;if not self:HasViews("search") then self.Search:EndBrowse() end end
 function G:SetFilters(filters) self.Search:SetFilters(filters) end
 function G:OnEvent(event,id) self:Notify(event=="LFG_LIST_SEARCH_RESULT_UPDATED" and "result" or "results",id) end
 function G.Results:BeginSearch(generation) self.gen=generation;wipe(G.records) end
 function G.Results:FailSearch() wipe(G.records) end
 function G.Results:CommitResults(generation)
  self.gen=generation
  if not f.emptyResults then
   for id=1,24 do
    G.records[id]={id=id,name="Fixture group "..id,activity=G.Catalog:GetActivity(2),activityID=2,categoryID=2,maxNumPlayers=5,numMembers=1,leaderName="Fixture-Home",leaderKey="Fixture-Home",age=0,requiredItemLevel=0,bnetFriends=0,charFriends=0,guildMates=0,ratingKind="dungeon"}
   end
  end
  G:Notify("results")
 end
 local node=getmetatable(CreateFrame("Frame")).__index
 function node:GetAnimationGroups() end
 function node:GetName() return nil end
 function f:Advance(delta)
  self.now=self.now+delta;self.base.AdvanceClock(delta);U.Motion:Tick(delta)
 end
 function f:Start(script)
  local p={active=true,cleanup={}}
  function p:Async() return true end
  function p:Guard(check) return check() end
  function p:IsCancelled() return not self.active end
  function p:OnCleanup(fn) self.cleanup[#self.cleanup+1]=fn;return true end
  function p:Log(value) self.lastLog=value end
  function p:Close()
   if not self.active then return end
   self.active=false
   for i=#self.cleanup,1,-1 do self.cleanup[i]() end
  end
  function p:Finish(result) self.result=result;self:Close() end
  function p:Fail(reason) self.error=reason;self:Close() end
  function p:Callback(fn)
   return function(...)
    if not self.active then return end
    local function Run(...)
     if f.callbackError then error("simulated callback failure") end
     return fn(...)
    end
    local ok,err=pcall(Run,...);if not ok then self:Fail(err) end
   end
  end
  local ok,err=pcall(assert(loadfile(script)),p)
  if not ok then p:Fail(err) end
  return p
 end
 return f
end
