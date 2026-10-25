-- 当前观察者的角色好友、战网游戏角色和公会身份；不保存账号昵称或成员原表。
local A=_G.LycheeGroup
local G=A.Group
local R={names={},guids={},shortNames={},dirty=true,dirtySources=7,version=0}
G.Relations=R
local BNET,CHARACTER,GUILD,ALL=1,2,4,7
local memberNames={}
local sampledNames,sampledGUIDs={},{}
local notifiedVersion=0
-- Each current friend owns only normalized WoW identities, never the native
-- account record. A presence event replaces that friend's entries in place.
local bnetFriends,bnetUpdates={},{}
local bnetFull,bnetCount=true,0
local function Clear()
 -- Consumers can outlive event ownership briefly (for example an applicant
 -- awaiting its removal event). Clearing a nonempty index invalidates them.
 if next(R.names) or next(R.guids) then R.version=R.version+1 end
 wipe(R.names);wipe(R.guids);wipe(R.shortNames)
 wipe(sampledNames);wipe(sampledGUIDs)
 wipe(bnetFriends);wipe(bnetUpdates);bnetFull,bnetCount=true,0
 R.guildClubID,R.sampledAt=nil,nil;R.dirty=true;R.dirtySources=ALL;notifiedVersion=R.version
end
local function Schedule()
 if R.timer then return end
 R.timer=C_Timer.NewTimer(0,function()
  R.timer=nil
  if not R.active then Clear();return end
  -- A solo/empty view has not consumed a social snapshot yet. Leave it lazy.
  if R.sampledAt==nil then return end
  local version=R:GetVersion()
  if version~=notifiedVersion then
   notifiedVersion=version
   G:Notify("relations")
  end
 end)
end

local function Identity(name,realm,guid)
 name,realm,guid=G.Public(name),G.Public(realm),G.Public(guid)
 local key
 if realm and realm~="" or type(name)=="string" and name:find("-",1,true) then
  key=A:PlayerKey(name,realm)
 elseif guid then
  local _,_,_,_,_,resolvedName,resolvedRealm=GetPlayerInfoByGUID(guid)
  if G.Public(resolvedName) and G.Public(resolvedRealm)~=nil then key=A:PlayerKey(resolvedName,resolvedRealm) end
 end
 return key,guid
end
local function AddIdentity(flag,key,guid)
 if guid then sampledGUIDs[guid]=bit.bor(sampledGUIDs[guid] or 0,flag) end
 if key then sampledNames[key]=bit.bor(sampledNames[key] or 0,flag) end
end
local function Add(flag,name,realm,guid)
 AddIdentity(flag,Identity(name,realm,guid))
end
-- Compare identity sets, not native order or duplicate account ownership.
-- Preserve other source bits and leave unchanged entries untouched.
local function MergeSource(map,sampled,sources)
 local changed,keysChanged=false,false
 for key,flags in pairs(map) do
  local current=flags-bit.band(flags,sources)+(sampled[key] or 0)
  sampled[key]=nil
  if current~=flags then
   map[key]=current>0 and current or nil;changed=true
   if current==0 then keysChanged=true end
  end
 end
 for key,flags in pairs(sampled) do map[key]=flags;changed,keysChanged=true,true end
 wipe(sampled)
 return changed,keysChanged
end
local function ReadBnetFriend(index)
 local identities=bnetFriends[index]
 local count=0
 for account=1,C_BattleNet.GetFriendNumGameAccounts(index) do
  local info=G.Public(C_BattleNet.GetFriendGameAccountInfo(index,account))
  if info and G.Public(info.clientProgram)==BNET_CLIENT_WOW and G.Public(info.wowProjectID)==WOW_PROJECT_ID
   and G.Public(info.isOnline) and G.Public(info.isInCurrentRegion) then
   local key,guid=Identity(info.characterName,info.realmName,info.playerGuid)
   if key or guid then
    if not identities then identities={};bnetFriends[index]=identities end
    count=count+1
    local identity=identities[count] or {};identities[count]=identity
    identity.key,identity.guid=key,guid
   end
  end
 end
 if identities then for i=#identities,count+1,-1 do identities[i]=nil end end
end
local function RefreshBnet()
 local count=BNGetNumFriends()
 if bnetFull or count~=bnetCount then
  for index=1,count do ReadBnetFriend(index) end
  for index in pairs(bnetFriends) do if index>count then bnetFriends[index]=nil end end
 else
  for index in pairs(bnetUpdates) do if index<=count then ReadBnetFriend(index) end end
 end
 bnetFull,bnetCount=false,count;wipe(bnetUpdates)
 for _,identities in pairs(bnetFriends) do
  for _,identity in ipairs(identities) do AddIdentity(BNET,identity.key,identity.guid) end
 end
end

function R:GetVersion()
 if self.active and not self.dirty then return self.version end
 local now=GetTime()
 -- A hidden one-off reader can request a fresh snapshot without owning events.
 -- Within one frame it shares that snapshot with the rest of its member batch.
 if self.dirty or not self.active and self.sampledAt~=now then
  local firstSample=self.sampledAt==nil
  local sources=self.dirtySources
  if not self.active and self.sampledAt~=now then sources=ALL;bnetFull=true end
  wipe(sampledNames);wipe(sampledGUIDs)
  if bit.band(sources,CHARACTER)~=0 and C_FriendList.IsLegacyFriendSystemEnabled() then
   for index=1,C_FriendList.GetNumFriends() do
    local info=G.Public(C_FriendList.GetFriendInfoByIndex(index))
    if info then Add(CHARACTER,info.name,nil,info.guid) end
   end
  end
  if bit.band(sources,BNET)~=0 then RefreshBnet() end
  if bit.band(sources,GUILD)~=0 then
   self.guildClubID=C_Club.GetGuildClubId()
   if self.guildClubID then
    -- The scalar roster includes offline members independently of the native
    -- display filter. Avoid allocating one full ClubMemberInfo per identity.
    for index=1,GetNumGuildMembers() do
     local name,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,guid=GetGuildRosterInfo(index)
     Add(GUILD,name,nil,guid)
    end
   end
  end
  local namesChanged,keysChanged=MergeSource(self.names,sampledNames,sources)
  local guidsChanged=MergeSource(self.guids,sampledGUIDs,sources)
  if keysChanged then
   wipe(self.shortNames)
   for key in pairs(self.names) do
    local short=key:match("^([^-]+)");local previous=self.shortNames[short]
    if previous==nil then self.shortNames[short]=key
    elseif previous~=key then self.shortNames[short]=false end
   end
  end
  if namesChanged or guidsChanged then self.version=self.version+1 end
  self.sampledAt,self.dirty,self.dirtySources=now,false,0
  -- First consumption supplies its own current data; later synchronous reads
  -- must leave an already-scheduled change notification pending.
  if firstSample then notifiedVersion=self.version end
  if not self.active and (next(self.names) or next(self.guids)) then Schedule() end
 end
 return self.version
end

-- Native generic "friend" is deliberately not reclassified as Battle.net.
-- Applicants and the current roster use this index; search keeps native group lists.
function R:Apply(member,matchNameOnly)
 if member.isSelf then
  member.isBNetFriend,member.isCharFriend,member.isGuildMate,member.isFriend=false,false,false,false
  return member
 end
 self:GetVersion()
 local key=member.nameKey or member.realm and member.realm~="" and A:PlayerKey(member.name,member.realm) or G:RemotePlayerKey(member.name)
 local flags=bit.bor(self.names[key] or 0,self.guids[member.guid] or 0)
 -- LFG may return only a character name. Resolve display relationships from
 -- a unique real character, without inventing a canonical player identity.
 if matchNameOnly and not key and not member.guid then
  local identity=self.shortNames[member.name]
  if identity then flags=self.names[identity] end
 end
 member.isBNetFriend=bit.band(flags,BNET)~=0
 member.isCharFriend=bit.band(flags,CHARACTER)~=0 or member.nativeCharFriend==true
 member.isGuildMate=bit.band(flags,GUILD)~=0 or member.nativeGuildMate==true or member.relationship=="guild"
 member.isFriend=member.relationship=="friend" and not member.isBNetFriend and not member.isCharFriend
 return member
end

function R:ApplyMembers(members)
 local version=self:GetVersion()
 for _,member in ipairs(members) do
  local name=member.name or member.nameKey
  local short=name and name:match("^([^-]+)")
  if short then memberNames[short]=(memberNames[short] or 0)+1 end
 end
 for _,member in ipairs(members) do self:Apply(member,memberNames[member.name]==1) end
 wipe(memberNames)
 return version
end

function R:SetActive(active)
 if self.active==active then return end
 if self.timer then self.timer:Cancel();self.timer=nil end
 self.active,self.dirty=active,true;self.sampledAt=nil;self.dirtySources=ALL;bnetFull=true
 if active then
  if C_FriendList.IsLegacyFriendSystemEnabled() then C_FriendList.ShowFriends() end
  if IsInGuild() then C_GuildInfo.GuildRoster() end
 else
  Clear()
 end
end

function R:OnChanged(source,friendIndex)
 local flag=source=="bnet" and BNET or source=="character" and CHARACTER or source=="guild" and GUILD or ALL
 if bit.band(flag,BNET)~=0 then
  friendIndex=G.Public(friendIndex)
  if source=="bnet" and type(friendIndex)=="number" and friendIndex>=1 and friendIndex%1==0 and friendIndex<=bnetCount then
   if not bnetFull then bnetUpdates[friendIndex]=true end
  else bnetFull=true;wipe(bnetUpdates) end
 end
 self.dirty=true;self.dirtySources=bit.bor(self.dirtySources,flag)
 if self.active then Schedule() end
end

function R:OnClubChanged(id)
 if id==self.guildClubID or id==C_Club.GetGuildClubId() then self:OnChanged("guild") end
end
