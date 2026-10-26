-- Production Create controls and Catalog; native data is supplied offline.
-- Standalone: lua tests/test_create_difficulty.lua
local Fixture=dofile("tests/ui_fixture.lua")
local checks=0
local function Equal(actual,expected,message)
 checks=checks+1
 if T then T.eq(actual,expected,message) else assert(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected)) end
end
local function Check(value,message) Equal(not not value,true,message) end
local function Click(button) button:Fire("OnClick","LeftButton") end
local function Session(locale,prefs)
 local f=Fixture(locale,prefs);local entries,ids={},{}
 local nativeInfo,nativeActivities=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities
 local function Add(id,group,difficulty)
  entries[id]={id=id,categoryID=3,mapID=110,fullName="Raid "..group,shortName="Raid "..group,groupFinderActivityGroupID=group,difficultyID=difficulty,maxNumPlayers=30,orderIndex=id,allowCrossFaction=true}
  ids[#ids+1]=id
 end
 Add(101,10,14);Add(102,10,15);Add(103,10,16)
 Add(201,30,14);Add(202,30,15);Add(203,30,16)
 Add(301,40,14) -- A raid without Heroic must fall back without losing the preference.
 for index,difficulty in ipairs({14,15,16,17,24}) do Add(400+index,50,difficulty) end
 C_LFGList.GetActivityInfoTable=function(id) return entries[id] or nativeInfo(id) end
 C_LFGList.GetAvailableActivities=function(category,...) if category==3 then return ids end;return nativeActivities(category,...) end
 C_LFGList.GetActivityGroupInfo=function(id) return "Activity "..id end
 f.G.Catalog:Invalidate();f.A:SetSetting("reduceMotion",true);f.A:Open("create")
 f.page=f.U.pages.create
 function f:Choose(category,group)
  local p=self.page
  if not p.picker or not p.picker:IsShown() then Click(p.pickerTrigger) end
  p.pickerCategory=category;p.pickerTier=nil;p:RefreshPickerRows()
  for _,row in ipairs(p.pickerResults.rows) do
   if row:IsShown() and row.key==category..":"..group then Click(row);return end
  end
  error("activity row not found: "..category..":"..group)
 end
 function f:Difficulty(difficulty)
  local p=self.page
  for _,button in ipairs(p.difficultyButtons) do
   local activity=button.value and self.G.Catalog:GetActivity(button.value)
   if button:IsShown() and activity.difficultyID==difficulty then Click(button);return end
  end
  for _,item in ipairs(p:DifficultyItems()) do
   if self.G.Catalog:GetActivity(item.value).difficultyID==difficulty then self.Pick(p.difficultyChoice,item.value);return end
  end
  error("difficulty not found: "..difficulty)
 end
 return f
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local prefs={};local f=Session(locale,prefs);local p=f.page
 f:Choose("seasonRaid",10);Equal(p:FormData().activityID,101,"without memory, raid keeps its original default")
 f:Difficulty(15);Equal(p:FormData().activityID,102,"the real Heroic button selects its native activity")
 f:Choose("seasonRaid",30)
 Equal(p:FormData().activityID,202,"choosing another seasonal raid restores Heroic rather than its first activity")
 Equal(f.U.Native.entry.selectedActivity,202,"the remembered native activity reaches the actual creation input")
 Equal(f.G.published,nil,"choosing or remembering difficulty does not publish a listing")
 Equal(prefs.creationRaidDifficultyID,15,"explicit difficulty belongs to the character's existing preferences")
 Equal(f.A.db.creationRaidDifficultyID,nil,"raid memory is not account-wide")
 f:Choose("3",10);Equal(p:FormData().activityID,102,"ordinary and seasonal raid contexts share the native difficulty")
 f:Choose("3",40);Equal(p:FormData().activityID,301,"an unavailable difficulty falls back to the raid's first valid activity")
 Equal(prefs.creationRaidDifficultyID,15,"fallback does not overwrite the explicit preference")
 f:Choose("seasonRaid",30);Equal(p:FormData().activityID,202,"returning from a limited raid restores the remembered difficulty")
 f.U:Hide(true);f.A:Open("create");Equal(p:FormData().activityID,202,"closing and reopening preserves the valid draft")
 f:Choose("seasonDungeon",20);Equal(p:FormData().activityID,2,"dungeon default remains Mythic Keystone")
 f:Difficulty(1);Equal(prefs.creationRaidDifficultyID,15,"dungeon difficulty cannot change raid memory")
 f:Choose("3",50);Check(p.difficultyChoice:IsShown(),"five variants exercise the dropdown path")
 f:Difficulty(16);Equal(prefs.creationRaidDifficultyID,16,"the real dropdown also remembers explicit selection")
 f:Choose("seasonRaid",10);Equal(p:FormData().activityID,103)
 f.U:Hide(true)
 -- A new fixture reconstructs Core, Catalog and Create from the same SavedVariables.
 f=Session(locale,prefs);p=f.page
 f:Choose("seasonRaid",30);Equal(p:FormData().activityID,203,"native difficulty survives a full Lua-session reload")
 f.G.listing={activityID=201,name="Existing raid",comment=""};f.G:Notify("listing");Click(p.editListing)
 Equal(p:FormData().activityID,201,"editing an existing listing preserves its exact activity")
 Equal(prefs.creationRaidDifficultyID,16,"editing does not silently rewrite the remembered difficulty")
 f.G.listing=nil;f.G:Notify("listing")
 p:UsePreset({activityID=202})
 Equal(p:FormData().activityID,202,"a favorite keeps its explicitly saved activity")
 Equal(prefs.creationRaidDifficultyID,16,"applying a favorite does not impersonate a difficulty click")
 f:Choose("seasonRaid",10);Equal(p:FormData().activityID,103)
 Check(f.A:Preview("create"),"ordinary preview starts")
 f:Choose("seasonRaid",30);f:Difficulty(15)
 Equal(prefs.creationRaidDifficultyID,16,"ordinary preview cannot write the real character preference")
 Equal(f.U:GetGroup().prefs.creationRaidDifficultyID,15,"preview memory stays in its provider")
 f.U:StopPreview(false)
 Equal(p:FormData().activityID,103,"leaving preview restores the real draft")
 for line in io.lines("addon/LycheeGroup_Guide/LycheeGroup_Guide.toc") do
  local file=line:match("^%s*(.-)%s*$")
  if file~="" and file:sub(1,1)~="#" then dofile("addon/LycheeGroup_Guide/"..file) end
 end
 local guide=f.A.Guide
 Check(guide:Open(),"guide welcome opens");Check(guide:Start(),"guide starts its isolated provider")
 guide.transition=true;f.A:Open("create");guide.transition=nil
 f:Choose("seasonRaid",30);f:Difficulty(14)
 Equal(prefs.creationRaidDifficultyID,16,"guide controls cannot write the real character preference")
 Equal(f.U:GetGroup().prefs.creationRaidDifficultyID,14,"guide memory stays in its own provider")
 guide:Stop("interrupted")
 Equal(p:FormData().activityID,103,"leaving the guide restores the real draft")
 f.U:Hide(true)
 local other=Session(locale,{})
 other:Choose("seasonRaid",10);Equal(other.page:FormData().activityID,101,"another character starts with the original default")
 other.U:Hide(true)
 for _,invalid in ipairs({false,"15",0,-1,999,{},0/0}) do
  local old={creationRaidDifficultyID=invalid};local s=Session(locale,old)
  s:Choose("seasonRaid",10);Equal(s.page:FormData().activityID,101,"invalid or unavailable saved difficulty keeps the original default")
  s.U:Hide(true)
 end
end

print("create difficulty: "..checks.." checks passed")
