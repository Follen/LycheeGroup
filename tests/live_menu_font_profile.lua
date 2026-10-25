local probe,lib=...
local g=LycheeUI
local host,ctx,menu,d,m,rf,rw
local done
local r={scope='private_native_menu',sourceHash=lib and lib.auditSourceHash,revision=lib and lib.version,opens=100,entries=14,phases={},gc='natural'}
local function Clean()
if not done then
done=true
if d then d:SetScript('OnUpdate',nil);d:Hide() end
if m then m.SetFont,m.GetStringWidth=rf,rw end
if ctx then ctx:CloseMenu();ctx:Hide() end
if host then host:Hide() end
end
r.cleanup={driverStopped=not d or d:GetScript('OnUpdate')==nil,methodsRestored=not m or m.SetFont==rf and m.GetStringWidth==rw,
parentHidden=not host or not host:IsShown(),jobs=ctx and ctx.Motion:Count() or 0,
menuReleased=not menu or menu.items==nil and menu.anchor==nil and menu.list.ids==nil,installedLibraryUnchanged=LycheeUI==g}
return r.cleanup
end
assert(probe:OnCleanup(Clean))
if not lib then probe:Fail('missing_library');return end
if InCombatLockdown() then probe:Fail('combat');return end
assert(probe:Guard(function() return not InCombatLockdown() end,{'PLAYER_REGEN_DISABLED'},'combat'))
assert(probe:Async(15))
host=CreateFrame('Frame',nil,UIParent);host:SetSize(900,700);host:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',0,-1000);host:Show()
ctx=lib:CreateContext({host=host,reducedMotion=true,fontScale=1.3})
local a=ctx.C.ChoiceTrigger(host,120,function() end);a:SetPoint('TOPLEFT',host,'TOPLEFT',0,0);a:Show()
local items={};for i=1,14 do items[i]={value=i,label='Measured menu choice '..i} end
local options={kind='select'}
ctx:OpenMenu(a,items,nil,options);menu=assert(ctx:GetMenu());assert(menu:IsShown());ctx:CloseMenu()
m=menu.measure;rf,rw=m.SetFont,m.GetStringWidth
local phase,mode,batch=0
local v
local function Font(self,...) v.fontWrites=v.fontWrites+1;return rf(self,...) end
local function Width(self,...) v.widthReads=v.widthReads+1;return rw(self,...) end
local function Start()
phase=phase+1
if phase>2 then Clean();probe:Finish(r);return false end
m.SetFont,m.GetStringWidth=rf,rw
ctx:SetFont(phase==1 and ctx.fontPath or STANDARD_TEXT_FONT,phase==1 and 1.3 or 1.07)
ctx:OpenMenu(a,items,nil,options)
local path,size,flags=m:GetFont()
v={phase=phase==1 and 'scale_130' or 'standard_scale_107',font={path=path,size=size,flags=flags or ''},width=menu:GetWidth(),height=menu:GetHeight(),pool=#menu.list.rows,
baseline={sumMs=0,maxBatchMs=0,batches=0},instrumented={sumMs=0,maxBatchMs=0,batches=0},fontWrites=0,widthReads=0}
ctx:CloseMenu();r.phases[phase]=v;mode,batch='baseline',0
return true
end
assert(Start())
d=CreateFrame('Frame',nil,host)
d:SetScript('OnUpdate',assert(probe:Callback(function()
if probe:IsCancelled() then return end
local start=debugprofilestop()
for i=1,10 do
ctx:OpenMenu(a,items,nil,options)
assert(math.abs(menu:GetWidth()-v.width)<.01 and math.abs(menu:GetHeight()-v.height)<.01,'menu_geometry_changed')
ctx:CloseMenu()
end
local elapsed=debugprofilestop()-start;local timing=v[mode]
timing.sumMs=timing.sumMs+elapsed;timing.maxBatchMs=math.max(timing.maxBatchMs,elapsed);timing.batches=timing.batches+1
batch=batch+1
if batch==10 then
if mode=='baseline' then mode,batch='instrumented',0;m.SetFont,m.GetStringWidth=Font,Width
else
v.poolAfter=#menu.list.rows;assert(v.poolAfter==v.pool,'menu_pool_grew');assert(v.widthReads==1400,'label_measurements_changed')
Start()
end
end
end)))
d:Show()
