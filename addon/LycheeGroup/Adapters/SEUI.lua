-- SeUI 1.8 exposes its marker bar by name, while its module namespace is private.
-- Keep the added entry outside the protected marker hierarchy.
local A=_G.LycheeGroup
local API=A.API.Floating
A.Adapters=A.Adapters or {}
local S={};A.Adapters.SEUI=S
local events=CreateFrame("Frame")
local bounds={}

local function Skull(bar)
 local children={bar:GetChildren()}
 for index=1,math.min(#children,32) do
  local child=children[index]
  if child.GetAttribute and child:GetAttribute("marker1")==8 then return child end
 end
end

function S:Restore()
 self.attached=nil;wipe(bounds)
 if self.host then self.host:Hide();self.host:ClearAllPoints() end
end
function S:Release()
 if not API:Detach(self) then self:Restore() end
end

function S:Build()
 if self.host then return end
 local theme=A.API.Appearance:Get("floating")
 self.logoSize,self.fontSize,self.gap=theme.seuiEntryLogoSize,theme.seuiEntryFontSize,theme.seuiEntryGap
 self.textGap=-theme.floatingLogoAnchorRightX
 local host=CreateFrame("Button","LycheeGroupSEUIEntry",UIParent)
 host:Hide();host:EnableMouse(true);host:RegisterForClicks("LeftButtonUp")
 local label=host:CreateFontString(nil,"OVERLAY")
 label:SetFont(STANDARD_TEXT_FONT,self.fontSize,"OUTLINE")
 label:SetTextColor(unpack(theme.text));label:SetWordWrap(false);label:SetJustifyH("RIGHT")
 label:SetPoint("RIGHT",host,"RIGHT",0,0)
 self.host,self.label=host,label
 host:SetScript("OnClick",function(_,button) if button=="LeftButton" then A:ToggleWindow() end end)
 host:SetScript("OnEnter",function()
  S:Sync()
  if S.attached then API:ShowPopup(S) end
 end)
 host:SetScript("OnLeave",function() API:HidePopup(S) end)
end

function S:Watch(bar)
 if self.bar==bar then return end
 self:Release();self.bar,self.skull=bar,Skull(bar)
 local function Refresh() if S.bar==bar then S:Sync() end end
 bar:HookScript("OnShow",Refresh)
 bar:HookScript("OnHide",function() if S.bar==bar then S:Release() end end)
 bar:HookScript("OnSizeChanged",Refresh)
 hooksecurefunc(bar,"SetScale",Refresh)
 hooksecurefunc(bar,"SetPoint",Refresh)
end

function S:Sync(status)
 if self.syncing then return end
 self.syncing=true
 local bar=_G.SeUIRaidMarkerBar
 if not C_AddOns.IsAddOnLoaded("SeUI") or not bar then
  self:Release();self.syncing=nil;return
 end
 self:Watch(bar)
 if not API:IsAvailable() or not bar:IsVisible() then
  self:Release();self.syncing=nil;return
 end
 self.skull=self.skull or Skull(bar)
 if not self.skull then self:Release();self.syncing=nil;return end
 self:Build()
 local host,label=self.host,self.label
 status=status or API:GetStatus();label:SetText(status.text)
 local width=math.ceil(label:GetUnboundedStringWidth())
 label:SetWidth(width)
 host:SetSize(math.max(1,self.logoSize+self.textGap+width),math.max(self.logoSize,self.skull:GetHeight()))
 -- Match the Rurutia entry's UI scale; marker-only scaling must not shrink it.
 host:SetScale(1)
 host:SetFrameStrata(bar:GetFrameStrata());host:SetFrameLevel(bar:GetFrameLevel()+1)
 host:ClearAllPoints();host:SetPoint("RIGHT",self.skull,"LEFT",-self.gap,0);host:Show()
 if not self.attached then
  self.attached=API:Attach(self,host,self.logoSize,label,function() S:Restore() end)
  if not self.attached then self:Restore();self.syncing=nil;return end
 end
 bounds[1]=bar;API:SetPopupBounds(self,bounds);API:Refresh(self,self.logoSize)
 self.syncing=nil
end

function S:Initialize()
 if not C_AddOns.IsAddOnLoaded("SeUI") then
  if C_AddOns.GetAddOnMetadata("SeUI","Version") then events:RegisterEvent("ADDON_LOADED") end
  return
 end
 events:UnregisterEvent("ADDON_LOADED")
 -- SeUI builds the bar during PLAYER_LOGIN; defer to entering the world if its
 -- login callback has not run yet. No polling or persistent update script.
 if not _G.SeUIRaidMarkerBar then events:RegisterEvent("PLAYER_ENTERING_WORLD");return end
 events:UnregisterEvent("PLAYER_ENTERING_WORLD")
 self:Watch(_G.SeUIRaidMarkerBar)
 if not self.unsubscribe then self.unsubscribe=API:Subscribe(function(status) S:Sync(status) end)
 else self:Sync() end
 events:RegisterEvent("UI_SCALE_CHANGED")
 events:RegisterEvent("DISPLAY_SIZE_CHANGED")
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,name)
 if event=="PLAYER_LOGIN" then events:UnregisterEvent(event)
 elseif event=="ADDON_LOADED" and name~="SeUI" then return end
 S:Initialize()
end)
