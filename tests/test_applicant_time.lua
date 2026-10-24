-- Focused session-only score/time interaction: lua tests/test_applicant_time.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Member(name,score,seconds)
 return {name=name,nameKey=name,class="WARRIOR",assignedRole="DAMAGER",rating=3200,itemLevel=300,
  dungeonScores={mapScore=score,current={level=18,timed=true,durationMs=(1800-seconds)*1000,timeLimitSeconds=1800}}}
end
local function Batch(page,id)
 for _,batch in ipairs(page.batchPool) do if batch:IsShown() and batch.appID==id then return batch end end
 error("missing batch")
end
local function Click(row,key)
 local button=row.mapScoreButton;key=key or "LeftButton"
 button:Fire("OnMouseDown",key);button:Fire("OnClick",key)
end
local function Text(row)
 return (row.mapScore:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function ClockColor(ui,row,token,text)
 Check(row.mapScore:GetText()==ui:Hex(ui.Theme[token])..text:gsub("/","|r/"),"elapsed time alone uses the expected timing color")
 local r,g,b=row.mapScore:GetTextColor();local gray=ui.Theme.muted
 Check(r==gray[1] and g==gray[2] and b==gray[3],"the limit and slash retain the existing gray text color")
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true})
 local a,u,g,s=f.A,f.U,f.G,f.S
 -- Insertion is ordered by native display order so it actually migrates pool rows.
 a.Configuration:Set({["layout.tables.createApplicants.sortKey"]=false,["layout.tables.createApplicants.descending"]=false},{storage="character"})
 local alice,bob=Member("Alice-Home",471,200),Member("Bob-Home",511,30)
 alice.dungeonScores.current.durationMs=1892000;alice.dungeonScores.current.timeLimitSeconds=1920
 g.listing={activityID=2,name="Time display",comment=""}
 g.applicants={[1]={id=1,status="applied",displayOrderID=1,members={alice,bob}},[2]={id=2,status="applied",displayOrderID=2,members={Member("Carol-Home",470,90)}}}
 function g:GetApplicantTimeMargin(member)
  local scores=member.dungeonScores;local run=scores and scores.current
  if not run then return nil,scores and scores.mapScore==0 and "none" or "unknown" end
  if not run.timed or not run.durationMs then return nil,"unavailable",run end
  if not run.timeLimitSeconds then return nil,"unknown",run end
  return run.timeLimitSeconds-run.durationMs/1000,"known",run
 end
 a:Open("create");local page=u.pages.create;page.batchScroll.mouseOver=true;local batch=Batch(page,1);local row=batch.people[1]
 local originalWidth=row.mapScore:GetWidth();local originalColor={row.mapScore:GetTextColor()};local button=row.mapScoreButton
 Check(Text(row)=="471" and not row.mapScoreTime,"numeric score remains the default")
 Check(button:GetWidth()==originalWidth and button:GetHeight()==row:GetHeight(),"hit target uses the existing column and member height")
 button:Fire("OnEnter")
 Check(not u.Tooltip.owner and (not u.Tooltip.text or not u.Tooltip.text:IsShown()),"default numeric score has no tooltip")
 Click(row)
 Check(row.mapScoreTime and Text(row)=="31:32/32:00","click displays recorded duration and limit in place")
 ClockColor(u,row,"dungeonTimeGreen","31:32/32:00")
 Check(row.mapScore:GetWidth()==originalWidth,"switching text preserves column geometry")
 local bare=Member("Bare",599,45);bare.nameKey=nil
 g.applicants[3]={id=3,status="applied",displayOrderID=3,members={bare}};g:Notify("applicants")
 local bareRow=Batch(page,3).people[1];Click(bareRow);g:Notify("applicants");bareRow=Batch(page,3).people[1]
 Check(bareRow.mapScoreTime and Text(bareRow)=="29:15/30:00","a bare native name keeps time mode through ordinary applicant refresh")
 local previousAlice=Batch(page,1).people[1]
 g.applicants[4]={id=4,status="applied",displayOrderID=0,members={Member("Newcomer-Home",520,15)}};g:Notify("applicants")
 row=Batch(page,1).people[1]
 Check(row~=previousAlice and row.mapScoreTime and Text(row)=="31:32/32:00","inserting another applicant before an existing person keeps time mode across pool migration")
 ClockColor(u,row,"dungeonTimeGreen","31:32/32:00")
 Check(Batch(page,3).people[1].mapScoreTime,"bare-name time mode also survives migration to a different pool row")
 g.applicants[4]=nil;g:Notify("applicants");row=Batch(page,1).people[1]
 Check(row.mapScoreTime and Text(row)=="31:32/32:00","removing another applicant keeps the original person's time mode")
 g.applicants[3]=nil;g:Notify("applicants")
 g.applicants[3]={id=3,status="applied",displayOrderID=3,members={Member("Bare",600,20)}};g.applicants[3].members[1].nameKey=nil;g:Notify("applicants")
 Check(not Batch(page,3).people[1].mapScoreTime and Text(Batch(page,3).people[1])=="600","a retired applicant ID reused with the same bare name does not inherit its previous mode")
 g.applicants[3]=nil;g:Notify("applicants");row=Batch(page,1).people[1];button=row.mapScoreButton
 button:Fire("OnEnter")
 Check(u.Tooltip.owner==button and u.Tooltip.text.lines[1]:GetText()==(locale=="zhCN" and "18 层 31:32/32:00" or "+18 31:32/32:00"),"time mode tooltip contains only level and recorded time/limit on one line")
 Click(row)
 Check(Text(row)=="471" and not u.Tooltip.owner,"click returns to score without opening a tooltip")
 Check(not row.mapScore:GetText():find("|c",1,true),"numeric mode clears elapsed-time inline color codes")
 button:Fire("OnEnter")
 Check(not u.Tooltip.owner and not u.Tooltip.text:IsShown(),"switching back restores numeric mode with no tooltip")
 local color={row.mapScore:GetTextColor()}
 Check(color[1]==originalColor[1] and color[2]==originalColor[2] and color[3]==originalColor[3],"returning to score restores its original rarity color")
 Click(row);g:Notify("applicants");row=Batch(page,1).people[1]
 Check(row.mapScoreTime and Text(row)=="31:32/32:00","the same applicant/member keeps display mode across data refresh")
 local second=Batch(page,1).people[2];Click(second)
 Check(Text(second)=="29:30/30:00","both clock values keep their complete seconds")
 Check(second.mapScore:GetUnboundedStringWidth()<=second.mapScore:GetWidth(),"time text stays inside its original column")
 g.applicants[1].members[2]=nil;g:Notify("applicants")
 g.applicants[1].members[2]=Member("Bob-Home",511,30);g:Notify("applicants");second=Batch(page,1).people[2]
 Check(not second.mapScoreTime and second.mapScore:GetText()=="511","a member leaving and reusing the same applicant slot starts in numeric mode")
 Click(second)
 local menus=0;local open=page.OpenApplicantMenu
 page.OpenApplicantMenu=function(_,owner) Check(owner==row,"right click keeps the current member owner");menus=menus+1 end
 local mode=row.mapScoreTime;Click(row,"RightButton")
 Check(menus==1 and row.mapScoreTime==mode,"right click opens only the original member menu")
 page.OpenApplicantMenu=open
 local scoreHeader
 for _,entry in ipairs(page.applicantTable.buttons) do if entry.definition.key=="mapScore" then scoreHeader=entry end end
 scoreHeader:Fire("OnClick","LeftButton")
 Check(page.appIDs[1]==2 and page.appIDs[2]==1,"header sorting continues to use numeric map score while time text is shown")
 Check(Batch(page,1).people[1].mapScoreTime and Text(Batch(page,1).people[1])=="31:32/32:00","header sorting preserves the original member's time mode after pool rebind")
 ClockColor(u,Batch(page,1).people[1],"dungeonTimeGreen","31:32/32:00")
 Check(Batch(page,1).people[2].mapScoreTime,"sorting preserves each companion's independent time mode")
 f.Pick(page.sortChoice,"newest")
 row=Batch(page,1).people[1];button=row.mapScoreButton;if not row.mapScoreTime then Click(row) end;row.mapScoreButton:Fire("OnEnter")
 row.mapScoreButton:Fire("OnMouseDown","LeftButton")
 local replacement=Member("Replacement-Home",480,45);g.applicants[1].members[1]=replacement;g:Notify("applicants")
 local rebound=Batch(page,1).people[1]
 Check(rebound.mapScoreButton==button and not rebound.mapScoreTime and Text(rebound)=="480","recycling keeps the hit object but resets the previous person's display mode")
 Check(not rebound.mapScore:GetText():find("|c",1,true),"replacement members do not inherit the previous elapsed-time color")
 Check(not u.Tooltip.owner,"rebind closes the previous member's time tooltip")
 rebound.mapScoreButton:Fire("OnClick","LeftButton")
 Check(not rebound.mapScoreTime,"press before rebind cannot toggle the replacement member")
 replacement.dungeonScores={mapScore=0};g:Notify("applicants");Click(rebound)
 Check(Text(rebound)==(locale=="zhCN" and "无记录" or "No run"),"missing completion record has a clear short state")
 Check(not rebound.mapScore:GetText():find("|c",1,true),"missing run state does not contain a timing color")
 Click(rebound);Check(Text(rebound)=="0","a missing run can always switch back to its numeric score")
 replacement.dungeonScores.current={level=18,timed=false,durationMs=1900000,timeLimitSeconds=1800};g:Notify("applicants");Click(rebound)
 Check(Text(rebound)==(locale=="zhCN" and "无用时" or "No time"),"an unsuccessful summary is not called overtime")
 replacement.dungeonScores.current.timed=true;g:Notify("applicants")
 Check(Text(rebound)=="31:40/30:00","recorded duration is shown directly even when it exceeds the limit")
 ClockColor(u,rebound,"dungeonTimeOvertime","31:40/30:00")
 replacement.dungeonScores.current.timeLimitSeconds=nil;g:Notify("applicants")
 Check(Text(rebound)==(locale=="zhCN" and "未知" or "Unknown"),"missing limit does not fabricate a margin")
 Check(not rebound.mapScore:GetText():find("|c",1,true),"unknown limit does not retain a previous timing color")
 replacement.dungeonScores.current.timeLimitSeconds=1800
 replacement.dungeonScores.current.durationMs=nil;g:Notify("applicants")
 Check(Text(rebound)==(locale=="zhCN" and "无用时" or "No time"),"missing elapsed time remains an uncolored unavailable state")
 Check(not rebound.mapScore:GetText():find("|c",1,true),"missing elapsed time does not inherit a previous timing color")
 for _,entry in ipairs({
  {1800000,"dungeonTimeGreen","30:00/30:00"}, -- A real zero remaining margin is still known.
  {1747000,"dungeonTimeGreen","29:07/30:00"},
  {1746000,"dungeonTimeBlue","29:06/30:00"},
  {1711000,"dungeonTimeBlue","28:31/30:00"},
  {1710000,"dungeonTimePurple","28:30/30:00"},
  {1621000,"dungeonTimePurple","27:01/30:00"},
  {1620000,"dungeonTimeOrange","27:00/30:00"},
  {1801000,"dungeonTimeOvertime","30:01/30:00"},
 }) do
  replacement.dungeonScores.current.durationMs=entry[1];g:Notify("applicants")
  ClockColor(u,rebound,entry[2],entry[3])
 end
 replacement.dungeonScores.current.timeLimitSeconds=1920
 replacement.dungeonScores.current.durationMs=1703000;g:Notify("applicants")
 ClockColor(u,rebound,"dungeonTimeOrange","28:23/32:00")
 replacement.dungeonScores.current.durationMs=1788000;g:Notify("applicants")
 ClockColor(u,rebound,"dungeonTimePurple","29:48/32:00")
 rebound:Hide();Check(not rebound.mapScoreTime and not rebound.mapScoreIdentity,"hidden rows clear display identity and mode")
 rebound:Show();g:Notify("applicants");local nodes=#s.nodes
 for i=1,20 do Click(rebound) end
 Check(#s.nodes==nodes,"repeated toggles reuse the hit target without a tooltip")
 replacement.dungeonScores.current.timeLimitSeconds=1800;replacement.dungeonScores.current.durationMs=1770000;g:Notify("applicants")
 if not rebound.mapScoreTime then Click(rebound) end
 for _,scale in ipairs({70,100,130}) do
  a:SetSetting("fontScale",scale);rebound=Batch(page,1).people[1]
  Check(Text(rebound)=="29:30/30:00","font changes retain complete duration and limit")
  ClockColor(u,rebound,"dungeonTimeGreen","29:30/30:00")
  Check(rebound.mapScore:GetUnboundedStringWidth()<=rebound.mapScore:GetWidth()+.01,"both clock values fit at supported font scales")
  Check(rebound.mapScoreButton:GetHeight()==rebound:GetHeight() and rebound.mapScoreButton:GetWidth()==rebound.mapScore:GetWidth(),"hit geometry follows column/font and wrapped row changes")
 end
 local previous=rebound.mapScoreTime;page.batchScroll.mouseOver=false;Click(rebound);page.batchScroll.mouseOver=true
 Check(rebound.mapScoreTime==previous,"a clipped-away click cannot toggle another visible row")
 u.Tooltip:Hide();page.batchScroll.mouseOver=false;rebound.mapScoreButton:Fire("OnEnter");page.batchScroll.mouseOver=true
 Check(not u.Tooltip.owner and (not u.Tooltip.text or not u.Tooltip.text:IsShown()),"clipped-away hover does not create a time tooltip")
 u.hiding=true;Click(rebound);u.hiding=nil
 Check(rebound.mapScoreTime==previous,"exit animation rejects new score clicks")
 local oldIgnore,oldAddIgnore=AddIgnore,C_FriendList and C_FriendList.AddIgnore
 local ignoreCalls=0
 _G.AddIgnore=function() ignoreCalls=ignoreCalls+1 end
 if C_FriendList then C_FriendList.AddIgnore=_G.AddIgnore end
 rebound:Fire("OnClick","RightButton")
 local menu=u.context.menu;local item=menu.items[3]
 Check(item.value=="block" and item.label==(locale=="zhCN" and "荔枝笔记：拉黑玩家" or "Player Notes: Block player"),"the applicant menu identifies the Player Notes action in both languages")
 menu.list.rows[3]:Fire("OnMouseDown","LeftButton");menu.list.rows[3]:Fire("OnClick","LeftButton")
 Check(u.page=="notes" and u.pages.notes.eName.box:GetText()=="Replacement-Home","the renamed action opens notes for the clicked applicant")
 Check(u.pages.notes.typeButtons.caution.active==true,"the renamed action keeps the existing caution editor")
 Check(a.Notes:Find("Replacement-Home")==nil,"opening the editor does not save a note")
 Check(ignoreCalls==0,"the notes action does not alter the game's ignore list")
 _G.AddIgnore=oldIgnore;if C_FriendList then C_FriendList.AddIgnore=oldAddIgnore end
 a:Open("find");Check(not rebound.mapScoreTime and not rebound.member,"leaving creation releases the bound display state")
 Check(page.applicantTimeModes==nil or next(page.applicantTimeModes)==nil,"leaving creation releases the session's sparse applicant time modes")
 Check(not g.lastInvite and not g.lastDecline,"score/time clicks do not invoke applicant actions")
 u:Hide(true)
end
print("Applicant time: "..checks.." checks passed")
