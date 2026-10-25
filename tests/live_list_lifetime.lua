-- Private natural-GC lifecycle probe. No product, listing or saved state access.
local probe,optionalLibrary=...
local installed=LycheeUI
local lib=optionalLibrary or installed
local host,panel,driver,ctx,main,stateList
local targets,lists={},{}
local cleaned,finished,logged=false,false,false
local started,phase,step,modeIndex=0,"setup",0,1
local kinds={"catalog","fixed","conditional","classes"}
local identities={};local callbackCounts={selected=0,hovered=0,geometry=0}
local mode="checked"
local report={schema=1,scope="private_native_list_lifetime",revision=lib and lib.version,sourceHash=lib and lib.auditSourceHash,
 build=GetBuildInfo and select(2,GetBuildInfo()) or "unavailable",checks={},stages={},rekey={},
 gc={policy="natural",forcedCollections=0,scope="whole-client Lua heap KiB, including observer and unrelated work",interpretation="heap net change, not cumulative allocation"},
 bounds={deadlineSeconds=60,operationsPerCallback=20,totalOperations=6000,wrappedCallbacks=1},
 geometry={maximumPhysicalPixelError=.01,scope="private native rectangle readback"},
 timing={clock="debugprofilestop milliseconds",callbacks=0,maxCallbackMs=0,maxBatchOperations=0,totalOperations=0},
 native={scope="private host, probe driver and private Context scheduler driver",framesCannotBeDestroyed=true},cleanup={}}
local visited={}
local function Count(values) local n=0;for _ in pairs(values or {}) do n=n+1 end;return n end
local function Heap() return collectgarbage("count") end
local function NativeCount()
 for key in pairs(visited) do visited[key]=nil end
 local n=0
 local function Visit(object,depth)
  if not object or visited[object] then return end
  assert(depth<12 and n<1200,"private_tree_bound")
  visited[object]=true;n=n+1
  if object.GetChildren then for _,child in ipairs({object:GetChildren()}) do Visit(child,depth+1) end end
  if object.GetRegions then for _,region in ipairs({object:GetRegions()}) do Visit(region,depth+1) end end
 end
 Visit(host,0)
 local scheduler=ctx and ctx.layoutScheduler
 if scheduler then Visit(scheduler.driver,0) end
 return n
end
local function Log(name,fields)
 local keys={};for key in pairs(fields or {}) do keys[#keys+1]=key end;table.sort(keys)
 local text={"list_lifetime",name}
 for _,key in ipairs(keys) do
  local value=fields[key]
  if type(value)=="number" then value=string.format("%.9g",value) else value=tostring(value) end
  text[#text+1]=tostring(key).."="..value:gsub("%s+","_")
 end
 local line=table.concat(text," ");probe:Log(#line>1800 and line:sub(1,1797).."..." or line)
end
local function Check(name,passed,detail)
 local item=detail or {};item.name=name;item.passed=passed==true;report.checks[#report.checks+1]=item
 if not passed and not report.firstFailure then report.firstFailure=name end
end
local function Snapshot(name)
 local scheduler=ctx and ctx.layoutScheduler or {}
 local result={name=name,heapKiB=Heap(),atSeconds=GetTimePreciseSec()-started,nativeObjects=NativeCount(),
  elements=ctx and Count(ctx.elements) or 0,fixedControllers=ctx and Count(ctx.fixedControllers) or 0,
  conditionalControllers=ctx and Count(ctx._conditionalControllers) or 0,
  containerSubscriptions=panel and panel._lycheeLayoutSignals and #panel._lycheeLayoutSignals.entries or 0,
  queue=#(scheduler.queue or {}),work=#(scheduler.work or {}),notifications=#(scheduler.notifications or {}),deferred=#(scheduler.deferred or {}),
  poolRows=main and #main.rows or 0,prefixNumbers=main and main.geometryOffsets and #main.geometryOffsets or 0}
 result.heapNetKiB=result.heapKiB-(report.heapBeforeSetupKiB or result.heapKiB)
 report.stages[#report.stages+1]=result;return result
end
local function GeometryMatches(target,actual,expected)
 local scale=target:GetEffectiveScale();local tolerance
 if GetPhysicalScreenSize then local _,height=GetPhysicalScreenSize();if height and height>0 then tolerance=768/height/scale*.01 end end
 if not tolerance then
  local extent=math.max(1,math.abs(actual),math.abs(expected))
  for _,method in ipairs({"GetLeft","GetRight","GetTop","GetBottom"}) do
   local value=target[method] and target[method](target)
   if type(value)=="number" then extent=math.max(extent,math.abs(value)) end
  end
  tolerance=4*2^-23*extent/scale
 end
 return math.abs(actual-expected)<=tolerance
end
local function Height(target)
 local value=target:GetHeight();local fixture=probe._offlineGeometryReadback
 if fixture and target._lycheeList==stateList then value=value+fixture.delta end
 return value
end
local function Safe(fn)
 local ok=pcall(fn);if not ok then report.cleanup.errors=(report.cleanup.errors or 0)+1 end
 return ok
end
local function ReleaseTarget(target)
 if not ctx then return end
 ctx.C.ReleaseElement(target)
 local controller=target._lycheeStyleController
 if controller and controller.context==ctx then controller:Release() end
end
local function Cleanup(quiet)
 if cleaned then return report.cleanup end
 cleaned=true
 if driver then Safe(function() driver:SetScript("OnUpdate",nil);driver:Hide() end) end
 for _,list in ipairs(lists) do
  Safe(function() list:Release() end)
  -- Frozen candidates may have the precise lifetime defect under test.
  -- Explicitly retire their private row bindings for probe cleanup too.
  for _,row in ipairs(list.rows or {}) do Safe(function() ReleaseTarget(row);row.pressedKey=nil end) end
  Safe(function() ReleaseTarget(list);list:Hide() end)
 end
 for _,target in ipairs(targets) do Safe(function() ReleaseTarget(target) end) end
 if ctx then
  for i=#ctx.layouts,1,-1 do local layout=ctx.layouts[i];Safe(function() layout:Release() end) end
  for job in pairs(ctx._layoutWork or {}) do if job.Release then Safe(function() job:Release() end) end end
  if panel then Safe(function() ctx.C.ReleaseContainer(panel) end) end
  Safe(function() ctx.Motion:StopAll();ctx:Hide() end)
 end
 if host then Safe(function() host:Hide() end) end
 local scheduler=ctx and ctx.layoutScheduler or {}
 if scheduler.driver then Safe(function() scheduler.driver:SetScript("OnUpdate",nil);scheduler.driver:Hide() end) end
 report.cleanup.driverStopped=not driver or driver:GetScript("OnUpdate")==nil
 report.cleanup.schedulerStopped=not scheduler.driver or scheduler.driver:GetScript("OnUpdate")==nil
 report.cleanup.queue=#(scheduler.queue or {});report.cleanup.work=#(scheduler.work or {})
 report.cleanup.notifications=#(scheduler.notifications or {});report.cleanup.deferred=#(scheduler.deferred or {})
 report.cleanup.layouts=ctx and #ctx.layouts or 0;report.cleanup.workOwners=ctx and Count(ctx._layoutWork) or 0
 report.cleanup.conditionalControllers=ctx and Count(ctx._conditionalControllers) or 0
 report.cleanup.elements=ctx and Count(ctx.elements) or 0;report.cleanup.fixedControllers=ctx and Count(ctx.fixedControllers) or 0
 report.cleanup.motionJobs=ctx and ctx.Motion:Count() or 0
 report.cleanup.containerSubscriptions=panel and panel._lycheeLayoutSignals and #panel._lycheeLayoutSignals.entries or 0
 report.cleanup.hostHidden=not host or not host:IsShown();report.cleanup.installedLibraryUnchanged=LycheeUI==installed
 report.cleanup.nativeObjects=NativeCount()
 if not quiet and not finished and not logged then logged=true;Log("aborted_cleanup",report.cleanup) end
 return report.cleanup
end
assert(probe:OnCleanup(function() Cleanup() end))
if not lib or type(lib.CreateContext)~="function" then probe:Fail("missing_library");return end
if type(debugprofilestop)~="function" then probe:Fail("profiling_clock_required");return end
if InCombatLockdown() then probe:Fail("combat");return end
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
assert(probe:Async(60))
local function Flush()
 local ok,message=ctx:FlushLayouts();if not ok then error(message or "private_flush_failed",0) end
 local scheduler=ctx.layoutScheduler
 if scheduler and scheduler.driver then scheduler.driver:SetScript("OnUpdate",nil) end
end
local function Operation(fn)
 report.timing.totalOperations=report.timing.totalOperations+1
 assert(report.timing.totalOperations<=report.bounds.totalOperations,"operation_bound")
 if fn then fn() end
end
local ids={};for index=1,1000 do ids[index]=index end
local function Render(row,key) row._lifetimeKey=key end
local function NewFrame(width,height,x,y)
 local frame=CreateFrame("Frame",nil,panel);frame:SetSize(width,height);frame:SetPoint("TOPLEFT",panel,"TOPLEFT",x or 0,y or 0);return frame
end
local function StateProjection(key,index,name)
 if key==1 and name==mode then return true end
 if key==1 and mode=="enable" and name=="disabled" then return false end
end
local function Setup()
 started=GetTimePreciseSec();report.heapBeforeSetupKiB=Heap()
 host=CreateFrame("Frame",nil,UIParent);host:SetSize(900,640);host:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",0,-1000);host:Show()
 panel=CreateFrame("Frame",nil,host);panel:SetSize(700,500);panel:SetPoint("TOPLEFT",host,"TOPLEFT",0,0)
 ctx=lib:CreateContext({parent=host,reducedMotion=true,
  elementDefaults={catalog={template=true,slotKinds={root="box"}},fixed={template=true,slotKinds={root="box"}},
   conditional={template=true,slotKinds={root="box"}},classes={template=true,slotKinds={root="box"}},
   row={template=true,slotKinds={root="box",label="text"}},state={template=true,slotKinds={root="box",label="text"}}},
  elements={fixed={base={root={height=60}}},conditional={conditions={{container="lifetime",minWidth=0,base={root={height=60}}}}},
   classes={classes="h-64"},row={conditions={{container="lifetime",minWidth=0,base={root={height=60}}}}},
   state={base={root={height=20}},states={checked={root={height=80}},disabled={root={height=40}},selected={root={height=100}}}}}})
 local C=ctx.C;assert(C.Container and C.RekeyElement,"required_list_api_unavailable");C.Container(panel,"lifetime")
 for index,kind in ipairs(kinds) do
  local target=NewFrame(50,30,index*60,0);targets[index]=target;C.Element(target,kind,{template=kind,key=1})
  local controller=target.styleController
  identities[index]={controller=controller,records=controller and controller.records,matches=controller and controller.conditionMatches,stable=true}
  report.rekey[index]={kind=kind,operations=0,recordsPreserved=true,matchesPreserved=true}
 end
 main=C.List(panel,200,100,40,function() callbackCounts.selected=callbackCounts.selected+1 end,function() callbackCounts.hovered=callbackCounts.hovered+1 end,
  {onGeometryChanged=function() callbackCounts.geometry=callbackCounts.geometry+1 end,initializeRow=function(row) row._lifetimeInitialized=true end})
 lists[#lists+1]=main;main:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-120)
 main:SetRowInitializer(function(row) row._lifetimeInitialized=true end)
 main:SetStyle({rowHeight=36});C.Element(main,"main.list",{rowTemplate="row"});main:SetItems(ids,Render)
 stateList=C.List(panel,200,100,20);lists[#lists+1]=stateList;stateList:SetPoint("TOPLEFT",panel,"TOPLEFT",230,-120)
 C.Element(stateList,"state.list",{rowTemplate="state",rowElementState=StateProjection})
 Flush();report.native.beforeWork=NativeCount();Snapshot("setup");phase="rekey";step=0
 driver=CreateFrame("Frame",nil,host);driver:SetPoint("TOPLEFT",host,"TOPLEFT",0,0)
end
local function LogReport()
 for _,stage in ipairs(report.stages) do Log("stage",stage) end
 for _,result in ipairs(report.rekey) do Log("rekey",result) end
 for _,result in ipairs(report.checks) do Log("check",result) end
 Log("timing",report.timing);Log("cleanup",report.cleanup)
end
local function Finish(callbackStart)
 Snapshot("before_terminal")
 main.rows[1].pressedKey=main.rows[1].key
 for _,target in ipairs(targets) do ReleaseTarget(target) end
 main:Release();stateList:Release();Flush()
 local scheduler=ctx.layoutScheduler or {}
 Check("terminal_prefix",not main.geometryOffsets and not main.geometryIndices and not main._geometryOffsets and not main._geometryIndices,
  {offsets=main.geometryOffsets and #main.geometryOffsets or 0,cachedOffsets=main._geometryOffsets and #main._geometryOffsets or 0})
 Check("terminal_data_callbacks",main.ids==nil and main.render==nil and main.initializeRow==nil and main.rowElementState==nil and main.rowElementKey==nil,
  {idsRetained=main.ids~=nil,rendererRetained=main.render~=nil,initializerRetained=main.initializeRow~=nil})
 local rowBindings,pressed=0,0
 for _,list in ipairs(lists) do for _,row in ipairs(list.rows) do
  if ctx.elements[row] or row._lycheeStyleController then rowBindings=rowBindings+1 end
  if row.pressedKey then pressed=pressed+1 end
 end end
 Check("terminal_row_bindings",rowBindings==0 and pressed==0,{rowBindings=rowBindings,pressedKeys=pressed})
 Check("terminal_subscriptions",Count(ctx._conditionalControllers)==0 and (not panel._lycheeLayoutSignals or #panel._lycheeLayoutSignals.entries==0),
  {conditionalControllers=Count(ctx._conditionalControllers),subscriptions=panel._lycheeLayoutSignals and #panel._lycheeLayoutSignals.entries or 0})
 Check("terminal_scheduler",#(scheduler.queue or {})==0 and #(scheduler.work or {})==0 and #(scheduler.deferred or {})==0 and #(scheduler.notifications or {})==0,
  {queue=#(scheduler.queue or {}),work=#(scheduler.work or {}),notifications=#(scheduler.notifications or {}),deferred=#(scheduler.deferred or {})})
 Snapshot("terminal_released")
 local cleanup=Cleanup(true)
 Check("cleanup",cleanup.driverStopped and cleanup.schedulerStopped and cleanup.queue==0 and cleanup.work==0 and cleanup.notifications==0 and cleanup.deferred==0 and
  cleanup.layouts==0 and cleanup.workOwners==0 and cleanup.conditionalControllers==0 and cleanup.fixedControllers==0 and cleanup.motionJobs==0 and
  cleanup.hostHidden and cleanup.installedLibraryUnchanged and (cleanup.errors or 0)==0)
 report.heapAfterCleanupKiB=Heap();report.heapNetKiB=report.heapAfterCleanupKiB-report.heapBeforeSetupKiB
 report.native.afterCleanup=NativeCount();report.callbackPayloadCollection="not observed: natural GC only; offline weak-reference fixture covers captured payloads"
 report.timing.maxCallbackMs=math.max(report.timing.maxCallbackMs,debugprofilestop()-callbackStart)
 finished=true;logged=true;LogReport()
 if report.firstFailure then probe:Fail("list_lifetime_checks_failed:"..report.firstFailure) else probe:Finish(report) end
end
local warmRecords,warmPool,warmNative
local function ListOperation(index)
 local action=index%4
 if action==1 then main:SetPixelOffset(100000,false)
 elseif action==2 then main:SetPixelOffset(0,false)
 elseif action==3 then main:Clear()
 else main:SetItems(ids,Render) end
 Flush()
end
local function StateStep(index)
 local row=stateList.rows[1]
 if index==1 then mode="checked";Operation(function() stateList:SetItems({1},Render) end);Operation(function() stateList:Select(1,false) end)
 elseif index==2 then Operation(function() stateList:SetItems({2},Render) end);Flush()
  Check("checked_selected_new_key",not row._checked and not row._selected and row:IsEnabled() and GeometryMatches(row,Height(row),20),{checked=row._checked==true,selected=row._selected==true,height=Height(row),expectedHeight=20})
 elseif index==3 then mode="disabled";Operation(function() stateList:SetItems({1},Render) end)
 elseif index==4 then Operation(function() stateList:SetItems({2},Render) end);Flush()
  Check("disabled_new_key",row:IsEnabled() and GeometryMatches(row,Height(row),20),{enabled=row:IsEnabled(),height=Height(row),expectedHeight=20})
 elseif index==5 then mode="enable";row:SetEnabled(false);Operation(function() stateList:SetItems({1},Render) end)
 elseif index==6 then Operation(function() stateList:SetItems({2},Render) end);Flush()
  Check("disabled_default_preserved",not row:IsEnabled() and GeometryMatches(row,Height(row),40),{enabled=row:IsEnabled(),height=Height(row),expectedHeight=40})
 elseif index==7 then mode="none";row:SetEnabled(true);Operation(function() stateList:SetItems({1},Render) end);Operation(function() stateList:Select(1,false) end)
 elseif index==8 then row._inside=true;row._pressed=true;row.pressedKey=row.key;Operation(function() stateList:SetItems({2},Render) end);Flush()
  Check("selection_press_identity",not row._selected and not row._inside and not row._pressed and row.pressCancelled==true and row.pressedKey==nil and
   GeometryMatches(row,Height(row),20),{selected=row._selected==true,pressed=row._pressed==true,pressedKeyRetained=row.pressedKey~=nil,height=Height(row),expectedHeight=20})
 end
 Flush()
end
local function Tick()
 if probe:IsCancelled() then return end
 if GetTimePreciseSec()-started>=60 then Cleanup();probe:Fail("list_lifetime_deadline");return end
 local callbackStart=debugprofilestop();local beforeOperations=report.timing.totalOperations
 report.timing.callbacks=report.timing.callbacks+1
 if phase=="rekey" then
  local target,identity,result=targets[modeIndex],identities[modeIndex],report.rekey[modeIndex]
  if step==0 then result.heapBeforeKiB=Heap();result.batches=0;result.totalBatchMs=0;result.maxBatchMs=0 end
  local batchStart=debugprofilestop()
  for i=1,20 do
   step=step+1;Operation();ctx.C.RekeyElement(target,step+1)
   result.operations=result.operations+1
   local controller=target.styleController
   if controller~=identity.controller or controller and controller.records~=identity.records then result.recordsPreserved=false end
   if controller and controller.conditionMatches~=identity.matches then result.matchesPreserved=false end
  end
  Flush()
  local batchMs=debugprofilestop()-batchStart
  result.batches=result.batches+1;result.totalBatchMs=result.totalBatchMs+batchMs;result.maxBatchMs=math.max(result.maxBatchMs,batchMs)
  if step==1000 then
   result.heapAfterKiB=Heap();result.heapNetKiB=result.heapAfterKiB-result.heapBeforeKiB
   Check("rekey_"..result.kind,result.recordsPreserved and result.matchesPreserved and ctx.elements[target].key==1001,
    {kind=result.kind,operations=result.operations,recordsPreserved=result.recordsPreserved,matchesPreserved=result.matchesPreserved})
   Snapshot("rekey_"..result.kind);modeIndex=modeIndex+1;step=0
   if modeIndex>#kinds then phase="warm_list" end
  end
 elseif phase=="warm_list" then
  for i=1,2 do step=step+1;Operation();ListOperation(step) end
  if step==8 then
   warmRecords={};for index,row in ipairs(main.rows) do warmRecords[index]=row.styleController and row.styleController.records end
   warmPool,warmNative=#main.rows,NativeCount();report.native.afterWarmup=warmNative;Snapshot("list_warm");phase="list_work";step=0
  end
 elseif phase=="list_work" then
  for i=1,2 do step=step+1;Operation();ListOperation(step) end
  if step==200 then
   local stable=true;for index,row in ipairs(main.rows) do if not row.styleController or row.styleController.records~=warmRecords[index] then stable=false end end
   Check("list_warm_reuse",#main.rows==warmPool and NativeCount()==warmNative and stable,{poolBefore=warmPool,poolAfter=#main.rows,nativeBefore=warmNative,nativeAfter=NativeCount(),recordsPreserved=stable})
   Check("list_1000_prefix",GeometryMatches(main,main:GetContentHeight(),63996),{contentHeight=main:GetContentHeight(),items=main.ids and #main.ids or 0})
   Snapshot("list_work");phase="state";step=0
  end
 elseif phase=="state" then
  step=step+1;StateStep(step)
  if step==8 then Snapshot("state_checks");phase="finish" end
 elseif phase=="finish" then Finish(callbackStart);return end
 local operations=report.timing.totalOperations-beforeOperations
 report.timing.maxBatchOperations=math.max(report.timing.maxBatchOperations,operations)
 report.timing.maxCallbackMs=math.max(report.timing.maxCallbackMs,debugprofilestop()-callbackStart)
 assert(operations<=20,"callback_operation_bound")
end
local setupStart=debugprofilestop()
local ok,message=pcall(Setup)
report.timing.setupMs=debugprofilestop()-setupStart
if not ok then report.failure=tostring(message);Log("setup_failure",{reason=report.failure});Cleanup();probe:Fail("list_lifetime_setup_failed");return end
local callback=assert(probe:Callback(function()
 local ok,reason=pcall(Tick)
 if not ok then report.failure=tostring(reason);Cleanup(true);Log("runtime_failure",{reason=tostring(reason)});LogReport();probe:Fail("list_lifetime_runtime_failed") end
end))
driver:SetScript("OnUpdate",callback);driver:Show()
