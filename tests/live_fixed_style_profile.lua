local probe,library=...
local installed=LycheeUI
library=library or installed
if not library or not library.CreateContext then return probe:Fail("library_unavailable") end
if InCombatLockdown() then return probe:Fail("combat") end
assert(probe:Async(12))
local parent,context,list,driver
local originals={}
local report={revision=library.version,sourceHash=library.auditSourceHash or "installed",isolated=library~=installed,build=select(2,GetBuildInfo()),rows=300,viewport=400,stride=40,iterations=120,gc="natural",scope="private_context",counts={},baseline={sumMs=0,maxBatchMs=0,batches=0},instrumented={sumMs=0,maxBatchMs=0,batches=0}}
assert(probe:OnCleanup(function()
 if driver then driver:SetScript("OnUpdate",nil);driver:Hide() end
 for _,entry in ipairs(originals) do entry.target[entry.name]=entry.method end
 if list then list:Clear() end
 if context then context:Hide() end
 if parent then parent:Hide() end
end))
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(500,500);parent:Hide()
context=library:CreateContext({parent=parent,reducedMotion=true,elementDefaults={row={template=true,slotKinds={root="box",label="text",icon="texture"}}},elements={row={base={label={fontSize=18,lineHeight=24},icon={texture=134400,points={{"LEFT","$root","LEFT",12,0}}}}}}})
list=context.C.List(parent,200,400,40,nil,nil,{initializeRow=function(row) row.icon=context.C.Icon(row,16) end})
context.C.Element(list,"audit.list",{rowTemplate="row"})
local ids={};for i=1,300 do ids[i]=i end
list:SetItems(ids,function(row,key) context:SetText(row.title,tostring(key)) end)
for i=1,5 do list:Refresh(true) end
report.pool=#list.rows
local methods={"SetFont","SetSpacing","SetHeight","SetJustifyV","SetTexture","SetAtlas","SetTexCoord","SetPoint","ClearAllPoints"}
local function Observe(target)
 for _,name in ipairs(methods) do
  local method=target[name]
  if method then
   originals[#originals+1]={target=target,name=name,method=method}
   target[name]=function(self,...)
    report.counts[name]=(report.counts[name] or 0)+1
    return method(self,...)
   end
  end
 end
end
local phase,done="baseline",0
driver=CreateFrame("Frame")
driver:SetScript("OnUpdate",assert(probe:Callback(function()
 if probe:IsCancelled() then return end
 local start=debugprofilestop()
 for i=1,5 do list:Refresh(true) end
 local cost=debugprofilestop()-start
 local group=report[phase];group.sumMs=group.sumMs+cost;group.maxBatchMs=math.max(group.maxBatchMs,cost);group.batches=group.batches+1
 done=done+5
 if done<120 then return end
 if phase=="baseline" then
  for _,row in ipairs(list.rows) do Observe(row.title);Observe(row.icon._lycheeTexture or row.icon) end
  phase,done="instrumented",0
 else
  driver:SetScript("OnUpdate",nil);driver:Hide()
  local row=list.rows[1]
  local font,size,flags=row.title:GetFont();local icon=row.icon._lycheeTexture or row.icon
  local point,relative,relativePoint,x,y=icon:GetPoint(1)
  report.output={text=row.title:GetText(),font=font,size=size,flags=flags,height=row.title:GetHeight(),texture=icon:GetTexture(),point=point,relativeIsRoot=relative==row,relativePoint=relativePoint,x=x,y=y}
  report.poolAfter=#list.rows
  for _,entry in ipairs(originals) do entry.target[entry.name]=entry.method end
  originals={}
  list:Clear();context:Hide();parent:Hide()
  report.cleanup={idsCleared=list.ids==nil,renderCleared=list.render==nil,jobs=context.Motion:Count(),parentHidden=not parent:IsShown(),driverStopped=driver:GetScript("OnUpdate")==nil,installedLibraryUnchanged=LycheeUI==installed}
  if report.poolAfter~=report.pool or report.output.size~=18 or report.output.texture~=134400 or report.cleanup.jobs~=0 then return probe:Fail("output_or_cleanup_changed") end
  probe:Finish(report)
 end
end)))
