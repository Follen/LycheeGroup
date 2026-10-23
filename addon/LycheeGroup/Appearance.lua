-- Visual configuration joins the shared component theme without owning game data.
local A=_G.LycheeGroup
local Library=_G.LycheeUI
local Configuration=A.Configuration
local Appearance={themes={},tableStates={}}
A.Appearance=Appearance
local definitions={}
for scope,defaults in pairs(A.StyleDefaults) do
 local schema=Library:GetThemeSchema(defaults)
 schema.font=nil -- The product font is selected once through settings.font.
 Appearance.themes[scope]=schema
 for token,field in pairs(schema) do
  definitions["theme."..scope.."."..token]={default=field.default,type=field.type,storage="account",min=field.min,max=field.max,exclusiveMin=field.exclusiveMin}
 end
end

local function Position(value)
 if value==false then return true end
 if type(value)~="table" then return false,"expected false or an anchor position" end
 local anchors={TOPLEFT=true,TOP=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,BOTTOMLEFT=true,BOTTOM=true,BOTTOMRIGHT=true}
 return anchors[value.point] and anchors[value.relativePoint] and type(value.x)=="number" and type(value.y)=="number",
  "position requires valid point/relativePoint anchors and numeric x/y"
end
definitions["layout.window.width"]={type="number",min=1,storage="character",legacy={path={"windowSize","width"}}}
definitions["layout.window.height"]={type="number",min=1,storage="character",legacy={path={"windowSize","height"}}}
definitions["layout.floating.position"]={default=false,type={"table","boolean"},validate=Position,storage="account",legacy={key="floatingPosition"}}
definitions["layout.find.railCollapsed"]={default=false,type="boolean",storage="character",legacy={path={"find","railCollapsed"}}}

local tables={
 findResults={columns={"title","leader","members","ilvl","rating","description","age"},sorts={"members","ilvl","rating","age"}},
 findRaidResults={columns={"title","leader","members","ilvl","rating","description","age"},sorts={"members","ilvl","rating","age"}},
 findApplications={columns={"title","leader","members","status","actions"},sorts={"members","status"}},
 createApplicants={columns={"name","role","faction","rating","mapScore","ilvl","comment","actions"},sorts={"rating","mapScore","ilvl"}},
 notesRecords={columns={"player","timestamp"},sorts={"timestamp"},sort="timestamp",descending=true},
 notesHistory={columns={"activity","level","duration","teammates","completed"},sorts={"level","duration","completed"},sort="completed",descending=true},
 notesHistoryMembers={columns={"player","actions"},sorts={}},
 blockedLeaders={columns={"name","realm","actions"},sorts={}},
}
local stateIDs=setmetatable({},{__mode="k"})
local function TableKey(id,field) return "layout.tables."..id.."."..field end
for id,info in pairs(tables) do
 local sortChoices={false};for _,key in ipairs(info.sorts) do sortChoices[#sortChoices+1]=key end
 definitions[TableKey(id,"sortKey")]={default=info.sort or false,type={"string","boolean"},enum=sortChoices,storage="character",legacy={path={"tableLayouts",id,"sortKey"}}}
 definitions[TableKey(id,"descending")]={default=info.descending==true,type="boolean",storage="character",legacy={path={"tableLayouts",id,"descending"}}}
 for _,column in ipairs(info.columns) do
  definitions[TableKey(id,"widths."..column)]={type="number",min=.001,storage="character",legacy={path={"tableLayouts",id,"widths",column}}}
 end
end
assert(Configuration:RegisterDefinitions(definitions))

function Appearance:GetTheme(scope)
 local overrides={}
 Configuration:EnsureReady()
 for token in pairs(self.themes[scope]) do
  local key="theme."..scope.."."..token
  local source=Configuration:GetSource(key)
  if source.kind~="default" then overrides[token]=Configuration:Get(key) end
 end
 return overrides
end
function A:ResolveConfigurationSnapshot(snapshot)
 for scope,defaults in pairs(self.StyleDefaults) do
  local theme=Library.ResolveTheme(Appearance:GetTheme(scope),defaults)
  for token in pairs(Appearance.themes[scope]) do snapshot["theme."..scope.."."..token]=theme[token] end
 end
end
function A:ValidateConfiguration(previous,changes)
 if previous and not changes then changes=Configuration:ChangesSince(previous) end
 for scope,defaults in pairs(self.StyleDefaults) do
  local changed=previous==nil
  if not changed then
   for token in pairs(Appearance.themes[scope]) do
    local key="theme."..scope.."."..token
    if changes[key] then changed=true;break end
   end
  end
  if changed then
   local ok,err=Library:ValidateTheme(Appearance:GetTheme(scope),defaults)
   if not ok then return false,scope..": "..err end
  end
 end
 return true
end
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
  if ok and header.layoutWidth then header:Layout(header.layoutWidth) end
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
 local scopes,changedTables={},{}
 local window,position,rail,settings
 for key in pairs(changes) do
  if key:sub(1,9)=="settings." then settings=true end
  local scope=key:match("^theme%.([^.]+)%.")
  if scope then scopes[scope]=true end
  local id=key:match("^layout%.tables%.([^.]+)%.")
  if id then changedTables[id]=true end
  if key=="layout.window.width" or key=="layout.window.height" then window=true end
  if key=="layout.floating.position" then position=true end
  if key=="layout.find.railCollapsed" then rail=true end
 end
 for id in pairs(changedTables) do Appearance:RefreshTableState(id) end
 if Appearance.savingTable then changedTables[Appearance.savingTable]=nil end
 if Appearance.savingRail then rail=nil end
 local ui=self.UI
 if scopes.main and self.Minimap then self.Minimap:ApplyAppearance() end
 if scopes.main and ui and ui.context then ui.context:SetTheme(Appearance:GetTheme("main")) end
 if scopes.floating and self.Floating and self.Floating.context then self.Floating.context:SetTheme(Appearance:GetTheme("floating")) end
 if position and self.Floating and self.Floating.frame then self.Floating:ResetPosition(true) end
 if ui and ui.frame then
  if window then ui:LoadWindowSize();ui:RefreshWindowSize() end
  if (next(changedTables) or rail) and ui.OnLayoutPreferencesChanged then ui:OnLayoutPreferencesChanged(changedTables,rail) end
  if settings and ui.pages.settings.frame then ui.pages.settings:Sync() end
 end
end

-- Convenience wrapper; Configuration is the common store for mixed presets.
A.API=A.API or {}
local API={version=1};A.API.Appearance=API
local function Scope(scope)
 if not Appearance.themes[scope] then return false,"unknown appearance scope: "..tostring(scope) end
 return true
end
function API:GetSchema(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local schema=Configuration:GetSchema();local result={}
 for token in pairs(Appearance.themes[scope]) do result[token]=schema["theme."..scope.."."..token] end
 return result
end
function API:Get(scope)
 local ok,err=Scope(scope);if not ok then return nil,err end
 local theme=Library.ResolveTheme(Appearance:GetTheme(scope),A.StyleDefaults[scope])
 -- Font selection is shared by both contexts and has its own persistent setting.
 theme.font=A.Fonts:GetPath()
 local copy={}
 for key,value in pairs(theme) do copy[key]=type(value)=="table" and {unpack(value)} or value end
 return copy
end
function API:Set(scope,values,options)
 local ok,err=Scope(scope);if not ok then return false,err end
 if type(values)~="table" then return false,"appearance values must be a token/value table" end
 local flat={};for token,value in pairs(values) do flat["theme."..scope.."."..tostring(token)]=value end
 return Configuration:Set(flat,options)
end
function API:Reset(scope,keys,options)
 local ok,err=Scope(scope);if not ok then return false,err end
 if type(keys)=="string" then keys={keys} end
 if type(keys)~="table" then return false,"reset requires a token or token array" end
 local flat={};for _,token in ipairs(keys) do flat[#flat+1]="theme."..scope.."."..tostring(token) end
 return Configuration:Reset(flat,options)
end
