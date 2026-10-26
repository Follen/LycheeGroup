-- Standalone: lua tests/test_guide_bindings.lua
-- Focused primary-script controls; no game API, frame or scheduler is needed.
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Equal(a,b,message) Check(a==b,message) end
local Guide={stops=0}
_G.LycheeGroup={Guide=Guide}
function Guide:Stop(reason)
 self.stops=self.stops+1;self.reason=reason;self.Bindings:Clear()
 if self.stopError then error(self.stopError,0) end
end
local create,timers,lfg=CreateFrame,C_Timer,C_LFGList
CreateFrame=function() error("bindings load created a native frame") end
C_Timer=setmetatable({},{__index=function() error("bindings load accessed a scheduler") end})
C_LFGList=setmetatable({},{__index=function() error("bindings load read a game API") end})
dofile("addon/LycheeGroup_Guide/Bindings.lua")
CreateFrame,C_Timer,C_LFGList=create,timers,lfg
local B=Guide.Bindings
Equal(#B.records,0,"module loading is cold")

local Control={};Control.__index=Control
local function New() return setmetatable({scripts={},hooks={},clicks=false,motion=true,writes=0},Control) end
function Control:GetScript(event) return self.scripts[event] end
function Control:SetScript(event,script)
 self.scripts[event]=script;self.writes=self.writes+1
 if script and (event=="OnEnter" or event=="OnLeave") then self:EnableMouse(true) end
 if self.afterSet then self:afterSet(event,script) end
end
function Control:IsMouseEnabled() return self.clicks end
function Control:IsMouseMotionEnabled() return self.motion end
function Control:EnableMouse(value) self.clicks=value;self.motion=value end
function Control:EnableMouseMotion(value) self.motion=value end
function Control:Fire(event,...)
 local primary=self:GetScript(event);if primary then primary(self,...) end
 local hook=self.hooks[event];if hook then hook(self,...) end
end

-- Primary order, multiple arguments, nil scripts and replacement without stacking.
do
 local control=New();local order={}
 local original=function(self,a,b) Equal(self,control,"original receives its native control");Equal(a,7,"original first argument");Equal(b,"value","original second argument");order[#order+1]="original" end
 control:SetScript("OnClick",original)
 local first=B:Bind(control,"OnClick",function(self,a,b) Equal(self,control,"handler control");Equal(a,7,"handler first argument");Equal(b,"value","handler second argument");order[#order+1]="first" end)
 local second=B:Bind(control,"OnClick",function() order[#order+1]="replacement" end)
 Equal(first,second,"duplicate binding reuses its wrapper");Equal(#B.records,1,"duplicate binding has one active record")
 control:Fire("OnClick",7,"value");Equal(table.concat(order,","),"original,replacement","original completes before the current handler")
 B:Clear();Equal(control:GetScript("OnClick"),original,"clear restores the original callback")
 local writes=control.writes;B:Clear();Equal(control.writes,writes,"repeated clear does not rewrite scripts")
 local count=0;B:Bind(control,"OnHide",function() count=count+1 end);control:Fire("OnHide");Equal(count,1,"nil original script is supported")
 B:Clear();Equal(control:GetScript("OnHide"),nil,"nil original script is restored")
end

-- All current handlers are disabled before the first restoration can reenter.
do
 local a,b=New(),New();local called=0
 local original=function() end;a:SetScript("OnClick",original)
 B:Bind(a,"OnClick",function() called=called+1 end);B:Bind(b,"OnClick",function() called=called+1 end)
 function a:afterSet() self.afterSet=nil;b:Fire("OnClick");B:Clear() end
 B:Clear();Equal(called,0,"clear atomically disables handlers before restoring controls")
 Equal(a:GetScript("OnClick"),original,"reentrant clear restores the first original");Equal(b:GetScript("OnClick"),nil,"reentrant clear restores the other original")
 Equal(#B.records,0,"reentrant clear leaves no records")
end

-- Stop and phase replacement inside a native callback invalidate the old handler.
do
 local a,b=New(),New();local old,new=0,0
 local original=function() B:Clear();B:Bind(b,"OnClick",function() new=new+1 end) end
 a:SetScript("OnClick",original);B:Bind(a,"OnClick",function() old=old+1 end)
 a:Fire("OnClick");Equal(old,0,"original phase replacement suppresses the previous teaching handler")
 b:Fire("OnClick");Equal(new,1,"new phase binding survives the old wrapper returning");B:Clear()
 B:Bind(a,"OnClick",function() Guide:Stop("skipped") end)
 -- Use an independent event whose original does not replace the phase.
 B:Bind(a,"OnMouseUp",function() Guide:Stop("skipped") end);a:Fire("OnMouseUp")
 Equal(#B.records,0,"Stop during a teaching handler releases the whole binding list")
end

-- Foreign callbacks keep their captured original chain, without retaining a tour.
do
 local control=New();local originals,handlers,foreigns=0,0,0
 local original=function() originals=originals+1 end;control:SetScript("OnClick",original)
 local old=B:Bind(control,"OnClick",function() handlers=handlers+1 end)
 local foreign=function(self,...) foreigns=foreigns+1;old(self,...) end
 control:SetScript("OnClick",foreign);B:Clear()
 Equal(control:GetScript("OnClick"),foreign,"clear does not overwrite an external replacement")
 control:Fire("OnClick");Equal(originals,1,"foreign chain still calls the previous native original");Equal(handlers,0,"foreign chain no longer teaches")
 B:Bind(control,"OnClick",function() handlers=handlers+1 end)
 control:Fire("OnClick");Equal(handlers,1,"rebinding a foreign chain runs only the current handler")
 B:Clear();Equal(control:GetScript("OnClick"),foreign,"rebinding restores the external chain")
 control:Fire("OnClick");Equal(handlers,1,"cleared foreign chain remains inactive");Equal(foreigns,3,"external callback stays intact")
 -- Duplicate Bind after an external install retires the old teaching record.
 old=B:Bind(control,"OnMouseDown",function() handlers=handlers+100 end)
 local wrapping=function(self,...) old(self,...) end;control:SetScript("OnMouseDown",wrapping)
 B:Bind(control,"OnMouseDown",function() handlers=handlers+1 end)
 Equal(#B.records,1,"foreign rebinding replaces the active record")
 control:Fire("OnMouseDown");Equal(handlers,2,"foreign rebinding never stacks teaching handlers")
 B:Clear();Equal(control:GetScript("OnMouseDown"),wrapping,"foreign wrapper owns its installed callback")
end

-- Native hook chains are outside GetScript and stay untouched.
do
 local control=New();local order={}
 control:SetScript("OnClick",function() order[#order+1]="primary" end)
 control.hooks.OnClick=function() order[#order+1]="native-hook" end
 B:Bind(control,"OnClick",function() order[#order+1]="guide" end);control:Fire("OnClick")
 Equal(table.concat(order,","),"primary,guide,native-hook","existing engine hooks remain in their native chain")
 B:Clear();order={};control:Fire("OnClick")
 Equal(table.concat(order,","),"primary,native-hook","clear does not remove native hooks")
end

-- A navigation step scopes its one allowed page change to the native callback.
do
 local control=New();local order={};local transition=false
 local original=function() Check(transition,"before hook scopes the native page action");order[#order+1]="original" end
 control:SetScript("OnClick",original)
 local wrapper=B:Bind(control,"OnClick",function() transition=false;order[#order+1]="after" end,
  function() transition=true;order[#order+1]="before" end)
 control:Fire("OnClick")
 Equal(table.concat(order,","),"before,original,after","navigation scope surrounds only the original callback")
 Equal(transition,false,"ordinary input does not inherit the navigation scope")
 local foreign=function(self,...) wrapper(self,...) end;control:SetScript("OnClick",foreign)
 B:Clear();transition=true;order={};control:Fire("OnClick")
 Equal(table.concat(order,","),"original","cleared foreign chains retain neither before nor after callbacks")
 Equal(control:GetScript("OnClick"),foreign,"foreign script remains installed")
end

-- Preserve the original error object even if Stop itself fails after cleanup.
for _,source in ipairs({"before","original","handler"}) do
 local control=New();local sentinel={source=source};local ran=false
 local original=function() if source=="original" then error(sentinel,0) end;ran=true end
 control:SetScript("OnClick",original)
 B:Bind(control,"OnClick",function() if source=="handler" then error(sentinel,0) end;ran=true end,
  function() if source=="before" then error(sentinel,0) end end)
 Guide.stopError="secondary stop failure"
 local stops=Guide.stops;local ok,err=pcall(control.Fire,control,"OnClick")
 Guide.stopError=nil
 Check(not ok and err==sentinel,"the exact original error is rethrown: "..source)
 Equal(Guide.stops,stops+1,"script error interrupts the guide: "..source)
 Equal(Guide.reason,"interrupted","script error stop reason")
 Equal(#B.records,0,"script error cleans active records")
 Equal(control:GetScript("OnClick"),original,"script error restores the original native callback")
 Equal(ran,source=="handler","failed native callbacks never reach teaching handlers")
end

-- A late inactive wrapper can still call its original, but cannot stop a new tour.
do
 local oldControl,current=New(),New();local sentinel={}
 oldControl:SetScript("OnClick",function() error(sentinel,0) end)
 local stale=B:Bind(oldControl,"OnClick",function() error("stale handler ran") end);B:Clear()
 local active=B:Bind(current,"OnClick",function() end);local stops=Guide.stops
 local ok,err=pcall(stale,oldControl)
 Check(not ok and err==sentinel,"late wrapper retains its original script semantics")
 Equal(Guide.stops,stops,"late inactive errors do not interrupt a newly opened tour")
 Equal(current:GetScript("OnClick"),active,"new owner remains active after an old callback");B:Clear()
end

-- Enter/leave assignment must not turn motion-only tooltip regions into buttons.
for _,event in ipairs({"OnEnter","OnLeave"}) do for _,clicks in ipairs({false,true}) do for _,motion in ipairs({false,true}) do
 local control=New();control:EnableMouse(clicks);control:EnableMouseMotion(motion)
 B:Bind(control,event,function() end)
 Equal(control:IsMouseEnabled(),clicks,"install preserves mouse click input")
 Equal(control:IsMouseMotionEnabled(),motion,"install preserves mouse motion input")
 -- Preserve current flags at release, rather than restoring stale bind-time flags.
 control:EnableMouse(not clicks);control:EnableMouseMotion(not motion);B:Clear()
 Equal(control:IsMouseEnabled(),not clicks,"release preserves current click input")
 Equal(control:IsMouseMotionEnabled(),not motion,"release preserves current motion input")
end end end
do
 local control=New();control.IsMouseMotionEnabled=false
 B:Bind(control,"OnClick",function() end);B:Clear();Equal(control.motion,true,"unaffected script assignments do not rewrite an unreadable motion flag")
 B:Bind(control,"OnEnter",function() end);Equal(control:IsMouseEnabled(),false,"missing motion getter is not fabricated")
 B:Clear();Equal(control:IsMouseEnabled(),false,"available click flag is preserved without a motion getter")
 control=New();control.IsMouseEnabled=false;control:EnableMouseMotion(false)
 B:Bind(control,"OnEnter",function() end);Equal(control:IsMouseMotionEnabled(),false,"available motion flag is preserved without a click getter");B:Clear()
end

-- Foreign closures may retain a wrapper; cleared wrappers retain no handler data.
do
 local weak=setmetatable({},{__mode="v"});local foreign
 do
  local provider,target,control={},{},New();weak[1],weak[2],weak[3]=provider,target,control
  local function Handler(p,t) return function() return p,t end end
  local wrapper=B:Bind(control,"OnClick",Handler(provider,target))
  foreign=function(self) wrapper(self) end;control:SetScript("OnClick",foreign);B:Clear()
 end
 collectgarbage("collect");collectgarbage("collect")
 Check(weak[1]==nil and weak[2]==nil and weak[3]==nil,"inactive foreign wrapper releases provider, target and control")
 foreign(New())
end

do
 local control=New();local originals,handlers=0,0
 local original=function() originals=originals+1 end;control:SetScript("OnClick",original)
 for _=1,50 do
  local first=B:Bind(control,"OnClick",function() error("replaced handler") end)
  Equal(B:Bind(control,"OnClick",function() handlers=handlers+1 end),first,"reopen duplicate bind keeps a single wrapper")
  control:Fire("OnClick");B:Clear()
  Equal(control:GetScript("OnClick"),original,"reopen restores original identity")
  Equal(#B.records,0,"reopen retains no active records")
 end
 Equal(originals,50,"fifty tours do not stack original callbacks");Equal(handlers,50,"fifty tours do not stack teaching callbacks")
end
print(("guide binding checks passed: %d"):format(checks))
