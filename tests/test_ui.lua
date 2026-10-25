-- Offline interaction coverage for the approved v4.4 layout and native field leasing.
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G,S,Pick=f.A,f.U,f.G,f.S,f.Pick
do
 local original=GetSpecializationInfoByID
 local calls,ready=0,false
 GetSpecializationInfoByID=function(id)
  calls=calls+1
  if id==900002 and not ready then return end
  return id,"Cached spec "..id,nil,1000000+id
 end
 local icon=U.C.GameIcon(UIParent,24)
 local member={specID=900001,class="WARRIOR"}
 for _=1,40 do
  U:SetMemberIcon(icon,member)
  T.eq(U:SpecName(member),"Cached spec 900001")
 end
 T.eq(calls,1,"forty icon/name bindings share one successful specialization lookup")
 T.eq(icon:GetTexture(),1900001)
 member.specName="Explicit specialization"
 T.eq(U:SpecName(member),member.specName,"provider specialization names keep precedence")
 U:SetMemberIcon(icon,member);T.eq(icon:GetTexture(),1900001,"a valid native ID keeps icon priority over an explicit display name")
 T.eq(A.Specializations:Get(900001),"Cached spec 900001","UI metadata is shared with lightweight core consumers")
 T.eq(calls,1)
 member.specName=nil;member.specID=900002
 T.eq(U:SpecName(member),nil,"unavailable specialization metadata stays absent")
 U:SetMemberIcon(icon,member)
 T.eq(calls,3,"missing metadata is retried rather than cached")
 ready=true
 T.eq(U:SpecName(member),"Cached spec 900002")
 U:SetMemberIcon(icon,member)
 T.eq(calls,4,"recovered metadata is shared with the next icon binding")
 T.eq(icon:GetTexture(),1900002,"changing specialization replaces the previous icon")
 member.specID=900001;U:SetMemberIcon(icon,member)
 T.eq(icon:GetTexture(),1900001,"reusing an earlier specialization restores its own icon")
 T.eq(calls,4)
 A.Specializations:Get(900003)
 U:SetMemberIcon(icon,{specID=900003,class="WARRIOR"})
 T.eq(icon:GetTexture(),1900003);T.eq(calls,5,"metadata first read by a core consumer is reused by UI icons")
 GetSpecializationInfoByID=original
end

-- Delve thumbnails use the native member's UV rectangle, including when it is
-- offset within the shared 2048x2048 entrance sheet, and remain square.
do
 local getAtlas=C_Texture.GetAtlasInfo
 local getJournal=C_EncounterJournal.GetInstanceForGameMap
 local getInstance=EJ_GetInstanceInfo
 local getCategories=G.Catalog.GetCategories
 G.Catalog.GetCategories=function() return {{id=121,icon="delve"},{id=1,icon="flag"},{id=4,icon="pvp"},{id=6,icon="plus"},{id=2,icon="mountain"}} end
 local expected={
  [2933]="delve-entrance-background-collegiate-calamity",[2951]="delve-entrance-background-voidrazor-sanctuary",
  [2953]="delve-entrance-background-parhelion-plaza",[2966]="delve-entrance-background-torments-rise",
  [2952]="delve-entrance-background-the-shadow-enclave",[2961]="delve-entrance-background-twilight-crypts",
  [2962]="delve-entrance-background-atal-aman",[2963]="delve-entrance-background-the-grudge-pit",
  [2964]="delve-entrance-background-gulf-of-memory",[3003]="delve-entrance-background-the-darkway",
  [2965]="delve-entrance-background-sunkiller-sanctum",[2979]="delve-entrance-background-shadowguard-point",
 }
 local requested,journalQueries,atlasReady=nil,0,true
 C_Texture.GetAtlasInfo=function(name)
  requested=name
  if atlasReady then return {file=7291407,width=584,height=384,leftTexCoord=.25,rightTexCoord=.25+584/2048,topTexCoord=.5,bottomTexCoord=.5+384/2048} end
 end
 C_EncounterJournal.GetInstanceForGameMap=function(map) journalQueries=journalQueries+1;if map==99999 or map==3038 then return 12 end end
 EJ_GetInstanceInfo=function() return "Native dungeon",nil,nil,67890,nil,12345 end
 local icon=U.C.GameIcon(UIParent,32)
 for map,atlas in pairs(expected) do U:SetActivityIcon(icon,{mapID=map,categoryID=121});T.eq(requested,atlas) end
 T.eq(icon:GetTexture(),7291407,"Delve thumbnail resolves the native entrance sheet")
 T.near(icon.texCoords[1],.2603125,.000001,"scene crop retains the atlas member's horizontal origin")
 T.near(icon.texCoords[2],.4115625,.000001,"the right-hand parchment panel stays outside the thumbnail")
 T.near(icon.texCoords[3],.518125,.000001,"the scene square is vertically centered within the member")
 T.near(icon.texCoords[4],.669375,.000001)
 T.near(icon.texCoords[2]-icon.texCoords[1],icon.texCoords[4]-icon.texCoords[3],.000001,"352x352 scene crop keeps equal pixel dimensions")
 T.ok(icon._lycheeMask,"Delve art keeps the shared GameIcon mask")
 T.eq(journalQueries,0,"mapped Delves resolve their atlas without journal work")
 for _,map in ipairs({3077,3079,2664}) do U:SetActivityIcon(icon,{mapID=map,categoryID=121});T.eq(icon:GetTexture(),U.Theme.productMedia.."delve.tga","unmapped Delves without journal art use their category icon") end
 T.same(icon.texCoords,{0,1,0,1},"category art does not retain the previous atlas crop")
 U:SetActivityIcon(icon,{mapID=3038,categoryID=121});T.eq(icon:GetTexture(),12345,"an unmapped Delve may use available native journal art")
 local before=journalQueries;U:SetActivityIcon(icon,{mapID=3077,categoryID=121});T.eq(journalQueries,before,"missing journal art is cached between row bindings")
 atlasReady=false;U:SetActivityIcon(icon,{mapID=2963,categoryID=121});T.eq(icon:GetTexture(),U.Theme.productMedia.."delve.tga","an unavailable atlas has a visible category fallback")
 atlasReady=true;U:SetActivityIcon(icon,{mapID=2963,categoryID=121});T.eq(icon:GetTexture(),7291407,"a later available atlas replaces the fallback")
 U:SetActivityIcon(icon,{mapID=99999,categoryID=2});T.eq(icon:GetTexture(),12345,"ordinary dungeon artwork uses the journal's sixth return, the button thumbnail")
 T.near(icon.texCoords[1],.06,.000001,"rebinding to dungeon art restores its complete texture crop")
 for _,category in ipairs(G.Catalog:GetCategories()) do
  U:SetActivityIcon(icon,{categoryID=category.id});T.eq(icon:GetTexture(),U:CategoryIcon(category.icon),"activities without a map use their catalog category icon")
 end
 U:SetActivityIcon(icon,{categoryID=1,mapID=99998});T.eq(icon:GetTexture(),U.Theme.productMedia.."flag.tga","a quest without journal art uses the quest category icon")
 C_Texture.GetAtlasInfo=getAtlas;C_EncounterJournal.GetInstanceForGameMap=getJournal;EJ_GetInstanceInfo=getInstance;G.Catalog.GetCategories=getCategories
end
A:SetSetting("reduceMotion",true)
do
 local native=C_ChallengeMode.GetDungeonScoreRarityColor;local reads=0
 C_ChallengeMode.GetDungeonScoreRarityColor=function(score) reads=reads+1;return native(score) end
 local one=U.C.Text(UIParent,"",12);local two=U.C.Text(UIParent,"",12)
 U:SetScore(one,nil);T.eq(one:GetText(),"未知分数");T.eq(U:ScoreText(nil),"未知分数")
 U:SetScore(one,0);T.eq(one:GetText(),"暂无");T.eq(U:ScoreText(0,"pvp"),"暂无")
 U:SetScore(one,2765);U:SetScore(two,2765);U:ScoreText(2765)
 T.eq(reads,1,"recycled rows and tooltip text share one native rating color")
 U:SetScore(one,2801);U:SetScore(one,2765)
 T.eq(reads,2,"reordering existing scores reuses their native colors")
 for score=3001,3130 do U:ScoreColor(score) end
 local before=reads;U:ScoreColor(2765)
 T.eq(reads,before+1,"rating colors stay bounded instead of retaining every historical score")
 C_ChallengeMode.GetDungeonScoreRarityColor=native
end
do
 local combat=InCombatLockdown;_G.InCombatLockdown=function() return true end
 T.eq(A:Open("settings"),true,"cold UI opens during combat")
 U.frame:Fire("OnEvent","PLAYER_REGEN_DISABLED")
 T.eq(U.frame:IsShown(),true,"entering combat keeps the current page open")
 T.eq(UISpecialFrames[1],"LycheeGroupEscapeHandler")
 local escape=_G[UISpecialFrames[1]]
 T.eq(escape:IsShown(),true)
 local modal=U:OpenModal("combatCheck","Test",240,160)
 escape:Hide();T.eq(modal.frame:IsShown(),false);T.eq(U.frame:IsShown(),true,"Escape first closes the active dialog")
 escape:Hide();T.eq(U.frame:IsShown(),false,"native Escape routing still closes the main window")
 T.eq(A:Open("notes"),true,"pages remain available during combat")
 _G.InCombatLockdown=combat
end
A:Open("settings")
local settings=U.pages.settings
do
 A.Notes:Add("PoolAudit","Away","A note")
 U.Tooltip:ShowNote(U.frame,"PoolAudit-Away")
 T.eq(#U.Tooltip.interactive.memberButtons,0,"a note tooltip does not prebuild unused member controls")
 U.Tooltip:Hide();A.Notes:Remove("PoolAudit-Away")
end
do
 local getMetadata=C_AddOns.GetAddOnMetadata
 local toc=assert(io.open("addon/LycheeGroup/LycheeGroup.toc","r"));local metadata={}
 for line in toc:lines() do local key,value=line:match("^## ([^:]+):%s*(.*)$");if key then metadata[key]=value end end;toc:close()
 C_AddOns.GetAddOnMetadata=function(addon,key) T.eq(addon,"LycheeGroup");return metadata[key] end
 T.ok(settings.nav.about,"About is part of the existing Settings sidebar")
 settings.nav.about:Fire("OnClick","LeftButton")
 T.eq(settings.section,"about");T.eq(settings.panels.about:IsShown(),true);T.eq(settings.panels.browse:IsShown(),false)
 T.eq(settings.heading:GetText(),"关于");T.eq(settings.nav.about.active,true)
 T.eq(settings.aboutValues.name:GetText(),metadata.Title);T.eq(settings.aboutValues.version:GetText(),metadata.Version,"About reads the installed addon's TOC version")
 T.eq(settings.aboutValues.author:GetText(),metadata.Author or U.L.metadataMissing,"missing author metadata is not replaced with an invented identity")
 T.eq(#settings.otherAddons,2,"About introduces only Lychee Launcher and Lychee Talent")
 local expectedLinks={
  {"https://www.wclbox.com/share/AJKkdJtw8gt","https://url.cc.163.com/HoH0Od"},
  {"https://www.wclbox.com/share/AJu72Mjcmed","https://url.cc.163.com/w64q1s"},
 }
 for index,row in ipairs(settings.otherAddons) do
  T.eq(#row.links,#expectedLinks[index]);T.ok(row.summary:GetText()~="")
  for i,button in ipairs(row.links) do
   button:Fire("OnClick","LeftButton")
   local copy=row.linkCopy
   T.eq(copy.field.box:GetText(),expectedLinks[index][i],"addon links expand their own copy field with the verified URL")
   T.eq(U.activeModal,nil);T.eq(copy.clip:GetParent(),row.frame);T.ok(copy.field.box:HasFocus())
   copy.close:Fire("OnClick");T.eq(copy.field.box:HasFocus(),false)
  end
 end
 local last=settings.otherAddons[2];local point={last.frame:GetPoint()}
 T.ok(-point[#point]+last.frame:GetHeight()<=settings.panels.about:GetHeight(),"both addon introductions fit below the compact metadata header")
 metadata.Version="metadata-only version";metadata.Author="Fixture author";settings:RefreshAbout()
 T.eq(settings.aboutValues.version:GetText(),metadata.Version);T.eq(settings.aboutValues.author:GetText(),metadata.Author)
 settings.nav.browse:Fire("OnClick","LeftButton");T.eq(settings.panels.about:IsShown(),false)
 C_AddOns.GetAddOnMetadata=getMetadata
end
T.eq(U.underline:IsShown(),false,"settings does not retain a business-page underline")
for _,button in pairs(U.navItems) do T.eq(button.active,false,"settings clears every business navigation selection") end
U.frame:Fire("OnMouseDown","LeftButton")
T.eq(U.drag.handle,U.frame,"passive main-window areas retain their drag callback after host setup")
U.frame:Fire("OnMouseUp","LeftButton");T.eq(U.drag.handle,nil,"releasing a passive-area drag stops the window")
settings:SelectSection("browse");settings.controls.rememberFilters.widget:Fire("OnClick")
T.eq(A.charPrefs.rememberFilters,false,"browse preference writes to this character through Core")
T.eq(A:GetSetting("rememberFilters"),false)
T.eq(settings.panels.keywords,nil,"keyword filtering has been removed from settings")
T.eq(settings.keywordInput,nil)
settings:SelectSection("memberIcons")
for _,mode in ipairs({"shift","alt","ctrl","always"}) do
 Pick(settings.controls.raidMembers.widget,mode);T.eq(A.db.raidMembers,mode,"raid roster controls save the selected display mode")
end
T.eq(settings.panels.sounds,nil,"sound settings page is removed");T.eq(settings.controls.applicantTone,nil,"notification tone is not configurable")
settings:SelectSection("floating")
T.ok(settings.controls.floatingCompatibility,"floating integration is available in the existing settings section")
settings.controls.floatingCompatibility.widget:Fire("OnClick");T.eq(A.db.floatingCompatibility,false)
settings.controls.floatingCompatibility.widget:Fire("OnClick");T.eq(A.db.floatingCompatibility,true)
do
 local setSetting=A.SetSetting;local writes=0
 function A:SetSetting(...) writes=writes+1;return setSetting(self,...) end
 settings:Sync();T.eq(writes,0,"synchronizing silent slider values never writes settings")
 settings.controls.floatingScale.widget.slider:SetValue(125)
 A.SetSetting=setSetting
 T.eq(writes,1,"a native slider action commits exactly once without a page synchronization guard")
 T.eq(A.db.floatingScale,125)
end
U:Hide()
local stockNameBorder=CreateFrame("Frame",nil,LFGListFrame.EntryCreation.Name);stockNameBorder:SetAlpha(.6);LFGListFrame.EntryCreation.Name.NineSlice=stockNameBorder
-- Exact shape observed in the live native-art probe: an anonymous child Frame
-- with two horizontal and two vertical WHITE8X8 lines, and no backdrop or alias.
local function SkinBorder(parent)
 local border=CreateFrame("Frame",nil,parent);border:SetAllPoints()
 for i=1,4 do
  local line=border:CreateTexture(nil,"OVERLAY");line:SetTexture(130871)
  if i<=2 then
   local edge=i==1 and "TOP" or "BOTTOM";line:SetHeight(.75)
   line:SetPoint(edge.."LEFT",border,edge.."LEFT",0,0);line:SetPoint(edge.."RIGHT",border,edge.."RIGHT",0,0)
  else
   local edge=i==3 and "LEFT" or "RIGHT";line:SetWidth(.75)
   line:SetPoint("TOP"..edge,border,"TOP"..edge,0,0);line:SetPoint("BOTTOM"..edge,border,"BOTTOM"..edge,0,0)
  end
 end
 return border
end
local anonymousNameBorder=SkinBorder(LFGListFrame.EntryCreation.Name);anonymousNameBorder:SetAlpha(.7)
local anonymousDescriptionBorder=SkinBorder(LFGListFrame.EntryCreation.Description)
local nameCursor=LFGListFrame.EntryCreation.Name:CreateTexture(nil,"OVERLAY");nameCursor:SetSize(2,14.25)
local descriptionCursor=LFGListFrame.EntryCreation.Description.EditBox:CreateTexture(nil,"OVERLAY");descriptionCursor:SetSize(2,14.25)
local solidNameBackground=LFGListFrame.EntryCreation.Name:CreateTexture(nil,"BACKGROUND");solidNameBackground:SetAllPoints();solidNameBackground:SetColorTexture(0,0,0,.9)
local solidDescriptionBackground=LFGListFrame.EntryCreation.Description:CreateTexture(nil,"BACKGROUND");solidDescriptionBackground:SetAllPoints();solidDescriptionBackground:SetColorTexture(0,0,0,.9)
local inputContent=CreateFrame("Frame",nil,LFGListFrame.EntryCreation.Name);inputContent:SetAllPoints();CreateFrame("EditBox",nil,inputContent)
A:Open("create")
T.eq(stockNameBorder:IsShown(),false,"borrowed native text hides its child border decoration");T.eq(stockNameBorder:GetAlpha(),0)
T.eq(anonymousNameBorder:IsShown(),false,"the observed anonymous four-line name border is hidden during the lease");T.eq(anonymousDescriptionBorder:GetAlpha(),0)
T.eq(nameCursor:IsShown(),true);T.eq(descriptionCursor:GetAlpha(),1,"untextured engine edit cursors remain operational")
T.eq(solidNameBackground:IsShown(),false);T.eq(solidDescriptionBackground:IsShown(),false,"the observed untextured full-field skin fills do not cover the shared input surface")
T.eq(inputContent:IsShown(),true,"a child containing an input is never treated as pure decoration")

local create=U.pages.create
T.eq(#create.batchPool,0,"an empty creation form does not prebuild recruitment batches")
T.eq(create.picker,nil,"Create keeps its hidden activity popup unbuilt until first expansion")
do
 for _=1,4 do U:Navigate("create") end
 local refreshRoster,refreshApplicants,notesChanged=create.RefreshRoster,create.RefreshApplicants,create.OnNotesChanged
 local rosterUpdates,applicantUpdates,noteUpdates=0,0,0
 create.RefreshRoster=function(self,...) rosterUpdates=rosterUpdates+1;return refreshRoster(self,...) end
 create.RefreshApplicants=function(self,...) applicantUpdates=applicantUpdates+1;return refreshApplicants(self,...) end
 create.OnNotesChanged=function(self,...) noteUpdates=noteUpdates+1;return notesChanged(self,...) end
 G:Notify("roster");G:Notify("applicants")
 T.eq(rosterUpdates,1,"reopening the current Create page must not multiply roster refreshes")
 T.eq(applicantUpdates,1,"reopening the current Create page must not multiply applicant refreshes")
 U:Navigate("settings");rosterUpdates,applicantUpdates=0,0
 G:Notify("roster");G:Notify("applicants")
 A.Notes:Add("SubscriptionProbe","Home","offline fixture",nil)
 A.Notes:Remove("SubscriptionProbe-Home")
 T.eq(rosterUpdates,0,"leaving Create releases every roster subscription")
 T.eq(applicantUpdates,0,"leaving Create releases every applicant subscription")
 T.eq(noteUpdates,0,"leaving Create releases every note subscription")
 T.eq(create.roster,nil,"leaving Create releases the roster snapshot")
 create.RefreshRoster,create.RefreshApplicants,create.OnNotesChanged=refreshRoster,refreshApplicants,notesChanged
 U:Navigate("create")
end
do
 T.eq(create.crossFaction.value,true,"new listings default to cross-faction")
 create.crossFaction:Fire("OnClick");create:RefreshPicker();T.eq(create.crossFaction.value,false,"refresh preserves an explicit opt-out")
 create.crossFaction:Fire("OnClick")
 local activity=G.Catalog:GetActivity(create:FormData().activityID)
 activity.allowCrossFaction=false;create:RefreshPicker();T.eq(create.crossFaction.value,false,"unsupported activities cannot submit cross-faction")
 activity.allowCrossFaction=true;create:RefreshPicker();T.eq(create.crossFaction.value,true,"returning to an allowed activity restores the draft choice")
 T.eq(create.roleFilters.DAMAGER:GetParent(),create.roleFilterSurface,"selected role fill renders above its own track")
end
T.eq(create.formFrame:GetWidth(),create.surface:GetWidth()-48);T.eq(create.rail:GetWidth(),288)
T.ok(create.descriptionShell:GetHeight()>=80,"the native description retains a readable minimum height")
T.eq(create.ilvl.placeholder:GetText(),"不限");T.eq(create.ilvl.placeholder:IsShown(),true,"unrestricted item level has an explicit placeholder")
do
 local summary=create.groupSummary
 T.ok(create.rosterList:IsShown(),"small-group activities show current members directly")
 T.eq(summary:IsShown(),false,"the inline roster replaces the group summary")
 local row=create.rosterList.rows[1];create.rosterList.clip.mouseOver=true
 T.eq(row.member,create.roster[1]);T.ok(row.leaderIcon:IsShown())
 row.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.member,create.roster[1]);T.eq(U.Tooltip.memberContext.source,"roster")
 U.Tooltip:Hide();create.rosterList.clip.mouseOver=nil
 T.eq(summary.mouseEnabled,false);T.eq(summary.mouseMotionEnabled,true)
 U.Tooltip:ShowRoster(summary,create.roster)
 local view=U.Tooltip.interactive;local member=view.memberButtons[1]
 T.eq(U.Tooltip.owner,summary);T.eq(U.Tooltip.sourceRoster,create.roster)
 T.ok(member.name:GetText():find("Player",1,true));T.eq(member.member,create.roster[1]);T.ok(member.leaderIcon:IsShown())
 member:Fire("OnClick");T.eq(U.Tooltip.member,create.roster[1]);T.ok(view.back:IsShown())
 view.back:Fire("OnClick");T.eq(U.Tooltip.member,nil);T.eq(U.Tooltip.sourceRoster,create.roster)
 U.Tooltip:Hide();U.Tooltip:ShowRoster(summary,create.roster);summary:Fire("OnLeave");U.Motion:Tick(.25)
 T.eq(U.Tooltip.owner,nil,"leaving the role summary closes an unpinned roster")
end
local native=LFGListFrame.EntryCreation
T.eq(native.Name:GetParent(),create.titleShell,"actual registered title is leased into our UI")
T.eq(native.Description:GetParent(),create.descriptionShell)
T.eq(native.Name:GetText(),"","a new listing starts with an empty native title")
T.eq(create.formError:GetText(),"","an untouched form does not show required-field errors")
T.eq(create.publish:IsEnabled(),true,"publish remains clickable so an incomplete form can explain its errors")
create.publish:Fire("OnClick");T.eq(create.validationSubmitted,true);T.ok(create.formError:GetText()~="","blank publish validates at the user's request");T.eq(G.published,nil)
native.Name:UserType("Corrected title");T.eq(create.formError:GetText(),"","correcting the submitted field clears its error")
do
 local reanchors=0;local clear=create.desc.ClearAllPoints
 for _,frame in ipairs({create.desc,create.req}) do frame.ClearAllPoints=function(self,...) reanchors=reanchors+1;return clear(self,...) end end
 for i=1,20 do native.Name:UserType("Corrected title "..i) end
 for _,frame in ipairs({create.desc,create.req}) do frame.ClearAllPoints=clear end
 T.eq(reanchors,0,"valid title input does not reflow form containers while the notice remains hidden")
 T.eq(create.formNotice:IsShown(),false)
 native.Name:UserType("Corrected title")
end
do
 local function PointY(region) local points={region:GetPoint()};return points[#points] end
 local originalRequirementsY=PointY(create.req)
 local validator=native.ItemLevel.validateFunc;local ownLevel=200;local warning="要求的物品等级高于你自己的物品等级。"
 native.ItemLevel.validateFunc=function(_,value) if tonumber(value)>ownLevel then return warning end end
 create.ilvl.box:SetText("220");create:ValidateForm()
 T.eq(create.formError:GetText(),warning,"the native requirement reason reaches the form notice")
 T.ok(create.formNotice:IsShown());T.eq(create.formError.justify,"LEFT")
 local point={create.formNotice:GetPoint()};T.eq(point[1],"TOPLEFT");T.eq(point[#point],-44,"the notice appears immediately after the heading")
 T.eq(PointY(create.desc),-56-create.formNotice:GetHeight()-12,"the notice pushes the form content down only while shown")
 T.eq(PointY(create.req),PointY(create.desc)+PointY(create.descriptionShell)-create.descriptionShell:GetHeight()-24)
 T.eq(create.ilvl.box:GetText(),"220","validation alone preserves programmatically filled requirements until submission")
 ownLevel=240;create:ValidateForm();T.eq(create.formNotice:IsShown(),false,"unchanged text is revalidated after the player's equipment changes")
 T.eq(PointY(create.desc),-56,"clearing the notice removes its layout space")
 T.eq(PointY(create.req),originalRequirementsY)
 native.ItemLevel.validateFunc=validator;create.ilvl.box:SetText("");create:ValidateForm()
 local height=create.batchScroll:GetHeight()
 create:SetManageError("An applicant action failed. Please check the current application.")
 T.ok(create.manageNotice:IsShown());T.eq(create.dError.justify,"LEFT")
 T.eq(create.batchScroll:GetHeight()+create.manageNotice:GetHeight()+12,height,"the recruitment notice reserves real viewport space")
 T.eq(PointY(create.batchScroll),-194-create.manageNotice:GetHeight()-12,"the recruitment list moves down when the notice appears")
 T.eq(PointY(create.applicantTable),-167-create.manageNotice:GetHeight()-12)
 T.eq(create.batchSlider:GetHeight(),create.batchScroll:GetHeight())
 create.manageNotice.close:Fire("OnClick");T.eq(create.batchScroll:GetHeight(),height,"closing the notice restores the list viewport")
 T.eq(PointY(create.batchScroll),-194);T.eq(PointY(create.applicantTable),-167)
end
native.Name:UserType("");create:PrepareForm(false)
do
 local foreign=CreateFrame("Frame",nil,UIParent)
 native.Name:SetParent(foreign)
 create.titleShell:Fire("OnMouseDown","LeftButton")
 T.eq(native.Name:GetParent(),create.titleShell,"creation reclaims the actual registered field after a foreign handoff")
 T.eq(native.Name:HasFocus(),true)
 T.ok(U.Native.titleInput:IsOwned() and U.Native.descriptionInput:IsOwned(),"both creation fields use shared native controls")
 local descriptionHeight=native.Description:GetHeight()
 native.Description:SetParent(foreign);native.Description:SetHeight(40)
 T.eq(U.Native.owner,nil,"a lost description releases the paired creation form")
 T.eq(anonymousDescriptionBorder:GetAlpha(),1,"foreign layout restores description artwork before any focus or key event")
 T.eq(native.Description:GetParent(),foreign,"creation release does not move a field already owned elsewhere")
 create.descriptionShell:Fire("OnMouseDown","LeftButton")
 T.eq(native.Description:GetParent(),create.descriptionShell);T.eq(native.Description.EditBox:HasFocus(),true)
 -- Return both controls to their normal host before the rest of the flow.
 U.Native:ReleaseCreation()
 native.Name:SetParent(native);native.Description:SetParent(native);native.Description:SetHeight(descriptionHeight)
 create:EnsureCreationInput()
end
T.ok(create.score:IsShown(),"key activity exposes score")
do
 local catalog=G.Catalog
 local group=catalog:GetGroups("seasonDungeon")[1]
 local variants=group.variants
 group.variants={catalog:GetActivity(3),catalog:GetActivity(2)}
 create:TogglePicker()
 local seasonalKey
 for key,entry in pairs(create.pickerEntries) do if entry.category=="seasonDungeon" and entry.group==group then seasonalKey=key;break end end
 create:SelectPickerRow(seasonalKey)
 T.eq(create:FormData().activityID,2,"new seasonal dungeons default to Mythic Keystone even when Normal sorts first")
 for _,button in ipairs(create.difficultyButtons) do if button.value==3 then button:Fire("OnClick");break end end
 create:RefreshPicker()
 T.eq(create:FormData().activityID,3,"an explicit Normal choice remains selected on refresh")
 group.variants=variants
 create:TogglePicker();create:SelectPickerRow(seasonalKey)
end
do
 create:TogglePicker()
 local picker=create.picker
 T.ok(picker:IsShown(),"first expansion creates the complete activity popup")
 create:ClosePicker();create:TogglePicker();T.eq(create.picker,picker,"Create reuses its activity popup after closing")
 T.eq(create.tierChoice:IsShown(),false,"已固定本赛季的活动不再提供重复范围下拉")
 local catalog=G.Catalog;local getGroups,getTiers=catalog.GetGroups,catalog.GetTiers
 local source=getGroups(catalog,"2")[1]
 local groups={{key="one",name="One",tier=1,activity=source.activity},{key="two",name="Two",tier=2,activity=source.activity}}
 catalog.GetGroups=function(self,key) if key=="2" then return groups end;return getGroups(self,key) end
 catalog.GetTiers=function() return {{id=1,name="First"},{id=2,name="Second"}} end
 create.pickerCategory="2";create.pickerTier=2;create:RefreshPickerRows()
 T.eq(create.tierChoice:IsShown(),true,"多个有效资料片仍保留范围选择")
 T.eq(#create.pickerResults.ids,1)
 local tiers={{id=1,name="First"},{id=2,name="Second"}}
 for i=3,11 do groups[i]={key="tier"..i,name="Tier "..i,tier=i,activity=source.activity};tiers[i]={id=i,name="Tier "..i} end
 catalog.GetTiers=function() return tiers end
 create:RefreshPickerRows();create.tierChoice:Fire("OnClick")
 local menu=U.context.menu
 T.ok(menu:GetHeight()>picker:GetHeight()-120,"the expansion submenu extends below the activity popup")
 menu.mouseOver=true
 picker:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
 T.eq(picker:IsShown(),true,"clicking the expansion submenu outside Create's popup keeps its owner open")
 menu.list:SetPixelOffset(100000,false)
 local choice;for _,row in ipairs(menu.list.rows) do if row.key and menu.items[row.key].value==11 then choice=row;break end end
 T.ok(choice,"the last expansion remains selectable in the scrolled submenu")
 choice:Fire("OnClick","LeftButton");menu.mouseOver=nil
 T.eq(create.pickerTier,11);T.eq(#create.pickerResults.ids,1)
 for i=11,3,-1 do groups[i]=nil end
 groups[2]=nil;create:RefreshPickerRows()
 T.eq(create.tierChoice:IsShown(),false,"单一有效范围不显示只有全部和自身的下拉")
 T.eq(create.pickerTier,nil,"隐藏下拉同时清除已失效的范围条件")
 T.eq(#create.pickerResults.ids,1,"清除隐藏范围后唯一活动仍可浏览")
 catalog.GetGroups,catalog.GetTiers=getGroups,getTiers
 picker:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
 T.eq(picker:IsShown(),false,"a click outside both Create's popup and its expansion submenu still closes the popup")
end
create:TogglePicker();create.pickerSearch.box:SetText("Dungeon")
T.eq(#create.pickerResults.ids,2,"one dungeon group has distinct seasonal and original contexts")
local original;for key,entry in pairs(create.pickerEntries) do if entry.category=="2" then original=key end end
G.Catalog:GetActivity(3).isMythicPlusActivity=false;G.Catalog:GetActivity(3).isRatedPvpActivity=false
create:SelectPickerRow(original);T.eq(create:FormData().activityID,3,"selected original context resolves its own native activity")
local normalActivity=G.Catalog:GetActivity(3);local normalDifficulty=normalActivity.difficultyID
normalActivity.difficultyID=nil;create:RefreshPicker()
T.eq(create.difficultyGroup:IsShown(),false);T.eq(create.difficultyChoice:IsShown(),false)
T.eq(create.difficultyFixedSurface:IsShown(),false,"an activity without native difficulty has no artificial difficulty label")
T.eq(create:FormData().activityID,3,"hiding difficulty preserves the valid native activity")
normalActivity.difficultyID=normalDifficulty;create:RefreshPicker()
T.eq(create.score:IsShown(),false,"original normal dungeon hides score")
T.eq(create.scoreLabel:IsShown(),false,"native false rating flags hide the rating label alongside the control")
T.eq(native.Name:GetText(),"","switching the new listing's activity does not generate a title")
native.Name:UserType("My custom group");create:TogglePicker();create.pickerSearch.box:SetText("Dungeon");local seasonal;for key,entry in pairs(create.pickerEntries) do if entry.category=="seasonDungeon" then seasonal=key end end;create:SelectPickerRow(seasonal);T.eq(native.Name:GetText(),"My custom group","activity change preserves a custom title")
create.ilvl.box:SetText("250");create.score.box:SetText("1800");create:Submit()
T.eq(G.published.requiredDungeonScore,1800);T.eq(G.published.activityID,2)
T.eq(G.published.isCrossFactionListing,true,"cross-faction default reaches the actual publish payload")
T.eq(create.manage:IsShown(),true,"native listing replaces form with applicant management")
do
 G.applicants[70]={id=70,status="applied",displayOrderID=0,members={{name="Solo-Away",nameKey="Solo-Away",class="WARRIOR",assignedRole="DAMAGER",dungeonScore=2200}}}
 G:Notify("applicants")
 T.eq(#create.batchPool,1,"only the visible applicant batch is allocated")
 local solo=create.batchPool[1];T.eq(#solo.people,1,"a solo applicant does not prebuild four unused member rows")
 local nodes=#S.nodes;G:Notify("applicants");T.eq(#S.nodes,nodes,"unchanged applicants reuse their batch and member controls")
 local dk={name="DeathKnight-Away",nameKey="DeathKnight-Away",class="DEATHKNIGHT",specID=252,assignedRole="DAMAGER",requestedRoles={TANK=true,DAMAGER=true,HEALER=false}}
 G.applicants[70].members[1]=dk;G:Notify("applicants")
 local row=solo.people[1];local specTexture=row.icon:GetTexture()
 T.eq(row.roles[1]:GetTexture(),U.Theme.productMedia.."role-tank.tga");T.eq(row.roles[2]:GetTexture(),U.Theme.productMedia.."role-dps.tga")
 T.eq(row.roles[1]:IsShown(),true);T.eq(row.roles[2]:IsShown(),true);T.eq(row.roles[3]:IsShown(),false,"a DK applicant can request tank and damage independently of specialization")
 create.roleFilters.TANK:Fire("OnClick");T.eq(#create.appIDs,1)
 create.roleFilters.DAMAGER:Fire("OnClick");T.eq(#create.appIDs,1)
 T.eq(create.roleFilters.TANK.active,true);T.eq(create.roleFilters.DAMAGER.active,true,"applicant roles can be selected together")
 create.roleFilters.HEALER:Fire("OnClick");T.eq(#create.appIDs,1,"any selected requested role retains the complete applicant batch")
 T.eq(create.roleFilters.ALL.active,true,"selecting all three roles collapses to All")
 for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do T.eq(create.roleFilters[role].active,false,"All clears individual role highlights") end
 create.roleFilters.HEALER:Fire("OnClick");T.eq(#create.appIDs,0,"selecting one role from All applies only that role")
 create.roleFilters.HEALER:Fire("OnClick");T.eq(#create.appIDs,1);T.eq(create.roleFilters.ALL.active,true,"clearing the final role restores all applicants")
 create.roleFilters.ALL:Fire("OnClick")
 G.applicants[72]={id=72,status="applied",displayOrderID=1,members={{name="Healer-Away",class="PRIEST",assignedRole="HEALER"}}}
 G:Notify("applicants")
 create.roleFilters.TANK:Fire("OnClick");T.eq(#create.appIDs,1)
 create.roleFilters.HEALER:Fire("OnClick");T.eq(#create.appIDs,2,"different selected roles include the union of matching applicant batches")
 create.roleFilters.ALL:Fire("OnClick");T.eq(#create.appIDs,2);T.eq(create.roleFilters.TANK.active,false);T.eq(create.roleFilters.HEALER.active,false)
 G.applicants[72]=nil;G:Notify("applicants")
 dk.requestedRoles.TANK=false;G:Notify("applicants")
 T.eq(solo.people[1],row,"changing requested roles reuses the existing applicant row")
 T.eq(row.roles[1]:GetTexture(),U.Theme.productMedia.."role-dps.tga");T.eq(row.roles[2]:IsShown(),false);T.eq(row.roles[3]:IsShown(),false,"row reuse removes the old second requested role")
 T.eq(dk.specID,252);T.eq(row.icon:GetTexture(),specTexture,"requested roles do not rewrite the DK specialization icon")
 G.applicants[70]=nil;G:Notify("applicants")
 T.eq(solo.appID,nil);T.eq(solo.people[1].member,nil,"emptying recruitment releases pooled member bindings")
end
G.applicants[71]={id=71,status="applied",displayOrderID=1,comment="We join together",members={{name="One-Away",nameKey="One-Away",class="WARRIOR",assignedRole="TANK",specID=71,itemLevel=270,dungeonScore=2200,factionGroup=1,raceName="人类"},{name="Two-Away",nameKey="Two-Away",class="PALADIN",assignedRole="HEALER",specID=66,itemLevel=260,dungeonScore=2100,factionGroup=0,raceName="血精灵"}}}
G.applicants[71].members[1].dungeonScores={mapScore=315.7}
G.applicants[71].members[2].dungeonScores={mapScore=0}
G:Notify("applicants")
local batch=create.batchPool[1]
T.eq(batch.people[2]:IsShown(),true,"every batch member has an individual row")
T.eq(batch.comment:GetText(),"We join together");T.eq(batch.people[2].score:GetText(),"2100")
T.eq(batch.people[1].mapScore:GetText(),"315");T.eq(batch.people[2].mapScore:GetText(),"0","a real zero map score remains numeric")
T.near(batch.people[1]:GetHeight(),72*.7*.94,.001);T.near(batch:GetHeight(),172*.7*.94,.001,"the complete applicant batch retains the additional six percent compression")
T.eq(batch.people[1].race:GetText(),"人类");T.eq(batch.people[2].race:GetText(),"血精灵")
T.ok(batch.people[1].faction:IsShown());T.ok(batch.people[2].faction:IsShown())
do
 local row=batch.people[1]
 U.Tooltip:Hide();row:Fire("OnEnter")
 T.eq(U.Tooltip.owner,nil,"applicant numeric and note columns keep the row hover without opening player details")
 T.eq(batch.bg:IsShown(),true,"the whole applicant row retains its hover feedback")
 create.batchScroll.mouseOver=true;row.tooltipArea:Fire("OnEnter")
 T.eq(U.Tooltip.owner,row);T.eq(U.Tooltip.member,row.member)
 T.eq(row.tooltipArea:GetWidth(),row:GetWidth()*.25,"applicant details activate only over the left quarter")
 T.eq(row.tooltipArea.mouseEnabled,false,"the identity hover area does not intercept clicks or dragging")
 T.eq(row.tooltipArea.mouseMotionEnabled,true)
 local open,showPlayer=A.Open,U.Tooltip.ShowPlayer;local opens,shows=0,0
 A.Open=function() opens=opens+1 end;U.Tooltip.ShowPlayer=function() shows=shows+1 end
 for _,button in ipairs({"LeftButton","RightButton"}) do row:Fire("OnClick",button) end
 A.Open,U.Tooltip.ShowPlayer=open,showPlayer
 T.eq(opens,0,"applicant clicks do not route to Notes");T.eq(shows,0,"applicant clicks do not open preview details")
 row.mouseOver=true;row.tooltipArea:Fire("OnLeave");U.Motion:Tick(.25)
 T.eq(U.Tooltip.owner,nil,"moving from identity to right-side columns closes unpinned details")
 row.mouseOver=nil;row.tooltipArea:Fire("OnEnter");row.tooltipArea:Fire("OnHide")
 T.eq(U.Tooltip.owner,nil,"hiding an identity trigger releases its player details")
 create.batchScroll.mouseOver=nil
end
do
 local function X(region)
  local p={region:GetPoint()};local x=p[#p-1];local parent=region:GetParent()
  if parent and parent.definition then local point={parent:GetPoint()};x=x+point[#point-1] end
  return x
 end
 for _,pair in ipairs({{"role","role"},{"ilvl","ilvl"},{"rating","score"},{"mapScore","mapScore"}}) do
  local header,value=create.applicantHeaders[pair[1]],batch.people[1][pair[2]]
  local layout=create.applicantColumns[pair[1]];local cell=create.applicantTable.columns[pair[1]]
  T.eq(header.justify,"CENTER");T.near(X(value)+value:GetWidth()/2,layout.x+layout.width/2,.001,"numeric values share their declared column center")
  T.ok(X(value)>=cell.x and X(value)+value:GetWidth()<=cell.x+cell.width+.001,"numeric values remain within the corresponding header cell")
 end
 T.eq(X(create.applicantHeaders.actions),X(batch.invite));T.ok(create.applicantTable.columns.actions.width>=batch.invite:GetWidth()+batch.decline:GetWidth()+4,"the actions column fits both decision buttons")
 local headings={};for _,header in pairs(create.applicantHeaders) do if header:IsShown() then headings[#headings+1]=header end end
 table.sort(headings,function(a,b) return X(a)<X(b) end)
 local labels={};for i,header in ipairs(headings) do labels[i]=header:GetText() end
 T.same(labels,{"申请者","职责","阵营","评分","单本分","装等","备注","操作"},"key applicant headings follow the visible data columns")
 T.ok(create.applicantTable.columns.role.x>=create.applicantTable.columns.name.x+create.applicantTable.columns.name.width-.001,"roles follow the applicant identity column")
 local row=batch.people[1]
 local faction=create.applicantHeaders.faction
 T.eq(faction.justify,"CENTER","faction headings center over the icon and replacement race")
 T.eq(row.faction:GetParent(),row.factionButton);T.eq(row.faction:GetPoint(),"CENTER")
 T.near(X(row.factionButton)+row.factionButton:GetWidth()/2,create.applicantColumns.faction.x+create.applicantColumns.faction.width/2,.001,"the icon button shares its faction column center")
 T.eq(row.race.justify,"CENTER");T.eq(row.race:GetParent(),row.factionButton);T.eq(row.race:GetPoint(),"CENTER")
 T.ok(row.factionButton:GetWidth()<=row.faction:GetWidth()+16,"faction hover feedback stays close to the icon")
 T.ok(create.applicantColumns.comment.x-X(row.ilvl)-row.ilvl:GetWidth()>=12-.001,"notes keep clear space after item level")
 T.ok(X(batch.invite)-X(batch.comment)-batch.comment:GetWidth()>=12-.001,"notes do not crowd the action buttons")
 local previous
 for _,key in ipairs({"rating","mapScore","ilvl"}) do
  local column=create.applicantColumns[key];local center=column.x+column.width/2
  if previous then T.ok(center>previous,"all three adjustable numeric columns keep their visible order") end
  previous=center
 end
 local height=row:GetHeight()
 T.eq(row.race:IsShown(),false,"race names start collapsed")
 row.factionButton:Fire("OnClick","LeftButton");T.eq(row.race:IsShown(),false,"clipped cells do not toggle outside the viewport")
 create.batchScroll.mouseOver=true
 row.factionButton:Fire("OnClick","LeftButton")
 T.eq(row.race:IsShown(),true);T.eq(batch.people[2].race:IsShown(),false,"each member expands independently")
 local iconPoint={row.factionButton:GetPoint()}
 T.eq(iconPoint[#iconPoint],0);T.eq(row.race:GetPoint(),"CENTER");T.eq(row.faction:IsShown(),false,"the race replaces the faction icon")
 T.eq(row.factionButton:GetWidth(),create.applicantColumns.faction.width,"the displayed race remains clickable across its full width")
 T.eq(row:GetHeight(),height,"race switching keeps the compact row height")
 create:RefreshApplicants();T.eq(row.race:IsShown(),true,"ordinary applicant refresh preserves the current member's expansion")
 row.factionButton:Fire("OnClick","RightButton")
 T.ok(U.context:IsMenuOpen(row),"right clicking the faction cell keeps the member menu");T.eq(row.race:IsShown(),true)
 U:CloseMenu()
 row.factionButton:Fire("OnClick","LeftButton")
 iconPoint={row.factionButton:GetPoint()}
 T.eq(row.race:IsShown(),false);T.eq(row.faction:IsShown(),true);T.eq(iconPoint[#iconPoint],0,"both states share the same vertical center")
 T.eq(row.factionButton:GetWidth(),32,"switching back restores the compact icon hit area")
 local member=G.applicants[71].members[1];local race=member.raceName
 -- Full race text is checked with an explicitly wide faction column.
 local factionWidthPath="layout.tables.createApplicants.widths.faction"
 local savedFactionWidth=A.Configuration:Get(factionWidthPath)
 A.Configuration:Set({[factionWidthPath]=.16},{storage="character"})
 for _,name in ipairs({"人类","血精灵","赞达拉巨魔","光铸德莱尼","至高岭牛头人"}) do
  member.raceName=name;create:RefreshApplicants()
  T.ok(row.race:GetStringWidth()<=row.race:GetWidth(),"long Chinese race names fit on one line")
  T.eq(row.race.wrap,false,"race names never wrap as recycled applicant rows change")
  T.eq(row.race:GetPoint(),"CENTER","all race names keep the icon's center")
 end
 row.factionButton:Fire("OnClick","LeftButton")
 local nameKey=member.nameKey;member.nameKey="Replacement-Away";create:RefreshApplicants()
 T.eq(row.race:IsShown(),false,"a reused row does not transfer expansion to a different member")
 member.nameKey=nameKey
 local factionGroup=member.factionGroup;member.factionGroup=nil;member.raceName=nil;create:RefreshApplicants()
 T.eq(row.faction:IsShown(),false);T.eq(row.factionButton.label:GetText(),"—","unknown faction keeps a visible centered trigger")
 row.factionButton:Fire("OnClick","LeftButton");T.eq(row.race:GetText(),"—");T.eq(row.race:IsShown(),true)
 row:Hide();row:Show();T.eq(row.race:IsShown(),false,"hidden rows release transient expansion")
 member.factionGroup=factionGroup;create.batchScroll.mouseOver=nil
 member.raceName=race;create:RefreshApplicants()
 A.Configuration:Set({[factionWidthPath]=savedFactionWidth},{storage="character"})
 local scores=member.dungeonScores;member.dungeonScores=nil;create:RefreshApplicants()
 T.eq(row.mapScore:GetText(),"—","missing map scores do not reuse the previous applicant's value")
 T.same({row.mapScore:GetTextColor()},U.Theme.muted,"missing map scores clear the previous rarity color")
 member.dungeonScores=scores;create:RefreshApplicants()
 T.same({row.mapScore:GetTextColor()},{.3,.8,.2},"map scores use the native dungeon-specific color")
 member.dungeonScores={mapScore=0};create:RefreshApplicants()
 T.eq(row.mapScore:GetText(),"0");T.same({row.mapScore:GetTextColor()},U.Theme.muted,"a reused zero-score row clears the known score color")
 member.dungeonScores=scores;create:RefreshApplicants()
 T.eq(create.groupSummary:GetWidth(),create.groupStrip:GetWidth()+24,"the hover summary hugs its content with equal padding")
end
do
 local saved=G.applicants[71]
 local one={applicantID=71,name="ArenaOne-Away",nameKey="ArenaOne-Away",class="MAGE",assignedRole="DAMAGER",itemLevel=288,dungeonScore=3900,ratingKind="pvp",rating=1950,pvpRatingInfo={bracket=1,rating=1950,activityName="2v2"}}
 local two={applicantID=71,name="ArenaTwo-Away",nameKey="ArenaTwo-Away",class="PRIEST",assignedRole="HEALER",itemLevel=285,dungeonScore=4100,ratingKind="pvp",rating=1450,pvpRatingInfo={bracket=1,rating=1450,activityName="2v2"}}
 G.applicants[71]={id=71,status="applied",displayOrderID=1,comment="2v2",members={one,two}}
 G.applicants[72]={id=72,status="applied",displayOrderID=2,comment="2v2",members={{name="ArenaThree-Away",nameKey="ArenaThree-Away",class="MAGE",assignedRole="DAMAGER",itemLevel=290,dungeonScore=1000,ratingKind="pvp",rating=1750,pvpRatingInfo={bracket=1,rating=1750,activityName="2v2"}}}}
 G:Notify("applicants");Pick(create.sortChoice,"score")
 T.same(create.appIDs,{72,71},"同行申请按当前PvP赛制最低分排序，不按M+分或最高成员分")
 local party;for _,candidate in ipairs(create.batchPool) do if candidate.appID==71 then party=candidate end end
 T.eq(party.people[1].score:GetText(),"1950");T.eq(party.people[2].score:GetText(),"1450");T.eq(party.people[2].ilvl:GetText(),"285")
 two.rating=nil;two.pvpRatingInfo=nil;G:Notify("applicants")
 T.eq(party.people[2].score:GetText(),"未知分数","缺少竞技场评分的申请者不显示M+分")
 U.Tooltip:ShowPlayer(party.people[2],two)
 T.eq(U.Tooltip.interactive.metrics[1].value:GetText(),"285");T.eq(U.Tooltip.interactive.metrics[1].title:GetText(),"PvP 装等")
 T.eq(U.Tooltip.interactive.metrics[2].value:GetText(),"未知分数","申请者详情使用同一PvP缺值语义")
 two.rating=0;two.pvpRatingInfo={bracket=2,rating=0,activityName="3v3"}
 G:Notify("applicants")
 T.eq(U.Tooltip.interactive.metrics[2].title:GetText(),"3v3");T.eq(U.Tooltip.interactive.metrics[2].value:GetText(),"暂无","真实零分与未知评分明确区分")
 U.Tooltip:Hide();G.applicants[71]=saved;G.applicants[72]=nil;Pick(create.sortChoice,"newest");G:Notify("applicants")
end
do
 local listing=G.listing;local oldActivity=listing.activityID
 local memberHeight,batchHeight=batch.people[1]:GetHeight(),batch:GetHeight()
 Pick(create.sortChoice,"score")
 listing.activityID=1;G:Notify("listing")
 T.eq(batch.people[1]:GetHeight(),memberHeight,"raid applicants retain the same compact member height as key applicants")
 T.eq(batch:GetHeight(),batchHeight,"switching recruitment to a raid preserves batch spacing")
 T.ok(not create.applicantHeaders.rating or not create.applicantHeaders.rating:IsShown(),"raid applicants have no unusable score column")
 T.ok(not create.applicantHeaders.mapScore or not create.applicantHeaders.mapScore:IsShown());T.eq(batch.people[1].mapScore:IsShown(),false)
 T.eq(batch.people[1].score:IsShown(),false);T.eq(batch.people[1].score:GetText(),"")
 T.eq(create.sortChoice.value,"newest","changing to raid recruitment clears an unavailable score sort")
 local function X(region)
  local p={region:GetPoint()};local x=p[#p-1];local parent=region:GetParent()
  if parent and parent.definition then local point={parent:GetPoint()};x=x+point[#point-1] end
  return x
 end
 local ilvlColumn=create.applicantColumns.ilvl
 T.near(ilvlColumn.x+ilvlColumn.width,X(batch.people[1].ilvl)+batch.people[1].ilvl:GetWidth(),.001,"raid item levels stay within the configured column")
 local headings={};for _,header in pairs(create.applicantHeaders) do if header:IsShown() then headings[#headings+1]=header end end
 table.sort(headings,function(a,b) return X(a)<X(b) end)
 local labels={};for i,header in ipairs(headings) do labels[i]=header:GetText() end
 T.same(labels,{"申请者","职责","阵营","装等","备注","操作"},"raid applicant headings reclaim the score column")
 local faction=create.applicantHeaders.faction
 T.eq(faction.justify,"CENTER","raid faction headings also center over their content")
 T.near(X(batch.people[1].factionButton)+batch.people[1].factionButton:GetWidth()/2,create.applicantColumns.faction.x+create.applicantColumns.faction.width/2,.001,"raid faction icons share their column center")
 T.eq(batch.people[1].race:GetParent(),batch.people[1].factionButton);T.eq(batch.people[1].race:GetPoint(),"CENTER","raid race names share the same center")
 create.batchScroll.mouseOver=true;batch.people[1].factionButton:Fire("OnClick","LeftButton")
 T.eq(batch.people[1].race:IsShown(),true);T.eq(batch.people[1].faction:IsShown(),false,"raid race names also replace the faction icon")
 T.eq(batch.people[1]:GetHeight(),memberHeight);T.eq(batch:GetHeight(),batchHeight,"showing a raid applicant's race leaves the row and batch heights unchanged")
 batch.people[1].factionButton:Fire("OnClick","LeftButton");create.batchScroll.mouseOver=nil
 for _,key in ipairs({"role","ilvl"}) do local header,value=create.applicantHeaders[key],batch.people[1][key];local layout=create.applicantColumns[key];T.eq(header.justify,"CENTER");T.near(layout.x+layout.width/2,X(value)+value:GetWidth()/2,.001,"raid role and item level share their column centers") end
 T.ok(batch.comment:GetWidth()>115,"raid notes use the space released by the score column")
 create.sortChoice:Fire("OnClick","LeftButton")
 for _,item in ipairs(U.context.menu.items) do T.ok(item.value~="score","raid sort menu omits rating") end
 U:CloseMenu()
 listing.activityID=oldActivity;G:Notify("listing")
 T.eq(create.applicantHeaders.rating:IsShown(),true);T.eq(batch.people[1].score:IsShown(),true)
 T.eq(create.applicantHeaders.mapScore:IsShown(),true);T.eq(batch.people[1].mapScore:IsShown(),true)
 T.eq(batch.people[1].score:GetText(),"2200");T.eq(batch.people[1].mapScore:GetText(),"315");T.near(batch.comment:GetWidth(),create.applicantColumns.comment.width,.001,"reused key batches restore their note cell alongside both score columns")
 listing.activityID=3;G:Notify("listing")
 T.eq(create.applicantHeaders.rating:IsShown(),true);T.ok(not create.applicantHeaders.mapScore or not create.applicantHeaders.mapScore:IsShown());T.eq(batch.people[1].mapScore:IsShown(),false,"ordinary dungeons do not have a listing map score")
 T.near(batch.comment:GetWidth(),create.applicantColumns.comment.width,.001,"non-key activities use their resized note cell")
 listing.activityID=oldActivity;G:Notify("listing")
 Pick(create.sortChoice,"score");Pick(create.sortChoice,"newest")
end

do
 G.manageApplicants,G.manageListing=false,false;G:Notify("permissions")
 T.eq(batch.people[1]:IsShown(),true,"ordinary members retain the complete applicant display")
 T.eq(batch.comment:GetText(),G.applicants[71].comment)
 T.eq(batch.invite:IsShown(),false);T.eq(batch.decline:IsShown(),false)
 T.eq(create.editListing:IsShown(),false);T.eq(create.cancelListing:IsShown(),false)
 batch.invite:Fire("OnClick");T.eq(G.invitedApplicant,nil,"an old invite callback cannot act after permission loss")
 G.manageApplicants=true;G:Notify("permissions")
 T.eq(batch.invite:IsShown(),true,"assistants can manage applicant batches");T.eq(create.editListing:IsShown(),false,"assistants cannot edit the listing")
 G.manageListing=true;G:Notify("permissions");T.eq(create.editListing:IsShown(),true);T.eq(create.cancelListing:IsShown(),true)
 G.listing.isCrossFactionListing=false
 create.editListing:Fire("OnClick");T.eq(native.Name:GetText(),G.listing.name,"editing preserves the published native title");T.eq(create.crossFaction.value,false,"editing preserves an existing same-faction listing")
 G.manageListing=false;G:Notify("permissions");T.eq(U.Native.owner,nil,"losing listing authority returns the leased fields")
 T.eq(create.manage:IsShown(),true);T.eq(native.Name:GetParent(),native)
 G.manageListing=true;G:Notify("permissions")
end
do
 create.manageNotice.close:Fire("OnClick")
 local layout=create.LayoutApplicantViewport;local layouts=0
 create.LayoutApplicantViewport=function(self,...) layouts=layouts+1;return layout(self,...) end
 batch.invite:Fire("OnClick")
 create.LayoutApplicantViewport=layout
 T.eq(G.invitedApplicant,71);T.eq(batch.invite:IsShown(),false,"inflight invitation removes duplicate actions")
 T.eq(layouts,1,"the synchronous invitation update is not rebound again by an already hidden notice")
 T.eq(create.manageNotice:IsShown(),false)
end
for id=72,84 do G.applicants[id]={id=id,status="applied",displayOrderID=id,comment="",members=G.applicants[71].members} end
G:Notify("applicants");T.eq(create.batchSlider:IsShown(),true,"the full applicant list exposes a scrollbar when it overflows")
T.eq(create.batchBody:GetWidth(),create.manage:GetWidth()-U.C.listRightInset,"applicant content leaves the shared six-plus-twelve scrollbar gutter")
do
 local slider=create.batchSlider
 T.eq(slider:GetWidth(),6);T.eq(slider.thumb:GetWidth(),6);T.eq(slider.thumb:GetHeight(),28)
 T.same(slider.thumb.fill,U.Theme.accent,"Create uses the shared brand-red scrollbar thumb")
 slider:SetValue(56);T.eq(create.batchScroll:GetVerticalScroll(),56,"native thumb dragging still updates applicant scrolling")
 slider:Fire("OnEnter");slider:Fire("OnMouseDown","LeftButton");slider:SetValue(112);slider:Fire("OnMouseUp","LeftButton");slider:Fire("OnLeave")
 T.same(slider.thumb.fill,U.Theme.accent,"hover and drag never replace the brand-red thumb with native gray")
 create:SetBatchOffset(0,false);create.batchScroll.mouseOver=true
 local row=create.batchPool[1].people[1];row.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.owner,row)
 create:SetBatchOffset(280,false);T.eq(U.Tooltip.owner,nil,"recycling an applicant batch clears the previous identity's tooltip")
 create:SetBatchOffset(0,false);create.batchScroll.mouseOver=nil
end
do
 local saved=G.applicants;G.applicants={}
 local function Member(index) return {name="Scroll"..index,nameKey="Scroll"..index.."-Away",class="WARRIOR",assignedRole="DAMAGER",itemLevel=600,rating=2000} end
 for id=1,100 do G.applicants[id]={id=id,status="applied",displayOrderID=id,members={Member(id)}} end
 do
  local rating=U.MemberRating;local reads=0
  U.MemberRating=function(self,member) reads=reads+1;return rating(self,member) end
  G.applicants[10].members[1].rating=nil
  Pick(create.sortChoice,"score")
  T.ok(reads<=120,"one hundred batches compute rating once each plus the visible rows, got "..reads)
  T.eq(create.appIDs[100],10,"unknown rating remains below every known rating")
  local expected=1;for i=1,99 do if expected==10 then expected=11 end;T.eq(create.appIDs[i],expected,"equal ratings preserve native display order");expected=expected+1 end
  U.MemberRating=rating;G.applicants[10].members[1].rating=2000;Pick(create.sortChoice,"newest")
 end
 create:RefreshApplicants();create:SetBatchOffset(0,false);A:SetSetting("reduceMotion",false)
 local get=G.GetApplicant;local reads,total=0,0
 G.GetApplicant=function(self,id) reads=reads+1;return get(self,id) end
 create.batchScroll:Fire("OnMouseWheel",-1)
 for tick=1,9 do
  local first,last=create.firstBatch,create.lastBatch;reads=0;U.Motion:Tick(1/60);total=total+reads
  if first==create.firstBatch and last==create.lastBatch then T.eq(reads,0,"scrolling within a bound interval does not reread applicants")
  else T.eq(reads,create.lastBatch-create.firstBatch+1,"a changed interval reads only its visible batches") end
 end
 T.ok(total<=#create.batchPool*2,"one wheel animation reads at most two visible intervals without scanning all applicants")
 create:SetBatchOffset(create.batchBody:GetHeight(),false);T.eq(create.batchPool[1].appID,create.firstBatch);T.eq(create.batchPool[create.lastBatch-create.firstBatch+1].appID,100,"scrolling reaches the final applicant without truncating the data")
 G.applicants[1].members={Member(1),Member(101),Member(102),Member(103),Member(104)}
 G.applicants[2].members={Member(2),Member(105)}
 create:RefreshApplicants();create:SetBatchOffset(0,false)
 T.near(create.batchPool[1]:GetHeight(),400*.7*.94,.001);T.near(create.batchPool[2]:GetHeight(),172*.7*.94,.001)
 T.eq(create.lastBatch,5,"compact batches expose more applicants in the same viewport");T.eq(create.batchPool[1].people[5].member,G.applicants[1].members[5],"a tall batch keeps every member")
 local edge=create.batchTops[2]
 create:SetBatchOffset(edge,false);T.eq(create.firstBatch,1,"a batch touching the top edge keeps the established boundary semantics")
 create:SetBatchOffset(edge+.1,false);T.eq(create.firstBatch,2);T.eq(create.batchPool[1].appID,2,"cached geometry locates the next variable-height batch")
 create:SetBatchOffset(8000,false);create:SetBatchOffset(0,false)
 local nodes,pool=#S.nodes,#create.batchPool
 create:SetBatchOffset(8000,false);create:SetBatchOffset(0,false)
 T.eq(#S.nodes,nodes,"variable-height scrolling reuses the reached batch/member object high-water mark")
 T.eq(#create.batchPool,pool);T.ok(pool<=10,"one hundred applicant batches retain only a viewport-sized native pool")
 G.GetApplicant=get;G.applicants=saved;create:RefreshApplicants();create:SetBatchOffset(0,false)
end
A:SetSetting("reduceMotion",false);create.batchScroll:Fire("OnMouseWheel",-1);T.ok(U.Motion.jobs[create.batchScroll],"applicant wheel movement starts one finite animation");U.Motion:Tick(.2);T.eq(create.batchScroll:GetVerticalScroll(),56);T.eq(U.Motion.jobs[create.batchScroll],nil)
A:SetSetting("reduceMotion",true)
U:Hide();T.eq(native.Name:GetParent(),native,"hiding restores native protected title parent")
T.eq(U.Motion.jobs[create.batchScroll],nil,"leaving Create releases its scroll driver")
for id=72,84 do G.applicants[id]=nil end
T.eq(stockNameBorder:IsShown(),true);T.eq(stockNameBorder:GetAlpha(),.6,"release restores native border alpha and visibility")
T.eq(anonymousNameBorder:IsShown(),true);T.eq(anonymousNameBorder:GetAlpha(),.7);T.eq(anonymousDescriptionBorder:IsShown(),true,"release restores the skin's original border state")
A:Open("notes",{add={name="Guest",realm="Away",class="WARRIOR",specID=71,type="positive"}})
local notes=U.pages.notes
T.eq(notes.reminderState,nil);T.eq(notes.historyState,nil,"notes and history leave preference states in Settings")
T.eq(notes.left:GetWidth(),420);T.eq(notes.list.rowHeight,92,"note rows keep the name and reason in two compact lines")
T.eq(notes.search:GetWidth(),notes.list.rows[1]:GetWidth(),"notes search ends at the card edge before the scrollbar gutter")
local function AnchorX(region) local point={region:GetPoint()};return point[#point-1] end
T.eq(AnchorX(notes.listTitle),6,"notes heading keeps the shared header's text inset")
T.eq(AnchorX(notes.list.rows[1].icon),notes.noteHeader.columns.player.x+12,"note icons remain in the player column")
T.eq(notes.countText,nil,"the redundant total count is removed from the page heading")
T.eq(notes.actions:GetPoint(),"TOPRIGHT","note tools occupy the right side of the page heading")
T.eq(notes.findPerson,nil,"note details no longer create the removed find-group shortcut")
notes.eReason.box:SetText("A good teammate");notes:Save()
local note=A.Notes:Find("Guest-Away")
T.eq(note.type,"positive");T.eq(note.specID,71);T.eq(note.class,"WARRIOR")
do
 local row=notes.list.rows[1];notes.list.clip.mouseOver=true;U.Tooltip:Hide()
 row:Fire("OnEnter");T.eq(U.Tooltip.owner,nil,"a note's full row does not trigger its details")
 row.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.owner,nil,"the already selected note does not duplicate its open detail")
 local selected=notes.list.selectedKey;notes.list.selectedKey=nil;row.tooltipArea:Fire("OnEnter");notes.list.selectedKey=selected
 T.eq(U.Tooltip.owner,row,"an unselected note opens details from its left-quarter area")
 T.eq(row.tooltipArea:GetWidth(),row:GetWidth()*.25)
 U.Tooltip:Hide();notes.list.clip.mouseOver=nil
end
T.eq(notes.eAvatar:IsShown(),true);T.eq(notes.eRealm:GetText(),"Away");T.ok(notes.eDate:GetText():find("记录于",1,true),"saved note details show their recorded date");T.eq(notes.eSpec,nil,"the repeated recorded specialization line is removed")
do
 local button=notes.eDelete
 T.ok(button:GetWidth()-button.label:GetStringWidth()>=32,"the complete delete label has sixteen units of button padding on each side")
 T.eq(select(2,button.label:GetFont()),17,"delete keeps the normal shared button font")
 local cancelStart=notes.editor:GetWidth()-16-notes.eSave:GetWidth()-8-notes.eCancel:GetWidth()
 T.ok(cancelStart-(16+button:GetWidth())>=12,"the destructive action stays separate from Cancel and Save")
 button:Fire("OnEnter");T.same(button.label.color,U.Theme.accent,"the shared hover state makes the destructive action explicit")
 button:Fire("OnLeave");T.same(button.label.color,{unpack(U.Theme.muted)})
end
do
 local classLabel,specLabel=notes.classChoice.label:GetText(),notes.specChoice.label:GetText()
 local avatar,reason=notes.eAvatar:GetTexture(),notes.eReason.box:GetText()
 local getClass,getSpec,classReads,specReads=GetClassInfo,GetSpecializationInfoForClassID,0,0
 GetClassInfo=function(...) classReads=classReads+1;return getClass(...) end
 GetSpecializationInfoForClassID=function(...) specReads=specReads+1;return getSpec(...) end
 for i=1,20 do notes.typeButtons[i%2==0 and "caution" or "positive"]:Fire("OnClick") end
 GetClassInfo,GetSpecializationInfoForClassID=getClass,getSpec
 T.eq(classReads,0,"changing only note type does not reread the class directory")
 T.eq(specReads,0,"changing only note type does not reread the specialization directory")
 T.eq(notes.classChoice.label:GetText(),classLabel);T.eq(notes.specChoice.label:GetText(),specLabel)
 T.eq(notes.eAvatar:GetTexture(),avatar);T.eq(notes.eReason.box:GetText(),reason)
 T.eq(notes.typeButtons.caution.active,true);T.eq(notes.typeButtons.positive.active,false)
end
notes.typeButtons.caution:Fire("OnClick");notes.eReason.box:SetText("A different experience");notes:Save();T.eq(note.type,"caution")
T.eq(note.class,"WARRIOR");T.eq(note.specID,71,"saving the new type preserves the chosen specialization")
T.eq(notes.tabs.caution.count:GetText(),"1");T.eq(notes.tabs.positive.count:GetText(),"0","editing a type updates category counts before export or tab changes")
notes:DoExport();local transferred=assert(U.Transfer.Decode(notes.tBox.box:GetText()));T.eq(transferred[1].type,"caution");T.eq(transferred[1].specID,71)
notes:CloseTransfer()
do
 -- A historical text-only note and a new roster note must feed the same
 -- class/spec values to the icon, editor and saved record.
 A.Notes:Merge({{name="Legacy",server="Away",timestamp=1,reason="1213",classSpec="圣骑士-神圣",type="neutral"}})
 local legacy=A.Notes:Find("Legacy-Away")
 notes:OpenEdit("Legacy-Away")
 T.eq(notes.classChoice.value,"PALADIN");T.eq(notes.specChoice.value,66)
 T.ok(notes.eAvatar:GetTexture(),"historical class/spec text restores a visible specialization icon")
 T.eq(legacy.class,nil);T.eq(legacy.specID,nil,"viewing historical notes never rewrites the record")
 local legacyRow;for _,row in ipairs(notes.list.rows) do if row.key=="Legacy-Away" then legacyRow=row;break end end
 T.ok(legacyRow);T.ok(legacyRow.icon:GetTexture())
 T.eq(AnchorX(legacyRow.reason),AnchorX(legacyRow.title),"the note reason stays in the player's text column")
 T.eq(notes.eReason.box:GetText(),"1213")
 local base=f.base
 base.SetUnit("party1",{name="Observed",realm="Away",class="PALADIN",classID=2,guid="observed-note"})
 base.SetInspectSpec("party1",0)
 notes:OpenAdd({name="Observed",realm="Away",unit="party1"})
 T.eq(notes.classChoice.value,"PALADIN","the roster identity fills its known class immediately")
 notes.eReason.box:SetText("from the roster");notes:Save()
 base.SetInspectSpec("party1",66)
 for _,node in ipairs(S.nodes) do if node.events.INSPECT_READY then node:Fire("OnEvent","INSPECT_READY","observed-note") end end
 local observed=assert(A.Notes:Find("Observed-Away"))
 T.eq(observed.class,"PALADIN");T.eq(observed.specID,66)
 T.ok(observed.classSpec:find("神圣",1,true),"async inspection saves structured fields alongside the text")
 T.eq(notes.specChoice.value,66);T.eq(notes.eStatus:GetText(),U.L.saved)
 notes:OpenAdd({name="Observed",realm="Away",unit="party1"})
 T.eq(notes.specChoice.value,66,"the initial snapshot fills the specialization before Save")
 Pick(notes.specChoice,70);notes:Save()
 T.eq(A.Notes:Find("Observed-Away").specID,70,"an explicit specialization selection takes priority over the snapshot")
 A.Notes:Remove("Observed-Away");base.SetInspectSpec("party1",0)
 notes:OpenAdd({name="Observed",realm="Away",unit="party1"})
 notes.eReason.box:SetText("Before pending edit");notes:Save()
 notes.eName.box:SetText("Corrected-Away");notes.eReason.box:SetText("After pending edit")
 base.SetInspectSpec("party1",66);base.FireEvent("INSPECT_READY","observed-note");base.AdvanceClock(5)
 T.eq(A.Notes:Find("Observed-Away"),nil,"editing the pending identity cancels the old save before its callback")
 T.eq(A.Notes:Find("Corrected-Away"),nil,"typing a correction does not implicitly save it")
 T.eq(notes.eName.box:GetText(),"Corrected-Away");T.eq(notes.eReason.box:GetText(),"After pending edit")
 T.eq(notes.eStatus:GetText(),"","editing clears the obsolete inspection status")
 notes:Save();T.eq(A.Notes:Find("Corrected-Away").reason,"After pending edit","the next save uses the corrected identity and reason")
 A.Notes:Remove("Corrected-Away")
 local edits={
  function() notes.eReason.box:SetText("Revised while inspecting") end,
  function() Pick(notes.classChoice,"WARRIOR") end,
  function() Pick(notes.specChoice,70) end,
  function() notes.typeButtons.caution:Fire("OnClick") end,
 }
 for _,edit in ipairs(edits) do
  base.SetInspectSpec("party1",0);notes:OpenAdd({name="Observed",realm="Away",unit="party1"})
  notes.eReason.box:SetText("Original pending value");notes:Save();edit()
  base.SetInspectSpec("party1",66);base.FireEvent("INSPECT_READY","observed-note");base.AdvanceClock(5)
  T.eq(A.Notes:Find("Observed-Away"),nil,"every editable save field invalidates the pending snapshot")
  notes:Save();T.ok(A.Notes:Find("Observed-Away"),"a corrected draft remains saveable")
  A.Notes:Remove("Observed-Away")
 end
 A.Notes:Remove("Legacy-Away");A.Notes:Remove("Observed-Away");base.SetUnit("party1",nil)
 notes:OpenEdit("Guest-Away")
end
notes:SelectTab("positive");T.eq(#notes.list.ids,0,"note type filtering follows edits")
notes:SelectTab("history");T.eq(notes.historyFrame:IsShown(),true);T.eq(notes.toolbar:IsShown(),false)
do
 local list,setItems=A.Notes.List,notes.list.SetItems;local reads,renders=0,0
 local saved={type=note.type,class=note.class,specID=note.specID,classSpec=note.classSpec};local savedReason=note.reason
 A.Notes.List=function(...) reads=reads+1;return list(...) end
 notes.list.SetItems=function(self,ids,render) return setItems(self,ids,function(...) renders=renders+1;return render(...) end) end
 A:Open("notes");T.eq(reads,0,"reentering history does not build the hidden player-note list")
 T.eq(notes.historyFrame:IsShown(),true)
 A.Notes:Edit("Guest-Away","edited while viewing history",{type="positive"})
 T.eq(reads,0,"record edits while viewing history do not derive a hidden note list")
 T.eq(renders,0,"record edits while viewing history do not render hidden note rows")
 T.eq(notes.tabs.positive.count:GetText(),"1","visible category counts still follow edits on the history tab")
 notes:SelectTab("all");reads=0;renders=0
 A:Open("notes");T.eq(reads,1,"reentering player notes generates its ordered list once")
 T.eq(renders,1,"reentering notes binds each visible record only once")
 T.eq(notes.left:IsShown(),true);T.ok(notes.list.ids and #notes.list.ids>0)
 renders=0;A.Notes:Edit("Guest-Away","updated selected record")
 T.eq(renders,1,"editing the selected record refreshes only that row")
 T.eq(notes.eReason.box:GetText(),"updated selected record","the current editor still follows the saved record")
 local refreshCounts,counts=notes.RefreshCounts,0
 notes.RefreshCounts=function(self) counts=counts+1;return refreshCounts(self) end
 notes.search.box:SetText("no matching note");notes:OnSearchChanged()
 T.eq(#notes.list.ids,0);T.eq(notes.tabs.all.count:GetText(),"1","search filters the displayed list without changing total category counts")
 notes.search.box:SetText("");notes:OnSearchChanged();T.eq(counts,0,"search input does not rescan category totals")
 notes.RefreshCounts=refreshCounts
 renders=0;notes:OpenEdit("Guest-Away");T.eq(renders,0,"opening the same selected record does not rebind the list")
 A.Notes:Edit("Guest-Away",savedReason,saved);renders=0
 notes:Leave();T.eq(renders,0,"leaving the page clears rows without a final hidden render")
 notes:Enter();notes:SelectTab("history");A.Notes.List=list;notes.list.SetItems=setItems
end
U:Hide();T.eq(next(G.views),nil,"hidden pages release Group browsing ownership")
T.eq(notes.runs,nil,"history references release on close")
local chosen
local list=U.C.List(U.frame,200,46,46,function(key) chosen=key end);list:SetItems({"A","B","C","D","E"},function() end)
local row=list.rows[1];row:Fire("OnMouseDown");list:SetPixelOffset(46,false);row:Fire("OnClick","LeftButton");T.eq(chosen,nil,"rebound rows reject an earlier mouse press")
list:SetHeight(45.99998474121);list:SetItems({"A"},function() end)
T.eq(list.slider:IsShown(),false,"native float rounding does not add a scrollbar to a full viewport")

-- Catalog-backed browsing, pinned applications and interactive shared tooltips.
G:RemoveListing()
A:Open("create");T.eq(create.crossFaction.value,true,"a new listing after an ended same-faction listing restores the cross-faction default");U:Hide(true)
local now=100
GetTime=function() return now end
GetCurrentRegion=function() return 5 end
MouseIsOver=nil -- Retail exposes the region method rather than this retired global.
function G.Applications:IsActive(id) local app=G:GetApplication(id);return app and (app.status=="applied" or app.status=="invited") or false end
local activity=G.Catalog:GetActivity(2)
local members={{name="Guest-Away",nameKey="Guest-Away",class="WARRIOR",specID=71,assignedRole="TANK",dungeonScore=2450,itemLevel=270}}
for i=1,35 do G.records[100+i]={id=100+i,activity=activity,activityID=2,categoryID=2,name="Search group "..i,leaderName="Guest-Away",leaderKey="Guest-Away",activityName=activity.name,numMembers=1,maxNumPlayers=5,age=i,requiredItemLevel=250,leaderOverallDungeonScore=2450,leaderRating=2450,details={members=members,counts={TANK=1,HEALER=0,DAMAGER=0}}} end
G.apps={{id=101,name="Pinned application",status="applied",categoryID=2,expiresAt=now+300,result=G.records[101],leaderName="Guest-Away"}}
do
 local box=LFGListFrame.SearchPanel.SearchBox
 local parent=box:GetParent();local point={box:GetPoint()};local font={box:GetFont()};local color={box:GetTextColor()};local insets={box:GetTextInsets()}
 local events={"OnTextChanged","OnEnterPressed","OnEscapePressed","OnTabPressed","OnArrowPressed","OnEditFocusGained","OnEditFocusLost","OnEnter","OnLeave","OnHide","OnShow"}
 local scripts={};for _,event in ipairs(events) do scripts[event]=box:GetScript(event) end
 box:UserType("Old native activity token")
 local remember=A.charPrefs.rememberFilters;A:SetSetting("rememberFilters",true)
 G.prefs.find={filters={text="Old saved local query",minLevel=12,maxLevel=99,tankPresence="present",healerPresence="missing",needsDamage=true,hideZeroScore=true}}
 local combat=InCombatLockdown;_G.InCombatLockdown=function() return true end
 T.eq(A:Open("find"),true,"Find first opens during combat without protected mouse propagation")
 local page=U.pages.find
 T.eq(A:GetSetting("showImportantFilters"),false);T.eq(page.quickPlacement,"popup","important filters default to the popup")
 T.eq(page.quickFilters:GetParent(),page.importantFilters)
 T.near(page.search:GetWidth(),page.main:GetWidth()-60,.001,"the search field uses the complete row")
 A:SetSetting("showImportantFilters",true)
 T.eq(G.filters.tankPresence,"present");T.eq(G.filters.healerPresence,"missing");T.eq(G.filters.damagePresence,"missing","first entry migrates the saved damage requirement alongside the other role-presence fields")
 T.eq(G.filters.needsDamage,nil);T.eq(G.prefs.find.filters.needsDamage,nil,"migration removes the retired damage field")
 T.eq(page.quickChoices.tankPresence.button.label:GetText(),"已有");T.eq(page.quickChoices.healerPresence.button.label:GetText(),"缺少");T.eq(page.quickChoices.damagePresence.button.label:GetText(),"缺少")
 T.eq(page.hideZeroScore.value,true);T.eq(G.filters.hideZeroScore,true,"the saved seasonal score filter is restored on first entry")
 T.eq(page.filterCount,4);T.eq(page.filterToggle.label:GetText(),"筛选 4","restored conditions remain visible while the panel is closed")
 T.eq(page.clearFilters:IsEnabled(),true)
 page:ClearFilters();T.eq(G.filters.tankPresence,nil);T.eq(G.filters.healerPresence,nil);T.eq(G.filters.damagePresence,nil)
 T.eq(G.filters.hideZeroScore,nil);T.eq(page.hideZeroScore.value,false,"clear filters resets the score switch")
 T.eq(page.filterCount,0);T.eq(page.filterStatus:GetText(),"0 项条件 · 待搜索");T.eq(page.clearFilters:IsEnabled(),false,"reset is unavailable when the filters and sort are already at their defaults")
 T.eq(page.picker,nil,"Find keeps the activity popup unbuilt while only results are open")
 T.eq(page.main.keyboardEnabled,nil,"first combat build does not change restricted keyboard propagation")
 T.eq(page.main.events.PLAYER_REGEN_ENABLED,true)
 _G.InCombatLockdown=combat;page.main:Fire("OnEvent","PLAYER_REGEN_ENABLED")
 T.eq(page.main.keyboardEnabled,true);T.eq(page.main.keyboardPropagation,true)
 T.eq(page.main.events.PLAYER_REGEN_ENABLED,nil,"shortcut setup releases its one-time event")
 T.eq(page.emptyText:GetText(),"请选择副本","opening Find waits for an explicit instance selection")
 page:SelectCategory("seasonDungeon");page.activities.rows[1]:Fire("OnClick","LeftButton")
 T.eq(page.search.box,box,"group mode starts with the registered native input")
 T.eq(page.searchHint:GetText(),"队伍标题或钥石范围，如 12-15")
 T.eq(page.searchModeToggle.label:GetText(),"标题","title is the default search mode label")
 T.eq(page.searchModeToggle:IsShown(),true)
 box:UserType("灵止光")
 page.searchModeToggle:Fire("OnClick")
 T.eq(page.search.box,page.previewSearchBox,"leader mode uses an ordinary input")
 T.eq(page.search.box:GetText(),"灵止光","switching from title to leader carries the existing query")
 T.eq(U.Native.searchLease,nil);T.eq(box:GetParent(),parent)
 T.eq(page.searchHint:GetText(),"队长名字，可带服务器")
 T.eq(G.filters.leaderText,"灵止光");T.eq(G.filters.text,nil)
 T.eq(G.leaderText,"灵止光","switching modes immediately searches the carried query")
 page.search.box:Fire("OnEnterPressed");T.eq(G.leaderText,"灵止光");T.eq(G.searchMode,"leader");T.eq(G.searchText,"","leader text never enters the native name filter")
 page:SelectCategory("seasonDungeon");T.eq(page.search.box,page.previewSearchBox);T.eq(page.search.box:GetText(),"灵止光","same-category refresh keeps the leader query")
 local picker=page.picker;T.ok(picker:IsShown(),"selecting a category creates its complete activity popup")
 page:ClosePicker();page:SelectCategory("seasonDungeon");T.eq(page.picker,picker,"Find reuses its popup on later expansions")
 page:SetSearchMode("group")
 T.eq(page.search.box,box,"the production search pill leases the engine's registered input")
 T.eq(box:GetParent(),page.search);T.eq(U.Native.searchLease.box,box)
 T.eq(page.previewSearchBox:IsShown(),false);T.eq(box.nativeBackground:IsShown(),false)
 T.eq(box.Instructions:GetAlpha(),0);T.eq(box.clearButton:IsShown(),false,"stock search decorations do not overlap the shared pill")
 T.eq(box:GetText(),"");T.ok(G.searchClears>0,"leader search and first native lease discard stale native activity tokens")
 T.eq(page.searchHint:GetText(),"队伍标题或钥石范围，如 12-15")
 T.eq(page.fMinLevel,nil);T.eq(page.fMaxLevel,nil,"unsupported local level range inputs are not created")
 T.ok(76+page.filterPanel:GetHeight()<=U.frame:GetHeight(),"the internal seasonal overlay fits below its top inset");T.eq(page.filterPanel:GetWidth(),460)
 local revision=U.Native.searchLease.revision
 box:UserType("12-15");T.eq(U.Native.searchLease.revision,revision+1,"each native edit distinguishes a newer query without parsing it")
 T.eq(G.filters.text,nil);T.eq(G.filters.leaderText,nil);T.eq(G.filters.minLevel,nil);T.eq(G.filters.maxLevel,nil,"native range text is never copied into local result filters")
 T.eq(G.prefs.find.filters.text,nil,"protected search text is not saved for a forbidden SetText restore")
 box:SetFocus();T.eq(page.search.focused,true);box:Fire("OnEnterPressed")
 T.eq(G.searchText,"12-15","Enter submits the text already owned by the native input")
 page.search:Fire("OnMouseDown","LeftButton");box:Fire("OnTextChanged",false)
 T.eq(box:GetText(),"12-15","refocusing and native refresh notifications retain the submitted query")
 box:UserType("12-16");box:Fire("OnEnterPressed");T.eq(G.searchText,"12-16","the existing query can be edited and searched again")
 box:UserType("12-15")
 page:SelectCategory("seasonDungeon");T.eq(box:GetText(),"12-15","searches within the category preserve the player's native query")
 page.fMembers.box:SetText("5")
 page.hideZeroScore:Fire("OnClick");T.eq(G.prefs.find.categoryPrefs.seasonDungeon.hideZeroScore,true)
 page.fMinMembers.box:SetText("1");T.eq(page.filterCount,2,"the two player bounds count as one range condition alongside the score switch")
 page.fMinMembers.box:SetText("");T.eq(page.filterToggle.label:GetText(),"筛选 2")
 page:SelectCategory("seasonRaid");T.eq(box:GetText(),"","switching category clears incompatible native text and activity tokens")
 T.eq(page.hideZeroScore:IsShown(),false);T.eq(G.filters.hideZeroScore,nil,"the seasonal score filter does not affect other categories")
 T.eq(page.filterCount,0);T.ok(not page.importantFilters:IsShown() and not page.roleChoice:IsShown(),"categories without role conditions omit those controls")
 T.eq(page.searchHint:GetText(),"队伍标题","raid search returns to title mode without a key-range hint")
 T.eq(page.searchModeToggle:IsShown(),true);T.eq(page.search.box,box)
 T.eq(G.filters.maxMembers,nil,"a category without saved conditions does not inherit the dungeon member limit")
 page.activities.rows[1]:Fire("OnClick","LeftButton")
 page.search.box:UserType("Heroic");page.refresh:Fire("OnClick");T.eq(G.searchMode,"group");T.eq(G.searchText,"Heroic")
 page.searchClear:Fire("OnClick");T.eq(page.search.box:GetText(),"");T.eq(G.searchText,"")
 page:SelectCategory("seasonDungeon")
 T.eq(page.hideZeroScore:IsShown(),true);T.eq(page.hideZeroScore.value,true);T.eq(G.filters.hideZeroScore,true,"returning to seasonal dungeons restores the score preference")
 T.eq(page.filterCount,2,"the summary follows the restored category conditions")
 page.hideZeroScore:Fire("OnClick")
 page.activities.rows[1]:Fire("OnClick","LeftButton")
 local clears=G.searchClears
 box:UserType("12-15");box:SetFocus();U:Hide(true)
 T.eq(U.Native.searchLease,nil);T.eq(box:GetParent(),parent)
 local restoredPoint={box:GetPoint()};for index,value in ipairs(point) do T.eq(restoredPoint[index],value,"native search anchor restored") end
 T.same({box:GetFont()},font);T.same({box:GetTextColor()},color);T.same({box:GetTextInsets()},insets)
 for _,event in ipairs(events) do T.eq(box:GetScript(event),scripts[event],"native search script restored: "..event) end
 T.eq(box.nativeBackground:IsShown(),true);T.eq(box.Instructions:GetAlpha(),1);T.eq(box.clearButton:IsShown(),true)
 T.eq(box:GetText(),"12-15","closing returns the native input without clearing the player's text")
 A:Open("find");T.eq(page.search.box,box);T.eq(box:GetText(),"12-15");T.eq(G.searchClears,clears,"reopening reuses the native text instead of writing SavedVariables into it")
 local bound=0;for _,input in ipairs(U.inputs) do if input==box then bound=bound+1 end end;T.eq(bound,1,"the leased input has one focus-registry entry")
 box:Fire("OnTextChanged",false)
 T.eq(box:GetText(),"12-15","a non-user notification does not erase text while the lease still owns the input")
 -- MeetingStone moves this same registered box on show. Our lease record alone
 -- is not proof that the input is still in the Lychee search field.
 local foreign=CreateFrame("Frame",nil,UIParent)
 local foreignEnter=function() end
 local foreignChanges=0
 local foreignChanged=function() foreignChanges=foreignChanges+1 end
 box:SetParent(foreign);box:ClearAllPoints();box:SetPoint("LEFT",foreign,"LEFT",20,0);box:SetWidth(220)
 T.eq(U.Native.searchLease,nil,"MeetingStone's reparent-and-resize releases the input before typing or focus")
 T.same({box:GetFont()},font,"the other browser receives the original font immediately")
 T.same({box:GetTextColor()},color);T.same({box:GetTextInsets()},insets)
 T.eq(box.nativeBackground:IsShown(),true,"the other browser receives its original input background immediately")
 T.eq(box:GetWidth(),220,"giving up the input preserves the new browser's width")
 T.eq(box:GetScript("OnEnterPressed"),scripts.OnEnterPressed,"giving up the input restores the previous browser's handler")
 box:SetScript("OnEnterPressed",foreignEnter);box:SetScript("OnTextChanged",foreignChanged);box:UserType("Other dungeon activity")
 page.search:Fire("OnMouseDown","LeftButton")
 T.eq(box:GetParent(),page.search,"clicking the visible search field recovers the registered input")
 T.eq(box:HasFocus(),true);T.eq(box:GetText(),"","a reclaimed input discards the other browser's stale query")
 box:UserType("Raid search");box:Fire("OnEnterPressed");T.eq(G.searchText,"Raid search","reclaimed Enter uses the Lychee search controller")
 bound=0;for _,input in ipairs(U.inputs) do if input==box then bound=bound+1 end end;T.eq(bound,1,"reclaim does not duplicate the input registry")
 U:Hide(true);T.eq(box:GetParent(),foreign);T.eq(box:GetScript("OnEnterPressed"),foreignEnter,"closing returns the input to its latest previous owner")
 A:Open("find");box:SetParent(foreign)
 local beforeForeignChange=foreignChanges
 box.text="External query";box:Fire("OnTextChanged",false)
 T.eq(box:GetText(),"External query","input owned by another browser is not cleared by our handler")
 T.eq(foreignChanges,beforeForeignChange+1,"the previous browser receives its text event after taking the input")
 T.eq(U.Native.searchLease,nil);T.eq(page.previewSearchBox:IsShown(),false,"a lost real input is not replaced by an ineffective ordinary edit")
 page.search:Fire("OnMouseDown","LeftButton")
 T.eq(box:GetParent(),page.search);T.eq(box:GetText(),"","returning from the other browser clears its query")
 box:UserType("12-15");T.eq(box:GetText(),"12-15","hardware text remains accepted after the handoff")
 U:Hide(true)
 A:Open("find");box:SetParent(foreign);box:SetScript("OnEnterPressed",foreignEnter)
 U:Hide(true);T.eq(box:GetParent(),foreign);T.eq(box:GetScript("OnEnterPressed"),foreignEnter,"closing after another UI takes the input does not overwrite its layout or handler")
 box:SetParent(parent);box:ClearAllPoints();box:SetPoint(unpack(point));for _,event in ipairs(events) do box:SetScript(event,scripts[event]) end
 A:Open("find")
 page:SetSearchMode("leader");T.eq(page.search.box,page.previewSearchBox);T.eq(U.Native.searchLease,nil)
 page.searchClear:Fire("OnClick")
 A:SetSetting("rememberFilters",remember)
end
A:Open("find")
local find=U.pages.find
do
 local getResults,previousState,previousError,inputError=G.GetResults,G.state,G.error,find.searchError
 local resultIDs=getResults(G)
 G.GetResults=function() return {} end;find.searchError=nil
 G.state="waiting";G.error="Retry in 5 seconds";G:Notify("results");G:Notify("search")
 T.eq(find.emptyHelp:GetText(),G.error,"the empty state explains the pending retry")
 T.eq(find.statusText:GetText(),"","the search notice does not repeat the visible retry explanation")
 G.error="Retry in 4 seconds";G:Notify("search")
 T.eq(find.emptyHelp:GetText(),G.error,"retry countdown updates still reach the empty state")
 T.eq(find.statusText:GetText(),"","countdown updates do not reintroduce duplicate search text")
 G.state="failed";G.error="Search failed";G:Notify("search")
 T.eq(find.emptyHelp:GetText(),G.error,"the empty state explains the search failure")
 T.eq(find.statusText:GetText(),"","the search notice does not repeat the visible failure explanation")
 find.searchError="Search input unavailable";G:Notify("search")
 T.eq(find.statusText:GetText(),find.searchError,"a distinct input error remains visible")
 find.searchError=nil;G.GetResults=function() return resultIDs end
 G.state="waiting";G.error="Retry in 3 seconds";G:Notify("results");G:Notify("search")
 T.eq(find.emptyPanel:IsShown(),false,"existing results keep the central empty state hidden")
 T.eq(find.statusText:GetText(),G.error,"results retain the pending retry beside the search results")
 G.state="failed";G.error="Search failed again";G:Notify("search")
 T.eq(find.statusText:GetText(),G.error,"results retain search failures beside the search results")
 T.ok(find.limitNotice:IsShown(),"search failures reuse the shared notice")
 local noticePoint={find.limitNotice:GetPoint()};local resultsPoint={find.results:GetPoint()}
 T.eq(noticePoint[#noticePoint-1],0,"the notice aligns with the result body's left edge")
 T.ok(noticePoint[#noticePoint]-find.limitNotice:GetHeight()>resultsPoint[#resultsPoint],"the notice ends above the result viewport")
 find.closeApplicationNotice:Fire("OnClick");find:ReadSearchState();T.eq(find.limitNotice:IsShown(),false,"passive state reads do not reopen a dismissed notice")
 G.GetResults=getResults;G.state=previousState;G.error=previousError;find.searchError=inputError;find:RefreshResults()
end
find:SetSidebarCollapsed(false,false)
T.eq(find.rail:GetWidth(),208);T.near(find.main:GetWidth(),U.content:GetWidth()-208-U.Theme.contentGap-U.Theme.findContentInset*2,.001)
T.eq(find.filterPanel:GetWidth(),460);T.near(find.results.rowHeight,53,.001)
T.eq(find.seasonCategories.rows[1]:GetHeight(),48,"the activity sidebar keeps its original compact row height")
do
 local countPoint={find.resultCount:GetPoint()}
 T.eq(countPoint[1],"RIGHT");T.eq(countPoint[2],find.main);T.eq(countPoint[3],"TOPRIGHT");T.eq(countPoint[4],-16)
 T.eq(find.resultCount.justify,"RIGHT","the result count aligns with the result body's right text edge")
 local headerPoint={find.resultsHeader:GetPoint()};local contextPoint={find.context:GetPoint()}
 T.eq(contextPoint[#contextPoint]-headerPoint[#headerPoint],find.context:GetHeight()+16,"the column headings follow the complete context line with the sixteen-unit gap")
 T.eq(select(2,find.context:GetFont()),23);T.eq(find.context:GetHeight(),32)
end
do
 local getTiers,getTierInfo=G.Catalog.GetTiers,EJ_GetTierInfo
 local names={[9]="巨龙时代",[10]="地心之战",[11]="至暗之夜"}
 G.Catalog.GetTiers=function() return {{id=9,name=names[9]},{id=10,name=names[10]},{id=11,name=names[11]}} end
 EJ_GetTierInfo=function(id) return names[id] end
 find:SelectCategory("3")
 for _,tier in ipairs({9,10,11}) do
  find.tierChoice:Fire("OnClick")
  local menu=U.context.menu;menu.mouseOver=true
  find.picker:Fire("OnEvent","GLOBAL_MOUSE_DOWN")
  T.eq(find.picker:IsShown(),true,"clicking the expansion submenu outside its parent popup keeps the parent open")
  local chosen;for i,item in ipairs(menu.items) do if item.value==tier then chosen=menu.list.rows[i];break end end
  chosen:Fire("OnClick","LeftButton")
  T.eq(find.tierChoice.value,tier);T.eq(find.tierChoice.label:GetText(),names[tier])
  T.eq(G.filters.tier,tier,"the expansion menu applies the chosen tier to the search")
  menu.mouseOver=nil
 end
 local catalog=G.Catalog
 local getCategories,getGroups,getActivities,getActivityTier=catalog.GetCategories,catalog.GetGroups,catalog.GetActivities,catalog.GetActivityTier
 local categories={};for _,cat in ipairs(getCategories(catalog)) do categories[#categories+1]=cat end;categories[#categories+1]={key="121",id=121,name="Delves",icon="delve"}
 local delveGroups={
  {key=501,name="TWW Delve",tier=10,activity={id=501,groupKey=501,categoryID=121,maxNumPlayers=5,fixtureTier=10}},
  {key=502,name="Midnight Delve",tier=11,activity={id=502,groupKey=502,categoryID=121,maxNumPlayers=5,fixtureTier=11}},
  {key=503,name="Unmapped Delve",activity={id=503,groupKey=503,categoryID=121,maxNumPlayers=5}},
 }
 catalog.GetCategories=function() return categories end
 catalog.GetGroups=function(self,key) if key=="121" then return delveGroups end;return getGroups(self,key) end
 catalog.GetActivities=function(self,key) if key=="121" then return {delveGroups[1].activity,delveGroups[2].activity,delveGroups[3].activity} end;return getActivities(self,key) end
 catalog.GetActivityTier=function(self,activity) if activity.categoryID==121 then return activity.fixtureTier end;return getActivityTier(self,activity) end
 find:SelectCategory("121");T.eq(find.tierChoice:IsShown(),true,"Delves expose their expansion selector")
 find.tierChoice:Fire("OnClick");local items=U.context.menu.items
 T.eq(#items,3);T.eq(items[1].value,false);T.eq(items[2].value,10);T.eq(items[3].value,11,"Delves only list expansions present in their own activity groups")
 U:CloseMenu();Pick(find.tierChoice,10);T.eq(G.filters.tier,10);T.same(find.activityIDs,{0,501})
 find.activities.rows[2]:Fire("OnClick","LeftButton");T.eq(G.filters.groupKey,501)
 find:SelectCategory("121")
 Pick(find.tierChoice,11);T.eq(G.filters.tier,11);T.eq(G.filters.groupKey,nil,"changing expansion resets the old selected Delve");T.eq(G.filters.difficultyID,nil);T.same(find.activityIDs,{0,502})
 Pick(find.tierChoice,false);T.eq(G.filters.tier,nil);T.same(find.activityIDs,{0,501,502,503},"all expansions retain unmapped native Delves")
 find:SelectCategory("3")
 catalog.GetCategories,catalog.GetGroups,catalog.GetActivities,catalog.GetActivityTier=getCategories,getGroups,getActivities,getActivityTier
 G.Catalog.GetTiers=getTiers;EJ_GetTierInfo=getTierInfo
end
find:SelectCategory("seasonRaid")
for _,button in ipairs(find.difficultyButtons) do if button.value==14 and button:IsShown() then button:Fire("OnClick") end end
local raidActivity=G.Catalog:GetActivity(1);local raidDifficulty=raidActivity.difficultyID
raidActivity.difficultyID=nil;find:RefreshPicker();find:UpdateFilters()
T.eq(find.difficultySurface:IsShown(),false,"an All-only difficulty selector is hidden")
T.eq(G.filters.difficultyID,nil,"hiding the difficulty selector clears stale difficulty filters")
local activityListPoint={find.activities:GetPoint()};T.eq(activityListPoint[#activityListPoint],-64,"activities move up when the difficulty row is absent")
raidActivity.difficultyID=raidDifficulty;find:RefreshPicker();find:UpdateFilters()
local difficultyWidth,count=0,0
for _,button in ipairs(find.difficultyButtons) do if button:IsShown() then difficultyWidth=difficultyWidth+button:GetWidth();count=count+1;T.ok(button:GetWidth()>=button.textWidth+20,"difficulty labels retain their full natural width") end end
T.near(difficultyWidth+math.max(0,count-1)*4+6,find.difficultySurface:GetWidth(),.001,"difficulty buttons fill the available row without a trailing empty strip")
local membersAnchor={find.fMembers:GetPoint()}
local minimumAnchor={find.fMinMembers:GetPoint()}
T.eq(membersAnchor[#membersAnchor],minimumAnchor[#minimumAnchor],"member bounds share one compact range row")
T.ok(find.fMembers.placeholder and find.fMembers.placeholder:IsShown(),"an empty maximum input visibly names its range endpoint")
T.eq(find.fMembers.increase,nil,"numeric filters have no stepper arrows")
find.activities.rows[1]:Fire("OnClick","LeftButton")
do
 local getResults=G.GetResults;local reads=0
 G.GetResults=function(self) reads=reads+1;return getResults(self) end
 find.fMembers.box:SetText("1")
 T.eq(reads,1,"one filter change refreshes the result list once through the service notification")
 G.GetResults=getResults
end
T.eq(G.filters.maxMembers,1,"direct numeric input immediately updates real filter state");T.eq(find.fMembers.placeholder:IsShown(),false)
find.fMembers.box:SetText("");T.eq(G.filters.maxMembers,nil);T.eq(find.fMembers.placeholder:IsShown(),true)
local rememberBounds=A.charPrefs.rememberFilters;A:SetSetting("rememberFilters",true)
find.fMembers.box:SetText("4");find.fMinMembers.box:SetText("2")
T.eq(G.filters.minMembers,2);T.eq(G.filters.maxMembers,4,"minimum input never overwrites the maximum")
find.fMinMembers.box:SetText("3");T.eq(G.filters.maxMembers,4)
find:SelectCategory("seasonDungeon");T.eq(G.filters.minMembers,nil,"a category without a minimum stays unrestricted")
find:SelectCategory("seasonRaid");T.eq(G.filters.minMembers,3);T.eq(G.filters.maxMembers,4,"both bounds restore with their category")
find:ClearFilters();T.eq(G.filters.minMembers,nil);T.eq(G.filters.maxMembers,nil)
do
 local wasOpen=find.filtersOpen;find:SetFiltersOpen(true)
 local sortKey,descending=find.resultsHeader.state.sortKey,find.resultsHeader.state.descending
 find.resultsHeader:SetSort("members",true);find:OnHeaderSort()
 T.eq(find.sortChoice,nil);T.eq(find.filterCount,0);T.ok(find.filterStatus:GetText():find("0 项条件 · ",1,true));T.eq(find.clearFilters:IsEnabled(),false,"sorting alone is independent of filter reset")
 find.fMinMembers.box:UserType("2");T.eq(find.clearFilters:IsEnabled(),true)
 find.clearFilters:Fire("OnClick")
 T.eq(G.filters.minMembers,nil);T.eq(find.resultsHeader.state.sortKey,"members");T.eq(find.resultsHeader.state.descending,true,"reset preserves header sorting")
 T.eq(find.clearFilters:IsEnabled(),false,"reset clears only local filters")
 find.resultsHeader:SetSort(sortKey,descending,true);find:OnHeaderSort()
 find:SetFiltersOpen(wasOpen)
end
do
 find:SelectCategory("seasonDungeon")
 local filtersOpen=find.filtersOpen;find:SetFiltersOpen(true)
 local choices=find.quickChoices
 local keys={TANK="tankPresence",HEALER="healerPresence",DAMAGER="damagePresence"}
 local function Choose(role,value)
  local button=choices[keys[role]].button;button:Fire("OnClick","RightButton")
  if value then button:Fire("OnClick","LeftButton");if value=="present" then button:Fire("OnClick","LeftButton") end end
 end
 T.eq(find.quickFilters:IsShown(),true);T.eq(find.roleChoice:IsShown(),false,"seasonal dungeons use the compact role controls")
 for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do Choose(role,nil);T.eq(choices[keys[role]].button.label:GetText(),"不限") end
 local tank=choices.tankPresence.button
 tank:Fire("OnClick","LeftButton");T.eq(G.filters.tankPresence,"missing");T.eq(tank.active,true)
 tank:Fire("OnClick","LeftButton");T.eq(G.filters.tankPresence,"present");T.eq(tank.label:GetText(),"已有")
 tank:Fire("OnClick","LeftButton");T.eq(G.filters.tankPresence,nil);T.eq(tank.active,false,"the three-state cycle returns to unrestricted")
 Choose("DAMAGER","present");T.eq(G.filters.damagePresence,"present");T.eq(choices.damagePresence.button.label:GetText(),"已齐")
 Choose("DAMAGER",nil);T.eq(G.filters.damagePresence,nil,"right click explicitly clears one role")
 Choose("TANK","missing");Choose("HEALER","present");Choose("DAMAGER","missing")
 T.eq(G.filters.tankPresence,"missing");T.eq(G.filters.healerPresence,"present");T.eq(G.filters.damagePresence,"missing","independent role fields combine in the result filter")
 Choose("TANK","present");Choose("DAMAGER","present")
 T.eq(G.filters.damagePresence,nil,"AND keeps the existing maximum of two present-role conditions")
 find.quickLogic:Fire("OnClick");Choose("DAMAGER","present")
 T.eq(G.filters.roleMatchAny,true);T.eq(G.filters.damagePresence,"present","OR allows all three present-role conditions")
 find.quickLogic:Fire("OnClick");T.eq(G.filters.roleMatchAny,nil);T.eq(G.filters.damagePresence,nil,"returning to AND removes the third present-role condition")
 find:SelectCategory("seasonRaid")
 T.eq(find.quickFilters:IsShown(),false);T.eq(G.filters.tankPresence,nil);T.eq(G.filters.healerPresence,nil);T.eq(G.filters.damagePresence,nil,"seasonal conditions do not leak to raids")
 find:SelectCategory("seasonDungeon");find:ClearFilters()
end
A:SetSetting("rememberFilters",rememberBounds)
T.eq(find.filterToggle.label:GetText(),"筛选","the filter arrow is texture art rather than an unsupported font glyph")
T.eq(find.seasonCategories.indicator:IsShown(),true,"category selection shares one moving tonal background and vertical marker")
T.eq(find.seasonCategories.indicator.mark:IsShown(),true)
T.eq(find.seasonCategories.indicator:GetWidth(),find.seasonCategories.rows[1]:GetWidth())


find:SelectCategory("seasonDungeon")
local activityRow=find.activities.rows[2]
activityRow:Fire("OnMouseDown");activityRow:Fire("OnClick","LeftButton")
for _,button in ipairs(find.difficultyButtons) do if button.value==1 and button:IsShown() then button:Fire("OnClick") end end
T.eq(find.searchHint:GetText(),"队伍标题","normal dungeon search uses the native title query")
T.eq(find.quickFilters:IsShown(),true,"seasonal role choices also work at normal difficulty")
find.quickChoices.tankPresence.button:Fire("OnClick","LeftButton");find.quickChoices.tankPresence.button:Fire("OnClick","LeftButton");T.eq(G.filters.tankPresence,"present");T.eq(G.filters.neededRole,nil)
find.quickChoices.tankPresence.button:Fire("OnClick","RightButton")
T.eq(G.filters.tankPresence,nil,"right click clears the seasonal condition at normal difficulty")
local searchMethod=G.Search.Search;local requestedActivity
G.Search.Search=function(_,category,id) requestedActivity=id;return true end
activityRow:Fire("OnClick","LeftButton");T.same(requestedActivity,{3},"confirming a seasonal map and normal difficulty requests its unique native activity")
for _,button in ipairs(find.difficultyButtons) do if button.value==false and button:IsShown() then button:Fire("OnClick") end end
T.eq(find.searchHint:GetText(),"队伍标题或钥石范围，如 12-15");T.eq(find.searchModeToggle:IsShown(),true,"title and leader modes remain available with Mythic+ selected")
activityRow:Fire("OnClick","LeftButton");T.same(requestedActivity,{2,3},"confirming all difficulties requests every valid native activity for the selected dungeon")
G.Search.Search=searchMethod
find:SetFiltersOpen(true);Pick(find.socialChoice,"noCaution")
T.eq(find.socialChoice.label:GetText(),"不含拉黑记录");T.eq(G.filters.notes,"noCaution","the note choice requests exclusion rather than blocked-only results")
Pick(find.socialChoice,false);find:SetFiltersOpen(false)
do
 local catalog=G.Catalog
 local getActivities,getGroups,getTier,getShort=catalog.GetActivities,catalog.GetGroups,catalog.GetActivityTier,catalog.GetGroupShortName
 local search=G.Search.Search;local calls,lastActivity=0,nil
 G.Search.Search=function(_,category,id) calls=calls+1;lastActivity=id;return true end
 local activities={
  {id=2001,groupKey=201,categoryID=2,difficultyID=8,isMythicPlusActivity=true,maxNumPlayers=5,fixtureTier=1},
  {id=2002,groupKey=202,categoryID=2,difficultyID=8,isMythicPlusActivity=true,maxNumPlayers=5,fixtureTier=1},
  {id=2003,groupKey=201,categoryID=2,difficultyID=1,maxNumPlayers=5,fixtureTier=1},
  {id=2004,groupKey=203,categoryID=2,difficultyID=1,maxNumPlayers=5,fixtureTier=1},
 }
 local groups={{key=201,name="毒牙洞窟",tier=1,activity=activities[1]},{key=202,name="红玉新生法池",tier=1,activity=activities[2]},{key=203,name="普通专属地下城",tier=1,activity=activities[4]}}
 catalog.GetActivities=function(self,key) if key=="seasonDungeon" or key=="2" then return activities end;return getActivities(self,key) end
 catalog.GetGroups=function(self,key) if key=="seasonDungeon" or key=="2" then return groups end;return getGroups(self,key) end
 catalog.GetActivityTier=function(self,activity) return activity.fixtureTier or getTier(self,activity) end
 catalog.GetGroupShortName=function(self,key,groupKey) if groupKey==201 then return "毒牙" elseif groupKey==202 then return "红玉" end;return getShort(self,key,groupKey) end
 local remember=A.charPrefs.rememberFilters;A:SetSetting("rememberFilters",true)
 local function Row(key) for _,row in ipairs(find.activities.rows) do if row.key==key then return row end end;error("missing activity row "..key) end
 local function Difficulty(id) for _,button in ipairs(find.difficultyButtons) do if button.value==id and button:IsShown() then button:Fire("OnClick");return end end;error("missing difficulty "..tostring(id)) end
 local function Check(key) Row(key).multiSelect:Fire("OnClick") end
 find:SelectCategory("seasonRaid")
 T.eq(Row(0).title:GetText(),"全部副本","the seasonal raid menu restores an explicit all-instances entry")
 find:SelectCategory("seasonDungeon")
 local before=calls
 T.eq(find.emptyText:GetText(),"请选择副本");T.eq(#find.results.ids,0,"a pending category cannot relabel the old result rows")
 Difficulty(8);T.eq(calls,before,"category and difficulty selection prepare a choice without searching")
 T.eq(Row(201).multiSelect:IsShown(),true);T.eq(Row(202).multiSelect:IsShown(),true,"keystone rows show checkboxes immediately")
 T.eq(Row(203).multiSelect:IsShown(),false,"non-keystone rows have no checkbox")
 T.eq(find.multiSelectToggle,nil,"there is no multi-select mode button")
 T.eq(Row(0).title:GetWidth(),Row(0):GetWidth()-60,"all-instances text no longer reserves a mode button")
 T.eq(find.pickerConfirm:IsShown(),false)
 local savedDifficulty=G.prefs.find.categoryPrefs.seasonDungeon.difficultyID
 find:ClosePicker();find:SelectCategory("seasonDungeon")
 T.eq(G.filters.difficultyID,savedDifficulty,"closing an unsubmitted choice restores the confirmed difficulty")
 Difficulty(8)
 Check(202);Check(201)
 T.eq(calls,before,"checkbox drafts do not send native searches")
 T.eq(G.filters.groupKeys,nil,"checkbox drafts do not change the active result filters")
 T.eq(find.pickerConfirm:IsShown(),true);T.eq(find.pickerConfirm:GetHeight(),40);T.eq(find.pickerConfirm.primary,true)
 Check(202);Check(201);T.eq(find.pickerConfirm:IsShown(),false,"unchecking the whole draft hides confirmation")
 Check(202);Check(201);find.pickerConfirm:Fire("OnClick")
 T.eq(calls,before+1);T.same(lastActivity,{2001,2002},"confirming multiple dungeons submits only their selected keystone activities")
 T.same(G.filters.groupKeys,{[201]=true,[202]=true});T.eq(G.filters.groupKey,nil)
 T.eq(find.context:GetText(),"毒牙·红玉  ·  "..GetDifficultyInfo(8),"multi-selection titles use catalog order and short names")
 T.eq(find.draftGroupKeys,nil);T.eq(find.picker:IsShown(),false)
 find:SelectCategory("seasonDungeon");T.eq(calls,before+1,"reopening the active category never resubmits")
 T.eq(Row(201).multiSelect:IsShown(),true);T.eq(find.pickerConfirm:IsShown(),true,"reopening visibly restores the confirmed multi-selection")
 T.eq(find.activities.selectedKey,nil);T.eq(Row(0).selected:IsShown(),false,"a confirmed collection never highlights the all-instances single-selection row")
 T.eq(Row(201).multiSelect:GetChecked(),true);T.eq(Row(202).multiSelect:GetChecked(),true)
 T.eq(Row(201).multiSelect.mark:IsShown(),true)
 for _,stroke in ipairs(Row(201).multiSelect.mark.strokes) do T.same(stroke.fill,U.Theme.onPrimary,"the checkbox strokes use the untinted white foreground") end
 Row(202):Fire("OnClick","LeftButton")
 T.eq(Row(202).multiSelect:GetChecked(),false);T.eq(calls,before+1,"clicking an activity in multi-selection only toggles the draft")
 find:ClosePicker();T.same(G.filters.groupKeys,{[201]=true,[202]=true},"cancelling discards checkbox edits")
 T.eq(find.draftGroupKeys,nil);T.eq(find.pickerConfirm:IsShown(),false,"closing the picker releases the draft controls")
 find:SelectCategory("seasonDungeon");T.eq(Row(202).multiSelect:GetChecked(),true,"reopening restores the active checks")
 Check(202);find.pickerConfirm:Fire("OnClick")
 T.same(G.filters.groupKeys,{[201]=true});T.same(lastActivity,{2001},"one checked dungeon narrows the native request to its keystone activity")
 T.eq(find.context:GetText(),"毒牙洞窟  ·  "..GetDifficultyInfo(8),"a one-item collection retains the complete dungeon name")
 find:SelectCategory("seasonDungeon");local draftCalls=calls
 Row(201):Fire("OnClick","LeftButton");Row(202):Fire("OnClick","LeftButton")
 T.eq(calls,draftCalls,"keystone row clicks edit the default checkbox draft without searching")
 T.same(G.filters.groupKeys,{[201]=true},"the active result filter stays unchanged until confirmation")
 find.pickerConfirm:Fire("OnClick")
 T.same(G.filters.groupKeys,{[202]=true});T.eq(G.filters.groupKey,nil);T.same(lastActivity,{2002})
 local singleCalls=calls
 find:SelectCategory("seasonDungeon");T.eq(Row(202).multiSelect:GetChecked(),true);T.eq(G.filters.difficultyID,8);T.eq(calls,singleCalls,"same-category reopening preserves the confirmed one-item collection and difficulty")
 find:SelectCategory("seasonRaid");singleCalls=calls;find:SelectCategory("seasonDungeon")
 T.same(G.filters.groupKeys,{[202]=true});T.eq(find.activities.selectedKey,nil);T.eq(Row(202).multiSelect:GetChecked(),true,"returning from another category restores the checked dungeon")
 T.eq(G.filters.difficultyID,8);T.eq(calls,singleCalls,"returning to a confirmed one-item collection restores its choice without searching")
 Row(0):Fire("OnClick","LeftButton");T.eq(G.filters.groupKey,nil);T.eq(G.filters.groupKeys,nil);T.eq(find.context:GetText(),"全部副本  ·  "..GetDifficultyInfo(8))
 find:SelectCategory("seasonDungeon");Check(201);Check(202);find.pickerConfirm:Fire("OnClick")
 local selectedCalls=calls
 G.Search.pending={categoryKey="seasonDungeon"};G.Search.timer=C_Timer.NewTimer(.2,function() calls=calls+100 end)
 find:SelectCategory("seasonRaid");T.eq(G.Search.pending,nil);T.eq(G.Search.timer,nil)
 selectedCalls=calls
 f.base.AdvanceClock(.3);T.eq(calls,selectedCalls,"switching category cancels delayed native searches")
 find:SelectCategory("seasonDungeon");T.eq(calls,selectedCalls,"returning to confirmed multi-selection only restores the picker")
 T.eq(find.picker:IsShown(),true,"restoring the choice keeps the selection menu open")
 selectedCalls=calls
 T.same(G.filters.groupKeys,{[201]=true,[202]=true});T.eq(G.filters.difficultyID,8,"category restoration recovers only the confirmed keystone selection")
 T.ok(find.refresh:IsEnabled(),"restoring confirmed dungeons keeps manual refresh available")
 T.ok(not find.emptyPanel:IsShown() or find.emptyText:GetText()~="请选择副本","confirmed dungeons never render the unselected prompt")
 T.eq(Row(201).multiSelect:GetChecked(),true);T.eq(Row(202).multiSelect:GetChecked(),true)
 T.eq(Row(201).multiSelect:IsShown(),true,"returning to a category visibly restores its confirmed multi-selection")
 T.eq(find.appList.rows[1].key,101,"preparing a browse choice preserves real pinned applications")
 Difficulty(1);T.eq(G.filters.groupKeys,nil);T.eq(Row(201).multiSelect:IsShown(),false);T.eq(calls,selectedCalls,"a non-keystone draft clears the collection without a search")
 find:ClosePicker();find:SelectCategory("seasonDungeon");T.eq(Row(201).multiSelect:GetChecked(),true,"closing the unsubmitted difficulty draft returns to the confirmed collection")
 Difficulty(1);Row(203):Fire("OnClick","LeftButton");T.eq(G.filters.groupKeys,nil)
 find:SelectCategory("2");Difficulty(8);Check(201);find.pickerConfirm:Fire("OnClick")
 find:SelectCategory("2");local tierCalls=calls
 G.Search.pending={categoryKey="2"};G.Search.timer=C_Timer.NewTimer(.2,function() calls=calls+100 end)
 Pick(find.tierChoice,1);T.eq(G.filters.groupKeys,nil,"changing expansion removes the active dungeon collection")
 T.eq(calls,tierCalls);T.eq(G.Search.pending,nil);T.eq(G.Search.timer,nil)
 f.base.AdvanceClock(.3);T.eq(calls,tierCalls,"changing expansion cancels queued searches and waits for an explicit activity selection")
 T.eq(find.emptyText:GetText(),"请选择副本")
 find:ClosePicker();find:SelectCategory("2")
 T.same(G.filters.groupKeys,{[201]=true});T.eq(Row(201).multiSelect:GetChecked(),true,"closing the expansion draft restores the last confirmed collection")
 local saved=G.prefs.find.categoryPrefs.seasonDungeon
 saved.groupKey=nil;saved.groupKeys={[201]=true,[203]=true,[999]=true};saved.difficultyID=8
 find:SelectCategory("seasonRaid");find:SelectCategory("seasonDungeon")
 T.same(G.filters.groupKeys,{[201]=true},"restoration excludes removed groups and groups without the chosen keystone activity")
 Row(0):Fire("OnClick","LeftButton");Difficulty(false)
 local getCategories=catalog.GetCategories
 local activityGroups,activityLists,extraCategories={},{},{}
 local allLabels={[1]="全部任务",[4]="全部竞技场",[7]="全部竞技场练习赛",[6]="全部自定义活动",[121]="全部地下堡"}
 for _,entry in ipairs({{1,"任务"},{4,"竞技场"},{7,"竞技场练习赛"},{6,"自定义"},{9,"评级战场"},{121,"地下堡"}}) do
  local id,name=entry[1],entry[2];local key=tostring(id)
  extraCategories[#extraCategories+1]={key=key,id=id,name=name,icon="pvp"}
  local activity={id=9000+id,groupKey=900+id,categoryID=id,maxNumPlayers=id==121 and 5 or 0,fixtureTier=1}
  activityLists[key]={activity};activityGroups[key]={{key=900+id,name="单个"..name,tier=1,activity=activity}}
 end
 local priorActivities,priorGroups=catalog.GetActivities,catalog.GetGroups
 catalog.GetCategories=function(self) local list={};for _,cat in ipairs(getCategories(self)) do list[#list+1]=cat end;for _,cat in ipairs(extraCategories) do list[#list+1]=cat end;return list end
 catalog.GetActivities=function(self,key) return activityLists[key] or priorActivities(self,key) end
 catalog.GetGroups=function(self,key) return activityGroups[key] or priorGroups(self,key) end
 for _,id in ipairs({1,4,7,6,121}) do
  find:SelectCategory(tostring(id));local unopenedCalls=calls
  T.eq(find.emptyText:GetText(),"请选择活动");T.ok(find.emptyHelp:GetText():find(allLabels[id],1,true),"pending non-dungeon copy names the matching all-activity choice")
  T.eq(Row(0).title:GetText(),allLabels[id],"all-activity rows name their own activity category")
  T.eq(#find.activityIDs,2,"other one-item categories retain their all-activity choice")
  Row(0):Fire("OnClick","LeftButton")
  T.eq(calls,unopenedCalls+1);T.eq(find.context:GetText(),allLabels[id],"selecting all activities keeps the full category name in the result title")
 end
 find:SelectCategory("9");local ratedCalls=calls
 T.same(find.activityIDs,{909},"rated battlegrounds alone omit the redundant all-activities row")
 T.eq(calls,ratedCalls);Row(909):Fire("OnClick","LeftButton");T.eq(calls,ratedCalls+1);T.same(lastActivity,{9009})
 find:SelectCategory("seasonRaid");catalog.GetCategories=getCategories
 catalog.GetActivities,catalog.GetGroups,catalog.GetActivityTier,catalog.GetGroupShortName=getActivities,getGroups,getTier,getShort
 G.Search.Search=search;A:SetSetting("rememberFilters",remember)
 find:SelectCategory("seasonRaid");find:SelectCategory("seasonDungeon");Row(0):Fire("OnClick","LeftButton")
end
find:SelectCategory("seasonDungeon");find:ClosePicker()
T.eq(find.appList.rows[1].key,101,"applications survive the browse result selection")
T.eq(find.appList.rows[1].status:GetText(),"5:00")
do
 U.Motion:Tick(2)
 T.eq(U.Motion:Count(),0,"a static application countdown does not keep the animation driver running")
 local clock,details=now,G.Results.GetDetails;local reads=0
 G.Results.GetDetails=function(self,...) reads=reads+1;return details(self,...) end
 now=clock+1;f.base.AdvanceClock(1)
 T.eq(find.appList.rows[1].status:GetText(),"4:59","the visible countdown still advances once per second")
 T.eq(reads,0,"countdown ticks do not reread or rebind roster details")
 U:SetReducedMotion(true);now=clock+2;f.base.AdvanceClock(1)
 T.eq(find.appList.rows[1].status:GetText(),"4:58","settling animations cannot stop the business countdown")
 G.Results.GetDetails=details;now=clock;find:RefreshApplications()
end
do
 local row=find.appList.rows[1]
 T.eq(row.leaderIcon:IsShown(),false,"application rows omit the redundant leader crown")
 T.eq(row.count:IsShown(),false);row:Fire("OnClick","LeftButton");T.eq(row.count:IsShown(),false)
 row.membersButton:Fire("OnClick");T.eq(row.count:IsShown(),false,"party applications also omit the N/N expansion");T.eq(row.count:GetText(),"")
end
find.autoJoin:Fire("OnClick");T.eq(A.db.autoJoin,true,"invite handling uses the shared account preference")
do
 local switch=find.autoJoin
 switch:Fire("OnEnter");U.Motion:Tick(.12)
 T.eq(switch.hover,nil,"auto-join hover has no full-button capsule")
 T.eq(switch.fill,nil,"the switch does not allocate an unused full-button surface")
 T.same(switch.track.bg.color,U.Theme.primaryHover,"hover feedback stays on the enabled track")
 switch:Fire("OnMouseDown","LeftButton");U.Motion:Tick(.12);T.same(switch.track.bg.color,U.Theme.primaryPressed)
 switch:Fire("OnMouseUp","LeftButton");switch:Fire("OnLeave");U.Motion:Tick(.12)
 T.same(switch.track.bg.color,U.Theme.primary,"leaving restores the enabled track")
 switch:SetValue(false);switch:Fire("OnEnter");U.Motion:Tick(.12)
 T.same(switch.track.bg.color,U.Theme.surfaceHighest,"the off track also responds locally")
 switch:SetAvailable(false)
 T.same(switch.track.bg.color,U.Theme.surfaceHigh,"disabling clears the track hover")
 switch:SetAvailable(true);switch:SetValue(true)
end
find.appList.rows[1].cancel:Fire("OnClick");T.eq(G.cancelled,101)
do
 local search,calls=G.Search.Search,0
 local status=G.apps[1].status
 local applies=G.applyCalls
 G.Search.Search=function(self,...) calls=calls+1;return search(self,...) end
 G.apps[1].status="cancelled";G:Notify("applicationCancelled",101)
 T.eq(calls,1,"confirmed cancellation refreshes the current browse to obtain reusable result IDs")
 T.eq(G.applyCalls,applies,"refreshing cancelled results never submits an application")
 G:Notify("applicationCancelled",99999)
 T.eq(calls,1,"cancelling outside the current result set does not refresh an unrelated browse")
 G.Search.Search=search;G.apps[1].status=status;G:Notify("applications")
end
-- Keep the geometry fixture on a stable row while its sort values change.
find.resultsHeader:SetSort(nil,false,true)
find:DoSearch();T.eq(G.state,"done")
local target=find.results.rows[1]
do
 local r=G.records[target.key]
 local fields={"categoryID","maxNumPlayers","numMembers","leaderRating","ratingKind","age","requiredItemLevel","details","comment"};local saved={}
 for _,key in ipairs(fields) do saved[key]=r[key] end
 local function Geometry(region) local p={region:GetPoint()};return {anchor=p[1],x=p[#p-1],y=p[#p],width=region:GetWidth(),height=region:GetHeight()} end
 local function Render() G:Notify("result",r.id);U.Motion:Tick(.016) end
 local body=target:GetWidth()
 local cells=find.resultsHeader.columns
 local markPoint={target.marks:GetPoint()};T.eq(markPoint[2],target.leader,"relationship and note icons follow the leader name")
 T.eq(markPoint[3],"RIGHT");T.eq(markPoint[5],0,"icons share the leader name's vertical center")
 T.eq(target.noteDot:IsShown(),false,"the old generic note dot is unused")
 T.near(Geometry(target.leader).x,cells.leader.x+4,.001,"the leader uses its full cell without a crown")
 local leaderWidth=target.marks:IsShown() and math.min(math.ceil(target.leader:GetUnboundedStringWidth())+2,cells.leader.width-8-target.marks:GetWidth()-6) or cells.leader.width-8
 T.near(target.leader:GetWidth(),leaderWidth,.001);T.eq(target.leaderIcon:IsShown(),false)
 T.eq(select(2,target.title:GetFont()),19,"group titles use the same larger font size as their activity and description")
 T.near(target.title:GetWidth(),cells.title.width-20,.001)
 T.near(target.description:GetWidth(),cells.description.width-8,.001);T.eq(target.description:GetHeight(),26)
 T.near(Geometry(target.score).x,cells.rating.x+4,.001);T.near(target.score:GetWidth(),cells.rating.width-8,.001)
 T.near(Geometry(target.ilvl).x,cells.ilvl.x+4,.001);T.near(Geometry(target.membersButton).x+target.membersButton:GetWidth()/2,cells.members.x+cells.members.width/2,.001)
 T.near(Geometry(target.description).x,cells.description.x+4,.001);T.near(Geometry(target.age).x,cells.age.x+4,.001);T.near(target.age:GetWidth(),cells.age.width-20,.001)
 T.eq(target.description.maxLines,1);T.eq(target.description.wrap,false);T.eq(select(2,target.description:GetFont()),19)
 T.eq(find.resultHeadings.description:GetText(),"描述");T.eq(find.resultHeadings.description.justify,"LEFT")
 T.ok(Geometry(target.title).x+target.title:GetWidth()+4<=cells.activity.x+.001)
 T.near(Geometry(target.score).x+target.score:GetWidth()+8,Geometry(target.description).x,.001)
 T.near(Geometry(target.description).x+target.description:GetWidth()+8,Geometry(target.age).x,.001,"description and age retain their compact cell insets")
 T.eq(find.appList.rows[1].description,nil,"outbound applications do not gain a description column")
 T.near(find.appList.rows[1].title:GetWidth(),find.applicationHeader.columns.title.width-6,.001);T.near(Geometry(find.appList.rows[1].leader).x,find.applicationHeader.columns.leader.x+6,.001,"outbound applications retain their dedicated columns")
 r.comment="A complete group description stays on one line without shifting member slots or numeric columns";Render()
 T.eq(target.description:GetText(),r.comment,"search rows display the listing description independently of its title")
 r.comment="";Render();T.eq(target.description:GetText(),"—","empty descriptions replace any previous row text")
 r.comment=nil;Render();T.eq(target.description:GetText(),"—")
 T.near(Geometry(target.icon).x,cells.activity.x+4,.001,"the instance icon begins the activity cell")
 T.near(Geometry(target.meta).x,Geometry(target.icon).x+target.icon:GetWidth()+6,.001,"the full activity name follows its icon")
 T.near(Geometry(target.title).x,cells.title.x+16,.001,"the group title retains the shared left content inset")
 T.eq(target.ratingLabel,nil,"score labels appear once in the column header")
 T.eq(target.ilvlLabel,nil,"item-level labels do not repeat in every result")
 for key,region in pairs({activity=target.meta,description=target.description,leader=target.leader,rating=target.score,ilvl=target.ilvl,members=target.count,age=target.age}) do
  local cell=cells[key];local label=find.resultHeadings[key]
  T.eq(label:GetParent().definition.key,key,"the visible heading belongs to the matching table cell")
  T.ok(Geometry(region).x>=cell.x-.001 and Geometry(region).x+region:GetWidth()<=cell.x+cell.width+.001,"data fits within its matching header cell")
 end
 for _,region in ipairs({target.leader,target.score,target.ilvl,target.age}) do T.eq(Geometry(region).y,0,"single-line values share the row center") end
 T.eq(target.score.justify,"CENTER");T.eq(target.ilvl.justify,"CENTER")
 T.near(cells.leader.x+cells.leader.width+4,Geometry(target.membersButton).x,.001,"relationship marks do not shift the adjacent member cell")
 T.near(Geometry(target.membersButton).x+target.membersButton:GetWidth()+8,Geometry(target.ilvl).x,.001)
 T.near(Geometry(target.ilvl).x+target.ilvl:GetWidth()+8,Geometry(target.score).x,.001)
 T.eq(find.resultHeadings.members.justify,"CENTER");T.eq(find.resultHeadings.age.justify,"RIGHT")
 T.near(cells.members.x+cells.members.width/2,Geometry(target.membersButton).x+target.membersButton:GetWidth()/2,.001,"the member cell follows the visual roster center")
 T.ok(Geometry(find.resultsHeader).y-find.resultsHeader:GetHeight()-Geometry(find.results).y>=-.001,"the single header stays above the first result without overlap")
 local getSpecInfo=GetSpecializationInfoByID
 _G.GetSpecializationInfoByID=function(id) return id,"Spec "..id,nil,200000+id end
 -- These fixture IDs have not been resolved before this API override.
 local members={{name="One",nameKey="One-Away",class="WARRIOR",assignedRole="TANK",specID=900071}}
 r.categoryID=2;r.maxNumPlayers=5;r.numMembers=1;r.age=10;r.leaderRating=2500;r.requiredItemLevel=320;r.ratingKind=nil
 r.details={members=members,counts={TANK=1,HEALER=0,DAMAGER=0},encounters={}};Render()
 local roster,count,age,score=Geometry(target.roster),Geometry(target.count),Geometry(target.age),Geometry(target.score)
 T.eq(roster.anchor,"CENTER");T.eq(Geometry(target.membersButton).x,count.x)
 local memberY=Geometry(target.membersButton).y
 T.ok(memberY<=0,"the compact row offsets the roster to reserve crown space")
 T.eq(target.count:IsShown(),false,"member totals are hidden until the role summary is clicked")
 T.eq(target.roster.slots[1].icon:IsShown(),true);T.eq(target.roster.slots[1].icon:GetTexture(),1100071,"a party result shows its member's specialization")
 T.eq(target.roster.counts[1].text:IsShown(),false,"party rows use individual specializations rather than aggregate role counts")
 target:Fire("OnClick","LeftButton");T.eq(target.count:IsShown(),false,"ordinary row clicks do not expand member totals")
 target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),false);T.eq(target.count:GetText(),"","party slots never reveal a redundant N/N counter")
 T.eq(Geometry(target.membersButton).y,memberY)
 target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),false)
 for i,role in ipairs({"TANK","HEALER","DAMAGER","DAMAGER","DAMAGER"}) do
  local slot=target.roster.slots[i]
  T.eq(slot.role:IsShown(),true,"empty party slots retain a role placeholder")
  T.eq(slot.role:GetTexture(),U.Theme.productMedia..({TANK="role-tank",HEALER="role-healer",DAMAGER="role-dps"})[role]..".tga")
  T.eq(slot.icon:IsShown(),i==1,"only the occupied slot shows a specialization")
  T.eq(slot.role.desaturated,i~=1,"only empty party roles use grayscale")
  T.same(slot.role.vertex,i==1 and {1,1,1,1} or {.7,.7,.7,1},"missing roles are darker while occupied roles retain their colors")
 end
 T.eq(count.width,138);T.near(age.width,cells.age.width-20,.001)
 members[1]={name="Damage1",class="MAGE",assignedRole="DAMAGER",specID=900063}
 members[2]={name="Tank",class="WARRIOR",assignedRole="TANK",specID=900071}
 members[3]={name="Damage2",class="MAGE",assignedRole="DAMAGER",specID=900062}
 members[4]={name="Healer",class="PRIEST",assignedRole="HEALER",specID=900257}
 members[5]={name="Damage3",class="MAGE",assignedRole="DAMAGER",specID=900064}
 r.numMembers=5;r.age=99*86400;r.leaderRating=nil;Render()
 T.eq(Geometry(target.roster).x,roster.x,"one to five members share the membership column center")
 T.eq(target.roster:GetWidth(),Geometry(target.roster.slots[5].icon).x+target.roster.slots[5].icon:GetWidth(),"the five visible party slots fill the centered roster frame")
 T.same(Geometry(target.count),count,"member totals retain their fixed position")
 T.same(Geometry(target.age),age,"longer time text does not resize the time column")
 T.same(Geometry(target.score),score,"unknown scores retain the same numeric column")
 T.ok(target.score:GetStringWidth()<=target.score:GetWidth(),"the complete unknown-score label fits")
 for i,spec in ipairs({900071,900257,900063,900062,900064}) do
  T.eq(target.roster.slots[i].icon:IsShown(),true)
  T.eq(target.roster.slots[i].icon:GetTexture(),200000+spec,"unordered party members render tank, healer, then damage in stable order")
  T.eq(target.roster.slots[i].role.desaturated,false,"a filled slot restores its colored role icon")
  T.same(target.roster.slots[i].role.vertex,{1,1,1,1},"recycled slots restore normal brightness")
 end
 T.eq(members[1].specID,900063,"rendering preserves provider member order")
 r.categoryID=3;r.maxNumPlayers=40;r.numMembers=40;r.details.counts={TANK=2,HEALER=8,DAMAGER=30};Render()
 T.near(Geometry(target.membersButton).x+Geometry(target.roster).x+target.roster:GetWidth()/2,Geometry(target.count).x+target.count:GetWidth()/2,.001,"fixed raid composition shares the membership column center")
 local function MemberColumnPositions()
  local rosterGeometry=Geometry(target.roster)
  local offset=Geometry(target.membersButton).x+(rosterGeometry.anchor=="CENTER" and (target.membersButton:GetWidth()-target.roster:GetWidth())/2 or rosterGeometry.x)
  local positions={}
  for i,item in ipairs(target.roster.counts) do
   positions[i]={icon=offset+Geometry(item.icon).x,text=offset+Geometry(item.text).x}
  end
  return positions
 end
 local function MemberHoverPadding()
  local positions=MemberColumnPositions()
  local buttonX=Geometry(target.membersButton).x
  local left=positions[1].icon-buttonX
  local right=buttonX+target.membersButton:GetWidth()-positions[3].text-target.roster.counts[3].text:GetStringWidth()
  T.near(left,right,.001,"the hover background has equal padding around the first icon and the visible DPS number")
  return left
 end
 local memberColumnPositions=MemberColumnPositions()
 T.eq(target.roster.slots[1].icon:IsShown(),false,"raid rows switch back to aggregate role counts")
 T.eq(target.roster.counts[1].text:GetText(),"2");T.eq(target.roster.counts[2].text:GetText(),"8");T.eq(target.roster.counts[3].text:GetText(),"30")
 local height,viewport=find.results.rowHeight,find.results:GetHeight()
 target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),true);T.eq(target.count:GetText(),"40/40","raid results keep their member counter")
 T.eq(target.roster:IsShown(),false,"the total replaces role counts in the same row")
 T.eq(Geometry(target.count).y,Geometry(target.membersButton).y)
 T.eq(find.results.rowHeight,height);T.eq(find.results:GetHeight(),viewport,"count toggles do not move the result viewport")
 target.membersButton:Fire("OnClick")
 T.eq(target.count:IsShown(),false);T.eq(target.roster:IsShown(),true)
 local roleColumns={}
 for i,item in ipairs(target.roster.counts) do
  roleColumns[i]=Geometry(item.icon);T.eq(roleColumns[i].x,(i-1)*46);T.eq(item.text:GetWidth(),20)
  T.eq(item.text.justify,"LEFT");T.eq(Geometry(item.text).x,roleColumns[i].x+20,"each role count sits four units after its own icon")
 end
 r.details.counts={TANK=10,HEALER=10,DAMAGER=20};Render()
 for i,item in ipairs(target.roster.counts) do T.same(Geometry(item.icon),roleColumns[i],"two-digit role counts never move later columns") end
 T.same(MemberColumnPositions(),memberColumnPositions,"all three raid columns remain aligned for different two-digit counts")
 r.details.counts={TANK=0,HEALER=0,DAMAGER=1};Render()
 T.same(MemberColumnPositions(),memberColumnPositions,"single-digit raid counts keep the same icon and text columns as two-digit counts")
 local hoverPadding=MemberHoverPadding()
 r.details.counts={TANK=2,HEALER=7,DAMAGER=20};Render()
 T.eq(MemberHoverPadding(),hoverPadding,"single- and two-digit DPS counts retain the same hover padding")
 T.same(MemberColumnPositions(),memberColumnPositions,"resizing the hover background never moves the role columns")
 target.membersButton:Fire("OnClick")
 T.same(MemberColumnPositions(),memberColumnPositions,"expanding the member total preserves horizontal column alignment")
 T.eq(MemberHoverPadding(),hoverPadding,"expanding the member total preserves hover padding")
 target.membersButton:Fire("OnClick")
 r.categoryID=4;r.ratingKind="pvp";r.leaderRating=0;Render()
 T.eq(find.resultHeadings.rating:GetText(),"评分","PvP uses the shared score column")
 T.eq(target.score:GetText(),"暂无");T.ok(target.score:GetStringWidth()<=target.score:GetWidth())
 _G.GetSpecializationInfoByID=getSpecInfo
 for _,key in ipairs(fields) do r[key]=saved[key] end;Render()
end
do
 local r=G.records[target.key]
 local activityText=target.meta:GetText()
 r.bnetFriends=1;r.charFriends=0;G:Notify("result",r.id);U.Motion:Tick(.016)
 T.ok(target.marks.icons.bnet:IsShown(),"Battle.net counts show the distinct Battle.net friend icon")
 T.eq(target.marks.icons.bnet:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\battlenet-friend.tga")
 T.eq(target.meta:GetText(),activityText,"relationship changes preserve the compact activity label")
 T.eq(target.marks.flags.friend,false,"Battle.net friends do not become character friends")
 r.charFriends=1;G:Notify("result",r.id);U.Motion:Tick(.016)
 T.ok(target.marks.icons.friend:IsShown(),"both types of friendship can appear together")
 T.eq(target.marks.icons.friend:GetTexture(),U.Theme.productMedia.."friend.tga")
 r.bnetFriends=0;r.charFriends=0;G:Notify("result",r.id);U.Motion:Tick(.016)
end
do
 local r=G.records[target.key];local score=r.leaderRating
 r.ratingKind="pvp";r.leaderRating=1620;r.requiredRating=1800;r.pvpRatingActivity="评级战场";r.maxNumPlayers=0
 r.pvpRatings={{bracket=4,rating=1620,activityName="评级战场"},{bracket=1,rating=1800,activityName="2v2"},{bracket=2,rating=1750,activityName="3v3"},{bracket=3,rating=1500,activityName="5v5"}}
 G:Notify("result",r.id);U.Motion:Tick(.016)
 T.eq(target.score:GetText(),"1620","PvP列表显示评级分，不显示大秘境分")
 T.eq(target.count:GetText(),"1","未提供人数上限不显示1/0")
 U.Tooltip:ShowGroup(target,r);T.eq(U.Tooltip.interactive.metrics[1].value:GetText(),"1620");T.eq(U.Tooltip.interactive.metrics[3].value:GetText(),"1800")
 T.eq(U.Tooltip.interactive.pvpRatings:GetText(),"2v2  1800\n3v3  1750\n5v5  1500","提示列出API额外提供的各赛制，不猜活动对应或丢弃旧赛制")
 r.leaderRating=0;U.Tooltip:RenderGroup();T.eq(U.Tooltip.interactive.metrics[1].value:GetText(),"暂无","明确零分不套大秘境评分颜色")
 r.leaderRating=nil;U.Tooltip:RenderGroup();T.eq(U.Tooltip.interactive.metrics[1].value:GetText(),"未知分数","缺少PvP分不回退大秘境分")
 local over=find.results.clip.IsMouseOver;find.results.clip.IsMouseOver=function() return true end
 U.Tooltip:Hide();target:Fire("OnEnter");T.eq(U.Tooltip.owner,nil,"结果行右侧不触发提示")
 target.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.owner,target,"图标与队名区域触发完整队伍提示")
 T.eq(find.results.tooltipFraction,.25);T.eq(target.tooltipArea:GetWidth(),find.resultsHeader.columns.title.width,"结果提示覆盖可调宽度的队伍信息列")
 T.eq(target.tooltipArea.mouseEnabled,false,"the tooltip area never intercepts the row's click after scripts are assigned")
 T.eq(target.tooltipArea.mouseMotionEnabled,true,"the tooltip area keeps hover events")
 target.mouseOver=true;target.tooltipArea.mouseOver=false;target.tooltipArea:Fire("OnLeave");U.Motion:Tick(.25)
 T.eq(U.Tooltip.owner,nil,"鼠标仍在整行右侧时也收起未固定提示")
 target.mouseOver=nil;find.results.clip.IsMouseOver=over
 r.ratingKind=nil;r.leaderRating=score;r.requiredRating=nil;r.pvpRatingActivity=nil;r.pvpRatings=nil;r.maxNumPlayers=5
 G:Notify("result",r.id);U.Motion:Tick(.016)
end
target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),false)
target:Fire("OnMouseDown","LeftButton");target:Fire("OnMouseUp","LeftButton");target:Fire("OnClick","LeftButton")
local function DoubleClickResult(row)
 row:Fire("OnMouseDown","LeftButton");row:Fire("OnMouseUp","LeftButton");row:Fire("OnClick","LeftButton")
 row:Fire("OnMouseDown","LeftButton");row:Fire("OnDoubleClick","LeftButton")
end
local firstFocusBackground
local noteBox=LFGListApplicationDialog.Description.EditBox
local nativeNoteFocus=noteBox:GetScript("OnEditFocusGained")
noteBox:SetScript("OnEditFocusGained",function(box)
 if nativeNoteFocus then nativeNoteFocus(box) end
 if not firstFocusBackground then
  firstFocusBackground=box:CreateTexture(nil,"BACKGROUND");firstFocusBackground:SetAllPoints();firstFocusBackground:SetColorTexture(0,0,0,.9)
 end
end)
find.main:Fire("OnKeyDown","ENTER");T.eq(U.Application.applicationLease,nil,"Enter leaves the selected result alone so the user can open chat")
DoubleClickResult(target);T.eq(U.Application.applicationLease.id,target.key);T.eq(G.clearedApplication,nil,"opening configuration keeps the engine's current note")
T.eq(firstFocusBackground:IsShown(),false,"native art created on first application focus stays behind the shared input surface");T.eq(firstFocusBackground:GetAlpha(),0)
local savedApps=G.apps
G.apps={savedApps[1]}
for i=2,5 do G.apps[i]={id=900+i,name="Other category "..i,leaderName="Other-Away",categoryID=3,status=i==5 and "invited" or "applied"} end
local previousID=LFGListApplicationDialog.resultID
A:SetSetting("reduceMotion",false)
U.Application:Apply(102)
T.ok(find.limitNotice:IsShown(),"the sixth application explains the cap beside the primary action")
T.ok(find.limitNotice:GetHeight()>=40)
T.eq(find.limitText.justify,"LEFT","notice text has an explicit left alignment")
T.eq(find.limitNotice:GetWidth(),find.results.rows[1]:GetWidth(),"notice and result body share their left and right edges")
local noticeAnimation=U.Motion.jobs[find.limitNotice]
T.ok(noticeAnimation,"the user action animates the inline notice")
G:Notify("applications");T.eq(U.Motion.jobs[find.limitNotice],noticeAnimation,"passive native updates do not replay the notice")
T.eq(find.scopeToggle:GetWidth(),find.scopeToggle.label:GetWidth()+12,"inline scope replaces the title with compact symmetric padding")
T.eq(find.appsTitle:IsShown(),false,"the inline scope toggle takes the title's place")
local scopePoint={find.scopeToggle:GetPoint()};T.eq(scopePoint[2],find.applicationPanel);T.eq(scopePoint[3],"TOPLEFT")
local countPoint={find.appsBadge:GetPoint()};T.eq(countPoint[2],find.scopeToggle);T.eq(countPoint[3],"RIGHT");T.eq(countPoint[4],10,"the count immediately follows the scope toggle")
T.eq(({find.scopeToggle.label:GetPoint()})[1],"CENTER","hover fill centers on the scope label")
T.eq(U.limitDialog,nil,"the cap never creates a modal")
T.eq(find.appsCount:GetText(),"5 / 5","the header reports the shared global slot count")
T.eq(#find.appList.ids,5,"the cap expands applications from every category")
T.eq(LFGListApplicationDialog.resultID,previousID,"reaching the cap never submits or opens a new native application")
find.appList:Select(905,true)
local invitedRow;for _,r in ipairs(find.appList.rows) do if r.key==905 then invitedRow=r end end
T.ok(invitedRow and not invitedRow.cancel:IsShown(),"invitations keep the native response dialog without duplicate action buttons")
find.appList:SetPixelOffset(0,false)
find.appList.rows[2].cancel:Fire("OnClick");T.eq(G.cancelled,902)
T.eq(find.continueApplication,nil,"the quota notice has no continue-application button")
T.eq(find.limitText:GetText(),"最多同时申请 5 支队伍，请先取消一项申请。","cancellation waits for a native status event")
G.apps[2].status="cancelled";G:Notify("applications")
T.eq(find.limitText:GetText(),"已有空余名额，可以继续申请。")
T.same(find.limitNotice.fill.color,{38/255,61/255,48/255,1},"available application slots use a green notice background")
T.eq(LFGListApplicationDialog.resultID,previousID,"freeing a slot does not auto apply")
do
 local search,calls=G.Search.Search,0
 G.Search.Search=function(self,...) calls=calls+1;return search(self,...) end
 G.apps[1].status="cancelled";G:Notify("applicationCancelled",101);G:Notify("applications")
 T.eq(calls,1,"freeing a slot refreshes current results even while the quota notice is shown")
 T.eq(find.limitNotice:IsShown(),true)
 G.Search.Search=search;G.apps[1].status="applied";G:Notify("applications")
end
find:Apply(102);T.eq(U.Application.applicationLease.id,102,"the player selects a group again after freeing a slot")
T.eq(find.limitNotice:IsShown(),false,"selecting a group again clears the quota notice")
do
 T.eq(find.quickFilterHeight,0,"important filters do not consume a second row")
 local expectedRows=6
 local row=find.results.rows[expectedRows];local point={row:GetPoint()}
 T.ok(#find.appList.ids>=3,"the density check keeps all three application rows visible")
 T.eq(math.floor(find.results:GetHeight()/find.results.rowHeight),expectedRows,"compact result rows fit below three applications")
 T.ok(row.key and -point[#point]+row:GetHeight()<=find.results:GetHeight(),"the expected complete result rows fit below three applications")
end
G.apps[2].status="applied";U.Application:Apply(102)
T.same(find.limitNotice.fill.color,U.Theme.notice,"reaching the cap again restores the ordinary notice background")
f.base.AdvanceClock(6.4);G:Notify("applications");f.base.AdvanceClock(.11)
T.eq(find.limitNotice:IsShown(),true,"the quota notice remains after 6.5 seconds")
G:Notify("applications");T.eq(find.limitNotice:IsShown(),true,"passive updates retain the quota notice")
G.apps[2].status="cancelled";G:Notify("applications");find:Apply(103)
T.eq(U.Application.applicationLease.id,103,"the player can choose a different group after a slot becomes available")
G.apps[2].status="applied"
U.Application:Apply(102);find.closeApplicationNotice:Fire("OnClick");G:Notify("applications")
T.eq(find.limitNotice:IsShown(),false,"the notice can be dismissed without passive reopening")
G.apps=savedApps;find.scopeToggle:Fire("OnClick");G:Notify("applications")
do
 local ended={id=902,name="Expired application",status="timedout",categoryID=2,result=G.records[102]}
 G.apps[#G.apps+1]=ended;find:RefreshApplications()
 T.eq(#find.appList.ids,1,"expired applications disappear immediately from the current category")
 local row=find.appList.rows[1];find.appList.clip.mouseOver=true;U.Tooltip:Hide();row:Fire("OnEnter")
 T.eq(U.Tooltip.owner,nil,"pinned application statistics do not trigger a whole-row tooltip")
 row.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.owner,row,"pinned application details activate in the left quarter")
 T.eq(find.appList.tooltipFraction,.25);T.eq(row.tooltipArea:GetWidth(),find.applicationHeader.columns.title.width)
 T.eq(row.tooltipArea.mouseEnabled,false);T.eq(row.tooltipArea.mouseMotionEnabled,true)
 row.mouseOver=true;row.tooltipArea:Fire("OnLeave");U.Motion:Tick(.25);row.mouseOver=nil
 T.eq(U.Tooltip.owner,nil,"moving to the application status or action closes the tooltip")
 T.eq(row.hover:IsShown(),false,"an application status row has no full-row hover block")
 row:Fire("OnMouseDown","LeftButton");T.eq(row.hover:IsShown(),false,"pressing the status row does not restore the full-row block")
 row:Fire("OnClick","LeftButton");row:Fire("OnLeave");find.appList.clip.mouseOver=false
 T.eq(row.selected:IsShown(),false,"clicking an application does not leave a full-row selection block")
 T.eq(row.mark:IsShown(),false,"application rows do not keep a selection marker")
 local isActive=G.Applications.IsActive
 ended.status,ended.pendingStatus="none","applied"
 G.Applications.IsActive=function(self,id) return id==ended.id or isActive(self,id) end
 find:RefreshApplications()
 local pending=find.appList.rows[2]
 T.eq(pending.status:GetText(),"提交中","a pending submission without a deadline is never labeled expired")
 T.eq(pending.cancel:IsShown(),false,"a pending native submission has no ineffective cancellation button")
 G.Applications.IsActive=isActive
 G.apps[#G.apps]=nil;find:RefreshApplications()
end
do
 local dialog=LFGListApplicationDialog;local roles={GetLFGRoles()};local setRoles=SetLFGRoles
 local getSpec,getSpecRole=GetSpecialization,GetSpecializationRole
 _G.GetSpecialization=function() return 2 end
 _G.GetSpecializationRole=function(spec) T.eq(spec,2);return "TANK" end
 _G.SetLFGRoles=function() error("an application must not change dungeon finder roles") end
 local originalSubmit=dialog.SignUpButton:GetScript("OnClick");local originalEvent=dialog:GetScript("OnEvent");local noteParent=dialog.Description.EditBox:GetParent();local noteFont={dialog.Description.EditBox:GetFont()}
 local before=dialog.submissions
 U:CloseModal()
 T.eq(U.Application:IsAutoApplyEnabled(),false,"automatic application starts disabled without a saved enabled flag")
 T.eq(find.autoApply.value,false);T.eq(find.autoApply:GetWidth(),44,"only the actual track is a toggle target")
 T.eq(find.applicationRoles,nil,"header role shortcuts are removed")
 find.applicationSettings:Fire("OnClick");T.eq(U.activeModal,nil,"the disabled text cannot bypass enabling configuration")
 T.eq(target.key,102);DoubleClickResult(target);T.eq(dialog.submissions,before,"a disabled double click opens a temporary confirmation")
 T.eq(U.Application.applicationLease.id,102);T.eq(dialog.Description:GetParent(),U.Application.applicationModal.note)
 T.eq(U.Application.applicationLease.roles.TANK,true,"first confirmation prefers the current specialization")
 T.eq(U.Application.applicationPrefs and U.Application.applicationPrefs.roles,nil,"preselection does not confirm saved roles")
 T.eq(A.charPrefs.applicationRoles,nil,"opening a default selection does not persist it")
 U:CloseModal();T.eq(dialog.submissions,before)
 _G.GetSpecializationRole=function() return "HEALER" end
 find:Apply(102);T.eq(U.Application.applicationLease.roles.DAMAGER,true,"an unavailable specialization falls back to an available queue role")
 U:CloseModal();_G.GetSpecializationRole=function() return "TANK" end
 find:Apply(102)
 dialog.Description.EditBox:UserType("Temporary native note")
 U.Application.applicationModal.roles.DAMAGER:Fire("OnClick");U.Application.applicationModal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+1);T.eq(dialog.submitted.note,"Temporary native note")
 T.eq(dialog.submitted.tank,true);T.eq(dialog.submitted.damage,true,"manual confirmation preserves multiple selected roles")
 T.eq(G.applyCalls,1,"temporary confirmation submits through the business Apply entry")
 T.eq(U.Application:IsAutoApplyEnabled(),false);T.same(U.Application.applicationPrefs.roles,{TANK=true,DAMAGER=true},"a confirmed manual application becomes this character's next default")
 T.same(A.charPrefs.applicationRoles,{TANK=true,HEALER=false,DAMAGER=true},"only the three explicit role booleans enter this character's saved preferences")
 T.eq(U.activeModal,nil);T.eq(dialog.Description:GetParent(),dialog);T.eq(dialog.Description.EditBox:GetParent(),noteParent)
 T.eq(dialog.SignUpButton:GetScript("OnClick"),originalSubmit);T.eq(dialog:GetScript("OnEvent"),originalEvent)
 T.same({dialog.Description.EditBox:GetFont()},noteFont,"releasing restores the original native text presentation")
 find.main:Fire("OnKeyDown","ENTER");T.eq(dialog.submissions,before+1,"Enter never submits while automatic application is off")
 T.eq(U.Application.applicationLease,nil,"Enter does not open the temporary application window")
 find.autoApply:Fire("OnClick")
 T.eq(U.Application:IsAutoApplyEnabled(),true,"confirmed available roles enable directly")
 T.eq(U.activeModal,nil,"valid saved roles do not require another settings confirmation")
 T.eq(A.charPrefs.autoApply,true,"direct activation is saved for this character")
 find.autoApply:Fire("OnClick");T.eq(A.charPrefs.autoApply,false)
 dialog.available.DAMAGER=false
 find.autoApply:Fire("OnClick")
 T.eq(find.autoApply.value,false,"the switch stays off while its configuration is pending")
 T.eq(U.Application.applicationLease.id,nil)
 T.eq(U.Application.applicationModal.autoApply.value,true,"the pending activation remains visible only in the modal draft")
 T.eq(U.Application.applicationModal.group:IsShown(),false,"configuration has no retired explanation or empty group row")
 T.eq(({U.Application.applicationModal.roleLabel:GetPoint()})[3],0,"roles start at the content edge after removing the help text")
 U:CloseModal();T.eq(U.Application:IsAutoApplyEnabled(),false,"cancelling activation leaves the feature off")
 T.eq(U.Application.applicationModal.autoApply.value,false,"cancelling clears the pending modal checkbox")
 find.autoApply:Fire("OnClick")
 local modal=U.Application.applicationModal
 dialog.available.DAMAGER=true;U.Application:RefreshApplicationRoles();modal.roles.DAMAGER:Fire("OnClick")
 local groupText=modal.group:GetText();U:SetText(modal.group,string.rep("较长的申请队伍标题",6));U.Application:LayoutApplication()
 T.eq(modal.group:GetHeight(),modal.group:GetStringHeight(),"two-line application titles reserve their complete enlarged line boxes")
 U:SetText(modal.group,groupText);U.Application:LayoutApplication()
 modal.roles.TANK:Fire("OnClick");modal.roles.DAMAGER:Fire("OnClick")
 T.eq(modal.submit:IsEnabled(),false,"activation cannot save an empty role selection")
 modal.submit:Fire("OnClick");T.eq(U.Application:IsAutoApplyEnabled(),false)
 modal.roles.DAMAGER:Fire("OnClick");modal.roles.TANK:Fire("OnClick")
 T.eq(modal.roles.TANK.active,true);T.eq(modal.roles.DAMAGER.active,true)
 dialog.Description.EditBox:UserType("A reusable native note");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+1,"saving activation does not submit a group application")
 T.eq(U.Application:IsAutoApplyEnabled(),true);T.eq(find.autoApply.value,true)
 T.same(U.Application.applicationPrefs.roles,{TANK=true,DAMAGER=true})
 T.eq(LycheeGroupDB.autoApply,nil,"automatic application never writes an account-wide flag")
 T.eq(A.charPrefs.autoApply,true,"saving valid activation persists this character's switch")
 T.same(A.charPrefs.applicationRoles,{TANK=true,HEALER=false,DAMAGER=true})
 local activity=G.records[102].activityID;G.records[102].activityID=1
 DoubleClickResult(target);T.eq(dialog.submissions,before+2,"an enabled double click reuses the configured input directly")
 T.eq(dialog.submitted.tank,true);T.eq(dialog.submitted.damage,true,"quick submission retains the complete multi-role selection")
 T.eq(dialog.submitted.note,"A reusable native note");T.eq(U.activeModal,nil);T.eq(G.clearedApplication,nil)
 G.records[102].activityID=activity
 find.main:Fire("OnKeyDown","ENTER");T.eq(dialog.submissions,before+2,"Enter never submits while automatic application is on")
 T.eq(U.Application.applicationLease,nil,"Enter does not open a window while automatic application is on")
 DoubleClickResult(target);T.eq(dialog.submissions,before+3,"double click keeps using the configured quick path")
 find.applicationSettings:Fire("OnEnter")
 T.same(find.applicationSettings.label.color,U.Theme.brand,"the separate settings text uses brand color on hover")
 T.eq(find.applicationSettings.hover:IsShown(),false,"the settings text has no surrounding hover surface")
 find.applicationSettings:Fire("OnLeave");find.applicationSettings:Fire("OnClick")
 T.eq(U.Application:IsAutoApplyEnabled(),true,"clicking the text edits without toggling")
 T.eq(U.Application.applicationLease.id,nil);T.eq(modal.submit.label:GetText(),U.L.save)
 dialog.Description.EditBox:UserType("Updated native note");modal.roles.DAMAGER:Fire("OnClick");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+3);T.same(U.Application.applicationPrefs.roles,{TANK=true})
 find:OpenResultMenu(find.results,102)
 local menu=U.context.menu;T.eq(menu.items[1].label,"编辑后申请")
 menu.list.rows[1]:Fire("OnClick","LeftButton")
 T.eq(dialog.submissions,before+3,"the context menu always waits for confirmation")
 T.eq(U.Application.applicationLease.id,102);T.eq(modal.submit.label:GetText(),"申请")
 dialog.Description.EditBox:UserType("Manual application note")
 modal.roles.DAMAGER:Fire("OnClick");modal.roles.TANK:Fire("OnClick");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+4);T.eq(dialog.submitted.note,"Manual application note")
 T.eq(dialog.submitted.damage,true);T.eq(dialog.submitted.tank,false)
 T.same(U.Application.applicationPrefs.roles,{TANK=true},"manual application does not replace the automatic role configuration")
 T.same(A.charPrefs.applicationRoles,{TANK=true,HEALER=false,DAMAGER=false},"one-off overrides do not replace the character's saved automatic roles")
 dialog.Description.EditBox:UserType("Updated native note")
 dialog.available.TANK=false;find:Apply(102)
 T.eq(dialog.submissions,before+4,"an unavailable remembered role cannot be submitted")
 T.eq(modal.submit:IsEnabled(),false)
 modal.roles.DAMAGER:Fire("OnClick");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+5);T.eq(dialog.submitted.damage,true)
 dialog.available.TANK=true
 find.autoApply:Fire("OnClick");T.eq(U.Application:IsAutoApplyEnabled(),false)
 find:Apply(102);T.eq(dialog.submissions,before+5,"turning the switch off immediately restores confirmation")
 T.eq(U.Application.applicationLease.id,102);U:CloseModal()
 find.autoApply:Fire("OnClick")
 T.eq(U.Application:IsAutoApplyEnabled(),true,"reenabling reuses available saved roles directly")
 T.eq(U.activeModal,nil,"reenabling valid roles does not open a redundant dialog")
 _G.GetSpecializationRole=function() return "DAMAGER" end
 find.applicationSettings:Fire("OnClick")
 T.eq(U.Application.applicationLease.roles.TANK,true,"editing retains explicitly saved roles across specialization changes")
 local foreign=CreateFrame("Frame",nil,UIParent);dialog.Description:SetParent(foreign);dialog.Description:SetHeight(40)
 T.eq(U.Application.applicationLease,nil);T.eq(dialog.Description:GetParent(),foreign,"lease release preserves an external owner's layout")
 T.eq(U.activeModal,nil);dialog.Description:SetParent(dialog);dialog.Description:SetSize(210,28)
 T.same({GetLFGRoles()},roles,"temporary and automatic applications leave dungeon finder roles unchanged")
 local nativeApply=C_LFGList.ApplyToGroup;C_LFGList.ApplyToGroup=function() error("Rejected by client") end
 find:Apply(102);T.eq(find.limitText:GetText(),G.L.applyFailed,"client rejection is reported beside the application controls")
 C_LFGList.ApplyToGroup=nativeApply
 local priorApps=G.apps;G.apps={}
 for i=1,5 do G.apps[i]={id=900+i,name="Pending "..i,categoryID=3,status="applied"} end
 local submitted=dialog.submissions
 find:Apply(102,true);G.apps[1].status="cancelled";G:Notify("applications")
 find:Apply(102,true)
 T.eq(dialog.submissions,submitted,"selecting Edit and apply again still waits for confirmation")
 T.eq(U.Application.applicationLease.id,102);T.eq(U.Application.applicationModal.submit.label:GetText(),"申请")
 U:CloseModal()
 G.apps[1].status="applied";find:Apply(102)
 local pendingRecord=G.records[102];G.records[102]=nil;G.apps[1].status="cancelled";G:Notify("applications")
 find:Apply(102)
 T.eq(find.limitText:GetText(),U.L.unavailable,"selecting a vanished target gives a visible explanation instead of the quota notice")
 T.eq(dialog.submissions,submitted)
 G.records[102]=pendingRecord;G.apps=priorApps;G:Notify("applications")
 _G.GetSpecialization,_G.GetSpecializationRole=getSpec,getSpecRole
 _G.SetLFGRoles=setRoles
end
do
 local tip=U.Tooltip
 tip:ShowGroup(target,G.records[target.key])
 local view=tip.interactive;local member=view.memberButtons[1]
 T.ok(view:IsShown());T.eq(view:GetWidth(),320)
 T.eq(view.raidLeader:IsShown(),false);T.eq(view.raidLeaderIcon:IsShown(),false,"party tooltips hide the raid-only footer")
 T.eq(view.leader,nil);T.eq(view.leaderIcon,nil,"search tooltips no longer allocate a duplicate leader header")
 T.near(view.title:GetWidth()+52,view.canvas:GetWidth(),.001,"a party title uses the full left column after its activity icon")
 T.eq(member:IsEnabled(),false,"search-result party members are display-only")
 member:Fire("OnClick")
 T.eq(tip.member,nil,"clicking a search-result member never opens personal details")
 T.eq(tip.record,G.records[target.key]);T.ok(not tip.pinned)
 T.eq(view.back:IsShown(),false);T.eq(view.wcl:IsShown(),false);T.eq(view.note:IsShown(),false)
 local knownLeader={id=-8001,name="Known leader",leaderName="Warrior-Away",details={members={{nameKey="Warrior-Away",class="WARRIOR",isLeader=true}}}}
 local unknownLeader={id=-8002,name="Missing leader details",leaderName="Unknown-Away",details={members={}}}
 tip:ShowGroup(target,knownLeader)
 T.eq(member.member,knownLeader.details.members[1]);T.eq(member.targetKey,"Warrior-Away")
 local r,g,b=member.name:GetTextColor();local classR,classG,classB=U:ClassColor("WARRIOR")
 T.same({r,g,b},{classR,classG,classB},"the actual leader member keeps its current class color")
 T.ok(member.leaderIcon:IsShown(),"the member list retains its leader crown")
 tip:ShowGroup(target,unknownLeader)
 T.eq(member.member,nil);T.eq(member:IsShown(),false,"missing details do not retain the previous leader in the reused member row")
 T.eq(view.leader,nil);T.eq(view.leaderIcon,nil,"missing details do not recreate a leader header")
 tip:Hide()
 local app={members=members}
 tip:ShowApplicants(target,app)
 T.eq(member:IsEnabled(),true,"reusing the row for applicants restores member interaction")
 member:Fire("OnClick")
 T.eq(tip.member,members[1],"an applicant still opens inside the shared tooltip")
 T.ok(tip.pinned);T.eq(tip.sourceApp,app)
 T.eq(select(2,view.title:GetFont()),19);T.eq(view.icon:GetWidth(),36,"personal details keep their larger portrait")
 T.eq(view.playerRole:GetWidth(),16);T.eq(view.playerFaction:GetWidth(),16,"personal detail markers keep their original size")
 T.ok(view.back:IsShown());T.ok(view.comment:GetText():find("A different experience",1,true))
 view.wcl:Fire("OnClick");T.ok(view.copyField.box:GetText():find("/Away/Guest",1,true),"WCL link uses the complete known identity")
 T.eq(U.activeModal,nil,"WCL stays inside the member detail")
 view.back:Fire("OnClick");T.eq(tip.member,nil);T.eq(tip.sourceApp,app)
 T.eq(member:IsEnabled(),true,"returning to applicants keeps member details available")
 tip:Hide()
end
do
 local tip=U.Tooltip
 local left,top=U.frame.GetLeft,U.frame.GetTop
 U.frame.GetLeft=function() return 400 end;U.frame.GetTop=function() return 960 end
 local surface=tip.interactive;surface:SetSize(424,240)
 tip.pointX,tip.pointY=1000,100;tip:Position(surface)
 T.eq(tip.positionX,1020,"tooltip may extend past the main window on the cursor's right")
 T.eq(tip.positionY,80,"the interactive tooltip starts alongside the pointer")
 tip.pointX,tip.pointY=1480,930;tip:Position(surface)
 T.eq(tip.positionX,1036,"the screen edge flips the tooltip to the pointer's left")
 T.eq(tip.positionY,710,"bottom-edge placement keeps the pointer beside the interactive tooltip")
 tip.pinned=true;tip.pointX,tip.pointY=500,100;tip:Position(surface)
 T.eq(tip.positionX,1036,"a pinned member detail remains reachable while the pointer moves")
 U.frame.GetLeft,U.frame.GetTop=left,top;tip:Hide()
end
local raidMembers={}
local function CheckRaidLeaderFooter(view,name,ui,class)
 if ui.Tooltip.expanded then
  T.eq(view.raidLeader:IsShown(),false);T.eq(view.raidLeaderIcon:IsShown(),false,"expanded raids omit the duplicate leader footer")
  T.ok(view.memberButtons[1].leaderIcon:IsShown(),"the actual leader keeps the crown in the full roster")
  return
 end
 T.ok(view.raidLeader:IsShown());T.ok(view.raidLeaderIcon:IsShown())
 T.eq(view.raidLeader:GetText(),name,"the raid-only footer shows the complete current leader identity")
 local r,g,b=view.raidLeader:GetTextColor();local cr,cg,cb=ui:ClassColor(class)
 T.same({r,g,b},{cr,cg,cb},"the raid-only leader footer follows its member's class color")
 local point={view.raidLeader:GetPoint()}
 local hintHeight=view.footer:GetText()~="" and view.footer:GetStringHeight() or 0
 local leaderOffset=hintHeight>0 and hintHeight+10 or 0
 T.eq(point[1],"BOTTOMLEFT");T.eq(point[2],view.canvas);T.eq(point[3],"BOTTOMLEFT");T.eq(point[4],20);T.eq(point[5],leaderOffset,"the raid leader sits above the bottom modifier hint")
 local icon={view.raidLeaderIcon:GetPoint()}
 T.eq(icon[2],view.raidLeader);T.eq(icon[3],"TOPLEFT");T.eq(icon[4],-12);T.near(icon[5],-view.raidLeader:GetLineHeight()/2,.001,"the footer crown centers on the first identity line")
 local top=view.canvas:GetHeight()-leaderOffset-math.max(view.raidLeader:GetLineHeight(),view.raidLeader:GetStringHeight())
 if view.footer:GetText()~="" then
  local hint={view.footer:GetPoint()}
  T.eq(hint[1],"BOTTOMLEFT");T.eq(hint[2],view.canvas);T.eq(hint[3],"BOTTOMLEFT");T.eq(hint[4],0);T.eq(hint[5],0,"the modifier hint occupies the bottom of the raid canvas")
 end
 for _,row in ipairs(view.memberButtons) do if row:IsShown() then
  local position={row:GetPoint()};T.ok(top>=-position[#position]+row:GetHeight()+12-.001,"the raid leader stays below the member list")
 end end
 for _,row in ipairs(view.bossRows) do if row:IsShown() then
  local position={row:GetPoint()};T.ok(view.canvas:GetHeight()>=-position[#position]+row:GetHeight()+4-.001,"the canvas retains room below the final boss")
 end end
end
local function CheckInlineSearchMarks(row)
 local portrait,role,text={row.icon:GetPoint()},{row.role:GetPoint()},{row.name:GetPoint()}
 local firstMarkLeft=portrait[#portrait-1]+row.icon:GetWidth()+role[4]-row.role:GetWidth()
 if row.marks:IsShown() then firstMarkLeft=firstMarkLeft-4-row.marks:GetWidth() end
 local textWidth=math.min(row.name:GetWidth(),math.max(row.name:GetStringWidth(),row.realm:GetStringWidth()))
 T.near(firstMarkLeft,text[#text-1]+textWidth+6,.001,"search role and note marks follow the wider identity line by six units")
 T.eq(role[2],row.icon);T.eq(role[5],0,"inline search marks keep the portrait's vertical center")
end
for i=1,30 do raidMembers[i]={name="Raider"..i.."-Away",nameKey="Raider"..i.."-Away",class="WARRIOR",specID=71,assignedRole="DAMAGER",subgroup=math.ceil(i/5)} end
raidMembers[30].isLeader=true;raidMembers[2].assignedRole="TANK";raidMembers[3].assignedRole="HEALER"
raidMembers[30].factionGroup=1
raidMembers[2].isCharFriend=true
local raid={id=800,categoryID=3,activity={mapID=4444,journalID=444},activityName="A native raid",name="Thirty members",comment=string.rep("A complete native description. ",80),leaderName="Raider30-Away",leaderKey="Raider30-Away",numMembers=30,maxNumPlayers=30,details={members=raidMembers,counts={TANK=2,HEALER=6,DAMAGER=22}}}
local journalReady=false;local journalInstance,journalDifficulty=22,14
EJ_GetCurrentInstance=nil;EJ_GetDifficulty=function() return journalDifficulty end
EJ_GetInstanceInfo=function() return "Selected journal",nil,nil,nil,nil,nil,nil,nil,nil,journalInstance==22 and 222 or 4444 end
local instanceForMap=C_EncounterJournal.GetInstanceForGameMap
C_EncounterJournal.GetInstanceForGameMap=function(map) if map==222 then return 22 end;return instanceForMap(map) end
EJ_SelectInstance=function(id) journalInstance=id end;EJ_SetDifficulty=function(id) journalDifficulty=id end
do
 local select=EJ_SelectInstance;EJ_SelectInstance=function() error("world bosses must not select an instance journal") end
 T.eq(U:ProgressText({categoryID=3,activity={mapID=0,journalID=1206,difficultyID=0}},{encounters={}}),"—")
 EJ_SelectInstance=select
end
raid.activity.difficultyID=15
EJ_GetEncounterInfoByIndex=function(index) if journalReady and journalInstance==444 and journalDifficulty==15 then return ({"Boss A","Boss B","Boss C"})[index] end end
A:SetSetting("raidMembers","shift")
U.Tooltip:ShowGroup(target,raid);T.eq(U.Tooltip.interactive:GetWidth(),624)
CheckRaidLeaderFooter(U.Tooltip.interactive,raid.leaderName,U,"WARRIOR")
do
 local view=U.Tooltip.interactive;local boss={view.bossTitle:GetPoint()}
 T.near(view.title:GetWidth()+52,view.canvas:GetWidth()-224-24,.001,"raid titles use the full left column after their activity icon")
 T.near(boss[#boss-1]-view.title:GetWidth()-52,24,.001,"raid content leaves the planned gap before the boss column")
 T.near(view.canvas:GetWidth()-boss[#boss-1],224,.001,"raid summaries reserve the compact boss column")
end
T.ok(U.Tooltip.interactive.bossText:IsShown(),"an unavailable journal is displayed as unknown")
journalReady=true;U.Tooltip:RenderGroup()
T.ok(U.Tooltip.interactive.bossText:IsShown(),"missing progress is explained once instead of repeating unknown for every boss")
T.eq(journalInstance,22,"reading a raid directory restores the previously selected native instance");T.eq(journalDifficulty,14,"reading a raid directory restores the previous difficulty")
T.eq(U.Tooltip.interactive.bossText:GetText(),"队伍未提供首领进度","an available directory does not invent missing progress")
T.eq(U:ProgressText(raid,raid.details),"—","unavailable native progress stays absent, not zero")
raid.details.encounters={"Boss A"}
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",1)
T.eq(U.Tooltip.interactive:GetWidth(),880);T.ok(U.Tooltip.interactive.memberButtons[30]:IsShown(),"Shift exposes the entire native raid roster")
CheckRaidLeaderFooter(U.Tooltip.interactive,raid.leaderName,U,"WARRIOR")
T.eq(#U.Tooltip.interactive.memberButtons,30,"the member pool grows only to the roster actually opened")
T.eq(U.Tooltip.interactive.memberButtons[1].member,raidMembers[30],"the native raid leader is always first")
U.Tooltip.interactive.memberButtons[1]:Fire("OnEnter");U.Motion:Tick(.12)
T.eq(U.Tooltip.interactive.memberButtons[1]:IsEnabled(),false)
T.eq(U.Tooltip.interactive.memberButtons[1].hover:IsShown(),false,"display-only search members have no action hover")
U.Tooltip.interactive.memberButtons[1]:Fire("OnLeave")
T.eq(U.Tooltip.interactive.memberButtons[2].member,raidMembers[2]);T.eq(U.Tooltip.interactive.memberButtons[3].member,raidMembers[3])
T.eq(U.Tooltip.interactive.memberButtons[2].marks:IsShown(),false,"an expanded search roster never attributes relationship names to a member")
T.eq(U.Tooltip.interactive.memberButtons[2].realm:GetText():find("角色好友",1,true),nil,"relationship labels no longer repeat below member names")
T.eq(U.Tooltip.interactive.memberButtons[1].name:GetText(),"Raider30");T.eq(U.Tooltip.interactive.memberButtons[1].targetKey,"Raider30-Away");T.eq(U.Tooltip.interactive.memberButtons[1]:GetHeight(),56)
T.eq(U.Tooltip.interactive.memberButtons[1].name.wrap,true,"long character names stay within the member cell");T.eq(select(2,U.Tooltip.interactive.memberButtons[2].icon:GetPoint()),6,"member cells have equal compact horizontal padding");T.ok(U.Tooltip.interactive.memberButtons[1].name:GetWidth()<U.Tooltip.interactive.memberButtons[1]:GetWidth()-56,"leader crown and role keep their own space")
do
 local first=U.Tooltip.interactive.memberButtons[1];local nextRow=U.Tooltip.interactive.memberButtons[4]
 T.eq(first.icon:GetWidth(),24);T.eq(first.role:GetWidth(),18);T.eq(first.faction:GetWidth(),18);T.eq(first.leaderIcon:GetWidth(),14)
 local crown={first.leaderIcon:GetPoint()};T.eq(crown[1],"BOTTOM");T.eq(crown[2],first.icon);T.eq(crown[3],"TOP");T.eq(crown[4],0);T.eq(crown[5],1,"the member crown keeps a one-unit gap above its portrait")
 CheckInlineSearchMarks(first)
 T.eq(select(2,first.name:GetFont()),17);T.eq(select(2,first.realm:GetFont()),15)
 local role,faction={first.role:GetPoint()},{first.faction:GetPoint()}
 T.eq(role[1],"RIGHT");T.eq(role[2],first.icon);T.eq(role[3],"RIGHT");T.eq(role[5],0,"raid roles share the avatar center")
 T.eq(faction[2],first.role);T.eq(faction[3],"LEFT");T.eq(faction[5],0,"raid faction and role share one centerline")
 local a,b={first:GetPoint()},{nextRow:GetPoint()};T.near(a[#a]-b[#b],58,.001,"compact raid rows retain a two-pixel gap")
end
do
 local row=U.Members:Create(UIParent)
 local member={name="Member-Away",nameKey="Member-Away",class="MAGE",specName="Frost",assignedRole="HEALER",factionGroup=1}
 U.Members:Bind(row,member,250,false,true)
 local function CheckIdentityCenter()
  local icon,name,spec={row.icon:GetPoint()},{row.name:GetPoint()},{row.realm:GetPoint()}
  local textBottom=-spec[#spec]+math.max(row.realm:GetLineHeight(),row.realm:GetStringHeight())
  T.near(-icon[#icon]+row.icon:GetHeight()/2,(-name[#name]+textBottom)/2,.001,"member portrait aligns with the two-line identity, independent of minimum row height")
 end
 CheckIdentityCenter()
 U.Members:BindSearch(row,member,100,false,false);CheckIdentityCenter()
 member.specName="Long Frost";U.Members:BindSearch(row,member,250,false,false);CheckInlineSearchMarks(row);member.specName="Frost"
 U.Members:Bind(row,member,250,false,true)
 local portrait,role={row.icon:GetPoint()},{row.role:GetPoint()}
 T.near(portrait[#portrait-1]+row.icon:GetWidth()+role[4],row:GetWidth()-6,.001,"ordinary member roles retain the cell's right alignment")
 local bothWidth=row.name:GetWidth()
 T.eq(row.role:GetHeight(),18);T.eq(row.faction:GetHeight(),18);T.ok(row:IsEnabled(),"larger markers preserve member-row interaction")
 member.assignedRole=nil;U.Members:Bind(row,member,250,false,true)
 local faction={row.faction:GetPoint()}
 T.eq(row.role:IsShown(),false);T.eq(row.faction:IsShown(),true)
 T.eq(faction[2],row.icon);T.eq(faction[3],"RIGHT");T.eq(faction[5],0,"a faction without a role stays on the shared portrait center")
 T.eq(row.name:GetWidth(),bothWidth+22,"a missing role releases its eighteen-pixel slot and four-pixel gap")
 member.assignedRole="DAMAGER";member.factionGroup=nil;U.Members:Bind(row,member,250,false,true)
 T.eq(row.role:IsShown(),true);T.eq(row.faction:IsShown(),false)
 T.eq(row.name:GetWidth(),bothWidth+22,"a role without faction uses the same single-marker text boundary")
 member.assignedRole=nil;U.Members:Bind(row,member,250,false,true)
 T.eq(row.name:GetWidth(),bothWidth+46,"a reused row without markers returns both slots and the text gap")
 T.eq(row.role:IsShown(),false);T.eq(row.faction:IsShown(),false)
 member.isBNetFriend=true;member.assignedRole="HEALER";member.factionGroup=1;U.Members:BindRoster(row,member,250,false,true)
 local marks={row.marks:GetPoint()};faction={row.faction:GetPoint()}
 T.ok(row.marks.icons.bnet:IsShown());T.eq(marks[2],row.faction);T.eq(marks[3],"LEFT","relationships precede faction in current-roster rows")
 T.eq(faction[2],row.role);T.eq(faction[3],"LEFT","faction precedes the final role icon")
 member.factionGroup=nil;U.Members:BindRoster(row,member,250,false,true);marks={row.marks:GetPoint()}
 T.eq(marks[2],row.role);T.eq(marks[3],"LEFT","relationships close up against the role when faction is unknown")
 member.assignedRole=nil;U.Members:BindRoster(row,member,250,false,true);marks={row.marks:GetPoint()}
 T.eq(marks[2],row.icon);T.eq(marks[3],"RIGHT","relationships use the right edge when both trailing icons are absent")
 row:Hide()
end
T.eq(U.Tooltip.interactive.leader,nil);T.eq(U.Tooltip.interactive.leaderIcon,nil,"raid search headers omit the duplicate leader name and crown")
T.ok(U.Tooltip.interactive.memberButtons[1].leaderIcon:IsShown());T.eq(U.Tooltip.interactive.memberButtons[2].leaderIcon:IsShown(),false)
CheckRaidLeaderFooter(U.Tooltip.interactive,raid.leaderName,U,"WARRIOR")
T.eq(U.Tooltip.interactive.bossRows[1].status:GetText(),"已击败");T.eq(U.Tooltip.interactive.bossRows[2].status:GetText(),"未击败")
T.eq(U.Tooltip.interactive.bossCount:GetText(),"1/3");T.eq(U.Tooltip.interactive.bossRows[3].name:GetText(),"Boss C")
T.eq(U.Tooltip.interactive.bossRows[1]:GetWidth(),224,"expanded raids keep the same compact boss column")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",0)
T.eq(U.Tooltip.interactive:GetWidth(),880,"releasing Shift keeps the toggled expanded state")
U.Tooltip.interactive:Fire("OnEnter")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","RSHIFT",1)
T.eq(U.Tooltip.interactive:GetWidth(),624,"another Shift press collapses even while the pointer is inside the tooltip")
T.eq(U.Tooltip.interactive.memberButtons[30]:IsShown(),false,"collapsing hides the expanded roster")
CheckRaidLeaderFooter(U.Tooltip.interactive,raid.leaderName,U,"WARRIOR")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","RSHIFT",0)
T.eq(U.Tooltip.interactive:GetWidth(),624,"releasing Shift keeps the summary state")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",1)
U.Tooltip.interactive.memberButtons[1]:Fire("OnClick")
T.eq(U.Tooltip.member,nil,"expanded raid search members also remain display-only")
T.eq(U.Tooltip.interactive:GetWidth(),880);T.ok(not U.Tooltip.pinned)
T.eq(U.Tooltip.interactive.footer:GetText(),"按 Shift 收起名单","search tooltips no longer advertise member detail clicks")
U.Tooltip:Hide();U.Tooltip:ShowRoster(target,raidMembers)
T.eq(U.Tooltip.interactive.raidLeader:IsShown(),false);T.eq(U.Tooltip.interactive.raidLeaderIcon:IsShown(),false,"current-roster tooltips clear the search-only raid footer")
T.eq(U.Tooltip.interactive.memberButtons[1]:IsEnabled(),true,"a search member row becomes interactive for the current roster")
T.eq(U.Tooltip.interactive.memberButtons[1].member,raidMembers[1],"current rosters retain actual subgroup and raid-index order")
U.Tooltip.interactive.memberButtons[30]:Fire("OnClick");T.eq(U.Tooltip.member,raidMembers[30])
T.eq(U.Tooltip.outsideClicks:IsMouseEnabled(),false);T.eq(U.Tooltip.outsideClicks:GetScript("OnMouseDown"),nil)
T.eq(U.Tooltip.outsideClicks.events.GLOBAL_MOUSE_DOWN,true,"pinned details observe global clicks without taking mouse input")
U.Tooltip.interactive.mouseOver=true;U.Tooltip.outsideClicks:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
T.eq(U.Tooltip.interactive:IsShown(),true,"an internal click retains pinned details");U.Tooltip.interactive.mouseOver=nil
U.Tooltip.interactive.back:Fire("OnClick")
T.eq(U.Tooltip.interactive:GetWidth(),960,"returning from a member preserves the complete current roster")
T.eq(U.Tooltip.sourceRoster,raidMembers)
T.eq(U.Tooltip.outsideClicks.events.GLOBAL_MOUSE_DOWN,true,"returning to the pinned roster retains outside-click dismissal")
U.Tooltip.interactive.memberButtons[30]:Fire("OnClick");T.eq(U.Tooltip.member,raidMembers[30])
U.Tooltip.outsideClicks:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
T.eq(U.Tooltip.interactive:IsShown(),false,"an external click closes pinned details")
T.eq(U.Tooltip.outsideClicks.events.GLOBAL_MOUSE_DOWN,nil)
for _,mode in ipairs({"alt","ctrl"}) do
 local keyName=mode=="alt" and "Alt" or "Ctrl"
 local leftKey,rightKey="L"..mode:upper(),"R"..mode:upper()
 U.Tooltip:Hide();A:SetSetting("raidMembers",mode);U.Tooltip:ShowGroup(target,raid)
 T.eq(U.Tooltip.interactive:GetWidth(),624,"a configurable modifier still starts with a raid summary")
 T.eq(U.Tooltip.interactive.footer:GetText(),"按 "..keyName.." 展开成员名单","the collapsed hint follows the chosen modifier")
 for _,other in ipairs({"LSHIFT","RSHIFT","LALT","RALT","LCTRL","RCTRL"}) do
  if other~=leftKey and other~=rightKey then
   U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED",other,1)
   U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED",other,0)
   T.eq(U.Tooltip.interactive:GetWidth(),624,"unselected modifiers do not toggle the roster")
  end
 end
 U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED",leftKey,1)
 T.eq(U.Tooltip.interactive:GetWidth(),880);T.ok(U.Tooltip.interactive.memberButtons[30]:IsShown())
 T.eq(U.Tooltip.interactive.footer:GetText(),"按 "..keyName.." 收起名单","the expanded hint uses the same chosen modifier")
 U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED",leftKey,0)
 T.eq(U.Tooltip.interactive:GetWidth(),880,"releasing the chosen modifier preserves the expanded roster")
 U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED",rightKey,1)
 T.eq(U.Tooltip.interactive:GetWidth(),624,"the right-side modifier also toggles the roster")
 T.eq(U.Tooltip.interactive.footer:GetText(),"按 "..keyName.." 展开成员名单")
 U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED",rightKey,0)
 T.eq(U.Tooltip.interactive:GetWidth(),624)
end
U.Tooltip:Hide();A:SetSetting("raidMembers","always");U.Tooltip:ShowGroup(target,raid)
T.eq(U.Tooltip.interactive:GetWidth(),880,"the always setting opens the full roster")
T.eq(U.Tooltip.interactive.memberButtons[1]:IsEnabled(),false,"returning to search data disables a previously interactive roster row")
U.Tooltip.interactive.memberButtons[1]:Fire("OnClick");T.eq(U.Tooltip.member,nil)
T.eq(U.Tooltip.interactive.footer:GetText(),"","always-expanded search rosters have no obsolete member-click hint")
for _,key in ipairs({"LSHIFT","RSHIFT","LALT","RALT","LCTRL","RCTRL"}) do
 U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED",key,1)
 T.eq(U.Tooltip.interactive:GetWidth(),880,"modifiers do not collapse the always setting")
end
A:SetSetting("raidMembers","shift")
A:SetSetting("reduceMotion",false)
local tipScroll=U.Tooltip.interactive.scroll
tipScroll:Fire("OnMouseWheel",-1);T.ok(U.Motion.jobs[tipScroll],"tooltip wheel scrolling uses the shared finite motion driver")
U.Motion:Tick(.07);T.ok(tipScroll:GetVerticalScroll()>0 and tipScroll:GetVerticalScroll()<42,"tooltip wheel movement is interpolated")
U.Tooltip:Hide();T.eq(U.Tooltip.interactive.memberButtons[30].member,nil,"closing releases member bindings")
T.eq(U.Motion.jobs[tipScroll],nil,"tooltip hide stops its scroll interpolation")
do
 local buttons=U.Tooltip.interactive.memberButtons;local first=buttons[1]
 for i=31,40 do raidMembers[i]={name="Raider"..i.."-Away",nameKey="Raider"..i.."-Away",class="WARRIOR",assignedRole="DAMAGER"} end
 raid.numMembers,raid.maxNumPlayers=40,40;A:SetSetting("raidMembers","always")
 U.Tooltip:ShowGroup(target,raid)
 T.eq(#buttons,40,"opening a larger raid expands the existing member pool")
 T.eq(buttons[40].member,raidMembers[40]);T.ok(buttons[40]:IsVisible(),"the full forty-player roster remains accessible")
 local nodes=#S.nodes;U.Tooltip:Hide()
 local hides,widths=0,{};local hide=buttons[1].Hide;local view=U.Tooltip.interactive;local setWidth=view.SetWidth
 local titleReads,subtitleReads=0,0
 local titleHeight,subtitleHeight=view.title.GetStringHeight,view.subtitle.GetStringHeight
 local subtitlePoint,metricPoint,canvasHeight={view.subtitle:GetPoint()},{view.metrics[1].title:GetPoint()},view.canvas:GetHeight()
 view.title.GetStringHeight=function(self) titleReads=titleReads+1;return titleHeight(self) end
 view.subtitle.GetStringHeight=function(self) subtitleReads=subtitleReads+1;return subtitleHeight(self) end
 for _,button in ipairs(buttons) do button.Hide=function(self) hides=hides+1;return hide(self) end end
 view.SetWidth=function(self,width) widths[#widths+1]=width;return setWidth(self,width) end
 U.Tooltip:ShowGroup(target,raid)
 T.eq(hides,40,"one hover clears the warm member pool only once");T.same(widths,{880},"the raid goes directly to its final width")
 T.eq(titleReads,1,"the group title is measured only at its final width")
 T.eq(subtitleReads,1,"the group subtitle is measured only at its final width")
 T.same({view.subtitle:GetPoint()},subtitlePoint);T.same({view.metrics[1].title:GetPoint()},metricPoint);T.eq(view.canvas:GetHeight(),canvasHeight,"removing provisional measurements preserves the complete layout")
 T.eq(U.Tooltip.owner,target);T.eq(buttons[40].member,raidMembers[40]);T.ok(buttons[40]:IsVisible())
 for _,button in ipairs(buttons) do button.Hide=hide end;view.SetWidth=setWidth
 view.title.GetStringHeight,view.subtitle.GetStringHeight=titleHeight,subtitleHeight
 T.eq(#S.nodes,nodes,"reopening a roster reuses its native object high-water mark");T.eq(buttons[1],first)
 U.Tooltip:Hide();T.eq(buttons[40].member,nil,"closing clears newly grown member bindings too")
 for i=40,31,-1 do raidMembers[i]=nil end
 raid.numMembers,raid.maxNumPlayers=30,30;A:SetSetting("raidMembers","shift")
end
U.Tooltip:ShowGroup(target,raid);T.eq(U.Tooltip.interactive:GetWidth(),624,"a new tooltip starts in summary mode");U.Tooltip:LeaveOwner(target);U.Motion:Tick(.23)
T.eq(U.Tooltip.interactive:IsShown(),false,"leaving both owner and tooltip closes it through the native region mouse query")
T.eq(U.Motion.jobs[U.Tooltip],nil,"tooltip leave delay releases its motion job")
find.results:SetPixelOffset(11*find.results.rowHeight,false);T.eq(find.results.rows[1].key,113,"pixel scrolling reaches results beyond the visible pool without reintroducing an applied result")
local poolSize=#S.nodes
find.results:SetPixelOffset(20*find.results.rowHeight,false);find.results:SetPixelOffset(0,false)
T.eq(#S.nodes,poolSize,"scrolling reuses the fixed native row pool")
find.results:Fire("OnMouseWheel",-1);T.ok(U.Motion.jobs[find.results],"the actual result wheel event animates pixel scrolling")
U.Motion:Tick(.07);T.ok(find.results.pixelOffset>0 and find.results.pixelOffset<144,"result wheel scrolling reaches an intermediate pixel offset")
find.results:SetPixelOffset(0,false)
do
 local first=find.results.rows[1];local record=G:GetResult(first.key);local old=record.name
 record.name="First update";G:Notify("result",first.key);local pending=U.Motion.jobs[find]
 record.name="Latest update";G:Notify("result",first.key)
 T.ok(pending and U.Motion.jobs[find]==pending,"a result-event burst shares one pending render callback")
 T.eq(first.title:GetText(),old,"result events defer duplicate row work until the frame boundary")
 U.Motion:Tick(.01)
 T.eq(first.title:GetText(),"Latest update","the coalesced render uses the final record state")
 T.eq(U.Motion.jobs[find],nil,"the pending render releases itself immediately")
 record.name=old;find:RefreshResults()
end
do
 local records,status,errorText=G.records,G.state,G.error
 local setItems=find.results.SetItems;local fills,renders=0,0
 find.results.SetItems=function(self,ids,render)
  fills=fills+1
  return setItems(self,ids,function(...) renders=renders+1;return render(...) end)
 end
 G.state="done";G.error=nil;G:Notify("results")
 local completedRenders=renders;local ids=find.results.ids
 T.ok(completedRenders>0,"completion binds the visible results")
 G:Notify("search")
 T.eq(fills,1,"results then search completion binds the list only once")
 T.eq(renders,completedRenders,"completion state notification does not repaint result rows")
 local points=0;local originals={}
 for _,region in ipairs({find.context,find.resultCount,find.resultsHeader,find.results,find.emptyPanel}) do
  local previous=region.SetPoint;originals[region]=previous
  region.SetPoint=function(self,...) points=points+1;return previous(self,...) end
 end
 G:Notify("results");G:Notify("search")
 T.eq(points,0,"unchanged final layout reuses the five result anchors")
 for region,previous in pairs(originals) do region.SetPoint=previous end
 ids=find.results.ids
 G.state="waiting";G.error="Queued search";G:Notify("search")
 T.eq(find.results.ids,ids,"queued search retains the already bound result set")
 T.eq(find.refresh:IsEnabled(),false,"queued state disables refresh immediately")
 T.eq(find.statusMessage,"Queued search","queued feedback updates without a list repaint")
 G.records={};G.state="searching";G.error=nil;G:Notify("results");G:Notify("search")
 T.eq(find.emptyPanel:IsShown(),true);T.eq(find.emptyText:GetText(),U.L.searching)
 T.eq(find.start:IsShown(),false);T.eq(find.busyIcon:IsShown(),true)
 local emptyFills=fills
 G.state="waiting";G.error="Retry soon";G:Notify("search")
 T.eq(find.emptyText:GetText(),U.L.searchWaitingTitle);T.eq(find.emptyHelp:GetText(),"Retry soon")
 G.state="failed";G.error="Search failed";G:Notify("search")
 T.eq(find.emptyText:GetText(),U.L.searchFailedTitle);T.eq(find.emptyHelp:GetText(),"Search failed")
 T.eq(find.start:IsShown(),true);T.eq(find.busyIcon:IsShown(),false)
 G.state="done";G.error=nil;G:Notify("search")
 T.eq(find.emptyText:GetText(),U.L.noResults);T.eq(find.emptyHelp:GetText(),U.L.noResultsHelp)
 T.eq(fills,emptyFills,"empty-state transitions update immediately without rebinding rows")
 find.results.SetItems=setItems;G.records,G.state,G.error=records,status,errorText;find:RefreshResults()
end
find:SetFiltersOpen(true);T.ok(U.Motion.jobs[find.filterPanel]);find:SetFiltersOpen(false);T.eq(U.Motion.jobs[find.filterPanel],nil)
find:SelectCategory("seasonDungeon");T.ok(U.Motion.jobs[find.picker]);find:ClosePicker();T.eq(U.Motion.jobs[find.picker],nil)
A:SetSetting("reduceMotion",false);G.state="searching";find:ReadSearchState();T.ok(U.Motion.jobs[find.busyIcon],"only an active search animates the lychee")
find:ShowApplicationLimit();local closingRecords=G.records
local applicationClock=find.countdown
U:Hide(true);T.eq(next(U.Motion.jobs),nil,"closing releases scroll, tooltip and waiting jobs")
T.eq(find.countdown,nil,"closing releases the application countdown")
if applicationClock then T.eq(applicationClock.cancelled,true,"closing cancels the active countdown timer") end
T.eq(find.limitNotice:IsShown(),false,"leaving clears the quota notice")
T.eq(next(G.views),nil)
local nativeSpecIcon=U.C.Icon(U.frame,24)
U:SetMemberIcon(nativeSpecIcon,{class="WARRIOR",specName="武器",assignedRole="DAMAGER"})
T.eq(nativeSpecIcon.texture,100071,"a search member with only a native specialization name resolves through the class API")
U:SetMemberIcon(nativeSpecIcon,{class="WARRIOR",specName="神圣",assignedRole="HEALER"})
T.eq(nativeSpecIcon.texture,"Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES","an unmatched specialization never guesses from role or another class")
A:Open("find");G.records=closingRecords;find:RefreshResults()
local submissions=LFGListApplicationDialog.submissions;find:Apply(102)
T.eq(LFGListApplicationDialog.submissions,submissions+1,"closing and reopening preserves this login's configured quick application")
T.eq(U.activeModal,nil);T.eq(LFGListApplicationDialog.submitted.note,"Updated native note")
U:Hide(true)
-- The actual page stays painted until its window finishes leaving.
A:SetSetting("reduceMotion",false);A:Open("find");G.records=closingRecords;find:RefreshResults();U.Motion:Tick(.5)
local closingRow=find.results.rows[1];local closingTitle=closingRow.title:GetText()
T.ok(closingRow.key and closingRow:IsShown(),"close coverage starts from a real populated result row")
local closingLogoWidth,closingLogoHeight=U.logo:GetWidth(),U.logo:GetHeight()
U:Hide();T.eq(U.hiding,true);T.eq(closingRow:IsShown(),true,"closing preserves visible row bindings during Presence")
T.eq(U.logo:GetWidth(),closingLogoWidth,"closing does not snap a visible brand animation to its resting pose")
T.eq(U.logo:GetHeight(),closingLogoHeight)
T.eq(closingRow.title:GetText(),closingTitle);T.eq(U.frame:IsShown(),true)
U.Motion:Tick(.43);T.eq(U.frame:IsShown(),false);T.eq(next(G.views),nil);T.eq(U.Native.searchLease,nil,"the completed close releases browsing and native input ownership")
T.eq(U.brandMotion:IsPlaying(),false,"the brand animation stops once the window is hidden")
A:Open("find");G.records=closingRecords;find:RefreshResults();U.Motion:Tick(.5)
U:Hide();U.Motion:Tick(.1);U:Show("find");U.Motion:Tick(.5)
T.eq(U.frame:IsShown(),true,"an interrupted close cannot hide the reopened window");T.eq(U.hiding,nil);T.ok(G.views[find],"the reopened page keeps its live browsing subscription")
U:Hide();U.Motion:Tick(.1);A:SetSetting("reduceMotion",true)
T.eq(U.frame:IsShown(),false,"enabling reduced motion completes a running close");T.eq(next(G.views),nil);T.eq(U.Native.searchLease,nil)
T.eq(next(U.context.nativeControls),nil,"the final hidden window retains no leased native controls")
T.eq(next(U.Motion.jobs),nil,"the completed close leaves no UI animation task")
for _,page in ipairs({"find","create","notes"}) do
 A:Open(page);T.eq(U.navItems[page].active,true);T.eq(U.underline:IsShown(),true)
 A:Open("settings");T.eq(U.underline:IsShown(),false)
 for _,button in pairs(U.navItems) do T.eq(button.active,false) end
 U.navItems[page]:Fire("OnClick");T.eq(U.page,page,"the shared navigation leaves settings for any business page")
 T.eq(U.navItems[page].active,true);T.eq(U.underline:IsShown(),true,"returning restores the correct underline")
end
U:Hide(true)
-- Find tables use one compact line; notes retain their title hierarchy.
do
 T.near(U.Theme.width,1160*1.12,.001,"the main window is twelve percent wider")
 T.eq(U.Theme.height,840,"widening keeps the original window height")
 T.eq(select(2,find.appList.rows[1].title:GetFont()),19,"outgoing applications use the larger single-line title")
 T.eq(find.appList.rows[1].title:GetHeight(),26)
 local function Top(region) local point={region:GetPoint()};return -point[#point] end
 for _,row in ipairs({find.results.rows[1],notes.list.rows[1],notes.historyList.rows[1]}) do
  T.eq(select(2,row.title:GetFont()),row==find.results.rows[1] and 19 or 21)
  T.eq(row.title:GetHeight(),row==find.results.rows[1] and 26 or 28)
  if row==notes.list.rows[1] then
   T.eq(row.meta:IsShown(),false,"notes omit the class/spec subtitle")
   T.ok(Top(row.reason)-Top(row.title)-row.title:GetHeight()>=8,"note title and reason keep an eight-unit gap")
  elseif row==find.results.rows[1] then
   T.eq(Top(row.meta),Top(row.title),"the activity column and title share the result body center")
  else
   T.ok(Top(row.meta)-Top(row.title)-row.title:GetHeight()>=4,"content title and metadata keep a four-unit gap")
  end
 end
 T.eq(select(2,find.categories.rows[1].title:GetFont()),19)
 T.eq(select(2,find.activities.rows[1].title:GetFont()),19)
 T.eq(select(2,create.pickerResults.rows[1].title:GetFont()),19)
 local leaderPoint={find.results.rows[1].leader:GetPoint()}
 T.eq(leaderPoint[1],"LEFT");T.eq(leaderPoint[#leaderPoint],0,"the leader name centers on the complete result row")
 T.eq(find.results.rows[1].leaderIcon:IsShown(),false,"list rows omit the crown while the tooltip retains its leader markers")
end
-- Saved settings restore the form without storing, replacing or submitting text.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 local nativeActivities=C_LFGList.GetAvailableActivities
 local outsideSeason=g.Catalog:GetFilter("2")
 C_LFGList.GetAvailableActivities=function(category,group,flags)
  if category==2 and flags==outsideSeason then return {} end
  return nativeActivities(category,group,flags)
 end
 g.Catalog:GetActivity(2).shortName=GetDifficultyInfo(8)
 a:SetSetting("reduceMotion",true);a:Open("create")
 local page=u.pages.create;local entry=LFGListFrame.EntryCreation
 T.eq(page.favoritesExpanded,nil);T.eq(page.favoritesBody,nil,"collapsed favorites build no row controls")
 local collapsedHeight=page.rosterCard:GetHeight()
 T.eq(page.favoritesToggle:GetParent(),page.favoritesCard);T.eq(page.groupSummary:GetParent(),page.rosterCard)
 local function CardGap() local p={page.rosterCard:GetPoint()};return -p[#p]-page.favoritesCard:GetHeight() end
 T.eq(CardGap(),16,"the two right-side cards have a transparent gap")
 page:UsePreset({activityID=2,requiredItemLevel=321,requiredDungeonScore=3400,requiredPvpRating=0,privateGroup=true,autoAccept=true,isCrossFactionListing=true,generalPlaystyle=2})
 T.eq(page.favorite.selected,false);T.ok(page.favoriteIcon:GetTexture():find("favorite%-off"))
 page.favorite:Fire("OnClick");T.eq(#g.Presets:Get(),1);T.eq(page.favorite.selected,true);T.ok(page.favoriteIcon:GetTexture():find("favorite%-on"))
 page.favorite:Fire("OnClick");T.eq(#g.Presets:Get(),0,"clicking the selected star removes the current settings")
 page.favorite:Fire("OnClick");local saved=g.Presets:Get()[1]
 page.favoritesToggle:Fire("OnClick");T.ok(page.favoritesBody:IsShown())
 T.eq(CardGap(),16);T.eq(page.rosterCard:GetHeight(),collapsedHeight,"the roster summary stays compact as its independent card moves down")
 local list=page.favoritesList
 T.eq(#list.ids,1);T.eq(page.favoritesEmpty:IsShown(),false)
 T.eq(list.rows[1].title:GetText(),"Dungeon","a season-only favorite shows its dungeon, not the difficulty from shortName")
 T.ok(list.rows[1].meta:GetText():find(GetDifficultyInfo(8),1,true),"difficulty shares the conditions line below the activity title")
 T.ok(list.rows[1].conditions:GetText():find("321",1,true));T.ok(list.rows[1].conditions:GetText():find("3400",1,true))
 entry.Name:UserType("My draft");entry.Description.EditBox:UserType("My description")
 page.ilvl.box:SetText("300");T.eq(page.favorite.selected,false,"changing requirements updates the star state")
 list.clip.mouseOver=true;list.rows[1].create:Fire("OnClick")
 T.eq(g.published,nil,"applying saved requirements never publishes")
 T.eq(page:FormData().requiredItemLevel,321);T.eq(page:FormData().requiredDungeonScore,3400)
 T.eq(page:FormData().isPrivateGroup,true);T.eq(page:FormData().isAutoAccept,true)
 T.eq(page.favorite.selected,true)
 T.eq(entry.Name:GetText(),"My draft");T.eq(entry.Description.EditBox:GetText(),"My description","applying settings preserves the current native text")
 page:Submit();T.eq(g:GetListing().name,"My draft");T.eq(g:GetListing().comment,"My description")
 T.eq(g.Presets:Get()[1],saved,"publishing preserves explicitly saved favorites")
 T.eq(saved.name,nil);T.eq(saved.comment,nil)
 local activeListing=g:GetListing()
 T.eq(list.rows[1].create.label:GetText(),"应用")
 T.eq(list.rows[1].create:IsEnabled(),false)
 T.eq(list.rows[1].unavailable:IsShown(),false,"a recruiting favorite keeps Apply disabled without an extra explanatory row")
 T.eq(page.listingFavorite.selected,true,"the active listing has its own favorite state")
 page.ilvl.box:SetText("399")
 page.listingFavorite:Fire("OnClick")
 T.eq(#g.Presets:Get(),0,"the management star removes the listing settings, not the hidden draft")
 T.eq(page.favoritesEmpty:GetText(),"暂无收藏");T.eq(page.listingFavorite.selected,false)
 page.listingFavorite:Fire("OnClick");saved=g.Presets:Get()[1]
 T.eq(saved.requiredItemLevel,321,"saving during recruitment uses the confirmed listing requirements")
 T.eq(page.listingFavorite.selected,true);T.eq(saved.name,nil);T.eq(saved.comment,nil)
 T.eq(g:GetListing(),activeListing);T.eq(g.updated,nil,"favoriting never updates or ends recruitment")
 local published=g.published;page:UsePreset(saved);T.eq(g.published,published,"saved creation does not overwrite a live listing")
 g:RemoveListing()
 T.eq(list.rows[1].create:IsEnabled(),true);T.eq(list.rows[1].unavailable:IsShown(),false,"ending recruitment restores Apply without adding explanatory text")
 page:UsePreset(saved)
 T.eq(g:GetListing(),nil,"reapplying unchanged settings still requires the Publish button")
 entry.Name:UserType("");entry.Description.EditBox:UserType("")
 local basic={activityID=2,requiredItemLevel=0,requiredDungeonScore=0,requiredPvpRating=0,privateGroup=false,autoAccept=false,isCrossFactionListing=true,generalPlaystyle=2}
 page:UsePreset(basic);T.eq(entry.Name:GetText(),"");T.eq(g:GetListing(),nil,"saved activity does not generate a listing title")
 page.favorite:Fire("OnClick");T.eq(#g.Presets:Get(),2)
 g.manageListing=false;published=g.published;page:UsePreset(saved);T.eq(g.published,published,"permission loss blocks saved creation through the same business boundary")
 g.manageListing=true
 for i=1,20 do g.Presets:ToggleFavorite({activityID=2,requiredItemLevel=280+i}) end
 T.eq(#list.ids,22);T.ok(#list.rows<=5,"saved entries scroll through three visible rows and two overscan rows")
 list:SetPixelOffset(list.contentHeight,false);T.eq(list.rows[#list.rows].key,nil,"unused pool rows release their entries")
 page.favoritesToggle:Fire("OnClick");T.eq(page.favoritesBody:IsShown(),false);T.eq(list.rows[1].key,nil)
 T.eq(page.rosterCard:GetHeight(),collapsedHeight);T.eq(CardGap(),16)
 page.favoritesToggle:Fire("OnClick");a:Open("find");a:Open("create");T.eq(page.favoritesExpanded,false,"returning to creation starts with favorites collapsed")
 -- Native summaries and both factions share the production tooltip and applicant rows.
 g.listing={activityID=2,name="Listing",requiredItemLevel=300}
 local one={name="Alliance-Away",nameKey="Alliance-Away",class="MAGE",assignedRole="DAMAGER",factionGroup=1,applicantID=91,itemLevel=326,dungeonScore=3641,dungeonScores={mapScore=456,current={name="Current dungeon",level=18,timed=true},best={name="Best dungeon",level=19,timed=false}}}
 local two={name="Horde-Away",nameKey="Horde-Away",class="WARRIOR",assignedRole="TANK",factionGroup=0}
 g.applicants[91]={id=91,status="applied",activityID=2,members={one,two}};g:Notify("listing");g:Notify("applicants")
 local batch=page.batchPool[1];T.ok(batch.people[1].faction.texture:find("faction%-alliance"));T.ok(batch.people[2].faction.texture:find("faction%-horde"))
 local rarity=C_ChallengeMode.GetKeystoneLevelRarityColor;local colorReads=0
 C_ChallengeMode.GetKeystoneLevelRarityColor=function(level)
  colorReads=colorReads+1
  return level==18 and {r=.64,g=.21,b=.93} or {r=1,g=.5,b=0}
 end
 u.Tooltip:ShowPlayer(batch.people[1],one)
 local tip=u.Tooltip.interactive
 T.same({tip.metrics[1].title:GetText(),tip.metrics[2].title:GetText(),tip.metrics[3].title:GetText()},{"装等","单本分","大秘境评分"})
 T.same({tip.metrics[1].value:GetText(),tip.metrics[2].value:GetText(),tip.metrics[3].value:GetText()},{"326","456","3641"})
 local previousX,valueY
 for i=1,3 do
  local metric=tip.metrics[i];local title,value={metric.title:GetPoint()},{metric.value:GetPoint()}
  local alignment=i==1 and "LEFT" or "CENTER"
  T.eq(metric.title.justify,alignment);T.eq(metric.value.justify,alignment)
  T.eq(title[#title-1],value[#value-1]);T.eq(metric.title:GetWidth(),metric.value:GetWidth(),"each number shares its heading's column")
  if i==1 then T.eq(title[#title-1],0,"item level starts at the portrait and body left edge") end
  T.ok(value[#value]<title[#title]-metric.title:GetHeight(),"numbers sit on the second row below all headings")
  if valueY then T.eq(value[#value],valueY,"all three numbers share one baseline") end
  if previousX then T.near(title[#title-1]-previousX,metric.title:GetWidth()+16,.001,"tooltip numeric columns retain equal spacing") end
  T.ok(metric.title:GetStringWidth()<=metric.title:GetWidth(),"the complete heading fits its column")
  previousX,valueY=title[#title-1],value[#value]
 end
 T.same(tip.metrics[2].value.color,{.3,.8,.2},"the tooltip uses the same native map-score color as the applicant row")
 local realAlign=tip.metrics[1].value.SetJustifyH
 local realVertical=tip.metrics[1].value.SetJustifyV
 local horizontalResets,middleResets=0,0
 for i=1,3 do
  local expectedAlignment=i==1 and "LEFT" or "CENTER"
  tip.metrics[i].value.SetJustifyH=function(self,alignment)
   if alignment~=expectedAlignment then horizontalResets=horizontalResets+1 end
   return realAlign(self,alignment)
  end
  tip.metrics[i].value.SetJustifyV=function(self,alignment)
   if alignment~="TOP" then middleResets=middleResets+1 end
   return realVertical(self,alignment)
  end
 end
 for i=1,3 do u.Tooltip:RefreshApplicant() end
 for i=1,3 do tip.metrics[i].value.SetJustifyH=realAlign;tip.metrics[i].value.SetJustifyV=realVertical end
 T.eq(horizontalResets,0,"refreshes preserve the left item-level column and centered score columns throughout measurement")
 T.eq(middleResets,0,"refreshes keep the displayed numeric baseline throughout measurement")
 T.eq(select(2,tip.title:GetFont()),19);T.eq(tip.dungeonRows[1].keyLevel:GetText(),"+18");T.eq(tip.dungeonRows[2].status:GetText(),"未限时");T.ok(tip.playerFaction:IsShown())
 T.eq(tip.dungeonRows[1].label:GetText(),"当前");T.eq(tip.dungeonRows[2].label:GetText(),"最佳")
 T.same(tip.dungeonRows[1].keyLevel.color,{.64,.21,.93});T.same(tip.dungeonRows[2].keyLevel.color,{1,.5,0},"both levels use native keystone rarity colors")
 one.dungeonScores.current.timed=false;u.Tooltip:ShowPlayer(batch.people[1],one)
 T.eq(tip.dungeonRows[1].status:GetText(),"未限时");T.same(tip.dungeonRows[1].keyLevel.color,{.64,.21,.93},"overtime changes status, not level rarity")
 T.eq(colorReads,2,"unchanged levels reuse each row's applied color")
 one.dungeonScores.current.level=19;u.Tooltip:ShowPlayer(batch.people[1],one)
 T.same(tip.dungeonRows[1].keyLevel.color,{1,.5,0},"a recycled level row refreshes its native color");T.eq(colorReads,3)
 one.dungeonScores.current.durationMs=1952000;one.dungeonScores.current.timeLimitSeconds=1980;one.dungeonScores.current.timed=true
 one.dungeonScores.best.durationMs=1900000;one.dungeonScores.best.timeLimitSeconds=1800
 local nodes=#f.S.nodes
 u.Tooltip:ShowPlayer(batch.people[1],one)
 T.eq(tip.dungeonRows[1].status:GetText(),"|cff7cd99b32:32|r/33:00","only current elapsed time is green; its own limit follows the color reset")
 T.eq(tip.dungeonRows[2].status:GetText(),"|cff9d9d9d31:40|r/30:00","an overtime best record is gray and uses its own limit")
 T.same(tip.dungeonRows[1].status.color,u.Theme.dim);T.same(tip.dungeonRows[2].status.color,u.Theme.dim)
 T.eq(#f.S.nodes,nodes,"time display reuses the existing two record rows")
 one.dungeonScores.current.timeLimitSeconds=100
 for _,case in ipairs({
  {90000,"ffae63","1:30"},{90001,"c08aff","1:30"},
  {95000,"c08aff","1:35"},{95001,"68b7ff","1:35"},
  {97000,"68b7ff","1:37"},{97001,"7cd99b","1:37"},
  {100000,"7cd99b","1:40"},{100001,"9d9d9d","1:40"},
 }) do
  one.dungeonScores.current.durationMs=case[1];u.Tooltip:ShowPlayer(batch.people[1],one)
  T.eq(tip.dungeonRows[1].status:GetText(),"|cff"..case[2]..case[3].."|r/1:40","time tiers use exact duration, not rounded display seconds")
  T.same(tip.dungeonRows[1].status.color,u.Theme.dim,"separator and limit keep their neutral base color")
 end
 one.dungeonScores.current.durationMs=30000;one.dungeonScores.current.timed=false;u.Tooltip:ShowPlayer(batch.people[1],one)
 T.eq(tip.dungeonRows[1].status:GetText(),"|cff9d9d9d0:30|r/1:40","an unsuccessful attempt never receives a timed color")
 one.dungeonScores.current.timed=true;one.dungeonScores.current.durationMs=1703000;one.dungeonScores.current.timeLimitSeconds=1920
 one.dungeonScores.best.timed=true;one.dungeonScores.best.durationMs=1788000;one.dungeonScores.best.timeLimitSeconds=1920
 u.Tooltip:ShowPlayer(batch.people[1],one)
 T.eq(tip.dungeonRows[1].status:GetText(),"|cffffae6328:23|r/32:00","the reported 28:23 run has more than ten percent remaining and is orange")
 T.eq(tip.dungeonRows[2].status:GetText(),"|cffc08aff29:48|r/32:00","the reported 29:48 run has more than five percent remaining and is purple")
 one.dungeonScores.best.timed=false
 one.dungeonScores.current.timeLimitSeconds=nil;u.Tooltip:ShowPlayer(batch.people[1],one)
 T.eq(tip.dungeonRows[1].status:GetText(),"限时","missing limits keep the available completion state")
 one.dungeonScores.best.durationMs=nil;u.Tooltip:ShowPlayer(batch.people[1],one)
 T.eq(tip.dungeonRows[2].status:GetText(),"未限时","missing duration is never fabricated")
 C_ChallengeMode.GetKeystoneLevelRarityColor=rarity
 u.Tooltip:Hide();u.Tooltip:ShowGroup(page.frame,{name="Party",numMembers=2,maxNumPlayers=5,details={members={one,two}}})
 T.eq(select(2,tip.memberButtons[1].name:GetFont()),17);T.eq(tip.memberButtons[1].faction:IsShown(),false);T.eq(tip.memberButtons[2].faction:IsShown(),false)
 two.factionGroup=nil;g:Notify("applicants");T.eq(batch.people[2].faction:IsShown(),false,"reused rows clear a missing faction")
 u:Hide(true)
end

-- Relations can repaint after native deletion but before the queued applicant notification.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 g.listing={activityID=2,name="Recruiting"}
 for id=1,2 do g.applicants[id]={id=id,status="applied",displayOrderID=id,members={{name="Member"..id.."-Away",nameKey="Member"..id.."-Away",class="MAGE",assignedRole="DAMAGER"}}} end
 a:Open("create");local page=u.pages.create
 g.applicants[1]=nil
 g:Notify("relations")
 T.same(page.appIDs,{2},"a repaint drops deleted IDs before painting the remaining applicants")
 T.eq(page.batchPool[1].appID,2);T.ok(page.batchPool[1]:IsShown())
 g.applicants[2]=nil
 g:Notify("relations")
 T.eq(#page.appIDs,0);T.ok(page.empty:IsShown());T.eq(page.batchPool[1]:IsShown(),false)
 u:Hide(true)
end
-- Rejection text follows party identity and its timer only repaints visible labels.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local now=0;GetTime=function() return now end
 g.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}
 for id=1,3 do g.records[id]={id=id,partyGUID="Party-"..id,name="Group "..id,activityID=2,activity=g.Catalog:GetActivity(2),categoryID=2,numMembers=1,maxNumPlayers=5,age=10} end
 a:Open("find");local page=u.pages.find
 T.eq(page.declineClock,nil);T.near(page.results.rowHeight,53,.001,"ordinary results use the tighter single-line row height")
 now=59;g.declinedParties["Party-2"]=0;g:Notify("applications")
 T.same(page.results.ids,{1,3,2});T.ok(page.declineClock);T.eq(page.countdown,nil,"rejection text does not need an active application")
 local function Row(id) for _,row in ipairs(page.results.rows) do if row.key==id then return row end end;error("missing result "..id) end
 T.eq(Row(2).declined:GetText(),locale=="zhCN" and "刚刚拒绝了你" or "Rejected you just now")
 T.eq(Row(1).declined:IsShown(),false)
 local reads,sorts,binds=0,0,0
 local details,getResults,setItems=g.Results.GetDetails,g.GetResults,page.results.SetItems
 g.Results.GetDetails=function(self,...) reads=reads+1;return details(self,...) end
 g.GetResults=function(self,...) sorts=sorts+1;return getResults(self,...) end
 page.results.SetItems=function(self,...) binds=binds+1;return setItems(self,...) end
 now=60;fresh.base.AdvanceClock(1)
 T.eq(Row(2).declined:GetText(),locale=="zhCN" and "1分钟前拒绝了你" or "Rejected you 1 min ago","the first refresh occurs at the rejection's minute boundary")
 now=120;fresh.base.AdvanceClock(60)
 T.eq(Row(2).declined:GetText(),locale=="zhCN" and "2分钟前拒绝了你" or "Rejected you 2 min ago")
 T.eq(reads,0,"minute updates never read member details");T.eq(sorts,0,"minute updates never sort results");T.eq(binds,0,"minute updates never rebind lists")
 g.Results.GetDetails,g.GetResults,page.results.SetItems=details,getResults,setItems
 local rejected=g.records[2];g.records[2]=nil;rejected.id=20;rejected.name="Changed group title";g.records[20]=rejected
 g.records[3].name=rejected.name;g:Notify("results")
 T.eq(Row(20).declined:GetText(),locale=="zhCN" and "2分钟前拒绝了你" or "Rejected you 2 min ago","new tickets and titles retain the same party's rejection")
 T.eq(Row(3).declined:IsShown(),false,"another party with the same title is not marked")
 for id=4,19 do g.records[id]={id=id,partyGUID="Party-"..id,name="Group "..id,activityID=2,activity=g.Catalog:GetActivity(2),categoryID=2,numMembers=1,maxNumPlayers=5,age=10} end
 g:Notify("results");T.eq(page.declineClock,nil,"offscreen rejected results do not keep a display timer")
 page.results:SetPixelOffset(100000,false)
 local declineReads,visible,readDecline=0,0,g.Applications.GetDeclinedAt
 for _,row in ipairs(page.results.rows) do if row.key and row._hitVisible then visible=visible+1 end end
 g.Applications.GetDeclinedAt=function(self,...) declineReads=declineReads+1;return readDecline(self,...) end
 now=180;fresh.base.AdvanceClock(60)
 T.eq(declineReads,visible,"the minute callback reads rejection times for visible rows only")
 g.Applications.GetDeclinedAt=readDecline
 page.results:SetPixelOffset(0,false);T.eq(page.declineClock,nil,"scrolling the final rejection out of view stops its timer")
 g.declinedParties["Party-19"]=now-59;g:Notify("results")
 T.eq(page.declineClock,nil)
 local rejectedIndex
 for index,id in ipairs(page.results.ids) do if id==19 then rejectedIndex=index;break end end
 T.ok(rejectedIndex,"the rejection used for the viewport edge remains in the result set")
 local edge=page.results.geometryOffsets[rejectedIndex]-page.results:GetHeight()
 page.results:SetPixelOffset(edge,false);local edgeRow=Row(19)
 T.eq(page.declineClock,nil,"a rejected row merely touching the viewport does not start a timer")
 local bound={};for _,row in ipairs(page.results.rows) do if row.key then bound[row.key]=true end end
 reads=0;g.Results.GetDetails=function(self,record,...)
  if bound[record.id] then reads=reads+1 end
  return details(self,record,...)
 end
 page.results:SetPixelOffset(edge+1,false)
 T.eq(Row(19),edgeRow);T.eq(reads,0,"revealing a bound partial row does not re-read any already-bound details; the next variable-height buffer row may bind")
 T.ok(page.declineClock,"revealing an already-bound rejection also restarts its timer")
 g.Results.GetDetails=details
 page.results:SetPixelOffset(100000,false);local reused=page.results.rows[1]
 T.ok(page.declineClock,"binding a visible rejection restarts the unique minute timer")
 now=181;fresh.base.AdvanceClock(1)
 T.eq(Row(19).declined:GetText(),locale=="zhCN" and "1分钟前拒绝了你" or "Rejected you 1 min ago","scrolling uses the newly visible rejection's minute boundary")
 local timer=page.declineClock
 page.results:SetPixelOffset(0,false);T.eq(reused.declined:GetText(),"");T.eq(reused.declined:IsShown(),false,"row reuse removes the old rejection label")
 T.eq(page.declineClock,nil);T.eq(timer.cancelled,true)
 local normal=g.records[1];g.records={[1]=normal};g:Notify("results")
 T.eq(page.declineClock,nil);T.eq(timer.cancelled,true);T.near(page.results.rowHeight,53,.001,"a view without rejected results restores the compact single-line layout")
 g.records[20]=rejected;g:Notify("results");timer=page.declineClock
 u:Hide(true);T.eq(timer.cancelled,true);T.eq(page.declineClock,nil)
 for _,row in ipairs(page.results.rows) do T.eq(row.declined:GetText(),"") end
 now=240;a:Open("find");T.ok(page.declineClock);T.eq(Row(20).declined:GetText(),locale=="zhCN" and "4分钟前拒绝了你" or "Rejected you 4 min ago","re-entering recovers the session's rejection time")
 a:SetSetting("reduceMotion",false);u:Hide();T.eq(u.hiding,true)
 now=300;fresh.base.AdvanceClock(60);T.eq(page.declineClock,nil,"a callback during window exit cannot renew the timer")
 u:Show("find");T.ok(page.declineClock,"reversing the exit restores the current visible rejection timer")
 u:Hide(true)
end

-- Offscreen applications still own the countdown until the final deadline.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local clock,now=GetTime,0;GetTime=function() return now end
 for i=1,5 do g.apps[i]={id=i,name="Application "..i,categoryID=2,status=i==5 and "applied" or "invited",expiresAt=i==5 and 90 or nil} end
 a:Open("find");local page=u.pages.find;page:ShowApplicationLimit()
 T.ok(page.countdown)
 now=1;fresh.base.AdvanceClock(1)
 T.ok(page.countdown,"four invited rows do not stop an offscreen applied entry's countdown")
 page.appList:SetPixelOffset(999,false)
 local row;for _,candidate in ipairs(page.appList.rows) do if candidate.key==5 then row=candidate;break end end
 T.eq(row.status:GetText(),"1:29")
 now=5;fresh.base.AdvanceClock(1);T.eq(row.status:GetText(),"1:25","scrolling to the pending entry keeps updating its remaining time")
 now=90;fresh.base.AdvanceClock(1)
 T.eq(page.countdown,nil,"the final display deadline stops the countdown")
 T.eq(g.apps[5].status,"applied","a display deadline does not invent a native terminal status")
 g.apps[5].expiresAt=120;g:Notify("applications");T.ok(page.countdown,"a refreshed future deadline restarts the countdown")
 now=91;fresh.base.AdvanceClock(1);T.eq(row.status:GetText(),"0:29")
 u:Hide(true);T.eq(page.countdown,nil);GetTime=clock
end
-- Applicant details keep the selected identity when native member slots are reused.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local function Member(name,score)
  return {applicantID=71,name=name.."-Away",nameKey=name.."-Away",class="MAGE",assignedRole="DAMAGER",itemLevel=320,dungeonScore=score}
 end
 local original=Member("Original",2500)
 local app={id=71,status="applied",activityID=2,members={original}}
 g.listing={activityID=2,name="Recruitment"};g.applicants[71]=app;a:Open("create")
 local page,tip=u.pages.create,u.Tooltip
 page.batchScroll.mouseOver=true;page.batchPool[1].people[1].tooltipArea:Fire("OnEnter")
 T.eq(tip.selectedMemberID,"Original-Away")
 original.name,original.nameKey="Replacement-Away","Replacement-Away"
 local current=Member("Original",3100);app.members[2]=current;g:Notify("applicants")
 T.eq(tip.member,current,"an in-place applicant slot replacement follows the selected identity to its new slot")
 T.eq(tip.interactive.metrics[3].value:GetText(),"3100")
 current.name,current.nameKey="Another-Away","Another-Away";g:Notify("applicants")
 T.eq(tip.member,nil);T.eq(tip.interactive:IsShown(),false,"details never silently switch to the new occupant of a selected slot")
 local function OpenCopy()
  tip:Hide();tip:ShowApplicants(page.batchPool[1],app)
  tip.interactive.memberButtons[1]:Fire("OnClick")
  local x,y=tip.positionX,tip.positionY
  tip.interactive.wcl:Fire("OnClick")
  T.ok(tip.member);T.ok(tip.interactive.copyField:IsShown());T.eq(u.activeModal,nil)
  return x,y
 end
 app.members={Member("Original",3200)};g:Notify("applicants")
 local x,y=OpenCopy()
 app={id=71,status="applied",activityID=1,members={Member("Other",1000),Member("Original",3300)}}
 g.applicants[71]=app;g:Notify("applicants")
 T.eq(tip.member,app.members[2],"copying follows the current applicant record and member identity")
 T.ok(tip.pinned);T.ok(tip.interactive.back:IsShown())
 T.eq(tip.positionX,x);T.eq(tip.positionY,y,"inline copying keeps the pinned position")
 T.eq(tip.interactive.metrics[2].value:IsShown(),false,"restored detail uses the current recruitment activity")
 tip.interactive.back:Fire("OnClick");T.eq(tip.sourceApp,app);T.eq(tip.member,nil)
 OpenCopy();g.applicants[71]=nil;g:Notify("applicants")
 T.eq(tip.member,nil);T.eq(tip.interactive:IsShown(),false,"a removed application closes the inline copy")
 g.applicants[71]=app;g:Notify("applicants");OpenCopy()
 app.members[1].name,app.members[1].nameKey="NewOccupant-Away","NewOccupant-Away"
 g:Notify("applicants")
 T.eq(tip.member,nil);T.eq(tip.interactive:IsShown(),false,"inline copy retains the original identity even when the saved table is rewritten")
 u:Hide(true)
end
-- Applicant detail scope follows its recruitment activity, and personal markers
-- share the full identity block's center instead of sitting below the portrait.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local person={applicantID=81,applicantIndex=1,name="RaidGuest-Away",nameKey="RaidGuest-Away",class="MAGE",localizedClass="法师",specName="冰霜",assignedRole="DAMAGER",factionGroup=1,itemLevel=324,dungeonScore=0,subgroup=1}
 local app={id=81,status="applied",activityID=1,members={person}}
 g.listing={activityID=1,name="Raid recruitment"};g.applicants[81]=app
 person.dungeonScores={current={name="Cached dungeon",level=18,timed=true}}
 local dungeonReads=0
 g.GetApplicantDungeonScores=function(_,member) dungeonReads=dungeonReads+1;return member.dungeonScores end
 a:Open("create")
 local page,tip=u.pages.create,u.Tooltip
 local row=page.batchPool[1].people[1]
 page.batchScroll.mouseOver=true;row.tooltipArea:Fire("OnEnter")
 local view=tip.interactive
 T.eq(tip.member,person,"the actual applicant identity hover opens its details")
 T.eq(view.metrics[1].value:GetText(),"324");T.ok(view.metrics[1].value:IsShown())
 T.eq(view.metrics[2].title:IsShown(),false);T.eq(view.metrics[2].value:IsShown(),false,"raid applicant details have no rating or unrated placeholder")
 T.eq(dungeonReads,0,"raid applicants never request Mythic+ detail data")
 T.eq(view.dungeonTitle:IsShown(),false);T.eq(view.dungeonEmpty:IsShown(),false,"raid details do not retain an empty Mythic+ section")
 app.activityID=2;g:Notify("applicants")
 T.ok(view.metrics[2].value:IsShown(),"an open applicant detail follows an activity change without reopening")
 app.activityID=1;g:Notify("applicants");T.eq(view.metrics[2].value:IsShown(),false)
 dungeonReads=0
 T.eq(select(2,view.title:GetFont()),19);T.eq(view.icon:GetWidth(),36)
 T.eq(view.playerRole:GetWidth(),16);T.eq(view.playerFaction:GetWidth(),16)
 local function CheckIdentity()
  local title,summary,role,faction={view.title:GetPoint()},{view.summary:GetPoint()},{view.playerRole:GetPoint()},{view.playerFaction:GetPoint()}
  local bottom=summary[#summary]-math.max(20,view.summary:GetStringHeight())
  T.eq(role[1],"RIGHT");T.eq(role[2],view.canvas);T.eq(role[3],"TOPRIGHT")
  T.near(role[5],(title[#title]+bottom)/2,.001,"personal markers center on the complete name, realm and specialization block")
  T.eq(faction[2],view.playerRole);T.eq(faction[3],"LEFT");T.eq(faction[5],0)
  T.eq(view.subtitle:IsShown(),false,"the realm shares the name line instead of taking a third identity line");T.eq(view.summary:GetWidth(),view.title:GetWidth())
  T.ok(48+view.title:GetWidth()+12<=view.canvas:GetWidth()-38,"all identity text leaves room for both right-side markers")
 end
 CheckIdentity()
 local baseHeight=view:GetHeight()
 local name,key,spec=person.name,person.nameKey,person.specName
 local longName,longRealm=string.rep("长名字",8),string.rep("长服务器",6)
 person.name=longName.."-"..longRealm;person.nameKey=person.name;person.specName=string.rep("专精",10)
 tip:Hide();tip:ShowPlayer(row,person)
 T.eq(view.title:GetText(),longName.."-"..longRealm)
 T.ok(view.title:GetStringHeight()>22);T.ok(view:GetHeight()>baseHeight,"long identity fields grow the detail without overlap")
 CheckIdentity()
 person.name,person.nameKey,person.specName=name,key,spec
 tip:Hide();person.applicantID=nil;tip:ShowApplicants(row,app);view.memberButtons[1]:Fire("OnClick")
 T.eq(view.metrics[2].value:IsShown(),false,"the applicant-list source also supplies its raid activity")
 T.eq(dungeonReads,0);T.ok(view.back:IsShown());view.back:Fire("OnClick");T.eq(tip.sourceApp,app)
 person.applicantID=81;app.activityID=2
 tip:Hide();tip:ShowPlayer(row,person)
 T.ok(view.metrics[3].value:IsShown());T.eq(view.metrics[3].value:GetText(),"暂无","dungeon zero rating stays visible even while the global listing is a raid")
 T.eq(view.metrics[2].value:GetText(),"—","an unavailable current-map score keeps its own placeholder")
 T.eq(dungeonReads,1);T.ok(view.dungeonTitle:IsShown())
 app.activityID=1;tip:Hide();tip:ShowPlayer(row,person)
 T.eq(dungeonReads,1);T.eq(view.metrics[2].value:IsShown(),false)
 for _,record in ipairs(view.dungeonRows) do T.eq(record:IsShown(),false,"raid rendering clears previously visible dungeon rows") end
 tip:Hide();tip:ShowRoster(page.groupSummary,{person});view.memberButtons[1]:Fire("OnClick")
 T.eq(tip.sourceRoster[1],person);T.ok(view.metrics[2].value:IsShown(),"the current-roster source retains personal rating during raid recruitment")
 local inRaid=IsInRaid;_G.IsInRaid=function() return true end
 tip:Hide();person.applicantID=nil;tip:ShowPlayer(row,person)
 T.ok(view.metrics[2].value:IsShown(),"merely being in a raid never hides a general player's rating")
 _G.IsInRaid=inRaid
 local getActivity=g.Catalog.GetActivity
 g.Catalog.GetActivity=function(self,id) if id==900 then return {id=900,categoryID=4,isPvpActivity=true,isRatedPvpActivity=true} end;return getActivity(self,id) end
 person.applicantID=81;app.activityID=900;person.dungeonScores=nil;person.ratingKind="pvp";person.rating=1800;person.pvpRatingInfo={activityName="3v3"}
 tip:Hide();tip:ShowPlayer(row,person)
 T.eq(view.metrics[1].title:GetText(),"PvP 装等");T.eq(view.metrics[2].title:GetText(),"3v3");T.eq(view.metrics[2].value:GetText(),"1800")
 T.ok(view.metrics[2].value:IsShown(),"PvP applicant rating is restored after raid details")
 local function TopOffset(region) local point={region:GetPoint()};return point[#point] end
 for _,metric in ipairs({view.metrics[1],view.metrics[2]}) do
  T.eq(metric.title:GetHeight(),24);T.eq(metric.value:GetHeight(),24,"player labels and numbers each use a single-line box")
  T.eq(metric.title.justifyV,"TOP");T.eq(metric.value.justifyV,"TOP")
  T.eq(TopOffset(metric.title)-metric.title:GetHeight()-4,TopOffset(metric.value),"player numbers sit beneath their headings")
 end
 local actionTop=TopOffset(view.wcl)
 person.pvpRatingInfo.activityName=string.rep("Long rated arena ",5);tip:RenderPlayer(person)
 local wrappedHeight=view.metrics[2].title:GetStringHeight()
 T.ok(wrappedHeight>24,"the long rating label exercises real wrapping")
 for i=1,2 do
  T.eq(view.metrics[i].title:GetHeight(),wrappedHeight);T.eq(view.metrics[i].value:GetHeight(),24)
  T.eq(TopOffset(view.metrics[i].value),TopOffset(view.metrics[i].title)-wrappedHeight-4,"both numbers clear the full wrapped heading")
 end
 T.ok(TopOffset(view.wcl)<actionTop,"actions move below the complete wrapped metric row")
 person.pvpRatingInfo.activityName="3v3";tip:RenderPlayer(person)
 T.eq(view.metrics[2].value:GetHeight(),24,"reusing a player detail releases the previous wrapped height")
 tip:ResetInteractive(row,440)
 T.eq(view.metrics[2].value:GetHeight(),24);T.eq(view.metrics[2].value.justifyV,"MIDDLE","other tooltip views restore the standard value alignment")
 person.assignedRole=nil;person.factionGroup=nil;tip:Hide();tip:ShowPlayer(row,person)
 T.eq(view.playerRole:IsShown(),false);T.eq(view.playerFaction:IsShown(),false)
 T.eq(view.title:GetWidth(),view.canvas:GetWidth()-48,"unknown markers leave the full identity text width")
 tip:Hide();g.Catalog.GetActivity=getActivity;u:Hide(true)
end
-- The real Listing service must survive delayed native publication, delisting,
-- and another publish; a mocked UI Publish method cannot cover this contract.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local active,pending
 local creates,titleChecks=0,0
 g.Game={RefreshSubscriptions=function() end}
 g.Applicants={TryAutoInvite=function() end}
 dofile("addon/LycheeGroup_Group/Listing.lua")
 function g:GetListing() return self.Listing:GetListing() end
 function g:Publish(data) return self.Listing:Publish(data) end
 function g:Update(data) return self.Listing:Update(data) end
 function g:RemoveListing() return self.Listing:RemoveListing() end
 C_LFGList.HasActiveEntryInfo=function() return active~=nil end
 C_LFGList.GetActiveEntryInfo=function() return active end
 local function Stage(data)
  pending={activityIDs=data.activityIDs,name=LFGListFrame.EntryCreation.Name:GetText(),comment=LFGListFrame.EntryCreation.Description.EditBox:GetText(),requiredItemLevel=data.requiredItemLevel,requiredDungeonScore=data.requiredDungeonScore,requiredPvpRating=data.requiredPvpRating,autoAccept=data.isAutoAccept,privateGroup=data.isPrivateGroup,isCrossFactionListing=data.isCrossFactionListing,generalPlaystyle=data.generalPlaystyle,playstyle=data.playstyle}
  return true
 end
 C_LFGList.CreateListing=function(data) creates=creates+1;return Stage(data) end
 C_LFGList.UpdateListing=Stage
 C_LFGList.RemoveListing=function() active=nil end
 C_LFGList.CopyActiveEntryInfoToCreationFields=function()
  LFGListFrame.EntryCreation.Name:UserType(active.name);LFGListFrame.EntryCreation.Description.EditBox:UserType(active.comment)
 end
 C_LFGList.DoesEntryTitleMatchPrebuiltTitle=function()
  titleChecks=titleChecks+1;error("Saved settings must not inspect protected listing titles")
 end
 a:Open("create")
 local page=u.pages.create;local native=LFGListFrame.EntryCreation
 page.favoritesToggle:Fire("OnClick")
 native.Name:UserType("First listing");native.Description.EditBox:UserType("First description")
 local ok,err=pcall(page.Submit,page)
 T.ok(ok,"a successful asynchronous create must finish Submit without throwing: "..tostring(err))
 T.eq(page.submitting,nil);T.eq(creates,1);T.eq(titleChecks,0,"no title comparison runs before a native entry exists")
 T.eq(#g.Presets:Get(),0,"publishing does not automatically save settings")
 active,pending=pending,nil;g.Listing:OnEntryUpdate(true)
 T.eq(#g.Presets:Get(),0);T.eq(page.favoritesEmpty:IsShown(),true,"native confirmation leaves favorites unchanged")
 T.eq(page.manage:IsShown(),true)
 local readEntry=C_LFGList.GetActiveEntryInfo;local confirmed=g:GetListing()
 C_LFGList.GetActiveEntryInfo=function() return nil end
 g.Listing:OnEntryUpdate(false)
 T.eq(page.manage:IsShown(),true,"an active listing with temporarily unavailable details stays in management")
 T.eq(g:GetListing(),confirmed,"retain the confirmed entry until native details return")
 C_LFGList.GetActiveEntryInfo=readEntry;g.Listing:OnEntryUpdate(false)
 page.editListing:Fire("OnClick");page.ilvl.box:SetText("321");page.favorite:Fire("OnClick")
 T.eq(#page.favoritesList.ids,1,"the star saves the current editing requirements")
 page:Submit()
 active,pending=pending,nil;g.Listing:OnEntryUpdate(false)
 T.eq(g.Presets:Get()[1].requiredItemLevel,321);T.eq(#g.Presets:Get(),1,"delayed updates do not add automatic history")
 -- Ordinary raid listings can leave the native autoAccept flag disabled.
 -- The plugin's automatic invitations must survive that native readback.
 local update=C_LFGList.UpdateListing
 C_LFGList.UpdateListing=function(data)
  T.eq(data.isAutoAccept,true,"the enabled switch reaches the real Listing service")
  local result=Stage(data);pending.autoAccept=false;return result
 end
 page.editListing:Fire("OnClick");page.autoAccept:Fire("OnClick");page:Submit()
 active,pending=pending,nil;g.Listing:OnEntryUpdate(false)
 page.editListing:Fire("OnClick")
 T.eq(page.autoAccept.value,true,"automatic invitations remain enabled after a raid update and native readback")
 C_LFGList.UpdateListing=update
 page.cancelListing:Fire("OnClick");g.Listing:OnEntryUpdate(false)
 T.eq(page.formFrame:IsShown(),true);T.eq(page.publish:IsEnabled(),true,"delisting restores an enabled publish button")
 T.eq(page.submitting,nil,"the previous request does not lock a new listing")
 native.Name:UserType("Second listing");native.Description.EditBox:UserType("Second description")
 page.publish:Fire("OnClick");T.eq(creates,2,"the actual publish button can submit a new group after delisting")
 active,pending=pending,nil;g.Listing:OnEntryUpdate(true)
 T.eq(g.Presets:Get()[1].requiredItemLevel,321);T.eq(#g.Presets:Get(),1,"republishing changes no favorites")
 T.eq(titleChecks,0,"creation and update confirmations no longer call native title comparison")
 T.eq(g.Presets:Get()[1].name,nil);T.eq(g.Presets:Get()[1].comment,nil)
 u:Hide(true)
end
-- A failed cross-faction recreation keeps the edited draft through native
-- removal events, whether they arrive during the call or afterwards.
for _,synchronous in ipairs({false,true}) do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local active={activityIDs={2},name="Existing listing",comment="Existing description",isCrossFactionListing=true}
 local reject=true
 local submitted
 g.Game={RefreshSubscriptions=function() end}
 dofile("addon/LycheeGroup_Group/Listing.lua")
 function g:GetListing() return self.Listing:GetListing() end
 function g:Publish(data) return self.Listing:Publish(data) end
 function g:Update(data) return self.Listing:Update(data) end
 function g:RemoveListing() return self.Listing:RemoveListing() end
 C_LFGList.HasActiveEntryInfo=function() return active~=nil end
 C_LFGList.GetActiveEntryInfo=function() return active end
 C_LFGList.RemoveListing=function() active=nil;if synchronous then g.Listing:OnEntryUpdate(false) end end
 C_LFGList.CreateListing=function(data)
  submitted=data
  if reject then return false end
  active={activityIDs=data.activityIDs,name=LFGListFrame.EntryCreation.Name:GetText(),comment=LFGListFrame.EntryCreation.Description.EditBox:GetText(),isCrossFactionListing=data.isCrossFactionListing}
  return true
 end
 C_LFGList.CopyActiveEntryInfoToCreationFields=function()
  LFGListFrame.EntryCreation.Name:UserType(active.name);LFGListFrame.EntryCreation.Description.EditBox:UserType(active.comment)
 end
 g.Listing:Restore();a:Open("create")
 local page,native=u.pages.create,LFGListFrame.EntryCreation
 page.editListing:Fire("OnClick");page.crossFaction:Fire("OnClick")
 native.Name:UserType("Edited listing");native.Description.EditBox:UserType("Edited description")
 page.ilvl.box:SetText("123");page:Submit()
 T.eq(submitted.isCrossFactionListing,false)
 g.Listing:OnEntryUpdate(false)
 T.eq(g:GetListing(),nil,"failed recreation publishes the native removal")
 T.eq(page:FormData().isCrossFactionListing,false,"failed recreation preserves the explicit cross-faction choice")
 T.eq(page:FormData().requiredItemLevel,123)
 T.eq(native.Name:GetText(),"Edited listing");T.eq(native.Description.EditBox:GetText(),"Edited description")
 T.eq(page.formError:GetText(),a.GroupLocale.updateFailed,"late removal confirmation keeps the submission error")
 T.eq(page.publish:IsEnabled(),true,"the retained draft can be published again")
 reject=false;page:Submit()
 T.eq(submitted.isCrossFactionListing,false,"retry uses the original edited choice")
 T.eq(page.manage:IsShown(),true)
 page.cancelListing:Fire("OnClick");g.Listing:OnEntryUpdate(false)
 T.eq(page:FormData().isCrossFactionListing,true,"explicitly ending the next listing restores the new-listing default")
 u:Hide(true)
end
-- Context actions use the clicked identity without restricting whispers by faction.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g,base=fresh.A,fresh.U,fresh.G,fresh.base
 a:SetSetting("reduceMotion",true)
 g.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}
 for id=1,2 do g.records[id]={id=id,activityID=2,activity=g.Catalog:GetActivity(2),categoryID=2,name="Group "..id,leaderName="Leader"..id.."-Away",leaderKey="Leader"..id.."-Away",leaderFactionGroup=1,numMembers=1,maxNumPlayers=5,age=10} end
 g.apps={{id=2,status="applied",categoryID=2,result=g.records[2],expiresAt=GetTime()+300}}
 local sendTell,tells=ChatFrame_SendTell,{}
 ChatFrame_SendTell=function(name) tells[#tells+1]=name end
 local function Item(value)
  local menu=u.context.menu
  for i,item in ipairs(menu.items) do if item.value==value then return item,menu.list.rows[i] end end
  error("missing context action: "..value)
 end
 local function Choose(value)
  local _,row=Item(value);row:Fire("OnMouseDown","LeftButton");row:Fire("OnClick","LeftButton")
 end
 a:Open("find")
 local page=u.pages.find
 T.eq(page.results.rows[1].key,1);T.eq(page.appList.rows[1].key,2)
 for _,entry in ipairs({{list=page.results,id=1},{list=page.appList,id=2}}) do
  entry.list.clip.mouseOver=true
  for _,case in ipairs({{"Alliance",1},{"Alliance",0},{"Alliance",false},{"Horde",0},{"Horde",1},{"Neutral",1}}) do
   base.SetUnit("player",{faction=case[1]});g.records[entry.id].leaderFactionGroup=case[2] or nil
   local row=entry.list.rows[1];row:Fire("OnMouseDown","RightButton");row:Fire("OnClick","RightButton")
   local item,action=Item("whisper")
   T.eq(item.disabled,false,"search and saved-application whispers ignore unreliable faction data")
   T.eq(action:IsEnabled(),true)
   local before=#tells;Choose("whisper")
   T.eq(#tells,before+1);T.eq(tells[#tells],"Leader"..entry.id.."-Away")
  end
 end
 base.SetUnit("player",{faction="Alliance"});g.records[1].leaderFactionGroup=1
 page:OpenResultMenu(page.results.rows[1],1)
 g.records[1].leaderFactionGroup=0
 local before=#tells;Choose("whisper");T.eq(#tells,before+1,"a faction update does not block opening chat")
 page:OpenResultMenu(page.results.rows[1],1);Choose("copy")
 T.eq(u.copyDialog.value,"Leader1-Away");T.eq(u.copyDialog.fieldLabel:GetText(),"完整名称")
 u:CloseModal()
 g.listing={activityID=2,name="Recruiting",comment=""}
 local one={name="One-Away",nameKey="One-Away",class="WARRIOR",assignedRole="TANK",factionGroup=1}
 local two={name="Two-Away",nameKey="Two-Away",class="PALADIN",specID=66,assignedRole="HEALER",factionGroup=0}
 g.applicants[70]={id=70,status="applied",displayOrderID=1,members={one,two}}
 a:Open("create")
 local create=u.pages.create;local row=create.batchPool[1].people[2]
 u:CloseMenu();row:Fire("OnClick","RightButton")
 T.eq(u.context.menu:IsShown(),false,"clipped applicant rows cannot open a menu")
 create.batchScroll.mouseOver=true;row:Fire("OnClick","LeftButton")
 T.eq(u.context.menu:IsShown(),false,"applicant left clicks retain their existing behavior")
 row:Fire("OnClick","RightButton")
 local menu=u.context.menu
 T.eq(#menu.items,3);T.eq(menu.items[1].label,"密聊");T.eq(menu.items[2].label,"复制名称");T.eq(menu.items[3].label,"荔枝笔记：拉黑玩家")
 T.eq(Item("whisper").disabled,false);T.eq(Item("copy").disabled,false);T.eq(Item("block").disabled,false)
 before=#tells;Choose("whisper");T.eq(#tells,before+1)
 row:Fire("OnClick","RightButton")
 Choose("copy");T.eq(u.copyDialog.value,"Two-Away","copy targets the clicked second member, including realm")
 T.eq(u.copyDialog.fieldLabel:GetText(),"完整名称");u:CloseModal()
 two.factionGroup=1;g:Notify("applicants");row:Fire("OnClick","RightButton");Choose("whisper")
 T.eq(tells[#tells],"Two-Away","whisper targets the clicked member rather than the batch leader")
 two.factionGroup=nil;g:Notify("applicants");row:Fire("OnClick","RightButton")
 T.eq(Item("whisper").disabled,false,"unknown applicant faction does not block opening chat")
 two.factionGroup=1;g:Notify("applicants")
 T.eq(menu:IsShown(),false,"updating applicant data closes the old menu")
 row:Fire("OnClick","RightButton");create:SetBatchOffset(1,false)
 T.eq(menu:IsShown(),false,"scrolling closes the applicant menu even within the same pooled batch")
 row:Fire("OnClick","RightButton");g.applicants[70]=nil;g:Notify("applicants")
 T.eq(menu:IsShown(),false,"removing the applicant releases its open menu")
 g.applicants[70]={id=70,status="applied",displayOrderID=1,members={one,two}};g:Notify("applicants")
 u.preview={provider=g};row:Fire("OnClick","RightButton")
 T.eq(Item("whisper").disabled,true);T.eq(Item("block").disabled,true);T.eq(Item("copy").disabled,false,"preview names remain copyable without enabling social actions")
 u:CloseMenu();u.preview=nil
 row:Fire("OnClick","RightButton");Choose("block")
 T.eq(u.page,"notes");T.eq(u.pages.notes.eName.box:GetText(),"Two-Away")
 T.eq(u.pages.notes.typeButtons.caution.active,true,"block opens the existing caution editor for the clicked member")
 T.eq(a.Notes:Find("Two-Away"),nil,"opening the block editor does not save an unconfirmed note")
 u:Hide(true);ChatFrame_SendTell=sendTell
end
-- A fresh UI instance restores the saved seasonal single selection before any
-- new search; this also covers the English all-instances label.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 fresh.A:SetSetting("rememberFilters",true)
 fresh.G.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={groupKey=20,difficultyID=8}}}
 fresh.A:Open("find")
 local page=fresh.U.pages.find
 T.eq(fresh.G.filters.groupKey,20);T.eq(fresh.G.filters.difficultyID,8,"first entry restores the seasonal single-selection context")
 T.eq(fresh.G.searchText,"","opening Find searches the restored confirmed selection")
 T.eq(page.refresh:IsEnabled(),true,"a restored confirmed single selection can be refreshed")
 page:SelectCategory("seasonDungeon")
 T.eq(page.activities.selectedKey,nil,"a restored keystone choice uses its checkbox without a second row highlight");T.eq(page.activities.rows[1].title:GetText(),"All instances")
 local row;for _,item in ipairs(page.activities.rows) do if item.key==20 then row=item;break end end
 T.eq(row.multiSelect:IsShown(),true);T.eq(row.multiSelect:GetChecked(),true,"a legacy single selection opens as a checked keystone draft")
 fresh.U:Hide(true)
end
-- A collection and the explicit all-instances choice both survive a reload.
for _,choice in ipairs({{groupKeys={[20]=true},difficultyID=8},{selected=true,difficultyID=8}}) do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 fresh.G.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon=choice}}
 local search,calls=fresh.G.Search.Search,0
 fresh.G.Search.Search=function(self,...) calls=calls+1;return search(self,...) end
 fresh.A:Open("find")
 local page=fresh.U.pages.find
 T.eq(fresh.G.searchText,"","restoring a confirmed collection or all-instances choice starts browsing")
 T.ok(page.refresh:IsEnabled(),"restored selection enables refresh")
 T.ok(page.emptyText:GetText()~="请选择副本","restored selection does not ask for another choice")
 T.same(fresh.G.filters.groupKeys,choice.groupKeys)
 page:SelectCategory("seasonDungeon")
 T.eq(calls,1,"reopening the restored selection does not send another search")
 local row;for _,item in ipairs(page.activities.rows) do if item.key==20 then row=item;break end end
 T.eq(row.multiSelect:IsShown(),true,"after reload all keystone selections show checkboxes by default")
 T.eq(row.multiSelect:GetChecked(),choice.groupKeys~=nil)
 T.eq(page.pickerConfirm:IsShown(),choice.groupKeys~=nil,"a restored collection can be edited and confirmed immediately")
 fresh.U:Hide(true)
end
-- The role summary owns a live, complete roster and season-raid coverage.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local members={}
 for i=1,40 do members[i]={guid="Roster-"..i,name="Player"..i.."-Away",nameKey="Player"..i.."-Away",class="WARRIOR",assignedRole=i==1 and "TANK" or "DAMAGER",subgroup=math.ceil(i/5),isLeader=i==40} end
 g.GetRoster=function() return members end
 a:Open("create")
 local page,tip=u.pages.create,u.Tooltip
 T.eq(page.buffArea,nil,"non-raid creation builds no buff controls")
 T.ok(page.rosterList:IsShown(),"a small-group activity uses its inline list even before the roster shrinks")
 T.eq(page.rosterList.rows[1].name:GetText(),"Player1","the current party in Create hides the realm just like its raid roster")
 T.eq(page.rosterList.rows[1].targetKey,"Roster-1","hiding a roster realm does not change its action identity")
 page:UsePreset({activityID=1})
 page.groupSummary:Fire("OnEnter")
 local view=tip.interactive
 T.eq(view:GetWidth(),960);T.eq(#view.memberButtons,40);T.ok(view.memberButtons[40]:IsShown())
 T.eq(view.footer:GetText(),"","current-roster tooltips have no interaction instructions")
 do
  local last=view.memberButtons[40];local point={last:GetPoint()}
  T.near(view.canvas:GetHeight(),-point[#point]+last:GetHeight()+12,.001,"grouped rosters retain 12 pixels of bottom padding without an instruction area")
 end
 T.eq(view.memberButtons[1].member,members[1],"the roster tooltip starts with the first actual member of subgroup one")
 T.eq(view.memberButtons[40].member,members[40]);T.ok(view.memberButtons[40].leaderIcon:IsShown(),"the leader crown remains on its real subgroup member")
 for group=1,8 do T.eq(view.rosterGroupTitles[group]:GetText(),"小队 "..group);T.ok(view.rosterGroupTitles[group]:IsShown()) end
 members[5].subgroup,members[6].subgroup=2,1;g:Notify("roster")
 T.eq(view.memberButtons[5].member,members[6]);T.eq(view.memberButtons[6].member,members[5],"subgroup moves preserve each group's real roster order")
 members[5].subgroup,members[6].subgroup=1,2;g:Notify("roster")
 T.ok(view.scrollbar:IsShown());view.scrollbar:SetValue(64);g:Notify("roster")
 T.eq(view.scroll:GetVerticalScroll(),64,"a roster update preserves the open list position")
 view.memberButtons[1]:Fire("OnClick");T.eq(tip.selectedMemberID,"Roster-1")
 local selected=members[1]
 selected.guid="Roster-new";selected.name="Replacement-Away";selected.nameKey=selected.name
 members[3]={guid="Roster-1",name="Player1-Away",nameKey="Player1-Away",class="PRIEST",assignedRole="HEALER",subgroup=1,dungeonScore=3200}
 g:Notify("roster");T.eq(tip.member,members[3],"reused roster slots retain the selected player by GUID")
 T.eq(view.metrics[2].value:GetText(),"3200")
 view.wcl:Fire("OnClick");T.ok(tip.owner);T.ok(view.copyField:IsShown())
 members[3].dungeonScore=3300;g:Notify("roster")
 T.eq(tip.member,members[3]);T.eq(view.metrics[2].value:GetText(),"3300","WCL copying retains the latest member snapshot")
 table.remove(members,3);g:Notify("roster")
 T.eq(tip.member,nil);T.eq(tip.sourceRoster,members,"a departed selected player returns to the current list")
 do
  tip:Hide();local all=members;members={all[1],all[2],all[3],all[4]}
  local first=members[1];local name,key=first.name,first.nameKey
  first.name=string.rep("长名字",8).."-Away";first.nameKey=first.name;first.factionGroup=1
  g:Notify("roster");page.groupSummary:Fire("OnEnter")
  T.eq(view:GetWidth(),440,"a normal four-player party keeps one compact column")
  for i=1,4 do T.eq(view.memberButtons[i].member,members[i],"party members retain actual unit order") end
  local row=view.memberButtons[1];local role,faction={row.role:GetPoint()},{row.faction:GetPoint()}
  T.ok(row:GetHeight()>44,"complete long names grow a compact member cell")
  T.eq((row.name:GetText():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")),first.name:match("^[^-]+"),"current-roster names omit the realm without truncating the character name")
  T.eq(role[2],row.icon);T.eq(role[3],"RIGHT");T.eq(role[5],0,"party roles remain centered on the portrait after name wrapping")
  T.eq(faction[2],row.role);T.eq(faction[5],0,"party faction shares the role and portrait center")
  local portrait,namePoint,metaPoint={row.icon:GetPoint()},{row.name:GetPoint()},{row.realm:GetPoint()}
  local textBottom=metaPoint[#metaPoint]-math.max(16,row.realm:GetStringHeight())
  T.near(portrait[#portrait]-12,(namePoint[#namePoint]+textBottom)/2,.001,"portrait and markers center on the complete wrapped identity block")
  T.ok(row.name:GetWidth()+38+6<=row:GetWidth()-6-40,"both identity lines leave space for the enlarged faction and role")
  T.ok(view.rosterGroupTitles[1]:IsShown(),"a raid activity keeps subgroup headings even with only four current members")
  for subgroup,title in pairs(view.rosterGroupTitles) do if subgroup~=1 then T.eq(title:IsShown(),false,"empty raid subgroup headings are hidden") end end
  tip:Hide();first.name,first.nameKey=name,key;members=all;g:Notify("roster")
 end
 tip:Hide();members={members[1]};g:Notify("roster");page.groupSummary:Fire("OnEnter")
 T.eq(view:GetWidth(),440);T.eq(view.memberButtons[2]:IsShown(),false)
 do
  local last=view.memberButtons[1];local point={last:GetPoint()}
  T.near(view.canvas:GetHeight(),-point[#point]+last:GetHeight()+12,.001,"a one-member raid subgroup retains its bottom padding without footer height")
  T.near(view:GetHeight()-view.canvas:GetHeight(),40,.001,"the ordinary twenty-pixel top and bottom surface padding remains")
 end
 tip:Hide()
 page:UsePreset({activityID=1});T.ok(page.buffArea:IsShown());T.eq(page.buffReport.maxGroup,6)
 T.eq(#page.buffReport.missing,12)
 local raid=g.Catalog:GetActivity(1);raid.difficultyID=16;page:RefreshPicker()
 T.eq(page.buffReport.maxGroup,4,"difficulty changes update coverage without a roster event")
 for i=1,6 do g.Presets:ToggleFavorite({activityID=1,requiredItemLevel=300+i}) end
 page.favoritesToggle:Fire("OnClick")
 T.eq(page.buffList.slider:IsShown(),false,"compact favorites leave enough room for the complete buff list")
 local p={page.rosterCard:GetPoint()}
 T.ok(-p[#p]+page.rosterCard:GetHeight()<=page.rail:GetHeight(),"expanded favorites leave the roster card inside the resized rail")
 members={}
 for _,class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","MONK","DRUID","DEMONHUNTER","EVOKER"}) do members[#members+1]={name=class,nameKey=class.."-Away",class=class,subgroup=1} end
 g:Notify("roster");T.ok(page.buffComplete:IsShown());T.eq(page.buffList:IsShown(),false)
 table.remove(members,5);g:Notify("roster")
 T.eq(page.buffList.rows[1].cells[1].label:GetText(),"毒药仅1人")
 members[#members+1]={name="Unknown",nameKey="Unknown-Away",subgroup=1};g:Notify("roster")
 T.eq(page.buffTitle:GetText(),"待确认增益")
 page:UsePreset({activityID=2});T.eq(page.buffArea:IsShown(),false);T.ok(page.rosterList:IsShown());T.eq(page.groupSummary:IsShown(),false)
 g.listing={activityID=1,name="Raid listing"};g:Notify("listing");T.ok(page.buffArea:IsShown(),"managed listings use their own raid activity")
 local matches=g.Catalog.Matches
 g.Catalog.Matches=function(self,activity,category,...) if category=="seasonRaid" then return false end;return matches(self,activity,category,...) end
 g:Notify("activities");T.eq(page.buffArea:IsShown(),false,"a catalog refresh can remove outdated season coverage")
 g.Catalog.Matches=matches
 u:Hide(true);T.eq(page.roster,nil);T.eq(page.buffReport,nil);T.eq(tip.sourceRoster,nil)
end
-- Current-roster actions use native group permissions and never filter by faction.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local saved={}
 local function Stub(key,value) saved[key]={value=_G[key]};_G[key]=value end
 local state={leader=true,inspect=true}
 local guids={player="Self-GUID",party1="Cross-GUID"}
 local tells,removals,inspections={},{},{}
 Stub("IsInRaid",function() return state.raid==true end)
 Stub("IsInGroup",function() return true end)
 Stub("UnitGUID",function(unit) return guids[unit] end)
 Stub("UnitIsHumanPlayer",function(unit) return guids[unit]~=nil end)
 Stub("UnitIsConnected",function() return not state.offline end)
 Stub("UnitCanCooperate",function() return true end)
 Stub("UnitCanAttack",function() return false end)
 Stub("UnitIsDeadOrGhost",function() return state.dead==true end)
 Stub("UnitIsGroupLeader",function(unit) return unit=="player" and state.leader==true or unit=="party1" and state.targetLeader==true end)
 Stub("UnitIsGroupAssistant",function(unit) return unit=="player" and state.assistant==true or unit=="party1" and state.targetAssistant==true end)
 Stub("HasLFGRestrictions",function() return state.restricted==true end)
 Stub("GetInstanceInfo",function() return "Instance",state.kind or "party" end)
 Stub("IsInActiveWorldPVP",function() return state.worldPvp==true end)
 Stub("InCombatLockdown",function() return state.combat==true end)
 Stub("CanInspect",function() return state.inspect==true end)
 Stub("ChatFrameUtil",{SendTell=function(name) tells[#tells+1]=name end})
 Stub("InspectUnit",function(unit) inspections[#inspections+1]=unit end)
 Stub("C_PartyInfo",{
  ChallengeModeRestrictionsActive=function() return state.challenge==true end,
  UninviteUnit=function(...) removals[#removals+1]={count=select("#",...),...} end,
 })
 local members={
  {unit="player",guid=guids.player,name="Self",realm="Home",nameKey="Self-Home",class="WARRIOR",assignedRole="TANK",subgroup=1,isSelf=true,factionGroup=1},
  {unit="party1",guid=guids.party1,name="Cross",realm="Away",nameKey="Cross-Away",class="PRIEST",assignedRole="HEALER",subgroup=1,factionGroup=0},
 }
 g.GetRoster=function() return members end
 a:Open("create")
 local tip=u.Tooltip
 local function Open(index)
  tip:Hide();tip:ShowRoster(u.frame,members)
  local row=tip.interactive.memberButtons[index]
  row:Fire("OnMouseDown","RightButton");row:Fire("OnMouseUp","RightButton");row:Fire("OnClick","RightButton")
  T.eq(tip.member,nil,"right-click opens actions instead of personal details")
  T.ok(tip.pinned);T.ok(u.context.menu:IsShown())
  return u.context.menu
 end
 local menu=Open(2)
 T.eq(#menu.items,3);T.eq(menu.items[1].label,"私聊");T.eq(menu.items[2].label,"移出队伍");T.eq(menu.items[3].label,"查看角色信息")
 T.same(menu.list.rows[2].title.color,u.Theme.accent,"the removal action renders the destructive color")
 T.eq(menu.items[1].disabled,false,"joined cross-faction players can be whispered")
 menu.list.rows[1]:Fire("OnClick","LeftButton");T.eq(tells[1],"Cross-Away")
 menu=Open(2);menu.list.rows[2]:Fire("OnClick","LeftButton")
 T.eq(removals[1][1],"Cross-Away");T.eq(removals[1].count,3);T.eq(removals[1][3],true,"native removal receives the full name and confirmed hardware action")
 menu=Open(2);menu.list.rows[3]:Fire("OnClick","LeftButton")
 T.eq(inspections[1],"party1","character information uses the native InspectUnit entry");T.eq(tip.owner,nil)
 menu=Open(1);for _,item in ipairs(menu.items) do T.eq(item.disabled,true,"self actions remain unavailable") end
 state.leader=false;menu=Open(2);T.eq(menu.items[2].disabled,true,"ordinary party members cannot remove players")
 menu.list.rows[2]:Fire("OnClick","LeftButton");T.eq(#removals,1)
 state.raid=true;state.assistant=true;menu=Open(2);T.eq(menu.items[2].disabled,false,"raid assistants can remove ordinary members")
 state.targetLeader=true;menu=Open(2);T.eq(menu.items[2].disabled,true,"assistants cannot remove the raid leader")
 state.targetLeader=false;state.targetAssistant=true;menu=Open(2);T.eq(menu.items[2].disabled,true,"assistants cannot remove other assistants")
 state.leader=true;menu=Open(2);T.eq(menu.items[2].disabled,false,"the raid leader can remove an assistant")
 state.raid=false;state.targetAssistant=false;state.assistant=false;state.challenge=true
 menu=Open(2);T.eq(menu.items[2].disabled,true,"challenge-mode restrictions disable direct party removal")
 state.challenge=false;state.leader=false;state.restricted=true
 menu=Open(2);T.ok(menu.items[2].label:find("投票",1,true));T.eq(menu.items[2].disabled,false,"LFG groups use the native vote-removal path")
 menu.list.rows[2]:Fire("OnClick","LeftButton");T.eq(#removals,2);T.eq(removals[2][1],"Cross-Away")
 state.kind="pvp";menu=Open(2);T.eq(menu.items[2].disabled,true,"the LFG vote action respects native PvP restrictions")
 state.kind=nil;state.restricted=false;state.leader=true;state.combat=true
 menu=Open(2);T.eq(menu.items[3].disabled,true,"combat disables opening native character inspection")
 state.combat=false;state.inspect=false;menu=Open(2);T.eq(menu.items[3].disabled,true,"native CanInspect determines target availability")
 state.inspect=true;state.offline=true;menu=Open(2);T.eq(menu.items[1].disabled,true,"offline players cannot receive a tell")
 state.offline=false;menu=Open(2);state.leader=false;menu.list.rows[2]:Fire("OnClick","LeftButton")
 T.eq(#removals,2,"removal rechecks permissions when the selected action runs")
 state.leader=true;menu=Open(2);guids.party1="Replacement-GUID";menu.list.rows[1]:Fire("OnClick","LeftButton")
 T.eq(#tells,1,"a reused native unit token cannot act on the replacement player")
 guids.party1=members[2].guid;menu=Open(2);menu.mouseOver=true
 tip.outsideClicks:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
 T.ok(tip.interactive:IsShown(),"moving into the roster's action menu keeps the pinned list open")
 tip:Hide();T.eq(menu:IsShown(),false,"closing the source roster releases its menu")
 u:Hide(true)
 for key,entry in pairs(saved) do _G[key]=entry.value end
end
-- Binding capture uses Blizzard's binding map, and scale applies to the whole window.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local one={guid="Inline-1",name="First-Away",nameKey="First-Away",class="MAGE",assignedRole="DAMAGER",dungeonScore=2500,subgroup=1}
 local two={guid="Inline-2",name="Longnamehere-Away",nameKey="Longnamehere-Away",class="PRIEST",assignedRole="HEALER",factionGroup=0,isBNetFriend=true,subgroup=1}
 local members={one,two};g.GetRoster=function() return members end
 a:Open("create");local page,tip=u.pages.create,u.Tooltip
 local list=page.rosterList;list.clip.mouseOver=true
 T.eq(list.rows[1]:GetWidth(),list:GetWidth(),"a fitting roster returns the scrollbar space so hover margins are equal")
 local fullHeight,favoriteHeight=list.body:GetHeight(),page.favoritesCard:GetHeight()
 page.favoritesCard:SetHeight(u.Theme.contentHeight-16-76-(fullHeight-8));page:LayoutRosterCard()
 T.ok(list.slider:IsShown());T.eq(list.rows[1]:GetWidth(),list:GetWidth()-u.C.listRightInset)
 T.ok(list.body:GetHeight()>fullHeight,"reserving the scrollbar can wrap a name onto another line")
 page:SetRosterOffset(20)
 page.favoritesCard:SetHeight(u.Theme.contentHeight-16-76-fullHeight);page:LayoutRosterCard()
 T.eq(list.slider:IsShown(),false,"full-width content that fits must release the gutter even when narrow rows would still overflow")
 T.eq(list.rows[1]:GetWidth(),list:GetWidth());T.eq(list.body:GetHeight(),fullHeight);T.eq(list.clip:GetVerticalScroll(),0)
 page.favoritesCard:SetHeight(favoriteHeight);page:LayoutRosterCard()
 list.rows[1].tooltipArea:Fire("OnEnter")
 T.eq(tip.member,one);T.ok(tip.directPlayer);T.eq(tip.interactive.back:IsShown(),false)
 members={two,one};one.dungeonScore=2600;g:Notify("roster")
 T.eq(tip.member,one);T.eq(tip.owner,list.rows[2]);T.eq(tip.interactive.metrics[2].value:GetText(),"2600","inline details retain the same player when roster positions move")
 tip.interactive.wcl:Fire("OnClick");members={one,two};one.dungeonScore=2700;g:Notify("roster")
 T.eq(tip.member,one);T.eq(tip.owner,list.rows[1]);T.eq(tip.interactive.metrics[2].value:GetText(),"2700")
 members={two};g:Notify("roster");T.eq(tip.owner,nil,"a departing inline player closes their details")
 list.rows[1]:Fire("OnClick","RightButton");T.eq(#u.context.menu.items,3,"inline members use the same roster action menu")
 u:CloseMenu()
 g.listing={activityID=1,name="Small raid"};g:Notify("listing")
 T.ok(page.groupSummary:IsShown());T.eq(list:IsShown(),false);T.eq(list.rows[1].member,nil)
 page.groupSummary:Fire("OnEnter");T.ok(tip.interactive.rosterGroupTitles[1]:IsShown(),"even a one-person raid activity keeps its group presentation")
 tip:Hide();g.listing.activityID=2;g:Notify("listing")
 T.ok(list:IsShown());T.eq(page.groupSummary:IsShown(),false);T.eq(list.rows[1].member,two)
 u:Hide(true);T.eq(list.rows[1].member,nil,"leaving releases inline roster bindings")
end
-- Keyboard shortcuts stop when close starts, before the retained page leaves.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 g.records[901]={id=901,activityID=2,name="Closing shortcut",leaderName="Leader-Home",numMembers=1}
 g.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}
 a:SetSetting("reduceMotion",false);a:Open("find")
 u.Motion:Tick(2)
 local page=u.pages.find;page:RefreshResults();T.eq(page.results.rows[1].key,901);page.results.rows[1]:Fire("OnClick","LeftButton")
 page.autoApply:Fire("OnClick");u.Application.applicationModal.submit:Fire("OnClick")
 T.ok(u.Application:IsAutoApplyEnabled())
 local dialog=LFGListApplicationDialog;local before=dialog.submissions
 u:Hide();T.ok(u.hiding);T.ok(u.frame:IsShown())
 page.main:Fire("OnKeyDown","ENTER");T.eq(dialog.submissions,before,"Enter cannot apply while the window exits")
 local shift=IsShiftKeyDown;IsShiftKeyDown=function() return true end
 page.main:Fire("OnKeyDown","F10");T.eq(u.context.menu and u.context.menu:IsShown() or false,false,"closing cannot open a result menu")
 IsShiftKeyDown=shift
 a:Open("find");page.results.rows[1]:Fire("OnClick","LeftButton");page.main:Fire("OnKeyDown","ENTER")
 T.eq(dialog.submissions,before,"Enter remains available to chat after reversing close")
 IsShiftKeyDown=function() return true end
 page.main:Fire("OnKeyDown","F10");T.ok(u.context.menu:IsShown(),"reversing close restores the result menu shortcut")
 IsShiftKeyDown=shift
 u.Motion:Tick(2);a:ToggleWindow();u.Motion:Tick(.1)
 T.ok(u.hiding);local closingToken=u.exitToken
 a:ToggleWindow();T.eq(u.hiding,nil);T.ok(u.exitToken>closingToken,"a second toggle invalidates the earlier close")
 u.Motion:Tick(1);T.ok(u:IsShown(),"toggle reverses the in-progress close");T.eq(g.views[page],"search")
 u:Hide(true)
end
-- Binding capture uses Blizzard's binding map, and scale applies to the whole window.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,s=fresh.A,fresh.U,fresh.S
 a:SetSetting("reduceMotion",true)
 SetBinding(";","OPENALLBAGS");SetBinding("M","TOGGLEWORLDMAP")
 a:Open("settings")
 local page=u.pages.settings
 T.eq(page.section,"general");T.ok(page.frame.events.UPDATE_BINDINGS)
 T.ok(page.controls.toggleBinding.help:GetText():find("OPENALLBAGS",1,true))
 page.controls.toggleBinding.widget:Fire("OnClick")
 local capture=page.controls.toggleBinding.frame
 T.eq(page.bindingCapture,capture);T.eq(capture.keyboardEnabled,true);T.eq(capture.keyboardPropagation,false)
 T.eq(u.activeModal,nil,"changing a key captures it directly in the settings row")
 T.ok(page.controls.toggleBinding.help:GetText():find("Esc",1,true))
 capture:Fire("OnKeyDown","LCTRL");T.eq(page.bindingCapture,capture)
 capture:Fire("OnKeyDown","SEMICOLON");T.eq(page.pendingBindingAction,"OPENALLBAGS")
 T.eq(#s.bindingSaves,0);T.eq(s.bindings[";"],"OPENALLBAGS")
 T.ok(page.bindingNotice:IsShown());T.eq(page.bindingNotice.close:IsShown(),false)
 T.ok(page.bindingNotice.text:GetText():find("OPENALLBAGS",1,true))
 T.ok(page.overwriteBinding:IsShown());T.eq(page.overwriteBinding.label:GetText(),"覆盖")
 T.eq(select(5,page.panels.general:GetPoint()),-80-page.bindingNotice:GetHeight()-12,"the existing Notice reserves space above the settings rows")
 page.cancelBinding:Fire("OnClick")
 T.eq(page.bindingCapture,nil);T.eq(capture.keyboardEnabled,false);T.eq(capture:GetScript("OnKeyDown"),nil)
 T.eq(page.bindingNotice:IsShown(),false);T.eq(page.pendingBindingKey,nil);T.eq(#s.bindingSaves,0)
 page:BeginBindingCapture();capture:Fire("OnKeyDown","SEMICOLON");capture:Fire("OnKeyDown","ESCAPE")
 T.eq(page.bindingCapture,nil);T.eq(page.bindingNotice:IsShown(),false);T.eq(#s.bindingSaves,0)
 page:BeginBindingCapture();u:HandleEscape()
 T.eq(page.bindingCapture,nil);T.ok(u:IsShown(),"Escape cancels row capture before closing the window")
 page:BeginBindingCapture();s.bindingModifiers.ctrl=true
 capture:Fire("OnKeyDown","G");s.bindingModifiers.ctrl=nil
 T.eq(page.bindingCapture,nil);T.eq(capture.keyboardEnabled,false);T.eq(s.bindings["CTRL-G"],a.Bindings.action);T.eq(#s.bindingSaves,1)
 T.ok(page.controls.toggleBinding.help:GetText():find("CTRL-G",1,true));T.eq(u.modals and u.modals.keybinding,nil)
 SetBinding("CTRL-G");SetBinding("F",a.Bindings.action);page.frame:Fire("OnEvent","UPDATE_BINDINGS")
 T.ok(page.controls.toggleBinding.help:GetText():find("F",1,true),"the displayed binding follows native changes")
 page:BeginBindingCapture();capture:Fire("OnKeyDown","M")
 T.eq(page.pendingBindingAction,"TOGGLEWORLDMAP");T.eq(s.bindings.M,"TOGGLEWORLDMAP")
 page.overwriteBinding:Fire("OnClick")
 T.eq(s.bindings.M,a.Bindings.action);T.eq(s.bindings.F,nil);T.eq(page.bindingCapture,nil);T.eq(page.bindingNotice:IsShown(),false)
 SetBinding("K","TOGGLEWORLDMAP");page:BeginBindingCapture();capture:Fire("OnKeyDown","K")
 SetBinding("K","OPENALLBAGS");page.overwriteBinding:Fire("OnClick")
 T.eq(s.bindings.K,"OPENALLBAGS","a changed conflict must be confirmed again")
 T.eq(page.pendingBindingAction,"OPENALLBAGS");T.ok(page.bindingNotice.text:GetText():find("OPENALLBAGS",1,true))
 page.cancelBinding:Fire("OnClick")
 page:BeginBindingCapture()
 local inCombat=InCombatLockdown;InCombatLockdown=function() return true end
 local saves=#s.bindingSaves;page.frame:Fire("OnEvent","PLAYER_REGEN_DISABLED")
 T.eq(page.bindingCapture,nil);T.eq(capture.keyboardEnabled,false);T.eq(#s.bindingSaves,saves)
 T.eq(page.frame.events.PLAYER_REGEN_DISABLED,nil);T.eq(page.bindingNotice.text:GetText(),a.L.bindingCombat)
 T.eq(page.overwriteBinding:IsShown(),false)
 page:BeginBindingCapture();T.eq(page.bindingCapture,nil);T.eq(#s.bindingSaves,saves)
 page.cancelBinding:Fire("OnClick")
 InCombatLockdown=inCombat
 page:BeginBindingCapture();page:SelectSection("browse")
 T.eq(page.bindingCapture,nil);T.eq(capture.keyboardEnabled,false);T.eq(page.pendingBindingAction,nil)
 page:SelectSection("general");page:BeginBindingCapture();capture:Hide()
 T.eq(page.bindingCapture,nil);T.eq(capture.keyboardEnabled,false);T.eq(capture:GetScript("OnKeyDown"),nil)
 capture:Show();page:BeginBindingCapture();u:Navigate("notes")
 T.eq(page.bindingCapture,nil);T.eq(page.frame.events.PLAYER_REGEN_DISABLED,nil);T.eq(capture.keyboardEnabled,false)
 u:Navigate("settings",{section="general"});a:SetSetting("reduceMotion",false);page:BeginBindingCapture()
 local beforeClose=#s.bindingSaves
 u:Hide();T.ok(u.hiding);T.ok(u.frame:IsShown(),"closing preserves the animated page")
 T.eq(page.bindingCapture,nil);T.eq(capture.keyboardEnabled,false);T.eq(capture:GetScript("OnKeyDown"),nil)
 T.eq(page.frame.events.PLAYER_REGEN_DISABLED,nil)
 capture:Fire("OnKeyDown","F8");T.eq(#s.bindingSaves,beforeClose,"closing immediately cancels key capture")
 a:Open("settings");page:BeginBindingCapture();T.eq(page.bindingCapture,capture,"capture remains available after reversing close")
 page:CancelBindingCapture();a:SetSetting("reduceMotion",true)
 u:Navigate("settings",{section="interface"})
 local baseline=math.min(1,(UIParent:GetWidth()-40)/u.Theme.width,(UIParent:GetHeight()-40)/u.Theme.height)
 local floatingScale=a.db.floatingScale
 T.near(u.frame:GetScale(),baseline,.00001)
 local scaleControl=page.controls.uiScale.widget;local scaleSlider=scaleControl.slider
 T.eq(scaleSlider.kind,"Frame","window scaling does not use the native Slider input path")
 T.eq(scaleControl.thumb.kind,"Button")
 local mouseDown=IsMouseButtonDown;local pressed=false
 IsMouseButtonDown=function(button) return button=="LeftButton" and pressed end
 local dragScale,dragLeft,dragWidth
 local function Move(value)
  s.cursorX=(dragLeft+(value-75)/50*dragWidth)*dragScale
 end
 local function BeginAt(value,target)
  dragScale,dragLeft,dragWidth=scaleSlider:GetEffectiveScale(),scaleSlider:GetLeft(),scaleSlider:GetWidth()
  pressed=true;Move(value);(target or scaleSlider):Fire("OnMouseDown","LeftButton")
 end
 local function Release(target)
  pressed=false;(target or scaleSlider):Fire("OnMouseUp","LeftButton")
 end
 local setScale=u.frame.SetScale;local scaleWrites=0
 u.frame.SetScale=function(frame,value) scaleWrites=scaleWrites+1;return setScale(frame,value) end
 BeginAt(105)
 T.eq(scaleControl.valueLabel:GetText(),"105%","the initial track click only previews its snapped value")
 Move(110);scaleSlider:Fire("OnUpdate",.016)
 local getLeft,getEffective=scaleSlider.GetLeft,scaleSlider.GetEffectiveScale
 scaleSlider.GetLeft=function() error("drag must use its captured track origin") end
 scaleSlider.GetEffectiveScale=function() error("drag must use its captured effective scale") end
 Move(107.4);scaleSlider:Fire("OnUpdate",.016)
 T.eq(scaleControl.valueLabel:GetText(),"110%","small boundary jitter keeps the current five-percent step")
 Move(106.6);scaleSlider:Fire("OnUpdate",.016);T.eq(scaleControl.valueLabel:GetText(),"105%")
 Move(115);scaleSlider:Fire("OnUpdate",.016)
 scaleSlider.GetLeft,scaleSlider.GetEffectiveScale=getLeft,getEffective
 page:Sync()
 T.eq(scaleWrites,0,"dragging the scale slider keeps its parent and track stable until release")
 T.eq(a.db.uiScale,100,"drag samples do not repeatedly save or resize the window")
 T.eq(scaleSlider:GetValue(),115,"an unrelated settings sync preserves the pending drag position")
 T.eq(page.controls.uiScale.widget.valueLabel:GetText(),"115%")
 Release()
 T.eq(scaleWrites,1,"releasing a scale drag applies its final value once")
 T.eq(a.db.uiScale,115);T.near(u.frame:GetScale(),baseline*1.15,.00001)
 T.eq(scaleSlider:GetScript("OnUpdate"),nil,"mouse release removes the drag sampler before applying scale")
 BeginAt(116);Release()
 T.eq(scaleWrites,1,"another sample in the same five-percent step does not resize again")
 BeginAt(115);Move(200);pressed=false;scaleSlider:Fire("OnUpdate",.016)
 T.eq(a.db.uiScale,125,"release outside the control is detected and clamped without a mouse-up event")
 T.eq(scaleWrites,2);T.eq(scaleSlider:GetScript("OnUpdate"),nil)
 BeginAt(75);scaleControl:Hide();pressed=false
 T.eq(a.db.uiScale,125,"hiding during a drag cancels the preview without resizing inside OnHide")
 T.eq(scaleControl.valueLabel:GetText(),"125%");T.eq(scaleWrites,2)
 T.eq(scaleControl:IsDragging(),false);T.eq(scaleSlider:GetScript("OnUpdate"),nil)
 scaleControl:Show();scaleControl:SetValue(75)
 T.eq(a.db.uiScale,125,"programmatic control synchronization does not save a setting")
 page:Sync();T.eq(scaleControl:GetValue(),125)
 u.frame.SetScale=setScale
 BeginAt(75);Release()
 T.eq(a.db.uiScale,75);T.near(u.frame:GetScale(),baseline*.75,.00001)
 T.near(u.settingsButton:GetEffectiveScale(),u.frame:GetEffectiveScale(),.00001)
 u.Tooltip:ShowRoster(u.frame,fresh.G:GetRoster());local tip=u.Tooltip.interactive
 T.near(tip:GetScale(),u.frame:GetEffectiveScale()/UIParent:GetEffectiveScale(),.00001)
 BeginAt(75,scaleControl.thumb);Move(125);scaleSlider:Fire("OnUpdate",.016);Release(scaleControl.thumb)
 T.eq(a.db.uiScale,125);T.near(u.frame:GetScale(),baseline*1.25,.00001)
 T.near(tip:GetScale(),u.frame:GetEffectiveScale()/UIParent:GetEffectiveScale(),.00001)
 local modal=u:OpenModal("scaleCheck","Test",480,260)
 T.near(modal.frame:GetEffectiveScale(),u.frame:GetEffectiveScale(),.00001)
 modal:Close();BeginAt(100);u:Navigate("notes");pressed=false
 T.eq(scaleControl:IsDragging(),false);T.eq(scaleSlider:GetScript("OnUpdate"),nil);T.eq(a.db.uiScale,125,"leaving settings clears an unfinished preview")
 T.eq(page.frame.events.UPDATE_BINDINGS,nil)
 IsMouseButtonDown=mouseDown
 T.eq(a.db.floatingScale,floatingScale,"main-window scale leaves the floating window's setting unchanged")
 u:Navigate("find");local find=u.pages.find;local normalClamp=u.frame.clampInsets;find:SetFiltersOpen(true)
 local function ScreenScale(filterWidth)
  local minWidth,minHeight=u:GetWindowMinimum();filterWidth=filterWidth or 0
  local desired=math.min(1,(UIParent:GetWidth()-40)/(u.Theme.width+filterWidth),(UIParent:GetHeight()-40)/u.Theme.height)*a.db.uiScale/100
  return math.min(desired,(UIParent:GetWidth()-40)/(minWidth+filterWidth),(UIParent:GetHeight()-40)/minHeight)
 end
 T.eq(u.frame.clampInsets,normalClamp,"the internal filter overlay keeps the ordinary window clamp")
 T.near(u.frame:GetScale(),ScreenScale(),.00001,"opening the internal overlay preserves the normal window scale")
 find:SetFiltersOpen(false);T.near(u.frame:GetScale(),baseline*1.25,.00001)
 T.eq(u.frame.clampInsets,normalClamp,"closing filters preserves the normal window boundary")
 find:SetFiltersOpen(true)
 UIParent:SetSize(1100,800);u.frame:Fire("OnEvent","DISPLAY_SIZE_CHANGED")
 T.near(u.frame:GetScale(),ScreenScale(),.00001,"screen resizing uses the same scale with an internal overlay")
 UIParent:SetSize(1280,860);u:Navigate("settings")
 baseline=math.min(1,1240/u.Theme.width,820/u.Theme.height)
 u:Hide(true);a:Open("settings");T.near(u.frame:GetScale(),ScreenScale(),.00001)
 UIParent:SetSize(1100,800);u.frame:Fire("OnEvent","DISPLAY_SIZE_CHANGED")
 T.near(u.frame:GetScale(),ScreenScale(),.00001)
 u:Hide(true)
end

-- Item-level correction reserves inline space and stays independent of failures.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g,clock=fresh.A,fresh.U,fresh.G,fresh.base
 local original=GetAverageItemLevel;local highest,pvpLevel=400.9,450.7
 GetAverageItemLevel=function() return highest,200,pvpLevel end
 a:Open("create");local page=u.pages.create
 page:UsePreset({activityID=2,generalPlaystyle=2})
 LFGListFrame.EntryCreation.Name:UserType("Item level test")
 local function FormY(region) local point={region:GetPoint()};return point[#point] end
 local originalRequirementsY=FormY(page.req)
 page.ilvl.box:UserType("999")
 T.eq(page.ilvl.box:GetText(),"400","manual input clamps to floored highest item level, not equipped level")
 T.ok(page.correctionNotice and page.correctionNotice:IsShown(),"the actual correction appears inline in the creation form")
 T.eq(page.correctionNotice:GetParent(),page.formFrame)
 T.eq(page.correctionNotice:GetWidth(),page.formFrame:GetWidth(),"correction feedback spans the activity form instead of the window footer")
 local correctionPoint={page.correctionNotice:GetPoint()}
 T.eq(correctionPoint[1],"TOPLEFT");T.eq(correctionPoint[#correctionPoint],-44,"correction feedback starts below the form heading")
 T.eq(FormY(page.desc),-56-page.correctionNotice:GetHeight()-12,"inline correction reserves space above the activity form")
 T.eq(FormY(page.req),FormY(page.desc)+FormY(page.descriptionShell)-page.descriptionShell:GetHeight()-24,"the requirements follow the resized description with a clear gap")
 local notice,timer=page.correctionNotice,page.correctionTimer
 T.ok(notice.text:GetText():find("400",1,true))
 clock.AdvanceClock(2);page.ilvl.box:UserType("999")
 T.eq(page.correctionNotice,notice,"repeated corrections reuse one inline notice")
 T.eq(timer.cancelled,true,"a replacement correction cancels the old expiration")
 clock.AdvanceClock(2);T.ok(notice:IsShown(),"the cancelled old expiration does not hide the new message")
 clock.AdvanceClock(2);T.eq(notice:IsShown(),false);T.eq(page.correctionTimer,nil)
 T.eq(FormY(page.desc),-56);T.eq(FormY(page.req),originalRequirementsY,"expiration returns the form to its original layout")
 for _,value in ipairs({"","0","350"}) do page.ilvl.box:UserType(value);T.eq(page.ilvl.box:GetText(),value) end
 T.eq(page.correctionTimer,nil,"empty, zero and valid requirements do not create a correction timer")
 local activity=g.Catalog:GetActivity(2);local oldPvp=activity.isPvpActivity
 activity.isPvpActivity=true;page.ilvl.box:UserType("999")
 T.eq(page.ilvl.box:GetText(),"450","PvP activities use the third native item-level return")
 T.ok(notice.text:GetText():find("PvP",1,true));activity.isPvpActivity=oldPvp
 page:HideCorrectionNotice();page:UsePreset({activityID=2,requiredItemLevel=999,generalPlaystyle=2})
 T.eq(page.ilvl.box:GetText(),"999","preset population preserves its requirement until an explicit submit")
 T.eq(page.correctionTimer,nil)
 page:Submit();T.eq(g.published.requiredItemLevel,400,"publish corrects prefilled requirements before dispatch")
 T.eq(page.correctionTimer,nil,"switching from the form to applicant management releases correction feedback")
 g.listing.requiredItemLevel=999;page.editListing:Fire("OnClick")
 T.eq(page.ilvl.box:GetText(),"999","opening an existing listing does not silently edit its requirement")
 highest=380.8;page:Submit()
 T.eq(g.updated.requiredItemLevel,380,"editing submission rereads the current highest level after equipment changes")
 page.editListing:Fire("OnClick")
 page:ShowCorrectionNotice("Transient correction");page:SetFormError("Persistent form error")
 T.eq(page.formError:GetText(),"Persistent form error");T.ok(page.formNotice:IsShown())
 T.eq(notice.text:GetText(),"Transient correction","failure feedback does not replace the correction message")
 T.eq(FormY(notice),-44-page.formNotice:GetHeight()-12,"errors and corrections occupy separate rows under the title")
 local offset=page.formNotice:GetHeight()+notice:GetHeight()+24
 T.eq(FormY(page.desc),-56-offset)
 T.eq(FormY(page.req),FormY(page.desc)+FormY(page.descriptionShell)-page.descriptionShell:GetHeight()-24,"both notices preserve the description-to-requirements gap")
 T.ok(-FormY(page.req)+page.req:GetHeight()<=page.formFrame:GetHeight()-page.publish:GetHeight()-12,"both notices reserve space without reaching the fixed publish action")
 page.formNotice.close:Fire("OnClick")
 T.ok(notice:IsShown(),"dismissing a failure keeps correction feedback")
 T.eq(FormY(notice),-44);T.eq(FormY(page.desc),-56-notice:GetHeight()-12)
 page:SetFormError("Persistent form error");timer=page.correctionTimer
 notice.close:Fire("OnClick")
 T.eq(timer.cancelled,true);T.eq(page.correctionTimer,nil)
 T.eq(page.formError:GetText(),"Persistent form error","dismissing the correction keeps the failure reason")
 T.ok(page.formNotice:IsShown());T.eq(FormY(page.desc),-56-page.formNotice:GetHeight()-12)
 page:SetFormError("");T.eq(FormY(page.desc),-56);T.eq(FormY(page.req),originalRequirementsY)
 page:ShowCorrectionNotice("Page change test");local active=page.correctionTimer;u:Navigate("notes")
 T.eq(active.cancelled,true);T.eq(page.correctionTimer,nil);T.eq(notice:IsShown(),false,"page changes clear transient feedback")
 u:Navigate("create");page.editListing:Fire("OnClick");page:ShowCorrectionNotice("Close test");active=page.correctionTimer;u:Hide(true)
 T.eq(active.cancelled,true);T.eq(page.correctionTimer,nil);T.eq(notice:IsShown(),false,"closing clears correction feedback and its sole timer")
 GetAverageItemLevel=original
end

-- Native layout rounds scaled heights; a fitting roster must not expose a thumb.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u=fresh.A,fresh.U;a:SetSetting("reduceMotion",true);a:Open("create")
 local members={}
 for i=1,40 do members[i]={name="Member"..i,nameKey="Member"..i.."-Home",class="MAGE",assignedRole="DAMAGER",subgroup=math.ceil(i/5)} end
 local fitting={};for i=1,10 do fitting[i]=members[i] end
 local tip=u.Tooltip;tip:ShowRoster(u.frame,fitting)
 T.eq(tip.interactive.memberButtons[1].name:GetText(),"Member1","current roster shows character names without realm suffixes")
 T.eq(tip.interactive.memberButtons[1].targetKey,"Member1-Home","display changes preserve full identity for member actions")
 tip.interactive.memberButtons[1]:Fire("OnClick")
 T.eq(tip.interactive.title:GetText(),"Member1-Home","personal detail keeps the server on the name line")
 T.eq(tip.member.nameKey,"Member1-Home")
 do
  local person=tip.member;local class=person.class;person.class="PALADIN"
  tip:RenderPlayer(person,true)
  local view=tip.interactive;local summary,height,metricPoint=view.summary:GetText(),view:GetHeight(),{view.metrics[1].title:GetPoint()}
  a.Specializations:Class(person.class)
  local getClass,getCount,classReads,countReads=GetClassInfo,GetNumClasses,0,0
  GetClassInfo=function(id) classReads=classReads+1;return getClass(id) end
  GetNumClasses=function() countReads=countReads+1;return getCount() end
  for _=1,20 do tip:RenderPlayer(person,true) end
  GetClassInfo,GetNumClasses=getClass,getCount
  T.eq(classReads,0,"warmed roster details reuse the core class metadata")
  T.eq(countReads,0,"warmed details do not enumerate the class directory again")
  T.eq(view.summary:GetText(),summary);T.eq(view:GetHeight(),height);T.same({view.metrics[1].title:GetPoint()},metricPoint)
  person.localizedClass="Explicit class";tip:RenderPlayer(person,true)
  T.eq(view.summary:GetText(),"Explicit class","provider-localized class names keep precedence")
  person.localizedClass=nil;person.class="UNKNOWN";tip:RenderPlayer(person,true)
  T.eq(view.summary:GetText(),u.L.unknown,"unknown class tokens retain the existing display")
  person.class=class
 end
 tip.interactive.back:Fire("OnClick")
 tip:Hide()
 local searchMember={name="浅墨影-白银之手",nameKey="浅墨影-白银之手",class="ROGUE",specName="敏锐",assignedRole="DAMAGER",isBNetFriend=true}
 local result={id=8720,name="H56",leaderName=searchMember.name,leaderKey=searchMember.nameKey,numMembers=1,maxNumPlayers=5,details={members={searchMember}}}
 tip:ShowGroup(u.frame,result)
 local searchRow=tip.interactive.memberButtons[1]
 T.eq(searchRow.name:GetText(),"浅墨影","search members display the character name when reusing a current-roster row")
 T.eq(searchRow.memberContext.source,"search");T.eq(searchRow.marks:IsShown(),false,"search relationships are never attributed to a member")
 T.eq(searchRow.member,searchMember);T.eq(searchRow.targetKey,"浅墨影-白银之手");T.ok(searchRow.leaderIcon:IsShown(),"party member crowns retain the complete leader identity")
 T.eq(tip.interactive.leader,nil);T.eq(tip.interactive.leaderIcon,nil,"party headers omit the duplicate leader identity")
 T.eq(searchMember.name,"浅墨影-白银之手");T.eq(searchMember.nameKey,"浅墨影-白银之手","displaying a roster never mutates search member identity")
 tip:Hide();tip:ShowRoster(u.frame,fitting)
 local view=tip.interactive;local getHeight=view.scroll.GetHeight
 view.scroll.GetHeight=function(self) return getHeight(self)-.00001525879 end
 tip:ShowRoster(u.frame,fitting)
 T.ok(view.memberButtons[10]:IsShown(),"both five-player subgroups remain present")
 T.eq(view.scrollbar:IsShown(),false,"native fractional height rounding does not create a spurious roster scrollbar")
 T.eq(select(2,view.scrollbar:GetMinMaxValues()),0)
 view.scroll:Fire("OnMouseWheel",-1);T.eq(view.scroll:GetVerticalScroll(),0,"a fitting roster cannot acquire a fractional wheel offset")
 tip:ShowRoster(u.frame,members)
 T.ok(view.scrollbar:IsShown(),"a genuinely overflowing eight-subgroup roster retains scrolling")
 view.scrollbar:SetValue(64);tip:RefreshRoster(u.frame,members)
 T.eq(view.scroll:GetVerticalScroll(),64,"an overflowing roster refresh retains its scroll position")
 tip:RefreshRoster(u.frame,fitting)
 T.eq(view.scrollbar:IsShown(),false);T.eq(view.scroll:GetVerticalScroll(),0,"shrinking the pooled roster clears its former scroll position")
 view.scroll.GetHeight=getHeight;tip:Hide();u:Hide(true)
end
-- Search uses native relationship summaries, separate names and leader-only notes.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g,s=fresh.A,fresh.U,fresh.G,fresh.S
 a:SetSetting("reduceMotion",true)
 local person={applicantID=81,name="荔枝小月亮-燃烧之刃",nameKey="荔枝小月亮-燃烧之刃",class="PALADIN",specName="神圣",assignedRole="HEALER",factionGroup=0,isBNetFriend=true}
 local plain={name="Ordinary-Away",nameKey="Ordinary-Away",class="MAGE",assignedRole="DAMAGER",factionGroup=1}
 a.Notes:Add("荔枝小月亮","燃烧之刃","备注内容",nil,nil,{type="neutral"})
 local marks=u.Members:CreateMarks(UIParent,true)
 T.eq(u.Members:BindMarks(marks,person),40)
 T.eq(marks.icons.bnet:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\battlenet-friend.tga")
 T.eq(marks.noteButton.icon:GetTexture(),u.Theme.media.."book.tga")
 do
  local row=u.Members:Create(UIParent)
  local identity=u.Members.Identity;local identities=0
  u.Members.Identity=function(self,member) identities=identities+1;return identity(self,member) end
  local unknown={name="Unknown",class="MAGE"};local counts={}
  for _,method in ipairs({"Bind","BindRoster","BindSearch"}) do
   identities=0
   for _=1,5 do u.Members[method](u.Members,row,person,250,true,true) end
   counts[method]=identities
   T.eq(row.marks.flags.neutral,true,"all member binding paths preserve the leader's existing note")
   identities=0;u.Members[method](u.Members,row,unknown,250,true,true)
   counts[method.."Unknown"]=identities
   T.eq(row.name:GetText(),"Unknown");T.eq(row.marks.flags.neutral,nil,"an unknown realm never inherits the previous member's note")
  end
  identities=0;u.Members:BindMarks(marks,person);local publicReads=identities
  identities=0;u.Members:BindMarks(marks,unknown);local unknownReads=identities
  u.Members.Identity=identity
  for _,method in ipairs({"Bind","BindRoster","BindSearch"}) do
   T.eq(counts[method],5,method.." resolves each member identity only once")
   T.eq(counts[method.."Unknown"],1,"a resolved nil identity is not resolved again")
  end
  T.eq(publicReads,1,"direct mark binding still resolves its own identity")
  T.eq(unknownReads,1);T.eq(marks.noteKey,nil)
  u.Members:BindMarks(marks,person);row:Hide()
 end
 local button,nodes=marks.noteButton,#s.nodes
 u.Members:BindMarks(marks,plain)
 T.eq(marks:IsShown(),false);T.eq(marks.noteKey,nil);T.eq(button:IsShown(),false)
 u.Members:BindMarks(marks,person);T.eq(#s.nodes,nodes,"rebinding reuses the textures and note button")
 person.isCharFriend=true;person.isGuildMate=true
 T.eq(u.Members:BindMarks(marks,person),84,"all three relationships coexist with the specific note kind")
 T.eq(marks.icons.friend:GetTexture(),u.Theme.productMedia.."friend.tga");T.eq(marks.icons.guild:GetTexture(),u.Theme.productMedia.."guild.tga")
 a:SetSetting("relations",false);T.eq(u.Members:BindMarks(marks,person),18,"relationship settings leave the enabled note visible")
 a:SetSetting("relations",true);a:SetSetting("noteMarks",false);T.eq(u.Members:BindMarks(marks,person),62)
 T.eq(button:IsShown(),false);T.eq(marks.noteKey,nil)
 a:SetSetting("noteMarks",true);a:SetSetting("notesEnabled",false);T.eq(u.Members:BindMarks(marks,person),62)
 a:SetSetting("notesEnabled",true)
 g.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}
 local record={id=1,activityID=2,activity=g.Catalog:GetActivity(2),activityName="Dungeon activity",categoryID=2,name="Known members",leaderName=plain.name,leaderKey=plain.nameKey,numMembers=2,maxNumPlayers=5,age=10,bnetFriends=1,charFriends=1,guildMates=1,details={members={plain,person},counts={HEALER=1,DAMAGER=1},relationships={bnet={"战网昵称"},character={person.name},guild={"公会玩家"}}}}
 g.records[1]=record;a:Open("find")
 local row=u.pages.find.results.rows[1]
 T.ok(row.marks.icons.bnet:IsShown());T.ok(row.marks.icons.friend:IsShown());T.ok(row.marks.icons.guild:IsShown())
 T.eq(row.marks.icons.neutral,nil,"a member note never marks a search result")
 T.eq(row.meta:GetText(),record.activityName,"the activity column preserves the complete native activity name")
 u.Tooltip:ShowGroup(row,record)
 local view=u.Tooltip.interactive
 T.eq(view.relationshipRows.bnet.names:GetText(),"：战网昵称")
 T.eq(view.relationshipRows.character.names:GetText(),"："..person.name)
 T.eq(view.relationshipRows.guild.names:GetText(),"：公会玩家")
 T.eq(view.relationshipRows.bnet.icon:GetTexture(),u.Members.relationshipTextures.bnet)
 local related,ordinary
 for _,entry in ipairs(view.memberButtons) do if entry.member==person then related=entry elseif entry.member==plain then ordinary=entry end end
 T.eq(related.marks:IsShown(),false);T.eq(ordinary.marks:IsShown(),false,"native group friend totals never label any member, including the leader")
 T.eq(related.name:GetText(),"荔枝小月亮");T.eq(ordinary.name:GetText(),"Ordinary")
 person.isBNetFriend=false;person.isCharFriend=false;person.isGuildMate=false;record.bnetFriends=0;record.details.relationships.bnet={};g:Notify("relations")
 T.eq(row.marks.icons.bnet:IsShown(),false);T.eq(view.relationshipRows.bnet:IsShown(),false,"updated native lists hide the pooled relationship row")
 a.Notes:Edit(person.nameKey,"Changed",{type="positive"})
 T.eq(row.marks.icons.positive,nil);T.eq(related.marks:IsShown(),false,"editing an ordinary member note does not expose it before joining")
 a.Notes:Add("Ordinary","Away","Neutral",nil,nil,{type="neutral"})
 a.Notes:Add("Caution","Away","Caution",nil,nil,{type="caution"})
 local caution={nameKey="Caution-Away"};record.details.members[3]=caution
 record.bnetFriends,record.charFriends,record.guildMates=1,1,1;g:Notify("relations")
 T.eq(row.marks:GetWidth(),84);T.ok(row.leader:GetWidth()+6+row.marks:GetWidth()<=u.pages.find.resultsHeader.columns.leader.width-8+.001,"leader name and relationship marks fit within the leader column")
 T.ok(ordinary.marks.icons.neutral:IsShown(),"only the leader note appears in the search member list")
 CheckInlineSearchMarks(ordinary)
 T.eq(ordinary.faction:IsShown(),false,"search identities never show faction icons")
 local point={ordinary.marks:GetPoint()};T.eq(point[2],ordinary.role);T.eq(point[3],"LEFT");T.eq(point[5],0,"the leader note precedes the role icon")
 a.Notes:Edit(plain.nameKey,"Updated leader",{type="positive"})
 T.ok(row.marks.icons.positive:IsShown());T.eq(row.marks.icons.neutral:IsShown(),false)
 T.ok(ordinary.marks.icons.positive:IsShown());T.eq(ordinary.marks.icons.neutral:IsShown(),false)
 T.eq(ordinary.marks.icons.bnet,nil,"summary-only counts stay separate from member identity")
 a:SetSetting("relations",false);g:Notify("relations")
 T.eq(view.relationshipRows.character:IsShown(),false);T.eq(view.relationshipRows.guild:IsShown(),false)
 T.eq(row.marks:GetWidth(),18);T.ok(ordinary.marks.icons.positive:IsShown(),"relationship visibility leaves the leader note intact")
 a:SetSetting("relations",true)
 u.Tooltip:Hide();g.listing={activityID=1,name="Raid recruitment"};g.manageApplicants=false
 person.isBNetFriend=true;g.applicants[81]={id=81,status="applied",displayOrderID=1,activityID=1,members={person}}
 a:Open("create")
 local page=u.pages.create;local batch=page.batchPool[1];local applicant=batch.people[1]
 T.eq(batch.invite:IsShown(),false);T.eq(batch.decline:IsShown(),false)
 T.eq(applicant.title:GetText(),person.nameKey);T.eq(applicant.meta,nil,"applicants have no generic note text under the name")
 T.eq(applicant.title.wrap,true);T.ok(applicant.title:GetStringHeight()<=applicant:GetHeight())
 T.ok(56+applicant.title:GetWidth()+6+applicant.marks:GetWidth()<=236,"full name and marks fit the name column")
 point={applicant.marks:GetPoint()};T.eq(point[2],applicant.title);T.eq(point[3],"RIGHT");T.eq(point[5],0)
 point={applicant.factionButton:GetPoint()};T.ok(point[#point-1]>=314,"applicant faction sits in its dedicated column")
 T.eq(applicant.faction:GetParent(),applicant.factionButton);T.eq(applicant.faction:GetPoint(),"CENTER")
 a.Notes:Edit(person.nameKey,"Caution",{type="caution"})
 T.eq(applicant.marks.noteButton.icon:GetTexture(),u.Theme.media.."caution.tga","the pooled note button follows the actual current note type")
 person.isBNetFriend=false;g:Notify("relations");T.eq(applicant.marks.icons.bnet:IsShown(),false)
 applicant.marks.noteButton:Fire("OnClick","LeftButton")
 T.eq(u.page,"notes","a non-manager can open an applicant's existing note")
 T.eq(u.pages.notes.list.selectedKey,person.nameKey)
 T.eq(u.pages.notes.eIdentity:GetText(),"荔枝小月亮");T.eq(u.pages.notes.eRealm:GetText(),"燃烧之刃")
 T.eq(u.pages.notes.typeButtons.caution.active,true)
 T.eq(g.invitedApplicant,nil);T.eq(g.declinedApplicant,nil)
 T.eq(applicant.marks.noteKey,nil,"leaving the applicant page releases the clickable player identity")
 u:Hide(true)
end

-- Title blocking follows the clicked row and leaves active applications intact.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 g.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}
 for id=1,4 do g.records[id]={id=id,activityID=2,activity=g.Catalog:GetActivity(2),categoryID=2,name=id==3 and "Different title" or "Repeated title",leaderName="Leader"..id.."-Home",leaderKey="Leader"..id.."-Home",numMembers=1,maxNumPlayers=5,age=10} end
 local application={id=4,status="applied",categoryID=2,result=g.records[4],expiresAt=GetTime()+300}
 g.apps={application}
 a:Open("find")
 local page=u.pages.find
 local function ChooseBlock()
  local menu=u.context.menu
  for i,item in ipairs(menu.items) do if item.value=="blockTitle" then
   T.eq(item.label,locale=="zhCN" and "屏蔽相同标题队伍" or "Block groups with this title")
   local row=menu.list.rows[i];row:Fire("OnMouseDown","LeftButton");row:Fire("OnClick","LeftButton");return
  end end
  error("missing title-block menu action")
 end
 page.results.clip.mouseOver=true
 local row=page.results.rows[1];row:Fire("OnMouseDown","RightButton");row:Fire("OnClick","RightButton")
 ChooseBlock()
 T.same(page.results.ids,{3},"right-click blocking removes every matching result")
 T.eq(g.Results:GetBlockedTitleCount(),1)
 T.same(page.appList.ids,{4});T.eq(g:GetApplication(4),application);T.eq(g.cancelled,nil,"blocking never cancels or removes an application")
 page:ClearFilters();T.same(page.results.ids,{3},"ordinary filter clearing preserves the separate title blocks")
 u:Hide(true);a:Open("find")
 T.same(page.results.ids,{3},"closing and reopening Find keeps session title blocks")
 g.records[4]=nil;application.result.name="Application-only title";application.result.leaderKey="ApplicationOnly-Home"
 page:OpenResultMenu(page.appList,4);ChooseBlock()
 T.eq(g.db.blockedLeaders["ApplicationOnly-Home"],true,"the application menu passes the selected leader even outside current results")
 page:OpenResultMenu(page.results,3)
 for _,item in ipairs(u.context.menu.items) do if item.value=="block" then T.eq(item.label,locale=="zhCN" and "荔枝笔记：拉黑" or "Player Notes: Block","note blocking remains distinct from blocked leaders") end end
 u:CloseMenu()
 g.records[1].name="Changed title";g:Notify("results")
 T.same(page.results.ids,{3},"the clicked leader remains blocked after changing the title")
 u:Hide(true)
end

-- Block management loads Group only on entry and reuses the existing list pool.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local ensure,loads=a.Ensure,0
 a.Ensure=function(self,module) if module=="Group" then loads=loads+1 end;return ensure(self,module) end
 a:Open("settings");local page=u.pages.settings
 T.eq(loads,0,"ordinary settings do not load Group");T.eq(page.blocksList,nil,"the block list is created on first use")
 for id=1,40 do g.Results:BlockTitle("Blocked title "..id,("Blocked%02d-Away"):format(id)) end
 page.nav.blocks:Fire("OnClick")
 T.eq(page.heading:GetText(),locale=="zhCN" and "屏蔽名单" or "Blocked leaders")
 T.eq(loads,1);T.eq(fresh.Count(g.subs),1,"only the active block section subscribes to result changes")
 local list=page.blocksList
 T.eq(#list.ids,40);T.ok(#list.rows<40,"blocked leaders use a virtualized row pool")
 T.eq(list.rows[1].title:GetText(),"Blocked01","rows display the player name")
 T.eq(list.rows[1].meta:GetText(),"Away","the complete realm has its own column")
 local first=list.rows[1].remove
 first:Fire("OnClick");T.eq(#g.Results:GetBlockedLeaders(),40,"clipped action buttons cannot remove a player")
 list.clip.mouseOver=true
 first:Fire("OnMouseDown");list:SetPixelOffset(list.rowHeight*3,false);first:Fire("OnClick")
 T.eq(#g.Results:GetBlockedLeaders(),40,"rebinding a pressed remove button cannot remove another player")
 local key=list.rows[1].key
 first:Fire("OnMouseDown");first:Fire("OnClick")
 T.eq(g.db.blockedLeaders[key],nil);T.eq(#list.ids,39,"single removal refreshes the active list")
 g.Results:BlockTitle("Another title","Another-Home");T.eq(#list.ids,40,"external blocking updates the visible list")
 local nodes=#fresh.S.nodes -- First scroll has materialized the other alternating row surfaces.
 for _,percent in ipairs({70,100,130}) do
  a:SetSetting("fontScale",percent);list:SetPixelOffset(0,false)
  local row=list.rows[1];local point={list:GetPoint()};local top=-point[#point]
  T.ok(top+list:GetHeight()<=page.panels.blocks:GetHeight()+.001,"the block list fits at each font size")
  T.ok(row.title:GetStringHeight()+16<=row:GetHeight(),"complete identities fit their scaled row")
  T.near(row.remove:GetWidth(),math.ceil(row.remove.label:GetStringWidth())+32,.001,"remove buttons retain text padding")
  T.near(page.blocksClear:GetWidth(),math.ceil(page.blocksClear.label:GetStringWidth())+32,.001,"clear buttons retain text padding")
  local function Left(region) local p={region:GetPoint()};return p[#p-1] end
  local cols=page.blocksHeader.columns
  T.ok(Left(row.title)+row.title:GetWidth()<=cols.realm.x+.001 and Left(row.meta)+row.meta:GetWidth()<=cols.actions.x+.001,"name and realm remain separate within their adjustable cells")
  T.ok(Left(row.remove)>=cols.actions.x-.001 and Left(row.remove)+row.remove:GetWidth()<=cols.actions.x+cols.actions.width+.001,"remove actions stay within the actions cell")
  T.ok(row.meta:GetStringWidth()<=row.meta:GetWidth(),"realm text fits at each font size")
 end
 T.eq(#fresh.S.nodes,nodes,"font changes reuse the block-list controls")
 page.blocksClear:Fire("OnClick")
 T.eq(#list.ids,0);T.eq(g.Results:GetBlockedTitleCount(),0);T.eq(page.blocksClear:IsEnabled(),false)
 T.eq(page.blocksEmpty:IsShown(),true);T.eq(list:IsShown(),false)
 g.Results:BlockTitle("Title without a known leader")
 T.eq(#list.ids,0);T.eq(page.blocksClear:IsEnabled(),true,"title rules can be cleared even when no leader is known")
 page.blocksClear:Fire("OnClick");T.eq(page.blocksClear:IsEnabled(),false)
 page:SelectSection("general")
 T.eq(fresh.Count(g.subs),0);T.eq(page.blockGroup,nil);T.eq(list.ids,nil,"leaving the section releases list identities")
 for _,row in ipairs(list.rows) do T.eq(row.remove.targetKey,nil) end
 page:SelectSection("blocks");T.eq(loads,2);T.eq(fresh.Count(g.subs),1)
 a:Open("settings",{section="blocks"});T.eq(loads,2);T.eq(fresh.Count(g.subs),1,"same-section entry reuses the subscription")
 u:Hide(true);T.eq(fresh.Count(g.subs),0);T.eq(page.blockGroup,nil,"closing settings unsubscribes from block changes")
end

-- A failed lazy load stays local to block management and can be retried on entry.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local ensure=a.Ensure
 a.Ensure=function(self,module) if module=="Group" then return nil,"Group load failed" end;return ensure(self,module) end
 a:Open("settings",{section="blocks"});local page=u.pages.settings
 T.eq(page.blocksEmpty:GetText(),"Group load failed");T.eq(page.blocksClear:IsEnabled(),false);T.eq(fresh.Count(g.subs),0)
 a.Ensure=ensure;a:Open("settings",{section="blocks"})
 T.eq(page.blockGroup,g);T.eq(page.blocksEmpty:GetText(),"暂无屏蔽的队长");T.eq(fresh.Count(g.subs),1)
 u:Hide(true);T.eq(fresh.Count(g.subs),0)
end

-- Header widths can be unavailable during construction or until the first visible frame.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 local a,u,s=fresh.A,fresh.U,fresh.S
 a:SetSetting("reduceMotion",true)
 local proto=getmetatable(s.nodes[1]);local measure,natural=proto.GetStringWidth,proto.GetUnboundedStringWidth
 local pending,factor=true,1
 function proto:GetUnboundedStringWidth()
  local header=self.text==u.L.find or self.text==u.L.create or self.text==u.L.notes or self.text==u.L.settings
  if header and u.frame then
   if pending or not u.frame:IsShown() then return 0 end
   return natural(self)*factor
  end
  return natural(self)
 end
 proto.GetStringWidth=proto.GetUnboundedStringWidth
 local function CheckHeader()
  local x=0
  for _,key in ipairs({"find","create","notes"}) do
   local button=u.navItems[key]
   T.near(button:GetWidth(),button.label:GetStringWidth()+38,.01,"navigation contains its full icon and label after text metrics become ready")
   T.near(button.navX,x,.01,"navigation preserves the gap after the previous complete label")
   x=x+button:GetWidth()+u.Theme.navGap
  end
  T.near(u.settingsButton:GetWidth(),u.settingsButton.label:GetStringWidth()+52,.01,"settings text stays inside its pill and away from the close control")
  T.near(u.underline:GetWidth(),u.navItems.find.label:GetStringWidth(),.51,"the current underline follows the corrected label width")
  T.eq(u.frame:GetScript("OnUpdate"),nil,"header correction detaches after one frame")
 end
 a:Open("find")
 pending=false;u.frame:Fire("OnUpdate",.016);CheckHeader()
 pending=true;factor=1.25;u:ApplyFont(u.Theme.font)
 pending=false;u.frame:Fire("OnUpdate",.016);CheckHeader()
 u:Hide(true);factor=1.5;u:ApplyFont(u.Theme.font)
 a:Open("find");u.frame:Fire("OnUpdate",.016);CheckHeader()
 pending=true;u:ApplyFont(u.Theme.font);u:Hide(true)
 T.eq(u.frame:GetScript("OnUpdate"),nil,"closing the window cancels its pending header correction")
 proto.GetStringWidth,proto.GetUnboundedStringWidth=measure,natural
end

-- The settings pill centers its complete icon/label group, including after font changes.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 fresh.A:SetSetting("reduceMotion",true);fresh.A:Open("settings")
 local u=fresh.U;local button=u.settingsButton
 local function CheckSettingsPadding()
  local iconPoint={button.icon:GetPoint()};local textPoint={button.label:GetPoint()}
  local left=iconPoint[#iconPoint-1]
  local right=button:GetWidth()-textPoint[#textPoint-1]-button.label:GetStringWidth()
  T.near(left,right,.01,"settings icon and label have equal outer padding")
 end
 CheckSettingsPadding();u:ApplyFont(u.Theme.font);CheckSettingsPadding()
 button:Fire("OnEnter");CheckSettingsPadding();button:Fire("OnLeave")
 fresh.A:Open("find")
 local page=u.pages.find
 local function CenterOffset(region)
  local point={region:GetPoint()};local offset=point[#point]
  return point[1]:find("TOP") and offset-region:GetHeight()/2 or offset
 end
 T.near(CenterOffset(page.appsTitle),-page.applicationPanel:GetHeight()/2,.01,"the empty application title centers in its header band")
 T.near(CenterOffset(page.autoJoin),CenterOffset(page.appsTitle),.01,"both switches share the title's vertical center")
 u:ApplyFont(u.Theme.font)
 T.near(CenterOffset(page.autoJoin),CenterOffset(page.appsTitle),.01,"changing typeface preserves header alignment")
 T.near(page.autoJoin:GetWidth(),math.ceil(page.autoJoin.label:GetStringWidth())+56,.01,"font changes update the complete auto-join label width")
 fresh.A:Open("create")
 local create=u.pages.create;local widths={}
 T.eq(u.Application:OpenApplicationSettings(),true)
 local modal=u.Application.applicationModal;u:CloseModal()
 local controls={create.private,create.crossFaction,create.autoAccept,create.cancelListing,create.editListing,modal.cancel}
 for _,role in ipairs({"ALL","TANK","HEALER","DAMAGER"}) do controls[#controls+1]=create.roleFilters[role] end
 for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do controls[#controls+1]=modal.roles[role] end
 for _,option in ipairs(controls) do
  local width,natural=option.label.GetStringWidth,option.label.GetUnboundedStringWidth;widths[option]={width,natural}
  option.label.GetStringWidth=function(self) return natural(self)*1.5 end
  option.label.GetUnboundedStringWidth=option.label.GetStringWidth
 end
 fresh.A:Open("settings");u:ApplyFont(u.Theme.font);fresh.A:Open("create")
 local right=0
 for _,option in ipairs({create.private,create.crossFaction,create.autoAccept}) do
  local point={option:GetPoint()};local left=point[#point-1]
  T.ok(left>=right,"a wider font never overlaps the previous creation option")
  T.ok(option:GetWidth()>=52+option.label:GetStringWidth(),"each option's hitbox contains its complete wider label")
  right=left+option:GetWidth()+28
 end
 for _,button in ipairs({create.cancelListing,create.editListing}) do T.ok(button:GetWidth()>=button.label:GetStringWidth()+34,"listing actions retain their label padding after a font change") end
 T.near(create.sName:GetWidth(),create.manage:GetWidth()-116-create.cancelListing:GetWidth()-8-create.editListing:GetWidth(),.01,"the listing summary reserves the resized action area")
 right=3
 for _,role in ipairs({"ALL","TANK","HEALER","DAMAGER"}) do
  local button=create.roleFilters[role];local point={button:GetPoint()};local x=point[#point-1]
  T.ok(x>=right,"role filters do not overlap after a font change")
  T.ok(button:GetWidth()>=button.label:GetStringWidth()+24+(role~="ALL" and 22 or 0))
  right=x+button:GetWidth()+4
 end
 T.near(create.roleFilterSurface:GetWidth(),right-1,.01)
 T.eq(u.Application:OpenApplicationSettings(),true)
 for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do
  local button=modal.roles[role]
  T.near(button:GetWidth(),button.label:GetStringWidth()+60,.01,"reopened application roles include the new font width")
 end
 T.ok(modal.cancel:GetWidth()>=modal.cancel.label:GetStringWidth()+40,"application cancel retains full text padding")
 u:CloseModal()
 for _,option in ipairs(controls) do option.label.GetStringWidth,option.label.GetUnboundedStringWidth=widths[option][1],widths[option][2] end
 u:ApplyFont(u.Theme.font)
 u:Hide(true)
end

-- English layout uses the addon locale even on a Chinese client.
for _,locale in ipairs({"enUS","zhCN"}) do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN",nil,{language=locale})
 local a,u=fresh.A,fresh.U;a:SetSetting("reduceMotion",true);a:Open("find")
 local page=u.pages.find
 local any=locale=="zhCN" and "不限" or "Any"
 T.eq(page.fMinMembers.placeholder:GetText(),locale=="zhCN" and "最少 1" or "Min 1","minimum endpoint follows the addon language and lower capacity bound")
 T.eq(page.fMembers.placeholder:GetText(),locale=="zhCN" and "最多 5" or "Max 5")
 for _,row in ipairs(page.seasonCategories.rows) do
  if row.key and locale=="enUS" then T.ok(row:GetHeight()>=row.title:GetStringHeight()+16,"two-line season categories retain eight units of vertical padding") end
 end
 a:Open("create");T.eq(u.pages.create.ilvl.placeholder:GetText(),any);T.eq(u.pages.create.score.placeholder:GetText(),any)
 a:Open("notes")
 local notes=u.pages.notes
 for _,button in pairs(notes.tabs) do T.ok(button.label:GetStringWidth()<=button.label:GetWidth(),"complete note navigation labels fit beside their counts") end
 local function CheckAddPadding()
  local button=notes.addButton
  T.ok(button:GetWidth()>=button.label:GetStringWidth()+56,"the add label, icon, gap and outer padding all fit")
  local iconPoint={button.icon:GetPoint()};local labelPoint={button.label:GetPoint()}
  local left=iconPoint[#iconPoint-1];local textX=labelPoint[#labelPoint-1]
  T.eq(textX-left-button.icon:GetWidth(),8,"the add icon stays eight units from its label")
  T.ok(left>=16,"the add icon has full outer padding")
  T.near(button:GetWidth()-textX-button.label:GetStringWidth(),left,1,"the complete add button content is centered")
 end
 CheckAddPadding();u:ApplyFont(u.Theme.font);CheckAddPadding();u:Hide(true)
end

-- Character defaults survive a new UI session; only confirmed, available roles are saved.
do
 local preferences={defaultSort="members",rememberFilters=true,applicationRoles={TANK=true,HEALER=true,DAMAGER=false},find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,groupKey=20,difficultyID=8,minMembers="2",maxMembers="4",sort="rating"}}}}
 local fresh=dofile("tests/ui_fixture.lua")("enUS",preferences,{defaultSort="itemLevel",rememberFilters=false})
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 g.records[901]={id=901,name="Saved roles",activityID=2,activity=g.Catalog:GetActivity(2),activityName="Dungeon activity",categoryID=2,leaderName="Leader-Home",leaderKey="Leader-Home",numMembers=2,maxNumPlayers=5,age=1,details={members={{name="Leader-Home",nameKey="Leader-Home",class="WARRIOR",assignedRole="TANK",isLeader=true},{name="Member-Home",nameKey="Member-Home",class="MAGE",assignedRole="DAMAGER"}}}}
 local countMembers=u.MemberCounts
 u.MemberCounts=function() error("five-player result and application rows must not calculate unused role counts") end
 a:Open("find")
 local page=u.pages.find;local application=u.Application;local dialog=LFGListApplicationDialog
 T.eq(g.prefs,a.charPrefs);T.eq(page.fMinMembers.box:GetText(),"2");T.eq(page.fMembers.box:GetText(),"4")
 T.eq(g.filters.sort,"rating","the category preserves this character's saved fallback sorting")
 T.eq(page.results.rows[1].roster.slots[1].icon:GetTexture(),"Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES","removing unused counts preserves the actual player's class icon")
 T.ok(page.results.rows[1].roster.slots[2].icon:IsShown());T.eq(page.results.rows[1].roster.slots[3].icon:IsShown(),false,"only the two actual members have portraits")
 T.eq(application:IsAutoApplyEnabled(),false,"saved roles alone do not enable automatic application")
 T.same(application.applicationPrefs.roles,{TANK=true,HEALER=true})
 page:ClearFilters();T.eq(g.filters.sort,"rating","clearing conditions preserves existing sorting")
 T.eq(a.charPrefs.find.categoryPrefs.seasonDungeon.sort,"rating");T.eq(g.db.prefs.find,nil,"Find never writes the account migration seed")
 application:Apply(901)
 T.eq(application.applicationLease.roles.TANK,true);T.eq(application.applicationLease.roles.HEALER,nil,"unavailable remembered roles are filtered before confirmation")
 local modal=application.applicationModal
 modal.roles.TANK:Fire("OnClick");modal.roles.DAMAGER:Fire("OnClick");u:CloseModal()
 T.same(preferences.applicationRoles,{TANK=true,HEALER=true,DAMAGER=false},"cancelled edits do not change saved role defaults")
 application:Apply(901);T.eq(application.applicationLease.roles.TANK,true,"cancelled changes do not alter the next default selection")
 local nativeApply=C_LFGList.ApplyToGroup
 C_LFGList.ApplyToGroup=function() error("Rejected") end
 modal.roles.TANK:Fire("OnClick");modal.roles.DAMAGER:Fire("OnClick");modal.submit:Fire("OnClick")
 T.same(preferences.applicationRoles,{TANK=true,HEALER=true,DAMAGER=false},"a failed submission does not save one-off roles")
 C_LFGList.ApplyToGroup=nativeApply;modal.submit:Fire("OnClick")
 T.same(preferences.applicationRoles,{TANK=false,HEALER=false,DAMAGER=true},"a successful manual confirmation saves this character's next roles")
 T.eq(application:IsAutoApplyEnabled(),false);T.eq(preferences.enabled,nil);T.eq(preferences.note,nil)
 g.apps={{id=901,status="applied",result=g.records[901]}};page:RefreshApplications()
 T.ok(page.appList.rows[1].roster.slots[2].icon:IsShown(),"pinned applications keep both actual five-player members without unused counts")
 T.eq(page.appList.rows[1].roster.slots[3].icon:IsShown(),false)
 u.MemberCounts=countMembers
 a:Open("settings",{section="browse"})
 local settings=u.pages.settings
 T.eq(settings.controls.defaultSort.widget.value,"members");T.eq(settings.controls.rememberFilters.widget.value,true)
 fresh.Pick(settings.controls.defaultSort.widget,"rating")
 T.eq(a.charPrefs.defaultSort,"rating");T.eq(a.db.defaultSort,"itemLevel","settings do not rewrite the account migration seed")
 settings.controls.rememberFilters.widget:Fire("OnClick");T.eq(a.charPrefs.rememberFilters,false);T.eq(a.db.rememberFilters,false)
 u:Hide(true)
 local restored=dofile("tests/ui_fixture.lua")("zhCN",preferences)
 restored.A:SetSetting("reduceMotion",true);restored.A:Open("find")
 T.eq(restored.U.Application:IsAutoApplyEnabled(),false,"reloading without an enabled flag restores roles and keeps automation off")
 T.same(restored.U.Application.applicationPrefs.roles,{DAMAGER=true})
 T.eq(restored.A.charPrefs.applicationRoles,preferences.applicationRoles)
 restored.U:Hide(true)
end

-- Search notifications own list refreshes, including queued requests and preview.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS",{find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true}}}})
 local a,u,g=fresh.A,fresh.U,fresh.G
 g.Game={RefreshSubscriptions=function() end}
 function g:HasViews(kind) for _,value in pairs(self.views) do if not kind or value==kind then return true end end;return false end
 function g.Results:BeginSearch() g.records={};g:Notify("results") end
 dofile("addon/LycheeGroup_Group/Search.lua")
 function g:GetSearchState() return self.Search:GetState() end
 function g:GetSearchError() return self.Search:GetSearchError() end
 local nativeCalls=0
 C_LFGList.GetLanguageSearchFilter=function() return 0 end
 C_LFGList.Search=function() nativeCalls=nativeCalls+1 end
 a:Open("find")
 local page=u.pages.find;local refresh=page.RefreshResults;local fills=0
 page.RefreshResults=function(self,...) fills=fills+1;return refresh(self,...) end
 g.Search.state="done";fills=0
 page:DoSearch()
 T.eq(fills,2,"a native search refreshes for changed filters and its cleared result snapshot only")
 T.eq(g.Search:GetState(),"searching");T.eq(page.refresh:IsEnabled(),false)
 g.Results.FailSearch=g.Results.BeginSearch
 g.Search:OnSearchFailed("throttled")
 local calls=nativeCalls;fills=0
 page:DoSearch()
 T.eq(fills,1,"a waiting request refreshes changed local filters without a duplicate tail repaint")
 T.eq(nativeCalls,calls);T.ok(g.Search.pending);T.eq(page.refresh:IsEnabled(),false)
 u:Hide(true);g.Search:EndBrowse() -- This fixture's Attach/Detach only tracks view ownership.
 T.eq(a:Preview("applications"),true)
 page:CommitChoice();page.search.box:SetText("");fills=0
 page:DoSearch()
 T.eq(fills,1,"preview search needs only its filter notification to bind results")
 T.eq(#page.results.ids,3);T.eq(#page.appList.ids,3);T.eq(nativeCalls,calls,"preview never submits a native search")
 u:Hide(true)
end

-- Selected dungeon groups must narrow the native request, before local filtering.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local nativeActivity,nativeGroups=C_LFGList.GetActivityInfoTable,C_LFGList.GetActivityGroupInfo
 local activities={}
 for index,entry in ipairs({{2001,201,8},{2002,201,1},{2003,201,2},{2101,202,8},{2102,202,1},{2201,203,8}}) do
  activities[entry[1]]={categoryID=2,groupFinderActivityGroupID=entry[2],difficultyID=entry[3],isMythicPlusActivity=entry[3]==8,fullName="Dungeon "..entry[2],shortName="Dungeon "..entry[2],maxNumPlayers=5,orderIndex=index}
 end
 C_LFGList.GetActivityInfoTable=function(id) return activities[id] or nativeActivity(id) end
 C_LFGList.GetAvailableActivities=function(category) if category==2 then return {2001,2002,2003,2101,2102,2201} end;return {1} end
 C_LFGList.GetActivityGroupInfo=function(id) return ({[201]="Ruby Life Pools",[202]="Second dungeon",[203]="Third dungeon"})[id] or nativeGroups(id) end
 g.Catalog:Invalidate()
 g.Game={RefreshSubscriptions=function() end}
 function g:HasViews(kind) for _,value in pairs(self.views) do if not kind or value==kind then return true end end;return false end
 function g.Results:BeginSearch() g.records={};g:Notify("results") end
 function g.Results:CommitResults() end
 dofile("addon/LycheeGroup_Group/Search.lua")
 function g:GetSearchState() return self.Search:GetState() end
 function g:GetSearchError() return self.Search:GetSearchError() end
 C_LFGList.GetLanguageSearchFilter=function() return 0 end
 local nativeFilters={}
 C_LFGList.Search=function(category,filter,preferred,language,search,filterOptions,activityIDsFilter)
  local ids={};for _,id in ipairs(activityIDsFilter or {}) do ids[#ids+1]=id end;table.sort(ids)
  nativeFilters[#nativeFilters+1]=table.concat(ids,",")
 end
 a:Open("find");local page=u.pages.find
 local function Row(key) for _,row in ipairs(page.activities.rows) do if row.key==key then return row end end;error("missing activity row "..key) end
 local function Difficulty(id) for _,button in ipairs(page.difficultyButtons) do if button:IsShown() and button.value==id then button:Fire("OnClick");return end end;error("missing difficulty "..tostring(id)) end
 page:SelectCategory("seasonDungeon");Difficulty(8)
 Row(201).multiSelect:Fire("OnClick");page.pickerConfirm:Fire("OnClick")
 T.eq(#nativeFilters,1,"the first confirmed collection reaches the real native search")
 g.Search:OnResultsReceived()
 page:SelectCategory("seasonDungeon");Row(202).multiSelect:Fire("OnClick");page.pickerConfirm:Fire("OnClick")
 T.eq(#nativeFilters,2,"the second confirmed collection reaches the real native search")
 g.Search:OnResultsReceived()
 page:SelectCategory("seasonDungeon");Difficulty(false);Row(201):Fire("OnClick","LeftButton")
 T.eq(#nativeFilters,3,"an explicit single-group All choice reaches the real native search")
 g.Search:OnResultsReceived();u:Hide(true)
 T.eq(table.concat(nativeFilters," | "),"2001 | 2001,2101 | 2001,2002,2003","native activityIDsFilter must contain only the selected dungeon groups and difficulty: single keystone | multiple keystones | one group's complete variants")
end

-- Closing skips applicant presentation, while the real service keeps terminal deadlines.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;local now=0
 GetTime=function() return now end
 g.Public=function(value) return value end
 function g:RemotePlayerKey(name) return name and a:PlayerKey(name) end
 g.Relations={ApplyMembers=function() return 0 end,GetVersion=function() return 0 end}
 g.Listing={GetListing=function() return g.listing end}
 local previousEye=QueueStatusButton
 QueueStatusButton={glowLocks={},SetGlowLock=function(self,key,enabled,count) self.glowLocks[key]=enabled and (count or -1) end}
 LFGListFrame:Hide()
 g.listing={activityID=2,name="Listing",requiredItemLevel=0}
 local status="applied"
 C_LFGList.HasActiveEntryInfo=function() return true end
 C_LFGList.GetApplicants=function() return {1} end
 C_LFGList.RefreshApplicants=function() end
 C_LFGList.GetApplicantInfo=function() return {applicationStatus=status,numMembers=1,displayOrderID=1,comment="A note"} end
 C_LFGList.GetApplicantMemberInfo=function() return "Applicant-Away","WARRIOR","Warrior",80,600,0,false,false,true,"DAMAGER",nil,2500,nil,0,nil,71,false end
 dofile("addon/LycheeGroup_Group/Applicants.lua")
 dofile("addon/LycheeGroup_Group/Alerts.lua")
 function g:SetApplicantView(owner,visible) self.Alerts:SetViewed(owner,visible) end
 local lists,reads=0,0
 function g:GetApplicants() lists=lists+1;return self.Applicants:GetApplicants() end
 function g:GetApplicant(id) reads=reads+1;return self.Applicants:GetApplicant(id) end
 function g:RefreshApplicants() return self.Applicants:RequestRefresh() end
 g.Applicants:RefreshList()
 T.eq(QueueStatusButton.glowLocks["lfglist-applicant"],-1,"a hidden real applicant service starts the native reminder")
 a:Open("create");local page=u.pages.create;u.Motion:Tick(.5)
 T.eq(QueueStatusButton.glowLocks["lfglist-applicant"],false,"entering the actual applicant page acknowledges the reminder")
 local ids=page.appIDs
 u:Hide();u.Motion:Tick(.1);lists,reads=0,0
 status="cancelled";g.Applicants:OnApplicantUpdated(1);fresh.base.AdvanceClock(0)
 T.eq(g.Applicants:GetApplicant(1).status,"cancelled","closing does not delay the native applicant status")
 T.eq(lists,0);T.eq(reads,0,"the closing page performs no applicant lookup or sorting")
 T.eq(page.appIDs,ids,"the leaving animation retains its existing applicant bindings")
 u:Show("create");u.Motion:Tick(.5)
 T.eq(u.hiding,nil);T.eq(u.frame:IsShown(),true);T.eq(g.views[page],"create")
 T.ok(reads>0,"a reversed close refreshes the latest applicants on entry")
 T.eq(page.batchPool[1].status:GetText(),u.L.states.cancelled)
 now=5;fresh.base.AdvanceClock(5)
 T.eq(g.Applicants:GetApplicant(1),nil);T.eq(#page.appIDs,0,"confirmed terminal rows expire after a quick reopen without another page change")
 T.eq(fresh.base.PendingTimers(),0)
 u:Hide();u.Motion:Tick(.5)
 T.eq(page.unsub,nil);T.eq(next(g.views),nil);T.eq(u.Motion.jobs[page.batchScroll],nil)
 status="applied";g.Applicants:RefreshList();fresh.base.AdvanceClock(0)
 T.eq(QueueStatusButton.glowLocks["lfglist-applicant"],-1,"a closed main window releases its applicant-view ownership")
 T.eq(a:Preview("applicants"),true)
 T.eq(QueueStatusButton.glowLocks["lfglist-applicant"],-1,"preview applicants never acknowledge a real reminder")
 u:Hide(true);a:Open("create")
 T.eq(QueueStatusButton.glowLocks["lfglist-applicant"],false,"returning to the live applicant page acknowledges it")
 page.editListing:Fire("OnClick");g.Alerts:Update(true)
 T.eq(QueueStatusButton.glowLocks["lfglist-applicant"],-1,"the editing form does not claim the hidden applicant list is visible")
 page.formCancel:Fire("OnClick")
 T.eq(QueueStatusButton.glowLocks["lfglist-applicant"],false,"returning from editing acknowledges the visible applicants")
 u:Hide(true);g.Applicants:Clear();QueueStatusButton=previousEye
end

-- Search and saved-application details follow the current leader and faction.
do
 for _,notification in ipairs({"result","results","applications","dirtyBatch"}) do
  local fresh=dofile("tests/ui_fixture.lua")("zhCN",{find={category="3",categoryPrefs={["3"]={selected=true}}}})
  local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true);a:SetSetting("raidMembers","shift")
  EJ_GetDifficulty=function() return 14 end;EJ_SelectInstance=function() end;EJ_GetEncounterInfoByIndex=function() end
  local alpha={name="Alpha-Away",nameKey="Alpha-Away",class="WARRIOR",assignedRole="TANK",isLeader=true,factionGroup=1}
  local beta={name="Beta-Away",nameKey="Beta-Away",class="MAGE",assignedRole="DAMAGER"}
  local record={id=7,activityID=1,activity=g.Catalog:GetActivity(1),categoryID=3,name="Raid group",comment=string.rep("Complete description. ",200),leaderName=alpha.name,leaderKey=alpha.nameKey,leaderFactionGroup=1,numMembers=2,maxNumPlayers=30,age=10,details={members={alpha,beta},counts={TANK=1,HEALER=0,DAMAGER=1}}}
  local other={id=8,activityID=1,activity=record.activity,categoryID=3,name="Other group",leaderName="Other-Away",leaderKey="Other-Away",leaderFactionGroup=1,numMembers=1,maxNumPlayers=30,age=20,details={members={{name="Other-Away",nameKey="Other-Away",class="MAGE",isLeader=true,factionGroup=1}},counts={TANK=0,HEALER=0,DAMAGER=1}}}
  g.records[7],g.records[8]=record,other
  local application={id=7,status="applied",categoryID=3,name=record.name,leaderName=alpha.name,result=record,expiresAt=GetTime()+300}
  if notification=="applications" then g.apps={application} end
  a:Open("find")
  local page,tip=u.pages.find,u.Tooltip
  local deferred=notification=="result" or notification=="dirtyBatch"
  local function Notify(id)
   if notification=="dirtyBatch" then
    local changed={[id]=true};g:Notify("results",changed);wipe(changed)
   else g:Notify(notification,id) end
  end
  local list=notification=="applications" and page.appList or page.results
  local function RowFor(target,id) for _,row in ipairs(target.rows) do if row.key==id then return row end end end
  local row=RowFor(list,7);list.clip.mouseOver=true;row.mouseOver=true;row.tooltipArea:Fire("OnEnter")
  local view=tip.interactive;view:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",1)
  T.eq(view:GetWidth(),880);tip.pinned=true;tip.outsideClicks:Show();view.scrollbar:SetValue(48)
  local scroll,x,y=view.scroll:GetVerticalScroll(),tip.positionX,tip.positionY
  T.eq(scroll,48,"the full description gives the tooltip a real scroll position to preserve")
  local render=tip.RenderGroup;local renders=0
  tip.RenderGroup=function(self,...) renders=renders+1;return render(self,...) end
  if deferred then
   Notify(8);u.Motion:Tick(.02)
   T.eq(renders,0,"another result does not redraw the open tooltip")
  end
  record.leaderName,record.leaderKey,record.leaderFactionGroup=beta.name,beta.nameKey,0;application.leaderName=beta.name
  alpha.isLeader,alpha.factionGroup=nil,nil;beta.isLeader,beta.factionGroup=true,0
  Notify(7)
  if deferred then
   Notify(7)
   T.eq(renders,0,"single-result tooltip updates wait for the existing frame batch")
  end
  u.Motion:Tick(.02)
  T.eq(renders,1,notification.." refreshes the open source once after its rows")
  T.eq(row.leader:GetText(),"Beta");T.eq(view.memberButtons[1].member,beta,"the tooltip follows the changed leader in the member list")
  T.eq(view.memberButtons[1].targetKey,beta.nameKey,"leader updates preserve the real member identity")
  local alphaRow,betaRow
  for _,memberRow in ipairs(view.memberButtons) do
   if memberRow.member==alpha then alphaRow=memberRow elseif memberRow.member==beta then betaRow=memberRow end
  end
  T.eq(alphaRow.leaderIcon:IsShown(),false,"the former leader loses its member crown")
  T.eq(betaRow.leaderIcon:IsShown(),true,"the new leader gains the member crown")
  CheckRaidLeaderFooter(view,beta.name,u,"MAGE")
  T.eq(alphaRow.faction:IsShown(),false,"the former leader loses its unsupported faction marker")
  T.eq(betaRow.faction:IsShown(),false,"a new search leader also has no faction marker")
  T.eq(tip.expanded,true);T.eq(tip.pinned,true);T.eq(view:GetWidth(),880)
  T.eq(view.scroll:GetVerticalScroll(),scroll);T.eq(tip.positionX,x);T.eq(tip.positionY,y)
  if deferred then
   Notify(7);tip:Hide()
   local nextRow=RowFor(page.results,8);nextRow.mouseOver=true;nextRow.tooltipArea:Fire("OnEnter");renders=0
   u.Motion:Tick(.02)
   T.eq(renders,0,"a queued result does not redraw a different tooltip opened before the batch")
   T.eq(tip.record,other)
  end
  u:Hide(true)
 end
end

-- Notes categories share the same moving sidebar selection and content reveal.
do
 local f=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u=f.A,f.U
 a.Notes:Add("MotionNeutral","Away","neutral",nil,nil,{type="neutral"})
 a.Notes:Add("MotionPositive","Away","positive",nil,nil,{type="positive"})
 a:SetSetting("reduceMotion",false);a:Open("notes")
 local p,m=u.pages.notes,u.Motion;m:Tick(2)
 T.ok(p.tabSelection,"notes use the shared moving sidebar background and mark")
 local function X(region) return select(4,region:GetPoint()) end
 local function Y(region) return select(5,region:GetPoint()) end
 local sidebarY=Y(p.tabSelection)
 p.tabs.positive:Fire("OnClick")
 T.eq(Y(p.tabSelection),sidebarY,"category input commits before the shared sidebar moves")
 T.eq(p.tabSelection.mark:IsShown(),true)
 T.eq(X(p.left),56,"forward note categories enter from the standard right offset")
 T.ok(p.left:GetAlpha()<1 and m.jobs[p.left],"the records heading and populated list enter as one container")
 T.eq(p.emptyState:IsShown(),false)
 T.eq(p.list.ids[1],"MotionPositive-Away")
 m:Tick(.05)
 T.ok(Y(p.tabSelection)<sidebarY,"notes sidebar passes through a visible intermediate position")
 local x,alpha,sideY=X(p.left),p.left:GetAlpha(),Y(p.tabSelection)
 p.tabs.caution:Fire("OnClick")
 T.eq(#p.list.ids,0);T.eq(p.emptyState:IsShown(),true)
 T.eq(p.emptyTitle:GetText(),"这里还没有记录")
 T.eq(p.emptyState:GetParent(),p.left,"the empty message shares the records content transition")
 T.eq(X(p.left),x,"rapid record-to-empty switching continues at the current visible position")
 T.eq(p.left:GetAlpha(),alpha,"record-to-empty switching retains the current fade")
 T.eq(Y(p.tabSelection),sideY,"rapid sidebar switching retains its visible position")
 local reveal,rect=m.jobIds[p.left],m.jobIds[m.rects[p.tabSelection]]
 p.tabs.caution:Fire("OnClick");p:RefreshList()
 T.eq(m.jobIds[p.left],reveal,"same-category and same-content refreshes do not restart the reveal")
 T.eq(m.jobIds[m.rects[p.tabSelection]],rect,"same-category refreshes do not restart sidebar movement")
 m:Tick(.2);T.eq(X(p.left),24);T.eq(p.left:GetAlpha(),1)
 p.tabs.neutral:Fire("OnClick")
 T.eq(X(p.left),-8,"backward note categories enter from the standard left offset")
 T.eq(p.list.ids[1],"MotionNeutral-Away");T.eq(p.emptyState:IsShown(),false)
 m:Tick(.2)
 local editorReveal=m.nextJobId
 p:OpenEdit("MotionNeutral-Away")
 T.eq(m.nextJobId,editorReveal,"refreshing the same selected record does not replay its editor")
 p.tabs.neutral:Fire("OnClick")
 T.eq(m.nextJobId,editorReveal,"reselecting the same category does not close and reopen its editor")
 p.tabs.history:Fire("OnClick")
 T.eq(p.historyFrame:IsShown(),true);T.eq(p.historyEmpty:IsShown(),true)
 T.eq(m.jobs[p.left],nil,"switching to history releases the hidden note transition")
 T.eq(m.jobs[p.editor],nil,"switching to history releases the hidden editor transition")
 T.ok(m.jobs[p.historyFrame],"history includes its heading, list and empty state in one reveal")
 m:Tick(.05);local historyJob=m.jobIds[p.historyFrame]
 p.tabs.history:Fire("OnClick")
 T.eq(m.jobIds[p.historyFrame],historyJob,"refreshing history does not replay its reveal")
 p.tabs.all:Fire("OnClick")
 T.eq(m.jobs[p.historyFrame],nil,"returning to records releases hidden history movement")
 T.eq(X(p.left),-8)
 u:Hide(true)
 T.eq(m:Count(),0,"hiding notes releases sidebar, list, history and editor motion")
 a:Open("notes");m:Tick(2)
 p.tabs.positive:Fire("OnClick");a:SetSetting("reduceMotion",true);u:SetReducedMotion(true)
 T.eq(m:Count(),0);T.eq(X(p.left),24);T.eq(p.left:GetAlpha(),1)
 u:Hide(true)
end

-- Exercise the actual routing, popup layout and selection entry points together.
do
 local f=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=f.A,f.U,f.G
 a:SetSetting("reduceMotion",false);a:SetSetting("showImportantFilters",true);a:Open("find");local m=u.Motion;m:Tick(2)
 local firstX=select(4,u.underline:GetPoint())
 u:Navigate("create")
 T.eq(select(4,u.pages.create.frame:GetPoint()),32,"forward navigation slides the entire page from the right")
 T.eq(select(4,u.underline:GetPoint()),firstX,"navigation input commits before the underline moves")
 m:Tick(.08);local middleX=select(4,u.underline:GetPoint())
 T.ok(middleX>firstX,"the underline passes through an intermediate horizontal position")
 u:Navigate("find")
 T.eq(select(4,u.pages.find.frame:GetPoint()),-32,"backward navigation slides the entire page from the left")
 T.eq(select(4,u.underline:GetPoint()),middleX,"a rapid navigation reversal keeps the current underline position")
 m:Tick(.2);T.eq(select(4,u.underline:GetPoint()),firstX)
 u:Navigate("notes");m:Tick(.2);u:Navigate("find");m:Tick(.2)
 local label=u.navItems.find.label;local stringWidth,naturalWidth=label.GetStringWidth,label.GetUnboundedStringWidth
 label.GetStringWidth=function(self) return naturalWidth(self)+40 end;label.GetUnboundedStringWidth=label.GetStringWidth
 u:ApplyFont(u.Theme.font);u:Navigate("create");m:Tick(.2)
 T.near(select(4,u.underline:GetPoint()),select(4,u.navItems.create:GetPoint())+34,.51,"font relayout updates the underline's destination with its navigation item")
 label.GetStringWidth,label.GetUnboundedStringWidth=stringWidth,naturalWidth;u:ApplyFont(u.Theme.font);u:Navigate("find");m:Tick(.2)

 local p=u.pages.find
 p:SelectCategory("seasonDungeon")
 T.ok(p.picker:GetAlpha()<1,"the secondary menu enters as one animated container")
 local opened=m.jobIds[p.picker]
 p:RefreshPicker()
 T.eq(m.jobIds[p.picker],opened,"refreshing the same popup geometry continues its entry animation")
 local point={p.activities:GetPoint()};local left=point[#point-1]
 T.eq(p.picker:GetWidth()-left-p.activities.rows[1]:GetWidth(),left,"a non-scrolling activity highlight has equal side padding")
 T.eq(p.activities.gutter,0)
 local groups=g.Catalog.GetGroups
 local source=groups(g.Catalog,"seasonDungeon")[1]
 local overflow={};for i=1,12 do overflow[i]={key=700+i,name="Overflow "..i,activity=source.activity,tier=source.tier} end
 g.Catalog.GetGroups=function() return overflow end
 p:RefreshPicker();T.eq(p.activities.gutter,u.C.listRightInset);T.eq(p.activities.slider:IsShown(),true)
 g.Catalog.GetGroups=groups;p:RefreshPicker()
 T.eq(p.activities.gutter,0,"shrinking the list removes the scrollbar reservation again")
 m:Tick(.2)
 local selection=p.difficultySelection
 local fromX=select(4,selection:GetPoint())
 for _,button in ipairs(p.difficultyButtons) do if button:IsShown() and not button.active then button:Fire("OnClick");break end end
 T.eq(select(4,selection:GetPoint()),fromX,"difficulty commits immediately while its shared background begins at the old position")
 m:Tick(.08);T.ok(select(4,selection:GetPoint())~=fromX,"difficulty has a visible intermediate selection position")
 p:SetFiltersOpen(true)
 T.ok(p.filterPanel:GetAlpha()<1 and select(4,p.filterPanel:GetPoint())>-20,"the internal filter overlay slides toward its final right inset")
 local role=p.quickChoices.tankPresence.button
 role:Fire("OnClick","RightButton");m:Tick(.2)
 role:Fire("OnClick","LeftButton");m:Tick(.07)
 T.ok(role.fill:IsShown() and role.fill:GetAlpha()>0 and role.fill:GetAlpha()<1,"quick role activation keeps finite tonal feedback")
 m:Tick(.2);T.eq(role.fill:GetAlpha(),1)
 role:Fire("OnClick","RightButton");m:Tick(.2);T.eq(role.fill:IsShown(),false,"clearing a quick role settles its tonal feedback")
 p.socialChoice:Fire("OnClick")
 local menu=u.context:GetMenu()
 T.ok(menu:IsShown() and menu:GetAlpha()<1,"ordinary dropdowns use the same finite reveal")
 u:CloseMenu();T.eq(m.placements[menu],nil,"closing a dropdown removes its pending placement")
 m:Tick(.2)
 p:SelectCategory("seasonRaid");m:Tick(.2);p:SelectCategory("seasonDungeon");m:Tick(.2)
 local nodes=#f.S.nodes
 for _=1,8 do
  u:Navigate("create");m:Tick(.2);u:Navigate("notes");m:Tick(.2);u:Navigate("find");m:Tick(.2)
  p:SelectCategory("seasonRaid");m:Tick(.2);p:SelectCategory("seasonDungeon");m:Tick(.2)
  p:SetFiltersOpen(true);p.socialChoice:Fire("OnClick");m:Tick(.2);u:CloseMenu();p:SetFiltersOpen(false);m:Tick(.2)
 end
 T.eq(#f.S.nodes,nodes,"warmed page, sidebar, popup and dropdown transitions reuse their native objects")
 T.eq(m:Count(),0,"settled UI transitions leave no frame driver")
 p:SelectCategory("seasonRaid");a:SetSetting("reduceMotion",true);u:SetReducedMotion(true)
 T.eq(m:Count(),0);T.eq(p.picker:GetAlpha(),1,"reduce motion settles an active secondary menu immediately")
 u:Hide(true);T.eq(m:Count(),0,"closing the host leaves no local motion jobs")
end

-- A visible consumer joins Notes when its real command first loads the service.
do
 local function LateNotes(pageName,settings,existing)
  local fresh=dofile("tests/ui_fixture.lua")("enUS",nil,settings)
  local a,u,g=fresh.A,fresh.U,fresh.G
  a:SetSetting("reduceMotion",true)
  local notes=a.Notes
  if existing then notes:Add("LateNote","Away","Existing before login") end
  a.Notes=nil
  local person={name="LateNote-Away",nameKey="LateNote-Away",class="MAGE",assignedRole="DAMAGER",isLeader=true}
  g.records[8101]={id=8101,name="Late note group",leaderName=person.name,leaderKey=person.nameKey,activity=g.Catalog:GetActivity(2),activityID=2,activityName="Dungeon",categoryID=2,maxNumPlayers=5,numMembers=1,charFriends=0,bnetFriends=0,guildMates=0,details={members={person},counts={TANK=0,HEALER=0,DAMAGER=1}}}
  if pageName=="create" then g.listing={activityID=2,name="Late note listing"};g.applicants[81]={id=81,status="applied",activityID=2,displayOrderID=1,members={person}} end
  a.charPrefs.find={category="seasonDungeon",filters={selected=true}}
  -- Keep the focused Group/UI providers, but exercise Core's actual Notes loader
  -- and Entrypoints' module-ready handoff and direct-recording command.
  local fixtureEnsure=a.Ensure
  dofile("addon/LycheeGroup/Core.lua")
  local coreEnsure=a.Ensure
  function a:Ensure(module) if module=="Notes" then return coreEnsure(self,module) end;return fixtureEnsure(self,module) end
  local loaded,load=C_AddOns.IsAddOnLoaded,C_AddOns.LoadAddOn
  local loads=0
  C_AddOns.IsAddOnLoaded=function(name) if name=="LycheeGroup_Notes" then return a.Notes~=nil,a.Notes~=nil end;return loaded(name) end
  C_AddOns.LoadAddOn=function(name) if name=="LycheeGroup_Notes" then loads=loads+1;a.Notes=notes;return true end;return load(name) end
  dofile("addon/LycheeGroup/Entrypoints.lua")
  a:Open(pageName)
  local page=u.pages[pageName];local row
  if pageName=="create" then row=page.batchPool[1].people[1]
  else for _,candidate in ipairs(page.results.rows) do if candidate.key==8101 then row=candidate;break end end end
  assert(row)
  return a,u,g,page,row,function() return loads end,notes
 end
 for _,pageName in ipairs({"find","create"}) do
  local a,u,g,page,row,loads,notes=LateNotes(pageName,{reminders="off"},true)
  T.eq(loads(),1,"opening "..pageName.." loads existing notes even with reminders off")
  T.eq(a.Notes,notes);T.ok(page.notesUnsub)
  T.eq(row.marks.flags.neutral,true,"the first displayed member retains its existing note marker")
  a:SetSetting("noteMarks",false)
  T.eq(u:GetNote("LateNote-Away").reason,"Existing before login","note details remain available when markers are hidden")
  T.eq(u:HasNote("LateNote-Away"),true,"existing records still open for viewing rather than creation")
  u:Hide(true)
 end
 for _,pageName in ipairs({"find","create"}) do
  local a,u,g,page,row,loads,notes=LateNotes(pageName,{notesEnabled=false,reminders="off"})
  T.eq(notes:Add("LateNote","Away","Existing before loading"),true)
  local changes,subscriptions=0,0
  local changed,subscribe=page.OnNotesChanged,notes.Subscribe
  function page:OnNotesChanged() changes=changes+1;return changed(self) end
  function notes:Subscribe(callback) subscriptions=subscriptions+1;return subscribe(self,callback) end
  a:SetSetting("notesEnabled",true)
  T.eq(loads(),1,"enabling cold Notes loads the service once")
  T.eq(changes,1,"cold enabling Notes refreshes the visible "..pageName.." consumer once")
  T.eq(subscriptions,1,"module readiness and setting notification share one Notes subscription")
  T.ok(page.notesUnsub);T.eq(row.marks.flags.neutral,true,"cold enabling reveals existing notes immediately")
  u:Hide(true);T.eq(page.notesUnsub,nil)
 end
 for _,pageName in ipairs({"find","create"}) do
  local a,u,g,page,row,loads=LateNotes(pageName)
  T.eq(a.Notes,nil,"opening "..pageName.." does not eagerly load Notes");T.eq(loads(),0)
  local changes=0;local changed=page.OnNotesChanged
  page.OnNotesChanged=function(self) changes=changes+1;return changed(self) end
  T.eq(a:RecordPlayer("LateNote","Away",nil,"First command note"),true)
  T.eq(loads(),1);T.ok(page.notesUnsub,"the first Notes load subscribes the visible "..pageName.." page")
  T.eq(row.marks.flags.neutral,true,"the first direct record updates the already visible member marker")
  local before=changes
  a:Ensure("Notes");T.eq(loads(),1);T.eq(changes,before,"an already-ready module does not repeat the handoff")
  a:SetSetting("notesEnabled",false)
  T.eq(page.notesUnsub,nil);T.eq(row.marks.flags.neutral,nil,"disabling notes removes visible markers immediately")
  before=changes;a:RecordPlayer("LateNote","Away",nil,"Recorded while disabled")
  T.eq(changes,before,"disabled automatic notes do not redraw the consumer")
  a:SetSetting("notesEnabled",true)
  T.ok(page.notesUnsub);T.eq(row.marks.flags.neutral,true,"reenabling notes restores the current record")
  a:SetSetting("defaultNote","caution");before=changes
  a:RecordPlayer("LateNote","Away",nil,"Changed after enabling")
  T.eq(changes,before+1,"reenabling installs exactly one Notes subscription")
  T.eq(row.marks.flags.caution,true);T.eq(row.marks.flags.neutral,nil)
  a:Open("settings");T.eq(page.notesUnsub,nil)
  before=changes;a:RecordPlayer("LateNote","Away",nil,"Recorded after leaving")
  T.eq(changes,before,"leaving releases the Notes consumer")
  u:Hide(true)
 end
 for _,pageName in ipairs({"find","create"}) do
  local a,u,g,page,row=LateNotes(pageName)
  a:SetSetting("reduceMotion",false);u.Motion:Tick(.5);u:Hide()
  local changes=0;local changed=page.OnNotesChanged
  page.OnNotesChanged=function(self) changes=changes+1;return changed(self) end
  a:RecordPlayer("LateNote","Away",nil,"Recorded during closing")
  T.eq(changes,0,"a first Notes load during exit does not redraw "..pageName)
  T.eq(page.notesUnsub,nil);u.Motion:Tick(.5)
  a:Open(pageName);T.ok(page.notesUnsub);T.eq(row.marks.flags.neutral,true,"reopening binds the note written while closing")
  u:Hide(true);T.eq(page.notesUnsub,nil)
 end
 for _,scenario in ipairs({"applications","applicants"}) do
  local fresh=dofile("tests/ui_fixture.lua")("enUS")
  local a,u=fresh.A,fresh.U;a:SetSetting("reduceMotion",true)
  dofile("addon/LycheeGroup/Entrypoints.lua")
  local subscriptions=0;local subscribe=a.Notes.Subscribe
  function a.Notes:Subscribe(callback) subscriptions=subscriptions+1;return subscribe(self,callback) end
  T.eq(a:Preview(scenario),true)
  T.eq(subscriptions,0,"preview never subscribes its page to real player notes")
  local page=u.pages[u.page];local changes=0;local changed=page.OnNotesChanged
  page.OnNotesChanged=function(self) changes=changes+1;return changed(self) end
  a:OnModuleReady("Notes");a:SetSetting("notesEnabled",false);a:SetSetting("notesEnabled",true)
  T.eq(subscriptions,0);T.eq(changes,0,"real Notes readiness and settings do not refresh the preview provider")
  u:Hide(true)
 end
end

-- A direct current-roster hover needs only the final player-detail reset.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local members={}
 for i=1,40 do members[i]={guid="Player-detail-"..i,name="Member"..i,nameKey="Member"..i.."-Away",class="WARRIOR",assignedRole="DAMAGER",isLeader=i==1} end
 function g:GetRoster() return members end
 g.listing={activityID=2,name="Current listing"};a:Open("create")
 local page,tip=u.pages.create,u.Tooltip;tip:ShowRoster(page.groupSummary,members);tip:Hide()
 local row=page.rosterList.rows[1];page.rosterList.clip.mouseOver=true;row.tooltipArea:Fire("OnEnter")
 local view=tip.interactive
 local title,summary,width,height=view.title:GetText(),view.summary:GetText(),view:GetWidth(),view:GetHeight()
 local metricPoint={view.metrics[1].title:GetPoint()};tip:Hide()
 local reset,setWidth=tip.ResetInteractive,view.SetWidth;local resets,hides,widths=0,0,{}
 local hide=view.memberButtons[1].Hide
 tip.ResetInteractive=function(self,...) resets=resets+1;return reset(self,...) end
 view.SetWidth=function(self,value) widths[#widths+1]=value;return setWidth(self,value) end
 for _,button in ipairs(view.memberButtons) do button.Hide=function(self) hides=hides+1;return hide(self) end end
 row.tooltipArea:Fire("OnEnter")
 T.eq(resets,1,"a current-member hover resets the detail surface once")
 T.eq(hides,40,"a player hover clears the forty-member warm pool only once")
 T.same(widths,{width},"a direct roster player goes straight to the measured final width")
 T.eq(view.title:GetText(),title);T.eq(view.summary:GetText(),summary);T.eq(view:GetWidth(),width);T.eq(view:GetHeight(),height)
 T.same({view.metrics[1].title:GetPoint()},metricPoint)
 T.eq(tip.owner,row);T.eq(tip.member,members[1]);T.eq(tip.pinned,false)
 local x,y=tip.pointX,tip.pointY
 tip:ShowPlayer(nil,members[1],row.memberContext)
 T.eq(tip.owner,row,"a nil owner retains the previously captured owner")
 T.eq(tip.pointX,x);T.eq(tip.pointY,y);T.eq(resets,2)
 tip.ResetInteractive,view.SetWidth=reset,setWidth
 for _,button in ipairs(view.memberButtons) do button.Hide=hide end
 u:Hide(true)
end

-- Editor labels reuse the class-matched metadata already needed by the record.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,pick=fresh.A,fresh.U,fresh.Pick;a:SetSetting("reduceMotion",true)
 a.Notes:Add("Label","Away","same reason",nil,"",{class="PALADIN",specID=66,type="neutral"})
 a:Open("notes",{playerKey="Label-Away"});local page=u.pages.notes
 local className,specName=page.classChoice.label:GetText(),page.specChoice.label:GetText()
 local getClass,getSpec=GetClassInfo,GetSpecializationInfoForClassID;local classes,specs=0,0
 GetClassInfo=function(...) classes=classes+1;return getClass(...) end
 GetSpecializationInfoForClassID=function(...) specs=specs+1;return getSpec(...) end
 for _=1,20 do page:OpenEdit("Label-Away") end
 GetClassInfo,GetSpecializationInfoForClassID=getClass,getSpec
 T.eq(classes,0,"reopening a known note does not rebuild the class menu for its selected label")
 T.eq(specs,0,"reopening a known note reuses its class-matched specialization label")
 T.eq(page.classChoice.label:GetText(),className);T.eq(page.specChoice.label:GetText(),specName)
 T.eq(page.eReason.box:GetText(),"same reason")
 pick(page.classChoice,"WARRIOR");T.eq(page.classChoice.label:GetText(),select(1,getClass(1)));T.eq(page.specChoice.label:GetText(),u.L.unknown)
 pick(page.specChoice,72);T.eq(page.specChoice.value,72);T.ok(page.specChoice.label:GetText()~=u.L.unknown)
 for _,identity in ipairs({{class="WARRIOR",specID=66},{class="PALADIN",specID=999999},{class="UNKNOWN",specID=66},{}}) do
  page:OpenAdd(identity);T.eq(page.specChoice.label:GetText(),u.L.unknown,"invalid, other-class and absent specializations remain unknown")
 end
 u:Hide(true)
end
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u=fresh.A,fresh.U;a:SetSetting("reduceMotion",true)
 local getClass,getSpec=GetClassInfo,GetSpecializationInfoForClassID
 -- Keep the token even if the class label is temporarily missing.
 GetClassInfo=function(index) local name,token,id=getClass(index);if token=="PALADIN" then name=nil end;return name,token,id end
 a:Open("notes",{add={class="PALADIN",specID=66}});local page=u.pages.notes
 T.eq(page.classChoice.label:GetText(),u.L.unknown);T.ok(page.specChoice.label:GetText()~=u.L.unknown,"a missing class label does not discard an available specialization label")
 GetClassInfo=getClass;page:OpenAdd({class="PALADIN",specID=66})
 T.eq(page.classChoice.label:GetText(),select(1,getClass(2)),"an incomplete class directory is retried")
 u:Hide(true)
 fresh=dofile("tests/ui_fixture.lua")("enUS");a,u=fresh.A,fresh.U;a:SetSetting("reduceMotion",true)
 getSpec=GetSpecializationInfoForClassID
 GetSpecializationInfoForClassID=function() return end
 a:Open("notes",{add={class="PALADIN",specID=70}});page=u.pages.notes
 T.eq(page.specChoice.label:GetText(),u.L.unknown)
 GetSpecializationInfoForClassID=getSpec;page:OpenAdd({class="PALADIN",specID=70})
 T.ok(page.specChoice.label:GetText()~=u.L.unknown,"a missing specialization is retried after recovery")
 u:Hide(true)
end

-- Rejected wheel movement applies its clamped position once, without a driver.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local member={name="Wheel",nameKey="Wheel-Away",class="WARRIOR",assignedRole="DAMAGER"}
 g.listing={activityID=2,name="Wheel listing"}
 g.applicants[1]={id=1,status="applied",displayOrderID=1,members={member}}
 a:Open("create");local page=u.pages.create;a:SetSetting("reduceMotion",false)
 local calls=0;local render=page.RenderBatches
 page.RenderBatches=function(self,...) calls=calls+1;return render(self,...) end
 page.batchScroll:Fire("OnMouseWheel",1)
 T.eq(u.Motion.jobs[page.batchScroll],nil,"a fitting applicant list does not animate a zero-distance wheel")
 for _=1,14 do u.Motion:Tick(.01) end
 T.eq(calls,1,"a fitting applicant wheel has no later render ticks")
 for id=2,20 do g.applicants[id]={id=id,status="applied",displayOrderID=id,members={member}} end
 page:RefreshApplicants();page:SetBatchOffset(0,false)
 page.batchScroll:Fire("OnMouseWheel",-1);T.ok(u.Motion.jobs[page.batchScroll])
 page.batchScroll:Fire("OnMouseWheel",1)
 T.eq(u.Motion.jobs[page.batchScroll],nil,"an immediate opposite wheel cancels movement back to the current position")
 T.eq(page.batchScrollTarget,nil);T.eq(page.batchScroll:GetVerticalScroll(),0)
 page.batchScroll:Fire("OnMouseWheel",-1);u.Motion:Tick(.2);T.eq(page.batchScroll:GetVerticalScroll(),56)
 page:SetBatchOffset(page.batchBody:GetHeight(),false);local bottom=page.batchScroll:GetVerticalScroll()
 page.batchScroll:Fire("OnMouseWheel",-1);T.eq(u.Motion.jobs[page.batchScroll],nil);T.eq(page.batchScroll:GetVerticalScroll(),bottom)
 page.RenderBatches=render
 u.Tooltip:ShowPlayer(page.batchPool[1].people[1],member,page.applicantContext)
 local view=u.Tooltip.interactive;view.scroll:Fire("OnMouseWheel",1)
 T.eq(u.Motion.jobs[view.scroll],nil,"a fitting player tooltip has no idle wheel animation")
 local members={};for i=1,40 do members[i]={name="Wheel"..i,nameKey="Wheel"..i.."-Away",class="WARRIOR",assignedRole="DAMAGER"} end
 u.Tooltip:ShowRoster(u.frame,members);view.scroll:Fire("OnMouseWheel",1)
 T.eq(u.Motion.jobs[view.scroll],nil,"the top of an overflowing tooltip does not animate outward")
 view.scroll:Fire("OnMouseWheel",-1);T.ok(u.Motion.jobs[view.scroll]);view.scroll:Fire("OnMouseWheel",1)
 T.eq(u.Motion.jobs[view.scroll],nil);T.eq(view.scroll.scrollTarget,nil)
 view.scroll:Fire("OnMouseWheel",-1);u.Motion:Tick(.2);T.eq(view.scroll:GetVerticalScroll(),42)
 local maximum=select(2,view.scrollbar:GetMinMaxValues());view.scrollbar:SetValue(maximum)
 view.scroll:Fire("OnMouseWheel",-1);T.eq(u.Motion.jobs[view.scroll],nil);T.eq(view.scroll:GetVerticalScroll(),maximum)
 u:Hide(true)
end

-- Native fields may be taken by another browser during synchronous layout.
for _,target in ipairs({"creationTitle","creationDescription","applicationDescription","search"}) do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local creation=target=="creationTitle" or target=="creationDescription"
 if not creation then a:Open("find") end
 local page=u.pages[creation and "create" or "find"]
 if target=="search" then u.Native:ReleaseSearch() end
 local region=target=="creationTitle" and LFGListFrame.EntryCreation.Name
  or target=="creationDescription" and LFGListFrame.EntryCreation.Description
  or target=="applicationDescription" and LFGListApplicationDialog.Description
  or LFGListFrame.SearchPanel.SearchBox
 local originalParent,originalScript=region:GetParent(),region:GetScript("OnSizeChanged")
 local inputs=#u.inputs
 local foreign=CreateFrame("Frame",nil,UIParent)
 region:SetScript("OnSizeChanged",function(self) self:SetParent(foreign) end)
 local ok,err
 if creation then
  a:Open("create");ok=u.Native.owner~=nil;err=page.formError:GetText()
  T.eq(page.publish:IsEnabled(),false,"opening a form with failed native acquisition keeps Publish disabled")
  T.ok(page.formNotice:IsShown(),"the full page-entry path preserves the acquisition failure notice")
 elseif target=="applicationDescription" then ok,err=u.Application:OpenApplicationSettings(nil,true)
 else ok,err=u.Native:AcquireSearch(page,page.search) end
 T.eq(ok,false,target.." reports acquisition failure instead of publishing an inactive lease")
 T.eq(err,u.L.unavailable);T.eq(region:GetParent(),foreign,"failed acquisition preserves the new browser's parent")
 if not creation then T.eq(#u.inputs,inputs,"failed acquisition leaves no borrowed input registration") end
 inputs=#u.inputs
 for lease in pairs(u.context.nativeControls) do T.ok(lease:IsOwned(),"remaining native registrations still own their controls") end
 if creation then
  T.eq(u.Native.owner,nil);T.eq(u.Native.titleInput,nil);T.eq(u.Native.descriptionInput,nil)
 elseif target=="applicationDescription" then
  T.eq(u.Application.applicationLease,nil);T.eq(u.Application.previewApplication,nil)
  T.eq(u.activeModal,nil,"failed application acquisition closes its temporary modal")
 else T.eq(u.Native.searchLease,nil);T.eq(g.Search.inputLease,nil,"search never binds a failed native lease") end
 region:SetScript("OnSizeChanged",originalScript);region:SetParent(originalParent)
 if creation then
  ok,err=a:Open("create");T.eq(u.Native.owner,page);T.ok(u.Native.titleInput:IsOwned() and u.Native.descriptionInput:IsOwned())
  T.eq(#u.inputs,inputs+2);T.eq(page.publish:IsEnabled(),true);T.eq(page.formNotice:IsShown(),false,"a successful page-entry retry clears the unavailable notice")
 elseif target=="applicationDescription" then ok,err=u.Application:OpenApplicationSettings(nil,true);T.ok(u.Application.applicationLease.description:IsOwned())
 else ok,err=page:EnsureSearchInput();T.ok(u.Native.searchLease:IsOwned());T.eq(g.Search.inputLease,u.Native.searchLease) end
 T.eq(ok,true,target.." can be retried after the foreign browser returns the field")
 u:Hide(true)
 T.eq(next(u.context.nativeControls),nil,"closing after recovery releases all native controls")
end

-- Entering the creation page binds the current roster only after mode setup.
do
 local f=dofile("tests/ui_fixture.lua")("enUS");local a,u,g=f.A,f.U,f.G
 a:SetSetting("reduceMotion",true)
 local members={}
 for i=1,5 do members[i]={name="P"..i,nameKey="P"..i.."-Home",class="WARRIOR",assignedRole="DAMAGER"} end
 g.GetRoster=function() return members end
 local original,bindings=u.Members.BindRoster,0
 u.Members.BindRoster=function(self,...) bindings=bindings+1;return original(self,...) end
 a:Open("create")
 local page=u.pages.create
 T.eq(bindings,5,"first entry binds each current member once")
 T.eq(page.rosterCount:GetText(),"5 members");T.eq(page.roster,members)
 local height,error=page.rosterList.body:GetHeight(),page.formError:GetText()
 u:Navigate("settings");bindings=0;u:Navigate("create")
 T.eq(bindings,5,"re-entry binds each current member once")
 T.eq(page.rosterCount:GetText(),"5 members");T.eq(page.roster,members)
 T.eq(page.rosterList.body:GetHeight(),height);T.eq(page.formError:GetText(),error)
 u:Hide(true)
end

-- Same-spec preferences follow their category; every font size keeps the entire
-- seasonal filter panel inside the main window with separated controls.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale);local a,u,g=f.A,f.U,f.G
 a:SetSetting("reduceMotion",true);a:SetSetting("showImportantFilters",true)
 local name=locale=="zhCN" and "邪恶" or "Unholy"
 C_SpecializationInfo.GetSpecialization=function() return 3 end
 C_SpecializationInfo.GetSpecializationInfo=function() return 252,name,nil,135775 end
 g.prefs.find={category="seasonDungeon",filters={hideSameSpec=true}}
 a:Open("find");local page=u.pages.find;page:SetFiltersOpen(true)
 T.eq(page.quickIdentity.active,true);T.eq(g.filters.hideSameSpec,true);T.eq(page.filterCount,1)
 T.eq(page.sameSpecHint,nil,"the filter has no current-spec hint line")
 page:SelectCategory("seasonRaid")
 T.eq(page.quickFilters:IsShown(),false);T.eq(g.filters.hideSameSpec,nil)
 page:SelectCategory("seasonDungeon")
 T.eq(page.quickIdentity.active,true);T.eq(g.filters.hideSameSpec,true,"returning restores the seasonal specialization preference")
 page:ClearFilters();T.eq(page.quickIdentity.active,false,"Any uses the same idle state as unrestricted role filters");T.eq(g.filters.hideSameSpec,nil);T.eq(page.filterCount,0)
 page.quickIdentity:Fire("OnClick","LeftButton");page.quickIdentity:Fire("OnClick","LeftButton");page.quickIdentity:Fire("OnClick","LeftButton");T.eq(g.prefs.find.categoryPrefs.seasonDungeon.hideSameSpec,true)
 page.quickChoices.tankPresence.button:Fire("OnClick","LeftButton")
 page.quickChoices.tankPresence.button:Fire("OnClick","RightButton")
 T.eq(g.filters.tankPresence,nil);T.eq(page.quickChoices.tankPresence.button.active,false,"right click explicitly clears one role")
 local function Top(frame) local point={frame:GetPoint()};return -point[#point] end
 for _,scale in ipairs({70,100,130}) do
  a:SetSetting("fontScale",scale)
  T.ok(76+page.filterPanel:GetHeight()<=u.frame:GetHeight(),locale.." internal filter panel fits below its top inset at "..scale.." percent")
  T.eq(Top(page.fMembers),Top(page.fMinMembers),"member range endpoints stay in one row")
  local membersRange,itemLevelRange=page.fMembers:GetParent(),page.filterFields.maxItemLevel:GetParent()
  T.ok(Top(membersRange)>=Top(itemLevelRange)+itemLevelRange:GetHeight()+12,"member bounds stay below the item-level range")
  T.ok(Top(page.hideZeroScore)>=Top(membersRange),"the score switch shares or follows the members range row")
  T.ok(Top(page.socialChoice)>=Top(page.hideZeroScore)+page.hideZeroScore:GetHeight()+6,"relations start after the numeric group")
  T.ok(Top(page.filterFooter)+Top(page.filterDone)+page.filterDone:GetHeight()<=page.filterPanel:GetHeight()-20,"the completion action retains bottom padding")
  for _,choice in pairs(page.quickChoices) do
   T.ok(choice.button.label:GetStringWidth()+42<=choice.button:GetWidth(),"quick role text and icon fit the selected font size")
  end
 end
 page:ClearFilters();page:SelectCategory("seasonRaid");page:SelectCategory("seasonDungeon")
 T.eq(g.filters.hideSameSpec,nil,"cleared specialization preferences do not return")
 u:Hide(true)
end

-- The category rail changes geometry only; filters, search and row bindings survive.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS",{rememberFilters=false,find={railCollapsed=true}})
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 a:Open("find");local page=u.pages.find
 T.eq(page.rail:GetWidth(),48,"interface preferences restore even when filter memory is off")
 T.eq(page.sidebarToggle:GetWidth(),40);T.eq(page.sidebarToggle:GetHeight(),40)
 T.eq(page.main:GetWidth(),u.content:GetWidth()-48-u.Theme.contentGap-u.Theme.findContentInset*2);T.eq(page.sidebarToggle.label:IsShown(),false)
 for _,list in ipairs({page.seasonCategories,page.categories}) do
  for _,row in ipairs(list.rows) do T.eq(row.title:IsShown(),false);T.eq(row.chevron:IsShown(),false) end
 end
 page:UpdateFilters();T.eq(g.prefs.find.railCollapsed,true,"saving filters preserves the interface preference")
 page.sidebarToggle:Fire("OnClick");T.eq(page.rail:GetWidth(),208);T.eq(page.sidebarToggle:GetWidth(),192)
 T.eq(page.main:GetWidth(),u.content:GetWidth()-208-u.Theme.contentGap-u.Theme.findContentInset*2);T.eq(page.sidebarToggle.label:IsShown(),true)
 page:SelectCategory("seasonDungeon")
 local point={page.picker:GetPoint()};T.eq(point[2],page.rail);T.eq(point[3],"TOPRIGHT","the activity picker follows the animated rail edge")
 page:ClosePicker();u.Motion:Tick(1)
 local results,details,search,items=g.GetResults,g.Results.GetDetails,g.Search.Search,page.results.SetItems
 local reads,bindings,searches=0,0,0
 g.GetResults=function(self,...) reads=reads+1;return results(self,...) end
 g.Results.GetDetails=function(self,...) reads=reads+1;return details(self,...) end
 g.Search.Search=function(self,...) searches=searches+1;return search(self,...) end
 page.results.SetItems=function(self,...) bindings=bindings+1;return items(self,...) end
 -- The shared animation driver is lazy and is not a sidebar control.
 u.Motion:Start("rail-test",function() return true end);u.Motion:Stop("rail-test")
 local nodes=#fresh.S.nodes;local originalRow=page.results.rows[1]
 a:SetSetting("reduceMotion",false);page.sidebarToggle:Fire("OnClick");u.Motion:Tick(.06)
 T.eq(page.sidebarToggle.label:GetText(),"Collapse","collapsing fades the current caption without flashing Expand")
 local middle=page.rail:GetWidth();T.ok(middle>48 and middle<208,"the rail interpolates its width")
 page.sidebarToggle:Fire("OnClick");T.eq(page.rail:GetWidth(),middle,"reversing starts at the current geometry")
 u.Motion:Tick(.03);T.ok(page.rail:GetWidth()>middle,"the same animation reverses continuously")
 page.sidebarToggle:Fire("OnClick");u.Motion:Tick(.2)
 T.eq(page.rail:GetWidth(),48);T.eq(u.Motion.jobs[u.Motion.rects[page.rail]],nil)
 T.eq(reads,0);T.eq(bindings,0);T.eq(searches,0,"rail animation does not submit a search")
 T.eq(#fresh.S.nodes,nodes,"rail animation reuses existing controls");T.eq(page.results.rows[1],originalRow)
 g.GetResults,g.Results.GetDetails,g.Search.Search,page.results.SetItems=results,details,search,items
 page.sidebarToggle:Fire("OnClick");u.Motion:Tick(.03);a:SetSetting("reduceMotion",true)
 T.eq(page.rail:GetWidth(),208);T.eq(u.Motion.jobs[u.Motion.rects[page.rail]],nil,"reduced motion settles the active rail")
 a:SetSetting("reduceMotion",false);page.sidebarToggle:Fire("OnClick");u.Motion:Tick(.03);u:Navigate("settings")
 T.eq(page.rail:GetWidth(),48);T.eq(u.Motion.jobs[u.Motion.rects[page.rail]],nil,"leaving settles the rail")
 u:Navigate("find");T.eq(page.rail:GetWidth(),48)
 page.sidebarToggle:Fire("OnClick");u.Motion:Tick(.03);u:Hide()
 T.eq(page.rail:GetWidth(),208);T.eq(u.Motion.jobs[u.Motion.rects[page.rail]],nil,"closing settles before the window fade completes")
 u:Hide(true);a:SetSetting("reduceMotion",true);a:Open("find");page:SetSidebarCollapsed(true,false)
 dofile("addon/LycheeGroup/Entrypoints.lua");T.eq(a:Preview("applications"),true)
 T.eq(page.rail:GetWidth(),208,"preview starts with its independent interface preference")
 local provider=u.preview.provider;page:SetSidebarCollapsed(true,false);page:UpdateFilters()
 T.eq(provider.prefs.find.railCollapsed,true);T.eq(g.prefs.find.railCollapsed,true)
 page:SetSidebarCollapsed(false,false);u:StopPreview(true)
 T.eq(page.rail:GetWidth(),48,"returning from preview restores the real rail preference")
 T.eq(g.prefs.find.railCollapsed,true);u:Hide(true)
end

-- Native PvP category identities use distinct color assets and shared icon states.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN");local a,u,g=fresh.A,fresh.U,fresh.G
 local available=C_LFGList.GetAvailableCategories
 C_LFGList.GetAvailableCategories=function() return {4,7,8,9} end
 g.Catalog:Invalidate();a:SetSetting("reduceMotion",true);a:Open("find")
 local page=u.pages.find;local expected={[4]="arena",[7]="skirmish",[8]="battleground",[9]="rated-battleground"};local textures={}
 for _,row in ipairs(page.categories.rows) do
  local suffix=expected[tonumber(row.key)]
  if suffix then
   T.eq(row.symbol:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\pvp-"..suffix..".tga")
   T.eq(textures[row.symbol:GetTexture()],nil);textures[row.symbol:GetTexture()]=true
   T.eq(row.symbol:IsDesaturated(),true);T.eq(row.symbol:GetAlpha(),.72)
   page.categories:Select(row.key,true)
   T.eq(row.symbol:IsDesaturated(),false);T.eq(row.symbol:GetAlpha(),1)
   page.categories:Select(nil,true)
   T.eq(row.symbol:IsDesaturated(),true);T.eq(row.symbol:GetAlpha(),.72)
  end
 end
 T.eq(fresh.Count(textures),4,"all four native PvP categories bind distinct assets")
 C_LFGList.GetAvailableCategories=available;u:Hide(true)
end

-- Relationship marks stay beside the leader name across data and geometry refreshes.
do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN",{find={category="seasonDungeon",railCollapsed=true,categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}});local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local record={id=1,activityID=2,activity=g.Catalog:GetActivity(2),activityName="Dungeon",categoryID=2,name="21/22",leaderName="Player-Home",numMembers=2,maxNumPlayers=5,age=10,bnetFriends=1}
 g.records[1]=record;a:Open("find");g:Notify("results")
 local page=u.pages.find;local row=page.results.rows[1];local width=row.leader:GetWidth()
 T.ok(row.marks.icons.bnet:IsShown())
 local point={row.marks:GetPoint()};T.eq(point[2],row.leader);T.eq(point[3],"RIGHT");T.eq(point[4],6)
 for i=1,3 do
  page:LayoutSize(u.content:GetWidth(),u.content:GetHeight())
  T.eq(row.leader:GetWidth(),width,"same-size layout must not move the Battle.net mark")
  g:Notify("relations")
  T.eq(row.leader:GetWidth(),width,"relationship refresh must preserve the same mark position")
  page:SetSidebarCollapsed(i%2==1,false)
  T.eq(row.leader:GetWidth(),width,"short leader names keep their marks while the sidebar changes")
 end
 u:SetWindowSize(1400,900)
 a:SetSetting("fontScale",130)
 T.eq(row.leader:GetWidth(),math.ceil(row.leader:GetUnboundedStringWidth())+2,"font changes remeasure the leader name without waiting for new data")
 record.leaderName=string.rep("LongLeader",8).."-Home";record.charFriends=1;record.guildMates=1;g:Notify("relations")
 u:SetWindowSize(1,1)
 width=row.leader:GetWidth()
 T.eq(width+6+row.marks:GetWidth(),page.resultsHeader.columns.leader.width-8,"long names reserve space for every relationship mark at the minimum window width")
 T.eq(row.meta:GetWidth(),page.resultsHeader.columns.activity.width-38,"relationship marks leave the activity text width intact")
 g:Notify("results");T.eq(row.leader:GetWidth(),width,"data refresh preserves the compact column layout")
 page:LayoutResultColumns();T.eq(row.leader:GetWidth(),width,"column layout preserves the same truncation boundary")
 record.bnetFriends,record.charFriends,record.guildMates=0,0,0;g:Notify("relations")
 T.eq(row.marks:IsShown(),false);T.eq(row.leader:GetWidth(),page.resultsHeader.columns.leader.width-8,"removing the final mark restores the complete leader text width")
 u:Hide(true)
end

-- The settings button toggles back to the actual business page that opened it.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 for _,page in ipairs({"find","create","notes"}) do
  -- Make the ordinary entry default disagree with the visible source page.
  g.listing=page=="find" and {name="Active listing",activityID=2,comment=""} or nil
  a:Open(page);u.settingsButton:Fire("OnClick","LeftButton")
  T.eq(u.page,"settings");T.eq(u.settingsReturnPage,page,"settings remembers the actual source page")
  a:Open("settings",{section="interface"});a:Open("settings",{section="general"})
  T.eq(u.settingsReturnPage,page,"reentering settings preserves its source")
  u.settingsButton:Fire("OnClick","LeftButton")
  T.eq(u.page,page,"a second settings click returns to the saved page instead of the ordinary entry default")
  u.settingsButton:Fire("OnClick","LeftButton");u:Hide(true);a:Open("settings")
  T.eq(u.settingsReturnPage,page,"closing and reopening settings keeps its original source")
  u.settingsButton:Fire("OnClick","LeftButton");T.eq(u.page,page)
 end
 a:Open("notes");a:Open("settings");u.navItems.create:Fire("OnClick","LeftButton")
 u.settingsButton:Fire("OnClick","LeftButton")
 T.eq(u.settingsReturnPage,"create","entering from a different business page updates the source")
 u.settingsButton:Fire("OnClick","LeftButton");T.eq(u.page,"create")
 u:Hide(true)
 local cold=dofile("tests/ui_fixture.lua")(locale)
 cold.A:SetSetting("reduceMotion",true);cold.A:Open("settings")
 T.eq(cold.U.settingsReturnPage,nil,"a cold settings entry does not invent a source")
 cold.U.settingsButton:Fire("OnClick","LeftButton");T.eq(cold.U.page,"find","a cold settings entry can return through the ordinary default")
 cold.U:Hide(true)
end

-- The default product typography remains the main-line visual baseline.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u=fresh.A,fresh.U
 a:SetSetting("reduceMotion",true);a:Open("find")
 T.eq(select(2,u.brandTitle:GetFont()),23,"brand typography matches the released main-line default")
 T.eq(select(2,u.navItems.find.label:GetFont()),17,"top navigation keeps its main-line default")
 a:Open("notes")
 T.eq(select(2,u.pages.notes.list.rows[1].title:GetFont()),21,"note names retain the main-line list title")
 a:SetSetting("fontScale",130)
 T.near(select(2,u.brandTitle:GetFont()),23*1.3,.001,"the user font setting still updates built text immediately")
 a:SetSetting("fontScale",100)
 T.eq(select(2,u.brandTitle:GetFont()),23,"font changes recalculate from the base instead of accumulating")
 u:Hide(true)
end

-- Live appearance changes must not revive a hidden application's display clock.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true)
 local clock,now=GetTime,0;GetTime=function() return now end
 local result={id=42,name="Active application",activityID=2,activity=g.Catalog:GetActivity(2),activityName="Dungeon",categoryID=2,maxNumPlayers=5,numMembers=1,leaderName="Leader-Home",details={members={{name="Leader",nameKey="Leader-Home",class="WARRIOR",assignedRole="TANK"}},counts={TANK=1,HEALER=0,DAMAGER=0}}}
 local application={id=42,name=result.name,status="applied",expiresAt=GetTime()+300,categoryID=2,result=result}
 g.records[42]=result;g.apps={application}
 a:Open("find")
 local page=u.pages.find
 T.same(page.appList.ids,{42});T.ok(page.countdown)
 a:Open("settings",{section="interface"})
 T.eq(page.frame:IsVisible(),false);T.eq(page.countdown,nil);T.eq(page.appList.ids,nil)
 local reads,getApplications=0,g.GetApplications
 g.GetApplications=function(self) reads=reads+1;return getApplications(self) end
 a:SetSetting("fontScale",110);a:SetSetting("font","game")
 a:SetSetting("memberIconScale",125)
 T.eq(reads,0,"changing appearance in Settings does not fetch hidden application rows")
 T.eq(page.countdown,nil,"a hidden Find page has no display clock after a font change")
 T.eq(page.appList.ids,nil,"appearance changes preserve the released hidden bindings")
 u:Hide(true)
 a:SetSetting("fontScale",100);a:SetSetting("font","default")
 T.eq(reads,0,"font changes while closed do not fetch application rows")
 T.eq(page.countdown,nil);T.eq(page.appList.ids,nil)
 T.eq(g.apps[1],application);T.eq(application.status,"applied");T.eq(g.cancelled,nil)
 a:Open("find")
 T.same(page.appList.ids,{42});T.ok(page.countdown,"returning to Find restores the real application's clock")
 now=1;fresh.base.AdvanceClock(1)
 for _,row in ipairs(page.appList.rows) do if row.key==42 then T.eq(row.status:GetText(),"4:59") end end
 T.eq(g.Applications:GetActiveCount(),1);T.eq(g.cancelled,nil)
 a:SetSetting("reduceMotion",false);u.Motion:Tick(.5)
 now=1.8;fresh.base.AdvanceClock(.8)
 u:Hide();u.Motion:Tick(.1)
 T.eq(u.hiding,true)
 now=2;fresh.base.AdvanceClock(.2)
 for _,row in ipairs(page.appList.rows) do if row.key==42 then T.eq(row.status:GetText(),"4:59","closing freezes the displayed countdown") end end
 T.eq(page.countdown,nil,"a clock callback during exit cancels its ticker")
 a:Open("find")
 T.eq(u.hiding,nil);T.ok(page.countdown,"quickly reopening restores the current application's ticker")
 for _,row in ipairs(page.appList.rows) do if row.key==42 then T.eq(row.status:GetText(),"4:58") end end
 now=3;fresh.base.AdvanceClock(1)
 for _,row in ipairs(page.appList.rows) do if row.key==42 then T.eq(row.status:GetText(),"4:57") end end
 u:Hide(true);T.eq(page.countdown,nil);GetTime=clock
end

-- Closing freezes Find notifications even after the native host retakes its input.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=false})
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:Open("find");u.Motion:SetPresence(1)
 local page=u.pages.find;local count=#page.catIDs
 u:Hide();T.ok(u.hiding)
 local box=LFGListFrame.SearchPanel.SearchBox
 box:SetParent(LFGListFrame.SearchPanel);box:Fire("OnTextChanged",false)
 T.eq(u.Native.searchLease,nil)
 local categories=g.Catalog.GetCategories
 g.Catalog.GetCategories=function(self,...)
  local result={};for i,category in ipairs(categories(self,...)) do result[i]=category end
  result[#result+1]={key="closingCategory",id=87,name="Latest category",icon="pvp"};return result
 end
 local changes=0
 for _,method in ipairs({"RefreshCategories","OnApplicationCancelled","RefreshResults","RefreshSearchState"}) do
  local original=page[method]
  page[method]=function(self,...) changes=changes+1;return original(self,...) end
 end
 for _,kind in ipairs({"activities","applicationCancelled","result","relations","search","results","applications"}) do g:Notify(kind,41) end
 T.eq(changes,0,"business updates leave the departing Find page frozen")
 T.eq(u.Native.searchLease,nil,"an activity event cannot reacquire an input returned to its native host")
 T.eq(box:GetParent(),LFGListFrame.SearchPanel);T.eq(#page.catIDs,count)
 a:Open("find")
 T.eq(u.hiding,nil);T.ok(u.Native.searchLease)
 T.eq(box:GetParent(),page.search);T.ok(page.catMap.closingCategory)
 T.eq(#page.catIDs,count+1,"quick reopen synchronizes the latest activity directory")
 u:Hide(true);T.eq(page.unsub,nil);T.eq(u.Native.searchLease,nil)
end

-- External note changes freeze during exit and are consumed on a quick reopen.
for _,removed in ipairs({false,true}) do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u=fresh.A,fresh.U
 a:SetSetting("reduceMotion",false)
 a.Notes:Add("ClosingEdit","Away","Original reason")
 a:Open("notes",{playerKey="ClosingEdit-Away"});u.Motion:Tick(1)
 local page=u.pages.notes;local count=#page.list.ids
 u:Hide();T.ok(u.hiding)
 if removed then a.Notes:Remove("ClosingEdit-Away") else a.Notes:Edit("ClosingEdit-Away","External change") end
 a.Notes:Add("AddedDuringExit","Away","New record")
 T.eq(page.eReason.box:GetText(),"Original reason","external changes leave the departing editor frozen")
 T.eq(#page.list.ids,count,"external changes leave the departing list frozen")
 a:Open("notes")
 if removed then T.eq(page.eStatus:GetText(),u.L.missingRecord);T.eq(page.eSave:IsShown(),false,"a removed record cannot remain editable after reopening")
 else T.eq(page.eReason.box:GetText(),"External change","reopening synchronizes the edited record") end
 T.eq(#page.list.ids,count+(removed and 0 or 1),"reopening reads the current record list")
 u:Hide(true)
end

-- Closing cancels the editor's inspect request; a quick reopen keeps a saveable draft.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,base=fresh.A,fresh.U,fresh.base
 a:SetSetting("reduceMotion",false)
 base.SetUnit("party1",{name="ClosingNote",realm="Away",class="PALADIN",classID=2,guid="closing-note"})
 base.SetInspectSpec("party1",0)
 a:Open("notes",{add={name="ClosingNote",realm="Away",unit="party1"}});u.Motion:Tick(1)
 local page=u.pages.notes
 page.eReason.box:SetText("Keep this draft");page:Save()
 T.eq(base.PendingTimers(),1);T.eq(page.eStatus:GetText(),u.L.busy)
 u:Hide();T.ok(u.hiding)
 T.eq(base.PendingTimers(),0,"closing immediately releases the editor's pending inspection")
 base.SetInspectSpec("party1",66);base.FireEvent("INSPECT_READY","closing-note")
 T.eq(a.Notes:Find("ClosingNote-Away"),nil,"a late inspection cannot save a closed draft")
 a:Open("notes")
 T.eq(page.eReason.box:GetText(),"Keep this draft");T.eq(page.eStatus:GetText(),"")
 page:Save()
 local record=a.Notes:Find("ClosingNote-Away")
 T.ok(record,"a quickly reopened draft can be saved again without editing a field")
 T.eq(record.reason,"Keep this draft");T.eq(record.specID,66)
 u:Hide(true)
end

-- Business events do not rebuild the departing creation page or reacquire inputs.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",false)
 g.listing={activityID=2,name="Closing recruitment",requiredItemLevel=0}
 a:Open("create");u.Motion:Tick(1)
 local page=u.pages.create
 T.ok(page.manage:IsShown());T.eq(page.formFrame:IsShown(),false)
 local roster=page.roster;local rosterText=page.rosterCount:GetText()
 local acquisitions,acquire=0,u.Native.AcquireCreation
 u.Native.AcquireCreation=function(self,...) acquisitions=acquisitions+1;return acquire(self,...) end
 u:Hide();T.ok(u.hiding);T.ok(u.frame:IsShown());T.eq(u.Native.owner,nil)
 g.listing=nil;g.GetRoster=function() return {} end
 for _,kind in ipairs({"listing","permissions","roster","activities","creationPresets","applicants"}) do g:Notify(kind) end
 T.eq(acquisitions,0,"events during exit cannot reacquire the returned native creation inputs")
 T.eq(page.manage:IsShown(),true,"the departing page keeps its last recruitment view")
 T.eq(page.formFrame:IsShown(),false);T.eq(page.roster,roster);T.eq(page.rosterCount:GetText(),rosterText)
 a:Open("create")
 T.eq(u.hiding,nil);T.eq(page.formFrame:IsShown(),true);T.eq(page.manage:IsShown(),false)
 T.eq(u.Native.owner,page,"reversing the exit acquires the current form normally")
 T.eq(#page.roster,0,"reopening takes the latest roster after skipped presentation updates")
 u:Hide(true);T.eq(page.unsub,nil);T.eq(u.Native.owner,nil)
end

-- A table-header repaint can precede the queued notice for in-place members.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 local function Member(name) return {name=name,nameKey=name,class="MAGE",assignedRole="DAMAGER",itemLevel=320,dungeonScore=2500} end
 g.listing={activityID=2,name="Changing recruitment"}
 for id=1,20 do g.applicants[id]={id=id,status="applied",displayOrderID=id,members={Member("Member"..id.."-Away")}} end
 a:Open("create");local page=u.pages.create;local app=g.applicants[1]
 local function Header()
  local ok,err=pcall(page.applicantTable.Layout,page.applicantTable,page.applicantTable.layoutWidth)
  T.ok(ok,"the real table-header callback accepts pending member changes: "..tostring(err))
 end
 local function Geometry()
  for _,batch in ipairs(page.batchPool) do if batch:IsShown() then
   local current=g.applicants[batch.appID];local layout=page.batchLayouts[batch.appID]
   T.eq(#layout.heights,#current.members,"member geometry covers the current complete batch")
   for index,row in ipairs(batch.people) do
    local member=current.members[index]
    T.eq(row:IsShown(),member~=nil)
    if member then
     T.eq(row.member,member);T.eq(row.title:GetText(),member.nameKey)
     T.eq(row:GetHeight(),layout.heights[index]);T.ok(row:GetHeight()>=math.ceil(row.title:GetStringHeight()),"current names fit the rebuilt member height")
     if index>1 then T.ok(layout.tops[index]>=layout.tops[index-1]+layout.heights[index-1],"member rows never overlap after in-place changes") end
    end
   end
  end end
 end
 app.members[2]=Member("Two-Away")
 Header();Geometry();T.eq(page.batchPool[1].people[2].member,app.members[2])
 local oldHeight=page.batchLayouts[1].heights[1]
 app.members[1].nameKey=string.rep("LongApplicant",12).."-Away";app.members[1].name=app.members[1].nameKey
 app.comment=string.rep("The current complete recruitment note. ",15)
 Header();Geometry();T.ok(page.batchLayouts[1].heights[1]>oldHeight,"same-count native name changes invalidate wrapped height")
 T.eq(page.batchPool[1].comment:GetText(),app.comment,"a pre-notification repaint includes the current long note")
 app.members[1],app.members[2]=app.members[2],app.members[1]
 page:SetBatchOffset(1,false);Geometry();T.eq(page.batchPool[1].people[1].member,app.members[1],"scrolling within the same bound interval accepts current member ordering")
 local tall=page.batchLayouts[1].heights[2]
 app.members[2].isBNetFriend,app.members[2].isCharFriend,app.members[2].isGuildMate=true,true,true
 page:SetBatchOffset(2,false);Geometry()
 T.ok(page.batchLayouts[1].heights[2]>tall,"in-place relationship marks invalidate the available wrapped-name width")
 Header();Geometry()
 table.remove(app.members,2)
 Header();Geometry();T.eq(page.batchPool[1].people[2]:IsShown(),false,"a pending member removal hides the old pooled slot")
 g.applicants[20].members[2]=Member(string.rep("LastApplicant",10).."-Away")
 page:SetBatchOffset(page.batchBody:GetHeight(),false);Geometry()
 local last=page.batchPool[page.lastBatch-page.firstBatch+1]
 T.eq(last.appID,20);T.eq(last.people[2].member,g.applicants[20].members[2],"scrolling into pending data rebuilds its geometry before binding")
 page:SetBatchOffset(0,false)
 local measure=page.applicantMeasure.text;local getHeight=measure.GetStringHeight;local measurements=0
 measure.GetStringHeight=function(self,...) measurements=measurements+1;return getHeight(self,...) end
 Header();page:SetBatchOffset(1,false);Header()
 T.eq(measurements,0,"unchanged header layout and scrolling do not remeasure applicant names")
 g:Notify("applicants");Geometry();T.eq(page.batchPool[1].people[1].member,app.members[1],"the final queued notification remains consistent with the earlier repaint")
 measure.GetStringHeight=getHeight
 u:Hide(true)
end

-- Member-count and faction child actions also reject an earlier row's press.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 g.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8}}}
 for id=1,25 do g.records[id]={id=id,activityID=1,name="Raid "..id,leaderName="Leader-Away",leaderKey="Leader-Away",numMembers=10,maxNumPlayers=40,age=10} end
 a:Open("find");local page=u.pages.find;local row=page.results.rows[1];local button=row.membersButton;local old=row.key
 button:Fire("OnMouseDown","LeftButton");page.results:SetPixelOffset(page.results.rowHeight,false)
 T.ok(row.key~=old);button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(row.membersExpanded,nil,"releasing a rebound member-count button cannot expand the new result")
 button:Fire("OnClick","LeftButton");T.eq(row.membersExpanded,true,"direct activation expands the current result")
 u:Hide(true)
end
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 g.listing={activityID=2,name="Faction actions"}
 for id=1,20 do g.applicants[id]={id=id,status="applied",displayOrderID=id,members={{name="Member"..id.."-Away",nameKey="Member"..id.."-Away",class="MAGE",assignedRole="DAMAGER",raceName="Human",factionGroup=1}}} end
 a:Open("create");local page=u.pages.create;page.batchScroll.mouseOver=true
 local row=page.batchPool[1].people[1];local button=row.factionButton;local old=row.member
 button:Fire("OnMouseDown","LeftButton");page:SetBatchOffset(200,false)
 T.ok(row.member~=old);button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(row.factionExpanded,nil,"releasing a rebound faction button cannot expand the new applicant")
 button:Fire("OnClick","LeftButton");T.eq(row.factionExpanded,true,"direct activation expands the current applicant's race")
 button:Fire("OnMouseDown","RightButton");page:SetBatchOffset(0,false)
 button:Fire("OnMouseUp","RightButton");button:Fire("OnClick","RightButton")
 T.ok(not u.context.menu or not u.context.menu:IsShown(),"releasing a rebound faction press cannot open the new applicant's menu")
 u:Hide(true)
end

-- Favorite child actions retain the entry that owned their mouse press.
for _,actionName in ipairs({"remove","create"}) do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 local a,u,g=fresh.A,fresh.U,fresh.G;a:SetSetting("reduceMotion",true)
 for index=1,8 do g.Presets:ToggleFavorite({activityID=2,requiredItemLevel=200+index}) end
 a:Open("create");local page=u.pages.create;page.favoritesToggle:Fire("OnClick")
 local list=page.favoritesList;list.clip.mouseOver=true
 local row=list.rows[1];local old=row.key;local button=row[actionName]
 page.ilvl.box:SetText("399")
 button:Fire("OnMouseDown","LeftButton")
 list:SetPixelOffset(list.favoriteLayouts[old].height,false)
 local current=row.key;T.ok(current~=old,"scrolling reuses the pressed favorite's native row")
 button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(#g.Presets:Get(),8,"releasing a rebound favorite action cannot remove the new entry")
 T.eq(page:FormData().requiredItemLevel,399,"releasing a rebound favorite action cannot apply the new entry")
 button:Fire("OnClick","LeftButton")
 if actionName=="create" then T.eq(page:FormData().requiredItemLevel,current.requiredItemLevel,"direct activation applies the current favorite")
 else T.eq(#g.Presets:Get(),7);T.eq(g.Presets:Find(current),nil,"direct activation removes the current favorite") end
 button:Fire("OnMouseDown","LeftButton");page.favoritesToggle:Fire("OnClick")
 for _,pooled in ipairs(list.rows) do T.eq(pooled.create.targetKey,nil);T.eq(pooled.remove.targetKey,nil,"collapsed favorites release child action identities") end
 page.favoritesToggle:Fire("OnClick");local count=#g.Presets:Get();local itemLevel=page:FormData().requiredItemLevel
 button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(#g.Presets:Get(),count);T.eq(page:FormData().requiredItemLevel,itemLevel,"hiding and reopening cannot complete an old favorite press")
 local active=row.key;button:Fire("OnMouseDown","LeftButton");button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 if actionName=="create" then T.eq(page:FormData().requiredItemLevel,active.requiredItemLevel,"a new mouse press applies the current entry")
 else T.eq(#g.Presets:Get(),count-1,"a new mouse press removes the current entry") end
 u:Hide(true)
end

-- Raw applicant right-click targets remain attached to the pressed identity.
for _,entry in ipairs({"mapScore","row"}) do
 local fresh=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true})
 local a,u,g=fresh.A,fresh.U,fresh.G
 a.Configuration:Set({["layout.tables.createApplicants.sortKey"]=false,["layout.tables.createApplicants.descending"]=false},{storage="character"})
 local function Applicant(id,order)
  return {id=id,status="applied",displayOrderID=order or id,members={{name="Applicant"..id.."-Home",nameKey="Applicant"..id.."-Home",class="MAGE",assignedRole="DAMAGER",itemLevel=320,dungeonScore=2500,dungeonScores={mapScore=400}}}}
 end
 g.listing={activityID=2,name="Right-click target"};g.applicants={[1]=Applicant(1),[2]=Applicant(2),[3]=Applicant(3)}
 a:Open("create");local page=u.pages.create;page.batchScroll.mouseOver=true
 local row=page.batchPool[1].people[1];local button=entry=="row" and row or row.mapScoreButton
 local function CopyOpenedMenu()
  local menu=u.context.menu
  if not menu or not menu:IsShown() then return nil end
  for index,item in ipairs(menu.items) do if item.value=="copy" then
   local action=menu.list.rows[index];action:Fire("OnMouseDown","LeftButton");action:Fire("OnClick","LeftButton")
   local value=u.copyDialog.value;u:CloseModal();return value
  end end
  error("missing applicant copy action")
 end
 button:Fire("OnMouseDown","RightButton");g.applicants[1]=nil;g:Notify("applicants")
 T.eq(row.member.nameKey,"Applicant2-Home","a normal applicant notification rebinds the same visible row")
 button:Fire("OnMouseUp","RightButton");button:Fire("OnClick","RightButton")
 T.eq(CopyOpenedMenu(),nil,"a stale "..entry.." press cannot copy the replacement applicant")
 button:Fire("OnClick","RightButton");T.eq(CopyOpenedMenu(),"Applicant2-Home","direct right-click copies the current applicant")
 button:Fire("OnMouseDown","RightButton");g.applicants[4]=Applicant(4,0);g:Notify("applicants")
 T.eq(row.member.nameKey,"Applicant4-Home","a newly sorted applicant reuses the same native target")
 button:Fire("OnMouseUp","RightButton");button:Fire("OnClick","RightButton")
 T.eq(CopyOpenedMenu(),nil,"insertion cannot retarget a pending "..entry.." menu")
 button:Fire("OnMouseDown","RightButton");g:Notify("applicants");button:Fire("OnMouseUp","RightButton");button:Fire("OnClick","RightButton")
 T.eq(CopyOpenedMenu(),"Applicant4-Home","a new press survives a same-identity refresh")
 button:Fire("OnMouseDown","RightButton");button:Fire("OnLeave");button:Fire("OnMouseUp","RightButton");button:Fire("OnClick","RightButton")
 T.eq(CopyOpenedMenu(),nil,"leaving cancels the pressed "..entry.." identity")
 button:Fire("OnClick","RightButton");T.eq(CopyOpenedMenu(),"Applicant4-Home","consuming a cancelled press does not block direct activation")
 button:Fire("OnMouseDown","RightButton");a:Open("settings");a:Open("create")
 button:Fire("OnMouseUp","RightButton");button:Fire("OnClick","RightButton")
 T.eq(CopyOpenedMenu(),nil,"hiding and reopening cancels the old "..entry.." press")
 button:Fire("OnMouseDown","RightButton");button:Fire("OnMouseUp","RightButton");button:Fire("OnClick","RightButton")
 T.eq(CopyOpenedMenu(),"Applicant4-Home","a new press after reopening targets the current member")
 u:Hide(true)
end

-- Theme saves explain their reload boundary without applying appearance or search.
for _,locale in ipairs({"zhCN","enUS"}) do
 local fresh=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=fresh.A,fresh.U,fresh.G
 a:SetSetting("reduceMotion",true);a:Open("settings",{section="interface"})
 local page=u.pages.settings;local reload=page.reloadLanguage;local current=u.context.Theme
 T.eq(page.themeReloadHint,nil,"default Settings do not construct a pending-theme message")
 T.eq(reload:IsShown(),false)
 local searches=0;local search=g.Search.Search
 g.Search.Search=function(self,...) searches=searches+1;return search(self,...) end
 local definition={schema=1,id="fixture.reload.hint."..locale,revision=1,appearance={main={tokens={brand={.2,.3,.4,1}}}}}
 T.ok(a.API.Theme:Import(definition,{activate=true}))
 T.eq(page.themeReloadHint,nil,"Theme import does not broadcast a UI refresh")
 page:Sync()
 T.eq(page.reloadLanguage,reload,"pending themes reuse the existing reload button")
 T.eq(reload:IsVisible(),true)
 T.eq(page.themeReloadHint:GetText(),locale=="zhCN" and "主题已保存，重载界面后生效。" or "Theme saved. Reload the UI to apply it.")
 T.eq(page.themeReloadHint:IsVisible(),true);T.eq(page.themeReloadHint:GetParent(),page.panels.interface)
 T.eq(u.context.Theme,current,"showing pending feedback never replaces the current theme")
 T.eq(searches,0,"reading and presenting pending status does not start a search")
 local hintSize=select(2,page.themeReloadHint:GetFont())
 a:SetSetting("fontScale",130)
 T.near(select(2,page.themeReloadHint:GetFont()),hintSize*1.3,.001,"pending feedback follows the live font preference")
 T.ok(page.themeReloadHint:GetWidth()>0 and page.themeReloadHint:GetWidth()+reload:GetWidth()+16<=page.panels.interface:GetWidth(),"pending text leaves space for the existing reload action")
 a:SetSetting("fontScale",100)
 local nativeUI=C_UI;local reloads=0;_G.C_UI={Reload=function() reloads=reloads+1 end}
 reload:Fire("OnClick","LeftButton");_G.C_UI=nativeUI
 T.eq(reloads,1,"the shared reload action remains connected")
 page:SelectSection("general")
 T.eq(page.themeReloadHint:IsVisible(),false,"pending feedback is confined to Interface settings")
 T.ok(a.API.Theme:Remove(definition.id));page:Sync()
 T.eq(page.themeReloadHint:IsShown(),false);T.eq(reload:IsShown(),false)
 a:SetSetting("language",locale=="zhCN" and "enUS" or "zhCN");page:SelectSection("general")
 T.eq(reload:IsVisible(),true,"language-only reload feedback keeps the existing button")
 T.eq(page.themeReloadHint:IsShown(),false,"a language change does not claim that a theme was saved")
 T.ok(a.API.Theme:Import(definition,{activate=true}));page:Sync()
 a:SetSetting("language","auto");page:Sync()
 page:SelectSection("interface")
 T.eq(reload:IsVisible(),true,"clearing the language change still leaves a pending theme actionable")
 T.eq(page.themeReloadHint:IsVisible(),true)
 u:Hide(true)
end
