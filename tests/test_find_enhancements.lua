-- Exercise Find through real controls, subscriptions and header drag handling.
-- Native rendering and game services are supplied by the shared offline fixture.
local Check=T or {}
if not Check.eq then function Check.eq(actual,expected,why) assert(actual==expected,(why or "")..": "..tostring(actual).." ~= "..tostring(expected)) end end
if not Check.ok then function Check.ok(value,why) assert(value,why) end end
if not Check.near then function Check.near(actual,expected,delta,why) assert(math.abs(actual-expected)<=delta,why) end end
local function Color(actual,expected,why)
 for i=1,4 do Check.near(actual[i] or 1,expected[i] or 1,.000001,why) end
end
local function SavedChoice(extra)
 local choice={selected=true,difficultyID=8};for key,value in pairs(extra or {}) do choice[key]=value end
 return {category="seasonDungeon",categoryPrefs={seasonDungeon=choice}}
end
local function Open(locale,prefs,settings)
 local f=dofile("tests/ui_fixture.lua")(locale,prefs,settings)
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 return f,f.U.pages.find
end
local function ExcludeClassRole(page)
 page.quickIdentity:Fire("OnClick","RightButton")
 page.quickIdentity:Fire("OnClick","LeftButton");page.quickIdentity:Fire("OnClick","LeftButton")
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local preferences={rememberFilters=true,find=SavedChoice()}
 local f,page=Open(locale,preferences);local a,u,g=f.A,f.U,f.G
 page.filterToggle:Fire("OnClick","LeftButton")
 Check.eq(page.filterPanel:IsShown(),true)
 Check.eq(page.hideSameClassRole,nil,"the independent class/role switch is removed")
 Check.eq(page.requireBloodlust.label:GetText(),locale=="zhCN" and "嗜血来源" or "Bloodlust source")
 Check.eq(page.filterCount,0)
 ExcludeClassRole(page)
 Check.eq(page.quickIdentity.label:GetText(),locale=="zhCN" and "同职同责" or "Class + role")
 Check.eq(g.filters.hideSameClassRole,true);Check.eq(page.filterCount,1)
 page.requireBloodlust:Fire("OnClick","LeftButton")
 Check.eq(g.filters.requireBloodlust,true);Check.eq(page.filterCount,2)
 Check.eq(page.filterToggle.label:GetText(),locale=="zhCN" and "筛选 2" or "Filters 2")
 Check.eq(a.charPrefs.find.categoryPrefs.seasonDungeon.hideSameClassRole,true)
 Check.eq(a.charPrefs.find.categoryPrefs.seasonDungeon.requireBloodlust,true)
 page:SelectCategory("seasonRaid")
 Check.eq(page.quickFilters:IsShown(),false);Check.eq(page.requireBloodlust:IsShown(),false)
 Check.eq(g.filters.hideSameClassRole,nil);Check.eq(g.filters.requireBloodlust,nil);Check.eq(page.filterCount,0)
 page:SelectCategory("seasonDungeon")
 Check.eq(page.quickIdentity.label:GetText(),locale=="zhCN" and "同职同责" or "Class + role");Check.eq(page.requireBloodlust.value,true)
 Check.eq(g.filters.hideSameClassRole,true);Check.eq(g.filters.requireBloodlust,true);Check.eq(page.filterCount,2)
 page:ClosePicker();page:SetFiltersOpen(true);page.clearFilters:Fire("OnClick","LeftButton")
 Check.eq(g.filters.hideSameClassRole,nil);Check.eq(g.filters.requireBloodlust,nil);Check.eq(page.filterCount,0)
 Check.eq(page.clearFilters:IsEnabled(),false)
 page:SelectCategory("seasonRaid");page:SelectCategory("seasonDungeon")
 Check.eq(g.filters.hideSameClassRole,nil);Check.eq(g.filters.requireBloodlust,nil,"cleared category filters stay cleared")
 ExcludeClassRole(page);page.requireBloodlust:Fire("OnClick","LeftButton")
 a:SetSetting("rememberFilters",false)
 page:SelectCategory("seasonRaid");page:SelectCategory("seasonDungeon")
 Check.eq(g.filters.hideSameClassRole,nil);Check.eq(g.filters.requireBloodlust,nil,"disabled memory does not restore a previous category")
 Check.eq(page.filterCount,0);u:Hide(true)

 -- A new UI session uses character preferences even when the legacy account
 -- seed has the opposite choices; edits must not overwrite that seed.
 local accountChoice=SavedChoice({hideSameClassRole=false,requireBloodlust=false})
 local account={rememberFilters=false,find=accountChoice}
 local character={rememberFilters=true,find=SavedChoice({hideSameClassRole=true,requireBloodlust=true})}
 local nextSession,nextPage=Open(locale,character,account)
 Check.eq(nextSession.G.filters.hideSameClassRole,true);Check.eq(nextSession.G.filters.requireBloodlust,true)
 nextPage:SetFiltersOpen(true);nextPage.clearFilters:Fire("OnClick","LeftButton")
 Check.eq(character.find.categoryPrefs.seasonDungeon.hideSameClassRole,nil)
 Check.eq(character.find.categoryPrefs.seasonDungeon.requireBloodlust,nil)
 Check.eq(accountChoice.categoryPrefs.seasonDungeon.hideSameClassRole,false)
 Check.eq(accountChoice.categoryPrefs.seasonDungeon.requireBloodlust,false,"character edits leave the account seed intact")
 nextSession.U:Hide(true)
 local other,otherPage=Open(locale,{rememberFilters=false,find=SavedChoice({hideSameClassRole=true,requireBloodlust=true})},account)
 Check.eq(other.G.filters.hideSameClassRole,nil);Check.eq(other.G.filters.requireBloodlust,nil,"a character with memory disabled starts without the saved filters")
 otherPage:SetFiltersOpen(true);otherPage.requireBloodlust:Fire("OnClick","LeftButton")
 Check.eq(other.G.filters.requireBloodlust,true);Check.eq(character.find.categoryPrefs.seasonDungeon.requireBloodlust,nil,"a second character cannot edit the first character's filters")
 other.U:Hide(true)
end

-- Saved combinations retain their actual predicates. A known spec can match
-- even when assignedRole is missing; a same-role member may have another spec.
for _,locale in ipairs({"zhCN","enUS"}) do
 for mask=0,7 do
  local class=mask%2==1;local spec=math.floor(mask/2)%2==1;local role=math.floor(mask/4)%2==1
  local f,page=Open(locale,{rememberFilters=true,find=SavedChoice({hideSameClass=class,hideSameSpec=spec,hideSameClassRole=role})})
  local expected=class and "class" or spec and role and "specRole" or role and "classRole" or spec and "spec" or "any"
  Check.eq(f.G.filters.hideSameClass,class and true or nil)
  Check.eq(f.G.filters.hideSameSpec,not class and spec and true or nil)
  Check.eq(f.G.filters.hideSameClassRole,not class and role and true or nil)
  Check.eq(page.filterCount,class and 1 or (spec and 1 or 0)+(role and 1 or 0))
  if expected=="specRole" then
   Check.eq(page.quickIdentity.label:GetText(),locale=="zhCN" and "专精+职责" or "Spec + role")
   page:SelectCategory("seasonRaid");page:SelectCategory("seasonDungeon")
   Check.eq(f.G.filters.hideSameSpec,true);Check.eq(f.G.filters.hideSameClassRole,true,"category restore retains both distinct predicates")
   page.quickIdentity:Fire("OnClick","LeftButton")
   Check.eq(f.G.filters.hideSameSpec,nil);Check.eq(f.G.filters.hideSameClassRole,nil,"the legacy combined state returns to Any")
  end
  page.quickIdentity:Fire("OnClick","RightButton")
  Check.eq(f.G.filters.hideSameClass,nil);Check.eq(f.G.filters.hideSameSpec,nil);Check.eq(f.G.filters.hideSameClassRole,nil)
  Check.eq(page.filterCount,0)
  f.U:Hide(true)
 end
end

do
 local f=dofile("tests/ui_fixture.lua")("zhCN",{rememberFilters=true,find=SavedChoice()})
 local a,u,g,s=f.A,f.U,f.G,f.S;a:SetSetting("reduceMotion",true)
 local function Record(id,name)
  local leader={name=name.."-Away",nameKey=name.."-Away",class="MAGE",assignedRole="DAMAGER",isLeader=true}
  return {id=id,partyGUID="Enhanced-"..id,name="Group "..id,activityID=2,activity=g.Catalog:GetActivity(2),activityName="Dungeon activity",categoryID=2,leaderName=leader.name,leaderKey=leader.nameKey,numMembers=1,maxNumPlayers=5,age=id,details={members={leader},counts={TANK=0,HEALER=0,DAMAGER=1}}}
 end
 for id=1,4 do g.records[id]=Record(id,"Leader"..id) end
 g.records[1].bnetFriends,g.records[1].charFriends,g.records[1].guildMates=1,1,1
 g.records[2].charFriends,g.records[2].guildMates=1,1
 g.records[3].guildMates=1
 a:Open("find");local page=u.pages.find
 local function Row(id)
  for _,row in ipairs(page.results.rows) do if row.key==id then return row end end
  error("missing visible result "..id)
 end
 Color(Row(1).title.color,u.Theme.findTitleBnetColor,"Battle.net takes priority over character friend and guild")
 Color(Row(2).title.color,u.Theme.findTitleFriendColor,"character friend takes priority over guild")
 Color(Row(3).title.color,u.Theme.findTitleGuildColor,"guild title")
 Color(Row(4).title.color,u.Theme.text,"ordinary title")
 Check.ok(a.Notes:Add("Leader1","Away","Blocked leader",nil,nil,{type="caution"}))
 Color(Row(1).title.color,u.Theme.findTitleBlockedColor,"a leader caution record overrides every relationship")
 Check.ok(a.Notes:Edit("Leader1-Away","Recommended instead",{type="positive"}))
 Color(Row(1).title.color,u.Theme.findTitleBnetColor,"editing a leader note refreshes the visible title")
 Check.ok(a.Notes:Edit("Leader1-Away","Blocked again",{type="caution"}))
 Color(Row(1).title.color,u.Theme.findTitleBlockedColor)
 a:SetSetting("noteMarks",false)
 Color(Row(1).title.color,u.Theme.findTitleBnetColor,"disabling note marks removes the blocked color")
 a:SetSetting("noteMarks",true);Color(Row(1).title.color,u.Theme.findTitleBlockedColor)
 Check.ok(a.Notes:Remove("Leader1-Away"));Color(Row(1).title.color,u.Theme.findTitleBnetColor,"deleting a leader note refreshes immediately")
 Check.ok(a.Notes:Add("OtherMember","Away","Member only",nil,nil,{type="caution"}))
 g.records[4].details.members[2]={name="OtherMember-Away",nameKey="OtherMember-Away",class="WARRIOR",assignedRole="TANK"}
 g:Notify("relations");Color(Row(4).title.color,u.Theme.text,"another member's caution never colors the leader title")
 a:SetSetting("relations",false)
 for id=1,4 do Color(Row(id).title.color,u.Theme.text,"relationship visibility also controls title color") end
 a:SetSetting("relations",true);Color(Row(1).title.color,u.Theme.findTitleBnetColor)
 g.records[1].bnetFriends=0;g:Notify("relations");Color(Row(1).title.color,u.Theme.findTitleFriendColor)
 g.records[1].charFriends=0;g:Notify("relations");Color(Row(1).title.color,u.Theme.findTitleGuildColor)
 g.records[1].guildMates=0;g:Notify("relations");Color(Row(1).title.color,u.Theme.text,"rebinding clears the previous relationship color")
 Row(1):Fire("OnEnter");Color(Row(1).title.color,u.Theme.text);Row(1):Fire("OnLeave")
 g.records[1].bnetFriends=1;g:Notify("relations")
 Row(1):Fire("OnEnter");Color(Row(1).title.color,u.Theme.findTitleBnetColor,"hover retains the relationship color")
 Row(1):Fire("OnLeave");Color(Row(1).title.color,u.Theme.findTitleBnetColor,"pointer leave retains the relationship color")
 for _,scale in ipairs({70,100,130}) do
  a:SetSetting("fontScale",scale)
  Color(Row(1).title.color,u.Theme.findTitleBnetColor,"font refresh retains the current relationship")
  Color(Row(4).title.color,u.Theme.text,"font refresh never restores an obsolete color")
 end
 a:SetSetting("fontScale",100)
 local oldRecords=g.records;local pooled=page.results.rows[1];local previousKey=pooled.key
 g.records={[40]=Record(40,"Replacement")};g:Notify("results")
 Check.eq(page.results.rows[1],pooled);Check.ok(pooled.key~=previousKey,"a pooled row is rebound to another result")
 Check.eq(pooled.key,40);Check.eq(pooled.title:GetText(),"Group 40")
 Color(pooled.title.color,u.Theme.text,"a reused result row clears the previous relationship color")
 Check.eq(pooled.marks:IsShown(),false,"a reused result row clears previous relationship marks")
 pooled:Fire("OnEnter");pooled:Fire("OnLeave");Color(pooled.title.color,u.Theme.text,"hover does not resurrect a previous result's color")
 g.records=oldRecords;g:Notify("results")

 -- Drag the real boundary between activity and leader all the way to the new
 -- leader minimum. Every visible mark still has reserved space beside text.
 g.records[1].charFriends,g.records[1].guildMates=1,1
 Check.ok(a.Notes:Add("Leader1","Away","Visible record",nil,nil,{type="neutral"}));g:Notify("relations")
 local header=page.resultsHeader;Check.eq(header.columns.leader.minimum,112)
 Check.eq(u.Theme.findResultLeaderWidth,176,"the default leader width is retained")
 local oldMouse=IsMouseButtonDown;local pressed=true
 IsMouseButtonDown=function(button) return pressed and button=="LeftButton" end
 s.cursorX=400;header.handles[2]:Fire("OnMouseDown","LeftButton")
 s.cursorX=400+1000*header:GetEffectiveScale();header:Fire("OnUpdate",.016)
 pressed=false;header:Fire("OnUpdate",.016);IsMouseButtonDown=oldMouse
 Check.near(header.columns.leader.width,112,.001,"leader column reaches its minimum through a drag")
 local row=Row(1);Check.eq(row.marks:GetWidth(),84)
 Check.ok(row.leader:GetWidth()+6+row.marks:GetWidth()<=header.columns.leader.width-8+.001,"the narrower leader column keeps every relationship and note mark")
 local point={row.marks:GetPoint()};Check.eq(point[2],row.leader);Check.eq(point[3],"RIGHT")
 Check.near(page.results.rowHeight,53,.001,"ordinary result stride is reduced")
 Check.near(Row(4):GetHeight(),53,.001,"ordinary result body uses the tighter height")
 g.records[10]=Record(10,"Applied")
 g.apps={{id=10,name="Applied group",leaderName="Applied-Away",categoryID=2,status="applied",expiresAt=GetTime()+120,result=g.records[10]}}
 g:Notify("applications")
 local appHeight=page.appList.rowHeight
 Check.near(appHeight,44,.001,"application rows keep their independent height")
 g.declinedParties[g.records[2].partyGUID]=GetTime();g:Notify("applications")
 Check.ok(Row(2).declined:IsShown());Check.ok(Row(2):GetHeight()>53,"a rejected result grows independently for its explanation")
 Check.near(Row(4):GetHeight(),53,.001,"rejection text does not enlarge ordinary results")
 Check.near(page.results.rowHeight,53,.001);Check.near(page.appList.rowHeight,appHeight,.001,"rejection text does not enlarge application rows")
 g.declinedParties[g.records[2].partyGUID]=nil;g:Notify("applications")
 Check.near(Row(2):GetHeight(),53,.001,"removing rejection restores the compact result body")
 u:Hide(true)
end
