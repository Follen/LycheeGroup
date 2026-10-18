-- Reuse the engine's registered text objects. Protected text is never SetText'd,
-- copied through addon strings, or replaced with an ordinary EditBox.
-- Explicit local preview uses separate ordinary edits and never leases these objects.
local A = _G.LycheeGroup
local UI, Native = A.UI, {}
UI.Native = Native
local T, L, C = UI.Theme, UI.L, UI.C
local zh=GetLocale()=="zhCN"
local function Say(cn,en) return zh and cn or en end

function Native:Ready()
	if not LFGListFrame then
		local ok, reason = C_AddOns.LoadAddOn("Blizzard_GroupFinder")
		if not ok then return nil, reason or L.unavailable end
	end
	return LFGListFrame.EntryCreation
end

function Native:AcquireSearch(owner,shell)
 local lease=self.searchLease
 if lease and lease.owner==owner and lease:IsOwned() then return true end
 self:ReleaseSearch()
 local entry,err=self:Ready()
 if not entry then return false,err end
 local panel=LFGListFrame.SearchPanel
 local box=panel and panel.SearchBox
 if not box then return false,L.unavailable end
 local previousChanged=box:GetScript("OnTextChanged")
 local hide={}
 for _,region in ipairs({box.Instructions,box.clearButton,panel.AutoCompleteFrame}) do hide[#hide+1]=region end
 lease=C.NativeInput(shell,box,{
  padding={52,4,238,4},textInsets={0,0,0,0},hide=hide,
  onLost=function(control)
   if Native.searchLease==control then
    Native.searchLease=nil;Native.searchDirty=true;owner:OnSearchInputLost()
   end
  end,
  scripts={
   OnTextChanged=function(input,userInput)
    lease.revision=lease.revision+1
    -- Activity tokens belong to this browser's selected category. Other group
    -- browsers may write their previous activity after an availability event.
    if not userInput and input:GetText()~="" then C_LFGList.ClearSearchTextFields();return end
    owner:OnSearchTextChanged(input,userInput==true)
   end,
   OnEnterPressed=function(input) input:ClearFocus();owner:DoSearch() end,
   OnEscapePressed=function(input) input:ClearFocus() end,
   OnTabPressed=function(input) input:ClearFocus() end,
   OnArrowPressed=false,OnShow=false,OnHide=false,
   OnEditFocusGained=false,OnEditFocusLost=false,OnEnter=false,OnLeave=false,
  },
 })
 lease.owner=owner;lease.revision=0;lease.previousChanged=previousChanged
 self.searchLease=lease
 if not self.searchInitialized or self.searchDirty then self.searchInitialized=true;self.searchDirty=nil;C_LFGList.ClearSearchTextFields() end
 owner:OnSearchTextChanged(box)
 return true
end
function Native:ClearSearch()
 if not self.searchLease then return end
 C_LFGList.ClearSearchTextFields();self.searchLease.box:ClearFocus()
end
function Native:ReleaseSearch()
 local lease=self.searchLease;if not lease then return end
 self.searchLease=nil
 local owned=lease:Release()
 if not owned then self.searchDirty=true;lease.owner:OnSearchInputLost()
 elseif lease.previousChanged then lease.previousChanged(lease.box,false) end
end
function Native:UseLeaderSearch(owner)
 self:ReleaseSearch()
 C_LFGList.ClearSearchTextFields()
 if owner and owner.search and owner.previewSearchBox then
  owner.search.box=owner.previewSearchBox
  owner.previewSearchBox:Show()
 end
 return true
end

function Native:AcquireCreation(owner,title,description)
 if UI.preview then return self:AcquirePreviewCreation(owner,title,description) end
 if self.owner==owner and self.titleInput:IsOwned() and self.descriptionInput:IsOwned() then return true end
 self:ReleaseCreation()
 local entry,err=self:Ready();if not entry then return false,err end
 self.owner,self.entry=owner,entry
 local name,desc=entry.Name,entry.Description
 local descriptionChanged=desc.EditBox:GetScript("OnTextChanged")
 name.selectedCategory,name.selectedActivity=entry.selectedCategory,entry.selectedActivity
 desc.selectedCategory,desc.selectedActivity=entry.selectedCategory,entry.selectedActivity
 local function Lost()
  Native:ReleaseCreation()
  owner.publish:SetAvailable(false)
 end
 self.titleInput=C.NativeInput(title,name,{
  onLost=Lost,
  scripts={
   -- The stock callback assumes EntryCreation is the field's direct parent.
   OnTextChanged=function(box) InputBoxInstructions_OnTextChanged(box);owner:ValidateForm() end,
   OnTabPressed=function() desc.EditBox:SetFocus() end,
  },
 })
 self.descriptionInput=C.NativeInput(description,desc.EditBox,{
  container=desc,onLost=Lost,
  scripts={
   OnTabPressed=function() name:SetFocus() end,
   OnTextChanged=function(box,userInput) if descriptionChanged then descriptionChanged(box,userInput) end;owner:ValidateForm() end,
  },
 })
 return true
end

function Native:SelectActivity(activityID)
 if self.previewCreation then self.entry.selectedActivity=activityID;return end
	local entry = self.entry
	if not entry then return end
	local activity = activityID and C_LFGList.GetActivityInfoTable(activityID)
	entry.Name.selectedActivity, entry.Description.selectedActivity = activityID, activityID
	entry.Name.selectedCategory, entry.Description.selectedCategory = activity and activity.categoryID, activity and activity.categoryID
	if activity then
		-- Select without the native layout pass: these registered fields are leased
		-- into our form. The engine still owns and writes protected title text.
		entry.selectedActivity,entry.selectedCategory,entry.selectedGroup=activityID,activity.categoryID,activity.groupFinderActivityGroupID
		entry.MythicPlusRating:SetShown(activity.isMythicPlusActivity)
		entry.PVPRating:SetShown(activity.isRatedPvpActivity)
		entry.ItemLevel:SetShown(not activity.isPvpActivity);entry.PvpItemLevel:SetShown(activity.isPvpActivity)
	else
		entry.selectedActivity = nil
	end
end

function Native:GetCreationItemLevelLimit(activityID)
 local activity=UI:GetGroup().Catalog:GetActivity(activityID)
 if not activity then return end
 local average,_,pvp=GetAverageItemLevel()
 return math.floor(activity.isPvpActivity and pvp or average),activity.isPvpActivity==true
end

function Native:ValidateCreation(data)
 if self.previewCreation then
  if not data.activityID then return false,L.noActivity end
  local activity=UI:GetGroup().Catalog:GetActivity(data.activityID)
  local category=C_LFGList.GetLfgCategoryInfo(activity.categoryID)
  if category.showPlaystyleDropdown and (not data.generalPlaystyle or data.generalPlaystyle==Enum.LFGEntryGeneralPlaystyle.None) then return false,L.choosePlaystyle end
  local valid=self.entry.Name:GetText():match("%S")~=nil
  return valid,not valid and L.title or nil
 end
	local entry = self.entry
	if not entry or not data.activityID then return false, L.noActivity end
 if not self.titleInput:IsOwned() or not self.descriptionInput:IsOwned() then self:ReleaseCreation();return false,L.unavailable end
	local activity=C_LFGList.GetActivityInfoTable(data.activityID)
	local category=C_LFGList.GetLfgCategoryInfo(activity.categoryID)
	if category.showPlaystyleDropdown and (not data.generalPlaystyle or data.generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None) then return false, L.choosePlaystyle end
	entry.generalPlaystyle = data.generalPlaystyle
	local levelField=activity.isPvpActivity and entry.PvpItemLevel.EditBox or entry.ItemLevel.EditBox
	local inactiveLevel=activity.isPvpActivity and entry.ItemLevel.EditBox or entry.PvpItemLevel.EditBox
	local ilvl, score,pvp = tostring(data.requiredItemLevel or 0), tostring(activity.isMythicPlusActivity and (data.requiredDungeonScore or 0) or 0),tostring(activity.isRatedPvpActivity and (data.requiredPvpRating or 0) or 0)
	if levelField:GetText() ~= ilvl then levelField:SetText(ilvl) end
	if inactiveLevel:GetText()~="0" then inactiveLevel:SetText("0") end
	if entry.MythicPlusRating.EditBox:GetText() ~= score then entry.MythicPlusRating.EditBox:SetText(score) end
	if entry.PVPRating.EditBox:GetText() ~= pvp then entry.PVPRating.EditBox:SetText(pvp) end
	-- The stock validator tests the legacy None value even for categories whose
	-- catalog explicitly hides playstyle. A missing selection skips that test.
	if not category.showPlaystyleDropdown then entry.generalPlaystyle=nil end
	-- Refresh requirement warnings even when the text is unchanged: the player's
	-- item level or rating and the selected PvP activity may have changed.
	LFGListRequirement_Validate(entry.ItemLevel, entry.ItemLevel.EditBox:GetText())
	LFGListRequirement_Validate(entry.PvpItemLevel, entry.PvpItemLevel.EditBox:GetText())
	LFGListRequirement_Validate(entry.MythicPlusRating, entry.MythicPlusRating.EditBox:GetText())
	LFGListRequirement_Validate(entry.PVPRating, entry.PVPRating.EditBox:GetText())
	entry.generalPlaystyle=data.generalPlaystyle
	local errorText = entry.ListGroupButton.errorText
	if errorText and errorText == CANNOT_DO_THIS_WITH_LFGLIST_APP then errorText = A.GroupLocale.publishApplications end
	return entry.ListGroupButton:IsEnabled(), errorText
end

function Native:ClearFocus()
	if self.entry then self.entry.Name:ClearFocus(); self.entry.Description.EditBox:ClearFocus() end
 if self.searchLease then self.searchLease.box:ClearFocus() end
 if self.applicationLease then self.applicationLease.dialog.Description.EditBox:ClearFocus() end
 if self.previewApplication then self.applicationModal.previewNote.box:ClearFocus() end
end

function Native:ReleaseCreation()
 if self.previewCreation then
  self:ClearFocus();self.previewCreation=nil
  local owner=self.owner;local preparing=owner.preparing;owner.preparing=true
  owner.previewTitle.box:SetText("");owner.previewDescription.box:SetText("")
  owner.previewTitle:Hide();owner.previewDescription:Hide();owner.preparing=preparing
  self.owner,self.entry=nil,nil;return
 end
 if not self.owner then return end
 local entry=self.entry
 local title,description=self.titleInput,self.descriptionInput
 self.owner,self.entry,self.titleInput,self.descriptionInput=nil,nil,nil,nil
 if title:IsOwned() then entry.Name.selectedActivity,entry.Name.selectedCategory=nil,nil end
 if description:IsOwned() then entry.Description.selectedActivity,entry.Description.selectedCategory=nil,nil end
 title:Release();description:Release()
end

local roleKeys={"TANK","HEALER","DAMAGER"}
local roleLabels={TANK=L.tank,HEALER=L.healer,DAMAGER=L.damage}
local function ApplicationPrefs()
 if UI.preview then return UI:GetGroup().applicationPrefs end
 Native.applicationPrefs=Native.applicationPrefs or {}
 return Native.applicationPrefs
end
function Native:GetApplicationRoles()
 return ApplicationPrefs().roles
end
function Native:IsAutoApplyEnabled()
 return ApplicationPrefs().enabled==true
end
local function RefreshApplicationEntry()
 local page=UI.pages.find
 if page.applicationSettings then page:UpdateApplicationSettings() end
end
function Native:SetAutoApply(enabled)
 if enabled then
  local ok,err=self:OpenApplicationSettings(nil,true)
  RefreshApplicationEntry()
  return ok,err
 end
 ApplicationPrefs().enabled=false
 RefreshApplicationEntry()
 return true
end
function Native:BuildApplication()
 if self.applicationModal then return self.applicationModal end
 local modal=UI:OpenModal("application",Say("申请加入","Apply to group"),456,434)
 local content=modal.content
 modal.group=C.Text(content,"",14,T.muted,408,22);modal.group:SetPoint("TOPLEFT");modal.group:SetWordWrap(true);modal.group:SetMaxLines(2)
 modal.roleLabel=C.Text(content,Say("选择申请职责（可多选）","Choose your roles (multiple allowed)"),14,T.muted);C.SetLineHeight(modal.roleLabel,20,true)
 modal.roles={}
 for _,role in ipairs(roleKeys) do
  modal.roles[role]=C.RoleButton(content,role,nil,roleLabels[role],function() Native:SetApplicationRole(role) end)
 end
 modal.noteLabel=C.Text(content,Say("给队长的备注","Note to the leader"),14,T.muted);C.SetLineHeight(modal.noteLabel,20,true)
 modal.note=C.Field(content,408,96,false,"modal")
 modal.error=C.Text(content,"",14,T.warning,408,20);modal.error:SetMaxLines(1)
 modal.cancel=C.Button(modal.frame,L.cancel,nil,function() UI:CloseModal() end);modal.cancel:SetWidth(math.max(72,modal.cancel.label:GetStringWidth()+40));modal.cancel:SetHeight(40)
 modal.submit=C.Button(modal.frame,L.apply,112,function() Native:ConfirmApplication() end);modal.submit:SetPrimary(true);modal.submit:SetHeight(40)
 self.applicationModal=modal
 return modal
end
function Native:LayoutApplication()
 local modal=self.applicationModal
 local hasGroup=modal.group:GetText()~=""
 local groupHeight=hasGroup and math.max(22,math.min(44,modal.group:GetStringHeight())) or 0
 local groupOffset=hasGroup and groupHeight+20 or 0
 modal.group:SetShown(hasGroup)
 modal.group:SetHeight(groupHeight)
 modal.roleLabel:SetPoint("TOPLEFT",0,-groupOffset)
 local x=0
 for _,role in ipairs(roleKeys) do
  local button=modal.roles[role];button:SetPoint("TOPLEFT",x,-groupOffset-28);x=x+button:GetWidth()+8
 end
 modal.noteLabel:SetPoint("TOPLEFT",0,-groupOffset-88)
 modal.note:SetPoint("TOPLEFT",0,-groupOffset-116)
 local hasError=modal.error:GetText()~=""
 modal.error:SetShown(hasError);modal.error:SetPoint("TOPLEFT",0,-groupOffset-224);modal.error:SetHeight(hasError and 20 or 0)
 modal.frame:SetHeight(392+groupOffset+(hasError and 20 or 0))
 modal.submit:SetWidth(math.max(96,modal.submit.label:GetStringWidth()+40));modal.submit:SetPoint("BOTTOMRIGHT",-24,24)
 modal.cancel:SetPoint("RIGHT",modal.submit,"LEFT",-8,0)
end
function Native:SetApplicationRole(role)
 local lease=self.previewApplication or self.applicationLease;if not lease or not lease.available[role] then return end
 lease.roles[role]=not lease.roles[role] or nil
 self:RefreshApplicationRoles()
end
function Native:RefreshApplicationRoles()
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
function Native:ReleaseApplication()
 local lease=self.previewApplication or self.applicationLease;if not lease then return end
 self.previewApplication,self.applicationLease=nil,nil
 local modal=self.applicationModal
 modal.onClose=nil
 if lease.description then lease.description:Release()
 else modal.previewNote.box:ClearFocus();modal.previewNote.box:SetText("");modal.previewNote:Hide() end
 if modal.frame:IsShown() then modal:Close() end
end
function Native:OpenApplicationSettings(resultID,enableOnSave)
 if not UI.preview then local entry,err=self:Ready();if not entry then return false,err end end
 self:ReleaseApplication()
 local title=resultID and Say("申请加入","Apply to group") or L.applicationSettings
 local modal=self.applicationModal;if modal then UI:OpenModal("application",title,456,434) else modal=self:BuildApplication();modal:SetTitle(title) end
 local prefs=ApplicationPrefs();local lease={id=resultID,available={},roles={},enableOnSave=enableOnSave}
 for _,role in ipairs(roleKeys) do if prefs.roles and prefs.roles[role] then lease.roles[role]=true end end
 if UI.preview then
  self.previewApplication=lease
  if not modal.previewNote then modal.previewNote=C.Edit(modal.note,408,96,true,false,"modal");modal.previewNote:SetAllPoints(modal.note) end
  modal.previewNote.box:SetText(prefs.note or "");modal.previewNote:Show();modal.previewNote.box:SetFocus()
 else
  self.applicationLease=lease
  local dialog=LFGListApplicationDialog;local description=dialog.Description
  lease.dialog=dialog
  lease.description=C.NativeInput(modal.note,description.EditBox,{container=description,onLost=function() Native:ReleaseApplication() end})
  lease.description:Bind(dialog,"OnShow",function(frame,previous,...) if previous then previous(frame,...) end;Native:ReleaseApplication() end)
  lease.description:Bind(dialog,"OnEvent",function(frame,previous,event,...) if previous then previous(frame,event,...) end;if event=="LFG_ROLE_UPDATE" then Native:RefreshApplicationRoles() end end)
  if modal.previewNote then modal.previewNote:Hide() end
  description.EditBox:SetFocus();lease.description:RefreshStyle()
 end
 modal.onClose=function() Native:ReleaseApplication() end
 local result=resultID and UI:GetGroup():GetResult(resultID)
 UI:SetText(modal.group,result and result.name or "")
 UI:SetText(modal.submit.label,resultID and L.apply or L.save)
 self:RefreshApplicationRoles()
 return true
end
function Native:ConfirmApplication()
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
  prefs.roles=lease.roles
  if lease.enableOnSave then prefs.enabled=true end
  RefreshApplicationEntry();self:ReleaseApplication()
 end
end
function Native:Apply(resultID,manual,confirmedRoles)
 local group=UI:GetGroup()
 if group:GetListing() then return false,group.L.recruiting end
 if group.Applications:IsActive(resultID) then return false,group.L.alreadyApplied end
 if group.Applications:GetActiveCount()>=5 then self:ReleaseApplication();UI:ShowApplicationLimit(resultID,manual);return false,group.L.applicationLimit end
 if not UI.preview then
  local entry,err=self:Ready();if not entry then return false,err end
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
 if ok then self:ReleaseApplication() end
 return ok,err
end

-- Ordinary edits exist only for explicit preview and never register native text.
function Native:AcquirePreviewCreation(owner,title,description)
 if self.owner==owner and self.previewCreation then return true end
 self:ReleaseCreation()
 if not owner.previewTitle then
  owner.previewTitle=C.Edit(title,title:GetWidth(),title:GetHeight());owner.previewTitle:SetAllPoints(title)
  owner.previewDescription=C.Edit(description,description:GetWidth(),description:GetHeight(),true);owner.previewDescription:SetAllPoints(description)
  owner.previewTitle.box:SetScript("OnTextChanged",function() owner:ValidateForm() end)
  owner.previewDescription.box:SetScript("OnTextChanged",function() owner:ValidateForm() end)
 end
 self.owner=owner;self.previewCreation=true
 self.entry={Name=owner.previewTitle.box,Description={EditBox=owner.previewDescription.box}}
 owner.previewTitle:Show();owner.previewDescription:Show();return true
end
function Native:SetPreviewCreationText(name,comment)
 self.entry.Name:SetText(name or "");self.entry.Description.EditBox:SetText(comment or "")
end
function Native:GetPreviewCreationText() return self.entry.Name:GetText(),self.entry.Description.EditBox:GetText() end
