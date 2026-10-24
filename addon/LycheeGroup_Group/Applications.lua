-- 已提交申请由原生事件推进；关窗不取消申请或自动进组。
local A = _G.LycheeGroup
local G,L = A.Group,A.GroupLocale
local Applications={}
G.Applications=Applications
local records,ordered={},{}
local sequence,generation=0,0
local dirty=true
local accepting,joined
local retired={}
local function PruneRetired()
 if not next(retired) then return end
 local present={}
 for _,id in ipairs(C_LFGList.GetApplications() or {}) do present[id]=true end
 for id in pairs(retired) do if not present[id] then retired[id]=nil end end
end
-- Rejection belongs to the party, not a search result ID or title ticket.
-- Keep only its timestamp for this session after the application retires.
local declinedParties={}
local retirementTimer,retirementAt
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
  if changed then G.Results:InvalidateView();G:Notify("applications") end
 end)
end
local function Active(record)
 local status,pending=record.status,record.pendingStatus
 if pending and pending~="applied" and pending~="invited" then return false end
 return status=="applied" or status=="invited" or (status==nil or status=="none") and (pending=="applied" or pending=="invited")
end
local function Sort(a,b)
 if (a.status=="invited")~=(b.status=="invited") then return a.status=="invited" end
 return a.seq<b.seq
end
local function AdoptResult(record,result)
 record.result=result;record.categoryID=result.categoryID
 record.partyGUID=result.partyGUID or record.partyGUID
 record.name=result.name;record.leaderName=result.leaderName;record.activityName=result.activityName
 record.activityArt=result.activity and result.activity.journalID and select(6,EJ_GetInstanceInfo(result.activity.journalID))
 local activity=result.activity
 record.activityLabel=activity and activity.groupID and activity.groupID>0 and C_LFGList.GetActivityGroupInfo(activity.groupID) or result.activityName
 record.activityDetail=activity and activity.difficultyID and activity.difficultyID>0 and GetDifficultyInfo(activity.difficultyID) or ""
 record.leaderClass=nil
 for _,member in ipairs(G.Results:GetDetails(result).members) do if member.isLeader then record.leaderClass=member.class;break end end
end
-- Adopt an already-read result without changing application status or join state.
function Applications:AdoptResult(id,result)
 local record=records[id]
 if not record or not Active(record) then return false end
 AdoptResult(record,result)
 return true
end
local function Update(id,status,pending,remaining,groupName,statusOnly)
 if status=="applied" or (status==nil or status=="none") and pending=="applied" then retired[id]=nil
 elseif retired[id] then return nil end
 local record=records[id]
 if not record then sequence=sequence+1;record={id=id,seq=sequence};records[id]=record end
 local cancelled=status=="cancelled" and record.status~="cancelled"
 local declined=status=="declined" and record.status~="declined"
 local wasApplying=record.status=="applied" or record.pendingStatus=="applied"
 -- Native and other UI submissions must start a new round too. Refreshing an
 -- existing application must keep the latch that protects the previous join.
 if (status=="applied" or pending=="applied") and not wasApplying then joined=nil;record.partyGUID=nil end
 if record.status~=status then record.autoAttempted=nil end
 record.status,record.pendingStatus=status,pending
 if finished[status] then record.removeAt=record.removeAt or GetTime()+5 else record.removeAt=nil end
 if type(remaining)=="number" then record.expiresAt=GetTime()+remaining end
 local result=not statusOnly and Active(record) and (G.Results:GetResult(id) or G.Results:Capture(id,record.result,true) or record.result)
 if result then AdoptResult(record,result) end
 if declined then
  local partyGUID=record.partyGUID
  if not partyGUID then
   local cached=G.Results:GetResult(id)
   partyGUID=cached and cached.partyGUID
   if not partyGUID then
    local info=G.Public(C_LFGList.GetSearchResultInfo(id))
    partyGUID=type(info)=="table" and G.Public(info.partyGUID) or nil
   end
  end
  if partyGUID and (wasApplying or not declinedParties[partyGUID]) then declinedParties[partyGUID]=GetTime() end
 end
 if groupName and groupName~="" then record.name=groupName end
 dirty=true
 if cancelled then G:Notify("applicationCancelled",id) end
 return record
end
function Applications:SyncAll()
 generation=generation+1
 for _,id in ipairs(C_LFGList.GetApplications() or {}) do
  if retired[id] then retired[id]=generation end
  local infoID,status,pending,remaining=C_LFGList.GetApplicationInfo(id)
  if infoID then local record=Update(infoID,status,pending,remaining);if record then record.generation=generation end end
 end
 for id,record in pairs(records) do
  if record.generation~=generation then records[id]=nil;dirty=true end
 end
 for id,seen in pairs(retired) do if seen~=generation then retired[id]=nil end end
 ScheduleRetirement()
 G.Game:RefreshApplicationSubscriptions()
end
function Applications:Apply(id,roles)
 if C_LFGList.HasActiveEntryInfo() then return false,L.recruiting end
 local record=records[id]
 if record and Active(record) then return false,L.alreadyApplied end
 if self:GetActiveCount()>=5 then return false,L.applicationLimit end
 local _,status,pending=C_LFGList.GetApplicationInfo(id)
 if pending=="cancelled" then return false,L.actionBusy end
 if status=="cancelled" then return false,L.applicationCancelled end
 local ok=pcall(C_LFGList.ApplyToGroup,id,roles.tank==true,roles.healer==true,roles.damage==true)
 if not ok then return false,L.applyFailed end
 self:SyncAll()
 G:Notify("applications")
 return true
end
function Applications:CanCancel(id)
 local record=records[id]
 if not record then return false,L.invalidAction end
 if record.pendingStatus then return false,L.actionBusy end
 if record.status~="applied" then return false,L.invalidAction end
 return true
end
function Applications:Cancel(id)
 -- An explicit action rechecks its one native record. Routine CanCancel calls
 -- remain cache-only, and a stale local pending flag never overrides a newer
 -- native confirmation or permits cancelling a genuinely pending request.
 local record=records[id]
 if not record then return false,L.invalidAction end
 local infoID,status,pending,remaining=C_LFGList.GetApplicationInfo(id)
 local changed=false
 if infoID==id and status~=nil then
  if status=="none" and not pending then
   records[id]=nil;dirty=true;changed=true
  elseif status~=record.status or pending~=record.pendingStatus then
   Update(id,status,pending,remaining,nil,true);changed=true
  end
 elseif not infoID and not pending then
  records[id]=nil;dirty=true;changed=true
 else
  return false,L.invalidAction
 end
 if changed then
  wipe(ordered);ScheduleRetirement()
  G.Game:RefreshApplicationSubscriptions()
  G.Results:InvalidateView();G:Notify("applications")
 end
 local allowed,reason=self:CanCancel(id)
 if not allowed then return false,reason end
 local ok=pcall(C_LFGList.CancelApplication,id)
 if not ok then return false,L.cancelFailed end
 self:SyncAll();self:ReleaseFinished()
 G.Results:InvalidateView();G:Notify("applications")
 return true
end
function Applications:AcceptInvite(id)
 local record=records[id]
 if not record or record.status~="invited" or record.pendingStatus then return false,L.invalidAction end
 if accepting then return false,L.actionBusy end
 accepting=id
 local ok=pcall(C_LFGList.AcceptInvite,id)
 if not ok then accepting=nil end
 return ok,not ok and L.acceptFailed or nil
end
function Applications:DeclineInvite(id)
 local record=records[id]
 if not record or record.status~="invited" or record.pendingStatus then return false,L.invalidAction end
 local ok=pcall(C_LFGList.DeclineInvite,id)
 return ok,not ok and L.declineFailed or nil
end
function Applications:TryAutoJoin()
 if not A:GetSetting("autoJoin") or accepting or joined or C_LFGList.HasActiveEntryInfo() then return end
 if IsInGroup(LE_PARTY_CATEGORY_HOME) and not UnitIsGroupLeader("player",LE_PARTY_CATEGORY_HOME) then return end
 for _,record in ipairs(self:GetApplications()) do
  if record.status=="invited" and not record.pendingStatus and not record.autoAttempted then
   record.autoAttempted=true
   local ok,err=self:AcceptInvite(record.id)
   if not ok then A:Print(err) end
   return
  end
 end
end
function Applications:OnStatusUpdated(id,status,oldStatus,groupName)
 local infoID,nativeStatus,pending,remaining=C_LFGList.GetApplicationInfo(id)
 if not records[id] and (not infoID or nativeStatus=="none" and not pending) then
  PruneRetired()
  return
 end
 Update(id,status,infoID and pending or nil,infoID and remaining or nil,groupName)
 if accepting==id and status~="invited" then
  accepting=nil
  if status=="inviteaccepted" or status=="invitedaccepted" then joined=true end
 end
 self:TryAutoJoin()
 G.Game:RefreshApplicationSubscriptions()
 G.Results:InvalidateView();G:Notify("applications");self:ReleaseFinished()
 PruneRetired()
end
function Applications:Restore()
 self:SyncAll();self:TryAutoJoin();self:ReleaseFinished();G:Notify("applications")
end
function Applications:GetApplications()
 if dirty then
  wipe(ordered);for _,record in pairs(records) do ordered[#ordered+1]=record end
  table.sort(ordered,Sort);dirty=false
 end
 return ordered
end
function Applications:GetApplication(id) return records[id] end
function Applications:GetDeclinedAt(partyGUID) return declinedParties[partyGUID] end
function Applications:IsActive(id) local record=records[id];return record and Active(record) or false end
function Applications:GetActiveCount()
 local count=0
 for _,record in pairs(records) do if Active(record) then count=count+1 end end
 return count
end
function Applications:ReleaseFinished()
 if not G:HasViews("search") then
  for id,record in pairs(records) do
   if not Active(record) then
    records[id]=nil;dirty=true
    if finished[record.status] then retired[id]=generation end
   end
  end
  if dirty then wipe(ordered) end
 end
 ScheduleRetirement()
end
