-- Standalone offline geometry checks: lua tests/test_font_layout.lua
-- Font measurements come from the existing UI fixture, not game rendering.
local count=0
local function check(value,message)
 count=count+1;assert(value,message)
end
local function near(a,b) return math.abs(a-b)<.001 end
local function top(region) local p={region:GetPoint()};return -p[#p] end
local function left(region) local p={region:GetPoint()};return p[#p-1] end
local function separated(first,second)
 return top(second)+.001>=top(first)+first:GetHeight()
end
local function position(region,root)
 if region==root then return 0,0 end
 local point={region:GetPoint()};local relative,relativePoint,x,y
 if type(point[2])=="table" then relative,relativePoint,x,y=point[2],point[3],point[4] or 0,point[5] or 0
 else relative,relativePoint,x,y=region:GetParent(),point[1],point[2] or 0,point[3] or 0 end
 local function fraction(anchor,first,last)
  return anchor:find(first) and 0 or anchor:find(last) and 1 or .5
 end
 local px,py=position(relative,root)
 return px+relative:GetWidth()*fraction(relativePoint,"LEFT","RIGHT")+x-region:GetWidth()*fraction(point[1],"LEFT","RIGHT"),py+relative:GetHeight()*fraction(relativePoint,"TOP","BOTTOM")-y-region:GetHeight()*fraction(point[1],"TOP","BOTTOM")
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,percent in ipairs({70,100,130}) do
  local f=dofile("tests/ui_fixture.lua")(locale,nil,{fontScale=percent,reduceMotion=true})
  local a,u,g=f.A,f.U,f.G
  a:Open("find")
  local find=u.pages.find
  local row=find.results.rows[1]
  check(separated(row.title,row.meta),"result title and activity text overlap")
  check(top(row.meta)+row.meta:GetHeight()<=row:GetHeight()+.001,"result text exceeds its row")
  check(row.description:GetHeight()>=row.meta:GetHeight()*2,"two-line result description is clipped")
  for _,list in ipairs({find.results,find.appList}) do
   local item=list.rows[1];item.isParty=false;item.membersExpanded=true
  end
  find:LayoutListRows()
  for _,list in ipairs({find.results,find.appList}) do
   local item=list.rows[1]
   local upper={item.membersButton:GetPoint()};local lower={item.count:GetPoint()}
   local upperBottom=upper[#upper]-item.roster.counts[1].text:GetHeight()/2
   local lowerTop=lower[#lower]+item.count:GetHeight()/2
   check(upperBottom+.001>=lowerTop,"expanded member totals overlap the role counts")
   check(lowerTop-item.count:GetHeight()>=-item:GetHeight()/2-.001,"expanded member total exceeds its row")
  end
  if percent==100 then
   check(row:GetHeight()==76 and top(row.meta)==42,"100% result geometry changed")
   check(find.appList.rowHeight==36,"100% application stride changed")
  end
  local descriptionWidth=row.description:GetWidth()
  for _,collapsed in ipairs({true,false}) do
   find:SetSidebarCollapsed(collapsed,false)
   check(near(find.rail:GetWidth(),collapsed and 48 or 208),"category rail width changes with its state")
   check(near(find.main:GetWidth(),collapsed and 1155.2 or 995.2),"main content uses the available rail width")
   local cell=find.resultsHeader.columns.description
   check(near(left(row.description),cell.x+8) and near(row.description:GetWidth(),cell.width-16),"the result description follows its resized table cell")
   check(collapsed and row.description:GetWidth()>descriptionWidth or not collapsed and near(row.description:GetWidth(),descriptionWidth),"the result description grows with reclaimed sidebar width and restores afterward")
   check(find.sidebarToggle:GetHeight()==40 and find.sidebarToggle:GetWidth()==(collapsed and 40 or 192),"sidebar toggle keeps its hit area")
   check(find.sidebarToggle.label:IsShown()~=collapsed,"toggle caption visibility matches the rail")
   if not collapsed then check(find.sidebarToggle.label:GetStringWidth()+52<=find.sidebarToggle:GetWidth(),"translated toggle caption fits the largest font") end
   for _,list in ipairs({find.seasonCategories,find.categories}) do
    for _,categoryRow in ipairs(list.rows) do
     check(categoryRow.title:IsShown()~=collapsed and categoryRow.chevron:IsShown()~=collapsed,"collapsed categories hide captions and arrows")
     check(left(categoryRow.symbol)>=0 and left(categoryRow.symbol)+categoryRow.symbol:GetWidth()<=find.rail:GetWidth(),"category icon stays within the rail")
    end
   end
   check(top(find.categories)+find.categories:GetHeight()+8<=find.rail:GetHeight()-48,"category viewport remains above the sidebar toggle")
   check(separated(row.title,row.meta),"changing rail width preserves result line separation")
  end
  find:SelectCategory("seasonDungeon");find:CommitChoice();find:SetFiltersOpen(true)
  check(not find.quickFilters:IsShown() and find.importantFilters:IsShown(),"important filters default to the popup")
  check(find.filterPanel:GetWidth()==592 and find.importantFilters:GetWidth()==552,"seasonal popup uses the compact panel width")
  for key,choice in pairs(find.presenceChoices) do
   local label=find.presenceLabels[key]
   check(left(choice)>=left(label)+label:GetWidth()+8-.001,"role segments leave room beside their label")
   check(left(choice)+choice:GetWidth()<=552+.001,"role segments stay inside the compact important-filter block")
   for _,button in ipairs(choice.buttons) do
    check(button.label:GetStringWidth()<=button.label:GetWidth()+.001,"translated role segment fits its text area")
    check(button:GetHeight()+.001>=button.label:GetStringHeight(),"role segment height follows the selected font")
   end
  end
  for _,choice in ipairs({find.presenceLogic,find.identityChoice}) do
   for _,button in ipairs(choice.buttons) do check(button.label:GetStringWidth()<=button.label:GetWidth()+.001,"logic and identity segment labels fit") end
  end
  check(top(find.filterPanel)+find.filterPanel:GetHeight()<=u.frame:GetHeight()-20+.001,"compact filter popup stays within the window")
  local footerRight,footerCenter
  for _,control in ipairs({find.filterStatus,find.clearFilters,find.filterDone}) do
   local x,y=position(control,find.filterPanel)
   check(not footerRight or x>=footerRight-.001,"popup footer counts and actions overlap")
   check(not footerCenter or near(y+control:GetHeight()/2,footerCenter),"popup footer shares one horizontal line")
   check(x>=20-.001 and x+control:GetWidth()<=find.filterPanel:GetWidth()-20+.001,"popup footer stays within its panel padding")
   footerRight,footerCenter=x+control:GetWidth(),y+control:GetHeight()/2
  end
  local preferredWidth=u.preferredWindowWidth
  local windowWidth,windowHeight=u.windowWidth,u.windowHeight
  for _,show in ipairs({true,false}) do
   a:SetSetting("showImportantFilters",show)
   check(near(find.search:GetWidth(),find.main:GetWidth()-60),"important-filter placement never reduces search width")
   check(find.quickFilters:IsShown()==show and find.importantFilters:IsShown()~=show,"the setting shows exactly one set of important filters")
   check(find.quickFilterHeight==0,"important filters never reserve a second header row")
   check(near(top(find.applicationPanel),68) and near(find.applicationPanel:GetHeight(),44+(find.appsHeight or 0)),"applications keep their existing vertical geometry")
   check(near(top(find.applicationHeader),40),"application headings keep their original top inset")
   check(near(top(find.appList),44+find.applicationHeader:GetHeight()),"application rows retain their original top inset")
   check(find.filterPanel:GetWidth()==(show and 368 or 592),"popup width follows the important-filter placement")
   if show then
    u:SetWindowSize(1,1)
    local minimum=u:GetWindowMinimum()
    check(minimum>=find:GetMinimumWidth(),"window minimum respects the measured header width")
    check(u.preferredWindowWidth==preferredWidth,"header constraints preserve the user's preferred window width")
    local root=find.applicationPanel
    local previousRight,center
    for _,button in ipairs({find.quickChoices.tankPresence.button,find.quickChoices.healerPresence.button,find.quickChoices.damagePresence.button,find.quickIdentity,find.quickLogic,find.applicationSettings,find.autoApply,find.autoJoin}) do
     local x,y=position(button,root)
     check(not previousRight or x>=previousRight-.001,"header controls overlap horizontally")
     check(not center or near(y+button:GetHeight()/2,center),"important filters and automation controls share one line")
     check(button.label:GetStringWidth()<=button.label:GetWidth()+.001,"header control text fits its full label")
     check(x>=0 and x+button:GetWidth()<=root:GetWidth()+.001,"header controls stay within the application panel")
     previousRight,center=x+button:GetWidth(),y+button:GetHeight()/2
    end
    local leading=find.scopeToggle:IsShown() and find.scopeToggle or find.appsTitle
    local x=position(leading,root);local countX=position(find.appsBadge,root)
    local filterX=position(find.quickFilters,root)
    check(countX>=x+leading:GetWidth()-.001 and countX+find.appsBadge:GetWidth()<=filterX-.001,"scope/title and count fit before the important filters")
   end
  end
  u:SetWindowSize(windowWidth,windowHeight)
  find:SetFiltersOpen(false)
  g.records[99]={id=99,partyGUID="Font-rejection",name="Rejected group",activityID=2,activity=g.Catalog:GetActivity(2),activityName="Dungeon activity",categoryID=2,numMembers=1,maxNumPlayers=5,age=1}
  g.declinedParties["Font-rejection"]=GetTime();find:CommitChoice();find:DoSearch()
  local rejected=find.results.rows[1]
  local function CheckRejectionLayout()
   check(rejected.key==99 and rejected.declined:IsShown(),"geometry checks render a rejected result")
   check(separated(rejected.meta,rejected.declined),"rejection text overlaps the activity line")
   check(top(rejected.declined)+rejected.declined:GetHeight()+10<=rejected:GetHeight()+.001,"rejection text exceeds the result row")
   check(rejected.declined:GetStringWidth()<=rejected.declined:GetWidth(),"the complete rejection text fits at the selected font size")
   check(rejected:GetHeight()/2+rejected.leader:GetHeight()/2<=top(rejected.declined),"rejection text overlaps the leader column")
  end
  CheckRejectionLayout()
  a:SetSetting("fontScale",percent==130 and 70 or 130);CheckRejectionLayout();a:SetSetting("fontScale",percent)
  g.records[99]=nil;g.declinedParties["Font-rejection"]=nil;g:Notify("results")
  check(find.declineClock==nil,"clearing the rejected result releases its clock")
  local name=locale=="zhCN" and "很长的玩家姓名-很长的服务器" or "Longplayer-Longrealm"
  local people={{nameKey=name,class="WARRIOR",assignedRole="TANK",isFriend=true},{nameKey=name,class="PALADIN",assignedRole="HEALER"}}
  g.listing={name="Test listing",activityID=2,comment="",requiredItemLevel=0}
  g.applicants[1]={id=1,status="applied",displayOrderID=1,members=people}
  a:Open("create")
  local create=u.pages.create
  local batch=create.batchPool[1]
  check(create.applicantMeasure.text:GetText()=="" and next(create.applicantMeasure.marks.flags)==nil,"applicant measurement retains player content")
  for _,person in ipairs(batch.people) do
   check(person:GetHeight()+.001>=person.title:GetStringHeight(),"wrapped applicant name exceeds its row")
  end
  check(top(batch.people[2])>=top(batch.people[1])+batch.people[1]:GetHeight(),"applicant member rows overlap")
  check(top(batch.people[2])+batch.people[2]:GetHeight()<=batch:GetHeight(),"final applicant row exceeds its batch")
  check(top(create.batchScroll)>=top(create.applicantTable)+create.applicantTable:GetHeight(),"applicant headers overlap the viewport")
  if percent==100 then check(near(batch.people[1]:GetHeight(),47.376),"100% applicant row changed") end
  if percent>100 then
   check(separated(create.pickerName,create.pickerContext),"activity picker text overlaps")
   check(top(create.pickerContext)+create.pickerContext:GetHeight()<=create.pickerTrigger:GetHeight(),"activity context exceeds its control")
   check(separated(create.titleLabel,create.titleShell),"listing title label overlaps its input")
   check(separated(create.descriptionLabel,create.descriptionShell),"description label overlaps its input")
   check(top(create.req)>=top(create.desc)+top(create.descriptionShell)+create.descriptionShell:GetHeight(),"requirements overlap the description input")
   check(top(create.ilvl)>=top(create.ilvlLabel)+create.ilvlLabel:GetHeight(),"requirement label overlaps its input")
  end
  for _,refresh in ipairs({function() create:RefreshPicker() end,function() create:LayoutFont() end}) do
   refresh()
   for _,pair in ipairs({{create.ilvlLabel,create.ilvl},{create.scoreLabel,create.score},{create.styleLabel,create.playstyle}}) do
    if percent>100 then check(separated(pair[1],pair[2]),"refreshing requirements overlaps a label and input") end
    check(near(left(pair[1]),left(pair[2])),"requirement input no longer aligns with its label")
   end
   check(left(create.score)>=left(create.ilvl)+create.ilvl:GetWidth()+16-.001,"requirement inputs overlap after font layout")
   check(left(create.playstyle)>=left(create.score)+create.score:GetWidth()+16-.001,"playstyle overlaps the score input after font layout")
   check(top(create.private)>=top(create.ilvl)+create.ilvl:GetHeight()+12-.001,"requirement options overlap the input row")
  end
  people[1].dungeonScores={mapScore=300,current={name="Test dungeon",level=12,timed=true},best={name="Test dungeon",level=13,timed=true}}
  u.Tooltip:ShowPlayer(batch.people[1],people[1],batch.people[1].memberContext)
  local tip=u.Tooltip.interactive
  for _,metric in ipairs(tip.metrics) do
   if metric.value:IsShown() then check(near(metric.value:GetHeight(),metric.value:GetLineHeight()+metric.value:GetSpacing()),"player metric clips the scaled line height") end
  end
  check(separated(tip.dungeonTitle,tip.dungeonRows[1]),"dungeon records overlap their scaled heading")
  u.Tooltip:Hide()
  u.Tooltip:ShowRoster(create.frame,{{nameKey="Test-Home",class="WARRIOR",assignedRole="TANK",isLeader=true}},false,{rosterMode="members"})
  local leader=u.Tooltip.interactive.memberButtons[1];local crown=leader.leaderIcon
  local anchor={crown:GetPoint()}
  check(anchor[1]=="BOTTOM" and anchor[2]==leader.icon and anchor[3]=="TOP" and anchor[5]==1,"member crowns stay above the portrait with a gap")
  check(crown:GetWidth()==14 and crown:GetHeight()==14,"tooltip crowns remain readable beside the member portrait")
  check(crown.layer=="OVERLAY" and crown.sublevel==1,"the portrait cannot cover its leader crown")
  check(top(leader.icon)-1-crown:GetHeight()>=-.001,"the crown fits inside its row at every supported font size")
  check(top(leader.icon)+leader.icon:GetHeight()<=leader:GetHeight()+.001,"crown spacing keeps the portrait inside its row")
  u.Tooltip:Hide()
  a.Notes:Merge({{name="Example",server="Home",timestamp=1,reason="A sample note",type="positive"}})
  g.GetHistory=function() return {{mapName="Test dungeon",level=12,startedAt=1,completedAt=100,members={{name="Example",realm="Home",class="WARRIOR"}}}} end
  a:Open("notes")
  local notes=u.pages.notes;local item=notes.list.rows[1]
  check(separated(item.title,item.meta),"note title and identity overlap")
  check(separated(item.meta,item.reason),"note identity and reason overlap")
  check(top(item.reason)+item.reason:GetHeight()<=item:GetHeight(),"note reason exceeds its row")
  notes:SelectTab("history");notes:OpenRun(1)
  local historyRow=notes.historyList.rows[1]
  check(top(historyRow.title)+historyRow.title:GetHeight()<=historyRow:GetHeight(),"the history activity title exceeds its row")
  for _,entry in ipairs({{"level",historyRow.level},{"duration",historyRow.duration},{"completed",historyRow.date}}) do
   local cell=notes.historyHeader.columns[entry[1]];local value=entry[2]
   check(left(value)>=cell.x and left(value)+value:GetWidth()<=cell.x+cell.width+.001,"history values extend outside their adjustable cells")
   check(value:GetHeight()<=historyRow:GetHeight(),"scaled history values exceed their row")
  end
  local member=notes.historyModal.list.rows[1]
  check(separated(member.title,member.meta),"history member title and metadata overlap")
  check(top(member.meta)+member.meta:GetHeight()<=member:GetHeight(),"history member metadata exceeds its row")
  a:Open("find");find:SelectCategory("seasonDungeon")
  a:SetSetting("fontScale",percent==130 and 70 or 130)
  for _,buttons in ipairs({find.difficultyButtons,create.difficultyButtons}) do
   for _,button in ipairs(buttons) do
    if button:IsShown() then check(button:GetWidth()>=button.label:GetStringWidth()+20,"difficulty choice retains its old width after changing font size") end
   end
  end
  a:SetSetting("fontScale",100)
  check(find.results.rowHeight==76 and notes.list.rowHeight==100,"returning to 100% retains enlarged row geometry")
  check(top(create.titleLabel)==92 and top(create.titleShell)==116,"returning to 100% retains enlarged form geometry")
  a:SetSetting("fontScale",percent);a:Open("settings",{section="interface"})
  local settings=u.pages.settings
  local panel=settings.panels.interface
  check(#panel.rows==6,"appearance settings contain all six rows including important-filter placement")
  local previous
  for _,entry in ipairs(panel.rows) do
   if previous then check(separated(previous,entry.frame),"appearance setting rows overlap") end
   check(entry.label:GetStringWidth()<=entry.label:GetWidth()+.001,"appearance setting title fits its column")
   check(entry.frame:GetHeight()+.001>=entry.help:GetStringHeight()+32,"appearance setting description exceeds its row")
   previous=entry.frame
  end
  check(separated(previous,settings.reloadLanguage),"reload action overlaps the sixth appearance row")
  check(top(settings.reloadLanguage)+settings.reloadLanguage:GetHeight()<=panel:GetHeight()+.001,"all six appearance rows and reload action fit their panel")
  local function CheckRange(control)
   local value=control.valueLabel;local anchor={control:GetPoint()}
   check(value:GetStringWidth()<=value:GetWidth(),"the complete percentage fits its measured label")
   check(value.justify=="RIGHT" and value.wrap==false,"percentage text remains right aligned without wrapping")
   check(near(anchor[#anchor-1]+12+value:GetWidth(),-12),"percentage right edges align twelve units inside their rows")
   check(near(control:GetWidth()+12+value:GetWidth(),220),"the slider gives measured percentage text space within the existing control area")
  end
  for _,key in ipairs({"uiScale","fontScale","floatingScale","memberIconScale"}) do CheckRange(settings.controls[key].widget) end
  local scaleControl=settings.controls.uiScale.widget
  local measure=scaleControl.valueLabel.GetStringWidth;local previousWidth=scaleControl:GetWidth()
  scaleControl.valueLabel.GetStringWidth=function(self) return measure(self)*1.8 end
  settings:Sync();CheckRange(scaleControl)
  check(scaleControl:GetWidth()<previousWidth,"a wider numeric typeface shortens the track to keep the full percentage visible")
  scaleControl.valueLabel.GetStringWidth=measure;settings:Sync();CheckRange(scaleControl)
  u:Hide(true)
 end
end
print("Font layout: "..count.." geometry checks passed")
