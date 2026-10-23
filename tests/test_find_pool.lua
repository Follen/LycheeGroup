-- Empty Find lists keep only shared spare rows and grow from real visible data.
local f=dofile("tests/ui_fixture.lua")("enUS",nil,nil,{schema=1,id="fixture.find.pool",revision=1,appearance={main={elements={["find.application"]={instances={[503]={base={title={alpha=.39}}}}}}}}})
local A,U,G=f.A,f.U,f.G
-- Native order deliberately leaves the marked ID at the end for scroll/rebind checks.
A.Configuration:Set({["layout.tables.findResults.sortKey"]=false,["layout.tables.findResults.descending"]=false},{storage="character"})
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Near(a,b,message) Check(math.abs(a-b)<.001,message) end
A:SetSetting("reduceMotion",true);A:Open("find")
local page=U.pages.find
Check(#page.results.rows==2 and #page.appList.rows==2,"empty result and application lists do not prebuild a full viewport")
U:SetWindowSize(U.windowWidth+180,U.windowHeight+100)
U:ApplyFont(A.Fonts:GetPath(),1.3)
Check(#page.results.rows==2 and #page.appList.rows==2,"resizing and changing font on empty lists creates no unused rows")
Check(A.API.Appearance.SetElement==nil,"runtime element mutation is not exposed")
local activity=G.Catalog:GetActivity(2)
for id=1,30 do
 G.records[id]={id=id,name="Result "..id,leaderName="Leader"..id.."-Away",leaderKey="Leader"..id.."-Away",activity=activity,activityID=2,activityName=activity.name,categoryID=2,maxNumPlayers=5,numMembers=1,partyGUID="pool-"..id,age=id,
  details={members={{name="Member"..id,class="WARRIOR",assignedRole="TANK",specID=73}},counts={TANK=1,HEALER=0,DAMAGER=0}}}
end
local markedLeader="Verylongleadernameforpoolcolumntruncation"
local markedKey=markedLeader.."-Home"
A.Notes:Add(markedLeader,"Home","Pooled leader marks",nil,nil,{type="caution"})
local marked=G.records[30]
marked.leaderName,marked.leaderKey=markedKey,markedKey
marked.bnetFriends,marked.charFriends,marked.guildMates=1,1,1
marked.details.members[1].name,marked.details.members[1].nameKey,marked.details.members[1].isLeader=markedKey,markedKey,true
for index=1,5 do G.apps[index]={id=500+index,name="Application "..index,leaderName="Leader-Away",categoryID=2,status="applied",expiresAt=500+index,result=G.records[index]} end
page:CommitChoice();page:DoSearch();page:RefreshApplications()
Check(#page.results.ids==30 and #page.results.rows>2 and #page.results.rows<30,"all results remain available through a pool limited to the visible window")
Check(#page.appList.ids==5 and #page.appList.rows>2,"new pinned applications grow their actual compact row pool")
local row=page.appList.rows[3]
Check(row.key==503 and row.cancel and row.roster,"new application rows receive their complete product widgets")
Near(row.title:GetAlpha(),.39,"a newly created application inherits the preloaded keyed override")
Near(row.title:GetWidth(),page.applicationHeader.columns.title.width-6,"new application title width uses its independent text column")
Near(select(2,row.title:GetFont()),19*1.3,"new application rows use the current scaled single-line font")
local activityPoint={row.meta:GetPoint()};local activityCell=page.applicationHeader.columns.activity
Near(activityPoint[#activityPoint-1],activityCell.x+36,"new application activities reserve their own artwork and text gap")
Near(row.meta:GetWidth(),activityCell.width-42,"new application activities share the same artwork and text insets as existing rows")
Check(row.meta:GetText()==activity.name,"a newly created application preserves the complete native activity name")
local iconPoint={row.icon:GetPoint()}
Near(iconPoint[#iconPoint-1],activityCell.x+6,"new application artwork stays inside the activity cell")
Near(row.icon:GetWidth(),24,"new application artwork keeps its unscaled size")
Near(page.results.rows[1]:GetWidth(),page.main:GetWidth(),"new result backgrounds span the full main panel")
Near(row:GetWidth(),page.main:GetWidth()-32,"new application rows keep exactly the panel's sixteen-unit side insets")
Near(page.results:GetWidth()-page.results.rows[1]:GetWidth(),14,"the result scrollbar is outside the row's usable width")
Near(page.appList:GetWidth()-row:GetWidth(),14,"the application scrollbar is outside the row's usable width")
local point={row.cancel:GetPoint()};local actions=page.applicationHeader.columns.actions
Near(point[#point-1],actions.x+actions.width/2,"new application actions use the current table-column center")
page.results:SetPixelOffset(100000,false)
local last=false;local markedRow
for _,entry in ipairs(page.results.rows) do if entry.key==30 then last=true;markedRow=entry end end
Check(last,"scrolling reaches the final result beyond the original viewport")
Check(markedRow.marks.icons.bnet:IsShown() and markedRow.marks.icons.friend:IsShown() and markedRow.marks.icons.guild:IsShown() and markedRow.marks.icons.caution:IsShown(),"a reused offscreen result acquires all current leader marks")
local markAnchor={markedRow.marks:GetPoint()};local leaderPoint={markedRow.leader:GetPoint()};local leaderCell=page.resultsHeader.columns.leader
Check(markAnchor[2]==markedRow.leader and markAnchor[3]=="RIGHT" and markAnchor[4]==6,"newly bound result marks follow the current leader name")
Check(leaderPoint[#leaderPoint-1]+markedRow.leader:GetWidth()+6+markedRow.marks:GetWidth()<=leaderCell.x+leaderCell.width-4+.001,"all pooled leader marks fit their current resized column")
Check(markedRow.meta:GetText()==activity.name,"pooled leader marks do not replace or shorten activity-name data")
Near(markedRow.meta:GetWidth(),page.resultsHeader.columns.activity.width-38,"leader marks never take space from a pooled activity cell")
page.results:SetPixelOffset(0,false)
Check(markedRow.key~=30 and not markedRow.marks:IsShown(),"reusing the marked row for another result clears its former leader marks")
page.results:SetPixelOffset(100000,false)
page.appList:SetPixelOffset(100000,false)
last=false;for _,entry in ipairs(page.appList.rows) do if entry.key==505 then last=true end end
Check(last,"scrolling keeps all five pinned applications reachable")
local highWater=#f.S.nodes
for _=1,5 do page:RefreshResults();page:RefreshApplications() end
Check(#f.S.nodes==highWater,"unchanged data reuses the grown native row pools")
local resultFirst,applicationFirst=page.results.rows[1],page.appList.rows[1]
G.records={};G.apps={};page:RefreshResults();page:RefreshApplications()
for _,entry in ipairs(page.results.rows) do Check(entry.key==nil and not entry:IsShown(),"emptying results releases each old result binding") end
for _,entry in ipairs(page.appList.rows) do Check(entry.key==nil and not entry:IsShown(),"emptying applications releases each old application binding") end
Check(page.results.rows[1]==resultFirst and page.appList.rows[1]==applicationFirst,"clearing data preserves the reusable native row objects")
highWater=#f.S.nodes;page:RefreshResults();page:RefreshApplications()
Check(#f.S.nodes==highWater,"repeating the empty state creates no additional objects")
U:Hide(true)
print("Find lazy pool checks passed: "..checks)
