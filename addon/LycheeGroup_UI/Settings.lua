-- One Settings navigation serves account and character preferences and addon information.
local A=_G.LycheeGroup
local UI=A.UI
local C,T,L=UI.C,UI.Theme,UI.L
local P={section="general"};UI.pages.settings=P
local zh=A:GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
local sections={{"general",S("入口与快捷键","Access & shortcuts")},{"interface",S("界面与外观","Appearance")},{"browse",S("队伍与成员","Groups & members")},{"memberIcons",S("成员图标","Member icons")},{"blocks",S("屏蔽","Blocks")},{"notes",S("笔记与提醒","Notes and reminders")},{"floating",S("悬浮窗","Floating window")},{"about",L.about}}
local types={{value="positive",label=S("推荐","Positive")},{value="neutral",label=S("中性","Neutral")},{value="caution",label=S("拉黑","Blocked")}}
local definitions={
 general={{"toggleBinding",A.L.bindingToggle,"","binding"},
 {"minimap",S("显示小地图按钮","Show minimap button"),S("是否显示小地图按钮","Show or hide the minimap button.")},
 {"nativeLFGEntry",S("隐藏原生组队眼睛","Hide the native LFG eye"),S("预组队隐藏原生眼睛按钮","Hide the native eye button for premade groups.")}},
 interface={{"language",S("界面语言","Interface language"),S("仅改变插件文字，重载界面后生效。","Change addon text. Reload the UI to apply."),{{value="auto",label=S("跟随游戏","Game language")},{value="zhCN",label="简体中文"},{value="enUS",label="English"}}},
 {"uiScale",S("主窗口缩放","Main window scale"),S("等比调整整个主窗口。","Scale the entire main window proportionally."),"range",75,125},
 {"fontScale",S("字体大小","Font size"),S("调节插件全局文字","Adjust text size throughout the addon."),"range",70,130},
 {"font",S("界面字体","Interface font"),S("界面字体选择","Choose the interface font."),function() return A.Fonts:Choices() end},
 {"showImportantFilters",S("在主界面显示重要过滤","Show key filters on the main page"),S("开启后在“我的申请”内显示；关闭时在筛选弹窗内调整。","Show them in My applications, or keep them in the filter panel when off.")},
 {"reduceMotion",L.reduceMotion,S("关闭开窗位移、Logo 动作和局部过渡。","Disable window movement, logo animation and local transitions.")}},
 browse={
 {"defaultSort",S("默认排序","Default sorting"),S("本角色进入其他活动分类时采用的排序。","Default sorting for this character's activity categories."),{{value="newest",label=L.newest},{value="rating",label=L.leaderRating},{value="itemLevel",label=L.requiredItemLevel},{value="members",label=L.members}}},
 {"rememberFilters",S("记住本角色的筛选","Remember character filters"),S("本角色独立保存各分类筛选。","Save category filters for this character.")},
 {"relations",S("好友与公会标记","Friend and guild markers"),S("在队伍、申请者和成员提示中显示关系。","Show relationships in group, applicant and player details.")},
 {"raidMembers",S("团本成员列表","Raid members"),S("控制团本悬停提示中何时展开成员。","Choose when raid tooltips expand the member list."),{{value="shift",label=S("按 Shift 切换","Press Shift to toggle")},{value="alt",label=S("按 Alt 切换","Press Alt to toggle")},{value="ctrl",label=S("按 Ctrl 切换","Press Ctrl to toggle")},{value="always",label=S("始终展开","Always expand")}}}},
 memberIcons={
 {"memberIconShape",S("图标形状","Icon shape"),S("调整寻队五人成员图标及职业色边框的轮廓。","Choose the shape of five-player search-result icons and their borders."),{{value="circle",label=S("圆形","Circle")},{value="square",label=S("圆角方形","Rounded square")}}},
 {"memberLeaderMark",S("成员队长标记","Roster leader mark"),S("在实际队长的成员头像上方显示皇冠。","Show a crown above the actual leader's member icon.")},
 {"memberClassBorder",S("成员职业色边框","Class-color borders"),S("为寻队结果已有成员显示职业色边框。","Show class-color borders around occupied search-result member icons.")},
 {"memberIconScale",S("成员图标缩放","Member icon scale"),S("调整寻队结果五人成员图标大小，成员列自动预留空间。","Resize five-player search-result icons; reserve column space automatically."),"range",75,175}},
 notes={{"defaultNote",S("新记录的默认类型","Default note type"),S("每次记笔记时仍可选择其他类型。","Choose a different type whenever you record a player."),types},
 {"noteMarks",S("荔枝笔记标记","Player note markers"),S("分别显示推荐、中性和拉黑记录；包含队伍成员。","Show recommendation, neutral and block markers, including group members.")},
 {"reminders",S("组队与邀请提醒","Group and invite reminders"),S("收到邀请、邀请玩家或再次组队时，提示符合范围的记录。","Show matching player notes when receiving an invite, inviting a player or grouping again."),{{value="all",label=S("全部记录","All notes")},{value="positive",label=S("仅推荐","Recommended only")},{value="caution",label=S("仅拉黑","Blocked only")},{value="off",label=S("不提醒","Off")}}},
 {"history",S("记录大秘境历史队友","Record Mythic+ teammates"),S("完成后保留活动与成员，便于回顾和补充笔记。","Keep completed runs and teammates for reviewing and adding notes.")}},
 floating={{"floating",S("显示悬浮窗","Show floating window"),S("查看申请与招募状态，关闭主窗口后仍然显示。","View active applications and recruitment while the main window is closed.")},
 {"floatingCompatibility",S("悬浮窗兼容","Floating window integration"),S("自动接入第三方UI配置的视觉兼容","Automatically adapt the appearance to third-party UI configurations.")},
 {"floatingScale",S("悬浮窗缩放","Floating window scale"),S("调整悬浮窗大小。","Adjust the floating window size."),"range"},
 {"floatingLocked",S("锁定位置","Lock position"),S("锁定后不能拖动，查看状态和点击入口不受影响。","Lock movement while keeping the status and shortcuts active.")}}}
local BODY_WIDTH = T.contentWidth - T.settingsMainX - T.settingsContentInset*2 - 12
function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 root:SetScript("OnEvent",function(_,event)
  if event=="UPDATE_BINDINGS" then P:Sync()
  elseif event=="PLAYER_REGEN_DISABLED" then
   P:CancelBindingCapture(true);P:ShowBindingNotice(A.L.bindingCombat);P:Sync()
  end
 end)
 root:HookScript("OnHide",function() P:CancelBindingCapture(true) end)
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(T.settingsSidebarWidth,T.contentHeight);rail:SetPoint("TOPLEFT");self.rail=rail
 self.nav={};for i,entry in ipairs(sections) do
  local b=C.Navigation(rail,entry[2],T.settingsSidebarWidth,function() P:SelectSection(entry[1]) end,nil,{radius=8,fontSize="font14"});b:SetPoint("TOPLEFT",0,-12-(i-1)*52);C.ApplyStyle(b.label,{width="settingsBLabelWidth"})
  self.nav[entry[1]]=b
 end
 local main=CreateFrame("Frame",nil,root);main:SetSize(T.contentWidth-T.settingsMainX,T.contentHeight);main:SetPoint("TOPLEFT",T.settingsMainX,0);C.Panel(main,"surfaceLow","settingsPanelRadius");self.main=main
 self.heading=C.Text(main,"","font24");self.heading:SetPoint("TOPLEFT",T.settingsContentInset,-T.settingsContentInset);C.SetLineHeight(self.heading,"line32",true)
 self.panels={};self.controls={}
 for _,entry in ipairs(sections) do
  local panel=CreateFrame("Frame",nil,main);panel:SetSize(BODY_WIDTH,T.contentHeight-120);C.SetPoint(panel,"TOPLEFT",panel:GetParent(),"TOPLEFT",T.settingsContentInset,"settingsPanelTopleftY");self.panels[entry[1]]=panel
  for i,row in ipairs(definitions[entry[1]] or {}) do self:BuildRow(panel,row,i) end
 end
 local reset={"resetPosition",S("悬浮窗位置","Floating window position"),S("未锁定时拖动荔枝标志，可放在屏幕内任意位置。","Drag the lychee logo to position the window when unlocked."),"action"}
 self:BuildRow(self.panels.floating,reset,#definitions.floating+1)
 self.reloadLanguage=C.Button(self.panels.interface,S("重载界面","Reload UI"),T.settingsReloadLanguageWidth,function() C_UI.Reload() end);C.ApplyStyle(self.reloadLanguage,{width="settingsReloadLanguageWidth"})
 self:BuildAbout(self.panels.about)
end
function P:BuildBlocks()
 local panel=self.panels.blocks
 self.blocksHelp=C.Text(panel,S("屏蔽相同标题队伍时，也会屏蔽对应队长。","Blocking groups with the same title also blocks their leaders."),"font14","muted",BODY_WIDTH)
 self.blocksHelp:SetPoint("TOPLEFT");self.blocksHelp:SetWordWrap(true);C.SetLineHeight(self.blocksHelp,"line20")
 self.blocksCount=C.Text(panel,"","font14","muted");C.SetLineHeight(self.blocksCount,"line20",true)
 self.blocksClear=C.Button(panel,S("全部清空","Clear all"),T.settingsBlocksClearWidth,function() if P.blockGroup then P.blockGroup.Results:ClearBlockedTitles() end end,{variant="text"});C.ApplyStyle(self.blocksClear,{width="settingsBlocksClearWidth"})
 local list=C.List(panel,BODY_WIDTH+12,T.contentHeight-120,52)
 list:SetStyle({selectionFill=false,selectionMark=false,hoverFill=false});self.blocksList=list
 list:SetRowInitializer(function(row)
  row.title:ClearAllPoints();C.SetPoint(row.title,"LEFT",row.title:GetParent(),"LEFT","settingsRowTitleLeftX",0);row.title:SetWordWrap(false);C.SetFont(row.title,"font15");C.SetLineHeight(row.title,"line20",true)
  row.meta:ClearAllPoints();row.meta:Show();row.meta:SetWordWrap(false);C.SetFont(row.meta,"font13");C.SetLineHeight(row.meta,"line18",true);UI:Color(row.meta,T.muted)
  row:SetScript("OnClick",nil)
  row.remove=C.Button(row,S("移除","Remove"),T.settingsRowRemoveWidth,function(button)
   if P.blockGroup and row.key==button.targetKey and row._hitVisible and list.clip:IsMouseOver() then P.blockGroup.Results:RemoveBlockedLeader(button.targetKey) end
  end,{variant="text"});C.ApplyStyle(row.remove,{width="settingsRowRemoveWidth"});C.SetPoint(row.remove,"RIGHT",row.remove:GetParent(),"RIGHT","settingsRowRemoveRightX",0)
 end)
 self.blocksHeader=C.TableHeader(panel,{
  {key="name",label=S("名字","Name"),width="settingsColumnNameWidth340",min="settingsColumnNameMin140"},
  {key="realm",label=S("服务器","Realm"),width="settingsColumnRealmWidth280",min="settingsColumnRealmMin120"},
  {key="actions",label=S("操作","Actions"),width="settingsColumnActionsWidth148",min="settingsColumnActionsMin132",align="CENTER"},
 },{onLayout=function(header) P:LayoutBlockColumns(header) end})
 self.blocksEmpty=C.Text(panel,"","font18","dim",BODY_WIDTH);C.SetLineHeight(self.blocksEmpty,"line24");self.blocksEmpty:SetJustifyH("CENTER");self.blocksEmpty:SetWordWrap(true)
end
function P:LayoutBlockColumns(header)
 if not self.blocksList then return end
 local name,realm,actions=header.columns.name,header.columns.realm,header.columns.actions
 for _,row in ipairs(self.blocksList.rows) do
  row.title:ClearAllPoints();row.title:SetPoint("LEFT",name.x+6,0);row.title:SetWidth(name.width-12)
  row.meta:ClearAllPoints();row.meta:SetPoint("LEFT",realm.x+6,0);row.meta:SetWidth(realm.width-12)
  row.remove:ClearAllPoints();row.remove:SetPoint("LEFT",actions.x+(actions.width-row.remove:GetWidth())/2,0)
 end
end
function P:LayoutBlocks()
 if not self.blocksList then return end
 local top=self.blocksHelp:GetStringHeight()+8
 self.blocksHelp:SetHeight(self.blocksHelp:GetStringHeight())
 local list=self.blocksList
 local toolbarHeight=math.max(32,math.ceil(self.blocksClear.label:GetStringHeight())+12)
 self.blocksClear:SetHeight(toolbarHeight)
 self.blocksClear:SetWidth(math.ceil(self.blocksClear.label:GetStringWidth())+32)
 self.blocksClear:ClearAllPoints();self.blocksClear:SetPoint("TOPRIGHT",-list.gutter-12,-top)
 self.blocksCount:ClearAllPoints();self.blocksCount:SetPoint("LEFT",self.panels.blocks,"TOPLEFT",0,-top-toolbarHeight/2)
 top=top+toolbarHeight+8
 self.blocksHeader:ClearAllPoints();C.SetPoint(self.blocksHeader,"TOPLEFT",self.blocksHeader:GetParent(),"TOPLEFT","settingsBlocksHeaderTopleftX",-top)
 top=top+self.blocksHeader:GetHeight()+8
 local rowHeight=math.max(52,math.ceil(UI.context:GetLineHeight("line20")+24))
 local changed=list.rowHeight~=rowHeight
 list.rowHeight=rowHeight;list.capacity=math.min(list.poolCapacity-1,math.ceil(list:GetHeight()/rowHeight))
 list.canvas:SetHeight(list:GetHeight()+rowHeight*2)
 local viewport=math.max(rowHeight,self.panels.blocks:GetHeight()-top)
 local sameViewport=list.viewportHeight==viewport
 list:ClearAllPoints();C.SetPoint(list,"TOPLEFT",list:GetParent(),"TOPLEFT","settingsListTopleftX",-top);list:SetViewport(viewport)
 for i,row in ipairs(list.rows) do
  row:SetHeight(rowHeight);row:SetPoint("TOPLEFT",0,-(i-1)*rowHeight)
  row.remove:SetHeight(toolbarHeight)
  row.remove:SetWidth(math.ceil(row.remove.label:GetStringWidth())+32)
 end
 self.blocksHeader:Layout(list:GetWidth()-list.gutter)
 if changed and sameViewport then list:Refresh(true) end
 self.blocksEmpty:ClearAllPoints();self.blocksEmpty:SetPoint("TOPLEFT",0,-top-48)
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
  if group then self.blocksUnsub=group:Subscribe(function(kind) if kind=="results" then P:RefreshBlocks() end end) end
 end
end
function P:BuildAbout(parent)
 local header=CreateFrame("Frame",nil,parent);header:SetSize(BODY_WIDTH,T.settingsHeaderHeight);header:SetPoint("TOPLEFT");UI.drag:AddHandle(header);self.aboutHeader=header
 local logo=C.Icon(header,T.settingsLogoWidth);C.ApplyStyle(logo,{width="settingsLogoWidth",height="settingsLogoHeight"});logo:SetTexture(T.media.."lychee-logo.tga");C.SetPoint(logo,"TOPLEFT",logo:GetParent(),"TOPLEFT","settingsLogoTopleftX","settingsLogoTopleftY")
 self.aboutValues={}
 local name=C.Text(header,"","font18","text",BODY_WIDTH-84);C.SetLineHeight(name,"line24",true);name:SetWordWrap(false);C.SetPoint(name,"TOPLEFT",name:GetParent(),"TOPLEFT","settingsNameTopleftX","settingsNameTopleftY");self.aboutValues.name=name
 local versionLabel=C.Text(header,L.addonVersion,"font14","muted");C.SetLineHeight(versionLabel,"line20",true);C.SetPoint(versionLabel,"TOPLEFT",versionLabel:GetParent(),"TOPLEFT","settingsVersionLabelTopleftX","settingsVersionLabelTopleftY")
 local version=C.Text(header,"","font14","text",T.settingsVersionWidth);C.ApplyStyle(version,{width="settingsVersionWidth"});C.SetLineHeight(version,"line20",true);version:SetWordWrap(false);C.SetPoint(version,"TOPLEFT",versionLabel,"TOPRIGHT","settingsVersionTopleftX",0);self.aboutValues.version=version
 local authorLabel=C.Text(header,L.addonAuthor,"font14","muted");C.SetLineHeight(authorLabel,"line20",true);C.SetPoint(authorLabel,"TOPLEFT",version,"TOPRIGHT","settingsAuthorLabelTopleftX",0)
 local author=C.Text(header,"","font14","text");C.SetLineHeight(author,"line20",true);author:SetWordWrap(false);C.SetPoint(author,"TOPLEFT",authorLabel,"TOPRIGHT","settingsAuthorTopleftX",0);C.SetPoint(author,"TOPRIGHT",header,"TOPRIGHT","settingsAuthorToprightX","settingsAuthorToprightY");self.aboutValues.author=author
 local brand=CreateFrame("Button",nil,header);C.ApplyStyle(brand,{width="settingsBrandWidth",height="settingsBrandHeight"});brand:SetPoint("TOPLEFT");brand:RegisterForClicks("LeftButtonUp");self.aboutBrand=brand
 brand:SetScript("OnClick",function()
  P.aboutClicks=(P.aboutClicks or 0)+1
  if P.aboutClicks==10 then P.aboutClicks=0;P:ShowDedicationToast() end
 end)
 parent:HookScript("OnHide",function() P.aboutClicks=0;P:HideDedicationToast() end)
 self.otherAddonsHeading=C.Text(parent,L.otherAddons,"font14","muted",BODY_WIDTH-24);C.SetLineHeight(self.otherAddonsHeading,"line20",true);C.SetPoint(self.otherAddonsHeading,"TOPLEFT",self.otherAddonsHeading:GetParent(),"TOPLEFT","settingsOtherAddonsHeadingTopleftX","settingsOtherAddonsHeadingTopleftY")
 local media="Interface\\AddOns\\LycheeGroup_UI\\Media\\"
 local entries={
  {name=L.lycheeLauncher,summary=L.lycheeLauncherHelp,icon=media.."about-launcher.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJKkdJtw8gt"},{L.neteaseDD,"https://url.cc.163.com/HoH0Od"}}},
  {name=L.lycheeTalent,summary=L.lycheeTalentHelp,icon=media.."about-talent.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJu72Mjcmed"},{L.neteaseDD,"https://url.cc.163.com/w64q1s"}}},
 }
 self.otherAddons={}
 for index,entry in ipairs(entries) do
  local holder=CreateFrame("Frame",nil,parent);holder:SetSize(BODY_WIDTH,T.settingsHolderHeight);UI.drag:AddHandle(holder)
  C.Panel(holder,"rowAlternate","settingsPanelRadius2"):SetShown(index%2==0)
  local icon=C.Icon(holder,T.settingsIconWidth);C.ApplyStyle(icon,{width="settingsIconWidth",height="settingsIconHeight"});icon:SetTexture(entry.icon);C.SetPoint(icon,"TOPLEFT",icon:GetParent(),"TOPLEFT","settingsIconTopleftX","settingsIconTopleftY")
  local title=C.Text(holder,entry.name,"font18","text",BODY_WIDTH-84);C.SetLineHeight(title,"line24",true);C.SetPoint(title,"TOPLEFT",title:GetParent(),"TOPLEFT","settingsTitleTopleftX","settingsTitleTopleftY")
  local summary=C.Text(holder,entry.summary,"font14","muted",BODY_WIDTH-96);C.SetLineHeight(summary,"line20");summary:SetWordWrap(true);C.SetPoint(summary,"TOPLEFT",summary:GetParent(),"TOPLEFT","settingsSummaryTopleftX","settingsSummaryTopleftY")
  local row={frame=holder,icon=icon,title=title,summary=summary,links={}}
  for i,link in ipairs(entry.links) do
   local url,identity=link[2],entry.name.." · "..link[1]
   local button=C.Button(holder,link[1],T.settingsButtonWidth,function() UI:CopyText(L.copyDownloadLink,url,nil,identity,L.downloadLink) end);C.ApplyStyle(button,{width="settingsButtonWidth"});C.ApplyStyle(button,{height="settingsButtonHeight"});C.SetPoint(button,"BOTTOMLEFT",button:GetParent(),"BOTTOMLEFT",72+(i-1)*132,"settingsButtonBottomleftY");button:SetSurfaceColors(T.surfaceContainer,T.surfaceHighest)
   row.links[i]=button
  end
  self.otherAddons[index]=row
 end
end
function P:HideDedicationToast()
 if self.dedicationTimer then self.dedicationTimer:Cancel();self.dedicationTimer=nil end
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
 self.dedicationTimer=C_Timer.NewTimer(5,function() P:HideDedicationToast() end)
end
function P:RefreshAbout()
 for key,field in pairs({name="Title",version="Version",author="Author"}) do
  local text=C_AddOns.GetAddOnMetadata("LycheeGroup",field)
  UI:SetText(self.aboutValues[key],text and text~="" and text or key=="name" and L.reminder or L.metadataMissing)
 end
 self.aboutBrand:SetWidth(math.max(220,math.ceil(self.aboutValues.name:GetStringWidth())+84))
 local top=140
 for _,row in ipairs(self.otherAddons) do
  local height=math.max(148,row.summary:GetStringHeight()+104)
  row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-top);row.frame:SetHeight(height);top=top+height+12
  local left=72
  for _,button in ipairs(row.links) do
   local width=math.max(120,math.ceil(button.label:GetStringWidth())+32)
   button:SetWidth(width);button:ClearAllPoints();C.SetPoint(button,"BOTTOMLEFT",button:GetParent(),"BOTTOMLEFT",left,"settingsButtonBottomleftY");left=left+width+12
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
 local fill=C.Panel(holder,"rowAlternate","settingsFillRadius");fill:SetShown(index%2==0)
 local controlWidth=220;local content=BODY_WIDTH-24-controlWidth-48;local labelWidth=content*.4;local helpWidth=content-labelWidth
 local label=C.Text(holder,row[2],"font14","text",labelWidth);C.SetPoint(label,"LEFT",label:GetParent(),"LEFT","settingsLabelLeftX",0);label:SetWordWrap(true);C.SetLineHeight(label,"line20")
 local help=C.Text(holder,row[3],"font14","muted",helpWidth);help:SetPoint("LEFT",36+labelWidth,0);help:SetWordWrap(true);C.SetLineHeight(help,"line20")
 local rowHeight=math.max(88,label:GetStringHeight()+32,help:GetStringHeight()+32);holder:SetHeight(rowHeight);parent.nextRowY=(parent.nextRowY or 0)+rowHeight
 local layoutRow={frame=holder,label=label,help=help}
 parent.rows=parent.rows or {};parent.rows[#parent.rows+1]=layoutRow
 local control
 if row[4]=="range" then
  if row[1]=="uiScale" then control=WindowScaleControl(holder)
  else control=C.Slider(holder,156,row[5] or 50,row[6] or 150,5,function(value)
   value=math.floor(value/5+.5)*5
   local widget=P.controls[row[1]].widget
   UI:SetText(widget.valueLabel,value.."%")
   A:SetSetting(row[1],value)
  end) end
  control.valueLabel=C.Text(control,"","font14","muted",T.settingsControlValueLabelWidth);C.ApplyStyle(control.valueLabel,{width="settingsControlValueLabelWidth"});C.SetPoint(control.valueLabel,"LEFT",control,"RIGHT","settingsControlValueLabelLeftX",0);control.valueLabel:SetJustifyH("RIGHT")
  function control:LayoutValueWidth()
   local text=self.valueLabel:GetText()
   self.valueLabel:SetWidth(0);self.valueLabel:SetWordWrap(false)
   local width=52
   for digit=0,9 do
    UI:SetText(self.valueLabel,string.rep(tostring(digit),3).."%")
    width=math.max(width,math.ceil(self.valueLabel:GetStringWidth())+6)
   end
   UI:SetText(self.valueLabel,text);self.valueLabel:SetWidth(width)
   self:ClearAllPoints();self:SetPoint("RIGHT",-24-width,0)
   self:SetWidth(math.max(60,controlWidth-12-width))
  end
  control:LayoutValueWidth()
 elseif row[4]=="binding" then
  control=C.Button(holder,A.L.bindingChange,controlWidth,function() P:BeginBindingCapture() end);C.SetPoint(control,"RIGHT",control:GetParent(),"RIGHT","settingsControlRightX",0)
  holder:HookScript("OnHide",function() if P.bindingCapture==holder then P:CancelBindingCapture(true) end end)
 elseif row[4]=="action" then
  control=C.Button(holder,S("重置位置","Reset position"),controlWidth,function() A.Appearance:SaveFloatingPosition(false) end);C.SetPoint(control,"RIGHT",control:GetParent(),"RIGHT","settingsControlRightX",0)
 elseif row[4] then
  control=C.Choice(holder,controlWidth,function() return type(row[4])=="function" and row[4]() or row[4] end,function(value) A:SetSetting(row[1],value) end);C.ApplyStyle(control,{height="settingsControlHeight"});C.SetPoint(control,"RIGHT",control:GetParent(),"RIGHT","settingsControlRightX",0)
 else
  control=C.Check(holder,"",function(value) A:SetSetting(row[1],value);P:Sync() end)
  control.track:ClearAllPoints();C.SetPoint(control.track,"RIGHT",control.track:GetParent(),"RIGHT","settingsControlTrackRightX",0);control.label:ClearAllPoints();C.SetPoint(control.label,"RIGHT",control.track,"LEFT","settingsControlLabelRightX",0);C.SetFont(control.label,"font14");control:SetPoint("RIGHT",0,0)
  control:HookScript("OnEnter",function(button) UI:Color(button.label,T.text) end)
  control:HookScript("OnLeave",function(button) UI:Color(button.label,T.muted) end)
  control:HookScript("OnHide",function(button) UI:Color(button.label,T.muted) end)
 end
 if row[4]=="binding" or row[4]=="action" then layoutRow.action=control end
 if row[4]~="action" then self.controls[row[1]]={widget=control,definition=row,help=help,frame=holder} end
end

function P:ShowBindingNotice(message,conflict)
 if not self.bindingNotice then
  local notice=C.Notice(self.main,BODY_WIDTH);C.SetPoint(notice,"TOPLEFT",notice:GetParent(),"TOPLEFT",T.settingsContentInset,"settingsNoticeTopleftY");notice.close:Hide()
  self.bindingNotice=notice
  self.cancelBinding=C.Button(notice,A.L.bindingCancel,T.settingsCancelBindingWidth,function() P:CancelBindingCapture() end);C.ApplyStyle(self.cancelBinding,{width="settingsCancelBindingWidth"});self.cancelBinding:SetHeight(T.settingsCancelBindingHeight);C.SetPoint(self.cancelBinding,"RIGHT",self.cancelBinding:GetParent(),"RIGHT","settingsCancelBindingRightX",0)
  self.overwriteBinding=C.Button(notice,S("覆盖","Overwrite"),T.settingsOverwriteBindingWidth,function() P:TryBinding(P.pendingBindingKey,P.pendingBindingAction) end);C.ApplyStyle(self.overwriteBinding,{width="settingsOverwriteBindingWidth"});self.overwriteBinding:SetHeight(T.settingsOverwriteBindingHeight);C.SetPoint(self.overwriteBinding,"RIGHT",self.cancelBinding,"LEFT","settingsOverwriteBindingRightX",0)
 end
 self.overwriteBinding:SetShown(conflict==true)
 self.bindingNotice:SetMessage(message,conflict and 216 or 96)
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
 local offset=self.bindingNotice and self.bindingNotice:IsShown() and self.bindingNotice:GetHeight()+12 or 0
 for key,panel in pairs(self.panels) do
  UI.Motion:FinishPlacement(panel)
  panel.layoutTop=(key=="blocks" and T.settingsContentInset+self.heading:GetHeight()+12 or 80)+offset
  panel:ClearAllPoints();panel:SetPoint("TOPLEFT",self.main,"TOPLEFT",T.settingsContentInset,-panel.layoutTop);panel:SetHeight((self.layoutHeight or T.contentHeight)-panel.layoutTop-40)
  local top=0
  for _,row in ipairs(panel.rows or {}) do
   if row.action then row.action:SetWidth(math.ceil(row.action.label:GetStringWidth())+32) end
   local height=math.max(88,row.label:GetStringHeight()+32,row.help:GetStringHeight()+32)
   row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-top);row.frame:SetHeight(height);top=top+height
  end
  panel.nextRowY=top
 end
 self.reloadLanguage:ClearAllPoints();self.reloadLanguage:SetPoint("TOPRIGHT",0,-self.panels.interface.nextRowY-16)
end
function P:LayoutSize(width,height)
 self.layoutHeight=height;BODY_WIDTH=width-T.settingsMainX-T.settingsContentInset*2-12
 self.rail:SetHeight(height);self.main:SetSize(width-T.settingsMainX,height)
 local content=BODY_WIDTH-24-220-48;local labelWidth=content*.4;local helpWidth=content-labelWidth
 for _,panel in pairs(self.panels) do
  panel:SetWidth(BODY_WIDTH)
  for _,row in ipairs(panel.rows or {}) do
   row.frame:SetWidth(BODY_WIDTH);row.label:SetWidth(labelWidth);row.help:SetWidth(helpWidth)
   row.help:SetPoint("LEFT",36+labelWidth,0)
  end
 end
 self.aboutHeader:SetWidth(BODY_WIDTH);self.aboutValues.name:SetWidth(BODY_WIDTH-84)
 self.otherAddonsHeading:SetWidth(BODY_WIDTH-24)
 for _,row in ipairs(self.otherAddons) do row.frame:SetWidth(BODY_WIDTH);row.title:SetWidth(BODY_WIDTH-84);row.summary:SetWidth(BODY_WIDTH-96) end
 if self.bindingNotice then self.bindingNotice:SetWidth(BODY_WIDTH) end
 self:LayoutRows()
 if self.blocksList then
  self.blocksHelp:SetWidth(BODY_WIDTH);self.blocksEmpty:SetWidth(BODY_WIDTH);self.blocksList:SetWidth(BODY_WIDTH+12);self:LayoutBlocks()
 end
 if self.section=="about" then self:RefreshAbout() end
end
function P:SelectSection(key)
 local changed=self.section~=key
 if changed then self:CancelBindingCapture(true);self:StopBlocks() end
 for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end
 self.section=key;for id,panel in pairs(self.panels) do panel:SetShown(id==key);self.nav[id]:SetActive(id==key);UI:Color(self.nav[id].label,id==key and T.text or T.muted) end
 for _,entry in ipairs(sections) do if entry[1]==key then UI:SetText(self.heading,entry[2]);break end end
 if key=="blocks" then self:EnterBlocks() end
 self:Sync()
 if changed then UI.Motion:Reveal(self.panels[key],"TOPLEFT",self.main,"TOPLEFT",T.settingsContentInset,-self.panels[key].layoutTop,4,0,.14) end
end
function P:LayoutAppearance(width,height)
 self:LayoutSize(width,height)
 self.rail:SetWidth(T.settingsSidebarWidth);self.main:SetPoint("TOPLEFT",T.settingsMainX,0)
 self:LayoutRows()
 if self.blocksHeader then
  self.blocksHeader:Layout(self.blocksList:GetWidth()-C.listRightInset)
  self.blocksList:Refresh(true)
 end
end

function P:Sync()
 for key,entry in pairs(self.controls) do
  local c,row=entry.widget,entry.definition
  local value=A:GetSetting(key)
  if row[4]=="binding" then
   local text=self.bindingCapture and A.L.bindingListen or A.L.bindingCurrent:format(A.Bindings:Text())
   local conflict=not A.Bindings:Keys() and A.Bindings:Conflict(A.Bindings.defaultKey)
   if not self.bindingCapture and conflict then text=text.."\n"..A.L.bindingDefaultConflict:format(GetBindingName(conflict)) end
   UI:SetText(entry.help,text)
   UI:SetText(c.label,self.bindingCapture and S("按下新按键…","Press a key…") or A.L.bindingChange)
  elseif row[4]=="range" then c:LayoutValueWidth();if not c:IsDragging() then c:SetValue(value);UI:SetText(c.valueLabel,value.."%") end
  elseif row[4] then local label;local choices=type(row[4])=="function" and row[4]() or row[4];for _,choice in ipairs(choices) do if choice.value==value then label=choice.label;break end end;c:SetValue(value,label)
  else c:SetValue(value==true);UI:SetText(c.label,value and S("已开启","On") or S("已关闭","Off"));c:SetWidth(math.ceil(c.label:GetStringWidth())+c.track:GetWidth()+36);UI:Color(c.label,c._inside and T.text or T.muted) end
 end
 local floatingScale=self.controls.floatingScale.widget
 local scaleAvailable=not A:GetSetting("floatingCompatibility")
 floatingScale.slider:EnableMouse(scaleAvailable)
 floatingScale.progress:SetShown(scaleAvailable)
 floatingScale.thumb:SetVertexColor(unpack(scaleAvailable and T.accent or T.disabled))
 UI:Color(floatingScale.valueLabel,scaleAvailable and T.muted or T.disabled)
 self.reloadLanguage:SetShown(A:NeedsLanguageReload())
 self:LayoutRows()
 if self.section=="about" then self:RefreshAbout() end
 if self.section=="blocks" then self:RefreshBlocks() end
end
function P:Enter(context) self.frame:RegisterEvent("UPDATE_BINDINGS");self:SelectSection(context and context.section or self.section) end
function P:Leave()
 self:StopBlocks()
 self.frame:UnregisterEvent("UPDATE_BINDINGS")
 self.aboutClicks=0;self:HideDedicationToast()
 self.controls.uiScale.widget:FinishDrag(false)
 self:CancelBindingCapture(true)
 for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end
end
