-- One Settings navigation serves account and character preferences and addon information.
local A=_G.LycheeGroup
local UI=A.UI
local C,T,L=UI.C,UI.Theme,UI.L
local P={section="general"};UI.pages.settings=P
local zh=A:GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
local sections={{"general",S("入口与快捷键","Access & shortcuts")},{"interface",S("界面与外观","Appearance")},{"browse",S("队伍与成员","Groups & members")},{"notes",S("笔记与提醒","Notes and reminders")},{"floating",S("悬浮窗","Floating window")},{"about",L.about}}
local types={{value="positive",label=S("推荐","Positive")},{value="neutral",label=S("中性","Neutral")},{value="caution",label=S("拉黑","Blocked")}}
local definitions={
 general={{"toggleBinding",A.L.bindingToggle,"","binding"},
 {"minimap",S("显示小地图按钮","Show minimap button"),S("左键开关主窗口，右键打开设置；拖动调整位置。","Left-click toggles the window; right-click opens settings. Drag to reposition.")},
 {"nativeLFGEntry",S("隐藏原生组队眼睛","Hide the native LFG eye"),S("隐藏原生队列入口，保留申请提示音；关闭后恢复原生入口。","Hide the native queue button while keeping applicant sounds; turn this off to restore the native button.")}},
 interface={{"language",S("界面语言","Interface language"),S("仅改变插件文字，重载界面后生效。","Change addon text. Reload the UI to apply."),{{value="auto",label=S("跟随游戏","Game language")},{value="zhCN",label="简体中文"},{value="enUS",label="English"}}},
 {"uiScale",S("主窗口缩放","Main window scale"),S("等比调整整个主窗口。","Scale the entire main window proportionally."),"range",75,125},
 {"font",S("界面字体","Interface font"),S("默认使用荔枝字体，也可选择游戏或共享字体，立即生效。","Use LycheeFont, a game font or an installed shared font. Changes apply immediately."),function() return A.Fonts:Choices() end},
 {"reduceMotion",L.reduceMotion,S("关闭开窗位移、Logo 动作和局部过渡。","Disable window movement, logo animation and local transitions.")}},
 browse={
 {"defaultSort",S("默认排序","Default sorting"),S("本角色进入其他活动分类时采用的排序。","Default sorting for this character's activity categories."),{{value="newest",label=L.newest},{value="rating",label=L.leaderRating},{value="itemLevel",label=L.requiredItemLevel},{value="members",label=L.members}}},
 {"rememberFilters",S("记住本角色的筛选","Remember character filters"),S("本角色独立保存各分类筛选。","Save category filters for this character.")},
 {"relations",S("好友与公会标记","Friend and guild markers"),S("在队伍、申请者和成员提示中显示关系。","Show relationships in group, applicant and player details.")},
 {"raidMembers",S("团本成员列表","Raid members"),S("控制团本悬停提示中何时展开成员。","Choose when raid tooltips expand the member list."),{{value="shift",label=S("按 Shift 切换","Press Shift to toggle")},{value="alt",label=S("按 Alt 切换","Press Alt to toggle")},{value="ctrl",label=S("按 Ctrl 切换","Press Ctrl to toggle")},{value="always",label=S("始终展开","Always expand")}}}},
 notes={{"defaultNote",S("新记录的默认类型","Default note type"),S("每次记笔记时仍可选择其他类型。","Choose a different type whenever you record a player."),types},
 {"noteMarks",S("荔枝笔记标记","Player note markers"),S("分别显示推荐、中性和拉黑记录；包含队伍成员。","Show recommendation, neutral and block markers, including group members.")},
 {"reminders",S("组队与邀请提醒","Group and invite reminders"),S("收到邀请、邀请玩家或再次组队时，提示符合范围的记录。","Show matching player notes when receiving an invite, inviting a player or grouping again."),{{value="all",label=S("全部记录","All notes")},{value="positive",label=S("仅推荐","Recommended only")},{value="caution",label=S("仅拉黑","Blocked only")},{value="off",label=S("不提醒","Off")}}},
 {"history",S("记录大秘境历史队友","Record Mythic+ teammates"),S("完成后保留活动与成员，便于回顾和补充笔记。","Keep completed runs and teammates for reviewing and adding notes.")}},
 floating={{"floating",S("显示悬浮窗","Show floating window"),S("查看申请与招募状态，关闭主窗口后仍然显示。","View active applications and recruitment while the main window is closed.")},
 {"floatingCompatibility",S("悬浮窗兼容","Floating window integration"),S("自动接入第三方UI配置的视觉兼容","Automatically adapt the appearance to third-party UI configurations.")},
 {"floatingScale",S("悬浮窗缩放","Floating window scale"),S("调整悬浮窗大小。","Adjust the floating window size."),"range"},
 {"floatingLocked",S("锁定位置","Lock position"),S("锁定后不能拖动，查看状态和点击入口不受影响。","Lock movement while keeping the status and shortcuts active.")}}}
local RAIL, MAIN_X, PAD = 208, 224, 24
local BODY_WIDTH = T.contentWidth - MAIN_X - PAD*2 - 12
function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 root:SetScript("OnEvent",function(_,event)
  if event=="UPDATE_BINDINGS" then P:Sync()
  elseif event=="PLAYER_REGEN_DISABLED" then
   P:CancelBindingCapture(true);P:ShowBindingNotice(A.L.bindingCombat);P:Sync()
  end
 end)
 root:HookScript("OnHide",function() P:CancelBindingCapture(true) end)
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(RAIL,T.contentHeight);rail:SetPoint("TOPLEFT")
 self.nav={};for i,entry in ipairs(sections) do
  local b=C.Navigation(rail,entry[2],RAIL,function() P:SelectSection(entry[1]) end,nil,{radius=8,fontSize=14});b:SetPoint("TOPLEFT",0,-12-(i-1)*52);b.label:SetWidth(176)
  self.nav[entry[1]]=b
 end
 local main=CreateFrame("Frame",nil,root);main:SetSize(T.contentWidth-MAIN_X,T.contentHeight);main:SetPoint("TOPLEFT",MAIN_X,0);C.Panel(main,T.surfaceLow,24);self.main=main
 self.heading=C.Text(main,"",24);self.heading:SetPoint("TOPLEFT",PAD,-PAD);C.SetLineHeight(self.heading,32,true)
 self.panels={};self.controls={}
 for _,entry in ipairs(sections) do
  local panel=CreateFrame("Frame",nil,main);panel:SetSize(BODY_WIDTH,T.contentHeight-120);panel:SetPoint("TOPLEFT",PAD,-80);self.panels[entry[1]]=panel
  for i,row in ipairs(definitions[entry[1]] or {}) do self:BuildRow(panel,row,i) end
 end
 local reset={"resetPosition",S("悬浮窗位置","Floating window position"),S("未锁定时拖动荔枝标志，可放在屏幕内任意位置。","Drag the lychee logo to position the window when unlocked."),"action"}
 self:BuildRow(self.panels.floating,reset,#definitions.floating+1)
 self.reloadLanguage=C.Button(self.panels.interface,S("重载界面","Reload UI"),220,function() C_UI.Reload() end)
 self:BuildAbout(self.panels.about)
end
function P:BuildAbout(parent)
 local header=CreateFrame("Frame",nil,parent);header:SetSize(BODY_WIDTH,80);header:SetPoint("TOPLEFT");UI.drag:AddHandle(header)
 local logo=C.Icon(header,44);logo:SetTexture(T.media.."lychee-logo.tga");logo:SetPoint("TOPLEFT",12,-4)
 self.aboutValues={}
 local name=C.Text(header,"",18,T.text,BODY_WIDTH-84);C.SetLineHeight(name,24,true);name:SetWordWrap(false);name:SetPoint("TOPLEFT",72,-4);self.aboutValues.name=name
 local versionLabel=C.Text(header,L.addonVersion,14,T.muted);C.SetLineHeight(versionLabel,20,true);versionLabel:SetPoint("TOPLEFT",72,-44)
 local version=C.Text(header,"",14,T.text,160);C.SetLineHeight(version,20,true);version:SetWordWrap(false);version:SetPoint("TOPLEFT",versionLabel,"TOPRIGHT",8,0);self.aboutValues.version=version
 local authorLabel=C.Text(header,L.addonAuthor,14,T.muted);C.SetLineHeight(authorLabel,20,true);authorLabel:SetPoint("TOPLEFT",version,"TOPRIGHT",24,0)
 local author=C.Text(header,"",14,T.text);C.SetLineHeight(author,20,true);author:SetWordWrap(false);author:SetPoint("TOPLEFT",authorLabel,"TOPRIGHT",8,0);author:SetPoint("TOPRIGHT",header,"TOPRIGHT",-12,-44);self.aboutValues.author=author
 self.otherAddonsHeading=C.Text(parent,L.otherAddons,14,T.muted,BODY_WIDTH-24);C.SetLineHeight(self.otherAddonsHeading,20,true);self.otherAddonsHeading:SetPoint("TOPLEFT",12,-100)
 local media="Interface\\AddOns\\LycheeGroup_UI\\Media\\"
 local entries={
  {name=L.lycheeLauncher,summary=L.lycheeLauncherHelp,icon=media.."about-launcher.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJKkdJtw8gt"},{L.neteaseDD,"https://url.cc.163.com/HoH0Od"}}},
  {name=L.lycheeTalent,summary=L.lycheeTalentHelp,icon=media.."about-talent.tga",links={{L.newBeeBox,"https://www.wclbox.com/share/AJu72Mjcmed"},{L.neteaseDD,"https://url.cc.163.com/w64q1s"}}},
 }
 self.otherAddons={}
 for index,entry in ipairs(entries) do
  local holder=CreateFrame("Frame",nil,parent);holder:SetSize(BODY_WIDTH,148);UI.drag:AddHandle(holder)
  C.Panel(holder,T.rowAlternate,12):SetShown(index%2==0)
  local icon=C.Icon(holder,44);icon:SetTexture(entry.icon);icon:SetPoint("TOPLEFT",12,-12)
  local title=C.Text(holder,entry.name,18,T.text,BODY_WIDTH-84);C.SetLineHeight(title,24,true);title:SetPoint("TOPLEFT",72,-12)
  local summary=C.Text(holder,entry.summary,14,T.muted,BODY_WIDTH-96);C.SetLineHeight(summary,20);summary:SetWordWrap(true);summary:SetPoint("TOPLEFT",72,-48)
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
 local top=140
 for _,row in ipairs(self.otherAddons) do
  local height=math.max(148,row.summary:GetStringHeight()+104)
  row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-top);row.frame:SetHeight(height);top=top+height+12
  local left=72
  for _,button in ipairs(row.links) do
   local width=math.max(120,math.ceil(button.label:GetStringWidth())+32)
   button:SetWidth(width);button:ClearAllPoints();button:SetPoint("BOTTOMLEFT",left,12);left=left+width+12
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
 local holder=CreateFrame("Frame",nil,parent);holder:SetSize(BODY_WIDTH,88);holder:SetPoint("TOPLEFT",0,-(parent.nextRowY or 0));holder:EnableMouse(true)
 UI.drag:AddHandle(holder)
 local fill=C.Panel(holder,T.rowAlternate,12);fill:SetShown(index%2==0)
 local controlWidth=220;local content=BODY_WIDTH-24-controlWidth-48;local labelWidth=content*.4;local helpWidth=content-labelWidth
 local label=C.Text(holder,row[2],14,T.text,labelWidth);label:SetPoint("LEFT",12,0);label:SetWordWrap(true);C.SetLineHeight(label,20)
 local help=C.Text(holder,row[3],14,T.muted,helpWidth);help:SetPoint("LEFT",36+labelWidth,0);help:SetWordWrap(true);C.SetLineHeight(help,20)
 local rowHeight=math.max(88,label:GetStringHeight()+32,help:GetStringHeight()+32);holder:SetHeight(rowHeight);parent.nextRowY=(parent.nextRowY or 0)+rowHeight
 parent.rows=parent.rows or {};parent.rows[#parent.rows+1]={frame=holder,label=label,help=help}
 local control
 if row[4]=="range" then
  if row[1]=="uiScale" then control=WindowScaleControl(holder)
  else control=C.Slider(holder,156,row[5] or 50,row[6] or 150,5,function(value)
   value=math.floor(value/5+.5)*5
   local widget=P.controls[row[1]].widget
   UI:SetText(widget.valueLabel,value.."%")
   A:SetSetting(row[1],value)
  end) end
  control.valueLabel=C.Text(control,"",14,T.muted,52);control.valueLabel:SetPoint("LEFT",control,"RIGHT",12,0);control.valueLabel:SetJustifyH("RIGHT")
  control:SetPoint("RIGHT",-76,0)
 elseif row[4]=="binding" then
  control=C.Button(holder,A.L.bindingChange,controlWidth,function() P:BeginBindingCapture() end);control:SetPoint("RIGHT",-12,0)
  holder:HookScript("OnHide",function() if P.bindingCapture==holder then P:CancelBindingCapture(true) end end)
 elseif row[4]=="action" then
  control=C.Button(holder,S("重置位置","Reset position"),controlWidth,function() A.db.floatingPosition=nil;if A.Floating then A.Floating:ResetPosition() end end);control:SetPoint("RIGHT",-12,0)
 elseif row[4] then
  control=C.Choice(holder,controlWidth,function() return type(row[4])=="function" and row[4]() or row[4] end,function(value) A:SetSetting(row[1],value) end);control:SetHeight(44);control:SetPoint("RIGHT",-12,0)
 else
  control=C.Check(holder,"",function(value) A:SetSetting(row[1],value);P:Sync() end)
  control.track:ClearAllPoints();control.track:SetPoint("RIGHT",-12,0);control.label:ClearAllPoints();control.label:SetPoint("RIGHT",control.track,"LEFT",-12,0);C.SetFont(control.label,14);control:SetPoint("RIGHT",0,0)
  control:HookScript("OnEnter",function(button) UI:Color(button.label,T.text) end)
  control:HookScript("OnLeave",function(button) UI:Color(button.label,T.muted) end)
  control:HookScript("OnHide",function(button) UI:Color(button.label,T.muted) end)
 end
 if row[4]~="action" then self.controls[row[1]]={widget=control,definition=row,help=help,frame=holder} end
end

function P:ShowBindingNotice(message,conflict)
 if not self.bindingNotice then
  local notice=C.Notice(self.main,BODY_WIDTH);notice:SetPoint("TOPLEFT",PAD,-80);notice.close:Hide()
  self.bindingNotice=notice
  self.cancelBinding=C.Button(notice,A.L.bindingCancel,96,function() P:CancelBindingCapture() end);self.cancelBinding:SetHeight(32);self.cancelBinding:SetPoint("RIGHT",-12,0)
  self.overwriteBinding=C.Button(notice,S("覆盖","Overwrite"),112,function() P:TryBinding(P.pendingBindingKey,P.pendingBindingAction) end);self.overwriteBinding:SetHeight(32);self.overwriteBinding:SetPoint("RIGHT",self.cancelBinding,"LEFT",-8,0)
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
 for _,panel in pairs(self.panels) do
  UI.Motion:FinishPlacement(panel)
  panel:ClearAllPoints();panel:SetPoint("TOPLEFT",self.main,"TOPLEFT",PAD,-80-offset);panel:SetHeight(T.contentHeight-120-offset)
  local top=0
  for _,row in ipairs(panel.rows or {}) do
   local height=math.max(88,row.label:GetStringHeight()+32,row.help:GetStringHeight()+32)
   row.frame:ClearAllPoints();row.frame:SetPoint("TOPLEFT",0,-top);row.frame:SetHeight(height);top=top+height
  end
  panel.nextRowY=top
 end
 self.reloadLanguage:ClearAllPoints();self.reloadLanguage:SetPoint("TOPRIGHT",0,-self.panels.interface.nextRowY-16)
end
function P:SelectSection(key)
 local changed=self.section~=key
 if changed then self:CancelBindingCapture(true) end
 for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end
 self.section=key;for id,panel in pairs(self.panels) do panel:SetShown(id==key);self.nav[id]:SetActive(id==key);UI:Color(self.nav[id].label,id==key and T.text or T.muted) end
 for _,entry in ipairs(sections) do if entry[1]==key then UI:SetText(self.heading,entry[2]);break end end
 self:Sync()
 if changed then UI.Motion:Reveal(self.panels[key],"TOPLEFT",self.main,"TOPLEFT",PAD,-80,4,0,.14) end
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
  elseif row[4]=="range" then if not c:IsDragging() then c:SetValue(value);UI:SetText(c.valueLabel,value.."%") end
  elseif row[4] then local label;local choices=type(row[4])=="function" and row[4]() or row[4];for _,choice in ipairs(choices) do if choice.value==value then label=choice.label;break end end;c:SetValue(value,label)
  else c:SetValue(value==true);UI:SetText(c.label,value and S("已开启","On") or S("已关闭","Off"));c:SetWidth(math.ceil(c.label:GetStringWidth())+c.track:GetWidth()+36);UI:Color(c.label,c._inside and T.text or T.muted) end
 end
 local floatingScale=self.controls.floatingScale.widget
 local scaleAvailable=not A.db.floatingCompatibility
 floatingScale.slider:EnableMouse(scaleAvailable)
 floatingScale.progress:SetShown(scaleAvailable)
 floatingScale.thumb:SetVertexColor(unpack(scaleAvailable and T.accent or T.disabled))
 UI:Color(floatingScale.valueLabel,scaleAvailable and T.muted or T.disabled)
 self.reloadLanguage:SetShown(A:NeedsLanguageReload())
 self:LayoutRows()
 if self.section=="about" then self:RefreshAbout() end
end
function P:Enter(context) self.frame:RegisterEvent("UPDATE_BINDINGS");self:SelectSection(context and context.section or self.section) end
function P:Leave()
 self.frame:UnregisterEvent("UPDATE_BINDINGS")
 self.controls.uiScale.widget:FinishDrag(false)
 self:CancelBindingCapture(true)
 for _,panel in pairs(self.panels) do UI.Motion:FinishPlacement(panel) end
end
