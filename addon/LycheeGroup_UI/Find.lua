-- 寻求组队：原生目录、共享结果仓库、固定像素行池和独立申请生命周期。
local A = _G.LycheeGroup
local UI = A.UI
local T,L,C,M = UI.Theme,UI.L,UI.C,UI.Motion
local P={};UI.pages.find=P
local zh=A:GetLocale()=="zhCN"
local function Say(cn,en) return zh and cn or en end
local SEARCH_HINT=Say("队伍标题","Group title")
local KEY_SEARCH_HINT=Say("队伍标题或钥石范围，如 12-15","Group title or keystone range, e.g. 12-15")
local LEADER_SEARCH_HINT=Say("队长名字，可带服务器","Leader name, realm optional")
-- Measure unconstrained text: recycled labels may still carry the previous row width.
local function FitText(label)
 label:SetWordWrap(false);label:SetWidth(0)
 local width=math.ceil(label:GetStringWidth())+2;label:SetWidth(width);return width
end
local LEFT=208
local COLLAPSED_LEFT=56
local PICKER_GAP=24
local MAIN=T.contentWidth-LEFT-T.contentGap-48
local HEIGHT=T.contentHeight-48
local LIST_GUTTER=14
local BODY=MAIN-LIST_GUTTER
local BASE_BODY=BODY
local APP_BODY=MAIN-32-LIST_GUTTER
local AGE_WIDTH=zh and 88 or 96
local APP_ROW_HEIGHT,RESULT_ROW_HEIGHT=36,76
local function SetRowHeight(list,height)
 list.rowHeight=height
 list.capacity=math.min(list.poolCapacity-1,math.ceil(list:GetHeight()/height))
 list.canvas:SetHeight(list:GetHeight()+height*2)
 for i,row in ipairs(list.rows) do row:SetHeight(height);row:SetPoint("TOPLEFT",0,-(i-1)*height) end
 list:Refresh(true)
end
local AVAILABLE_NOTICE_COLOR={38/255,61/255,48/255,1}
local FILTER_BUTTON_WIDTH=126
local SEARCH_RIGHT=144+FILTER_BUTTON_WIDTH
local RESULT_COLUMNS={
 title={x=60,width=210},leader={x=303,width=108},
 members={x=427,width=138},ilvl={x=581,width=52},rating={x=649,width=76},
 description={x=741,width=BODY-765-AGE_WIDTH},age={x=BODY-12-AGE_WIDTH,width=AGE_WIDTH},
}
local APPLICATION_COLUMNS={title={x=36,width=APP_BODY-591},leader={x=APP_BODY-522,width=120}}
local state={category="seasonDungeon",searchMode="group",apps={},appIDs={},categoryPrefs={},filters={sort="newest"}}
local function Category() return UI:GetGroup().Catalog:GetCategory(state.category) end
local function AllActivitiesLabel(cat)
 if cat.id==2 or cat.id==3 then return Say("全部副本","All instances") end
 if cat.id==6 then return Say("全部自定义活动","All custom activities") end
 if cat.id==121 then return Say("全部地下堡","All delves") end
 return zh and "全部"..cat.name or "All "..cat.name
end
local function CopyGroupKeys(keys)
 if not keys then return nil end
 local copy={};for key,selected in pairs(keys) do if selected then copy[key]=true end end
 return next(copy) and copy or nil
end
local function ChoiceSnapshot(choice)
 local keys=CopyGroupKeys(choice.groupKeys)
 return {groupKey=choice.groupKey,groupKeys=keys,difficultyID=choice.difficultyID,tier=choice.tier,
  selected=choice.selected==true or choice.browseReady==true or choice.groupKey~=nil or keys~=nil}
end
function P:CommitChoice()
 state.browseReady=true;state.confirmedChoice=ChoiceSnapshot(state)
end
local function Record(id)
 local app=UI:GetGroup():GetApplication(id)
 return UI:GetGroup():GetResult(id) or app and app.result
end
local function Active(app) return UI:GetGroup().Applications:IsActive(app.id) end
local function NameOnly(value) return value and value:match("^[^-]+") or L.unknown end
local function Detail(record) return UI:GetGroup().Results:GetDetails(record) end
local function ResultTooltipArea(row,list)
 UI:BindTooltipArea(row,list.tooltipFraction,
  function(r) return r:IsEnabled() and r.key and r._hitVisible and list.clip:IsMouseOver() end,
  function(r) local record=Record(r.key);if record then UI.Tooltip:ShowGroup(r,record) end end)
end
local function RosterColumns(roster)
 for _,slot in ipairs(roster.slots) do slot.role:SetSize(10,10) end
 for i,item in ipairs(roster.counts) do
  item.icon:SetSize(16,16);item.icon:ClearAllPoints();item.icon:SetPoint("LEFT",(i-1)*46,0)
  item.text:SetWidth(20);item.text:SetJustifyH("LEFT");item.text:ClearAllPoints();item.text:SetPoint("LEFT",(i-1)*46+20,0)
 end
end
local function MemberIconScale()
 local value=tonumber(A.db.rurutiaMemberIconScale) or 100
 if value~=value then value=100 end
 return math.max(75,math.min(175,value))/100
end
local function LayoutMembers(row)
 -- Fixed raid columns keep one- and two-digit counts aligned across rows.
 row.roster:SetWidth(row.isParty and row.partyWidth or 132)
 local scale=row.partyScale*(not row.membersCompact and MemberIconScale() or 1)
 row.roster:SetScale(row.isParty and scale or 1)
 -- Resolve the crown cap only after the final roster scale is applied.
 if not row.membersCompact then for _,slot in ipairs(row.roster.slots) do
  UI:UpdateMemberLeader(slot.icon,row.isParty and slot.icon:IsShown())
 end end
 row.roster:ClearAllPoints()
 local x=row.membersX
 if row.isParty then
  row.membersButton:SetSize(math.max(138,math.ceil(row.partyWidth*scale)),math.max(row.membersCompact and 18 or 24,math.ceil(18*scale)));row.roster:SetPoint("CENTER")
 else
  -- Keep the columns in place while the hover/click area fits the visible count.
  x=x-3
  row.membersButton:SetHeight(row.membersCompact and 18 or 24)
  row.membersButton:SetWidth(112+row.roster.counts[3].text:GetStringWidth()+12)
  row.roster:SetPoint("LEFT",6,0)
 end
 local extra=math.max(0,row.count:GetHeight()-row.memberCountLine)/2
 row.membersButton:ClearAllPoints();row.membersButton:SetPoint("LEFT",x,row.membersExpanded and row.membersExpandedY+extra or 0)
 row.count:SetPoint("LEFT",row.membersX,row.memberCountY-extra)
 row.count:SetShown(not row.isParty and row.membersExpanded==true)
end
local function BuildMembers(row,x,compact)
 row.membersCompact=compact
 row.membersX=x;row.membersExpandedY=compact and 9 or 11
 row.memberCountY=compact and -9 or -13;row.memberCountLine=(compact and 14 or 20)+T.lineHeightDelta
 local partyGap=compact and 5 or 2
 row.partyWidth=18*5+partyGap*4
 row.partyScale=compact and 1 or 1.2*1.15
 row.membersButton=C.Button(row,"",138,function()
  if row.isParty or not row.key or not row._hitVisible then return end
  row.membersExpanded=not row.membersExpanded;LayoutMembers(row)
 end)
 row.membersButton:SetStyle({height=compact and 18 or 24,radius=6})
 row.roster=C.Roster(row.membersButton,18,partyGap);row.roster:SetSize(132,compact and 18 or 20);row.roster:SetPoint("CENTER");RosterColumns(row.roster)
 if not compact then for _,slot in ipairs(row.roster.slots) do slot.icon.rurutiaClassBorder=true end end
 if compact then for _,item in ipairs(row.roster.counts) do C.SetFont(item.text,12);C.SetLineHeight(item.text,14,true) end end
 row.count=C.Text(row,"",compact and 12 or 14,T.muted,138);C.SetLineHeight(row.count,compact and 14 or 20,true);row.count:SetPoint("LEFT",x,compact and -9 or -13);row.count:SetJustifyH("CENTER");row.count:SetWordWrap(false)
 LayoutMembers(row)
end
local function UpdateMembers(row,id,record,details)
 if row.membersKey~=id then row.membersKey=id;row.membersExpanded=nil end
 row.isParty=record and record.maxNumPlayers==5
 if row.isParty then row.membersExpanded=nil end
 row.membersButton:EnableMouse(not row.isParty)
 local counts=details and details.counts
 if not row.membersCompact then for _,slot in ipairs(row.roster.slots) do slot.icon.rurutiaMemberClass=nil;slot.icon.rurutiaMemberLeader=false;slot.icon.rurutiaLeaderKey=record and record.leaderKey end end
 row.roster:Update(details and details.members,counts,record and record.maxNumPlayers,true)
 if not row.membersCompact then for _,slot in ipairs(row.roster.slots) do
  local occupied=row.isParty and slot.icon:IsShown()
  UI:UpdateMemberBorder(slot.icon,occupied)
 end end
 UI:SetText(row.count,record and not row.isParty and UI:MemberCountText(record) or "")
 LayoutMembers(row)
end
local function DeclinedAt(record)
 return record and record.partyGUID and UI:GetGroup().Applications:GetDeclinedAt(record.partyGUID)
end
local EnsureDeclineClock
local function UpdateDeclineLabel(row,record,now)
 local declinedAt=DeclinedAt(record)
 local text=""
 if declinedAt then
  local minutes=math.floor((now-declinedAt)/60)
  text=minutes<1 and Say("刚刚拒绝了你","Rejected you just now") or Say("%d分钟前拒绝了你","Rejected you %d min ago"):format(minutes)
 end
 UI:SetText(row.declined,text);row.declined:SetShown(declinedAt~=nil)
 return declinedAt and 60-(now-declinedAt)%60
end
local function StopDeclineClock()
 if P.declineClock then P.declineClock:Cancel();P.declineClock=nil end
 P.declineDeadline=nil
end
local function RefreshVisibleDeclines()
 if UI.hiding or UI.page~="find" or not P.frame:IsVisible() or not P.hasDeclinedResults then StopDeclineClock();return end
 local group,now=UI:GetGroup(),GetTime()
 local delay
 for _,row in ipairs(P.results.rows) do
  if row.key and row._hitVisible then
   local nextMinute=UpdateDeclineLabel(row,group:GetResult(row.key),now)
   if nextMinute then delay=math.min(delay or nextMinute,nextMinute) end
  end
 end
 if delay then EnsureDeclineClock(delay) else StopDeclineClock() end
end
local function RefreshDeclineClock()
 P.declineClock,P.declineDeadline=nil,nil
 RefreshVisibleDeclines()
end
EnsureDeclineClock=function(delay)
 local deadline=GetTime()+delay
 if P.declineClock and P.declineDeadline<=deadline then return end
 StopDeclineClock();P.declineDeadline=deadline;P.declineClock=C_Timer.NewTimer(delay,RefreshDeclineClock)
end
function P:RefreshDeclineState(ids)
 local declined=false
 for _,id in ipairs(ids) do if DeclinedAt(UI:GetGroup():GetResult(id)) then declined=true;break end end
 if (self.hasDeclinedResults==true)~=declined then self.hasDeclinedResults=declined;self:LayoutListRows() end
end
local function LayoutResultActivity(row)
 local width=RESULT_COLUMNS.title.width
 if row.marks:IsShown() then
  width=math.min(math.ceil(row.meta:GetUnboundedStringWidth())+2,width-row.marks:GetWidth()-6)
 end
 -- Data refresh and window layout must use the same text edge for the marks.
 if row.meta:GetWidth()~=width then row.meta:SetWidth(width) end
end
local function RenderResult(row,id)
 local r=Record(id);if not r then return end
 UI:SetText(row.title,r.name or L.unknown)
 UI:SetText(row.description,r.comment and r.comment~="" and r.comment or "—")
 UI:Color(row.description,r.comment and r.comment~="" and T.muted or T.dim)
 UI:SetText(row.meta,r.activityName or L.unknown)
 UI:SetText(row.leader,NameOnly(r.leaderName))
 UI:SetActivityIcon(row.icon,r.activity or r)
 local d=Detail(r);UpdateMembers(row,id,r,d)
 -- Only seasonal dungeon result rows dim empty role slots; occupied members
 -- and every other use of the shared roster retain their original colors.
 for _,slot in ipairs(row.roster.slots) do
  local missing=state.category=="seasonDungeon" and row.isParty and not slot.icon:IsShown()
  UI:StyleRosterRole(slot.role,missing,row.isParty and not slot.icon:IsShown() and slot.icon:GetWidth() or nil)
 end
 UI.Members:BindGroupMarks(row.marks,r)
 LayoutResultActivity(row)
 local leaderClass
 for _,member in ipairs(d.members) do if member.isLeader or r.leaderKey and member.nameKey==r.leaderKey then leaderClass=member.class;break end end
 row.leader:SetTextColor(UI:ClassColor(leaderClass))
 if A.GroupPresentation.Result(r).groupMetric=="progress" then
  local progress=UI:ProgressText(r,d)
  UI:SetText(row.score,progress);UI:Color(row.score,progress=="—" and T.dim or T.good)
 else UI:SetScore(row.score,r.leaderRating,r.ratingKind) end
 UI:SetText(row.ilvl,(r.requiredItemLevel or 0)>0 and math.floor(r.requiredItemLevel) or Say("不限","Any"))
 UI:SetText(row.age,UI:AgeText(r.age))
 UpdateDeclineLabel(row,r,GetTime())
 row.noteDot:Hide()
end
local function UpdateApplicationStatus(row,app)
 local remaining=app.expiresAt and math.max(0,math.ceil(app.expiresAt-GetTime()))
 local status=app.pendingStatus or app.status
 UI:SetText(row.status,status=="invited" and Say("已收到邀请","Invited") or app.pendingStatus=="applied" and Say("提交中","Submitting") or status=="applied" and (remaining and remaining>0 and ("%d:%02d"):format(math.floor(remaining/60),remaining%60) or L.states.applied) or L.states[status] or status)
 UI:Color(row.status,UI:StatusColor(status))
 return status
end
local function StopCountdown()
 if P.countdown then P.countdown:Cancel();P.countdown=nil end
end
local function HasApplicationCountdown()
 local now=GetTime()
 for _,id in ipairs(state.appIDs) do
  local app=state.apps[id]
  if app.status=="applied" and app.expiresAt and app.expiresAt>now then return true end
 end
 return false
end
local function RefreshApplicationClock()
 for _,row in ipairs(P.appList.rows) do
  local app=row.key and state.apps[row.key]
  if app and row._hitVisible then UpdateApplicationStatus(row,app) end
 end
 if not HasApplicationCountdown() then StopCountdown() end
end
local function UpdateApplication(row,id)
 local app=UI:GetGroup():GetApplication(id);local r=app and app.result
 if not app then return end
 UI:SetText(row.title,app.name or L.unknown);UI:SetText(row.meta,"")
 UI:Color(row.title,app.status=="invited" and T.good or T.text)
 UI:SetActivityIcon(row.icon,r and (r.activity or r))
 UI:SetText(row.leader,NameOnly(app.leaderName))
 local d=r and Detail(r);UpdateMembers(row,id,r,d)
 local leaderClass;if d then for _,m in ipairs(d.members) do if m.isLeader or r.leaderKey and m.nameKey==r.leaderKey then leaderClass=m.class;break end end end;row.leader:SetTextColor(UI:ClassColor(leaderClass))
 local status=UpdateApplicationStatus(row,app)
 row.cancel.targetKey=id;row.cancel:SetShown(UI:GetGroup().Applications:CanCancel(id))
 UI:SetText(row.cancel.label,status=="invited" and L.accept or L.cancelApplication)
end
function P:Build(parent)
 local f=CreateFrame("Frame",nil,parent);f:SetAllPoints(parent);self.frame=f
 local rail=CreateFrame("Frame",nil,f);rail:SetSize(LEFT,T.contentHeight);rail:SetPoint("TOPLEFT");self.rail=rail
 local seasonStride=zh and 52 or 72
 local seasonHeight=seasonStride*2;local categoriesTop=seasonHeight+24
 self.seasonCategories=C.List(rail,LEFT,seasonHeight,seasonStride,function(key,button,row) P:SelectCategory(key,row) end);self.seasonCategories:SetPoint("TOPLEFT",0,-8)
 self.categories=C.List(rail,LEFT,T.contentHeight-categoriesTop-72,52,function(key,button,row) P:SelectCategory(key,row) end);self.categories:SetPoint("TOPLEFT",0,-categoriesTop)
 self.seasonIDs={};self.catIDs={};self.catMap={}
 for _,list in ipairs({self.seasonCategories,self.categories}) do list:SetGutter(0);list.alternateRows=false;list.selectionFill=true;list.idleTextColor=T.muted;list:SetRowInitializer(function(row)
  row:SetHeight(list.rowHeight-4);row.selected:SetRadius(8);row.hover:SetRadius(8);row.alternate:SetRadius(8);row.title:ClearAllPoints();row.title:SetPoint("LEFT",52,0);row.title:SetWidth(116);C.SetFont(row.title,T.railFontSize+2);row.title:SetWordWrap(true);row.title:SetHeight(0);C.SetLineHeight(row.title,22);row.meta:Hide()
  row.symbol=C.Icon(row,T.railIconSize);row.symbol:SetPoint("CENTER");row.chevron=C.Glyph(row,"chevron",12);row.chevron:SetPoint("RIGHT",-16,0)
  row.title:Hide();row.chevron:Hide()
  row:HookScript("OnEnter",function(button)
   local cat=button.key and P.catMap[button.key]
   if not cat then return end
   GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:SetText(cat.name);GameTooltip:Show()
  end)
  local function HideTip(button) if GameTooltip:IsOwned(button) then GameTooltip:Hide() end end
  row:HookScript("OnLeave",HideTip);row:HookScript("OnHide",HideTip)
 end);list:SetStyle({selectionMotion=true,radius=8}) end
 local surface=CreateFrame("Frame",nil,f);surface:SetSize(MAIN+48,T.contentHeight);surface:SetPoint("TOPLEFT",LEFT+T.contentGap,0);C.Panel(surface,T.surfaceLow,24);self.surface=surface
 local main=CreateFrame("Frame",nil,surface);main:SetSize(MAIN,HEIGHT);main:SetPoint("TOPLEFT",24,-24);self.main=main
 self.searchInputRight=SEARCH_RIGHT
 self.search=C.Edit(main,MAIN-60,48,false,true);self.search:SetPoint("TOPLEFT")
 self.search:EnableMouse(true)
 self.search:SetScript("OnEnter",function() P:EnsureSearchInput() end)
 self.search:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" and P:EnsureSearchInput() then P.search.box:SetFocus() end end)
  self.previewSearchBox=self.search.box
 self.search.box:ClearAllPoints();self.search.box:SetPoint("TOPLEFT",52,-4);self.search.box:SetPoint("BOTTOMRIGHT",-SEARCH_RIGHT,4)
 C.Glyph(self.search,"search",22):SetPoint("LEFT",18,0)
  self.searchHint=C.Text(self.search,SEARCH_HINT,14,T.dim,MAIN-350);self.searchHint:SetPoint("LEFT",52,0)
  self.search.box:SetScript("OnTextChanged",function(box) self:OnSearchTextChanged(box,true) end)
 self.search.box:SetScript("OnEnterPressed",function(box) box:ClearFocus();self:DoSearch() end)
 self.filterToggle=C.Button(self.search,Say("筛选","Filters"),FILTER_BUTTON_WIDTH,function() P:SetFiltersOpen(not P.filtersOpen) end);self.filterToggle:SetHeight(36);self.filterToggle:SetTextColors(T.muted,T.text,T.onSecondaryContainer);self.filterToggle:SetPoint("RIGHT",-6,0)
 self.filterToggle.label:ClearAllPoints();self.filterToggle.label:SetPoint("LEFT",12,0)
 self.filterToggle.label:SetWidth(FILTER_BUTTON_WIDTH-42);self.filterToggle.label:SetJustifyH("LEFT");self.filterToggle.label:SetWordWrap(false)
 self.filterChevron=C.Icon(self.filterToggle,12);self.filterChevron:SetTexture(T.media.."chevron.tga");self.filterChevron:SetPoint("RIGHT",-10,0)
 self.searchModeToggle=C.Button(self.search,"",82,function() P:SetSearchMode(state.searchMode=="group" and "leader" or "group") end);self.searchModeToggle:SetHeight(32);self.searchModeToggle:SetTextColors(T.muted,T.text,T.onSecondaryContainer);self.searchModeToggle:SetPoint("RIGHT",self.filterToggle,"LEFT",-6,0)
 self.searchModeToggle:HookScript("OnEnter",function(button)
  GameTooltip:SetOwner(button,"ANCHOR_TOP");GameTooltip:SetText(Say("按队伍标题搜索/按队长名字搜索","Search by: group title/leader name"));GameTooltip:Show()
 end)
 local function HideSearchModeTip() if GameTooltip:IsOwned(P.searchModeToggle) then GameTooltip:Hide() end end
 self.searchModeToggle:HookScript("OnLeave",HideSearchModeTip);self.searchModeToggle:HookScript("OnHide",HideSearchModeTip)
 self.searchClear=C.Button(self.search,"",28,function() P:ClearSearch() end);self.searchClear:SetSize(28,28);self.searchClear:SetPoint("RIGHT",self.searchModeToggle,"LEFT",-6,0);C.Glyph(self.searchClear,"close",14):SetPoint("CENTER");self.searchClear:Hide()
 self.search.box:ClearAllPoints();self.search.box:SetPoint("TOPLEFT",52,-4);self.search.box:SetPoint("BOTTOMRIGHT",self.searchModeToggle,"LEFT",-40,4)
 self.applicationPanel=CreateFrame("Frame",nil,main);self.applicationPanel:SetPoint("TOPLEFT",0,-68);self.applicationPanel:SetWidth(MAIN);self.applicationPanel.fill=C.Panel(self.applicationPanel,T.panel,20)
 self.appsTitle=C.Text(self.applicationPanel,L.applications,14,T.text);C.SetLineHeight(self.appsTitle,20,true);self.appsTitle:SetPoint("LEFT",self.applicationPanel,"TOPLEFT",16,-22)
 self.appsBadge=CreateFrame("Frame",nil,self.applicationPanel);self.appsBadge:SetSize(48,24);self.appsBadge:SetPoint("LEFT",self.appsTitle,"RIGHT",10,0);C.Panel(self.appsBadge,T.selected,12)
 self.appsCount=C.Text(self.appsBadge,"0",14,T.text);C.SetLineHeight(self.appsCount,20,true);self.appsCount:SetPoint("CENTER")
 self.appsEmpty=C.Text(self.applicationPanel,Say("本分类暂无申请","No applications in this category"),14,T.dim);self.appsEmpty:SetPoint("LEFT",self.appsBadge,"RIGHT",12,0)
 self.scopeToggle=C.Button(self.applicationPanel,Say("全部申请","All applications"),112,function()
  state.showGlobal=not state.showGlobal
  if not state.showGlobal then P:DismissApplicationNotice() end
  P:RefreshApplications()
 end,{height=32,radius=16});self.scopeToggle:SetPoint("LEFT",self.appsBadge,"RIGHT",10,0)
 self.autoJoin=C.Check(self.applicationPanel,Say("自动进组","Auto join"),function(value) UI:SetGroupSetting("autoJoin",value) end);C.SetFont(self.autoJoin.label,14);C.SetLineHeight(self.autoJoin.label,20,true);self.autoJoin:SetSize(54+FitText(self.autoJoin.label),26);self.autoJoin:SetPoint("RIGHT",self.applicationPanel,"TOPRIGHT",-16,-22);self.autoJoin.track:ClearAllPoints();self.autoJoin.track:SetPoint("RIGHT",0,0);self.autoJoin.label:ClearAllPoints();self.autoJoin.label:SetPoint("RIGHT",self.autoJoin.track,"LEFT",-10,0)
 self.autoApply=C.Check(self.applicationPanel,"",function(value)
  local ok,err=UI.Application:SetAutoApply(value);if not ok then P:SetStatus(err or L.failed) end
 end);self.autoApply:SetSize(44,26);self.autoApply:SetPoint("RIGHT",self.autoJoin,"LEFT",-20,0);self.autoApply.label:Hide()
 self.applicationSettings=C.Button(self.applicationPanel,L.applicationSettings,112,function()
  if not UI.Application:IsAutoApplyEnabled() then return end
  local ok,err=UI.Application:OpenApplicationSettings();if not ok then P:SetStatus(err or L.failed) end
 end)
 self.applicationSettings:SetHeight(26);C.SetFont(self.applicationSettings.label,14);C.SetLineHeight(self.applicationSettings.label,20,true)
 UI.Application.onPreferencesChanged=function() P:UpdateApplicationSettings() end
 self.applicationSettings:SetPoint("RIGHT",self.autoApply,"LEFT",-10,0)
 function self.applicationSettings:RefreshStyle()
  self.fill:Hide();self.hover:Hide();UI:Color(self.label,self._inside and T.brand or T.muted)
 end
 self.refresh=C.IconButton(main,"refresh",48,function() P:DoSearch() end,{iconSize=22,radius=24,surfaceColors={T.selected,T.refreshHover}});self.refresh:SetPoint("TOPRIGHT",main,"TOPRIGHT",0,0);self.refreshIcon=self.refresh.icon
 self.appList=C.List(self.applicationPanel,MAIN-32,APP_ROW_HEIGHT*3,APP_ROW_HEIGHT,function(id,button,row) if button=="RightButton" then P:OpenResultMenu(row,id) end end);self.appList:SetGutter(LIST_GUTTER);self.appList:SetPoint("TOPLEFT",16,-40);self.appList.tooltipFraction=.25
 self.appList.selectionFill=false;self.appList.selectionMark=false;self.appList.hoverFill=false;self.appList.alternateRows=false
 self.limitNotice=C.Notice(main,BODY,function()
  if state.applicationLimit then P:DismissApplicationNotice()
  else P.dismissedStatus=P.statusMessage;P.statusMessage="" end
  P:LayoutResults()
 end)
 self.limitText=self.limitNotice.text;self.statusText=self.limitText
 self.closeApplicationNotice=self.limitNotice.close
 self.limitNotice:Hide()
 for _,row in ipairs(self.appList.rows) do
  ResultTooltipArea(row,self.appList)
  row.title:ClearAllPoints();row.title:SetPoint("LEFT",APPLICATION_COLUMNS.title.x,0);row.title:SetWidth(APPLICATION_COLUMNS.title.width);C.SetFont(row.title,15);C.SetLineHeight(row.title,20,true);row.meta:Hide()
  row.icon=C.Icon(row,24);row.icon:SetPoint("LEFT",0,0)
  row.leaderIcon=C.Icon(row,12);row.leaderIcon:SetTexture(T.media.."leader.tga");row.leaderIcon:Hide();row.leaderIcon:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x-17,0)
  row.leader=C.Text(row,"",14,T.muted,APPLICATION_COLUMNS.leader.width);row.leader:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x,0);C.SetLineHeight(row.leader,20,true);row.leader:SetWordWrap(false)
  BuildMembers(row,APP_BODY-386,true)
  row.status=C.Text(row,"",14,T.dim,112);row.status:SetPoint("LEFT",APP_BODY-224,0);C.SetLineHeight(row.status,20,true);row.status:SetJustifyH("CENTER")
  row.cancel=C.Button(row,L.cancelApplication,92,function(b)
   local id=b.targetKey;local app=UI:GetGroup():GetApplication(id);if not app then return end
   if not UI:GetGroup().Applications:CanCancel(id) then return end
   local ok,err=UI:GetGroup():Cancel(id)
   if not ok then P:SetStatus(err or L.failed) end
  end);C.SetFont(row.cancel.label,14);C.SetLineHeight(row.cancel.label,20,true);row.cancel:SetStyle({height=28,radius=14});row.cancel:SetPoint("RIGHT",0,0)
  row.cancel:HookScript("OnEnter",function(button) if button:IsEnabled() then UI:Color(button.label,T.accent) end end)
 end
 self.context=C.Text(main,"",20,T.text,MAIN-180)
 self.resultCount=C.Text(main,"",14,T.dim,132);C.SetLineHeight(self.context,28,true);C.SetLineHeight(self.resultCount,20,true);self.resultCount:SetJustifyH("LEFT")
 self.resultsHeader=CreateFrame("Frame",nil,main);self.resultsHeader:SetSize(BODY,24);self.resultHeadings={}
 for _,entry in ipairs({{"title",Say("队伍","Group")},{"leader",Say("队长","Leader")},{"members",Say("成员","Members")},{"ilvl",Say("装等","iLvl")},{"rating",Say("评分","Score")},{"description",Say("描述","Description")},{"age",Say("发布","Posted")}}) do
  local key,label=entry[1],entry[2];local column=RESULT_COLUMNS[key]
  local text=C.Text(self.resultsHeader,label,14,T.dim,column.width);C.SetLineHeight(text,20,true);text:SetPoint("TOPLEFT",key=="title" and 12 or column.x,0);text:SetWordWrap(false)
  text:SetJustifyH((key=="title" or key=="description" or key=="leader") and "LEFT" or key=="age" and "RIGHT" or "CENTER");self.resultHeadings[key]=text
 end
 self.results=C.List(main,MAIN,T.height*1.5,RESULT_ROW_HEIGHT,function(id,button,row) P:OnResultSelect(id,button,row) end)
 self.results:SetGutter(LIST_GUTTER);self.results.tooltipFraction=.25
 self.results:SetRowInitializer(function(row)
  ResultTooltipArea(row,self.results)
  row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-10);row.title:SetWidth(RESULT_COLUMNS.title.width);C.SetFont(row.title,T.listTitleSize);C.SetLineHeight(row.title,T.listTitleLineHeight,true)
  row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-42);row.meta:SetWidth(RESULT_COLUMNS.title.width);C.SetLineHeight(row.meta,20,true)
  row.declined=C.Text(row,"",12,T.warning,RESULT_COLUMNS.leader.x+RESULT_COLUMNS.leader.width-RESULT_COLUMNS.title.x);C.SetLineHeight(row.declined,18,true);row.declined:SetWordWrap(false);row.declined:Hide()
  row:HookScript("OnHide",function() UI:SetText(row.declined,"");row.declined:Hide() end)
  row.marks=UI.Members:CreateMarks(row);row.marks:SetPoint("LEFT",row.meta,"RIGHT",6,0)
  row:HookScript("OnHide",function(self) UI.Members:ClearMarks(self.marks) end)
  row.description=C.Text(row,"",14,T.muted,RESULT_COLUMNS.description.width,20);row.description:SetPoint("LEFT",RESULT_COLUMNS.description.x,0);row.description:SetHeight(48);row.description:SetMaxLines(2);row.description:SetWordWrap(true);row.description:SetJustifyV("MIDDLE")
  row.leaderIcon=C.Icon(row,12);row.leaderIcon:SetTexture(T.media.."leader.tga");row.leaderIcon:Hide();row.leaderIcon:SetPoint("LEFT",RESULT_COLUMNS.leader.x-17,0)
  row.leader=C.Text(row,"",14,T.muted,RESULT_COLUMNS.leader.width);row.leader:SetPoint("LEFT",RESULT_COLUMNS.leader.x,0);C.SetLineHeight(row.leader,20,true);row.leader:SetWordWrap(false)
  row.icon=C.Icon(row,36);row.icon:SetPoint("LEFT",12,0)
  row.score=C.Text(row,"",14,T.text,RESULT_COLUMNS.rating.width);C.SetLineHeight(row.score,20,true);row.score:SetPoint("LEFT",RESULT_COLUMNS.rating.x,0);row.score:SetJustifyH("CENTER");row.score:SetWordWrap(false)
  row.ilvl=C.Text(row,"",14,T.text,RESULT_COLUMNS.ilvl.width);C.SetLineHeight(row.ilvl,20,true);row.ilvl:SetPoint("LEFT",RESULT_COLUMNS.ilvl.x,0);row.ilvl:SetJustifyH("CENTER");row.ilvl:SetWordWrap(false)
  BuildMembers(row,RESULT_COLUMNS.members.x)
  row.age=C.Text(row,"",14,T.dim,RESULT_COLUMNS.age.width);row.age:SetPoint("LEFT",RESULT_COLUMNS.age.x,0);row.age:SetJustifyH("RIGHT");C.SetLineHeight(row.age,20,true);row.age:SetWordWrap(false)
  local metaTop=math.max(42,10+row.title:GetHeight()+4)
  row.meta:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-metaTop)
  row.declined:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-metaTop-row.meta:GetHeight()-4)
  row.description:SetHeight(math.max(48,row.meta:GetHeight()*2));LayoutMembers(row)
  row:SetScript("OnDoubleClick",function(b,button) if button=="LeftButton" and b.key then P:Apply(b.key) end end)
 end)
 local refreshResultsList=self.results.Refresh
 function self.results:Refresh(...)
  refreshResultsList(self,...)
  RefreshVisibleDeclines()
 end
 self.emptyPanel=CreateFrame("Frame",nil,main);self.emptyPanel:SetSize(MAIN,280);self.emptyPanel:SetPoint("CENTER",0,-12)
 self.busyIcon=C.Icon(self.emptyPanel,44);self.busyIcon:SetTexture(T.media.."lychee-logo.tga");self.busyIcon:SetPoint("TOP",self.emptyPanel,"TOP",0,-26)
 self.emptyText=C.Text(self.emptyPanel,L.findEmptyTitle,18,T.text,600);self.emptyText:SetPoint("TOP",0,-90);self.emptyText:SetJustifyH("CENTER")
 self.emptyHelp=C.Text(self.emptyPanel,"",14,T.muted,600);self.emptyHelp:SetPoint("TOP",0,-124);self.emptyHelp:SetJustifyH("CENTER")
 self.start=C.Button(self.emptyPanel,L.searchNow,140,function() if state.browseReady then P:DoSearch() else P:SelectCategory(state.category) end end);self.start:SetPrimary(true);self.start:SetPoint("TOP",self.emptyHelp,"BOTTOM",0,-24)
 main:SetScript("OnKeyDown",function(_,key)
  if UI.hiding then return end
  if key=="F10" and IsShiftKeyDown() and state.selected then P:OpenResultMenu(P.results,state.selected,false);return end
 end)
 -- Keyboard propagation cannot be changed during combat. A first build in
 -- combat remains mouse-usable; initialize shortcuts once combat ends.
 local function EnableShortcuts()
  main:SetPropagateKeyboardInput(true);main:EnableKeyboard(true)
  main:UnregisterEvent("PLAYER_REGEN_ENABLED");main:SetScript("OnEvent",nil)
 end
 if InCombatLockdown() then
  main:RegisterEvent("PLAYER_REGEN_ENABLED");main:SetScript("OnEvent",EnableShortcuts)
 else EnableShortcuts() end
 self:BuildQuickFilters()
 self:BuildSortHeaders()
 self:BuildColumnHandles()
 self:LayoutRailIcons()
 self:BuildFilters()
 for _,label in ipairs({self.membersLabel,self.maxMembersLabel,self.roleLabel,self.socialLabel,self.sortLabel}) do C.SetLineHeight(label,20,true) end
 self:BuildSidebarToggle()
 self:LayoutListRows()
end
function P:LayoutResultColumns() self:LayoutColumns() end
function P:LayoutSidebar(width)
 self.sidebarWidth=width
 MAIN=(self.layoutWidth or T.contentWidth)-width-T.contentGap-48;BODY=MAIN-LIST_GUTTER;APP_BODY=MAIN-32-LIST_GUTTER
 local compact=math.min(70,math.max(0,BASE_BODY-BODY))
 RESULT_COLUMNS.title.width=210-compact
 RESULT_COLUMNS.leader.x=303-compact;RESULT_COLUMNS.members.x=427-compact;RESULT_COLUMNS.ilvl.x=581-compact
 RESULT_COLUMNS.rating.x=649-compact;RESULT_COLUMNS.description.x=741-compact
 RESULT_COLUMNS.description.width=BODY-765-AGE_WIDTH+compact;RESULT_COLUMNS.age.x=BODY-12-AGE_WIDTH
 APPLICATION_COLUMNS.title.width=APP_BODY-591;APPLICATION_COLUMNS.leader.x=APP_BODY-522
 local alpha=math.max(0,math.min(1,(width-COLLAPSED_LEFT)/(LEFT-COLLAPSED_LEFT)))
 if math.abs(width-(state.railCollapsed and COLLAPSED_LEFT or LEFT))<1/self.rail:GetEffectiveScale() then alpha=state.railCollapsed and 0 or 1 end
 for _,list in ipairs({self.seasonCategories,self.categories}) do
  list:SetWidth(width)
  if list.indicator then list.indicator:SetWidth(width) end
  for _,row in ipairs(list.rows) do
   row.symbol:SetPoint("LEFT",12+4*alpha,0);local iconSize=T.railIconSize*math.max(75,math.min(175,tonumber(A.db.rurutiaRailIconScale) or 100))/100;row.symbol:SetSize(iconSize,iconSize)
   row.title:SetShown(alpha>0);row.title:SetAlpha(alpha);row.chevron:SetShown(alpha>0);row.chevron:SetAlpha(alpha)
  end
 end
 local buttonInset=4+4*alpha
 self.sidebarToggle:SetPoint("BOTTOMLEFT",buttonInset,8);self.sidebarToggle:SetWidth(width-buttonInset*2)
 self.sidebarToggle.label:SetShown(alpha>0);self.sidebarToggle.label:SetAlpha(alpha)
 self.surface:SetPoint("TOPLEFT",width+T.contentGap,0);self.surface:SetWidth(MAIN+48);self.main:SetWidth(MAIN)
 self.search:SetWidth(MAIN-60);self.searchHint:SetWidth(self.search:GetWidth()-52-self.searchInputRight)
 self.applicationPanel:SetWidth(MAIN);self.appList:SetWidth(MAIN-32)
 for _,row in ipairs(self.appList.rows) do
  row.title:SetWidth(APPLICATION_COLUMNS.title.width)
  row.leaderIcon:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x-17,0);row.leader:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x,0)
  row.membersX=APP_BODY-386;LayoutMembers(row);row.status:SetPoint("LEFT",APP_BODY-224,0)
 end
 self.results:SetWidth(MAIN);self.resultsHeader:SetWidth(BODY);self.emptyPanel:SetWidth(MAIN)
 self.context:SetWidth(math.min(MAIN-180,self.contextNaturalWidth or self.context:GetStringWidth()))
 self.limitNotice:SetWidth(BODY);self.limitText:SetWidth(BODY-52)
 self:LayoutResultColumns();self:LayoutQuickFilters();self:LayoutFilters()
 if self.limitNotice:IsShown() then
  local height=math.max(40,math.ceil(self.limitText:GetStringHeight())+16)
  if self.limitNotice:GetHeight()~=height then self.resultsTop=nil;self:LayoutResults() end
 end
end
function P:LayoutSize(width,height)
 self.layoutWidth,self.layoutHeight=width,height
 HEIGHT=height-48
 self.rail:SetHeight(height);self.surface:SetHeight(height);self.main:SetHeight(HEIGHT)
 local categoriesTop=self.seasonCategories:GetHeight()+24
 self.categories:SetViewport(height-categoriesTop-72)
 self:LayoutSidebar(self.rail:GetWidth())
 self.resultsTop=nil;self:LayoutResults()
end
function P:SetSidebarCollapsed(collapsed,animate)
 state.railCollapsed=collapsed==true
 local prefs=UI:GetGroup().prefs.find or {};UI:GetGroup().prefs.find=prefs;prefs.railCollapsed=state.railCollapsed
 for _,list in ipairs({self.seasonCategories,self.categories}) do if list.indicator then M:FinishRect(list.indicator) end end
 M:Rect(self.rail,0,0,state.railCollapsed and COLLAPSED_LEFT or LEFT,self.layoutHeight or T.contentHeight,animate and .18 or 0)
 self:LayoutSidebar(self.rail:GetWidth())
end
function P:FinishSidebar()
 M:FinishRect(self.rail)
end
function P:BuildSidebarToggle()
 local button=C.Button(self.rail,Say("收起","Collapse"),LEFT-16,function() P:SetSidebarCollapsed(not state.railCollapsed,true) end,{height=40,radius=8,textColor=T.muted})
 button:SetPoint("BOTTOMLEFT",8,8);button.label:ClearAllPoints();button.label:SetPoint("LEFT",44,0);self.sidebarToggle=button
 local icon=C.Icon(button,24);icon:SetPoint("LEFT",8,0)
 icon:SetTexture("Interface\\AddOns\\LycheeGroup_UI\\Media\\sidebar-toggle.tga");UI.context:SetIconState(icon,false,false);self.sidebarIcon=icon
 self.rail:HookScript("OnSizeChanged",function(_,width) P:LayoutSidebar(width) end)
 self.frame:HookScript("OnHide",function() P:FinishSidebar() end)
 UI.blocker:HookScript("OnShow",function() if UI.page=="find" then P:FinishSidebar() end end)
 M:Rect(self.rail,0,0,LEFT,T.contentHeight,0)
 self:LayoutSidebar(LEFT)
end
-- Resize the existing controls; fixed readable columns leave extra space to descriptions.
function P:LayoutWindow(width,height)
 if not self.results then return end
 MAIN=width-LEFT-T.contentGap-48;HEIGHT=height-48
 BODY=MAIN-LIST_GUTTER;APP_BODY=MAIN-32-LIST_GUTTER
 self.frame:SetSize(width,height)
 self.rail:SetHeight(height);self.surface:SetSize(MAIN+48,height);self.main:SetSize(MAIN,HEIGHT)
 self.search:SetWidth(MAIN-60);self.applicationPanel:SetWidth(MAIN)
 self.appList:SetWidth(MAIN-32);self.results:SetWidth(MAIN);self.resultsHeader:SetWidth(BODY)
 self.limitNotice:SetWidth(BODY);self.emptyPanel:SetWidth(MAIN)
 self:LayoutColumns()
 APPLICATION_COLUMNS.title.width=APP_BODY-591;APPLICATION_COLUMNS.leader.x=APP_BODY-522
 for _,row in ipairs(self.appList.rows) do
  row.title:SetWidth(APPLICATION_COLUMNS.title.width)
  row.leader:ClearAllPoints();row.leader:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x,0)
  row.leaderIcon:ClearAllPoints();row.leaderIcon:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x-17,0)
  row.membersX=APP_BODY-386;LayoutMembers(row)
  row.status:ClearAllPoints();row.status:SetPoint("LEFT",APP_BODY-224,0)
 end
 self:LayoutQuickFilters()
 self:LayoutFilters()
 self.resultsTop=nil
 self:LayoutResults()
 self.searchHint:SetWidth(self.search:GetWidth()-52-self.searchInputRight)
 if self.frame:IsShown() and state.browseReady then self:RefreshResults() end
end

function P:RefreshMemberBorders()
 if not self.results then return end
 for _,row in ipairs(self.results.rows) do
  for _,slot in ipairs(row.roster.slots) do UI:UpdateMemberBorder(slot.icon,row.isParty and slot.icon:IsShown());UI:UpdateMemberLeader(slot.icon,row.isParty and slot.icon:IsShown()) end
 end
end
function P:LayoutRailIcons()
 local size=T.railIconSize*math.max(75,math.min(175,tonumber(A.db.rurutiaRailIconScale) or 100))/100
 for _,list in ipairs({self.seasonCategories,self.categories}) do
  for _,row in ipairs(list.rows) do row.symbol:SetSize(size,size) end
 end
end

local COLUMN_MIN={210,128,154,64,80,100,88}
local function ColumnMinimum(index)
 if index==3 and Category().id~=3 then
  return math.max(154,math.ceil(98*1.2*1.15*MemberIconScale())+16)
 end
 return COLUMN_MIN[index]
end
function P:ResolveColumnWidths(body,saved)
 local defaults={291,124,154,68,92,body-841,100}
 local widths,total,weight={},0,0
 for i=1,7 do
  local value=type(saved)=="table" and tonumber(saved[i]) or defaults[i]
  if not value or value~=value or value==math.huge or value==-math.huge then value=defaults[i] end
  local minimum=ColumnMinimum(i)
  widths[i]=math.max(minimum,value);total=total+minimum;weight=weight+widths[i]-minimum
 end
 local available=math.max(0,body-12-total)
 for i=1,7 do local minimum=ColumnMinimum(i);widths[i]=minimum+available*(weight>0 and (widths[i]-minimum)/weight or 1/7) end
 return widths
end

function P:LayoutColumns(override)
 if not self.results then return end
 local raid=Category().id==3
 local mode=raid and "raid" or "party"
 local saved=type(A.db.rurutiaColumnWidths)=="table" and A.db.rurutiaColumnWidths[mode]
 if raid and type(saved)~="table" then saved={291,124,154,68,BODY-841,92,100} end
 local widths=override or self:ResolveColumnWidths(BODY,saved)
 self.columnWidths=widths;self.columnMode=mode;self.raidResultColumns=raid
 local order=raid and {"title","leader","members","ilvl","description","rating","age"} or {"title","leader","members","ilvl","rating","description","age"}
 local x=12
 for i,key in ipairs(order) do
  local col=RESULT_COLUMNS[key]
  col.x=x+(key=="title" and 48 or key=="leader" and 20 or 0)
  col.width=widths[i]-(key=="title" and 60 or key=="leader" and 28 or 12)
  local heading=self.resultHeadings[key]
  -- Keep text out of the divider hit area, including left-aligned descriptions.
  local headingX=key=="title" and x or math.max(x+8,col.x)
  heading:ClearAllPoints();heading:SetPoint("TOPLEFT",headingX,0);heading:SetWidth(x+widths[i]-12-headingX)
  local sortButton=self.sortHeaders and self.sortHeaders[key]
  if sortButton then sortButton:ClearAllPoints();sortButton:SetPoint("TOPLEFT",headingX,2);sortButton:SetSize(heading:GetWidth(),28) end
  x=x+widths[i]
  local handle=self.columnHandles and self.columnHandles[i]
  if handle then handle:ClearAllPoints();handle:SetPoint("TOPLEFT",x-4,2) end
 end
 for _,row in ipairs(self.results.rows) do
  row.title:SetWidth(RESULT_COLUMNS.title.width);row.meta:SetWidth(RESULT_COLUMNS.title.width)
  row.leader:ClearAllPoints();row.leader:SetPoint("LEFT",RESULT_COLUMNS.leader.x,0);row.leader:SetWidth(RESULT_COLUMNS.leader.width)
  row.leaderIcon:ClearAllPoints();row.leaderIcon:SetPoint("LEFT",RESULT_COLUMNS.leader.x-17,0)
  row.membersX=RESULT_COLUMNS.members.x;LayoutMembers(row)
  for key,field in pairs({ilvl="ilvl",rating="score",description="description",age="age"}) do
   local col=RESULT_COLUMNS[key];local region=row[field]
   region:ClearAllPoints();region:SetPoint("LEFT",col.x,0);region:SetWidth(col.width)
  end
 end
 self:SyncSortHeaders()
 self.results:Refresh(true)
end

-- A divider can use spare width beyond its immediate neighbour.
-- Shrink nearest columns first; keep the total width and every minimum intact.
function P:ResizeColumnWidths(original,index,delta)
 local widths={};for j,value in ipairs(original) do widths[j]=value end
 local first,last,step,receiver
 if delta>=0 then first,last,step,receiver=index+1,7,1,index
 else first,last,step,receiver=index,1,-1,index+1 end
 local remaining=math.abs(delta)
 for j=first,last,step do
  local taken=math.min(remaining,math.max(0,widths[j]-ColumnMinimum(j)))
  widths[j]=widths[j]-taken;widths[receiver]=widths[receiver]+taken
  remaining=remaining-taken
  if remaining<=0 then break end
 end
 return widths,(math.abs(delta)-remaining)*(delta>=0 and 1 or -1)
end

local SORT_HEADERS={members="members",ilvl="itemLevel",rating="rating",age="newest"}
function P:SortByHeader(key,button)
 local mode=SORT_HEADERS[key]
 if button=="RightButton" then return self:ResetSort() end
 if not mode or key=="rating" and Category().id==3 then return end
 state.filters.sortAscending=state.filters.sort==mode and not state.filters.sortAscending or false
 state.filters.sort=mode
 self:UpdateFilters(true)
end
function P:ResetSort()
 state.filters.sort=A:GetSetting("defaultSort") or "newest"
 state.filters.sortAscending=nil
 self:UpdateFilters(true)
end
function P:SyncSortHeaders()
 if not self.sortHeaders then return end
 local raid=Category().id==3
 for key,button in pairs(self.sortHeaders) do
  local enabled=not (key=="rating" and raid)
  local active=enabled and state.filters.sort==SORT_HEADERS[key]
  local base=key=="members" and L.members or key=="ilvl" and Say("装等","iLvl") or key=="rating" and (raid and Say("进度","Progress") or Say("评分","Score")) or Say("发布","Posted")
  UI:SetText(self.resultHeadings[key],base)
  UI:SetText(button.arrow,active and (state.filters.sortAscending and "▲" or "▼") or "")
  UI:Color(self.resultHeadings[key],active and T.text or T.dim)
  button:EnableMouse(enabled)
 end
 self.resetSort:SetAvailable(state.filters.sort~=(A:GetSetting("defaultSort") or "newest") or state.filters.sortAscending==true)
 if self.sortChoice then
  local labels={newest=L.newest,rating=Say("队长评分","Leader rating"),itemLevel=Say("要求装等","Required item level"),members=L.members}
  self.sortChoice:SetValue(state.filters.sort,labels[state.filters.sort] or L.newest)
 end
end
function P:BuildSortHeaders()
 self.sortHeaders={}
 for key in pairs(SORT_HEADERS) do
  local column=key
  local button=CreateFrame("Button",nil,self.resultsHeader)
  button.arrow=C.Text(button,"",10,T.accent);button.arrow:SetPoint("TOPRIGHT",0,8)
  button:RegisterForClicks("LeftButtonUp","RightButtonUp")
  button:SetScript("OnClick",function(_,mouse) P:SortByHeader(column,mouse) end)
  button:SetScript("OnEnter",function()
   GameTooltip:SetOwner(button,"ANCHOR_TOP")
   GameTooltip:SetText(Say("单击切换排序方向；右键恢复默认排序\n保留好友优先，缺失数据排在末尾。","Click to reverse sort; right-click to restore default.\nFriends first; missing values last."));GameTooltip:Show()
  end)
  local function HideTip() if GameTooltip:IsOwned(button) then GameTooltip:Hide() end end
  button:SetScript("OnLeave",HideTip);button:SetScript("OnHide",HideTip)
  self.sortHeaders[key]=button
 end
 self.resetSort=C.Button(self.main,Say("默认排序","Default sort"),104,function() P:ResetSort() end,{height=28,variant="text"})
end

function P:BuildColumnHandles()
 self.columnHandles={}
 for i=1,6 do
  local index=i
  local handle=CreateFrame("Button",nil,self.resultsHeader);handle:SetSize(8,28)
  local line=handle:CreateTexture(nil,"OVERLAY");line:SetColorTexture(unpack(T.dim));line:SetSize(1,18);line:SetPoint("CENTER");line:SetAlpha(0)
  local function Stop()
   if not handle.dragging then return end
   handle.dragging=nil;handle:SetScript("OnUpdate",nil);line:SetAlpha(handle.hovered and .65 or 0)
   if type(A.db.rurutiaColumnWidths)~="table" then A.db.rurutiaColumnWidths={} end
   local saved={};for j,value in ipairs(P.columnWidths) do saved[j]=value end
   A.db.rurutiaColumnWidths[P.columnMode]=saved
  end
  handle:SetScript("OnEnter",function() handle.hovered=true;line:SetAlpha(.65);GameTooltip:SetOwner(handle,"ANCHOR_TOP");GameTooltip:SetText(Say("拖动调整列宽；右键恢复默认","Drag to resize; right-click to reset"));GameTooltip:Show() end)
  handle:SetScript("OnLeave",function() handle.hovered=nil;line:SetAlpha(handle.dragging and .65 or 0);if GameTooltip:IsOwned(handle) then GameTooltip:Hide() end end)
  handle:SetScript("OnMouseDown",function(_,button)
   if button=="RightButton" then
    Stop();if type(A.db.rurutiaColumnWidths)=="table" then A.db.rurutiaColumnWidths[P.columnMode]=nil end
    P:LayoutColumns();return
   end
   if button~="LeftButton" or UI.hiding then return end
   UI:CloseMenu();UI.Tooltip:Hide();GameTooltip:Hide()
   local start=GetCursorPosition()/handle:GetEffectiveScale()
   local original={};for j,value in ipairs(P.columnWidths) do original[j]=value end
   handle.dragging=true;line:SetAlpha(.65)
   handle:SetScript("OnUpdate",function()
    local delta=GetCursorPosition()/handle:GetEffectiveScale()-start
    local widths; widths,delta=P:ResizeColumnWidths(original,index,delta)
    if handle.lastDelta==delta then return end
    handle.lastDelta=delta
    P:LayoutColumns(widths)
   end)
   handle.lastDelta=nil
  end)
  handle:SetScript("OnMouseUp",Stop)
  handle:SetScript("OnHide",function() handle.hovered=nil;Stop();line:SetAlpha(0);if GameTooltip:IsOwned(handle) then GameTooltip:Hide() end end)
  self.columnHandles[i]=handle
 end
end

function P:BuildQuickFilters()
 local function Tip(button,text)
  button:HookScript("OnEnter",function() GameTooltip:SetOwner(button,"ANCHOR_TOP");GameTooltip:SetText(text);GameTooltip:Show() end)
  local function Hide() if GameTooltip:IsOwned(button) then GameTooltip:Hide() end end
  button:HookScript("OnLeave",Hide);button:HookScript("OnHide",Hide)
 end
 self.quickFilters=CreateFrame("Frame",nil,self.applicationPanel)
 self.quickFilters:SetSize(444,32);self.quickChoices={}
 local roles={{"TANK","tankPresence"},{"HEALER","healerPresence"},{"DAMAGER","damagePresence"}}
 for i,entry in ipairs(roles) do
  local role,key=entry[1],entry[2]
  local button=C.Button(self.quickFilters,"",90,function(_,mouseButton)
   local value=state.filters[key]
   if mouseButton=="RightButton" then value=nil
   elseif not value then value="missing"
   elseif value=="missing" then
    local presentCount=(state.filters.tankPresence=="present" and 1 or 0)+(state.filters.healerPresence=="present" and 1 or 0)+(state.filters.damagePresence=="present" and 1 or 0)
    value=(state.filters.roleMatchAny or presentCount<2) and "present" or nil
   else value=nil end
   state.filters[key]=value;P:UpdateFilters()
  end,{height=32,radius=8})
  button:RegisterForClicks("LeftButtonUp","RightButtonUp")
  Tip(button,Say("左键切换，右键恢复","Left-click to cycle; right-click to reset."))
  button:SetPoint("LEFT",(i-1)*96,0)
  local icon=C.Icon(button,18);icon:SetPoint("LEFT",8,0);UI:SetRoleIcon(icon,role)
  button.label:ClearAllPoints();button.label:SetPoint("LEFT",32,0);C.SetFont(button.label,13)
  self.quickChoices[key]={button=button,role=role}
 end
 self.quickLogic=C.Button(self.quickFilters,"",80,function()
  state.filters.roleMatchAny=not state.filters.roleMatchAny or nil
  if not state.filters.roleMatchAny and state.filters.tankPresence=="present" and state.filters.healerPresence=="present" and state.filters.damagePresence=="present" then state.filters.damagePresence=nil end
  P:UpdateFilters()
 end,{height=32,radius=8})
 Tip(self.quickLogic,Say("筛选切换：全部/任意条件符合","Filter matching: all/any conditions."))
 self.quickLogic:SetPoint("LEFT",288,0);C.SetFont(self.quickLogic.label,13)
 local function QuickToggle(label,key)
  local toggle=C.Check(self.quickFilters,label,function(value) state.filters[key]=value or nil;P:UpdateFilters() end)
  toggle:SetHeight(32);C.SetFont(toggle.label,13)
  toggle.label:ClearAllPoints();toggle.label:SetPoint("LEFT")
  toggle.track:ClearAllPoints();toggle.track:SetPoint("RIGHT")
  return toggle
 end
 self.quickSame=QuickToggle(Say("同专精过滤","Same spec"),"hideSameSpec")
 self.quickClass=QuickToggle(Say("同职过滤","Same class"),"hideSameClass")
end

function P:SyncQuickFilters(seasonDungeon)
 self.quickFilters:SetShown(seasonDungeon)
 for key,entry in pairs(self.quickChoices) do
  local value=state.filters[key]
  UI:SetText(entry.button.label,value=="missing" and Say("缺少","Lacks") or value=="present" and (entry.role=="DAMAGER" and Say("已齐","Full") or Say("已有","Has")) or Say("不限","Any"))
  entry.button:SetActive(value~=nil and value~=false)
 end
 UI:SetText(self.quickLogic.label,state.filters.roleMatchAny and Say("或","OR") or Say("全部","All"))
 self.quickLogic:SetActive(state.filters.roleMatchAny==true)
 self.quickSame:SetValue(state.filters.hideSameSpec)
 self.quickClass:SetValue(state.filters.hideSameClass)
 self:LayoutQuickFilters()
 self:LayoutResults()
end

function P:LayoutQuickFilters()
 if not self.quickFilters then return end
 local left=16+self.appsTitle:GetStringWidth()+10+48+12
 if self.appsEmpty:IsShown() then left=left+self.appsEmpty:GetStringWidth()+20
 elseif self.scopeToggle:IsShown() then left=left+self.scopeToggle:GetWidth()+20 end
 local right=16+self.autoJoin:GetWidth()+20+44+10+self.applicationSettings:GetWidth()+20
 local needed=376
 for _,toggle in ipairs({self.quickSame,self.quickClass}) do
  local width=toggle.label:GetStringWidth()+54
  toggle:SetWidth(width);toggle:ClearAllPoints();toggle:SetPoint("LEFT",needed,0)
  needed=needed+width+16
 end
 needed=needed-16
 self.quickFilters:SetWidth(needed)
 local extra=self.quickFilters:IsShown() and (MAIN-left-right<needed) and 40 or 0
 self.quickFilters:ClearAllPoints();self.quickFilters:SetPoint("TOPLEFT",extra>0 and 16 or left,extra>0 and -46 or -6)
 self.quickFilterHeight=extra
 self.applicationPanel:SetHeight(44+(self.appsHeight or 0)+extra)
 self.appList:ClearAllPoints();self.appList:SetPoint("TOPLEFT",16,-40-extra)
 self.resultsTop=nil
end

local advancedKeys={"minItemLevel","maxItemLevel","minRating","maxRating","blockedKeywords","blockedKeywordsText"}
function P:ParseAdvancedFilters(values,text)
 local parsed={}
 for i=1,4 do
  local key=advancedKeys[i];local raw=tostring(values[key] or ""):match("^%s*(.-)%s*$")
  if raw~="" then
   local value=tonumber(raw)
   if not value or value~=value or value<0 or value>99999 or value%1~=0 then return nil,Say("请输入0至99999的整数，或留空。","Enter an integer from 0 to 99999, or leave blank.") end
   parsed[key]=value
  end
 end
 if parsed.minItemLevel and parsed.maxItemLevel and parsed.minItemLevel>parsed.maxItemLevel or parsed.minRating and parsed.maxRating and parsed.minRating>parsed.maxRating then
  return nil,Say("最低值不能大于最高值。","Minimum must not exceed maximum.")
 end
 local words,lines,seen={},{},{}
 for line in (text or ""):gmatch("[^\r\n]+") do
  local trimmed=line:match("^%s*(.-)%s*$");local word=trimmed:lower()
  if word~="" and not seen[word] then seen[word]=true;words[#words+1]=word;lines[#lines+1]=trimmed end
 end
 if #words>100 then return nil,Say("最多填写100个屏蔽词。","Use at most 100 keywords.") end
 if #words>0 then parsed.blockedKeywords=words;parsed.blockedKeywordsText=table.concat(lines,"\n") end
 return parsed
end
function P:SyncFilterFields()
 if not self.filterFields then return end
 self.syncingFilterFields=true
 for key,field in pairs(self.filterFields) do field.box:SetText(state.filters[key] and tostring(state.filters[key]) or "") end
 self.filterWords.box:SetText(state.filters.blockedKeywordsText or "")
 UI:SetText(self.filterError,"");self.syncingFilterFields=nil
end
function P:ApplyFilterFields()
 if self.loading or self.syncingFilterFields then return true end
 local values={};for key,field in pairs(self.filterFields) do values[key]=field.box:GetText() end
 local parsed,err=self:ParseAdvancedFilters(values,self.filterWords.box:GetText())
 UI:SetText(self.filterError,err or "")
 if not parsed then return false end
 for _,key in ipairs(advancedKeys) do state.filters[key]=parsed[key] end
 self:UpdateFilters();return true
end

function P:BuildFilters()
 local f=CreateFrame("Frame",nil,UI.frame);f:SetSize(368,744);f:SetPoint("TOPRIGHT",UI.frame,"TOPRIGHT",-20,-76);f:SetFrameLevel(UI.frame:GetFrameLevel()+5);f:SetFrameStrata("DIALOG");C.Panel(f,T.panel,28);self.filterPanel=f
 f:SetClampedToScreen(true);f:EnableMouse(true)
 local scrim=CreateFrame("Button",nil,UI.frame);scrim:SetAllPoints(UI.frame);scrim:SetFrameStrata("DIALOG");scrim:SetFrameLevel(UI.frame:GetFrameLevel()+4)
 C.Fill(scrim,{0,0,0,.18});scrim:SetScript("OnClick",function() P:SetFiltersOpen(false) end);scrim:Hide()
 f:HookScript("OnShow",function() scrim:Show() end)
 f:HookScript("OnHide",function() scrim:Hide();P.filtersOpen=false end)
 self.filterTitle=C.Text(f,Say("筛选队伍","Filter groups"),20);C.SetLineHeight(self.filterTitle,24,true)
 local close=C.IconButton(f,"close",36,function() P:SetFiltersOpen(false) end,{iconSize=20});close:SetPoint("TOPRIGHT",-14,-14)
 self.filterStatus=C.Text(f,"",14,T.dim,240);C.SetLineHeight(self.filterStatus,20,true)
 self.clearFilters=C.Button(f,Say("重置","Reset"),72,function() P:ClearFilters() end,{variant="text",height=32})
 local function Changed() if not P.loading then P:UpdateFilters() end end
 self.filterFields={}
 for i=1,4 do
  local field=C.Number(f,76,34,function() if P.filterWords then P:ApplyFilterFields() end end)
  field.box:SetMaxLetters(5);field:SetPlaceholder(i%2==1 and Say("最低","Min") or Say("最高","Max"));self.filterFields[advancedKeys[i]]=field
 end
 self.ilvlLabel=C.Text(f,Say("要求装等","Required item level"),14,T.muted,160)
 self.ratingLabel=C.Text(f,Say("队长评分","Leader rating"),14,T.muted,160)
 self.filterWordsLabel=C.Text(f,Say("屏蔽标题/备注 · 每行一个词","Block title/notes · one keyword per line"),14,T.muted,512)
 self.filterWords=C.Edit(f,512,76,true);self.filterWords.box:SetMaxLetters(4000)
 self.filterWords:SetPlaceholder(Say("包含任意一个词即隐藏；英文不分大小写。","Hide if any keyword matches; case-insensitive."))
 self.filterWords.box:HookScript("OnTextChanged",function(_,userInput) if userInput then P:ApplyFilterFields() end end)
 self.filterError=C.Text(f,"",13,T.warning,512,28)
 self.filterDone=C.Button(f,Say("完成","Done"),88,function() if P:ApplyFilterFields() then P:SetFiltersOpen(false) end end,{height=34});self.filterDone:SetPrimary(true)
 self.membersLabel=C.Text(f,Say("队伍人数","Group size"),14,T.muted,160)
 self.maxMembersLabel=C.Text(f,Say("最多人数","Max. players"),14,T.muted,164)
 self.fMinMembers=C.Number(f,76,34,Changed);self.fMembers=C.Number(f,76,34,Changed)
 self.fMinMembers:SetPlaceholder(Say("最少","Min"));self.fMembers:SetPlaceholder(Say("最多","Max"));self.maxMembersLabel:Hide()
 self.roleLabel=C.Text(f,Say("队伍缺少职责","Role needed"),14,T.muted,344)
 self.roleChoice=C.Choice(f,244,{{value=false,label=L.anyRole},{value="TANK",label=L.tank},{value="HEALER",label=L.healer},{value="DAMAGER",label=L.damage}},function(value) state.filters.neededRole=value or nil;P:UpdateFilters() end)
 self.filterDivider=f:CreateTexture(nil,"ARTWORK");self.filterDivider:SetColorTexture(unpack(T.field));self.filterDivider:SetSize(344,1)
 self.hideZeroScore=C.Check(f,Say("过滤队长 0 分队伍","Hide 0-score leaders"),function(value) state.filters.hideZeroScore=value or nil;P:UpdateFilters() end)
 for _,toggle in ipairs({self.hideZeroScore}) do
  toggle:SetSize(244,30);C.SetFont(toggle.label,14);C.SetLineHeight(toggle.label,20,true)
  toggle.label:ClearAllPoints();toggle.label:SetPoint("LEFT");toggle.label:SetWidth(190)
  toggle.track:ClearAllPoints();toggle.track:SetPoint("RIGHT")
 end
 self.socialLabel=C.Text(f,Say("关系与笔记","Relations and notes"),14,T.muted)
 self.socialChoice=C.Choice(f,244,{{value=false,label=Say("全部关系","All relations")},{value="friend",label=Say("好友在队","Friends in group")},{value="guild",label=Say("同公会成员","Guildmates")},{value="any",label=Say("含笔记记录","With player notes")},{value="positive",label=Say("含推荐玩家","Recommended players")},{value="noCaution",label=Say("不含拉黑记录","Without blocked players")}},function(value) state.social=value or nil;P:UpdateFilters() end)
 self.sortLabel=C.Text(f,L.sort,14,T.muted)
 self.sortChoice=C.Choice(f,244,{{value="newest",label=L.newest},{value="rating",label=Say("队长评分","Leader rating")},{value="itemLevel",label=Say("要求装等","Required item level")},{value="members",label=L.members}},function(value) state.filters.sort=value;state.filters.sortAscending=nil;P:UpdateFilters() end)
 f:Hide()
end
function P:LayoutFilters()
 if not self.filterPanel then return end
 local function Place(frame,x,y) frame:ClearAllPoints();frame:SetPoint("TOPLEFT",x,-y) end
 local width,inner=368,328
 self.filterPanel:SetWidth(width)
 Place(self.filterTitle,20,18);Place(self.filterStatus,20,48);self.filterStatus:SetWidth(244)
 self.clearFilters:SetWidth(72);Place(self.clearFilters,276,44)
 local y=90
 local fieldHeight=math.max(36,math.ceil(self.socialChoice.label:GetHeight()+12))
 -- Final requested order: leader rating, required item level, then group size.
 for _,row in ipairs({
  {self.ratingLabel,self.filterFields.minRating,self.filterFields.maxRating},
  {self.ilvlLabel,self.filterFields.minItemLevel,self.filterFields.maxItemLevel},
  {self.membersLabel,self.fMinMembers,self.fMembers},
 }) do
  row[1]:SetWidth(100)
  local h=math.max(fieldHeight,row[1]:GetHeight())
  Place(row[1],20,y+(h-row[1]:GetHeight())/2)
  for i=2,3 do row[i]:SetWidth(104);row[i]:SetHeight(h);Place(row[i],132+(i-2)*112,y) end
  y=y+h+12
 end
 for _,row in ipairs({{self.socialLabel,self.socialChoice},{self.sortLabel,self.sortChoice}}) do
  row[1]:SetWidth(inner);Place(row[1],20,y);y=y+math.max(20,row[1]:GetHeight())+6
  row[2]:SetWidth(inner);row[2]:SetHeight(fieldHeight);Place(row[2],20,y);y=y+fieldHeight+14
 end
 if self.filterLayout=="presence" then
  self.hideZeroScore:SetWidth(inner);self.hideZeroScore.label:SetWidth(inner-54)
  local h=math.max(30,self.hideZeroScore.label:GetHeight());self.hideZeroScore:SetHeight(h)
  Place(self.hideZeroScore,20,y);y=y+h+12
 elseif self.filterLayout=="needed" then
  self.roleLabel:SetWidth(inner);Place(self.roleLabel,20,y);y=y+math.max(20,self.roleLabel:GetHeight())+6
  self.roleChoice:SetWidth(inner);self.roleChoice:SetHeight(fieldHeight);Place(self.roleChoice,20,y);y=y+fieldHeight+12
 end
 Place(self.filterDivider,20,y);self.filterDivider:SetWidth(inner);y=y+12
 self.filterWordsLabel:SetWidth(inner);Place(self.filterWordsLabel,20,y);y=y+math.max(20,self.filterWordsLabel:GetHeight())+6
 local height=math.max(UI.frame:GetHeight()-96,y+76+10+36+34+20)
 self.filterPanel:SetHeight(height)
 local footerY=height-54
 self.filterWords:SetWidth(inner);self.filterWords:SetHeight(footerY-46-y);Place(self.filterWords,20,y)
 if self.filterWords.placeholder then self.filterWords.placeholder:SetWidth(inner-24) end
 self.filterError:SetWidth(inner);self.filterError:SetHeight(36);Place(self.filterError,20,footerY-36)
 Place(self.filterDone,width-20-88,footerY)
end
function P:UpdateFilterSummary()
 local filters=state.filters
 local count=(filters.minMembers or filters.maxMembers) and 1 or 0
 local advanced=(filters.minItemLevel or filters.maxItemLevel) and 1 or 0
 if filters.minRating or filters.maxRating then advanced=advanced+1 end
 if filters.blockedKeywords and #filters.blockedKeywords>0 then advanced=advanced+1 end
 count=count+advanced
 for _,key in ipairs({"neededRole","tankPresence","healerPresence","damagePresence","hideZeroScore","hideSameSpec","hideSameClass"}) do if filters[key] then count=count+1 end end
 if state.social then count=count+1 end
 local sortChanged=filters.sort~=A:GetSetting("defaultSort")
 self.filterCount=count
 UI:SetText(self.filterToggle.label,count>0 and Say("筛选 ","Filters ")..count or Say("筛选","Filters"))
 self.filterToggle:SetTextColors(count>0 and T.brand or T.muted,T.text,T.onSecondaryContainer)
 UI:SetText(self.filterStatus,count>0 and Say("已启用 %d 项","%d active filters"):format(count) or sortChanged and Say("已更改排序","Sort changed") or Say("未启用条件","No active filters"))
 self.clearFilters:SetAvailable(count>0 or sortChanged)
end
function P:SetFiltersOpen(open)
 local wasOpen=self.filterPanel:IsShown()
 self.filtersOpen=open==true
 if self.filtersOpen and not wasOpen then self:SyncFilterFields();self:LayoutFilters() end
 if not self.filtersOpen then M:FinishPlacement(self.filterPanel) end
 self.filterPanel:SetShown(self.filtersOpen);self:ClosePicker();UI.Tooltip:Hide()
 UI:FitToScreen()
 self.filterToggle:SetActive(self.filtersOpen);self.filterChevron:SetRotation(self.filtersOpen and math.pi or 0);self.filterChevron:SetVertexColor(unpack(self.filtersOpen and T.accent or T.muted))
 if self.filtersOpen and not wasOpen then M:Reveal(self.filterPanel,"TOPRIGHT",UI.frame,"TOPRIGHT",-20,-76,8,0,.18) end
end
function P:TierItems()
 local catalog=UI:GetGroup().Catalog;local used
 if Category().id==121 then
  used={};for _,group in ipairs(catalog:GetGroups(state.category)) do if group.tier then used[group.tier]=true end end
 end
 local items={{value=false,label=Say("全部资料片","All expansions")}}
 for _,tier in ipairs(catalog:GetTiers()) do if not used or used[tier.id] then items[#items+1]={value=tier.id,label=tier.name} end end
 return items
end
function P:BuildPicker()
 local f=CreateFrame("Frame",nil,self.frame);f:SetSize(336,552);f:SetPoint("TOPLEFT",self.rail,"TOPRIGHT",PICKER_GAP,0);f:SetFrameLevel(self.frame:GetFrameLevel()+35);f:EnableMouse(true);C.Panel(f,T.surface,12);self.picker=f
 f.title=C.Text(f,"",14,T.text,220);C.SetLineHeight(f.title,21,true);f.title:SetPoint("TOPLEFT",12,-18)
 local close=C.IconButton(f,"close",40,function() P:ClosePicker() end);close:SetPoint("TOPRIGHT",-12,-8)
 self.tierChoice=C.Choice(f,280,function() return P:TierItems() end,function(value)
  state.browseReady=false;UI:GetGroup().Search:EndBrowse()
  state.tier=value or nil;state.groupKey,state.groupKeys=nil,nil;P.draftGroupKeys=nil;state.difficultyID=nil
  P:RefreshPicker();P.results:SetPixelOffset(0,false);P:UpdateFilters(true)
 end);self.tierChoice:SetHeight(44);self.tierChoice:SetPoint("TOPLEFT",8,-64)
 self.tierChoice:SetSurfaceVariant("dark")
 self.difficultySurface=CreateFrame("Frame",nil,f);self.difficultySurface:SetSize(280,36);C.Panel(self.difficultySurface,T.surfaceLow,8)
 self.difficultySelection=C.Selection(self.difficultySurface)
 self.difficultyButtons={}
 for i=1,12 do self.difficultyButtons[i]=C.Button(self.difficultySurface,"",60,function(button) state.difficultyID=button.value or nil;P:RefreshPicker();P.results:SetPixelOffset(0,false);if state.browseReady then P:CommitChoice();P:DoSearch(true) else P:UpdateFilters(true) end end,{variant="compact",selectionFill=false}) end
 self.activities=C.List(f,280,440,48,function(key)
  if P.keystoneGroups and P.keystoneGroups[key] then P:ToggleGroupChoice(key);return end
  state.groupKeys=nil;P.draftGroupKeys=nil
  state.groupKey=key~=0 and key or nil
  local valid=not state.difficultyID
  for _,activity in ipairs(UI:GetGroup().Catalog:GetActivities(state.category)) do if (not state.groupKey or UI:GetGroup().Catalog:GetGroupKey(state.category,activity)==state.groupKey) and activity.difficultyID==state.difficultyID then valid=true;break end end
  if not valid then state.difficultyID=nil end
  P:RefreshPicker();P:CommitChoice();P.results:SetPixelOffset(0,false);P:DoSearch()
 end)
 self.activities:SetStyle({alternateRows=false,rowHeight=44,radius=8,singleLine=true,titleX=48,titleWidth=200,titleSize=16,titleLineHeight=22})
 self.activityIDs={};self.activityMap={}
 for _,row in ipairs(self.activities.rows) do
  row.icon=C.Icon(row,24);row.icon:SetPoint("LEFT",12,0)
  row.multiSelect=C.Checkbox(row,function() P:ToggleGroupChoice(row.key) end);row.multiSelect:SetPoint("RIGHT",-6,0)
 end
 self.pickerConfirm=C.Button(f,Say("确定","Confirm"),280,function()
  state.groupKeys=CopyGroupKeys(P.draftGroupKeys);state.groupKey=nil;P:CommitChoice()
  P.results:SetPixelOffset(0,false);P:DoSearch()
 end);self.pickerConfirm:SetPrimary(true);self.pickerConfirm:SetHeight(40);self.pickerConfirm:Hide()
 f:SetScript("OnEvent",function()
  local insideMenu=UI.context:IsMenuHovered(P.tierChoice)
  if not f:IsMouseOver() and not P.rail:IsMouseOver() and not insideMenu then P:ClosePicker() end
 end)
 f:Hide()
end
function P:PositionPicker()
 local top=8
 for i,key in ipairs(self.seasonIDs) do if key==state.category then top=8+(i-1)*52 end end
 for i,key in ipairs(self.catIDs) do if key==state.category then top=128+(i-1)*52 end end
 local y=math.max(10,math.min(top,T.contentHeight-self.picker:GetHeight()-10))
 if M.placements[self.picker] then M:Reveal(self.picker,"TOPLEFT",self.rail,"TOPRIGHT",PICKER_GAP,-y,0,8,.16)
 elseif self.pickerY~=y then self.picker:SetPoint("TOPLEFT",self.rail,"TOPRIGHT",PICKER_GAP,-y) end
 self.pickerY=y
end
function P:ClosePicker()
 if self.picker then M:FinishPlacement(self.picker);self.picker:UnregisterEvent("GLOBAL_MOUSE_DOWN");self.picker:Hide() end
 if not state.browseReady and state.confirmedChoice then
  local choice=state.confirmedChoice
  state.groupKey,state.groupKeys,state.difficultyID,state.tier=choice.groupKey,CopyGroupKeys(choice.groupKeys),choice.difficultyID,choice.tier
  self.restoringChoice=true;self:RefreshPicker()
  if self.unsub then self:UpdateFilters() end
 end
 self.draftGroupKeys=nil
 if self.picker then self.pickerConfirm:Hide() end
end
function P:ToggleGroupChoice(key)
 self.draftGroupKeys[key]=not self.draftGroupKeys[key] or nil
 self:RefreshPicker()
end
function P:KeystoneGroups()
 if Category().id~=2 or not state.difficultyID then return nil end
 local catalog=UI:GetGroup().Catalog;local keys={}
 for _,activity in ipairs(catalog:GetActivities(state.category)) do
  if activity.isMythicPlusActivity and activity.difficultyID==state.difficultyID and (not state.tier or catalog:GetActivityTier(activity)==state.tier) then keys[catalog:GetGroupKey(state.category,activity)]=true end
 end
 return next(keys) and keys or nil
end
function P:RefreshPicker()
 local cat=Category()
 if state.groupKey and not UI:GetGroup().Catalog:GetGroup(state.category,state.groupKey) then state.groupKey=nil;state.browseReady=false end
 local useTiers=not cat.season and (cat.id==2 or cat.id==3 or cat.id==121)
 local tierName=state.tier and UI:GetGroup().Catalog:GetTierName(state.tier)
 if cat.id==121 and state.tier then
  local valid=false;for _,item in ipairs(self:TierItems()) do if item.value==state.tier then valid=true;break end end
  if not valid then tierName=nil end
 end
 if not tierName then state.tier=nil end
 local diffs,seen={{id=false,name=L.all}},{}
 for _,activity in ipairs(UI:GetGroup().Catalog:GetActivities(state.category)) do
  if (not state.groupKey or UI:GetGroup().Catalog:GetGroupKey(state.category,activity)==state.groupKey) and (not state.tier or UI:GetGroup().Catalog:GetActivityTier(activity)==state.tier) then
   local id=activity.difficultyID
   local name=id and id>0 and GetDifficultyInfo(id)
   if name and not seen[id] then seen[id]=true;diffs[#diffs+1]={id=id,name=name} end
  end
 end
 local chooseDifficulty=cat.id~=121 and #diffs>1
 if not chooseDifficulty or not seen[state.difficultyID] then state.difficultyID=nil end
 local multiGroups=self:KeystoneGroups();self.keystoneGroups=multiGroups
 for _,keys in ipairs({state.groupKeys or false,self.draftGroupKeys or false}) do
  if keys then for key in pairs(keys) do if not multiGroups or not multiGroups[key] then keys[key]=nil end end end
 end
 if state.groupKeys and not next(state.groupKeys) then state.groupKeys=nil;state.browseReady=false end
 if not multiGroups then self.draftGroupKeys=nil end
 if self.restoringChoice then
  local choice=state.confirmedChoice
  state.browseReady=state.groupKey~=nil or state.groupKeys~=nil or choice.selected==true and not (choice.groupKey or choice.groupKeys)
  state.confirmedChoice=ChoiceSnapshot(state);self.restoringChoice=nil
 end
 if not self.picker then return end
 if multiGroups and not self.draftGroupKeys then
  self.draftGroupKeys=CopyGroupKeys(state.groupKeys) or {}
  if state.groupKey and multiGroups[state.groupKey] then self.draftGroupKeys[state.groupKey]=true end
 end
 UI:SetText(self.picker.title,cat.name)
 self.tierChoice:SetShown(useTiers);self.tierChoice:SetValue(state.tier or false,tierName or Say("全部资料片","All expansions"))
 local top=useTiers and 120 or 64
 self.difficultySurface:SetShown(chooseDifficulty)
 self.difficultySurface:ClearAllPoints();self.difficultySurface:SetPoint("TOPLEFT",8,-top)
 local total=0
 for i,d in ipairs(diffs) do local button=self.difficultyButtons[i];if button then UI:SetText(button.label,d.name);button.textWidth=FitText(button.label);button.optionWidth=button.textWidth+20;total=total+button.optionWidth end end
 -- Difficulty names remain complete; the native menu grows to its real content width.
 local menuWidth=chooseDifficulty and math.max(336,total+math.max(0,#diffs-1)*4+22) or 336
 self.picker:SetWidth(menuWidth);self.picker.title:SetWidth(menuWidth-76);self.tierChoice:SetWidth(menuWidth-16);self.difficultySurface:SetWidth(menuWidth-16)
 self.activities:SetWidth(menuWidth-16)
 local extra=chooseDifficulty and (self.difficultySurface:GetWidth()-6-math.max(0,#diffs-1)*4-total)/#diffs or 0
 local x=3
 for i,button in ipairs(self.difficultyButtons) do
  local d=diffs[i];button:SetShown(chooseDifficulty and d~=nil)
  if d then
   button:ClearAllPoints();button:SetPoint("LEFT",x,0);button:SetWidth(button.optionWidth+extra);button.value=d.id;button:SetActive(state.difficultyID==d.id or not state.difficultyID and not d.id)
   if chooseDifficulty and button.active then self.difficultySelection:Select(x,-3,button:GetWidth(),button:GetHeight(),self.picker:IsVisible()) end
   x=x+button:GetWidth()+4
  end
 end
 if not chooseDifficulty then self.difficultySelection:Clear() end
 if chooseDifficulty then top=top+48 end;wipe(self.activityIDs);wipe(self.activityMap)
 if cat.id~=9 then self.activityIDs[#self.activityIDs+1]=0 end
 for _,group in ipairs(UI:GetGroup().Catalog:GetGroups(state.category)) do if not state.tier or group.tier==state.tier then self.activityMap[group.key]=group;self.activityIDs[#self.activityIDs+1]=group.key end end
 local confirm=multiGroups and next(self.draftGroupKeys)~=nil
 local contentHeight=math.max(1,#self.activityIDs*48-4);local listHeight=math.min(440,contentHeight)
 self.activities:SetGutter(contentHeight>listHeight and C.listRightInset or 0)
 self.activities:ClearAllPoints();self.activities:SetPoint("TOPLEFT",8,-top);self.activities:SetViewport(listHeight);self.picker:SetHeight(top+listHeight+(confirm and 64 or 8))
 self.pickerConfirm:SetShown(confirm);self.pickerConfirm:SetWidth(menuWidth-16);self.pickerConfirm:ClearAllPoints();self.pickerConfirm:SetPoint("TOPLEFT",8,-top-listHeight-8)
 if state.groupKeys then self.activities.selectedKey=nil else self.activities.selectedKey=state.groupKey or 0 end
 self.activities:SetItems(self.activityIDs,function(row,key)
  local group=self.activityMap[key];UI:SetText(row.title,group and group.name or AllActivitiesLabel(cat));row.icon:Show();if group then UI:SetActivityIcon(row.icon,group.activity) else row.icon:SetTexture(UI:CategoryIcon(cat.icon));row.icon:SetTexCoord(0,1,0,1) end
  local selectable=multiGroups and multiGroups[key]
  row.multiSelect:SetShown(selectable or false)
  local checked=self.draftGroupKeys or state.groupKeys
  row.multiSelect:SetValue(checked and checked[key] or false)
  row.title:SetWidth(row:GetWidth()-60-(selectable and 32 or 0))
 end)
 self:PositionPicker()
end
function P:RefreshCategories()
 wipe(self.catIDs);wipe(self.seasonIDs);wipe(self.catMap)
 for _,cat in ipairs(UI:GetGroup().Catalog:GetCategories()) do
  local ids=cat.season and self.seasonIDs or self.catIDs;ids[#ids+1]=cat.key;self.catMap[cat.key]=cat
 end
 if not self.catMap[state.category] then state.category=self.seasonIDs[1] or self.catIDs[1] end
 local function RenderCategory(row,key)
  local cat=self.catMap[key];UI:SetText(row.title,cat.name);if row.kind~=cat.icon then row.kind=cat.icon;row.symbol:SetTexture(UI:CategoryIcon(cat.icon)) end
 end
 self.seasonCategories.selectedKey=state.category;self.categories.selectedKey=state.category
 self.seasonCategories:SetItems(self.seasonIDs,RenderCategory);self.categories:SetItems(self.catIDs,RenderCategory)
end
function P:SelectCategory(key,row)
 local changed=state.category~=key
 if changed then
  self:RememberCategory()
  self.draftGroupKeys=nil
  state.browseReady=false;UI:GetGroup().Search:EndBrowse()
  state.category=key;state.searchMode="group";local prefs=A:GetSetting("rememberFilters") and state.categoryPrefs[key]
  state.groupKey=prefs and prefs.groupKey or nil;state.tier=prefs and prefs.tier;state.difficultyID=prefs and prefs.difficultyID
  self:RestoreCategory(prefs or {})
  self.loading=true;state.personKey=nil
  if UI.preview then self.previewSearchBox:SetText("") else
   UI.Native:UseLeaderSearch()
   self.search.box=self.previewSearchBox;self.previewSearchBox:Show();self.previewSearchBox:SetText("")
  end
  self.loading=nil
 end
 self.seasonCategories.selectedKey=state.category;self.categories.selectedKey=state.category
 self.seasonCategories:Refresh();self.categories:Refresh()
 if not self.picker then self:BuildPicker() end
 if changed or not self.picker:IsShown() then
  self.draftGroupKeys=nil
 end
 self:RefreshPicker();self:UpdateFilters(true)
 if changed or not self.picker:IsShown() then self.picker:Show();self.picker:RegisterEvent("GLOBAL_MOUSE_DOWN");M:Reveal(self.picker,"TOPLEFT",self.rail,"TOPRIGHT",PICKER_GAP,-self.pickerY,0,8,.16) else self:ClosePicker() end
 if changed and state.browseReady then self:DoSearch(true) end
end
function P:RememberCategory()
 if not A:GetSetting("rememberFilters") then return end
 local prefs=state.categoryPrefs[state.category] or {};state.categoryPrefs[state.category]=prefs
 local choice=state.confirmedChoice or {}
 prefs.groupKey,prefs.tier,prefs.difficultyID=choice.groupKey,choice.tier,choice.difficultyID
 prefs.groupKeys=CopyGroupKeys(choice.groupKeys)
 prefs.selected=choice.selected==true
 prefs.minLevel,prefs.maxLevel=nil,nil;prefs.minMembers=self.fMinMembers.box:GetText();prefs.maxMembers=self.fMembers.box:GetText()
 local cat=Category();local seasonDungeon=cat.id==2 and cat.season
 prefs.neededRole=not seasonDungeon and self.roleChoice.value or nil
 prefs.tankPresence,prefs.healerPresence,prefs.damagePresence=state.filters.tankPresence,state.filters.healerPresence,state.filters.damagePresence
 prefs.hideZeroScore=state.filters.hideZeroScore
 prefs.hideSameSpec=state.filters.hideSameSpec
 prefs.hideSameClass=state.filters.hideSameClass
 prefs.roleMatchAny=state.filters.roleMatchAny
 for _,key in ipairs(advancedKeys) do prefs[key]=state.filters[key] end
 prefs.social=state.social;prefs.sort=state.filters.sort;prefs.sortAscending=state.filters.sortAscending
end
function P:RestoreCategory(prefs)
 self.loading=true
 for _,key in ipairs(advancedKeys) do state.filters[key]=prefs[key] end
 state.groupKeys=CopyGroupKeys(prefs.groupKeys)
 state.confirmedChoice=ChoiceSnapshot(prefs);self.restoringChoice=true
 self.fMinMembers.box:SetText(prefs.minMembers or "")
 self.fMembers.box:SetText(prefs.maxMembers or "")
 local cat=Category();local seasonDungeon=cat and cat.id==2 and cat.season
 local role=not seasonDungeon and prefs.neededRole or nil
 if seasonDungeon then
  prefs.tankPresence=prefs.tankPresence or prefs.neededRole=="TANK" and "missing" or nil
  prefs.healerPresence=prefs.healerPresence or prefs.neededRole=="HEALER" and "missing" or nil
  prefs.damagePresence=prefs.damagePresence or (prefs.needsDamage or prefs.neededRole=="DAMAGER") and "missing" or nil
  prefs.neededRole=nil
  if not prefs.roleMatchAny and prefs.tankPresence=="present" and prefs.healerPresence=="present" and prefs.damagePresence=="present" then prefs.damagePresence=nil end
 end
 prefs.needsDamage=nil
 state.filters.tankPresence=seasonDungeon and prefs.tankPresence or nil
 state.filters.healerPresence=seasonDungeon and prefs.healerPresence or nil
 state.filters.damagePresence=seasonDungeon and prefs.damagePresence or nil
 state.filters.hideZeroScore=seasonDungeon and prefs.hideZeroScore or nil
 state.filters.hideSameSpec=seasonDungeon and prefs.hideSameSpec or nil
 state.filters.hideSameClass=seasonDungeon and prefs.hideSameClass or nil
 state.filters.roleMatchAny=seasonDungeon and prefs.roleMatchAny==true or nil
 self.roleChoice:SetValue(role or false,role and ({TANK=L.tank,HEALER=L.healer,DAMAGER=L.damage})[role] or L.anyRole)
 state.social=prefs.social=="caution" and "noCaution" or prefs.social;self.socialChoice:SetValue(state.social or false,state.social and ({friend=L.friendChar,guild=L.friendGuild,any=L.notes,positive=Say("含推荐玩家","Recommended players"),noCaution=Say("不含拉黑记录","Without blocked players")})[state.social] or Say("全部关系","All relations"))
 state.filters.sortAscending=prefs.sortAscending==true
 state.filters.sort=prefs.sort or A:GetSetting("defaultSort");self.sortChoice:SetValue(state.filters.sort,L[state.filters.sort] or L.newest)
 self.loading=nil
end
function P:SyncSearchInputMode()
 if not self.search or not self.searchModeToggle then return false end
 local wantsNative=state.searchMode=="group"
 self.searchModeToggle:Show()
 self.searchModeToggle:SetActive(state.searchMode=="leader")
 UI:SetText(self.searchModeToggle.label,state.searchMode=="leader" and Say("队长","Leader") or Say("标题","Title"))
 local right=self.searchInputRight
 self.previewSearchBox:ClearAllPoints();self.previewSearchBox:SetPoint("TOPLEFT",52,-4);self.previewSearchBox:SetPoint("BOTTOMRIGHT",-right,4)
 self.searchHint:SetWidth(self.search:GetWidth()-52-right)
 self.searchClear:ClearAllPoints();self.searchClear:SetPoint("RIGHT",self.searchModeToggle,"LEFT",-6,0)
 if UI.preview then
  self.search.box=self.previewSearchBox;self.previewSearchBox:Show();self.searchAvailable=true;self.searchError=nil
  return true
 end
 if wantsNative then
  local ok,err=UI.Native:AcquireSearch(self,self.search)
  self.searchAvailable=ok;self.searchError=not ok and (err or L.unavailable) or nil
  if not ok then self.previewSearchBox:Hide();self:SetStatus(err or L.unavailable) end
  return ok
 end
 if UI.Native.searchLease then UI.Native:ReleaseSearch() end
 self.search.box=self.previewSearchBox;self.previewSearchBox:Show()
 self.searchAvailable=true;self.searchError=nil
 return true
end
function P:SetSearchMode(mode)
 if mode~="group" and mode~="leader" then return end
 if state.searchMode==mode then return end
 local text=mode=="leader" and self.search.box:GetText() or nil
 state.searchMode=mode
 if not UI.preview then
  if mode=="leader" then
   UI.Native:UseLeaderSearch()
   self.search.box=self.previewSearchBox;self.previewSearchBox:Show()
   self.previewSearchBox:SetText(text)
  else
   local ok,err=UI.Native:AcquireSearch(self,self.search)
   self.searchAvailable=ok;self.searchError=not ok and (err or L.unavailable) or nil
   if not ok then self:SetStatus(err or L.unavailable);return false end
  end
 end
 self:OnSearchTextChanged(self.search.box)
 self:UpdateFilters(true)
 self:DoSearch()
end
function P:UpdateFilters(reset)
 if not self.frame then return end
 local filters=state.filters;local cat=Category();local keys=false
 if cat.id==2 then for _,activity in ipairs(UI:GetGroup().Catalog:GetActivities(state.category)) do if activity.isMythicPlusActivity and (not state.groupKey or UI:GetGroup().Catalog:GetGroupKey(state.category,activity)==state.groupKey) and (not state.difficultyID or activity.difficultyID==state.difficultyID) and (not state.tier or UI:GetGroup().Catalog:GetActivityTier(activity)==state.tier) then keys=true;break end end end
 local seasonDungeon=cat.id==2 and cat.season
 self:SyncSearchInputMode()
 UI:SetText(self.searchHint,state.searchMode=="leader" and LEADER_SEARCH_HINT or keys and KEY_SEARCH_HINT or SEARCH_HINT)
 filters.category=state.category;filters.groupKey=state.groupKey;filters.groupKeys=state.groupKeys;filters.tier=state.tier;filters.difficultyID=state.difficultyID
 local query=state.searchMode=="leader" and self.search.box:GetText() or nil
 filters.searchMode=state.searchMode
 filters.text=UI.preview and state.searchMode=="group" and self.search.box:GetText() or nil
 filters.leaderText=query
 filters.minLevel,filters.maxLevel=nil,nil
 filters.personKey=state.personKey
 filters.minMembers=tonumber(self.fMinMembers.box:GetText());filters.maxMembers=tonumber(self.fMembers.box:GetText());filters.neededRole=not seasonDungeon and keys and self.roleChoice.value or nil
 if not seasonDungeon then filters.hideSameClass=nil;filters.roleMatchAny=nil;filters.tankPresence,filters.healerPresence,filters.damagePresence,filters.hideZeroScore,filters.hideSameSpec=nil,nil,nil,nil,nil end
 self.hideZeroScore:SetShown(seasonDungeon);self.hideZeroScore:SetValue(filters.hideZeroScore)
 self.filterDivider:SetShown(seasonDungeon)
 filters.friends=state.social=="friend";filters.guild=state.social=="guild";filters.notes=(state.social=="any" or state.social=="positive" or state.social=="noCaution") and state.social or nil
 self.roleChoice:SetShown(keys and not seasonDungeon);self.roleLabel:SetShown(keys and not seasonDungeon)
 UI:SetText(self.roleLabel,seasonDungeon and Say("队伍职责","Group roles") or Say("队伍缺少职责","Role needed"))
 local layout=seasonDungeon and "presence" or keys and "needed" or "basic"
 if self.filterLayout~=layout then
  self.filterLayout=layout
  self:LayoutFilters()
 end
 self:SyncSortHeaders()
 self:SyncQuickFilters(seasonDungeon)
 self:UpdateFilterSummary()
 if reset then self.results:SetPixelOffset(0,false) end
 local group=state.groupKey and UI:GetGroup().Catalog:GetGroup(state.category,state.groupKey)
 local name=group and group.name or state.browseReady and AllActivitiesLabel(cat) or cat.name
 if state.groupKeys then
  local catalog=UI:GetGroup().Catalog;local names={};local selected
  for _,entry in ipairs(catalog:GetGroups(state.category)) do if state.groupKeys[entry.key] then names[#names+1]=catalog:GetGroupShortName(state.category,entry.key);selected=entry end end
  if #names==1 then name=selected.name elseif #names>1 then name=table.concat(names,"·") end
 end
 if state.difficultyID then name=name.."  ·  "..(GetDifficultyInfo(state.difficultyID) or L.unknown) end
 UI:SetText(self.context,name);self.contextNaturalWidth=FitText(self.context);self.context:SetWidth(math.min(MAIN-300,self.contextNaturalWidth))
 self:SavePrefs()
 -- The provider notifies results after all filter controls and context are ready.
 UI:GetGroup():SetFilters(filters)
end
function P:SavePrefs()
 local prefs=UI:GetGroup().prefs.find or {};UI:GetGroup().prefs.find=prefs;prefs.railCollapsed=state.railCollapsed==true
 if not A:GetSetting("rememberFilters") then return end
 self:RememberCategory()
 prefs.category=state.category;prefs.categoryPrefs=state.categoryPrefs;prefs.social=state.social
 prefs.filters=prefs.filters or {};wipe(prefs.filters);for k,v in pairs(state.filters) do if k~="text" and k~="leaderText" and k~="searchMode" then prefs.filters[k]=v end end
 local choice=state.confirmedChoice or {}
 prefs.filters.groupKey,prefs.filters.groupKeys,prefs.filters.difficultyID,prefs.filters.tier=choice.groupKey,CopyGroupKeys(choice.groupKeys),choice.difficultyID,choice.tier
 prefs.filters.selected=choice.selected==true
end
function P:ClearFilters()
 for _,key in ipairs(advancedKeys) do state.filters[key]=nil end
 state.filters.hideSameClass=nil
 state.filters.hideZeroScore,state.filters.hideSameSpec=nil,nil
 self.loading=true;self.fMinMembers.box:SetText("");self.fMembers.box:SetText("");self.roleChoice:SetValue(false,L.anyRole);state.filters.tankPresence,state.filters.healerPresence,state.filters.damagePresence=nil,nil,nil;state.filters.roleMatchAny=nil;state.social=nil;self.socialChoice:SetValue(false,Say("全部关系","All relations"));state.filters.sortAscending=nil;state.filters.sort=A:GetSetting("defaultSort");self.sortChoice:SetValue(state.filters.sort,L[state.filters.sort] or L.newest);self.loading=nil;self:SyncFilterFields();self:UpdateFilters()
end
function P:OnSearchTextChanged(box,changed)
 local empty=box:GetText()==""
 self.searchHint:SetShown(empty);self.searchClear:SetShown(not empty)
 if changed and not self.loading then
  state.personKey=nil
  if UI.preview or state.searchMode=="leader" then self:UpdateFilters() end
 end
end
function P:OnSearchInputLost()
 self.searchAvailable=false;self.previewSearchBox:Hide()
 self.searchHint:Show();self.searchClear:Hide()
end
function P:ClearSearch()
 if not self:EnsureSearchInput() then return end
 if UI.preview or state.searchMode=="leader" then self.previewSearchBox:SetText("");if not UI.preview then C_LFGList.ClearSearchTextFields() end
 else UI.Native:ClearSearch() end
 state.personKey=nil;self:DoSearch()
end
function P:DoSearch(keepPicker)
 if not state.browseReady then self:UpdateFilters();return end
 if not self:EnsureSearchInput() then return end
 if not keepPicker then self:ClosePicker() end
 UI.Tooltip:Hide();self:UpdateFilters()
 local activityIDs
 if state.groupKey or state.groupKeys or state.difficultyID or state.tier then
  local catalog=UI:GetGroup().Catalog;activityIDs={}
  for _,activity in ipairs(catalog:GetActivities(state.category)) do
   local key=catalog:GetGroupKey(state.category,activity)
   if (not state.groupKey or key==state.groupKey) and (not state.groupKeys or state.groupKeys[key])
    and (not state.difficultyID or activity.difficultyID==state.difficultyID)
    and (not state.tier or catalog:GetActivityTier(activity)==state.tier) then activityIDs[#activityIDs+1]=activity.id end
  end
 end
 local mode=UI.preview and "preview" or state.searchMode
 local text=mode=="leader" and self.search.box:GetText() or nil
 local ok,err=UI:GetGroup().Search:Search(state.category,activityIDs,mode,text)
 if not ok then self:SetStatus(err or L.failed) end
 self:ReadSearchState()
end
function P:SetStatus(message)
 self.statusMessage=message or ""
 self:LayoutResults()
end
function P:LayoutResults()
 if not self.results then return end
 local top=132+(self.appsHeight or 0)+(self.quickFilterHeight or 0)
 local quota=state.applicationLimit
 local available=quota and UI:GetGroup().Applications:GetActiveCount()<5
 local message=quota and (available and Say("已有空余名额，可以继续申请。","A slot is available. You can continue your application.") or Say("最多同时申请 5 支队伍，请先取消一项申请。","You can apply to five groups at once. Cancel an application to continue.")) or self.statusMessage or ""
 self.limitNotice.fill:SetColor(available and AVAILABLE_NOTICE_COLOR or T.notice)
 self.limitNotice:SetMessage(message)
 if self.noticeTop~=top then
  M:FinishPlacement(self.limitNotice);self.limitNotice:ClearAllPoints();self.limitNotice:SetPoint("TOPLEFT",self.main,"TOPLEFT",0,-top);self.noticeTop=top
 end
 if message~="" then top=top+self.limitNotice:GetHeight()+12 end
 if self.resultsTop==top then return end
 self.resultsTop=top
 self.context:ClearAllPoints();self.context:SetPoint("TOPLEFT",12,-top)
 self.resultCount:ClearAllPoints();self.resultCount:SetPoint("LEFT",self.context,"RIGHT",12,0)
 self.resetSort:ClearAllPoints();self.resetSort:SetPoint("TOPRIGHT",0,-top)
 self.resultsHeader:ClearAllPoints();self.resultsHeader:SetPoint("TOPLEFT",0,-top-40)
 local resultsHeight=math.max(self.results.rowHeight,HEIGHT-top-80)
 self.results:ClearAllPoints();self.results:SetPoint("TOPLEFT",0,-top-80);self.results:SetViewport(resultsHeight)
 self.emptyPanel:ClearAllPoints();self.emptyPanel:SetPoint("TOP",self.results,"TOP",0,-math.max(8,(resultsHeight-280)/2-40))
end
function P:ReadSearchState()
 local status=UI:GetGroup():GetSearchState();local busy=state.browseReady and (status=="searching" or status=="waiting")
 self.refresh:SetAvailable(self.searchAvailable and state.browseReady and not busy);self.start:SetAvailable(self.searchAvailable and not busy);M:Spin(self.refreshIcon,busy)
 if self.busyState~=busy then M:Waiting(self.busyIcon,busy);self.busyState=busy end
 local message=self.searchError or state.browseReady and (status=="failed" or busy) and UI:GetGroup():GetSearchError() or ""
 if self.emptyPanel:IsShown() and self.emptyHelp:GetText()==message then message="" end
 if message==self.dismissedStatus then message="" else self.dismissedStatus=nil end
 self:SetStatus(message)
end
function P:RefreshApplications()
 wipe(state.apps);wipe(state.appIDs);local cat=Category();local categoryCount=0
 for _,app in ipairs(UI:GetGroup():GetApplications()) do
  local r=app.result
  local same=r and UI:GetGroup().Catalog:Matches(r.activity,state.category) or app.categoryID==cat.id and not cat.season
  if same and Active(app) then categoryCount=categoryCount+1 end
  if Active(app) and (state.showGlobal or same) then state.apps[app.id]=app;state.appIDs[#state.appIDs+1]=app.id end
 end
 self.appList:SetItems(state.appIDs,UpdateApplication)
 local count=#state.appIDs;local h=math.min(3,count)*self.appList.rowHeight
 local globalCount=UI:GetGroup().Applications:GetActiveCount()
 self.appList:SetShown(count>0);self.appList:SetViewport(math.max(1,h));UI:SetText(self.appsCount,("%d / 5"):format(globalCount))
 UI:Color(self.appsCount,globalCount>=5 and T.warning or T.text)
 UI:SetText(self.appsEmpty,Say("本分类暂无申请","No applications in this category"));C.SetLineHeight(self.appsEmpty,20,true);self.appsEmpty:SetShown(categoryCount==0 and globalCount==0);self.scopeToggle:SetShown(globalCount>categoryCount)
 UI:SetText(self.scopeToggle.label,state.showGlobal and Say("仅看本分类","This category") or Say("查看全部申请","All applications"))
 self.scopeToggle:SetWidth(FitText(self.scopeToggle.label)+24)
 self.appsHeight=h;self:LayoutQuickFilters();self:LayoutResults()
 self.autoJoin:SetValue(UI:GetGroupSetting("autoJoin"))
 local ticking=HasApplicationCountdown()
 if ticking and not self.countdown then
  self.countdown=C_Timer.NewTicker(1,RefreshApplicationClock)
 elseif not ticking then StopCountdown() end
end
function P:ShowApplicationLimit()
 state.applicationLimit=true;state.showGlobal=true
 self:ClosePicker();UI:CloseMenu();UI.Tooltip:Hide();self:RefreshApplications()
 M:Reveal(self.limitNotice,"TOPLEFT",self.main,"TOPLEFT",0,-140-(self.appsHeight or 0),0,7,.20)
end
function P:DismissApplicationNotice()
 state.applicationLimit=nil
 if self.limitNotice then M:FinishPlacement(self.limitNotice);self.limitNotice:Hide() end
end
function UI:ShowApplicationLimit()
 if self.page~="find" or not P.frame or not P.frame:IsShown() then A:Open("find",{applicationLimit=true})
 else P:ShowApplicationLimit() end
end
function P:RefreshResults(refreshTooltip)
 M:Stop(self)
 local tooltipResultID=self.pendingTooltipResultID;self.pendingTooltipResultID=nil
 if not self.frame or not self.frame:IsShown() or UI.hiding then return end
 local raid=Category().id==3
 if self.raidResultColumns~=raid then self:LayoutColumns() end
 self:RefreshApplications();local ids=state.browseReady and UI:GetGroup():GetResults() or {};self.results:SetItems(ids,RenderResult);UI:SetText(self.resultCount,Say("%d 支队伍","%d groups"):format(#ids))
 self:RefreshDeclineState(ids)
 self:RefreshSearchState()
 if refreshTooltip or tooltipResultID and UI.Tooltip:IsResult(tooltipResultID) then UI.Tooltip:RefreshRelations() end
end
function P:RefreshSearchState()
 if not self.frame or not self.frame:IsShown() or UI.hiding then return end
 local raid=Category().id==3
 local status=UI:GetGroup():GetSearchState();local empty=not self.results.ids or #self.results.ids==0;self.emptyPanel:SetShown(empty)
 self.resultsHeader:SetShown(not empty);self:SyncSortHeaders()
 if empty then
  local busy=state.browseReady and (status=="searching" or status=="waiting")
  local cat=Category();local instances=cat.id==2 or cat.id==3
  local prompt=instances and Say("请选择副本","Choose an instance") or Say("请选择活动","Choose an activity")
  local help=cat.id==9 and Say("从左侧分类中选择要浏览的活动。","Choose an activity from the category list.")
   or Say("选择具体"..(instances and "副本" or "活动").."，或“"..AllActivitiesLabel(cat).."”。","Select an "..(instances and "instance" or "activity").." or choose “"..AllActivitiesLabel(cat).."”.")
  local title=not state.browseReady and prompt or status=="waiting" and L.searchWaitingTitle or status=="searching" and L.searching or status=="failed" and L.searchFailedTitle or status=="idle" and L.findEmptyTitle or UI:GetGroup():GetResultCount()>0 and L.noFilteredResults or L.noResults
  local description=not state.browseReady and help or status=="waiting" and UI:GetGroup():GetSearchError() or status=="searching" and L.searchPendingHelp or status=="failed" and UI:GetGroup():GetSearchError() or status=="idle" and "" or L.noResultsHelp
  UI:SetText(self.emptyText,title);UI:SetText(self.emptyHelp,description);self.emptyHelp:SetShown(description~="")
  self.start:ClearAllPoints();self.start:SetPoint("TOP",description~="" and self.emptyHelp or self.emptyText,"BOTTOM",0,-24)
  UI:SetText(self.start.label,state.browseReady and L.searchNow or instances and Say("选择副本","Choose instance") or Say("选择活动","Choose activity"))
  self.start:SetShown(not busy);self.busyIcon:SetShown(busy)
 end
 self:ReadSearchState()
end
local function RefreshPendingResults() P:RefreshResults();return true end
function P:Apply(id,manual)
 if state.applicationLimit then self:DismissApplicationNotice() end
 if not Record(id) then self:SetStatus(L.unavailable);return end
 local ok,err=UI.Application:Apply(id,manual);self:SetStatus(not state.applicationLimit and ok==false and (err or L.failed) or "")
end
function P:OnApplicationCancelled(id)
 if not state.browseReady or not UI:GetGroup():GetResult(id) then return end
 self:DoSearch()
end
function P:UpdateApplicationSettings()
 local enabled=UI.Application:IsAutoApplyEnabled()
 self.autoApply:SetValue(enabled)
 UI:SetText(self.applicationSettings.label,L.applicationSettings)
 self.applicationSettings:SetWidth(FitText(self.applicationSettings.label))
 self.applicationSettings:SetAvailable(enabled)
end
function P:LayoutListRows()
 local first=self.results.rows[1]
 local metaTop=math.max(42,10+first.title:GetHeight()+4)
 local declineTop=metaTop+first.meta:GetHeight()+4
 local height=math.max(RESULT_ROW_HEIGHT,math.ceil(self.hasDeclinedResults and declineTop+first.declined:GetHeight()+10 or metaTop+first.meta:GetHeight()+10))
 for _,row in ipairs(self.results.rows) do
  row.meta:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-metaTop)
  LayoutResultActivity(row)
  row.declined:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-declineTop)
  row.description:SetHeight(math.max(48,row.meta:GetHeight()*2))
  LayoutMembers(row)
 end
 SetRowHeight(self.results,height)
 local appHeight=math.max(APP_ROW_HEIGHT,math.ceil(self.appList.rows[1].count:GetHeight()*2))
 for _,row in ipairs(self.appList.rows) do
  row.cancel:SetHeight(math.max(28,row.cancel.label:GetHeight()+2))
  LayoutMembers(row)
 end
 SetRowHeight(self.appList,appHeight)
 if self.appsHeight then self:RefreshApplications() end
end
function P:LayoutFont()
 if not self.frame then return end
 self.autoJoin:SetWidth(54+FitText(self.autoJoin.label))
 self.scopeToggle:SetWidth(FitText(self.scopeToggle.label)+24)
 self:UpdateApplicationSettings()
 self:LayoutQuickFilters()
 self:LayoutRailIcons()
 self:LayoutListRows()
 self:LayoutFilters()
 if self.picker then self:RefreshPicker() end
end
function P:OnResultSelect(id,button,row)
 state.selected=id;self:ClosePicker()
 if button=="RightButton" then self:OpenResultMenu(row or self.results,id) end
end
function P:OpenResultMenu(anchor,id,cursor)
 local r=Record(id);if not r then return end
 local applications=UI:GetGroup().Applications;local active=applications:IsActive(id);local application=UI:GetGroup():GetApplication(id);local invited=application and application.status=="invited"
 UI:OpenMenu(anchor,{{value="apply",label=invited and Say("已收到邀请","Invited") or active and L.cancelApplication or L.editAndApply,disabled=active and not applications:CanCancel(id)},{value="whisper",label=Say("与队长密聊","Whisper leader"),disabled=UI.preview~=nil or not r.leaderName},{value="copy",label=Say("复制队长名称","Copy leader name"),disabled=UI.preview~=nil or not r.leaderName},{value="blockTitle",label=Say("屏蔽相同标题队伍","Block groups with this title"),disabled=r.name==nil},{value="block",label=Say("荔枝笔记：拉黑","Player Notes: Block"),disabled=UI.preview~=nil or not r.leaderKey}},function(action)
  local target=Record(id);if not target then return end
  if action=="apply" then if applications:CanCancel(id) then local ok,err=UI:GetGroup():Cancel(id);if not ok then P:SetStatus(err or L.failed) end elseif not applications:IsActive(id) then P:Apply(id,true) end
  elseif action=="whisper" and target.leaderName and not UI.preview then ChatFrame_SendTell(target.leaderName)
  elseif action=="copy" then UI:CopyText(L.leader,target.leaderName,nil,nil,Say("完整名称","Full name"))
  elseif action=="blockTitle" then UI:GetGroup().Results:BlockTitle(target.name,target.leaderKey)
  elseif action=="block" and not UI.preview then local _,n,r=A:PlayerKey(target.leaderKey);A:Open("notes",{add={name=n,realm=r,type="caution"}}) end
 end,{cursor=cursor~=false})
end
function P:OnNotesChanged()
 if self.frame and self.frame:IsVisible() and not UI.hiding then UI:GetGroup().Results:InvalidateView();self:RefreshResults(true) end
end
function P:WatchNotes()
 UI:PrepareNotes()
 local wanted=not UI.preview and A.db.notesEnabled==true and A.Notes~=nil
 if (self.notesUnsub~=nil)==wanted then return false end
 if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 if wanted then self.notesUnsub=A.Notes:Subscribe(function() P:OnNotesChanged() end) end
 return true
end
function P:EnsureSearchInput()
 return self:SyncSearchInputMode()
end
function P:Enter(context)
 UI:GetGroup():Attach(self,"search")
 if UI.preview then
  self.search.box=self.previewSearchBox;self.previewSearchBox:Show();self.searchAvailable=true;self.searchError=nil
 else
  self:EnsureSearchInput()
 end
 if not self.loaded then
  self.loaded=true;self.loading=true
  local stored=UI:GetGroup().prefs.find or {};state.railCollapsed=stored.railCollapsed~=false
  local prefs=A:GetSetting("rememberFilters") and stored or {};local filters=prefs.filters or {}
  state.category=prefs.category or "seasonDungeon";state.categoryPrefs=prefs.categoryPrefs or {};state.filters.sort=filters.sort or A:GetSetting("defaultSort");state.social=prefs.social
  if UI.preview then self.previewSearchBox:SetText(filters.text or "") end
  local saved=state.categoryPrefs[state.category] or filters
  state.groupKey=saved.groupKey;state.difficultyID=saved.difficultyID;state.tier=saved.tier
  self:RestoreCategory(state.categoryPrefs[state.category] or {groupKey=filters.groupKey,groupKeys=filters.groupKeys,difficultyID=filters.difficultyID,tier=filters.tier,selected=filters.selected,minMembers=filters.minMembers,maxMembers=filters.maxMembers,neededRole=filters.neededRole,tankPresence=filters.tankPresence,healerPresence=filters.healerPresence,damagePresence=filters.damagePresence,hideZeroScore=filters.hideZeroScore,minItemLevel=filters.minItemLevel,maxItemLevel=filters.maxItemLevel,minRating=filters.minRating,maxRating=filters.maxRating,blockedKeywords=filters.blockedKeywords,blockedKeywordsText=filters.blockedKeywordsText,hideSameSpec=filters.hideSameSpec,hideSameClass=filters.hideSameClass,roleMatchAny=filters.roleMatchAny,needsDamage=filters.needsDamage,sort=filters.sort,sortAscending=filters.sortAscending,social=prefs.social})
  self.loading=nil
 end
 self:SetSidebarCollapsed(state.railCollapsed,false)
 self:UpdateApplicationSettings()
 if not self.restoredInitial then
  local saved=state.categoryPrefs[state.category]
  if saved then state.tier=saved.tier;state.difficultyID=saved.difficultyID;state.groupKey=saved.groupKey end
  self.restoredInitial=true
 end
 if context and context.applicationID then
  local app=UI:GetGroup():GetApplication(context.applicationID)
  if app then state.category=app.categoryID==2 and "seasonDungeon" or app.categoryID==3 and "seasonRaid" or tostring(app.categoryID) end
 end
 if context and context.leaderKey then
  self.loading=true
  if UI.preview then self.previewSearchBox:SetText(context.leaderName or "") else UI.Native:ClearSearch() end
  self.loading=nil;state.personKey=context.leaderKey
 end
 if not self.unsub then self.unsub=UI:GetGroup():Subscribe(function(kind,id)
  if kind=="activities" then P:RefreshCategories();P:RefreshPicker();P:UpdateFilters()
  elseif kind=="applicationCancelled" then P:OnApplicationCancelled(id)
  elseif kind=="result" or kind=="results" and type(id)=="table" then
   if kind=="result" then
    if UI.Tooltip:IsResult(id) then P.pendingTooltipResultID=id end
   else
    for resultID in pairs(id) do
     if UI.Tooltip:IsResult(resultID) then P.pendingTooltipResultID=resultID;break end
    end
   end
   M:Start(P,RefreshPendingResults)
  elseif kind=="relations" then P:RefreshResults(true)
  elseif kind=="search" then P:RefreshSearchState()
  elseif kind=="results" or kind=="applications" then P:RefreshResults(true) end
 end) end
 self:WatchNotes();self:RefreshCategories();self:RefreshPicker();self:UpdateFilters();self:SetFiltersOpen(self.filtersOpen)
 self:OnSearchTextChanged(self.search.box)
 if context and context.applicationID then self.appList:Select(context.applicationID,true) end
 if context and context.applicationLimit then self:ShowApplicationLimit() end
 local searchState=UI:GetGroup():GetSearchState()
  if context and context.leaderKey or UI:GetGroup().Search.abandoned or searchState=="idle" or searchState~="searching" and UI:GetGroup().Search.categoryKey~=state.category then self:DoSearch() end
end
function P:Leave()
 self:FinishSidebar()
 M:Stop(self);self.pendingTooltipResultID=nil
 UI.Native:ReleaseSearch();self.searchAvailable,self.searchError=nil,nil
 self:DismissApplicationNotice()
 if self.unsub then self.unsub();self.unsub=nil end;if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 self.results:Clear();self.appList:Clear();self.seasonCategories:Clear();self.categories:Clear();if self.picker then self.activities:Clear();self:ClosePicker() end;M:FinishPlacement(self.filterPanel);self.filterPanel:Hide()
 StopCountdown();StopDeclineClock();M:Waiting(self.busyIcon,false);M:Spin(self.refreshIcon,false);self.busyState=nil
 wipe(state.apps);wipe(state.appIDs);state.selected=nil
 state.showGlobal=nil
 UI:GetGroup():Detach(self);UI:FitToScreen()
end

-- Preview owns a separate page state; real preferences are restored on exit.
function P:BeginPreview(provider)
 self.liveState={state=state}
 state={category=provider.category,searchMode="group",apps={},appIDs={},categoryPrefs={},filters={sort="newest"},browseReady=true}
 self.loaded,self.restoredInitial=nil,nil
end
function P:EndPreview()
 local saved=self.liveState;if not saved then return end
 state=saved.state
 self.liveState=nil
 -- Rebind the visible controls from the restored real preferences on next entry.
 self.loaded=nil;self.restoredInitial=nil
end
