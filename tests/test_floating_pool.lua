-- Cold entry, background recruitment and first-hover allocation use real UI paths.
local f=dofile("tests/ui_fixture.lua")("enUS",nil,nil,{schema=1,id="fixture.floating.pool",revision=1,appearance={floating={tokens={productMedia="Interface\\AddOns\\PoolTheme\\"},elements={["floating.member"]={instances={["1:Applicant1-Home"]={base={name={alpha=.41}}}}}}}}})
local A,G=f.A,f.G
RAID_CLASS_COLORS={MAGE={r=.4,g=.6,b=.9}}
dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
local F=A.Floating
local count=0
local function Check(value,message) count=count+1;assert(value,message) end
F:Bind(G);F:UpdateSettings()
Check(#F.rows==0 and #F.batches==0,"idle startup builds the entry without allocating invisible cards")
local function Applicant(id)
 return {id=id,status="applied",displayOrderID=id,members={{name="Applicant"..id.."-Home",nameKey="Applicant"..id.."-Home",class="MAGE",assignedRole="DAMAGER",specID=63}}}
end
G.listing={activityID=2,name="Pool fixture"}
for id=1,4 do G.applicants[id]=Applicant(id) end
G:Notify("listing");G:Notify("applicants")
Check(F.count:GetText()=="4 applicants" or F.count:GetText():find("4",1,true),"background recruitment keeps the complete applicant count")
Check(#F.rows==0 and #F.batches==0 and not F.panel:IsShown(),"background recruitment does not construct cards before hover")
F:ShowPanel()
Check(#F.entries==8 and #F.rows==8 and #F.batches==4,"first hover builds exactly the four visible member cards and their action footers")
for _,row in ipairs(F.rows) do
 if row.kind=="member" then
  Check(row.invite==nil and row.decline==nil and row.cancel==nil and row.leader==nil and row.timer==nil and row.background==nil,"member rows allocate no action, application or separate-card branch")
 else Check(row.icon==nil and row.meta==nil and row.score==nil and row.faction==nil and row.itemLevel==nil and row.memberLayout==nil and row.applicationLayout==nil,"footer rows allocate no member or application branch") end
end
local nodes=#f.S.nodes
for _=1,10 do F:ShowPanel() end
Check(#f.S.nodes==nodes,"repeated hover reuses the actual visible card pool")
local key="1:Applicant1-Home"
Check(A.API.Appearance.SetElement==nil,"runtime element mutation is not exposed")
Check(math.abs(F.rows[1].name:GetAlpha()-.41)<.001,"the keyed member override reaches its live text")
F:ApplyFont(A.Fonts:GetPath(),1.3)
Check(math.abs(select(2,F.rows[1].name:GetFont())-F.context:GetFontSize("floatingMemberNameFont"))<.001,"font changes reach existing lazy rows")
Check(A.API.Appearance.Set==nil,"runtime token mutation is not exposed")
Check(F.rows[2].invite.glyph:GetTexture()=="Interface\\AddOns\\PoolTheme\\invite.tga","startup product art reaches action footers")
for id=5,20 do G.applicants[id]=Applicant(id) end
G:Notify("applicants")
Check(#F.entries==40,"twenty applicants preserve all forty member/footer entries")
Check(#F.rows<#F.entries,"a long list allocates only its visible window")
F:SetOffset(math.max(0,F.body:GetHeight()-F.scroll:GetHeight()),false)
local last=false
for _,row in ipairs(F.rows) do if row:IsShown() and row.name:GetText()=="Applicant20-Home" then last=true end end
Check(last,"scrolling reaches applicants beyond the former fourteen-row startup pool")
F:SetOffset(0,false)
Check(math.abs(F.rows[1].name:GetAlpha()-.41)<.001,"scroll reuse restores the correct member's keyed override")
F:Dismiss();local retainedNodes=#f.S.nodes
G:Notify("applicants")
Check(#f.S.nodes==retainedNodes and not F.panel:IsShown(),"hidden updates reuse the established pool without allocating more rows")
local listing=G.listing
G.listing=nil
for index=1,3 do G.apps[index]={id=100+index,status="applied",name="Outgoing "..index,activityName="Dungeon",activityID=2,expiresAt=500} end
G:Notify("listing");F:ShowPanel()
Check(#F.entries==3,"switching modes keeps all outbound applications")
for index=1,3 do
 local row=F.rows[index]
 Check(row.kind=="application" and row.cancel and row.leader and row.timer and not row.invite and not row.itemLevel and not row.faction and not row.memberLayout and not row.footerLayout,"outbound applications allocate their own complete branch only")
end
F:Dismiss();G.listing=listing;G:Notify("listing");F:ShowPanel()
F:SetOffset(math.max(0,F.body:GetHeight()-F.scroll:GetHeight()),false);F:SetOffset(0,false)
F:Dismiss();G.listing=nil;G:Notify("listing");F:ShowPanel()
retainedNodes=#f.S.nodes
for _=1,5 do
 F:Dismiss();G.listing=listing;G:Notify("listing");F:ShowPanel()
 F:SetOffset(math.max(0,F.body:GetHeight()-F.scroll:GetHeight()),false);F:SetOffset(0,false)
 F:Dismiss();G.listing=nil;G:Notify("listing");F:ShowPanel()
end
Check(#f.S.nodes==retainedNodes,"repeating long recruitment scrolls and outbound applications reuses typed native pools without accumulating branch objects")
F:Dismiss()
print("Floating lazy pool checks passed: "..count)
