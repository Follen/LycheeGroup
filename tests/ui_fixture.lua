-- Shared offline UI fixtures; no game client is contacted.
return function(locale,preferences,settings)
local base=dofile("tests/stubs.lua");base.Install({locale=locale,realm="Home"})
local S=dofile("tests/ui_stubs.lua");S.Install()
C_SpecializationInfo.GetSpecialization=function() return nil end
_G.LycheeGroup=nil;_G.LycheeGroupDB=nil;_G.LycheeGroupPrefsDB=nil;_G.LycheeGroupNotesDB=nil;_G.LibStub=nil
dofile("addon/LycheeGroup/Core.lua");dofile("addon/LycheeGroup/Specializations.lua");dofile("addon/LycheeGroup/Locale.lua");dofile("addon/LycheeGroup/Fonts.lua")
-- WoW restores SavedVariables after executing the addon's files.
_G.LycheeGroupDB=settings;_G.LycheeGroupPrefsDB=preferences
local A=LycheeGroup;A:LoadDB();dofile("addon/LycheeGroup/Bindings.lua")
for _,file in ipairs({"Locale.lua","Notes.lua","Records.lua","PlayerInfo.lua","RosterReminder.lua"}) do dofile("addon/LycheeGroup_Notes/"..file) end
A.Notes:Initialize()
local G={db={prefs={}},prefs=A.charPrefs,subs={},views={},records={},apps={},applicants={},state="idle"}
local blockedTitles,blockedTitleCount={},0
A.Group=G
dofile("addon/LycheeGroup_Group/CreationPresets.lua")
dofile("addon/LycheeGroup_Group/RaidBuffs.lua")
dofile("addon/LycheeGroup/Presentation.lua")
G.db.creationPresets={};G.Presets=A.CreationPresets.New(G.db.creationPresets,function() G:Notify("creationPresets") end)
function G:Subscribe(fn) self.subs[fn]=true;return function() self.subs[fn]=nil end end
function G:Notify(kind,id) for fn in pairs(self.subs) do fn(kind,id) end end
function G:Attach(view,kind) self.views[view]=kind end
function G:Detach(view) self.views[view]=nil end
function G:SetApplicantView(owner,visible) self.applicantViews=self.applicantViews or {};self.applicantViews[owner]=visible or nil end
function G:OnSettingChanged(key,value)
 if key=="autoJoin" and value then self.Applications:TryAutoJoin() end
end
function G:GetActivities() return {{id=1,name="Raid activity",fullName="A full raid activity name"}} end
function G:GetHistory() return {} end
function G:GetResults() local ids={};for id,record in pairs(self.records) do if not blockedTitles[record.name] and not self.Applications:IsActive(id) then ids[#ids+1]=id end end;table.sort(ids);return ids end
function G:GetResult(id) return self.records[id] end
function G:GetResultCount() local n=0;for _ in pairs(self.records) do n=n+1 end;return n end
function G:GetResultDetails(id) return self.records[id] and {members={},counts={TANK=1,HEALER=1,DAMAGER=2},encounters={}} end
function G:GetRoster() return {{name="Player",nameKey="Player-Home",class="WARRIOR",assignedRole="TANK",isLeader=true}} end
function G:GetRaidBuffs(activityID)
 local report=A.RaidBuffs.Get(self.Catalog,activityID,self:GetRoster(),self.buffReport)
 if report then self.buffReport=report end
 return report
end
function G:GetApplications() return self.apps end
function G:GetApplication(id) for _,app in ipairs(self.apps) do if app.id==id then return app end end end
function G:GetApplicants() local ids={};for id in pairs(self.applicants) do ids[#ids+1]=id end;table.sort(ids);return ids end
function G:GetApplicant(id) return self.applicants[id] end
function G:GetSearchState() return self.state end
function G:GetSearchError() return self.error end
function G:SetFilters(filters) self.filters=filters;self:Notify("results") end
function G:GetListing() return self.listing end
function G:GetApplicantDungeonScores(member) return member.dungeonScores end
function G:GetApplicantMapScore(member) return member.dungeonScores and member.dungeonScores.mapScore end
function G:CanManageApplicants() if self.manageApplicants==false then return false,"Cannot manage applicants" end;return true end
function G:CanManageListing() if self.manageListing==false then return false,"Cannot manage listing" end;return true end
function G:RefreshApplicants() if not self.listing then return false end;self.refreshApplicants=(self.refreshApplicants or 0)+1;self:Notify("applicants");return true end
function G:Apply(id,roles)
 if self.listing then return false,self.L.recruiting end
 if self.Applications:IsActive(id) then return false,self.L.alreadyApplied end
 if self.Applications:GetActiveCount()>=5 then return false,self.L.applicationLimit end
 self.applyCalls=(self.applyCalls or 0)+1
 local ok=pcall(C_LFGList.ApplyToGroup,id,roles.tank==true,roles.healer==true,roles.damage==true)
 return ok,not ok and self.L.applyFailed or nil
end
function G:Cancel(id) self.cancelled=id;return true end
function G:AcceptInvite(id) self.accepted=id;return true end
function G:DeclineInvite(id) self.declined=id;return true end
function G:Invite(id) local allowed,reason=self:CanManageApplicants();if not allowed then return false,reason end;local app=self.applicants[id];if app.acting then return false,"Busy" end;app.acting=true;self.invitedApplicant=id;self:Notify("applicants");return true end
function G:Decline(id) local allowed,reason=self:CanManageApplicants();if not allowed then return false,reason end;local app=self.applicants[id];if app.acting then return false,"Busy" end;app.acting=true;self.declinedApplicant=id;self:Notify("applicants");return true end
G.Search={}
function G.Search:BindInput(lease) self.inputLease=lease end
function G.Search:ReleaseInput(lease) if self.inputLease==lease then self.inputLease=nil end end
G.Results={}
function G.Results:GetDetails(record) return record.details or {members={},counts={TANK=1,HEALER=1,DAMAGER=2},encounters={}} end
function G.Results:InvalidateView() end
function G.Results:BlockTitle(title)
 if title==nil or blockedTitles[title] then return false end
 blockedTitles[title]=true;blockedTitleCount=blockedTitleCount+1;G:Notify("results");return true
end
function G.Results:ClearBlockedTitles()
 if blockedTitleCount==0 then return false end
 wipe(blockedTitles);blockedTitleCount=0;G:Notify("results");return true
end
function G.Results:GetBlockedTitleCount() return blockedTitleCount end
G.Applications={}
function G.Applications:IsActive(id)
 local app=G:GetApplication(id);if not app then return false end
 local status,pending=app.status,app.pendingStatus
 if pending and pending~="applied" and pending~="invited" then return false end
 return status=="applied" or status=="invited" or (status==nil or status=="none") and (pending=="applied" or pending=="invited")
end
function G.Applications:TryAutoJoin() end
function G.Applications:CanCancel(id) local app=G:GetApplication(id);return app~=nil and app.status=="applied" and not app.pendingStatus end
function G.Applications:GetActiveCount()
 local count=0;for _,app in ipairs(G.apps) do if self:IsActive(app.id) then count=count+1 end end;return count
end
G.Alerts={Stop=function() end}
function G.Search:EndBrowse() G.state="idle";self.pending=nil;if self.timer then self.timer:Cancel();self.timer=nil end;G:Notify("results") end
function G.Search:Search(category,activityID,mode,text)
 if mode=="leader" then C_LFGList.ClearSearchTextFields() end
 G.searchText=LFGListFrame.SearchPanel.SearchBox:GetText();G.searchMode=mode;G.leaderText=text;G.state="done";G:Notify("results");G:Notify("search");return true
end
function G:Publish(data)
 self.published=data
 self.listing={activityID=data.activityID,activityIDs={data.activityID},name=LFGListFrame.EntryCreation.Name:GetText(),comment=LFGListFrame.EntryCreation.Description.EditBox:GetText(),generalPlaystyle=data.generalPlaystyle,isCrossFactionListing=data.isCrossFactionListing,requiredItemLevel=data.requiredItemLevel,requiredDungeonScore=data.requiredDungeonScore,requiredPvpRating=data.requiredPvpRating,autoAccept=data.isAutoAccept,privateGroup=data.isPrivateGroup,playstyle=data.playstyle,newPlayerFriendly=data.newPlayerFriendly,questID=data.questID}
 self:Notify("listing");return true
end
function G:Update(data) self.updated=data;return true end
function G:RemoveListing() self.listing=nil;self:Notify("listing");return true end
local activities={
 [1]={id=1,categoryID=3,mapID=110,fullName="Raid activity",shortName="Raid",groupFinderActivityGroupID=10,difficultyID=14,maxNumPlayers=30,orderIndex=1,allowCrossFaction=true},
 [2]={id=2,categoryID=2,fullName="Dungeon activity",shortName="Dungeon",groupFinderActivityGroupID=20,difficultyID=8,isMythicPlusActivity=true,maxNumPlayers=5,orderIndex=1,allowCrossFaction=true},
 [3]={id=3,categoryID=2,fullName="Dungeon normal",shortName="Normal",groupFinderActivityGroupID=20,difficultyID=1,maxNumPlayers=5,orderIndex=2,allowCrossFaction=true}}
local selectedTier=1
EJ_GetCurrentTier=function() return selectedTier end
EJ_GetNumTiers=function() return 2 end
EJ_GetTierInfo=function(tier) return tier==2 and "Current season" or "Test expansion" end
EJ_SelectTier=function(tier) selectedTier=tier end
EJ_GetInstanceByIndex=function(index,isRaid) if index==1 and isRaid then return 10,"Raid" end end
EJ_GetInstanceInfo=function() return "Raid",nil,nil,67890,nil,12345 end
C_EncounterJournal.GetInstanceForGameMap=function(map) if map==110 then return 10 end end
C_LFGList={
 HasActiveEntryInfo=function() return G.listing~=nil end,
 GetActivityInfoTable=function(id) return activities[id] end,
 GetAvailableCategories=function() return {2,3} end,
 GetLfgCategoryInfo=function(id) return {name=id==2 and "Dungeons" or "Raids",showPlaystyleDropdown=true,allowCrossFaction=true} end,
 GetAvailableActivityGroups=function(id) return {id==2 and 20 or 10} end,
 GetAvailableActivities=function(category,group,flags) if category==2 then if flags==68 then return {2,3} elseif flags==4 then return {2,3} else return {3} end end;return {1} end,
 GetActivityGroupInfo=function(id) return id==20 and "Dungeon" or "Raid" end,
 GetActivityFullName=function(id) return activities[id].fullName end,
 ClearCreationTextFields=function() local e=LFGListFrame.EntryCreation;e.Name:UserType("");e.Description.EditBox:UserType("") end,
 CopyActiveEntryInfoToCreationFields=function() local e=LFGListFrame.EntryCreation;e.Name:UserType(G.listing.name);e.Description.EditBox:UserType(G.listing.comment or "") end,
 SetEntryTitle=function(id) LFGListFrame.EntryCreation.Name:UserType(activities[id].fullName);G.autoTitle=activities[id].fullName end,
 DoesEntryTitleMatchPrebuiltTitle=function() error("Saved settings must not inspect protected listing titles") end,
 ClearApplicationTextFields=function() G.clearedApplication=true end,
 ClearSearchTextFields=function() G.searchClears=(G.searchClears or 0)+1;local box=LFGListFrame.SearchPanel.SearchBox;box.text="";box:Fire("OnTextChanged",false) end,
}
dofile("tests/application_fixture.lua")(S)
dofile("addon/LycheeGroup_Group/Locale.lua");G.L=A.GroupLocale;dofile("addon/LycheeGroup_Group/Catalog.lua")
_G.LycheeUI=nil
local libraryPrivate={}
for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Components.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",libraryPrivate) end
for _,file in ipairs({"Locale.lua","Theme.lua","Motion.lua","Components.lua","Members.lua","Preview.lua","Tooltip.lua","Native.lua","Application.lua","Transfer.lua","Host.lua","Find.lua","Create.lua","Notes.lua","Settings.lua"}) do dofile("addon/LycheeGroup_UI/"..file) end
local U=A.UI;local C=U.C
local Open=A.Open
function A:Open(page,ctx) self.lastOpen=page;return Open(self,page,ctx) end
function A:Ensure(module) return self[module] end
function A:RecordPlayer(name,realm,unit) A:Open("notes",{add={name=name,realm=realm,unit=unit}}) end
local function Pick(button,value)
 button:Fire("OnClick","LeftButton")
 local menu=U.context.menu
 for _,row in ipairs(menu.list.rows) do
  local item=row.key and menu.items[row.key]
  if item and item.value==value and row:IsVisible() then row:Fire("OnMouseDown");row:Fire("OnClick","LeftButton");return end
 end
 error("menu value not found: "..tostring(value))
end
local function Count(table) local n=0;for _ in pairs(table) do n=n+1 end;return n end

return {A=A,U=U,G=G,S=S,base=base,Pick=Pick,Count=Count}
end
