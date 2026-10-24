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
 -- Scroll children use their viewport origin; SetAllPoints also has no point
 -- tuple in this fixture, but retains the explicit relative region.
 if not point[1] then return position(region.allPoints or region:GetParent(),root) end
 if type(point[2])=="table" then relative,relativePoint,x,y=point[2],point[3],point[4] or 0,point[5] or 0
 else relative,relativePoint,x,y=region:GetParent(),point[1],point[2] or 0,point[3] or 0 end
 local function fraction(anchor,first,last)
  return anchor:find(first) and 0 or anchor:find(last) and 1 or .5
 end
 local px,py=position(relative,root)
 return px+relative:GetWidth()*fraction(relativePoint,"LEFT","RIGHT")+x-region:GetWidth()*fraction(point[1],"LEFT","RIGHT"),py+relative:GetHeight()*fraction(relativePoint,"TOP","BOTTOM")-y-region:GetHeight()*fraction(point[1],"TOP","BOTTOM")
end
local function centered(region,root)
 local _,y=position(region,root)
 return near(y+region:GetHeight()/2,root:GetHeight()/2)
end
local function activityCell(row,header)
 local cell=header.columns.activity
 local x,y=position(row.meta,row)
 check(cell and x>=cell.x-.001 and x+row.meta:GetWidth()<=cell.x+cell.width+.001,"activity text stays inside its independent table cell")
 check(y>=-.001 and y+row.meta:GetHeight()<=row:GetHeight()+.001,"activity text fits the compact row")
 check(centered(row.title,row) and centered(row.meta,row),"title and activity share the compact row's vertical center")
end
local function leaderMarks(row,header)
 local cell=header.columns.leader
 local nameX,nameY=position(row.leader,row);local markX,markY=position(row.marks,row)
 local anchor={row.marks:GetPoint()}
 check(anchor[2]==row.leader and anchor[3]=="RIGHT" and near(anchor[4],6),"relationship and note marks follow the leader instead of the activity name")
 check(row.leader:GetWidth()>0 and nameX>=cell.x-.001,"the leader retains a positive text box in its own column")
 check(near(markX,nameX+row.leader:GetWidth()+6) and markX+row.marks:GetWidth()<=cell.x+cell.width-4+.001,"all concurrent marks fit beside the leader inside the same column")
 check(near(nameY+row.leader:GetHeight()/2,markY+row.marks:GetHeight()/2),"leader marks share the name's vertical center")
 check(near(row.meta:GetWidth(),header.columns.activity.width-38),"leader marks never consume activity text width")
end
local function findEdges(find,u)
 local mainWidth=find.main:GetWidth()
 local headerX=position(find.resultsHeader,find.main)
 local row=find.results.rows[1];local rowX=position(row,find.main)
 check(near(headerX,0) and near(find.resultsHeader:GetWidth(),mainWidth),"the result header spans the main panel without losing scrollbar space")
 check(near(rowX,0) and near(row:GetWidth(),mainWidth),"result row backgrounds align with both main panel edges")
 check(near(find.results:GetWidth(),mainWidth+14),"the result scrollbar gutter stays outside the aligned rows")
 local app=find.appList.rows[1];local appX=position(app,find.main)
 local appHeaderX=position(find.applicationHeader,find.main)
 check(near(appX,16) and near(appX+app:GetWidth(),mainWidth-16),"application rows keep the same sixteen-unit left and right panel insets")
 check(near(appHeaderX,appX) and near(find.applicationHeader:GetWidth(),app:GetWidth()),"application headings and backgrounds have identical horizontal bounds")
 check(near(find.appList:GetWidth(),mainWidth-32+14),"the application scrollbar gutter does not shorten its rows")
 local titleX=position(row.title,find.main);local appTitleX=position(app.title,find.main)
 local contextX=position(find.context,find.main);local searchX=position(find.searchIcon,find.main)
 check(near(titleX,16) and near(appTitleX,16) and near(contextX,16) and near(searchX,16),"both lists' titles align with the context and search icons")
 local iconX=position(row.icon,row);local appIconX=position(app.icon,app)
 check(near(iconX,find.resultsHeader.columns.activity.x+4) and near(appIconX,find.applicationHeader.columns.activity.x+6),"both lists keep the artwork inside the independent activity cell")
 local countX=position(find.resultCount,find.main);local ageX=position(row.age,find.main)
 local trackX=position(find.autoJoin.track,find.main)
 check(near(countX+find.resultCount:GetWidth(),mainWidth-16),"the result total has the same right inset as the main controls")
 check(near(ageX+row.age:GetWidth(),mainWidth-16),"the posted-age text ends sixteen units inside the main panel")
 check(near(trackX+find.autoJoin.track:GetWidth(),mainWidth-16),"the automation track aligns with the result total and age column")
 if row.marks:IsShown() then leaderMarks(row,find.resultsHeader) end
 for _,list in ipairs({find.results,find.appList}) do
  local listX=position(list,find.main);local sliderX=position(list.slider,find.main)
  local clipX=position(list.clip,find.main);local item=list.rows[1];local itemX=position(item,find.main)
  local rowRight=itemX+item:GetWidth()
  check(near(clipX,itemX) and near(clipX+list.clip:GetWidth(),rowRight),"list clipping matches the usable row bounds")
  check(sliderX>=rowRight-.001 and sliderX+list.slider:GetWidth()<=listX+list:GetWidth()+.001,"the scrollbar stays in the outside gutter without covering row content")
 end
 for _,header in ipairs({find.resultsHeader,find.applicationHeader}) do
  for index,def in ipairs(header.definitions) do
   local cell,label=header.columns[def.key],header.buttons[index].label
   local declared=u.context:ResolveValue(def.min or 32)
   local minimum=math.max(declared,label:GetUnboundedStringWidth()+u.Theme.tablePadding*2)
   check(cell.width+.001>=minimum,"the smallest host never compresses a column below its declared or complete translated heading minimum")
   check(label:GetUnboundedStringWidth()<=label:GetWidth()+.001,"each full localized column heading fits at the current font scale")
  end
 end
 check(u.C.MeasureTextWidth(row.score,u:ScoreText(nil))<=row.score:GetWidth()+.001,"the smallest host preserves enough rating width for the complete unknown label")
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,percent in ipairs({70,100,130}) do
  local f=dofile("tests/ui_fixture.lua")(locale,nil,{fontScale=percent,reduceMotion=true})
  local a,u,g=f.A,f.U,f.G
  EJ_GetDifficulty=function() return 14 end;EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
  a:Open("find")
  local find=u.pages.find
  local leaderName=locale=="zhCN" and "很长的队长名字用来验证同列截断" or "Verylongleadernameforcolumntruncation"
  local leaderKey=leaderName.."-Home"
  a.Notes:Add(leaderName,"Home","Leader mark layout",nil,nil,{type="positive"})
  g.records[77]={id=77,activityID=2,activity=g.Catalog:GetActivity(2),activityName="Dungeon activity",categoryID=2,name="Compact result",leaderName=leaderKey,leaderKey=leaderKey,bnetFriends=1,charFriends=1,guildMates=1,numMembers=3,maxNumPlayers=5,age=1,details={members={},counts={TANK=1,HEALER=1,DAMAGER=1}}}
  find:CommitChoice();find:DoSearch()
  local row=find.results.rows[1]
  check(near(select(2,row.title:GetFont()),19*percent/100) and near(select(2,row.meta:GetFont()),19*percent/100) and near(select(2,row.description:GetFont()),19*percent/100),"result body cells share the enlarged nineteen-unit text role")
  check(near(row.title:GetLineHeight()+row.title:GetSpacing(),26*percent/100) and near(row.meta:GetLineHeight()+row.meta:GetSpacing(),26*percent/100),"result body line boxes follow the enlarged twenty-six-unit line height")
  activityCell(row,find.resultsHeader)
  findEdges(find,u)
  for _,kind in ipairs({"positive","neutral","caution"}) do
   a.Notes:Edit(leaderKey,"Leader mark layout",{type=kind});g:Notify("relations")
   check(row.marks.icons.bnet:IsShown() and row.marks.icons.friend:IsShown() and row.marks.icons.guild:IsShown() and row.marks.icons[kind]:IsShown(),"all three relationship marks and each supported leader note coexist")
   check(row.leader:GetWidth()<row.leader:GetUnboundedStringWidth(),"a long leader name truncates to preserve every concurrent mark")
   check(row.meta:GetText()=="Dungeon activity","all concurrent marks preserve the complete activity-name data")
   leaderMarks(row,find.resultsHeader)
  end
  check(row.description.maxLines==1 and not row.description.wrap and row.description:GetHeight()<=row:GetHeight()+.001 and centered(row.description,row),"the result description stays on one centered line inside the compact row")
  for _,score in ipairs({false,0}) do
   g.records[77].leaderRating=score~=false and score or nil;g:Notify("result",77);u.Motion:Tick(.016)
   check(row.score:GetText()==u:ScoreText(score~=false and score or nil),"unknown and zero ratings keep their complete display text")
   check(row.score:GetUnboundedStringWidth()<=row.score:GetWidth()+.001,"unknown and zero ratings fit their numeric column at every font scale")
  end
  for _,age in ipairs({59*60,23*3600,99*86400}) do
   g.records[77].age=age;g:Notify("result",77);u.Motion:Tick(.016)
   check(row.age:GetText()~="" and row.age:GetUnboundedStringWidth()<=row.age:GetWidth()+.001,"long minute, hour and day ages fit their fixed column at every font scale")
  end
  g.apps[1]={id=901,status="applied",name="Raid application",categoryID=3,result={id=901,activity=g.Catalog:GetActivity(1),maxNumPlayers=30,numMembers=30,details={members={},counts={TANK=10,HEALER=10,DAMAGER=10}}}}
  g.records[77].activity=g.Catalog:GetActivity(1);g.records[77].activityID=1;g.records[77].activityName=g.records[77].activity.name
  g.records[77].maxNumPlayers=30;g.records[77].numMembers=30;g.records[77].categoryID=3;g.records[77].details.counts={TANK=10,HEALER=10,DAMAGER=10};g:Notify("result",77);u.Motion:Tick(.016)
  find:RefreshApplications();find.scopeToggle:Fire("OnClick","LeftButton")
  for _,list in ipairs({find.results,find.appList}) do
   local item=list.rows[1];item.isParty=false;item.membersExpanded=false
  end
  find:LayoutListRows()
  local application=find.appList.rows[1]
  check(application.key==901,"the cross-category application keeps its actual raid record")
  activityCell(application,find.applicationHeader)
  check(select(2,application.meta:GetFont())==select(2,row.meta:GetFont()) and near(application.meta:GetLineHeight(),row.meta:GetLineHeight()),"result and application activity cells use the same text role")
  check(near(select(2,application.title:GetFont()),19*percent/100) and near(select(2,application.count:GetFont()),19*percent/100),"application titles and member totals share the enlarged body font")
  local layoutRows,layoutCalls=find.LayoutListRows,0
  find.LayoutListRows=function(self,...) layoutCalls=layoutCalls+1;return layoutRows(self,...) end
  for _,list in ipairs({find.results,find.appList}) do
   local item=list.rows[1];local height,viewport=list.rowHeight,list:GetHeight()
   for index,role in ipairs(item.roster.counts) do
    check(role.text:GetText()=="10" and role.text:GetUnboundedStringWidth()<=role.text:GetWidth()+.001,"two-digit role totals fit their text boxes at every font scale")
    check(role.text:GetWidth()>=20 and left(role.icon)==(index-1)*46,"enlarging role text preserves the fixed icon starting positions")
   end
   item.membersButton:Fire("OnClick","LeftButton")
   check(item.membersExpanded and item.count:IsShown() and not item.roster:IsShown(),"raid totals replace the role summary instead of adding a second line")
   local _,buttonY=position(item.membersButton,item);local _,countY=position(item.count,item)
   check(near(buttonY+item.membersButton:GetHeight()/2,countY+item.count:GetHeight()/2),"raid totals occupy the role summary's original vertical center")
   check(centered(item.count,item),"raid totals remain centered in the compact member row")
   check(list.rowHeight==height and list:GetHeight()==viewport,"showing raid totals does not change row height or viewport")
   item.membersButton:Fire("OnClick","LeftButton")
   check(not item.membersExpanded and not item.count:IsShown() and item.roster:IsShown(),"a second click restores the role summary")
   check(list.rowHeight==height and list:GetHeight()==viewport,"restoring roles does not change row height or viewport")
  end
  find.LayoutListRows=layoutRows
  check(layoutCalls==0,"switching raid summaries never requests a list reflow")
  check(find.appList.rowHeight>=application.meta:GetHeight()+8 and find.appList.rowHeight>=application.title:GetHeight()+8,"application stride fits its actual activity and title line boxes")
  g.apps[1]=nil;find:RefreshApplications();find.scopeToggle:Fire("OnClick","LeftButton")
  g.records[77].activity=g.Catalog:GetActivity(2);g.records[77].activityID=2;g.records[77].activityName=g.records[77].activity.name
  g.records[77].maxNumPlayers=5;g.records[77].numMembers=3;g.records[77].categoryID=2;g.records[77].details.counts={TANK=1,HEALER=1,DAMAGER=1};g:Notify("result",77);u.Motion:Tick(.016)
  if percent==100 then
   check(near(row:GetHeight(),u.Theme.findResultRowHeight) and near(row:GetHeight(),53),"100% results use the tighter single-row baseline")
   check(find.appList.rowHeight>=u.Theme.findApplicationRowHeight,"application stride preserves its base minimum")
   check(u.Theme.findApplicationRowHeight==44,"applications keep the enlarged forty-four-unit row baseline")
  end
  -- The captured preset may keep Description at its minimum at both rail widths.
  -- Give this growth/restore scenario a deliberately flexible description column.
  local descriptionPath="layout.tables.findResults.widths.description"
  local savedDescriptionWeight=a.Configuration:Get(descriptionPath)
  a.Configuration:Set({[descriptionPath]=.25},{storage="character"})
  find:SetSidebarCollapsed(false,false)
  local descriptionWidth=row.description:GetWidth()
  local expandedMainWidth,expandedContentWidth=find.main:GetWidth(),u.content:GetWidth()
  for _,collapsed in ipairs({true,false}) do
   find:SetSidebarCollapsed(collapsed,false)
   check(near(find.rail:GetWidth(),collapsed and 48 or 208),"category rail width changes with its state")
   local expectedMain=u.content:GetWidth()-find.rail:GetWidth()-u.Theme.contentGap-u.Theme.findContentInset*2
   check(near(find.main:GetWidth(),expectedMain),"main content uses the current host width after rail, gap and panel insets")
   check(near(find.main:GetWidth()-expandedMainWidth-(u.content:GetWidth()-expandedContentWidth),collapsed and 160 or 0),"collapsing the rail reclaims its complete one-hundred-sixty-unit width")
   local cell=find.resultsHeader.columns.description
   check(near(left(row.description),cell.x+4) and near(row.description:GetWidth(),cell.width-8),"the result description follows its compact resized table cell")
   check(collapsed and row.description:GetWidth()>descriptionWidth or not collapsed and near(row.description:GetWidth(),descriptionWidth),("the result description grows with reclaimed sidebar width and restores afterward (%s/%d/%s: %.3f, expanded %.3f)"):format(locale,percent,tostring(collapsed),row.description:GetWidth(),descriptionWidth))
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
   activityCell(row,find.resultsHeader)
   findEdges(find,u)
  end
  a.Configuration:Set({[descriptionPath]=savedDescriptionWeight},{storage="character"})
  -- A minimum reached with the narrow rail cannot be reused unchanged when
  -- expanding it: the target rail and both tables determine the new minimum.
  local beforeEdgeWidth,beforeEdgeHeight=u.windowWidth,u.windowHeight
  for _,animate in ipairs({false,true}) do
   a:SetSetting("reduceMotion",not animate)
   find:SetSidebarCollapsed(true,false);u:SetWindowSize(1,1)
   findEdges(find,u)
   find:SetSidebarCollapsed(false,animate)
   u.Motion:Tick(1)
   local required=u:GetWindowMinimum()
   check(near(find.rail:GetWidth(),208),"expanding the rail reaches its full width after shrinking the collapsed host")
   check(u.windowWidth+.001>=required,"expanding the rail grows a narrow host to its target content minimum")
   findEdges(find,u)
  end
  a:SetSetting("reduceMotion",true);u:SetWindowSize(beforeEdgeWidth,beforeEdgeHeight)
  find:SelectCategory("seasonDungeon");find:CommitChoice();find:SetFiltersOpen(true)
  check(find.quickPlacement=="popup" and find.quickFilters:GetParent()==find.importantFilters and find.importantFilters:IsShown(),"shared important filters default to the popup")
  check(find.filterPanel:GetWidth()>=560 and near(find.importantFilters:GetWidth(),find.filterViewport:GetWidth()),"seasonal conditions fill the scrollable body width")
  local roleRight,roleCenter
  for index,button in ipairs({find.quickChoices.tankPresence.button,find.quickChoices.healerPresence.button,find.quickChoices.damagePresence.button,find.quickIdentity,find.quickLogic}) do
   local x,y=position(button,find.importantFilters)
   check(x>=-.001 and x+button:GetWidth()<=find.importantFilters:GetWidth()+.001,"compact filter stays within its popup row")
   check(y>=-.001 and y+button:GetHeight()<=find.importantFilters:GetHeight()+.001,"compact filter stays within its popup height")
   check(button.label:GetStringWidth()<=button.label:GetWidth()+.001,"translated compact filter fits its text area")
   check(button:GetHeight()+.001>=button.label:GetStringHeight(),"compact filter height follows the selected font")
   if index<=3 then
    check(not roleRight or x>=roleRight+5.999,"three role controls retain their horizontal gap")
    check(not roleCenter or near(y+button:GetHeight()/2,roleCenter),"three role controls share one row")
    roleRight,roleCenter=x+button:GetWidth(),y+button:GetHeight()/2
   end
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
   check(find.quickPlacement==(show and "header" or "popup") and find.quickFilters:GetParent()==(show and find.applicationPanel or find.importantFilters) and find.importantFilters:IsShown()~=show,"the setting moves the same important filters between header and popup")
   check(find.quickFilterHeight==0,"important filters never reserve a second header row")
   check(near(top(find.applicationPanel),68) and near(find.applicationPanel:GetHeight(),44+(find.appsHeight or 0)),"applications keep their existing vertical geometry")
   check(near(top(find.applicationHeader),40),"application headings keep their original top inset")
   check(near(top(find.appList),44+find.applicationHeader:GetHeight()),"application rows retain their original top inset")
   check(find.filterPanel:GetWidth()>=(show and 460 or 560),"popup width fits the selected placement and translated grid labels")
   if show then
    u:SetWindowSize(1,1)
    findEdges(find,u)
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
    check(countX>=x+leading:GetWidth()-.001 and countX+find.appsBadge:GetWidth()<=filterX-.001,
     ("scope/title and count fit before the important filters (%s/%d: leading %.3f..%.3f, badge %.3f..%.3f, filters %.3f)"):format(locale,percent,x,x+leading:GetWidth(),countX,countX+find.appsBadge:GetWidth(),filterX))
   end
  end
  u:SetWindowSize(windowWidth,windowHeight)
  find:SetFiltersOpen(false)
  a.Notes:Remove(leaderKey)
  g.records[77]=nil
  g.records[99]={id=99,partyGUID="Font-rejection",name="Rejected group",activityID=2,activity=g.Catalog:GetActivity(2),activityName=string.rep(locale=="zhCN" and "很长的副本名称" or "Long dungeon activity ",6),categoryID=2,numMembers=1,maxNumPlayers=5,age=1}
  g.declinedParties["Font-rejection"]=GetTime();find:CommitChoice();find:DoSearch()
  local rejected=find.results.rows[1]
  local function CheckRejectionLayout()
   check(rejected.key==99 and rejected.declined:IsShown(),"geometry checks render a rejected result")
   local _,footerY=position(rejected.declined,rejected)
   for _,body in ipairs({rejected.title,rejected.meta,rejected.description}) do
    local _,bodyY=position(body,rejected)
    check(footerY+.001>=bodyY+body:GetHeight()+4,"the rejection footer follows every complete body cell with a gap")
   end
   check(footerY+rejected.declined:GetHeight()<=rejected:GetHeight()+.001,"rejection text exceeds the result row")
   check(rejected.declined:GetStringWidth()<=rejected.declined:GetWidth(),"the complete rejection text fits at the selected font size")
   local _,leaderY=position(rejected.leader,rejected)
   check(leaderY+rejected.leader:GetHeight()<=footerY+.001,"rejection text overlaps the leader column")
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
  if percent==100 then check(near(batch.people[1]:GetHeight(),math.max(u.Theme.createMemberHeight,math.ceil(batch.people[1].title:GetStringHeight()))),"the default applicant row fits its paired label lines") end
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
  people[1].dungeonScores={mapScore=300,current={name="Test dungeon with a long name",level=12,timed=true,durationMs=1952000,timeLimitSeconds=1980},best={name="Another dungeon with a long name",level=13,timed=false,durationMs=3903000,timeLimitSeconds=3600}}
  u.Tooltip:ShowPlayer(batch.people[1],people[1],batch.people[1].memberContext)
  local tip=u.Tooltip.interactive
  for _,metric in ipairs(tip.metrics) do
   if metric.value:IsShown() then check(near(metric.value:GetHeight(),metric.value:GetLineHeight()+metric.value:GetSpacing()),"player metric clips the scaled line height") end
  end
  check(separated(tip.dungeonTitle,tip.dungeonRows[1]),"dungeon records overlap their scaled heading")
  check(tip.dungeonRows[1].status:GetText()=="|cff7cd99b32:32|r/33:00" and tip.dungeonRows[2].status:GetText()=="|cff9d9d9d65:03|r/60:00","colored elapsed times retain their complete minutes and seconds without coloring the limits")
  for _,record in ipairs(tip.dungeonRows) do
   check(record.status:GetUnboundedStringWidth()<=record.status:GetWidth()+.001,"the complete dungeon time fits its column")
   local nameX=position(record.name,record);local timeX=position(record.status,record)
   check(nameX+record.name:GetWidth()+12<=timeX+.001,"the dungeon name does not overlap its time")
   check(record:GetHeight()+.001>=record.name:GetStringHeight(),"a long dungeon name stays within its row")
  end
  u.Tooltip:Hide()
  u.Tooltip:ShowRoster(create.frame,{{nameKey="Test-Home",class="WARRIOR",assignedRole="TANK",isLeader=true}},false,{rosterMode="members"})
  local leader=u.Tooltip.interactive.memberButtons[1];local crown=leader.leaderIcon
  local anchor={crown:GetPoint()}
  check(anchor[1]=="BOTTOM" and anchor[2]==leader.icon and anchor[3]=="TOP" and anchor[5]==1,"member crowns stay above the portrait with a gap")
  check(crown:GetWidth()==14 and crown:GetHeight()==14,"tooltip crowns remain readable beside the member portrait")
  check(crown.layer=="OVERLAY" and crown.sublevel==1,"the portrait cannot cover its leader crown")
  check(top(leader.icon)-1-crown:GetHeight()>=-.001,"the crown fits inside its row at every supported font size")
  check(top(leader.icon)+leader.icon:GetHeight()<=leader:GetHeight()+.001,"crown spacing keeps the portrait inside its row")
  leader:Fire("OnClick","LeftButton")
  local back=u.Tooltip.interactive.back
  check(back:IsShown(),"opening a roster member offers the group return action")
  back:Fire("OnEnter")
  local iconX=position(back.elementIcon,back);local labelX=position(back.label,back)
  local rightInset=back:GetWidth()-labelX-back.label:GetStringWidth()
  check(iconX>=11.999 and rightInset>=11.999,
   ("return-button hover encloses the arrow and full label with padding (%s/%d: left %.3f, right %.3f)"):format(locale,percent,iconX,rightInset))
  check(labelX>=iconX+back.elementIcon:GetWidth()+7.999,"return-button label leaves a gap after its arrow")
  check(centered(back.elementIcon,back) and centered(back.label,back),"return-button content shares the hover background's vertical center")
  check(back:GetHeight()+.001>=back.label:GetHeight()+12,"return-button hover leaves vertical padding at larger font sizes")
  check(back.hover:IsShown() and back.hover:GetAlpha()>0,"return-button pointer entry shows its existing hover background")
  local width,height=back:GetWidth(),back:GetHeight()
  back:Fire("OnMouseDown","LeftButton");back:Fire("OnMouseUp","LeftButton");back:Fire("OnLeave")
  check(near(back:GetWidth(),width) and near(back:GetHeight(),height),"hover and press do not change the return-button hit area")
  check(not back.hover:IsShown() or back.hover:GetAlpha()==0,"leaving the return action clears its hover")
  back:Fire("OnEnter");back:Fire("OnMouseDown","LeftButton");back:Fire("OnMouseUp","LeftButton");back:Fire("OnClick","LeftButton")
  check(u.Tooltip.member==nil and u.Tooltip.sourceRoster~=nil,"the padded return action still opens the source roster")
  u.Tooltip:Hide()
  a.Notes:Merge({{name="Example",server="Home",timestamp=1,reason="A sample note",type="positive"}})
  g.GetHistory=function() return {{mapName="Test dungeon",level=12,startedAt=1,completedAt=100,members={{name="Example",realm="Home",class="WARRIOR"}}}} end
  a:Open("notes")
  local notes=u.pages.notes;local item=notes.list.rows[1]
  check(not item.meta:IsShown() and item.meta:GetText()=="","note rows omit class and specialization text")
  check(separated(item.title,item.reason),"note title and reason overlap")
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
  check(near(find.results.rowHeight,u.Theme.findResultRowHeight) and near(find.results.rowHeight,53) and notes.list.rowHeight==92,"returning to 100% restores the compact result and unchanged note row geometry")
  check(top(create.titleLabel)==92 and top(create.titleShell)==116,"returning to 100% retains enlarged form geometry")
  a:SetSetting("fontScale",percent);a:Open("settings",{section="interface"})
  local settings=u.pages.settings
  local panel=settings.panels.interface
  check(#panel.rows==4,"interface settings group font, font size, window scale and motion together")
  local previous
  for _,entry in ipairs(panel.rows) do
   if previous then check(separated(previous,entry.frame),"appearance setting rows overlap") end
   check(entry.label:GetWidth()>0 and entry.frame:GetHeight()+.001>=entry.label:GetStringHeight()+32,
    ("appearance setting title fits its row after wrapping (%s/%d: %s)"):format(locale,percent,entry.label:GetText()))
   check(entry.frame:GetHeight()+.001>=entry.help:GetStringHeight()+32,"appearance setting description exceeds its row")
   previous=entry.frame
  end
  check(top(previous)+previous:GetHeight()<=panel:GetHeight()+.001,("all four interface rows fit their panel (%s/%d: %.2f/%.2f)"):format(locale,percent,top(previous)+previous:GetHeight(),panel:GetHeight()))
  if settings.reloadLanguage:IsShown() then
   check(separated(previous,settings.reloadLanguage),"reload action overlaps the fourth interface row")
   check(top(settings.reloadLanguage)+settings.reloadLanguage:GetHeight()<=panel:GetHeight()+.001,
    ("all four interface rows and reload action fit their panel (%s/%d: end %.3f, panel %.3f)"):format(locale,percent,top(settings.reloadLanguage)+settings.reloadLanguage:GetHeight(),panel:GetHeight()))
  end
  for _,entry in pairs(settings.controls) do
   if not entry.definition[4] then
    local control=entry.widget;local holder=control:GetParent()
    local controlX=position(control,holder);local trackX=position(control.track,holder)
    check(near(controlX+control:GetWidth(),holder:GetWidth()),"settings switches retain the row right edge")
    check(near(trackX+control.track:GetWidth(),holder:GetWidth()-12),"settings switch tracks retain their twelve-unit inset")
   end
  end
  local function CheckRange(control)
   local value=control.valueLabel;local valueX=position(value,control:GetParent())
   check(value:GetStringWidth()<=value:GetWidth(),"the complete percentage fits its measured label")
   check(value.justify=="RIGHT" and value.wrap==false,"percentage text remains right aligned without wrapping")
   check(near(valueX+value:GetWidth(),control:GetParent():GetWidth()-12),"percentage right edges align twelve units inside their rows")
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
