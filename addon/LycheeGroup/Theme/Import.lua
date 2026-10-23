-- Persistent themes are selected for the next login/reload, never applied live.
local A=_G.LycheeGroup
local Configuration=A.Configuration
local Service={}
A.ThemeService=Service
local API={version=2};A.API=A.API or {};A.API.Theme=API
local function HasPrefix(path)
 if path=="theme" then return true end
 local scope=path:match("^theme%.([^.]+)$");if scope then return A.StyleDefaults[scope]~=nil end
 local prefix=path.."."
 for key in pairs(Configuration.definitions) do if key:sub(1,#prefix)==prefix then return true end end
 return false
end
local function RecipeBranch(scope,path)
 for _,root in ipairs({_G.LycheeUI.ComponentRecipes,A.ThemeDefaults.appearance[scope].components or {}}) do
  local value=root
  for part in path:gmatch("[^.]+") do value=type(value)=="table" and value[part] or nil;if value==nil then break end end
  if type(value)=="table" then return true end
 end
 return false
end

local function Copy(value)
 if type(value)~="table" then return value end
 local result={};for key,item in pairs(value) do result[key]=Copy(item) end;return result
end
function API:GetDefaults()
 local defaults=A.ThemeDefaults
 local result={schema=defaults.schema,id=defaults.id,revision=defaults.revision,
  settings=Copy(defaults.settings),layout=Copy(defaults.layout),appearance={}}
 for scope,source in pairs(defaults.appearance) do
  local appearance={};result.appearance[scope]=appearance
  local theme=_G.LycheeUI.ResolveTheme({},A.StyleDefaults[scope])
  appearance.tokens={}
  -- Export editable bases, not a snapshot which pins every derived color or alias.
  for token,field in pairs(A.API.Appearance:GetSchema(scope)) do
   if not field.aliasOf and not field.derivedFrom then appearance.tokens[token]=Copy(theme[token]) end
  end
  appearance.components=Copy(_G.LycheeUI.ResolveRecipes(A.ThemeDefaults.appearance[scope].components))
  for _,recipe in pairs(appearance.components) do recipe.slotKinds=nil end
  if source.elements then
   appearance.elements={}
   for id,element in pairs(source.elements) do
    local rule={}
    for _,branch in ipairs({"classes","base","states","variants","instances"}) do if element[branch]~=nil then rule[branch]=Copy(element[branch]) end end
    if next(rule) then appearance.elements[id]=rule end
   end
  end
  if source.utilities then appearance.utilities=Copy(source.utilities) end
 end
 return result
end

local function Flatten(value,path,values)
 if A.Appearance:GetField(path) or Configuration.definitions[path] then values[path]=value;return true end
 if not HasPrefix(path) then return false,"unknown theme configuration path: "..path end
 if type(value)~="table" then return false,path.." must be a table" end
 for key,item in pairs(value) do
  if type(key)~="string" then return false,path.." requires named fields" end
  local ok,err=Flatten(item,path.."."..key,values)
  if not ok then return false,err end
 end
 return true
end
local function RecipeValues(value,scope,path,values)
 local full="style."..scope..(path~="" and "."..path or "")
 if path:match("%.slotKinds$") then return false,"slotKinds declares product objects and cannot be imported as a style override" end
 local field=A.Appearance:GetField(full)
 if field then
  values[full]=value
  return true
 end
 if type(value)~="table" then return false,"unknown theme configuration path: "..full end
 if next(value)==nil and path~="" and not RecipeBranch(scope,path) then return false,"unknown theme configuration path: "..full end
 for key,item in pairs(value) do
  if type(key)~="string" then return false,full.." requires named fields" end
  local ok,err=RecipeValues(item,scope,path=="" and key or path.."."..key,values)
  if not ok then return false,err end
 end
 return true
end
local function Values(definition)
 if type(definition)~="table" or definition.schema~=1 then return nil,"theme definition requires schema=1" end
 local fields={schema=true,id=true,revision=true,appearance=true,settings=true,layout=true}
 for key in pairs(definition) do if not fields[key] then return nil,"unknown theme definition field: "..tostring(key) end end
 local values={}
 if definition.appearance~=nil then
  if type(definition.appearance)~="table" then return nil,"appearance must be a scope table" end
  for scope,appearance in pairs(definition.appearance) do
   if not A.StyleDefaults[scope] then return nil,"unknown appearance scope: "..tostring(scope) end
   if type(appearance)~="table" then return nil,"appearance."..scope.." must be a table" end
   for kind,items in pairs(appearance) do
    local prefix=kind=="tokens" and "theme." or kind=="components" and "style." or kind=="elements" and "element." or kind=="utilities" and "utility."
    if not prefix then return nil,"unknown appearance field: "..tostring(kind) end
    local ok,err
    if kind=="components" then ok,err=RecipeValues(items,scope,"",values)
    elseif kind=="elements" then
     local result;result,err=A.Appearance:FlattenElements(scope,items,values);ok=result~=nil
    elseif kind=="utilities" then
     if type(items)~="table" then return nil,"utilities must be a named rule table" end
     ok=true;for name,value in pairs(items) do
      if type(name)~="string" then return nil,"utilities require string names" end
      values["utility."..scope.."."..name]=value
     end
    else ok,err=Flatten(items,prefix..scope,values) end
    if not ok then return nil,err end
   end
  end
 end
 if definition.settings~=nil then
  if type(definition.settings)~="table" then return nil,"settings must be a UI setting table" end
  for key,value in pairs(definition.settings) do
   if A.ThemeDefaults.settings[key]==nil then return nil,"unknown UI setting: "..tostring(key) end
   values["settings."..key]=value
  end
 end
 if definition.layout~=nil then
  local ok,err=Flatten(definition.layout,"layout",values)
  if not ok then return nil,err end
 end
 return values
end
local function IsVisual(key) return type(key)=="string" and key:match("^(%a+)%.") and (key:match("^theme%.") or key:match("^style%.") or key:match("^element%.") or key:match("^utility%.")) end
local function ThemePreference(key)
 local name=key:match("^settings%.(.+)$")
 return name and A.ThemeDefaults.settings[name]~=nil or key:match("^layout%.") and Configuration.definitions[key]~=nil
end
local function Clone(value) return Configuration:CopyValue(value) end
local function Equal(a,b) return Configuration:SameValue(a,b) end
local function Identity(id,revision)
 if type(id)~="string" or not id:match("^[%w][%w_.%-]*$") then return false,"theme id must be a nonempty identifier" end
 if type(revision)~="number" and type(revision)~="string" or type(revision)=="string" and revision:match("^%s*$") then return false,"theme revision must be a nonempty string or finite number" end
 return true
end
function Service:Parse(definition)
 local ok,copy=pcall(Clone,definition);if not ok then return nil,copy end
 if type(copy)~="table" then return nil,"theme definition must be a table" end
 local valid,err=Identity(copy.id,copy.revision);if not valid then return nil,err end
 local values,reason=Values(copy);if not values then return nil,reason end
 local package={schema=1,id=copy.id,revision=copy.revision,values=values}
 local compiled;compiled,err=A.Appearance:Compile({selection={id=copy.id,revision=copy.revision},values=values,overrides={}})
 if not compiled then return nil,err end
 return package
end
local function NewStore() return {presets={},overrides={}} end
local function Split(values,visual)
 local themed,preferences,unknown={},{},{}
 for key,value in pairs(values) do
  if IsVisual(key) or visual and ThemePreference(key) then themed[key]=value
  elseif Configuration.definitions[key] then preferences[key]=value
  else unknown[key]=value end
 end
 return themed,preferences,unknown
end
function Service:Migrate(store)
 if not store.theme then store.theme=NewStore() end
 if store.schema~=1 then return end
 local theme=store.theme
 local user={};local unknown={}
 for key,value in pairs(store.user) do
  if IsVisual(key) then theme.overrides[key]=value
  elseif Configuration.definitions[key] then user[key]=value
  else unknown[key]=value end
 end
 store.user=user
 local presets={};local legacy={}
 for id,package in pairs(store.presets) do
  local visual=false;for key in pairs(package.values) do if IsVisual(key) then visual=true;break end end
  local themed,preferences,rejected=Split(package.values,visual)
  if next(themed) then theme.presets[id]={schema=1,id=id,revision=package.revision,values=themed} end
  if next(preferences) then presets[id]={revision=package.revision,values=preferences} end
  if next(rejected) then legacy[id]={revision=package.revision,values=rejected} end
 end
 local selected=store.activePreset
 if selected~=nil then theme.migrationSelection=selected end
 if next(unknown) or next(legacy) then theme.legacy={user=unknown,presets=legacy} end
 store.presets,store.schema=presets,2
end
function Service:Bind()
 self.stores={}
 for _,storage in ipairs({"account","character"}) do
  local store=Configuration.stores[storage];self:Migrate(store)
  self.stores[storage]=store.theme
 end
 for _,storage in ipairs({"account","character"}) do
  local theme=self.stores[storage];local selected=theme.migrationSelection
  if selected~=nil then
   if selected==false then theme.activePreset=false;Configuration.stores[storage].activePreset=false
   else
    theme.activePreset=(self.stores.character.presets[selected] or self.stores.account.presets[selected]) and selected or nil
    Configuration.stores[storage].activePreset=(Configuration.stores.character.presets[selected] or Configuration.stores.account.presets[selected]) and selected or nil
   end
   theme.migrationSelection=nil
  end
 end
end
function Service:Source(stores)
 stores=stores or self.stores
 local id,activation
 for _,storage in ipairs({"character","account"}) do if stores[storage].activePreset~=nil then id,activation=stores[storage].activePreset,storage;break end end
 local package,owner
 if id then for _,storage in ipairs({"character","account"}) do if stores[storage].presets[id] then package,owner=stores[storage].presets[id],storage;break end end end
 local selection={id=id or false,revision=package and package.revision or nil,storage=owner,activationStorage=activation}
 return {selection=selection,values=package and package.values or {},overrides={account=stores.account.overrides,character=stores.character.overrides},error=id and not package and "selected theme definition is missing: "..id or nil}
end
function A:InitializeRuntimeTheme()
 if self.RuntimeTheme then return end
 Service:Bind()
 local source=Service:Source()
 local runtime,err=self.Appearance:Compile(source)
 if not runtime then
  runtime=assert(self.Appearance:Compile({selection={id=false},values={},overrides={}}))
  runtime.error, runtime.requested=err,source
 end
 self.RuntimeTheme=runtime
end
local function Storage(options)
 if options~=nil and type(options)~="table" then return nil,"options must be a table" end
 local storage=options and options.storage
 if storage==nil then storage="account" end
 if storage~="account" and storage~="character" then return nil,"themes require account or character storage; session themes cannot survive reload" end
 return storage
end
local function Ready() Configuration:EnsureReady() end
local function Shallow(value)local result={};for key,item in pairs(value) do result[key]=item end;return result end
local function Draft(storage)
 local store=Service.stores[storage];local draft=Shallow(store)
 draft.presets=Shallow(store.presets)
 return draft
end
local function Commit(storage,draft)
 local stores=Shallow(Service.stores);stores[storage]=draft
 local source=Service:Source(stores)
 if not Equal(source,Service:Source()) then
  local runtime,err=A.Appearance:Compile(source);if not runtime then return false,err end
 end
 Service.stores[storage]=draft;Configuration.stores[storage].theme=draft
 return true
end
function API:Import(definition,options)
 local storage,err=Storage(options);if not storage then return false,err end
 if options and options.activate~=nil and type(options.activate)~="boolean" then return false,"activate must be a boolean" end
 local package;package,err=Service:Parse(definition);if not package then return false,err end
 Ready()
 local draft=Draft(storage)
 draft.presets[package.id]=Equal(draft.presets[package.id],package) and draft.presets[package.id] or package
 if options and options.activate then draft.activePreset=package.id end
 return Commit(storage,draft)
end
function API:Activate(id,options)
 local storage,err=Storage(options);if not storage then return false,err end
 Ready()
 if id~=false then
  if type(id)~="string" then return false,"theme id must be a string or false" end
  if not Service.stores.character.presets[id] and not Service.stores.account.presets[id] then return false,"unknown theme: "..id end
 end
 local draft=Draft(storage);draft.activePreset=id
 return Commit(storage,draft)
end
function API:Remove(id,options)
 local storage,err=Storage(options);if not storage then return false,err end
 if type(id)~="string" or not id:match("^[%w][%w_.%-]*$") then return false,"theme id must be a nonempty identifier" end
 Ready()
 local draft=Draft(storage);draft.presets[id]=nil
 if draft.activePreset==id then draft.activePreset=nil end
 return Commit(storage,draft)
end
function API:GetStatus()
 Ready()
 local source=Service:Source();local runtime=A.RuntimeTheme
 local pending=Clone(source.selection);pending.error=source.error
 return {current=Clone(runtime.selection),next=pending,reloadRequired=not Equal(runtime.source,source),error=runtime.error}
end
function API:List()
 Ready();local source=Service:Source();local list={}
 for _,storage in ipairs({"character","account"}) do for id,package in pairs(Service.stores[storage].presets) do
  list[#list+1]={id=id,revision=package.revision,storage=storage,current=A.RuntimeTheme.selection.id==id and A.RuntimeTheme.selection.storage==storage,selected=source.selection.id==id and source.selection.storage==storage}
 end end
 table.sort(list,function(a,b)return a.id==b.id and a.storage<b.storage or a.id<b.id end);return list
end
function API:Export(id,options)
 Ready()
 if options~=nil and type(options)~="table" then return nil,"options must be a table" end
 local state=options and options.state or "next"
 if state~="current" and state~="next" then return nil,"export state must be current or next" end
 local source=state=="current" and A.RuntimeTheme.source or Service:Source()
 if source.error and not id then return nil,source.error end
 local package
 local storage=options and options.storage
 if storage~=nil and storage~="account" and storage~="character" then return nil,"unknown theme storage" end
 if state=="current" then
  if id and id~=source.selection.id or storage and storage~=source.selection.storage then return nil,"theme is not the current startup source" end
  package={id=source.selection.id or A.ThemeDefaults.id,revision=source.selection.revision or A.ThemeDefaults.revision,values=source.values}
 elseif id then
  if type(id)~="string" then return nil,"theme id must be a string" end
  if storage then package=Service.stores[storage].presets[id]
  else package=Service.stores.character.presets[id] or Service.stores.account.presets[id] end
 else package={id=source.selection.id or A.ThemeDefaults.id,revision=source.selection.revision or A.ThemeDefaults.revision,values=source.values} end
 if not package then return nil,"unknown theme: "..tostring(id) end
 local definition={schema=1,id=package.id,revision=package.revision}
 for key,value in pairs(package.values) do A.Appearance:WriteDeclaration(definition,key,Clone(value)) end
 return definition
end
function API:ResetOverrides(scope,paths,options)
 local storage,err=Storage(options);if not storage then return false,err end
 if not A.StyleDefaults[scope] then return false,"unknown appearance scope: "..tostring(scope) end
 if type(paths)=="string" then paths={paths} end
 if paths~=nil and type(paths)~="table" then return false,"paths must be a full visual-key array or nil" end
 Ready();local draft=Draft(storage);draft.overrides=Shallow(draft.overrides)
 if paths then
  for _,key in ipairs(paths) do
   if type(key)~="string" then return false,"override paths must be strings" end
   local kind,owner=key:match("^([^.]+)%.([^.]+)%.")
   if owner~=scope or not IsVisual(key) then return false,"override path must include its visual prefix and selected scope" end
   draft.overrides[key]=nil
  end
 else for key in pairs(draft.overrides) do if key:match("^[^.]+%.([^.]+)%.")==scope then draft.overrides[key]=nil end end end
 return Commit(storage,draft)
end
