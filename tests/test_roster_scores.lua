-- Isolated player-detail reads: lua tests/test_roster_scores.lua
local checks=0
local function Equal(actual,expected,message)
 checks=checks+1
 if T then T.eq(actual,expected,message) else assert(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected)) end
end
local function Session()
 local s={reads=0,mapReads=0,units={party1="A"},activities={[10]={mapID=100,isMythicPlusActivity=true},[11]={mapID=100}},
  maps={[1]={"Current",1800,100},[2]={"Highest",2100,200},[3]={"Other",2400,300}},
  summary={currentSeasonScore=3200,runs={
   {challengeModeID=1,mapScore=450,bestRunLevel=17,bestRunDurationMS=1700000,finishedSuccess=true},
   {challengeModeID=2,mapScore=300,bestRunLevel=20,bestRunDurationMS=2200000,finishedSuccess=false},
   {challengeModeID=3,mapScore=490,bestRunLevel=18,bestRunDurationMS=2300000,finishedSuccess=true},
  }}}
 local secrets,inaccessible={},{}
 function s:Secret()
  local value=setmetatable({},{__index=function() error("secret read") end,__lt=function() error("secret comparison") end})
  secrets[value]=true;return value
 end
 function s:Inaccessible()
  local value=setmetatable({},{__index=function() error("inaccessible read") end})
  inaccessible[value]=true;return value
 end
 local E=setmetatable({},{__index=_G});E._G=E
 E.canaccesstable=function(value) return not inaccessible[value] end
 local G={Public=function(value) if not secrets[value] then return value end end}
 E.LycheeGroup={Group=G}
 G.Catalog={GetActivity=function(_,id) return s.activities[id] end}
 E.UnitGUID=function(unit) return s.units[unit] end
 E.C_PlayerInfo={GetPlayerMythicPlusRatingSummary=function(unit) Equal(unit,"party1");s.reads=s.reads+1;return s.summary end}
 E.C_ChallengeMode={GetMapUIInfo=function(id)
  s.mapReads=s.mapReads+1;local map=s.maps[id]
  if map then return map[1],nil,map[2],nil,nil,map[3] end
 end}
 -- These operations are forbidden even if an ambient fixture makes them available.
 E.NotifyInspect=function() error("detail read started inspection") end
 E.C_Timer={NewTimer=function() error("detail read started timer") end,NewTicker=function() error("detail read started ticker") end}
 setfenv(assert(loadfile("addon/LycheeGroup_Group/Roster.lua")),E)()
 s.roster=G.Roster;s.member={unit="party1",guid="A"};s.roster.members={s.member}
 return s
end
do
 local s=Session();local scores=s.roster:GetDungeonScores(s.member,10)
 Equal(s.reads,1);Equal(scores.mapScore,450)
 Equal(scores.current.name,"Current");Equal(scores.current.activityID,10);Equal(scores.current.level,17)
 Equal(scores.current.durationMs,1700000,"rating summary uses the native capital-MS duration field")
 Equal(scores.current.timeLimitSeconds,1800);Equal(scores.current.timed,true)
 Equal(scores.best.name,"Highest");Equal(scores.best.level,20,"highest means level, independent of map score")
 Equal(scores.best.durationMs,2200000);Equal(scores.best.timeLimitSeconds,2100);Equal(scores.best.timed,false)
 Equal(scores.best.activityID,nil,"highest run never inherits the current activity")
 Equal(s.member.dungeonScores,nil,"the native summary tree is not retained on roster members")
 s.summary.runs[1].bestRunLevel=21
 Equal(s.roster:GetDungeonScores(s.member,10).best.level,21,"explicit reopen reads current native evidence")
 Equal(scores.current.level,17,"the published detail result owns its normalized values")
 Equal(s.reads,2)
end
do
 local s=Session()
 for _,activityID in ipairs({false,11,99}) do
  local scores=s.roster:GetDungeonScores(s.member,activityID or nil)
  Equal(scores.current,nil,"no current M+ activity leaves the current dungeon unknown")
  Equal(scores.mapScore,nil);Equal(scores.best.level,20)
 end
 Equal(s.mapReads,3,"only the highest run needs metadata without a current M+ map")
end
do
 local s=Session();local reads=s.reads
 Equal(s.roster:GetDungeonScores({unit="party1",guid="A"},10),nil,"a copied identity is not an owned current member")
 s.units.party1="B"
 Equal(s.roster:GetDungeonScores(s.member,10),nil,"reused unit slots cannot expose the departed member's records")
 s.units.party1="A";s.roster.members={}
 Equal(s.roster:GetDungeonScores(s.member,10),nil,"retired objects cannot read native records")
 Equal(s.reads,reads,"invalid identities never query native summaries")
end
do
 local s=Session();local run=s.summary.runs[1]
 s.summary.runs={run};run.bestRunLevel=0;run.mapScore=0
 local scores=s.roster:GetDungeonScores(s.member,10)
 Equal(scores.current,nil);Equal(scores.best,nil);Equal(scores.mapScore,0,"a known zero score is preserved without fabricating a completed run")
 s.summary.runs={};scores=s.roster:GetDungeonScores(s.member,10)
 Equal(scores.current,nil);Equal(scores.best,nil);Equal(scores.mapScore,nil)
 s.summary=nil;Equal(s.roster:GetDungeonScores(s.member,10),nil,"missing native evidence remains unknown")
end
do
 local s=Session();local run=s.summary.runs[2]
 s.summary.runs={run,{challengeModeID=1,mapScore=300,bestRunLevel=20,bestRunDurationMS=1700000,finishedSuccess=true}}
 Equal(s.roster:GetDungeonScores(s.member).best.name,"Current","a tied highest level prefers the timed run")
 s.maps[4]={"Ambiguous",1900,100}
 s.summary.runs[#s.summary.runs+1]={challengeModeID=4,mapScore=500,bestRunLevel=23,finishedSuccess=true}
 local scores=s.roster:GetDungeonScores(s.member,10)
 Equal(scores.current,nil,"two challenge IDs for the same activity map do not establish its current record")
 Equal(scores.mapScore,nil);Equal(scores.best.level,23)
end
do
 local s=Session();local run=s.summary.runs[1]
 s.summary.runs={run,s:Secret(),s:Inaccessible()}
 local badValues={0,-1,math.huge,0/0,"1700000",true,s:Secret()}
 for _,bad in ipairs(badValues) do
  run.bestRunDurationMS=bad
  local scores=s.roster:GetDungeonScores(s.member,10)
  Equal(scores.current.durationMs,nil,"invalid and secret durations are never formatted")
 end
 run.bestRunDurationMS=nil;run.finishedSuccess=s:Secret()
 Equal(s.roster:GetDungeonScores(s.member,10).current.timed,false)
 run.challengeModeID=s:Secret()
 Equal(s.roster:GetDungeonScores(s.member,10).best,nil,"a secret challenge ID cannot identify a dungeon")
 for _,bad in ipairs({s:Secret(),s:Inaccessible()}) do
  s.summary=bad;Equal(s.roster:GetDungeonScores(s.member,10),nil)
  s.summary={runs=bad};Equal(s.roster:GetDungeonScores(s.member,10),nil)
 end
end
if not T then print("Roster scores: "..checks.." checks passed") end
