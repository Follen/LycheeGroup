-- Offline settings block-list layout and interaction checks.
-- Run: lua tests/test_blocked_layout.lua
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function near(a,b,message) check(math.abs(a-b)<.001,message) end
local function position(region,root)
 if region==root then return 0,0 end
 local point={region:GetPoint()};local relative,anchor,x,y
 if not point[1] then
  local parent=region:GetParent();local px,py=position(parent,root)
  return px,py-(parent.scrollChild==region and parent:GetVerticalScroll() or 0)
 end
 if type(point[2])=="table" then relative,anchor,x,y=point[2],point[3],point[4] or 0,point[5] or 0
 else relative,anchor,x,y=region:GetParent(),point[1],point[2] or 0,point[3] or 0 end
 local function part(value,low,high) return value:find(low) and 0 or value:find(high) and 1 or .5 end
 local px,py=position(relative,root)
 return px+relative:GetWidth()*part(anchor,"LEFT","RIGHT")+x-region:GetWidth()*part(point[1],"LEFT","RIGHT"),py+relative:GetHeight()*part(anchor,"TOP","BOTTOM")-y-region:GetHeight()*part(point[1],"TOP","BOTTOM")
end
local f=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=true})
f.A:Open("settings",{section="blocks"})
check(f.U.pages.settings.blocksHelp==nil,"removed blocking explanation still has an object and layout space")
f.U:Hide(true)
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,percent in ipairs({70,100,130}) do
  local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true,fontScale=percent})
  local a,u,g,s=f.A,f.U,f.G,f.S
  for index=1,48 do
   local key=locale=="zhCN" and ("组队玩家%02d-燃烧平原"):format(index) or ("Player%02d-Silvermoon"):format(index)
   g.Results:BlockTitle("Fixture group "..index,key)
  end
  a:Open("settings",{section="blocks"});u:SetWindowSize(1,1)
  local p=u.pages.settings;local list,header=p.blocksList,p.blocksHeader
  local tag=locale.."/"..percent
  check(p.blocksHelp==nil,tag..": removed explanation remains constructed")
  local titleX,titleY=position(p.heading,p.main)
  local countX,countY=position(p.blocksCount,p.main)
  local clearX,clearY=position(p.blocksClear,p.main)
  near(countX,titleX+p.heading:GetWidth()+12,tag..": count is not next to the page title")
  near(countY+p.blocksCount:GetHeight()/2,titleY+p.heading:GetHeight()/2,tag..": count and title do not share a center")
  near(clearY+p.blocksClear:GetHeight()/2,titleY+p.heading:GetHeight()/2,tag..": clear action does not share the title line")
  check(p.blocksCount:GetUnboundedStringWidth()<=p.blocksCount:GetWidth(),tag..": blocked count is truncated")
  check(countX+p.blocksCount:GetWidth()+16<=clearX,tag..": count overlaps the clear action")
  local _,headerY=position(header,p.main)
  near(headerY,titleY+p.heading:GetHeight()+12,tag..": header retains the removed explanation's space")
  local _,listY=position(list,p.panels.blocks)
  check(listY+list:GetHeight()<=p.panels.blocks:GetHeight()+.001,tag..": viewport exceeds the panel")
  check(#list.ids==48 and #list.rows<48,tag..": block list does not use a bounded visible pool")
  local row=list.rows[1]
  for _,entry in ipairs({{"name",row.title},{"realm",row.meta}}) do
   local x,y=position(entry[2],p.main);local hx=position(header.labels[entry[1]],p.main)
   near(x,hx,tag..": column text does not align with its heading")
   check(entry[2]:GetUnboundedStringWidth()<=entry[2]:GetWidth(),tag..": player or realm is truncated at the normal column width")
   check(entry[2]:GetStringHeight()+24<=row:GetHeight()+.001,tag..": scaled player text crowds the row")
  end
  near(position(row.title,p.main),titleX,tag..": player name does not align with the page title")
  local removeX=position(row.remove,p.main)
  near(removeX+row.remove:GetWidth(),clearX+p.blocksClear:GetWidth(),tag..": remove and clear right edges differ")
  local actionX=position(header.labels.actions,p.main)
  local removeLabelX=position(row.remove.label,p.main)
  check(math.abs(actionX+header.labels.actions:GetWidth()-removeLabelX-row.remove.label:GetWidth())<=1,tag..": action heading and action text have different right edges")
  for index=1,math.min(#list.rows,5) do
   local item=list.rows[index]
   check(item.alternate.radius==0 and item.alternate.color==u.Theme.rowAlternate,tag..": alternating rows add a card surface or rounded gap")
   if index>1 then
    local _,y=position(item,list.canvas);local _,beforeY=position(list.rows[index-1],list.canvas)
    near(y,beforeY+list.rowHeight,tag..": continuous rows have a vertical gap")
   end
  end
  -- Preserve user sizing and verify the text follows both columns after a drag.
  local oldMouse=IsMouseButtonDown;IsMouseButtonDown=function() return true end
  local oldWidth=header.columns.name.width
  header.handles[1]:Fire("OnMouseDown","LeftButton")
  s.cursorX=s.cursorX-36*header:GetEffectiveScale();header:UpdateDrag()
  header.handles[1]:Fire("OnMouseUp","LeftButton");IsMouseButtonDown=oldMouse
  check(header.columns.name.width<oldWidth and header.state.widths~=nil,tag..": resizing does not persist column proportions")
  local widths=header.state.widths
  p:LayoutBlocks();check(header.state.widths==widths,tag..": layout replaces the user's column widths")
  near(position(row.meta,p.main),position(header.labels.realm,p.main),tag..": dragged realm column loses its shared edge")
  for _,nextPercent in ipairs({70,130,percent}) do
   a:SetSetting("fontScale",nextPercent)
   local hotTag=tag.." -> "..nextPercent
   check(header.state.widths==widths,hotTag..": changing font size resets the user's column widths")
   near(position(row.title,p.main),position(header.labels.name,p.main),hotTag..": player column loses its shared edge")
   near(position(row.meta,p.main),position(header.labels.realm,p.main),hotTag..": realm column loses its shared edge")
   check(math.max(row.title:GetStringHeight(),row.meta:GetStringHeight())+24<=row:GetHeight()+.001,hotTag..": player text crowds the row after a font change")
   local hotClearX=position(p.blocksClear,p.main);local hotRemoveX=position(row.remove,p.main)
   near(hotRemoveX+row.remove:GetWidth(),hotClearX+p.blocksClear:GetWidth(),hotTag..": font change separates the action edges")
  end
  local first=row.remove;first:Fire("OnMouseDown","LeftButton")
  list:SetPixelOffset(list.rowHeight*3,false);list.clip.mouseOver=true;first:Fire("OnClick","LeftButton")
  check(#g.Results:GetBlockedLeaders()==48,tag..": a recycled pressed button removes a different player")
  local target=list.rows[1].key
  first:Fire("OnMouseDown","LeftButton");first:Fire("OnClick","LeftButton")
  check(g.db.blockedLeaders[target]==nil and #list.ids==47,tag..": single removal does not update the same target")
  list:SetPixelOffset(100000,false)
  local last=list.ids[#list.ids];local found=false
  for _,item in ipairs(list.rows) do if item.key==last and item._hitVisible then found=true end end
  check(found,tag..": the last of 40+ records cannot be reached")
  local nodes=#s.nodes
  for _=1,8 do list:SetPixelOffset(0,false);list:SetPixelOffset(100000,false);p:LayoutBlocks() end
  check(#s.nodes==nodes,tag..": warm scrolling and layout allocate more visual objects")
  p.blocksClear:Fire("OnClick","LeftButton")
  check(#g.Results:GetBlockedLeaders()==0 and #list.ids==0,tag..": fixture clear leaves blocked players")
  check(p.blocksEmpty:IsShown() and not list:IsShown() and not header:IsShown() and not p.blocksClear:IsEnabled(),tag..": empty state and clear availability disagree")
  check(p.blocksEmpty:GetHeight()>=p.blocksEmpty:GetStringHeight(),tag..": empty-state message is clipped")
  g.Results:BlockTitle("Fixture title without a leader")
  check(p.blocksClear:IsEnabled(),tag..": title-only rules cannot be cleared")
  p.blocksClear:Fire("OnClick","LeftButton")
  check(g.Results:GetBlockedTitleCount()==0 and not p.blocksClear:IsEnabled(),tag..": clearing title-only rules changed behavior")
  p:SelectSection("general")
  check(not p.blocksCount:IsVisible() and not p.blocksClear:IsVisible() and p.blocksUnsub==nil,tag..": block header or subscription leaks into another section")
  u:Hide(true)
 end
end
print("Blocked settings layout: "..checks.." checks passed")
