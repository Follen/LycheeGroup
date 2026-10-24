local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
local empty={}
local states={selected=true,checked=true,hover=true,pressed=true,focus=true,disabled=true}
local stateOrder={"selected","checked","hover","pressed","focus","disabled"}
local properties=Library.StyleProperties
Library.ElementDefinitions={
 ["menu"]={scope="menu",template=true,slotKinds={root="box",surface="surface",measure="text",catcher="box"}},
 ["menu.list"]={scope="menu",template=true,slotKinds={root="box",slider="box",thumb="texture",clip="box",canvas="box"}},
 ["menu.row"]={scope="menu",template=true,slotKinds={root="box",label="text",icon="texture",check="shape",hover="surface",surface="surface",mark="texture",meta="text"}},
}
local function Merge(into,source)
 for key,value in pairs(source or empty) do
  if type(value)=="table" and not value[1] then into[key]=Merge(type(into[key])=="table" and into[key] or {},value) else into[key]=value end
 end
 return into
end
local function Copy(value)
 if type(value)~="table" then return value end
 local out={};for key,item in pairs(value) do out[key]=Copy(item) end;return out
end
local function Words(value)
 if type(value)=="table" then return table.concat(value," ") end
 return value or ""
end
local function HasRules(rule)
 for _,part in pairs(rule.base or empty) do if next(part) then return true end end
 for _,group in pairs(rule.states or empty) do for _,part in pairs(group) do if next(part) then return true end end end
 for _,variant in pairs(rule.variants or empty) do if HasRules(variant) then return true end end
 return false
end
local utilities={}
Library.Utilities=utilities
for _,size in ipairs({0,1,2,3,4,6,8,10,12,14,16,18,20,24,28,30,32,36,40,44,48,56,64,80,96,100,120,160,200,240,300,400}) do
 utilities["w-"..size]={width=size};utilities["h-"..size]={height=size};utilities["size-"..size]={width=size,height=size};utilities["p-"..size]={padding=size}
end
for role in pairs(Library.TextStyles) do utilities["text-"..role]={fontSize=role,lineHeight=role} end
for _,color in ipairs({"text","muted","dim","brand","primary","good","warning","blue","onPrimary","surface","surfaceLow","surfaceHigh","secondaryContainer"}) do utilities["text-"..color]={color=color};utilities["bg-"..color]={base={surface={color=color}}} end
for _,alpha in ipairs({0,25,50,75,100}) do utilities["alpha-"..alpha]={alpha=alpha/100} end
utilities["single-line"]={singleLine=true,wordWrap=false};utilities["wrap"]={wordWrap=true};utilities["hidden"]={shown=false};utilities["shown"]={shown=true}
local function RuleShape(value)
 if value.base or value.states or value.classes or value.variants or value.slotKinds or value.scope or value.instances or value.template then return value end
 return {base={root=value}}
end
local function CompileUtilities(directory)
 local cache={};local resolving={}
 local Compile
 local function Named(name)
  if cache[name] then return cache[name] end
  local value=directory[name] or utilities[name]
  if not value then error("unknown utility: "..name,3) end
  if resolving[name] then error("cyclic utility: "..name,3) end
  resolving[name]=true;local result=Compile(value);resolving[name]=nil;cache[name]=result;return result
 end
 local strings={};local tables=setmetatable({},{__mode="k"})
 function Compile(input)
  local kind=type(input)
  if kind=="string" or kind=="table" and input[1] then
   local key=Words(input);if strings[key] then return strings[key] end
   local rule={}
   for token in key:gmatch("%S+") do
    local prefix,name=token:match("^([^:]+):(.+)$");if not prefix then name=token elseif not states[prefix] then error("unknown utility state: "..prefix,3) end
    local item=Named(name)
    if prefix then rule.states=rule.states or {};rule.states[prefix]=Merge(rule.states[prefix] or {},item.base)
    else Merge(rule,item) end
   end
   strings[key]=rule;return rule
  end
  if kind~="table" then error("utility rules must be a string or table",3) end
  if tables[input] then return tables[input] end
  local shape=RuleShape(input);local rule=shape.classes and Merge({},Compile(shape.classes)) or {}
  for _,key in ipairs({"base","states","variants"}) do if shape[key] then rule[key]=Merge(rule[key] or {},shape[key]) end end
  tables[input]=rule;return rule
 end
 return Compile
end
Library.CompileUtilities=CompileUtilities
local function ValidateRule(rule,theme,definition)
 if type(rule)~="table" then return false,"element rule must be a table" end
 for _,key in ipairs({"base","states","variants","instances","slotKinds"}) do if rule[key]~=nil and type(rule[key])~="table" then return false,"element "..key.." must be a table" end end
 for key in pairs(rule) do if key~="base" and key~="states" and key~="variants" and key~="classes" and key~="instances" and key~="scope" and key~="slotKinds" and key~="template" and not properties[key] then return false,"unknown element rule field: "..tostring(key) end end
 local function Part(part)
  if part~=nil and type(part)~="table" then return false,"element slots must be a table" end
  for slot,values in pairs(part or empty) do
   if type(slot)~="string" or type(values)~="table" then return false,"element slot properties must be a table: "..tostring(slot) end
   local declared=not definition or definition.slotKinds and definition.slotKinds[slot] or definition.base and definition.base[slot]
   if definition and not declared then return false,"unknown element slot: "..slot end
   for key,value in pairs(values) do
    if not properties[key] or not Library.ValidateStyleValue(key,value,theme) then return false,"invalid element property: "..slot.."."..tostring(key) end
    local kind=definition and definition.slotKinds and definition.slotKinds[slot]
    local allowed=kind and Library.StyleSlotKinds[kind] and Library.StyleSlotKinds[kind][key]
    if not allowed and slot=="root" and definition and definition.slotKinds and definition.slotKinds.label=="text" then allowed=Library.StyleSlotKinds.text[key] end
    if kind and not allowed then return false,"unsupported element property: "..slot.."."..key end
   end
  end
  return true
 end
 local valid,message=Part(rule.base);if not valid then return valid,message end
 for name,part in pairs(rule.states or empty) do if not states[name] then return false,"unknown element state: "..tostring(name) end;valid,message=Part(part);if not valid then return valid,message end end
 for _,variant in pairs(rule.variants or empty) do valid,message=ValidateRule(variant,theme,definition);if not valid then return valid,message end end
 return true
end
function Library:ValidateUtilities(directory,theme)
 if type(directory)~="table" then return false,"utilities must be a table" end
 local compile=CompileUtilities(directory);theme=theme or self.ResolveTheme()
 for name in pairs(directory) do
  local ok,rule=pcall(compile,name);if not ok then return false,rule end
  local valid,message=ValidateRule(rule,theme);if not valid then return valid,message end
 end
 return true
end
function Library:ValidateElements(overrides,defaults,theme,directory)
 if type(overrides)~="table" then return false,"elements must be a table" end
 if defaults~=nil and type(defaults)~="table" then return false,"element defaults must be a table" end
 theme=theme or self.ResolveTheme();local compile=CompileUtilities(directory or {})
 for id,entry in pairs(overrides) do
  if type(entry)~="table" then return false,"element rule must be a table: "..tostring(id) end
  local definition=defaults and defaults[id]
  if definition~=nil and type(definition)~="table" then return false,"element definition must be a table: "..tostring(id) end
  if defaults and not definition then return false,"unknown element: "..tostring(id) end
  if definition and (entry.slotKinds or entry.scope or entry.template~=nil) then return false,"element identity metadata is read-only: "..tostring(id) end
  if entry.slotKinds~=nil and type(entry.slotKinds)~="table" then return false,"element slotKinds must be a table" end
  for slot,kind in pairs(entry.slotKinds or empty) do if not Library.StyleSlotKinds[kind] then return false,"unknown element slot kind: "..tostring(slot) end end
  local ok,rule=pcall(compile,entry);if not ok then return false,rule end
  local valid,message=ValidateRule(rule,theme,definition);if not valid then return valid,message end
  valid,message=ValidateRule(entry,theme,definition);if not valid then return valid,message end
  for key,instance in pairs(entry.instances or empty) do
   local passed,compiled=pcall(compile,instance);if not passed then return false,compiled end
   valid,message=ValidateRule(compiled,theme,definition);if not valid then return valid,message end
   valid,message=ValidateRule(instance,theme,definition);if not valid then return valid,message end
  end
 end
 return true
end
local function Parse(path,defaults)
 local id,tail=path:match("^(.-)%.(base%..+)$")
 if not id then id,tail=path:match("^(.-)%.(states%..+)$") end
 if not id then id,tail=path:match("^(.-)%.(variants%..+)$") end
 if not id then id=path:match("^(.-)%.classes$");if id then return id,"classes" end end
 if not id or not defaults[id] then return nil end
 local parts={};for name in tail:gmatch("[^.]+") do parts[#parts+1]=name end
 return id,parts
end
function Library:GetElementField(path,defaults)
 defaults=defaults or self.ElementDefinitions;local id,parts=Parse(path,defaults);if not id or not defaults[id] then return nil end
 local definition=defaults[id]
 if parts=="classes" then return {type={"string","table"},types={"string","table"},default=Copy(definition.classes),ref=false} end
 local index=1;local branch=definition
 if parts[index]=="variants" then branch=definition.variants and definition.variants[parts[2]] or empty;index=3 end
 local section=parts[index];local slot,key
 if section=="base" then slot,key=parts[index+1],parts[index+2];if #parts~=index+2 then return nil end
 elseif section=="states" and states[parts[index+1]] then slot,key=parts[index+2],parts[index+3];if #parts~=index+3 then return nil end
 else return nil end
 if not properties[key] then return nil end
 local kind=definition.slotKinds and definition.slotKinds[slot]
 if not kind and not (definition.base and definition.base[slot]) then return nil end
 if kind and (not Library.StyleSlotKinds[kind] or not Library.StyleSlotKinds[kind][key]) then return nil end
 local part
 if section=="base" then part=branch.base and branch.base[slot] else local group=branch.states and branch.states[parts[index+1]];part=group and group[slot] end
 local value=part and part[key]
 local field=Library.StyleField(key,value);field.slotKind=kind;field.inherited=value==nil;return field
end
function Library:GetElementSchema(defaults,id,paths)
 local result={};defaults=defaults or self.ElementDefinitions
 local function Visit(value,path)
  for name,item in pairs(value) do local full=path.."."..name
   if properties[name] or name=="classes" then local field=self:GetElementField(full,defaults);if field then result[full]=field end
   elseif name~="slotKinds" and name~="scope" and type(item)=="table" then Visit(item,full) end
  end
 end
 if id then if defaults[id] then Visit(defaults[id],id) end else for name,entry in pairs(defaults) do Visit(entry,name) end end
 for _,path in ipairs(paths or empty) do if not result[path] then result[path]=self:GetElementField(path,defaults) end end
 return result
end
function Library:ListElementDefinitions(defaults,scope)
 local result={};for id,entry in pairs(defaults or self.ElementDefinitions) do if not scope or entry.scope==scope then result[#result+1]={id=id,scope=entry.scope,template=entry.template==true,slotKinds=Copy(entry.slotKinds)} end end
 table.sort(result,function(a,b) return a.id<b.id end);return result
end

function Library.AttachElements(UI)
 local C=UI.C
 UI.elementDefaults={};for id,entry in pairs(Library.ElementDefinitions) do UI.elementDefaults[id]=entry end;for id,entry in pairs(UI.options.elementDefaults or empty) do UI.elementDefaults[id]=entry end
 UI.elementOverrides=UI.options.elements or {};UI.utilities=UI.options.utilities or {}
 UI.elements=setmetatable({},{__mode="k"});UI.elementIndex={};UI.elementScopes={};UI.elementActive=setmetatable({},{__mode="k"});UI.elementReferences={}
 local compile=CompileUtilities(UI.utilities);local rules,aliases={},{}
 local function Slot(record,name)
  if not name or name=="root" then return record.target end
  local target=record.slots[name] or record.fallbackSlots and record.fallbackSlots[name]
  if target then return target end
  local family,key=name:match("^([^:]+):(.+)$");local host=record.target
  if family=="columns" then return host.labels and host.labels[key] or host.columns and host.columns[key]
  elseif family=="surface" then local count=0;for _,visual in ipairs(host._lycheeVisuals or empty) do if visual.SetColor then count=count+1;if count==tonumber(key) then return visual end end end
  elseif family=="columnButton" or family=="columnHandle" or family=="columnLine" then for index,definition in ipairs(host.definitions or empty) do if definition.key==key then local item=(family=="columnButton" and host.buttons or host.handles)[index];return family=="columnLine" and item.line or item end end end
  if name:find("/",1,true) then local item=record.slots;for part in name:gmatch("[^/]+") do item=item and item[tonumber(part) or part] end;return item end
  if name=="label" then return host.title elseif name=="icon" then return host.elementIcon elseif name=="surface" then
   if host.fill or host.alternate then return host.fill or host.alternate end
   for _,visual in ipairs(host._lycheeVisuals or empty) do if visual.SetColor then return visual end end
  end
 end
 local function Slots(record)
  if not record.resolvedSlots then
   record.resolvedSlots=setmetatable({root=record.target},{__index=function(_,name) return Slot(record,name) end})
  end
  return record.resolvedSlots
 end
 local function Identity(record)
  local group=UI.elementIndex[record.template or record.id]
  local key=record.key;if key==nil then key=false end;if group then group[key]=record.target end
  if record.id~=record.template and record.template then local own=UI.elementIndex[record.id];if own then own[key]=record.target end end
 end
 local function Unindex(record)
  for _,id in ipairs({record.id,record.template or record.id}) do local group=UI.elementIndex[id];local key=record.key;if key==nil then key=false end;if group and group[key]==record.target then group[key]=nil end end
 end
 -- Catalog-only entries describe capabilities but have no runtime style work.
 -- Inputs are immutable for a context, so negative results can be shared too.
 local declared=setmetatable({},{__mode="k"})
 local function HasDeclared(value)
  if not value then return false end
  if declared[value]~=nil then return declared[value] end
  local result=HasRules(value) or value.classes~=nil
  for _,part in pairs(value.instances or empty) do result=result or HasDeclared(part) end
  for _,part in pairs(value.variants or empty) do result=result or HasDeclared(part) end
  declared[value]=result;return result
 end
 local function BaseRule(id)
  local cached=rules[id]
  if not cached then
   local base=UI.elementDefaults[id] or empty;local override=UI.elementOverrides[id] or empty
   if not HasDeclared(base) and not HasDeclared(override) then rules[id]=empty;return empty end
   cached=Merge(Merge({},compile(base)),compile(override));rules[id]=cached
  end
  return cached
 end
 local function InstanceRule(combined,cached,id,key)
  for index=1,2 do
   local directory=index==1 and UI.elementDefaults or UI.elementOverrides;local entry=directory[id];local part=entry and entry.instances and entry.instances[key]
   if part then if combined==cached then combined=Merge({},cached) end;Merge(combined,compile(part)) end
  end
  return combined
 end
 local function Rules(record)
  local template=record.template or record.id;local id=record.id;local cached=BaseRule(template)
  if cached==empty and BaseRule(id)==empty and not record.classes then return empty end
  if template~=id then
   local group=aliases[template] or {};aliases[template]=group
   if not group[id] then group[id]=Merge(Merge({},cached),BaseRule(id)) end;cached=group[id]
  end
  if not record.instanceRules or record.ruleBase~=cached then
   local combined=cached
   combined=InstanceRule(combined,cached,template,record.key);if id~=template then combined=InstanceRule(combined,cached,id,record.key) end
   record.instanceRules,record.ruleBase=combined,cached
  end
  cached=record.instanceRules
  if record.classes then
   if not record.classRules or record.classBase~=cached then record.classRules=Merge(Merge({},cached),compile(record.classes));record.classBase=cached end
   return record.classRules
  end
  return cached
 end
 local heightKeys={"height","minHeight","maxHeight"}
 local function HasHeightPart(part)
  local root=part and part.root or empty
  for _,key in ipairs(heightKeys) do if root[key]~=nil then return true end end
  return false
 end
 local function HasHeightRules(rule)
  if HasHeightPart(rule.base) then return true end
  for _,part in pairs(rule.states or empty) do if HasHeightPart(part) then return true end end
  for _,part in pairs(rule.variants or empty) do if HasHeightRules(part) then return true end end
  return false
 end
 local function HasListHeightRules(list)
  local id=list.elementTemplate;if not id then return false end
  if HasHeightRules(BaseRule(id)) then return true end
  for _,directory in ipairs({UI.elementDefaults,UI.elementOverrides}) do
   local entry=directory[id]
   for _,part in pairs(entry and entry.instances or empty) do if HasHeightRules(compile(part)) then return true end end
  end
  return false
 end
 UI.elementLists=setmetatable({},{__mode="k"})
 local function GeometryPart(part,height,minHeight,maxHeight)
  local root=part and part.root
  if root then
   if root.height~=nil then height=Library.ResolveStyleValue(root.height,"height",UI.Theme,UI.fontScale) end
   if root.minHeight~=nil then minHeight=Library.ResolveStyleValue(root.minHeight,"minHeight",UI.Theme,UI.fontScale) end
   if root.maxHeight~=nil then maxHeight=Library.ResolveStyleValue(root.maxHeight,"maxHeight",UI.Theme,UI.fontScale) end
  end
  return height,minHeight,maxHeight
 end
 function UI:ResolveListElementHeight(list,key,fallback,row,index)
  if row and not list.rowElementState then
   local value=C.ElementValue(row,"root","height",fallback)
   value=math.max(C.ElementValue(row,"root","minHeight",0),math.min(C.ElementValue(row,"root","maxHeight",math.huge),value))
   return value
  end
  local current=row and UI.elements[row]
  local elementKey=list:GetElementKey(key,index)
  local record=current
  if not record or record.key~=elementKey then
   record=list._elementHeightRecord
   if not record then record={};list._elementHeightRecord=record end
   record.id=current and current.id or list.elementTemplate;record.template=current and current.template
   record.key=elementKey;record.instanceRules=nil
   record.classes=current and current.classes;record.classRules=nil
  end
  local controller=row and row._lycheeStyleController
  local variant=controller and controller.options.variant or current and current.variant or list.elementVariant
  local rule=Library.ResolveStyleVariant(Rules(record),variant)
  local height,minHeight,maxHeight=fallback,0,math.huge
  height,minHeight,maxHeight=GeometryPart(rule.base,height,minHeight,maxHeight)
  if list.rowElementState then
   local active=list._elementHeightStates
   if not active then active={};list._elementHeightStates=active end
   for _,name in ipairs(stateOrder) do
    local value=controller and controller.active[name]==true or false
    if name=="selected" then value=key==list.selectedKey end
    local supplied
    if name=="checked" or name=="disabled" then supplied=list.rowElementState(key,index,name) end
    active[name]=supplied==nil and value or supplied==true
   end
   if active.disabled then active.hover,active.pressed=false,false end
   for _,name in ipairs(stateOrder) do if active[name] then height,minHeight,maxHeight=GeometryPart(rule.states and rule.states[name],height,minHeight,maxHeight) end end
  elseif key==list.selectedKey then height,minHeight,maxHeight=GeometryPart(rule.states and rule.states.selected,height,minHeight,maxHeight) end
  return math.max(minHeight,math.min(maxHeight,height))
 end
 local bindingOptions={}
 local function BindElementStates(record,controller)
  local owner=record.stateOwner;if not owner then return end
  local hover,pressed,focus=false,false,false
  for _,name in ipairs(controller.stateOrder) do
   if name=="hover" then hover=true elseif name=="pressed" then pressed=true elseif name=="focus" and owner.GetObjectType and owner:GetObjectType()=="EditBox" then focus=true end
  end
  local mask=(hover and 1 or 0)+(pressed and 2 or 0)+(focus and 4 or 0)
  local bound=record.boundController==controller and record.bound or 0
  if mask==0 then return end
  local added=(hover and bound%2==0 and 1 or 0)+(pressed and math.floor(bound/2)%2==0 and 2 or 0)+(focus and math.floor(bound/4)%2==0 and 4 or 0)
  if added==0 then return end
  local options=bindingOptions[mask]
  if not options then options={hover=hover,pressed=pressed,focus=focus};bindingOptions[mask]=options end
  controller:Bind(owner,options)
  record.bound=bound+added;record.boundController=controller
 end
 local function Apply(record)
  if record.owner and not record.owner:IsOwned() then return record.target end
  local rule=Rules(record);local active=HasRules(rule)
  if not active and not record.applied then return record.target end
  UI.elementActive[record.target]=active and true or nil
  local scope=record.scope or false;local group=UI.elementScopes[scope]
  if not group then group=setmetatable({},{__mode="k"});UI.elementScopes[scope]=group end
  group[record.target]=active and true or nil
  for id,targets in pairs(UI.elementReferences) do targets[record.target]=nil end
  local function References(part)
   for _,values in pairs(part or empty) do for _,point in ipairs(values.points or empty) do local reference=point[2]
    if type(reference)=="string" and reference:sub(1,1)=="@" then local id=reference:match("^@([^#]+)");if not UI.elementIndex[id] then UI.elementIndex[id]=setmetatable({},{__mode="v"});for _,other in pairs(UI.elements) do if other.id==id or other.template==id then local key=other.key;if key==nil then key=false end;UI.elementIndex[id][key]=other.target end end end;local targets=UI.elementReferences[id] or setmetatable({},{__mode="k"});UI.elementReferences[id]=targets;targets[record.target]=true end
   end end
  end
  local function RuleReferences(value) References(value.base);for _,part in pairs(value.states or empty) do References(part) end;for _,variant in pairs(value.variants or empty) do RuleReferences(variant) end end
  RuleReferences(rule)
  if active or record.applied then
   for _,part in ipairs({rule.base or empty}) do for name,values in pairs(part) do local target=Slot(record,name);if target then for key in pairs(values) do if not C.ValidateStyleTarget(target,key) then error("unsupported element target: "..record.id.."."..name.."."..key,3) end end end end end
   local existing=record.target._lycheeStyleController;if existing and record.variant~=nil then existing.options.variant=record.variant end
   local controller=UI:_BindFixedElement(record.target,active and rule or nil,Slots(record),record.variant);record.applied=active
   if controller and record.variant~=nil and controller.options.variant~=record.variant then controller:SetVariant(record.variant) end
   if active then BindElementStates(record,controller) end
  end
  return record.target
 end
 function C.ResolveElementReference(target,reference,root)
  local host=root or target;local record=UI.elements[host]
  if reference=="$parent" then return target:GetParent() elseif reference=="$root" then return host
  elseif reference:sub(1,1)=="$" then return record and Slot(record,reference:sub(2))
  elseif reference:sub(1,1)=="@" then local id,slot=reference:match("^@([^#]+)#?(.*)$");return UI:_FindAnchor(id,slot~="" and slot or nil) end
  return _G[reference]
 end
 function C.Element(target,id,options)
  options=options or {};local record=UI.elements[target]
  if record and record.id==id and record.template==options.template and record.key==options.key and record.scope==options.scope and record.slots==(options.slots or target) and record.classes==options.classes and record.variant==options.variant and record.owner==options.owner and (not options.stateOwner or record.stateOwner==options.stateOwner) and (not options.rowTemplate or target.elementTemplate==options.rowTemplate) and (not options.rowElementKey or target.rowElementKey==options.rowElementKey) and (not options.rowElementState or target.rowElementState==options.rowElementState) then return Apply(record) end
  if record then Unindex(record);if record.applied then UI:_BindFixedElement(target,nil,Slots(record)) end end
  local controller=target._lycheeStyleController
  local kind=target.GetObjectType and target:GetObjectType()
  local stateOwner=options.stateOwner
  if stateOwner==nil and not controller and target.HookScript and kind~="Texture" and kind~="MaskTexture" and kind~="FontString" then stateOwner=target end
  -- Do not reserve hash slots for absent optional identity fields.
  record={target=target,id=id,slots=options.slots or target}
  if options.template~=nil then record.template=options.template end
  if options.key~=nil then record.key=options.key end
  if options.scope~=nil then record.scope=options.scope end
  if options.classes~=nil then record.classes=options.classes end
  if options.owner~=nil then record.owner=options.owner end
  if stateOwner~=nil then record.stateOwner=stateOwner end
  if options.variant~=nil then record.variant=options.variant end
  if controller then record.fallbackSlots=controller.slots end
  UI.elements[target]=record
  if not UI.elementDefaults[id] and not UI.elementDefaults[record.template or id] then UI.elementDefaults[id]={base={root={}}} end
  local list=target._lycheeList
  if list and not UI.elementLists[list] then
   UI.elementLists[list]=true
   list.bodyHeight=list.rowStyle and UI:ResolveValue(list.rowStyle.rowHeight) or list.rows[1] and list.rows[1]:GetHeight() or list.bodyHeight
   list.elementHeights=HasListHeightRules(list)
   if list.elementHeights then list.geometryDirty=true end
  end
  target._lycheeElementOwner=options.owner;Identity(record);Apply(record)
  if options.rowTemplate or target.elementTemplate then
   local previousTemplate=target.elementTemplate
   target.elementTemplate=options.rowTemplate or target.elementTemplate;target.elementScope=options.scope;target.elementRowSlots=options.rowSlots
   target.rowElementKey=options.rowElementKey or target.rowElementKey
   target.rowElementState=options.rowElementState or target.rowElementState
   if previousTemplate~=target.elementTemplate then target._elementHeightRecord=nil end
   target.elementHeights=HasListHeightRules(target);UI.elementLists[target]=true
   if target.elementHeights then target.geometryDirty=true end
   for _,row in ipairs(target.rows or empty) do C.Element(row,target.elementTemplate,{template=target.elementTemplate,key=target:GetElementKey(row.key,row._lycheeListIndex),scope=options.scope,slots=options.rowSlots or row});row._lycheeElementRegistered=true end
  end
  -- Reconnect explicitly registered semantic anchors only on registry mutations.
  for other in pairs(UI.elementReferences[id] or empty) do if other~=target then C.ApplyElement(other) end end
  return target
 end
 function C.RekeyElement(target,key,template)
  local record=UI.elements[target];if not record then return target end
  if record.key==key and (not template or record.template==template) then return target end
  Unindex(record);if record.applied then UI:_BindFixedElement(target,nil,Slots(record)) end
  record.key=key;if template then record.template=template end;record.classRules=nil;record.instanceRules=nil;Identity(record);return Apply(record)
 end
 function C.ReleaseElement(target)
  local record=UI.elements[target];if not record then return target end
  Unindex(record);if record.applied then
   if record.owner and not record.owner:IsOwned() then
    local controller=target._lycheeStyleController;if controller then controller:Release(true) end
   else UI:_BindFixedElement(target,nil,Slots(record)) end
  end
  target._lycheeElementOwner=nil;UI.elements[target]=nil;UI.elementActive[target]=nil
  local group=UI.elementScopes[record.scope or false];if group then group[target]=nil end
  return target
 end
 function C.ApplyElement(target) local record=UI.elements[target];if record and record.applied and (not record.owner or record.owner:IsOwned()) then local controller=target._lycheeStyleController;if controller then controller:Apply(true) end end;return target end
 function C.SetElementState(target,name,value) local controller=target._lycheeStyleController;if controller then controller:SetState(name,value) end;return target end
 function UI:_FindAnchor(id,slot,key)
  local group=UI.elementIndex[id];if key==nil then key=false end;local target=group and group[key]
  local record=target and UI.elements[target];return record and Slot(record,slot)
 end
 function UI:GetElementField(path) return Library:GetElementField(path,self.elementDefaults) end
 function UI:GetElementSchema(id,paths) return Library:GetElementSchema(self.elementDefaults,id,paths) end
 function UI:ApplyElements(scope)
  local group=self.elementActive;if scope then group=self.elementScopes[scope] end
  for target in pairs(group or empty) do C.ApplyElement(target) end
 end
 local function RuleValue(rule,slot,key,controller)
  if not rule then return end
  local part=rule.base and rule.base[slot];local value=part and part[key]
  if controller and rule.states then for _,name in ipairs(stateOrder) do local group=rule.states[name];part=group and group[slot];if controller.active[name] and part and part[key]~=nil then value=part[key] end end end
  return value
 end
 function C.ElementValue(target,slot,key,fallback)
  local record=UI.elements[target];if not record then return fallback end
  slot=slot or "root"
  local controller=target._lycheeStyleController
  local value=RuleValue(Library.ResolveStyleVariant(Rules(record),controller and controller.options.variant or record.variant),slot,key,controller)
  local native=Slot(record,slot)
  if native then local shared,hasShared=C.SharedElementValue(native,key);if hasShared then value=shared end end
  if value==nil then return fallback end
  if key=="points" then return value end
  return Library.ResolveStyleValue(value,key,UI.Theme,UI.fontScale)
 end
 function UI:GetElementValue(id,slot,key,fallback,businessKey,variant) return self:ResolveElementValue(id,slot,key,fallback,businessKey,variant) end
 function UI:ResolveElementValue(id,slot,key,fallback,businessKey,variant)
  local rule=Library.ResolveStyleVariant(Rules({id=id,key=businessKey}),variant);local part=rule.base and rule.base[slot or "root"];local value=part and part[key]
  if value==nil then return fallback end;return Library.ResolveStyleValue(value,key,self.Theme,self.fontScale)
 end
 local valid,message=Library:ValidateUtilities(UI.utilities,UI.Theme);if not valid then error(message,2) end
 valid,message=Library:ValidateElements(UI.elementDefaults,nil,UI.Theme,UI.utilities);if not valid then error(message,2) end
 valid,message=Library:ValidateElements(UI.elementOverrides,UI.elementDefaults,UI.Theme,UI.utilities);if not valid then error(message,2) end
end
