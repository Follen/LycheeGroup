-- New applicants own one-shot audio; the native eye retains visual acknowledgement.
local A=_G.LycheeGroup
local G=A.Group
local Alerts={}
G.Alerts=Alerts
local viewers={}
local INTERVAL=3
local VOICE="Interface\\AddOns\\LycheeGroup_Group\\Media\\new-applicant-zhCN-v2.ogg"
local Now=GetTimePreciseSec or GetTime
local nativeButton,deadline,soundHandle,previewing
-- Cooldown survives preference/listing resets. Arrivals during it are dropped;
-- no queue, expiry callback or catch-up playback. Preview does not move it.
-- idle: next new applicant plays now; cooldown: timestamp only;
-- disabled: no listing/permission or sound off. Playback is independent of view.
local state="idle"

-- A zero glow lock is still visible but contributes no sound in OnGlowPulse.
-- Keep the shared animation, other locks and the global sound functions intact.
local function NativeGlowChanged(button,lock,enabled)
 if lock~="lfglist-applicant" then return end
 if enabled then button.glowLocks[lock]=0 else Alerts.unread=nil end
end
local function BindNative()
 local button=QueueStatusButton
 if not button or button==nativeButton then return end
 nativeButton=button
 hooksecurefunc(button,"SetGlowLock",NativeGlowChanged)
 if button.glowLocks["lfglist-applicant"] then button.glowLocks["lfglist-applicant"]=0 end
end
local function StopPlayback()
 if soundHandle then StopSound(soundHandle);soundHandle=nil end
 previewing=nil
end
function Alerts:Play(preview,choice)
 StopPlayback()
 choice=choice or A:GetSetting("applicantAlertSound")
 local channel=A:GetSetting("soundChannel")
 local played,handle
 if choice=="voice" then played,handle=PlaySoundFile(VOICE,channel)
 elseif choice=="native" then played,handle=PlaySound(47615,channel) end
 if played then soundHandle=handle;previewing=preview end
 return played
end
function Alerts:StopPreview()
 if previewing then StopPlayback() end
end
function Alerts:Preview(choice)
 return self:Play(true,choice)
end
function Alerts:OnSettingChanged()
 StopPlayback()
 self:Sync()
end
function Alerts:Sync()
 BindNative()
 local active=C_LFGList.HasActiveEntryInfo() and G:CanManageApplicants()
 local enabled=active and A:GetSetting("applicantAlertSound")~="off"
 local pending=G.Applicants:HasWaitingApplicants()
 if not enabled then
  state="disabled"
  if not active and not previewing then StopPlayback() end
 else
  state=deadline and Now()<deadline and "cooldown" or "idle"
 end
 if not active or not pending then self.unread=nil end
 if next(viewers) or LFGListFrame and LFGListFrame:IsVisible() then self.unread=nil end
 local target=self.unread and 0 or false
 if nativeButton and (nativeButton.glowLocks["lfglist-applicant"] or false)~=target then
  nativeButton:SetGlowLock("lfglist-applicant",self.unread==true,0)
 end
 return enabled and pending
end
function Alerts:Update(hasNew)
 if hasNew then self.unread=true end
 if not self:Sync() or not hasNew or state~="idle" then return end
 deadline=Now()+INTERVAL;state="cooldown"
 self:Play(false)
 -- Anchor the next eligible start after the actual playback call, including
 -- its synchronous work; the first stamp also guards reentrant callbacks.
 deadline=Now()+INTERVAL
end
function Alerts:Stop()
 self.unread=nil
 if not previewing then StopPlayback() end
 self:Sync()
end
function Alerts:GetState()
 -- Read the effective state without installing a cooldown-expiry timer.
 if state=="cooldown" and Now()>=deadline then return "idle" end
 return state
end
function Alerts:SetViewed(owner,visible)
 viewers[owner]=visible or nil
 if visible then self.unread=nil;self:Sync() end
end
BindNative()
