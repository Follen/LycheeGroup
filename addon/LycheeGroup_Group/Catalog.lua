-- 客户端活动目录按需读取；分类、菜单与筛选共享同一份活动原表。
local A = _G.LycheeGroup
local G = A.Group
local Catalog = {activities={},groups={},journalTiers={}}
G.Catalog = Catalog
local F = Enum.LFGListFilter
-- Labels only: membership remains the live catalog's native group identity.
local dungeonAbbreviations={
 [2993]={"毒牙","AoF"},[2825]={"洞穴","DoN"},[1877]={"神庙","ToS"},[1762]={"诸王","KR"},
 [2521]={"红玉","RLP"},[2859]={"夺目","BV"},[2813]={"密谋","MR"},[2923]={"竞技场","VA"},
}
-- Client-derived Delve map metadata, Retail 12.1.5.70391.
-- Data pin PIN-93b278ff0cb7e66294714a107bb19afb8456125a9a9acae43275a3828de17938;
-- CAP-d0352dd303ec3a04ef12dd845dad7233a3729b526a7a767d508223155b862189.
-- Distinct MapID and ExpansionID pairs from category 121 activity records,
-- joined with the native Map table on MapID.
-- Names and activity membership always come from the running client.
local delveExpansions={
 [2664]=10,[2679]=10,[2680]=10,[2681]=10,[2682]=10,[2683]=10,[2684]=10,[2685]=10,[2686]=10,[2687]=10,[2688]=10,[2689]=10,[2690]=10,[2803]=10,[2815]=10,[2826]=10,[2831]=10,[2951]=10,
 [2933]=11,[2952]=11,[2953]=11,[2961]=11,[2962]=11,[2963]=11,[2964]=11,[2965]=11,[2966]=11,[2979]=11,[3003]=11,[3038]=11,[3077]=11,[3079]=11,
}
local function SortActivity(a,b)
 if a.orderIndex~=b.orderIndex then return (a.orderIndex or 0)<(b.orderIndex or 0) end
 return a.id<b.id
end
function Catalog:GetActivity(id)
 if not id then return nil end
 local value=self.activities[id]
 if value then return value end
 value=C_LFGList.GetActivityInfoTable(id)
 if not value then return nil end
 value.id=id;value.name=value.fullName~="" and value.fullName or value.shortName
 value.groupID=value.groupFinderActivityGroupID
 value.groupKey=value.groupID and value.groupID>0 and value.groupID or -id
 value.journalID=value.mapID and value.mapID>0 and C_EncounterJournal.GetInstanceForGameMap(value.mapID) or nil
 self.activities[id]=value
 return value
end
function Catalog:GetCategories()
 if self.categories then return self.categories end
 local list={
  {key="seasonDungeon",id=2,name=G.L.seasonDungeon,icon="mountain",season=true},
  {key="seasonRaid",id=3,name=G.L.seasonRaid,icon="tower",season=true},
 }
 local ids=C_LFGList.GetAvailableCategories(0) or {}
 local function Add(id)
  for _,value in ipairs(ids) do
   if value==id then
    local info=C_LFGList.GetLfgCategoryInfo(id)
    list[#list+1]={key=tostring(id),id=id,name=info.name,
     icon=id==2 and "mountain" or id==3 and "tower" or id==121 and "delve" or id==1 and "flag" or id==6 and "plus" or "pvp"}
    return
   end
  end
 end
 Add(121);Add(2);Add(3)
 for _,id in ipairs(ids) do if id~=121 and id~=2 and id~=3 then Add(id) end end
 self.categories=list
 return list
end
function Catalog:GetCategory(key)
 for _,category in ipairs(self:GetCategories()) do if category.key==key then return category end end
end
function Catalog:GetFilter(category)
 if type(category)=="string" then category=self:GetCategory(category) end
 if category.id==3 then return F.PvE end
 if category.season then
  return bit.bor(F.CurrentSeason,F.PvE)
 end
 if category.id==2 then return bit.bor(F.NotCurrentSeason,F.PvE) end
 return 0
end
function Catalog:GetActivities(key)
 local category=self:GetCategory(key)
 if not category then return {} end
 if category.activities then return category.activities end
 local result,activitySet={},{}
 local flags=self:GetFilter(category)
 local seasonRaid=category.key=="seasonRaid"
 if seasonRaid then self:GetTiers() end
 -- Native CurrentSeason returns the map's available normal/heroic/mythic/key
 -- variants together (Retail 12.1.5.70391 live scan f019d9da39b8f4df907fa3540827f015).
 -- Keep the complete getter result; do not narrow it to isMythicPlusActivity.
 for _,id in ipairs(C_LFGList.GetAvailableActivities(category.id,nil,flags) or {}) do
  local activity=self:GetActivity(id)
  if activity and (not seasonRaid or (activity.mapID or 0)>0 and self.seasonRaidJournals[activity.journalID]) then
   result[#result+1]=activity
   activitySet[id]=true
  end
 end
 table.sort(result,SortActivity);category.activities,category.activitySet=result,activitySet
 return result
end
function Catalog:GetTiers()
 if self.tiers then return self.tiers end
 local tiers={}
 local current=EJ_GetCurrentTier()
 -- Observed in Retail 12.1.5.70391: the final EJ tier is the season subset.
 -- Keep that membership separate so repeated journals retain their expansion.
 local seasonTier=EJ_GetNumTiers()
 self.seasonRaidJournals={}
 for tier=1,seasonTier do
  local isSeason=tier==seasonTier
  if not isSeason then tiers[#tiers+1]={id=tier,name=EJ_GetTierInfo(tier)} end
  EJ_SelectTier(tier)
  for mode=1,2 do
   if not isSeason or mode==2 then
    local index=1
    local id=EJ_GetInstanceByIndex(index,mode==2)
    while id do
     if isSeason then self.seasonRaidJournals[id]=true else self.journalTiers[id]=tier end
     index=index+1;id=EJ_GetInstanceByIndex(index,mode==2)
    end
   end
  end
 end
 if current then EJ_SelectTier(current) end
 self.expansionTiers={}
 for expansion=10,11 do
  local name=_G["EXPANSION_NAME"..expansion]
  if name then
   for _,tier in ipairs(tiers) do if tier.name==name then self.expansionTiers[expansion]=tier.id;break end end
   if not self.expansionTiers[expansion] then local id="exp"..expansion;tiers[#tiers+1]={id=id,name=name};self.expansionTiers[expansion]=id end
  end
 end
 self.tiers=tiers
 return tiers
end
function Catalog:GetTierName(id)
 for _,tier in ipairs(self:GetTiers()) do if tier.id==id then return tier.name end end
end
function Catalog:GetActivityTier(activity)
 self:GetTiers()
 local journal=activity.journalID and self.journalTiers[activity.journalID]
 if journal then return journal end
 local expansion=activity.categoryID==121 and delveExpansions[activity.mapID]
 return expansion and self.expansionTiers[expansion]
end
function Catalog:GetGroupKey(key,activity)
 return activity.groupKey
end
-- Search the complete explicit seasonal activity set without adding another difficulty restriction.
function Catalog:GetSearchFilter(category)
 if type(category)=="string" then category=self:GetCategory(category) end
 return category.key=="seasonDungeon" and F.PvE or self:GetFilter(category)
end
function Catalog:GetGroups(key)
 if self.groups[key] then return self.groups[key] end
 self:GetTiers()
 local list,index={},{}
 for _,activity in ipairs(self:GetActivities(key)) do
  local groupKey=self:GetGroupKey(key,activity)
  local group=index[groupKey]
  if not group then
   local name=groupKey>0 and C_LFGList.GetActivityGroupInfo(groupKey)
   group={key=groupKey,name=name or activity.name,categoryID=activity.categoryID,
    tier=self:GetActivityTier(activity),activity=activity,variants={}}
   index[groupKey]=group;list[#list+1]=group
  end
  group.variants[#group.variants+1]=activity
 end
 self.groups[key]=list
 return list
end
function Catalog:GetGroup(key,groupKey)
 for _,group in ipairs(self:GetGroups(key)) do if group.key==groupKey then return group end end
end
function Catalog:GetGroupShortName(key,groupKey)
 local group=self:GetGroup(key,groupKey)
 local names=dungeonAbbreviations[group.activity.mapID]
 return names and names[A:GetLocale()=="zhCN" and 1 or 2] or group.name
end
function Catalog:Matches(activity,key,groupKey,difficultyID,tier,groupKeys)
 if not activity then return false end
 local category=self:GetCategory(key)
 if not category or activity.categoryID~=category.id then return false end
 if groupKey and self:GetGroupKey(key,activity)~=groupKey then return false end
 if groupKeys and not groupKeys[self:GetGroupKey(key,activity)] then return false end
 if difficultyID and activity.difficultyID~=difficultyID then return false end
 if tier then self:GetTiers();if self:GetActivityTier(activity)~=tier then return false end end
 if category.season or category.id==2 or category.id==3 then
  if not category.activities then self:GetActivities(key) end
  return category.activitySet[activity.id]==true
 end
 return true
end
function Catalog:Invalidate()
 wipe(self.activities);wipe(self.groups);wipe(self.journalTiers)
 self.categories=nil;self.tiers=nil;self.expansionTiers=nil;self.seasonRaidJournals=nil
end

-- A saved listing is identified by its actual native activity, never by its name.
function Catalog:GetContextForActivity(id,preferred)
 if preferred then for _,activity in ipairs(self:GetActivities(preferred)) do if activity.id==id then return preferred end end end
 for _,category in ipairs(self:GetCategories()) do for _,activity in ipairs(self:GetActivities(category.key)) do if activity.id==id then return category.key end end end
end
