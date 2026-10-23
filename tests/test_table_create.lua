-- Focused applicant table checks: lua tests/test_table_create.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Near(a,b,message) Check(math.abs(a-b)<.001,message) end
local function X(region) local point={region:GetPoint()};return point[#point-1] end
local function Top(region) local point={region:GetPoint()};return -point[#point] end
local function Order(page,expected,message)
 Check(#page.appIDs==#expected,message.." count")
 for i,id in ipairs(expected) do Check(page.appIDs[i]==id,message.." item "..i) end
end
local function Click(header,key)
 for _,button in ipairs(header.buttons) do
  if button:IsShown() and button.definition.key==key then button:Fire("OnClick","LeftButton");return end
 end
 error("missing header "..key)
end
local function Batch(page,id)
 for _,batch in ipairs(page.batchPool) do if batch:IsShown() and batch.appID==id then return batch end end
 error("missing applicant batch "..id)
end
local function Member(name,rating,map,ilvl)
 return {name=name,nameKey=name,class="WARRIOR",assignedRole="DAMAGER",rating=rating,itemLevel=ilvl,dungeonScores={mapScore=map}}
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g,s=f.A,f.U,f.G,f.S;a:SetSetting("reduceMotion",true)
 a.Configuration:Set({["layout.tables.createApplicants.sortKey"]=false,["layout.tables.createApplicants.descending"]=false},{storage="character"})
 local long=locale=="zhCN" and "很长的申请人姓名-很长的服务器名称" or "LongApplicantName-LongServerName"
 g.listing={name="Table test",activityID=2,comment="",requiredItemLevel=0}
 g.applicants={
  [1]={id=1,status="applied",displayOrderID=1,comment="Friends stay together",members={Member(long,100,100,250),Member(long.."2",400,500,280)}},
  [2]={id=2,status="applied",displayOrderID=2,members={Member("Two-Home",200,50,270)}},
  [3]={id=3,status="applied",displayOrderID=3,members={Member("Three-Home",300,200,260)}},
 }
 a:Open("create");local page=u.pages.create;local header=page.applicantTable
 Order(page,{1,2,3},"default display order")
 Check(header.state==u:GetTablePrefs("createApplicants"),"applicant table uses character preferences")
 Check(#header.definitions==8,"keystone applicants show both score columns")
 Click(header,"rating");Order(page,{1,2,3},"rating ascending uses the weakest friend")
 Check(page.sortChoice.value=="score" and header.state.descending==false,"dropdown follows ascending rating")
 Check(page.sortChoice.label:GetText()==u.L.rating,"dropdown keeps its plain label without direction arrows")
 Click(header,"rating");Order(page,{3,2,1},"rating descending keeps the batch intact")
 Click(header,"mapScore");Order(page,{2,1,3},"dungeon score ascending uses the weakest friend")
 Click(header,"mapScore");Order(page,{3,1,2},"dungeon score descending")
 Click(header,"ilvl");Order(page,{1,3,2},"item level ascending")
 Click(header,"ilvl");Order(page,{2,3,1},"item level descending")
 f.Pick(page.sortChoice,"score");Order(page,{3,2,1},"dropdown retains descending numeric sorting")
 Check(header.state.sortKey=="rating" and header.state.descending,"dropdown and header share sorting state")
 f.Pick(page.sortChoice,"newest");Order(page,{1,2,3},"dropdown restores original display order")
 Check(header.state.sortKey==nil,"newest removes the numeric sort marker")
 Check(g.applicants[1].members[1].name==long and #g.applicants[1].members==2,"sorting never mutates friends or source order")

 g.applicants[4]={id=4,status="applied",displayOrderID=5,members={Member("Known-Home",999,999,999),Member("Unknown-Home")}}
 g.applicants[5]={id=5,status="applied",displayOrderID=4,members={Member("UnknownOne-Home"),Member("UnknownTwo-Home")}}
 g.applicants[6]={id=6,status="applied",displayOrderID=6,members={Member("Zero-Home",0,0,0)}}
 page:RefreshApplicants()
 for _,entry in ipairs({
  {key="rating",ascending={6,1,2,3,5,4},descending={3,2,1,6,5,4}},
  {key="mapScore",ascending={6,2,1,3,5,4},descending={3,1,2,6,5,4}},
  {key="ilvl",ascending={6,1,3,2,5,4},descending={2,3,1,6,5,4}},
 }) do
  Click(header,entry.key);Order(page,entry.ascending,"ascending keeps zero numeric and partial/all unknown batches last for "..entry.key)
  Click(header,entry.key);Order(page,entry.descending,"descending keeps unknown batches last in display order for "..entry.key)
 end
 g.applicants[4],g.applicants[5],g.applicants[6]=nil,nil,nil
 f.Pick(page.sortChoice,"newest")

 local mouse=IsMouseButtonDown;IsMouseButtonDown=function() return true end
 local refreshes,scans=0,0;local refresh,scan=g.RefreshApplicants,g.GetApplicants
 g.RefreshApplicants=function(self,...) refreshes=refreshes+1;return refresh(self,...) end
 g.GetApplicants=function(self,...) scans=scans+1;return scan(self,...) end
 header.mouseOver=true;header:Fire("OnEnter")
 Check(header.handles[1].line:IsShown(),"hover reveals the column divider")
 header.handles[1]:Fire("OnMouseDown","LeftButton")
 s.cursorX=s.cursorX-100*header:GetEffectiveScale();header:UpdateDrag()
 Near(header.columns.name.width,header.columns.name.minimum,"name drag respects its minimum")
 local batch=Batch(page,1)
 Check(#batch.people==2 and batch.people[1].member==g.applicants[1].members[1] and batch.people[2].member==g.applicants[1].members[2],"dragging preserves the friends batch")
 for i,row in ipairs(batch.people) do
  Check(X(row.title)+row.title:GetWidth()<=header.columns.role.x+.001,"wrapped applicant names stay within their column")
  Check(row:GetHeight()+.001>=row.title:GetStringHeight(),"dragging grows rows for wrapped names")
  if i>1 then Check(Top(row)>=Top(batch.people[i-1])+batch.people[i-1]:GetHeight(),"wrapped friend rows do not overlap") end
 end
 Check(refreshes==0 and scans==0,"dragging never refreshes or rescans native applicant data")
 header.handles[1]:Fire("OnMouseUp","LeftButton")
 local ratio=header.state.widths.name
 Check(ratio~=nil and header:GetScript("OnUpdate")==nil,"releasing saves proportions and stops the drag task")
 for _,percent in ipairs({70,100,130}) do
  a:SetSetting("fontScale",percent);batch=Batch(page,1)
  local endX=0
  for _,definition in ipairs(header.definitions) do
   local cell=header.columns[definition.key]
   Near(cell.x,endX,"column boundaries remain contiguous");Check(cell.width>=cell.minimum-.001,"columns retain their minimum")
   local label=header.labels[definition.key]
   Check(X(label)>=0 and X(label)+label:GetWidth()<=cell.width+.001,"header text stays inside its cell button")
   Check(label:GetUnboundedStringWidth()<=label:GetWidth()+.001,"complete translated header text fits at the selected font size")
   endX=cell.x+cell.width
  end
  Near(endX,page.batchScroll:GetWidth(),"table and batch viewport share their full width")
  for _,row in ipairs(batch.people) do
   Check(row:GetHeight()+.001>=row.title:GetStringHeight(),"font changes preserve wrapped name height")
   Check(X(row.ilvl)>=header.columns.ilvl.x and X(row.ilvl)+row.ilvl:GetWidth()<=header.columns.ilvl.x+header.columns.ilvl.width+.001,"item level follows its resized column")
  end
  Check(X(batch.comment)>=header.columns.comment.x and X(batch.comment)+batch.comment:GetWidth()<=header.columns.actions.x+.001,"comment stays before actions")
  Check(X(batch.invite)>=header.columns.actions.x and X(batch.decline)+batch.decline:GetWidth()<=header.columns.actions.x+header.columns.actions.width+.001,"invite and decline stay within the action column")
 end
 a:SetSetting("fontScale",100)
 for i,definition in ipairs(header.definitions) do if definition.key=="comment" then
  header:StartDrag(i);s.cursorX=s.cursorX+1000*header:GetEffectiveScale();header:UpdateDrag()
  Near(header.columns.actions.width,102,"the action column stops before its two buttons are clipped")
  batch=Batch(page,1)
  Check(X(batch.decline)+batch.decline:GetWidth()<=header.columns.actions.x+header.columns.actions.width+.001,"actions fit when the adjacent column is dragged to its maximum")
  header:StopDrag(true);ratio=header.state.widths.name;break
 end end
 Click(header,"mapScore");g.listing.activityID=3;g:Notify("listing")
 Check(#header.definitions==7 and header.labels.mapScore==nil,"ordinary dungeons omit the unavailable dungeon score")
 Check(page.sortChoice.value=="newest" and header.state.sortKey==nil,"hiding the selected score clears its sorting state")
 Click(header,"rating");g.listing.activityID=1;g:Notify("listing")
 Check(#header.definitions==6 and header.labels.rating==nil,"raid applicants omit score columns")
 Check(header.state.sortKey==nil and page.sortChoice.value=="newest","raid applicants clear unavailable rating sorting")
 Click(header,"ilvl");Order(page,{1,3,2},"raids retain numeric item level sorting")
 g.Catalog.activities[4]={id=4,categoryID=4,isPvpActivity=true,isRatedPvpActivity=true,maxNumPlayers=3,fullName="Rated PvP"}
 g.listing.activityID=4;g:Notify("listing")
 Check(#header.definitions==7 and header.labels.rating~=nil and header.labels.mapScore==nil,"rated PvP uses the single-rating variant")
 g.listing.activityID=2;g:Notify("listing")
 Check(header.labels.rating~=nil and header.labels.mapScore~=nil,"returning to keys restores both score columns")
 f.Pick(page.sortChoice,"newest");header:StartDrag(1);u:Navigate("settings")
 Check(header.drag==nil and header:GetScript("OnUpdate")==nil,"leaving recruitment stops and commits the active drag")
 u:Navigate("create");Near(header.state.widths.name,ratio,"reentering keeps the saved proportions")
 local realPrefs=header.state
 dofile("addon/LycheeGroup/Entrypoints.lua");Check(a:Preview("applicants"),"applicant preview opens")
 Check(header.state~=realPrefs and header.state==u:GetTablePrefs("createApplicants"),"preview isolates applicant table preferences")
 Click(header,"rating");Check(realPrefs.sortKey==nil,"preview sorting does not change real preferences")
 u:StopPreview(true);Check(header.state==realPrefs,"leaving preview restores the real table state")
 IsMouseButtonDown=mouse;g.RefreshApplicants,g.GetApplicants=refresh,scan;u:Hide(true)
end
print("Applicant tables: "..checks.." checks passed")
