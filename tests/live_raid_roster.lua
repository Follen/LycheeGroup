-- Current native raid data and Frame/controller checks. Never calls Drop or a
-- subgroup mutation API; combat notices below explicitly exercise presentation.
local probe=...
local A=assert(LycheeGroup)
assert(not InCombatLockdown(),"combat")
assert(IsInRaid(),"real_raid_required")
local initial=A.UI
assert(not initial or not initial.preview and not initial.activeModal,"preview_or_modal")
local initialTip=initial and initial.Tooltip
assert(not initialTip or not initialTip.owner or initialTip.sourceRoster and not initialTip.member and not initialTip.rosterDrag,"existing_non_roster_tooltip")
local savedRosterTip=initialTip and initialTip.owner and initialTip:Capture()
local original={shown=initial and initial:IsShown(),page=initial and initial.page,returnPage=initial and initial.settingsReturnPage}
local originalPages={}
if initial then for key,page in pairs(initial.pages)do originalPages[key]=page.frame and page.frame:IsShown() or false end end
local U,G,Tip,timer,cleaned,page,originalFavorites
local out={scope="current native raid item levels, Frame geometry, drag start/cancel and explicit notice presentation; no hardware dispatch or subgroup mutation",checks=0,notices={}}
local function Check(value,message)out.checks=out.checks+1;assert(value,message)end
local function Clean()
 if cleaned then return end
 if timer then timer:Cancel();timer=nil end
 if Tip then Tip:Hide() end
 if page and originalFavorites~=nil and page.favoritesExpanded~=originalFavorites then page.favoritesExpanded=originalFavorites;page:RefreshFavorites() end
 if U and U.frame then
  if original.shown then assert(A:Open(original.page or "create"))else
   U:Hide(true)
   for key,page in pairs(U.pages)do if page.frame then page.frame:SetShown(originalPages[key]==true)end end
   U.page=original.page;U:UpdateNav()
  end
  U.settingsReturnPage=original.returnPage
  if savedRosterTip then Tip:Restore(savedRosterTip) end
 end
 cleaned=true
end
assert(probe:OnCleanup(Clean))
assert(probe:Async(15))
assert(probe:Guard(function()return not InCombatLockdown() and IsInRaid()end,{"PLAYER_REGEN_DISABLED","GROUP_ROSTER_UPDATE"},"raid_scene_changed"))
assert(A:Ensure("Group"));assert(A:Ensure("UI"))
G,U=A.Group,A.UI;Tip=U.Tooltip
Check(LycheeUI.version==38 and G.RaidGroups and G.RaidGroups.ResolveDrop and Tip.EnsureRosterDragGhost,"new_runtime_not_loaded")
assert(A:Open("create"))
local members=G:GetRoster()
Check(#members>0 and #members<=40,"native_roster_missing")
page=U.pages.create;originalFavorites=page.favoritesExpanded
if G:GetListing() and #G.Presets:Get()>0 then
 page.favoritesExpanded=true;page:RefreshFavorites()
 local checked=0
 for _,row in ipairs(page.favoritesList.rows)do if row.key and row._hitVisible then
  Check(not row.create:IsEnabled() and not row.unavailable:IsShown(),"recruiting_favorite_hint_not_removed")
  checked=checked+1
 end end
 out.favorites={checked=checked,applyDisabled=true,hintHidden=true}
 page.favoritesExpanded=originalFavorites;page:RefreshFavorites()
end
local owner=page.groupSummary:IsShown() and page.groupSummary or U.frame
Tip:ShowRoster(owner,members,true,{rosterMode="groups"})
local function Notices(f)
 local previousTimer
 for _,reason in ipairs({"playerCombat","sourceCombat","targetCombat"})do
  Tip:ShowRosterNotice(reason)
  local notice=f.rosterNotice
  Check(notice:IsShown() and notice.text:GetText()~="","notice_missing")
  Check(math.abs(notice:GetWidth()-f.canvas:GetWidth())<.1,"notice_width_mismatch")
  Check(notice:GetTop()<=f.title:GetBottom()-12,"notice_overlaps_title")
  for _,title in pairs(f.rosterGroupTitles)do if title:IsShown() then Check(title:GetTop()<=notice:GetBottom()-11,"notice_overlaps_group")end end
  if previousTimer then Check(previousTimer:IsCancelled(),"repeated_notice_retains_timer")end
  previousTimer=Tip.rosterNoticeTimer
  out.notices[#out.notices+1]={reason=reason,height=notice:GetHeight(),width=notice:GetWidth(),syntheticReason=true}
 end
 f.rosterNotice.close:Click()
 Check(not f.rosterNotice:IsShown() and Tip.rosterNoticeTimer==nil,"notice_manual_close_failed")
 Tip:ShowRosterNotice("sourceCombat")
 timer=C_Timer.NewTimer(4.2,assert(probe:Callback(function()
  Check(not f.rosterNotice:IsShown() and Tip.rosterNoticeTimer==nil,"notice_timeout_failed")
  Clean()
  Check(not Tip.rosterDrag and not Tip.rosterNoticeTimer and (savedRosterTip and f:IsShown() or not savedRosterTip and not f:IsShown()),"roster_cleanup_failed")
  out.previousRosterTooltipRestored=savedRosterTip~=nil
  out.resourcesReleased=true
  probe:Finish(out)
 end)))
end
local function Rect(frame)return {frame:GetLeft(),frame:GetTop(),frame:GetWidth(),frame:GetHeight()}end
local function SameRect(frame,before)
 local current=Rect(frame)
 for i=1,4 do if math.abs(current[i]-before[i])>.1 then return false end end
 return true
end
timer=C_Timer.NewTimer(.15,assert(probe:Callback(function()
 local f=Tip.interactive;local visible,known,unknown,nativeMatches=0,0,0,0
 local source
 for _,button in ipairs(f.memberButtons)do if button:IsShown() and button.member then
  local member=button.member;visible=visible+1
  local level=G.Public(member.itemLevel)
  local available=type(level)=="number" and level>0 and level<math.huge
  local text=button.realm:GetText()
  Check(text:find(A:GetLocale()=="zhCN" and "装等 " or "iLvl ",1,true)~=nil,"item_level_label_missing")
  Check(text:find(available and tostring(math.floor(level)) or "—",1,true)~=nil,"item_level_text_mismatch")
  Check(button.realm:GetStringHeight()<=button.realm:GetHeight()+1,"member_metadata_clipped")
  if available then known=known+1 else unknown=unknown+1 end
  local native=G.Public(member.isSelf and select(2,GetAverageItemLevel()) or C_PaperDollInfo.GetInspectItemLevel(member.unit))
  if type(native)=="number" and native>0 and native<math.huge then
   Check(available and math.abs(native-level)<.001,"native_item_level_mismatch");nativeMatches=nativeMatches+1
  end
  if not source and G.RaidGroups:CanStart(member.guid) then source=button end
 end end
 Check(visible==#members,"roster_members_missing")
 out.members={total=visible,known=known,unknown=unknown,nativeMatches=nativeMatches}
 if source then
  local guid=source.member.guid
  local before=Rect(f);local cards={}
  for _,button in ipairs(f.memberButtons)do if button:IsShown() and button.member then cards[#cards+1]={frame=button,rect=Rect(button)}end end
  local intents={empty=0,join=0,swap=0,unavailable=0}
  for subgroup=1,8 do
   local intent=G.RaidGroups:ResolveDrop(guid,subgroup)
   if intent then Check(intent.mode==(Tip.rosterGroupCounts[subgroup] and "join" or "empty"),"native_background_intent_mismatch");intents[intent.mode]=intents[intent.mode]+1
   else intents.unavailable=intents.unavailable+1 end
  end
  for _,member in ipairs(members)do if member.guid~=guid then
   local intent=G.RaidGroups:ResolveDrop(guid,member.subgroup,member.guid)
   if intent then Check(intent.mode=="swap","native_member_intent_mismatch");intents.swap=intents.swap+1 end
  end end
  out.intentModes=intents
  Tip:StartRosterDrag(source)
  Check(Tip.rosterDrag and Tip.rosterDrag.guid==guid and Tip.rosterDrag.button==source,"drag_source_changed")
  local targets=0;for _,drop in pairs(f.rosterDrops)do if drop:IsShown()then targets=targets+1 end end
  local sameRowPairs=0
  for subgroup,drop in pairs(f.rosterDrops)do if drop:IsShown()then
   for otherGroup,other in pairs(f.rosterDrops)do if otherGroup>subgroup and other:IsShown() and math.abs(drop:GetTop()-other:GetTop())<.1 then
    Check(math.abs(drop:GetBottom()-other:GetBottom())<.1,"short_group_blank_space_not_in_drop_region")
    sameRowPairs=sameRowPairs+1
   end end
  end end
  out.sameRowDropPairs=sameRowPairs
  if Tip.emptyRosterPanel and Tip.emptyRosterPanel:IsShown() then for _,button in pairs(Tip.emptyRosterPanel.buttons)do if button:IsShown()then targets=targets+1 end end end
  Check(targets==8,"empty_group_drop_targets_missing")
  Check(f:IsEventRegistered("PLAYER_REGEN_DISABLED") and f:IsEventRegistered("UNIT_FLAGS"),"drag_events_missing")
  Check(source:IsShown() and source.member.guid==guid,"drag_source_hidden_or_rebound")
  Check(SameRect(f,before),"pickup_moves_or_resizes_tooltip")
  for _,card in ipairs(cards)do Check(SameRect(card.frame,card.rect),"pickup_moves_member_card")end
  timer=C_Timer.NewTimer(.2,assert(probe:Callback(function()
   local ghost,drag=Tip.rosterDragGhost,assert(Tip.rosterDrag,"drag_cancelled_during_sample")
   Check(ghost:IsShown() and not ghost:IsMouseEnabled() and not ghost.card:IsMouseEnabled(),"ghost_missing_or_intercepts_mouse")
   Check(U.Motion.jobs[ghost]~=nil,"ghost_follow_task_missing")
   Check(SameRect(f,before),"pickup_animation_moves_tooltip")
   for _,card in ipairs(cards)do Check(SameRect(card.frame,card.rect),"pickup_animation_moves_member")end
   local expected=A:GetSetting("reduceMotion") and 1 or 1.035
   Check(math.abs(ghost:GetEffectiveScale()/drag.visualScale-expected)<.001,"pickup_scale_mismatch")
   out.drag={started=true,targets=targets,stableLayout=true,scale=ghost:GetEffectiveScale()/drag.visualScale,mutations=0}
   Tip:CancelRosterDrag();Tip:RenderCurrentRoster()
   Check(not Tip.rosterDrag and not f:IsEventRegistered("PLAYER_REGEN_DISABLED") and not f:IsEventRegistered("UNIT_FLAGS"),"drag_events_retained")
   Check(not ghost:IsShown() and U.Motion.jobs[ghost]==nil and (not Tip.emptyRosterPanel or not Tip.emptyRosterPanel:IsShown()),"drag_visuals_retained")
   out.drag.cancelled=true
   Notices(f)
  end)))
 else out.drag={started=false,reason="no_member_currently_permitted",mutations=0};Notices(f)end
end)))
