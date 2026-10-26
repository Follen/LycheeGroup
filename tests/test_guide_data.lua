-- Native activity selection and isolated Guide sample records. No game client is contacted.
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function equal(actual,expected,message) check(actual==expected,message) end
local function LoadGuideData(locale,challenge,existing)
 local reads=0;local app=existing or {};app.Guide={}
 function app:GetLocale() reads=reads+1;return locale end
 if not existing then setmetatable(app,{__index=function(_,key) error("unexpected application dependency: "..tostring(key)) end}) end
 local env={LycheeGroup=app,ipairs=ipairs,pairs=pairs,next=next,type=type,math=math,table=table,tostring=tostring,tonumber=tonumber,
  wipe=wipe,GetTime=GetTime,C_LFGList=C_LFGList,C_ChallengeMode=challenge}
 env._G=env
 setmetatable(env,{__index=function(_,key) error("external API access: "..tostring(key)) end})
 setfenv(assert(loadfile("addon/LycheeGroup_Guide/Data.lua")),env)()
 setfenv(assert(loadfile("addon/LycheeGroup_Guide/Provider.lua")),env)()
 equal(reads,0,"loading Guide data and provider does not read locale or the client")
 equal(app.Guide.Catalog,nil,"Guide does not register a fabricated activity catalog")
 return app.Guide
end
local function Catalog()
 local ordinary={key="2",id=2};local raid={key="3",id=3};local seasonal={key="seasonDungeon",id=2,season=true}
 local normal={id=201,categoryID=2,groupKey=20,difficultyID=1,name="Native normal dungeon"}
 local mythic={id=202,categoryID=2,groupKey=21,difficultyID=8,isMythicPlusActivity=true,mapID=220,name="Native seasonal dungeon"}
 local older={id=101,categoryID=2,groupKey=10,difficultyID=2,name="Native dungeon"}
 local raidActivity={id=301,categoryID=3,groupKey=30,name="Native raid"}
 local c={categories={ordinary,raid,seasonal},activities={["2"]={older},["3"]={raidActivity},seasonDungeon={normal,mythic}},groups={},byID={},builds=0}
 for _,activity in ipairs({normal,mythic,older,raidActivity}) do
  c.byID[activity.id]=activity;c.groups[activity.groupKey]={key=activity.groupKey,activity=activity,variants={activity}}
 end
 function c:Build() self.builds=self.builds+1 end
 function c:GetCategories() return self.categories end
 function c:GetActivities(key) return self.activities[key] end
 function c:GetGroupKey(_,activity) return activity.groupKey end
 function c:GetGroup(_,key) return self.groups[key] end
 function c:GetActivity(id) return self.byID[id] end
 return c,mythic,normal,older
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local guide=LoadGuideData(locale);local catalog,mythic,normal,ordinary=Catalog()
 local activity,key,group=guide:ResolveActivity(catalog)
 equal(activity,mythic,"seasonal keystones take priority over earlier categories and normal variants")
 equal(key,"seasonDungeon","the selected category retains its native key")
 equal(group,catalog.groups[mythic.groupKey],"the selected group retains native object identity")
 equal(catalog.builds,1,"directory construction happens only after explicit resolution")
 for index=1,20 do
  local selected,category,selectedGroup=guide:ResolveActivity(catalog)
  equal(selected,mythic,"repeated selection never copies or rewrites the native activity")
  equal(category,key,"repeated selection preserves the native context")
  equal(selectedGroup,group,"repeated selection reuses the native group")
 end
 catalog.activities.seasonDungeon={normal}
 equal(guide:ResolveActivity(catalog),normal,"a seasonal ordinary dungeon remains a valid fallback")
 catalog.activities.seasonDungeon={}
 local selected,category=guide:ResolveActivity(catalog)
 equal(selected,ordinary,"ordinary dungeons remain available when the seasonal list is empty")
 equal(category,"2","ordinary dungeons keep their actual category")
 catalog.activities["2"]={}
 local missing,reason=guide:ResolveActivity(catalog)
 equal(missing,nil,"an empty dungeon directory never falls back to a fabricated ID or raid")
 check(type(reason)=="string" and reason~="","an empty catalog reports an actionable localized error")
 check(reason:find(locale=="zhCN" and "当前游戏活动目录" or "game activity catalog",1,true),"the error explains which real source is unavailable")
 catalog.activities.seasonDungeon={{id=-1,categoryID=2,groupKey=20,isMythicPlusActivity=true},mythic}
 catalog.byID[mythic.id]={id=mythic.id}
 equal(guide:ResolveActivity(catalog),nil,"negative IDs and copied activity metadata are rejected")
 catalog.byID[mythic.id]=mythic;catalog.groups[mythic.groupKey]=nil
 equal(guide:ResolveActivity(catalog),nil,"an activity without a real picker group is not a usable seed")
 equal(guide:ResolveActivity(nil),nil,"a missing native catalog has no fallback")
 local empty={GetCategories=function() return nil end,GetActivities=function() return nil end,GetGroupKey=function() end,GetGroup=function() end,GetActivity=function() end}
 equal(guide:ResolveActivity(empty),nil,"not-yet-populated catalog collections fail clearly")
end

do
 local reads,tableReads=0,0
 local challenge={GetMapTable=function() tableReads=tableReads+1;return {7,8,9} end,GetMapUIInfo=function(id)
  reads=reads+1
  if id==7 then return "First dungeon",nil,2400,nil,nil,220 end
  if id==8 then return "Second dungeon",nil,1980,nil,nil,330 end
  return "Unavailable dungeon",nil,0,nil,nil,440
 end}
 local guide=LoadGuideData("enUS",challenge)
 equal(reads,0,"loading Guide does not enumerate challenge metadata")
 equal(guide:ResolveTimeLimit({mapID=220}),2400,"the limit uses native map metadata rather than a fixed example")
 equal(reads,1,"the first matching native map ends the static scan")
 equal(guide:ResolveTimeLimit({mapID=220}),2400,"the current successful map lookup is reused")
 equal(reads,1,"a repeated map lookup performs no client reads")
 equal(guide:ResolveTimeLimit({mapID=330}),1980,"another dungeon uses its own actual limit")
 equal(guide:ResolveTimeLimit({mapID=440}),nil,"unknown native limits are not replaced with thirty minutes")
 local before=tableReads
 equal(guide:ResolveTimeLimit({mapID=440}),nil,"a later explicit request may retry an unavailable map")
 equal(tableReads,before+1,"failed map lookups are not retained forever")
 before=reads
 equal(guide:ResolveTimeLimit({mapID=330}),1980,"an unsuccessful lookup does not discard the last successful static map")
 equal(reads,before,"only one successful map remains cached")
 equal(guide:ResolveTimeLimit({mapID=-1}),nil,"negative maps do not reach the client")
 equal(guide:ResolveTimeLimit({}),nil,"missing maps do not invent activity metadata")
 equal(guide:ResolveTimeLimit(nil),nil,"a missing activity has no time limit")
 equal(reads,before,"invalid inputs never call a native function")
end

-- Construct the Guide provider directly; no guide options enter the old Preview package.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale);local a,u,g=f.A,f.U,f.G
 local nativeInfo,nativeActivities,nativeFullName=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities,C_LFGList.GetActivityFullName
 nativeInfo(2).mapID=222
 local other={id=4,categoryID=2,mapID=444,fullName="Second native dungeon",shortName="Second",groupFinderActivityGroupID=40,difficultyID=8,isMythicPlusActivity=true,maxNumPlayers=5,orderIndex=4,allowCrossFaction=true}
 C_LFGList.GetActivityInfoTable=function(id) return id==4 and other or nativeInfo(id) end
 C_LFGList.GetAvailableActivities=function(category,group,flags) if category==2 and (flags==68 or flags==4) then return {2,4,3} end;return nativeActivities(category,group,flags) end
 C_LFGList.GetActivityFullName=function(id) return id==4 and other.fullName or nativeFullName(id) end
 local challenge={GetMapTable=function() return {22,44} end,GetMapUIInfo=function(id)
  return "Native dungeon",nil,id==22 and 2400 or 1980,nil,nil,id==22 and 222 or 444
 end}
 local nodes=#f.S.nodes
 local guide=LoadGuideData(locale,challenge,a)
 equal(#f.S.nodes,nodes,"loading Data and Provider allocates no native object")
 local activity,category,group=guide:ResolveActivity(g.Catalog)
 equal(activity,g.Catalog:GetActivity(2),"the selector consumes the production native catalog")
 equal(group,g.Catalog:GetGroup(category,activity.groupKey),"the selected picker group is the original production object")
 local function Trap(owner,key) owner[key]=function() error("real player read or mutation reached during Guide: "..key) end end
 for _,key in ipairs({"Search","ApplyToGroup","CreateListing","UpdateListing","RemoveListing","InviteApplicant","DeclineApplicant","CancelApplication","AcceptInvite","ClearApplicationTextFields","ClearCreationTextFields","ClearSearchTextFields","CopyActiveEntryInfoToCreationFields","SetEntryTitle",
  "GetApplicantInfo","GetApplicantMemberInfo","GetSearchResults","GetSearchResultInfo","GetSearchResultMemberInfo","GetActiveEntryInfo","GetApplicationInfo","GetApplications"}) do Trap(C_LFGList,key) end
 for _,key in ipairs({"Apply","Publish","Update","RemoveListing","Invite","Decline","Cancel","GetRoster","GetApplicants","GetApplicant","GetApplications"}) do Trap(g,key) end
 Trap(g.Search,"Search");Trap(_G,"SetLFGRoles");Trap(_G,"UnitClass");Trap(a.Specializations,"Player")
 Trap(C_SpecializationInfo,"GetSpecialization");Trap(C_SpecializationInfo,"GetSpecializationInfo")
 local nativeGet=u.Native.GetPreviewCreationText
 u.Native.GetPreviewCreationText=function() return "Dungeon run","Ready to go" end
 local player={class="SHAMAN",specID=264,role="HEALER",roles={TANK=false,HEALER=true,DAMAGER=true}}
 local options={catalog=g.Catalog,activity=activity,category=category,player=player}
 local provider,reason=guide:CreateProvider("applications",options)
 check(provider,reason or "Guide provider constructs directly")
 equal(#f.S.nodes,nodes,"constructing the teaching records allocates no native UI")
 equal(u.preview,nil,"constructing a provider neither starts nor replaces ordinary Preview")
 equal(provider.Catalog,g.Catalog,"the provider does not wrap or duplicate the real catalog")
 equal(provider.activity,activity,"the provider retains selected activity identity")
 equal(a.Group,g,"the real backend remains installed")
 check(provider.prefs~=a.charPrefs and provider.applicationPrefs~=a.charPrefs,"the provider owns private preference containers")
 equal(provider:GetResultCount(),6,"the provider has six fixed teaching groups")
 equal(#provider:GetApplications(),0,"Guide groups are initially selectable rather than already applied")
 local firstID=provider.recordIDs[1];local first=provider.records[firstID]
 local current=provider:GetApplicant(1).members[1].dungeonScores.current
 equal(current.timeLimitSeconds,2400,"sample run times use this real dungeon's native limit")
 local initialIDs=provider.recordIDs
 local visible=provider:GetResults()
 equal(#visible,6,"initial Guide data leaves all teaching records selectable")
 for _,record in pairs(provider.records) do
  equal(record.activity,activity,"sample listings reference the selected real activity")
  for _,value in ipairs({record.name,record.comment,record.leaderName}) do
   for _,marker in ipairs({"演示","模拟","Preview","Demo"}) do check(not value:find(marker,1,true),"ordinary sample text does not repeat the introductory explanation") end
  end
 end
 for index=1,3 do for _,member in ipairs(provider.applicants[index].members) do
  for _,marker in ipairs({"演示","模拟","Preview","Demo"}) do check(not member.name:find(marker,1,true) and not provider.applicants[index].comment:find(marker,1,true),"applicants use normal sample names and notes") end
 end end
 provider:SetFilters({category=category,selected=true,difficultyID=other.difficultyID,groupKeys={[other.groupKey]=true}})
 for index=1,20 do provider.Search:Search(category,{other.id}) end
 equal(provider.recordIDs,initialIDs,"searches reuse the original six record identities")
 equal(provider.records[firstID],first,"searches rebind the existing group instead of allocating replacements")
 equal(first.activity,other,"searching another real activity rebinds to that native object")
 equal(provider:GetResults(),visible,"Guide result queries reuse a bounded visible-ID array")
 equal(#visible,6,"any selected real seasonal dungeon has six teaching groups")
 equal(current.timeLimitSeconds,1980,"rebinding reuses the run record with the new dungeon's actual limit")
 equal(provider:GetApplicant(1).members[1].dungeonScores.current,current,"repeated applicant activity reads reuse run data")
 provider:SetApplicantActivity(other.id)
 equal(provider:GetApplicant(1).members[1].dungeonScores.current,current,"same activity does not expand applicant records")
 provider:SetFilters({category=category,hideSameSpec=true,hideSameClass=true,hideSameClassRole=true,requireBloodlust=true})
 check(provider:GetResults(),"player-dependent filters use the supplied teaching player without native reads")
 provider:SetFilters({category=category})
 provider.SeasonScores:Begin(function() end)
 local seasonal=provider.SeasonScores:GetRecord(group)
 equal(provider.SeasonScores:GetRecord({key=999}),seasonal,"repeated score queries reuse one teaching score")
 provider.SeasonScores:End()
 check(provider:Apply(firstID,{HEALER=true},"Ready"),"applying changes only the sample provider")
 equal(#provider:GetApplications(),1,"the sample application appears only after an explicit apply")
 check(provider:Cancel(firstID),"cancelling the sample application stays local")
 check(provider:Publish({activityID=other.id,requiredItemLevel=260}),"sample publishing never reaches native group actions")
 equal(g:GetListing(),nil,"the real listing is unchanged")
 equal(provider:GetListing().activityID,other.id,"the sample listing preserves real activity identity")
 check(provider:Invite(1),"sample invitation never reaches native group actions")
 check(provider:Decline(2),"sample rejection never reaches native group actions")
 check(provider:RemoveListing(),"sample listing removal never reaches native group actions")
 local bad,why=guide:CreateProvider("applications",{catalog=g.Catalog,activity={id=other.id},category=category,player=player})
 equal(bad,nil,"a copied activity is rejected rather than becoming a fake directory entry")
 check(type(why)=="string" and why~="","invalid selection has an explicit error")
 equal(guide:CreateProvider("applications",{catalog=g.Catalog,activity=activity,category="missing",player=player}),nil,"empty categories cannot produce private replacement activities")
 equal(guide:CreateProvider("applications",{catalog=g.Catalog,activity=activity,category=category}),nil,"missing sample players never fall back to the current real player")
 equal(guide:CreateProvider("missing",options),nil,"unknown scenarios fail before construction")
 equal(guide:CreateProvider("applications"),nil,"missing options cannot reach the native directory")
 local normal=g.Catalog:GetActivity(3)
 local plain=guide:CreateProvider("create",{catalog=g.Catalog,activity=normal,category=category,player=player})
 check(plain,"a real ordinary dungeon can initialize the teaching form")
 equal(plain:GetApplicant(1).members[1].dungeonScores,nil,"ordinary dungeons do not invent keystone records")
 local missingLimit=guide.ResolveTimeLimit
 guide.ResolveTimeLimit=function() return nil end
 local unknown=guide:CreateProvider("create",options)
 check(unknown,"a missing static limit does not require fabricated activity data")
 local run=unknown:GetApplicant(1).members[1].dungeonScores.current
 equal(run.timeLimitSeconds,nil,"unknown limits remain unknown in the provider")
 equal(run.durationMs,nil,"unknown static limits never generate a made-up run duration")
 equal(select(2,unknown:GetApplicantTimeMargin(unknown:GetApplicant(1).members[1])),"unknown","unknown limit status is explicit")
 guide.ResolveTimeLimit=missingLimit
 u.Native.GetPreviewCreationText=nativeGet
 equal(u.preview,nil,"direct provider operations do not alter ordinary preview state")
 equal(#f.S.nodes,nodes,"provider operations create no frame or periodic driver")
end
print("Guide native activity data: "..checks.." checks passed")
