-- Offline probe contract only; optional library directory enables frozen RED.
local libraryDir=arg[1] or "../LycheeUI"
local fixtureDir=arg[2] or "../LycheeUI"
local checks,failures=0,0
local function Check(value,message) checks=checks+1;assert(value,message) end
local actualGC=collectgarbage
local function Run(mode)
 local S=dofile(fixtureDir.."/tests/stubs.lua");S.Install();_G.LycheeUI=nil
 local private={};local file=assert(io.open(libraryDir.."/embeds.xml"));local xml=file:read("*a");file:close()
 for name in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(libraryDir.."/"..name))("ListLifetimeFixture",private) end
 local actual=LycheeUI
 local selected=setmetatable({},{__index=actual});local contexts={}
 selected.CreateContext=function(self,options)
  local context=actual.CreateContext(self,options);contexts[#contexts+1]=context
  return context
 end
 GetBuildInfo=function() return "fixture","offline-build",nil,120000 end
 GetPhysicalScreenSize=function() return 1920,1440 end
 InCombatLockdown=function() return false end
 local clock=0;debugprofilestop=function() clock=clock+.01;return clock end
 if mode=="missing_clock" then debugprofilestop=nil end
 local gcCalls=0
 _G.collectgarbage=function(operation,...) Check(operation=="count","probe changed GC policy");gcCalls=gcCalls+1;return actualGC(operation,...) end
 local forbiddenProduct=setmetatable({},{__index=function() error("product_or_listing_was_accessed") end})
 local oldProduct=LycheeGroup;LycheeGroup=forbiddenProduct
 local p={active=true,cleanups={},callbacks={},logs={},guards={}}
 if mode=="float_precision" then p._offlineGeometryReadback={delta=2^-16}
 elseif mode=="pixel_error" then p._offlineGeometryReadback={delta=768/1440} end
 local function Cleanup()
  if not p.active then return end;p.active=false
  for i=#p.cleanups,1,-1 do p.cleanups[i]() end
 end
 function p:OnCleanup(fn) self.cleanups[#self.cleanups+1]=fn;return true end
 function p:Async(seconds) self.seconds=seconds;return true end
 function p:IsCancelled() return not self.active end
 function p:Guard(fn,events,reason) Check(fn() and events[1]=="PLAYER_REGEN_DISABLED","private guard contract");self.guards[#self.guards+1]={fn=fn,reason=reason};return true end
 function p:Log(line)
  Check(type(line)=="string" and #line<=1800,"native diagnostics must be bounded strings")
  self.logs[#self.logs+1]=line;Check(#self.logs<=100,"native log limit")
 end
 function p:Fail(reason) Check(not self.result,"failure cannot follow successful Finish");self.error=reason;Cleanup();return true end
 function p:Finish(report) Check(not self.error,"failed check cannot be wrapped as successful Finish");self.result=report;Cleanup();return true end
 function p:Callback(fn)
  local wrapped=function(...)
   if not self.active then return end
   for _,guard in ipairs(self.guards) do if not guard.fn() then self:Fail(guard.reason);return end end
   local ok,message=pcall(fn,...);if not ok then self:Fail(tostring(message)) end
  end
  self.callbacks[#self.callbacks+1]=wrapped;return wrapped
 end
 local nodeStart=#S.nodes;local installed=LycheeUI
 if mode=="missing_library" then _G.LycheeUI=nil end
 local injection=selected;if mode=="missing_library" then injection=nil end
 local ok,message=pcall(assert(loadfile("tests/live_list_lifetime.lua")),p,injection)
 if not ok then p:Fail(tostring(message)) end
 if mode=="runtime_error" and contexts[1] then contexts[1].C.RekeyElement=function() error("injected_private_rekey_failure") end end
 local late
 for index=nodeStart+1,#S.nodes do local node=S.nodes[index];if node:GetScript("OnUpdate") then late={node,node:GetScript("OnUpdate")} end end
 if mode=="abort_before" then Cleanup() end
 for tick=1,320 do
  if not p.active then break end
  if mode=="abort_rekey" and tick==4 or mode=="abort_list" and tick==203 then Cleanup() end
  if mode=="deadline" and tick==2 then S.preciseNow=61 end
  if not p.active then break end
  S.preciseNow=S.preciseNow+.0167
  local limit=#S.nodes
  for index=nodeStart+1,limit do
   local node=S.nodes[index];local callback=node:GetScript("OnUpdate")
   if callback and node:IsVisible() then callback(node,.0167) end
  end
 end
 if mode=="complete_repeat" then
  Check(p.result and not p.error,"first run of same-world repeat failed")
  local previous=p
  p={active=true,cleanups={},callbacks={},logs={},guards={}}
  for key,value in pairs(previous) do if type(value)=="function" then p[key]=value end end
  local ok,message=pcall(assert(loadfile("tests/live_list_lifetime.lua")),p,selected)
  if not ok then p:Fail(tostring(message)) end
  for tick=1,320 do
   if not p.active then break end;S.preciseNow=S.preciseNow+.0167
   local limit=#S.nodes
   for index=nodeStart+1,limit do local node=S.nodes[index];local callback=node:GetScript("OnUpdate");if callback and node:IsVisible() then callback(node,.0167) end end
  end
  Check(not previous.active and previous.result~=nil,"repeat changed the completed first result")
 end
 Check(not p.active,"probe exceeded its bounded offline callback schedule")
 Check(#p.callbacks<=16 and #p.cleanups==1,"bounded callbacks and cleanup registered first")
 local beforeLate=#S.nodes
 if late then late[2](late[1],.0167);late[2](late[1],.0167) end
 Check(not p.active and #S.nodes==beforeLate,"late callback reentered the released probe")
 for index=nodeStart+1,#S.nodes do Check(not S.nodes[index]:GetScript("OnUpdate"),"cleanup retained a private OnUpdate") end
 for _,context in ipairs(contexts) do
  Check(context.Motion:Count()==0 and not next(context._conditionalControllers or {}),"cleanup retained owned jobs or conditional sources")
  local scheduler=context.layoutScheduler or {}
  Check(#(scheduler.queue or {})==0 and #(scheduler.work or {})==0 and #(scheduler.notifications or {})==0 and #(scheduler.deferred or {})==0,"cleanup retained scheduler work")
 end
 Check(LycheeGroup==forbiddenProduct,"probe changed the product global")
 LycheeGroup=oldProduct;_G.collectgarbage=actualGC;_G.LycheeUI=installed
 if mode=="complete" or mode=="complete_repeat" or mode=="float_precision" then
  if not p.result then
   for _,line in ipairs(p.logs) do if line:find("passed=false",1,true) then print(line) end end
  end
  Check(p.result and not p.error,"private lifetime probe failed: "..tostring(p.error))
  local result=p.result
  Check(result.gc.forcedCollections==0 and result.gc.policy=="natural" and gcCalls>0,"natural-GC observer contract")
  Check(result.timing.maxBatchOperations<=20 and result.timing.totalOperations<=6000 and result.timing.callbacks<320,"bounded workload")
  Check(result.native.framesCannotBeDestroyed and result.native.afterCleanup>0,"native objects are retained honestly")
  Check(result.heapNetKiB==result.heapAfterCleanupKiB-result.heapBeforeSetupKiB,"heap statistic is a net delta")
  Check(#result.rekey==4,"four rekey modes")
  for _,entry in ipairs(result.rekey) do Check(entry.operations==1000 and entry.batches==50 and entry.recordsPreserved and entry.matchesPreserved and entry.heapNetKiB==entry.heapAfterKiB-entry.heapBeforeKiB,"1000 equivalent rekeys keep identity and stage heap/timing") end
  local names={};for _,entry in ipairs(result.checks) do Check(entry.passed,"all accumulated native checks pass");names[entry.name]=true end
  for _,name in ipairs({"list_warm_reuse","terminal_prefix","terminal_data_callbacks","terminal_row_bindings","terminal_subscriptions","terminal_scheduler","checked_selected_new_key","disabled_new_key","disabled_default_preserved","selection_press_identity","cleanup"}) do Check(names[name],"missing lifecycle check: "..name) end
  Check(result.cleanup.conditionalControllers==0 and result.cleanup.containerSubscriptions==0 and result.cleanup.motionJobs==0,"released private owners")
 elseif mode=="abort_before" or mode=="abort_rekey" or mode=="abort_list" then
  Check(not p.result and not p.error,"abort must remain distinct from failure")
 else
  Check(not p.result and p.error,"expected failure must not be reported as success")
  local expected=mode=="missing_library" and "missing_library" or mode=="missing_clock" and "profiling_clock_required" or mode=="deadline" and "list_lifetime_deadline" or mode=="pixel_error" and "list_lifetime_checks_failed:checked_selected_new_key" or "list_lifetime_runtime_failed"
  Check(p.error==expected,"stable failure reason: "..tostring(p.error))
  if mode=="pixel_error" then
   local found=false;for _,line in ipairs(p.logs) do if line:find("expectedHeight=20",1,true) and line:find("passed=false",1,true) then found=true end end
   Check(found,"one-pixel rejection lacks its complete geometry diagnostic")
  end
 end
 return p
end
for _,mode in ipairs({"complete","complete_repeat","float_precision","pixel_error","abort_before","abort_rekey","abort_list","deadline","runtime_error","missing_clock","missing_library"}) do
 local ok,message=pcall(Run,mode)
 _G.collectgarbage=actualGC
 if not ok then failures=failures+1;print("[FAIL] "..mode..": "..tostring(message)) else print("[PASS] "..mode) end
end
print("Private list lifetime lifecycle: "..checks.." checks, "..failures.." failures")
os.exit(failures==0 and 0 or 1)
