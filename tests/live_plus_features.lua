-- LycheeDev real-data acceptance. Run only against an already open Find scene.
-- Controller/Button:Click coverage, not hardware input or protected business actions.
local probe=...
local A=assert(LycheeGroup,"addon_missing")
local U,G=A.UI,A.Group
local out={scope="real native data; controller calls and Button:Click; no hardware dispatch, applications, invitations, cancellations or listings",uncovered={},filters={},scores={}}
local started=GetTime()
local function Public(value) if issecretvalue and issecretvalue(value) then return end;return value end
local function Accessible(value)
 value=Public(value)
 if type(value)=="table" and (not canaccesstable or canaccesstable(value)) then return value end
end
local function Number(value) value=Public(value);if type(value)=="number" and value>=0 and value<math.huge then return value end end
local function Copy(value,depth,count)
 if type(value)~="table" then return value end
 depth=(depth or 0)+1;assert(depth<=12,"snapshot_depth_limit")
 count=count or {0};local copy={}
 for key,item in pairs(value) do count[1]=count[1]+1;assert(count[1]<=4096,"snapshot_size_limit");copy[key]=Copy(item,depth,count) end
 return copy
end
local function Same(a,b)
 if type(a)~="table" or type(b)~="table" then return a==b end
 for key,value in pairs(a) do if not Same(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end
 return true
end
local function Restore(target,snapshot)
 for key in pairs(target) do if snapshot[key]==nil then target[key]=nil end end
 for key,value in pairs(snapshot) do
  if type(value)=="table" then
   if type(target[key])~="table" then target[key]={} end
   Restore(target[key],value)
  else target[key]=value end
 end
end
local function Unavailable(reason)
 out.uncovered[#out.uncovered+1]=reason;probe:Log(out);probe:Fail(reason)
end
if not U or not G or not U:IsShown() or U.page~="find" or U.hiding or U.preview or U.activeModal then Unavailable("requires_visible_real_find_without_modal");return end
local P=U.pages.find;local Tip=U.Tooltip
if InCombatLockdown() then Unavailable("combat_not_supported");return end
if U.context:GetMenuAnchor() or P.picker and P.picker:IsShown() or Tip.interactive and Tip.interactive:IsShown() or Tip.text and Tip.text:IsShown() then Unavailable("close_existing_menu_or_tooltip_before_probe");return end
local currentFilters=G.Search:GetFilters()
if currentFilters.category~="seasonDungeon" or currentFilters.difficultyID~=8 then Unavailable("requires_existing_season_keystone_results");return end
if G:GetSearchState()~="done" or G.Search.pending or G.Search.timer or G:GetResultCount()==0 then Unavailable("real_search_not_settled");return end
if not P.results.ids or #P.results.ids==0 then Unavailable("requires_visible_confirmed_result_list");return end
if type(GetFramesRegisteredForEvent)~="function" or not C_MythicPlus or type(C_MythicPlus.GetSeasonBestForMap)~="function" or type(C_MythicPlus.GetSeasonBestAffixScoreInfoForMap)~="function" or not C_ChallengeMode or type(C_ChallengeMode.GetMapTable)~="function" or type(C_ChallengeMode.GetMapUIInfo)~="function" then Unavailable("required_native_score_api_unavailable");return end
if not A.ActivityLabels or not U.PlayerLinks or not G.SeasonScores then Unavailable("integrated_modules_not_loaded");return end
local savedFilters=Copy(currentFilters)
local prefsReference=G.prefs.find;local savedPrefs=Copy(prefsReference)
local saved={page=U.page,shown=U:IsShown(),filtersOpen=P.filtersOpen==true,offset=P.results.pixelOffset or P.results.clip:GetVerticalScroll(),selected=P.results.selectedKey}
local generation,searchGeneration=G.Results.gen,G.Search.generation
local playerGUID=Public(UnitGUID("player"))
if not playerGUID then Unavailable("player_identity_unavailable");return end
local timer,cleaned,completed,mutated
local function CloseScores()
 if P.picker then P:ClosePicker() end
end
local function Clean()
 if cleaned then return end
 if timer then timer:Cancel();timer=nil end
 Tip:Hide();CloseScores();U:CloseMenu()
 if mutated then
  -- No settings API is used. Restore both the original preference reference
  -- and the live service filters even if a controller failed mid-experiment.
  if type(prefsReference)=="table" then Restore(prefsReference,savedPrefs) end
  G.prefs.find=prefsReference
  G.Search:SetFilters(Copy(savedFilters))
  P.results.selectedKey=saved.selected;P.results:Refresh();P.results:SetPixelOffset(saved.offset or 0,false)
  P:SetFiltersOpen(saved.filtersOpen)
 end
 out.restored={preferences=G.prefs.find==prefsReference and Same(savedPrefs,prefsReference),filters=Same(savedFilters,G.Search:GetFilters()),page=U.page==saved.page,shown=U:IsShown()==saved.shown,filterPanel=P.filtersOpen==saved.filtersOpen,offset=math.abs((P.results.pixelOffset or 0)-(saved.offset or 0))<.05,modal=U.activeModal==nil,menu=U.context:GetMenuAnchor()==nil,tooltip=not Tip.interactive or not Tip.interactive:IsShown(),picker=not P.picker or not P.picker:IsShown()}
 for key,value in pairs(out.restored) do assert(value,"restore_failed_"..key) end
 cleaned=true
end
assert(probe:OnCleanup(function()
 Clean()
 if not completed then out.aborted=true;out.elapsedSeconds=GetTime()-started;probe:Log(out) end
end))
assert(probe:Guard(function()
 return not InCombatLockdown() and Public(UnitGUID("player"))==playerGUID and U:IsShown() and U.page=="find" and not U.hiding and not U.preview and not U.activeModal and G.Results.gen==generation and G.Search.generation==searchGeneration
end,{"PLAYER_REGEN_DISABLED","PLAYER_LEAVING_WORLD"},"real_scene_changed"))
assert(probe:Async(105))
local function Check(value,reason) assert(value,reason) end
local function Budget() Check(not probe:IsCancelled() and GetTime()-started<90,"probe_work_budget_exceeded_or_cancelled") end
local function IDs()
 local values=G:GetResults();Check(#values<=400,"result_sample_limit")
 local list={};for i,id in ipairs(values) do list[i]=id end;return list
end
local function DisplayReference(text)
 text=Public(text);if type(text)~="string" then return end
 return (text:gsub("史诗钥石","M+"):gsub("史诗钥匙","M+"):gsub("Mythic Keystone","M+"))
end
local function SetFilters(role,lust)
 local filters=Copy(savedFilters);filters.hideSameClassRole=role;filters.requireBloodlust=lust
 G.Search:SetFilters(filters);return IDs()
end
out.build=select(2,GetBuildInfo());out.locale=A:GetLocale();out.resultCount=G:GetResultCount();out.fontScale=A:GetSetting("fontScale")
out.phase="display_and_filters"
-- Isolate any incidental Find save without changing any settings or business data.
G.prefs.find=Copy(prefsReference);mutated=true
local baseline=SetFilters(nil,nil)
Check(#baseline>0,"baseline_results_unavailable")
local visible=0
for _,row in ipairs(P.results.rows) do if row.key and row._hitVisible then
 local record=G:GetResult(row.key);Check(record~=nil,"visible_result_missing")
 local rawActivity,rawTitle,rawComment=record.activityName,record.name,record.comment
 local activity=Public(rawActivity)
 local native=Accessible(C_LFGList.GetActivityInfoTable(record.activityID))
 local nativeName=native and Public(native.fullName)
 if nativeName=="" or nativeName==nil then nativeName=native and Public(native.shortName) end
 Check(type(nativeName)=="string" and activity==nativeName,"raw_activity_differs_from_native_"..row.key)
 Check(record.activity and record.activity.name==nativeName,"catalog_name_was_rewritten_"..row.key)
 if type(activity)=="string" then
  Check(Public(row.meta:GetText())==DisplayReference(activity),"activity_display_mismatch_"..row.key)
  Check(A.ActivityLabels.Display(activity)==DisplayReference(activity),"activity_alias_mismatch")
 end
 Check(row.title:GetText()==rawTitle,"player_title_was_rewritten")
 Check(record.activityName==rawActivity and record.name==rawTitle and record.comment==rawComment,"raw_result_fields_changed")
 local flags=row.marks.flags
 local color=U.Theme[flags.caution and "findTitleBlockedColor" or flags.bnet and "findTitleBnetColor" or flags.friend and "findTitleFriendColor" or flags.guild and "findTitleGuildColor" or "text"]
 local r,g,b=row.title:GetTextColor()
 Check(math.abs(r-color[1])<.004 and math.abs(g-color[2])<.004 and math.abs(b-color[3])<.004,"result_title_color_mismatch_"..row.key)
 visible=visible+1
end end
Check(visible>0,"no_visible_result_rows")
Check(math.abs(U.Theme.findResultRowHeight-53)<.001 and P.results.rowHeight>=53,"result_base_height_mismatch")
Check(math.abs(U.Theme.findResultLeaderMin-112)<.001 and P.resultsHeader.columns.leader.minimum>=112,"leader_column_minimum_mismatch")
out.display={visible=visible,baseHeight=U.Theme.findResultRowHeight,actualStride=P.results.rowHeight,leaderBaseMinimum=U.Theme.findResultLeaderMin,leaderMinimum=P.resultsHeader.columns.leader.minimum}
local playerClass=Public(select(2,UnitClass("player")))
local spec=Public(C_SpecializationInfo.GetSpecialization())
local playerRole=spec and Public(select(5,C_SpecializationInfo.GetSpecializationInfo(spec)))
Check(type(playerClass)=="string" and (playerRole=="TANK" or playerRole=="HEALER" or playerRole=="DAMAGER"),"player_class_or_spec_role_unavailable")
local lustClasses={SHAMAN=true,MAGE=true,HUNTER=true,EVOKER=true}
local independent={}
for _,id in ipairs(baseline) do
 Budget();local record=G:GetResult(id);Check(record~=nil,"baseline_record_lost")
 local count=Number(record.numMembers);Check(count and count<=40,"native_roster_size_unavailable")
 local duplicate,lust,unknown=false,false,false
 for index=1,count do
  local info=Accessible(C_LFGList.GetSearchResultPlayerInfo(id,index))
  if info then
   local class=Public(info.classFilename) or Public(info.class)
   if class==playerClass and Public(info.assignedRole)==playerRole then duplicate=true end
   if type(class)~="string" or class=="" then unknown=true elseif lustClasses[class] then lust=true end
  else unknown=true end
 end
 independent[id]={role=not duplicate,lust=lustClasses[playerClass] or count<4 or lust or unknown}
end
for _,case in ipairs({{name="same_class_role",role=true},{name="bloodlust",lust=true},{name="both",role=true,lust=true}}) do
 Budget();local actual=SetFilters(case.role,case.lust);local expected={}
 for _,id in ipairs(baseline) do local ref=independent[id];if (not case.role or ref.role) and (not case.lust or ref.lust) then expected[id]=true end end
 local mismatches={};local expectedCount=0
 for _ in pairs(expected) do expectedCount=expectedCount+1 end
 for _,id in ipairs(actual) do if expected[id] then expected[id]=nil elseif #mismatches<12 then mismatches[#mismatches+1]=id end end
 for id in pairs(expected) do if #mismatches<12 then mismatches[#mismatches+1]=id end end
 out.filters[#out.filters+1]={name=case.name,baseline=#baseline,actual=#actual,expected=expectedCount,mismatchIDs=mismatches}
 Check(#mismatches==0 and #actual==expectedCount,"filter_reference_mismatch_"..case.name)
end
G.Search:SetFilters(Copy(savedFilters))

local function MapFrames()
 local list={GetFramesRegisteredForEvent("CHALLENGE_MODE_MAPS_UPDATE")};Check(#list<=512,"event_registry_limit")
 local set={};for _,frame in ipairs(list) do set[frame]=true end;return set
end
local events={"CHALLENGE_MODE_MAPS_UPDATE","CHALLENGE_MODE_COMPLETED","PLAYER_ENTERING_WORLD"}
local beforeFrames=MapFrames()
out.phase="season_scores"
if not P.picker then P:BuildPicker() end
P:RefreshPicker();P.picker:Show()
Check(P.pickerScoreService==G.SeasonScores,"score_picker_service_not_active")
local ownedFrames={}
for frame in pairs(MapFrames()) do
 if not beforeFrames[frame] and frame:IsEventRegistered(events[2]) and frame:IsEventRegistered(events[3]) then ownedFrames[#ownedFrames+1]=frame end
end
Check(#ownedFrames>0,"score_event_owner_not_observable")
local function NativeScores()
 local mapToCM={};local maps=Accessible(C_ChallengeMode.GetMapTable());Check(maps and #maps<=128,"native_challenge_map_table_unavailable")
 for _,id in ipairs(maps) do
  id=Number(id)
  if id and id>0 then
   local mapID=Number(select(6,C_ChallengeMode.GetMapUIInfo(id)))
   if mapID and mapID>0 then if mapToCM[mapID]==nil then mapToCM[mapID]=id elseif mapToCM[mapID]~=id then mapToCM[mapID]=false end end
  end
 end
 local groups=G.Catalog:GetGroups("seasonDungeon");Check(#groups<=32,"season_group_limit")
 local rows,matches={},true
 for _,group in ipairs(groups) do
  Budget();local mapID,ambiguous,mythic
  for _,activity in ipairs(group.variants or {}) do if activity.isMythicPlusActivity then
   mythic=true;local candidate=Number(activity.mapID)
   if not candidate or candidate==0 or mapID and candidate~=mapID then ambiguous=true end
   mapID=mapID or candidate
  end end
  if mythic then
   local cmID=not ambiguous and mapID and mapToCM[mapID]
   local level,score
   if cmID then
    local run=Accessible(C_MythicPlus.GetSeasonBestForMap(cmID));level=run and Number(run.level);if level==0 then level=nil end
    score=Number(select(2,C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(cmID)))
   end
   local record=G.SeasonScores:GetRecord(group)
   local match=record.level==level and record.score==score;matches=matches and match
   rows[#rows+1]={group=group.key,mapID=mapID,challengeID=cmID or nil,ambiguous=ambiguous==true,level=record.level,nativeLevel=level,score=record.score,nativeScore=score,match=match}
  end
 end
 Check(#rows>0,"no_real_season_keystone_groups")
 return rows,matches
end
local attempts=0
local ScoreStage
ScoreStage=assert(probe:Callback(function()
 if probe:IsCancelled() then return end
 attempts=attempts+1;out.scores.rows,out.scores.match=NativeScores();out.scores.attempts=attempts
 if not out.scores.match and attempts<8 then timer=C_Timer.NewTimer(1,ScoreStage);return end
 Check(out.scores.match,"native_season_score_mismatch")
 CloseScores()
 for _,frame in ipairs(ownedFrames) do for _,event in ipairs(events) do Check(not frame:IsEventRegistered(event),"score_subscription_survived_close_"..event) end end
 out.scores.eventOwners=#ownedFrames;out.scores.closed=true
 out.phase="roster_io_copy"
 local selfMember
 for _,member in ipairs(G:GetRoster()) do if Public(member.guid)==playerGUID or Public(member.unit)=="player" then selfMember=member;break end end
 Check(selfMember~=nil,"current_player_not_in_real_roster")
 local key,name,realm=U.PlayerLinks.Identity(selfMember);Check(key and name and realm,"real_roster_identity_unavailable")
 local slug=U.PlayerLinks.GetRealmSlug(realm);local region=Public(GetCurrentRegion());local regions={"us","kr","eu","tw","cn"}
 Check(slug and type(region)=="number" and regions[region],"current_player_io_region_or_realm_unavailable")
 local function Encode(value) return (value:gsub("[^A-Za-z0-9%-%_%.~]",function(byte) return ("%%%02X"):format(byte:byte()) end)) end
 local expected="https://raider.io"..(A:GetLocale()=="zhCN" and "/cn" or "").."/characters/"..regions[region].."/"..Encode(slug).."/"..Encode(name)
 Tip:ShowPlayer(P.frame,selfMember,A.GroupPresentation.Member("roster"))
 local identity=Tip.selectedMemberID;Check(Tip.directPlayer==true and Tip.interactive.io:IsEnabled(),"real_player_io_action_unavailable")
 Tip.interactive.io:Click()
 local view=Tip.interactive;local box=view.copyField.box
 Check(view.copyField:IsShown() and not U.activeModal,"io_inline_copy_missing")
 local url=Public(box:GetText())
 Check(url==expected,"io_copy_url_mismatch")
 Check(Tip.selectedMemberID==identity and Tip.directPlayer==true and view:IsShown(),"io_copy_changed_player_identity")
 Check(Tip.pinned and box:HasFocus(),"io_copy_not_focused")
 Tip:Hide()
 Check(not view.copyField:IsShown() and not box:HasFocus() and Public(box:GetText())=="","io_copy_focus_or_text_retained")
 out.io={identity=key,url=url,inline=true,identityPreserved=true,focusReleased=true}
 out.phase="restore"
 Clean();out.elapsedSeconds=GetTime()-started;completed=true;probe:Finish(out)
end))
timer=C_Timer.NewTimer(2,ScoreStage)
