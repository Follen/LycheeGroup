-- Public startup themes reach the real Find relationship menu.
local Fixture=dofile("tests/ui_fixture.lua")
local function Definition(height,revision)
 return {schema=1,id="menu.geometry",revision=revision or 1,appearance={main={elements={
  ["menu.row"]={instances={["find.socialChoice/string:friend"]={base={root={height=height}}}}},
 }}}}
end
local function Open(f)
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 local page=f.U.pages.find;page:SetFiltersOpen(true)
 page.socialChoice:Fire("OnClick","LeftButton")
 local menu=f.U.context:GetMenu()
 T.eq(menu.anchor,page.socialChoice,"the actual relationship choice owns the menu")
 return page,menu
end
local function Y(row)
 local _,a,b,_,value=row:GetPoint();return type(a)=="number" and b or value
end
local function Row(menu,value)
 for _,row in ipairs(menu.list.rows) do
  if row.key and menu.items[row.key].value==value then return row end
 end
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale,nil,nil,Definition(80));local page,menu=Open(f)
 local stride=f.U.Theme.menuRowHeight
 T.eq(Row(menu,"friend"):GetHeight(),80)
 T.eq(Y(Row(menu,"guild")),-stride-80,"the following relationship clears the configured row")
 T.eq(menu.list:GetHeight(),5*stride+80,"the popup includes the complete configured content")
 T.eq(select(2,menu.list.slider:GetMinMaxValues()),0,"all six options fit without a hidden tail")
 local row=Row(menu,"guild")
 row:Fire("OnMouseDown","LeftButton");row:Fire("OnMouseUp","LeftButton");row:Fire("OnClick","LeftButton")
 T.eq(f.G.filters.guild,true,"the visible third option retains its actual value")
 T.ok(not f.U.context:IsMenuOpen())
 T.ok(f.A.API.Theme:Import(Definition(100,2),{activate=true}))
 page.socialChoice:Fire("OnClick","LeftButton");menu=f.U.context:GetMenu()
 T.eq(Row(menu,"friend"):GetHeight(),80,"reopening cannot activate a pending menu theme")
 f.U:Hide(true)
 f=Fixture(locale,f.A.charPrefs,f.A.db);page,menu=Open(f)
 T.eq(Row(menu,"friend"):GetHeight(),100,"a real startup uses the updated menu theme")
 T.eq(Y(Row(menu,"guild")),-stride-100)
 f.U:Hide(true)

 f=Fixture(locale,nil,nil,Definition(0));page,menu=Open(f)
 T.eq(Row(menu,"friend"),nil,"a zero-height option consumes no native row")
 T.eq(Y(Row(menu,"guild")),-stride,"the next option moves into the collapsed space")
 T.eq(menu.list:GetHeight(),5*stride)
 T.eq(select(2,menu.list.slider:GetMinMaxValues()),0)
 f.U:Hide(true)

 for _,values in ipairs({{base=0,checked=80},{base=40,checked=0}}) do
  local definition={schema=1,id="menu.checked.geometry",revision=1,appearance={main={elements={
   ["menu.row"]={base={root={height=values.base}},states={checked={root={height=values.checked}}}},
  }}}}
  f=Fixture(locale,nil,nil,definition);page,menu=Open(f)
  T.eq(f.A.RuntimeTheme.error,nil,"checked geometry is a valid public startup theme")
  if values.base==0 then
   T.eq(menu.list:GetContentHeight(),80,"the checked option is measured before a native row is bound")
   T.eq(Row(menu,false):GetHeight(),80)
   T.eq(Row(menu,"friend"),nil)
   T.eq(menu.list:GetHeight(),80)
  else
   T.eq(menu.list:GetContentHeight(),200,"collapsing the current choice does not alternate between bound and unbound height")
   T.eq(Row(menu,false),nil)
   T.eq(Y(Row(menu,"friend")),0)
   local friend=Row(menu,"friend")
   friend:Fire("OnMouseDown","LeftButton");friend:Fire("OnMouseUp","LeftButton");friend:Fire("OnClick","LeftButton")
   T.eq(f.G.filters.friends,true,"remaining options keep the real filter callback")
   page.socialChoice:Fire("OnClick","LeftButton");menu=f.U.context:GetMenu()
   T.eq(menu.list:GetContentHeight(),200)
   T.eq(Row(menu,"friend"),nil,"the newly checked option collapses after reopening")
   T.eq(Y(Row(menu,false)),0,"the previously checked option returns without stale pooled state")
  end
  f.U:Hide(true)
 end
end
