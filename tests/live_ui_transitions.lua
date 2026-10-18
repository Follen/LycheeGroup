-- Bounded transition timing, driven through the real host controllers.
-- Run only with a warmed, closed UI, default animations and no combat/modal.
local probe=...
local A=LycheeGroup
local U=A and A.UI
if not U or not U.frame or U:IsShown() or U.hiding or U.preview or U.activeModal or InCombatLockdown() or A.db.reduceMotion then
 return probe:Fail("requires_warmed_closed_ui_with_animation")
end
local originalPage=U.page
local oldFPS,oldBackground=GetCVar("maxFPS"),GetCVar("maxFPSBk")
local observer=CreateFrame("Frame")
local report={build=select(2,GetBuildInfo()),profile=GetCVar("scriptProfile"),originalFPS=oldFPS,originalBackgroundFPS=oldBackground,limit=120,cycles={},baseline={frames={}},gc="natural",scope="Real Find and Settings controllers; frame intervals include the rest of the client"}
local pages={"find","settings","find","settings","find","settings"}
local stage,elapsed,index="baseline",0,0
local current
local function Summarize(bucket)
 local frames=bucket.frames
 table.sort(frames)
 bucket.count=#frames
 bucket.median=frames[math.max(1,math.ceil(#frames*.5))]
 bucket.p95=frames[math.max(1,math.ceil(#frames*.95))]
 bucket.max=frames[#frames]
 bucket.frames=nil
end
local function OpenNext()
 index=index+1
 if not pages[index] then
  Summarize(report.baseline)
  for _,cycle in ipairs(report.cycles) do
   Summarize(cycle.opening);Summarize(cycle.hold);Summarize(cycle.closing);Summarize(cycle.rest)
  end
  report.jobsAfter=U.Motion:Count()
  report.closedAfter=not U:IsShown() and not U.hiding
  probe:Finish(report)
  return
 end
 current={page=pages[index],opening={frames={}},hold={frames={}},closing={frames={}},rest={frames={}}}
 report.cycles[index]=current
 local start=debugprofilestop()
 U:Show(current.page)
 current.openSyncMs=debugprofilestop()-start
 current.resultsAtOpen=A.Group and A.Group:GetResultCount()
 stage,elapsed="opening",0
end
assert(probe:Async(18))
assert(probe:OnCleanup(function()
 observer:SetScript("OnUpdate",nil);observer:Hide()
 if U:IsShown() then U:Hide(true) end
 SetCVar("maxFPS",oldFPS);SetCVar("maxFPSBk",oldBackground)
 if U.page~=originalPage then U.pages[U.page].frame:Hide() end
 U.page=originalPage
 U.pages[originalPage].frame:Show();U:UpdateNav()
end))
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
SetCVar("maxFPS",120);SetCVar("maxFPSBk",120)
observer:SetScript("OnUpdate",assert(probe:Callback(function(_,dt)
 local bucket=stage=="baseline" and report.baseline or current[stage]
 if #bucket.frames<500 then bucket.frames[#bucket.frames+1]=dt*1000 end
 elapsed=elapsed+dt
 if stage=="baseline" and elapsed>=.7 then OpenNext()
 elseif stage=="opening" and elapsed>=.55 then stage,elapsed="hold",0
 elseif stage=="hold" and elapsed>=.35 then
  local start=debugprofilestop();U:Hide();current.closeSyncMs=debugprofilestop()-start
  stage,elapsed="closing",0
 elseif stage=="closing" and elapsed>=.55 then
  current.closed=not U:IsShown() and not U.hiding
  stage,elapsed="rest",0
 elseif stage=="rest" and elapsed>=.25 then OpenNext() end
end)))
