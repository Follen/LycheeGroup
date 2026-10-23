-- Pending themes cannot alter existing or late-built product controls.
local fixture=dofile("tests/ui_fixture.lua")
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function Theme(id,alpha)
 return {schema=1,id=id,revision=1,appearance={
  main={tokens={brand={alpha,.2,.3,1}},
   components={button={base={label={alpha=alpha}},states={hover={label={alpha=alpha/2}}}}},
   utilities={resultTone={base={title={alpha=alpha}}}},
   elements={["settings.row"]={instances={font={base={label={alpha=alpha}}}}},["find.result"]={classes="resultTone"},
    ["host.resize"]={base={root={alpha=alpha}},states={hover={root={alpha=alpha/2}},pressed={root={alpha=alpha/4}}}},
    ["tooltip.rich"]={base={root={alpha=alpha}},states={hover={root={alpha=alpha/2}}}},
   },
  },
  floating={elements={["floating.member"]={base={name={alpha=alpha}}}},
 }}}
end
local f=fixture("enUS",nil,nil,Theme("fixture.before",.43))
local A,U,G=f.A,f.U,f.G
A:SetSetting("reduceMotion",true);A:Open("settings")
local label=U.pages.settings.controls.font.frame.label
local grip=U.resizeHandle
local function Alpha(target,value,message) check(math.abs(target:GetAlpha()-value)<.001,message) end
Alpha(grip,.43,"the resize handle applies its startup rule")
grip:Fire("OnEnter");Alpha(grip,.43/2,"resize hover survives product input scripts")
check(grip.inside==true,"resize hover also preserves product feedback")
grip:Fire("OnMouseDown","RightButton");Alpha(grip,.43/4,"resize pressed state survives product input scripts")
check(U.resizing==nil,"right-click keeps the product resize action inactive")
grip:Fire("OnMouseUp","RightButton");Alpha(grip,.43/2,"resize release restores hover")
grip:Fire("OnLeave");Alpha(grip,.43,"resize pointer exit restores the startup rule")
grip:Fire("OnEnter");grip:Hide();Alpha(grip,.43,"hidden resize handles clear fixed interaction state")
check(grip.inside==nil,"hidden resize handles also clear product hover")
grip:Show();Alpha(grip,.43,"a reused resize handle starts idle")
U.Tooltip:BuildInteractive()
local rich=U.Tooltip.interactive
rich:Show();Alpha(rich,.43,"rich tooltips apply their startup rule")
rich:Fire("OnEnter");Alpha(rich,.43/2,"rich tooltip hover survives product pointer scripts")
rich:Fire("OnLeave");Alpha(rich,.43,"rich tooltip exit restores its startup rule")
rich:Fire("OnEnter");rich.scroll.scrollTarget=12;U.Tooltip.outsideClicks:Show();rich:Hide()
Alpha(rich,.43,"hidden rich tooltips clear fixed interaction state")
check(rich.scroll.scrollTarget==nil and not U.Tooltip.outsideClicks:IsShown(),"tooltip hiding preserves product scroll and outside-click cleanup")
rich:Show();Alpha(rich,.43,"a reused rich tooltip starts idle");rich:Hide()
local early=U.C.Button(U.frame,"Early",80)
check(math.abs(label:GetAlpha()-.43)<.001,"startup rules apply to the first built page")
check(math.abs(early.label:GetAlpha()-.43)<.001,"startup component recipes are compiled before control creation")
check(A.API.Theme:Import(Theme("fixture.after",.71),{activate=true}),"a valid import records the next startup theme")
check(math.abs(label:GetAlpha()-.43)<.001 and U.Theme.brand[1]==.43,"import leaves existing controls and their context unchanged")
check(A.API.Appearance.Set==nil and A.API.Appearance.SetElements==nil and U.context.SetTheme==nil,"general live appearance mutation APIs are absent")
local late=U.C.Button(U.frame,"Late",80)
check(math.abs(early.label:GetAlpha()-.43)<.001 and math.abs(late.label:GetAlpha()-.43)<.001,"existing and late component recipes ignore the pending import")
late:Fire("OnEnter")
check(math.abs(late.label:GetAlpha()-.43/2)<.001,"interactive states continue to use the fixed startup recipe")
late:Fire("OnLeave")
check(math.abs(late.label:GetAlpha()-.43)<.001,"leaving a state restores the startup recipe")
G.records[1]={id=1,name="Late result",categoryID=2,activityID=2,activity=G.Catalog:GetActivity(2),maxNumPlayers=5,numMembers=1,age=0,details={members={},counts={TANK=1,HEALER=0,DAMAGER=0}}}
A:Open("find");local find=U.pages.find;find:CommitChoice();find:DoSearch()
check(math.abs(find.results.rows[1].title:GetAlpha()-.43)<.001,"late-created result rows use the same startup theme")
RAID_CLASS_COLORS={MAGE={r=.4,g=.6,b=.9}}
G.listing={activityID=2,name="Late listing"};G.applicants[1]={id=1,status="applied",members={{name="Late-Home",class="MAGE",assignedRole="DAMAGER"}}}
dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua");A.Floating:UpdateSettings();A.Floating:ShowPanel()
check(math.abs(A.Floating.rows[1].name:GetAlpha()-.43)<.001,"a context first created after import still consumes the startup snapshot")
local base=select(2,U.brandTitle:GetFont())
A:SetSetting("fontScale",130)
check(math.abs(select(2,U.brandTitle:GetFont())-base*1.3)<.001,"user font settings remain immediate with a pending theme")
check(U.Theme.brand[1]==.43 and math.abs(label:GetAlpha()-.43)<.001,"font changes do not activate pending appearance")
local before=U.windowWidth;U:SetWindowSize(before+100,U.windowHeight)
check(U.windowWidth~=before,"user window resizing remains immediate")
local saved,preferences=A.db,A.charPrefs
U:Hide(true)
local nextSession=fixture("enUS",preferences,saved)
nextSession.A:Open("settings")
check(math.abs(nextSession.U.pages.settings.controls.font.frame.label:GetAlpha()-.71)<.001,"a new startup applies the selected imported theme")
check(nextSession.U.Theme.brand[1]==.71,"the reloaded context has the new tokens")
local reloaded=nextSession.U.C.Button(nextSession.U.frame,"Reloaded",80)
check(math.abs(reloaded.label:GetAlpha()-.71)<.001,"reload installs the imported component recipe")
nextSession.U:Hide(true)
print("Deferred product theme: "..count.." checks passed")
