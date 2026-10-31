-- One Settings navigation serves account and character preferences and addon information.
local A=_G.LycheeGroup
local UI=A.UI
local C,T,L=UI.C,UI.Theme,UI.L
local P={section="general"};UI.pages.settings=P
local zh=A:GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
local sections={
 {"general",S("常规与入口","General")},
 {"browse",S("寻队偏好","Group search")},
 {"memberIcons",S("成员与标记","Members")},
 {"notifications",S("提示与声音","Alerts & sound")},
 {"notes",S("笔记与历史","Notes & history")},
 {"blocks",S("屏蔽名单","Blocked leaders")},
 {"interface",S("外观与缩放","Appearance"),gapBefore=12},
 {"floating",S("悬浮窗","Floating window")},
 {"about",L.about,gapBefore=12},
 {"credits",S("鸣谢","Credits"),true},
}
local types={{value="positive",label=S("推荐","Positive")},{value="neutral",label=S("中性","Neutral")},{value="caution",label=S("拉黑","Blocked")}}
local applicantSounds={
 {value="voice",label=S("荔枝内置语音","Lychee built-in voice")},
 {value="native",label=S("原生提示音","Native alert")},
 {value="off",label=S("关闭","Off")},
}
local soundChannels={
 {value="Master",label=S("主音量","Master")},
 {value="SFX",label=S("音效","Sound effects")},
 {value="Music",label=S("音乐","Music")},
 {value="Ambience",label=S("环境","Ambience")},
 {value="Dialog",label=S("对话","Dialog")},
}
local channelCVars={Master="Sound_MasterVolume",SFX="Sound_SFXVolume",Music="Sound_MusicVolume",Ambience="Sound_AmbienceVolume",Dialog="Sound_DialogVolume"}
function P:ChannelVolumeCVar() return channelCVars[A:GetSetting("soundChannel")] end
function P:GetChannelVolume()
 return math.floor(tonumber(C_CVar.GetCVar(self:ChannelVolumeCVar()))*100+.5)
end
function P:SyncChannelVolume()
 local control=self.controls.channelVolume.widget
 local value=self:GetChannelVolume();control:SetValue(value);UI:SetText(control.valueLabel,value.."%")
end
local function ThemeChoices()
 local catalog=A.API.Theme:List({includeBuiltins=true});local choices={}
 table.sort(catalog,function(a,b)
  if a.builtin~=b.builtin then return a.builtin end
  return a.id==b.id and a.storage<b.storage or a.id<b.id
 end)
 for _,theme in ipairs(catalog) do
  if theme.effective then choices[#choices+1]={value=theme.id,label=theme.name} end
 end
 return choices
end
local definitions={
 general={{"language",S("界面语言","Interface language"),S("仅改变插件文字，重载界面后生效。","Change addon text. Reload the UI to apply."),{{value="auto",label=S("跟随游戏","Game language")},{value="zhCN",label="简体中文"},{value="enUS",label="English"}}},
 {"toggleBinding",A.L.bindingToggle,"","binding"},
 {"minimap",S("显示小地图按钮","Show minimap button"),S("左键开关主窗，右键打开设置。","Left-click opens the main window; right-click opens settings.")},
 {"nativeLFGEntry",S("隐藏原生组队眼睛","Hide the native LFG eye"),S("仅隐藏预组队入口，保留副本与 PvP 排队入口。","Hide the premade-group entry; keep dungeon and PvP queue access.")}},
 interface={{"theme",S("界面主题","Theme"),S("切换主窗口与悬浮窗外观，重载后生效。","Change the main and floating window appearance. Reload to apply."),ThemeChoices},
 {"font",S("界面字体","Interface font"),S("选择主窗口与悬浮窗使用的字体。","Choose the main and floating window font."),function() return A.Fonts:Choices() end},
 {"fontScale",S("字体大小","Font size"),S("调节插件全局文字大小。","Adjust text size throughout the addon."),"range",70,130},
 {"uiScale",S("主窗口缩放","Main window scale"),S("等比调整整个主窗口。","Scale the entire main window proportionally."),"range",75,125},
 {"reduceMotion",L.reduceMotion,S("关闭开窗位移、Logo 动作和局部过渡。","Disable window movement, logo animation and local transitions.")}},
 browse={
 {"defaultSort",S("默认排序","Default sorting"),S("各分类未单独设置排序时使用。","Used when a category has no saved sorting preference."),{{value="newest",label=L.newest},{value="rating",label=L.leaderRating},{value="itemLevel",label=L.requiredItemLevel},{value="members",label=L.members}}},
 {"rememberFilters",S("记住本角色的筛选","Remember character filters"),S("本角色独立保存各分类筛选。","Save category filters for this character.")},
 {"showImportantFilters",S("常用筛选快捷按钮","Filter shortcuts"),S("开启后在“我的申请”内显示；关闭时在筛选弹窗内调整。","Show them in My applications, or keep them in the filter panel when off.")},
 {"raidMembers",S("团本成员名单","Raid member list"),S("设置寻队团本详情中的名单展开方式。","Choose how group-search raid details expand the roster."),{{value="shift",label=S("按 Shift 切换","Shift to toggle")},{value="alt",label=S("按 Alt 切换","Alt to toggle")},{value="ctrl",label=S("按 Ctrl 切换","Ctrl to toggle")},{value="always",label=S("始终展开","Always expand")}}}},
 memberIcons={
 {"memberIconShape",S("成员头像形状","Member icon shape"),S("用于寻队结果的五人队伍。","For five-player groups in search results."),{{value="circle",label=S("圆形","Circle")},{value="square",label=S("圆角方形","Rounded square")}}},
 {"memberIconScale",S("成员头像大小","Member icon size"),S("调整寻队头像，成员列自动适配。","Resize search-result icons; the column adapts."),"range",75,175},
 {"memberClassBorder",S("职业色边框","Class-color borders"),S("在寻队已有成员图标周围显示职业色。","Show class colors around occupied member icons.")},
 {"memberLeaderMark",S("队长皇冠","Leader crown"),S("在实际队长的成员头像上方显示皇冠。","Show a crown above the actual leader's icon.")},
 {"relations",S("好友与公会标记","Friend and guild markers"),S("在队伍、申请者和成员提示中显示关系。","Show relationships in group and player details.")},
 {"noteMarks",S("荔枝笔记标记","Player note markers"),S("在队长、申请者和队友旁显示记录类型。","Show note types beside leaders, applicants and teammates.")}},
 notifications={
 {"reminders",S("玩家记录提醒","Player note reminders"),S("邀请或组队时，在聊天框提示已有玩家记录。","Show saved player notes in chat when inviting or grouping."),{{value="all",label=S("全部记录","All notes")},{value="positive",label=S("仅推荐","Recommended only")},{value="caution",label=S("仅拉黑","Blocked only")},{value="off",label=S("不提醒","Off")}}},
 {"applicantAlertSound",S("新申请提示音","New applicant sound"),S("选择音色，点击菜单中的播放图标试听。","Choose a sound; use its play icon to preview."),applicantSounds},
 {"soundChannel",S("音频频道","Audio channel"),S("提示音与试听使用所选游戏频道。","Alerts and previews use this game audio channel."),soundChannels},
 {"channelVolume",S("频道音量","Channel volume"),S("直接调整游戏频道音量，也影响同频道的其他声音。","Changes the game channel volume, including other sounds on it."),"range",0,100}},

 notes={{"defaultNote",S("新记录的默认类型","Default note type"),S("每次记笔记时仍可选择其他类型。","Choose a different type whenever you record a player."),types},
 {"history",S("记录大秘境历史队友","Record Mythic+ teammates"),S("保存完成的副本及队友，供笔记页回顾。","Save completed runs and teammates in Player Notes.")}},
 floating={{"floating",S("显示悬浮窗","Show floating window"),S("查看申请与招募状态，关闭主窗口后仍然显示。","View active applications and recruitment while the main window is closed.")},
 {"floatingCompatibility",S("悬浮窗兼容","Floating window integration"),S("接入第三方 UI 入口，开启时由对方控制大小。","Use a third-party UI entry and its sizing when enabled.")},
 {"floatingScale",S("悬浮窗缩放","Floating window scale"),S("调整悬浮窗大小。","Adjust the floating window size."),"range"},
 {"floatingLocked",S("锁定位置","Lock position"),S("锁定后不能拖动，查看状态和点击入口不受影响。","Lock movement while keeping the status and shortcuts active.")}}}
local BODY_WIDTH = T.contentWidth - T.settingsMainX - T.settingsContentInset*2 - 12
function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 root:SetScript("OnEvent",function(_,event,name)
  if event=="CVAR_UPDATE" then
   if name:lower()==P:ChannelVolumeCVar():lower() then P:SyncChannelVolume() end
  elseif event=="UPDATE_BINDINGS" then P:Sync()
  elseif event=="PLAYER_REGEN_DISABLED" then
   P:CancelBindingCapture(true);P:ShowBindingNotice(A.L.bindingCombat);P:Sync()
  end
 end)
 root:HookScript("OnHide",function() root:UnregisterEvent("CVAR_UPDATE");P:CancelBindingCapture(true);P:CloseLinkCopy(true);P:StopThemeSubscription();P:StopSoundPreview() end)
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(T.settingsSidebarWidth,T.contentHeight);rail:SetPoint("TOPLEFT");self.rail=rail
 self.nav={};for i,entry in ipairs(sections) do
  local b=C.Navigation(rail,entry[2],T.settingsSidebarWidth,function() P:SelectSection(entry[1]) end,nil,{radius=8,fontSize=14});b:SetPoint("TOPLEFT",0,-12-(i-1)*52);b.label:SetWidth(T.settingsBLabelWidth)
  b.label:SetWordWrap(true);C.SetLineHeight(b.label,T.navigationLineHeight)
  UI:Element(b,"settings.navigation","settings",b,"settings.navigation",entry[1]);self.nav[entry[1]]=b
 end
 local main=CreateFrame("Frame",nil,root);main:SetSize(T.contentWidth-T.settingsMainX,T.contentHeight);main:SetPoint("TOPLEFT",T.settingsMainX,0);C.Panel(main,"surfaceLow","settingsPanelRadius");self.main=main
 self.heading=C.Text(main,"",24);self.heading:SetPoint("TOPLEFT",T.settingsContentInset,-T.settingsContentInset);C.SetLineHeight(self.heading,32,true)
 self.panels={};self.controls={}
 for _,entry in ipairs(sections) do
  local panel=CreateFrame("Frame",nil,main);panel:SetSize(BODY_WIDTH,T.contentHeight-120);C.SetPoint(panel,"TOPLEFT",panel:GetParent(),"TOPLEFT",T.settingsContentInset,"settingsPanelTopleftY");self.panels[entry[1]]=panel;UI:Element(panel,"settings.panel","settings",panel,"settings.panel",entry[1]);C.Container(panel,"settings-content")
  for i,row in ipairs(definitions[entry[1]] or {}) do self:BuildRow(panel,row,i) end
 end
 local reset={"resetPosition",S("悬浮窗位置","Floating window position"),S("未锁定时拖动荔枝标志，可放在屏幕内任意位置。","Drag the lychee logo to position the window when unlocked."),"action"}
 self:BuildRow(self.panels.floating,reset,#definitions.floating+1)
 self.reloadLanguage=C.Button(self.panels.general,S("重载界面","Reload UI"),T.settingsReloadLanguageWidth,function() C_UI.Reload() end);self.reloadLanguage:SetWidth(T.settingsReloadLanguageWidth)
 self:BuildAbout(self.panels.about)
self:RegisterBuildElements()
 end
function P:BuildBlocks()
 local panel=self.panels.blocks
 local toolbar=CreateFrame("Frame",nil,panel);self.blocksToolbar=toolbar
 self.blocksCount=C.Text(toolbar,"",14,"muted");C.SetLineHeight(self.blocksCount,20,true)
 self.blocksCount:SetWordWrap(false)
 self.blocksClear=C.Button(toolbar,S("全部清空","Clear all"),nil,function() if P.blockGroup then P.blockGroup.Results:ClearBlockedTitles() end end,{variant="text"})
 local spacer=CreateFrame("Frame",nil,toolbar);spacer:SetSize(0,1)
 self.blocksToolbarItems={{frame=self.blocksCount,manageWidth=false,manageHeight=false},{frame=spacer,width="fill",manageHeight=false},{frame=self.blocksClear,manageWidth=false,manageHeight=false}}
 local _,toolbarLayout=C.Box(toolbar,{layout="row",items=self.blocksToolbarItems,align="center",gap=0,track=true});self.blocksToolbarLayout=toolbarLayout
 -- SetRowInitializer grows the visible pool after the actual records arrive.
 local list=C.List(panel,BODY_WIDTH+12,0,52)
 list:SetStyle({selectionFill=false,selectionMark=false,hoverFill=false,radius=0});self.blocksList=list
 list:SetRowInitializer(function(row)
  row.title:ClearAllPoints();C.SetPoint(row.title,"LEFT",row.title:GetParent(),"LEFT","settingsRowTitleLeftX",0);row.title:SetWordWrap(false);C.SetFont(row.title,16);C.SetLineHeight(row.title,22,true)
  row.meta:ClearAllPoints();row.meta:Show();row.meta:SetWordWrap(false);C.SetFont(row.meta,14);C.SetLineHeight(row.meta,20,true);UI:Color(row.meta,"muted")
  row:SetScript("OnClick",nil)
  row.remove=C.Button(row,S("移除","Remove"),nil,function(button)
   if P.blockGroup and row.key==button.targetKey and row._hitVisible and list.clip:IsMouseOver() then P.blockGroup.Results:RemoveBlockedLeader(button.targetKey) end
  end,{variant="text"});C.SetPoint(row.remove,"RIGHT",row.remove:GetParent(),"RIGHT","settingsRowRemoveRightX",0)
  row.blockItems={{frame=row.title,gapAfter=24,manageHeight=false},{frame=row.meta,manageHeight=false},{frame=row.remove,manageHeight=false}}
  row.blockLayout=C.Row(row,row.blockItems,{mode="flex",width="fill",height="fill",padding={12,0,12,0},align="center",track=true})
 end)
 self.blocksHeader=C.TableHeader(panel,{
  {key="name",label=S("名字","Name"),width="settingsColumnNameWidth340",min="settingsColumnNameMin140"},
  {key="realm",label=S("服务器","Realm"),width="settingsColumnRealmWidth280",min="settingsColumnRealmMin120"},
  {key="actions",label=S("操作","Actions"),width="settingsColumnActionsWidth148",min="settingsColumnActionsMin132",align="CENTER"},
 },{onLayout=function(header) P:LayoutBlockColumns(header) end})
 self.blocksEmpty=C.Text(panel,"",18,"dim",BODY_WIDTH);C.SetLineHeight(self.blocksEmpty,24);self.blocksEmpty:SetJustifyH("CENTER");self.blocksEmpty:SetWordWrap(true)
self:RegisterBuildElements()
 end
function P:LayoutBlockColumns(header)
 if not self.blocksList then return end
 local name,realm,actions=header.columns.name,header.columns.realm,header.columns.actions
 -- Quantize cumulative column edges once, then share their differences with
 -- the native header and every physical row in the bounded list pool.
 local unit
 if GetPhysicalScreenSize then local _,height=GetPhysicalScreenSize();if height and height>0 then unit=768/height/header:GetEffectiveScale() end end
 local function snap(value) return unit and math.floor(value/unit+.5)*unit or value end
 local first,last,total=snap(name.width),snap(name.width+realm.width),snap(name.width+realm.width+actions.width)
 name.x,name.width=0,first;realm.x,realm.width=first,last-first;actions.x,actions.width=last,total-last
 header:SetWidth(total)
 for index,definition in ipairs(header.definitions) do
  local cell=header.columns[definition.key];local button,handle=header.buttons[index],header.handles[index]
  button:ClearAllPoints();button:SetPoint("TOPLEFT",cell.x,0);button:SetWidth(cell.width)
  handle:ClearAllPoints();handle:SetPoint("TOPLEFT",cell.x+cell.width-T.tableHandleWidth/2,0)
 end
 local geometry=self.blockColumnGeometry or {};self.blockColumnGeometry=geometry
 geometry.width,geometry.nameWidth,geometry.realmWidth,geometry.actionsWidth=total,math.max(1,name.width-24),math.max(1,realm.width-24),actions.width
 for _,key in ipairs({"name","realm"}) do
  local label=header.labels[key]
  local cell=header.columns[key];local left,right=snap(cell.x+12),snap(cell.x+cell.width-12)
  label:ClearAllPoints();label:SetPoint("LEFT",left-cell.x,0);label:SetWidth(math.max(1,right-left))
 end
 local actionLabel=header.labels.actions
 local actionRight=snap(total-12)
 actionLabel:ClearAllPoints();actionLabel:SetPoint("RIGHT",actionRight-total-T.settingsActionTextPadding/2,0);actionLabel:SetJustifyH("RIGHT");actionLabel:SetWidth(math.max(1,actions.width-24-T.settingsActionTextPadding/2))
 for _,row in ipairs(self.blocksList.rows) do
  local items=row.blockItems;local removeWidth=row.blockRemoveWidth or row.remove:GetWidth();local gap=geometry.actionsWidth-removeWidth
  if items[1].width~=geometry.nameWidth or items[2].width~=geometry.realmWidth or items[2].gapAfter~=gap or items[3].width~=removeWidth then
   items[1].width,items[2].width,items[2].gapAfter,items[3].width=geometry.nameWidth,geometry.realmWidth,gap,removeWidth
   row.blockLayout:Invalidate("columns")
  end
  if row.blockLayout.dirty then row.blockLayout:Layout() end
 end
end
function P:LayoutBlocks()
 if not self.blocksList then return end
 local top=0
 local list=self.blocksList
 local toolbarHeight=math.max(32,math.ceil(self.blocksClear.label:GetStringHeight())+12)
 self.blocksClear:SetHeight(toolbarHeight)
 self.blocksClear:SetWidth(math.ceil(C.MeasureTextWidth(self.blocksClear.label))+T.settingsActionTextPadding)
 -- The toolbar belongs to the block panel while sharing the page title line.
 self.blocksCount:SetWidth(math.ceil(C.MeasureTextWidth(self.blocksCount))+2)
 self.blocksToolbar:SetSize(math.max(1,BODY_WIDTH-self.heading:GetWidth()-24-list.gutter),math.max(toolbarHeight,self.blocksCount:GetHeight()))
 self.blocksToolbar:ClearAllPoints();self.blocksToolbar:SetPoint("LEFT",self.heading,"RIGHT",12,0)
 if self.blocksToolbarLayout.dirty then self.blocksToolbarLayout:Layout() end
 local headingHeight=24
 for _,label in pairs(self.blocksHeader.labels) do headingHeight=math.max(headingHeight,math.ceil(label:GetHeight())) end
 self.blocksHeader:SetHeight(headingHeight)
 self.blocksHeader:ClearAllPoints();C.SetPoint(self.blocksHeader,"TOPLEFT",self.blocksHeader:GetParent(),"TOPLEFT","settingsBlocksHeaderTopleftX",-top)
 top=top+self.blocksHeader:GetHeight()+8
 local first=list.rows[1]
 local rowHeight=math.max(52,math.ceil(math.max(first.title:GetHeight(),first.meta:GetHeight())+24))
 local viewport=math.max(rowHeight,self.panels.blocks:GetHeight()-top)
 list:ClearAllPoints();C.SetPoint(list,"TOPLEFT",list:GetParent(),"TOPLEFT","settingsListTopleftX",-top);list:SetRowHeight(rowHeight,rowHeight,viewport)
 for _,row in ipairs(list.rows) do
  row.remove:SetHeight(toolbarHeight)
  row.blockRemoveWidth=math.ceil(C.MeasureTextWidth(row.remove.label))+T.settingsActionTextPadding
  if not row.remove._lycheeLayoutFields or not row.remove._lycheeLayoutFields.width then row.remove:SetWidth(row.blockRemoveWidth) end
 end
 self.blocksHeader:Layout(list:GetWidth()-list.gutter)
 self.blocksEmpty:SetWidth(math.max(1,self.blocksHeader:GetWidth()-24));self.blocksEmpty:SetHeight(math.ceil(self.blocksEmpty:GetStringHeight()))
 self.blocksEmpty:ClearAllPoints();self.blocksEmpty:SetPoint("CENTER",list.clip,"CENTER",0,0)
end
function P:RefreshBlocks()
 local results=self.blockGroup and self.blockGroup.Results
 local leaders=results and results:GetBlockedLeaders() or {}
 UI:SetText(self.blocksCount,S("已屏蔽 %d 位队长","%d blocked leaders"):format(#leaders))
 self.blocksClear:SetAvailable(results~=nil and (#leaders>0 or results:GetBlockedTitleCount()>0))
 self.blocksList:SetShown(#leaders>0);self.blocksHeader:SetShown(#leaders>0);self.blocksEmpty:SetShown(#leaders==0)
 UI:SetText(self.blocksEmpty,self.blockError or S("暂无屏蔽的队长","No blocked leaders"))
 self.blocksList:SetItems(leaders,function(row,key)
  local _,name,realm=A:PlayerKey(key)
  UI:SetText(row.title,name);UI:SetText(row.meta,realm);row.remove.targetKey=key
 end)
 self:LayoutBlocks()
end
function P:StopBlocks()
 if self.blocksHeader then self.blocksHeader:StopDrag(false) end
 if self.blocksUnsub then self.blocksUnsub();self.blocksUnsub=nil end
 self.blockGroup,self.blockError=nil,nil
 if self.blocksList then self.blocksList:Clear();for _,row in ipairs(self.blocksList.rows) do row.remove.targetKey=nil end end
end
function P:EnterBlocks()
 if not self.blocksList then self:BuildBlocks() end
 self.blocksHeader:SetState(UI:GetTablePrefs("blockedLeaders"))
 if not self.blockGroup then
  local group,err
  if UI.preview then group=UI:GetGroup() else group,err=A:Ensure("Group") end
  self.blockGroup,self.blockError=group,err
  if group then self.blocksUnsub=group:Subscribe(function(kind)
   if kind=="results" and not UI.hiding and P.section=="blocks" and P.frame:IsVisible() then P:RefreshBlocks() end
  end) end
 end
end
function P:LayoutLinkCopy(row,baseHeight,left)
 local copy=row.linkCopy;if not copy then return baseHeight end
 local width=math.max(1,BODY_WIDTH-left-16)
 local fieldHeight=math.max(40,select(2,copy.field.box:GetFont())+20)
 copy.field:SetSize(width,fieldHeight)
 copy.hint:SetWidth(math.max(1,width-copy.close:GetWidth()-12));copy.hint:SetHeight(0)
 local hintHeight=math.max(copy.hint:GetLineHeight(),math.ceil(copy.hint:GetStringHeight()))
 local headerHeight=math.max(hintHeight,copy.close:GetHeight())
 copy.hint:SetHeight(hintHeight);copy.hint:ClearAllPoints();copy.hint:SetPoint("TOPLEFT",0,-(headerHeight-hintHeight)/2)
 copy.close:ClearAllPoints();copy.close:SetPoint("TOPRIGHT",0,-(headerHeight-copy.close:GetHeight())/2)
 copy.field:ClearAllPoints();copy.field:SetPoint("TOPLEFT",0,-headerHeight-8)
 local height=headerHeight+8+fieldHeight
 local progress=copy.progress or 0
 copy.canvas:SetSize(width,height);copy.clip:SetSize(width,math.max(1,height*progress))
 copy.clip:ClearAllPoints();copy.clip:SetPoint("TOPLEFT",left,-baseHeight+4)
 copy.clip:SetAlpha(progress);copy.clip:SetShown(progress>0)
 copy.field.box:EnableMouse(progress>=1);copy.close:SetEnabled(progress>=1)
 return baseHeight+(12+height)*progress
end
function P:LayoutLinkRows()
 if self.section=="about" then self:LayoutAbout()
 elseif self.section=="credits" then self:LayoutCredits() end
end
local function FinishLinkCopies(self)
 for _,copy in ipairs(self.linkCopies) do
  copy.progress=copy.target
  if copy.target==0 then copy.field.box:ClearFocus();copy.field.box:SetText("");copy.value=nil end
 end
 self:LayoutLinkRows()
end
function P:AnimateLinkCopies(immediate)
 local motion=self.linkMotion
 self.retargetingLinks=true;UI.Motion:Stop(motion);self.retargetingLinks=nil
 local moving=false
 for _,copy in ipairs(self.linkCopies) do copy.from=copy.progress or 0;if copy.from~=copy.target then moving=true end end
 if immediate or not moving or UI.context:IsReducedMotion() then FinishLinkCopies(self);return end
 local elapsed=0
 UI.Motion:Start(motion,function(dt)
  elapsed=math.min(.18,elapsed+dt)
  local p=elapsed/.18;p=p*(2-p)
  for _,copy in ipairs(P.linkCopies) do copy.progress=copy.from+(copy.target-copy.from)*p end
  P:LayoutLinkRows()
  return elapsed>=.18
 end,function() if not P.retargetingLinks then FinishLinkCopies(P) end end)
end
function P:CloseLinkCopy(immediate)
 if not self.linkCopies then return false end
 local active=self.activeLinkCopy
 self.activeLinkCopy=nil
 for _,copy in ipairs(self.linkCopies) do
  copy.target=0;copy.field.box:ClearFocus()
  if copy.button then copy.button:SetActive(false);copy.button=nil end
 end
 self:AnimateLinkCopies(immediate)
 return active~=nil
end
function P:ShowLinkCopy(row,button,value,label)
 if not row.linkCopy then
  local clip=CreateFrame("ScrollFrame",nil,row.frame or row);clip:Hide()
  local canvas=CreateFrame("Frame",nil,clip);clip:SetScrollChild(canvas)
  local copy={clip=clip,canvas=canvas,progress=0,target=0};row.linkCopy=copy
  copy.field=C.Edit(canvas,1,40,false,false,"modal");copy.field:SetPoint("TOPLEFT")
  copy.field.box:SetScript("OnTextChanged",function(box,user) if user then box:SetText(copy.value or "");box:SetCursorPosition(0);box:HighlightText() end end)
  copy.field.box:HookScript("OnEscapePressed",function() P:CloseLinkCopy() end)
  copy.hint=C.Text(canvas,"",13,"dim");C.SetLineHeight(copy.hint,20,true);copy.hint:SetWordWrap(true)
  copy.close=C.IconButton(canvas,"close",24,function() P:CloseLinkCopy() end,{iconSize=14})
  self.linkCopies=self.linkCopies or {};self.linkCopies[#self.linkCopies+1]=copy;self.linkMotion=self.linkMotion or {}
  UI:Element(clip,"settings.linkCopy","settings",copy,"settings.linkCopy",row.linkKey)
  for _,part in ipairs({"field","hint","close"}) do UI:Element(copy[part],"settings.linkCopy."..part,"settings",copy[part],"settings.linkCopy."..part,row.linkKey) end
 end
 local copy=row.linkCopy
 for _,other in ipairs(self.linkCopies) do
  other.target=other==copy and 1 or 0
  other.field.box:ClearFocus()
  if other.button then other.button:SetActive(false);other.button=nil end
 end
 self.activeLinkCopy=copy;copy.value=value;copy.button=button;button:SetActive(true)
 copy.field.box:SetText(value)
 UI:SetText(copy.hint,label..S(" · 按 Ctrl+C 复制链接。"," · Press Ctrl+C to copy."))
 UI.Tooltip:Hide();self:AnimateLinkCopies();self:LayoutLinkRows()
 copy.clip:Show();copy.field.box:SetFocus();copy.field.box:SetCursorPosition(0);copy.field.box:HighlightText()
end
function P:BuildAbout(parent)
 local header=CreateFrame("Frame",nil,parent);header:SetWidth(BODY_WIDTH);header:SetHeight(T.settingsHeaderHeight);header:SetPoint("TOPLEFT");UI.drag:AddHandle(header);self.aboutHeader=header
 local logo=C.Icon(header,T.settingsLogoWidth);header.icon=logo;C.Box(logo,{width="settingsLogoWidth",height="settingsLogoHeight"});UI:SetMediaTexture(logo,"lychee-logo.tga");C.SetPoint(logo,"TOPLEFT",logo:GetParent(),"TOPLEFT","settingsLogoTopleftX","settingsLogoTopleftY")
 self.aboutValues={}
 local name=C.Text(header,"",18,"text",BODY_WIDTH-84);C.SetLineHeight(name,24,true);name:SetWordWrap(false);C.SetPoint(name,"TOPLEFT",name:GetParent(),"TOPLEFT","settingsNameTopleftX","settingsNameTopleftY");self.aboutValues.name=name
 local versionLabel=C.Text(header,L.addonVersion,14,"muted");C.SetLineHeight(versionLabel,20,true);C.SetPoint(versionLabel,"TOPLEFT",versionLabel:GetParent(),"TOPLEFT","settingsVersionLabelTopleftX","settingsVersionLabelTopleftY")
 local version=C.Text(header,"",14,"text",T.settingsVersionWidth);version:SetWidth(T.settingsVersionWidth);C.SetLineHeight(version,20,true);version:SetWordWrap(false);C.SetPoint(version,"TOPLEFT",versionLabel,"TOPRIGHT","settingsVersionTopleftX",0);self.aboutValues.version=version
 local authorLabel=C.Text(header,L.addonAuthor,14,"muted");C.SetLineHeight(authorLabel,20,true);C.SetPoint(authorLabel,"TOPLEFT",version,"TOPRIGHT","settingsAuthorLabelTopleftX",0)
 local author=C.Text(header,"",14,"text");C.SetLineHeight(author,20,true);author:SetWordWrap(false);C.SetPoint(author,"TOPLEFT",authorLabel,"TOPRIGHT","settingsAuthorTopleftX",0);C.SetPoint(author,"TOPRIGHT",header,"TOPRIGHT","settingsAuthorToprightX","settingsAuthorToprightY");self.aboutValues.author=author;header.name,header.versionLabel,header.version,header.authorLabel,header.author=name,versionLabel,version,authorLabel,author
 local brand=CreateFrame("Button",nil,header);brand:SetHeight(T.settingsBrandHeight);brand:SetPoint("TOPLEFT");brand:RegisterForClicks("LeftButtonUp");self.aboutBrand=brand
 brand:SetScript("OnClick",function()
  P.aboutClicks=(P.aboutClicks or 0)+1
  if P.aboutClicks==10 then P.aboutClicks=0;P:ShowDedicationToast() end
 end)
 parent:HookScript("OnHide",function() P.aboutClicks=0;P:HideDedicationToast() end)
 self.otherAddonsHeading=C.Text(parent,L.otherAddons,14,"muted",BODY_WIDTH-24);C.SetLineHeight(self.otherAddonsHeading,20,true);C.SetPoint(self.otherAddonsHeading,"TOPLEFT",self.otherAddonsHeading:GetParent(),"TOPLEFT","settingsOtherAddonsHeadingTopleftX","settingsOtherAddonsHeadingTopleftY")
 local media="Interface\\AddOns\\LycheeGroup_UI\\Media\\"
 local entries={
  {name=L.lycheeLauncher,summary=L.lycheeLauncherHelp,icon=media.."about-launcher.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJKkdJtw8gt"},{L.neteaseDD,"https://url.cc.163.com/HoH0Od"}}},
  {name=L.lycheeTalent,summary=L.lycheeTalentHelp,icon=media.."about-talent.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJu72Mjcmed"},{L.neteaseDD,"https://url.cc.163.com/w64q1s"}}},
 }
 self.otherAddons={}
 for index,entry in ipairs(entries) do
  local holder=CreateFrame("Frame",nil,parent);holder:SetSize(BODY_WIDTH,T.settingsHolderHeight);UI.drag:AddHandle(holder)
  C.Panel(holder,"rowAlternate","settingsPanelRadius2"):SetShown(index%2==0)
  local icon=C.Icon(holder,T.settingsIconWidth);C.Box(icon,{width="settingsIconWidth",height="settingsIconHeight"});icon:SetTexture(entry.icon);C.SetPoint(icon,"TOPLEFT",icon:GetParent(),"TOPLEFT","settingsIconTopleftX","settingsIconTopleftY")
  local title=C.Text(holder,entry.name,18,"text",BODY_WIDTH-84);C.SetLineHeight(title,24,true);C.SetPoint(title,"TOPLEFT",title:GetParent(),"TOPLEFT","settingsTitleTopleftX","settingsTitleTopleftY")
  local summary=C.Text(holder,entry.summary,14,"muted",BODY_WIDTH-96);C.SetLineHeight(summary,20);summary:SetWordWrap(true);C.SetPoint(summary,"TOPLEFT",summary:GetParent(),"TOPLEFT","settingsSummaryTopleftX","settingsSummaryTopleftY")
  local row={frame=holder,icon=icon,title=title,summary=summary,links={},linkKey=index==1 and "about:launcher" or "about:talent"}
  for i,link in ipairs(entry.links) do
   local url,label=link[2],link[1]
   local button=C.Button(holder,label,nil,function(button) P:ShowLinkCopy(row,button,url,label) end);button:SetHeight(T.settingsButtonHeight);C.SetPoint(button,"BOTTOMLEFT",button:GetParent(),"BOTTOMLEFT",72+(i-1)*132,"settingsButtonBottomleftY");button:SetSurfaceColors("surfaceContainer","surfaceHighest")
   row.links[i]=button
  end
  UI:Element(holder,"settings.about.addon","settings",row,"settings.about.addon",index==1 and "launcher" or "talent")
  for i,button in ipairs(row.links) do UI:Element(button,"settings.about.link","settings",button,"settings.about.link",(index==1 and "launcher" or "talent")..":"..i) end
  self.otherAddons[index]=row
 end
end
function P:BuildCredits()
 local parent=self.panels.credits
 local media="Interface\\AddOns\\LycheeGroup_UI\\Media\\"
 self.credits={}
 for index,entry in ipairs({
  {"rurutia","@露露缇雅","credits-rurutia.tga","https://space.bilibili.com/455259","https://v.douyin.com/U6Jk7GPitmk/"},
  {"soul-revival","@灵魂复苏","credits-soul-revival.tga","https://space.bilibili.com/10420749?","https://v.douyin.com/UD4dIzYrhao/"},
 }) do
  local row=CreateFrame("Frame",nil,parent)
  local portrait=C.GameIcon(row,64);portrait:SetPoint("LEFT",16,0);portrait:SetTexture(media..entry[3])
  local name=C.Text(row,entry[2],20,"text");C.SetLineHeight(name,28,true);name:SetWordWrap(true)
  row.portrait,row.name,row.links,row.linkKey=portrait,name,{},"credits:"..entry[1];self.credits[index]=row
  for linkIndex,platform in ipairs({{"bilibili","Bilibili",entry[4]},{"douyin",S("抖音","Douyin"),entry[5]}}) do
   local url,label=platform[3],platform[2]
   local button=C.IconButton(row,nil,40,function(button) P:ShowLinkCopy(row,button,url,label) end,{iconSize=24,variant="creditsLink"})
   button.icon:SetTexture(media.."credits-"..platform[1]..".tga")
   row.links[linkIndex]=button
   UI:Element(button,"settings.credits.link","settings",button,"settings.credits.link",entry[1]..":"..platform[1])
  end
  UI:Element(row,"settings.credits.person","settings",row,"settings.credits.person",entry[1])
 end
end
function P:LayoutCredits()
 if not self.credits then return end
 local top=8
 for _,row in ipairs(self.credits) do
  row:SetWidth(BODY_WIDTH);row.name:SetWidth(math.max(1,BODY_WIDTH-120));row.name:SetHeight(0)
  local nameHeight=math.ceil(row.name:GetStringHeight());row.name:SetHeight(nameHeight)
  local contentHeight=math.max(64,nameHeight+8+40);row:SetHeight(self:LayoutLinkCopy(row,contentHeight+32,104))
  row.portrait:ClearAllPoints();row.portrait:SetPoint("TOPLEFT",16,-16-(contentHeight-64)/2)
  row.name:ClearAllPoints();row.name:SetPoint("TOPLEFT",104,-16-(contentHeight-nameHeight-8-40)/2)
  for index,button in ipairs(row.links) do button:ClearAllPoints();button:SetPoint("TOPLEFT",row.name,"BOTTOMLEFT",(index-1)*48,-8) end
  row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-top);top=top+row:GetHeight()+16
 end
end
function P:HideDedicationToast()
 if self.dedicationTimer then self.dedicationTimer:Cancel();self.dedicationTimer=nil end
 self.dedicationExpired=nil
 if self.dedicationToast then self.dedicationToast:Hide() end
end
function P:ShowDedicationToast()
 self:HideDedicationToast()
 if not self.dedicationToast then
  local toast=C.Notice(self.main,400);C.SetPoint(toast,"BOTTOM",toast:GetParent(),"BOTTOM",0,"settingsToastBottomY");toast:SetFrameLevel(self.main:GetFrameLevel()+10)
  toast.close:Hide();toast.text:SetJustifyH("CENTER");self.dedicationToast=toast
 end
 local toast,message=self.dedicationToast,"谨献给挚爱：荔枝小月亮"
 UI:SetText(toast.text,message);toast:SetWidth(math.ceil(toast.text:GetStringWidth())+48);toast:SetMessage(message,-28)
 self.dedicationTimer=C_Timer.NewTimer(5,function()
  P.dedicationTimer=nil
  if UI.hiding then P.dedicationExpired=true else P:HideDedicationToast() end
 end)
self:RegisterBuildElements()
 end
function P:RefreshAbout()
 for key,field in pairs({name="Title",version="Version",author="Author"}) do
  local text=C_AddOns.GetAddOnMetadata("LycheeGroup",field)
  UI:SetText(self.aboutValues[key],text and text~="" and text or key=="name" and L.reminder or L.metadataMissing)
 end
 self.aboutBrand:SetWidth(math.max(T.settingsBrandMinWidth,math.ceil(self.aboutValues.name:GetStringWidth())+84))
 self:LayoutAbout()
end
function P:LayoutAbout()
 local top=140
 for _,row in ipairs(self.otherAddons) do
  local height=math.max(T.settingsHolderHeight,row.summary:GetStringHeight()+104)
  row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-top);row.frame:SetHeight(self:LayoutLinkCopy(row,height,72));top=top+row.frame:GetHeight()+12
  local left=72
  for _,button in ipairs(row.links) do
   local width=math.max(T.settingsButtonMinWidth,math.ceil(button.label:GetStringWidth())+T.settingsActionTextPadding)
   button:SetWidth(width);button:ClearAllPoints();button:SetPoint("TOPLEFT",left,-height+button:GetHeight()+T.settingsButtonBottomleftY);left=left+width+12
  end
 end
end
-- The window-scale control uses a manual track: a native Slider can update its
-- value before Lua mouse handlers, while its own parent is the thing being scaled.
local function WindowScaleControl(parent)
 local control
 control=C.Slider(parent,156,75,125,5,function(value) A:SetSetting("uiScale",value) end,{
  commitOnRelease=true,
  onPreview=function(value) if control and control.valueLabel then UI:SetText(control.valueLabel,value.."%") end end,
 })
 control:SetValue(A:GetSetting("uiScale"))
 return control
end

function P:BuildRow(parent,row,index)
 local holder=CreateFrame("Frame",nil,parent);holder:SetSize(BODY_WIDTH,T.settingsHolderHeight2);holder:SetPoint("TOPLEFT",0,-(parent.nextRowY or 0));holder:EnableMouse(true)
 UI.drag:AddHandle(holder)
 local fill=C.Panel(holder,"rowAlternate","settingsFillRadius");holder.fill=fill;fill:SetShown(index%2==0)
 local controlWidth=UI.context:ResolveElementValue("settings.row","control","width",T.settingsControlWidth,row[1]);local content=BODY_WIDTH-24-controlWidth-48;local labelWidth=content*T.settingsLabelRatio;local helpWidth=content-labelWidth
 local label=C.Text(holder,row[2],14,"text",labelWidth);C.SetPoint(label,"LEFT",label:GetParent(),"LEFT","settingsLabelLeftX",0);label:SetWordWrap(true);C.SetLineHeight(label,20)
 label:SetWidth(C.ElementValue(holder,"label","width",labelWidth))
 local help=C.Text(holder,row[3],14,"muted",C.ElementValue(holder,"help","width",helpWidth));help:SetPoint("LEFT",36+labelWidth,0);help:SetWordWrap(true);C.SetLineHeight(help,20)
 local rowHeight=math.max(T.settingsHolderHeight2,label:GetStringHeight()+32,help:GetStringHeight()+32);holder:SetHeight(rowHeight);parent.nextRowY=(parent.nextRowY or 0)+rowHeight
 holder.label,holder.help=label,help
 local layoutRow={frame=holder,label=label,help=help,controlWidth=controlWidth}
 parent.rows=parent.rows or {};parent.rows[#parent.rows+1]=layoutRow
 local control
 if row[4]=="range" then
  if row[1]=="uiScale" then control=WindowScaleControl(holder)
  else control=C.Slider(holder,156,row[5] or 50,row[6] or 150,5,function(value)
   value=math.floor(value/5+.5)*5
   local widget=P.controls[row[1]].widget
   UI:SetText(widget.valueLabel,value.."%")
   if row[1]=="channelVolume" then
    if not UI.preview then C_CVar.SetCVar(P:ChannelVolumeCVar(),value/100) end
    P:SyncChannelVolume()
   else A:SetSetting(row[1],value) end
  end) end
  control.valueLabel=C.Text(control,"",14,"muted",nil);C.SetPoint(control.valueLabel,"LEFT",control,"RIGHT","settingsControlValueLabelLeftX",0);control.valueLabel:SetJustifyH("RIGHT")
  function control:LayoutValueWidth()
   local label=self.valueLabel
   local path,size,flags=label:GetFont();local spacing=label:GetSpacing();local scale=label:GetEffectiveScale()
   local screenWidth,screenHeight;if GetPhysicalScreenSize then screenWidth,screenHeight=GetPhysicalScreenSize() end
   local width=self.valueWidth
   if not self.valueMetricsReady or self.valueMeasure~=label.GetStringWidth or self.valueFont~=path or self.valueSize~=size or self.valueFlags~=flags or self.valueSpacing~=spacing or self.valueScale~=scale
    or self.valueScreenWidth~=screenWidth or self.valueScreenHeight~=screenHeight or label:CanWordWrap() then
    local text=label:GetText();local ready=true
    label:SetWidth(0);label:SetWordWrap(false);width=52
    for digit=0,9 do
     UI:SetText(label,string.rep(tostring(digit),3).."%")
     local measured=label:GetStringWidth();if measured<=0 then ready=false end
     width=math.max(width,math.ceil(measured)+6)
    end
    UI:SetText(label,text);label:SetWidth(width)
    self.valueFont,self.valueSize,self.valueFlags,self.valueSpacing,self.valueScale=path,size,flags,spacing,scale
    self.valueMeasure=label.GetStringWidth
    self.valueScreenWidth,self.valueScreenHeight,self.valueMetricsReady=screenWidth,screenHeight,ready
   end
   self.valueWidth,self.desiredWidth=width,math.max(60,controlWidth-12-width)
   if not self._lycheeLayoutOwner then self:ClearAllPoints();self:SetPoint("RIGHT",-24-width,0) end
   if not self._lycheeLayoutFields or not self._lycheeLayoutFields.width then self:SetWidth(self.desiredWidth) end
  end
  control:LayoutValueWidth()
 elseif row[4]=="binding" then
  control=C.Button(holder,A.L.bindingChange,controlWidth,function() P:BeginBindingCapture() end);C.SetPoint(control,"RIGHT",control:GetParent(),"RIGHT","settingsControlRightX",0)
  holder:HookScript("OnHide",function() if P.bindingCapture==holder then P:CancelBindingCapture(true) end end)
 elseif row[4]=="action" then
  control=C.Button(holder,S("重置位置","Reset position"),controlWidth,function() A.Configuration:Reset("layout.floating.position",{storage="account"}) end)
  C.SetPoint(control,"RIGHT",control:GetParent(),"RIGHT","settingsControlRightX",0)
 elseif row[4] then
  if row[1]=="applicantAlertSound" then
   control=C.ChoiceTrigger(holder,controlWidth,function(button) P:OpenSoundMenu(button) end)
  else control=C.Choice(holder,controlWidth,function() return type(row[4])=="function" and row[4]() or row[4] end,function(value)
   if row[1]=="theme" then
    local status=A.API.Theme:GetStatus()
    local storage=not status.followingDefault and status.next.activationStorage or "account"
    local ok=A.API.Theme:Activate(value,{storage=storage})
    P.themeSelectionError=not ok and S("无法切换主题，请重新选择。","Unable to switch themes. Choose another theme.") or nil
    P:Sync()
   else A:SetSetting(row[1],value) end
  end) end
  control:SetHeight(T.settingsControlHeight);C.SetPoint(control,"RIGHT",control:GetParent(),"RIGHT","settingsControlRightX",0)
 else
  control=C.Check(holder,"",function(value)
   A:SetSetting(row[1],value)
   -- A session preset can mask the saved setting without a value-change callback.
   if control.value~=A:GetSetting(row[1]) then P:Sync() end
  end)
  control.track:ClearAllPoints();C.SetPoint(control.track,"RIGHT",control.track:GetParent(),"RIGHT","settingsControlTrackRightX",0);control.label:ClearAllPoints();C.SetPoint(control.label,"RIGHT",control.track,"LEFT","settingsControlLabelRightX",0);C.SetFont(control.label,14);control:SetPoint("RIGHT",0,0)

  layoutRow.labelStyle=C.Style(holder,{recipe="labelAction",slots={root=holder,label=control.label}})
  layoutRow.labelStyle:Bind(control,{hover=true})
 end
 holder.control,holder.valueLabel,holder.input,holder.track,holder.thumb=control,control.valueLabel,control.box,control.track,control.thumb
 if control.thumb then holder.thumbVisual=control.thumb:GetObjectType()=="Texture" and control.thumb or control.thumb:GetRegions() end
 layoutRow.control,layoutRow.range,layoutRow.check=control,row[4]=="range",not row[4]
 layoutRow.items={{frame=label,width=0,grow=T.settingsLabelRatio,height="content"},{frame=help,width=0,grow=1-T.settingsLabelRatio,height="content"},{frame=control,manageHeight=false}}
 if layoutRow.range then layoutRow.items[3].gapAfter=12;layoutRow.items[4]={frame=control.valueLabel,manageWidth=false} end
 local _,layout=C.Box(holder,{layout="row",items=layoutRow.items,width="fill",height="content",minHeight="settingsHolderHeight2",padding={T.settingsLabelLeftX,16,layoutRow.check and 0 or 12,16},gap=24,align="center",track=true})
 layoutRow.layout=layout
 parent.rowItems=parent.rowItems or {};parent.rowItems[#parent.rowItems+1]={frame=holder,width="fill",manageHeight=false}
 if not parent.rowLayout then parent.rowLayout=C.Column(parent,parent.rowItems,{mode="flex",width="fill",height="content",includeHidden=true,track=true}) else parent.rowLayout:SetItems(parent.rowItems) end
 if row[4]=="binding" or row[4]=="action" then layoutRow.action=control end
 if row[4]~="action" then self.controls[row[1]]={widget=control,definition=row,help=help,frame=holder} end
 UI:Element(holder,"settings.row","settings",holder,"settings.row",row[1])
end

function P:ShowBindingNotice(message,conflict)
 if not self.bindingNotice then
  local notice=C.Notice(self.main,BODY_WIDTH);C.SetPoint(notice,"TOPLEFT",notice:GetParent(),"TOPLEFT",T.settingsContentInset,"settingsNoticeTopleftY");notice.close:Hide()
  self.bindingNotice=notice
  self.cancelBinding=C.Button(notice,A.L.bindingCancel,T.settingsCancelBindingWidth,function() P:CancelBindingCapture() end);C.Box(self.cancelBinding,{width="settingsCancelBindingWidth",height="settingsCancelBindingHeight"});C.SetPoint(self.cancelBinding,"RIGHT",self.cancelBinding:GetParent(),"RIGHT","settingsCancelBindingRightX",0)
  self.overwriteBinding=C.Button(notice,S("覆盖","Overwrite"),T.settingsOverwriteBindingWidth,function() P:TryBinding(P.pendingBindingKey,P.pendingBindingAction) end);C.Box(self.overwriteBinding,{width="settingsOverwriteBindingWidth",height="settingsOverwriteBindingHeight"});C.SetPoint(self.overwriteBinding,"RIGHT",self.cancelBinding,"LEFT","settingsOverwriteBindingRightX",0)
 end
 self.overwriteBinding:SetShown(conflict==true)
 self.bindingNotice:SetMessage(message,conflict and 216 or 96)
self:RegisterBuildElements()
 end

function P:CancelBindingCapture(skipSync)
 local capture=self.bindingCapture
 local handled=capture~=nil or self.bindingNotice and self.bindingNotice:IsShown()
 if not handled then return false end
 if capture then capture:EnableKeyboard(false);capture:SetScript("OnKeyDown",nil) end
 self.frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
 self.bindingCapture,self.pendingBindingKey,self.pendingBindingAction=nil,nil,nil
 if self.bindingNotice then self.bindingNotice:SetMessage("") end
 if not skipSync then self:Sync() end
 return true
end

function P:TryBinding(key,confirmedAction)
 local ok,reason,conflict=A.Bindings:SetKey(key,confirmedAction)
 if ok then self:CancelBindingCapture();return end
 if reason=="conflict" then
  self.pendingBindingKey,self.pendingBindingAction=key,conflict
  self:ShowBindingNotice(S("%s 已用于“%s”。要覆盖此按键吗？","%s is bound to “%s”. Overwrite this binding?"):format(GetBindingText(key),GetBindingName(conflict)),true)
  self:Sync()
 else
  self:CancelBindingCapture(true)
  self:ShowBindingNotice(reason=="combat" and A.L.bindingCombat or A.L.bindingFailed);self:Sync()
 end
end

function P:BeginBindingCapture()
 self:CancelBindingCapture(true)
 if InCombatLockdown() then self:ShowBindingNotice(A.L.bindingCombat);self:Sync();return end
 UI:CloseMenu();UI.Tooltip:Hide()
 local capture=self.controls.toggleBinding.frame;self.bindingCapture=capture
 capture:EnableKeyboard(true);capture:SetPropagateKeyboardInput(false)
 self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
 capture:SetScript("OnKeyDown",function(_,input)
  if input=="ESCAPE" then P:CancelBindingCapture();return end
  local key=GetConvertedKeyOrButton(input)
  if not IsKeyPressIgnoredForBinding(key) then P:TryBinding(CreateKeyChordStringUsingMetaKeyState(key)) end
 end)
 self:Sync()
end
function P:LayoutRows()
 local navTop=12
 for _,entry in ipairs(sections) do
  local button=self.nav[entry[1]]
  navTop=navTop+(entry.gapBefore or 0)
  button.label:SetHeight(0)
  local labelHeight=math.ceil(button.label:GetStringHeight())
  button.label:SetHeight(labelHeight);button:SetHeight(math.max(48,labelHeight+16))
  button:ClearAllPoints()
  if entry[3] then button:SetPoint("BOTTOMLEFT",0,12)
  else button:SetPoint("TOPLEFT",0,-navTop);navTop=navTop+button:GetHeight()+4 end
 end
 local offset=self.bindingNotice and self.bindingNotice:IsShown() and self.bindingNotice:GetHeight()+12 or 0
 for key,panel in pairs(self.panels) do
  UI.Motion:FinishPlacement(panel)
  panel.layoutTop=(key=="blocks" and T.settingsContentInset+self.heading:GetHeight()+12 or 80)+offset
  panel:ClearAllPoints();panel:SetPoint("TOPLEFT",self.main,"TOPLEFT",T.settingsContentInset,-panel.layoutTop);panel:SetHeight((self.layoutHeight or T.contentHeight)-panel.layoutTop-40)
  local top=0
  if panel.rowLayout and panel.rowLayout.dirty then panel.rowLayout:Layout() end
  for _,row in ipairs(panel.rows or {}) do
   local labelWidth=C.ElementValue(row.frame,"label","width",0);local helpWidth=C.ElementValue(row.frame,"help","width",0)
   local labelGrow=labelWidth==0 and T.settingsLabelRatio or 0;local helpGrow=helpWidth==0 and 1-T.settingsLabelRatio or 0
   local control=row.control
   local naturalWidth=row.range and control.desiredWidth or row.action and math.ceil(C.MeasureTextWidth(control.label))+T.settingsActionTextPadding or row.check and control:GetWidth() or T.settingsControlWidth
   local controlWidth=C.ElementValue(row.frame,"control","width",naturalWidth)
   local gap;if not row.range then gap=24+row.controlWidth-controlWidth+(row.check and 12 or 0) end
   if row.items[1].width~=labelWidth or row.items[1].grow~=labelGrow or row.items[2].width~=helpWidth or row.items[2].grow~=helpGrow or row.items[2].gapAfter~=gap or row.items[3].width~=controlWidth or row.range and row.items[4].width~=control.valueWidth then
    row.items[1].width,row.items[1].grow,row.items[2].width,row.items[2].grow=labelWidth,labelGrow,helpWidth,helpGrow
    row.items[2].gapAfter,row.items[3].width=gap,controlWidth
    if row.range then row.items[4].width=control.valueWidth end
    row.layout:Invalidate("settings-control")
   end
   if row.layout.dirty then row.layout:Layout() end;top=top+row.frame:GetHeight()
  end
  if panel.rowLayout and panel.rowLayout.dirty then panel.rowLayout:Layout() end
  panel.nextRowY=top
 end
 local reloadPanel=self.reloadLanguage:GetParent()
 self.reloadLanguage:ClearAllPoints();self.reloadLanguage:SetPoint("TOPRIGHT",reloadPanel,"TOPRIGHT",0,-reloadPanel.nextRowY-16)
 if self.themeReloadHint then
  self.themeReloadHint:SetWidth(math.max(1,BODY_WIDTH-self.reloadLanguage:GetWidth()-24))
  self.themeReloadHint:ClearAllPoints();self.themeReloadHint:SetPoint("TOPLEFT",0,-self.panels.interface.nextRowY-16)
 end
 self:LayoutCredits()
end
local function SizePage(self,width,height)
 self.layoutHeight=height;BODY_WIDTH=width-T.settingsMainX-T.settingsContentInset*2-12
 self.rail:SetHeight(height);self.main:SetSize(width-T.settingsMainX,height)
 for _,panel in pairs(self.panels) do
  panel:SetWidth(BODY_WIDTH)
  for _,row in ipairs(panel.rows or {}) do
   row.controlWidth=C.ElementValue(row.frame,"control","width",T.settingsControlWidth)
  end
 end
 self.aboutHeader:SetWidth(BODY_WIDTH);self.aboutValues.name:SetWidth(BODY_WIDTH-84)
 self.otherAddonsHeading:SetWidth(BODY_WIDTH-24)
 for _,row in ipairs(self.otherAddons) do row.frame:SetWidth(BODY_WIDTH);row.title:SetWidth(BODY_WIDTH-84);row.summary:SetWidth(BODY_WIDTH-96) end
 if self.bindingNotice then self.bindingNotice:SetWidth(BODY_WIDTH) end
 if self.blocksList then
  self.blocksEmpty:SetWidth(BODY_WIDTH);self.blocksList:SetWidth(BODY_WIDTH+12)
 end
end
function P:LayoutSize(width,height)
 SizePage(self,width,height)
 self:LayoutRows()
 if self.blocksList then self:LayoutBlocks() end
 if self.section=="about" then self:RefreshAbout() end
UI:ApplyElementScope("settings")
 end
function P:LayoutFont(width,height)
 SizePage(self,width or UI.content:GetWidth(),height or UI.content:GetHeight())
 self:Sync()
 if self.blocksList and self.section~="blocks" then self:LayoutBlocks() end
UI:ApplyElementScope("settings")
 end
function P:SelectSection(key)
 local changed=self.section~=key
 if changed then self:CancelBindingCapture(true);self:StopBlocks();self:CloseLinkCopy(true);self:StopSoundPreview() end
 for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end
 if key=="notifications" then self.frame:RegisterEvent("CVAR_UPDATE") else self.frame:UnregisterEvent("CVAR_UPDATE") end
 self.section=key;for id,panel in pairs(self.panels) do panel:SetShown(id==key);self.nav[id]:SetActive(id==key);UI:Color(self.nav[id].label,id==key and "text" or "muted") end
 for _,entry in ipairs(sections) do if entry[1]==key then UI:SetText(self.heading,entry[2]);break end end
 if key=="blocks" then self:EnterBlocks() end
 if key=="credits" and not self.credits then self:BuildCredits() end
 self:Sync()
 if changed then UI.Motion:Reveal(self.panels[key],"TOPLEFT",self.main,"TOPLEFT",T.settingsContentInset,-self.panels[key].layoutTop,4,0,.14) end
UI:ApplyElementScope("settings")
 end
function P:ReflowMetrics(width,height)
 self:LayoutSize(width,height)
 self.rail:SetWidth(T.settingsSidebarWidth);self.main:SetPoint("TOPLEFT",T.settingsMainX,0)
 self.heading:SetPoint("TOPLEFT",T.settingsContentInset,-T.settingsContentInset)
 for _,button in pairs(self.nav) do button:SetWidth(T.settingsSidebarWidth) end
 if self.section~="about" then self:RefreshAbout() end
 if self.blocksHeader then
  self.blocksHeader:Layout(self.blocksList:GetWidth()-C.listRightInset)
  self.blocksList:Refresh(true)
 end
UI:ApplyElementScope("settings")
 end

function P:Sync()
 local themeStatus=A.API.Theme:GetStatus()
 for key,entry in pairs(self.controls) do
  local c,row=entry.widget,entry.definition
  local value
  if key=="theme" then value=themeStatus.next.id or A.ThemeDefaults.id elseif key=="channelVolume" then value=self:GetChannelVolume() else value=A:GetSetting(key) end
  if row[4]=="binding" then
   local text=self.bindingCapture and A.L.bindingListen or A.L.bindingCurrent:format(A.Bindings:Text())
   local conflict=not A.Bindings:Keys() and A.Bindings:Conflict(A.Bindings.defaultKey)
   if not self.bindingCapture and conflict then text=text.."\n"..A.L.bindingDefaultConflict:format(GetBindingName(conflict)) end
   UI:SetText(entry.help,text)
   UI:SetText(c.label,self.bindingCapture and S("按下新按键…","Press a key…") or A.L.bindingChange)
  elseif row[4]=="range" then c:LayoutValueWidth();if not c:IsDragging() then c:SetValue(value);UI:SetText(c.valueLabel,value.."%") end
  elseif row[4] then
   local label
   if key=="font" then label=A.Fonts:ChoiceLabel(value)
   else local choices=type(row[4])=="function" and row[4]() or row[4];for _,choice in ipairs(choices) do if choice.value==value then label=choice.label;break end end end
   c:SetValue(value,label)
  else c:SetValue(value==true);UI:SetText(c.label,value and S("已开启","On") or S("已关闭","Off"));c:SetWidth(math.ceil(c.label:GetStringWidth())+c.track:GetWidth()+36) end
 end
 local floatingScale=self.controls.floatingScale.widget
 local scaleAvailable=not A:GetSetting("floatingCompatibility")
 floatingScale.slider:EnableMouse(scaleAvailable)
 floatingScale.progress:SetShown(scaleAvailable)
 floatingScale.thumb:SetVertexColor(unpack(scaleAvailable and T.accent or T.disabled))
 UI:Color(floatingScale.valueLabel,scaleAvailable and "muted" or T.disabled)
 local pendingTheme=themeStatus.reloadRequired
 local themeMessage=self.themeSelectionError or S("主题已保存，重载界面后生效。","Theme saved. Reload the UI to apply it.")
 if (pendingTheme or self.themeSelectionError) and not self.themeReloadHint then
  self.themeReloadHint=C.Text(self.panels.interface,S("主题已保存，重载界面后生效。","Theme saved. Reload the UI to apply it."),14,"muted",BODY_WIDTH,20)
  self.themeReloadHint:SetWordWrap(true)
  UI:Element(self.themeReloadHint,"settings.themeReloadHint","settings")
 end
 if self.themeReloadHint then UI:SetText(self.themeReloadHint,themeMessage);self.themeReloadHint:SetShown(pendingTheme or self.themeSelectionError~=nil) end
 -- Language belongs to General; a pending theme belongs to Appearance.
 -- Reuse the action while keeping each reload reason in its own section.
 self.reloadLanguage:SetParent(self.section=="general" and self.panels.general or self.panels.interface)
 self.reloadLanguage:SetShown(self.section=="general" and A:NeedsLanguageReload() or self.section=="interface" and pendingTheme)
 self:LayoutRows()
 if self.section=="about" then self:RefreshAbout() end
 if self.section=="blocks" then self:RefreshBlocks() end
UI:ApplyElementScope("settings")
 end
function P:StopThemeSubscription()
 if self.themeSubscription then self.themeSubscription();self.themeSubscription=nil end
end
function P:HideSoundMenuButtons()
 if not self.soundMenuButtons then return end
 for _,button in ipairs(self.soundMenuButtons) do
  if button.soundChoice then button:Hide();button.soundChoice=nil end
 end
end
function P:SyncSoundMenuButtons()
 if not self.soundMenuAnchor or not UI.context:IsMenuOpen(self.soundMenuAnchor) then self:HideSoundMenuButtons();return end
 local menu=UI.context:GetMenu()
 for _,row in ipairs(menu.list.rows) do
  local entry=row:IsShown() and row:IsMouseEnabled() and applicantSounds[row.key]
  local button=row.applicantSoundPreview
  if entry and entry.value~="off" then
   if not button then
    button=C.IconButton(row,nil,32,function(b)
     if row:IsMouseEnabled() and menu.list.clip:IsMouseOver() then P:PreviewApplicantSound(b.soundChoice) end
    end,{iconSize=12})
    button.icon:SetTexture("Interface\\AddOns\\LycheeGroup_UI\\Media\\sound-preview-play.tga")
    button:SetPoint("RIGHT",-4,0);row.applicantSoundPreview=button
    self.soundMenuButtons[#self.soundMenuButtons+1]=button
   end
   -- Hiding cancels the component's old press before this pooled row is rebound.
   if button.soundChoice~=entry.value then button:Hide();button.soundChoice=entry.value end
   if not button:IsShown() then button:Show() end
   local width=math.max(0,row:GetWidth()-T.menuSelectInset-T.menuTextInset-40)
   if math.abs(row.title:GetWidth()-width)>.01 then row.title:SetWidth(width) end
  elseif button and button.soundChoice then button:Hide();button.soundChoice=nil end
 end
end
function P:OpenSoundMenu(anchor)
 if not self.soundMenuMeasure then self.soundMenuMeasure=C.Text(anchor,"","menuFontSize","text");self.soundMenuMeasure:Hide() end
 local width=anchor:GetWidth()
 local context,measure=UI.context,self.soundMenuMeasure
 for _,entry in ipairs(applicantSounds) do
  local key=context:GetMenuElementKey(anchor,entry.value)
  local font=context:ResolveElementValue("menu.row","label","font",context.fontPath,key)
  local size=context:ResolveElementValue("menu.row","label","fontSize",context:GetFontSize("menuFontSize"),key)
  local flags=context:ResolveElementValue("menu.row","label","flags","",key)
  local currentFont,currentSize,currentFlags=measure:GetFont()
  if currentFont~=font or currentSize~=size or currentFlags~=flags then measure:SetFont(font,size,flags) end
  -- Reserve the scrollbar too: startup row heights may make this menu scroll.
  width=math.max(width,math.ceil(C.MeasureTextWidth(measure,entry.label))+T.menuSelectInset+T.menuTextInset+T.menuPadding*2+40+C.listRightInset)
 end
 UI:OpenMenu(anchor,applicantSounds,function(value,label) anchor:SetValue(value,label);A:SetSetting("applicantAlertSound",value) end,{kind="select",selectedValue=anchor.value,width=width})
 if not UI.context:IsMenuOpen(anchor) then return end
 self.soundMenuAnchor=anchor
 if not self.soundMenuButtons then
  self.soundMenuButtons={}
  local menu=UI.context:GetMenu()
  -- The shared menu/list exposes rows for product-owned controls. Rebind after
  -- refresh so font/layout changes and row reuse cannot leave stale actions.
  hooksecurefunc(menu.list,"Refresh",function() if P.soundMenuAnchor then P:SyncSoundMenuButtons() end end)
  menu:HookScript("OnHide",function()
   if not P.soundMenuAnchor then return end
   P.soundMenuAnchor=nil;P:HideSoundMenuButtons();P:StopSoundPreview()
  end)
 end
 self:SyncSoundMenuButtons()
end
function P:PreviewApplicantSound(choice)
 if choice~="voice" and choice~="native" then return end
 local group,err=A:Ensure("Group")
 if not group then A:Print(A.L.loadFailed:format(tostring(err)));return end
 self.previewAlerts=group.Alerts
 self.previewAlerts:Preview(choice)
end
function P:StopSoundPreview()
 if self.previewAlerts then self.previewAlerts:StopPreview();self.previewAlerts=nil end
end
function P:Enter(context)
 if self.dedicationExpired then self:HideDedicationToast() end
 self:StopThemeSubscription()
 self.themeSubscription=A.API.Theme:Subscribe(function()
  if self.frame:IsShown() and UI.page=="settings" and not UI.hiding then P:Sync() end
 end)
 self.frame:RegisterEvent("UPDATE_BINDINGS");self:SelectSection(context and context.section or self.section)
end
function P:Leave()
 self:StopSoundPreview()
 self:StopThemeSubscription()
 self:CloseLinkCopy(true)
 self:StopBlocks()
 self.frame:UnregisterEvent("UPDATE_BINDINGS");self.frame:UnregisterEvent("CVAR_UPDATE")
 self.aboutClicks=0;self:HideDedicationToast()
 self.controls.uiScale.widget:FinishDrag(false)
 self:CancelBindingCapture(true)
 for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end
end




function P:RegisterBuildElements()
UI:ElementFields(self,"settings","frame rail main heading reloadLanguage blocksToolbar blocksCount blocksClear blocksHeader blocksEmpty aboutHeader aboutBrand otherAddonsHeading dedicationToast bindingNotice cancelBinding overwriteBinding","settings")
 if self.blocksList then UI:ElementList(self.blocksList,"settings.blocksList","settings","settings.block") end
end
