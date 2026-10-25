-- Run from LycheeGroup: lua tests/test_live_layout_profile.lua [../LycheeUI]
-- Lifecycle/contract fixtures only; fake clocks and native substitutes prove no live cost.
local libraryDir=arg[1] or '../LycheeUI'
local script='tests/live_layout_profile.lua'
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local keys={'GetWidth','GetHeight','SetWidth','SetHeight','SetSize','GetPoint','GetNumPoints','SetPoint','ClearAllPoints',
 'GetStringWidth','GetUnboundedStringWidth','GetStringHeight','GetFont','GetSpacing','CanWordWrap','GetText'}
local function Run(mode,capability,optional)
 local S=dofile(libraryDir..'/tests/stubs.lua');S.Install();_G.LycheeUI=nil
 local private={}
 for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do
  assert(loadfile(libraryDir..'/'..file..'.lua'))('LayoutProfileTest',private)
 end
 local actual=LycheeUI
 local selected=setmetatable({layoutModes=capability and {flex=true} or false},{__index=actual})
 local layouts,modeOptions={},{}
 local operationsThisCallback,maxOperations=0,0
 function selected:CreateContext(options)
  if mode=='setup_error' then error('injected_context_failure') end
  local context=actual.CreateContext(self,options)
  for _,name in ipairs({'Row','Column'}) do
   local factory=context.C[name]
   context.C[name]=function(parent,items,options)
    modeOptions[#modeOptions+1]=options.mode or 'legacy'
    local layout=factory(parent,items,options);layouts[#layouts+1]=layout
    local run=layout.Layout
    function layout:Layout(...)
     operationsThisCallback=operationsThisCallback+1
     local counting=rawget(items[1].frame,'GetWidth')~=nil
     if mode=='write_failure' and counting then
      items[1].frame:SetWidth(37)
      error('injected_after_native_write')
     end
     if mode=='native_growth' and counting and not selected.grew then
      selected.grew=true;CreateFrame('Frame',nil,parent)
     end
     local result=run(self,...)
     if mode=='pixel_mismatch' and options and options.mode=='flex' and counting then
      local point,relative,relativePoint,x,y=items[1].frame:GetPoint()
      local pixelUnit=768/1080/(items[1].frame:GetEffectiveScale() or 1)
      items[1].frame:SetPoint(point,relative,relativePoint,x+pixelUnit*1.25,y)
     end
     return result
    end
    return layout
   end
  end
  return context
 end
 _G.LycheeUI=selected
 GetBuildInfo=function() return 'fixture','offline-build','date',120000 end
 GetPhysicalScreenSize=function() return 1920,mode=='native_roundtrip' and 1024 or 1080 end
 local inCombat=mode=='combat'
 InCombatLockdown=function() return inCombat end
 local clock=0
 debugprofilestop=function() clock=clock+.001;return clock end
 if mode=='missing_clock' then debugprofilestop=nil end
 local gcCalls={}
 local originalGC=collectgarbage
 collectgarbage=function(operation,...)
  gcCalls[#gcCalls+1]=operation;assert(operation=='count','GC policy mutation');return originalGC(operation,...)
 end
 local done,report,failed,logged,cleanup
 local cleanups,callbacks,guards={},{},{}
 local probe={}
 local function Stop()
  if done then return end
  done=true
  for index=#cleanups,1,-1 do cleanup=cleanups[index]() end
 end
 function probe:OnCleanup(fn) cleanups[#cleanups+1]=fn;return true end
 function probe:Guard(fn,events,reason)
  Check(fn(),'valid initial guard');Check(events[1]=='PLAYER_REGEN_DISABLED','combat event guard')
  guards[#guards+1]={fn=fn,reason=reason};return true
 end
 function probe:Async(seconds) Check(seconds==30,'30 second deadline');return true end
 function probe:IsCancelled() return done==true end
 function probe:Log(value) logged=value end
 function probe:Fail(reason) failed=reason;Stop();return true end
 function probe:Finish(value) report=value;Stop();return true end
 function probe:Callback(fn)
  local callback=function(...)
   if done then return end
   for _,guard in ipairs(guards) do if not guard.fn() then probe:Fail(guard.reason);return end end
   local ok,reason=pcall(fn,...)
   if not ok then probe:Fail(tostring(reason)) end
  end
  callbacks[#callbacks+1]=callback;return callback
 end
 if mode=='native_roundtrip' then probe._offlineGeometryReadback={object=1,axis='height',delta=1.39e-5} end
 if mode=='missing_library' then _G.LycheeUI=nil end
 local ok,reason=pcall(assert(loadfile(script)),probe,optional and selected or nil)
 if not ok then probe:Fail(tostring(reason)) end
 local baseline={}
 for _,object in ipairs(S.nodes) do
  local record={object=object,methods={},own={}}
  for _,key in ipairs(keys) do record.methods[key]=object[key];record.own[key]=rawget(object,key) end
  baseline[#baseline+1]=record
 end
 local cancelled=false
 local frames=0
 for frame=1,1000 do
  if done then break end
  frames=frame;S.preciseNow=S.preciseNow+1/60
  local counting=false
  for _,object in ipairs(S.nodes) do if rawget(object,'GetWidth')~=nil then counting=true;break end end
  if mode=='cancel_before' or mode=='timeout' or mode=='cancel_timing' and frame==5 or mode=='cancel_counting' and counting then
   cancelled=true;Stop()
  elseif mode=='combat_later' and counting then inCombat=true
  elseif mode=='deadline' then S.preciseNow=30 end
  operationsThisCallback=0
  for _,callback in ipairs(callbacks) do callback(nil,1/60) end
  maxOperations=math.max(maxOperations,operationsThisCallback)
 end
 Check(done,mode..' terminates within callback bound')
 Check(maxOperations<=20,mode..' never performs more than 20 layouts per callback')
 local result=report or logged
 Check(result and result.cleanup,mode..' publishes cleanup report on success or abort')
 cleanup=result.cleanup
 Check(cleanup.driverStopped and cleanup.parentHidden and cleanup.methodsRestored and cleanup.layoutOwnershipReleased
  and cleanup.remainingLayouts==0 and cleanup.motionJobs==0 and cleanup.installedLibraryUnchanged,mode..' releases private work')
 for _,record in ipairs(baseline) do
  for _,key in ipairs(keys) do Check(record.object[key]==record.methods[key] and rawget(record.object,key)==record.own[key],mode..' restores effective method and original instance field '..key) end
 end
 local beforeLate=operationsThisCallback
 for _,callback in ipairs(callbacks) do callback(nil,1/60) end
 Check(done and result.cleanup.driverStopped and operationsThisCallback==beforeLate,mode..' ignores late callbacks')
 if mode=='complete' or mode=='repeat' or mode=='optional' or mode=='capability' or mode=='native_roundtrip' then
  Check(report and not failed and not report.aborted,mode..' succeeds: '..tostring(failed))
  Check(#report.scenes==(capability and 16 or 8),'all declared scenarios run')
  local nativeCount=report.nativeObjectCount.highWater
  Check(report.nativeObjectCount.physicalChildren==24 and nativeCount>=26 and nativeCount<=27,'24 physical children plus private host, driver and optional measurer')
  Check(report.cleanup.nativeObjectsAfter==report.cleanup.nativeObjectsAtHighWater,'native count stable after high water')
  Check(report.firstCreation.elapsedMs>0 and report.firstCreation.naturalHeapDeltaKiB~=nil,'first creation measured separately')
  Check(report.longestSynchronousSegmentMs>0 and report.frameIntervals.samples==frames,'sync duration and frame interval separated')
  Check(report.flex.enabled==capability,'explicit flex capability gates candidate')
  Check(report.revision==actual.version and report.build=='offline-build','revision and build recorded')
  local expectedPixelUnit=mode=='native_roundtrip' and .75 or 768/1080
  Check(not capability or math.abs(report.scenes[9].geometryComparison.pixelUnitUi-expectedPixelUnit)<1e-10,
   'geometry comparator uses the fixture physical pixel scale')
  Check(not capability or report.scenes[9].geometryComparison.physicalWidth==1920 and
   report.scenes[9].geometryComparison.physicalHeight==(mode=='native_roundtrip' and 1024 or 1080),
   'geometry comparison reports the physical screen dimensions')
  if mode=='native_roundtrip' then
   local comparison=report.scenes[9].geometryComparison
   local relativeOnly=4*2^-23*math.max(1,math.abs(comparison.maximumErrorActual),math.abs(comparison.maximumErrorExpected),
    math.abs(comparison.maximumErrorExpected),math.abs(comparison.maximumErrorExpected+comparison.maximumError))
   Check(comparison.hostAbsolutePosition.top~=0 and comparison.maximumErrorObject==1 and comparison.maximumErrorAxis=='height' and
    comparison.maximumError>relativeOnly and comparison.maximumTolerance>comparison.maximumError,
    'first-row native-like height readback uses host absolute-position precision bound')
  end
  for _,value in ipairs(report.scenes) do
   Check(value.uninstrumented.samples==300 and value.uninstrumented.p50Ms<=value.uninstrumented.p95Ms and value.uninstrumented.p95Ms<=value.uninstrumented.maxMs,'bounded timing distribution')
   Check(type(value.counters.GetWidth)=='number' and type(value.counters.GetHeight)=='number' and type(value.counters.GetPoint)=='number','instance counting phase records zero or positive values')
   Check(value.nativeObjectsAfter==nativeCount and value.geometryMatchesLegacy,value.name..' geometry and native count checked')
   Check(value.naturalHeapDeltaKiB~=nil,'natural heap delta retained')
  end
  for index,value in ipairs(modeOptions) do Check(value==(index<=8 and 'legacy' or 'flex'),'only candidate passes explicit flex option') end
 elseif mode=='missing_library' then Check(failed=='missing_library','missing dependency fails clearly')
 elseif mode=='combat' or mode=='combat_later' then Check(failed=='combat','combat fails clearly')
 elseif mode=='setup_error' then Check(failed and failed:find('injected_context_failure',1,true),'setup exception fails')
 elseif mode=='write_failure' then Check(failed and failed:find('injected_after_native_write',1,true),'write exception fails and restores wrappers')
 elseif mode=='native_growth' then Check(failed and failed:find('native_objects_grew',1,true),'native growth fails')
 elseif mode=='pixel_mismatch' then
  Check(failed and failed:find('flex_legacy_geometry_mismatch',1,true),'geometry beyond one physical pixel is rejected')
  local mismatch=logged and logged.geometryFailure and logged.geometryFailure.mismatch
  Check(mismatch and mismatch.axis=='x' and mismatch.deltaPixels and math.abs(mismatch.deltaPixels)>1,
   'aborted report preserves the first mismatch and its pixel delta')
  Check(logged.scenes and logged.scenes[9] and logged.scenes[9].geometryComparison and
   logged.scenes[9].geometryComparison.firstMismatch==mismatch,'failed scene retains comparison diagnostics before throwing')
 elseif mode=='missing_clock' then Check(failed and failed:find('profiling_clock_required',1,true),'missing clock fails')
 elseif mode=='deadline' then Check(failed and failed:find('layout_probe_deadline',1,true),'own deadline fails')
 else Check(cancelled and logged.aborted and not report,'cancellation/timeout retains aborted diagnostics') end
 for _,operation in ipairs(gcCalls) do Check(operation=='count','only natural GC count reads') end
 collectgarbage=originalGC
 return report
end
Run('complete',false,false)
Run('repeat',false,false)
Run('optional',false,true)
-- An explicit fixture capability also verifies the same script's candidate path
-- on r46. It is not evidence for an actual candidate's layout implementation.
Run('capability',true,true)
Run('native_roundtrip',true,true)
Run('pixel_mismatch',true,true)
for _,mode in ipairs({'missing_library','combat','combat_later','setup_error','missing_clock','cancel_before','cancel_timing','cancel_counting','timeout','deadline','write_failure','native_growth'}) do Run(mode,false,false) end
print('Private layout profile lifecycle: '..checks..' checks passed')
