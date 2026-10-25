-- Real Preview/Find/Search and transfer controllers; counters and business data are substitutes.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
for _,mode in ipairs({"complete","remember_off","late_pool_growth","cancel","cancel_raid","cancel_applicants","observer_error","prepare_failure"}) do
 local f=dofile("tests/live_probe_fixture.lua")({rememberFilters=mode~="remember_off"})
 local A,U,G=f.A,f.U,f.G
 EJ_GetDifficulty=function() return 15 end;EJ_SetDifficulty=function() end
 EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
 C_LFGList.GetActivityInfoTable(1).difficultyID=15
 for _,page in ipairs({"find","create","notes","settings"}) do A:Open(page);U:Hide(true) end
 local oldPrefs,oldPage,oldReturn=G.prefs.find,U.page,U.settingsReturnPage
 local oldRemember=A:GetSetting("rememberFilters")
 if mode=="observer_error" then f.failWhen=function() return U.preview and U.preview.scenario=="applications" end end
 if mode=="prepare_failure" then
  local get=G.Catalog.GetActivities
  G.Catalog.GetActivities=function(self,key) if key=="seasonRaid" then return {} end;return get(self,key) end
 end
 if mode=="late_pool_growth" then
  local list=U.pages.find.results
  local setOffset,calls=list.SetPixelOffset,0
  list.SetPixelOffset=function(self,...)
   local result=setOffset(self,...)
   if U.preview and U.preview.scenario=="applications" then
    calls=calls+1
    if calls==81 then
     local height=self:GetHeight()
     self:SetHeight(height+self.rowHeight*4);self:SetItems(self.ids,self.render)
     self:SetHeight(height);self:SetItems(self.ids,self.render)
    end
   end
   return result
  end
 end
 local p=f:Start("tests/live_memory_scenarios.lua")
 for tick=1,1100 do
  if mode=="cancel" and tick==2 then p:Close() end
  if mode=="cancel_raid" and U.preview and U.preview.scenario=="applications" then p:Close() end
  if mode=="cancel_applicants" and U.preview and U.preview.scenario=="applicants" then p:Close() end
  f:Advance(.1)
  if not p.active then break end
 end
 Check(not p.active,mode.." completes within its bound")
 if mode=="complete" or mode=="remember_off" then
  if p.result then for key,value in pairs(p.result.checks) do Check(value,mode.." report check: "..key) end end
  Check(p.result and p.result.ok,tostring(p.error or "report failed"))
  Check(p.result.fixture.visiblePreviewResults==100 and p.result.fixture.boundPreviewResults==100,"all raid groups pass real Preview/Find filtering")
  Check(p.result.checks.raidScrolled and p.result.checks.raidFirstRowChanged,"full bound list actually scrolls")
  Check(p.result.fixture.initialFindPool<p.result.fixture.findPoolAtFirstBind and p.result.fixture.initialBatchPool<p.result.fixture.batchPoolAtFirstBind,"first full lists legitimately grow both empty-state pools")
  Check(p.result.fixture.findPoolAfterFirstTraversal>p.result.fixture.findPoolAtFirstBind,"first scroll warms partially visible edge rows")
  Check(p.result.operations.raidScroll>=81 and p.result.operations.applicantScroll>=81,"each pool is observed through a complete repeated traversal")
  Check(#p.result.codec==3 and p.result.operations.applicantRefresh>0,"applicants and codec phases complete")
 elseif mode=="late_pool_growth" then
  Check(p.result and p.result.checks.poolsReused==false and p.result.ok==false,"pool growth after the fixed warmup must fail")
 elseif mode=="prepare_failure" then Check(p.error and p.error:find("raid_activity_missing",1,true),tostring(p.error))
 elseif mode=="observer_error" then Check(p.error and p.error:find("simulated observer failure",1,true),tostring(p.error))
 else Check(p.result==nil,"cancellation cannot report completion") end
 Check(G.prefs.find==oldPrefs and A:GetSetting("rememberFilters")==oldRemember,mode.." real preference source and reference preserved")
 Check(not U:IsShown() and not U.preview and U.page==oldPage and U.settingsReturnPage==oldReturn and not U.Native.searchLease and U.Motion:Count()==0,mode.." Preview and UI owners restored")
 Check(U._nav==oldPage and U.settingsButton.active==(oldPage=="settings"),mode.." navigation presentation restored")
 local reads=f.reads
 for tick=1,12 do f:Advance(.25) end
 Check(f.reads==reads and not G:HasViews(),mode.." late callbacks remain inactive")
 assert(A:Open(oldPage))
 for key,page in pairs(U.pages) do if page.frame then Check(page.frame:IsVisible()==(key==oldPage),mode.." reopen shows only original page: "..key) end end
 U.settingsButton:Fire("OnClick","LeftButton");Check(U.page==oldReturn,mode.." settings button returns to the original source");U:Hide(true)
end
print("Supplementary memory probe lifecycle: "..checks.." checks passed")
