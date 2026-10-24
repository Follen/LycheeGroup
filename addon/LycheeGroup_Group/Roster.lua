-- 当前队伍专精：LibSpecialization 优先；缺失时串行检视。
-- 没有轮询。计时器用于合并同帧专精广播、一次通信等待、检视节流和当前请求超时。
local A=_G.LycheeGroup
local G=A.Group
local R={members={},dirty=true,librarySpecs={},inspected={},attempted={},changed={}}
G.Roster=R
local LIBRARY_WAIT,INSPECT_INTERVAL,INSPECT_TIMEOUT=1,2,5
local lastInspect=-math.huge

local function EachUnit(callback)
 if IsInRaid() then for i=1,GetNumGroupMembers() do callback("raid"..i,i) end
 else callback("player");for i=1,GetNumSubgroupMembers() do callback("party"..i) end end
end
local function Positive(value)
 value=G.Public(value)
 if type(value)=="number" and value>0 and value<math.huge then return value end
end
local function CancelTimer()
 if R.timer then R.timer:Cancel();R.timer=nil end
end
local function CancelRefresh()
 if R.refreshTimer then R.refreshTimer:Cancel();R.refreshTimer=nil end
end
local function Refresh()
 G:Notify("roster")
 if R.active then R:Get() end
end
local function Prune(seen)
 for _,cache in ipairs({R.librarySpecs,R.inspected,R.attempted,R.changed}) do
  for guid in pairs(cache) do if not seen[guid] then cache[guid]=nil end end
 end
 if R.pending and not seen[R.pending.guid] then CancelTimer();R.pending=nil end
end

function R:Init()
 self.library=LibStub("LibSpecialization")
 self.library.RegisterGroup(self,function(specID,_,_,name) R:OnLibrarySpec(specID,name) end)
end

-- 库不提供历史缓存；只保留当前队伍的 specID，不保存天赋字符串。
-- 回调在 Group 已加载期间接收事件，关窗不丢失队友之后广播的新专精。
function R:OnLibrarySpec(specID,name)
 local key=A:PlayerKey(name)
 local seen,matched,matchedKey={},nil,nil
 EachUnit(function(unit)
  local unitKey=A:UnitIdentity(unit)
  local guid=G.Public(UnitGUID(unit))
  if guid then
   seen[guid]=true
   if unitKey==key and not G.Public(UnitIsUnit(unit,"player")) then matched,matchedKey=guid,unitKey end
  end
 end)
 Prune(seen)
 if not matched then return end
 G.History:OnSpecUpdate(matchedKey,specID)
 if self.librarySpecs[matched]==specID then return end
 self.librarySpecs[matched]=specID;self.changed[matched]=nil
 if self.pending and self.pending.guid==matched then CancelTimer();self.pending=nil
 elseif not self.pending then CancelTimer() end
 self.dirty=true
 if self.active then
  if not self.refreshTimer then
   self.refreshTimer=C_Timer.NewTimer(0,function() R.refreshTimer=nil;Refresh() end)
  end
 else
  Refresh()
 end
end

function R:SetActive(active)
 if self.active==active then return end
 self.active=active;self.dirty=true
 CancelTimer();CancelRefresh();self.pending=nil;wipe(self.attempted)
 if active then self.libraryWaitUntil=GetTime()+LIBRARY_WAIT end
end

function R:Invalidate(reason,unit)
 CancelRefresh()
 if reason=="spec" and unit and not G.Public(UnitIsUnit(unit,"player")) then
  local guid=G.Public(UnitGUID(unit))
  if guid then
   self.librarySpecs[guid]=nil;self.inspected[guid]=nil;self.attempted[guid]=nil;self.changed[guid]=true
  end
 elseif reason=="group" or reason=="available" then
  wipe(self.attempted)
 end
 self.dirty=true
 Refresh()
end

function R:Pump()
 if not self.active or self.pending or self.timer or InCombatLockdown() then return end
 if InspectFrame and InspectFrame:IsShown() then
  if self.inspectFrame~=InspectFrame then
   self.inspectFrame=InspectFrame
   InspectFrame:HookScript("OnHide",function() R:Pump() end)
  end
  return
 end
 local target
 for _,member in ipairs(self.members) do
  if not member.isSelf and member.guid and not member.specID and not self.attempted[member.guid]
   and G.Public(UnitGUID(member.unit))==member.guid and G.Public(CanInspect(member.unit)) then
   target=member;break
  end
 end
 if not target then return end
 local delay=math.max(self.libraryWaitUntil-GetTime(),lastInspect+INSPECT_INTERVAL-GetTime())
 if delay>0 then
  self.timer=C_Timer.NewTimer(delay,function() R.timer=nil;R:Pump() end)
  return
 end
 local request={unit=target.unit,guid=target.guid}
 self.pending=request;self.attempted[request.guid]=true;lastInspect=GetTime()
 self.timer=C_Timer.NewTimer(INSPECT_TIMEOUT,function()
  R.timer=nil;R.pending=nil;R:Pump()
 end)
 NotifyInspect(request.unit)
end

function R:OnInspectReady(guid)
 guid=G.Public(guid)
 if not guid then return end
 local related=self.pending and self.pending.guid==guid
 for _,member in ipairs(self.members) do
  if member.guid==guid and G.Public(UnitGUID(member.unit))==guid then
   related=true
   local specID=Positive(C_SpecializationInfo.GetInspectSpecialization(member.unit))
   self:GetUnitItemLevel(member.unit,guid,false)
   if specID then
    local cached=self.inspected[guid] or {};self.inspected[guid]=cached;cached.specID=specID
    self.changed[guid]=nil
    G.History:OnSpecUpdate(member.nameKey,specID)
   end
   break
  end
 end
 if not related then return end
 if self.pending and self.pending.guid==guid then CancelTimer();self.pending=nil end
 self:Invalidate()
end

-- 其他业务读取已持有的快照，不刷新花名册、不启动检视或通信。
function R:GetCachedSpec(guid)
 local spec=Positive(self.librarySpecs[guid])
 if spec then return spec end
 if self.changed[guid] then return nil end
 local cached=self.inspected[guid]
 return cached and Positive(cached.specID)
end

-- Read one unit from existing local/native caches; this never refreshes the
-- roster or starts communication/inspection work.
function R:GetUnitSpec(unit,guid,isSelf)
 if isSelf then
  local selected=C_SpecializationInfo.GetSpecialization()
  return Positive(selected and C_SpecializationInfo.GetSpecializationInfo(selected))
 end
 local spec=self.librarySpecs[guid]
 if not spec and not self.changed[guid] then
  local cached=self.inspected[guid]
  spec=Positive(C_SpecializationInfo.GetInspectSpecialization(unit)) or cached and cached.specID
 end
 return Positive(spec)
end

-- Read equipped item level from existing native data only. Item-level-only
-- responses share the current-GUID inspect cache; no new request is started.
function R:GetUnitItemLevel(unit,guid,isSelf)
 if isSelf then return Positive(select(2,GetAverageItemLevel())) end
 local level=Positive(C_PaperDollInfo.GetInspectItemLevel(unit))
 local cached=guid and self.inspected[guid]
 if level and guid then
  if not cached then cached={};self.inspected[guid]=cached end
  cached.itemLevel=level
 end
 return level or cached and Positive(cached.itemLevel)
end

function R:Get()
 if not self.dirty then
  if self.relationsVersion~=nil then
   local version=G.Relations:GetVersion()
   if self.relationsVersion~=version then
    for _,member in ipairs(self.members) do G.Relations:Apply(member) end
    self.relationsVersion=version
   end
  end
  return self.members
 end
 local index,seen,needsRelations=0,{},false
 EachUnit(function(unit,raidIndex)
  local key,name,realm=A:UnitIdentity(unit)
  if not key then return end
  index=index+1
  local member=self.members[index] or {};self.members[index]=member
  member.unit,member.name,member.realm,member.nameKey=unit,name,realm,key
  member.subgroup=raidIndex and G.Public(select(3,GetRaidRosterInfo(raidIndex))) or 1
  local guid=G.Public(UnitGUID(unit));member.guid=guid
  if guid then seen[guid]=true end
  member.class=G.Public(UnitClassBase(unit))
  local faction=G.Public(UnitFactionGroup(unit))
  member.factionGroup=faction and PLAYER_FACTION_GROUP[faction] or nil
  member.assignedRole=G.Public(UnitGroupRolesAssigned(unit))
  member.isLeader=G.Public(UnitIsGroupLeader(unit))==true
  member.isSelf=G.Public(UnitIsUnit(unit,"player"))==true
  if not member.isSelf then needsRelations=true end
  member.itemLevel=self:GetUnitItemLevel(unit,guid,member.isSelf)
  member.specID=self:GetUnitSpec(unit,guid,member.isSelf)
  if member.specID and (not member.assignedRole or member.assignedRole=="NONE") then member.assignedRole=select(5,GetSpecializationInfoByID(member.specID)) end
  local summary=G.Public(C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit))
  member.dungeonScore=summary and G.Public(summary.currentSeasonScore)
  G.Relations:Apply(member)
 end)
 for i=#self.members,index+1,-1 do self.members[i]=nil end
 Prune(seen)
 self.dirty=false
 -- Self has no relationship badges. Avoid building a complete friend/guild
 -- index for an empty or solo roster; membership changes rebuild this decision.
 self.relationsVersion=needsRelations and G.Relations:GetVersion() or nil
 self:Pump()
 return self.members
end

function R:GetRaidBuffs(activityID)
 local report=A.RaidBuffs.Get(G.Catalog,activityID,self:Get(),self.buffReport)
 if report then self.buffReport=report end
 return report
end
