-- User-sized window geometry and the bottom-right three-state resize grip.
local A=_G.LycheeGroup
local UI=A.UI
local T,M,C=UI.Theme,UI.Motion,UI.C
local MEDIA="Interface\\AddOns\\LycheeGroup_UI\\Media\\resize-grip-lines-"

function UI:GetWindowMinimum()
 local large=math.max(0,self.context.fontScale-1)
 local page=self.page and self.pages[self.page]
 local pageWidth=page and page.frame and page.GetMinimumWidth and page:GetMinimumWidth() or 0
 local pageHeight=page and page.frame and page.GetMinimumHeight and page:GetMinimumHeight() or 0
 return math.max(T.windowMinWidth+math.floor(large*T.windowFontWidthGrowth+.5),pageWidth),math.max(T.windowMinHeight+math.floor(large*T.windowFontHeightGrowth+.5),pageHeight)
end

function UI:LoadWindowSize()
 local width,height=A.Appearance:GetWindowSize()
 self.windowWidth=width or T.width
 self.windowHeight=height or T.height
 self.preferredWindowWidth,self.preferredWindowHeight=self.windowWidth,self.windowHeight
end

function UI:LayoutWindow(deferPage)
 if not self.content then return end
 local width,height=self.windowWidth-T.pageInset*2,self.windowHeight-T.headerHeight-T.pageInset
 self.content:SetSize(width,height)
 local page=self.page and self.pages[self.page]
 if page and page.frame then
  page.frame:SetSize(width,height)
  if not deferPage then
   page:LayoutSize(width,height)
   page.enteredWidth,page.enteredHeight=width,height
  end
 end
end

function UI:SetWindowSize(width,height,deferPage)
 local minWidth,minHeight=self:GetWindowMinimum()
 local scale=self.frame:GetScale()
 local maxWidth=math.max(minWidth,(UIParent:GetWidth()-T.windowScreenInset*2)/scale)
 local maxHeight=math.max(minHeight,(UIParent:GetHeight()-T.windowScreenInset*2)/scale)
 width=math.max(minWidth,math.min(maxWidth,width))
 height=math.max(minHeight,math.min(maxHeight,height))
 if width==self.windowWidth and height==self.windowHeight and self.frame:GetWidth()==width and self.frame:GetHeight()==height then return end
 self.windowWidth,self.windowHeight=width,height
 self.frame:SetSize(width,height)
 self:LayoutWindow(deferPage)
end

function UI:RefreshWindowSize()
 if self.navigating then return end
 -- Page feedback may arrive from native inputs while the user is resizing.
 -- Only the cursor owns the current dimensions until the drag ends.
 if self.resizing then self:SetWindowSize(self.windowWidth,self.windowHeight)
 else self:SetWindowSize(self.preferredWindowWidth,self.preferredWindowHeight) end
end

function UI:RefreshResizeState()
 local handle=self.resizeHandle
 handle.icon:SetAlpha((self.resizing or handle.inside) and 1 or 0)
 local state=self.resizing and "pressed" or handle.inside and "hover" or "normal"
 if state~=handle.state then handle.state=state;handle.icon:SetTexture(MEDIA..state..".tga") end
end

function UI:ResizeToCursor()
 local drag=self.resizing
 local x,y=GetCursorPosition()
 local width=drag.width+math.floor((x-drag.cursorX)/drag.scale+.5)
 local height=drag.height+math.floor((drag.cursorY-y)/drag.scale+.5)
 self:SetWindowSize(math.min(drag.maxWidth,width),math.min(drag.maxHeight,height))
end

function UI:StopWindowResize()
 if not self.resizing then return end
 self.resizing=nil
 self.resizeHandle:SetScript("OnUpdate",nil)
 self.preferredWindowWidth,self.preferredWindowHeight=self.windowWidth,self.windowHeight
 A.Appearance:SaveWindowSize(self.windowWidth,self.windowHeight)
 M:CapturePosition();M:SetPresence(1)
 self:RefreshResizeState()
end

function UI:BeginWindowResize()
 if self.hiding or self.activeModal or self.resizing then return end
 self.drag:Stop();self:CloseMenu();self.Tooltip:Hide()
 local page=self.page and self.pages[self.page]
 if page and page.ClosePicker then page:ClosePicker() end
 if page and page.FinishSidebar then page:FinishSidebar() end
 M:StopPresence();M:CapturePosition();M:SetPresence(1)
 local frame=self.frame
 local scale=frame:GetEffectiveScale()
 local left,top=frame:GetLeft()*scale,frame:GetTop()*scale
 local parentScale=UIParent:GetEffectiveScale()
 local minWidth,minHeight=self:GetWindowMinimum()
 local x,y=GetCursorPosition()
 self.resizing={cursorX=x,cursorY=y,width=self.windowWidth,height=self.windowHeight,scale=scale,
  maxWidth=math.max(minWidth,(UIParent:GetWidth()*parentScale-T.windowScreenInset*parentScale-left)/scale),
  maxHeight=math.max(minHeight,(top-T.windowScreenInset*parentScale)/scale)}
 frame:ClearAllPoints();frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left/scale,top/scale)
 M:CapturePosition()
 self:RefreshResizeState()
 self.resizeHandle:SetScript("OnUpdate",function()
  UI:ResizeToCursor()
  if not IsMouseButtonDown("LeftButton") then UI:StopWindowResize() end
 end)
end

function UI:BuildResizeHandle()
 local handle=CreateFrame("Button",nil,self.frame)
 handle:SetWidth(T.windowResizeHandleSize);handle:SetHeight(T.windowResizeHandleSize);C.SetPoint(handle,"BOTTOMRIGHT",handle:GetParent(),"BOTTOMRIGHT","resizeHandleBottomrightX","resizeHandleBottomrightY")
 handle:SetFrameLevel(self.frame:GetFrameLevel()+30)
 local icon=handle:CreateTexture(nil,"ARTWORK");icon:SetWidth(T.windowResizeIconSize);icon:SetHeight(T.windowResizeIconSize);C.SetPoint(icon,"BOTTOMRIGHT",icon:GetParent(),"BOTTOMRIGHT","resizeIconBottomrightX","resizeIconBottomrightY")
 handle.icon=icon;self.resizeHandle=handle
 handle:SetScript("OnEnter",function() handle.inside=true;UI:RefreshResizeState() end)
 handle:SetScript("OnLeave",function() handle.inside=nil;UI:RefreshResizeState() end)
 handle:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then UI:BeginWindowResize() end end)
 handle:SetScript("OnMouseUp",function(_,button)
  if button=="LeftButton" and UI.resizing then UI:ResizeToCursor();UI:StopWindowResize() end
 end)
 handle:SetScript("OnHide",function() handle.inside=nil;UI:StopWindowResize();UI:RefreshResizeState() end)
 UI:Element(handle,"host.resize","host")
 self:RefreshResizeState()
end
