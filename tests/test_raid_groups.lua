-- Native raid-action boundary, independent of UI snapshots.
local checks=0
local function Equal(a,b,message)
 checks=checks+1;if T then T.eq(a,b,message) else assert(a==b,(message or "value")..": "..tostring(a).." ~= "..tostring(b)) end
end
local function Session()
 local s={raid=true,leader=true,assistant=false,locked=false,playerCombat=false,calls={},rows={
  {guid="A",subgroup=1,combat=false},{guid="B",subgroup=2,combat=false},{guid="P",subgroup=1,combat=false},
 }}
 local secret={};s.secret=secret
 local E=setmetatable({},{__index=_G});E._G=E
 E.LycheeGroup={Group={Public=function(value) if value~=secret then return value end end}}
 E.IsInRaid=function() return s.raid end
 E.UnitIsGroupLeader=function() return s.leader end
 E.UnitIsGroupAssistant=function() return s.assistant end
 E.InCombatLockdown=function() return s.locked end
 E.GetNumGroupMembers=function() return s.count or #s.rows end
 E.UnitGUID=function(unit)
  if unit=="player" then return "P" end
  local row=s.rows[tonumber(unit:match("%d+$"))];return row and row.guid
 end
 E.UnitAffectingCombat=function(unit)
  if unit=="player" then return s.playerCombat end
  local row=s.rows[tonumber(unit:match("%d+$"))];return row and row.combat
 end
 E.GetRaidRosterInfo=function(index)
  if s.onRead then s.onRead(index) end
  local row=s.rows[index];if row then return "Player"..index,0,row.subgroup end
 end
 E.SetRaidSubgroup=function(index,group) s.calls[#s.calls+1]={"set",index,group};if s.fail then error("protected") end end
 E.SwapRaidSubgroup=function(a,b) s.calls[#s.calls+1]={"swap",a,b};if s.fail then error("protected") end end
 setfenv(assert(loadfile("addon/LycheeGroup_Group/RaidGroups.lua")),E)()
 s.service=E.LycheeGroup.Group.RaidGroups
 return s
end
do
 local s=Session();Equal(s.service:CanStart("A"),true);Equal(#s.calls,0)
 local intent=s.service:ResolveDrop("A",3);Equal(intent.mode,"empty");Equal(intent.subgroup,3)
 intent=s.service:ResolveDrop("A",2);Equal(intent.mode,"join")
 intent=s.service:ResolveDrop("A",2,"B");Equal(intent.mode,"swap");Equal(intent.target.guid,"B");Equal(#s.calls,0,"drop descriptions never send native actions")
 Equal(s.service:Drop("A",3),true);Equal(s.calls[1][1],"set");Equal(s.calls[1][2],1);Equal(s.calls[1][3],3)
 Equal(s.rows[1].subgroup,1,"subgroup state is never changed optimistically")
 Equal(s.service:Drop("A",2,"B"),true);Equal(s.calls[2][1],"swap");Equal(s.calls[2][2],1);Equal(s.calls[2][3],2)
 s.rows={s.rows[2],s.rows[3],s.rows[1]}
 Equal(s.service:Drop("A",2,"B"),true);Equal(s.calls[3][2],3);Equal(s.calls[3][3],1,"release resolves current indices from GUIDs")
 s.rows[1].subgroup=4
 Equal(s.service:Drop("A",2,"B"),true,"the live target group wins over the old rendered cell")
end
for _,case in ipairs({
 {"playerCombat",true,"playerCombat"},{"locked",true,"playerCombat"},{"playerCombat","secret","unknown"},
 {"raid",false,"notRaid"},{"leader",false,"permission"},{"leader","secret","permission"},
}) do
 local s=Session();s[case[1]]=case[2]=="secret" and s.secret or case[2]
 local ok,reason=s.service:CanStart("A");Equal(ok,false);Equal(reason,case[3]);Equal(#s.calls,0)
 ok,reason=s.service:Drop("A",3);Equal(ok,false);Equal(reason,case[3]);Equal(#s.calls,0)
end
do
 local s=Session();s.leader=false;s.assistant=true;Equal(s.service:CanStart("A"),true)
 s.rows[1].combat=true;local ok,reason=s.service:Drop("A",3);Equal(ok,false);Equal(reason,"sourceCombat")
 s.rows[1].combat=false;s.rows[2].combat=true
 ok,reason=s.service:Drop("A",2,"B");Equal(ok,false);Equal(reason,"targetCombat");Equal(#s.calls,0)
 s.rows[2].combat=s.secret;ok,reason=s.service:Drop("A",2,"B");Equal(ok,false);Equal(reason,"unknown")
end
do
 local s=Session();Equal(s.service:CanStart("A"),true)
 s.leader=false;local ok,reason=s.service:Drop("A",2,"B");Equal(ok,false);Equal(reason,"permission");Equal(#s.calls,0)
 s.leader=true;s.rows[1].guid="Replacement";ok,reason=s.service:Drop("A",2,"B");Equal(ok,false);Equal(reason,"identity")
 s.rows[1].guid="A";s.onRead=function(index) if index==2 then s.rows[1].guid="Replacement" end end
 ok,reason=s.service:Drop("A",2,"B");Equal(ok,false);Equal(reason,"identity","index reuse during validation cannot receive a stale action")
end
do
 local s=Session();for i=4,7 do s.rows[i]={guid="Other"..i,subgroup=2,combat=false} end
 local ok,reason=s.service:Drop("A",2);Equal(ok,false);Equal(reason,"full");Equal(#s.calls,0)
 local intent;intent,reason=s.service:ResolveDrop("A",2);Equal(intent,nil);Equal(reason,"full","preview and release share full-group validation")
 Equal(s.service:Drop("A",2,"B"),true,"swapping with a member is valid even when their group is full")
 ok,reason=s.service:Drop("A",1);Equal(ok,false);Equal(reason,"same");Equal(#s.calls,1)
 Equal(s.service:Drop("A",8),true,"empty groups remain valid destinations")
 s.rows[4].subgroup=s.secret;ok,reason=s.service:Drop("A",3);Equal(ok,false);Equal(reason,"unknown")
end
do
 local s=Session()
 for _,group in ipairs({0,9,1.5,s.secret}) do local ok=s.service:Drop("A",group);Equal(ok,false) end
 Equal(s.service:CanStart(s.secret),false);Equal(s.service:CanStart("Gone"),false);Equal(#s.calls,0)
 s.rows[1].subgroup=s.secret;Equal(s.service:CanStart("A"),false)
 s.rows[1].subgroup=1;s.count=s.secret;Equal(s.service:CanStart("A"),false)
 s.count=nil;s.fail=true;local ok,reason=s.service:Drop("A",3);Equal(ok,false);Equal(reason,"failed")
end
if not T then print("Raid subgroup actions: "..checks.." checks passed") end
