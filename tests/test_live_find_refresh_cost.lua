-- Offline lifecycle testing only. Fake API counters do not establish game timings.
local script='tests/live_find_refresh_cost.lua'
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Copy(value) if type(value)~='table' then return value end;local out={};for key,item in pairs(value) do out[key]=Copy(item) end;return out end
local function Same(left,right)
 if type(left)~='table' or type(right)~='table' then return left==right end
 for key,item in pairs(left) do if not Same(item,right[key]) then return false end end
 for key in pairs(right) do if left[key]==nil then return false end end;return true
end
for _,mode in ipairs({'complete','repeat','warm_session_override','regressed_picker','regressed_caption','cancel_initial','cancel_font','cancel_close','cancel_restored','timeout','callback_error','combat','missing_group','wrong_revision','wrong_scene','font_error','layout_error'}) do
 local f=dofile('tests/live_probe_fixture.lua')()
 local a,u,g=f.A,f.U,f.G
 a:SetSetting('reduceMotion',false)
 if mode=='warm_session_override' then assert(a.API.Configuration:Set({['settings.fontScale']=115},{storage='session'})) end
 g.prefs.find={category='seasonDungeon',categoryPrefs={seasonDungeon={selected=true,difficultyID=8}},filters={selected=true,difficultyID=8,sort='rating'}}
 local function Pump(seconds)
  for step=1,math.ceil(seconds/.05) do
   f.S.preciseNow=f.S.preciseNow+.05;f:Advance(.05)
   for _,frame in ipairs({u.frame,u.pages.find.frame,u.pages.create.frame,u.pages.notes.frame,u.pages.settings.frame}) do
    if frame and frame:IsVisible() and frame:GetScript('OnUpdate') then frame:Fire('OnUpdate',.05) end
   end
  end
 end
 a:Open('find');Pump(2)
 Check(g:GetSearchState()=='done',mode..' settled fixture search')
 local p=u.pages.find
 if mode~='complete' then p:BuildPicker() end
 local originalRefresh,originalBind=p.RefreshPicker,p.activities and p.activities.SetItems
 local originalWidths={p.autoJoin.label.GetUnboundedStringWidth,p.applicationSettings.label.GetUnboundedStringWidth}
 local originalReflow=p.ReflowMetrics
 if mode=='regressed_picker' then p.ReflowMetrics=function(self,...) local value=originalReflow(self,...);if self.picker then self:RefreshPicker() end;return value end end
 local oldFilters,oldValues=g.Search:GetFilters(),Copy(g.Search:GetFilters())
 local oldPrefs,oldPrefsValue=g.prefs.find,Copy(g.prefs.find)
 local stores=Copy(a.Configuration.stores)
 local oldFont,oldMotion=a:GetSetting('fontScale'),a:GetSetting('reduceMotion')
 local originalLayout=p.LayoutApplicationControls
 local layoutCalls=0
 if mode=='regressed_caption' then p.LayoutApplicationControls=function(self,...) self:InvalidateApplicationControlMetrics();return originalLayout(self,...) end end
 if mode=='layout_error' then p.LayoutApplicationControls=function(self,...)
  layoutCalls=layoutCalls+1
  if layoutCalls==25 then error('simulated target layout failure') end
  return originalLayout(self,...)
 end end
 local configuration=a.API.Configuration
 local originalSet=configuration.Set
 local failed=false
 if mode=='font_error' then configuration.Set=function(self,values,...)
  if values['settings.fontScale']==130 and not failed then failed=true;error('simulated font write failure') end
  return originalSet(self,values,...)
 end end
 if mode=='missing_group' then a.Group=nil end
 if mode=='wrong_revision' then LycheeUI.version=45 end
 if mode=='wrong_scene' then u:Hide(true) end
 local originalTimer=C_Timer.NewTimer
 local late;local probeTimers={}
 C_Timer.NewTimer=function(delay,callback)
  if delay==1.6 and not late then late=callback end
  local handle=originalTimer(delay,callback);if callback==late then probeTimers[#probeTimers+1]=handle end;return handle
 end
 local probe=f:Start(script)
 for step=1,240 do
  if mode=='cancel_initial' and step==4 or mode=='cancel_font' and step==35 or mode=='cancel_close' and step==50 or mode=='cancel_restored' and step==65 then probe:Close() end
  if mode=='timeout' and step==35 then probe:Fail('probe_timeout') end
  if mode=='callback_error' and step==35 then f.callbackError=true end
  if mode=='combat' and step==35 then InCombatLockdown=function() return true end end
  Pump(.05)
  if not probe.active then break end
 end
 C_Timer.NewTimer=originalTimer;configuration.Set=originalSet;a.Group=g
 Check(not probe.active,mode..' bounded termination')
 if mode=='complete' or mode=='repeat' or mode=='warm_session_override' then
  Check(probe.result,tostring(probe.error))
  Check(#probe.result.phases==2 and probe.result.phases[1].iterations==100 and probe.result.phases[2].iterations==100,'both bounded font phases')
  Check(probe.result.closed.motionJobs==0 and probe.result.closed.leasesReleased,'ordinary close releases jobs and native leases')
  Check(probe.result.positiveControl.refresh>0 and probe.result.positiveControl.bind>0,'positive control exercises real picker')
 elseif mode:find('cancel',1,true) then Check(not probe.result and not probe.error,'cancellation reports no successful result')
 elseif mode=='regressed_picker' then Check(probe.error and probe.error:find('hidden_picker_rebuilt_on_font',1,true),'detects old hidden picker work')
 elseif mode=='regressed_caption' then Check(probe.error and probe.error:find('steady_captions_remeasured',1,true),'detects old repeated caption measurement')
 else Check(probe.error~=nil,mode..' expected failure') end
 if mode~='wrong_scene' and mode~='wrong_revision' and mode~='missing_group' then
  Check(a:GetSetting('fontScale')==oldFont and a:GetSetting('reduceMotion')==oldMotion,mode..' live preferences restored')
  Check(g.Search:GetFilters()==oldFilters and Same(oldFilters,oldValues),mode..' exact Group filters reference and contents restored')
  Check(g.prefs.find==oldPrefs and Same(g.prefs.find,oldPrefsValue),mode..' original Find preference reference and values restored')
  Check(Same(a.Configuration.stores,stores),mode..' all config stores restored')
  Check(u:IsShown() and u.page=='find' and not u.hiding,mode..' original route and shown state restored')
  Check(p.RefreshPicker==originalRefresh,'exact picker method restored')
  if originalBind then Check(p.activities.SetItems==originalBind,'exact list method restored') end
  Check(p.autoJoin.label.GetUnboundedStringWidth==originalWidths[1] and p.applicationSettings.label.GetUnboundedStringWidth==originalWidths[2],'exact product FontString methods restored')
  Check(probeTimers[#probeTimers] and probeTimers[#probeTimers].cancelled,'last owned timer is cancelled on every exit')
 end
 local before={font=a:GetSetting('fontScale'),shown=u:IsShown(),page=u.page,filters=g.Search:GetFilters(),result=probe.result,error=probe.error}
 if late then late() end
 Check(a:GetSetting('fontScale')==before.font and u:IsShown()==before.shown and u.page==before.page and g.Search:GetFilters()==before.filters and probe.result==before.result and probe.error==before.error,mode..' late wrapped callback does nothing')
 f.callbackError=nil;InCombatLockdown=function() return false end;LycheeUI.version=46
 Pump(2)
 if mode=='repeat' then
  local second=f:Start(script);for step=1,240 do Pump(.05);if not second.active then break end end
  Check(second.result,tostring(second.error));Check(Same(a.Configuration.stores,stores),'repeated complete execution restores stores')
 end
 p.ReflowMetrics=originalReflow;p.LayoutApplicationControls=originalLayout
 u:Hide(true);Pump(.5)
 Check(u.Motion:Count()==0 and u.Native.searchLease==nil,'final normal user close releases UI')
 Check(f.base.PendingTimers()==0,'final user close leaves no owned or fixture search timer')
end
print('Find hidden-picker/caption live probe lifecycle: '..checks..' checks passed')
