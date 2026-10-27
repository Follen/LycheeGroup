local count=0
for _,mode in ipairs({'complete','cancel','callback_error'}) do
 LycheeGroup={UI={Transfer={},IsShown=function() return false end}}
 InCombatLockdown=function() return false end
 local driver,steps
 debugprofilestop=function() if mode=='callback_error' and steps==3 then error('clock failure') end;return os.clock()*1000 end
 CreateFrame=function()
  driver={};function driver:SetScript(_,fn) self.tick=fn end
  function driver:GetScript() return self.tick end
  function driver:Hide() self.shown=false end;function driver:Show() self.shown=true end
  return driver
 end
 local p={active=true}
 function p:Async(seconds) assert(seconds==25);return true end
 function p:Guard(fn) assert(fn());return true end
 function p:OnCleanup(fn) self.cleanup=fn;return true end
 function p:IsCancelled() return not self.active end
 function p:Close() self.active=false;self.cleanup() end
 function p:Finish(result) self.result=result;self:Close() end
 function p:Callback(fn) return function() if self.active then local ok,err=pcall(fn);if not ok then self.error=err;self:Close() end end end end
 assert(loadfile('.lycheedev/memory-opt-20261027/live-codec-comparison.lua'))(p)
 for i=1,30 do
  steps=i
  if mode=='cancel' and i==3 then p:Close() end
  if not p.active then break end
  driver.tick()
 end
 assert(not p.active and not driver.tick and driver.shown==false)
 if mode=='complete' then
  assert(p.result.ok and #p.result.samples==12)
  for _,sample in ipairs(p.result.samples) do assert(sample.equal) end
  assert(p.result.cleanup.driverStopped and p.result.cleanup.installedUnchanged and p.result.cleanup.privateDataReleased)
 elseif mode=='callback_error' then assert(p.error:find('clock failure',1,true))
 else assert(not p.result) end
 count=count+1
end
print('Private codec probe complete/cancel/callback-error: '..count..' scenarios passed')
