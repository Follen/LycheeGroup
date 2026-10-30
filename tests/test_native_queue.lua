-- Exercise the real entrypoint with the stock eye's branch contract from
-- wow-ui-source 15881d5, QueueStatusFrame.lua:283-318. No game actions are sent.
TestStubs.Install({locale="zhCN"})
for _,late in ipairs({false,true}) do
 local listing,apps,battlefield,lfdBattlefield=false,{},false,false
 local opened,menus,scoreboards,nativeOpens,restored=0,0,0,0,0
 local lastPage,lastContext,failOpen,queueMode
 local conceal=false
 local frames={}
 local writes=0
 local env=setmetatable({}, {__index=_G});env._G=env
 env.CreateFrame=function(...)
  local frame=CreateFrame(...);frames[#frames+1]=frame
  local show,hide=frame.Show,frame.Hide
  function frame:Show() writes=writes+1;show(self) end
  function frame:Hide() writes=writes+1;hide(self) end
  return frame
 end
 env.C_LFGList={
  HasActiveEntryInfo=function() return listing end,
  GetApplications=function() local ids={};for i=1,#apps do ids[i]=i end;return ids end,
  GetApplicationInfo=function(id) return id,apps[id][1],apps[id][2] end,
 }
 env.QueueStatusButton=false
 env.QueueStatus_InActiveBattlefield=function() return battlefield end
 env.IsInLFDBattlefield=function() return lfdBattlefield end
 env.GetLFGMode=function() return queueMode end
 env.NUM_LE_LFG_CATEGORYS=8
 env.PVEFrame=env.CreateFrame("Frame");env.PVEFrame:Hide()
 env.HideUIPanel=function(frame) T.eq(frame,env.PVEFrame);frame:Hide() end
 env.ShowUIPanel=function(frame) restored=restored+1;frame:Show() end
 env.LinkUtil={RegisterLinkHandler=function() end};env.SlashCmdList={}
 env.Menu=false
 local a={db={},L={},Minimap={Initialize=function() end}}
 env.LycheeGroup=a
 function a:LoadDB() end
 function a:GetSetting(key) return key=="nativeLFGEntry" and conceal end
 function a:Open(page,context)
  opened=opened+1;lastPage,lastContext=page,context
  T.eq(env.PVEFrame:IsShown(),false,"stock panel releases its inputs before Lychee opens")
  return not failOpen
 end
 env.LFGListUtil_OpenBestWindow=function(toggle)
  nativeOpens=nativeOpens+1;env.PVEFrame:Show();return "native",toggle
 end
 -- Original native branch contract. Its premade branch would also trigger
 -- other addons' hooks, so Lychee's left click must not enter that branch.
 local function NativeClick(_,button)
  if button=="RightButton" then menus=menus+1
  elseif battlefield or lfdBattlefield then scoreboards=scoreboards+1
  elseif listing then env.LFGListUtil_OpenBestWindow(true)
  else
   for i=1,#apps do
    if apps[i][1]=="applied" or apps[i][1]=="invited" then env.LFGListUtil_OpenBestWindow(true);return end
   end
   menus=menus+1
  end
  return "native",button
 end
 local function LoadNative()
  env.QueueStatusFrame=env.CreateFrame("Frame")
  function env.QueueStatusFrame:Update() end
  env.QueueStatusButton=env.CreateFrame("Button")
  local eye=env.QueueStatusButton
  eye.alpha=1;eye.mouse=true
  function eye:GetAlpha() return self.alpha end
  function eye:SetAlpha(alpha) writes=writes+1;self.alpha=alpha end
  function eye:IsMouseEnabled() return self.mouse end
  function eye:EnableMouse(enabled) writes=writes+1;self.mouse=enabled end
  function eye:HookScript(name,callback)
   local original=self:GetScript(name)
   self:SetScript(name,function(...) if original then original(...) end;callback(...) end)
  end
  eye:SetScript("OnClick",NativeClick)
 end
 if not late then LoadNative() end
 local chunk=assert(loadfile("addon/LycheeGroup/Entrypoints.lua"));setfenv(chunk,env);chunk()
 local events=frames[#frames]
 local function Event(event,name) events:GetScript("OnEvent")(events,event,name) end
 Event("ADDON_LOADED","LycheeGroup");Event("PLAYER_LOGIN")
 T.eq(opened,0,"binding an already-loaded or late native addon does not open UI")
 if late then
  T.ok(events.events.ADDON_LOADED,"late queue button is awaited even when the hide option is off")
  Event("ADDON_LOADED","Unrelated");T.eq(opened,0)
  LoadNative();Event("ADDON_LOADED","Blizzard_QueueStatusFrame")
 end
 T.eq(events.events.ADDON_LOADED,nil,"the load listener ends after binding")
 local eye=env.QueueStatusButton
 T.eq(eye:GetScript("OnClick"),NativeClick,"PvP menu construction must remain on the untouched native click script")
 local routed=eye:GetScript("OnClick")
 a:SyncNativeLFGEntry();a:SyncNativeLFGEntry()
 T.eq(eye:GetScript("OnClick"),routed,"sync preserves the original click script")
 local function LeftButton()
  for _,frame in ipairs(frames) do if rawget(frame,"parent")==eye and frame.kind=="Button" then return frame end end
 end
 local function Click(button)
  button=button or "LeftButton"
  env.QueueStatusFrame:Update()
  local left=LeftButton()
  if left and left:IsShown() then
   local pass=false
   for _,key in ipairs(left.passThroughButtons) do if key==button then pass=true end end
   if not pass then return left:GetScript("OnClick")(left,button) end
  end
  return eye:GetScript("OnClick")(eye,button)
 end
 for _,mode in ipairs({"queued","rolecheck","proposal","lfgparty"}) do
  local previousMenus=menus
  queueMode=mode;local first,second=Click()
  T.eq(opened,0);T.eq(menus,previousMenus+1,"matchmaking alone keeps its native left-click menu: "..mode)
  T.eq(first,"native");T.eq(second,"LeftButton","native left-click results are preserved")
 end
 apps={{"cancelled"},{"declined_full"},{"inviteaccepted"},{"none","applied"}}
 local previousMenus=menus
 Click();T.eq(opened,0,"finished and merely pending applications do not open Lychee");T.eq(menus,previousMenus+1)
 Click("RightButton");T.eq(menus,previousMenus+2,"queue actions stay available on right click")
 env.LFGListUtil_OpenBestWindow(false)
 T.eq(opened,0,"other callers of the native utility are unchanged")
 T.eq(env.PVEFrame:IsShown(),true)
 apps={{"cancelled"},{"applied"}};Click()
 T.eq(opened,1);T.eq(lastPage,"find");T.eq(lastContext.applicationID,2,"application plus matchmaking opens and locates the application")
 T.eq(env.PVEFrame:IsShown(),false)
 Click();T.eq(opened,2,"repeated clicks keep the requested page open")
 apps={{"invited"}};Click();T.eq(lastPage,"find");T.eq(lastContext.applicationID,1)
 listing=true;Click();T.eq(lastPage,"create");T.eq(lastContext,nil,"a listing takes precedence over applications")
 local left=LeftButton()
 T.ok(left and left:IsShown(),"premade business enables a separate left-click target")
 T.eq(left.mouseMotionEnabled,false,"the overlay lets native hover reach the stock button")
 T.eq(eye:GetScript("OnClick"),NativeClick,"premade routing never wraps the original native script")
 local count=opened;Click("RightButton");T.eq(opened,count,"right click remains the original menu")
 listing=false;apps={};battlefield=true;Click();T.eq(opened,count,"an active battlefield without premade business still opens its scoreboard")
 battlefield=false;lfdBattlefield=true;Click();T.eq(opened,count);T.eq(scoreboards,2)
 lfdBattlefield=false;listing=true
 local stopped=0;a.UI={preview={},StopPreview=function(self,close) stopped=stopped+1;T.eq(close,false);self.preview=nil end}
 Click();T.eq(stopped,1,"a real queue entry exits an explicit sample preview");T.eq(lastPage,"create")
 failOpen=true;env.PVEFrame:Show();Click();T.eq(restored,1);T.eq(env.PVEFrame:IsShown(),true,"failed Lychee loading restores the previously visible native panel")
 failOpen=false
 local first,second=eye:GetScript("OnClick")(eye,"RightButton")
 T.eq(first,"native");T.eq(second,"RightButton","the router preserves the original right-click results")
 T.eq(eye:GetScript("OnClick"),routed,"clicks do not wrap the handler again")
 T.eq(nativeOpens,1,"premade clicks never also open native or other hooked group windows")
 -- Matchmaking transitions and setting changes must never enter addon Lua to
 -- construct the right-click menu. Its protected callbacks remain stock-owned.
 local pvpStatus
 env.GetBattlefieldStatus=function() return pvpStatus or "none" end
 queueMode=nil;listing=true;apps={}
 for _,hidden in ipairs({false,true}) do
  conceal=hidden
  for _,status in ipairs({"queued","confirm","active"}) do
   pvpStatus=status;a:SyncNativeLFGEntry()
   T.eq(eye:GetScript("OnClick"),NativeClick,status.." retains native script identity")
   T.eq(eye:GetAlpha(),1);T.eq(eye:IsMouseEnabled(),true)
   local before=menus;Click("RightButton");T.eq(menus,before+1,status.." passes through to the native menu")
   T.eq(LeftButton(),left,"all transitions reuse a single overlay")
  end
 end
 pvpStatus=nil;a:SyncNativeLFGEntry()
 T.eq(left:IsShown(),false,"concealment disables the premade overlay too")
 conceal=false;a:SyncNativeLFGEntry();T.eq(left:IsShown(),true)
 -- Release after the application vanishes must not invoke a stale target or
 -- call the native menu from our addon callback as a fallback.
 listing=false;apps={};local before=opened;local beforeMenus=menus
 left:GetScript("OnClick")(left,"LeftButton")
 T.eq(opened,before);T.eq(menus,beforeMenus);T.eq(left:IsShown(),false)
 T.eq(eye:GetScript("OnClick"),NativeClick)
 -- The stock frame does not subscribe to application status changes. Keep
 -- the routing state fresh even after Group has taken over the wake events.
 a:OnModuleReady("Group")
 T.ok(events.events.LFG_LIST_APPLICATION_STATUS_UPDATED,"application routing remains observed after the domain loads")
 apps={{"applied"}};Event("LFG_LIST_APPLICATION_STATUS_UPDATED",1)
 T.eq(left:IsShown(),true,"new application enables routing without a stock Update")
 apps={{"cancelled"}};Event("LFG_LIST_APPLICATION_STATUS_UPDATED",1)
 T.eq(left:IsShown(),false,"ended application releases routing before the next click")
 for _,mode in ipairs({"hidden","premade","native"}) do
  conceal=mode=="hidden";listing=mode=="premade";apps={}
  a:SyncNativeLFGEntry()
  local count,frameCount=writes,#frames
  for i=1,100 do a:SyncNativeLFGEntry() end
  T.eq(writes,count,mode.." steady refresh performs no visibility/alpha/mouse writes")
  T.eq(#frames,frameCount,mode.." steady refresh allocates no frames")
 end
 T.eq(TestStubs.PendingTimers(),0,"queue state changes need no polling")
 for _,frame in ipairs(frames) do
  for event in pairs(frame.events) do frame:UnregisterEvent(event) end
  frame:SetScript("OnEvent",nil)
 end
end
