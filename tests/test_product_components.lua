-- Product-owned role, roster and creation controllers compose generic LycheeUI.
local f=dofile("tests/ui_fixture.lua")("enUS",nil,nil,{schema=1,id="fixture.product.components",revision=1,appearance={main={elements={
 ["create.groupStrip"]={base={["countIcon:TANK"]={alpha=.37},["member:1"]={alpha=.29}}},
 ["member.marks"]={instances={
  ["Marked-Home"]={base={["icons/friend"]={alpha=.31,shown=false}}},
  ["Other-Home"]={base={["icons/friend"]={alpha=.74}}},
  [777]={base={["icons/friend"]={shown=false}}},
 }},
}}}})
local A,U,G=f.A,f.U,f.G
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
A:SetSetting("reduceMotion",true)
for _,name in ipairs({"SetMemberIcon","SetRoleIcon","SetActivityIcon","StyleMemberIcon"}) do
 Check(LycheeUI.Context[name]==nil,"shared Context has no product API: "..name)
 Check(rawget(U.context,name)==nil,"product does not patch a business resolver onto Context: "..name)
end
Check(U.C.Roster==nil and U.C.RoleButton==nil,"shared constructors contain no roster or role widget")
local markDefinition,orphanMark
for _,entry in ipairs(A.API.Appearance:ListElementDefinitions("main","members")) do
 if entry.id=="member.marks" then markDefinition=entry end
 if entry.id=="member.mark" then orphanMark=entry end
end
Check(markDefinition and markDefinition.template and not orphanMark,"the member directory exposes the bound marks template without an unused mark element")
local roster=U:CreateRoster(UIParent,23,5)
local members={
 {name="Damage one",class="MAGE",assignedRole="DAMAGER",specID=63},
 {name="Tank",class="WARRIOR",assignedRole="TANK",specID=73},
 {name="Healer",class="PRIEST",assignedRole="HEALER",specID=257},
 {name="Damage two",class="WARLOCK",assignedRole="DAMAGER",specID=266},
}
roster:Update(members,nil,5,true)
Check(members[1].name=="Damage one" and members[2].name=="Tank","roster sorting does not mutate the source array")
for index,source in ipairs({2,3,1,4}) do
 local expected=U.C.GameIcon(UIParent,23);U:SetMemberIcon(expected,members[source])
 Check(roster.slots[index].icon:GetTexture()==expected:GetTexture(),"roster stable role order: "..index)
end
Check(not roster.slots[5].icon:IsShown() and roster.slots[5].role:IsShown(),"fixed party composition fills only the missing damage slot")
Check(roster.slots[5].role:GetTexture()==U.Theme.productMedia.."role-dps.tga","empty party role art belongs to the product")
local role=roster.slots[5].role
local setPoint,setSize=role.SetPoint,role.SetSize
local writes=0
role.SetPoint=function(self,...) writes=writes+1;return setPoint(self,...) end
role.SetSize=function(self,...) writes=writes+1;return setSize(self,...) end
roster:Update(members,nil,5,true)
Check(writes==0,"unchanged fixed-role updates reuse their geometry")
role:ClearAllPoints();role:SetPoint("CENTER",roster,0,0);writes=0
roster:Update(members,nil,5,true)
Check(writes>0 and select(2,role:GetPoint())==roster.slots[5].icon,"roster repairs role geometry changed by a prior consumer")
roster:Update(nil,{TANK=2,HEALER=4,DAMAGER=14},20)
for index,value in ipairs({2,4,14}) do
 Check(roster.counts[index].text:GetText()==tostring(value),"large groups keep the complete role count")
 Check(not roster.slots[index].icon:IsShown(),"large groups release individual portraits")
end
U:Element(roster,"create.groupStrip","create")
for index=1,5 do
 Check(roster.elementSlots["member:"..index]==roster.slots[index].icon,"product explicitly maps portrait slots")
 Check(roster.elementSlots["memberRole:"..index]==roster.slots[index].role,"product explicitly maps portrait role slots")
end
Check(roster.elementSlots["countText:TANK"]==roster.counts[1].text,"product explicitly maps role count slots")
Check(math.abs(roster.counts[1].icon:GetAlpha()-.37)<.001,"startup role-count styling survives generic slot resolution")
Check(math.abs(roster.slots[1].icon:GetAlpha()-.29)<.001,"startup portrait styling survives generic slot resolution")
A:Open("create")
local page=U.pages.create
LFGListFrame.EntryCreation.Name:UserType("Boundary fixture")
local refresh,refreshCalls=page.RefreshMode,0
page.RefreshMode=function(self,...) refreshCalls=refreshCalls+1;return refresh(self,...) end
page:Submit()
Check(G.published~=nil and page.manage:IsShown(),"actual Submit reaches Publish and enters applicant management")
Check(refreshCalls==1,"synchronous listing notification finishes the submit mode once")
local render,renderCalls=page.RenderBatches,0
page.RenderBatches=function(self,...) renderCalls=renderCalls+1;return render(self,...) end
G.applicants[1]={id=1,status="applied",displayOrderID=1,members={{name="One-Home",nameKey="One-Home",class="MAGE",assignedRole="DAMAGER"}}}
G:Notify("applicants")
Check(renderCalls==1 and page.batchPool[1].people[1].member==G.applicants[1].members[1],"applicant event lays out and binds the visible batch once")
local scopeApply,applyCalls=U.context.ApplyElements,0
U.context.ApplyElements=function(self,scope) if scope=="members" then applyCalls=applyCalls+1 end;return scopeApply(self,scope) end
local identity=U.Members:Create(UIParent)
U.Members:Bind(identity,members[1],300,false,false)
Check(applyCalls==0,"binding one identity does not reapply every other member's overrides")
local marked={name="Marked",nameKey="Marked-Home",class="MAGE",assignedRole="DAMAGER",isCharFriend=true}
U.Members:Bind(identity,marked,300,false,false)
Check(math.abs(identity.marks.icons.friend:GetAlpha()-.31)<.001,"member cards apply the current identity's mark instance")
U.Members:BindRoster(identity,marked,300,false,false)
Check(math.abs(identity.marks.icons.friend:GetAlpha()-.31)<.001,"roster member cards retain the current identity's mark instance")
local friendIcon=identity.marks.icons.friend
local other={name="Other",nameKey="Other-Home",class="MAGE",assignedRole="DAMAGER",isCharFriend=true}
U.Members:BindRoster(identity,other,300,false,false)
Check(identity.marks.icons.friend==friendIcon and math.abs(friendIcon:GetAlpha()-.74)<.001,"reused mark slots switch to the new member's instance")
Check(friendIcon:IsShown(),"a new friend's default visibility replaces the previous instance's hidden rule")
local ordinary={name="Ordinary",nameKey="Ordinary-Home",class="MAGE",assignedRole="DAMAGER",isCharFriend=true}
U.Members:Bind(identity,ordinary,300,false,false)
Check(math.abs(friendIcon:GetAlpha()-1)<.001,"an unconfigured member does not inherit the previous mark instance")
U.Members:Bind(identity,marked,300,false,false)
U.Members:ClearMarks(identity.marks)
Check(identity.marks.elementKey==nil and not identity.marks:IsShown() and not friendIcon:IsShown(),"clearing marks releases the member identity and hides its slots")
Check(math.abs(friendIcon:GetAlpha()-1)<.001,"clearing marks restores the unkeyed style before reuse")
U.Members:BindRoster(identity,marked,300,false,false)
Check(identity.marks.icons.friend==friendIcon and math.abs(friendIcon:GetAlpha()-.31)<.001,"cleared marks reuse their slots with the rebound member's instance")
local guildOnly={name="Guild",nameKey="Guild-Home",class="MAGE",assignedRole="DAMAGER",isGuildMate=true}
for _,method in ipairs({"Bind","BindRoster"}) do
 U.Members[method](U.Members,identity,marked,300,false,false)
 Check(not friendIcon:IsShown(),method.." applies the marked friend's hidden instance")
 U.Members[method](U.Members,identity,guildOnly,300,false,false)
 Check(not friendIcon:IsShown() and identity.marks.icons.guild:IsShown(),method.." releases the old instance before hiding unused relationship slots")
 U.Members[method](U.Members,identity,ordinary,300,false,false)
 Check(friendIcon:IsShown() and not identity.marks.icons.guild:IsShown(),method.." restores a default friend's visibility after the guild-only binding")
end
local groupMarks=U.Members:CreateMarks(UIParent)
U.Members:BindGroupMarks(groupMarks,{id=777,charFriends=1})
local groupFriend=groupMarks.icons.friend
Check(not groupFriend:IsShown(),"group marks apply the result instance's hidden friend rule")
U.Members:ClearMarks(groupMarks)
Check(not groupFriend:IsShown() and not groupMarks:IsShown(),"explicit clear keeps every mark hidden after releasing a visibility override")
U.Members:BindGroupMarks(groupMarks,{id=777,charFriends=1})
U.Members:BindGroupMarks(groupMarks,{id=778,guildMates=1})
Check(not groupFriend:IsShown() and groupMarks.icons.guild:IsShown(),"reused group marks show only the new result's guild relationship")
U.Members:BindGroupMarks(groupMarks,{id=779,charFriends=1})
Check(groupFriend:IsShown() and not groupMarks.icons.guild:IsShown(),"group marks restore default friend visibility when it is needed again")
U:Hide(true)
print("Product component checks passed: "..checks)
