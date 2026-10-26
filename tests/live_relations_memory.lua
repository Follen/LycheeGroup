-- Observe an existing Create page during real friend/guild updates. No business
-- actions, method wrappers, forced collection or GC-policy changes.
local probe=...
local A=assert(LycheeGroup,"product_missing")
local G,U=assert(A.Group,"group_missing"),assert(A.UI,"ui_missing")
assert(U:IsShown() and U.page=="create" and not U.preview and G.Relations.active,"requires_live_create_page")
assert(type(G.Relations.dirtySources)=="number","requires_scoped_relations_refresh")
local packages={"LycheeGroup","LycheeGroup_Group","LycheeGroup_Notes","LycheeGroup_UI","LycheeGroup_Guide"}
local report={schema="lycheegroup.relations-memory.v1",build=select(2,GetBuildInfo()),
 gcPolicy="natural; no explicit collection",sampleIntervalSeconds=5,durationSeconds=110,
 budgetBytes=20000000,peakBytes=0,samples={},events={},activeSamples=0,relationNotifications=0}
local events={"GUILD_ROSTER_UPDATE","BN_FRIEND_INFO_CHANGED","BN_FRIEND_LIST_SIZE_CHANGED",
 "BN_FRIEND_ACCOUNT_ONLINE","BN_FRIEND_ACCOUNT_OFFLINE","FRIENDLIST_UPDATE",
 "CLUB_MEMBER_ADDED","CLUB_MEMBER_REMOVED","CLUB_MEMBER_UPDATED","CLUB_MEMBERS_UPDATED"}
local timer,frame,unsubscribe
assert(probe:OnCleanup(function()
 if timer then timer:Cancel();timer=nil end
 if frame then frame:UnregisterAllEvents();frame:SetScript("OnEvent",nil);frame:Hide();frame=nil end
 if unsubscribe then unsubscribe();unsubscribe=nil end
end))
assert(probe:Async(115))
-- Prime once through the public read. Later samples observe the content version
-- without triggering a refresh, so normal business events own all later work.
report.initialVersion=G.Relations:GetVersion();report.primedSnapshot=true
unsubscribe=G:Subscribe(assert(probe:Callback(function(kind)
 if kind=="relations" then report.relationNotifications=report.relationNotifications+1 end
end)))
frame=CreateFrame("Frame")
frame:SetScript("OnEvent",assert(probe:Callback(function(_,event) report.events[event]=(report.events[event]or 0)+1 end)))
for _,event in ipairs(events)do frame:RegisterEvent(event)end
local started=GetTime()
local function Sample()
 local at=debugprofilestop();UpdateAddOnMemoryUsage()
 local row={elapsedSeconds=GetTime()-started,observerRefreshMs=debugprofilestop()-at,
  heapKiB=collectgarbage("count"),bytes=0,packages={},groupMembers=GetNumGroupMembers(),
  guildMembers=GetNumGuildMembers(),relationsVersion=G.Relations.version,
  listing=C_LFGList.HasActiveEntryInfo(),shown=U:IsShown(),page=U.page,
  rosterMembers=#G.Roster.members,applicants=U.pages.create.appIDs and #U.pages.create.appIDs or 0,
  active=U:IsShown() and U.page=="create" and G.Relations.active or false,combat=InCombatLockdown()}
 for _,name in ipairs(packages)do local value=GetAddOnMemoryUsage(name)*1024;row.packages[name]=value;row.bytes=row.bytes+value end
 report.samples[#report.samples+1]=row;report.peakBytes=math.max(report.peakBytes,row.bytes)
 if row.active then report.activeSamples=report.activeSamples+1 end
end
Sample()
local tick
tick=assert(probe:Callback(function()
 Sample()
 if #report.samples==23 then
  report.elapsedSeconds=GetTime()-started
  report.identityVersionChanges=G.Relations.version-report.initialVersion
  report.checks={budget=report.peakBytes<=report.budgetBytes,scene=report.activeSamples==#report.samples,
   repeatedSocialUpdates=(report.events.GUILD_ROSTER_UPDATE or 0)+(report.events.BN_FRIEND_INFO_CHANGED or 0)>=10}
  report.ok=report.checks.budget and report.checks.scene and report.checks.repeatedSocialUpdates
  return probe:Finish(report)
 end
 timer=C_Timer.NewTimer(5,tick)
end))
timer=C_Timer.NewTimer(5,tick)
