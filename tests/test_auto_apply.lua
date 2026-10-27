-- Focused production application flow: lua tests/test_auto_apply.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Fixture(locale,prefs)
 local f=dofile("tests/ui_fixture.lua")(locale,prefs)
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 return f,f.A,f.U,f.G,f.U.Application,f.U.pages.find
end
local function Click(button) button:Fire("OnClick","LeftButton") end

for _,locale in ipairs({"zhCN","enUS"}) do
 -- Saved valid roles enable directly, and both entry points share the saved flag.
 local prefs={applicationRoles={TANK=true,HEALER=false,DAMAGER=false},autoApply=true}
 local f,a,u,g,application,find=Fixture(locale,prefs)
 Check(application:IsAutoApplyEnabled() and find.autoApply.value,"a saved character flag restores on load")
 application:OpenApplicationSettings();local modal=application.applicationModal
 Check(modal.autoApply.value and modal.autoApply.box:GetChecked(),"the modal restores the same checked state")
 Check(modal.autoApply.box:GetParent()==modal.autoApply and not modal.autoApply.box:IsMouseEnabled(),"one click target covers the box and its label")
 Click(modal.autoApply)
 Check(not application:IsAutoApplyEnabled() and not find.autoApply.value and prefs.autoApply==false,"modal disable synchronizes the main switch and character data")
 Click(find.autoApply)
 Check(application:IsAutoApplyEnabled() and modal.autoApply.value and prefs.autoApply==true,"the main switch synchronizes an open modal")
 u:CloseModal();application:SetAutoApply(false)
 Click(find.autoApply)
 Check(application:IsAutoApplyEnabled() and u.activeModal==nil,"valid saved roles enable without opening another dialog")
 Check(a.db.autoApply==nil,"the switch never writes account-wide preferences")
 u:Hide(true)
 f,a,u,g,application,find=Fixture(locale,prefs)
 Check(application:IsAutoApplyEnabled() and find.autoApply.value,"the actual character preference reloads enabled")
 Click(find.autoApply);u:Hide(true)
 f,a,u,g,application,find=Fixture(locale,prefs)
 Check(not application:IsAutoApplyEnabled() and not find.autoApply.value,"an explicit disabled flag also survives reload")
 u:Hide(true)

 -- Pending activation cannot survive cancellation, missing roles or failed opening.
 f,a,u,g,application,find=Fixture(locale,{})
 local dialog=LFGListApplicationDialog
 dialog.available={TANK=false,HEALER=false,DAMAGER=false}
 Click(find.autoApply);modal=application.applicationModal
 Check(not application:IsAutoApplyEnabled() and find.autoApply.value==false,"unconfigured activation remains off on the main page")
 Check(modal.autoApply.value and application.applicationLease.enableOnSave,"the checked activation request stays in the current dialog draft")
 application:ConfirmApplication()
 Check(not application:IsAutoApplyEnabled() and a.charPrefs.autoApply~=true,"invalid roles cannot save activation")
 Click(modal.cancel)
 Check(application.applicationLease==nil and not modal.autoApply.value,"cancel releases and clears the pending checkbox")
 application:OpenApplicationSettings()
 Check(not modal.autoApply.value and not application.applicationLease.enableOnSave,"reopening settings never revives a cancelled activation request")
 u:CloseModal()
 local ready=u.Native.Ready;u.Native.Ready=function() return nil,"Native input unavailable" end
 local ok,err=application:SetAutoApply(true)
 Check(ok==false and err=="Native input unavailable","activation reports native acquisition failure")
 Check(not application:IsAutoApplyEnabled() and a.charPrefs.autoApply~=true and u.activeModal==nil,"a failed settings entry never enables automation")
 u.Native.Ready=ready
 Click(find.autoApply);dialog.available.TANK=true;application:RefreshApplicationRoles();application:SetApplicationRole("TANK")
 Check(modal.submit:IsEnabled(),"a newly available role completes the pending configuration")
 Click(modal.submit)
 Check(application:IsAutoApplyEnabled() and find.autoApply.value and a.charPrefs.autoApply==true,"saving valid roles commits activation")
 Check(a.charPrefs.applicationRoles.TANK==true and a.charPrefs.applicationRoles.HEALER==false,"activation saves only explicit role booleans")
 u:Hide(true)

 -- A saved but currently unavailable role must use the same guarded flow.
 f,a,u,g,application,find=Fixture(locale,{applicationRoles={HEALER=true},rurutiaAutoApply=true})
 Check(not application:IsAutoApplyEnabled(),"an unrelated remote-PR preference is not migrated")
 Click(find.autoApply);modal=application.applicationModal
 Check(application.applicationLease~=nil and not modal.submit:IsEnabled(),"unavailable saved roles cannot directly enable")
 Click(modal.cancel)
 Check(not application:IsAutoApplyEnabled() and a.charPrefs.autoApply~=true,"cancelling invalid saved roles remains disabled")
 u:Hide(true)

 -- A manual application can request activation, but only a successful submission
 -- confirms its selected roles. Failed requests and cancellation keep it off.
 f,a,u,g,application,find=Fixture(locale,{})
 local record={id=42,name="Application test",activityID=2,activity=g.Catalog:GetActivity(2),categoryID=2,numMembers=1,maxNumPlayers=5,age=1}
 g.records[42]=record
 application:OpenApplicationSettings(42);modal=application.applicationModal
 Click(modal.autoApply)
 Check(modal.autoApply.value and not application:IsAutoApplyEnabled(),"a manual dialog stages its first activation")
 local apply=g.Apply;g.Apply=function() return false,"Rejected submission" end
 Click(modal.submit)
 Check(modal.error:GetText()=="Rejected submission" and not application:IsAutoApplyEnabled(),"failed submission cannot commit activation")
 Check(a.charPrefs.autoApply~=true and a:GetSetting("applicationRoles")==false,"failed submission saves neither automation nor role defaults")
 Click(modal.cancel);application:OpenApplicationSettings(42)
 Check(not modal.autoApply.value,"a failed and cancelled request leaves no checkbox draft")
 Click(modal.autoApply);g.Apply=apply;Click(modal.submit)
 Check(application:IsAutoApplyEnabled() and a.charPrefs.autoApply==true and u.activeModal==nil,"successful application commits requested activation")
 Check(LFGListApplicationDialog.submissions==1,"successful confirmation still uses the production application path")
 local savedRoles=a.charPrefs.applicationRoles
 local editedRole=savedRoles.TANK and "DAMAGER" or "TANK"
 application:OpenApplicationSettings(42);modal.roles[editedRole]:Fire("OnClick");Click(modal.submit)
 Check(a.charPrefs.applicationRoles~=savedRoles and a.charPrefs.applicationRoles[editedRole]==true,"a successful explicitly edited application updates automatic roles")
 for _,percent in ipairs({70,100,130}) do
  a:SetSetting("fontScale",percent);application:OpenApplicationSettings();application:LayoutApplication()
  local available=modal.frame:GetWidth()-48-modal.submit:GetWidth()-8-modal.cancel:GetWidth()
  Check(modal.autoApply:GetWidth()+8<=available,"translated checkbox and footer actions do not overlap at "..percent)
  Check(modal.autoApply.label:GetStringHeight()<=modal.autoApply:GetHeight(),"the checkbox label fits its click area at "..percent)
  u:CloseModal()
 end
 u:Hide(true)

 -- An enabled healer preference must accept an explicit DPS correction only
 -- after successful submission, then use it for later applications and reload.
 local corrected={autoApply=true,applicationRoles={TANK=false,HEALER=true,DAMAGER=false}}
 f,a,u,g,application,find=Fixture(locale,corrected)
 dialog=LFGListApplicationDialog;dialog.available={TANK=false,HEALER=true,DAMAGER=true}
 for _,id in ipairs({42,43}) do g.records[id]={id=id,name="Role correction",activityID=2,numMembers=1,maxNumPlayers=5,age=1} end
 local function CorrectDPS()
  application:OpenApplicationSettings(42)
  Check(application.applicationLease.roles.HEALER==true,"saved healer selection is shown before correction")
  application:SetApplicationRole("HEALER");application:SetApplicationRole("DAMAGER")
 end
 local originalRoles=corrected.applicationRoles
 CorrectDPS();apply=g.Apply;g.Apply=function() return false,"Rejected correction" end;Click(application.applicationModal.submit)
 Check(corrected.applicationRoles==originalRoles and a:GetSetting("applicationRoles").HEALER==true,"failed correction does not save roles")
 Click(application.applicationModal.cancel);g.Apply=apply
 CorrectDPS();Click(application.applicationModal.cancel)
 Check(corrected.applicationRoles==originalRoles,"cancelled correction does not save roles")
 CorrectDPS();Click(application.applicationModal.submit)
 Check(dialog.submitted.damage and not dialog.submitted.healer,"successful correction submits DPS to the requested group")
 Check(a:GetSetting("applicationRoles").DAMAGER==true and a:GetSetting("applicationRoles").HEALER==false,"successful correction persists the new automatic role")
 local correctedRoles=corrected.applicationRoles
 Check(application:Apply(43),"the next automatic application succeeds")
 Check(dialog.submitted.damage and not dialog.submitted.healer and corrected.applicationRoles==correctedRoles,"next automatic application uses DPS without another preference write")
 u:Hide(true);f,a,u,g,application,find=Fixture(locale,corrected)
 dialog=LFGListApplicationDialog;dialog.available={TANK=false,HEALER=true,DAMAGER=true}
 application:OpenApplicationSettings()
 Check(application.applicationLease.roles.DAMAGER==true and not application.applicationLease.roles.HEALER,"explicit correction survives a full reload")
 u:CloseModal()

 -- Fixed healer teaching data is private, including edited roles while the
 -- tutorial's auto-apply is enabled and stale modal callbacks after exit.
 for line in io.lines("addon/LycheeGroup_Guide/LycheeGroup_Guide.toc") do
  local file=line:match("^%s*(.-)%s*$");if file~="" and file:sub(1,1)~="#" then dofile("addon/LycheeGroup_Guide/"..file) end
 end
 local guide=a.Guide;Check(guide:Open() and guide:Start(),"guide starts its private player")
 local provider=u:GetGroup();Check(provider.player.role=="HEALER","the real DPS preference is tested against the guide's fixed healer")
 local privateID;for _,id in ipairs(provider.recordIDs) do if not provider.Applications:IsActive(id) then privateID=id;break end end
 application:OpenApplicationSettings();application:SetApplicationRole("HEALER");application:SetAutoApply(true);Click(application.applicationModal.submit)
 Check(provider.prefs.autoApply==true and provider.prefs.applicationRoles.HEALER==true,"guide saves healer automation privately")
 application:OpenApplicationSettings(privateID);application:SetApplicationRole("HEALER");application:SetApplicationRole("DAMAGER");Click(application.applicationModal.submit)
 Check(provider.prefs.applicationRoles.DAMAGER==true and provider.prefs.applicationRoles.HEALER==false,"guide applies the same explicit correction rule to private preferences")
 Check(corrected.applicationRoles==correctedRoles and a:GetSetting("applicationRoles").DAMAGER==true,"teaching confirmation cannot change real DPS preferences")
 guide:Stop("interrupted");Click(application.applicationModal.submit)
 Check(u.preview==nil and application.previewApplication==nil and corrected.applicationRoles==correctedRoles,"guide exit releases the lease before a stale callback can write real preferences")
 application:OpenApplicationSettings();Check(application.applicationLease.roles.DAMAGER==true and not application.applicationLease.roles.HEALER,"leaving the healer tutorial restores the real DPS choice")
 u:Hide(true)

 -- An untouched confirmation must not turn a package role default into a user
 -- override merely because it successfully applies while automation is on.
 f,a,u,g,application,find=Fixture(locale,{autoApply=true})
 dialog=LFGListApplicationDialog;dialog.available={TANK=false,HEALER=true,DAMAGER=true}
 Check(a.Configuration:RegisterPreset("roles",1,{["settings.applicationRoles"]={HEALER=true}},{storage="account",default=true}),"package role default installs")
 g.records[42]={id=42,name="Unedited default",activityID=2,numMembers=1,maxNumPlayers=5,age=1}
 application:OpenApplicationSettings(42);Check(not application.applicationLease.rolesEdited,"preselection alone is not an edit")
 Click(application.applicationModal.submit)
 Check(dialog.submitted.healer and a.charPrefs.uiConfig.user["settings.applicationRoles"]==nil,"successful unedited confirmation leaves the package default unpinned")
 u:Hide(true)

 -- Preview uses its own flag and roles; all real submission paths are trapped.
 f,a,u,g,application,find=Fixture(locale,{autoApply=true,applicationRoles={TANK=true,HEALER=false,DAMAGER=false}})
 local realPrefs=a.charPrefs;local roles=realPrefs.applicationRoles
 C_LFGList.ApplyToGroup=function() error("preview must never apply to a real group") end
 dofile("addon/LycheeGroup/Entrypoints.lua");Check(a:Preview("applications"),"preview opens")
 local provider=u.preview.provider
 Check(not application:IsAutoApplyEnabled() and not find.autoApply.value,"preview does not inherit real auto-apply")
 Click(find.autoApply);modal=application.applicationModal;Click(modal.submit)
 Check(application:IsAutoApplyEnabled() and provider.prefs.autoApply==true,"preview saves activation to its own provider")
 Click(find.autoApply)
 Check(not application:IsAutoApplyEnabled() and provider.prefs.autoApply==false,"preview disable updates only its own flag")
 Check(realPrefs.autoApply==true and realPrefs.applicationRoles==roles,"preview never changes real activation or role preferences")
 u:StopPreview(true)
 Check(application:IsAutoApplyEnabled() and find.autoApply.value,"leaving preview restores the real enabled state")
 u:Hide(true)
end
print("Auto apply: "..checks.." checks passed")
