-- Scale and lifecycle regressions for startup favorites and roster refreshes.
TestStubs.Install({locale="enUS",realm="Realm"})
_G.LycheeGroup={GroupLocale={},Group={Catalog={GetActivity=function(_,id) return {id=id} end}}}
Load.addon("LycheeGroup_Group","CreationPresets.lua")
local Presets=LycheeGroup.CreationPresets
local function Entry(score)
 return {activityID=100,favorite=true,requiredDungeonScore=score}
end

do
 local first,latest,tied=Entry(1000),Entry("1000"),Entry(1000)
 first.usedAt,latest.usedAt,tied.usedAt=1,2,2
 first.questID,latest.questID=0,nil
 local invalid={favorite=true,activityID=100,requiredItemLevel=math.huge}
 local previous={old=true}
 local store={[2]=first,[4]=latest,[6]=tied,[8]=invalid,invalidEntries=previous}
 local result=Presets.New(store,function() error("startup must not notify") end)
 T.eq(#result:Get(),1,"normalized nil/zero and numeric-string duplicates share one favorite")
 T.eq(result:Get()[1],latest,"latest usedAt wins; ties keep the first original slot and object")
 T.eq(latest.usedAt,nil);T.eq(latest.requiredDungeonScore,1000);T.eq(latest.questID,nil)
 T.eq(store.invalidEntries,previous,"existing recovery container stays authoritative")
 T.eq(previous[1].value,invalid,"quarantine retains the original invalid object")
end

do
 local values={0,-0,1,1+2^-52,9007199254740991,9007199254740992,2^-1022,2^-1074,1e308}
 local store={}
 for i,value in ipairs(values) do store[i]=Entry(value) end
 T.eq(tostring(values[3]),tostring(values[4]),"the fixture includes distinct doubles with the same ordinary string")
 T.ok(values[3]~=values[4]);T.ok(values[5]~=values[6]);T.ok(values[8]>0)
 local result=Presets.New(store,function() end)
 T.eq(#result:Get(),#values-1,"only positive/negative zero deduplicate; adjacent finite doubles remain distinct")
 for _,value in ipairs(values) do
  local found=false
  for _,entry in ipairs(result:Get()) do if entry.requiredDungeonScore==value then found=true;break end end
  T.ok(found,"every exact numeric favorite remains available")
 end
 local flags=Presets.New({{favorite=true,activityID=100,autoAccept=true},{favorite=true,activityID=100,autoAccept=false}},function() end)
 T.eq(#flags:Get(),2,"boolean fields remain part of the duplicate identity")
 local aliases=Presets.New({{favorite=true,activityID=100,isAutoAccept=true,isPrivateGroup=true},{favorite=true,activityID=100,autoAccept=true,privateGroup=true}},function() end)
 T.eq(#aliases:Get(),1,"legacy aliases deduplicate after normalization")
 local allFields={Entry(0)}
 for _,key in ipairs({"activityID","requiredItemLevel","requiredDungeonScore","requiredPvpRating","autoAccept","privateGroup","isCrossFactionListing","newPlayerFriendly","playstyle","generalPlaystyle","questID"}) do
  local entry=Entry(0)
  entry[key]=key=="activityID" and 101 or (key=="autoAccept" or key=="privateGroup" or key=="isCrossFactionListing" or key=="newPlayerFriendly") and true or 1
  allFields[#allFields+1]=entry
 end
 T.eq(#Presets.New(allFields,function() end):Get(),12,"each of the eleven normalized fields contributes to favorite identity")
end

do
 local samples={}
 for _,size in ipairs({128,256,512}) do
  local store={}
  for i=1,size do store[i]=Entry(i) end
  local ticks=0
  local previous,mask,count=debug.gethook()
  debug.sethook(function() ticks=ticks+1 end,"",1000)
  local result=Presets.New(store,function() end)
  debug.sethook(previous,mask,count)
  T.eq(#result:Get(),size,"scale verification keeps every unique favorite")
  samples[size]=ticks
 end
 T.ok(samples[512]<samples[128]*7,"four times the favorites must not approach quadratic startup work")
end

-- Use the real Group dispatch and Roster owner, with a native forty-member raid.
_G.LycheeGroup={GroupLocale={}}
local A=LycheeGroup
function A:PlayerKey(name,realm) return realm and name.."-"..realm or name end
function A:UnitIdentity(unit)
 local index=unit=="player" and 1 or tonumber(unit:match("%d+"))
 return "Member"..index.."-Realm","Member"..index,"Realm"
end
local equipped,reads,updates,scheduled=260,0,0,0
local jobs={}
_G.GetTime=function() return 100 end
_G.IsInRaid=function() return true end
_G.GetNumGroupMembers=function() return 40 end
_G.UnitGUID=function(unit) return "GUID-"..(unit=="player" and 1 or unit:match("%d+")) end
_G.UnitClassBase=function() return "MAGE" end
_G.UnitFactionGroup=function() return "Alliance" end
_G.UnitGroupRolesAssigned=function() return "DAMAGER" end
_G.UnitIsGroupLeader=function() return false end
_G.UnitIsUnit=function(unit,other) return unit==other or unit=="raid1" and other=="player" end
_G.GetRaidRosterInfo=function(index) return "Member"..index,nil,math.ceil(index/5) end
_G.GetAverageItemLevel=function() return equipped,equipped end
_G.InCombatLockdown=function() return false end
_G.PLAYER_FACTION_GROUP={Alliance=1}
_G.C_PaperDollInfo={GetInspectItemLevel=function() return 260 end}
_G.C_PlayerInfo={GetPlayerMythicPlusRatingSummary=function() reads=reads+1;return {currentSeasonScore=3000} end}
_G.C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 62 end,GetInspectSpecialization=function() return 62 end}
_G.C_Timer={NewTimer=function(delay,callback)
 scheduled=scheduled+1
 local job={delay=delay,callback=callback,Cancel=function(self) self.cancelled=true end}
 jobs[#jobs+1]=job;return job
end}
local function Flush()
 local due=jobs;jobs={}
 for _,job in ipairs(due) do if not job.cancelled then job.callback() end end
end
Load.addon("LycheeGroup_Group","Group.lua")
local G=A.Group
G.Game={RefreshApplicationSubscriptions=function() end}
G.Relations={GetVersion=function() return 1 end,Apply=function() end}
G.History={OnSpecUpdate=function() end}
Load.addon("LycheeGroup_Group","Roster.lua")
G.Roster:SetActive(true);G:GetRoster()
G:Subscribe(function(kind) if kind=="roster" then updates=updates+1;G:GetRoster() end end)
reads,scheduled=0,0
for i=1,17 do equipped=260+i;G:OnEvent("PLAYER_EQUIPMENT_CHANGED",i,true) end
T.eq(updates,0,"same-frame native events defer the visual notification")
T.eq(reads,0,"same-frame equipment events do not proactively rebuild forty-member metadata")
T.eq(scheduled,1,"all native invalidations share the existing single refresh timer")
local members=G:GetRoster()
T.eq(members[1].itemLevel,277,"an explicit read sees the latest equipment immediately")
T.eq(reads,40)
Flush();T.eq(updates,1);T.eq(reads,40,"notification reuses an explicitly read snapshot")
for _,member in ipairs(members) do
 T.eq(member.specID,62);T.eq(member.dungeonScore,3000)
 T.eq(member.itemLevel,member.isSelf and 277 or 260)
end
G:OnEvent("PLAYER_ROLES_ASSIGNED")
G.Roster:OnLibrarySpec(63,"Member2-Realm")
T.eq(G.Roster:GetCachedSpec("GUID-2"),63,"library state is immediately readable within the same pending native refresh")
T.eq(scheduled,2,"library and native events share one pending notification")
Flush();T.eq(updates,2);T.eq(reads,80)
G:OnEvent("PLAYER_EQUIPMENT_CHANGED",1,true)
local previousUpdates=updates
G.Roster:SetActive(false)
T.eq(G.Roster.refreshTimer,nil)
Flush();T.eq(updates,previousUpdates,"leaving cancels the pending visual notification")

-- Membership cancellation must not wait for the coalesced visual refresh.
G.Roster:SetActive(true);G:GetRoster()
local cancelled=false
G.Roster.timer={Cancel=function() cancelled=true end}
G.Roster.pending={guid="DEPARTED",unit="raid40"}
G.Roster.librarySpecs.DEPARTED=63
G.Roster.inspected.DEPARTED={specID=63}
G.Roster:Invalidate("group")
T.eq(G.Roster.pending,nil,"a departed inspection is cancelled during the membership event")
T.eq(cancelled,true)
T.eq(G.Roster.librarySpecs.DEPARTED,nil);T.eq(G.Roster.inspected.DEPARTED,nil)
G.Roster:SetActive(false)
