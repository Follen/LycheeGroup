-- Applicant cards must release their hover surface after every pointer exit.
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G=f.A,f.U,f.G
A:SetSetting("reduceMotion",true)
G.listing={activityID=2,name="Hover regression"}
for id=1,2 do
 G.applicants[id]={id=id,status="applied",displayOrderID=id,members={{name="Applicant"..id.."-Home",class="MAGE",assignedRole="DAMAGER"}}}
end
A:Open("create")
local P=U.pages.create
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Visible(batch) return batch.bg:IsShown() and batch.bg:GetAlpha()>0 end
local function Idle(batch,index,message)
 Check(Visible(batch)==(index%2==0),message.." restores alternating-row visibility")
 for channel=1,3 do Check(batch.bg.color[channel]==U.Theme.rowAlternate[channel],message.." restores its normal color") end
end
for index=1,2 do
 local batch=P.batchPool[index]
 local row=batch.people[1]
 Idle(batch,index,"idle applicant "..index)
 row.mouseOver=true;row:Fire("OnEnter")
 Check(Visible(batch),"entering an applicant member shows its card hover: "..index)
 row.mouseOver=false;row:Fire("OnLeave");U.Motion:Tick(.25)
 Idle(batch,index,"leaving applicant "..index)
 row:Fire("OnEnter");row:Hide()
 Idle(batch,index,"hiding applicant "..index)
 row:Show();G:Notify("applicants")
 Idle(batch,index,"reusing applicant "..index)
 P.batchScroll.mouseOver=true;row.tooltipArea:Fire("OnEnter")
 Check(U.Tooltip.owner==row and Visible(batch),"the identity hover area opens details and highlights its card")
 row.mouseOver=false;row.tooltipArea:Fire("OnLeave");U.Motion:Tick(.25)
 Check(U.Tooltip.owner==nil,"leaving identity closes unpinned details")
 Idle(batch,index,"leaving applicant identity "..index)
end
U:Hide(true)
print("Applicant hover checks passed: "..checks)
