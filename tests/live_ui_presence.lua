-- Real window opacity/placement trace, plus a close during the brand animation.
local probe=...
local A=LycheeGroup
local U=A and A.UI
if not A or InCombatLockdown() or A.db.reduceMotion or U and (U:IsShown() or U.hiding or U.preview or U.activeModal) then
 return probe:Fail("requires_closed_ui_with_animation")
end
local warmedHere=not U or not U.frame
if warmedHere then A:Open("settings");U=A.UI;U:Hide(true) end
local originalPage=U.page
local oldFPS,oldBackground=GetCVar("maxFPS"),GetCVar("maxFPSBk")
local observer=CreateFrame("Frame")
local report={build=select(2,GetBuildInfo()),library=LycheeUI.versionString,requestedFPSLimit=60,warmedHere=warmedHere,gc="natural",opening={},closing={},quickClosing={}}
local stage,elapsed="baseline",0
local function Sample(dt)
 return {dtMs=dt*1000,phase=U.Motion.phase,alpha=U.frame:GetAlpha(),offsetY=select(5,U.frame:GetPoint())-(U.Motion.originY or 0),shown=U:IsShown()}
end
local function Logo()
 return {width=U.logo:GetWidth(),height=U.logo:GetHeight(),y=select(5,U.logo:GetPoint())}
end
assert(probe:Async(10))
assert(probe:OnCleanup(function()
 observer:SetScript("OnUpdate",nil);observer:Hide()
 if U:IsShown() then U:Hide(true) end
 SetCVar("maxFPS",oldFPS);SetCVar("maxFPSBk",oldBackground)
 if U.page~=originalPage then U.pages[U.page].frame:Hide() end
 U.page=originalPage;U.pages[originalPage].frame:Show();U:UpdateNav()
end))
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
SetCVar("maxFPS",60);SetCVar("maxFPSBk",60)
observer:SetScript("OnUpdate",assert(probe:Callback(function(_,dt)
 elapsed=elapsed+dt
 if stage=="baseline" and elapsed>=.3 then
  U:Show("settings");stage,elapsed="opening",0
 elseif stage=="opening" then
  if #report.opening<80 then report.opening[#report.opening+1]=Sample(dt) end
  if elapsed>=.6 then stage,elapsed="hold",0 end
 elseif stage=="hold" and elapsed>=1 then
  U:Hide();stage,elapsed="closing",0
 elseif stage=="closing" then
  if #report.closing<80 then report.closing[#report.closing+1]=Sample(dt) end
  if not U:IsShown() then
   report.normalClosedJobs=U.Motion:Count();stage,elapsed="rest",0
  end
 elseif stage=="rest" and elapsed>=.3 then
  U:Show("settings");stage,elapsed="quickOpening",0
 elseif stage=="quickOpening" and elapsed>=.21 then
  report.logoBeforeClose=Logo();U:Hide();report.logoAfterClose=Logo()
  stage,elapsed="quickClosing",0
 elseif stage=="quickClosing" then
  if #report.quickClosing<80 then report.quickClosing[#report.quickClosing+1]=Sample(dt) end
  if not U:IsShown() then
   report.logoAfterHidden=Logo();report.jobsAfter=U.Motion:Count()
   report.closedAfter=not U:IsShown() and not U.hiding
   stage,elapsed="reverseRest",0
  end
 elseif stage=="reverseRest" and elapsed>=.2 then
  U:Show("settings");stage,elapsed="reverseOpening",0
 elseif stage=="reverseOpening" and elapsed>=.5 then
  U:Hide();stage,elapsed="reverseClosing",0
 elseif stage=="reverseClosing" and elapsed>=.15 then
  report.beforeReverse=Sample(dt);report.logoBeforeReverse=Logo()
  U:Show("settings")
  report.afterReverse=Sample(dt);report.logoAfterReverse=Logo()
  stage,elapsed="reopened",0
 elseif stage=="reopened" and elapsed>=.5 then
  report.reopened=Sample(dt)
  if not U:IsShown() or U.hiding or U.Motion.phase~=1 then return probe:Fail("rapid_reopen_did_not_finish_open") end
  U:Hide();stage,elapsed="finalClose",0
 elseif stage=="finalClose" and not U:IsShown() then
  report.finalClosedJobs=U.Motion:Count()
  report.finalClosed=not U:IsShown() and not U.hiding
  probe:Finish(report)
 end
end)))
