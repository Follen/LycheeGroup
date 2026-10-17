-- A new applicant batch uses the native LFG notification once.
local A=_G.LycheeGroup
local Alerts={}
A.Group.Alerts=Alerts
function Alerts:Stop()
 if self.pending then self.pending:Cancel();self.pending=nil end
 if self.frame then self.frame:UnregisterEvent("SOUNDKIT_FINISHED") end
 if self.handle then StopSound(self.handle,120);self.handle=nil end
end
function Alerts:Play()
 self:Stop()
 if not self.frame then
  self.frame=CreateFrame("Frame")
  self.frame:SetScript("OnEvent",function(frame,_,handle)
   if handle==Alerts.handle then Alerts.handle=nil;frame:UnregisterEvent("SOUNDKIT_FINISHED") end
  end)
 end
 self.frame:RegisterEvent("SOUNDKIT_FINISHED")
 local played,handle=PlaySound(SOUNDKIT.UI_GROUP_FINDER_RECEIVE_APPLICATION or 47615,"Master",nil,true)
 if played then self.handle=handle else self.frame:UnregisterEvent("SOUNDKIT_FINISHED") end
end
function Alerts:NewApplicants()
 if self.pending then return end
 self.pending=C_Timer.NewTimer(.12,function()
  self.pending=nil
  if C_LFGList.HasActiveEntryInfo() then self:Play() end
 end)
end
