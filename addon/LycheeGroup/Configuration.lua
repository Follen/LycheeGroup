-- Product configuration: preset defaults and explicit user choices stay separate.
-- Only account/character namespaces are SavedVariables; session state is memory-only.
local A=_G.LycheeGroup
local C={definitions={}}
A.Configuration=C
local order={"session","character","account"}
local function Namespace()
 return {schema=2,user={},presets={},imported={}}
end
local function Copy(value,parents)
 local kind=type(value)
 if kind=="nil" or kind=="string" or kind=="boolean" then return value end
 if kind=="number" then
  if value~=value or value==math.huge or value==-math.huge then error("numbers must be finite",0) end
  return value
 end
 if kind~="table" then error("configuration values must be serializable",0) end
 parents=parents or {}
 if parents[value] then error("configuration values cannot contain cycles",0) end
 parents[value]=true
 local result={}
 for key,item in pairs(value) do
  local keyType=type(key)
  if keyType~="string" and keyType~="number" and keyType~="boolean" then error("configuration table keys must be serializable scalars",0) end
  result[Copy(key,parents)]=Copy(item,parents)
 end
 parents[value]=nil
 return result
end
-- Startup validation reads saved values without cloning whole namespaces.
local function Serializable(value,parents)
 local kind=type(value)
 if kind=="nil" or kind=="string" or kind=="boolean" then return true end
 if kind=="number" then return value==value and value~=math.huge and value~=-math.huge,"numbers must be finite" end
 if kind~="table" then return false,"configuration values must be serializable" end
 parents=parents or {}
 if parents[value] then return false,"configuration values cannot contain cycles" end
 parents[value]=true
 for key,item in pairs(value) do
  local keyType=type(key)
  if keyType~="string" and keyType~="number" and keyType~="boolean" then parents[value]=nil;return false,"configuration table keys must be serializable scalars" end
  local ok,err=Serializable(key,parents)
  if ok then ok,err=Serializable(item,parents) end
  if not ok then parents[value]=nil;return false,err end
 end
 parents[value]=nil;return true
end
function C:CheckSerializable(value) return Serializable(value) end
-- Recovery records retain the original object; repeated binds do not append copies.
function C:RetainInvalid(root,path,value,reason)
 local recovery=root.uiConfigRecovery
 if type(recovery)~="table" then
  root.uiConfigRecovery={}
  if recovery~=nil then root.uiConfigRecovery.previous={value=recovery,error="uiConfigRecovery must be a table"} end
  recovery=root.uiConfigRecovery
 end
 local previous=recovery[path]
 recovery[path]={value=value,error=reason,previous=previous}
 return reason
end
function C:BindTable(root,owner,key,path)
 local value=owner[key]
 if type(value)=="table" then return value end
 local err
 if value~=nil then err=self:RetainInvalid(root,path,value,path.." must be a table") end
 owner[key]={};return owner[key],err
end
local function Equal(a,b)
 if a==b then return true end
 if type(a)~="table" or type(b)~="table" then return false end
 for key,value in pairs(a) do if not Equal(value,b[key]) then return false end end
 for key in pairs(b) do if a[key]==nil then return false end end
 return true
end
local function MatchesType(expected,value)
 if expected=="color" then
  if type(value)~="table" or (#value~=3 and #value~=4) then return false,"expected a three- or four-channel color" end
  for key,channel in pairs(value) do
   if type(key)~="number" or key%1~=0 or key<1 or key>#value or type(channel)~="number" or channel<0 or channel>1 then return false,"color channels must be numbers from 0 to 1" end
  end
  return true
 end
 return type(value)==expected,"expected "..expected
end
local function Validate(def,value)
 local expected=def.type or type(def.default)
 if type(expected)=="table" then
  local accepted=false
  for _,choice in ipairs(expected) do if MatchesType(choice,value) then accepted=true;break end end
  if not accepted then return false,"expected "..table.concat(expected," or ") end
 else
  local accepted,reason=MatchesType(expected,value);if not accepted then return false,reason end
 end
 if type(value)=="number" then
  if def.min and (value<def.min or def.exclusiveMin and value==def.min) or def.max and value>def.max then return false,"number is outside the allowed range" end
  if def.integer and value%1~=0 then return false,"expected an integer" end
 end
 if def.enum then
  local found=false;for _,allowed in ipairs(def.enum) do if value==allowed then found=true;break end end
  if not found then return false,"value is not an allowed choice" end
 end
 if def.validate then
  local ok,valid,reason=pcall(def.validate,value)
  if not ok then return false,tostring(valid) end
  if not valid then return false,reason or "value is invalid" end
 end
 return true
end
local function Storage(options)
 if options~=nil and type(options)~="table" then return nil,"options must be a table" end
 local storage=options and options.storage
 if storage==nil then storage="session" end
 if storage~="account" and storage~="character" and storage~="session" then return nil,"unknown configuration storage" end
 return storage
end
local function Identity(id,revision)
 if type(id)~="string" or not id:match("^[%w][%w_.%-]*$") then return false,"preset id must be a nonempty identifier" end
 if revision~=nil then
  local kind=type(revision)
  if kind~="string" and kind~="number" or kind=="string" and revision:match("^%s*$") then return false,"preset revision must be a nonempty string or number" end
  local ok,err=pcall(Copy,revision);if not ok then return false,err end
 end
 return true
end
function C:EnsureReady()
 if not self.stores then A:LoadDB() end
end
local function ValueDefinition(self,key) return self.definitions[key] end
function C:ValidateValues(values)
 if type(values)~="table" then return nil,"values must be a flat key/value table" end
 local ok,copy=pcall(Copy,values)
 if not ok then return nil,copy end
 -- Retired role defaults must not break the remaining settings in older packages.
 copy["settings.applicationRoles"]=nil
 for key,value in pairs(copy) do
  local def=ValueDefinition(self,key)
  if not def then return nil,"unknown configuration key: "..tostring(key) end
  local valid,reason=Validate(def,value)
  if not valid then return nil,key..": "..reason end
 end
 return copy
end
local function Selection(self,field)
 for _,storage in ipairs(order) do
  local id=self.stores[storage][field]
  if id~=nil then return id,storage end
 end
end
local function Package(self,id)
 for _,storage in ipairs(order) do
  local preset=self.stores[storage].presets[id]
  if preset then return preset,storage end
 end
end
function C:SelectedPreset(withSource)
 local id,activationStorage=Selection(self,"activePreset")
 if id==nil then id,activationStorage=Selection(self,"defaultPreset") end
 if not id then return end
 local preset,storage=Package(self,id)
 if preset then return preset,withSource and {kind="preset",id=id,revision=preset.revision,storage=storage,activationStorage=activationStorage} or nil end
end
function C:GetPresetStatus()
 self:EnsureReady()
 local selected,selectedStorage=Selection(self,"activePreset")
 local default,defaultStorage=Selection(self,"defaultPreset")
 local id,selectionStorage=selected,selectedStorage
 if id==nil then id,selectionStorage=default,defaultStorage end
 local function Describe(value,owner)
  if not value then return {id=false,selectionStorage=owner} end
  local package,storage=Package(self,value)
  return {id=value,selectionStorage=owner,storage=storage,revision=package and package.revision,error=not package and "unknown preset: "..value or nil}
 end
 return {selected=Describe(id,selectionStorage),default=Describe(default,defaultStorage),followingDefault=selected==nil,defaultConfigured=default~=nil}
end
function C:Resolve(key,withSource)
 for _,storage in ipairs(order) do
  local value=self.stores[storage].user[key]
  if value~=nil then return value,withSource and {kind="user",storage=storage} or nil end
 end
 local preset,source=self:SelectedPreset(withSource)
 if preset and preset.values[key]~=nil then return preset.values[key],source end
 local runtime=A.RuntimeTheme
 if runtime and runtime.preferences[key]~=nil then
  return runtime.preferences[key],withSource and {kind="theme",id=runtime.selection.id,revision=runtime.selection.revision,storage=runtime.selection.storage} or nil
 end
 return ValueDefinition(self,key).default,withSource and {kind="default"} or nil
end
function C:Snapshot(keys)
 local snapshot={}
 for key in pairs(keys or self.definitions) do snapshot[key]=self:Resolve(key) end
 return snapshot
end
local function Changes(previous,current)
 local changes={}
 for key,value in pairs(current) do if not Equal(previous[key],value) then changes[key]={previous=Copy(previous[key]),value=Copy(value)} end end
 for key,value in pairs(previous) do if current[key]==nil then changes[key]={previous=Copy(value)} end end
 return changes
end
local function Shallow(value) local result={};for key,item in pairs(value) do result[key]=item end;return result end
function C:Change(callback,storage,onCommit,keys,write)
 local previous=self:Snapshot(keys)
 local original=self.stores[storage]
 local draft=Shallow(original)
 -- Public operations declare the container they replace. Unchanged catalogs
 -- and sealed migration markers can stay shared through the draft and commit.
 if write==nil or write=="user" then draft.user=Shallow(original.user) end
 if write==nil or write=="presets" then draft.presets=Shallow(original.presets) end
 if write==nil then draft.imported=Shallow(original.imported)
 elseif write=="user" and storage~="session" then
  for key in pairs(keys) do if self.definitions[key] and original.imported[key]~=true then draft.imported=Shallow(original.imported);break end end
 end
 self.stores[storage]=draft
 callback()
 local changes=Changes(previous,self:Snapshot(keys))
 original.user,original.presets,original.imported,original.activePreset=draft.user,draft.presets,draft.imported,draft.activePreset
 original.defaultPreset=draft.defaultPreset
 self.stores[storage]=original
 if onCommit then onCommit() end
 if next(changes) then A:ApplyConfigurationChanges(changes) end
 return true
end
-- Shared by the static Theme boundary, never a visual write route.
function C:ValidateField(def,value) return Validate(def,value) end
function C:CopyValue(value) return Copy(value) end
function C:SameValue(a,b) return Equal(a,b) end
local function LegacyPath(def)
 if not def.legacy then return end
 return def.legacy.storage or def.storage,def.legacy.path or {def.legacy.key}
end
local function ReadPath(root,path)
 local value=root
 for _,key in ipairs(path) do
  if type(value)~="table" then return nil end
  value=value[key]
 end
 return value
end
function C:MirrorLegacy(key,value,storage)
 local def=ValueDefinition(self,key)
 local owner,path=LegacyPath(def)
 if owner~=storage then return end
 local root=storage=="account" and A.db or A.charPrefs
 local savedRoot=root
 for i=1,#path-1 do
  local name=path[i]
  if type(root[name])~="table" then
   if root[name]==nil and value==nil then return end
   if root[name]~=nil then
    local legacyPath=table.concat(path,".",1,i)
    self:RetainInvalid(savedRoot,legacyPath,root[name],legacyPath.." must be a table")
   end
   root[name]={}
  end
  root=root[name]
 end
 root[path[#path]]=Copy(value)
end
function C:ImportDefinitions(keys)
 for _,key in ipairs(keys) do
  local def=self.definitions[key];local storage=def.storage or "account"
  local store=self.stores[storage]
  if (def.import or def.legacy) and not store.imported[key] then
   local value,present
   if def.import then value,present=def.import(self.legacy.account,self.legacy.character)
   else
    local owner,path=LegacyPath(def)
    if owner then value=ReadPath(self.legacy[owner],path) end
   end
   if present==nil then present=value~=nil end
   if present and store.user[key]==nil then
    local ok,copy=pcall(Copy,value)
    if ok and Validate(def,copy) then store.user[key]=copy end
   end
   store.imported[key]=true
  end
 end
end
function C:RegisterDefinitions(definitions)
 if type(definitions)~="table" then return false,"definitions must be a table" end
 local pending,keys={},{}
 for key,def in pairs(definitions) do
  if type(key)~="string" or not key:match("^settings%.") and not key:match("^layout%.") or type(def)~="table" then return false,"preference definitions require settings/layout keys and tables" end
  if self.definitions[key] then return false,"configuration key is already registered: "..key end
  local storage=def.storage or "account"
  if storage~="account" and storage~="character" then return false,"definition storage must be account or character" end
  local ok,default=pcall(Copy,def.default);if not ok then return false,key..": "..default end
  if default~=nil then local valid,reason=Validate(def,default);if not valid then return false,key..": "..reason end end
  local entry={};for name,value in pairs(def) do entry[name]=value end
  entry.default,entry.storage=default,storage;pending[key]=entry;keys[#keys+1]=key
 end
 local previous=self.stores and self:Snapshot()
 for key,def in pairs(pending) do
  self.definitions[key]=def
 end
 if self.stores then
  self:ImportDefinitions(keys)
  local changes=Changes(previous,self:Snapshot())
  if next(changes) then A:ApplyConfigurationChanges(changes) end
 end
 return true
end
local function LegacySnapshot(root)
 local result={}
 for key,value in pairs(root) do
  if key~="uiConfig" and key~="uiConfigRecovery" then local ok,copy=pcall(Copy,value);if ok then result[key]=copy end end
 end
 return result
end
local function StoredValues(self,values)
 if type(values)~="table" then return false,"preset values must be a flat key/value table" end
 local ok,err=Serializable(values);if not ok then return false,err end
 for key,value in pairs(values) do
  if type(key)~="string" then return false,"configuration values require named keys" end
  local def=self.definitions[key]
  if def then local valid,reason=Validate(def,value);if not valid then return false,key..": "..reason end end
 end
 return true
end
function C:BindNamespace(root)
 local store,err=self:BindTable(root,root,"uiConfig","uiConfig")
 if store.schema~=nil and store.schema~=1 and store.schema~=2 then
  err=self:RetainInvalid(root,"uiConfig",store,"uiConfig requires schema=1 or schema=2")
  store=Namespace();root.uiConfig=store
 end
 self.namespaceErrors[root]=err
 for _,key in ipairs({"user","presets","imported"}) do self:BindTable(root,store,key,"uiConfig."..key) end
 store.user["settings.applicationRoles"],store.imported["settings.applicationRoles"]=nil,nil
 for key,value in pairs(store.user) do
  local def=self.definitions[key]
  if def then
   local ok,err=Serializable(value)
   if ok then ok,err=Validate(def,value) end
   if not ok then self:RetainInvalid(root,"uiConfig.user."..key,value,key..": "..err);store.user[key]=nil end
  end
 end
 for id,package in pairs(store.presets) do
  if type(package)=="table" and type(package.values)=="table" then package.values["settings.applicationRoles"]=nil end
  local ok,err=Identity(id,type(package)=="table" and package.revision or nil)
  if ok and (type(package)~="table" or package.revision==nil) then ok,err=false,"preset requires a revision and values table" end
  if ok then ok,err=StoredValues(self,package.values) end
  if not ok then self:RetainInvalid(root,"uiConfig.presets."..tostring(id),package,tostring(err));store.presets[id]=nil end
 end
 for _,field in ipairs({"activePreset","defaultPreset"}) do
  if store[field]~=nil and store[field]~=false then
   local ok,err=Identity(store[field])
   if not ok then self:RetainInvalid(root,"uiConfig."..field,store[field],err);store[field]=nil end
  end
 end
 return store
end
function C:Bind(account,character)
 -- Capture before Core materializes legacy defaults, including nested UI leaves.
 self.legacy={account=LegacySnapshot(account),character=LegacySnapshot(character)}
 self.roots={account=account,character=character};self.namespaceErrors={}
 self.stores={account=self:BindNamespace(account),character=self:BindNamespace(character),session=Namespace()}
 for _,store in pairs(self.stores) do if store.schema==nil then store.schema=2 end end
 local keys={};for key in pairs(self.definitions) do keys[#keys+1]=key end
 self:ImportDefinitions(keys)
end
function C:Get(key)
 self:EnsureReady()
 if not ValueDefinition(self,key) then return nil,"unknown configuration key: "..tostring(key) end
 local value=self:Resolve(key);return Copy(value)
end
function C:GetSource(key)
 self:EnsureReady()
 if not ValueDefinition(self,key) then return nil,"unknown configuration key: "..tostring(key) end
 local _,source=self:Resolve(key,true);return source
end
function C:GetSchema(keys)
 if type(keys)=="string" then keys={keys} end
 if keys~=nil and type(keys)~="table" then return nil,"schema requires a key or key array" end
 local schema={}
 local function Add(key,def)
  if not def then return end
  schema[key]={default=Copy(def.default),storage=def.storage,type=Copy(def.type or type(def.default)),min=def.min,max=def.max,exclusiveMin=def.exclusiveMin,integer=def.integer,enum=Copy(def.enum)}
  for _,field in ipairs({"key","role","unit","canonical","representative","aliases","aliasOf","independent","group","derivedFrom","overlay","property","types","ref","refType","inherited","slotKind"}) do schema[key][field]=Copy(def[field]) end
 end
 if keys then for _,key in ipairs(keys) do Add(key,ValueDefinition(self,key)) end
 else
  for key in pairs(self.definitions) do Add(key,ValueDefinition(self,key)) end
 end
 return schema
end
function C:Set(values,options)
 self:EnsureReady()
 local storage,err=Storage(options);if not storage then return false,err end
 local copy,reason=self:ValidateValues(values);if not copy then return false,reason end
 return self:Change(function()
  for key,value in pairs(copy) do
   self.stores[storage].user[key]=value
   -- Dynamic appearance fields have no legacy source to mark as imported.
   if storage~="session" and self.definitions[key] and self.stores[storage].imported[key]~=true then self.stores[storage].imported[key]=true end
  end
 end,storage,function()
  if storage~="session" then for key,value in pairs(copy) do self:MirrorLegacy(key,value,storage) end end
 end,copy,"user")
end
function C:Reset(keys,options)
 self:EnsureReady()
 local storage,err=Storage(options);if not storage then return false,err end
 if type(keys)=="string" then keys={keys} end
 if type(keys)~="table" then return false,"reset requires a key or key array" end
 local copy,writeSet={},{}
 for index,key in pairs(keys) do
  if type(index)~="number" or index%1~=0 or index<1 or not ValueDefinition(self,key) then return false,"reset requires registered keys" end
  copy[#copy+1]=key
  writeSet[key]=true
 end
 return self:Change(function()
  for _,key in ipairs(copy) do
   self.stores[storage].user[key]=nil
   if storage~="session" and self.definitions[key] and self.stores[storage].imported[key]~=true then self.stores[storage].imported[key]=true end
  end
 end,storage,function()
  if storage~="session" then for _,key in ipairs(copy) do self:MirrorLegacy(key,nil,storage) end end
 end,writeSet,"user")
end
function C:RegisterPreset(id,revision,values,options)
 self:EnsureReady()
 local valid,err=Identity(id,revision);if not valid or revision==nil then return false,err or "preset revision is required" end
 local storage,reason=Storage(options);if not storage then return false,reason end
 if options and options.default~=nil and type(options.default)~="boolean" then return false,"default must be a boolean" end
 local copy,problem=self:ValidateValues(values);if not copy then return false,problem end
 return self:Change(function()
  self.stores[storage].presets[id]={revision=revision,values=copy}
  if options and options.default then self.stores[storage].defaultPreset=id end
 end,storage,nil,nil,"presets")
end
function C:ActivatePreset(id,options)
 self:EnsureReady()
 local storage,err=Storage(options);if not storage then return false,err end
 if id~=false then
  local valid,reason=Identity(id);if not valid then return false,reason end
  local found=false;for _,store in pairs(self.stores) do if store.presets[id] then found=true end end
  if not found then return false,"unknown preset: "..id end
 end
 return self:Change(function() self.stores[storage].activePreset=id end,storage,nil,nil,"selection")
end
function C:ApplyPreset(id,revision,values,options)
 self:EnsureReady()
 local valid,err=Identity(id,revision);if not valid or revision==nil then return false,err or "preset revision is required" end
 local storage,reason=Storage(options);if not storage then return false,reason end
 local copy,problem=self:ValidateValues(values);if not copy then return false,problem end
 return self:Change(function() self.stores[storage].presets[id]={revision=revision,values=copy};self.stores[storage].activePreset=id end,storage,nil,nil,"presets")
end
function C:SetDefaultPreset(id,options)
 self:EnsureReady()
 local storage,err=Storage(options);if not storage then return false,err end
 if id~=nil and id~=false then
  local valid,reason=Identity(id);if not valid then return false,reason end
  if not Package(self,id) then return false,"unknown preset: "..id end
 end
 return self:Change(function() self.stores[storage].defaultPreset=id end,storage,nil,nil,"selection")
end
function C:UseDefaultPreset(options)
 self:EnsureReady()
 local storage,err=Storage(options);if not storage then return false,err end
 return self:Change(function() self.stores[storage].activePreset=nil end,storage,nil,nil,"selection")
end
function C:RemovePreset(id,options)
 self:EnsureReady()
 local valid,err=Identity(id);if not valid then return false,err end
 local storage,reason=Storage(options);if not storage then return false,reason end
 return self:Change(function()
  local store=self.stores[storage];store.presets[id]=nil
  if store.activePreset==id then store.activePreset=nil end
  if store.defaultPreset==id then store.defaultPreset=nil end
 end,storage,nil,nil,"presets")
end
function C:ListPresets()
 self:EnsureReady()
 local _,selected=self:SelectedPreset(true);local list={}
 for _,storage in ipairs(order) do
  for id,preset in pairs(self.stores[storage].presets) do
   list[#list+1]={id=id,revision=preset.revision,storage=storage,active=selected~=nil and selected.id==id and selected.storage==storage}
  end
 end
 table.sort(list,function(a,b) if a.id~=b.id then return a.id<b.id end;return a.storage<b.storage end)
 return list
end
function C:ExportPreset(id)
 self:EnsureReady()
 local valid,err=Identity(id);if not valid then return nil,err end
 for _,storage in ipairs(order) do
  local preset=self.stores[storage].presets[id]
  if preset then return {id=id,revision=preset.revision,values=Copy(preset.values),storage=storage} end
 end
 return nil,"unknown preset: "..id
end
A:RegisterConfigurationSettings()
