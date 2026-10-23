-- Configuration storage and provenance without a UI, library or business package.
local function Start(account,character)
 TestStubs.Install({locale="zhCN"})
 _G.LycheeGroupDB=account;_G.LycheeGroupPrefsDB=character
 Load.addon("LycheeGroup","Locale.lua")
 Load.addon("LycheeGroup","Core.lua")
 Load.addon("LycheeGroup","Configuration.lua")
 return LycheeGroup,LycheeGroup.Configuration
end
local function Reload(account,character)
 local a,c=Start(account,character);a:LoadDB();return a,c
end
local scale="settings.fontScale"
local function User(store,key) return store.uiConfig.user[key] end

-- First reads initialize storage, but never create user choices from filled defaults.
do
 local a,c=Start()
 T.eq(a.db,nil)
 T.eq(c:Get(scale),100)
 T.eq(a.db,LycheeGroupDB);T.eq(a.charPrefs,LycheeGroupPrefsDB)
 T.eq(a.db.uiConfig.schema,1);T.eq(a.charPrefs.uiConfig.schema,1)
 T.eq(next(a.db.uiConfig.user),nil);T.eq(next(a.charPrefs.uiConfig.user),nil)
 T.same(c:GetSource(scale),{kind="default"})
 T.eq(c:GetSchema()[scale].min,70)
 T.eq(c:GetSchema()["settings.schema"],nil)
 T.eq(c:GetSchema()["settings.notesHasRecords"],nil)
 T.eq(c:GetSchema()["settings.bindingDefaultScopes"],nil)
 local namespace=a.db.uiConfig
 c:Get(scale);c:GetSource(scale);c:GetSchema();c:ListPresets()
 T.eq(a.db.uiConfig,namespace);T.eq(next(namespace.user),nil)
 T.ok(c:ApplyPreset("sample",1,{[scale]=110},{storage="account"}))
 T.eq(a:GetSetting("fontScale"),110)
 T.eq(a.db.fontScale,100,"a preset does not materialize its value into the legacy field")
 T.eq(User(a.db,scale),nil)
end

-- Every actually saved old preference is an explicit choice, including false/default.
do
 local account={fontScale=100,notesEnabled=false,rememberFilters=false,defaultSort="rating",notesHasRecords=true,bindingDefaultScopes={x=true}}
 local character={defaultSort="members"}
 local a,c=Reload(account,character)
 T.eq(User(account,scale),100)
 T.eq(User(account,"settings.notesEnabled"),false)
 T.eq(User(character,"settings.rememberFilters"),false)
 T.eq(User(character,"settings.defaultSort"),"members")
 T.eq(User(account,"settings.defaultSort"),nil)
 T.eq(User(account,"settings.notesHasRecords"),nil)
 T.eq(account.notesHasRecords,true);T.eq(account.bindingDefaultScopes.x,true)
 T.ok(c:ApplyPreset("sample",2,{[scale]=120,["settings.notesEnabled"]=true},{storage="account"}))
 T.eq(c:Get(scale),100);T.eq(c:Get("settings.notesEnabled"),false)
 T.ok(c:Reset(scale,{storage="account"}));T.eq(c:Get(scale),120)
 T.eq(account.fontScale,nil)
 a,c=Reload(account,character)
 T.eq(c:Get(scale),120,"cleared legacy field is not imported again after reload")
 T.eq(User(account,scale),nil)
end

-- Same-value writes pin; full preset replacement, removal and reset preserve ownership.
do
 local a,c=Reload({},{});local notices={}
 a.OnConfigurationChanged=function(_,changes) notices[#notices+1]=changes end
 T.ok(c:ApplyPreset("sample","r1",{[scale]=110,["settings.uiScale"]=110},{storage="account"}))
 T.eq(#notices,1)
 T.ok(a:SetSetting("fontScale",110));T.eq(#notices,1,"pinning an unchanged value has no effects")
 T.eq(User(a.db,scale),110)
 T.ok(c:RegisterPreset("sample","r2",{[scale]=120},{storage="account"}))
 T.eq(c:Get(scale),110);T.eq(c:Get("settings.uiScale"),100,"removed package keys fall back")
 T.eq(#notices,2)
 T.ok(c:Reset(scale,{storage="account"}));T.eq(c:Get(scale),120)
 T.ok(c:RegisterPreset("sample","r1",{[scale]=105},{storage="account"}))
 T.eq(c:Get(scale),105,"explicit rollback revisions remain valid")
 T.ok(c:RemovePreset("sample",{storage="account"}))
 T.eq(c:Get(scale),100);T.eq(a.db.uiConfig.activePreset,nil)
 T.eq(#c:ListPresets(),0)
end

-- User and activation scope priorities are independent of where a package is stored.
do
 local a,c=Reload({},{});local account,character=a.db,a.charPrefs
 T.ok(c:ApplyPreset("base",1,{[scale]=105},{storage="account"}))
 T.ok(c:RegisterPreset("other",1,{[scale]=110},{storage="character"}))
 T.eq(c:Get(scale),105,"registering another package never activates it")
 T.ok(c:ActivatePreset("other",{storage="character"}));T.eq(c:Get(scale),110)
 T.ok(c:ActivatePreset(false));T.eq(c:Get(scale),100,"false explicitly selects built-in defaults")
 T.ok(c:RemovePreset("other"));T.eq(c:Get(scale),100,"removing unrelated session registration preserves built-in selection")
 T.ok(c:Set({[scale]=111},{storage="account"}));T.eq(c:Get(scale),111)
 T.ok(c:Set({[scale]=112},{storage="character"}));T.eq(c:Get(scale),112)
 T.ok(c:Set({[scale]=113}));T.eq(c:Get(scale),113)
 T.same(c:GetSource(scale),{kind="user",storage="session"})
 T.eq(account.fontScale,111,"persistent writes mirror only their matching legacy scope")
 T.eq(character.fontScale,nil)
 T.ok(c:Reset(scale));T.eq(c:Get(scale),112)
 T.ok(c:Reset(scale,{storage="character"}));T.eq(c:Get(scale),111)
 T.ok(c:Reset(scale,{storage="account"}));T.eq(c:Get(scale),100)
 a,c=Reload(account,character)
 T.eq(c:Get(scale),110,"session selection and user values disappear on reload")
 T.ok(c:RemovePreset("other",{storage="character"}));T.eq(c:Get(scale),105,"removing a character selection reveals the explicit account selection")
 T.same(c:GetSource(scale),{kind="preset",id="base",revision=1,storage="account",activationStorage="account"})
end

-- A session update can shadow a persistent selected definition without writing raw DB.
do
 local a,c=Reload({},{});local account,character=a.db,a.charPrefs
 T.ok(c:ApplyPreset("base",1,{[scale]=105},{storage="account"}))
 T.ok(c:RegisterPreset("base",2,{[scale]=120}))
 T.eq(c:Get(scale),120);T.eq(account.uiConfig.presets.base.revision,1)
 T.same(c:GetSource(scale),{kind="preset",id="base",revision=2,storage="session",activationStorage="account"})
 T.ok(c:ApplyPreset("base",3,{[scale]=125}))
 T.eq(account.uiConfig.presets.base.values[scale],105)
 T.eq(account.uiConfig.activePreset,"base");T.eq(character.uiConfig.activePreset,nil)
 T.ok(c:RemovePreset("base"));T.eq(c:Get(scale),105)
 a,c=Reload(account,character);T.eq(c:Get(scale),105)
end

-- Account values/packages travel across characters; character overrides do not.
do
 local account,first,second={},{},{}
 local a,c=Reload(account,first)
 T.ok(c:ApplyPreset("base",1,{[scale]=110,["settings.defaultSort"]="rating"},{storage="account"}))
 T.ok(c:Set({[scale]=115},{storage="account"}))
 T.ok(c:Set({[scale]=120},{storage="character"}))
 T.ok(a:SetSetting("defaultSort","members"))
 a,c=Reload(account,second)
 T.eq(c:Get(scale),115);T.eq(a:GetSetting("defaultSort"),"rating")
 T.ok(a:SetSetting("defaultSort","itemLevel"))
 a,c=Reload(account,first)
 T.eq(c:Get(scale),120);T.eq(a:GetSetting("defaultSort"),"members")
 T.eq(second.defaultSort,"itemLevel")
end

-- External batches validate before any mutation, including cyclic/nonserializable input.
do
 local a,c=Reload({},{});local notices=0
 a.OnConfigurationChanged=function() notices=notices+1 end
 local function Invalid(values)
  local ok,err=c:Set(values,{storage="account"})
  T.eq(ok,false);T.eq(type(err),"string");T.eq(c:Get(scale),100);T.eq(User(a.db,scale),nil)
 end
 Invalid({[scale]=110,unknown=1})
 Invalid({[scale]=110,["settings.uiScale"]=150})
 Invalid({[scale]=110,["settings.notesEnabled"]="false"})
 Invalid({[scale]=110,["settings.font"]=function() end})
 local cycle={};cycle.self=cycle;Invalid({[scale]=110,["settings.font"]=cycle})
 Invalid({[scale]=0/0});Invalid({[scale]=math.huge})
 T.eq(c:Set({[scale]=110},{storage=false}),false)
 T.eq(c:Reset({scale,"unknown"},{storage="account"}),false)
 T.eq(c:ApplyPreset("bad",{}, {[scale]=110},{storage="account"}),false)
 T.eq(c:ApplyPreset("bad","",{[scale]=110},{storage="account"}),false)
 T.eq(c:ApplyPreset("bad",1,{unknown=110},{storage="account"}),false)
 T.eq(c:ActivatePreset("missing"),false)
 T.eq(c:ExportPreset("bad"),nil)
 T.eq(#c:ListPresets(),0);T.eq(notices,0)
end

-- Visual/table leaves support independent copy ownership and actual old-field presence.
do
 local account={windowSize={width=1180},oldColor={.2,.3,.4,1}}
 local a,c=Reload(account,{})
 account.windowSize.height=700 -- a program-filled default after Bind is not an old user value.
 T.ok(c:RegisterDefinitions({
  ["layout.main.width"]={default=1000,type="number",min=800,storage="account",legacy={path={"windowSize","width"}}},
  ["layout.main.height"]={default=650,type="number",storage="account",legacy={path={"windowSize","height"}}},
  ["theme.main.color"]={default={1,1,1,1},type="color",storage="account",legacy={key="oldColor"}},
  ["layout.main.columns"]={default={a=.5,b=.5},type="table",storage="character"},
  ["layout.floating.position"]={default=false,type={"table","boolean"},storage="account",validate=function(value) return value~=true end},
 }))
 T.eq(c:Get("layout.main.width"),1180);T.eq(c:Get("layout.main.height"),650)
 T.eq(User(account,"layout.main.height"),nil)
 local color=c:Get("theme.main.color");color[1]=.9
 T.eq(c:Get("theme.main.color")[1],.2);T.eq(account.oldColor[1],.2)
 T.ok(c:ApplyPreset("visual",1,{["theme.main.color"]={0,0,0,1},["layout.main.height"]=680}))
 T.eq(c:Get("layout.main.height"),680);T.eq(c:Get("theme.main.color")[1],.2)
 T.ok(c:Set({["layout.main.width"]=1200},{storage="account"}));T.eq(account.windowSize.width,1200)
 T.ok(c:Reset("layout.main.width",{storage="account"}));T.eq(account.windowSize.width,nil)
 local columns={a=.3,b=.7}
 T.ok(c:Set({["layout.main.columns"]=columns}));columns.a=.9
 T.eq(c:Get("layout.main.columns").a,.3)
 T.eq(c:Set({["theme.main.color"]={1.1,0,0}}),false)
 T.ok(c:ImportLegacy({["layout.main.columns"]={a=.4,b=.6}},{storage="character"}))
 T.eq(User(a.charPrefs,"layout.main.columns").a,.4)
 T.ok(c:ImportLegacy({["layout.main.columns"]={a=.8,b=.2}},{storage="character"}))
 T.eq(User(a.charPrefs,"layout.main.columns").a,.4,"legacy import is once per registered leaf")
 local schema=c:GetSchema();schema["theme.main.color"].default[1]=0
 T.eq(c:GetSchema()["theme.main.color"].default[1],1)
 T.same(c:GetSchema()["layout.floating.position"].type,{"table","boolean"})
 T.ok(c:ApplyPreset("position",1,{["layout.floating.position"]={x=10,y=20}}))
 T.ok(c:Set({["layout.floating.position"]=false},{storage="account"}))
 T.eq(c:Get("layout.floating.position"),false,"an explicit false masks preset position data")
 T.eq(c:Set({["layout.floating.position"]=true}),false)
 T.eq(c:Set({["layout.floating.position"]="center"}),false)
 local preset=c:ExportPreset("visual");preset.values["theme.main.color"][1]=.7
 T.eq(c:ExportPreset("visual").values["theme.main.color"][1],0)
end

-- One batch produces one effective change set and one call to each shared lifecycle.
do
 local a,c=Reload({},{});local fontCalls,floatingCalls,notesCalls,minimapCalls,notices=0,0,0,0,{}
 a.Fonts={Apply=function() fontCalls=fontCalls+1 end}
 a.Floating={UpdateSettings=function() floatingCalls=floatingCalls+1 end}
 a.Notes={SyncEnabled=function() notesCalls=notesCalls+1 end}
 a.Minimap={UpdateSettings=function() minimapCalls=minimapCalls+1 end}
 a.OnConfigurationChanged=function(_,changes) notices[#notices+1]=changes end
 T.ok(c:Set({[scale]=110,["settings.font"]="other.ttf",["settings.floatingScale"]=120,["settings.floatingLocked"]=true,["settings.notesEnabled"]=false,["settings.reminders"]="off"}))
 T.eq(fontCalls,1);T.eq(floatingCalls,1);T.eq(notesCalls,1);T.eq(#notices,1)
 T.same(notices[1][scale],{previous=100,value=110})
 T.ok(c:Set({[scale]=110,["settings.font"]="other.ttf"}));T.eq(fontCalls,1);T.eq(#notices,1)
 T.ok(c:Set({[scale]=105},{storage="account"}));T.eq(fontCalls,1,"hidden lower-priority edits do not refresh consumers")
 T.ok(c:Reset(scale));T.eq(fontCalls,2);T.eq(#notices,2)
 T.ok(c:Set({["settings.minimapAngle"]=180}));T.eq(minimapCalls,1)
 T.ok(c:Set({["settings.minimap"]=false,["settings.minimapAngle"]=120}));T.eq(minimapCalls,2,"one minimap refresh per batch")
end

-- Public API is available without loading UI, and all unrelated business DBs retain identity.
do
 local account,character={customBusiness={keep=true}},{customCharacter={keep=true}}
 local a,c=Start(account,character)
 local group,groupChar,notes={history={1}},{filters={x=2}},{records={one={reason="keep"}}}
 LycheeGroupGroupDB,LycheeGroupGroupCharDB,LycheeGroupNotesDB=group,groupChar,notes
 local loads=0;a.Ensure=function() loads=loads+1 end
 a.Floating={frame={},UpdateSettings=function() end};Load.addon("LycheeGroup","API.lua")
 local api=a.API.Configuration
 T.eq(api.version,1);T.eq(a.API.Floating.version,1)
 T.eq(api:Get(scale),100)
 T.ok(api:Set({[scale]=115}));T.eq(api:Get(scale),115);T.eq(account.fontScale,100)
 T.eq(a.API.Floating:IsAvailable(),true)
 T.ok(api:Set({["settings.floating"]=false}));T.eq(account.floating,true)
 T.eq(a.API.Floating:IsAvailable(),false,"floating integration reads effective session preferences")
 T.eq(loads,0);T.eq(a.UI,nil);T.eq(a.Group,nil);T.eq(a.Notes,nil)
 T.eq(a.db,account);T.eq(a.charPrefs,character)
 T.eq(account.customBusiness.keep,true);T.eq(character.customCharacter.keep,true)
 T.eq(LycheeGroupGroupDB,group);T.eq(LycheeGroupGroupCharDB,groupChar);T.eq(LycheeGroupNotesDB,notes)
 T.eq(notes.records.one.reason,"keep")
 T.eq(account.uiConfig.session,nil);T.eq(character.uiConfig.session,nil)
 a,c=Reload(account,character);T.eq(c:Get(scale),100)
end

-- Final-value validation is transactional for writes, package changes and resets.
do
 local a,c=Reload({},{});local size,delta="visual.size","visual.delta"
 T.ok(c:RegisterDefinitions({
  [size]={default=12,type="number",min=0,exclusiveMin=true,storage="account",legacy={key="oldSize"}},
  [delta]={default=0,type="number",storage="account",legacy={key="oldDelta"}},
 }))
 T.eq(c:GetSchema()[size].exclusiveMin,true)
 T.eq(c:Set({[size]=0}),false)
 local notices=0
 a.OnConfigurationChanged=function() notices=notices+1 end
 a.ValidateConfiguration=function() return c:Get(size)+c:Get(delta)>0,"font size plus delta must be positive" end
 local function Rejected(operation)
  local root=a.db.uiConfig;local users,presets,imported=root.user,root.presets,root.imported
  local oldSize,oldDelta=a.db.oldSize,a.db.oldDelta;local beforeNotices=notices
  local ok,err=operation();T.eq(ok,false);T.eq(type(err),"string")
  T.eq(a.db.uiConfig,root);T.eq(c.stores.account,root)
  T.eq(root.user,users);T.eq(root.presets,presets);T.eq(root.imported,imported)
  T.eq(a.db.oldSize,oldSize);T.eq(a.db.oldDelta,oldDelta);T.eq(notices,beforeNotices)
 end
 Rejected(function() return c:Set({[size]=1,[delta]=-2,[scale]=110},{storage="account"}) end)
 T.eq(c:Get(scale),100);T.eq(User(a.db,scale),nil)
 Rejected(function() return c:ApplyPreset("invalid",1,{[size]=1,[delta]=-2},{storage="account"}) end)
 T.eq(c:ExportPreset("invalid"),nil)
 T.ok(c:RegisterPreset("inactive",1,{[size]=1,[delta]=-2},{storage="account"}))
 Rejected(function() return c:ActivatePreset("inactive",{storage="account"}) end)
 T.eq(a.db.uiConfig.activePreset,nil)
 T.ok(c:ApplyPreset("valid",1,{[size]=10},{storage="account"}))
 Rejected(function() return c:RegisterPreset("valid",2,{[size]=1,[delta]=-2},{storage="account"}) end)
 T.eq(c:ExportPreset("valid").revision,1)
 T.ok(c:Set({[size]=3},{storage="account"}))
 T.ok(c:ApplyPreset("under",1,{[size]=1,[delta]=-2},{storage="account"}))
 Rejected(function() return c:Reset(size,{storage="account"}) end)
 T.eq(User(a.db,size),3);T.eq(a.db.oldSize,3)
 T.ok(c:RemovePreset("under",{storage="account"}));T.ok(c:Reset(size,{storage="account"}))
 T.ok(c:ApplyPreset("large",1,{[size]=20},{storage="account"}))
 T.ok(c:Set({[delta]=-15},{storage="account"}))
 Rejected(function() return c:RemovePreset("large",{storage="account"}) end)
 Rejected(function() return c:ActivatePreset(false,{storage="account"}) end)
 T.eq(a.db.uiConfig.activePreset,"large")
 T.eq(c:Get(size),20);T.eq(c:Get(delta),-15)
 a.ValidateConfiguration=function() error("validation failed") end
 Rejected(function() return c:Set({[scale]=110},{storage="account"}) end)
 T.eq(c:Get(scale),100)
end
