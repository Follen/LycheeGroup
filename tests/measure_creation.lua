-- Creation-page allocation attribution through the real Submit / notification path.
-- Lua 5.1 fixture allocations include UI substitutes; they are not WoW AddOn bytes.
local f=dofile("tests/ui_fixture.lua")("enUS")
local A,U,G=f.A,f.U,f.G
A:SetSetting("reduceMotion",true);A:Open("create")
local page=U.pages.create
LFGListFrame.EntryCreation.Name:UserType("Allocation fixture")
local calls={}
for _,name in ipairs({"RefreshMode","RefreshApplicants","LayoutBatches","LayoutApplicantViewport","RenderBatches","RefreshRoster","LayoutSize"}) do
 local original=page[name]
 page[name]=function(self,...)
  local count=calls[name];if not count then count={calls=0,allocated=0};calls[name]=count end
  count.calls=count.calls+1;local before=collectgarbage("count")
  local a,b,c=original(self,...)
  count.allocated=count.allocated+collectgarbage("count")-before
  return a,b,c
 end
end
local function Measure(label,action)
 calls={};collectgarbage("stop")
 local before,nodes=collectgarbage("count"),#f.S.nodes
 local started=os.clock();action();local elapsed=os.clock()-started
 local allocated=collectgarbage("count")-before;collectgarbage("restart")
 print(string.format("%s allocatedKiB=%.3f cpuMs=%.3f newNodes=%d",label,allocated,elapsed*1000,#f.S.nodes-nodes))
 local names={};for name in pairs(calls) do names[#names+1]=name end;table.sort(names)
 for _,name in ipairs(names) do local item=calls[name];print(string.format("  %s calls=%d inclusiveKiB=%.3f",name,item.calls,item.allocated)) end
end
Measure("submit",function() page:Submit();assert(G.published,"submit must reach the publish boundary") end)
for id=1,4 do
 G.applicants[id]={id=id,status="applied",displayOrderID=id,members={{name="Applicant"..id.."-Home",nameKey="Applicant"..id.."-Home",class="WARRIOR",assignedRole="DAMAGER",itemLevel=270,dungeonScore=2200}}}
end
Measure("four-applicants-first",function() G:Notify("applicants") end)
Measure("four-applicants-unchanged",function() G:Notify("applicants") end)
Measure("listing-event",function() G:Notify("listing") end)
dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
RAID_CLASS_COLORS={WARRIOR={r=.8,g=.6,b=.4}}
local floating=A.Floating
local function Size(values) local count=0;for _ in pairs(values or {}) do count=count+1 end;return count end
local function FloatingObjects()
 local context=floating.context
 local records=0
 for controller in pairs(context.fixedControllers or {}) do records=records+Size(controller.records) end
 -- Only objects with fixed rules need controllers; this is not a native-object count.
 print(string.format("  rows=%d batches=%d fonts=%d fixedRuleControllers=%d ruleRecords=%d",#floating.rows,#floating.batches,Size(context.fontStyles),Size(context.fixedControllers),records))
end
Measure("floating-collapsed-four-applicants",function() floating:Bind(G);floating:UpdateSettings() end);FloatingObjects()
Measure("floating-four-first-hover",function() floating:ShowPanel() end);FloatingObjects()
