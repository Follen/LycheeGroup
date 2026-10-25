-- One warm, real Find scenario. All counters wrap only product-owned objects.
-- Prerequisite: r46, out of combat, visible Find, no modal/preview/menu/filter/picker,
-- and settled search. No Blizzard/global hooks, CVar writes, GC or business actions.
local probe=...
local A=assert(LycheeGroup,'product_unavailable')
assert(LycheeUI and LycheeUI.version==46,'revision_46_required')
assert(not InCombatLockdown(),'combat_started')
local U=assert(A.UI,'warm_ui_required')
local P=assert(U.pages and U.pages.find,'warm_find_required')
local G=assert(A.Group,'warm_group_required')
assert(U.frame and P.frame and U:IsShown() and U.page=='find' and not U.hiding,'visible_find_required')
assert(not U.preview and not U.activeModal and not U.context:IsMenuOpen(),'exclusive_transient_ui_required')
assert(not P.filtersOpen and not P.filterPanel:IsShown() and (not P.picker or not P.picker:IsShown()),'closed_picker_filter_required')
assert(not U.Tooltip.owner,'closed_tooltip_required')
assert(G:GetSearchState()~='searching' and G:GetSearchState()~='waiting','settled_search_required')
assert(#G.Catalog:GetCategories()>0,'catalog_required')
assert(A:GetSetting('reduceMotion')==false,'normal_animation_required')
local cfg=assert(A.API.Configuration)
local stores=assert(A.Configuration.stores)
local function Copy(value)
 if type(value)~='table' then return value end
 local out={};for key,item in pairs(value) do out[key]=Copy(item) end;return out
end
local function Same(left,right)
 if type(left)~='table' or type(right)~='table' then return left==right end
 for key,item in pairs(left) do if not Same(item,right[key]) then return false end end
 for key in pairs(right) do if left[key]==nil then return false end end
 return true
end
local saved={account=Copy(stores.account),character=Copy(stores.character),session=Copy(stores.session),
 font=A:GetSetting('fontScale'),motion=A:GetSetting('reduceMotion'),sessionFont=stores.session.user['settings.fontScale'],
 prefs=G.prefs.find,prefsValue=Copy(G.prefs.find),filters=G.Search:GetFilters(),
 returnPage=U.settingsReturnPage,section=U.pages.settings.section,pageShown={},floating=A.Floating and A.Floating.panel and A.Floating.panel:IsShown() or false}
saved.filterValues=Copy(saved.filters)
for key,page in pairs(U.pages) do saved.pageShown[key]=page.frame and page.frame:IsShown() or false end
local methods,labels={},{}
local timer,tick,restored,finished,stage,phase,waits
local counts={refresh=0,bind=0,render=0,width={0,0}}
local report={revision=LycheeUI.version,build=select(2,GetBuildInfo()),scope='warm_real_find_hidden_picker_and_fixed_captions',
 iterationsPerPhase=100,captionCount=2,realResultsAtStart=G:GetResultCount(),pooledResultRows=#P.results.rows,phases={},nativeBusinessActions=0,globalHooks=0,cvarWrites=0,forcedGC=0,defaultMotion=true}
local function RestoreMethods()
 for _,entry in ipairs(methods) do entry.object[entry.key]=entry.method end
end
local function Restore()
 if timer then timer:Cancel();timer=nil end
 if restored then return end
 restored=true
 RestoreMethods()
 U:CloseMenu();U.Tooltip:Hide();U:Hide(true)
 local ok,err
 if saved.sessionFont==nil then ok,err=cfg:Reset({'settings.fontScale'},{storage='session'})
 else ok,err=cfg:Set({['settings.fontScale']=saved.sessionFont},{storage='session'}) end
 assert(ok,err)
 G.prefs.find=saved.prefs
 -- The original filters table stays untouched while the probe-owned Find leave
 -- and normal reentry use the isolated table. Restore its exact public reference.
 local reopened,reason=A:Open('find');assert(reopened,reason)
 G.Search.filters=saved.filters
 U.settingsReturnPage=saved.returnPage
 U.pages.settings.section=saved.section
 if A.Floating then if saved.floating then A.Floating:ShowPanel() else A.Floating:Dismiss() end end
 report.restored={shown=U:IsShown(),page=U.page,font=A:GetSetting('fontScale'),
  filtersReference=G.Search:GetFilters()==saved.filters,filtersValues=Same(saved.filters,saved.filterValues),
  prefsReference=G.prefs.find==saved.prefs,prefsValues=Same(G.prefs.find,saved.prefsValue),
  account=Same(stores.account,saved.account),character=Same(stores.character,saved.character),session=Same(stores.session,saved.session),
  methods=true,pageVisibility=true,returnPage=U.settingsReturnPage==saved.returnPage,section=U.pages.settings.section==saved.section}
 for key,page in pairs(U.pages) do if (page.frame and page.frame:IsShown() or false)~=saved.pageShown[key] then report.restored.pageVisibility=false end end
 for _,entry in ipairs(methods) do if entry.object[entry.key]~=entry.method then report.restored.methods=false end end
end
assert(probe:OnCleanup(function()
 Restore()
 if not finished then report.aborted=true;probe:Log(report) end
end))
assert(probe:Guard(function() return not InCombatLockdown() end,{'PLAYER_REGEN_DISABLED'},'combat_started'))
assert(probe:Async(25))
-- Preserve actual filter references and persistent preferences before any
-- ordinary close/reopen can use Search:SetFilters or Find:SavePrefs.
G.Search.filters=Copy(saved.filters)
G.prefs.find=Copy(saved.prefs)
local function Wrap(object,key,wrapper)
 local method=assert(object[key],key..'_unavailable')
 methods[#methods+1]={object=object,key=key,method=method}
 object[key]=wrapper(method)
end
local function ResetCounts()
 counts.refresh,counts.bind,counts.render=0,0,0;counts.width[1],counts.width[2]=0,0
end
local function Schedule(delay) timer=C_Timer.NewTimer(delay,tick) end
local function Scene()
 assert(not InCombatLockdown(),'combat_started')
 assert(not U.preview and not U.activeModal and not U.context:IsMenuOpen(),'scene_changed')
 assert(U:IsShown() and U.page=='find' and not U.hiding,'find_scene_changed')
 assert(not P.picker:IsShown() and not P.filterPanel:IsShown(),'picker_filter_changed')
end
local function ClosedChecks()
 local leases=U.Native.searchLease==nil and U.Native.titleInput==nil and U.Native.descriptionInput==nil
 local stopped=U.Motion:Count()==0 and P.frame:GetScript('OnUpdate')==nil and U.frame:GetScript('OnUpdate')==nil
 local pageReleased=P.unsub==nil and P.notesUnsub==nil and P.pickerScoreService==nil and P.countdown==nil and P.declineClock==nil
 report.closed={shown=U:IsShown(),leasesReleased=leases,motionJobs=U.Motion:Count(),settleStopped=stopped,pageReleased=pageReleased,
  resultsReleased=P.results.ids==nil or #P.results.ids==0,applicationsReleased=P.appList.ids==nil or #P.appList.ids==0,
  hiddenRefresh=counts.refresh,hiddenBind=counts.bind,hiddenRender=counts.render}
 assert(not U:IsShown() and not U.hiding and leases and stopped and pageReleased,'close_resources_retained')
 assert(report.closed.resultsReleased and report.closed.applicationsReleased,'close_rows_retained')
 assert(counts.refresh==0 and counts.bind==0 and counts.render==0,'close_picker_work')
end
tick=assert(probe:Callback(function()
 if probe:IsCancelled() then return end
 if stage=='closed' then
  if U:IsShown() then waits=waits+1;assert(waits<=8,'close_did_not_settle');Schedule(.15);return end
  ClosedChecks();Restore();stage='restored';Schedule(1.6);return
 elseif stage=='restored' then
  assert(report.restored.shown and report.restored.page=='find' and report.restored.font==saved.font,'route_font_restore')
  for key,value in pairs(report.restored) do if type(value)=='boolean' then assert(value,'restore_'..key) end end
  assert(A:GetSetting('reduceMotion')==saved.motion,'motion_setting_changed')
  finished=true;probe:Finish(report);return
 elseif stage=='initial' then
  Scene()
  if P.frame:GetScript('OnUpdate') or U.frame:GetScript('OnUpdate') then waits=waits+1;assert(waits<=8,'initial_settle_timeout');Schedule(.15);return end
  stage='font';phase=0
 end
 if stage=='font' then
  Scene();phase=phase+1;waits=0;ResetCounts()
  local scale=phase==1 and 130 or 100
  local ok,err=cfg:Set({['settings.fontScale']=scale},{storage='session'});assert(ok,err)
  assert(A:GetSetting('fontScale')==scale and U.context.fontScale==scale/100,'font_scale_not_applied')
  stage='measure';Schedule(.35);return
 elseif stage=='measure' then
  Scene()
  if P.frame:GetScript('OnUpdate') or U.frame:GetScript('OnUpdate') then waits=waits+1;assert(waits<=8,'font_settle_timeout');Schedule(.15);return end
  assert(counts.refresh==0 and counts.bind==0 and counts.render==0,'hidden_picker_rebuilt_on_font')
  local warm={counts.width[1],counts.width[2]}
  assert(warm[1]>0 and warm[2]>0,'font_change_did_not_remeasure_captions')
  ResetCounts()
  local started=debugprofilestop()
  for iteration=1,100 do P:LayoutApplicationControls() end
  local elapsed=debugprofilestop()-started
  local output={fontScale=phase==1 and 130 or 100,warmWidthReads=warm,widthReads={counts.width[1],counts.width[2]},
   hiddenRefresh=counts.refresh,hiddenBind=counts.bind,hiddenRender=counts.render,iterations=100,instrumentedLayoutMs=elapsed,widths={},nativeWidths={}}
  for index,entry in ipairs(labels) do
   local native=entry.method(entry.object)
   output.widths[index],output.nativeWidths[index]=entry.object:GetWidth(),native
   assert(math.abs(output.widths[index]-(math.ceil(native)+2))<.02,'caption_geometry_mismatch')
  end
  report.phases[#report.phases+1]=output
  assert(counts.width[1]==0 and counts.width[2]==0,'steady_captions_remeasured')
  assert(counts.refresh==0 and counts.bind==0 and counts.render==0,'steady_picker_work')
  if phase<2 then stage='font';Schedule(.1);return end
  -- Positive control: a real OnShow still refreshes and binds the picker.
  ResetCounts();P.picker:Show()
  report.positiveControl={refresh=counts.refresh,bind=counts.bind,render=counts.render}
  assert(counts.refresh>0 and counts.bind>0,'picker_show_positive_control_missing')
  P:ClosePicker();ResetCounts()
  U:Hide();stage='closed';waits=0;Schedule(.7);return
 end
end))
-- Build only the real product's existing hidden picker shell if still lazy.
if not P.picker then P:BuildPicker() end
Wrap(P,'RefreshPicker',function(method) return function(self,...) counts.refresh=counts.refresh+1;return method(self,...) end end)
Wrap(P.activities,'SetItems',function(method) return function(self,ids,renderer,...)
 counts.bind=counts.bind+1
 return method(self,ids,function(...) counts.render=counts.render+1;return renderer(...) end,...)
end end)
for index,label in ipairs({P.autoJoin.label,P.applicationSettings.label}) do
 labels[index]={object=label,method=label.GetUnboundedStringWidth}
 Wrap(label,'GetUnboundedStringWidth',function(method) return function(self,...)
  counts.width[index]=counts.width[index]+1;return method(self,...)
 end end)
end
assert(cfg:Set({['settings.fontScale']=100},{storage='session'}))
stage='initial';waits=0;Schedule(1.6)
