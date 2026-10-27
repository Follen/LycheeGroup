-- Application preferences, role selection and confirmation belong to this UI flow.
-- Real notes remain in the engine's registered description control.
local A=_G.LycheeGroup
local UI=A.UI
local Application={};UI.Application=Application
local T,L,C=UI.Theme,UI.L,UI.C
local zh=A:GetLocale()=="zhCN"
local function Say(cn,en) return zh and cn or en end

function Application:ClearFocus()
 if self.applicationLease then self.applicationLease.dialog.Description.EditBox:ClearFocus() end
 if self.previewApplication then self.applicationModal.previewNote.box:ClearFocus() end
end

local roleKeys={"TANK","HEALER","DAMAGER"}
local roleLabels={TANK=L.tank,HEALER=L.healer,DAMAGER=L.damage}
local function CopyRoles(source)
 if not source then return end
 local roles={};for _,role in ipairs(roleKeys) do if source[role]==true then roles[role]=true end end
 return roles
end
local function ApplicationPrefs()
 if UI.preview then
  local group=UI:GetGroup();local prefs=group.applicationPrefs
  if prefs.enabled==nil then prefs.enabled=group.prefs.autoApply==true end
  return prefs
 end
 Application.applicationPrefs=Application.applicationPrefs or {roles=CopyRoles(A:GetSetting("applicationRoles")),enabled=A:GetSetting("autoApply")==true}
 return Application.applicationPrefs
end
local function SaveEnabled(enabled)
 ApplicationPrefs().enabled=enabled==true
 if UI.preview then UI:GetGroup().prefs.autoApply=enabled==true
 else A:SetSetting("autoApply",enabled==true) end
end
local function SaveRoles(roles)
 ApplicationPrefs().roles=CopyRoles(roles)
 local saved={TANK=roles.TANK==true,HEALER=roles.HEALER==true,DAMAGER=roles.DAMAGER==true}
 if UI.preview then UI:GetGroup().prefs.applicationRoles=saved
 else A:SetSetting("applicationRoles",saved) end
end
function Application:IsAutoApplyEnabled()
 return ApplicationPrefs().enabled==true
end
local function RefreshApplicationEntry()
 local modal=Application.applicationModal
 if modal then
  local lease=Application.previewApplication or Application.applicationLease
  modal.autoApply:SetValue(Application:IsAutoApplyEnabled() or lease and lease.enableOnSave==true)
 end
 if Application.onPreferencesChanged then Application.onPreferencesChanged() end
end
function Application:OnPreferencesChanged(rolesChanged)
 self.applicationPrefs=nil
 if UI.preview then return end
 local lease=self.applicationLease
 if rolesChanged and lease and not lease.rolesEdited then
  lease.roles=CopyRoles(ApplicationPrefs().roles) or {};lease.initialized=nil
  self:RefreshApplicationRoles()
 end
 RefreshApplicationEntry()
end
local function ValidRoles(roles)
 if not roles or not next(roles) then return false end
 local tank,healer,damage=C_LFGList.GetAvailableRoles()
 return not (roles.TANK and not tank or roles.HEALER and not healer or roles.DAMAGER and not damage)
end
function Application:SetAutoApply(enabled)
 local lease=self.previewApplication or self.applicationLease
 if enabled then
  if ValidRoles(ApplicationPrefs().roles) then
   SaveEnabled(true);if lease then lease.enableOnSave=nil end
  elseif lease then lease.enableOnSave=true
  else
   local ok,err=self:OpenApplicationSettings(nil,true)
   RefreshApplicationEntry();return ok,err
  end
 else
  if lease then lease.enableOnSave=nil end
  SaveEnabled(false)
 end
 RefreshApplicationEntry()
 return true
end
function Application:BuildApplication()
 if self.applicationModal then return self.applicationModal end
 local modal=UI:OpenModal("application",Say("申请加入","Apply to group"),512,452)
 local content=modal.content
 modal.group=C.Text(content,"",14,"muted",T.applicationModalGroupWidth,22);modal.group:SetWidth(T.applicationModalGroupWidth);modal.group:SetPoint("TOPLEFT");modal.group:SetWordWrap(true);modal.group:SetMaxLines(2)
 modal.roleLabel=C.Text(content,Say("选择申请职责（可多选）","Choose your roles (multiple allowed)"),14,"muted");C.SetLineHeight(modal.roleLabel,20,true)
 modal.roles={}
 for _,role in ipairs(roleKeys) do
  modal.roles[role]=UI:CreateRoleButton(content,role,nil,roleLabels[role],function() Application:SetApplicationRole(role) end)
  modal.roles[role]:SetSurfaceColors(nil)
  modal.roles[role]:SetStyle({radius="compactRadius",textColor="muted",hoverTextColor="text",selectedTextColor="onSecondaryContainer"})
 end
 modal.noteLabel=C.Text(content,Say("给队长的备注","Note to the leader"),14,"muted");C.SetLineHeight(modal.noteLabel,20,true)
 modal.note=C.Field(content,T.applicationModalNoteWidth,T.applicationModalNoteHeight,false,"modal");C.Box(modal.note,{width="applicationModalNoteWidth",height="applicationModalNoteHeight"})
 modal.error=C.Text(content,"",14,"warning",T.applicationModalErrorWidth,20);modal.error:SetWidth(T.applicationModalErrorWidth);modal.error:SetMaxLines(1)
 modal.cancel=C.Button(modal.frame,L.cancel,nil,function() UI:CloseModal() end);modal.cancel:SetHeight(T.applicationModalCancelHeight)
 modal.submit=C.Button(modal.frame,L.apply,nil,function() Application:ConfirmApplication() end);modal.submit:SetPrimary(true);modal.submit:SetHeight(T.applicationModalSubmitHeight)
 modal.autoApply=C.Button(modal.frame,Say("自动申请","Auto apply"),nil,function()
  local lease=Application.previewApplication or Application.applicationLease
  local requested=Application:IsAutoApplyEnabled() or lease and lease.enableOnSave==true
  local ok,err=Application:SetAutoApply(not requested)
  if not ok then UI:SetText(modal.error,err or L.failed);Application:LayoutApplication() end
 end,{height=40,variant="text"});
 modal.autoApply.label:ClearAllPoints();C.SetPoint(modal.autoApply.label,"LEFT",modal.autoApply.label:GetParent(),"LEFT","applicationModalAutoApplyLabelLeftX",0)
 modal.autoApply.box=C.Checkbox(modal.autoApply,nil,{size=20,boxSize=18,radius=3})
 local autoApplyBox=modal.autoApply.box
 C.Element(autoApplyBox,"application.autoApplyBox",{scope="application",slots={root=autoApplyBox,surface=autoApplyBox.fill,mark=autoApplyBox.mark}})
 C.SetPoint(modal.autoApply.box,"LEFT",modal.autoApply.box:GetParent(),"LEFT","applicationModalAutoApplyBoxLeftX",0);modal.autoApply.box:EnableMouse(false);modal.autoApply.box:EnableMouseMotion(false)
 function modal.autoApply:SetValue(value) self.value=value==true;self.box:SetValue(self.value) end
 modal.autoApply:SetValue(self:IsAutoApplyEnabled())
 modal.roleItems={};for _,role in ipairs(roleKeys) do modal.roleItems[#modal.roleItems+1]={frame=modal.roles[role]} end
 modal.roleOptions={width="content",height=40,gap=8};modal.roleLayout=C.Row(content,modal.roleItems,modal.roleOptions)
 modal.actionItems={{frame=modal.cancel},{frame=modal.submit}}
 modal.actionOptions={anchor="BOTTOMRIGHT",width="content",height=40,align="center"}
 modal.actionLayout=C.Row(modal.frame,modal.actionItems,modal.actionOptions)
 self.applicationModal=modal
 self:RegisterBuildApplicationElements()
 return modal
end
function Application:LayoutApplication()
 local modal=self.applicationModal
 local hasGroup=modal.group:GetText()~=""
 local groupHeight=hasGroup and modal.group:GetStringHeight() or 0
 local groupOffset=hasGroup and groupHeight+20 or 0
 modal.group:SetShown(hasGroup)
 modal.group:SetHeight(groupHeight)
 modal.roleLabel:SetPoint("TOPLEFT",0,-groupOffset)
 for _,item in ipairs(modal.roleItems) do item.width=C.MeasureTextWidth(item.frame.label)+60 end
 modal.roleOptions.y=-groupOffset-32;modal.roleLayout:Layout()
 modal.noteLabel:SetPoint("TOPLEFT",0,-groupOffset-96)
 modal.note:SetPoint("TOPLEFT",0,-groupOffset-128)
 local hasError=modal.error:GetText()~=""
 modal.error:SetShown(hasError);modal.error:SetPoint("TOPLEFT",0,-groupOffset-252);modal.error:SetHeight(hasError and 24 or 0)
 modal.frame:SetHeight(408+groupOffset+(hasError and 28 or 0))
 modal.submit:SetWidth(math.max(96,modal.submit.label:GetStringWidth()+40));C.SetPoint(modal.submit,"BOTTOMRIGHT",modal.submit:GetParent(),"BOTTOMRIGHT","applicationModalSubmitBottomrightX","applicationModalSubmitBottomrightY")
 modal.cancel:SetWidth(math.max(72,C.MeasureTextWidth(modal.cancel.label)+40))
 modal.actionOptions.x=T.applicationModalSubmitBottomrightX;modal.actionOptions.y=T.applicationModalSubmitBottomrightY;modal.actionOptions.gap=-T.applicationModalCancelRightX
 modal.actionOptions.height=math.max(modal.cancel:GetHeight(),modal.submit:GetHeight());modal.actionLayout:Layout()
 modal.autoApply:SetWidth(modal.autoApply.label:GetStringWidth()+40);C.SetPoint(modal.autoApply,"BOTTOMLEFT",modal.autoApply:GetParent(),"BOTTOMLEFT","applicationModalAutoApplyBottomleftX","applicationModalAutoApplyBottomleftY")
UI:ApplyElementScope("application")
 end
function Application:SetApplicationRole(role)
 local lease=self.previewApplication or self.applicationLease;if not lease or not lease.available[role] then return end
 lease.roles[role]=not lease.roles[role] or nil
 lease.rolesEdited=true
 self:RefreshApplicationRoles()
end
function Application:RefreshApplicationRoles()
 local lease=self.previewApplication or self.applicationLease;if not lease then return end
 local tank,healer,damage=C_LFGList.GetAvailableRoles()
 lease.available.TANK,lease.available.HEALER,lease.available.DAMAGER=tank,healer,damage
 if not lease.initialized then
  lease.initialized=true
  if not ApplicationPrefs().roles then
   local specRole
   if GetSpecialization and GetSpecializationRole then
    local spec=GetSpecialization();specRole=spec and GetSpecializationRole(spec)
   end
   if specRole and lease.available[specRole] then lease.roles[specRole]=true
   else
    local _,a,b,c=GetLFGRoles()
    lease.roles.TANK=tank and a or nil;lease.roles.HEALER=healer and b or nil;lease.roles.DAMAGER=damage and c or nil
    if not next(lease.roles) then
     local role=tank and "TANK" or healer and "HEALER" or damage and "DAMAGER"
     if role then lease.roles[role]=true end
    end
   end
  end
 end
 local selected=false
 for _,role in ipairs(roleKeys) do
  if not lease.available[role] then lease.roles[role]=nil end
  if lease.roles[role] then selected=true end
  self.applicationModal.roles[role]:SetAvailable(lease.available[role]==true)
  self.applicationModal.roles[role]:SetActive(lease.roles[role]==true)
 end
 self.applicationModal.submit:SetAvailable(selected)
 UI:SetText(self.applicationModal.error,selected and "" or L.applicationRoleUnavailable)
 self:LayoutApplication()
UI:ApplyElementScope("application")
 end
function Application:ReleaseApplication()
 local lease=self.previewApplication or self.applicationLease;if not lease then return end
 local preview=self.previewApplication~=nil
 self.previewApplication,self.applicationLease=nil,nil
 local modal=self.applicationModal
 RefreshApplicationEntry()
 modal.onClose=nil
 if preview then modal.previewNote.box:ClearFocus();modal.previewNote.box:SetText("");modal.previewNote:Hide()
 elseif lease.description then C.ReleaseElement(lease.description.box);lease.description:Release() end
 if modal.frame:IsShown() then modal:Close() end
end
function Application:OpenApplicationSettings(resultID,enableOnSave)
 if not UI.preview then local entry,err=UI.Native:Ready();if not entry then return false,err end end
 self:ReleaseApplication()
 local title=resultID and Say("申请加入","Apply to group") or L.applicationSettings
 local modal=self.applicationModal;if modal then UI:OpenModal("application",title,512,452) else modal=self:BuildApplication();modal:SetTitle(title) end
 local prefs=ApplicationPrefs();local lease={id=resultID,available={},roles={},enableOnSave=enableOnSave}
 for _,role in ipairs(roleKeys) do if prefs.roles and prefs.roles[role] then lease.roles[role]=true end end
 if UI.preview then
  self.previewApplication=lease
  if not modal.previewNote then modal.previewNote=C.Edit(modal.note,T.applicationModalPreviewNoteWidth,T.applicationModalPreviewNoteHeight,true,false,"modal");C.Box(modal.previewNote,{width="applicationModalPreviewNoteWidth",height="applicationModalPreviewNoteHeight"});modal.previewNote:SetAllPoints(modal.note) end
  modal.previewNote.box:SetText(prefs.note or "");modal.previewNote:Show();modal.previewNote.box:SetFocus()
 else
  self.applicationLease=lease
  local dialog=LFGListApplicationDialog;local description=dialog.Description
  lease.dialog=dialog
  local input=C.NativeInput(modal.note,description.EditBox,{container=description,onLost=function(control) C.ReleaseElement(control.box);Application:ReleaseApplication() end})
  if self.applicationLease~=lease or not input:IsOwned() then input:Release();self:ReleaseApplication();return false,L.unavailable end
  C.Element(description.EditBox,"native.application.note",{scope="native",owner=input});lease.description=input
  lease.description:Bind(dialog,"OnShow",function(frame,previous,...) if previous then previous(frame,...) end;Application:ReleaseApplication() end)
  lease.description:Bind(dialog,"OnEvent",function(frame,previous,event,...) if previous then previous(frame,event,...) end;if event=="LFG_ROLE_UPDATE" then Application:RefreshApplicationRoles() end end)
  if modal.previewNote then modal.previewNote:Hide() end
  description.EditBox:SetFocus();lease.description:RefreshStyle()
 end
 if (self.previewApplication or self.applicationLease)~=lease then return false,L.unavailable end
 modal.onClose=function() Application:ReleaseApplication() end
 local result=resultID and UI:GetGroup():GetResult(resultID)
 UI:SetText(modal.group,result and result.name or "")
 UI:SetText(modal.submit.label,resultID and L.apply or L.save)
 self:RefreshApplicationRoles()
 RefreshApplicationEntry()
 self:RegisterBuildApplicationElements()
 return true
end
function Application:ConfirmApplication()
 local lease=self.previewApplication or self.applicationLease;if not lease then return end
 if lease.description and not lease.description:IsOwned() then self:ReleaseApplication();return end
 self:RefreshApplicationRoles()
 if not next(lease.roles) then return end
 local prefs=ApplicationPrefs()
 if self.previewApplication then prefs.note=self.applicationModal.previewNote.box:GetText() end
 if lease.id then
  local ok,err=self:Apply(lease.id,true,lease.roles)
  if not ok and self.applicationModal.frame:IsShown() then UI:SetText(self.applicationModal.error,err or L.failed);self:LayoutApplication() end
 else
  SaveRoles(lease.roles)
  if lease.enableOnSave then SaveEnabled(true) end
  RefreshApplicationEntry();self:ReleaseApplication()
 end
end
function Application:Apply(resultID,manual,confirmedRoles)
 local group=UI:GetGroup()
 if group:GetListing() then return false,group.L.recruiting end
 if group.Applications:IsActive(resultID) then return false,group.L.alreadyApplied end
 if group.Applications:GetActiveCount()>=5 then self:ReleaseApplication();UI:ShowApplicationLimit();return false,group.L.applicationLimit end
 if not UI.preview then
  local entry,err=UI.Native:Ready();if not entry then return false,err end
  local result=C_LFGList.GetSearchResultInfo(resultID);if not result or result.isDelisted then return false,L.unavailable end
 end
 local prefs=ApplicationPrefs();local tank,healer,damage=C_LFGList.GetAvailableRoles()
 local roles=confirmedRoles or prefs.roles
 if not confirmedRoles and (manual or not prefs.enabled or not roles) then return self:OpenApplicationSettings(resultID) end
 if not next(roles) or roles.TANK and not tank or roles.HEALER and not healer or roles.DAMAGER and not damage then return self:OpenApplicationSettings(resultID) end
 local submittedRoles={tank=roles.TANK==true,healer=roles.HEALER==true,damage=roles.DAMAGER==true}
 local lease=self.previewApplication or self.applicationLease
 local ok,err
 if UI.preview then ok,err=group:Apply(resultID,submittedRoles,prefs.note or "")
 else ok,err=group:Apply(resultID,submittedRoles) end
 if ok then
  if confirmedRoles and (not prefs.enabled or lease and lease.rolesEdited) then
   SaveRoles(confirmedRoles)
   if lease and lease.enableOnSave then SaveEnabled(true) end
   RefreshApplicationEntry()
  end
  self:ReleaseApplication()
 end
 return ok,err
end




function Application:RegisterBuildApplicationElements()
local modal=self.applicationModal;if not modal then return end
 UI:ElementFields(modal,"application","group roleLabel noteLabel note error cancel submit autoApply previewNote","application")
 for role,button in pairs(modal.roles) do UI:Element(button,"application.role","application",button,"application.role",role) end
end
