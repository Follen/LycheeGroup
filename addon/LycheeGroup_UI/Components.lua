-- Game data resolvers stay in LycheeGroup; visual objects come from LycheeUI.
local UI = _G.LycheeGroup.UI
local context = UI.context
local T = context.Theme
UI.C = context.C
local C = UI.C
local function ClockText(seconds)
 local total=math.floor(seconds+.5)
 return ("%d:%02d"):format(math.floor(total/60),total%60)
end
function UI:DungeonRunTimeText(run, colored)
 if not run or not run.durationMs or not run.timeLimitSeconds then return end
 local elapsed=ClockText(run.durationMs/1000)
 if colored then
  local ratio=run.durationMs/(run.timeLimitSeconds*1000)
  local color
  if not run.timed or ratio>1 then color="dungeonTimeOvertime"
  elseif ratio<=.9 then color="dungeonTimeOrange"
  elseif ratio<=.95 then color="dungeonTimePurple"
  elseif ratio<=.97 then color="dungeonTimeBlue"
  else color="dungeonTimeGreen" end
  elapsed=self:Hex(T[color])..elapsed.."|r"
 end
 return elapsed.."/"..ClockText(run.timeLimitSeconds)
end
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
 return categoryTextures[kind] or self:MediaPath(kind..".tga")
end
local roleFiles={TANK="role-tank",HEALER="role-healer",DAMAGER="role-dps"}
function UI:SetRoleIcon(icon,role)
 local file=roleFiles[role]
 icon:SetTexture(file and UI:MediaPath(file..".tga") or nil);icon:SetTexCoord(0,1,0,1)
end
function UI:SetGameTexture(icon,...)
 return context:SetGameTexture(icon,...)
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
-- Search-result member decoration is product composition of ordinary images.
local function ApplyMemberDecoration(icon)
 local addon=_G.LycheeGroup
 local shape=addon:GetSetting("memberIconShape")
 local media="Interface\\AddOns\\LycheeGroup_UI\\Media\\member-"..shape
 local colors=CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
 local color=icon.memberClass and colors and colors[icon.memberClass]
 local visible=icon.memberDecorationVisible
 local bordered=visible and addon:GetSetting("memberClassBorder") and color~=nil
 local leader=visible and icon.memberIsLeader and addon:GetSetting("memberLeaderMark")
 context:RoundIcon(icon,shape=="square" and T.media.."icon-mask.tga" or media.."-mask.tga")
 local border=icon.memberBorder
 if bordered and not border then border=C.Icon(icon:GetParent(),1);icon.memberBorder=border end
 if border then
  border:SetTexture(shape=="square" and T.media.."icon-mask.tga" or media.."-border.tga")
  local inset=shape=="square" and T.memberSquareBorderWidth or 0
  border:SetDrawLayer(shape=="square" and "ARTWORK" or "OVERLAY",shape=="square" and -1 or 0)
  border:ClearAllPoints()
  if inset==0 then border:SetAllPoints(icon) else border:SetPoint("TOPLEFT",icon,"TOPLEFT",-inset,inset);border:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",inset,-inset) end
  if bordered then border:SetVertexColor(color.r,color.g,color.b,1) end
  border:SetShown(bordered==true)
 end
 local mark=icon.memberLeaderMark
 if leader and not mark then
  mark=C.Icon(icon:GetParent(),1);mark:SetDrawLayer("OVERLAY",1);UI:SetMediaTexture(mark,"leader.tga");icon.memberLeaderMark=mark
 end
 if mark then
  local scale=icon:GetParent():GetScale();local size=math.min(T.memberCrownSize,T.memberCrownScreenSize/scale)
  mark:SetSize(size,size);mark:ClearAllPoints();mark:SetPoint("BOTTOM",icon,"TOP",0,T.memberCrownGap/scale);mark:SetShown(leader==true)
 end
end
function UI:UpdateMemberIconStyle(icon,visible)
 icon.memberDecorationVisible=visible
 ApplyMemberDecoration(icon)
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
 if texture then self:SetGameTexture(icon,texture)
 else
  local coords=member and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[member.class]
  if coords then self:SetGameTexture(icon,"Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",unpack(coords))
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
 UI:SetGameTexture(icon,info.file or info.filename,left,right,top,bottom)
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
 if art then self:SetGameTexture(icon,art) else self:SetCategoryIcon(icon,activity and activity.categoryID) end
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


function UI:CreateRoleButton(parent,role,width,text,action)
 local button=C.Button(parent,text,width or 0,action)
 local icon=C.Icon(button,T.roleButtonIconSize);icon:SetPoint("LEFT",T.roleButtonInset,0);UI:SetRoleIcon(icon,role)
 button.roleIcon=icon
 button.label:ClearAllPoints();button.label:SetPoint("LEFT",icon,"RIGHT",T.roleButtonGap,0)
 button:SetWidth(width or button.label:GetStringWidth()+T.roleButtonReserve)
 button:SetSurfaceColors("surfaceLow","surfaceLowHover","surfaceLowPressed")

 return button
end
local rosterRoleOrder={TANK=1,HEALER=2,DAMAGER=3}
function UI:CreateRoster(parent,size,gap)
 local sizeRef,gapRef=size or "rosterSize",gap or "rosterGap"
 size,gap=context:ResolveValue(sizeRef),context:ResolveValue(gapRef)
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(size*5+gap*4,size+1)
 frame.slots={};frame.counts={};frame.elementSlots={root=frame}
 for i=1,5 do
  local icon=C.GameIcon(frame,size);icon:SetPoint("TOPLEFT",(i-1)*(size+gap),0)
  local role=C.Icon(frame,T.rosterRoleSize);role:SetDrawLayer("OVERLAY",2);role:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",1,-1)
  frame.slots[i]={icon=icon,role=role};frame.elementSlots["member:"..i]=icon;frame.elementSlots["memberRole:"..i]=role
 end
 for i,role in ipairs({"TANK","HEALER","DAMAGER"}) do
  local icon=C.Icon(frame,T.rosterCountIconSize);icon:SetPoint("LEFT",(i-1)*T.rosterCountStride,0);UI:SetRoleIcon(icon,role)
  local text=C.Text(frame,"","font14","text",T.rosterCountTextWidth);C.DefaultLineHeight(text,"line20",true);text:SetPoint("LEFT",icon,"RIGHT",T.rosterCountGap,0)
  frame.counts[i]={icon=icon,text=text,role=role};frame.elementSlots["countIcon:"..role]=icon;frame.elementSlots["countText:"..role]=text
 end
 local function PlaceRole(slot,large)
  local role=slot.role
  local extent=large and size or T.rosterRoleSize
  if role:GetWidth()~=extent or role:GetHeight()~=extent then role:SetSize(extent,extent) end
  local anchor=large and "CENTER" or "BOTTOMRIGHT"
  local offsetX,offsetY=large and 0 or 1,large and 0 or -1
  local point,parent,relative,x,y=role:GetPoint()
  if role:GetNumPoints()~=1 or point~=anchor or parent~=slot.icon or relative~=anchor or x~=offsetX or y~=offsetY then
   role:ClearAllPoints();role:SetPoint(anchor,slot.icon,anchor,offsetX,offsetY)
  end
 end
 function frame:Update(members,counts,maximum,fixedRoles)
  local party=maximum==5
  for _,item in ipairs(self.counts) do item.icon:SetShown(not party);item.text:SetShown(not party);if not party then UI:SetText(item.text,counts and counts[item.role] or "—") end end
  local used=0
  if party and (members or fixedRoles) then
   local tanks,healers,damage=0,0,0
   for rank=1,4 do
    local present=0
    for i=1,5 do
     local member=members and members[i]
     if member and (rosterRoleOrder[member.assignedRole] or 4)==rank then
      present=present+1
      used=used+1;local slot=self.slots[used]
      slot.icon:Show();slot.role:Hide();UI:SetMemberIcon(slot.icon,member);slot.icon:SetAlpha(1)
      PlaceRole(slot,false)
      if member.assignedRole and member.assignedRole~="NONE" then UI:SetRoleIcon(slot.role,member.assignedRole);slot.role:Show() end
     end
    end
    if rank==1 then tanks=present elseif rank==2 then healers=present elseif rank==3 then damage=present end
   end
   if fixedRoles then
    for rank=1,3 do
     local present=rank==1 and tanks or rank==2 and healers or damage
     local missing=math.min(5-used,math.max(0,(rank==3 and 3 or 1)-present))
     local role=rank==1 and "TANK" or rank==2 and "HEALER" or "DAMAGER"
     for i=1,missing do
      used=used+1;local slot=self.slots[used]
      slot.icon:Hide();PlaceRole(slot,true)
      UI:SetRoleIcon(slot.role,role);slot.role:Show()
     end
    end
   end
  end
  for i=used+1,5 do self.slots[i].icon:Hide();self.slots[i].role:Hide() end
 end

 return frame
end
