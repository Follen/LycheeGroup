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
 {"general","常规","General",{"language","toggleBinding","minimap","nativeLFGEntry"}},
 {"interface","界面显示","Appearance",{"font","fontScale","uiScale","reduceMotion"}},
 {"browse","寻求组队","Find groups",{"defaultSort","rememberFilters","showImportantFilters"}},
 {"memberIcons","成员显示","Member display",{"relations","raidMembers","memberIconShape","memberIconScale","memberClassBorder","memberLeaderMark"}},
 {"notes","笔记与提醒","Notes & reminders",{"defaultNote","noteMarks","reminders","history"}},
 {"blocks","屏蔽名单","Blocked leaders",{}},
 {"floating","悬浮窗","Floating window",{"floating","floatingCompatibility","floatingScale","floatingLocked","resetPosition"}},
 {"about","关于","About",{}},
}
local function layout(p,tag)
 local previous
 for _,section in ipairs(sections) do
  local key=section[1];local button=p.nav[key]
  local _,y=position(button,p.rail)
  if previous then near(y,previous+4,tag..": navigation entries lose their four-unit gap") else near(y,12,tag..": first category moves away from the rail inset") end
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
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,percent in ipairs({70,100,130}) do
  local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true,fontScale=percent})
  local a,u=f.A,f.U
  a:Open("settings",{section="general"});u:SetWindowSize(1,1)
  local p=u.pages.settings;local tag=locale.."/"..percent
  local seen={};local count=0
  for _,section in ipairs(sections) do
   local key,rows=section[1],section[4];local panel=p.panels[key]
   check(p.nav[key].label:GetText()==section[locale=="zhCN" and 2 or 3],tag..": category name is unclear or misplaced")
   check(#(panel.rows or {})==#rows,tag..": category has unexpected settings: "..key)
   for index,setting in ipairs(rows) do
    local row=panel.rows[index]
    if setting=="resetPosition" then check(row.action~=nil and p.controls[setting]==nil,tag..": position reset stops being an action")
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
  check(actual==count and count==25,tag..": settings were lost during regrouping")
  check(p.rail:GetWidth()==208,tag..": categories change the sidebar width")
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
 -- All moved controls still call the same setting entry point and save scope.
 for _,section in ipairs(sections) do
  p:SelectSection(section[1])
  for _,key in ipairs(section[4]) do
   local entry=p.controls[key]
   if entry and key~="toggleBinding" then
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
print("Settings sections: "..checks.." checks passed")
