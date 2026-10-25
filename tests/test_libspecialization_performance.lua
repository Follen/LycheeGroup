-- Run directly with Lua 5.1, or through the product runner's module registry.
-- Private environments isolate the real embedded LibStub/LibSpecialization files.
local checked=0
local function eq(actual,expected,message)
 checked=checked+1
 if T then return T.eq(actual,expected,message) end
 assert(actual==expected,(message or '')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function Setup(options)
 options=options or {}
 local s={now=100,config=1,spec=70,talent='A',generated=0,sends={},timers={},frames={},home=true,instance=false,guild=true,callbacks=0,returnCode=0}
 local env=setmetatable({},{__index=_G});env._G=env
 env.LibStub=nil -- overwrite below before loading; never use another suite's singleton.
 env.strmatch=string.match;env.WOW_PROJECT_ID=options.product or 1
 env.LibStub=false
 local function Load(path) local chunk=assert(loadfile(path));setfenv(chunk,env);return chunk() end
 Load('addon/LycheeGroup_Group/Libs/LibStub/LibStub.lua')
 if options.minor then
  env.LibStub.minors.LibSpecialization=options.minor
  env.LibStub.libs.LibSpecialization={marker=true}
 end
 env.CreateFrame=function()
  local frame={events={}}
  function frame:SetScript(key,fn) self[key]=fn end
  function frame:RegisterEvent(name) self.events[name]=true end
  function frame:RegisterUnitEvent(name) self.events[name]=true end
  function frame:UnregisterEvent(name) self.events[name]=nil end
  s.frames[#s.frames+1]=frame;return frame
 end
 env.C_ChatInfo={RegisterAddonMessagePrefix=function() return 0 end,InChatMessagingLockdown=function() return false end,SendAddonMessage=function(prefix,payload,channel)
  s.sends[#s.sends+1]={prefix=prefix,payload=payload,channel=channel,time=s.now};return s.returnCode
 end}
 env.C_Traits={GenerateImportString=function(config)
  s.generated=s.generated+1;eq(config,s.config,'serialize the current config')
  if s.throw then error('native import failed') end
  return s.talent
 end}
 env.C_ClassTalents={GetActiveConfigID=function() return s.config end}
 env.C_SpecializationInfo={GetSpecialization=function() return s.spec and 1 end,GetSpecializationInfo=function() return s.spec end}
 env.UnitNameUnmodified=function() return 'Self' end
 env.GetTime=function() return s.now end
 env.IsInGroup=function(category) if category==1 then return s.home elseif category==2 then return s.instance end;return s.home or s.instance end
 env.IsInGuild=function() return s.guild end
 env.IsLoggedIn=function() return options.loggedIn==true end
 env.geterrorhandler=function() return error end
 env.securecallfunction=function(fn,...) return fn(...) end
 env.Ambiguate=function(name) return name end
 env.C_Timer={NewTimer=function(delay,fn)
  local task={at=s.now+delay,fn=fn};function task:Cancel() self.cancelled=true end
  s.timers[#s.timers+1]=task;return task
 end}
 Load('addon/LycheeGroup_Group/Libs/LibSpecialization/LibSpecialization.lua')
 s.lib=env.LibStub('LibSpecialization');s.env=env
 function s:Event(event,...)
  local frame=self.lib.frame
  if frame and frame.events[event] then frame.OnEvent(frame,event,...) end
 end
 function s:Request(channel) self:Event('CHAT_MSG_ADDON','LibSpec','R',channel or 'RAID','Peer') end
 function s:Pending() local n=0;for _,task in ipairs(self.timers) do if not task.cancelled and not task.done then n=n+1 end end;return n end
 function s:Advance(now)
  self.now=now
  local pending={};for _,task in ipairs(self.timers) do if not task.cancelled and not task.done and task.at<=now then pending[#pending+1]=task end end
  for _,task in ipairs(pending) do task.done=true;task.fn() end
 end
 return s
end

-- Forty real protocol requests stay within the original one-message/one-timer policy.
for _,distributed in ipairs({false,true}) do
 local s=Setup()
 for index=1,40 do if distributed then s.now=100+(index-1)*.05 end;s:Request() end
 eq(s.generated,1,'stable broadcast burst serializes once')
 eq(#s.sends,1);eq(s:Pending(),1)
 s:Advance(104);eq(#s.sends,2);eq(s.generated,1);eq(s:Pending(),0)
 eq(s.sends[1].payload,'70,A');eq(s.sends[2].payload,'70,A');eq(s.sends[2].channel,'RAID')
end

-- Invalidations precede consumer callbacks, including callback reentry into a response.
do
 local s=Setup();s:Request();s:Request()
 local owner={}
 s.lib.RegisterPlayerSpecChange(owner,function()
  s.callbacks=s.callbacks+1;s:Request()
 end)
 s.talent='B';s:Event('TRAIT_CONFIG_UPDATED',1)
 eq(s.generated,2,'reentrant callback sees invalidated talent')
 s:Advance(104);eq(s.sends[2].payload,'70,B')
 s.now=105;s.config=2;s.spec=65;s.talent='C';s:Event('ACTIVE_COMBAT_CONFIG_CHANGED',2)
 eq(s.generated,3);eq(s.callbacks,2)
 s:Advance(109);eq(s.sends[#s.sends].payload,'65,C')
 -- Unrelated inactive configurations neither notify nor invalidate current data.
 local before=s.generated;s:Event('TRAIT_CONFIG_UPDATED',999);s:Request();eq(s.generated,before);eq(s.callbacks,2)
 -- Key changes are also safe before their corresponding notification is delivered.
 s.config=3;s.talent='D';s:Request();eq(s.generated,before+1)
 s.spec=70;s.talent='E';s:Request();eq(s.generated,before+2)
end

-- Both home and instance broadcast consumers share one current cached native value.
do
 local s=Setup();s.instance=true;s:Request();s:Request('INSTANCE_CHAT')
 eq(s.generated,1);eq(#s.sends,2);eq(s.sends[1].channel,'RAID');eq(s.sends[2].channel,'INSTANCE_CHAT')
 s.talent='B';s:Event('TRAIT_CONFIG_UPDATED',1)
 eq(s.generated,2,'one config mutation shared by both channels');eq(s:Pending(),2)
 s:Advance(104);eq(#s.sends,4);eq(s.sends[3].payload,'70,B');eq(s.sends[4].payload,'70,B')
end

-- Guild replies use the same cache and retain their independent channel/timer.
do
 local s=Setup();for i=1,40 do s:Request('GUILD') end
 eq(s.generated,1);eq(#s.sends,1);eq(s.sends[1].channel,'GUILD');eq(s:Pending(),1)
 s:Advance(104);eq(#s.sends,2);eq(s.sends[2].payload,'70,A')
end

-- Existing retries preserve their original payload, channel and 3-second delay.
for _,failure in ipairs({3,8,9}) do
 local s=Setup();s.returnCode=failure;s:Request();eq(s:Pending(),1)
 s.talent='B';s:Event('TRAIT_CONFIG_UPDATED',1);eq(s.generated,2)
 s:Advance(103);eq(s.sends[2].payload,'70,B');eq(s:Pending(),1)
 s.returnCode=0;s:Advance(106);eq(s.sends[#s.sends].channel,'RAID');eq(s:Pending(),0)
 eq(s.generated,2,'send retry reuses the latest prepared snapshot')
end

do
 local s=Setup();s:Request();s.throw=true
 eq(pcall(s.lib.MySpecialization),false,'direct native failure still propagates')
 s.throw=false;s.talent='B';s:Request()
 eq(s.generated,3,'throwing direct read cannot revive old broadcast data')
 s:Request();eq(s.generated,3)
end

-- Nil/empty/missing configurations never turn unknown data into a reusable success.
for _,missing in ipairs({'nil','empty','config','spec'}) do
 local s=Setup();s:Request()
 if missing=='nil' then s.talent=nil elseif missing=='empty' then s.talent='' elseif missing=='config' then s.config=nil else s.spec=nil end
 -- A public native read must discard a previous successful broadcast cache.
 s.lib.MySpecialization()
 local before=s.generated;s:Request();s:Request()
 if missing=='nil' or missing=='empty' then eq(s.generated,before+2,'unknown talent retries each response') else eq(s.generated,before) end
 s.config=1;s.spec=70;s.talent='B';s:Request()
 eq(s.generated,before+((missing=='nil' or missing=='empty') and 3 or 1))
end

-- Direct getters and manual request callbacks keep fresh synchronous native data.
do
 local s=Setup();s:Request();s.talent='B'
 local id,role,position,talent=s.lib.MySpecialization(true)
 eq(talent,'B');eq(s.generated,2,'public optional arguments cannot activate reuse')
 s:Request();eq(s.generated,2,'direct fresh successful read can prime the one cache')
 local observed
 s.lib.RegisterGuild({},function(_,_,_,_,value) observed=value end)
 s.talent='C';s.lib.RequestGuildSpecialization();eq(observed,'C');eq(s.generated,3)
 s.talent='D';s.lib.RequestGuildSpecialization();eq(observed,'D');eq(s.generated,4)
 s.home=false;s.instance=false;s.lib.RegisterGroup({},function(_,_,_,_,value) observed=value end)
 s.talent='E';s:Event('GROUP_FORMED');eq(observed,'E');eq(s.generated,5)
end

-- Respect LibStub selection: unchanged minor 28 never replaces equal/newer providers.
for _,minor in ipairs({27,28,29}) do
 local s=Setup({minor=minor})
 eq(s.env.LibStub.minors.LibSpecialization,math.max(28,minor))
 if minor<28 then eq(#s.frames,1);s:Request();eq(s.generated,1)
 else eq(#s.frames,0);eq(s.lib.marker,true);eq(s.generated,0) end
end

-- The sibling Forever branch retains its original uncached automatic reads.
do
 local s=Setup({product=18});for index=1,40 do s:Request() end
 eq(s.generated,40,'no new cache outside Retail')
end
if not T then print('LibSpecialization performance: '..checked..' assertions passed') end
