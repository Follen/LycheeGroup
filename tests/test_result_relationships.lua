-- Real result/application owners: complete current names with no container churn.
TestStubs.Install({locale="enUS",realm="Realm"})
local secret={}
local S={ids={1},applications={},friends={},counts={bnet=1,character=1,guild=1},friendReads=0}
_G.GetTime=function() return 100 end
local A={Group={db={blockedLeaders={}},Game={frame=CreateFrame("Frame"),RefreshApplicationSubscriptions=function() end}}}
_G.LycheeGroup=A
local G=A.Group
function A:PlayerKey(name,realm)
 if not name then return end
 return name:find("-",1,true) and name or name.."-"..(realm or "Realm")
end
function A:UnitIdentity() return "Self-Realm" end
G.Public=function(value) if value~=secret then return value end end
G.RemotePlayerKey=function(_,name) return name and name:find("-",1,true) and name or nil end
G.Notify=function() end
local activity={id=100,categoryID=2,maxNumPlayers=5,name="Dungeon"}
G.Catalog={GetActivity=function() return activity end}
_G.C_LFGList={
 GetFilteredSearchResults=function() return #S.ids,S.ids end,
 GetSearchResultInfo=function(id)
  return {activityIDs={100},name="Group "..id,leaderName="Friend-Realm",partyGUID="Party-"..id,numMembers=1,
   numBNetFriends=S.counts.bnet,numCharFriends=S.counts.character,numGuildMates=S.counts.guild}
 end,
 GetSearchResultPlayerInfo=function() return {name="Friend-Realm",classFilename="MAGE",isLeader=true,assignedRole="DAMAGER"} end,
 GetSearchResultFriends=function() S.friendReads=S.friendReads+1;return S.friends.bnet,S.friends.character,S.friends.guild end,
 GetApplications=function() return S.applications end,
 GetApplicationInfo=function(id) return id,"applied",nil,120 end,
}
Load.addon("LycheeGroup_Group","Results.lua")
Load.addon("LycheeGroup_Group","Applications.lua")
S.friends={bnet={"Nickname","",secret,"Duplicate","Duplicate"},character={"Friend-Realm","Other-Realm"},guild={"Self-Realm","Guild-Realm","Self-Elsewhere"}}
G.Results:BeginSearch(1);G.Results:CommitResults(1)
local record=G.Results:GetResult(1)
local details=G.Results:GetDetails(record)
local relations=details.relationships
local bnet,character,guild=relations.bnet,relations.character,relations.guild
T.same(bnet,{"Nickname","Duplicate","Duplicate"},"public native names retain their complete order and duplicates")
T.same(character,{"Friend-Realm","Other-Realm"})
T.same(guild,{"Guild-Realm","Self-Elsewhere"},"only the observer's complete identity is excluded")
for round=1,100 do
 S.friends.bnet[1]="Nickname "..round
 G.Results:OnResultUpdated(1)
 T.eq(G.Results:GetDetails(record),details)
 T.eq(details.relationships,relations)
 T.eq(relations.bnet,bnet);T.eq(relations.character,character);T.eq(relations.guild,guild)
 T.eq(bnet[1],"Nickname "..round,"the reused array holds the latest native content")
end
S.friends={bnet={},character={},guild={}}
for index=1,128 do
 S.friends.bnet[index]="Nickname "..index
 S.friends.character[index]="Character"..index.."-Realm"
 S.friends.guild[index]="Guild"..index.."-Realm"
end
G.Results:OnResultUpdated(1);G.Results:GetDetails(record)
T.eq(details.relationships,relations)
T.same(bnet,S.friends.bnet);T.same(character,S.friends.character);T.same(guild,S.friends.guild,"all native names survive growth beyond a visible roster")
S.friends={bnet=secret,character=nil,guild={"Self","Guild2-Realm"}}
G.Results:OnResultUpdated(1);G.Results:GetDetails(record)
T.eq(details.relationships,relations)
T.same(bnet,{},"restricted source removes previous names")
T.same(character,{},"missing source removes previous names")
T.same(guild,{"Guild2-Realm"},"bare observer name is also excluded")
S.counts={bnet=0,character=0,guild=0}
G.Results:OnResultUpdated(1);local reads=S.friendReads;G.Results:GetDetails(record)
T.eq(details.relationships,nil,"zero relationships have no retained container pool")
T.same(bnet,{});T.same(character,{});T.same(guild,{},"retained former arrays no longer reference old player names")
T.eq(S.friendReads,reads,"zero relationships do not read native name lists")
S.counts={bnet=1,character=0,guild=0};S.friends={bnet={"New nickname"}}
G.Results:OnResultUpdated(1);G.Results:GetDetails(record)
T.ok(details.relationships~=relations,"a removed relationship container is not kept as an extra pool")
T.same(details.relationships,{bnet={"New nickname"},character={},guild={}})

-- The application's result is the same owner, including after LRU eviction.
S.applications={1};G.Applications:SyncAll()
local app=G.Applications:GetApplication(1)
T.eq(app.result,record);T.eq(G.Results:GetDetails(app.result),details)
local shared=details.relationships
S.friends.bnet={"Application nickname"};G.Results:OnResultUpdated(1)
T.eq(G.Results:GetDetails(app.result).relationships,shared)
T.eq(shared.bnet[1],"Application nickname")
S.ids={};for id=1,65 do S.ids[id]=id end
G.Results:CommitResults(1)
for id=2,65 do G.Results:GetDetails(id) end
T.eq(record.details,nil,"the existing 64-result LRU still evicts the oldest full detail")
local rebuilt=G.Results:GetDetails(app.result)
T.ok(rebuilt~=details);T.ok(rebuilt.relationships~=shared,"LRU eviction does not retain a hidden relationship pool")
T.same(rebuilt.relationships,{bnet={"Application nickname"},character={},guild={}})
G.Results:BeginSearch(2)
T.eq(G.Results:GetResult(1),nil)
T.eq(G.Applications:GetApplication(1).result,record,"a submitted application continues owning its result after browse ends")
local applicationRelations=rebuilt.relationships
S.friends.bnet={"Hidden application nickname"}
G.Results:Capture(1,app.result,true)
T.eq(G.Results:GetDetails(app.result).relationships,applicationRelations)
T.eq(applicationRelations.bnet[1],"Hidden application nickname")
S.applications={};G.Applications:SyncAll()
T.eq(G.Applications:GetActiveCount(),0)
T.eq(TestStubs.PendingTimers(),0)
T.eq(G.Game.frame:GetScript("OnUpdate"),nil)
