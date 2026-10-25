-- Real product buttons use the constructor's native state refresh once per event.
-- Standalone: lua tests/test_button_state_performance.lua
local checks=0
local function Check(value,message) checks=checks+1;if T then T.ok(value,message) else assert(value,message) end end
local function Near(a,b,message) Check(math.abs(a-b)<.000001,message.." expected="..tostring(b).." actual="..tostring(a)) end
local function Color(actual,wanted,message)
 local r,g,b=actual:GetTextColor();Near(r,wanted[1],message..' red');Near(g,wanted[2],message..' green');Near(b,wanted[3],message..' blue')
end
local function Count(style)
 local count=0;local apply=style.Apply
 function style:Apply(...) count=count+1;return apply(self,...) end
 return function() local previous=count;count=0;return previous end
end
local function Event(button,event,take,message)
 take();button:Fire(event,'LeftButton');Check(take()==1,message..' applies its fixed controller once')
end
local function Batch(page,id)
 for _,batch in ipairs(page.batchPool) do if batch:IsShown() and batch.appID==id then return batch end end
 error('missing batch '..id)
end
local function Applicant(id)
 return {id=id,status='applied',displayOrderID=id,members={{name='Applicant'..id,nameKey='Applicant'..id..'-Home',class='WARRIOR',assignedRole='DAMAGER',rating=100,itemLevel=250}}}
end
for _,locale in ipairs({'zhCN','enUS'}) do for _,reduced in ipairs({false,true}) do
 local f=dofile('tests/ui_fixture.lua')(locale,{autoApply=true,applicationRoles={DAMAGER=true}},{reduceMotion=reduced});local a,u,g=f.A,f.U,f.G
 a:Open('find');local page=u.pages.find;local button=page.applicationSettings;local style=page.applicationSettingsStyle
 Check(style==button.styleController,'Find retains the constructor controller alias')
 local take=Count(style)
 Event(button,'OnEnter',take,'Find hover');Color(button.label,u.Theme.brand,'Find hover text')
 Event(button,'OnMouseDown',take,'Find press');Check(style.active.hover and style.active.pressed,'Find constructor tracks hover and pressed')
 Event(button,'OnMouseUp',take,'Find release');Check(style.active.hover and not style.active.pressed,'Find mouse-up keeps hover')
 Event(button,'OnLeave',take,'Find leave');Color(button.label,u.Theme.muted,'Find idle text')
 button:Fire('OnEnter');button:Fire('OnMouseDown');take();button:SetAvailable(false)
 Check(take()==1 and style.active.disabled and not style.active.hover and not style.active.pressed,'Find disable refreshes once and clears transient states')
 Near(button:GetAlpha(),u.Theme.disabledAlpha,'Find disabled opacity');Color(button.label,u.Theme.muted,'Find disabled text')
 button:SetAvailable(true);Check(not style.active.hover and not style.active.pressed,'Find enabling does not revive stale hover or press')
 button:Fire('OnEnter');button:Fire('OnMouseDown');button:Hide();Check(not style.active.hover and not style.active.pressed,'Find hiding clears transient state')
 button:Show();Event(button,'OnEnter',take,'Find reused hover');Event(button,'OnLeave',take,'Find reused leave')
 take();for i=1,120 do button:Fire('OnEnter');button:Fire('OnLeave') end
 Check(take()==240,'120 real Find hover cycles apply exactly once per native event')
 g.listing={activityID=2,name='Button feedback'};g.applicants={[1]=Applicant(1)}
 u:Navigate('create');local create=u.pages.create;local batch=Batch(create,1)
 Check(batch.cardStyle.sources[batch]~=nil,'batch card retains its custom hover binding')
 for _,name in ipairs({'invite','decline'}) do
  local action=batch[name];local feedback=action.feedbackStyle;local takeAction=Count(feedback)
  Check(feedback==action.styleController,'applicant action retains its constructor controller alias')
  local function Settle() u.context.Motion:Tick(1) end
  Event(action,'OnEnter',takeAction,name..' hover');Settle()
  Check(feedback.active.hover and action.hover:IsShown(),name..' hover remains visible')
  if reduced then Near(action.hover:GetAlpha(),u.Theme.createActionHoverAlpha,name..' hover opacity') end
  local color=name=='invite' and u.Theme.good or u.Theme.accent
  for i=1,3 do Near(action.hover.color[i],color[i],name..' hover tint') end
  Event(action,'OnMouseDown',takeAction,name..' press');Settle()
  Check(feedback.active.pressed and action.hover:IsShown(),name..' constructor tracks press')
  if reduced then Near(action.hover:GetAlpha(),u.Theme.createActionPressedAlpha,name..' pressed opacity') end
  Event(action,'OnMouseUp',takeAction,name..' release');Settle()
  Check(feedback.active.hover and not feedback.active.pressed and action.hover:IsShown(),name..' release retains hover feedback')
  if reduced then Near(action.hover:GetAlpha(),u.Theme.createActionHoverAlpha,name..' released opacity') end
  Event(action,'OnLeave',takeAction,name..' leave');Settle();Check(not action.hover:IsShown() and not feedback.active.hover and not feedback.active.pressed,name..' leave restores hidden idle feedback')
  action:Fire('OnEnter');action:Fire('OnMouseDown');takeAction();action:SetAvailable(false);Settle()
  Check(takeAction()==1 and feedback.active.disabled and not feedback.active.hover and not feedback.active.pressed,name..' disable refreshes once and clears transient states')
  Check(not action.hover:IsShown(),name..' disabled feedback is hidden');Near(action:GetAlpha(),u.Theme.disabledAlpha,name..' disabled opacity')
  action:SetAvailable(true);Check(not feedback.active.hover and not feedback.active.pressed,name..' enabling does not restore stale hover')
 end
 local oldInvite,oldDecline=batch.invite,batch.decline
 oldInvite:Fire('OnEnter');oldInvite:Fire('OnMouseDown')
 g.applicants={[2]=Applicant(2)};g:Notify('applicants');local rebound=Batch(create,2)
 Check(rebound==batch and rebound.invite==oldInvite and rebound.decline==oldDecline,'new applicants reuse the batch and both action buttons')
 oldInvite:Fire('OnClick','LeftButton');Check(g.invitedApplicant==nil,'a press from the old applicant cannot invite its replacement')
 for _,name in ipairs({'invite','decline'}) do
  local action=rebound[name];Check(action.targetKey==2,'rebound action targets the current applicant')
  local takeAction=Count(action.feedbackStyle)
  Event(action,'OnLeave',takeAction,'rebound '..name..' old leave')
  Check(not action.feedbackStyle.active.hover and not action.feedbackStyle.active.pressed,'rebound action leave clears transient states')
  Event(action,'OnEnter',takeAction,'rebound '..name..' hover');Event(action,'OnLeave',takeAction,'rebound '..name..' leave')
 end
 u:Navigate('notes');local notes=u.pages.notes
 for _,key in ipairs({'all','positive','neutral','caution','history'}) do
  local navigation=notes.tabs[key];local controller=navigation.navigationStyle;local takeNavigation=Count(controller)
  Check(controller==navigation.styleController,'Notes retains its constructor controller alias')
  Event(navigation,'OnEnter',takeNavigation,'Notes '..key..' hover')
  Event(navigation,'OnMouseDown',takeNavigation,'Notes '..key..' press')
  Check(controller.active.hover and controller.active.pressed,'Notes tracks hover and press')
  Event(navigation,'OnMouseUp',takeNavigation,'Notes '..key..' release')
  Event(navigation,'OnLeave',takeNavigation,'Notes '..key..' leave')
  notes:SelectTab(key);Check(controller.active.selected,'Notes selected state follows the current tab')
  navigation:Fire('OnEnter');navigation:Fire('OnMouseDown');takeNavigation();navigation:SetAvailable(false)
  Check(takeNavigation()==1 and controller.active.disabled and not controller.active.hover and not controller.active.pressed,'Notes disable refreshes once and clears transient states')
  navigation:SetAvailable(true);navigation:Fire('OnEnter');navigation:Fire('OnMouseDown');takeNavigation();navigation:Hide()
  Check(takeNavigation()==1 and not controller.active.hover and not controller.active.pressed,'Notes hiding refreshes once and clears transient states')
  navigation:Show();takeNavigation()
  for i=1,120 do navigation:Fire('OnEnter');navigation:Fire('OnLeave') end
  Check(takeNavigation()==240,'120 reused Notes hover cycles apply once per native event')
 end
 u:Hide(true);Check(u.context.Motion:Count()==0,'closing leaves no feedback animation tasks')
end end
print('Product button state performance: '..checks..' checks passed')
