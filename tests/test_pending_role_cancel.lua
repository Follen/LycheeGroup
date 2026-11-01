-- Isolated production Applications/Locale contract; no UI fixture or game access.
-- lua tests/test_pending_role_cancel.lua
local checks, cases, failures = 0, 0, {}
local function Eq(actual, expected, message)
 checks=checks+1
 if T then return T.eq(actual,expected,message) end
 assert(actual==expected,(message or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function Case(name, run)
 cases=cases+1
 local ok,err=pcall(run)
 if not ok then failures[#failures+1]=name..": "..tostring(err) end
end
local function Fixture(locale)
 local s={native={},results={},completeCalls=0,cancelCalls=0,applyCalls=0,notices={},
  roleCheck=true,activityID=700,home=false,raid=false,leader=true,subgroup=0,members=0,
  units={},unitReads={},groupReads={},timers={},now=100,views=false,completeResult=true}
 local env=setmetatable({}, {__index=_G})
 env._G=env
 env.LE_PARTY_CATEGORY_HOME=101
 env.LE_PARTY_CATEGORY_INSTANCE=102
 env.GetTime=function() return s.now end
 env.wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end
 env.IsInGroup=function(category)
  s.groupReads[#s.groupReads+1]={"group",category}
  return category==env.LE_PARTY_CATEGORY_HOME and s.home or category~=env.LE_PARTY_CATEGORY_HOME and s.instance or false
 end
 env.IsInRaid=function(category)
  Eq(category,env.LE_PARTY_CATEGORY_HOME,"raid check uses home category")
  s.groupReads[#s.groupReads+1]={"raid",category};return s.raid
 end
 env.UnitIsGroupLeader=function(unit,category)
  Eq(unit,"player","permission checks player")
  Eq(category,env.LE_PARTY_CATEGORY_HOME,"permission uses home party")
  return s.leader
 end
 env.GetNumSubgroupMembers=function(category)
  Eq(category,env.LE_PARTY_CATEGORY_HOME,"party size uses home category");return s.subgroup
 end
 env.GetNumGroupMembers=function(category)
  Eq(category,env.LE_PARTY_CATEGORY_HOME,"raid size uses home category");return s.members
 end
 env.UnitExists=function(unit) s.unitReads[#s.unitReads+1]={"exists",unit};return s.units[unit] and s.units[unit].exists or false end
 env.UnitIsConnected=function(unit) s.unitReads[#s.unitReads+1]={"connected",unit};return s.units[unit] and s.units[unit].connected end
 env.UnitInParty=function(unit,category)
  Eq(category,env.LE_PARTY_CATEGORY_HOME,"party membership uses home category")
  local member=s.units[unit]
  return member~=nil and member.home~=false
 end
 env.UnitInRaid=function(unit,category)
  Eq(category,env.LE_PARTY_CATEGORY_HOME,"raid membership uses home category")
  local member=s.units[unit]
  return member~=nil and member.home~=false and tonumber(unit:match("^raid(%d+)$")) or nil
 end
 env.EJ_GetInstanceInfo=function() return nil end
 env.GetDifficultyInfo=function() return "" end
 env.C_Timer={NewTimer=function(delay,callback)
  local timer={at=s.now+delay,callback=callback}
  function timer:Cancel() self.cancelled=true end
  s.timers[#s.timers+1]=timer;return timer
 end}
 local g={Results={},Game={}}
 function g:Notify(event,id) s.notices[#s.notices+1]={event,id} end
 function g:HasViews() return s.views end
 function g.Public(value) return value end
 function g.Results:GetResult(id) return s.results[id] end
 function g.Results:Capture(id) return s.results[id] end
 function g.Results:GetFlaggedLeaderClass() return "MAGE" end
 function g.Results:InvalidateView() s.invalidations=(s.invalidations or 0)+1 end
 function g.Game:RefreshApplicationSubscriptions() s.subscriptions=(s.subscriptions or 0)+1 end
 env.LycheeGroup={Group=g,GetLocale=function() return locale end,GetSetting=function() return false end,Print=function() end}
 env.C_LFGList={
  GetApplications=function() local ids={};for id in pairs(s.native) do ids[#ids+1]=id end;table.sort(ids);return ids end,
  GetApplicationInfo=function(id)
   local row=s.native[id];if row then return id,row.status,row.pending,row.remaining or 60 end
  end,
  GetRoleCheckInfo=function() return s.roleCheck,s.activityID end,
  GetActivityGroupInfo=function() return "Test activity" end,
  GetSearchResultInfo=function(id) return s.results[id] end,
  HasActiveEntryInfo=function() return false end,
  ApplyToGroup=function(id,tank,healer,damage)
   s.applyCalls=s.applyCalls+1;s.applied={id,tank,healer,damage}
   s.native[id]={status="applied"}
  end,
  CancelApplication=function(id)
   s.cancelCalls=s.cancelCalls+1
   s.native[id]={status="cancelled"}
  end,
 }
 env.CompleteLFGRoleCheck=function(accept)
  Eq(accept,false,"cancel declines native role check")
  s.completeCalls=s.completeCalls+1
  if s.onComplete then s.onComplete() end
  if s.completeError then error("native role cancellation unavailable") end
  return s.completeResult
 end
 local function Load(path) local chunk=assert(loadfile(path));setfenv(chunk,env);chunk() end
 Load("addon/LycheeGroup_Group/Locale.lua")
 Load("addon/LycheeGroup_Group/Applications.lua")
 s.app,s.L,s.env=g.Applications,env.LycheeGroup.GroupLocale,env
 function s:Add(id,status,pending,activity)
  self.native[id]={status=status,pending=pending}
  self.results[id]={id=id,activityID=activity or 700,categoryID=2,name="Party "..id,activityName="Test"}
 end
 function s:Sync() self.app:SyncAll() end
 function s:Checking(id)
  Eq(type(self.app.IsCheckingRoles),"function","Applications exposes native checking status")
  return self.app:IsCheckingRoles(id)
 end
 function s:RoleChanged()
  Eq(type(self.app.OnRoleCheckChanged),"function","Applications handles native role-check changes")
  self.app:OnRoleCheckChanged()
 end
 function s:Advance(seconds)
  self.now=self.now+seconds
  for _,timer in ipairs(self.timers) do
   if not timer.cancelled and timer.at<=self.now then timer.cancelled=true;timer.callback() end
  end
 end
 function s:Notices(event)
  local n=0;for _,notice in ipairs(self.notices) do if notice[1]==event then n=n+1 end end;return n
 end
 return s
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local function Test(name,run) Case(locale.." "..name,run) end
 Test("unique matching pending role check",function()
  for _,status in ipairs({"none","applied"}) do
   local s=Fixture(locale);s:Add(10,status,"applied");s:Sync()
   Eq(s:Checking(10),true);Eq(s.app:CanCancel(10),true)
   Eq(s.app:GetActiveCount(),1,"checking role application remains active")
   Eq(s:Checking(999),false,"unknown application cannot own role check")
  end
 end)
 Test("permission uses home party",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync();s.home=true;s.leader=false;s.instance=true
  Eq(s.app:CanCancel(10),false,"home member cannot cancel whole party check")
  Eq(s.app:Cancel(10),false);Eq(s.completeCalls,0);Eq(s.cancelCalls,0)
  s.leader=true;Eq(s.app:CanCancel(10),true,"home leader may cancel")
  s.home=false;s.leader=false;Eq(s.app:CanCancel(10),true,"instance membership does not block solo home player")
 end)
 Test("role check identity and ambiguity",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  s.activityID=701;Eq(s:Checking(10),false);Eq(s.app:Cancel(10),false)
  s.activityID=700;s.roleCheck=false;Eq(s:Checking(10),false);Eq(s.app:Cancel(10),false)
  s.roleCheck=true;s:Add(11,"none","applied",701);s:Sync()
  Eq(s:Checking(10),false,"two pending applications are ambiguous even with one matching activity")
  Eq(s.app:Cancel(10),false);Eq(s.app:Cancel(11),false)
  s.native[11]=nil;s:Sync();Eq(s:Checking(10),true)
  Eq(s.completeCalls,0);Eq(s.cancelCalls,0,"unrelated native checks are untouched")
 end)
 Test("ordinary statuses retain cancellation rules",function()
  local s=Fixture(locale);s.roleCheck=false;s:Add(10,"applied");s:Sync()
  Eq(s.app:CanCancel(10),true);Eq(s.app:Cancel(10),true);Eq(s.cancelCalls,1);Eq(s.completeCalls,0)
  for _,row in ipairs({{"none","applied"},{"applied","cancelled"},{"invited"},{"none","invited"},{"declined"},{"cancelled"}}) do
   s=Fixture(locale);s.roleCheck=true;s:Add(10,row[1],row[2]);s:Sync()
   if row[1]=="none" and row[2]=="applied" then s.roleCheck=false end
   Eq(s:Checking(10),false);Eq(s.app:CanCancel(10),false);Eq(s.app:Cancel(10),false)
   Eq(s.cancelCalls,0);Eq(s.completeCalls,0)
  end
 end)
 Test("offline home member blocks new apply but not existing cancellation",function()
  for _,raid in ipairs({false,true}) do
   local s=Fixture(locale);s.home=true;s.raid=raid;s.subgroup=1;s.members=2;s.roleCheck=false
   local unit=raid and "raid2" or "party1"
   s.units[unit]={exists=true,connected=true}
   s:Add(10,"applied");s:Sync()
   s.units[unit].connected=false
   Eq(s.app:Apply(20,{damage=true}),false,"offline HOME member prevents a new submission")
   Eq(s.applyCalls,0)
   Eq(s.app:GetApplication(10).status,"applied","new-submission rejection preserves the existing application")
   Eq(s.app:CanCancel(10),true,"offline HOME member does not block an existing application cancellation")
   Eq(s.app:Cancel(10),true);Eq(s.cancelCalls,1,"ordinary applied cancellation uses CancelApplication")
   Eq(s.completeCalls,0,"existing applied cancellation does not decline a role check")
  end
 end)
 Test("missing identity and nonpending status cannot own check",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  s.results[10].activityID=nil
  Eq(s:Checking(10),false);Eq(s.app:Cancel(10),false)
  s.results[10].activityID=700;s.activityID=nil
  Eq(s:Checking(10),false);Eq(s.app:Cancel(10),false)
  s.activityID=700;s.native[10].status="invited";s:Sync()
  Eq(s:Checking(10),false);Eq(s.app:CanCancel(10),false)
  s.native[10].status=nil;s:Sync()
  Eq(s:Checking(10),false,"unspecified status is not a confirmed pending application")
  Eq(s.completeCalls,0);Eq(s.cancelCalls,0)
 end)
 Test("role-check identity is rechecked at click time",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  Eq(s.app:CanCancel(10),true)
  s.activityID=701
  Eq(s.app:Cancel(10),false);Eq(s.completeCalls,0);Eq(s.cancelCalls,0)
  s.activityID=700;s:Add(11,"none","applied");s:Sync()
  Eq(s.app:Cancel(10),false);Eq(s.completeCalls,0)
 end)
 Test("second native pending before local sync blocks cancellation",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  Eq(s.app:CanCancel(10),true)
  s:Add(11,"none","applied",701)
  Eq(s.app:GetApplication(11),nil,"second application has not reached local cache")
  Eq(s.app:Cancel(10),false,"click must reload all native applications before deciding uniqueness")
  Eq(s.completeCalls,0);Eq(s.cancelCalls,0)
  Eq(s.app:GetApplication(10)~=nil,true,"ambiguous application stays intact")
  Eq(s.app:GetApplication(11)~=nil,true,"click synchronizes the newly discovered pending application")
 end)
 Test("accepted request retains native pending application",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  Eq(s.app:Cancel(10),true);Eq(s.completeCalls,1);Eq(s.cancelCalls,0)
  local record=s.app:GetApplication(10)
  Eq(record~=nil,true);Eq(record.status,"none");Eq(record.pendingStatus,"applied")
  Eq(record.roleCheckCancelRequested,true);Eq(s.app:GetActiveCount(),1)
  Eq(s:Notices("applicationCancelled"),0,"request is not a successful cancellation event")
  Eq(s.app:CanCancel(10),false);Eq(s.app:Cancel(10),false);Eq(s.completeCalls,1,"duplicate clicks issue no second native decline")
  s:Sync();Eq(s.app:CanCancel(10),false,"ordinary sync cannot erase outstanding request")
 end)
 Test("false return and throw permit retry",function()
  for _,mode in ipairs({"false","throw"}) do
   local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
   s.completeResult=false;s.completeError=mode=="throw"
   local ok,reason=s.app:Cancel(10)
   Eq(ok,false);Eq(reason,s.L.cancelFailed,"native rejection uses real localized failure")
   Eq(s.completeCalls,1);Eq(s.cancelCalls,0);Eq(s.app:GetApplication(10)~=nil,true)
   Eq(s.app:GetApplication(10).roleCheckCancelRequested==true,false)
   Eq(s.app:CanCancel(10),true);Eq(s:Notices("applicationCancelled"),0)
   s.completeError=false;s.completeResult=true
   Eq(s.app:Cancel(10),true);Eq(s.completeCalls,2,"failed request can be retried")
  end
 end)
 Test("synchronous cancellation event cannot resurrect application",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  s.onComplete=function()
   s.roleCheck=false;s.native[10]={status="cancelled"}
   s.app:OnStatusUpdated(10,"cancelled","none")
  end
  Eq(s.app:Cancel(10),true);Eq(s.completeCalls,1);Eq(s.cancelCalls,0)
  Eq(s.app:GetApplication(10),nil,"hidden views release synchronous terminal state")
  Eq(s:Notices("applicationCancelled"),1)
  s:Sync();Eq(s.app:GetApplication(10),nil,"retired native result stays retired")
 end)
 Test("visible terminal state retires on existing timer",function()
  local s=Fixture(locale);s.views=true;s:Add(10,"applied","applied");s:Sync()
  s.onComplete=function()
   s.roleCheck=false;s.native[10]={status="cancelled"}
   s.app:OnStatusUpdated(10,"cancelled","applied")
  end
  Eq(s.app:Cancel(10),true);Eq(s.app:GetApplication(10).status,"cancelled")
  s:Advance(4.9);Eq(s.app:GetApplication(10)~=nil,true)
  s:Advance(0.2);Eq(s.app:GetApplication(10),nil)
  s:Sync();Eq(s.app:GetApplication(10),nil)
 end)
 Test("reentrant request is blocked before calling native",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  s.onComplete=function()
   if s.completeCalls==1 then Eq(s.app:CanCancel(10),false);Eq(s.app:Cancel(10),false) end
  end
  Eq(s.app:Cancel(10),true);Eq(s.completeCalls,1);Eq(s.cancelCalls,0)
 end)
 Test("role-check end clears latch then syncs and notifies",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  Eq(s.app:Cancel(10),true)
  s:RoleChanged();Eq(s.app:GetApplication(10).roleCheckCancelRequested,true,"active native check keeps latch")
  local notices=s:Notices("applications")
  s.roleCheck=false;s.native[10]={status="applied"};s:RoleChanged()
  Eq(s.app:GetApplication(10).roleCheckCancelRequested==true,false)
  Eq(s.app:GetApplication(10).pendingStatus,nil,"event synchronizes native application")
  Eq(s.app:GetApplication(10).status,"applied");Eq(s.app:CanCancel(10),true)
  Eq(s:Notices("applications")>notices,true)
  Eq(s.app:Cancel(10),true);Eq(s.cancelCalls,1,"finished role check resumes ordinary cancellation")
 end)
 Test("synchronous role-check hide cannot restore request latch",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  s.onComplete=function()
   s.roleCheck=false;s.native[10]={status="applied"};s:RoleChanged()
  end
  Eq(s.app:Cancel(10),true);Eq(s.completeCalls,1)
  Eq(s.app:GetApplication(10).roleCheckCancelRequested==true,false,"returning native call cannot overwrite completed event cleanup")
  Eq(s.app:GetApplication(10).status,"applied");Eq(s.app:CanCancel(10),true)
 end)
 Test("ended role check permits a later native check",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  Eq(s.app:Cancel(10),true);s.roleCheck=false;s:RoleChanged()
  Eq(s.app:GetApplication(10).roleCheckCancelRequested==true,false)
  Eq(s.app:CanCancel(10),false,"pending application without native check remains busy")
  s.roleCheck=true;s:RoleChanged()
  Eq(s.app:CanCancel(10),true);Eq(s.app:Cancel(10),true);Eq(s.completeCalls,2)
 end)
 Test("role-check end removes vanished record",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  Eq(s.app:Cancel(10),true);s.roleCheck=false;s.native[10]=nil;s:RoleChanged()
  Eq(s.app:GetApplication(10),nil);Eq(s.app:GetActiveCount(),0)
 end)
 Test("native state is rechecked before cancellation",function()
  local s=Fixture(locale);s:Add(10,"none","applied");s:Sync()
  s.native[10]={status="invited"}
  Eq(s.app:Cancel(10),false);Eq(s.completeCalls,0);Eq(s.cancelCalls,0)
  Eq(s.app:GetApplication(10).status,"invited")
 end)
 Test("home party offline member rejects submit",function()
  local s=Fixture(locale);s.home=true;s.subgroup=2
  s.units.party1={exists=true,connected=true};s.units.party2={exists=true,connected=false}
  local ok,reason=s.app:Apply(20,{tank=true,healer=false,damage=true})
  Eq(ok,false);Eq(type(reason),"string");Eq(reason~="",true);Eq(s.applyCalls,0)
  Eq(s.app:GetApplication(20),nil,"offline rejection creates no successful local application")
 end)
 Test("home raid scans beyond party unit range",function()
  local s=Fixture(locale);s.home=true;s.raid=true;s.members=8;s.subgroup=4
  for i=1,8 do s.units["raid"..i]={exists=true,connected=true} end
  s.units.raid8.connected=false
  Eq(s.app:Apply(20,{damage=true}),false);Eq(s.applyCalls,0)
  s.units.raid8.connected=true
  Eq(s.app:Apply(20,{damage=true}),true);Eq(s.applyCalls,1)
  for _,read in ipairs(s.unitReads) do Eq(read[2]:sub(1,4),"raid","home raid uses raid units") end
 end)
 Test("nonhome offline unit in party token is ignored",function()
  local s=Fixture(locale);s.home=true;s.instance=true;s.subgroup=2
  s.units.party1={exists=true,connected=true}
  s.units.party2={exists=true,connected=false,home=false}
  Eq(s.app:Apply(20,{healer=true}),true);Eq(s.applyCalls,1,"instance-only offline party unit does not block home submission")
  s.units.party2.home=true
  Eq(s.app:Apply(21,{healer=true}),false);Eq(s.applyCalls,1,"same token blocks only after confirmed HOME membership")
 end)
 Test("nonhome offline unit in raid token is ignored",function()
  local s=Fixture(locale);s.home=true;s.instance=true;s.raid=true;s.members=8
  for i=1,8 do s.units["raid"..i]={exists=true,connected=true} end
  s.units.raid8.connected=false;s.units.raid8.home=false
  Eq(s.app:Apply(20,{damage=true}),true);Eq(s.applyCalls,1,"instance-only offline raid unit does not block home submission")
  s.units.raid8.home=true
  Eq(s.app:Apply(21,{damage=true}),false);Eq(s.applyCalls,1,"HOME raid member at same token blocks")
 end)
 Test("only explicit offline existing home units reject",function()
  for _,mode in ipairs({"solo","instance","absent","unknown","online"}) do
   local s=Fixture(locale);s.home=mode~="solo" and mode~="instance";s.instance=true;s.subgroup=1
   s.units.party1={exists=mode~="absent",connected=mode=="unknown" and nil or false}
   if mode=="unknown" then s.units.party1.connected=nil elseif mode=="online" then s.units.party1.connected=true end
   local ok=s.app:Apply(20,{tank=true,healer=true,damage=false})
   Eq(ok,true,mode.." must not be rejected");Eq(s.applyCalls,1)
   Eq(s.applied[1],20);Eq(s.applied[2],true);Eq(s.applied[3],true);Eq(s.applied[4],false)
   if mode=="solo" or mode=="instance" then Eq(#s.unitReads,0,"no home group: do not scan instance units") end
  end
 end)
end

for _,failure in ipairs(failures) do print("[FAIL] pending_role_cancel "..failure) end
print(("pending_role_cancel: %d cases, %d checks, %d failed cases"):format(cases,checks,#failures))
assert(#failures==0,"pending_role_cancel: "..#failures.." failed cases")
