-- Fixed startup element rules through real result and application renderers.
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local f=dofile("tests/ui_fixture.lua")("zhCN",nil,nil,{schema=1,id="fixture.find.elements",revision=1,appearance={main={elements={
 ["find.quickRole"]={instances={tankPresence={base={root={width=160},label={fontSize=24}}}}},
 ["find.result"]={instances={
  [1]={base={root={height=140},description={color={.12,.34,.56,1}},title={alpha=.3}}},
  [20]={base={root={height=180}}},
 }},
}}}})
local A,U,G=f.A,f.U,f.G
A:SetSetting("reduceMotion",true);A:Open("find")
local P=U.pages.find
P:LayoutQuickFilters()
check(math.abs(P.quickChoices.tankPresence.button:GetWidth()-160)<.001,"fixed instance widths participate in initial layout")
check(math.abs(select(2,P.quickChoices.tankPresence.button.label:GetFont())-U.context:GetFontSize(24))<.001,"fixed instance typography uses the current user scale")
for id=1,20 do G.records[id]={id=id,name="Element group "..id,leaderName="Element-Away",activity=G.Catalog:GetActivity(2),activityID=2,categoryID=2,maxNumPlayers=5,numMembers=1,age=id,comment="Description",details={members={},counts={TANK=0,HEALER=0,DAMAGER=1}}} end
P:CommitChoice();P:DoSearch()
local row=P.results.rows[1]
check(row.key==1 and math.abs(row.title:GetAlpha()-.3)<.001,"fixed business-key styles apply when the result first arrives")
check(math.abs(row:GetHeight()-140)<.001,"fixed instance height participates in the first result's geometry")
check(math.abs(row.description.color[1]-.12)<.001,"business rendering preserves the fixed custom description color")
P.results:SetPixelOffset(100000,false)
check(row.key~=1 and math.abs(row.title:GetAlpha()-1)<.001,"pool rebind removes the previous key's fixed instance override")
local final;for _,item in ipairs(P.results.rows) do if item.key==20 then final=item end end
check(final and math.abs(final:GetHeight()-180)<.001,"virtualization reaches the last keyed row with its distinct fixed height")
P.results:SetPixelOffset(0,false)
check(P.results.rows[1].key==1 and math.abs(P.results.rows[1].title:GetAlpha()-.3)<.001,"scrolling back restores the same key's fixed theme")
local before=#f.S.nodes
P:ReflowMetrics(U.content:GetWidth(),U.content:GetHeight())
check(#f.S.nodes==before,"metric reflow preserves the existing row and header objects")
U:Hide(true)
print("Fixed Find elements: "..checks.." checks passed")
