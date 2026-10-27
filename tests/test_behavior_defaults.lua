-- Effective behavior defaults use the production configuration and UI consumers.
-- Standalone: lua tests/test_behavior_defaults.lua
local Fixture=dofile("tests/ui_fixture.lua")
local checks=0
local function Eq(actual,expected,message)
 checks=checks+1
 if T then T.eq(actual,expected,message) else assert(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected)) end
end
local function Ok(value,message) Eq(not not value,true,message) end
local function Click(button) button:Fire("OnClick","LeftButton") end
local auto,roles,raid="settings.autoApply","settings.applicationRoles","settings.creationRaidDifficultyID"
local function Package(f,revision,enabled,selected,difficulty)
 Ok(f.A.Configuration:RegisterPreset("suite",revision,{[auto]=enabled,[roles]=selected,[raid]=difficulty},{storage="account",default=true}))
end
local function Start(character,account)
 local f=Fixture("zhCN",character,account);f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 return f,f.A.Configuration,f.U.Application
end

-- New characters follow upgrades without reads becoming overrides. Old values,
-- including false and empty tables, import once as explicit character choices.
do
 local character,account={},{};local f,c,app=Start(character,account)
 Eq(f.A:GetSetting("autoApply"),false);Eq(f.A:GetSetting("applicationRoles"),false);Eq(f.A:GetSetting("creationRaidDifficultyID"),false)
 Package(f,1,true,{TANK=true},15)
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("applicationRoles").TANK,true);Eq(f.A:GetSetting("creationRaidDifficultyID"),15)
 Eq(character.uiConfig.user[auto],nil);Eq(character.uiConfig.user[roles],nil);Eq(character.uiConfig.user[raid],nil,"reading defaults never pins a character choice")
 Eq(character.autoApply,false,"legacy mirror is not the effective default")
 Package(f,2,false,{DAMAGER=true},16)
 Eq(app:IsAutoApplyEnabled(),false);Eq(f.A:GetSetting("applicationRoles").DAMAGER,true)
 Ok(f.A:SetSetting("autoApply",true));Ok(f.A:SetSetting("applicationRoles",{}));Ok(f.A:SetSetting("creationRaidDifficultyID",false))
 Package(f,3,false,{TANK=true},15)
 Ok(app:IsAutoApplyEnabled());Eq(next(f.A:GetSetting("applicationRoles")),nil);Eq(f.A:GetSetting("creationRaidDifficultyID"),false)
 Ok(f.A:SetSetting("autoApply",false));Ok(f.A:SetSetting("applicationRoles",{TANK=false,HEALER=false,DAMAGER=false}))
 Package(f,4,true,{TANK=true},16)
 Eq(app:IsAutoApplyEnabled(),false);Eq(f.A:GetSetting("applicationRoles").TANK,false)
 f.U:Hide(true);f,c,app=Start(character,account)
 Eq(app:IsAutoApplyEnabled(),false);Eq(f.A:GetSetting("applicationRoles").DAMAGER,false);Eq(f.A:GetSetting("creationRaidDifficultyID"),false)
 Ok(c:Reset({auto,roles,raid},{storage="character"}))
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("applicationRoles").TANK,true);Eq(f.A:GetSetting("creationRaidDifficultyID"),16)
 f.U:Hide(true);f,c,app=Start(character,account)
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("creationRaidDifficultyID"),16,"reload after reset does not import manufactured mirrors")
 f.U:Hide(true)
 for _,saved in ipairs({{}, {TANK=false,HEALER=false,DAMAGER=false}}) do
  f,c,app=Start({autoApply=false,applicationRoles=saved,creationRaidDifficultyID=14},{})
  Package(f,1,true,{TANK=true},16)
  Eq(app:IsAutoApplyEnabled(),false)
  local effective=f.A:GetSetting("applicationRoles");for _,key in ipairs({"TANK","HEALER","DAMAGER"}) do Eq(effective[key],saved[key]) end
  Eq(f.A:GetSetting("creationRaidDifficultyID"),14)
  f.U:Hide(true)
 end
 f,c,app=Start({}, {autoApply=true,applicationRoles={TANK=true},creationRaidDifficultyID=15})
 Package(f,1,false,{DAMAGER=true},16)
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("applicationRoles").TANK,true);Eq(f.A:GetSetting("creationRaidDifficultyID"),15,"old account preference migrates into character ownership")
 f.U:Hide(true)
 f,c,app=Start({applicationRoles={TANK=true,HEALER=false,DAMAGER="true",OTHER=true}},{})
 local repaired=f.A:GetSetting("applicationRoles")
 Eq(repaired.TANK,true);Eq(repaired.HEALER,false);Eq(repaired.DAMAGER,nil);Eq(repaired.OTHER,nil,"migration preserves valid legacy role leaves")
 f.U:Hide(true)
end

-- Reject malformed role/difficulty values atomically; false and empty roles are
-- deliberate values, not a request to inherit the suite's selection.
do
 local f,c=Start({},{});Package(f,1,true,{TANK=true},15)
 for _,invalid in ipairs({true,"TANK",{TANK=1},{HEALER="true"},{LEADER=true},{[1]=true}}) do
  Eq(c:Set({[roles]=invalid,[auto]=false},{storage="character"}),false)
  Eq(f.A:GetSetting("autoApply"),true);Eq(f.A:GetSetting("applicationRoles").TANK,true)
 end
 for _,invalid in ipairs({true,"15",0,-1,1.5,math.huge,0/0,{}}) do
  Eq(c:Set({[raid]=invalid},{storage="character"}),false)
  Eq(f.A:GetSetting("creationRaidDifficultyID"),15)
 end
 f.U:Hide(true)
end

-- A displayed settings dialog follows defaults/reset until a role is edited.
-- Changes only update controls: no application, native role write or listing.
do
 local f,c,app=Start({},{});local dialog=LFGListApplicationDialog
 dialog.available={TANK=true,HEALER=true,DAMAGER=true}
 Package(f,1,true,{TANK=true},15);Ok(app:OpenApplicationSettings())
 local modal=app.applicationModal
 Eq(app.applicationLease.roles.TANK,true);Ok(modal.autoApply.value)
 Package(f,2,false,{HEALER=true},16)
 Eq(app.applicationLease.roles.TANK,nil);Eq(app.applicationLease.roles.HEALER,true);Eq(modal.autoApply.value,false)
 Ok(f.A:SetSetting("applicationRoles",{}));Eq(next(app.applicationLease.roles),nil,"explicit clear stays clear instead of choosing native roles")
 Eq(modal.submit:IsEnabled(),false)
 Ok(c:Reset(roles,{storage="character"}));Eq(app.applicationLease.roles.HEALER,true)
 app:SetApplicationRole("DAMAGER");Package(f,3,true,{TANK=true},15)
 Eq(app.applicationLease.roles.HEALER,true);Eq(app.applicationLease.roles.DAMAGER,true);Eq(app.applicationLease.roles.TANK,nil,"an edited role draft survives external defaults")
 Eq(f.G.applyCalls,nil);Eq(dialog.submissions,0);Eq(f.G.published,nil)
 Click(modal.submit)
 Eq(f.A.charPrefs.uiConfig.user[roles].HEALER,true);Eq(f.A.charPrefs.uiConfig.user[roles].DAMAGER,true,"Save explicitly commits roles to the character user layer")
 Ok(f.A:Preview("applications"));local provider=f.U:GetGroup()
 Eq(app:IsAutoApplyEnabled(),false)
 Package(f,4,false,{DAMAGER=true},16)
 Eq(app:IsAutoApplyEnabled(),false,"real configuration callbacks do not mutate preview preferences")
 Ok(app:OpenApplicationSettings());if not app.previewApplication.roles.TANK then app:SetApplicationRole("TANK") end;Click(app.applicationModal.submit)
 Eq(f.A.charPrefs.uiConfig.user[roles].HEALER,true);Eq(provider.prefs.applicationRoles.TANK,true)
 f.U:StopPreview(true);Eq(app:IsAutoApplyEnabled(),false)
 for line in io.lines("addon/LycheeGroup_Guide/LycheeGroup_Guide.toc") do
  local file=line:match("^%s*(.-)%s*$")
  if file~="" and file:sub(1,1)~="#" then dofile("addon/LycheeGroup_Guide/"..file) end
 end
 local guide=f.A.Guide;Ok(guide:Open());Ok(guide:Start());provider=f.U:GetGroup()
 Package(f,5,true,{TANK=true},15)
 Eq(app:IsAutoApplyEnabled(),false,"guide automation remains private when the real default changes")
 Ok(app:OpenApplicationSettings())
 local selected;for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do if provider.player.roles[role] then selected=role;break end end
 if not app.previewApplication.roles[selected] then app:SetApplicationRole(selected) end;Click(app.applicationModal.submit)
 Eq(provider.prefs.applicationRoles[selected],true);Eq(f.A.charPrefs.uiConfig.user[roles].HEALER,true)
 guide:Stop("interrupted");Ok(app:IsAutoApplyEnabled(),"leaving guide restores the current effective default")
 f.U:Hide(true)
end

-- Raid fallback reads the effective default; only a real difficulty click pins
-- it. Preview remains isolated, and a false override restores product fallback.
do
 local f,c=Start({},{});local nativeInfo,nativeActivities=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities
 local entries={};for group=10,20,10 do for index,difficulty in ipairs({14,15,16}) do
  local id=group*10+index;entries[id]={id=id,categoryID=3,mapID=110,fullName="Raid "..group,shortName="Raid "..group,groupFinderActivityGroupID=group,difficultyID=difficulty,maxNumPlayers=30,orderIndex=id}
 end end
 C_LFGList.GetActivityInfoTable=function(id) return entries[id] or nativeInfo(id) end
 C_LFGList.GetAvailableActivities=function(category,...) if category==3 then return {101,102,103,201,202,203} end;return nativeActivities(category,...) end
 C_LFGList.GetActivityGroupInfo=function(id) return "Activity "..id end
 f.G.Catalog:Invalidate();Package(f,1,false,false,15);f.A:Open("create");local p=f.U.pages.create
 local function Choose(group)
  Click(p.pickerTrigger);p.pickerCategory="3";p.pickerTier=nil;p:RefreshPickerRows()
  for _,row in ipairs(p.pickerResults.rows) do if row:IsShown() and row.key=="3:"..group then Click(row);return end end
  error("missing raid picker row")
 end
 Choose(10);Eq(p:FormData().activityID,102);Eq(f.A.charPrefs.uiConfig.user[raid],nil)
 Package(f,2,false,false,16);Eq(p:FormData().activityID,102,"a valid creation draft is preserved")
 Choose(20);Eq(p:FormData().activityID,203)
 p:SelectDifficulty(202);Eq(f.A.charPrefs.uiConfig.user[raid],15)
 Package(f,3,false,false,14);Choose(10);Eq(p:FormData().activityID,102)
 Ok(f.A:SetSetting("creationRaidDifficultyID",false));Choose(20);Eq(p:FormData().activityID,201)
 Ok(c:Reset(raid,{storage="character"}));Choose(10);Eq(p:FormData().activityID,101)
 Ok(f.A:Preview("create"));Choose(20);p:SelectDifficulty(203)
 Eq(f.U:GetGroup().prefs.creationRaidDifficultyID,16);Eq(f.A.charPrefs.uiConfig.user[raid],nil)
 f.U:StopPreview(true);Eq(f.A:GetSetting("creationRaidDifficultyID"),14)
 f.U:Hide(true)
end

-- The core party check uses the effective role default without loading another
-- consumer or relying on the compatibility mirror.
do
 local f,c=Start({},{});Package(f,1,false,{HEALER=true},15)
 Eq(f.A.charPrefs.applicationRoles,false)
 local replaced={"IsInGroup","UnitIsGroupLeader","InCombatLockdown","LFDRoleCheckPopup","LFDRoleCheckPopupRoleButtonTank","LFDRoleCheckPopupRoleButtonHealer","LFDRoleCheckPopupRoleButtonDPS","LFDPopupCheckRoleSelectionValid","GetLFGRoles","SetLFGRoles","CompleteLFGRoleCheck","StaticPopupSpecial_Hide"}
 local original={};for _,key in ipairs(replaced) do original[key]=_G[key] end
 IsInGroup=function() return true end;UnitIsGroupLeader=function() return false end;InCombatLockdown=function() return false end
 C_LFGList.GetRoleCheckInfo=function() return true end;C_LFGList.GetAvailableRoles=function() return true,true,true end
 LFDRoleCheckPopup=CreateFrame("Frame");LFDRoleCheckPopup:Hide()
 local button={IsEnabled=function() return true end};LFDRoleCheckPopupRoleButtonTank=button;LFDRoleCheckPopupRoleButtonHealer=button;LFDRoleCheckPopupRoleButtonDPS=button
 LFDPopupCheckRoleSelectionValid=function() return true end
 local selected,submitted
 GetLFGRoles=function() return false,false,false,true end
 SetLFGRoles=function(...) selected={...} end;CompleteLFGRoleCheck=function() submitted=(submitted or 0)+1;return true end
 StaticPopupSpecial_Hide=function(popup) popup:Hide() end
 local create,events=CreateFrame
 CreateFrame=function(...) events=create(...);return events end
 dofile("addon/LycheeGroup/PartyRoleCheck.lua");CreateFrame=create
 local function Show() events:Fire("OnEvent","LFG_ROLE_CHECK_SHOW");LFDRoleCheckPopup:Show();f.base.AdvanceClock(0);events:Fire("OnEvent","LFG_ROLE_CHECK_HIDE") end
 Show();Eq(submitted,1);Eq(selected[2],false);Eq(selected[3],true);Eq(selected[4],false)
 Ok(f.A:SetSetting("applicationRoles",{}));Show();Eq(submitted,1,"explicit cleared roles require native manual confirmation")
 Ok(c:Reset(roles,{storage="character"}));Show();Eq(submitted,2)
 f.U:Hide(true)
 for _,key in ipairs(replaced) do _G[key]=original[key] end
end
print("behavior defaults: "..checks.." checks passed")
