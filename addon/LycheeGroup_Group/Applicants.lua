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
-- 原生状态同步读取；只把事件触发的展示通知合并到下一次调度。
local function NotifyChanged(immediate)
 if immediate then
  if notifyTimer then notifyTimer:Cancel();notifyTimer=nil end
  G:Notify("applicants")
 elseif not notifyTimer then
  notifyTimer=C_Timer.NewTimer(0,function() notifyTimer=nil;G:Notify("applicants") end)
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
local function Read(id,activityID)
 local info=G.Public(C_LFGList.GetApplicantInfo(id))
 if type(info)~="table" then return nil end
 local status,pending=G.Public(info.applicationStatus),G.Public(info.pendingApplicationStatus)
 if status=="applied" or (status==nil or status=="none") and pending=="applied" then retired[id]=nil
 elseif retired[id] then return nil end
 local record=records[id]
 local isNew=record==nil
 if not record then record={id=id,members={}};records[id]=record end
 if record.status~=status or record.pendingStatus~=pending then record.acting=nil end
 record.status,record.pendingStatus=status,pending
 if finished[status] then record.removeAt=record.removeAt or GetTime()+5 else record.removeAt=nil end
 record.numMembers=G.Public(info.numMembers) or 0
 record.comment=G.Public(info.comment)
 record.isNew=G.Public(info.isNew)==true
 record.displayOrderID=G.Public(info.displayOrderID) or 0
 local activity=G.Catalog:GetActivity(activityID)
 local pvp=activity and (activity.isPvpActivity or activity.isRatedPvpActivity)
 record.activityID=activityID
 for i=1,record.numMembers do
  local name,class,localizedClass,level,itemLevel,honorLevel,tank,healer,damage,role,relationship,score,pvpItemLevel,factionGroup,raceID,specID,isLeaver=C_LFGList.GetApplicantMemberInfo(id,i)
  local member=record.members[i] or {};record.members[i]=member
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
  local requested=member.requestedRoles or {};member.requestedRoles=requested
  requested.TANK,requested.HEALER,requested.DAMAGER=G.Public(tank)==true,G.Public(healer)==true,G.Public(damage)==true
  member.isLeaver=G.Public(isLeaver)==true
 end
 for i=#record.members,record.numMembers+1,-1 do record.members[i]=nil end
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
   record.generation=generation
   if isNew and record.status=="applied" then newBatch=true end
  end
 end
 for id,record in pairs(records) do if record.generation~=generation then records[id]=nil;dirty=true end end
 for id,seen in pairs(retired) do if seen~=generation then retired[id]=nil end end
 ScheduleRetirement()
 if newBatch and not silent then G.Alerts:NewApplicants() end
 NotifyChanged(immediate)
end
function Applicants:OnApplicantUpdated(id)
 local listing=G.Listing:GetListing()
 local record,isNew=Read(id,listing and listing.activityID)
 if not record then records[id]=nil;dirty=true
 elseif isNew and record.status=="applied" then G.Alerts:NewApplicants() end
 ScheduleRetirement()
 NotifyChanged()
end
function Applicants:OnEntryUpdate(created)
 if not C_LFGList.HasActiveEntryInfo() then self:Clear()
 else
  local listing=G.Listing:GetListing()
  if created or listing and listing.activityID~=currentActivityID then self:RefreshList() end
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
 wipe(records);wipe(ordered);wipe(retired);ScheduleRetirement()
 currentActivityID=nil;dirty=false;G.Alerts:Stop();NotifyChanged(true)
end
local function Act(id,decline)
 local allowed,reason=G:CanManageApplicants()
 if not allowed then return false,reason end
 local record=records[id]
 if not record or record.status~="applied" then return false,L.invalidAction end
 if record.acting or record.pendingStatus then return false,L.actionBusy end
 record.acting=true
 local ok=pcall(decline and C_LFGList.DeclineApplicant or C_LFGList.InviteApplicant,id)
 if not ok then record.acting=nil;return false,decline and L.declineApplicantFailed or L.inviteFailed end
 NotifyChanged(true)
 return true
end
function Applicants:Invite(id) return Act(id,false) end
function Applicants:Decline(id) return Act(id,true) end
function Applicants:GetApplicants()
 if dirty then
  wipe(ordered);for id in pairs(records) do ordered[#ordered+1]=id end
  table.sort(ordered,Sort);dirty=false
 end
 return ordered
end
function Applicants:GetApplicant(id) return records[id] end
function Applicants:GetCount()
 local total=0
 for _,record in pairs(records) do if record.status=="applied" and not record.pendingStatus then total=total+1 end end
 return total
end
