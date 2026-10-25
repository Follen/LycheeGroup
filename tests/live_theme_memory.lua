-- LycheeDev Theme v2 acceptance: real existing business, normal animation, 12 page/font cycles.
-- Button:Click is controller coverage. No hardware dispatch, forced GC, GC-policy changes or protected business actions.
local probe=...
local A=assert(LycheeGroup);assert(LycheeUI.version>=46 and A.RuntimeTheme and not InCombatLockdown())
assert(A.API.Theme.version==2 and A.API.Configuration.version==2,"cold_theme_api_not_loaded")
assert(not LycheeUI.Context.SetTheme and not LycheeUI.Context.SetRecipes,"runtime_theme_writes_remain")
assert(not LycheeUI.Context.StyleMemberIcon and not LycheeUI.Context.SetMemberIcon and not LycheeUI.Context.SetRoleIcon and not LycheeUI.Context.SetActivityIcon,'business interfaces remain in shared library')
local cfg=A.API.Configuration;local stores=A.Configuration.stores
local function Copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v)do out[k]=Copy(x)end;return out end
local function Same(a,b)if type(a)~='table' or type(b)~='table' then return a==b end;for k,v in pairs(a)do if not Same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local savedAccount,savedCharacter,savedSession=Copy(stores.account),Copy(stores.character),Copy(stores.session)
local initial=A.UI;assert(not initial or not initial.preview and not initial.activeModal)
local original={shown=initial and initial:IsShown(),page=initial and initial.page,returnPage=initial and initial.settingsReturnPage,section=initial and initial.pages.settings.section}
local originalPageShown={}
if initial then for key,page in pairs(initial.pages) do originalPageShown[key]=page.frame and page.frame:IsShown() or false end end
local U,P,timer,cleaned,completed
local group,oldFindPrefs,oldFindFilters
local function SaveFind()
 group=assert(A.Group)
 oldFindPrefs=group.prefs.find;oldFindFilters=Copy(group.Search:GetFilters())
 group.prefs.find=Copy(oldFindPrefs)
 if A.UI then A.UI.pages.find.loaded=nil;A.UI.pages.find.restoredInitial=nil end
end
local initialListing=A.Group and A.Group:GetListing()
assert(not C_LFGList.HasActiveEntryInfo() or initialListing,'listing restoration missing')
local listingActivity=initialListing and initialListing.activityID
local floatingShown=A.Floating and A.Floating.panel and A.Floating.panel:IsShown()
local out={themeAPI=2,revision=LycheeUI.version,build=select(2,GetBuildInfo()),samples={},search={},cycles={},stages=0,nativeClicks=0,fontChanges=0,budget=20000000,budgetPassed=true,peakBytes=0}
local started=GetTime()
out.mainBuiltAtStart=initial~=nil and initial.frame~=nil
out.initialFloatingPool=A.Floating and A.Floating.rows and #A.Floating.rows or 0
local function Memory(label)
 local start=debugprofilestop();UpdateAddOnMemoryUsage()
 local row={label=label,elapsedSeconds=GetTime()-started,bytes=0,packages={},observerRefreshMs=debugprofilestop()-start,luaHeapKiB=collectgarbage('count')}
 for _,name in ipairs({'LycheeGroup','LycheeGroup_Group','LycheeGroup_Notes','LycheeGroup_UI'})do local bytes=GetAddOnMemoryUsage(name)*1024;row.packages[name]=bytes;row.bytes=row.bytes+bytes end
 out.samples[#out.samples+1]=row;out.peakBytes=math.max(out.peakBytes,row.bytes);if row.bytes>out.budget then out.budgetPassed=false end
end
local function Clean()
 if cleaned then return end
 if timer then timer:Cancel()end
 if not U and A.UI and A.UI.frame then U=A.UI;P=U.pages.find end
 if U then U:CloseMenu();U.Tooltip:Hide() end
 local values,keys={},{}
 for _,key in ipairs({'settings.fontScale','settings.reduceMotion'})do local value=savedSession.user[key];if value==nil then keys[#keys+1]=key else values[key]=value end end
 if next(values)then assert(cfg:Set(values))end;if #keys>0 then assert(cfg:Reset(keys))end
 if U then
  U:Hide(true)
  if group then
   group.prefs.find=Copy(oldFindPrefs);P.loaded=nil;P.restoredInitial=nil
  end
  if original.shown then assert(A:Open(original.page,{section=original.section}))else
   for key,page in pairs(U.pages) do if page.frame then page.frame:SetShown(originalPageShown[key]==true) end end
   U.page=original.page;U:UpdateNav();U.Motion:FinishRect(U.underline)
  end
  U.settingsReturnPage=original.returnPage
  if original.section then U.pages.settings.section=original.section end
 end
 if group then group.Search:SetFilters(oldFindFilters);group.prefs.find=oldFindPrefs end
 if U and A.Floating then if floatingShown then A.Floating:ShowPanel()else A.Floating:Dismiss()end end
 cleaned=true
end
assert(probe:OnCleanup(function()
 Clean()
 if not completed then out.aborted=true;probe:Log(out)end
end));assert(probe:Guard(function()return not InCombatLockdown()end,{'PLAYER_REGEN_DISABLED'},'combat_started'))
assert(probe:Async(120))
assert(cfg:Set({['settings.fontScale']=100,['settings.reduceMotion']=false}))
Memory('before_main_open')
assert(A:Ensure('Group'));SaveFind()
assert(A:Open(initialListing and 'create' or 'find'));U=A.UI;P=U.pages.find
if P.filterPanel then
 local strata={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
 local shield=U.blocker;local shieldStrata=strata[shield:GetFrameStrata()];local shieldLevel=shield:GetFrameLevel()
 local targets={P.filterPanel,P.filterScrim}
 for _,entry in ipairs(P.filterHitTargets or {}) do targets[#targets+1]=entry.target end
 for _,target in ipairs(targets) do
  local layer=strata[target:GetFrameStrata()]
  assert(shieldStrata>layer or shieldStrata==layer and shieldLevel>target:GetFrameLevel(),'closing_input_shield_below_filter')
 end
 out.inputShield={strata=shield:GetFrameStrata(),level=shieldLevel,filterTargets=#targets}
end
Memory(initialListing and 'first_listing_manage' or 'first_find')
local tick,ready,attempt,index,lastLabel,resultWait
local sections={'general','interface','browse','memberIcons','blocks','notes','floating','about','credits'}
local pages={'find','create','notes','settings'}
out.settingsSections=#sections
local function Click(button)button:Click();out.nativeClicks=out.nativeClicks+1 end
tick=assert(probe:Callback(function()
 if lastLabel then
  if not initialListing and lastLabel:match('_find$') then
   local G=A.Group;local count,status=G:GetResultCount(),G:GetSearchState()
   if count==0 or status~='done' then
    resultWait=(resultWait or 0)+1
    if resultWait>=12 then
     out.incompleteCycle={label=lastLabel,count=count,state=status,error=G:GetSearchError()}
     probe:Log(out);Clean();completed=true;probe:Fail('cycle_search_results_unavailable');return
    end
    Memory(lastLabel..'_waiting_'..resultWait)
    timer=C_Timer.NewTimer(.5,tick);return
   end
   local visible=0
   assert(not P.results.refreshing and not G.Search.abandoned,'result_renderer_not_ready')
   assert(G.Results.gen==G.Search.generation,'result_generation_mismatch')
   for _,row in ipairs(P.results.rows)do
    if row.key and row._hitVisible then
     local record=assert(G:GetResult(row.key),'visible_result_missing')
     local text=G.Public(row.title:GetText());local name=G.Public(record.name)
     assert(text==nil or text==(name or U.L.unknown),'visible_result_title_mismatch')
     visible=visible+1
    end
   end
   local filtered=#G:GetResults()
   assert(filtered==0 or visible>0,'visible_result_rows_missing')
   out.cycles[#out.cycles+1]={label=lastLabel,count=count,filtered=filtered,visible=visible,state=status,generation=G.Search.generation,waits=resultWait or 0}
   resultWait=nil
  end
  Memory(lastLabel)
 end
 index=index+1
 if index<=#sections then
  Click(U.pages.settings.nav[sections[index]])
  lastLabel='settings_'..sections[index]
 elseif index<=#sections+12*#pages then
  local n=index-#sections-1;local cycle=math.floor(n/#pages)+1;local page=pages[n%#pages+1]
  if page=='settings' then Click(U.settingsButton)else Click(U.navItems[page])end
  assert(U.page==page,'native navigation failed: '..page)
  if page=='settings' then
   assert(cfg:Set({['settings.fontScale']=cycle%2==1 and 130 or 100}));out.fontChanges=out.fontChanges+1
  end
  lastLabel='cycle_'..cycle..'_'..page
 else
  Clean();Memory('restored_natural')
  out.accountUnchanged=Same(savedAccount,stores.account);out.characterUnchanged=Same(savedCharacter,stores.character);out.sessionRestored=Same(savedSession,stores.session)
  assert(out.accountUnchanged and out.characterUnchanged and out.sessionRestored,'configuration restore')
  if not original.shown then assert(not U:IsShown() and not U.Native.searchLease and U.Motion:Count()==0,'closed cleanup')end
  local finalListing=A.Group:GetListing()
  out.initialListingActivity=listingActivity
  out.finalListingActivity=finalListing and finalListing.activityID
  out.listingUnchanged=not initialListing or finalListing~=nil and finalListing.activityID==listingActivity
  out.finalPools={find=#P.results.rows,applications=#P.appList.rows,floatingRows=A.Floating and #A.Floating.rows or 0,floatingBatches=A.Floating and #A.Floating.batches or 0}
  out.scope='native Button:Click navigation and public session font writes; no hardware dispatch, forced GC, GC-policy changes or protected business actions'
  if not out.listingUnchanged then probe:Log(out);completed=true;probe:Fail('listing_changed_during_observation');return end
  out.resourcesReleased=cleaned;out.elapsedSeconds=GetTime()-started
  completed=true
  probe:Finish(out);return
 end
 out.stages=index;timer=C_Timer.NewTimer(.75,tick)
end))
attempt=0
ready=assert(probe:Callback(function()
 attempt=attempt+1;local G=A.Group
 if initialListing then
  assert(G:GetListing() and G:GetListing().activityID==listingActivity,'listing was lost')
  out.liveListing={activityID=listingActivity,applicants=#G:GetApplicants()}
  if A.Floating then A.Floating:ShowPanel()end
  Memory('actual_listing_and_floating_applicants')
  if A.Floating then A.Floating:Dismiss()end
  Click(U.settingsButton);assert(U.page=='settings')
  index=0;lastLabel=nil;timer=C_Timer.NewTimer(.75,tick);return
 end
 out.search[#out.search+1]={attempt=attempt,count=G:GetResultCount(),state=G:GetSearchState()}
 if G:GetResultCount()==0 then
  if attempt>=12 then probe:Log(out);Clean();probe:Fail('real_results_unavailable');return end
  timer=C_Timer.NewTimer(2,ready);return
 end
 local row=assert(P.results.rows[1]);local result=assert(G:GetResult(row.key))
 U.Tooltip:ShowGroup(row,result);out.realResult=row.key;Memory('real_results_tooltip')
 U.Tooltip:Hide();Click(U.settingsButton);assert(U.page=='settings')
 index=0;lastLabel=nil;timer=C_Timer.NewTimer(.75,tick)
end))
timer=C_Timer.NewTimer(2,ready)
