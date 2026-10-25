local addonName, private = ...
local VERSION=10000 -- V1.0.0 embedded-copy load order.
local Library=_G.LycheeUI
private.LycheeUILoad,private.LycheeUILoadVersion=nil,nil
if Library and Library.version and Library.version>=VERSION then private.LycheeUI=Library;return end
Library=Library or {}
_G.LycheeUI = Library
private.LycheeUI,private.LycheeUILoad,private.LycheeUILoadVersion=Library,Library,VERSION
local function DefaultMedia(addon)
 return "Interface\\AddOns\\"..addon..(addon=="LycheeUI" and "\\Media\\" or "\\Libs\\LycheeUI\\Media\\")
end
Library.media=DefaultMedia(addonName)
-- Existing contexts retain their original prototype during an embedded upgrade.
-- New contexts receive only the API declared by this version.
local Context = {}
Library.Context = Context
Context.__index = Context

-- A context owns its input registry, menus and animation driver. No login state.
function Library:CreateContext(options)
 options=options or {}
 if options.fontScale and (type(options.fontScale)~="number" or options.fontScale<=0 or options.fontScale~=options.fontScale or options.fontScale==math.huge) then error("fontScale must be a finite positive number",2) end
 local valid,message,theme
 local defaults=options.themeDefaults
 if defaults and (type(defaults)~="table" or next(defaults)~=nil or getmetatable(defaults)~=nil) then
  valid,message,theme=self:ValidateTheme(defaults,defaults);if not valid then error(message,2) end
 end
 local overrides=options.theme
 -- Keep one resolved table when there is only one actual input layer. Tables
 -- with metatables retain the generic two-pass lookup and validation behavior.
 if not theme or defaults and getmetatable(defaults)~=nil or overrides and (type(overrides)~="table" or next(overrides)~=nil or getmetatable(overrides)~=nil) then
  valid,message,theme=self:ValidateTheme(overrides or {},defaults);if not valid then error(message,2) end
 end
 if options.media then theme.media=options.media elseif options.addon then theme.media=DefaultMedia(options.addon) end
 local context=setmetatable({Theme=theme,options=options,parent=options.parent or UIParent,
  inputs=options.inputs or {},L=options.text or {},frame=options.frame,
  fontScale=options.fontScale or 1,fontPath=options.font or theme.font,
  fontStyles=setmetatable({},{__mode="k"}),fontLayouts=setmetatable({},{__mode="k"}),
  themeDefaults=options.themeDefaults or {}},Context)
 context.Motion=self.CreateMotion(context)
 context.C=self.CreateComponents(context)
 valid,message=self:ValidateRecipes(options.recipes or {},options.recipeDefaults,theme);if not valid then error(message,2) end
 self.AttachLayouts(context)
 self.AttachResponsive(context)
 self.AttachNative(context)
 self.AttachMenus(context)
 self.AttachElements(context)
 return context
end
function Context:GetToken(key) return self.Theme[key] end
function Context:ResolveValue(value) return type(value)=="string" and self.Theme[value] or value end
function Context:GetFontSize(value)
 local role=Library.TextStyles[value];if role then value=role.fontSize end
 local size=(self:ResolveValue(value or "bodySize")+self.Theme.fontSizeDelta)*self.fontScale
 if size<=0 or size~=size or size==math.huge then error("effective font size must be finite and positive",2) end
 return size
end
function Context:GetLineHeight(value)
 local role=Library.TextStyles[value];if role then value=role.lineHeight end
 local height=(self:ResolveValue(value)+self.Theme.lineHeightDelta)*self.fontScale
 if height<=0 or height~=height or height==math.huge then error("effective line height must be finite and positive",2) end
 return height
end
-- Weak target keys retain bindings only for the lifetime of their visual objects.
-- Only registered component text and currently owned native leases are restyled.
function Context:SetFont(path,scale)
 path=path or self.fontPath
 if scale and (type(scale)~="number" or scale<=0 or scale~=scale or scale==math.huge) then error("fontScale must be a finite positive number",2) end
 local changed=self.fontPath~=path or scale and self.fontScale~=scale
 self.fontPath=path
 if scale then self.fontScale=scale end
 if not changed then return false end
 self.C.RefreshFonts();self:RefreshFontRules();self.C.RefreshLayouts()
 for target in pairs(self.fontLayouts) do if target.LayoutFonts then target:LayoutFonts() end end
 if self._LayoutOpenMenu then self:_LayoutOpenMenu() end
 for header in pairs(self.tableHeaders or {}) do if header.layoutWidth then header:Layout(header.layoutWidth) end end
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
 if region._text~=value then region:SetText(value);region._text=value;self.C.InvalidateLayout(region,"text") end
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
 self:_SuspendLayouts()
end
function Context:Resume() self.hiding=false;self:_ResumeLayouts() end
function Context:SetWindow(frame)
 self.frame=frame
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
