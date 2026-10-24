-- Theme v2 uses real startup boundaries; opening another page is not a reload.
local Fixture=dofile("tests/ui_fixture.lua")
local function Definition(id,revision,width,scale)
 return {schema=1,id=id,revision=revision,appearance={main={tokens={width=width}}},settings={fontScale=scale}}
end
local function Reload(f) return Fixture("enUS",f.A.charPrefs,f.A.db) end
local function Namespace(user,presets,selected)
 return {schema=1,user=user or {},presets=presets or {},activePreset=selected,imported={}}
end

-- Current context, newly created contexts and data getters share one boot source.
do
 local f=Fixture("enUS");local a=f.A;local api=a.API.Theme
 local width=a.Appearance:GetResolvedTheme("main").width
 local context=f.U.context;local theme=context.Theme
 local definition=Definition("reload.current",1,width+100,110)
 T.ok(api:Import(definition,{activate=true}))
 T.eq(a.Appearance:GetResolvedTheme("main").width,width)
 T.eq(context.Theme,theme);T.eq(theme.width,width);T.eq(a:GetSetting("fontScale"),100)
 T.eq(api:GetStatus().current.id,false);T.eq(api:GetStatus().next.id,definition.id);T.eq(api:GetStatus().reloadRequired,true)
 local late=LycheeUI:CreateContext({themeDefaults=a.StyleDefaults.main,theme=a.Appearance:GetTheme("main"),recipeDefaults=a.ThemeDefaults.appearance.main.components,recipes=a.Appearance:GetRecipes("main"),elementDefaults=a.ThemeDefaults.appearance.main.elements,elements=a.Appearance:GetElements("main"),utilities=a.Appearance:GetUtilities("main")})
 T.eq(late.Theme.width,width,"first LoD consumers cannot see the pending theme")
 definition.settings.fontScale=125;T.eq(a:GetSetting("fontScale"),100)
 f=Reload(f);a=f.A;api=a.API.Theme
 T.eq(a.Appearance:GetResolvedTheme("main").width,width+100);T.eq(a:GetSetting("fontScale"),110)
 T.eq(api:GetStatus().reloadRequired,false)
 local saved=api:Export();T.eq(saved.settings.fontScale,110)
 T.ok(api:Import(saved));T.eq(api:GetStatus().reloadRequired,false,"startup re-registration is idempotent")
 T.eq(#api:List(),1)
 T.ok(api:Import(Definition("reload.unselected",1,width+200,120)))
 T.eq(api:GetStatus().reloadRequired,false,"an unselected package update needs no reload")
 saved.revision=2;saved.settings.fontScale=115;T.ok(api:Import(saved))
 T.eq(a:GetSetting("fontScale"),110);T.eq(api:GetStatus().reloadRequired,true)
 T.eq(api:Export(nil,{state="current"}).settings.fontScale,110)
 T.eq(api:Export(saved.id,{state="current"}).revision,1)
 T.eq(api:Export(nil,{state="unknown"}),nil)
 T.eq(api:Export().settings.fontScale,115)
end

-- All theme writes validate before committing and never invoke live lifecycle.
do
 local f=Fixture("enUS");local a=f.A;local api=a.API.Theme;local store=a.db.uiConfig.theme
 local updates=0;a.ApplyConfigurationChanges=function() updates=updates+1 end
 local function Invalid(def,options)
  local presets,overrides=store.presets,store.overrides
  local ok,err=api:Import(def,options);T.eq(ok,false);T.eq(type(err),"string")
  T.eq(store.presets,presets);T.eq(store.overrides,overrides);T.eq(api:GetStatus().reloadRequired,false)
 end
 Invalid(Definition("reload.session",1,1500,110),{storage="session",activate=true})
 Invalid(Definition("reload.storage",1,1500,110),{storage=false})
 T.eq(api:Remove(nil),false)
 Invalid({schema=1,id="bad",revision=0/0})
 Invalid({schema=1,id="bad",revision=math.huge})
 local cycle={schema=1,id="bad",revision=1};cycle.appearance=cycle;Invalid(cycle)
 Invalid({schema=1,id="bad",revision=1,settings={autoJoin=true}})
 Invalid({schema=1,id="bad",revision=1,appearance={main={tokens={unknownToken=1}}}})
 Invalid({schema=1,id="bad",revision=1,appearance={main={components={button={base={bogus={color="primary"}}}}}}})
 Invalid({schema=1,id="bad",revision=1,appearance={main={elements={["host.settingsButton"]={slotKinds={root="text"}}}}}})
 Invalid({schema=1,id="bad",revision=1,appearance={main={utilities={bad={base={label={color="missingToken"}}}}}}})
 T.ok(api:Import(Definition("reload.valid",1,1450,110),{activate=true}))
 T.eq(updates,0)
 T.eq(api:Activate("missing"),false);T.eq(api:Activate(false,{storage="session"}),false)
 T.eq(a.API.Appearance:Get("main").width,a.StyleDefaults.main.width)
end

-- Live preferences and their packages are independent of pending Theme selection.
do
 local f=Fixture("enUS",nil,nil,Definition("reload.live",1,1500,105));local a=f.A;local api=a.API.Theme;local c=a.Configuration
 T.eq(a:GetSetting("fontScale"),105);T.eq(c:GetSource("settings.fontScale").kind,"theme")
 T.ok(api:Import(Definition("reload.live",2,1600,120)))
 T.ok(c:ApplyPreset("live.preferences",1,{["settings.fontScale"]=110,["settings.history"]=false},{storage="account"}))
 T.eq(a:GetSetting("fontScale"),110);T.eq(a:GetSetting("history"),false)
 T.eq(api:GetStatus().current.revision,1);T.eq(api:GetStatus().next.revision,2)
 T.ok(a:SetSetting("fontScale",115));T.eq(a:GetSetting("fontScale"),115)
 T.ok(c:Reset("settings.fontScale",{storage="account"}));T.eq(a:GetSetting("fontScale"),110)
 T.ok(c:ActivatePreset(false,{storage="account"}));T.eq(a:GetSetting("fontScale"),105,"pending theme defaults never leak through live resets")
 T.eq(c:GetSource("settings.fontScale").revision,1)
 T.ok(c:ActivatePreset("live.preferences",{storage="account"}));T.ok(a:SetSetting("fontScale",115))
 T.ok(c:Set({["settings.fontScale"]=125}));T.eq(a:GetSetting("fontScale"),125)
 T.ok(c:Reset("settings.fontScale"));T.eq(a:GetSetting("fontScale"),115)
 f=Reload(f);a=f.A;c=a.Configuration
 T.eq(a:GetSetting("fontScale"),115);T.eq(a:GetSetting("history"),false)
 T.eq(a.API.Theme:GetStatus().current.revision,2);T.eq(a.API.Theme:GetStatus().reloadRequired,false)
 T.ok(c:Reset("settings.fontScale",{storage="account"}));T.eq(a:GetSetting("fontScale"),110)
 T.ok(c:RemovePreset("live.preferences",{storage="account"}));T.eq(a:GetSetting("fontScale"),120)
end

-- Persistent layers preserve false selections, lookup precedence and fallback.
do
 local f=Fixture("enUS");local api=f.A.API.Theme
 T.ok(api:Import(Definition("reload.layer",1,1400,105),{activate=true}))
 T.ok(api:Import(Definition("reload.layer",2,1500,110),{storage="character"}))
 T.eq(api:GetStatus().next.revision,2,"character definition shadows the same account ID")
 T.ok(api:Activate(false,{storage="character"}));T.eq(api:GetStatus().next.id,false)
 T.ok(api:Remove("reload.layer",{storage="character"}));T.eq(api:GetStatus().next.id,false,"removing another definition does not clear explicit builtin selection")
 T.ok(api:Activate("reload.layer",{storage="character"}));T.eq(api:GetStatus().next.revision,1)
 T.ok(api:Remove("reload.layer",{storage="character"}))
 T.eq(api:GetStatus().next.id,"reload.layer","removing a selected character entry reveals account selection")
 T.ok(api:Remove("reload.layer"));T.eq(api:GetStatus().next.id,false)
end

-- Old sparse visual choices move without changing their layer or reviving mirrors.
do
 local account={uiConfig=Namespace({["theme.main.primary"]={.2,.3,.4,1},["settings.history"]=false,["future.unknown"]=17})}
 local character={uiConfig=Namespace({["theme.main.primary"]={.6,.5,.4,1}})}
 local f=Fixture("enUS",character,account);local a=f.A;local api=a.API.Theme
 T.eq(a.db.uiConfig.schema,2);T.eq(a.charPrefs.uiConfig.schema,2)
 T.eq(a.db.uiConfig.user["theme.main.primary"],nil)
 T.same(a.API.Appearance:GetColors("main").primary,{.6,.5,.4,1})
 T.eq(a.db.uiConfig.theme.legacy.user["future.unknown"],17)
 T.eq(a:GetSetting("history"),false)
 local current=a.RuntimeTheme.source.overrides.character
 T.ok(api:ResetOverrides("main",{"theme.main.primary"},{storage="character"}))
 T.same(current["theme.main.primary"],{.6,.5,.4,1},"override reset uses copy-on-write")
 T.same(a.API.Appearance:GetColors("main").primary,{.6,.5,.4,1})
 T.eq(api:GetStatus().reloadRequired,true,"an override reset also requires reload")
 f=Reload(f);a=f.A;api=a.API.Theme
 T.same(a.API.Appearance:GetColors("main").primary,{.2,.3,.4,1})
 T.eq(api:GetStatus().reloadRequired,false)
 T.ok(api:ResetOverrides("main"));f=Reload(f)
 T.eq(f.A.db.uiConfig.theme.overrides["theme.main.primary"],nil)
 T.eq(f.A:GetSetting("history"),false)
 T.eq(f.A.db.uiConfig.theme.legacy.user["future.unknown"],17)
end

-- Mixed v1 packages split once; pure preferences remain live preference packages.
do
 local mixed={revision="r1",values={["theme.main.width"]=1450,["settings.fontScale"]=105,["layout.window.width"]=1400,["settings.notesEnabled"]=false}}
 local account={uiConfig=Namespace({}, {mixed=mixed,prefs={revision=1,values={["settings.defaultSort"]="rating"}}},"mixed")}
 local character={uiConfig=Namespace({}, {},"mixed")}
 local f=Fixture("enUS",character,account);local a=f.A
 T.eq(a.db.uiConfig.theme.activePreset,"mixed");T.eq(a.charPrefs.uiConfig.theme.activePreset,"mixed")
 T.eq(a.db.uiConfig.activePreset,"mixed");T.eq(a.charPrefs.uiConfig.activePreset,"mixed")
 T.eq(a.db.uiConfig.presets.mixed.values["settings.fontScale"],nil)
 T.eq(a.db.uiConfig.theme.presets.mixed.values["settings.notesEnabled"],nil)
 T.eq(a:GetSetting("fontScale"),105);T.eq(a:GetSetting("notesEnabled"),false)
 T.eq(a.Appearance:GetWindowSize(),1400);T.eq(a.Appearance:GetResolvedTheme("main").width,1450)
 T.ok(a.Configuration:ActivatePreset("prefs",{storage="character"}))
 T.eq(a:GetSetting("defaultSort"),"rating");T.eq(a.API.Theme:GetStatus().reloadRequired,false)
 local themeStore=a.db.uiConfig.theme;f=Reload(f)
 T.eq(f.A.db.uiConfig.theme,themeStore,"migration does not run again")
 T.eq(f.A:GetSetting("defaultSort"),"rating")
 local only={uiConfig=Namespace({}, {visual={revision=1,values={["theme.main.width"]=1500}}},"visual")}
 local g=Fixture("enUS",nil,only)
 T.eq(g.A.db.uiConfig.activePreset,nil,"a missing preference projection is not invented as false")
 T.eq(g.A.db.uiConfig.theme.activePreset,"visual")
end

-- Invalid persisted selections fall back explicitly and retain their repair data.
do
 local account={uiConfig={schema=2,user={},presets={},imported={},theme={presets={},overrides={},activePreset="missing.theme"}}}
 local f=Fixture("enUS",nil,account);local status=f.A.API.Theme:GetStatus()
 T.eq(status.current.id,false);T.eq(status.next.id,"missing.theme");T.eq(status.reloadRequired,true)
 T.eq(type(status.error),"string");T.eq(type(status.next.error),"string")
 T.eq(account.uiConfig.theme.activePreset,"missing.theme")
 T.eq(f.A.API.Theme:Export(),nil)
 account.uiConfig.theme.presets["missing.theme"]={schema=1,id="missing.theme",revision=1,values={["theme.main.fontSizeDelta"]=-100}}
 f=Reload(f);status=f.A.API.Theme:GetStatus()
 T.eq(status.current.id,false);T.eq(status.next.id,"missing.theme");T.eq(type(status.error),"string")
 T.eq(account.uiConfig.theme.presets["missing.theme"].values["theme.main.fontSizeDelta"],-100)
 T.ok(f.A.API.Theme:Import(Definition("missing.theme",2,1500,110),{activate=true}))
 T.eq(f.A.API.Theme:GetStatus().current.id,false)
 f=Reload(f);T.eq(f.A.API.Theme:GetStatus().current.id,"missing.theme");T.eq(f.A.API.Theme:GetStatus().reloadRequired,false)
end

-- A stale visual scope remains repairable data and reports startup fallback.
do
 local values={["theme.removedScope.primary"]={.2,.3,.4,1}}
 local account={uiConfig={schema=2,user={},presets={},imported={},theme={presets={stale={schema=1,id="stale",revision=1,values=values}},overrides={},activePreset="stale"}}}
 local f=Fixture("enUS",nil,account)
 T.eq(f.A.RuntimeTheme.selection.id,false)
 T.ok(f.A.RuntimeTheme.error:find("theme.removedScope.primary",1,true))
 T.eq(account.uiConfig.theme.presets.stale.values,values)
end

-- Exercise the real addon event order before any optional UI module executes.
do
 local base=dofile("tests/stubs.lua")
 local ui=dofile("tests/ui_stubs.lua")
 local function Start(account,prefs)
  base.Install({locale="enUS",realm="Home"});ui.Install();_G.LycheeUI=nil;_G.LibStub=nil
  C_ChallengeMode.IsChallengeModeActive=function() return false end
  local private={}
  for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Styles.lua","Components.lua","Layouts.lua","Elements.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",private) end
  for _,file in ipairs({"Locale.lua","Theme/Defaults.lua","Theme/Elements.lua","Theme/FindElements.lua","Core.lua","Configuration.lua","Appearance.lua","Theme/Import.lua","Specializations.lua","Presentation.lua","Fonts.lua","BrandMotion.lua","ActivityLabels.lua","Floating.lua","API.lua","Entrypoints.lua"}) do dofile("addon/LycheeGroup/"..file) end
  LycheeGroupDB,LycheeGroupPrefsDB=account,prefs
  LycheeGroup.Minimap={Initialize=function() end}
  local function Fire(event,name)
   for index=1,#ui.nodes do local frame=ui.nodes[index];if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame,event,name) end end
  end
  return LycheeGroup,Fire
 end
 local account,prefs={},{}
 local a,Fire=Start(account,prefs)
 T.eq(a.RuntimeTheme,nil);T.eq(a.UI,nil)
 Fire("ADDON_LOADED","Unrelated");T.eq(a.RuntimeTheme,nil)
 Fire("ADDON_LOADED","LycheeGroup");T.eq(a.RuntimeTheme.selection.id,false)
 local original=a.Appearance:GetResolvedTheme("floating").floatingEntryHeight
 local thirdParty=CreateFrame("Frame");thirdParty:RegisterEvent("ADDON_LOADED")
 thirdParty:SetScript("OnEvent",function(self,_,name)
  if name=="ThemeAuthor" then self:UnregisterAllEvents();T.ok(a.API.Theme:Import({schema=1,id="reload.startup",revision=1,appearance={floating={tokens={floatingEntryHeight=original+12}}}},{activate=true})) end
 end)
 Fire("ADDON_LOADED","ThemeAuthor");T.eq(a.API.Theme:GetStatus().reloadRequired,true)
 Fire("PLAYER_LOGIN")
 T.eq(a.Floating.context.Theme.floatingEntryHeight,original,"startup addon imports cannot slip into Floating's later login construction")
 T.eq(a.UI,nil);T.eq(a.Group,nil);T.eq(a.Notes,nil)
 a,Fire=Start(account,prefs);Fire("ADDON_LOADED","LycheeGroup")
 T.eq(a.RuntimeTheme.selection.id,"reload.startup")
 Fire("PLAYER_LOGIN");T.eq(a.Floating.context.Theme.floatingEntryHeight,original+12)
 T.eq(a.API.Theme:GetStatus().reloadRequired,false)
end

-- Malformed persisted structures reach the startup fallback without losing raw data.
do
 local cases={
  {presets={bad={schema=1,id="bad",revision=1,values={[1]="x"}}},overrides={},activePreset="bad"},
  {presets={bad=false},overrides={},activePreset="bad"},
  {presets={bad={schema=1,id="bad",revision=1,values=false}},overrides={},activePreset="bad"},
  {presets={bad={schema=1,id="wrong",revision=1,values={}}},overrides={},activePreset="bad"},
  {presets={bad={schema=1,id="bad",revision=math.huge,values={}}},overrides={},activePreset="bad"},
  {presets={bad={schema=1,id="bad",revision=-math.huge,values={}}},overrides={},activePreset="bad"},
  {presets={bad={schema=1,id="bad",revision=0/0,values={}}},overrides={},activePreset="bad"},
  {presets={},overrides={[1]="x"}},
  {presets={},overrides=false},
  {presets=false,overrides={}},
  {presets={},overrides={},activePreset={"bad"}},
 }
 local cycle={};cycle.self=cycle
 cases[#cases+1]={presets={bad={schema=1,id="bad",revision=1,values={["utility.main.bad"]=cycle}}},overrides={},activePreset="bad"}
 for _,theme in ipairs(cases) do
  local rawPresets,rawOverrides,rawSelection=theme.presets,theme.overrides,theme.activePreset
  local package;if type(rawPresets)=="table" then package=rawPresets.bad end
  local account={uiConfig={schema=2,user={},presets={},imported={},theme=theme}}
  local f=Fixture("enUS",nil,account);local status=f.A.API.Theme:GetStatus()
  T.eq(status.current.id,false);T.eq(type(status.error),"string")
  T.eq(account.uiConfig.theme,theme);T.eq(theme.activePreset,rawSelection)
  if type(rawOverrides)~="table" then T.eq(account.uiConfigRecovery["uiConfig.theme.overrides"].value,rawOverrides)
  else T.eq(theme.overrides,rawOverrides) end
  if type(rawPresets)~="table" then T.eq(account.uiConfigRecovery["uiConfig.theme.presets"].value,rawPresets)
  else T.eq(theme.presets,rawPresets);T.eq(theme.presets.bad,package) end
  if rawSelection=="bad" then
   T.eq(f.A.API.Theme:Export(),nil)
   local list=f.A.API.Theme:List();T.eq(#list,1)
   if type(package)=="table" and type(package.revision)=="number" and (package.revision~=package.revision or package.revision==math.huge or package.revision==-math.huge) then
    T.eq(list[1].revision,nil,"invalid saved revision remains private repair data")
   end
   T.ok(f.A.API.Theme:Import({schema=1,id="bad",revision=2},{activate=true}))
   T.eq(f.A.API.Theme:GetStatus().next.error,nil)
   f=Reload(f);T.eq(f.A.API.Theme:GetStatus().current.id,"bad")
  end
 end
 for _,raw in ipairs({false,"broken theme"}) do
  local account={uiConfig={schema=2,user={},presets={},imported={},theme=raw}}
  local f=Fixture("enUS",nil,account)
  T.eq(type(f.A.RuntimeTheme.error),"string");T.eq(account.uiConfigRecovery["uiConfig.theme"].value,raw)
  local record=account.uiConfigRecovery["uiConfig.theme"]
  T.ok(f.A.API.Theme:Import({schema=1,id="repair.container",revision=1},{activate=true}))
  f=Reload(f);T.eq(f.A.RuntimeTheme.selection.id,"repair.container")
  T.eq(account.uiConfigRecovery["uiConfig.theme"],record)
 end
end

-- Persisted theme packages have the same UI-only preference boundary as imports.
do
 local blocked={['settings.autoJoin']=true,['settings.defaultSort']='rating',['settings.notesEnabled']=false,['settings.rememberFilters']=false}
 for key,value in pairs(blocked) do
  local package={schema=1,id='business.preference',revision=1,values={[key]=value}}
  local account={uiConfig={schema=2,theme={presets={[package.id]=package},overrides={},activePreset=package.id}}}
  local f=Fixture('enUS',nil,account);local a=f.A;local status=a.API.Theme:GetStatus()
  T.eq(status.current.id,false,'a stored theme cannot provide '..key)
  T.eq(type(status.error),'string');T.eq(account.uiConfig.theme.presets[package.id],package)
  T.eq(a:GetSetting(key:sub(10)),a.Configuration.definitions[key].default,'theme fallback preserves the business default')
  T.eq(a.API.Theme:Export(package.id),nil,'explicit export rejects a stored business preference')
  T.eq(a.API.Theme:Export(),nil,'selected export has the same preference boundary')
  T.ok(a.API.Theme:Activate(false))
  T.eq(a.API.Theme:Activate(package.id),false)
 end
 for _,storage in ipairs({'account','character'}) do
  for key,value in pairs({['settings.autoJoin']=true,['settings.fontScale']=130,['layout.window.width']=1400,['layout.unknown']=1}) do
   local overrides={[key]=value}
   local root={uiConfig={schema=2,theme={presets={},overrides=overrides}}}
   local f=Fixture('enUS',storage=='character' and root or nil,storage=='account' and root or nil)
   T.eq(f.A.RuntimeTheme.selection.id,false)
   T.eq(type(f.A.RuntimeTheme.error),'string',storage..' overrides reject nonvisual path '..key)
   T.eq(root.uiConfig.theme.overrides,overrides,'invalid overrides remain available for repair')
   T.eq(f.A:GetSetting('autoJoin'),false);T.eq(f.A:GetSetting('fontScale'),100)
  end
 end
 local f=Fixture('enUS');local a=f.A;local values={['settings.fontScale']=115,['layout.window.width']=1400,['theme.main.primary']={.2,.3,.4,1}}
 local package={schema=1,id='allowed.preferences',revision=1,values=values}
 a.db.uiConfig.theme.presets[package.id]=package;a.db.uiConfig.theme.activePreset=package.id
 f=Reload(f);a=f.A
 T.eq(a.RuntimeTheme.selection.id,package.id);T.eq(a:GetSetting('fontScale'),115)
 local exported=assert(a.API.Theme:Export());T.eq(exported.layout.window.width,1400)
 T.ok(a.API.Theme:Import(exported),'valid UI preferences and visuals still round trip')
end

-- Startup owns the selected immutable source; queries never recompile unselected data.
do
 local values={["theme.main.width"]=1450};local overrides={}
 local selected={schema=1,id="valid.references",revision=1,values=values}
 local unused={schema=1,id="unused.corrupt",revision=1,values=false}
 local theme={presets={[selected.id]=selected,[unused.id]=unused},overrides=overrides,activePreset=selected.id}
 local account={uiConfig={schema=2,presets={},imported={},theme=theme}}
 local f=Fixture("enUS",nil,account);local a=f.A;local api=a.API.Theme
 T.eq(a.RuntimeTheme.selection.id,selected.id);T.eq(a.RuntimeTheme.source.values,values)
 T.eq(a.RuntimeTheme.source.overrides.account,overrides);T.eq(theme.presets[unused.id],unused)
 T.eq(account.uiConfigRecovery,nil)
 local compile=a.Appearance.Compile;local checks=a.Configuration.CheckSerializable
 a.Appearance.Compile=function() error("queries must not recompile themes") end
 a.Configuration.CheckSerializable=function() error("queries must not revalidate saved tables") end
 for index=1,3 do
  T.eq(api:GetStatus().reloadRequired,false);T.eq(#api:List(),2)
  T.eq(a.Configuration:Get("settings.fontScale"),100)
 end
 a.Appearance.Compile=compile;a.Configuration.CheckSerializable=checks
 T.eq(api:Activate(unused.id),false);T.eq(theme.presets[unused.id],unused)
 T.ok(api:Import({schema=1,id=unused.id,revision=2}))
 T.eq(api:GetStatus().reloadRequired,false)
 local committed=account.uiConfig.theme
 f=Reload(f);T.eq(account.uiConfig.theme,committed);T.eq(committed.presets[selected.id],selected)
 T.eq(f.A.RuntimeTheme.source.values,values);T.eq(account.uiConfigRecovery,nil)
end

-- Element structure is checked even when unknown branches contain no leaves.
do
 local f=Fixture("enUS");local api=f.A.API.Theme
 local function Import(rule,id)
  return api:Import({schema=1,id="empty.structure",revision=1,appearance={main={elements={[id or "settings.row"]=rule}}}})
 end
 for _,rule in ipairs({{bogus={}},{base={bogus={}}},{states={bogus={}}},{states={hover={bogus={}}}},
  {variants={sample={bogus={}}}},{instances={sample={bogus={}}}},{base={label={bogus={}}}},
  {variants={sample={instances={}}}}}) do
  local ok,err=Import(rule);T.eq(ok,false);T.eq(type(err),"string")
 end
 T.eq(Import({instances={}},"host.settingsButton"),false)
 T.eq(#api:List(),0);T.eq(api:GetStatus().reloadRequired,false,"rejected empty branches never register partial definitions")
 T.ok(Import({base={},states={},variants={},instances={}}))
 T.ok(Import({variants={sample={variants={nested={base={},states={},variants={}}}}}}))
 T.ok(Import({base={label={}},states={hover={label={}}},variants={sample={base={},states={}}},instances={sample={base={},states={},variants={}}}}))
end
