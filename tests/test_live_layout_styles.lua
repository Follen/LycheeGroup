-- Run from LycheeGroup: lua tests/test_live_layout_styles.lua [../LycheeUI]
-- Fake lifecycle and native substitutes; this never contacts the game.
local libraryDir=arg[1] or '../LycheeUI'
local script='tests/live_layout_styles.lua'
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local keys={'GetSize','GetWidth','GetHeight','SetWidth','SetHeight','SetSize','GetPoint','GetNumPoints','SetPoint','ClearAllPoints'}
local function LoadLibrary()
 local stubPath=libraryDir..'/tests/stubs.lua';local stubFile=io.open(stubPath,'r')
 if stubFile then stubFile:close() else stubPath='../LycheeUI/tests/stubs.lua' end
 local S=dofile(stubPath);S.Install();_G.LycheeUI=nil
 local nativeStub=getmetatable(UIParent)
 nativeStub.GetSize=function(self) return self:GetWidth(),self:GetHeight() end
 local private={}
 for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do
  assert(loadfile(libraryDir..'/'..file..'.lua'))('LayoutStylesTest',private)
 end
 return S,LycheeUI
end
local function Run(mode)
 local S,actual=LoadLibrary()
 local selected=setmetatable({layoutModes=actual.layoutModes},{__index=actual})
 local rowCount,operationsThisCallback,maxOperations=0,0,0
 function selected:CreateContext(options)
  local context=actual.CreateContext(actual,options)
  local factory=context.C.Row
  context.C.Row=function(parent,items,values)
   local layout=factory(parent,items,values);rowCount=rowCount+1
   local run=layout.Layout
   function layout:Layout(...)
    operationsThisCallback=operationsThisCallback+1
    return run(self,...)
   end
   return layout
  end
  return context
 end
 GetBuildInfo=function() return 'fixture','offline-build','date',120000 end
 GetPhysicalScreenSize=function() return 1920,1080 end
 InCombatLockdown=function() return false end
 S.preciseNow=0
 GetTimePreciseSec=function() return S.preciseNow end
 local clock=0
 debugprofilestop=function() clock=clock+.001;return clock end
 local done,report,failed,logged,cleanup=false,nil,nil,nil,nil
 local cleanups,callbacks={},{}
 local probe={}
 local function Stop()
  if done then return end
  done=true
  for index=#cleanups,1,-1 do cleanup=cleanups[index]() end
 end
 function probe:OnCleanup(fn) cleanups[#cleanups+1]=fn;return true end
 function probe:Guard(fn,events,reason)
  Check(fn(),'initial guard is valid');Check(events[1]=='PLAYER_REGEN_DISABLED' and reason=='combat','combat guard is registered');return true
 end
 function probe:Async(seconds) Check(seconds==30,'bounded asynchronous deadline');return true end
 function probe:IsCancelled() return done end
 function probe:Log(value) Check(type(value)=='string' and #value<=180,'failure diagnostics are bounded strings');logged=value end
 function probe:Fail(reason) failed=tostring(reason);Stop();return true end
 function probe:Finish(value) report=value;Stop();return true end
 function probe:Callback(fn)
  local callback=function(...)
   if done then return end
   local ok,reason=pcall(fn,...)
   if not ok then probe:Fail(tostring(reason)) end
  end
  callbacks[#callbacks+1]=callback;return callback
 end
 if mode=='tiny_readback' then probe._offlineGeometryReadback={object=1,axis='width',delta=1e-5}
 elseif mode=='full_pixel' then probe._offlineGeometryReadback={object=1,axis='width',deltaPixels=1.1}
 elseif mode=='write_failure' then probe._offlineInjectWriteFailure={perturbBeforeLayout=true} end
 local ok,reason=pcall(assert(loadfile(script)),probe,selected)
 if not ok then probe:Fail(tostring(reason)) end
 local baseline={}
 for _,object in ipairs(S.nodes) do
  local record={object=object,methods={},own={}}
  for _,key in ipairs(keys) do record.methods[key]=object[key];record.own[key]=rawget(object,key) end
  baseline[#baseline+1]=record
 end
 if mode=='cancel_before' then Stop() end
 local frames=0
 for frame=1,500 do
  if done then break end
  frames=frame;S.preciseNow=S.preciseNow+1/60;operationsThisCallback=0
  for _,callback in ipairs(callbacks) do callback(nil,1/60) end
  maxOperations=math.max(maxOperations,operationsThisCallback)
 end
 Check(done,'probe reaches a terminal state within 500 callbacks')
 Check(maxOperations<=20,'no callback performs more than twenty Layout calls: '..tostring(maxOperations))
 for _,record in ipairs(baseline) do
  for _,key in ipairs(keys) do
   Check(record.object[key]==record.methods[key] and rawget(record.object,key)==record.own[key],'native instance method restored: '..key)
  end
 end
 local beforeLate=operationsThisCallback
 for _,callback in ipairs(callbacks) do callback(nil,1/60) end
 Check(operationsThisCallback==beforeLate,'late callbacks perform no more layouts')
 Check(cleanup and cleanup.driverStopped and cleanup.apiMethodsRestored and cleanup.nativeMethodsRestored
  and cleanup.parentHidden and cleanup.layoutOwnershipReleased and cleanup.remainingLayouts==0 and cleanup.motionJobs==0 and cleanup.schedulerStopped and cleanup.schedulerEmpty
  and cleanup.subscriptionsEmpty and cleanup.installedLibraryUnchanged,'all terminal paths clean private state')
 if mode=='complete' or mode=='tiny_readback' then
  Check(report and not failed and report.business.ok,'probe finishes with business ok: failure='..tostring(failed)..' log='..tostring(logged)..' business='..tostring(report and report.business and report.business.failure))
  Check(#report.scenes==3 and report.nativeObjectCount.physicalChildren==24,'three style cases use 24 mixed children')
  Check(report.cleanup.nativeObjectsAfter==report.cleanup.nativeObjectsAtHighWater
   and report.nativeObjectCount.highWater>report.nativeObjectCount.physicalChildren,'native object count stays at its warmed high water')
  for _,scene in ipairs(report.scenes) do
   Check(scene.timing.stable.samples==80 and scene.timing.width_change.samples==80,'each phase keeps 80 uninstrumented timing samples')
   Check(scene.counters.stable.GetSize>0 and scene.counters.widthChange.GetSize>0,'native GetSize reads are counted')
   Check(type(scene.counters.stable.GetWidth)=='number' and type(scene.counters.widthChange.SetWidth)=='number',
    'native reads and writes have separate counter values')
   Check(scene.semantics.itemsDeclarationReused and scene.semantics.conditionBoundaryChecked
   and scene.semantics.conditionBoundaryAt480.expectedWidth==20 and scene.semantics.conditionBoundaryAt960.expectedWidth==(scene.name=='matchingCondition' and 24 or 20),'same item declaration and semantic boundary checks recorded')
  end
  Check(report.scenes[1].counters.widthChange.LayoutValue==0 and report.scenes[1].counters.widthChange.FixedValue==0,
   'plain width changes have no Element rule lookups')
  Check(type(report.scenes[2].counters.widthChange.FixedValue)=='number'
   and ((report.scenes[2].counters.widthChange._ReadLayoutValues or report.scenes[2].counters.widthChange.ReadLayoutValues)==nil
    or (report.scenes[2].counters.widthChange._ReadLayoutValues or report.scenes[2].counters.widthChange.ReadLayoutValues)>0),
   'static class width/height path reports available rule projection counters')
  Check(type(report.scenes[3].counters.widthChange.FixedValue)=='number'
   and ((report.scenes[3].counters.widthChange._ReadLayoutValues or report.scenes[3].counters.widthChange.ReadLayoutValues)==nil
    or (report.scenes[3].counters.widthChange._ReadLayoutValues or report.scenes[3].counters.widthChange.ReadLayoutValues)>0),
   'matching condition path reports available rule projection counters')
  if mode=='tiny_readback' then Check(report.scenes[1].semantics.stableAt960.maximumReadbackError>9e-6,'subpixel native-like readback is included in bounded tolerance') end
 elseif mode=='full_pixel' then
  Check(failed and failed:find('layout_style_readback_',1,true) and logged==failed,
   'more than one pixel of readback error aborts with a short diagnostic: failed='..tostring(failed)..' logged='..tostring(logged))
 elseif mode=='write_failure' then
  Check(failed and failed:find('injected_native_setwidth_after_write',1,true) and logged==failed,'post-write failure aborts with a short diagnostic')
  Check(probe._offlineInjectWriteFailure.fired,'failure fixture writes native size before throwing')
 elseif mode=='cancel_before' then Check(not failed and not report,'cancellation exits without publishing success') end
 return report
end
Run('complete')
Run('tiny_readback')
Run('full_pixel')
Run('write_failure')
Run('cancel_before')
print('Private declarative layout styles lifecycle: '..checks..' checks passed')
