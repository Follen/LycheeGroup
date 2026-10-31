-- Missing raid coverage filters the complete applicant batch through real controls.
-- Standalone: lua tests/test_raid_buff_filter.lua
local Fixture=dofile("tests/ui_fixture.lua")
local checks=0
local function Equal(actual,expected,message)
 checks=checks+1
 if T then T.eq(actual,expected,message) else assert(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected)) end
end
local function Check(value,message) Equal(not not value,true,message) end
local function Click(button) button:Fire("OnMouseDown","LeftButton");button:Fire("OnClick","LeftButton") end
local function Member(name,class,roles)
 return {name=name,nameKey=name.."-Away",class=class,assignedRole="DAMAGER",requestedRoles=roles or {DAMAGER=true},itemLevel=260,rating=1000}
end
local function IDs(page,expected,message)
 Equal(#page.appIDs,#expected,message.." count")
 for i,id in ipairs(expected) do Equal(page.appIDs[i],id,message.." #"..i) end
end
local function Cell(page,class)
 for _,row in ipairs(page.buffList.rows) do for _,cell in ipairs(row.cells) do if cell:IsShown() and cell.targetKey==class then return cell end end end
 error("Missing visible class: "..class)
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale,nil,{reduceMotion=true})
 local a,u,g=f.A,f.U,f.G
 local roster={Member("Current","PALADIN",{HEALER=true})}
 g.GetRoster=function() return roster end
 g.listing={activityID=1,name="Raid"}
 local function App(id,members) return {id=id,status="applied",displayOrderID=id,members=members} end
 g.applicants={
  [1]=App(1,{Member("Warrior","WARRIOR",{TANK=true,DAMAGER=true})}),
  [2]=App(2,{Member("Mage","MAGE")}),
  [3]=App(3,{Member("WarriorFriend","WARRIOR"),Member("PriestFriend","PRIEST",{HEALER=true})}),
  [4]=App(4,{Member("Paladin","PALADIN",{HEALER=true})}),
  [5]=App(5,{Member("Unknown",nil,{TANK=true})}),
  [6]=App(6,{Member("Rogue","ROGUE")}),
 }
 a:Open("create")
 local p=u.pages.create;p.buffList.clip.mouseOver=true
 IDs(p,{1,2,3,4,5,6},"no class filter")
 Click(Cell(p,"WARRIOR"));IDs(p,{1,3},"one missing class keeps whole friend batches")
 Check(Cell(p,"WARRIOR").active,"selected class feedback")
 Check(not p.roleFilters.ALL.active,"All is not active during a class filter")
 Equal(#g.applicants[3].members,2,"filtering retains the original complete batch")
 Click(Cell(p,"MAGE"));IDs(p,{1,2,3},"class choices are OR")
 Click(Cell(p,"WARRIOR"));IDs(p,{2},"click again removes one choice")
 Click(Cell(p,"MAGE"));IDs(p,{1,2,3,4,5,6},"last class deselected restores all")
 Click(Cell(p,"WARRIOR"));Click(p.roleFilters.HEALER);IDs(p,{},"class and role must match the same member")
 Click(p.roleFilters.TANK);IDs(p,{1},"multi-role applicant matches its tank registration")
 Click(p.roleFilters.ALL);IDs(p,{1,2,3,4,5,6},"All clears role and class filters")
 Check(not Cell(p,"WARRIOR").active and p.roleFilters.ALL.active,"All clears selected class feedback")

 Click(Cell(p,"WARRIOR"));Click(Cell(p,"MAGE"))
 roster[#roster+1]=Member("JoinedWarrior","WARRIOR");g:Notify("roster")
 IDs(p,{2},"a filled class is removed while other choices survive")
 roster[#roster+1]=Member("JoinedMage","MAGE");g:Notify("roster")
 IDs(p,{1,2,3,4,5,6},"last filled class restores full list")
 Click(Cell(p,"ROGUE"));roster[#roster+1]=Member("FirstRogue","ROGUE");g:Notify("roster")
 IDs(p,{6},"one rogue still leaves a coverage gap")
 Check(Cell(p,"ROGUE").active,"one-rogue label retains selection")
 roster[#roster+1]=Member("SecondRogue","ROGUE");g:Notify("roster")
 IDs(p,{1,2,3,4,5,6},"second rogue fills coverage and clears choice")

 -- A roster update can replace a cell while the mouse is held down.
 local cell=Cell(p,"HUNTER");cell:Fire("OnMouseDown","LeftButton")
 roster[#roster+1]=Member("JoinedHunter","HUNTER");g:Notify("roster")
 Check(cell.targetKey~="HUNTER","the pressed cell was rebound")
 cell:Fire("OnClick","LeftButton");IDs(p,{1,2,3,4,5,6},"rebound cell cancels the old press")
 Click(cell);Check(not p.roleFilters.ALL.active,"fresh press selects the displayed class")
 Click(p.roleFilters.ALL)
 p.buffList.clip.mouseOver=false;Click(Cell(p,"PRIEST"));IDs(p,{1,2,3,4,5,6},"clipped clicks do not filter")
 p.buffList.clip.mouseOver=true

 Click(Cell(p,"PRIEST"));u:Hide(true)
 for _,row in ipairs(p.buffList.rows) do for _,button in ipairs(row.cells) do Equal(button.targetKey,nil,"hidden cells release action identity") end end
 a:Open("create");IDs(p,{3},"same raid reopens with its session filter")
 Check(Cell(p,"PRIEST").active,"reopened selection is visible")
 g.listing.activityID=2;g:Notify("listing");IDs(p,{1,2,3,4,5,6},"non-raid context clears invisible class filters")
 Check(not p.buffArea:IsShown(),"non-raid coverage stays hidden")
 g.listing.activityID=1;g:Notify("listing")
 Click(Cell(p,"PRIEST"))
 local matches=g.Catalog.Matches
 g.Catalog.Matches=function(self,activity,category,...) if category=="seasonRaid" then return false end;return matches(self,activity,category,...) end
 g:Notify("activities");IDs(p,{3},"non-season raids retain the selected class filter")
 Check(p.buffArea:IsShown() and Cell(p,"PRIEST").active,"non-season raid coverage remains visible and interactive")
 local getActivity=g.Catalog.GetActivity
 g.Catalog.GetActivity=function(self,id) if id~=1 then return getActivity(self,id) end end
 g:Notify("activities");IDs(p,{1,2,3,4,5,6},"unavailable activity clears invisible class filters")
 g.Catalog.GetActivity=getActivity
 g.Catalog.Matches=matches;g:Notify("activities")
 Click(Cell(p,"PRIEST"));Equal(a:Preview("applicants"),true,"preview enters")
 Equal(a:Preview("off"),true,"preview exits")
 IDs(p,{3},"preview preserves the live class filter")
 local nodes=#f.S.nodes
 for _=1,20 do p:RefreshApplicants();g:Notify("roster") end
 Equal(#f.S.nodes,nodes,"stable filtering and roster updates reuse controls")
 a:SetSetting("fontScale",130)
 for _,row in ipairs(p.buffList.rows) do for _,button in ipairs(row.cells) do
  if button.targetKey then Check(button.label:GetWidth()>0 and button:GetHeight()>=button.label:GetHeight(),"large font fits class filter row") end
 end end
 u:Hide(true)
end
print("Raid buff filters: "..checks.." checks passed")
