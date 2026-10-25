-- Private native layout replay. Register this file unchanged for r46 and candidate.
-- Entry: probe[, library]; omitted library uses the actual installed LycheeUI.
-- No business UI, global hooks, GC policy changes or hardware input are involved.
local probe,optionalLibrary=...
local installed=LycheeUI
local lib=optionalLibrary or installed
local host,driver,ctx,objects,highWater
local layouts,methods,scenes={},{},{}
local stopped,finished,logged=false,false,false
local report={schema=1,scope='private_native_layout_replay',revision=lib and lib.version,
 sourceHash=lib and lib.auditSourceHash,version=lib and lib.versionString,
 build=GetBuildInfo and select(2,GetBuildInfo()) or 'unavailable',
 input={physicalChildren=24,frames=12,fontStrings=12,iterationsPerSequence=300,maxIterationsPerCallback=20,widths={720,960}},
 gc={policy='natural',scope='whole_client_Lua_heap_KiB; includes observer and unrelated Lua work; not allocated or retained bytes',forcedCollections=0},
 counterScope='temporary instance methods on private native subtree only; input setters included; nested method calls inclusive',
 timingScope='one scene operation including its specified input update; no wrappers; milliseconds from debugprofilestop',
 clock={source='debugprofilestop',unit='milliseconds',resolution='client dependent; not calibrated'},
 frameIntervalScope='driver OnUpdate elapsed only; separate from synchronous Lua duration',
 longestSynchronousSegmentScope='first creation or whole driver callback before Finish; includes observation, validation and counting setup',
 globalHooks=0,scenes={},frameIntervals={},longestSynchronousSegmentMs=0}
local function Heap() return collectgarbage('count') end
local function Summary(samples)
 local count=#samples
 if count==0 then return {samples=0} end
 local sum=0;for _,value in ipairs(samples) do sum=sum+value end
 table.sort(samples)
 return {samples=count,sumMs=sum,p50Ms=samples[math.ceil(count*.50)],p95Ms=samples[math.ceil(count*.95)],maxMs=samples[count]}
end
local function NativeObjects()
 local out,seen={},{}
 local function Visit(object,depth)
  assert(depth<=8 and #out<128,'private_native_tree_bound')
  if seen[object] then return end
  seen[object]=true;out[#out+1]=object
  if object.GetChildren then for _,child in ipairs({object:GetChildren()}) do Visit(child,depth+1) end end
  if object.GetRegions then for _,region in ipairs({object:GetRegions()}) do Visit(region,depth+1) end end
 end
 if host then Visit(host,0) end
 return out
end
local function RestoreMethods()
 for index=#methods,1,-1 do local entry=methods[index];entry.object[entry.key]=entry.own end
 local restored=true
 for _,entry in ipairs(methods) do if entry.object[entry.key]~=entry.method then restored=false end end
 return restored
end
local function Cleanup(quiet)
 if not stopped then
  stopped=true
  if driver then driver:SetScript('OnUpdate',nil);driver:Hide() end
  local restored=RestoreMethods()
  for _,layout in ipairs(layouts) do layout:Release() end
  if ctx then ctx:Hide() end
  if host then host:Hide() end
  local released=true
  for _,object in ipairs(objects or {}) do if object._lycheeLayoutOwner then released=false end end
  report.cleanup={driverStopped=not driver or driver:GetScript('OnUpdate')==nil,methodsRestored=restored,
   parentHidden=not host or not host:IsShown(),layoutOwnershipReleased=released,
   remainingLayouts=ctx and #ctx.layouts or 0,motionJobs=ctx and ctx.Motion:Count() or 0,
   installedLibraryUnchanged=LycheeUI==installed,nativeObjectsAfter=host and #NativeObjects() or 0,
   nativeObjectsAtHighWater=highWater or 0}
 end
 if not quiet and not finished and not logged then logged=true;report.aborted=true;probe:Log(report) end
 return report.cleanup
end
assert(probe:OnCleanup(function() return Cleanup() end))
if not lib or type(lib.CreateContext)~='function' then probe:Fail('missing_library');return end
if InCombatLockdown() then probe:Fail('combat');return end
assert(probe:Guard(function() return not InCombatLockdown() end,{'PLAYER_REGEN_DISABLED'},'combat'))
assert(probe:Async(30))
assert(type(debugprofilestop)=='function','profiling_clock_required')
local startedAt=GetTimePreciseSec()
local firstStart,firstHeap=debugprofilestop(),Heap()
host=CreateFrame('Frame',nil,UIParent);host:SetSize(720,640)
host:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-1000);host:Show()
driver=CreateFrame('Frame',nil,host)
ctx=lib:CreateContext({parent=host,reducedMotion=true})
objects={}
for index=1,24 do
 local object
 if index%2==1 then object=CreateFrame('Frame',nil,host)
 else
  object=host:CreateFontString(nil,'OVERLAY');object:SetFont(STANDARD_TEXT_FONT,14,'')
  object:SetText('L'..index);object:SetWordWrap(false)
 end
 object:SetSize(20,16);object:Show();objects[index]=object
end
local modes={'legacy'}
local flex=lib.layoutModes and lib.layoutModes.flex==true
report.flex={enabled=flex,reason=flex and 'library.layoutModes.flex' or 'unsupported_explicit_capability'}
if flex then modes[#modes+1]='flex' end
for _,mode in ipairs(modes) do
 for _,vertical in ipairs({false,true}) do
  for _,kind in ipairs({'fixed','content_text','width_change','stable_relayout'}) do
   local items={}
   for index,object in ipairs(objects) do
    local text=index%2==0
    items[index]={frame=object,width=kind=='content_text' and text and 'content' or 20,
     height=kind=='content_text' and text and 'content' or 16}
    if kind=='width_change' then
     if vertical then items[index].width='fill'
     elseif index==1 then items[index].width='fill' end
    end
   end
   local options={gap=3,height=640}
   -- r46 Row/Column have no mode option. Keep that original path verbatim.
   if mode=='flex' then options.mode='flex' end
   local factory=vertical and ctx.C.Column or ctx.C.Row
   local layout=factory(host,items,options);layouts[#layouts+1]=layout
   local name=(vertical and 'column_' or 'row_')..kind
   scenes[#scenes+1]={name=name,kind=kind,mode=mode,items=items,layout=layout}
  end
 end
end
-- Materialize any context-private text measurer during first creation, before
-- fixing the native-object high water. At most 16 one-operation warmups.
for _,scene in ipairs(scenes) do scene.layout:Layout() end
highWater=#NativeObjects()
report.nativeObjectCount={highWater=highWater,physicalChildren=#objects,scope='private host descendants and regions, including driver'}
report.firstCreation={elapsedMs=debugprofilestop()-firstStart,naturalHeapDeltaKiB=Heap()-firstHeap,nativeObjects=highWater,warmupLayouts=#scenes,
 scope='private Context, host, driver, 24 children, controllers and one warmup per scene; definitions already loaded'}
report.longestSynchronousSegmentMs=report.firstCreation.elapsedMs
local measuredMethods={'GetWidth','GetHeight','SetWidth','SetHeight','SetSize','GetPoint','GetNumPoints','SetPoint','ClearAllPoints',
 'GetStringWidth','GetUnboundedStringWidth','GetStringHeight','GetFont','GetSpacing','CanWordWrap','GetText'}
local current,sceneIndex,iteration,stage,samples,heapBefore= nil,0,0,'next',{},nil
local frameSamples,legacyGeometry={},{}
local function Snapshot()
 local out={}
 for index,object in ipairs(objects) do
  local point,parent,relative,x,y=object:GetPoint()
  local width,height=object:GetWidth(),object:GetHeight()
  local fixture=probe._offlineGeometryReadback
  if fixture and current and current.mode=='flex' and fixture.object==index and fixture.axis=='height' then height=height+fixture.delta end
  assert(width>=0 and height>=0 and width<100000 and height<100000,'invalid_geometry')
  assert(object:GetNumPoints()==1 and point=='TOPLEFT' and parent==host and relative=='TOPLEFT','invalid_placement')
  out[index]={width,height,x,y}
 end
 return out
end
local function CheckNativeCount() assert(#NativeObjects()==highWater,'native_objects_grew_after_high_water') end
local function WrapMethods(counts)
 methods={}
 for _,key in ipairs(measuredMethods) do counts[key]=0 end
 for _,object in ipairs(NativeObjects()) do
  for _,key in ipairs(measuredMethods) do
   local method=object[key]
   if type(method)=='function' then
    assert(type(object)=='table','private_native_instance_fields_required')
    local entry={object=object,key=key,method=method,own=rawget(object,key)}
    methods[#methods+1]=entry
    object[key]=function(self,...) counts[key]=(counts[key] or 0)+1;return method(self,...) end
   end
  end
 end
end
local function Operate(scene,index)
 if scene.kind=='fixed' then scene.layout:SetItems(scene.items)
 elseif scene.kind=='width_change' then host:SetWidth(index%2==0 and 960 or 720) end
 scene.layout:Layout()
end
local function BeginScene()
 sceneIndex=sceneIndex+1;current=scenes[sceneIndex]
 if not current then return false end
 host:SetSize(720,640)
 for _,object in ipairs(objects) do object:SetSize(20,16) end
 current.layout:SetItems(current.items);current.layout:Layout()
 Snapshot();CheckNativeCount()
 local value={name=current.name,mode=current.mode,iterations=300,
  scene=current.kind=='fixed' and 'SetItems same 24 descriptors then Layout' or current.kind=='width_change' and 'alternate parent width 720/960 then Layout' or 'Layout unchanged 24 descriptors',
  uninstrumented={},counters={}}
 current.output=value;report.scenes[#report.scenes+1]=value
 samples={};iteration=0;stage='timing';heapBefore=Heap()
 return true
end
local function EndScene()
 CheckNativeCount()
 local geometry=Snapshot()
 if current.mode=='legacy' then legacyGeometry[current.name]=geometry
 else
  local expected=assert(legacyGeometry[current.name],'missing_legacy_geometry')
  local physicalWidth,physicalHeight
  if GetPhysicalScreenSize then physicalWidth,physicalHeight=GetPhysicalScreenSize() end
  local scale=host.GetEffectiveScale and host:GetEffectiveScale() or 1
  if type(scale)~='number' or scale<=0 or scale>=math.huge then scale=1 end
  local pixelUnit=type(physicalHeight)=='number' and physicalHeight>0 and physicalHeight<math.huge and
   768/physicalHeight/scale or nil
  local hostLeft=host.GetLeft and host:GetLeft() or 0;local hostTop=host.GetTop and host:GetTop() or 0
  if type(hostLeft)~='number' or hostLeft~=hostLeft then hostLeft=0 end
  if type(hostTop)~='number' or hostTop~=hostTop then hostTop=0 end
  local function Snap(value) return pixelUnit and math.floor(value/pixelUnit+.5)*pixelUnit or value end
  local function Tolerance(actual,wanted,startEdge,endEdge,absoluteStart,absoluteEnd)
   return 4*2^-23*math.max(1,math.abs(actual),math.abs(wanted),math.abs(startEdge or 0),
    math.abs(endEdge or 0),math.abs(absoluteStart or 0),math.abs(absoluteEnd or 0))
  end
  local comparison={pixelUnitUi=pixelUnit,physicalWidth=physicalWidth,physicalHeight=physicalHeight,parentScale=scale,
   hostAbsolutePosition={left=hostLeft,top=hostTop},comparedObjects=#geometry,
   rule='snap x/y starts and cumulative x+w/y+h ends to the physical-pixel grid',
   readbackEpsilon='4 * 2^-23 * max(1, actual, expected, relative snapped edges, absolute host-coordinate edges)',
   maximumError=0,maximumTolerance=0}
  for index,values in ipairs(geometry) do
   local old=expected[index];local left,right=Snap(old[3]),Snap(old[3]+old[1])
   local top,bottom=Snap(-old[4]),Snap(-old[4]+old[2])
   local wanted={math.max(0,right-left),math.max(0,bottom-top),left,-top}
   local starts={left,top,left,top};local ends={right,bottom,left,top}
   local absoluteStarts={hostLeft+left,hostTop-top,hostLeft+left,hostTop-top}
   local absoluteEnds={hostLeft+right,hostTop-bottom,hostLeft+left,hostTop-top}
   for axis,value in ipairs(values) do
    local tolerance=Tolerance(value,wanted[axis],starts[axis],ends[axis],absoluteStarts[axis],absoluteEnds[axis])
    local errorMagnitude=math.abs(value-wanted[axis])
    if errorMagnitude>comparison.maximumError then
     comparison.maximumError,comparison.maximumErrorObject,comparison.maximumErrorAxis=errorMagnitude,index,({'width','height','x','y'})[axis]
     comparison.maximumErrorActual,comparison.maximumErrorExpected,comparison.maximumErrorTolerance=value,wanted[axis],tolerance
    end
    comparison.maximumTolerance=math.max(comparison.maximumTolerance,tolerance)
    if errorMagnitude>tolerance then
     local mismatch={object=index,axis=({'width','height','x','y'})[axis],actual=value,expected=wanted[axis],
      legacy=old[axis],pixelUnitUi=pixelUnit,tolerance=tolerance,delta=value-wanted[axis],
      absoluteHostStart=absoluteStarts[axis],absoluteHostEnd=absoluteEnds[axis],
      deltaPixels=pixelUnit and (value-wanted[axis])/pixelUnit or nil}
     comparison.firstMismatch=mismatch;comparison.matches=false
     current.output.geometryComparison=comparison;current.output.geometryMatchesLegacy=false
     report.geometryFailure={scene=current.name,mode=current.mode,mismatch=mismatch,rule=comparison.rule}
     report.failure='flex_legacy_geometry_mismatch: '..current.name..' object '..index..' '..mismatch.axis..
      ' actual='..tostring(value)..' expected='..tostring(wanted[axis])..' pixelUnitUi='..tostring(pixelUnit)
     report.aborted=true;probe:Log(report)
     error(report.failure,0)
    end
   end
  end
  comparison.matches=true;current.output.geometryComparison=comparison;current.output.geometryMatchesLegacy=true
 end
 if current.mode=='legacy' then current.output.geometryMatchesLegacy=true end
 current.output.nativeObjectsAfter=highWater
 stage='next'
end
local function Complete(callbackStart)
 report.frameIntervals=Summary(frameSamples)
 report.durationSeconds=GetTimePreciseSec()-startedAt
 local cleanup=Cleanup(true)
 assert(cleanup.driverStopped and cleanup.methodsRestored and cleanup.parentHidden and cleanup.layoutOwnershipReleased
  and cleanup.remainingLayouts==0 and cleanup.motionJobs==0 and cleanup.installedLibraryUnchanged,'cleanup_incomplete')
 report.longestSynchronousSegmentMs=math.max(report.longestSynchronousSegmentMs,debugprofilestop()-callbackStart)
 finished=true
 probe:Finish(report)
end
driver:SetScript('OnUpdate',assert(probe:Callback(function(_,elapsed)
 if stopped or probe:IsCancelled() then return end
 assert(GetTimePreciseSec()-startedAt<29,'layout_probe_deadline')
 local callbackStart=debugprofilestop()
 assert(#frameSamples<1024,'frame_sample_bound')
 frameSamples[#frameSamples+1]=(elapsed or 0)*1000
 if stage=='next' then
  if not BeginScene() then Complete(callbackStart);return end
 elseif stage=='counting_setup' then
  -- Keep the warmup out of the preceding 20-operation callback.
  host:SetSize(720,640);current.layout:SetItems(current.items);current.layout:Layout()
  iteration=0;stage='counting';WrapMethods(current.output.counters)
 else
  for _=1,20 do
   iteration=iteration+1
   if stage=='timing' then
    local before=debugprofilestop();Operate(current,iteration);samples[#samples+1]=debugprofilestop()-before
   else Operate(current,iteration) end
  end
  if iteration==300 then
   if stage=='timing' then
    current.output.uninstrumented=Summary(samples)
    current.output.naturalHeapDeltaKiB=Heap()-heapBefore
    CheckNativeCount();Snapshot()
    -- The counting phase gets the same warm state and input sequence.
    stage='counting_setup'
   else
    assert(RestoreMethods(),'method_restore_failed');EndScene()
   end
  end
 end
 report.longestSynchronousSegmentMs=math.max(report.longestSynchronousSegmentMs,debugprofilestop()-callbackStart)
end)))
driver:Show()
