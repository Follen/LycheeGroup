-- Shared LycheeUI visuals; the LycheeGroup UI/business pages stay unloaded until opened.
local A=_G.LycheeGroup
local F={};A.Floating=F
local zh
local C,T
local MEMBER_TEXT_X,MEMBER_TEXT_WIDTH,MEMBER_METRIC_WIDTH=56,168,76
local MEMBER_NAME_SIZE,MEMBER_NAME_LINE,MEMBER_META_SIZE,MEMBER_META_LINE=16,22,12,16
local MEMBER_FACTION_SIZE,MEMBER_FACTION_GAP=16,6
local factionTextures={Alliance="Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-alliance.tga",Horde="Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-horde.tga"}
local entries,tops,batchEntries,boundBatches={},{},{},{}
local fadeState,scrollState,cancelIDs,exits={},{},{},{}
local entryCount=0
local function AddEntry(top,height)
 entryCount=entryCount+1
 local entry=entries[entryCount]
 if entry then wipe(entry) else entry={};entries[entryCount]=entry end
 entry.height=height;tops[entryCount]=top
 return entry
end
local function TrimEntries(used,batches)
 for i=#entries,used+1,-1 do wipe(entries[i]);entries[i]=nil;tops[i]=nil end
 for i=#batchEntries,batches+1,-1 do wipe(batchEntries[i]);batchEntries[i]=nil end
end
local function ReleaseEntries()
 -- Keep only empty shells bounded by the visible native pools, not a past roster.
 TrimEntries(#F.rows,#F.batches)
 for _,entry in ipairs(entries) do wipe(entry) end
 for _,batch in ipairs(batchEntries) do wipe(batch) end
 wipe(tops);wipe(boundBatches)
end
local function Waiting(app) return A.Group.Applications:IsActive(app.id) and app.status~="invited" and (app.status=="applied" or app.pendingStatus=="applied") end
local function Operable(app) return app.status=="applied" and not app.pendingStatus and not app.acting end
local function Text(parent,size,width)
 return C.Text(parent,"",size,T.text,width,size==18 and 24 or size==16 and 22 or 20)
end
local function MemberIcon(texture,member,icon)
 if icon then F.context:SetGameTexture(texture,icon);return end
 local coords=member.class and CLASS_ICON_TCOORDS[member.class]
 if coords then F.context:SetGameTexture(texture,"Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",unpack(coords))
 else F.context:SetGameTexture(texture,"Interface\\Icons\\INV_Misc_QuestionMark") end
end
local function ColorScore(t,score,kind)
 if type(score)~="number" or score<0 then t:SetText(zh and "未知分数" or "Unknown");t:SetTextColor(unpack(T.muted))
 elseif score==0 then t:SetText(zh and "暂无分数" or "Unrated");t:SetTextColor(unpack(T.muted))
 elseif kind=="pvp" then t:SetText(math.floor(score));t:SetTextColor(unpack(T.text))
 else t:SetText(math.floor(score));local c=C_ChallengeMode.GetDungeonScoreRarityColor(score);t:SetTextColor(c.r,c.g,c.b) end
end
function F:HoverRow(row,inside)
 if row.exit then return end
 local card=row.batch or row
 if row.application or row.batch then card.background:SetHovered(inside or card:IsMouseOver()) end
end
function F:Build()
 if self.frame then return end
 zh=A:GetLocale()=="zhCN"
 self.context=_G.LycheeUI:CreateContext({font=A.Fonts:GetPath(),reducedMotion=function() return A.db.reduceMotion end})
 C,T=self.context.C,self.context.Theme
 local f=CreateFrame("Frame","LycheeGroupFloating",UIParent);f:SetSize(80,44);f:SetFrameStrata("MEDIUM");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(false);self.frame=f
 local button=CreateFrame("Button",nil,f);button:SetSize(80,44)
 button:SetScript("OnClick",function()
  if F.dragging or F.dragClick then F.dragClick=nil;return end
  A:Open(F.recruiting and "create" or "find")
 end)
 button:SetPoint("TOPLEFT");button:RegisterForDrag("LeftButton");self.button=button
 local logoAnchor=CreateFrame("Frame",nil,button);logoAnchor:SetSize(38,38);logoAnchor:SetPoint("LEFT",8,0);logoAnchor:EnableMouse(false);self.logoAnchor=logoAnchor
 local art=logoAnchor:CreateTexture(nil,"ARTWORK");art:SetTexture(T.media.."lychee-logo.tga");art:SetTexCoord(0,1,0,1);art:SetSize(38,38);art:SetPoint("CENTER",logoAnchor,"CENTER",0,0);self.logoTexture=art
 self.context.logo,self.context.logoButton=art,logoAnchor;T.logoSize=38
 self.count=Text(button,16,18);self.count:SetPoint("LEFT",logoAnchor,"RIGHT",4,0);self.count:SetJustifyH("CENTER");self.count:SetWordWrap(false);C.SetLineHeight(self.count,22,true)
 self.ownCount=self.count
 button:HookScript("OnMouseDown",function(_,key) if key=="LeftButton" then F.dragClick=nil end end)
 button:SetScript("OnDragStart",function() if not A.db.floatingLocked then F.dragging=true;F.dragClick=true;F.frame:StartMoving();F:Dismiss() end end)
 button:SetScript("OnDragStop",function()
  if not F.dragging then return end
  F.frame:StopMovingOrSizing();F.dragging=nil
  if not F.standaloneTest then local point,_,relativePoint,x,y=F.frame:GetPoint();A.db.floatingPosition={point=point,relativePoint=relativePoint,x=x,y=y} end
 end)
 local panel=CreateFrame("Frame",nil,f);panel:SetSize(348,220);panel:SetPoint("BOTTOMLEFT",f,"TOPLEFT",0,8);panel:SetFrameStrata("DIALOG");panel:EnableMouse(true);panel:Hide();self.panel=panel
 panel:SetScript("OnShow",function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
 panel:SetScript("OnEvent",function()
  if not F:GetAnchor():IsMouseOver() and not F.panel:IsMouseOver() then F:Dismiss() end
 end)
 panel:SetScript("OnHide",function(self)
  self:UnregisterEvent("GLOBAL_MOUSE_DOWN");F:CancelHide()
  if A.Group then A.Group:SetApplicantView(F,false) end
  if F.countdown then F.countdown:Cancel();F.countdown=nil end
  local resumeBrand=F.attention and F.context.Motion.jobs.brand~=nil
  F.context.Motion:StopAll();if resumeBrand then F:PlayAttention() end
  F.entries=nil;F.entryTops=nil;F.boundVersion=nil;F.fade=nil;F.cardElapsed=nil;F.scrollTween=nil;wipe(exits);F:UpdateDriver();ReleaseEntries()
  for _,row in ipairs(F.rows) do
   row.exit=nil;row.exitAlpha=nil;row.exitTop=nil;row:EnableMouse(true)
   row.faction:Hide();row.faction:SetTexture(nil)
   row.application=nil;row.applicantID=nil;row.applicationID=nil;row.batch=nil;row.pressedTarget=nil;row.invite.applicantID=nil;row.invite.pressedTarget=nil;row.decline.applicantID=nil;row.decline.pressedTarget=nil;row.cancel.applicationID=nil;row.cancel.pressedTarget=nil
  end
  for _,batch in ipairs(F.batches) do batch.exit=nil;batch.exitAlpha=nil;batch.exitTop=nil;batch:EnableMouse(true);batch.applicantID=nil;batch.background:Hide();batch:Hide() end
 end)
 local cancel=C.Button(panel,"",160,nil,{variant="text",height=24});cancel:SetPoint("TOPRIGHT",-24,-4);cancel.label:ClearAllPoints();cancel.label:SetPoint("RIGHT");self.cancel=cancel
 cancel:HookScript("OnEnter",function() F:CancelHide() end)
 cancel:HookScript("OnLeave",function() F:ScheduleHide() end)
 cancel:SetScript("OnClick",function()
  local g=A.Group;if not g then return end
  if F.recruiting then local ok,err=g:RemoveListing();if not ok then A:Print(err) end
  else wipe(cancelIDs);for _,app in ipairs(g:GetApplications()) do if Waiting(app) then cancelIDs[#cancelIDs+1]=app.id end end;for _,id in ipairs(cancelIDs) do local ok,err=g:Cancel(id);if not ok then A:Print(err) end end;wipe(cancelIDs) end
 end)
 self.scroll=CreateFrame("ScrollFrame",nil,panel);self.scroll:SetSize(324,252);self.scroll:SetPoint("TOPLEFT",12,-48)
 self.body=CreateFrame("Frame",nil,self.scroll);self.body:SetSize(324,1);self.scroll:SetScrollChild(self.body)
 self.scroll:EnableMouseWheel(true);self.scroll:SetScript("OnMouseWheel",function(s,d) F:SetOffset(math.max(0,math.min(s:GetVerticalScrollRange(),(F.scrollTween and F.scrollTween.to or s:GetVerticalScroll())-d*44)),true) end)
 self.scrollBar=C.ScrollBar(panel);self.scrollBar:SetHeight(252);self.scrollBar:SetPoint("TOPRIGHT",-14,-46)
 self.thumb=self.scrollBar.thumb
 self.scrollBar:SetScript("OnValueChanged",function(_,value) if not F.syncScroll then F:SetOffset(value,false) end end)
 self.batches={};self.CreateBatch=function(self)
  local i=#self.batches+1;local batch=CreateFrame("Button",nil,self.body);batch:SetWidth(324);batch.background=C.Surface(batch,{variant="floating"});batch.background:Hide()
  batch:SetScript("OnEnter",function() if batch.exit then return end;F:CancelHide();batch.background:SetHovered(true) end)
  batch:SetScript("OnLeave",function() batch.background:SetHovered(batch:IsMouseOver());F:ScheduleHide() end)
  batch:SetScript("OnClick",function() if batch.applicantID and not batch.exit then A:Open("create",{applicantID=batch.applicantID}) end end)
  batch:Hide();self.batches[i]=batch;return batch
 end
 self.rows={};self.CreateRow=function(self)
  local i=#self.rows+1
  local row=CreateFrame("Button",nil,self.body);row:SetSize(324,48);row:SetFrameLevel(self.body:GetFrameLevel()+3)
  row.background=C.Surface(row,{variant="floating"});row.background:Hide()
  row.icon=C.GameIcon(row,24);row.icon:SetPoint("TOPLEFT",12,-10);row.icon:SetTexCoord(.06,.94,.06,.94)
  row.name=Text(row,T.listTitleSize,180);row.name:SetPoint("TOPLEFT",40,-7);row.name:SetWordWrap(false)
  row.faction=C.Icon(row,MEMBER_FACTION_SIZE);row.faction:Hide()
  row.meta=Text(row,14,180);row.meta:SetPoint("TOPLEFT",40,-29);row.meta:SetTextColor(unpack(T.muted));row.meta:SetWordWrap(false)
  row.score=Text(row,14,64);row.score:SetPoint("RIGHT",-7,0);row.score:SetJustifyH("RIGHT")
  row.itemLevel=Text(row,14,76);C.SetLineHeight(row.itemLevel,20,true);row.itemLevel:SetPoint("TOPRIGHT",-8,-28);row.itemLevel:SetJustifyH("RIGHT");row.itemLevel:SetTextColor(unpack(T.muted))
  row.leader=Text(row,14,196);C.SetLineHeight(row.leader,20);row.leader:SetPoint("TOPLEFT",40,-49);row.leader:SetWordWrap(false)
  row.timer=Text(row,14,56);C.SetLineHeight(row.timer,20,true);row.timer:SetPoint("TOPRIGHT",-4,-53);row.timer:SetJustifyH("RIGHT");row.timer:SetTextColor(unpack(T.muted))
  local function DecisionButton(x,method)
   local button=C.IconButton(row,nil,32,nil,{iconSize=18,hoverColor=method=="Invite" and T.positiveHover or T.negativeHover,pressedColor=method=="Invite" and T.positivePressed or T.negativePressed});button:SetPoint("TOPRIGHT",x,-1)
   button.glyph=button.icon;button.glyph:SetTexture(T.media..(method=="Invite" and "invite.tga" or "decline.tga"))
   button:HookScript("OnEnter",function() F:CancelHide();F:HoverRow(row,true) end);button:HookScript("OnLeave",function() F:HoverRow(row,false);F:ScheduleHide() end)
   button:HookScript("OnMouseDown",function(self) self.pressedTarget=self.applicantID end)
   button:SetScript("OnClick",function(self)
    if not self:IsEnabled() or row.exit then return end
    if self.pressedTarget and self.pressedTarget~=self.applicantID then self.pressedTarget=nil;return end;self.pressedTarget=nil
    local id=self.applicantID;local app=id and A.Group:GetApplicant(id)
    if not app or not Operable(app) or not A.Group:CanManageApplicants() then return end
    -- Freeze the current binding before Act's synchronous notification. The
    -- native operation stays in this hardware callback, never in the animation.
    F:BeginDecision(id)
    local ok,err=A.Group[method](A.Group,id)
    if not ok then F:FinishDecision(id,false);A:Print(err)
    elseif A.db.reduceMotion then F:FinishDecision(id,true)
    else F:UpdateDriver() end
   end)
   return button
  end
  row.invite=DecisionButton(-29,"Invite");row.invite:Hide()
  row.decline=DecisionButton(-7,"Decline");row.decline:Hide()
  row.cancel=C.Button(row,"",32,nil,{height=32,hoverColor=T.negativeHover,pressedColor=T.negativePressed});row.cancel.label:Hide();row.cancel:SetPoint("TOPRIGHT",-12,-12);row.cancel:Hide()
  local cross=C.Glyph(row.cancel,"close",16);cross:SetPoint("CENTER");cross:SetColor(T.dim)
  row.cancel:HookScript("OnEnter",function() F:CancelHide();F:HoverRow(row,true);cross:SetColor(T.brand) end)
  row.cancel:HookScript("OnLeave",function() cross:SetColor(T.dim);F:HoverRow(row,false);F:ScheduleHide() end)
  row.cancel:HookScript("OnHide",function() cross:SetColor(T.dim) end)
  row.cancel:HookScript("OnMouseDown",function(self) self.pressedTarget=self.applicationID end)
  row.cancel:SetScript("OnClick",function(self)
   if self.pressedTarget and self.pressedTarget~=self.applicationID then self.pressedTarget=nil;return end;self.pressedTarget=nil
   local id=self.applicationID;local app=id and A.Group:GetApplication(id)
   if not app or not Waiting(app) or app.pendingStatus then return end
   local ok,err=A.Group:Cancel(id);if ok then self:SetEnabled(false) else A:Print(err) end
  end)
  row:SetScript("OnMouseDown",function(r) r.pressedTarget=r.applicantID or r.applicationID end)
  row:SetScript("OnClick",function(r) if r.exit then return end;if r.pressedTarget and r.pressedTarget~=(r.applicantID or r.applicationID) then r.pressedTarget=nil;return end;r.pressedTarget=nil;if r.applicantID then A:Open("create",{applicantID=r.applicantID}) elseif r.applicationID then A:Open("find",{applicationID=r.applicationID}) end end)
  row:SetScript("OnEnter",function() F:CancelHide();F:HoverRow(row,true) end);row:SetScript("OnLeave",function() F:HoverRow(row,false);F:ScheduleHide() end);row:Hide();self.rows[i]=row;return row
 end
 for i=1,14 do self:CreateRow();self:CreateBatch() end
 self.emptyCard=CreateFrame("Frame",nil,panel);self.emptyCard:SetSize(324,44);self.emptyCard:SetPoint("TOPLEFT",12,-48)
 self.emptyCard.background=C.Surface(self.emptyCard,{variant="floating"})
 self.empty=Text(self.emptyCard,14,292);self.empty:SetPoint("CENTER");self.empty:SetJustifyH("CENTER");self.empty:SetWordWrap(false);C.SetLineHeight(self.empty,20,true);self.empty:SetTextColor(unpack(T.muted))
 self.measure=Text(panel,14,300);self.measure:SetWordWrap(true);self.measure:Hide();self.empty:SetText(zh and "暂无申请" or "No applications")
 button:HookScript("OnEnter",function() F:ShowPanel() end);button:HookScript("OnLeave",function() F:ScheduleHide() end)
 f:SetScript("OnShow",function() F:Update() end)
 f:SetScript("OnHide",function()
  if F.dragging then F.frame:StopMovingOrSizing();F.dragging=nil end
  F.dragClick=nil;F:SetAttention(false);F:Dismiss();F.context.Motion:StopAll()
 end)
 panel:SetScript("OnEnter",function() F:CancelHide() end);panel:SetScript("OnLeave",function() F:ScheduleHide() end)
 f:RegisterEvent("DISPLAY_SIZE_CHANGED");f:RegisterEvent("UI_SCALE_CHANGED");f:SetScript("OnEvent",function() F:UpdateSettings() end)
 self:ResetPosition(true)
end
function F:PlayAttention()
 if self.attentionTimer then self.attentionTimer:Cancel() end
 self.context.Motion:Brand()
 self.attentionTimer=C_Timer.NewTimer(2.4,function()
  F.attentionTimer=nil;if F.attention then F:PlayAttention() end
 end)
end
function F:SetAttention(enabled)
 enabled=enabled and self:GetAnchor():IsVisible() and not A.db.reduceMotion or false
 if self.attention==enabled then return end
 self.attention=enabled
 if enabled then self:PlayAttention()
 else
  if self.attentionTimer then self.attentionTimer:Cancel();self.attentionTimer=nil end
  self.context.Motion:StopBrand()
 end
end
-- Only active panel fades, decisions and scrolls use this driver.
local function Drive(_,elapsed) F:Tick(elapsed,F.startedAt and GetTimePreciseSec() or nil) end
function F:UpdateDriver()
 local running=self.fade~=nil or self.cardElapsed~=nil or self.scrollTween~=nil or next(exits)~=nil
 if self.running==running then return end
 self.running=running
 self.startedAt=running and GetTimePreciseSec() or nil
 self.frame:SetScript("OnUpdate",running and Drive or nil)
end
local function PositionCard(card,elapsed)
 local exit=card.exit
 if exit then
  local p=1-(1-math.min(1,exit.elapsed/.14))^3
  card:SetAlpha(card.exitAlpha*(1-p));card:SetPoint("TOPLEFT",0,card.exitTop+6*p)
  return
 end
 local p=not elapsed and 1 or math.max(0,math.min(1,(elapsed-math.min(3,(card.cardOrder or 1)-1)*.018)/.17))
 p=1-(1-p)^3;card:SetAlpha(p);card:SetPoint("TOPLEFT",0,-card.baseTop-6*(1-p))
end
function F:ApplyCardMotion(elapsed)
 for _,batch in ipairs(self.batches) do if batch:IsShown() then PositionCard(batch,elapsed) end end
 for _,row in ipairs(self.rows) do if row:IsShown() then PositionCard(row,elapsed) end end
end
local function BindExit(card,state)
 card.exit=state;card.exitAlpha=card:GetAlpha();card.exitTop=-card.baseTop-6*(1-card.exitAlpha);card:EnableMouse(false)
end
function F:BeginDecision(id)
 local state={elapsed=0};exits[id]=state
 self:CancelHide();self.scrollTween=nil
 for _,row in ipairs(self.rows) do if row:IsShown() and row.applicantID==id then
  BindExit(row,state);row.invite:SetEnabled(false);row.decline:SetEnabled(false);row.invite:RefreshStyle(true);row.decline:RefreshStyle(true)
 end end
 for _,batch in ipairs(self.batches) do if batch:IsShown() and batch.applicantID==id then BindExit(batch,state) end end
end
function F:FinishDecision(id,hide)
 local state=exits[id];if not state then return end;exits[id]=nil
 for _,row in ipairs(self.rows) do if row.exit==state then row.exit=nil;row.exitAlpha=nil;row.exitTop=nil;row:EnableMouse(true);if hide then row:Hide() end end end
 for _,batch in ipairs(self.batches) do if batch.exit==state then batch.exit=nil;batch.exitAlpha=nil;batch.exitTop=nil;batch:EnableMouse(true);if hide then batch:Hide() end end end
 if not next(exits) and self.panel:IsShown() then self:ShowPanel() end
 self:UpdateDriver()
end
function F:Fade(show)
 if not show and not self.panel:IsShown() then return end
 if show and not self.panel:IsShown() then self.panel:SetAlpha(A.db.reduceMotion and 1 or 0);self.panel:Show();self.cardElapsed=not A.db.reduceMotion and 0 or nil;self:ApplyCardMotion(self.cardElapsed) end
 local target=show and 1 or 0
 if self.fade and self.fade.to==target then return end
 if not show then self.scrollTween=nil end
 if A.db.reduceMotion then self.fade=nil;self.cardElapsed=nil;self.panel:SetAlpha(target);self:ApplyCardMotion();if not show then self.panel:Hide() end
 elseif math.abs(self.panel:GetAlpha()-target)>.001 then fadeState.from,fadeState.to,fadeState.elapsed=self.panel:GetAlpha(),target,0;self.fade=fadeState
 else self.fade=nil;if not show then self.panel:Hide() end end
 self:UpdateDriver()
end
function F:SetOffset(value,animate)
 if next(exits) then return end
 local current=self.scroll:GetVerticalScroll()
 if value==current then self.scrollTween=nil;self:UpdateDriver();return end
 if animate and not A.db.reduceMotion then scrollState.from,scrollState.to,scrollState.elapsed=current,value,0;self.scrollTween=scrollState
 else self.scrollTween=nil;self.scroll:SetVerticalScroll(value);self.syncScroll=true;self.scrollBar:SetValue(value);self.syncScroll=nil;self:Render() end
 self:UpdateDriver()
end
function F:Tick(elapsed,now)
 if self.startedAt then if now then elapsed=math.max(0,math.min(elapsed,now-self.startedAt)) end;self.startedAt=nil end
 for _,exit in pairs(exits) do exit.elapsed=exit.elapsed+elapsed end
 local scroll=self.scrollTween
 if scroll then
  scroll.elapsed=scroll.elapsed+elapsed;local p=A.db.reduceMotion and 1 or math.min(1,scroll.elapsed/.12);local eased=1-(1-p)^3
  local value=scroll.from+(scroll.to-scroll.from)*eased;self.scroll:SetVerticalScroll(value);self.syncScroll=true;self.scrollBar:SetValue(value);self.syncScroll=nil;self:Render()
  if p==1 then self.scrollTween=nil end
 end
 local fade=self.fade
 if fade then
  fade.elapsed=fade.elapsed+elapsed;local p=A.db.reduceMotion and 1 or math.min(1,fade.elapsed/(fade.to==1 and .17 or .11));self.panel:SetAlpha(fade.from+(fade.to-fade.from)*(1-(1-p)^3))
  if A.db.reduceMotion or fade.elapsed>=(fade.to==1 and .17 or .11) then self.fade=nil;if fade.to==0 then self.panel:Hide() end end
 end
 local hadCardMotion=self.cardElapsed~=nil
 if hadCardMotion then
  self.cardElapsed=self.cardElapsed+elapsed
  if A.db.reduceMotion or self.cardElapsed>=.224 then self.cardElapsed=nil end
 end
 if hadCardMotion or next(exits) then self:ApplyCardMotion(self.cardElapsed) end
 if next(exits) then
  for id,exit in pairs(exits) do if A.db.reduceMotion or exit.elapsed>=.14 then self:FinishDecision(id,true) end end
 end
 self:UpdateDriver()
end
function F:CancelHide() if self.hideTask then self.hideTask:Cancel();self.hideTask=nil end end
function F:Dismiss() self:CancelHide();if self.panel then self.panel:Hide() end end
function F:ScheduleHide()
 if not self.panel:IsShown() then return end
 self:CancelHide();self.hideTask=C_Timer.NewTimer(.12,function() F.hideTask=nil;if not F:GetAnchor():IsMouseOver() and not F.panel:IsMouseOver() then F:Fade(false) end end)
end
function F:GetAnchor() return self.host or self.frame end
function F:LayoutEntry()
 if self.host then
  self.frame:SetSize(self.host:GetWidth(),self.host:GetHeight())
  self.logoAnchor:SetPoint("RIGHT",self.count,"LEFT",-4,0)
 else
  local countWidth=math.max(18,math.ceil(self.count:GetUnboundedStringWidth()))
  self.count:SetWidth(countWidth)
  local width=math.max(80,58+countWidth)
  self.frame:SetSize(width,44);self.button:SetWidth(width)
  self.logoAnchor:SetPoint("LEFT",8,0)
 end
 self.panel:SetScale(A.db.floatingScale/100*UIParent:GetEffectiveScale()/self.frame:GetEffectiveScale())
end
-- The public API supplies an existing mouse target; the same logo and list
-- move with it. The adapter keeps ownership of that target's clicks.
function F:SetHost(host,logoSize,count)
 count=count or self.ownCount
 local changed=self.host~=host or self.count~=count
 logoSize=host and logoSize or 38
 local resized=T.logoSize~=logoSize
 if changed or resized then self:SetAttention(false) end
 if changed then
  self:Dismiss();self.host=host;self.count=count;self.lastCount=nil;self.popupBounds=nil
  self.frame:ClearAllPoints();self.frame:SetParent(host or UIParent)
  self.frame:SetClampedToScreen(host==nil)
  self.logoAnchor:ClearAllPoints();self.logoAnchor:SetParent(host and self.frame or self.button)
  self.button:SetShown(host==nil)
  if host then self.frame:SetPoint("CENTER",host,"CENTER",0,0) else self:ResetPosition(true) end
 end
 if host and self.statusText then self.count:SetText(self.statusText) end
 if resized then
  T.logoSize=logoSize;self.logoAnchor:SetSize(logoSize,logoSize);self.context.Motion:StopBrand()
 end
 self.frame:SetScale(host and 1 or A.db.floatingScale/100)
 self:LayoutEntry()
 if changed or resized then self:Update()
 elseif self.panel:IsShown() then self:LayoutPanel();self:Render() end
end
function F:ResetPosition(restore)
 if self.host then return end
 if self.standaloneTest then self.frame:ClearAllPoints();self.frame:SetPoint("CENTER",UIParent,"CENTER",0,0);return end
 local p=restore and A.db.floatingPosition
 self.frame:ClearAllPoints();if p then self.frame:SetPoint(p.point,UIParent,p.relativePoint,p.x,p.y) else self.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",25.660334,-2.884586) end
end
function F:Bind(group)
 if self.unsub then return end
 self.unsub=group:Subscribe(function(kind) if kind=="applications" or kind=="applicants" or kind=="applicant" or kind=="listing" or kind=="permissions" then F:Update() end end)
 self:Update()
end
function F:UpdateSettings()
 local enabled=A.db.floating or self.standaloneTest
 if not self.frame then if not enabled then self:PublishStatus();return end;self:Build();if not self.frame then return end end
 self.frame:SetScale(self.host and 1 or A.db.floatingScale/100);self:LayoutEntry();self.frame:SetShown(enabled==true)
 if not enabled then self.panel:Hide();self.entries=nil;self:CancelHide() end
 self:Update()
end
function F:ToggleStandaloneTest()
 self:Dismiss();self.standaloneTest=not self.standaloneTest
 self:UpdateSettings();self:ResetPosition(true)
 if self.standaloneTest then self:ShowPanel() end
 return self.standaloneTest
end
function F:ApplyFont(path)
 if not self.frame then return end
 T.font=path;A.Fonts:ApplyTree(self.frame,path)
 self.lastCount=nil;self:Update()
end
function F:Update()
 if not self.frame or not (A.db.floating or self.standaloneTest) then self:PublishStatus();return end
 local group=A.Group;self.recruiting=group and group:GetListing()~=nil
 local count=0
 if group then
  if self.recruiting then for _,id in ipairs(group:GetApplicants()) do local app=group:GetApplicant(id);if Operable(app) then count=count+#app.members end end else for _,app in ipairs(group:GetApplications()) do if Waiting(app) then count=count+1 end end end
 end
 local idle=not self.recruiting and (not group or group.Applications:GetActiveCount()==0)
 if self.lastCount~=count or self.lastRecruiting~=self.recruiting or self.lastIdle~=idle then
  self.statusText=idle and (zh and "荔枝组队" or "Lychee LFG") or count==0 and (zh and "暂无申请" or "No applications") or (self.recruiting and (zh and "%d人申请" or "%d applicants") or (zh and "申请%d个" or "Applied: %d")):format(count)
  self.count:SetText(self.statusText)
  self:LayoutEntry();self.lastCount,self.lastRecruiting,self.lastIdle=count,self.recruiting,idle
 end
 self:SetAttention(self.recruiting and count>0)
 if self.panel:IsShown() then self:ShowPanel() end
 self:PublishStatus()
end
function F:ShowPanel()
 if self.dragging or not (A.db.floating or self.standaloneTest) or not self:GetAnchor():IsVisible() or next(exits) then return end
 local hadEntries=self.entries and #self.entries>0
 self:CancelHide();entryCount=0;self.entries,self.entryTops=entries,tops
 self.entriesVersion=(self.entriesVersion or 0)+1
 local group=A.Group;local total=0;local pending=false;local batchCount=0;local now=GetTime()
 local canManage=group and group:CanManageApplicants()
 local canCancel=not self.recruiting or group:CanManageListing()
 if group then
  if self.recruiting then
   local activity=group.Catalog:GetActivity(group:GetListing().activityID)
   local hideRating=not A.GroupPresentation.Member("applicant",activity).showRating
   for _,id in ipairs(group:GetApplicants()) do
    local app=group:GetApplicant(id)
    if Operable(app) then
     local comment=app.comment and app.comment~="" and app.comment or nil
     batchCount=batchCount+1;local batch=batchEntries[batchCount]
     if batch then wipe(batch) else batch={};batchEntries[batchCount]=batch end
     batch.top,batch.applicantID=total,id
     for index,member in ipairs(app.members) do
      local faction=member.factionGroup and PLAYER_FACTION_GROUP[member.factionGroup]
      local factionTexture=factionTextures[faction]
      local nameWidth=MEMBER_TEXT_WIDTH
      self.measure:SetFont(T.font,MEMBER_NAME_SIZE,"");C.SetLineHeight(self.measure,MEMBER_NAME_LINE);self.measure:SetWidth(nameWidth);self.measure:SetText(member.nameKey or member.name or A.L.invalidName)
      local nameHeight=math.max(MEMBER_NAME_LINE,self.measure:GetStringHeight())
      local _,spec,icon,class=group:ResolveMemberSpec(member)
      local meta=(member.raceName or "—").." · "..(class or (zh and "未知职业" or "Unknown class")).." · "..(spec or member.specName or (zh and "未知专精" or "Unknown specialization"))
      local metaWidth=MEMBER_TEXT_WIDTH-(factionTexture and MEMBER_FACTION_SIZE+MEMBER_FACTION_GAP or 0)
      self.measure:SetFont(T.font,MEMBER_META_SIZE,"");C.SetLineHeight(self.measure,MEMBER_META_LINE);self.measure:SetWidth(metaWidth);self.measure:SetText(meta)
      local metaHeight=math.max(MEMBER_META_LINE,self.measure:GetStringHeight());local pad=index==1 and 12 or 4
      local contentHeight=nameHeight+2+metaHeight
      local height=pad+contentHeight;local entry=AddEntry(total,height);total=total+height
      entry.member,entry.applicantID,entry.padTop,entry.batch,entry.nameHeight,entry.metaText,entry.memberIcon=member,id,pad,batch,nameHeight,meta,icon
      entry.nameWidth,entry.factionTexture,entry.metaWidth,entry.hideRating=nameWidth,factionTexture,metaWidth,hideRating
     end
     if canManage or comment then
      local textWidth=canManage and 180 or 324-MEMBER_TEXT_X-12;local textHeight=0
      if comment then self.measure:SetFont(T.font,MEMBER_META_SIZE,"");C.SetLineHeight(self.measure,MEMBER_META_LINE);self.measure:SetWidth(textWidth);self.measure:SetText(comment);textHeight=math.max(MEMBER_META_LINE,self.measure:GetStringHeight()) end
      local height=math.max(canManage and 40 or 0,textHeight+24)
      local footer=AddEntry(total,height);total=total+height
      footer.footer,footer.actions,footer.comment,footer.applicantID,footer.batch,footer.textHeight,footer.textWidth=true,canManage,comment,id,batch,textHeight,textWidth
     else local last=entries[entryCount];last.height=last.height+12;total=total+12 end
     batch.height=total-batch.top
     local last=entries[entryCount]
     last.height=last.height+8;last.gap=8;total=total+8
    end
   end
  else
   for _,app in ipairs(group:GetApplications()) do if Waiting(app) then
    local detailText=app.activityDetail and app.activityDetail~="" and ("· "..app.activityDetail) or ""
    self.measure:SetFont(T.font,14,"");C.SetLineHeight(self.measure,20);self.measure:SetWidth(112);self.measure:SetText(detailText)
    local detailWidth=math.min(112,self.measure:GetStringWidth())
    local detailHeight=detailWidth>0 and self.measure:GetStringHeight() or 0
    local activityWidth=224-detailWidth-(detailWidth>0 and 6 or 0)
    self.measure:SetFont(T.font,16,"");C.SetLineHeight(self.measure,22);self.measure:SetWidth(activityWidth);self.measure:SetText(app.activityLabel or app.activityName or app.result and app.result.activityName or "")
    local activityHeight=math.max(22,self.measure:GetStringHeight(),detailHeight)
    self.measure:SetFont(T.font,T.listTitleSize,"");C.SetLineHeight(self.measure,T.listTitleLineHeight);self.measure:SetWidth(224);self.measure:SetText(app.name or "")
    local titleHeight=math.max(T.listTitleLineHeight,self.measure:GetStringHeight())
    self.measure:SetFont(T.font,14,"");C.SetLineHeight(self.measure,20);self.measure:SetWidth(196);self.measure:SetText(app.leaderName or (zh and "队长身份未知" or "Leader unknown"))
    local leaderHeight=math.max(20,self.measure:GetStringHeight())
    local height=24+activityHeight+4+titleHeight+4+leaderHeight+8;local entry=AddEntry(total,height);total=total+height
    entry.application,entry.gap,entry.activityWidth,entry.detailWidth,entry.detailText,entry.activityHeight,entry.titleHeight=app,8,activityWidth,detailWidth,detailText,activityHeight,titleHeight
    if app.expiresAt and app.expiresAt>now then pending=true end
   end end
  end
 end
 TrimEntries(entryCount,batchCount)
 if hadEntries and entryCount==0 then self:Dismiss();return end
 if entries[#entries] and entries[#entries].gap then local last=entries[#entries];local gap=last.gap;last.gap=0;last.height=last.height-gap;total=total-gap end
 canCancel=canCancel and (self.recruiting or #entries>0)
 self.body:SetHeight(math.max(1,total));self.empty:SetShown(#entries==0);self.emptyCard:SetShown(#entries==0)
 if #entries==0 then self.empty:SetText(self.lastIdle and (zh and "暂无活动" or "No activity") or (zh and "暂无申请" or "No applications")) end
 self.cancel.label:SetText(self.recruiting and (zh and "取消招募" or "End listing") or (zh and "取消全部申请" or "Cancel all applications"));self.cancel:SetAvailable(canCancel and (self.recruiting or #entries>0));self.cancel:SetShown(canCancel)
 self.cancel:SetWidth(self.cancel.label:GetStringWidth()+8)
 self:LayoutPanel()
 self:Render();self:Fade(true)
 if group then group:SetApplicantView(self,self.recruiting and self.panel:IsVisible()) end
 if pending and not self.countdown then self.countdown=C_Timer.NewTicker(1,function() F:RefreshClock() end)
 elseif not pending and self.countdown then self.countdown:Cancel();self.countdown=nil end
end
-- Host movement changes viewport geometry without invalidating measured entries.
function F:LayoutPanel()
 local total=self.body:GetHeight();local canCancel=self.cancel:IsShown()
 local width=324
 if self.emptyCard:IsShown() then width=math.max(120,math.ceil(self.empty:GetUnboundedStringWidth())+32,canCancel and self.cancel:GetWidth()+24 or 0) end
 self.panel:SetWidth(width+24);self.scroll:SetWidth(width);self.emptyCard:SetWidth(width);self.empty:SetWidth(width-32)
 local anchor=self:GetAnchor();local panelScale=self.panel:GetEffectiveScale();local scale=anchor:GetEffectiveScale()/panelScale
 local screenHeight=UIParent:GetHeight()*UIParent:GetEffectiveScale()/panelScale
 local anchorTop=anchor:GetTop()*scale;local anchorBottom=anchorTop-anchor:GetHeight()*scale
 local top,bottom=anchorTop,anchorBottom
 local right=anchor:GetLeft()*anchor:GetEffectiveScale()>UIParent:GetWidth()*UIParent:GetEffectiveScale()*.6
 local left=anchor:GetLeft()*scale+(right and anchor:GetWidth()*scale-self.panel:GetWidth() or 0)
 if self.popupBounds then
  for _,frame in ipairs(self.popupBounds) do
   if frame:IsVisible() then
    local frameScale=frame:GetEffectiveScale()/panelScale;local frameLeft=frame:GetLeft()*frameScale
    if frameLeft<left+self.panel:GetWidth() and frameLeft+frame:GetWidth()*frameScale>left then
     local frameTop=frame:GetTop()*frameScale
     top=math.max(top,frameTop);bottom=math.min(bottom,frameTop-frame:GetHeight()*frameScale)
    end
   end
  end
 end
 local downRoom=bottom-8;local upRoom=screenHeight-top-8;local down=downRoom>upRoom
 local header=canCancel and 32 or 8;local padding=header+8
 self.scroll:SetPoint("TOPLEFT",12,-header);self.emptyCard:SetPoint("TOPLEFT",12,-header)
 local height=math.min(math.max(44,math.max(downRoom,upRoom)-padding),total);self.panel:SetHeight(math.max(44,height)+padding);self.scroll:SetHeight(math.max(44,height));self.syncScroll=true;self.scrollBar:SetHeight(self.scroll:GetHeight());self.scrollBar:SetMinMaxValues(0,math.max(0,total-self.scroll:GetHeight()));self.scrollBar:SetValue(self.scroll:GetVerticalScroll());self.thumb:SetHeight(math.max(24,self.scroll:GetHeight()*self.scroll:GetHeight()/math.max(1,total)));self.scrollBar:Hide();self.syncScroll=nil
 self.emptyCard:SetHeight(self.scroll:GetHeight())
 self.scroll:SetVerticalScroll(math.max(0,math.min(self.scroll:GetVerticalScroll(),total-self.scroll:GetHeight())))
 self.panel:ClearAllPoints()
 self.panel:SetPoint(down and (right and "TOPRIGHT" or "TOPLEFT") or (right and "BOTTOMRIGHT" or "BOTTOMLEFT"),anchor,down and (right and "BOTTOMRIGHT" or "BOTTOMLEFT") or (right and "TOPRIGHT" or "TOPLEFT"),0,down and bottom-anchorBottom-8 or top-anchorTop+8)
end
function F:RefreshClock()
 if self.recruiting then return end
 local now=GetTime();local pending=false
 for _,entry in ipairs(self.entries) do
  local app=entry.application
  if app and app.expiresAt and app.expiresAt>now then pending=true;break end
 end
 for _,row in ipairs(self.rows) do
  local app=row.application
  if app and row:IsShown() then
   local remaining=app.expiresAt and math.max(0,math.ceil(app.expiresAt-now))
   row.timer:SetText(remaining and ("%d:%02d"):format(math.floor(remaining/60),remaining%60) or "—")
  end
 end
 if not pending and self.countdown then self.countdown:Cancel();self.countdown=nil end
end
function F:Render()
 if not self.entries or next(exits) then return end
 local offset=self.scroll:GetVerticalScroll();local bound=0
 local first,last
 local count=#self.entries;local low,high=1,count
 while low<=high do
  local index=math.floor((low+high)/2)
  if self.entryTops[index]+self.entries[index].height>=offset then first=index;high=index-1 else low=index+1 end
 end
 local bottom=offset+self.scroll:GetHeight()
 if first and self.entryTops[first]<bottom then
  last=first
  while last<count and self.entryTops[last+1]<bottom do last=last+1 end
 else first=nil end
 if self.boundVersion==self.entriesVersion and self.visibleFirst==first and self.visibleLast==last then return end
 self.boundVersion,self.visibleFirst,self.visibleLast=self.entriesVersion,first,last
 local batchCount=0;wipe(boundBatches)
 for _,batch in ipairs(self.batches) do batch.applicantID=nil;batch.background:Hide();batch:Hide() end
 for index=first or 1,last or 0 do
  local entry=self.entries[index]
  local top=self.entryTops[index]
   bound=bound+1;local row=self.rows[bound] or self:CreateRow()
   row.baseTop=top;row.cardOrder=entry.batch and batchCount+1 or bound;row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-top);row:SetHeight(entry.height-(entry.gap or 0));row.background:ClearAllPoints();row.background:SetAllPoints();row.background:Hide();row:Show();row.applicationID=nil;row.applicantID=entry.applicantID;row.application=nil;row.batch=nil
   if entry.batch then
    local batch=boundBatches[entry.batch]
    if not batch then
     batchCount=batchCount+1;batch=self.batches[batchCount] or self:CreateBatch();boundBatches[entry.batch]=batch
     batch:ClearAllPoints();batch:SetPoint("TOPLEFT",0,-entry.batch.top);batch:SetHeight(entry.batch.height);batch.applicantID=entry.applicantID;batch.baseTop=entry.batch.top;batch.cardOrder=batchCount;batch.background:SetHovered(batch:IsMouseOver());batch.background:Show();batch:Show()
    end
    row.batch=batch;row.cardOrder=batch.cardOrder
   end
   row.icon:SetShown(entry.member~=nil or entry.application~=nil);row.meta:SetShown(entry.member~=nil or entry.application~=nil);row.score:SetShown(entry.member~=nil and not entry.hideRating);row.itemLevel:SetShown(entry.member~=nil);row.leader:SetShown(entry.application~=nil);row.timer:SetShown(entry.application~=nil)
   row.faction:Hide();row.faction:SetTexture(nil)
   row.name:ClearAllPoints();row.meta:ClearAllPoints();row.name:SetHeight(0);row.name:SetWordWrap(true);row.meta:SetWordWrap(true);row.leader:SetWordWrap(true)
   row.invite:Hide();row.decline:Hide();row.cancel:Hide();row.invite.applicantID=nil;row.decline.applicantID=nil;row.cancel.applicationID=nil
   row.name:SetTextColor(unpack(T.text));row.name:SetFont(T.font,entry.comment and MEMBER_META_SIZE or entry.member and MEMBER_NAME_SIZE or 16,"")
   C.SetLineHeight(row.name,entry.member and MEMBER_NAME_LINE or entry.comment and MEMBER_META_LINE or 22);row.meta:SetFont(T.font,entry.application and T.listTitleSize or MEMBER_META_SIZE,"");C.SetLineHeight(row.meta,entry.application and T.listTitleLineHeight or MEMBER_META_LINE)
   if entry.footer then
     local commentTop=entry.actions and entry.comment and entry.textHeight<=MEMBER_META_LINE and 6 or 12
     row.name:SetWidth(entry.textWidth);row.name:SetPoint("TOPLEFT",MEMBER_TEXT_X,-commentTop);row.name:SetHeight(entry.textHeight);row.name:SetTextColor(unpack(T.muted));row.name:SetText(entry.comment or "")
    if entry.actions then
     row.invite:SetSize(28,28);row.decline:SetSize(28,28)
     row.invite:ClearAllPoints();row.invite:SetPoint("BOTTOMRIGHT",-48,12);row.decline:ClearAllPoints();row.decline:SetPoint("BOTTOMRIGHT",-12,12)
     row.invite.applicantID=entry.applicantID;row.decline.applicantID=entry.applicantID;row.invite:Show();row.decline:Show()
     row.invite:SetEnabled(true);row.decline:SetEnabled(true)
    end
   elseif entry.member then
    local m=entry.member;local name=m.nameKey or m.name
    local pad=entry.padTop
    row.icon:SetSize(32,32);row.icon:ClearAllPoints();row.icon:SetPoint("TOPLEFT",12,-pad)
    row.name:SetWidth(entry.nameWidth);row.name:SetPoint("TOPLEFT",MEMBER_TEXT_X,-pad);row.name:SetText(name or A.L.invalidName)
    local metaTop=-pad-entry.nameHeight-2
    if entry.factionTexture then row.faction:SetTexture(entry.factionTexture);row.faction:ClearAllPoints();row.faction:SetPoint("TOPLEFT",MEMBER_TEXT_X,metaTop-(MEMBER_META_LINE-MEMBER_FACTION_SIZE)/2);row.faction:Show() end
    row.meta:SetWidth(entry.metaWidth);row.meta:SetPoint("TOPLEFT",MEMBER_TEXT_X+MEMBER_TEXT_WIDTH-entry.metaWidth,metaTop);row.meta:SetText(entry.metaText)
    local color=m.class and RAID_CLASS_COLORS[m.class];if color then row.name:SetTextColor(color.r,color.g,color.b) end
    MemberIcon(row.icon,m,entry.memberIcon)
    if entry.hideRating then row.score:SetText("") elseif m.ratingKind=="pvp" then ColorScore(row.score,m.rating,"pvp") else ColorScore(row.score,m.dungeonScore) end
    row.itemLevel:SetFont(T.font,entry.hideRating and 14 or MEMBER_META_SIZE,"");C.SetLineHeight(row.itemLevel,entry.hideRating and MEMBER_NAME_LINE or MEMBER_META_LINE,true)
    row.itemLevel:ClearAllPoints();row.itemLevel:SetWidth(MEMBER_METRIC_WIDTH);row.itemLevel:SetPoint("TOPRIGHT",-12,entry.hideRating and -pad or -pad-entry.nameHeight-2);row.itemLevel:SetText((zh and "装等 " or "ilvl ")..(m.itemLevel and math.floor(m.itemLevel) or "—"))

   else
    local app=entry.application;row.applicationID=app.id;row.application=app;row.background:SetHovered(row:IsMouseOver());row.background:Show()
    row.icon:SetSize(24,24);row.icon:ClearAllPoints();row.icon:SetPoint("TOPLEFT",12,-11);F.context:SetGameTexture(row.icon,app.activityArt or "Interface\\Icons\\INV_Misc_GroupLooking")
    row.name:SetPoint("TOPLEFT",48,-12);row.name:SetText(app.activityLabel or app.activityName or app.result and app.result.activityName or "")
    row.score:Show();row.score:SetFont(T.font,14,"");row.score:SetHeight(0);row.score:SetWordWrap(true);C.SetLineHeight(row.score,20);row.score:ClearAllPoints();row.score:SetWidth(entry.detailWidth);row.score:SetTextColor(unpack(T.muted));row.score:SetText(entry.detailText);row.score:SetJustifyH("LEFT")
    row.name:SetWidth(entry.activityWidth);local nameWidth=math.min(entry.activityWidth,row.name:GetStringWidth());row.name:SetWidth(nameWidth);row.score:SetPoint("TOPLEFT",48+nameWidth+6,-12)
    row.meta:SetWidth(224);row.meta:SetPoint("TOPLEFT",48,-16-entry.activityHeight);row.meta:SetText(app.name or "")
    row.cancel:ClearAllPoints();row.cancel:SetPoint("TOPRIGHT",-12,-12);row.cancel.applicationID=app.id;row.cancel:Show();row.cancel:SetEnabled(not app.pendingStatus)
    row.leader:ClearAllPoints();row.leader:SetWidth(196);row.leader:SetPoint("TOPLEFT",48,-20-entry.activityHeight-entry.titleHeight);row.timer:ClearAllPoints();row.timer:SetPoint("TOPRIGHT",-12,-20-entry.activityHeight-entry.titleHeight);row.leader:SetText(app.leaderName or (zh and "队长身份未知" or "Leader unknown"))
    local color=app.leaderClass and RAID_CLASS_COLORS[app.leaderClass];if color then row.leader:SetTextColor(color.r,color.g,color.b) else row.leader:SetTextColor(unpack(T.muted)) end
   end
   if row:IsMouseOver() then self:HoverRow(row,true) end
   if entry.member then row.score:SetFont(T.font,14,"");row.score:SetWordWrap(false);C.SetLineHeight(row.score,MEMBER_NAME_LINE,true);row.score:ClearAllPoints();row.score:SetPoint("TOPRIGHT",-12,-entry.padTop);row.score:SetWidth(MEMBER_METRIC_WIDTH);row.score:SetJustifyH("RIGHT") end
 end
 for i=bound+1,#self.rows do local row=self.rows[i];row:Hide();row.faction:Hide();row.faction:SetTexture(nil);row.applicationID=nil;row.applicantID=nil;row.application=nil;row.batch=nil;row.invite:Hide();row.decline:Hide();row.cancel:Hide();row.invite.applicantID=nil;row.decline.applicantID=nil;row.cancel.applicationID=nil end
 self:ApplyCardMotion(self.cardElapsed)
 self:RefreshClock()
end
local boot=CreateFrame("Frame");boot:RegisterEvent("PLAYER_LOGIN");boot:SetScript("OnEvent",function(self) self:UnregisterAllEvents();A:LoadDB();F:UpdateSettings();if A.Group then F:Bind(A.Group) end end)
