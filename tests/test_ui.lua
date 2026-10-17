-- Offline interaction coverage for the approved v4.4 layout and native field leasing.
local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,G,S,Pick=f.A,f.U,f.G,f.S,f.Pick
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
 for _,map in ipairs({3077,3079,2664}) do U:SetActivityIcon(icon,{mapID=map,categoryID=121});T.eq(icon:GetTexture(),U.Theme.media.."delve.tga","unmapped Delves without journal art use their category icon") end
 T.same(icon.texCoords,{0,1,0,1},"category art does not retain the previous atlas crop")
 U:SetActivityIcon(icon,{mapID=3038,categoryID=121});T.eq(icon:GetTexture(),12345,"an unmapped Delve may use available native journal art")
 local before=journalQueries;U:SetActivityIcon(icon,{mapID=3077,categoryID=121});T.eq(journalQueries,before,"missing journal art is cached between row bindings")
 atlasReady=false;U:SetActivityIcon(icon,{mapID=2963,categoryID=121});T.eq(icon:GetTexture(),U.Theme.media.."delve.tga","an unavailable atlas has a visible category fallback")
 atlasReady=true;U:SetActivityIcon(icon,{mapID=2963,categoryID=121});T.eq(icon:GetTexture(),7291407,"a later available atlas replaces the fallback")
 U:SetActivityIcon(icon,{mapID=99999,categoryID=2});T.eq(icon:GetTexture(),12345,"ordinary dungeon artwork uses the journal's sixth return, the button thumbnail")
 T.near(icon.texCoords[1],.06,.000001,"rebinding to dungeon art restores its complete texture crop")
 for _,category in ipairs(G.Catalog:GetCategories()) do
  U:SetActivityIcon(icon,{categoryID=category.id});T.eq(icon:GetTexture(),U.Theme.media..category.icon..".tga","activities without a map use their catalog category icon")
 end
 U:SetActivityIcon(icon,{categoryID=1,mapID=99998});T.eq(icon:GetTexture(),U.Theme.media.."flag.tga","a quest without journal art uses the quest category icon")
 C_Texture.GetAtlasInfo=getAtlas;C_EncounterJournal.GetInstanceForGameMap=getJournal;EJ_GetInstanceInfo=getInstance;G.Catalog.GetCategories=getCategories
end
A.db.reduceMotion=true
do
 local native=C_ChallengeMode.GetDungeonScoreRarityColor;local reads=0
 C_ChallengeMode.GetDungeonScoreRarityColor=function(score) reads=reads+1;return native(score) end
 local one=U.C.Text(UIParent,"",12);local two=U.C.Text(UIParent,"",12)
 U:SetScore(one,nil);T.eq(one:GetText(),"未知分数");T.eq(U:ScoreText(nil),"未知分数")
 U:SetScore(one,0);T.eq(one:GetText(),"暂无分数");T.eq(U:ScoreText(0,"pvp"),"暂无分数")
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
 local copyDialog
 for index,row in ipairs(settings.otherAddons) do
  T.eq(#row.links,#expectedLinks[index]);T.ok(row.summary:GetText()~="")
  for i,button in ipairs(row.links) do
   button:Fire("OnClick","LeftButton")
   T.eq(U.copyDialog.field.box:GetText(),expectedLinks[index][i],"addon links open the existing Ctrl+C modal with the verified URL")
   T.eq(U.copyDialog.fieldLabel:GetText(),U.L.downloadLink)
   if copyDialog then T.eq(U.copyDialog,copyDialog,"all addon links reuse the common copy dialog") else copyDialog=U.copyDialog end
   U.copyDialog.close:Fire("OnClick");T.eq(U.copyDialog.field.box:HasFocus(),false)
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
T.eq(A.db.rememberFilters,false,"shared browse preference writes through Core")
T.eq(settings.panels.keywords,nil,"keyword filtering has been removed from settings")
T.eq(settings.keywordInput,nil)
settings:SelectSection("interface");Pick(settings.controls.raidMembers.widget,"always");T.eq(A.db.raidMembers,"always")
T.eq(settings.panels.sounds,nil,"sound settings page is removed");T.eq(settings.controls.applicantTone,nil,"notification tone is not configurable")
settings:SelectSection("floating");settings.controls.floatingScale.widget.slider:SetValue(125);T.eq(A.db.floatingScale,125)
U:Hide()
local stockNameBorder=CreateFrame("Frame",nil,LFGListFrame.EntryCreation.Name);stockNameBorder:SetAlpha(.6);LFGListFrame.EntryCreation.Name.NineSlice=stockNameBorder
-- Exact shape observed in the live native-art probe: an anonymous child Frame
-- with two horizontal and two vertical WHITE8X8 lines, and no backdrop or alias.
local function SkinBorder(parent)
 local border=CreateFrame("Frame",nil,parent);border:SetAllPoints()
 for i=1,4 do local line=border:CreateTexture(nil,"OVERLAY");line:SetTexture(130871);if i<=2 then line:SetHeight(.75) else line:SetWidth(.75) end end
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
 T.eq(create.rosterList.rows[1].key,nil,"hidden roster rows remain released")
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
T.eq(create.formFrame:GetWidth(),700);T.eq(create.rail:GetWidth(),288)
T.eq(create.descriptionShell:GetHeight(),80,"native description shell matches one-screen mock")
T.eq(create.ilvl.placeholder:GetText(),"不限");T.eq(create.ilvl.placeholder:IsShown(),true,"unrestricted item level has an explicit placeholder")
local rosterRow=create.rosterList.rows[1]
T.eq(rosterRow.title:GetText(),"Player-Home","current member identity is complete on the first line")
T.eq(rosterRow.meta:GetText(),"战士 · 未知","the second line contains only class and specialization")
T.eq(rosterRow.leaderTag:IsShown(),true,"leader marker remains a separate subdued label")
do
 local clip=create.rosterList.clip;clip.mouseOver=true
 local open,showPlayer=A.Open,U.Tooltip.ShowPlayer;local opens,shows=0,0
 A.Open=function() opens=opens+1 end;U.Tooltip.ShowPlayer=function() shows=shows+1 end
 local selectedKey=create.rosterList.selectedKey
 for _,button in ipairs({"LeftButton","RightButton"}) do rosterRow:Fire("OnMouseDown",button);rosterRow:Fire("OnMouseUp",button);rosterRow:Fire("OnClick",button) end
 A.Open,U.Tooltip.ShowPlayer=open,showPlayer
 T.eq(opens,0,"current-member clicks do not route to Notes");T.eq(shows,0,"current-member clicks do not open a preview tooltip")
 T.eq(create.rosterList.selectedKey,selectedKey,"read-only current-member clicks do not select a row")
 T.eq(rosterRow.tooltipArea:GetWidth(),rosterRow:GetWidth()*.25,"current-member details activate only over the left quarter")
 local width=rosterRow:GetWidth();rosterRow:SetWidth(width-20)
 T.eq(rosterRow.tooltipArea:GetWidth(),rosterRow:GetWidth()*.25,"the quarter-width trigger follows the actual row when its gutter changes")
 rosterRow:SetWidth(width)
 U.Tooltip:Hide();rosterRow:Fire("OnEnter");T.eq(U.Tooltip.owner,nil,"current-member row hover alone does not open player details")
 rosterRow.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.owner,rosterRow,"current-member identity area opens player details")
 T.eq(rosterRow.tooltipArea.mouseEnabled,false);T.eq(rosterRow.tooltipArea.mouseMotionEnabled,true)
 rosterRow.mouseOver=true;rosterRow.tooltipArea:Fire("OnLeave");U.Motion:Tick(.25)
 T.eq(U.Tooltip.owner,nil,"leaving the roster identity area closes details even while over the row")
 rosterRow.mouseOver=nil;clip.mouseOver=nil
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
 local function PointY(region) local points={region:GetPoint()};return points[#points] end
 local validator=native.ItemLevel.validateFunc;local ownLevel=200;local warning="要求的物品等级高于你自己的物品等级。"
 native.ItemLevel.validateFunc=function(_,value) if tonumber(value)>ownLevel then return warning end end
 create.ilvl.box:SetText("220");create:ValidateForm()
 T.eq(create.formError:GetText(),warning,"the native requirement reason reaches the form notice")
 T.ok(create.formNotice:IsShown());T.eq(create.formError.justify,"LEFT")
 local point={create.formNotice:GetPoint()};T.eq(point[1],"TOPLEFT");T.eq(point[#point],-44,"the notice appears immediately after the heading")
 T.eq(PointY(create.desc),-56-create.formNotice:GetHeight()-12,"the notice pushes the form content down only while shown")
 T.eq(PointY(create.req),-356-create.formNotice:GetHeight()-12)
 T.eq(create.ilvl.box:GetText(),"220","validation never clamps the user's item level requirement")
 ownLevel=240;create:ValidateForm();T.eq(create.formNotice:IsShown(),false,"unchanged text is revalidated after the player's equipment changes")
 T.eq(PointY(create.desc),-56,"clearing the notice removes its layout space")
 T.eq(PointY(create.req),-356)
 native.ItemLevel.validateFunc=validator;create.ilvl.box:SetText("");create:ValidateForm()
 local height=create.batchScroll:GetHeight()
 create:SetManageError("An applicant action failed. Please check the current application.")
 T.ok(create.manageNotice:IsShown());T.eq(create.dError.justify,"LEFT")
 T.eq(create.batchScroll:GetHeight()+create.manageNotice:GetHeight()+12,height,"the recruitment notice reserves real viewport space")
 T.eq(PointY(create.batchScroll),-194-create.manageNotice:GetHeight()-12,"the recruitment list moves down when the notice appears")
 T.eq(PointY(create.applicantHeaders.name),-167-create.manageNotice:GetHeight()-12)
 T.eq(create.batchSlider:GetHeight(),create.batchScroll:GetHeight())
 create.manageNotice.close:Fire("OnClick");T.eq(create.batchScroll:GetHeight(),height,"closing the notice restores the list viewport")
 T.eq(PointY(create.batchScroll),-194);T.eq(PointY(create.applicantHeaders.name),-167)
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
 create.pickerEntries={{category="seasonDungeon",group=group}}
 create:SelectPickerRow(1)
 T.eq(create:FormData().activityID,2,"new seasonal dungeons default to Mythic Keystone even when Normal sorts first")
 for _,button in ipairs(create.difficultyButtons) do if button.value==3 then button:Fire("OnClick");break end end
 create:RefreshPicker()
 T.eq(create:FormData().activityID,3,"an explicit Normal choice remains selected on refresh")
 group.variants=variants
 create:SelectPickerRow(1)
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
 T.eq(#create.pickerEntries,1)
 groups[2]=nil;create:RefreshPickerRows()
 T.eq(create.tierChoice:IsShown(),false,"单一有效范围不显示只有全部和自身的下拉")
 T.eq(create.pickerTier,nil,"隐藏下拉同时清除已失效的范围条件")
 T.eq(#create.pickerEntries,1,"清除隐藏范围后唯一活动仍可浏览")
 catalog.GetGroups,catalog.GetTiers=getGroups,getTiers;create:ClosePicker()
end
create:TogglePicker();create.pickerSearch.box:SetText("Dungeon")
T.eq(#create.pickerEntries,2,"one dungeon group has distinct seasonal and original contexts")
local original;for i,entry in ipairs(create.pickerEntries) do if entry.category=="2" then original=i end end
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
native.Name:UserType("My custom group");create:TogglePicker();create.pickerSearch.box:SetText("Dungeon");local seasonal;for i,entry in ipairs(create.pickerEntries) do if entry.category=="seasonDungeon" then seasonal=i end end;create:SelectPickerRow(seasonal);T.eq(native.Name:GetText(),"My custom group","activity change preserves a custom title")
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
 T.eq(row.roles[1]:GetTexture(),U.Theme.media.."role-tank.tga");T.eq(row.roles[2]:GetTexture(),U.Theme.media.."role-dps.tga")
 T.eq(row.roles[1]:IsShown(),true);T.eq(row.roles[2]:IsShown(),true);T.eq(row.roles[3]:IsShown(),false,"a DK applicant can request tank and damage independently of specialization")
 create.roleFilters.TANK:Fire("OnClick");T.eq(#create.appIDs,1)
 create.roleFilters.DAMAGER:Fire("OnClick");T.eq(#create.appIDs,1)
 create.roleFilters.HEALER:Fire("OnClick");T.eq(#create.appIDs,0)
 create.roleFilters.ALL:Fire("OnClick")
 dk.requestedRoles.TANK=false;G:Notify("applicants")
 T.eq(solo.people[1],row,"changing requested roles reuses the existing applicant row")
 T.eq(row.roles[1]:GetTexture(),U.Theme.media.."role-dps.tga");T.eq(row.roles[2]:IsShown(),false);T.eq(row.roles[3]:IsShown(),false,"row reuse removes the old second requested role")
 T.eq(dk.specID,252);T.eq(row.icon:GetTexture(),specTexture,"requested roles do not rewrite the DK specialization icon")
 G.applicants[70]=nil;G:Notify("applicants")
 T.eq(solo.appID,nil);T.eq(solo.people[1].member,nil,"emptying recruitment releases pooled member bindings")
end
G.applicants[71]={id=71,status="applied",displayOrderID=1,comment="We join together",members={{name="One-Away",nameKey="One-Away",class="WARRIOR",assignedRole="TANK",specID=71,itemLevel=270,dungeonScore=2200},{name="Two-Away",nameKey="Two-Away",class="PALADIN",assignedRole="HEALER",specID=66,itemLevel=260,dungeonScore=2100}}}
G:Notify("applicants")
local batch=create.batchPool[1]
T.eq(batch.people[2]:IsShown(),true,"every batch member has an individual row")
T.eq(batch.comment:GetText(),"We join together");T.eq(batch.people[2].score:GetText(),"2100")
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
 local function X(region) local p={region:GetPoint()};return p[#p-1] end
 for _,pair in ipairs({{"ilvl","ilvl"},{"rating","score"}}) do
  local header,value=create.applicantHeaders[pair[1]],batch.people[1][pair[2]]
  T.eq(header.justify,"RIGHT");T.eq(X(header)+header:GetWidth(),X(value)+value:GetWidth(),"numeric header and value share their right edge")
 end
 T.eq(X(create.applicantHeaders.actions),X(batch.invite));T.eq(create.applicantHeaders.actions:GetWidth(),84)
 T.eq(create.rosterList.gutter,0,"a fitting roster keeps equal card margins without an empty scrollbar slot")
end
do
 local saved=G.applicants[71]
 local one={name="ArenaOne-Away",nameKey="ArenaOne-Away",class="MAGE",assignedRole="DAMAGER",itemLevel=288,dungeonScore=3900,ratingKind="pvp",rating=1950,pvpRatingInfo={bracket=1,rating=1950,activityName="2v2"}}
 local two={name="ArenaTwo-Away",nameKey="ArenaTwo-Away",class="PRIEST",assignedRole="HEALER",itemLevel=285,dungeonScore=4100,ratingKind="pvp",rating=1450,pvpRatingInfo={bracket=1,rating=1450,activityName="2v2"}}
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
 T.eq(U.Tooltip.interactive.metrics[2].title:GetText(),"3v3");T.eq(U.Tooltip.interactive.metrics[2].value:GetText(),"暂无分数","真实零分与未知评分明确区分")
 U.Tooltip:Hide();G.applicants[71]=saved;G.applicants[72]=nil;Pick(create.sortChoice,"newest");G:Notify("applicants")
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
batch.invite:Fire("OnClick");T.eq(G.invitedApplicant,71);T.eq(batch.invite:IsShown(),false,"inflight invitation removes duplicate actions")
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
 create:RefreshApplicants();create:SetBatchOffset(0,false);A.db.reduceMotion=false
 local get=G.GetApplicant;local reads,total=0,0
 G.GetApplicant=function(self,id) reads=reads+1;return get(self,id) end
 create.batchScroll:Fire("OnMouseWheel",-1)
 for tick=1,9 do
  local first,last=create.firstBatch,create.lastBatch;reads=0;U.Motion:Tick(1/60);total=total+reads
  if first==create.firstBatch and last==create.lastBatch then T.eq(reads,0,"scrolling within a bound interval does not reread applicants")
  else T.eq(reads,create.lastBatch-create.firstBatch+1,"a changed interval reads only its visible batches") end
 end
 T.eq(total,8,"one wheel animation reads eight newly visible batches instead of scanning one hundred per tick")
 create:SetBatchOffset(8000,false);T.eq(create.batchPool[1].appID,94);T.eq(create.batchPool[7].appID,100,"scrolling reaches the final applicant without truncating the data")
 G.applicants[1].members={Member(1),Member(101),Member(102),Member(103),Member(104)}
 G.applicants[2].members={Member(2),Member(105)}
 create:RefreshApplicants();create:SetBatchOffset(0,false)
 T.eq(create.batchPool[1]:GetHeight(),320);T.eq(create.batchPool[2]:GetHeight(),140)
 T.eq(create.batchPool[3].appID,3);T.eq(create.batchPool[1].people[5].member,G.applicants[1].members[5],"a tall batch keeps every member")
 create:SetBatchOffset(320,false);T.eq(create.firstBatch,1,"a batch touching the top edge keeps the established boundary semantics")
 create:SetBatchOffset(320.1,false);T.eq(create.firstBatch,2);T.eq(create.batchPool[1].appID,2,"cached geometry locates the next variable-height batch")
 create:SetBatchOffset(8000,false);create:SetBatchOffset(0,false)
 local nodes,pool=#S.nodes,#create.batchPool
 create:SetBatchOffset(8000,false);create:SetBatchOffset(0,false)
 T.eq(#S.nodes,nodes,"variable-height scrolling reuses the reached batch/member object high-water mark")
 T.eq(#create.batchPool,pool);T.ok(pool<=8,"one hundred applicant batches retain only a viewport-sized native pool")
 G.GetApplicant=get;G.applicants=saved;create:RefreshApplicants();create:SetBatchOffset(0,false)
end
A.db.reduceMotion=false;create.batchScroll:Fire("OnMouseWheel",-1);T.ok(U.Motion.jobs[create.batchScroll],"applicant wheel movement starts one finite animation");U.Motion:Tick(.2);T.eq(create.batchScroll:GetVerticalScroll(),56);T.eq(U.Motion.jobs[create.batchScroll],nil)
A.db.reduceMotion=true
U:Hide();T.eq(native.Name:GetParent(),native,"hiding restores native protected title parent")
T.eq(U.Motion.jobs[create.batchScroll],nil,"leaving Create releases its scroll driver")
for id=72,84 do G.applicants[id]=nil end
T.eq(stockNameBorder:IsShown(),true);T.eq(stockNameBorder:GetAlpha(),.6,"release restores native border alpha and visibility")
T.eq(anonymousNameBorder:IsShown(),true);T.eq(anonymousNameBorder:GetAlpha(),.7);T.eq(anonymousDescriptionBorder:IsShown(),true,"release restores the skin's original border state")
A:Open("notes",{add={name="Guest",realm="Away",class="WARRIOR",specID=71,type="positive"}})
local notes=U.pages.notes
T.eq(notes.reminderState,nil);T.eq(notes.historyState,nil,"notes and history leave preference states in Settings")
T.eq(notes.left:GetWidth(),326);T.eq(notes.list.rowHeight,88)
T.eq(notes.search:GetWidth(),notes.list.rows[1]:GetWidth(),"notes search ends at the card edge before the scrollbar gutter")
local function AnchorX(region) local point={region:GetPoint()};return point[#point-1] end
T.eq(AnchorX(notes.listTitle),AnchorX(notes.list.rows[1].icon),"notes heading aligns to card icon and reason inset")
T.eq(AnchorX(notes.countText),AnchorX(notes.list.rows[1].kind)-U.C.listRightInset,"record count shares the card's inner right edge")
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
 T.eq(select(2,button.label:GetFont()),14,"delete keeps the normal shared button font")
 local cancelStart=notes.editor:GetWidth()-16-notes.eSave:GetWidth()-8-notes.eCancel:GetWidth()
 T.ok(cancelStart-(16+button:GetWidth())>=12,"the destructive action stays separate from Cancel and Save")
 button:Fire("OnEnter");T.same(button.label.color,U.Theme.accent,"the shared hover state makes the destructive action explicit")
 button:Fire("OnLeave");T.same(button.label.color,U.Theme.muted)
end
notes.typeButtons.caution:Fire("OnClick");notes.eReason.box:SetText("A different experience");notes:Save();T.eq(note.type,"caution")
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
 A.Notes:Remove("Legacy-Away");A.Notes:Remove("Observed-Away");base.SetUnit("party1",nil)
 notes:OpenEdit("Guest-Away")
end
notes:SelectTab("positive");T.eq(#notes.list.ids,0,"note type filtering follows edits")
notes:SelectTab("history");T.eq(notes.historyFrame:IsShown(),true);T.eq(notes.toolbar:IsShown(),false)
do
 local list=A.Notes.List;local reads=0
 A.Notes.List=function(...) reads=reads+1;return list(...) end
 A:Open("notes");T.eq(reads,0,"reentering history does not build the hidden player-note list")
 T.eq(notes.historyFrame:IsShown(),true)
 notes:SelectTab("all");reads=0
 A:Open("notes");T.eq(reads,1,"reentering player notes generates its ordered list once")
 T.eq(notes.left:IsShown(),true);T.ok(notes.list.ids and #notes.list.ids>0)
 notes:SelectTab("history");A.Notes.List=list
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
 local remember=A.db.rememberFilters;A.db.rememberFilters=true
 G.db.prefs.find={filters={text="Old saved local query",minLevel=12,maxLevel=99,tankPresence="present",healerPresence="missing",needsDamage=true}}
 local combat=InCombatLockdown;_G.InCombatLockdown=function() return true end
 T.eq(A:Open("find"),true,"Find first opens during combat without protected mouse propagation")
 local page=U.pages.find
 T.eq(G.filters.tankPresence,"present");T.eq(G.filters.healerPresence,"missing");T.eq(G.filters.needsDamage,true,"first entry restores all role-presence fields from fallback filters")
 T.eq(page.rolePresenceChoices.TANK.value,"present");T.eq(page.rolePresenceChoices.HEALER.value,"missing");T.eq(page.rolePresenceChoices.DAMAGER.value,"missing")
 page:ClearFilters();T.eq(G.filters.tankPresence,nil);T.eq(G.filters.healerPresence,nil);T.eq(G.filters.needsDamage,nil)
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
 T.eq(page.filterPanel:GetHeight(),616,"seasonal role-presence rows fit alongside size, relations and sorting")
 local revision=U.Native.searchLease.revision
 box:UserType("12-15");T.eq(U.Native.searchLease.revision,revision+1,"each native edit distinguishes a newer query without parsing it")
 T.eq(G.filters.text,nil);T.eq(G.filters.leaderText,nil);T.eq(G.filters.minLevel,nil);T.eq(G.filters.maxLevel,nil,"native range text is never copied into local result filters")
 T.eq(G.db.prefs.find.filters.text,nil,"protected search text is not saved for a forbidden SetText restore")
 box:SetFocus();T.eq(page.search.focused,true);box:Fire("OnEnterPressed")
 T.eq(G.searchText,"12-15","Enter submits the text already owned by the native input")
 page:SelectCategory("seasonDungeon");T.eq(box:GetText(),"12-15","searches within the category preserve the player's native query")
 page.fMembers.box:SetText("5")
 page:SelectCategory("seasonRaid");T.eq(box:GetText(),"","switching category clears incompatible native text and activity tokens")
 T.eq(page.searchHint:GetText(),"队伍标题","raid search returns to title mode without a key-range hint")
 T.eq(page.searchModeToggle:IsShown(),true);T.eq(page.search.box,box)
 T.eq(G.filters.maxMembers,nil,"a category without saved conditions does not inherit the dungeon member limit")
 page.activities.rows[1]:Fire("OnClick","LeftButton")
 page.search.box:UserType("Heroic");page.refresh:Fire("OnClick");T.eq(G.searchMode,"group");T.eq(G.searchText,"Heroic")
 page.searchClear:Fire("OnClick");T.eq(page.search.box:GetText(),"");T.eq(G.searchText,"")
 page:SelectCategory("seasonDungeon")
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
 box.text="Other browser activity";box:Fire("OnTextChanged",false)
 T.eq(box:GetText(),"","an external activity token cannot refill the active Lychee query after an availability update")
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
 A.db.rememberFilters=remember
end
A:Open("find")
local find=U.pages.find
do
 local getResults,previousState,previousError,inputError=G.GetResults,G.state,G.error,find.searchError
 local resultIDs=getResults(G)
 G.GetResults=function() return {} end;find.searchError=nil
 G.state="waiting";G.error="Retry in 5 seconds";G:Notify("search")
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
 G.state="waiting";G.error="Retry in 3 seconds";G:Notify("search")
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
T.eq(find.rail:GetWidth(),208);T.eq(find.main:GetWidth(),856)
T.eq(find.filterPanel:GetWidth(),268);T.eq(find.results.rowHeight,72)
do
 local countPoint={find.resultCount:GetPoint()}
 T.eq(countPoint[1],"LEFT");T.eq(countPoint[2],find.context);T.eq(countPoint[3],"RIGHT");T.eq(countPoint[4],12)
 T.eq(find.resultCount.justify,"LEFT","the result count stays beside the context heading")
 local headerPoint={find.resultsHeader:GetPoint()};local contextPoint={find.context:GetPoint()}
 T.eq(contextPoint[#contextPoint]-headerPoint[#headerPoint],40,"the larger context heading stays close to the column headings")
 T.eq(select(2,find.context:GetFont()),20);T.eq(find.context:GetHeight(),28)
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
  {key=501,name="TWW Delve",tier=10,activity={id=501,groupKey=501,categoryID=121,fixtureTier=10}},
  {key=502,name="Midnight Delve",tier=11,activity={id=502,groupKey=502,categoryID=121,fixtureTier=11}},
  {key=503,name="Unmapped Delve",activity={id=503,groupKey=503,categoryID=121}},
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
T.eq(membersAnchor[#membersAnchor],-139,"non-dungeon filters close the hidden key-level row")
T.ok(find.fMembers.placeholder and find.fMembers.placeholder:IsShown(),"an empty numeric filter visibly says unrestricted")
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
local rememberBounds=A.db.rememberFilters;A.db.rememberFilters=true
find.fMembers.box:SetText("4");find.fMinMembers.box:SetText("2")
T.eq(G.filters.minMembers,2);T.eq(G.filters.maxMembers,4,"minimum input never overwrites the maximum")
find.fMinMembers.box:SetText("3");T.eq(G.filters.maxMembers,4)
find:SelectCategory("seasonDungeon");T.eq(G.filters.minMembers,nil,"a category without a minimum stays unrestricted")
find:SelectCategory("seasonRaid");T.eq(G.filters.minMembers,3);T.eq(G.filters.maxMembers,4,"both bounds restore with their category")
find:ClearFilters();T.eq(G.filters.minMembers,nil);T.eq(G.filters.maxMembers,nil)
do
 find:SelectCategory("seasonDungeon")
 local filtersOpen=find.filtersOpen;find:SetFiltersOpen(true)
 local choices=find.rolePresenceChoices
 local function Choose(role,value)
  for _,button in ipairs(choices[role].buttons) do if button.value==value then button:Fire("OnClick");return end end
  error("missing role-presence option "..role..":"..value)
 end
 T.eq(find.rolePresencePanel:IsShown(),true);T.eq(find.roleChoice:IsShown(),false,"seasonal dungeons replace the old one-role menu")
 T.eq(#choices.TANK.buttons,3);T.eq(#choices.HEALER.buttons,3);T.eq(#choices.DAMAGER.buttons,2,"damage exposes only unrestricted and missing")
 Choose("TANK","present");T.eq(G.filters.tankPresence,"present")
 Choose("TANK","missing");T.eq(G.filters.tankPresence,"missing");T.eq(choices.TANK.buttons[2].active,false);T.eq(choices.TANK.buttons[3].active,true,"tank presence options are mutually exclusive")
 Choose("HEALER","present");Choose("DAMAGER","missing")
 T.eq(G.filters.tankPresence,"missing");T.eq(G.filters.healerPresence,"present");T.eq(G.filters.needsDamage,true,"independent role fields combine in the result filter")
 find:SelectCategory("seasonRaid")
 T.eq(find.rolePresencePanel:IsShown(),false);T.eq(G.filters.tankPresence,nil);T.eq(G.filters.healerPresence,nil);T.eq(G.filters.needsDamage,nil,"seasonal conditions do not leak to raids")
 find:SelectCategory("seasonDungeon")
 T.eq(choices.TANK.value,"missing");T.eq(choices.HEALER.value,"present");T.eq(choices.DAMAGER.value,"missing","returning restores the category's visible controls")
 local catalog=G.Catalog;local getActivities=catalog.GetActivities
 catalog.GetActivities=function(self,key) if key=="2" then return {self:GetActivity(2)} end;return getActivities(self,key) end
 find:SelectCategory("2");T.eq(find.roleChoice:IsShown(),true,"ordinary Mythic+ browsing keeps the existing missing-role menu")
 Pick(find.roleChoice,"TANK");T.eq(G.filters.neededRole,"TANK");T.eq(G.filters.tankPresence,nil)
 find:SelectCategory("seasonDungeon");T.eq(G.filters.neededRole,nil);T.eq(G.filters.tankPresence,"missing")
 find:SelectCategory("2");T.eq(find.roleChoice.value,"TANK");T.eq(G.filters.neededRole,"TANK","the original category restores its own role choice")
 find:SelectCategory("seasonDungeon");catalog.GetActivities=getActivities;find.clearFilters:Fire("OnClick")
 for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do T.eq(choices[role].value,"any") end
 T.eq(G.filters.tankPresence,nil);T.eq(G.filters.healerPresence,nil);T.eq(G.filters.needsDamage,nil)
 find:SelectCategory("seasonRaid");find:SelectCategory("seasonDungeon")
 T.eq(choices.TANK.value,"any");T.eq(choices.HEALER.value,"any");T.eq(choices.DAMAGER.value,"any","cleared conditions do not return after a category switch")
 for _,role in ipairs({"TANK","HEALER","DAMAGER"}) do
  find:RestoreCategory({neededRole=role});find:UpdateFilters()
  T.eq(choices[role].value,"missing","legacy saved missing-role filters migrate to a visible seasonal choice")
  T.eq(G.filters.neededRole,nil,"the migrated condition has only one active representation")
  Choose(role,"any")
  local saved=G.db.prefs.find.categoryPrefs.seasonDungeon
  T.eq(saved.neededRole,nil);T.eq(saved.tankPresence,nil);T.eq(saved.healerPresence,nil);T.eq(saved.needsDamage,nil,"choosing unrestricted completely removes the legacy condition")
 end
 find:SelectCategory("seasonRaid");find:SetFiltersOpen(filtersOpen)
end
A.db.rememberFilters=rememberBounds
T.eq(find.filterToggle.label:GetText(),"筛选","the filter arrow is texture art rather than an unsupported font glyph")
for _,r in ipairs(find.seasonCategories.rows) do if r.key=="seasonRaid" then T.eq(r.selected:IsShown(),true,"category selection has a tonal background and vertical marker");T.eq(r.mark:IsShown(),true) end end


find:SelectCategory("seasonDungeon")
local activityRow=find.activities.rows[2]
activityRow:Fire("OnMouseDown");activityRow:Fire("OnClick","LeftButton")
for _,button in ipairs(find.difficultyButtons) do if button.value==1 and button:IsShown() then button:Fire("OnClick") end end
T.eq(find.searchHint:GetText(),"队伍标题","normal dungeon search uses the native title query")
T.eq(find.rolePresencePanel:IsShown(),true,"seasonal role-presence choices also work at normal difficulty")
find.rolePresenceChoices.TANK.buttons[2]:Fire("OnClick");T.eq(G.filters.tankPresence,"present");T.eq(G.filters.neededRole,nil)
find.rolePresenceChoices.TANK.buttons[1]:Fire("OnClick")
local searchMethod=G.Search.Search;local requestedActivity
G.Search.Search=function(_,category,id) requestedActivity=id;return true end
find:DoSearch();T.eq(requestedActivity,3,"a selected seasonal map and normal difficulty request its unique native activity")
for _,button in ipairs(find.difficultyButtons) do if button.value==false and button:IsShown() then button:Fire("OnClick") end end
T.eq(find.searchHint:GetText(),"队伍标题或钥石范围，如 12-15");T.eq(find.searchModeToggle:IsShown(),true,"title and leader modes remain available with Mythic+ selected")
find:DoSearch();T.eq(requestedActivity,nil,"multiple valid native difficulties are not replaced by a guessed activity")
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
  {id=2001,groupKey=201,categoryID=2,difficultyID=8,isMythicPlusActivity=true,fixtureTier=1},
  {id=2002,groupKey=202,categoryID=2,difficultyID=8,isMythicPlusActivity=true,fixtureTier=1},
  {id=2003,groupKey=201,categoryID=2,difficultyID=1,fixtureTier=1},
  {id=2004,groupKey=203,categoryID=2,difficultyID=1,fixtureTier=1},
 }
 local groups={{key=201,name="毒牙洞窟",tier=1,activity=activities[1]},{key=202,name="红玉新生法池",tier=1,activity=activities[2]},{key=203,name="普通专属地下城",tier=1,activity=activities[4]}}
 catalog.GetActivities=function(self,key) if key=="seasonDungeon" or key=="2" then return activities end;return getActivities(self,key) end
 catalog.GetGroups=function(self,key) if key=="seasonDungeon" or key=="2" then return groups end;return getGroups(self,key) end
 catalog.GetActivityTier=function(self,activity) return activity.fixtureTier or getTier(self,activity) end
 catalog.GetGroupShortName=function(self,key,groupKey) if groupKey==201 then return "毒牙" elseif groupKey==202 then return "红玉" end;return getShort(self,key,groupKey) end
 local remember=A.db.rememberFilters;A.db.rememberFilters=true
 local function Row(key) for _,row in ipairs(find.activities.rows) do if row.key==key then return row end end;error("missing activity row "..key) end
 local function Difficulty(id) for _,button in ipairs(find.difficultyButtons) do if button.value==id and button:IsShown() then button:Fire("OnClick");return end end;error("missing difficulty "..tostring(id)) end
 local function Check(key) if not find.multiSelectMode then find.multiSelectToggle:Fire("OnClick") end;Row(key).multiSelect:Fire("OnClick") end
 find:SelectCategory("seasonRaid")
 T.eq(Row(0).title:GetText(),"全部副本","the seasonal raid menu restores an explicit all-instances entry")
 find:SelectCategory("seasonDungeon")
 local before=calls
 T.eq(find.emptyText:GetText(),"请选择副本");T.eq(#find.results.ids,0,"a pending category cannot relabel the old result rows")
 Difficulty(8);T.eq(calls,before,"category and difficulty selection prepare a choice without searching")
 T.eq(Row(201).multiSelect:IsShown(),false);T.eq(Row(202).multiSelect:IsShown(),false,"checkboxes are hidden in the default single-selection view")
 T.eq(find.multiSelectToggle:GetParent(),Row(0));T.eq(find.multiSelectToggle.label:GetText(),"多选")
 find.multiSelectToggle:Fire("OnClick")
 T.eq(Row(201).multiSelect:IsShown(),true);T.eq(Row(202).multiSelect:IsShown(),true);T.eq(Row(203).multiSelect:IsShown(),false,"entering multi-selection only enables actual keystone rows")
 T.eq(calls,before,"entering multi-selection does not search")
 T.eq(find.pickerConfirm:IsShown(),false)
 local savedDifficulty=G.db.prefs.find.categoryPrefs.seasonDungeon.difficultyID
 find:ClosePicker();find:SelectCategory("seasonDungeon")
 T.eq(G.filters.difficultyID,savedDifficulty,"closing an unsubmitted choice restores the confirmed difficulty")
 Difficulty(8)
 Check(202);Check(201)
 T.eq(calls,before,"checkbox drafts do not send native searches")
 T.eq(G.filters.groupKeys,nil,"checkbox drafts do not change the active result filters")
 T.eq(find.pickerConfirm:IsShown(),true);T.eq(find.pickerConfirm:GetHeight(),40);T.eq(find.pickerConfirm.primary,true)
 Check(202);Check(201);T.eq(find.pickerConfirm:IsShown(),false,"unchecking the whole draft hides confirmation")
 Check(202);Check(201);find.pickerConfirm:Fire("OnClick")
 T.eq(calls,before+1);T.eq(lastActivity,nil,"confirming multiple dungeons submits one complete native search")
 T.same(G.filters.groupKeys,{[201]=true,[202]=true});T.eq(G.filters.groupKey,nil)
 T.eq(find.context:GetText(),"毒牙·红玉  ·  "..GetDifficultyInfo(8),"multi-selection titles use catalog order and short names")
 T.eq(find.draftGroupKeys,nil);T.eq(find.picker:IsShown(),false)
 find:SelectCategory("seasonDungeon");T.eq(calls,before+1,"reopening the active category never resubmits")
 T.eq(Row(201).multiSelect:IsShown(),false);T.eq(find.pickerConfirm:IsShown(),false,"reopening keeps the confirmed collection while hiding multi-selection controls")
 T.eq(find.activities.selectedKey,nil);T.eq(Row(0).selected:IsShown(),false,"a confirmed collection never highlights the all-instances single-selection row")
 T.eq(Row(201).multiSelect:GetChecked(),true);T.eq(Row(202).multiSelect:GetChecked(),true)
 T.eq(Row(201).multiSelect.mark:IsShown(),true)
 for _,stroke in ipairs(Row(201).multiSelect.mark.strokes) do T.same(stroke.fill,U.Theme.onPrimary,"the checkbox strokes use the untinted white foreground") end
 find.multiSelectToggle:Fire("OnClick");Row(202):Fire("OnClick","LeftButton")
 T.eq(Row(202).multiSelect:GetChecked(),false);T.eq(calls,before+1,"clicking an activity in multi-selection only toggles the draft")
 find.multiSelectToggle:Fire("OnClick")
 T.eq(Row(202).multiSelect:IsShown(),false);T.eq(find.pickerConfirm:IsShown(),false,"cancelling multi-selection hides the draft controls")
 find:ClosePicker();T.same(G.filters.groupKeys,{[201]=true,[202]=true},"cancelling discards checkbox edits")
 find:SelectCategory("seasonDungeon");T.eq(Row(202).multiSelect:GetChecked(),true,"reopening restores the active checks")
 Check(202);find.pickerConfirm:Fire("OnClick")
 T.same(G.filters.groupKeys,{[201]=true});T.eq(lastActivity,nil,"even one checked dungeon uses the complete-search multi-selection path")
 T.eq(find.context:GetText(),"毒牙洞窟  ·  "..GetDifficultyInfo(8),"a one-item collection retains the complete dungeon name")
 find:SelectCategory("seasonDungeon");Row(202):Fire("OnClick","LeftButton")
 T.eq(G.filters.groupKeys,nil);T.eq(G.filters.groupKey,202);T.eq(lastActivity,2002,"the row keeps its original single-selection request")
 local singleCalls=calls
 find:SelectCategory("seasonDungeon");T.eq(find.activities.selectedKey,202);T.eq(G.filters.difficultyID,8);T.eq(calls,singleCalls,"same-category reopening preserves the confirmed single selection and difficulty")
 find:SelectCategory("seasonRaid");find:SelectCategory("seasonDungeon")
 T.eq(G.filters.groupKey,202);T.eq(find.activities.selectedKey,202);T.eq(Row(202).selected:IsShown(),true,"returning from another category restores the seasonal single-selection highlight")
 T.eq(G.filters.difficultyID,8);T.eq(calls,singleCalls,"restoring a confirmed seasonal single selection still waits for an explicit search action")
 Row(0):Fire("OnClick","LeftButton");T.eq(G.filters.groupKey,nil);T.eq(G.filters.groupKeys,nil);T.eq(find.context:GetText(),"全部副本  ·  "..GetDifficultyInfo(8))
 find:SelectCategory("seasonDungeon");Check(201);Check(202);find.pickerConfirm:Fire("OnClick")
 local selectedCalls=calls
 G.Search.pending={categoryKey="seasonDungeon"};G.Search.timer=C_Timer.NewTimer(.2,function() calls=calls+100 end)
 find:SelectCategory("seasonRaid");T.eq(G.Search.pending,nil);T.eq(G.Search.timer,nil)
 f.base.AdvanceClock(.3);T.eq(calls,selectedCalls,"switching category cancels delayed native searches")
 find:SelectCategory("seasonDungeon");T.eq(calls,selectedCalls)
 T.same(G.filters.groupKeys,{[201]=true,[202]=true});T.eq(G.filters.difficultyID,8,"category restoration recovers only the confirmed keystone selection")
 T.ok(find.refresh:IsEnabled(),"restoring confirmed dungeons keeps manual refresh available")
 T.ok(not find.emptyPanel:IsShown() or find.emptyText:GetText()~="请选择副本","confirmed dungeons never render the unselected prompt")
 T.eq(Row(201).multiSelect:GetChecked(),true);T.eq(Row(202).multiSelect:GetChecked(),true)
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
 local saved=G.db.prefs.find.categoryPrefs.seasonDungeon
 saved.groupKey=nil;saved.groupKeys={[201]=true,[203]=true,[999]=true};saved.difficultyID=8
 find:SelectCategory("seasonRaid");find:SelectCategory("seasonDungeon")
 T.same(G.filters.groupKeys,{[201]=true},"restoration excludes removed groups and groups without the chosen keystone activity")
 Row(0):Fire("OnClick","LeftButton");Difficulty(false)
 local getCategories=catalog.GetCategories
 local activityGroups,activityLists,extraCategories={},{},{}
 local allLabels={[1]="全部任务",[4]="全部竞技场",[5]="全部竞技场练习赛",[6]="全部自定义活动",[121]="全部地下堡"}
 for _,entry in ipairs({{1,"任务"},{4,"竞技场"},{5,"竞技场练习赛"},{6,"自定义"},{9,"评级战场"},{121,"地下堡"}}) do
  local id,name=entry[1],entry[2];local key=tostring(id)
  extraCategories[#extraCategories+1]={key=key,id=id,name=name,icon="pvp"}
  local activity={id=9000+id,groupKey=900+id,categoryID=id,fixtureTier=1}
  activityLists[key]={activity};activityGroups[key]={{key=900+id,name="单个"..name,tier=1,activity=activity}}
 end
 local priorActivities,priorGroups=catalog.GetActivities,catalog.GetGroups
 catalog.GetCategories=function(self) local list={};for _,cat in ipairs(getCategories(self)) do list[#list+1]=cat end;for _,cat in ipairs(extraCategories) do list[#list+1]=cat end;return list end
 catalog.GetActivities=function(self,key) return activityLists[key] or priorActivities(self,key) end
 catalog.GetGroups=function(self,key) return activityGroups[key] or priorGroups(self,key) end
 for _,id in ipairs({1,4,5,6,121}) do
  find:SelectCategory(tostring(id));local unopenedCalls=calls
  T.eq(find.emptyText:GetText(),"请选择活动");T.ok(find.emptyHelp:GetText():find(allLabels[id],1,true),"pending non-dungeon copy names the matching all-activity choice")
  T.eq(Row(0).title:GetText(),allLabels[id],"all-activity rows name their own activity category")
  T.eq(#find.activityIDs,2,"other one-item categories retain their all-activity choice")
  Row(0):Fire("OnClick","LeftButton")
  T.eq(calls,unopenedCalls+1);T.eq(find.context:GetText(),allLabels[id],"selecting all activities keeps the full category name in the result title")
 end
 find:SelectCategory("9");local ratedCalls=calls
 T.same(find.activityIDs,{909},"rated battlegrounds alone omit the redundant all-activities row")
 T.eq(calls,ratedCalls);Row(909):Fire("OnClick","LeftButton");T.eq(calls,ratedCalls+1);T.eq(lastActivity,9009)
 find:SelectCategory("seasonRaid");catalog.GetCategories=getCategories
 catalog.GetActivities,catalog.GetGroups,catalog.GetActivityTier,catalog.GetGroupShortName=getActivities,getGroups,getTier,getShort
 G.Search.Search=search;A.db.rememberFilters=remember
 find:SelectCategory("seasonRaid");find:SelectCategory("seasonDungeon");Row(0):Fire("OnClick","LeftButton")
end
find:SelectCategory("seasonDungeon");find:ClosePicker()
T.eq(find.appList.rows[1].key,101,"applications survive the browse result selection")
T.eq(find.appList.rows[1].status:GetText(),"5:00")
do
 local row=find.appList.rows[1]
 T.ok(row.leaderIcon:IsShown(),"my applications show the leader crown")
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
find:DoSearch();T.eq(G.state,"done")
local target=find.results.rows[1]
do
 local r=G.records[target.key]
 local fields={"categoryID","maxNumPlayers","numMembers","leaderRating","ratingKind","age","requiredItemLevel","details"};local saved={}
 for _,key in ipairs(fields) do saved[key]=r[key] end
 local function Geometry(region) local p={region:GetPoint()};return {anchor=p[1],x=p[#p-1],y=p[#p],width=region:GetWidth(),height=region:GetHeight()} end
 local function Render() G:Notify("result",r.id);U.Motion:Tick(.016) end
 local body=target:GetWidth()
 T.eq(Geometry(target.leader).x,body-495,"the leader leaves room for independent data columns")
 T.eq(target.leader:GetWidth(),91);T.eq(Geometry(target.leaderIcon).x,body-512)
 T.eq(Geometry(find.resultHeadings.title).x,Geometry(target.icon).x,"the group heading aligns with the activity icon's left edge")
 T.eq(target.ratingLabel,nil,"score labels appear once in the column header")
 T.eq(target.ilvlLabel,nil,"item-level labels do not repeat in every result")
 for key,region in pairs({leader=target.leader,rating=target.score,ilvl=target.ilvl,members=target.count,age=target.age}) do
  T.eq(Geometry(region).x,Geometry(find.resultHeadings[key]).x,"data shares its header's column")
  T.eq(region:GetWidth(),find.resultHeadings[key]:GetWidth())
 end
 for _,region in ipairs({target.leader,target.score,target.ilvl,target.age}) do T.eq(Geometry(region).y,0,"single-line values share the row center") end
 T.eq(target.score.justify,"CENTER");T.eq(target.ilvl.justify,"CENTER")
 T.ok(Geometry(target.score).x+target.score:GetWidth()+20<=Geometry(target.ilvl).x)
 T.ok(Geometry(target.ilvl).x+target.ilvl:GetWidth()+20<=Geometry(target.count).x)
 T.ok(Geometry(target.count).x+target.count:GetWidth()+20<=Geometry(target.age).x)
 T.eq(Geometry(find.resultsHeader).y-find.resultsHeader:GetHeight()-Geometry(find.results).y,12,"the single header has a clear gap above the first row")
 local getSpecInfo=GetSpecializationInfoByID
 _G.GetSpecializationInfoByID=function(id) return id,"Spec "..id,nil,200000+id end
 local members={{name="One",nameKey="One-Away",class="WARRIOR",assignedRole="TANK",specID=71}}
 r.categoryID=2;r.maxNumPlayers=5;r.numMembers=1;r.age=10;r.leaderRating=2500;r.requiredItemLevel=320;r.ratingKind=nil
 r.details={members=members,counts={TANK=1,HEALER=0,DAMAGER=0},encounters={}};Render()
 local roster,count,age,score=Geometry(target.roster),Geometry(target.count),Geometry(target.age),Geometry(target.score)
 T.eq(roster.anchor,"CENTER");T.eq(Geometry(target.membersButton).x,count.x);T.eq(Geometry(target.membersButton).y,0)
 T.eq(target.count:IsShown(),false,"member totals are hidden until the role summary is clicked")
 T.eq(target.roster.slots[1].icon:IsShown(),true);T.eq(target.roster.slots[1].icon:GetTexture(),200071,"a party result shows its member's specialization")
 T.eq(target.roster.counts[1].text:IsShown(),false,"party rows use individual specializations rather than aggregate role counts")
 target:Fire("OnClick","LeftButton");T.eq(target.count:IsShown(),false,"ordinary row clicks do not expand member totals")
 target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),false);T.eq(target.count:GetText(),"","party slots never reveal a redundant N/N counter")
 T.eq(Geometry(target.membersButton).y,0)
 target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),false)
 for i,role in ipairs({"TANK","HEALER","DAMAGER","DAMAGER","DAMAGER"}) do
  local slot=target.roster.slots[i]
  T.eq(slot.role:IsShown(),true,"empty party slots retain a role placeholder")
  T.eq(slot.role:GetTexture(),U.Theme.media..({TANK="role-tank",HEALER="role-healer",DAMAGER="role-dps"})[role]..".tga")
  T.eq(slot.icon:IsShown(),i==1,"only the occupied slot shows a specialization")
 end
 T.eq(count.width,138);T.eq(age.width,76)
 members[1]={name="Damage1",class="MAGE",assignedRole="DAMAGER",specID=63}
 members[2]={name="Tank",class="WARRIOR",assignedRole="TANK",specID=71}
 members[3]={name="Damage2",class="MAGE",assignedRole="DAMAGER",specID=62}
 members[4]={name="Healer",class="PRIEST",assignedRole="HEALER",specID=257}
 members[5]={name="Damage3",class="MAGE",assignedRole="DAMAGER",specID=64}
 r.numMembers=5;r.age=99*86400;r.leaderRating=nil;Render()
 T.eq(Geometry(target.roster).x,roster.x,"one to five members share the membership column center")
 T.eq(target.roster:GetWidth(),132,"party and raid role summaries use the same width")
 T.same(Geometry(target.count),count,"member totals retain their fixed position")
 T.same(Geometry(target.age),age,"longer time text does not resize the time column")
 T.same(Geometry(target.score),score,"unknown scores retain the same numeric column")
 T.ok(target.score:GetStringWidth()<=target.score:GetWidth(),"the complete unknown-score label fits")
 for i,spec in ipairs({71,257,63,62,64}) do
  T.eq(target.roster.slots[i].icon:IsShown(),true)
  T.eq(target.roster.slots[i].icon:GetTexture(),200000+spec,"unordered party members render tank, healer, then damage in stable order")
 end
 T.eq(members[1].specID,63,"rendering preserves provider member order")
 r.categoryID=3;r.maxNumPlayers=40;r.numMembers=40;r.details.counts={TANK=2,HEALER=8,DAMAGER=30};Render()
 T.eq(Geometry(target.roster).x,roster.x,"raid composition shares the membership column center")
 T.eq(target.roster:GetWidth(),132,"raid roles are centered without a trailing column gap")
 T.eq(target.roster.slots[1].icon:IsShown(),false,"raid rows switch back to aggregate role counts")
 T.eq(target.roster.counts[1].text:GetText(),"2");T.eq(target.roster.counts[2].text:GetText(),"8");T.eq(target.roster.counts[3].text:GetText(),"30")
 target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),true);T.eq(target.count:GetText(),"40/40","raid results keep their member counter")
 target.membersButton:Fire("OnClick")
 local roleColumns={}
 for i,item in ipairs(target.roster.counts) do
  roleColumns[i]=Geometry(item.icon);T.eq(roleColumns[i].x,(i-1)*46);T.eq(item.text:GetWidth(),20)
  T.eq(item.text.justify,"LEFT");T.eq(Geometry(item.text).x,roleColumns[i].x+20,"each role count sits four units after its own icon")
 end
 r.details.counts={TANK=10,HEALER=10,DAMAGER=20};Render()
 for i,item in ipairs(target.roster.counts) do T.same(Geometry(item.icon),roleColumns[i],"two-digit role counts never move later columns") end
 r.categoryID=4;r.ratingKind="pvp";r.leaderRating=0;Render()
 T.eq(find.resultHeadings.rating:GetText(),"评分","PvP uses the shared score column")
 T.eq(target.score:GetText(),"暂无分数");T.ok(target.score:GetStringWidth()<=target.score:GetWidth())
 _G.GetSpecializationInfoByID=getSpecInfo
 for _,key in ipairs(fields) do r[key]=saved[key] end;Render()
end
do
 local r=G.records[target.key]
 r.bnetFriends=1;r.charFriends=0;G:Notify("result",r.id);U.Motion:Tick(.016)
 T.ok(target.meta:GetText():find("战网好友",1,true),"战网计数显示战网好友标签")
 T.eq(target.meta:GetText():find("角色好友",1,true),nil,"战网好友不冒充角色好友")
 r.charFriends=1;G:Notify("result",r.id);U.Motion:Tick(.016)
 T.ok(target.meta:GetText():find("角色好友",1,true),"两种好友关系可以同时出现")
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
 r.leaderRating=0;U.Tooltip:RenderGroup();T.eq(U.Tooltip.interactive.metrics[1].value:GetText(),"暂无分数","明确零分不套大秘境评分颜色")
 r.leaderRating=nil;U.Tooltip:RenderGroup();T.eq(U.Tooltip.interactive.metrics[1].value:GetText(),"未知分数","缺少PvP分不回退大秘境分")
 local over=find.results.clip.IsMouseOver;find.results.clip.IsMouseOver=function() return true end
 U.Tooltip:Hide();target:Fire("OnEnter");T.eq(U.Tooltip.owner,nil,"结果行右侧不触发提示")
 target.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.owner,target,"图标与队名区域触发完整队伍提示")
 T.eq(find.results.tooltipFraction,.25);T.eq(target.tooltipArea:GetWidth(),target:GetWidth()*.25,"结果提示仅在列表左侧四分之一激活")
 T.eq(target.tooltipArea.mouseEnabled,false,"the tooltip area never intercepts the row's click after scripts are assigned")
 T.eq(target.tooltipArea.mouseMotionEnabled,true,"the tooltip area keeps hover events")
 target.mouseOver=true;target.tooltipArea.mouseOver=false;target.tooltipArea:Fire("OnLeave");U.Motion:Tick(.25)
 T.eq(U.Tooltip.owner,nil,"鼠标仍在整行右侧时也收起未固定提示")
 target.mouseOver=nil;find.results.clip.IsMouseOver=over
 r.ratingKind=nil;r.leaderRating=score;r.requiredRating=nil;r.pvpRatingActivity=nil;r.pvpRatings=nil;r.maxNumPlayers=5
 G:Notify("result",r.id);U.Motion:Tick(.016)
end
target.membersButton:Fire("OnClick");T.eq(target.count:IsShown(),false)
find:OnResultSelect(target.key,"LeftButton",target)
local firstFocusBackground
local noteBox=LFGListApplicationDialog.Description.EditBox
local nativeNoteFocus=noteBox:GetScript("OnEditFocusGained")
noteBox:SetScript("OnEditFocusGained",function(box)
 if nativeNoteFocus then nativeNoteFocus(box) end
 if not firstFocusBackground then
  firstFocusBackground=box:CreateTexture(nil,"BACKGROUND");firstFocusBackground:SetAllPoints();firstFocusBackground:SetColorTexture(0,0,0,.9)
 end
end)
find.main:Fire("OnKeyDown","ENTER");T.eq(U.Native.applicationLease.id,target.key);T.eq(G.clearedApplication,nil,"opening configuration keeps the engine's current note")
T.eq(firstFocusBackground:IsShown(),false,"native art created on first application focus stays behind the shared input surface");T.eq(firstFocusBackground:GetAlpha(),0)
local savedApps=G.apps
G.apps={savedApps[1]}
for i=2,5 do G.apps[i]={id=900+i,name="Other category "..i,leaderName="Other-Away",categoryID=3,status=i==5 and "invited" or "applied"} end
local previousID=LFGListApplicationDialog.resultID
A.db.reduceMotion=false
U.Native:Apply(102)
T.ok(find.limitNotice:IsShown(),"the sixth application explains the cap beside the primary action")
T.ok(find.limitNotice:GetHeight()>=40)
T.eq(find.limitText.justify,"LEFT","notice text has an explicit left alignment")
T.eq(find.limitNotice:GetWidth(),find.results.rows[1]:GetWidth(),"notice and result body share their left and right edges")
local noticeAnimation=U.Motion.jobs[find.limitNotice]
T.ok(noticeAnimation,"the user action animates the inline notice")
G:Notify("applications");T.eq(U.Motion.jobs[find.limitNotice],noticeAnimation,"passive native updates do not replay the notice")
T.eq(find.scopeToggle:GetWidth(),find.scopeToggle.label:GetWidth()+24,"scope buttons use symmetric horizontal padding")
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
T.eq(find.continueApplication:IsEnabled(),false,"cancellation waits for a native status event")
G.apps[2].status="cancelled";G:Notify("applications")
T.eq(find.continueApplication:IsEnabled(),true)
T.eq(LFGListApplicationDialog.resultID,previousID,"freeing a slot does not auto apply")
do
 local search,calls=G.Search.Search,0
 G.Search.Search=function(self,...) calls=calls+1;return search(self,...) end
 G.apps[1].status="cancelled";G:Notify("applicationCancelled",101);G:Notify("applications")
 T.eq(calls,0,"freeing a slot keeps the pending application's original result ID")
 T.eq(find.continueApplication:IsEnabled(),true)
 G.Search.Search=search;G.apps[1].status="applied";G:Notify("applications")
end
find.continueApplication:Fire("OnClick");T.eq(U.Native.applicationLease.id,102,"continuing configures the original target when no role has been confirmed yet")
G.apps[2].status="applied";U.Native:Apply(102)
f.base.AdvanceClock(6.4);G:Notify("applications");f.base.AdvanceClock(.11)
T.eq(find.limitNotice:IsShown(),true,"the pending target and notice remain after 6.5 seconds")
G:Notify("applications");T.eq(find.limitNotice:IsShown(),true,"passive updates retain the pending application")
G.apps[2].status="cancelled";G:Notify("applications");find.continueApplication:Fire("OnClick")
T.eq(U.Native.applicationLease.id,102,"a slot released after the old timeout still continues the original target")
G.apps[2].status="applied"
U.Native:Apply(102);find.closeApplicationNotice:Fire("OnClick");G:Notify("applications")
T.eq(find.limitNotice:IsShown(),false,"the notice can be dismissed without passive reopening")
G.apps=savedApps;find.scopeToggle:Fire("OnClick");G:Notify("applications")
do
 local ended={id=902,name="Expired application",status="timedout",categoryID=2,result=G.records[102]}
 G.apps[#G.apps+1]=ended;find:RefreshApplications()
 T.eq(#find.appList.ids,1,"expired applications disappear immediately from the current category")
 local row=find.appList.rows[1];find.appList.clip.mouseOver=true;U.Tooltip:Hide();row:Fire("OnEnter")
 T.eq(U.Tooltip.owner,nil,"pinned application statistics do not trigger a whole-row tooltip")
 row.tooltipArea:Fire("OnEnter");T.eq(U.Tooltip.owner,row,"pinned application details activate in the left quarter")
 T.eq(find.appList.tooltipFraction,.25);T.eq(row.tooltipArea:GetWidth(),row:GetWidth()*.25)
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
 T.eq(U.Native:IsAutoApplyEnabled(),false,"automatic application starts disabled for this login")
 T.eq(find.autoApply.value,false);T.eq(find.autoApply:GetWidth(),44,"only the actual track is a toggle target")
 T.eq(find.applicationRoles,nil,"header role shortcuts are removed")
 find.applicationSettings:Fire("OnClick");T.eq(U.activeModal,nil,"the disabled text cannot bypass enabling configuration")
 T.eq(target.key,102);target:Fire("OnDoubleClick","LeftButton");T.eq(dialog.submissions,before,"a disabled double click opens a temporary confirmation")
 T.eq(U.Native.applicationLease.id,102);T.eq(dialog.Description:GetParent(),U.Native.applicationModal.note)
 T.eq(U.Native.applicationLease.roles.TANK,true,"first confirmation prefers the current specialization")
 T.eq(U.Native:GetApplicationRoles(),nil,"preselection does not confirm saved automatic roles")
 U:CloseModal();T.eq(dialog.submissions,before)
 _G.GetSpecializationRole=function() return "HEALER" end
 find:Apply(102);T.eq(U.Native.applicationLease.roles.DAMAGER,true,"an unavailable specialization falls back to an available queue role")
 U:CloseModal();_G.GetSpecializationRole=function() return "TANK" end
 find:Apply(102)
 dialog.Description.EditBox:UserType("Temporary native note")
 U.Native.applicationModal.roles.DAMAGER:Fire("OnClick");U.Native.applicationModal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+1);T.eq(dialog.submitted.note,"Temporary native note")
 T.eq(dialog.submitted.tank,true);T.eq(dialog.submitted.damage,true,"manual confirmation preserves multiple selected roles")
 T.eq(G.applyCalls,1,"temporary confirmation submits through the business Apply entry")
 T.eq(U.Native:IsAutoApplyEnabled(),false);T.eq(U.Native:GetApplicationRoles(),nil,"temporary application does not configure automatic roles")
 T.eq(U.activeModal,nil);T.eq(dialog.Description:GetParent(),dialog);T.eq(dialog.Description.EditBox:GetParent(),noteParent)
 T.eq(dialog.SignUpButton:GetScript("OnClick"),originalSubmit);T.eq(dialog:GetScript("OnEvent"),originalEvent)
 T.same({dialog.Description.EditBox:GetFont()},noteFont,"releasing restores the original native text presentation")
 find.main:Fire("OnKeyDown","ENTER");T.eq(dialog.submissions,before+1,"Enter still requires confirmation while automatic application is off")
 T.eq(U.Native.applicationLease.id,102);U:CloseModal()
 find.autoApply:Fire("OnClick")
 T.eq(find.autoApply.value,false,"the switch stays off while its configuration is pending")
 T.eq(U.Native.applicationLease.id,nil)
 T.eq(U.Native.applicationModal.group:IsShown(),false,"configuration has no retired explanation or empty group row")
 T.eq(({U.Native.applicationModal.roleLabel:GetPoint()})[3],0,"roles start at the content edge after removing the help text")
 U:CloseModal();T.eq(U.Native:IsAutoApplyEnabled(),false,"cancelling activation leaves the feature off")
 find.autoApply:Fire("OnClick")
 local modal=U.Native.applicationModal
 modal.roles.TANK:Fire("OnClick")
 T.eq(modal.submit:IsEnabled(),false,"activation cannot save an empty role selection")
 modal.submit:Fire("OnClick");T.eq(U.Native:IsAutoApplyEnabled(),false)
 modal.roles.DAMAGER:Fire("OnClick");modal.roles.TANK:Fire("OnClick")
 T.eq(modal.roles.TANK.active,true);T.eq(modal.roles.DAMAGER.active,true)
 dialog.Description.EditBox:UserType("A reusable native note");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+1,"saving activation does not submit a group application")
 T.eq(U.Native:IsAutoApplyEnabled(),true);T.eq(find.autoApply.value,true)
 T.same(U.Native:GetApplicationRoles(),{TANK=true,DAMAGER=true})
 T.eq(LycheeGroupDB.autoApply,nil,"automatic application preferences remain session only")
 local activity=G.records[102].activityID;G.records[102].activityID=1
 target:Fire("OnDoubleClick","LeftButton");T.eq(dialog.submissions,before+2,"an enabled double click reuses the configured input directly")
 T.eq(dialog.submitted.tank,true);T.eq(dialog.submitted.damage,true,"quick submission retains the complete multi-role selection")
 T.eq(dialog.submitted.note,"A reusable native note");T.eq(U.activeModal,nil);T.eq(G.clearedApplication,nil)
 G.records[102].activityID=activity
 find.main:Fire("OnKeyDown","ENTER");T.eq(dialog.submissions,before+3,"enabled Enter follows the configured quick path")
 find.applicationSettings:Fire("OnEnter")
 T.same(find.applicationSettings.label.color,U.Theme.brand,"the separate settings text uses brand color on hover")
 T.eq(find.applicationSettings.hover:IsShown(),false,"the settings text has no surrounding hover surface")
 find.applicationSettings:Fire("OnLeave");find.applicationSettings:Fire("OnClick")
 T.eq(U.Native:IsAutoApplyEnabled(),true,"clicking the text edits without toggling")
 T.eq(U.Native.applicationLease.id,nil);T.eq(modal.submit.label:GetText(),U.L.save)
 dialog.Description.EditBox:UserType("Updated native note");modal.roles.DAMAGER:Fire("OnClick");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+3);T.same(U.Native:GetApplicationRoles(),{TANK=true})
 find:OpenResultMenu(find.results,102)
 local menu=U.context.menu;T.eq(menu.items[1].label,"编辑后申请")
 menu.list.rows[1]:Fire("OnClick","LeftButton")
 T.eq(dialog.submissions,before+3,"the context menu always waits for confirmation")
 T.eq(U.Native.applicationLease.id,102);T.eq(modal.submit.label:GetText(),"申请")
 dialog.Description.EditBox:UserType("Manual application note")
 modal.roles.DAMAGER:Fire("OnClick");modal.roles.TANK:Fire("OnClick");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+4);T.eq(dialog.submitted.note,"Manual application note")
 T.eq(dialog.submitted.damage,true);T.eq(dialog.submitted.tank,false)
 T.same(U.Native:GetApplicationRoles(),{TANK=true},"manual application does not replace the automatic role configuration")
 dialog.Description.EditBox:UserType("Updated native note")
 dialog.available.TANK=false;find:Apply(102)
 T.eq(dialog.submissions,before+4,"an unavailable remembered role cannot be submitted")
 T.eq(modal.submit:IsEnabled(),false)
 modal.roles.DAMAGER:Fire("OnClick");modal.submit:Fire("OnClick")
 T.eq(dialog.submissions,before+5);T.eq(dialog.submitted.damage,true)
 dialog.available.TANK=true
 find.autoApply:Fire("OnClick");T.eq(U.Native:IsAutoApplyEnabled(),false)
 find:Apply(102);T.eq(dialog.submissions,before+5,"turning the switch off immediately restores confirmation")
 T.eq(U.Native.applicationLease.id,102);U:CloseModal()
 find.autoApply:Fire("OnClick");modal.submit:Fire("OnClick")
 T.eq(U.Native:IsAutoApplyEnabled(),true,"reenabling requires saving configuration again")
 _G.GetSpecializationRole=function() return "DAMAGER" end
 find.applicationSettings:Fire("OnClick")
 T.eq(U.Native.applicationLease.roles.TANK,true,"editing retains explicitly saved roles across specialization changes")
 local foreign=CreateFrame("Frame",nil,UIParent);dialog.Description:SetParent(foreign);dialog.Description:SetHeight(40)
 T.eq(U.Native.applicationLease,nil);T.eq(dialog.Description:GetParent(),foreign,"lease release preserves an external owner's layout")
 T.eq(U.activeModal,nil);dialog.Description:SetParent(dialog);dialog.Description:SetSize(210,28)
 T.same({GetLFGRoles()},roles,"temporary and automatic applications leave dungeon finder roles unchanged")
 local nativeApply=C_LFGList.ApplyToGroup;C_LFGList.ApplyToGroup=function() error("Rejected by client") end
 find:Apply(102);T.eq(find.limitText:GetText(),G.L.applyFailed,"client rejection is reported beside the application controls")
 C_LFGList.ApplyToGroup=nativeApply
 local priorApps=G.apps;G.apps={}
 for i=1,5 do G.apps[i]={id=900+i,name="Pending "..i,categoryID=3,status="applied"} end
 local submitted=dialog.submissions
 find:Apply(102,true);G.apps[1].status="cancelled";G:Notify("applications")
 find.continueApplication:Fire("OnClick")
 T.eq(dialog.submissions,submitted,"continuing Edit and apply still waits for confirmation")
 T.eq(U.Native.applicationLease.id,102);T.eq(U.Native.applicationModal.submit.label:GetText(),"申请")
 U:CloseModal()
 G.apps[1].status="applied";find:Apply(102)
 local pendingRecord=G.records[102];G.records[102]=nil;G.apps[1].status="cancelled";G:Notify("applications")
 find.continueApplication:Fire("OnClick")
 T.eq(find.limitText:GetText(),U.L.unavailable,"continuing a vanished target gives a visible explanation")
 T.eq(dialog.submissions,submitted)
 G.records[102]=pendingRecord;G.apps=priorApps;G:Notify("applications")
 _G.GetSpecialization,_G.GetSpecializationRole=getSpec,getSpecRole
 _G.SetLFGRoles=setRoles
end
U.Tooltip:ShowGroup(target,G.records[target.key])
T.ok(U.Tooltip.interactive:IsShown());T.eq(U.Tooltip.interactive:GetWidth(),424)
U.Tooltip.interactive.memberButtons[1]:Fire("OnClick")
T.eq(U.Tooltip.member,members[1],"a member opens inside the shared group tooltip")
T.ok(U.Tooltip.interactive.back:IsShown());T.ok(U.Tooltip.interactive.comment:GetText():find("A different experience",1,true))
U.Tooltip.interactive.wcl:Fire("OnClick");T.ok(U.copyDialog.field.box:GetText():find("/Away/Guest",1,true),"WCL link uses the complete known identity")
T.eq(U.copyDialog.fieldLabel:GetText(),"角色链接","WCL restores its default field label after copying other addon links")
U.copyDialog:Hide();U.Tooltip.interactive.back:Fire("OnClick");T.eq(U.Tooltip.member,nil)
U.Tooltip:Hide()
do
 local tip=U.Tooltip
 local left,top=U.frame.GetLeft,U.frame.GetTop
 U.frame.GetLeft=function() return 400 end;U.frame.GetTop=function() return 960 end
 local surface=tip.interactive;surface:SetSize(424,240)
 tip.pointX,tip.pointY=1000,100;tip:Position(surface)
 T.eq(tip.positionX,1020,"tooltip may extend past the main window on the cursor's right")
 T.eq(tip.positionY,116,"tooltip leaves a visible gap below the pointer")
 tip.pointX,tip.pointY=1480,930;tip:Position(surface)
 T.eq(tip.positionX,1036,"the screen edge flips the tooltip to the pointer's left")
 T.eq(tip.positionY,674,"bottom-edge placement flips above the pointer")
 tip.pinned=true;tip.pointX,tip.pointY=500,100;tip:Position(surface)
 T.eq(tip.positionX,1036,"a pinned member detail remains reachable while the pointer moves")
 U.frame.GetLeft,U.frame.GetTop=left,top;tip:Hide()
end
local raidMembers={}
for i=1,30 do raidMembers[i]={name="Raider"..i.."-Away",nameKey="Raider"..i.."-Away",class="WARRIOR",specID=71,assignedRole="DAMAGER"} end
raidMembers[30].isLeader=true;raidMembers[2].assignedRole="TANK";raidMembers[3].assignedRole="HEALER"
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
A.db.raidMembers="shift"
U.Tooltip:ShowGroup(target,raid);T.eq(U.Tooltip.interactive:GetWidth(),640)
T.ok(U.Tooltip.interactive.bossText:IsShown(),"an unavailable journal is displayed as unknown")
journalReady=true;U.Tooltip:RenderGroup()
T.ok(U.Tooltip.interactive.bossText:IsShown(),"missing progress is explained once instead of repeating unknown for every boss")
T.eq(journalInstance,22,"reading a raid directory restores the previously selected native instance");T.eq(journalDifficulty,14,"reading a raid directory restores the previous difficulty")
T.eq(U.Tooltip.interactive.bossText:GetText(),"队伍未提供首领进度","an available directory does not invent missing progress")
T.eq(U:ProgressText(raid,raid.details),"—","unavailable native progress stays absent, not zero")
raid.details.encounters={"Boss A"}
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",1)
T.eq(U.Tooltip.interactive:GetWidth(),960);T.ok(U.Tooltip.interactive.memberButtons[30]:IsShown(),"Shift exposes the entire native raid roster")
T.eq(#U.Tooltip.interactive.memberButtons,30,"the member pool grows only to the roster actually opened")
T.eq(U.Tooltip.interactive.memberButtons[1].member,raidMembers[30],"the native raid leader is always first")
U.Tooltip.interactive.memberButtons[1]:Fire("OnEnter");U.Motion:Tick(.12)
T.near(U.Tooltip.interactive.memberButtons[1].hover.regions[1]:GetAlpha(),13/255,.001,"expanded members use the shared subtle hover layer")
U.Tooltip.interactive.memberButtons[1]:Fire("OnLeave")
T.eq(U.Tooltip.interactive.memberButtons[2].member,raidMembers[2]);T.eq(U.Tooltip.interactive.memberButtons[3].member,raidMembers[3])
T.ok(U.Tooltip.interactive.memberButtons[2].realm:GetText():find("角色好友",1,true),"Shift 名单直接指出好友成员")
T.eq((U.Tooltip.interactive.memberButtons[1].name:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")),"Raider30-Away");T.eq(U.Tooltip.interactive.memberButtons[1]:GetHeight(),60)
T.eq(U.Tooltip.interactive.memberButtons[1].name.wrap,true,"long name-realm text stays within its member cell");T.eq(select(2,U.Tooltip.interactive.memberButtons[2].icon:GetPoint()),8,"member hover has equal horizontal padding");T.ok(U.Tooltip.interactive.memberButtons[1].name:GetWidth()<U.Tooltip.interactive.memberButtons[1]:GetWidth()-56,"leader crown and role keep their own space")
T.ok(U.Tooltip.interactive.leaderIcon:IsShown(),"the right-aligned header uses a leader icon beside the name")
T.ok(U.Tooltip.interactive.memberButtons[1].leaderIcon:IsShown());T.eq(U.Tooltip.interactive.memberButtons[2].leaderIcon:IsShown(),false)
T.eq(U.Tooltip.interactive.bossRows[1].status:GetText(),"已击败");T.eq(U.Tooltip.interactive.bossRows[2].status:GetText(),"未击败")
T.eq(U.Tooltip.interactive.bossCount:GetText(),"1/3");T.eq(U.Tooltip.interactive.bossRows[3].name:GetText(),"Boss C")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",0)
T.eq(U.Tooltip.interactive:GetWidth(),960,"releasing Shift keeps the toggled expanded state")
U.Tooltip.interactive:Fire("OnEnter")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","RSHIFT",1)
T.eq(U.Tooltip.interactive:GetWidth(),640,"another Shift press collapses even while the pointer is inside the tooltip")
T.eq(U.Tooltip.interactive.memberButtons[30]:IsShown(),false,"collapsing hides the expanded roster")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","RSHIFT",0)
T.eq(U.Tooltip.interactive:GetWidth(),640,"releasing Shift keeps the summary state")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",1)
U.Tooltip.interactive.memberButtons[1]:Fire("OnClick")
T.eq(U.Tooltip.member,raidMembers[30])
T.eq(U.Tooltip.outsideClicks:IsMouseEnabled(),false);T.eq(U.Tooltip.outsideClicks:GetScript("OnMouseDown"),nil)
T.eq(U.Tooltip.outsideClicks.events.GLOBAL_MOUSE_DOWN,true,"pinned details observe global clicks without taking mouse input")
U.Tooltip.interactive.mouseOver=true;U.Tooltip.outsideClicks:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
T.eq(U.Tooltip.interactive:IsShown(),true,"an internal click retains pinned details");U.Tooltip.interactive.mouseOver=nil
U.Tooltip.interactive.back:Fire("OnClick")
T.eq(U.Tooltip.interactive:GetWidth(),960,"returning from a member preserves the source raid's expanded state")
T.eq(U.Tooltip.outsideClicks.events.GLOBAL_MOUSE_DOWN,true,"returning to the pinned source group retains outside-click dismissal")
U.Tooltip:RenderPlayer(raidMembers[30],true);U.Tooltip.outsideClicks:Fire("OnEvent","GLOBAL_MOUSE_DOWN","LeftButton")
T.eq(U.Tooltip.interactive:IsShown(),false,"an external click closes pinned details")
T.eq(U.Tooltip.outsideClicks.events.GLOBAL_MOUSE_DOWN,nil)
U.Tooltip:Hide();A.db.raidMembers="always";U.Tooltip:ShowGroup(target,raid)
T.eq(U.Tooltip.interactive:GetWidth(),960,"the always setting opens the full roster")
U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",1)
T.eq(U.Tooltip.interactive:GetWidth(),960,"Shift does not collapse the always setting")
A.db.raidMembers="shift"
A.db.reduceMotion=false
local tipScroll=U.Tooltip.interactive.scroll
tipScroll:Fire("OnMouseWheel",-1);T.ok(U.Motion.jobs[tipScroll],"tooltip wheel scrolling uses the shared finite motion driver")
U.Motion:Tick(.07);T.ok(tipScroll:GetVerticalScroll()>0 and tipScroll:GetVerticalScroll()<42,"tooltip wheel movement is interpolated")
U.Tooltip:Hide();T.eq(U.Tooltip.interactive.memberButtons[30].member,nil,"closing releases member bindings")
T.eq(U.Motion.jobs[tipScroll],nil,"tooltip hide stops its scroll interpolation")
do
 local buttons=U.Tooltip.interactive.memberButtons;local first=buttons[1]
 for i=31,40 do raidMembers[i]={name="Raider"..i.."-Away",nameKey="Raider"..i.."-Away",class="WARRIOR",assignedRole="DAMAGER"} end
 raid.numMembers,raid.maxNumPlayers=40,40;A.db.raidMembers="always"
 U.Tooltip:ShowGroup(target,raid)
 T.eq(#buttons,40,"opening a larger raid expands the existing member pool")
 T.eq(buttons[40].member,raidMembers[40]);T.ok(buttons[40]:IsVisible(),"the full forty-player roster remains accessible")
 local nodes=#S.nodes;U.Tooltip:Hide();U.Tooltip:ShowGroup(target,raid)
 T.eq(#S.nodes,nodes,"reopening a roster reuses its native object high-water mark");T.eq(buttons[1],first)
 U.Tooltip:Hide();T.eq(buttons[40].member,nil,"closing clears newly grown member bindings too")
 for i=40,31,-1 do raidMembers[i]=nil end
 raid.numMembers,raid.maxNumPlayers=30,30;A.db.raidMembers="shift"
end
U.Tooltip:ShowGroup(target,raid);T.eq(U.Tooltip.interactive:GetWidth(),640,"a new tooltip starts in summary mode");U.Tooltip:LeaveOwner(target);U.Motion:Tick(.23)
T.eq(U.Tooltip.interactive:IsShown(),false,"leaving both owner and tooltip closes it through the native region mouse query")
T.eq(U.Motion.jobs[U.Tooltip],nil,"tooltip leave delay releases its motion job")
find.results:SetPixelOffset(11*72,false);T.eq(find.results.rows[1].key,113,"pixel scrolling reaches results beyond the visible pool without reintroducing an applied result")
local poolSize=#S.nodes
find.results:SetPixelOffset(20*72,false);find.results:SetPixelOffset(0,false)
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
find:SetFiltersOpen(true);T.ok(U.Motion.jobs[find.filterPanel]);find:SetFiltersOpen(false);T.eq(U.Motion.jobs[find.filterPanel],nil)
find:SelectCategory("seasonDungeon");T.ok(U.Motion.jobs[find.picker]);find:ClosePicker();T.eq(U.Motion.jobs[find.picker],nil)
A.db.reduceMotion=false;G.state="searching";find:ReadSearchState();T.ok(U.Motion.jobs[find.busyIcon],"only an active search animates the lychee")
find:ShowApplicationLimit(102);local closingRecords=G.records
U:Hide(true);T.eq(next(U.Motion.jobs),nil,"closing releases scroll, tooltip, countdown and waiting jobs")
T.eq(find.limitNotice:IsShown(),false,"leaving clears the pending application notice")
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
A.db.reduceMotion=false;A:Open("find");G.records=closingRecords;find:RefreshResults();U.Motion:Tick(.5)
local closingRow=find.results.rows[1];local closingTitle=closingRow.title:GetText()
T.ok(closingRow.key and closingRow:IsShown(),"close coverage starts from a real populated result row")
U:Hide();T.eq(U.hiding,true);T.eq(closingRow:IsShown(),true,"closing preserves visible row bindings during Presence")
T.eq(closingRow.title:GetText(),closingTitle);T.eq(U.frame:IsShown(),true)
U.Motion:Tick(.43);T.eq(U.frame:IsShown(),false);T.eq(next(G.views),nil);T.eq(U.Native.searchLease,nil,"the completed close releases browsing and native input ownership")
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
 settings.back:Fire("OnClick");T.eq(U.page,page,"settings returns to the saved business page")
 T.eq(U.navItems[page].active,true);T.eq(U.underline:IsShown(),true,"returning restores the correct underline")
end
U:Hide(true)
-- Larger content titles retain a real gap above the second line, while
-- navigation and activity choices keep their own compact type role.
do
 local function Top(region) local point={region:GetPoint()};return -point[#point] end
 for _,row in ipairs({find.results.rows[1],create.rosterList.rows[1],notes.list.rows[1],notes.historyList.rows[1]}) do
  T.eq(select(2,row.title:GetFont()),18)
  T.eq(row.title:GetHeight(),24)
  T.ok(Top(row.meta)-Top(row.title)-row.title:GetHeight()>=4,"content title and metadata keep a four-unit gap")
 end
 T.eq(select(2,find.categories.rows[1].title:GetFont()),16)
 T.eq(select(2,find.activities.rows[1].title:GetFont()),16)
 T.eq(select(2,create.pickerResults.rows[1].title:GetFont()),16)
 local leaderPoint={find.results.rows[1].leader:GetPoint()}
 local crownPoint={find.results.rows[1].leaderIcon:GetPoint()}
 T.eq(leaderPoint[1],"LEFT");T.eq(leaderPoint[#leaderPoint],0,"the leader name centers on the complete result row")
 T.eq(crownPoint[1],"LEFT");T.eq(crownPoint[#crownPoint],0,"the leader crown shares the name's center")
end
-- A fresh UI instance restores the saved seasonal single selection before any
-- new search; this also covers the English all-instances label.
do
 local fresh=dofile("tests/ui_fixture.lua")("enUS")
 fresh.A.db.rememberFilters=true
 fresh.G.db.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon={groupKey=20,difficultyID=8}}}
 fresh.A:Open("find")
 local page=fresh.U.pages.find
 T.eq(fresh.G.filters.groupKey,20);T.eq(fresh.G.filters.difficultyID,8,"first entry restores the seasonal single-selection context")
 T.eq(fresh.G.searchText,"","opening Find searches the restored confirmed selection")
 T.eq(page.refresh:IsEnabled(),true,"a restored confirmed single selection can be refreshed")
 page:SelectCategory("seasonDungeon")
 T.eq(page.activities.selectedKey,20);T.eq(page.activities.rows[1].title:GetText(),"All instances")
 fresh.U:Hide(true)
end
-- A collection and the explicit all-instances choice both survive a reload.
for _,choice in ipairs({{groupKeys={[20]=true},difficultyID=8},{selected=true,difficultyID=8}}) do
 local fresh=dofile("tests/ui_fixture.lua")("zhCN")
 fresh.G.db.prefs.find={category="seasonDungeon",categoryPrefs={seasonDungeon=choice}}
 fresh.A:Open("find")
 local page=fresh.U.pages.find
 T.eq(fresh.G.searchText,"","restoring a confirmed collection or all-instances choice starts browsing")
 T.ok(page.refresh:IsEnabled(),"restored selection enables refresh")
 T.ok(page.emptyText:GetText()~="请选择副本","restored selection does not ask for another choice")
 T.same(fresh.G.filters.groupKeys,choice.groupKeys)
 fresh.U:Hide(true)
end
