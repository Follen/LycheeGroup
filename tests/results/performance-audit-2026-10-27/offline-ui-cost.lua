-- Offline Lua 5.1 audit. Run from the LycheeUI source worktree:
-- lua <LycheeGroup>/tests/results/performance-audit-2026-10-27/offline-ui-cost.lua
-- Runtime files are loaded from exact git commits; no source files are changed.
-- GC controls below are OFFLINE ONLY. live-icon-cost.lua never calls GC.
-- Native Texture writes are normalized to mutate persistent storage when a
-- Motion test measures Lua-owned allocation, avoiding the general stub's fake
-- native SetVertexColor table allocation.
local S=dofile('tests/stubs.lua')
local function boot(ref)
 _G.LycheeUI=nil;S.Install()
 local meta=getmetatable(UIParent);local old=meta.__index
 meta.__index=function(self,key)
  if self._objectType=='Frame' and (key=='GetTextColor' or key=='GetVertexColor') then return nil end
  if type(old)=='function' then return old(self,key) end;return old[key]
 end
 local p={}
 for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do
  local h=assert(io.popen('git show '..ref..':'..file..'.lua'));local src=h:read('*a');h:close();assert(loadstring(src,file..'.lua'))('PerfAudit',p)
 end
 return p.LycheeUI,meta,old
end

local refs={'72c4f379cb6cb32162dfdd8182e1a5db689b5ba4','40a900539510fe8af259a90d1e3c328093756fde'}
local function Measure(label,run,n,counts)
 for i=1,100 do run(i) end
 for k in pairs(counts or {}) do counts[k]=0 end
 collectgarbage('collect');collectgarbage('stop')
 local before=collectgarbage('count');local t=os.clock()
 for i=1,n do run(i) end
 local elapsed=(os.clock()-t)*1000;local delta=collectgarbage('count')-before
 collectgarbage('restart')
 local extra='';for _,key in ipairs({'GetVertexColor','GetAlpha','IsDesaturated','SetVertexColor','SetAlpha','SetDesaturated'}) do if counts and counts[key] then extra=extra..' '..key..'='..counts[key] end end
 print(string.format('%s n=%d CPU_ms=%.3f GC_stopped_KiB=%.3f%s',label,n,elapsed,delta,extra))
end
local function NativeWrites(image)
 image.vertex={1,1,1,1}
 image.SetVertexColor=function(self,r,g,b,a) self.vertex[1],self.vertex[2],self.vertex[3],self.vertex[4]=r,g,b,a or 1;self.alpha=a or 1 end
end
print('OFFLINE Lua='.._VERSION..' clock=os.clock; current source=40a9005; Group=73b4254')
for _,ref in ipairs(refs) do
 local L,meta,old=boot(ref);local c=L:CreateContext({reducedMotion=true});local C=c.C
 print('VERSION '..ref..' '..L.versionString)
 local glyph=C.Glyph(UIParent,'book',20);glyph:SetSelected(false,false)
 local counts={}
 for _,name in ipairs({'GetVertexColor','GetAlpha','IsDesaturated','SetVertexColor','SetAlpha','SetDesaturated'}) do
  local method=glyph.texture[name];counts[name]=0
  glyph.texture[name]=function(self,...) counts[name]=counts[name]+1;return method(self,...) end
 end
 Measure('stable_unowned_glyph',function() glyph:SetSelected(false,false) end,10000,counts)
 local button=C.Button(UIParent,'button',100)
 Measure('stable_unowned_button',function() button:RefreshStyle(true) end,10000)
 local fixed=C.Glyph(UIParent,'book',20);local style=C.Style(fixed,{style={root={color={.17,.38,.61,1}}}})
 Measure('fixed_color_feedback_apply',function() fixed:SetSelected(false,false);style:Apply(true) end,10000)
 Measure('fixed_color_apply_only',function() style:Apply(true) end,10000)
 local plain=C.Glyph(UIParent,'book',20);plain:SetSelected(false,false)
 for _,case in ipairs({'glyph','button'}) do
  local run=case=='glyph' and function() plain:SetSelected(false,false) end or function() button:RefreshStyle(true) end
  local samples={}
  for sample=1,3 do collectgarbage('collect');local t=os.clock();for i=1,100000 do run() end;samples[sample]=(os.clock()-t)*1000 end
  print(ref:sub(1,7)..' stable_'..case..' n=100000 CPU_ms='..table.concat(samples,','))
 end
 local immediate=C.Glyph(UIParent,'book',20);NativeWrites(immediate.texture)
 local getter=immediate.texture.GetVertexColor;local reads={GetVertexColor=0}
 immediate.texture.GetVertexColor=function(self) reads.GetVertexColor=reads.GetVertexColor+1;return getter(self) end
 local target={.17,.38,.61,1}
 Measure('reducedMotion_Color_immediate',function() c.Motion:Color(immediate,target,.1) end,10000,reads)
 print('immediate_jobs='..c.Motion:Count())
 meta.__index=old
end
do
 local L,meta,old=boot(refs[2])
 for _,n in ipairs({1,4,16,64}) do
  local c=L:CreateContext({reducedMotion=true});local glyph=c.C.Glyph(UIParent,'book',20);local controllers={}
  for i=1,n do local owner=L:CreateContext({reducedMotion=true});controllers[i]=owner.C.Style(CreateFrame('Frame',nil,UIParent),{slots={icon=glyph},style={icon={color={.17,.38,.61,1}}}}) end
  Measure('overlapping_owners_'..n,function() glyph:SetSelected(false,false) end,10000)
  local oldpairs=pairs;local visits=0
  _G.pairs=function(tab)
   if tab~=glyph._lycheeFixedRecords then return oldpairs(tab) end
   return function(state,key) local k,v=next(state,key);if k then visits=visits+1 end;return k,v end,tab,nil
  end
  glyph:SetSelected(false,false);local feedbackVisits=visits;visits=0
  for _,controller in ipairs(controllers) do controller:Apply(true) end
  _G.pairs=oldpairs
  print(string.format('owners=%d record_visits_feedback=%d record_visits_all_Apply=%d',n,feedbackVisits,visits))
  for _,controller in ipairs(controllers) do controller:Release() end
 end
 local c=L:CreateContext({reducedMotion=true});local glyph=c.C.Glyph(UIParent,'book',20)
 local style=c.C.Style(glyph,{style={root={color={.17,.38,.61,1}}}})
 Measure('fixed_color_actual_hover_toggles',function(i) glyph:SetSelected(false,i%2==0);style:Apply(true) end,10000)
 meta.__index=old
end
do
 local L,meta,old=boot(refs[2]);local c=L:CreateContext();local M=c.Motion
 local target={.17,.38,.61,1};local glyphs={}
 for i=1,100 do local glyph=c.C.Glyph(UIParent,'book',20);NativeWrites(glyph.texture);glyphs[i]=glyph;M:Color(glyph,target,100) end
 Measure('Motion_100_jobs_10000_frames',function() M:Tick(.000001) end,10000)
 M:StopAll();local used=0;for _ in pairs(M.tickBuffer) do used=used+1 end
 print(string.format('Motion_cleanup jobs=%d buffer_entries=%d running=%s OnUpdate=%s',M:Count(),used,tostring(M.running),tostring(M.driver:GetScript('OnUpdate'))))
 local panel={color={1,1,1,1},SetColor=function(self,color) self.color=color end}
 local a,b={.2,.3,.4,1},{.7,.8,.9,1}
 for _,item in ipairs({{name='Panel_retarget',object=panel},{name='Glyph_retarget',object=glyphs[1]}}) do
  Measure(item.name,function(i) M:Color(item.object,i%2==0 and a or b,1);M:Tick(.000001) end,10000)
  M:StopAll()
 end
 meta.__index=old
end
for _,ref in ipairs(refs) do
 local L,meta,old=boot(ref)
 local c=L:CreateContext({reducedMotion=true,elementDefaults={item={slotKinds={root='box'}}},elements={item={base={root={alpha=.5}}}}})
 local target=CreateFrame('Frame',nil,UIParent);local weak=setmetatable({},{__mode='v'})
 collectgarbage('collect');local before=collectgarbage('count')
 for i=1,1000 do
  local scope={};weak[i]=scope
  c.C.Element(target,'item',{scope=scope});c.C.ReleaseElement(target)
  if target._lycheeStyleController then target._lycheeStyleController:Release() end
 end
 collectgarbage('collect')
 local groups,alive,active=0,0,0
 for _,group in pairs(c.elementScopes) do groups=groups+1;for _ in pairs(group) do active=active+1 end end
 for _ in pairs(weak) do alive=alive+1 end
 print(string.format('%s scope_cycles=1000 retained_KiB=%.3f empty_scope_groups=%d retained_scope_keys=%d active_targets=%d',ref:sub(1,7),collectgarbage('count')-before,groups,alive,active))
 meta.__index=old
end
