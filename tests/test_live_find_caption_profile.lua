-- Build the isolated library + Find module probe before running this lifecycle test.
local path=assert(arg[1],"pass the generated isolated caption probe path")
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
for _,mode in ipairs({"complete","cancel","timeout","callback_error","combat"}) do
 local f=dofile("tests/live_probe_fixture.lua")()
 if mode=="combat" then InCombatLockdown=function() return true end end
 local installed,product=LycheeUI,LycheeGroup
 local first=#f.S.nodes
 local p=f:Start(path)
 local late
 for step=1,100 do
  if step==6 and mode=="cancel" then p:Close() end
  if step==6 and mode=="timeout" then p:Fail("probe_timeout") end
  if step==6 and mode=="callback_error" then f.callbackError=true end
  for index=first+1,#f.S.nodes do
   local node=f.S.nodes[index];local callback=node:GetScript("OnUpdate")
   if callback and node:IsVisible() then late={callback,node};callback(node,.016) end
  end
  if not p.active then break end
 end
 Check(not p.active,mode.." bounded completion")
 if mode=="complete" then
  Check(p.result,p.error)
  Check(#p.result.phases==6,"two languages and all three font phases complete")
  Check(p.result.cleanup.jobs==0,"owned animation work stops")
 elseif mode=="cancel" then Check(not p.result and not p.error,"cancel does not report success")
 else Check(p.error,mode.." reports failure") end
 Check(LycheeUI==installed and LycheeGroup==product,mode.." leaves installed namespaces unchanged")
 local result,failure,count=p.result,p.error,#f.S.nodes
 if late then late[1](late[2],.016) end
 Check(p.result==result and p.error==failure and #f.S.nodes==count,mode.." ignores late callbacks")
 for index=first+1,#f.S.nodes do
  local node=f.S.nodes[index]
  Check(node:GetScript("OnUpdate")==nil,mode.." clears its update scripts")
  if node:GetObjectType()=="FontString" then Check(node.GetUnboundedStringWidth==getmetatable(node).__index.GetUnboundedStringWidth,mode.." restores observed methods") end
 end
end
print("Find caption profile lifecycle: "..checks.." checks passed")
