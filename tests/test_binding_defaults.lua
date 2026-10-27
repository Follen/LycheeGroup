-- Standalone: lua tests/test_binding_defaults.lua (no game connection).
if not TestStubs then dofile('tests/stubs.lua') end
local checks=0
local function eq(actual,expected,message)
 checks=checks+1
 if T then T.eq(actual,expected,message)
 else assert(actual==expected,(message or 'value')..': expected '..tostring(expected)..', got '..tostring(actual)) end
end
local PATH='settings.toggleBinding'
local ACTION='LYCHEEGROUP_TOGGLE'
local function Start(account,character,native)
 TestStubs.Install({locale='zhCN'})
 _G.LycheeGroupDB=account or {};_G.LycheeGroupPrefsDB=character or {}
 for _,file in ipairs({'Locale','Theme/Defaults','Core','Configuration','Bindings'}) do assert(loadfile('addon/LycheeGroup/'..file..'.lua'))() end
 local a=LycheeGroup;local c=a.Configuration
 native=native or {scope=1,banks={[1]={map={},order={}},[2]={map={},order={}}},writes=0,saves=0}
 local function Bank() return native.banks[native.scope] end
 C_KeyBindings={GetBindingContextForAction=function(action) eq(action,ACTION);return 7 end}
 GetBindingAction=function(key,_,context) eq(context,7);return Bank().map[key] or '' end
 GetBindingKey=function(action,_,context)
  eq(context,7);local keys={}
  for _,key in ipairs(Bank().order) do if Bank().map[key]==action then keys[#keys+1]=key end end
  return unpack(keys)
 end
 GetBindingText=function(key) return key end
 GetCurrentBindingSet=function() return native.scope end
 InCombatLockdown=function() return native.combat end
 UnitGUID=function() return 'Player-defaults' end
 function native:Assign(key,action)
  local bank=Bank()
  for i=#bank.order,1,-1 do if bank.order[i]==key then table.remove(bank.order,i) end end
  bank.map[key]=action
  if action then bank.order[#bank.order+1]=key end
 end
 SetBinding=function(key,action,context)
  eq(context,7);native.writes=native.writes+1
  native.lastScope=native.scope
  if native.reject or native.rejectAt==native.writes then return false end
  native:Assign(key,action);TestStubs.FireEvent('UPDATE_BINDINGS');return true
 end
 SaveBindings=function(scope)
  eq(scope,native.scope);native.saves=native.saves+1
  TestStubs.FireEvent('UPDATE_BINDINGS')
  if native.rejectSave then return false end
 end
 function native:External(key,action) self:Assign(key,action);TestStubs.FireEvent('UPDATE_BINDINGS') end
 function native:Switch(scope) self.scope=scope;TestStubs.FireEvent('UPDATE_BINDINGS') end
 function native:Login() TestStubs.FireEvent('PLAYER_LOGIN') end
 function native:Key(key,scope) return self.banks[scope or self.scope].map[key] end
 function native:Pack(revision,key) return c:RegisterPreset('suite',revision,{[PATH]=key},{storage='account',default=true}) end
 return a,c,a.Bindings,native
end

do
 local a,c,b,n=Start()
 eq(c:GetSchema(PATH)[PATH].default,';');eq(c:Get(PATH),';');eq(c:GetSource(PATH).kind,'default')
 eq(next(a.db.uiConfig.user),nil,'reading leaves account user layer empty')
 eq(next(a.charPrefs.uiConfig.user),nil,'reading leaves character user layer empty')
 eq(n.writes,0,'reading never writes native bindings')
 eq(c:Set({[PATH]=true}),false);eq(c:Set({[PATH]=''}),false)
 eq(n:Pack(1,'ALT-G'),true);n:Login()
 eq(n:Key('ALT-G'),ACTION,'new install uses pack default');eq(n:Key(';'),nil)
 eq(a.db.uiConfig.user[PATH],nil,'auto default is not a user override')
 eq(c:GetSource(PATH).kind,'preset');eq(n.saves,1,'recursive native events do not duplicate saves')
 n:External('CTRL-G',ACTION)
 eq(a.db.uiConfig.user[PATH],nil,'adding a secondary binding does not select a primary override')
 eq(n:Pack(2,'ALT-H'),true)
 eq(n:Key('ALT-G'),nil);eq(n:Key('ALT-H'),ACTION);eq(n:Key('CTRL-G'),ACTION,'default upgrade retains secondary key')
 local first,second=b:Keys();eq(first,'ALT-H');eq(second,'CTRL-G')
 local account,character=a.db,a.charPrefs
 a,c,b,n=Start(account,character,n);n:Login()
 eq(n:Key('ALT-H'),ACTION,'reload retains automatic ownership')
 eq(n:Pack(3,'ALT-J'),true);eq(n:Key('ALT-J'),ACTION,'pack upgrade remains effective after reload')
 eq(n:Key('CTRL-G'),ACTION)
end

do
 local a,c,b,n=Start();n:Pack(1,'ALT-G');n:Login()
 eq(b:SetKey('ALT-G'),true,'recording the same key is explicit intent')
 eq(a.db.uiConfig.user[PATH],'ALT-G');eq(c:GetSource(PATH).kind,'user')
 n:Pack(2,'ALT-H');eq(n:Key('ALT-G'),ACTION);eq(n:Key('ALT-H'),nil)
 eq(b:SetKey('ALT-J'),true);eq(c:Get(PATH),'ALT-J')
 n:Pack(3,'ALT-K');eq(n:Key('ALT-J'),ACTION,'manual key wins over new author defaults')
 eq(c:Reset(PATH,{storage='account'}),true)
 eq(n:Key('ALT-J'),nil);eq(n:Key('ALT-K'),ACTION,'reset resumes default inheritance')
 eq(a.db.uiConfig.user[PATH],nil)
 n:External('ALT-K',nil)
 eq(c:Get(PATH),false,'external unbinding records explicit intent')
 n:Pack(4,'ALT-L');eq(n:Key('ALT-L'),nil,'pack upgrade preserves external unbinding')
 local account,character=a.db,a.charPrefs
 a,c,b,n=Start(account,character,n);n:Login();n:Pack(5,'ALT-M')
 eq(n:Key('ALT-M'),nil,'external unbinding survives reload')
 eq(c:Reset(PATH,{storage='account'}),true);eq(n:Key('ALT-M'),ACTION)
 n:External('ALT-M',nil);n:External('SHIFT-G',ACTION)
 eq(c:Get(PATH),'SHIFT-G','external Blizzard rebind records the observed primary')
 n:Pack(6,'ALT-N');eq(n:Key('SHIFT-G'),ACTION);eq(n:Key('ALT-N'),nil)
end

do
 local a,c,b,n=Start();n:Assign('SHIFT-G',ACTION);n:Pack(1,'ALT-G');n:Login()
 eq(n.writes,0,'existing Blizzard addon binding takes precedence')
 eq(a.db.uiConfig.user[PATH],nil,'observing an existing binding does not write user preferences')
 n:Pack(2,'ALT-H');eq(n.writes,0,'author upgrades preserve preexisting keys')
 local before=n.writes;eq(b:SetKey('bad key'),false);eq(n.writes,before,'invalid user input is rejected before any native write')
 eq(c:Set({[PATH]='ALT-J'},{storage='account'}),true)
 eq(n:Key('SHIFT-G'),nil);eq(n:Key('ALT-J'),ACTION,'explicit configuration user value can replace a preexisting primary')
 eq(c:Reset(PATH,{storage='account'}),true);eq(n:Key('ALT-H'),ACTION)
end

do
 local a,c,b,n=Start();n:Pack(1,'ALT-G');n:Login()
 n:Assign('ALT-G',nil);n:Assign('SHIFT-G',ACTION)
 local account,character=a.db,a.charPrefs
 a,c,b,n=Start(account,character,n);n:Login()
 eq(c:Get(PATH),'SHIFT-G','a native change while the addon was absent is detected after reload')
 n:Pack(2,'ALT-H');eq(n:Key('SHIFT-G'),ACTION);eq(n:Key('ALT-H'),nil)
end

do
 local a,c,b,n=Start();n:Assign('ALT-G','OPENALLBAGS');n:Pack(1,'ALT-G');n:Login()
 eq(n.writes,0,'new install never steals a conflicting key')
 eq(a.db.bindingDefaultScopes.account,nil,'conflict is not marked completed')
 n:External('ALT-G',nil);eq(n:Key('ALT-G'),ACTION,'freeing the conflict retries the default')
 n:Assign('ALT-H','OPENALLBAGS');n:Pack(2,'ALT-H')
 eq(n:Key('ALT-G'),ACTION,'failed upgrade retains previous automatic key')
 eq(n:Key('ALT-H'),'OPENALLBAGS')
 n:External('ALT-H',nil);eq(n:Key('ALT-H'),ACTION,'upgrade retries once the key is available')
 b:SetKey('SHIFT-G');n:Assign('ALT-J','OPENALLBAGS');n:Pack(3,'ALT-J')
 eq(c:Reset(PATH,{storage='account'}),true)
 eq(n:Key('SHIFT-G'),ACTION,'reset does not steal a conflicting default key')
 eq(n:Key('ALT-J'),'OPENALLBAGS')
 n:External('ALT-J',nil);eq(n:Key('ALT-J'),ACTION,'reset retains inheritance while a conflict is pending')
end

do
 local a,c,b,n=Start();n:Pack(1,false);n:Login()
 eq(n.writes,0,'false supplies no default key');eq(b.defaultKey,false)
 n:Pack(2,'ALT-G');eq(n:Key('ALT-G'),ACTION)
 n:External('CTRL-G',ACTION);n:Pack(3,false)
 eq(n:Key('ALT-G'),nil,'false withdraws the automatically owned primary')
 eq(n:Key('CTRL-G'),ACTION,'false retains a secondary Blizzard key')
 b:InitializeDefault();eq(n:Key('CTRL-G'),ACTION,'repeated false does not remove the preserved secondary')
end

do
 local a,c,b,n=Start();n:Pack(1,'ALT-G');n.combat=true;n:Login()
 eq(n.writes,0);eq(a.db.bindingDefaultScopes.account,nil,'combat does not complete initialization')
 n:Pack(2,'ALT-H');n.combat=false;TestStubs.FireEvent('PLAYER_REGEN_ENABLED')
 eq(n:Key('ALT-H'),ACTION,'combat exit uses the latest configured default')
 eq(#TestStubs.FramesWithEvent('PLAYER_REGEN_ENABLED'),0)
 n:Switch(2);eq(n:Key('ALT-H'),ACTION);eq(n.lastScope,2)
 n:Pack(3,'ALT-J');eq(n:Key('ALT-J'),ACTION);eq(n:Key('ALT-H',1),ACTION,'inactive account set is not changed')
 n:Switch(1);eq(n:Key('ALT-J'),ACTION,'switching scope updates only the newly active set')
 n.combat=true;local before=n.writes
 eq(c:Set({[PATH]='SHIFT-G'},{storage='account'}),true)
 eq(n.writes,before,'explicit configuration is deferred during combat')
 eq(b.defaultKey,'SHIFT-G','pending hint reads the current effective configuration')
 n.combat=false;TestStubs.FireEvent('PLAYER_REGEN_ENABLED')
 eq(n:Key('SHIFT-G'),ACTION,'deferred user configuration applies after combat')
end

do
 local a,c,b,n=Start();n:Pack(1,'ALT-G');n.reject=true;n:Login()
 eq(a.db.bindingDefaultScopes.account,nil,'rejected native write is not marked completed')
 n.reject=false;b:InitializeDefault();eq(n:Key('ALT-G'),ACTION,'rejected initialization can retry')
 n.rejectSave=true;n:Pack(2,'ALT-H')
 eq(n:Key('ALT-G'),ACTION,'failed save restores original binding');eq(n:Key('ALT-H'),nil)
 n.rejectSave=false;b:InitializeDefault();eq(n:Key('ALT-H'),ACTION,'failed save remains retryable')
 n.rejectAt=n.writes+2;n:Pack(3,'ALT-J')
 eq(n:Key('ALT-H'),ACTION,'partial write rollback preserves prior primary');eq(n:Key('ALT-J'),nil)
 n.rejectAt=nil;b:InitializeDefault();eq(n:Key('ALT-J'),ACTION)
end

do
 local account={bindingDefaultScopes={account=true,['character:Player-defaults']=true}}
 local a,c,b,n=Start(account);n:Pack(1,'ALT-G');n:Login();n:Switch(2)
 eq(n.writes,0,'legacy initialized scopes preserve intentionally empty bindings')
 n:Pack(2,'ALT-H');eq(n.writes,0,'legacy metadata does not invent automatic ownership')
 eq(account.bindingDefaultScopes.account,true)
 eq(account.bindingDefaultScopes['character:Player-defaults'],true)
 n:External('SHIFT-G',ACTION);eq(c:Get(PATH),'SHIFT-G','new user edits after legacy initialization are recorded')
 eq(a.charPrefs.uiConfig.user[PATH],'SHIFT-G','character binding edits use the character user layer')
end

print('binding defaults: '..checks..' checks passed')
