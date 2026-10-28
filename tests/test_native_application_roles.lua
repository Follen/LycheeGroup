-- Native role ownership through the production controller and configuration.
-- lua tests/test_native_application_roles.lua
local checks=0
local function Eq(a,b,label) checks=checks+1;if T then T.eq(a,b,label) else assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b)) end end
local roleKey="settings.applicationRoles"
local function OldPreferences()
 return {applicationRoles={HEALER=true},autoApply=true,uiConfig={schema=2,user={[roleKey]={HEALER=true}},imported={[roleKey]=true},presets={old={revision=1,values={[roleKey]={HEALER=true},["settings.fontScale"]=110}}},defaultPreset="old"}}
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local character,account=OldPreferences(),OldPreferences()
 local f=dofile("tests/ui_fixture.lua")(locale,character,account)
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 local app,dialog=f.U.Application,LFGListApplicationDialog
 dialog.available={TANK=true,HEALER=true,DAMAGER=true}
 for _,root in ipairs({character,account}) do
  Eq(root.applicationRoles,nil);Eq(root.uiConfig.user[roleKey],nil);Eq(root.uiConfig.imported[roleKey],nil)
  Eq(root.uiConfig.presets.old.values[roleKey],nil);Eq(root.uiConfig.presets.old.values["settings.fontScale"],110)
 end
 local c=f.A.Configuration;Eq(c.definitions[roleKey],nil)
 local legacyPackage={[roleKey]={TANK=true},["settings.autoApply"]=true}
 Eq(c:RegisterPreset("old.author",2,legacyPackage,{storage="account",default=true}),true)
 Eq(legacyPackage[roleKey].TANK,true,"caller data stays intact")
 Eq(account.uiConfig.presets["old.author"].values[roleKey],nil)
 Eq(c:Set({[roleKey]={HEALER=true}},{storage="character"}),true)
 Eq(character.uiConfig.user[roleKey],nil,"obsolete writes cannot recreate a role override")
 local nativeWrites,layouts=0,0
 local setNative,layout=SetLFGRoles,app.LayoutApplication
 SetLFGRoles=function(...) nativeWrites=nativeWrites+1;return setNative(...) end
 function app:LayoutApplication(...) layouts=layouts+1;return layout(self,...) end
 SetLFGRoles(true,false,false,true);app:OpenApplicationSettings()
 Eq(app.applicationLease.roles.DAMAGER,true);Eq(app.applicationLease.roles.HEALER,nil)
 Eq(app.applicationModal.roles.LEADER,nil,"no leader option is exposed")
 local bits={"TANK","HEALER","DAMAGER"}
 for mask=0,7 do
  local selected={mask%2==1,math.floor(mask/2)%2==1,math.floor(mask/4)%2==1}
  SetLFGRoles(true,unpack(selected))
  for index,role in ipairs(bits) do Eq(app.applicationModal.roles[role].active==true,selected[index],"native update reflects every bit") end
  Eq(app.applicationModal.submit:IsEnabled(),mask~=0,"empty selection disables confirmation")
  for index,role in ipairs(bits) do
   for flip=1,2 do
    local beforeWrites,beforeLayouts=nativeWrites,layouts
    app:SetApplicationRole(role);selected[index]=not selected[index]
    local actual={GetLFGRoles()};Eq(actual[1],true)
    for bit=1,3 do Eq(actual[bit+1],selected[bit],"click preserves full multi-selection") end
    Eq(nativeWrites-beforeWrites,1,"one native write per click")
    Eq(layouts-beforeLayouts,1,"synchronous event and click completion share one layout")
   end
  end
 end
 local beforeLayouts=layouts
 for i=1,100 do dialog:Fire("OnEvent","LFG_ROLE_UPDATE") end
 Eq(layouts,beforeLayouts,"unchanged native events do not repeat layout")
 SetLFGRoles(true,false,true,true);f.U:CloseModal()
 local beforeWrites=nativeWrites
 app:SetApplicationRole("TANK");Eq(nativeWrites,beforeWrites,"closed callbacks cannot alter roles")
 Eq(app.applicationLease,nil)
 -- No dialog cache supplies automatic requests. Read each new native selection.
 local submitted
 f.G.Apply=function(_,id,roles) submitted=roles;return true end
 f.G.records[42]={id=42,name="Native role audit",activityID=2,numMembers=1,maxNumPlayers=5,age=1}
 for mask=1,7 do
  local selected={mask%2==1,math.floor(mask/2)%2==1,math.floor(mask/4)%2==1}
  SetLFGRoles(false,unpack(selected));Eq(app:Apply(42),true)
  Eq(submitted.tank,selected[1]);Eq(submitted.healer,selected[2]);Eq(submitted.damage,selected[3])
 end
 Eq(app.applicationPrefs.roles,nil,"real roles are not cached in application preferences")
 Eq(character.applicationRoles,nil);Eq(character.uiConfig.user[roleKey],nil)
 f.U:Hide(true);SetLFGRoles=setNative
end
print("Native application roles: "..checks.." checks passed")
