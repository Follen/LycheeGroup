-- Focused offline geometry checks; run: lua tests/test_find_member_size.lua
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G=f.A,f.U,f.G
local checks=0
local function Check(condition,message) checks=checks+1;assert(condition,message) end
local function Near(actual,expected,message) Check(math.abs(actual-expected)<.001,message) end
local members={}
for i,role in ipairs({"TANK","HEALER","DAMAGER","DAMAGER","DAMAGER"}) do
 members[i]={name="Member"..i,class="WARRIOR",assignedRole=role,specID=71}
end
local record={id=41,name="Party",activityID=2,categoryID=2,maxNumPlayers=5,numMembers=5,
 details={members=members,counts={TANK=1,HEALER=1,DAMAGER=3},encounters={}}}
record.activity=G.Catalog:GetActivity(2)
G.records[41]=record
A:Open("find");U.Motion:Tick(.25)
local page=U.pages.find
page:CommitChoice()
page:DoSearch();U.Motion:Tick(.25)
local row=page.results.rows[1]
Check(row.key==41,"the fixture must render the actual result row")
local function Render() G:Notify("result",41);U.Motion:Tick(.016) end
local function PartyGeometry()
 local roster=row.roster
 local scale=roster:GetScale()
 Near(scale,1.2*1.15,"only result party members gain 15 percent scale")
 local width=roster:GetWidth()*scale
 local left=(row.membersButton:GetWidth()-width)/2
 for i,slot in ipairs(roster.slots) do
  Near(slot.icon:GetWidth()*scale,18*1.2*1.15,"member avatars gain 15 percent")
  local point={slot.icon:GetPoint()}
  local x=point[#point-1]
  local right=left+(x+slot.icon:GetWidth())*scale
  if slot.icon:IsShown() then
   Near(slot.role:GetWidth()*scale,10*1.2*1.15,"occupied member role badges gain 15 percent")
   local badge={slot.role:GetPoint()}
   Check(badge[1]=="BOTTOMRIGHT" and badge[2]==slot.icon,"badges remain attached to the member avatar")
   right=right+badge[#badge-1]*scale
  else
   Near(slot.role:GetWidth()*scale,18*1.2*1.15,"empty role slots match the enlarged member size")
  end
  Check(left+x*scale>=-.001 and right<=138.001,"every enlarged slot and badge fits the 138-unit member column")
  if i<5 then
   local nextPoint={roster.slots[i+1].icon:GetPoint()}
   Check(right<=left+nextPoint[#nextPoint-1]*scale,"the enlarged badge does not overlap the next member")
  end
 end
 local memberPoint={row.membersButton:GetPoint()}
 local itemPoint={row.ilvl:GetPoint()}
 Check(memberPoint[#memberPoint-1]+138<itemPoint[#itemPoint-1],"the member column stays clear of item level")
end
PartyGeometry()
record.details.members={members[1]};record.numMembers=1;Render();PartyGeometry()
record.maxNumPlayers=30;record.categoryID=3;record.numMembers=20;Render()
Near(row.roster:GetScale(),1,"raid role summaries retain their original scale")
for _,count in ipairs(row.roster.counts) do
 Near(count.icon:GetWidth(),16,"raid count icons retain their original size")
 Check(count.icon:IsShown(),"raid role counts remain visible")
end
record.maxNumPlayers=5;record.categoryID=2;record.numMembers=5;record.details.members=members;Render();PartyGeometry()
local appRecord={id=42,name="Applied party",activityID=2,categoryID=2,maxNumPlayers=5,numMembers=5,details=record.details}
appRecord.activity=record.activity
G.apps={{id=42,name=appRecord.name,status="applied",result=appRecord}}
G:Notify("applications");U.Motion:Tick(.016)
local applied=page.appList.rows[1]
Check(applied.key==42,"the fixture must render an application row")
Near(applied.roster:GetScale(),1,"application members retain their original scale")
Near(applied.roster:GetWidth(),110,"application members retain their original spacing")
Near(applied.roster.slots[1].icon:GetWidth(),18,"application avatars retain their original size")
Near(applied.roster.slots[1].role:GetWidth(),10,"application badges retain their original size")
print(("[PASS] find member size: %d geometry checks"):format(checks))
