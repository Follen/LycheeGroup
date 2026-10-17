-- One Settings navigation serves account preferences and addon information.
local A=_G.LycheeGroup
local UI=A.UI
local C,T,L=UI.C,UI.Theme,UI.L
local P={section="browse"};UI.pages.settings=P
local zh=GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
local sections={{"browse",S("队伍浏览","Group browsing")},{"notes",S("笔记与提醒","Notes and reminders")},{"floating",S("悬浮窗","Floating window")},{"interface",S("界面与提示","Interface")},{"about",L.about}}
local types={{value="positive",label=S("推荐","Recommended")},{value="neutral",label=S("中性","Neutral")},{value="caution",label=S("拉黑","Blocked")}}
local definitions={
 browse={
 {"defaultSort",S("默认排序","Default sorting"),S("进入其他活动分类时采用的排序。","Sorting used when entering another activity category."),{{value="newest",label=L.newest},{value="rating",label=L.leaderRating},{value="itemLevel",label=L.requiredItemLevel},{value="members",label=L.members}}},
 {"rememberFilters",S("记住各分类的筛选","Remember category filters"),S("切换活动后恢复筛选条件；赛季分类默认查看全部活动。","Restore filters for each category; seasonal categories start with all activities.")},
 {"relations",S("好友与公会标记","Friend and guild markers"),S("在队伍、申请者和成员提示中显示关系。","Show relationships in group, applicant and player details.")},
 {"noteMarks",S("荔枝笔记标记","Player note markers"),S("分别显示推荐、中性和拉黑记录；包含队伍成员。","Show recommendation, neutral and block markers, including group members.")}},
 notes={{"defaultNote",S("新记录的默认类型","Default note type"),S("每次记笔记时仍可选择其他类型。","Choose a different type whenever you record a player."),types},
 {"reminders",S("组队与邀请提醒","Group and invite reminders"),S("收到邀请、邀请玩家或再次组队时，提示符合范围的记录。","Show matching player notes when receiving an invite, inviting a player or grouping again."),{{value="all",label=S("全部记录","All notes")},{value="positive",label=S("仅推荐","Recommended only")},{value="caution",label=S("仅拉黑","Blocked only")},{value="off",label=S("不提醒","Off")}}},
 {"history",S("记录大秘境历史队友","Record Mythic+ teammates"),S("完成后保留活动与成员，便于回顾和补充笔记。","Keep completed runs and teammates for reviewing and adding notes.")}},
 floating={{"floating",S("显示悬浮窗","Show floating window"),S("查看申请与招募状态，关闭主窗口后仍然显示。","View active applications and recruitment while the main window is closed.")},
 {"floatingLocked",S("锁定位置","Lock position"),S("锁定后不能拖动，查看状态和点击入口不受影响。","Lock movement while keeping the status and shortcuts active.")},
 {"floatingScale",S("悬浮窗缩放","Floating window scale"),S("单独调整悬浮窗大小，不影响主窗口。","Adjust the floating window independently."),"range"}},
 interface={{"nativeLFGEntry",S("接管原生组队眼睛","Use the native LFG eye"),S("点击小地图组队眼睛打开荔枝组队；右键仍显示原生队列菜单。","Open Lychee LFG from the minimap eye; right-click keeps the native queue menu.")},
 {"reduceMotion",L.reduceMotion,S("关闭开窗位移、Logo 动作和局部过渡。","Disable window movement, logo animation and local transitions.")},
 {"raidMembers",S("团本成员列表","Raid members"),S("控制团本悬停提示中何时展开成员。","Choose when raid tooltips expand the member list."),{{value="shift",label=S("按 Shift 切换","Press Shift to toggle")},{value="always",label=S("始终展开","Always expand")}}},
 {"font",S("界面字体","Interface font"),S("选择游戏字体或已安装的共享字体，立即生效。","Choose a game or installed shared font. Changes apply immediately."),function() return A.Fonts:Choices() end},
 {"minimap",S("显示小地图按钮","Show minimap button"),S("左键开关主窗口，右键打开设置；拖动调整位置。","Left-click toggles the window; right-click opens settings. Drag to reposition.")}}}
local RAIL, MAIN_X, PAD = 208, 224, 24
local BODY_WIDTH = T.contentWidth - MAIN_X - PAD*2 - 12
function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(RAIL,T.contentHeight);rail:SetPoint("TOPLEFT")
 self.nav={};for i,entry in ipairs(sections) do
  local b=C.Navigation(rail,entry[2],RAIL,function() P:SelectSection(entry[1]) end);b.fill:SetRadius(8);b.hover:SetRadius(8);b:SetPoint("TOPLEFT",0,-12-(i-1)*52);b:SetHeight(48);b.label:SetFont(T.font,14,"");b.label:ClearAllPoints();b.label:SetPoint("LEFT",16,0);b.label:SetWidth(176)
  self.nav[entry[1]]=b
 end
 local main=CreateFrame("Frame",nil,root);main:SetSize(T.contentWidth-MAIN_X,T.contentHeight);main:SetPoint("TOPLEFT",MAIN_X,0);C.Panel(main,T.surfaceLow,24);self.main=main
 self.heading=C.Text(main,"",24);self.heading:SetPoint("TOPLEFT",PAD,-PAD);C.SetLineHeight(self.heading,32,true)
 self.back=C.Button(main,L.back,90,function() A:Open(UI.mainPage or "find") end);self.back:SetWidth(self.back.label:GetStringWidth()+58);self.back:SetPoint("TOPRIGHT",-PAD,-PAD)
 self.back.label:ClearAllPoints();self.back.label:SetPoint("LEFT",40,0);C.Glyph(self.back,"arrow",16):SetPoint("LEFT",16,0)
 self.panels={};self.controls={}
 for _,entry in ipairs(sections) do
  local panel=CreateFrame("Frame",nil,main);panel:SetSize(BODY_WIDTH,T.contentHeight-120);panel:SetPoint("TOPLEFT",PAD,-80);self.panels[entry[1]]=panel
  for i,row in ipairs(definitions[entry[1]] or {}) do self:BuildRow(panel,row,i) end
 end
 local reset={"resetPosition",S("悬浮窗位置","Floating window position"),S("未锁定时拖动荔枝标志，可放在屏幕内任意位置。","Drag the lychee logo to position the window when unlocked."),"action"}
 self:BuildRow(self.panels.floating,reset,4)
 self:BuildAbout(self.panels.about)
end
function P:BuildAbout(parent)
 local header=CreateFrame("Frame",nil,parent);header:SetSize(BODY_WIDTH,80);header:SetPoint("TOPLEFT");UI.drag:AddHandle(header)
 local logo=C.Icon(header,44);logo:SetTexture(T.media.."lychee-logo.tga");logo:SetPoint("TOPLEFT",12,-4)
 self.aboutValues={}
 local name=C.Text(header,"",18,T.text,BODY_WIDTH-84);C.SetLineHeight(name,24,true);name:SetWordWrap(false);name:SetPoint("TOPLEFT",72,-4);self.aboutValues.name=name
 local versionLabel=C.Text(header,L.addonVersion,14,T.muted);C.SetLineHeight(versionLabel,20,true);versionLabel:SetPoint("TOPLEFT",72,-40)
 local version=C.Text(header,"",14,T.text,160);C.SetLineHeight(version,20,true);version:SetWordWrap(false);version:SetPoint("TOPLEFT",versionLabel,"TOPRIGHT",8,0);self.aboutValues.version=version
 local authorLabel=C.Text(header,L.addonAuthor,14,T.muted);C.SetLineHeight(authorLabel,20,true);authorLabel:SetPoint("TOPLEFT",version,"TOPRIGHT",24,0)
 local author=C.Text(header,"",14,T.text);C.SetLineHeight(author,20,true);author:SetWordWrap(false);author:SetPoint("TOPLEFT",authorLabel,"TOPRIGHT",8,0);author:SetPoint("TOPRIGHT",header,"TOPRIGHT",-12,-40);self.aboutValues.author=author
 self.otherAddonsHeading=C.Text(parent,L.otherAddons,14,T.muted,BODY_WIDTH-24);C.SetLineHeight(self.otherAddonsHeading,20,true);self.otherAddonsHeading:SetPoint("TOPLEFT",12,-96)
 local media="Interface\\AddOns\\LycheeGroup_UI\\Media\\"
 local entries={
  {name=L.lycheeLauncher,summary=L.lycheeLauncherHelp,icon=media.."about-launcher.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJKkdJtw8gt"},{L.neteaseDD,"https://url.cc.163.com/HoH0Od"}}},
  {name=L.lycheeTalent,summary=L.lycheeTalentHelp,icon=media.."about-talent.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJu72Mjcmed"},{L.neteaseDD,"https://url.cc.163.com/w64q1s"}}},
 }
 self.otherAddons={}
 for index,entry in ipairs(entries) do
  local holder=CreateFrame("Frame",nil,parent);holder:SetSize(BODY_WIDTH,124);UI.drag:AddHandle(holder)
  C.Panel(holder,T.rowAlternate,12):SetShown(index%2==0)
  local icon=C.Icon(holder,44);icon:SetTexture(entry.icon);icon:SetPoint("TOPLEFT",12,-12)
  local title=C.Text(holder,entry.name,18,T.text,BODY_WIDTH-84);C.SetLineHeight(title,24,true);title:SetPoint("TOPLEFT",72,-12)
  local summary=C.Text(holder,entry.summary,14,T.muted,BODY_WIDTH-96);C.SetLineHeight(summary,20);summary:SetWordWrap(true);summary:SetPoint("TOPLEFT",72,-44)
  local row={frame=holder,icon=icon,title=title,summary=summary,links={}}
  for i,link in ipairs(entry.links) do
   local url,identity=link[2],entry.name.." · "..link[1]
   local button=C.Button(holder,link[1],120,function() UI:CopyText(L.copyDownloadLink,url,nil,identity,L.downloadLink) end);button:SetHeight(32);button:SetPoint("BOTTOMLEFT",72+(i-1)*132,12);button:SetSurfaceColors(T.surfaceContainer,T.surfaceHighest)
   row.links[i]=button
  end
  self.otherAddons[index]=row
 end
end
function P:RefreshAbout()
 for key,field in pairs({name="Title",version="Version",author="Author"}) do
  local text=C_AddOns.GetAddOnMetadata("LycheeGroup",field)
  UI:SetText(self.aboutValues[key],text and text~="" and text or key=="name" and L.reminder or L.metadataMissing)
 end
 local top=128
 for _,row in ipairs(self.otherAddons) do
  local height=math.max(124,row.summary:GetStringHeight()+104)
  row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-top);row.frame:SetHeight(height);top=top+height+12
 end
end
function P:BuildRow(parent,row,index)
 local holder=CreateFrame("Frame",nil,parent);holder:SetSize(BODY_WIDTH,80);holder:SetPoint("TOPLEFT",0,-(parent.nextRowY or 0));holder:EnableMouse(true)
 UI.drag:AddHandle(holder)
 local fill=C.Panel(holder,T.rowAlternate,12);fill:SetShown(index%2==0)
 local controlWidth=184;local content=BODY_WIDTH-24-controlWidth-32;local labelWidth=content/2.3;local helpWidth=content-labelWidth
 local label=C.Text(holder,row[2],14,T.text,labelWidth);label:SetPoint("LEFT",12,0);label:SetWordWrap(true);C.SetLineHeight(label,20)
 local help=C.Text(holder,row[3],14,T.muted,helpWidth);help:SetPoint("LEFT",28+labelWidth,0);help:SetWordWrap(true);C.SetLineHeight(help,20)
 local rowHeight=math.max(80,label:GetStringHeight()+32,help:GetStringHeight()+32);holder:SetHeight(rowHeight);parent.nextRowY=(parent.nextRowY or 0)+rowHeight
 parent.rows=parent.rows or {};parent.rows[#parent.rows+1]={frame=holder,label=label,help=help}
 local control
 if row[4]=="range" then
  control=C.Slider(holder,132,50,150,5,function(value)
   value=math.floor(value/5+.5)*5;UI:SetText(P.controls[row[1]].widget.valueLabel,value.."%");if not P.syncing then A:SetSetting(row[1],value) end
  end)
  control.valueLabel=C.Text(control,"",14,T.muted,40);control.valueLabel:SetPoint("LEFT",control,"RIGHT",12,0);control.valueLabel:SetJustifyH("RIGHT")
  control:SetPoint("RIGHT",-64,0)
 elseif row[4]=="action" then
  control=C.Button(holder,S("重置位置","Reset position"),144,function() A.db.floatingPosition=nil;if A.Floating then A.Floating:ResetPosition() end end);control:SetPoint("RIGHT",-12,0)
 elseif row[4] then
  control=C.Choice(holder,controlWidth,function() return type(row[4])=="function" and row[4]() or row[4] end,function(value) A:SetSetting(row[1],value) end);control:SetHeight(44);control:SetPoint("RIGHT",-12,0)
 else
  control=C.Check(holder,"",function(value) A:SetSetting(row[1],value);P:Sync() end)
  control.track:ClearAllPoints();control.track:SetPoint("RIGHT",-12,0);control.label:ClearAllPoints();control.label:SetPoint("RIGHT",control.track,"LEFT",-12,0);control.label:SetFont(T.font,14,"");control:SetPoint("RIGHT",0,0)
  control.settingsSwitch=true
  control:HookScript("OnEnter",function(button) UI:Color(button.label,T.text) end)
  control:HookScript("OnLeave",function(button) UI:Color(button.label,T.muted) end)
  control:HookScript("OnHide",function(button) UI:Color(button.label,T.muted) end)
 end
 if row[4]~="action" then self.controls[row[1]]={widget=control,definition=row} end
end
function P:LayoutRows()
 self.back:SetWidth(self.back.label:GetStringWidth()+58)
 for _,panel in pairs(self.panels) do
  local top=0
  for _,row in ipairs(panel.rows or {}) do
   local height=math.max(80,row.label:GetStringHeight()+32,row.help:GetStringHeight()+32)
   row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-top);row.frame:SetHeight(height);top=top+height
  end
  panel.nextRowY=top
 end
end
function P:SelectSection(key)
 local changed=self.section~=key
 for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end
 self.section=key;for id,panel in pairs(self.panels) do panel:SetShown(id==key);self.nav[id]:SetActive(id==key);self.nav[id].mark:SetShown(id==key);UI:Color(self.nav[id].label,id==key and T.text or T.muted) end
 for _,entry in ipairs(sections) do if entry[1]==key then UI:SetText(self.heading,entry[2]);break end end
 self:Sync()
 if key=="about" then self:RefreshAbout() end
 if changed then UI.Motion:Reveal(self.panels[key],"TOPLEFT",self.main,"TOPLEFT",PAD,-80,4,0,.14) end
end
function P:Sync()
 self.syncing=true
 for key,entry in pairs(self.controls) do
  local c,row=entry.widget,entry.definition
  if row[4]=="range" then c:SetValue(A.db[key]);UI:SetText(c.valueLabel,A.db[key].."%")
  elseif row[4] then local label;local choices=type(row[4])=="function" and row[4]() or row[4];for _,choice in ipairs(choices) do if choice.value==A.db[key] then label=choice.label;break end end;c:SetValue(A.db[key],label)
  else c:SetValue(A.db[key]==true);UI:SetText(c.label,A.db[key] and S("已开启","On") or S("已关闭","Off"));c:SetWidth(math.ceil(c.label:GetStringWidth())+c.track:GetWidth()+36);UI:Color(c.label,c._inside and T.text or T.muted) end
 end
 self.syncing=nil
end
function P:Enter(context) self:SelectSection(context and context.section or self.section) end
function P:Leave() for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end end
