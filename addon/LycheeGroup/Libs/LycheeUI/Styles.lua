local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
local states={"selected","checked","hover","pressed","focus","disabled"}
local empty={}
local writeProperties={"texture","atlas","texCoord","blendMode","drawLayer","justifyH","justifyV","wordWrap","spacing","rotation","scale","frameStrata","frameLevel"}
-- A native HookScript cannot be removed. Keep one hook per source/event and
-- retain controllers only through active subscriptions, across all contexts.
local function RunStyleEvent(snapshot,count,source)
 local index=1
 while index<=count do
  local entry=snapshot[index];snapshot[index]=nil
  index=index+1
  local controller=entry.controller
  if controller and not controller.released then
   local action,owned=entry.action,entry.owned
   if action=="state" then
    owned[entry.name]=entry.value
    -- A leave can clear both hover and pressed. Consume only this controller's
    -- adjacent contributions; other subscribers keep their binding order.
    while index<=count do
     local following=snapshot[index]
     if following.controller~=controller or following.owned~=owned or following.action~="state" then break end
     owned[following.name]=following.value;snapshot[index]=nil;index=index+1
    end
    controller:Apply(false)
   elseif action=="checked" then owned.checked=source:GetChecked();controller:Apply(false)
   elseif action=="hide" then for name in pairs(owned) do owned[name]=false end;controller:Apply(true)
   elseif action=="disable" then
    for _,values in pairs(controller.sources) do values.hover,values.pressed=false,false end
    -- This source's permanent dispatcher may outlive an embedded upgrade.
    -- Never compare another revision's shared empty table by identity.
    if controller.states.hover or controller.states.pressed then controller.states.hover,controller.states.pressed=false,false end
    controller:Apply(true)
   else controller:Apply(true) end
  end
 end
end
local function DispatchStyleEvent(state,source)
 local nested=state.dispatching
 local snapshot=nested and {} or state.buffer;local count=#state.entries
 for index=1,count do snapshot[index]=state.entries[index] end
 state.dispatching=true
 local ok,message=pcall(RunStyleEvent,snapshot,count,source)
 state.dispatching=nested
 if not ok then for index=1,count do snapshot[index]=nil end;error(message,0) end
end
local function SubscribeStyleEvent(source,event,controller,owned,action,name,value)
 local events=source._lycheeFixedEvents
 if not events then events={};source._lycheeFixedEvents=events end
 local state=events[event]
 if not state then
  state={entries={},buffer={}};events[event]=state
  source:HookScript(event,function(control) DispatchStyleEvent(state,control) end)
 end
 local entry={controller=controller,owned=owned,action=action,name=name,value=value,eventState=state}
 state.entries[#state.entries+1]=entry;return entry
end
local function UnsubscribeStyleEvents(controller)
 for _,events in pairs(controller.bindings or empty) do for _,entry in pairs(events) do
  local entries=entry.eventState.entries
  for index=1,#entries do if entries[index]==entry then table.remove(entries,index);break end end
  entry.controller,entry.owned,entry.eventState=nil,nil,nil
 end end
 controller.sources,controller.bindings=empty,nil
end
local function Merge(into,source)
 for key,value in pairs(source or empty) do
  if type(value)=="table" and type(key)~="number" and not value[1] then into[key]=Merge(type(into[key])=="table" and into[key] or {},value)
  else into[key]=value end
 end
 return into
end
Library.ComponentRecipes={
 button={base={root={height="buttonHeight",radius="buttonRadius"},label={fontSize="buttonFontSize",lineHeight="buttonLineHeight",singleLine=true}},
  states={disabled={root={alpha="disabledAlpha"}}},
  variants={compact={base={root={height="compactHeight",radius="compactRadius"},label={fontSize="compactSize",lineHeight="compactLineHeight",singleLine=true}}}}},
}
local recipes=Library.ComponentRecipes
for _,variant in ipairs({"primary","tonal","text","ghost"}) do recipes.button.variants[variant]={base={}} end
recipes.iconButton={variants=Merge({},recipes.button.variants),base={root={height="buttonHeight"},icon={width="iconButtonSize",height="iconButtonSize",alpha=1}},states={disabled={root={alpha="disabledAlpha"}}}}
recipes.check={base={root={height="buttonHeight"},label={color="text"},track={width="switchWidth",height="switchHeight"},knob={width="switchKnobSize",height="switchKnobSize"},surface={color="surfaceHigh"}},states={hover={surface={color="surfaceHighest"}},pressed={surface={color="secondaryContainer"}},checked={surface={color="primary"}},disabled={root={alpha="disabledAlpha"}}}}
recipes.checkbox={base={root={width="checkboxSize",height="checkboxSize"},surface={color="surfaceHigh",radius="checkboxRadius"},mark={color="onPrimary",shown=false}},states={hover={surface={color="secondaryContainer"}},checked={surface={color="primary"},mark={shown=true}},disabled={root={alpha="disabledAlpha"}}}}
recipes.field={base={root={height="fieldHeight"},surface={color="field",radius="fieldRadius"},outline={color="focusBorder",shown=false}},states={hover={surface={color="surfaceHighest"}},focus={surface={color="fieldFocus"},outline={shown=true}}}}
recipes.edit=Merge({},recipes.field);recipes.edit.base.input={fontSize="label",color="text"}
recipes.navigation={base={root={height="navigationHeight",radius="navigationRadius"},label={fontSize="navigationFontSize",lineHeight="navigationLineHeight",color="muted"},icon={width="railIconSize",height="railIconSize"},mark={color="accent",width="selectionMarkWidth",height="selectionMarkHeight"}},states={hover={label={color="text"}},selected={label={color="onSecondaryContainer"}},disabled={root={alpha="disabledAlpha"}}}}
recipes.listRow={base={root={height="listRowHeight"},label={fontSize="listTitleSize",lineHeight="listTitleLineHeight",color="text"},meta={fontSize="listMetaSize",lineHeight="listMetaLineHeight",color="muted"},surface={color="rowAlternate",radius="listRadius"},hover={color="rowHover"},selected={color="secondaryContainer"},mark={color="accent"}},states={hover={hover={color="rowHover"}},pressed={hover={color="pressed"}},selected={selected={color="secondaryContainer"}}}}
recipes.menuRow={base={root={height="menuRowHeight"},label={fontSize="menuFontSize",lineHeight="menuLineHeight",color="text"},icon={width="menuIconSize",height="menuIconSize"},check={shown=false}},states={hover={hover={color="rowHover"}},checked={check={shown=true}},disabled={root={alpha="disabledAlpha"}}}}
recipes.surface={base={surface={color="panel",radius="panelRadius"}},states={hover={surface={color="panel"}}},variants={floating={base={surface={color="floatingSurface",radius="floatingRadius"}},states={hover={surface={color="floatingHover"}}}}}}
function Library.ResolveRecipes(defaults,overrides)
 return Merge(Merge(Merge({},Library.ComponentRecipes),defaults),overrides)
end
local properties={minWidth={"number","string"},maxWidth={"number","string"},minHeight={"number","string"},maxHeight={"number","string"},padding={"number","string","table"},align={"string"},fit={"string"},width={"number","string"},height={"number","string"},radius={"number","string"},alpha={"number","string"},fontSize={"number","string"},lineHeight={"number","string"},color={"table","string"},singleLine={"boolean"},shown={"boolean"},desaturated={"boolean"},flags={"string"}}
local literal={flags=true,align=true,fit=true,texture=true,atlas=true,texCoord=true,blendMode=true,drawLayer=true,font=true,justifyH=true,justifyV=true,wordWrap=true,points=true,frameStrata=true}
for key,types in pairs({texture={"number","string","boolean"},atlas={"string","boolean"},texCoord={"table"},blendMode={"string"},drawLayer={"table"},font={"string"},justifyH={"string"},justifyV={"string"},wordWrap={"boolean"},spacing={"number","string"},rotation={"number","string"},scale={"number","string"},frameStrata={"string"},frameLevel={"number","string"},points={"table"}}) do properties[key]=types end
Library.StyleProperties=properties
local geometry={width=true,height=true,minWidth=true,maxWidth=true,minHeight=true,maxHeight=true,padding=true,align=true,fit=true,alpha=true,shown=true}
Library.StyleSlotKinds={box=geometry,roundedBox=Merge(Merge({},geometry),{radius=true}),text=Merge(Merge({},geometry),{fontSize=true,lineHeight=true,singleLine=true,flags=true,color=true}),texture=Merge(Merge({},geometry),{color=true,desaturated=true}),shape=Merge(Merge({},geometry),{color=true}),surface={alpha=true,shown=true,color=true,radius=true}}
for name,kind in pairs(Library.StyleSlotKinds) do if name~="surface" then kind.points=true end end
for _,name in ipairs({"box","roundedBox"}) do local kind=Library.StyleSlotKinds[name];kind.scale=true;kind.frameStrata=true;kind.frameLevel=true end
for _,name in ipairs({"font","justifyH","justifyV","wordWrap","spacing"}) do Library.StyleSlotKinds.text[name]=true end
for _,name in ipairs({"texture","atlas","texCoord","blendMode","drawLayer","rotation"}) do Library.StyleSlotKinds.texture[name]=true end
local slotKinds={root="box",label="text",title="text",meta="text",input="text",placeholder="text",icon="texture",mark="texture",surface="surface",hover="surface",selected="surface",outline="surface",border="surface",knobSurface="surface",track="box",knob="box",check="shape"}
recipes.button.slotKinds={root="roundedBox",label="text",surface="surface",hover="surface"}
recipes.iconButton.slotKinds={root="roundedBox",label="text",surface="surface",hover="surface",icon="texture"}
recipes.check.slotKinds={root="box",label="text",track="box",knob="box",surface="surface",knobSurface="surface"}
recipes.checkbox.slotKinds={root="box",surface="surface",mark="shape"}
recipes.field.slotKinds={root="box",surface="surface",outline="surface"}
recipes.edit.slotKinds={root="box",surface="surface",outline="surface",input="text"}
recipes.navigation.slotKinds={root="roundedBox",label="text",surface="surface",hover="surface",icon="texture",mark="texture"}
recipes.listRow.slotKinds={root="box",label="text",meta="text",surface="surface",hover="surface",selected="surface",mark="texture"}
recipes.menuRow.slotKinds={root="box",label="text",icon="texture",check="shape",hover="surface",surface="surface"}
recipes.surface.slotKinds={root="box",surface="surface"}
local function SlotKind(recipe,slot) return recipe.slotKinds and recipe.slotKinds[slot] or slotKinds[slot] or "box" end
local function Supports(recipe,slot,property)
 local kind=SlotKind(recipe,slot);local allowed=Library.StyleSlotKinds[kind]
 return allowed and allowed[property],kind
end
local function Clone(value)
 if type(value)~="table" then return value end
 local result={};for key,item in pairs(value) do result[key]=Clone(item) end;return result
end
local function PaddingSide(value,name,index,theme)
 if type(value)=="string" then value=theme[value] end
 if type(value)=="table" then value=value[name] or value[index] or 0 end
 if type(value)=="string" then value=theme[value] end
 return value or 0
end
local paddingSides={"left","top","right","bottom"}
local function StyleField(property,value)
 local field={default=Clone(value),type=type(value),types={unpack(properties[property])},property=property,
  ref=not literal[property] and properties[property][2]=="string",refType=property=="fontSize" and "font" or property=="lineHeight" and "line" or property=="color" and "color" or "number"}
 if property=="width" or property=="height" or property:find("^min") or property:find("^max") or property=="padding" or property=="radius" or property=="alpha" then field.min=0 end
 if property=="align" then field.enum={"start","center","end","stretch"} elseif property=="fit" then field.enum={"none","contain","cover"} end
 if property=="alpha" then field.max=1 end
 return field
end
Library.StyleField=StyleField
function Library.ResolveStyleValue(value,field,theme,scale)
 local property=type(field)=="table" and field.property or field
 theme=theme or Library.ResolveTheme()
 if property=="padding" and value~=nil then
  local result={};for i,name in ipairs(paddingSides) do result[i]=PaddingSide(value,name,i,theme) end;return result
 end
 if type(value)=="string" and not literal[property] then local role=Library.TextStyles[value];value=theme[role and (property=="fontSize" and role.fontSize or role.lineHeight) or value] end
 if property=="fontSize" and value~=nil then return (value+theme.fontSizeDelta)*(scale or 1) end
 if property=="lineHeight" and value~=nil then return (value+theme.lineHeightDelta)*(scale or 1) end
 return value
end
Library.ResolveRecipeValue=Library.ResolveStyleValue
local variantCache=setmetatable({},{__mode="k"})
function Library.ResolveStyleVariant(rule,name)
 if not rule or not name or not rule.variants or not rule.variants[name] then return rule end
 local cache=variantCache[rule];if not cache then cache={};variantCache[rule]=cache end
 if not cache[name] then local part=rule.variants[name];cache[name]={base=Merge(Merge({},rule.base),part.base),states=Merge(Merge({},rule.states),part.states)} end
 return cache[name]
end
function Library.SameRecipes(a,b,oldTheme,newTheme)
 local function Same(left,right,key)
  if properties[key] then
   if key=="padding" and left~=nil and right~=nil then
    for i,name in ipairs(paddingSides) do if PaddingSide(left,name,i,oldTheme)~=PaddingSide(right,name,i,newTheme) then return false end end
    return true
   end
   left,right=Library.ResolveStyleValue(left,key,oldTheme),Library.ResolveStyleValue(right,key,newTheme)
   if type(left)=="table" and type(right)=="table" then
    if key=="color" then for i=1,4 do if (left[i] or 1)~=(right[i] or 1) then return false end end;return true end
    local function Deep(a,b) if a==b then return true end;if type(a)~="table" or type(b)~="table" or a.GetObjectType or b.GetObjectType then return false end;for k,v in pairs(a) do if not Deep(v,b[k]) then return false end end;for k in pairs(b) do if a[k]==nil then return false end end;return true end
    return Deep(left,right)
   end
   return left==right
  end
  if type(left)~="table" or type(right)~="table" then return left==right end
  for name,value in pairs(left) do if not Same(value,right[name],name) then return false end end
  for name in pairs(right) do if left[name]==nil then return false end end
  return true
 end
 return Same(a,b)
end
local schemaCache=setmetatable({},{__mode="k"})
local noDefaults={}
local function Catalog(defaults)
 local key=defaults or noDefaults;local cached=schemaCache[key]
 if cached then return cached end
 cached={recipes=Library.ResolveRecipes(defaults),fields={}};schemaCache[key]=cached
 local function Visit(value,path)
  for name,item in pairs(value) do
   local nextPath=path=="" and name or path.."."..name
   if properties[name] then
    local recipeName,slot=path:match("^([^.]+).*%.([^.]+)$")
    local allowed,kind=Supports(cached.recipes[recipeName],slot,name)
    if allowed then cached.fields[nextPath]=value
    else cached.error="unsupported recipe property: "..nextPath end
   elseif name~="slotKinds" and type(item)=="table" then Visit(item,nextPath) end
  end
 end
 Visit(cached.recipes,"");return cached
end
function Library:GetStyleSchema(defaults,paths)
 local catalog=Catalog(defaults);local result={}
 for path,part in pairs(catalog.fields) do
  local property=path:match("([^.]+)$");local recipeName,slot=path:match("^([^.]+).*%.([^.]+)%.[^.]+$")
  local _,kind=Supports(catalog.recipes[recipeName],slot,property)
  local field=StyleField(property,part[property]);field.slotKind=kind;result[path]=field
 end
 for _,path in ipairs(paths or {}) do if not result[path] then result[path]=self:GetStyleField(path,defaults) end end
 return result
end
function Library:GetStyleField(path,defaults)
 local parts={};for part in path:gmatch("[^.]+") do parts[#parts+1]=part end
 local recipe=Catalog(defaults).recipes[parts[1]];if not recipe then return nil end
 local branch,index=recipe,2
 if parts[index]=="variants" then branch=recipe.variants and recipe.variants[parts[index+1]];if not branch then return nil end;index=index+2 end
 local section=parts[index];local slot,property
 if section=="base" then slot,property=parts[index+1],parts[index+2]
 elseif section=="states" then
  local allowed=false;for _,state in ipairs(states) do if state==parts[index+1] then allowed=true end end
  if not allowed then return nil end;slot,property=parts[index+2],parts[index+3]
 else return nil end
 if not properties[property] or #parts~=(section=="base" and index+2 or index+3) then return nil end
 local declared=recipe.slotKinds and recipe.slotKinds[slot] or recipe.base and recipe.base[slot] or branch.base and branch.base[slot]
 if not declared then for _,group in pairs(recipe.states or {}) do if group[slot] then declared=group[slot];break end end end
 if not declared then return nil end
 local allowed,kind=Supports(recipe,slot,property);if not allowed then return nil end
 local field=StyleField(property,nil);field.type=field.types;field.inherited=true;field.slotKind=kind;return field
end
local function ValidateValue(property,value,theme)
 if property=="texture" then return value==false or type(value)=="string" or type(value)=="number" and value==value and math.abs(value)~=math.huge
 elseif property=="atlas" then return value==false or type(value)=="string"
 elseif property=="points" then
  if type(value)~="table" then return false end
  for _,point in ipairs(value) do if type(point)~="table" or type(point[1])~="string" or type(point[3])~="string" then return false end;for i=4,5 do local v=point[i] or 0;v=type(v)=="string" and theme[v] or v;if type(v)~="number" or v~=v or math.abs(v)==math.huge then return false end end end
  return true
 elseif property=="texCoord" then if type(value)~="table" or #value~=4 and #value~=8 then return false end;for _,n in ipairs(value) do if type(n)~="number" or n~=n then return false end end;return true
 elseif property=="drawLayer" then return type(value)=="table" and type(value[1])=="string" and (value[2]==nil or type(value[2])=="number")
 elseif property=="font" or property=="blendMode" or property=="frameStrata" then return type(value)=="string"
 elseif property=="justifyH" then return value=="LEFT" or value=="CENTER" or value=="RIGHT"
 elseif property=="justifyV" then return value=="TOP" or value=="MIDDLE" or value=="BOTTOM"
 elseif property=="wordWrap" then return type(value)=="boolean"
 elseif property=="align" then return value=="start" or value=="center" or value=="end" or value=="stretch"
 elseif property=="fit" then return value=="none" or value=="contain" or value=="cover"
 elseif property=="padding" and type(value)=="table" then
  for key,item in pairs(value) do
   if key~="left" and key~="top" and key~="right" and key~="bottom" and key~=1 and key~=2 and key~=3 and key~=4 then return false end
   local n=type(item)=="string" and theme[item] or item
   if type(n)~="number" or n<0 or n~=n or n==math.huge then return false end
  end
  return true
 elseif property=="color" then
  if type(value)=="string" then value=theme[value] end
  if type(value)~="table" or #value<3 or #value>4 then return false end
  for _,channel in ipairs(value) do if type(channel)~="number" or channel~=channel or channel<0 or channel>1 then return false end end
  return true
 elseif property=="singleLine" or property=="shown" or property=="desaturated" then return type(value)=="boolean"
 elseif property=="flags" then return type(value)=="string" end
 if type(value)=="string" then
  local role=Library.TextStyles[value]
  value=theme[role and (property=="fontSize" and role.fontSize or role.lineHeight) or value]
 end
 if type(value)~="number" or value~=value or value==math.huge or value==-math.huge then return false end
 if property=="fontSize" or property=="lineHeight" then return value+(property=="fontSize" and theme.fontSizeDelta or theme.lineHeightDelta)>0 end
 return (property=="rotation" or property=="spacing" or value>=0) and (property~="alpha" or value<=1) and (property~="scale" or value>0)
end
Library.ValidateStyleValue=ValidateValue
function Library:ValidateRecipes(overrides,defaults,theme)
 if type(overrides)~="table" then return false,"recipes must be a table" end
 if defaults~=nil and type(defaults)~="table" then return false,"recipe defaults must be a table" end
 theme=theme or self.ResolveTheme();local catalog=Catalog(defaults);if catalog.error then return false,catalog.error end;local schema=catalog.fields
 for path,part in pairs(schema) do local property=path:match("([^.]+)$");if not ValidateValue(property,part[property],theme) then return false,"invalid recipe default: "..path end end
 local function Visit(value,path)
  for key,item in pairs(value) do
   local name=path=="" and key or path.."."..key;local property
   if schema[name] then property=key else local field=self:GetStyleField(name,defaults);property=field and field.property end
   if property then if not ValidateValue(property,item,theme) then return false,"invalid recipe value: "..name end
   elseif type(item)=="table" and not item[1] then local ok,message=Visit(item,name);if not ok then return ok,message end
   else return false,"unknown recipe property: "..name end
  end
  return true
 end
 return Visit(overrides,"")
end
function Library.AttachStyles(UI,C)
 UI.recipes=Library.ResolveRecipes(UI.options.recipeDefaults,UI.options.recipes)
 UI.fixedControllers=setmetatable({},{__mode="k"})
 local function Value(v) return UI:ResolveValue(v) end
 local function Text(target) return target.label or target end
 local none={}
 local function Unwrap(value) if value~=none then return value end end
 local methods={texture={"GetTexture","SetTexture"},atlas={"GetAtlas","SetAtlas"},texCoord={"GetTexCoord","SetTexCoord"},blendMode={"GetBlendMode","SetBlendMode"},drawLayer={"GetDrawLayer","SetDrawLayer"},justifyH={"GetJustifyH","SetJustifyH"},justifyV={"GetJustifyV","SetJustifyV"},wordWrap={"CanWordWrap","SetWordWrap"},spacing={"GetSpacing","SetSpacing"},rotation={"GetRotation","SetRotation"},scale={"GetScale","SetScale"},frameStrata={"GetFrameStrata","SetFrameStrata"},frameLevel={"GetFrameLevel","SetFrameLevel"}}
 local function Object(target,key)
  if key=="justifyH" or key=="justifyV" or key=="wordWrap" or key=="spacing" then return Text(target) end
  if key=="texture" or key=="atlas" or key=="texCoord" or key=="blendMode" or key=="drawLayer" or key=="rotation" then return target._lycheeTexture or target end
  return target
 end
 local function Read(target,key)
  local text=Text(target);local font=UI.fontStyles[text]
  if key=="width" then return target:GetWidth() elseif key=="height" then return target:GetHeight()
  elseif key=="alpha" then return target:GetAlpha() elseif key=="shown" then return target:IsShown()
  elseif key=="radius" then return target.radius or 0
  elseif key=="color" then return target.color or (text.GetTextColor and {text:GetTextColor()} or {(target._lycheeTexture or target):GetVertexColor()})
  elseif key=="fontSize" then return font and font.size or select(2,text:GetFont())/UI.fontScale-UI.Theme.fontSizeDelta
  elseif key=="lineHeight" then return font and font.lineHeight or (text.GetLineHeight and text:GetLineHeight() or select(2,text:GetFont()))/UI.fontScale-UI.Theme.lineHeightDelta
  elseif key=="flags" then return select(3,text:GetFont()) or ""
  elseif key=="font" then return (text:GetFont())
  elseif key=="singleLine" then return font and font.singleLine==true or false
  elseif key=="desaturated" then return (target._lycheeTexture or target):IsDesaturated()
  elseif key=="points" then local out={};for i=1,target:GetNumPoints() do out[i]={target:GetPoint(i)} end;return out
  elseif key=="padding" or key=="align" or key=="fit" or key:match("^min") or key:match("^max") then return target._lycheeBoxValues and target._lycheeBoxValues[key] or (key=="align" and "start" or key=="fit" and "none" or key:match("^max") and math.huge or 0) end
  local method=methods[key];if method then local object=Object(target,key);if key=="texCoord" or key=="drawLayer" then return {object[method[1]](object)} end;return object[method[1]](object) end
 end
 local function Equal(a,b)
  if a==b then return true end
  if type(a)~="table" or type(b)~="table" then return type(a)=="number" and type(b)=="number" and math.abs(a-b)<.000001 end
  if a.GetObjectType or b.GetObjectType then return false end
  for key,v in pairs(a) do if not Equal(v,b[key]) then return false end end
  for key in pairs(b) do if a[key]==nil then return false end end;return true
 end
 local function ValidateTarget(target,key)
  if key=="color" then return target.SetColor or target.SetVertexColor or Text(target).SetTextColor end
  if key=="radius" then return target.SetRadius end
  if key=="alpha" then return target.SetAlpha elseif key=="shown" then return target.SetShown end
  if key=="font" or key=="fontSize" or key=="lineHeight" or key=="flags" or key=="singleLine" then local text=Text(target);local kind=text.GetObjectType and text:GetObjectType();return (kind=="FontString" or kind=="EditBox") and text.SetFont end
  if key=="desaturated" then return (target._lycheeTexture or target).SetDesaturated end
  if key=="points" then return target.SetPoint end
  local method=methods[key];if method then return Object(target,key)[method[2]] end
  return target.SetWidth and target.SetHeight
 end
 local Winner
 local function FontPreserve(target)
  local text=Text(target)
  return ((Winner(target,"spacing") or text~=target and Winner(text,"spacing")) and 1 or 0)+(Winner(text,"height") and 2 or 0)+((Winner(target,"justifyV") or text~=target and Winner(text,"justifyV")) and 4 or 0)
 end
 C.FixedFontPreserve=FontPreserve
 local function Write(target,part,immediate,duration,host)
  local previousHeight=target._lycheeList and target:GetHeight()
  if part.__art then local object=target._lycheeTexture or target;local art=part.__art;if art.atlas then object:SetAtlas(art.atlas) else object:SetTexture(art.texture) end;object:SetTexCoord(unpack(art.texCoord)) end
  local box=target._lycheeBoxValues
  for _,key in ipairs({"minWidth","maxWidth","minHeight","maxHeight","padding","align","fit"}) do if part[key]~=nil then box=box or {};target._lycheeBoxValues=box;box[key]=(key=="align" or key=="fit") and part[key] or Value(part[key]) end end
  if part.width~=nil or part.minWidth~=nil or part.maxWidth~=nil then target:SetWidth(math.max(box and box.minWidth or 0,math.min(box and box.maxWidth or math.huge,Value(part.width) or target:GetWidth()))) end
  if part.height~=nil or part.minHeight~=nil or part.maxHeight~=nil then target:SetHeight(math.max(box and box.minHeight or 0,math.min(box and box.maxHeight or math.huge,Value(part.height) or target:GetHeight()))) end
  if part.radius~=nil then target:SetRadius(Value(part.radius)) end
  if part.alpha~=nil then if immediate or duration==0 then target:SetAlpha(Value(part.alpha)) else UI.Motion:Alpha(target,Value(part.alpha),duration or UI.Theme.feedbackDuration) end end
  if part.color~=nil then local color=Value(part.color);if target.SetColor then if immediate or duration==0 then target:SetColor(color) else UI.Motion:Color(target,color,duration or UI.Theme.feedbackDuration) end elseif Text(target).SetTextColor then local text=Text(target);text:SetTextColor(unpack(color));text._color=color else target:SetVertexColor(unpack(color)) end end
  local text=Text(target)
  local preserve;if part.fontSize~=nil or part.lineHeight~=nil or part.singleLine~=nil or part.flags~=nil then preserve=FontPreserve(target) end
  if part.fontSize~=nil then C.DefaultFont(text,part.fontSize,part.flags or select(3,text:GetFont()),preserve) end
  if part.lineHeight~=nil or part.singleLine~=nil then local font=UI.fontStyles[text];C.DefaultLineHeight(text,part.lineHeight or font and font.lineHeight or Read(target,"lineHeight"),part.singleLine==nil and font and font.singleLine or part.singleLine,preserve) end
  if part.flags~=nil and part.fontSize==nil then local font=UI.fontStyles[text];C.DefaultFont(text,font and font.size or Read(target,"fontSize"),part.flags,preserve) end
  if part.font~=nil then local _,size,flags=text:GetFont();text:SetFont(part.font,size,flags) end
  for _,key in ipairs(writeProperties) do if part[key]~=nil then local method=methods[key];local value=part[key];local object=Object(target,key)
   if value==none or value==false and (key=="texture" or key=="atlas") then value=nil elseif not literal[key] then value=Value(value) end
   if key=="rotation" then local _,pivot=object:GetRotation();if pivot then object:SetRotation(value,pivot.x,pivot.y) else object:SetRotation(value) end
   elseif key=="atlas" and value==nil then object:SetTexture(nil)
   elseif key=="texCoord" or key=="drawLayer" then object[method[2]](object,unpack(value)) else object[method[2]](object,value) end
  end end
  if part.desaturated~=nil then (target._lycheeTexture or target):SetDesaturated(part.desaturated) end
  if part.shown~=nil then target:SetShown(part.shown) end
  if part.points and not target._lycheeLayoutOwner then target:ClearAllPoints();for _,point in ipairs(part.points) do local relative=point[2];if type(relative)=="string" then relative=C.ResolveElementReference(target,relative,host) end;if relative then target:SetPoint(point[1],relative,point[3],Value(point[4] or 0),Value(point[5] or 0)) end end end
  if target._lycheeBoxApply then target._lycheeBoxApply() end
  if target._lycheeLayoutOwner and (part.width~=nil or part.height~=nil or part.fontSize~=nil or part.lineHeight~=nil or part.minWidth~=nil or part.maxWidth~=nil or part.minHeight~=nil or part.maxHeight~=nil) then target._lycheeLayoutOwner:Layout() end
  if previousHeight and previousHeight~=target:GetHeight() then target._lycheeList:RowGeometryChanged() end
 end
 C.ReadStyleValue=Read;C.ValidateStyleTarget=ValidateTarget
 function C.DefaultTextStyle(target,defaults) if defaults.width then target:SetWidth(Value(defaults.width)) end;UI:Color(target,Value(defaults.color)) end
 function C.SetPoint(target,point,relative,relativePoint,x,y)
  x,y=Value(x or 0),Value(y or 0)
  if type(x)~="number" or type(y)~="number" then error("point offsets must be numbers or declared numeric tokens",2) end
  if type(relative)=="string" then relative=C.ResolveElementReference(target,relative) end
  if relative then target:SetPoint(point,relative,relativePoint,x,y) end;return target
 end
 local serial=0
 local Controller={};Controller.__index=Controller
 Winner=function(target,key)
  local winner
  for record in pairs(target._lycheeFixedRecords or empty) do if record.rule.properties[key] and (not winner or record.direct and not winner.direct or record.direct==winner.direct and record.controller.serial>winner.controller.serial) then winner=record end end
  return winner
 end
 local function RuleValue(record,key)
  local value=record.rule.base[key]
  for _,name in ipairs(states) do if record.controller.active[name] then local part=record.rule.states[name];if part and part[key]~=nil then value=part[key] end end end
  return value
 end
 function C.SharedElementValue(target,key) local record=Winner(target,key);if not record then return nil,false end;local value=RuleValue(record,key);if value==nil then value=record.base[key] end;return value,true end
 function C.FixedValue(target,key,fallback) local record=Winner(target,key);local value=record and RuleValue(record,key);if value~=nil and value~=none then return Value(value) end;return fallback end
 function C.OwnsStyle(host,slot,key,value)
  local controller=host._lycheeStyleController;local record=controller and controller.records[slot]
  if not record or not record.rule.properties[key] then return false end
  record.base[key]=value
  return true
 end
 local function ProtectedRefresh(self,...)
  local value=self._lycheeBusinessRefresh(self,...);local controller=self._lycheeStyleController
  if controller and controller.hasOverrides then controller:Apply(select(1,...)==true) end
  return value
 end
 function C.ProtectStyle(host)
  if host._lycheeBusinessRefresh or not host.RefreshStyle then return end
  host._lycheeBusinessRefresh=host.RefreshStyle;host.RefreshStyle=ProtectedRefresh
 end
 local function ValidateBinding(slots,part)
  for name,style in pairs(part or empty) do local target=slots[name];if target then for key,value in pairs(style) do if not properties[key] or not ValidateTarget(target,key) or not ValidateValue(key,value,UI.Theme) then error("unsupported slot property: "..name.."."..key,3) end end end end
 end
 local function Difference(base,value)
  local out={};for key,item in pairs(value or empty) do local original=base and base[key];if type(item)=="table" and not item[1] then local nested=Difference(type(original)=="table" and original or nil,item);if next(nested) then out[key]=nested end elseif item~=original then out[key]=item end end;return out
 end
 local recipes={}
 local stateOrders=setmetatable({},{__mode="k"})
 local compiled=setmetatable({},{__mode="k"})
 local function Compile(options,element)
  local key=(options.recipe or "").."/"..(options.variant or "")..(options.legacy and "/legacy" or "/full")
  local recipe=recipes[key]
  if not recipe then recipe=UI.recipes[options.recipe] or empty;if options.legacy then recipe=Difference(Library.ComponentRecipes[options.recipe],recipe) end;recipe=Library.ResolveStyleVariant(recipe,options.variant);recipes[key]=recipe end
  element=Library.ResolveStyleVariant(element,options.variant) or empty
  local node=compiled
  for _,source in ipairs({recipe,element,options.style or empty,options.states or empty}) do local child=node[source];if not child then child=setmetatable({},{__mode="k"});node[source]=child end;node=child end
  if node.value then return node.value end
  local base=Merge(Merge(Merge({},recipe.base),options.style),element.base)
  local groups={};local names={}
  for name in pairs(base) do names[name]=true end
  for _,state in ipairs(states) do local part=Merge(Merge(Merge({},recipe.states and recipe.states[state]),options.states and options.states[state]),element.states and element.states[state]);groups[state]=part;for name in pairs(part) do names[name]=true end end
  local out={}
  for name in pairs(names) do local rule={base=base[name] or empty,states={},properties={}}
   for property in pairs(rule.base) do rule.properties[property]=true end
   for _,state in ipairs(states) do local part=groups[state][name];if part and next(part) then rule.states[state]=part;for property in pairs(part) do rule.properties[property]=true end end end
   if next(rule.properties) then out[name]=rule end
  end
  node.value=out;return out
 end
 local function Art(target) local object=target._lycheeTexture or target;return {texture=object:GetTexture(),atlas=object:GetAtlas(),texCoord={object:GetTexCoord()}} end
 local artKeys={texture=true,atlas=true,texCoord=true}
 local function SameTexCoord(object,expected)
  local a,b,c,d,e,f,g,h=object:GetTexCoord()
  return Equal(a,expected[1]) and Equal(b,expected[2]) and Equal(c,expected[3]) and Equal(d,expected[4]) and Equal(e,expected[5]) and Equal(f,expected[6]) and Equal(g,expected[7]) and Equal(h,expected[8])
 end
 local function SameArt(target,expected)
  local object=target._lycheeTexture or target
  return expected and object:GetTexture()==expected.texture and object:GetAtlas()==expected.atlas and SameTexCoord(object,expected.texCoord)
 end
 local function Current(record,key,art)
  local target=record.target;local previous=Unwrap(record.applied[key])
  if artKeys[key] and art then return art[key] end
  if key=="points" and previous and target:GetNumPoints()==#previous then
   local same=true
   for index,point in ipairs(previous) do
    local a,b,c,x,y=target:GetPoint(index)
    if a~=point[1] or b~=point[2] or c~=point[3] or not Equal(x,point[4]) or not Equal(y,point[5]) then same=false;break end
   end
   if same then return previous end
  elseif key=="color" and previous and not target.color then
   local text=Text(target);local r,g,b,a
   if text.GetTextColor then r,g,b,a=text:GetTextColor() else r,g,b,a=(target._lycheeTexture or target):GetVertexColor() end
   if Equal(r,previous[1]) and Equal(g,previous[2]) and Equal(b,previous[3]) and Equal(a,previous[4]) then return previous end
  elseif key=="drawLayer" and previous then
   local layer,sub=(target._lycheeTexture or target):GetDrawLayer()
   if layer==previous[1] and sub==previous[2] then return previous end
  end
  return Read(target,key)
 end
 local fontGroup={fontSize=true,lineHeight=true,singleLine=true,flags=true,font=true}
 local widthGroup={width=true,minWidth=true,maxWidth=true}
 local heightGroup={height=true,minHeight=true,maxHeight=true}
 local function Dimensions(record,capture,changedWidth,changedHeight)
  local target=record.target;local box=target._lycheeBoxValues or empty;local rule=record.rule.properties
  local width=rule.width or rule.minWidth or rule.maxWidth
  local height=rule.height or rule.minHeight or rule.maxHeight
  local minW,maxW,minH,maxH=box.minWidth or 0,box.maxWidth or math.huge,box.minHeight or 0,box.maxHeight or math.huge
  local w,h=width and target:GetWidth(),height and target:GetHeight()
  if capture then
   if width and changedWidth then record.minW,record.maxW,record.nativeW=minW,maxW,w end
   if height and changedHeight then record.minH,record.maxH,record.nativeH=minH,maxH,h end
   return
  end
  return width and (record.minW~=minW or record.maxW~=maxW or not Equal(w,record.nativeW) and not Equal(w,math.max(minW,math.min(maxW,w)))) or false,
   height and (record.minH~=minH or record.maxH~=maxH or not Equal(h,record.nativeH) and not Equal(h,math.max(minH,math.min(maxH,h)))) or false
 end
 local function PointReferences(target,points,host)
  if target._lycheeLayoutOwner or points==none then return true end
  local count=0
  for _,point in ipairs(points) do
   local relative=point[2];if type(relative)=="string" then relative=C.ResolveElementReference(target,relative,host) end
   if relative then
    count=count+1;local a,b,c=target:GetPoint(count)
    if a~=point[1] or b~=relative or c~=point[3] then return false end
   end
  end
  return target:GetNumPoints()==count
 end
 local function NativeFont(record,capture)
  local text=Text(record.target);local saved=record.nativeFont
  if not text.GetFont then return true end
  local path,size,flags=text:GetFont();local spacing=text:GetSpacing();local height=text:GetHeight();local justify=text:GetJustifyV()
  local style=UI.fontStyles[text];local fixed=style and style.singleLine==true
  local mask=FontPreserve(record.target)
  if capture then
   saved=saved or {};record.nativeFont=saved
   saved[1],saved[2],saved[3],saved[4],saved[5],saved[6],saved.fixed,saved.mask=path,size,flags,spacing,height,justify,fixed,mask
   return true
  end
  return saved and saved.mask==mask and path==saved[1] and size==saved[2] and flags==saved[3] and (mask%2~=0 or spacing==saved[4]) and (not saved.fixed or math.floor(mask/2)%2~=0 or height==saved[5]) and (mask>=4 or justify==saved[6])
 end
 local function SameChannel(actual,wanted)
  return math.abs(actual-wanted)<=.000001 or math.floor(actual*255+.5)==math.floor(wanted*255+.5)
 end
 local function MotionValue(key,actual,wanted)
  if key=="alpha" then return SameChannel(actual,wanted) end
  if type(actual)~="table" or type(wanted)~="table" then return Equal(actual,wanted) end
  for i=1,4 do if not SameChannel(actual[i] or 1,wanted[i] or 1) then return false end end
  return true
 end
 local function MotionOwns(record,key,actual)
  local wanted=record.moving and record.moving[key]
  if wanted==nil then return false end
  local target=record.target;local motion=UI.Motion
  local pending=key=="alpha" and motion.alphas[target] or motion.colors[target]
  if motion.jobs[target] and Equal(pending,wanted) then return true end
  record.moving[key]=nil
  return MotionValue(key,actual,wanted)
 end
 local function StopOwnedMotion(record)
  for key,wanted in pairs(record.moving or empty) do
   local pending=key=="alpha" and UI.Motion.alphas[record.target] or UI.Motion.colors[record.target]
   if UI.Motion.jobs[record.target] and Equal(pending,wanted) then UI.Motion:Stop(record.target,true) end
  end
 end
 local function ReleaseRecord(record)
  for key in pairs(record.moving or empty) do
   if Winner(record.target,key)==record and MotionOwns(record,key,Read(record.target,key)) then
    UI.Motion:Stop(record.target,true);record.applied[key]=Read(record.target,key)
   end
  end
  local target=record.target;target._lycheeFixedRecords[record]=nil
  local restore={}
  for key in pairs(record.rule.properties) do if not Winner(target,key) and record.applied[key]~=nil and Equal(Read(target,key),Unwrap(record.applied[key])) then restore[key]=record.base[key] end end
  if record.artBase and Equal(Art(target),record.artApplied) then restore.__art=record.artBase;restore.texture,restore.atlas,restore.texCoord=nil,nil,nil end
  if next(restore) then Write(target,restore,true,nil,record.controller.host) end
  for other in pairs(target._lycheeFixedRecords) do other.controller:Apply(true,false,true) end
 end
 function Controller:Configure(element,slots,variant)
  if self.configured and self.element==element and self.slots==slots and self.options.variant==variant then
   local unchanged=true;for name in pairs(self.compiled or empty) do if self.slots[name]~=(self.records[name] and self.records[name].target) then unchanged=false;break end end
   if unchanged then return self end
  end
  self.configured=true
  -- Restoring a row dimension can synchronously remeasure its list. Expose the
  -- selected variant before that callback resolves the row's fixed values.
  self.options.variant=variant
  for _,record in pairs(self.records) do ReleaseRecord(record) end
  self.element,self.slots,self.options.variant=element,slots or self.slots,variant
  self.records=empty;local rules=Compile(self.options,element);self.compiled=rules;self.hasOverrides=next(rules)~=nil
  UI.fixedControllers[self]=self.hasOverrides and true or nil
  for name,rule in pairs(rules) do local target=self.slots[name];if target then
   ValidateBinding({[name]=target},{[name]=rule.base});for _,part in pairs(rule.states) do ValidateBinding({[name]=target},{[name]=part}) end
   local record={controller=self,target=target,slot=name,direct=name=="root" and target==self.host,rule=rule,base={},applied={}}
   if self.records==empty then self.records={} end;self.records[name]=record;target._lycheeFixedRecords=target._lycheeFixedRecords or {};target._lycheeFixedRecords[record]=true
  end end
  self.stateOrder=stateOrders[rules]
  if not self.stateOrder then local names={};for _,name in ipairs(states) do for _,rule in pairs(rules) do if rule.states[name] then names[#names+1]=name;break end end end;self.stateOrder=next(names) and names or empty;stateOrders[rules]=self.stateOrder end
  if self.hasOverrides then C.ProtectStyle(self.host) end
  return self
 end
 local fontKeys={font=true,fontSize=true,lineHeight=true,flags=true,singleLine=true,spacing=true,wordWrap=true,justifyH=true,justifyV=true}
 function Controller:Apply(immediate,fontOnly,noObserve)
  if self.released or self.applying or self.host._lycheeElementOwner and not self.host._lycheeElementOwner:IsOwned() then return self end
  if not self.hasOverrides then return self end
  self.applying=true;if self.active==empty then self.active={} end
  for _,name in ipairs(states) do local active=self.states[name]==true;for _,source in pairs(self.sources) do active=active or source[name]==true end
   if self.options.trackNative then local host=self.host;if name=="hover" then active=active or host._inside==true or host.hovered==true elseif name=="pressed" then active=active or host._pressed==true elseif name=="selected" then active=active or host.active==true or host.selected==true or host._selected==true elseif name=="focus" then active=active or host.focused==true or host.expanded==true elseif name=="checked" then active=active or host._checked==true or host.GetChecked and host:GetChecked()==true end end
   if name=="disabled" and self.host.IsEnabled then active=active or not self.host:IsEnabled() end;self.active[name]=active
  end
  if self.active.disabled then self.active.hover,self.active.pressed=false,false;if self.states~=empty then self.states.hover,self.states.pressed=false,false end;for _,source in pairs(self.sources) do source.hover,source.pressed=false,false end end
  for _,record in pairs(self.records) do local target=record.target;local patch
   if (not target._lycheeElementOwner or target._lycheeElementOwner:IsOwned()) and (not fontOnly or not Text(target).GetFont or not UI.options.ownsText or UI.options.ownsText(Text(target))) then
   local sameArt=true;local observedArt;local hasFont,hasArt=false,false;local sameFont
   local widthChanged,heightChanged=Dimensions(record)
   for key in pairs(record.rule.properties) do
    if fontGroup[key] then hasFont=true end
    if artKeys[key] and Winner(target,key)==record then hasArt=true end
   end
   if hasFont then sameFont=NativeFont(record) end
   if not fontOnly and hasArt then
    sameArt=SameArt(target,record.artApplied)
    if not record.artBase or record.artApplied and not sameArt then observedArt=Art(target);record.artBase=observedArt end
    observedArt=observedArt or record.artApplied or record.artBase
   end
   for key in pairs(record.rule.properties) do if (not fontOnly or fontKeys[key]) and Winner(target,key)==record then
    local actual=Current(record,key,observedArt);local applied=record.applied[key]
    local moving=(key=="alpha" or key=="color") and MotionOwns(record,key,actual)
    if record.base[key]==nil or not moving and not fontOnly and not noObserve and applied~=nil and not Equal(actual,Unwrap(applied)) then record.base[key]=actual==nil and none or actual end
    local value=RuleValue(record,key);if value==nil and not artKeys[key] then value=record.base[key] end
    local requested=value==nil and none or value
    local finish=moving and (immediate~=false or self.options.immediate or self.options.duration and Value(self.options.duration)==0 or UI:IsReducedMotion())
    if not record.requested or not Equal(record.requested[key],requested) or finish or not moving and not Equal(actual,Unwrap(applied)) or artKeys[key] and not sameArt or fontGroup[key] and not sameFont or widthGroup[key] and widthChanged or heightGroup[key] and heightChanged or key=="points" and not PointReferences(target,requested,self.host) then
     patch=patch or {};patch[key]=requested
     if finish then UI.Motion:Stop(target,true) end
    elseif moving then record.applied[key]=actual==nil and none or actual end
   end end
   if patch then
    local values={}
    for key in pairs(record.rule.properties) do if (not fontOnly or fontKeys[key]) and Winner(target,key)==record then
     local value=RuleValue(record,key);if value==nil and not artKeys[key] then value=record.base[key] end;values[key]=value==nil and none or value
    end end
    local art,font,width,height=false,false,false,false
    for key in pairs(patch) do art=art or artKeys[key];font=font or fontGroup[key];width=width or widthGroup[key];height=height or heightGroup[key] end
    for key,value in pairs(values) do if art and artKeys[key] or font and fontGroup[key] or width and widthGroup[key] or height and heightGroup[key] then patch[key]=value end end
    if art then patch.__art=record.artBase end
    -- A nil art override means restore the captured group, not SetTexture(nil).
    for key in pairs(artKeys) do if patch[key]==none then patch[key]=nil end end
    Write(target,patch,immediate~=false or self.options.immediate,self.options.duration and Value(self.options.duration),self.host)
    if patch.__art then record.artApplied=Art(target) end
    record.requested=record.requested or {}
    for key,value in pairs(values) do
     record.requested[key]=value
     local actual=Current(record,key,record.artApplied);record.applied[key]=actual==nil and none or actual
     if key=="alpha" or key=="color" then
      local pending=key=="alpha" and UI.Motion.alphas[target] or UI.Motion.colors[target]
      if UI.Motion.jobs[target] and pending~=nil and Equal(pending,Value(Unwrap(value))) then record.moving=record.moving or {};record.moving[key]=pending elseif record.moving then record.moving[key]=nil end
     end
    end
    if hasFont then NativeFont(record,true) end
    Dimensions(record,true,width,height)
   elseif target._lycheeBoxApply then target._lycheeBoxApply()
   end
   end
  end
  self.applying=false;return self
 end
 function Controller:SetState(name,value) value=value==true;if self.states[name]==value or self.states[name]==nil and not value then return self end;if self.states==empty then self.states={} end;self.states[name]=value;return self:Apply(false) end
 function Controller:SetStates(values) if self.states==empty then self.states={} end;for key in pairs(self.states) do self.states[key]=nil end;for key,value in pairs(values) do self.states[key]=value end;return self:Apply(false) end
 function Controller:SetVariant(name) if self.options.variant==name then return self end;self.element=nil;self:Configure(self.fixedElement,self.slots,name);return self:Apply(true) end
 function Controller:Bind(source,bindings)
  if self.released then return self end
  bindings=bindings or {hover=true,pressed=true};if self.sources==empty then self.sources={} end
  local owned=self.sources[source];if not owned then owned={};self.sources[source]=owned end
  self.bindings=self.bindings or {};local events=self.bindings[source];if not events then events={};self.bindings[source]=events end
  local function Bind(event,name,value)
   if events[event..name] or source.HasScript and not source:HasScript(event) then return end
   events[event..name]=SubscribeStyleEvent(source,event,self,owned,"state",name,value)
  end
  if bindings.hover then Bind("OnEnter","hover",true);Bind("OnLeave","hover",false) end
  if bindings.pressed then Bind("OnMouseDown","pressed",true);Bind("OnMouseUp","pressed",false);Bind("OnLeave","pressed",false) end
  if bindings.focus then Bind("OnEditFocusGained","focus",true);Bind("OnEditFocusLost","focus",false) end
  if bindings.checked and not events.checked then events.checked=SubscribeStyleEvent(source,"OnClick",self,owned,"checked") end
  if not events.hide then events.hide=SubscribeStyleEvent(source,"OnHide",self,owned,"hide") end
  if source==self.host and not events.enabled and (not source.HasScript or source:HasScript("OnDisable")) then
   events.enabled=SubscribeStyleEvent(source,"OnDisable",self,owned,"disable")
   events.enable=SubscribeStyleEvent(source,"OnEnable",self,owned,"enable")
  end
  return self
 end
 function Controller:Release(lost)
  if self.released then return end
  self.released=true;UnsubscribeStyleEvents(self)
  for _,record in pairs(self.records) do if lost then StopOwnedMotion(record);record.target._lycheeFixedRecords[record]=nil else ReleaseRecord(record) end end
  self.records=empty;UI.fixedControllers[self]=nil
  if self.host._lycheeStyleController==self then self.host._lycheeStyleController=nil;self.host.styleController=nil end
 end
 function C.Style(host,options)
  if host._lycheeStyleController then if Equal(host._lycheeStyleController.options,options or empty) then return host._lycheeStyleController end;error("Style is a construction binding; an existing binding cannot be replaced",2) end
  options=options or {};if options.duration~=nil and (type(Value(options.duration))~="number" or Value(options.duration)<0) then error("invalid style duration",2) end;serial=serial+1
  local controller=setmetatable({host=host,options=options,slots=options.slots or {root=host},records=empty,states=empty,active=empty,sources=empty,serial=serial},Controller)
  controller:Configure(nil,controller.slots,options.variant)
  host._lycheeStyleController,host.styleController=controller,controller;return controller:Apply(true)
 end
 function UI:_BindFixedElement(host,rule,slots,variant)
  local controller=host._lycheeStyleController
  if not controller then if not rule or not next(rule) then return end;controller=C.Style(host,{slots=slots,trackNative=true}) end
  controller.fixedElement=rule;controller:Configure(rule,slots or controller.slots,variant~=nil and variant or controller.options.variant);return controller:Apply(true)
 end
 function UI:RefreshFontRules() for controller in pairs(self.fixedControllers) do controller:Apply(true,true) end end
end
