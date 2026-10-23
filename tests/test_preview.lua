-- Explicit preview uses the production pages, with all real mutation exits trapped.
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G=f.A,f.U,f.G
A:SetSetting("reduceMotion",true)
local function Clone(value)
 if type(value)~="table" then return value end
 local copy={};for k,v in pairs(value) do copy[k]=Clone(v) end;return copy
end
A.charPrefs.applicationRoles={TANK=true,HEALER=false,DAMAGER=false}
local savedDB=Clone(A.db);local savedGroupDB=Clone(G.db);local savedPrefs=Clone(A.charPrefs)
local nativeName=LFGListFrame.EntryCreation.Name
local nativeDescription=LFGListFrame.EntryCreation.Description.EditBox
local nativeSearch=LFGListFrame.SearchPanel.SearchBox
nativeName:UserType("Real draft");nativeDescription:UserType("Real description")
nativeSearch:UserType("Real native range 12-15")
local actions={}
local function Trap(table,key)
 actions[#actions+1]={table,key,table[key]}
 table[key]=function() error("real action called during preview: "..key) end
end
for _,key in ipairs({"Search","ApplyToGroup","CreateListing","UpdateListing","RemoveListing","InviteApplicant","DeclineApplicant","CancelApplication","AcceptInvite","ClearApplicationTextFields","ClearCreationTextFields","ClearSearchTextFields","CopyActiveEntryInfoToCreationFields","SetEntryTitle"}) do Trap(C_LFGList,key) end
for _,key in ipairs({"Publish","Update","RemoveListing","Invite","Decline","Cancel"}) do Trap(G,key) end
Trap(G.Search,"Search");Trap(_G,"SetLFGRoles")
local function Click(button) button:Fire("OnMouseDown");button:Fire("OnClick","LeftButton") end
local function Segment(choice,value)
 for _,button in ipairs(choice.buttons) do if button.value==value then Click(button);return end end
 error("missing segment "..tostring(value))
end
local combat=InCombatLockdown;_G.InCombatLockdown=function() return true end
T.eq(A:Preview("applications"),true,"preview has no blanket combat gate")
_G.InCombatLockdown=combat;U.pages.find.main:Fire("OnEvent","PLAYER_REGEN_ENABLED")
local preview=U:GetGroup()
T.eq(A.Group,G,"the real backend is never replaced")
T.ok(preview~=G);T.eq(#preview:GetApplications(),3)
T.ok(preview.prefs~=A.charPrefs,"preview owns a separate character-preference table")
T.eq(preview.applicationPrefs.roles,nil,"preview does not inherit the real character's application configuration")
T.eq(U.page,"find");T.eq(U.previewExit:IsShown(),true)
local find=U.pages.find
T.eq(find.quickFilters:IsShown(),false);T.eq(find.quickFilterHeight,0)
T.near(find.search:GetWidth(),find.main:GetWidth()-60,.001,"preview also keeps the search row clear")
T.eq(find.search.box,find.previewSearchBox,"preview keeps its own ordinary search input")
T.eq(U.Native.searchLease,nil);T.eq(nativeSearch:GetParent(),LFGListFrame.SearchPanel)
find.search.box:SetText("Preview group 2");T.eq(preview.filters.text,"Preview group 2","preview group mode uses simulated title filtering")
find.search.box:SetText("12-15")
T.same(preview:GetResults(),{preview.recordIDs[5],preview.recordIDs[4],preview.recordIDs[6]},"preview combines group-mode keystone range filtering with friend priority")
find.search.box:SetText("12-13")
T.same(preview:GetResults(),{preview.recordIDs[5],preview.recordIDs[4]},"preview range includes both bounds and excludes higher levels")
find.search.box:SetText(preview.records[preview.recordIDs[4]].name)
T.same(preview:GetResults(),{preview.recordIDs[4]},"preview simulates native group-name matching")
find.search.box:SetText("描述检索样例")
T.same(preview:GetResults(),{},"preview does not claim native descriptions are locally searchable")
find:SetSearchMode("leader")
local captainRecord=preview.records[preview.recordIDs[4]]
local captain,comment=captainRecord.leaderName,captainRecord.comment
find.search.box:SetText(captain)
T.same(preview:GetResults(),{preview.recordIDs[4]},"leader preview searches the exposed leader name")
find.search.box:SetText("  "..captain.."  ")
T.same(preview:GetResults(),{preview.recordIDs[4]},"leader preview trims surrounding query whitespace like production")
captainRecord.leaderName=nil;captainRecord.comment="描述检索样例"
find.search.box:SetText("描述检索样例")
T.same(preview:GetResults(),{},"leader mode does not inspect descriptions when the leader name is absent")
captainRecord.leaderName=captain;captainRecord.comment=comment
find.search.box:SetText("");T.eq(nativeSearch:GetText(),"Real native range 12-15","preview search never clears or rewrites the registered input")
preview.records[preview.recordIDs[5]].numMembers=3;preview.records[preview.recordIDs[6]].numMembers=4
find.fMembers.box:SetText("3");find.fMinMembers.box:SetText("3")
T.same(preview:GetResults(),{preview.recordIDs[5]},"preview applies inclusive minimum and maximum independently")
find.fMinMembers.box:SetText("4");T.eq(preview.filters.minMembers,3);T.eq(preview.filters.maxMembers,3);T.same(preview:GetResults(),{preview.recordIDs[5]},"an inverted member draft preserves the last valid preview range")
find:ClearFilters();T.eq(preview.filters.minMembers,nil);T.eq(preview.filters.maxMembers,nil)
do
 local zero,unknown=preview.records[preview.recordIDs[4]],preview.records[preview.recordIDs[5]]
 local zeroScore,unknownScore=zero.leaderOverallDungeonScore,unknown.leaderOverallDungeonScore
 zero.leaderOverallDungeonScore=0;unknown.leaderOverallDungeonScore=nil
 T.eq(find.hideZeroScore.value,false,"score filtering is off by default")
 Click(find.hideZeroScore)
 T.same(preview:GetResults(),{preview.recordIDs[6]},"preview excludes both zero and missing leader scores")
 T.eq(#find.appList.ids,3,"score filtering leaves existing applications visible")
 Click(find.hideZeroScore);T.eq(#preview:GetResults(),3,"turning the switch off restores filtered groups")
 zero.leaderOverallDungeonScore=zeroScore;unknown.leaderOverallDungeonScore=unknownScore
end
local beforeNoteFilter=preview:GetResults()
do
 local first,second,third=preview.records[preview.recordIDs[4]],preview.records[preview.recordIDs[5]],preview.records[preview.recordIDs[6]]
 T.ok(first.partyGUID and second.partyGUID and third.partyGUID)
 T.ok(first.partyGUID~=second.partyGUID and second.partyGUID~=third.partyGUID,"every preview result has a distinct party identity")
 local old={first.bnetFriends,first.charFriends,second.bnetFriends,second.charFriends,third.bnetFriends,third.charFriends}
 first.bnetFriends,first.charFriends,second.bnetFriends,second.charFriends,third.bnetFriends,third.charFriends=1,0,0,0,0,0
 preview.declinedParties[first.partyGUID]=0
 preview:SetFilters({sort="newest"})
 T.same(preview:GetResults(),{second.id,third.id,first.id},"a rejected friend follows every un-rejected preview group")
 T.eq(preview.Applications:GetDeclinedAt(first.partyGUID),0,"the preview interface preserves a rejection at session time zero")
 preview.declinedParties[third.partyGUID]=0
 preview:SetFilters({sort="itemLevel"})
 T.same(preview:GetResults(),{second.id,first.id,third.id},"both buckets retain friend priority before the selected sort")
 first.bnetFriends=0;preview:SetFilters({sort="itemLevel"})
 T.same(preview:GetResults(),{second.id,third.id,first.id},"the rejected bucket still applies the selected item-level ordering")
 local oldID,oldName=first.id,first.name
 first.id,first.name=oldID-1000,"A changed preview title";preview.records[oldID]=nil;preview.records[first.id]=first;preview.recordIDs[4]=first.id
 preview:Notify("results")
 T.same(preview:GetResults(),{second.id,third.id,first.id},"a result ID and title change retain the party's rejection")
 local originalGUID=first.partyGUID;first.partyGUID="A different party"
 preview:SetFilters({sort="newest"})
 T.same(preview:GetResults(),{first.id,second.id,third.id},"a new party does not inherit a matching title's rejection")
 first.partyGUID=originalGUID;preview.records[first.id]=nil;first.id,first.name=oldID,oldName;preview.records[oldID]=first;preview.recordIDs[4]=oldID
 first.bnetFriends,first.charFriends,second.bnetFriends,second.charFriends,third.bnetFriends,third.charFriends=unpack(old)
 wipe(preview.declinedParties);find:ClearFilters()
 T.eq(find.declineClock,nil,"clearing preview rejections releases the minute timer")
end
do
 local player=A.Specializations.Player
 local first,second,third=preview.records[preview.recordIDs[4]],preview.records[preview.recordIDs[5]],preview.records[preview.recordIDs[6]]
 local saved={first.details.members,second.details.members,third.details.members}
 first.details.members={{class="DEATHKNIGHT",specID=252}}
 second.details.members={{class="DEATHKNIGHT",specID=251}}
 third.details.members={{class="DEATHKNIGHT"}}
 local spec=252
 A.Specializations.Player=function() return spec,"Test specialization",135775 end
 preview:SetFilters({hideSameSpec=true})
 T.same(preview:GetResults(),{second.id,third.id},"preview excludes the current specialization while preserving other and unknown specializations")
 spec=251
 T.same(preview:GetResults(),{first.id,third.id},"preview follows the player's newly selected specialization")
 spec=nil
 T.same(preview:GetResults(),beforeNoteFilter,"preview keeps unknown local specialization unfiltered")
 first.details.members,second.details.members,third.details.members=unpack(saved)
 A.Specializations.Player=player
 preview:SetFilters({})
end
preview:SetFilters({notes="noCaution"})
T.same(preview:GetResults(),beforeNoteFilter,"preview groups without player notes pass the blocked-player exclusion")
find:ClearFilters()
do
 local first,second=preview.records[preview.recordIDs[4]],preview.records[preview.recordIDs[5]]
 local secondName=second.name;second.name=first.name
 T.ok(preview.Results:BlockTitle(first.name))
 T.same(preview:GetResults(),{preview.recordIDs[6]},"preview uses its own exact-title block set")
 T.eq(G.Results:GetBlockedTitleCount(),0,"preview never blocks titles in the real provider")
 T.eq(#find.appList.ids,3,"title blocks preserve pinned applications")
 T.eq(find.clearBlockedTitles,nil,"the removed clear-title button stays absent")
 T.eq(#preview.Results:GetBlockedLeaders(),2)
 preview.Results:RemoveBlockedLeader(first.leaderKey)
 T.eq(#preview:GetResults(),2,"preview removal restores a leader even while the title rule remains")
 preview.Results:BlockTitle(first.name,first.leaderKey)
 T.eq(#preview:GetResults(),1,"preview can explicitly block the removed leader again")
 local firstName=first.name
 first.name,second.name="Changed title","Another title"
 T.same(preview:GetResults(),{preview.recordIDs[6]},"preview remembers the matched leaders when titles change")
 T.eq(next(G.db.blockedLeaders),nil,"preview never saves blocked leaders in the real provider")
 preview.Results:ClearBlockedTitles()
 T.eq(preview.Results:GetBlockedTitleCount(),0);T.eq(#preview:GetResults(),3)
 first.name,second.name=firstName,secondName
end
do
 local saved={}
 for i=4,6 do
  local r=preview.records[preview.recordIDs[i]]
  saved[i]={r.bnetFriends,r.charFriends};r.bnetFriends,r.charFriends=0,0
 end
 preview.records[preview.recordIDs[6]].charFriends=1
 preview:SetFilters({sort="newest"})
 T.same(preview:GetResults(),{preview.recordIDs[6],preview.recordIDs[4],preview.recordIDs[5]},"preview puts character-friend groups first")
 preview.records[preview.recordIDs[4]].bnetFriends=1
 T.same(preview:GetResults(),{preview.recordIDs[4],preview.recordIDs[6],preview.recordIDs[5]},"Battle.net and character friends have the same priority")
 preview:SetFilters({sort="itemLevel"})
 T.same(preview:GetResults(),{preview.recordIDs[6],preview.recordIDs[4],preview.recordIDs[5]},"preview sorts within the friend and other groups")
 for i=4,6 do local r=preview.records[preview.recordIDs[i]];r.bnetFriends,r.charFriends=unpack(saved[i]) end
 find:ClearFilters()
end
do
 local members=captainRecord.details.members
 local saved={captainRecord.bnetFriends,captainRecord.charFriends,captainRecord.guildMates}
 local flags={}
 for i,member in ipairs(members) do flags[i]={member.isBNetFriend,member.isGuildMate} end
 captainRecord.bnetFriends,captainRecord.charFriends,captainRecord.guildMates=0,0,0
 for _,member in ipairs(members) do member.isBNetFriend=true;member.isGuildMate=true end
 preview:SetFilters({friends=true,guild=true})
 local function Contains(ids,wanted) for _,id in ipairs(ids) do if id==wanted then return true end end;return false end
 T.eq(Contains(preview:GetResults(),captainRecord.id),false,"relationship filters use result aggregate counts, not member flags")
 captainRecord.bnetFriends=1;captainRecord.guildMates=1
 T.eq(Contains(preview:GetResults(),captainRecord.id),true,"relationship aggregate counts admit a matching result")
 captainRecord.bnetFriends,captainRecord.charFriends,captainRecord.guildMates=unpack(saved)
 for i,member in ipairs(members) do member.isBNetFriend=flags[i][1];member.isGuildMate=flags[i][2] end
 find:ClearFilters()
end
do
 local app={id=99999,status="none",pendingStatus="applied"};preview.apps[#preview.apps+1]=app
 T.eq(preview.Applications:IsActive(app.id),true,"pending applied status counts as active")
 app.status="applied";app.pendingStatus="cancelled"
 T.eq(preview.Applications:IsActive(app.id),false,"a non-active pending transition excludes an otherwise applied record")
 app.status="none";app.pendingStatus="invited"
 T.eq(preview.Applications:IsActive(app.id),true,"pending invite status counts as active")
 preview.apps[#preview.apps]=nil
end
local previewCounts=captainRecord.details.counts
local savedTank,savedHealer,savedDamage=previewCounts.TANK,previewCounts.HEALER,previewCounts.DAMAGER
previewCounts.TANK,previewCounts.HEALER,previewCounts.DAMAGER=0,1,2
T.eq(find.filterStatus:GetText(),"0 项条件 · 待搜索","unselected sample activities retain the no-search footer state")
find:CommitChoice()
find:SetFiltersOpen(true);T.ok(find.importantFilters:IsShown());T.eq(find.filterPanel:GetWidth(),592)
Segment(find.presenceChoices.tankPresence,"missing")
Segment(find.presenceChoices.healerPresence,"present")
Segment(find.presenceChoices.damagePresence,"missing")
T.same(preview:GetResults(),{captainRecord.id},"preview combines missing tank, present healer and missing damage")
T.eq(find.filteredResultCount,1);T.eq(find.filterStatus:GetText(),"3 项条件 · 1 支队伍","sample choices immediately refresh both footer counts")
T.eq(A.charPrefs.find and A.charPrefs.find.categoryPrefs and A.charPrefs.find.categoryPrefs.seasonDungeon and A.charPrefs.find.categoryPrefs.seasonDungeon.tankPresence,nil,"popup sample choices never change the real role preferences")
Click(find.filterDone);T.ok(not find.filtersOpen);T.eq(preview.filters.healerPresence,"present","preview Done preserves direct role choices")
previewCounts.TANK,previewCounts.HEALER,previewCounts.DAMAGER=savedTank,savedHealer,savedDamage
find:ClearFilters()
T.eq(#find.appList.ids,3,"samples bind the production pinned-application list")
T.eq(preview:GetApplications()[1].status,"invited")
Click(find.autoJoin);T.eq(preview.settings.autoJoin,true);T.eq(A.db.autoJoin,savedDB.autoJoin,"preview invite handling does not change SavedVariables")
local result=preview:GetResults()[1]
find:Apply(result)
T.eq(U.Application.applicationLease,nil,"preview does not lease the registered native application dialog")
T.ok(U.Application.previewApplication~=nil)
T.eq(U.Application.applicationModal.previewNote.box:GetText(),"")
T.eq(U.Application:IsAutoApplyEnabled(),false)
if not U.Application.previewApplication.roles.DAMAGER then Click(U.Application.applicationModal.roles.DAMAGER) end
if not U.Application.previewApplication.roles.TANK then Click(U.Application.applicationModal.roles.TANK) end
T.eq(U.Application.applicationModal.roles.DAMAGER.active,true);T.eq(U.Application.applicationModal.roles.TANK.active,true,"preview also supports multiple selected roles")
U.Application.applicationModal.previewNote.box:SetText("Preview note")
Click(U.Application.applicationModal.submit)
T.eq(preview:GetApplication(result).comment,"Preview note");T.eq(preview:GetApplication(result).status,"applied")
T.eq(preview:GetApplication(result).role.tank,true);T.eq(preview:GetApplication(result).role.damage,true)
T.eq(U.activeModal,nil)
T.eq(U.Application:IsAutoApplyEnabled(),false,"a temporary preview application leaves automation off")
T.same(preview.prefs.applicationRoles,{TANK=true,HEALER=false,DAMAGER=true},"manual preview confirmation saves only to the sample provider")
T.same(A.charPrefs,savedPrefs,"preview role and filter edits do not alter the real character's preferences")
Click(find.autoApply);T.eq(find.autoApply.value,true,"valid sample roles enable directly")
T.eq(U.activeModal,nil,"valid preview roles do not open redundant configuration")
T.eq(U.Application:IsAutoApplyEnabled(),true);T.eq(preview.prefs.autoApply,true)
T.same(A.charPrefs,savedPrefs,"preview activation never saves the real character's switch")
local nextResult=preview:GetResults()[1];find:Apply(nextResult)
T.eq(U.activeModal,nil,"preview has the same configured quick-apply path")
T.eq(preview:GetApplication(nextResult).comment,"Preview note")
Click(find.applicationSettings);U.Application.applicationModal.previewNote.box:SetText("Changed sample note");Click(U.Application.applicationModal.submit)
T.eq(preview.applicationPrefs.note,"Changed sample note");T.eq(U.activeModal,nil)
T.eq(preview:Cancel(result),true);T.eq(preview:GetApplication(result).status,"cancelled")
T.eq(A:Preview("create"),true)
preview=U:GetGroup();local create=U.pages.create
T.eq(U.page,"create");T.eq(U.Native.previewCreation,true)
T.eq(U.Native.entry.Name,create.previewTitle.box,"the actual form renders ordinary preview fields")
create.previewTitle.box:SetText("Local listing");create.previewDescription.box:SetText("Local description")
create.ilvl.box:SetText("270");create.score.box:SetText("2500")
T.eq(create.publish:IsEnabled(),true)
Click(create.publish)
T.eq(preview:GetListing().name,"Local listing");T.eq(preview:GetListing().comment,"Local description")
T.eq(#preview.Presets:Get(),0,"preview publishing does not create a favorite")
T.eq(create.manage:IsShown(),true);T.eq(#create.appIDs,3,"publish opens real applicant-management layout")
local batch=create.batchPool[1];Click(batch.invite)
T.eq(preview:GetApplicant(batch.appID).status,"invited","invite only changes this sample batch")
local groupBatch
for _,row in ipairs(create.batchPool) do if row.appID==2 then groupBatch=row end end
T.ok(groupBatch~=nil);T.eq(groupBatch.people[2]:IsShown(),true,"同行成员全部在真实行池中显示")
Click(groupBatch.decline);T.eq(preview:GetApplicant(2).status,"declined")
Click(create.editListing)
T.eq(create.previewTitle.box:GetText(),"Local listing","editing copies only local fields")
create.previewTitle.box:SetText("Edited local listing");Click(create.publish)
T.eq(preview:GetListing().name,"Edited local listing")
T.eq(#preview.Presets:Get(),0,"preview updates do not create a favorite")
local preset=preview.Presets:ToggleFavorite(create:FormData())
T.ok(preset~=nil,"preview favorites require the same explicit action")
T.eq(preview.Presets:Find(preview:GetListing()),preset,"preview form and listing flags match the same favorite")
T.eq(preview.Presets:ToggleFavorite(create:FormData()),nil,"preview can cancel the current favorite")
T.eq(#preview.Presets:Get(),0)
preset=preview.Presets:ToggleFavorite(create:FormData())
preview:RemoveListing();create:UsePreset(preset)
T.eq(preview:GetListing(),nil,"applying saved settings does not publish a preview listing")
T.eq(preset.name,nil);T.eq(preset.comment,nil)
T.eq(create.previewTitle.box:GetText(),"","a new preview draft does not recover saved text")
create.previewTitle.box:SetText("Another local listing");Click(create.publish)
T.eq(preview:GetListing().name,"Another local listing")
T.eq(#preview.Presets:Get(),1);T.eq(preview.Presets:Get()[1],preset,"preview publishing keeps only the user-saved favorite")
T.eq(A:Preview("applicants"),true)
T.eq(U.pages.create.manage:IsShown(),true)
T.eq(U:GetGroup():GetListing().activityID,G.Catalog:GetActivity(2).id,"sample uses a valid client catalog activity")
U:StopPreview(false)
T.eq(U.preview,nil);T.eq(U:GetGroup(),G);T.eq(U.previewExit:IsShown(),false)
T.eq(nativeName:GetText(),"Real draft");T.eq(nativeDescription:GetText(),"Real description","registered native text is untouched")
T.same(A.db,savedDB,"preview never writes real settings")
T.same(G.db,savedGroupDB,"preview preferences stay in memory")
T.same(A.charPrefs,savedPrefs,"leaving preview preserves every real character preference")
T.eq(next(G.views),nil,"no preview owner is attached to the real backend")
T.eq(U.Native.previewCreation,nil);T.eq(U.Application.previewApplication,nil)
for _,saved in ipairs(actions) do saved[1][saved[2]]=saved[3] end
T.eq(A:Preview("applications"),true)
A:Open("settings")
T.eq(U.preview,nil,"leaving preview for a real page releases the sample provider")
T.eq(U:GetGroup(),G)
U:Hide()
