-- Effective automation and raid defaults use production configuration consumers.
-- Roles are owned by native LFG and covered by test_native_application_roles.lua.
local Fixture=dofile("tests/ui_fixture.lua")
local checks=0
local function Eq(actual,expected,message)
 checks=checks+1
 if T then T.eq(actual,expected,message) else assert(actual==expected,(message or "value")..": "..tostring(actual).." ~= "..tostring(expected)) end
end
local function Ok(value,message) Eq(not not value,true,message) end
local function Click(button) button:Fire("OnClick","LeftButton") end
local auto,roles,raid="settings.autoApply","settings.applicationRoles","settings.creationRaidDifficultyID"
local function Package(f,revision,enabled,selected,difficulty)
 Ok(f.A.Configuration:RegisterPreset("suite",revision,{[auto]=enabled,[roles]=selected,[raid]=difficulty},{storage="account",default=true}))
end
local function Start(character,account)
 local f=Fixture("zhCN",character,account);f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 return f,f.A.Configuration,f.U.Application
end

do
 local character,account={},{};local f,c,app=Start(character,account)
 Eq(f.A:GetSetting("autoApply"),false);Eq(f.A:GetSetting("creationRaidDifficultyID"),false)
 Package(f,1,true,{HEALER=true},15)
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("creationRaidDifficultyID"),15)
 Eq(c.definitions[roles],nil);Eq(account.uiConfig.presets.suite.values[roles],nil,"old package role fields are discarded without losing supported settings")
 Eq(character.uiConfig.user[auto],nil);Eq(character.uiConfig.user[raid],nil)
 Package(f,2,false,{TANK=true},16)
 Eq(app:IsAutoApplyEnabled(),false)
 Ok(f.A:SetSetting("autoApply",true));Ok(f.A:SetSetting("creationRaidDifficultyID",false))
 Package(f,3,false,{HEALER=true},15)
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("creationRaidDifficultyID"),false)
 f.U:Hide(true);f,c,app=Start(character,account)
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("creationRaidDifficultyID"),false)
 Ok(c:Reset({auto,raid},{storage="character"}))
 Eq(app:IsAutoApplyEnabled(),false);Eq(f.A:GetSetting("creationRaidDifficultyID"),15)
 f.U:Hide(true);f,c,app=Start(character,account)
 Eq(app:IsAutoApplyEnabled(),false);Eq(f.A:GetSetting("creationRaidDifficultyID"),15)
 for _,invalid in ipairs({true,"15",0,-1,1.5,math.huge,0/0,{}}) do
  Eq(c:Set({[raid]=invalid},{storage="character"}),false)
  Eq(f.A:GetSetting("creationRaidDifficultyID"),15)
 end
 f.U:Hide(true)
 f,c,app=Start({}, {autoApply=true,applicationRoles={HEALER=true},creationRaidDifficultyID=15})
 Package(f,1,false,{TANK=true},16)
 Ok(app:IsAutoApplyEnabled());Eq(f.A:GetSetting("creationRaidDifficultyID"),15,"supported old account settings still migrate")
 Eq(f.A.db.applicationRoles,nil);Eq(f.A.charPrefs.applicationRoles,nil)
 f.U:Hide(true)
end

-- Raid fallback reads the effective default; only a real difficulty click pins
-- it. Preview remains isolated, and a false override restores product fallback.
do
 local f,c=Start({},{});local nativeInfo,nativeActivities=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities
 local entries={};for group=10,20,10 do for index,difficulty in ipairs({14,15,16}) do
  local id=group*10+index;entries[id]={id=id,categoryID=3,mapID=110,fullName="Raid "..group,shortName="Raid "..group,groupFinderActivityGroupID=group,difficultyID=difficulty,maxNumPlayers=30,orderIndex=id}
 end end
 C_LFGList.GetActivityInfoTable=function(id) return entries[id] or nativeInfo(id) end
 C_LFGList.GetAvailableActivities=function(category,...) if category==3 then return {101,102,103,201,202,203} end;return nativeActivities(category,...) end
 C_LFGList.GetActivityGroupInfo=function(id) return "Activity "..id end
 f.G.Catalog:Invalidate();Package(f,1,false,false,15);f.A:Open("create");local p=f.U.pages.create
 local function Choose(group)
  Click(p.pickerTrigger);p.pickerCategory="3";p.pickerTier=nil;p:RefreshPickerRows()
  for _,row in ipairs(p.pickerResults.rows) do if row:IsShown() and row.key=="3:"..group then Click(row);return end end
  error("missing raid picker row")
 end
 Choose(10);Eq(p:FormData().activityID,102);Eq(f.A.charPrefs.uiConfig.user[raid],nil)
 Package(f,2,false,false,16);Eq(p:FormData().activityID,102,"a valid creation draft is preserved")
 Choose(20);Eq(p:FormData().activityID,203)
 p:SelectDifficulty(202);Eq(f.A.charPrefs.uiConfig.user[raid],15)
 Package(f,3,false,false,14);Choose(10);Eq(p:FormData().activityID,102)
 Ok(f.A:SetSetting("creationRaidDifficultyID",false));Choose(20);Eq(p:FormData().activityID,201)
 Ok(c:Reset(raid,{storage="character"}));Choose(10);Eq(p:FormData().activityID,101)
 Ok(f.A:Preview("create"));Choose(20);p:SelectDifficulty(203)
 Eq(f.U:GetGroup().prefs.creationRaidDifficultyID,16);Eq(f.A.charPrefs.uiConfig.user[raid],nil)
 f.U:StopPreview(true);Eq(f.A:GetSetting("creationRaidDifficultyID"),14)
 f.U:Hide(true)
end

print("behavior defaults: "..checks.." checks passed")
