-- Standalone: lua tests/test_guide_adapter.lua
-- Lifecycle and ownership evidence uses the production controller with UI stubs.
local Fixture=dofile("tests/ui_fixture.lua")
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Equal(a,b,message) Check(a==b,message) end
local function Copy(value)
 if type(value)~="table" then return value end
 local result={};for key,item in pairs(value) do result[key]=Copy(item) end;return result
end
local function Same(actual,expected,path)
 if type(actual)~="table" or type(expected)~="table" then Equal(actual,expected,path);return end
 for key,value in pairs(expected) do Same(actual[key],value,path.."."..tostring(key)) end
 for key in pairs(actual) do Check(expected[key]~=nil,path.." gained "..tostring(key)) end
end
local function LoadGuide()
 for line in io.lines("addon/LycheeGroup_Guide/LycheeGroup_Guide.toc") do
  local file=line:match("^%s*(.-)%s*$")
  if file~="" and file:sub(1,1)~="#" then dofile("addon/LycheeGroup_Guide/"..file) end
 end
end
local function MethodSnapshot(f)
 local result={}
 for _,owner in ipairs({f.U,f.U.Native,f.U.Application,f.U.Tooltip,f.A.Appearance,f.U.pages.find,f.U.pages.create,f.U.pages.settings,f.A.GuideEntry}) do
  -- Public production methods use capitalized names. Lowercase fields such as
  -- Settings.themeSubscription are normal per-visit unsubscribe closures.
  local methods={};for key,value in pairs(owner) do if type(value)=="function" and type(key)=="string" and key:match("^[A-Z]") then methods[key]=value end end
  result[#result+1]={owner=owner,methods=methods}
 end
 return result
end
local function ReplaceExpected(snapshot,owner,key,value)
 for _,record in ipairs(snapshot) do if record.owner==owner then record.methods[key]=value;return end end
 error("test method owner missing")
end
local function Geometry(U)
 local point={n=U.frame:GetNumPoints()}
 for i=1,point.n do point[i]={U.frame:GetPoint(i)} end
 return {width=U.windowWidth,height=U.windowHeight,preferredWidth=U.preferredWindowWidth,preferredHeight=U.preferredWindowHeight,point=point}
end
local function NativeBoundary()
 local api,average=C_LFGList,GetAverageItemLevel
 local members={};for key,value in pairs(api) do members[key]=value end
 local originalMeta=getmetatable(_G)
 local writes=0
 local proxy=setmetatable({},{__index=api,__newindex=function(_,key) writes=writes+1;error("guide attempted to replace C_LFGList."..tostring(key),0) end})
 local meta={};for key,value in pairs(originalMeta or {}) do meta[key]=value end
 meta.__index=function(owner,key)
  if key=="C_LFGList" then return proxy elseif key=="GetAverageItemLevel" then return average end
  local previous=originalMeta and originalMeta.__index
  if type(previous)=="function" then return previous(owner,key) elseif previous then return previous[key] end
 end
 meta.__newindex=function(owner,key,value)
  if key=="C_LFGList" or key=="GetAverageItemLevel" then writes=writes+1;error("guide attempted to replace native global "..key,0) end
  local previous=originalMeta and originalMeta.__newindex
  if type(previous)=="function" then return previous(owner,key,value) elseif previous then previous[key]=value else rawset(owner,key,value) end
 end
 rawset(_G,"C_LFGList",nil);rawset(_G,"GetAverageItemLevel",nil);setmetatable(_G,meta)
 return function()
  Equal(C_LFGList,proxy,"native API table identity never changes")
  Equal(GetAverageItemLevel,average,"native player item-level function identity never changes")
  Equal(writes,0,"guide never attempts a temporary or permanent native API replacement")
  for key,value in pairs(members) do Equal(api[key],value,"original native API member remains intact: "..tostring(key)) end
 end,function()
  setmetatable(_G,originalMeta);rawset(_G,"C_LFGList",api);rawset(_G,"GetAverageItemLevel",average)
 end
end
local function Prepare()
 local f=Fixture("enUS",nil,{reduceMotion=true});local A,U=f.A,f.U
 -- Build the production pages and ordinary preview indicator before measuring
 -- ownership. Creating legitimate lazy controls is not a guide field leak.
 A:Open("find");A:Open("create");A:Open("notes");A:Open("settings")
 Check(U:StartPreview("applications"),"ordinary preview warms its standard controls")
 U:StopPreview(true);A:Open("settings")
 U.frame:ClearAllPoints();U.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",110,-70);U.Motion:CapturePosition()
 f.methods=MethodSnapshot(f);f.geometry=Geometry(U)
 f.textTooltip=U.Tooltip.text
 f.character=Copy(A.charPrefs);f.group=Copy(f.G.db)
 f.account=Copy(A.db);f.account.guide=nil
 f.uiKeys={};for key in pairs(U) do f.uiKeys[key]=true end
 local check,restore=NativeBoundary();f.checkNative,f.restoreNative=check,restore
 local ok,err=pcall(LoadGuide)
 if not ok then restore();error(err,0) end
 f.guide=A.Guide;return f
end
local function Clean(f)
 local guide,U=f.guide,f.U
 Equal(guide.active,nil,"tour is inactive after exit")
 Equal(guide.Adapter.session,nil,"adapter releases the private preview session")
 Equal(guide.Adapter.geometry,nil,"adapter releases its temporary geometry")
 Equal(guide.Adapter.starting,nil,"adapter releases startup write suppression")
 Equal(#guide.Adapter.leases,0,"adapter releases all method leases")
 Equal(U.Tooltip.text,f.textTooltip,"the exact ordinary text tooltip reference is restored")
 Equal(guide.Adapter.tooltip,nil,"adapter releases tooltip ownership")
 Check(not guide.Adapter.quietTooltip:IsShown(),"the reusable private tooltip stays hidden")
 Equal(#guide.Bindings.records,0,"current-phase native scripts are released")
 Equal(guide.task,nil,"tour releases its finite task")
 Equal(guide.View.target,nil,"spotlight releases its target")
 Equal(guide.View.avoidFrame,nil,"spotlight releases its tooltip")
 Equal(U.preview,nil,"tour returns to the production data source")
 Equal(U:GetGroup(),f.G,"production group identity is restored")
 Equal(U.pages.find.liveState,nil,"Find releases its saved preview state")
 Equal(U.pages.create.liveState,nil,"Create releases its saved preview state")
 Equal(U.guideSession,nil,"UI does not retain guide state")
 Equal(U.NotifyGuide,nil,"UI has no guide dispatch method")
 for _,record in ipairs(f.methods) do
  for key,method in pairs(record.methods) do Equal(record.owner[key],method,"existing method restored: "..tostring(key)) end
  for key,method in pairs(record.owner) do
   if type(method)=="function" and type(key)=="string" and key:match("^[A-Z]") then Check(record.methods[key]~=nil,"tour added a permanent method: "..tostring(key)) end
  end
 end
 for key in pairs(U) do
  Check(f.uiKeys[key],"tour leaves no additional top-level UI state after the production warmup: "..tostring(key))
 end
 Same(f.A.charPrefs,f.character,"character preferences")
 Same(f.G.db,f.group,"real group database")
 local account=Copy(f.A.db);account.guide=nil;Same(account,f.account,"account preferences")
 local geometry=Geometry(U)
 Equal(geometry.width,f.geometry.width,"window width restored")
 Equal(geometry.height,f.geometry.height,"window height restored")
 Equal(geometry.preferredWidth,f.geometry.preferredWidth,"preferred width restored")
 Equal(geometry.preferredHeight,f.geometry.preferredHeight,"preferred height restored")
 Equal(geometry.point.n,f.geometry.point.n,"window anchors restored")
 for i=1,geometry.point.n do
  for j,value in ipairs(f.geometry.point[i]) do Equal(geometry.point[i][j],value,"window anchor component restored") end
 end
 f.checkNative()
end
local function Scenario(name,body)
 local f=Prepare()
 local ok,err=pcall(body,f)
 if ok then ok,err=pcall(Clean,f) end
 f.restoreNative()
 if not ok then error(name..": "..tostring(err),0) end
end
local function Start(f)
 Check(f.guide:Open(),"welcome page opens")
 Check(f.guide:Start(),"tour starts with production controls")
 Check(f.guide.Adapter.session==f.U.preview and f.U.preview.provider~=f.G,"tour owns a private preview rather than the real group")
 f.checkNative()
end

for _,exit in ipairs({"escape","hide","open","navigate","endPreview"}) do
 Scenario("exit via "..exit,function(f)
  Start(f)
  f.U:SetWindowSize(f.geometry.width+65,f.geometry.height+30)
  if exit=="escape" then f.U:HandleEscape();Check(f.U:IsShown(),"escape keeps the original window available")
  elseif exit=="hide" then f.U:Hide(true);Check(not f.U:IsShown(),"explicit Hide remains hidden")
  elseif exit=="open" then Check(f.A:Open("notes"),"ordinary A.Open can interrupt the tour");Equal(f.U.page,"notes","ordinary navigation reaches its destination")
  elseif exit=="navigate" then f.U:Navigate("settings");Equal(f.U.page,"settings","direct navigation reaches its destination")
  else f.U:EndPreview() end
 end)
end

Scenario("welcome escape",function(f)
 Check(f.guide:Open(),"welcome opens without a private session")
 Check(not f.U:IsShown() and f.guide.View.card:IsVisible(),"standalone welcome is visible while the main window is hidden")
 Check(LycheeGroupEscapeHandler:IsShown(),"native Escape dispatch can reach the standalone welcome")
 LycheeGroupEscapeHandler:Hide()
end)

Scenario("page entry error",function(f)
 local page=f.U.pages.find;local original=page.Enter
 local sentinel={source="page-entry"}
 local failing=function(owner,...) original(owner,...);error(sentinel,0) end
 page.Enter=failing;ReplaceExpected(f.methods,page,"Enter",failing)
 Check(f.guide:Open(),"welcome is independent of the Find page")
 local ok,err=pcall(f.guide.Start,f.guide)
 Check(not ok and err==sentinel,"page startup preserves the original failure object")
end)

Scenario("leased method error",function(f)
 local sentinel={source="font-method"}
 local failing=function() error(sentinel,0) end
 f.U.ApplyFont=failing;ReplaceExpected(f.methods,f.U,"ApplyFont",failing)
 Start(f)
 local ok,err=pcall(f.U.ApplyFont,f.U,nil,1)
 Check(not ok and err==sentinel,"leased original errors propagate after cleanup")
end)

Scenario("EndPreview fails before releasing its session",function(f)
 local sentinel={source="before-preview-release"}
 local failing=function() error(sentinel,0) end
 f.U.EndPreview=failing;ReplaceExpected(f.methods,f.U,"EndPreview",failing)
 Start(f)
 Check(f.U.pages.find.liveState and f.U.pages.create.liveState,"both pages hold real state while teaching")
 local ok,err=pcall(f.guide.Stop,f.guide,"later")
 Check(not ok and err==sentinel,"the original preview-cleanup error propagates after fallback cleanup")
 Equal(f.U.preview,nil,"failed EndPreview cannot leave the private session installed")
 Equal(f.U.pages.find.liveState,nil,"failed EndPreview still restores real Find state")
 Equal(f.U.pages.create.liveState,nil,"failed EndPreview still restores real Create state")
end)

Scenario("starting guide while a resize is active",function(f)
 local saves=0;local original=f.A.Appearance.SaveWindowSize
 local tracked=function(owner,...) saves=saves+1;return original(owner,...) end
 f.A.Appearance.SaveWindowSize=tracked;ReplaceExpected(f.methods,f.A.Appearance,"SaveWindowSize",tracked)
 f.S.cursorX,f.S.cursorY=800,400
 f.U:BeginWindowResize()
 Check(f.U.resizing~=nil,"a real production resize is active before starting the guide")
 -- BeginWindowResize owns a temporary top-left anchor. Preserve that current
 -- geometry; the guide must not commit its unfinished size to real preferences.
 f.geometry.point=Geometry(f.U).point
 Start(f)
 Equal(saves,0,"guide startup suppresses a pending resize's real SaveWindowSize call")
 Equal(f.U.resizing,nil,"guide startup finishes the transient production drag")
 f.guide:Stop("later")
 Equal(saves,0,"ending the guide also leaves the unfinished resize unsaved")
end)

Scenario("foreign wrapper survives detach and reopen",function(f)
 Start(f)
 local original
 for _,record in ipairs(f.methods) do if record.owner==f.U then original=record.methods.ApplyFont end end
 local proxy=f.U.ApplyFont;local calls=0
 local foreign=function(owner,...) calls=calls+1;return proxy(owner,...) end
 f.U.ApplyFont=foreign;ReplaceExpected(f.methods,f.U,"ApplyFont",foreign)
 local weak=setmetatable({f.U.preview.provider},{__mode="v"})
 f.guide:Stop("later")
 Equal(f.U.ApplyFont,foreign,"detach preserves the later external wrapper")
 local updates=0;local update=f.guide.UpdateStep
 f.guide.UpdateStep=function(owner,...) updates=updates+1;return update(owner,...) end
 Start(f)
 local before=updates
 f.U:ApplyFont(nil,1)
 Equal(updates,before+1,"retired proxy calls only its original while the new adapter teaches once")
 Equal(calls,1,"external wrapper remains in the method chain")
 f.guide:Stop("later");f.guide.UpdateStep=update
 collectgarbage("collect");collectgarbage("collect")
 Equal(weak[1],nil,"foreign proxy releases the previous private provider graph")
 Equal(f.U.ApplyFont,foreign,"second detach still respects foreign ownership")
 -- Test owns this external wrapper and removes it after proving preservation.
 f.U.ApplyFont=original;ReplaceExpected(f.methods,f.U,"ApplyFont",original)
end)

Scenario("ordinary preview replaced by guide",function(f)
 Check(f.U:StartPreview("applications"),"ordinary preview opens before the guide")
 local ordinary=f.U.preview
 local weak=setmetatable({ordinary.provider},{__mode="v"})
 Start(f,"create")
 Check(f.U.preview~=ordinary and f.U.preview.provider~=ordinary.provider,"guide does not adopt the ordinary preview's provider")
 f.guide:Stop("later")
 Equal(f.U.page,"find","leaving guide opens the real home page")
 ordinary=nil;collectgarbage("collect");collectgarbage("collect")
 Equal(weak[1],nil,"replaced ordinary preview provider is released")
end)

Scenario("fifty reopens retain no permanent callbacks",function(f)
 for _,route in ipairs({"find","create"}) do Start(f,route);f.guide:Stop("later") end
 local objects=#f.S.nodes
 local baselines={};local providers={}
 for i=1,50 do
  Start(f,i%2==0 and "find" or "create")
  providers[i]=setmetatable({f.U.preview.provider},{__mode="v"})
  local scripts={}
  for _,record in ipairs(f.guide.Bindings.records) do
   scripts[#scripts+1]={record.control,record.event,record.original}
   local prior=baselines[record.control]
   if not prior then prior={};baselines[record.control]=prior end
   if prior[record.event] then Equal(record.original,prior[record.event],"reopening never wraps a previously retained teaching callback")
   else prior[record.event]=record.original end
  end
  f.guide:Stop("later")
  for _,record in ipairs(scripts) do Equal(record[1]:GetScript(record[2]),record[3],"exit restores each phase's native script identity") end
  Equal(#f.S.nodes,objects,"warm reopens do not create permanent native objects")
  Equal(#f.guide.Adapter.leases,0,"each reopen releases method leases")
  Equal(#f.guide.Bindings.records,0,"each reopen releases native callbacks")
 end
 collectgarbage("collect");collectgarbage("collect")
 for _,weak in ipairs(providers) do Equal(weak[1],nil,"each closed tour releases its provider graph") end
end)

print(("guide adapter checks passed: %d"):format(checks))
