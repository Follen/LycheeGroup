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
