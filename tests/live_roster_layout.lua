-- Synthetic records on native Frames only; execute budget: 20 seconds.
-- This explicitly invokes visual controllers, not hardware input or a permitted
-- raid drag. No Blizzard API, roster provider, or subgroup action is replaced.
local probe=...
local A=assert(LycheeGroup)
local U=assert(A.UI and A.UI.frame and A.UI,"requires_built_ui")
local G,Tip=assert(A.Group),assert(U.Tooltip)
assert(not InCombatLockdown() and not IsInRaid(),"requires_noncombat_nonraid")
assert(not U.preview and not U.hiding and not U.activeModal,"preview_modal_or_hiding")
assert(not Tip.rosterDrag and not (U.drag and U.drag.handle) and not U.resizing,"active_drag")
assert(not U.context:GetMenuAnchor(),"existing_menu")
for _,page in pairs(U.pages)do
 for _,key in ipairs({"resultsHeader","applicationHeader","applicantTable"})do assert(not (page[key] and page[key].drag),"active_table_drag")end
end
assert(not Tip.owner or Tip.sourceRoster and not Tip.member,"existing_non_roster_tooltip")
assert(not Tip.rosterNoticeTimer,"existing_roster_notice")
local original={shown=U:IsShown(),page=U.page}
local savedTip=Tip.owner and Tip:Capture()
local buttonState={}
if Tip.interactive then for _,button in ipairs(Tip.interactive.memberButtons)do
 buttonState[button]={suppress=button.suppressRosterClick,grab=button.rosterGrab}
end end
local generation=G.Search.generation
local timer,cleaned
local out={scope="synthetic records/native Frames/nohardware/nosubgroupactions",source="11 local sample members: groups 4/5/6 contain 5/5/1; no native roster or permission success claimed",checks=0,groups={}}
local function Check(value,message)out.checks=out.checks+1;assert(value,message)end
local function Close(a,b)return type(a)=="number" and type(b)=="number" and math.abs(a-b)<.15 end
local function Rect(frame)return {frame:GetLeft(),frame:GetTop(),frame:GetWidth(),frame:GetHeight()}end
local function SameRect(frame,before)
 local current=Rect(frame)
 for i=1,4 do if not Close(current[i],before[i])then return false end end
 return true
end
local function Clean()
 if cleaned then return end
 if timer then timer:Cancel();timer=nil end
 Tip:CancelRosterDrag();Tip:Hide()
 if savedTip then Tip:Restore(savedTip)end
 if Tip.interactive then for _,button in ipairs(Tip.interactive.memberButtons)do
  local saved=buttonState[button];button.suppressRosterClick=saved and saved.suppress or nil;button.rosterGrab=saved and saved.grab or nil
 end end
 cleaned=true
end
assert(probe:OnCleanup(Clean))
assert(probe:Async(15))
assert(probe:Guard(function()
 return not InCombatLockdown() and not IsInRaid() and not U.preview and not U.activeModal
end,{"PLAYER_REGEN_DISABLED","GROUP_ROSTER_UPDATE"},"layout_scene_changed"))
local members={}
for subgroup=4,6 do for i=1,(subgroup==6 and 1 or 5)do
 local guid="LycheeGroup-LayoutSample-G"..subgroup.."M"..i
 members[#members+1]={guid=guid,name="LayoutSample"..subgroup..i.."-SampleRealm",nameKey="LayoutSample"..subgroup..i.."-SampleRealm",subgroup=subgroup,class="MAGE",assignedRole="DAMAGER",isLeader=subgroup==4 and i==1}
end end
local raidGroups=G.RaidGroups
Check(raidGroups and Tip.StartRosterDragVisual and Tip.PrepareRosterDropTargets,"layout_runtime_missing")
local intent,reason=raidGroups:ResolveDrop(members[1].guid,6)
Check(intent==nil and reason=="notRaid","native_service_must_reject_sample")
-- U.frame deliberately avoids the real Create groupSummary refresh owner.
Tip:ShowRoster(U.frame,members,true,{rosterMode="groups"})
U:SetText(Tip.interactive.title,A:GetLocale()=="zhCN" and "布局样例 · 非实时成员" or "Layout sample · synthetic members")
timer=C_Timer.NewTimer(.15,assert(probe:Callback(function()
 local f=Tip.interactive;local cards,byGroup={},{}
 for _,button in ipairs(f.memberButtons)do if button:IsShown() and button.member then
  cards[#cards+1]={frame=button,rect=Rect(button)}
  local subgroup=button.member.subgroup;byGroup[subgroup]=byGroup[subgroup] or {};byGroup[subgroup][#byGroup[subgroup]+1]=button
 end end
 Check(#cards==11,"sample_cards_missing")
 local before=Rect(f)
 Tip:PrepareRosterDropTargets()
 local previous
 for subgroup=4,6 do
  local drop,title=f.rosterDrops[subgroup],f.rosterGroupTitles[subgroup]
  local group=byGroup[subgroup];local first,last=group[1],group[#group]
  Check(drop:IsShown() and title:IsShown(),"group_frame_missing_"..subgroup)
  Check(Close(title:GetLeft()-drop:GetLeft(),12),"title_left_padding_"..subgroup)
  Check(Close(drop:GetRight()-title:GetRight(),12),"title_right_padding_"..subgroup)
  Check(Close(drop:GetTop()-title:GetTop(),12),"title_top_padding_"..subgroup)
  Check(Close(title:GetTop()-title:GetLineHeight()-first:GetTop(),12),"title_member_gap_"..subgroup)
  Check(last:GetBottom()-drop:GetBottom()>=11.85,"bottom_padding_"..subgroup)
  if subgroup<6 then Check(Close(last:GetBottom()-drop:GetBottom(),12),"full_group_bottom_padding_"..subgroup)end
  Check(Close(drop:GetTop(),f.rosterDrops[4]:GetTop()) and Close(drop:GetHeight(),f.rosterDrops[4]:GetHeight()),"same_row_background_height_"..subgroup)
  if previous then Check(Close(drop:GetLeft()-previous:GetRight(),12),"column_gap_"..subgroup)end
  previous=drop
  out.groups[#out.groups+1]={subgroup=subgroup,members=#group,height=drop:GetHeight(),blankArea=last:GetBottom()-drop:GetBottom()}
 end
 Check(out.groups[3].blankArea>12,"short_group_blank_area_missing")
 Check(SameRect(f,before),"drop_targets_move_tooltip")
 for _,card in ipairs(cards)do Check(SameRect(card.frame,card.rect),"drop_targets_move_card")end
 local source=byGroup[4][1]
 -- Provide the visual-only grab explicitly. CaptureRosterGrab correctly refuses
 -- a real drag outside a raid; no context or permission guard is overridden.
 source.rosterGrab={guid=source.member.guid,width=source:GetWidth(),height=source:GetHeight(),scale=source:GetEffectiveScale(),x=source:GetWidth()/2,y=source:GetHeight()/2}
 local drag={guid=source.member.guid,button=source,alpha=source:GetAlpha(),wasPinned=Tip.pinned}
 Tip.rosterDrag=drag;Tip:StartRosterDragVisual(source,drag)
 timer=C_Timer.NewTimer(.2,assert(probe:Callback(function()
  local ghost=Tip.rosterDragGhost
  Check(Tip.rosterDrag==drag and ghost:IsShown(),"visual_drag_missing")
  Check(not ghost:IsMouseEnabled() and not ghost.card:IsMouseEnabled(),"ghost_intercepts_mouse")
  Check(U.Motion.jobs[ghost]~=nil,"native_motion_job_missing")
  local scale=ghost:GetEffectiveScale()/drag.visualScale
  Check(math.abs(scale-(A:GetSetting("reduceMotion") and 1 or 1.035))<.001,"native_pickup_scale_mismatch")
  Check(SameRect(f,before),"visual_drag_moves_tooltip")
  for _,card in ipairs(cards)do Check(SameRect(card.frame,card.rect),"visual_drag_moves_card")end
  out.visual={scale=scale,reduceMotion=A:GetSetting("reduceMotion"),nativeMotion=true,mouseOff=true,stableLayout=true,permissionSucceeded=false}
  Tip:CancelRosterDrag()
  Check(not Tip.rosterDrag and not ghost:IsShown() and U.Motion.jobs[ghost]==nil,"visual_drag_cleanup_failed")
  Check(not f:IsEventRegistered("PLAYER_REGEN_DISABLED") and not f:IsEventRegistered("UNIT_FLAGS"),"drag_events_retained")
  Check(not Tip.emptyRosterPanel or not Tip.emptyRosterPanel:IsShown(),"empty_panel_retained")
  for _,drop in pairs(f.rosterDrops)do Check(not drop:IsShown(),"drop_frame_retained")end
  Check(SameRect(f,before),"cancel_moves_tooltip")
  for _,card in ipairs(cards)do Check(SameRect(card.frame,card.rect),"cancel_moves_card")end
  Clean()
  Check(G.RaidGroups==raidGroups and G.Search.generation==generation,"business_service_or_search_changed")
  Check(U.page==original.page and U:IsShown()==original.shown,"page_restore_failed")
  Check(not Tip.rosterDrag and not Tip.rosterNoticeTimer and U.Motion.jobs[ghost]==nil,"background_task_retained")
  Check(savedTip and Tip.sourceRoster~=nil or not savedTip and not f:IsShown(),"tooltip_restore_failed")
  out.resourcesReleased=true;out.previousRosterTooltipRestored=savedTip~=nil
  probe:Finish(out)
 end)))
end)))
