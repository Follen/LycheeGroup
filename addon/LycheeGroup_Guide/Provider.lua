-- Local teaching records backed by native activity objects; no native group actions.
local A=_G.LycheeGroup
local Guide=A.Guide
local function S(cn,en) return A:GetLocale()=="zhCN" and cn or en end
local function Active(app)
 if not app then return false end
 local status,pending=app.status,app.pendingStatus
 if pending and pending~="applied" and pending~="invited" then return false end
 return status=="applied" or status=="invited" or (status==nil or status=="none") and (pending=="applied" or pending=="invited")
end
local function Copy(source) local out={};for key,value in pairs(source or {}) do out[key]=value end;return out end
function Guide:CreateProvider(scenario,options)
 if scenario~="applications" and scenario~="create" and scenario~="applicants" then return nil,S("未知引导场景。","Unknown guide scenario.") end
 if type(options)~="table" then return nil,S("教学活动与角色资料尚未就绪。","The tutorial activity and player data are not ready.") end
 local catalog,activity,category,player=options.catalog,options.activity,options.category,options.player
 if type(catalog)~="table" or type(catalog.GetActivity)~="function" or type(catalog.GetActivities)~="function"
  or type(activity)~="table" or type(activity.id)~="number" or activity.id~=activity.id or activity.id<=0 or activity.id>=math.huge
  or catalog:GetActivity(activity.id)~=activity then return nil,S("当前游戏活动目录尚未就绪，请稍后再开始引导。","The game activity catalog is not ready. Start the guide again shortly.") end
 category=category or catalog:GetContextForActivity(activity.id)
 local found=false
 for _,candidate in ipairs(catalog:GetActivities(category) or {}) do if candidate==activity then found=true;break end end
 if not found then return nil,S("所选活动不在当前游戏分类中。","The selected activity is not in this game category.") end
 if type(player)~="table" then return nil,S("教学角色资料尚未就绪。","The tutorial player data is not ready.") end
 local UI=A.UI
 local p={isPreview=true,Catalog=catalog,L=A.Group.L,category=category,activity=activity,db={},prefs={find={category=category}},settings={autoJoin=false},applicationPrefs={},subs={},views={},records={},apps={},applicants={},roster={},filters={},state="done"}
 p.player=player
 function p:GetCategoryInfo(id)
  if self.Catalog.GetCategoryInfo then return self.Catalog:GetCategoryInfo(id) end
  return C_LFGList.GetLfgCategoryInfo(id)
 end
 p.Results={};p.Applications={};p.Search={categoryKey=category};p.Relations={};p.declinedParties={}
 p.SeasonScores={records={},unknown={}}
 local seasonRecord={level=18,score=360}
 function p.SeasonScores:Begin(callback) self.active=true;self.callback=callback end
 function p.SeasonScores:End() self.active=nil;self.callback=nil;wipe(self.records) end
 function p.SeasonScores:GetRecord(group)
  if not self.active or not group then return self.unknown end
  return seasonRecord
 end
 function p.Relations:Apply(member) return member end
 function p:Subscribe(callback) self.subs[callback]=true;return function() self.subs[callback]=nil end end
 function p:Notify(kind,id) for fn in pairs(self.subs) do fn(kind,id) end end
 p.Presets=A.CreationPresets.New({},function() p:Notify("creationPresets") end)
 function p:Attach(owner,kind) self.views[owner]=kind end
 function p:Detach(owner) self.views[owner]=nil end
 function p:SetApplicantView() end
 function p:GetSearchState() return self.state end
 function p:GetSearchError() return nil end
 function p.Search:Search(key,ids)
  self.categoryKey=key;self.activityIDs=ids
  local selected=ids and ids[1] and p.Catalog:GetActivity(ids[1])
  if selected then p:BindActivity(selected,key) end
  p.state="done";p:Notify("search");return true
 end
 function p.Search:EndBrowse() end
 function p:SetFilters(filters) self.filters=Copy(filters);self:Notify("results") end
 function p.Results:GetDetails(record) if type(record)=="number" then record=p.records[record] end;return record.details end
 function p.Results:GetProgressCount(record) return record.details.encounters and #record.details.encounters end
 function p.Results:GetMemberCounts(record) return self:GetDetails(record).counts end
 function p.Results:GetLeaderClass(record)
  for _,member in ipairs(record.details.members) do
   if member.isLeader or record.leaderKey and member.nameKey==record.leaderKey then return member.class end
  end
 end
 function p.Results:HasMemberSpec(record,playerSpecID)
  for _,member in ipairs(record.details.members) do if member.specID==playerSpecID then return true end end
  return false
 end
 function p.Results:InvalidateView() end
 local blockedTitles,blockedTitleCount={},0
 local unblockedLeaders,blockedLeaderIDs={},{}
 local blockedLeadersDirty=true
 p.db.blockedLeaders={}
 local function RememberBlockedLeader(record)
  if blockedTitles[record.name] and record.leaderKey and not unblockedLeaders[record.leaderKey] and not p.db.blockedLeaders[record.leaderKey] then
   p.db.blockedLeaders[record.leaderKey]=true;blockedLeadersDirty=true;return true
  end
 end
 function p.Results:BlockTitle(title,leaderKey)
  if title==nil then return false end
  local changed=not blockedTitles[title]
  if changed then blockedTitles[title]=true;blockedTitleCount=blockedTitleCount+1 end
  if leaderKey then
   unblockedLeaders[leaderKey]=nil
   if not p.db.blockedLeaders[leaderKey] then p.db.blockedLeaders[leaderKey]=true;blockedLeadersDirty=true;changed=true end
  end
  for _,record in pairs(p.records) do
   if record.name==title and record.leaderKey then unblockedLeaders[record.leaderKey]=nil end
   if RememberBlockedLeader(record) then changed=true end
  end
  if not changed then return false end
  p:Notify("results");return true
 end
 function p.Results:ClearBlockedTitles()
  if blockedTitleCount==0 and not next(p.db.blockedLeaders) then return false end
  wipe(blockedTitles);wipe(p.db.blockedLeaders);wipe(unblockedLeaders);blockedTitleCount=0;blockedLeadersDirty=true;p:Notify("results");return true
 end
 function p.Results:GetBlockedTitleCount() return blockedTitleCount end
 function p.Results:GetBlockedLeaders()
  if blockedLeadersDirty then
   wipe(blockedLeaderIDs)
   for key in pairs(p.db.blockedLeaders) do blockedLeaderIDs[#blockedLeaderIDs+1]=key end
   table.sort(blockedLeaderIDs);blockedLeadersDirty=false
  end
  return blockedLeaderIDs
 end
 function p.Results:RemoveBlockedLeader(key)
  if not p.db.blockedLeaders[key] then return false end
  p.db.blockedLeaders[key]=nil;unblockedLeaders[key]=true;blockedLeadersDirty=true;p:Notify("results");return true
 end
 function p:GetResult(id) return self.records[id] end
 function p:GetResultCount() return #self.recordIDs end
 function p:GetApplications() return self.apps end
 function p:GetApplication(id) for _,app in ipairs(self.apps) do if app.id==id then return app end end end
 function p.Applications:IsActive(id) return Active(p:GetApplication(id)) end
 function p.Applications:GetDeclinedAt(partyGUID) return partyGUID and p.declinedParties[partyGUID] end
 function p.Applications:CanCancel(id) local app=p:GetApplication(id);return app~=nil and app.status=="applied" and not app.pendingStatus end
 function p.Applications:GetActiveCount() local count=0;for _,app in ipairs(p.apps) do if Active(app) then count=count+1 end end;return count end
 function p.Applications:TryAutoJoin() end
 function p:GetListing() return self.listing end
 function p:CanManageApplicants() return true end
 function p:CanManageListing() return true end
 function p:RefreshApplicants() if not self.listing then return false end;self:Notify("applicants");return true end
 function p:GetRoster() return self.roster end
 function p:GetRaidBuffs(activityID)
  local report=A.RaidBuffs.Get(self.Catalog,activityID,self.roster,self.buffReport)
  if report then self.buffReport=report end
  return report
 end
 function p:GetApplicants() return self.listing and self.applicantIDs or self.emptyIDs end
 function p:GetApplicant(id) return self.applicants[id] end
 function p:GetApplicantDungeonScores(member) return member.dungeonScores end
 function p:GetApplicantMapScore(member) return member.dungeonScores and member.dungeonScores.mapScore end
 function p:GetApplicantTimeMargin(member)
  local scores=member.dungeonScores;local run=scores and scores.current
  if not run then return nil,scores and scores.mapScore==0 and "none" or "unknown" end
  if not run.timeLimitSeconds then return nil,"unknown",run end
  if not run.timed or not run.durationMs then return nil,"unavailable",run end
  return run.timeLimitSeconds-run.durationMs/1000,"known",run
 end
 local resultIDs={}
 local function ResultOrder(a,b)
  local f=p.filters
  local x,y=p.records[a],p.records[b];local key=f.sort=="rating" and "leaderRating" or f.sort=="itemLevel" and "requiredItemLevel" or f.sort=="members" and "numMembers"
  local xd,yd=p.Applications:GetDeclinedAt(x.partyGUID)~=nil,p.Applications:GetDeclinedAt(y.partyGUID)~=nil
  if xd~=yd then return not xd end
  local xf,yf=x.bnetFriends+x.charFriends+x.guildMates>0,y.bnetFriends+y.charFriends+y.guildMates>0
  if xf~=yf then return xf end
  if key and x[key]~=y[key] then return x[key]>y[key] end
  return x.age<y.age
 end
 function p:GetResults()
  local ids=resultIDs;wipe(ids);local f=self.filters
  local playerSpecID=f.hideSameSpec and self.player.specID or nil
  local playerClass=f.hideSameClass and self.player.class or nil
  local partyClass,partyRole,needBloodlust
  if f.category=="seasonDungeon" and (f.hideSameClassRole or f.requireBloodlust) then
   partyClass=self.player.class
   if f.hideSameClassRole then
    partyRole=self.player.role
    if partyRole=="NONE" then partyRole=nil end
   end
   needBloodlust=f.requireBloodlust and partyClass and partyClass~="SHAMAN" and partyClass~="MAGE" and partyClass~="HUNTER" and partyClass~="EVOKER"
  end
  local text=(f.searchMode=="leader" and f.leaderText or f.searchMode=="group" and f.text or ""):lower()
  local minLevel,maxLevel
  if f.searchMode=="group" then minLevel,maxLevel=text:match("^%s*(%d+)%s*%-%s*(%d+)%s*$") end
  if minLevel then minLevel,maxLevel=tonumber(minLevel),tonumber(maxLevel) end
  for _,id in ipairs(self.recordIDs) do
   local r=self.records[id];local counts=r.details.counts
   RememberBlockedLeader(r)
   local pass=(not blockedTitles[r.name] or unblockedLeaders[r.leaderKey]) and not self.db.blockedLeaders[r.leaderKey] and not self.Applications:IsActive(id) and self.Catalog:Matches(r.activity,f.category or self.category,f.groupKey,f.difficultyID,f.tier,f.groupKeys)
   if pass and text~="" then
    if f.searchMode=="group" and minLevel then pass=r.level and r.level>=minLevel and r.level<=maxLevel
    elseif f.searchMode=="leader" then
     local leaderText=text:match("^%s*(.-)%s*$")
     pass=leaderText~="" and r.leaderName and r.leaderName:lower():find(leaderText,1,true)~=nil
    else pass=r.name:lower():find(text,1,true)~=nil end
   end
   if pass then pass=A.Group.Results:MatchesNumericFilters(r,f) end
   if pass and f.minMembers then pass=r.numMembers>=f.minMembers end
   if pass and f.maxMembers then pass=r.numMembers<=f.maxMembers end
   if pass and f.hideZeroScore then pass=(r.leaderOverallDungeonScore or 0)>=1 end
   if pass and f.neededRole then pass=r.maxNumPlayers==5 and counts[f.neededRole]<(f.neededRole=="DAMAGER" and 3 or 1) end
   if pass and (f.tankPresence or f.healerPresence or f.damagePresence) then
    pass=A.Group.Results:MatchesRolePresence(counts,f,r.maxNumPlayers)
   end
   if pass and (f.friends or f.guild) then
    local friends=r.bnetFriends+r.charFriends>0;local guild=r.guildMates>0
    if f.friends and not friends or f.guild and not guild then pass=false end
   end
   if pass and (f.notes and f.notes~="noCaution" or f.personKey and f.personKey~=r.leaderKey) then pass=false end
   if pass and playerSpecID then pass=not self.Results:HasMemberSpec(r,playerSpecID) end
   if pass and playerClass then pass=not A.Group.Results:HasMemberClass(r,playerClass) end
   if pass and (partyRole or needBloodlust) then pass=A.Group.Results:MatchesPartyFilters(r,partyClass,partyRole,needBloodlust) end
   if pass then ids[#ids+1]=id end
  end
  table.sort(ids,ResultOrder)
  return ids
 end
 function p:Cancel(id) local app=self:GetApplication(id);if app and app.status=="applied" then app.status="cancelled";self:Notify("applications",id);return true end;return false,self.L.alreadyApplied end
 function p:Apply(id,role,comment)
  if self.listing then return false,self.L.recruiting end
  if self.Applications:IsActive(id) then return false,self.L.alreadyApplied end
  if self.Applications:GetActiveCount()>=5 then return false,self.L.applicationLimit end
  local r=self.records[id];local app=self:GetApplication(id)
  if not app then app={id=id};self.apps[#self.apps+1]=app end
  app.status="applied";app.result=r;app.name=r.name;app.categoryID=r.categoryID;app.leaderName=r.leaderName;app.expiresAt=GetTime()+300;app.role=role;app.comment=comment
  self:Notify("applications",id);return true
 end
 function p:SetApplicantActivity(activityID)
  local activity=self.Catalog:GetActivity(activityID);local profile=A.GroupPresentation.Activity(activity)
  local limit=Guide:ResolveTimeLimit(activity)
  if self.applicantActivityID==activityID and self.applicantTimeLimit==limit then return end
  self.applicantActivityID,self.applicantTimeLimit=activityID,limit
  for _,app in pairs(self.applicants) do
   app.activityID=activityID
   for index,member in ipairs(app.members) do
    member.applicantID,member.applicantIndex=app.id,index
    member.ratingKind=profile.kind=="pvp" and "pvp" or "dungeon"
    if profile.kind=="pvp" then member.rating=profile.requirementRatingKind and 1800+index*75 or nil
    else member.rating=member.dungeonScore end
    if profile.applicant.showDungeonRecords then
     local scores=member.dungeonScores or {};member.dungeonScores=scores
     local current,best=scores.current or {},scores.best or {};scores.current,scores.best=current,best
     scores.mapScore=280+index*12
     current.activityID,current.name,current.level,current.timed=activityID,activity.fullName or activity.name,18,true
     current.durationMs=limit and limit*1000-(index%3==1 and 200000 or index%3==2 and 30000 or 90000) or nil
     current.timeLimitSeconds=limit
     best.name,best.level,best.timed=activity.fullName or activity.name,19,false
     best.durationMs,best.timeLimitSeconds=limit and limit*1000+100000 or nil,limit
    else member.dungeonScores=nil end
   end
  end
 end
 function p:Publish(data)
  local name,comment=UI.Native:GetPreviewCreationText()
  local listing=Copy(data);listing.name=name;listing.comment=comment;listing.activityName=self.Catalog:GetActivity(data.activityID).name
  listing.privateGroup=data.isPrivateGroup;listing.isCrossFactionListing=data.isCrossFactionListing;listing.autoAccept=data.isAutoAccept
  self.listing=listing
  self:SetApplicantActivity(data.activityID)
  self:Notify("listing");return true
 end
 function p:Update(data) return self:Publish(data) end
 function p:RemoveListing() self.listing=nil;self:Notify("listing");return true end
 function p:Invite(id) local app=self.applicants[id];app.status="invited";app.acting=nil;self:Notify("applicants",id);return true end
 function p:Decline(id) local app=self.applicants[id];app.status="declined";app.acting=nil;self:Notify("applicants",id);return true end
 function p:BindActivity(selected,key)
  self.activity,self.category=selected,key
  local profile=A.GroupPresentation.Activity(selected)
  for _,id in ipairs(self.recordIDs) do
   local record=self.records[id]
   record.activity,record.activityID,record.activityName,record.categoryID=selected,selected.id,selected.name,selected.categoryID
   record.maxNumPlayers=selected.maxNumPlayers or 5
   record.level=selected.isMythicPlusActivity and 8+(-9000-id) or nil
   record.ratingKind=profile.kind=="pvp" and "pvp" or "dungeon"
   if profile.kind=="pvp" then record.leaderRating=profile.requirementRatingKind and 1600+(-9000-id)*75 or nil
   else record.leaderRating=record.leaderOverallDungeonScore end
  end
  self:SetApplicantActivity(selected.id)
 end
 local classes={"WARRIOR","PRIEST","MAGE","SHAMAN","ROGUE"}
 local roles={"TANK","HEALER","DAMAGER","HEALER","DAMAGER"}
 local specs={73,257,64,264,260}
 local scores={2940,2535,3075,2670,2805}
 local names={S("山间小路","Oakshield"),S("晨风","Morningwind"),S("冰糖","Winterlight"),S("浅蓝","Clearwater"),S("夜行","Nightstep")}
 local function Member(index)
  local slot=(index-1)%5+1;local name=names[slot]..(index>5 and tostring(index) or "");local realm=S("白银之手","Silvermoon")
  local relation=(index-1)%4
  return {isPreview=true,name=name,realm=realm,nameKey=name.."-"..realm,class=classes[slot],assignedRole=roles[slot],specID=specs[slot],itemLevel=260+slot*3,dungeonScore=scores[slot],factionGroup=index%2,raceID=index%2==1 and 1 or 2,raceName=index%2==1 and S("人类","Human") or S("兽人","Orc"),isBNetFriend=relation==1,isCharFriend=relation==2,isGuildMate=relation==3,isFriend=false}
 end
 p.recordIDs={};p.applicantIDs={1,2,3};p.emptyIDs={}
 local titles={S("轻松打完","Relaxed run"),S("熟练来","Experienced group"),S("稳一点打","Steady pace"),S("缺坦克","Tank needed"),S("缺治疗","Healer needed"),S("一起拿装备","Gear run")}
 for i=1,6 do
  local members={Member(i),Member(i+1)};members[1].isLeader=true
  if i==6 then for _,member in ipairs(members) do member.isBNetFriend,member.isCharFriend,member.isGuildMate=false,false,false end end
  local counts={TANK=0,HEALER=0,DAMAGER=0};local bnet,character,guild=0,0,0
  for _,m in ipairs(members) do
   counts[m.assignedRole]=counts[m.assignedRole]+1
   if m.isBNetFriend then bnet=bnet+1 end;if m.isCharFriend then character=character+1 end;if m.isGuildMate then guild=guild+1 end
  end
  local id=-9000-i
  local r={id=id,isPreview=true,name=titles[i],comment=S("跟标记走，打完一起分装备。","Follow the markers; finish the run together."),activity=activity,activityID=activity.id,activityName=activity.name,categoryID=activity.categoryID,numMembers=#members,maxNumPlayers=activity.maxNumPlayers or 5,leaderName=members[1].nameKey,leaderKey=members[1].nameKey,leaderOverallDungeonScore=members[1].dungeonScore,requiredItemLevel=260+i*2,age=i*47,level=activity.isMythicPlusActivity and 8+i or nil,charFriends=character,bnetFriends=bnet,guildMates=guild,details={members=members,counts=counts}}
  local profile=A.GroupPresentation.Activity(activity)
  r.ratingKind=profile.kind=="pvp" and "pvp" or "dungeon"
  if profile.kind=="pvp" then r.leaderRating=profile.requirementRatingKind and 1600+i*75 or nil
  else r.leaderRating=members[1].dungeonScore end
  r.partyGUID="PreviewParty-"..i
  p.records[id]=r;p.recordIDs[#p.recordIDs+1]=id
 end
 p.roster={Member(1),Member(2),Member(3)};p.roster[1].isLeader=true
 p.applicants[1]={id=1,status="applied",displayOrderID=1,comment=S("可以治疗，随时出发。","Healer ready to go."),members={Member(4)}}
 p.applicants[2]={id=2,status="applied",displayOrderID=2,comment=S("两位同行，邀请与拒绝作用于整组。","Two friends applying together; actions affect the whole batch."),members={Member(5),Member(6)}}
 p.applicants[3]={id=3,status="applied",displayOrderID=3,comment=S("熟悉路线，有打断。","Know the route; interrupts ready."),members={Member(7)}}
 p:SetApplicantActivity(activity.id)
 if scenario=="applicants" then p.listing={activityID=activity.id,activityName=activity.name,name=S("一起完成地下城","Dungeon run"),comment=S("来熟悉路线的队友。","Looking for teammates who know the route."),requiredItemLevel=260,requiredDungeonScore=2000,generalPlaystyle=Enum.LFGEntryGeneralPlaystyle.FunRelaxed} end
 return p
end
