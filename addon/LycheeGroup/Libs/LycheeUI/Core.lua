local addonName, private = ...
local REVISION=31
local Library=_G.LycheeUI
private.LycheeUILoad,private.LycheeUILoadVersion=nil,nil
if Library and Library.version and Library.version>=REVISION then private.LycheeUI=Library;return end
Library=Library or {}
_G.LycheeUI = Library
private.LycheeUI,private.LycheeUILoad,private.LycheeUILoadVersion=Library,Library,REVISION
local function DefaultMedia(addon)
 return "Interface\\AddOns\\"..addon..(addon=="LycheeUI" and "\\Media\\" or "\\Libs\\LycheeUI\\Media\\")
end
Library.media=DefaultMedia(addonName)
local Context = Library.Context or {}
Library.Context = Context
Context.__index = Context

-- A context owns its input registry, menus and animation driver. No login state.
function Library:CreateContext(options)
 options=options or {}
 local theme=self.ResolveTheme(options.theme)
 if options.font then theme.font=options.font end
 if options.media then theme.media=options.media elseif options.addon then theme.media=DefaultMedia(options.addon) end
 local context=setmetatable({Theme=theme,options=options,parent=options.parent or UIParent,
  inputs=options.inputs or {},L=options.text or {},frame=options.frame,
  logo=options.logo,logoButton=options.logoButton,fontScale=options.fontScale or 1,
  fontStyles=setmetatable({},{__mode="k"})},Context)
 context.Motion=self.CreateMotion(context)
 context.C=self.CreateComponents(context)
 self.AttachNative(context)
 self.AttachMenus(context)
 return context
end
-- Only registered component text and currently owned native leases are restyled.
function Context:SetFont(path,scale)
 self.Theme.font=path
 if scale then self.fontScale=scale end
 self.C.RefreshFonts()
 for lease in pairs(self.nativeControls) do
  if lease:IsOwned() and lease.RefreshStyle then lease:RefreshStyle() end
 end
end
function Context:IsReducedMotion()
 local setting=self.options.reducedMotion
 return type(setting)=="function" and setting() or setting==true
end
function Context:IsHiding()
 local setting=self.options.isHiding
 return self.hiding==true or (type(setting)=="function" and setting() or setting==true)
end
function Context:SetText(region,value)
 value=tostring(value or "")
 if region._text~=value then region:SetText(value);region._text=value end
end
function Context:Color(region,color)
 if region._color~=color then region:SetTextColor(unpack(color));region._color=color end
end
function Context:Hex(color)
 if not color._hex then color._hex=string.format("|cff%02x%02x%02x",math.floor(color[1]*255+.5),math.floor(color[2]*255+.5),math.floor(color[3]*255+.5)) end
 return color._hex
end
function Context:ClearFocus()
 for _,box in ipairs(self.inputs) do box:ClearFocus() end
end
function Context:Hide()
 if self.tableHeaders then for header in pairs(self.tableHeaders) do header:StopDrag(false) end end
 self.hiding=true;self:CloseMenu();self:ReleaseNativeControls();self:ClearFocus();self.Motion:StopAll()
end
function Context:Resume() self.hiding=false end
function Context:SetWindow(frame,logo,logoButton)
 self.frame,self.logo,self.logoButton=frame,logo,logoButton
 self.Motion.lastAlpha=nil
 self.Motion:CapturePosition()
end
function Context:ReleaseRow(row)
 if self.options.onRowRelease then self.options.onRowRelease(row) end
 self:CloseMenuFor(row)
end
function Context:LeaveRow(row)
 if self.options.onRowLeave then self.options.onRowLeave(row) end
end
-- Applications may replace these resolvers. The library only consumes explicit art.
function Context:SetMemberIcon(icon,member)
 if self.options.setMemberIcon then return self.options.setMemberIcon(icon,member) end
 if member and member.texture then self:SetGameTexture(icon,member.texture)
 elseif member and member.atlas then self:SetGameAtlas(icon,member.atlas)
 else icon:SetTexture(nil) end
end
local roleFiles={TANK="role-tank",HEALER="role-healer",DAMAGER="role-dps"}
function Context:SetRoleIcon(icon,role)
 local file=roleFiles[role]
 icon:SetTexture(file and self.Theme.media..file..".tga" or nil);icon:SetTexCoord(0,1,0,1)
end
function Context:SetActivityIcon(icon,activity)
 if self.options.setActivityIcon then return self.options.setActivityIcon(icon,activity) end
 if activity and activity.texture then self:SetGameTexture(icon,activity.texture)
 elseif activity and activity.atlas then self:SetGameAtlas(icon,activity.atlas)
 else icon:SetTexture(nil) end
end
