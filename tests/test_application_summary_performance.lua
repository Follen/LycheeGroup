-- Standalone or runner-compatible: real hidden application/result services.
local checks=0
local function Check(value,message)
 checks=checks+1
 assert(value,message)
end
local function Eq(actual,expected,message) Check(actual==expected,(message or "value")..": expected "..tostring(expected)..", got "..tostring(actual)) end
local reads={players=0,leaders=0,counts=0,relations=0,progress=0}
local function ResetReads() for key in pairs(reads) do reads[key]=0 end end
local secret={}
local ids,sources={},{}
_G.wipe=function(value) for key in pairs(value) do value[key]=nil end;return value end
_G.GetTime=function() return 100 end
_G.issecretvalue=function(value) return value==secret end
_G.EJ_GetInstanceInfo=function() end
_G.GetDifficultyInfo=function() return "Normal" end
_G.C_Timer={NewTimer=function() return {Cancel=function() end} end}
local activity={id=1,name="Raid",categoryID=3,maxNumPlayers=40,groupID=1,difficultyID=14}
_G.C_LFGList={
 GetApplications=function() return ids end,
 GetApplicationInfo=function(id) return id,"applied",nil,300 end,
 HasActiveEntryInfo=function() return false end,
 GetActivityGroupInfo=function() return "Raid" end,
 GetSearchResultInfo=function(id)
  local source=sources[id]
  return {activityIDs={1},name=source.title or "Group "..id,leaderName="Leader"..id.."-Realm",numMembers=#source.members,numBNetFriends=1,numCharFriends=0,numGuildMates=0}
 end,
 GetSearchResultPlayerInfo=function(id,index)
  reads.players=reads.players+1
  local source=sources[id].members[index]
  if source==secret then return secret end
  local member={};for key,value in pairs(source) do member[key]=value end;return member
 end,
 GetSearchResultLeaderInfo=function() reads.leaders=reads.leaders+1;return {isLeader=true,classFilename="MAGE"} end,
 GetSearchResultMemberCounts=function() reads.counts=reads.counts+1;return {TANK=2,HEALER=8,DAMAGER=30} end,
 GetSearchResultFriends=function() reads.relations=reads.relations+1;return {"Friend-Realm"},{},{} end,
 GetSearchResultEncounterInfo=function() reads.progress=reads.progress+1;return {"Boss"} end,
}
local frame={SetScript=function(self,kind,callback) self[kind]=callback end,Show=function() end}
local G={db={blockedLeaders={}},Game={frame=frame,RefreshApplicationSubscriptions=function() end},Catalog={GetActivity=function() return activity end}}
local A={Group=G,GroupLocale={},GetSetting=function() return false end,PlayerKey=function(_,name) return name end,UnitIdentity=function() return "Self-Realm" end}
_G.LycheeGroup=A
G.Public=function(value) if value~=secret then return value end end
function G:RemotePlayerKey(name) return name end
function G:HasViews() return false end
function G:Notify() end
dofile("addon/LycheeGroup_Group/Results.lua")
dofile("addon/LycheeGroup_Group/Applications.lua")
local function Members(id,count,leader)
 local result={}
 for index=1,count do result[index]={name=(index==leader and "Leader"..id or "Member"..id.."_"..index).."-Realm",classFilename=index==leader and "MAGE" or "WARRIOR",isLeader=index==leader} end
 return result
end
for id=1,5 do ids[id]=id;sources[id]={members=Members(id,40,1)} end
G.Applications:SyncAll()
Eq(reads.players,5,"five hidden applications only read their first flagged members")
Eq(reads.leaders,0,"strict application summaries do not use the differently defined direct endpoint")
Eq(reads.counts+reads.relations+reads.progress,0,"hidden summaries do not request details-only data")
for _,id in ipairs(ids) do
 local app=G.Applications:GetApplication(id)
 Eq(app.leaderClass,"MAGE");Eq(app.result.details,nil,"hidden applications allocate no full details")
end
ResetReads();G.Applications:SyncAll()
Eq(reads.players,5,"a same-frame native reread invalidates strict summaries")
ResetReads();G.Applications:OnStatusUpdated(1,"applied","applied")
Eq(reads.players,1,"one hidden status event only reads its own first flagged member")
local app=G.Applications:GetApplication(1)
ResetReads();Eq(G.Results:GetFlaggedLeaderClass(app.result),"MAGE");Eq(reads.players,0,"summary consumers share the cached scalar")

-- A same-frame event invalidates the strict scalar even without metadata changes.
sources[1].members[1].classFilename="PRIEST"
G.Results:QueueUpdate(1);frame.OnUpdate()
Eq(app.leaderClass,"PRIEST");Eq(reads.players,1);Eq(app.result.details,nil)

-- Last or missing flags retain the full ordered search, without full snapshots.
ids={1}
sources[1].members=Members(1,40,40);ResetReads();G.Applications:SyncAll()
Eq(reads.players,40);Eq(app.leaderClass,"MAGE");Eq(app.result.details,nil)
sources[1].members[40].isLeader=false;ResetReads();G.Applications:SyncAll()
Eq(reads.players,40);Eq(app.leaderClass,nil,"a matching leader key does not substitute for an explicit member flag")
Eq(reads.counts+reads.relations+reads.progress,0)
ResetReads();Eq(G.Results:GetFlaggedLeaderClass(app.result),nil);Eq(reads.players,0,"unknown strict results are cached")
Eq(G.Results:GetLeaderClass(app.result),"MAGE","the existing permissive direct summary remains independent")
Eq(G.Results:GetFlaggedLeaderClass(app.result),nil,"permissive known data cannot fill the strict cache")

-- Native secrets and the first flag keep their previous normalization semantics.
sources[1].members={secret,{name="Leader1-Realm",classFilename="MAGE",isLeader=secret},{name="Other-Realm",classFilename=secret,isLeader=true},{name="Later-Realm",classFilename="PRIEST",isLeader=true}}
ResetReads();G.Applications:SyncAll()
Eq(reads.players,3,"the first public flagged member wins even when its class is secret")
Eq(app.leaderClass,nil);Eq(app.result.details,nil)
local secretDetails=G.Results:GetDetails(app.result)
Eq(#secretDetails.members,3,"an explicit detail consumer retains every public member table")
Eq(G.Results:GetFlaggedLeaderClass(app.result),nil,"full-detail assembly also stops at the first flag with an unavailable class")
sources[1].members[3].classFilename="WARRIOR";ResetReads();G.Applications:SyncAll()
Eq(reads.players,3);Eq(app.leaderClass,"WARRIOR","later flags never replace the first flagged class")
sources[1].members={{name="Leader1-Realm",classFilename="MAGE",isLeader=false},{name="Flagged-Realm",classFilename="PRIEST",isLeader=true},{name="Later-Realm",classFilename="WARRIOR",isLeader=true}}
G.Applications:SyncAll();Eq(app.leaderClass,"PRIEST")
Eq(G.Results:GetLeaderClass(app.result),"MAGE");Eq(G.Results:GetFlaggedLeaderClass(app.result),"PRIEST")

-- Explicit full consumers keep complete data and original container reuse.
ResetReads();local result=app.result;local details=G.Results:GetDetails(result);local members=details.members
Eq(#members,3);Eq(reads.players,3);Eq(reads.relations,1);Eq(reads.progress,1);Eq(reads.counts,1)
Eq(details.relationships.bnet[1],"Friend-Realm");Eq(details.encounters[1],"Boss")
Eq(G.Results:GetFlaggedLeaderClass(result),"PRIEST","full details fill the independent strict scalar")
result.flaggedLeaderClassKnown,result.flaggedLeaderClass=nil,nil
ResetReads();Eq(G.Results:GetFlaggedLeaderClass(result),"PRIEST");Eq(reads.players,0,"clean full details satisfy strict summaries without native IO")
local oldMember=members[2]
sources[1].members[2].classFilename="PALADIN";sources[1].title="Latest metadata"
ResetReads();G.Applications:SyncAll()
Eq(app.result,result);Eq(result.details,details);Eq(result.detailsDirty,true)
Eq(app.leaderClass,"PALADIN");Eq(app.name,"Latest metadata");Eq(reads.players,2)
Eq(oldMember.class,"PRIEST","dirty full details wait for their real consumer")
Eq(G.Results:GetDetails(result),details);Eq(details.members,members);Eq(members[2],oldMember);Eq(oldMember.class,"PALADIN")
Eq(reads.players,5,"the explicit consumer refreshes all three members")
Eq(result.detailsDirty,nil)
sources[1].members[2]={name="Replacement-Realm",classFilename="DRUID",isLeader=true}
G.Applications:SyncAll();G.Results:GetDetails(result)
Check(members[2]~=oldMember,"replacement identities do not overwrite held member objects")
Eq(oldMember.name,"Flagged-Realm");Eq(members[2].name,"Replacement-Realm")
sources[1].members={}
local empty=G.Results:Capture(1,nil,true)
ResetReads();Eq(G.Results:GetFlaggedLeaderClass(empty),nil);Eq(reads.players,0,"empty rosters have no member reads")
C_LFGList.GetApplicationInfo=function(id) return id,"cancelled" end
ResetReads();G.Applications:OnStatusUpdated(1,"cancelled","applied")
Eq(reads.players+reads.counts+reads.relations+reads.progress,0,"terminal events do not fetch member summaries or full details")
print("Application summary performance: "..checks.." checks passed")
