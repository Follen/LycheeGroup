-- Reuse the engine's registered text objects. Protected text is never SetText'd,
-- copied through addon strings, or replaced with an ordinary EditBox.
-- Explicit local preview uses separate ordinary edits and never leases these objects.
local A = _G.LycheeGroup
local UI, Native = A.UI, {}
UI.Native = Native
local L, C = UI.L, UI.C

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
 local search=UI:GetGroup().Search
 local entry,err=self:Ready()
 if not entry then return false,err end
 local panel=LFGListFrame.SearchPanel
 local box=panel and panel.SearchBox
 if not box then return false,L.unavailable end
 local previousChanged=box:GetScript("OnTextChanged")
 local hide={}
 for _,region in ipairs({box.Instructions,box.clearButton,panel.AutoCompleteFrame}) do hide[#hide+1]=region end
 lease=C.NativeInput(shell,box,{
  padding={52,4,owner.searchInputRight,4},textInsets={0,0,0,0},hide=hide,
  onLost=function(control)
   search:ReleaseInput(control)
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
 if not lease:IsOwned() then self.searchDirty=true;lease:Release();return false,L.unavailable end
 lease.owner=owner;lease.revision=0;lease.previousChanged=previousChanged;lease.searchService=search
 self.searchLease=lease
 search:BindInput(lease)
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
 lease.searchService:ReleaseInput(lease)
 local owned=lease:Release()
 if not owned then self.searchDirty=true;lease.owner:OnSearchInputLost()
 elseif lease.previousChanged then lease.previousChanged(lease.box,false) end
end
function Native:UseLeaderSearch()
 self:ReleaseSearch()
 C_LFGList.ClearSearchTextFields()
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
  owner:OnCreationInputLost()
 end
 local titleInput=C.NativeInput(title,name,{
  onLost=Lost,
  scripts={
   -- The stock callback assumes EntryCreation is the field's direct parent.
   OnTextChanged=function(box) InputBoxInstructions_OnTextChanged(box);owner:ValidateForm() end,
   OnTabPressed=function() desc.EditBox:SetFocus() end,
  },
 })
 if self.owner~=owner or not titleInput:IsOwned() then titleInput:Release();self:ReleaseCreation();return false,L.unavailable end
 self.titleInput=titleInput
 local descriptionInput=C.NativeInput(description,desc.EditBox,{
  container=desc,onLost=Lost,
  scripts={
   OnTabPressed=function() name:SetFocus() end,
   OnTextChanged=function(box,userInput) if descriptionChanged then descriptionChanged(box,userInput) end;owner:ValidateForm() end,
  },
 })
 if self.owner~=owner or not titleInput:IsOwned() or not descriptionInput:IsOwned() then descriptionInput:Release();self:ReleaseCreation();return false,L.unavailable end
 self.descriptionInput=descriptionInput
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
 if title then if title:IsOwned() then entry.Name.selectedActivity,entry.Name.selectedCategory=nil,nil end;title:Release() end
 if description then if description:IsOwned() then entry.Description.selectedActivity,entry.Description.selectedCategory=nil,nil end;description:Release() end
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
