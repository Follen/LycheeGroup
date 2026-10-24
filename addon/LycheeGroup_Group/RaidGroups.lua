-- Raid subgroup actions resolve current native identities at each user action.
-- No roster snapshot or optimistic subgroup state is retained by this service.
local G=_G.LycheeGroup.Group
local R={};G.RaidGroups=R
local function Guid(value)
 value=G.Public(value)
 return type(value)=="string" and value~="" and value or nil
end
local function Group(value)
 value=G.Public(value)
 return type(value)=="number" and value>=1 and value<=8 and value%1==0 and value or nil
end
local function Permission()
 if G.Public(IsInRaid())~=true then return false,"notRaid" end
 if G.Public(UnitIsGroupLeader("player"))~=true and G.Public(UnitIsGroupAssistant("player"))~=true then return false,"permission" end
 local locked=G.Public(InCombatLockdown())
 local combat=G.Public(UnitAffectingCombat("player"))
 if locked==true or combat==true then return false,"playerCombat" end
 if locked~=false or combat~=false then return false,"unknown" end
 return true
end
local function Resolve(guid)
 guid=Guid(guid);if not guid then return nil,"identity" end
 local count=G.Public(GetNumGroupMembers())
 if type(count)~="number" or count<1 or count>40 or count%1~=0 then return nil,"unknown" end
 for index=1,count do
  local unit="raid"..index
  if Guid(UnitGUID(unit))==guid then
   local name,_,subgroup=GetRaidRosterInfo(index)
   subgroup=Group(subgroup)
   if not subgroup then return nil,"unknown" end
   return {guid=guid,unit=unit,index=index,subgroup=subgroup,name=G.Public(name)}
  end
 end
 return nil,"identity"
end
local function Combat(member,reason)
 local value=G.Public(UnitAffectingCombat(member.unit))
 if value==true then return false,reason end
 if value~=false then return false,"unknown" end
 return true
end
function R:CanStart(guid)
 local allowed,reason=Permission();if not allowed then return false,reason end
 local member;member,reason=Resolve(guid);if not member then return false,reason end
 return Combat(member,"sourceCombat")
end
function R:ResolveDrop(guid,subgroup,targetGUID)
 local allowed,reason=Permission();if not allowed then return nil,reason end
 subgroup=Group(subgroup);if not subgroup then return nil,"unknown" end
 local source;source,reason=Resolve(guid);if not source then return nil,reason end
 allowed,reason=Combat(source,"sourceCombat");if not allowed then return nil,reason end
 local target
 local size=0
 if targetGUID~=nil then
  target,reason=Resolve(targetGUID);if not target then return nil,reason end
  -- The member's current subgroup wins over an old rendered drop position.
  subgroup=target.subgroup
 else
  local count=G.Public(GetNumGroupMembers())
  if type(count)~="number" or count<1 or count>40 or count%1~=0 then return nil,"unknown" end
  for index=1,count do
   local _,_,value=GetRaidRosterInfo(index);value=Group(value)
   if not value then return nil,"unknown" end
   if value==subgroup then size=size+1 end
  end
  if source.subgroup~=subgroup and size>=5 then return nil,"full" end
 end
 if source.subgroup==subgroup then return nil,"same" end
 if target then allowed,reason=Combat(target,"targetCombat");if not allowed then return nil,reason end end
 -- Never let a reused raid index receive an action meant for a departed GUID.
 if Guid(UnitGUID(source.unit))~=source.guid or target and Guid(UnitGUID(target.unit))~=target.guid then return nil,"identity" end
 return {mode=target and "swap" or size==0 and "empty" or "join",subgroup=subgroup,source=source,target=target}
end
function R:Drop(guid,subgroup,targetGUID)
 local intent,reason=self:ResolveDrop(guid,subgroup,targetGUID)
 if not intent then return false,reason end
 local ok
 if intent.target then ok=pcall(SwapRaidSubgroup,intent.source.index,intent.target.index)
 else ok=pcall(SetRaidSubgroup,intent.source.index,intent.subgroup) end
 return ok,not ok and "failed" or nil
end
