-- Lifecycle validation for the built native role cost probe.
local path=assert(arg[1],"pass generated probe path")
local checks=0
local function Check(ok,label) checks=checks+1;assert(ok,label) end
for _,mode in ipairs({"complete","cancel","timeout","callback_error","combat"}) do
 local f=dofile("tests/live_probe_fixture.lua")()
 if mode=="combat" then InCombatLockdown=function() return true end end
 local product,library=LycheeGroup,LycheeUI
 local first=#f.S.nodes;local p=f:Start(path);local late
 for step=1,160 do
  if step==6 and mode=="cancel" then p:Close() end
  if step==6 and mode=="timeout" then p:Fail("probe_timeout") end
  if step==6 and mode=="callback_error" then f.callbackError=true end
  for i=first+1,#f.S.nodes do
   local node=f.S.nodes[i];local callback=node:GetScript("OnUpdate")
   if callback and node:IsVisible() then late={callback,node};callback(node,.016) end
  end
  if not p.active then break end
 end
 Check(not p.active,mode.." ends")
 if mode=="complete" then
  Check(p.result,p.error)
  Check(p.result.scenes.unchanged.layouts==0,"stable selection never layouts")
  Check(p.result.scenes.toggle.layouts==300,"one layout per toggle, including synchronous event")
  Check(p.result.cleanup.jobs==0,"no remaining animations")
 elseif mode=="cancel" then Check(not p.result and not p.error,"cancel not success")
 else Check(p.error,mode.." fails") end
 Check(product==LycheeGroup and library==LycheeUI,"installed namespaces unchanged")
 local result,err,count=p.result,p.error,#f.S.nodes
 if late then late[1](late[2],.016) end
 Check(p.result==result and p.error==err and #f.S.nodes==count,"late callback ignored")
 for i=first+1,#f.S.nodes do Check(f.S.nodes[i]:GetScript("OnUpdate")==nil,"driver stopped") end
end
print("Native roles profile lifecycle: "..checks.." checks passed")
