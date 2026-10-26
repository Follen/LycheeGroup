-- 当前招募的申请组；成员原地更新，排序数组和动作状态共用记录。
local A = _G.LycheeGroup
local G,L = A.Group,A.GroupLocale
local Applicants={}
G.Applicants=Applicants
local records,ordered={},{}
-- Maintain the actionable count with record mutations; visual/audio sync is O(1).
local alertWaiting=0
local function TrackAlert(record)
 local waiting=record.status=="applied" and not record.pendingStatus and not record.acting or false
 if waiting~=(record.alertWaiting or false) then
  alertWaiting=alertWaiting+(waiting and 1 or -1);record.alertWaiting=waiting or nil
 end
end
local function ForgetAlert(record)
 if not record then return end
 if record.alertWaiting then alertWaiting=alertWaiting-1;record.alertWaiting=nil end
end
local generation,dirty=0,true
local currentActivityID
local retired={}
local retirementTimer,retirementAt
local confirmation
local confirmationPopup="LYCHEEGROUP_INVITING_CONVERT_TO_RAID"
local function ClearConfirmation(hide)
 local previous=confirmation
 confirmation=nil
 if previous and hide then StaticPopup_Hide(confirmationPopup) end
end
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
  G.Alerts:Sync();G:Notify("applicants")
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
   if record.removeAt and record.removeAt<=now then ForgetAlert(record);records[id]=nil;retired[id]=generation;changed=true end
  end
  if changed then wipe(ordered);dirty=true end
  ScheduleRetirement()
  if changed then NotifyChanged(true) end
 end)
end
local function Read(id,activityID)
 local info=G.Public(C_LFGList.GetApplicantInfo(id))
 if type(info)~="table" then return nil end
 local status,pending=G.Public(info.applicationStatus),G.Public(info.pendingApplicationStatus)
 if status=="applied" or (status==nil or status=="none") and pending=="applied" then retired[id]=nil
 elseif retired[id] then return nil end
 local record=records[id]
 if not record then record={id=id,members={}};records[id]=record end
 -- Initial data can arrive before the actual applied state. A batch is new
 -- once, when it first becomes a complete pending application.
 local isNew=status=="applied" and not pending and not record.alertSeen
 if status=="applied" and not pending then record.alertSeen=true end
 if record.status~=status or record.pendingStatus~=pending then record.acting=nil;record.inviteSize=nil end
 record.status,record.pendingStatus=status,pending
 TrackAlert(record)
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
 return record,isNew
end
local function Sort(a,b)
 local x,y=records[a],records[b]
 if x.displayOrderID~=y.displayOrderID then return x.displayOrderID<y.displayOrderID end
 return a<b
end
function Applicants:RefreshList(silent,immediate)
 if not C_LFGList.HasActiveEntryInfo() then self:Clear();return end
 local listing=G.Listing:GetListing()
 currentActivityID=listing and listing.activityID
 generation=generation+1
 local newBatch=false
 for _,id in ipairs(C_LFGList.GetApplicants() or {}) do
  if retired[id] then retired[id]=generation end
  local record,isNew=Read(id,currentActivityID)
  if record then
   record.generation=generation;record.listed=true
   if isNew and not silent then newBatch=true end
  end
 end
 for id,record in pairs(records) do
  if record.generation~=generation then
   -- An item event can precede its first appearance in GetApplicants. Keep
   -- that still-active record so the later list cannot reset alertSeen.
   local info=not record.listed and G.Public(C_LFGList.GetApplicantInfo(id))
   local arriving=type(info)=="table" and (G.Public(info.applicationStatus)=="applied" or G.Public(info.pendingApplicationStatus)=="applied")
   if not arriving then ForgetAlert(record);records[id]=nil;dirty=true end
  end
 end
 for id,seen in pairs(retired) do if seen~=generation then retired[id]=nil end end
 ScheduleRetirement()
 self:TryAutoInvite()
 G.Alerts:Update(newBatch and not silent)
 NotifyChanged(immediate)
end
function Applicants:OnApplicantUpdated(id)
 local listing=G.Listing:GetListing()
 local record,isNew=Read(id,listing and listing.activityID)
 if not record then ForgetAlert(records[id]);records[id]=nil;dirty=true end
 ScheduleRetirement()
 self:TryAutoInvite()
 G.Alerts:Update(isNew)
 NotifyChanged()
end
function Applicants:OnEntryUpdate(created)
 if confirmation then
  local listing=G.Listing:GetListing()
  if created or not listing or listing.activityID~=confirmation.activityID then ClearConfirmation(true) end
 end
 if not C_LFGList.HasActiveEntryInfo() then self:Clear()
 else
  local listing=G.Listing:GetListing()
  if created or listing and listing.activityID~=currentActivityID then self:RefreshList() else self:TryAutoInvite() end
 end
end
function Applicants:Restore() if C_LFGList.HasActiveEntryInfo() then self:RefreshList(true,true) end end
function Applicants:RequestRefresh()
 if not C_LFGList.HasActiveEntryInfo() then self:Clear();return false end
 C_LFGList.RefreshApplicants()
 self:RefreshList(true,true)
 return true
end
function Applicants:Clear()
 if self.autoInviting then self.autoInviteDirty=true end
 ClearConfirmation(true)
 wipe(records);wipe(ordered);wipe(retired);ScheduleRetirement()
 alertWaiting=0
 currentActivityID=nil;dirty=false;G.Alerts:Stop();NotifyChanged(true)
end
local function Finite(value)
 return type(value)=="number" and value==value and value>-math.huge and value<math.huge
end
-- One capacity snapshot per synchronous batch. A native business event can
-- invalidate it; manual actions and confirmed actions always read a fresh one.
local function Capacity()
 if not C_LFGList.HasActiveEntryInfo() then return nil,L.noActiveListing end
 local listing=G.Listing:GetListing()
 if not listing then return nil,L.noActiveListing end
 local native=G.Public(C_LFGList.GetActiveEntryInfo())
 local ids=type(native)=="table" and G.Public(native.activityIDs)
 local activityID=type(ids)=="table" and G.Public(ids[1])
 if not activityID or activityID~=listing.activityID then return nil,L.invalidActivity end
 local activity=G.Catalog:GetActivity(activityID)
 local maximum=activity and G.Public(activity.maxNumPlayers)
 if not Finite(maximum) or maximum<0 or maximum%1~=0 then return nil,L.invalidActivity end
 if maximum==0 then maximum=activity.categoryID==9 and CONQUEST_SIZES[5] or MAX_RAID_MEMBERS end
 maximum=math.min(maximum,MAX_RAID_MEMBERS)
 local count=math.max(1,GetNumGroupMembers(LE_PARTY_CATEGORY_HOME))+C_LFGList.GetNumInvitedApplicantMembers()
 for _,other in pairs(records) do if other.acting=="invite" then count=count+(other.inviteSize or other.numMembers) end end
 return {listing=listing,activityID=activityID,maximum=maximum,count=count}
end
local function Validate(id,decline,capacity)
 local allowed,reason=G:CanManageApplicants()
 if not allowed then return nil,reason end
 local record=records[id]
 if not record or record.status~="applied" then return nil,L.invalidAction end
 if record.acting or record.pendingStatus then return nil,L.actionBusy end
 if decline then return record end
 if not capacity then capacity,reason=Capacity() end
 if not capacity then return nil,reason end
 local info=G.Public(C_LFGList.GetApplicantInfo(id))
 if type(info)~="table" or G.Public(info.applicationStatus)~="applied" then return nil,L.invalidAction end
 if G.Public(info.pendingApplicationStatus) then return nil,L.actionBusy end
 local size=G.Public(info.numMembers)
 if not Finite(size) or size<1 or size%1~=0 then return nil,L.invalidAction end
 if capacity.count+size>capacity.maximum then return nil,L.groupFull end
 local convert=capacity.count+size>(MAX_PARTY_MEMBERS or 4)+1 and not IsInRaid(LE_PARTY_CATEGORY_HOME)
 return record,nil,convert,capacity.activityID,size
end
local function InviteNative(id,convertToRaid)
 if convertToRaid then C_PartyInfo.ConfirmConvertToRaid() end
 C_LFGList.InviteApplicant(id)
end
local function Act(id,decline,automatic,confirmed,capacity)
 local record,reason,convertToRaid,activityID,size=Validate(id,decline,capacity)
 if not record then return false,reason end
 if confirmation and confirmation.record==record then return false,L.actionBusy end
 if not decline and convertToRaid and not automatic and not confirmed then
  ClearConfirmation(true)
  local token={id=id,record=record,activityID=activityID}
  confirmation=token
  StaticPopupDialogs[confirmationPopup]={
   text=LFG_LIST_CONVERT_TO_RAID_WARNING,button1=INVITE,button2=CANCEL,
   timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
   OnAccept=function(_,data)
    if confirmation~=data then return end
    ClearConfirmation(false)
    local listing=G.Listing:GetListing()
    if records[data.id]~=data.record or not listing or listing.activityID~=data.activityID then return end
    local ok,err=Act(data.id,false,false,true)
    if ok==false then A:Print(err);NotifyChanged(true) end
   end,
   OnCancel=function(_,data) if confirmation==data then ClearConfirmation(false);NotifyChanged(true) end end,
   OnHide=function(frame) if confirmation==frame.data then ClearConfirmation(false);NotifyChanged(true) end end,
  }
  if not StaticPopup_Show(confirmationPopup,nil,nil,token) then ClearConfirmation(false);return false,L.inviteFailed end
  -- An opened confirmation has not submitted an invitation yet.
  return nil,nil
 end
 if automatic and not GetCVarBool("profanityFilter") then ConsoleExec("profanityFilter 1") end
 record.inviteSize=not decline and size or nil
 record.acting=decline and "decline" or "invite"
 TrackAlert(record)
 local ok=pcall(decline and C_LFGList.DeclineApplicant or InviteNative,id,convertToRaid)
 if not ok then
  record.acting=nil;record.inviteSize=nil
  if records[id]==record then
   TrackAlert(record)
   G.Alerts:Sync()
  end
  return false,decline and L.declineApplicantFailed or L.inviteFailed
 end
 NotifyChanged(not Applicants.autoInviting)
 return true,nil,size
end
function Applicants:Invite(id)
 local ok,reason=Act(id,false)
 return ok,reason
end
function Applicants:Decline(id) return Act(id,true) end
-- Explicit auto invitation uses the same latest capacity and reservation checks.
function Applicants:TryAutoInvite()
 if self.autoInviting then self.autoInviteDirty=true;return end
 local listing=G.Listing:GetListing()
 if not listing or listing.autoInvite~=true or listing.autoAccept~=false or not G:CanManageListing() then return end
 local capacity=Capacity()
 if not capacity or capacity.count>=capacity.maximum then return end
 self.autoInviting=true
 for _,id in ipairs(self:GetApplicants()) do
  listing=G.Listing:GetListing()
  if not listing or listing.autoInvite~=true or listing.autoAccept~=false or not G:CanManageListing() or not C_LFGList.HasActiveEntryInfo() then break end
  -- Synchronous native events may alter capacity, activity, or local actions.
  -- Never carry the old batch snapshot across those changes.
  if self.autoInviteDirty or listing~=capacity.listing then
   self.autoInviteDirty=nil;capacity=Capacity()
  end
  if not capacity or capacity.count>=capacity.maximum then break end
  local record=records[id]
  if record and record.status=="applied" and not record.pendingStatus and not record.acting then
   local ok,_,size=Act(id,false,true,false,capacity)
   if ok then capacity.count=capacity.count+size end
  end
 end
 self.autoInviting=nil;self.autoInviteDirty=nil
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
function Applicants:HasWaitingApplicants()
 return alertWaiting>0
end
