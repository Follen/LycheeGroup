-- Borrow RurutiaSuite's TopBar entry; Floating owns its list and animation.
local A=_G.LycheeGroup
A.Integrations=A.Integrations or {}
local R={};A.Integrations.Rurutia=R
local events=CreateFrame("Frame")

function R:Release()
 local record=self.record
 if not record then return end
 self.record=nil
 if self.font then self.font:Unsubscribe(self);self.font=nil end
 if record.frame:GetScript("OnClick")==self.click then record.frame:SetScript("OnClick",self.originalClick) end
 self.click,self.originalClick=nil,nil
 A.Floating:SetHost(nil)
 record.icon:SetShown(self.iconShown);record.text:SetText(self.originalText)
 self.iconShown,self.originalText=nil,nil
end

function R:Sync(view)
 local F=A.Floating
 if not A.db or not F.frame then return end
 local suite=_G.RurutiaSuite
 view=view or suite and suite.TopBar and suite.TopBar.view
 local record=view and view.records.meetingstone
 if not A.db.floating or not A.db.floatingCompatibility or not record or not record.active or not record.frame:IsShown() then
  self:Release();return
 end
 if self.record~=record then
  self:Release();self.record=record
  self.iconShown,self.originalText=record.icon:IsShown(),record.text:GetText()
  self.font=suite.Font
  if self.font then self.font:Subscribe(self,function(_,font,role,name,path)
   if role=="interface" then font:ApplyFontString(record.text,path);F:LayoutEntry() end
  end) end
 end
 if record.frame:GetScript("OnClick")~=self.click then
  self.originalClick=record.frame:GetScript("OnClick")
  self.click=function(button,mouseButton,...)
   if mouseButton=="LeftButton" then return A:Open(F.recruiting and "create" or "find") end
   return R.originalClick(button,mouseButton,...)
  end
  record.frame:SetScript("OnClick",self.click)
 end
 if self.hookedRecord~=record then
  self.hookedRecord=record
  record.frame:HookScript("OnEnter",function()
   if R.record~=record then return end
   view:HideTooltip();F:ShowPanel()
  end)
  record.frame:HookScript("OnLeave",function() if R.record==record then F:ScheduleHide() end end)
 end
 record.icon:Hide()
 F:SetHost(record.frame,math.max(record.icon:GetWidth(),record.icon:GetHeight()),record.text)
end

function R:Initialize()
 local suite=_G.RurutiaSuite
 local viewClass=suite and suite.TopBarViewClass
 if not viewClass then
  if C_AddOns.GetAddOnMetadata("RurutiaSuite","Version") then events:RegisterEvent("ADDON_LOADED") end
  return
 end
 events:UnregisterEvent("ADDON_LOADED")
 if not self.hooked then
  self.hooked=true
  hooksecurefunc(viewClass,"RefreshQuick",function(view,key) if key=="meetingstone" then R:Sync(view) end end)
  hooksecurefunc(viewClass,"ShowComponent",function(view,key,visible) if key=="meetingstone" and not visible then R:Sync(view) end end)
  hooksecurefunc(viewClass,"HideAll",function() R:Release() end)
 end
 self:Sync()
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,name)
 if event=="PLAYER_LOGIN" then events:UnregisterEvent(event)
 elseif name~="RurutiaSuite" then return end
 R:Initialize()
end)
