-- Bounded observation of this addon's real voice calls and applicant arrival ordering.
local probe=...
local A=LycheeGroup
local G=assert(A and A.Group)
local alerts=G.Alerts
if type(alerts.Play)~="function" then return probe:Fail("playback_observer_entry_not_loaded") end
local play=alerts.Play
local env=getfenv(play)
local frame,timer,preview
local report={rule="new-arrivals-only-no-catch-up",started=GetTime(),choice=A:GetSetting("applicantAlertSound"),plays={},events={},listChecks={},newItems={},violations={}}
local function add(rows,row) if #rows<100 then rows[#rows+1]=row end end
local last
local scoped=setmetatable({PlaySoundFile=function(path,channel,...)
 local now=GetTimePreciseSec()
 local played,handle=env.PlaySoundFile(path,channel,...)
 local row={t=GetTime(),precise=now,path=path,channel=channel,played=played,handle=handle,preview=preview==true}
 if not preview and played then
  if last then row.interval=now-last;if row.interval<3 then add(report.violations,row.interval) end end
  last=now
 end
 add(report.plays,row)
 return played,handle
end},{__index=env,__newindex=env})
local oldList,oldItem=G.Applicants.RefreshList,G.Applicants.OnApplicantUpdated
assert(probe:Async(70))
assert(probe:OnCleanup(function()
 alerts.Play=play;setfenv(play,env)
 G.Applicants.RefreshList=oldList;G.Applicants.OnApplicantUpdated=oldItem
 if timer then timer:Cancel() end
 if frame then frame:UnregisterAllEvents();frame:SetScript("OnEvent",nil) end
end))
setfenv(play,scoped)
alerts.Play=function(self,isPreview,choice) preview=isPreview;local result=play(self,isPreview,choice);preview=nil;return result end
G.Applicants.RefreshList=function(self,...)
 local present={};for _,id in ipairs(C_LFGList.GetApplicants() or {}) do present[id]=true end
 local missing={};for _,id in ipairs(self:GetApplicants()) do local r=G:GetApplicant(id);if not present[id] and not r.listed then missing[#missing+1]=id end end
 oldList(self,...)
 for _,id in ipairs(missing) do local r=G:GetApplicant(id);add(report.listChecks,{t=GetTime(),id=id,preserved=r~=nil,seen=r and r.alertSeen}) end
end
G.Applicants.OnApplicantUpdated=function(self,id,...)
 local before=G:GetApplicant(id);oldItem(self,id,...);local r=G:GetApplicant(id)
 if not before and r then add(report.newItems,{t=GetTime(),id=id,status=r.status,seen=r.alertSeen}) end
end
frame=CreateFrame("Frame")
frame:SetScript("OnEvent",assert(probe:Callback(function(_,event,a,b)
 local waiting=G.Applicants:HasWaitingApplicants()
 add(report.events,{t=GetTime(),event=event,a=a,b=b,state=alerts:GetState(),waiting=waiting})
end)))
frame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED");frame:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
timer=C_Timer.NewTimer(60,assert(probe:Callback(function() report.finished=GetTime();probe:Finish(report) end)))
