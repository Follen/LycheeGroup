local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
function Library.AttachMenus(UI)
 local C,T,M=UI.C,UI.Theme,UI.Motion
 local menu
 local function Close()
  if menu then menu:Hide() end
 end
 local function Build()
  menu=CreateFrame("Frame",nil,UI.parent);menu:SetFrameStrata("TOOLTIP");menu:SetFrameLevel(20);menu:SetClampedToScreen(true);menu:EnableMouse(true)
  C.Shadow(menu,12);menu.fill=C.Panel(menu,T.raised,12);menu.keys={};menu:Hide()
  menu.measure=C.Text(menu,"",16,T.text);menu.measure:Hide()
  local catcher=CreateFrame("Button",nil,UI.parent);catcher:SetAllPoints(UI.parent);catcher:SetFrameStrata("TOOLTIP");catcher:SetFrameLevel(19)
  catcher:RegisterForClicks("AnyDown");catcher:SetScript("OnClick",Close);catcher:Hide();menu.catcher=catcher
  local list=C.List(menu,240,400,40,function(index)
   local entry=menu.items[index]
   if entry.disabled or entry.header then return end
   local pick=menu.onPick;Close()
   if entry.onClick then entry.onClick(entry.value,entry.label) elseif pick then pick(entry.value,entry.label,entry) end
  end,function(row,index)
   local entry=menu.items[index];if UI.options.onMenuHover then UI.options.onMenuHover(row,entry) end
  end)
  list:SetPoint("TOPLEFT",4,-4);list.selectionMark=false;list.alternateRows=false;menu.list=list
  for _,row in ipairs(list.rows) do
   row.meta:Hide();row.title:SetFont(T.font,16,"");C.SetLineHeight(row.title,22,true);row.title:ClearAllPoints();row.title:SetPoint("LEFT",12,0)
   row.icon=C.Icon(row,20);row.icon:SetPoint("LEFT",12,0)
   row.selected:SetRadius(8);row.hover:SetRadius(8)
   row.check=CreateFrame("Frame",nil,row);row.check:SetSize(16,20);row.check:SetPoint("LEFT",8,0)
   row.check.strokes={}
   for _,stroke in ipairs({{5,-3,-1,-math.pi/4},{9,1.3,.5,math.pi/4}}) do
    local line=row.check:CreateTexture(nil,"ARTWORK");line:SetColorTexture(unpack(T.onSecondaryContainer));line:SetSize(stroke[1],1.5)
    line:SetPoint("CENTER",stroke[2],stroke[3]);line:SetRotation(stroke[4]);row.check.strokes[#row.check.strokes+1]=line
   end
   row.check:Hide()
  end
  menu:SetScript("OnHide",function(self)
   M:Stop(self);self:SetAlpha(1);self.catcher:Hide();self.list:Clear()
   local owner=self.anchor;self.anchor,self.items,self.onPick=nil,nil,nil
   for i=#self.keys,1,-1 do self.keys[i]=nil end
   if owner and owner.isChoice then owner:SetExpanded(false) end
   if UI.options.onMenuClosed then UI.options.onMenuClosed(owner) end
  end)
  menu.renderRow=function(row,index)
   local entry=menu.items[index];row.meta:Hide();row.mark:Hide();row.title:ClearAllPoints()
   local textLeft=menu.selectMenu and 32 or entry.icon and 40 or 12
   row.title:SetPoint("LEFT",textLeft,0);row.title:SetWidth(menu.contentWidth-menu.gutter-textLeft-12);row.title:SetWordWrap(false)
   UI:SetText(row.title,entry.label or tostring(entry.value or ""));UI:Color(row.title,entry.color or T.text);row:SetAlpha(entry.disabled and .38 or 1)
   row.icon:SetShown(entry.icon~=nil);if entry.icon then row.icon:SetTexture(type(entry.icon)=="string" and T.media..entry.icon..".tga" or entry.icon) end
   row.check:SetShown(entry.checked==true or menu.selectMenu and entry.value==menu.selectedValue);row:SetEnabled(not entry.disabled and not entry.header)
  end
 end
 function UI:OpenMenu(anchor,items,onPick,options)
  if #items==0 or not anchor:IsVisible() or self:IsHiding() then return end
  if not menu then Build() end
  Close();options=options or {}
  menu.anchor,menu.items,menu.onPick=anchor,items,onPick
  menu.fill:SetColor(T.raised)
  if anchor.isChoice then anchor:SetExpanded(true) end
  local parentScale=UI.parent:GetEffectiveScale()
  local anchorScale=anchor:GetEffectiveScale()
  local scale=anchorScale/parentScale
  menu:SetScale(scale)
  -- Bounds are expressed in menu units; GetBottom/GetRight use each region's scale.
  local selectMenu=options.kind=="select"
  local height=math.min(400,math.max(40,math.floor((UI.parent:GetHeight()/scale-48)/40)*40),#items*40)
  local gutter=#items*40>height and C.listRightInset or 0
  local natural=selectMenu and anchor:GetWidth() or 216
  for _,entry in ipairs(items) do
   menu.measure:SetText(entry.label or tostring(entry.value or ""))
   natural=math.max(natural,math.ceil(menu.measure:GetStringWidth())+(selectMenu and 32 or entry.icon and 40 or 12)+12+8+gutter)
  end
  local width=math.min(UI.parent:GetWidth()/scale-16,options.width or natural)-8
  menu.selectMenu,menu.contentWidth,menu.gutter,menu.selectedValue=selectMenu,width,gutter,options.selectedValue
  menu:SetSize(width+8,height+8);menu.list:SetSize(width,height);menu.list:SetGutter(gutter)
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
   local x=(cursorX-parentLeft)/anchorScale+4
   local y=(cursorY-parentBottom)/anchorScale-4
   x=math.max(4,math.min(x,UI.parent:GetWidth()/scale-menu:GetWidth()-4))
   y=math.max(menu:GetHeight()+4,math.min(y,UI.parent:GetHeight()/scale-4))
   menu:SetPoint("TOPLEFT",UI.parent,"BOTTOMLEFT",x,y)
  else
   local below=((anchor:GetBottom() or 0)*anchorScale-parentBottom)/anchorScale
   local above=below<height+32
   local right=(anchor:GetRight() or 0)*anchorScale
   local parentRight=(UI.parent:GetRight() or UI.parent:GetWidth())*parentScale
   local alignRight=(parentRight-right)/anchorScale<width+8
   menu:SetPoint((above and "BOTTOM" or "TOP")..(alignRight and "RIGHT" or "LEFT"),anchor,(above and "TOP" or "BOTTOM")..(alignRight and "RIGHT" or "LEFT"),0,above and 8 or -8)
  end
  menu.catcher:Show();menu:Show();M:Alpha(menu,1,.12,.25)
  self.menu=menu
 end
 function UI:CloseMenu() Close() end
 function UI:CloseMenuFor(anchor) if menu and menu.anchor==anchor then Close() end end
end
-- Commit only after all six definition files completed in manifest order.
Library.version=private.LycheeUILoadVersion
Library.versionString="1.1.11"
private.LycheeUILoad,private.LycheeUILoadVersion=nil,nil
