local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
function Library.AttachMenus(UI)
 local C,T,M=UI.C,UI.Theme,UI.Motion
 local menu
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
  local list=C.List(menu,240,T.menuMaxHeight,T.menuRowHeight,function(index)
   local entry=menu.items[index]
   if entry.disabled or entry.header then return end
   local pick=menu.onPick;Close()
   if entry.onClick then entry.onClick(entry.value,entry.label) elseif pick then pick(entry.value,entry.label,entry) end
  end,function(row,index)
   local entry=menu.items[index];if UI.options.onMenuHover then UI.options.onMenuHover(row,entry) end
  end)
  list:SetPoint("TOPLEFT",T.menuPadding,-T.menuPadding);list:SetStyle({selectionMark=false,alternateRows=false,singleLine=true,radius="selectionRadius",titleSize="menuFontSize",titleLineHeight="menuLineHeight"});menu.list=list
  list:SetRowInitializer(function(row)
   row.icon=C.Icon(row,T.menuIconSize);row.icon:SetPoint("LEFT",T.menuIconInset,0)
   row.check=C.CheckMark(row);row.check:SetPoint("LEFT",T.menuCheckInset,0)
   row.check:Hide()
  end)
  UI:BindStyle(menu,"menu",function(object)
   object.list.rowHeight=T.menuRowHeight
   object.list:SetStyle({rowHeight=T.menuRowHeight,titleSize="menuFontSize",titleLineHeight="menuLineHeight"})
   for i,row in ipairs(object.list.rows) do row:SetPoint("TOPLEFT",0,-(i-1)*T.menuRowHeight);row.icon:SetSize(T.menuIconSize,T.menuIconSize);row.icon:SetPoint("LEFT",T.menuIconInset,0);row.check:SetPoint("LEFT",T.menuCheckInset,0) end
   object.list:SetPoint("TOPLEFT",T.menuPadding,-T.menuPadding)
  end)
  menu:SetScript("OnHide",function(self)
   M:FinishPlacement(self);self:SetAlpha(1);self.catcher:Hide();self.list:Clear()
   local owner=self.anchor;self.anchor,self.items,self.onPick=nil,nil,nil
   for i=#self.keys,1,-1 do self.keys[i]=nil end
   if owner and owner.isChoice then owner:SetExpanded(false) end
   if UI.options.onMenuClosed then UI.options.onMenuClosed(owner) end
  end)
  menu.renderRow=function(row,index)
   local entry=menu.items[index];row.meta:Hide();row.mark:Hide();row.title:ClearAllPoints()
   local textLeft=menu.selectMenu and T.menuSelectInset or entry.icon and T.menuIconTextInset or T.menuTextInset
   row.title:SetPoint("LEFT",textLeft,0);row.title:SetWidth(menu.contentWidth-menu.gutter-textLeft-T.menuTextInset);row.title:SetWordWrap(false)
   UI:SetText(row.title,entry.label or tostring(entry.value or ""));UI:Color(row.title,entry.color or T.text);row:SetAlpha(entry.disabled and T.disabledAlpha or 1)
   row.icon:SetShown(entry.icon~=nil);if entry.icon then row.icon:SetTexture(type(entry.icon)=="string" and T.media..entry.icon..".tga" or entry.icon) end
   row.check:SetShown(entry.checked==true or menu.selectMenu and entry.value==menu.selectedValue);row:SetEnabled(not entry.disabled and not entry.header)
  end
 end
 function UI:OpenMenu(anchor,items,onPick,options)
  if #items==0 or not CanOpen(anchor) then return end
  if not menu then Build() end
  Close()
  if menu:IsShown() or not CanOpen(anchor) then return end
  options=options or {}
  menu.anchor,menu.items,menu.onPick=anchor,items,onPick
  menu.fill:SetColor(T.raised)
  if anchor.isChoice then anchor:SetExpanded(true) end
  local parentScale=UI.parent:GetEffectiveScale()
  local anchorScale=anchor:GetEffectiveScale()
  local scale=anchorScale/parentScale
  menu:SetScale(scale)
  -- Bounds are expressed in menu units; GetBottom/GetRight use each region's scale.
  local selectMenu=options.kind=="select"
  local height=math.min(T.menuMaxHeight,math.max(T.menuRowHeight,math.floor((UI.parent:GetHeight()/scale-T.menuScreenReserve)/T.menuRowHeight)*T.menuRowHeight),#items*T.menuRowHeight)
  local gutter=#items*T.menuRowHeight>height and C.listRightInset or 0
  local natural=selectMenu and anchor:GetWidth() or T.menuMinWidth
  if not options.width then
   for _,entry in ipairs(items) do
    menu.measure:SetText(entry.label or tostring(entry.value or ""))
    natural=math.max(natural,math.ceil(menu.measure:GetStringWidth())+(selectMenu and T.menuSelectInset or entry.icon and T.menuIconTextInset or T.menuTextInset)+T.menuTextInset+T.menuPadding*2+gutter)
   end
  end
  local width=math.min(UI.parent:GetWidth()/scale-T.menuScreenInset,options.width or natural)-T.menuPadding*2
  menu.selectMenu,menu.contentWidth,menu.gutter,menu.selectedValue=selectMenu,width,gutter,options.selectedValue
  menu:SetSize(width+T.menuPadding*2,height+T.menuPadding*2);menu.list:SetSize(width,height);menu.list:SetGutter(gutter)
  menu.list:SetViewport(height)
  local keys=menu.keys;for i=1,#items do keys[i]=i end
  menu.list:SetItems(keys,menu.renderRow)
  menu.list.selectedKey=nil
  for i,entry in ipairs(items) do if entry.checked or (options.selectedValue~=nil and entry.value==options.selectedValue) then menu.list:Select(i,options.locate~=false);break end end
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
  self.menu=menu
 end
 function UI:CloseMenu() Close() end
 function UI:CloseMenuFor(anchor) if menu and menu.anchor==anchor then Close() end end
 function UI:GetMenu() return menu end
 function UI:GetMenuAnchor() return menu and menu.anchor end
 function UI:IsMenuOpen(anchor) return menu~=nil and menu:IsShown() and (anchor==nil or menu.anchor==anchor) end
 function UI:IsMenuHovered(anchor) return self:IsMenuOpen(anchor) and menu:IsMouseOver() end
end
-- Commit only after all six definition files completed in manifest order.
Library.version=private.LycheeUILoadVersion
Library.versionString="1.3.0"
private.LycheeUILoad,private.LycheeUILoadVersion=nil,nil
