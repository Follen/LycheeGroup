-- Exercise actual player detail controllers and record action callbacks.
local f=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=true})
local A,U,G=f.A,f.U,f.G
f.base.SetUnit("player",{name="Self",realm="Home",class="WARRIOR",classID=1,guid="Player-self"})
local tip=U.Tooltip
local context=A.GroupPresentation.Member("roster")
local own={name="Self",realm="Home",nameKey="Self-Home",guid="Player-self",unit="player",class="WARRIOR",isSelf=true}
local other={name="Other",realm="Away",nameKey="Other-Away",guid="Player-other",class="MAGE"}
G.GetRoster=function() return {own,other} end
A:Open("create")
local page=U.pages.create
page.rosterList.clip.mouseOver=true
page.rosterList.rows[1].tooltipArea:Fire("OnEnter")
T.eq(tip.member,nil,"the actual self row hover never opens details")
tip:Hide();tip:ShowPlayer(U.frame,own,context)
T.eq(tip.member,nil,"hovering self must not open player details")
T.ok(not tip.interactive or not tip.interactive:IsShown(),"self hover has no tooltip")
tip:ShowRoster(U.frame,G:GetRoster(),false,{rosterMode="groups"})
local selfButton
for _,button in ipairs(tip.interactive.memberButtons) do if button.member==own then selfButton=button end end
T.ok(selfButton,"self remains in roster overview")
selfButton:Fire("OnClick","LeftButton")
T.eq(tip.member,nil,"clicking self in group overview must not open details")
T.ok(tip.sourceRoster,"self click preserves the group overview")
tip:Hide()
tip:ShowPlayer(U.frame,{nameKey="sELF-hOME",class="WARRIOR"},context)
T.eq(tip.member,nil,"identity fallback blocks self without live roster flags")
tip:ShowPlayer(U.frame,other,context)
T.eq(tip.member,other,"other players keep their details")
local scoreReads=0
G.listing={activityID=77}
G.Catalog.GetActivity=function(_,id) return {id=id,isMythicPlusActivity=true} end
G.GetRosterDungeonScores=function(_,member,activityID)
 T.eq(member,other);T.eq(activityID,77);scoreReads=scoreReads+1
 return {mapScore=280,current={name="当前副本",level=10,timed=true,durationMs=1200000,timeLimitSeconds=1800},best={name="最高副本",level=14,timed=false,durationMs=1900000,timeLimitSeconds=1800}}
end
tip:RenderPlayer(other,false)
T.eq(scoreReads,1,"roster detail queries current and best runs")
T.eq(tip.interactive.metrics[2].title:GetText(),"单本分")
T.eq(tip.interactive.metrics[2].value:GetText(),"280")
T.eq(tip.interactive.dungeonRows[1].name:GetText(),"当前副本")
T.eq(tip.interactive.dungeonRows[2].name:GetText(),"最高副本")
T.eq(tip.interactive.dungeonRows[2].keyLevel:GetText(),"+14")
T.ok(tip.interactive.dungeonRows[2].status:GetText():find("31:40",1,true),"best run renders actual time")
G.GetRosterDungeonScores=function() return nil end
tip:RenderPlayer(other,false)
T.ok(tip.interactive.dungeonEmpty:IsShown(),"missing runs show the existing unknown state")
T.ok(not tip.interactive.dungeonRows[2]:IsShown(),"missing data clears previous best run")
local opened=0;local open=A.Open
A.Open=function() opened=opened+1 end
tip.member=own
tip.interactive.note:Fire("OnClick","LeftButton")
T.eq(opened,0,"stale record action cannot open self editor")
tip.member=other
tip.interactive.note:Fire("OnClick","LeftButton")
T.eq(opened,1,"record action remains available for other players")
A.Open=open
other.isSelf=true
tip:RenderPlayer(other,false)
T.eq(tip.member,nil,"a refreshed self identity closes previously open details")
T.ok(not tip.interactive:IsShown(),"refresh cannot retain stale player details")
other.isSelf=nil
local ok=A.Notes:Add("SELF","HOME","self note")
T.eq(ok,false,"record storage continues rejecting self")
T.eq(A.Notes:Find("Self-Home"),nil)
tip:Hide()
