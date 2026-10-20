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
 if UI.preview then return UI:GetGroup().applicationPrefs end
 Application.applicationPrefs=Application.applicationPrefs or {roles=CopyRoles(A.charPrefs.applicationRoles)}
 return Application.applicationPrefs
end
local function SaveRoles(roles)
 ApplicationPrefs().roles=CopyRoles(roles)
 local saved=UI.preview and UI:GetGroup().prefs or A.charPrefs
 saved.applicationRoles={TANK=roles.TANK==true,HEALER=roles.HEALER==true,DAMAGER=roles.DAMAGER==true}
end
function Application:IsAutoApplyEnabled()
 return ApplicationPrefs().enabled==true
end
local function RefreshApplicationEntry()
 if Application.onPreferencesChanged then Application.onPreferencesChanged() end
end
function Application:SetAutoApply(enabled)
 if enabled then
  local ok,err=self:OpenApplicationSettings(nil,true)
  RefreshApplicationEntry()
  return ok,err
 end
 ApplicationPrefs().enabled=false
 RefreshApplicationEntry()
 return true
end
function Application:BuildApplication()
 if self.applicationModal then return self.applicationModal end
 local modal=UI:OpenModal("application",Say("申请加入","Apply to group"),512,452)
 local content=modal.content
 modal.group=C.Text(content,"",14,T.muted,464,22);modal.group:SetPoint("TOPLEFT");modal.group:SetWordWrap(true);modal.group:SetMaxLines(2)
 modal.roleLabel=C.Text(content,Say("选择申请职责（可多选）","Choose your roles (multiple allowed)"),14,T.muted);C.SetLineHeight(modal.roleLabel,20,true)
 modal.roles={}
 for _,role in ipairs(roleKeys) do
  modal.roles[role]=C.RoleButton(content,role,nil,roleLabels[role],function() Application:SetApplicationRole(role) end)
 end
 modal.noteLabel=C.Text(content,Say("给队长的备注","Note to the leader"),14,T.muted);C.SetLineHeight(modal.noteLabel,20,true)
 modal.note=C.Field(content,464,112,false,"modal")
 modal.error=C.Text(content,"",14,T.warning,464,20);modal.error:SetMaxLines(1)
 modal.cancel=C.Button(modal.frame,L.cancel,nil,function() UI:CloseModal() end);modal.cancel:SetWidth(math.max(72,modal.cancel.label:GetStringWidth()+40));modal.cancel:SetHeight(40)
 modal.submit=C.Button(modal.frame,L.apply,112,function() Application:ConfirmApplication() end);modal.submit:SetPrimary(true);modal.submit:SetHeight(40)
 self.applicationModal=modal
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
 local x=0
 for _,role in ipairs(roleKeys) do
  local button=modal.roles[role];button:SetPoint("TOPLEFT",x,-groupOffset-32);x=x+button:GetWidth()+8
 end
 modal.noteLabel:SetPoint("TOPLEFT",0,-groupOffset-96)
 modal.note:SetPoint("TOPLEFT",0,-groupOffset-128)
 local hasError=modal.error:GetText()~=""
 modal.error:SetShown(hasError);modal.error:SetPoint("TOPLEFT",0,-groupOffset-252);modal.error:SetHeight(hasError and 24 or 0)
 modal.frame:SetHeight(408+groupOffset+(hasError and 28 or 0))
 modal.submit:SetWidth(math.max(96,modal.submit.label:GetStringWidth()+40));modal.submit:SetPoint("BOTTOMRIGHT",-24,24)
 modal.cancel:SetPoint("RIGHT",modal.submit,"LEFT",-8,0)
end
function Application:SetApplicationRole(role)
 local lease=self.previewApplication or self.applicationLease;if not lease or not lease.available[role] then return end
 lease.roles[role]=not lease.roles[role] or nil
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
end
function Application:ReleaseApplication()
 local lease=self.previewApplication or self.applicationLease;if not lease then return end
 local preview=self.previewApplication~=nil
 self.previewApplication,self.applicationLease=nil,nil
 local modal=self.applicationModal
 modal.onClose=nil
 if preview then modal.previewNote.box:ClearFocus();modal.previewNote.box:SetText("");modal.previewNote:Hide()
 elseif lease.description then lease.description:Release() end
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
  if not modal.previewNote then modal.previewNote=C.Edit(modal.note,464,112,true,false,"modal");modal.previewNote:SetAllPoints(modal.note) end
  modal.previewNote.box:SetText(prefs.note or "");modal.previewNote:Show();modal.previewNote.box:SetFocus()
 else
  self.applicationLease=lease
  local dialog=LFGListApplicationDialog;local description=dialog.Description
  lease.dialog=dialog
  local input=C.NativeInput(modal.note,description.EditBox,{container=description,onLost=function() Application:ReleaseApplication() end})
  if self.applicationLease~=lease or not input:IsOwned() then input:Release();self:ReleaseApplication();return false,L.unavailable end
  lease.description=input
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
  if lease.enableOnSave then prefs.enabled=true end
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
 local ok,err
 if UI.preview then ok,err=group:Apply(resultID,submittedRoles,prefs.note or "")
 else ok,err=group:Apply(resultID,submittedRoles) end
 if ok then
  if confirmedRoles and not prefs.enabled then SaveRoles(confirmedRoles);RefreshApplicationEntry() end
  self:ReleaseApplication()
 end
 return ok,err
end
