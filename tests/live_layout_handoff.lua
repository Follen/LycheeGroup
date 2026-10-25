-- Matched diagnostic for exact native request/readback handoff between owners.
-- Uses only private off-screen controls. No forced GC or global method changes.
local probe=...
local lib=LycheeUI
local host,oldContext,newContext,oldLayout,newLayout
local objects,wrappers={},{}
local stopped=false
local report={scope='private_native_layout_handoff',revision=lib and lib.version,items=24,globalHooks=0,forcedCollections=0}
local function Restore()
 for _,entry in ipairs(wrappers) do entry.object[entry.key]=entry.own end
end
local function Cleanup()
 if stopped then return report.cleanup end
 stopped=true;Restore()
 if oldLayout then oldLayout:Release() end
 if newLayout then newLayout:Release() end
 if oldContext then oldContext:Hide() end
 if newContext then newContext:Hide() end
 if host then host:Hide() end
 local released=true
 for _,object in ipairs(objects) do if object._lycheeLayoutOwner or object._lycheeLayoutFields and next(object._lycheeLayoutFields) then released=false end end
 report.cleanup={hostHidden=not host or not host:IsShown(),ownersReleased=released,
  oldLayouts=oldContext and #oldContext.layouts or 0,newLayouts=newContext and #newContext.layouts or 0,
  oldMotion=oldContext and oldContext.Motion:Count() or 0,newMotion=newContext and newContext.Motion:Count() or 0}
 return report.cleanup
end
assert(probe:OnCleanup(Cleanup))
assert(lib and lib.layoutModes and lib.layoutModes.flex,'flex_required')
assert(probe:Guard(function() return not InCombatLockdown() end,{'PLAYER_REGEN_DISABLED'},'combat'))
local started=debugprofilestop()
host=CreateFrame('Frame',nil,UIParent);host:SetSize(720,640);host:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-1000);host:Show()
oldContext=lib:CreateContext({parent=host,reducedMotion=true})
newContext=lib:CreateContext({parent=host,reducedMotion=true})
local items={}
for i=1,24 do
 local f
 if i%2==1 then f=CreateFrame('Frame',nil,host)
 else f=host:CreateFontString(nil,'OVERLAY');f:SetFont(STANDARD_TEXT_FONT,14,'');f:SetText('H'..i);f:SetWordWrap(false) end
 f:SetSize(20,16);f:Show();objects[i]=f;items[i]={frame=f,width=20,height=16}
end
oldLayout=oldContext.C.Row(host,items,{mode='flex',gap=3,height=640});oldLayout:Layout()
local counts={SetWidth=0,SetHeight=0,ClearAllPoints=0,SetPoint=0}
for _,f in ipairs(objects) do for key in pairs(counts) do
 local method,own=f[key],rawget(f,key)
 wrappers[#wrappers+1]={object=f,key=key,own=own}
 f[key]=function(self,...) counts[key]=counts[key]+1;return method(self,...) end
end end
newLayout=newContext.C.Row(host,items,{mode='flex',gap=3,height=640});newLayout:Layout()
Restore()
local geometry={}
for i,f in ipairs(objects) do geometry[i]={f:GetSize()};local a,b,c,x,y=f:GetPoint();geometry[i][3],geometry[i][4]=x,y
 assert(f._lycheeLayoutOwner==newLayout and f._lycheeLayoutFields.width==newLayout and f._lycheeLayoutFields.height==newLayout,'new_owner_missing') end
oldLayout:Release();oldContext:Hide();newLayout:Layout()
for i,f in ipairs(objects) do local w,h=f:GetSize();local _,_,_,x,y=f:GetPoint();local saved=geometry[i]
 assert(w==saved[1] and h==saved[2] and x==saved[3] and y==saved[4],'released_owner_changed_successor') end
report.handoffWrites=counts;report.oldReleasePreservedSuccessor=true;report.elapsedMs=debugprofilestop()-started
probe:Log(string.format('handoff SetWidth=%d SetHeight=%d ClearAllPoints=%d SetPoint=%d oldReleasePreserved=true',counts.SetWidth,counts.SetHeight,counts.ClearAllPoints,counts.SetPoint))
local passed=counts.SetWidth==0 and counts.SetHeight==0 and counts.ClearAllPoints==0 and counts.SetPoint==0
Cleanup()
assert(report.cleanup.ownersReleased and report.cleanup.oldLayouts==0 and report.cleanup.newLayouts==0,'handoff_cleanup_failed')
if not passed then probe:Fail('handoff_repeated_identical_native_writes');return end
report.passed=true;probe:Finish(report)
