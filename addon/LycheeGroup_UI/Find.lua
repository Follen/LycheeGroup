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
local PICKER_GAP=24
local MAIN=T.contentWidth-LEFT-T.contentGap-48
local HEIGHT=T.contentHeight-48
local LIST_GUTTER=14
local BODY=MAIN-LIST_GUTTER
local APP_BODY=MAIN-32-LIST_GUTTER
local AGE_WIDTH=zh and 88 or 96
local APP_ROW_HEIGHT,RESULT_ROW_HEIGHT=40,84
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
local function LayoutMembers(row)
 row.membersButton:ClearAllPoints();row.membersButton:SetPoint("LEFT",row.membersX,row.membersExpanded and row.membersExpandedY or 0)
 row.roster:SetWidth(row.isParty and 110 or 132)
 row.count:SetShown(not row.isParty and row.membersExpanded==true)
end
local function BuildMembers(row,x,compact)
 row.membersX=x;row.membersExpandedY=compact and 9 or 11
 row.membersButton=C.Button(row,"",138,function()
  if row.isParty or not row.key or not row._hitVisible then return end
  row.membersExpanded=not row.membersExpanded;LayoutMembers(row)
 end)
 row.membersButton:SetStyle({height=compact and 18 or 24,radius=6})
 row.roster=C.Roster(row.membersButton,18,5);row.roster:SetSize(132,compact and 18 or 20);row.roster:SetPoint("CENTER");RosterColumns(row.roster)
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
 row.roster:Update(details and details.members,counts,record and record.maxNumPlayers,true)
 UI:SetText(row.count,record and not row.isParty and UI:MemberCountText(record) or "")
 LayoutMembers(row)
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
  local shade=missing and .7 or 1
  slot.role:SetDesaturated(missing);slot.role:SetVertexColor(shade,shade,shade)
 end
 local marksWidth=UI.Members:BindGroupMarks(row.marks,r)
 local activityWidth=FitText(row.meta)
 row.meta:SetWidth(marksWidth>0 and math.min(activityWidth,RESULT_COLUMNS.title.width-marksWidth-6) or RESULT_COLUMNS.title.width)
 row.marks:ClearAllPoints();row.marks:SetPoint("LEFT",row.meta,"RIGHT",6,0)
 local leaderClass
 for _,member in ipairs(d.members) do if member.isLeader or r.leaderKey and member.nameKey==r.leaderKey then leaderClass=member.class;break end end
 row.leader:SetTextColor(UI:ClassColor(leaderClass))
 if A.GroupPresentation.Result(r).groupMetric=="progress" then
  local progress=UI:ProgressText(r,d)
  UI:SetText(row.score,progress);UI:Color(row.score,progress=="—" and T.dim or T.good)
 else UI:SetScore(row.score,r.leaderRating,r.ratingKind) end
 UI:SetText(row.ilvl,(r.requiredItemLevel or 0)>0 and math.floor(r.requiredItemLevel) or Say("不限","Any"))
 UI:SetText(row.age,UI:AgeText(r.age))
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
 row.cancel.isCancel=true
 UI:SetText(row.cancel.label,status=="invited" and L.accept or L.cancelApplication)
end
function P:Build(parent)
 local f=CreateFrame("Frame",nil,parent);f:SetAllPoints(parent);self.frame=f
 local rail=CreateFrame("Frame",nil,f);rail:SetSize(LEFT,T.contentHeight);rail:SetPoint("TOPLEFT");self.rail=rail
 local seasonStride=zh and 52 or 72
 local seasonHeight=seasonStride*2;local categoriesTop=seasonHeight+24
 self.seasonCategories=C.List(rail,LEFT,seasonHeight,seasonStride,function(key,button,row) P:SelectCategory(key,row) end);self.seasonCategories:SetPoint("TOPLEFT",0,-8)
 self.categories=C.List(rail,LEFT,T.contentHeight-categoriesTop-8,52,function(key,button,row) P:SelectCategory(key,row) end);self.categories:SetPoint("TOPLEFT",0,-categoriesTop)
 self.seasonIDs={};self.catIDs={};self.catMap={}
 for _,list in ipairs({self.seasonCategories,self.categories}) do list:SetGutter(0);list.alternateRows=false;list.selectionFill=true;list.idleTextColor=T.muted;for _,row in ipairs(list.rows) do
  row:SetHeight(list.rowHeight-4);row.selected:SetRadius(8);row.hover:SetRadius(8);row.alternate:SetRadius(8);row.title:ClearAllPoints();row.title:SetPoint("LEFT",52,0);row.title:SetWidth(116);C.SetFont(row.title,T.railFontSize+2);row.title:SetWordWrap(true);row.title:SetHeight(0);C.SetLineHeight(row.title,22);row.meta:Hide()
  row.symbol=C.Icon(row,T.railIconSize);row.symbol:SetPoint("LEFT",16,0);row.chevron=C.Glyph(row,"chevron",12);row.chevron:SetPoint("RIGHT",-16,0)
 end end
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
 self.searchClear=C.Button(self.search,"",28,function() P:ClearSearch() end);self.searchClear:SetSize(28,28);self.searchClear:SetPoint("RIGHT",self.searchModeToggle,"LEFT",-6,0);C.Glyph(self.searchClear,"close",14):SetPoint("CENTER");self.searchClear:Hide()
 self.search.box:ClearAllPoints();self.search.box:SetPoint("TOPLEFT",52,-4);self.search.box:SetPoint("BOTTOMRIGHT",self.searchModeToggle,"LEFT",-40,4)
 self.applicationPanel=CreateFrame("Frame",nil,main);self.applicationPanel:SetPoint("TOPLEFT",0,-68);self.applicationPanel:SetWidth(MAIN);self.applicationPanel.fill=C.Panel(self.applicationPanel,T.panel,20)
 self.appsTitle=C.Text(self.applicationPanel,L.applications,14,T.text);C.SetLineHeight(self.appsTitle,20,true);self.appsTitle:SetPoint("LEFT",self.applicationPanel,"TOPLEFT",16,-26)
 self.appsBadge=CreateFrame("Frame",nil,self.applicationPanel);self.appsBadge:SetSize(48,24);self.appsBadge:SetPoint("LEFT",self.appsTitle,"RIGHT",10,0);C.Panel(self.appsBadge,T.selected,12)
 self.appsCount=C.Text(self.appsBadge,"0",14,T.text);C.SetLineHeight(self.appsCount,20,true);self.appsCount:SetPoint("CENTER")
 self.appsEmpty=C.Text(self.applicationPanel,Say("本分类暂无申请","No applications in this category"),14,T.dim);self.appsEmpty:SetPoint("LEFT",self.appsBadge,"RIGHT",12,0)
 self.scopeToggle=C.Button(self.applicationPanel,Say("全部申请","All applications"),112,function()
  state.showGlobal=not state.showGlobal
  if not state.showGlobal then P:DismissApplicationNotice() end
  P:RefreshApplications()
 end,{height=32,radius=16});self.scopeToggle:SetPoint("LEFT",self.appsBadge,"RIGHT",10,0)
 self.autoJoin=C.Check(self.applicationPanel,Say("自动进组","Auto join"),function(value) UI:SetGroupSetting("autoJoin",value) end);C.SetFont(self.autoJoin.label,14);C.SetLineHeight(self.autoJoin.label,20,true);self.autoJoin:SetSize(54+FitText(self.autoJoin.label),26);self.autoJoin:SetPoint("RIGHT",self.applicationPanel,"TOPRIGHT",-16,-26);self.autoJoin.track:ClearAllPoints();self.autoJoin.track:SetPoint("RIGHT",0,0);self.autoJoin.label:ClearAllPoints();self.autoJoin.label:SetPoint("RIGHT",self.autoJoin.track,"LEFT",-10,0)
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
 self.appList=C.List(self.applicationPanel,MAIN-32,APP_ROW_HEIGHT*3,APP_ROW_HEIGHT,function(id,button,row) if button=="RightButton" then P:OpenResultMenu(row,id) end end);self.appList:SetGutter(LIST_GUTTER);self.appList:SetPoint("TOPLEFT",16,-44);self.appList.tooltipFraction=.25
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
  row.base=C.Panel(row,T.rowAlternate,12);row.base:Hide()
  row.title:ClearAllPoints();row.title:SetPoint("LEFT",APPLICATION_COLUMNS.title.x,0);row.title:SetWidth(APPLICATION_COLUMNS.title.width);C.SetFont(row.title,15);C.SetLineHeight(row.title,20,true);row.meta:Hide()
  row.icon=C.Icon(row,24);row.icon:SetPoint("LEFT",0,0)
  row.leaderIcon=C.Icon(row,12);row.leaderIcon:SetTexture(T.media.."leader.tga");row.leaderIcon:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x-17,0)
  row.leader=C.Text(row,"",14,T.muted,APPLICATION_COLUMNS.leader.width);row.leader:SetPoint("LEFT",APPLICATION_COLUMNS.leader.x,0);C.SetLineHeight(row.leader,20,true);row.leader:SetWordWrap(false)
  BuildMembers(row,APP_BODY-386,true)
  row.status=C.Text(row,"",14,T.dim,112);row.status:SetPoint("LEFT",APP_BODY-224,0);C.SetLineHeight(row.status,20,true);row.status:SetJustifyH("CENTER")
  row.cancel=C.Button(row,L.cancelApplication,92,function(b)
   local id=b.targetKey;local app=UI:GetGroup():GetApplication(id);if not app then return end
   if not UI:GetGroup().Applications:CanCancel(id) then return end
   local ok,err=UI:GetGroup():Cancel(id)
   if not ok then P:SetStatus(err or L.failed) end
  end);C.SetFont(row.cancel.label,14);C.SetLineHeight(row.cancel.label,20,true);row.cancel:SetStyle({height=28,radius=14});row.cancel:SetPoint("RIGHT",0,0)
  row.cancel:HookScript("OnEnter",function(button) if button:IsEnabled() and button.isCancel then UI:Color(button.label,T.accent) end end)
 end
 self.context=C.Text(main,"",20,T.text,MAIN-180)
 self.resultCount=C.Text(main,"",14,T.dim,132);C.SetLineHeight(self.context,28,true);C.SetLineHeight(self.resultCount,20,true);self.resultCount:SetJustifyH("LEFT")
 self.resultsHeader=CreateFrame("Frame",nil,main);self.resultsHeader:SetSize(BODY,24);self.resultHeadings={}
 for _,entry in ipairs({{"title",Say("队伍","Group")},{"leader",Say("队长","Leader")},{"members",Say("成员","Members")},{"ilvl",Say("装等","iLvl")},{"rating",Say("评分","Score")},{"description",Say("描述","Description")},{"age",Say("发布","Posted")}}) do
  local key,label=entry[1],entry[2];local column=RESULT_COLUMNS[key]
  local text=C.Text(self.resultsHeader,label,14,T.dim,column.width);C.SetLineHeight(text,20,true);text:SetPoint("TOPLEFT",key=="title" and 12 or column.x,0);text:SetWordWrap(false)
  text:SetJustifyH((key=="title" or key=="description" or key=="leader") and "LEFT" or key=="age" and "RIGHT" or "CENTER");self.resultHeadings[key]=text
 end
 self.results=C.List(main,MAIN,HEIGHT-180,RESULT_ROW_HEIGHT,function(id,button,row) P:OnResultSelect(id,button,row) end)
 self.results:SetGutter(LIST_GUTTER);self.results.tooltipFraction=.25
 for _,row in ipairs(self.results.rows) do
  ResultTooltipArea(row,self.results)
  row.base=C.Panel(row,T.rowAlternate,12);row.base:Hide()
  row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-14);row.title:SetWidth(RESULT_COLUMNS.title.width);C.SetFont(row.title,T.listTitleSize);C.SetLineHeight(row.title,T.listTitleLineHeight,true)
  row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",RESULT_COLUMNS.title.x,-46);row.meta:SetWidth(RESULT_COLUMNS.title.width);C.SetLineHeight(row.meta,20,true)
  row.marks=UI.Members:CreateMarks(row)
  row:HookScript("OnHide",function(self) UI.Members:ClearMarks(self.marks) end)
  row.description=C.Text(row,"",14,T.muted,RESULT_COLUMNS.description.width,20);row.description:SetPoint("LEFT",RESULT_COLUMNS.description.x,0);row.description:SetHeight(48);row.description:SetMaxLines(2);row.description:SetWordWrap(true);row.description:SetJustifyV("MIDDLE")
  row.leaderIcon=C.Icon(row,12);row.leaderIcon:SetTexture(T.media.."leader.tga");row.leaderIcon:SetPoint("LEFT",RESULT_COLUMNS.leader.x-17,0)
  row.leader=C.Text(row,"",14,T.muted,RESULT_COLUMNS.leader.width);row.leader:SetPoint("LEFT",RESULT_COLUMNS.leader.x,0);C.SetLineHeight(row.leader,20,true);row.leader:SetWordWrap(false)
  row.icon=C.Icon(row,36);row.icon:SetPoint("LEFT",12,0)
  row.score=C.Text(row,"",14,T.text,RESULT_COLUMNS.rating.width);C.SetLineHeight(row.score,20,true);row.score:SetPoint("LEFT",RESULT_COLUMNS.rating.x,0);row.score:SetJustifyH("CENTER");row.score:SetWordWrap(false)
  row.ilvl=C.Text(row,"",14,T.text,RESULT_COLUMNS.ilvl.width);C.SetLineHeight(row.ilvl,20,true);row.ilvl:SetPoint("LEFT",RESULT_COLUMNS.ilvl.x,0);row.ilvl:SetJustifyH("CENTER");row.ilvl:SetWordWrap(false)
  BuildMembers(row,RESULT_COLUMNS.members.x)
  row.age=C.Text(row,"",14,T.dim,RESULT_COLUMNS.age.width);row.age:SetPoint("LEFT",RESULT_COLUMNS.age.x,0);row.age:SetJustifyH("RIGHT");C.SetLineHeight(row.age,20,true);row.age:SetWordWrap(false)
  row:SetScript("OnDoubleClick",function(b,button) if button=="LeftButton" and b.key then P:Apply(b.key) end end)
 end
 self.emptyPanel=CreateFrame("Frame",nil,main);self.emptyPanel:SetSize(MAIN,280);self.emptyPanel:SetPoint("CENTER",0,-12)
 self.busyIcon=C.Icon(self.emptyPanel,44);self.busyIcon:SetTexture(T.media.."lychee-logo.tga");self.busyIcon:SetPoint("TOP",self.emptyPanel,"TOP",0,-26)
 self.emptyText=C.Text(self.emptyPanel,L.findEmptyTitle,18,T.text,600);self.emptyText:SetPoint("TOP",0,-90);self.emptyText:SetJustifyH("CENTER")
 self.emptyHelp=C.Text(self.emptyPanel,"",14,T.muted,600);self.emptyHelp:SetPoint("TOP",0,-124);self.emptyHelp:SetJustifyH("CENTER")
 self.start=C.Button(self.emptyPanel,L.searchNow,140,function() if state.browseReady then P:DoSearch() else P:SelectCategory(state.category) end end);self.start:SetPrimary(true);self.start:SetPoint("TOP",self.emptyHelp,"BOTTOM",0,-24)
 main:SetScript("OnKeyDown",function(_,key)
  if UI.hiding then return end
  if key=="F10" and IsShiftKeyDown() and state.selected then P:OpenResultMenu(P.results,state.selected,false);return end
  if key~="ENTER" or not state.selected then return end
  for _,input in ipairs(UI.inputs or {}) do if input:HasFocus() then return end end
  P:Apply(state.selected)
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
 self:BuildFilters()
 for _,label in ipairs({self.membersLabel,self.maxMembersLabel,self.roleLabel,self.socialLabel,self.sortLabel}) do C.SetLineHeight(label,20,true) end
end
function P:BuildFilters()
 local f=CreateFrame("Frame",nil,UI.frame);f:SetSize(300,376);f:SetPoint("TOPLEFT",UI.frame,"TOPRIGHT",12,0);f:SetFrameLevel(UI.frame:GetFrameLevel()+5);C.Panel(f,T.panel,28);self.filterPanel=f
 self.filterTitle=C.Text(f,Say("筛选队伍","Filter groups"),20);C.SetLineHeight(self.filterTitle,24,true);self.filterTitle:SetPoint("TOPLEFT",20,-20)
 local close=C.IconButton(f,"close",36,function() P:SetFiltersOpen(false) end,{iconSize=20});close:SetPoint("TOPRIGHT",-14,-14)
 self.filterStatus=C.Text(f,"",14,T.dim,180);C.SetLineHeight(self.filterStatus,20,true);self.filterStatus:SetPoint("TOPLEFT",20,-56)
 self.clearFilters=C.Button(f,Say("重置","Reset"),72,function() P:ClearFilters() end,{variant="text",height=32});self.clearFilters:SetPoint("TOPRIGHT",-14,-52)
 local function Changed() if not P.loading then P:UpdateFilters() end end
 self.membersLabel=C.Text(f,Say("最少人数","Min. players"),14,T.muted,122)
 self.maxMembersLabel=C.Text(f,Say("最多人数","Max. players"),14,T.muted,122)
 self.fMinMembers=C.Number(f,122,40,Changed);self.fMembers=C.Number(f,122,40,Changed)
 self.roleLabel=C.Text(f,Say("队伍缺少职责","Role needed"),14,T.muted,260)
 self.roleChoice=C.Choice(f,260,{{value=false,label=L.anyRole},{value="TANK",label=L.tank},{value="HEALER",label=L.healer},{value="DAMAGER",label=L.damage}},function(value) state.filters.neededRole=value or nil;P:UpdateFilters() end)
 self.rolePresencePanel=CreateFrame("Frame",nil,f);self.rolePresencePanel:SetSize(260,116)
 self.rolePresenceChoices={}
 local presenceOptions={{"TANK",L.tank,"tankPresence"},{"HEALER",L.healer,"healerPresence"},{"DAMAGER",Say("输出","DPS"),"damagePresence"}}
 for i,option in ipairs(presenceOptions) do
  local role,key=option[1],option[3]
  local icon=C.Icon(self.rolePresencePanel,18);icon:SetPoint("TOPLEFT",0,-9-(i-1)*40);UI:SetRoleIcon(icon,role)
  local label=C.Text(self.rolePresencePanel,option[2],14,T.muted,60,20);C.SetLineHeight(label,20,true);label:SetPoint("TOPLEFT",24,-6-(i-1)*40)
  local options={{value="present",label=role=="DAMAGER" and Say("已齐","Full") or Say("已有","Has")},{value="missing",label=Say("缺少","Lacks")}}
  local choice=C.Segmented(self.rolePresencePanel,174,options,function(value)
   state.filters[key]=state.filters[key]~=value and value or nil;P:UpdateFilters()
  end)
  choice:SetPoint("TOPLEFT",86,-(i-1)*40);self.rolePresenceChoices[role]=choice
  for _,button in ipairs(choice.buttons) do button:SetSurfaceColors(T.surface,T.surfaceLow,T.surfaceLowPressed) end
 end
 self.hideZeroScore=C.Check(f,Say("过滤队长 0 分队伍","Hide 0-score leaders"),function(value) state.filters.hideZeroScore=value or nil;P:UpdateFilters() end)
 self.hideZeroScore:SetSize(260,26);self.hideZeroScore:SetPoint("TOPLEFT",20,-348)
 C.SetFont(self.hideZeroScore.label,14);C.SetLineHeight(self.hideZeroScore.label,20,true)
 self.hideZeroScore.label:ClearAllPoints();self.hideZeroScore.label:SetPoint("LEFT");self.hideZeroScore.label:SetWidth(206)
 self.hideZeroScore.track:ClearAllPoints();self.hideZeroScore.track:SetPoint("RIGHT")
 self.socialLabel=C.Text(f,Say("关系与笔记","Relations and notes"),14,T.muted)
 self.socialChoice=C.Choice(f,260,{{value=false,label=Say("全部关系","All relations")},{value="friend",label=Say("好友在队","Friends in group")},{value="guild",label=Say("同公会成员","Guildmates")},{value="any",label=Say("含笔记记录","With player notes")},{value="positive",label=Say("含推荐玩家","Recommended players")},{value="noCaution",label=Say("不含拉黑记录","Without blocked players")}},function(value) state.social=value or nil;P:UpdateFilters() end);self.socialChoice:SetHeight(40)
 self.sortLabel=C.Text(f,L.sort,14,T.muted)
 self.sortChoice=C.Choice(f,260,{{value="newest",label=L.newest},{value="rating",label=Say("队长评分","Leader rating")},{value="itemLevel",label=Say("要求装等","Required item level")},{value="members",label=L.members}},function(value) state.filters.sort=value;P:UpdateFilters() end);self.sortChoice:SetHeight(40)
 f:Hide()
end
function P:UpdateFilterSummary()
 local filters=state.filters
 local count=(filters.minMembers or filters.maxMembers) and 1 or 0
 for _,key in ipairs({"neededRole","tankPresence","healerPresence","damagePresence","hideZeroScore"}) do if filters[key] then count=count+1 end end
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
 if not self.filtersOpen then M:FinishPlacement(self.filterPanel) end
 self.filterPanel:SetShown(self.filtersOpen);self:ClosePicker();UI.Tooltip:Hide()
 UI:FitToScreen()
 self.filterToggle:SetActive(self.filtersOpen);self.filterChevron:SetRotation(self.filtersOpen and math.pi or 0);self.filterChevron:SetVertexColor(unpack(self.filtersOpen and T.accent or T.muted))
 if self.filtersOpen and not wasOpen then M:Reveal(self.filterPanel,"TOPLEFT",UI.frame,"TOPRIGHT",12,0,-4,0,.16) end
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
  state.tier=value or nil;state.groupKey,state.groupKeys=nil,nil;P.draftGroupKeys,P.multiSelectMode=nil,nil;state.difficultyID=nil
  P:RefreshPicker();P.results:SetPixelOffset(0,false);P:UpdateFilters(true)
 end);self.tierChoice:SetHeight(44);self.tierChoice:SetPoint("TOPLEFT",8,-64)
 self.tierChoice:SetSurfaceVariant("dark")
 self.difficultySurface=CreateFrame("Frame",nil,f);self.difficultySurface:SetSize(280,36);C.Panel(self.difficultySurface,T.surfaceLow,8)
 self.difficultyButtons={}
 for i=1,12 do self.difficultyButtons[i]=C.Button(self.difficultySurface,"",60,function(button) state.difficultyID=button.value or nil;P:RefreshPicker();P.results:SetPixelOffset(0,false);if state.browseReady then P:CommitChoice();P:DoSearch(true) else P:UpdateFilters(true) end end,{variant="compact"}) end
 self.activities=C.List(f,280,440,48,function(key)
  if P.multiSelectMode and P.keystoneGroups[key] then P:ToggleGroupChoice(key);return end
  state.groupKeys=nil;P.draftGroupKeys,P.multiSelectMode=nil,nil
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
 self.multiSelectToggle=C.Button(f,Say("多选","Multi-select"),zh and 52 or 96,function() P:SetMultiSelectMode(not P.multiSelectMode) end,{variant="text",height=32})
 self.multiSelectToggle.label:ClearAllPoints();self.multiSelectToggle.label:SetPoint("RIGHT",-6,0)
 self.multiSelectToggle:Hide()
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
 self.pickerY=math.max(10,math.min(top,T.contentHeight-self.picker:GetHeight()-10))
 self.picker:ClearAllPoints();self.picker:SetPoint("TOPLEFT",self.rail,"TOPRIGHT",PICKER_GAP,-self.pickerY)
end
function P:ClosePicker()
 self.draftGroupKeys,self.multiSelectMode=nil,nil
 if self.picker then M:FinishPlacement(self.picker);self.picker:UnregisterEvent("GLOBAL_MOUSE_DOWN");self.pickerConfirm:Hide();self.picker:Hide() end
 if not state.browseReady and state.confirmedChoice then
  local choice=state.confirmedChoice
  state.groupKey,state.groupKeys,state.difficultyID,state.tier=choice.groupKey,CopyGroupKeys(choice.groupKeys),choice.difficultyID,choice.tier
  self.restoringChoice=true;self:RefreshPicker()
  if self.unsub then self:UpdateFilters() end
 end
end
function P:SetMultiSelectMode(enabled)
 self.multiSelectMode=enabled or nil
 self.draftGroupKeys=enabled and (CopyGroupKeys(state.groupKeys) or {}) or nil
 if enabled and state.groupKey and self.keystoneGroups[state.groupKey] then self.draftGroupKeys[state.groupKey]=true end
 self:RefreshPicker()
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
 if not multiGroups then self.draftGroupKeys,self.multiSelectMode=nil,nil end
 if self.restoringChoice then
  local choice=state.confirmedChoice
  state.browseReady=state.groupKey~=nil or state.groupKeys~=nil or choice.selected==true and not (choice.groupKey or choice.groupKeys)
  state.confirmedChoice=ChoiceSnapshot(state);self.restoringChoice=nil
 end
 if not self.picker then return end
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
 self.activities:SetWidth(menuWidth-16);self.activities:SetGutter(C.listRightInset)
 local extra=chooseDifficulty and (self.difficultySurface:GetWidth()-6-math.max(0,#diffs-1)*4-total)/#diffs or 0
 local x=3
 for i,button in ipairs(self.difficultyButtons) do
  local d=diffs[i];button:SetShown(chooseDifficulty and d~=nil)
  if d then button:ClearAllPoints();button:SetPoint("LEFT",x,0);button:SetWidth(button.optionWidth+extra);button.value=d.id;button:SetActive(state.difficultyID==d.id or not state.difficultyID and not d.id);x=x+button:GetWidth()+4 end
 end
 if chooseDifficulty then top=top+48 end;wipe(self.activityIDs);wipe(self.activityMap)
 if cat.id~=9 then self.activityIDs[#self.activityIDs+1]=0 end
 for _,group in ipairs(UI:GetGroup().Catalog:GetGroups(state.category)) do if not state.tier or group.tier==state.tier then self.activityMap[group.key]=group;self.activityIDs[#self.activityIDs+1]=group.key end end
 local confirm=self.multiSelectMode and next(self.draftGroupKeys)~=nil
 self.activities:ClearAllPoints();self.activities:SetPoint("TOPLEFT",8,-top);local listHeight=math.min(440,math.max(1,#self.activityIDs*48-4));self.activities:SetViewport(listHeight);self.picker:SetHeight(top+listHeight+(confirm and 64 or 8))
 self.pickerConfirm:SetShown(confirm);self.pickerConfirm:SetWidth(menuWidth-16);self.pickerConfirm:ClearAllPoints();self.pickerConfirm:SetPoint("TOPLEFT",8,-top-listHeight-8)
 if state.groupKeys then self.activities.selectedKey=nil else self.activities.selectedKey=state.groupKey or 0 end
 self.activities:SetItems(self.activityIDs,function(row,key)
  local group=self.activityMap[key];UI:SetText(row.title,group and group.name or AllActivitiesLabel(cat));row.icon:Show();if group then UI:SetActivityIcon(row.icon,group.activity) else row.icon:SetTexture(T.media..cat.icon..".tga");row.icon:SetTexCoord(0,1,0,1) end
  local selectable=self.multiSelectMode and multiGroups and multiGroups[key]
  row.multiSelect:SetShown(selectable or false)
  local checked=self.draftGroupKeys or state.groupKeys
  row.multiSelect:SetValue(checked and checked[key] or false)
  row.title:SetWidth(menuWidth-16-C.listRightInset-60-(key==0 and multiGroups and self.multiSelectToggle:GetWidth()+4 or selectable and 32 or 0))
  local toggle=self.multiSelectToggle
  if key==0 then
   toggle:SetParent(row);toggle:ClearAllPoints();toggle:SetPoint("RIGHT",-6,0);toggle:SetShown(multiGroups~=nil)
   UI:SetText(toggle.label,self.multiSelectMode and Say("返回","Back") or Say("多选","Multi-select"));toggle:SetActive(self.multiSelectMode==true)
  elseif toggle:GetParent()==row then toggle:Hide() end
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
  local cat=self.catMap[key];UI:SetText(row.title,cat.name);if row.kind~=cat.icon then row.kind=cat.icon;row.symbol:SetTexture(T.media..cat.icon..".tga") end
 end
 self.seasonCategories.selectedKey=state.category;self.categories.selectedKey=state.category
 self.seasonCategories:SetItems(self.seasonIDs,RenderCategory);self.categories:SetItems(self.catIDs,RenderCategory)
end
function P:SelectCategory(key,row)
 local changed=state.category~=key
 if changed then
  self:RememberCategory()
  self.draftGroupKeys,self.multiSelectMode=nil,nil
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
  self.draftGroupKeys=CopyGroupKeys(state.groupKeys)
  self.multiSelectMode=self.draftGroupKeys and true or nil
 end
 self:RefreshPicker();self:UpdateFilters(true)
 if changed or not self.picker:IsShown() then self.picker:Show();self.picker:RegisterEvent("GLOBAL_MOUSE_DOWN");M:Reveal(self.picker,"TOPLEFT",self.rail,"TOPRIGHT",PICKER_GAP,-self.pickerY,0,4,.14) else self:ClosePicker() end
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
 prefs.social=state.social;prefs.sort=state.filters.sort
end
function P:RestoreCategory(prefs)
 self.loading=true
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
  if prefs.tankPresence=="present" and prefs.healerPresence=="present" and prefs.damagePresence=="present" then prefs.damagePresence=nil end
 end
 prefs.needsDamage=nil
 state.filters.tankPresence=seasonDungeon and prefs.tankPresence or nil
 state.filters.healerPresence=seasonDungeon and prefs.healerPresence or nil
 state.filters.damagePresence=seasonDungeon and prefs.damagePresence or nil
 state.filters.hideZeroScore=seasonDungeon and prefs.hideZeroScore or nil
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
 if not seasonDungeon then filters.tankPresence,filters.healerPresence,filters.damagePresence,filters.hideZeroScore=nil,nil,nil,nil end
 self.hideZeroScore:SetShown(seasonDungeon);self.hideZeroScore:SetValue(filters.hideZeroScore)
 filters.friends=state.social=="friend";filters.guild=state.social=="guild";filters.notes=(state.social=="any" or state.social=="positive" or state.social=="noCaution") and state.social or nil
 self.roleChoice:SetShown(keys and not seasonDungeon);self.roleLabel:SetShown(keys or seasonDungeon);self.rolePresencePanel:SetShown(seasonDungeon)
 UI:SetText(self.roleLabel,seasonDungeon and Say("队伍职责","Group roles") or Say("队伍缺少职责","Role needed"))
 self.rolePresenceChoices.TANK:SetValue(filters.tankPresence)
 self.rolePresenceChoices.HEALER:SetValue(filters.healerPresence)
 self.rolePresenceChoices.DAMAGER:SetValue(filters.damagePresence)
 local presentCount=(filters.tankPresence=="present" and 1 or 0)+(filters.healerPresence=="present" and 1 or 0)+(filters.damagePresence=="present" and 1 or 0)
 self.rolePresenceChoices.TANK.buttons[1]:SetAvailable(filters.tankPresence=="present" or presentCount<2)
 self.rolePresenceChoices.HEALER.buttons[1]:SetAvailable(filters.healerPresence=="present" or presentCount<2)
 self.rolePresenceChoices.DAMAGER.buttons[1]:SetAvailable(filters.damagePresence=="present" or presentCount<2)
 local layout=seasonDungeon and "presence" or keys and "needed" or "basic"
 if self.filterLayout~=layout then
  self.filterLayout=layout
  local memberY=-100
  self.membersLabel:ClearAllPoints();self.membersLabel:SetPoint("TOPLEFT",20,memberY)
  self.maxMembersLabel:ClearAllPoints();self.maxMembersLabel:SetPoint("TOPLEFT",158,memberY)
  self.fMinMembers:ClearAllPoints();self.fMinMembers:SetPoint("TOPLEFT",20,memberY-28)
  self.fMembers:ClearAllPoints();self.fMembers:SetPoint("TOPLEFT",158,memberY-28)
  self.roleLabel:ClearAllPoints();self.roleLabel:SetPoint("TOPLEFT",20,-188)
  self.roleChoice:ClearAllPoints();self.roleChoice:SetPoint("TOPLEFT",20,-216);self.roleChoice:SetHeight(40)
  self.rolePresencePanel:ClearAllPoints();self.rolePresencePanel:SetPoint("TOPLEFT",20,-216)
  local socialY=seasonDungeon and -402 or keys and -284 or -196
  self.socialLabel:ClearAllPoints();self.socialLabel:SetPoint("TOPLEFT",20,socialY)
  self.socialChoice:ClearAllPoints();self.socialChoice:SetPoint("TOPLEFT",20,socialY-32)
  self.sortLabel:ClearAllPoints();self.sortLabel:SetPoint("TOPLEFT",20,socialY-88)
  self.sortChoice:ClearAllPoints();self.sortChoice:SetPoint("TOPLEFT",20,socialY-120)
  self.filterPanel:SetHeight(-socialY+180)
 end
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
 UI:SetText(self.context,name);self.context:SetWidth(math.min(MAIN-180,FitText(self.context)))
 self:SavePrefs()
 -- The provider notifies results after all filter controls and context are ready.
 UI:GetGroup():SetFilters(filters)
end
function P:SavePrefs()
 if not A:GetSetting("rememberFilters") then return end
 self:RememberCategory()
 local prefs=UI:GetGroup().prefs.find or {};UI:GetGroup().prefs.find=prefs
 prefs.category=state.category;prefs.categoryPrefs=state.categoryPrefs;prefs.social=state.social
 prefs.filters=prefs.filters or {};wipe(prefs.filters);for k,v in pairs(state.filters) do if k~="text" and k~="leaderText" and k~="searchMode" then prefs.filters[k]=v end end
 local choice=state.confirmedChoice or {}
 prefs.filters.groupKey,prefs.filters.groupKeys,prefs.filters.difficultyID,prefs.filters.tier=choice.groupKey,CopyGroupKeys(choice.groupKeys),choice.difficultyID,choice.tier
 prefs.filters.selected=choice.selected==true
end
function P:ClearFilters()
 state.filters.hideZeroScore=nil
 self.loading=true;self.fMinMembers.box:SetText("");self.fMembers.box:SetText("");self.roleChoice:SetValue(false,L.anyRole);state.filters.tankPresence,state.filters.healerPresence,state.filters.damagePresence=nil,nil,nil;state.social=nil;self.socialChoice:SetValue(false,Say("全部关系","All relations"));state.filters.sort=A:GetSetting("defaultSort");self.sortChoice:SetValue(state.filters.sort,L[state.filters.sort] or L.newest);self.loading=nil;self:UpdateFilters()
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
 local activityID
 if state.groupKey then
  local matched=0
  for _,activity in ipairs(UI:GetGroup().Catalog:GetActivities(state.category)) do
   if UI:GetGroup().Catalog:GetGroupKey(state.category,activity)==state.groupKey and (not state.difficultyID or activity.difficultyID==state.difficultyID) then
    matched=matched+1;activityID=activity.id
   end
  end
  -- Only a unique native activity narrows the request. Multiple valid variants
  -- retain the complete category request and the existing local selection.
  if matched~=1 then activityID=nil end
 end
 local mode=UI.preview and "preview" or state.searchMode
 local text=mode=="leader" and self.search.box:GetText() or nil
 local ok,err=UI:GetGroup().Search:Search(state.category,activityID,mode,text)
 if not ok then self:SetStatus(err or L.failed) end
 self:ReadSearchState()
end
function P:SetStatus(message)
 self.statusMessage=message or ""
 self:LayoutResults()
end
function P:LayoutResults()
 if not self.results then return end
 local top=140+(self.appsHeight or 0)
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
 self.resultsHeader:ClearAllPoints();self.resultsHeader:SetPoint("TOPLEFT",0,-top-40)
 local resultsHeight=math.max(RESULT_ROW_HEIGHT,HEIGHT-top-80)
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
 local count=#state.appIDs;local h=math.min(3,count)*APP_ROW_HEIGHT
 local globalCount=UI:GetGroup().Applications:GetActiveCount()
 self.appList:SetShown(count>0);self.appList:SetViewport(math.max(1,h));UI:SetText(self.appsCount,("%d / 5"):format(globalCount))
 UI:Color(self.appsCount,globalCount>=5 and T.warning or T.text)
 UI:SetText(self.appsEmpty,Say("本分类暂无申请","No applications in this category"));C.SetLineHeight(self.appsEmpty,20,true);self.appsEmpty:SetShown(categoryCount==0 and globalCount==0);self.scopeToggle:SetShown(globalCount>categoryCount)
 UI:SetText(self.scopeToggle.label,state.showGlobal and Say("仅看本分类","This category") or Say("查看全部申请","All applications"))
 self.scopeToggle:SetWidth(FitText(self.scopeToggle.label)+24)
 self.appsHeight=h;self.applicationPanel:SetHeight(52+h);self:LayoutResults()
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
function P:RefreshResults()
 M:Stop(self)
 if not self.frame or not self.frame:IsShown() or UI.hiding then return end
 local raid=Category().id==3
 if self.raidResultColumns~=raid then
  self.raidResultColumns=raid
  local descriptionX=raid and RESULT_COLUMNS.rating.x or RESULT_COLUMNS.description.x
  local ratingX=raid and RESULT_COLUMNS.description.x+RESULT_COLUMNS.description.width-RESULT_COLUMNS.rating.width or RESULT_COLUMNS.rating.x
  local function PlaceColumns(rating,description,point)
   rating:ClearAllPoints();rating:SetPoint(point,ratingX,0)
   description:ClearAllPoints();description:SetPoint(point,descriptionX,0)
  end
  PlaceColumns(self.resultHeadings.rating,self.resultHeadings.description,"TOPLEFT")
  for _,row in ipairs(self.results.rows) do PlaceColumns(row.score,row.description,"LEFT") end
 end
 self:RefreshApplications();local ids=state.browseReady and UI:GetGroup():GetResults() or {};self.results:SetItems(ids,RenderResult);UI:SetText(self.resultCount,Say("%d 支队伍","%d groups"):format(#ids))
 self:RefreshSearchState()
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
function P:LayoutFont()
 if not self.frame then return end
 self.autoJoin:SetWidth(54+FitText(self.autoJoin.label))
 self.scopeToggle:SetWidth(FitText(self.scopeToggle.label)+24)
 self:UpdateApplicationSettings()
end
function P:OnResultSelect(id,button,row)
 state.selected=id;self:ClosePicker()
 if button=="RightButton" then self:OpenResultMenu(row or self.results,id) end
end
function P:OpenResultMenu(anchor,id,cursor)
 local r=Record(id);if not r then return end
 local applications=UI:GetGroup().Applications;local active=applications:IsActive(id);local application=UI:GetGroup():GetApplication(id);local invited=application and application.status=="invited"
 UI:OpenMenu(anchor,{{value="apply",label=invited and Say("已收到邀请","Invited") or active and L.cancelApplication or L.editAndApply,disabled=active and not applications:CanCancel(id)},{value="whisper",label=Say("与队长密聊","Whisper leader"),disabled=not r.leaderName or not UI:CanWhisperFaction(r.leaderFactionGroup)},{value="copy",label=Say("复制完整队长名称","Copy leader name"),disabled=UI.preview~=nil or not r.leaderName},{value="blockTitle",label=Say("屏蔽相同标题队伍","Block groups with this title"),disabled=r.name==nil},{value="block",label=Say("拉黑队长","Block leader"),disabled=UI.preview~=nil or not r.leaderKey}},function(action)
  local target=Record(id);if not target then return end
  if action=="apply" then if applications:CanCancel(id) then local ok,err=UI:GetGroup():Cancel(id);if not ok then P:SetStatus(err or L.failed) end elseif not applications:IsActive(id) then P:Apply(id,true) end
  elseif action=="whisper" and target.leaderName and UI:CanWhisperFaction(target.leaderFactionGroup) then ChatFrame_SendTell(target.leaderName)
  elseif action=="copy" then UI:CopyText(L.leader,target.leaderName,nil,nil,Say("完整名称","Full name"))
  elseif action=="blockTitle" then UI:GetGroup().Results:BlockTitle(target.name)
  elseif action=="block" and not UI.preview then local _,n,r=A:PlayerKey(target.leaderKey);A:Open("notes",{add={name=n,realm=r,type="caution"}}) end
 end,{cursor=cursor~=false})
end
function P:OnNotesChanged()
 if self.frame and self.frame:IsShown() then UI:GetGroup().Results:InvalidateView();self:RefreshResults();UI.Tooltip:RefreshRelations() end
end
function P:WatchNotes()
 if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 if A.db.notesEnabled and A.Notes then self.notesUnsub=A.Notes:Subscribe(function() P:OnNotesChanged() end) end
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
  local prefs=A:GetSetting("rememberFilters") and UI:GetGroup().prefs.find or {};local filters=prefs.filters or {}
  state.category=prefs.category or "seasonDungeon";state.categoryPrefs=prefs.categoryPrefs or {};state.filters.sort=filters.sort or A:GetSetting("defaultSort");state.social=prefs.social
  if UI.preview then self.previewSearchBox:SetText(filters.text or "") end
  local saved=state.categoryPrefs[state.category] or filters
  state.groupKey=saved.groupKey;state.difficultyID=saved.difficultyID;state.tier=saved.tier
  self:RestoreCategory(state.categoryPrefs[state.category] or {groupKey=filters.groupKey,groupKeys=filters.groupKeys,difficultyID=filters.difficultyID,tier=filters.tier,selected=filters.selected,minMembers=filters.minMembers,maxMembers=filters.maxMembers,neededRole=filters.neededRole,tankPresence=filters.tankPresence,healerPresence=filters.healerPresence,damagePresence=filters.damagePresence,hideZeroScore=filters.hideZeroScore,needsDamage=filters.needsDamage,sort=filters.sort,social=prefs.social})
  self.loading=nil
 end
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
  elseif kind=="result" then M:Start(P,RefreshPendingResults)
  elseif kind=="relations" then P:RefreshResults();UI.Tooltip:RefreshRelations()
  elseif kind=="search" then P:RefreshSearchState()
  elseif kind=="results" or kind=="applications" then P:RefreshResults() end
 end) end
 self:WatchNotes();self:RefreshCategories();self:RefreshPicker();self:UpdateFilters();self:SetFiltersOpen(self.filtersOpen)
 self:OnSearchTextChanged(self.search.box)
 if context and context.applicationID then self.appList:Select(context.applicationID,true) end
 if context and context.applicationLimit then self:ShowApplicationLimit() end
 local searchState=UI:GetGroup():GetSearchState()
  if context and context.leaderKey or UI:GetGroup().Search.abandoned or searchState=="idle" or searchState~="searching" and UI:GetGroup().Search.categoryKey~=state.category then self:DoSearch() end
end
function P:Leave()
 M:Stop(self)
 UI.Native:ReleaseSearch();self.searchAvailable,self.searchError=nil,nil
 self:DismissApplicationNotice()
 if self.unsub then self.unsub();self.unsub=nil end;if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 self.results:Clear();self.appList:Clear();self.seasonCategories:Clear();self.categories:Clear();if self.picker then self.activities:Clear();self:ClosePicker() end;M:FinishPlacement(self.filterPanel);self.filterPanel:Hide()
 StopCountdown();M:Waiting(self.busyIcon,false);M:Spin(self.refreshIcon,false);self.busyState=nil
 wipe(state.apps);wipe(state.appIDs);state.selected=nil
 state.showGlobal=nil
 UI:GetGroup():Detach(self);UI:FitToScreen()
end

-- Preview owns a separate page state; real preferences are restored on exit.
function P:BeginPreview(provider)
 self.liveState={state=state,loaded=self.loaded,restored=self.restoredInitial}
 state={category=provider.category,searchMode="group",apps={},appIDs={},categoryPrefs={},filters={sort="newest"},browseReady=true}
 self.loaded,self.restoredInitial=nil,nil
end
function P:EndPreview()
 local saved=self.liveState;if not saved then return end
 state=saved.state;self.loaded,self.restoredInitial=saved.loaded,saved.restored
 self.liveState=nil
 -- Rebind the visible controls from the restored real preferences on next entry.
 self.loaded=nil;self.restoredInitial=nil
end
