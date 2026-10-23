-- The status entry remains usable before the UI business package is loaded.
local base=dofile("tests/stubs.lua");base.Install({locale="zhCN",realm="Home"})
local stub=dofile("tests/ui_stubs.lua");stub.Install()
_G.LycheeUI=nil
local libraryPrivate={}
for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Styles.lua","Components.lua","Layouts.lua","Elements.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",libraryPrivate) end
_G.LycheeGroup=nil;_G.LycheeGroupDB=nil
for _,file in ipairs({"Locale.lua","Theme/Defaults.lua","Theme/Elements.lua","Core.lua","Configuration.lua","Appearance.lua","Theme/Import.lua","Specializations.lua","Fonts.lua","BrandMotion.lua","Floating.lua","API.lua"}) do dofile("addon/LycheeGroup/"..file) end
local A=LycheeGroup;local API=A.API.Floating
local startupNotifications=0
local stopStartup=API:Subscribe(function(status)
 startupNotifications=startupNotifications+1
 T.eq(status.available,false,"subscribing before the database is ready immediately reports unavailable")
end)
T.eq(API.version,1);T.eq(startupNotifications,1)
A:LoadDB();T.eq(API:IsAvailable(),false,"database loading alone does not publish a host before the floating UI exists")
stopStartup()
local apps={{id=1,name="A group",status="applied",activityID=1,activityName="A dungeon",leaderName="Leader-Away",expiresAt=130},{id=2,name="An invitation",status="invited",activityID=1}}
local members={};for i=1,30 do members[i]={name="Player"..i.."-Away",nameKey="Player"..i.."-Away",class="WARRIOR",specID=71,dungeonScore=2000+i,itemLevel=500+i} end
dofile("addon/LycheeGroup_Group/Group.lua");local resolveSpec=A.Group.ResolveMemberSpec
dofile("addon/LycheeGroup/Presentation.lua")
local listing,callback
local nativeListing
C_LFGList.HasActiveEntryInfo=function() if nativeListing~=nil then return nativeListing end;return listing~=nil end
local manageApplicants,manageListing=true,true
local applicant={status="applied",members=members,comment="A shared application note"}
local G={ResolveMemberSpec=resolveSpec,Applications={GetActiveCount=function() return #apps end,IsActive=function() return true end},GetListing=function() return listing end,GetApplications=function() return apps end,
 GetApplicants=function() return {77} end,GetApplicant=function() return applicant end,Subscribe=function(_,fn) callback=fn;return function() end end}
local activities={[1]={categoryID=2,maxNumPlayers=5},[2]={categoryID=3,maxNumPlayers=30},[3]={categoryID=4,maxNumPlayers=3}}
G.Catalog={GetActivity=function(_,id) return activities[id] end}
function G:GetApplication(id) for _,app in ipairs(apps) do if app.id==id then return app end end end
function G:CanManageApplicants() return manageApplicants end
function G:CanManageListing() return manageListing end
function G:SetApplicantView(owner,visible) self.applicantViews=self.applicantViews or {};self.applicantViews[owner]=visible or nil end
function G:Cancel(id) G.cancelled=id;return true end
function G:Invite(id) G.inviteCalls=(G.inviteCalls or 0)+1;if applicant.acting then return false,"Pending" end;applicant.acting=true;G.invited=id;callback("applicants");return true end
function G:Decline(id) if G.failDecline then return false,"Decline failed" end;if applicant.acting then return false,"Pending" end;applicant.acting=true;G.declined=id;callback("applicants");return true end
A.Group=G;A.Open=function(_,page,context) A.openedPage=page;A.openedContext=context end
RAID_CLASS_COLORS={WARRIOR={r=.8,g=.6,b=.4}}
C_LFGList.GetActivityInfoTable=function() return {} end
_G.GetTime=function() return 0 end
local F=A.Floating;F:Bind(G);F:UpdateSettings()
T.eq(#F.rows,0,"a collapsed entry does not construct unused application rows")
T.eq(#F.batches,0,"a collapsed entry does not construct unused applicant batch cards")
F:ShowPanel()
T.eq(#F.rows,1,"the first hover constructs only the visible application row")
T.eq(#F.batches,0,"outbound applications need no applicant batch cards")
T.eq(startupNotifications,1,"disposing a subscription before startup prevents later delivery")
local function Position(frame)
 local _,relative,point,x,y=frame:GetPoint();if type(relative)=="number" then return relative,point end;return x,y
end
T.eq(A.UI,nil,"hover does not load the UI addon")
T.eq(F.context.Theme.fontSizeDelta,0,"the floating context does not inherit the main-window font increase")
T.eq(select(2,F.rows[1].name:GetFont()),16);T.eq(select(2,F.rows[1].meta:GetFont()),18,"floating activity and group titles retain their existing sizes")
T.eq(F.panel.events.GLOBAL_MOUSE_DOWN,true,"the expanded popup observes global clicks without a full-screen input catcher")
local entryButtons=0;for _,child in ipairs({F.frame:GetChildren()}) do if child:GetObjectType()=="Button" then entryButtons=entryButtons+1 end end
T.eq(entryButtons,1,"the collapsed icon and number share one actual button")
T.eq(F.frame:GetWidth(),115);T.eq(F.frame:GetHeight(),44);T.eq(F.panel:GetWidth(),348);T.eq(F.scroll:GetWidth(),324)
T.eq(F.count:GetText(),"申请1个");T.eq(F.rows[1].name:GetText(),"A dungeon");T.eq(F.rows[1].meta:GetText(),"A group");T.eq(F.rows[1].leader:GetText(),"Leader-Away");T.eq(F.rows[1].timer:GetText(),"2:10")
T.eq(F.rows[1].background:IsShown(),true,"each resting application keeps its own card")
T.eq(F.rows[1].faction,nil,"outbound application cards allocate no applicant faction marker")
T.eq(F.panel.background,nil,"the space around application cards has no outer backdrop")
T.eq(F.frame:IsMouseEnabled(),false,"the outer container adds no second mouse target")
T.eq(F.count:GetParent(),F.button);T.eq(F.logoTexture:GetParent(),F.logoAnchor);T.eq(F.logoAnchor:GetParent(),F.button)
T.eq(F.button.fill,nil,"the entry has no backdrop at rest")
F.button:Fire("OnEnter");F.context.Motion:Tick(.12)
T.eq(F.button.hover,nil,"hover opens the list without an entry highlight")
F.button:Fire("OnLeave")
do
 local countX,countY=Position(F.count);local logoX,logoY=Position(F.logoAnchor)
 T.eq(select(2,F.count:GetPoint()),F.button,"the entry row owns its icon and text slots")
 T.near(countX-logoX-F.logoAnchor:GetWidth(),4,.001,"the count preserves the gap after the logo")
 T.near(countY-F.count:GetHeight()/2,logoY-F.logoAnchor:GetHeight()/2,.001,"icon and text share the same centerline")
end
do
 local starts,stops=0,0;local start,stop=F.frame.StartMoving,F.frame.StopMovingOrSizing
 F.frame.StartMoving=function() starts=starts+1 end;F.frame.StopMovingOrSizing=function() stops=stops+1 end
 A.openedPage=nil;F.button:Fire("OnMouseDown","LeftButton");F.button:Fire("OnDragStart");F.button:Fire("OnDragStop");F.button:Fire("OnClick","LeftButton")
 T.eq(starts,1);T.eq(stops,1);T.eq(A.openedPage,nil,"releasing a drag cannot also open the main window")
 T.ok(A.db.floatingPosition,"the unified entry persists the dragged anchor")
 F.button:Fire("OnMouseDown","LeftButton");F.button:Fire("OnMouseUp","LeftButton");F.button:Fire("OnClick","LeftButton")
 T.eq(A.openedPage,"find","a fresh click anywhere on the unified entry remains usable after dragging")
 A:SetSetting("floatingLocked",true);F.button:Fire("OnDragStart");F.button:Fire("OnDragStop")
 T.eq(starts,1,"locking the entry prevents movement from its complete hit area")
 A:SetSetting("floatingLocked",false);F.frame.StartMoving,F.frame.StopMovingOrSizing=start,stop
 F:ShowPanel()
end
do
 -- A current party listing may exist before the floating snapshot has caught up.
 local oldManageApplicants,oldManageListing=manageApplicants,manageListing
 nativeListing=true;manageApplicants,manageListing=false,false
 T.eq(F.recruiting,false)
 F.button:Fire("OnClick","LeftButton")
 T.eq(A.openedPage,"create","a member's active party listing opens recruitment from the standalone entry")
 API:Open();T.eq(A.openedPage,"create","the public entry routes without applicant or listing permission")
 nativeListing=false;F.recruiting=true
 F.button:Fire("OnClick","LeftButton")
 T.eq(A.openedPage,"find","a stale recruitment summary cannot reopen an ended listing")
 API:Open();T.eq(A.openedPage,"find")
 nativeListing=nil;F.recruiting=false;manageApplicants,manageListing=oldManageApplicants,oldManageListing
end
apps[1].activityLabel="A longer dungeon activity name";apps[1].activityDetail="A very long difficulty label";callback("applications")
local applicationRow=F.rows[1];local detailX,detailY=Position(applicationRow.score);local _,titleY=Position(applicationRow.meta)
T.ok(applicationRow.score:GetStringHeight()>22,"long activity details wrap instead of losing text")
T.ok(-detailY+applicationRow.score:GetStringHeight()<=-titleY,"the complete activity heading fits above the group title")
local cancelX=Position(applicationRow.cancel)
T.ok(detailX+applicationRow.score:GetWidth()+8<=324+cancelX-applicationRow.cancel:GetWidth(),"the activity heading leaves a real gap before cancel")
T.ok(Position(applicationRow.leader)+applicationRow.leader:GetWidth()+12<=324-12-applicationRow.timer:GetWidth(),"leader and countdown have independent columns")
do
 local previous=apps[1].leaderName
 apps[1].leaderName=string.rep("LongLeader",8).."-Away";callback("applications")
 local _,leaderTop=Position(applicationRow.leader)
 T.eq(applicationRow.leader.wrap,true,"outbound application leaders retain wrapping after typed-row construction")
 T.ok(applicationRow.leader:GetStringHeight()>applicationRow.leader:GetLineHeight()+applicationRow.leader:GetSpacing(),"long leader identities wrap onto additional lines")
 T.ok(-leaderTop+applicationRow.leader:GetStringHeight()+12<=applicationRow:GetHeight()+.001,"the complete wrapped leader fits above the card's bottom padding")
 apps[1].leaderName=previous;callback("applications")
end
apps[1].activityLabel=nil;apps[1].activityDetail=nil;callback("applications")
GameTooltip:Hide();F.cancel:Fire("OnEnter");T.eq(F.cancel.hover:IsShown(),false,"the top cancellation action uses text feedback only")
T.eq(GameTooltip:IsShown(),false,"cancel-all does not open a redundant tooltip");F.cancel:Fire("OnLeave");T.eq(F.cancel.hover:IsShown(),false)
apps[1].status="invited";callback("applications")
T.eq(F.panel:IsShown(),false,"removing the last waiting application closes the popup instead of replacing it with a stuck empty card")
T.eq(F.countdown,nil,"automatic empty closure stops its countdown")
T.eq(F.panel.events.GLOBAL_MOUSE_DOWN,nil,"closing releases the outside-click listener")
F:ShowPanel()
T.eq(F.cancel:IsShown(),false,"an empty waiting list hides cancel-all instead of leaving a disabled header")
T.eq(F.panel:GetHeight(),60,"an empty application popup drops the unused header")
T.eq(F.emptyCard:IsShown(),true);T.eq(F.emptyCard:GetHeight(),44)
T.ok(F.emptyCard:GetWidth()<324,"an empty popup uses a compact card instead of a full application row")
T.eq(F.panel:GetWidth(),F.emptyCard:GetWidth()+24);T.eq(F.scroll:GetWidth(),F.emptyCard:GetWidth())
T.eq(F.empty:GetText(),"暂无申请","an active invitation keeps the waiting-list empty message")
T.eq(F.empty.justify,"CENTER","empty text is centered within its complete width")
T.eq(F.empty:GetPoint(),"CENTER");T.eq(select(2,Position(F.emptyCard)),-8,"empty content keeps equal top and bottom padding")
apps[1].status="applied";callback("applications")
T.eq(F.cancel:IsShown(),true);T.eq(F.emptyCard:IsShown(),false)
T.eq(select(2,Position(F.scroll)),-32,"restored applications regain the action header")
T.eq(F.rows[1]:GetHeight(),98,"restoring applications keeps the card's twelve-pixel vertical padding")
local _,headingY=Position(F.rows[1].name);local _,leaderY=Position(F.rows[1].leader)
T.eq(-headingY,12);T.ok(F.rows[1]:GetHeight()+leaderY-F.rows[1].leader:GetStringHeight()>=12,"the caption leader retains the full bottom padding inside its minimum-height line")
local workingEntries,workingTops,firstEntry=F.entries,F.entryTops,F.entries[1]
local fadeState=F.fade
F:Tick(.23);F:Fade(false);F:Tick(.04)
local reversingAlpha=F.rows[1]:GetAlpha();local _,reversingY=Position(F.rows[1])
F:ShowPanel()
T.near(F.rows[1]:GetAlpha(),reversingAlpha,.001,"reentering during close keeps the current card opacity")
T.near(select(2,Position(F.rows[1])),reversingY,.001,"reentering during close keeps the current card position")
apps[1].name="Updated group";callback("applications")
T.eq(F.entries,workingEntries);T.eq(F.entryTops,workingTops);T.eq(F.entries[1],firstEntry,"application refresh reuses the current entry container")
T.eq(F.rows[1].meta:GetText(),"Updated group","same-table data updates still render the visible row")
apps[1].name="A group";callback("applications")
F.rows[1]:Fire("OnClick");T.eq(A.openedPage,"find");T.eq(A.openedContext.applicationID,1)
A.openedPage=nil;F.rows[1].cancel:Fire("OnClick");T.eq(G.cancelled,1,"row cancel targets only its own pending application");T.eq(A.openedPage,nil,"row cancel does not navigate the main UI")
T.ok(F.countdown,"countdown exists only during an expanded waiting list");F.panel:Hide();T.eq(F.countdown,nil)
apps[2].status="applied";F:ShowPanel();F:Tick(.01)
T.ok(F.rows[1]:GetAlpha()>F.rows[2]:GetAlpha(),"separate application cards enter with a short stagger")
local entrance=F.fade;callback("applications");T.eq(F.fade,entrance,"native application refresh does not replay card entrance")
F.rows[1].cancel:Fire("OnEnter");T.eq(F.rows[1].background:IsShown(),true);T.eq(F.rows[2].background.fill.color[4],.60,"cancel hover leaves the other card unchanged")
T.eq(F.rows[1].background.fill.color[4],F.context.Theme.floatingHover[4],"row hover keeps the individual card translucent")
T.ok(F.rows[1].cancel.hover:IsShown(),"the icon retains its local red feedback");T.eq(GameTooltip:IsShown(),false,"single cancellation also omits a tooltip")
F.rows[1].cancel:Fire("OnLeave");T.eq(F.rows[1].background.fill.color[4],.60);T.eq(F.rows[1].cancel.hover:IsShown(),false)
apps[2].status="applied";for i=3,5 do apps[i]={id=i,name="Another group",status="applied",activityID=1} end
F:ShowPanel();T.eq(F.scroll:GetHeight(),522,"five padded application cards remain fully visible");T.eq(F.rows[1]:GetHeight(),98);T.eq(F.scrollBar:IsShown(),false,"floating wheel scrolling has no visible track");T.eq(F.rows[5]:IsShown(),true)
for i=5,3,-1 do apps[i]=nil end;apps[2].status="invited";F.panel:Hide()
F:ShowPanel()
members[1].factionGroup=1;members[1].raceName="光铸德莱尼";members[2].factionGroup=0;members[2].raceName="赞达拉巨魔"
listing={name="My listing",activityID=1};callback("listing");T.eq(F.count:GetText(),"30人申请","recruitment counts individual people");T.eq(F.scroll:GetHeight(),UIParent:GetHeight()/F.frame:GetScale()-F.frame:GetHeight()-48)
T.eq(G.applicantViews[F],true,"an expanded recruitment popup reports that applicants are being viewed")
F:Dismiss();T.eq(G.applicantViews[F],nil,"dismissing the popup releases applicant-view ownership")
F:ShowPanel();T.eq(G.applicantViews[F],true,"reopening the popup acknowledges applicants again")
do
 local getID,getClass=GetSpecializationInfoByID,GetSpecializationInfoForClassID
 local idReads,nameReads=0,0
 GetSpecializationInfoByID=function(...) idReads=idReads+1;return getID(...) end
 GetSpecializationInfoForClassID=function(...) nameReads=nameReads+1;return getClass(...) end
 local score=members[1].dungeonScore
 for i=1,20 do members[1].dungeonScore=score+i;callback("applicant") end
 T.eq(idReads,0,"twenty updates of thirty already-bound members make no further ID metadata reads")
 local specName=select(2,getClass(1,2))
 for _,member in ipairs(members) do member.specID=nil;member.specName=specName end
 for i=1,20 do members[1].dungeonScore=score+i;callback("applicant") end
 T.eq(nameReads,2,"thirty name-only members share one two-entry class lookup across twenty updates")
 for _,member in ipairs(members) do member.specID=71;member.specName=nil end
 members[1].dungeonScore=score;callback("applicants")
 GetSpecializationInfoByID,GetSpecializationInfoForClassID=getID,getClass
end
T.eq(F.brandMotion.texture,F.logoTexture,"the product reminder animates its original logo");T.eq(F.context.logo,nil,"the generic context holds no brand object")
T.eq(F.entries,workingEntries);T.eq(F.entries[1],firstEntry);T.eq(firstEntry.application,nil,"recruitment reuse clears the previous application reference")
local batchEntry=F.entries[1].batch
local comments=0;for _,entry in ipairs(F.entries) do if entry.comment then comments=comments+1 end end;T.eq(comments,1,"one shared comment is displayed at the bottom of its application batch")
T.eq(F.rows[1].name:GetText(),"Player1-Away","recruitment shows players directly without group-size headings");T.eq(F.rows[1].meta:GetText(),"光铸德莱尼 · 战士 · Specialization");T.eq(F.rows[1].score:GetText(),"2001")
T.eq(F.rows[1].itemLevel:GetText(),"装等 501","native item level has its own right-aligned second line")
do
 local row=F.rows[1];local faction=row.faction
 T.eq(faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-alliance.tga");T.eq(faction:IsShown(),true)
 T.eq(F.rows[2].faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-horde.tga","native faction zero shows Horde")
 T.eq(faction:GetWidth(),16);T.eq(faction:GetHeight(),16)
 local x,y=Position(faction);local nameX,nameY=Position(row.name)
 T.eq(x,nameX,"the faction starts the metadata line below the full-width name")
 local metaX,metaY=Position(row.meta)
 T.eq(metaX,x+faction:GetWidth()+6);T.eq(y,metaY,"faction and race share the metadata line")
 T.ok(metaY<nameY-row.name:GetLineHeight())
 T.eq(row.name:GetWidth(),168,"the faction and race leave the full identity width for the name")
 T.ok(F.entries[1].height>=12+row.name:GetStringHeight()+2+row.meta:GetStringHeight(),"wrapped race and specialization text fits the measured row")
 T.ok(x+faction:GetWidth()+12<=324-12-row.score:GetWidth(),"identity and faction retain the metric-column gap")
 T.eq(F.rows[3].faction:IsShown(),false);T.eq(F.rows[3].faction:GetTexture(),nil,"unknown members do not inherit another member's faction")
 members[1].factionGroup=0;callback("applicants")
 T.eq(row.faction,faction,"member refreshes reuse the same marker");T.eq(faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-horde.tga")
 members[1].factionGroup=nil;members[1].raceName=nil;callback("applicants")
 T.eq(faction:IsShown(),false);T.eq(faction:GetTexture(),nil,"losing known faction clears the old texture")
 T.eq(row.name:GetWidth(),168,"unknown faction restores the full name width")
 T.eq(row.meta:GetText(),"— · 战士 · Specialization","unknown race clears the previous race name")
 members[1].factionGroup=1;callback("applicants")
 T.eq(A.UI,nil,"faction textures do not load the UI addon")
end
T.eq(F.rows[1].batch,F.rows[2].batch,"member rows belong to one continuous batch hover area")
F.rows[1]:Fire("OnEnter");T.eq(F.rows[1].batch.background:IsShown(),true);T.eq(F.rows[1].background,nil,"members allocate no separate hover surface")
T.eq(F.rows[1].batch.line,nil,"a party card has no grouping line");T.eq(F.rows[1].batch.background.fill.color[4],F.context.Theme.floatingHover[4],"hover highlights the complete application card")
F.rows[1]:Fire("OnLeave");T.eq(F.rows[1].batch.background.fill.color[4],.60,"leaving the batch restores its resting card")
F.scroll:SetVerticalScroll(F.entryTops[30]);F:Render()
T.eq(F.rows[1].faction:IsShown(),false);T.eq(F.rows[1].faction:GetTexture(),nil,"a row rebound to an unknown member clears the previous faction")
local lastMember;for _,row in ipairs(F.rows) do if row:IsShown() and row.name:GetText()=="Player30-Away" then lastMember=row end end
T.ok(lastMember,"complete applicant roster stays scrollable after list text grows")
lastMember:Fire("OnClick");T.eq(A.openedPage,"create");T.eq(A.openedContext.applicantID,77)
F.scroll:SetVerticalScroll(F.body:GetHeight()-F.scroll:GetHeight());F:Render()
local actionRow,commentRow;for _,row in ipairs(F.rows) do if row.kind=="footer" and row.invite:IsVisible() then actionRow=row end;if row.name:GetText()==applicant.comment then commentRow=row end end
T.ok(actionRow,"the shared footer keeps one action pair");T.eq(commentRow,actionRow,"the shared comment and the one action pair occupy a single footer")
T.eq(commentRow.faction,nil,"a shared footer allocates no applicant marker")
T.ok(Position(commentRow.name)+commentRow.name:GetWidth()+12<=Position(actionRow.invite),"the comment leaves a real gap before the invite hit area")
T.eq(F.rows[1].invite,nil,"member rows allocate no duplicate footer actions")
T.eq(Position(commentRow.name),Position(F.rows[1].name),"the shared note aligns with the member text column")
T.ok(actionRow:GetHeight()>=40,"the footer keeps room for the note and twelve-pixel bottom inset")
local actionX,actionY=Position(actionRow.invite);T.eq(select(2,actionRow.invite:GetPoint()),actionRow);T.eq(actionRow:GetWidth()-actionX-actionRow.invite:GetWidth(),48);T.eq(actionRow:GetHeight()+actionY-actionRow.invite:GetHeight(),12,"the invite hit area clears the card bottom by twelve pixels")
local declineX,declineY=Position(actionRow.decline);T.eq(select(2,actionRow.decline:GetPoint()),actionRow);T.eq(actionRow:GetWidth()-declineX-actionRow.decline:GetWidth(),12);T.eq(actionRow:GetHeight()+declineY-actionRow.decline:GetHeight(),12,"the decline hit area shares the same outer inset")
T.eq(actionRow.invite:GetHeight(),28);T.eq(actionRow.invite.glyph:GetWidth(),18);T.eq(actionRow.decline.glyph:GetWidth(),18)
actionRow.invite:Fire("OnEnter");T.ok(actionRow.invite.hover:IsShown(),"invite hover preserves the shared button surface")
T.eq(actionRow.invite.hover.color[4],.14);T.eq(GameTooltip:IsShown(),false,"invite keeps local feedback without a redundant tooltip")
actionRow.invite:Fire("OnMouseDown");T.eq(actionRow.invite.hover.color[4],.22,"press adds the stronger semantic state layer");actionRow.invite:Fire("OnMouseUp")
F:Tick(.23)
local exitingMember,exitingBatch=F.rows[1],actionRow.batch;local frozenName=exitingMember.name:GetText()
A.openedPage=nil;actionRow.invite:Fire("OnClick");T.eq(G.invited,77,"the hardware click calls Invite before an animation tick");T.eq(A.openedPage,nil)
T.eq(actionRow.pending,nil,"applicant actions never create a processing label")
T.eq(actionRow.invite:IsEnabled(),false);T.eq(actionRow.decline:IsEnabled(),false)
actionRow.invite:Fire("OnClick");T.eq(G.inviteCalls,1,"an exiting batch cannot be submitted twice")
applicant.members={members[1]};callback("applicants");F:SetOffset(0,false);F:Render()
T.eq(exitingMember.name:GetText(),frozenName,"synchronous and later updates cannot rebind an exiting row")
T.eq(exitingMember.applicantID,77)
F:Tick(.07);T.ok(exitingMember:GetAlpha()>0 and exitingMember:GetAlpha()<1,"members play a finite exit")
T.near(commentRow:GetAlpha(),exitingMember:GetAlpha(),.001,"the shared note exits with its members")
T.near(actionRow:GetAlpha(),exitingMember:GetAlpha(),.001,"the actions exit with their members")
T.near(exitingBatch:GetAlpha(),exitingMember:GetAlpha(),.001,"the hover surface exits with the batch")
F:Tick(.08);T.eq(F.entries,nil,"finishing the last batch exit releases the popup bindings")
T.eq(F.panel:IsShown(),false,"the last applicant exits without replacing the batch with an empty popup")
T.eq(F.frame:GetScript("OnUpdate"),nil,"the exit leaves no persistent driver")
applicant.acting=nil;applicant.pendingStatus="invited";callback("applicants");T.eq(F.entries,nil,"native pending status remains hidden")
applicant.pendingStatus=nil;callback("applicants");F:Tick(.2)
T.eq(F.panel:IsShown(),false,"a later native refresh cannot reopen the automatically closed popup")
F:ShowPanel();F:SetOffset(0,false)
T.eq(#F.entries,2,"explicit hover can restore a native return to operable applied")
F:Tick(.23)
batchEntry=F.entries[1].batch;actionRow,commentRow=F.rows[2],F.rows[2]
actionRow.decline:Fire("OnEnter");T.ok(actionRow.decline.hover:IsShown());T.eq(GameTooltip:IsShown(),false,"decline omits its redundant tooltip");actionRow.decline:Fire("OnLeave");T.eq(actionRow.decline.hover:IsShown(),false)
local printMessage=A.Print;local failure;A.Print=function(_,message) failure=message end
G.failDecline=true;actionRow.decline:Fire("OnClick")
T.eq(failure,"Decline failed","immediate action failures are reported")
T.eq(#F.entries,2);T.eq(actionRow.decline:IsEnabled(),true,"a failed call restores the available action")
T.eq(actionRow.exit,nil,"failed calls do not leave an exit state")
T.ok(F.attention and F.attentionTimer,"the operable applicant keeps its independent logo reminder after a failed action")
A.Print=printMessage;G.failDecline=nil
actionRow.decline:Fire("OnClick");T.eq(G.declined,77,"decline also submits in the click callback");F:Tick(.15);T.eq(F.panel:IsShown(),false)
applicant.acting=nil;callback("applicants");F:ShowPanel();F:SetOffset(0,false)
batchEntry=F.entries[1].batch;commentRow=F.rows[2]
T.eq(#F.entries,2,"a smaller roster drops old member containers instead of retaining the past roster size")
T.eq(F.entries[1].batch,batchEntry,"current batch metadata is reused while its members change")
T.eq(F.rows[1].batch.line,nil,"a solo application uses the same borderless card")
T.eq(F.rows[1].batch.background:IsShown(),true,"a resting applicant batch retains one shared card")
T.eq(F.rows[1].batch.background.fill.color[4],.60,"the resting batch shares the lighter translucent background")
local staleInvite=F.rows[2].invite;local callsBefore=G.inviteCalls
manageApplicants,manageListing=false,false;callback("permissions")
T.eq(F.count:GetText(),"1人申请","ordinary members retain the applicant count")
T.eq(#F.entries,2,"read-only applicants retain all members and the shared note without an empty footer")
T.eq(F.rows[1].name:GetText(),"Player1-Away");T.eq(F.rows[2].name:GetText(),applicant.comment)
T.eq(F.cancel:IsShown(),false,"ordinary members cannot end a listing")
staleInvite:Fire("OnClick");T.eq(G.inviteCalls,callsBefore,"a stale invite callback cannot act after losing permission")
manageApplicants=true;callback("permissions")
T.eq(#F.entries,2);T.eq(F.rows[2].invite:IsShown(),true,"an assistant can invite the applicant batch")
T.eq(F.cancel:IsShown(),false,"assistants still cannot end the leader's listing")
manageListing=true;callback("permissions");T.eq(F.cancel:IsShown(),true,"the leader regains the end-listing action")
local rarity=C_ChallengeMode.GetDungeonScoreRarityColor;local rarityCalls=0
C_ChallengeMode.GetDungeonScoreRarityColor=function(score) rarityCalls=rarityCalls+1;return rarity(score) end
local metricRow=F.rows[1]
listing.activityID=2;callback("listing")
T.eq(F.rows[1],metricRow,"changing the listing activity reuses the visible member row")
T.eq(metricRow.score:IsShown(),false);T.eq(metricRow.score:GetText(),"","raid recruitment does not show or retain a rating")
T.eq(metricRow.itemLevel:IsShown(),true);T.eq(metricRow.itemLevel:GetText(),"装等 501")
T.eq(select(1,metricRow.itemLevel:GetPoint()),"TOPRIGHT");T.eq(Position(metricRow.itemLevel),-12)
T.eq(select(2,Position(metricRow.itemLevel)),select(2,Position(metricRow.name)),"raid item level moves to the member's first line")
T.eq(select(2,metricRow.itemLevel:GetFont()),14)
T.eq(metricRow.faction:IsShown(),true);T.eq(metricRow.faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-alliance.tga","raid metrics preserve the member faction marker")
T.eq(rarityCalls,0,"hidden raid ratings do not calculate dungeon score colors")
listing.activityID=3;members[1].ratingKind="pvp";members[1].rating=1820;callback("listing")
T.eq(F.rows[1],metricRow);T.eq(metricRow.score:IsShown(),true,"a reused PvP row restores its rating")
T.eq(select(2,Position(metricRow.itemLevel)),select(2,Position(metricRow.meta)),"PvP item level returns to the second line")
T.eq(select(2,metricRow.itemLevel:GetFont()),12)
T.eq(F.rows[1].score:GetText(),"1820","floating uses the listing's normalized PvP rating instead of its dungeon score")
T.same(F.rows[1].score.color,F.context.Theme.text,"PvP rating uses neutral text")
members[1].rating=0;callback("applicants");T.eq(F.rows[1].score:GetText(),"暂无分数","known zero is distinct from missing PvP data")
members[1].rating=nil;callback("applicants");T.eq(F.rows[1].score:GetText(),"未知分数","missing PvP rating does not fall back to a dungeon score")
T.eq(rarityCalls,0,"PvP does not request dungeon score rarity colors")
listing.activityID=2;callback("listing");T.eq(metricRow.score:IsShown(),false,"returning from PvP to raid hides the reused score again")
listing.activityID=1;members[1].ratingKind="dungeon";members[1].rating=members[1].dungeonScore;callback("listing")
T.eq(F.rows[1],metricRow);T.eq(metricRow.score:IsShown(),true);T.eq(select(2,Position(metricRow.itemLevel)),select(2,Position(metricRow.meta)),"dungeon row reuse keeps item level on its second line")
T.eq(F.rows[1].score:GetText(),"2001");T.eq(rarityCalls,1,"dungeon ratings keep their rarity colors")
C_ChallengeMode.GetDungeonScoreRarityColor=rarity
T.eq(select(2,F.rows[1].name:GetFont()),16,"floating applicant names use the compact 16/22 typography")
T.eq(select(2,F.rows[1].score:GetFont()),14)
T.eq(select(2,F.rows[1].meta:GetFont()),12);T.eq(select(2,F.rows[1].itemLevel:GetFont()),12)
T.eq(F.rows[1].leader,nil);T.eq(F.rows[1].timer,nil,"member rows allocate no application leader or countdown text")
T.eq(select(2,commentRow.name:GetFont()),12,"shared comments use the compact footer typography")
T.ok(56+F.rows[1].name:GetWidth()+12<=324-12-F.rows[1].itemLevel:GetWidth(),"the name and metric columns retain a twelve-pixel gap")
T.eq(F.rows[1].icon:GetWidth(),32,"the applicant avatar spans the name and specialization block")
local iconX,iconY=Position(F.rows[1].icon)
local nameX,nameY=Position(F.rows[1].name)
local metaX,metaY=Position(F.rows[1].meta)
T.eq(iconX,12);T.eq(nameX,56);T.eq(metaX,78)
T.eq(iconY,-12,"the avatar has a twelve-pixel inset from the card top")
T.eq(nameY,-12,"the player name aligns with the avatar and has a twelve-pixel top inset")
local scorePoint=select(1,F.rows[1].score:GetPoint());local scoreX,scoreY=Position(F.rows[1].score)
T.eq(scorePoint,"TOPRIGHT");T.eq(scoreX,-12,"the score keeps a twelve-pixel right inset");T.eq(scoreY,-12,"the score aligns with the member heading")
T.eq(select(2,F.count:GetFont()),16,"the collapsed indicator count retains its size")
T.eq(select(2,F.cancel.label:GetFont()),14,"the top action uses the readable control size")
T.eq(A.UI,nil,"PvP rendering still leaves the UI addon unloaded")
local originalKey=members[1].nameKey;members[1].nameKey="A-very-long-player-identity-from-another-realm";callback("applicants")
local _,nameY=Position(F.rows[1].name);local _,scoreY=Position(F.rows[1].score);local _,metaY=Position(F.rows[1].meta);local _,itemY=Position(F.rows[1].itemLevel)
T.ok(F.entries[1].nameHeight>22,"long identities still expand the complete member row")
T.eq(nameY,scoreY,"rating follows the name's first baseline even after wrapping")
T.eq(metaY,itemY,"item level follows the specialization baseline after the wrapped name")
local _,wrappedIconY=Position(F.rows[1].icon)
T.eq(wrappedIconY,nameY,"a wrapped identity keeps the avatar aligned with the first name line")
local factionX,factionY=Position(F.rows[1].faction)
T.eq(factionY,metaY,"a wrapped name keeps faction beside the race below the complete identity")
T.eq(factionX,56,"long identities preserve the metadata inset")
members[1].nameKey=originalKey;callback("applicants")
local comment=applicant.comment
applicant.comment="熟练";callback("applicants");T.eq(F.body:GetHeight(),F.entries[1].height+40,"the card fits the full identity and race metadata plus its compact note footer")
local commentTop=select(2,Position(F.rows[2].name))
T.eq(commentTop,-6,"a single-line note sits lower beside the action controls")
T.eq(-commentTop+F.rows[2].name:GetHeight()/2,40-(12+14),"a single-line note and action controls share a centerline")
local shortHeight=F.body:GetHeight()
applicant.comment=nil;callback("applicants");T.eq(#F.entries,2,"a batch without a note has no empty note row");T.eq(F.body:GetHeight(),shortHeight,"an empty note and one short line use the same compact footer")
applicant.comment=string.rep("A long shared note ",12);callback("applicants")
T.ok(F.body:GetHeight()>shortHeight,"a long shared note expands instead of truncating its content")
T.eq(select(2,Position(F.rows[2].name)),-12,"a multi-line note keeps its top inset as it grows")
T.eq(F.rows[2].name:GetText(),applicant.comment);T.eq(F.rows[2].invite:IsShown(),true)
applicant.comment=comment;callback("applicants")
F:Tick(.23);F.rows[2].invite:Fire("OnClick")
local closingRow=F.rows[1];T.ok(closingRow.exit,"an accepted action owns a finite display state")
F.panel.mouseOver=true;F.panel:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
T.eq(F.panel:IsShown(),true,"clicking inside the exiting popup does not trigger its outside close")
F.panel.mouseOver=false;F.frame.mouseOver=false;F:ScheduleHide()
local outsideClicks=0;local outside=CreateFrame("Button",nil,UIParent);outside:SetScript("OnClick",function() outsideClicks=outsideClicks+1 end)
F.panel:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton");outside:Fire("OnClick","LeftButton")
T.eq(outsideClicks,1,"the outside click still reaches its original button")
T.eq(F.panel:IsShown(),false,"an outside click immediately closes an active batch exit")
T.eq(closingRow.exit,nil,"closing clears the row's exit state");T.eq(closingRow.applicantID,nil)
T.eq(closingRow.faction:IsShown(),false);T.eq(closingRow.faction:GetTexture(),nil,"closing clears the pooled applicant marker")
T.eq(F.panel.events.GLOBAL_MOUSE_DOWN,nil);T.eq(F.hideTask,nil)
T.eq(F.frame:GetScript("OnUpdate"),nil,"closing stops an active batch exit")
F.panel.mouseOver=true;base.AdvanceClock(.2);F:Tick(.5);callback("applicants")
T.eq(F.panel:IsShown(),false,"a cancelled hide timer, completed exit and native refresh cannot reopen the popup")
F.panel.mouseOver=false
F:ShowPanel();T.eq(#F.entries,0,"reopening never revives an acting applicant");T.eq(F.count:GetText(),"暂无申请","the collapsed count uses the same operable filter as the list")
T.eq(F.emptyCard:IsShown(),true);T.eq(F.emptyCard:GetHeight(),44)
T.eq(F.cancel:IsShown(),true,"the owner can still end an empty listing")
T.eq(F.panel:GetHeight(),84,"the empty recruitment view reserves only its meaningful listing action and centered content")
F.panel:Fire("OnEvent","GLOBAL_MOUSE_DOWN","RightButton")
T.eq(F.panel:IsShown(),false,"an explicitly hovered empty listing can also be closed by an outside click")
applicant.acting=nil;callback("applicants");T.eq(F.panel:IsShown(),false,"a closed empty listing stays closed when applicants return")
F:ShowPanel();T.eq(#F.entries,2,"an operable native record can return after explicit hover")
F:Tick(.23);T.eq(F.panel:GetAlpha(),1,"expanded panel finishes its finite fade")
do
 F.panel.mouseOver=false;F.frame.mouseOver=false;F:ScheduleHide();base.AdvanceClock(.06);F:Tick(.02)
 T.ok(F.fade and F.fade.to==0,"leaving starts the configured finite fade after its delay")
 F.panel.mouseOver=true;F.panel:Fire("OnEnter");F:Tick(.055)
 T.eq(F.panel:IsShown(),true,"returning to the popup during fade-out keeps its existing cards visible")
 F:Tick(.2);T.eq(F.panel:GetAlpha(),1,"returning reverses the existing fade without replaying card entrance")
 F.panel.mouseOver=false
end
do
 F:SetOffset(0,false)
 local render=F.Render;local renders=0
 F.Render=function(self,...) renders=renders+1;return render(self,...) end
 for _=1,10 do
  F.scroll:Fire("OnMouseWheel",1)
  for _=1,15 do if F.frame:GetScript("OnUpdate") then F.frame:Fire("OnUpdate",.01) end end
 end
 F.Render=render
 T.eq(renders,0,"wheel input at the upper boundary does not render motion with no displacement")
 T.eq(F.scroll:GetVerticalScroll(),0);T.eq(F.frame:GetScript("OnUpdate"),nil)
end
F:SetOffset(11,true);T.ok(F.scrollTween);local scrollState=F.scrollTween;F:Tick(.03);T.ok(F.scroll:GetVerticalScroll()>0 and F.scroll:GetVerticalScroll()<11,"a real scroll retains its intermediate position");F:SetOffset(22,true);T.eq(F.scrollTween,scrollState,"a new scroll target reuses the finite tween state");F:Tick(.2);T.eq(F.scroll:GetVerticalScroll(),22);T.eq(F.scrollTween,nil,"completed scrolling removes its tween");F:SetOffset(0,true);F:Tick(.2);T.eq(F.scroll:GetVerticalScroll(),0)
F:Fade(false);T.ok(F.fade);T.eq(F.fade,fadeState,"fade direction changes reuse the finite fade state");F:Tick(.2);T.eq(F.panel:IsShown(),false);T.ok(F.attention and F.attentionTimer,"closing only the popup preserves the pending-applicant reminder")
T.eq(F.frame:GetScript("OnUpdate"),nil,"collapsed attention does not keep the panel driver running")
T.eq(next(firstEntry),nil,"closing clears every business field from retained entry shells")
T.eq(next(batchEntry),nil,"closing clears retained batch metadata")
T.eq(#workingTops,0);T.ok(#workingEntries<=#F.rows,"closed entry shells are bounded by the visible row pool")
F:ShowPanel();T.eq(F.rows[1]:GetAlpha(),0,"a newly opened card starts below its final position with zero opacity");F:Tick(.08);T.ok(F.rows[1]:GetAlpha()>0 and F.rows[1]:GetAlpha()<1);local entering=F.fade;F.panel:Fire("OnEnter");T.eq(F.fade,entering,"moving into the panel does not restart card entrance")
F.rows[2].invite:Fire("OnClick")
do
 local row=F.rows[2];local apply,clear=F.ApplyCardMotion,row.ClearAllPoints
 local applies,clears=0,0
 F.ApplyCardMotion=function(self,...) applies=applies+1;apply(self,...) end
 row.ClearAllPoints=function(self) clears=clears+1;clear(self) end
 local alpha,top=row.exitAlpha,row.exitTop
 F:Tick(.01)
 T.eq(applies,1,"overlapping entrance and exit apply the card state once per tick")
 T.eq(clears,0,"animated cards update their existing root anchor")
 T.near(row:GetAlpha(),alpha*(1-.01/.14)^3,.00001,"the exit keeps its original cubic opacity")
 T.near(select(2,Position(row)),top+6*(1-(1-.01/.14)^3),.00001,"the exit keeps its original six-pixel path")
 F.ApplyCardMotion,row.ClearAllPoints=apply,clear
end
A:SetSetting("reduceMotion",true)
T.eq(F.panel:IsShown(),false);T.eq(F.frame:GetScript("OnUpdate"),nil,"reduced motion finishes the entrance and last batch exit immediately");T.eq(F.entries,nil)
applicant.acting=nil;callback("applicants");F:ShowPanel();T.eq(#F.entries,2)
F.rows[2].decline:Fire("OnClick");T.eq(F.entries,nil,"reduced motion closes the last accepted batch without a display task");T.eq(F.frame:GetScript("OnUpdate"),nil)
applicant.acting=nil;callback("applicants");F:ShowPanel()
F:SetOffset(22,true);T.eq(F.scrollTween,nil);T.eq(F.scroll:GetVerticalScroll(),22)
local highWater=#stub.nodes
for i=1,15 do F:ShowPanel() end
T.eq(#stub.nodes,highWater,"repeated hover reuses native rows")
F:Dismiss()
do
 local originalMembers=applicant.members;local many={};for i=1,100 do many[i]=originalMembers[1] end
 applicant.members=many;callback("applicants")
 T.eq(F.count:GetText(),"100人申请");T.ok(F.frame:GetWidth()>80,"the single entry expands to preserve the complete count")
 T.eq(F.button:GetWidth(),F.frame:GetWidth());T.ok(F.count:GetWidth()>=F.count:GetStringWidth());T.eq(F.count.wrap,false,"the complete count stays on one stable line")
 F:ShowPanel()
 local tops=F.entryTops
 local function CheckRange(offset,height)
  F.scroll:SetHeight(height);F.scroll:SetVerticalScroll(offset);F:Render()
  local first,last
  for i,entry in ipairs(F.entries) do if tops[i]+entry.height>=offset and tops[i]<offset+height then first=first or i;last=i end end
  T.eq(F.visibleFirst,first,"floating range keeps the original inclusive top boundary")
  T.eq(F.visibleLast,last,"floating range keeps the original exclusive bottom boundary")
 end
 local viewport=F.scroll:GetHeight()
 CheckRange(0,viewport);CheckRange(tops[50],tops[55]-tops[50]);CheckRange(tops[50]+.01,viewport)
 CheckRange(F.body:GetHeight()-viewport,viewport)
 local iterate,clockScans=ipairs,0
 _G.ipairs=function(values)
  local iterator,state,index=iterate(values)
  if values~=F.entries then return iterator,state,index end
  return function(source,key) local nextKey,value=iterator(source,key);if value then clockScans=clockScans+1 end;return nextKey,value end,state,index
 end
 F:SetOffset(tops[20],false);F:SetOffset(tops[60],false)
 _G.ipairs=iterate
 T.eq(clockScans,0,"recruiting scrolls do not scan every member for nonexistent application clocks")
 T.eq(#F.entries,101);T.eq(F.rows[1].applicantID,77);T.eq(F.countdown,nil)
 local reads=0
 F.entryTops=setmetatable({},{__index=function(_,index) reads=reads+1;return tops[index] end})
 F:Render()
 T.ok(reads<30,"a stable scroll frame locates visible entries without scanning the complete applicant list")
 F.entryTops=tops;F:Dismiss()
 applicant.members=originalMembers;callback("applicants");T.eq(F.frame:GetWidth(),115)
end
A:SetSetting("reduceMotion",false)
T.ok(F.attention and F.brandMotion:IsPlaying(),"restoring motion starts the actual product Brand job")
T.eq(F.frame:GetScript("OnUpdate"),nil,"the collapsed reminder does not install the panel driver")
local countPoint={F.count:GetPoint()};local framePoint={F.frame:GetPoint()};local beforeAttentionNodes=#stub.nodes
F.context.Motion:Tick(.168)
T.near(F.logoTexture:GetWidth(),38*1.075,.001,"the first original Bezier segment stretches the logo horizontally")
T.near(F.logoTexture:GetHeight(),38*.925,.001,"the same segment squashes the logo vertically around its original pivot")
local currentCountPoint={F.count:GetPoint()};for i,value in ipairs(countPoint) do T.eq(currentCountPoint[i],value,"the count baseline remains stable during attention") end
local currentFramePoint={F.frame:GetPoint()};for i,value in ipairs(framePoint) do T.eq(currentFramePoint[i],value,"the clickable container remains stable during attention") end
T.same(F.logoTexture.texCoords,{0,1,0,1},"attention preserves the original full logo UV")
local brandJob,timer=F.brandMotion.elapsed,F.attentionTimer;callback("applicants");A:SetSetting("floatingScale",110)
T.eq(F.brandMotion.elapsed,brandJob);T.eq(F.attentionTimer,timer,"ordinary data and settings refreshes do not restart the current Brand cycle")
local getApplicants=G.GetApplicants;local queries=0;G.GetApplicants=function(self) queries=queries+1;return getApplicants(self) end
F.context.Motion:Tick(1.22)
T.eq(F.logoTexture:GetWidth(),38);T.eq(F.logoTexture:GetHeight(),38)
T.eq(F.context.Motion.driver:GetScript("OnUpdate"),nil,"the shared driver is idle between the 1.386s animation and the next reminder")
T.eq(F.frame:GetScript("OnUpdate"),nil);T.eq(base.PendingTimers(),1,"only one cancellable replay timer owns the quiet interval")
F:ShowPanel()
do
 local clock=GetTimePreciseSec;local reads=0
 _G.GetTimePreciseSec=function() reads=reads+1;return clock() end
 for i=1,24 do stub.preciseNow=i*.01;F.frame:Fire("OnUpdate",.01) end
 T.eq(reads,1,"floating reads the native clock only for the first frame of a busy interval")
 T.eq(F.frame:GetScript("OnUpdate"),nil,"floating stops its driver after its entrance finishes")
 _G.GetTimePreciseSec=clock;stub.preciseNow=0
end
F:Dismiss()
T.eq(F.attentionTimer,timer,"closing the panel during the quiet interval does not unnecessarily replay the logo")
queries=0;base.AdvanceClock(2.4)
T.ok(F.brandMotion:IsPlaying(),"the single timer starts the next original Brand animation")
T.eq(base.PendingTimers(),1,"the timer replaces its own handle without accumulating reminders")
F.context.Motion:Tick(.168);T.near(F.logoTexture:GetWidth(),38*1.075,.001)
T.eq(queries,0,"animation and replay never query the applicant service")
G.GetApplicants=getApplicants
T.eq(#stub.nodes,beforeAttentionNodes,"the repeated reminder reuses its texture and existing driver")
A:SetSetting("reduceMotion",true)
T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(F.logoTexture:GetWidth(),38);T.eq(select(2,Position(F.logoTexture)),0)
T.eq(F.frame:GetScript("OnUpdate"),nil,"reduced motion stops and settles the collapsed reminder")
A:SetSetting("reduceMotion",false);F.context.Motion:Tick(.1)
local visibleAttention
local stopAttention=API:Subscribe(function(status) visibleAttention=status.attention end)
T.eq(visibleAttention,true)
F.frame:Hide()
T.eq(visibleAttention,false,"hiding the entry publishes the stopped attention state to API subscribers")
stopAttention()
T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(F.logoTexture:GetWidth(),38);T.eq(F.brandMotion:IsPlaying(),false,"hiding the entire entry cancels Brand and the replay timer")
F.frame:Show();T.ok(F.attention,"showing the entry derives attention again from the pending snapshot")
listing=nil;callback("listing");T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(F.logoTexture:GetWidth(),38);T.eq(F.frame:GetScript("OnUpdate"),nil,"ending recruitment stops attention even if outbound applications remain")
listing={name="My listing",activityID=1};callback("listing");T.ok(F.attention)
applicant.pendingStatus="invited";callback("applicants");T.eq(F.attention,false,"only operable applied applicants trigger attention")
applicant.pendingStatus=nil;callback("applicants");T.ok(F.attention)
applicant.status="declined";callback("applicants");T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(select(2,Position(F.logoTexture)),0,"clearing the final pending applicant restores the original logo anchor")
A:SetSetting("floating",false);T.eq(F.frame:IsShown(),false);T.eq(F.entries,nil,"disabled floating releases its list");T.eq(F.frame:GetScript("OnUpdate"),nil)
T.eq(F.context.Motion:Count(),0);T.eq(F.context.Motion.driver:GetScript("OnUpdate"),nil,"hidden floating releases its button hover driver")
T.eq(base.PendingTimers(),0,"idle floating has no periodic task")
do
 local getApplications,getApplicants=G.GetApplications,G.GetApplicants;local applicationReads,applicantReads=0,0
 G.GetApplications=function(...) applicationReads=applicationReads+1;return getApplications(...) end
 G.GetApplicants=function(...) applicantReads=applicantReads+1;return getApplicants(...) end
 callback("applications");callback("applicants")
 T.eq(applicationReads,0,"disabled floating ignores application notifications without reading the application list")
 T.eq(applicantReads,0,"disabled floating ignores applicant notifications without reading the applicant list")
 applicant.status="applied";A:SetSetting("floating",true)
 T.eq(F.count:GetText(),"1人申请","reenabling floating refreshes its applicant count")
 F:ShowPanel();T.ok(#F.entries>0,"reenabling floating restores the applicant list on hover")
 A:SetSetting("floating",false);T.eq(F.frame:IsShown(),false);T.eq(base.PendingTimers(),0,"disabling again leaves no pending floating timer")
  T.eq(G.applicantViews[F],nil,"disabling the floating entry cannot leave a hidden applicant viewer")
 G.GetApplications,G.GetApplicants=getApplications,getApplicants
end
do
 local clock,now=GetTime,0;GetTime=function() return now end
 listing=nil;apps={{id=91,name="Countdown",status="applied",activityID=1,activityName="Dungeon",expiresAt=1}}
 A:SetSetting("reduceMotion",true);A:SetSetting("floating",true);F:ShowPanel()
 local row=F.rows[1];local writes=0;local setText=row.timer.SetText
 row.timer.SetText=function(self,value) writes=writes+1;return setText(self,value) end
 now=1;base.AdvanceClock(1)
 T.eq(row.timer:GetText(),"0:00");T.eq(F.countdown,nil,"floating stops its ticker after every displayed deadline reaches zero")
 local settled=writes;now=4;base.AdvanceClock(1)
 T.eq(writes,settled,"an unchanged zero countdown has no periodic text writes")
 T.eq(apps[1].status,"applied","floating leaves expiry status to native business events")
 apps[1].expiresAt=10;callback("applications");T.ok(F.countdown,"a new future deadline restarts the floating ticker")
 now=5;base.AdvanceClock(1);T.eq(row.timer:GetText(),"0:05")
 F:Dismiss();T.eq(F.countdown,nil)
 now=12;F:ShowPanel();T.eq(F.countdown,nil,"opening an already elapsed application does not start a ticker")
 row.timer.SetText=setText
 local savedApps=apps;apps={{id=91,status="invited"}};callback("applications")
 T.eq(F.count:GetText(),"暂无申请","an active invitation is not an idle entry")
 apps={};callback("applications")
 T.eq(F.count:GetText(),"荔枝组队","ending the last application shows the brand even when the waiting count stays zero")
 F:ShowPanel();T.eq(F.empty:GetText(),"暂无活动","the idle popup distinguishes no activity from an active empty waiting list")
 F:Dismiss();apps=savedApps;callback("applications")
 T.eq(F.count:GetText(),"申请1个","a new application restores the status text")
 A:SetSetting("floating",false);GetTime=clock
end
do
 -- A third-party host can integrate without loading any bundled adapter.
 T.eq(A.Adapters,nil)
 local host=CreateFrame("Button",nil,UIParent);host:SetSize(120,24)
 local label=host:CreateFontString(nil,"OVERLAY");label:SetText("External entry")
 label:SetFont("External.ttf",16,"");label:SetPoint("CENTER")
 local owner,other={},{}
 local released=0
 local function Release()
  released=released+1
  T.eq(F.host,nil,"release runs after the floating objects return to their own entry")
  T.eq(API:Detach(owner),false,"ownership is already cleared when release runs")
  label:SetText("External entry")
 end
 local ok,reason=API:Attach(owner,host,24,label,Release)
 T.eq(ok,false);T.eq(reason,"unavailable","disabled floating does not lend its controls")
 A:SetSetting("floating",true)
 local notifications,status=0
 local unsubscribe=API:Subscribe(function(value) notifications=notifications+1;status=value end)
 T.eq(notifications,1);T.eq(status.available,true);T.eq(status.count,1);T.eq(status.recruiting,false)
 status.text="changed by consumer";T.eq(API:GetStatus().text,"申请1个","status snapshots do not expose mutable internal state")
 F:Update();T.eq(notifications,1,"unchanged presentation does not send another status notification")
 local frame,rows=F.frame,F.rows
 T.eq(API:Attach(owner,host,24,label,Release),true)
 T.eq(F.frame,frame);T.eq(F.rows,rows);T.eq(F.host,host);T.eq(F.count,label)
 T.eq(label:GetText(),"申请1个");T.eq(label:GetFont(),"External.ttf")
 ok,reason=API:Attach(other,host,24,label,Release)
 T.eq(ok,false);T.eq(reason,"occupied","a second adapter cannot take the existing host")
 T.eq(API:Refresh(other),false);T.eq(API:Detach(other),false)
 T.eq(API:ShowPopup(other),false);T.eq(API:HidePopup(other),false)
 T.eq(API:ShowPopup(owner),true);T.eq(F.panel:IsShown(),true)
 local bounds=CreateFrame("Frame",nil,UIParent);bounds:SetSize(300,40);bounds:SetScale(.5)
 bounds.GetTop=function() return 1900 end;bounds.GetLeft=function() return 180 end
 host.GetTop=function() return 1000 end;host.GetLeft=function() return 100 end
 T.eq(API:SetPopupBounds(other,{bounds}),false)
 T.eq(API:SetPopupBounds(owner,{bounds}),true)
 local layouts,layoutPanel=0,F.LayoutPanel
 F.LayoutPanel=function(...) layouts=layouts+1;return layoutPanel(...) end
 T.eq(API:SetPopupBounds(owner,{bounds}),true);T.eq(layouts,0,"unchanged host bounds do not duplicate the following popup layout")
 F.LayoutPanel=layoutPanel
 T.eq(F.panel:GetPoint(),"TOPLEFT")
 local popupScale=F.panel:GetEffectiveScale()
 T.near(select(5,F.panel:GetPoint()),(930-976)/popupScale-8,.001,"popup starts below the visible host region at its own scale")
 bounds:Hide();API:Refresh(owner)
 T.eq(select(5,F.panel:GetPoint()),-8,"hidden host controls do not reserve popup space")
 bounds:Show();bounds.GetLeft=function() return 1200 end;API:Refresh(owner)
 T.eq(select(5,F.panel:GetPoint()),-8,"controls outside the popup width do not move it")
 bounds.GetLeft=function() return 180 end;bounds.GetTop=function() return 200 end
 host.GetTop=function() return 50 end;API:Refresh(owner)
 T.eq(F.panel:GetPoint(),"BOTTOMLEFT")
 T.near(select(5,F.panel:GetPoint()),50/popupScale+8,.001,"a bottom entry opens above the reserved host region")
 T.eq(API:SetPopupBounds(owner,nil),true);T.eq(select(5,F.panel:GetPoint()),8)
 host.GetTop,host.GetLeft=nil,nil
 host.mouseOver=false;F.panel.mouseOver=false
 T.eq(API:HidePopup(owner),true);base.AdvanceClock(.12);F:Tick(.23)
 T.eq(F.panel:IsShown(),false)
 host:SetSize(150,28);T.eq(API:Refresh(owner),true);T.eq(F.frame:GetWidth(),150)
 T.eq(notifications,1,"host geometry changes do not publish unchanged business status")
 API:Open();T.eq(A.openedPage,"find")
 local savedApps=apps;apps={};callback("applications")
 T.eq(notifications,2);T.eq(status.idle,true);T.eq(status.count,0);T.eq(status.text,"荔枝组队")
 apps=savedApps;callback("applications");T.eq(notifications,3)
 A:SetSetting("floatingCompatibility",false)
 T.eq(released,1);T.eq(label:GetText(),"External entry");T.eq(status.available,false)
 T.eq(API:Detach(owner),false);T.eq(released,1,"detaching a released owner does not repeat cleanup")
 A:SetSetting("floatingCompatibility",true)
 T.eq(API:Attach(owner,host,24,label,Release),true)
 local beforeDisable=notifications
 A:SetSetting("floating",false)
 T.eq(notifications,beforeDisable+1,"disabling a hosted entry publishes its final unavailable status only once")
 T.eq(released,2);T.eq(F.frame:IsShown(),false);T.eq(base.PendingTimers(),0)
 local previous=notifications;unsubscribe()
 A:SetSetting("floating",true);T.eq(notifications,previous,"unsubscribe stops later availability notifications")
 -- Public callbacks may re-enter Attach or fail. Keep external failures at
 -- the API boundary so the remaining notifications and cleanup still run.
 local errors={};local oldErrorHandler=geterrorhandler
 geterrorhandler=function() return function(message) errors[#errors+1]=message end end
 local immediate=API:Subscribe(function() error("immediate subscriber") end)
 T.eq(#errors,1,"an immediate subscriber error is reported")
 immediate()
 local goodCalls=0
 local bad=API:Subscribe(function() error("later subscriber") end)
 local good=API:Subscribe(function() goodCalls=goodCalls+1 end)
 local before=goodCalls
 A:SetSetting("floatingCompatibility",false)
 T.eq(goodCalls,before+1,"a failing subscriber does not block later subscribers")
 T.ok(#errors>=3,"later subscriber errors are reported")
 bad();good();A:SetSetting("floatingCompatibility",true)

 local host2=CreateFrame("Button",nil,UIParent);host2:SetSize(120,24)
 local ownerB={};local releaseMode="reattach"
 local function ReentrantRelease()
  if releaseMode=="reattach" then
   T.eq(API:Attach(ownerB,host2,24,label,function() end),true)
  elseif releaseMode=="disable" then
   A:SetSetting("floatingCompatibility",false)
  elseif releaseMode=="error" then
   error("release callback")
  end
 end
 T.eq(API:Attach(owner,host,24,label,ReentrantRelease),true)
 ok,reason=API:Attach(owner,host2,24,label,function() end)
 T.eq(ok,false,"reentrant owner B keeps the slot during owner A's host change")
 T.eq(reason,"occupied");T.eq(F.host,host2)
 T.eq(API:Detach(ownerB),true)

 releaseMode="disable"
 T.eq(API:Attach(owner,host,24,label,ReentrantRelease),true)
 ok,reason=API:Attach(owner,host2,24,label,function() end)
 T.eq(ok,false,"a release callback that disables compatibility blocks the outer attach")
 T.eq(reason,"unavailable");T.eq(F.host,nil)
 A:SetSetting("floatingCompatibility",true)

 releaseMode="error"
 T.eq(API:Attach(owner,host,24,label,ReentrantRelease),true)
 T.eq(API:Detach(owner),true,"a failed external release is isolated after ownership is cleared")
 T.ok(#errors>=4,"release errors are reported")
 T.eq(API:Attach(owner,host,24,label,function() end),true,"failed release cleanup leaves the API available for remount")
 T.eq(API:Detach(owner),true)
 geterrorhandler=oldErrorHandler
 A:SetSetting("floating",false)
end
do
 -- Match the exported RurutiaSuite 4.5.7 TopBar contract, including a baseline
 -- layout refresh that writes its own text and retains non-left clicks.
 dofile("addon/LycheeGroup/Adapters/Rurutia.lua")
 local R=A.Adapters.Rurutia
 C_AddOns.GetAddOnMetadata=function() return nil end
 R:Initialize();A:SetSetting("floating",true)
 T.eq(F.host,nil,"missing RurutiaSuite keeps the standalone entry")
 local host=CreateFrame("Button",nil,UIParent);host:SetSize(90,20);host:SetScale(.8)
 local icon=host:CreateTexture(nil,"ARTWORK");icon:SetTexture("original-icon");icon:SetSize(33,34)
 local text=host:CreateFontString(nil,"OVERLAY");text:SetText("集合石");text:SetFont("Rurutia.ttf",18,"OUTLINE");text:SetPoint("CENTER",host,"CENTER",6,0)
 local font={}
 function font:Subscribe(owner,fn) self.owner,self.callback=owner,fn end
 function font:Unsubscribe(owner) if owner==self.owner then self.owner,self.callback=nil,nil end end
 function font:ApplyFontString(label,path) local _,size,flags=label:GetFont();label:SetFont(path,size,flags) end
 local record={frame=host,icon=icon,text=text,active=true}
 local View={}
 function View:HideTooltip() GameTooltip:Hide() end
 function View:RefreshQuick(key)
  if key~="meetingstone" then return end
  self.records[key].active=true;host:Show();icon:Show();text:Show();text:SetText("集合石")
 end
 function View:ShowComponent(key,visible)
  if visible then self:RefreshQuick(key) else record.active=false;host:Hide() end
 end
 function View:HideAll() host:Hide() end
 local view=setmetatable({records={meetingstone=record}},{__index=View})
 local markerBar=CreateFrame("Frame",nil,UIParent);markerBar:SetSize(300,24)
 markerBar.GetTop=function() return 30 end
 local markerView={bar=markerBar}
 host:SetScript("OnEnter",function() GameTooltip:Show() end)
 host:SetScript("OnLeave",function() GameTooltip:Hide() end)
 local clicked
 local originalClick=function(_,button) clicked=button end;host:SetScript("OnClick",originalClick)
 _G.RurutiaSuite={TopBarViewClass=View,TopBar={view=view},RaidMarker={view=markerView},Font=font}
 A:SetSetting("floating",false)
 R:Initialize()
 T.eq(F.host,nil,"an adapter initialized before floating is enabled waits for availability")
 A:SetSetting("floating",true)
 T.eq(F.host,host);T.eq(F.frame:GetParent(),host);T.eq(F.button:IsShown(),false,"integration has only the existing top bar mouse target")
 T.eq(F.count,text,"the integrated label is the original Rurutia font string");T.eq(F.logoAnchor:GetParent(),F.frame)
 T.eq(icon:IsShown(),false);T.eq(text:IsShown(),true);T.eq(icon:GetTexture(),"original-icon")
 T.eq(F.logoTexture:GetWidth(),34);T.eq(F.count:GetText(),"申请1个")
 T.eq(F.count:GetFont(),"Rurutia.ttf");T.eq(select(2,F.count:GetFont()),18);T.eq(select(3,F.count:GetFont()),"OUTLINE")
 T.eq(select(2,F.logoAnchor:GetPoint()),text);T.eq(select(5,F.logoAnchor:GetPoint()),0,"the logo follows the native text's vertical anchor")
 T.eq(text:GetPoint(),"CENTER");T.eq(select(4,text:GetPoint()),6);T.eq(select(5,text:GetPoint()),0,"the original text anchor is preserved")
 font.callback(font.owner,font,"interface","Other","Other.ttf")
 T.eq(F.count:GetFont(),"Other.ttf");T.eq(select(2,F.count:GetFont()),18);T.eq(select(3,F.count:GetFont()),"OUTLINE","font settings preserve Rurutia's size and outline")
 A.Floating:ApplyFont("Lychee.ttf");T.eq(F.count:GetFont(),"Other.ttf","Lychee's font setting does not restyle the Rurutia entry")
 T.eq(F.frame:GetWidth(),90);T.eq(host:GetWidth(),90,"count layout does not resize the host")
 T.near(F.panel:GetEffectiveScale(),A.db.floatingScale/100,.001,"popup scale is independent of the top bar scale")
 host:Fire("OnClick","RightButton");T.eq(clicked,"RightButton")
 host:Fire("OnClick","LeftButton");T.eq(A.openedPage,"find","outgoing applications open the group list")
 local savedApps=apps;apps={};callback("applications")
 T.eq(text:GetText(),"荔枝组队","the native Rurutia text also shows the brand while idle")
 View.RefreshQuick(view,"meetingstone");T.eq(text:GetText(),"荔枝组队","a top bar refresh preserves the idle brand")
 apps=savedApps;callback("applications")
 host.mouseOver=true;host:Fire("OnEnter")
 T.eq(GameTooltip:IsShown(),false,"the native tooltip yields to the existing floating list")
 T.eq(F.panel:IsShown(),true);T.eq(select(2,F.panel:GetPoint()),host,"the popup anchors to the top bar target")
 T.near(select(5,F.panel:GetPoint()),(30-16)/F.panel:GetEffectiveScale()+8,.001,"Rurutia reserves the raid-marker controls through the public API")
 host.GetTop=function() return 1000 end;host.GetLeft=function() return 100 end
 View.RefreshQuick(view,"meetingstone")
 T.eq(F.panel:GetPoint(),"TOPLEFT","moving the entry away from the marker bar keeps the popup near its entry")
 T.eq(select(5,F.panel:GetPoint()),-8,"a distant marker bar does not reserve the screen between the two controls")
 host:Fire("OnEnter");T.eq(select(5,F.panel:GetPoint()),-8,"reopening also excludes independently moved controls")
 host.GetTop,host.GetLeft=nil,nil;View.RefreshQuick(view,"meetingstone")
 T.near(select(5,F.panel:GetPoint()),(30-16)/F.panel:GetEffectiveScale()+8,.001,"returning the entry restores nearby marker avoidance")
 local reads,measures=0,0
 local getApplications,measureHeight=G.GetApplications,F.measure.GetStringHeight
 G.GetApplications=function(...) reads=reads+1;return getApplications(...) end
 F.measure.GetStringHeight=function(...) measures=measures+1;return measureHeight(...) end
 local version,fade,cards=F.entriesVersion,F.fade,F.cardElapsed
 for i=1,25 do View.RefreshQuick(view,"meetingstone") end
 T.eq(reads,0,"unrelated top bar refreshes do not read the application list")
 T.eq(measures,0,"unrelated top bar refreshes do not remeasure popup entries")
 T.eq(F.entriesVersion,version);T.eq(F.fade,fade);T.eq(F.cardElapsed,cards)
 host.GetTop=function() return 1200 end;host.GetLeft=function() return 1700 end
 host:SetScale(.9);host:SetSize(110,24);View.RefreshQuick(view,"meetingstone")
 T.eq(F.frame:GetWidth(),110);T.eq(F.frame:GetHeight(),24)
 T.near(F.panel:GetEffectiveScale(),A.db.floatingScale/100,.001,"host scaling leaves the popup at its configured scale")
 T.eq(F.panel:GetPoint(),"TOPRIGHT","moving the host to the top right repositions the existing popup")
 T.eq(select(3,F.panel:GetPoint()),"BOTTOMRIGHT");T.eq(F.entriesVersion,version)
 T.eq(reads,0);T.eq(measures,0,"geometry changes reuse measured list content")
 G.GetApplications,F.measure.GetStringHeight=getApplications,measureHeight
 local oldTitle=apps[1].name;apps[1].name="Updated application";callback("applications")
 T.eq(F.rows[1].meta:GetText(),"Updated application","real business notifications still rebuild visible content")
 apps[1].name=oldTitle;callback("applications")
 host.GetTop,host.GetLeft=nil,nil;host:SetScale(.8);host:SetSize(90,20);View.RefreshQuick(view,"meetingstone")
 host.mouseOver=false;host:Fire("OnLeave");F.panel.mouseOver=true;base.AdvanceClock(.12)
 T.eq(F.panel:IsShown(),true,"moving from the host into its list does not close it")
 F.panel.mouseOver=false;F.panel:Fire("OnEvent","GLOBAL_MOUSE_DOWN")
 T.eq(F.panel:IsShown(),false);T.eq(F.countdown,nil)
 local oldManageApplicants,oldManageListing=manageApplicants,manageListing
 nativeListing=true;manageApplicants,manageListing=false,false
 T.eq(F.recruiting,false)
 host:Fire("OnClick","LeftButton")
 T.eq(A.openedPage,"create","an ordinary member opens their active party listing from the integrated entry before its status refresh")
 nativeListing=nil;manageApplicants,manageListing=oldManageApplicants,oldManageListing
 A:SetSetting("reduceMotion",false);listing={activityID=1};applicant.status="applied";callback("listing")
 T.eq(F.count:GetText(),"1人申请","switching mode changes wording even when the count is unchanged")
 host:Fire("OnClick","LeftButton");T.eq(A.openedPage,"create","an active listing opens recruitment from the integrated entry")
 host:Fire("OnEnter");T.eq(G.applicantViews[F],true,"integrated hover uses the existing viewed-applicants notification")
 F:Dismiss();T.eq(G.applicantViews[F],nil)
 T.ok(F.attentionTimer)
 F.context.Motion:Tick(.2);local animation=F.brandMotion.elapsed;T.ok(F.logoTexture:GetWidth()~=34,"integrated logo uses the same brand animation")
 View.RefreshQuick(view,"meetingstone")
 T.eq(F.brandMotion.elapsed,animation,"a host refresh does not restart or reset the logo")
 T.eq(icon:IsShown(),false);T.eq(text:IsShown(),true);T.eq(text:GetText(),"1人申请","a top bar refresh cannot replace the status with its original label")
 A:SetSetting("floatingCompatibility",false)
 T.eq(F.host,nil);T.eq(F.frame:GetParent(),UIParent);T.eq(F.button:IsShown(),true)
 T.eq(icon:IsShown(),true);T.eq(text:IsShown(),true);T.eq(text:GetText(),"集合石");T.eq(F.logoTexture:GetWidth(),38)
 T.eq(font.callback,nil,"disabling integration unsubscribes from Rurutia font changes")
 T.eq(host:GetScript("OnClick"),originalClick,"disabling integration restores the original click handler")
 T.eq(F.count:GetParent(),F.button);T.eq(F.logoAnchor:GetParent(),F.button)
 host:Fire("OnEnter");T.eq(GameTooltip:IsShown(),true);T.eq(F.panel:IsShown(),false,"disabled integration restores the original tooltip")
 A:SetSetting("floatingCompatibility",true);T.eq(F.host,host)
 View.ShowComponent(view,"meetingstone",false);T.eq(F.host,nil,"disabling the top bar component restores the standalone entry")
 View.ShowComponent(view,"meetingstone",true);T.eq(F.host,host,"reenabling the component reuses the same floating objects")
 View.HideAll(view);T.eq(F.host,nil)
 View.RefreshQuick(view,"meetingstone");T.eq(F.host,host)
 local savedPosition,existingFrame=A.db.floatingPosition,F.frame
 local getStringWidth=F.ownCount.GetStringWidth
 -- The client reports the rendered (possibly truncated) width for bounded text.
 F.ownCount.GetStringWidth=function(label) return math.min(label:GetWidth(),label:GetUnboundedStringWidth()) end
 F.ownCount:SetWidth(18)
 F:ToggleStandaloneTest()
 T.eq(F.host,nil);T.eq(F.frame:GetPoint(),"CENTER");T.eq(F.panel:IsShown(),true)
 T.ok(F.count:GetWidth()>=F.count:GetUnboundedStringWidth(),"restoring the standalone entry fits the complete label instead of keeping its old clipped width")
 T.eq(icon:IsShown(),true);T.eq(text:GetText(),"集合石","test mode restores the original top bar entry")
 T.eq(A.db.floatingCompatibility,true,"testing does not change the compatibility setting")
 T.eq(F.frame,existingFrame,"testing reuses the real floating window")
 View.RefreshQuick(view,"meetingstone");T.eq(F.host,nil,"top bar refreshes leave the standalone test visible")
 F.button:Fire("OnDragStart");F.button:Fire("OnDragStop")
 T.eq(A.db.floatingPosition,savedPosition,"dragging the test window preserves the saved position")
 F:ToggleStandaloneTest()
 T.eq(F.host,host);T.eq(F.panel:IsShown(),false);T.eq(icon:IsShown(),false)
 F.ownCount.GetStringWidth=getStringWidth
 A:SetSetting("floating",false)
 F:ToggleStandaloneTest();T.eq(F.frame:IsShown(),true,"the explicit test also works with floating disabled")
 T.eq(A.db.floating,false,"testing does not enable the saved floating setting")
 F:ToggleStandaloneTest();T.eq(F.frame:IsShown(),false,"closing the test restores the disabled setting")
 T.eq(F.host,nil);T.eq(icon:IsShown(),true);T.eq(text:IsShown(),true)
 T.eq(base.PendingTimers(),0);T.eq(F.context.Motion:Count(),0,"disabled integration leaves no animation or popup timers")
 _G.RurutiaSuite=nil;GameTooltip:Hide()
end
-- Compact empty content is shared by the standalone and integrated popups.
for _,locale in ipairs({"zhCN","enUS"}) do
 local clock=dofile("tests/stubs.lua");clock.Install({locale=locale,realm="Home"})
 local native=dofile("tests/ui_stubs.lua");native.Install()
 _G.LycheeUI=nil;_G.LycheeGroup=nil;_G.LycheeGroupDB=nil
 local private={}
 for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Styles.lua","Components.lua","Layouts.lua","Elements.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",private) end
 for _,file in ipairs({"Locale.lua","Theme/Defaults.lua","Theme/Elements.lua","Core.lua","Configuration.lua","Appearance.lua","Theme/Import.lua","Specializations.lua","Fonts.lua","BrandMotion.lua","Floating.lua","API.lua","Presentation.lua"}) do dofile("addon/LycheeGroup/"..file) end
 local addon=LycheeGroup;addon:LoadDB();addon:SetSetting("reduceMotion",true)
 local applications,activeListing,notify={},nil,nil
 local group={Applications={GetActiveCount=function() return #applications end,IsActive=function() return true end},
  Catalog={GetActivity=function() return {categoryID=2,maxNumPlayers=5} end}}
 function group:GetApplications() return applications end
 function group:GetListing() return activeListing end
 function group:GetApplicants() return {} end
 function group:CanManageApplicants() return true end
 function group:CanManageListing() return true end
 function group:SetApplicantView() end
 function group:Subscribe(callback) notify=callback;return function() end end
 addon.Group=group
 local floating,api=addon.Floating,addon.API.Floating
 floating:Bind(group);floating:UpdateSettings()
 local idleText=locale=="zhCN" and "暂无活动" or "No activity"
 local waitingText=locale=="zhCN" and "暂无申请" or "No applications"
 local brand=locale=="zhCN" and "荔枝组队" or "Lychee LFG"
 local card=floating.emptyCard
 for _,integrated in ipairs({false,true}) do
  local host,owner
  if integrated then
   owner={};host=CreateFrame("Button",nil,UIParent);host:SetSize(90,20);host:SetScale(.8)
   local label=host:CreateFontString(nil,"OVERLAY");label:SetFont("Rurutia.ttf",18,"OUTLINE");label:SetPoint("CENTER")
   T.eq(api:Attach(owner,host,24,label,function() end),true)
  end
  local function Open()
   if integrated then T.eq(api:ShowPopup(owner),true) else floating.button:Fire("OnEnter") end
  end
  local function Empty(message,height)
   Open()
   T.eq(floating.empty:GetText(),message);T.eq(floating.emptyCard,card,"all empty states reuse one card")
   T.ok(card:IsShown());T.ok(card:GetWidth()<324,"short localized empty content remains compact")
   T.ok(card:GetWidth()-floating.empty:GetUnboundedStringWidth()>=32,"the complete empty label retains its horizontal padding")
   T.eq(floating.panel:GetWidth(),card:GetWidth()+24);T.eq(floating.scroll:GetWidth(),card:GetWidth())
   T.eq(floating.panel:GetHeight(),height);T.eq(floating.scroll:GetHeight(),44)
   T.eq(floating.body:GetWidth(),324,"empty viewport resizing leaves the content canvas width stable")
   T.eq(select(2,floating.panel:GetPoint()),floating:GetAnchor())
   T.near(floating.panel:GetEffectiveScale(),addon.db.floatingScale/100,.001)
  end
  applications={};activeListing=nil;notify("applications")
  Empty(idleText,60);T.eq(floating.count:GetText(),brand,"the folded idle entry retains the product name")
  applications={{id=1,status="invited"}};notify("applications")
  Empty(waitingText,60)
  activeListing={activityID=1};notify("listing")
  Empty(waitingText,84);T.ok(floating.cancel:IsShown(),"an empty listing retains its end-listing action")
  T.ok(floating.panel:GetWidth()>=floating.cancel:GetWidth()+48,"a compact recruitment header still fits its complete action")
  activeListing=nil;applications={{id=1,status="applied",name="Group",activityName="Dungeon",leaderName="Leader-Away"}};notify("listing")
  T.eq(floating.panel:GetWidth(),348);T.eq(floating.scroll:GetWidth(),324)
  T.eq(floating.emptyCard:IsShown(),false);T.eq(floating.rows[1]:GetWidth(),324,"real application rows recover their original full width")
  applications={};notify("applications")
  T.eq(floating.panel:IsShown(),false,"the last waiting application still closes the popup")
  Empty(idleText,60)
  local measure=floating.empty.GetUnboundedStringWidth
  floating.empty.GetUnboundedStringWidth=function() return 323.7 end
  floating:LayoutPanel()
  T.ok(card:GetWidth()>=323.7+32,"wider font metrics can expand an empty card without clipping")
  T.eq(floating.rows[1]:GetWidth(),324,"a widened empty viewport never resizes the fixed row pool")
  T.eq(floating.body:GetWidth(),324)
  floating.empty.GetUnboundedStringWidth=measure;floating:LayoutPanel()
  T.ok(card:GetWidth()<324,"restoring short text metrics returns to the compact width")
  if integrated then
   host.GetTop=function() return 1200 end;host.GetLeft=function() return 1700 end
   host:SetSize(110,24);host:SetScale(.9);api:Refresh(owner)
   T.eq(floating.panel:GetPoint(),"TOPRIGHT","a resized host retains the popup's screen-edge anchoring")
   T.eq(card:GetWidth(),floating.scroll:GetWidth());T.eq(floating.rows[1]:GetWidth(),324)
   T.near(floating.panel:GetEffectiveScale(),addon.db.floatingScale/100,.001)
   api:Detach(owner)
  else floating:Dismiss() end
 end
 addon:SetSetting("floating",false)
 T.eq(clock.PendingTimers(),0)
end
_G.LycheeGroup=nil;_G.LycheeGroupDB=nil
