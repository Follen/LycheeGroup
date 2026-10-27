-- Standalone: lua tests/test_find_row_geometry.lua
-- Production result-row layout: stable refresh, rebind and geometry invalidation.
local Fixture=dofile("tests/ui_fixture.lua")
local journalDifficulty,journalInstance,journalEncounter=EJ_GetDifficulty,EJ_SelectInstance,EJ_GetEncounterInfoByIndex
local checks=0
local function Eq(a,b,why)
 checks=checks+1;if T then T.eq(a,b,why) else assert(a==b,(why or "value")..": "..tostring(a).." ~= "..tostring(b)) end
end
local function Ok(value,why) Eq(not not value,true,why) end
local function Same(a,b,why)
 if type(a)~="table" or type(b)~="table" then Eq(a,b,why);return end
 for key,value in pairs(b) do Same(a[key],value,why) end
 for key in pairs(a) do Ok(b[key]~=nil,why) end
end
local fixed={"title","meta","icon","leader","ilvl","score","description","age","declined"}
local function Point(region)
 local p={region:GetPoint()};if type(p[2])=="number" then return p[2],p[3] end
 return p[4] or 0,p[5] or 0
end
local function Projection(row)
 local out={key=row.key,title=row.title:GetText(),leader=row.leader:GetText(),party=row.isParty}
 for _,field in ipairs(fixed) do local r=row[field];local x,y=Point(r);out[field]={x=x,y=y,w=r:GetWidth(),h=r:GetHeight(),text=r.GetText and r:GetText() or nil} end
 return out
end
local function Track(row)
 local count={point=0,clear=0,width=0,members=0};local restores={}
 local function Wrap(owner,key,kind)
  local original=owner[key];owner[key]=function(self,...) count[kind]=count[kind]+1;return original(self,...) end
  restores[#restores+1]=function() owner[key]=original end
 end
 for _,field in ipairs(fixed) do Wrap(row[field],"SetPoint","point");Wrap(row[field],"ClearAllPoints","clear");Wrap(row[field],"SetWidth","width") end
 Wrap(row.roster,"ClearAllPoints","members")
 function count:Reset() self.point,self.clear,self.width,self.members=0,0,0,0 end
 function count:Restore() for _,restore in ipairs(restores) do restore() end end
 return count
end
local function Open(locale,theme,definition)
 local f=Fixture(locale,nil,nil,definition)
 if theme=="frosted" then assert(f.A.API.Theme:Activate("lycheegroup.frosted"));f=Fixture(locale,f.A.charPrefs,f.A.db) end
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 EJ_GetDifficulty=function() return 14 end;EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
 local activity=f.G.Catalog:GetActivity(2)
 for id=1,48 do
  f.G.records[id]={id=id,name="Group "..id,leaderName="Leader"..id.."-Away",leaderKey="Leader"..id.."-Away",activity=activity,activityID=2,activityName=activity.name,categoryID=2,maxNumPlayers=5,numMembers=1,age=id,partyGUID="Geometry-"..id,bnetFriends=0,charFriends=0,guildMates=0,
   details={members={{name="Leader"..id.."-Away",nameKey="Leader"..id.."-Away",class="MAGE",assignedRole="DAMAGER",isLeader=true}},counts={TANK=0,HEALER=0,DAMAGER=1}}}
 end
 local page=f.U.pages.find;page:CommitChoice();page:DoSearch();page:RefreshResults()
 return f,page
end

for _,locale in ipairs({"zhCN","enUS"}) do for _,theme in ipairs({"default","frosted"}) do
 local f,p=Open(locale,theme);local row=p.results.rows[1];local c=Track(row)
 local stable=Projection(row)
 for _=1,20 do p:RefreshResults() end
 Eq(c.point,0,"stable refresh must not rewrite fixed result anchors")
 Eq(c.clear,0,"stable refresh must not clear fixed result anchors")
 Eq(c.width,0,"stable refresh must not rewrite fixed result widths")
 Ok(c.members>=20,"member content layout still runs on every refresh")
 Same(Projection(row),stable,"stable visible output is identical")
 local record=f.G.records[row.key];record.leaderName="A very long updated leader-Away";record.bnetFriends=1
 p:RefreshResults();Eq(row.leader:GetText(),"A very long updated leader")
 Ok(row.marks:IsShown());Ok(row.leader:GetWidth()<=stable.leader.w,"changed marks and leader content still constrain the leader column")
 local changed=Projection(row);c:Reset();p:RefreshResults();Same(Projection(row),changed);Eq(c.point,0)
 -- The same bound row changes its footer offset without a new result identity.
 for _,r in pairs(f.G.records) do f.G.declinedParties[r.partyGUID]=GetTime()-1 end
 c:Reset();p:RefreshResults();Ok(c.point>0,"decline offset relayouts fixed columns")
 local _,y=Point(row.title);Eq(y,p.resultFooterHeight/2)
 for _,r in pairs(f.G.records) do f.G.declinedParties[r.partyGUID]=nil end
 p:RefreshResults();local _,clearY=Point(row.title);Eq(clearY,0)
 -- Actual header drag changes both adjacent columns, then leaves stable rows.
 local mouse=IsMouseButtonDown;local pressed=true;IsMouseButtonDown=function() return pressed end
 local h=p.resultsHeader;local oldWidth=h.columns.title.width
 f.S.cursorX=400;h.handles[1]:Fire("OnMouseDown","LeftButton");f.S.cursorX=416;h:Fire("OnUpdate",.016);pressed=false;h:Fire("OnUpdate",.016);IsMouseButtonDown=mouse
 Ok(h.columns.title.width~=oldWidth,"real header drag changes geometry")
 Eq(row.title:GetWidth(),h.columns.title.width-f.U.Theme.findResultTitleX-f.U.Theme.findColumnInset)
 c:Reset();p:RefreshResults();Eq(c.point,0,"dragged columns are stable after commit")
 for _,scale in ipairs({70,130,100}) do
  f.A:SetSetting("fontScale",scale);p:RefreshResults()
  local x=Point(row.meta);Eq(x,h.columns.activity.x+f.U.Theme.findColumnInset+f.U.Theme.findResultIconSize+6,"font reflow keeps activity text aligned")
  c:Reset();p:RefreshResults();Eq(c.point,0,"font reflow publishes a reusable fixed geometry")
 end
 -- Pool rows rebind and a Clear/Release to the same result key must repair
 -- their normal geometry even when no column or footer input changed.
 local key=row.key;p.results:SetPixelOffset(8*p.results.rowHeight,false);Ok(row.key~=key)
 p.results:SetPixelOffset(0,false);Eq(row.key,key)
 local expected=Projection(row);p.results:Clear();p:RefreshResults();Same(Projection(row),expected,"same-key reuse after Clear restores the normal projection")
 local activity=f.G.Catalog:GetActivity(1);record=f.G.records[row.key];record.activity=activity;record.activityID=1;record.activityName=activity.name;record.categoryID=3;record.maxNumPlayers=30
 p:SelectCategory("seasonRaid");p:CommitChoice();p:DoSearch();Ok(p.raidResultColumns)
 local raidX=Point(p.results.rows[1].score);Eq(raidX,p.resultsHeader.columns.rating.x+f.U.Theme.findColumnInset)
 p:SelectCategory("seasonDungeon");p:CommitChoice();p:DoSearch();Ok(not p.raidResultColumns)
 c:Restore();f.U:Hide(true)
end end

-- A keyed geometry declaration is applied after product layout. Leaving that
-- key, including via Clear, must not leave its restored old column baseline.
do
 local theme={schema=1,id="geometry.instance",revision=1,appearance={main={elements={
  ["find.result"]={instances={[1]={base={meta={width=73,points={{"LEFT","$parent","LEFT",37,9}}}}}}},
 }}}}
 local f,p=Open("enUS","default",theme);local row=p.results.rows[1]
 Eq(row.key,1);Eq(row.meta:GetWidth(),73);local x,y=Point(row.meta);Eq(x,37);Eq(y,9)
 f.U:SetWindowSize(f.U.windowWidth+180,f.U.windowHeight);p:RefreshResults()
 Eq(row.meta:GetWidth(),73);x,y=Point(row.meta);Eq(x,37);Eq(y,9)
 local activityColumn=p.resultsHeader.columns.activity
 p.results:SetPixelOffset(8*p.results.rowHeight,false);Ok(row.key~=1)
 x,y=Point(row.meta);Eq(x,activityColumn.x+f.U.Theme.findColumnInset+f.U.Theme.findResultIconSize+6);Eq(y,0)
 p.results:SetPixelOffset(0,false);Eq(row.key,1);Eq(row.meta:GetWidth(),73);x,y=Point(row.meta);Eq(x,37);Eq(y,9)
 p.results:Clear();p:RefreshResults();Eq(row.key,1);Eq(row.meta:GetWidth(),73);x,y=Point(row.meta);Eq(x,37);Eq(y,9)
 f.U:Hide(true)
end
do
 local theme={schema=1,id="geometry.state",revision=1,appearance={main={elements={
  ["find.result"]={instances={[1]={states={hover={meta={width=73,points={{"LEFT","$parent","LEFT",37,9}}}}}}}},
 }}}}
 local f,p=Open("enUS","default",theme);local row=p.results.rows[1]
 p.results.clip.mouseOver=true;row.mouseOver=true;row:Fire("OnEnter");p:RefreshResults();Eq(row.meta:GetWidth(),73)
 f.U:SetWindowSize(f.U.windowWidth+180,f.U.windowHeight);p:RefreshResults();Eq(row.meta:GetWidth(),73)
 row.mouseOver=false;row:Fire("OnLeave");p:RefreshResults()
 local x,y=Point(row.meta);Eq(x,p.resultsHeader.columns.activity.x+f.U.Theme.findColumnInset+f.U.Theme.findResultIconSize+6,"state exit restores the current column rather than its old captured baseline");Eq(y,0)
 Eq(row.meta:GetWidth(),p.resultsHeader.columns.activity.width-f.U.Theme.findColumnInset*2-f.U.Theme.findResultIconSize-6)
 f.U:Hide(true)
end
print("Find row geometry: "..checks.." checks passed")
EJ_GetDifficulty,EJ_SelectInstance,EJ_GetEncounterInfoByIndex=journalDifficulty,journalInstance,journalEncounter
