-- Exercise the saved settings route through real Host and animation controllers.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
local function Copy(value)
 if type(value)~="table" then return value end
 local result={};for key,item in pairs(value) do result[key]=Copy(item) end;return result
end
local function Same(a,b)
 if type(a)~="table" or type(b)~="table" then return a==b end
 for key,value in pairs(a) do if not Same(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end
 return true
end
for _,script in ipairs({"live_ui_presence","live_ui_motion_profile","live_ui_transitions","live_memory"}) do
 local modes={"complete","complete_notes","cancel","callback_error"}
 if script=="live_ui_presence" or script=="live_ui_motion_profile" then modes[#modes+1]="cold_open_failure";modes[#modes+1]="cold_complete" end
 for _,mode in ipairs(modes) do
  local f=dofile("tests/live_probe_fixture.lua")()
  local A,U,G=f.A,f.U,f.G
  G.Roster={};G.Applicants={GetCount=function() return 0 end}
  function G.Game.frame:IsEventRegistered(event) return self.events[event]==true end
  local cvars={maxFPS="90",maxFPSBk="30",scriptProfile="0"}
  GetCVar=function(key) return cvars[key] end
  SetCVar=function(key,value) cvars[key]=tostring(value) end
  Enum.AddOnProfilerMetric={LastTime=1}
  C_AddOnProfiler={IsEnabled=function() return true end,GetApplicationMetric=function() return 0 end,
   GetOverallMetric=function() return 0 end,GetAddOnMetric=function() return 0 end,GetTopKAddOnsForMetric=function() return {} end}
  local oldFind={category="seasonRaid",filters={sort="oldest",maxMembers=12},categoryPrefs={}}
  G.prefs.find=oldFind
  if not mode:match("^cold_") then A:Open("find");A:Open("create");A:Open("settings");U:Hide(true) end
  if mode=="complete_notes" then A:Open("notes");U:Hide(true) end
  G.Search:SetFilters({sort="rating",maxMembers=4})
  local oldFindValue=Copy(oldFind)
  local originalPage,originalReturn=U.page,U.settingsReturnPage
  local tick,presence=U.Motion.Tick,U.Motion.SetPresence
  local open=A.Open
  if mode=="cold_open_failure" then
   A.Open=function(self,page,...)
    local result=open(self,page,...)
    if page=="settings" then error("simulated open failure") end
    return result
   end
  end
  local p=f:Start("tests/"..script..".lua")
  A.Open=open
  for index=1,2300 do
   if f.now>=3 then
    if mode=="cancel" then p:Close() end
    if mode=="callback_error" then f.callbackError=true end
   end
   f:Advance(.05)
   local count=#f.S.nodes
   for i=1,count do
    local node=f.S.nodes[i]
    local callback=node:GetScript("OnUpdate")
    if callback and node~=U.Motion.driver and node:IsVisible() then callback(node,.05) end
   end
   if not p.active then break end
  end
  local label=script.." "..mode
  Check(not p.active,label.." bounded completion")
  if mode=="complete" or mode=="complete_notes" or mode=="cold_complete" then Check(p.result~=nil,tostring(p.error))
  elseif mode=="callback_error" then Check(p.error and p.error:find("simulated callback failure",1,true),tostring(p.error))
  elseif mode=="cold_open_failure" then Check(p.error and p.error:find("simulated open failure",1,true),tostring(p.error))
  else Check(p.result==nil,label.." cancelled without success") end
  Check(not U:IsShown() and U.page==originalPage and U.settingsReturnPage==originalReturn,label.." actual hidden route restored")
  Check(not U.Native.searchLease and not G:HasViews() and U.Motion:Count()==0,label.." UI owners released")
  Check(G.prefs.find==oldFind and Same(oldFind,oldFindValue),label.." original role filters preserved")
  local filters=G.Search:GetFilters()
  Check(filters.sort=="rating" and filters.maxMembers==4 and filters.category==nil,label.." runtime filters restored")
  Check(U.Motion.Tick==tick and U.Motion.SetPresence==presence and cvars.maxFPS=="90" and cvars.maxFPSBk=="30",label.." wrappers and frame settings restored")
  Check(U._nav==(originalPage or "find") and U.settingsButton.active==(originalPage=="settings"),label.." navigation presentation restored")
  local reads=f.reads
  for i=1,10 do f:Advance(.1) end
  Check(f.reads==reads,label.." late callbacks remain inactive")
  if originalPage then
   assert(A:Open(originalPage))
   for key,page in pairs(U.pages) do if page.frame then Check(page.frame:IsVisible()==(key==originalPage),label.." reopen shows only original page: "..key) end end
   U.settingsButton:Fire("OnClick","LeftButton");Check(U.page==(originalPage=="settings" and originalReturn or "settings"),label.." actual settings button returns to original source");U:Hide(true)
  end
 end
end
for _,mode in ipairs({"complete","open_error","old_revision","combat"}) do
 local f=dofile("tests/live_probe_fixture.lua")()
 local library=LycheeUI;local create=library.CreateContext
 local ctx,parent
 library.CreateContext=function(self,options)
  parent=options.parent;ctx=create(self,options)
  if mode=="open_error" then
   local open=ctx.OpenMenu
   ctx.OpenMenu=function(self,...) open(self,...);error("simulated menu open failure") end
  end
  return ctx
 end
 if mode=="old_revision" then library.version=37 end
 if mode=="combat" then InCombatLockdown=function() return true end end
 local before=#f.S.nodes
 local probe={cleanup={}}
 function probe:OnCleanup(fn) self.cleanup[#self.cleanup+1]=fn;return true end
 function probe:Fail(reason) self.error=reason end
 function probe:Log(message) self.lastLog=message end
 local ok,result=pcall(assert(loadfile("tests/live_menu_geometry.lua")),probe)
 library.CreateContext=create
 for index=#probe.cleanup,1,-1 do probe.cleanup[index]() end
 if mode=="complete" then
  Check(ok and result and result.closed,"native menu probe completes against the real shared controllers")
  Check(result.mixed.contentHeight==200 and result.mixed.zeroCollapsed and result.long.lastReachable,"menu probe checks mixed and distant row geometry")
  Check(result.states.checkedCollapsed and result.states.disabledCollapsed and result.states.restoredHeight==120,"menu probe checks stable states and reopen restoration")
 elseif mode=="open_error" then
  Check(not ok and result:find("simulated menu open failure",1,true),"menu failure remains a failed result")
 else Check(ok and probe.error=="requires_r38_out_of_combat" and #f.S.nodes==before,"menu prerequisites fail before creating native objects") end
 if ctx then
  local menu=ctx:GetMenu()
  Check(not parent:IsShown() and not menu:IsShown() and not menu.catcher:IsShown() and not ctx:GetMenuAnchor(),mode.." menu ownership and frames released")
  Check(ctx.Motion:Count()==0,mode.." menu motion released")
 end
end
print("UI probe lifecycle and routing: "..checks.." checks passed")
