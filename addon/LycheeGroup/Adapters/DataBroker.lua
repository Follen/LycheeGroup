-- A standard broker source; the display owns its position, icon and visibility.
local A=_G.LycheeGroup
local API=A.API.Floating
A.Adapters=A.Adapters or {}
local B={};A.Adapters.DataBroker=B
local BROKER_NAME="荔枝组队"
local events=CreateFrame("Frame")
local watched=setmetatable({},{__mode="k"})
local function Name() return A:GetLocale()=="zhCN" and "荔枝组队" or "Lychee LFG" end
local function Click(_,button)
 if button=="LeftButton" then A:ToggleWindow()
 elseif button=="RightButton" then A:Open("settings") end
end
local function Enter(frame)
 if not watched[frame] then
  watched[frame]=true
  frame:HookScript("OnHide",function(hidden)
   API:HidePopup(hidden,true)
  end)
 end
 API:ShowPopup(frame,frame)
end
local function Leave(frame)
 API:HidePopup(frame)
end
function B:Sync(status)
 local text=status.text
 self.object.text=type(text)=="string" and text~="" and text or Name()
end
function B:Initialize()
 if self.object then events:UnregisterEvent("ADDON_LOADED");return true end
 local ldb=_G.LibStub and _G.LibStub:GetLibrary("LibDataBroker-1.1",true)
 if not ldb then
  if C_AddOns.GetAddOnMetadata("EllesmereUI","Version") then events:RegisterEvent("ADDON_LOADED") end
  return false
 end
 self.object=ldb:GetDataObjectByName(BROKER_NAME) or ldb:NewDataObject(BROKER_NAME,{
  type="data source",icon="Interface\\AddOns\\LycheeGroup\\Media\\lychee-logo.tga",text=Name(),OnClick=Click,OnEnter=Enter,OnLeave=Leave,
 })
 self.object.type="data source";self.object.icon="Interface\\AddOns\\LycheeGroup\\Media\\lychee-logo.tga"
 self.object.iconCoords={20/128,106/128,19/128,105/128}
 self.object.OnClick,self.object.OnEnter,self.object.OnLeave=Click,Enter,Leave
 self.object.OnTooltipShow=nil
 events:UnregisterEvent("ADDON_LOADED")
 self.unsubscribe=API:Subscribe(function(status) B:Sync(status) end,{background=true})
 return true
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,name)
 if event=="PLAYER_LOGIN" then events:UnregisterEvent(event)
 elseif event=="ADDON_LOADED" and name~="EllesmereUI" then return end
 B:Initialize()
end)
