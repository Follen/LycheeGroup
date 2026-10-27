-- Startup-only theme assembly and explicit live preference bridges.
local A=_G.LycheeGroup
local Library=_G.LycheeUI
local Configuration=A.Configuration
local Appearance={tableStates={}}
A.Appearance=Appearance
local definitions={}
local function Clone(value)
 if type(value)~="table" then return value end
 local copy={};for key,item in pairs(value) do copy[key]=Clone(item) end;return copy
end
local function ThemeField(scope,token)
 if token=="font" then return end
 local field=Library:GetThemeField(token,A.StyleDefaults[scope]);if not field then return end
 if token=="settingsLabelRatio" then field.min,field.max=0,1 end
 field.storage="account";return field
end
local function Position(value)
 if value==false then return true end
 if type(value)~="table" then return false,"expected false or an anchor position" end
 local anchors={TOPLEFT=true,TOP=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,BOTTOMLEFT=true,BOTTOM=true,BOTTOMRIGHT=true}
 return anchors[value.point] and anchors[value.relativePoint] and type(value.x)=="number" and type(value.y)=="number",
  "position requires valid point/relativePoint anchors and numeric x/y"
end
local layoutDefaults=A.ThemeDefaults.layout
definitions["layout.window.width"]={default=layoutDefaults.window.width,type="number",min=1,storage="character",legacy={path={"windowSize","width"}}}
definitions["layout.window.height"]={default=layoutDefaults.window.height,type="number",min=1,storage="character",legacy={path={"windowSize","height"}}}
definitions["layout.floating.position"]={default=layoutDefaults.floating.position,type={"table","boolean"},validate=Position,storage="account",legacy={key="floatingPosition"}}
definitions["layout.find.railCollapsed"]={default=layoutDefaults.find.railCollapsed,type="boolean",storage="character",legacy={path={"find","railCollapsed"}}}

local tables={
 findResults={columns={"title","activity","leader","members","ilvl","rating","description","age"},sorts={"activity","members","ilvl","rating","age"}},
 findRaidResults={columns={"title","activity","leader","members","ilvl","rating","description","age"},sorts={"activity","members","ilvl","rating","age"}},
 findApplications={columns={"title","activity","leader","members","status","actions"},sorts={"members","status"}},
 createApplicants={columns={"name","role","faction","rating","mapScore","ilvl","comment","actions"},sorts={"rating","mapScore","ilvl"}},
 notesRecords={columns={"player","timestamp"},sorts={"timestamp"}},
 notesHistory={columns={"activity","level","duration","teammates","completed"},sorts={"level","duration","completed"}},
 notesHistoryMembers={columns={"player","actions"},sorts={}},
 blockedLeaders={columns={"name","realm","actions"},sorts={}},
}
local stateIDs=setmetatable({},{__mode="k"})
local function TableKey(id,field) return "layout.tables."..id.."."..field end
local function ImportFindWidths(id)
 local snapshot,combinedTitle
 return function(character,column)
  local layouts=character.tableLayouts
  local layout=type(layouts)=="table" and layouts[id]
  local widths=type(layout)=="table" and layout.widths
  if type(widths)~="table" then return end
  if snapshot~=character then
   snapshot=character
   local store=Configuration.stores.character
   local titleKey=TableKey(id,"widths.title")
   -- Decide once for both leaves, before either import changes the store.
   -- Existing canonical choices/imports make a title-only mirror ambiguous.
   combinedTitle=widths.activity==nil and type(widths.title)=="number" and store.user[titleKey]==nil and not store.imported[titleKey] and widths.title or nil
  end
  -- Only the captured legacy table layout used one combined title/activity
  -- column. Current Configuration values always describe individual columns.
  if combinedTitle then return combinedTitle*(column=="title" and .45 or .55) end
  return widths[column]
 end
end
for id,info in pairs(tables) do
 local defaults=layoutDefaults.tables[id]
 local importFind=(id=="findResults" or id=="findRaidResults" or id=="findApplications") and ImportFindWidths(id)
 local sortChoices={false};for _,key in ipairs(info.sorts) do sortChoices[#sortChoices+1]=key end
 definitions[TableKey(id,"sortKey")]={default=defaults.sortKey,type={"string","boolean"},enum=sortChoices,storage="character",legacy={path={"tableLayouts",id,"sortKey"}}}
 definitions[TableKey(id,"descending")]={default=defaults.descending,type="boolean",storage="character",legacy={path={"tableLayouts",id,"descending"}}}
 for _,column in ipairs(info.columns) do
  local field={default=defaults.widths[column],type="number",min=.001,storage="character",legacy={path={"tableLayouts",id,"widths",column}}}
  if importFind and (column=="title" or column=="activity") then
   local name=column;field.import=function(_,character) return importFind(character,name) end
  end
  definitions[TableKey(id,"widths."..column)]=field
 end
end
assert(Configuration:RegisterDefinitions(definitions))
local function SetPath(root,path,value)
 local parent=root
 local parts={};for part in path:gmatch("[^.]+") do parts[#parts+1]=part end
 for i=1,#parts-1 do local part=parts[i];parent[part]=parent[part] or {};parent=parent[part] end
 parent[parts[#parts]]=value
end
local function ElementParts(scope,path)
 local selected
 for id in pairs(A.ThemeDefaults.appearance[scope].elements or {}) do
  if path:sub(1,#id+1)==id.."." and (not selected or #id>#selected) then selected=id end
 end
 if selected then return selected,path:sub(#selected+2) end
end
local function EncodeKey(key)
 local kind=type(key)
 if kind~="string" and kind~="number" then return nil,"element instance key must be a string or number" end
 if kind=="number" and (key~=key or key==math.huge or key==-math.huge) then return nil,"element instance key must be finite" end
 return (kind=="number" and "n:" or "s:")..tostring(key):gsub("[.%%%c]",function(char) return string.format("%%%02X",string.byte(char)) end)
end
local function DecodeKey(key)
 local kind,value=key:match("^([ns]):(.*)$");if not kind then return nil end
 if value:gsub("%%[%x][%x]",""):find("%",1,true) then return nil end
 value=value:gsub("%%([%x][%x])",function(hex) return string.char(tonumber(hex,16)) end)
 if kind=="s" then return value end
 local number=tonumber(value)
 if number and number==number and number~=math.huge and number~=-math.huge then return number end
end
local function ElementField(scope,path)
 local property=path:match("([^.]+)$")
 if property~="classes" and not Library.StyleProperties[property] then return end
 local id,part=ElementParts(scope,path);if not id then return end
 local encoded,leaf=part:match("^instances%.([^.]+)%.(.+)$")
 if encoded then
  if not A.ThemeDefaults.appearance[scope].elements[id].template then return end
  local key=DecodeKey(encoded)
  if key==nil or EncodeKey(key)~=encoded then return end
  local field=Library:GetElementField(id.."."..leaf,A.ThemeDefaults.appearance[scope].elements)
  if field then field.default=nil;field.inherited=true end
  return field
 end
 return Library:GetElementField(path,A.ThemeDefaults.appearance[scope].elements)
end
local elementStates={selected=true,checked=true,hover=true,pressed=true,focus=true,disabled=true}
local function ElementBranch(scope,id,path)
 local definition=A.ThemeDefaults.appearance[scope].elements[id]
 local relative=path==id and "" or path:sub(#id+2)
 local encoded,tail=relative:match("^instances%.([^.]+)%.?(.*)$")
 if encoded then
  local key=DecodeKey(encoded)
  if not definition.template or key==nil or EncodeKey(key)~=encoded then return false end
  relative=tail
 end
 if relative=="" then return true end
 while relative:match("^variants%.") do
  local name,rest=relative:match("^variants%.([^.]+)%.?(.*)$")
  if not name then return false end
  relative=rest
  if relative=="" then return true end
 end
 if relative=="variants" or relative=="base" or relative=="states" then return true end
 local slot=relative:match("^base%.([^.]+)$")
 if not slot then
  local state;state,slot=relative:match("^states%.([^.]+)%.([^.]+)$")
  if state and not elementStates[state] then return false end
  local name=relative:match("^states%.([^.]+)$")
  if name then return elementStates[name]==true end
 end
 return slot~=nil and (definition.slotKinds and definition.slotKinds[slot]~=nil or definition.base and definition.base[slot]~=nil)
end
function Appearance:FlattenElements(scope,entries,values)
 if type(entries)~="table" then return nil,"elements must be an element/rule table" end
 values=values or {}
 local defaults=A.ThemeDefaults.appearance[scope].elements or {}
 local function Visit(value,path,id)
  local field=ElementField(scope,path)
  if field then values["element."..scope.."."..path]=value;return true end
  if type(value)~="table" or not ElementBranch(scope,id,path) then return false,"unknown element configuration path: "..path end
  for name,item in pairs(value) do
   if type(name)~="string" or name=="slotKinds" then return false,"element styles require named properties; slotKinds cannot be imported" end
   if name=="instances" then
    if path~=id or not defaults[id].template then return false,"instances require an element template root: "..path end
    if type(item)~="table" then return false,"element instances must be a key/rule table" end
    for key,rule in pairs(item) do
     local encoded,reason=EncodeKey(key);if not encoded then return false,reason end
     local ok,err=Visit(rule,path..".instances."..encoded,id);if not ok then return false,err end
    end
   else local ok,err=Visit(item,path.."."..name,id);if not ok then return false,err end end
  end
  return true
 end
 for id,entry in pairs(entries) do
  if not defaults[id] then return nil,"unknown element id: "..tostring(id) end
  if type(entry)=="table" and entry.instances~=nil and not defaults[id].template then return nil,"element is not an instance template: "..id end
  local ok,err=Visit(entry,id,id);if not ok then return nil,err end
 end
 return values
end
function Appearance:GetField(key)
 if type(key)~="string" then return end
 local kind,scope,path=key:match("^([^.]+)%.([^.]+)%.(.+)$")
 if not A.StyleDefaults[scope] then return end
 local field
 if kind=="theme" then field=ThemeField(scope,path)
 elseif kind=="style" then field=Library:GetStyleField(path,A.ThemeDefaults.appearance[scope].components)
 elseif kind=="element" then field=ElementField(scope,path)
 elseif kind=="utility" and path:match("^[%w][%w_.%-]*$") then field={type="table"} end
 if field then field.type,field.storage=field.types or field.type,"account" end
 return field
end
function Appearance:GetPreferenceField(key)
 if type(key)~="string" then return end
 local name=key:match("^settings%.(.+)$")
 if name and A.ThemeDefaults.settings[name]~=nil or key:match("^layout%.") then return Configuration.definitions[key] end
end
function Appearance:WriteDeclaration(definition,key,value)
 local kind,scope,path=key:match("^([^.]+)%.([^.]+)%.(.+)$")
 if kind=="settings" or key:match("^settings%.") then definition.settings=definition.settings or {};definition.settings[key:sub(10)]=value;return end
 if kind=="layout" then definition.layout=definition.layout or {};SetPath(definition.layout,key:sub(8),value);return end
 definition.appearance=definition.appearance or {};local appearance=definition.appearance[scope] or {};definition.appearance[scope]=appearance
 if kind=="theme" then appearance.tokens=appearance.tokens or {};appearance.tokens[path]=value
 elseif kind=="style" then appearance.components=appearance.components or {};SetPath(appearance.components,path,value)
 elseif kind=="utility" then appearance.utilities=appearance.utilities or {};appearance.utilities[path]=value
 elseif kind=="element" then
  appearance.elements=appearance.elements or {};local id,leaf=ElementParts(scope,path);local rule=appearance.elements[id] or {};appearance.elements[id]=rule
  local encoded,relative=leaf:match("^instances%.([^.]+)%.(.+)$")
  if encoded then local instance=DecodeKey(encoded);rule.instances=rule.instances or {};rule.instances[instance]=rule.instances[instance] or {};SetPath(rule.instances[instance],relative,value)
  else SetPath(rule,leaf,value) end
 end
end
local function Layer(into,source,rank,ranks)
 for key,value in pairs(source) do into[key]=value;ranks[key]=rank end
end
function Appearance:Compile(source)
 if source.error then return nil,source.error end
 for _,layer in ipairs({{name="theme values",value=source.values,preferences=true},{name="account overrides",value=source.overrides.account},{name="character overrides",value=source.overrides.character}}) do
  if layer.value~=nil then
   if type(layer.value)~="table" then return nil,layer.name.." must be a flat key/value table" end
   local ok,err=Configuration:CheckSerializable(layer.value);if not ok then return nil,layer.name..": "..err end
   for key in pairs(layer.value) do
    if type(key)~="string" then return nil,layer.name.." requires named keys: "..tostring(key) end
    if (key:match("^settings%.") or key:match("^layout%.")) and (not layer.preferences or not self:GetPreferenceField(key)) then return nil,layer.name.." contains an unsupported preference: "..key end
   end
  end
 end
 local values,ranks={},{}
 Layer(values,source.values or {},1,ranks)
 Layer(values,source.overrides.account or {},2,ranks)
 Layer(values,source.overrides.character or {},3,ranks)
 local result={selection=source.selection,source=source,preferences={},scopes={}}
 for key,value in pairs(source.values or {}) do if key:match("^settings%.") or key:match("^layout%.") then
  local field=self:GetPreferenceField(key);if not field then return nil,"unknown theme preference: "..key end
  local ok,err=Configuration:ValidateField(field,value);if not ok then return nil,key..": "..err end
  result.preferences[key]=value
 end end
 for key,value in pairs(values) do
  if not key:match("^settings%.") and not key:match("^layout%.") then
   local field=self:GetField(key);if not field then return nil,"unknown theme path: "..key end
   local ok,err=Configuration:ValidateField(field,value);if not ok then return nil,key..": "..err end
  end
 end
 for scope,defaults in pairs(A.StyleDefaults) do
  local part={theme={},recipes={},elements={},utilities={}};result.scopes[scope]=part
  for name,rule in pairs(A.ThemeDefaults.appearance[scope].utilities or {}) do part.utilities[name]=rule end
  for key,value in pairs(values) do
   local kind,owner,path=key:match("^([^.]+)%.([^.]+)%.(.+)$")
   if owner==scope then
    if kind=="theme" then part.theme[path]=value
    elseif kind=="style" then SetPath(part.recipes,path,value)
    elseif kind=="utility" then part.utilities[path]=value
    elseif kind=="element" then
     local id,leaf=ElementParts(scope,path);local entry=part.elements[id] or {};part.elements[id]=entry
     local encoded,relative=leaf:match("^instances%.([^.]+)%.(.+)$")
     if encoded then
      local instance=DecodeKey(encoded);entry.instances=entry.instances or {};entry.instances[instance]=entry.instances[instance] or {};SetPath(entry.instances[instance],relative,value)
     else SetPath(entry,leaf,value) end
    end
   end
  end
  local prefix="theme."..scope.."."
  for canonical,group in pairs(Library.TypographyAliases) do
   local selected,priority=nil,0
   local function Consider(token)local rank=ranks[prefix..token] or 0;if rank>priority then selected,priority=token,rank end end
   Consider(canonical);for _,token in ipairs(group.aliases) do Consider(token) end
   local value=selected and part.theme[selected]
   for _,token in ipairs(group.aliases) do part.theme[token]=nil end
   if selected then part.theme[canonical]=value end
  end
  if ranks[prefix.."media"] and not ranks[prefix.."productMedia"] then part.theme.productMedia=part.theme.media end
  local ok,err,resolved=Library:ValidateTheme(part.theme,defaults);if not ok then return nil,scope..": "..err end
  part.resolved=resolved
  ok,err=Library:ValidateRecipes(part.recipes,A.ThemeDefaults.appearance[scope].components,resolved);if not ok then return nil,scope..": "..err end
  ok,err=Library:ValidateUtilities(part.utilities,resolved);if not ok then return nil,scope..": "..err end
  ok,err=Library:ValidateElements(part.elements,A.ThemeDefaults.appearance[scope].elements,resolved,part.utilities);if not ok then return nil,scope..": "..err end
  ok,err=Library:ValidateElements(A.ThemeDefaults.appearance[scope].elements or {},nil,resolved,part.utilities);if not ok then return nil,scope..": "..err end
 end
 return result
end
local function Current(scope)
 Configuration:EnsureReady();return A.RuntimeTheme.scopes[scope]
end
function Appearance:GetTheme(scope) return Current(scope).theme end
function Appearance:GetResolvedTheme(scope) return Current(scope).resolved end
function Appearance:GetRecipes(scope) return Current(scope).recipes end
function Appearance:GetElements(scope) return Current(scope).elements end
function Appearance:GetUtilities(scope) return Current(scope).utilities end
function Appearance:RefreshTableState(id)
 local state=self.tableStates[id]
 if not state then state={};self.tableStates[id]=state;stateIDs[state]=id end
 local widths={}
 for _,column in ipairs(tables[id].columns) do widths[column]=Configuration:Get(TableKey(id,"widths."..column)) end
 state.widths=next(widths) and widths or nil
 state.sortKey=Configuration:Get(TableKey(id,"sortKey")) or nil
 state.descending=Configuration:Get(TableKey(id,"descending"))
 return state
end
function Appearance:GetTableState(id)
 return self.tableStates[id] or self:RefreshTableState(id)
end
function Appearance:GetTableID(state) return stateIDs[state] end
function Appearance:SaveTableState(header,changes)
 local id=stateIDs[header.state]
 if not id then return end -- Preview headers use their provider's private state.
 local values={}
 self.savingTable=id
 local ok,err
 if changes.widths==false then
  local keys={};for _,column in ipairs(tables[id].columns) do keys[#keys+1]=TableKey(id,"widths."..column) end
  ok,err=Configuration:Reset(keys,{storage="character"})
  self.savingTable=nil
  -- Clearing a user width may reveal a preset width in the same existing header.
  -- Equal-value resets emit no change, but ResetWidths already cleared the view.
  if ok then
   self:RefreshTableState(id)
   if header.layoutWidth then header:Layout(header.layoutWidth) end
  end
  return ok,err
 elseif changes.widths then
  for column,width in pairs(changes.widths) do values[TableKey(id,"widths."..column)]=width end
 end
 if changes.descending~=nil then
  values[TableKey(id,"sortKey")]=changes.sortKey or false
  values[TableKey(id,"descending")]=changes.descending
 end
 ok,err=Configuration:Set(values,{storage="character"})
 self.savingTable=nil
 return ok,err
end
function Appearance:GetWindowSize()
 return Configuration:Get("layout.window.width"),Configuration:Get("layout.window.height")
end
function Appearance:SaveWindowSize(width,height)
 return Configuration:Set({["layout.window.width"]=width,["layout.window.height"]=height},{storage="character"})
end
function Appearance:GetFloatingPosition() return Configuration:Get("layout.floating.position") end
function Appearance:SaveFloatingPosition(position)
 return Configuration:Set({["layout.floating.position"]=position or false},{storage="account"})
end
function Appearance:GetRailCollapsed() return Configuration:Get("layout.find.railCollapsed") end
function Appearance:SaveRailCollapsed(collapsed)
 self.savingRail=true
 local ok,err=Configuration:Set({["layout.find.railCollapsed"]=collapsed==true},{storage="character"})
 self.savingRail=nil
 return ok,err
end

function A:OnConfigurationChanged(changes)
 local changedTables={};local window,position,rail,settings
 for key in pairs(changes) do
  if key:sub(1,9)=="settings." then settings=true end
  local id=key:match("^layout%.tables%.([^.]+)%.");if id then changedTables[id]=true end
  if key=="layout.window.width" or key=="layout.window.height" then window=true end
  if key=="layout.floating.position" then position=true end
  if key=="layout.find.railCollapsed" then rail=true end
 end
 local ui=self.UI
 -- A header's Layout commits its current drag. Cancel the old geometry before
 -- refreshing its shared state so it cannot replace a newly resolved default.
 if next(changedTables) and ui and ui.context then for header in pairs(ui.context.tableHeaders or {}) do
  if changedTables[Appearance:GetTableID(header.state)] then header:StopDrag(false) end
 end end
 for id in pairs(changedTables) do Appearance:RefreshTableState(id) end
 if Appearance.savingTable then changedTables[Appearance.savingTable]=nil end
 if Appearance.savingRail then rail=nil end
 if position and self.Floating and self.Floating.frame then self.Floating:ResetPosition(true) end
 if ui and ui.frame then
  if window then ui:LoadWindowSize();ui:RefreshWindowSize() end
  if (next(changedTables) or rail) and ui.OnLayoutPreferencesChanged then ui:OnLayoutPreferencesChanged(changedTables,rail) end
  if settings and not changes["settings.font"] and not changes["settings.fontScale"] and ui.pages.settings.frame then ui.pages.settings:Sync() end
 end
end
A.API=A.API or {}
local API={version=2};A.API.Appearance=API
local function Scope(scope) if not A.StyleDefaults[scope] then return false,"unknown appearance scope: "..tostring(scope) end;return true end
function API:GetSchema(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local fields=Library:GetThemeSchema(A.StyleDefaults[scope]);fields.font=nil
 for token in pairs(fields) do fields[token]=ThemeField(scope,token) end
 return fields
end
function API:GetStyleSchema(scope,paths)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local fields=Library:GetStyleSchema(A.ThemeDefaults.appearance[scope].components,paths)
 for _,field in pairs(fields) do field.type,field.storage=field.types or field.type,"account" end
 return fields
end
function API:GetElementSchema(scope,id,paths)
 local ok,err=Scope(scope);if not ok then return nil,err end
 return Library:GetElementSchema(A.ThemeDefaults.appearance[scope].elements,id,paths)
end
function API:ListElementDefinitions(scope,filter)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local defaults=A.ThemeDefaults.appearance[scope].elements
 local result=Clone(Library:ListElementDefinitions(defaults,filter))
 for _,item in ipairs(result) do item.template=defaults[item.id].template==true end
 return result
end
local function Merge(into,source)
 for key,value in pairs(source or {}) do
  if type(value)=="table" and not value[1] then into[key]=Merge(type(into[key])=="table" and into[key] or {},value)
  else into[key]=Clone(value) end
 end
 return into
end
function API:GetElements(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end
 return Merge(Clone(A.ThemeDefaults.appearance[scope].elements or {}),Appearance:GetElements(scope))
end
function API:GetElementRules(scope,id,key)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local defaults=(A.ThemeDefaults.appearance[scope].elements or {})[id]
 if not defaults then return nil,"unknown element id: "..tostring(id) end
 if key~=nil and not defaults.template then return nil,"element is not an instance template: "..id end
 local overrides=Appearance:GetElements(scope)
 local entry=Merge(Clone(defaults),overrides[id])
 if key~=nil then
  local encoded,reason=EncodeKey(key);if not encoded then return nil,reason end
  local instance=entry.instances and entry.instances[key];entry.instances=nil
  if instance then Merge(entry,instance) end
 end
 return entry
end
function API:GetUtilities(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end;return Clone(Appearance:GetUtilities(scope))
end
function API:Get(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local result=Clone(Appearance:GetResolvedTheme(scope));if A.Fonts then result.font=A.Fonts:GetPath() end;return result
end
function API:GetTypography(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local theme=Appearance:GetResolvedTheme(scope)
 local result={};for role,fields in pairs(Library.TextStyles) do result[role]={fontSize=theme[fields.fontSize],lineHeight=theme[fields.lineHeight]} end;return result
end
function API:GetColors(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local theme=Appearance:GetResolvedTheme(scope)
 -- Theme validation admits tables only as colors; copy each returned color
 -- without building an authoring schema or cloning unrelated scalar tokens.
 local result={};for key,value in pairs(theme) do if type(value)=="table" then result[key]=Clone(value) end end;return result
end
