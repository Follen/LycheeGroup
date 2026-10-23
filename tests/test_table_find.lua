local fixture=dofile("tests/ui_fixture.lua")
local f=fixture("zhCN")
local A,U,G,S=f.A,f.U,f.G,f.S
A:SetSetting("reduceMotion",true);A:Open("find")
local page=U.pages.find
local function Left(region) local point={region:GetPoint()};return point[#point-1] or 0 end
T.eq(Left(page.context),Left(page.search),"the dungeon heading shares the search and results left edge")
local activity=G.Catalog:GetActivity(2)
local values={{9,90,300,100},{80,300,1200,9},{12,12,20,80},{5,150,nil,30},{90,400,1400,1}}
for id,v in ipairs(values) do
 G.records[id]={id=id,name="Column group "..id,leaderName="Leader"..id.."-Away",leaderKey="Leader"..id.."-Away",
  activity=activity,activityID=2,activityName=activity.name,categoryID=2,maxNumPlayers=40,partyGUID="party-"..id,
  numMembers=v[1],requiredItemLevel=v[2],leaderRating=v[3],age=v[4],
  details={members={},counts={TANK=1,HEALER=1,DAMAGER=v[1]-2}}}
end
G.declinedParties["party-5"]=1
page:CommitChoice();page:DoSearch()
local function Click(header,key)
 for _,button in ipairs(header.buttons) do if button:IsShown() and button.definition.key==key then button:Fire("OnClick","LeftButton");return end end
 error("no header "..key)
end
local header=page.resultsHeader
Click(header,"members");T.same(page.results.ids,{4,1,3,2,5},"member counts sort numerically, with declined groups in their existing bottom bucket")
Click(header,"members");T.same(page.results.ids,{2,3,1,4,5})
Click(header,"ilvl");T.same(page.results.ids,{3,1,4,2,5})
Click(header,"ilvl");T.same(page.results.ids,{2,4,1,3,5})
Click(header,"rating");T.same(page.results.ids,{3,1,2,4,5},"unknown score stays after known values")
Click(header,"rating");T.same(page.results.ids,{2,1,3,4,5},"unknown score stays last in descending order too")
Click(header,"age");T.same(page.results.ids,{2,4,3,1,5})
Click(header,"age");T.same(page.results.ids,{1,3,4,2,5})
local raw=G:GetResults();T.same(raw,{1,2,3,4,5},"header sorting leaves the result service's array unchanged")
G.records[4].age=80;page:RefreshResults();T.same(page.results.ids,{1,3,4,2,5},"equal values use stable result IDs")
local savedSort=U:GetTablePrefs("findResults");T.eq(savedSort.sortKey,"age");T.eq(savedSort.descending,true)

local oldMouse=IsMouseButtonDown;local pressed=false
IsMouseButtonDown=function(button) return pressed and button=="LeftButton" end
local function Begin(h,index)
 S.cursorX=400;pressed=true;h.handles[index]:Fire("OnMouseDown","LeftButton")
end
local function Move(h,delta)
 S.cursorX=400+delta*h:GetEffectiveScale();h:Fire("OnUpdate",.016)
end
local function Release(h)
 pressed=false;h:Fire("OnUpdate",.016)
end
local cell=header.columns.title;local initial=cell.width
local leader=header.columns.leader.width
local oldIds=table.concat(page.results.ids,",")
local reads=0;local getDetails=G.Results.GetDetails
G.Results.GetDetails=function(...) reads=reads+1;return getDetails(...) end
header.mouseOver=true;header:Fire("OnEnter");T.ok(header.handles[1].line:IsShown())
Begin(header,1);Move(header,24)
T.near(cell.width,initial+24,.001);T.near(header.columns.leader.width,leader-24,.001)
T.eq(reads,0,"dragging only changes geometry, without retrieving row details")
T.eq(savedSort.widths,nil,"drag samples do not write preferences")
T.eq(table.concat(page.results.ids,","),oldIds,"resizing does not reorder data")
T.near(page.results.rows[1].title:GetWidth(),cell.width-76,.001)
T.near(page.results.rows[1].tooltipArea:GetWidth(),cell.width,.001,"title tooltip hit area follows its resized column")
Release(header);T.ok(savedSort.widths);T.eq(header:GetScript("OnUpdate"),nil)
local ratios=savedSort.widths;local savedWidth=cell.width
Begin(header,1);Move(header,1000)
T.ok(header.columns.leader.width>=header.columns.leader.minimum-.001)
U:Hide(true);pressed=false
T.eq(header.drag,nil);T.eq(header:GetScript("OnUpdate"),nil);T.eq(savedSort.widths,ratios)
A:Open("find");T.near(header.columns.title.width,savedWidth,.001,"close cancels the unfinished drag and reopens saved widths")
U:SetWindowSize(U.windowWidth+180,U.windowHeight)
T.near(header.columns.title.width/header:GetWidth(),ratios.title,.001,"saved column proportions follow a wider window")
local before=#S.nodes
Begin(header,1);Move(header,-12);Release(header)
T.eq(#S.nodes,before,"repeated drag reuses header and row objects")
header.mouseOver=false;header:Fire("OnLeave");T.ok(not header.handles[1].line:IsShown())
G.Results.GetDetails=getDetails

-- The compact pinned applications have the same resize/sort behavior.
G.apps={
 {id=1,name="First",leaderName="Leader1-Away",categoryID=2,status="applied",expiresAt=200,result=G.records[1]},
 {id=2,name="Second",leaderName="Leader2-Away",categoryID=2,status="applied",expiresAt=90,result=G.records[2]},
 {id=3,name="Third",leaderName="Leader3-Away",categoryID=2,status="invited",result=G.records[3]},
}
page:RefreshApplications()
local apps=page.applicationHeader
T.ok(apps:IsShown())
Click(apps,"members");T.same(page.appList.ids,{1,3,2})
Click(apps,"members");T.same(page.appList.ids,{2,3,1})
Click(apps,"status");T.same(page.appList.ids,{2,1,3})
Click(apps,"status");T.same(page.appList.ids,{1,2,3},"applications without a numeric timer remain last")
local w=apps.columns.title.width
Begin(apps,1);Move(apps,15);Release(apps)
T.near(apps.columns.title.width,w+15,.001)
T.near(page.appList.rows[1].title:GetWidth(),apps.columns.title.width-48,.001)
T.near(page.appList.rows[1].tooltipArea:GetWidth(),apps.columns.title.width,.001)
G.apps={};page:RefreshApplications();T.ok(not apps:IsShown())

-- Raid progress is a separate layout with numeric encounter counts, not score.
local getProgress=G.Results.GetProgressCount;local countReads=0
G.Results.GetProgressCount=function(_,record) countReads=countReads+1;return record.testProgress end
G.records[1].testProgress=2;G.records[2].testProgress=10;G.records[3].testProgress=1
page.raidResultColumns=true;page:LayoutResultColumns()
local raidPrefs=header.state;T.ok(raidPrefs~=savedSort)
header:SetSort("rating",false)
T.same(page:SortResultIDs({1,2,3,4}),{3,1,2,4})
header:SetSort("rating",true)
T.same(page:SortResultIDs({1,2,3,4}),{2,1,3,4})
T.eq(countReads,8,"each sort reads one numeric progress value per result")
T.ok(header.columns.description.x<header.columns.rating.x,"raid progress follows the description")
page.raidResultColumns=false;page:LayoutResultColumns()
T.eq(header.state,savedSort);T.ok(header.columns.rating.x<header.columns.description.x)
G.Results.GetProgressCount=getProgress

-- Preview cannot overwrite the character's persisted table state.
local liveWidths=savedSort.widths
U.preview={provider={prefs={}}}
local previewPrefs=U:GetTablePrefs("findResults");T.ok(previewPrefs~=savedSort)
header:SetState(previewPrefs);header:Layout(header:GetWidth())
Begin(header,1);Move(header,18);Release(header);header:SetSort("members",false)
T.eq(savedSort.widths,liveWidths);T.eq(savedSort.sortKey,"age")
U.preview=nil;header:SetState(savedSort)

-- Font and window scale changes keep all cells and numeric values in bounds.
for _,locale in ipairs({"zhCN","enUS"}) do
 local nextF=fixture(locale);A,U,G,S=nextF.A,nextF.U,nextF.G,nextF.S
 A:SetSetting("reduceMotion",true);A:Open("find");page=U.pages.find
 for _,scale in ipairs({70,100,130}) do
  A:SetSetting("fontScale",scale)
  for _,h in ipairs({page.resultsHeader,page.applicationHeader}) do
   local right=0
   for _,def in ipairs(h.definitions) do
    local col=h.columns[def.key]
    T.near(col.x,right,.001);T.ok(col.width>0)
    right=right+col.width
   end
   T.near(right,h:GetWidth(),.001)
   T.eq(h:GetScript("OnUpdate"),nil)
  end
 end
end
IsMouseButtonDown=oldMouse
