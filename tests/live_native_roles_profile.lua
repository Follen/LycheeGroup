-- Private native application modal replay; never changes player roles or saved data.
-- Build with Build-IsolatedLibraryProbe.ps1 and the candidate Application.lua.
local probe,library,loadModule=...
local product=LycheeGroup
if not library or not loadModule or not product then return probe:Fail("dependencies_unavailable") end
if InCombatLockdown() then return probe:Fail("combat") end
assert(probe:Async(25))
local parent,context,driver,app
local report={scope="private_native_application_modal",build=select(2,GetBuildInfo()),library=library.versionString,iterations=300,maxBatch=10,gc="natural; whole-client heap, not addon retained bytes",scenes={}}
local originalLayout
assert(probe:OnCleanup(function()
 if driver then driver:SetScript("OnUpdate",nil);driver:Hide() end
 if app and originalLayout then app.LayoutApplication=originalLayout end
 if context then context.Motion:StopAll();context:Hide() end
 if parent then parent:Hide() end
end))
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(600,600);parent:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",-10000,-10000)
context=library:CreateContext({parent=parent,reducedMotion=false,font="Interface\\AddOns\\LycheeGroup\\Media\\Fonts\\LycheeFont-zhCN.ttf",themeDefaults=product.StyleDefaults.main})
local C,T=context.C,context.Theme
local ui={Theme=T,C=C,Motion=context.Motion,L=product.L,ApplyElementScope=function() end,ElementFields=function() end,Element=function() end}
function ui:SetText(label,text) label:SetText(text or "") end
function ui:OpenModal()
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(512,452);frame:SetPoint("TOPLEFT")
 local content=CreateFrame("Frame",nil,frame);content:SetSize(464,320);content:SetPoint("TOPLEFT",24,-64)
 return {frame=frame,content=content}
end
function ui:CreateRoleButton(owner,role,width,text,action)
 local button=C.Button(owner,text,width or 0,action)
 local icon=C.Icon(button,T.roleButtonIconSize);icon:SetPoint("LEFT",T.roleButtonInset,0)
 -- Icon identity is irrelevant to this three-button role/layout cost.
 button.roleIcon=icon;button.label:ClearAllPoints();button.label:SetPoint("LEFT",icon,"RIGHT",T.roleButtonGap,0)
 button:SetWidth(width or button.label:GetStringWidth()+T.roleButtonReserve)
 button:SetSurfaceColors("surfaceLow","surfaceLowHover","surfaceLowPressed")
 return button
end
local native={false,false,false,true}
local group={UI=ui,GetLocale=function() return "zhCN" end,GetSetting=function(_,key) if key=="applicationRoles" then return {DAMAGER=true} end;return false end}
local environment=setmetatable({LycheeGroup=group,C_LFGList={GetAvailableRoles=function() return true,true,true end},GetLFGRoles=function() return unpack(native) end,SetLFGRoles=function(a,b,c,d) native[1],native[2],native[3],native[4]=a,b,c,d;if app then app:RefreshApplicationRoles() end end},{__index=_G});environment._G=environment
loadModule(environment);app=ui.Application
local buildStart=debugprofilestop();app:BuildApplication()
app.applicationLease={available={},roles={DAMAGER=true}}
app:RefreshApplicationRoles();report.buildMs=debugprofilestop()-buildStart
local names={"unchanged","toggle"}
local phase,round,index,waiting=1,1,0,2
local samples,layouts={},0
originalLayout=app.LayoutApplication
local heapStart=collectgarbage("count")
local function Summary(values)
 table.sort(values);local total=0;for _,v in ipairs(values) do total=total+v end
 return {count=#values,totalMs=total,p95Ms=values[math.ceil(#values*.95)],maxMs=values[#values]}
end
local maxBatch=0
local function Operate()
 if phase==1 then app:RefreshApplicationRoles() else app:SetApplicationRole("HEALER") end
end
driver=CreateFrame("Frame")
driver:SetScript("OnUpdate",assert(probe:Callback(function()
 if waiting>0 then waiting=waiting-1;return end
 local batchStart=debugprofilestop()
 for i=1,10 do
  local started=debugprofilestop();Operate();local duration=debugprofilestop()-started
  if round==1 then samples[#samples+1]=duration end
 end
 maxBatch=math.max(maxBatch,debugprofilestop()-batchStart);index=index+10
 if index<300 then return end
 if round==1 then
  report.scenes[names[phase]]={timing=Summary(samples),maxBatchMs=maxBatch}
  round=2;index=0;layouts=0
  function app:LayoutApplication(...) layouts=layouts+1;return originalLayout(self,...) end
  return
 end
 report.scenes[names[phase]].layouts=layouts
 app.LayoutApplication=originalLayout
 if phase==1 then phase=2;round=1;index=0;samples={};maxBatch=0;waiting=2;return end
 report.heapStartKiB=heapStart;report.heapEndKiB=collectgarbage("count")
 report.nativeIsPrivate=environment.GetLFGRoles~=GetLFGRoles
 context.Motion:StopAll();context:Hide();parent:Hide();driver:SetScript("OnUpdate",nil);driver:Hide()
 report.cleanup={jobs=context.Motion:Count(),driverStopped=driver:GetScript("OnUpdate")==nil,productUnchanged=LycheeGroup==product}
 assert(report.cleanup.jobs==0 and report.nativeIsPrivate,"isolation_or_cleanup_failed")
 probe:Finish(report)
end)))
