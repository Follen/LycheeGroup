local probe=...
local A=LycheeGroup
local U=A and A.UI
if not A or U and (U:IsShown() or U.hiding or U.preview or U.activeModal) or InCombatLockdown() or A.db.reduceMotion then
 return probe:Fail("requires_warm_closed_ui_with_animation")
end
local warmedHere=not U or not U.frame
if warmedHere then A:Open("settings");U=A.UI;U:Hide(true) end
if not C_AddOnProfiler.IsEnabled() then return probe:Fail("profiler_disabled") end
local M=U.Motion
local oldPage=U.page
local oldFPS,oldBackground=GetCVar("maxFPS"),GetCVar("maxFPSBk")
local oldPresence,oldTick=M.SetPresence,M.Tick
local observer=CreateFrame("Frame")
local modes={"normalA","fixedAnchor","normalB"}
local stage,elapsed,pass,cycle="idle",0,1,0
local metric=Enum.AddOnProfilerMetric.LastTime
local report={library=LycheeUI.versionString,build=select(2,GetBuildInfo()),metric="LastTime",gc="natural",warmedHere=warmedHere,groups={},spikes={},calls={}}
local observerSum,observerMax,observerCount=0,0,0
local tickSum,tickMax,tickCount=0,0,0
local function Group()
 local name=stage=="idle" and "idle" or modes[pass].."_"..stage
 local group=report.groups[name]
 if not group then group={frames={},application={},allAddons={},lychee={},dev={}};report.groups[name]=group end
 return group
end
local function ProfileTick(self,...)
 local start=debugprofilestop();oldTick(self,...)
 local cost=debugprofilestop()-start
 tickSum,tickMax,tickCount=tickSum+cost,math.max(tickMax,cost),tickCount+1
end
local function FixedPresence(self,p)
 local scale=U.frame:GetEffectiveScale()
 self.lastX=self.originX or 0
 self.lastY=(self.originY or 0)+math.floor(-64*(1-p*(2-p))*scale+.5)/scale
 oldPresence(self,p)
end
local function SetMode()
 M.SetPresence=pass==2 and FixedPresence or oldPresence
 M.lastX,M.lastY=nil,nil
 oldPresence(M,1)
 M.phase=0
end
local function Action(kind)
 local start=debugprofilestop()
 if kind=="open" then U:Show("settings") else U:Hide() end
 report.calls[#report.calls+1]={mode=modes[pass],cycle=cycle,kind=kind,ms=debugprofilestop()-start}
end
assert(probe:Async(28))
assert(probe:OnCleanup(function()
 observer:SetScript("OnUpdate",nil);observer:Hide()
 M.SetPresence,M.Tick=oldPresence,oldTick
 if U:IsShown() then U:Hide(true) end
 SetCVar("maxFPS",oldFPS);SetCVar("maxFPSBk",oldBackground)
 if U.page~=oldPage then U.pages[U.page].frame:Hide() end
 U.page=oldPage;U.pages[oldPage].frame:Show();U:UpdateNav()
end))
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
SetCVar("maxFPS",120);SetCVar("maxFPSBk",120)
M.Tick=ProfileTick
observer:SetScript("OnUpdate",assert(probe:Callback(function(_,dt)
 local observedAt=debugprofilestop()
 local group=Group()
 local app=C_AddOnProfiler.GetApplicationMetric(metric)
 local all=C_AddOnProfiler.GetOverallMetric(metric)
 local lychee=C_AddOnProfiler.GetAddOnMetric("LycheeGroup",metric)+C_AddOnProfiler.GetAddOnMetric("LycheeGroup_UI",metric)
 local dev=C_AddOnProfiler.GetAddOnMetric("Lychee Dev",metric)
 if #group.frames<400 then
  local n=#group.frames+1
  group.frames[n],group.application[n],group.allAddons[n],group.lychee[n],group.dev[n]=dt*1000,app,all,lychee,dev
 end
 if dt>.030 and #report.spikes<24 then
  report.spikes[#report.spikes+1]={mode=modes[pass],stage=stage,cycle=cycle,dtMs=dt*1000,appMs=app,allAddonMs=all,lycheeMs=lychee,devMs=dev,top=C_AddOnProfiler.GetTopKAddOnsForMetric(metric,5)}
 end
 local observationCost=debugprofilestop()-observedAt
 observerSum,observerMax,observerCount=observerSum+observationCost,math.max(observerMax,observationCost),observerCount+1
 elapsed=elapsed+dt
 if stage=="idle" and elapsed>=2 then cycle=1;SetMode();Action("open");stage,elapsed="opening",0
 elseif stage=="opening" and elapsed>=.55 then Action("close");stage,elapsed="closing",0
 elseif stage=="closing" and elapsed>=.55 then stage,elapsed="rest",0
 elseif stage=="rest" and elapsed>=.35 then
  if cycle<4 then cycle=cycle+1;SetMode();Action("open");stage,elapsed="opening",0
  elseif pass<3 then pass,cycle=pass+1,1;SetMode();Action("open");stage,elapsed="opening",0
  else
   report.tick={sumMs=tickSum,maxMs=tickMax,count=tickCount}
   report.observer={sumMs=observerSum,maxMs=observerMax,count=observerCount}
   report.closed=not U:IsShown() and not U.hiding;report.jobs=M:Count()
   for _,g in pairs(report.groups) do
    for key,values in pairs(g) do
     table.sort(values);local count=#values;local sum=0;for _,v in ipairs(values) do sum=sum+v end
     g[key]={count=count,mean=sum/count,p50=values[math.ceil(count*.5)],p95=values[math.ceil(count*.95)],max=values[count]}
    end
   end
   probe:Finish(report)
  end
 end
end)))
