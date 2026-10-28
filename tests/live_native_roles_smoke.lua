-- Candidate installation smoke: transparent host, real native role reads, no role edits.
local probe=...
local A=assert(LycheeGroup)
assert(not InCombatLockdown(),"combat")
assert(C_AddOns.GetAddOnMetadata("LycheeGroup","Version")=="1.2.8","wrong_installed_version")
assert(not A.UI or not A.UI:IsShown(),"close_product_ui")
assert(not LFGListApplicationDialog or not LFGListApplicationDialog:IsShown(),"native_application_in_use")
assert(A:Ensure("Group"));local U=assert(A:Ensure("UI"));assert(not U.activeModal and not U.preview,"modal_in_use")
assert(A.Configuration.definitions["settings.applicationRoles"]==nil,"obsolete_schema")
for _,root in ipairs({A.db,A.charPrefs}) do
 assert(root.applicationRoles==nil,"obsolete_legacy")
 if root.uiConfig then
  assert(root.uiConfig.user["settings.applicationRoles"]==nil,"obsolete_override")
  for _,p in pairs(root.uiConfig.presets) do assert(p.values["settings.applicationRoles"]==nil,"obsolete_preset") end
 end
end
if not U.frame then U:Build() end
assert(U.Native:Ready())
local dialog=LFGListApplicationDialog
local note=dialog.Description.EditBox
local parent,onEvent,onShow=note:GetParent(),dialog:GetScript("OnEvent"),dialog:GetScript("OnShow")
local before={GetLFGRoles()};local app=U.Application;local layout=app.LayoutApplication
local owned=false
local hostShown=false
assert(probe:OnCleanup(function()
 app.LayoutApplication=layout
 if owned then app:ReleaseApplication();owned=false end
 if hostShown then U.frame:Hide();hostShown=false end
end))
-- A modal must have a visible parent for native OnHide ownership cleanup.
-- The newly built host has alpha zero; no page or real search is opened.
assert(U.frame:GetAlpha()==0,"host_should_be_transparent")
U.frame:Show();hostShown=true
assert(app:OpenApplicationSettings());owned=true
local tank,healer,damage=C_LFGList.GetAvailableRoles()
for i,role in ipairs({"TANK","HEALER","DAMAGER"}) do
 local available=({tank,healer,damage})[i]
 assert((app.applicationLease.roles[role]==true)==(before[i+1]==true and available==true),"native_role_mismatch_"..role)
end
local count=0
function app:LayoutApplication(...) count=count+1;return layout(self,...) end
local start=debugprofilestop()
for i=1,300 do app:RefreshApplicationRoles() end
local cost=debugprofilestop()-start
assert(count==0,"stable_refresh_relayout")
app.LayoutApplication=layout;app:ReleaseApplication();owned=false
U.frame:Hide();hostShown=false
local after={GetLFGRoles()}
for i=1,4 do assert(before[i]==after[i],"native_roles_changed") end
assert(note:GetParent()==parent and dialog:GetScript("OnEvent")==onEvent and dialog:GetScript("OnShow")==onShow,"native_lease_not_restored")
assert(not app.applicationLease and not U.activeModal and not U:IsShown(),"ui_cleanup_failed")
local observe=debugprofilestop();UpdateAddOnMemoryUsage();observe=debugprofilestop()-observe
local memory,total={},0
for _,name in ipairs({"LycheeGroup","LycheeGroup_Group","LycheeGroup_UI","LycheeGroup_Notes","LycheeGroup_Guide"}) do
 local bytes=GetAddOnMemoryUsage(name)*1024;memory[name]=bytes;total=total+bytes
end
return {version="1.2.8",nativeRolesMatched=true,unchangedRoles=true,stableRefreshes=300,layouts=count,refreshTotalMs=cost,nativeLeaseRestored=true,hiddenUI=true,memoryBytes=memory,totalBytes=total,memoryObserverMs=observe,memoryScope="single natural sample after hidden UI first build; not workload peak",fullCollection=false}
