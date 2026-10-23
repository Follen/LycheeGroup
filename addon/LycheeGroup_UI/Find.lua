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
local MAIN=T.contentWidth-T.findSidebarWidth-T.contentGap-T.findContentInset*2
local HEIGHT=T.contentHeight-T.findContentInset*2
local BODY=MAIN-T.findListGutter
local APP_BODY=MAIN-T.findApplicationInset*2-T.findListGutter
local function SetRowHeight(list,height)
 list.rowHeight=height
 list.capacity=math.min(list.poolCapacity-1,math.ceil(list:GetHeight()/height))
 list.canvas:SetHeight(list:GetHeight()+height*2)
 for i,row in ipairs(list.rows) do row:SetHeight(height);row:SetPoint("TOPLEFT",0,-(i-1)*height) end
 list:Refresh(true)
end
local RESULT_COLUMNS={
 title={x=60,width=210},leader={x=303,width=108},
 members={x=427,width=138},ilvl={x=581,width=52},rating={x=649,width=76},
 description={x=741,width=BODY-765-(zh and T.findAgeWidthCN or T.findAgeWidthEN)},age={x=BODY-12-(zh and T.findAgeWidthCN or T.findAgeWidthEN),width=(zh and T.findAgeWidthCN or T.findAgeWidthEN)},
}
local APPLICATION_COLUMNS={title={x=36,width=APP_BODY-591},leader={x=APP_BODY-522,width=120}}
local resultDefinitions={
 {key="title",label=Say("队伍","Group"),width="findResultTitleWidth",min="findResultTitleMin"},
 {key="leader",label=Say("队长","Leader"),width="findResultLeaderWidth",min="findResultLeaderMin"},
 {key="members",label=Say("成员","Members"),width="findResultMembersWidth",min="findResultMembersMin",align="CENTER",sortable=true},
 {key="ilvl",label=Say("装等","iLvl"),width="findResultIlvlWidth",min="findResultIlvlMin",align="CENTER",sortable=true},
 {key="rating",label=Say("评分","Score"),width="findResultRatingWidth",min="findResultRatingMin",align="CENTER",sortable=true},
 {key="description",label=Say("描述","Description"),width="findResultDescriptionWidth",min="findResultDescriptionMin"},
 {key="age",label=Say("发布","Posted"),width=(zh and T.findAgeWidthCN or T.findAgeWidthEN)+20,min="findResultAgeMin",align="RIGHT",sortable=true},
}
local applicationDefinitions={
 {key="title",label=Say("队伍","Group"),width=APP_BODY-542,min="findApplicationTitleMin"},
 {key="leader",label=Say("队长","Leader"),width="findApplicationLeaderWidth",min="findApplicationLeaderMin"},
 {key="members",label=Say("成员","Members"),width="findApplicationMembersWidth",min="findApplicationMembersMin",align="CENTER",sortable=true},
 {key="status",label=Say("状态 / 剩余","Status / time"),width="findApplicationStatusWidth",min="findApplicationStatusMin",align="CENTER",sortable=true},
 {key="actions",label=Say("操作","Actions"),width="findApplicationActionsWidth",min="findApplicationActionsMin",align="CENTER"},
}
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
 for _,slot in ipairs(roster.slots) do slot.role:SetSize(T.findSlotRoleWidth,T.findSlotRoleHeight) end
 for i,item in ipairs(roster.counts) do
  item.icon:SetSize(T.findItemIconWidth,T.findItemIconHeight);item.icon:ClearAllPoints();item.icon:SetPoint("LEFT",(i-1)*46,0)
  item.text:SetWidth(T.findItemTextWidth);item.text:SetJustifyH("LEFT");item.text:ClearAllPoints();item.text:SetPoint("LEFT",(i-1)*46+20,0)
 end
end
local function MemberIconScale() return A:GetSetting("memberIconScale")/100 end
local function ResultMemberWidth()
 -- Include the one-unit role-badge overhang on either side of the roster.
 return math.max(138,math.ceil(100*T.findMemberBaseScale*T.findMemberScaleAdjustment*MemberIconScale()))
end
local function LayoutMembers(row)
 -- Fixed raid columns keep one- and two-digit counts aligned across rows.
 row.roster:SetWidth(row.isParty and row.partyWidth or 132)
 local scale=row.partyScale*(row.membersCompact and 1 or MemberIconScale())
 row.roster:SetScale(row.isParty and scale or 1)
 if not row.membersCompact then for _,slot in ipairs(row.roster.slots) do UI:UpdateMemberIconStyle(slot.icon,row.isParty and slot.icon:IsShown()) end end
 row.roster:ClearAllPoints()
 local x=row.membersX
 if row.isParty then
  row.membersButton:SetSize(row.membersCompact and 138 or ResultMemberWidth(),math.max(row.membersCompact and 18 or 24,math.ceil(18*scale)));row.roster:SetPoint("CENTER")
 else
  -- Keep the columns in place while the hover/click area fits the visible count.
  x=x-3
  row.membersButton:SetHeight(row.membersCompact and 18 or 24)
  row.membersButton:SetWidth(112+row.roster.counts[3].text:GetStringWidth()+12)
  C.SetPoint(row.roster,"LEFT",row.roster:GetParent(),"LEFT","findRowRosterLeftX",0)
 end
 local extra=math.max(0,row.count:GetHeight()-row.memberCountLine)/2
 if row.membersWidth then x=row.membersX+(row.membersWidth-(row.isParty and row.membersButton:GetWidth() or 138))/2-(row.isParty and 0 or 3) end
 local y=row.membersExpanded and row.membersExpandedY+extra or 0
 if row.isParty and not row.membersCompact and A:GetSetting("memberLeaderMark") then
  local crownHeight=math.min(14*scale,19)
  y=-math.max(0,10*scale+crownHeight+1-row:GetHeight()/2+2)
 end
 row.membersButton:ClearAllPoints();row.membersButton:SetPoint("LEFT",x,y)
 row.count:SetWidth(row.membersWidth or 138)
 row.count:SetPoint("LEFT",row.membersX,row.memberCountY-extra)
 row.count:SetShown(not row.isParty and row.membersExpanded==true)
end
local function BuildMembers(row,x,compact)
 row.membersCompact=compact
 row.membersX=x;row.membersExpandedY=compact and 9 or 11
 row.memberCountY=compact and -9 or -13;row.memberCountLine=UI.context:GetLineHeight(compact and "line14" or "line20")/UI.context.fontScale
 local partyGap=compact and 5 or 2
 row.partyWidth=18*5+partyGap*4
 row.partyScale=compact and 1 or T.findMemberBaseScale*T.findMemberScaleAdjustment
 row.membersButton=C.Button(row,"",T.findRowMembersButtonWidth,function()
  if row.isParty or not row.key or not row._hitVisible then return end
  row.membersExpanded=not row.membersExpanded;LayoutMembers(row)
 end);C.ApplyStyle(row.membersButton,{width="findRowMembersButtonWidth"})
 row.membersButton:SetStyle({height=compact and 18 or 24,radius=6})
 row.roster=C.Roster(row.membersButton,18,partyGap);row.roster:SetSize(T.findRowRosterWidth,compact and 18 or 20);row.roster:SetPoint("CENTER");RosterColumns(row.roster)
 if not compact then for _,slot in ipairs(row.roster.slots) do slot.icon.memberStyle=true end end
 if compact then for _,item in ipairs(row.roster.counts) do C.SetFont(item.text,"font12");C.SetLineHeight(item.text,"line14",true) end end
 row.count=C.Text(row,"",compact and "font12" or "font14","muted",T.findRowCountWidth);C.ApplyStyle(row.count,{width="findRowCountWidth"});C.SetLineHeight(row.count,compact and "line14" or "line20",true);row.count:SetPoint("LEFT",x,compact and -9 or -13);row.count:SetJustifyH("CENTER");row.count:SetWordWrap(false)
 LayoutMembers(row)
end
local function UpdateMembers(row,id,record,details)
 if row.membersKey~=id then row.membersKey=id;row.membersExpanded=nil end
 row.isParty=record and record.maxNumPlayers==5
 if row.isParty then row.membersExpanded=nil end
 row.membersButton:EnableMouse(not row.isParty)
 local counts=details and details.counts
 if not row.membersCompact then for _,slot in ipairs(row.roster.slots) do
  slot.icon.memberClass=nil;slot.icon.memberIsLeader=false;slot.icon.memberLeaderKey=record and record.leaderKey
 end end
 row.roster:Update(details and details.members,counts,record and record.maxNumPlayers,true)
 UI:SetText(row.count,record and not row.isParty and UI:MemberCountText(record) or "")
 LayoutMembers(row)
end
local function DeclinedAt(record)
 return record and record.partyGUID and UI:GetGroup().Applications:GetDeclinedAt(record.partyGUID)
end
function P:SortResultIDs(ids)
 local prefs=self.resultsHeader.state;local key=prefs.sortKey
 if not key then return ids end
 self.sortedResults=self.sortedResults or {};self.sortValues=self.sortValues or {}
 local sorted,values=self.sortedResults,self.sortValues;wipe(sorted);wipe(values)
 local group=UI:GetGroup()
 for i,id in ipairs(ids) do
  local r=group:GetResult(id);local value
  if key=="members" then value=r.numMembers
  elseif key=="ilvl" then value=r.requiredItemLevel
  elseif key=="age" then value=r.age
  elseif key=="rating" then
   if self.raidResultColumns then value=group.Results:GetProgressCount(r) else value=r.leaderRating end
  end
  sorted[i]=id;values[id]=value
 end
 table.sort(sorted,function(a,b)
  local ad,bd=DeclinedAt(group:GetResult(a))~=nil,DeclinedAt(group:GetResult(b))~=nil
  if ad~=bd then return not ad end
  local av,bv=values[a],values[b]
  if av~=bv then
   if av==nil then return false elseif bv==nil then return true end
   if prefs.descending then return av>bv else return av<bv end
  end
  return a<b
 end)
 return sorted
end
function P:OnHeaderSort(key,descending)
 local values={members="members",ilvl="itemLevel",rating="rating",age="newest"}
 state.filters.sort=values[key]
 self.sortChoice:SetValue(values[key],self.resultsHeader.labels[key]:GetText())
 self:RefreshResults()
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
  local shade=missing and T.findMissingRoleShade or 1
  slot.role:SetDesaturated(missing);slot.role:SetVertexColor(shade,shade,shade)
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
 local rail=CreateFrame("Frame",nil,f);rail:SetSize(T.findSidebarWidth,T.contentHeight);rail:SetPoint("TOPLEFT");self.rail=rail
 local seasonStride=zh and 52 or 72
 local seasonHeight=seasonStride*2;local categoriesTop=seasonHeight+24
 self.seasonCategories=C.List(rail,T.findSidebarWidth,seasonHeight,seasonStride,function(key,button,row) P:SelectCategory(key,row) end);C.SetPoint(self.seasonCategories,"TOPLEFT",self.seasonCategories:GetParent(),"TOPLEFT",0,"findSeasonCategoriesTopleftY")
 self.categories=C.List(rail,T.findSidebarWidth,T.contentHeight-categoriesTop-72,52,function(key,button,row) P:SelectCategory(key,row) end);self.categories:SetPoint("TOPLEFT",0,-categoriesTop)
 self.seasonIDs={};self.catIDs={};self.catMap={}
 for _,list in ipairs({self.seasonCategories,self.categories}) do list:SetGutter(0);list.alternateRows=false;list.selectionFill=true;list.idleTextColor="muted";list:SetRowInitializer(function(row)
  row:SetHeight(list.rowHeight-4);row.selected:SetRadius(8);row.hover:SetRadius(8);row.alternate:SetRadius(8);row.title:ClearAllPoints();C.SetPoint(row.title,"LEFT",row.title:GetParent(),"LEFT","findRowTitleLeftX",0);C.ApplyStyle(row.title,{width="findRowTitleWidth"});C.SetFont(row.title,"findRailFont");row.title:SetWordWrap(true);row.title:SetHeight(0);C.SetLineHeight(row.title,"line22");row.meta:Hide()
  row.symbol=C.Icon(row,T.railIconSize);C.SetPoint(row.symbol,"LEFT",row.symbol:GetParent(),"LEFT","findRowSymbolLeftX",0);row.chevron=C.Glyph(row,"chevron",T.findRowChevronWidth);C.ApplyStyle(row.chevron,{width="findRowChevronWidth",height="findRowChevronHeight"});C.SetPoint(row.chevron,"RIGHT",row.chevron:GetParent(),"RIGHT","findRowChevronRightX",0)
 end);list:SetStyle({selectionMotion=true,radius=8}) end
 local surface=CreateFrame("Frame",nil,f);surface:SetSize(MAIN+T.findContentInset*2,T.contentHeight);surface:SetPoint("TOPLEFT",T.findSidebarWidth+T.contentGap,0);C.Panel(surface,"surfaceLow","findPanelRadius");self.surface=surface
 local main=CreateFrame("Frame",nil,surface);main:SetSize(MAIN,HEIGHT);C.SetPoint(main,"TOPLEFT",main:GetParent(),"TOPLEFT","findMainTopleftX","findMainTopleftY");self.main=main
 self.searchInputRight=0
 self.search=C.Edit(main,MAIN-60,T.findSearchHeight,false,true);C.ApplyStyle(self.search,{height="findSearchHeight"});self.search:SetPoint("TOPLEFT");C.ApplyStyle(self.search,{height="findSearchHeight"})
 self.search:EnableMouse(true)
 self.search:SetScript("OnEnter",function() P:EnsureSearchInput() end)
 self.search:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" and P:EnsureSearchInput() then P.search.box:SetFocus() end end)
  self.previewSearchBox=self.search.box
 self.search.box:ClearAllPoints();C.SetPoint(self.search.box,"TOPLEFT",self.search.box:GetParent(),"TOPLEFT","findSearchBoxTopleftX","findSearchBoxTopleftY");C.SetPoint(self.search.box,"BOTTOMRIGHT",self.search.box:GetParent(),"BOTTOMRIGHT",0,"findSearchBoxBottomrightY")
 C.Glyph(self.search,"search",T.findGlyphWidth):SetPoint("LEFT",self.search,"TOPLEFT",18,-24)
  self.searchHint=C.Text(self.search,SEARCH_HINT,"font14","dim",MAIN-350);C.SetPoint(self.searchHint,"LEFT",self.search,"TOPLEFT","findSearchHintLeftX","findSearchHintLeftY")
  self.searchHint:SetWordWrap(false)
  self.search.box:SetScript("OnTextChanged",function(box) self:OnSearchTextChanged(box,true) end)
 self.search.box:SetScript("OnEnterPressed",function(box) box:ClearFocus();self:DoSearch() end)
 self.filterToggle=C.Button(self.search,Say("筛选","Filters"),nil,function() P:SetFiltersOpen(not P.filtersOpen) end);C.ApplyStyle(self.filterToggle,{height="findFilterToggleHeight"});self.filterToggle:SetTextColors("muted","text","onSecondaryContainer");C.SetPoint(self.filterToggle,"RIGHT",self.search,"TOPRIGHT","findFilterToggleRightX","findFilterToggleRightY")
 self.filterToggle.label:ClearAllPoints();C.SetPoint(self.filterToggle.label,"LEFT",self.filterToggle.label:GetParent(),"LEFT","findFilterToggleLabelLeftX",0)
 self.filterToggle.label:SetWidth(0);self.filterToggle.label:SetJustifyH("LEFT");self.filterToggle.label:SetWordWrap(false)
 self.filterChevron=C.Icon(self.filterToggle,T.findFilterChevronWidth);C.ApplyStyle(self.filterChevron,{width="findFilterChevronWidth",height="findFilterChevronHeight"});UI:SetMediaTexture(self.filterChevron,"chevron.tga");C.SetPoint(self.filterChevron,"RIGHT",self.filterChevron:GetParent(),"RIGHT","findFilterChevronRightX",0)
 self.searchModeToggle=C.Button(self.search,"",nil,function() P:SetSearchMode(state.searchMode=="group" and "leader" or "group") end);C.ApplyStyle(self.searchModeToggle,{height="findSearchModeToggleHeight"});self.searchModeToggle:SetTextColors("muted","text","onSecondaryContainer");C.SetPoint(self.searchModeToggle,"RIGHT",self.filterToggle,"LEFT","findSearchModeToggleRightX",0)
 UI.Tooltip:BindText(self.searchModeToggle,Say("按队伍标题搜索/按队长名字搜索","Search by: group title/leader name"))
 self.searchClear=C.Button(self.search,"",T.findSearchClearWidth,function() P:ClearSearch() end);C.ApplyStyle(self.searchClear,{width="findSearchClearWidth"});C.ApplyStyle(self.searchClear,{width="findSearchClearWidth",height="findSearchClearHeight"});C.SetPoint(self.searchClear,"RIGHT",self.searchModeToggle,"LEFT","findSearchClearRightX",0);C.Glyph(self.searchClear,"close",T.findGlyphWidth2):SetPoint("CENTER");self.searchClear:Hide()
 self.search.box:ClearAllPoints();C.SetPoint(self.search.box,"TOPLEFT",self.search.box:GetParent(),"TOPLEFT","findSearchBoxTopleftX","findSearchBoxTopleftY");C.SetPoint(self.search.box,"BOTTOMRIGHT",self.searchModeToggle,"LEFT","findSearchBoxBottomrightX","findSearchBoxBottomrightY")
 self.applicationPanel=CreateFrame("Frame",nil,main);self.applicationPanel:SetPoint("TOPLEFT",0,-T.findApplicationTop);self.applicationPanel:SetWidth(MAIN);self.applicationPanel.fill=C.Panel(self.applicationPanel,"panel","findApplicationPanelFillRadius")
 self.appsTitle=C.Text(self.applicationPanel,L.applications,"font14","text");C.SetLineHeight(self.appsTitle,"line20",true);C.SetPoint(self.appsTitle,"LEFT",self.applicationPanel,"TOPLEFT","findAppsTitleLeftX","findAppsTitleLeftY")
 self.appsBadge=CreateFrame("Frame",nil,self.applicationPanel);C.ApplyStyle(self.appsBadge,{width="findAppsBadgeWidth",height="findAppsBadgeHeight"});C.SetPoint(self.appsBadge,"LEFT",self.appsTitle,"RIGHT","findAppsBadgeLeftX",0)
 self.appsCount=C.Text(self.appsBadge,"0","font14","text");C.SetLineHeight(self.appsCount,"line20",true);self.appsCount:SetPoint("CENTER")
 self.appsEmpty=C.Text(self.applicationPanel,Say("本分类暂无申请","No applications in this category"),"font14","dim");C.SetPoint(self.appsEmpty,"LEFT",self.appsBadge,"RIGHT","findAppsEmptyLeftX",0)
 self.scopeToggle=C.Button(self.applicationPanel,Say("全部申请","All applications"),nil,function()
  state.showGlobal=not state.showGlobal
  if not state.showGlobal then P:DismissApplicationNotice() end
  P:RefreshApplications()
 end,{height=32,radius=16});C.SetPoint(self.scopeToggle,"LEFT",self.appsBadge,"RIGHT","findScopeToggleLeftX",0)
 C.SetFont(self.scopeToggle.label,"font14");C.SetLineHeight(self.scopeToggle.label,"line20",true)
 UI.Tooltip:BindText(self.scopeToggle,Say("点击切换本分类／全部申请","Click to switch category / all applications."))
 self.applicationInfoMeasure=C.Text(self.applicationPanel,"","font14");self.applicationInfoMeasure:Hide()
 self.autoJoin=C.Check(self.applicationPanel,Say("自动进组","Auto join"),function(value) UI:SetGroupSetting("autoJoin",value) end);C.SetFont(self.autoJoin.label,"font14");C.SetLineHeight(self.autoJoin.label,"line20",true);self.autoJoin:SetSize(54+FitText(self.autoJoin.label),26);C.SetPoint(self.autoJoin,"RIGHT",self.applicationPanel,"TOPRIGHT","findAutoJoinRightX","findAutoJoinRightY");self.autoJoin.track:ClearAllPoints();self.autoJoin.track:SetPoint("RIGHT",0,0);self.autoJoin.label:ClearAllPoints();C.SetPoint(self.autoJoin.label,"RIGHT",self.autoJoin.track,"LEFT","findAutoJoinLabelRightX",0)
 self.autoApply=C.Check(self.applicationPanel,"",function(value)
  local ok,err=UI.Application:SetAutoApply(value);if not ok then P:SetStatus(err or L.failed) end
 end);C.ApplyStyle(self.autoApply,{width="findAutoApplyWidth",height="findAutoApplyHeight"});C.SetPoint(self.autoApply,"RIGHT",self.autoJoin,"LEFT","findAutoApplyRightX",0);self.autoApply.label:Hide()
 self.applicationSettings=C.Button(self.applicationPanel,L.applicationSettings,T.findApplicationSettingsWidth,function()
  if not UI.Application:IsAutoApplyEnabled() then return end
  local ok,err=UI.Application:OpenApplicationSettings();if not ok then P:SetStatus(err or L.failed) end
 end);C.ApplyStyle(self.applicationSettings,{width="findApplicationSettingsWidth"})
 C.ApplyStyle(self.applicationSettings,{height="findApplicationSettingsHeight"});C.SetFont(self.applicationSettings.label,"font14");C.SetLineHeight(self.applicationSettings.label,"line20",true)
 UI.Application.onPreferencesChanged=function() P:UpdateApplicationSettings() end
 C.SetPoint(self.applicationSettings,"RIGHT",self.autoApply,"LEFT","findApplicationSettingsRightX",0)
 function self.applicationSettings:RefreshStyle()
  self.fill:Hide();self.hover:Hide();UI:Color(self.label,self._inside and T.brand or T.muted)
 end
 self.refresh=C.IconButton(main,"refresh",T.findRefreshWidth,function() P:DoSearch() end,{iconSize=22,radius=24,surfaceColors={T.selected,T.refreshHover}});C.ApplyStyle(self.refresh,{width="findRefreshWidth",height="findRefreshHeight"});self.refresh:SetPoint("TOPRIGHT",main,"TOPRIGHT",0,0);self.refreshIcon=self.refresh.icon
 self.appList=C.List(self.applicationPanel,MAIN-32,T.findApplicationRowHeight*3,T.findApplicationRowHeight,function(id,button,row) if button=="RightButton" then P:OpenResultMenu(row,id) end end);self.appList:SetGutter(T.findListGutter);C.SetPoint(self.appList,"TOPLEFT",self.appList:GetParent(),"TOPLEFT","findAppListTopleftX","findAppListTopleftY");self.appList.tooltipFraction=.25
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
  row.title:ClearAllPoints();row.title:SetPoint("LEFT",APPLICATION_COLUMNS.title.x,0);row.title:SetWidth(APPLICATION_COLUMNS.title.width);C.SetFont(row.title,"font15");C.SetLineHeight(row.title,"line20",true);row.meta:Hide()
  row.icon=C.Icon(row,T.findRowIconWidth);C.ApplyStyle(row.icon,{width="findRowIconWidth",height="findRowIconHeight"});row.icon:SetPoint("LEFT",0,0)
  row.leaderIcon=C.Icon(row,T.findRowLeaderIconWidth);C.ApplyStyle(row.leaderIcon,{width="findRowLeaderIconWidth",height="findRowLeaderIconHeight"});row.leaderIcon:Hide()
  row.leader=C.Text(row,"","font14","muted",APPLICATION_COLUMNS.leader.width);row.leader:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x,0);C.SetLineHeight(row.leader,"line20",true);row.leader:SetWordWrap(false)
  BuildMembers(row,APP_BODY-386,true)
  row.status=C.Text(row,"","font14","dim",T.findRowStatusWidth);C.ApplyStyle(row.status,{width="findRowStatusWidth"});row.status:SetPoint("LEFT",APP_BODY-224,0);C.SetLineHeight(row.status,"line20",true);row.status:SetJustifyH("CENTER")
  row.cancel=C.Button(row,L.cancelApplication,T.findRowCancelWidth,function(b)
   local id=b.targetKey;local app=UI:GetGroup():GetApplication(id);if not app then return end
   if not UI:GetGroup().Applications:CanCancel(id) then return end
   local ok,err=UI:GetGroup():Cancel(id)
   if not ok then P:SetStatus(err or L.failed) end
  end);C.ApplyStyle(row.cancel,{width="findRowCancelWidth"});C.SetFont(row.cancel.label,"font14");C.SetLineHeight(row.cancel.label,"line20",true);row.cancel:SetStyle({height=28,radius=14});row.cancel:SetPoint("RIGHT",0,0)
  row.cancel:HookScript("OnEnter",function(button) if button:IsEnabled() then UI:Color(button.label,T.accent) end end)
 end
 self.context=C.Text(main,"","font20","text",MAIN-180)
 self.resultCount=C.Text(main,"","font14","dim",T.findResultCountWidth);C.ApplyStyle(self.resultCount,{width="findResultCountWidth"});C.SetLineHeight(self.context,"line28",true);C.SetLineHeight(self.resultCount,"line20",true);self.resultCount:SetJustifyH("LEFT")
 self.resultsHeader=C.TableHeader(main,resultDefinitions,{
  onLayout=function() if P.results then P:ApplyResultColumns() end end,
  onSort=function(key,descending) P:OnHeaderSort(key,descending) end,
 })
 self.resultHeadings=self.resultsHeader.labels
 self.applicationHeader=C.TableHeader(self.applicationPanel,applicationDefinitions,{
  onLayout=function() P:LayoutApplicationColumns() end,
  onSort=function() P:RefreshApplications() end,
 })
 C.SetPoint(self.applicationHeader,"TOPLEFT",self.applicationHeader:GetParent(),"TOPLEFT","findApplicationHeaderTopleftX","findApplicationHeaderTopleftY")
 C.SetPoint(self.appList,"TOPLEFT",self.appList:GetParent(),"TOPLEFT","findAppListTopleftX","findAppListTopleftY2")
 self.results=C.List(main,MAIN,HEIGHT-180,T.findResultRowHeight,function(id,button,row) P:OnResultSelect(id,button,row) end)
 self.results:SetGutter(T.findListGutter);self.results.tooltipFraction=.25
 self.results:SetRowInitializer(function(row)
  ResultTooltipArea(row,self.results)
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT",RESULT_COLUMNS.title.x,"findRowTitleTopleftY");row.title:SetWidth(RESULT_COLUMNS.title.width);C.SetFont(row.title,"listTitleSize");C.SetLineHeight(row.title,"listTitleLineHeight",true)
  row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT",RESULT_COLUMNS.title.x,"findRowMetaTopleftY");row.meta:SetWidth(RESULT_COLUMNS.title.width);C.SetLineHeight(row.meta,"line20",true)
  row.declined=C.Text(row,"","font12","warning",RESULT_COLUMNS.leader.x+RESULT_COLUMNS.leader.width-RESULT_COLUMNS.title.x);C.SetLineHeight(row.declined,"line18",true);row.declined:SetWordWrap(false);row.declined:Hide()
  row:HookScript("OnHide",function() UI:SetText(row.declined,"");row.declined:Hide() end)
  row.marks=UI.Members:CreateMarks(row);C.SetPoint(row.marks,"LEFT",row.meta,"RIGHT","findRowMarksLeftX",0)
  row:HookScript("OnHide",function(self) UI.Members:ClearMarks(self.marks) end)
  row.description=C.Text(row,"","font14","muted",RESULT_COLUMNS.description.width,"line20");row.description:SetPoint("LEFT",RESULT_COLUMNS.description.x,0);C.ApplyStyle(row.description,{height="findRowDescriptionHeight"});row.description:SetMaxLines(2);row.description:SetWordWrap(true);row.description:SetJustifyV("MIDDLE")
  row.leaderIcon=C.Icon(row,T.findRowLeaderIconWidth);C.ApplyStyle(row.leaderIcon,{width="findRowLeaderIconWidth",height="findRowLeaderIconHeight"});row.leaderIcon:Hide()
  row.leader=C.Text(row,"","font14","muted",RESULT_COLUMNS.leader.width);row.leader:SetPoint("LEFT",RESULT_COLUMNS.leader.x,0);C.SetLineHeight(row.leader,"line20",true);row.leader:SetWordWrap(false)
  row.icon=C.Icon(row,T.findResultIconSize);C.ApplyStyle(row.icon,{width="findResultIconSize",height="findResultIconSize"});row.icon:SetPoint("LEFT",T.findResultIconInset,0)
  row.score=C.Text(row,"","font14","text",RESULT_COLUMNS.rating.width);C.SetLineHeight(row.score,"line20",true);row.score:SetPoint("LEFT",RESULT_COLUMNS.rating.x,0);row.score:SetJustifyH("CENTER");row.score:SetWordWrap(false)
  row.ilvl=C.Text(row,"","font14","text",RESULT_COLUMNS.ilvl.width);C.SetLineHeight(row.ilvl,"line20",true);row.ilvl:SetPoint("LEFT",RESULT_COLUMNS.ilvl.x,0);row.ilvl:SetJustifyH("CENTER");row.ilvl:SetWordWrap(false)
  BuildMembers(row,RESULT_COLUMNS.members.x)
  row.age=C.Text(row,"","font14","dim",RESULT_COLUMNS.age.width);row.age:SetPoint("LEFT",RESULT_COLUMNS.age.x,0);row.age:SetJustifyH("RIGHT");C.SetLineHeight(row.age,"line20",true);row.age:SetWordWrap(false)
  local metaTop=math.max(42,10+row.title:GetHeight()+4)
  row.meta:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-metaTop)
  row.declined:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-metaTop-row.meta:GetHeight()-4)
  row.description:SetHeight(math.max(T.findDescriptionMinHeight,row.meta:GetHeight()*2));LayoutMembers(row)
  row.membersWidth=RESULT_COLUMNS.members.width;LayoutMembers(row)
  row.tooltipArea:SetWidth(self.resultsHeader.columns.title.width)
  row:SetScript("OnDoubleClick",function(b,button) if button=="LeftButton" and b.key then P:Apply(b.key) end end)
 end)
 local refreshResultsList=self.results.Refresh
 function self.results:Refresh(...)
  refreshResultsList(self,...)
  RefreshVisibleDeclines()
 end
 self.emptyPanel=CreateFrame("Frame",nil,main);self.emptyPanel:SetSize(MAIN,T.findEmptyPanelHeight);C.SetPoint(self.emptyPanel,"CENTER",self.emptyPanel:GetParent(),"CENTER",0,"findEmptyPanelCenterY")
 self.busyIcon=C.Icon(self.emptyPanel,T.findBusyIconWidth);C.ApplyStyle(self.busyIcon,{width="findBusyIconWidth",height="findBusyIconHeight"});UI:SetMediaTexture(self.busyIcon,"lychee-logo.tga");C.SetPoint(self.busyIcon,"TOP",self.emptyPanel,"TOP",0,"findBusyIconTopY")
 self.emptyText=C.Text(self.emptyPanel,L.findEmptyTitle,"font18","text",T.findEmptyTextWidth);C.ApplyStyle(self.emptyText,{width="findEmptyTextWidth"});C.SetPoint(self.emptyText,"TOP",self.emptyText:GetParent(),"TOP",0,"findEmptyTextTopY");self.emptyText:SetJustifyH("CENTER")
 self.emptyHelp=C.Text(self.emptyPanel,"","font14","muted",T.findEmptyHelpWidth);C.ApplyStyle(self.emptyHelp,{width="findEmptyHelpWidth"});C.SetPoint(self.emptyHelp,"TOP",self.emptyHelp:GetParent(),"TOP",0,"findEmptyHelpTopY");self.emptyHelp:SetJustifyH("CENTER")
 self.start=C.Button(self.emptyPanel,L.searchNow,T.findStartWidth,function() if state.browseReady then P:DoSearch() else P:SelectCategory(state.category) end end);C.ApplyStyle(self.start,{width="findStartWidth"});self.start:SetPrimary(true);C.SetPoint(self.start,"TOP",self.emptyHelp,"BOTTOM",0,"findStartTopY")
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
 self:BuildFilters();self:BuildQuickFilters()
 for _,label in ipairs({self.ratingLabel,self.ilvlLabel,self.membersLabel,self.roleLabel,self.socialLabel,self.sortLabel}) do C.SetLineHeight(label,"line20",true) end
 self:BuildSidebarToggle()
 self:LayoutListRows()
end
function P:ApplyResultColumns()
 local titleLabel=self.resultsHeader.labels.title
 titleLabel:ClearAllPoints();C.SetPoint(titleLabel,"LEFT",titleLabel:GetParent(),"LEFT","findTitleLabelLeftX",0);titleLabel:SetWidth(self.resultsHeader.columns.title.width-18)
 for key,cell in pairs(self.resultsHeader.columns) do
  local column=RESULT_COLUMNS[key]
  local inset=key=="title" and T.findResultTitleX or T.findColumnInset
  column.x=cell.x+inset;column.width=cell.width-inset-(key=="title" and 16 or key=="age" and 12 or 8)
 end
 for _,row in ipairs(self.results.rows) do
  row.title:SetWidth(RESULT_COLUMNS.title.width);LayoutResultActivity(row)
  C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT",RESULT_COLUMNS.title.x,"findRowTitleTopleftY")
  row.leader:SetPoint("LEFT",RESULT_COLUMNS.leader.x,0);row.leader:SetWidth(RESULT_COLUMNS.leader.width)
  row.declined:SetWidth(RESULT_COLUMNS.leader.x+RESULT_COLUMNS.leader.width-RESULT_COLUMNS.title.x)
  row.membersX,row.membersWidth=RESULT_COLUMNS.members.x,RESULT_COLUMNS.members.width;LayoutMembers(row)
  row.ilvl:SetPoint("LEFT",RESULT_COLUMNS.ilvl.x,0);row.ilvl:SetWidth(RESULT_COLUMNS.ilvl.width)
  row.description:SetWidth(RESULT_COLUMNS.description.width);row.description:SetPoint("LEFT",RESULT_COLUMNS.description.x,0)
  row.score:SetPoint("LEFT",RESULT_COLUMNS.rating.x,0);row.score:SetWidth(RESULT_COLUMNS.rating.width)
  row.age:SetPoint("LEFT",RESULT_COLUMNS.age.x,0);row.age:SetWidth(RESULT_COLUMNS.age.width)
  row.tooltipArea:SetWidth(self.resultsHeader.columns.title.width)
 end
end
function P:LayoutResultColumns()
 local raid=self.raidResultColumns
 resultDefinitions[3].min=raid and 154 or ResultMemberWidth()+16
 local rating,description=resultDefinitions[5],resultDefinitions[6]
 if rating.key~="rating" then rating,description=description,rating end
 rating.label=raid and Say("进度","Progress") or Say("评分","Score")
 resultDefinitions[5],resultDefinitions[6]=raid and description or rating,raid and rating or description
 self.resultsHeader:SetColumns(resultDefinitions)
 self.resultsHeader:SetState(UI:GetTablePrefs(raid and "findRaidResults" or "findResults"))
 self.resultsHeader:Layout(BODY)
end
function P:RefreshMemberStyle()
 if not self.results then return end
 self:LayoutResultColumns();self.results:Refresh()
end
function P:LayoutApplicationColumns()
 if not self.applicationHeader then return end
 local cols=self.applicationHeader.columns
 APPLICATION_COLUMNS.title.width=cols.title.width-48
 APPLICATION_COLUMNS.leader.x,APPLICATION_COLUMNS.leader.width=cols.leader.x+6,cols.leader.width-12
 for _,row in ipairs(self.appList.rows) do
  row.title:SetWidth(APPLICATION_COLUMNS.title.width)
  row.leader:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x,0);row.leader:SetWidth(APPLICATION_COLUMNS.leader.width)
  row.membersX,row.membersWidth=cols.members.x+6,cols.members.width-12;LayoutMembers(row)
  row.status:SetPoint("LEFT",cols.status.x+6,0);row.status:SetWidth(cols.status.width-12)
  row.cancel:ClearAllPoints();row.cancel:SetPoint("CENTER",row,"LEFT",cols.actions.x+cols.actions.width/2,0)
  row.tooltipArea:SetWidth(cols.title.width)
 end
end
function P:LayoutSidebar(width)
 self.sidebarWidth=width
 MAIN=(self.layoutWidth or T.contentWidth)-width-T.contentGap-T.findContentInset*2;BODY=MAIN-T.findListGutter;APP_BODY=MAIN-T.findApplicationInset*2-T.findListGutter
 local compact=math.min(70,math.max(0,(T.contentWidth-T.findSidebarWidth-T.contentGap-T.findContentInset*2-T.findListGutter)-BODY))
 resultDefinitions[1].width=T.findResultTitleWidth-compact
 for _,def in ipairs(resultDefinitions) do if def.key=="description" then def.width=BODY-753-(zh and T.findAgeWidthCN or T.findAgeWidthEN)+compact end end
 applicationDefinitions[1].width=APP_BODY-542
 local alpha=math.max(0,math.min(1,(width-T.findCollapsedSidebarWidth)/(T.findSidebarWidth-T.findCollapsedSidebarWidth)))
 if math.abs(width-(state.railCollapsed and T.findCollapsedSidebarWidth or T.findSidebarWidth))<1/self.rail:GetEffectiveScale() then alpha=state.railCollapsed and 0 or 1 end
 for _,list in ipairs({self.seasonCategories,self.categories}) do
  list:SetWidth(width)
  if list.indicator then list.indicator:SetWidth(width) end
  for _,row in ipairs(list.rows) do
   row.symbol:SetPoint("LEFT",12+4*alpha,0)
   row.title:SetShown(alpha>0);row.title:SetAlpha(alpha);row.chevron:SetShown(alpha>0);row.chevron:SetAlpha(alpha)
  end
 end
 local buttonInset=4+4*alpha
 C.SetPoint(self.sidebarToggle,"BOTTOMLEFT",self.sidebarToggle:GetParent(),"BOTTOMLEFT",buttonInset,"findSidebarToggleBottomleftY");self.sidebarToggle:SetWidth(width-buttonInset*2)
 self.sidebarToggle.label:SetShown(alpha>0);self.sidebarToggle.label:SetAlpha(alpha)
 self.surface:SetPoint("TOPLEFT",width+T.contentGap,0);self.surface:SetWidth(MAIN+T.findContentInset*2);self.main:SetWidth(MAIN)
 self.applicationPanel:SetWidth(MAIN);self.appList:SetWidth(MAIN-32)
 self.applicationHeader:SetState(UI:GetTablePrefs("findApplications"));self.applicationHeader:Layout(APP_BODY)
 self.results:SetWidth(MAIN);self.resultsHeader:SetWidth(BODY);self.emptyPanel:SetWidth(MAIN)
 self.context:SetWidth(math.min(MAIN-180,self.contextNaturalWidth or self.context:GetStringWidth()))
 self.limitNotice:SetWidth(BODY);self.limitText:SetWidth(BODY-52)
 self:LayoutResultColumns();self:LayoutQuickFilters()
 if self.limitNotice:IsShown() then
  local height=math.max(40,math.ceil(self.limitText:GetStringHeight())+16)
  if self.limitNotice:GetHeight()~=height then self.resultsTop=nil;self:LayoutResults() end
 end
end
function P:LayoutSize(width,height)
 self.layoutWidth,self.layoutHeight=width,height
 HEIGHT=height-T.findContentInset*2
 self.rail:SetHeight(height);self.surface:SetHeight(height);self.main:SetHeight(HEIGHT)
 local categoriesTop=self.seasonCategories:GetHeight()+24
 self.categories:SetViewport(height-categoriesTop-72)
 self:LayoutSidebar(self.rail:GetWidth())
 self.resultsTop=nil;self:LayoutResults();self:LayoutFilters()
end
function P:SetSidebarCollapsed(collapsed,animate,persist)
 state.railCollapsed=collapsed==true
 if UI.preview then
  local prefs=UI:GetGroup().prefs.find or {};UI:GetGroup().prefs.find=prefs;prefs.railCollapsed=state.railCollapsed
 elseif persist~=false then A.Appearance:SaveRailCollapsed(state.railCollapsed) end
 for _,list in ipairs({self.seasonCategories,self.categories}) do if list.indicator then M:FinishRect(list.indicator) end end
 M:Rect(self.rail,0,0,state.railCollapsed and T.findCollapsedSidebarWidth or T.findSidebarWidth,self.layoutHeight or T.contentHeight,animate and T.findSidebarMotionDuration or 0)
 self:LayoutSidebar(self.rail:GetWidth())
end
function P:FinishSidebar()
 M:FinishRect(self.rail)
end
function P:BuildSidebarToggle()
 local button=C.Button(self.rail,Say("收起","Collapse"),T.findSidebarWidth-16,function() P:SetSidebarCollapsed(not state.railCollapsed,true) end,{height=40,radius=8,textColor="muted"})
 C.SetPoint(button,"BOTTOMLEFT",button:GetParent(),"BOTTOMLEFT","findButtonBottomleftX","findButtonBottomleftY");button.label:ClearAllPoints();C.SetPoint(button.label,"LEFT",button.label:GetParent(),"LEFT","findButtonLabelLeftX",0);self.sidebarToggle=button
 local icon=C.Icon(button,T.findIconWidth);C.ApplyStyle(icon,{width="findIconWidth",height="findIconHeight"});C.SetPoint(icon,"LEFT",icon:GetParent(),"LEFT","findIconLeftX",0)
 icon:SetTexture("Interface\\AddOns\\LycheeGroup_UI\\Media\\sidebar-toggle.tga");UI.context:SetIconState(icon,false,false);self.sidebarIcon=icon
 self.rail:HookScript("OnSizeChanged",function(_,width) P:LayoutSidebar(width) end)
 self.frame:HookScript("OnHide",function() P:FinishSidebar() end)
 UI.blocker:HookScript("OnShow",function() if UI.page=="find" then P:FinishSidebar() end end)
 M:Rect(self.rail,0,0,T.findSidebarWidth,T.contentHeight,0)
 self:LayoutSidebar(T.findSidebarWidth)
end
local numericFilterKeys={"minRating","maxRating","minItemLevel","maxItemLevel","minMembers","maxMembers"}
function P:BuildQuickFilters()
 self.quickFilters=CreateFrame("Frame",nil,self.applicationPanel);self.quickChoices={}
 for _,entry in ipairs({{"TANK","tankPresence"},{"HEALER","healerPresence"},{"DAMAGER","damagePresence"}}) do
  local role,key=entry[1],entry[2]
  local button=C.Button(self.quickFilters,"",T.findButtonWidth,function(_,mouse)
   local value=state.filters[key]
   if mouse=="RightButton" then value=nil
   elseif not value then value="missing"
   elseif value=="missing" then
    local presentCount=(state.filters.tankPresence=="present" and 1 or 0)+(state.filters.healerPresence=="present" and 1 or 0)+(state.filters.damagePresence=="present" and 1 or 0)
    value=(state.filters.roleMatchAny or presentCount<2) and "present" or nil
   else value=nil end
   state.filters[key]=value;P:UpdateFilters()
  end,{height=32,radius=8});C.ApplyStyle(button,{width="findButtonWidth"})
  button:RegisterForClicks("LeftButtonUp","RightButtonUp")
  UI.Tooltip:BindText(button,Say("左键切换，右键恢复","Left-click to cycle; right-click to reset."))
  local icon=C.Icon(button,T.findIconWidth2);C.ApplyStyle(icon,{width="findIconWidth2",height="findIconHeight2"});C.SetPoint(icon,"LEFT",icon:GetParent(),"LEFT","findIconLeftX",0);UI:SetRoleIcon(icon,role)
  button.label:ClearAllPoints();C.SetPoint(button.label,"LEFT",button.label:GetParent(),"LEFT","findButtonLabelLeftX2",0);C.SetFont(button.label,"font13")
  self.quickChoices[key]={button=button,role=role}
 end
 self.quickLogic=C.Button(self.quickFilters,"",T.findQuickLogicWidth,function()
  P:SetRoleMatchAny(not state.filters.roleMatchAny)
 end,{height=32,radius=8});C.ApplyStyle(self.quickLogic,{width="findQuickLogicWidth"});C.SetFont(self.quickLogic.label,"font13")
 UI.Tooltip:BindText(self.quickLogic,Say("筛选切换：全部/任意条件符合","Filter matching: all/any conditions."))
 self.quickIdentity=C.Button(self.quickFilters,"",T.findQuickIdentityWidth,function(_,mouse)
  local mode=state.filters.hideSameClass and "class" or state.filters.hideSameSpec and "spec" or "any"
  if mouse=="RightButton" then mode="any"
  else mode=mode=="any" and "class" or mode=="class" and "spec" or "any" end
  P:SetIdentityFilter(mode)
 end,{height=32,radius=8});C.ApplyStyle(self.quickIdentity,{width="findQuickIdentityWidth"})
 self.quickIdentity:RegisterForClicks("LeftButtonUp","RightButtonUp")
 C.SetFont(self.quickIdentity.label,"font13");self.quickIdentity.label:ClearAllPoints();C.SetPoint(self.quickIdentity.label,"LEFT",self.quickIdentity.label:GetParent(),"LEFT","findQuickIdentityLabelLeftX",0)
 self.identityMeasure=C.Text(self.quickIdentity,"","font13");self.identityMeasure:Hide()
 self.quickIdentityIcon=C.GameIcon(self.quickIdentity,T.findQuickIdentityIconWidth);C.ApplyStyle(self.quickIdentityIcon,{width="findQuickIdentityIconWidth",height="findQuickIdentityIconHeight"});C.SetPoint(self.quickIdentityIcon,"LEFT",self.quickIdentityIcon:GetParent(),"LEFT","findQuickIdentityIconLeftX",0)
 self.quickIdentityFunnel=C.Icon(self.quickIdentity,T.findQuickIdentityFunnelWidth);C.ApplyStyle(self.quickIdentityFunnel,{width="findQuickIdentityFunnelWidth",height="findQuickIdentityFunnelHeight"});self.quickIdentityFunnel:SetTexture("Interface\\AddOns\\LycheeGroup_UI\\Media\\filter-any.tga");C.SetPoint(self.quickIdentityFunnel,"LEFT",self.quickIdentityFunnel:GetParent(),"LEFT","findQuickIdentityFunnelLeftX",0)
 UI.Tooltip:BindText(self.quickIdentity,Say("同职过滤/同专精过滤","Same class/spec filter"))
 self.quickFilters:Hide()
end
function P:SetRoleMatchAny(value)
 state.filters.roleMatchAny=value or nil
 if not value and state.filters.tankPresence=="present" and state.filters.healerPresence=="present" and state.filters.damagePresence=="present" then state.filters.damagePresence=nil end
 self:UpdateFilters()
end
function P:SetIdentityFilter(mode)
 state.filters.hideSameClass=mode=="class" or nil
 state.filters.hideSameSpec=mode=="spec" or nil
 self:UpdateFilters()
end
function P:SyncQuickFilters(seasonDungeon)
 self.quickFilters:SetShown(seasonDungeon and A:GetSetting("showImportantFilters")==true)
 self.importantFilters:SetShown(seasonDungeon and not A:GetSetting("showImportantFilters"))
 local presentCount=(state.filters.tankPresence=="present" and 1 or 0)+(state.filters.healerPresence=="present" and 1 or 0)+(state.filters.damagePresence=="present" and 1 or 0)
 for key,entry in pairs(self.quickChoices) do
  local value=state.filters[key]
  UI:SetText(entry.button.label,value=="missing" and Say("缺少","Lacks") or value=="present" and (entry.role=="DAMAGER" and Say("已齐","Full") or Say("已有","Has")) or Say("不限","Any"))
  entry.button:SetActive(value~=nil and value~=false)
  self.presenceChoices[key]:SetValue(value or false)
  self.presenceChoices[key].buttons[3]:SetAvailable(state.filters.roleMatchAny or presentCount<2 or value=="present")
 end
 self.presenceLogic:SetValue(state.filters.roleMatchAny==true)
 self.identityChoice:SetValue(state.filters.hideSameClass and "class" or state.filters.hideSameSpec and "spec" or "any")
 UI:SetText(self.quickLogic.label,state.filters.roleMatchAny and Say("或","OR") or Say("全部","All"))
 self.quickLogic:SetActive(state.filters.roleMatchAny==true)
 local enabled=state.filters.hideSameClass==true or state.filters.hideSameSpec==true
 UI:SetText(self.quickIdentity.label,state.filters.hideSameClass and Say("同职过滤","Same class") or state.filters.hideSameSpec and Say("专精过滤","Same spec") or Say("不限","Any"))
 self.quickIdentity:SetActive(enabled)
 self.quickIdentityIcon:SetShown(enabled);self.quickIdentityFunnel:SetShown(not enabled)
 if enabled then
  local class=select(2,UnitClass("player"))
  local spec=state.filters.hideSameSpec and A.Specializations:Player() or nil
  UI:SetMemberIcon(self.quickIdentityIcon,{class=class,specID=spec})
 end
 self:LayoutQuickFilters()
end
function P:RefreshFilterPlacement()
 self:SyncQuickFilters(self.filterLayout=="presence")
 self:LayoutFilters()
 if UI.page=="find" then UI:FitToScreen() end
end
function P:LayoutQuickFilters()
 if not self.quickFilters then return end
 local height=32
 local roleWidth=0
 for _,label in ipairs({Say("不限","Any"),Say("缺少","Lacks"),Say("已有","Has"),Say("已齐","Full")}) do
  UI:SetText(self.identityMeasure,label);roleWidth=math.max(roleWidth,self.identityMeasure:GetStringWidth())
 end
 roleWidth=math.max(74,math.ceil(roleWidth)+44)
 for _,key in ipairs({"tankPresence","healerPresence","damagePresence"}) do
  local button=self.quickChoices[key].button
  FitText(button.label)
  height=math.max(height,button.label:GetHeight()+12)
  button:SetWidth(roleWidth)
 end
 local labelWidth=0
 for _,label in ipairs({Say("专精过滤","Same spec"),Say("同职过滤","Same class"),Say("不限","Any")}) do
  UI:SetText(self.identityMeasure,label);labelWidth=math.max(labelWidth,self.identityMeasure:GetStringWidth())
 end
 local identityWidth=math.ceil(labelWidth)+40
 local logicWidth=54
 for _,label in ipairs({Say("全部","All"),Say("或","OR")}) do UI:SetText(self.identityMeasure,label);logicWidth=math.max(logicWidth,math.ceil(self.identityMeasure:GetStringWidth())+22) end
 FitText(self.quickLogic.label)
 height=math.max(height,self.quickLogic.label:GetHeight()+12,self.quickIdentity.label:GetHeight()+12)
 for _,entry in pairs(self.quickChoices) do entry.button:SetHeight(height) end
 self.quickIdentity:SetSize(identityWidth,height)
 self.quickLogic:SetSize(logicWidth,height)
 local filterWidth=math.max(84,math.ceil(self.filterToggle.label:GetUnboundedStringWidth())+42)
 self.filterToggle:SetWidth(filterWidth);self.filterToggle.label:SetWidth(filterWidth-42)
 self.searchModeToggle:SetWidth(math.max(56,FitText(self.searchModeToggle.label)+24))
 local right=filterWidth+self.searchModeToggle:GetWidth()+52
 self.search:SetSize(MAIN-60,T.findSearchHeight)
 local rowX=0
 for _,button in ipairs({self.quickChoices.tankPresence.button,self.quickChoices.healerPresence.button,self.quickChoices.damagePresence.button,self.quickIdentity,self.quickLogic}) do
  local gap=rowX>0 and 6 or 0
  button:ClearAllPoints();button:SetPoint("LEFT",rowX+gap,0)
  rowX=rowX+gap+button:GetWidth()
 end
 self.quickFilters:SetSize(rowX,height)
 self.quickFilters:ClearAllPoints();C.SetPoint(self.quickFilters,"RIGHT",self.applicationSettings,"LEFT","findQuickFiltersRightX",0)
 self.quickFilterHeight=0
 local inline=self.quickFilters:IsShown()
 local scope=inline and self.hasOtherApplications
 self.appsTitle:SetShown(not scope)
 self.scopeToggle:SetShown(self.hasOtherApplications==true)
 UI:SetText(self.scopeToggle.label,scope and (state.showGlobal and Say("全部申请","All applications") or Say("本分类申请","This category")) or (state.showGlobal and Say("仅看本分类","This category") or Say("查看全部申请","All applications")))
 self.scopeToggle:SetWidth(FitText(self.scopeToggle.label)+(scope and 12 or 24))
 self.scopeToggle:ClearAllPoints()
 self.appsBadge:ClearAllPoints()
 if scope then
  C.SetPoint(self.scopeToggle,"LEFT",self.applicationPanel,"TOPLEFT","findScopeToggleLeftX2","findScopeToggleLeftY")
  C.SetPoint(self.appsBadge,"LEFT",self.scopeToggle,"RIGHT","findAppsBadgeLeftX",0)
 else
  C.SetPoint(self.appsBadge,"LEFT",self.appsTitle,"RIGHT","findAppsBadgeLeftX",0)
  C.SetPoint(self.scopeToggle,"LEFT",self.appsBadge,"RIGHT","findScopeToggleLeftX",0)
 end
 local infoWidth=self.appsTitle:GetStringWidth()
 for _,label in ipairs({Say("全部申请","All applications"),Say("本分类申请","This category")}) do
  UI:SetText(self.applicationInfoMeasure,label);infoWidth=math.max(infoWidth,self.applicationInfoMeasure:GetStringWidth()+14)
 end
 local autoWidth=16+self.autoJoin:GetWidth()+20+self.autoApply:GetWidth()+10+self.applicationSettings:GetWidth()
 self.minimumMainWidth=math.ceil(16+infoWidth+10+self.appsBadge:GetWidth()+12+rowX+12+autoWidth)
 local emptyWidth=MAIN-autoWidth-(inline and rowX+24 or 12)-(16+self.appsTitle:GetStringWidth()+10+self.appsBadge:GetWidth()+12)
 self.appsEmpty:SetShown(self.noApplications==true and emptyWidth>=self.appsEmpty:GetStringWidth())
 self.searchInputRight=right
 self:LayoutSearchInput()
 self.applicationPanel:SetPoint("TOPLEFT",0,-T.findApplicationTop);self.applicationPanel:SetHeight(44+(self.appsHeight or 0))
 self.applicationHeader:ClearAllPoints();C.SetPoint(self.applicationHeader,"TOPLEFT",self.applicationHeader:GetParent(),"TOPLEFT","findApplicationHeaderTopleftX","findApplicationHeaderTopleftY")
 self.appList:ClearAllPoints();C.SetPoint(self.appList,"TOPLEFT",self.appList:GetParent(),"TOPLEFT","findAppListTopleftX",-44-self.applicationHeader:GetHeight())
end
function P:GetMinimumWidth()
 if not self.quickFilters or not self.quickFilters:IsShown() then return 0 end
 return UI.frame:GetWidth()-MAIN+self.minimumMainWidth
end
function P:LayoutSearchInput()
 local right,bottom=self.searchInputRight,4
 local function Layout(box)
  box:ClearAllPoints();C.SetPoint(box,"TOPLEFT",self.search,"TOPLEFT","findBoxTopleftX","findBoxTopleftY");box:SetPoint("BOTTOMRIGHT",self.search,"BOTTOMRIGHT",-right,bottom)
  box:SetSize(self.search:GetWidth()-52-right,40)
 end
 Layout(self.previewSearchBox)
 local lease=UI.Native.searchLease
 if lease and lease.owner==self and lease:IsOwned() then Layout(lease.box) end
 self.searchHint:SetWidth(self.search:GetWidth()-52-right)
 self.searchClear:ClearAllPoints();C.SetPoint(self.searchClear,"RIGHT",self.searchModeToggle,"LEFT","findSearchClearRightX",0)
end
function P:SyncFilterFields()
 self.syncingFilterFields=true
 for _,key in ipairs(numericFilterKeys) do self.filterFields[key].box:SetText(state.filters[key] and tostring(state.filters[key]) or "") end
 UI:SetText(self.filterError,"");self.syncingFilterFields=nil
end
function P:UpdateMemberLimit()
 local catalog=UI:GetGroup().Catalog;local maximum=0
 for _,activity in ipairs(catalog:GetActivities(state.category)) do
  if catalog:Matches(activity,state.category,state.groupKey,state.difficultyID,state.tier,state.groupKeys) then
   local capacity=activity.maxNumPlayers
   if capacity==0 then capacity=activity.categoryID==9 and CONQUEST_SIZES[5] or MAX_RAID_MEMBERS end
   maximum=math.max(maximum,capacity)
  end
 end
 if maximum==0 then maximum=Category().id==2 and 5 or MAX_RAID_MEMBERS end
 if self.memberLimit==maximum then return end
 self.memberLimit=maximum
 self.fMinMembers:SetPlaceholder(Say("最少 1","Min 1"));self.fMembers:SetPlaceholder(Say("最多 %d","Max %d"):format(maximum))
 local filters=state.filters
 for _,key in ipairs({"minMembers","maxMembers"}) do
  local value=tonumber(filters[key])
  filters[key]=value and math.max(1,math.min(maximum,math.floor(value))) or nil
 end
 if filters.minMembers and filters.maxMembers and filters.minMembers>filters.maxMembers then
  filters.minMembers,filters.maxMembers=filters.maxMembers,filters.minMembers
 end
 self.syncingFilterFields=true
 for _,key in ipairs({"minMembers","maxMembers"}) do self.filterFields[key].box:SetText(filters[key] and tostring(filters[key]) or "") end
 self.syncingFilterFields=nil
end
function P:ApplyFilterFields()
 if self.loading or self.syncingFilterFields then return true end
 local values,err={}
 for _,key in ipairs(numericFilterKeys) do
  local raw=self.filterFields[key].box:GetText():match("^%s*(.-)%s*$")
  if raw~="" then
   local value=tonumber(raw)
   local members=key=="minMembers" or key=="maxMembers"
   local minimum,maximum=members and 1 or 0,members and self.memberLimit or 99999
   if not value or value<minimum or value>maximum or value%1~=0 then
    err=members and Say("队伍人数请输入 1 至 %d 的整数，或留空。","Group size must be an integer from 1 to %d, or blank."):format(maximum) or Say("请输入 0 至 99999 的整数，或留空。","Enter an integer from 0 to 99999, or leave blank.");break
   end
   values[key]=value
  end
 end
 if not err and (values.minRating and values.maxRating and values.minRating>values.maxRating or values.minItemLevel and values.maxItemLevel and values.minItemLevel>values.maxItemLevel or values.minMembers and values.maxMembers and values.minMembers>values.maxMembers) then err=Say("最低值不能大于最高值。","Minimum must not exceed maximum.") end
 UI:SetText(self.filterError,err or "");self:LayoutFilters()
 if err then return false end
 for _,key in ipairs(numericFilterKeys) do state.filters[key]=values[key] end
 self:UpdateFilters();return true
end
function P:BuildFilters()
 local f=CreateFrame("Frame",nil,UI.frame);C.ApplyStyle(f,{width="findFWidth",height="findFHeight"});C.SetPoint(f,"TOPRIGHT",UI.frame,"TOPRIGHT","findFToprightX","findFToprightY");f:SetFrameLevel(UI.frame:GetFrameLevel()+5);f:SetFrameStrata("DIALOG");f:EnableMouse(true);C.Panel(f,"panel","findPanelRadius2");self.filterPanel=f
 local scrim=CreateFrame("Button",nil,UI.frame);scrim:SetAllPoints(UI.frame);scrim:SetFrameStrata("DIALOG");scrim:SetFrameLevel(UI.frame:GetFrameLevel()+4)
 C.Fill(scrim,"findFilterScrimColor");scrim:SetScript("OnClick",function() P:SetFiltersOpen(false) end);scrim:Hide();self.filterScrim=scrim
 f:HookScript("OnShow",function() scrim:Show() end)
 f:HookScript("OnHide",function() scrim:Hide() end)
 self.filterTitle=C.Text(f,Say("筛选队伍","Filter groups"),"font20");C.SetLineHeight(self.filterTitle,"line24",true)
 local close=C.IconButton(f,"close",T.findCloseWidth,function() P:SetFiltersOpen(false) end,{iconSize=20});C.ApplyStyle(close,{width="findCloseWidth",height="findCloseHeight"});C.SetPoint(close,"TOPRIGHT",close:GetParent(),"TOPRIGHT","findCloseToprightX","findCloseToprightY")
 self.filterStatus=C.Text(f,"","font14","dim",T.findFilterStatusWidth);C.ApplyStyle(self.filterStatus,{width="findFilterStatusWidth"});C.SetLineHeight(self.filterStatus,"line20",true)
 self.clearFilters=C.Button(f,Say("重置","Reset"),T.findClearFiltersWidth,function() P:ClearFilters() end,{variant="text",height=32});C.ApplyStyle(self.clearFilters,{width="findClearFiltersWidth"})
 local important=CreateFrame("Frame",nil,f);C.ApplyStyle(important,{width="findImportantWidth"});self.importantFilters=important
 local function Segments(entries,onChange)
  return C.Segmented(important,T.findSegmentWidth,entries,onChange,{
   height="findSegmentHeight",padding="findSegmentPadding",gap="findSegmentGap",radius="findSegmentRadius",
   fontSize="findSegmentFont",lineHeight="findSegmentLine",selectionMotion=false,wordWrap=false
  })
 end
 self.presenceChoices={};self.presenceLabels={};self.presenceIcons={}
 for _,entry in ipairs({{"TANK","tankPresence",L.tank},{"HEALER","healerPresence",L.healer},{"DAMAGER","damagePresence",L.damage}}) do
  local role,key=entry[1],entry[2]
  local label=C.Text(important,entry[3],"font14","muted");C.SetLineHeight(label,"line20",true);self.presenceLabels[key]=label
  local icon=C.Icon(important,T.findIconWidth2);C.ApplyStyle(icon,{width="findIconWidth2",height="findIconHeight2"});UI:SetRoleIcon(icon,role);self.presenceIcons[key]=icon
  self.presenceChoices[key]=Segments({{value=false,label=Say("不限","Any")},{value="missing",label=Say("缺少","Missing")},{value="present",label=role=="DAMAGER" and Say("已齐","Full") or Say("已有","Present")}},function(value) state.filters[key]=value or nil;P:UpdateFilters() end)
  UI.Tooltip:BindText(self.presenceChoices[key].buttons[3],Say("全部满足时，最多选择两项已有／已齐。","Match all allows at most two Present / Full conditions."))
 end
 self.presenceLogicLabel=C.Text(important,Say("匹配方式","Match mode"),"font14","muted");C.SetLineHeight(self.presenceLogicLabel,"line20",true)
 self.presenceLogic=Segments({{value=false,label=Say("全部满足","Match all")},{value=true,label=Say("任一满足","Match any")}},function(value) P:SetRoleMatchAny(value) end)
 self.identityLabel=C.Text(important,Say("同职过滤","Class/spec filter"),"font14","muted");C.SetLineHeight(self.identityLabel,"line20",true)
 self.identityChoice=Segments({{value="any",label=Say("不限","Any")},{value="class",label=Say("同职业","My class")},{value="spec",label=Say("同专精","My spec")}},function(value) P:SetIdentityFilter(value) end)
 for _,button in ipairs(self.identityChoice.buttons) do UI.Tooltip:BindText(button,Say("排除已有同职业或同专精成员的队伍，始终与其他条件共同满足。","Hide groups with your class or specialization. This always combines with the other filters.")) end
 important:Hide()
 self.filterFields={}
 for _,key in ipairs(numericFilterKeys) do
  local field=C.Number(f,T.findFieldWidth,T.findFieldHeight,function() P:ApplyFilterFields() end);C.ApplyStyle(field,{width="findFieldWidth",height="findFieldHeight"});field.box:SetMaxLetters(5)
  field:SetPlaceholder(key:sub(1,3)=="min" and Say("最低","Min") or Say("最高","Max"));self.filterFields[key]=field
 end
 self.ratingLabel=C.Text(f,Say("队长评分","Leader rating"),"font14","muted",T.findRatingLabelWidth);C.ApplyStyle(self.ratingLabel,{width="findRatingLabelWidth"})
 self.ilvlLabel=C.Text(f,Say("要求装等","Required item level"),"font14","muted",T.findIlvlLabelWidth);C.ApplyStyle(self.ilvlLabel,{width="findIlvlLabelWidth"})
 self.membersLabel=C.Text(f,Say("队伍人数","Group size"),"font14","muted",T.findMembersLabelWidth);C.ApplyStyle(self.membersLabel,{width="findMembersLabelWidth"})
 self.fMinMembers,self.fMembers=self.filterFields.minMembers,self.filterFields.maxMembers
 self.roleLabel=C.Text(f,Say("队伍缺少职责","Role needed"),"font14","muted",T.findRoleLabelWidth);C.ApplyStyle(self.roleLabel,{width="findRoleLabelWidth"})
 self.roleChoice=C.Choice(f,T.findRoleChoiceWidth,{{value=false,label=L.anyRole},{value="TANK",label=L.tank},{value="HEALER",label=L.healer},{value="DAMAGER",label=L.damage}},function(value) state.filters.neededRole=value or nil;P:UpdateFilters() end);C.ApplyStyle(self.roleChoice,{width="findRoleChoiceWidth"})
 self.hideZeroScore=C.Check(f,Say("过滤队长 0 分队伍","Hide 0-score leaders"),function(value) state.filters.hideZeroScore=value or nil;P:UpdateFilters() end)
 C.ApplyStyle(self.hideZeroScore,{width="findHideZeroScoreWidth",height="findHideZeroScoreHeight"});C.SetFont(self.hideZeroScore.label,"font14");C.SetLineHeight(self.hideZeroScore.label,"line20",true)
 self.hideZeroScore.label:ClearAllPoints();self.hideZeroScore.label:SetPoint("LEFT");C.ApplyStyle(self.hideZeroScore.label,{width="findHideZeroScoreLabelWidth"})
 self.hideZeroScore.track:ClearAllPoints();self.hideZeroScore.track:SetPoint("RIGHT")
 self.socialLabel=C.Text(f,Say("关系与笔记","Relations and notes"),"font14","muted")
 self.socialChoice=C.Choice(f,T.findSocialChoiceWidth,{{value=false,label=Say("全部关系","All relations")},{value="friend",label=Say("好友在队","Friends in group")},{value="guild",label=Say("同公会成员","Guildmates")},{value="any",label=Say("含笔记记录","With player notes")},{value="positive",label=Say("含推荐玩家","Recommended players")},{value="noCaution",label=Say("不含拉黑记录","Without blocked players")}},function(value) state.social=value or nil;P:UpdateFilters() end);C.ApplyStyle(self.socialChoice,{width="findSocialChoiceWidth"})
 self.sortLabel=C.Text(f,L.sort,"font14","muted")
 self.sortChoice=C.Choice(f,T.findSortChoiceWidth,{{value="newest",label=L.newest},{value="rating",label=Say("队长评分","Leader rating")},{value="itemLevel",label=Say("要求装等","Required item level")},{value="members",label=L.members}},function(value)
  state.filters.sort=value;P.resultsHeader:SetSort(nil,false,true);P:UpdateFilters()
 end);C.ApplyStyle(self.sortChoice,{width="findSortChoiceWidth"})
 self.filterError=C.Text(f,"","font13","warning",T.findFilterErrorWidth);C.ApplyStyle(self.filterError,{width="findFilterErrorWidth"});C.SetLineHeight(self.filterError,"line20",true)
 self.filterDone=C.Button(f,Say("完成","Done"),T.findFilterDoneWidth,function() if P:ApplyFilterFields() then P:SetFiltersOpen(false) end end,{height=34});C.ApplyStyle(self.filterDone,{width="findFilterDoneWidth"});self.filterDone:SetPrimary(true)
 f:Hide()
end
function P:LayoutFilters()
 if not self.filterPanel then return end
 local function Place(frame,x,y) frame:ClearAllPoints();frame:SetPoint("TOPLEFT",x,-y) end
 local expanded=self.importantFilters:IsShown()
 local width=expanded and 592 or 368
 local inner=width-40
 self.filterPanel:SetWidth(width)
 Place(self.filterTitle,20,18)
 local y=18+self.filterTitle:GetHeight()+18
 local fieldHeight=math.max(36,math.ceil(self.socialChoice.label:GetHeight()+12))
 if expanded then
  Place(self.importantFilters,20,y)
  self.importantFilters:SetWidth(inner)
  local labelWidth=math.max(FitText(self.presenceLogicLabel),FitText(self.identityLabel))
  for _,label in pairs(self.presenceLabels) do labelWidth=math.max(labelWidth,FitText(label)+26) end
  local controlX=labelWidth+16
  local top=0
  local function SegmentRow(label,control,icon)
   local height=math.max(36,control.buttons[1].label:GetHeight()+18)
   Place(label,icon and 26 or 0,top+(height-label:GetHeight())/2)
   if icon then Place(icon,0,top+(height-18)/2) end
   control:Layout(inner-controlX,height);Place(control,controlX,top)
   top=top+height+6
  end
  for _,key in ipairs({"tankPresence","healerPresence","damagePresence"}) do SegmentRow(self.presenceLabels[key],self.presenceChoices[key],self.presenceIcons[key]) end
  SegmentRow(self.presenceLogicLabel,self.presenceLogic)
  SegmentRow(self.identityLabel,self.identityChoice)
  self.importantFilters:SetHeight(top-6);y=y+top+14
  local column=(inner-20)/2
  local right=20+column+20
  local function Range(label,low,high,x)
   label:SetWidth(column);Place(label,x,y)
   local top=y+label:GetHeight()+6
   low:SetSize((column-8)/2,fieldHeight);high:SetSize((column-8)/2,fieldHeight)
   Place(low,x,top);Place(high,x+(column+8)/2,top)
   return top+fieldHeight
  end
  local function Choice(label,control,x)
   label:SetWidth(column);Place(label,x,y)
   local top=y+label:GetHeight()+6
   control:SetSize(column,fieldHeight);Place(control,x,top)
   return top+fieldHeight
  end
  y=math.max(Range(self.ratingLabel,self.filterFields.minRating,self.filterFields.maxRating,20),Range(self.ilvlLabel,self.filterFields.minItemLevel,self.filterFields.maxItemLevel,right))+14
  y=math.max(Range(self.membersLabel,self.fMinMembers,self.fMembers,20),Choice(self.socialLabel,self.socialChoice,right))+14
  local bottom=Choice(self.sortLabel,self.sortChoice,right)
  self.hideZeroScore.label:SetWidth(column-54)
  self.hideZeroScore:SetSize(column,math.max(32,self.hideZeroScore.label:GetStringHeight()))
  Place(self.hideZeroScore,20,y+(bottom-y-self.hideZeroScore:GetHeight())/2)
  y=math.max(bottom,y+self.hideZeroScore:GetHeight())+18
 else
  for _,row in ipairs({{self.ratingLabel,self.filterFields.minRating,self.filterFields.maxRating},{self.ilvlLabel,self.filterFields.minItemLevel,self.filterFields.maxItemLevel},{self.membersLabel,self.fMinMembers,self.fMembers}}) do
   row[1]:SetWidth(100)
   local height=math.max(fieldHeight,row[1]:GetStringHeight())
   Place(row[1],20,y+(height-row[1]:GetHeight())/2)
   for i=2,3 do row[i]:SetSize(104,height);Place(row[i],132+(i-2)*112,y) end
   y=y+height+12
  end
  for _,row in ipairs({{self.socialLabel,self.socialChoice},{self.sortLabel,self.sortChoice}}) do
   row[1]:SetWidth(inner);Place(row[1],20,y);y=y+row[1]:GetHeight()+6
   row[2]:SetSize(inner,fieldHeight);Place(row[2],20,y);y=y+fieldHeight+14
  end
  if self.filterLayout=="presence" then
   self.hideZeroScore.label:SetWidth(inner-54)
   self.hideZeroScore:SetSize(inner,math.max(32,self.hideZeroScore.label:GetStringHeight()))
   Place(self.hideZeroScore,20,y);y=y+self.hideZeroScore:GetHeight()+12
  elseif self.filterLayout=="needed" then
   self.roleLabel:SetWidth(inner);Place(self.roleLabel,20,y);y=y+self.roleLabel:GetHeight()+6
   self.roleChoice:SetSize(inner,fieldHeight);Place(self.roleChoice,20,y);y=y+fieldHeight+12
  end
 end
 local hasError=self.filterError:GetText()~=""
 self.filterError:SetWidth(inner)
 self.filterError:SetShown(hasError)
 if hasError then self.filterError:SetHeight(math.ceil(self.filterError:GetStringHeight()));Place(self.filterError,20,y);y=y+self.filterError:GetHeight()+8 end
 self.filterDone:SetSize(math.max(88,self.filterDone.label:GetStringWidth()+28),math.max(34,self.filterDone.label:GetHeight()+12))
 self.clearFilters:SetSize(math.max(72,self.clearFilters.label:GetStringWidth()+20),math.max(32,self.clearFilters.label:GetHeight()+8))
 self.filterStatus:SetWidth(inner-self.clearFilters:GetWidth()-self.filterDone:GetWidth()-24)
 self.filterStatus:SetHeight(math.ceil(self.filterStatus:GetStringHeight()))
 local footerHeight=math.max(self.filterStatus:GetHeight(),self.clearFilters:GetHeight(),self.filterDone:GetHeight())
 Place(self.filterStatus,20,y+(footerHeight-self.filterStatus:GetHeight())/2)
 Place(self.clearFilters,width-32-self.filterDone:GetWidth()-self.clearFilters:GetWidth(),y+(footerHeight-self.clearFilters:GetHeight())/2)
 Place(self.filterDone,width-20-self.filterDone:GetWidth(),y+(footerHeight-self.filterDone:GetHeight())/2)
 self.filterPanel:SetHeight(y+footerHeight+20)
end
function P:UpdateFilterSummary()
 local filters=state.filters
 local count=(filters.minMembers or filters.maxMembers) and 1 or 0
 if filters.minRating or filters.maxRating then count=count+1 end
 if filters.minItemLevel or filters.maxItemLevel then count=count+1 end
 for _,key in ipairs({"neededRole","tankPresence","healerPresence","damagePresence","hideZeroScore","hideSameSpec","hideSameClass"}) do if filters[key] then count=count+1 end end
 if state.social then count=count+1 end
 local sortChanged=filters.sort~=A:GetSetting("defaultSort")
 self.filterCount=count
 UI:SetText(self.filterToggle.label,count>0 and Say("筛选 ","Filters ")..count or Say("筛选","Filters"))
 self.filterToggle:SetTextColors(count>0 and T.brand or T.muted,T.text,T.onSecondaryContainer)
 self.clearFilters:SetAvailable(count>0 or sortChanged)
 self:UpdateFilterResultSummary()
end
function P:UpdateFilterResultSummary()
 local count=self.filterCount or 0
 UI:SetText(self.filterStatus,state.browseReady and Say("%d 项条件 · %d 支队伍","%d filters · %d groups"):format(count,self.filteredResultCount or 0) or Say("%d 项条件 · 待搜索","%d filters · No search yet"):format(count))
 self:LayoutFilters()
end
function P:SetFiltersOpen(open)
 local wasOpen=self.filterPanel:IsShown()
 self.filtersOpen=open==true
 if self.filtersOpen and not wasOpen then UI:StopTableDrags();self:SyncFilterFields();self:LayoutFilters() end
 if not self.filtersOpen then M:FinishPlacement(self.filterPanel) end
 self.filterPanel:SetShown(self.filtersOpen);self:ClosePicker();UI.Tooltip:Hide()
 UI:FitToScreen()
 self.filterToggle:SetActive(self.filtersOpen);self.filterChevron:SetRotation(self.filtersOpen and math.pi or 0);self.filterChevron:SetVertexColor(unpack(self.filtersOpen and T.accent or T.muted))
 if self.filtersOpen and not wasOpen then M:Reveal(self.filterPanel,"TOPRIGHT",UI.frame,"TOPRIGHT",-T.findFilterWindowInset,-T.findFilterWindowTop,T.findFilterMotionOffset,0,T.findFilterMotionDuration) end
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
 local f=CreateFrame("Frame",nil,self.frame);C.ApplyStyle(f,{width="findFWidth2",height="findFHeight2"});f:SetPoint("TOPLEFT",self.rail,"TOPRIGHT",T.findPickerGap,0);f:SetFrameLevel(self.frame:GetFrameLevel()+35);f:EnableMouse(true);C.Panel(f,"surface","findPanelRadius3");self.picker=f
 f.title=C.Text(f,"","font14","text",T.findFTitleWidth);C.ApplyStyle(f.title,{width="findFTitleWidth"});C.SetLineHeight(f.title,"line21",true);C.SetPoint(f.title,"TOPLEFT",f.title:GetParent(),"TOPLEFT","findFTitleTopleftX","findFTitleTopleftY")
 local close=C.IconButton(f,"close",T.findCloseWidth2,function() P:ClosePicker() end);C.ApplyStyle(close,{width="findCloseWidth2",height="findCloseHeight2"});C.SetPoint(close,"TOPRIGHT",close:GetParent(),"TOPRIGHT","findCloseToprightX2","findCloseToprightY2")
 self.tierChoice=C.Choice(f,T.findTierChoiceWidth,function() return P:TierItems() end,function(value)
  state.browseReady=false;UI:GetGroup().Search:EndBrowse()
  state.tier=value or nil;state.groupKey,state.groupKeys=nil,nil;P.draftGroupKeys=nil;state.difficultyID=nil
  P:RefreshPicker();P.results:SetPixelOffset(0,false);P:UpdateFilters(true)
 end);C.ApplyStyle(self.tierChoice,{width="findTierChoiceWidth"});C.ApplyStyle(self.tierChoice,{height="findTierChoiceHeight"});C.SetPoint(self.tierChoice,"TOPLEFT",self.tierChoice:GetParent(),"TOPLEFT","findTierChoiceTopleftX","findTierChoiceTopleftY")
 self.tierChoice:SetSurfaceVariant("dark")
 self.difficultySurface=CreateFrame("Frame",nil,f);C.ApplyStyle(self.difficultySurface,{width="findDifficultySurfaceWidth",height="findDifficultySurfaceHeight"});C.Panel(self.difficultySurface,"surfaceLow","findPanelRadius4")
 self.difficultySelection=C.Selection(self.difficultySurface)
 self.difficultyButtons={}
 for i=1,12 do self.difficultyButtons[i]=C.Button(self.difficultySurface,"",T.findButtonWidth2,function(button) state.difficultyID=button.value or nil;P:RefreshPicker();P.results:SetPixelOffset(0,false);if state.browseReady then P:CommitChoice();P:DoSearch(true) else P:UpdateFilters(true) end end,{variant="compact",selectionFill=false}) end
 self.activities=C.List(f,T.findActivitiesWidth,T.findActivitiesHeight,48,function(key)
  if P.keystoneGroups and P.keystoneGroups[key] then P:ToggleGroupChoice(key);return end
  state.groupKeys=nil;P.draftGroupKeys=nil
  state.groupKey=key~=0 and key or nil
  local valid=not state.difficultyID
  for _,activity in ipairs(UI:GetGroup().Catalog:GetActivities(state.category)) do if (not state.groupKey or UI:GetGroup().Catalog:GetGroupKey(state.category,activity)==state.groupKey) and activity.difficultyID==state.difficultyID then valid=true;break end end
  if not valid then state.difficultyID=nil end
  P:RefreshPicker();P:CommitChoice();P.results:SetPixelOffset(0,false);P:DoSearch()
 end);C.ApplyStyle(self.activities,{width="findActivitiesWidth",height="findActivitiesHeight"})
 self.activities:SetStyle({alternateRows=false,rowHeight=44,radius=8,singleLine=true,titleX=48,titleWidth=200,titleSize=16,titleLineHeight=22})
 self.activityIDs={};self.activityMap={}
 for _,row in ipairs(self.activities.rows) do
  row.icon=C.Icon(row,T.findRowIconWidth);C.ApplyStyle(row.icon,{width="findRowIconWidth",height="findRowIconHeight"});C.SetPoint(row.icon,"LEFT",row.icon:GetParent(),"LEFT","findRowIconLeftX",0)
  row.multiSelect=C.Checkbox(row,function() P:ToggleGroupChoice(row.key) end);C.SetPoint(row.multiSelect,"RIGHT",row.multiSelect:GetParent(),"RIGHT","findRowMultiSelectRightX",0)
 end
 self.pickerConfirm=C.Button(f,Say("确定","Confirm"),T.findPickerConfirmWidth,function()
  state.groupKeys=CopyGroupKeys(P.draftGroupKeys);state.groupKey=nil;P:CommitChoice()
  P.results:SetPixelOffset(0,false);P:DoSearch()
 end);C.ApplyStyle(self.pickerConfirm,{width="findPickerConfirmWidth"});self.pickerConfirm:SetPrimary(true);C.ApplyStyle(self.pickerConfirm,{height="findPickerConfirmHeight"});self.pickerConfirm:Hide()
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
 if M.placements[self.picker] then M:Reveal(self.picker,"TOPLEFT",self.rail,"TOPRIGHT",T.findPickerGap,-y,0,T.findPickerMotionOffset,T.findPickerMotionDuration)
 elseif self.pickerY~=y then self.picker:SetPoint("TOPLEFT",self.rail,"TOPRIGHT",T.findPickerGap,-y) end
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
 self.difficultySurface:ClearAllPoints();C.SetPoint(self.difficultySurface,"TOPLEFT",self.difficultySurface:GetParent(),"TOPLEFT","findDifficultySurfaceTopleftX",-top)
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
 self.activities:ClearAllPoints();C.SetPoint(self.activities,"TOPLEFT",self.activities:GetParent(),"TOPLEFT","findActivitiesTopleftX",-top);self.activities:SetViewport(listHeight);self.picker:SetHeight(top+listHeight+(confirm and 64 or 8))
 self.pickerConfirm:SetShown(confirm);self.pickerConfirm:SetWidth(menuWidth-16);self.pickerConfirm:ClearAllPoints();C.SetPoint(self.pickerConfirm,"TOPLEFT",self.pickerConfirm:GetParent(),"TOPLEFT","findPickerConfirmTopleftX",-top-listHeight-8)
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
 if changed or not self.picker:IsShown() then self.picker:Show();self.picker:RegisterEvent("GLOBAL_MOUSE_DOWN");M:Reveal(self.picker,"TOPLEFT",self.rail,"TOPRIGHT",T.findPickerGap,-self.pickerY,0,T.findPickerMotionOffset,T.findPickerMotionDuration) else self:ClosePicker() end
 if changed and state.browseReady then self:DoSearch(true) end
end
function P:RememberCategory()
 if not A:GetSetting("rememberFilters") then return end
 local prefs=state.categoryPrefs[state.category] or {};state.categoryPrefs[state.category]=prefs
 local choice=state.confirmedChoice or {}
 prefs.groupKey,prefs.tier,prefs.difficultyID=choice.groupKey,choice.tier,choice.difficultyID
 prefs.groupKeys=CopyGroupKeys(choice.groupKeys)
 prefs.selected=choice.selected==true
 prefs.minLevel,prefs.maxLevel=nil,nil
 local cat=Category();local seasonDungeon=cat.id==2 and cat.season
 prefs.neededRole=not seasonDungeon and self.roleChoice.value or nil
 prefs.tankPresence,prefs.healerPresence,prefs.damagePresence=state.filters.tankPresence,state.filters.healerPresence,state.filters.damagePresence
 prefs.hideZeroScore=state.filters.hideZeroScore
 prefs.hideSameSpec=state.filters.hideSameSpec
 prefs.hideSameClass=state.filters.hideSameClass
 prefs.roleMatchAny=state.filters.roleMatchAny
 for _,key in ipairs(numericFilterKeys) do prefs[key]=state.filters[key] end
 prefs.social=state.social;prefs.sort=state.filters.sort
end
function P:RestoreCategory(prefs)
 if prefs.hideSameClass then prefs.hideSameSpec=nil end
 self.loading=true
 state.groupKeys=CopyGroupKeys(prefs.groupKeys)
 state.confirmedChoice=ChoiceSnapshot(prefs);self.restoringChoice=true
 local cat=Category();local seasonDungeon=cat and cat.id==2 and cat.season
 local role=not seasonDungeon and prefs.neededRole or nil
 if seasonDungeon then
  prefs.tankPresence=prefs.tankPresence or prefs.neededRole=="TANK" and "missing" or nil
  prefs.healerPresence=prefs.healerPresence or prefs.neededRole=="HEALER" and "missing" or nil
  prefs.damagePresence=prefs.damagePresence or (prefs.needsDamage or prefs.neededRole=="DAMAGER") and "missing" or nil
  if not prefs.roleMatchAny and prefs.tankPresence=="present" and prefs.healerPresence=="present" and prefs.damagePresence=="present" then prefs.damagePresence=nil end
  prefs.neededRole=nil
 end
 prefs.needsDamage=nil
 state.filters.tankPresence=seasonDungeon and prefs.tankPresence or nil
 state.filters.healerPresence=seasonDungeon and prefs.healerPresence or nil
 state.filters.damagePresence=seasonDungeon and prefs.damagePresence or nil
 state.filters.hideZeroScore=seasonDungeon and prefs.hideZeroScore or nil
 state.filters.hideSameSpec=seasonDungeon and prefs.hideSameSpec or nil
 state.filters.hideSameClass=seasonDungeon and prefs.hideSameClass or nil
 state.filters.roleMatchAny=seasonDungeon and prefs.roleMatchAny or nil
 for _,key in ipairs(numericFilterKeys) do state.filters[key]=prefs[key] end
 self.memberLimit=nil;self:UpdateMemberLimit()
 self:SyncFilterFields()
 self.roleChoice:SetValue(role or false,role and ({TANK=L.tank,HEALER=L.healer,DAMAGER=L.damage})[role] or L.anyRole)
 state.social=prefs.social=="caution" and "noCaution" or prefs.social;self.socialChoice:SetValue(state.social or false,state.social and ({friend=L.friendChar,guild=L.friendGuild,any=L.notes,positive=Say("含推荐玩家","Recommended players"),noCaution=Say("不含拉黑记录","Without blocked players")})[state.social] or Say("全部关系","All relations"))
 state.filters.sort=prefs.sort or A:GetSetting("defaultSort");self.sortChoice:SetValue(state.filters.sort,L[state.filters.sort] or L.newest)
 self.loading=nil
end
function P:SyncSearchInputMode()
 if not self.search or not self.searchModeToggle then return false end
 local wantsNative=state.searchMode=="group"
 self.searchModeToggle:Show()
 self.searchModeToggle:SetActive(state.searchMode=="leader")
 UI:SetText(self.searchModeToggle.label,state.searchMode=="leader" and Say("队长","Leader") or Say("标题","Title"))
 self:LayoutQuickFilters()
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
 self:UpdateMemberLimit()
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
 filters.neededRole=not seasonDungeon and keys and self.roleChoice.value or nil
 if not seasonDungeon then filters.tankPresence,filters.healerPresence,filters.damagePresence,filters.hideZeroScore,filters.hideSameSpec,filters.hideSameClass,filters.roleMatchAny=nil,nil,nil,nil,nil,nil,nil end
 if filters.hideSameClass then filters.hideSameSpec=nil end
 self.hideZeroScore:SetShown(seasonDungeon);self.hideZeroScore:SetValue(filters.hideZeroScore)
 filters.friends=state.social=="friend";filters.guild=state.social=="guild";filters.notes=(state.social=="any" or state.social=="positive" or state.social=="noCaution") and state.social or nil
 self.roleChoice:SetShown(keys and not seasonDungeon);self.roleLabel:SetShown(keys and not seasonDungeon)
 self:UpdateFilterSummary()
 self:SyncQuickFilters(seasonDungeon)
 local layout=seasonDungeon and "presence" or keys and "needed" or "basic"
 if self.filterLayout~=layout then
  self.filterLayout=layout
  self:LayoutFilters()
 end
 if reset then self.results:SetPixelOffset(0,false) end
 local group=state.groupKey and UI:GetGroup().Catalog:GetGroup(state.category,state.groupKey)
 local name=group and group.name or state.browseReady and AllActivitiesLabel(cat) or cat.name
 if state.groupKeys then
  local catalog=UI:GetGroup().Catalog;local names={};local selected
  for _,entry in ipairs(catalog:GetGroups(state.category)) do if state.groupKeys[entry.key] then names[#names+1]=catalog:GetGroupShortName(state.category,entry.key);selected=entry end end
  if #names==1 then name=selected.name elseif #names>1 then name=table.concat(names,"·") end
 end
 if state.difficultyID then name=name.."  ·  "..(GetDifficultyInfo(state.difficultyID) or L.unknown) end
 UI:SetText(self.context,name);self.contextNaturalWidth=FitText(self.context);self.context:SetWidth(math.min(MAIN-180,self.contextNaturalWidth))
 self:SavePrefs()
 -- The provider notifies results after all filter controls and context are ready.
 UI:GetGroup():SetFilters(filters)
end
function P:SavePrefs()
 local prefs=UI:GetGroup().prefs.find or {};UI:GetGroup().prefs.find=prefs
 if UI.preview then prefs.railCollapsed=state.railCollapsed==true end
 if not A:GetSetting("rememberFilters") then return end
 self:RememberCategory()
 prefs.category=state.category;prefs.categoryPrefs=state.categoryPrefs;prefs.social=state.social
 prefs.filters=prefs.filters or {};wipe(prefs.filters);for k,v in pairs(state.filters) do if k~="text" and k~="leaderText" and k~="searchMode" then prefs.filters[k]=v end end
 local choice=state.confirmedChoice or {}
 prefs.filters.groupKey,prefs.filters.groupKeys,prefs.filters.difficultyID,prefs.filters.tier=choice.groupKey,CopyGroupKeys(choice.groupKeys),choice.difficultyID,choice.tier
 prefs.filters.selected=choice.selected==true
end
function P:ClearFilters()
 self.resultsHeader:SetSort(nil,false,true)
 state.filters.hideZeroScore,state.filters.hideSameSpec,state.filters.hideSameClass=nil,nil,nil
 self.loading=true;self.fMinMembers.box:SetText("");self.fMembers.box:SetText("");self.roleChoice:SetValue(false,L.anyRole);state.filters.tankPresence,state.filters.healerPresence,state.filters.damagePresence=nil,nil,nil;state.filters.roleMatchAny=nil;for _,key in ipairs(numericFilterKeys) do state.filters[key]=nil end;self:SyncFilterFields();state.social=nil;self.socialChoice:SetValue(false,Say("全部关系","All relations"));state.filters.sort=A:GetSetting("defaultSort");self.sortChoice:SetValue(state.filters.sort,L[state.filters.sort] or L.newest);self.loading=nil;self:UpdateFilters()
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
 local top=124+(self.appsHeight or 0)+(self.quickFilterHeight or 0)
 local quota=state.applicationLimit
 local available=quota and UI:GetGroup().Applications:GetActiveCount()<5
 local message=quota and (available and Say("已有空余名额，可以继续申请。","A slot is available. You can continue your application.") or Say("最多同时申请 5 支队伍，请先取消一项申请。","You can apply to five groups at once. Cancel an application to continue.")) or self.statusMessage or ""
 self.limitNotice.fill:SetColor(available and T.findAvailableNoticeColor or T.notice)
 self.limitNotice:SetMessage(message)
 if self.noticeTop~=top then
  M:FinishPlacement(self.limitNotice);self.limitNotice:ClearAllPoints();self.limitNotice:SetPoint("TOPLEFT",self.main,"TOPLEFT",0,-top);self.noticeTop=top
 end
 if message~="" then top=top+self.limitNotice:GetHeight()+12 end
 if self.resultsTop==top then return end
 self.resultsTop=top
 self.context:ClearAllPoints();self.context:SetPoint("TOPLEFT",0,-top)
 self.resultCount:ClearAllPoints();C.SetPoint(self.resultCount,"LEFT",self.context,"RIGHT","findResultCountLeftX",0)
 local headerOffset=self.context:GetHeight()+8
 local rowsOffset=headerOffset+self.resultsHeader:GetHeight()
 self.resultsHeader:ClearAllPoints();self.resultsHeader:SetPoint("TOPLEFT",0,-top-headerOffset)
 local resultsHeight=math.max(self.results.rowHeight,HEIGHT-top-rowsOffset)
 self.results:ClearAllPoints();self.results:SetPoint("TOPLEFT",0,-top-rowsOffset);self.results:SetViewport(resultsHeight)
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
 local prefs=self.applicationHeader.state
 if prefs.sortKey then
  local function Value(id)
   local app=state.apps[id]
   if prefs.sortKey=="members" then return app.result and app.result.numMembers end
   return app.expiresAt
  end
  table.sort(state.appIDs,function(a,b)
   local av,bv=Value(a),Value(b)
   if av~=bv then
    if av==nil then return false elseif bv==nil then return true end
    if prefs.descending then return av>bv else return av<bv end
   end
   return a<b
  end)
 end
 self.appList:SetItems(state.appIDs,UpdateApplication)
 local count=#state.appIDs;local h=math.min(3,count)*self.appList.rowHeight
 local globalCount=UI:GetGroup().Applications:GetActiveCount()
 self.applicationHeader:SetShown(count>0)
 self.appList:SetShown(count>0);self.appList:SetViewport(math.max(1,h));UI:SetText(self.appsCount,("%d / 5"):format(globalCount))
 UI:Color(self.appsCount,globalCount>=5 and T.warning or T.text)
 self.hasOtherApplications=globalCount>categoryCount;self.noApplications=globalCount==0
 UI:SetText(self.appsEmpty,Say("本分类暂无申请","No applications in this category"));C.SetLineHeight(self.appsEmpty,"line20",true)
 self.appsHeight=h+(count>0 and self.applicationHeader:GetHeight()+4 or 0);self:LayoutQuickFilters();self:LayoutResults()
 self.autoJoin:SetValue(UI:GetGroupSetting("autoJoin"))
 local ticking=HasApplicationCountdown()
 if ticking and not self.countdown then
  self.countdown=C_Timer.NewTicker(1,RefreshApplicationClock)
 elseif not ticking then StopCountdown() end
end
function P:ShowApplicationLimit()
 state.applicationLimit=true;state.showGlobal=true
 self:ClosePicker();UI:CloseMenu();UI.Tooltip:Hide();self:RefreshApplications()
 M:Reveal(self.limitNotice,"TOPLEFT",self.main,"TOPLEFT",0,-140-(self.appsHeight or 0)-(self.quickFilterHeight or 0),0,7,.20)
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
 if self.raidResultColumns~=raid then
  self.raidResultColumns=raid
  self:LayoutResultColumns()
 end
 self:RefreshApplications();local ids=self:SortResultIDs(state.browseReady and UI:GetGroup():GetResults() or {});self.results:SetItems(ids,RenderResult);UI:SetText(self.resultCount,Say("%d 支队伍","%d groups"):format(#ids))
 self.filteredResultCount=#ids;self:UpdateFilterResultSummary()
 self:RefreshDeclineState(ids)
 self:RefreshSearchState()
 if refreshTooltip or tooltipResultID and UI.Tooltip:IsResult(tooltipResultID) then UI.Tooltip:RefreshRelations() end
end
function P:RefreshSearchState()
 if not self.frame or not self.frame:IsShown() or UI.hiding then return end
 local raid=Category().id==3
 local status=UI:GetGroup():GetSearchState();local empty=not self.results.ids or #self.results.ids==0;self.emptyPanel:SetShown(empty)
 self.resultsHeader:SetShown(not empty);UI:SetText(self.resultHeadings.rating,raid and Say("进度","Progress") or Say("评分","Score"))
 if empty then
  local busy=state.browseReady and (status=="searching" or status=="waiting")
  local cat=Category();local instances=cat.id==2 or cat.id==3
  local prompt=instances and Say("请选择副本","Choose an instance") or Say("请选择活动","Choose an activity")
  local help=cat.id==9 and Say("从左侧分类中选择要浏览的活动。","Choose an activity from the category list.")
   or Say("选择具体"..(instances and "副本" or "活动").."，或“"..AllActivitiesLabel(cat).."”。","Select an "..(instances and "instance" or "activity").." or choose “"..AllActivitiesLabel(cat).."”.")
  local title=not state.browseReady and prompt or status=="waiting" and L.searchWaitingTitle or status=="searching" and L.searching or status=="failed" and L.searchFailedTitle or status=="idle" and L.findEmptyTitle or UI:GetGroup():GetResultCount()>0 and L.noFilteredResults or L.noResults
  local description=not state.browseReady and help or status=="waiting" and UI:GetGroup():GetSearchError() or status=="searching" and L.searchPendingHelp or status=="failed" and UI:GetGroup():GetSearchError() or status=="idle" and "" or L.noResultsHelp
  UI:SetText(self.emptyText,title);UI:SetText(self.emptyHelp,description);self.emptyHelp:SetShown(description~="")
  self.start:ClearAllPoints();C.SetPoint(self.start,"TOP",description~="" and self.emptyHelp or self.emptyText,"BOTTOM",0,"findStartTopY")
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
 self:LayoutQuickFilters()
end
function P:LayoutListRows()
 local first=self.results.rows[1]
 local metaTop=math.max(T.findResultMetaTop,T.findResultTitleTop+first.title:GetHeight()+T.findResultTextGap)
 local declineTop=metaTop+first.meta:GetHeight()+T.findResultTextGap
 local height=math.max(T.findResultRowHeight,math.ceil(self.hasDeclinedResults and declineTop+first.declined:GetHeight()+T.findResultBottomInset or metaTop+first.meta:GetHeight()+T.findResultBottomInset))
 for _,row in ipairs(self.results.rows) do
  row.meta:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-metaTop)
  LayoutResultActivity(row)
  row.declined:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-declineTop)
  row.description:SetHeight(math.max(T.findDescriptionMinHeight,row.meta:GetHeight()*2))
  LayoutMembers(row)
 end
 SetRowHeight(self.results,height)
 local appHeight=math.max(T.findApplicationRowHeight,math.ceil(self.appList.rows[1].count:GetHeight()*2))
 for _,row in ipairs(self.appList.rows) do
  row.cancel:SetHeight(math.max(28,row.cancel.label:GetHeight()+2))
  LayoutMembers(row)
 end
 SetRowHeight(self.appList,appHeight)
 if self.appsHeight then self:RefreshApplications() end
end
function P:LayoutFont()
 if not self.frame then return end
 self.resultsHeader:SetHeight(math.max(24,self.resultHeadings.title:GetHeight()))
 self.applicationHeader:SetHeight(math.max(24,self.applicationHeader.labels.title:GetHeight()))
 self.resultsTop=nil;self:LayoutQuickFilters()
 self:LayoutResultColumns();self.applicationHeader:Layout(APP_BODY)
 self.autoJoin:SetWidth(54+FitText(self.autoJoin.label))
 self.scopeToggle:SetWidth(FitText(self.scopeToggle.label)+24)
 self:UpdateApplicationSettings()
 self:LayoutListRows()
 self:LayoutFilters()
 if self.picker then self:RefreshPicker() end
end
-- Reflow existing controls only; keep query, selection, input leases and result identity.
function P:LayoutAppearance(width,height)
 self:LayoutSize(width,height)
 self:LayoutSidebar(state.railCollapsed and T.findCollapsedSidebarWidth or T.findSidebarWidth)
 self:LayoutFont()
 self:RefreshMemberStyle()
 self.appList:Refresh(true)
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
 local wanted=not UI.preview and A:GetSetting("notesEnabled")==true and A.Notes~=nil
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
  local stored=UI:GetGroup().prefs.find or {};state.railCollapsed=UI.preview and stored.railCollapsed==true or not UI.preview and A.Appearance:GetRailCollapsed()
  local prefs=A:GetSetting("rememberFilters") and stored or {};local filters=prefs.filters or {}
  state.category=prefs.category or "seasonDungeon";state.categoryPrefs=prefs.categoryPrefs or {};state.filters.sort=filters.sort or A:GetSetting("defaultSort");state.social=prefs.social
  if UI.preview then self.previewSearchBox:SetText(filters.text or "") end
  local saved=state.categoryPrefs[state.category] or filters
  state.groupKey=saved.groupKey;state.difficultyID=saved.difficultyID;state.tier=saved.tier
  self:RestoreCategory(state.categoryPrefs[state.category] or {groupKey=filters.groupKey,groupKeys=filters.groupKeys,difficultyID=filters.difficultyID,tier=filters.tier,selected=filters.selected,minMembers=filters.minMembers,maxMembers=filters.maxMembers,neededRole=filters.neededRole,tankPresence=filters.tankPresence,healerPresence=filters.healerPresence,damagePresence=filters.damagePresence,hideZeroScore=filters.hideZeroScore,hideSameSpec=filters.hideSameSpec,hideSameClass=filters.hideSameClass,roleMatchAny=filters.roleMatchAny,minRating=filters.minRating,maxRating=filters.maxRating,minItemLevel=filters.minItemLevel,maxItemLevel=filters.maxItemLevel,needsDamage=filters.needsDamage,sort=filters.sort,social=prefs.social})
  self.loading=nil
 end
 if not UI.preview then state.railCollapsed=A.Appearance:GetRailCollapsed() end
 self:SetSidebarCollapsed(state.railCollapsed,false,false)
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
 self.resultsHeader:StopDrag(false);self.applicationHeader:StopDrag(false)
 self:FinishSidebar()
 M:Stop(self);self.pendingTooltipResultID=nil
 UI.Native:ReleaseSearch();self.searchAvailable,self.searchError=nil,nil
 self:DismissApplicationNotice()
 if self.unsub then self.unsub();self.unsub=nil end;if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 self.results:Clear();self.appList:Clear();self.seasonCategories:Clear();self.categories:Clear();if self.picker then self.activities:Clear();self:ClosePicker() end;M:FinishPlacement(self.filterPanel);self.filterPanel:Hide()
 StopCountdown();StopDeclineClock();M:Waiting(self.busyIcon,false);M:Spin(self.refreshIcon,false);self.busyState=nil
 wipe(state.apps);wipe(state.appIDs);state.selected=nil
 if self.sortedResults then wipe(self.sortedResults);wipe(self.sortValues) end
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
