-- Private candidate probe for responsive layouts and text-flow list work.
-- It creates one hidden-from-user subtree and one Context; no product state or
-- global hooks are changed. Candidate selection is capability based.
local probe,optionalLibrary=...
local installed=LycheeUI
local lib=optionalLibrary or installed
local host,ctx,driver,list,edit
local layouts,elements,containers,wrappers={}, {}, {}, {}
local cleaned,finished,logged=false,false,false
local editFocusGetter,editFocusBefore,editFocusTested
local report={schema=1,scope="private_native_responsive_layout",revision=lib and lib.version,
 sourceHash=lib and lib.auditSourceHash,build=GetBuildInfo and select(2,GetBuildInfo()) or "unavailable",
 capability={flex=lib and lib.layoutModes and lib.layoutModes.flex==true},
 apiSource={snapshot="PIN-0186341d67e6671b73bfff1299e77f3026a027addaee76e47f1e1bdfee627d91",
  commit="15881d522c44cd106d3d8660106ec9f9d2f44167",selectionRead="not available in the pinned EditBox API",
  cursorRead="secret return",cursorSet="limited-input restricted"},
 gc={policy="natural",forcedCollections=0,scope="whole client Lua heap KiB; observer and unrelated client work included"},
 timing={clock="debugprofilestop milliseconds",clockResolution="client dependent; not calibrated",longestSynchronousSegmentMs=0,
  flowBatchLimit=128,flowTimeBudgetMs=2,flowBatchWallLimitMs=100,probeDeadlineSeconds=60},
 scenarios={},flow={items=1000},scheduler={},cleanup={}}
local startTime

local function Heap() return collectgarbage("count") end
local function Now() return debugprofilestop() end
local function LogText(value)
 local ok,result=pcall(tostring,value);if not ok then return "<unreadable>" end
 return result:gsub("[%s]+","_")
end
local function LogDiagnostic(kind,name,fields)
 local parts={kind,"name="..LogText(name)}
 local keys={};for key in pairs(fields or {}) do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys) do
  local value=fields[key]
  if type(value)=="number" then
   local ok,formatted=pcall(string.format,"%.9g",value);value=ok and formatted or "<unreadable>"
  end
  parts[#parts+1]=LogText(key).."="..LogText(value)
 end
 local message=table.concat(parts," ")
 if #message>1800 then message=message:sub(1,1797).."..." end
 probe:Log(message)
end
local function Record(name,ok,detail)
 local result={name=name,passed=ok==true}
 if detail then for key,value in pairs(detail) do result[key]=value end end
 report.scenarios[#report.scenarios+1]=result
 if not ok then
  report.failure="scenario_failed:"..name
  LogDiagnostic("responsive_scenario_failure",name,detail)
  error(report.failure,0)
 end
end
local function NativeCount()
 local seen,count={},0
 local function Visit(object,depth)
  assert(depth<=10 and count<1200,"private_native_tree_bound")
  if not object or seen[object] then return end
  seen[object]=true;count=count+1
  if object.GetChildren then for _,child in ipairs({object:GetChildren()}) do Visit(child,depth+1) end end
  if object.GetRegions then for _,region in ipairs({object:GetRegions()}) do Visit(region,depth+1) end end
 end
 if host then Visit(host,0) end
 if driver then Visit(driver,0) end
 local scheduler=ctx and ctx.layoutScheduler
 if scheduler and scheduler.driver then Visit(scheduler.driver,0) end
 return count
end
local function RestoreWrappers()
 local restored=true
 for index=#wrappers,1,-1 do
  local entry=wrappers[index]
  local ok=pcall(function() entry.target[entry.key]=entry.value end)
  if not ok or entry.target[entry.key]~=entry.effective then restored=false end
 end
 wrappers={}
 return restored
end
local function Safe(fn)
 local ok,value=pcall(fn)
 if not ok then report.cleanup.errors=(report.cleanup.errors or 0)+1 end
 return ok,value
end
local function Cleanup(quiet)
 if cleaned then
  if not quiet and not finished and not logged then
   report.aborted=true;logged=true
   LogDiagnostic("responsive_probe_cleanup","repeat",report.cleanup)
  end
  return report.cleanup
 end
 cleaned=true
 if driver then Safe(function() driver:SetScript("OnUpdate",nil);driver:Hide() end) end
 if edit and editFocusGetter and editFocusBefore==nil then
  Safe(function() if editFocusGetter()==edit and edit.ClearFocus then edit:ClearFocus() end end)
 end
 local restored=RestoreWrappers()
 if list then Safe(function() list:Release() end) end
 for index=#layouts,1,-1 do local layout=layouts[index];Safe(function() layout:Release() end) end
 for index=#elements,1,-1 do local entry=elements[index];Safe(function() entry.C.ReleaseElement(entry.target) end) end
 for index=#containers,1,-1 do local entry=containers[index];Safe(function() entry.C.ReleaseContainer(entry.target) end) end
 if ctx then Safe(function() ctx:Hide() end) end
 if host then Safe(function() host:Hide() end) end
 report.cleanup.driverStopped=not driver or driver:GetScript("OnUpdate")==nil
 report.cleanup.schedulerStopped=not ctx or not ctx.layoutScheduler or not ctx.layoutScheduler.driver or ctx.layoutScheduler.driver:GetScript("OnUpdate")==nil
 report.cleanup.methodsRestored=restored
 report.cleanup.remainingLayouts=ctx and #(ctx.layouts or {}) or 0
 report.cleanup.motionJobs=ctx and ctx.Motion:Count() or 0
 report.cleanup.privateHostHidden=not host or not host:IsShown()
 report.cleanup.listReleased=not list or list.released and list.flowText==nil and list.ids==nil and list.render==nil
 report.cleanup.probeEditFocusReleased=not edit or not editFocusGetter or editFocusGetter()~=edit
 report.cleanup.installedLibraryUnchanged=LycheeUI==installed
 report.cleanup.nativeObjectsAfter=NativeCount()
 report.cleanup.nativeObjectsAtHighWater=report.nativeObjectCount and report.nativeObjectCount.highWater or 0
 if not quiet and not finished and not logged then
  report.aborted=true;logged=true
  local cleanupDetails={};for key,value in pairs(report.cleanup) do cleanupDetails[key]=value end
  cleanupDetails.failure=report.failure or "aborted"
  cleanupDetails.aborted=report.aborted
  LogDiagnostic("responsive_probe_cleanup",report.failure or "aborted",cleanupDetails)
 end
 return report.cleanup
end
assert(probe:OnCleanup(function() Cleanup() end))
if not lib or type(lib.CreateContext)~="function" then probe:Fail("missing_library");return end
if not report.capability.flex then probe:Fail("flex_capability_unavailable");return end
if InCombatLockdown() then probe:Fail("combat");return end
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
assert(probe:Async(60))
if type(debugprofilestop)~="function" then probe:Fail("profiling_clock_required");return end

local function AddElement(C,target,id,options)
 C.Element(target,id,options);elements[#elements+1]={C=C,target=target}
end
local function AddContainer(C,target,name)
 C.Container(target,name);containers[#containers+1]={C=C,target=target}
end
local function OwnMethod(target,key,replacement)
 local effective=target[key]
 local value=rawget(target,key)
 wrappers[#wrappers+1]={target=target,key=key,value=value,effective=effective}
 target[key]=replacement
end
local function IsIdle(context)
 local state=context.layoutScheduler
 local function HasActiveWork(values) for job in pairs(values or {}) do if job.dirty or job._layoutQueued or job._layoutDeferred then return true end end;return false end
 return (not state or (#(state.queue or {})==0 and #(state.work or {})==0 and #(state.notifications or {})==0 and
  #(state.deferred or {})==0 and (not state.driver or not state.driver:GetScript("OnUpdate")))) and not HasActiveWork(context._layoutWork)
end
local function Flush(context)
 local ok,message=context:FlushLayouts()
 if not ok then error(message or "layout_flush_failed") end
 local state=context.layoutScheduler
 if state and state.driver then state.driver:SetScript("OnUpdate",nil) end
end
local function ResizeWidth(frame,width)
 frame:SetWidth(width)
 return frame:GetWidth()
end
local function ResizeHeight(frame,height)
 frame:SetHeight(height)
 return frame:GetHeight()
end
local function ResizeWidthAndFlush(frame,width,context)
 local settled=ResizeWidth(frame,width);Flush(context);return settled
end
local function ResizeHeightAndFlush(frame,height,context)
 local settled=ResizeHeight(frame,height);Flush(context);return settled
end
local function Point(target)
 local _,relative,relativePoint,x,y=target:GetPoint()
 return relative,relativePoint,x,y
end
local function GeometryTolerance(target,actual,expected)
 local scale=target and target.GetEffectiveScale and target:GetEffectiveScale() or 1
 if type(scale)~="number" or scale<=0 or scale>=math.huge then scale=1 end
 -- Native dimensions can be differences of absolute binary32 edges. Include
 -- their magnitude, while retaining the hundredth-of-a-physical-pixel cap.
 local magnitude=math.max(1,math.abs(actual),math.abs(expected))
 for _,method in ipairs({"GetLeft","GetRight","GetTop","GetBottom"}) do
  if target and type(target[method])=="function" then
   local ok,value=pcall(target[method],target)
   if ok and type(value)=="number" and value==value and math.abs(value)<math.huge then
    magnitude=math.max(magnitude,math.abs(value))
   end
  end
 end
 local tolerance=4*2^-23*magnitude/scale
 if type(GetPhysicalScreenSize)=="function" then
  local ok,_,height=pcall(GetPhysicalScreenSize)
  if ok and type(height)=="number" and height>0 and height<math.huge then
   tolerance=math.min(tolerance,(768/height/scale)*.01)
  end
 end
 return tolerance
end
local function GeometryMatches(target,actual,expected)
 return math.abs(actual-expected)<=GeometryTolerance(target,actual,expected)
end
local function Width(target)
 local value=target:GetWidth();local fixture=probe._offlineGeometryReadback
 local record=ctx and ctx.elements and ctx.elements[target]
 if fixture and fixture.axis=="width" and record and record.id==fixture.elementId then value=value+fixture.delta end
 return value
end
local function Height(target)
 local value=target:GetHeight();local fixture=probe._offlineGeometryReadback
 local record=ctx and ctx.elements and ctx.elements[target]
 if fixture and fixture.axis=="height" and record and record.id==fixture.elementId then value=value+fixture.delta end
 return value
end
local function Timed(name,fn)
 local before=Now();fn();local elapsed=Now()-before
 report.timing.longestSynchronousSegmentMs=math.max(report.timing.longestSynchronousSegmentMs,elapsed)
 return elapsed
end

local function Setup()
 startTime=GetTimePreciseSec()
 report.heapBeforeSetupKiB=Heap()
 host=CreateFrame("Frame",nil,UIParent);host:SetSize(900,640)
 host:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",0,-1000);host:Show()
 ctx=lib:CreateContext({parent=host,reducedMotion=false,
  elementDefaults={row={template=true,slotKinds={root="box",label="text"}}},
  elements={row={conditions={{container="panel",minWidth=500,base={root={height=80}}}},
   instances={["item:100"]={conditions={{container="panel",minWidth=500,
    base={root={height=100}},states={checked={root={height=120}}}}}}}}}})
 local C=ctx.C

 -- Nearest unnamed and explicitly named ancestor selectors, plus inclusive
 -- minWidth / exclusive maxWidth at the shared 600 UI-unit boundary.
 local inner=CreateFrame("Frame",nil,host);inner:SetSize(500,100);inner:SetPoint("TOPLEFT",host,"TOPLEFT",0,0);inner:Show();AddContainer(C,host,"outer");AddContainer(C,inner,"panel")
 local near=CreateFrame("Frame",nil,inner);near:SetSize(20,20);near:Show()
 AddElement(C,near,"probe.nearest",{classes={conditions={{minWidth=600,base={root={width=45}}}}}})
 local named=CreateFrame("Frame",nil,inner);named:SetSize(20,20);named:Show()
 AddElement(C,named,"probe.named",{classes={conditions={{container="outer",minWidth=700,base={root={width=75}}}}}})
 local edge=CreateFrame("Frame",nil,inner);edge:SetSize(20,20);edge:Show()
 AddElement(C,edge,"probe.edge",{classes={conditions={
  {container="panel",maxWidth=600,base={root={width=65}}},
  {container="panel",minWidth=600,base={root={width=85}}},
 }}})
 Flush(ctx)
 Record("conditions_initial",inner:GetNumPoints()>0 and GeometryMatches(near,Width(near),20) and GeometryMatches(named,Width(named),75) and GeometryMatches(edge,Width(edge),65),
  {nearestWidth=Width(near),nearestExpectedWidth=20,namedWidth=Width(named),namedExpectedWidth=75,
   boundaryWidth=Width(edge),boundaryExpectedWidth=65,nearestContainerWidth=inner:GetWidth(),
   nearestContainerScale=inner:GetEffectiveScale(),nearestElementScale=near:GetEffectiveScale(),innerAnchored=inner:GetNumPoints()>0})
 ResizeWidthAndFlush(inner,600,ctx)
 local nearestWidth,boundaryWidth=Width(near),Width(edge)
 Record("nearest_and_boundary",inner:GetNumPoints()>0 and GeometryMatches(near,nearestWidth,45) and GeometryMatches(edge,boundaryWidth,85),
  {nearestWidth=nearestWidth,nearestExpectedWidth=45,nearestWidthDelta=nearestWidth-45,
   nearestWidthTolerance=GeometryTolerance(near,nearestWidth,45),
   boundaryWidth=boundaryWidth,boundaryExpectedWidth=85,boundaryWidthDelta=boundaryWidth-85,
   boundaryWidthTolerance=GeometryTolerance(edge,boundaryWidth,85),
   nearestContainerWidth=inner:GetWidth(),nearestContainerCachedWidth=inner._lycheeContainer and inner._lycheeContainer.width,
   boundaryContainerWidth=inner:GetWidth(),boundaryContainerCachedWidth=inner._lycheeContainer and inner._lycheeContainer.width,
   namedOuterWidth=host:GetWidth(),nearestContainerScale=inner:GetEffectiveScale(),
   nearestElementScale=near:GetEffectiveScale(),boundaryElementScale=edge:GetEffectiveScale(),
   innerAnchored=inner:GetNumPoints()>0,boundary=600})
 ResizeWidthAndFlush(host,650,ctx)
 Record("named_outer_independent",GeometryMatches(named,Width(named),20) and GeometryMatches(near,Width(near),45),
  {namedWidth=Width(named),nearestWidth=Width(near)})
 ResizeWidthAndFlush(host,800,ctx)
 Record("named_outer_matches",GeometryMatches(named,Width(named),75),{namedWidth=Width(named),expectedWidth=75,
  widthTolerance=GeometryTolerance(named,Width(named),75)})
 ResizeWidthAndFlush(inner,599,ctx)
 Record("max_exclusive_and_min_inclusive",GeometryMatches(edge,Width(edge),65),
  {belowBoundaryWidth=Width(edge),below=599,atBoundary=600})
 ctx:Hide();ResizeWidth(inner,500)
 local hiddenDriver=ctx.layoutScheduler and ctx.layoutScheduler.driver
 local noHiddenDriver=not hiddenDriver or hiddenDriver:GetScript("OnUpdate")==nil
 ctx:Resume();Flush(ctx)
 Record("hidden_resume_latest_condition",noHiddenDriver and GeometryMatches(near,Width(near),20) and GeometryMatches(edge,Width(edge),65),
  {driverStayedStoppedWhileHidden=noHiddenDriver,nearestWidth=Width(near),edgeWidth=Width(edge)})

 local function ProbeParent(name,width,height,x,y)
  local parent=CreateFrame("Frame",nil,host);parent:SetSize(width,height)
  parent:SetPoint("TOPLEFT",host,"TOPLEFT",x,-y);parent:Show();AddContainer(C,parent,name);return parent
 end
 local function ProbeChild(parent,width,height)
  local target=CreateFrame("Frame",nil,parent);target:SetSize(width,height);target:Show();return target
 end
 local function ProbeRow(parent,items,options)
  local layout=C.Row(parent,items,options);layouts[#layouts+1]=layout;return layout
 end
 local function PointX(target)
  local _,_,_,x=target:GetPoint();return x
 end
 local function PointY(target)
  local _,_,_,_,y=target:GetPoint();return y
 end
 local function SnapUi(target,value)
  local _,height=GetPhysicalScreenSize();local scale=target:GetEffectiveScale()
  local pixel=768/height/scale
  return math.floor(value/pixel+.5)*pixel
 end

 -- Partial state/condition rules deliberately change minWidth and alignment;
 -- each exit must restore the item descriptor's minWidth=48 and center alignment.
 local metadataParent=ProbeParent("metadata-state",48,96,0,180)
 local metadataChild=ProbeChild(metadataParent,24,24)
 AddElement(C,metadataChild,"probe.metadata.defaults",{classes={
  states={disabled={root={height=48,minWidth=72,align="end"}}},
  conditions={{container="metadata-state",minWidth=60,base={root={height=72,minWidth=96,align="start"}}}}
 }})
 local metadataLayout=ProbeRow(metadataParent,{{frame=metadataChild,width=24,height=24,minWidth=48,align="center"}},
  {mode="flex",height=96})
 metadataLayout:Layout()
 local defaultWidth,defaultHeight=metadataChild:GetWidth(),Height(metadataChild);local defaultY=PointY(metadataChild)
 metadataParent:SetWidth(72);metadataParent:GetWidth();metadataLayout:Layout()
 local conditionWidth,conditionHeight=metadataChild:GetWidth(),Height(metadataChild);local conditionY=PointY(metadataChild)
 C.SetElementState(metadataChild,"disabled",true);metadataLayout:Layout()
 local stateWidth,stateHeight=metadataChild:GetWidth(),Height(metadataChild);local stateY=PointY(metadataChild)
 metadataParent:SetWidth(48);metadataParent:GetWidth();metadataLayout:Layout()
 local stateExitWidth,stateExitHeight=metadataChild:GetWidth(),Height(metadataChild);local stateExitY=PointY(metadataChild)
 C.SetElementState(metadataChild,"disabled",false);metadataLayout:Layout()
 local restoredWidth,restoredHeight=metadataChild:GetWidth(),Height(metadataChild);local restoredY=PointY(metadataChild)
 local metadataChecks={
  GeometryMatches(metadataChild,defaultWidth,48),GeometryMatches(metadataChild,defaultHeight,24),GeometryMatches(metadataChild,defaultY,-SnapUi(metadataParent,36)),
  GeometryMatches(metadataChild,conditionWidth,96),GeometryMatches(metadataChild,conditionHeight,72),GeometryMatches(metadataChild,conditionY,0),
  GeometryMatches(metadataChild,stateWidth,72),GeometryMatches(metadataChild,stateHeight,48),GeometryMatches(metadataChild,stateY,-48),
  GeometryMatches(metadataChild,stateExitWidth,72),GeometryMatches(metadataChild,stateExitHeight,48),GeometryMatches(metadataChild,stateExitY,-48),
  GeometryMatches(metadataChild,restoredWidth,48),GeometryMatches(metadataChild,restoredHeight,24),GeometryMatches(metadataChild,restoredY,-SnapUi(metadataParent,36))}
 local metadataPassed=true;for _,matched in ipairs(metadataChecks) do if not matched then metadataPassed=false end end
 Record("partial_rules_keep_item_metadata",metadataPassed,
  {baseWidth=defaultWidth,baseHeight=defaultHeight,baseHeightTolerance=GeometryTolerance(metadataChild,defaultHeight,24),
   baseY=defaultY,expectedBaseY=-SnapUi(metadataParent,36),conditionWidth=conditionWidth,
   conditionHeight=conditionHeight,conditionY=conditionY,stateWidth=stateWidth,stateHeight=stateHeight,stateY=stateY,
   stateExitWidth=stateExitWidth,stateExitHeight=stateExitHeight,stateExitY=stateExitY,restoredWidth=restoredWidth,
   restoredHeight=restoredHeight,restoredY=restoredY,descriptorMinWidth=48,descriptorAlign="center",
   conditionMinWidth=96,conditionAlign="start",stateMinWidth=72,stateAlign="end",checks=table.concat((function()
    local values={};for index,matched in ipairs(metadataChecks) do values[index]=matched and "1" or "0" end;return values end)(),"")})

 -- Bind a max-width condition after a plain child has been laid out. The
 -- named container is a separate ancestor; the Row parent stays 96 units wide.
 local maxAncestor=CreateFrame("Frame",nil,host);maxAncestor:SetSize(48,48)
 maxAncestor:SetPoint("TOPLEFT",host,"TOPLEFT",120,-180);maxAncestor:Show();AddContainer(C,maxAncestor,"late-max")
 local maxParent=CreateFrame("Frame",nil,maxAncestor);maxParent:SetSize(96,48)
 maxParent:SetPoint("TOPLEFT",maxAncestor,"TOPLEFT",0,0);maxParent:Show()
 local maxChild=ProbeChild(maxParent,96,24)
 local maxLayout=ProbeRow(maxParent,{{frame=maxChild,width=96,height=24}},{mode="flex",height=48})
 maxLayout:Layout()
 local initialMaxWidth=maxChild:GetWidth()
 AddElement(C,maxChild,"probe.late.max",{classes={conditions={{container="late-max",minWidth=60,base={root={maxWidth=30}}}}}})
 maxAncestor:SetWidth(72);local activeAncestorWidth=maxAncestor:GetWidth()
 local activeAncestorCachedWidth=maxAncestor._lycheeContainer and maxAncestor._lycheeContainer.width
 maxLayout:Layout()
 local activeMaxWidth=maxChild:GetWidth();local activeMaxParentWidth=maxParent:GetWidth()
 local activeStyle=maxChild._lycheeStyleController
 local activeStyleDirty=activeStyle and activeStyle._conditionDirty or false
 local activeMatch=activeStyle and activeStyle.conditionMatches and activeStyle.conditionMatches[1] or false
 local afterLayoutCachedWidth=maxAncestor._lycheeContainer and maxAncestor._lycheeContainer.width
 maxAncestor:SetWidth(45);local restoredAncestorWidth=maxAncestor:GetWidth();maxLayout:Layout()
 local restoredMaxWidth=maxChild:GetWidth();local restoredMaxParentWidth=maxParent:GetWidth()
 Record("late_max_condition_direct_layout",GeometryMatches(maxChild,initialMaxWidth,96) and GeometryMatches(maxChild,activeMaxWidth,SnapUi(maxChild,30)) and
  GeometryMatches(maxChild,restoredMaxWidth,96) and GeometryMatches(maxParent,activeMaxParentWidth,96) and GeometryMatches(maxParent,restoredMaxParentWidth,96),
  {initialWidth=initialMaxWidth,activeWidth=activeMaxWidth,expectedActiveWidth=SnapUi(maxChild,30),restoredWidth=restoredMaxWidth,
   activeContainerWidth=activeAncestorWidth,requestedActiveContainerWidth=72,conditionMinWidth=60,activeContainerCachedBeforeLayout=activeAncestorCachedWidth,
   activeContainerCachedAfterLayout=afterLayoutCachedWidth,activeStyleDirty=activeStyleDirty,activeConditionMatch=activeMatch,
   restoredContainerWidth=restoredAncestorWidth,layoutParentWidth=activeMaxParentWidth,restoredLayoutParentWidth=restoredMaxParentWidth,
   flushBetweenResizeAndLayout=false})

 -- A separate ancestor changes the condition while the fixed-size Row parent
 -- stays put. The excluded child's size is not read before its condition exits.
 local participateAncestor=CreateFrame("Frame",nil,host);participateAncestor:SetSize(48,48)
 participateAncestor:SetPoint("TOPLEFT",host,"TOPLEFT",240,-180);participateAncestor:Show();AddContainer(C,participateAncestor,"late-participate")
 local participateParent=CreateFrame("Frame",nil,participateAncestor);participateParent:SetSize(96,48)
 participateParent:SetPoint("TOPLEFT",participateAncestor,"TOPLEFT",0,0);participateParent:Show()
 local first=ProbeChild(participateParent,24,24);local second=ProbeChild(participateParent,24,24)
 local participateLayout=ProbeRow(participateParent,{{frame=first,width=24,height=24},{frame=second,width=24,height=24}},
  {mode="flex",gap=24,height=48})
 participateLayout:Layout()
 local secondInitialX=PointX(second)
 AddElement(C,first,"probe.late.participate",{classes={conditions={{container="late-participate",minWidth=60,base={root={participate=false}}}}}})
 participateAncestor:SetWidth(72);local activeParticipateAncestorWidth=participateAncestor:GetWidth();participateLayout:Layout()
 local excludedSecondX=PointX(second);local excludedLayoutParentWidth=participateParent:GetWidth()
 participateAncestor:SetWidth(45);local restoredParticipateAncestorWidth=participateAncestor:GetWidth();participateLayout:Layout()
 local restoredFirstX,restoredSecondX=PointX(first),PointX(second);local restoredLayoutParentWidth=participateParent:GetWidth()
 Record("late_participate_exclude_restore",GeometryMatches(participateParent,secondInitialX,48) and
  GeometryMatches(participateParent,excludedSecondX,0) and GeometryMatches(participateParent,restoredFirstX,0) and
  GeometryMatches(participateParent,restoredSecondX,48),
  {initialSecondX=secondInitialX,excludedSecondX=excludedSecondX,restoredFirstX=restoredFirstX,restoredSecondX=restoredSecondX,
   activeContainerWidth=activeParticipateAncestorWidth,requestedActiveContainerWidth=72,conditionMinWidth=60,
   restoredContainerWidth=restoredParticipateAncestorWidth,layoutParentWidth=excludedLayoutParentWidth,
   restoredLayoutParentWidth=restoredLayoutParentWidth,flushBetweenResizeAndLayout=false})

 -- A late disabled-state Apply on the Row parent changes padding without any
 -- container or parent-size event; the next direct Layout must use the input.
 local paddingParent=CreateFrame("Frame",nil,host);paddingParent:SetSize(48,72)
 paddingParent:SetPoint("TOPLEFT",host,"TOPLEFT",360,-180);paddingParent:Show()
 local paddingChild=ProbeChild(paddingParent,24,24)
 local paddingLayout=ProbeRow(paddingParent,{{frame=paddingChild,width=24,height=24}},
  {mode="flex",gap=0,height=72,padding=24})
 paddingLayout:Layout()
 local initialPaddingX=PointX(paddingChild);local initialPaddingParentWidth=paddingParent:GetWidth()
 AddElement(C,paddingParent,"probe.late.padding",{classes={states={disabled={root={padding=48}}}}})
 C.SetElementState(paddingParent,"disabled",true);paddingLayout:Layout()
 local activePaddingX=PointX(paddingChild);local activePaddingParentWidth=paddingParent:GetWidth()
 local paddingValue=paddingParent._lycheeBoxValues and paddingParent._lycheeBoxValues.padding
 local appliedPadding=type(paddingValue)=="table" and paddingValue[1] or paddingValue
 C.SetElementState(paddingParent,"disabled",false);paddingLayout:Layout()
 local restoredPaddingX=PointX(paddingChild);local restoredPaddingParentWidth=paddingParent:GetWidth()
 local paddingPassed=GeometryMatches(paddingParent,initialPaddingX,24) and
  GeometryMatches(paddingParent,activePaddingX,48) and GeometryMatches(paddingParent,restoredPaddingX,24)
 if probe._offlineFailScenario=="parent_padding_options_fallback" then paddingPassed=false end
 Record("parent_padding_options_fallback",paddingPassed,
  {initialX=initialPaddingX,activeX=activePaddingX,expectedActiveX=48,restoredX=restoredPaddingX,
   optionPadding=24,conditionPadding=48,appliedPadding=appliedPadding,initialParentWidth=initialPaddingParentWidth,activeParentWidth=activePaddingParentWidth,restoredParentWidth=restoredPaddingParentWidth,
   flushBetweenResizeAndLayout=false})

 -- Program-set EditBox state is sampled around a conditional geometry write.
 edit=CreateFrame("EditBox",nil,inner);edit:SetSize(180,26);edit:Show();edit:SetAutoFocus(false)
 local expectedText="responsive-layout-probe"
 edit:SetText(expectedText)
 edit:HighlightText(2,8)
 local function ReadOwnText()
  if type(issecretvalue)~="function" or type(edit.GetText)~="function" then return nil,"unavailable" end
  local ok,value=pcall(edit.GetText,edit);if not ok then return nil,"unavailable" end
  local safe,secret=pcall(issecretvalue,value)
  if not safe or secret then return nil,"secret" end
  return value==expectedText,"readable"
 end
 local initialTextMatches,textStatus=ReadOwnText()
 editFocusGetter=type(GetCurrentKeyBoardFocus)=="function" and GetCurrentKeyBoardFocus or nil
 editFocusBefore=editFocusGetter and editFocusGetter() or nil
 local ownsFocus=false
 if editFocusGetter and editFocusBefore==nil and type(edit.SetFocus)=="function" then
  local ok=pcall(edit.SetFocus,edit);ownsFocus=ok and editFocusGetter()==edit
 end
 editFocusTested=editFocusGetter~=nil and (editFocusBefore~=nil or ownsFocus)
 local writes=0;local method=edit.SetText
 OwnMethod(edit,"SetText",function(self,...) writes=writes+1;return method(self,...) end)
 AddElement(C,edit,"probe.edit",{classes={conditions={{container="panel",minWidth=600,base={root={width=220}}}}}})
 ResizeWidthAndFlush(inner,601,ctx)
 local sameText,textAfterStatus=ReadOwnText()
 if textAfterStatus~="readable" then textStatus=textAfterStatus end
 local focusDuring=not editFocusGetter or (ownsFocus and editFocusGetter()==edit) or
  (not ownsFocus and editFocusBefore~=nil and editFocusGetter()==editFocusBefore)
 if ownsFocus and editFocusGetter()==edit then edit:ClearFocus() end
 local focusRestored=not editFocusGetter or editFocusGetter()==editFocusBefore
 Record("editbox_state_on_condition",writes==0 and (not editFocusTested or focusDuring) and (not editFocusTested or focusRestored),
  {textUnchanged=textStatus=="readable" and initialTextMatches==true and sameText==true or "not_tested_"..textStatus,
   focusPreserved=editFocusTested and focusDuring or not editFocusGetter and "not_tested_current_focus_api_unavailable" or "not_tested_private_focus_unavailable",
   focusRestored=editFocusTested and focusRestored or not editFocusGetter and "not_tested_current_focus_api_unavailable" or "not_tested_private_focus_unavailable",
   cursorPosition="not_tested_secret_return_and_limited_input_setter",
   selection="not_tested_no_selection_read_api",setTextCalls=writes,
   stateSource="programmatically set on a private EditBox; no keyboard or IME event was generated"})

 -- Repeated fixed Box declarations do not create tracked layout work.
 local fixed=CreateFrame("Frame",nil,host);fixed:SetSize(10,10);fixed:Show()
 local queueBefore=ctx.layoutScheduler and #ctx.layoutScheduler.queue or 0
 local registeredBefore=#ctx.layouts
 for _=1,100 do C.Box(fixed,{width=50,height=20}) end
 local queueAfter=ctx.layoutScheduler and #ctx.layoutScheduler.queue or 0
 Record("fixed_box_no_task_record",not fixed._lycheeBoxLayout and not fixed._lycheeBoxApply and not ctx.boxes[fixed] and
  queueBefore==queueAfter and registeredBefore==#ctx.layouts,
  {repeatedCalls=100,queueBefore=queueBefore,queueAfter=queueAfter,layoutsBefore=registeredBefore,layoutsAfter=#ctx.layouts})
 C.ReleaseBox(fixed)

 -- C.Box keeps a native FontString identity and does not insert proxy Frames.
 local label=host:CreateFontString(nil,"OVERLAY");label:SetFont(STANDARD_TEXT_FONT,14,"");label:SetText("native region")
 label:SetSize(80,18);local childCountBefore=#({host:GetChildren()})
 local boxed=C.Box(label,{width=96});local childCountAfter=#({host:GetChildren()})
 Record("fontstring_identity",boxed==label and label:GetObjectType()=="FontString" and childCountAfter==childCountBefore,
  {sameObject=boxed==label,objectType=label:GetObjectType(),frameChildrenBefore=childCountBefore,frameChildrenAfter=childCountAfter})

 -- Different effective scales share one parent-coordinate flex row budget.
 local scaleHost=CreateFrame("Frame",nil,host);scaleHost:SetSize(260,30);scaleHost:SetPoint("TOPLEFT",host,"TOPLEFT",0,-120);scaleHost:Show()
 local a,b=CreateFrame("Frame",nil,scaleHost),CreateFrame("Frame",nil,scaleHost)
 a:SetSize(20,20);b:SetSize(20,20);a:SetScale(.8);b:SetScale(1.2)
 local scaled=C.Row(scaleHost,{{frame=a,width="fill",grow=1},{frame=b,width="fill",grow=1}},
  {mode="flex",width=260,height=24,gap=4,track=true})
 layouts[#layouts+1]=scaled;Flush(ctx)
 local scaleA=a:GetWidth()*a:GetEffectiveScale()/scaleHost:GetEffectiveScale()
 local scaleB=b:GetWidth()*b:GetEffectiveScale()/scaleHost:GetEffectiveScale()
 Record("different_effective_scales",scaleHost:GetNumPoints()>0 and math.abs(scaleA+scaleB+4-260)<1,
  {parentUnitsA=scaleA,parentUnitsB=scaleB,gap=4,parentWidth=260,parentAnchored=scaleHost:GetNumPoints()>0})

 -- Tracked flex flows consume native child dimensions even when an axis is unmanaged.
 local function ChildDimensionCase(name,direction,includeHidden,unmanaged)
  local dimensionHost=CreateFrame("Frame",nil,host);dimensionHost:SetSize(180,160);dimensionHost:SetPoint("TOPLEFT",host,"TOPLEFT",0,-180);dimensionHost:Show()
  local first,second=CreateFrame("Frame",nil,dimensionHost),CreateFrame("Frame",nil,dimensionHost)
  first:SetSize(20,20);second:SetSize(20,20);first:Show();second:Show()
  local firstItem,secondItem={frame=first},{frame=second}
  if unmanaged then
   if direction=="column" then firstItem.manageHeight=false;secondItem.manageHeight=false
   else firstItem.manageWidth=false;secondItem.manageWidth=false end
  end
  local flowOptions={mode="flex",track=true,gap=5}
  if direction=="column" then flowOptions.includeHidden=includeHidden end
  local flow=direction=="column" and C.Column(dimensionHost,{firstItem,secondItem},flowOptions) or
   C.Row(dimensionHost,{firstItem,secondItem},flowOptions)
  layouts[#layouts+1]=flow;Flush(ctx)
  local _,_,beforeX,beforeY=Point(second)
  if direction=="column" then ResizeHeightAndFlush(first,50,ctx) else ResizeWidthAndFlush(first,50,ctx) end
  local _,_,afterX,afterY=Point(second)
  local moved=direction=="column" and math.abs(beforeY-afterY-30)<1 or math.abs(afterX-beforeX-30)<1
  Record(name,moved and dimensionHost:GetNumPoints()>0,{direction=direction,includeHidden=includeHidden,unmanaged=unmanaged,
   secondBeforeX=beforeX,secondBeforeY=beforeY,secondAfterX=afterX,secondAfterY=afterY,
   firstNativeHeight=first:GetHeight(),firstNativeWidth=first:GetWidth(),parentAnchored=dimensionHost:GetNumPoints()>0})
 end
 ChildDimensionCase("column_unmanaged_height_visible_children", "column",false,true)
 ChildDimensionCase("column_unmanaged_height_including_hidden", "column",true,true)
 ChildDimensionCase("column_omitted_height_native_input", "column",false,false)
 ChildDimensionCase("row_omitted_width_native_input", "row",false,false)

 -- Conditional row geometry uses the shared prefix, including a checked offscreen instance.
 local heightList=C.List(host,400,120,40);heightList:SetPoint("TOPLEFT",host,"TOPLEFT",0,-360);list=heightList
 AddContainer(C,heightList,"panel")
 heightList:SetStyle({rowHeight=36})
 local ids={};for index=1,100 do ids[index]=index end
 heightList:SetItems(ids,function() end)
 AddElement(C,heightList,"probe.height_list",{scope="probe",rowTemplate="row",
  rowElementKey=function(key,index) return "item:"..index end,
  rowElementState=function(key,index,state) if state=="checked" then return key==100 end end})
 Flush(ctx)
 local narrowContent=heightList:GetContentHeight()
 local narrowRange=select(2,heightList.slider:GetMinMaxValues())
 ResizeWidthAndFlush(heightList,600,ctx)
 local wideContent=heightList:GetContentHeight()
 local wideRange=select(2,heightList.slider:GetMinMaxValues())
 heightList:Select(100,true)
 local offscreenStateHeight
 local offscreenStateRow
 for _,row in ipairs(heightList.rows) do if row.key==100 then offscreenStateRow=row;offscreenStateHeight=row:GetHeight() end end
 ResizeWidthAndFlush(heightList,400,ctx)
 local restoredContent=heightList:GetContentHeight()
 Record("conditional_list_height_prefix_offscreen_state",heightList:GetNumPoints()>0 and GeometryMatches(heightList,narrowContent,3996) and
  GeometryMatches(heightList,narrowRange,3876) and GeometryMatches(heightList,wideContent,8436) and
  GeometryMatches(heightList,wideRange,8316) and GeometryMatches(heightList,restoredContent,3996) and
  heightList.elementHeights==true and offscreenStateRow and GeometryMatches(offscreenStateRow,offscreenStateHeight,120),
  {narrowContentHeight=narrowContent,narrowScrollRange=narrowRange,wideContentHeight=wideContent,
   wideScrollRange=wideRange,restoredContentHeight=restoredContent,offscreenKey=100,
   offscreenState="checked",offscreenStateHeight=offscreenStateHeight,
   listAnchored=heightList:GetNumPoints()>0,
   narrowContentTolerance=GeometryTolerance(heightList,narrowContent,3996),
   wideContentTolerance=GeometryTolerance(heightList,wideContent,8436),
   rowPool=#heightList.rows,itemCount=#ids})
 -- Remove the temporary element and list now; later flow work reuses the list variable.
 C.ReleaseElement(heightList);C.ReleaseContainer(heightList);heightList:Release();list=nil

 -- Callback may hide its host and release itself while notifications run.
 local callbackHost=CreateFrame("Frame",nil,host);callbackHost:SetSize(120,30);callbackHost:SetPoint("TOPLEFT",host,"TOPLEFT",0,-500);callbackHost:Show()
 local action=CreateFrame("Frame",nil,callbackHost);action:SetSize(20,20);action:Show()
 local callbackCount=0;local callbackLayout
 callbackLayout=C.Row(callbackHost,{{frame=action,width="fill"}},
  {mode="flex",width=120,height=24,track=true,onLayout=function(self)
   callbackCount=callbackCount+1;callbackHost:Hide();self:Release()
  end})
 layouts[#layouts+1]=callbackLayout;callbackLayout:Invalidate("probe callback")
 Flush(ctx)
 Record("callback_hide_release",callbackHost:GetNumPoints()>0 and callbackCount==1 and callbackLayout.released and not callbackHost:IsShown(),
  {callbackCount=callbackCount,released=callbackLayout.released,hostVisible=callbackHost:IsShown(),
   callbackHostAnchored=callbackHost:GetNumPoints()>0})

 -- A pool row pressed for A must not deliver the old action after rebinding B.
 list=C.List(host,220,120,24,function(key) if key=="A" then report.listActions=(report.listActions or 0)+1 end end)
 list:SetPoint("TOPLEFT",host,"TOPLEFT",0,-540)
 list:SetItems({"A"},function() end)
 local row=list.rows[1];row._hitVisible=true;row:SetEnabled(true)
 row:GetScript("OnMouseDown")(row,"LeftButton")
 list:SetItems({"B"},function() end)
 row:GetScript("OnMouseUp")(row,"LeftButton");row:GetScript("OnClick")(row,"LeftButton")
 Record("pressed_a_rebound_b",list:GetNumPoints()>0 and (report.listActions or 0)==0 and row.key=="B",
  {oldActionCalls=report.listActions or 0,reboundKey=row.key,
   listAnchored=list:GetNumPoints()>0,inputSource="programmatic callbacks; hardware press/release not exercised"})
 list:Clear();list:Release();list=nil

 -- One context scheduler step per explicit frame, each flow batch capped at 128.
 local ids={}
 for index=1,1000 do ids[index]=index end
 list=C.List(host,260,220,24,nil,nil,{onGeometryChanged=function(_,height)
  report.flow.geometryCallbacks=(report.flow.geometryCallbacks or 0)+1;report.flow.finalContentHeight=height
 end})
 list:SetPoint("TOPLEFT",host,"TOPLEFT",0,-600)
 report.flow.listAnchored=list:GetNumPoints()>0
 list:SetRowTextResolver(function(id)
  return "row "..id.." wrapped text for bounded responsive flow measurement"
 end,{batchSize=128,timeBudgetMs=2})
 list:SetItems(ids,function() end)
 report.flow.poolHighWater=#list.rows
 report.flow.ids=1000;report.flow.steps=0;report.flow.measurements=0;report.flow.indexWork=0
 report.flow.maxBatch=0;report.flow.batchMs={};report.flow.frames=0
 if ctx.layoutScheduler and ctx.layoutScheduler.driver then ctx.layoutScheduler.driver:SetScript("OnUpdate",nil) end
 local flow=list.flowText;local originalStep=flow.StepLayout
 OwnMethod(flow,"StepLayout",function(self,...)
  local before=Now();local result=originalStep(self,...);local elapsed=Now()-before
  report.flow.batchMs[#report.flow.batchMs+1]=elapsed
  report.flow.maxBatch=math.max(report.flow.maxBatch,self.lastBatch or 0)
  report.flow.steps=self.steps;report.flow.measurements=self.measurements;report.flow.indexWork=self.indexWork
  report.flow.timeBudgetMs=self.options.timeBudgetMs or 2
  report.flow.maxBatchMs=math.max(report.flow.maxBatchMs or 0,elapsed)
  assert((self.lastBatch or 0)<=128,"flow_batch_exceeded_128")
  assert(elapsed<=100,"flow_batch_time_limit_exceeded")
  return result
 end)
 driver=CreateFrame("Frame")
 local phase="initial_flow";local previousAnchor
 report.nativeObjectCount={beforeFlow=NativeCount(),highWater=0,maxObserved=0,
  scope="private host subtree, list rows/regions and both private drivers"}
 report.flow.poolObjectsAtStart=report.nativeObjectCount.beforeFlow
 report.heapBeforeFlowKiB=Heap()
 local function Finish()
  report.flow.poolAfter=#list.rows
  report.flow.naturalHeapDeltaKiB=Heap()-report.heapBeforeFlowKiB
  report.heapAfterFlowKiB=Heap()
  report.flow.anchorPreserved=previousAnchor==nil or list.ids[list.geometryIndices[list.offset+1]]==previousAnchor
  report.flow.initialMeasurements=flow.initialMeasurements;report.flow.fontRebuildMeasurements=flow.fontRebuildMeasurements
  Record("flow_1000_bounded",report.flow.listAnchored and not flow.dirty and flow.initialMeasurements==1000 and flow.fontRebuildMeasurements==1000 and
   flow.measurements==2000 and flow.maxBatch<=128 and NativeCount()==report.nativeObjectCount.highWater and
   #list.rows==report.flow.poolHighWater and report.flow.anchorPreserved,
   {items=1000,steps=flow.steps,measurements=flow.measurements,indexWork=flow.indexWork,
    maxBatch=flow.maxBatch,timeBudgetMs=report.flow.timeBudgetMs,poolRowsBefore=report.flow.poolHighWater,poolRowsAfter=#list.rows,
    anchorPreserved=report.flow.anchorPreserved,geometryCallbacks=report.flow.geometryCallbacks or 0,
    maxBatchMs=report.flow.maxBatchMs,naturalHeapDeltaKiB=report.flow.naturalHeapDeltaKiB})
  local settleOk,settleError=ctx:FlushLayouts()
  local state=ctx.layoutScheduler or {};local queueCount=#(state.queue or {})
  local workCount=#(state.work or {});local notificationCount=#(state.notifications or {})
  local deferredCount=#(state.deferred or {});local registeredWork=0
  local activeWork=0
  for job in pairs(ctx._layoutWork or {}) do registeredWork=registeredWork+1;if job.dirty or job._layoutQueued or job._layoutDeferred then activeWork=activeWork+1 end end
  local driverActive=state.driver and state.driver:GetScript("OnUpdate")~=nil or false
  report.scheduler={settleSucceeded=settleOk==true,settleError=settleError,queueCount=queueCount,
   workCount=workCount,notificationCount=notificationCount,deferredCount=deferredCount,
   registeredWork=registeredWork,activeWork=activeWork,driverActive=driverActive}
  Record("scheduler_idle",settleOk==true and IsIdle(ctx) and queueCount==0 and workCount==0 and
   notificationCount==0 and deferredCount==0 and activeWork==0 and not driverActive,report.scheduler)
  local cleanup=Cleanup(true)
  Record("cleanup",cleanup.driverStopped and cleanup.schedulerStopped and cleanup.methodsRestored and cleanup.remainingLayouts==0 and
   cleanup.motionJobs==0 and cleanup.privateHostHidden and cleanup.listReleased and cleanup.installedLibraryUnchanged and (cleanup.errors or 0)==0,
   cleanup)
  finished=true;probe:Finish(report)
 end
 driver:SetScript("OnUpdate",assert(probe:Callback(function(_,elapsed)
  if probe:IsCancelled() then return end
  assert(GetTimePreciseSec()-startTime<60,"responsive_probe_deadline")
  local callbackStart=Now();report.timing.frames= (report.timing.frames or 0)+1
  if phase=="initial_flow" then
   local before=flow.steps
   Timed("flow_flush",function() Flush(ctx) end)
   if flow.steps>before then
    report.flow.frames=report.flow.frames+1
    local countNow=NativeCount()
    report.nativeObjectCount.maxObserved=math.max(report.nativeObjectCount.maxObserved,countNow)
    if report.nativeObjectCount.highWater==0 then report.nativeObjectCount.highWater=countNow end
    assert(countNow==report.nativeObjectCount.highWater,"native_objects_grew_after_flow_warmup")
   end
   if not flow.dirty then
    assert(flow.measurements==1000 and #list.rows==report.flow.poolHighWater,"initial_flow_incomplete")
    flow.initialMeasurements=flow.measurements
    list:SetPixelOffset(math.max(0,(list.geometryOffsets[300] or 0)+5),false)
    flow:CaptureAnchor();previousAnchor=flow.anchorKey
    ctx:SetFont(nil,1.1);phase="font_rebuild"
   end
  elseif phase=="font_rebuild" then
   Timed("font_flow_flush",function() Flush(ctx) end)
   local countNow=NativeCount()
   report.nativeObjectCount.maxObserved=math.max(report.nativeObjectCount.maxObserved,countNow)
   if not flow.dirty then
    flow.fontRebuildMeasurements=flow.measurements-flow.initialMeasurements
    report.nativeObjectCount.afterFontRebuild=countNow
    report.nativeObjectCount.highWater=math.max(report.nativeObjectCount.highWater,countNow)
    Flush(ctx)
    report.nativeObjectCount.afterStableFlush=NativeCount()
    Record("native_count_stable_after_font_warmup",countNow==report.nativeObjectCount.afterStableFlush,
     {beforeStableFlush=countNow,afterStableFlush=report.nativeObjectCount.afterStableFlush,
      initialHighWater=report.nativeObjectCount.highWater,maxObserved=report.nativeObjectCount.maxObserved})
    Finish();return
   end
  end
  report.timing.longestSynchronousSegmentMs=math.max(report.timing.longestSynchronousSegmentMs,Now()-callbackStart)
  assert(#report.flow.batchMs<64,"flow_step_bound")
 end)))
 driver:Show()
end

local setupStart=Now()
local ok,message=pcall(Setup)
report.heapAfterSetupKiB=Heap()
report.setupNaturalHeapDeltaKiB=report.heapAfterSetupKiB-(report.heapBeforeSetupKiB or report.heapAfterSetupKiB)
report.timing.longestSynchronousSegmentMs=math.max(report.timing.longestSynchronousSegmentMs,Now()-setupStart)
if not ok then
 report.failure=tostring(message)
 Cleanup()
 probe:Fail("responsive_setup_failed:"..tostring(message))
end
