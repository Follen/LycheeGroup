-- Render the current real Floating data through its public popup API.
-- No applications, invitations, listing changes or fixture records are submitted.
local probe=...
local A=assert(LycheeGroup);local F=assert(A.Floating);local API=A.API.Floating
assert(not InCombatLockdown(),"combat")
assert(not F.standaloneTest,"standalone_test_in_use")
assert(A.StyleDefaults.floating.floatingRowLeaderWidth==221,"updated_theme_not_loaded")
assert(A.StyleDefaults.floating.floatingIconFilter=="TRILINEAR","smooth_texture_filter_not_loaded")
local previous={shown=F.panel and F.panel:IsShown(),owner=F.popupOwner,anchor=F.popupAnchor}
local anchor=CreateFrame("Frame",nil,UIParent);anchor:SetSize(80,1);anchor:SetPoint("TOPLEFT",UIParent,"TOPLEFT",40,-120);anchor:EnableMouse(false)
local screenshotEvents=CreateFrame("Frame")
local timer,cleaned
local report={scope="current real application/listing data, native Frame geometry and generated textures; public popup controller only",checks=0}
local function Check(value,label)report.checks=report.checks+1;assert(value,label)end
local function Clean()
 if cleaned then return end;cleaned=true
 if timer then timer:Cancel()end
 screenshotEvents:UnregisterAllEvents();screenshotEvents:SetScript("OnEvent",nil)
 API:HidePopup(anchor,true);anchor:Hide();anchor:SetParent(nil)
 if previous.shown then
  if previous.owner and previous.anchor and previous.anchor:IsVisible()then API:ShowPopup(previous.owner,previous.anchor)else F:ShowPanel()end
 end
end
assert(probe:OnCleanup(Clean));assert(probe:Async(8))
assert(probe:Guard(function()return not InCombatLockdown()end,{"PLAYER_REGEN_DISABLED","PLAYER_LEAVING_WORLD"},"scene_changed"))
assert(probe:ProtectInput(4))
assert(API:ShowPopup(anchor,anchor),"popup_unavailable")
timer=C_Timer.NewTimer(.6,assert(probe:Callback(function()
 Check(F.panel:IsVisible(),"popup_not_visible")
 Check(F.headingDot:GetObjectType()=="Texture","status_dot_is_not_a_texture")
 Check(F.panel:GetScript("OnUpdate")==nil,"completed_animation_driver_retained")
 report.heading=F.heading:GetText();report.status=F.statusText;report.recruiting=F.recruiting==true
 report.empty=F.emptyCard:IsShown() and F.empty:GetText() or nil;report.entries=#F.entries
 report.panel={left=F.panel:GetLeft(),bottom=F.panel:GetBottom(),width=F.panel:GetWidth(),height=F.panel:GetHeight(),scale=F.panel:GetEffectiveScale()}
 report.screen={width=UIParent:GetWidth()*UIParent:GetEffectiveScale(),height=UIParent:GetHeight()*UIParent:GetEffectiveScale()}
 report.icons={dot=F.headingDot:GetTexture(),waiting=F.waitIcon:GetTexture(),dotSize=F.headingDot:GetWidth(),waitingSize=F.waitIcon:GetWidth()}
 if F.heading:IsShown()then
  local _,cy=F.headingDot:GetCenter()
  local expected=F.heading:GetTop()-F.context:GetLineHeight(F.context.Theme.floatingHeaderLine)/2+F.context.Theme.floatingHeaderDotOffsetY
  Check(math.abs(cy-expected)<.5,"status_dot_not_centered_on_first_heading_line")
 end
 report.rows={}
 for _,row in ipairs(F.rows)do if row:IsShown() and #report.rows<8 then
  local data={kind=row.kind,name=row.name:GetText(),height=row:GetHeight()}
  if row.kind=="application"then
   local _,activityFont=row.name:GetFont();local _,titleFont=row.meta:GetFont()
   Check(activityFont>titleFont,"activity_heading_not_larger_than_title")
   Check(row.timer:GetUnboundedStringWidth()<=row.timer:GetWidth()+1,"timer_clipped")
   local gap=row.timer:GetLeft()-row.leader:GetRight()
   Check(gap>=12,"leader_overlaps_timer")
   data.title=row.meta:GetText();data.timer=row.timer:GetText();data.leaderTimerGap=gap;data.activityFont=activityFont;data.titleFont=titleFont
  elseif row.kind=="member"then
   Check(row.itemLevel:GetUnboundedStringWidth()<=row.itemLevel:GetWidth()+1,"item_level_clipped")
   if row.score:IsShown()then Check(row.score:GetUnboundedStringWidth()<=row.score:GetWidth()+1,"score_clipped")end
   data.score=row.score:IsShown() and row.score:GetText() or nil;data.itemLevel=row.itemLevel:GetText();data.meta=row.meta:GetText()
  end
  report.rows[#report.rows+1]=data
 end end
 screenshotEvents:RegisterEvent("SCREENSHOT_SUCCEEDED")
 screenshotEvents:SetScript("OnEvent",assert(probe:Callback(function()
  report.screenshotCompleted=true
  Clean();probe:ReleaseInput()
  if not previous.shown then
   Check(not F.panel:IsShown(),"popup_not_restored_hidden")
   Check(F.countdown==nil and F.panel:GetScript("OnUpdate")==nil,"popup_work_retained")
  end
  report.resourcesReleased=true;report.currentSessionErrors={}
  if BugGrabber then
   local session=BugGrabber:GetSessionId()
   for _,entry in ipairs(BugGrabber:GetDB())do
    if entry.session==session and tostring(entry.message):find("LycheeGroup",1,true) and #report.currentSessionErrors<8 then report.currentSessionErrors[#report.currentSessionErrors+1]={message=entry.message,counter=entry.counter}end
   end
  end
  Check(#report.currentSessionErrors==0,"current_session_product_error")
  probe:Finish(report)
 end)))
 timer=C_Timer.NewTimer(3,assert(probe:Callback(function()probe:Fail("screenshot_not_confirmed")end)))
 report.screenshotTime=date("%m%d%y_%H%M%S");Screenshot()
end)))
