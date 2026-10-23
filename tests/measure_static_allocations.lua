-- Run from the product worktree: lua tests/measure_static_allocations.lua [stable|native]
-- Uses the embedded library through ui_fixture by default.
-- Diagnostic collections delimit measurements only; no production runtime is modified.
local source='addon/LycheeGroup/Libs/LycheeUI/'
local rawLoad=loadfile
loadfile=function(path)
 local resolved=path
 if arg[2]=='cow' and resolved==source..'Styles.lua' then
  local file=assert(io.open(resolved));local text=file:read('*a');file:close()
  local helper=[[
local function ProbeOverlay(base,patch)
 if not patch or next(patch)==nil then return base end
 local out
 for key,value in pairs(patch) do
  local previous=base[key];local nextValue=value
  if type(value)=="table" and not value[1] and type(previous)=="table" then nextValue=ProbeOverlay(previous,value) end
  if nextValue~=previous then if not out then out={};for name,item in pairs(base) do out[name]=item end end;out[key]=nextValue end
 end
 return out or base
end
]]
  text=text:gsub('function Library.AttachStyles%(UI,C%)',helper..'function Library.AttachStyles(UI,C)',1)
  text=text:gsub('UI.recipes=Library.ResolveRecipes%(UI.options.recipeDefaults,UI.options.recipes%)','UI.recipes=ProbeOverlay(ProbeOverlay(Library.ComponentRecipes,UI.options.recipeDefaults),UI.options.recipes)',1)
  return loadstring(text,'@'..resolved)
 end
 return rawLoad(resolved)
end
local f=dofile('tests/ui_fixture.lua')('enUS');local A,U,S=f.A,f.U,f.S
A:SetSetting('reduceMotion',true)
local stats,depth,child={},0,{}
local function Watch(object,key,label)
 local fn=object[key];if type(fn)~='function' then return end
 label=label or key;local row={label=label,calls=0,inclusive=0,exclusive=0};stats[#stats+1]=row
 object[key]=function(...)
  depth=depth+1;local level=depth;child[level]=0;local before=collectgarbage('count')
  local a,b,c,d=fn(...)
  local delta=collectgarbage('count')-before;row.calls=row.calls+1;row.inclusive=row.inclusive+delta;row.exclusive=row.exclusive+delta-child[level]
  depth=depth-1;if depth>0 then child[depth]=(child[depth] or 0)+delta end
  if key=="MeasureText" then return a,b end;return a
 end
end
for name,fn in pairs(U.C) do if type(fn)=='function' then Watch(U.C,name,'C.'..name) end end
for _,name in ipairs({'SetFont','RefreshFontRules','ApplyElements'}) do Watch(U.context,name,'ctx.'..name) end
local function Reset() for _,row in ipairs(stats) do row.calls,row.inclusive,row.exclusive=0,0,0 end end
local function Count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function Shape()
 local ctx=U.context;local controllers,records,properties,states,active,sources,fixedRecords=0,0,0,0,0,0,0
 local targets,fonts,controllerRoots,panelRoots={ },0,{ },{ }
 for _,node in ipairs(S.nodes) do
  local c=node._lycheeStyleController
  if c then controllerRoots[#controllerRoots+1]=c;controllers=controllers+1;records=records+Count(c.records);states=states+Count(c.states);active=active+Count(c.active);sources=sources+Count(c.sources)
   for _,r in pairs(c.records) do properties=properties+Count(r.base)+Count(r.applied);fixedRecords=fixedRecords+1 end
  end
  for _,visual in ipairs(node._lycheeVisuals or {}) do if visual._lycheePanel then panelRoots[#panelRoots+1]=visual end end
  if node._lycheeFixedRecords then targets[#targets+1]=node._lycheeFixedRecords end
 end
 local baseline=0;for _,ref in pairs(ctx.fontStyles) do fonts=fonts+1;baseline=baseline+Count(ref) end
 local layouts,items=0,0;for _,layout in ipairs(ctx.layouts) do layouts=layouts+1;items=items+Count(layout.records) end
 print(string.format('SHAPE native=%d fonts=%d fontFields=%d controllers=%d records=%d baseAppliedFields=%d states=%d active=%d sources=%d fixedScan=%d elements=%d layouts=%d layoutRecords=%d',#S.nodes,fonts,baseline,controllers,records,properties,states,active,sources,Count(ctx.fixedControllers),Count(ctx.elements),layouts,items))
 -- Graphs overlap, so counts cannot be added. Native/frame references are leaves.
 local function Graph(root)
  local seen={};local tables,entries,functions=0,0,0;local nodes={}
  local function Visit(value)
   if type(value)=='function' then if not seen[value] then seen[value]=true;functions=functions+1 end;return end
   if type(value)~='table' or seen[value] or value.GetObjectType then return end
   seen[value]=true;tables=tables+1;nodes[#nodes+1]=value
   for key,item in pairs(value) do entries=entries+1;if key~='controller' and key~='parent' and key~='host' and key~='target' and key~='UI' and key~='context' then Visit(item) end end
  end
  Visit(root)
  local copies={};for i=1,#nodes do copies[i]=false end
  local before=collectgarbage('count')
  for i,original in ipairs(nodes) do local copy={};for key,value in pairs(original) do copy[key]=value end;copies[i]=copy end
  local tableKiB=collectgarbage('count')-before
  return tables,entries,functions,tableKiB
 end
 for _,name in ipairs({'fontStyles','layouts','elements','controllers','panels'}) do local a,b,c,k=Graph(name=='controllers' and controllerRoots or name=='panels' and panelRoots or ctx[name]);print(string.format('GRAPH %s tables=%d entries=%d functions=%d shallowCopyKiB=%.3f',name,a,b,c,k)) end
end
local function Phase(label,fn,show)
 collectgarbage('collect');Reset();local before=collectgarbage('count');local nodes=#S.nodes;collectgarbage('stop');fn();local allocated=collectgarbage('count')-before;collectgarbage('restart');collectgarbage('collect');local retained=collectgarbage('count')-before
 print(string.format('PHASE %s allocKiB=%.3f retainedKiB=%.3f nativeDelta=%d totalKiB=%.3f',label,allocated,retained,#S.nodes-nodes,collectgarbage('count')))
 if show then table.sort(stats,function(a,b) return a.exclusive>b.exclusive end);for i=1,math.min(14,#stats) do local row=stats[i];if row.calls>0 then print(string.format('CALL %-25s calls=%d inclusiveKiB=%.3f exclusiveKiB=%.3f',row.label,row.calls,row.inclusive,row.exclusive)) end end;Shape() end
end
Phase('first_find',function() A:Open('find') end,true)
Phase('first_settings',function() A:Open('settings') end,true)
Phase('first_all_pages',function() for _,page in ipairs({'find','create','notes','settings'}) do A:Open(page) end end,true)
if arg[1]=='stable' or arg[1]=='native' then
 local function Font(self,a,b,c) local t=self.font;t[1],t[2],t[3]=a,b,c;return true end
 local function Color(self,a,b,c,d) local t=self.color or {};self.color=t;t[1],t[2],t[3],t[4]=a,b,c,d end
 local function Vertex(self,a,b,c,d) local t=self.vertex or {};self.vertex=t;t[1],t[2],t[3],t[4]=a,b,c,d or 1;self.alpha=d or 1 end
 local function Shadow(self,a,b) local t=self.shadowOffset or {};self.shadowOffset=t;t[1],t[2]=a,b end
 local function Insets(self,a,b,c,d) local t=self.textInsets or {};self.textInsets=t;t[1],t[2],t[3],t[4]=a,b,c,d end
 local function ShadowRead(self) local t=self.shadowOffset;if t then return t[1],t[2] end;return 0,0 end
 local function InsetsRead(self) local t=self.textInsets;if t then return t[1],t[2],t[3],t[4] end;return 0,0,0,0 end
 for _,node in ipairs(S.nodes) do
  node.SetFont,node.SetTextColor,node.SetVertexColor,node.SetShadowOffset,node.SetTextInsets=Font,Color,Vertex,Shadow,Insets
  node.GetShadowOffset,node.GetTextInsets=ShadowRead,InsetsRead
  local records={};for i,point in ipairs(node.points) do records[i]=point end
  node.ClearAllPoints=function(self) for i=#self.points,1,-1 do self.points[i]=nil end;self.allPoints=nil end
  node.SetPoint=function(self,a,b,c,x,y)
   local index=#self.points+1;for i,point in ipairs(self.points) do if point[1]==a then index=i;break end end
   local point=records[index] or {};records[index]=point;self.points[index]=point;point[1],point[2],point[3],point[4],point[5]=a,b,c,x,y
  end
  local regions,children={},{};for _,entry in ipairs(node.children) do if entry:GetObjectType()=='Texture' or entry:GetObjectType()=='FontString' then regions[#regions+1]=entry else children[#children+1]=entry end end
  node.GetRegions=function() return unpack(regions) end;node.GetChildren=function() return unpack(children) end
 end
 print('MODE stable-native-storage: native setter/readback Lua tables reused; text metric substitute remains unchanged')
end
if arg[1]=='native' then
 local metrics={}
 local textUnits={}
 local function Units(self)
  local record=metrics[self]
  if not record or record.text~=self.text then
   record=textUnits[self.text];if record then metrics[self]=record;return record end
   record={text=self.text,total=0,lines={}};metrics[self]=record;textUnits[self.text]=record
   for line in (self.text.."\n"):gmatch("(.-)\n") do
    local units=0;for ch in line:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do units=units+(#ch>1 and 1 or .55) end
    record.lines[#record.lines+1]=units;record.total=record.total+units
   end
   record.total=record.total+(#record.lines-1)*.55
  end
  return record
 end
 local function NaturalWidth(self) return Units(self).total*(self.font[2] or 14) end
 local function StringHeight(self)
  local lines=0;for _,units in ipairs(Units(self).lines) do lines=lines+math.max(1,self.wrap and math.ceil(units*(self.font[2] or 14)/math.max(1,self.w)) or 1) end
  if self.maxLines then lines=math.min(lines,self.maxLines) end
  return lines*((self.font[2] or 14)*1.2+(self.spacing or 0))
 end
 for _,node in ipairs(S.nodes) do
  if node._objectType=='FontString' or node._objectType=='EditBox' then
   Units(node);local expectedW,expectedH=node:GetUnboundedStringWidth(),node:GetStringHeight()
   assert(math.abs(expectedW-NaturalWidth(node))<.000001 and math.abs(expectedH-StringHeight(node))<.000001,'native metric substitute must preserve initial fixture values')
   node.GetUnboundedStringWidth,node.GetStringWidth,node.GetStringHeight=NaturalWidth,NaturalWidth,StringHeight
  end
 end
 print('MODE native-text-metrics: same fixture formulas, glyph units cached; native readback no longer allocates Lua gmatch iterators')
end
Phase('warm_12_navigation',function() for i=1,12 do for _,page in ipairs({'find','create','notes','settings'}) do A:Open(page) end end end,true)
Phase('warm_12_font',function() for i=1,12 do for _,scale in ipairs({70,100,130,100}) do A:SetSetting('fontScale',scale) end end end,true)
U:Hide(true)
