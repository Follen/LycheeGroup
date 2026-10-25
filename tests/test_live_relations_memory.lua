-- Lifecycle and failure checks for the read-only social-event memory observer.
local checks=0
local function check(value,message) checks=checks+1;assert(value,message)end
local function fixture()
 local f=dofile("tests/live_probe_fixture.lua")()
 f.U.IsShown=function()return not f.hidden end
 f.U.page="create"
 f.primes,f.subscriptions,f.unsubscribes=0,0,0
 f.G.Relations={active=true,dirtySources=0,version=17,GetVersion=function(self)
  f.primes=f.primes+1
  if f.failPrime then error("simulated priming failure")end
  self.sampledAt=f.now;return self.version
 end}
 f.G.Roster={members={}};for i=1,14 do f.G.Roster.members[i]={}end
 f.U.pages.create.appIDs={}
 _G.GetNumGroupMembers=function()return 14 end
 _G.GetNumGuildMembers=function()return 1000 end
 _G.C_LFGList.HasActiveEntryInfo=function()return f.listing==true end
 local subscribe=f.G.Subscribe
 function f.G:Subscribe(callback)
  f.subscriptions=f.subscriptions+1;f.lastRelationCallback=callback
  local unsubscribe=subscribe(self,callback)
  return function()f.unsubscribes=f.unsubscribes+1;unsubscribe()end
 end
 function f:Fire(event)
  for _,node in ipairs(self.S.nodes)do if node.events[event]then node:Fire("OnEvent",event)end end
 end
 return f
end
local function run(f,events)
 local p=f:Start("tests/live_relations_memory.lua")
 for i=1,22 do
  if f.beforeTick then f.beforeTick(i)end
  if events~=false then f:Fire("GUILD_ROSTER_UPDATE")end
  f:Advance(5)
 end
 return p
end
local function released(f,p)
 check(not p.active,"observer finished")
 check(f.subscriptions==f.unsubscribes,"the group notification subscription is released exactly once")
 check(f.primes==f.subscriptions+(f.failPrime and 1 or 0),"each observation primes once; samples never call GetVersion")
 for _,node in ipairs(f.S.nodes)do check(not node.events.GUILD_ROSTER_UPDATE,"event frame released")end
 local notifications=p.result and p.result.relationNotifications
 local reads=f.reads;f:Advance(20);f:Fire("GUILD_ROSTER_UPDATE")
 f.G:Notify("relations")
 if f.lastRelationCallback then f.lastRelationCallback("relations")end
 check(f.reads==reads,"late callbacks cannot sample after cleanup")
 if p.result then check(p.result.relationNotifications==notifications,"late group callbacks cannot alter a completed report")end
end
do
 local f=fixture();local p=run(f)
 check(not p.error and p.result.ok,"normal observation passes")
 check(#p.result.samples==23 and p.result.events.GUILD_ROSTER_UPDATE==22,"bounded samples and real event count")
 check(p.result.peakBytes==4096000,"all four package counters are included")
 check(p.result.primedSnapshot and p.result.initialVersion==17,"the one intentional public read is identified in the report")
 check(p.result.identityVersionChanges==0 and p.result.relationNotifications==0,"repeated source events are distinct from identity changes and display notifications")
 for _,row in ipairs(p.result.samples)do
  check(row.shown and row.page=="create" and row.listing==false,"each sample records the actual page and listing state")
  check(row.rosterMembers==14 and row.applicants==0,"zero applicants is a recorded scale, not a required test precondition")
  check(row.relationsVersion==17,"samples observe the current identity version without refreshing it")
 end
 released(f,p)
 local again=run(f);check(again.result.ok,"repeated observation remains usable");released(f,again)
end
do
 local f=fixture();f.listing=true
 f.U.pages.create.appIDs={71,72};f.G.Roster.members={{},{},{}}
 f.beforeTick=function(index)
  -- Use the real Group notification seam; event sampling does not manufacture
  -- identity changes or infer them from the number of native events.
  if index==3 or index==10 then f.G.Relations.version=f.G.Relations.version+1;f.G:Notify("relations")end
  f.G:Notify("roster")
 end
 local p=run(f)
 check(p.result.ok and p.result.identityVersionChanges==2,"only actual content-version advances are counted")
 check(p.result.relationNotifications==2,"only relations notifications are counted")
 check(p.result.samples[1].relationsVersion==17 and p.result.samples[4].relationsVersion==18 and p.result.samples[11].relationsVersion==19,"samples retain the content-version sequence")
 check(p.result.samples[1].listing and p.result.samples[1].rosterMembers==3 and p.result.samples[1].applicants==2,"listing and current displayed scale are recorded")
 released(f,p)
end
do
 local f=fixture();GetAddOnMemoryUsage=function()return 6000 end
 local p=run(f);check(not p.result.ok and not p.result.checks.budget,"high memory fails the product budget")
 released(f,p)
end
do
 local f=fixture();local p=run(f,false)
 check(not p.result.ok and not p.result.checks.repeatedSocialUpdates,"an idle event source cannot validate social churn")
 released(f,p)
end
do
 local f=fixture();local p=f:Start("tests/live_relations_memory.lua")
 for i=1,22 do if i==5 then f.hidden=true end;f:Fire("GUILD_ROSTER_UPDATE");f:Advance(5)end
 check(not p.result.ok and not p.result.checks.scene,"closing the required page is reported")
 released(f,p)
end
for _,read in ipairs({1,2})do
 local f=fixture();f.failRead=read
 local p=f:Start("tests/live_relations_memory.lua");f:Advance(5)
 check(p.error and p.error:find("observer failure",1,true),"initial/callback observer errors fail cleanly")
 released(f,p)
end
do
 local f=fixture();f.failPrime=true
 local p=f:Start("tests/live_relations_memory.lua")
 check(p.error and p.error:find("priming failure",1,true),"a failed initial identity read follows the same cleanup contract")
 check(f.subscriptions==0,"priming failure cannot leave a notification subscription")
 released(f,p)
end
do
 local f=fixture();local p=f:Start("tests/live_relations_memory.lua");p:Close()
 check(p.result==nil,"cancelled observation has no success report");released(f,p)
end
print("Live relationships memory: "..checks.." checks passed")
