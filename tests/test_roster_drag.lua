-- Real Tooltip/Members controllers with a native raid-action substitute.
local checks=0
local function Check(value,message) checks=checks+1;if T then T.ok(value,message) else assert(value,message) end end
local function Session(locale,withFourthGroup)
 local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true})
 local s={f=f,calls={},raid=true,leader=true,assistant=false,playerCombat=false,locked=false}
 s.rows={
  {guid="A",name="Alpha-Away",nameKey="Alpha-Away",unit="raid1",subgroup=1,class="WARRIOR",assignedRole="DAMAGER",itemLevel=650},
  {guid="B",name="Beta-Away",nameKey="Beta-Away",unit="raid2",subgroup=2,class="MAGE",assignedRole="DAMAGER"},
 }
 if withFourthGroup then s.rows[3]={guid="C",name="Gamma-Away",nameKey="Gamma-Away",unit="raid3",subgroup=4,class="PRIEST",assignedRole="HEALER",itemLevel=651} end
 IsInRaid=function() return s.raid end
 UnitIsGroupLeader=function() return s.leader end;UnitIsGroupAssistant=function() return s.assistant end
 InCombatLockdown=function() return s.locked end
 UnitGUID=function(unit)
  if unit=="player" then return "P" end
  local row=s.rows[tonumber(unit:match("%d+$"))];return row and row.guid
 end
 UnitIsUnit=function(unit,other) return unit==other end
 UnitIsHumanPlayer=function() return true end;UnitIsConnected=function() return true end
 UnitCanCooperate=function() return true end;HasLFGRestrictions=function() return false end
 UnitCanAttack=function() return false end;UnitIsDeadOrGhost=function() return false end;CanInspect=function() return true end
 UnitAffectingCombat=function(unit)
  if unit=="player" then return s.playerCombat end
  local row=s.rows[tonumber(unit:match("%d+$"))];return row and row.combat==true or false
 end
 GetNumGroupMembers=function() return #s.rows end
 GetRaidRosterInfo=function(index) local row=s.rows[index];return row.name,0,row.subgroup end
 SetRaidSubgroup=function(index,group) s.calls[#s.calls+1]={"set",index,group} end
 SwapRaidSubgroup=function(a,b) s.calls[#s.calls+1]={"swap",a,b} end
 f.G.GetRoster=function() return s.rows end
 dofile("addon/LycheeGroup_Group/RaidGroups.lua")
 local resolve=f.G.RaidGroups.ResolveDrop;s.intentReads=0
 f.G.RaidGroups.ResolveDrop=function(self,...) s.intentReads=s.intentReads+1;return resolve(self,...) end
 f.G.listing={activityID=1,name="Raid"}
 f.A:Open("create");s.tip=f.U.Tooltip
 function s:Show()
  self.tip:Hide();self.tip:ShowRoster(f.U.frame,self.rows,false,{rosterMode="groups"});self.tip.interactive.scroll.mouseOver=true
  for _,button in ipairs(self.tip.interactive.memberButtons) do button.mouseOver=nil end
  for _,drop in pairs(self.tip.interactive.rosterDrops) do drop.mouseOver=nil end
  if self.tip.emptyRosterPanel then for _,button in pairs(self.tip.emptyRosterPanel.buttons) do button.mouseOver=nil end end
 end
 function s:Button(guid)
  for _,button in ipairs(self.tip.interactive.memberButtons) do if button:IsVisible() and button.member and button.member.guid==guid then return button end end
  error("member not found")
 end
 function s:Start(guid)
  local button=self:Button(guid or "A");button:Fire("OnMouseDown","LeftButton");button:Fire("OnDragStart");return button
 end
 s:Show();return s
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local s=Session(locale);local tip,u=s.tip,s.f.U
 local known=s:Button("A");local unknown=s:Button("B")
 Check(known.realm:GetText():find(locale=="zhCN" and "装等 650" or "iLvl 650",1,true),"roster Tooltip shows known item level")
 Check(unknown.realm:GetText():find(locale=="zhCN" and "装等 —" or "iLvl —",1,true),"unknown item level stays unknown")
 s.rows[1].itemLevel=0;tip:RefreshRoster(u.frame,s.rows,{rosterMode="groups"})
 Check(s:Button("A").realm:GetText():find(locale=="zhCN" and "装等 —" or "iLvl —",1,true),"zero item level does not become a fabricated known value")
 s.rows[1].itemLevel=650;tip:RefreshRoster(u.frame,s.rows,{rosterMode="groups"})
 local source=s:Start();Check(tip.rosterDrag and tip.rosterDrag.guid=="A","valid native raid member starts a drag")
 for group=1,8 do
  local drop=tip.interactive.rosterDrops[group] or tip.emptyRosterPanel.buttons[group]
  Check(drop:IsVisible(),"drag exposes occupied backgrounds and separate empty subgroup destinations")
 end
 Check(source:IsVisible() and source.member.guid=="A" and s:Button("A")==source,"expansion retains the visible member and original drag-stop owner")
 local hidden=0;source:HookScript("OnHide",function() hidden=hidden+1 end)
 s.rows={s.rows[2],s.rows[1]};tip:RefreshRoster(u.frame,s.rows,{rosterMode="groups"})
 Check(hidden==0 and source:IsVisible() and source.member.guid=="A" and s:Button("A")==source,"native roster reordering retains the visible source and its identity")
 tip.interactive.rosterDrops[2].mouseOver=true;u.Motion:Tick(.01)
 Check(tip.rosterDrag.intent and tip.rosterDrag.intent.mode=="join" and tip.rosterDragGhost.status:GetText():find(locale=="zhCN" and "加入小队 2" or "Join group 2",1,true),"occupied group backgrounds preview a join before release")
 tip.interactive.rosterDrops[2].mouseOver=nil;tip.emptyRosterPanel.buttons[8].mouseOver=true;u.Motion:Tick(.01)
 Check(tip.rosterDrag.intent and tip.rosterDrag.intent.mode=="empty" and tip.rosterDragGhost.status:GetText():find(locale=="zhCN" and "移至小队 8" or "Move to group 8",1,true),"empty subgroup targets preview the destination before release")
 local reads=s.intentReads;for _=1,20 do u.Motion:Tick(.01) end
 Check(s.intentReads==reads,"cursor animation on one target performs no repeated raid scans")
 source:Fire("OnDragStop")
 Check(#s.calls==1 and s.calls[1][1]=="set" and s.calls[1][2]==2 and s.calls[1][3]==8,"empty-group drop resolves the current native raid index")
 Check(s.rows[2].subgroup==1,"subgroup display waits for the native roster event")
 source:Fire("OnClick","LeftButton");Check(tip.member==nil,"drag release does not also open member details")
 Check(not tip.rosterDrag and tip.interactive.events.PLAYER_REGEN_DISABLED==nil and tip.interactive.events.UNIT_FLAGS==nil,"drop releases all temporary drag events")
 for _,drop in pairs(tip.interactive.rosterDrops) do drop.mouseOver=nil;Check(not drop:IsShown(),"drop hides temporary occupied-group backgrounds") end
 Check(not tip.emptyRosterPanel:IsShown() and not tip.rosterDragGhost:IsShown() and not u.Motion:IsRunning(tip.rosterDragGhost),"release hides external targets and removes the cursor driver")
 s:Show();source=s:Start();s:Button("B").mouseOver=true;s.rows[1].combat=true;u.Motion:Tick(.01)
 Check(tip.rosterDrag.invalidReason=="targetCombat" and #s.calls==1,"a combat target is visibly rejected before release without sending an action")
 s.rows[1].combat=false;tip:CheckRosterDrag("raid1")
 Check(tip.rosterDrag.intent and tip.rosterDrag.intent.mode=="swap" and tip.rosterDragGhost.status:GetText():find(locale=="zhCN" and "交换" or "Swap with",1,true),"member targets preview a swap before release")
 source:Fire("OnDragStop")
 Check(#s.calls==2 and s.calls[2][1]=="swap","member drop swaps rather than moving into the group's background")
 s:Button("B").mouseOver=nil
 for _,invalid in ipairs({false,"",{}}) do
  s:Show();source=s:Start();local target=s:Button("B");local member=target.member
  local oldSecret=issecretvalue
  if type(invalid)=="table" then issecretvalue=function(value) return rawequal(value,invalid) or oldSecret and oldSecret(value) or false end end
  if invalid==false then member.guid=nil else member.guid=invalid end;target.mouseOver=true
  local before=#s.calls;source:Fire("OnDragStop")
  Check(#s.calls==before,"a member drop with unknown, empty or secret GUID never falls back to a background move")
  target.mouseOver=nil;member.guid="B";issecretvalue=oldSecret
 end
 s:Show();s:Start();s:Button("B"):Fire("OnClick","RightButton")
 Check(not tip.rosterDrag and tip.interactive:GetWidth()==660 and not tip.emptyRosterPanel:IsShown(),"right click ends dragging without changing the compact occupied groups")
 u:CloseMenu();tip.pinned=false
 s:Show();s:Start();s.leader=false;tip:RefreshRoster(u.frame,s.rows,{rosterMode="groups"})
 Check(not tip.rosterDrag and tip.interactive.events.UNIT_FLAGS==nil and tip.interactive.rosterNotice:IsShown(),"permission loss cancels drag events and explains the block")
 tip.interactive.rosterNotice.close:Fire("OnClick","LeftButton")
 Check(tip.rosterNoticeTimer==nil and not tip.interactive.rosterNotice:IsShown(),"closing the toast removes its only timer")
 s.leader=true
 s:Show();s.playerCombat=true;source=s:Start()
 Check(not tip.rosterDrag and #s.calls==2,"combat blocks the native action before dragging")
 local notice=tip.interactive.rosterNotice
 Check(notice:IsShown() and notice.text:GetText():find(locale=="zhCN" and "你正在战斗中" or "you are in combat",1,true),"a specific combat toast is displayed")
 local noticePoint={notice:GetPoint()};local memberPoint={s:Button("A"):GetPoint()};local noticeY,memberY=noticePoint[#noticePoint],memberPoint[#memberPoint]
 Check(noticeY<0 and memberY<noticeY-notice:GetHeight(),"toast sits below the title and above member content")
 for _,scale in ipairs({70,100,130}) do
  s.f.A:SetSetting("fontScale",scale);s:Show();s:Start();notice=tip.interactive.rosterNotice
  Check(notice.text:GetUnboundedStringWidth()<=notice.text:GetWidth()+.01 or notice.text:GetHeight()>notice.text:GetLineHeight(),"combat notice wraps at supported font sizes")
  local button=s:Button("A");Check(button.realm:GetWidth()>0 and button:GetHeight()>=button.realm:GetStringHeight(),"item-level text retains a usable row at each font size")
 end
 s.f.base.AdvanceClock(4.1);Check(not notice:IsShown() and tip.rosterNoticeTimer==nil,"toast stops after one short timer")
 s.playerCombat=false;s:Show();source=s:Start();s.playerCombat=true
 tip.interactive:Fire("OnEvent","PLAYER_REGEN_DISABLED")
 Check(not tip.rosterDrag and tip.interactive.rosterNotice:IsShown(),"combat starting mid-drag cancels and explains the block")
 tip:Hide();Check(tip.rosterNoticeTimer==nil and not tip.interactive.rosterNotice:IsShown(),"closing the Tooltip clears drag and toast lifecycle")
 s.playerCombat=false;s:Show();source=s:Start();table.remove(s.rows,2);tip:RefreshRoster(u.frame,s.rows,{rosterMode="groups"})
 Check(not tip.rosterDrag and tip.rosterNoticeTimer==nil,"loss of the source identity cleans up without a stale timer")
 s:Show();u.preview={provider=s.f.G};local before=#s.calls;source=s:Button("B");source:Fire("OnDragStart");source:Fire("OnDragStop")
 Check(#s.calls==before and not tip.rosterDrag,"preview never sends a real raid operation")
 u.preview=nil;s:Show();s:Start("B");u:Navigate("find")
 Check(not tip.rosterDrag and not tip.sourceRoster and tip.rosterNoticeTimer==nil and tip.interactive.events.UNIT_FLAGS==nil,"leaving the page clears drag identity, events and toast work")
 tip:Hide();u:Hide(true)
end
local function Geometry(frame)
 return {width=frame:GetWidth(),height=frame:GetHeight(),scale=frame:GetScale(),parent=frame:GetParent(),point={frame:GetPoint()}}
end
local function Unchanged(frame,saved,message)
 Check(frame:GetWidth()==saved.width and frame:GetHeight()==saved.height and frame:GetScale()==saved.scale and frame:GetParent()==saved.parent,message)
 local point={frame:GetPoint()};Check(#point==#saved.point,message.." anchor count")
 for i,value in ipairs(saved.point) do Check(point[i]==value,message.." anchor "..i) end
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local s=Session(locale,true);local tip,u=s.tip,s.f.U
 UIParent:SetScale(.9);u.frame:SetScale(1.4);s.f.A:SetSetting("reduceMotion",false);s:Show()
 local source=s:Button("C")
 source.GetLeft=function() return 100 end;source.GetTop=function() return 500 end
 local scale=source:GetEffectiveScale();s.f.S.cursorX=(100+31)*scale;s.f.S.cursorY=(500-17)*scale
 -- A short viewport clips the real list, but must never clip the picked-up card.
 tip.interactive.scroll:SetHeight(source:GetHeight()/2)
 local saved,scrollSaved=Geometry(tip.interactive),Geometry(tip.interactive.scroll)
 local cards={};for _,button in ipairs(tip.interactive.memberButtons) do if button:IsVisible() and button.member then cards[button]=Geometry(button) end end
 s:Start("C")
 Unchanged(tip.interactive,saved,"groups 1/2/4 do not resize or reposition the original Tooltip on pickup")
 Unchanged(tip.interactive.scroll,scrollSaved,"pickup does not change the original viewport")
 for button,geometry in pairs(cards) do Unchanged(button,geometry,"pickup keeps every original member card in place") end
 Check(tip.interactive.rosterGroupTitles[4]:IsShown() and not tip.interactive.rosterGroupTitles[3],"group 4 stays in its original position instead of inserting empty group 3")
 local ghost=tip.rosterDragGhost
 Check(ghost:IsVisible() and ghost:GetParent()==UIParent and not ghost:IsMouseEnabled() and not ghost.card:IsMouseEnabled(),"the full ghost is outside scroll clipping and cannot steal mouse targets")
 Check(ghost.card:GetWidth()==source:GetWidth() and ghost.card:GetHeight()==source:GetHeight(),"the pickup keeps the entire source card including item level")
 u.Motion:Tick(.06)
 Check(ghost:GetEffectiveScale()>scale and ghost:GetEffectiveScale()<scale*1.0351,"pickup smoothly lifts the card toward its small final scale")
 s.f.S.cursorX=s.f.S.cursorX+47;s.f.S.cursorY=s.f.S.cursorY-25;u.Motion:Tick(.06)
 local _,relative,relativePoint,x,y=ghost:GetPoint();local ghostScale=ghost:GetEffectiveScale()
 Check(relative==UIParent and relativePoint=="BOTTOMLEFT" and math.abs(x*ghostScale+31*ghostScale-s.f.S.cursorX)<.00001 and math.abs(y*ghostScale-17*ghostScale-s.f.S.cursorY)<.00001,"native cursor pixels preserve the grabbed point across UI scale and pickup animation")
 Check(math.abs(ghostScale/scale-1.035)<.000001,"normal pickup reaches 1.035 after 0.12 seconds")
 local panel=tip.emptyRosterPanel;local _,_,_,px,py=panel:GetPoint();local ps=panel:GetEffectiveScale()
 Check(px*ps>=0 and py*ps<=UIParent:GetHeight()*UIParent:GetEffectiveScale()+.01 and py*ps-panel:GetHeight()*ps>=0,"the separate empty-group panel stays inside the screen")
 tip.interactive.scroll.mouseOver=false;panel.buttons[3].mouseOver=true;u.Motion:Tick(.01)
 Check(tip.rosterDrag.intent and tip.rosterDrag.intent.mode=="empty" and tip.rosterDropHighlight:IsShown(),"independent empty groups accept and highlight drops outside the original scroll viewport")
 local nativeNodes=#s.f.S.nodes;source:Fire("OnDragStop")
 Check(#s.calls==1 and s.calls[1][3]==3 and s.rows[3].subgroup==4,"the ghost never changes the real raid snapshot optimistically")
 Check(not ghost:IsShown() and not panel:IsShown() and not tip.rosterDropHighlight:IsShown() and not u.Motion:IsRunning(ghost) and ghost.card.member==nil,"release clears the ghost, highlight, target panel, member binding and cursor driver")
 s.f.A:SetSetting("reduceMotion",true);s:Show();source=s:Start("C");u.Motion:Tick(.2)
 Check(tip.rosterDragGhost==ghost and #s.f.S.nodes==nativeNodes,"later drags reuse the single ghost and bounded target objects")
 Check(math.abs(ghost:GetEffectiveScale()/source:GetEffectiveScale()-1)<.000001 and u.Motion:IsRunning(ghost),"reduced motion skips pickup easing while retaining cursor following")
 s.f.A:SetSetting("reduceMotion",false)
 Check(not tip.rosterDrag and not u.Motion:IsRunning(ghost) and not ghost:IsShown() and not panel:IsShown(),"changing reduced motion through preferences cancels the complete drag lifecycle")
 Check(not tip.interactive.events.UNIT_FLAGS and not tip.interactive.events.PLAYER_REGEN_DISABLED and source:GetAlpha()==1 and #s.calls==1,"motion preferences restore the source and release temporary events without submitting a raid action")
 source=s:Start("C");u.Motion:Tick(.05);s.f.A:SetSetting("reduceMotion",true)
 Check(not tip.rosterDrag and not ghost:IsShown() and not panel:IsShown() and not u.Motion:IsRunning(ghost),"enabling reduced motion during animated pickup also cancels all drag state")
 source=s:Start("C");u.Motion:Tick(.2);Check(s.f.A:SetSetting("uiScale",75),"the scale regression uses a valid live preference")
 Check(not tip.rosterDrag and not ghost:IsShown() and not panel:IsShown() and not u.Motion:IsRunning(ghost),"actual window scale changes cancel the independent drag visuals")
 Check(not tip.interactive.events.UNIT_FLAGS and not tip.interactive.events.PLAYER_REGEN_DISABLED and source:GetAlpha()==1 and #s.calls==1,"scale changes release drag events and restore the source without a raid action")
 s:Start("C");tip:Hide();Check(not u.Motion:IsRunning(ghost) and not ghost:IsShown() and not panel:IsShown(),"Tooltip closure releases every drag visual driver")
 UIParent:SetScale(1);u:Hide(true)
end
-- Native-shaped geometry hit testing: derive every target rectangle from the
-- controller's actual anchors and sizes, rather than setting mouseOver flags.
local function GeometryTargets(s)
 local tip=s.tip;local canvas=tip.interactive.canvas;local left,top=100,900
 local function Bounds(region)
  if region==tip.interactive.scroll then return left,top,region:GetWidth(),region:GetHeight() end
  local point,relative,x,y=region:GetPoint()
  assert(point=="TOPLEFT" and type(relative)=="number","roster target uses its actual canvas anchor")
  return left+relative,top+(x or 0),region:GetWidth(),region:GetHeight()
 end
 local function Bind(region)
  region.IsMouseOver=function(self)
   local x,y=GetCursorPosition();local scale=self:GetEffectiveScale();x,y=x/scale,y/scale
   local l,t,w,h=Bounds(self);return self:IsVisible() and x>=l and x<=l+w and y<=t and y>=t-h
  end
 end
 Bind(tip.interactive.scroll)
 for _,button in ipairs(tip.interactive.memberButtons) do Bind(button) end
 for _,drop in pairs(tip.interactive.rosterDrops) do Bind(drop) end
 return function(region,offsetY)
  local l,t,w,h=Bounds(region);local scale=region:GetEffectiveScale()
  s.f.S.cursorX=(l+w/2)*scale;s.f.S.cursorY=(t-(offsetY or h/2))*scale
 end
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,fontScale in ipairs({70,100,130}) do
 local s=Session(locale);local tip,u=s.tip,s.f.U;s.f.A:SetSetting("fontScale",fontScale);s.rows={}
 for group=4,6 do for i=1,(group==6 and 1 or 5) do
  local guid=group==4 and i==1 and "A" or "G"..group.."M"..i
  s.rows[#s.rows+1]={guid=guid,name=guid.."-Away",nameKey=guid.."-Away",subgroup=group,class="MAGE",assignedRole="DAMAGER"}
 end end
 s:Show();local saved=Geometry(tip.interactive);local cards={}
 local bounds=tip.rosterGroupBounds[4];local title=tip.interactive.rosterGroupTitles[4];local _,titleX,titleY=title:GetPoint()
 local _,_,firstY=s:Button("A"):GetPoint();local lastCard=s:Button("G4M5");local _,_,lastCardY=lastCard:GetPoint()
 Check(math.abs(titleX-bounds.x-12)<.001 and math.abs(-titleY-bounds.top-12)<.001,"group headings have 12 pixels of left and top breathing room")
 Check(-firstY-(-titleY+title:GetLineHeight())==12 and bounds.top+bounds.height-(-lastCardY+lastCard:GetHeight())==12,"heading-to-member and group bottom padding are both 12 pixels")
 Check(tip.rosterGroupBounds[5].x-(bounds.x+bounds.width)==12,"occupied groups have 12 pixel column gaps outside their drop backgrounds")
 local noOverlap=true
 for group=4,5 do for i=1,4 do
  local a=s:Button(group==4 and i==1 and "A" or "G"..group.."M"..i);local b=s:Button("G"..group.."M"..(i+1))
  local _,_,ay=a:GetPoint();local _,_,by=b:GetPoint();if -by<-ay+a:GetHeight()+2 then noOverlap=false end
 end end
 Check(noOverlap and title:GetUnboundedStringWidth()<=title:GetWidth(),"bilingual group headings and member cards fit without overlap at every supported font scale")
 for _,button in ipairs(tip.interactive.memberButtons) do if button:IsVisible() and button.member then cards[button]=Geometry(button) end end
 local source=s:Start("A");local pointAt=GeometryTargets(s)
 Check(tip.rosterDragGhost.inner==nil and tip.rosterDragGhost.surface.color==u.Theme.raised and #tip.rosterDragGhost._lycheeVisuals==2,"the ghost uses one Tooltip raised surface with a soft shadow and no outline layer")
 local short=tip.interactive.rosterDrops[6];local tall=tip.interactive.rosterDrops[4]
 local scale=tall:GetEffectiveScale();s.f.S.cursorX=(100+bounds.x+bounds.width+6)*scale;s.f.S.cursorY=(900-bounds.top-20)*scale;u.Motion:Tick(.01)
 Check(not tip.rosterDrag.intent and (not tip.rosterDropHighlight or not tip.rosterDropHighlight:IsShown()),"column gaps do not belong to subgroup drop backgrounds")
 local last=s:Button("G4M5");local _,_,lastY=last:GetPoint()
 local belowShort=-lastY-tip.rosterGroupBounds[6].top+last:GetHeight()/2
 pointAt(short,belowShort);u.Motion:Tick(.01)
 Check(tip.rosterDrag.intent and tip.rosterDrag.intent.mode=="join" and tip.rosterDrag.intent.subgroup==6,"5/5/1: the short group's visible empty slots preview joining group 6")
 Check(short:GetHeight()==tall:GetHeight(),"occupied subgroup backgrounds share the actual height of their visual row")
 Unchanged(tip.interactive,saved,"extending only drop backgrounds does not change Tooltip geometry")
 for button,geometry in pairs(cards) do Unchanged(button,geometry,"long and short subgroup cards keep their original geometry") end
 source:Fire("OnDragStop")
 Check(#s.calls==1 and s.calls[1][1]=="set" and s.calls[1][2]==1 and s.calls[1][3]==6,"release in a short group's empty slot submits the native move")
 s:Show();source=s:Start("A");pointAt=GeometryTargets(s);pointAt(s:Button("G4M2"));u.Motion:Tick(.01)
 Check(not tip.rosterDrag.intent and not tip.rosterDrag.invalidReason and not tip.rosterDropHighlight:IsShown(),"same-group members have no error intent or target highlight")
 Check(tip.rosterDragGhost.status:GetText()==(locale=="zhCN" and "拖至小队背景或其他成员" or "Drag to a group or another member"),"same-group pickup retains neutral instructions")
 source:Fire("OnDragStop")
 Check(#s.calls==1 and tip.rosterNoticeTimer==nil and (not tip.interactive.rosterNotice or not tip.interactive.rosterNotice:IsShown()),"same-group release is silent and never calls a native grouping API")
 s.rows[#s.rows+1]={guid="G7M1",name="Delta-Away",nameKey="Delta-Away",subgroup=7,class="MAGE",assignedRole="DAMAGER"};s:Show()
 local firstRow,secondRow=tip.rosterGroupBounds[4],tip.rosterGroupBounds[7]
 Check(secondRow.top-(firstRow.top+firstRow.height)==16 and tip.interactive.canvas:GetHeight()==secondRow.top+secondRow.height,"row gaps are 16 pixels and Tooltip scrolling follows the padded content height")
 source=s:Start("A");GeometryTargets(s);scale=tip.interactive.rosterDrops[4]:GetEffectiveScale()
 s.f.S.cursorX=(100+firstRow.x+firstRow.width/2)*scale;s.f.S.cursorY=(900-firstRow.top-firstRow.height-8)*scale;u.Motion:Tick(.01)
 Check(not tip.rosterDrag.intent and not tip.rosterDropHighlight:IsShown(),"row gaps are excluded from subgroup drop backgrounds")
 tip:Hide();u:Hide(true)
 end
end
if not T then print("Roster drag: "..checks.." checks passed") end
