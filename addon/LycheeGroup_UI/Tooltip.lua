local A = _G.LycheeGroup
local UI = A.UI
local T,L,C = UI.Theme,UI.L,UI.C
-- A separate tooltip owned by this UI; the global GameTooltip stays untouched.
local Tip={orderedMembers={}}
local GUTTER=T.scrollWidth
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
end
function Tip:IsOwned(owner) return self.owner==owner end
function Tip:Hide()
 if self.outsideClicks then self.outsideClicks:Hide() end
 UI.Motion:Stop(self)
 wipe(self.orderedMembers)
 if self.interactive then
  local f=self.interactive;f:Hide();f:UnregisterEvent("MODIFIER_STATE_CHANGED")
  for _,button in ipairs(f.memberButtons) do button.member=nil;button.targetKey=nil end
 end
 self.owner=nil
 self.record,self.member,self.details,self.pinned,self.sourceApp=nil,nil,nil,nil,nil
 self.pointX,self.pointY,self.positionX,self.positionY,self.expanded,self.adjustPoint=nil,nil,nil,nil,nil,nil
end

local zh=GetLocale()=="zhCN"
local function Say(cn,en) return zh and cn or en end
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
 if not list or #list==0 or not details or not details.encounters then return "—" end
 return #details.encounters.."/"..#list
end
local function Identity(member)
 if member.nameKey then return A:PlayerKey(member.nameKey) end
 if member.name and ((member.realm and member.realm~="") or member.name:find("-",1,true)) then return A:PlayerKey(member.name,member.realm) end
 return nil,member.name,nil
end
local function NoteMark(key)
 if A.db.noteMarks==false or not UI:HasNote(key) then return "" end
 local note=A.Notes:Find(key)
 local color=note.type=="positive" and T.good or note.type=="caution" and T.warning or T.muted
 return " "..UI:Hex(color).."•|r"
end
local function MemberRelations(member)
 if not A.db.relations then return "" end
 local labels={}
 if member.isBNetFriend then labels[#labels+1]=UI:Hex(T.blue)..L.friendBnet.."|r" end
 if member.isCharFriend then labels[#labels+1]=UI:Hex(T.blue)..L.friendChar.."|r" end
 if member.isGuildMate then labels[#labels+1]=UI:Hex(T.good)..L.friendGuild.."|r" end
 if #labels==0 and member.relationship and member.relationship~="" then labels[1]=member.relationship end
 return table.concat(labels," · ")
end
local function MemberMeta(member)
 local text=UI:SpecName(member) or member.localizedClass or L.unknown
 local relation=MemberRelations(member)
 return text..(relation~="" and " · "..relation or "")
end
function UI:MemberRating(member)
 if member.ratingKind=="pvp" then return member.rating,"pvp",member.pvpRatingInfo and member.pvpRatingInfo.activityName end
 return member.dungeonScore or member.rating,"dungeon"
end
function UI:CopyText(title,value,restoreTooltip,identity,fieldLabel)
 local modal=self:OpenModal("copyText",title,560,314)
 if not modal.built then
  local f=modal.frame;f.help=C.Text(modal.content,"",14,T.muted,512);f.help:SetPoint("TOPLEFT");C.SetLineHeight(f.help,22,true)
  f.fieldLabel=C.Text(modal.content,Say("角色链接","Character link"),14,T.muted,512);C.SetLineHeight(f.fieldLabel,20,true);f.fieldLabel:SetPoint("TOPLEFT",0,-42)
  f.copyHint=C.Text(modal.content,Say("链接已选中，按 Ctrl+C 复制。","The link is selected. Press Ctrl+C to copy."),14,T.dim,512);C.SetLineHeight(f.copyHint,20,true);f.copyHint:SetPoint("TOPLEFT",0,-126)
  f.field=C.Edit(modal.content,512,44,false,false,"modal");f.field:SetPoint("TOPLEFT",0,-70)
  f.field.box:SetScript("OnTextChanged",function(box,user) if user then box:SetText(f.value);box:HighlightText() end end)
  f.close=C.Button(modal.content,L.close,80,function() modal:Close() end);f.close:SetPoint("BOTTOMRIGHT")
  modal.onClose=function(reason)
   local saved=modal.restoreTooltip;modal.restoreTooltip=nil
   f.field.box:ClearFocus();f.value=nil;f.field.box:SetText("")
   if saved and reason==nil and UI.frame:IsShown() and not UI.hiding and UI.page==saved.page and not UI.activeModal then
    Tip.owner,Tip.record,Tip.details,Tip.sourceApp=saved.owner,saved.record,saved.details,saved.sourceApp
    Tip.pointX,Tip.pointY,Tip.positionX,Tip.positionY,Tip.expanded=saved.pointX,saved.pointY,saved.positionX,saved.positionY,saved.expanded
    Tip:RenderPlayer(saved.member,true)
   end
  end
  modal.built=true;self.copyDialog=f
 end
 local f=modal.frame;modal.restoreTooltip=restoreTooltip;UI:SetText(f.fieldLabel,fieldLabel or Say("角色链接","Character link"));UI:SetText(f.help,identity or Say("按 Ctrl+C 复制完整文本。","Press Ctrl+C to copy the complete text."));f.value=value;f.field.box:SetText(value);f.field.box:SetFocus();f.field.box:HighlightText()
end
function Tip:BuildInteractive()
 local f=CreateFrame("Frame",nil,UIParent);f:SetFrameStrata("TOOLTIP");f:SetFrameLevel(2);f:SetClampedToScreen(true);f:EnableMouse(true);C.Shadow(f,16);C.Panel(f,T.raised,16)
 -- Observe outside clicks only while pinned; no mouse surface intercepts the game.
 local outside=CreateFrame("Frame",nil,UIParent)
 outside:SetScript("OnShow",function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
 outside:SetScript("OnHide",function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
 outside:SetScript("OnEvent",function() if not Tip.interactive:IsMouseOver() then Tip:Hide() end end)
 outside:Hide();self.outsideClicks=outside
 f:SetScript("OnEnter",function() UI.Motion:Stop(Tip) end)
 f:SetScript("OnLeave",function() Tip:LeaveOwner() end)
 f:SetScript("OnEvent",function(_,event,key,down)
  if event=="MODIFIER_STATE_CHANGED" and down==1 and (key=="LSHIFT" or key=="RSHIFT") and Tip.record and Tip.record.categoryID==3 and not Tip.member and A.db.raidMembers~="always" then
   Tip.expanded=not Tip.expanded;Tip:RenderGroup()
  end
 end)
 local scroll=CreateFrame("ScrollFrame",nil,f);scroll:SetPoint("TOPLEFT",16,-16);scroll:SetPoint("BOTTOMRIGHT",-16-GUTTER,16)
 local canvas=CreateFrame("Frame",nil,scroll);canvas:SetSize(360,100);scroll:SetScrollChild(canvas)
 local slider=C.ScrollBar(f);slider:SetPoint("TOPRIGHT",0,-16);slider:SetPoint("BOTTOMRIGHT",0,16);f.scrollbar=slider
 slider:SetScript("OnValueChanged",function(_,value) if not f.updatingScroll then UI.Motion:Stop(scroll);scroll.scrollTarget=nil;scroll:SetVerticalScroll(value) end end)
 scroll:EnableMouseWheel(true);scroll:SetScript("OnMouseWheel",function(self,delta)
  local maximum=math.max(0,canvas:GetHeight()-self:GetHeight());local target=math.max(0,math.min(maximum,(self.scrollTarget or self:GetVerticalScroll())-delta*42))
  self.scrollTarget=target;UI.Motion:Stop(self)
  if A.db.reduceMotion then self:SetVerticalScroll(target);f.updatingScroll=true;slider:SetValue(target);f.updatingScroll=false;return end
  local from,elapsed=self:GetVerticalScroll(),0
  UI.Motion:Start(self,function(dt)
   elapsed=math.min(.14,elapsed+dt);local p=elapsed/.14;p=p*(2-p);local value=from+(target-from)*p
   self:SetVerticalScroll(value);f.updatingScroll=true;slider:SetValue(value);f.updatingScroll=false
   if elapsed==.14 then self.scrollTarget=nil;return true end
  end)
 end)
 f.scroll,f.canvas=scroll,canvas
 f:SetScript("OnHide",function() outside:Hide();UI.Motion:Stop(scroll);scroll.scrollTarget=nil end)
 f.icon=C.Icon(canvas,34);f.icon:SetPoint("TOPLEFT")
 f.title=C.Text(canvas,"",18,T.text);f.title:SetPoint("TOPLEFT",46,0);f.title:SetWordWrap(true)
 f.subtitle=C.Text(canvas,"",14,T.muted);f.subtitle:SetPoint("TOPLEFT",52,-28);C.SetLineHeight(f.subtitle,20)
 f.summary=C.Text(canvas,"",14,T.muted);f.summary:SetPoint("TOPLEFT",0,-56);C.SetLineHeight(f.summary,20)
 f.relations=C.Text(canvas,"",14,T.muted);f.relations:SetWordWrap(true);C.SetLineHeight(f.relations,20);f.relations:Hide()
 f.pvpRatings=C.Text(canvas,"",14,T.muted);f.pvpRatings:SetWordWrap(true);C.SetLineHeight(f.pvpRatings,20);f.pvpRatings:Hide()
 f.metrics={}
 for i=1,4 do local title=C.Text(canvas,"",14,T.dim);C.SetLineHeight(title,20,true);local value=C.Text(canvas,"",14,T.text);C.SetLineHeight(value,20,true);f.metrics[i]={title=title,value=value} end
 f.composition=C.Roster(canvas,22,5);f.composition:SetPoint("TOPLEFT",0,-86)
 f.leader=C.Text(canvas,"",14,T.muted);f.leader:SetPoint("TOPLEFT",0,-122);C.SetLineHeight(f.leader,20)
 f.leaderIcon=C.Icon(canvas,14);f.leaderIcon:SetTexture(T.media.."leader.tga");f.leaderIcon:Hide()
 f.comment=C.Text(canvas,"",14,T.text);f.comment:SetPoint("TOPLEFT",0,-146);f.comment:SetWordWrap(true);C.SetLineHeight(f.comment,22)
 f.footer=C.Text(canvas,"",14,T.dim);f.footer:SetWordWrap(true);C.SetLineHeight(f.footer,20)
 f.bossTitle=C.Text(canvas,Say("首领进度","Boss progress"),14,T.text,120);C.SetLineHeight(f.bossTitle,20,true)
 f.bossCount=C.Text(canvas,"",14,T.text,48);f.bossCount:SetJustifyH("RIGHT");C.SetLineHeight(f.bossCount,20,true)
 f.bossText=C.Text(canvas,"",14,T.muted,180);f.bossText:SetWordWrap(true);C.SetLineHeight(f.bossText,20)
 f.bossRows={}
 f.memberButtons={}
 f.playerRole=C.Icon(canvas,20);f.playerRole:Hide()
 f.noteHeading=C.Text(canvas,"",14,T.muted);C.SetLineHeight(f.noteHeading,20,true);f.noteHeading:Hide()
 f.noteGlyph=C.Glyph(canvas,"book",16);f.noteGlyph:Hide()
 f.noteDate=C.Text(canvas,"",14,T.dim);C.SetLineHeight(f.noteDate,20);f.noteDate:Hide()
 f.noteDivider=canvas:CreateTexture(nil,"ARTWORK");f.noteDivider:SetColorTexture(unpack(T.border));f.noteDivider:SetHeight(1);f.noteDivider:Hide()
 f.back=C.Button(canvas,Say("返回队伍","Back to group"),160,function() Tip.member=nil;Tip.adjustPoint=true;if Tip.record then Tip:RenderGroup() elseif Tip.sourceApp then Tip:ShowApplicants(Tip.owner,Tip.sourceApp,true) end end)
 f.back:SetHeight(26);f.back.label:SetFont(T.font,14,"");C.SetLineHeight(f.back.label,20,true);f.back.label:ClearAllPoints();f.back.label:SetPoint("LEFT",22,0);UI:Color(f.back.label,T.muted);C.Glyph(f.back,"arrow",14):SetPoint("LEFT",0,0)
 f.wcl=C.Button(canvas,Say("复制 WCL 链接","Copy WCL link"),170,function()
  local _,name,realm=Identity(Tip.member)
  if UI.preview or not name or not realm or realm=="" then return end
  local function Encode(value) return value:gsub("([^%w%-_%.~])",function(ch) return ("%%%02X"):format(ch:byte()) end) end
  local regions={[1]="us",[2]="kr",[3]="eu",[4]="tw",[5]="cn"};local region=regions[GetCurrentRegion()] or "us"
  local restore=Tip.pinned and {owner=Tip.owner,record=Tip.record,details=Tip.details,sourceApp=Tip.sourceApp,member=Tip.member,page=UI.page,pointX=Tip.pointX,pointY=Tip.pointY,positionX=Tip.positionX,positionY=Tip.positionY,expanded=Tip.expanded} or nil
  UI:CopyText(Say("复制 WCL 链接","Copy WCL link"),"https://"..(region=="cn" and "cn." or "www.").."warcraftlogs.com/character/"..region.."/"..Encode(realm).."/"..Encode(name),restore,name.."-"..realm)
 end)
 f.note=C.Button(canvas,L.record,120,function()
  local key,name,realm=Identity(Tip.member)
  if UI.preview then return end
  if name then A:Open("notes",UI:HasNote(key) and {playerKey=key} or {add={name=name,realm=realm,class=Tip.member.class,specID=Tip.member.specID}}) end
 end)
 self.interactive=f;f:Hide()
end
function Tip:EnsureMemberButtons(count)
 local f=self.interactive
 for i=#f.memberButtons+1,count do
  local b=C.Button(f.canvas,"",250,function(self) if self.member then Tip:RenderPlayer(self.member,true,true) end end);b:SetHeight(54);b.fill:SetRadius(8);b.hover:SetRadius(8);b.label:Hide()
  b.icon=C.GameIcon(b,24);b.icon:SetPoint("LEFT",0,0)
  b.name=C.Text(b,"",T.listTitleSize,T.text);b.name:SetPoint("TOPLEFT",32,-2);b.name:SetWordWrap(true);C.SetLineHeight(b.name,T.listTitleLineHeight)
  b.leaderIcon=C.Icon(b,12);b.leaderIcon:SetTexture(T.media.."leader.tga");b.leaderIcon:SetPoint("TOPLEFT",32,-4);b.leaderIcon:Hide()
  b.realm=C.Text(b,"",14,T.dim);b.realm:SetPoint("TOPLEFT",32,-25);b.realm:SetWordWrap(true);C.SetLineHeight(b.realm,20)
  b.role=C.Icon(b,14);b.role:SetPoint("RIGHT",-4,0)
  f.memberButtons[i]=b
 end
end
function Tip:ResetInteractive(owner,width)
 UI.Motion:Stop(self)
 wipe(self.orderedMembers)
 if not self.interactive then self:BuildInteractive() end
 local f=self.interactive;if owner then self:CaptureOwner(owner) end
 f:UnregisterEvent("MODIFIER_STATE_CHANGED")
 f.icon:ClearAllPoints();f.icon:SetPoint("TOPLEFT")
 f.icon:SetSize(40,40)
 f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",52,0);UI:Color(f.title,T.text)
 f.title:SetFont(T.font,18,"");C.SetLineHeight(f.title,24);f.title:SetHeight(0)
 f.subtitle:ClearAllPoints();f.subtitle:SetPoint("TOPLEFT",52,-28);f.subtitle:SetHeight(0)
 f.summary:ClearAllPoints();f.summary:SetPoint("TOPLEFT",0,-56)
 f.leader:ClearAllPoints();f.leader:SetPoint("TOPLEFT",0,-122);f.leader:SetJustifyH("LEFT");f.leader:SetWordWrap(false);f.leaderIcon:Hide()
 f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-146)
 for _,b in ipairs(f.memberButtons) do b:Hide();b.member=nil;b.targetKey=nil end
 for _,metric in ipairs(f.metrics) do metric.title:Hide();metric.value:Hide() end
 f.back:Hide();f.note:Hide();f.wcl:Hide();f.playerRole:Hide();f.noteHeading:Hide();f.noteGlyph:Hide();f.noteDate:Hide();f.noteDivider:Hide();f.bossTitle:Hide();f.bossCount:Hide();f.bossText:Hide();f.composition:Hide();f.relations:Hide();f.pvpRatings:Hide()
 for _,row in ipairs(f.bossRows) do row:Hide() end
 f.icon:Show();f.title:Show();f.subtitle:Show();f.summary:Show();f.leader:Show();f.comment:Show()
 f:SetWidth(width);f.canvas:SetWidth(width-32-GUTTER);f.title:SetWidth(width-84-GUTTER);f.subtitle:SetWidth(width-84-GUTTER);f.summary:SetWidth(width-32-GUTTER);f.leader:SetWidth(width-32-GUTTER);f.comment:SetWidth(width-32-GUTTER);f.footer:SetWidth(width-32-GUTTER)
 UI.Motion:Stop(f.scroll);f.scroll.scrollTarget=nil
 f.scroll:SetVerticalScroll(0)
 return f
end
function Tip:ShowApplicants(owner,app,keepPinned)
 if self.pinned and not keepPinned then return end
 self.pinned=keepPinned==true
 self.sourceApp=app
 self.record,self.member,self.details=nil,nil,nil
 local f=self:ResetInteractive(owner,424)
 UI:SetText(f.title,L.applicants);f.icon:Hide();f.subtitle:Hide();f.summary:Hide();f.leader:Hide()
 f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-40);UI:SetText(f.comment,app.comment or "");f.comment:SetHeight(0)
 local top=40+f.comment:GetStringHeight()+14
 self:EnsureMemberButtons(#app.members)
 for i,member in ipairs(app.members) do local b=f.memberButtons[i];if b then self:BindMember(b,member,f.canvas:GetWidth());b:ClearAllPoints();b:SetPoint("TOPLEFT",0,-top);top=top+b:GetHeight()+4 end end
 UI:SetText(f.footer,"");self:Place(top)
end
function Tip:Place(height)
 local f=self.interactive;local _,scale,topLimit,bottomLimit=Viewport();f:SetScale(scale);f.canvas:SetHeight(height);f:SetHeight(math.min(height+32,math.min(760,bottomLimit-topLimit)))
 f.scroll:SetHeight(f:GetHeight()-32);local maximum=math.max(0,height-f.scroll:GetHeight())
 f.updatingScroll=true;f.scrollbar:SetMinMaxValues(0,maximum);f.scrollbar:SetValue(math.min(f.scroll:GetVerticalScroll(),maximum));f.updatingScroll=false;f.scrollbar:SetShown(maximum>0)
 self:Position(f)
 self.outsideClicks:SetShown(self.pinned==true);f:Show()
end
function Tip:BindMember(button,member,width)
 button.member=member;button.targetKey=member.nameKey or member.name;button:SetWidth(width)
 button:SetHeight(54);button.icon:ClearAllPoints();button.icon:SetPoint("LEFT",8,0);button.role:ClearAllPoints();button.role:SetPoint("RIGHT",-8,0);button.leaderIcon:Hide();button.name:ClearAllPoints();button.name:SetPoint("TOPLEFT",40,-6);button.name:SetWordWrap(true);button.realm:ClearAllPoints();button.realm:SetPoint("TOPLEFT",40,-28);button.role:SetSize(16,16)
 UI:SetMemberIcon(button.icon,member);UI:SetRoleIcon(button.role,member.assignedRole)
 local key,name,realm=Identity(member);local r,g,b=UI:ClassColor(member.class)
 UI:SetText(button.name,(name or member.name or L.unknown)..(realm and UI:Hex(T.muted).."-"..realm.."|r" or "")..NoteMark(key));button.name:SetTextColor(r,g,b);button.name:SetWidth(width-72)
 UI:SetText(button.realm,MemberMeta(member));button.realm:SetWidth(width-72)
 local nameHeight=math.max(T.listTitleLineHeight,button.name:GetStringHeight());button.realm:ClearAllPoints();button.realm:SetPoint("TOPLEFT",40,-10-nameHeight);button:SetHeight(math.max(60,nameHeight+button.realm:GetStringHeight()+16))
 button:Show()
end
function Tip:ShowGroup(owner,record)
 if self.pinned then return end
 if self.record~=record or self.owner~=owner then self.expanded=false end
 self.record,self.member,self.sourceApp=record,nil,nil
 self.details=UI:GetGroup().Results:GetDetails(record)
 self:ResetInteractive(owner,424);self:RenderGroup()
end
function Tip:RenderGroup()
 local record=self.record;if not record then return end
 local details=self.details or UI:GetGroup().Results:GetDetails(record)
 local raid=record.categoryID==3
 local expanded=not raid or self.expanded==true or A.db.raidMembers=="always"
 self.expanded=expanded
 local width=raid and (expanded and 960 or 640) or 424
 local f=self:ResetInteractive(nil,width);f:RegisterEvent("MODIFIER_STATE_CHANGED")
 local mainWidth=raid and width-32-GUTTER-184-20 or width-32-GUTTER
 f.title:SetWidth(mainWidth-52-(raid and 152 or 0));f.subtitle:SetWidth(mainWidth-52-(raid and 152 or 0));f.summary:SetWidth(mainWidth);f.comment:SetWidth(mainWidth)
 f.icon:SetSize(40,40);f.title:SetFont(T.font,18,"")
 UI:SetActivityIcon(f.icon,record.activity or record);UI:SetText(f.title,record.name or L.unknown)
 UI:SetText(f.subtitle,record.activityName or L.unknown)
 local titleHeight=math.max(24,f.title:GetStringHeight());f.subtitle:ClearAllPoints();f.subtitle:SetPoint("TOPLEFT",52,-titleHeight-4)
 local headerHeight=math.max(40,titleHeight+4+math.max(18,f.subtitle:GetStringHeight()))
 UI:SetText(f.leader,record.leaderName or L.unknown)
 local leader
 for _,member in ipairs(details and details.members or {}) do if member.isLeader or record.leaderKey and member.nameKey==record.leaderKey then leader=member;break end end
 if leader then f.leader:SetTextColor(UI:ClassColor(leader.class)) end
 if raid then
  f.leader:SetWidth(0);local leaderWidth=math.min(mainWidth*.42,f.leader:GetStringWidth()+18)
  f.leader:SetWidth(leaderWidth-18);f.leader:SetWordWrap(true);f.leader:SetJustifyH("LEFT");f.leader:ClearAllPoints();f.leader:SetPoint("TOPRIGHT",f.canvas,"TOPLEFT",mainWidth,-4)
  f.leaderIcon:ClearAllPoints();f.leaderIcon:SetPoint("CENTER",f.leader,"TOPLEFT",-11,-f.leader:GetLineHeight()/2);f.leaderIcon:Show()
  f.title:SetWidth(mainWidth-leaderWidth-16-52);f.subtitle:SetWidth(mainWidth-leaderWidth-16-52)
  titleHeight=math.max(24,f.title:GetStringHeight());f.subtitle:ClearAllPoints();f.subtitle:SetPoint("TOPLEFT",52,-titleHeight-4)
  headerHeight=math.max(40,titleHeight+4+math.max(18,f.subtitle:GetStringHeight()),f.leader:GetStringHeight()+4)
 else f.leader:Hide() end
 f.summary:Hide()
 local itemLevel=(record.requiredItemLevel or 0)>0 and math.floor(record.requiredItemLevel) or Say("不限","Any")
 local metricTop=headerHeight+16
 local commentTop=raid and headerHeight+12 or metricTop
 if raid then
  f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-commentTop);f.comment:SetHeight(0);UI:Color(f.comment,T.muted);UI:SetText(f.comment,record.comment or "")
  metricTop=commentTop+(record.comment and record.comment~="" and f.comment:GetStringHeight()+16 or 0)
 end
 local membersText=UI:MemberCountText(record)
 local metricHeight=40
 local metricX,metricY=0,0
 for i=1,(raid and 3 or 4) do
  local label,value
  if i==1 then label=raid and Say("进度","Progress") or record.ratingKind=="pvp" and (record.pvpRatingActivity or Say("队长 PvP 评分","Leader PvP rating")) or Say("队长评分","Leader rating");value=raid and UI:ProgressText(record,details) or UI:ScoreText(record.leaderRating,record.ratingKind)
  elseif i==2 then label,value=record.ratingKind=="pvp" and Say("要求 PvP 装等","Required PvP item level") or Say("要求装等","Required item level"),itemLevel
  elseif i==3 and not raid then label=L.minRating;value=(record.requiredRating or 0)>0 and UI:ScoreText(record.requiredRating,record.ratingKind) or Say("不限","Any")
  else label,value=L.members,membersText end
  local metric=f.metrics[i];UI:SetText(metric.title,label);UI:SetText(metric.value,value);UI:Color(metric.value,raid and i==1 and (value=="—" and T.dim or T.good) or T.text)
  metric.title:ClearAllPoints();metric.value:ClearAllPoints();metric.title:SetWidth(0);metric.value:SetWidth(0)
  local titleWidth=metric.title:GetStringWidth();local valueWidth=metric.value:GetStringWidth()
  local cellWidth=raid and titleWidth+8+valueWidth or math.max(56,titleWidth,valueWidth)
  if metricX>0 and metricX+cellWidth>mainWidth then metricX=0;metricY=metricY+(raid and 28 or 54) end
  metric.title:SetPoint("TOPLEFT",metricX,-metricTop-metricY)
  metric.value:SetPoint("TOPLEFT",metricX+(raid and titleWidth+8 or 0),-metricTop-metricY-(raid and 0 or 22))
  metricX=metricX+cellWidth+(raid and 24 or 20);metricHeight=metricY+(raid and 20 or 42)
  metric.title:Show();metric.value:Show()
 end
 local top=metricTop+metricHeight+16
 if raid then
  f.composition:ClearAllPoints();f.composition:SetPoint("TOPLEFT",0,-top);f.composition:Update(details and details.members,details and details.counts,record.maxNumPlayers);f.composition:SetHeight(18);f.composition:Show();top=top+34
 else
  f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-top);f.comment:SetHeight(0);UI:Color(f.comment,T.muted);UI:SetText(f.comment,record.comment or "");top=top+(record.comment and record.comment~="" and f.comment:GetStringHeight()+16 or 0)
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
 if A.db.relations and details and details.relationships then
  local r=details.relationships;local lines={}
  if #r.bnet>0 then lines[#lines+1]=UI:Hex(T.blue)..L.friendBnet.."|r · "..table.concat(r.bnet,"、") end
  if #r.character>0 then lines[#lines+1]=UI:Hex(T.blue)..L.friendChar.."|r · "..table.concat(r.character,"、") end
  if #r.guild>0 then lines[#lines+1]=UI:Hex(T.good)..L.friendGuild.."|r · "..table.concat(r.guild,"、") end
  if #lines>0 then
   f.relations:SetWidth(mainWidth);f.relations:SetHeight(0);UI:SetText(f.relations,table.concat(lines,"\n"));f.relations:ClearAllPoints();f.relations:SetPoint("TOPLEFT",0,-top);f.relations:Show();top=top+f.relations:GetStringHeight()+12
  end
 end
 if expanded then
  local members=details and details.members or {}
  local ordered=members
  if raid then
   ordered=self.orderedMembers;wipe(ordered)
   for _,member in ipairs(members) do if member.isLeader or record.leaderKey and member.nameKey==record.leaderKey then leader=member;ordered[1]=member;break end end
   for pass=1,4 do for _,member in ipairs(members) do
    local role=member.assignedRole;local rank=role=="TANK" and 1 or role=="HEALER" and 2 or role=="DAMAGER" and 3 or 4
    if member~=leader and rank==pass then ordered[#ordered+1]=member end
   end end
  end
  self:EnsureMemberButtons(#ordered)
  local cols=raid and 3 or 1;local w=(mainWidth-(cols-1)*8)/cols
  local gridTop,gridHeight=top,0
  for i,member in ipairs(ordered) do
   local button=f.memberButtons[i]
   if button then
    self:BindMember(button,member,w);button.icon:SetSize(24,24)
    button.name:SetWordWrap(true);button.name:SetHeight(0);button.name:SetWidth(w-72);button.realm:SetWidth(w-72)
    if raid or member==leader then
     local key,name,realm=Identity(member)
     local isLeader=member==leader;local nameX=isLeader and 56 or 40
     button.leaderIcon:ClearAllPoints();button.leaderIcon:SetPoint("CENTER",button.name,"TOPLEFT",-10,-button.name:GetLineHeight()/2);button.leaderIcon:SetShown(isLeader);button.name:ClearAllPoints();button.name:SetPoint("TOPLEFT",nameX,-6);button.name:SetWidth(w-nameX-32);button.realm:SetWidth(w-72)
     UI:SetText(button.name,(name or member.name or L.unknown)..(realm and UI:Hex(T.muted).."-"..realm.."|r" or "")..NoteMark(key))
     UI:SetText(button.realm,MemberMeta(member))
     button.realm:ClearAllPoints();button.realm:SetPoint("TOPLEFT",40,-28);button.role:SetSize(16,16)
    else button.realm:ClearAllPoints();button.realm:SetPoint("TOPLEFT",40,-28);button.role:SetSize(16,16) end
    local nameHeight=math.max(T.listTitleLineHeight,button.name:GetStringHeight())
    button.realm:ClearAllPoints();button.realm:SetPoint("TOPLEFT",40,-10-nameHeight);button:SetHeight(math.max(60,nameHeight+button.realm:GetStringHeight()+16))
    button:ClearAllPoints();button:SetPoint("TOPLEFT",((i-1)%cols)*(w+8),-gridTop)
    gridHeight=math.max(gridHeight,button:GetHeight())
    if i%cols==0 or i==#ordered then gridTop=gridTop+gridHeight+(i==#ordered and 0 or 4);gridHeight=0 end
   end
  end
  top=gridTop
 end
 if raid then
  top=top+12;UI:SetText(f.footer,A.db.raidMembers=="always" and Say("点击成员查看详情","Click a member to view details") or (expanded and Say("按 Shift 收起名单 · 点击成员查看详情","Press Shift to collapse · Click a member for details") or Say("按 Shift 展开成员名单","Press Shift to expand the member list")));f.footer:ClearAllPoints();f.footer:SetPoint("TOPLEFT",0,-top);top=top+20
 else UI:SetText(f.footer,"") end
 if raid then
  local list=Bosses(record.activity);local bossTop=32
  f.bossTitle:ClearAllPoints();f.bossTitle:SetPoint("TOPLEFT",mainWidth+36,0);f.bossTitle:Show()
  local progress=UI:ProgressText(record,details)
  f.bossCount:ClearAllPoints();f.bossCount:SetPoint("TOPRIGHT",f.canvas,"TOPRIGHT",0,-2);UI:SetText(f.bossCount,progress);UI:Color(f.bossCount,progress=="—" and T.dim or T.good);f.bossCount:SetShown(progress~="—")
  if list and #list>0 and details and details.encounters then
   for index,name in ipairs(list) do
    local row=f.bossRows[index]
    if not row then
     row=CreateFrame("Frame",nil,f.canvas);row:SetWidth(168)
     row.name=C.Text(row,"",14,T.muted,110);C.SetLineHeight(row.name,22);row.name:SetWordWrap(true);row.name:SetPoint("LEFT",0,0)
     row.status=C.Text(row,"",14,T.dim,72);C.SetLineHeight(row.status,22,true);row.status:SetJustifyH("RIGHT");row.status:SetPoint("RIGHT",0,0)
     f.bossRows[index]=row
    end
    local defeated=false
    for _,completed in ipairs(details and details.encounters or {}) do if completed==name then defeated=true;break end end
    UI:SetText(row.name,name)
    UI:SetText(row.status,details and details.encounters and (defeated and Say("已击败","Defeated") or Say("未击败","Not defeated")) or L.unknown)
    row.status:SetWidth(0);row.name:SetWidth(168-12-row.status:GetStringWidth())
    UI:Color(row.status,defeated and T.good or T.dim)
    local height=math.max(36,row.name:GetStringHeight()+16)
    row:SetHeight(height);row:ClearAllPoints();row:SetPoint("TOPLEFT",mainWidth+36,-bossTop);row:Show();bossTop=bossTop+height
   end
  else
   local missing=list and #list>0 and Say("队伍未提供首领进度","This group has not provided boss progress") or Say("暂无首领目录","Boss directory unavailable")
   f.bossText:ClearAllPoints();f.bossText:SetPoint("TOPLEFT",mainWidth+36,-32);f.bossText:SetWidth(168);UI:SetText(f.bossText,missing);f.bossText:Show()
   bossTop=30+f.bossText:GetStringHeight()
  end
  top=math.max(top,bossTop+4)
 end
 self:Place(top)
end
function Tip:ShowPlayer(owner,member)
 if self.pinned then return end
 self.record,self.details,self.sourceApp=nil,nil,nil;self:ResetInteractive(owner,376);self:RenderPlayer(member,false)
end
local function NoteHeader(f,note,top)
 local color=note.type=="positive" and T.good or note.type=="caution" and T.warning or T.muted
 f.noteDivider:ClearAllPoints();f.noteDivider:SetPoint("TOPLEFT",0,-top);f.noteDivider:SetWidth(f.canvas:GetWidth());f.noteDivider:Show()
 f.noteHeading:ClearAllPoints();f.noteHeading:SetPoint("TOPLEFT",24,-top-17);UI:SetText(f.noteHeading,L.notes.." · "..(L.types and L.types[note.type] or L.notes));UI:Color(f.noteHeading,color);f.noteHeading:Show()
 f.noteGlyph:SetTexture(T.media..(note.type=="positive" and "heart" or note.type=="caution" and "caution" or "book")..".tga");f.noteGlyph:SetColor(color);f.noteGlyph:ClearAllPoints();f.noteGlyph:SetPoint("TOPLEFT",0,-top-19);f.noteGlyph:Show()
 f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",0,-top-45);f.comment:SetHeight(0);UI:Color(f.comment,T.text);UI:SetText(f.comment,note.reason~="" and note.reason or L.noReason)
 local dateTop=top+45+math.max(22,f.comment:GetStringHeight())+8
 f.noteDate:ClearAllPoints();f.noteDate:SetPoint("TOPLEFT",0,-dateTop);f.noteDate:SetWidth(f.canvas:GetWidth());UI:SetText(f.noteDate,(note.classSpec and note.classSpec~="" and note.classSpec.." · " or "")..UI:DateText(note.timestamp));f.noteDate:Show()
 return dateTop+math.max(18,f.noteDate:GetStringHeight())
end
function Tip:ShowNote(owner,key)
 if self.pinned then return end
 local note=A.Notes:Find(key);if not note then return end
 self.record,self.member,self.details,self.sourceApp=nil,nil,nil,nil
 local f=self:ResetInteractive(owner,424)
 f.icon:Hide();f.subtitle:Hide();f.summary:Hide();f.leader:Hide()
 f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT");f.title:SetWidth(f.canvas:GetWidth());UI:SetText(f.title,note.name.."-"..note.server)
 local top=NoteHeader(f,note,math.max(24,f.title:GetStringHeight())+16)+12
 f.footer:ClearAllPoints();f.footer:SetPoint("TOPLEFT",0,-top);UI:SetText(f.footer,Say("点击编辑记录。","Click to edit this note."));self:Place(top+20)
end
function Tip:RenderPlayer(member,fromGroup,adjustPoint)
 self.member=member;self.pinned=fromGroup==true;self.adjustPoint=adjustPoint==true
 local f=self:ResetInteractive(nil,376);f:UnregisterEvent("MODIFIER_STATE_CHANGED")
 local key,name,realm=Identity(member)
 local top=fromGroup and 42 or 0
 f.back:SetShown(fromGroup==true);f.back:ClearAllPoints();f.back:SetPoint("TOPLEFT");f.back:SetWidth(f.back.label:GetStringWidth()+22)
 local identityWidth=f.canvas:GetWidth()-84
 f.title:ClearAllPoints();f.title:SetPoint("TOPLEFT",52,-top);f.title:SetWidth(identityWidth);UI:SetText(f.title,name or member.name or L.unknown);f.title:SetTextColor(UI:ClassColor(member.class));f.title._color=nil
 local titleHeight=math.max(24,f.title:GetStringHeight())
 f.subtitle:ClearAllPoints();f.subtitle:SetPoint("TOPLEFT",52,-top-titleHeight);f.subtitle:SetWidth(identityWidth);UI:SetText(f.subtitle,realm or member.realm or L.unknown)
 local headerHeight=math.max(40,titleHeight+math.max(18,f.subtitle:GetStringHeight()))
 f.icon:ClearAllPoints();f.icon:SetPoint("TOPLEFT",0,-top-(headerHeight-40)/2);UI:SetMemberIcon(f.icon,member)
 f.playerRole:ClearAllPoints();f.playerRole:SetPoint("TOPRIGHT",0,-top-(headerHeight-20)/2);UI:SetRoleIcon(f.playerRole,member.assignedRole);f.playerRole:Show()
 local className=member.localizedClass
 if not className and member.class then for classID=1,GetNumClasses() do local name,token=GetClassInfo(classID);if token==member.class then className=name;break end end end
 local specName=UI:SpecName(member)
 local summaryTop=top+headerHeight+12
 local relation=MemberRelations(member)
 f.summary:ClearAllPoints();f.summary:SetPoint("TOPLEFT",0,-summaryTop);UI:SetText(f.summary,(className or L.unknown)..(specName and " · "..specName or "")..(relation~="" and " · "..relation or ""))
 local metricTop=summaryTop+math.max(20,f.summary:GetStringHeight())+16
 local x=0
 local rating,ratingKind,ratingActivity=UI:MemberRating(member)
 for i,label in ipairs({ratingKind=="pvp" and Say("PvP 装等","PvP item level") or L.itemLevel,ratingKind=="pvp" and (ratingActivity or Say("PvP 评分","PvP rating")) or L.rating}) do
  local metric=f.metrics[i];metric.title:ClearAllPoints();metric.value:ClearAllPoints();metric.title:SetWidth(0);metric.value:SetWidth(0)
  UI:SetText(metric.title,label)
  if i==2 then UI:SetScore(metric.value,rating,ratingKind) else UI:SetText(metric.value,member.itemLevel and math.floor(member.itemLevel) or "—");UI:Color(metric.value,T.text) end
  metric.title:SetPoint("TOPLEFT",x,-metricTop);metric.value:SetPoint("TOPLEFT",x,-metricTop-22);metric.title:Show();metric.value:Show();x=x+math.max(56,metric.title:GetStringWidth(),metric.value:GetStringWidth())+20
 end
 f.leader:Hide()
 local note=key and A.Notes and A.Notes:Find(key)
 if note then top=NoteHeader(f,note,metricTop+42+16)+20 else f.comment:Hide();top=metricTop+42+20 end
 f.wcl:ClearAllPoints();f.wcl:SetPoint("TOPLEFT",0,-top);f.wcl:SetWidth(f.wcl.label:GetStringWidth()+24);f.wcl:SetShown(name~=nil and realm~=nil and realm~="")
 f.note:ClearAllPoints();f.note:SetPoint("TOPRIGHT",0,-top);UI:SetText(f.note.label,note and Say("编辑笔记","Edit note") or L.record);f.note:SetWidth(f.note.label:GetStringWidth()+24);f.note:SetShown(not UI.preview and key~=nil)
 UI:SetText(f.footer,"");self:Place(top+40)
end
function Tip:LeaveOwner(owner)
 if self.pinned then return end
 if owner and owner~=self.owner then return end
 if not self.interactive or not self.interactive:IsShown() then self:Hide();return end
 local elapsed=0
 UI.Motion:Start(self,function(dt)
  elapsed=elapsed+dt;if elapsed<.22 then return end
  local area=self.owner and (self.owner.tooltipArea or self.owner)
  if not self.interactive:IsMouseOver() and not (area and area:IsMouseOver()) then self:Hide() end
  return true
 end)
end

