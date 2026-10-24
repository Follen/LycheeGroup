-- Native Frame geometry for shared menu theme rules; no player settings or business actions.
local probe=...
local Library=LycheeUI
if not Library or Library.version<38 or InCombatLockdown() then return probe:Fail("requires_r38_out_of_combat") end
local parent,ctx
assert(probe:OnCleanup(function()
 if ctx then ctx:Hide() end
 if parent then parent:Hide() end
end))
parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(800,600);parent:SetPoint("CENTER")
local prefix="native.menu.anchor/"
ctx=Library:CreateContext({parent=parent,reducedMotion=true,elements={["menu.row"]={
 instances={
  [prefix.."string:one"]={base={root={height=80}},states={checked={root={height=0}}}},
  [prefix.."string:two"]={base={root={height=0}}},
 },
 states={selected={root={height=120}},disabled={root={height=0}}},
}}})
local anchor=ctx.C.ChoiceTrigger(parent,200);anchor:SetPoint("TOPLEFT",20,-20)
ctx.C.Element(anchor,"native.menu.anchor")
local entries={{value="one",label="Native tall row"},{value="two",label="Collapsed row"},{value="three",label="Selected row"}}
local function Row(menu,key)
 for _,row in ipairs(menu.list.rows) do if row.key==key then return row end end
end
local function Y(row) local _,relative,point,_,value=row:GetPoint();return type(relative)=="number" and point or value end
local function Near(a,b) return math.abs(a-b)<.01 end
ctx:OpenMenu(anchor,entries,nil,{selectedValue="three"})
local menu=ctx:GetMenu()
local first,last=assert(Row(menu,1)),assert(Row(menu,3))
probe:Log(string.format("mixed first=%.9f last=%.9f y=%.9f content=%.9f viewport=%.9f",first:GetHeight(),last:GetHeight(),Y(last),menu.list:GetContentHeight(),menu.list:GetHeight()))
assert(not Row(menu,2),"zero height must omit the second item")
assert(Near(first:GetHeight(),80) and Near(last:GetHeight(),120) and Near(Y(last),-80),"native mixed row geometry")
assert(menu.list:GetContentHeight()==200 and Near(menu.list:GetHeight(),200),"native mixed viewport geometry")
assert(ctx.elements[first].key==prefix.."string:one" and last.key==3,"element and business identity")
local report={build=select(2,GetBuildInfo()),libraryRevision=Library.version,scope="isolated_native_menu_geometry",
 mixed={firstHeight=first:GetHeight(),lastHeight=last:GetHeight(),lastY=Y(last),contentHeight=menu.list:GetContentHeight(),viewport=menu.list:GetHeight(),zeroCollapsed=true}}
ctx:CloseMenu()
assert(not menu:IsShown() and not menu.catcher:IsShown() and not ctx:GetMenuAnchor(),"close releases menu ownership")
local many={};for index=1,100 do many[index]={value=index,label="Native row "..index} end
ctx:OpenMenu(anchor,many,nil,{selectedValue=100})
menu=ctx:GetMenu();last=assert(Row(menu,100))
local maximum=select(2,menu.list.slider:GetMinMaxValues())
assert(menu.list:GetContentHeight()==4080 and Near(last:GetHeight(),120),"offscreen selected height")
assert(Near(menu.list.pixelOffset,maximum) and last._hitVisible and #menu.list.rows<20,"last item is reachable with a bounded pool")
local pool=#menu.list.rows
menu.list:SetPixelOffset(0,false);assert(Row(menu,1) and not Row(menu,100),"scroll to first item")
menu.list:SetPixelOffset(maximum,false);assert(Row(menu,100) and #menu.list.rows==pool,"scroll reuses native rows")
report.long={contentHeight=menu.list:GetContentHeight(),viewport=menu.list:GetHeight(),scrollMaximum=maximum,pool=pool,lastReachable=true}
ctx:CloseMenu()
entries[1].checked=true
ctx:OpenMenu(anchor,entries)
assert(not Row(menu,1) and not Row(menu,2) and Row(menu,3) and menu.list:GetContentHeight()==40,"checked item collapses before binding")
ctx:CloseMenu();entries[1].checked=false;entries[1].disabled=true
ctx:OpenMenu(anchor,entries)
assert(not Row(menu,1) and menu.list:GetContentHeight()==40,"disabled item collapses before binding")
ctx:CloseMenu();entries[1].disabled=false
ctx:OpenMenu(anchor,entries)
assert(Row(menu,1) and Row(menu,1):IsEnabled() and not Row(menu,1)._checked and menu.list:GetContentHeight()==120,"reopen clears old stable states")
report.states={checkedCollapsed=true,disabledCollapsed=true,restoredHeight=menu.list:GetContentHeight()}
ctx:CloseMenu();ctx:Hide();parent:Hide()
assert(not menu:IsShown() and not menu.catcher:IsShown() and ctx.Motion:Count()==0,"menu cleanup")
report.closed=true
return report
