-- Production auto-apply with native LFG role ownership: lua tests/test_auto_apply.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Fixture(locale,prefs)
 local f=dofile("tests/ui_fixture.lua")(locale,prefs)
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 return f,f.A,f.U,f.G,f.U.Application,f.U.pages.find
end
local function Click(button) button:Fire("OnClick","LeftButton") end
local function Select(app,tank,healer,damage)
 local selected={TANK=tank,HEALER=healer,DAMAGER=damage}
 local lease=app.previewApplication or app.applicationLease
 for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do
  if (lease.roles[role]==true)~=(selected[role]==true) then app:SetApplicationRole(role) end
 end
end
for _,locale in ipairs({"zhCN","enUS"}) do
 -- Only the automation flag persists; existing native roles enable directly.
 local prefs={applicationRoles={HEALER=true},autoApply=true}
 local f,a,u,g,app,find=Fixture(locale,prefs)
 local dialog=LFGListApplicationDialog
 Check(app:IsAutoApplyEnabled() and find.autoApply.value,"saved automation restores")
 app:OpenApplicationSettings();local modal=app.applicationModal
 Check(app.applicationLease.roles.DAMAGER and not app.applicationLease.roles.HEALER,"native DPS beats removed saved healer")
 Check(modal.autoApply.value and modal.autoApply.box:GetChecked(),"modal shows the same automation flag")
 Check(modal.autoApply.box:GetParent()==modal.autoApply and not modal.autoApply.box:IsMouseEnabled(),"one checkbox click target")
 Click(modal.autoApply);Check(not app:IsAutoApplyEnabled() and not find.autoApply.value and prefs.autoApply==false,"modal disable updates flag")
 Click(find.autoApply);Check(app:IsAutoApplyEnabled() and modal.autoApply.value,"main toggle updates modal")
 u:CloseModal();app:SetAutoApply(false);Click(find.autoApply)
 Check(app:IsAutoApplyEnabled() and u.activeModal==nil,"valid native choices enable without a dialog")
 Check(a.db.autoApply==nil and a.charPrefs.applicationRoles==nil,"only the character automation flag is stored")
 u:Hide(true);f,a,u,g,app,find=Fixture(locale,prefs)
 Check(app:IsAutoApplyEnabled(),"automation survives reload")
 Click(find.autoApply);u:Hide(true);f,a,u,g,app,find=Fixture(locale,prefs)
 Check(not app:IsAutoApplyEnabled(),"disabled automation survives reload")
 u:Hide(true)

 -- Missing or unavailable native roles require an explicit choice and save.
 f,a,u,g,app,find=Fixture(locale,{})
 dialog=LFGListApplicationDialog;dialog.available={TANK=false,HEALER=false,DAMAGER=false}
 Click(find.autoApply);modal=app.applicationModal
 Check(not app:IsAutoApplyEnabled() and modal.autoApply.value and app.applicationLease.enableOnSave,"invalid native roles stage activation")
 app:ConfirmApplication();Check(a.charPrefs.autoApply~=true,"invalid roles cannot enable automation")
 Click(modal.cancel);app:OpenApplicationSettings()
 Check(not modal.autoApply.value and not app.applicationLease.enableOnSave,"cancel drops pending activation")
 u:CloseModal()
 local ready=u.Native.Ready;u.Native.Ready=function() return nil,"Native input unavailable" end
 local ok,err=app:SetAutoApply(true)
 Check(ok==false and err=="Native input unavailable" and not app:IsAutoApplyEnabled(),"failed entry keeps automation off")
 u.Native.Ready=ready
 Click(find.autoApply);dialog.available.TANK=true;app:RefreshApplicationRoles();app:SetApplicationRole("TANK")
 local _,tank,healer,damage=GetLFGRoles()
 Check(tank and not healer and not damage and modal.submit:IsEnabled(),"role click immediately updates native selection")
 Click(modal.submit);Check(app:IsAutoApplyEnabled() and a.charPrefs.autoApply==true,"save commits pending activation")
 Check(a.charPrefs.applicationRoles==nil,"activation never stores roles")
 u:Hide(true)
 f,a,u,g,app,find=Fixture(locale,{})
 dialog=LFGListApplicationDialog;SetLFGRoles(false,false,true,false)
 Click(find.autoApply);modal=app.applicationModal
 Check(app.applicationLease and not modal.submit:IsEnabled(),"unavailable native healer does not enable automation")
 Click(modal.cancel);Check(not app:IsAutoApplyEnabled(),"cancel remains disabled")
 u:Hide(true)

 -- Pending activation waits for successful submission; native role edits do not.
 f,a,u,g,app,find=Fixture(locale,{})
 dialog=LFGListApplicationDialog
 g.records[42]={id=42,name="Application test",activityID=2,numMembers=1,maxNumPlayers=5,age=1}
 SetLFGRoles(false,false,false,false);app:OpenApplicationSettings(42);modal=app.applicationModal
 Click(modal.autoApply);Select(app,false,false,true)
 Check(not app:IsAutoApplyEnabled() and modal.autoApply.value,"first activation remains pending")
 local apply=g.Apply;g.Apply=function() return false,"Rejected submission" end
 Click(modal.submit)
 Check(modal.error:GetText()=="Rejected submission" and not app:IsAutoApplyEnabled(),"failed application cannot commit pending activation")
 local _,_,_,dps=GetLFGRoles();Check(dps and a.charPrefs.applicationRoles==nil,"failed submission retains the native edit without DB roles")
 Click(modal.cancel);SetLFGRoles(false,false,false,false);app:OpenApplicationSettings(42)
 Click(modal.autoApply);Select(app,false,false,true);g.Apply=apply;Click(modal.submit)
 Check(app:IsAutoApplyEnabled() and a.charPrefs.autoApply==true and u.activeModal==nil,"successful application commits pending activation")
 Check(dialog.submissions==1 and dialog.submitted.damage,"actual native submission receives DPS")
 for _,percent in ipairs({70,100,130}) do
  a:SetSetting("fontScale",percent);app:OpenApplicationSettings();app:LayoutApplication()
  local available=modal.frame:GetWidth()-48-modal.submit:GetWidth()-8-modal.cancel:GetWidth()
  Check(modal.autoApply:GetWidth()+8<=available,"footer fits at "..percent)
  Check(modal.autoApply.label:GetStringHeight()<=modal.autoApply:GetHeight(),"checkbox label fits at "..percent)
  u:CloseModal()
 end
 u:Hide(true)

 -- Live native edits drive each application, including multiple roles.
 f,a,u,g,app,find=Fixture(locale,{autoApply=true,applicationRoles={HEALER=true}})
 dialog=LFGListApplicationDialog;dialog.available={TANK=true,HEALER=true,DAMAGER=true}
 for _,id in ipairs({42,43,44}) do g.records[id]={id=id,name="Role correction",activityID=2,numMembers=1,maxNumPlayers=5,age=1} end
 SetLFGRoles(false,false,true,false);app:OpenApplicationSettings(42);modal=app.applicationModal
 Select(app,false,false,true)
 apply=g.Apply;g.Apply=function() return false,"Rejected correction" end;Click(modal.submit)
 local _,_,heal,dps=GetLFGRoles();Check(not heal and dps,"a failed application does not roll back a role click")
 Click(modal.cancel);g.Apply=apply;app:OpenApplicationSettings(42)
 Check(app.applicationLease.roles.DAMAGER and not app.applicationLease.roles.HEALER,"cancelled edit remains selected natively")
 Click(modal.submit);Check(dialog.submitted.damage and not dialog.submitted.healer,"manual application uses current DPS")
 SetLFGRoles(false,true,true,false);Check(app:Apply(43),"next automatic application succeeds")
 Check(dialog.submitted.tank and dialog.submitted.healer and not dialog.submitted.damage,"automatic application reads the new native multi-selection")
 SetLFGRoles(false,false,false,false);app:Apply(44)
 Check(app.applicationLease and not app.applicationModal.submit:IsEnabled() and dialog.submissions==2,"empty roles require manual choice")
 u:CloseModal()
 SetLFGRoles(false,false,false,true)

 -- Guide uses its private roles, never writing the real native selection.
 for line in io.lines("addon/LycheeGroup_Guide/LycheeGroup_Guide.toc") do
  local file=line:match("^%s*(.-)%s*$");if file~="" and file:sub(1,1)~="#" then dofile("addon/LycheeGroup_Guide/"..file) end
 end
 local guide=a.Guide;Check(guide:Open() and guide:Start(),"guide starts")
 local provider=u:GetGroup();Check(provider.player.role=="HEALER","guide keeps its own healer")
 local setNative=SetLFGRoles;SetLFGRoles=function() error("teaching must not write native roles") end
 app:OpenApplicationSettings();Select(app,false,true,true);app:SetAutoApply(true);Click(app.applicationModal.submit)
 Check(provider.prefs.autoApply and provider.applicationPrefs.roles.HEALER and provider.applicationPrefs.roles.DAMAGER,"guide supports private multi-selection")
 Check(provider.prefs.applicationRoles==nil and a.charPrefs.applicationRoles==nil,"no role preference is stored")
 guide:Stop("interrupted");Click(app.applicationModal.submit);SetLFGRoles=setNative
 local _,_,heal,dps=GetLFGRoles();Check(not heal and dps,"guide and late callbacks preserve real native choices")
 app:OpenApplicationSettings();Check(app.applicationLease.roles.DAMAGER and not app.applicationLease.roles.HEALER,"real choices return after guide")
 u:CloseModal()

 -- General preview also owns a private session and cannot submit real requests.
 C_LFGList.ApplyToGroup=function() error("preview must never apply to a real group") end
 dofile("addon/LycheeGroup/Entrypoints.lua");Check(a:Preview("applications"),"preview opens")
 provider=u.preview.provider;SetLFGRoles=function() error("preview must not write native roles") end
 Check(not app:IsAutoApplyEnabled() and not find.autoApply.value,"preview does not inherit automation")
 Click(find.autoApply);modal=app.applicationModal;Click(modal.submit)
 Check(app:IsAutoApplyEnabled() and provider.prefs.autoApply,"preview enables its own flag")
 Click(find.autoApply);Check(not app:IsAutoApplyEnabled(),"preview flag can be disabled")
 u:StopPreview(true);SetLFGRoles=setNative
 Check(app:IsAutoApplyEnabled() and a.charPrefs.applicationRoles==nil,"real automation returns without role persistence")
 u:Hide(true)
end
print("Auto apply: "..checks.." checks passed")
