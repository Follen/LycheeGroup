local addonName, private = ...
local REVISION=32
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
 if options.fontScale and (type(options.fontScale)~="number" or options.fontScale<=0 or options.fontScale~=options.fontScale or options.fontScale==math.huge) then error("fontScale must be a finite positive number",2) end
 local valid,message=self:ValidateTheme(options.themeDefaults or {},options.themeDefaults);if not valid then error(message,2) end
 valid,message=self:ValidateTheme(options.theme or {},options.themeDefaults);if not valid then error(message,2) end
 local theme=self.ResolveTheme(options.theme,options.themeDefaults)
 if options.font then theme.font=options.font end
 if options.media then theme.media=options.media elseif options.addon then theme.media=DefaultMedia(options.addon) end
 local context=setmetatable({Theme=theme,options=options,parent=options.parent or UIParent,
  inputs=options.inputs or {},L=options.text or {},frame=options.frame,
  logo=options.logo,logoButton=options.logoButton,fontScale=options.fontScale or 1,
  fontStyles=setmetatable({},{__mode="k"}),styleBindings=setmetatable({},{__mode="k"}),
  themeOverrides={},themeDefaults=options.themeDefaults or {}},Context)
 for key,value in pairs(options.theme or {}) do context.themeOverrides[key]=value end
 context.Motion=self.CreateMotion(context)
 context.C=self.CreateComponents(context)
 self.AttachNative(context)
 self.AttachMenus(context)
 return context
end
function Context:GetToken(key) return self.Theme[key] end
function Context:ResolveValue(value) return type(value)=="string" and self.Theme[value] or value end
function Context:GetFontSize(value)
 local size=(self:ResolveValue(value or "bodySize")+self.Theme.fontSizeDelta)*self.fontScale
 if size<=0 or size~=size or size==math.huge then error("effective font size must be finite and positive",2) end
 return size
end
function Context:GetLineHeight(value)
 local height=(self:ResolveValue(value)+self.Theme.lineHeightDelta)*self.fontScale
 if height<=0 or height~=height or height==math.huge then error("effective line height must be finite and positive",2) end
 return height
end
-- Weak target keys retain bindings only for the lifetime of their visual objects.
function Context:BindStyle(target,key,apply)
 local bindings=target._lycheeStyleBindings
 if not bindings then bindings={};target._lycheeStyleBindings=bindings;self.styleBindings[target]=true end
 bindings[key]=apply
end
function Context:RefreshStyles(changes)
 self.C.RefreshFonts()
 for target in pairs(self.styleBindings) do for key,apply in pairs(target._lycheeStyleBindings) do if key~="state" then apply(target,changes) end end end
 for target in pairs(self.styleBindings) do local apply=target._lycheeStyleBindings.state;if apply then apply(target,changes) end end
 for lease in pairs(self.nativeControls) do if lease:IsOwned() and lease.RefreshStyle then lease:RefreshStyle() end end
 if self.options.onStyleChanged then self.options.onStyleChanged(self,changes) end
end
local function SameValue(a,b)
 if a==b then return true end
 if type(a)~="table" or type(b)~="table" then return false end
 for i=1,4 do if a[i]~=b[i] then return false end end
 return true
end
function Context:SetTheme(overrides)
 local valid,message=Library:ValidateTheme(overrides,self.themeDefaults);if not valid then error(message,2) end
 local nextTheme=Library.ResolveTheme(overrides,self.themeDefaults)
 if self.options.font then nextTheme.font=self.options.font end
 if self.options.media then nextTheme.media=self.options.media elseif self.options.addon then nextTheme.media=DefaultMedia(self.options.addon) end
 local changes,changed={},false
 for key,value in pairs(nextTheme) do if not SameValue(self.Theme[key],value) then
  changed=true
  if type(value)=="table" then changes.colors=true
  elseif key=="font" or key:find("font") or key:find("Font") or key:find("line") or key:find("Line") then changes.font=true;changes.metrics=true
  elseif key:find("Duration") or key:find("Period") or key:find("presence") or key:find("waiting") or key:find("busy") or key:find("brand") then changes.motion=true
  else changes.metrics=true end
 end end
 self.themeOverrides={};for key,value in pairs(overrides) do self.themeOverrides[key]=value end
 if not changed then return false end
 if self.tableHeaders then for header in pairs(self.tableHeaders) do header:StopDrag(false) end end
 self:CloseMenu();self.Motion:StopAll(true)
 for key,value in pairs(nextTheme) do if not SameValue(self.Theme[key],value) then self.Theme[key]=value end end
 self:RefreshStyles(changes)
 self.Motion:RefreshTheme()
 return true
end
function Context:PatchTheme(patch)
 local values={};for key,value in pairs(self.themeOverrides) do values[key]=value end
 for key,value in pairs(patch) do values[key]=value end
 return self:SetTheme(values)
end
-- Only registered component text and currently owned native leases are restyled.
function Context:SetFont(path,scale)
 if scale and (type(scale)~="number" or scale<=0 or scale~=scale or scale==math.huge) then error("fontScale must be a finite positive number",2) end
 local changed=self.Theme.font~=path or scale and self.fontScale~=scale
 self.Theme.font=path
 self.options.font=path
 if scale then self.fontScale=scale end
 if not changed then return false end
 self.C.RefreshFonts()
 for lease in pairs(self.nativeControls) do
  if lease:IsOwned() and lease.RefreshStyle then lease:RefreshStyle() end
 end
 return true
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
 icon._lycheeGameBounds=nil
 icon._lycheeRole=role
 icon:SetTexture(file and self.Theme.media..file..".tga" or nil);icon:SetTexCoord(0,1,0,1)
 if not icon._lycheeRoleBound then
  icon._lycheeRoleBound=true
  self:BindStyle(icon,"roleIcon",function(target)
   if target._lycheeRole then local roleFile=roleFiles[target._lycheeRole];target:SetTexture(roleFile and self.Theme.media..roleFile..".tga" or nil) end
  end)
 end
end
function Context:SetActivityIcon(icon,activity)
 if self.options.setActivityIcon then return self.options.setActivityIcon(icon,activity) end
 if activity and activity.texture then self:SetGameTexture(icon,activity.texture)
 elseif activity and activity.atlas then self:SetGameAtlas(icon,activity.atlas)
 else icon:SetTexture(nil) end
end
