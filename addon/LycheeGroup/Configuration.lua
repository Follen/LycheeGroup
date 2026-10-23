-- Product configuration: preset defaults and explicit user choices stay separate.
-- Only account/character namespaces are SavedVariables; session state is memory-only.
local A=_G.LycheeGroup
local C={definitions={}}
A.Configuration=C
local order={"session","character","account"}
local function Namespace()
 return {schema=1,user={},presets={},imported={}}
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
local function Storage(options,persistent)
 if options~=nil and type(options)~="table" then return nil,"options must be a table" end
 local storage=options and options.storage
 if storage==nil then storage="session" end
 if storage~="account" and storage~="character" and (persistent or storage~="session") then return nil,"unknown configuration storage" end
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
function C:ValidateValues(values)
 if type(values)~="table" then return nil,"values must be a flat key/value table" end
 local ok,copy=pcall(Copy,values)
 if not ok then return nil,copy end
 for key,value in pairs(copy) do
  local def=self.definitions[key]
  if not def then return nil,"unknown configuration key: "..tostring(key) end
  local valid,reason=Validate(def,value)
  if not valid then return nil,key..": "..reason end
 end
 return copy
end
function C:SelectedPreset(withSource)
 local id,activationStorage
 for _,storage in ipairs(order) do
  local selected=self.stores[storage].activePreset
  if selected~=nil then id,activationStorage=selected,storage;break end
 end
 if not id then return end
 for _,storage in ipairs(order) do
  local preset=self.stores[storage].presets[id]
  if preset then return preset,withSource and {kind="preset",id=id,revision=preset.revision,storage=storage,activationStorage=activationStorage} or nil end
 end
end
function C:Resolve(key,withSource)
 for _,storage in ipairs(order) do
  local value=self.stores[storage].user[key]
  if value~=nil then return value,withSource and {kind="user",storage=storage} or nil end
 end
 local preset,source=self:SelectedPreset(withSource)
 if preset and preset.values[key]~=nil then return preset.values[key],source end
 return self.definitions[key].default,withSource and {kind="default"} or nil
end
function C:Snapshot()
 local snapshot={}
 for key in pairs(self.definitions) do snapshot[key]=self:Resolve(key) end
 return snapshot
end
function C:Notify(previous)
 local changes={}
 for key in pairs(self.definitions) do
  local value=self:Resolve(key)
  if not Equal(previous[key],value) then changes[key]={previous=Copy(previous[key]),value=Copy(value)} end
 end
 if next(changes) then A:ApplyConfigurationChanges(changes) end
end
local function Shallow(value)
 local result={};for key,item in pairs(value) do result[key]=item end;return result
end
function C:Change(callback,storage,onCommit)
 local previous=self:Snapshot()
 -- Draft only the selected layer. Validated leaf values are replaced as units.
 local original=self.stores[storage]
 local draft=Shallow(original)
 draft.user,draft.presets,draft.imported=Shallow(original.user),Shallow(original.presets),Shallow(original.imported)
 self.stores[storage]=draft
 callback()
 if A.ValidateConfiguration then
  local ok,valid,reason=pcall(A.ValidateConfiguration,A,previous)
  if not ok or not valid then self.stores[storage]=original;return false,ok and reason or valid end
 end
 original.user,original.presets,original.imported,original.activePreset=draft.user,draft.presets,draft.imported,draft.activePreset
 self.stores[storage]=original
 if onCommit then onCommit() end
 self:Notify(previous)
 return true
end
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
 local def=self.definitions[key]
 local owner,path=LegacyPath(def)
 if owner~=storage then return end
 local root=storage=="account" and A.db or A.charPrefs
 for i=1,#path-1 do
  local name=path[i]
  if root[name]==nil then
   if value==nil then return end
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
  if type(key)~="string" or type(def)~="table" then return false,"definitions require string keys and table definitions" end
  if self.definitions[key] then return false,"configuration key is already registered: "..key end
  local storage=def.storage or "account"
  if storage~="account" and storage~="character" then return false,"definition storage must be account or character" end
  local ok,default=pcall(Copy,def.default);if not ok then return false,key..": "..default end
  if default~=nil then local valid,reason=Validate(def,default);if not valid then return false,key..": "..reason end end
  local entry={};for name,value in pairs(def) do entry[name]=value end
  entry.default,entry.storage=default,storage;pending[key]=entry;keys[#keys+1]=key
 end
 local previous=self.stores and self:Snapshot()
 for key,def in pairs(pending) do self.definitions[key]=def end
 if self.stores then self:ImportDefinitions(keys);self:Notify(previous) end
 return true
end
local function LegacySnapshot(root)
 local result={}
 for key,value in pairs(root) do
  if key~="uiConfig" then local ok,copy=pcall(Copy,value);if ok then result[key]=copy end end
 end
 return result
end
function C:Bind(account,character)
 -- Capture before Core materializes legacy defaults, including nested UI leaves.
 self.legacy={account=LegacySnapshot(account),character=LegacySnapshot(character)}
 for _,root in ipairs({account,character}) do
  if root.uiConfig==nil then root.uiConfig=Namespace() end
 end
 self.stores={account=account.uiConfig,character=character.uiConfig,session=Namespace()}
 local keys={};for key in pairs(self.definitions) do keys[#keys+1]=key end
 self:ImportDefinitions(keys)
end
function C:Get(key)
 self:EnsureReady()
 if not self.definitions[key] then return nil,"unknown configuration key: "..tostring(key) end
 local value=self:Resolve(key);return Copy(value)
end
function C:GetSource(key)
 self:EnsureReady()
 if not self.definitions[key] then return nil,"unknown configuration key: "..tostring(key) end
 local _,source=self:Resolve(key,true);return source
end
function C:GetSchema()
 local schema={}
 for key,def in pairs(self.definitions) do
  schema[key]={default=Copy(def.default),storage=def.storage,type=Copy(def.type or type(def.default)),min=def.min,max=def.max,exclusiveMin=def.exclusiveMin,integer=def.integer,enum=Copy(def.enum)}
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
   if storage~="session" then self.stores[storage].imported[key]=true end
  end
 end,storage,function()
  if storage~="session" then for key,value in pairs(copy) do self:MirrorLegacy(key,value,storage) end end
 end)
end
function C:Reset(keys,options)
 self:EnsureReady()
 local storage,err=Storage(options);if not storage then return false,err end
 if type(keys)=="string" then keys={keys} end
 if type(keys)~="table" then return false,"reset requires a key or key array" end
 local copy={}
 for index,key in pairs(keys) do
  if type(index)~="number" or index%1~=0 or index<1 or not self.definitions[key] then return false,"reset requires registered keys" end
  copy[#copy+1]=key
 end
 return self:Change(function()
  for _,key in ipairs(copy) do
   self.stores[storage].user[key]=nil
   if storage~="session" then self.stores[storage].imported[key]=true end
  end
 end,storage,function()
  if storage~="session" then for _,key in ipairs(copy) do self:MirrorLegacy(key,nil,storage) end end
 end)
end
function C:ImportLegacy(values,options)
 self:EnsureReady()
 local storage,err=Storage(options,true);if not storage then return false,err end
 local copy,reason=self:ValidateValues(values);if not copy then return false,reason end
 return self:Change(function()
  local store=self.stores[storage]
  for key,value in pairs(copy) do
   if not store.imported[key] then
    if store.user[key]==nil then store.user[key]=value end
    store.imported[key]=true
   end
  end
 end,storage)
end
function C:RegisterPreset(id,revision,values,options)
 self:EnsureReady()
 local valid,err=Identity(id,revision);if not valid or revision==nil then return false,err or "preset revision is required" end
 local storage,reason=Storage(options);if not storage then return false,reason end
 local copy,problem=self:ValidateValues(values);if not copy then return false,problem end
 return self:Change(function() self.stores[storage].presets[id]={revision=revision,values=copy} end,storage)
end
function C:ActivatePreset(id,options)
 self:EnsureReady()
 local storage,err=Storage(options);if not storage then return false,err end
 if id~=false then
  local valid,reason=Identity(id);if not valid then return false,reason end
  local found=false;for _,store in pairs(self.stores) do if store.presets[id] then found=true end end
  if not found then return false,"unknown preset: "..id end
 end
 return self:Change(function() self.stores[storage].activePreset=id end,storage)
end
function C:ApplyPreset(id,revision,values,options)
 self:EnsureReady()
 local valid,err=Identity(id,revision);if not valid or revision==nil then return false,err or "preset revision is required" end
 local storage,reason=Storage(options);if not storage then return false,reason end
 local copy,problem=self:ValidateValues(values);if not copy then return false,problem end
 return self:Change(function() self.stores[storage].presets[id]={revision=revision,values=copy};self.stores[storage].activePreset=id end,storage)
end
function C:RemovePreset(id,options)
 self:EnsureReady()
 local valid,err=Identity(id);if not valid then return false,err end
 local storage,reason=Storage(options);if not storage then return false,reason end
 return self:Change(function()
  local store=self.stores[storage];store.presets[id]=nil
  if store.activePreset==id then store.activePreset=nil end
 end,storage)
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
