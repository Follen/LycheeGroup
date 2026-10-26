-- Offline Settings information architecture, live controls and layout.
-- Run: lua tests/test_settings_sections.lua
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b,message) check(math.abs(a-b)<.001,message) end
local function position(region,root)
 if region==root then return 0,0 end
 local point={region:GetPoint()};local relative,anchor,x,y
 if type(point[2])=="table" then relative,anchor,x,y=point[2],point[3],point[4] or 0,point[5] or 0
 else relative,anchor,x,y=region:GetParent(),point[1],point[2] or 0,point[3] or 0 end
 local function part(value,low,high) return value:find(low) and 0 or value:find(high) and 1 or .5 end
 local px,py=position(relative,root)
 return px+relative:GetWidth()*part(anchor,"LEFT","RIGHT")+x-region:GetWidth()*part(point[1],"LEFT","RIGHT"),py+relative:GetHeight()*part(anchor,"TOP","BOTTOM")-y-region:GetHeight()*part(point[1],"TOP","BOTTOM")
end
local sections={
 {"general","常规","General",{"language","toggleBinding","minimap","nativeLFGEntry","guide"}},
 {"interface","界面显示","Appearance",{"theme","font","fontScale","uiScale","reduceMotion"}},
 {"browse","寻求组队","Find groups",{"defaultSort","rememberFilters","showImportantFilters"}},
 {"memberIcons","成员显示","Member display",{"relations","raidMembers","memberIconShape","memberIconScale","memberClassBorder","memberLeaderMark"}},
 {"notes","笔记与提醒","Notes & reminders",{"defaultNote","noteMarks","reminders","history"}},
 {"blocks","屏蔽名单","Blocked leaders",{}},
 {"floating","悬浮窗","Floating window",{"floating","floatingCompatibility","floatingScale","floatingLocked","resetPosition"}},
 {"about","关于","About",{}},
 {"credits","鸣谢","Credits",{}},
}
local function layout(p,tag)
 local previous
 for _,section in ipairs(sections) do
  local key=section[1];local button=p.nav[key]
  local _,y=position(button,p.rail)
  if key=="credits" then
   near(y+button:GetHeight(),p.rail:GetHeight()-12,tag..": Credits does not stay at the bottom of the sidebar")
   check(y>=previous+16,tag..": Credits overlaps the ordinary settings categories")
  elseif previous then near(y,previous+4,tag..": navigation entries lose their four-unit gap") else near(y,12,tag..": first category moves away from the rail inset") end
  check(button:GetHeight()>=48 and button.label:GetHeight()>=button.label:GetStringHeight(),tag..": long category text is clipped")
  previous=y+button:GetHeight()
  check(previous<=p.rail:GetHeight(),tag..": a category falls below the smallest window")
  local panel=p.panels[key];local bottom=0
  for _,row in ipairs(panel.rows or {}) do
   local x,top=position(row.frame,panel)
   near(top,bottom,tag..": settings rows overlap or add a gap")
   check(row.frame:GetHeight()>=row.label:GetStringHeight()+32-.001,tag..": a setting title exceeds its row")
   check(row.frame:GetHeight()>=row.help:GetStringHeight()+32-.001,tag..": a setting description exceeds its row")
   check(row.label:GetWidth()>0 and row.help:GetWidth()>0,tag..": text columns collapse")
   local controlX=position(row.control,row.frame)
   local helpX=position(row.help,row.frame)
   check(helpX+row.help:GetWidth()+12<=controlX+.001,tag..": helper text collides with its control")
   bottom=top+row.frame:GetHeight()
  end
  if panel.rows then check(bottom<=panel:GetHeight()+.001,tag..": all rows must fit the minimum window in "..key) end
 end
 local bottom=0
 for _,row in ipairs(p.credits) do
  local _,y=position(row,p.panels.credits)
  local portraitX,portraitY=position(row.portrait,row)
  local nameX,nameY=position(row.name,row)
  check(y>=bottom and y+row:GetHeight()<=p.panels.credits:GetHeight(),tag..": a credit row is clipped or overlaps another contributor")
  check(portraitX>=16 and portraitY>=16 and portraitY+row.portrait:GetHeight()<=row:GetHeight()-16,tag..": a contributor portrait loses its padding")
  check(nameX>=portraitX+row.portrait:GetWidth()+24 and nameX+row.name:GetWidth()<=row:GetWidth()-16,tag..": a contributor name overlaps its portrait or panel edge")
  check(nameY>=0 and nameY+row.name:GetStringHeight()<=row:GetHeight(),tag..": a contributor name is clipped at this font size")
  local previousRight
  for _,button in ipairs(row.links) do
   local x,top=position(button,row)
   check(button:GetWidth()>=40 and button:GetHeight()>=40,tag..": a platform logo has too little click space")
   check(top>=nameY+row.name:GetHeight()+8-.001 and top+button:GetHeight()<=row:GetHeight()-16+.001,tag..": a platform action overlaps the name or row edge")
   check(x>=nameX and x+button:GetWidth()<=row:GetWidth()-16,tag..": platform actions are clipped")
   if previousRight then check(x>=previousRight+8,tag..": platform actions overlap") end
   previousRight=x+button:GetWidth()
  end
  local copy=row.linkCopy
  if copy and copy.clip:IsShown() then
   local hintX,hintY=position(copy.hint,copy.canvas)
   local closeX,closeY=position(copy.close,copy.canvas)
   local fieldX,fieldY=position(copy.field,copy.canvas)
   check(hintX+copy.hint:GetWidth()+12<=closeX+.001,tag..": inline copy guidance overlaps its close button")
   near(hintY+copy.hint:GetHeight()/2,closeY+copy.close:GetHeight()/2,tag..": inline copy header is not vertically aligned")
   check(fieldY>=math.max(hintY+copy.hint:GetHeight(),closeY+copy.close:GetHeight())+8-.001,tag..": link field is not below the guidance and close row")
   near(fieldX+position(copy.clip,row),nameX,tag..": link field is not aligned with the contributor content")
  end
  bottom=y+row:GetHeight()
 end
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,percent in ipairs({70,100,130}) do
  local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true,fontScale=percent})
  local a,u=f.A,f.U
  a:Open("settings",{section="general"});u:SetWindowSize(1,1)
  local p=u.pages.settings;local tag=locale.."/"..percent
  check(p.credits==nil,tag..": contributor portraits are created before opening Credits")
  local seen={};local count=0
  for _,section in ipairs(sections) do
   local key,rows=section[1],section[4];local panel=p.panels[key]
   check(p.nav[key].label:GetText()==section[locale=="zhCN" and 2 or 3],tag..": category name is unclear or misplaced")
   check(#(panel.rows or {})==#rows,tag..": category has unexpected settings: "..key)
   for index,setting in ipairs(rows) do
    local row=panel.rows[index]
    if setting=="resetPosition" or setting=="guide" then check(row.action~=nil and p.controls[setting]==nil,tag..": action stored as a preference: "..setting)
    else
     local control=p.controls[setting]
     check(control~=nil and control.frame==row.frame and control.frame:GetParent()==panel,tag..": setting appears in the wrong category or order: "..setting)
     check(not seen[setting],tag..": duplicate setting: "..setting);seen[setting]=true;count=count+1
    end
   end
   p:SelectSection(key)
   check(p.section==key and p.nav[key].active and p.heading:GetText()==p.nav[key].label:GetText(),tag..": an existing section shortcut no longer selects its category")
   for other,otherPanel in pairs(p.panels) do check(otherPanel:IsShown()==(other==key),tag..": a hidden category leaks content") end
  end
  local actual=0;for key in pairs(p.controls) do actual=actual+1;check(seen[key],tag..": unclassified setting: "..key) end
  check(actual==count and count==26,tag..": settings were lost during regrouping")
  check(p.rail:GetWidth()==208,tag..": categories change the sidebar width")
  check(#p.credits==2 and p.credits[1].name:GetText()=="@露露缇雅" and p.credits[2].name:GetText()=="@灵魂复苏",tag..": contributor names or order are incorrect")
  p.nav.general:Fire("OnClick","LeftButton");p.nav.credits:Fire("OnClick","LeftButton")
  check(p.section=="credits" and p.panels.credits:IsVisible(),tag..": the bottom navigation does not open Credits")
  local expectedLinks={
   {"https://space.bilibili.com/455259","https://v.douyin.com/U6Jk7GPitmk/"},
   {"https://space.bilibili.com/10420749?","https://v.douyin.com/UD4dIzYrhao/"},
  }
  for person,row in ipairs(p.credits) do
   check(#row.links==2,tag..": a contributor is missing a platform link")
   for platform,button in ipairs(row.links) do
    button:Fire("OnClick","LeftButton")
    local copy=row.linkCopy
    check(not u.activeModal and copy.field.box:GetText()==expectedLinks[person][platform],tag..": a platform logo opens the wrong link or a separate dialog")
    check(copy.clip:GetParent()==row,tag..": the copy field loses its contributor context")
    check(copy.field.box:HasFocus(),tag..": the copy link field does not receive focus")
    layout(p,tag.." with link expanded")
    copy.close:Fire("OnClick");check(not copy.field.box:HasFocus() and copy.field.box:GetText()=="",tag..": closing a platform link retains focus or stale text")
   end
  end
  layout(p,tag)
  a:SetSetting("fontScale",percent==130 and 70 or 130);u:SetWindowSize(1,1)
  layout(p,tag.." after live font change")
  a:SetSetting("fontScale",percent);u:SetWindowSize(1,1)
  layout(p,tag.." after restoring font size")
  u:Hide(true)
 end

 local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true})
 local a,u,s=f.A,f.U,f.S
 a:Open("settings",{section="general"})
 local p=u.pages.settings
 -- Preference controls still call the same setting entry point and save scope.
 -- The theme Choice uses Theme:Activate; its storage contract has its own suite.
 for _,section in ipairs(sections) do
  p:SelectSection(section[1])
  for _,key in ipairs(section[4]) do
   local entry=p.controls[key]
   if entry and key~="toggleBinding" and key~="theme" then
    local original=a:GetSetting(key);local definition=a.Configuration.definitions["settings."..key]
    local storage=definition.storage;local widget,row=entry.widget,entry.definition;local changed
    if not row[4] then widget:Fire("OnClick","LeftButton");changed=not original
    elseif row[4]=="range" then
     changed=original==(row[6] or 150) and original-5 or original+5
     if key=="floatingScale" then a:SetSetting("floatingCompatibility",false) end
     if key=="uiScale" then
      local mouse=IsMouseButtonDown;IsMouseButtonDown=function() return true end
      local track=widget.slider;s.cursorX=(track:GetLeft()+(changed-75)/50*track:GetWidth())*track:GetEffectiveScale()
      track:Fire("OnMouseDown","LeftButton");track:Fire("OnMouseUp","LeftButton");IsMouseButtonDown=mouse
     else widget.slider:SetValue(changed) end
    else
     local choices=type(row[4])=="function" and row[4]() or row[4]
     for _,choice in ipairs(choices) do if choice.value~=original then changed=choice.value;break end end
     f.Pick(widget,changed)
    end
    check(a:GetSetting(key)==changed,locale..": moved control writes a different setting: "..key)
    check(a.Configuration.definitions["settings."..key]==definition and definition.storage==storage,locale..": regrouping changes setting scope: "..key)
    a:SetSetting(key,original)
   end
  end
 end
 a:SetSetting("reduceMotion",true);p:SelectSection("general")
 p.controls.toggleBinding.widget:Fire("OnClick","LeftButton")
 check(p.bindingCapture==p.controls.toggleBinding.frame,locale..": the main-window binding action is lost")
 p:SelectSection("interface");check(p.bindingCapture==nil,locale..": leaving General retains keyboard capture")
 local reload=p.reloadLanguage;local current=u.context.Theme
 check(not reload:IsShown() and p.themeReloadHint==nil,locale..": normal settings show an irrelevant reload action")
 p:SelectSection("general")
 f.Pick(p.controls.language.widget,locale=="zhCN" and "enUS" or "zhCN")
 p:SelectSection("general")
 check(reload:IsVisible() and reload:GetParent()==p.panels.general,locale..": a language change has no reload action in General")
 local _,reloadY=position(reload,p.panels.general)
 near(reloadY,p.panels.general.nextRowY+16,locale..": language reload does not follow the General rows")
 p:SelectSection("interface")
 check(not reload:IsVisible() and p.themeReloadHint==nil,locale..": a language change claims Appearance needs a reload")
 local definition={schema=1,id="fixture.settings.sections."..locale,revision=1,appearance={main={tokens={brand={.2,.3,.4,1}}}}}
 check(a.API.Theme:Import(definition,{activate=true}),locale..": theme fixture import fails")
 p:Sync();local hint=p.themeReloadHint
 check(reload:IsVisible() and reload:GetParent()==p.panels.interface and hint:IsVisible(),locale..": a pending theme has no reload action in Appearance")
 check(hint:GetParent()==p.panels.interface and u.context.Theme==current,locale..": pending feedback changes the running theme")
 for _,percent in ipairs({70,130,100}) do
  a:SetSetting("fontScale",percent);u:SetWindowSize(1,1)
  local panel=p.panels.interface;local hintX,hintY=position(hint,panel);local reloadX,reloadY=position(reload,panel)
  near(hintY,panel.nextRowY+16,locale..": pending theme text is not below the Appearance rows")
  near(reloadY,hintY,locale..": theme feedback and action occupy different rows")
  check(hintX+hint:GetWidth()+24<=reloadX+.001,locale..": pending theme feedback overlaps Reload UI")
  check(hintY+hint:GetStringHeight()<=panel:GetHeight() and reloadY+reload:GetHeight()<=panel:GetHeight(),locale..": pending theme feedback does not fit the minimum window")
  check(u.context.Theme==current,locale..": a live preference activates the pending theme")
  p:SelectSection("general")
  check(reload:IsVisible() and not hint:IsVisible() and reload:GetParent()==p.panels.general,locale..": language and theme feedback leak between categories")
  p:SelectSection("interface")
 end
 a:SetSetting("language","auto");p:SelectSection("general")
 check(not reload:IsVisible(),locale..": a theme-only reload action appears in General")
 p:SelectSection("interface");check(reload:IsVisible() and hint:IsVisible(),locale..": clearing a language change hides a pending theme")
 local native=C_UI;local reloads=0;_G.C_UI={Reload=function() reloads=reloads+1 end}
 reload:Fire("OnClick","LeftButton");_G.C_UI=native
 check(reloads==1,locale..": the reused reload button stops invoking Reload UI")
 check(a.API.Theme:Remove(definition.id),locale..": theme fixture cleanup fails");p:Sync()
 check(not reload:IsShown() and not hint:IsShown(),locale..": clearing pending reasons retains reload feedback")
 local nodes=#s.nodes
 for _=1,6 do for _,section in ipairs(sections) do p:SelectSection(section[1]) end end
 check(#s.nodes==nodes and p.reloadLanguage==reload and p.themeReloadHint==hint,locale..": revisiting categories creates more controls")
 u:Hide(true)
end
-- Inline links have one active owner, including rapid changes during expansion.
do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=false})
 local a,u=f.A,f.U;a:Open("settings",{section="about"});u.Motion:Tick(1)
 local p=u.pages.settings;local first,second=p.otherAddons[1],p.otherAddons[2]
 local initialHeight=first.frame:GetHeight();local initialY=select(2,position(second.frame,p.panels.about))
 first.links[1]:Fire("OnClick","LeftButton")
 local copy=first.linkCopy;local selections,cursor=0
 copy.field.box.HighlightText=function() selections=selections+1 end
 copy.field.box.SetCursorPosition=function(_,value) cursor=value end
 first.links[2]:Fire("OnClick","LeftButton")
 check(copy==first.linkCopy and selections==1 and cursor==0,"changing platforms recreates the copy field or loses selection and the URL start")
 check(copy.field.box:HasFocus() and not u.activeModal,"inline copy does not focus within the existing page")
 check(u.Motion:IsRunning(p.linkMotion),"opening a copy field has no finite expansion")
 u.Motion:Tick(.06)
 check(copy.progress>0 and copy.progress<1,"copy expansion jumps directly to its final state")
 check(first.frame:GetHeight()>initialHeight and select(2,position(second.frame,p.panels.about))>initialY,"expansion does not move the following addon row")
 local before=copy.progress
 second.links[1]:Fire("OnClick","LeftButton")
 near(copy.progress,before,"retargeting an expansion jumps to the old end state")
 check(not copy.field.box:HasFocus() and second.linkCopy.field.box:HasFocus(),"moving to another addon retains the old keyboard focus")
 u.Motion:Tick(.07)
 check(copy.progress<before and second.linkCopy.progress>0,"changing addons does not collapse and expand their own rows")
 u.Motion:Tick(1)
 check(not copy.clip:IsShown() and copy.field.box:GetText()=="" and not u.Motion:IsRunning(p.linkMotion),"finished copy animation retains text or a frame driver")
 local active=second.linkCopy;local value=active.field.box:GetText()
 active.field.box:UserType("overwrite")
 check(active.field.box:GetText()==value,"the displayed link is editable")
 active.field.box:Fire("OnEscapePressed");check(not active.field.box:HasFocus() and p.activeLinkCopy==nil,"Escape keeps the inline field focused")
 u.Motion:Tick(1);near(first.frame:GetHeight(),initialHeight,"closing the copy field does not restore the original row height")
 first.links[1]:Fire("OnClick","LeftButton");u.Motion:Tick(.05)
 a:SetSetting("reduceMotion",true)
 check(copy.progress==1 and not u.Motion:IsRunning(p.linkMotion),"reducing motion leaves copy expansion half open")
 p:SelectSection("credits")
 check(not copy.field.box:HasFocus() and copy.field.box:GetText()=="" and not copy.clip:IsShown(),"leaving About retains copy state")
 for _,row in ipairs(p.credits) do for _,button in ipairs(row.links) do button:Fire("OnClick","LeftButton") end end
 local nodes=#f.S.nodes
 for _=1,5 do for _,row in ipairs(p.credits) do for _,button in ipairs(row.links) do button:Fire("OnClick","LeftButton") end end end
 check(#f.S.nodes==nodes,"repeated platform clicks allocate more copy widgets")
 u:Hide(true)
 for _,field in ipairs(p.linkCopies) do check(not field.field.box:HasFocus() and field.field.box:GetText()=="" and not field.clip:IsShown(),"hiding Settings leaks an inline input") end
 check(not u.Motion:IsRunning(p.linkMotion),"hiding Settings leaves copy animation running")
end
print("Settings sections: "..checks.." checks passed")
