-- Configuration-only allocation diagnostics in the existing Lua 5.1 UI fixture.
-- These are Lua fixture costs, not WoW AddOn memory or a replacement budget.
-- Run with lifecycle for individual source/startup/UI construction phases.
-- The default mode measures the public cold-theme and live-preference routes.
-- Source loading includes bytecode compilation. Context samples are nested in
-- their containing source/operation sample, so those rows must not be summed.
-- The Lua 5.1 fixture uses Lua tables for native objects; retained KiB here are
-- process diagnostics, never WoW AddOn attribution or a natural-operation peak.
if arg and arg[1]=="lifecycle" then
 local originalDofile,originalLoadfile=dofile,loadfile
 local active,contextNumber
 local function Phase(name,callback,...)
  local parent=active
  if parent then parent.allocated=parent.allocated+collectgarbage("count")-parent.segment end
  collectgarbage("collect")
  local initial=collectgarbage("count")
  collectgarbage("stop")
  local sample={allocated=0,segment=initial};active=sample
  local result=callback(...)
  sample.allocated=sample.allocated+collectgarbage("count")-sample.segment
  collectgarbage("restart");collectgarbage("collect")
  local retained=collectgarbage("count")-initial
  print(string.format("%s allocatedKiB=%.3f retainedKiB=%.3f",name,sample.allocated,retained))
  active=parent
  if parent then
   parent.allocated=parent.allocated+sample.allocated
   parent.segment=collectgarbage("count");collectgarbage("stop")
  end
  return result
 end
 local wrappedContext
 local function ContextHook()
  if wrappedContext or not LycheeUI or not LycheeUI.CreateContext then return end
  wrappedContext=LycheeUI.CreateContext
  LycheeUI.CreateContext=function(self,...)
   contextNumber=(contextNumber or 0)+1
   return Phase("context-"..contextNumber,wrappedContext,self,...)
  end
 end
 dofile=function(path)
  if path:find("addon/",1,true)~=1 then return originalDofile(path) end
  local result=Phase("source:"..path,originalDofile,path)
  if path=="addon/LycheeGroup/Core.lua" then
   local loadDB=LycheeGroup.LoadDB
   LycheeGroup.LoadDB=function(self)
    if self.db then return loadDB(self) end
    return Phase("first-LoadDB",loadDB,self)
   end
  end
  return result
 end
 loadfile=function(path)
  if path:find("addon/LycheeGroup/Libs/LycheeUI/",1,true)~=1 then return originalLoadfile(path) end
  -- The fixture immediately calls each known library chunk with its addon
  -- private table. Compile inside this seam to include compilation costs.
  return function(...)
   local result=Phase("source:"..path,function(...) return assert(originalLoadfile(path))(...) end,...)
   ContextHook();return result
  end
 end
 print("lifecycle Lua=".._VERSION.." size_t="..string.dump(function() end):byte(9).." bytes; diagnostic GC only; nested rows overlap")
 local measured=originalDofile("tests/ui_fixture.lua")("enUS")
 local A=measured.A
 dofile,loadfile=originalDofile,originalLoadfile
 Phase("source:Floating.lua",originalDofile,"addon/LycheeGroup/Floating.lua")
 Phase("source:API.lua",originalDofile,"addon/LycheeGroup/API.lua")
 Phase("first-floating",A.Floating.UpdateSettings,A.Floating)
 for _,page in ipairs({"settings","find","create","notes"}) do Phase("first-page:"..page,A.Open,A,page) end
 Phase("repeat-page:create",A.Open,A,"create")
 Phase("same-page:create",function() for index=1,10 do A:Open("create") end end)
 LycheeUI.CreateContext=wrappedContext
 return
end
local fixture=dofile("tests/ui_fixture.lua")("enUS")
local A,C,L=fixture.A,fixture.A.Configuration,LycheeUI
local function Count(value)
 local count=0;for _ in pairs(value or {}) do count=count+1 end;return count
end
local function Tables(value,seen)
 if type(value)~="table" then return 0 end
 seen=seen or {};if seen[value] then return 0 end;seen[value]=true
 local total=1;for key,item in pairs(value) do total=total+Tables(key,seen)+Tables(item,seen) end
 return total
end
local function Measure(name,iterations,callback)
 collectgarbage("collect");collectgarbage("stop")
 local initial=collectgarbage("count");local started=os.clock()
 local result
 for i=1,iterations do result=callback(i) end
 local allocated=collectgarbage("count")-initial
 local elapsed=os.clock()-started
 collectgarbage("restart");collectgarbage("collect")
 local retained=collectgarbage("count")-initial
 print(string.format("%s iterations=%d allocatedKiB=%.3f retainedKiB=%.3f cpuMs=%.3f resultFields=%d resultTables=%d",name,iterations,allocated,retained,elapsed*1000,type(result)=="table" and Count(result) or 0,Tables(result)))
 return result
end
local function Structure(name)
 print(string.format("%s definitions=%d configurationTables=%d appearanceTables=%d runtimeThemeTables=%d defaultsTables=%d savedUserFields=%d",name,Count(C.definitions),Tables(C),Tables(A.Appearance),Tables(A.RuntimeTheme),Tables(A.ThemeDefaults),Count(A.db.uiConfig.user)+Count(A.charPrefs.uiConfig.user)))
end
print("cold-theme Lua=".._VERSION.." size_t="..string.dump(function() end):byte(9).." bytes; diagnostic GC only")
Structure("startup")
Measure("preference-schema",10,function() return C:GetSchema() end)
Measure("main-theme-schema",10,function() return A.API.Appearance:GetSchema("main") end)
Measure("main-style-schema",10,function() return A.API.Appearance:GetStyleSchema("main") end)
Measure("default-template",10,function() return A.API.Theme:GetDefaults() end)
local definition={schema=1,id="measure.cold",revision=1,settings={fontScale=110},appearance={main={tokens={primary={.1,.2,.3,1}}}}}
local runtime=A.RuntimeTheme
Measure("theme-first-import",1,function() assert(A.API.Theme:Import(definition,{activate=true}));return A.API.Theme:GetStatus() end)
Measure("theme-same-import",25,function() assert(A.API.Theme:Import(definition,{activate=true}));return A.API.Theme:GetStatus() end)
Measure("theme-replacement",25,function(index)
 definition.revision=index+1;definition.appearance.main.tokens.primary[1]=index%2==1 and .2 or .1
 assert(A.API.Theme:Import(definition,{activate=true}));return A.API.Theme:GetStatus()
end)
assert(A.RuntimeTheme==runtime,"theme writes must not replace the startup source")
assert(A:GetSetting("fontScale")~=110,"pending defaults must not change current preferences")
assert(A.API.Theme:GetStatus().reloadRequired,"selected replacement requires reload")
local resolved=0;local resolve=L.ResolveTheme
L.ResolveTheme=function(...) resolved=resolved+1;return resolve(...) end
local value=C:Get("settings.fontScale")
Measure("same-preference",25,function() assert(C:Set({["settings.fontScale"]=value})) end)
Measure("changed-preference",25,function(index) assert(C:Set({["settings.fontScale"]=index%2==1 and 105 or 100})) end)
print("live-preferences ResolveTheme="..resolved)
L.ResolveTheme=resolve
Measure("all-pages",1,function()
 A:SetSetting("reduceMotion",true)
 for _,page in ipairs({"find","create","notes","settings"}) do A:Open(page) end
end)
Measure("live-ui-preference",10,function(index) assert(C:Set({["settings.fontScale"]=index%2==1 and 105 or 100})) end)
assert(A.RuntimeTheme==runtime)
local context=A.UI.context
local records=0
for controller in pairs(context.fixedControllers or {}) do records=records+Count(controller.records) end
-- Rule controllers cover styled objects, not every native object in the context.
print(string.format("all-pages nodes=%d fontStyles=%d fixedRuleControllers=%d ruleRecords=%d",#fixture.S.nodes,Count(context.fontStyles),Count(context.fixedControllers),records))
Structure("all-pages")
