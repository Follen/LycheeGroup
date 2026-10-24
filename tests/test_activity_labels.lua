-- Pure display aliases plus real product consumers. No catalog, result or
-- player-authored source field is rewritten by a display conversion.
local Check=T or {}
if not Check.eq then function Check.eq(actual,expected,why) assert(actual==expected,(why or "")..": "..tostring(actual).." ~= "..tostring(expected)) end end
if not Check.ok then function Check.ok(value,why) assert(value,why) end end
do
 local secret={};local env=setmetatable({},{__index=_G});env._G=env
 env.LycheeGroup={};env.issecretvalue=function(value) return rawequal(value,secret) end
 env.GetLocale=function() error("display aliases must not query native state") end
 setfenv(assert(loadfile("addon/LycheeGroup/ActivityLabels.lua")),env)()
 local display=env.LycheeGroup.ActivityLabels.Display
 for _,case in ipairs({{"副本（史诗钥石）","副本（M+）"},{"副本（史诗钥匙）","副本（M+）"},{"Dungeon (Mythic Keystone)","Dungeon (M+)"},{"Mythic Keystone","M+"},{"史诗钥匙","M+"},{"普通 / Heroic / Mythic","普通 / Heroic / Mythic"},{"M+","M+"},{"",""}}) do
  Check.eq(display(case[1]),case[2]);Check.eq(display(display(case[1])),case[2],"display normalization is idempotent")
 end
 Check.eq(display(nil),nil)
 for _,value in ipairs({false,42,{},secret}) do Check.eq(display(value),nil,"non-text or secret values never become display text") end
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale,{rememberFilters=true,find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}})
 local a,u,g=f.A,f.U,f.G;a:SetSetting("reduceMotion",true)
 local difficulty=locale=="zhCN" and "史诗钥石" or "Mythic Keystone"
 local rawActivity=locale=="zhCN" and "测试副本（史诗钥石）" or "Test Dungeon (Mythic Keystone)"
 local shownActivity=locale=="zhCN" and "测试副本（M+）" or "Test Dungeon (M+)"
 local playerText="Player 史诗钥石 / 史诗钥匙 / Mythic Keystone"
 local getActivity,getGroup,getDifficulty=C_LFGList.GetActivityInfoTable,C_LFGList.GetActivityGroupInfo,GetDifficultyInfo
 C_LFGList.GetActivityInfoTable=function(id)
  local source=getActivity(id);if id~=2 or not source then return source end
  local info={};for key,value in pairs(source) do info[key]=value end
  info.fullName,info.shortName=rawActivity,rawActivity;return info
 end
 C_LFGList.GetActivityGroupInfo=function(id) return id==20 and rawActivity or getGroup(id) end
 GetDifficultyInfo=function(id) return id==8 and difficulty or getDifficulty(id) end
 g.Catalog:Invalidate()
 local activity=g.Catalog:GetActivity(2)
 local group=g.Catalog:GetGroup("seasonDungeon",20)
 local member={name="Leader-Away",nameKey="Leader-Away",class="MAGE",assignedRole="DAMAGER",isLeader=true,itemLevel=320}
 local function Result(id)
  return {id=id,name=playerText,comment=playerText,partyGUID="Labels-"..id,activityID=2,activity=activity,activityName=rawActivity,categoryID=2,leaderName=member.name,leaderKey=member.nameKey,numMembers=1,maxNumPlayers=5,age=1,details={members={member},counts={TANK=0,HEALER=0,DAMAGER=1}}}
 end
 local result,applied=Result(11),Result(12)
 g.records[11],g.records[12]=result,applied
 local application={id=12,name=playerText,activityID=2,activityName=rawActivity,activityLabel=rawActivity,activityDetail=difficulty,leaderName=member.name,categoryID=2,status="applied",expiresAt=GetTime()+120,result=applied}
 g.apps={application}
 a:Open("find");local find=u.pages.find
 local row=find.results.rows[1]
 Check.eq(row.key,11);Check.eq(row.meta:GetText(),shownActivity);Check.eq(row.title:GetText(),playerText)
 Check.eq(find.appList.rows[1].meta:GetText(),shownActivity);Check.eq(find.appList.rows[1].title:GetText(),playerText)
 u.Tooltip:ShowGroup(row,result)
 Check.eq(u.Tooltip.interactive.subtitle:GetText(),shownActivity)
 Check.eq(u.Tooltip.interactive.title:GetText(),playerText);Check.eq(u.Tooltip.interactive.comment:GetText(),playerText,"tooltip leaves player-authored titles and comments intact")
 u.Tooltip:Hide();find:SelectCategory("seasonDungeon")
 local activityRow
 for _,candidate in ipairs(find.activities.rows) do if candidate.key==20 then activityRow=candidate;break end end
 Check.ok(activityRow);Check.eq(activityRow.title:GetText(),shownActivity)
 local difficultyButton
 for _,button in ipairs(find.difficultyButtons) do if button.value==8 then difficultyButton=button;break end end
 Check.ok(difficultyButton);Check.eq(difficultyButton.label:GetText(),"M+")
 local searchedIDs;local search=g.Search.Search
 function g.Search:Search(category,ids,...) searchedIDs=ids;return search(self,category,ids,...) end
 activityRow:Fire("OnClick","LeftButton");find.pickerConfirm:Fire("OnClick","LeftButton")
 Check.eq(searchedIDs[1],2,"display aliases retain the native selected activity ID")
 Check.ok(find.context:GetText():find("M+",1,true));Check.eq(g.searchMode,"group")

 a:Open("create");local create=u.pages.create
 create:UsePreset({activityID=2})
 Check.eq(create.pickerName:GetText(),shownActivity)
 local variants=create:DifficultyItems();local variant
 for _,entry in ipairs(variants) do if entry.value==2 then variant=entry end end
 Check.ok(variant);Check.eq(variant.label,"M+")
 local choice
 for _,entry in ipairs(create:ActivityItems()) do if entry.value==20 then choice=entry end end
 Check.ok(choice);Check.eq(choice.label,shownActivity)
 create.pickerTrigger:Fire("OnClick","LeftButton")
 create.pickerSearch.box:UserType(difficulty)
 local pickerRow
 for _,candidate in ipairs(create.pickerResults.rows) do if candidate.key and candidate:IsShown() then
  local entry=create.pickerEntries[candidate.key]
  if entry and entry.group.key==20 then pickerRow=candidate;break end
 end end
 Check.ok(pickerRow,"native activity search still matches the original difficulty words")
 Check.eq(pickerRow.title:GetText(),shownActivity);create:ClosePicker()
 LFGListFrame.EntryCreation.Name:UserType(playerText);LFGListFrame.EntryCreation.Description.EditBox:UserType(playerText)
 Check.eq(create:FormData().activityID,2);Check.eq(LFGListFrame.EntryCreation.Name:GetText(),playerText);Check.eq(LFGListFrame.EntryCreation.Description.EditBox:GetText(),playerText)
 g.Presets:ToggleFavorite({activityID=2});create.favoritesToggle:Fire("OnClick","LeftButton")
 Check.eq(create.favoritesList.rows[1].title:GetText(),shownActivity)
 Check.eq(create.favoritesList.rows[1].meta:GetText(),"M+","favorite difficulty uses the shared display alias")
 g.listing={activityID=2,name=playerText,comment=playerText,activityName=rawActivity,requiredItemLevel=0};g:Notify("listing")
 Check.eq(create.sName:GetText(),playerText);Check.ok(create.sMeta:GetText():find(shownActivity,1,true));Check.ok(create.sMeta:GetText():find("M+",1,true))
 Check.eq(g.listing.name,playerText);Check.eq(g.listing.comment,playerText)
 member.dungeonScores={current={name=rawActivity,level=12,timed=true}}
 u.Tooltip:ShowPlayer(u.frame,member)
 Check.eq(u.Tooltip.interactive.dungeonRows[1].name:GetText(),shownActivity)
 Check.eq(member.dungeonScores.current.name,rawActivity);u.Tooltip:Hide()
 g.listing=nil;g:Notify("listing");u:Hide(true)
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 a.Floating:Bind(g);a.Floating:UpdateSettings();a.Floating:ShowPanel()
 Check.eq(a.Floating.rows[1].name:GetText(),shownActivity);Check.eq(a.Floating.rows[1].score:GetText(),"· M+")
 Check.eq(a.Floating.rows[1].meta:GetText(),playerText,"floating group titles retain the player's words")
 Check.eq(activity.name,rawActivity);Check.eq(activity.fullName,rawActivity);Check.eq(group.name,rawActivity)
 Check.eq(result.activityName,rawActivity);Check.eq(result.name,playerText);Check.eq(result.comment,playerText)
 Check.eq(application.activityName,rawActivity);Check.eq(application.activityLabel,rawActivity);Check.eq(application.activityDetail,difficulty)
 Check.eq(GetDifficultyInfo(8),difficulty);Check.eq(C_LFGList.GetActivityInfoTable(2).fullName,rawActivity)
 a:SetSetting("floating",false)
 C_LFGList.GetActivityInfoTable,C_LFGList.GetActivityGroupInfo,GetDifficultyInfo=getActivity,getGroup,getDifficulty
end
