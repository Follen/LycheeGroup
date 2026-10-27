-- Read-only authoring and current-startup appearance data.
local Fixture=dofile("tests/ui_fixture.lua")
local function Theme(id,appearance) return {schema=1,id=id,revision=1,appearance=appearance} end

do
 local f=Fixture("enUS");local a=f.A;local api=a.API.Appearance
 T.eq(api.version,2)
 for _,name in ipairs({"Set","Reset","SetElement","SetElements","ResetElement","ResetElements","SetUtilities","ResetUtilities","GetElement","GetElementInfo"}) do T.eq(api[name],nil) end
 T.eq(api:GetSchema("missing"),nil);T.eq(api:Get("missing"),nil)
 local schema=api:GetSchema("main")
 T.eq(schema.font,nil);T.eq(schema.labelFontSize.role,"label")
 local original=schema.labelFontSize.aliases[1];schema.labelFontSize.aliases[1]="changed"
 T.eq(api:GetSchema("main").labelFontSize.aliases[1],original)
 local colors=api:GetColors("main");local red=colors.primary[1];colors.primary[1]=0
 T.eq(api:GetColors("main").primary[1],red)
 local styles=api:GetStyleSchema("main");T.eq(type(styles["button.base.root.height"].types),"table")
 styles["button.base.root.height"].types[1]="changed"
 T.eq(api:GetStyleSchema("main")["button.base.root.height"].types[1],"number")
 local field=api:GetElementSchema("main","settings.row",{"settings.row.base.label.alpha"})
 T.eq(field["settings.row.base.label.alpha"].max,1)
 T.eq(a.UI.frame,nil);T.eq(next(a.db.uiConfig.user),nil)
end

-- Defaults remain an editable template, independent of current/user values.
do
 local f=Fixture("enUS");local api=f.A.API.Theme
 local defaults=api:GetDefaults();T.eq(defaults.schema,1);T.eq(defaults.settings.fontScale,100)
 T.eq(defaults.appearance.main.tokens.memberNameFont,f.A.StyleDefaults.main.memberNameFont)
 local original=defaults.appearance.main.tokens.labelFontSize
 defaults.appearance.main.tokens.labelFontSize=999
 T.eq(api:GetDefaults().appearance.main.tokens.labelFontSize,original)
 T.eq(#api:List(),0);T.eq(api:GetStatus().reloadRequired,false)
end

-- Keyed declarations retain typed keys and are applied only to their real bind.
do
 local definition=Theme("appearance.rules",{main={utilities={emphasis={base={label={color="warning"}}}},elements={
  ["settings.row"]={classes="emphasis",base={label={alpha=.8}},instances={
   [7]={base={label={alpha=.4}}},["7"]={base={label={alpha=.6}}},["玩家.A%角色"]={base={label={fontSize=19}}},
  }},
 }}})
 local f=Fixture("enUS",nil,nil,definition);local api=f.A.API.Appearance
 T.eq(api:GetElementRules("main","settings.row",7).base.label.alpha,.4)
 T.eq(api:GetElementRules("main","settings.row","7").base.label.alpha,.6)
 T.eq(api:GetElementRules("main","settings.row","玩家.A%角色").base.label.fontSize,19)
 T.eq(api:GetElementRules("main","settings.row","other").base.label.alpha,.8)
 local rules=api:GetElements("main");rules["settings.row"].base.label.alpha=0
 T.eq(api:GetElementRules("main","settings.row","other").base.label.alpha,.8)
 T.eq(api:GetUtilities("main").emphasis.base.label.color,"warning")
end

-- Typography aliases and old media compatibility are resolved at startup.
do
 local definition=Theme("appearance.aliases",{main={tokens={font14=17,media="LegacyAssets/"}},floating={tokens={media="GenericAssets/",productMedia="ProductAssets/"}}})
 local f=Fixture("enUS",nil,nil,definition);local api=f.A.API.Appearance
 T.eq(api:GetTypography("main").label.fontSize,17)
 T.eq(api:Get("main").memberNameFont,f.A.StyleDefaults.main.memberNameFont)
 T.eq(api:Get("main").productMedia,"LegacyAssets/")
 T.eq(api:Get("floating").productMedia,"ProductAssets/")
 T.eq(api:Get("floating").media,"GenericAssets/")
end

-- Narrow public projections preserve the full getter/schema result, including
-- derived colors, aliases and startup isolation while another theme is pending.
local function CheckProjections(f,label)
 local a,library=f.A,LycheeUI;local api=a.API.Appearance
 for _,scope in ipairs({"main","floating"}) do
  local theme=api:Get(scope);local expectedType,expectedColors={},{}
  for role,fields in pairs(library.TextStyles) do expectedType[role]={fontSize=theme[fields.fontSize],lineHeight=theme[fields.lineHeight]} end
  for key in pairs(library:GetColorSchema(a.StyleDefaults[scope])) do expectedColors[key]=theme[key] end
  local get,schema=api.Get,library.GetThemeSchema
  api.Get=function() error("narrow projection cloned the complete theme") end
  library.GetThemeSchema=function() error("narrow projection built the complete schema") end
  local ok,typography,colors=pcall(function() return api:GetTypography(scope),api:GetColors(scope) end)
  api.Get,library.GetThemeSchema=get,schema
  if not ok then error(typography,0) end
  T.same(typography,expectedType,label.." "..scope.." typography")
  T.same(colors,expectedColors,label.." "..scope.." exact color key domain and values")
  typography.label.fontSize=-1;colors.primary[1]=-1
  T.same(api:GetTypography(scope),expectedType,"nested typography returns are isolated")
  T.same(api:GetColors(scope),expectedColors,"nested color returns are isolated")
  T.ok(colors.primary~=colors.accent,"aliased source colors still return separate arrays")
 end
 T.eq(f.U.frame,nil,"read-only projections do not create the window")
end

do
 local seed=Fixture("enUS")
 local imported=Theme("appearance.projections",{
  main={tokens={primary={.2,.4,.6},labelFontSize=19,bodyLineHeight=27}},
  floating={tokens={surface={.1,.2,.3,.4},bodyFontSize=18}},
 })
 for _,case in ipairs({{"default"},{"frosted",seed.A.BuiltinThemes["lycheegroup.frosted"]},{"imported",imported}}) do
  local f=Fixture("enUS",nil,nil,case[2]);local api=f.A.API.Appearance
  CheckProjections(f,case[1])
  for _,method in ipairs({"GetTypography","GetColors"}) do
   for _,scope in ipairs({false,"missing"}) do
    local value,err=api[method](api,scope)
    T.eq(value,nil);T.eq(err,"unknown appearance scope: "..tostring(scope))
   end
   local value,err=api[method](api)
   T.eq(value,nil);T.eq(err,"unknown appearance scope: nil")
  end
  local beforeType,beforeColors={},{}
  for _,scope in ipairs({"main","floating"}) do beforeType[scope]=api:GetTypography(scope);beforeColors[scope]=api:GetColors(scope) end
  T.ok(f.A.API.Theme:Import(Theme("appearance.pending",{
   main={tokens={primary={.7,.2,.1,1},labelFontSize=23}},
   floating={tokens={surface={.6,.5,.4,.3},bodyFontSize=20}},
  }),{activate=true}))
  T.eq(f.A.API.Theme:GetStatus().reloadRequired,true)
  CheckProjections(f,case[1].." pending")
  for _,scope in ipairs({"main","floating"}) do
   T.same(api:GetTypography(scope),beforeType[scope],"pending typography waits for reload")
   T.same(api:GetColors(scope),beforeColors[scope],"pending colors wait for reload")
  end
  f=Fixture("enUS",f.A.charPrefs,f.A.db)
  CheckProjections(f,case[1].." reloaded")
  T.eq(f.A.API.Appearance:GetTypography("main").label.fontSize,23)
  T.same(f.A.API.Appearance:GetColors("main").primary,{.7,.2,.1,1})
  T.same(f.A.API.Appearance:GetColors("floating").surface,{.6,.5,.4,.3})
 end
end

-- Find-only changes have no Settings consumer, even after that page is built.
-- Real settings retain their normal visible/hidden synchronization and reopening.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale,nil,{reduceMotion=true});local a,u,c=f.A,f.U,f.A.Configuration
 a:Open("settings");local settings=u.pages.settings;local sync=settings.Sync;local syncs=0
 settings.Sync=function(self,...) syncs=syncs+1;return sync(self,...) end
 local key="settings.find.categories.seasonDungeon.minRating"
 local searches=0;local search=f.G.Search.Search
 f.G.Search.Search=function(...) searches=searches+1;return search(...) end
 T.ok(c:Set({[key]=100},{storage="character"}));T.eq(syncs,0,"visible settings has no Find-leaf dependency")
 a:Open("find");syncs=0
 for i=1,20 do T.ok(c:Set({[key]=100+i},{storage="character"})) end
 T.eq(syncs,0,"Find edits do not synchronize the hidden Settings page")
 T.eq(searches,0,"configuration changes do not start a native search")
 T.eq(f.G.filters.minRating,120)
 T.ok(c:Reset(key,{storage="character"}));T.eq(syncs,0)
 T.eq(f.G.filters.minRating,nil)
 T.ok(c:Set({["settings.rememberFilters"]=false}));T.eq(syncs,1)
 T.eq(settings.controls.rememberFilters.widget.value,false,"hidden genuine settings still synchronize")
 T.ok(c:ApplyPreset("sync.batch",1,{[key]=250,["settings.defaultSort"]="rating"}))
 T.eq(syncs,2,"mixed Find/settings package changes synchronize Settings once")
 T.eq(settings.controls.defaultSort.widget.value,"rating")
 T.ok(c:RegisterPreset("sync.batch",2,{[key]=260,["settings.defaultSort"]="newest"}))
 T.eq(syncs,3);T.eq(settings.controls.defaultSort.widget.value,"newest")
 T.eq(f.G.filters.minRating,260,"remember-off still resolves package defaults")
 a:Open("settings");T.eq(settings.controls.rememberFilters.widget.value,false)
 T.eq(settings.controls.defaultSort.widget.value,"newest")
 T.eq(searches,0)
end

-- Dynamic visual fields belong to the startup Theme boundary, never imported
-- live-preference markers. Rejected live writes and valid Theme operations
-- both preserve the Configuration migration namespaces.
do
 local f=Fixture("enUS");local a,c=f.A,f.A.Configuration
 local markers={}
 for _,storage in ipairs({"account","character","session"}) do
  markers[storage]={reference=c.stores[storage].imported,value=c:CopyValue(c.stores[storage].imported)}
 end
 for _,key in ipairs({"theme.main.primary","style.main.button.base.root.height","element.main.settings.row.base.label.alpha"}) do
  T.ok(a.Appearance:GetField(key));T.eq(c.definitions[key],nil)
  for _,storage in ipairs({"account","character","session"}) do
   T.eq(c:Set({[key]=1},{storage=storage}),false)
   T.eq(c:Reset(key,{storage=storage}),false)
   T.eq(c.stores[storage].imported,markers[storage].reference)
   T.same(c.stores[storage].imported,markers[storage].value)
  end
 end
 T.ok(a.API.Theme:Import(Theme("marker.visual",{main={tokens={primary={.2,.3,.4,1}}}}),{activate=true}))
 T.ok(a.API.Theme:ResetOverrides("main",{"theme.main.primary"},{storage="account"}))
 for _,storage in ipairs({"account","character","session"}) do
  T.eq(c.stores[storage].imported,markers[storage].reference)
  T.same(c.stores[storage].imported,markers[storage].value)
 end
end
