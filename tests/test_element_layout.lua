-- Startup rules keep geometry, pooled identities and native input ownership.
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local f=dofile("tests/ui_fixture.lua")("zhCN",nil,nil,{schema=1,id="fixture.element.layout",revision=1,appearance={main={elements={
 ["settings.row"]={instances={font={base={control={width=300},label={width=150}}}}},
 ["notes.record"]={instances={["ElementOne-Away"]={base={title={alpha=.3}}}}},
 ["native.creation.title"]={base={root={alpha=.4,fontSize=27}}},
}}}})
local A,U=f.A,f.U
A:SetSetting("reduceMotion",true);A:Open("settings")
local holder=U.pages.settings.controls.font.frame
check(math.abs(holder.control:GetWidth()-300)<.001 and math.abs(holder.label:GetWidth()-150)<.001,"startup instance geometry survives settings layout")
A.Notes:Add("ElementOne","Away","first");A.Notes:Add("ElementTwo","Away","second")
A:Open("notes");local notes=U.pages.notes
local row;for _,item in ipairs(notes.list.rows) do if item.key=="ElementOne-Away" then row=item end end
check(row and math.abs(row.title:GetAlpha()-.3)<.001,"real note identities receive their startup instance rules")
notes.list:SetItems({"ElementTwo-Away"},function(item)U:SetText(item.title,"second")end)
check(notes.list.rows[1].key=="ElementTwo-Away" and math.abs(notes.list.rows[1].title:GetAlpha()-1)<.001,"pooled notes discard the previous identity's style")
A:Open("create");local lease=U.Native.titleInput
check(lease and math.abs(lease.box:GetAlpha()-.4)<.001,"startup native styling applies only after its real lease is owned")
check(math.abs(select(2,lease.box:GetFont())-U.context:GetFontSize(27))<.001,"leased native typography uses the startup declaration")
U:Hide(true);lease.box:SetAlpha(.9);U.C.ApplyElement(lease.box)
check(math.abs(lease.box:GetAlpha()-.9)<.001,"released native inputs cannot be repainted by the former theme binding")
check(U.ElementMethods==nil,"method-wide hot-update wrappers are removed")
print("Startup element layout: "..checks.." checks passed")
