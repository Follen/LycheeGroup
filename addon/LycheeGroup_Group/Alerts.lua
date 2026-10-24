-- Native attention and custom speech share arrivals, not their lifetime.
local A=_G.LycheeGroup
local G=A.Group
local Alerts={}
G.Alerts=Alerts
local viewers={}
local hookedButton
local function Read(callback,...)
 local ok,value=pcall(callback,...)
 if ok then return G.Public(value) end
end
local function Merge(self,ids)
 if type(ids)~="table" then return false end
 self.seen=self.seen or {}
 for _,id in ipairs(ids) do
  id=G.Public(id)
  if type(id)=="number" or type(id)=="string" then self.seen[id]=true end
 end
 self.needsBaseline=nil
 return true
end
local function ResetState(self)
 self.seen,self.needsBaseline,self.cooldownUntil,self.unread=nil,true,nil,nil
 A.ApplicantAudio:Stop()
end
local function Observe(self)
 local active=Read(C_LFGList.HasActiveEntryInfo)
 local removing=G.Listing:IsRemovalPending()
 if active==false then ResetState(self);return false,active,removing end
 if active~=true or removing or G.Game:IsLfgPaused() then
  self.needsBaseline=true
  A.ApplicantAudio:Stop()
  if removing then self.unread=nil end
  return false,active,removing
 end
 if G.Public(G:CanManageApplicants())~=true then ResetState(self);return false,active end
 if not self.seen or self.needsBaseline then
  if not Merge(self,Read(C_LFGList.GetApplicants)) then
   self.needsBaseline=true
   A.ApplicantAudio:Stop()
   return false,active
  end
 end
 return true,active
end
function Alerts:Sync()
 A.ApplicantAudio:ApplySetting()
 local button=QueueStatusButton
 if button and button~=hookedButton then
  hookedButton=button
  hooksecurefunc(button,"SetGlowLock",function(_,lock,enabled)
   if lock=="lfglist-applicant" and not enabled then Alerts.unread=nil end
  end)
 end
 local ready,active,removing=Observe(self)
 -- Unreadable or paused state does not prove that native recruitment ended.
 if not ready and active~=false and not removing then return false end
 if G.Applicants:GetCount()==0 or next(viewers) or LFGListFrame and LFGListFrame:IsVisible() then self.unread=nil end
 local enabled=self.unread==true
 if button and ((button.glowLocks or {})["lfglist-applicant"] or false)~=(enabled and -1 or false) then
  button:SetGlowLock("lfglist-applicant",enabled)
 end
 return ready
end
-- Only explicit restore/entry/permission edges merge a silent baseline.
function Alerts:Baseline(newEntry)
 if newEntry==true then ResetState(self) end
 if not self:Sync() then return false end
 if not Merge(self,Read(C_LFGList.GetApplicants)) then self.needsBaseline=true;return false end
 return true
end
function Alerts:Stop()
 self.unread=nil
 A.ApplicantAudio:Stop()
 self:Sync()
end
function Alerts:Reset()
 ResetState(self)
 self:Sync()
end
function Alerts:Update(hasNew)
 if not self:Sync() or not hasNew then return false end
 self.unread=true
 if FlashClientIcon then pcall(FlashClientIcon) end
 local played=false
 local now=GetTime()
 if now>=(self.cooldownUntil or 0) then
  played=A.ApplicantAudio:Play(false)
  if played then self.cooldownUntil=now+10 end
 end
 self:Sync()
 return played
end
function Alerts:OnApplicant(id,status)
 if not self:Sync() then return false end
 id=G.Public(id)
 if id~=nil then
  if type(id)~="number" and type(id)~="string" or self.seen[id] then return false end
  self.seen[id]=true
  return self:Update(G.Public(status)=="applied")
 end
 local ids=Read(C_LFGList.GetApplicants)
 if type(ids)~="table" then return false end
 local hasNew=false
 for _,candidate in ipairs(ids) do
  candidate=G.Public(candidate)
  if (type(candidate)=="number" or type(candidate)=="string") and not self.seen[candidate] then
   self.seen[candidate]=true
   local info=Read(C_LFGList.GetApplicantInfo,candidate)
   if type(info)=="table" and G.Public(info.applicationStatus)=="applied" then hasNew=true end
  end
 end
 return self:Update(hasNew)
end
function Alerts:SetViewed(owner,visible)
 viewers[owner]=visible or nil
 self:Sync()
end
