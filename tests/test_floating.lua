-- The status entry remains usable before the UI business package is loaded.
local base=dofile("tests/stubs.lua");base.Install({locale="zhCN",realm="Home"})
local stub=dofile("tests/ui_stubs.lua");stub.Install()
_G.LycheeUI=nil
local libraryPrivate={}
for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Components.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",libraryPrivate) end
_G.LycheeGroup=nil;_G.LycheeGroupDB=nil
for _,file in ipairs({"Locale.lua","Core.lua","Fonts.lua","Floating.lua"}) do dofile("addon/LycheeGroup/"..file) end
local A=LycheeGroup;A:LoadDB()
local apps={{id=1,name="A group",status="applied",activityID=1,activityName="A dungeon",leaderName="Leader-Away",expiresAt=130},{id=2,name="An invitation",status="invited",activityID=1}}
local members={};for i=1,30 do members[i]={name="Player"..i.."-Away",nameKey="Player"..i.."-Away",class="WARRIOR",specID=71,dungeonScore=2000+i,itemLevel=500+i} end
dofile("addon/LycheeGroup_Group/Group.lua");local resolveSpec=A.Group.ResolveMemberSpec
dofile("addon/LycheeGroup/Presentation.lua")
local listing,callback
local manageApplicants,manageListing=true,true
local applicant={status="applied",members=members,comment="A shared application note"}
local G={ResolveMemberSpec=resolveSpec,Applications={GetActiveCount=function() return #apps end,IsActive=function() return true end},GetListing=function() return listing end,GetApplications=function() return apps end,
 GetApplicants=function() return {77} end,GetApplicant=function() return applicant end,Subscribe=function(_,fn) callback=fn;return function() end end}
local activities={[1]={categoryID=2,maxNumPlayers=5},[2]={categoryID=3,maxNumPlayers=30},[3]={categoryID=4,maxNumPlayers=3}}
G.Catalog={GetActivity=function(_,id) return activities[id] end}
function G:GetApplication(id) for _,app in ipairs(apps) do if app.id==id then return app end end end
function G:CanManageApplicants() return manageApplicants end
function G:CanManageListing() return manageListing end
function G:Cancel(id) G.cancelled=id;return true end
function G:Invite(id) G.inviteCalls=(G.inviteCalls or 0)+1;if applicant.acting then return false,"Pending" end;applicant.acting=true;G.invited=id;callback("applicants");return true end
function G:Decline(id) if G.failDecline then return false,"Decline failed" end;if applicant.acting then return false,"Pending" end;applicant.acting=true;G.declined=id;callback("applicants");return true end
A.Group=G;A.Open=function(_,page,context) A.openedPage=page;A.openedContext=context end
RAID_CLASS_COLORS={WARRIOR={r=.8,g=.6,b=.4}}
C_LFGList.GetActivityInfoTable=function() return {} end
_G.GetTime=function() return 0 end
local F=A.Floating;F:Bind(G);F:UpdateSettings();F:ShowPanel()
local function Position(frame)
 local _,relative,point,x,y=frame:GetPoint();if type(relative)=="number" then return relative,point end;return x,y
end
T.eq(A.UI,nil,"hover does not load the UI addon")
T.eq(F.panel.events.GLOBAL_MOUSE_DOWN,true,"the expanded popup observes global clicks without a full-screen input catcher")
local entryButtons=0;for _,child in ipairs({F.frame:GetChildren()}) do if child:GetObjectType()=="Button" then entryButtons=entryButtons+1 end end
T.eq(entryButtons,1,"the collapsed icon and number share one actual button")
T.eq(F.frame:GetWidth(),80);T.eq(F.frame:GetHeight(),44);T.eq(F.panel:GetWidth(),348);T.eq(F.scroll:GetWidth(),324)
T.eq(F.count:GetText(),"1");T.eq(F.rows[1].name:GetText(),"A dungeon");T.eq(F.rows[1].meta:GetText(),"A group");T.eq(F.rows[1].leader:GetText(),"Leader-Away");T.eq(F.rows[1].timer:GetText(),"2:10")
T.eq(F.rows[1].background:IsShown(),true,"each resting application keeps its own card")
T.eq(F.rows[1].faction:IsShown(),false,"outbound application cards have no applicant faction marker")
T.eq(F.rows[1].faction:GetTexture(),nil)
T.eq(F.panel.background,nil,"the space around application cards has no outer backdrop")
T.eq(F.frame:IsMouseEnabled(),false,"the outer container adds no second mouse target")
T.eq(F.count:GetParent(),F.button);T.eq(F.logoTexture:GetParent(),F.logoAnchor);T.eq(F.logoAnchor:GetParent(),F.button)
T.eq(F.button.fill:IsShown(),false,"the unified entry stays transparent at rest")
F.button:Fire("OnEnter");F.context.Motion:Tick(.12)
T.eq(F.button.hover:IsShown(),true,"one capsule highlights both the icon and the number")
F.button:Fire("OnLeave");T.eq(F.button.hover:IsShown(),false)
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
apps[1].activityLabel="A longer dungeon activity name";apps[1].activityDetail="A very long difficulty label";callback("applications")
local applicationRow=F.rows[1];local detailX,detailY=Position(applicationRow.score);local _,titleY=Position(applicationRow.meta)
T.ok(applicationRow.score:GetStringHeight()>22,"long activity details wrap instead of losing text")
T.ok(-detailY+applicationRow.score:GetStringHeight()<=-titleY,"the complete activity heading fits above the group title")
local cancelX=Position(applicationRow.cancel)
T.ok(detailX+applicationRow.score:GetWidth()+8<=324+cancelX-applicationRow.cancel:GetWidth(),"the activity heading leaves a real gap before cancel")
T.ok(Position(applicationRow.leader)+applicationRow.leader:GetWidth()+12<=324-12-applicationRow.timer:GetWidth(),"leader and countdown have independent columns")
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
T.eq(F.empty.justify,"CENTER","empty text is centered within its complete width")
T.eq(F.empty:GetPoint(),"CENTER");T.eq(select(2,Position(F.emptyCard)),-8,"empty content keeps equal top and bottom padding")
apps[1].status="applied";callback("applications")
T.eq(F.cancel:IsShown(),true);T.eq(F.emptyCard:IsShown(),false)
T.eq(select(2,Position(F.scroll)),-32,"restored applications regain the action header")
T.eq(F.rows[1]:GetHeight(),98,"restoring applications keeps the card's twelve-pixel vertical padding")
local _,headingY=Position(F.rows[1].name);local _,leaderY=Position(F.rows[1].leader)
T.eq(-headingY,12);T.near(F.rows[1]:GetHeight()+leaderY-F.rows[1].leader:GetStringHeight(),12,.001,"last line keeps the same bottom padding")
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
T.eq(F.rows[1].background.fill.color[4],.66,"row hover keeps the individual card translucent")
T.ok(F.rows[1].cancel.hover:IsShown(),"the icon retains its local red feedback");T.eq(GameTooltip:IsShown(),false,"single cancellation also omits a tooltip")
F.rows[1].cancel:Fire("OnLeave");T.eq(F.rows[1].background.fill.color[4],.60);T.eq(F.rows[1].cancel.hover:IsShown(),false)
apps[2].status="applied";for i=3,5 do apps[i]={id=i,name="Another group",status="applied",activityID=1} end
F:ShowPanel();T.eq(F.scroll:GetHeight(),522,"five padded application cards remain fully visible");T.eq(F.rows[1]:GetHeight(),98);T.eq(F.scrollBar:IsShown(),false,"floating wheel scrolling has no visible track");T.eq(F.rows[5]:IsShown(),true)
for i=5,3,-1 do apps[i]=nil end;apps[2].status="invited";F.panel:Hide()
F:ShowPanel()
members[1].factionGroup=1;members[2].factionGroup=0
listing={name="My listing",activityID=1};callback("listing");T.eq(F.count:GetText(),"30","recruitment counts individual people");T.eq(F.scroll:GetHeight(),UIParent:GetHeight()/F.frame:GetScale()-F.frame:GetHeight()-48)
T.eq(F.context.logo,F.logoTexture,"the applicant reminder animates the original logo through the shared Brand context")
T.eq(F.entries,workingEntries);T.eq(F.entries[1],firstEntry);T.eq(firstEntry.application,nil,"recruitment reuse clears the previous application reference")
local batchEntry=F.entries[1].batch
local comments=0;for _,entry in ipairs(F.entries) do if entry.comment then comments=comments+1 end end;T.eq(comments,1,"one shared comment is displayed at the bottom of its application batch")
T.eq(F.rows[1].name:GetText(),"Player1-Away","recruitment shows players directly without group-size headings");T.eq(F.rows[1].meta:GetText(),"战士 · Specialization");T.eq(F.rows[1].score:GetText(),"2001")
T.eq(F.rows[1].itemLevel:GetText(),"装等 501","native item level has its own right-aligned second line")
do
 local row=F.rows[1];local faction=row.faction
 T.eq(faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-alliance.tga");T.eq(faction:IsShown(),true)
 T.eq(F.rows[2].faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-horde.tga","native faction zero shows Horde")
 T.eq(faction:GetWidth(),16);T.eq(faction:GetHeight(),16)
 local x,y=Position(faction);local nameX,nameY=Position(row.name)
 T.near(x,nameX+row.name:GetStringWidth()+6,.001,"a short name is followed by its faction with a six-pixel gap")
 T.eq(y-faction:GetHeight()/2,nameY-11,"the marker centers on the name's first line")
 T.ok(x+faction:GetWidth()+12<=324-12-row.score:GetWidth(),"identity and faction retain the metric-column gap")
 T.eq(F.rows[3].faction:IsShown(),false);T.eq(F.rows[3].faction:GetTexture(),nil,"unknown members do not inherit another member's faction")
 members[1].factionGroup=0;callback("applicants")
 T.eq(row.faction,faction,"member refreshes reuse the same marker");T.eq(faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-horde.tga")
 members[1].factionGroup=nil;callback("applicants")
 T.eq(faction:IsShown(),false);T.eq(faction:GetTexture(),nil,"losing known faction clears the old texture")
 T.eq(row.name:GetWidth(),168,"unknown faction restores the full name width")
 members[1].factionGroup=1;callback("applicants")
 T.eq(A.UI,nil,"faction textures do not load the UI addon")
end
T.eq(F.rows[1].batch,F.rows[2].batch,"member rows belong to one continuous batch hover area")
F.rows[1]:Fire("OnEnter");T.eq(F.rows[1].batch.background:IsShown(),true);T.eq(F.rows[1].background:IsShown(),false,"members never draw separate hover bars")
T.eq(F.rows[1].batch.line,nil,"a party card has no grouping line");T.eq(F.rows[1].batch.background.fill.color[4],.66,"hover highlights the complete application card")
F.rows[1]:Fire("OnLeave");T.eq(F.rows[1].batch.background.fill.color[4],.60,"leaving the batch restores its resting card")
F.scroll:SetVerticalScroll(F.entryTops[30]);F:Render()
T.eq(F.rows[1].faction:IsShown(),false);T.eq(F.rows[1].faction:GetTexture(),nil,"a row rebound to an unknown member clears the previous faction")
local lastMember;for _,row in ipairs(F.rows) do if row:IsShown() and row.name:GetText()=="Player30-Away" then lastMember=row end end
T.ok(lastMember,"complete applicant roster stays scrollable after list text grows")
lastMember:Fire("OnClick");T.eq(A.openedPage,"create");T.eq(A.openedContext.applicantID,77)
F.scroll:SetVerticalScroll(F.body:GetHeight()-F.scroll:GetHeight());F:Render()
local actionRow,commentRow;for _,row in ipairs(F.rows) do if row.invite:IsVisible() then actionRow=row end;if row.name:GetText()==applicant.comment then commentRow=row end end
T.ok(actionRow,"the shared footer keeps one action pair");T.eq(commentRow,actionRow,"the shared comment and the one action pair occupy a single footer")
T.eq(commentRow.faction:IsShown(),false);T.eq(commentRow.faction:GetTexture(),nil,"a shared footer never inherits an applicant marker")
T.ok(Position(commentRow.name)+commentRow.name:GetWidth()+12<=324+Position(actionRow.invite)-actionRow.invite:GetWidth(),"the comment leaves a real gap before the invite hit area")
T.eq(F.rows[1].invite:IsShown(),false,"member rows do not duplicate footer actions")
T.eq(Position(commentRow.name),Position(F.rows[1].name),"the shared note aligns with the member text column")
T.ok(actionRow:GetHeight()>=40,"the footer keeps room for the note and twelve-pixel bottom inset")
local actionPoint=select(1,actionRow.invite:GetPoint());local actionX,actionY=Position(actionRow.invite);T.eq(actionPoint,"BOTTOMRIGHT");T.eq(actionX,-48);T.eq(actionY,12,"the invite hit area clears the card bottom by twelve pixels")
local declinePoint=select(1,actionRow.decline:GetPoint());local declineX,declineY=Position(actionRow.decline);T.eq(declinePoint,"BOTTOMRIGHT");T.eq(declineX,-12);T.eq(declineY,12,"the decline hit area shares the same outer inset")
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
T.eq(F.count:GetText(),"1","ordinary members retain the applicant count")
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
T.eq(select(2,F.rows[1].leader:GetFont()),14);T.eq(select(2,F.rows[1].timer:GetFont()),14)
T.eq(select(2,commentRow.name:GetFont()),12,"shared comments use the compact footer typography")
T.ok(56+F.rows[1].name:GetWidth()+12<=324-12-F.rows[1].itemLevel:GetWidth(),"the name and metric columns retain a twelve-pixel gap")
T.eq(F.rows[1].icon:GetWidth(),32,"the applicant avatar spans the name and specialization block")
local iconX,iconY=Position(F.rows[1].icon)
local nameX,nameY=Position(F.rows[1].name)
local metaX,metaY=Position(F.rows[1].meta)
T.eq(iconX,12);T.eq(nameX,56);T.eq(metaX,56)
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
T.eq(factionY-F.rows[1].faction:GetHeight()/2,nameY-11,"a wrapped name keeps faction on its first line")
T.ok(factionX+F.rows[1].faction:GetWidth()+12<=324-12-F.rows[1].score:GetWidth(),"long identities leave room for faction before the score")
members[1].nameKey=originalKey;callback("applicants")
local comment=applicant.comment
applicant.comment="熟练";callback("applicants");T.eq(F.body:GetHeight(),92,"one complete member and a short note fit in a naturally padded 92-pixel card")
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
F:ShowPanel();T.eq(#F.entries,0,"reopening never revives an acting applicant");T.eq(F.count:GetText(),"0","the collapsed count uses the same operable filter as the list")
T.eq(F.emptyCard:IsShown(),true);T.eq(F.emptyCard:GetHeight(),44)
T.eq(F.cancel:IsShown(),true,"the owner can still end an empty listing")
T.eq(F.panel:GetHeight(),84,"the empty recruitment view reserves only its meaningful listing action and centered content")
F.panel:Fire("OnEvent","GLOBAL_MOUSE_DOWN","RightButton")
T.eq(F.panel:IsShown(),false,"an explicitly hovered empty listing can also be closed by an outside click")
applicant.acting=nil;callback("applicants");T.eq(F.panel:IsShown(),false,"a closed empty listing stays closed when applicants return")
F:ShowPanel();T.eq(#F.entries,2,"an operable native record can return after explicit hover")
F:Tick(.23);T.eq(F.panel:GetAlpha(),1,"expanded panel finishes its finite fade")
F:SetOffset(0,true);T.ok(F.scrollTween);local scrollState=F.scrollTween;F:SetOffset(11,true);T.eq(F.scrollTween,scrollState,"a new scroll target reuses the finite tween state");F:SetOffset(0,true);F:Tick(.2);T.eq(F.scroll:GetVerticalScroll(),0);T.eq(F.scrollTween,nil,"completed scrolling removes its tween")
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
 T.eq(F.count:GetText(),"100");T.ok(F.frame:GetWidth()>80,"the single entry expands to preserve the complete count")
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
 local reads=0
 F.entryTops=setmetatable({},{__index=function(_,index) reads=reads+1;return tops[index] end})
 F:Render()
 T.ok(reads<30,"a stable scroll frame locates visible entries without scanning the complete applicant list")
 F.entryTops=tops;F:Dismiss()
 applicant.members=originalMembers;callback("applicants");T.eq(F.frame:GetWidth(),80)
end
A:SetSetting("reduceMotion",false)
T.ok(F.attention and F.context.Motion.jobs.brand,"restoring motion starts the actual shared Brand job")
T.eq(F.frame:GetScript("OnUpdate"),nil,"the collapsed reminder does not install the panel driver")
local countPoint={F.count:GetPoint()};local framePoint={F.frame:GetPoint()};local beforeAttentionNodes=#stub.nodes
F.context.Motion:Tick(.168)
T.near(F.logoTexture:GetWidth(),38*1.075,.001,"the first original Bezier segment stretches the logo horizontally")
T.near(F.logoTexture:GetHeight(),38*.925,.001,"the same segment squashes the logo vertically around its original pivot")
T.same({F.count:GetPoint()},countPoint,"the count baseline remains stable during attention")
local currentFramePoint={F.frame:GetPoint()};for i,value in ipairs(framePoint) do T.eq(currentFramePoint[i],value,"the clickable container remains stable during attention") end
T.same(F.logoTexture.texCoords,{0,1,0,1},"attention preserves the original full logo UV")
local brandJob,timer=F.context.Motion.jobs.brand,F.attentionTimer;callback("applicants");A:SetSetting("floatingScale",110)
T.eq(F.context.Motion.jobs.brand,brandJob);T.eq(F.attentionTimer,timer,"ordinary data and settings refreshes do not restart the current Brand cycle")
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
T.ok(F.context.Motion.jobs.brand,"the single timer starts the next original Brand animation")
T.eq(base.PendingTimers(),1,"the timer replaces its own handle without accumulating reminders")
F.context.Motion:Tick(.168);T.near(F.logoTexture:GetWidth(),38*1.075,.001)
T.eq(queries,0,"animation and replay never query the applicant service")
G.GetApplicants=getApplicants
T.eq(#stub.nodes,beforeAttentionNodes,"the repeated reminder reuses its texture and existing driver")
A:SetSetting("reduceMotion",true)
T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(F.logoTexture:GetWidth(),38);T.eq(select(2,Position(F.logoTexture)),0)
T.eq(F.frame:GetScript("OnUpdate"),nil,"reduced motion stops and settles the collapsed reminder")
A:SetSetting("reduceMotion",false);F.context.Motion:Tick(.1);F.frame:Hide()
T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(F.logoTexture:GetWidth(),38);T.eq(F.context.Motion.jobs.brand,nil,"hiding the entire entry cancels Brand and the replay timer")
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
 T.eq(F.count:GetText(),"1","reenabling floating refreshes its applicant count")
 F:ShowPanel();T.ok(#F.entries>0,"reenabling floating restores the applicant list on hover")
 A:SetSetting("floating",false);T.eq(F.frame:IsShown(),false);T.eq(base.PendingTimers(),0,"disabling again leaves no pending floating timer")
 G.GetApplications,G.GetApplicants=getApplications,getApplicants
end
_G.LycheeGroup=nil;_G.LycheeGroupDB=nil
