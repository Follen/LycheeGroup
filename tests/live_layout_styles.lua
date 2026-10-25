-- Private native probe for declarative Element-style layout inputs.
-- Entry: probe[, library]; omitted library uses the installed LycheeUI.
-- Uses only a private host and never modifies global APIs or business state.
local probe,optionalLibrary=...
local installed=LycheeUI
local lib=optionalLibrary or installed
local host,driver,ctx,C,layout,objects,items,highWater
local methods,apiMethods={},{}
local scenes={'plain','staticElement','matchingCondition'}
local sceneIndex,current,phase,iteration,samples=0,nil,'next',0,{}
local stopped,finished=false,false
local startedAt=GetTimePreciseSec and GetTimePreciseSec() or 0
local report={schema=1,scope='private_native_element_style_layout',revision=lib and lib.version,
 sourceHash=lib and lib.auditSourceHash,version=lib and lib.versionString,
 build=GetBuildInfo and select(2,GetBuildInfo()) or 'unavailable',
 input={physicalChildren=24,frames=12,fontStrings=12,iterationsPerPhase=80,maxOperationsPerCallback=20,
  maxWidthChangeOperationsPerCallback=2,parentWidths={720,960},itemsDeclaration='one persistent 24-entry table; never replaced during measured operations'},
 timingScope='debugprofilestop around parent resize, condition flush, and Layout; no method or query wrappers during timing',
 counterScope='temporary instance wrappers on private host descendants plus temporary Context C.LayoutValue/C.FixedValue and public or internal batch-query wrappers when available; native reads and writes are counts, not hardware operations',
 globalHooks=0,scenes={},business={ok=false}}
local measuredMethods={'GetSize','GetWidth','GetHeight','SetWidth','SetHeight','SetSize','GetPoint','GetNumPoints','SetPoint','ClearAllPoints'}
local function Bounded(value)
 local text=tostring(value or 'probe_failure'):gsub('[\r\n]+',' ')
 if #text>180 then text=text:sub(1,180) end
 return text
end
local function NativeObjects()
 local result,seen={},{}
 local function Visit(object,depth)
  assert(depth<=4 and #result<64,'native_tree_bound')
  if seen[object] then return end
  seen[object]=true;result[#result+1]=object
  if object.GetChildren then for _,child in ipairs({object:GetChildren()}) do Visit(child,depth+1) end end
  if object.GetRegions then for _,region in ipairs({object:GetRegions()}) do Visit(region,depth+1) end end
 end
 if host then Visit(host,0) end
 -- Responsive.lua creates this driver without a parent, so include it explicitly.
 local schedulerDriver=ctx and ctx.layoutScheduler and ctx.layoutScheduler.driver
 if schedulerDriver then Visit(schedulerDriver,0) end
 return result
end
local function RestoreMethods()
 for index=#methods,1,-1 do local entry=methods[index];entry.object[entry.key]=entry.own end
 local ok=true
 for _,entry in ipairs(methods) do if entry.object[entry.key]~=entry.method then ok=false end end
 methods={};return ok
end
local function RestoreAPI()
 for index=#apiMethods,1,-1 do local entry=apiMethods[index];C[entry.key]=entry.own end
 local ok=true
 for _,entry in ipairs(apiMethods) do if C[entry.key]~=entry.method then ok=false end end
 apiMethods={};return ok
end
local function Cleanup()
 if stopped then return report.cleanup end
 stopped=true
 if driver then driver:SetScript('OnUpdate',nil);driver:Hide() end
 local apiRestored=RestoreAPI();local methodsRestored=RestoreMethods()
 if layout then layout:Release();layout=nil end
 if C and objects then for _,object in ipairs(objects) do C.ReleaseElement(object) end end
 if C and host then C.ReleaseContainer(host) end
 if ctx then ctx:Hide() end
 if host then host:Hide() end
 local ownershipReleased=true
 for _,object in ipairs(objects or {}) do if object._lycheeLayoutOwner or object._lycheeLayoutFields then ownershipReleased=false end end
 local scheduler=ctx and ctx.layoutScheduler
 local schedulerEmpty=not scheduler or (#scheduler.queue==0 and #scheduler.work==0 and #scheduler.notifications==0
  and #(scheduler.deferred or {})==0 and not scheduler.flushing and not scheduler.notifying)
 local subscriptionsEmpty=true
 for _,object in ipairs(objects or {}) do
  local signal=object._lycheeLayoutSignals
  if object._lycheeLayoutSources or signal and #signal.entries>0 then subscriptionsEmpty=false end
 end
 local hostSignal=host and host._lycheeLayoutSignals
 if host and (host._lycheeLayoutSources or hostSignal and #hostSignal.entries>0) then subscriptionsEmpty=false end
 report.cleanup={driverStopped=not driver or driver:GetScript('OnUpdate')==nil,apiMethodsRestored=apiRestored,
  nativeMethodsRestored=methodsRestored,parentHidden=not host or not host:IsShown(),layoutOwnershipReleased=ownershipReleased,
  remainingLayouts=ctx and #ctx.layouts or 0,motionJobs=ctx and ctx.Motion:Count() or 0,
  schedulerStopped=not scheduler or not scheduler.driver or scheduler.driver:GetScript('OnUpdate')==nil,
  schedulerEmpty=schedulerEmpty,subscriptionsEmpty=subscriptionsEmpty,
  installedLibraryUnchanged=LycheeUI==installed,nativeObjectsAfter=host and #NativeObjects() or 0,
  nativeObjectsAtHighWater=highWater or 0}
 return report.cleanup
end
local function Fail(reason)
 if stopped then return end
 report.business.ok=false;report.business.failure=Bounded(reason)
 Cleanup()
 probe:Log(report.business.failure)
 probe:Fail(report.business.failure)
end
assert(probe:OnCleanup(function() return Cleanup() end))
if not lib or type(lib.CreateContext)~='function' then Fail('missing_library');return end
if InCombatLockdown() then Fail('combat');return end
assert(probe:Guard(function() return not InCombatLockdown() end,{'PLAYER_REGEN_DISABLED'},'combat'))
assert(probe:Async(30))
assert(type(debugprofilestop)=='function','profiling_clock_required')
assert(type(GetTimePreciseSec)=='function','elapsed_clock_required')
local function Setup()
 host=CreateFrame('Frame',nil,UIParent);host:SetSize(960,640)
 host:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-1000);host:Show()
 driver=CreateFrame('Frame',nil,host)
 ctx=lib:CreateContext({parent=host,reducedMotion=true,elementDefaults={auditItem={
  base={root={width=20,height=16}},
  conditions={{container='layout-style-audit',minWidth=600,base={root={width=24,height=18}}}}
 }}})
 C=ctx.C;C.Container(host,'layout-style-audit')
 objects,items={},{}
 for index=1,24 do
  local object
  if index%2==1 then object=CreateFrame('Frame',nil,host)
  else object=host:CreateFontString(nil,'OVERLAY');object:SetFont(STANDARD_TEXT_FONT,14,'');object:SetText('S'..index);object:SetWordWrap(false) end
  object:SetSize(20,16);object:Show();objects[index]=object;items[index]={frame=object,width=20,height=16}
 end
end
local function ResetObjects()
 for _,object in ipairs(objects) do
  C.ReleaseElement(object)
  object:ClearAllPoints();object:SetSize(20,16);object:Show()
 end
end
local function BuildScene(name)
 if layout then layout:Release();layout=nil end
 ResetObjects();host:SetWidth(960);host:GetWidth()
 if name=='staticElement' then
  local classes={base={root={width=20,height=16}}}
  for _,object in ipairs(objects) do C.Element(object,'auditStatic',{classes=classes}) end
 elseif name=='matchingCondition' then
  for _,object in ipairs(objects) do C.Element(object,'auditItem') end
 end
 layout=C.Row(host,items,{mode='flex',gap=3,height=640,track=true})
 ctx:FlushLayouts();layout:Layout()
 layout:Invalidate('probe_warmup');ctx:FlushLayouts();layout:Layout()
 highWater=math.max(highWater or 0,#NativeObjects())
end
local function CheckNativeCount()
 assert(#NativeObjects()==highWater,'native_objects_grew_after_high_water')
end
local function FloatTolerance(actual,expected,x,y,width,height)
 local left=host.GetLeft and host:GetLeft() or 0;local top=host.GetTop and host:GetTop() or 0
 local extent=math.max(1,math.abs(actual),math.abs(expected),math.abs(left+x),math.abs(left+x+width),
  math.abs(top+y),math.abs(top+y-height))
 return 4*2^-23*extent
end
local function PixelUnit()
 local _,height=GetPhysicalScreenSize();local scale=host.GetEffectiveScale and host:GetEffectiveScale() or 1
 if type(height)~='number' or height<=0 or type(scale)~='number' or scale<=0 then return end
 return 768/height/scale
end
local function Expected(name,width)
 if name=='matchingCondition' and width>=600 then return 24,18 end
 return 20,16
end
local function CheckGeometry(name)
 local fixture=probe._offlineGeometryReadback
 local maximumError,maximumTolerance=0,0
 local parentWidth=host:GetWidth()
 local pixel=PixelUnit()
 assert(type(pixel)=='number' and pixel>0,'invalid_pixel_unit')
 local firstDesiredW,firstDesiredH=Expected(name,parentWidth)
 local firstExpectedW,firstExpectedH
 local cursor=0
 for index,object in ipairs(objects) do
  local desiredW,desiredH=Expected(name,parentWidth)
  local expectedX=math.floor(cursor/pixel+.5)*pixel
  local expectedRight=math.floor((cursor+desiredW)/pixel+.5)*pixel
  local expectedW=expectedRight-expectedX
  local expectedH=math.floor(desiredH/pixel+.5)*pixel
  if index==1 then firstExpectedW,firstExpectedH=expectedW,expectedH end
  local actualW,actualH=object:GetSize()
  local point,relative,relativePoint,x,y=object:GetPoint()
  assert(point=='TOPLEFT' and relative==host and relativePoint=='TOPLEFT','invalid_placement_'..index)
  local record=layout.records[object];assert(record,'missing_layout_record_'..index)
  if name~='plain' then assert(record.widthRef==desiredW and record.heightRef==desiredH,
   'element_style_projection_'..name..'_'..index..'_'..tostring(record.widthRef)..'_'..tostring(record.heightRef)..'_'..tostring(desiredW)..'_'..tostring(desiredH)) end
  if fixture and fixture.object==index then
   local delta=fixture.delta or 0
   if fixture.deltaPixels then delta=fixture.deltaPixels*pixel end
   if fixture.axis=='height' then actualH=actualH+delta else actualW=actualW+delta end
  end
  local errors={math.abs(actualW-expectedW),math.abs(actualH-expectedH),math.abs(x-expectedX),math.abs(y)}
  local tolerances={FloatTolerance(actualW,expectedW,x,y,expectedW,expectedH),
   FloatTolerance(actualH,expectedH,x,y,expectedW,expectedH),FloatTolerance(x,expectedX,x,y,expectedW,expectedH),
   FloatTolerance(y,0,x,y,expectedW,expectedH)}
  for axis=1,#errors do
   maximumError=math.max(maximumError,errors[axis]);maximumTolerance=math.max(maximumTolerance,tolerances[axis])
   if errors[axis]>tolerances[axis] then
    error('layout_style_readback_'..name..'_'..({'width','height','x','y'})[axis]..'_'..index..'_actual_'..
     string.format('%.6f',({actualW,actualH,x,y})[axis])..'_expected_'..
     string.format('%.6f',({expectedW,expectedH,expectedX,0})[axis])..'_'..
     string.format('%.6f',errors[axis])..'>'..string.format('%.6f',tolerances[axis]),0)
   end
  end
  assert(actualW>=0 and actualH>=0 and actualW<100000 and actualH<100000,'invalid_geometry_'..index)
  cursor=cursor+desiredW+3
 end
 return {comparedObjects=#objects,maximumReadbackError=maximumError,maximumFloatTolerance=maximumTolerance,pixelUnitUi=pixel,
  parentWidth=parentWidth,expectedWidth=firstDesiredW,expectedHeight=firstDesiredH,
  expectedNativeWidth=firstExpectedW,expectedNativeHeight=firstExpectedH}
end

local function Summary(values)
 local count=#values;if count==0 then return {samples=0} end
 local sorted={};local sum=0
 for index,value in ipairs(values) do sorted[index]=value;sum=sum+value end
 table.sort(sorted)
 return {samples=count,sumMs=sum,p50Ms=sorted[math.ceil(count*.5)],p95Ms=sorted[math.ceil(count*.95)],maxMs=sorted[count]}
end
local function AddMethodCounters(counts)
 methods={}
 for _,key in ipairs(measuredMethods) do counts[key]=0 end
 for _,object in ipairs(NativeObjects()) do for _,key in ipairs(measuredMethods) do
  local method=object[key]
  if type(method)=='function' then
   local entry={object=object,key=key,method=method,own=rawget(object,key)};methods[#methods+1]=entry
   object[key]=function(self,...) counts[key]=counts[key]+1;return method(self,...) end
  end
 end end
end
local function AddValueCounters(counts)
 apiMethods={}
 for _,key in ipairs({'LayoutValue','FixedValue','ReadLayoutValues','_ReadLayoutValues'}) do
  local method=C[key]
  if method~=nil then assert(type(method)=='function','invalid_'..key)
  counts[key]=0
  local entry={key=key,method=method,own=rawget(C,key)};apiMethods[#apiMethods+1]=entry
  C[key]=function(...) counts[key]=counts[key]+1;return method(...) end
  end
 end
end
local function Operate(kind,index)
 if kind=='width_change' then
  host:SetWidth(index%2==1 and 720 or 960);host:GetWidth()
  ctx:FlushLayouts()
  local fixture=probe._offlineInjectWriteFailure
  if fixture and not fixture.installed then
   local object=objects[1];local method=object.SetWidth
   method(object,21)
   local entry={object=object,key='SetWidth',method=method,own=rawget(object,'SetWidth')};methods[#methods+1]=entry
   fixture.installed=true
   object.SetWidth=function(self,value) method(self,value);fixture.fired=true;error('injected_native_setwidth_after_write',0) end
  end
 end
 assert(layout.items==items,'items_declaration_changed')
 layout:Layout()
end
local function NewOutput(name)
 return {name=name,iterationsPerPhase=80,widthChange='alternate host width 720/960, flush matching conditions, then Layout',
  stable='repeat Layout at host width 960',timing={},counters={},semantics={}}
end
local function PrepareTiming()
 host:SetWidth(960);host:GetWidth();ctx:FlushLayouts();layout:Layout()
 samples={};iteration=0;phase='timing'
end
local function PrepareCounters()
 host:SetWidth(960);host:GetWidth();ctx:FlushLayouts();layout:Layout()
 current.counts={}
 AddMethodCounters(current.counts);AddValueCounters(current.counts)
 iteration=0;phase='counting'
end
local function CompleteScene()
 assert(RestoreAPI(),'context_api_restore_failed');assert(RestoreMethods(),'native_method_restore_failed')
 local stable=CheckGeometry(current.name)
 host:SetWidth(480);host:GetWidth();ctx:FlushLayouts();layout:Layout()
 local narrow=CheckGeometry(current.name)
 host:SetWidth(960);host:GetWidth();ctx:FlushLayouts();layout:Layout()
 local wide=CheckGeometry(current.name)
 current.output.semantics={stableAt960=stable,conditionBoundaryAt480=narrow,conditionBoundaryAt960=wide,
  conditionBoundaryChecked=true,itemsDeclarationReused=true}
 CheckNativeCount()
 current.output.nativeObjectsAfter=highWater
 layout:Release();layout=nil
 current=nil;phase='next'
end
local function Finish()
 report.nativeObjectCount={physicalChildren=#objects,highWater=highWater,scope='private host descendants, regions, and explicitly counted unparented scheduler driver'}
 local cleanup=Cleanup()
 local valid=cleanup.driverStopped and cleanup.apiMethodsRestored and cleanup.nativeMethodsRestored and cleanup.parentHidden
  and cleanup.layoutOwnershipReleased and cleanup.remainingLayouts==0 and cleanup.motionJobs==0
  and cleanup.schedulerStopped and cleanup.schedulerEmpty and cleanup.subscriptionsEmpty and cleanup.installedLibraryUnchanged
 if not valid then
  report.business.ok=false;report.business.failure='layout_style_probe_cleanup_incomplete'
  probe:Log(report.business.failure);probe:Fail(report.business.failure);return
 end
 report.business.ok=true;finished=true;probe:Finish(report)
end
local function Step(callbackStart)
 if stopped or probe:IsCancelled() then return end
 assert(GetTimePreciseSec()-startedAt<29,'layout_style_probe_deadline')
 if phase=='next' then
  sceneIndex=sceneIndex+1;local name=scenes[sceneIndex]
  if not name then Finish();return end
  BuildScene(name);CheckNativeCount()
  current={name=name,output=NewOutput(name)};report.scenes[#report.scenes+1]=current.output
  current.mode='stable';samples={};iteration=0;phase='timing';return
 end
 if phase=='timing_setup' then PrepareTiming();return end
 if phase=='count_setup' then PrepareCounters();return end
 local processed=0;local callbackLimit=current.mode=='width_change' and 2 or 20
 while processed<callbackLimit and iteration<80 do
  iteration=iteration+1;processed=processed+1
  local kind=current.mode
  if phase=='timing' then
   local before=debugprofilestop();Operate(kind,iteration);samples[#samples+1]=debugprofilestop()-before
  else Operate(kind,iteration) end
 end
 if iteration==80 then
  if phase=='timing' then
   current.output.timing[ current.mode ]=Summary(samples)
   if current.mode=='stable' then current.mode='width_change';phase='timing_setup'
   else current.mode='stable';phase='count_setup' end
   return
  elseif current.mode=='stable' then
   local counts=current.counts;RestoreAPI();RestoreMethods()
   current.output.counters.stable=counts
   current.mode='width_change';phase='count_setup';return
  else
   local counts=current.counts;RestoreAPI();RestoreMethods()
   current.output.counters.widthChange=counts
   CompleteScene();return
  end
 end
 report.longestSynchronousSegmentMs=math.max(report.longestSynchronousSegmentMs or 0,debugprofilestop()-callbackStart)
end
local function Run()
 Setup()
 local callback=assert(probe:Callback(function()
  local began=debugprofilestop();local ok,message=pcall(Step,began)
  report.longestSynchronousSegmentMs=math.max(report.longestSynchronousSegmentMs or 0,debugprofilestop()-began)
  if not ok then Fail(message) end
 end))
 driver:SetScript('OnUpdate',callback);driver:Show()
end
local ok,message=pcall(Run)
if not ok then Fail(message) end
