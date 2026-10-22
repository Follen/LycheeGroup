local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
function Library.CreateComponents(UI)
local T,M=UI.Theme,UI.Motion
local C={listRightInset=T.scrollWidth+T.scrollGap}
local function Hook(frame,script,callback) frame:HookScript(script,callback) end
local editLineMeasure
local function FontStyle(label)
 local style=UI.fontStyles[label]
 if not style then style={};UI.fontStyles[label]=style end
 return style
end
function C.SetFont(label,size,flags)
 local style=FontStyle(label)
 style.size,style.flags=size or T.bodySize,flags or ""
 return label:SetFont(T.font,(style.size+T.fontSizeDelta)*UI.fontScale,style.flags)
end
local function ApplyLineHeight(label,height,singleLine)
 height=(height+T.lineHeightDelta)*UI.fontScale
 local kind=label:GetObjectType()
 if kind~="FontString" and kind~="EditBox" then error("LycheeUI.SetLineHeight expects a FontString or EditBox, got "..kind,2) end
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
 if singleLine then label:SetHeight(height);label:SetJustifyV("MIDDLE") end
end
function C.SetLineHeight(label,height,singleLine)
 local style=FontStyle(label)
 style.lineHeight,style.singleLine=height,singleLine
 ApplyLineHeight(label,height,singleLine)
 style.appliedHeight=singleLine and label:GetHeight() or nil
end
function C.RefreshFonts()
 for label,style in pairs(UI.fontStyles) do
  if not UI.options.ownsText or UI.options.ownsText(label) then
   if style.size then label:SetFont(T.font,(style.size+T.fontSizeDelta)*UI.fontScale,style.flags) end
   if style.lineHeight then
    -- A caller may have changed a former single-line label to automatic height.
    local fixed=style.singleLine and label:GetHeight()==style.appliedHeight
    ApplyLineHeight(label,style.lineHeight,fixed)
    style.appliedHeight=fixed and label:GetHeight() or nil
   end
  end
 end
end
function C.Text(parent,text,size,color,width,lineHeight)
 local label=parent:CreateFontString(nil,"OVERLAY")
 C.SetFont(label,size);label:SetShadowOffset(0,0);label:SetJustifyH("LEFT")
 if width then label:SetWidth(width) end
 UI:Color(label,color or T.text);UI:SetText(label,text)
 if lineHeight then C.SetLineHeight(label,lineHeight) end
 return label
end
function C.Fill(parent,color,layer)
 local texture=parent:CreateTexture(nil,layer or "BACKGROUND")
 texture:SetAllPoints();texture:SetColorTexture(unpack(color));return texture
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
   if frame==UI.frame then M:Stop("presence");M:CapturePosition();M:SetPresence(1) end
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
function C.Panel(parent,color,radius,inset,layer)
 radius,inset=radius or T.panelRadius,inset or 0
 local regions={};local panel={regions=regions,alpha=1}
 for i=1,7 do
  local region=parent:CreateTexture(nil,layer or "BACKGROUND",nil,-7)
  regions[i]=region
  if i>=4 then region.corner=true;region:SetTexture(T.media.."rounded-corner.tga")
  else region:SetTexture(130871) end
 end
 local placedRadius
 local paintedR,paintedG,paintedB,paintedAlpha
 local function Place()
  local width,height=parent:GetWidth(),parent:GetHeight()
  local r=math.max(0,math.min(radius,(width-inset*2)/2,(height-inset*2)/2))
  -- The slices already stretch with their parent; only a changed corner
  -- radius needs new geometry while a selection indicator changes width.
  if r==placedRadius then return end
  placedRadius=r
  for _,region in ipairs(regions) do region:ClearAllPoints() end
  regions[1]:SetPoint("TOPLEFT",inset+r,-inset);regions[1]:SetPoint("BOTTOMRIGHT",-inset-r,inset)
  for i,side in ipairs(panelSides) do
   local edge=regions[i+1];edge:SetWidth(r);edge:SetPoint("TOP"..side,side=="LEFT" and inset or -inset,-inset-r);edge:SetPoint("BOTTOM"..side,side=="LEFT" and inset or -inset,inset+r)
  end
  for i,v in ipairs(panelCorners) do
   local corner=regions[i+3];corner:SetSize(r,r);corner:SetTexCoord(v[2],v[3],v[4],v[5]);corner:SetPoint(v[1],v[1]:find("LEFT") and inset or -inset,v[1]:find("TOP") and -inset or inset)
  end
 end
 function panel:SetColor(value)
  self.color=value
  -- All slices use white image textures and the same vertex tint pipeline.
  -- Mixing SetColorTexture centers with tinted image corners changes RGB
  -- compositing in the client, even when their final alpha is identical.
  local r,g,b=value[1],value[2],value[3]
  local composed=self.alpha*(value[4] or 1)
  if r~=paintedR or g~=paintedG or b~=paintedB then
   -- Vertex alpha and Texture:SetAlpha share the same native value. Submit
   -- the final RGBA together instead of resetting alpha and writing it again.
   for _,region in ipairs(regions) do region:SetVertexColor(r,g,b,composed) end
   paintedR,paintedG,paintedB,paintedAlpha=r,g,b,composed
  else self:SetAlpha(self.alpha) end
 end
 function panel:SetColorTexture(...) self:SetColor({...}) end
 function panel:SetAlpha(value)
  self.alpha=value
  local composed=value*(self.color[4] or 1)
  if composed~=paintedAlpha then
   for _,region in ipairs(regions) do region:SetAlpha(composed) end
   paintedAlpha=composed
  end
 end
 function panel:GetAlpha() return self.alpha end
 function panel:SetShown(value)
  value=not not value
  for _,region in ipairs(regions) do if region:IsShown()~=value then region:SetShown(value) end end
 end
 function panel:IsShown() return regions[1]:IsShown() end
 function panel:Show() self:SetShown(true) end
 function panel:Hide() self:SetShown(false) end
 function panel:SetRadius(value) radius=value;Place() end
 Hook(parent,"OnSizeChanged",Place);Place();panel:SetColor(color or T.panel)
 return panel
end
-- Nine fixed slices supply soft shadows without an update driver.
function C.Shadow(parent,radius)
 radius=radius or T.windowRadius
 local closest=28;for _,candidate in ipairs({12,16,24,28}) do if math.abs(candidate-radius)<math.abs(closest-radius) then closest=candidate end end
 local extent=24;local corner=closest+extent;local cut=corner/128
 local uv={0,cut,1-cut,1};local regions={}
 for y=1,3 do for x=1,3 do
  local texture=parent:CreateTexture(nil,"BACKGROUND",nil,-8)
  texture:SetTexture(T.media.."shadow-"..closest..".tga");texture:SetTexCoord(uv[x],uv[x+1],uv[y],uv[y+1]);regions[#regions+1]=texture
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
 local shadow={regions=regions}
 function shadow:SetAlpha(value) for _,texture in ipairs(regions) do texture:SetAlpha(value) end end
 function shadow:SetShown(value) for _,texture in ipairs(regions) do texture:SetShown(value) end end
 function shadow:Show() self:SetShown(true) end
 function shadow:Hide() self:SetShown(false) end
 return shadow
end
local function ButtonBase(parent,text,width,action)
 local b=CreateFrame("Button",nil,parent);b:SetSize(width or 100,T.buttonHeight)
 b.label=C.Text(b,text,14);C.SetLineHeight(b.label,20,true);b.label:SetPoint("CENTER")
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
  self:SetEnabled(available);self:SetAlpha(available and 1 or .38)
  if not available then self._inside=nil;self._pressed=nil;UI:CloseMenuFor(self) end
  self:RefreshStyle(true)
 end
 return b
end
function C.Button(parent,text,width,action,options)
 local b=ButtonBase(parent,text,width,action)
 b.fill=C.Panel(b,T.primary,T.buttonRadius);b.fill:Hide()
 b.hover=C.Panel(b,T.rowHover,T.buttonRadius);b.hover:Hide()
 b.hoverColor=T.rowHover
 function b:RefreshStyle(immediate)
  local enabled=self:IsEnabled()
  local inside,pressed=enabled and self._inside,enabled and self._pressed
  local duration=not immediate and .12 or nil
  local colors=self.surfaceColors
  local darkChoice=self.isChoice and self.surfaceVariant=="dark"
  local fill=self.primary and (pressed and T.primaryPressed or inside and T.primaryHover or T.primary)
   or self.isChoice and (darkChoice and T.surfaceLow or T.selectBackground)
   or self.active and (self.variant=="text" and T.transparent or T.secondaryContainer)
   or colors and (pressed and colors[3] or inside and colors[2] or colors[1]) or T.secondaryContainer
  local permanent=self.primary or self.isChoice or colors~=nil
  local selected=self.active and self.selectionFill~=false
  if permanent then
   self.fill._selMotion=nil;self.fill:Show();self.fill:SetAlpha(1)
   M:Color(self.fill,fill,duration)
  else
   self.fill:SetColor(fill)
   if immediate then
    M:Stop(self.fill);self.fill._selMotion=selected==true;self.fill:SetShown(selected);self.fill:SetAlpha(selected and 1 or 0)
   else M:Selection(self.fill,selected==true,.14) end
  end
  local hovered=(not (self.primary or self.isChoice or self.active or colors) or self.isChoice and not self.expanded) and (pressed or inside)
  if hovered then
   local state=self.isChoice and not darkChoice and (pressed and T.selectPressed or T.selectHover)
    or pressed and (self.pressedColor or T.pressed) or self.hoverColor
   M:Stop(self.hover);self.hover:SetColor(state)
   self.hover:Show();if immediate then self.hover:SetAlpha(1) else M:Alpha(self.hover,1,.12) end
  else M:Stop(self.hover);self.hover:SetAlpha(0);self.hover:Hide() end
  local textColor=self.primary and T.onPrimary or self.active and (self.selectedTextColor or T.onSecondaryContainer)
   or inside and (self.hoverTextColor or T.text) or self.textColor or T.text
  UI:Color(self.label,textColor)
  if self.icon and self.icon.SetSelected and self._iconSelection~=false then self.icon:SetSelected(self.active,inside) end
  if self.focus then self.focusInner:SetColor(darkChoice and T.surfaceLow or T.selectBackground);self.focus:SetShown(self.expanded==true);self.focusInner:SetShown(self.expanded==true) end
 end
 function b:SetPrimary(value) self.primary=value==true;self:RefreshStyle(true) end
 function b:SetActive(value)
  value=value==true;if self.active==value then return end
  self.active=value;self:RefreshStyle(not self:IsVisible())
 end
 function b:SetSurfaceColors(rest,hover,pressed) self.surfaceColors=rest and {rest,hover or rest,pressed or hover or rest} or nil;self:RefreshStyle(true) end
 function b:SetTextColors(rest,hover,selected) self.textColor,self.hoverTextColor,self.selectedTextColor=rest,hover,selected;self:RefreshStyle(true) end
 function b:SetFeedbackColors(hover,pressed) self.hoverColor,self.pressedColor=hover or T.rowHover,pressed;self:RefreshStyle(true) end
 function b:SetRadius(radius)
  self.radius=radius;self.fill:SetRadius(radius);self.hover:SetRadius(radius)
  if self.focus then self.focus:SetRadius(radius);self.focusInner:SetRadius(math.max(0,radius-1)) end
 end
 function b:SetLabelStyle(size,lineHeight)
  C.SetFont(self.label,size);C.SetLineHeight(self.label,lineHeight,true)
 end
 function b:SetVariant(variant)
  self.variant=variant;self.primary=variant=="primary";self.surfaceColors=nil
  self.hoverColor,self.pressedColor=T.rowHover,nil
  self.textColor,self.hoverTextColor,self.selectedTextColor=T.text,T.text,T.onSecondaryContainer
  self:SetHeight(T.buttonHeight);self:SetRadius(T.buttonRadius);self:SetLabelStyle(14,20)
  if variant=="compact" then
   self:SetHeight(T.compactHeight);self:SetRadius(T.compactRadius);self:SetLabelStyle(T.compactSize,T.compactLineHeight);self.textColor=T.muted
  elseif variant=="tonal" then self.surfaceColors={T.secondaryContainer,T.refreshHover,T.secondaryPressed}
  elseif variant=="text" then
   self.surfaceColors={T.transparent,T.transparent,T.transparent};self.textColor,self.hoverTextColor,self.selectedTextColor=T.muted,T.brand,T.brand
  end
  self:RefreshStyle(true)
 end
 function b:SetStyle(style)
  if style.selectionFill~=nil then self.selectionFill=style.selectionFill end
  if style.variant then self:SetVariant(style.variant) end
  if style.height then self:SetHeight(style.height) end
  if style.radius then self:SetRadius(style.radius) end
  if style.fontSize or style.lineHeight then
   local font=UI.fontStyles[self.label]
   self:SetLabelStyle(style.fontSize or font.size,style.lineHeight or font.lineHeight)
  end
  if style.surfaceColors then self:SetSurfaceColors(unpack(style.surfaceColors)) end
  if style.hoverColor or style.pressedColor then self:SetFeedbackColors(style.hoverColor or self.hoverColor,style.pressedColor or self.pressedColor) end
  if style.textColor or style.hoverTextColor or style.selectedTextColor then self:SetTextColors(style.textColor or self.textColor,style.hoverTextColor or self.hoverTextColor,style.selectedTextColor or self.selectedTextColor) end
  if style.selectionFill~=nil then self:RefreshStyle(true) end
 end
 function b:SetExpanded(value)
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
   self.focus=C.Panel(self,T.focusBorder,self.radius or T.fieldRadius)
   self.focusInner=C.Panel(self,T.selectBackground,math.max(0,(self.radius or T.fieldRadius)-1),1)
   for _,region in ipairs(self.focus.regions) do region:SetDrawLayer("BACKGROUND",-6) end
   for _,region in ipairs(self.focusInner.regions) do region:SetDrawLayer("BACKGROUND",-5) end
  end
  self:RefreshStyle(true)
 end
 b.hover:SetAlpha(0)
 if options then b:SetStyle(options) end
 return b
end
-- Native buttons stay available to callers; the library owns their appearance.
function C.IconButton(parent,icon,size,action,options)
 options=options or {}
 local button=C.Button(parent,"",size or T.buttonHeight,action,options)
 button._iconSelection=false
 button:SetHeight(options.height or size or T.buttonHeight);button.label:Hide()
 local iconSize=options.iconSize or 20
 if icon then button.icon=C.Glyph(button,icon,iconSize)
 else button.icon=C.Icon(button,iconSize) end
 button.icon:SetPoint("CENTER")
 return button
end
function C.Surface(parent,options)
 options=options or {}
 local floating=options.variant=="floating"
 local surface=CreateFrame("Frame",nil,parent);surface:SetAllPoints(parent);surface:EnableMouse(false)
 surface:SetFrameLevel(math.max(0,parent:GetFrameLevel()-1))
 surface.restColor=options.color or (floating and T.floatingSurface or T.panel)
 surface.hoverColor=options.hoverColor or (floating and T.floatingHover or surface.restColor)
 surface.fill=C.Panel(surface,surface.restColor,options.radius or (floating and T.floatingRadius or T.panelRadius))
 function surface:SetHovered(value) self.hovered=value==true;self.fill:SetColor(self.hovered and self.hoverColor or self.restColor) end
 function surface:SetColors(rest,hover) self.restColor,self.hoverColor=rest,hover or rest;self:SetHovered(self.hovered) end
 return surface
end
function C.CheckMark(parent,color)
 local mark=CreateFrame("Frame",nil,parent);mark:SetSize(16,20);mark.strokes={}
 for _,stroke in ipairs({{5,-3,-1,-math.pi/4},{9,1.3,.5,math.pi/4}}) do
  local line=mark:CreateTexture(nil,"ARTWORK");line:SetSize(stroke[1],1.5)
  line:SetPoint("CENTER",stroke[2],stroke[3]);line:SetRotation(stroke[4]);mark.strokes[#mark.strokes+1]=line
 end
 function mark:SetColor(value) for _,line in ipairs(self.strokes) do line:SetColorTexture(unpack(value)) end end
 mark:SetColor(color or T.onSecondaryContainer)
 return mark
end
function C.Checkbox(parent,onChange,options)
 options=options or {}
 local size=options.size or 32;local boxSize=options.boxSize or 18
 local check=CreateFrame("CheckButton",nil,parent);check:SetSize(size,size)
 check.fill=C.Panel(check,T.surfaceHigh,options.radius or 5,(size-boxSize)/2)
 check.mark=C.CheckMark(check,T.onPrimary);check.mark:SetPoint("CENTER")
 function check:RefreshStyle()
  local inside=self:IsEnabled() and self.hovered
  self.fill:SetColor(self:GetChecked() and (inside and T.primaryHover or T.primary) or (inside and T.secondaryContainer or T.surfaceHigh))
  self.mark:SetShown(self:GetChecked()==true)
 end
 function check:SetValue(value) self:SetChecked(value==true);self:RefreshStyle() end
 function check:GetValue() return self:GetChecked()==true end
 function check:SetAvailable(value) self:SetEnabled(value);self:SetAlpha(value and 1 or .38);self:RefreshStyle() end
 check:SetScript("OnEnter",function(self) self.hovered=true;self:RefreshStyle() end)
 check:SetScript("OnLeave",function(self) self.hovered=nil;self:RefreshStyle() end)
 check:SetScript("OnHide",function(self) self.hovered=nil;self:RefreshStyle() end)
 check:SetScript("OnClick",function(self) if self:IsEnabled() and not UI:IsHiding() then self:RefreshStyle();if onChange then onChange(self:GetValue(),self) end end end)
 check:SetValue(false)
 return check
end
-- Visual field only: native/registered EditBoxes can be leased into this shell.
function C.Notice(parent,width,onClose)
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(width,40);frame.fill=C.Panel(frame,T.notice,12)
 frame.text=C.Text(frame,"",14,T.noticeText,width-52,20);frame.text:SetPoint("LEFT",12,0);frame.text:SetJustifyH("LEFT");frame.text:SetWordWrap(true)
 frame.close=C.IconButton(frame,"close",24,function() if onClose then onClose(frame) else frame:Hide() end end,{iconSize=12})
 frame.close:SetPoint("RIGHT",-8,0)
 function frame:SetMessage(message,actionWidth)
  message=message or "";self.text:SetWidth(self:GetWidth()-52-(actionWidth or 0));UI:SetText(self.text,message)
  self:SetHeight(math.max(40,math.ceil(self.text:GetStringHeight())+16));self:SetShown(message~="")
 end
 frame:Hide();return frame
end
function C.Field(parent,width,height,search,variant)
 local shell=CreateFrame("Frame",nil,parent);shell:SetSize(width,height or T.fieldHeight)
 local radius=search and 24 or T.fieldRadius
 local baseColor=variant=="modal" and T.surfaceLow or T.field
 local hoverColor=variant=="modal" and T.surfaceContainer or T.surfaceHighest
 local focusColor=variant=="modal" and T.field or T.fieldFocus
 shell.focus=C.Panel(shell,T.focusBorder,radius);shell.focus:Hide()
 shell.fill=C.Panel(shell,baseColor,radius)
 function shell:SetFocused(focused,hovered)
  self.focused=focused==true;self.hovered=hovered==true
  self.focus:SetShown(self.focused)
  self.fill:SetColor(self.focused and focusColor or self.hovered and hoverColor or baseColor)
  -- 1px inner ring, without a constant bright border or outer glow.
  self.fill:Hide()
  if self.inner then self.inner:Hide() end
  if self.focused then
   self.focus:SetColor(T.focusBorder)
   if not self.inner then
    self.inner=C.Panel(self,focusColor,math.max(0,radius-1),1)
    -- Texture batching does not preserve creation order within a shared sublayer.
    for _,region in ipairs(self.inner.regions) do region:SetDrawLayer("BACKGROUND",-6) end
   end
   self.inner:Show()
  else self.fill:Show() end
 end
 function shell:SetBackdropColor(...) self.fill:SetColorTexture(...) end
 function shell:SetBackdropBorderColor(r,g,b,a) self.focus:SetColorTexture(r,g,b,a);self.focus:SetShown((a or 1)>0) end
 shell:SetScript("OnHide",function(self) self:SetFocused(false) end)
 return shell
end
function C.Edit(parent,width,height,multiline,search,variant)
 local shell=C.Field(parent,width,height,search,variant)
 local function Surface(focused,hovered) shell:SetFocused(focused,hovered) end
 local scroll=multiline and CreateFrame("ScrollFrame",nil,shell) or nil
 local box=CreateFrame("EditBox",nil,scroll or shell)
 C.SetFont(box,14);box:SetShadowOffset(0,0);box:SetTextColor(unpack(T.text));box:SetAutoFocus(false)
 box:SetJustifyV(multiline and "TOP" or "MIDDLE");box:SetMultiLine(multiline==true);box:SetMaxLetters(0)
 if scroll then
  scroll:SetPoint("TOPLEFT",12,-10);scroll:SetPoint("BOTTOMRIGHT",-12,10)
  box:SetWidth(width-24);box:SetHeight((height or 80)-20);scroll:SetScrollChild(box)
  Hook(shell,"OnSizeChanged",function() box:SetWidth(math.max(1,shell:GetWidth()-24)) end)
  box:SetScript("OnCursorChanged",function(_,_,y,_,cursorHeight)
   local top=scroll:GetVerticalScroll();y=-y
   if y<top then scroll:SetVerticalScroll(y) elseif y+cursorHeight>top+scroll:GetHeight() then scroll:SetVerticalScroll(y+cursorHeight-scroll:GetHeight()) end
  end)
  scroll:EnableMouseWheel(true);scroll:SetScript("OnMouseWheel",function(self,delta) self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*28))) end)
 else box:SetPoint("TOPLEFT",12,-4);box:SetPoint("BOTTOMRIGHT",-12,4) end
 box:SetScript("OnEditFocusGained",function() Surface(true) end)
 box:SetScript("OnEditFocusLost",function() Surface(false) end)
 box:SetScript("OnEnter",function() if not box:HasFocus() then Surface(false,true) end end)
 box:SetScript("OnLeave",function() if not box:HasFocus() then Surface(false) end end)
 box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
 box:SetScript("OnHide",function(self) self:ClearFocus();Surface(false) end)
 shell.box=box;shell.scroll=scroll
 function shell:SetPlaceholder(text)
  if not self.placeholder then
   self.placeholder=C.Text(box,"",14,T.muted,width-24);C.SetLineHeight(self.placeholder,20,not multiline);self.placeholder:SetPoint(multiline and "TOPLEFT" or "LEFT",0,0);self.placeholder:SetWordWrap(multiline==true)
   Hook(box,"OnTextChanged",function() self.placeholder:SetShown(box:GetText()=="") end)
  end
  UI:SetText(self.placeholder,text);self.placeholder:SetShown(box:GetText()=="")
 end
 UI.inputs[#UI.inputs+1]=box
 return shell
end
function C.Number(parent,width,height,onChange)
 local shell=C.Edit(parent,width,height or T.fieldHeight)
 shell.box:SetNumeric(true)
 shell.box:SetScript("OnTextChanged",function() if onChange then onChange(shell.box:GetText()) end end)
 shell:SetPlaceholder(UI.L.any or (GetLocale()=="zhCN" and "不限" or "Any"))
 return shell
end
function C.ChoiceTrigger(parent,width,action,options)
 local b=C.Button(parent,"",width,action)
 b:SetHeight(T.fieldHeight);b.isChoice=true;b:SetRadius(T.fieldRadius);b.fill:SetColor(T.selectBackground);b.fill:Show()
 b.label:ClearAllPoints();b.label:SetPoint("LEFT",14,0);b.label:SetWidth(width-46);b.label:SetWordWrap(false)
 Hook(b,"OnSizeChanged",function(self,value) self.label:SetWidth(math.max(0,value-46)) end)
 for i=1,2 do local arm=b:CreateTexture(nil,"ARTWORK");arm:SetColorTexture(unpack(T.muted));arm:SetSize(5,1.5);arm:SetPoint("CENTER",b,"RIGHT",i==1 and -20 or -16,0);arm:SetRotation(i==1 and -math.pi/4 or math.pi/4) end
 function b:SetValue(value,label) self.value=value;UI:SetText(self.label,label or tostring(value or "")) end
 function b:SetSurfaceVariant(value) self.surfaceVariant=value;self:RefreshStyle(true) end
 if options then b:SetStyle(options) end
 return b
end
function C.Choice(parent,width,entries,onChange)
 return C.ChoiceTrigger(parent,width,function(self)
  UI:OpenMenu(self,type(entries)=="function" and entries() or entries,function(value,label) self:SetValue(value,label);if onChange then onChange(value) end end,{kind="select",selectedValue=self.value})
 end)
end
function C.Check(parent,label,onChange)
 local b=ButtonBase(parent,label,180,function(self) self:SetValue(not self.value,true);if onChange then onChange(self.value) end end)
 b.label:ClearAllPoints();b.label:SetPoint("LEFT",56,0)
 local track=CreateFrame("Frame",nil,b);track:SetSize(44,26);track:SetPoint("LEFT")
 track.bg=C.Panel(track,T.surfaceHigh,13)
 local knob=CreateFrame("Frame",nil,track);knob:SetSize(16,16);knob:SetPoint("LEFT",5,0);knob.bg=C.Panel(knob,T.dim,10)
 function b:RefreshStyle(immediate)
  local enabled=self:IsEnabled()
  local inside,pressed=enabled and self._inside,enabled and self._pressed
  local color=self.value and (pressed and T.primaryPressed or inside and T.primaryHover or T.primary)
   or pressed and T.secondaryContainer or inside and T.surfaceHighest or T.surfaceHigh
  M:Color(track.bg,color,not immediate and .12 or nil)
 end
 function b:SetValue(value,animate)
  local old=self.value;self.value=value==true
  if self.stateLabel then UI:SetText(self.stateLabel,self.value and (UI.L.on or "On") or (UI.L.off or "Off")) end
  if old==self.value then return end
  self:RefreshStyle(true);knob.bg:SetColor(self.value and T.onPrimary or T.dim)
  local x,size=self.value and 21 or 5,self.value and 20 or 16
  knob:SetSize(size,size)
  if animate and old~=nil then M:Switch(knob,old and 21 or 5,x) else M:Stop(knob);knob:ClearAllPoints();knob:SetPoint("LEFT",track,"LEFT",x,0);knob._slideX=x end
 end
 b:SetValue(false);b.track=track;b.knob=knob
 Hook(b,"OnHide",function(self)
  M:Stop(knob)
  local x=self.value and 21 or 5
  if knob._slideX~=x then knob:ClearAllPoints();knob:SetPoint("LEFT",track,"LEFT",x,0);knob._slideX=x end
 end)
 return b
end

-- Remaining components below share this context and its finite motion driver.

-- Appearance for a native vertical scrollbar. Its owner supplies anchors,
-- content range and value callbacks; no extra driver or scroll state is added.
function C.ScrollBar(parent)
 local slider=CreateFrame("Slider",nil,parent);slider:SetOrientation("VERTICAL");slider:SetWidth(6)
 slider:SetValueStep(1);slider:SetObeyStepOnDrag(true);slider:SetMinMaxValues(0,0)
 local thumb=slider:CreateTexture(nil,"ARTWORK");thumb:SetColorTexture(unpack(T.accent));thumb:SetSize(6,28);slider:SetThumbTexture(thumb)
 slider.thumb=thumb
 return slider
end

-- Pixel virtual list: one clipped viewport, visible rows plus two spare rows.
-- offset stays an integer row index for older page callers; pixelOffset owns motion.
-- One passive visual layer moves; labels and button hit rectangles stay fixed.
function C.Selection(parent,options)
 options=options or {}
 local frame=CreateFrame("Frame",nil,parent);frame:SetFrameLevel(parent:GetFrameLevel()+1);frame:EnableMouse(false)
 frame.fill=C.Panel(frame,options.color or T.secondaryContainer,options.radius or 8)
 if options.mark then
  frame.mark=frame:CreateTexture(nil,"ARTWORK");frame.mark:SetColorTexture(unpack(T.accent));frame.mark:SetSize(3,T.selectionMarkHeight);frame.mark:SetPoint("LEFT",4,0)
 end
 frame:Hide()
 function frame:Select(x,y,width,height,animate)
  local visible=self:IsShown()
  if animate==false then
   M:Stop(self);self._selMotion=true;self:SetAlpha(1);self:Show()
  else M:Selection(self,true,.14) end
  M:Rect(self,x,y,width,height,visible and animate~=false and .16 or 0)
 end
 function frame:Clear(animate)
  if animate and self:IsShown() then
   if self._selMotion~=false then M:Stop(self);M:Selection(self,false,.14) end
  else M:FinishRect(self);M:Stop(self);self._selMotion=nil;self:Hide() end
 end
 frame:SetScript("OnHide",function(self) M:FinishRect(self);M:Stop(self);self._selMotion=nil end)
 Hook(parent,"OnHide",function() frame:Clear() end)
 return frame
end
function C.List(parent,width,height,rowHeight,onSelect,onHover)
 local list=CreateFrame("Frame",nil,parent);list:SetSize(width,height)
 list.rows={};list.offset=0;list.pixelOffset=0;list.rowHeight=rowHeight or 64;list.viewportHeight=height;list.gutter=C.listRightInset
 list.capacity=math.ceil(height/list.rowHeight);list.poolCapacity=list.capacity+2
 local clip=CreateFrame("ScrollFrame",nil,list);clip:SetPoint("TOPLEFT");clip:SetPoint("BOTTOMRIGHT",-C.listRightInset,0)
 local canvas=CreateFrame("Frame",nil,clip);canvas:SetSize(width-C.listRightInset,height+list.rowHeight*2);clip:SetScrollChild(canvas)
 list.clip,list.canvas=clip,canvas
 local slider=C.ScrollBar(list);slider:SetPoint("TOPRIGHT",0,-2);slider:SetPoint("BOTTOMRIGHT",0,2)
 list.slider=slider
 local function MaxOffset()
  local count=list.ids and #list.ids or 0
  -- Row spacing advances each slot; the final row has no trailing gap.
  local contentHeight=count>0 and (count-1)*list.rowHeight+list.rows[1]:GetHeight() or 0
  local overflow=contentHeight-list:GetHeight()
  -- Native scaled anchors can report 103.999984 for a 104px viewport.
  return overflow>.01 and overflow or 0
 end
 local function Release(row)
  if row.pressedKey then row.pressCancelled=true end
  row.key=nil;row.noteDot:Hide();row.alternate:Hide();row.hover:Hide();row.hover:SetAlpha(0)
  row._inside=nil;row._pressed=nil
  M:Stop(row.selected);M:Stop(row.mark);M:Stop(row.hover)
  row.selected._selMotion=nil;row.selected:SetAlpha(0);row.selected:Hide()
  row.mark._selMotion=nil;row.mark:SetAlpha(0);row.mark:Hide()
  UI:ReleaseRow(row)
 end
 local function Leave(row)
  row._inside=nil;row._pressed=nil;M:Stop(row.hover);row.hover:Hide();row.hover:SetAlpha(0)
  if list.idleTextColor then UI:Color(row.title,row.key==list.selectedKey and T.onSecondaryContainer or list.idleTextColor) end
  if row.symbol then UI:SetIconState(row.symbol,row.key==list.selectedKey,false) end
  if row.pressedKey then row.pressCancelled=true end
  UI:LeaveRow(row)
 end
 local function Highlight(row,immediate)
  local selected=row.key==list.selectedKey and list.selectionFill~=false
  local hovered=row:IsEnabled() and row._hitVisible and not selected and (row._inside or row._pressed)
  if hovered and list.hoverFill~=false then
   row.hover:SetColor(row._pressed and T.pressed or list.hoverColor or T.rowHover);row.hover:Show()
   if immediate then M:Stop(row.hover);row.hover:SetAlpha(1) else M:Alpha(row.hover,1,.10) end
  else M:Stop(row.hover);row.hover:SetAlpha(0);row.hover:Hide() end
  if list.idleTextColor then UI:Color(row.title,selected and T.onSecondaryContainer or hovered and T.text or list.idleTextColor) end
 end
 function list:Refresh(positionOnly)
  local ids=self.ids;local maximum=MaxOffset()
  local selectionRow,selectionY
  if self.offset~=math.floor((self.pixelOffset or 0)/self.rowHeight) then self.pixelOffset=self.offset*self.rowHeight end
  self.pixelOffset=math.max(0,math.min(self.pixelOffset or 0,maximum));self.offset=math.floor(self.pixelOffset/self.rowHeight)
  if self.scrollTarget and self.pixelOffset==maximum and self.scrollTarget>maximum then M:Stop(self);self.scrollTarget=maximum end
  self.updating=true
  local minimum,currentMaximum=slider:GetMinMaxValues()
  if minimum~=0 or currentMaximum~=maximum then slider:SetMinMaxValues(0,maximum) end
  slider:SetValue(self.pixelOffset);self.updating=false
  if slider:IsShown()~=(maximum>0) then slider:SetShown(maximum>0) end
  clip:SetVerticalScroll(self.pixelOffset-self.offset*self.rowHeight)
  for i,row in ipairs(self.rows) do
   local absolute=self.offset+i
   local key=ids and i<=self.capacity+1 and ids[self.offset+i] or nil
   local rebound=row.key~=key
   if rebound then Release(row);row.key=key;if UI.CloseMenuFor then UI:CloseMenuFor(self) end end
   row.alternate:SetShown(key~=nil and self.alternateRows~=false and absolute%2==0)
   if row:IsShown()~=(key~=nil) then row:SetShown(key~=nil) end
   if key and self.render then
    if rebound or not positionOnly then self.render(row,key) end
    local selected=key==self.selectedKey
    local duration=not self:IsVisible() and 0 or nil
    M:Selection(row.selected,selected and self.selectionFill~=false and not self.selectionMotion,duration);M:Selection(row.mark,selected and self.selectionMark~=false and not self.selectionMotion,duration)
    if selected then selectionRow,selectionY=row,-(i-1)*self.rowHeight end
    Highlight(row,true)
    if row.symbol then UI:SetIconState(row.symbol,selected,row._inside==true) end
   end
   -- ScrollFrame clips pixels, while each button still owns its full hit rect.
   -- Keep partial rows visible and clickable only inside the clipped viewport.
   local rowHeight=row:GetHeight()
   local top=(i-1)*self.rowHeight-(self.pixelOffset-self.offset*self.rowHeight)
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
 end
 local scrollFrom,scrollElapsed=0,0
 local function ScrollStep(dt)
  scrollElapsed=math.min(.14,scrollElapsed+dt);local p=scrollElapsed/.14;p=1-(1-p)*(1-p)
  list.pixelOffset=scrollFrom+(list.scrollTarget-scrollFrom)*p;list.offset=math.floor(list.pixelOffset/list.rowHeight);list:Refresh(true)
  return scrollElapsed==.14
 end
 function list:SetPixelOffset(value,animate)
  local target=math.max(0,math.min(value,MaxOffset()))
  M:Stop(self);self.scrollTarget=target
  if target==self.pixelOffset or not animate or UI:IsReducedMotion() then self.pixelOffset=target;self.offset=math.floor(target/self.rowHeight);self:Refresh(true);return end
  scrollFrom,scrollElapsed=self.pixelOffset,0
  M:Start(self,ScrollStep)
 end
 function list:SetItems(ids,render) self.ids=ids;self.render=render;self:Refresh() end
 function list:SetViewport(value)
  if self.viewportHeight==value then return end
  self.viewportHeight=value
  self:SetHeight(value);self.capacity=math.min(self.poolCapacity-1,math.ceil(value/self.rowHeight));canvas:SetHeight(value+self.rowHeight*2);self:Refresh()
 end
 local function ResizeContent()
  local width=list:GetWidth()-list.gutter
  canvas:SetWidth(width)
  for _,row in ipairs(list.rows) do row:SetWidth(width) end
 end
 function list:SetGutter(width)
  if self.gutter==width then return end
  self.gutter=width;clip:SetPoint("BOTTOMRIGHT",-width,0);ResizeContent()
  self:Refresh()
 end
 function list:Select(key,locate)
  self.selectedKey=key
  if locate and self.ids then for i,id in ipairs(self.ids) do if id==key then self:SetPixelOffset((i-1)*self.rowHeight,false);return end end end
  self:Refresh(true)
 end
 function list:Clear()
  M:Stop(self);self.scrollTarget=nil;self.ids=nil;self.render=nil;self.selectedKey=nil
  if self.indicator then self.indicator:Clear();self.indicatorKey=nil end
  for _,row in ipairs(self.rows) do Release(row);row:Hide();UI:SetText(row.title,"");UI:SetText(row.meta,"") end
  slider:Hide()
 end
 function list:RefreshKeys(keys,resolve)
  for _,row in ipairs(self.rows) do if row.key then
   for _,key in ipairs(keys) do if resolve(row.key,key) then self.render(row,row.key);UI:ReleaseRow(row);break end end
  end end
 end
 function list:SetStyle(style)
  if style.selectionMotion~=nil then
   self.selectionMotion=style.selectionMotion
   if style.selectionMotion and not self.indicator then self.indicator=C.Selection(canvas,{radius=style.radius or 8,mark=true}) end
  end
  if self.indicator and style.radius then self.indicator.fill:SetRadius(style.radius) end
  for _,key in ipairs({"alternateRows","selectionFill","selectionMark","hoverFill","idleTextColor","hoverColor"}) do if style[key]~=nil then self[key]=style[key] end end
  for _,row in ipairs(self.rows) do
   if style.rowHeight then row:SetHeight(style.rowHeight) end
   if style.radius then row.alternate:SetRadius(style.radius);row.selected:SetRadius(style.radius);row.hover:SetRadius(style.radius) end
   if style.titleSize then C.SetFont(row.title,style.titleSize) end
   if style.titleLineHeight then C.SetLineHeight(row.title,style.titleLineHeight,true) end
   if style.singleLine~=nil then row.meta:SetShown(not style.singleLine) end
   if style.singleLine~=nil or style.titleX then
    row.title:ClearAllPoints()
    if style.singleLine==false then row.title:SetPoint("TOPLEFT",style.titleX or 12,-8) else row.title:SetPoint("LEFT",style.titleX or 12,0) end
   end
   if style.titleWidth then row.title:SetWidth(style.titleWidth) end
  end
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
 for i=1,list.poolCapacity do
  local row=CreateFrame("Button",nil,canvas);row:SetSize(width-C.listRightInset,list.rowHeight);row:SetPoint("TOPLEFT",0,-(i-1)*list.rowHeight)
  row.alternate=C.Panel(row,T.rowAlternate,12)
  row.selected=C.Panel(row,T.secondaryContainer,12);row.selected:Hide()
  row.hover=C.Panel(row,T.rowHover,12);row.hover:Hide()
  row.hover:SetAlpha(0)
  row.mark=row:CreateTexture(nil,"ARTWORK");row.mark:SetColorTexture(unpack(T.accent));row.mark:SetSize(3,T.selectionMarkHeight);row.mark:SetPoint("LEFT",4,0);row.mark:Hide()
  row.title=C.Text(row,"",T.listTitleSize,T.text,width-48);C.SetLineHeight(row.title,T.listTitleLineHeight,true);row.title:SetPoint("TOPLEFT",12,-8);row.title:SetWordWrap(false)
  row.meta=C.Text(row,"",T.listMetaSize,T.muted,width-48);C.SetLineHeight(row.meta,T.listMetaLineHeight,true);row.meta:SetPoint("BOTTOMLEFT",12,8);row.meta:SetWordWrap(false)
  row.noteDot=row:CreateTexture(nil,"ARTWORK");row.noteDot:SetColorTexture(unpack(T.accent));row.noteDot:SetSize(6,6);row.noteDot:Hide()
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
  list.rows[i]=row
 end
 Hook(list,"OnSizeChanged",ResizeContent)
 return list
end

-- Fixed columns share each row's native objects; scrolling only changes their text.
function C.Columns(list,columns,titleWidth)
 for _,row in ipairs(list.rows) do
  row.title:SetWidth(titleWidth);row.meta:SetWidth(titleWidth)
  row.columns={}
  for _,column in ipairs(columns) do
   local size=column.size or T.listMetaSize
   local text=C.Text(row,"",size,T.muted,column.width)
   C.SetLineHeight(text,column.lineHeight or (column.size and size+6 or T.listMetaLineHeight),true)
   text:SetPoint("LEFT",row,"LEFT",column.x,0);text:SetJustifyH(column.align or "RIGHT");text:SetWordWrap(false)
   row.columns[column.key]=text
  end
 end
end

function C.Header(parent,label,x,y,width,align)
 local text=C.Text(parent,label,14,T.dim,width)
 C.SetLineHeight(text,20,true)
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
function C.RoleButton(parent,role,width,text,action)
 local button=C.Button(parent,text,width,action)
 local icon=C.Icon(button,20);icon:SetPoint("LEFT",16,0);UI:SetRoleIcon(icon,role)
 button.roleIcon=icon
 button.label:ClearAllPoints();button.label:SetPoint("LEFT",icon,"RIGHT",8,0)
 button:SetWidth(width or button.label:GetStringWidth()+60)
 button:SetSurfaceColors(T.surfaceLow,T.surfaceLowHover,T.surfaceLowPressed)
 return button
end
local rosterRoleOrder={TANK=1,HEALER=2,DAMAGER=3}
function C.Roster(parent,size,gap)
 size,gap=size or 23,gap or 5
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(size*5+gap*4,size+1)
 frame.slots={};frame.counts={}
 for i=1,5 do
  local icon=C.GameIcon(frame,size);icon:SetPoint("TOPLEFT",(i-1)*(size+gap),0)
  local role=C.Icon(frame,10);role:SetDrawLayer("OVERLAY",2);role:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",1,-1)
  frame.slots[i]={icon=icon,role=role}
 end
 for i,role in ipairs({"TANK","HEALER","DAMAGER"}) do
  local icon=C.Icon(frame,18);icon:SetPoint("LEFT",(i-1)*44,0);UI:SetRoleIcon(icon,role)
  local text=C.Text(frame,"",14,T.text,22);C.SetLineHeight(text,20,true);text:SetPoint("LEFT",icon,"RIGHT",3,0)
  frame.counts[i]={icon=icon,text=text,role=role}
 end
 local function PlaceRole(slot,large)
  local role=slot.role
  local extent=large and size or 10
  if role:GetWidth()~=extent or role:GetHeight()~=extent then role:SetSize(extent,extent) end
  local anchor=large and "CENTER" or "BOTTOMRIGHT"
  local offsetX,offsetY=large and 0 or 1,large and 0 or -1
  local point,parent,relative,x,y=role:GetPoint()
  if role:GetNumPoints()~=1 or point~=anchor or parent~=slot.icon or relative~=anchor or x~=offsetX or y~=offsetY then
   role:ClearAllPoints();role:SetPoint(anchor,slot.icon,anchor,offsetX,offsetY)
  end
 end
 function frame:Update(members,counts,maximum,fixedRoles)
  local party=maximum==5
  for _,item in ipairs(self.counts) do item.icon:SetShown(not party);item.text:SetShown(not party);if not party then UI:SetText(item.text,counts and counts[item.role] or "—") end end
  local used=0
  if party and (members or fixedRoles) then
   local tanks,healers,damage=0,0,0
   for rank=1,4 do
    local present=0
    for i=1,5 do
     local member=members and members[i]
     if member and (rosterRoleOrder[member.assignedRole] or 4)==rank then
      present=present+1
      used=used+1;local slot=self.slots[used]
      slot.icon:Show();slot.role:Hide();UI:SetMemberIcon(slot.icon,member);slot.icon:SetAlpha(1)
      PlaceRole(slot,false)
      if member.assignedRole and member.assignedRole~="NONE" then UI:SetRoleIcon(slot.role,member.assignedRole);slot.role:Show() end
     end
    end
    if rank==1 then tanks=present elseif rank==2 then healers=present elseif rank==3 then damage=present end
   end
   if fixedRoles then
    for rank=1,3 do
     local present=rank==1 and tanks or rank==2 and healers or damage
     local missing=math.min(5-used,math.max(0,(rank==3 and 3 or 1)-present))
     local role=rank==1 and "TANK" or rank==2 and "HEALER" or "DAMAGER"
     for i=1,missing do
      used=used+1;local slot=self.slots[used]
      slot.icon:Hide();PlaceRole(slot,true)
      UI:SetRoleIcon(slot.role,role);slot.role:Show()
     end
    end
   end
  end
  for i=used+1,5 do self.slots[i].icon:Hide();self.slots[i].role:Hide() end
 end
 return frame
end
function C.Slider(parent,width,min,max,step,onChange,options)
 local shell=CreateFrame("Frame",nil,parent);shell:SetSize(width,40)
 if options and options.commitOnRelease then
  min,max,step=min or 0,max or 100,step or 1
  local input=CreateFrame("Frame",nil,shell);input:SetSize(width,24);input:SetPoint("CENTER");input:EnableMouse(true)
  local track=CreateFrame("Frame",nil,input);track:SetHeight(4);track:SetPoint("LEFT");track:SetPoint("RIGHT");C.Panel(track,T.surfaceHigh,2)
  local progress=CreateFrame("Frame",nil,track);progress:SetHeight(4);progress:SetPoint("LEFT");C.Panel(progress,T.accent,2)
  local thumb=CreateFrame("Button",nil,input);thumb:SetSize(8,12)
  local texture=thumb:CreateTexture(nil,"ARTWORK");texture:SetAllPoints();texture:SetTexture(130871);texture:SetVertexColor(unpack(T.accent))
  local drag
  function shell:SetValue(value)
   value=min+math.floor((value-min)/step+.5)*step
   self.value=math.max(min,math.min(max,value))
   local x=input:GetWidth()*(self.value-min)/(max-min)
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
 local slider=CreateFrame("Slider",nil,shell);slider:SetPoint("LEFT",0,0);slider:SetPoint("RIGHT",0,0);slider:SetHeight(24)
 slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(min or 0,max or 100);slider:SetValueStep(step or 1);slider:SetObeyStepOnDrag(true)
 local track=CreateFrame("Frame",nil,slider);track:SetFrameLevel(slider:GetFrameLevel()-2);track:SetPoint("LEFT");track:SetPoint("RIGHT");track:SetHeight(4);C.Panel(track,T.surfaceHigh,2)
 local progress=CreateFrame("Frame",nil,slider);progress:SetFrameLevel(slider:GetFrameLevel()-1);progress:SetPoint("LEFT");progress:SetHeight(4);C.Panel(progress,T.accent,2)
 local thumb=slider:CreateTexture(nil,"OVERLAY");thumb:SetTexture(130871);thumb:SetVertexColor(unpack(T.accent));thumb:SetSize(8,12);slider:SetThumbTexture(thumb)
 local function UpdateProgress(value)
  local low,high=slider:GetMinMaxValues()
  progress:SetWidth(slider:GetWidth()*(value-low)/(high-low))
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
function C.Segmented(parent,width,entries,onChange)
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(width,T.segmentHeight);C.Panel(frame,T.surfaceContainer,8)
 frame.buttons={};frame.selection=C.Selection(frame)
 local itemWidth=(width-6-math.max(0,#entries-1)*4)/#entries
 for i,entry in ipairs(entries) do
  local value=entry.value;if value==nil then value=entry[1] end
  local button=C.Button(frame,entry.label or entry[2],itemWidth,function() frame:SetValue(value);if onChange then onChange(frame.value) end end,{variant="compact",selectionFill=false})
  button:SetPoint("LEFT",3+(i-1)*(itemWidth+4),0);button.value=value
  if entry.icon then button.icon=C.Glyph(button,entry.icon,14);button.icon:SetPoint("LEFT",10,0);button.label:ClearAllPoints();button.label:SetPoint("LEFT",button.icon,"RIGHT",6,0) end
  frame.buttons[i]=button
 end
 function frame:SetValue(value)
  self.value=value
  local selected
  for i,button in ipairs(self.buttons) do
   button:SetActive(button.value==value)
   if button.active then selected=button;self.selection:Select(3+(i-1)*(itemWidth+4),-(self:GetHeight()-button:GetHeight())/2,button:GetWidth(),button:GetHeight(),self:IsVisible()) end
  end
  if not selected then self.selection:Clear() end
 end
 frame:HookScript("OnShow",function(self) self:SetValue(self.value) end)
 return frame
end
-- Rounded rail entry with a straight 3 x 18 selection mark.
function C.Navigation(parent,text,width,action,iconName,options)
 local button=C.Button(parent,text,width,action,{height=48,radius=24,fontSize=16,lineHeight=22})
 button.label:ClearAllPoints();button.label:SetPoint("LEFT",iconName and 52 or 16,0)
 if iconName then button.icon=C.Glyph(button,iconName,24);button.icon:SetPoint("LEFT",16,0);button.icon:SetSelected(false) end
 button.mark=button:CreateTexture(nil,"ARTWORK");button.mark:SetColorTexture(unpack(T.accent));button.mark:SetSize(3,18);button.mark:SetPoint("LEFT",4,0);button.mark:Hide()
 local setActive=button.SetActive
 function button:SetActive(value) setActive(self,value);M:Selection(self.mark,value==true) end
 Hook(button,"OnHide",function(self) M:Selection(self.mark,self.active==true,0) end)
 button:SetTextColors(T.muted,T.text,T.onSecondaryContainer)
 if options then button:SetStyle(options) end
 return button
end
-- A generic text tooltip, separate from application-specific roster tooltips.
function C.Tooltip(parent,width)
 local tip=CreateFrame("Frame",nil,parent or UIParent);tip:SetSize(width or 300,40);tip:SetFrameStrata("TOOLTIP");tip:SetClampedToScreen(true)
 C.Shadow(tip,T.tooltipRadius);C.Panel(tip,T.raised,T.tooltipRadius);tip.lines={};tip.count=0;tip:Hide()
 function tip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor;self.count=0;for _,line in ipairs(self.lines) do line:Hide() end end
 function tip:AddLine(text,r,g,b,wrap)
  self.count=self.count+1;local line=self.lines[self.count]
  if not line then line=C.Text(self,"",12,T.text,self:GetWidth()-32,18);self.lines[self.count]=line end
  UI:SetText(line,text);line:SetTextColor(r or T.text[1],g or T.text[2],b or T.text[3]);line:SetWordWrap(wrap~=false);line:Show()
 end
 local show=tip.Show
 function tip:Show()
  local y=16;for i=1,self.count do local line=self.lines[i];line:ClearAllPoints();line:SetPoint("TOPLEFT",16,-y);y=y+line:GetStringHeight()+4 end
  self:SetHeight(y+12);self:ClearAllPoints();self:SetPoint(self.anchor=="ANCHOR_TOP" and "BOTTOM" or "TOPLEFT",self.owner,self.anchor=="ANCHOR_TOP" and "TOP" or "BOTTOMRIGHT",0,8)
  show(self);M:Alpha(self,1,.12,.25)
 end
 function tip:IsOwned(owner) return self.owner==owner and self:IsShown() end
 function tip:LeaveOwner(owner) if self.owner==owner then self:Hide() end end
 tip:SetScript("OnHide",function(self) M:Stop(self);self:SetAlpha(1);self.owner=nil end)
 return tip
end
function C.Modal(parent,width,height,title,onClose)
 parent=parent or UI.parent
 local frame=CreateFrame("Frame",nil,parent);frame:SetSize(width or 480,height or 300)
 frame:SetPoint("CENTER",parent,"CENTER",0,0)
 frame:SetFrameStrata("DIALOG");frame:EnableMouse(true);frame:SetClampedToScreen(true)
 local function Close() if onClose then onClose(frame) else frame:Hide() end end
 local scrim=CreateFrame("Button",nil,parent);scrim:SetAllPoints(parent);scrim:SetFrameStrata("DIALOG")
 scrim:SetFrameLevel(frame:GetFrameLevel());frame:SetFrameLevel(scrim:GetFrameLevel()+1)
 C.Fill(scrim,{0,0,0,.48});scrim:SetScript("OnClick",Close);scrim:Hide();frame.scrim=scrim
 C.Shadow(frame,T.windowRadius);C.Panel(frame,T.surfaceHigh,T.windowRadius)
 frame.title=C.Text(frame,title,24,T.text,(width or 480)-96);C.SetLineHeight(frame.title,32,true);frame.title:SetPoint("TOPLEFT",24,-24);frame.title:SetWordWrap(false)
 frame.close=C.IconButton(frame,"close",40,Close)
 frame.close:SetPoint("TOPRIGHT",-24,-24)
 frame.content=CreateFrame("Frame",nil,frame);frame.content:SetPoint("TOPLEFT",24,-80);frame.content:SetPoint("BOTTOMRIGHT",-24,24)
 frame:SetScript("OnShow",function() scrim:Show() end)
 frame:SetScript("OnHide",function(self) scrim:Hide();M:FinishPlacement(self) end)
 frame:Hide()
 return frame
end
return C
end

function Library.Context:RoundIcon(icon)
 if icon._lycheeMask then return end
 local mask=icon:GetParent():CreateMaskTexture(nil,"ARTWORK")
 -- Same mask sampler contract as Blizzard's portrait/action-button masks.
 mask:SetTexture(self.Theme.media.."icon-mask.tga","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
 mask:SetAllPoints(icon);icon:AddMaskTexture(mask);icon._lycheeMask=mask
end
function Library.Context:SetGameTexture(icon,file,left,right,top,bottom)
 self:RoundIcon(icon);icon:SetTexture(file)
 local crop=self.Theme.iconCrop;left,right,top,bottom=left or 0,right or 1,top or 0,bottom or 1
 local width,height=right-left,bottom-top
 icon:SetTexCoord(left+width*crop,right-width*crop,top+height*crop,bottom-height*crop)
end
function Library.Context:SetGameAtlas(icon,name)
 self:RoundIcon(icon);icon:SetAtlas(name)
 local info=C_Texture.GetAtlasInfo(name)
 if info then
  local crop=self.Theme.iconCrop;local width,height=info.rightTexCoord-info.leftTexCoord,info.bottomTexCoord-info.topTexCoord
  icon:SetTexCoord(info.leftTexCoord+width*crop,info.rightTexCoord-width*crop,info.topTexCoord+height*crop,info.bottomTexCoord-height*crop)
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
 local value=selected and 1 or hovered and .98 or .9
 local byte=math.floor(value*255+.5)
 local r,g,b=icon:GetVertexColor()
 if not SameIconChannel(r,value,byte) or not SameIconChannel(g,value,byte) or not SameIconChannel(b,value,byte) then icon:SetVertexColor(value,value,value) end
 local alpha=selected and 1 or hovered and .9 or .72
 if not SameIconChannel(icon:GetAlpha(),alpha,math.floor(alpha*255+.5)) then icon:SetAlpha(alpha) end
end

