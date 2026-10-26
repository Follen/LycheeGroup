-- Lifecycle and preference preservation through the real Find/Search controllers.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
for _,mode in ipairs({"complete","remember_off","late_pool_growth","cancel","prepare_failure","observer_error","warm_open_failure"}) do
 local f=dofile("tests/live_probe_fixture.lua")({rememberFilters=mode~="remember_off"})
 local A,U,G=f.A,f.U,f.G
 local guideLoaded=mode=="remember_off"
 C_AddOns.IsAddOnLoaded=function(name) return true,name~="LycheeGroup_Guide" or guideLoaded end
 GetAddOnMemoryUsage=function(name) return name=="LycheeGroup_Guide" and (guideLoaded and 512 or 0) or 1000 end
 A:Open("create");A:Open("settings");U:Hide(true)
 G.Search:SetFilters({sort="rating",maxMembers=4})
 local oldPrefs,oldPage,oldReturn=G.prefs.find,U.page,U.settingsReturnPage
 local oldRemember=A:GetSetting("rememberFilters")
 if mode=="prepare_failure" then f.emptyResults=true end
 if mode=="observer_error" then f.failRead=8 end
 local open=A.Open
 if mode=="warm_open_failure" then
  A.Open=function(self,page,...)
   local result=open(self,page,...)
   if page=="settings" then error("simulated open failure") end
   return result
  end
 end
 local p=f:Start("tests/live_list_memory.lua")
 A.Open=open
 for tick=1,1000 do
  if mode=="cancel" and tick==2 then p:Close() end
  if mode=="late_pool_growth" and tick==30 then
   local list=U.pages.find.results;local height=list:GetHeight()
   list:SetHeight(height+list.rowHeight*4);list:SetItems(list.ids,list.render)
   list:SetHeight(height);list:SetItems(list.ids,list.render)
  end
  f:Advance(.1)
  if not p.active then break end
 end
 Check(not p.active,mode.." completes within its bound")
 if mode=="complete" or mode=="remember_off" then
  Check(p.result and p.result.ok,tostring(p.error or "report failed"))
  Check(#p.result.packages==5 and p.result.packages[5]=="LycheeGroup_Guide","the report includes the Guide package")
  for _,sample in ipairs(p.result.samples) do
   Check(sample.loaded[5]==guideLoaded,"sampling does not require loading Guide")
   Check(sample.addonTotalKB==4000+(guideLoaded and 512 or 0),"Guide retention contributes to the simultaneous product total")
  end
  Check(p.result.resultPoolAtStart==p.result.resultPoolBeforeWarm+1,"warmup includes the extra partially visible row")
  Check(f.nativeCalls==1,"exactly one native search")
  Check(p.result.initialRealResults==24 and p.result.initialBoundResults==24,"real Find bound the substitute results")
  Check(p.result.operations[1].calls==320 and p.result.operations[2].calls==320,"complete workload ran")
 elseif mode=="late_pool_growth" then
  Check(p.result and not p.result.ok,"growth after warmup must still fail")
  Check(not p.result.checks.resultPoolStable and not p.result.checks.nativeObjectsStable,"both row and native object growth are detected")
 elseif mode=="prepare_failure" then Check(p.error and p.error:find("real_results_empty",1,true),tostring(p.error))
 elseif mode=="observer_error" then Check(p.error and p.error:find("simulated observer failure",1,true),tostring(p.error))
 elseif mode=="warm_open_failure" then Check(p.error and p.error:find("simulated open failure",1,true),tostring(p.error))
 else Check(p.result==nil,"cancellation cannot report completion") end
 local filters=G.Search:GetFilters()
 Check(filters.sort=="rating" and filters.maxMembers==4 and filters.category==nil,mode.." initial filters restored")
 Check(G.prefs.find==oldPrefs and A:GetSetting("rememberFilters")==oldRemember,mode.." preference source and reference preserved")
 Check(not U:IsShown() and U.page==oldPage and U.settingsReturnPage==oldReturn and not U.Native.searchLease and U.Motion:Count()==0,mode.." UI owners and navigation restored")
 Check(U._nav==oldPage and U.settingsButton.active==(oldPage=="settings"),mode.." navigation presentation restored")
 local reads=f.reads
 for tick=1,12 do f:Advance(.25) end
 Check(f.reads==reads and G:GetResultCount()==0 and not G:HasViews(),mode.." late callbacks remain inactive")
 assert(A:Open(oldPage))
 for key,page in pairs(U.pages) do if page.frame then Check(page.frame:IsVisible()==(key==oldPage),mode.." reopen shows only original page: "..key) end end
 U.settingsButton:Fire("OnClick","LeftButton");Check(U.page==oldReturn,mode.." settings button returns to the original source");U:Hide(true)
end
print("List memory probe lifecycle: "..checks.." checks passed")
