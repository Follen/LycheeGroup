-- 当前完整结果集只有一个所有者；视图复用排序后的 ID 数组。
local A = _G.LycheeGroup
local G = A.Group
local Results={gen=0}
G.Results=Results
local records,ids,detailQueue,pendingIDs={},{},{},{}
local pendingBulk
-- Keep recently visited rows across filter/sort/scroll changes. The old 16-entry
-- cache discarded the same party snapshots repeatedly during ordinary reordering.
local DETAIL_CAPACITY=64
local count,scan=0,0
local dirty=true
local function Public(value)
 if issecretvalue and issecretvalue(value) then return nil end
 return value
end
G.Public=Public
local function Normalize(id,record,invalidateDetails)
 -- GetTime is constant within one rendered frame. Bulk notifications in that
 -- frame share the normalized record; an explicit result event always rereads.
 local now=GetTime()
 if record and not invalidateDetails and record.sampledAt==now then return record end
 local info=Public(C_LFGList.GetSearchResultInfo(id))
 if type(info)~="table" then return nil end
 local previousActivity=record and record.activityID
 local previousMembers=record and record.numMembers
 local previousLeader=record and record.leaderKey
 local previousRating,previousRatingActivity=record and record.leaderRating,record and record.pvpRatingActivity
 local previousBnet,previousChar,previousGuild=record and record.bnetFriends,record and record.charFriends,record and record.guildMates
 local activityIDs=Public(info.activityIDs)
 local activityID=type(activityIDs)=="table" and Public(activityIDs[1]) or nil
 local activity=G.Catalog:GetActivity(activityID)
 record=record or {id=id}
 record.sampledAt=now
 record.activityID,record.activity=activityID,activity
 record.activityName=activity and activity.name
 record.activityShortName=activity and activity.shortName
 record.categoryID=activity and activity.categoryID
 record.mapID=activity and activity.mapID
 record.difficultyID=activity and activity.difficultyID
 record.maxNumPlayers=activity and activity.maxNumPlayers
 record.name,record.comment=Public(info.name),Public(info.comment)
 record.leaderName=Public(info.leaderName)
 record.leaderKey=G:RemotePlayerKey(record.leaderName)
 record.numMembers=Public(info.numMembers) or 0
 record.age=Public(info.age) or 0
 record.requiredItemLevel=Public(info.requiredItemLevel) or 0
 record.requiredDungeonScore=Public(info.requiredDungeonScore)
 record.leaderOverallDungeonScore=Public(info.leaderOverallDungeonScore)
 record.ratingKind=activity and (activity.isPvpActivity or activity.isRatedPvpActivity) and "pvp" or "dungeon"
 record.requiredPvpRating=Public(info.requiredPvpRating)
 record.leaderPvpRating,record.pvpRatingActivity=nil,nil
 local summaries=record.pvpRatings
 if summaries then wipe(summaries) end
 if activity and activity.isRatedPvpActivity then
  local ratings=Public(info.leaderPvpRatingInfo)
  if type(ratings)=="table" then
   summaries=summaries or {};record.pvpRatings=summaries
   for _,value in ipairs(ratings) do
    local rating=Public(value)
    if type(rating)=="table" then
     rating.bracket,rating.rating,rating.activityName,rating.tier=Public(rating.bracket),Public(rating.rating),Public(rating.activityName),Public(rating.tier)
     summaries[#summaries+1]=rating
    end
   end
  end
  local rating=type(ratings)=="table" and Public(ratings[1])
  if type(rating)=="table" then record.leaderPvpRating=Public(rating.rating);record.pvpRatingActivity=Public(rating.activityName) end
 else record.pvpRatings=nil end
 if record.ratingKind=="pvp" then record.leaderRating,record.requiredRating=record.leaderPvpRating,record.requiredPvpRating
 else record.leaderRating,record.requiredRating=record.leaderOverallDungeonScore,record.requiredDungeonScore end
 record.autoAccept=Public(info.autoAccept)==true
 record.isDelisted=Public(info.isDelisted)==true
 record.hasSelf=Public(info.hasSelf)==true
 record.playstyle=Public(info.playstyle)
 record.crossFactionListing=Public(info.crossFactionListing)==true
 record.bnetFriends,record.charFriends,record.guildMates=Public(info.numBNetFriends) or 0,Public(info.numCharFriends) or 0,Public(info.numGuildMates) or 0
 record.partyGUID=Public(info.partyGUID)
 -- Bulk list events retain unchanged snapshots. A specific result event also
 -- covers member/spec/progress changes that do not change the member count.
 if invalidateDetails or previousActivity~=record.activityID or previousMembers~=record.numMembers or previousLeader~=record.leaderKey or previousRating~=record.leaderRating or previousRatingActivity~=record.pvpRatingActivity or previousBnet~=record.bnetFriends or previousChar~=record.charFriends or previousGuild~=record.guildMates then
  record.detailsDirty=record.details and true or nil;record.memberCounts=nil
 end
 return record
end
function Results:Capture(id,record,invalidateDetails) return Normalize(id,record,invalidateDetails) end
function Results:GetMemberCounts(record)
 if record.memberCounts then return record.memberCounts end
 local native=Public(C_LFGList.GetSearchResultMemberCounts(record.id))
 if type(native)~="table" then return nil end
 -- 原生返回值归本次读取所有，清洗后直接持有，不再包一层小表。
 native.TANK,native.HEALER,native.DAMAGER=Public(native.TANK),Public(native.HEALER),Public(native.DAMAGER)
 record.memberCounts=native
 return native
end
local function RelationNames(values)
 values=Public(values)
 if type(values)~="table" then return {} end
 local names={}
 for _,value in ipairs(values) do
  value=Public(value)
  if type(value)=="string" and value~="" then names[#names+1]=value end
 end
 return names
end
local function MarkRelations(members,names,field)
 for _,name in ipairs(names) do
  local key=G:RemotePlayerKey(name)
  local matched
  for _,member in ipairs(members) do
   if key and member.nameKey==key or not key and member.name and member.name:match("^[^-]+$")==name or not key and member.name and member.name:match("^([^-]+)-")==name then
    if matched then matched=nil;break end
    matched=member
   end
  end
  if matched then matched[field]=true end
 end
end
function Results:GetDetails(idOrRecord)
 local record=type(idOrRecord)=="table" and idOrRecord or records[idOrRecord]
 if not record then return nil end
 local details=record.details
 if details and not record.detailsDirty then return details end
 details=details or {members={}}
 -- Five-player rows show individual members. Their role-count API result also
 -- contains nested class counts, so read it only for an actual role filter.
 local memberCount=0
 details.counts=record.memberCounts or record.maxNumPlayers~=5 and self:GetMemberCounts(record) or nil
 for index=1,record.numMembers do
  local info=Public(C_LFGList.GetSearchResultPlayerInfo(record.id,index))
  if type(info)=="table" then
   local name=Public(info.name)
   local key=G:RemotePlayerKey(name)
   memberCount=memberCount+1
   local previous=details.members[memberCount]
   if key and previous and previous.nameKey==key and previous~=info then
    wipe(previous)
    for field,value in pairs(info) do previous[field]=value end
    info=previous
   end
   info.name=name;info.nameKey=key
   info.class=Public(info.classFilename);info.localizedClass=Public(info.className)
   info.specName=Public(info.specName);info.assignedRole=Public(info.assignedRole)
   info.isLeader=Public(info.isLeader)==true
   info.ratingKind=record.ratingKind
   if record.ratingKind=="pvp" then
    info.rating=info.isLeader and record.leaderPvpRating or nil
    info.pvpRatingInfo=info.isLeader and record.pvpRatings and record.pvpRatings[1] or nil
   else info.rating=Public(info.dungeonScore);info.pvpRatingInfo=nil end
   info.isBNetFriend,info.isCharFriend,info.isGuildMate=false,false,false
   details.members[memberCount]=info
  end
 end
 for index=#details.members,memberCount+1,-1 do details.members[index]=nil end
 details.relationships=nil
 if record.bnetFriends+record.charFriends+record.guildMates>0 then
  local bnet,character,guild=C_LFGList.GetSearchResultFriends(record.id)
  local relations={bnet=RelationNames(bnet),character=RelationNames(character),guild=RelationNames(guild)}
  details.relationships=relations
  MarkRelations(details.members,relations.bnet,"isBNetFriend")
  MarkRelations(details.members,relations.character,"isCharFriend")
  MarkRelations(details.members,relations.guild,"isGuildMate")
 end
 local encounters=Public(C_LFGList.GetSearchResultEncounterInfo(record.id))
 if type(encounters)=="table" then
  details.encounters=details.encounters or {};wipe(details.encounters)
  for _,value in ipairs(encounters) do
   local name=Public(value)
   if type(name)=="string" then details.encounters[#details.encounters+1]=name end
  end
 elseif details.encounters then wipe(details.encounters) end
 record.details=details;record.detailsDirty=nil
 -- 队列仅存 ID，旧结果不会被缓存队列继续强引用。
 if records[record.id]==record then
  for i=#detailQueue,1,-1 do if detailQueue[i]==record.id then table.remove(detailQueue,i);break end end
  detailQueue[#detailQueue+1]=record.id
  if #detailQueue>DETAIL_CAPACITY then local old=records[table.remove(detailQueue,1)];if old then old.details=nil;old.detailsDirty=nil end end
 end
 return details
end
local function MatchesNote(key,kind)
 local note=key and A.Notes:Find(key)
 return note and (kind=="any" or note.type==kind)
end
local function MatchesLeaderText(record,text)
 if type(text)~="string" then return true end
 text=text:lower():match("^%s*(.-)%s*$")
 if text=="" then return true end
 local leader=record.leaderName
 return type(leader)=="string" and leader:lower():find(text,1,true)~=nil
end
local function Pass(record,filters)
 if G.Applications:IsActive(record.id) then return false end
 if filters.leaderText and not MatchesLeaderText(record,filters.leaderText) then return false end
 if filters.category and not G.Catalog:Matches(record.activity,filters.category,filters.groupKey,filters.difficultyID,filters.tier,filters.groupKeys) then return false end
 if filters.personKey then
  local match=record.leaderKey==filters.personKey
  if not match then for _,member in ipairs(Results:GetDetails(record).members) do if member.nameKey==filters.personKey then match=true;break end end end
  if not match then return false end
 end
 if filters.minMembers and record.numMembers<filters.minMembers then return false end
 if filters.maxMembers and record.numMembers>filters.maxMembers then return false end
 if filters.neededRole then
  local counts=Results:GetMemberCounts(record)
  local target=filters.neededRole=="DAMAGER" and 3 or 1
  if record.maxNumPlayers~=5 or not counts or not counts[filters.neededRole] or counts[filters.neededRole]>=target then return false end
 end
 if filters.tankPresence or filters.healerPresence or filters.needsDamage then
  local counts=Results:GetMemberCounts(record)
  if record.maxNumPlayers~=5 or not counts then return false end
  if filters.tankPresence and (counts.TANK==nil or (counts.TANK>0)~=(filters.tankPresence=="present")) then return false end
  if filters.healerPresence and (counts.HEALER==nil or (counts.HEALER>0)~=(filters.healerPresence=="present")) then return false end
  if filters.needsDamage and (counts.DAMAGER==nil or counts.DAMAGER>=3) then return false end
 end
 if filters.friends and record.bnetFriends+record.charFriends==0 then return false end
 if filters.guild and record.guildMates==0 then return false end
 if filters.notes then
  local exclude=filters.notes=="noCaution"
  if not A.Notes then return exclude end
  local kind=exclude and "caution" or filters.notes
  local found=MatchesNote(record.leaderKey,kind)
  if not found then
   for _,member in ipairs(Results:GetDetails(record).members) do if MatchesNote(member.nameKey,kind) then found=true;break end end
  end
  if exclude and found or not exclude and not found then return false end
 end
 return true
end
local sorting
local function Sort(a,b)
 local x,y=records[a],records[b]
 local av,bv
 if sorting=="rating" then av,bv=x.leaderRating or -1,y.leaderRating or -1
 elseif sorting=="members" then av,bv=x.numMembers,y.numMembers
 elseif sorting=="itemLevel" then av,bv=x.requiredItemLevel,y.requiredItemLevel end
 if av and av~=bv then return av>bv end
 if x.age~=y.age then return x.age<y.age end
 return a<b
end
function Results:InvalidateView() dirty=true end
function Results:CancelUpdates()
 G.Game.frame:SetScript("OnUpdate",nil)
 self.updatePending=nil;pendingBulk=nil;wipe(pendingIDs)
end
local function FlushUpdates()
 G.Game.frame:SetScript("OnUpdate",nil);Results.updatePending=nil
 if pendingBulk then
  pendingBulk=nil
  Results:CommitResults(Results.gen,pendingIDs)
 else
  for id in pairs(pendingIDs) do Results:OnResultUpdated(id) end
 end
 wipe(pendingIDs)
end
-- Native events delivered in one frame describe one final native snapshot.
-- Reuse the existing event frame and ID set, reading each affected row once.
function Results:QueueUpdate(id)
 if id then
  if not records[id] then return end
  pendingIDs[id]=true
 else pendingBulk=true end
 if not self.updatePending then
  self.updatePending=true;G.Game.frame:SetScript("OnUpdate",FlushUpdates);G.Game.frame:Show()
 end
end
function Results:BeginSearch(gen)
 self:CancelUpdates()
 self.gen=gen;wipe(records);wipe(detailQueue);wipe(ids);count=0;self:InvalidateView();G:Notify("results")
end
function Results:CommitResults(gen,updatedIDs)
 if gen~=self.gen then return end
 scan=scan+1
 local _,list=C_LFGList.GetFilteredSearchResults()
 for _,id in ipairs(list or {}) do
  local old=records[id]
  local record=Normalize(id,old,updatedIDs and updatedIDs[id])
  if record and not record.isDelisted then
   record.scan=scan;records[id]=record
   if not old then count=count+1 end
  end
 end
 for id,record in pairs(records) do if record.scan~=scan or record.isDelisted then records[id]=nil;count=count-1 end end
 for i=#detailQueue,1,-1 do if not records[detailQueue[i]] then table.remove(detailQueue,i) end end
 self:InvalidateView();G:Notify("results")
end
function Results:FailSearch(gen) if gen==self.gen then self:BeginSearch(gen) end end
function Results:OnResultUpdated(id)
 local record=records[id]
 if not record then return end
 record=Normalize(id,record,true)
 if not record or record.isDelisted then
  records[id]=nil;count=count-1
  for i=#detailQueue,1,-1 do if detailQueue[i]==id then table.remove(detailQueue,i);break end end
 end
 self:InvalidateView();G:Notify("result",id)
end
function Results:GetResults()
 if dirty then
  wipe(ids)
  local filters=G.Search:GetFilters()
  for id,record in pairs(records) do if not record.isDelisted and Pass(record,filters) then ids[#ids+1]=id end end
  sorting=filters.sort or A.db.defaultSort;table.sort(ids,Sort);dirty=false
 end
 return ids
end
function Results:GetResult(id) return records[id] end
function Results:GetCount() return count end
