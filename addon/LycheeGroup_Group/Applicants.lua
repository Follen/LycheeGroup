-- 当前招募的申请组；成员原地更新，排序数组和动作状态共用记录。
local A = _G.LycheeGroup
local G,L = A.Group,A.GroupLocale
local Applicants={}
G.Applicants=Applicants
local records,ordered={},{}
local generation,dirty=0,true
local currentActivityID
local retired={}
local retirementTimer,retirementAt
local notifyTimer
local races={}
-- Race names and native race factions are static client data. Keep successful
-- metadata only; neutral members still use their latest applicant faction.
local function Race(raceID)
 if not raceID then return end
 local cached=races[raceID]
 if cached then return cached.name,cached.faction end
 local race=C_CreatureInfo.GetRaceInfo(raceID)
 local faction=C_CreatureInfo.GetFactionInfo(raceID)
 local name=race and G.Public(race.raceName)
 local tag=faction and G.Public(faction.groupTag)
 local group=tag and PLAYER_FACTION_GROUP[tag]
 if type(name)=="string" and name~="" and (group~=nil or tag=="Neutral") then
  races[raceID]={name=name,faction=group}
 end
 return name,group
end
-- 原生状态同步读取；下一次调度合并展示，并在原生事件回调结束后同步提醒。
local function NotifyChanged(immediate)
 if immediate then
  if notifyTimer then notifyTimer:Cancel();notifyTimer=nil end
  G:Notify("applicants")
 elseif not notifyTimer then
  notifyTimer=C_Timer.NewTimer(0,function() notifyTimer=nil;G.Alerts:Sync();G:Notify("applicants") end)
 end
end
local finished={failed=true,cancelled=true,declined=true,declined_full=true,declined_delisted=true,invitedeclined=true,timedout=true,expired=true,inviteaccepted=true,invitedaccepted=true}
local function ScheduleRetirement()
 local nearest
 for _,record in pairs(records) do if record.removeAt and (not nearest or record.removeAt<nearest) then nearest=record.removeAt end end
 if nearest==retirementAt then return end
 if retirementTimer then retirementTimer:Cancel();retirementTimer=nil end
 retirementAt=nearest
 if not nearest then return end
 retirementTimer=C_Timer.NewTimer(math.max(0,nearest-GetTime()),function()
  retirementTimer,retirementAt=nil,nil
  local now,changed=GetTime(),false
  for id,record in pairs(records) do
   if record.removeAt and record.removeAt<=now then records[id]=nil;retired[id]=generation;changed=true end
  end
  if changed then wipe(ordered);dirty=true end
  ScheduleRetirement()
  if changed then NotifyChanged(true) end
 end)
end
local function Read(id,activityID,arrival)
 local ok,info=pcall(C_LFGList.GetApplicantInfo,id)
 info=ok and G.Public(info) or nil
 if type(info)~="table" then
  if arrival then G.Alerts:OnApplicant(id) end
  return nil
 end
 local status,pending=G.Public(info.applicationStatus),G.Public(info.pendingApplicationStatus)
 if status=="applied" or (status==nil or status=="none") and pending=="applied" then retired[id]=nil
 elseif retired[id] then
  if arrival then G.Alerts:OnApplicant(id,status) end
  return nil
 end
 local record=records[id]
 if not record then record={id=id,members={}};records[id]=record end
 if record.status~=status or record.pendingStatus~=pending then record.acting=nil end
 record.status,record.pendingStatus=status,pending
 -- Arrival admission only needs the public status. Member details below may
 -- be temporarily unavailable and must not postpone or replay this alert.
 if arrival then G.Alerts:OnApplicant(id,status) end
 if finished[status] then record.removeAt=record.removeAt or GetTime()+5 else record.removeAt=nil end
 record.numMembers=G.Public(info.numMembers) or 0
 record.comment=G.Public(info.comment)
 record.displayOrderID=G.Public(info.displayOrderID) or 0
 local activity=G.Catalog:GetActivity(activityID)
 local pvp=activity and (activity.isPvpActivity or activity.isRatedPvpActivity)
 record.activityID=activityID
 for i=1,record.numMembers do
  local name,class,localizedClass,level,itemLevel,honorLevel,tank,healer,damage,role,relationship,score,pvpItemLevel,factionGroup,raceID,specID,isLeaver=C_LFGList.GetApplicantMemberInfo(id,i)
  local member=record.members[i] or {};record.members[i]=member
  member.applicantID,member.applicantIndex=id,i
  member.dungeonScores=nil
  member.name=G.Public(name);member.nameKey=G:RemotePlayerKey(member.name)
  member.class,member.localizedClass=G.Public(class),G.Public(localizedClass)
  member.dungeonScore,member.pvpItemLevel=G.Public(score),G.Public(pvpItemLevel)
  member.ratingKind=pvp and "pvp" or "dungeon"
  member.pvpRatingInfo=nil
  if pvp then
   member.itemLevel,member.rating=member.pvpItemLevel,nil
   if activity.isRatedPvpActivity then
    local rating=G.Public(C_LFGList.GetApplicantPvpRatingInfoForListing(id,i,activityID))
    if type(rating)=="table" then
     rating.bracket,rating.rating,rating.activityName,rating.tier=G.Public(rating.bracket),G.Public(rating.rating),G.Public(rating.activityName),G.Public(rating.tier)
     member.pvpRatingInfo,member.rating=rating,rating.rating
    end
   end
  else member.itemLevel,member.rating=G.Public(itemLevel),member.dungeonScore end
  member.assignedRole,member.specID,member.relationship=G.Public(role),G.Public(specID),G.Public(relationship)
  member.raceID=G.Public(raceID)
  local raceName,raceFaction=Race(member.raceID)
  member.raceName=raceName
  member.factionGroup=raceFaction or G.Public(factionGroup)
  local requested=member.requestedRoles or {};member.requestedRoles=requested
  requested.TANK,requested.HEALER,requested.DAMAGER=G.Public(tank)==true,G.Public(healer)==true,G.Public(damage)==true
  member.isLeaver=G.Public(isLeaver)==true
 end
 for i=#record.members,record.numMembers+1,-1 do record.members[i]=nil end
 record.relationsVersion=G.Relations:ApplyMembers(record.members)
 dirty=true
 return record
end
local function Sort(a,b)
 local x,y=records[a],records[b]
 if x.displayOrderID~=y.displayOrderID then return x.displayOrderID<y.displayOrderID end
 return a<b
end
function Applicants:RefreshList(silent,immediate)
 local ok,active=pcall(C_LFGList.HasActiveEntryInfo)
 if ok and G.Public(active)==false then self:Clear();return end
 if silent then G.Alerts:Baseline() end
 if not G.Alerts:Sync() then return end
 local listOK,ids=pcall(C_LFGList.GetApplicants)
 ids=listOK and G.Public(ids)
 if type(ids)~="table" then return end
 local listing=G.Listing:GetListing()
 currentActivityID=listing and listing.activityID
 generation=generation+1
 for _,id in ipairs(ids) do
  id=G.Public(id)
  if type(id)=="number" or type(id)=="string" then
  if retired[id] then retired[id]=generation end
  local record=Read(id,currentActivityID)
  if record then
   record.generation=generation
  end
  end
 end
 for id,record in pairs(records) do if record.generation~=generation then records[id]=nil;dirty=true end end
 for id,seen in pairs(retired) do if seen~=generation then retired[id]=nil end end
 ScheduleRetirement()
 self:TryAutoInvite()
 G.Alerts:Sync()
 NotifyChanged(immediate)
end
function Applicants:OnApplicantUpdated(id)
 local ok,active=pcall(C_LFGList.HasActiveEntryInfo)
 if ok and G.Public(active)==false then self:Clear();return end
 if not G.Alerts:Sync() then return end
 id=G.Public(id)
 if id==nil then G.Alerts:OnApplicant();self:RefreshList();return end
 if type(id)~="number" and type(id)~="string" then return end
 local listing=G.Listing:GetListing()
 local record=Read(id,listing and listing.activityID,true)
 if not record then records[id]=nil;dirty=true end
 ScheduleRetirement()
 self:TryAutoInvite()
 NotifyChanged()
end
function Applicants:OnEntryUpdate(created)
 G.Alerts:Baseline(G.Public(created)==true)
 self:RefreshList()
end
function Applicants:Restore() self:RefreshList(true,true) end
function Applicants:RequestRefresh()
 if not G.Alerts:Sync() then return false end
 C_LFGList.RefreshApplicants()
 self:RefreshList(true,true)
 return true
end
function Applicants:Clear()
 wipe(records);wipe(ordered);wipe(retired);ScheduleRetirement()
 currentActivityID=nil;dirty=false;G.Alerts:Reset();NotifyChanged(true)
end
local function InviteNative(id,convertToRaid)
 if convertToRaid then C_PartyInfo.ConfirmConvertToRaid() end
 C_LFGList.InviteApplicant(id)
end
local function Act(id,decline,convertToRaid)
 local allowed,reason=G:CanManageApplicants()
 if not allowed then return false,reason end
 local record=records[id]
 if not record or record.status~="applied" then return false,L.invalidAction end
 if record.acting or record.pendingStatus then return false,L.actionBusy end
 record.acting=decline and "decline" or "invite"
 local ok=pcall(decline and C_LFGList.DeclineApplicant or InviteNative,id,convertToRaid)
 if not ok then record.acting=nil;return false,decline and L.declineApplicantFailed or L.inviteFailed end
 NotifyChanged(not Applicants.autoInviting)
 return true
end
function Applicants:Invite(id,convertToRaid) return Act(id,false,convertToRaid) end
function Applicants:Decline(id) return Act(id,true) end
-- Ordinary raids do not retain Blizzard's autoAccept flag. The listing's own
-- option also handles those applicants, using the same action/state path.
function Applicants:TryAutoInvite()
 local listing=G.Listing:GetListing()
 if self.autoInviting or not listing or listing.autoInvite~=true or listing.autoAccept~=false or not G:CanManageListing() then return end
 local activity=G.Catalog:GetActivity(listing.activityID)
 if not activity then return end
 local maximum=activity.maxNumPlayers
 if maximum==0 then maximum=activity.categoryID==9 and CONQUEST_SIZES[5] or MAX_RAID_MEMBERS end
 local count=math.max(1,GetNumGroupMembers(LE_PARTY_CATEGORY_HOME))+C_LFGList.GetNumInvitedApplicantMembers()
 -- Locally submitted invitations reserve space until a native state event.
 for _,record in pairs(records) do if record.acting=="invite" then count=count+record.numMembers end end
 if count>=maximum then return end
 if not GetCVarBool("profanityFilter") then ConsoleExec("profanityFilter 1") end
 self.autoInviting=true
 for _,id in ipairs(self:GetApplicants()) do
  local record=records[id]
  if record.status=="applied" and not record.pendingStatus and not record.acting and count+record.numMembers<=maximum then
   local convertToRaid=count+record.numMembers>MAX_PARTY_MEMBERS+1 and not IsInRaid(LE_PARTY_CATEGORY_HOME)
   if self:Invite(id,convertToRaid) then count=count+record.numMembers end
  end
 end
 self.autoInviting=nil
end
function Applicants:GetApplicants()
 if dirty then
  wipe(ordered);for id in pairs(records) do ordered[#ordered+1]=id end
  table.sort(ordered,Sort);dirty=false
 end
 return ordered
end
function Applicants:GetApplicant(id)
 local record=records[id]
 if record then
  local version=G.Relations:GetVersion()
  if record.relationsVersion~=version then
   record.relationsVersion=G.Relations:ApplyMembers(record.members)
  end
 end
 return record
end
-- Visible rows read the listing's map score; details reuse that snapshot and add the best run.
-- Applicant events invalidate the snapshot, including an unavailable native result.
local function DungeonRun(info,activityID)
 if type(info)~="table" then return nil end
 local level,name=G.Public(info.bestRunLevel),G.Public(info.mapName)
 if not level or level<=0 or not name or name=="" then return nil end
 local duration=G.Public(info.bestRunDurationMs)
 if type(duration)~="number" or duration<=0 or duration~=duration or duration==math.huge then duration=nil end
 return {activityID=activityID,name=name,level=level,timed=G.Public(info.finishedSuccess)==true,durationMs=duration}
end
-- Keep the latest successful listing-map and best-run-name lookups. The best
-- summary has no map ID, so only an exact native name with one limit is usable.
local limitMapID,limitSeconds,bestLimitName,bestLimitSeconds
local function ResolveTimeLimit(run)
 if not run or not run.durationMs or run.timeLimitSeconds then return end
 local activity=run.activityID and G.Catalog:GetActivity(run.activityID)
 local mapID=activity and G.Public(activity.mapID)
 if run.activityID then
  if type(mapID)~="number" or mapID<=0 then return end
  if limitMapID==mapID then run.timeLimitSeconds=limitSeconds;return end
 elseif bestLimitName==run.name then run.timeLimitSeconds=bestLimitSeconds;return end
 local found
 for _,challengeID in ipairs(G.Public(C_ChallengeMode.GetMapTable()) or {}) do
  local name,_,seconds,_,_,gameMapID=C_ChallengeMode.GetMapUIInfo(challengeID)
  name,seconds,gameMapID=G.Public(name),G.Public(seconds),G.Public(gameMapID)
  local matches=run.activityID and gameMapID==mapID or not run.activityID and name==run.name
  if matches and type(seconds)=="number" and seconds>0 and seconds<math.huge then
   if found and found~=seconds then return end
   found=seconds
   if run.activityID then break end
  end
 end
 if not found then return end
 run.timeLimitSeconds=found
 if run.activityID then limitMapID,limitSeconds=mapID,found
 else bestLimitName,bestLimitSeconds=run.name,found end
end
function Applicants:GetDungeonScores(member,currentOnly)
 local record=records[member.applicantID]
 if not record or record.members[member.applicantIndex]~=member then return nil end
 local activity=G.Catalog:GetActivity(record.activityID)
 if not activity or not activity.isMythicPlusActivity then return nil end
 local id,index=record.id,member.applicantIndex
 local scores=member.dungeonScores
 if not scores then
  local info=G.Public(C_LFGList.GetApplicantDungeonScoreForListing(id,index,record.activityID))
  scores={mapScore=type(info)=="table" and G.Public(info.mapScore) or nil,current=DungeonRun(info,record.activityID)}
  member.dungeonScores=scores
 end
 if not currentOnly and not scores.bestLoaded then
  scores.best=DungeonRun(G.Public(C_LFGList.GetApplicantBestDungeonScore(id,index)))
  scores.bestLoaded=true
 end
 if not currentOnly then ResolveTimeLimit(scores.current);ResolveTimeLimit(scores.best) end
 return scores
end
-- Missing limits retry only on the next explicit consumer request.
function Applicants:GetTimeMargin(member)
 local scores=self:GetDungeonScores(member,true)
 if not scores then return nil,"unknown" end
 local run=scores.current
 if not run then return nil,scores.mapScore==0 and "none" or "unknown" end
 if not run.timed or not run.durationMs then return nil,"unavailable",run end
 ResolveTimeLimit(run)
 if not run.timeLimitSeconds then return nil,"unknown",run end
 return run.timeLimitSeconds-run.durationMs/1000,"known",run
end
function Applicants:GetCount()
 local total=0
 for _,record in pairs(records) do if record.status=="applied" and not record.pendingStatus then total=total+1 end end
 return total
end
