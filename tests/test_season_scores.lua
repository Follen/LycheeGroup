-- Isolated API sessions also allow: lua tests/test_season_scores.lua
local checks = 0
local function Equal(actual, expected, message)
 if T then T.eq(actual, expected, message)
 else assert(actual == expected, (message or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected)) end
 checks = checks + 1
end
local function Session()
 local s = {requests=0, mapReads=0, uiReads=0, levelReads={}, scoreReads={}, frames={},
  ids={101,102,103,104,107,108}, mapIDs={[101]=501,[102]=502,[103]=503,[104]=503,[107]=507,[108]=508},
  timed={[101]={level=15},[102]={level=9}}, overtime={[101]={level=29}}, scores={[101]=452,[102]=321,[108]=0}}
 local secrets, inaccessible = {}, {}
 function s:Secret()
  local value = setmetatable({}, {__index=function() error("secret table read") end,
   __lt=function() error("secret comparison") end, __le=function() error("secret comparison") end})
  secrets[value] = true
  return value
 end
 function s:Inaccessible()
  local value = setmetatable({}, {__index=function() error("inaccessible table read") end})
  inaccessible[value] = true
  return value
 end
 local E = setmetatable({}, {__index=_G})
 E._G = E
 E.issecretvalue = function(value) return secrets[value] or false end
 E.canaccesstable = function(value) return not inaccessible[value] end
 E.wipe = function(value) for key in pairs(value) do value[key] = nil end end
 E.LycheeGroup = {Group={Public=function(value) if not E.issecretvalue(value) then return value end end}}
 E.CreateFrame = function(kind)
  Equal(kind, "Frame")
  local frame = {events={}, scripts={}}
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:UnregisterAllEvents() E.wipe(self.events) end
  function frame:SetScript(event, callback) self.scripts[event] = callback end
  s.frames[#s.frames+1] = frame
  return frame
 end
 function s:Fire(event)
  for _, frame in ipairs(self.frames) do
   if frame.events[event] then frame.scripts.OnEvent(frame, event) end
  end
 end
 function s:Subscriptions()
  local count = 0
  for _, frame in ipairs(self.frames) do for _ in pairs(frame.events) do count = count + 1 end end
  return count
 end
 E.C_ChallengeMode = {
  GetMapTable=function() s.mapReads=s.mapReads+1;return s.ids end,
  GetMapUIInfo=function(id) s.uiReads=s.uiReads+1;return "Dungeon",nil,nil,nil,nil,s.mapIDs[id] end,
 }
 E.C_MythicPlus = {
  RequestMapInfo=function()
   s.requests=s.requests+1
   if s.syncRequest then s:Fire("CHALLENGE_MODE_MAPS_UPDATE") end
  end,
  GetSeasonBestForMap=function(id)
   s.levelReads[id]=(s.levelReads[id] or 0)+1
   return s.timed[id],s.overtime[id]
  end,
  GetSeasonBestAffixScoreInfoForMap=function(id)
   s.scoreReads[id]=(s.scoreReads[id] or 0)+1
   return s.affixScores,s.scores[id]
  end,
 }
 local chunk = assert(loadfile("addon/LycheeGroup_Group/SeasonScores.lua"))
 setfenv(chunk, E);chunk()
 s.service = E.LycheeGroup.Group.SeasonScores
 s.callback = function() s.updates=(s.updates or 0)+1 end
 function s:Group(mapID) return {activity={mapID=mapID}} end
 function s:Record(mapID) return self.service:GetRecord(self:Group(mapID)) end
 return s
end

-- Timed and overtime records have different meanings; absent timed data stays absent.
do
 local s=Session()
 Equal(#s.frames,0);Equal(s:Record(501).level,nil);Equal(s.mapReads,0)
 s.service:Begin(s.callback)
 Equal(s.requests,1);Equal(s:Subscriptions(),3)
 local record=s:Record(501)
 Equal(record.level,15);Equal(record.score,452)
 s.overtime[107]={level=30}
 Equal(s:Record(507).level,nil)
 Equal(s:Record(508).level,nil);Equal(s:Record(508).score,0,"a zero score is a real value")
 Equal(s:Record(507).score,nil)
 Equal(s:Record(999).score,nil)
end

-- Map identity is independent of the group key, label or selected difficulty.
do
 local s=Session();s.ids[#s.ids+1]=101;s.service:Begin(s.callback)
 local group={key=999,name="unrelated label",activity={mapID=502},variants={
  {mapID=501,isMythicPlusActivity=true},{mapID=501,isMythicPlusActivity=true},
  {mapID=502,isMythicPlusActivity=false}}}
 Equal(s.service:GetRecord(group).level,15)
 Equal(s:Record(503).level,nil,"shared map has no unique CMID")
 Equal(s.levelReads[103],nil);Equal(s.levelReads[104],nil)
 group.variants[2].mapID=502
 Equal(s.service:GetRecord(group).level,nil,"multiple keystone maps in one group are ambiguous")
 group.variants[2].mapID=0
 Equal(s.service:GetRecord(group).level,nil,"missing keystone identity cannot use the fallback")
 Equal(s.service:GetRecord(nil).score,nil)
 Equal(s.mapReads,1,"map table is shared across every group")
end

-- Raw restricted values must never reach arithmetic, indexing, or table traversal.
do
 local s=Session();s.service:Begin(s.callback)
 s.timed[101]=s:Inaccessible();s.scores[101]=s:Secret()
 s.timed[102]={level=s:Secret()}
 s.timed[107]=s:Secret();s.affixScores=s:Secret()
 s.mapIDs[108]=s:Secret();s.ids[#s.ids+1]=s:Secret()
 Equal(s:Record(501).level,nil);Equal(s:Record(501).score,nil)
 Equal(s:Record(502).level,nil);Equal(s:Record(502).score,321)
 Equal(s:Record(507).level,nil)
 Equal(s:Record(508).score,nil)
 Equal(s:Record(s:Secret()).level,nil)
 s.ids=s:Inaccessible();s:Fire("CHALLENGE_MODE_MAPS_UPDATE")
 Equal(s:Record(501).level,nil)
 s.ids=s:Secret();s:Fire("CHALLENGE_MODE_MAPS_UPDATE")
 Equal(s:Record(501).level,nil)
end

-- Validate public numeric data too: invalid data stays unknown, score zero survives.
do
 for _, value in ipairs({-1,math.huge,0/0,"15",false}) do
  local s=Session();s.timed[101]={level=value};s.scores[101]=value;s.service:Begin(s.callback)
  Equal(s:Record(501).level,nil);Equal(s:Record(501).score,nil)
 end
 local s=Session();s.timed[101]={level=0};s.scores[101]=0;s.service:Begin(s.callback)
 Equal(s:Record(501).level,nil);Equal(s:Record(501).score,0)
end

-- Repeated rendering shares per-CMID records, including known absence.
do
 local s=Session();s.service:Begin(s.callback)
 local first=s:Record(501);local absent=s:Record(507)
 for _=1,12 do
  Equal(s:Record(501),first);Equal(s:Record(507),absent)
  s.service:Begin(s.callback)
 end
 Equal(s.requests,1);Equal(s.mapReads,1);Equal(#s.frames,1)
 Equal(s.levelReads[101],1);Equal(s.scoreReads[101],1)
 Equal(s.levelReads[107],1);Equal(s.scoreReads[107],1)
 s.timed[101]={level=17};s.scores[101]=500
 Equal(s:Record(501).level,15,"snapshot changes only after invalidation")
 s:Fire("CHALLENGE_MODE_MAPS_UPDATE")
 Equal(s.requests,1);Equal(s.updates,1)
 Equal(s:Record(501).level,17);Equal(s:Record(501).score,500)
 Equal(s.mapReads,2);Equal(s.levelReads[101],2)
 s:Fire("CHALLENGE_MODE_COMPLETED");Equal(s.requests,2);Equal(s.updates,2)
 s:Fire("PLAYER_ENTERING_WORLD");Equal(s.requests,3);Equal(s.updates,3)
end

-- Closing releases listeners and observations; stale queued events cannot wake it.
do
 local s=Session();s.service:Begin(s.callback);s:Record(501)
 local replacementUpdates=0
 s.service:Begin(function() replacementUpdates=replacementUpdates+1 end)
 s:Fire("CHALLENGE_MODE_MAPS_UPDATE")
 Equal(s.updates,nil);Equal(replacementUpdates,1);Equal(s.requests,1)
 s.service:End();s.service:End();Equal(s:Subscriptions(),0)
 local reads=s.mapReads+s.uiReads+s.levelReads[101]+s.scoreReads[101]
 s:Fire("CHALLENGE_MODE_COMPLETED")
 s.frames[1].scripts.OnEvent(s.frames[1],"PLAYER_ENTERING_WORLD")
 for _=1,8 do Equal(s:Record(501).level,nil) end
 Equal(s.mapReads+s.uiReads+s.levelReads[101]+s.scoreReads[101],reads)
 Equal(s.requests,1);Equal(replacementUpdates,1)
 Equal(s.frames[1].scripts.OnUpdate,nil)
 s.scores[101]=900;s.service:Begin(s.callback)
 Equal(#s.frames,1);Equal(s.requests,2);Equal(s:Record(501).score,900)
 Equal(s.levelReads[101],2)
end

-- Registration precedes a request that may synchronously deliver map data.
do
 local s=Session();s.syncRequest=true
 s.service:Begin(function()
  s.observed=s:Record(501).level
  s.service:End()
 end)
 Equal(s.observed,15);Equal(s:Subscriptions(),0)
 Equal(s:Record(501).level,nil);Equal(s.requests,1)
end

if not T then print("SeasonScores: " .. checks .. " checks passed") end
