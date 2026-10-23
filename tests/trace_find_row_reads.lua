-- Offline ordering diagnostic. No production edits or GC control.
local f=dofile("tests/ui_fixture.lua")("enUS")
local A,U,G=f.A,f.U,f.G
dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
EJ_GetDifficulty=function() return 14 end;EJ_SetDifficulty=function() end;EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
local phase="startup";local stack={};local depth=0
local current={calls=0,misses=0,ids={}}
local counts={TANK=2,HEALER=6,DAMAGER=22}
function G.Results:GetMemberCounts(record)
 current.calls=current.calls+1;current.ids[record.id]=true
 if not record.memberCounts then
  current.misses=current.misses+1;record.memberCounts=counts
  local list=U.pages.find.results
  print(string.format("read phase=%s id=%d scale=%.2f stride=%.1f height=%.1f capacity=%d path=%s",phase,record.id,U.context.fontScale,list.rowHeight,list:GetHeight(),list.capacity,table.concat(stack,"/",1,depth)))
 end
 return record.memberCounts
end
function G.Results:GetLeaderClass() return "MAGE" end
function G.Results:GetProgressCount() return 0 end
local activity=G.Catalog:GetActivity(1)
for id=1,105 do G.records[id]={id=id,name="Raid "..id,categoryID=3,activityID=1,activity=activity,maxNumPlayers=30,numMembers=26,leaderName="Leader-Away",leaderKey="Leader-Away",age=id} end
A:SetSetting("reduceMotion",true);A:Open("find")
local page=U.pages.find
for _,name in ipairs({"RefreshResults","RefreshApplications","LayoutListRows","LayoutResults","ReflowMetrics","LayoutFont","LayoutSize","Enter"}) do
 local original=page[name]
 page[name]=function(self,...)
  depth=depth+1;stack[depth]=name
  local a,b,c=original(self,...)
  depth=depth-1;return a,b,c
 end
end
page:SelectCategory("seasonRaid");page:CommitChoice();page:DoSearch()
for _,name in ipairs({"create","notes","settings"}) do A:Open(name) end
local function Run(label,action)
 phase=label;current={calls=0,misses=0,ids={}}
 for _,record in pairs(G.records) do record.memberCounts=nil end
 action()
 local n,shown,hit=0,0,0;for _ in pairs(current.ids) do n=n+1 end
 for _,row in ipairs(page.results.rows) do if row.key then shown=shown+1;if row._hitVisible then hit=hit+1 end end end
 print(string.format("end phase=%s calls=%d misses=%d distinct=%d bound=%d visible=%d stride=%.1f height=%.1f capacity=%d",label,current.calls,current.misses,n,shown,hit,page.results.rowHeight,page.results:GetHeight(),page.results.capacity))
end
Run("enter-100",function() A:Open("find") end)
Run("visible-font-130",function() A.API.Configuration:Set({["settings.fontScale"]=130},{storage="session"}) end)
A:Open("settings")
Run("hidden-font-100",function() A.API.Configuration:Set({["settings.fontScale"]=100},{storage="session"}) end)
Run("reenter-100",function() A:Open("find") end)
