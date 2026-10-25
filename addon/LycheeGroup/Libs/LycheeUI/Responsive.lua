local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
local Context=Library.Context
local empty={}
local function Visible(ui,job)
 if ui:IsHiding() then return false end
 local target=job.host or job.parent
 return target and (target.IsVisible and target:IsVisible() or not target.IsVisible and target:IsShown())
end
local Failed
local function NativeAxes(ui,layout,frame,item)
 local box=frame._lycheeBoxValues or empty;local C=ui.C
 local mw=item.manageWidth;if mw==nil then mw=box.manageWidth end;mw=C.LayoutValue(frame,"manageWidth",mw)~=false
 local mh=item.manageHeight;if mh==nil then mh=box.manageHeight end;mh=C.LayoutValue(frame,"manageHeight",mh)~=false
 local width=item.width;if width==nil then width=box.width end;width=C.LayoutValue(frame,"width",width)
 local height=item.height;if height==nil then height=box.height end;height=C.LayoutValue(frame,"height",height)
 return not mw or width==nil,not mh or height==nil,mw,mh
end
local function NativeInputChanged(entry)
 local source,owner=entry.source,entry.owner
 local width,height=source:GetWidth(),source:GetHeight()
 if entry.ui.C._IsLayoutWrite(source,owner) then entry.width,entry.height=width,height;return false end
 local watchW,watchH,manageW,manageH=NativeAxes(entry.ui,owner,source,entry.item)
 local changedW,changedH=watchW and width~=entry.width,watchH and height~=entry.height
 entry.width,entry.height=width,height
 local fields=source._lycheeLayoutFields;local record=owner.records[source]
 if changedW and manageW and fields and fields.width then
  if fields.width~=owner or entry.ui.C._IsLayoutWrite(source,owner,"width") or record and width==record.nativeReadW then changedW=false end
 end
 if changedH and manageH and fields and fields.height then
  if fields.height~=owner or entry.ui.C._IsLayoutWrite(source,owner,"height") or record and height==record.nativeReadH then changedH=false end
 end
 return changedW or changedH
end
local function SignalEntry(entry,kind)
 local ui,owner=entry.ui,entry.owner
 if entry.conditions then
  owner._conditionDirty=true
  ui:_QueueLayout(owner,kind)
 elseif not owner.released then
  if kind=="size" and owner.boxTarget==entry.source and ui.C._IsLayoutWrite(entry.source,owner) then return end
  if kind=="size" and entry.item and not NativeInputChanged(entry) then return end
  owner:Invalidate(kind)
 end
end
local function Notify(source,kind)
 local state=source._lycheeLayoutSignals
 if not state or #state.entries==0 then return end
 if kind=="size" and source._lycheeContainer then source._lycheeContainer.dirty=true end
 -- Signals may remove subscriptions or reenter while an earlier callback runs.
 local nested=state.dispatching
 local buffer=nested and {} or state.buffer
 local count=#state.entries
 for index=1,count do buffer[index]=state.entries[index] end
 state.dispatching=true
 for index=1,count do
  local entry=buffer[index];buffer[index]=nil
  if entry.owner and (kind~="size" or entry.size) then
   local ui,owner=entry.ui,entry.owner
   local ok,message=pcall(SignalEntry,entry,kind)
   if not ok then
    owner.lastError=tostring(message);owner._layoutFault=true
    if ui.layoutScheduler then Failed(ui,ui.layoutScheduler,owner,message)
    elseif ui.options.onLayoutError then pcall(ui.options.onLayoutError,tostring(message),owner) end
   end
  end
 end
 state.dispatching=nested
end
local function SizeSignal(source) Notify(source,"size") end
local function ShowSignal(source) Notify(source,"show") end
local function HideSignal(source) Notify(source,"hide") end
local signals={OnSizeChanged=SizeSignal,OnShow=ShowSignal,OnHide=HideSignal}
local function CanSignal(source,event)
 if not source or not source.HookScript then return false end
 local kind=source.GetObjectType and source:GetObjectType()
 if kind=="Texture" or kind=="MaskTexture" or kind=="FontString" then return false end
 return not source.HasScript or source:HasScript(event)
end
local function Subscribe(ui,owner,source,size,conditions)
 if not CanSignal(source,"OnShow") then return end
 local sources=owner._layoutSources
 if not sources then sources={};owner._layoutSources=sources end
 local entry=sources[source]
 if entry then entry.seen=true;entry.size=entry.size or size;return end
 local state=source._lycheeLayoutSignals
 if not state then
  state={entries={},buffer={}};source._lycheeLayoutSignals=state
  for event,handler in pairs(signals) do if CanSignal(source,event) then source:HookScript(event,handler) end end
 end
 entry={ui=ui,owner=owner,source=source,size=size,conditions=conditions,seen=true}
 state.entries[#state.entries+1]=entry;sources[source]=entry
end
local function Unsubscribe(owner,source,entry)
 local state=source._lycheeLayoutSignals
 if state then for index=1,#state.entries do if state.entries[index]==entry then table.remove(state.entries,index);break end end end
 entry.owner,entry.ui,entry.source=nil,nil,nil
 owner._layoutSources[source]=nil
end
local function BeginSources(owner)
 for _,entry in pairs(owner._layoutSources or empty) do entry.seen=false;entry.size=false end
end
local function EndSources(owner)
 for source,entry in pairs(owner._layoutSources or empty) do if not entry.seen then Unsubscribe(owner,source,entry) end end
end
local function ForgetSources(owner)
 for source,entry in pairs(owner._layoutSources or empty) do Unsubscribe(owner,source,entry) end
 owner._layoutSources=nil
end
local function Drive(frame) frame.context:FlushLayouts() end
local function Scheduler(ui)
 local state=ui.layoutScheduler
 if not state then
  state={queue={},work={},notifications={},flushes=0,prepares=0,commits=0,failures=0}
  ui.layoutScheduler=state
 end
 return state
end
local function Wake(ui,state)
 if state.flushing or ui:IsHiding() or #state.queue==0 then return end
 if not state.driver then state.driver=CreateFrame("Frame");state.driver.context=ui end
 if not state.driver:GetScript("OnUpdate") then state.driver:SetScript("OnUpdate",Drive) end
end
local function Cancel(ui,job)
 job._layoutQueued=nil
 local state=ui.layoutScheduler
 if not state then return end
 for index=#state.queue,1,-1 do if state.queue[index]==job then table.remove(state.queue,index) end end
 if not state.flushing then for index=#state.notifications,1,-1 do if state.notifications[index]==job then table.remove(state.notifications,index) end end end
 job._layoutNotifyQueued=nil
 if #state.queue==0 and not state.flushing and state.driver then state.driver:SetScript("OnUpdate",nil) end
end
function Context:_QueueLayout(job,reason)
 if job.released or job._layoutContext~=self then return end
 job.lastInvalidation=reason or job.lastInvalidation or "explicit"
 if not Visible(self,job) then Cancel(self,job);return end
 local state=Scheduler(self)
 if not state.flushing then job._layoutFault=nil;job._layoutFeedbackFrames=nil end
 if state.notifying then job._layoutFromNotify=true end
 if job._layoutFault or job._layoutQueued then return end
 job._layoutQueued=true;state.queue[#state.queue+1]=job
 Wake(self,state)
end
function Context:_TrackLayout(layout)
 if layout.released then return end
 if layout._layoutContext and layout._layoutContext~=self then layout._layoutContext:_ForgetLayout(layout) end
 layout._layoutContext=self
 self._trackedLayouts=self._trackedLayouts or setmetatable({},{__mode="k"})
 self._trackedLayouts[layout]=true
 BeginSources(layout)
 Subscribe(self,layout,layout.parent,true,false)
 for _,item in ipairs(layout.items) do
  local frame=item.frame or item;local declaration=item.frame and item or empty
  if declaration.participate~=false then
   local width,height=NativeAxes(self,layout,frame,declaration)
   if width or height or not layout.options.includeHidden and not declaration.reserve then
    Subscribe(self,layout,frame,width or height,false)
    local entry=layout._layoutSources and layout._layoutSources[frame]
    if entry and frame~=layout.parent then entry.item=declaration;entry.width,entry.height=frame:GetWidth(),frame:GetHeight() end
   end
  end
 end
 EndSources(layout)
 if layout.dirty then self:_QueueLayout(layout,"track") end
end
function Context:_ForgetLayout(layout)
 Cancel(self,layout);ForgetSources(layout)
 if self._trackedLayouts then self._trackedLayouts[layout]=nil end
 layout._layoutContext=nil
end
function Context:_LayoutSettled(layout)
 if not layout.dirty and not (self.layoutScheduler and self.layoutScheduler.flushing) then Cancel(self,layout) end
end
function Context:_DeferLayout(job,reason)
 local state=Scheduler(self)
 if not state.flushing or state.notifying then return self:_QueueLayout(job,reason) end
 if not state.deferred then state.deferred={} end
 if not job._layoutDeferred then job._layoutDeferred=true;state.deferred[#state.deferred+1]=job end
 job._layoutContinue=true;job.lastInvalidation=reason or job.lastInvalidation
end
function Context:_TrackWork(job)
 if job.released then return end
 if job._layoutContext and job._layoutContext~=self then job._layoutContext:_ForgetWork(job) end
 job._layoutContext=self
 self._layoutWork=self._layoutWork or setmetatable({},{__mode="k"})
 self._layoutWork[job]=true
 BeginSources(job);Subscribe(self,job,job.host,true,false);EndSources(job)
 if job.dirty then self:_QueueLayout(job,"track") end
end
function Context:_ForgetWork(job)
 Cancel(self,job);ForgetSources(job)
 if self._layoutWork then self._layoutWork[job]=nil end
 job._layoutContext=nil
end
local function FindContainer(ui,target,name,parentOverride)
 local node=parentOverride or target and target.GetParent and target:GetParent()
 local depth=0
 while node do
  depth=depth+1;if depth>128 then error("container ancestry is cyclic or exceeds 128 parents",3) end
  local container=node._lycheeContainer
  if container and container.context==ui and (name==nil or container.name==name) then return node,container end
  node=node.GetParent and node:GetParent()
 end
end
local function Bound(ui,value)
 if value==nil then return nil end
 local result=type(value)=="string" and ui:ResolveValue(value) or value
 if type(result)~="number" or result<0 or result~=result or result==math.huge then error("container bound must be a finite nonnegative number or token",3) end
 return result
end
local function CheckConditions(ui,controller,conditions)
 for _,condition in ipairs(conditions) do
  for _,selector in ipairs(condition.when or empty) do
   FindContainer(ui,controller.host,selector.container,controller._conditionParent)
   Bound(ui,selector.minWidth);Bound(ui,selector.maxWidth)
  end
 end
end
function Context:_BindConditions(controller,conditions)
 if conditions and #conditions>0 then CheckConditions(self,controller,conditions) end
 if controller._layoutContext and controller._layoutContext~=self then controller._layoutContext:_ReleaseConditions(controller) end
 if not conditions or #conditions==0 then self:_ReleaseConditions(controller);return end
 controller._layoutContext=self
 self._conditionalControllers=self._conditionalControllers or setmetatable({},{__mode="k"})
 self._conditionalControllers[controller]=true
 local bindings=controller._conditionBindings or {};controller._conditionBindings=bindings
 controller.conditionMatches=controller.conditionMatches or {}
 BeginSources(controller)
 -- The host's visibility matters even if every source container stays visible.
 Subscribe(self,controller,controller.host,false,true)
 for index,condition in ipairs(conditions) do
  local selectors=condition.when or {condition}
  local branch=bindings[index] or {};bindings[index]=branch
  for position,selector in ipairs(selectors) do
   local target,container=FindContainer(self,controller.host,selector.container,controller._conditionParent)
   local binding=branch[position] or {};branch[position]=binding
   binding.target,binding.container,binding.name=target,container,selector.container
   binding.minWidth,binding.maxWidth=Bound(self,selector.minWidth),Bound(self,selector.maxWidth)
   if target then Subscribe(self,controller,target,true,true) end
  end
  for position=#branch,#selectors+1,-1 do branch[position]=nil end
 end
 for index=#bindings,#conditions+1,-1 do bindings[index]=nil;controller.conditionMatches[index]=nil end
 EndSources(controller)
 controller._conditionDirty=true
 self:_RefreshConditions(controller)
end
function Context:_RefreshConditions(controller)
 if not controller._conditionDirty or controller.released then return false end
 local changed=false
 for index,branch in ipairs(controller._conditionBindings or empty) do
  local matched=true
  for _,binding in ipairs(branch) do
   local target,container=binding.target,binding.container
   if target and (container.dirty or container.width==nil) then
    container.width=math.max(0,target:GetWidth()-(container.left or 0)-(container.right or 0));container.dirty=false
   end
   local width=target and container.width
   binding.width=width
   if not width or binding.minWidth and width<binding.minWidth or binding.maxWidth and width>=binding.maxWidth then matched=false end
  end
  if controller.conditionMatches[index]~=matched then controller.conditionMatches[index]=matched;changed=true end
 end
 controller._conditionDirty=false
 if changed then controller._conditionApplyNeeded=true end
 return changed
end
function Context:_ReleaseConditions(controller)
 if not controller._conditionBindings then return end
 Cancel(self,controller);ForgetSources(controller)
 if self._conditionalControllers then self._conditionalControllers[controller]=nil end
 controller._conditionBindings,controller.conditionMatches,controller._conditionDirty,controller._conditionApplyNeeded=nil,nil,nil,nil
 controller._layoutContext=nil
end
Failed=function(ui,state,job,message)
 job.lastError=tostring(message);job._layoutFault=true
 state.failures=state.failures+1;state.lastError=job.lastError
 if job.mode=="flex" then job.dirty=true;job.prepared=false;job._notifyPending=nil end
 if job._conditionBindings then job._conditionDirty=true;job._conditionApplyNeeded=true end
 local handler=ui.options.onLayoutError
 if handler then pcall(handler,job.lastError,job) end
end
function Context:FlushLayouts()
 local state=self.layoutScheduler
 if not state or state.flushing or self:IsHiding() then return true end
 state.flushing=true;state.lastError=nil;state.flushes=state.flushes+1
 local queue,work,notifications=state.queue,state.work,state.notifications
 local deferred=state.deferred
 if not deferred then deferred={};state.deferred=deferred end
 local rounds=0
 while #queue>0 and rounds<4 do
  rounds=rounds+1
  local count=#queue
  for index=1,count do local job=queue[index];work[index]=job;queue[index]=nil;job._layoutQueued=nil;job._layoutPrepared=nil end
  -- Select every conditional branch before geometry reads see its values.
  for index=1,count do local job=work[index]
   if job._conditionBindings and job._layoutContext==self and not job.released and Visible(self,job) then
    local ok,changed=pcall(self._RefreshConditions,self,job)
    if ok then job._layoutPrepared=changed or job._conditionApplyNeeded else Failed(self,state,job,changed) end
   end
  end
  for index=1,count do local job=work[index]
   if job.mode=="flex" and job._layoutContext==self and not job.released and Visible(self,job) then
    local ok,message=pcall(job.PrepareLayout,job)
    state.prepares=state.prepares+1
    if ok then job._layoutPrepared=job.prepared else Failed(self,state,job,message) end
   end
  end
  -- Conditional font changes can invalidate the prepared geometry. Those
  -- records are recomputed in the next bounded pass, before the frame paints.
  -- Commit a list's common height projection before its visible row styles.
  -- Every row then sees the same complete prefix, including offscreen keys.
  for phase=1,2 do for index=1,count do local job=work[index]
   if (job._listHeightProjection==true)==(phase==1) and job._conditionBindings and job._layoutPrepared and job._layoutContext==self and not job.released then
    local ok,message=pcall(job.Apply,job,true)
    if not ok then Failed(self,state,job,message) end
   end
  end end
  for index=1,count do local job=work[index];work[index]=nil
   if job.mode=="flex" and job._layoutPrepared and job._layoutContext==self and not job.released and Visible(self,job) then
    local ok,message=pcall(job.CommitLayout,job,true)
    if ok then
     state.commits=state.commits+1
     if job._notifyPending and not job._layoutNotifyQueued then job._layoutNotifyQueued=true;notifications[#notifications+1]=job end
    else Failed(self,state,job,message) end
   end
   if job.mode=="list-flow" and job._layoutContext==self and not job.released and not job._layoutStepped and Visible(self,job) then
    job._layoutStepped=true
    if not job._layoutDeferred then job._layoutDeferred=true;deferred[#deferred+1]=job end
    local ok,done=pcall(job.StepLayout,job)
    if not ok then Failed(self,state,job,done)
    elseif done then
     if job._notifyPending and not job._layoutNotifyQueued then job._layoutNotifyQueued=true;notifications[#notifications+1]=job end
    else job._layoutContinue=true end
   end
   job._layoutPrepared=nil
  end
 end
 if #queue>0 then
  for index=#queue,1,-1 do local job=queue[index];queue[index]=nil;job._layoutQueued=nil;Failed(self,state,job,"layout feedback did not settle in four passes") end
 end
 -- Index rebuilds do one bounded step per frame and share this driver.
 for index=1,#deferred do
  local job=deferred[index];deferred[index]=nil;job._layoutStepped,job._layoutDeferred=nil,nil
  if job._layoutContinue or job.dirty then job._layoutContinue=nil;self:_QueueLayout(job,"continue") end
 end
 -- Callbacks may hide, release or invalidate another owner. They enter the
 -- next frame's queue, never the current read/compute/commit batch.
 state.notifying=true
 for index=1,#notifications do local job=notifications[index];notifications[index]=nil;job._layoutNotifyQueued=nil
  if not job.released and not job._layoutFault and job._layoutContext==self and Visible(self,job) then
   local ok,message=pcall(job.NotifyLayout,job)
   if not ok then Failed(self,state,job,message) end
  else job._notifyPending=nil end
 end
 state.notifying=false
 for index=#queue,1,-1 do
  local job=queue[index]
  if job._layoutFromNotify then
   job._layoutFromNotify=nil;job._layoutFeedbackFrames=(job._layoutFeedbackFrames or 0)+1
   if job._layoutFeedbackFrames>4 then
    table.remove(queue,index);job._layoutQueued=nil
    Failed(self,state,job,"layout notification feedback did not settle in four frames")
   end
  end
 end
 state.flushing=false
 if state.driver then state.driver:SetScript("OnUpdate",nil) end
 Wake(self,state)
 return state.lastError==nil,state.lastError
end
function Context:_SuspendLayouts()
 local state=self.layoutScheduler
 if not state then return end
 for index=#state.queue,1,-1 do local job=state.queue[index];job._layoutQueued=nil;state.queue[index]=nil end
 if state.driver then state.driver:SetScript("OnUpdate",nil) end
end
function Context:_ResumeLayouts()
 for layout in pairs(self._trackedLayouts or empty) do if layout.dirty then self:_QueueLayout(layout,"resume") end end
 for controller in pairs(self._conditionalControllers or empty) do if controller._conditionDirty then self:_QueueLayout(controller,"resume") end end
 for job in pairs(self._layoutWork or empty) do if job.dirty then self:_QueueLayout(job,"resume") end end
end
local function Descendant(target,ancestor)
 local depth=0
 while target do
  if target==ancestor then return true end
  depth=depth+1;if depth>128 then return false end
  target=target.GetParent and target:GetParent()
 end
 return false
end
function Context:_RebindResponsiveTree(target)
 for controller in pairs(self._conditionalControllers or empty) do if Descendant(controller.host,target) then CheckConditions(self,controller,controller.conditionSelectors) end end
 for controller in pairs(self._conditionalControllers or empty) do if Descendant(controller.host,target) then
  self:_BindConditions(controller,controller.conditionSelectors)
  self:_QueueLayout(controller,"reparent")
 end end
 for layout in pairs(self._trackedLayouts or empty) do if Descendant(layout.parent,target) then self:_TrackLayout(layout);layout:Invalidate("reparent") end end
end
function Library.AttachResponsive(UI)
 local C=UI.C
 function C.Container(target,name,options)
  if type(name)~="string" or name=="" or name:find("[%s:/]") then error("container name must be a nonempty identifier",2) end
  options=options or empty
  local left,right=Bound(UI,options.left) or 0,Bound(UI,options.right) or 0
  local previous=target._lycheeContainer
  if previous and previous.context==UI and previous.name==name and previous.left==left and previous.right==right then return target end
  if previous and previous.context~=UI then error("container belongs to another Context; release it before rebinding",2) end
  target._lycheeContainer={context=UI,name=name,left=left,right=right,dirty=true}
  local ok,message=pcall(UI._RebindResponsiveTree,UI,target)
  if not ok then target._lycheeContainer=previous;error(message,0) end
  return target
 end
 function C.ReleaseContainer(target)
  local container=target._lycheeContainer
  if container and container.context==UI then
   target._lycheeContainer=nil
   local ok,message=pcall(UI._RebindResponsiveTree,UI,target)
   if not ok then target._lycheeContainer=container;error(message,0) end
  end
  return target
 end
 function C.RebindLayout(target)
  UI:_RebindResponsiveTree(target)
  local own=target._lycheeBoxLayout;if own and not own.released then own:Invalidate("rebind") end
  return target
 end
 function C.InvalidateContainer(target)
  local container=target._lycheeContainer
  if container and container.context==UI then container.dirty=true;Notify(target,"size") end
  return target
 end
 local function RefreshLayoutConditions(target)
  local controller=target._lycheeStyleController
  if controller and controller._conditionDirty then
   local context=controller.context or controller._layoutContext or UI
   if context:_RefreshConditions(controller) then context:_QueueLayout(controller,"condition") end
  end
  local records=target._lycheeFixedRecords
  if records then for record in pairs(records) do
   local owner=record.controller
   if owner~=controller and owner._conditionDirty then
    local context=owner.context or owner._layoutContext or UI
    if context:_RefreshConditions(owner) then context:_QueueLayout(owner,"condition") end
   end
  end end
 end
 function C._ReadLayoutValues(target,out,keys,item)
  RefreshLayoutConditions(target)
  return C._ProjectFixedLayout(target,out,keys,item)
 end
 function C.LayoutValue(target,key,fallback)
  RefreshLayoutConditions(target)
  local value=C.FixedValue(target,key,nil)
  if value~=nil then return value end
  -- Numeric native size is a measurement, not an enduring Box declaration.
  if key~="width" and key~="height" then
   local box=target._lycheeBoxValues
   if box and box[key]~=nil then return box[key] end
  end
  return fallback
 end
 function C.ReleaseBox(target)
  if target._lycheeBoxContext and target._lycheeBoxContext~=UI then return target end
  local layout=target._lycheeBoxLayout
  if layout and layout.context and layout.context~=UI then return target end
  if layout then layout:Release();target._lycheeBoxLayout=nil end
  C.ClearBoxRules(target)
  C.ReleaseContainer(target)
  target._lycheeBoxApply,target._lycheeBoxValues,target._lycheeBoxContext=nil,nil,nil;UI.boxes[target]=nil
  C.ApplyElement(target);C.InvalidateLayout(target,"box-release")
  local controller=target._lycheeStyleController
  if not UI.elements[target] and controller and controller.context==UI and not controller.hasOverrides then controller:Release() end
  return target
 end
 function C.InvalidateLayout(target,reason)
  local function Invalidate(owner)
   local context=owner._layoutContext
   if owner.mode=="flex" and owner.options.track and context then context:_TrackLayout(owner) end
   owner:Invalidate(reason or "content")
  end
  local own=target._lycheeBoxLayout
  if own then Invalidate(own) end
  local fields=target._lycheeLayoutFields
  if fields then
   local w,h,p=fields.width,fields.height,fields.points
   if w and w~=own then Invalidate(w) end
   if h and h~=w and h~=own then Invalidate(h) end
   if p and p~=w and p~=h and p~=own then Invalidate(p) end
  end
  local inputs=target._lycheeLayoutInputs
  if inputs then
   local w,h,p=fields and fields.width,fields and fields.height,fields and fields.points
   if inputs.mode=="flex" then
    if inputs~=own and inputs~=w and inputs~=h and inputs~=p then Invalidate(inputs) end
   else
    for layout in pairs(inputs) do if layout~=own and layout~=w and layout~=h and layout~=p then Invalidate(layout) end end
   end
  end
  return target
 end
 function C.ExplainLayout(target)
  local layout=target._lycheeBoxLayout or target._lycheeLayoutOwner
  local controller=target._lycheeStyleController
  local report={objectType=target.GetObjectType and target:GetObjectType(),mode=layout and layout.mode or controller and controller._conditionBindings and "conditions" or "native",conditions={}}
  local job=layout or controller
  if job then report.reason,report.error,report.dirty,report.queued=job.lastInvalidation,job.lastError,job.dirty or job._conditionDirty,job._layoutQueued==true end
  if layout then report.items=#layout.items;report.metricsRetries=layout._metricsRetries end
  local fields=target._lycheeLayoutFields
  if fields then
   report.ownership={width=fields.width~=nil,height=fields.height~=nil,points=fields.points~=nil}
   report.owners={width=fields.width,height=fields.height,points=fields.points}
  end
  local state=UI.layoutScheduler
  if state then report.scheduler={queued=#state.queue,flushes=state.flushes,prepares=state.prepares,commits=state.commits,failures=state.failures} end
  for index,branch in ipairs(controller and controller._conditionBindings or empty) do
   local condition={matched=controller.conditionMatches[index],sources={}};report.conditions[index]=condition
   for position,binding in ipairs(branch) do condition.sources[position]={name=binding.name,width=binding.width,minWidth=binding.minWidth,maxWidth=binding.maxWidth,missing=binding.target==nil} end
  end
  return report
 end
end
