-- Offline lifecycle regression for the private responsive-layout probe.
-- Stubbed timings and object counts are test evidence only, never game results.
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local libraryDir=arg[1] or "../LycheeUI"
local probePath="tests/live_responsive_layout.lua"

local function Run(mode,flexCapability)
 local stubPath=libraryDir.."/tests/stubs.lua";local stubFile=io.open(stubPath,"r")
 if stubFile then stubFile:close() else stubPath="../LycheeUI/tests/stubs.lua" end
 local S=dofile(stubPath);S.Install();_G.LycheeUI=nil
 local private={};local manifest=assert(io.open(libraryDir.."/embeds.xml"));local xml=manifest:read("*a");manifest:close()
 for file in xml:gmatch('<Script file="([^"]+)"') do assert(loadfile(libraryDir.."/"..file))("ResponsiveProbeTest",private) end
 local actual=LycheeUI
 local selected=setmetatable({layoutModes=flexCapability and {flex=true} or {flex=false}},{__index=actual})
 _G.LycheeUI=selected
 GetBuildInfo=function() return "fixture","offline-build",nil,120000 end
 GetPhysicalScreenSize=function() return 1920,1440 end
 InCombatLockdown=function() return false end
 local ticks=0
 debugprofilestop=function() ticks=ticks+.01;return ticks end
 if mode=="missing_clock" then debugprofilestop=nil end
 local errorFlushes
 local delayedEvents=0
 local function DelayRectEvent(frame)
  local setSize,getWidth,getHeight=frame.SetSize,frame.GetWidth,frame.GetHeight
  local pending
  local function Emit(self)
   if pending then
    local callback=pending;pending=nil;delayedEvents=delayedEvents+1
    callback(self,getWidth(self),getHeight(self))
   end
  end
  frame.SetSize=function(self,width,height)
   local callback=self:GetScript("OnSizeChanged")
   if not callback then return setSize(self,width,height) end
   local beforeWidth,beforeHeight=getWidth(self),getHeight(self)
   self:SetScript("OnSizeChanged",nil)
   local ok,result=pcall(setSize,self,width,height)
   self:SetScript("OnSizeChanged",callback)
   if not ok then error(result) end
   if beforeWidth~=getWidth(self) or beforeHeight~=getHeight(self) then pending=callback end
   return result
  end
  frame.GetWidth=function(self) Emit(self);return getWidth(self) end
  frame.GetHeight=function(self) Emit(self);return getHeight(self) end
 end
 if mode=="scenario_fault" or mode=="pixel_fault" or mode=="unanchored_fixture" or mode=="delayed_rect_events" or
  mode=="native_metadata_float32" or mode=="metadata_pixel_fault" then
  local create=selected.CreateContext
  selected.CreateContext=function(self,options)
   local context=create(self,options);local flush=context.FlushLayouts;local count=0
   context.FlushLayouts=function(self,...)
    count=count+1;local result,message=flush(self,...)
    if count==2 and selected.nearest then
     if mode=="scenario_fault" then selected.nearest:SetWidth(44.75)
     elseif mode=="pixel_fault" then selected.nearest:SetWidth(45+768/1440)
     end
    end
    return result,message
   end
   local element=context.C.Element
   context.C.Element=function(target,id,elementOptions)
    if id=="probe.nearest" then selected.nearest=target end
    if id=="probe.metadata.defaults" and (mode=="native_metadata_float32" or mode=="metadata_pixel_fault") then
     target.GetTop=function() return mode=="metadata_pixel_fault" and -1000000000 or -1200 end
     target.GetBottom=function() return target:GetTop()-target:GetHeight() end
    end
    return element(target,id,elementOptions)
   end
   if mode=="unanchored_fixture" or mode=="delayed_rect_events" then
    local container=context.C.Container
    context.C.Container=function(target,name,...)
     local result=container(target,name,...)
     local parent=target.GetParent and target:GetParent()
     if name=="panel" and parent and parent.GetParent and parent:GetParent()==UIParent then
      if mode=="unanchored_fixture" then
       selected.panel=target
       local setWidth=target.SetWidth
       target.SetWidth=function(frame,width)
        if not selected.unanchorApplied then frame:ClearAllPoints();selected.unanchorApplied=true end
        if frame:GetNumPoints()==0 then
         selected.suppressedSizeSignal=true
         local callback=frame:GetScript("OnSizeChanged");frame:SetScript("OnSizeChanged",nil)
         local ok,value=pcall(setWidth,frame,width);frame:SetScript("OnSizeChanged",callback)
         if not ok then error(value) end
         return value
        end
        return setWidth(frame,width)
       end
      else DelayRectEvent(target) end
     end
     return result
    end
   end
   return context
  end
 end
 if mode=="layout_fault" then
  local create=selected.CreateContext
  selected.CreateContext=function(self,options)
   local context=create(self,options);local flush=context.FlushLayouts;local count=0
   context.FlushLayouts=function(self,...)
    count=count+1
    if count==3 then error("injected_layout_flush_fault") end
    return flush(self,...)
   end
   errorFlushes=function() return count end
   return context
  end
 end
 local p={active=true,cleanup={},callbacks={},guards={},logs={}}
 if mode=="native_float32" then p._offlineGeometryReadback={elementId="probe.nearest",axis="width",delta=3.814697265625e-6}
 elseif mode=="native_metadata_float32" then p._offlineGeometryReadback={elementId="probe.metadata.defaults",axis="height",delta=4.76837158203125e-5}
 elseif mode=="metadata_pixel_fault" then p._offlineGeometryReadback={elementId="probe.metadata.defaults",axis="height",delta=768/1440}
 elseif mode=="metadata_scenario_fault" then p._offlineFailScenario="parent_padding_options_fallback" end
 local function Cleanup()
  if not p.active then return end
  p.active=false
  for index=#p.cleanup,1,-1 do p.cleanup[index]() end
 end
 function p:Async(seconds) self.asyncSeconds=seconds;return true end
 function p:Guard(check,events,reason)
  Check(check(),"guard starts clear");Check(events[1]=="PLAYER_REGEN_DISABLED","combat boundary watched")
  self.guards[#self.guards+1]={check=check,reason=reason};return true
 end
 function p:IsCancelled() return not self.active end
 function p:OnCleanup(fn) self.cleanup[#self.cleanup+1]=fn;return true end
 function p:Log(value)
  Check(type(value)=="string","native probe diagnostics use bounded strings")
  self.logs[#self.logs+1]=value;self.log=value
 end
 function p:Fail(reason) self.error=reason;Cleanup();return true end
 function p:Finish(value) self.result=value;Cleanup();return true end
 function p:Callback(fn)
  local callback=function(...)
   if not self.active then return end
   for _,guard in ipairs(self.guards) do if not guard.check() then self:Fail(guard.reason);return end end
   if mode=="callback_fault" then self:Fail("injected_callback_fault");return end
   local ok,err=pcall(fn,...);if not ok then self:Fail(tostring(err)) end
  end
  self.callbacks[#self.callbacks+1]=callback;return callback
 end
 local function HasLog(fragment)
  for _,value in ipairs(p.logs) do if value:find(fragment,1,true) then return true end end
  return false
 end
 local before=#S.nodes
 local ok,err=pcall(assert(loadfile(probePath)),p)
 if not ok then p:Fail(tostring(err)) end
 Check(p.asyncSeconds==nil or p.asyncSeconds==60,mode.." uses a bounded 60 second probe deadline")
 if mode=="cancel_before" then Cleanup() end
 local cancelTick=mode=="cancel_during_flow" and 5 or mode=="timeout" and 10 or nil
 local deadlineTick=mode=="own_deadline" and 5 or nil
 for frame=1,1000 do
  if not p.active then break end
  if cancelTick==frame then Cleanup() end
  if mode=="timeout" and frame==cancelTick then p:Fail("simulated_async_timeout") end
  if deadlineTick==frame then S.preciseNow=61 end
  if not p.active then break end
  S.preciseNow=S.preciseNow+.0167
  local count=#S.nodes
  for index=1,count do
   local node=S.nodes[index];local callback=node:GetScript("OnUpdate")
   if callback and node:IsVisible() then callback(node,.0167) end
  end
 end
 Check(not p.active,mode.." ends within the offline callback bound")
 if mode=="complete" or mode=="native_float32" or mode=="delayed_rect_events" or mode=="native_metadata_float32" then
  local last=p.log and p.log.scenarios and p.log.scenarios[#p.log.scenarios]
  Check(p.result and not p.error,"candidate-capability run completes: "..tostring(p.error).."; "..tostring(p.logs[1]).."; "..tostring(last and last.passed))
  Check(p.result.capability.flex and p.result.revision==actual.version,"capability and source revision recorded")
  Check(p.result.apiSource.snapshot=="PIN-0186341d67e6671b73bfff1299e77f3026a027addaee76e47f1e1bdfee627d91",
   "input API constraints are pinned in the report")
  Check(#p.result.scenarios>=21,"condition, metadata fallback, late binding, identity, scale, native geometry, callback, input and flow scenarios recorded")
  local inputScenario
  local fixedBoxScenario
  local scenarios={}
  for _,scenario in ipairs(p.result.scenarios) do
   scenarios[scenario.name]=scenario
   if scenario.name=="editbox_state_on_condition" then inputScenario=scenario end
   if scenario.name=="fixed_box_no_task_record" then fixedBoxScenario=scenario end
  end
  Check(inputScenario and inputScenario.setTextCalls==0 and inputScenario.selection=="not_tested_no_selection_read_api",
   "input probe avoids text writes and reports the pinned selection API gap")
  Check(fixedBoxScenario and fixedBoxScenario.passed,"fixed Box calls retain no scheduler task or layout controller")
  for _,name in ipairs({"column_unmanaged_height_visible_children","column_unmanaged_height_including_hidden",
   "column_omitted_height_native_input","row_omitted_width_native_input"}) do
   Check(scenarios[name] and scenarios[name].passed,name.." follows native child dimensions")
  end
  local conditional=scenarios.conditional_list_height_prefix_offscreen_state
  Check(conditional and conditional.passed and conditional.narrowContentHeight==3996 and conditional.wideContentHeight==8436 and
   conditional.restoredContentHeight==3996 and conditional.offscreenKey==100 and conditional.offscreenState=="checked" and
   conditional.offscreenStateHeight==120,"conditional list prefix projects the checked offscreen instance and restores on width exit")
  Check(p.result.flow.measurements==2000 and p.result.flow.initialMeasurements==1000 and p.result.flow.fontRebuildMeasurements==1000,
   "1000 row rebuild runs twice: "..tostring(p.result.flow.measurements).."/"..tostring(p.result.flow.initialMeasurements).."/"..tostring(p.result.flow.fontRebuildMeasurements))
  Check(p.result.flow.maxBatch<=128 and p.result.flow.maxBatchMs<=100,"flow batches stay within count and time limits")
  Check(p.result.flow.anchorPreserved and p.result.flow.poolRowsBefore==p.result.flow.poolRowsAfter,"font reflow keeps key anchor and physical row pool")
  Check(p.result.cleanup.driverStopped and p.result.cleanup.schedulerStopped and p.result.cleanup.listReleased and
   p.result.cleanup.probeEditFocusReleased,"success cleans drivers, list data and probe focus")
  Check(scenarios.scheduler_idle and scenarios.scheduler_idle.passed and scenarios.scheduler_idle.queueCount==0 and
   scenarios.scheduler_idle.workCount==0 and scenarios.scheduler_idle.notificationCount==0 and
   scenarios.scheduler_idle.deferredCount==0 and scenarios.scheduler_idle.activeWork==0 and
   not scenarios.scheduler_idle.driverActive,"final direct flush verifies queue, active work and driver are idle")
  Check(scenarios.conditions_initial and scenarios.conditions_initial.innerAnchored and
   scenarios.nearest_and_boundary.innerAnchored and scenarios.different_effective_scales.parentAnchored and
   scenarios.column_unmanaged_height_visible_children.parentAnchored and
   scenarios.conditional_list_height_prefix_offscreen_state.listAnchored and
   scenarios.callback_hide_release.callbackHostAnchored and scenarios.pressed_a_rebound_b.listAnchored and
   p.result.flow.listAnchored,"native size-event roots have effective anchors")
  local metadata=scenarios.partial_rules_keep_item_metadata
  local metadataHeightDelta=mode=="native_metadata_float32" and 4.76837158203125e-5 or 0
  Check(metadata and metadata.passed and metadata.descriptorMinWidth==48 and metadata.descriptorAlign=="center" and
   metadata.conditionMinWidth==96 and metadata.conditionAlign=="start" and metadata.stateMinWidth==72 and metadata.stateAlign=="end" and
   metadata.baseHeight==24+metadataHeightDelta and metadata.conditionWidth==96 and metadata.conditionHeight==72+metadataHeightDelta and metadata.conditionY==0 and
   metadata.stateWidth==72 and metadata.stateHeight==48+metadataHeightDelta and metadata.stateY==-48 and metadata.restoredHeight==24+metadataHeightDelta,
   "partial state/condition rules preserve descriptor minWidth and center alignment through enter/exit")
  local lateMax=scenarios.late_max_condition_direct_layout
  Check(lateMax and lateMax.passed and lateMax.initialWidth==96 and lateMax.activeWidth==lateMax.expectedActiveWidth and
   lateMax.restoredWidth==96 and lateMax.layoutParentWidth==96 and lateMax.restoredLayoutParentWidth==96 and
   lateMax.flushBetweenResizeAndLayout==false,
   "late maxWidth binding is read on direct Layout and restores after ancestor condition exit")
  local participate=scenarios.late_participate_exclude_restore
  Check(participate and participate.passed and participate.initialSecondX==48 and participate.excludedSecondX==0 and
   participate.restoredSecondX==48 and participate.layoutParentWidth==96 and participate.restoredLayoutParentWidth==96 and
   participate.flushBetweenResizeAndLayout==false,
   "late participate=false excludes immediately and re-enters on direct Layout without a flush")
  local padding=scenarios.parent_padding_options_fallback
  Check(padding and padding.passed and padding.initialX==24 and padding.activeX==48 and padding.restoredX==24 and
   padding.initialParentWidth==48 and padding.activeParentWidth==48 and padding.restoredParentWidth==48 and
   padding.flushBetweenResizeAndLayout==false,
   "parent padding style overrides Row options then restores the options fallback on direct Layout")
  if mode=="native_float32" then
   local nearest=scenarios.nearest_and_boundary
   Check(nearest.passed and nearest.nearestWidthDelta>0 and nearest.nearestWidthDelta<=nearest.nearestWidthTolerance,
    "native-scale float32 width readback stays within the calculated precision bound")
  end
  if mode=="native_metadata_float32" then
   Check(metadata.baseHeight>24 and metadata.baseHeight-24<=metadata.baseHeightTolerance and metadata.baseHeightTolerance<=768/1440*.01,
    "native height edge-subtraction error uses absolute geometry precision and remains capped below a physical pixel")
  end
  if mode=="delayed_rect_events" then
   Check(delayedEvents>0 and scenarios.nearest_and_boundary.passed,
    "reading the resized native rect releases delayed size events before the condition flush")
  end
 elseif mode=="unsupported" then
  Check(p.error=="flex_capability_unavailable","legacy revision fails capability check explicitly")
  Check(#S.nodes==before,"unsupported capability fails before allocating native objects")
 elseif mode=="cancel_before" or mode=="cancel_during_flow" then
  Check(not p.result and not p.error and HasLog("aborted=true"),mode.." cancellation remains distinct from failure")
  Check(HasLog("driverStopped=true") and HasLog("schedulerStopped=true") and HasLog("methodsRestored=true") and
   HasLog("probeEditFocusReleased=true"),"cancelled probe performs full cleanup")
 elseif mode=="metadata_scenario_fault" then
  Check(not p.result and p.error and p.error:find("scenario_failed:parent_padding_options_fallback",1,true),
   "injected failure after all four metadata scenarios is surfaced")
  Check(HasLog("responsive_scenario_failure name=parent_padding_options_fallback") and
   HasLog("driverStopped=true") and HasLog("schedulerStopped=true") and HasLog("methodsRestored=true") and
   HasLog("probeEditFocusReleased=true") and #p.logs[1]<=1800,
   "late metadata failure logs a bounded diagnostic and releases scenario resources")
 elseif mode=="scenario_fault" then
  Check(not p.result and p.error and p.error:find("scenario_failed:nearest_and_boundary",1,true),
   "injected nearest-condition mismatch fails at the intended scenario")
  local diagnostic=p.logs[1] or ""
  Check(diagnostic:find("responsive_scenario_failure name=nearest_and_boundary",1,true) and
   diagnostic:find("nearestWidth=44.75",1,true) and diagnostic:find("nearestExpectedWidth=45",1,true) and
   diagnostic:find("nearestContainerWidth=600",1,true) and diagnostic:find("nearestContainerCachedWidth=600",1,true) and
   diagnostic:find("nearestContainerScale=1",1,true),"failure log preserves nearest width, expected width, container and scale")
  Check(not diagnostic:find("<unsupported>",1,true) and #diagnostic<=1800,"failure log is a bounded supported string")
 elseif mode=="metadata_pixel_fault" then
  Check(not p.result and p.error and p.error:find("scenario_failed:partial_rules_keep_item_metadata",1,true),
   "one physical pixel of height error is rejected even at a large absolute position")
  Check(HasLog("baseHeightTolerance=") and HasLog("schedulerStopped=true"),"metadata precision failure retains its bound and completes cleanup")
 elseif mode=="pixel_fault" then
  Check(not p.result and p.error and p.error:find("scenario_failed:nearest_and_boundary",1,true),
   "one-physical-pixel condition geometry error is rejected")
  local diagnostic=p.logs[1] or ""
  Check(diagnostic:find("nearestExpectedWidth=45",1,true) and diagnostic:find("nearestWidthDelta=",1,true) and
   diagnostic:find("nearestWidthTolerance=",1,true) and not diagnostic:find("<unsupported>",1,true),
   "one-pixel failure retains a string diagnostic with its tolerance")
 elseif mode=="unanchored_fixture" then
  Check(not p.result and p.error and p.error:find("scenario_failed:nearest_and_boundary",1,true) and selected.suppressedSizeSignal,
   "unanchored native fixture suppresses the size event and exposes the stale condition: "..tostring(p.error).."; suppressed="..tostring(selected.suppressedSizeSignal))
  local diagnostic=p.logs[1] or ""
  Check(diagnostic:find("innerAnchored=false",1,true) and diagnostic:find("nearestWidth=20",1,true) and
   diagnostic:find("nearestContainerWidth=600",1,true) and diagnostic:find("nearestContainerCachedWidth=500",1,true),
   "unanchored failure reports actual/cached widths and the unanchored container")
 else
  Check(not p.result and p.error,mode.." does not report a partial run as success")
  Check(HasLog("responsive_probe_cleanup") and HasLog("driverStopped=true"),"aborted report includes cleanup state")
  Check(HasLog("schedulerStopped=true") and HasLog("methodsRestored=true") and
   HasLog("probeEditFocusReleased=true"),"failure detaches callbacks, restores wrappers and releases probe focus")
  if mode=="layout_fault" then Check(p.error:find("injected_layout_flush_fault",1,true)~=nil and errorFlushes()==3,"mid-scenario layout fault is surfaced") end
 end
 local countAfter=#S.nodes
 local late
 for _,node in ipairs(S.nodes) do local callback=node:GetScript("OnUpdate");if callback then late={callback,node} end end
 if late then late[1](late[2],.0167) end
 Check(not p.active and #S.nodes==countAfter,mode.." ignores late callbacks and creates no post-cleanup objects")
 for index=before+1,#S.nodes do Check(not S.nodes[index]:GetScript("OnUpdate"),mode.." leaves no private OnUpdate callback") end
 _G.LycheeUI=actual
 return p.result
end

Run("complete",true)
Run("unsupported",false)
Run("scenario_fault",true)
Run("metadata_scenario_fault",true)
Run("native_float32",true)
Run("native_metadata_float32",true)
Run("metadata_pixel_fault",true)
Run("pixel_fault",true)
Run("unanchored_fixture",true)
Run("delayed_rect_events",true)
for _,mode in ipairs({"cancel_before","cancel_during_flow","timeout","callback_fault","layout_fault","own_deadline","missing_clock"}) do
 Run(mode,true)
end
print("Private responsive layout probe lifecycle: "..checks.." checks passed")
