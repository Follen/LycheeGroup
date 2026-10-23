-- Game data resolvers stay in LycheeGroup; visual objects come from LycheeUI.
local UI = _G.LycheeGroup.UI
local context = UI.context
local T = context.Theme
UI.C = context.C
function UI:GetTablePrefs(id)
 if not self.preview then return _G.LycheeGroup.Appearance:GetTableState(id) end
 local prefs=self.preview.provider.prefs
 prefs.tableLayouts=prefs.tableLayouts or {}
 prefs.tableLayouts[id]=prefs.tableLayouts[id] or {}
 return prefs.tableLayouts[id]
end
context.options.onTablePreferenceChanged=function(header,changes)
 return _G.LycheeGroup.Appearance:SaveTableState(header,changes)
end
function UI:OnLayoutPreferencesChanged(changed,rail)
 if self.preview then return end
 local appearance=_G.LycheeGroup.Appearance
 for header in pairs(context.tableHeaders or {}) do
  if changed[appearance:GetTableID(header.state)] and header.layoutWidth then header:Layout(header.layoutWidth) end
 end
 if not self:IsShown() then return end
 local page=self.page and self.pages[self.page]
 if not page or not page.frame then return end
 if self.page=="find" then
  if rail then page:SetSidebarCollapsed(appearance:GetRailCollapsed(),false,false) end
  if changed[appearance:GetTableID(page.resultsHeader.state)] then
   local sorting=page.resultsHeader.state
   if sorting.sortKey then page:OnHeaderSort(sorting.sortKey,sorting.descending) else page:RefreshResults() end
  elseif changed.findApplications then page:RefreshApplications() end
 elseif self.page=="create" and changed.createApplicants then page:ApplyTablePreferences()
 elseif self.page=="notes" then
  if changed.notesRecords and page.left:IsShown() then page:RefreshList() end
  if changed.notesHistory and page.historyFrame:IsShown() then page:RefreshHistory() end
 end
end
function UI:StopTableDrags()
 for header in pairs(context.tableHeaders or {}) do header:StopDrag(false) end
end
local categoryTextures={
 ["pvp-arena"]="Interface\\AddOns\\LycheeGroup_UI\\Media\\pvp-arena.tga",
 ["pvp-skirmish"]="Interface\\AddOns\\LycheeGroup_UI\\Media\\pvp-skirmish.tga",
 ["pvp-battleground"]="Interface\\AddOns\\LycheeGroup_UI\\Media\\pvp-battleground.tga",
 ["pvp-rated-battleground"]="Interface\\AddOns\\LycheeGroup_UI\\Media\\pvp-rated-battleground.tga",
}
function UI:CategoryIcon(kind)
 return categoryTextures[kind] or T.media..kind..".tga"
end
function UI:SetRoleIcon(icon,role)
 return _G.LycheeUI.Context.SetRoleIcon(context,icon,role)
end
function UI:MemberHasRole(member,role)
 if member.requestedRoles then return member.requestedRoles[role]==true end
 return member.assignedRole==role
end
local factionTextures={Alliance="Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-alliance.tga",Horde="Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-horde.tga"}
function UI:SetFactionIcon(icon,member)
 local faction=member.factionGroup and PLAYER_FACTION_GROUP[member.factionGroup]
 local texture=factionTextures[faction]
 icon:SetShown(texture~=nil)
 if texture then icon:SetTexture(texture) end
 return texture~=nil
end
function UI:BindTooltipArea(row,fraction,eligible,show)
 local area=CreateFrame("Frame",nil,row)
 area:SetPoint("TOPLEFT");area:SetPoint("BOTTOMLEFT");area:SetWidth(row:GetWidth()*fraction)
 row.tooltipArea=area
 row:HookScript("OnSizeChanged",function(_,width) area:SetWidth(width*fraction) end)
 area:SetScript("OnEnter",function()
  if not eligible(row) then return end
  local enter=row:GetScript("OnEnter");if enter then enter(row) end
  show(row)
 end)
 area:SetScript("OnLeave",function()
  if not row:IsMouseOver() then local leave=row:GetScript("OnLeave");if leave then leave(row) end end
  UI.Tooltip:LeaveOwner(row)
 end)
 area:SetScript("OnHide",function() if UI.Tooltip:IsOwned(row) then UI.Tooltip:Hide() end end)
 -- Setting hover scripts enables clicks in Retail; narrow input last.
 area:EnableMouse(false);area:EnableMouseMotion(true)
 return area
end
local Specializations=_G.LycheeGroup.Specializations
function UI:SpecName(member)
 if member.specName then return member.specName end
 if member.specID and member.specID>0 then local name=Specializations:Get(member.specID);return name end
end
-- These decorations belong only to opted-in search-result member slots.
function UI:UpdateMemberIconStyle(icon,visible)
 local addon=_G.LycheeGroup
 local shape=addon:GetSetting("memberIconShape")
 local media="Interface\\AddOns\\LycheeGroup_UI\\Media\\member-"..shape
 local colors=CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
 local color=icon.memberClass and colors and colors[icon.memberClass]
 local bordered=visible and addon:GetSetting("memberClassBorder") and color~=nil
 local leader=visible and icon.memberIsLeader and addon:GetSetting("memberLeaderMark")
 local mark=icon.memberLeaderMark
 if leader and not mark then
  mark=icon:GetParent():CreateTexture(nil,"OVERLAY",nil,1)
  mark:SetTexture(T.media.."leader.tga");icon.memberLeaderMark=mark
 end
 local scale=icon:GetParent():GetScale()
 local appearance=icon.memberAppearance
 if not appearance then appearance={classColor={0,0,0,1}};icon.memberAppearance=appearance end
 appearance.mask=shape=="square" and T.media.."icon-mask.tga" or media.."-mask.tga"
 appearance.border=icon.memberBorder
 appearance.borderTexture=(bordered or icon.memberBorder) and (shape=="square" and T.media.."icon-mask.tga" or media.."-border.tga") or nil
 if bordered then
  appearance.classColor[1],appearance.classColor[2],appearance.classColor[3]=color.r,color.g,color.b
  appearance.borderColor=appearance.classColor
 else appearance.borderColor=nil end
 appearance.borderVisible=bordered==true
 appearance.borderWidth=shape=="square" and T.memberSquareBorderWidth or 0
 appearance.borderLayer,appearance.borderSublevel=shape=="square" and "ARTWORK" or "OVERLAY",shape=="square" and -1 or 0
 appearance.crown,appearance.crownSize,appearance.crownGap=mark,math.min(T.memberCrownSize,T.memberCrownScreenSize/scale),T.memberCrownGap/scale
 appearance.crownVisible=leader==true
 context:StyleMemberIcon(icon,appearance)
 icon.memberShape=shape
end

function UI:SetMemberIcon(icon,member)
 if icon.memberStyle then
  icon.memberClass=member and member.class
  icon.memberIsLeader=member and (member.isLeader==true or icon.memberLeaderKey~=nil and member.nameKey==icon.memberLeaderKey) or false
 end
 local spec=member and member.specID
 local texture=spec and spec>0 and select(2,Specializations:Get(spec))
 if not texture and member and member.specName and member.class then
  texture=select(3,Specializations:Find(member.class,member.specName))
 end
 if texture then context:SetGameTexture(icon,texture)
 else
  local coords=member and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[member.class]
  if coords then context:SetGameTexture(icon,"Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",unpack(coords))
  else self:SetRoleIcon(icon,member and member.assignedRole) end
 end
end

-- Blizzard's Delve entrance backgrounds, Retail 12.1.5.70391.
-- UiWidgetVisualization.FrameTextureKit -> UiTextureKit.KitPrefix;
-- CAP-3282afcb4f9ab2d315a7a2c9d52ea2845d2de875772bb0ab4931bcfc8ae02112.
local delveAtlases={
 [2933]="delve-entrance-background-collegiate-calamity",
 [2951]="delve-entrance-background-voidrazor-sanctuary",
 [2952]="delve-entrance-background-the-shadow-enclave",
 [2953]="delve-entrance-background-parhelion-plaza",
 [2961]="delve-entrance-background-twilight-crypts",
 [2962]="delve-entrance-background-atal-aman",
 [2963]="delve-entrance-background-the-grudge-pit",
 [2964]="delve-entrance-background-gulf-of-memory",
 [2965]="delve-entrance-background-sunkiller-sanctum",
 [2966]="delve-entrance-background-torments-rise",
 [2979]="delve-entrance-background-shadowguard-point",
 [3003]="delve-entrance-background-the-darkway",
}
function UI:SetCategoryIcon(icon,categoryID)
 local group=self:GetGroup()
 local kind="plus"
 if group then
  for _,category in ipairs(group.Catalog:GetCategories()) do
   if category.id==categoryID then kind=category.icon;break end
  end
 end
 icon:SetTexture(self:CategoryIcon(kind));icon:SetTexCoord(0,1,0,1)
end
local function SetDelveIcon(icon,atlas)
 local info=C_Texture.GetAtlasInfo(atlas)
 if not info or not (info.file or info.filename) then UI:SetCategoryIcon(icon,121);return end
 local left,right,top,bottom=info.leftTexCoord,info.rightTexCoord,info.topTexCoord,info.bottomTexCoord
 -- The 584x384 entrance tile includes a parchment panel to the right of
 -- its 352x384 scene. Crop a square inside the scene, not the whole tile.
 local pixelU,pixelV=(right-left)/info.width,(bottom-top)/info.height
 right=left+352*pixelU
 top=top+(info.height-352)*.5*pixelV;bottom=top+352*pixelV
 context:SetGameTexture(icon,info.file or info.filename,left,right,top,bottom)
end
local activityArt={}
function UI:ActivityArt(activity)
 local map=activity and activity.mapID
 if not map or map==0 then return nil end
 local cached=activityArt[map]
 if cached~=nil then return cached or nil end
 local journal=C_EncounterJournal.GetInstanceForGameMap(map)
 local art=journal and select(6,EJ_GetInstanceInfo(journal)) -- buttonImage, not portraitImage
 activityArt[map]=art or false
 return art
end
function UI:SetActivityIcon(icon,activity)
 local atlas=activity and delveAtlases[activity.mapID]
 if atlas then SetDelveIcon(icon,atlas);return end
 local art=self:ActivityArt(activity)
 if art then context:SetGameTexture(icon,art) else self:SetCategoryIcon(icon,activity and activity.categoryID) end
end
function UI:MemberCounts(members)
 local counts={TANK=0,HEALER=0,DAMAGER=0}
 for _,member in ipairs(members) do local role=member.assignedRole;if counts[role] then counts[role]=counts[role]+1 end end
 return counts
end
function UI:StatusColor(status)
 if status=="invited" or status=="inviteaccepted" then return T.good end
 if status=="applied" or status=="pending" then return T.warning end
 if status=="failed" or status=="declined" then return T.accent end
 return T.muted
end


function context:SetMemberIcon(icon,member) return UI:SetMemberIcon(icon,member) end
function context:SetActivityIcon(icon,activity) return UI:SetActivityIcon(icon,activity) end
