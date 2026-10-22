-- 当前完整结果集只有一个所有者；视图复用排序后的 ID 数组。
local A = _G.LycheeGroup
local G = A.Group
local Results={gen=0}
G.Results=Results
local function InRange(value,minimum,maximum)
 if not minimum and not maximum then return true end
 return type(value)=="number" and value>=0 and (not minimum or value>=minimum) and (not maximum or value<=maximum)
end
function Results:MatchesNumericFilters(record,filters)
 return InRange(record.requiredItemLevel,filters.minItemLevel,filters.maxItemLevel)
  and InRange(record.leaderRating,filters.minRating,filters.maxRating)
end
local ROLE_FILTERS={{"tankPresence","TANK",1},{"healerPresence","HEALER",1},{"damagePresence","DAMAGER",3}}
function Results:MatchesRolePresence(counts,filters,maximum)
 local enabled,matched=0,0
 for _,entry in ipairs(ROLE_FILTERS) do
  local value=filters[entry[1]]
  if value then
   enabled=enabled+1
   local count=counts and counts[entry[2]]
   if count~=nil and (count>=entry[3])==(value=="present") then matched=matched+1 end
  end
 end
 if enabled==0 then return true end
 if maximum~=5 or not counts then return false end
 if filters.roleMatchAny then return matched>0 end
 return matched==enabled
end
local records,ids,detailQueue,pendingIDs,changedIDs={},{},{},{},{}
-- Native title tokens change across searches. Keep them in-session only;
-- matching leaders use their complete player keys in the account saved data.
local blockedTitles,blockedTitleCount={},0
local unblockedLeaders,blockedLeaderIDs={},{}
local blockedLeadersDirty=true
local pendingBulk,committing
local updateVersion=0
local BULK_INTERVAL=.2
local nextBulkAt=0
-- Keep recently visited rows across filter/sort/scroll changes. The old 16-entry
-- cache discarded the same party snapshots repeatedly during ordinary reordering.
local DETAIL_CAPACITY=64
local count,scan=0,0
local dirty=true
local Public=G.Public
local function RememberBlockedLeader(record)
 if blockedTitles[record.name] and record.leaderKey and not unblockedLeaders[record.leaderKey] and not G.db.blockedLeaders[record.leaderKey] then
  G.db.blockedLeaders[record.leaderKey]=true
  blockedLeadersDirty=true
  return true
 end
end
local function Normalize(id,record,invalidateDetails,expectedScan,metadataDirty)
 -- Repeated consumers can share a same-frame read. A new native event makes
 -- its metadata dirty even when GetTime has not advanced to another frame.
 local now=GetTime()
 if record and not metadataDirty and not invalidateDetails and record.sampledAt==now then return record end
 local info=Public(C_LFGList.GetSearchResultInfo(id))
 if type(info)~="table" then return nil end
 local previousActivity=record and record.activityID
 local previousMembers=record and record.numMembers
 local previousLeader=record and record.leaderKey
 local previousFaction=record and record.leaderFactionGroup
 local previousRating,previousRatingActivity=record and record.leaderRating,record and record.pvpRatingActivity
 local previousBnet,previousChar,previousGuild=record and record.bnetFriends,record and record.charFriends,record and record.guildMates
 local activityIDs=Public(info.activityIDs)
 local activityID=type(activityIDs)=="table" and Public(activityIDs[1]) or nil
 local activity=G.Catalog:GetActivity(activityID)
 if expectedScan and scan~=expectedScan then return nil end
 record=record or {id=id}
 record.sampledAt=now
 record.activityID,record.activity=activityID,activity
 record.activityName=activity and activity.name
 record.categoryID=activity and activity.categoryID
 record.mapID=activity and activity.mapID
 record.difficultyID=activity and activity.difficultyID
 record.maxNumPlayers=activity and activity.maxNumPlayers
 -- Rated battleground activity 19 reports 0; Blizzard's queue uses this team size.
 if record.categoryID==9 and record.maxNumPlayers==0 then record.maxNumPlayers=CONQUEST_SIZES[5] end
 record.name,record.comment=Public(info.name),Public(info.comment)
 record.partyGUID=Public(info.partyGUID)
 record.leaderName=Public(info.leaderName)
 record.leaderKey=G:RemotePlayerKey(record.leaderName)
 RememberBlockedLeader(record)
 record.leaderFactionGroup=Public(info.leaderFactionGroup)
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
 record.isDelisted=Public(info.isDelisted)==true
 record.bnetFriends,record.charFriends,record.guildMates=Public(info.numBNetFriends) or 0,Public(info.numCharFriends) or 0,Public(info.numGuildMates) or 0
 -- Native guild summaries can include the observer. Correct the shared count
 -- before list marks and filters consume it, without reading the member roster.
 if record.guildMates>0 then
  local _,_,guild=C_LFGList.GetSearchResultFriends(id)
  guild=Public(guild)
  local ownKey=A:UnitIdentity("player")
  if ownKey and type(guild)=="table" then
   for _,name in ipairs(guild) do
    if A:PlayerKey(name)==ownKey then record.guildMates=record.guildMates-1;break end
   end
  end
 end
 -- Bulk list events retain unchanged snapshots. A specific result event also
 -- covers member/spec/progress changes that do not change the member count.
 if invalidateDetails or previousActivity~=record.activityID or previousMembers~=record.numMembers or previousLeader~=record.leaderKey or previousFaction~=record.leaderFactionGroup or previousRating~=record.leaderRating or previousRatingActivity~=record.pvpRatingActivity or previousBnet~=record.bnetFriends or previousChar~=record.charFriends or previousGuild~=record.guildMates then
  record.detailsDirty=record.details and true or nil;record.memberCounts=nil
  record.progressKnown,record.progressCount=nil,nil
  record.checkedSpecID,record.hasMemberSpec=nil,nil
  record.checkedClass,record.hasMemberClass=nil,nil
 end
 return record
end
function Results:Capture(id,record,invalidateDetails) return Normalize(id,record,invalidateDetails) end
function Results:GetMemberCounts(record)
 if record.memberCounts then return record.memberCounts end
 local native=Public(C_LFGList.GetSearchResultMemberCounts(record.id))
 if type(native)~="table" then return nil end
 -- 展示和筛选只消费三个职责人数，不保留原生嵌套职业统计。
 local counts={TANK=Public(native.TANK),HEALER=Public(native.HEALER),DAMAGER=Public(native.DAMAGER)}
 record.memberCounts=counts
 return counts
end
function Results:HasMemberSpec(record,playerSpecID)
 if record.checkedSpecID==playerSpecID then return record.hasMemberSpec end
 local found=false
 local details=record.details
 if details and not record.detailsDirty then
  for _,member in ipairs(details.members) do
   if G:ResolveMemberSpec(member)==playerSpecID then found=true;break end
  end
 else
  for index=1,record.numMembers do
   local member=Public(C_LFGList.GetSearchResultPlayerInfo(record.id,index))
   if type(member)=="table" and G:ResolveMemberSpec(member)==playerSpecID then found=true;break end
  end
 end
 record.checkedSpecID,record.hasMemberSpec=playerSpecID,found
 return found
end
function Results:HasMemberClass(record,playerClass)
 if record.checkedClass==playerClass then return record.hasMemberClass end
 local found=false
 if record.details and not record.detailsDirty then
  for _,member in ipairs(record.details.members) do
   if member.class==playerClass then found=true;break end
  end
 else
  for index=1,record.numMembers do
   local member=Public(C_LFGList.GetSearchResultPlayerInfo(record.id,index))
   if type(member)=="table" and Public(member.classFilename)==playerClass then found=true;break end
  end
 end
 record.checkedClass,record.hasMemberClass=playerClass,found
 return found
end
local function RelationNames(values,excludeKey)
 values=Public(values)
 if type(values)~="table" then return {} end
 local names={}
 for _,value in ipairs(values) do
  value=Public(value)
  if type(value)=="string" and value~="" and (not excludeKey or A:PlayerKey(value)~=excludeKey) then names[#names+1]=value end
 end
 return names
end
local function TouchDetails(record)
 if records[record.id]~=record or detailQueue[#detailQueue]==record.id then return end
 for i=#detailQueue,1,-1 do if detailQueue[i]==record.id then table.remove(detailQueue,i);break end end
 detailQueue[#detailQueue+1]=record.id
 if #detailQueue>DETAIL_CAPACITY then local old=records[table.remove(detailQueue,1)];if old then old.details=nil;old.detailsDirty=nil end end
end
-- Sorting raid progress needs only this count, never every member's details.
function Results:GetProgressCount(record)
 if record.progressKnown then return record.progressCount end
 local encounters=Public(C_LFGList.GetSearchResultEncounterInfo(record.id))
 local count
 if type(encounters)=="table" then
  count=0
  for _,value in ipairs(encounters) do if type(Public(value))=="string" then count=count+1 end end
 end
 record.progressKnown,record.progressCount=true,count
 return count
end
function Results:GetDetails(idOrRecord)
 local record=type(idOrRecord)=="table" and idOrRecord or records[idOrRecord]
 if not record then return nil end
 local details=record.details
 if details and not record.detailsDirty then TouchDetails(record);return details end
 details=details or {members={}}
 -- Five-player rows show individual members. Their role-count API result also
 -- contains nested class counts, so read it only for an actual role filter.
 local memberCount=0
 details.counts=record.memberCounts or record.maxNumPlayers~=5 and self:GetMemberCounts(record) or nil
 for index=1,record.numMembers do
  local info=Public(C_LFGList.GetSearchResultPlayerInfo(record.id,index))
  if type(info)=="table" then
   local name=Public(info.name)
   local isLeader=Public(info.isLeader)==true
   local key=G:RemotePlayerKey(name)
   if not key and isLeader then key=record.leaderKey end
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
   info.isLeader=isLeader
   -- Search data identifies the leader's faction, not every remote member's.
   info.factionGroup=info.isLeader and record.leaderFactionGroup or nil
   info.ratingKind=record.ratingKind
   if record.ratingKind=="pvp" then
    info.rating=info.isLeader and record.leaderPvpRating or nil
    info.pvpRatingInfo=info.isLeader and record.pvpRatings and record.pvpRatings[1] or nil
   else info.rating=Public(info.dungeonScore);info.pvpRatingInfo=nil end
   -- Search relationships belong to the group-level native name lists. They
   -- are never attributed to roster rows, including the leader.
   info.nativeCharFriend,info.nativeGuildMate=nil,nil
   info.isBNetFriend,info.isCharFriend,info.isGuildMate,info.isFriend=nil,nil,nil,nil
   details.members[memberCount]=info
  end
 end
 for index=#details.members,memberCount+1,-1 do details.members[index]=nil end
 details.relationships=nil
 if record.bnetFriends+record.charFriends+record.guildMates>0 then
  local bnet,character,guild=C_LFGList.GetSearchResultFriends(record.id)
  local relations={bnet=RelationNames(bnet),character=RelationNames(character),guild=RelationNames(guild,A:UnitIdentity("player"))}
  details.relationships=relations
 end
 if record.categoryID==3 then
  local encounters=Public(C_LFGList.GetSearchResultEncounterInfo(record.id))
  if type(encounters)=="table" then
   details.encounters=details.encounters or {};wipe(details.encounters)
   for _,value in ipairs(encounters) do
    local name=Public(value)
    if type(name)=="string" then details.encounters[#details.encounters+1]=name end
   end
  else details.encounters=nil end
  record.progressKnown,record.progressCount=true,details.encounters and #details.encounters
 else details.encounters=nil end
 record.details=details;record.detailsDirty=nil
 -- 队列仅存 ID，旧结果不会被缓存队列继续强引用。
 TouchDetails(record)
 return details
end
local function MatchesNote(key,kind)
 local note=key and A.Notes:Find(key)
 return note and (kind=="any" or note.type==kind)
end
local function MatchesLeaderText(record,text)
 local leader=record.leaderName
 return type(leader)=="string" and leader:lower():find(text,1,true)~=nil
end
local function Pass(record,filters,leaderText,playerSpecID,playerClass)
 if blockedTitles[record.name] and not unblockedLeaders[record.leaderKey] or G.db.blockedLeaders[record.leaderKey] then return false end
 if not Results:MatchesNumericFilters(record,filters) then return false end
 if G.Applications:IsActive(record.id) then return false end
 if leaderText and not MatchesLeaderText(record,leaderText) then return false end
 if filters.category and not G.Catalog:Matches(record.activity,filters.category,filters.groupKey,filters.difficultyID,filters.tier,filters.groupKeys) then return false end
 if filters.hideZeroScore and (record.leaderOverallDungeonScore or 0)<1 then return false end
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
 if filters.tankPresence or filters.healerPresence or filters.damagePresence then
  local counts=Results:GetMemberCounts(record)
  if not Results:MatchesRolePresence(counts,filters,record.maxNumPlayers) then return false end
 end
 if filters.friends and record.bnetFriends+record.charFriends==0 or filters.guild and record.guildMates==0 then return false end
 if filters.notes then
  local exclude=filters.notes=="noCaution"
  if A.Notes then
   local kind=exclude and "caution" or filters.notes
   local found=MatchesNote(record.leaderKey,kind)
   if exclude and found or not exclude and not found then return false end
  elseif not exclude then return false end
 end
 if playerSpecID and Results:HasMemberSpec(record,playerSpecID) then return false end
 if playerClass and Results:HasMemberClass(record,playerClass) then return false end
 return true
end
local sorting
local function Sort(a,b)
 local x,y=records[a],records[b]
 local xd,yd=G.Applications:GetDeclinedAt(x.partyGUID)~=nil,G.Applications:GetDeclinedAt(y.partyGUID)~=nil
 if xd~=yd then return not xd end
 local xf,yf=x.bnetFriends+x.charFriends>0,y.bnetFriends+y.charFriends>0
 if xf~=yf then return xf end
 local av,bv
 if sorting=="rating" then av,bv=x.leaderRating or -1,y.leaderRating or -1
 elseif sorting=="members" then av,bv=x.numMembers,y.numMembers
 elseif sorting=="itemLevel" then av,bv=x.requiredItemLevel,y.requiredItemLevel end
 if av and av~=bv then return av>bv end
 if x.age~=y.age then return x.age<y.age end
 return a<b
end
function Results:InvalidateView() dirty=true end
function Results:BlockTitle(title,leaderKey)
 if title==nil then return false end
 local changed=not blockedTitles[title]
 if changed then blockedTitles[title]=true;blockedTitleCount=blockedTitleCount+1 end
 -- The selected application may no longer belong to the current search.
 if leaderKey then
  unblockedLeaders[leaderKey]=nil
  if not G.db.blockedLeaders[leaderKey] then G.db.blockedLeaders[leaderKey]=true;blockedLeadersDirty=true;changed=true end
 end
 for _,record in pairs(records) do
  if record.name==title and record.leaderKey then unblockedLeaders[record.leaderKey]=nil end
  if RememberBlockedLeader(record) then changed=true end
 end
 if not changed then return false end
 self:InvalidateView();G:Notify("results")
 return true
end
function Results:ClearBlockedTitles()
 if blockedTitleCount==0 and not next(G.db.blockedLeaders) then return false end
 wipe(blockedTitles);wipe(G.db.blockedLeaders);wipe(unblockedLeaders);blockedTitleCount=0;blockedLeadersDirty=true
 self:InvalidateView();G:Notify("results")
 return true
end
function Results:GetBlockedTitleCount() return blockedTitleCount end
function Results:GetBlockedLeaders()
 if blockedLeadersDirty then
  wipe(blockedLeaderIDs)
  for key in pairs(G.db.blockedLeaders) do blockedLeaderIDs[#blockedLeaderIDs+1]=key end
  table.sort(blockedLeaderIDs);blockedLeadersDirty=false
 end
 return blockedLeaderIDs
end
function Results:RemoveBlockedLeader(key)
 if not G.db.blockedLeaders[key] then return false end
 G.db.blockedLeaders[key]=nil;blockedLeadersDirty=true
 -- A deliberate removal wins over this session's still-matching title token.
 -- Explicitly blocking that title again can add the leader back.
 unblockedLeaders[key]=true
 self:InvalidateView();G:Notify("results")
 return true
end
local function FinishUpdates(version,fullSnapshot)
 for id,queued in pairs(pendingIDs) do if queued<=version then pendingIDs[id]=nil end end
 if fullSnapshot and pendingBulk and pendingBulk<=version then pendingBulk=nil end
 if Results.updatePending and not pendingBulk and not next(pendingIDs) then
  G.Game.frame:SetScript("OnUpdate",nil);Results.updatePending=nil
 end
end
function Results:CancelUpdates(keepApplications)
 pendingBulk,committing=nil,nil
 nextBulkAt=0
 for id in pairs(pendingIDs) do if not keepApplications or not G.Applications:IsActive(id) then pendingIDs[id]=nil end end
 if not next(pendingIDs) then G.Game.frame:SetScript("OnUpdate",nil);self.updatePending=nil end
end
local function FlushUpdates()
 local version,currentScan=updateVersion,scan
 -- A complete snapshot consumes the dirty IDs as part of the same native
 -- read, including detail invalidations; do not read those records twice.
 if pendingBulk and GetTime()>=nextBulkAt then Results:CommitResults(Results.gen,pendingIDs);return end
 -- Bulk events share the last commit's fixed window. Specific IDs are still
 -- read on this frame, without consuming or extending the pending snapshot.
 local applicationsChanged=false
 wipe(changedIDs)
 for id,queued in pairs(pendingIDs) do
  if queued<=version then
   local applicationChanged,inResults=Results:OnResultUpdated(id,true,true)
   if applicationChanged then applicationsChanged=true end
   if inResults then changedIDs[id]=true end
  end
  if scan~=currentScan then break end
 end
 if scan==currentScan then
  FinishUpdates(version)
  if next(changedIDs) then
   Results:InvalidateView();G:Notify("results",changedIDs)
  end
 end
 wipe(changedIDs)
 if applicationsChanged then G:Notify("applications") end
end
-- Reuse the event frame and ID set for queued updates. Events received during
-- a flush keep their newer sequence and are handled by the next frame.
function Results:QueueUpdate(id)
 if id and not records[id] and not committing and not G.Applications:IsActive(id) then return end
 updateVersion=updateVersion+1
 if id then pendingIDs[id]=updateVersion else pendingBulk=updateVersion end
 if not self.updatePending then
  self.updatePending=true;G.Game.frame:SetScript("OnUpdate",FlushUpdates);G.Game.frame:Show()
 end
end
function Results:BeginSearch(gen)
 self:CancelUpdates(true)
 self.gen=gen;scan=scan+1;wipe(records);wipe(detailQueue);wipe(ids);count=0;self:InvalidateView();G:Notify("results")
end
function Results:GetChangedResults()
 local _,list=C_LFGList.GetFilteredSearchResults()
 if #list~=count then return list end
 for _,id in ipairs(list) do if not records[id] then return list end end
end
function Results:CommitResults(gen,updatedIDs,list)
 if gen~=self.gen then return end
 nextBulkAt=GetTime()+BULK_INTERVAL
 scan=scan+1
 local currentScan,version=scan,updateVersion
 local applicationsChanged=false
 local metadataDirty=pendingBulk~=nil
 committing=currentScan
 if not list then local _;_,list=C_LFGList.GetFilteredSearchResults() end
 if scan~=currentScan then return end
 for _,id in ipairs(list or {}) do
  local old=records[id]
  local record=Normalize(id,old,updatedIDs and updatedIDs[id] or pendingIDs[id],currentScan,metadataDirty)
  if scan~=currentScan then return end
  if record and not record.isDelisted then
   record.scan=currentScan;records[id]=record
   if not old then count=count+1 end
  end
  if record and G.Applications:AdoptResult(id,record) then applicationsChanged=true end
 end
 for id,record in pairs(records) do if record.scan~=currentScan or record.isDelisted then records[id]=nil;count=count-1 end end
 for i=#detailQueue,1,-1 do if not records[detailQueue[i]] then table.remove(detailQueue,i) end end
 -- A bulk search snapshot does not contain applications from other categories.
 for id,queued in pairs(pendingIDs) do
  if queued<=version and not records[id] and G.Applications:IsActive(id) then
   local record=Normalize(id,G.Applications:GetApplication(id).result,true,currentScan)
   if scan~=currentScan then return end
   if record and G.Applications:AdoptResult(id,record) then applicationsChanged=true end
  end
 end
 -- A full snapshot consumes prior queued events, never events received during it.
 committing=nil
 FinishUpdates(version,true)
 self:InvalidateView();G:Notify("results")
 if applicationsChanged then G:Notify("applications") end
end
function Results:FailSearch(gen) if gen==self.gen then self:BeginSearch(gen) end end
function Results:OnResultUpdated(id,deferApplications,deferResults)
 local record=records[id]
 local inResults=record~=nil
 if not record then
  if not G.Applications:IsActive(id) then return end
  record=G.Applications:GetApplication(id).result
 end
 local currentScan=scan
 record=Normalize(id,record,true,currentScan)
 if scan~=currentScan then return end
 local applicationChanged=record and G.Applications:AdoptResult(id,record)
 if inResults and (not record or record.isDelisted) then
  records[id]=nil;count=count-1
  for i=#detailQueue,1,-1 do if detailQueue[i]==id then table.remove(detailQueue,i);break end end
 end
 if inResults and not deferResults then self:InvalidateView();G:Notify("result",id) end
 if applicationChanged and not deferApplications then G:Notify("applications") end
 return applicationChanged,inResults
end
function Results:GetResults()
 if dirty then
  wipe(ids)
  local filters=G.Search:GetFilters()
  local playerSpecID=filters.hideSameSpec and A.Specializations:Player() or nil
  local playerClass=filters.hideSameClass and select(2,UnitClass("player")) or nil
  local leaderText=type(filters.leaderText)=="string" and filters.leaderText:lower():match("^%s*(.-)%s*$") or nil
  if leaderText=="" then leaderText=nil end
  for id,record in pairs(records) do if not record.isDelisted and Pass(record,filters,leaderText,playerSpecID,playerClass) then ids[#ids+1]=id end end
  sorting=filters.sort or A:GetSetting("defaultSort");table.sort(ids,Sort);dirty=false
 end
 return ids
end
function Results:GetResult(id) return records[id] end
function Results:GetCount() return count end
