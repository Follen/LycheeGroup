-- Explicit preview uses the production pages, with all real mutation exits trapped.
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G=f.A,f.U,f.G
A.db.reduceMotion=true
local function Clone(value)
 if type(value)~="table" then return value end
 local copy={};for k,v in pairs(value) do copy[k]=Clone(v) end;return copy
end
local savedDB=Clone(A.db);local savedGroupDB=Clone(G.db)
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
local combat=InCombatLockdown;_G.InCombatLockdown=function() return true end
T.eq(A:Preview("applications"),true,"preview has no blanket combat gate")
_G.InCombatLockdown=combat;U.pages.find.main:Fire("OnEvent","PLAYER_REGEN_ENABLED")
local preview=U:GetGroup()
T.eq(A.Group,G,"the real backend is never replaced")
T.ok(preview~=G);T.eq(#preview:GetApplications(),3)
T.eq(U.page,"find");T.eq(U.previewExit:IsShown(),true)
local find=U.pages.find
T.eq(find.search.box,find.previewSearchBox,"preview keeps its own ordinary search input")
T.eq(U.Native.searchLease,nil);T.eq(nativeSearch:GetParent(),LFGListFrame.SearchPanel)
find.search.box:SetText("Preview group 2");T.eq(preview.filters.text,"Preview group 2","preview group mode uses simulated title filtering")
find.search.box:SetText("12-15")
T.same(preview:GetResults(),{preview.recordIDs[4],preview.recordIDs[5],preview.recordIDs[6]},"preview simulates group-mode keystone range filtering")
find.search.box:SetText("12-13")
T.same(preview:GetResults(),{preview.recordIDs[4],preview.recordIDs[5]},"preview range includes both bounds and excludes higher levels")
find.search.box:SetText(preview.records[preview.recordIDs[4]].name)
T.same(preview:GetResults(),{preview.recordIDs[4]},"preview simulates native group-name matching")
find.search.box:SetText("描述检索样例")
T.same(preview:GetResults(),{},"preview does not claim native descriptions are locally searchable")
find:SetSearchMode("leader")
local captainRecord=preview.records[preview.recordIDs[4]]
local captain,comment=captainRecord.leaderName,captainRecord.comment
find.search.box:SetText(captain)
T.same(preview:GetResults(),{preview.recordIDs[4]},"leader preview searches the exposed leader name")
captainRecord.leaderName=nil;captainRecord.comment="描述检索样例"
find.search.box:SetText("描述检索样例")
T.same(preview:GetResults(),{},"leader mode does not inspect descriptions when the leader name is absent")
captainRecord.leaderName=captain;captainRecord.comment=comment
find.search.box:SetText("");T.eq(nativeSearch:GetText(),"Real native range 12-15","preview search never clears or rewrites the registered input")
preview.records[preview.recordIDs[5]].numMembers=3;preview.records[preview.recordIDs[6]].numMembers=4
find.fMembers.box:SetText("3");find.fMinMembers.box:SetText("3")
T.same(preview:GetResults(),{preview.recordIDs[5]},"preview applies inclusive minimum and maximum independently")
find.fMinMembers.box:SetText("4");T.eq(preview.filters.maxMembers,3);T.eq(#preview:GetResults(),0,"a contradictory range honestly has no results")
find:ClearFilters();T.eq(preview.filters.minMembers,nil);T.eq(preview.filters.maxMembers,nil)
local beforeNoteFilter=preview:GetResults()
preview:SetFilters({notes="noCaution"})
T.same(preview:GetResults(),beforeNoteFilter,"preview groups without player notes pass the blocked-player exclusion")
find:ClearFilters()
local previewCounts=captainRecord.details.counts
local savedTank,savedHealer,savedDamage=previewCounts.TANK,previewCounts.HEALER,previewCounts.DAMAGER
previewCounts.TANK,previewCounts.HEALER,previewCounts.DAMAGER=0,1,2
Click(find.rolePresenceChoices.TANK.buttons[3])
Click(find.rolePresenceChoices.HEALER.buttons[2])
Click(find.rolePresenceChoices.DAMAGER.buttons[2])
T.same(preview:GetResults(),{captainRecord.id},"preview combines missing tank, present healer and missing damage")
previewCounts.TANK,previewCounts.HEALER,previewCounts.DAMAGER=savedTank,savedHealer,savedDamage
find:ClearFilters()
T.eq(#find.appList.ids,3,"samples bind the production pinned-application list")
T.eq(preview:GetApplications()[1].status,"invited")
Click(find.autoJoin);T.eq(preview.settings.autoJoin,true);T.eq(A.db.autoJoin,savedDB.autoJoin,"preview invite handling does not change SavedVariables")
local result=preview:GetResults()[1]
find:Apply(result)
T.eq(U.Native.applicationLease,nil,"preview does not lease the registered native application dialog")
T.ok(U.Native.previewApplication~=nil)
T.eq(U.Native.applicationModal.previewNote.box:GetText(),"")
T.eq(U.Native:IsAutoApplyEnabled(),false)
if not U.Native.previewApplication.roles.DAMAGER then Click(U.Native.applicationModal.roles.DAMAGER) end
if not U.Native.previewApplication.roles.TANK then Click(U.Native.applicationModal.roles.TANK) end
T.eq(U.Native.applicationModal.roles.DAMAGER.active,true);T.eq(U.Native.applicationModal.roles.TANK.active,true,"preview also supports multiple selected roles")
U.Native.applicationModal.previewNote.box:SetText("Preview note")
Click(U.Native.applicationModal.submit)
T.eq(preview:GetApplication(result).comment,"Preview note");T.eq(preview:GetApplication(result).status,"applied")
T.eq(preview:GetApplication(result).role.tank,true);T.eq(preview:GetApplication(result).role.damage,true)
T.eq(U.activeModal,nil)
T.eq(U.Native:IsAutoApplyEnabled(),false,"a temporary preview application leaves automation off")
Click(find.autoApply);T.eq(find.autoApply.value,false)
Click(U.Native.applicationModal.submit);T.eq(U.Native:IsAutoApplyEnabled(),true)
local nextResult=preview:GetResults()[1];find:Apply(nextResult)
T.eq(U.activeModal,nil,"preview has the same configured quick-apply path")
T.eq(preview:GetApplication(nextResult).comment,"Preview note")
Click(find.applicationSettings);U.Native.applicationModal.previewNote.box:SetText("Changed sample note");Click(U.Native.applicationModal.submit)
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
T.eq(A:Preview("applicants"),true)
T.eq(U.pages.create.manage:IsShown(),true)
T.eq(U:GetGroup():GetListing().activityID,G.Catalog:GetActivity(2).id,"sample uses a valid client catalog activity")
U:StopPreview(false)
T.eq(U.preview,nil);T.eq(U:GetGroup(),G);T.eq(U.previewExit:IsShown(),false)
T.eq(nativeName:GetText(),"Real draft");T.eq(nativeDescription:GetText(),"Real description","registered native text is untouched")
T.same(A.db,savedDB,"preview never writes real settings")
T.same(G.db,savedGroupDB,"preview preferences stay in memory")
T.eq(next(G.views),nil,"no preview owner is attached to the real backend")
T.eq(U.Native.previewCreation,nil);T.eq(U.Native.previewApplication,nil)
for _,saved in ipairs(actions) do saved[1][saved[2]]=saved[3] end
T.eq(A:Preview("applications"),true)
A:Open("settings")
T.eq(U.preview,nil,"leaving preview for a real page releases the sample provider")
T.eq(U:GetGroup(),G)
U:Hide()
