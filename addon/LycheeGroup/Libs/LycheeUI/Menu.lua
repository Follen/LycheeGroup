local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
function Library.AttachMenus(UI)
 local C,T,M=UI.C,UI.Theme,UI.Motion
 local menu
 local RelayoutGeometry
 local requestedFont,requestedSize,requestedFlags,appliedFont,appliedSize,appliedFlags
 local function MeasureFont(font,size,flags)
  local currentFont,currentSize,currentFlags=menu.measure:GetFont()
  if currentFont==font and currentSize==size and currentFlags==flags
   or requestedFont==font and requestedSize==size and requestedFlags==flags
    and currentFont==appliedFont and currentSize==appliedSize and currentFlags==appliedFlags then return end
  if menu.measure:SetFont(font,size,flags) then
   requestedFont,requestedSize,requestedFlags=font,size,flags
   appliedFont,appliedSize,appliedFlags=menu.measure:GetFont()
  else
   -- Failed native font requests must remain retryable on the next item/open.
   requestedFont,requestedSize,requestedFlags=nil,nil,nil
   appliedFont,appliedSize,appliedFlags=nil,nil,nil
  end
 end
 local function IsChecked(entry) return entry.checked==true or menu.selectMenu and entry.value==menu.selectedValue end
 local function PrepareRow(row,index)
  if not index then return end
  local entry=menu.items[index]
  row._checked=IsChecked(entry)==true;row:SetEnabled(not entry.disabled and not entry.header)
 end
 local anonymous=0
 function UI:GetMenuOwnerKey(anchor)
  local record=self.elements and self.elements[anchor]
  if record then return record.id..(record.key~=nil and "/"..type(record.key)..":"..tostring(record.key) or "") end
  if not anchor._lycheeMenuElementID then anonymous=anonymous+1;anchor._lycheeMenuElementID="anonymous:"..anonymous end
  return anchor._lycheeMenuElementID
 end
 function UI:GetMenuElementKey(anchor,value) return self:GetMenuOwnerKey(anchor).."/"..type(value)..":"..tostring(value) end
 local function EntryKey(entry,index) local key=entry.id;if key==nil then key=entry.value end;if key==nil then key=index end;return UI:GetMenuElementKey(menu.anchor,key) end
 local function Close()
  if menu then menu:Hide() end
 end
 local function CanOpen(anchor)
  return anchor:IsVisible() and not UI:IsHiding() and (not anchor.isChoice or anchor:IsEnabled())
 end
 local function Build()
  menu=CreateFrame("Frame",nil,UI.parent);menu:SetFrameStrata("TOOLTIP");menu:SetFrameLevel(20);menu:SetClampedToScreen(true);menu:EnableMouse(true)
  C.Shadow(menu,"menuRadius");menu.fill=C.Panel(menu,"raised","menuRadius");menu.keys={};menu:Hide()
  menu.measure=C.Text(menu,"","menuFontSize","text");menu.measure:Hide()
  local catcher=CreateFrame("Button",nil,UI.parent);catcher:SetAllPoints(UI.parent);catcher:SetFrameStrata("TOOLTIP");catcher:SetFrameLevel(19)
  catcher:RegisterForClicks("AnyDown");catcher:SetScript("OnClick",Close);catcher:Hide();menu.catcher=catcher
  local function InitializeRow(row)
   row.icon=C.Icon(row,T.menuIconSize);row.icon:SetPoint("LEFT",T.menuIconInset,0)
   row.check=C.CheckMark(row);row.check:SetPoint("LEFT",T.menuCheckInset,0);row.check:Hide()
  end
  local list=C.List(menu,240,T.menuMaxHeight,T.menuRowHeight,function(index)
   local entry=menu.items[index]
   if entry.disabled or entry.header then return end
   local pick=menu.onPick;Close()
   if entry.onClick then entry.onClick(entry.value,entry.label) elseif pick then pick(entry.value,entry.label,entry) end
  end,function(row,index)
   local entry=menu.items[index];if UI.options.onMenuHover then UI.options.onMenuHover(row,entry) end
  end,{recipe="menuRow",initializeRow=InitializeRow,onGeometryChanged=function() if RelayoutGeometry then RelayoutGeometry() end end})
  list:SetPoint("TOPLEFT",T.menuPadding,-T.menuPadding);list:SetStyle({selectionMark=false,alternateRows=false,singleLine=true,radius="selectionRadius",titleSize="menuFontSize",titleLineHeight="menuLineHeight"});menu.list=list
  list:SetRowInitializer(PrepareRow)
  menu:SetScript("OnHide",function(self)
   M:FinishPlacement(self);self:SetAlpha(1);self.catcher:Hide();self.list:Clear()
   C.RekeyElement(self,nil);C.RekeyElement(self.list,nil)
   local owner=self.anchor;self.anchor,self.items,self.onPick,self.options=nil,nil,nil,nil
   for i=#self.keys,1,-1 do self.keys[i]=nil end
   if owner and owner.isChoice then owner:SetExpanded(false) end
   if UI.options.onMenuClosed then UI.options.onMenuClosed(owner) end
  end)
  menu.renderRow=function(row,index)
   PrepareRow(row,index)
   local entry=menu.items[index];row.meta:Hide();row.mark:Hide();row.title:ClearAllPoints()
   local textLeft=menu.selectMenu and T.menuSelectInset or entry.icon and T.menuIconTextInset or T.menuTextInset
   row.title:SetPoint("LEFT",textLeft,0);row.title:SetWidth(menu.contentWidth-menu.gutter-textLeft-T.menuTextInset);row.title:SetWordWrap(false)
   UI:SetText(row.title,entry.label or tostring(entry.value or ""));UI:Color(row.title,UI:ResolveValue(entry.color or "text"));row:SetAlpha(entry.disabled and T.disabledAlpha or 1)
   row.icon:SetShown(entry.icon~=nil);if entry.icon then row.icon:SetTexture(type(entry.icon)=="string" and T.media..entry.icon..".tga" or entry.icon) end
   row.check:SetShown(row._checked)
  end
  C.Element(menu,"menu",{scope="menu"})
  C.Element(list,"menu.list",{scope="menu",rowTemplate="menu.row",rowElementKey=function(index)
   local entry=menu.items and menu.items[index];return entry and EntryKey(entry,index) or nil
  end,rowElementState=function(index,_,name)
   local entry=menu.items[index]
   if name=="checked" then return IsChecked(entry)==true end
   if name=="disabled" then return not not (entry.disabled or entry.header) end
  end,slots={root=list,slider=list.slider,thumb=list.slider.thumb,clip=list.clip,canvas=list.canvas}})
 end
 local function ElementSize(target,axis,fallback)
  local suffix=axis=="width" and "Width" or "Height"
  return math.max(C.ElementValue(target,"root","min"..suffix,0),math.min(C.ElementValue(target,"root","max"..suffix,math.huge),C.ElementValue(target,"root",axis,fallback)))
 end
 local function ViewportHeight(scale)
  local rowHeight=math.max(1,T.menuRowHeight)
  local maximum=math.min(T.menuMaxHeight,math.max(rowHeight,math.floor((UI.parent:GetHeight()/scale-T.menuScreenReserve)/rowHeight)*rowHeight))
  local content=menu.list:GetContentHeight()
  local height=ElementSize(menu,"height",math.min(maximum,content)+T.menuPadding*2)-T.menuPadding*2
  height=math.max(0,ElementSize(menu.list,"height",height))
  return height,content>height and C.listRightInset or 0
 end
 local function SizeMenu(anchor,items,options)
  menu.sizing=true
  local parentScale=UI.parent:GetEffectiveScale()
  local anchorScale=anchor:GetEffectiveScale()
  local scale=anchorScale/parentScale
  menu:SetScale(scale)
  -- Bounds are expressed in menu units; GetBottom/GetRight use each region's scale.
  local selectMenu=options.kind=="select"
  local height,gutter=ViewportHeight(scale)
  local natural=selectMenu and anchor:GetWidth() or T.menuMinWidth
  if not options.width then
   for index,entry in ipairs(items) do
    local key=EntryKey(entry,index)
    local fontSize=UI:ResolveElementValue("menu.row","label","fontSize",UI:GetFontSize("menuFontSize"),key)
    local font=UI:ResolveElementValue("menu.row","label","font",UI.fontPath,key)
    local flags=UI:ResolveElementValue("menu.row","label","flags","",key)
    MeasureFont(font,fontSize,flags)
    menu.measure:SetText(entry.label or tostring(entry.value or ""))
    natural=math.max(natural,math.ceil(menu.measure:GetStringWidth())+(selectMenu and T.menuSelectInset or entry.icon and T.menuIconTextInset or T.menuTextInset)+T.menuTextInset+T.menuPadding*2+gutter)
   end
  end
  local width=ElementSize(menu,"width",math.min(UI.parent:GetWidth()/scale-T.menuScreenInset,options.width or natural))-T.menuPadding*2
  width=ElementSize(menu.list,"width",width)
  menu.selectMenu,menu.contentWidth,menu.gutter,menu.selectedValue=selectMenu,width,gutter,options.selectedValue
  if menu:GetWidth()~=width+T.menuPadding*2 or menu:GetHeight()~=height+T.menuPadding*2 then menu:SetSize(width+T.menuPadding*2,height+T.menuPadding*2) end
  if menu.list:GetWidth()~=width or menu.list:GetHeight()~=height then menu.list:SetSize(width,height) end
  menu.list:SetGutter(gutter)
  menu.list:SetViewport(height)
  menu.sizing=nil
  return parentScale,anchorScale,scale,width,height
 end
 RelayoutGeometry=function()
  if not menu or menu.sizing or not menu:IsShown() or not menu.anchor then return end
  local height,gutter=ViewportHeight(menu:GetScale())
  if height==menu.list.viewportHeight and gutter==menu.gutter then return end
  SizeMenu(menu.anchor,menu.items,menu.options)
  menu.list:Refresh(true)
 end
 function UI:_LayoutOpenMenu()
  if not menu or not menu:IsShown() then return end
  SizeMenu(menu.anchor,menu.items,menu.options)
  menu.list:Refresh();C.ApplyElement(menu.list);C.ApplyElement(menu)
 end
 function UI:OpenMenu(anchor,items,onPick,options)
  if #items==0 or not CanOpen(anchor) then return end
  if not menu then Build() end
  Close()
  if menu:IsShown() or not CanOpen(anchor) then return end
  options=options or {}
  menu.anchor,menu.items,menu.onPick,menu.options=anchor,items,onPick,options
  local ownerKey=self:GetMenuOwnerKey(anchor);C.RekeyElement(menu,ownerKey);C.RekeyElement(menu.list,ownerKey)
  menu.fill:SetColor(T.raised)
  if anchor.isChoice then anchor:SetExpanded(true) end
  local keys=menu.keys;for i=1,#items do keys[i]=i end
  menu.selectMenu,menu.selectedValue=options.kind=="select",options.selectedValue
  menu.list.selectedKey=nil
  for i,entry in ipairs(items) do if entry.checked or (options.selectedValue~=nil and entry.value==options.selectedValue) then menu.list.selectedKey=i;break end end
  menu.list:SetItems(keys,PrepareRow)
  local parentScale,anchorScale,scale,width,height=SizeMenu(anchor,items,options)
  menu.list:SetItems(keys,menu.renderRow)
  if menu.list.selectedKey then menu.list:Select(menu.list.selectedKey,options.locate~=false) end
  menu:ClearAllPoints()
  local parentBottom=(UI.parent:GetBottom() or 0)*parentScale
  if options.cursor then
   local cursorX,cursorY=GetCursorPosition()
   local parentLeft=(UI.parent:GetLeft() or 0)*parentScale
   local x=(cursorX-parentLeft)/anchorScale+T.menuCursorOffset
   local y=(cursorY-parentBottom)/anchorScale-T.menuCursorOffset
   x=math.max(T.menuCursorOffset,math.min(x,UI.parent:GetWidth()/scale-menu:GetWidth()-T.menuCursorOffset))
   y=math.max(menu:GetHeight()+T.menuCursorOffset,math.min(y,UI.parent:GetHeight()/scale-T.menuCursorOffset))
   menu:SetPoint("TOPLEFT",UI.parent,"BOTTOMLEFT",x,y)
  else
   local below=((anchor:GetBottom() or 0)*anchorScale-parentBottom)/anchorScale
   local above=below<height+T.menuPopupGap*4
   local right=(anchor:GetRight() or 0)*anchorScale
   local parentRight=(UI.parent:GetRight() or UI.parent:GetWidth())*parentScale
   local alignRight=(parentRight-right)/anchorScale<width+T.menuPadding*2
   menu:SetPoint((above and "BOTTOM" or "TOP")..(alignRight and "RIGHT" or "LEFT"),anchor,(above and "TOP" or "BOTTOM")..(alignRight and "RIGHT" or "LEFT"),0,above and T.menuPopupGap or -T.menuPopupGap)
  end
  menu.catcher:Show();menu:Show()
  local point,parent,relative,x,y=menu:GetPoint()
  M:Reveal(menu,point,parent,relative,x,y,0,point:find("BOTTOM") and -T.menuRevealOffset or T.menuRevealOffset,T.menuRevealDuration)
  C.ApplyElement(menu.list);C.ApplyElement(menu)
  self.menu=menu
 end
 function UI:CloseMenu() Close() end
 function UI:CloseMenuFor(anchor) if menu and menu.anchor==anchor then Close() end end
 function UI:GetMenu() return menu end
 function UI:GetMenuAnchor() return menu and menu.anchor end
 function UI:IsMenuOpen(anchor) return menu~=nil and menu:IsShown() and (anchor==nil or menu.anchor==anchor) end
 function UI:IsMenuHovered(anchor) return self:IsMenuOpen(anchor) and menu:IsMouseOver() end
end
-- Commit only after all nine definition files completed in manifest order.
Library.version=private.LycheeUILoadVersion
Library.versionString="1.3.0"
private.LycheeUILoad,private.LycheeUILoadVersion=nil,nil
