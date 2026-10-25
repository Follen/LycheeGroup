-- lua tests/test_live_layout_handoff.lua [library-directory] [before]
-- Exact/quantized private geometry and failure cleanup; no client timings.
local source=arg[1] or '../LycheeUI'
local expectedFailure=arg[2]=='before'
local checks=0
local function Check(v,m) checks=checks+1;assert(v,m) end
local function single(v) if v==0 then return 0 end;local sign=v<0 and -1 or 1;local m,e=math.frexp(math.abs(v));return sign*math.ldexp(math.floor(m*16777216+.5)/16777216,e) end
for _,mode in ipairs({'exact','quantized','setup_error'}) do
 local S=dofile('../LycheeUI/tests/stubs.lua');S.Install();_G.LycheeUI=nil
 local N=getmetatable(UIParent);local width,height,getPoint=N.GetWidth,N.GetHeight,N.GetPoint
 local function read(value,origin) return single((single(origin+value*.7111111283302307)-single(origin))/.7111111283302307) end
 N.GetWidth=function(self) local v=width(self);return mode=='quantized' and self.parent~=UIParent and self.parent and read(v,500) or v end
 N.GetHeight=function(self) local v=height(self);return mode=='quantized' and self.parent~=UIParent and self.parent and read(v,700) or v end
 N.GetSize=function(self) return self:GetWidth(),self:GetHeight() end
 N.GetPoint=function(self) local a,b,c,x,y=getPoint(self);if a and mode=='quantized' then return a,b,c,read(x,1000),read(y,700) end;return a,b,c,x,y end
 GetPhysicalScreenSize=function() return 2560,1440 end
 UIParent:SetScale(.7111111283302307)
 local private={}
 for _,file in ipairs({'Core','Theme','Motion','Styles','Components','Layouts','Responsive','Elements','Native','Menu'}) do assert(loadfile(source..'/'..file..'.lua'))('NativeHandoff',private) end
 if mode=='setup_error' then LycheeUI.CreateContext=function() error('injected_context_error') end end
 InCombatLockdown=function() return false end
 local clock=0;debugprofilestop=function() clock=clock+.001;return clock end
 local p,cleanups,logs={},{},{};local report,failed
 function p:OnCleanup(fn) cleanups[#cleanups+1]=fn;return true end
 function p:Guard(fn) Check(fn(),'guard');return true end
 function p:Log(message) logs[#logs+1]=message end
 function p:Fail(reason) failed=reason end
 function p:Finish(value) report=value end
 local ok,err=pcall(assert(loadfile('tests/live_layout_handoff.lua')),p)
 local cleanup;for i=#cleanups,1,-1 do cleanup=cleanups[i]() end
 Check(cleanup.hostHidden and cleanup.ownersReleased and cleanup.oldLayouts==0 and cleanup.newLayouts==0,'cleanup after '..mode)
 if mode=='setup_error' then Check(not ok and tostring(err):find('injected_'),'setup error preserved')
 elseif mode=='quantized' and expectedFailure then Check(ok and failed=='handoff_repeated_identical_native_writes','quantized baseline exposes repeated writes');Check(#logs==1 and logs[1]:find('SetWidth=24'),'failure count retained')
 else Check(ok and not failed and report.passed and report.oldReleasePreservedSuccessor,'successful handoff '..mode) end
 Check(cleanups[1]()==cleanup,'late cleanup is idempotent')
end
print('Native handoff diagnostic: '..checks..' checks passed')
