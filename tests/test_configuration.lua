-- Configuration storage and provenance without a UI, library or business package.
local function Start(account,character)
 TestStubs.Install({locale="zhCN"})
 _G.LycheeGroupDB=account;_G.LycheeGroupPrefsDB=character
 Load.addon("LycheeGroup","Locale.lua")
 Load.addon("LycheeGroup","Theme/Defaults.lua");Load.addon("LycheeGroup","Core.lua")
 Load.addon("LycheeGroup","Configuration.lua")
 return LycheeGroup,LycheeGroup.Configuration
end

local function Reload(account,character)
 local a,c=Start(account,character);a:LoadDB();return a,c
end
local scale="settings.fontScale"
local function User(store,key) return store.uiConfig.user[key] end

-- A scoped schema query copies only selected leaves and preserves copy ownership.
do
 local a,c=Reload({},{})
 local selected=c:GetSchema({scale,"settings.notesEnabled"})
 T.eq(selected[scale].default,100);T.eq(selected["settings.notesEnabled"].default,true)
 T.eq(selected["settings.font"],nil)
 selected[scale].default=10
 T.eq(c:GetSchema(scale)[scale].default,100)
 T.eq(c:GetSchema("missing").missing,nil)
 T.eq(c:GetSchema(false),nil)
end

-- First reads initialize storage, but never create user choices from filled defaults.
do
 local a,c=Start()
 T.eq(a.db,nil)
 T.eq(c:Get(scale),100)
 T.eq(a.db,LycheeGroupDB);T.eq(a.charPrefs,LycheeGroupPrefsDB)
 T.eq(a.db.uiConfig.schema,2);T.eq(a.charPrefs.uiConfig.schema,2)
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

-- Layout preferences retain serialization, legacy presence and copy ownership.
do
 local account={windowSize={width=1180},oldColor={.2,.3,.4,1}}
 local a,c=Reload(account,{})
 account.windowSize.height=700
 T.ok(c:RegisterDefinitions({
  ["layout.main.width"]={default=1000,type="number",min=800,storage="account",legacy={path={"windowSize","width"}}},
  ["layout.main.height"]={default=650,type="number",storage="account",legacy={path={"windowSize","height"}}},
  ["layout.sampleColor"]={default={1,1,1,1},type="color",storage="account",legacy={key="oldColor"}},
  ["layout.main.columns"]={default={a=.5,b=.5},type="table",storage="character"},
 }))
 T.eq(c:Get("layout.main.width"),1180);T.eq(c:Get("layout.main.height"),650)
 T.eq(User(account,"layout.main.height"),nil)
 local color=c:Get("layout.sampleColor");color[1]=.9
 T.eq(c:Get("layout.sampleColor")[1],.2);T.eq(account.oldColor[1],.2)
 T.ok(c:ApplyPreset("layout",1,{["layout.main.height"]=680}))
 T.eq(c:Get("layout.main.height"),680)
 T.ok(c:Set({["layout.main.width"]=1200},{storage="account"}));T.eq(account.windowSize.width,1200)
 T.ok(c:Reset("layout.main.width",{storage="account"}));T.eq(account.windowSize.width,nil)
 local columns={a=.3,b=.7};T.ok(c:Set({["layout.main.columns"]=columns}));columns.a=.9
 T.eq(c:Get("layout.main.columns").a,.3)
 T.eq(c:Set({["layout.sampleColor"]={1.1,0,0}}),false)
 local schema=c:GetSchema();schema["layout.sampleColor"].default[1]=0
 T.eq(c:GetSchema("layout.sampleColor")["layout.sampleColor"].default[1],1)
end

-- A rejected visual leaf cannot partially apply a valid immediate setting.
do
 local a,c=Reload({},{});local users,presets=c.stores.account.user,c.stores.account.presets
 for _,key in ipairs({"theme.main.primary","style.main.button.base.root.height","element.main.settings.row.base.label.alpha","utility.main.notice"}) do
  T.eq(c:Set({[scale]=115,[key]=1},{storage="account"}),false)
  T.eq(c:RegisterPreset("visual",1,{[scale]=115,[key]=1},{storage="account"}),false)
  T.eq(c:Get(key),nil);T.eq(c:GetSchema(key)[key],nil)
 end
 T.eq(c:Get(scale),100);T.eq(c.stores.account.user,users);T.eq(c.stores.account.presets,presets)
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
 T.eq(api.version,2);T.eq(a.API.Floating.version,1)
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

-- Public schema keeps descriptive style metadata without sharing mutable arrays.
do
 local a,c=Reload({},{});local key="layout.label"
 T.ok(c:RegisterDefinitions({[key]={default=14,type="number",storage="account",key="labelFontSize",role="label",unit="font",canonical="labelFontSize",representative="font14",aliases={"font14","font13","font15"},aliasOf="labelFontSize",group="text"}}))
 local field=c:GetSchema()[key]
 T.eq(field.key,"labelFontSize");T.eq(field.role,"label");T.eq(field.unit,"font")
 T.eq(field.canonical,"labelFontSize");T.eq(field.representative,"font14")
 T.eq(field.aliasOf,"labelFontSize");T.eq(field.group,"text")
 T.same(field.aliases,{"font14","font13","font15"})
 field.aliases[1]="changed"
 T.eq(c:GetSchema()[key].aliases[1],"font14")
end

-- Native regions do not inherit dimensions from a parent without sizing constraints.
do
 local S=dofile("tests/ui_stubs.lua")
 local parent=S.New("Frame");parent:SetSize(200,100)
 local single=S.New("Frame",nil,parent);single:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
 T.eq(single:GetWidth(),0);T.eq(single:GetHeight(),0)
 local fill=S.New("Frame",nil,parent);fill:SetSize(30,20);fill:SetAllPoints(parent)
 T.eq(fill:GetWidth(),200);T.eq(fill:GetHeight(),100)
 local inset=S.New("Frame",nil,parent)
 inset:SetPoint("TOPLEFT",parent,"TOPLEFT",10,-5);inset:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-20,15)
 T.eq(inset:GetWidth(),170);T.eq(inset:GetHeight(),80)
 local icon=S.New("Frame",nil,parent);icon:SetSize(20,20);icon:SetPoint("LEFT",parent,"LEFT",10,0)
 local adjacent=S.New("Frame",nil,parent)
 adjacent:SetPoint("LEFT",icon,"RIGHT",4,0);adjacent:SetPoint("RIGHT",parent,"RIGHT",-8,0)
 T.eq(adjacent:GetWidth(),158)
 local text=S.New("FontString",nil,parent);text:SetText("abc")
 T.near(text:GetWidth(),23.1,.001);T.near(text:GetHeight(),16.8,.001)
end
