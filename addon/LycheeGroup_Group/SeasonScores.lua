-- 赛季选择器的自身成绩；仅可见消费者持有映射、成绩与事件。
local G = _G.LycheeGroup.Group
local S = {}
G.SeasonScores = S

local frame, active, onUpdate, maps
local records = {}
local unknown = {}

local function Number(value)
 value = G.Public(value)
 if type(value) == "number" and value >= 0 and value < math.huge then return value end
end

local function Accessible(value)
 value = G.Public(value)
 if type(value) == "table" and (not canaccesstable or canaccesstable(value)) then return value end
end

local function Invalidate()
 maps = nil
 wipe(records)
end

local function MapFor(group)
 if not group then return end
 local mapID
 for _, activity in ipairs(group.variants or {}) do
  if activity.isMythicPlusActivity then
   local id = Number(activity.mapID)
   if not id or id == 0 or mapID and mapID ~= id then return end
   mapID = id
  end
 end
 mapID = mapID or group.activity and Number(group.activity.mapID)
 if not mapID or mapID == 0 then return end
 if not maps then
  maps = {}
  for _, id in ipairs(Accessible(C_ChallengeMode.GetMapTable()) or {}) do
   id = Number(id)
   if id and id > 0 then
    -- LFG 使用地图 ID，成绩使用挑战模式 ID；同图多个 CMID 不猜归属。
    local _, _, _, _, _, nativeMapID = C_ChallengeMode.GetMapUIInfo(id)
    nativeMapID = Number(nativeMapID)
    if nativeMapID and nativeMapID > 0 then
     if maps[nativeMapID] == nil then maps[nativeMapID] = id
     elseif maps[nativeMapID] ~= id then maps[nativeMapID] = false end
    end
   end
  end
 end
 return maps[mapID] or nil
end

function S:GetRecord(group)
 if not active then return unknown end
 local id = MapFor(group)
 if not id then return unknown end
 if records[id] then return records[id] end
 -- 第一返回值是限时记录；第二返回值可能是更高层的超时记录。
 local intime = Accessible(C_MythicPlus.GetSeasonBestForMap(id))
 local _, score = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(id)
 local level = intime and Number(intime.level)
 local record = {level = level and level > 0 and level or nil, score = Number(score)}
 records[id] = record
 return record
end

function S:Begin(callback)
 onUpdate = callback
 if active then return end
 if not frame then
  frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function(_, event)
   if not active then return end
   Invalidate()
   if event ~= "CHALLENGE_MODE_MAPS_UPDATE" then C_MythicPlus.RequestMapInfo() end
   if active and onUpdate then onUpdate() end
  end)
 end
 active = true
 Invalidate()
 frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
 frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
 frame:RegisterEvent("PLAYER_ENTERING_WORLD")
 C_MythicPlus.RequestMapInfo()
end

function S:End()
 active, onUpdate = false, nil
 if frame then frame:UnregisterAllEvents() end
 Invalidate()
end
