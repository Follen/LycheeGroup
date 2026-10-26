-- Observe only the active production controls. Pages know nothing about steps.
local A=_G.LycheeGroup
local Guide=A.Guide
local function Current()
 if not Guide.active or not Guide.ready or Guide.preparing or Guide.pendingAdvance then return end
 local UI=A.UI
 return Guide.steps[Guide.index],Guide.phase,UI.pages[Guide.page],UI.preview.provider,UI
end
local function Visible(frame) return frame and frame:IsVisible() end
local function Geometry() Guide:QueueUpdate() end

function Guide:QueueUpdate()
 if not Current() or self.task then return end
 self.task=C_Timer.NewTimer(0,function()
  Guide.task=nil
  if Current() then Guide:UpdateStep() end
 end)
end

function Guide:AvoidFrame()
 local UI=A.UI;local tip=UI.Tooltip
 if Visible(tip.interactive) then return tip.interactive end
 if Visible(tip.text) then return tip.text end
 if UI.activeModal then return UI.activeModal.frame end
end

-- Keep the list or popup being explained visible, not only its current button.
-- Unlike AvoidFrame, this region remains masked and never becomes interactive.
function Guide:ContextFrame()
 local id,phase,page,_,UI=Current();if not id then return end
 if UI.activeModal then return UI.activeModal.frame end
 if Visible(page.picker) then return page.picker end
 if self.page=="find" then
  if id=="activity" or id=="sidebar" then return page.rail
  elseif id=="filters" then return page.filtersOpen and page.filterPanel or page.search
  elseif id=="apply" and phase==5 then return page.applicationPanel
  elseif id=="details" or id=="sort" or id=="apply" then return page.results end
 elseif id=="faction" or id=="time" then return page.batchScroll
 elseif id=="createActivity" then return page.pickerTrigger:GetParent()
 elseif id=="publish" then return page.publish:GetParent() end
end

-- A popup can close through its own outside-click handler. Recover on the next
-- layout task, after any selection/submission callback has finished.
function Guide:RecoverPhase()
 local id,phase,page,provider,UI=Current()
 if not id or phase==1 then return end
 -- Submission closes the modal before its click callback finishes. A native
 -- layout/hover refresh can arrive in between; the application is already live.
 if id=="apply" and phase<5 and not UI.Application.previewApplication
  and self.appliedID and provider.Applications:IsActive(self.appliedID) then
  self.phase=5;return
 end
 if (id=="activity" or id=="createActivity") and not Visible(page.picker)
  or id=="filters" and not page.filtersOpen
  or id=="details" and not Visible(UI.Tooltip.interactive)
  or id=="apply" and phase<5 and not UI.Application.previewApplication then
  self.phase=1;self.appliedID=nil
  if id=="activity" then self.activityChoiceGoal=nil end
 end
end

local function AfterEnter(control)
 local id,phase,_,_,UI=Current();if not id then return end
 -- Native HookScript observers run after the leased primary script. Recheck
 -- once after this event stack, including tooltips opened by a child region.
 Guide:QueueUpdate()
 if id=="details" then Guide.detailsLeaving=nil end
 if id=="details" then
  local row=control:GetParent()
  if UI.Tooltip:IsResult(row.key) and (phase==1 or Guide.detailsArea~=control) then Guide.detailsArea=control;Guide:SetPhase(2);return end
 end
 Guide:UpdateStep()
end
local function DetailsLeave()
 local id,phase=Current()
 if id=="details" and phase==2 then Guide.detailsLeaving=true end
 Guide:QueueUpdate()
end
local function PopupHide(frame)
 local id,phase,_,_,UI=Current()
 if id=="details" and phase==2 and Guide.detailsLeaving and frame==UI.Tooltip.interactive then Guide:QueueAdvance()
 else Guide:QueueUpdate() end
end

local function BeforeClick(_,button)
 local id=Current()
 if id=="createPage" and (not button or button=="LeftButton") then Guide.transition=true end
end
local function AfterClick(control,button)
 Guide.transition=nil
 if button and button~="LeftButton" then return end
 local id,phase,page,provider,UI=Current();if not id then return end
 if id=="activity" or id=="createActivity" then
  if phase==1 then
   if Visible(page.picker) then
    if id=="activity" then Guide:PrepareActivityPicker() else UI.Motion:FinishPlacement(page.picker) end
    Guide:SetPhase(2)
   end
  elseif id=="createActivity" then
   local activity=provider.Catalog:GetActivity(page:FormData().activityID)
   if not Visible(page.picker) and activity then Guide:UseCreationActivity(activity);Guide:QueueAdvance() end
  elseif not Visible(page.picker) and #provider:GetResults()>0 then Guide:QueueAdvance()
  elseif page.draftGroupKeys then
   local count=Guide:ActivityChoiceCount()
   Guide:SetPhase(count>=(Guide.activityChoiceGoal or 1) and 4 or count>0 and 3 or 2)
  end
 elseif id=="createPage" and UI.page=="create" then Guide.page="create";Guide:QueueAdvance()
 elseif id=="sidebar" then
  local collapsed=provider.prefs.find.railCollapsed
  if phase==1 and collapsed then Guide:SetPhase(2)
  elseif phase==2 and not collapsed then Guide:QueueAdvance() end
 elseif id=="filters" then
  if phase==1 and page.filtersOpen then Guide:SetPhase(2)
  elseif phase==1 and provider.filters.healerPresence then Guide:QueueAdvance()
  elseif phase==2 and page.filtersOpen and provider.filters.healerPresence then Guide:SetPhase(3)
  elseif phase==2 and not page.filtersOpen and not Guide:RoleFilterTarget() then Guide:QueueAdvance()
  elseif phase==3 and not page.filtersOpen and provider.filters.healerPresence then Guide:QueueAdvance() end
 elseif id=="sort" then
  if phase==1 then Guide:SetPhase(2) else Guide:QueueAdvance() end
 elseif id=="apply" then
  local lease=UI.Application.previewApplication
  if phase==2 and lease and lease.roles.HEALER then Guide:SetPhase(3)
  elseif phase==3 and (UI.Application:IsAutoApplyEnabled() or lease and lease.enableOnSave) then Guide:SetPhase(4)
  elseif phase==4 and provider.Applications:IsActive(Guide.appliedID) then Guide:SetPhase(5)
  elseif phase==5 and not provider.Applications:IsActive(Guide.appliedID) then Guide:QueueAdvance() end
 elseif id=="publish" and provider:GetListing() then Guide:QueueAdvance()
 elseif id=="faction" or id=="time" then
  local row=control:GetParent()
  local expanded=id=="faction" and row.factionExpanded or id=="time" and row.mapScoreTime
  if phase==1 and expanded then Guide:SetPhase(2)
  elseif phase==2 and not expanded then Guide:QueueAdvance() end
 end
end

local function AfterDoubleClick(_,button)
 local id,phase,_,_,UI=Current()
 if id=="apply" and phase==1 and button=="LeftButton" and UI.Application.previewApplication then
  Guide.appliedID=UI.Application.previewApplication.id;Guide:SetPhase(2)
 end
end
local function FinishResize()
 local id,_,_,_,UI=Current();local start=Guide.resizeStart
 if id~="resize" or not start or UI.resizing then return end
 Guide.resizeStart=nil
 local x,y=GetCursorPosition()
 if (x~=start.x or y~=start.y) and (UI.windowWidth~=start.width or UI.windowHeight~=start.height) then Guide:QueueAdvance() end
end
local function ResizeTick()
 -- The existing driver clears its own OnUpdate when released outside the grip.
 -- This invocation still finishes; no extra update loop is introduced.
 FinishResize()
end
local function AfterResizeDown(control,button)
 local id,_,_,_,UI=Current()
 if id=="resize" and button=="LeftButton" and UI.resizing then
  Guide.resizeStart={width=UI.resizing.width,height=UI.resizing.height,x=UI.resizing.cursorX,y=UI.resizing.cursorY}
  Guide.Bindings:Bind(control,"OnUpdate",ResizeTick)
 end
end
local function AfterResizeUp(_,button) if button=="LeftButton" then FinishResize() end end

function Guide:ReleaseBindings()
 self.Bindings:Clear()
 self.boundTarget,self.boundIndex,self.boundPhase,self.boundAvoid,self.boundContext,self.resizeStart=nil,nil,nil,nil,nil,nil
end
function Guide:BindStep(target,avoid,context)
 if self.boundTarget==target and self.boundIndex==self.index and self.boundPhase==self.phase and self.boundAvoid==avoid and self.boundContext==context then return end
 self:ReleaseBindings()
 self.boundTarget,self.boundIndex,self.boundPhase,self.boundAvoid,self.boundContext=target,self.index,self.phase,avoid,context
 local id,phase,page,_,UI=Current();if not id then return end
 local bindings=self.Bindings
 bindings:Bind(UI.frame,"OnSizeChanged",Geometry)
 if page.rail then bindings:Bind(page.rail,"OnSizeChanged",Geometry) end
 if page.picker then bindings:Bind(page.picker,"OnHide",Geometry) end
 if avoid then bindings:Bind(avoid,"OnHide",PopupHide);bindings:Bind(avoid,"OnSizeChanged",Geometry) end
 if context and context~=avoid then
  bindings:Bind(context,"OnSizeChanged",Geometry);bindings:Bind(context,"OnHide",Geometry)
 end
 if not target then return end
 bindings:Bind(target,"OnEnter",AfterEnter)
 bindings:Bind(target,"OnLeave",Geometry)
 if target.tooltipArea then bindings:Bind(target.tooltipArea,"OnEnter",AfterEnter) end
 if id=="resize" then
  bindings:Bind(target,"OnMouseDown",AfterResizeDown);bindings:Bind(target,"OnMouseUp",AfterResizeUp)
 elseif id=="details" then
  -- The production hover callback creates and positions the tooltip first;
  -- search-result members remain read-only, just as in the ordinary UI.
  if phase==2 then
   bindings:Bind(target,"OnLeave",DetailsLeave)
   if avoid then bindings:Bind(avoid,"OnEnter",AfterEnter);bindings:Bind(avoid,"OnLeave",DetailsLeave) end
  end
 elseif id=="apply" and phase==1 then bindings:Bind(target,"OnDoubleClick",AfterDoubleClick)
 else bindings:Bind(target,"OnClick",AfterClick,id=="createPage" and BeforeClick or nil) end
 if id=="activity" and (phase==2 or phase==3) and self.activityChoiceGoal then
  for _,row in ipairs(page.activities.rows) do
   if row._hitVisible and row:IsShown() and page.keystoneGroups[row.key] then
    bindings:Bind(row,"OnClick",AfterClick);bindings:Bind(row.multiSelect,"OnClick",AfterClick)
   end
  end
 end
 if id=="details" or id=="apply" and phase==1 then
  for _,row in ipairs(page.results.rows) do
   if row._hitVisible and row:IsShown() then
    if id=="details" then bindings:Bind(row.tooltipArea,"OnEnter",AfterEnter)
    else bindings:Bind(row,"OnDoubleClick",AfterDoubleClick) end
   end
  end
 end
end
