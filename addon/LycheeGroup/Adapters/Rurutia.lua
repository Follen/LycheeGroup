-- Bundled adapter. Only this file knows RurutiaSuite's TopBar contract.
local A=_G.LycheeGroup
local API=A.API.Floating
A.Adapters=A.Adapters or {}
local R={};A.Adapters.Rurutia=R
local events=CreateFrame("Frame")
local popupBounds={}

local function AddNearbyFrame(frame,top,bottom)
 if not frame:IsVisible() then return end
 local scale=frame:GetEffectiveScale();local frameTop=frame:GetTop()*scale
 if frameTop>=bottom and frameTop-frame:GetHeight()*scale<=top then popupBounds[#popupBounds+1]=frame end
end
function R:RefreshPopupBounds(view)
 local frame=self.record.frame;local scale=frame:GetEffectiveScale()
 local top=frame:GetTop()*scale;local height=frame:GetHeight()*scale
 -- Native controls can be moved independently. Reserve the entry's row and
 -- adjacent controls, allowing a gap of one entry height on either side.
 wipe(popupBounds)
 for _,component in pairs(view.records) do AddNearbyFrame(component.frame,top+height,top-height*2) end
 if view.microMenu and view.microMenu.frame then AddNearbyFrame(view.microMenu.frame,top+height,top-height*2) end
 local markers=_G.RurutiaSuite.RaidMarker
 if markers and markers.view and markers.view.bar then AddNearbyFrame(markers.view.bar,top+height,top-height*2) end
 API:SetPopupBounds(self,popupBounds)
end

function R:Restore()
 local record=self.record
 if not record then return end
 self.record=nil
 wipe(popupBounds)
 if self.font then self.font:Unsubscribe(self);self.font=nil end
 if record.frame:GetScript("OnClick")==self.click then record.frame:SetScript("OnClick",self.originalClick) end
 self.click,self.originalClick=nil,nil
 record.icon:SetShown(self.iconShown);record.text:SetText(self.originalText)
 self.iconShown,self.originalText=nil,nil
end
function R:Release() API:Detach(self) end

function R:Sync(view)
 local suite=_G.RurutiaSuite
 view=view or suite and suite.TopBar and suite.TopBar.view
 local record=view and view.records.meetingstone
 if not API:IsAvailable() or not record or not record.active or not record.frame:IsShown() then
  self:Release();return
 end
 if self.record~=record then
  self:Release();self.record=record
  self.iconShown,self.originalText=record.icon:IsShown(),record.text:GetText()
  local attached=API:Attach(self,record.frame,math.max(record.icon:GetWidth(),record.icon:GetHeight()),record.text,function() R:Restore() end)
  if not attached then self:Restore();return end
  self.font=suite.Font
  if self.font then self.font:Subscribe(self,function(_,font,role,name,path)
   if role=="interface" then font:ApplyFontString(record.text,path);API:Refresh(R) end
  end) end
 end
 if record.frame:GetScript("OnClick")~=self.click then
  self.originalClick=record.frame:GetScript("OnClick")
  self.click=function(button,mouseButton,...)
   if mouseButton=="LeftButton" then return API:Open() end
   return R.originalClick(button,mouseButton,...)
  end
  record.frame:SetScript("OnClick",self.click)
 end
 if self.hookedRecord~=record then
  self.hookedRecord=record
  record.frame:HookScript("OnEnter",function()
   if R.record~=record then return end
   R:RefreshPopupBounds(view)
   view:HideTooltip();API:ShowPopup(R)
  end)
  record.frame:HookScript("OnLeave",function() if R.record==record then API:HidePopup(R) end end)
 end
 record.icon:Hide()
 self:RefreshPopupBounds(view)
 API:Refresh(self,math.max(record.icon:GetWidth(),record.icon:GetHeight()))
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
 if not self.unsubscribe then
  self.unsubscribe=API:Subscribe(function(status)
   if R.available~=status.available then R.available=status.available;R:Sync() end
  end)
 end
 self:Sync()
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,name)
 if event=="PLAYER_LOGIN" then events:UnregisterEvent(event)
 elseif name~="RurutiaSuite" then return end
 R:Initialize()
end)
