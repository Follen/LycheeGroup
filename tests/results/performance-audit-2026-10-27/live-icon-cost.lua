-- Private method comparison, not a complete old/new library comparison.
-- The legacy function is copied from 72c4f379 Components.lua without changes.
-- No product objects, global method replacements, forced GC, or visible UI.
local probe=...
local library=assert(LycheeUI)
local installed=library
local prototypeMethod=library.Context.SetIconState
local parent,driver,ctx,unowned,fixed,style
local originalMethod,originalOwn
local savedMethods={}
local cleaned,finished=false,false
local iterations,batch,warmup=500,25,25
local report={schema=1,scope='private_context_icon_method_comparison',library=library.versionString,
 sourceCommit='40a900539510fe8af259a90d1e3c328093756fde',legacyMethodCommit='72c4f379cb6cb32162dfdd8182e1a5db689b5ba4',
 comparison='Only SetIconState is swapped on one private Context. Both variants use the currently installed Styles implementation.',
 input={iterationsPerScene=iterations,maxOperationsPerCallback=batch,warmupOperations=warmup,selected=false,hovered=false},
 clock='debugprofilestop milliseconds',gc='natural; no GC API calls',
 timing='One operation: Glyph:SetSelected(false,false), plus Style:Apply(true) in declared_color_apply. No wrappers during timing.',
 counters='Separate pass; temporary instance methods only on the private scene Texture. Setup/warmup excluded.',
 semantics='The legacy method overwrites declared color and Apply repairs it each time; its declared scene ends at alpha 1. Current feedback preserves color and ends at iconIdleAlpha.',
 scenes={}}
local function SameIconChannel(value,target,byte)
 return math.abs(value-target)<=.000001 or math.floor(value*255+.5)==byte
end
local function LegacyIconState(self,icon,selected,hovered)
 icon=icon._lycheeTexture or icon
 local gray=not selected
 if icon:IsDesaturated()~=gray then icon:SetDesaturated(gray) end
 local value=selected and 1 or hovered and self.Theme.iconHoverTint or self.Theme.iconIdleTint
 local byte=math.floor(value*255+.5)
 local r,g,b=icon:GetVertexColor()
 if not SameIconChannel(r,value,byte) or not SameIconChannel(g,value,byte) or not SameIconChannel(b,value,byte) then icon:SetVertexColor(value,value,value) end
 local alpha=selected and 1 or hovered and self.Theme.iconHoverAlpha or self.Theme.iconIdleAlpha
 if not SameIconChannel(icon:GetAlpha(),alpha,math.floor(alpha*255+.5)) then icon:SetAlpha(alpha) end
end
local function RestoreMethods()
 local restored=true
 for index=#savedMethods,1,-1 do
  local entry=savedMethods[index];entry.object[entry.name]=entry.own
  restored=restored and entry.object[entry.name]==entry.method
  savedMethods[index]=nil
 end
 return restored
end
local function Cleanup()
 if cleaned then return end
 cleaned=true
 if driver then driver:SetScript('OnUpdate',nil);driver:Hide() end
 local restored=RestoreMethods()
 if ctx then ctx.SetIconState=originalOwn end
 if style then style:Release() end
 if ctx then ctx:Hide() end
 if parent then parent:Hide() end
 report.cleanup={methodsRestored=restored,contextMethodRestored=ctx and ctx.SetIconState==originalMethod or false,
  driverStopped=not driver or driver:GetScript('OnUpdate')==nil,parentHidden=not parent or not parent:IsShown(),
  motionJobs=ctx and ctx.Motion:Count() or 0,globalLibraryUnchanged=LycheeUI==installed,
  prototypeMethodUnchanged=library.Context.SetIconState==prototypeMethod}
end
assert(probe:OnCleanup(Cleanup))
if InCombatLockdown() then return probe:Fail('combat') end
assert(probe:Guard(function() return not InCombatLockdown() end,{'PLAYER_REGEN_DISABLED'},'combat_started'))
assert(probe:Async(30))
assert(type(debugprofilestop)=='function','profiling_clock_required')
parent=CreateFrame('Frame',nil,UIParent);parent:SetSize(24,24);parent:Hide()
ctx=library:CreateContext({parent=parent,reducedMotion=true})
originalMethod,originalOwn=ctx.SetIconState,rawget(ctx,'SetIconState')
unowned=ctx.C.Glyph(parent,'book',20)
fixed=ctx.C.Glyph(parent,'book',20)
local declared={.17,.38,.61,1}
style=ctx.C.Style(fixed,{style={root={color=declared}}})
local definitions={
 {scene='unowned_stable',variant='legacy',icon=unowned,method=LegacyIconState},
 {scene='unowned_stable',variant='current',icon=unowned,method=originalMethod},
 {scene='declared_color_apply',variant='legacy',icon=fixed,method=LegacyIconState,apply=true},
 {scene='declared_color_apply',variant='current',icon=fixed,method=originalMethod,apply=true},
}
local stages={}
for _,pass in ipairs({'timing','counters'}) do for _,definition in ipairs(definitions) do stages[#stages+1]={definition=definition,pass=pass} end end
local stageIndex,done,warmed=1,0,false
local current,samples,counts
local function Operation(definition)
 definition.icon:SetSelected(false,false)
 if definition.apply then style:Apply(true) end
end
local function InstallCounters(texture)
 for _,name in ipairs({'GetVertexColor','GetAlpha','IsDesaturated','SetVertexColor','SetAlpha','SetDesaturated'}) do
  local method=texture[name]
  savedMethods[#savedMethods+1]={object=texture,name=name,method=method,own=rawget(texture,name)}
  counts[name]=0
  texture[name]=function(self,...) counts[name]=counts[name]+1;return method(self,...) end
 end
end
local function BeginStage()
 local stage=stages[stageIndex];if not stage then return false end
 RestoreMethods()
 current=stage.definition;ctx.SetIconState=current.method
 samples,counts={},{}
 done,warmed=0,false
 return true
end
local function Output(definition)
 local image=definition.icon.texture
 local r,g,b,a=image:GetVertexColor();local alpha=image:GetAlpha()
 local expected=definition.apply and declared or {ctx.Theme.iconIdleTint,ctx.Theme.iconIdleTint,ctx.Theme.iconIdleTint,1}
 local expectedAlpha=definition.apply and definition.variant=='legacy' and 1 or ctx.Theme.iconIdleAlpha
 local ok=SameIconChannel(r,expected[1],math.floor(expected[1]*255+.5))
  and SameIconChannel(g,expected[2],math.floor(expected[2]*255+.5))
  and SameIconChannel(b,expected[3],math.floor(expected[3]*255+.5))
  and SameIconChannel(alpha,expectedAlpha,math.floor(expectedAlpha*255+.5)) and image:IsDesaturated()
 return {r=r,g=g,b=b,vertexAlpha=a,alpha=alpha,gray=image:IsDesaturated(),expectedAlpha=expectedAlpha,ok=ok}
end
local function EndStage()
 local stage=stages[stageIndex]
 RestoreMethods()
 local output=Output(current)
 local entry={scene=current.scene,variant=current.variant,pass=stage.pass,iterations=done,output=output}
 if stage.pass=='timing' then
  local sum=0;for _,value in ipairs(samples) do sum=sum+value end;table.sort(samples)
  entry.timing={samples=#samples,totalMs=sum,p50Ms=samples[math.ceil(#samples*.5)],p95Ms=samples[math.ceil(#samples*.95)],maxMs=samples[#samples]}
 else entry.counts=counts end
 report.scenes[#report.scenes+1]=entry
 if not output.ok then probe:Log(report);return probe:Fail('private_icon_output_changed') end
 stageIndex=stageIndex+1
 if BeginStage() then return end
 Cleanup();finished=true;report.ok=true;probe:Finish(report)
end
BeginStage()
driver=CreateFrame('Frame')
driver:SetScript('OnUpdate',assert(probe:Callback(function()
 if finished or probe:IsCancelled() then return end
 if not warmed then
  for i=1,warmup do Operation(current) end
  warmed=true
  if stages[stageIndex].pass=='counters' then InstallCounters(current.icon.texture) end
  return
 end
 local n=math.min(batch,iterations-done)
 if stages[stageIndex].pass=='timing' then
  for i=1,n do local start=debugprofilestop();Operation(current);samples[#samples+1]=debugprofilestop()-start end
 else for i=1,n do Operation(current) end end
 done=done+n
 if done==iterations then EndStage() end
end)))
driver:Show()
