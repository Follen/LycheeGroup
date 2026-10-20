-- Share Blizzard's applicant glow lock; its animation owns sound playback.
local A=_G.LycheeGroup
local G=A.Group
local Alerts={}
G.Alerts=Alerts
local viewers={}
-- Opening Blizzard's panel (or another LFG panel) acknowledges the same lock.
if QueueStatusButton then
 hooksecurefunc(QueueStatusButton,"SetGlowLock",function(_,lock,enabled)
  if lock=="lfglist-applicant" and not enabled then Alerts.unread=nil end
 end)
end
function Alerts:Sync()
 if not C_LFGList.HasActiveEntryInfo() or G.Applicants:GetCount()==0 or not G:CanManageApplicants()
  or next(viewers) or LFGListFrame and LFGListFrame:IsVisible() then
  self.unread=nil
 end
 if QueueStatusButton then QueueStatusButton:SetGlowLock("lfglist-applicant",self.unread==true) end
end
function Alerts:Stop()
 self.unread=nil
 self:Sync()
end
function Alerts:Update(hasNew)
 if hasNew then self.unread=true end
 self:Sync()
end
function Alerts:SetViewed(owner,visible)
 viewers[owner]=visible or nil
 if visible then self:Stop() end
end
