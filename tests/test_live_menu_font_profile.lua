local candidate=assert(arg[1],'generated private probe path required')
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
for _,mode in ipairs({'complete','cancel','error','timeout','combat'}) do
 local fixture=dofile('tests/ui_fixture.lua')('enUS',nil,{reduceMotion=true})
 debugprofilestop=function() return os.clock()*1000 end
 local cleanups,callbacks={},{}
 local done,report,failed,cleanup
 local probe={}
 local function Stop()
  done=true
  for i=#cleanups,1,-1 do cleanup=cleanups[i]() end
 end
 function probe:OnCleanup(fn) cleanups[#cleanups+1]=fn;return true end
 function probe:Guard(fn) Check(fn(),'scene initially valid');return true end
 function probe:Async(seconds) Check(seconds==15,'bounded deadline');return true end
 function probe:IsCancelled() return done==true end
 function probe:Finish(value) report=value;Stop();return true end
 function probe:Fail(reason) failed=reason;Stop() end
 function probe:Callback(fn)
  local callback=function(...)
   if done then return end
   local ok,message=pcall(fn,...)
   if not ok then failed=tostring(message);Stop() end
  end
  callbacks[#callbacks+1]=callback;return callback
 end
 if mode=='combat' then InCombatLockdown=function() return true end end
 assert(loadfile(candidate))(probe)
 if mode=='cancel' or mode=='timeout' then Stop()
 elseif mode=='error' then
  local saved=debugprofilestop;debugprofilestop=function() error('expected injected error') end
  callbacks[1]();debugprofilestop=saved
 else for frame=1,50 do if done then break end;callbacks[1]() end end
 Check(done,mode..' finishes')
 Check(cleanup.driverStopped and cleanup.methodsRestored and cleanup.parentHidden and cleanup.jobs==0 and cleanup.menuReleased and cleanup.installedLibraryUnchanged,mode..' releases private work')
 if mode=='complete' then
  Check(report and not failed and #report.phases==2,'both font phases completed: '..tostring(failed))
  for _,phase in ipairs(report.phases) do
   Check(phase.widthReads==1400 and phase.poolAfter==phase.pool and phase.baseline.batches==10 and phase.instrumented.batches==10,'bounded measurements and stable pool')
  end
 elseif mode=='combat' then Check(failed=='combat','combat fails before work')
 elseif mode=='error' then Check(failed and failed:find('expected injected error',1,true),'callback error reported') end
 for _,callback in ipairs(callbacks) do callback() end
 Check(cleanup.driverStopped and cleanup.jobs==0,mode..' late callbacks do not restart work')
end
print('Private menu font profile: '..checks..' checks passed')
