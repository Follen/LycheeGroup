-- Select native activities only when a route starts; loading Guide reads no client data.
local A=_G.LycheeGroup
local Guide=A.Guide
local empty={}
local function Positive(value) return type(value)=="number" and value>0 and value<math.huge end
local function Select(catalog,category,mythicOnly)
 if type(category)~="table" or category.id~=2 then return end
 for _,activity in ipairs(catalog:GetActivities(category.key) or empty) do
  if type(activity)=="table" and Positive(activity.id) and activity.categoryID==2 and (not mythicOnly or activity.isMythicPlusActivity) then
   local key=catalog:GetGroupKey(category.key,activity)
   local group=key and catalog:GetGroup(category.key,key)
   if type(group)=="table" and group.activity and catalog:GetActivity(activity.id)==activity then return activity,category.key,group end
  end
 end
end
function Guide:ResolveActivity(catalog)
 if type(catalog)=="table" and type(catalog.GetCategories)=="function" and type(catalog.GetActivities)=="function"
  and type(catalog.GetGroupKey)=="function" and type(catalog.GetGroup)=="function" and type(catalog.GetActivity)=="function" then
  if type(catalog.Build)=="function" then catalog:Build() end
  local categories=catalog:GetCategories() or empty
  for _,category in ipairs(categories) do
   if category.key=="seasonDungeon" then
    local activity,key,group=Select(catalog,category,true)
    if activity then return activity,key,group end
   end
  end
  for _,category in ipairs(categories) do
   if category.key=="seasonDungeon" then
    local activity,key,group=Select(catalog,category)
    if activity then return activity,key,group end
   end
  end
  for _,category in ipairs(categories) do
   local activity,key,group=Select(catalog,category)
   if activity then return activity,key,group end
  end
 end
 return nil,A:GetLocale()=="zhCN" and "当前游戏活动目录尚无可用地下城，请稍后再开始引导。" or "No dungeon is available in the game activity catalog yet. Start the guide again shortly."
end

-- One successful static map lookup is retained; no player score or run history is read.
local limitMapID,limitSeconds
function Guide:ResolveTimeLimit(activity)
 local mapID=type(activity)=="table" and activity.mapID
 if not Positive(mapID) then return end
 if mapID==limitMapID then return limitSeconds end
 if not C_ChallengeMode or not C_ChallengeMode.GetMapTable or not C_ChallengeMode.GetMapUIInfo then return end
 for _,challengeID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
  local _,_,seconds,_,_,gameMapID=C_ChallengeMode.GetMapUIInfo(challengeID)
  if gameMapID==mapID and Positive(seconds) then limitMapID,limitSeconds=mapID,seconds;return seconds end
 end
end
