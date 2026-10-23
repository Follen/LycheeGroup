-- Public entry integration. Adapters never need Floating's private state.
local A=_G.LycheeGroup
local F=A.Floating
local API={version=1}
A.API=A.API or {}
A.API.Floating=API
local subscribers={}
local owner,host,logoSize,label,onDetach
local lastAvailable,lastText,lastCount,lastRecruiting,lastIdle,lastAttention

local function CallExternal(callback,...)
 local ok,err=pcall(callback,...)
 if not ok then geterrorhandler()(err) end
end

function API:IsAvailable()
 return A.db~=nil and A:GetSetting("floating")==true and A:GetSetting("floatingCompatibility")==true and F.frame~=nil and not F.standaloneTest
end
function API:GetStatus()
 return {available=self:IsAvailable(),text=F.statusText or "",count=F.lastCount or 0,
  recruiting=F.recruiting==true,idle=F.lastIdle==true,attention=F.attention==true}
end
function API:Subscribe(callback)
 subscribers[callback]=true
 CallExternal(callback,self:GetStatus())
 return function() subscribers[callback]=nil end
end
function API:Attach(newOwner,newHost,newLogoSize,newLabel,release)
 assert(newOwner and newHost and newLabel and type(newLogoSize)=="number" and newLogoSize>0 and type(release)=="function","Attach requires an owner, host, positive logo size, label and release callback")
 if owner==newOwner and (host~=newHost or label~=newLabel) then self:Detach(newOwner) end
 if not self:IsAvailable() then return false,"unavailable" end
 if owner and owner~=newOwner then return false,"occupied" end
 owner,host,logoSize,label,onDetach=newOwner,newHost,newLogoSize,newLabel,release
 F:SetHost(host,logoSize,label)
 return true
end
function API:Refresh(currentOwner,newLogoSize)
 if owner~=currentOwner or not owner then return false end
 if newLogoSize then logoSize=newLogoSize end
 F:SetHost(host,logoSize,label)
 return true
end
function API:SetPopupBounds(currentOwner,frames)
 if owner~=currentOwner or not owner then return false end
 assert(frames==nil or type(frames)=="table","SetPopupBounds requires an array of positioned frames or nil")
 local current=F.popupBounds
 if current==nil and frames==nil then return true end
 if current and frames and #current==#frames then
  local same=true;for i,frame in ipairs(frames) do if current[i]~=frame then same=false;break end end
  if same then return true end
 end
 F.popupBounds=frames and {unpack(frames)} or nil
 if F.panel:IsShown() then F:LayoutPanel();F:Render() end
 return true
end
function API:Detach(currentOwner)
 if owner~=currentOwner or not owner then return false end
 local release=onDetach
 owner,host,logoSize,label,onDetach=nil,nil,nil,nil,nil
 F:SetHost(nil)
 CallExternal(release)
 return true
end
function API:Open()
 return A:Open(A:GetDefaultPage())
end
function API:ShowPopup(currentOwner)
 if owner~=currentOwner or not owner then return false end
 F:ShowPanel()
 return true
end
function API:HidePopup(currentOwner)
 if owner~=currentOwner or not owner then return false end
 F:ScheduleHide()
 return true
end

-- Internal notification bridge. No adapter is named or called by Floating.
function F:PublishStatus()
 if owner and not API:IsAvailable() then API:Detach(owner) end
 local available=API:IsAvailable()
 local text,count=self.statusText or "",self.lastCount or 0
 local recruiting,idle,attention=self.recruiting==true,self.lastIdle==true,self.attention==true
 if lastAvailable==available and lastText==text and lastCount==count and lastRecruiting==recruiting and lastIdle==idle and lastAttention==attention then return end
 lastAvailable,lastText,lastCount,lastRecruiting,lastIdle,lastAttention=available,text,count,recruiting,idle,attention
 for callback in pairs(subscribers) do CallExternal(callback,API:GetStatus()) end
end

-- Whole-product configuration; this entry does not load a UI or business package.
local configuration={version=2}
A.API.Configuration=configuration
for _,name in ipairs({"Get","GetSource","GetSchema","Set","Reset","RegisterPreset","ActivatePreset","ApplyPreset","RemovePreset","ListPresets","ExportPreset"}) do
 local method=name
 configuration[method]=function(_,...) return A.Configuration[method](A.Configuration,...) end
end
