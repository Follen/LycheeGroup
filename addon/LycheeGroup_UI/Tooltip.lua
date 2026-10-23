local A = _G.LycheeGroup
local UI = A.UI
local T,L,C = UI.Theme,UI.L,UI.C
local Members=UI.Members
-- A separate tooltip owned by this UI; the global GameTooltip stays untouched.
local Tip={orderedMembers={},rosterGroupCounts={}}
local function ScrollMaximum(scroll,canvas)
 local overflow=canvas:GetHeight()-scroll:GetHeight()
 -- Match List: native scaled dimensions may differ by a tiny rounding residue.
 return overflow>.01 and overflow or 0
end
local raidModifierKeys={LSHIFT="shift",RSHIFT="shift",LALT="alt",RALT="alt",LCTRL="ctrl",RCTRL="ctrl"}
local raidModifierLabels={shift="Shift",alt="Alt",ctrl="Ctrl"}
UI.Tooltip=Tip
-- Capture once so the pointer can enter the interactive tooltip. Screen edges,
-- rather than the main window, bound it so it can sit beside the result list.
local function CursorInWindow()
 local x,y=GetCursorPosition();local window=UI.frame;local scale=window:GetEffectiveScale()
 return x/scale-window:GetLeft(),window:GetTop()-y/scale
end
local function Viewport()
 local window=UI.frame;local scale=window:GetEffectiveScale()/UIParent:GetEffectiveScale()
 local top=window:GetTop()-(UIParent:GetTop()-10)/scale
 local bottom=window:GetTop()-(UIParent:GetBottom()+10)/scale
 local left=(UIParent:GetLeft()+10)/scale-window:GetLeft()
 local right=(UIParent:GetRight()-10)/scale-window:GetLeft()
 return window,scale,top,bottom,left,right
end
function Tip:CaptureOwner(owner)
 if self.owner~=owner or self.pointX==nil then
  self.pointX,self.pointY=CursorInWindow();self.positionX,self.positionY=nil,nil
 end
 self.owner=owner
end
function Tip:Position(frame)
 local window,_,topLimit,bottomLimit,leftLimit,rightLimit=Viewport()
 local width,height=frame:GetWidth(),frame:GetHeight()
 local keep=self.pinned and self.positionX~=nil
 local x=keep and self.positionX or self.pointX+20
 local y=keep and self.positionY or self.pointY+16
 if not keep then
  if x+width>rightLimit then x=self.pointX-width-20 end
  if y+height>bottomLimit then y=self.pointY-height-16 end
 end
 if keep and self.adjustPoint then
  local cursorX,cursorY=CursorInWindow()
  x=math.max(cursorX-width+24,math.min(x,cursorX-12))
  y=math.max(cursorY-height+24,math.min(y,cursorY-12))
 end
 x=math.max(leftLimit,math.min(rightLimit-width,x));y=math.max(topLimit,math.min(bottomLimit-height,y))
 self.positionX,self.positionY,self.adjustPoint=x,y,nil
 frame:ClearAllPoints();frame:SetPoint("TOPLEFT",window,"TOPLEFT",x,-y)
UI:ApplyElementScope("tooltip")
 end
function Tip:IsOwned(owner) return self.owner==owner end
function Tip:IsResult(id)
 return self.record~=nil and self.record.id==id and self.interactive~=nil and self.interactive:IsShown()
end
function Tip:ClearSource()
 self.record,self.member,self.details,self.sourceApp,self.sourceRoster=nil,nil,nil,nil,nil
 self.memberContext,self.rosterContext,self.directPlayer,self.selectedMemberID,self.applicantID,self.noteKey=nil,nil,nil,nil,nil,nil
end
local resumeFields={"owner","record","details","sourceApp","sourceRoster","selectedMemberID","applicantID","member","memberContext","rosterContext","directPlayer","pinned","pointX","pointY","positionX","positionY","expanded"}
function Tip:Capture()
 local saved={page=UI.page,scroll=self.interactive.scroll:GetVerticalScroll(),back=self.interactive.back:IsShown()}
 for _,key in ipairs(resumeFields) do saved[key]=self[key] end
 return saved
end
local function FindMember(members,id)
 -- Providers reuse member tables by slot; only the identity captured at selection is stable.
 if not id then return end
 for _,member in ipairs(members) do if Members:ID(member)==id then return member end end
end
function Tip:Restore(saved)
 local group=UI:GetGroup()
 local member=saved.member
 if saved.sourceRoster then
  saved.sourceRoster=group:GetRoster();member=FindMember(saved.sourceRoster,saved.selectedMemberID)
 elseif saved.applicantID then
  saved.sourceApp=group:GetApplicant(saved.applicantID)
  member=saved.sourceApp and FindMember(saved.sourceApp.members,saved.selectedMemberID)
 elseif saved.record then
  local application=group:GetApplication(saved.record.id)
  saved.record=group:GetResult(saved.record.id) or application and application.result
  if saved.record then saved.details=group.Results:GetDetails(saved.record);member=FindMember(saved.details.members,saved.selectedMemberID) else member=nil end
 end
 if not member and not (saved.sourceRoster and not saved.directPlayer) then return end
 for _,key in ipairs(resumeFields) do self[key]=saved[key] end
 if member then self:RenderPlayer(member,saved.back)
 else self:ShowRoster(saved.owner,saved.sourceRoster,saved.pinned,saved.rosterContext) end
 local f=self.interactive;f.scrollbar:SetValue(math.min(saved.scroll,ScrollMaximum(f.scroll,f.canvas)))
end
function Tip:RebindRosterOwner(memberID,owner)
 if self.directPlayer and memberID==self.selectedMemberID then self.owner=owner end
 local saved=UI.activeModal and UI.activeModal.restoreTooltip
 if saved and saved.directPlayer and memberID==saved.selectedMemberID then saved.owner=owner end
end
function Tip:HideRosterOwner(owner,memberID)
 if self:IsOwned(owner) and not (self.directPlayer and memberID==self.selectedMemberID) then self:Hide() end
end
function Tip:Hide()
 if self.outsideClicks then self.outsideClicks:Hide() end
 if self.text then self.text:Hide() end
 UI.Motion:Stop(self)
 wipe(self.orderedMembers)
 wipe(self.rosterGroupCounts)
 if self.interactive then
  local f=self.interactive;f:Hide();f:UnregisterEvent("MODIFIER_STATE_CHANGED")
  for _,button in ipairs(f.memberButtons) do UI:CloseMenuFor(button);button.member=nil;button.memberContext=nil;button.targetKey=nil;C.RekeyElement(button,nil) end
 end
 self.owner=nil
 self:ClearSource();self.pinned=nil
 self.pointX,self.pointY,self.positionX,self.positionY,self.expanded,self.adjustPoint=nil,nil,nil,nil,nil,nil
end

local zh=A:GetLocale()=="zhCN"
local function Say(cn,en) return zh and cn or en end
function Tip:BindText(owner,text)
 owner:HookScript("OnEnter",function(button)
  if UI.hiding or self.pinned then return end
  self:Hide();self.owner=button
  if not self.text then self.text=C.Tooltip(UI.frame,300);UI:Element(self.text,"tooltip.plain","tooltip") end
  self.text:SetOwner(button,"ANCHOR_TOP");self.text:AddLine(text)
  local line=self.text.lines[1];local width=math.min(268,math.ceil(line:GetUnboundedStringWidth())+1)
  line:SetWidth(width);self.text:SetWidth(width+32);self.text:Show()
 end)
 owner:HookScript("OnLeave",function(button) self:LeaveOwner(button) end)
 owner:HookScript("OnHide",function(button) if self:IsOwned(button) then self:Hide() end end)
end
local bosses={}
local function Bosses(activity)
 local id=activity and activity.journalID
 -- Map zero is used by world-boss entries and can resolve to an unrelated EJ instance.
 if not id or not activity.mapID or activity.mapID<=0 then return nil end
 local difficulty=activity.difficultyID
 local cacheKey=difficulty or 0
 local byDifficulty=bosses[id]
 if byDifficulty and byDifficulty[cacheKey] then return byDifficulty[cacheKey] end
 -- Retail enumerates the selected journal instance. Its selected game map is
 -- return 10 of EJ_GetInstanceInfo; there is no EJ_GetCurrentInstance API.
 local previousMap=select(10,EJ_GetInstanceInfo())
 local previousInstance=previousMap and previousMap>0 and C_EncounterJournal.GetInstanceForGameMap(previousMap)
 local previousDifficulty=EJ_GetDifficulty()
 local previousEncounter=EncounterJournal and EncounterJournal.encounterID
 EJ_SelectInstance(id)
 if difficulty and difficulty>0 and difficulty~=previousDifficulty then EJ_SetDifficulty(difficulty) end
 local list={};local i=1
 local name=EJ_GetEncounterInfoByIndex(i)
 while name do list[#list+1]=name;i=i+1;name=EJ_GetEncounterInfoByIndex(i) end
 if previousInstance then EJ_SelectInstance(previousInstance) end
 if previousDifficulty and previousDifficulty>0 and difficulty~=previousDifficulty then EJ_SetDifficulty(previousDifficulty) end
 if previousInstance and previousEncounter then EJ_SelectEncounter(previousEncounter) end
 -- An uninitialized/temporarily unavailable journal must not poison the cache.
 if #list==0 then return nil end
 if not byDifficulty then byDifficulty={};bosses[id]=byDifficulty end
 byDifficulty[cacheKey]=list
 return list
end

function UI:ProgressText(record,details)
 local list=Bosses(record.activity)
 if not list or #list==0 then return "—" end
 local count
 if details then count=details.encounters and #details.encounters
 else count=self:GetGroup().Results:GetProgressCount(record) end
 if count==nil then return "—" end
 return count.."/"..#list
end
function Tip:OpenRosterMenu(button,member)
 self.pinned=true;self.outsideClicks:Show();UI.Motion:Stop(self)
 Members:OpenMenu(button,member,function() self:Hide() end)
end
local function ApplicantContext(applicant)
 local activity=applicant and UI:GetGroup().Catalog:GetActivity(applicant.activityID)
 return A.GroupPresentation.Member("applicant",activity)
end
local function DefaultMemberContext(member)
 return member.applicantID and ApplicantContext(UI:GetGroup():GetApplicant(member.applicantID)) or A.GroupPresentation.Member("roster")
end
function UI:MemberRating(member)
 if member.ratingKind=="pvp" then return member.rating,"pvp",member.pvpRatingInfo and member.pvpRatingInfo.activityName end
 return member.dungeonScore or member.rating,"dungeon"
end
function UI:CopyText(title,value,restoreTooltip,identity,fieldLabel)
 local modal=self:OpenModal("copyText",title,560,314)
 if not modal.built then
  local f=modal.frame;f.help=C.Text(modal.content,"",14,"muted",T.tooltipFHelpWidth);f.help:SetWidth(T.tooltipFHelpWidth);f.help:SetPoint("TOPLEFT");C.SetLineHeight(f.help,22);f.help:SetWordWrap(true)
  f.fieldLabel=C.Text(modal.content,Say("角色链接","Character link"),14,"muted",T.tooltipFFieldLabelWidth);f.fieldLabel:SetWidth(T.tooltipFFieldLabelWidth);C.SetLineHeight(f.fieldLabel,20,true);C.SetPoint(f.fieldLabel,"TOPLEFT",f.fieldLabel:GetParent(),"TOPLEFT",0,"tooltipFFieldLabelTopleftY")
  f.copyHint=C.Text(modal.content,Say("文本已选中，按 Ctrl+C 复制。","The text is selected. Press Ctrl+C to copy."),14,"dim",T.tooltipFCopyHintWidth);f.copyHint:SetWidth(T.tooltipFCopyHintWidth);C.SetLineHeight(f.copyHint,20,true);C.SetPoint(f.copyHint,"TOPLEFT",f.copyHint:GetParent(),"TOPLEFT",0,"tooltipFCopyHintTopleftY")
  f.field=C.Edit(modal.content,T.tooltipFFieldWidth,T.tooltipFFieldHeight,false,false,"modal");C.Box(f.field,{width="tooltipFFieldWidth",height="tooltipFFieldHeight"});C.SetPoint(f.field,"TOPLEFT",f.field:GetParent(),"TOPLEFT",0,"tooltipFFieldTopleftY")
  f.field.box:SetScript("OnTextChanged",function(box,user) if user then box:SetText(f.value);box:HighlightText() end end)
  f.close=C.Button(modal.content,L.close,T.tooltipFCloseWidth,function() modal:Close() end);f.close:SetWidth(T.tooltipFCloseWidth);f.close:SetPoint("BOTTOMRIGHT")
  modal.onClose=function(reason)
   local saved=modal.restoreTooltip;modal.restoreTooltip=nil
   f.field.box:ClearFocus();f.value=nil;f.field.box:SetText("")
   if saved and reason==nil and UI.frame:IsShown() and not UI.hiding and UI.page==saved.page and not UI.activeModal then
    Tip:Restore(saved)
   end
  end
  f.contentLayout=C.Column(modal.content,{{frame=f.help,height="content",gapAfter=16},{frame=f.fieldLabel,height="content",gapAfter=8},{frame=f.field,gapAfter=12},{frame=f.copyHint,height="content"}},{width="content",height="content"})
  UI:ElementFields(f,"tooltip.copyText","help fieldLabel copyHint field close","tooltip");modal.built=true;self.copyDialog=f
 end
 local f=modal.frame;modal.restoreTooltip=restoreTooltip;UI:SetText(f.fieldLabel,fieldLabel or Say("角色链接","Character link"));UI:SetText(f.help,identity or Say("按 Ctrl+C 复制完整文本。","Press Ctrl+C to copy the complete text."));f.value=value;f.field.box:SetText(value);f.field.box:SetFocus();f.field.box:HighlightText()
 local _,height=f.contentLayout:Layout()
 f:SetHeight(math.max(314,104+height+16+40))
end
function Tip:BuildInteractive()
 local f=CreateFrame("Frame",nil,UIParent);f:SetFrameStrata("TOOLTIP");f:SetFrameLevel(2);f:SetClampedToScreen(true);f:EnableMouse(true);C.Shadow(f,16);C.Panel(f,"raised","tooltipPanelRadius")
 -- Observe outside clicks only while pinned; no mouse surface intercepts the game.
 local outside=CreateFrame("Frame",nil,UIParent)
 outside:SetScript("OnShow",function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
 outside:SetScript("OnHide",function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
 outside:SetScript("OnEvent",function()
  local owner=UI.context:GetMenuAnchor()
  local ownMenu=owner and owner:GetParent()==Tip.interactive.canvas and UI.context:IsMenuHovered(owner)
  if not Tip.interactive:IsMouseOver() and not ownMenu then Tip:Hide() end
 end)
 outside:Hide();self.outsideClicks=outside
 f:SetScript("OnEnter",function() UI.Motion:Stop(Tip) end)
 f:SetScript("OnLeave",function() Tip:LeaveOwner() end)
 f:SetScript("OnEvent",function(_,event,key,down)
  if event=="MODIFIER_STATE_CHANGED" and down==1 and raidModifierKeys[key]==A:GetSetting("raidMembers") and Tip.record and A.GroupPresentation.Result(Tip.record).kind=="raid" and not Tip.member then
   Tip.expanded=not Tip.expanded;Tip:RenderGroup()
  end
 end)
 local scroll=CreateFrame("ScrollFrame",nil,f);scroll:SetPoint("TOPLEFT",T.tooltipPadding,-T.tooltipPadding);scroll:SetPoint("BOTTOMRIGHT",-T.tooltipPadding-T.scrollWidth,T.tooltipPadding)
 local canvas=CreateFrame("Frame",nil,scroll);C.Box(canvas,{width="tooltipCanvasWidth",height="tooltipCanvasHeight"});scroll:SetScrollChild(canvas)
 local slider=C.ScrollBar(f);slider:SetPoint("TOPRIGHT",0,-T.tooltipPadding);slider:SetPoint("BOTTOMRIGHT",0,T.tooltipPadding);f.scrollbar=slider
 slider:SetScript("OnValueChanged",function(_,value) if not f.updatingScroll then UI.Motion:Stop(scroll);scroll.scrollTarget=nil;scroll:SetVerticalScroll(value) end end)
 scroll:EnableMouseWheel(true);scroll:SetScript("OnMouseWheel",function(self,delta)
  local maximum=ScrollMaximum(self,canvas);local target=math.max(0,math.min(maximum,(self.scrollTarget or self:GetVerticalScroll())-delta*42))
  self.scrollTarget=target;UI.Motion:Stop(self)
  local from=self:GetVerticalScroll()
  if A:GetSetting("reduceMotion") or target==from then self.scrollTarget=nil;self:SetVerticalScroll(target);f.updatingScroll=true;slider:SetValue(target);f.updatingScroll=false;return end
  local elapsed=0
  UI.Motion:Start(self,function(dt)
   elapsed=math.min(.14,elapsed+dt);local p=elapsed/.14;p=p*(2-p);local value=from+(target-from)*p
   self:SetVerticalScroll(value);f.updatingScroll=true;slider:SetValue(value);f.updatingScroll=false
   if elapsed==.14 then self.scrollTarget=nil;return true end
  end)
 end)
 f.scroll,f.canvas=scroll,canvas
 f:SetScript("OnHide",function() outside:Hide();UI.Motion:Stop(scroll);scroll.scrollTarget=nil end)
 f.icon=C.Icon(canvas,T.tooltipFIconWidth2);C.Box(f.icon,{width="tooltipFIconWidth2",height="tooltipFIconHeight2"});f.icon:SetPoint("TOPLEFT")
 f.title=C.Text(canvas,"",18,"text");C.SetPoint(f.title,"TOPLEFT",f.title:GetParent(),"TOPLEFT","tooltipFTitleTopleftX",0);f.title:SetWordWrap(true)
 f.subtitle=C.Text(canvas,"",14,"muted");C.SetPoint(f.subtitle,"TOPLEFT",f.subtitle:GetParent(),"TOPLEFT","tooltipFSubtitleTopleftX","tooltipFSubtitleTopleftY");C.SetLineHeight(f.subtitle,20)
 f.summary=C.Text(canvas,"",14,"muted");C.SetPoint(f.summary,"TOPLEFT",f.summary:GetParent(),"TOPLEFT",0,"tooltipFSummaryTopleftY");C.SetLineHeight(f.summary,20)
 f.pvpRatings=C.Text(canvas,"",14,"muted");f.pvpRatings:SetWordWrap(true);C.SetLineHeight(f.pvpRatings,20);f.pvpRatings:Hide()
 f.metrics={}
 for i=1,4 do local title=C.Text(canvas,"",14,"dim");C.SetLineHeight(title,20,true);local value=C.Text(canvas,"",14,"text");C.SetLineHeight(value,20,true);f.metrics[i]={title=title,value=value} end
 f.metricTitleItems,f.metricValueItems={},{}
 for i,metric in ipairs(f.metrics) do f.metricTitleItems[i]={frame=metric.title,hidden=true};f.metricValueItems[i]={frame=metric.value,hidden=true} end
 f.metricTitleOptions={width=1,height=1,gap=16};f.metricValueOptions={width=1,height=1,gap=16}
 f.metricTitleLayout=C.Row(canvas,f.metricTitleItems,f.metricTitleOptions);f.metricValueLayout=C.Row(canvas,f.metricValueItems,f.metricValueOptions)
 f.composition=UI:CreateRoster(canvas,22,5);C.SetPoint(f.composition,"TOPLEFT",f.composition:GetParent(),"TOPLEFT",0,"tooltipFCompositionTopleftY")
 f.raidLeader=C.Text(canvas,"",14,"muted");C.SetLineHeight(f.raidLeader,20);f.raidLeader:SetWordWrap(true);f.raidLeader:Hide()
 f.raidLeaderIcon=C.Icon(canvas,T.tooltipFRaidLeaderIconWidth);C.Box(f.raidLeaderIcon,{width="tooltipFRaidLeaderIconWidth",height="tooltipFRaidLeaderIconHeight"});UI:SetMediaTexture(f.raidLeaderIcon,"leader.tga");f.raidLeaderIcon:Hide()
 f.comment=C.Text(canvas,"",14,"text");C.SetPoint(f.comment,"TOPLEFT",f.comment:GetParent(),"TOPLEFT",0,"tooltipFCommentTopleftY");f.comment:SetWordWrap(true);C.SetLineHeight(f.comment,22)
 f.footer=C.Text(canvas,"",14,"dim");f.footer:SetWordWrap(true);C.SetLineHeight(f.footer,20)
 f.bossTitle=C.Text(canvas,Say("首领进度","Boss progress"),14,"text",T.tooltipFBossTitleWidth);f.bossTitle:SetWidth(T.tooltipFBossTitleWidth);C.SetLineHeight(f.bossTitle,20,true)
 f.bossCount=C.Text(canvas,"",14,"text",T.tooltipFBossCountWidth);f.bossCount:SetWidth(T.tooltipFBossCountWidth);f.bossCount:SetJustifyH("RIGHT");C.SetLineHeight(f.bossCount,20,true)
 f.bossText=C.Text(canvas,"",14,"muted",T.tooltipFBossTextWidth);f.bossText:SetWidth(T.tooltipFBossTextWidth);f.bossText:SetWordWrap(true);C.SetLineHeight(f.bossText,20)
 f.bossRows={}
 f.memberButtons={}
 f.relationshipRows={}
 f.rosterGroupTitles={}
 f.dungeonTitle=C.Text(canvas,Say("本赛季大秘境","This season's Mythic+"),14,"text");C.SetLineHeight(f.dungeonTitle,20,true);f.dungeonTitle:Hide()
 f.dungeonEmpty=C.Text(canvas,Say("未提供大秘境记录","No Mythic+ records provided"),14,"dim");C.SetLineHeight(f.dungeonEmpty,20);f.dungeonEmpty:SetWordWrap(true);f.dungeonEmpty:Hide()
 f.dungeonRows={}
 f.playerRole=C.Icon(canvas,T.tooltipIdentityMarkSize);C.Box(f.playerRole,{width="tooltipIdentityMarkSize",height="tooltipIdentityMarkSize"});f.playerRole:Hide()
 f.playerFaction=C.Icon(canvas,T.tooltipIdentityMarkSize);C.Box(f.playerFaction,{width="tooltipIdentityMarkSize",height="tooltipIdentityMarkSize"});f.playerFaction:Hide()
 f.noteHeading=C.Text(canvas,"",14,"muted");C.SetLineHeight(f.noteHeading,20,true);f.noteHeading:Hide()
 f.noteGlyph=C.Glyph(canvas,"book",T.tooltipFNoteGlyphWidth);C.Box(f.noteGlyph,{width="tooltipFNoteGlyphWidth",height="tooltipFNoteGlyphHeight"});f.noteGlyph:Hide()
 f.noteDate=C.Text(canvas,"",14,"dim");C.SetLineHeight(f.noteDate,20);f.noteDate:Hide()
 f.noteDivider=C.Fill(canvas,"border","ARTWORK");f.noteDivider:SetHeight(1);f.noteDivider:Hide()
 f.back=C.Button(canvas,Say("返回队伍","Back to group"),T.tooltipFBackWidth,function()
  Tip.member=nil;Tip.memberContext=nil;Tip.adjustPoint=true
  if Tip.record then Tip:RenderGroup()
  elseif Tip.sourceApp then Tip:ShowApplicants(Tip.owner,Tip.sourceApp,true)
  elseif Tip.sourceRoster then Tip:ShowRoster(Tip.owner,Tip.sourceRoster,true,Tip.rosterContext) end
 end);f.back:SetWidth(T.tooltipFBackWidth)
 f.back:SetHeight(T.tooltipFBackHeight);C.SetFont(f.back.label,14);C.SetLineHeight(f.back.label,20,true);f.back.label:ClearAllPoints();C.SetPoint(f.back.label,"LEFT",f.back.label:GetParent(),"LEFT","tooltipFBackLabelLeftX",0);UI:Color(f.back.label,"muted");f.back.elementIcon=C.Glyph(f.back,"arrow",T.tooltipGlyphWidth);f.back.elementIcon:SetPoint("LEFT",0,0)
 f.wcl=C.Button(canvas,Say("复制 WCL 链接","Copy WCL link"),T.tooltipFWclWidth,function()
  local _,name,realm=Members:Identity(Tip.member)
  if UI.preview or not name or not realm or realm=="" then return end
  local function Encode(value) return value:gsub("([^%w%-_%.~])",function(ch) return ("%%%02X"):format(ch:byte()) end) end
  local regions={[1]="us",[2]="kr",[3]="eu",[4]="tw",[5]="cn"};local region=regions[GetCurrentRegion()] or "us"
  local restore=(Tip.pinned or Tip.directPlayer) and Tip:Capture() or nil
  UI:CopyText(Say("复制 WCL 链接","Copy WCL link"),"https://"..(region=="cn" and "cn." or "www.").."warcraftlogs.com/character/"..region.."/"..Encode(realm).."/"..Encode(name),restore,name.."-"..realm)
 end);f.wcl:SetWidth(T.tooltipFWclWidth)
 f.wcl:SetSurfaceColors("secondaryContainer","refreshHover","surfaceHighest")
 f.note=C.Button(canvas,L.record,T.tooltipFNoteWidth,function()
  local key,name,realm=Members:Identity(Tip.member)
  if UI.preview then return end
  if name then A:Open("notes",UI:HasNote(key) and {playerKey=key} or {add={name=name,realm=realm,class=Tip.member.class,specID=Tip.member.specID}}) end
 end);f.note:SetWidth(T.tooltipFNoteWidth)
 f.note:SetSurfaceColors("secondaryContainer","refreshHover","surfaceHighest")
 f.actionItems={{frame=f.wcl,width="fill",height="tooltipFWclHeight"},{frame=f.note,width="fill",height="tooltipFNoteHeight"}}
 f.actionOptions={width=1,height=40,gap=16};f.actionLayout=C.Row(canvas,f.actionItems,f.actionOptions)
 self.interactive=f;f:Hide()
self:RegisterBuildInteractiveElements()
 end
function Tip:EnsureMemberButtons(count)
 local f=self.interactive
 for i=#f.memberButtons+1,count do
  local b=Members:Create(f.canvas,function(self,key)
   if not self.member then return end
   if key=="RightButton" then if Tip.sourceRoster then Tip:OpenRosterMenu(self,self.member) end
   else Tip.memberContext=self.memberContext;Tip:RenderPlayer(self.member,true,true) end
  end)
  UI:Element(b,"tooltip.member","tooltip",b,"tooltip.member");f.memberButtons[i]=b
 end
end
function Tip:ResetInteractive(owner,width,metricAlignment)
 if self.text then self.text:Hide() end
 metricAlignment=metricAlignment or "LEFT"
 local metricVertical=metricAlignment=="CENTER" and "TOP" or "MIDDLE"
 UI.Motion:Stop(self)
 wipe(self.orderedMembers)
 if not self.interactive then self:BuildInteractive() end
 local f=self.interactive;width=C.ElementValue(f,"root","width",width);if owner then self:CaptureOwner(owner) end
 f:UnregisterEvent("MODIFIER_STATE_CHANGED")
 f.icon:ClearAllPoints();f.icon:SetPoint("TOPLEFT")
 f.icon:SetSize(T.tooltipFIconWidth,T.tooltipFIconHeight)
 f.title:ClearAllPoints();C.SetPoint(f.title,"TOPLEFT",f.title:GetParent(),"TOPLEFT","tooltipFTitleTopleftX2",0);UI:Color(f.title,"text")
 C.SetFont(f.title,18);C.SetLineHeight(f.title,24);f.title:SetHeight(0)
 f.subtitle:ClearAllPoints();C.SetPoint(f.subtitle,"TOPLEFT",f.subtitle:GetParent(),"TOPLEFT","tooltipFSubtitleTopleftX","tooltipFSubtitleTopleftY");f.subtitle:SetHeight(0)
 f.summary:ClearAllPoints();C.SetPoint(f.summary,"TOPLEFT",f.summary:GetParent(),"TOPLEFT",0,"tooltipFSummaryTopleftY")
 f.comment:ClearAllPoints();C.SetPoint(f.comment,"TOPLEFT",f.comment:GetParent(),"TOPLEFT",0,"tooltipFCommentTopleftY")
 for _,b in ipairs(f.memberButtons) do b:Hide();b.member=nil;b.memberContext=nil;b.targetKey=nil end
 for _,title in pairs(f.rosterGroupTitles) do title:Hide() end
 for _,row in pairs(f.relationshipRows) do row:Hide() end
 -- Measure reused text in its final alignment; temporary alignment changes can leave stale glyph positions.
 for i,metric in ipairs(f.metrics) do
  local alignment=i==1 and "LEFT" or metricAlignment
  metric.title:Hide();metric.value:Hide();metric.title:SetWordWrap(false)
  metric.title:SetJustifyH(alignment);metric.value:SetJustifyH(alignment)
  metric.title:SetJustifyV(metricVertical);metric.value:SetJustifyV(metricVertical)
  C.SetLineHeight(metric.title,20);C.SetLineHeight(metric.value,20)
  local height=UI.context:GetLineHeight("label")
  metric.title:SetHeight(height);metric.value:SetHeight(height)
 end
 for i=1,#f.metrics do f.metricTitleItems[i].hidden=true;f.metricValueItems[i].hidden=true end
 f.metricTitleLayout:Layout();f.metricValueLayout:Layout()
 f.back:Hide();f.note:Hide();f.wcl:Hide();f.playerRole:Hide();f.noteHeading:Hide();f.noteGlyph:Hide();f.noteDate:Hide();f.noteDivider:Hide();f.bossTitle:Hide();f.bossCount:Hide();f.bossText:Hide();f.composition:Hide();f.pvpRatings:Hide()
 f.raidLeader:Hide();f.raidLeaderIcon:Hide()
 for _,row in ipairs(f.bossRows) do row:Hide() end
 f.actionLayout:Layout()
 f.dungeonTitle:Hide();f.dungeonEmpty:Hide();f.playerFaction:Hide()
 for _,row in ipairs(f.dungeonRows) do row:Hide() end
 f.icon:Show();f.title:Show();f.subtitle:Show();f.summary:Show();f.comment:Show()
 f:SetWidth(width);f.canvas:SetWidth(width-2*T.tooltipPadding-T.scrollWidth);f.title:SetWidth(width-2*T.tooltipPadding-52-T.scrollWidth);f.subtitle:SetWidth(width-2*T.tooltipPadding-52-T.scrollWidth);f.summary:SetWidth(width-2*T.tooltipPadding-T.scrollWidth);f.comment:SetWidth(width-2*T.tooltipPadding-T.scrollWidth);f.footer:SetWidth(width-2*T.tooltipPadding-T.scrollWidth)
 UI.Motion:Stop(f.scroll);f.scroll.scrollTarget=nil
 f.scroll:SetVerticalScroll(0)
 return f
end
function Tip:ShowApplicants(owner,app,keepPinned)
 if self.pinned and not keepPinned then return end
 self:ClearSource()
 self.pinned=keepPinned==true
 self.sourceApp,self.applicantID=app,app.id
 local f=self:ResetInteractive(owner,512)
 UI:SetText(f.title,L.applicants);f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT");f.title:SetWidth(f.canvas:GetWidth());f.icon:Hide();f.subtitle:Hide();f.summary:Hide()
 f.comment:ClearAllPoints();C.SetPoint(f.comment,"TOPLEFT",f.comment:GetParent(),"TOPLEFT",0,"tooltipFCommentTopleftY2");UI:SetText(f.comment,app.comment or "");f.comment:SetHeight(0)
 local top=40+f.comment:GetStringHeight()+14
 self:EnsureMemberButtons(#app.members)
 for i,member in ipairs(app.members) do local b=f.memberButtons[i];if b then self:BindMember(b,member,f.canvas:GetWidth());b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-top);top=top+b:GetHeight()+2 end end
 UI:SetText(f.footer,"");self:Place(top)
UI:ApplyElementScope("tooltip")
 end
function Tip:Place(height)
 local f=self.interactive;local _,scale,topLimit,bottomLimit=Viewport();f:SetScale(scale);f.canvas:SetHeight(height);f:SetHeight(math.min(height+2*T.tooltipPadding,math.min(T.tooltipMaxHeight,bottomLimit-topLimit)))
 f.scroll:SetHeight(f:GetHeight()-2*T.tooltipPadding);local maximum=ScrollMaximum(f.scroll,f.canvas)
 f.updatingScroll=true;f.scrollbar:SetMinMaxValues(0,maximum);f.scrollbar:SetValue(math.min(f.scroll:GetVerticalScroll(),maximum));f.updatingScroll=false;f.scrollbar:SetShown(maximum>0)
 self:Position(f)
 self.outsideClicks:SetShown(self.pinned==true);f:Show()
UI:ApplyElementScope("tooltip")
 end
function Tip:BindMember(button,member,width,isLeader)
 local context=self.sourceRoster and A.GroupPresentation.Member("roster") or self.sourceApp and ApplicantContext(self.sourceApp) or A.GroupPresentation.Member("search",self.record and self.record.activity)
 C.RekeyElement(button,Members:ID(member));button.memberContext=context
 local bind=self.sourceRoster and Members.BindRoster or self.record and Members.BindSearch or Members.Bind
 return bind(Members,button,member,width,isLeader,context.canOpenDetails,context.canOpenDetails and 12 or 6,context.canOpenDetails and 8 or 4)
end
function Tip:LayoutMemberGrid(members,columns,width,top,leader)
 self:EnsureMemberButtons(#members)
 local cellWidth=(width-(columns-1)*8)/columns
 local rowTop,rowHeight=top,0
 for i,member in ipairs(members) do
  local button=self.interactive.memberButtons[i]
  self:BindMember(button,member,cellWidth,member==leader)
  button:ClearAllPoints();button:SetPoint("TOPLEFT",((i-1)%columns)*(cellWidth+8),-rowTop)
  rowHeight=math.max(rowHeight,button:GetHeight())
  if i%columns==0 or i==#members then rowTop=rowTop+rowHeight+(i==#members and 0 or 2);rowHeight=0 end
 end
 return rowTop
end
function Tip:LayoutRelationships(relationships,width,top)
 if not A:GetSetting("relations") or not relationships then return top end
 local rows=self.interactive.relationshipRows
 local shown=false
 for _,kind in ipairs({"bnet","character","guild"}) do
  local names=relationships[kind]
  if names and #names>0 then
   local row=rows[kind]
   if not row then
    row=CreateFrame("Frame",nil,self.interactive.canvas)
    row.icon=C.Icon(row,T.tooltipRowIconWidth);C.Box(row.icon,{width="tooltipRowIconWidth",height="tooltipRowIconHeight"});row.icon:SetTexture(Members.relationshipTextures[kind]);C.SetPoint(row.icon,"TOPLEFT",row.icon:GetParent(),"TOPLEFT",0,"tooltipRowIconTopleftY")
    row.names=C.Text(row,"",14,"muted");row.names:SetWordWrap(true);C.SetLineHeight(row.names,20);C.SetPoint(row.names,"TOPLEFT",row.names:GetParent(),"TOPLEFT","tooltipRowNamesTopleftX",0)
    UI:Element(row,"tooltip.relationship","tooltip",row,"tooltip.relationship",kind,self.interactive);rows[kind]=row
   end
   row:SetWidth(width);row.names:SetWidth(width-22);row.names:SetHeight(0)
   UI:SetText(row.names,(zh and "：" or ": ")..table.concat(names,zh and "、" or ", "))
   local height=math.max(20,row.names:GetStringHeight())
   row:SetHeight(height);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-top);row:Show()
   top=top+height+4;shown=true
  end
 end
 return shown and top+8 or top
end
function Tip:LayoutRosterGroups(members,columns,width,top)
 self:EnsureMemberButtons(#members)
 local f=self.interactive;local cellWidth=(width-(columns-1)*8)/columns
 local groups,bound,rowTop,rowHeight=0,0,top,0
 for subgroup=1,8 do if self.rosterGroupCounts[subgroup] then
  local x=(groups%columns)*(cellWidth+8)
  local title=f.rosterGroupTitles[subgroup]
  if not title then title=C.Text(f.canvas,"",12,"muted");C.SetLineHeight(title,16,true);f.rosterGroupTitles[subgroup]=title;UI:Element(title,"tooltip.rosterGroup","tooltip",nil,"tooltip.rosterGroup",subgroup,f) end
  title:ClearAllPoints();title:SetPoint("TOPLEFT",x+6,-rowTop);title:SetWidth(cellWidth-12);UI:SetText(title,Say("小队 %d","Group %d"):format(subgroup));title:Show()
  local memberTop=rowTop+title:GetLineHeight()+8
  for _,member in ipairs(members) do if (member.subgroup or 1)==subgroup then
   bound=bound+1;local button=f.memberButtons[bound]
   self:BindMember(button,member,cellWidth,member.isLeader)
   button:ClearAllPoints();button:SetPoint("TOPLEFT",x,-memberTop);memberTop=memberTop+button:GetHeight()+2
  end end
  rowHeight=math.max(rowHeight,memberTop-rowTop-2);groups=groups+1
  if groups%columns==0 then rowTop=rowTop+rowHeight+12;rowHeight=0 end
 end end
 return rowHeight>0 and rowTop+rowHeight or rowTop-12
end
function Tip:ShowRoster(owner,members,keepPinned,activityContext)
 if self.pinned and not keepPinned then return end
 self:ClearSource()
 self.pinned=keepPinned==true;self.sourceRoster=members
 self.expanded=nil;self.rosterContext=activityContext
 local raid
 if activityContext then raid=activityContext.rosterMode=="groups" else raid=not UI.preview and IsInRaid() or #members>5 end
 wipe(self.rosterGroupCounts)
 local groups=0
 if raid then for _,member in ipairs(members) do
  local subgroup=member.subgroup or 1
  if not self.rosterGroupCounts[subgroup] then self.rosterGroupCounts[subgroup]=0;groups=groups+1 end
  self.rosterGroupCounts[subgroup]=self.rosterGroupCounts[subgroup]+1
 end end
 local columns=raid and math.min(3,groups) or 1
 local f=self:ResetInteractive(owner,columns==3 and 960 or columns==2 and 660 or 440)
 f.icon:Hide();f.summary:Hide();f.comment:Hide()
 UI:SetText(f.title,L.yourGroup);f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT")
 UI:SetText(f.subtitle,L.rosterCount:format(#members));f.subtitle:ClearAllPoints();C.SetPoint(f.subtitle,"TOPRIGHT",f.subtitle:GetParent(),"TOPRIGHT",0,"tooltipFSubtitleToprightY");f.subtitle:SetWidth(0)
 local countWidth=f.subtitle:GetStringWidth();f.subtitle:SetWidth(countWidth);f.title:SetWidth(f.canvas:GetWidth()-countWidth-16)
 local top=math.max(24,f.title:GetStringHeight())+16
 if raid and groups>0 then top=self:LayoutRosterGroups(members,columns,f.canvas:GetWidth(),top)
 else
  local leader;for _,member in ipairs(members) do if member.isLeader then leader=member;break end end
  top=self:LayoutMemberGrid(members,1,f.canvas:GetWidth(),top,leader)
 end
 UI:SetText(f.footer,"")
 if #members==0 then
  f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-top);f.comment:SetHeight(0);UI:SetText(f.comment,L.rosterEmpty);f.comment:Show();top=top+f.comment:GetStringHeight()
 end
 self:Place(top)
UI:ApplyElementScope("tooltip")
 end
function Tip:RefreshRoster(owner,members,activityContext)
 local saved=UI.activeModal and UI.activeModal.restoreTooltip
 if saved and saved.sourceRoster and (saved.owner==owner or saved.directPlayer) then
  saved.sourceRoster=members;if activityContext then saved.rosterContext=activityContext end
 end
 if not self.sourceRoster or self.owner~=owner and not self.directPlayer then return end
 if activityContext then self.rosterContext=activityContext end
 local scroll=self.interactive.scroll:GetVerticalScroll()
 local selected
 if self.member then
  selected=FindMember(members,self.selectedMemberID)
 end
 self.sourceRoster=members
 if selected then self:RenderPlayer(selected,self.pinned)
 elseif self.directPlayer then self:Hide();return
 else self:ShowRoster(owner,members,self.pinned,self.rosterContext) end
 local f=self.interactive
 f.scrollbar:SetValue(math.min(scroll,ScrollMaximum(f.scroll,f.canvas)))
end
function Tip:RefreshApplicant()
 if not self.applicantID then return end
 local app=UI:GetGroup():GetApplicant(self.applicantID)
 if not app then self:Hide();return end
 local f=self.interactive;local offset=f.scroll:GetVerticalScroll()
 self.sourceApp=app
 if self.member then
  local member=FindMember(app.members,self.selectedMemberID)
  if not member then self:Hide();return end
  self:RenderPlayer(member,f.back:IsShown())
 else self:ShowApplicants(self.owner,app,self.pinned) end
 f.scrollbar:SetValue(math.min(offset,ScrollMaximum(f.scroll,f.canvas)))
end
function Tip:RefreshRelations()
 local f=self.interactive
 if not f or not f:IsShown() then return end
 local group=UI:GetGroup()
 if self.sourceRoster then self:RefreshRoster(self.owner,group:GetRoster(),self.rosterContext);return end
 if self.applicantID then self:RefreshApplicant();return end
 local offset=f.scroll:GetVerticalScroll()
 local members
 if self.record then
  local app=group:GetApplication(self.record.id)
  local record=group:GetResult(self.record.id) or app and app.result
  if not record then self:Hide();return end
  self.record=record;self.details=group.Results:GetDetails(record);members=self.details.members
 end
 if self.member then
  local current=self.member
  if members then
   current=FindMember(members,self.selectedMemberID)
  end
  if current then
   self:RenderPlayer(current,f.back:IsShown());f.scrollbar:SetValue(math.min(offset,ScrollMaximum(f.scroll,f.canvas)));return
  end
  self.member=nil;self.memberContext=nil
 end
 if self.record then self:RenderGroup()
 elseif self.sourceApp then self:ShowApplicants(self.owner,self.sourceApp,self.pinned) end
 f.scrollbar:SetValue(math.min(offset,ScrollMaximum(f.scroll,f.canvas)))
end
function Tip:ShowGroup(owner,record)
 if self.pinned then return end
 if self.record~=record or self.owner~=owner then self.expanded=false end
 self:ClearSource();self.record=record
 self.details=UI:GetGroup().Results:GetDetails(record)
 self:CaptureOwner(owner);self:RenderGroup()
end
function Tip:RenderGroup()
 local record=self.record;if not record then return end
 local details=self.details or UI:GetGroup().Results:GetDetails(record)
 local raid=A.GroupPresentation.Result(record).kind=="raid"
 local expanded=not raid or self.expanded==true or A:GetSetting("raidMembers")=="always"
 self.expanded=expanded
 local width=raid and (expanded and T.tooltipRaidExpandedWidth or T.tooltipRaidWidth) or T.tooltipGroupWidth
 local f=self:ResetInteractive(nil,width);width=f:GetWidth();f:RegisterEvent("MODIFIER_STATE_CHANGED")
 local mainWidth=raid and width-2*T.tooltipPadding-T.scrollWidth-T.tooltipBossWidth-T.tooltipBossGap or width-2*T.tooltipPadding-T.scrollWidth
 f.title:SetWidth(mainWidth-52);f.subtitle:SetWidth(mainWidth-52);f.summary:SetWidth(mainWidth);f.comment:SetWidth(mainWidth)
 f.icon:SetSize(T.tooltipFIconWidth,T.tooltipFIconHeight);C.SetFont(f.title,18)
 UI:SetActivityIcon(f.icon,record.activity or record);UI:SetText(f.title,record.name or L.unknown)
 UI:SetText(f.subtitle,record.activityName or L.unknown)
 local leader
 for _,member in ipairs(details and details.members or {}) do if member.isLeader or record.leaderKey and member.nameKey==record.leaderKey then leader=member;break end end
 local titleHeight=math.max(24,f.title:GetStringHeight());f.subtitle:ClearAllPoints();C.SetPoint(f.subtitle,"TOPLEFT",f.subtitle:GetParent(),"TOPLEFT","tooltipFSubtitleTopleftX",-titleHeight-4)
 local headerHeight=math.max(40,titleHeight+4+math.max(18,f.subtitle:GetStringHeight()))
 f.summary:Hide()
 local itemLevel=(record.requiredItemLevel or 0)>0 and math.floor(record.requiredItemLevel) or Say("不限","Any")
 local metricTop=headerHeight+16
 local commentTop=raid and headerHeight+12 or metricTop
 if raid then
  f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-commentTop);f.comment:SetHeight(0);UI:Color(f.comment,"muted");UI:SetText(f.comment,record.comment or "")
  metricTop=commentTop+(record.comment and record.comment~="" and f.comment:GetStringHeight()+16 or 0)
 end
 local membersText=UI:MemberCountText(record)
 local metricHeight=0
 local metricLine=f.metrics[1].title:GetLineHeight()
 local metricX,metricY=0,0
 for i=1,(raid and 3 or 4) do
  local label,value
  if i==1 then label=raid and Say("进度","Progress") or record.ratingKind=="pvp" and (record.pvpRatingActivity or Say("队长 PvP 评分","Leader PvP rating")) or Say("队长评分","Leader rating");value=raid and UI:ProgressText(record,details) or UI:ScoreText(record.leaderRating,record.ratingKind)
  elseif i==2 then label,value=record.ratingKind=="pvp" and Say("要求 PvP 装等","Required PvP item level") or Say("要求装等","Required item level"),itemLevel
  elseif i==3 and not raid then label=L.minRating;value=(record.requiredRating or 0)>0 and UI:ScoreText(record.requiredRating,record.ratingKind) or Say("不限","Any")
  else label,value=L.members,membersText end
  local metric=f.metrics[i];UI:SetText(metric.title,label);UI:SetText(metric.value,value);UI:Color(metric.value,raid and i==1 and (value=="—" and "dim" or "good") or "text")
  metric.title:ClearAllPoints();metric.value:ClearAllPoints();metric.title:SetWidth(0);metric.value:SetWidth(0)
  local titleWidth=metric.title:GetStringWidth();local valueWidth=metric.value:GetStringWidth()
  local cellWidth=raid and titleWidth+8+valueWidth or math.max(titleWidth,valueWidth)
  if metricX>0 and metricX+cellWidth>mainWidth then metricX=0;metricY=metricY+(raid and metricLine+8 or metricLine*2+12) end
  metric.title:SetPoint("TOPLEFT",metricX,-metricTop-metricY)
  metric.value:SetPoint("TOPLEFT",metricX+(raid and titleWidth+8 or 0),-metricTop-metricY-(raid and 0 or metricLine+4))
  metricX=metricX+cellWidth+(raid and 24 or 8);metricHeight=metricY+(raid and metricLine or metricLine*2+4)
  metric.title:Show();metric.value:Show()
 end
 local top=metricTop+metricHeight+16
 if raid then
  f.composition:ClearAllPoints();f.composition:SetPoint("TOPLEFT",0,-top);f.composition:Update(details and details.members,details and details.counts,record.maxNumPlayers);f.composition:SetHeight(T.tooltipFCompositionHeight);f.composition:Show();top=top+34
 else
  f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-top);f.comment:SetHeight(0);UI:Color(f.comment,"muted");UI:SetText(f.comment,record.comment or "");top=top+(record.comment and record.comment~="" and f.comment:GetStringHeight()+16 or 0)
 end
 if record.ratingKind=="pvp" and record.pvpRatings and #record.pvpRatings>1 then
  local lines={}
  -- The native first entry is already shown above. Preserve every additional
  -- API-provided bracket without inferring a mapping from activity IDs.
  for index=2,#record.pvpRatings do
   local rating=record.pvpRatings[index]
   lines[#lines+1]=(rating.activityName or Say("PvP 评分","PvP rating")).."  "..UI:ScoreText(rating.rating,"pvp")
  end
  f.pvpRatings:SetWidth(mainWidth);f.pvpRatings:SetHeight(0);UI:SetText(f.pvpRatings,table.concat(lines,"\n"));f.pvpRatings:ClearAllPoints();f.pvpRatings:SetPoint("TOPLEFT",0,-top);f.pvpRatings:Show();top=top+f.pvpRatings:GetStringHeight()+12
 end
 top=self:LayoutRelationships(details and details.relationships,mainWidth,top)
 if expanded then
  local members=details and details.members or {}
  local ordered=members
  if raid then
   ordered,leader=Members:Order(members,self.orderedMembers,record.leaderKey)
  end
  top=self:LayoutMemberGrid(ordered,raid and 3 or 1,mainWidth,top,leader)
 end
 local hasHint=raid and A:GetSetting("raidMembers")~="always"
 if hasHint then
  local hint=expanded and Say("按 %s 收起名单","Press %s to collapse") or Say("按 %s 展开成员名单","Press %s to expand the member list")
  f.footer:SetWidth(mainWidth);UI:SetText(f.footer,hint:format(raidModifierLabels[A:GetSetting("raidMembers")]))
 else UI:SetText(f.footer,"") end
 if raid then
  local list=Bosses(record.activity);local bossTop=32
  f.bossTitle:ClearAllPoints();f.bossTitle:SetPoint("TOPLEFT",mainWidth+T.tooltipBossGap,0);f.bossTitle:Show()
  local progress=UI:ProgressText(record,details)
  f.bossCount:ClearAllPoints();C.SetPoint(f.bossCount,"TOPRIGHT",f.canvas,"TOPRIGHT",0,"tooltipFBossCountToprightY");UI:SetText(f.bossCount,progress);UI:Color(f.bossCount,progress=="—" and "dim" or "good");f.bossCount:SetShown(progress~="—")
  if list and #list>0 and details and details.encounters then
   for index,name in ipairs(list) do
    local row=f.bossRows[index]
    if not row then
     row=CreateFrame("Frame",nil,f.canvas);row:SetWidth(T.tooltipBossWidth)
     row.name=C.Text(row,"",14,"muted",T.tooltipRowNameWidth);row.name:SetWidth(T.tooltipRowNameWidth);C.SetLineHeight(row.name,22);row.name:SetWordWrap(true);row.name:SetPoint("LEFT",0,0)
     row.status=C.Text(row,"",14,"dim",T.tooltipRowStatusWidth);row.status:SetWidth(T.tooltipRowStatusWidth);C.SetLineHeight(row.status,22,true);row.status:SetJustifyH("RIGHT");row.status:SetPoint("RIGHT",0,0)
     UI:Element(row,"tooltip.boss","tooltip",row,"tooltip.boss",index,f);f.bossRows[index]=row
    end
    local defeated=false
    for _,completed in ipairs(details and details.encounters or {}) do if completed==name then defeated=true;break end end
    UI:SetText(row.name,name)
    UI:SetText(row.status,details and details.encounters and (defeated and Say("已击败","Defeated") or Say("未击败","Not defeated")) or L.unknown)
    row.status:SetWidth(0);row.name:SetWidth(T.tooltipBossWidth-12-row.status:GetStringWidth())
    UI:Color(row.status,defeated and "good" or "dim")
    local height=math.max(36,row.name:GetStringHeight()+16)
    row:SetHeight(height);row:ClearAllPoints();row:SetPoint("TOPLEFT",mainWidth+T.tooltipBossGap,-bossTop);row:Show();bossTop=bossTop+height
   end
  else
   local missing=list and #list>0 and Say("队伍未提供首领进度","This group has not provided boss progress") or Say("暂无首领目录","Boss directory unavailable")
   f.bossText:ClearAllPoints();C.SetPoint(f.bossText,"TOPLEFT",f.bossText:GetParent(),"TOPLEFT",mainWidth+T.tooltipBossGap,"tooltipFBossTextTopleftY");f.bossText:SetWidth(T.tooltipBossWidth);UI:SetText(f.bossText,missing);f.bossText:Show()
   bossTop=30+f.bossText:GetStringHeight()
  end
  UI:SetText(f.raidLeader,record.leaderName or L.unknown);f.raidLeader:SetWidth(mainWidth-20);f.raidLeader:SetHeight(0)
  if leader then f.raidLeader:SetTextColor(UI:ClassColor(leader.class)) else UI:Color(f.raidLeader,"muted") end
  local leaderHeight=math.max(f.raidLeader:GetLineHeight(),f.raidLeader:GetStringHeight())
  local hintHeight=hasHint and f.footer:GetStringHeight() or 0;local hintGap=hasHint and 10 or 0
  top=math.max(top+12+leaderHeight+hintGap+hintHeight,bossTop+4)
  f.raidLeader:ClearAllPoints();C.SetPoint(f.raidLeader,"BOTTOMLEFT",f.canvas,"BOTTOMLEFT","tooltipFRaidLeaderBottomleftX",hintHeight+hintGap);f.raidLeader:Show()
  f.raidLeaderIcon:ClearAllPoints();C.SetPoint(f.raidLeaderIcon,"CENTER",f.raidLeader,"TOPLEFT","tooltipFRaidLeaderIconCenterX",-f.raidLeader:GetLineHeight()/2);f.raidLeaderIcon:Show()
  if hasHint then f.footer:ClearAllPoints();f.footer:SetPoint("BOTTOMLEFT",f.canvas,"BOTTOMLEFT",0,0) end
 end
 self:Place(top)
UI:ApplyElementScope("tooltip")
 end
function Tip:ShowPlayer(owner,member,context)
 if self.pinned then return end
 local directRoster=context and context.source=="roster"
 context=context or DefaultMemberContext(member)
 if context.canOpenDetails==false then return end
 self:ClearSource()
 self.sourceRoster=directRoster and UI:GetGroup():GetRoster() or nil;self.directPlayer=directRoster
 self.memberContext=context
 if owner then self:CaptureOwner(owner) end
 self:RenderPlayer(member,false)
end
local function NoteHeader(f,note,top)
 local color=note.type=="positive" and T.good or note.type=="caution" and T.warning or T.muted
 f.noteDivider:ClearAllPoints();f.noteDivider:SetPoint("TOPLEFT",0,-top);f.noteDivider:SetWidth(f.canvas:GetWidth());f.noteDivider:Show()
 f.noteHeading:ClearAllPoints();C.SetPoint(f.noteHeading,"TOPLEFT",f.noteHeading:GetParent(),"TOPLEFT","tooltipFNoteHeadingTopleftX",-top-17);UI:SetText(f.noteHeading,L.notes);UI:Color(f.noteHeading,color);f.noteHeading:Show()
 UI:SetMediaTexture(f.noteGlyph,(note.type=="positive" and "heart" or note.type=="caution" and "caution" or "book")..".tga");f.noteGlyph:SetColor(color);f.noteGlyph:ClearAllPoints();C.SetPoint(f.noteGlyph,"LEFT",f.noteHeading,"LEFT","tooltipFNoteGlyphLeftX",0);f.noteGlyph:Show()
 f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-top-17-f.noteHeading:GetStringHeight()-12);f.comment:SetHeight(0);UI:Color(f.comment,"text");UI:SetText(f.comment,note.reason~="" and note.reason or L.noReason)
 local dateTop=top+17+f.noteHeading:GetStringHeight()+12+math.max(f.comment:GetLineHeight(),f.comment:GetStringHeight())+12
 f.noteDate:ClearAllPoints();f.noteDate:SetPoint("TOPLEFT",0,-dateTop);f.noteDate:SetWidth(f.canvas:GetWidth());UI:SetText(f.noteDate,(note.classSpec and note.classSpec~="" and note.classSpec.." · " or "")..UI:DateText(note.timestamp));f.noteDate:Show()
 return dateTop+math.max(18,f.noteDate:GetStringHeight())
end
function Tip:ShowNote(owner,key)
 if self.pinned then return end
 local note=A.Notes:Find(key);if not note then return end
 self:ClearSource();self.noteKey=key
 local f=self:ResetInteractive(owner,512)
 f.icon:Hide();f.subtitle:Hide();f.summary:Hide()
 f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT");f.title:SetWidth(f.canvas:GetWidth());UI:SetText(f.title,note.name.."-"..note.server)
 C.SetFont(f.title,T.tooltipPlayerNameFont);C.SetLineHeight(f.title,T.tooltipPlayerNameLine)
 local top=NoteHeader(f,note,math.max(24,f.title:GetStringHeight())+16)+12
 f.footer:ClearAllPoints();f.footer:SetPoint("TOPLEFT",0,-top);UI:SetText(f.footer,Say("点击编辑记录。","Click to edit this note."));self:Place(top+f.footer:GetStringHeight())
UI:ApplyElementScope("tooltip")
 end
function Tip:RenderDungeons(scores,top)
 local f=self.interactive
 if not scores.current and not scores.best then
  f.dungeonEmpty:ClearAllPoints();f.dungeonEmpty:SetPoint("TOPLEFT",0,-top);f.dungeonEmpty:SetWidth(f.canvas:GetWidth());f.dungeonEmpty:SetHeight(0);f.dungeonEmpty:Show()
  return top+math.max(20,f.dungeonEmpty:GetStringHeight())
 end
 f.dungeonTitle:ClearAllPoints();f.dungeonTitle:SetPoint("TOPLEFT",0,-top);f.dungeonTitle:Show()
 local labelWidth,levelWidth,statusWidth=0,32,0
 for i=1,2 do
  local row=f.dungeonRows[i]
  if not row then
   row=CreateFrame("Frame",nil,f.canvas)
   row.label=C.Text(row,"",14,"dim");C.SetLineHeight(row.label,20,true)
   row.keyLevel=C.Text(row,"",14,"text");C.SetLineHeight(row.keyLevel,20,true)
   row.name=C.Text(row,"",14,"text");row.name:SetWordWrap(true);C.SetLineHeight(row.name,20)
   row.status=C.Text(row,"",14,"dim");C.SetLineHeight(row.status,20,true);row.status:SetJustifyH("RIGHT")
   UI:Element(row,"tooltip.dungeon","tooltip",row,"tooltip.dungeon",i==1 and "current" or "best",f);f.dungeonRows[i]=row
  end
  local run;if i==1 then run=scores.current else run=scores.best end
  UI:SetText(row.label,i==1 and Say("当前","Current") or Say("最佳","Best"))
  UI:SetText(row.keyLevel,run and "+"..run.level or "")
  UI:SetText(row.status,run and (run.timed and Say("限时","In time") or Say("未限时","Overtime")) or "")
  row.label:SetWidth(0);row.keyLevel:SetWidth(0);row.status:SetWidth(0)
  labelWidth=math.max(labelWidth,row.label:GetStringWidth());levelWidth=math.max(levelWidth,row.keyLevel:GetStringWidth());statusWidth=math.max(statusWidth,row.status:GetStringWidth())
 end
 top=top+math.max(28,f.dungeonTitle:GetHeight()+4)
 local width=f.canvas:GetWidth()
 for i,row in ipairs(f.dungeonRows) do
  local run;if i==1 then run=scores.current else run=scores.best end
  row:SetWidth(width);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-top)
  row.label:ClearAllPoints();row.label:SetPoint("TOPLEFT");row.label:SetWidth(labelWidth)
  row.keyLevel:ClearAllPoints();row.keyLevel:SetPoint("TOPLEFT",labelWidth+12,0);row.keyLevel:SetWidth(levelWidth);row.keyLevel:SetShown(run~=nil)
  if run and (row.coloredLevel~=run.level or row.keyLevel._color~=nil) then
   local color=C_ChallengeMode.GetKeystoneLevelRarityColor(run.level)
   row.keyLevel:SetTextColor(color.r,color.g,color.b);row.keyLevel._color=nil;row.coloredLevel=run.level
  end
  row.status:ClearAllPoints();row.status:SetPoint("TOPRIGHT");row.status:SetWidth(statusWidth);row.status:SetShown(run~=nil);UI:Color(row.status,run and run.timed and "good" or "dim")
  local nameX=labelWidth+12+(run and levelWidth+12 or 0)
  row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",nameX,0);row.name:SetWidth(width-nameX-(run and statusWidth+12 or 0));row.name:SetHeight(0);UI:SetText(row.name,run and run.name or Say("未提供记录","No record available"));UI:Color(row.name,run and "text" or "dim")
  local height=math.max(row.name:GetLineHeight(),row.name:GetStringHeight());row:SetHeight(height);row:Show();top=top+height+(i==1 and 8 or 0)
 end
 return top
end
function Tip:RenderPlayer(member,fromGroup,adjustPoint)
 local context=self.sourceRoster and A.GroupPresentation.Member("roster") or self.sourceApp and ApplicantContext(self.sourceApp) or self.memberContext or DefaultMemberContext(member)
 if context.source=="applicant" then
  local applicant=self.sourceApp or member.applicantID and UI:GetGroup():GetApplicant(member.applicantID)
  if applicant then context=ApplicantContext(applicant) end
 end
 if context.canOpenDetails==false then return end
 self.memberContext=context
 fromGroup=fromGroup==true and not self.directPlayer
 self.member=member;self.pinned=fromGroup==true;self.adjustPoint=adjustPoint==true
 self.selectedMemberID=Members:ID(member)
 self.applicantID=context.source=="applicant" and (self.sourceApp and self.sourceApp.id or member.applicantID) or nil
 local scores
 if context.source=="applicant" then
  if context.showDungeonRecords then scores=UI:GetGroup():GetApplicantDungeonScores(member) end
 else scores=member.dungeonScores end
 local showMapScore=context.source=="applicant" and context.showDungeonRecords
 local f=self:ResetInteractive(nil,(scores or showMapScore) and 512 or 440,"CENTER");f:UnregisterEvent("MODIFIER_STATE_CHANGED")
 local key,name,realm=Members:Identity(member)
 local top=fromGroup and 48 or 0
 f.back:SetShown(fromGroup==true);f.back:ClearAllPoints();f.back:SetPoint("TOPLEFT");f.back:SetWidth(f.back.label:GetStringWidth()+22)
 UI:SetFactionIcon(f.playerFaction,member);UI:SetRoleIcon(f.playerRole,member.assignedRole)
 local displayName=name or member.name or L.unknown
 UI:SetText(f.title,realm and realm~="" and displayName.."-"..realm or displayName);f.title:SetTextColor(UI:ClassColor(member.class));f.title._color=nil
 C.SetFont(f.title,T.tooltipPlayerNameFont);C.SetLineHeight(f.title,T.tooltipPlayerNameLine)
 f.subtitle:Hide();UI:SetMemberIcon(f.icon,member)
 local className=member.localizedClass
 if not className and member.class then local _,name=A.Specializations:Class(member.class);className=name end
 local specName=UI:SpecName(member)
 local relation=Members:Relations(member)
 local width=f.canvas:GetWidth();local identityX=T.tooltipPlayerIconSize+T.tooltipIdentityGap
 f.playerRole:SetShown(f.playerRole:GetTexture()~=nil)
 local bothMarks=f.playerRole:IsShown() and f.playerFaction:IsShown()
 local marks=(f.playerRole:IsShown() and T.tooltipIdentityMarkSize or 0)+(f.playerFaction:IsShown() and T.tooltipIdentityMarkSize or 0)+(bothMarks and 6 or 0)
 local identityWidth=width-identityX-(marks>0 and marks+12 or 0)
 f.icon:ClearAllPoints();f.icon:SetPoint("TOPLEFT",0,-top-2);f.icon:SetSize(T.tooltipPlayerIconSize,T.tooltipPlayerIconSize)
 f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",identityX,-top);f.title:SetWidth(identityWidth)
 local summaryTop=top+math.max(T.tooltipPlayerNameLine,f.title:GetStringHeight())+2
 f.summary:ClearAllPoints();f.summary:SetPoint("TOPLEFT",identityX,-summaryTop);f.summary:SetWidth(identityWidth);f.summary:SetHeight(0);f.summary:SetWordWrap(true);UI:SetText(f.summary,(className or L.unknown)..(specName and "-"..specName or "")..(relation~="" and " · "..relation or ""))
 local identityBottom=summaryTop+math.max(20,f.summary:GetStringHeight())
 local identityCenter=-(top+identityBottom)/2
 f.icon:ClearAllPoints();f.icon:SetPoint("LEFT",f.canvas,"TOPLEFT",0,identityCenter)
 f.playerRole:ClearAllPoints();f.playerRole:SetPoint("RIGHT",f.canvas,"TOPRIGHT",0,identityCenter)
 f.playerFaction:ClearAllPoints()
 if f.playerRole:IsShown() then C.SetPoint(f.playerFaction,"RIGHT",f.playerRole,"LEFT","tooltipFPlayerFactionRightX",0)
 else f.playerFaction:SetPoint("RIGHT",f.canvas,"TOPRIGHT",0,identityCenter) end
 local metricTop=math.max(top+T.tooltipPlayerIconSize+2,identityBottom)+16
 local metricCount=showMapScore and 3 or context.showRating and 2 or 1
 local columnWidth=(width-(metricCount-1)*16)/metricCount
 local metricHeight,valueHeight=f.metrics[1].title:GetHeight(),f.metrics[1].value:GetHeight()
 local rating,ratingKind,ratingActivity
 if context.showRating then rating,ratingKind,ratingActivity=UI:MemberRating(member) end
 for i=1,metricCount do
  local isMapScore=showMapScore and i==2
  local label=i==1 and (ratingKind=="pvp" and Say("PvP 装等","PvP item level") or L.itemLevel) or isMapScore and Say("单本分","Dungeon score") or (ratingKind=="pvp" and (ratingActivity or Say("PvP 评分","PvP rating")) or Say("大秘境评分","Mythic+ rating"))
  local metric=f.metrics[i];metric.title:ClearAllPoints();metric.value:ClearAllPoints()
  UI:SetText(metric.title,label)
  if i==1 then UI:SetText(metric.value,member.itemLevel and math.floor(member.itemLevel) or "—");UI:Color(metric.value,"text")
  elseif isMapScore then UI:SetScore(metric.value,scores and scores.mapScore,"map")
  else UI:SetScore(metric.value,rating,ratingKind) end
  metric.title:SetWidth(columnWidth);metric.title:SetHeight(0);metric.title:SetWordWrap(true)
  metric.value:SetWidth(columnWidth)
  metric.title:Show();metric.value:Show();metricHeight=math.max(metricHeight,metric.title:GetStringHeight())
 end
 for i=1,metricCount do
  local metric=f.metrics[i]
  f.metricTitleItems[i].hidden=false;f.metricTitleItems[i].width=columnWidth;f.metricTitleItems[i].height=metricHeight
  f.metricValueItems[i].hidden=false;f.metricValueItems[i].width=columnWidth;f.metricValueItems[i].height=valueHeight
 end
 f.metricTitleOptions.width,f.metricTitleOptions.height,f.metricTitleOptions.y=width,metricHeight,-metricTop
 f.metricValueOptions.width,f.metricValueOptions.height,f.metricValueOptions.y=width,valueHeight,-metricTop-metricHeight-4
 f.metricTitleLayout:Layout();f.metricValueLayout:Layout()
 top=metricTop+metricHeight+4+valueHeight+20
 if scores then top=self:RenderDungeons(scores,top)+20 end
 local note=key and A.Notes and A.Notes:Find(key)
 if note then top=NoteHeader(f,note,top)+20 else f.comment:Hide() end
 local showWCL=name~=nil and realm~=nil and realm~=""
 local showNote=not UI.preview and key~=nil
 f.wcl:SetShown(showWCL);UI:SetText(f.note.label,note and Say("编辑笔记","Edit note") or L.record);f.note:SetShown(showNote)
 f.actionOptions.width,f.actionOptions.y=f.canvas:GetWidth(),-top;f.actionLayout:Layout()
 UI:SetText(f.footer,"");self:Place(top+((showWCL or showNote) and 40 or 0))
UI:ApplyElementScope("tooltip")
 end


function Tip:LeaveOwner(owner)
 if self.pinned then return end
 if owner and owner~=self.owner then return end
 if not self.interactive or not self.interactive:IsShown() then self:Hide();return end
 local elapsed=0
 UI.Motion:Start(self,function(dt)
  elapsed=elapsed+dt;if elapsed<.11 then return end
  local area=self.owner and (self.owner.tooltipArea or self.owner)
  if not self.interactive:IsMouseOver() and not (area and area:IsMouseOver()) then self:Hide() end
  return true
 end)
end





function Tip:RegisterBuildInteractiveElements()
local f=self.interactive
 UI:Element(f,"tooltip.rich","tooltip",f)
 UI:ElementFields(f,"tooltip","scroll canvas scrollbar icon title subtitle summary pvpRatings composition raidLeader raidLeaderIcon comment footer bossTitle bossCount bossText dungeonTitle dungeonEmpty playerRole playerFaction noteHeading noteGlyph noteDate noteDivider back wcl note","tooltip",f)
 UI:Element(self.outsideClicks,"tooltip.outside","tooltip")
 for index,metric in ipairs(f.metrics) do UI:Element(metric.title,"tooltip.metric.title","tooltip",nil,"tooltip.metric.title",index,f);UI:Element(metric.value,"tooltip.metric.value","tooltip",nil,"tooltip.metric.value",index,f) end
end
