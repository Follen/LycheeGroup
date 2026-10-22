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
  check(top(create.batchScroll)>=top(create.applicantHeaders.name)+create.applicantHeaders.name:GetHeight(),"applicant headers overlap the viewport")
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
  a.Notes:Merge({{name="Example",server="Home",timestamp=1,reason="A sample note",type="positive"}})
  g.GetHistory=function() return {{mapName="Test dungeon",level=12,startedAt=1,completedAt=100,members={{name="Example",realm="Home",class="WARRIOR"}}}} end
  a:Open("notes")
  local notes=u.pages.notes;local item=notes.list.rows[1]
  check(separated(item.title,item.meta),"note title and identity overlap")
  check(separated(item.meta,item.reason),"note identity and reason overlap")
  check(top(item.reason)+item.reason:GetHeight()<=item:GetHeight(),"note reason exceeds its row")
  notes:SelectTab("history");notes:OpenRun(1)
  for _,list in ipairs({notes.historyList,notes.historyModal.list}) do
   local entry=list.rows[1]
   check(separated(entry.title,entry.meta),"history title and metadata overlap")
   check(top(entry.meta)+entry.meta:GetHeight()<=entry:GetHeight(),"history metadata exceeds its row")
  end
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
  u:Hide(true)
 end
end
print("Font layout: "..count.." geometry checks passed")
