-- Character search preferences are independent leaves, available before Group/UI.
local A=_G.LycheeGroup
local Configuration=A.Configuration
local F={categories={"seasonDungeon","seasonRaid","1","2","3","4","6","7","8","9","121"}}
A.FindPreferences=F
local prefix="settings.find."
local definitions,fields,templates,categorySet={},{},{},{}
for _,category in ipairs(F.categories) do categorySet[category]=true end
F.fields=fields
local function Integer(value,min,max)
 return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge and value%1==0 and value>=min and (not max or value<=max)
end
local function Optional(check) return function(value) return value==false or check(value),"expected false or a valid search preference" end end
local function Add(name,kind,check,choices)
 fields[#fields+1]=name
 templates[name]={default=false,type=kind,validate=check,enum=choices,storage="character"}
 for _,category in ipairs(F.categories) do
  definitions[prefix.."categories."..category.."."..name]={default=false,type=kind,validate=check,enum=choices,storage="character"}
 end
end
local function CategoryKey(value) return type(value)=="string" and (value=="seasonDungeon" or value=="seasonRaid" or value:match("^%d+$") and tonumber(value)>0) end
definitions[prefix.."category"]={default="seasonDungeon",type="string",validate=CategoryKey,storage="character"}
Add("groupKey",{"number","boolean"},Optional(function(value) return Integer(value,-math.huge) and value~=0 end))
Add("groupKeys",{"table","boolean"},Optional(function(value)
 if type(value)~="table" then return false end
 for key,selected in pairs(value) do if not Integer(key,-math.huge) or key==0 or type(selected)~="boolean" then return false end end
 return true
end))
Add("tier",{"number","string","boolean"},Optional(function(value) return Integer(value,1) or type(value)=="string" and value:match("^exp%d+$")~=nil end))
Add("difficultyID",{"number","boolean"},Optional(function(value) return Integer(value,1) end))
Add("selected","boolean")
Add("neededRole",{"string","boolean"},nil,{false,"TANK","HEALER","DAMAGER"})
for _,field in ipairs({"tankPresence","healerPresence","damagePresence"}) do Add(field,{"string","boolean"},nil,{false,"missing","present"}) end
for _,field in ipairs({"hideZeroScore","hideSameSpec","hideSameClass","hideSameClassRole","requireBloodlust","roleMatchAny"}) do Add(field,"boolean") end
for _,field in ipairs({"minRating","maxRating","minItemLevel","maxItemLevel","minMembers","maxMembers"}) do
 Add(field,{"number","boolean"},Optional(function(value) return Integer(value,field:match("Members$") and 1 or 0,99999) end))
end
Add("social",{"string","boolean"},nil,{false,"friend","guild","any","positive","noCaution"})
Add("sort",{"string","boolean"},nil,{false,"newest","rating","itemLevel","members"})
assert(Configuration:RegisterDefinitions(definitions))
function F:Key(category,field) return prefix.."categories."..category.."."..field end
local Resolve=Configuration.Resolve
function Configuration:Resolve(path,withSource)
 if not definitions[path] or Resolve(self,"settings.rememberFilters")~=false then return Resolve(self,path,withSource) end
 -- One effective-value rule keeps Get, provenance, change detection and UI in
 -- agreement while memory is disabled. Saved choices remain untouched.
 local value=self.stores.session.user[path]
 if value~=nil then return value,withSource and {kind="user",storage="session"} or nil end
 local package,source=self:SelectedPreset(withSource)
 if package and package.values[path]~=nil then return package.values[path],source end
 local runtime=A.RuntimeTheme
 if runtime and runtime.preferences[path]~=nil then
  return runtime.preferences[path],withSource and {kind="theme",id=runtime.selection.id,revision=runtime.selection.revision,storage=runtime.selection.storage} or nil
 end
 return definitions[path].default,withSource and {kind="default"} or nil
end
function F:Read(path) return Configuration:Get(path) end
local function LegacyValue(raw,field)
 local value=raw[field]
 if value==nil and field=="social" then return nil end
 if field=="social" and value=="caution" then return "noCaution" end
 if field:match("^min") or field:match("^max") then
  if value~=nil and value~=false then
   local number=tonumber(value)
   if number and number==number and number~=math.huge and number~=-math.huge then return math.max(field:match("Members$") and 1 or 0,math.min(99999,math.floor(number))) end
  end
 end
 return value
end
local function Import(path,value,seal)
 local store=Configuration.stores.character
 if store.imported[path] then return end
 if value~=nil then
  local valid,err=Configuration:CheckSerializable(value)
  if valid then valid,err=Configuration:ValidateField(definitions[path],value) end
  if valid and store.user[path]==nil then store.user[path]=Configuration:CopyValue(value)
  elseif not valid then Configuration:RetainInvalid(A.charPrefs,path,value,err) end
  store.imported[path]=true
 elseif seal then store.imported[path]=true end
end
function F:MigrateCategory(category,raw,seal)
  local current=raw.category or "seasonDungeon"
  local saved=type(raw.categoryPrefs)=="table" and raw.categoryPrefs[category]
  if type(saved)~="table" then saved=current==category and type(raw.filters)=="table" and raw.filters or {} end
  for _,field in ipairs(fields) do
   local value=LegacyValue(saved,field)
   if value==nil and field=="social" and current==category then value=raw.social end
   -- Old seasonal neededRole/needsDamage became the three presence predicates.
   if category=="seasonDungeon" then
    if field=="tankPresence" and value==nil and saved.neededRole=="TANK" then value="missing"
    elseif field=="healerPresence" and value==nil and saved.neededRole=="HEALER" then value="missing"
    elseif field=="damagePresence" and value==nil and (saved.neededRole=="DAMAGER" or saved.needsDamage) then value="missing" end
   end
   Import(self:Key(category,field),value,seal)
  end
end
function F:Migrate(seal)
 if self.sealed then return end
 local raw=A.charPrefs and A.charPrefs.find
 if type(raw)~="table" and not seal then return end
 raw=type(raw)=="table" and raw or {}
 Import(prefix.."category",raw.category,seal)
 for _,category in ipairs(self.categories) do self:MigrateCategory(category,raw,seal) end
 self.sealed=seal==true
end
function F:RegisterCategories(categories,migrate)
 local added,keys={},{}
 for _,entry in ipairs(categories) do
  local category=entry.key
  if CategoryKey(category) and not categorySet[category] then
   categorySet[category]=true;self.categories[#self.categories+1]=category;keys[#keys+1]=category
   for _,field in ipairs(fields) do local path=self:Key(category,field);added[path]=templates[field];definitions[path]=templates[field] end
  end
 end
 if next(added) then
  assert(Configuration:RegisterDefinitions(added))
  if migrate~=false and Configuration.stores then
   local raw=type(A.charPrefs.find)=="table" and A.charPrefs.find or {}
   for _,category in ipairs(keys) do self:MigrateCategory(category,raw,true) end
  end
 end
end
local Bind=Configuration.Bind
function Configuration:Bind(account,character)
 -- Saved native categories must have a schema before namespace validation.
 -- Inspect names only; no native directory or saved callbacks are evaluated.
 local categories,seen={},{}
 local function Category(value)
  if CategoryKey(value) and not categorySet[value] and not seen[value] then seen[value]=true;categories[#categories+1]={key=value} end
 end
 local function Values(values)
  if type(values)~="table" then return end
  for path in pairs(values) do if type(path)=="string" then
   local category,field=path:match("^settings%.find%.categories%.(%d+)%.([%w_]+)$")
   if templates[field] then Category(category) end
  end end
 end
 for _,root in ipairs({account,character}) do if type(root)=="table" then
  local raw=root.find
  if type(raw)=="table" then
   Category(raw.category)
   if type(raw.categoryPrefs)=="table" then for category in pairs(raw.categoryPrefs) do Category(category) end end
  end
  local store=root.uiConfig
  if type(store)=="table" then
   Values(store.user)
   if type(store.presets)=="table" then for _,package in pairs(store.presets) do if type(package)=="table" then Values(package.values) end end end
  end
 end end
 F:RegisterCategories(categories,false)
 Bind(self,account,character)
 F.sealed=false
 F:Migrate(false)
end
function F:Category(category,remember)
 self:Migrate(true)
 local result={}
 if not categorySet[category] then return result end
 for _,field in ipairs(fields) do local value=self:Read(self:Key(category,field),remember);if value~=false then result[field]=value end end
 return result
end
function F:InitialCategory(remember)
 self:Migrate(true);return self:Read(prefix.."category",remember)
end
local Changed=A.OnConfigurationChanged
function A:OnConfigurationChanged(changes)
 if Changed then Changed(self,changes) end
 local page=self.UI and self.UI.pages and self.UI.pages.find
 if not page or not page.frame or not page.RefreshPreferences then return end
 for key in pairs(changes) do if key:sub(1,#prefix)==prefix or key=="settings.rememberFilters" then page:RefreshPreferences(changes);return end end
end
