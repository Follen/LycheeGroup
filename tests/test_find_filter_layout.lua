-- Find automation captions and filter-panel geometry. No game client is contacted.
-- Run from the repository root: lua tests/test_find_filter_layout.lua
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function full(label)
 return label:GetUnboundedStringWidth()<=label:GetWidth()+.001
end
local function position(region,root)
 if region==root then return 0,0 end
 local point={region:GetPoint()};local relative,anchor,x,y
 if type(point[2])=="table" then relative,anchor,x,y=point[2],point[3],point[4] or 0,point[5] or 0
 else relative,anchor,x,y=region:GetParent(),point[1],point[2] or 0,point[3] or 0 end
 local function fraction(value,low,high) return value:find(low) and 0 or value:find(high) and 1 or .5 end
 local px,py=position(relative,root)
 return px+relative:GetWidth()*fraction(anchor,"LEFT","RIGHT")+x-region:GetWidth()*fraction(point[1],"LEFT","RIGHT"),py+relative:GetHeight()*fraction(anchor,"TOP","BOTTOM")-y-region:GetHeight()*fraction(point[1],"TOP","BOTTOM")
end
-- Native mouse eligibility must stay stable while a result notification only
-- updates the footer. The fixture deliberately does not invent native hover
-- dispatch; these transitions are the cause that can provoke leave/enter.
do
 local f=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=true,showImportantFilters=false})
 f.A:Open("find");local p=f.U.pages.find;p:SetFiltersOpen(true)
 local transitions,insets=0,0
 for _,target in ipairs({p.hideZeroScore,p.requireBloodlust,p.quickChoices.damagePresence.button})do
  check(target:IsVisible() and target:IsMouseEnabled(),"hover regression requires an interactive visible control")
  local enable,setInsets=target.EnableMouse,target.SetHitRectInsets
  target.EnableMouse=function(self,value)
   if self:IsMouseEnabled()~=value then transitions=transitions+1 end
   return enable(self,value)
  end
  target.SetHitRectInsets=function(self,...)insets=insets+1;return setInsets(self,...)end
 end
 local width,height,offset=p.filterPanel:GetWidth(),p.filterPanel:GetHeight(),p.filterViewport:GetVerticalScroll()
 f.G:Notify("results")
 check(p.filterPanel:GetWidth()==width and p.filterPanel:GetHeight()==height and p.filterViewport:GetVerticalScroll()==offset,"footer refresh changes filter geometry")
 check(transitions==0,"result refresh disables and re-enables stationary hover controls")
 check(insets==0,"result refresh rewrites unchanged mouse hit rectangles")
 -- Overflow needs two measurement passes. Neither may publish provisional
 -- hit regions, including the case where the visible result list is empty.
 f.A:SetSetting("fontScale",130);f.U:SetWindowSize(1,1);p:SetFiltersOpen(true)
 f.U.frame:SetHeight(380);p:LayoutFilters()
 check(p.filterScrollBar:IsShown(),"hover regression must exercise overflow")
 p.filterViewport:Fire("OnMouseWheel",-100)
 local changes=0
 for index=1,p.filterClipCount do
  local target=p.filterHitTargets[index].target
  local enable,setInsets=target.EnableMouse,target.SetHitRectInsets
  target.EnableMouse=function(self,value)changes=changes+1;return enable(self,value)end
  target.SetHitRectInsets=function(self,...)changes=changes+1;return setInsets(self,...)end
 end
 f.G:Notify("results")
 check(changes==0,"overflow measurement publishes temporary mouse eligibility or clipping")
 local previous={}
 for index=1,p.filterClipCount do previous[p.filterHitTargets[index].target]=true end
 p:SelectCategory("seasonRaid")
 local current={};for index=1,p.filterClipCount do current[p.filterHitTargets[index].target]=true end
 for target in pairs(previous)do if not current[target]then check(not target:IsMouseEnabled(),"discarded filter target keeps a stale mouse hit region")end end
 check(next(p.filterPreviousTargets)==nil,"retired target scratch storage retains frames after layout")
 f.U:Hide(true)
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true})
 f.A:Open("find")
 local p=f.U.pages.find
 -- Font geometry can settle after a hidden frame was first measured. Reproduce
 -- a wider, settled glyph run without changing its font tuple or label text.
 for _,label in ipairs({p.autoJoin.label,p.applicationSettings.label}) do
  local natural=label.GetUnboundedStringWidth
  label.GetUnboundedStringWidth=function(self) return natural(self)*1.22 end
 end
 local settle=p.frame:GetScript("OnUpdate")
 check(settle~=nil,locale..": first display schedules one metric settle")
 settle(p.frame,.016)
 check(full(p.autoJoin.label),locale..": Auto join is ellipsized after font metrics settle")
 check(full(p.applicationSettings.label),locale..": Auto apply is ellipsized after font metrics settle")
 f.U:Hide(true)
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,percent in ipairs({70,100,130,160}) do
  local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true,fontScale=math.min(percent,130)})
  local a,u,g=f.A,f.U,f.G
  a:Open("find")
  if percent==160 then u:ApplyFont(u.context.fontPath,1.6) end -- Stress only; public setting remains 70–130%.
  local p=u.pages.find
  g.apps[1]={id=901,status="applied",name="Raid application",categoryID=3,result={id=901,activity=g.Catalog:GetActivity(1),maxNumPlayers=30,numMembers=12}}
  p:RefreshApplications()
  local defaultWidth,defaultHeight=u.windowWidth,u.windowHeight
  for _,important in ipairs({false,true}) do
   a:SetSetting("showImportantFilters",important)
   for _,minimum in ipairs({false,true}) do
    local preferred=u.preferredWindowWidth
    if minimum then u:SetWindowSize(1,1) else u:SetWindowSize(defaultWidth,defaultHeight) end
    for _,category in ipairs({"seasonDungeon","2","seasonRaid"}) do
     check(g.Catalog:GetCategory(category)~=nil,"fixture must contain category "..category)
     do
      p:SelectCategory(category);p:CommitChoice();p:SetFiltersOpen(true)
      if minimum then u:SetWindowSize(1,1) end
      local tag=("%s/%d/%s/%s/%s"):format(locale,percent,tostring(important),tostring(minimum),category)
      for _,control in ipairs({p.applicationSettings,p.autoJoin}) do
       check(full(control.label),tag..": automation caption is clipped")
       local x=position(control,p.applicationPanel)
       check(x>=0 and x+control:GetWidth()<=p.applicationPanel:GetWidth()+.001,tag..": automation caption exceeds its panel")
      end
      local firstX=position(p.autoApply,p.applicationPanel)
      local joinX=position(p.autoJoin,p.applicationPanel)
      check(joinX>=firstX+p.autoApply:GetWidth(),tag..": automation switches overlap")
      if p.scopeToggle:IsShown() then
       local scopeX=position(p.scopeToggle,p.applicationPanel)
       local nextX=position(p.quickPlacement=="header" and p.quickFilters or p.applicationSettings,p.applicationPanel)
       check(scopeX+p.scopeToggle:GetWidth()<=nextX,tag..": application scope overlaps automation or important filters")
      end
      check(p.filterPanel:GetHeight()+u.Theme.findFilterWindowTop+u.Theme.findFilterWindowInset<=u.frame:GetHeight()+.001,tag..": filter panel exceeds its window")
      local footerTop=select(2,position(p.filterFooter,p.filterPanel))
      local viewX,viewY=position(p.filterViewport,p.filterPanel)
      check(viewY+p.filterViewport:GetHeight()+12<=footerTop+.001,tag..": body overlaps the fixed footer")
      check(p.filterScrollBar:IsShown()==(p.filterBody:GetHeight()>p.filterViewport:GetHeight()+.001),tag..": scrollbar does not match actual overflow")
      if percent==100 and not minimum then
       check(not p.filterScrollBar:IsShown(),tag..": default type hides conditions behind a scrollbar")
       local _,socialY=position(p.socialChoice,p.filterBody)
       check(socialY+p.socialChoice:GetHeight()<=p.filterViewport:GetHeight()+.001,tag..": default type hides relation filtering")
      end
      check(p.filterDividers==nil and p.filterFooterDivider==nil,tag..": filter layout adds decorative separators")
      check(p.sortChoice==nil and p.sortLabel==nil and a.ElementDefaults.main["find.sortChoice"]==nil,tag..": sorting remains in the filter panel")
      local hintX,hintY=position(p.filterRangeHint,p.filterBody)
      local rangeTitleX,rangeTitleY=position(p.filterRangeTitle,p.filterBody)
      check(full(p.filterRangeHint) and full(p.filterRangeTitle),tag..": range guidance is clipped")
      check(rangeTitleX+p.filterRangeTitle:GetWidth()+16<=hintX+.001,tag..": range title overlaps the blank-value guidance")
      check(math.abs(hintY+p.filterRangeHint:GetHeight()/2-rangeTitleY-p.filterRangeTitle:GetHeight()/2)<.001,tag..": range guidance is misaligned")
      check(p.filterSubtitle==nil and a.ElementDefaults.main["find.filterSubtitle"]==nil,tag..": removed subtitle is still constructed or registered")
      local right
      for _,control in ipairs({p.filterStatus,p.clearFilters,p.filterDone}) do
       local x,y=position(control,p.filterFooter)
       check(not right or x>=right+.001,tag..": footer actions overlap")
       check(x>=0 and x+control:GetWidth()<=p.filterFooter:GetWidth()+.001,tag..": footer exceeds its padded width")
       check(y>=0 and y+control:GetHeight()<=p.filterFooter:GetHeight()+.001,tag..": footer text clips vertically")
       right=x+control:GetWidth()
      end
      for _,field in pairs(p.filterFields) do
       check(full(field.placeholder),tag..": range placeholder is clipped")
       check(field:GetHeight()>=field.placeholder:GetStringHeight(),tag..": range placeholder clips vertically")
       check(field.fill.radius==u.Theme.fieldRadius and field.fill.color==u.Theme.field,tag..": range input does not use the existing field appearance")
      end
      for _,range in pairs(p.filterRanges) do
       local lowX=position(range.low,range.frame);local highX=position(range.high,range.frame)
       check(math.abs(highX-lowX-range.low:GetWidth()-8)<.001,tag..": paired inputs do not keep their eight-unit gap")
       check(range.frame.fill==nil and range.frame.separator==nil,tag..": paired fields add a custom background or separator")
      end
      local rangeX,previousBottom
      for _,label in ipairs({p.ratingLabel,p.ilvlLabel,p.membersLabel}) do
       local range=p.filterRanges[label];local x,y=position(range.frame,p.filterBody)
       check(not rangeX or math.abs(x-rangeX)<.001,tag..": numeric ranges do not share a column")
       check(not previousBottom or y>=previousBottom+12-.001,tag..": numeric rows overlap")
       local _,labelY=position(label,p.filterBody)
       check(math.abs(labelY+label:GetHeight()/2-y-range.frame:GetHeight()/2)<.001,tag..": range label does not align with its inputs")
       rangeX,previousBottom=x,y+range.frame:GetHeight()
      end
      if category=="seasonDungeon" then
       local _,zeroY=position(p.hideZeroScore,p.filterBody)
       check(zeroY>=previousBottom+12,tag..": zero-score switch shares the member range row")
       check(p.hideZeroScore:GetWidth()==p.filterBody:GetWidth(),tag..": zero-score switch is not a full line")
      end
      if p.importantFilters:IsShown() then
       check(p.quickFilters:GetParent()==p.importantFilters and p.quickPlacement=="popup",tag..": popup does not reuse the quick controls")
       check(p.presenceChoices==nil and p.identityChoice==nil and p.presenceLogic==nil,tag..": obsolete popup selectors remain allocated")
       local center,previousRight
       for _,key in ipairs({"tankPresence","healerPresence","damagePresence"}) do
        local button=p.quickChoices[key].button
        local x,y=position(button,p.quickFilters)
        check(not center or math.abs(y+button:GetHeight()/2-center)<.001,tag..": role buttons are not on one line")
        check(not previousRight or x>=previousRight+6-.001,tag..": role buttons overlap")
        center,previousRight=y+button:GetHeight()/2,x+button:GetWidth()
       end
       for _,item in ipairs(p.quickFilterItems) do
         local button=item.frame
         check(full(button.label),tag..": filter option is clipped: "..button.label:GetText())
         check(button:GetHeight()>=button.label:GetStringHeight(),tag..": filter option clips vertically")
       end
       local logicX,logicY=position(p.quickLogic,p.importantFilters)
       local rolesX,rolesY=position(p.filterRolesLabel,p.importantFilters)
       check(rolesX+p.filterRolesLabel:GetWidth()+16<=logicX+.001,tag..": role match control overlaps its heading")
       check(math.abs(rolesY+p.filterRolesLabel:GetHeight()/2-logicY-p.quickLogic:GetHeight()/2)<.001,tag..": role match control is not aligned with its heading")
       local identityX,identityY=position(p.quickIdentity,p.importantFilters)
       check(p.filterIdentityLabel==nil,tag..": obsolete class and specialization heading remains allocated")
       check(identityX>=previousRight+8-.001 and identityX+p.quickIdentity:GetWidth()<=p.importantFilters:GetWidth()+.001,tag..": identity filter overlaps the role row or overflows")
       check(math.abs(identityY+p.quickIdentity:GetHeight()/2-center)<.001,tag..": identity filtering is not on the role row")
       check(not p.quickIdentity.active,tag..": unrestricted identity filter retains a selected background")
       local button=p.quickChoices.tankPresence.button
       button:Fire("OnClick","RightButton");button:Fire("OnClick","LeftButton")
       check(button.active and g.filters.tankPresence=="missing",tag..": compact role button does not cycle")
       check(button.fill.color==u.Theme.secondaryContainer and button.fill:IsShown(),tag..": compact role selection does not use the shared gray fill")
       check(button.label._color==u.Theme.onSecondaryContainer,tag..": selected text does not use the normal shared foreground")
      end
      local fixedY=select(2,position(p.filterFooter,p.filterPanel))
      p.filterViewport:Fire("OnMouseWheel",-100)
      check(select(2,position(p.filterFooter,p.filterPanel))==fixedY,tag..": scrolling moves the action footer")
      local maximum=math.max(0,p.filterBody:GetHeight()-p.filterViewport:GetHeight())
      check(math.abs(p.filterViewport:GetVerticalScroll()-maximum)<.001,tag..": cannot reach the end of the filter body")
      for index=1,p.filterClipCount do
       local entry=p.filterHitTargets[index]
       local expected=entry.top+entry.height>maximum and entry.top<maximum+p.filterViewport:GetHeight()
       check(entry.target:IsMouseEnabled()==expected,tag..": clipped filter control retains an offscreen hit target")
      end
      p.socialChoice:SetValue("noCaution",locale=="zhCN" and "不含拉黑记录" or "Without blocked players")
      p:LayoutFilters();check(full(p.socialChoice.label),tag..": long relation value is clipped")
      p:SetFiltersOpen(false)
     end
    end
    -- Opening or closing filters does not change the stored preferred size.
    check(u.preferredWindowWidth==preferred,"filter presentation rewrites the preferred window width")
   end
  end
  p:SelectCategory("seasonDungeon");a:SetSetting("showImportantFilters",false);p:SetFiltersOpen(true)
  p.filterFields.minMembers.box:UserType("5");p.filterFields.maxMembers.box:UserType("1")
  check(p.filterError:GetText()~="" and p.filterError:IsShown(),"invalid range does not show its validation message")
  local ex,ey=position(p.filterError,p.filterFooter)
  check(ey+p.filterError:GetHeight()<select(2,position(p.filterDone,p.filterFooter)),"range error overlaps the fixed actions")
  p:ClearFilters();check(p.filterError:GetText()=="","reset does not clear the invalid range message")
  p.filterFields.minMembers.box:UserType("0")
  check(p.filterCount==0 and p.clearFilters:IsEnabled(),"invalid unsaved input cannot be cleared with Reset")
  p.clearFilters:Fire("OnClick")
  check(p.filterFields.minMembers.box:GetText()=="" and p.filterError:GetText()=="" and not p.clearFilters:IsEnabled(),"reset retains invalid range text or an enabled empty reset action")
  for _,key in ipairs({"tankPresence","healerPresence","damagePresence"}) do p.quickChoices[key].button:Fire("OnClick","LeftButton");p.quickChoices[key].button:Fire("OnClick","LeftButton") end
  check(g.filters.tankPresence=="present" and g.filters.healerPresence=="present" and not g.filters.damagePresence,"Match all permits a third positive role")
  p.quickLogic:Fire("OnClick","LeftButton")
  p.quickChoices.damagePresence.button:Fire("OnClick","LeftButton");p.quickChoices.damagePresence.button:Fire("OnClick","LeftButton")
  check(g.filters.roleMatchAny and g.filters.damagePresence=="present","Match any does not permit a third positive role")
  p.quickIdentity:Fire("OnClick","LeftButton");check(g.filters.hideSameClass==true and not g.filters.hideSameSpec,"same-class filtering changed behavior")
  p.quickIdentity:Fire("OnClick","LeftButton");check(g.filters.hideSameClassRole==true and not g.filters.hideSameClass and not g.filters.hideSameSpec,"class/role filtering is not the intermediate exclusion mode")
  p.quickIdentity:Fire("OnClick","LeftButton");check(g.filters.hideSameSpec==true and not g.filters.hideSameClass and not g.filters.hideSameClassRole,"same-specialization filtering changed behavior")
  -- Every identity state keeps the same reserved width and the same role row,
  -- including old independent filters that cannot be reduced without loss.
  for _,placement in ipairs({false,true}) do
   a:SetSetting("showImportantFilters",placement);p:SetFiltersOpen(true)
   for _,narrow in ipairs({false,true}) do
    u:SetWindowSize(narrow and 1 or defaultWidth,narrow and 1 or defaultHeight)
    local reserved=p.quickIdentity:GetWidth()
    for _,mode in ipairs({"classRole","spec","class","any"}) do
     p:SetIdentityFilter(mode)
     check(full(p.quickIdentity.label),"identity mode is clipped: "..mode)
     check(p.quickIdentity:GetWidth()==reserved,"changing identity mode changes the role-row width")
     local root=placement and p.quickFilters or p.importantFilters
     local identityX,identityY=position(p.quickIdentity,root)
     local _,roleY=position(p.quickChoices.tankPresence.button,root)
     local damage=p.quickChoices.damagePresence.button;local damageX=position(damage,root)
     check(identityX>=damageX+damage:GetWidth()+6-.001 and identityX+p.quickIdentity:GetWidth()<=root:GetWidth()+.001,"identity mode overlaps roles or overflows its row")
     check(math.abs(identityY+p.quickIdentity:GetHeight()/2-roleY-p.quickChoices.tankPresence.button:GetHeight()/2)<.001,"identity mode leaves its role row")
    end
    p:RestoreCategory({hideSameSpec=true,hideSameClassRole=true});p:UpdateFilters()
    check(full(p.quickIdentity.label),"legacy spec + role label is clipped")
   end
  end
  a:SetSetting("showImportantFilters",false)
  p.hideZeroScore:Fire("OnClick","LeftButton");check(g.filters.hideZeroScore==true,"zero-score toggle changed behavior")
  p:ClearFilters()
  local group=p.quickFilters;local buttons={}
  for index,item in ipairs(p.quickFilterItems) do buttons[index]=item.frame end
  for _,font in ipairs({70,130,100}) do
   a:SetSetting("fontScale",font)
   p:SetFiltersOpen(false);check(not group:IsVisible(),"closed popup exposes its compact buttons")
   a:SetSetting("showImportantFilters",true)
   check(group==p.quickFilters and group:GetParent()==p.applicationPanel and p.quickPlacement=="header","moving controls to the header creates a new strip or leaves the old parent")
   for index,item in ipairs(p.quickFilterItems) do
    check(item.frame==buttons[index],"placement replaces a compact button")
    local _,_,top,bottom=item.frame:GetHitRectInsets()
    check(item.frame:IsMouseEnabled() and top==0 and bottom==0,"popup clipping survives migration into the header")
   end
   local minimumWidth=u:GetWindowMinimum()
   p:SetFiltersOpen(true)
   check(u:GetWindowMinimum()==minimumWidth,"opening the popup changes the header minimum")
   a:SetSetting("showImportantFilters",false)
   check(group:GetParent()==p.importantFilters and p.quickPlacement=="popup","moving controls into the popup leaves the header parent")
   p:SelectCategory("seasonRaid");check(p.quickPlacement=="none" and not group:IsShown(),"unrelated categories retain seasonal controls")
   p:SelectCategory("seasonDungeon");p:SetFiltersOpen(true)
   check(group:IsVisible() and group:GetParent()==p.importantFilters,"category restoration loses the popup controls")
  end
  local before=#f.S.nodes
  for _=1,12 do p:SetFiltersOpen(false);p:SetFiltersOpen(true);p:LayoutFilters() end
  check(#f.S.nodes==before,"reopening filters allocates new visual objects")
  u:Hide(true)
 end
end
-- Force a small viewport independently of the public window minimum, so the
-- clipping-to-header handoff is exercised even though normal 100% content fits.
do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true,fontScale=130})
 local a,u=f.A,f.U;a:Open("find")
 local p=u.pages.find;p:SelectCategory("seasonDungeon");p:CommitChoice();p:SetFiltersOpen(true)
 u.frame:SetHeight(380);p:LayoutFilters()
 check(p.filterScrollBar:IsShown(),"short filter viewport does not expose its overflow")
 p.filterViewport:Fire("OnMouseWheel",-100)
 local clipped=0
 for _,item in ipairs(p.quickFilterItems) do if not item.frame:IsMouseEnabled() then clipped=clipped+1 end end
 check(clipped>0,"offscreen quick controls keep their hit areas in a short popup")
 local footerY=select(2,position(p.filterFooter,p.filterPanel))
 p.filterViewport:Fire("OnMouseWheel",100)
 check(select(2,position(p.filterFooter,p.filterPanel))==footerY,"overflow scrolling moves the fixed footer")
 p.filterViewport:Fire("OnMouseWheel",-100)
 a:SetSetting("showImportantFilters",true)
 for _,item in ipairs(p.quickFilterItems) do
  local _,_,top,bottom=item.frame:GetHitRectInsets()
  check(item.frame:IsMouseEnabled() and top==0 and bottom==0,"an offscreen popup control remains clipped after moving to the header")
 end
 u:Hide(true)
end
-- Native FontStrings report nil after SetText(""); blank feedback is not an error.
do
 local f=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=true})
 f.A:Open("find");local p=f.U.pages.find
 local getText=p.filterError.GetText
 p.filterError.GetText=function(self)local value=getText(self);return value~="" and value or nil end
 p:ClearFilters();p:SetFiltersOpen(true)
 check(not p.filterError:IsShown() and not p.clearFilters:IsEnabled(),"a nil native FontString enables reset or reserves an empty error row")
 p.filterFields.minMembers.box:UserType("0")
 check(p.filterError:IsShown() and p.clearFilters:IsEnabled(),"a real input error does not enable reset")
 p.clearFilters:Fire("OnClick")
 check(not p.filterError:GetText() and not p.filterError:IsShown() and not p.clearFilters:IsEnabled(),"clearing a native error retains feedback or reset availability")
 f.U:Hide(true)
end
print("Find filter layout: "..checks.." checks passed")
