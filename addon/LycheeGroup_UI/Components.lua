-- Game data resolvers stay in LycheeGroup; visual objects come from LycheeUI.
local UI = _G.LycheeGroup.UI
local context = UI.context
local T = context.Theme
UI.C = context.C
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
function UI:CanWhisperFaction(factionGroup)
 return not self.preview and factionGroup~=nil and factionGroup==PLAYER_FACTION_GROUP[UnitFactionGroup("player")]
end
local specIcons={}
local specMetadata={}
local function Specialization(specID)
 local cached=specMetadata[specID]
 if cached then return cached[1],cached[2] end
 local _,name,_,icon=GetSpecializationInfoByID(specID)
 -- Only complete native metadata is stable enough to retain; missing data
 -- must remain retryable when a later binding can resolve it.
 if name and icon then specMetadata[specID]={name,icon} end
 return name,icon
end
function UI:SpecName(member)
 if member.specName then return member.specName end
 if member.specID and member.specID>0 then local name=Specialization(member.specID);return name end
end
function UI:SetMemberIcon(icon,member)
 local spec=member and member.specID
 local texture=spec and spec>0 and select(2,Specialization(spec))
 if not texture and member and member.specName and member.class then
  local entries=specIcons[member.class]
  if not entries then
   entries={};specIcons[member.class]=entries
   for classID=1,GetNumClasses() do
    local _,file=GetClassInfo(classID)
    if file==member.class then
     for index=1,C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
      local _,name,_,art=GetSpecializationInfoForClassID(classID,index);entries[name]=art
     end
     break
    end
   end
  end
  texture=entries[member.specName]
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
 icon:SetTexture(T.media..kind..".tga");icon:SetTexCoord(0,1,0,1)
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
