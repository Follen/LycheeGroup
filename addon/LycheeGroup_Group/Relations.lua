-- 当前观察者的角色好友、战网游戏角色和公会身份；不保存账号昵称或成员原表。
local A=_G.LycheeGroup
local G=A.Group
local R={names={},guids={},shortNames={},available=0,dirty=true,version=0}
G.Relations=R
local BNET,CHARACTER,GUILD=1,2,4
local memberNames={}
local function Clear()
 wipe(R.names);wipe(R.guids);wipe(R.shortNames)
 R.guildClubID,R.sampledAt=nil,nil;R.available=0;R.dirty=true
end
local function Schedule()
 if R.timer then return end
 R.timer=C_Timer.NewTimer(0,function()
  R.timer=nil
  if R.active then G:Notify("relations") else Clear() end
 end)
end

local function Add(flag,name,realm,guid)
 name,realm,guid=G.Public(name),G.Public(realm),G.Public(guid)
 if guid then R.guids[guid]=bit.bor(R.guids[guid] or 0,flag) end
 local key
 if realm and realm~="" or type(name)=="string" and name:find("-",1,true) then
  key=A:PlayerKey(name,realm)
 elseif guid then
  local _,_,_,_,_,resolvedName,resolvedRealm=GetPlayerInfoByGUID(guid)
  if G.Public(resolvedName) and G.Public(resolvedRealm)~=nil then key=A:PlayerKey(resolvedName,resolvedRealm) end
 end
 if key then
  R.names[key]=bit.bor(R.names[key] or 0,flag)
  local short=key:match("^([^-]+)");local previous=R.shortNames[short]
  if previous==nil then R.shortNames[short]=key
  elseif previous~=key then R.shortNames[short]=false end
 end
 if key or guid then R.available=bit.bor(R.available,flag) end
end

function R:GetVersion()
 local now=GetTime()
 -- A hidden one-off reader can request a fresh snapshot without owning events.
 -- Within one frame it shares that snapshot with the rest of its member batch.
 if self.dirty or not self.active and self.sampledAt~=now then
  wipe(self.names);wipe(self.guids);wipe(self.shortNames);self.available=0
  if C_FriendList.IsLegacyFriendSystemEnabled() then
   for index=1,C_FriendList.GetNumFriends() do
    local info=G.Public(C_FriendList.GetFriendInfoByIndex(index))
    if info then Add(CHARACTER,info.name,nil,info.guid) end
   end
  end
  for index=1,BNGetNumFriends() do
   for account=1,C_BattleNet.GetFriendNumGameAccounts(index) do
    local info=G.Public(C_BattleNet.GetFriendGameAccountInfo(index,account))
    if info and G.Public(info.clientProgram)==BNET_CLIENT_WOW and G.Public(info.wowProjectID)==WOW_PROJECT_ID
     and G.Public(info.isOnline) and G.Public(info.isInCurrentRegion) then
     Add(BNET,info.characterName,info.realmName,info.playerGuid)
    end
   end
  end
  self.guildClubID=C_Club.GetGuildClubId()
  if self.guildClubID then
   local members=G.Public(C_Club.GetClubMembers(self.guildClubID))
   for _,id in ipairs(members or {}) do
    id=G.Public(id)
    if id then
     local info=G.Public(C_Club.GetMemberInfo(self.guildClubID,id))
     if info then Add(GUILD,info.name,nil,info.guid) end
    end
   end
  end
  self.sampledAt,self.dirty=now,false;self.version=self.version+1
  if not self.active and (next(self.names) or next(self.guids)) then Schedule() end
 end
 return self.version
end

function R:CanMatch(kind)
 self:GetVersion()
 return bit.band(self.available,kind=="guild" and GUILD or BNET+CHARACTER)~=0
end

-- Native generic "friend" is deliberately not reclassified as Battle.net.
-- Results may additionally provide explicit native character/guild evidence.
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
 self.active,self.dirty=active,true;self.sampledAt=nil
 if active then
  if C_FriendList.IsLegacyFriendSystemEnabled() then C_FriendList.ShowFriends() end
  if IsInGuild() then C_GuildInfo.GuildRoster() end
 else
  Clear()
 end
end

function R:OnChanged()
 self.dirty=true
 G.Results:InvalidateView()
 if self.active then Schedule() end
end

function R:OnClubChanged(id)
 if id==self.guildClubID or id==C_Club.GetGuildClubId() then self:OnChanged() end
end
