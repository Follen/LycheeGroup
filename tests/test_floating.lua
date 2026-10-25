local function WithNativeFrameColors(action)
 local createFrame=CreateFrame
 CreateFrame=function(kind,...)
  local frame=createFrame(kind,...)
  if kind=="Frame" then
   local previous=getmetatable(frame);local index=previous.__index
   local metatable={};for key,value in pairs(previous) do metatable[key]=value end
   metatable.__index=function(object,key)
    if key=="GetTextColor" or key=="SetTextColor" or key=="GetVertexColor" or key=="SetVertexColor" then return nil end
    if type(index)=="function" then return index(object,key) end
    return index[key]
   end
   setmetatable(frame,metatable)
  end
  return frame
 end
 local ok,err=pcall(action)
 CreateFrame=createFrame
 return ok,err
end
-- Entry clicks toggle the actual UI, including Presence reversal and delayed hide.
for _,integrated in ipairs({false,true}) do
 local fixture=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=false})
 local addon,ui,group=fixture.A,fixture.U,fixture.G
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 local floating,api=addon.Floating,addon.API.Floating
 floating:Bind(group);floating:UpdateSettings()
 local entry=floating.button
 if integrated then
  local host=CreateFrame("Button",nil,UIParent);host:SetSize(120,24);host:SetPoint("CENTER")
  local icon=host:CreateTexture(nil,"ARTWORK");icon:SetSize(24,24)
  local label=host:CreateFontString(nil,"OVERLAY");label:SetFont("host",14,"");label:SetPoint("CENTER");label:SetText("Host entry")
  local rightClicks=0;host:SetScript("OnClick",function(_,button) if button=="RightButton" then rightClicks=rightClicks+1 end end)
  local view={records={meetingstone={frame=host,icon=icon,text=label,active=true}}}
  function view:HideTooltip() end
  _G.RurutiaSuite={TopBar={view=view}}
  dofile("addon/LycheeGroup/Adapters/Rurutia.lua");addon.Adapters.Rurutia:Sync(view)
  host:Fire("OnClick","RightButton");T.eq(rightClicks,1,"integrated right click retains the host action")
  T.eq(ui.frame,nil,"the integrated right click does not create the main window")
  entry=host
 end
 local function Click() entry:Fire("OnClick","LeftButton") end
 local motionSetting=addon:GetSetting("reduceMotion")
 local floatingScale,compatibility=addon:GetSetting("floatingScale"),addon:GetSetting("floatingCompatibility")
 T.eq(ui.frame,nil,"the floating entry works before the main window exists")
 Click();T.eq(ui:IsShown(),true);T.eq(ui.page,"find")
 ui.Motion:Tick(.14);local openedPhase=ui.Motion.phase
 T.ok(openedPhase>0 and openedPhase<1,"the main window is partway through its normal opening motion")
 Click();T.eq(ui.hiding,true,"clicking the entry during opening starts closing")
 T.near(ui.Motion.phase,openedPhase,.000001,"closing starts at the current opening phase")
 local oldHide=ui.finishHide
 ui.Motion:Tick(.04);local closingPhase=ui.Motion.phase
 T.ok(closingPhase<openedPhase and closingPhase>0,"the closing animation progresses normally")
 Click();T.eq(ui.hiding,nil,"clicking during exit reopens instead of starting another hide")
 T.near(ui.Motion.phase,closingPhase,.000001,"reopening starts at the displayed closing phase")
 oldHide();T.eq(ui:IsShown(),true,"a replaced exit callback cannot hide the reopened window")
 ui.Motion:Tick(1);T.eq(ui.Motion.phase,1);T.eq(ui:IsShown(),true)
 addon:Open("notes");Click();T.eq(ui.hiding,true,"the entry closes whichever main page is open")
 T.eq(ui.page,"notes","closing does not first navigate to another page")
 ui.Motion:Tick(1);T.eq(ui:IsShown(),false);T.eq(ui.hiding,nil)
 group.listing={activityID=2,name="Current party listing",comment=""}
 Click();T.eq(ui.page,"create","opening resolves the current native party listing")
 ui.Motion:Tick(1)
 api:Open();T.eq(ui.hiding,nil);T.eq(ui:IsShown(),true,"the public Open method retains its explicit open behavior")
 Click();ui.Motion:Tick(1);T.eq(ui:IsShown(),false,"a completed entry close hides the main window")
 Click();ui.Motion:Tick(1);T.eq(ui:IsShown(),true,"the hidden frame opens again on the next entry click")
 T.eq(addon:GetSetting("reduceMotion"),motionSetting);T.eq(addon:GetSetting("floatingScale"),floatingScale);T.eq(addon:GetSetting("floatingCompatibility"),compatibility)
 ui:Hide(true);addon:SetSetting("floating",false);_G.RurutiaSuite=nil
end
-- The status entry remains usable before the UI business package is loaded.
local base=dofile("tests/stubs.lua");base.Install({locale="zhCN",realm="Home"})
local stub=dofile("tests/ui_stubs.lua");stub.Install()
_G.LycheeUI=nil
local libraryPrivate={}
for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Styles.lua","Components.lua","Layouts.lua","Responsive.lua","Elements.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",libraryPrivate) end
_G.LycheeGroup=nil;_G.LycheeGroupDB=nil
for _,file in ipairs({"Locale.lua","Theme/Defaults.lua","Theme/Elements.lua","Core.lua","Configuration.lua","Appearance.lua","Theme/Import.lua","Specializations.lua","Fonts.lua","BrandMotion.lua","ActivityLabels.lua","Floating.lua","API.lua"}) do dofile("addon/LycheeGroup/"..file) end
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
-- Only this lazy-construction scope models the native Frame/Texture boundary.
-- Native Frames have neither font-string color methods nor vertex-color methods.
local panelOK,panelError=WithNativeFrameColors(function() F:ShowPanel() end)
T.ok(panelOK,"application row constructs with native Frame color capabilities: "..tostring(panelError))
T.eq(#F.rows,1,"the first hover constructs only the visible application row")
local cancelGlyph=F.rows[1].cancel.elementIcon
T.eq(cancelGlyph:GetObjectType(),"Frame","the public glyph slot retains its original geometry frame")
T.eq(cancelGlyph.GetTextColor,nil);T.eq(cancelGlyph.GetVertexColor,nil,"a glyph frame exposes no native color getter")
T.eq(cancelGlyph:GetWidth(),F.context.Theme.floatingCrossWidth);T.eq(cancelGlyph:GetHeight(),F.context.Theme.floatingCrossHeight)
T.eq((cancelGlyph:GetPoint()),"CENTER","the cancel glyph keeps its original center anchor")
local function CancelGlyphColor(expected)
 local color={cancelGlyph.texture:GetVertexColor()}
 for i=1,4 do T.near(color[i],expected[i] or 1,.000001,"cancel glyph texture uses the current state color") end
end
CancelGlyphColor(F.context.Theme.dim)
F.rows[1].cancel:Fire("OnEnter");CancelGlyphColor(F.context.Theme.brand)
F.rows[1].cancel:Fire("OnLeave");CancelGlyphColor(F.context.Theme.dim)
T.eq(#F.batches,0,"outbound applications need no applicant batch cards")
T.eq(startupNotifications,1,"disposing a subscription before startup prevents later delivery")
local function Position(frame)
 local _,relative,point,x,y=frame:GetPoint();if type(relative)=="number" then return relative,point end;return x,y
end
T.eq(A.UI,nil,"hover does not load the UI addon")
T.eq(F.context.Theme.fontSizeDelta,0,"the floating context does not inherit the main-window font increase")
T.eq(select(2,F.rows[1].name:GetFont()),20);T.eq(select(2,F.rows[1].meta:GetFont()),15,"the dungeon heading is larger than the group title")
T.eq(F.panel.events.GLOBAL_MOUSE_DOWN,true,"the expanded popup observes global clicks without a full-screen input catcher")
local entryButtons=0;for _,child in ipairs({F.frame:GetChildren()}) do if child:GetObjectType()=="Button" then entryButtons=entryButtons+1 end end
T.eq(entryButtons,1,"the collapsed icon and number share one actual button")
T.eq(F.frame:GetWidth(),115);T.eq(F.frame:GetHeight(),44);T.eq(F.panel:GetWidth(),360);T.eq(F.scroll:GetWidth(),348)
T.eq(F.count:GetText(),"申请1个");T.eq(F.rows[1].name:GetText(),"A dungeon");T.eq(F.rows[1].meta:GetText(),"A group");T.eq(F.rows[1].leader:GetText(),"Leader-Away");T.eq(F.rows[1].timer:GetText(),"2:10")
T.eq(F.rows[1].background:IsShown(),true,"each resting application keeps its own card")
T.eq(F.rows[1].faction,nil,"outbound application cards allocate no applicant faction marker")
T.ok(F.panel.background,"application cards share a rounded outer backdrop")
T.ok(F.context.Theme.floatingPanelSurface[4]>0 and F.context.Theme.floatingPanelSurface[4]<1,"the outer backdrop is translucent")
T.same(F.panel.background.fill.color,F.context.Theme.floatingPanelSurface,"the actual outer fill uses the floating theme token")
T.same(F.rows[1].background.fill.color,F.context.Theme.floatingCardSurface,"the actual application fill uses the floating card token")
T.eq(F.heading:GetText(),"我的申请 2/5");T.eq(F.cancel.label:GetText(),"取消全部")
T.eq(select(2,F.rows[1].icon:GetPoint()),F.rows[1].leader,"the leader portrait shares the last information row")
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
T.ok(detailX+applicationRow.score:GetWidth()+8<=348+cancelX-applicationRow.cancel:GetWidth(),"the activity heading leaves a real gap before cancel")
T.ok(Position(applicationRow.leader)+applicationRow.leader:GetWidth()+12<=348-12-applicationRow.timer:GetWidth(),"leader and countdown have independent columns")
do
 local previous=apps[1].leaderName
 apps[1].leaderName=string.rep("LongLeader",8).."-Away";callback("applications")
 local _,leaderTop=Position(applicationRow.leader)
 T.eq(applicationRow.leader.wrap,true,"outbound application leaders retain wrapping after typed-row construction")
 T.ok(applicationRow.leader:GetStringHeight()>applicationRow.leader:GetLineHeight()+applicationRow.leader:GetSpacing(),"long leader identities wrap onto additional lines")
 T.ok(-leaderTop+applicationRow.leader:GetStringHeight()+F.context.Theme.floatingApplicationPaddingY<=applicationRow:GetHeight()+.001,"the complete wrapped leader fits above the card's bottom padding")
 apps[1].leaderName=previous;callback("applications")
end
apps[1].activityLabel=nil;apps[1].activityDetail=nil;callback("applications")
GameTooltip:Hide();F.cancel:Fire("OnEnter");T.eq(F.cancel.hover:IsShown(),false,"the top cancellation action uses text feedback only")
T.eq(GameTooltip:IsShown(),false,"cancel-all does not open a redundant tooltip");F.cancel:Fire("OnLeave");T.eq(F.cancel.hover:IsShown(),false)
apps[1].status="invited";callback("applications")
T.eq(F.panel:IsShown(),true,"the last invitation leaves the already expanded popup in its idle state")
T.eq(F.countdown,nil,"the invitation removes the final waiting countdown")
T.eq(F.panel.events.GLOBAL_MOUSE_DOWN,true,"the open idle popup keeps outside-click observation until it closes")
F:ShowPanel()
T.eq(F.cancel:IsShown(),false,"an empty waiting list hides cancel-all instead of leaving a disabled header")
T.eq(F.panel:GetHeight(),58,"an empty application popup drops the unused header")
T.eq(F.emptyCard:IsShown(),true);T.eq(F.emptyCard:GetHeight(),44)
T.ok(F.emptyCard:GetWidth()<348,"an idle popup uses a compact card instead of a full application row")
T.eq(F.panel:GetWidth(),F.emptyCard:GetWidth()+12);T.eq(F.scroll:GetWidth(),F.emptyCard:GetWidth())
T.eq(F.empty:GetText(),"暂无活动","native invitations do not remain in the waiting list")
T.eq(F.empty.justify,"CENTER","empty text is centered within its complete width")
T.eq(F.empty:GetPoint(),"CENTER");T.eq(select(2,Position(F.emptyCard)),-8,"empty content keeps equal top and bottom padding")
apps[1].status="applied";callback("applications")
T.eq(F.cancel:IsShown(),true);T.eq(F.emptyCard:IsShown(),false)
T.eq(select(2,Position(F.scroll)),-38,"restored applications regain the heading and action row")
T.eq(F.rows[1]:GetHeight(),96,"restoring applications keeps both title lines and ten-pixel vertical padding")
local _,headingY=Position(F.rows[1].name);local _,leaderY=Position(F.rows[1].leader)
T.eq(-headingY,10);T.ok(F.rows[1]:GetHeight()+leaderY-F.rows[1].leader:GetStringHeight()>=10,"the caption leader retains the full bottom padding inside its minimum-height line")
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
F.rows[1].cancel:Fire("OnEnter");T.eq(F.rows[1].background:IsShown(),true);T.eq(F.rows[2].background.fill.color[4],.16,"cancel hover leaves the other card unchanged")
T.eq(F.rows[1].background.fill.color[4],F.context.Theme.floatingCardHover[4],"row hover keeps the individual card translucent")
T.same(F.rows[1].background.fill.color,F.context.Theme.floatingCardHover,"the complete hover fill honors the card token")
T.ok(F.rows[1].cancel.hover:IsShown(),"the icon retains its local red feedback");T.eq(GameTooltip:IsShown(),false,"single cancellation also omits a tooltip")
F.rows[1].cancel:Fire("OnLeave");T.eq(F.rows[1].background.fill.color[4],.16);T.eq(F.rows[1].cancel.hover:IsShown(),false)
T.same(F.rows[1].background.fill.color,F.context.Theme.floatingCardSurface,"leaving restores the complete card color")
apps[2].status="applied";for i=3,5 do apps[i]={id=i,name="Another group",status="applied",activityID=1} end
F:ShowPanel();T.eq(F.scroll:GetHeight(),500,"five padded application cards remain fully visible");T.eq(F.rows[1]:GetHeight(),96);T.eq(F.scrollBar:IsShown(),false,"floating wheel scrolling has no visible track");T.eq(F.rows[5]:IsShown(),true)
for i=5,3,-1 do apps[i]=nil end;apps[2].status="invited";F.panel:Hide()
F:ShowPanel()
members[1].factionGroup=1;members[1].raceName="光铸德莱尼";members[2].factionGroup=0;members[2].raceName="赞达拉巨魔"
listing={name="My listing",activityID=1};callback("listing");T.eq(F.count:GetText(),"30人申请","recruitment counts individual people");T.eq(F.scroll:GetHeight(),UIParent:GetHeight()/F.frame:GetScale()-F.frame:GetHeight()-F.context.Theme.floatingHeaderHeight-F.context.Theme.floatingPanelBottomInset-F.context.Theme.floatingScreenInset)
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
T.eq(F.rows[1].name:GetText(),"Player1-Away","recruitment preserves the complete player identity");T.eq(F.rows[1].meta:GetText(),"光铸德莱尼 · Specialization");T.eq(F.rows[1].score:GetText(),"2001")
T.eq(F.rows[1].itemLevel:GetText(),"装等 501","native item level has its own right-aligned heading column")
T.eq(F.rows[2].name:GetText(),"Player2-Away");T.eq(F.rows[2].score:GetText(),"2002");T.eq(F.rows[2].itemLevel:GetText(),"装等 502","each member of the same batch keeps their own metrics")
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
 T.eq(row.name:GetWidth(),166,"the name leaves independent score and item-level columns")
 T.ok(F.entries[1].height>=8+row.name:GetStringHeight()+2+row.meta:GetStringHeight(),"wrapped race and specialization text fits the measured row")
 T.ok(x+faction:GetWidth()+12<=348-12-row.score:GetWidth(),"identity and faction retain the metric-column gap")
 T.eq(F.rows[3].faction:IsShown(),false);T.eq(F.rows[3].faction:GetTexture(),nil,"unknown members do not inherit another member's faction")
 members[1].factionGroup=0;callback("applicants")
 T.eq(row.faction,faction,"member refreshes reuse the same marker");T.eq(faction:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\faction-horde.tga")
 members[1].factionGroup=nil;members[1].raceName=nil;callback("applicants")
 T.eq(faction:IsShown(),false);T.eq(faction:GetTexture(),nil,"losing known faction clears the old texture")
 T.eq(row.name:GetWidth(),166,"unknown faction preserves the metric columns")
 T.eq(row.meta:GetText(),"— · Specialization","unknown race clears the previous race name")
 members[1].factionGroup=1;callback("applicants")
 T.eq(A.UI,nil,"faction textures do not load the UI addon")
end
T.eq(F.rows[1].batch,F.rows[2].batch,"member rows belong to one continuous batch hover area")
F.rows[1]:Fire("OnEnter");T.eq(F.rows[1].batch.background:IsShown(),true);T.eq(F.rows[1].background,nil,"members allocate no separate hover surface")
T.eq(F.rows[1].batch.line,nil,"a party card has no grouping line");T.eq(F.rows[1].batch.background.fill.color[4],F.context.Theme.floatingCardHover[4],"hover highlights the complete application card")
T.same(F.rows[1].batch.background.fill.color,F.context.Theme.floatingCardHover,"batch hover honors the same floating card token")
F.rows[1]:Fire("OnLeave");T.eq(F.rows[1].batch.background.fill.color[4],.16,"leaving the batch restores its resting card")
T.same(F.rows[1].batch.background.fill.color,F.context.Theme.floatingCardSurface,"batch leave restores the same floating card token")
F.scroll:SetVerticalScroll(F.entryTops[30]);F:Render()
T.eq(F.rows[1].faction:IsShown(),false);T.eq(F.rows[1].faction:GetTexture(),nil,"a row rebound to an unknown member clears the previous faction")
local lastMember;for _,row in ipairs(F.rows) do if row:IsShown() and row.name:GetText()=="Player30-Away" then lastMember=row end end
T.ok(lastMember,"complete applicant roster stays scrollable after list text grows")
lastMember:Fire("OnClick");T.eq(A.openedPage,"create");T.eq(A.openedContext.applicantID,77)
F.scroll:SetVerticalScroll(F.body:GetHeight()-F.scroll:GetHeight());F:Render()
local actionRow,commentRow;for _,row in ipairs(F.rows) do if row.kind=="footer" and row.invite:IsVisible() then actionRow=row end;if row.name:GetText()==applicant.comment then commentRow=row end end
T.ok(actionRow,"the shared footer keeps one action pair");T.eq(commentRow,actionRow,"the shared comment and the one action pair occupy a single footer")
T.eq(commentRow.faction,nil,"a shared footer allocates no applicant marker")
T.ok(Position(commentRow.name)+commentRow.name:GetWidth()+8<=Position(actionRow.invite),"the comment leaves an eight-pixel gap before the invite hit area")
T.eq(F.rows[1].invite,nil,"member rows allocate no duplicate footer actions")
T.eq(Position(commentRow.name),Position(F.rows[1].name),"the shared note aligns with the member text column")
T.ok(actionRow:GetHeight()>=40,"the footer keeps room for the note and action padding")
local actionX,actionY=Position(actionRow.invite);T.eq(select(2,actionRow.invite:GetPoint()),actionRow);T.eq(actionRow:GetWidth()-actionX-actionRow.invite:GetWidth(),48);T.eq(actionRow:GetHeight()+actionY-actionRow.invite:GetHeight(),6,"the invite hit area clears the card bottom")
local declineX,declineY=Position(actionRow.decline);T.eq(select(2,actionRow.decline:GetPoint()),actionRow);T.eq(actionRow:GetWidth()-declineX-actionRow.decline:GetWidth(),12);T.eq(actionRow:GetHeight()+declineY-actionRow.decline:GetHeight(),6,"the decline hit area shares the same bottom inset")
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
F:Tick(.08);T.eq(#F.entries,0,"finishing the last batch exit leaves no applicant bindings in the displayed empty state")
T.eq(exitingMember.applicantID,nil);T.eq(exitingMember.batch,nil,"the retired member row releases its batch binding")
T.eq(F.panel:IsShown(),true,"the last applicant leaves the open listing in its waiting state")
T.eq(F.empty:GetText(),"等待玩家申请");T.ok(F.waitIcon:IsShown())
T.eq(F.panel:GetScript("OnUpdate"),nil,"the exit leaves no persistent driver")
applicant.acting=nil;applicant.pendingStatus="invited";callback("applicants");T.eq(#F.entries,0,"native pending status remains absent from the waiting list")
applicant.pendingStatus=nil;callback("applicants");F:Tick(.2)
T.eq(F.panel:IsShown(),true,"the still-open popup updates when applicants become operable again")
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
local inviteBeforeConfirm=G.Invite;local printed=0
G.Invite=function() return nil,nil end
A.Print=function() printed=printed+1 end
actionRow.invite:Fire("OnClick")
T.eq(printed,0,"opening a conversion confirmation is not reported as an action error")
T.eq(actionRow.exit,nil,"an unconfirmed invitation keeps the applicant visible")
T.eq(#F.entries,2);T.eq(actionRow.invite:IsEnabled(),true)
G.Invite=inviteBeforeConfirm
A.Print=printMessage;G.failDecline=nil
actionRow.decline:Fire("OnClick");T.eq(G.declined,77,"decline also submits in the click callback");F:Tick(.15);T.eq(F.panel:IsShown(),true);T.eq(#F.entries,0)
applicant.acting=nil;callback("applicants");F:ShowPanel();F:SetOffset(0,false)
batchEntry=F.entries[1].batch;commentRow=F.rows[2]
T.eq(#F.entries,2,"a smaller roster drops old member containers instead of retaining the past roster size")
T.eq(F.entries[1].batch,batchEntry,"current batch metadata is reused while its members change")
T.eq(F.rows[1].batch.line,nil,"a solo application uses the same borderless card")
T.eq(F.rows[1].batch.background:IsShown(),true,"a resting applicant batch retains one shared card")
T.eq(F.rows[1].batch.background.fill.color[4],.16,"the resting batch shares the lighter translucent background")
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
T.eq(select(2,Position(metricRow.itemLevel)),select(2,Position(metricRow.name)),"PvP item level shares the member heading")
T.eq(select(2,metricRow.itemLevel:GetFont()),14)
T.eq(F.rows[1].score:GetText(),"1820","floating uses the listing's normalized PvP rating instead of its dungeon score")
T.same(F.rows[1].score.color,F.context.Theme.text,"PvP rating uses neutral text")
members[1].rating=0;callback("applicants");T.eq(F.rows[1].score:GetText(),"暂无","known zero is distinct from missing PvP data")
members[1].rating=nil;callback("applicants");T.eq(F.rows[1].score:GetText(),"未知分数","missing PvP rating does not fall back to a dungeon score")
T.eq(rarityCalls,0,"PvP does not request dungeon score rarity colors")
listing.activityID=2;callback("listing");T.eq(metricRow.score:IsShown(),false,"returning from PvP to raid hides the reused score again")
listing.activityID=1;members[1].ratingKind="dungeon";members[1].rating=members[1].dungeonScore;callback("listing")
T.eq(F.rows[1],metricRow);T.eq(metricRow.score:IsShown(),true);T.eq(select(2,Position(metricRow.itemLevel)),select(2,Position(metricRow.name)),"dungeon row reuse keeps item level beside its own name")
T.eq(F.rows[1].score:GetText(),"2001");T.eq(rarityCalls,1,"dungeon ratings keep their rarity colors")
C_ChallengeMode.GetDungeonScoreRarityColor=rarity
T.eq(select(2,F.rows[1].name:GetFont()),16,"floating applicant names use the compact 16/22 typography")
T.eq(select(2,F.rows[1].score:GetFont()),14)
T.eq(select(2,F.rows[1].meta:GetFont()),12);T.eq(select(2,F.rows[1].itemLevel:GetFont()),14)
T.eq(F.rows[1].leader,nil);T.eq(F.rows[1].timer,nil,"member rows allocate no application leader or countdown text")
T.eq(select(2,commentRow.name:GetFont()),14,"shared comments use the readable footer typography")
T.ok(Position(F.rows[1].name)+F.rows[1].name:GetWidth()+6<=F.rows[1]:GetWidth()+Position(F.rows[1].score)-F.rows[1].score:GetWidth(),"the name leaves a separate score column")
T.eq(F.rows[1].icon:GetWidth(),32,"the applicant avatar spans the name and specialization block")
local iconX,iconY=Position(F.rows[1].icon)
local nameX,nameY=Position(F.rows[1].name)
local metaX,metaY=Position(F.rows[1].meta)
T.eq(iconX,12);T.eq(nameX,50);T.eq(metaX,72)
T.eq(iconY,-8,"the avatar has an eight-pixel inset from the card top")
T.eq(nameY,-8,"the player name aligns with the avatar")
local scorePoint=select(1,F.rows[1].score:GetPoint());local scoreX,scoreY=Position(F.rows[1].score)
T.eq(scorePoint,"TOPRIGHT");T.eq(scoreX,-82,"the score leaves a separate item-level column and gap");T.eq(scoreY,-8,"the score aligns with the padded member heading")
T.eq(select(2,F.count:GetFont()),16,"the collapsed indicator count retains its size")
T.eq(select(2,F.cancel.label:GetFont()),14,"the top action uses the readable control size")
T.eq(A.UI,nil,"PvP rendering still leaves the UI addon unloaded")
local originalKey=members[1].nameKey;members[1].nameKey="A-very-long-player-identity-from-another-realm";callback("applicants")
local _,nameY=Position(F.rows[1].name);local _,scoreY=Position(F.rows[1].score);local _,metaY=Position(F.rows[1].meta);local _,itemY=Position(F.rows[1].itemLevel)
T.ok(F.entries[1].nameHeight>22,"long identities still expand the complete member row")
T.eq(nameY,scoreY,"rating follows the name's first baseline even after wrapping")
T.eq(nameY,itemY,"item level keeps the name's first baseline after the identity wraps")
local _,wrappedIconY=Position(F.rows[1].icon)
T.eq(wrappedIconY,nameY,"a wrapped identity keeps the avatar aligned with the first name line")
local factionX,factionY=Position(F.rows[1].faction)
T.eq(factionY,metaY,"a wrapped name keeps faction beside the race below the complete identity")
T.eq(factionX,50,"long identities preserve the metadata inset")
members[1].nameKey=originalKey;callback("applicants")
local comment=applicant.comment
applicant.comment="熟练";callback("applicants");T.eq(F.body:GetHeight(),F.entries[1].height+40,"the card fits the full identity and race metadata plus its compact note footer")
local commentTop=select(2,Position(F.rows[2].name))
T.ok(-commentTop>=6,"a single-line note retains its top padding")
local _,noteActionY=Position(F.rows[2].invite)
T.eq(-commentTop+F.rows[2].name:GetHeight()/2,F.rows[2]:GetHeight()+noteActionY-F.rows[2].invite:GetHeight()/2,"a single-line note and action controls share a centerline")
local shortHeight=F.body:GetHeight()
applicant.comment=nil;callback("applicants");T.eq(#F.entries,2,"a batch without a note has no empty note row");T.eq(F.body:GetHeight(),shortHeight,"an empty note and one short line use the same compact footer")
applicant.comment=string.rep("A long shared note ",12);callback("applicants")
T.ok(F.body:GetHeight()>shortHeight,"a long shared note expands instead of truncating its content")
T.eq(select(2,Position(F.rows[2].name)),-6,"a multi-line note keeps its top inset as it grows")
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
T.eq(F.panel:GetScript("OnUpdate"),nil,"closing stops an active batch exit")
F.panel.mouseOver=true;base.AdvanceClock(.2);F:Tick(.5);callback("applicants")
T.eq(F.panel:IsShown(),false,"a cancelled hide timer, completed exit and native refresh cannot reopen the popup")
F.panel.mouseOver=false
F:ShowPanel();T.eq(#F.entries,0,"reopening never revives an acting applicant");T.eq(F.count:GetText(),"招募中","the collapsed count uses the same operable filter as the list")
T.eq(F.emptyCard:IsShown(),true);T.eq(F.emptyCard:GetHeight(),44)
T.eq(F.cancel:IsShown(),true,"the owner can still end an empty listing")
T.eq(F.panel:GetHeight(),88,"the empty recruitment view reserves its listing heading and waiting content")
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
  for _=1,15 do if F.panel:GetScript("OnUpdate") then F.panel:Fire("OnUpdate",.01) end end
 end
 F.Render=render
 T.eq(renders,0,"wheel input at the upper boundary does not render motion with no displacement")
 T.eq(F.scroll:GetVerticalScroll(),0);T.eq(F.panel:GetScript("OnUpdate"),nil)
end
F:SetOffset(11,true);T.ok(F.scrollTween);local scrollState=F.scrollTween;F:Tick(.03);T.ok(F.scroll:GetVerticalScroll()>0 and F.scroll:GetVerticalScroll()<11,"a real scroll retains its intermediate position");F:SetOffset(22,true);T.eq(F.scrollTween,scrollState,"a new scroll target reuses the finite tween state");F:Tick(.2);T.eq(F.scroll:GetVerticalScroll(),22);T.eq(F.scrollTween,nil,"completed scrolling removes its tween");F:SetOffset(0,true);F:Tick(.2);T.eq(F.scroll:GetVerticalScroll(),0)
F:Fade(false);T.ok(F.fade);T.eq(F.fade,fadeState,"fade direction changes reuse the finite fade state");F:Tick(.2);T.eq(F.panel:IsShown(),false);T.ok(F.attention and F.attentionTimer,"closing only the popup preserves the pending-applicant reminder")
T.eq(F.panel:GetScript("OnUpdate"),nil,"collapsed attention does not keep the panel driver running")
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
T.eq(F.panel:IsShown(),true);T.eq(F.panel:GetScript("OnUpdate"),nil,"reduced motion finishes the last batch exit immediately");T.eq(#F.entries,0)
applicant.acting=nil;callback("applicants");F:ShowPanel();T.eq(#F.entries,2)
F.rows[2].decline:Fire("OnClick");T.eq(#F.entries,0,"reduced motion removes the last accepted batch without a display task");T.eq(F.panel:GetScript("OnUpdate"),nil)
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
 local visible=F.visibleLast-F.visibleFirst+1
 local searchBound=math.ceil(math.log(#F.entries)/math.log(2))+visible+3
 T.ok(reads<=searchBound,"visible-range lookup remains bounded by binary search plus the visible rows: "..reads.."/"..searchBound)
 T.ok(reads<#F.entries,"a stable scroll frame does not scan the complete applicant list")
 F.entryTops=tops;F:Dismiss()
 applicant.members=originalMembers;callback("applicants");T.eq(F.frame:GetWidth(),115)
end
A:SetSetting("reduceMotion",false)
T.ok(F.attention and F.brandMotion:IsPlaying(),"restoring motion starts the actual product Brand job")
T.eq(F.panel:GetScript("OnUpdate"),nil,"the collapsed reminder does not install the panel driver")
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
T.eq(F.panel:GetScript("OnUpdate"),nil);T.eq(base.PendingTimers(),1,"only one cancellable replay timer owns the quiet interval")
F:ShowPanel()
do
 local clock=GetTimePreciseSec;local reads=0
 _G.GetTimePreciseSec=function() reads=reads+1;return clock() end
 for i=1,24 do stub.preciseNow=i*.01;F.panel:Fire("OnUpdate",.01) end
 T.eq(reads,1,"floating reads the native clock only for the first frame of a busy interval")
 T.eq(F.panel:GetScript("OnUpdate"),nil,"floating stops its driver after its entrance finishes")
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
T.eq(F.panel:GetScript("OnUpdate"),nil,"reduced motion stops and settles the collapsed reminder")
A:SetSetting("reduceMotion",false);F.context.Motion:Tick(.1)
local visibleAttention
local stopAttention=API:Subscribe(function(status) visibleAttention=status.attention end)
T.eq(visibleAttention,true)
F.frame:Hide()
T.eq(visibleAttention,false,"hiding the entry publishes the stopped attention state to API subscribers")
stopAttention()
T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(F.logoTexture:GetWidth(),38);T.eq(F.brandMotion:IsPlaying(),false,"hiding the entire entry cancels Brand and the replay timer")
F.frame:Show();T.ok(F.attention,"showing the entry derives attention again from the pending snapshot")
listing=nil;callback("listing");T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(F.logoTexture:GetWidth(),38);T.eq(F.panel:GetScript("OnUpdate"),nil,"ending recruitment stops attention even if outbound applications remain")
listing={name="My listing",activityID=1};callback("listing");T.ok(F.attention)
applicant.pendingStatus="invited";callback("applicants");T.eq(F.attention,false,"only operable applied applicants trigger attention")
applicant.pendingStatus=nil;callback("applicants");T.ok(F.attention)
applicant.status="declined";callback("applicants");T.eq(F.attention,false);T.eq(F.attentionTimer,nil);T.eq(select(2,Position(F.logoTexture)),0,"clearing the final pending applicant restores the original logo anchor")
A:SetSetting("floating",false);T.eq(F.frame:IsShown(),false);T.eq(F.entries,nil,"disabled floating releases its list");T.eq(F.panel:GetScript("OnUpdate"),nil)
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
T.eq(F.count:GetText(),"荔枝组队","an invitation is handled by native UI and leaves no waiting application")
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
 local resubscribeCalls=0
 local function Resubscribed() resubscribeCalls=resubscribeCalls+1 end
 local baseline=F.backgroundStatusSubscribers or 0
 local oldStop=API:Subscribe(Resubscribed,{background=true})
 T.eq(F.backgroundStatusSubscribers,baseline+1)
 oldStop();T.eq(F.backgroundStatusSubscribers,baseline)
 local newStop=API:Subscribe(Resubscribed,{background=true})
 oldStop();oldStop()
 T.eq(F.backgroundStatusSubscribers,baseline+1,"a retired cancellation cannot remove a later background subscription")
 local beforeResubscribe=resubscribeCalls
 A:SetSetting("floatingCompatibility",false)
 T.eq(resubscribeCalls,beforeResubscribe+1,"the new subscription still receives status changes")
 local newestStop=API:Subscribe(Resubscribed,{background=true})
 newStop();T.eq(F.backgroundStatusSubscribers,baseline+1,"re-registering the same callback replaces its cancellation handle")
 newestStop();newestStop();T.eq(F.backgroundStatusSubscribers,baseline,"repeated cancellation removes exactly one background demand")
 A:SetSetting("floatingCompatibility",true)
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

 -- A release callback can also remount its own owner. The outer host change
 -- must not overwrite the newer mount or replace its cleanup callback.
 local host3=CreateFrame("Button",nil,UIParent);host3:SetSize(120,24)
 local label2=host2:CreateFontString(nil,"OVERLAY")
 local nestedReleased,outerReleased,initialReleased=0,0,0
 local function NestedRelease() nestedReleased=nestedReleased+1 end
 local function OuterRelease() outerReleased=outerReleased+1 end
 local function RemountSameOwner(target)
  return function()
   initialReleased=initialReleased+1
   T.eq(API:Attach(owner,target,28,label,NestedRelease),true)
  end
 end
 T.eq(API:Attach(owner,host,24,label,RemountSameOwner(host3)),true)
 ok,reason=API:Attach(owner,host2,24,label,OuterRelease)
 T.eq(ok,false,"a newer mount by the same owner keeps its host")
 T.eq(reason,"occupied");T.eq(F.host,host3)
 T.eq(initialReleased,1);T.eq(nestedReleased,0);T.eq(outerReleased,0)
 T.eq(API:Refresh(owner,30),true);T.eq(F.host,host3)
 T.eq(API:Detach(owner),true);T.eq(nestedReleased,1)
 T.eq(API:Detach(owner),false);T.eq(nestedReleased,1,"the nested release runs exactly once")
 T.eq(outerReleased,0,"a rejected outer mount never owns a release callback")

 T.eq(API:Attach(owner,host,24,label,RemountSameOwner(host2)),true)
 ok,reason=API:Attach(owner,host2,24,label,OuterRelease)
 T.eq(ok,true,"a release callback that already mounted the requested target satisfies Attach")
 T.eq(reason,nil);T.eq(F.host,host2)
 T.eq(F.logoAnchor:GetWidth(),24,"an already satisfied attach still applies the requested logo size")
 T.eq(API:Detach(owner),true);T.eq(nestedReleased,2)
 T.eq(outerReleased,0,"an already satisfied outer attach retains the nested release callback")

 T.eq(API:Attach(owner,host,24,label,function()
  API:Attach(owner,host2,28,label2,NestedRelease)
 end),true)
 ok,reason=API:Attach(owner,host2,24,label,OuterRelease)
 T.eq(ok,false,"a newer label on the requested host remains a different mount")
 T.eq(reason,"occupied");T.eq(F.host,host2);T.eq(F.count,label2)
 T.eq(API:Detach(owner),true);T.eq(nestedReleased,3)

 T.eq(API:Attach(owner,host,24,label,function()
  T.eq(API:Attach(owner,host3,28,label,NestedRelease),true)
  T.eq(API:Detach(owner),true)
 end),true)
 T.eq(API:Attach(owner,host2,24,label,OuterRelease),true,"a nested mount that was released leaves the slot available")
 T.eq(F.host,host2);T.eq(nestedReleased,4)
 T.eq(API:Detach(owner),true);T.eq(outerReleased,1)

 local normalReleased=0
 local function NormalRelease() normalReleased=normalReleased+1 end
 T.eq(API:Attach(owner,host,24,label,NormalRelease),true)
 T.eq(API:Attach(owner,host,28,label,NormalRelease),true,"same-target Attach remains idempotent")
 T.eq(normalReleased,0);T.eq(F.host,host)
 T.eq(API:Attach(owner,host2,24,label,NormalRelease),true,"a normal host change still succeeds")
 T.eq(normalReleased,1);T.eq(F.host,host2)
 T.eq(API:Attach(owner,host2,24,label2,NormalRelease),true,"a normal label change still succeeds")
 T.eq(normalReleased,2);T.eq(F.count,label2)
 T.eq(API:Detach(owner),true);T.eq(normalReleased,3)

 releaseMode="disable"
 T.eq(API:Attach(owner,host,24,label,ReentrantRelease),true)
 ok,reason=API:Attach(owner,host2,24,label,function() end)
 T.eq(ok,false,"a release callback that disables compatibility blocks the outer attach")
 T.eq(reason,"unavailable");T.eq(F.host,nil)
 A:SetSetting("floatingCompatibility",true)

 local disabledReleased,disabledAttached,disabledReason=0
 T.eq(API:Attach(owner,host,24,label,function()
  disabledReleased=disabledReleased+1
  disabledAttached,disabledReason=API:Attach(owner,host3,24,label,NestedRelease)
 end),true)
 A:SetSetting("floatingCompatibility",false)
 T.eq(disabledReleased,1);T.eq(F.host,nil)
 T.eq(disabledAttached,false,"a release callback cannot remount while compatibility is disabled")
 T.eq(disabledReason,"unavailable")
 T.eq(API:Detach(owner),false,"the failed disabled remount leaves no owner")
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
 for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Styles.lua","Components.lua","Layouts.lua","Responsive.lua","Elements.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",private) end
 for _,file in ipairs({"Locale.lua","Theme/Defaults.lua","Theme/Elements.lua","Core.lua","Configuration.lua","Appearance.lua","Theme/Import.lua","Specializations.lua","Fonts.lua","BrandMotion.lua","ActivityLabels.lua","Floating.lua","API.lua","Presentation.lua"}) do dofile("addon/LycheeGroup/"..file) end
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
 local waitingText=locale=="zhCN" and "等待玩家申请" or "Waiting for applicants"
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
   T.ok(card:IsShown())
   if floating.heading:IsShown() then T.eq(card:GetWidth(),348,"an empty listing keeps its full-width heading and waiting state")else T.ok(card:GetWidth()<348,"short idle content remains compact")end
   T.ok(card:GetWidth()-floating.empty:GetUnboundedStringWidth()>=32,"the complete empty label retains its horizontal padding")
   T.eq(floating.panel:GetWidth(),card:GetWidth()+12);T.eq(floating.scroll:GetWidth(),card:GetWidth())
   T.eq(floating.panel:GetHeight(),height);T.eq(floating.scroll:GetHeight(),44)
   T.eq(floating.body:GetWidth(),348,"empty viewport resizing leaves the content canvas width stable")
   T.eq(select(2,floating.panel:GetPoint()),floating:GetAnchor())
   T.near(floating.panel:GetEffectiveScale(),addon.db.floatingScale/100,.001)
  end
  applications={};activeListing=nil;notify("applications")
  Empty(idleText,58);T.eq(floating.count:GetText(),brand,"the folded idle entry retains the product name")
  applications={{id=1,status="invited"}};notify("applications")
  Empty(idleText,58);T.eq(floating.count:GetText(),brand,"native invitations do not keep a pending application status")
  activeListing={activityID=1};notify("listing")
  Empty(waitingText,88);T.ok(floating.cancel:IsShown(),"an empty listing retains its end-listing action")
  T.ok(floating.panel:GetWidth()>=floating.cancel:GetWidth()+48,"a compact recruitment header still fits its complete action")
  activeListing=nil;applications={{id=1,status="applied",name="Group",activityName="Dungeon",leaderName="Leader-Away"}};notify("listing")
  T.eq(floating.panel:GetWidth(),360);T.eq(floating.scroll:GetWidth(),348)
  T.eq(floating.emptyCard:IsShown(),false);T.eq(floating.rows[1]:GetWidth(),348,"real application rows recover their full width")
  applications={};notify("applications")
  T.eq(floating.panel:IsShown(),true,"the last waiting application leaves an expanded idle popup")
  T.eq(floating.countdown,nil);T.eq(floating.panel.events.GLOBAL_MOUSE_DOWN,true,"the idle popup remains closable until it actually hides")
  Empty(idleText,58)
  local measure=floating.empty.GetUnboundedStringWidth
  floating.empty.GetUnboundedStringWidth=function() return 323.7 end
  floating:LayoutPanel()
  T.ok(card:GetWidth()>=323.7+32,"wider font metrics can expand an empty card without clipping")
  T.eq(floating.rows[1]:GetWidth(),348,"a widened empty viewport never resizes the fixed row pool")
  T.eq(floating.body:GetWidth(),348)
  floating.empty.GetUnboundedStringWidth=measure;floating:LayoutPanel()
  T.ok(card:GetWidth()<348,"restoring short text metrics returns to the compact width")
  if integrated then
   host.GetTop=function() return 1200 end;host.GetLeft=function() return 1700 end
   host:SetSize(110,24);host:SetScale(.9);api:Refresh(owner)
   T.eq(floating.panel:GetPoint(),"TOPRIGHT","a resized host retains the popup's screen-edge anchoring")
   T.eq(card:GetWidth(),floating.scroll:GetWidth());T.eq(floating.rows[1]:GetWidth(),348)
   T.near(floating.panel:GetEffectiveScale(),addon.db.floatingScale/100,.001)
   api:Detach(owner)
  else floating:Dismiss() end
 end
 addon:SetSetting("floating",false)
 T.eq(clock.PendingTimers(),0)
end
-- Fixed startup rules preserve Glyph Frame geometry and texture-backed color.
do
 local color={.17,.38,.61,1}
 local theme={schema=1,id="floating.native-texture",revision=1,appearance={floating={elements={
  ["floating.application"]={base={["cancel/elementIcon"]={color=color,width=19,height=15,points={{"CENTER","$parent","CENTER",3,-2}}}}},
 }}}}
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true},theme)
 local a,g=f.A,f.G
 g.apps={{id=18,status="applied",name="Group",activityName="Dungeon",leaderName="Leader-Away"}}
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 local floating=a.Floating;floating:Bind(g)
 local ok,err=WithNativeFrameColors(function() floating:UpdateSettings();floating:ShowPanel() end)
 T.ok(ok,"startup cancel texture rules use native Texture color methods: "..tostring(err))
 local glyph=floating.rows[1].cancel.elementIcon
 T.eq(glyph:GetObjectType(),"Frame","the public icon slot retains the glyph geometry frame")
 T.eq(glyph.GetTextColor,nil);T.eq(glyph.GetVertexColor,nil,"the glyph has no native color getter")
 T.eq(glyph:GetWidth(),19);T.eq(glyph:GetHeight(),15)
 local point,relative,relativePoint,x,y=glyph:GetPoint()
 T.eq(point,"CENTER");T.eq(relative,glyph:GetParent(),"$parent still means the cancel button");T.eq(relativePoint,"CENTER");T.eq(x,3);T.eq(y,-2)
 local texture=glyph.texture
 for _,event in ipairs({"OnLeave","OnEnter","OnLeave"}) do
  floating.rows[1].cancel:Fire(event)
  local actual={texture:GetVertexColor()};for i=1,4 do T.near(actual[i],color[i],.000001,"startup element color retains ownership during hover") end
 end
 floating:Dismiss();a:SetSetting("floating",false)
end
-- Token overrides must survive the legacy Surface recipe and both hover paths.
do
 local colors={floatingPanelSurface={.13,.21,.31,.47},floatingCardSurface={.32,.24,.16,.29},floatingCardHover={.41,.35,.27,.39}}
 local theme={schema=1,id="floating.surface.tokens",revision=1,appearance={floating={tokens=colors}}}
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true},theme)
 local a,g=f.A,f.G
 RAID_CLASS_COLORS={WARRIOR={r=.8,g=.6,b=.4},MAGE={r=.2,g=.6,b=.9}}
 g.apps={{id=1,status="applied",activityName="Dungeon",name="Group",leaderName="Leader-Away"}}
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 local floating=a.Floating;floating:Bind(g);floating:UpdateSettings();floating:ShowPanel()
 T.same(floating.panel.background.fill.color,colors.floatingPanelSurface,"the outer panel paints a configured floating token")
 T.same(floating.rows[1].background.fill.color,colors.floatingCardSurface)
 floating.rows[1]:Fire("OnEnter");T.same(floating.rows[1].background.fill.color,colors.floatingCardHover)
 floating.rows[1]:Fire("OnLeave");T.same(floating.rows[1].background.fill.color,colors.floatingCardSurface)
 g.listing={activityID=2,name="My listing"}
 g.applicants={[7]={id=7,status="applied",members={
  {name="Alpha-Away",nameKey="Alpha-Away",class="WARRIOR",raceName="Human",specName="Arms",dungeonScore=3001,itemLevel=641},
  {name="Beta-Away",nameKey="Beta-Away",class="MAGE",raceName="Gnome",specName="Fire",dungeonScore=2802,itemLevel=632},
 }}}
 g:Notify("listing");g:Notify("applicants")
 T.eq(floating.panel:GetWidth(),360);T.eq(floating.body:GetWidth(),348)
 T.eq(floating.heading:GetText(),"Dungeon · Difficulty 8","the listing heading includes its native activity and difficulty")
 local first,second=floating.rows[1],floating.rows[2]
 T.eq(first.name:GetText(),"Alpha-Away");T.eq(first.score:GetText(),"3001");T.eq(first.itemLevel:GetText(),"ilvl 641")
 T.eq(second.name:GetText(),"Beta-Away");T.eq(second.score:GetText(),"2802");T.eq(second.itemLevel:GetText(),"ilvl 632")
 T.eq(first.meta:GetText(),"Human · Arms");T.eq(second.meta:GetText(),"Gnome · Fire")
 T.eq(first.batch,second.batch)
 T.same(first.batch.background.fill.color,colors.floatingCardSurface)
 first:Fire("OnEnter");T.same(first.batch.background.fill.color,colors.floatingCardHover)
 first:Fire("OnLeave");T.same(first.batch.background.fill.color,colors.floatingCardSurface)
 T.same(floating.panel.background.fill.color,colors.floatingPanelSurface,"member hover does not recolor the outer panel")
 local function MetricColumns(row)
  local width=row:GetWidth();local gap=floating.context.Theme.floatingMemberMetricGap
  local scoreLeft=width+Position(row.score)-row.score:GetWidth()
  local itemLeft=width+Position(row.itemLevel)-row.itemLevel:GetWidth()
  T.ok(row.name:GetWidth()>0 and Position(row.name)+row.name:GetWidth()+gap<=scoreLeft+.001,"the full identity width leaves room before its score")
  T.ok(scoreLeft+row.score:GetWidth()+gap<=itemLeft+.001,"score and item level retain separate columns")
  T.eq(select(2,Position(row.name)),select(2,Position(row.score)))
  T.eq(select(2,Position(row.name)),select(2,Position(row.itemLevel)),"name and both metrics share their heading baseline")
 end
 for _,percent in ipairs({70,100,130})do
  a:SetSetting("fontScale",percent)
  for _,row in ipairs({floating.rows[1],floating.rows[2]})do
   T.ok(row.score:GetUnboundedStringWidth()<=row.score:GetWidth()+.001,"member score remains complete at "..percent.." percent")
   T.ok(row.itemLevel:GetUnboundedStringWidth()<=row.itemLevel:GetWidth()+.001,("member item level remains on its heading line at %d percent (%.2f/%.2f)"):format(percent,row.itemLevel:GetUnboundedStringWidth(),row.itemLevel:GetWidth()))
   MetricColumns(row)
  end
 end
 for _,case in ipairs({{score=0,text="Unrated"},{text="Unknown"}})do
  g.applicants[7].members[1].dungeonScore=case.score;g:Notify("applicants")
  local row=floating.rows[1]
  T.eq(row.score:GetText(),case.text,"zero and missing scores retain their distinct labels")
  T.ok(row.score:GetUnboundedStringWidth()<=row.score:GetWidth()+.001,"the complete "..case.text.." score label fits its metric column")
  MetricColumns(row)
 end
 floating:Dismiss();a:SetSetting("floating",false)
end
-- Clearing a pooled floating action keeps its earlier press cancelled on reuse.
do
 local function Session(recruiting)
  local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true})
  local a,g=f.A,f.G
  local function Applicant(id) return {id=id,status="applied",displayOrderID=id,members={{name="Member"..id.."-Away",nameKey="Member"..id.."-Away",class="MAGE",assignedRole="DAMAGER",itemLevel=320,dungeonScore=2500}}} end
  local function Application(id) return {id=id,status="applied",name="Group "..id,activityName="Dungeon",activityID=2,leaderName="Leader-Away"} end
  if recruiting then g.listing={activityID=2,name="Current listing"};g.applicants={[1]=Applicant(1),[2]=Applicant(2)}
  else g.apps={Application(1),Application(2)} end
  dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
  local floating=a.Floating;floating:Bind(g);floating:UpdateSettings();floating:ShowPanel()
  return f,floating,Applicant,Application
 end
 local function Row(floating,id,kind)
  for _,row in ipairs(floating.rows) do if row:IsShown() and row.kind==kind and (row.applicantID or row.applicationID)==id then return row end end
  error("missing floating row "..id.."/"..kind)
 end
 for _,method in ipairs({"invite","decline"}) do
  local f,floating,Applicant=Session(true);local g=f.G
  local footer=Row(floating,2,"footer");local button=footer[method]
  button:Fire("OnMouseDown","LeftButton")
  g.applicants[2]=nil;g:Notify("applicants")
  g.applicants[3]=Applicant(3);g:Notify("applicants")
  T.eq(footer.applicantID,3,"the cleared native footer is reused for the next applicant")
  button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
  T.eq(g.invitedApplicant,nil);T.eq(g.declinedApplicant,nil,"release after reuse cannot decide the new applicant")
  button:Fire("OnClick","LeftButton")
  T.eq(method=="invite" and g.invitedApplicant or g.declinedApplicant,3,"direct activation still decides the current applicant")
  T.eq(footer.exit,nil,"reduced motion completes the synchronous decision exit")
  floating:Dismiss();f.A:SetSetting("floating",false)
 end
 for _,action in ipairs({"cancel","row"}) do
  local f,floating,_,Application=Session(false);local g=f.G
  local row=Row(floating,2,"application");local button=action=="row" and row or row.cancel
  local opened;f.A.Open=function(_,page,context) opened={page,context} end
  button:Fire("OnMouseDown","LeftButton")
  table.remove(g.apps,2);g:Notify("applications")
  g.apps[2]=Application(3);g:Notify("applications")
  T.eq(row.applicationID,3)
  button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
  T.eq(g.cancelled,nil);T.eq(opened,nil,"release after reuse cannot open the new application")
  button:Fire("OnMouseDown","LeftButton");button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
  if action=="cancel" then T.eq(g.cancelled,3,"a new press cancels the current application")
  else T.eq(opened[1],"find");T.eq(opened[2].applicationID,3,"a new press opens the current application") end
  floating:Dismiss();f.A:SetSetting("floating",false)
 end
 for _,kind in ipairs({"member","batch"}) do
  local f,floating,Applicant=Session(true);local g=f.G
  local row=Row(floating,2,"member");local button=kind=="batch" and row.batch or row
  local opened;f.A.Open=function(_,page,context) opened={page,context} end
  button:Fire("OnMouseDown","LeftButton")
  g.applicants[2]=nil;g:Notify("applicants")
  g.applicants[3]=Applicant(3);g:Notify("applicants")
  T.eq(button.applicantID,3)
  button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
  T.eq(opened,nil,"release after reuse cannot open the new applicant through "..kind)
  button:Fire("OnClick","LeftButton");T.eq(opened[1],"create");T.eq(opened[2].applicantID,3)
  floating:Dismiss();f.A:SetSetting("floating",false)
 end
 for _,action in ipairs({"invite","decline","cancel","row","member","batch","header"}) do
  local recruiting=action=="invite" or action=="decline" or action=="member" or action=="batch"
  local f,floating=Session(recruiting);local g=f.G
  local row=Row(floating,2,recruiting and (action=="member" or action=="batch") and "member" or recruiting and "footer" or "application")
  local button=action=="header" and floating.cancel or action=="batch" and row.batch or (action=="row" or action=="member") and row or row[action]
  local opened;f.A.Open=function(_,page,context) opened={page,context} end
  button:Fire("OnMouseDown","LeftButton");floating:Dismiss();floating:ShowPanel()
  button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
  T.eq(g.invitedApplicant,nil);T.eq(g.declinedApplicant,nil);T.eq(g.cancelled,nil);T.eq(opened,nil,"hiding cancels the old "..action.." press even when the same target returns")
  button:Fire("OnMouseDown","LeftButton");g:Notify(recruiting and "applicants" or "applications")
  button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
  if action=="invite" then T.eq(g.invitedApplicant,2)
  elseif action=="decline" then T.eq(g.declinedApplicant,2)
  elseif action=="cancel" or action=="header" then T.eq(g.cancelled,2)
  elseif recruiting then T.eq(opened[1],"create");T.eq(opened[2].applicantID,2)
  else T.eq(opened[1],"find");T.eq(opened[2].applicationID,2) end
  floating:Dismiss();f.A:SetSetting("floating",false)
 end
 do
  local f,floating=Session(false);local g=f.G
  floating.cancel:Fire("OnMouseDown","LeftButton")
  g.listing={activityID=2,name="New recruitment"};g:Notify("listing")
  floating.cancel:Fire("OnMouseUp","LeftButton");floating.cancel:Fire("OnClick","LeftButton")
  T.ok(g.listing,"a Cancel all press cannot become an End listing action after a mode change")
  floating.cancel:Fire("OnClick","LeftButton");T.eq(g.listing,nil,"direct activation still ends the current listing")
  floating:Dismiss();f.A:SetSetting("floating",false)
 end
end

_G.LycheeGroup=nil;_G.LycheeGroupDB=nil
