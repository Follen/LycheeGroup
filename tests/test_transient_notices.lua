-- Real form input and about-button timers preserve the visible exit frame.
local Fixture=dofile("tests/ui_fixture.lua")
for _,mode in ipairs({"expired_reopen","early_reopen","finish_close"}) do
 local f=Fixture("enUS");local a,u,s=f.A,f.U,f.base
 GetAverageItemLevel=function() return 400.9,200,450.7 end
 a:SetSetting("reduceMotion",false);a:Open("create");u.Motion:Tick(1)
 local p=u.pages.create
 p:UsePreset({activityID=2,generalPlaystyle=2})
 LFGListFrame.EntryCreation.Name:UserType("Item level test")
 p.ilvl.box:UserType("999")
 T.eq(p.ilvl.box:GetText(),"400");T.ok(p.correctionNotice:IsShown())
 local y=select(5,p.desc:GetPoint())
 s.AdvanceClock(mode=="early_reopen" and 3 or 3.8)
 u.closeButton:Fire("OnClick","LeftButton");s.AdvanceClock(.25)
 T.ok(u.hiding);T.ok(u.frame:IsShown())
 T.ok(p.correctionNotice:IsShown(),"a correction timeout preserves the departing form")
 T.eq(select(5,p.desc:GetPoint()),y,"expiration does not move the visible form during exit")
 if mode=="finish_close" then
  u.Motion:Tick(1)
  T.eq(u:IsShown(),false);T.eq(p.correctionTimer,nil);T.eq(p.correctionNotice:IsShown(),false)
 else
  a:Open("create")
  T.eq(p.correctionNotice:IsShown(),mode=="early_reopen","reopen resolves the current expiration state")
  if mode=="early_reopen" then s.AdvanceClock(.8) end
  T.eq(p.correctionNotice:IsShown(),false);T.eq(p.correctionTimer,nil)
  T.eq(p.ilvl.box:GetText(),"400","notice expiry preserves the corrected form value")
  u:Hide(true)
 end
end

-- Offline application failure uses the real Apply/Find and Confirm routes.
-- Only the business submission is substituted; native role/input APIs stay intact.
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,route in ipairs({"automatic","confirmation"}) do
  local f=Fixture(locale,nil,{reduceMotion=true})
  local a,u,g,s=f.A,f.U,f.G,f.base
  g.records[42]={id=42,name="Offline member test",activityID=2,numMembers=1,maxNumPlayers=5,age=1}
  local submissions,accepted=0,false
  function g:Apply(id,roles)
   T.eq(id,42);T.eq(roles.damage,true,"submission uses actual native role selection")
   submissions=submissions+1
   if accepted then return true end
   return false,self.L.offlinePartyMember
  end
  a:Open("find")
  local application,page=u.Application,u.pages.find
  if route=="automatic" then T.eq(application:SetAutoApply(true),true) end
  local function Submit()
   if route=="automatic" then page:SetStatus("Previous inline failure");page:Apply(42)
   else
    if not application.applicationLease then page:Apply(42,true) end
    u:SetText(application.applicationModal.error,"Previous form failure")
    application.applicationModal.submit:Fire("OnClick","LeftButton")
   end
  end
  local function CheckFailure()
   local toast=application.failureToast
   T.ok(toast and toast:IsShown(),route.." exposes a toast")
   T.eq(toast:GetParent(),u.frame);T.eq(toast.text:GetText(),g.L.offlinePartyMember)
   T.eq(toast.text:GetText(),locale=="zhCN" and "队伍中有离线成员，请等其上线或调整队伍后再申请。" or "A group member is offline. Wait for them to reconnect or adjust your group before applying.")
   T.eq(page.statusMessage,"","toast failure has no duplicate result-list error")
   T.eq(page.limitNotice:IsShown(),false)
   if route=="confirmation" then
    T.ok(application.applicationLease,"failure preserves the native description lease")
    T.eq(application.applicationModal.frame:IsShown(),true,"failure leaves confirmation open for retry")
    T.eq(application.applicationModal.error:GetText(),"","toast failure has no duplicate modal error")
   else T.eq(u.activeModal,nil,"automatic failure does not open role confirmation") end
   T.ok(application.failureTimer)
   T.eq(LFGListApplicationDialog.submissions,0,"business rejection never submits through the native button")
  end
  local timers=s.PendingTimers()
  Submit();CheckFailure();T.eq(submissions,1)
  local toast,firstTimer=application.failureToast,application.failureTimer
  T.eq(s.PendingTimers(),timers+1,"one timeout owns the toast")
  s.AdvanceClock(3);Submit();CheckFailure();T.eq(submissions,2)
  T.eq(application.failureToast,toast,"repeated error reuses the existing notice")
  T.eq(firstTimer.cancelled,true,"repeated error cancels the preceding timeout")
  T.ok(application.failureTimer~=firstTimer);T.eq(s.PendingTimers(),timers+1)
  s.AdvanceClock(2.1);T.eq(toast:IsShown(),true,"old five-second deadline cannot hide a refreshed toast")
  s.AdvanceClock(2.8);T.eq(toast:IsShown(),true,"refreshed error remains for its full timeout")
  s.AdvanceClock(.2);T.eq(toast:IsShown(),false);T.eq(application.failureTimer,nil)
  Submit();CheckFailure()
  local hidingTimer=application.failureTimer
  local wasVisible=toast:IsVisible()
  u:Hide(true)
  -- ui_stubs lacks native inherited OnHide delivery. Model that event only when
  -- the parent's real hide has actually changed this child's effective visibility.
  if wasVisible and not toast:IsVisible() and toast:IsShown() then toast:Fire("OnHide") end
  T.eq(application.failureTimer,nil,"main-window hide cancels the outstanding toast timer")
  T.eq(hidingTimer.cancelled,true)
  a:Open("find")
  T.eq(toast:IsVisible(),false,"reopening the main window cannot restore an expired untimed error")
  Submit();CheckFailure();local successTimer=application.failureTimer
  accepted=true;Submit()
  T.eq(toast:IsShown(),false,"successful application clears the previous failure toast")
  T.eq(application.failureTimer,nil);T.eq(successTimer.cancelled,true)
  T.eq(application.applicationLease,nil,"successful confirmation releases the native description")
  s.AdvanceClock(6);T.eq(toast:IsShown(),false,"retired timeout cannot recreate the notice")
  u:Hide(true)
 end
end

for _,mode in ipairs({"expired_reopen","early_reopen","finish_close"}) do
 local f=Fixture("enUS");local a,u,s=f.A,f.U,f.base
 a:SetSetting("reduceMotion",false);a:Open("settings",{section="about"});u.Motion:Tick(1)
 local p=u.pages.settings
 for i=1,10 do p.aboutBrand:Fire("OnClick","LeftButton") end
 T.ok(p.dedicationToast:IsShown())
 s.AdvanceClock(mode=="early_reopen" and 4 or 4.8)
 u.closeButton:Fire("OnClick","LeftButton");s.AdvanceClock(.25)
 T.ok(u.hiding);T.ok(u.frame:IsShown())
 T.ok(p.dedicationToast:IsShown(),"an about timeout preserves the departing panel")
 if mode=="finish_close" then
  u.Motion:Tick(1)
  T.eq(u:IsShown(),false);T.eq(p.dedicationToast:IsShown(),false);T.eq(p.dedicationTimer,nil)
 else
  a:Open("settings",{section="about"})
  T.eq(p.dedicationToast:IsShown(),mode=="early_reopen")
  if mode=="early_reopen" then s.AdvanceClock(.8) end
  T.eq(p.dedicationToast:IsShown(),false);T.eq(p.dedicationTimer,nil)
  u:Hide(true)
 end
end
