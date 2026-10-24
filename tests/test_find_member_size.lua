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
 Near(scale,1.2*.92*1.1,"default result party icons are ten percent larger")
 local width=roster:GetWidth()*scale
 local left=(row.membersButton:GetWidth()-width)/2
 for i,slot in ipairs(roster.slots) do
  Near(slot.icon:GetWidth()*scale,18*1.2*.92*1.1,"member avatars use the enlarged default size")
  local point={slot.icon:GetPoint()}
  local x=point[#point-1]
  local right=left+(x+slot.icon:GetWidth())*scale
  if slot.icon:IsShown() then
   Near(slot.role:GetWidth()*scale,10*1.2*.92*1.1,"occupied member role badges grow with their avatars")
   local badge={slot.role:GetPoint()}
   Check(badge[1]=="BOTTOMRIGHT" and badge[2]==slot.icon,"badges remain attached to the member avatar")
   right=right+badge[#badge-1]*scale
  else
   Near(slot.role:GetWidth()*scale,18*1.2*.92*1.1,"empty role slots use the same enlarged default size")
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
Check(not row.leaderIcon:IsShown() and not applied.leaderIcon:IsShown(),"search and application names no longer repeat the leader crown")

local oldColors,oldCustom=RAID_CLASS_COLORS,CUSTOM_CLASS_COLORS
RAID_CLASS_COLORS={WARRIOR={r=.8,g=.6,b=.4},PALADIN={r=.9,g=.4,b=.7}};CUSTOM_CLASS_COLORS=nil
members[2].isLeader=true;members[3].class="PALADIN";members[3].specID=66;Render()
local function Setting(key,value) A:SetSetting(key,value);page:RefreshMemberStyle() end
local function CrownCount()
 local count=0
 for _,slot in ipairs(row.roster.slots) do if slot.icon.memberLeaderMark and slot.icon.memberLeaderMark:IsShown() then count=count+1 end end
 return count
end
Check(CrownCount()==1 and row.roster.slots[2].icon.memberLeaderMark:IsShown(),"the native leader is marked in its actual member slot, not the first slot")
Setting("memberIconShape","circle");Setting("memberClassBorder",true)
for _,slot in ipairs(row.roster.slots) do
 Check(slot.icon._lycheeMask:GetTexture():find("member%-circle%-mask%.tga$")~=nil,"occupied result icons use the selected circular mask")
 Check(slot.icon.memberBorder and slot.icon.memberBorder:IsShown(),"occupied members receive a class-color border")
end
Near(row.roster.slots[3].icon.memberBorder.vertex[1],.9,"border colors follow each actual member class")
Setting("memberIconShape","square")
for _,slot in ipairs(row.roster.slots) do
 Check(slot.icon._lycheeMask:GetTexture()==U.Theme.media.."icon-mask.tga","square members reuse the original rounded icon silhouette")
 local border=slot.icon.memberBorder
 Check(border:GetTexture()==slot.icon._lycheeMask:GetTexture() and border.layer=="ARTWORK" and border.sublevel==-1,"the class-colored outline follows the same silhouette behind the avatar")
end
local border=row.roster.slots[1].icon.memberBorder
Setting("memberIconShape","circle")
Check(border.layer=="OVERLAY" and border.allPoints==row.roster.slots[1].icon,"switching back to circles restores their original overlay without leftover square anchors")
Setting("memberIconShape","square")
Check(row.roster.slots[1].icon.memberBorder==border and #border.points==2,"switching shapes reuses the border and restores the rounded-square outline")
Setting("memberClassBorder",false)
for _,slot in ipairs(row.roster.slots) do Check(not slot.icon.memberBorder:IsShown(),"border settings hide all existing result decorations") end
Setting("memberLeaderMark",false);Check(CrownCount()==0,"the crown setting hides existing leader marks")
Setting("memberClassBorder",true);Setting("memberLeaderMark",true)
members[2].isLeader=nil;record.leaderKey=nil;Render();Check(CrownCount()==0,"unknown leadership never assigns a crown by display order")
members[3].nameKey="Member3-Away";record.leaderKey="Member3-Away";Render()
Check(CrownCount()==1 and row.roster.slots[3].icon.memberLeaderMark:IsShown(),"a complete verified leader identity can locate its actual slot")
local header=page.resultsHeader;header:SetSort("rating",true)
local widthState=header.state.widths
for _,percent in ipairs({75,100,175,100}) do
 Setting("memberIconScale",percent)
 Near(row.roster:GetScale(),1.2*.92*1.1*percent/100,"saved member percentages apply to the enlarged default roster size")
 local cell=header.columns.members;local point={row.membersButton:GetPoint()};local start=point[#point-1]
 Check(start>=cell.x and start+row.membersButton:GetWidth()<=cell.x+cell.width+.001,"scaled members stay within the current resizable member cell")
 local scale=row.roster:GetScale();local left=(row.membersButton:GetWidth()-row.roster:GetWidth()*scale)/2
 for i,slot in ipairs(row.roster.slots) do
  local location={slot.icon:GetPoint()};local right=left+(location[#location-1]+slot.icon:GetWidth()+1)*scale
  Check(right<=row.membersButton:GetWidth()+.001,"the final scaled role badge stays inside the member area")
  if i<5 then local nextPoint={row.roster.slots[i+1].icon:GetPoint()};Check(right<=left+nextPoint[#nextPoint-1]*scale,"scaled badges stay clear of the next member") end
 end
 local crown=row.roster.slots[3].icon.memberLeaderMark
 Check(crown:GetHeight()*scale<=19.001,"leader marks retain the visual size cap at larger scales")
 local anchor={crown:GetPoint()};local gap=anchor[#anchor]*scale
 Near(gap,1,"crowns retain a visible gap above the avatar across icon scales")
 local rosterY=point[#point]
 Check(rosterY+10*scale+gap+crown:GetHeight()*scale<=row:GetHeight()/2+.001,"enlarged leader crowns remain inside the result row")
 Check(rosterY-10*scale>=-row:GetHeight()/2-.001,"moving a large crown into the row keeps the lower role badge inside")
 Check(page.resultsHeader==header and header.state.widths==widthState and header.state.sortKey=="rating" and header.state.descending,"member changes preserve the existing table and sort preferences")
end
record.details.members={members[1]};record.numMembers=1;Render()
for i=2,5 do
 local icon=row.roster.slots[i].icon
 Check(not icon.memberBorder:IsShown() and (not icon.memberLeaderMark or not icon.memberLeaderMark:IsShown()),"empty recycled slots release borders and leader marks")
 Near(row.roster.slots[i].role:GetWidth(),18,"missing-role placeholders keep their full existing size")
end
record.maxNumPlayers=30;record.categoryID=3;Render()
Check(CrownCount()==0,"raid role summaries never retain a member crown")
for _,slot in ipairs(row.roster.slots) do Check(not slot.icon.memberBorder:IsShown(),"raid role summaries do not retain member borders") end
record.maxNumPlayers=5;record.categoryID=2;record.numMembers=5;record.details.members=members;Render()
local nodes=#f.S.nodes;for _=1,20 do Render() end
Check(#f.S.nodes==nodes,"repeated native updates reuse masks, borders and crowns")
Near(applied.roster:GetScale(),1,"new result styles do not resize the application roster")
for _,slot in ipairs(applied.roster.slots) do Check(slot.icon.memberBorder==nil and slot.icon.memberLeaderMark==nil,"application members keep their original artwork") end
local unrelated=U.C.GameIcon(UIParent,24);U:SetMemberIcon(unrelated,members[3])
Check(unrelated.memberBorder==nil and not unrelated._lycheeMask:GetTexture():find("member%-"),"other member-icon consumers keep the shared library mask")
A:Open("settings",{section="memberIcons"});local settings=U.pages.settings
Check(settings.section=="memberIcons" and settings.controls.memberIconShape~=nil,"all member controls have a dedicated settings section")
local slider=settings.controls.memberIconScale.widget.slider
Check(slider:GetMinMaxValues()==75 and select(2,slider:GetMinMaxValues())==175,"member settings expose the adopted percentage range")
for _,percent in ipairs({70,100,130}) do
 A:SetSetting("fontScale",percent)
 local panel=settings.panels.memberIcons;local last=panel.rows[#panel.rows];local point={last.frame:GetPoint()}
 Check(-point[#point]+last.frame:GetHeight()<=panel:GetHeight()+.001,"member settings remain readable within the page at every supported font size")
end
RAID_CLASS_COLORS,CUSTOM_CLASS_COLORS=oldColors,oldCustom

-- Every five-slot search category distinguishes vacancies from occupied roles.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=fresh.A,fresh.U,fresh.G
 local activityInfo,categoryInfo=C_LFGList.GetActivityInfoTable,C_LFGList.GetLfgCategoryInfo
 local groups,activities=C_LFGList.GetAvailableActivityGroups,C_LFGList.GetAvailableActivities
 local extras={
  [501]={id=501,categoryID=121,fullName="Delve",shortName="Delve",groupFinderActivityGroupID=501,maxNumPlayers=5},
  [601]={id=601,categoryID=6,fullName="Custom party",shortName="Custom",groupFinderActivityGroupID=601,maxNumPlayers=5},
 }
 C_LFGList.GetAvailableCategories=function()return {2,3,121,6}end
 C_LFGList.GetActivityInfoTable=function(id)return extras[id] or activityInfo(id)end
 C_LFGList.GetLfgCategoryInfo=function(id)if id==121 or id==6 then return {name=id==121 and "Delves" or "Custom",allowCrossFaction=true}end;return categoryInfo(id)end
 C_LFGList.GetAvailableActivityGroups=function(id)if id==121 then return {501}elseif id==6 then return {601}end;return groups(id)end
 C_LFGList.GetAvailableActivities=function(id,group,flags)if id==121 then return {501}elseif id==6 then return {601}end;return activities(id,group,flags)end
 local people={{name="Tank",class="WARRIOR",assignedRole="TANK",specID=73},{name="Healer",class="PRIEST",assignedRole="HEALER",specID=257}}
 local r={id=941,name="Two members",maxNumPlayers=5,numMembers=2,details={members=people,counts={TANK=1,HEALER=1,DAMAGER=0},encounters={}}}
 g.records[941]=r
 a:Open("find");local p=u.pages.find
 for _,selection in ipairs({{"seasonDungeon",2},{"2",3},{"121",501},{"6",601}}) do
  r.activityID=selection[2];r.activity=g.Catalog:GetActivity(r.activityID);r.categoryID=r.activity.categoryID
  r.maxNumPlayers=5;r.numMembers=2;r.details.members={people[1],people[2]}
  p:SelectCategory(selection[1]);p:CommitChoice();p:DoSearch();u.Motion:Tick(.25)
  local current=p.results.rows[1];Check(current.key==941,"the selected category renders its real result row")
  for i,slot in ipairs(current.roster.slots) do
   Check(slot.role.desaturated==(i>2),selection[1].." vacancies must be gray while occupied badges remain colored")
   Near(slot.role.vertex[1],i>2 and .7 or 1,"vacancy brightness follows the existing missing-role shade")
  end
  for i=3,5 do r.details.members[i]={name="Damage"..i,class="MAGE",assignedRole="DAMAGER",specID=63}end
  r.numMembers=5;g:Notify("result",941);u.Motion:Tick(.016)
  for _,slot in ipairs(current.roster.slots) do
   Check(slot.icon:IsShown() and slot.role.desaturated==false,"a newly occupied slot restores its colored badge")
   Near(slot.role.vertex[1],1,"recycled occupied slots restore normal brightness")
  end
 end
 u:Hide(true)
end
print(("[PASS] find member size: %d geometry checks"):format(checks))
