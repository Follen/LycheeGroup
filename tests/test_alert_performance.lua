-- Actual applicant storage + audio machine: bounded work and no idle scheduling.
TestStubs.Install({locale="enUS",realm="Realm"})
local S={now=0,listing=true,allowed=true,choice="voice",data={},ids={},reads=0,infoReads=0,memberReads=0,plays=0,scheduled=0}
_G.GetTime=function() return S.now end
_G.GetTimePreciseSec=_G.GetTime
_G.QueueStatusButton=nil
_G.LFGListFrame=nil
_G.PlaySoundFile=function() S.plays=S.plays+1;return true,S.plays end
_G.PlaySound=_G.PlaySoundFile
_G.StopSound=function() end
local newTimer=C_Timer.NewTimer
C_Timer.NewTimer=function(delay,callback) S.scheduled=S.scheduled+1;return newTimer(delay,callback) end
_G.C_LFGList={
 HasActiveEntryInfo=function() return S.listing end,
 GetApplicants=function() S.reads=S.reads+1;return S.ids end,
 GetApplicantInfo=function(id) S.reads=S.reads+1;S.infoReads=S.infoReads+1;return S.data[id] end,
 GetApplicantMemberInfo=function() S.reads=S.reads+1;S.memberReads=S.memberReads+1;return "Member-Realm","MAGE","Mage",80,600,0,false,false,true,"DAMAGER" end,
}
_G.LycheeGroup={GroupLocale={}}
local A=LycheeGroup
function A:GetSetting(key) return key=="soundChannel" and "Dialog" or S.choice end
local G={};A.Group=G
G.Public=function(value) return value end
G.RemotePlayerKey=function(_,name) return name end
G.Notify=function() end
G.CanManageApplicants=function() return S.allowed end
G.Listing={GetListing=function() if S.listing then return {activityID=100} end end}
local activity={id=100}
G.Catalog={GetActivity=function() return activity end}
G.Relations={ApplyMembers=function() return 1 end,GetVersion=function() return 1 end}
Load.addon("LycheeGroup_Group","Applicants.lua")
Load.addon("LycheeGroup_Group","Alerts.lua")
local function Advance(seconds) S.now=S.now+seconds;TestStubs.AdvanceClock(seconds) end
local function Add(id)
 S.data[id]={applicationStatus="applied",numMembers=1,displayOrderID=id}
 S.ids[#S.ids+1]=id
 G.Applicants:OnApplicantUpdated(id)
end
local function Cost()
 local ticks=0
 local previous,mask,count=debug.gethook()
 local reads,scheduled=S.reads,S.scheduled
 debug.sethook(function() ticks=ticks+1 end,"",100)
 for _=1,1000 do G.Alerts:Sync();G.Applicants:HasWaitingApplicants() end
 debug.sethook(previous,mask,count)
 T.eq(S.reads,reads,"audio reconciliation never queries applicant/member APIs")
 T.eq(S.scheduled,scheduled,"repeated audio reconciliation never schedules idle work")
 return ticks
end

Add(1);Advance(0)
T.eq(S.plays,1);T.eq(G.Alerts:GetState(),"cooldown")
T.eq(TestStubs.PendingTimers(),0,"a single alert's cooldown is only a timestamp")
local one=Cost()
local scheduled=S.scheduled
for id=2,1000 do Add(id) end
T.eq(S.plays,1,"999 arrivals inside one cooldown do not overlap audio")
T.eq(S.scheduled-scheduled,1,"burst only uses the existing display notification")
T.eq(TestStubs.PendingTimers(),1)
Advance(0)
T.eq(TestStubs.PendingTimers(),0,"audio has no scheduled work after display coalescing")
Advance(3)
T.eq(S.plays,1,"cooldown expiry never catches up skipped arrivals");T.eq(TestStubs.PendingTimers(),0)
local thousand=Cost()
T.ok(thousand<=one*1.05+2,"audio snapshot work is independent of 1 versus 1000 applicants")
Advance(30)
T.eq(S.plays,1,"unprocessed existing applicants never cause another sound")
T.eq(G.Alerts:GetState(),"idle");T.eq(TestStubs.PendingTimers(),0)

-- The waiting count returns to zero as every record leaves.
for id=1,1000 do S.data[id]=nil;G.Applicants:OnApplicantUpdated(id) end
Advance(0)
local waiting=G.Applicants:HasWaitingApplicants()
T.eq(waiting,false);T.eq(TestStubs.PendingTimers(),0)
S.ids={}
Add(1001);Advance(0)
T.eq(S.plays,2,"a new arrival after cooldown plays immediately")
Add(1002);Advance(0)
S.data[1002]=nil;G.Applicants:OnApplicantUpdated(1002);Advance(0)
T.eq(G.Alerts:GetState(),"cooldown")
T.eq(TestStubs.PendingTimers(),0,"withdrawals do not create audio work")
Advance(3);T.eq(S.plays,2)

-- A silent restore marks existing records seen without generating audio work.
G.Applicants:Clear();S.ids={1001};G.Applicants:Restore();Advance(0)
G.Applicants:OnApplicantUpdated(1001);Advance(0)
T.eq(S.plays,2);T.eq(TestStubs.PendingTimers(),0)
Add(1003);Advance(0)
T.eq(S.plays,3)
S.allowed=false;G.Alerts:Sync()
T.eq(G.Alerts:GetState(),"disabled");T.eq(TestStubs.PendingTimers(),0)
G.Applicants:Clear()

-- An item update can arrive before the first complete applicant list. Repeated
-- omissions reconcile only the applicant info, without reading member data;
-- once a complete list confirms the record, later omissions use the listed
-- record path and do not repeat the extra info query.
S.allowed=true;S.ids={};S.data={}
local function AddBeforeList(id)
 S.data[id]={applicationStatus="applied",numMembers=1,displayOrderID=id}
 G.Applicants:OnApplicantUpdated(id)
end
AddBeforeList(2001);Advance(0)
local infoBefore=S.infoReads
local membersBefore=S.memberReads
G.Applicants:RefreshList(true,true)
T.eq(S.infoReads-infoBefore,1,"first list omission checks the event-only applicant once")
T.eq(S.memberReads-membersBefore,0,"first list omission does not read member data")
infoBefore=S.infoReads
G.Applicants:RefreshList(true,true)
T.eq(S.infoReads-infoBefore,1,"each repeated omission checks only the still-unlisted applicant")
T.eq(S.memberReads-membersBefore,0,"repeated omissions still do not read member data")

S.ids={2001}
infoBefore=S.infoReads;membersBefore=S.memberReads
G.Applicants:RefreshList(true,true)
T.eq(S.infoReads-infoBefore,1,"the first complete list reads applicant info once")
T.eq(S.memberReads-membersBefore,1,"the first complete list reads the applicant member once")
S.ids={}
infoBefore=S.infoReads;membersBefore=S.memberReads
G.Applicants:RefreshList(true,true)
T.eq(S.infoReads-infoBefore,0,"after list confirmation an omission does not repeat the reconciliation query")
T.eq(S.memberReads-membersBefore,0,"after list confirmation an omission reads no member data")
G.Applicants:Clear();Advance(0)
T.eq(TestStubs.PendingTimers(),0,"event-only reconciliation leaves no timer after cleanup")
