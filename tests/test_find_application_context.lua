-- External application links use the same category handoff as sidebar navigation.
local Fixture=dofile("tests/ui_fixture.lua")
local function Session()
 local preferences={find={category="seasonDungeon",categoryPrefs={
  seasonDungeon={selected=true,difficultyID=8,minRating="2000",social="friend"},
  seasonRaid={selected=true,minItemLevel="100",social="guild"},
  ["2"]={selected=true,minItemLevel="50"},
 }}}
 local f=Fixture("zhCN",preferences);f.A:SetSetting("reduceMotion",true)
 local g=f.G;f.searches=0
 local search=g.Search.Search
 g.Search.Search=function(self,category,...)
  f.searches=f.searches+1;self.categoryKey=category
  return search(self,category,...)
 end
 return f
end

-- Native double-click delivery may occur on the second mouse-down. It must
-- still refer to the physical row and business identity from the first click.
local function ResultClick(row,button)
 row:Fire("OnMouseDown",button);row:Fire("OnMouseUp",button);row:Fire("OnClick",button)
end
for _,auto in ipairs({false,true}) do
 for _,change in ipairs({"replaceID","replaceGUID","replaceNoGUID","sort","scroll","hide","reenter","leave","right","rightDouble","noFirst","otherRow","same","sameGUID","sameNoGUID"}) do
  local f=Fixture("enUS",{autoApply=auto,applicationRoles={DAMAGER=true}},{reduceMotion=true})
  local a,u,g=f.A,f.U,f.G
  a.Configuration:Set({["layout.tables.findResults.sortKey"]=false},{storage="character"})
  a:Open("find");local p=u.pages.find;local activity=g.Catalog:GetActivity(2)
  local function Result(id)
   return {id=id,name="Double click "..id,leaderName="Leader"..id.."-Away",leaderKey="Leader"..id.."-Away",
    activity=activity,activityID=2,activityName=activity.name,categoryID=2,maxNumPlayers=5,numMembers=1,partyGUID="dbl-"..id,age=1000-id}
  end
  local count=change=="scroll" and 30 or (change=="sort" or change=="otherRow") and 2 or 1
  for id=101,100+count do g.records[id]=Result(id) end
  if change=="replaceNoGUID" or change=="sameNoGUID" then g.records[101].partyGUID=nil end
  p:CommitChoice();p:DoSearch();local row=p.results.rows[1]
  T.eq(row.key,101)
  if change=="noFirst" then row:Fire("OnMouseDown","LeftButton") else ResultClick(row,"LeftButton") end
  if change=="replaceID" then g.records[101]=nil;g.records[102]=Result(102);g:Notify("results");u.Motion:Tick(.2);T.eq(row.key,102)
  elseif change=="replaceGUID" then g.records[101].partyGUID="new-party";g:Notify("result",101);u.Motion:Tick(.2)
  elseif change=="replaceNoGUID" then g.records[101]=Result(101);g.records[101].partyGUID=nil;g:Notify("results");u.Motion:Tick(.2)
  elseif change=="sort" then
   for _,button in ipairs(p.resultsHeader.buttons) do if button.definition.key=="age" then button:Fire("OnClick","LeftButton") end end
   T.eq(row.key,102,"a real header sort reuses the physical row")
  elseif change=="scroll" then p.results:SetPixelOffset(p.results.rowHeight*10,false);T.ok(row.key~=101);p.results:SetPixelOffset(0,false);T.eq(row.key,101)
  elseif change=="hide" then row:Hide();row:Show()
  elseif change=="reenter" then u:Hide(true);a:Open("find");T.eq(row.key,101)
  elseif change=="leave" then row:Fire("OnLeave")
  elseif change=="right" then ResultClick(row,"RightButton");u:CloseMenu()
  elseif change=="otherRow" then row=p.results.rows[2];T.eq(row.key,102)
  elseif change=="sameGUID" then g.records[101]=Result(101);g:Notify("results");u.Motion:Tick(.2)
  elseif change=="sameNoGUID" then g.records[101].comment="Refreshed";g:Notify("result",101);u.Motion:Tick(.2)
  end
  local doubleButton=change=="rightDouble" and "RightButton" or "LeftButton"
  row:Fire("OnMouseDown",doubleButton);row:Fire("OnDoubleClick",doubleButton)
  local permitted=change=="same" or change=="sameGUID" or change=="sameNoGUID"
  if not permitted then
   T.eq(u.Application.applicationLease,nil,change.." does not open confirmation for a recycled target")
   T.eq(LFGListApplicationDialog.submissions,0,change.." does not submit an automatic application")
  else
   if not auto then
    T.eq(u.Application.applicationLease.id,101,change.." preserves a real same-team double click")
    u.Application.applicationModal.submit:Fire("OnClick","LeftButton")
   end
   T.eq(LFGListApplicationDialog.submissions,1)
   T.eq(LFGListApplicationDialog.submitted.resultID,101)
   row:Fire("OnDoubleClick","LeftButton")
   T.eq(LFGListApplicationDialog.submissions,1,"a consumed first click cannot submit twice")
  end
  u:CloseModal();u:Hide(true)
 end
end
local function Application(f,id,activityID)
 local g=f.G;local activity=g.Catalog:GetActivity(activityID)
 local r={id=id,partyGUID="Party-"..id,name="Application "..id,activityID=activityID,activity=activity,
  categoryID=activity.categoryID,numMembers=1,maxNumPlayers=activity.maxNumPlayers,age=10}
 local app={id=id,status="applied",name=r.name,categoryID=r.categoryID,result=r}
 g.records[id]=r;g.apps[#g.apps+1]=app;return app
end
for _,entry in ipairs({"visible","hidden","first"}) do
 local f=Session();local a,u,g=f.A,f.U,f.G
 Application(f,101,1)
 if entry~="first" then
  a:Open("find",{leaderKey="OldLeader-Home",leaderName="OldLeader"})
  local p=u.pages.find;p:SetSearchMode("leader");p.search.box:SetText("OldLeader")
  if entry=="hidden" then u:Hide(true) end
 end
 local before=f.searches
 a:Open("find",{applicationID=101});local p=u.pages.find
 T.eq(g.filters.category,"seasonRaid",entry.." application opens its real category")
 T.eq(g.filters.minItemLevel,"100",entry.." restores the destination's item level")
 T.eq(g.filters.minRating,nil,entry.." does not carry the dungeon rating")
 T.eq(g.filters.guild,true);T.eq(g.filters.friends,false)
 T.eq(g.filters.personKey,nil);T.eq(g.filters.leaderText,nil)
 T.eq(g.filters.searchMode,"group");T.eq(p.search.box:GetText(),"")
 T.eq(g.prefs.find.categoryPrefs.seasonDungeon.minRating,"2000")
 T.eq(g.prefs.find.categoryPrefs.seasonDungeon.social,"friend")
 T.eq(g.prefs.find.categoryPrefs.seasonRaid.difficultyID,nil)
 T.same(p.appList.ids,{101});T.eq(p.appList.selectedKey,101)
 T.eq(f.searches,before+1,"the handoff submits one destination search")
 T.ok(not p.picker or not p.picker:IsShown(),"an application link does not open the activity picker")
 p:SelectCategory("seasonDungeon")
 T.eq(g.filters.minRating,"2000");T.eq(g.filters.minItemLevel,nil);T.eq(g.filters.friends,true)
 u:Hide(true)
end
-- A non-season dungeon must remain visible when the link is opened with the
-- default category-only application scope. The live catalog owns membership.
do
 local f=Session();local a,u,g=f.A,f.U,f.G
 local info,available=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities
 C_LFGList.GetActivityInfoTable=function(id)
  if id==4 then return {id=4,categoryID=2,fullName="Older dungeon",shortName="Older",groupFinderActivityGroupID=40,difficultyID=1,maxNumPlayers=5,orderIndex=4} end
  return info(id)
 end
 C_LFGList.GetAvailableActivities=function(category,group,flags)
  if category==2 and flags~=68 then return {4} end
  return available(category,group,flags)
 end
 g.Catalog:Invalidate();Application(f,102,4)
 a:Open("find",{applicationID=102});local p=u.pages.find
 T.eq(g.filters.category,"2","non-season activity uses the non-season category")
 T.eq(g.filters.minItemLevel,"50");T.eq(g.filters.minRating,nil)
 T.same(p.appList.ids,{102});T.eq(p.appList.selectedKey,102)
 T.eq(g.Applications:GetActiveCount(),1)
 u:Hide(true)
end
-- Reopening an application already in this category keeps an intentional query
-- and does not resubmit a finished search.
do
 local f=Session();local a,u,g=f.A,f.U,f.G;Application(f,103,2)
 a:Open("find");local p=u.pages.find;p.search.box:UserType("12-15")
 local before=f.searches;a:Open("find",{applicationID=103})
 T.eq(p.search.box:GetText(),"12-15");T.eq(f.searches,before)
 T.same(p.appList.ids,{103});T.eq(p.appList.selectedKey,103)
 T.eq(g.filters.minRating,"2000");u:Hide(true)
end

-- A category can disappear from the native catalog after its selection was
-- saved. Resolve it before restoring controls and keep each category's filters.
local function ArenaCatalog(f)
 local info,activities=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities
 local available=true
 C_LFGList.GetAvailableCategories=function() return available and {2,3,4} or {2,3} end
 C_LFGList.GetActivityInfoTable=function(id)
  if id==44 then return {categoryID=4,fullName="Arena",shortName="Arena",groupFinderActivityGroupID=44,maxNumPlayers=3,orderIndex=1,isPvpActivity=true} end
  return info(id)
 end
 C_LFGList.GetAvailableActivities=function(category,group,flags)
  if category==4 then return {44} end
  return activities(category,group,flags)
 end
 f.G.Catalog:Invalidate()
 return function(value) available=value;f.G.Catalog:Invalidate() end
end
for _,withFallback in ipairs({false,true}) do
 for _,boundary in ipairs({"restart","activities","reenter","valid"}) do
  local preferences={find={category="4",categoryPrefs=withFallback and {
   seasonDungeon={selected=true,minRating="2000",social="guild"},
  } or {}}}
  local f=Fixture("enUS",preferences,{reduceMotion=true})
  local setAvailable=ArenaCatalog(f)
  f.A:Open("find");local p=f.U.pages.find
  p:SelectCategory("4");p:CommitChoice();p:ClosePicker();p:SetFiltersOpen(true)
  p.filterFields.minItemLevel.box:UserType("77");f.Pick(p.socialChoice,"friend");p:DoSearch()
  T.eq(preferences.find.category,"4","the native category is saved through normal controls")
  T.eq(preferences.find.categoryPrefs["4"].minItemLevel,77)
  local savedArena={};for key,value in pairs(preferences.find.categoryPrefs["4"]) do savedArena[key]=value end
  if not withFallback then T.eq(preferences.find.categoryPrefs.seasonDungeon,nil) end
  if boundary=="restart" or boundary=="valid" then
   f.U:Hide(true)
   f=Fixture("enUS",preferences,{reduceMotion=true})
   if boundary=="valid" then setAvailable=ArenaCatalog(f) end
   f.A:Open("find");p=f.U.pages.find
  else
   if boundary=="reenter" then f.U:Hide(true) end
   setAvailable(false);f.G:Notify("activities")
   if boundary=="reenter" then f.A:Open("find") end
  end
  local filters=f.G.filters
  if boundary=="valid" then
   T.eq(filters.category,"4","an available saved category remains selected")
   T.eq(filters.minItemLevel,77);T.eq(filters.friends,true)
  else
   T.eq(filters.category,"seasonDungeon",boundary.." resolves the missing category")
   T.eq(filters.minItemLevel,nil,boundary.." does not inherit the unavailable category's filters")
   T.eq(filters.minRating,withFallback and "2000" or nil)
   T.eq(filters.guild,withFallback);T.eq(filters.friends,false)
   T.eq(p.filterFields.minItemLevel.box:GetText(),"")
   T.eq(preferences.find.categoryPrefs["4"].minItemLevel,77,"the unavailable category keeps its own saved filters")
   T.eq(preferences.find.categoryPrefs["4"].social,"friend")
   T.same(preferences.find.categoryPrefs["4"],savedArena,"catalog changes preserve the unavailable category's complete preferences")
   if boundary~="restart" then
    setAvailable(true);f.G:Notify("activities");p:SelectCategory("4")
    T.eq(f.G.filters.minItemLevel,77,"a category that becomes available restores its original filters")
    T.eq(f.G.filters.friends,true)
   end
  end
  f.U:Hide(true)
 end
end
