-- Explicit local preview. No provider methods call a native group action or save data.
local A=_G.LycheeGroup
local UI=A.UI
local zh=A:GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
local function Active(app)
 if not app then return false end
 local status,pending=app.status,app.pendingStatus
 if pending and pending~="applied" and pending~="invited" then return false end
 return status=="applied" or status=="invited" or (status==nil or status=="none") and (pending=="applied" or pending=="invited")
end
local function Copy(source) local out={};for key,value in pairs(source or {}) do out[key]=value end;return out end
local function Seed(catalog)
 local categories=catalog:GetCategories()
 for _,category in ipairs(categories) do
  local activities=catalog:GetActivities(category.key)
  for _,activity in ipairs(activities) do if activity.isMythicPlusActivity then return category.key,activity end end
 end
 for _,category in ipairs(categories) do local activity=catalog:GetActivities(category.key)[1];if activity then return category.key,activity end end
end
local function NewProvider(scenario)
 local catalog=A.Group.Catalog
 local category,activity=Seed(catalog)
 if not activity then return nil,S("当前客户端活动目录尚未就绪，请稍后再打开预览。","The client activity catalog is not ready. Open preview again shortly.") end
 local p={isPreview=true,Catalog=catalog,L=A.Group.L,category=category,activity=activity,db={},prefs={find={category=category}},settings={autoJoin=false},applicationPrefs={},subs={},views={},records={},apps={},applicants={},roster={},filters={},state="done"}
 p.Results={};p.Applications={};p.Search={categoryKey=category};p.Relations={}
 function p.Relations:Apply(member) return member end
 function p:Subscribe(callback) self.subs[callback]=true;return function() self.subs[callback]=nil end end
 function p:Notify(kind,id) for fn in pairs(self.subs) do fn(kind,id) end end
 p.Presets=A.CreationPresets.New({},function() p:Notify("creationPresets") end)
 function p:Attach(owner,kind) self.views[owner]=kind end
 function p:Detach(owner) self.views[owner]=nil end
 function p:SetApplicantView() end
 function p:GetSearchState() return self.state end
 function p:GetSearchError() return nil end
 function p.Search:Search(key,id) self.categoryKey=key;self.activityID=id;p.state="done";p:Notify("search");return true end
 function p.Search:EndBrowse() end
 function p:SetFilters(filters) self.filters=Copy(filters);self:Notify("results") end
 function p.Results:GetDetails(record) if type(record)=="number" then record=p.records[record] end;return record.details end
 function p.Results:GetMemberCounts(record) return self:GetDetails(record).counts end
 function p.Results:HasMemberSpec(record,playerSpecID)
  for _,member in ipairs(record.details.members) do if member.specID==playerSpecID then return true end end
  return false
 end
 function p.Results:InvalidateView() end
 local blockedTitles,blockedTitleCount={},0
 function p.Results:BlockTitle(title)
  if title==nil or blockedTitles[title] then return false end
  blockedTitles[title]=true;blockedTitleCount=blockedTitleCount+1;p:Notify("results");return true
 end
 function p.Results:ClearBlockedTitles()
  if blockedTitleCount==0 then return false end
  wipe(blockedTitles);blockedTitleCount=0;p:Notify("results");return true
 end
 function p.Results:GetBlockedTitleCount() return blockedTitleCount end
 function p:GetResult(id) return self.records[id] end
 function p:GetResultCount() return #self.recordIDs end
 function p:GetApplications() return self.apps end
 function p:GetApplication(id) for _,app in ipairs(self.apps) do if app.id==id then return app end end end
 function p.Applications:IsActive(id) return Active(p:GetApplication(id)) end
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
 function p:GetResults()
  local ids={};local f=self.filters
  local playerSpecID=f.hideSameSpec and A.Specializations:Player() or nil
  local text=(f.searchMode=="leader" and f.leaderText or f.searchMode=="group" and f.text or ""):lower()
  local minLevel,maxLevel
  if f.searchMode=="group" then minLevel,maxLevel=text:match("^%s*(%d+)%s*%-%s*(%d+)%s*$") end
  if minLevel then minLevel,maxLevel=tonumber(minLevel),tonumber(maxLevel) end
  for _,id in ipairs(self.recordIDs) do
   local r=self.records[id];local counts=r.details.counts
   local pass=not blockedTitles[r.name] and not self.Applications:IsActive(id) and self.Catalog:Matches(r.activity,f.category or self.category,f.groupKey,f.difficultyID,f.tier,f.groupKeys)
   if pass and text~="" then
    if f.searchMode=="group" and minLevel then pass=r.level and r.level>=minLevel and r.level<=maxLevel
    elseif f.searchMode=="leader" then
     local leaderText=text:match("^%s*(.-)%s*$")
     pass=leaderText~="" and r.leaderName and r.leaderName:lower():find(leaderText,1,true)~=nil
    else pass=r.name:lower():find(text,1,true)~=nil end
   end
   if pass and f.minMembers then pass=r.numMembers>=f.minMembers end
   if pass and f.maxMembers then pass=r.numMembers<=f.maxMembers end
   if pass and f.hideZeroScore then pass=(r.leaderOverallDungeonScore or 0)>=1 end
   if pass and f.neededRole then pass=r.maxNumPlayers==5 and counts[f.neededRole]<(f.neededRole=="DAMAGER" and 3 or 1) end
   if pass and (f.tankPresence or f.healerPresence or f.damagePresence) then
    pass=r.maxNumPlayers==5
    if pass and f.tankPresence then pass=counts.TANK~=nil and (counts.TANK>0)==(f.tankPresence=="present") end
    if pass and f.healerPresence then pass=counts.HEALER~=nil and (counts.HEALER>0)==(f.healerPresence=="present") end
    if pass and f.damagePresence then pass=counts.DAMAGER~=nil and (counts.DAMAGER>=3)==(f.damagePresence=="present") end
   end
   if pass and (f.friends or f.guild) then
    local friends=r.bnetFriends+r.charFriends>0;local guild=r.guildMates>0
    if f.friends and not friends or f.guild and not guild then pass=false end
   end
   if pass and (f.notes and f.notes~="noCaution" or f.personKey and f.personKey~=r.leaderKey) then pass=false end
   if pass and playerSpecID then pass=not self.Results:HasMemberSpec(r,playerSpecID) end
   if pass then ids[#ids+1]=id end
  end
  table.sort(ids,function(a,b)
   local x,y=self.records[a],self.records[b];local key=f.sort=="rating" and "leaderRating" or f.sort=="itemLevel" and "requiredItemLevel" or f.sort=="members" and "numMembers"
   local xf,yf=x.bnetFriends+x.charFriends>0,y.bnetFriends+y.charFriends>0
   if xf~=yf then return xf end
   if key and x[key]~=y[key] then return x[key]>y[key] end
   return x.age<y.age
  end)
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
  for _,app in pairs(self.applicants) do
   app.activityID=activityID
   for index,member in ipairs(app.members) do
    member.applicantID,member.applicantIndex=app.id,index
    member.ratingKind=profile.kind=="pvp" and "pvp" or "dungeon"
    if profile.kind=="pvp" then member.rating=profile.requirementRatingKind and 1800+index*75 or nil
    else member.rating=member.dungeonScore end
    member.dungeonScores=profile.applicant.showDungeonRecords and {mapScore=280+index*12,current={name=activity.fullName or activity.name,level=18,timed=true},best={name=activity.fullName or activity.name,level=19,timed=false}} or nil
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
 local classes={"WARRIOR","PRIEST","MAGE","SHAMAN","ROGUE"}
 local roles={"TANK","HEALER","DAMAGER","HEALER","DAMAGER"}
 local specs={73,257,64,264,260}
 local names={S("预览坦克","PreviewTank"),S("预览治疗","PreviewHealer"),S("预览法师","PreviewMage"),S("预览萨满","PreviewShaman"),S("预览潜行者","PreviewRogue")}
 local function Member(index)
  local slot=(index-1)%5+1;local name=names[slot]..(index>5 and tostring(index) or "");local realm=S("模拟服务器","PreviewRealm")
  local relation=(index-1)%4
  return {isPreview=true,name=name,realm=realm,nameKey=name.."-"..realm,class=classes[slot],assignedRole=roles[slot],specID=specs[slot],itemLevel=260+slot*3,dungeonScore=2400+slot*135,factionGroup=index%2,raceID=index%2==1 and 1 or 2,raceName=index%2==1 and S("人类","Human") or S("兽人","Orc"),isBNetFriend=relation==1,isCharFriend=relation==2,isGuildMate=relation==3,isFriend=false}
 end
 p.recordIDs={};p.applicantIDs={1,2,3};p.emptyIDs={}
 for i=1,6 do
  local members={Member(i),Member(i+1)};members[1].isLeader=true
  if i==6 then for _,member in ipairs(members) do member.isBNetFriend,member.isCharFriend,member.isGuildMate=false,false,false end end
  local counts={TANK=0,HEALER=0,DAMAGER=0};local bnet,character,guild=0,0,0
  for _,m in ipairs(members) do
   counts[m.assignedRole]=counts[m.assignedRole]+1
   if m.isBNetFriend then bnet=bnet+1 end;if m.isCharFriend then character=character+1 end;if m.isGuildMate then guild=guild+1 end
  end
  local id=-9000-i
  local r={id=id,isPreview=true,name=S("模拟队伍 ","Preview group ")..i,comment=S("本地预览样例：操作不会发送到游戏。","Local preview: actions are never sent to the game."),activity=activity,activityID=activity.id,activityName=activity.name,categoryID=activity.categoryID,numMembers=#members,maxNumPlayers=activity.maxNumPlayers or 5,leaderName=members[1].nameKey,leaderKey=members[1].nameKey,leaderOverallDungeonScore=members[1].dungeonScore,requiredItemLevel=260+i*2,age=i*47,level=activity.isMythicPlusActivity and 8+i or nil,charFriends=character,bnetFriends=bnet,guildMates=guild,details={members=members,counts=counts}}
  local profile=A.GroupPresentation.Activity(activity)
  r.ratingKind=profile.kind=="pvp" and "pvp" or "dungeon"
  if profile.kind=="pvp" then r.leaderRating=profile.requirementRatingKind and 1600+i*75 or nil
  else r.leaderRating=members[1].dungeonScore end
  p.records[id]=r;p.recordIDs[#p.recordIDs+1]=id
  if scenario=="applications" and i<=3 then p.apps[#p.apps+1]={id=id,status=i==1 and "invited" or "applied",name=r.name,result=r,categoryID=r.categoryID,leaderName=r.leaderName,expiresAt=GetTime()+300-i*30} end
 end
 p.roster={Member(1),Member(2),Member(3)};p.roster[1].isLeader=true
 p.applicants[1]={id=1,status="applied",displayOrderID=1,comment=S("单人模拟申请，可以治疗。","Single applicant; can heal."),members={Member(4)}}
 p.applicants[2]={id=2,status="applied",displayOrderID=2,comment=S("两位同行，邀请与拒绝作用于整组。","Two friends applying together; actions affect the whole batch."),members={Member(5),Member(6)}}
 p.applicants[3]={id=3,status="applied",displayOrderID=3,comment=S("模拟备注，查看职责、装等和评分。","Sample note; compare role, item level and score."),members={Member(7)}}
 p:SetApplicantActivity(activity.id)
 if scenario=="applicants" then p.listing={activityID=activity.id,activityName=activity.name,name=S("模拟招募 · 申请者预览","Preview listing · applicants"),comment=S("本地模拟招募，不会发布到游戏。","Local preview listing; never published to the game."),requiredItemLevel=260,requiredDungeonScore=2000,generalPlaystyle=Enum.LFGEntryGeneralPlaystyle.FunRelaxed} end
 return p
end
function UI:UpdatePreviewIndicator()
 if not self.frame then return end
 if self.preview and not self.previewExit then
  self.previewExit=self.C.Button(self.frame,S("预览 · 退出","Preview · Exit"),112,function() UI:StopPreview(true) end)
  self.previewExit:SetHeight(32);self.previewExit:SetPoint("RIGHT",self.settingsButton,"LEFT",-12,0);self:Color(self.previewExit.label,self.Theme.accent)
 end
 if self.previewExit then self.previewExit:SetShown(self.preview~=nil) end
end
function UI:StartPreview(scenario)
 if scenario~="applications" and scenario~="create" and scenario~="applicants" then return false,S("用法：/lg test applications|create|applicants|off","Usage: /lg test applications|create|applicants|off") end
 local provider,err=NewProvider(scenario);if not provider then return false,err end
 local returnPage=self.preview and self.preview.returnPage or self.page or "find"
 self:Hide(true)
 self.preview={provider=provider,scenario=scenario,returnPage=returnPage}
 self.pages.find:BeginPreview(provider);self.pages.create:BeginPreview(provider)
 self:Show(scenario=="applications" and "find" or "create");self:UpdatePreviewIndicator()
 return true
end
function UI:EndPreview()
 if not self.preview then return end
 self.Motion:Stop(self.preview.provider)
 self.preview=nil
 self.pages.find:EndPreview();self.pages.create:EndPreview();self:UpdatePreviewIndicator()
end
function UI:StopPreview(reopen)
 if not self.preview then return true end
 local page=self.preview.returnPage
 self:Hide(true)
 if reopen then A:Open(page) end
 return true
end
