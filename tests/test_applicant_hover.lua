-- Applicant cards must release their hover surface after every pointer exit.
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G=f.A,f.U,f.G
A:SetSetting("reduceMotion",true)
G.listing={activityID=2,name="Hover regression"}
for id=1,2 do
 G.applicants[id]={id=id,status="applied",displayOrderID=id,members={{name="Applicant"..id.."-Home",class="MAGE",assignedRole="DAMAGER"}}}
end
A:Open("create")
local P=U.pages.create
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Visible(batch) return batch.bg:IsShown() and batch.bg:GetAlpha()>0 end
local function Idle(batch,index,message)
 Check(Visible(batch)==(index%2==0),message.." restores alternating-row visibility")
 for channel=1,3 do Check(batch.bg.color[channel]==U.Theme.rowAlternate[channel],message.." restores its normal color") end
end
for index=1,2 do
 local batch=P.batchPool[index]
 local row=batch.people[1]
 Idle(batch,index,"idle applicant "..index)
 row.mouseOver=true;row:Fire("OnEnter")
 Check(Visible(batch),"entering an applicant member shows its card hover: "..index)
 row.mouseOver=false;row:Fire("OnLeave");U.Motion:Tick(.25)
 Idle(batch,index,"leaving applicant "..index)
 row:Fire("OnEnter");row:Hide()
 Idle(batch,index,"hiding applicant "..index)
 row:Show();G:Notify("applicants")
 Idle(batch,index,"reusing applicant "..index)
 P.batchScroll.mouseOver=true;row.tooltipArea:Fire("OnEnter")
 Check(U.Tooltip.owner==row and Visible(batch),"the identity hover area opens details and highlights its card")
 row.mouseOver=false;row.tooltipArea:Fire("OnLeave");U.Motion:Tick(.25)
 Check(U.Tooltip.owner==nil,"leaving identity closes unpinned details")
 Idle(batch,index,"leaving applicant identity "..index)
end
-- Replay A -> the next applicant B -> the current player's WCL action C.
-- Pointer coordinates and hover flags are supplied by the offline substitute;
-- the real row scripts decide which identity and link remain selected.
local tip=U.Tooltip
local first,second=P.batchPool[1].people[1],P.batchPool[2].people[1]
local boundaryY=100+first:GetHeight()
local function Move(x,y)
 local scale=U.frame:GetEffectiveScale()
 f.S.cursorX=(U.frame:GetLeft()+x)*scale;f.S.cursorY=(U.frame:GetTop()-y)*scale
end
local function Enter(row)
 row.mouseOver=true;row.tooltipArea.mouseOver=true;row.tooltipArea:Fire("OnEnter")
end
local function Leave(row)
 row.mouseOver=false;row.tooltipArea.mouseOver=false;row.tooltipArea:Fire("OnLeave")
end
P.batchScroll.mouseOver=true
local function Reset()
 for _,row in ipairs({first,second}) do row.mouseOver=false;row.tooltipArea.mouseOver=false end
 tip.interactive.mouseOver=false;tip:Hide()
end
local function Cross(x,direction)
 Reset();Move(x,boundaryY-8);Enter(first)
 Check(tip.positionY<=boundaryY-8 and tip.positionY+tip.interactive:GetHeight()>=boundaryY-8,"the popup is vertically reachable from its initial pointer")
 Move(x+direction*8,boundaryY+6);Leave(first);Enter(second)
 Check(tip.owner==first,"crossing applicant B toward the open tooltip must retain applicant A")
end
local scale=U.frame:GetScale()
for _,value in ipairs({1,1.4}) do
 U.frame:SetScale(value)
 for _,direction in ipairs({1,-1}) do
  local x=direction==1 and 220 or UIParent:GetWidth()/U.frame:GetEffectiveScale()-40
  Cross(x,direction)
  Check((tip.positionX-x)*direction>0,"the scenario exercises the intended screen side")
  Move(x+direction*15,boundaryY+20);U.Motion:Tick(.08)
  Move(x+direction*24,boundaryY+30);Leave(second);tip.interactive.mouseOver=true;tip.interactive:Fire("OnEnter")
  Check(not U.Motion:IsRunning(tip),"entering the tooltip stops the transit task")
  tip.interactive.wcl:Fire("OnClick","LeftButton")
  Check(tip.member==first.member and tip.copyValue:find("Applicant1",1,true),"WCL still copies applicant A after the diagonal crossing")
  Check(tip.hoverOwner==nil and tip.hoverX==nil,"entering and copying release the pending row")
 end
end
U.frame:SetScale(scale)
Cross(220,1);U.Motion:Tick(.21)
Check(tip.owner==second,"pausing on applicant B selects B after the short transit grace")
Check(not U.Motion:IsRunning(tip),"settling on B leaves no transit task")
Cross(220,1);tip:RefreshRelations();U.Motion:Tick(.21)
Check(tip.owner==second,"a same-player data refresh cannot strand the pending applicant or stop its transit task")
Cross(220,1);Move(216,boundaryY+10);U.Motion:Tick(.12)
Check(tip.owner==second,"moving away from the popup selects the hovered applicant")
Cross(220,1)
for step=1,12 do Move(228+step*.25,boundaryY+6);U.Motion:Tick(.1) end
Check(tip.owner==second and not U.Motion:IsRunning(tip),"small continuing movements cannot keep an old applicant locked indefinitely")
Cross(220,1);Leave(second);Move(220,boundaryY-8);Enter(first)
Check(tip.owner==first and tip.hoverOwner==nil and not U.Motion:IsRunning(tip),"returning to the original row clears the pending applicant")
Cross(220,1);Leave(second);Move(200,boundaryY+400);U.Motion:Tick(.25)
Check(tip.owner==nil,"leaving both rows and the popup closes details")
Cross(220,1);second.tooltipArea:Hide();U.Motion:Tick(.21)
Check(tip.owner==nil and tip.hoverOwner==nil,"a hidden pending row cannot reopen details")
second.tooltipArea:Show()
Cross(220,1);P.batchScroll.mouseOver=false;U.Motion:Tick(.21)
Check(tip.owner==nil,"a pending row outside its scroll clip cannot open details")
P.batchScroll.mouseOver=true
Cross(220,1);first.tooltipArea:Hide()
Check(tip.owner==nil and not U.Motion:IsRunning(tip),"hiding the source releases the popup and transit task")
first.tooltipArea:Show()
Cross(220,1);tip:Hide();U.Motion:Tick(.25)
Check(tip.owner==nil and tip.hoverOwner==nil,"explicit close cannot resurrect a pending row")
Reset();Move(220,boundaryY-8);Enter(first)
Move(228,boundaryY+6);first.mouseOver=false;first.tooltipArea.mouseOver=false
Enter(second);first.tooltipArea:Fire("OnLeave")
Check(tip.owner==first,"the new row entering before the previous leave callback still preserves the current player")
Reset()
U:Hide(true)

-- Exercise the real invitation/rejection controls with ordinary motion first.
-- The initial pointer entry must work without a second style application.
local feedbackFailures={}
local function FeedbackCheck(value,message)
 checks=checks+1
 if not value then feedbackFailures[#feedbackFailures+1]=message end
end
for _,reduced in ipairs({false,true}) do
 local fixture=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=reduced,floating=false})
 local addon,ui,group=fixture.A,fixture.U,fixture.G
 group.listing={activityID=2,name="Applicant action feedback"}
 group.applicants[1]={id=1,status="applied",displayOrderID=1,members={{name="ActionApplicant-Home",class="MAGE",assignedRole="DAMAGER"}}}
 addon:Open("create");ui.Motion:Tick(2)
 local batch=ui.pages.create.batchPool[1]
 local mode=reduced and "reduced motion" or "normal motion"
 for _,entry in ipairs({{key="invite",color="good"},{key="decline",color="accent"}}) do
  local button=batch[entry.key]
  local prefix=mode.." "..entry.key
  local function Settle() ui.Motion:Tick(.25) end
  local function Surface(alpha,shown,phase)
   local actual=button.hover:GetAlpha()
   FeedbackCheck(math.abs(actual-alpha)<.000001,prefix.." "..phase.." alpha: expected "..alpha..", got "..actual)
   FeedbackCheck(button.hover:IsShown()==shown,prefix.." "..phase.." visibility")
   if shown then
    local color=ui.Theme[entry.color]
    for channel=1,3 do
     FeedbackCheck(math.abs(button.hover.color[channel]-color[channel])<.000001,prefix.." "..phase.." color channel "..channel)
    end
   end
  end
  FeedbackCheck(button:IsVisible() and button:IsEnabled(),prefix.." is an actionable real applicant button")
  button.mouseOver=true;button:Fire("OnEnter");Settle()
  Surface(ui.Theme.createActionHoverAlpha,true,"first hover")
  button:Fire("OnMouseDown","LeftButton");Settle()
  Surface(ui.Theme.createActionPressedAlpha,true,"press")
  button:Fire("OnMouseUp","LeftButton");Settle()
  Surface(ui.Theme.createActionHoverAlpha,true,"release")
  button.mouseOver=false;button:Fire("OnLeave");Settle()
  Surface(0,false,"leave")
  button.mouseOver=true;button:Fire("OnEnter");Settle()
  Surface(ui.Theme.createActionHoverAlpha,true,"second hover")
  button.mouseOver=false;button:Hide();Settle()
  Surface(0,false,"hide")
  group:Notify("applicants");Settle()
  FeedbackCheck(batch[entry.key]==button and button:IsVisible(),prefix.." reuses the same applicant action button")
  Surface(0,false,"rebound idle")
  button.mouseOver=true;button:Fire("OnEnter");Settle()
  Surface(ui.Theme.createActionHoverAlpha,true,"hover after reuse")
  button.mouseOver=false;button:Fire("OnLeave");Settle()
  Surface(0,false,"leave after reuse")
 end
 FeedbackCheck(group.invitedApplicant==nil and group.declinedApplicant==nil,mode.." feedback does not invoke Invite or Decline")
 ui:Hide(true)
 FeedbackCheck(ui.Motion:Count()==0,mode.." close clears feedback animation jobs")
end
Check(#feedbackFailures==0,table.concat(feedbackFailures,"\n"))
print("Applicant hover checks passed: "..checks)
