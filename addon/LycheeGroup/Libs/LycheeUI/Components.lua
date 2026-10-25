local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
function Library.CreateComponents(UI)
local T,M=UI.Theme,UI.Motion
local C={listRightInset=T.scrollWidth+T.scrollGap}
local function Hook(frame,script,callback) frame:HookScript(script,callback) end
local editLineMeasure
local function Value(value) return UI:ResolveValue(value) end
local function FontStyle(label)
 local style=UI.fontStyles[label]
 if not style then style={};UI.fontStyles[label]=style end
 return style
end
local ApplyLineHeight
function C.DefaultFont(label,size,flags,preserve)
 size=size or "bodySize"
 local role=Library.TextStyles[size]
 local effective=UI:GetFontSize(size)
 local style=FontStyle(label)
 style.size,style.flags=role and role.fontSize or size,flags or ""
 local result=label:SetFont(UI.fontPath,effective,style.flags)
 if role then
  style.lineHeight=role.lineHeight
  ApplyLineHeight(label,style.lineHeight,style.singleLine,preserve)
  style.appliedHeight=style.singleLine and label:GetHeight() or nil
 end
 return result
end
-- Fixed-style callers protect explicitly owned native derivatives with three
-- bits: spacing, text height and vertical justification. Ordinary setters use nil.
ApplyLineHeight=function(label,height,singleLine,preserve)
 height=UI:GetLineHeight(height)
 local kind=label:GetObjectType()
 if kind~="FontString" and kind~="EditBox" then error("LycheeUI.SetLineHeight expects a FontString or EditBox, got "..kind,2) end
 if not preserve or preserve%2==0 then
 label:SetSpacing(0)
 local nativeHeight
 if kind=="FontString" then
  nativeHeight=label:GetLineHeight()
 elseif kind=="EditBox" then
  if not editLineMeasure then
   editLineMeasure=UI.parent:CreateFontString(nil,"OVERLAY");editLineMeasure:Hide()
  end
  editLineMeasure:SetFont(label:GetFont());editLineMeasure:SetText("Ag");editLineMeasure:SetSpacing(0)
  nativeHeight=editLineMeasure:GetLineHeight()
 end
 label:SetSpacing(height-nativeHeight)
 end
 if singleLine then
  if not preserve or math.floor(preserve/2)%2==0 then label:SetHeight(height) end
  if not preserve or preserve<4 then label:SetJustifyV("MIDDLE") end
 end
end
function C.DefaultLineHeight(label,height,singleLine,preserve)
 UI:GetLineHeight(height)
 local style=FontStyle(label)
 style.lineHeight,style.singleLine=height,singleLine
 ApplyLineHeight(label,height,singleLine,preserve)
 style.appliedHeight=singleLine and label:GetHeight() or nil
end
function C.SetFont(label,size,flags) return C.DefaultFont(label,size,flags) end
function C.SetLineHeight(label,height,singleLine) return C.DefaultLineHeight(label,height,singleLine) end
function C.SetTextStyle(label,role,singleLine)
 local definition=Library.TextStyles[role]
 if not definition then error("unknown text style: "..tostring(role),2) end
 C.SetFont(label,role)
 if singleLine~=nil then C.SetLineHeight(label,definition.lineHeight,singleLine) end
 return label
end
function C.RefreshFonts()
 for label,style in pairs(UI.fontStyles) do
  local owner=label._lycheeElementOwner
  if not owner or owner:IsOwned() then
  if not UI.options.ownsText or UI.options.ownsText(label) then
   if style.size then label:SetFont(UI.fontPath,UI:GetFontSize(style.size),style.flags) end
   if style.lineHeight then
    -- A caller may have changed a former single-line label to automatic height.
    local fixed=style.singleLine and label:GetHeight()==style.appliedHeight
    ApplyLineHeight(label,style.lineHeight,fixed,C.FixedFontPreserve and C.FixedFontPreserve(label))
    style.appliedHeight=fixed and label:GetHeight() or nil
   end
  end
  end
 end
end
function C.Text(parent,text,size,color,width,lineHeight)
 local label=parent:CreateFontString(nil,"OVERLAY")
 C.DefaultFont(label,size);label:SetShadowOffset(0,0);label:SetJustifyH("LEFT")
 if width then label:SetWidth(Value(width)) end
 UI:Color(label,Value(color or "text"));UI:SetText(label,text)
 if lineHeight then C.DefaultLineHeight(label,lineHeight) end
 return label
end
function C.Fill(parent,color,layer)
 local texture=parent:CreateTexture(nil,layer or "BACKGROUND")
 texture:SetAllPoints();texture:SetColorTexture(unpack(Value(color)));return texture
end
-- Bind only passive surfaces; child buttons, edits and sliders keep their input.
function C.Draggable(frame,options)
 options=options or {}
 local drag={frame=frame}
 frame:SetMovable(true)
 function drag:Stop()
  if not self.handle then return end
  frame:StopMovingOrSizing();self.handle=nil
  if frame==UI.frame then M:CapturePosition();M:SetPresence(1) end
  if options.onStop then options.onStop(frame) end
 end
 function drag:AddHandle(handle)
  handle:EnableMouse(true)
  Hook(handle,"OnMouseDown",function(_,button)
   if button~="LeftButton" then return end
   if UI:IsHiding() or (options.onStart and options.onStart(frame)==false) then return end
   if frame==UI.frame then M:StopPresence();M:CapturePosition();M:SetPresence(1) end
   self.handle=handle;frame:StartMoving()
  end)
  Hook(handle,"OnMouseUp",function(_,button) if button=="LeftButton" then self:Stop() end end)
  Hook(handle,"OnHide",function() if self.handle==handle then self:Stop() end end)
 end
 drag:AddHandle(frame)
 Hook(frame,"OnHide",function() drag:Stop() end)
 return drag
end
-- Seven native regions compose a rounded fill. Radius is clamped on resize.
local panelSides={"LEFT","RIGHT"}
local panelCorners={{"TOPLEFT",0,1,0,1},{"TOPRIGHT",1,0,0,1},{"BOTTOMLEFT",0,1,1,0},{"BOTTOMRIGHT",1,0,1,0}}
local Panel={_lycheePanel=true}
local MaterializePanel
Panel.__index=function(panel,key)
 if key=="regions" then return MaterializePanel(panel) end
 return Panel[key]
end
function Panel:Place()
 local parent,regions,inset=self.parent,rawget(self,"regions"),self.inset
 if not regions then return end
 local width,height=parent:GetWidth(),parent:GetHeight()
 local r=math.max(0,math.min(self.radius,(width-inset*2)/2,(height-inset*2)/2))
 if r==self.placedRadius then return end
 self.placedRadius=r
 for _,region in ipairs(regions) do region:ClearAllPoints() end
 regions[1]:SetPoint("TOPLEFT",inset+r,-inset);regions[1]:SetPoint("BOTTOMRIGHT",-inset-r,inset)
 for i,side in ipairs(panelSides) do
  local edge=regions[i+1];edge:SetWidth(r);edge:SetPoint("TOP"..side,side=="LEFT" and inset or -inset,-inset-r);edge:SetPoint("BOTTOM"..side,side=="LEFT" and inset or -inset,inset+r)
 end
 for i,v in ipairs(panelCorners) do
  local corner=regions[i+3];corner:SetSize(r,r);corner:SetTexCoord(v[2],v[3],v[4],v[5]);corner:SetPoint(v[1],v[1]:find("LEFT") and inset or -inset,v[1]:find("TOP") and -inset or inset)
 end
end
function Panel:SetColor(value)
 self.color=value
 local r,g,b=value[1],value[2],value[3];local composed=self.alpha*(value[4] or 1)
 local regions=rawget(self,"regions");if not regions then return end
 if r~=self.paintedR or g~=self.paintedG or b~=self.paintedB then
  for _,region in ipairs(regions) do region:SetVertexColor(r,g,b,composed) end
  self.paintedR,self.paintedG,self.paintedB,self.paintedAlpha=r,g,b,composed
 else self:SetAlpha(self.alpha) end
end
function Panel:SetColorTexture(...) self:SetColor({...}) end
function Panel:SetAlpha(value)
 self.alpha=value;local composed=value*(self.color[4] or 1)
 local regions=rawget(self,"regions");if not regions then return end
 if composed~=self.paintedAlpha then
  for _,region in ipairs(regions) do region:SetAlpha(composed) end
  self.paintedAlpha=composed
 end
end
function Panel:GetAlpha() return self.alpha end
function Panel:SetShown(value)
 value=not not value;self.shown=value
 local regions=value and self.regions or rawget(self,"regions")
 if regions then for _,region in ipairs(regions) do if region:IsShown()~=value then region:SetShown(value) end end end
end
function Panel:IsShown() local regions=rawget(self,"regions");return regions and regions[1]:IsShown() or not regions and self.shown end
function Panel:Show() self:SetShown(true) end
function Panel:Hide() self:SetShown(false) end
function Panel:SetRadius(value) self.radius=Value(value);self:Place() end
function Panel:SetInset(value) self.inset=Value(value);self.placedRadius=nil;self:Place() end
MaterializePanel=function(panel)
 local regions={};rawset(panel,"regions",regions)
 for i=1,7 do
  local region=panel.parent:CreateTexture(nil,panel.layer or "BACKGROUND",nil,-7);regions[i]=region
  if i>=4 then region.corner=true;region:SetTexture(T.media.."rounded-corner.tga") else region:SetTexture(130871) end
 end
 panel:Place();panel:SetColor(panel.color)
 if not panel.shown then for _,region in ipairs(regions) do region:Hide() end end
 return regions
end
local function ResizePanels(parent)
 for _,visual in ipairs(parent._lycheeVisuals) do if visual._lycheePanel then visual:Place() end end
end
local function CreatePanel(parent,color,radius,inset,layer,hidden)
 local panel=setmetatable({parent=parent,alpha=1,radius=Value(radius or "panelRadius"),inset=Value(inset or 0),color=Value(color or "panel"),layer=layer,shown=not hidden},Panel)
 parent._lycheeVisuals=parent._lycheeVisuals or {};parent._lycheeVisuals[#parent._lycheeVisuals+1]=panel
 if not parent._lycheePanelSizeBound then parent._lycheePanelSizeBound=true;Hook(parent,"OnSizeChanged",ResizePanels) end
 if not hidden then MaterializePanel(panel) end

 return panel
end
function C.Panel(parent,color,radius,inset,layer) return CreatePanel(parent,color,radius,inset,layer,false) end
-- Nine fixed slices supply soft shadows without an update driver.
function C.Shadow(parent,radius)
 local radiusRef=radius or "windowRadius"
 local regions={}
 for i=1,9 do regions[i]=parent:CreateTexture(nil,"BACKGROUND",nil,-8) end
 local shadow={regions=regions}
 parent._lycheeVisuals=parent._lycheeVisuals or {};parent._lycheeVisuals[#parent._lycheeVisuals+1]=shadow
 local function Draw()
  local r=Value(radiusRef)
  local closest=28;for _,candidate in ipairs({12,16,24,28}) do if math.abs(candidate-r)<math.abs(closest-r) then closest=candidate end end
  local extent=T.shadowExtent;local corner=closest+extent;local cut=corner/128
  local uv={0,cut,1-cut,1};local index=0
  for y=1,3 do for x=1,3 do
   index=index+1;local texture=regions[index]
   texture:SetTexture(T.media.."shadow-"..closest..".tga");texture:SetTexCoord(uv[x],uv[x+1],uv[y],uv[y+1]);texture:ClearAllPoints()
   if x~=2 and y~=2 then
    local anchor=(y==1 and "TOP" or "BOTTOM")..(x==1 and "LEFT" or "RIGHT")
    texture:SetSize(corner,corner);texture:SetPoint(anchor,parent,anchor,x==1 and -extent or extent,y==1 and extent or -extent)
   elseif x==2 and y~=2 then
    local vertical=y==1 and "TOP" or "BOTTOM";local offset=y==1 and extent or -extent
    texture:SetHeight(corner);texture:SetPoint(vertical.."LEFT",parent,vertical.."LEFT",closest,offset);texture:SetPoint(vertical.."RIGHT",parent,vertical.."RIGHT",-closest,offset)
   elseif y==2 and x~=2 then
    local horizontal=x==1 and "LEFT" or "RIGHT";local offset=x==1 and -extent or extent
    texture:SetWidth(corner);texture:SetPoint("TOP"..horizontal,parent,"TOP"..horizontal,offset,-closest);texture:SetPoint("BOTTOM"..horizontal,parent,"BOTTOM"..horizontal,offset,closest)
   else texture:SetPoint("TOPLEFT",parent,"TOPLEFT",closest,-closest);texture:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-closest,closest) end
  end end
 end
 function shadow:SetAlpha(value) for _,texture in ipairs(regions) do texture:SetAlpha(value) end end
 function shadow:SetShown(value) for _,texture in ipairs(regions) do texture:SetShown(value) end end
 function shadow:Show() self:SetShown(true) end
 function shadow:Hide() self:SetShown(false) end
 ;Draw()
 return shadow
end
local function ButtonBase(parent,text,width,action)
 local b=CreateFrame("Button",nil,parent);b:SetSize(Value(width or "buttonWidth"),T.buttonHeight)
 b.label=C.Text(b,text,"font14");C.DefaultLineHeight(b.label,"line20",true);b.label:SetPoint("CENTER")
 local function Reset(self)
  self._inside=nil;self._pressed=nil;self:RefreshStyle(true)
 end
 b:SetScript("OnEnter",function(self)
  self._inside=true;self:RefreshStyle()
 end)
 b:SetScript("OnLeave",function(self) self._inside=nil;self._pressed=nil;self:RefreshStyle();if self.pressedKey then self.pressCancelled=true end end)
 b:SetScript("OnMouseDown",function(self)
  self.pressedKey=self.targetKey or true;self.pressCancelled=nil
  self._pressed=self:IsEnabled();self:RefreshStyle()
 end)
 b:SetScript("OnMouseUp",function(self) self._pressed=nil;self:RefreshStyle() end)
 b:SetScript("OnClick",function(self,button)
  if not self:IsEnabled() or UI:IsHiding() or self.pressCancelled or (self.pressedKey and self.pressedKey~=(self.targetKey or true)) then self.pressedKey=nil;self.pressCancelled=nil;return end
  self.pressedKey=nil;if action then action(self,button) end
 end)
 b:SetScript("OnHide",function(self) if self.pressedKey then self.pressCancelled=true end;self.expanded=nil;Reset(self);if UI.CloseMenuFor then UI:CloseMenuFor(self) end end)
 function b:SetAvailable(available)
  if self:IsEnabled()==available then return end
  self:SetEnabled(available);if not C.OwnsStyle(self,"root","alpha",available and 1 or T.disabledAlpha) then self:SetAlpha(available and 1 or T.disabledAlpha) end
  if not available then self._inside=nil;self._pressed=nil;UI:CloseMenuFor(self) end
  self:RefreshStyle(true)
 end
 return b
end
local ButtonMethods={}
 function ButtonMethods:RefreshStyle(immediate)
  local enabled=self:IsEnabled()
  local inside,pressed=enabled and self._inside,enabled and self._pressed
  local duration=not immediate and T.feedbackDuration or nil
  local colors=self.surfaceColors
  if self._variantPalette then colors[1],colors[2],colors[3]=T.secondaryContainer,T.refreshHover,T.secondaryPressed end
  if self._textVariantPalette then colors[1],colors[2],colors[3]=T.transparent,T.transparent,T.transparent end
  local darkChoice=self.isChoice and self.surfaceVariant=="dark"
  local fill=self.primary and (pressed and T.primaryPressed or inside and T.primaryHover or T.primary)
   or self.isChoice and (darkChoice and T.surfaceLow or T.selectBackground)
   or self.active and (self.variant=="text" and T.transparent or T.secondaryContainer)
   or colors and Value(pressed and colors[3] or inside and colors[2] or colors[1]) or T.secondaryContainer
  local permanent=self.primary or self.isChoice or colors~=nil
  local selected=self.active and self.selectionFill~=false
  local ownFillColor=C.OwnsStyle(self,"surface","color",fill)
  local ownFillShown=C.OwnsStyle(self,"surface","shown",permanent or selected==true)
  local ownFillAlpha=C.OwnsStyle(self,"surface","alpha",(permanent or selected) and 1 or 0)
  if permanent then
   self.fill._selMotion=nil
   if not ownFillShown then self.fill:Show() end
   if not ownFillAlpha then self.fill:SetAlpha(1) end
   if not ownFillColor then M:Color(self.fill,fill,duration) end
  else
   if not ownFillColor then self.fill:SetColor(fill) end
   if ownFillShown or ownFillAlpha then
    if not ownFillShown then self.fill:SetShown(selected) end
    if not ownFillAlpha then self.fill:SetAlpha(selected and 1 or 0) end
   elseif immediate then
    M:Stop(self.fill);self.fill._selMotion=selected==true;self.fill:SetShown(selected);self.fill:SetAlpha(selected and 1 or 0)
   else M:Selection(self.fill,selected==true,T.buttonSelectionDuration) end
  end
  local hovered=(not (self.primary or self.isChoice or self.active or colors) or self.isChoice and not self.expanded) and (pressed or inside)
  local hoverColor=self.isChoice and not darkChoice and (pressed and T.selectPressed or T.selectHover)
   or pressed and Value(self.pressedColor or "pressed") or Value(self.hoverColor)
  local ownHoverShown=C.OwnsStyle(self,"hover","shown",hovered==true)
  local ownHoverAlpha=C.OwnsStyle(self,"hover","alpha",hovered and 1 or 0)
  local ownHoverColor=C.OwnsStyle(self,"hover","color",hoverColor)
  if hovered then
   if not ownHoverColor then M:Stop(self.hover);self.hover:SetColor(hoverColor) end
   if not ownHoverShown then self.hover:Show() end
   if not ownHoverAlpha then if immediate then self.hover:SetAlpha(1) else M:Alpha(self.hover,1,T.feedbackDuration) end end
  else
   if not ownHoverAlpha then M:Stop(self.hover);self.hover:SetAlpha(0) end
   if not ownHoverShown then self.hover:Hide() end
  end
  local textColor=self.primary and T.onPrimary or self.active and Value(self.selectedTextColor or "onSecondaryContainer")
   or inside and Value(self.hoverTextColor or "text") or Value(self.textColor or "text")
  if not C.OwnsStyle(self,"label","color",textColor) then UI:Color(self.label,textColor) end
  if self.icon and self.icon.SetSelected and self._iconSelection~=false then self.icon:SetSelected(self.active,inside) end
  if self.focus then self.focusInner:SetColor(darkChoice and T.surfaceLow or T.selectBackground);self.focus:SetShown(self.expanded==true);self.focusInner:SetShown(self.expanded==true) end
 end
 function ButtonMethods:SetPrimary(value) self.primary=value==true;self:RefreshStyle(true) end
 function ButtonMethods:SetActive(value)
  value=value==true;if self.active==value then return end
  self.active=value;self:RefreshStyle(not self:IsVisible())
 end
 function ButtonMethods:SetSurfaceColors(rest,hover,pressed) self._variantPalette,self._textVariantPalette=nil,nil;self.surfaceColors=rest and {rest,hover or rest,pressed or hover or rest} or nil;self:RefreshStyle(true) end
 function ButtonMethods:SetTextColors(rest,hover,selected) self.textColor,self.hoverTextColor,self.selectedTextColor=rest,hover,selected;self:RefreshStyle(true) end
 function ButtonMethods:SetFeedbackColors(hover,pressed) self.hoverColor,self.pressedColor=hover or "rowHover",pressed;self:RefreshStyle(true) end
 function ButtonMethods:SetRadius(radius)
  radius=Value(radius);self.radius=radius;self.fill:SetRadius(radius);self.hover:SetRadius(radius)
  if self.focus then self.focus:SetRadius(radius);self.focusInner:SetRadius(math.max(0,radius-1)) end
 end
 function ButtonMethods:SetLabelStyle(size,lineHeight)
  C.SetFont(self.label,size);C.SetLineHeight(self.label,lineHeight,true)
 end
 function ButtonMethods:SetVariant(variant)
  self.variant=variant;self.primary=variant=="primary";self.surfaceColors=nil;self._variantPalette,self._textVariantPalette=nil,nil
  self.hoverColor,self.pressedColor="rowHover",nil
  self.textColor,self.hoverTextColor,self.selectedTextColor="text","text","onSecondaryContainer"
  self:SetHeight(T.buttonHeight);self:SetRadius(T.buttonRadius);self:SetLabelStyle("buttonFontSize","buttonLineHeight")
  if variant=="compact" then
   self:SetHeight(T.compactHeight);self:SetRadius(T.compactRadius);self:SetLabelStyle("compactSize","compactLineHeight");self.textColor="muted"
  elseif variant=="tonal" then self.surfaceColors={T.secondaryContainer,T.refreshHover,T.secondaryPressed};self._variantPalette=true
  elseif variant=="text" then
   self.surfaceColors={T.transparent,T.transparent,T.transparent};self._textVariantPalette=true;self.textColor,self.hoverTextColor,self.selectedTextColor="muted","brand","brand"
  end
  if self._lycheeStyleController then self._lycheeStyleController:SetVariant(variant) end
  self:RefreshStyle(true)
 end
 function ButtonMethods:SetStyle(style)
  if style.selectionFill~=nil then self.selectionFill=style.selectionFill end
  if style.variant then self:SetVariant(style.variant) end
  if style.height then self:SetHeight(Value(style.height)) end;if style.radius then self:SetRadius(style.radius) end
  if style.fontSize or style.lineHeight then
   local font=UI.fontStyles[self.label]
   self:SetLabelStyle(style.fontSize or font.size,style.lineHeight or font.lineHeight)
  end
  if style.surfaceColors then self:SetSurfaceColors(unpack(style.surfaceColors)) end
  if style.hoverColor or style.pressedColor then self:SetFeedbackColors(style.hoverColor or self.hoverColor,style.pressedColor or self.pressedColor) end
  if style.textColor or style.hoverTextColor or style.selectedTextColor then self:SetTextColors(style.textColor or self.textColor,style.hoverTextColor or self.hoverTextColor,style.selectedTextColor or self.selectedTextColor) end
  if style.selectionFill~=nil then self:RefreshStyle(true) end
 end
 function ButtonMethods:SetExpanded(value)
  value=value==true;if self.expanded==value then return end
  self.expanded=value
  if self.expanded and not self.focus then
   -- Keep the label and arrow above surface batches when focus slices toggle.
   self.choiceForeground=CreateFrame("Frame",nil,self);self.choiceForeground:SetAllPoints(self)
   self.choiceForeground:SetFrameLevel(self:GetFrameLevel()+1)
   for _,region in ipairs({self:GetRegions()}) do
    local layer=region:GetDrawLayer()
    if layer=="ARTWORK" or layer=="OVERLAY" then region:SetParent(self.choiceForeground) end
   end
   self.focus=C.Panel(self,"focusBorder",self.radius or "fieldRadius")
   self.focusInner=C.Panel(self,T.selectBackground,math.max(0,(self.radius or "fieldRadius")-1),1)
   for _,region in ipairs(self.focus.regions) do region:SetDrawLayer("BACKGROUND",-6) end
   for _,region in ipairs(self.focusInner.regions) do region:SetDrawLayer("BACKGROUND",-5) end
  end
  self:RefreshStyle(true)
 end
local function Button(parent,text,width,action,options,deferStyle)
 local b=ButtonBase(parent,text,width,action)
 C.DefaultFont(b.label,"buttonFontSize");C.DefaultLineHeight(b.label,"buttonLineHeight",true)
 b.fill=CreatePanel(b,"primary","buttonRadius",nil,nil,true)
 b.hover=CreatePanel(b,"rowHover","buttonRadius",nil,nil,true)
 b.hoverColor="rowHover"
 for name,method in pairs(ButtonMethods) do b[name]=method end
 b.hover:SetAlpha(0)
 b:SetRadius(T.buttonRadius)

 if options then b:SetStyle(options) end
 if not deferStyle then C.Style(b,{recipe=options and options.recipe or "button",variant=b.variant,legacy=true,trackNative=true,slots={root=b,label=b.label,surface=b.fill,hover=b.hover}}) end
 return b
end
function C.Button(parent,text,width,action,options) return Button(parent,text,width,action,options,false) end
-- Native buttons stay available to callers; the library owns their appearance.
function C.IconButton(parent,icon,size,action,options)
 options=options or {}
 local button=Button(parent,"",size or "buttonHeight",action,options,true)
 button._iconSelection=false
 button:SetHeight(Value(options.height or size or "buttonHeight"));button.label:Hide()
 local iconSize=Value(options.iconSize or "iconButtonSize")
 if icon then button.icon=C.Glyph(button,icon,iconSize)
 else button.icon=C.Icon(button,iconSize) end
 button.icon:SetPoint("CENTER")
 C.Style(button,{recipe=options.recipe or "iconButton",variant=button.variant,legacy=true,trackNative=true,slots={root=button,label=button.label,surface=button.fill,hover=button.hover,icon=button.icon}})
 return button
end
function C.Surface(parent,options)
 options=options or {}
 local floating=options.variant=="floating"
 local surface=CreateFrame("Frame",nil,parent);surface:SetAllPoints(parent);surface:EnableMouse(false)
 surface:SetFrameLevel(math.max(0,parent:GetFrameLevel()-1))
 surface.restColor=Value(options.color or (floating and "floatingSurface" or "panel"))
 surface.hoverColor=Value(options.hoverColor or (floating and "floatingHover" or surface.restColor))
 surface.fill=C.Panel(surface,surface.restColor,options.radius or (floating and "floatingRadius" or "panelRadius"))
 function surface:SetHovered(value)
  self.hovered=value==true;local color=self.hovered and self.hoverColor or self.restColor
  if not C.OwnsStyle(self,"surface","color",color) then self.fill:SetColor(color) end
  if self._lycheeStyleController then self._lycheeStyleController:Apply(true) end
 end
 function surface:SetColors(rest,hover) options.color,options.hoverColor=rest,hover or rest;self.restColor,self.hoverColor=Value(rest),Value(hover or rest);self:SetHovered(self.hovered) end

 C.Style(surface,{recipe="surface",variant=options.variant,legacy=true,trackNative=true,slots={root=surface,surface=surface.fill}})
 return surface
end
function C.CheckMark(parent,color)
 local mark=CreateFrame("Frame",nil,parent);mark:SetSize(T.checkMarkWidth,T.checkMarkHeight);mark.strokes={}
 for _,stroke in ipairs({{5,-3,-1,-math.pi/4},{9,1.3,.5,math.pi/4}}) do
  local line=mark:CreateTexture(nil,"ARTWORK");line:SetSize(stroke[1],1.5)
  line:SetPoint("CENTER",stroke[2],stroke[3]);line:SetRotation(stroke[4]);mark.strokes[#mark.strokes+1]=line
 end
 function mark:SetColor(value) for _,line in ipairs(self.strokes) do line:SetColorTexture(unpack(value)) end end
 mark:SetColor(Value(color or "onSecondaryContainer"))

 return mark
end
function C.Checkbox(parent,onChange,options)
 options=options or {}
 local size=Value(options.size or "checkboxSize");local boxSize=Value(options.boxSize or "checkboxBoxSize")
 local check=CreateFrame("CheckButton",nil,parent);check:SetSize(size,size)
 check.fill=C.Panel(check,"surfaceHigh",options.radius or "checkboxRadius",(size-boxSize)/2)
 check.mark=C.CheckMark(check,"onPrimary");check.mark:SetPoint("CENTER")
 function check:RefreshStyle()
  local inside=self:IsEnabled() and self.hovered
  local color=self:GetChecked() and (inside and T.primaryHover or T.primary) or (inside and T.secondaryContainer or T.surfaceHigh)
  if not C.OwnsStyle(self,"surface","color",color) then self.fill:SetColor(color) end
  if not C.OwnsStyle(self,"mark","shown",self:GetChecked()==true) then self.mark:SetShown(self:GetChecked()==true) end
 end
 function check:SetValue(value) self:SetChecked(value==true);self:RefreshStyle() end
 function check:GetValue() return self:GetChecked()==true end
 function check:SetAvailable(value) self:SetEnabled(value);self:SetAlpha(value and 1 or T.disabledAlpha);self:RefreshStyle() end
 check:SetScript("OnEnter",function(self) self.hovered=true;self:RefreshStyle() end)
 check:SetScript("OnLeave",function(self) self.hovered=nil;self:RefreshStyle() end)
 check:SetScript("OnHide",function(self) self.hovered=nil;self:RefreshStyle() end)
 check:SetScript("OnClick",function(self) if self:IsEnabled() and not UI:IsHiding() then self:RefreshStyle();if onChange then onChange(self:GetValue(),self) end end end)
 check:SetValue(false)

 C.Style(check,{recipe="checkbox",legacy=true,trackNative=true,slots={root=check,surface=check.fill,mark=check.mark}})
 return check
end
-- Visual field only: native/registered EditBoxes can be leased into this shell.
function C.Notice(parent,width,onClose)
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(Value(width),T.noticeHeight);frame.fill=C.Panel(frame,"notice","noticeRadius")

 frame.text=C.Text(frame,"","font14","noticeText",Value(width)-T.noticeTextReserve,"line20");frame.text:SetPoint("LEFT",T.noticeInset,0);frame.text:SetJustifyH("LEFT");frame.text:SetWordWrap(true)
 frame.close=C.IconButton(frame,"close",T.noticeCloseSize,function() if onClose then onClose(frame) else frame:Hide() end end,{iconSize=12})
 frame.close:SetPoint("RIGHT",-T.noticeCloseInset,0)
 function frame:SetMessage(message,actionWidth)
  self.actionWidth=actionWidth or 0;message=message or "";self.text:SetWidth(self:GetWidth()-T.noticeTextReserve-(actionWidth or 0));UI:SetText(self.text,message)
  self:SetHeight(math.max(T.noticeHeight,math.ceil(self.text:GetStringHeight())+T.noticeVerticalPadding));self:SetShown(message~="")
 end

 frame:Hide();return frame
end
local function Field(parent,width,height,search,variant,deferStyle)
 local shell=CreateFrame("Frame",nil,parent);shell:SetSize(Value(width),Value(height or "fieldHeight"))
 local radiusRef=search and "searchRadius" or "fieldRadius"
 local radius=Value(radiusRef)
 local baseColor=variant=="modal" and T.surfaceLow or T.field
 local hoverColor=variant=="modal" and T.surfaceContainer or T.surfaceHighest
 local focusColor=variant=="modal" and T.field or T.fieldFocus
 shell.focus=CreatePanel(shell,"focusBorder",radius,nil,nil,true)
 shell.fill=C.Panel(shell,baseColor,radius)
 function shell:SetFocused(focused,hovered)
  self.focused=focused==true;self.hovered=hovered==true
  if not C.OwnsStyle(self,"outline","shown",self.focused) then self.focus:SetShown(self.focused) end
  local fillColor=self.focused and focusColor or self.hovered and hoverColor or baseColor
  if not C.OwnsStyle(self,"surface","color",fillColor) then self.fill:SetColor(fillColor) end
  -- 1px inner ring, without a constant bright border or outer glow.
  local ownFillShown=C.OwnsStyle(self,"surface","shown",not self.focused)
  if not ownFillShown then self.fill:Hide() end
  if self.inner then self.inner:Hide() end
  if self.focused then
   if not C.OwnsStyle(self,"outline","color",T.focusBorder) then self.focus:SetColor(T.focusBorder) end
   if not self.inner then
    self.inner=C.Panel(self,focusColor,math.max(0,radius-T.fieldRing),T.fieldRing)
    -- Texture batching does not preserve creation order within a shared sublayer.
    for _,region in ipairs(self.inner.regions) do region:SetDrawLayer("BACKGROUND",-6) end
   end
   self.inner:Show()
  elseif not ownFillShown then self.fill:Show() end
  if self._lycheeStyleController then self._lycheeStyleController:Apply(true) end
 end
 function shell:SetBackdropColor(...) self.fill:SetColorTexture(...) end
 function shell:SetBackdropBorderColor(r,g,b,a) self.focus:SetColorTexture(r,g,b,a);self.focus:SetShown((a or 1)>0) end
 shell:SetScript("OnHide",function(self) self:SetFocused(false) end)

 if not deferStyle then C.Style(shell,{recipe="field",legacy=true,trackNative=true,slots={root=shell,surface=shell.fill,outline=shell.focus}}) end
 return shell
end
function C.Field(parent,width,height,search,variant) return Field(parent,width,height,search,variant,false) end
function C.Edit(parent,width,height,multiline,search,variant)
 local shell=Field(parent,width,height,search,variant,true)
 local function Surface(focused,hovered) shell:SetFocused(focused,hovered) end
 local scroll=multiline and CreateFrame("ScrollFrame",nil,shell) or nil
 local box=CreateFrame("EditBox",nil,scroll or shell)
 C.DefaultFont(box,"font14");box:SetShadowOffset(0,0);box:SetTextColor(unpack(T.text));box:SetAutoFocus(false)
 box:SetJustifyV(multiline and "TOP" or "MIDDLE");box:SetMultiLine(multiline==true);box:SetMaxLetters(0)
 if scroll then
  scroll:SetPoint("TOPLEFT",T.editInset,-T.editMultilineInset);scroll:SetPoint("BOTTOMRIGHT",-T.editInset,T.editMultilineInset)
  box:SetWidth(width-T.editInset*2);box:SetHeight((height or 80)-20);scroll:SetScrollChild(box)
  Hook(shell,"OnSizeChanged",function() box:SetWidth(math.max(1,shell:GetWidth()-T.editInset*2)) end)
  box:SetScript("OnCursorChanged",function(_,_,y,_,cursorHeight)
   local top=scroll:GetVerticalScroll();y=-y
   if y<top then scroll:SetVerticalScroll(y) elseif y+cursorHeight>top+scroll:GetHeight() then scroll:SetVerticalScroll(y+cursorHeight-scroll:GetHeight()) end
  end)
  scroll:EnableMouseWheel(true);scroll:SetScript("OnMouseWheel",function(self,delta) self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*T.editScrollStep))) end)
 else box:SetPoint("TOPLEFT",T.editInset,-T.editVerticalInset);box:SetPoint("BOTTOMRIGHT",-T.editInset,T.editVerticalInset) end
 box:SetScript("OnEditFocusGained",function() Surface(true) end)
 box:SetScript("OnEditFocusLost",function() Surface(false) end)
 box:SetScript("OnEnter",function() if not box:HasFocus() then Surface(false,true) end end)
 box:SetScript("OnLeave",function() if not box:HasFocus() then Surface(false) end end)
 box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
 box:SetScript("OnHide",function(self) self:ClearFocus();Surface(false) end)
 shell.box=box;shell.scroll=scroll
 function shell:SetPlaceholder(text)
  if not self.placeholder then
   self.placeholder=C.Text(box,"","font14","muted",width-T.editInset*2);C.DefaultLineHeight(self.placeholder,"line20",not multiline);self.placeholder:SetPoint(multiline and "TOPLEFT" or "LEFT",0,0);self.placeholder:SetWordWrap(multiline==true)
   Hook(box,"OnTextChanged",function() self.placeholder:SetShown(box:GetText()=="") end)
  end
  UI:SetText(self.placeholder,text);self.placeholder:SetShown(box:GetText()=="")
 end
 UI.inputs[#UI.inputs+1]=box
 UI:Color(box,T.text)

 C.Style(shell,{recipe="edit",legacy=true,trackNative=true,slots={root=shell,surface=shell.fill,outline=shell.focus,input=box}})
 return shell
end
function C.Number(parent,width,height,onChange)
 local shell=C.Edit(parent,width,height or "fieldHeight")
 shell.box:SetNumeric(true)
 shell.box:SetScript("OnTextChanged",function() if onChange then onChange(shell.box:GetText()) end end)
 shell:SetPlaceholder("")
 return shell
end
function C.ChoiceTrigger(parent,width,action,options)
 local b=C.Button(parent,"",width,action)
 b:SetHeight(T.fieldHeight);b:SetRadius(T.fieldRadius);b.isChoice=true;b.fill:SetColor(T.selectBackground);b.fill:Show()
 b.label:ClearAllPoints();b.label:SetPoint("LEFT",T.choiceInset,0);b.label:SetWidth(width-T.choiceReserve);b.label:SetWordWrap(false)
 Hook(b,"OnSizeChanged",function(self,value) self.label:SetWidth(math.max(0,value-T.choiceReserve)) end)
 b.arrows={}
 for i=1,2 do local arm=b:CreateTexture(nil,"ARTWORK");b.arrows[i]=arm;arm:SetColorTexture(unpack(T.muted));arm:SetSize(T.choiceArrowWidth,T.choiceArrowThickness);arm:SetPoint("CENTER",b,"RIGHT",i==1 and -T.choiceArrowOuter or -T.choiceArrowInner,0);arm:SetRotation(i==1 and -math.pi/4 or math.pi/4) end

 function b:SetValue(value,label) self.value=value;UI:SetText(self.label,label or tostring(value or "")) end
 function b:SetSurfaceVariant(value) self.surfaceVariant=value;self:RefreshStyle(true) end
 if options then b:SetStyle(options) end
 C.ProtectStyle(b)
 return b
end
function C.Choice(parent,width,entries,onChange)
 return C.ChoiceTrigger(parent,width,function(self)
  UI:OpenMenu(self,type(entries)=="function" and entries() or entries,function(value,label) self:SetValue(value,label);if onChange then onChange(value) end end,{kind="select",selectedValue=self.value})
 end)
end
function C.Check(parent,label,onChange)
 local b=ButtonBase(parent,label,180,function(self) self:SetValue(not self.value,true);if onChange then onChange(self.value) end end)
 b.label:ClearAllPoints();b.label:SetPoint("LEFT",T.switchLabelX,0)
 local track=CreateFrame("Frame",nil,b);track:SetSize(T.switchWidth,T.switchHeight);track:SetPoint("LEFT")
 track.bg=C.Panel(track,"surfaceHigh",13)
 local knob=CreateFrame("Frame",nil,track);knob:SetSize(T.switchKnobSize,T.switchKnobSize);knob:SetPoint("LEFT",T.switchInset,0);knob.bg=C.Panel(knob,"dim",10)
 function b:RefreshStyle(immediate)
  local enabled=self:IsEnabled()
  local inside,pressed=enabled and self._inside,enabled and self._pressed
  local color=self.value and (pressed and T.primaryPressed or inside and T.primaryHover or T.primary)
   or pressed and T.secondaryContainer or inside and T.surfaceHighest or T.surfaceHigh
  if not C.OwnsStyle(self,"surface","color",color) then M:Color(track.bg,color,not immediate and T.feedbackDuration or nil) end
 end
 function b:SetValue(value,animate)
  local old=self.value;self.value=value==true
  if self.stateLabel then UI:SetText(self.stateLabel,self.value and (UI.L.on or "On") or (UI.L.off or "Off")) end
  if old==self.value then return end
  self:RefreshStyle(true);knob.bg:SetColor(self.value and T.onPrimary or T.dim)
  local x,size=self.value and T.switchActiveX or T.switchInset,self.value and T.switchActiveKnobSize or T.switchKnobSize
  knob:SetSize(size,size)
  if animate and old~=nil then M:Switch(knob,old and 21 or 5,x) else M:Stop(knob);knob:ClearAllPoints();knob:SetPoint("LEFT",track,"LEFT",x,0);knob._slideX=x end
 end
 b:SetValue(false);b.track=track;b.knob=knob
 Hook(b,"OnHide",function(self)
  M:Stop(knob)
  local x=self.value and T.switchActiveX or T.switchInset
  if knob._slideX~=x then knob:ClearAllPoints();knob:SetPoint("LEFT",track,"LEFT",x,0);knob._slideX=x end
 end)

 C.Style(b,{recipe="check",legacy=true,trackNative=true,slots={root=b,label=b.label,track=track,knob=knob,surface=track.bg,knobSurface=knob.bg}})
 return b
end

-- Remaining components below share this context and its finite motion driver.

-- Appearance for a native vertical scrollbar. Its owner supplies anchors,
-- content range and value callbacks; no extra driver or scroll state is added.
function C.ScrollBar(parent)
 local slider=CreateFrame("Slider",nil,parent);slider:SetOrientation("VERTICAL");slider:SetWidth(T.scrollWidth)
 slider:SetValueStep(1);slider:SetObeyStepOnDrag(true);slider:SetMinMaxValues(0,0)
 local thumb=slider:CreateTexture(nil,"ARTWORK");thumb:SetColorTexture(unpack(T.accent));thumb:SetSize(T.scrollWidth,T.scrollbarThumbHeight);slider:SetThumbTexture(thumb)
 slider.thumb=thumb

 return slider
end

-- Pixel virtual list: one clipped viewport, visible rows plus two spare rows.
-- offset stays an integer row index for older page callers; pixelOffset owns motion.
-- One passive visual layer moves; labels and button hit rectangles stay fixed.
function C.Selection(parent,options)
 options=options or {}
 local frame=CreateFrame("Frame",nil,parent);frame:SetFrameLevel(parent:GetFrameLevel()+1);frame:EnableMouse(false)
 frame.fill=C.Panel(frame,options.color or "secondaryContainer",options.radius or "selectionRadius")
 if options.mark then
  frame.mark=frame:CreateTexture(nil,"ARTWORK");frame.mark:SetColorTexture(unpack(T.accent));frame.mark:SetSize(T.selectionMarkWidth,T.selectionMarkHeight);frame.mark:SetPoint("LEFT",T.selectionMarkInset,0)

 end
 frame:Hide()
 function frame:Select(x,y,width,height,animate)
  local visible=self:IsShown()
  if animate==false then
   M:Stop(self);self._selMotion=true;self:SetAlpha(1);self:Show()
  else M:Selection(self,true,T.buttonSelectionDuration) end
  M:Rect(self,x,y,width,height,visible and animate~=false and T.selectionMoveDuration or 0)
 end
 function frame:Clear(animate)
  if animate and self:IsShown() then
   if self._selMotion~=false then M:Stop(self);M:Selection(self,false,T.buttonSelectionDuration) end
  else M:FinishRect(self);M:Stop(self);self._selMotion=nil;self:Hide() end
 end
 frame:SetScript("OnHide",function(self) M:FinishRect(self);M:Stop(self);self._selMotion=nil end)
 Hook(parent,"OnHide",function() frame:Clear() end)
 return frame
end
function C.List(parent,width,height,rowHeight,onSelect,onHover,options)
 local list=CreateFrame("Frame",nil,parent);list:SetSize(width,height)
 local CreateRow
 local gutterExplicit=false
 list.bodyHeight=rowHeight or T.listRowHeight
 list.rows={};list.offset=0;list.pixelOffset=0;list.rowHeight=rowHeight or T.listRowHeight;list.viewportHeight=height;list.gutter=C.listRightInset
 list.capacity=math.ceil(height/list.rowHeight);list.poolCapacity=list.capacity+2
 local clip=CreateFrame("ScrollFrame",nil,list);clip:SetPoint("TOPLEFT");clip:SetPoint("BOTTOMRIGHT",-C.listRightInset,0)
 local canvas=CreateFrame("Frame",nil,clip);canvas:SetSize(width-C.listRightInset,height+list.rowHeight*2);clip:SetScrollChild(canvas)
 list.clip,list.canvas=clip,canvas
 local slider=C.ScrollBar(list);slider:SetPoint("TOPRIGHT",0,-2);slider:SetPoint("BOTTOMRIGHT",0,2)
 list.slider=slider
 function list:GetElementKey(key,index)
  if key==nil then return nil end
  if self.rowElementKey then
   if not index then for position,value in ipairs(self.ids or {}) do if value==key then index=position;break end end end
   return self.rowElementKey(key,index)
  end
  return key
 end
 local function Variable() return list.rowHeightResolver~=nil or list.elementHeights==true end
 local function RowTop(index) return list.geometryOffsets and list.geometryOffsets[index] or (index-1)*list.rowHeight end
 local function FindRow(pixel)
  local offsets=list.geometryOffsets;if not offsets then return math.floor(pixel/list.rowHeight)+1 end
  local indices=list.geometryIndices;local low,high=1,#indices
  if high==0 then return 1,1 end
  while low<high do local middle=math.floor((low+high+1)/2);if offsets[indices[middle]]<=pixel then low=middle else high=middle-1 end end
  return indices[low],low
 end
 local function ClearGeometryRows()
  if list.geometryRows then for key in pairs(list.geometryRows) do list.geometryRows[key]=nil end end
  if list._elementHeightRecord then list._elementHeightRecord.key=nil end
 end
 local function BuildGeometry()
  local variable=Variable()
  if not variable then
   if list.geometryOffsets then
    for index,row in ipairs(list.rows) do row:SetHeight(list.bodyHeight);row:SetPoint("TOPLEFT",0,-(index-1)*list.rowHeight) end
    canvas:SetHeight(list:GetHeight()+list.rowHeight*2)
   end
   list.geometryOffsets=nil;list.geometryIndices=nil;list.geometryDirty=false;ClearGeometryRows();return
  end
  if not list.geometryDirty and list.geometryStride==list.rowHeight and list.geometryBody==list.bodyHeight then return end
  local offsets=list._geometryOffsets or {};list._geometryOffsets=offsets;list.geometryOffsets=offsets
  local rows=list.geometryRows or {};list.geometryRows=rows;for key in pairs(rows) do rows[key]=nil end
  for _,row in ipairs(list.rows) do if row.key then rows[row.key]=row end end
  local gap=math.max(0,list.rowHeight-list.bodyHeight);local top=0;local count=list.ids and #list.ids or 0
  local indices=list._geometryIndices or {};list._geometryIndices=indices;list.geometryIndices=indices;local visible=0
  for index=1,count do
   local key=list.ids[index];local height=list.bodyHeight
   if list.rowHeightResolver then height=list.rowHeightResolver(key,index,height) or height end
   if list.elementHeights then height=UI:ResolveListElementHeight(list,key,height,rows[key],index) end
   if type(height)~="number" or height<0 or height~=height or height==math.huge then error("list row height must be finite and nonnegative",2) end
   offsets[index]=top
   if height>0 then visible=visible+1;indices[visible]=index;top=top+height+gap end
  end
  offsets[count+1]=top;for index=#offsets,count+2,-1 do offsets[index]=nil end
  for index=#indices,visible+1,-1 do indices[index]=nil end
  ClearGeometryRows()
  list.contentHeight=visible>0 and top-gap or 0;list.geometryGap=gap;list.geometryStride,list.geometryBody=list.rowHeight,list.bodyHeight;list.geometryDirty=false
 end
 local function ContentHeight()
  BuildGeometry()
  local count=list.ids and #list.ids or 0
  return list.geometryOffsets and list.contentHeight or (count>0 and (count-1)*list.rowHeight+list.rows[1]:GetHeight() or 0)
 end
 function list:GetContentHeight() return ContentHeight() end
 local function MaxOffset()
  local overflow=ContentHeight()-list:GetHeight()
  return overflow>.01 and overflow or 0
 end
 function list:RefreshGeometry()
  self.geometryDirty=true
  if not self.refreshing then self:Refresh(true) end
 end
 function list:RowGeometryChanged()
  if Variable() then self:RefreshGeometry() end
 end
 function list:SetRowHeightResolver(resolve)
  if self.rowHeightResolver==resolve then return end
  self.rowHeightResolver=resolve;self:RefreshGeometry()
 end
 local function Release(row)
  if C.RekeyElement then C.RekeyElement(row,nil) end
  if row.pressedKey then row.pressCancelled=true end
  row._lycheeListIndex=nil
  row.key=nil;row.noteDot:Hide();row.alternate:Hide();row.hover:Hide();row.hover:SetAlpha(0)
  row._inside=nil;row._pressed=nil
  M:Stop(row.selected);M:Stop(row.mark);M:Stop(row.hover)
  row.selected._selMotion=nil;row.selected:SetAlpha(0);row.selected:Hide()
  row.mark._selMotion=nil;row.mark:SetAlpha(0);row.mark:Hide()
  UI:ReleaseRow(row)
 end
 local function Leave(row)
  row._inside=nil;row._pressed=nil;M:Stop(row.hover);row.hover:Hide();row.hover:SetAlpha(0)
  if list.idleTextColor then UI:Color(row.title,row.key==list.selectedKey and T.onSecondaryContainer or Value(list.idleTextColor)) end
  if row.symbol then UI:SetIconState(row.symbol,row.key==list.selectedKey,false) end
  if row.pressedKey then row.pressCancelled=true end
  UI:LeaveRow(row)
  if row._lycheeStyleController then row._lycheeStyleController:Apply(true) end
 end
 local function Highlight(row,immediate)
  local selected=row.key==list.selectedKey and list.selectionFill~=false
  local hovered=row:IsEnabled() and row._hitVisible and not selected and (row._inside or row._pressed)
  local visible=hovered and list.hoverFill~=false
  local hoverColor=row._pressed and T.pressed or Value(list.hoverColor) or T.rowHover
  local ownColor=C.OwnsStyle(row,"hover","color",hoverColor)
  local ownShown=C.OwnsStyle(row,"hover","shown",visible==true)
  local ownAlpha=C.OwnsStyle(row,"hover","alpha",visible and 1 or 0)
  if visible then
   if not ownColor then row.hover:SetColor(hoverColor) end
   if not ownShown then row.hover:Show() end
   if not ownAlpha then if immediate then M:Stop(row.hover);row.hover:SetAlpha(1) else M:Alpha(row.hover,1,T.selectionDuration) end end
  else
   if not ownAlpha then M:Stop(row.hover);row.hover:SetAlpha(0) end
   if not ownShown then row.hover:Hide() end
  end
  if list.idleTextColor then
   local textColor=selected and T.onSecondaryContainer or hovered and T.text or Value(list.idleTextColor)
   if not C.OwnsStyle(row,"label","color",textColor) then UI:Color(row.title,textColor) end
  end
  row._selected=selected==true;if row._lycheeStyleController then row._lycheeStyleController:Apply(immediate) end
 end
 function list:Refresh(positionOnly)
  if self.refreshing then return end
  self.refreshing=true
  local ids=self.ids;local maximum=MaxOffset()
  local selectionRow,selectionY
  if self.offset~=FindRow(self.pixelOffset or 0)-1 then self.pixelOffset=RowTop(self.offset+1) or 0 end
  self.pixelOffset=math.max(0,math.min(self.pixelOffset or 0,maximum));self.offset=FindRow(self.pixelOffset)-1
  if self.scrollTarget and self.pixelOffset==maximum and self.scrollTarget>maximum then M:Stop(self);self.scrollTarget=maximum end
  self.updating=true
  local minimum,currentMaximum=slider:GetMinMaxValues()
  if minimum~=0 or currentMaximum~=maximum then slider:SetMinMaxValues(0,maximum) end
  slider:SetValue(self.pixelOffset);self.updating=false
  if slider:IsShown()~=(maximum>0) then slider:SetShown(maximum>0) end
  local firstTop=RowTop(self.offset+1) or 0
  local visible=self.capacity+1;local firstVisible=1
  if self.geometryOffsets then
   local indices=self.geometryIndices
   local _,position=FindRow(self.pixelOffset);firstVisible=position
   local last=firstVisible
   while last<=#indices and RowTop(indices[last])<self.pixelOffset+self:GetHeight() do last=last+1 end
   visible=math.min(#indices-firstVisible+1,last-firstVisible+1)
   while self.poolCapacity<visible+1 do self.poolCapacity=self.poolCapacity+1;CreateRow(self.poolCapacity);if self.initializeRow then self.initializeRow(self.rows[self.poolCapacity]) end end
   visible=math.min(visible,self.poolCapacity)
   local last=indices[firstVisible+visible-1]
   local canvasHeight=math.max(self:GetHeight(),last and self.geometryOffsets[last+1]-firstTop-self.geometryGap or 0)
   if canvas:GetHeight()~=canvasHeight then canvas:SetHeight(canvasHeight) end
  end
  clip:SetVerticalScroll(self.pixelOffset-firstTop)
  for i,row in ipairs(self.rows) do
   local absolute=self.geometryIndices and self.geometryIndices[firstVisible+i-1] or self.offset+i
   local key=ids and i<=visible and ids[absolute] or nil
   local rebound=row.key~=key
   if rebound then Release(row);row.key=key;if UI.CloseMenuFor then UI:CloseMenuFor(self) end end
   if self.rowElementKey then row._lycheeListIndex=key~=nil and absolute or nil end
   if key and self.elementHeights and self.rowElementState then
    local checked=self.rowElementState(key,absolute,"checked")
    if checked~=nil then row._checked=checked==true end
    local disabled=self.rowElementState(key,absolute,"disabled")
    if disabled~=nil then local enabled=disabled~=true;if row:IsEnabled()~=enabled then row:SetEnabled(enabled) end end
   end
   row.alternate:SetShown(key~=nil and self.alternateRows~=false and absolute%2==0)
   if row:IsShown()~=(key~=nil) then row:SetShown(key~=nil) end
   if key and self.geometryOffsets then
    local y=-(RowTop(absolute)-firstTop)
    local p,a,b,x,oldY=row:GetPoint()
    if type(a)=="number" then oldY=b end
    if p~="TOPLEFT" or oldY~=y then row:SetPoint("TOPLEFT",0,y) end
    local body=self.geometryOffsets[absolute+1]-self.geometryOffsets[absolute]-self.geometryGap
    if row:GetHeight()~=body then row:SetHeight(body) end
   end
   if key and self.render then
    if rebound or not positionOnly then
     if list.elementTemplate then local elementKey=list:GetElementKey(key,absolute);if not row._lycheeElementRegistered then C.Element(row,list.elementTemplate,{template=list.elementTemplate,key=elementKey,scope=list.elementScope,slots=list.elementRowSlots or row});row._lycheeElementRegistered=true else C.RekeyElement(row,elementKey,list.elementTemplate) end end
     self.render(row,key);if C.ApplyElement then C.ApplyElement(row) end
    end
    local selected=key==self.selectedKey
    local duration=not self:IsVisible() and 0 or nil
    M:Selection(row.selected,selected and self.selectionFill~=false and not self.selectionMotion,duration);M:Selection(row.mark,selected and self.selectionMark~=false and not self.selectionMotion,duration)
    if selected then selectionRow,selectionY=row,-(RowTop(absolute)-firstTop) end
    Highlight(row,true)
    if row.symbol then UI:SetIconState(row.symbol,selected,row._inside==true) end
   end
   -- ScrollFrame clips pixels, while each button still owns its full hit rect.
   -- Keep partial rows visible and clickable only inside the clipped viewport.
   local rowHeight=row:GetHeight()
   local top=key and RowTop(absolute)-self.pixelOffset or 0
   local cropTop=math.min(rowHeight,math.max(0,-top))
   local cropBottom=math.min(rowHeight-cropTop,math.max(0,top+rowHeight-self:GetHeight()))
   local left,right,previousTop,previousBottom=row:GetHitRectInsets()
   if left~=0 or right~=0 or previousTop~=cropTop or previousBottom~=cropBottom then row:SetHitRectInsets(0,0,cropTop,cropBottom) end
   row._hitVisible=key~=nil and cropTop+cropBottom<rowHeight
   if row:IsMouseEnabled()~=row._hitVisible then row:EnableMouse(row._hitVisible) end
   if row._inside and (not row._hitVisible or not clip:IsMouseOver() or not row:IsMouseOver()) then Leave(row) end
  end
  if self.indicator then
   if self.selectionMotion and selectionRow then
    local animate=self:IsVisible() and (self.indicatorKey~=self.selectedKey or self.indicatorOffset==self.offset)
    self.indicator:Select(0,selectionY,selectionRow:GetWidth(),selectionRow:GetHeight(),animate)
    self.indicator.fill:SetShown(self.selectionFill~=false)
    self.indicator.mark:SetShown(self.selectionMark~=false)
   else self.indicator:Clear(self:IsVisible() and self.indicatorOffset==self.offset) end
   self.indicatorKey,self.indicatorOffset=self.selectedKey,self.offset
  end
  self.refreshing=nil
  if self.geometryDirty then self:Refresh(true) end
  if Variable() and options and options.onGeometryChanged then
   local height=ContentHeight()
   if self.notifiedContentHeight~=height then self.notifiedContentHeight=height;options.onGeometryChanged(self,height) end
  end
 end
 local scrollFrom,scrollElapsed=0,0
 local function ScrollStep(dt)
  scrollElapsed=math.min(T.scrollDuration,scrollElapsed+dt);local p=scrollElapsed/T.scrollDuration;p=1-(1-p)*(1-p)
  list.pixelOffset=scrollFrom+(list.scrollTarget-scrollFrom)*p;list.offset=FindRow(list.pixelOffset)-1;list:Refresh(true)
  return scrollElapsed==T.scrollDuration
 end
 function list:SetPixelOffset(value,animate)
  local target=math.max(0,math.min(value,MaxOffset()))
  M:Stop(self);self.scrollTarget=target
  if target==self.pixelOffset or not animate or UI:IsReducedMotion() or T.scrollDuration==0 then self.pixelOffset=target;self.offset=FindRow(target)-1;self:Refresh(true);return end
  scrollFrom,scrollElapsed=self.pixelOffset,0
  M:Start(self,ScrollStep)
 end
 local function EnsureRows(height)
  local visible=math.ceil(height/list.rowHeight)
  if list.initializeRow then
   local required=math.min(visible,list.ids and #list.ids or 0)+2
   for i=list.poolCapacity+1,required do CreateRow(i);list.initializeRow(list.rows[i]) end
   list.poolCapacity=math.max(list.poolCapacity,required)
  end
  list.capacity=math.min(list.poolCapacity-1,visible)
 end
 function list:SetItems(ids,render) self.ids=ids;self.render=render;self.geometryDirty=true;EnsureRows(self:GetHeight());self:Refresh() end
 function list:SetRowHeight(stride,bodyHeight,viewportHeight)
  if type(stride)~="number" or stride<=0 or stride~=stride or stride==math.huge then error("list row stride must be finite and positive",2) end
  local body=bodyHeight or self.rowStyle and Value(self.rowStyle.rowHeight) or stride
  if type(body)~="number" or body<0 or body~=body or body==math.huge then error("list row body height must be finite and nonnegative",2) end
  self.rowHeight=stride;self.bodyHeight=body
  if viewportHeight~=nil and self.viewportHeight~=viewportHeight then self.viewportHeight=viewportHeight;self:SetHeight(viewportHeight) end
  self.geometryDirty=true
  if not Variable() then for index,row in ipairs(self.rows) do row:SetHeight(self.bodyHeight);row:SetPoint("TOPLEFT",0,-(index-1)*stride) end end
  EnsureRows(self:GetHeight());canvas:SetHeight(self:GetHeight()+stride*2)
  self:Refresh(true)
 end
 function list:SetRowInitializer(initialize)
  self.initializeRow=initialize
  for _,row in ipairs(self.rows) do initialize(row) end
 end
 function list:SetViewport(value)
  if self.viewportHeight==value then return end
  self.viewportHeight=value
  self:SetHeight(value);EnsureRows(value);canvas:SetHeight(value+self.rowHeight*2);self:Refresh()
 end
 local function ResizeContent()
  local width=list:GetWidth()-list.gutter
  canvas:SetWidth(width)
  for _,row in ipairs(list.rows) do row:SetWidth(width) end
 end
 function list:SetGutter(width)
  gutterExplicit=true
  if self.gutter==width then return end
  self.gutter=width;clip:SetPoint("BOTTOMRIGHT",-width,0);ResizeContent()
  self:Refresh()
 end
 function list:Select(key,locate)
  self.selectedKey=key
  if self.elementHeights then self.geometryDirty=true;BuildGeometry() end
  if locate and self.ids then for i,id in ipairs(self.ids) do if id==key then self:SetPixelOffset(RowTop(i),false);return end end end
  self:Refresh(true)
 end
 function list:Clear()
  local refreshing=self.refreshing;self.refreshing=true
  M:Stop(self);self.scrollTarget=nil;self.ids=nil;self.render=nil;self.selectedKey=nil;self.geometryDirty=true
  if self.indicator then self.indicator:Clear();self.indicatorKey=nil end
  for _,row in ipairs(self.rows) do Release(row);row:Hide();UI:SetText(row.title,"");UI:SetText(row.meta,"") end
  ClearGeometryRows()
  self._elementHeightRecord=nil;self._elementHeightStates=nil
  slider:Hide()
  self.refreshing=refreshing
 end
 function list:RefreshKeys(keys,resolve)
  for _,row in ipairs(self.rows) do if row.key then
   for _,key in ipairs(keys) do if resolve(row.key,key) then self.render(row,row.key);UI:ReleaseRow(row);break end end
  end end
 end
 local function ApplyRowStyle(row,style)
  if style.rowHeight then row:SetHeight(Value(style.rowHeight)) end
  if style.radius then row.alternate:SetRadius(style.radius);row.selected:SetRadius(style.radius);row.hover:SetRadius(style.radius) end
  if style.titleSize then C.DefaultFont(row.title,style.titleSize) end
  if style.titleLineHeight then C.DefaultLineHeight(row.title,style.titleLineHeight,true) end
  if style.singleLine~=nil then row.meta:SetShown(not style.singleLine) end
  if style.singleLine~=nil or style.titleX then
   row.title:ClearAllPoints()
   if style.singleLine==false then row.title:SetPoint("TOPLEFT",Value(style.titleX or "listTextInset"),-T.listTextTop) else row.title:SetPoint("LEFT",Value(style.titleX or "listTextInset"),0) end
  end
  if style.titleWidth then row.title:SetWidth(Value(style.titleWidth)) end
 end
 function list:SetStyle(style)
  self.rowStyle=self.rowStyle or {};for key,value in pairs(style) do self.rowStyle[key]=value end
  if style.selectionMotion~=nil then
   self.selectionMotion=style.selectionMotion
   if style.selectionMotion and not self.indicator then self.indicator=C.Selection(canvas,{radius=style.radius or "selectionRadius",mark=true}) end
  end
  if self.indicator and style.radius then self.indicator.fill:SetRadius(style.radius) end
  for _,key in ipairs({"alternateRows","selectionFill","selectionMark","hoverFill","idleTextColor","hoverColor"}) do if style[key]~=nil then self[key]=style[key] end end
  if style.rowHeight then self.bodyHeight=Value(style.rowHeight);self.geometryDirty=true end
  for _,row in ipairs(self.rows) do ApplyRowStyle(row,self.rowStyle) end
  self:Refresh(true)
 end

 slider:SetScript("OnValueChanged",function(_,value) if not list.updating then list:SetPixelOffset(value,false) end end)
 list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",function(self,delta) self:SetPixelOffset((self.scrollTarget or self.pixelOffset)-delta*self.rowHeight*2,true) end)
 list:SetScript("OnHide",function(self)
  M:Stop(self);self.scrollTarget=nil
  if self.indicator then self.indicator:Clear();self.indicatorKey=nil end
  for _,row in ipairs(self.rows) do
   M:Stop(row.hover);row.hover:Hide();M:Stop(row.selected);M:Stop(row.mark)
   local selected=row.key~=nil and row.key==self.selectedKey
   row.selected:SetAlpha(selected and 1 or 0);row.mark:SetAlpha(selected and 1 or 0)
  end
 end)
 list:SetScript("OnShow",function(self) self:Refresh(true) end)
 CreateRow=function(i)
  local row=CreateFrame("Button",nil,canvas);row._lycheeList=list;row:SetSize(list:GetWidth()-list.gutter,list.rowHeight);row:SetPoint("TOPLEFT",0,-(i-1)*list.rowHeight)
  row.alternate=CreatePanel(row,"rowAlternate","listRadius",nil,nil,true)
  row.selected=CreatePanel(row,"secondaryContainer","listRadius",nil,nil,true)
  row.hover=CreatePanel(row,"rowHover","listRadius",nil,nil,true)
  row.hover:SetAlpha(0)
  row.mark=row:CreateTexture(nil,"ARTWORK");row.mark:SetColorTexture(unpack(T.accent));row.mark:SetSize(T.selectionMarkWidth,T.selectionMarkHeight);row.mark:SetPoint("LEFT",T.selectionMarkInset,0);row.mark:Hide()
  row.title=C.Text(row,"","listTitleSize","text",width-T.listTextReserve);C.DefaultLineHeight(row.title,"listTitleLineHeight",true);row.title:SetPoint("TOPLEFT",T.listTextInset,-T.listTextTop);row.title:SetWordWrap(false)
  row.meta=C.Text(row,"","listMetaSize","muted",width-T.listTextReserve);C.DefaultLineHeight(row.meta,"listMetaLineHeight",true);row.meta:SetPoint("BOTTOMLEFT",T.listTextInset,T.listTextTop);row.meta:SetWordWrap(false)
  row.noteDot=row:CreateTexture(nil,"ARTWORK");row.noteDot:SetColorTexture(unpack(T.accent));row.noteDot:SetSize(T.listDotSize,T.listDotSize);row.noteDot:Hide()
  row:RegisterForClicks("LeftButtonUp","RightButtonUp")
  row:SetScript("OnMouseDown",function(self) self.pressedKey=self.key;self.pressCancelled=nil;if self:IsEnabled() and self.key and self._hitVisible then self._pressed=true;Highlight(self) else self.pressCancelled=true end end)
  row:SetScript("OnMouseUp",function(self) self._pressed=nil;Highlight(self) end)
  row:SetScript("OnClick",function(self,button)
   if UI:IsHiding() or self.pressCancelled or not self.key or not self._hitVisible or (self.pressedKey and self.pressedKey~=self.key) then self.pressedKey=nil;self.pressCancelled=nil;return end
   self.pressedKey=nil;list:Select(self.key);if onSelect then onSelect(self.key,button,self) end
  end)
  row:SetScript("OnEnter",function(self) if not self:IsEnabled() or not self.key or not self._hitVisible or not clip:IsMouseOver() then return end;self._inside=true;Highlight(self);if self.symbol then UI:SetIconState(self.symbol,self.key==list.selectedKey,true) end;if onHover then onHover(self,self.key) end end)
  row:SetScript("OnLeave",Leave)
  row:SetScript("OnHide",function(self) self._inside=nil;self._pressed=nil;M:Stop(self.hover);self.hover:Hide();if self.pressedKey then self.pressCancelled=true end end)
  if options and options.initializeRow then options.initializeRow(row) end
  C.Style(row,{recipe=options and options.recipe or "listRow",legacy=true,trackNative=true,slots={root=row,label=row.title,meta=row.meta,surface=row.alternate,hover=row.hover,selected=row.selected,mark=row.mark,icon=row.icon,check=row.check}})
  if list.elementTemplate and C.Element then C.Element(row,list.elementTemplate,{template=list.elementTemplate,key=list:GetElementKey(row.key,row._lycheeListIndex),scope=list.elementScope,slots=list.elementRowSlots or row});row._lycheeElementRegistered=true end
  list.rows[i]=row
  if list.rowStyle then ApplyRowStyle(row,list.rowStyle) end
 end
 for i=1,list.poolCapacity do CreateRow(i) end
 Hook(list,"OnSizeChanged",ResizeContent)
 return list
end

-- Fixed columns share each row's native objects; scrolling only changes their text.
function C.Columns(list,columns,titleWidth)
 for _,row in ipairs(list.rows) do
  row.title:SetWidth(titleWidth);row.meta:SetWidth(titleWidth)
  row.columns={}
  for _,column in ipairs(columns) do
   local size=column.size or "listMetaSize"
   local text=C.Text(row,"",size,"muted",column.width)
   C.DefaultLineHeight(text,column.lineHeight or (column.size and Value(size)+6 or "listMetaLineHeight"),true)
   text:SetPoint("LEFT",row,"LEFT",column.x,0);text:SetJustifyH(column.align or "RIGHT");text:SetWordWrap(false)
   row.columns[column.key]=text
  end
 end
end

-- Column geometry belongs to the header; applications own rows, data and prefs.
function C.TableHeader(parent,definitions,options)
 options=options or {}
 local h=CreateFrame("Frame",nil,parent);h:SetSize(1,T.tableHeight);h:EnableMouse(true)
 h.columns,h.labels,h.buttons,h.handles={},{},{},{}
 h.state={}
 local function Notify(changes)
  local callback=options.onPreferenceChanged or UI.options.onTablePreferenceChanged
  if callback then callback(h,changes) end
 end
 UI.tableHeaders=UI.tableHeaders or setmetatable({},{__mode="k"});UI.tableHeaders[h]=true
 local function Hover()
  local inside=h.drag~=nil or h:IsMouseOver()
  for i,handle in ipairs(h.handles) do
   local active=h.drag and h.drag.index==i
   local hovered=not h.drag and handle:IsMouseOver()
   handle.line:SetShown(inside and i<#h.definitions)
   handle.line:SetColorTexture(unpack(active and T.accent or T.dim))
   handle.line:SetAlpha(active and 1 or hovered and T.tableHoverAlpha or T.tableIdleAlpha)
   handle.line:SetWidth((active or hovered) and T.tableActiveLineWidth or T.tableLineWidth)
  end
 end
 local function Paint()
  local x=0
  for i,def in ipairs(h.definitions) do
   local cell=h.columns[def.key];cell.x=x
   local button=h.buttons[i];button:ClearAllPoints();button:SetPoint("TOPLEFT",x,0);button:SetSize(cell.width,h:GetHeight())
   local sorted=h.state.sortKey==def.key and def.sortable
   UI:Color(button.label,sorted and T.text or T.dim)
   button.label:SetWidth(math.max(1,cell.width-T.tablePadding*2))
   local handle=h.handles[i]
   handle:ClearAllPoints();handle:SetPoint("TOPLEFT",x+cell.width-T.tableHandleWidth/2,0);handle:SetSize(T.tableHandleWidth,h:GetHeight())
   handle:SetShown(i<#h.definitions)
   x=x+cell.width
  end
  Hover()
  if options.onLayout then options.onLayout(h) end
 end
 function h:SetSort(key,descending,notify)
  self.state.sortKey,self.state.descending=key,descending==true
  if self.layoutWidth then Paint() end
  if notify==true then Notify({sortKey=key,descending=descending==true}) end
 end
 function h:Layout(width)
  if self.drag then self:StopDrag(true,false) end
  self.layoutWidth=math.max(1,width);self:SetWidth(self.layoutWidth)
  local totalWeight,minimum,defaultTotal=0,0,0
  for _,def in ipairs(self.definitions) do defaultTotal=defaultTotal+Value(def.width) end
  for i,def in ipairs(self.definitions) do
   local cell=self.columns[def.key]
   cell.weight=self.state.widths and self.state.widths[def.key] or Value(def.width)/defaultTotal
   cell.weight=math.max(.001,tonumber(cell.weight) or Value(def.width)/defaultTotal)
   cell.minimum=math.max(Value(def.min or 32),self.buttons[i].label:GetUnboundedStringWidth()+T.tablePadding*2);cell.fixed=nil
   minimum=minimum+cell.minimum;totalWeight=totalWeight+cell.weight
  end
  local remaining=self.layoutWidth
  -- Tiny hosts still fit; normal host minima keep each column fully usable.
  local minimumScale=math.min(1,self.layoutWidth/minimum)
  for _,def in ipairs(self.definitions) do self.columns[def.key].minimum=self.columns[def.key].minimum*minimumScale end
  for _=1,#self.definitions do
   local clamped=false
   for _,def in ipairs(self.definitions) do
    local cell=self.columns[def.key]
    if not cell.fixed and remaining*cell.weight/totalWeight<cell.minimum then
     cell.width,cell.fixed=cell.minimum,true;remaining=remaining-cell.width;totalWeight=totalWeight-cell.weight;clamped=true
    end
   end
   if not clamped then break end
  end
  for _,def in ipairs(self.definitions) do
   local cell=self.columns[def.key]
   if not cell.fixed then cell.width=remaining*cell.weight/totalWeight end
  end
  Paint()
 end
 function h:SetState(state)
  if self.state==state then return end
  self:StopDrag(false);self.state=state
  if self.layoutWidth then self:Layout(self.layoutWidth) end
 end
 function h:ResetWidths()
  self:StopDrag(false);self.state.widths=nil
  if self.layoutWidth then self:Layout(self.layoutWidth) end
  Notify({widths=false})
 end
 function h:StopDrag(commit,notify)
  if not self.drag then return end
  self.drag=nil;self:SetScript("OnUpdate",nil)
  if commit then
   local widths={}
   for _,def in ipairs(self.definitions) do widths[def.key]=self.columns[def.key].width/self.layoutWidth end
   self.state.widths=widths
   if notify~=false then Notify({widths=widths}) end
   Hover()
  else self:Layout(self.layoutWidth) end
 end
 function h:UpdateDrag()
  local drag=self.drag
  local released=not IsMouseButtonDown("LeftButton")
  local left=self.columns[self.definitions[drag.index].key]
  local right=self.columns[self.definitions[drag.index+1].key]
  local delta=GetCursorPosition()/drag.scale-drag.startX
  local width=math.max(left.minimum,math.min(drag.total-right.minimum,drag.width+delta))
  if math.abs(width-left.width)>=.01 then left.width,right.width=width,drag.total-width;Paint() end
  if released then self:StopDrag(true) end
 end
 function h:StartDrag(index)
  if UI:IsHiding() then return end
  self:StopDrag(true)
  if options.onDragStart then options.onDragStart(self) end
  local left=self.columns[self.definitions[index].key]
  local right=self.columns[self.definitions[index+1].key]
  local scale=self:GetEffectiveScale()
  self.drag={index=index,startX=GetCursorPosition()/scale,scale=scale,width=left.width,total=left.width+right.width}
  self:SetScript("OnUpdate",self.UpdateDrag);Hover()
 end
 function h:SetColumns(defs,width,state)
  self:StopDrag(true,false);self.definitions=defs;wipe(self.labels)
  if state~=nil then self.state=state end
  for i,def in ipairs(defs) do
   local button=self.buttons[i]
   if not button then
    button=CreateFrame("Button",nil,self);self.buttons[i]=button
    button.label=C.Text(button,"","font14","dim");C.DefaultLineHeight(button.label,"line20",true)
    button.label:SetPoint("LEFT",T.tablePadding,0);button.label:SetWordWrap(false)
    button:SetScript("OnEnter",Hover);button:SetScript("OnLeave",Hover)
    button:SetScript("OnClick",function(b)
     local col=b.definition
     if not col or not col.sortable or UI:IsHiding() then return end
     local descending=self.state.sortKey==col.key and not self.state.descending or false
     self:SetSort(col.key,descending,true)
     if options.onSort then options.onSort(col.key,descending) end
    end)
    local handle=CreateFrame("Button",nil,self);self.handles[i]=handle
    handle:SetFrameLevel(button:GetFrameLevel()+2)
    handle.line=handle:CreateTexture(nil,"OVERLAY");handle.line:SetSize(T.tableLineWidth,T.tableLineHeight);handle.line:SetPoint("CENTER")
    handle:SetScript("OnEnter",Hover);handle:SetScript("OnLeave",Hover)
    handle:SetScript("OnMouseDown",function(_,mouse)
     if UI:IsHiding() then return end
     if mouse=="LeftButton" then self:StartDrag(i)
     elseif mouse=="RightButton" then self:ResetWidths() end
    end)
    handle:SetScript("OnMouseUp",function(_,mouse) if mouse=="LeftButton" and self.drag then self:UpdateDrag();self:StopDrag(true) end end)
   end
   self.columns[def.key]=self.columns[def.key] or {x=0,width=Value(def.width)}
   button.definition=def;button:Show();button.label:SetJustifyH(def.align or "LEFT");UI:SetText(button.label,def.label)
   self.labels[def.key]=button.label
  end
  for key in pairs(self.columns) do if not self.labels[key] then self.columns[key]=nil end end
  for i=#defs+1,#self.buttons do
   local button=self.buttons[i];button.definition=nil;UI:SetText(button.label,"");button:Hide();self.handles[i]:Hide()
  end
  if width~=nil or self.layoutWidth then self:Layout(width or self.layoutWidth) end
 end
 h:SetScript("OnEnter",Hover);h:SetScript("OnLeave",Hover)
 h:SetScript("OnHide",function() h:StopDrag(false) end)
 h:SetColumns(definitions)
 h:SetHeight(T.tableHeight)

 return h
end

function C.Header(parent,label,x,y,width,align)
 local text=C.Text(parent,label,"font14","dim",width)
 C.DefaultLineHeight(text,"line20",true)
 text:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);text:SetJustifyH(align or "LEFT");text:SetWordWrap(false)
 return text
end

function C.Icon(parent,size)
 local texture=parent:CreateTexture(nil,"ARTWORK");texture:SetSize(size,size);return texture
end
function C.GameIcon(parent,size)
 local texture=C.Icon(parent,size);UI:RoundIcon(texture);return texture
end
function C.Glyph(parent,kind,size,color)
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(size,size)
 local image=C.Icon(frame,size);image:SetAllPoints();frame.texture=image;frame._lycheeTexture=image
 image:SetTexture(T.media..kind..".tga");image:SetTexCoord(0,1,0,1)
 function frame:SetSelected(selected,hovered) UI:SetIconState(image,selected,hovered) end
 function frame:SetTexture(file) image:SetTexture(file) end
 function frame:SetColor(value) image:SetVertexColor(unpack(value)) end
 if color then frame:SetColor(color) end

 return frame
end
function C.Slider(parent,width,min,max,step,onChange,options)
 local shell=CreateFrame("Frame",nil,parent);shell:SetSize(Value(width),T.sliderHeight)
 if options and options.commitOnRelease then
  min,max,step=min or 0,max or 100,step or 1
  local input=CreateFrame("Frame",nil,shell);input:SetSize(Value(width),T.sliderHitHeight);input:SetPoint("CENTER");input:EnableMouse(true)
  local track=CreateFrame("Frame",nil,input);track:SetHeight(T.sliderTrackHeight);track:SetPoint("LEFT");track:SetPoint("RIGHT");C.Panel(track,"surfaceHigh","sliderTrackRadius")
  local progress=CreateFrame("Frame",nil,track);progress:SetHeight(T.sliderTrackHeight);progress:SetPoint("LEFT");C.Panel(progress,"accent","sliderTrackRadius")
  local thumb=CreateFrame("Button",nil,input);thumb:SetSize(T.sliderThumbWidth,T.sliderThumbHeight)
  local texture=thumb:CreateTexture(nil,"ARTWORK");texture:SetAllPoints();texture:SetTexture(130871);texture:SetVertexColor(unpack(T.accent))
  local drag
  function shell:SetValue(value)
   value=min+math.floor((value-min)/step+.5)*step
   self.value=math.max(min,math.min(max,value))
   local x=max>min and input:GetWidth()*(self.value-min)/(max-min) or 0
   progress:SetWidth(x);thumb:ClearAllPoints();thumb:SetPoint("CENTER",input,"LEFT",x,0)
   if options.onPreview then options.onPreview(self.value) end
  end
  function shell:GetValue() return self.value end
  function shell:IsDragging() return drag~=nil end
  function input:GetValue() return shell:GetValue() end
  function input:SetValue(value) shell:SetValue(value) end
  local function Sample(first)
   local x=select(1,GetCursorPosition())/drag.scale-drag.left
   local raw=min+math.max(0,math.min(1,x/drag.width))*(max-min)
   -- Preserve the current step across small cursor jitter at its boundary.
   if first or math.abs(raw-shell.value)>=step*.65 then shell:SetValue(raw) end
  end
  function shell:FinishDrag(commit)
   if not drag then return end
   input:SetScript("OnUpdate",nil)
   local previous=drag.value;drag=nil
   if commit then if onChange then onChange(self.value) end
   else self:SetValue(previous) end
  end
  local function Begin(_,button)
   if button~="LeftButton" or drag then return end
   drag={scale=input:GetEffectiveScale(),left=input:GetLeft(),width=input:GetWidth(),value=shell.value}
   Sample(true)
   if not drag then return end
   input:SetScript("OnUpdate",function()
    Sample(false)
    if not IsMouseButtonDown("LeftButton") then shell:FinishDrag(true) end
   end)
  end
  local function Release(_,button)
   if button=="LeftButton" and drag then Sample(false);shell:FinishDrag(true) end
  end
  input:SetScript("OnMouseDown",Begin);input:SetScript("OnMouseUp",Release)
  thumb:SetScript("OnMouseDown",Begin);thumb:SetScript("OnMouseUp",Release)
  shell:HookScript("OnHide",function() shell:FinishDrag(false) end)
  shell.slider,shell.track,shell.thumb,shell.progress=input,track,thumb,progress;shell:SetValue(min)

  return shell
 end
 local slider=CreateFrame("Slider",nil,shell);slider:SetPoint("LEFT",0,0);slider:SetPoint("RIGHT",0,0);slider:SetHeight(T.sliderHitHeight)
 slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(min or 0,max or 100);slider:SetValueStep(step or 1);slider:SetObeyStepOnDrag(true)
 local track=CreateFrame("Frame",nil,slider);track:SetFrameLevel(slider:GetFrameLevel()-2);track:SetPoint("LEFT");track:SetPoint("RIGHT");track:SetHeight(T.sliderTrackHeight);C.Panel(track,"surfaceHigh","sliderTrackRadius")
 local progress=CreateFrame("Frame",nil,slider);progress:SetFrameLevel(slider:GetFrameLevel()-1);progress:SetPoint("LEFT");progress:SetHeight(T.sliderTrackHeight);C.Panel(progress,"accent","sliderTrackRadius")
 local thumb=slider:CreateTexture(nil,"OVERLAY");thumb:SetTexture(130871);thumb:SetVertexColor(unpack(T.accent));thumb:SetSize(T.sliderThumbWidth,T.sliderThumbHeight);slider:SetThumbTexture(thumb)
 local function UpdateProgress(value)
  local low,high=slider:GetMinMaxValues()
  progress:SetWidth(high>low and slider:GetWidth()*(value-low)/(high-low) or 0)
  progress:SetAlpha(value>low and 1 or 0)
 end
 function shell:SetValue(value) self.updating=true;slider:SetValue(value);self.updating=false end
 function shell:GetValue() return slider:GetValue() end
 function shell:IsDragging() return false end
 function shell:FinishDrag() end
 slider:SetScript("OnValueChanged",function(_,value)
  UpdateProgress(value);shell.value=value;if not shell.updating and onChange then onChange(value) end
 end)
 slider:SetScript("OnSizeChanged",function() UpdateProgress(slider:GetValue()) end)
 shell.slider,shell.track,shell.thumb,shell.progress=slider,track,thumb,progress;shell:SetValue(min or 0)
 UpdateProgress(slider:GetValue())

 return shell
end
function C.Segmented(parent,width,entries,onChange,options)
 options=options or {}
 local frame=CreateFrame("Frame",nil,parent)
 local setWidth,setHeight=frame.SetWidth,frame.SetHeight
 local widthRef,heightRef=width,options.height or "segmentHeight"
 frame.buttons={};frame.selection=C.Selection(frame,{radius=options.radius or "segmentRadius"})
 frame.fill=C.Panel(frame,"surfaceContainer",options.radius or "segmentRadius")
 for _,entry in ipairs(entries) do
  local value=entry.value;if value==nil then value=entry[1] end
  local button=C.Button(frame,entry.label or entry[2],100,function() frame:SetValue(value);if onChange then onChange(frame.value) end end,{variant="compact",radius=options.radius or "segmentRadius",selectionFill=options.selectionMotion==false})
  button.value=value
  button:SetLabelStyle(options.fontSize or "compactSize",options.lineHeight or "compactLineHeight")
  if options.wordWrap~=nil then button.label:SetWordWrap(options.wordWrap) end
  if entry.icon then button.icon=C.Glyph(button,entry.icon,14);button.icon:SetPoint("LEFT",10,0);button.label:ClearAllPoints();button.label:SetPoint("LEFT",button.icon,"RIGHT",6,0) end
  frame.buttons[#frame.buttons+1]=button
 end
 function frame:SetValue(value)
  self.value=value
  local selected
  for _,button in ipairs(self.buttons) do button:SetActive(button.value==value);if button.active then selected=button end end
  if selected and options.selectionMotion~=false then
   self.selection:Select(selected.segmentX,-(self:GetHeight()-selected:GetHeight())/2,selected:GetWidth(),selected:GetHeight(),self:IsVisible())
  else self.selection:Clear() end
 end
 function frame:Layout(newWidth,newHeight)
  if newWidth~=nil then widthRef=newWidth end
  if newHeight~=nil then heightRef=newHeight end
  local padding,gap=Value(options.padding or "segmentPadding"),Value(options.gap or "segmentGap")
  local w,h=Value(widthRef),Value(heightRef)
  setWidth(self,w);setHeight(self,h)
  local itemWidth=(w-padding*2-math.max(0,#self.buttons-1)*gap)/#self.buttons
  for i,button in ipairs(self.buttons) do
   button.segmentX=padding+(i-1)*(itemWidth+gap)
   button:SetSize(itemWidth,h-padding*2);button:ClearAllPoints();button:SetPoint("LEFT",button.segmentX,0)
   if not button.icon then button.label:SetWidth(itemWidth-Value(options.textInset or "segmentTextInset")*2) end
  end
  self:SetValue(self.value)
 end
 function frame:SetWidth(value) self:Layout(value) end
 function frame:SetHeight(value) self:Layout(nil,value) end

 frame:HookScript("OnShow",function(self) self:SetValue(self.value) end)
 frame.LayoutFonts=frame.Layout;UI.fontLayouts[frame]=true
 frame:Layout()
 return frame
end
-- Rounded rail entry with a straight 3 x 18 selection mark.
function C.Navigation(parent,text,width,action,iconName,options)
 local button=Button(parent,text,width,action,{height="navigationHeight",radius="navigationRadius",fontSize="navigationFontSize",lineHeight="navigationLineHeight"},true)
 button.label:ClearAllPoints();button.label:SetPoint("LEFT",iconName and T.navigationIconTextInset or T.navigationInset,0)
 if iconName then button.icon=C.Glyph(button,iconName,T.railIconSize);button.icon:SetPoint("LEFT",T.navigationInset,0);button.icon:SetSelected(false) end
 button.mark=button:CreateTexture(nil,"ARTWORK");button.mark:SetColorTexture(unpack(T.accent));button.mark:SetSize(T.selectionMarkWidth,T.selectionMarkHeight);button.mark:SetPoint("LEFT",T.selectionMarkInset,0);button.mark:Hide()
 local setActive=button.SetActive
 function button:SetActive(value) setActive(self,value);M:Selection(self.mark,value==true) end
 Hook(button,"OnHide",function(self) M:Selection(self.mark,self.active==true,0) end)
 button:SetTextColors("muted","text","onSecondaryContainer")
 if options then button:SetStyle(options) end

 C.Style(button,{recipe=options and options.recipe or "navigation",legacy=true,trackNative=true,slots={root=button,label=button.label,surface=button.fill,hover=button.hover,icon=button.icon,mark=button.mark}})
 return button
end
-- A generic text tooltip; the caller supplies its content.
function C.Tooltip(parent,width)
 local tip=CreateFrame("Frame",nil,parent or UIParent);tip:SetSize(Value(width or "tooltipWidth"),40);tip:SetFrameStrata("TOOLTIP");tip:SetClampedToScreen(true)
 C.Shadow(tip,"tooltipRadius");C.Panel(tip,"raised","tooltipRadius");tip.lines={};tip.count=0;tip:Hide()
 function tip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor;self.count=0;for _,line in ipairs(self.lines) do line:Hide() end end
 function tip:AddLine(text,r,g,b,wrap)
  self.count=self.count+1;local line=self.lines[self.count]
  if not line then line=C.Text(self,"","tooltipFontSize","text",self:GetWidth()-T.tooltipPadding*2,"tooltipLineHeight");self.lines[self.count]=line end
  UI:SetText(line,text);UI:Color(line,(r or g or b) and {r or T.text[1],g or T.text[2],b or T.text[3],1} or T.text);line:SetWordWrap(wrap~=false);line:Show()
 end
 local function Layout(self)
  local y=T.tooltipPadding;for i=1,self.count do local line=self.lines[i];line:ClearAllPoints();line:SetPoint("TOPLEFT",T.tooltipPadding,-y);y=y+line:GetStringHeight()+T.tooltipLineGap end
  self:SetHeight(y+T.tooltipBottom);self:ClearAllPoints();self:SetPoint(self.anchor=="ANCHOR_TOP" and "BOTTOM" or "TOPLEFT",self.owner,self.anchor=="ANCHOR_TOP" and "TOP" or "BOTTOMRIGHT",0,T.tooltipOffset)
 end
 local show=tip.Show
 function tip:Show() Layout(self);show(self);M:Alpha(self,1,T.feedbackDuration,.25) end

 tip.LayoutFonts=function(self) if self.owner then Layout(self) end end;UI.fontLayouts[tip]=true
 function tip:IsOwned(owner) return self.owner==owner and self:IsShown() end
 function tip:LeaveOwner(owner) if self.owner==owner then self:Hide() end end
 tip:SetScript("OnHide",function(self) M:Stop(self);self:SetAlpha(1);self.owner=nil end)
 return tip
end
function C.Modal(parent,width,height,title,onClose)
 parent=parent or UI.parent
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(Value(width or "modalWidth"),Value(height or "modalHeight"))
 frame:SetPoint("CENTER",parent,"CENTER",0,0)
 frame:SetFrameStrata("DIALOG");frame:EnableMouse(true);frame:SetClampedToScreen(true)
 local function Close() if onClose then onClose(frame) else frame:Hide() end end
 local scrim=CreateFrame("Button",nil,parent);scrim:SetAllPoints(parent);scrim:SetFrameStrata("DIALOG")
 scrim:SetFrameLevel(frame:GetFrameLevel());frame:SetFrameLevel(scrim:GetFrameLevel()+1)
 C.Fill(scrim,"modalScrim");scrim:SetScript("OnClick",Close);scrim:Hide();frame.scrim=scrim
 C.Shadow(frame,"windowRadius");C.Panel(frame,"surfaceHigh","windowRadius")
 frame.title=C.Text(frame,title,"font24","text",(Value(width or "modalWidth"))-T.modalTitleReserve);C.DefaultLineHeight(frame.title,"line32",true);frame.title:SetPoint("TOPLEFT",T.modalPadding,-T.modalPadding);frame.title:SetWordWrap(false)
 frame.close=C.IconButton(frame,"close",T.modalCloseSize,Close)
 frame.close:SetPoint("TOPRIGHT",-T.modalPadding,-T.modalPadding)
 frame.content=CreateFrame("Frame",nil,frame);frame.content:SetPoint("TOPLEFT",T.modalPadding,-T.modalContentTop);frame.content:SetPoint("BOTTOMRIGHT",-T.modalPadding,T.modalPadding)
 frame:SetScript("OnShow",function() scrim:Show() end)
 frame:SetScript("OnHide",function(self) scrim:Hide();M:FinishPlacement(self) end)

 frame:Hide()
 return frame
end
Library.AttachStyles(UI,C)
return C
end

function Library.Context:RoundIcon(icon,texture)
 if texture~=nil then icon._lycheeMaskTexture=texture end
 if icon._lycheeMask then
  if texture~=nil then icon._lycheeMask:SetTexture(texture,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE") end
  return
 end
 local mask=icon:GetParent():CreateMaskTexture(nil,"ARTWORK")
 -- Same mask sampler contract as Blizzard's portrait/action-button masks.
 local function Apply(target) target:SetTexture(icon._lycheeMaskTexture or self.Theme.media.."icon-mask.tga","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE") end
 Apply(mask);
 mask:SetAllPoints(icon);icon:AddMaskTexture(mask);icon._lycheeMask=mask
end
local function ApplyGameCrop(context,icon,left,right,top,bottom)
 local crop=context.Theme.iconCrop;local width,height=right-left,bottom-top
 icon:SetTexCoord(left+width*crop,right-width*crop,top+height*crop,bottom-height*crop)
end
function Library.Context:SetGameTexture(icon,file,left,right,top,bottom)
 self:RoundIcon(icon);icon:SetTexture(file)
 ApplyGameCrop(self,icon,left or 0,right or 1,top or 0,bottom or 1)
end
function Library.Context:SetGameAtlas(icon,name)
 self:RoundIcon(icon);icon:SetAtlas(name)
 local info=C_Texture.GetAtlasInfo(name)
 if info then
  ApplyGameCrop(self,icon,info.leftTexCoord,info.rightTexCoord,info.topTexCoord,info.bottomTexCoord)
 end
end
local function SameIconChannel(value,target,byte)
 -- Raw float readback can straddle a half-byte rounding boundary such as .9.
 return math.abs(value-target)<=.000001 or math.floor(value*255+.5)==byte
end
function Library.Context:SetIconState(icon,selected,hovered)
 icon=icon._lycheeTexture or icon
 local gray=not selected
 if icon:IsDesaturated()~=gray then icon:SetDesaturated(gray) end
 local value=selected and 1 or hovered and self.Theme.iconHoverTint or self.Theme.iconIdleTint
 local byte=math.floor(value*255+.5)
 local r,g,b=icon:GetVertexColor()
 if not SameIconChannel(r,value,byte) or not SameIconChannel(g,value,byte) or not SameIconChannel(b,value,byte) then icon:SetVertexColor(value,value,value) end
 local alpha=selected and 1 or hovered and self.Theme.iconHoverAlpha or self.Theme.iconIdleAlpha
 if not SameIconChannel(icon:GetAlpha(),alpha,math.floor(alpha*255+.5)) then icon:SetAlpha(alpha) end
end

