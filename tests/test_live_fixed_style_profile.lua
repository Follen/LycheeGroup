-- Isolated probe lifecycle only; these substitute timings are not game evidence.
local checks=0
local function Check(value,message) assert(value,message);checks=checks+1 end
local path=arg[1] or "tests/live_fixed_style_profile.lua"
local modes={"complete","cancel","timeout","callback_error","combat"}
if not arg[1] then modes[#modes+1]="missing_library" end
for _,mode in ipairs(modes) do
 local f=dofile("tests/live_probe_fixture.lua")()
 if mode=="missing_library" then LycheeUI=nil end
 if mode=="combat" then InCombatLockdown=function() return true end end
 local installed=LycheeUI
 local initialNodes=#f.S.nodes
 local p=f:Start(path)
 local originalMethods={}
 for index=initialNodes+1,#f.S.nodes do
  local node=f.S.nodes[index];local entry={node=node};originalMethods[#originalMethods+1]=entry
  for _,name in ipairs({"SetFont","SetSpacing","SetHeight","SetJustifyV","SetTexture","SetAtlas","SetTexCoord","SetPoint","ClearAllPoints"}) do entry[name]=node[name] end
 end
 local late
 for step=1,60 do
  if step==28 and mode=="cancel" then p:Close() end
  if step==28 and mode=="timeout" then p:Fail("probe_timeout") end
  if step==28 and mode=="callback_error" then f.callbackError=true end
  for _,node in ipairs(f.S.nodes) do
   local callback=node:GetScript("OnUpdate")
   if callback and node:IsVisible() then late={callback,node};callback(node,.016) end
  end
  if not p.active then break end
 end
 Check(not p.active,mode.." bounded completion")
 if mode=="complete" then
  Check(p.result,p.error)
  Check(p.result.pool==p.result.poolAfter,"refreshes keep the initial pool")
  Check(p.result.cleanup.jobs==0 and p.result.cleanup.idsCleared and p.result.cleanup.renderCleared,"owned work and row bindings cleared")
  Check(p.result.baseline.batches==24 and p.result.instrumented.batches==24,"both phases execute the same 120 refreshes")
 elseif mode=="cancel" then Check(not p.result and not p.error,"cancellation is not a successful result")
 else Check(p.error,mode.." reports failure") end
 Check(LycheeUI==installed,mode.." preserves installed library")
 local nodeCount=#f.S.nodes;local result=p.result;local failure=p.error
 if late then late[1](late[2],.016) end
 Check(not p.active and p.result==result and p.error==failure and #f.S.nodes==nodeCount,mode.." ignores late callbacks")
 local restored=true
 for _,entry in ipairs(originalMethods) do for name,method in pairs(entry) do if name~="node" and entry.node[name]~=method then restored=false end end end
 Check(restored,mode.." restores every observed method")
 for index=initialNodes+1,#f.S.nodes do
  local node=f.S.nodes[index]
  Check(not node:GetScript("OnUpdate"),mode.." detaches owned callbacks")
 end
end
print("Fixed style profile lifecycle: "..checks.." checks passed")
