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
 p:LayoutQuickFilters()
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
      if percent==100 then
       check(not p.filterScrollBar:IsShown(),tag..": default type hides conditions behind a scrollbar")
       local _,socialY=position(p.socialChoice,p.filterBody);local _,sortY=position(p.sortChoice,p.filterBody)
       check(math.max(socialY+p.socialChoice:GetHeight(),sortY+p.sortChoice:GetHeight())<=p.filterViewport:GetHeight()+.001,tag..": default type hides relations or sorting")
      end
      check(p.filterDividers==nil and p.filterFooterDivider==nil and p.filterSections==nil,tag..": filter layout adds headings or decorative separators")
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
  for _,key in ipairs({"tankPresence","healerPresence","damagePresence"}) do p.quickChoices[key].button:Fire("OnClick","LeftButton");p.quickChoices[key].button:Fire("OnClick","LeftButton") end
  check(g.filters.tankPresence=="present" and g.filters.healerPresence=="present" and not g.filters.damagePresence,"Match all permits a third positive role")
  p.quickLogic:Fire("OnClick","LeftButton")
  p.quickChoices.damagePresence.button:Fire("OnClick","LeftButton");p.quickChoices.damagePresence.button:Fire("OnClick","LeftButton")
  check(g.filters.roleMatchAny and g.filters.damagePresence=="present","Match any does not permit a third positive role")
  p.quickIdentity:Fire("OnClick","LeftButton");check(g.filters.hideSameClass==true and not g.filters.hideSameSpec,"same-class filtering changed behavior")
  p.quickIdentity:Fire("OnClick","LeftButton");check(g.filters.hideSameSpec==true and not g.filters.hideSameClass,"same-specialization filtering changed behavior")
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
print("Find filter layout: "..checks.." checks passed")
