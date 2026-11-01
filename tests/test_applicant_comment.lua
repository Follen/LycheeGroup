-- Real applicant hover, shared tooltip reuse and independent player notes.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true})
 local a,u,g=f.A,f.U,f.G
 local person={applicantID=81,applicantIndex=1,name="Guest-Away",nameKey="Guest-Away",class="MAGE",localizedClass="Mage",assignedRole="DAMAGER",itemLevel=335,dungeonScore=4038}
 local app={id=81,status="applied",activityID=2,comment="Ready with food and flasks.",members={person}}
 local activity=g.Catalog.GetActivity
 g.Catalog.GetActivity=function(self,id)
  if id==900 then return {id=id,categoryID=4,isPvpActivity=true,isRatedPvpActivity=true} end
  return activity(self,id)
 end
 g.listing={activityID=2,name="Recruitment"};g.applicants[81]=app
 a.Notes:Add("Guest","Away","Saved player note",nil,nil,{type="positive"})
 a:Open("create")
 local page,tip=u.pages.create,u.Tooltip
 local owner=page.batchPool[1].people[1]
 page.batchScroll.mouseOver=true;owner.tooltipArea:Fire("OnEnter")
 local view=tip.interactive
 local function Top(region) local point={region:GetPoint()};return -point[#point] end
 local function Bottom(region) return Top(region)+math.max(region:GetLineHeight(),region:GetStringHeight()) end
 local function Check(comment)
  T.ok(view.applicantCommentHeading:IsShown());T.ok(view.applicantComment:IsShown())
  T.eq(view.applicantComment:GetText(),comment)
  T.eq(view.applicantCommentHeading:GetText(),locale=="zhCN" and "申请备注" or "Application note")
  T.ok(Top(view.applicantCommentHeading)>Bottom(view.metrics[1].value))
  T.ok(Top(view.applicantComment)>Bottom(view.applicantCommentHeading))
  T.eq(view.comment:GetText(),"Saved player note","player notes keep their own content")
  T.ok(view.noteHeading:IsShown());T.eq(view.noteDivider:IsShown(),false,"personal details use spacing without a horizontal rule")
  T.ok(Top(view.noteHeading)>Bottom(view.applicantComment))
  if view.dungeonTitle:IsShown() then T.ok(Top(view.dungeonTitle)>Bottom(view.applicantComment)) end
 end
 Check(app.comment)
 -- A changed application refreshes the already-open detail, including raid/PvP.
 for _,id in ipairs({1,2,900}) do
  app.activityID=id;app.comment="Application for activity "..id;g:Notify("applicants")
  Check(app.comment)
 end
 local nodes=#f.S.nodes
 for _,scale in ipairs({70,100,130}) do
  a:SetSetting("fontScale",scale)
  app.activityID=2
  app.comment=string.rep("Long application text wraps naturally. ",20).."\nSecond paragraph."
  tip:Hide();tip:ShowPlayer(owner,person);Check(app.comment)
  T.ok(view.applicantComment:GetStringHeight()>view.applicantComment:GetLineHeight())
  T.ok(Top(view.wcl)>Bottom(view.applicantComment),"actions follow the complete note")
  for _,empty in ipairs({"","   \n\t"}) do
   app.comment=empty;tip:RefreshApplicant()
   T.eq(view.applicantCommentHeading:IsShown(),false);T.eq(view.applicantComment:IsShown(),false)
   T.eq(view.applicantComment:GetText(),"","reused tooltips release the previous application text")
  end
  local emptyHeight=tip.playerHeight
  app.comment=nil;tip:RefreshApplicant();T.eq(tip.playerHeight,emptyHeight,"missing and empty notes reserve identical space")
 end
 T.eq(#f.S.nodes,nodes,"comment length and font changes reuse the same controls")
 -- The application overview route shares its application, even without member IDs.
 person.applicantID=nil;app.comment="Shared application note";tip:Hide();tip:ShowApplicants(owner,app)
 view.memberButtons[1]:Fire("OnClick");Check(app.comment)
 tip:Hide();tip:ShowPlayer(owner,person)
 T.eq(view.applicantCommentHeading:IsShown(),false);T.eq(view.applicantComment:IsShown(),false,"ordinary player details do not inherit an application note")
 -- Another applicant without a saved note still sees their application note.
 local other={applicantID=82,applicantIndex=1,name="Other-Away",nameKey="Other-Away",class="WARRIOR",assignedRole="DAMAGER"}
 g.applicants[82]={id=82,status="applied",activityID=1,comment="Ready",members={other}}
 tip:Hide();tip:ShowPlayer(owner,other)
 T.eq(view.applicantComment:GetText(),"Ready");T.ok(view.applicantComment:IsShown());T.eq(view.noteHeading:IsShown(),false)
 tip:Hide();u:Hide(true)
end
