-- Production controls, native directory reads and a private player/provider graph.
local function LoadGuide()
 for line in io.lines("addon/LycheeGroup_Guide/LycheeGroup_Guide.toc") do
  local file=line:match("^%s*(.-)%s*$")
  if file~="" and file:sub(1,1)~="#" then dofile("addon/LycheeGroup_Guide/"..file) end
 end
end
local function Fixture(...)
 local f=dofile("tests/ui_fixture.lua")(...)
 EJ_GetDifficulty=function() return 14 end;EJ_SetDifficulty=function() end;EJ_SelectInstance=function() end
 EJ_GetEncounterInfoByIndex=function(index) return ({"First boss","Second boss","Final boss"})[index] end
 local info,available,groups,groupName,fullName=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities,C_LFGList.GetAvailableActivityGroups,C_LFGList.GetActivityGroupInfo,C_LFGList.GetActivityFullName
 local second={id=4,categoryID=2,fullName="Second dungeon",shortName="Second",groupFinderActivityGroupID=40,difficultyID=8,isMythicPlusActivity=true,maxNumPlayers=5,orderIndex=3,allowCrossFaction=true}
 C_LFGList.GetActivityInfoTable=function(id) return id==4 and second or info(id) end
 C_LFGList.GetAvailableActivities=function(category,group,flags)
  if category==2 and (flags==68 or flags==4) then return {2,4,3} end
  return available(category,group,flags)
 end
 C_LFGList.GetAvailableActivityGroups=function(category) return category==2 and {20,40} or groups(category) end
 C_LFGList.GetActivityGroupInfo=function(id) return id==40 and "Second dungeon" or groupName(id) end
 C_LFGList.GetActivityFullName=function(id) return id==4 and second.fullName or fullName(id) end
 return f
end
do
 TestStubs.Install({locale="zhCN"})
 for _,file in ipairs({"Locale.lua","Theme/Defaults.lua","Core.lua","Configuration.lua"}) do Load.addon("LycheeGroup",file) end
 local A=_G.LycheeGroup;A:LoadDB()
 local create,timer=CreateFrame,C_Timer
 CreateFrame=function() error("package loading created a frame") end
 C_Timer=setmetatable({},{__index=function() error("package loading scheduled work") end})
 LoadGuide();local guide=A.Guide
 CreateFrame,C_Timer=create,timer
 T.eq(type(guide),"table");T.eq(guide.View.root,nil);T.eq(guide.events,nil)
 T.eq(A.UI,nil);T.eq(A.Group,nil);T.eq(A.db.guide,nil)
 T.eq(A.MODULES.Guide,nil)
end
local function Copy(value)
 if type(value)~="table" then return value end
 local out={};for k,v in pairs(value) do out[k]=Copy(v) end;return out
end
local function Drain(f) f.base.AdvanceClock(0);f.base.AdvanceClock(0) end
local function Click(button)
 assert(button,"step has no target")
 if button._lycheeList then button._lycheeList.clip.mouseOver=true end
 button:Fire("OnMouseDown","LeftButton");button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
end
local function Step(guide) return guide.steps and guide.steps[guide.index] end
local function Start(f,guide)
 local ok,err=guide:Open();if not ok then return ok,err end
 return guide:Start()
end
local function CheckCard(guide,id,phase)
 local view=guide.View;T.ok(view.card:IsVisible(),id.."/"..phase.." instruction stays visible")
 local reveal=guide:RevealFrame()
 T.eq(view.revealFrame,reveal,id.."/"..phase.." uses the requested transparent region")
 local context=guide:ContextFrame()
 T.eq(view.contextFrame,context,id.."/"..phase.." protects the whole operation area")
 if not context or not context:IsVisible() then return end
 local card=view.card.guideRect;local window=_G.LycheeGroup.UI.frame
 local scale=context:GetEffectiveScale()/window:GetEffectiveScale()
 local x,y=context:GetLeft()*scale-window:GetLeft(),window:GetTop()-context:GetTop()*scale
 T.ok(card.x+card.width<=x or card.x>=x+context:GetWidth()*scale
  or card.y+card.height<=y or card.y>=y+context:GetHeight()*scale,id.."/"..phase.." card does not cover the list or popup")
end
local function Interact(f,guide,outsideRelease)
 local id,phase=Step(guide),guide.phase;local U,S=f.U,f.S
 CheckCard(guide,id,phase)
 local target=guide:Target();T.ok(target,id.."/"..phase.." has a production target")
 if (id=="details" or id=="raidDetails" or id=="applicantDetails") and phase==1 then
  if id=="applicantDetails" then U.pages.create.batchScroll.mouseOver=true else U.pages.find.results.clip.mouseOver=true end
  target.mouseOver=true;target:Fire("OnEnter")
 elseif id=="raidDetails" and phase==2 then
  T.eq(U.Tooltip.expanded,false,"raid starts in overview mode")
  U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LSHIFT",1)
  T.eq(U.Tooltip.expanded,true,"production Shift handler expands the member list")
 elseif id=="details" or id=="raidDetails" or id=="applicantDetails" then
  guide.detailsArea.mouseOver=false;guide.detailsArea:Fire("OnLeave")
  U.Tooltip.interactive.mouseOver=false;U.Tooltip.interactive:Fire("OnLeave");U.Tooltip:UpdateHoverTransit(2)
 elseif id=="apply" and phase==1 then
  Click(target);target:Fire("OnMouseDown","LeftButton");target:Fire("OnDoubleClick","LeftButton")
 elseif id=="resize" then
  U.frame.GetLeft=function(frame) return 100/frame:GetEffectiveScale() end
  U.frame.GetTop=function(frame) return 1000/frame:GetEffectiveScale() end
  local old=IsMouseButtonDown;local down=true;IsMouseButtonDown=function() return down end
  S.cursorX,S.cursorY=800,400;target:Fire("OnMouseDown","LeftButton")
  S.cursorX,S.cursorY=880,340;target:Fire("OnUpdate",.016);down=false
  target:Fire(outsideRelease and "OnUpdate" or "OnMouseUp",outsideRelease and .016 or "LeftButton")
  IsMouseButtonDown=old
 elseif id=="faction" or id=="time" then U.pages.create.batchScroll.mouseOver=true;Click(target)
 else Click(target) end
 Drain(f)
 T.ok(not guide.active or Step(guide)~=id or guide.phase~=phase,id.."/"..phase.." actual interaction progresses")
end

local function To(f,guide,id)
 for _=1,35 do if Step(guide)==id then return end;assert(guide.active,"route ended early");Interact(f,guide) end
 error("route did not reach "..id)
end
local function Finish(f,guide)
 for _=1,40 do if not guide.active then return end;Interact(f,guide) end
 error("route did not finish")
end

-- Opening the filter popup must settle its position before the spotlight reads
-- a child button. Otherwise the next hover repairs an old rectangle with a jump.
do
 local f=Fixture("zhCN",nil,{reduceMotion=true,showImportantFilters=false})
 local A,U=f.A,f.U;A:Open("find");LoadGuide();local guide=A.Guide
 T.ok(Start(f,guide));To(f,guide,"filters")
 local panel=U.pages.find.filterPanel;local target=U.pages.find.quickChoices.healerPresence.button
 local getLeft=target.GetLeft
 target.GetLeft=function(self)
  local _,_,_,x=panel:GetPoint()
  return getLeft(self)+(x or 0)+U.Theme.findFilterWindowInset
 end
 A:SetSetting("reduceMotion",false)
 Click(guide:Target());Drain(f);T.eq(guide.phase,2)
 local left=guide.View.targetRect.left
 U.Motion:Tick(1)
 target:Fire("OnEnter");Drain(f)
 T.near(guide.View.targetRect.left,left,.001,"hover does not repair a stale filter spotlight")
 T.eq(U.Motion.placements[panel],nil,"teaching settles popup placement before highlighting its child")
 guide:Stop("later")
 U.pages.find:SetFiltersOpen(true)
 T.ok(U.Motion.placements[panel],"ordinary filter opening retains its animation")
 U.pages.find:SetFiltersOpen(false)
end

-- First account use opens the actual welcome, without starting a private tour.
-- A fresh UI/character sharing that account's metadata stays cold afterwards.
do
 local f=Fixture("zhCN",nil,{reduceMotion=true,guide={}})
 local loads=0
 C_AddOns.LoadAddOn=function(name)
  T.eq(name,"LycheeGroup_Guide");loads=loads+1;LoadGuide();return true
 end
 f.A:Open("settings");local guide=f.A.Guide
 T.eq(loads,1);T.ok(guide and guide.active);T.eq(guide.View.mode,"intro")
 T.ok(guide.View.card:IsVisible());T.eq(guide.steps,nil);T.eq(f.U.preview,nil)
 T.ok(not f.U.frame:IsShown(),"first welcome is standalone, with the main window hidden")
 T.ok(guide.View.buttons.start.fill:IsShown(),"start has its primary fill before hover")
 T.same(guide.View.buttons.start.fill.color,f.U.Theme.primary,"start uses the default primary red before hover")
 T.eq(f.A.GuideEntry.hint,nil);T.eq(f.A.db.guide.welcomeShown,true)
 Click(guide.View.buttons.dismiss);T.eq(guide.active,nil)
 f.U:Hide(true);f.A:Open("find");T.eq(guide.active,nil);T.eq(loads,1)
 local account=Copy(f.A.db.guide)
 local nextCharacter=Fixture("zhCN",nil,{reduceMotion=true,guide=account})
 C_AddOns.LoadAddOn=function() error("a seen account must not auto-load the guide again") end
 nextCharacter.A:Open("settings")
 T.eq(nextCharacter.A.Guide,nil);T.eq(nextCharacter.A.GuideEntry.hint,nil)
end

-- Complete production-control flow at both supported text-scale extremes.
for _,locale in ipairs({"zhCN","enUS"}) do for _,fontScale in ipairs({70,130}) do
 local f=Fixture(locale,nil,{reduceMotion=true,fontScale=fontScale})
 f.A:Open("settings");LoadGuide();local guide=f.A.Guide
 T.ok(Start(f,guide));Finish(f,guide)
 T.eq(guide.active,nil);T.eq(guide.View.contextFrame,nil)
end end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale,nil,{reduceMotion=true})
 local A,U,G,S=f.A,f.U,f.G,f.S
 A:Open("find");A:Open("settings");T.eq(A.Guide,nil);T.eq(A.GuideEntry.hint,nil)
 local originalWidth,originalHeight=U.windowWidth,U.windowHeight
 local account,character,groupDB=Copy(A.db),Copy(A.charPrefs),Copy(G.db)
 account.guide=nil -- Welcome/completion metadata is the guide's allowed account state.
 local realTitle=LFGListFrame.EntryCreation.Name;local realNote=LFGListFrame.EntryCreation.Description.EditBox
 local realSearch=LFGListFrame.SearchPanel.SearchBox
 realTitle:UserType("Existing real title");realNote:UserType("Existing real note");realSearch:UserType("Existing real query")
 local originals={}
 local function Trap(owner,key)
  originals[#originals+1]={owner,key,owner[key]}
  local original=owner[key]
  owner[key]=function(...)
   if not A.Guide or not A.Guide.active and not U.preview then return original(...) end
   error("guide reached a real player/action boundary: "..key)
  end
 end
 for _,key in ipairs({"Search","ApplyToGroup","CreateListing","UpdateListing","RemoveListing","InviteApplicant","DeclineApplicant","CancelApplication","AcceptInvite","ClearApplicationTextFields","ClearCreationTextFields","ClearSearchTextFields","CopyActiveEntryInfoToCreationFields","SetEntryTitle","GetAvailableRoles"}) do Trap(C_LFGList,key) end
 for _,key in ipairs({"Publish","Update","RemoveListing","Invite","Decline","Cancel"}) do Trap(G,key) end
 Trap(G.Search,"Search");Trap(_G,"SetLFGRoles");Trap(_G,"GetAverageItemLevel")
 Trap(_G,"UnitClass");Trap(A.Specializations,"Player")
 LoadGuide();local guide=A.Guide
 T.eq(guide.Next,nil);T.eq(guide.Back,nil);T.eq(guide.OnAction,nil)
 T.ok(guide:Open());T.eq(guide.View.mode,"intro")
 T.eq(guide.View.body:GetText(),locale=="zhCN" and "感谢您使用荔枝组队，我们创建了一个新手引导，来帮助你更好的使用它" or "Thank you for using Lychee LFG. We created this guide to help you use it.","welcome preserves the requested copy")
 Click(guide.View.buttons[1]);Drain(f)
 T.eq(U.page,"find");T.eq(#guide.steps,15);T.eq(U.preview.provider.Catalog,G.Catalog)
 T.ok(U.preview.provider~=G);T.ok(not U.previewExit or not U.previewExit:IsShown())
 T.ok(U.preview.provider.activity.id>0);T.eq(#U.preview.provider.apps,0)
 T.eq(Step(guide),"activity");T.eq(guide.phase,1)
 local first=guide:Target();local category=U.preview.provider.category
 U.pages.find:SelectCategory(category,first);Drain(f);T.eq(guide.phase,1)
 U.pages.find:ClosePicker();Drain(f)
 Interact(f,guide);T.eq(guide.phase,2);Interact(f,guide)
 if Step(guide)=="activity" then T.eq(guide.phase,3);Interact(f,guide);T.eq(guide.phase,4);Interact(f,guide) end
 T.eq(Step(guide),"sidebar")
 Interact(f,guide);T.eq(guide.phase,2);Interact(f,guide);T.eq(Step(guide),"filters")
 Interact(f,guide);local box=U.pages.find.fMinMembers.box
 T.eq(guide:Target(),U.pages.find.quickChoices.healerPresence.button)
 box:UserType("1");Drain(f);T.eq(guide.phase,2,"typing cannot complete the role-filter instruction")
 box:UserType("");Drain(f)
 Interact(f,guide);T.eq(guide.phase,3)
 T.eq(U.preview.provider.filters.healerPresence,"missing");T.eq(U.preview.provider.filters.minMembers,nil)
 Interact(f,guide);T.eq(Step(guide),"details")
 local area=guide:Target();local beforeMouse=area:IsMouseEnabled()
 Interact(f,guide);T.eq(guide.phase,2);T.eq(area:IsMouseEnabled(),beforeMouse)
 T.eq(guide.View.avoidFrame,U.Tooltip.interactive)
 T.eq(guide:Target(),area,"original hover area remains open while reading the separate tooltip")
 area.mouseOver=false;area:Fire("OnLeave");U.Tooltip.interactive.mouseOver=true;U.Tooltip.interactive:Fire("OnEnter")
 Drain(f);T.eq(guide.phase,2,"entering the tooltip cancels leaving; reading does not advance")
 T.eq(U.Tooltip.interactive.memberButtons[1]:IsEnabled(),false,"tutorial preserves read-only search members")
 Interact(f,guide);T.eq(Step(guide),"sort")
 local header=U.pages.find.resultsHeader;header:SetSort("rating",true,false);Drain(f)
 T.eq(guide.phase,1,"programmatic sorting cannot complete the step")
 local unsorted=table.concat(U.pages.find.results.ids,",")
 Interact(f,guide);local ascending=table.concat(U.pages.find.results.ids,",")
 T.ok(ascending~=unsorted,"the first rating click visibly reorders the teaching groups")
 Interact(f,guide)
 T.ok(table.concat(U.pages.find.results.ids,",")~=ascending,"the second rating click visibly reverses the teaching groups")
 T.eq(Step(guide),"apply")
 local applyRow=guide:Target()
 applyRow.tooltipArea:Fire("OnEnter");Drain(f)
 T.ok(not U.Tooltip.interactive:IsShown(),"group details cannot cover the application target outside their teaching step")
 T.eq(guide.phase,1);applyRow.tooltipArea:Fire("OnLeave")
 Interact(f,guide);T.eq(guide.phase,2);T.eq(U.Application.applicationLease,nil)
 Interact(f,guide);T.eq(guide.phase,3)
 T.ok(U.preview.provider.applicationPrefs.roles.HEALER,"a teaching role click immediately updates the provider's private selection")
 Interact(f,guide);T.eq(guide.phase,4)
 T.ok(U.Application:IsAutoApplyEnabled(),"the checkbox enables automatic applications immediately with valid private roles")
 T.eq(U.Application.previewApplication.enableOnSave,nil,"valid private roles do not need pending activation")
 T.eq(U.preview.provider.prefs.applicationRoles,nil,"teaching roles stay in the provider's application session")
 Interact(f,guide);T.eq(guide.phase,5)
 T.ok(U.preview.provider.Applications:IsActive(guide.appliedID))
 T.ok(U.Application:IsAutoApplyEnabled());T.ok(U.preview.provider.applicationPrefs.roles.HEALER)
 T.eq(U.preview.provider.prefs.applicationRoles,nil,"submitting the teaching application does not create persisted role defaults")
 Interact(f,guide);T.eq(Step(guide),"raidActivity");T.eq(U.preview.provider.Applications:GetActiveCount(),0)
 To(f,guide,"createPage")
 local session=U.preview;local flowSteps=guide.steps
 T.eq(guide:Target(),U.navItems.create)
 T.ok(guide.View.target~=U.navItems.create,"navigation outline has its own tight visual bounds")
 T.ok(guide.View.target:GetHeight()<U.navItems.create:GetHeight(),"navigation outline does not span the full header height")
 Interact(f,guide);T.eq(U.page,"create");T.eq(guide.page,"create");T.eq(Step(guide),"createActivity")
 T.eq(U.preview,session,"switching page preserves the single private session")
 T.eq(guide.steps,flowSteps,"switching page continues the same sequence")
 T.eq(guide.transition,nil,"the tab click releases its temporary navigation allowance")
 To(f,guide,"resize")
 U:SetWindowSize(originalWidth+20,originalHeight+10);U:StopWindowResize();Drain(f)
 T.eq(Step(guide),"resize","programmatic resize cannot advance")
 local handle=guide:Target();S.cursorX,S.cursorY=800,400
 handle:Fire("OnMouseDown","LeftButton");handle:Fire("OnMouseUp","LeftButton");Drain(f)
 T.eq(Step(guide),"resize","clicking the grip without moving cannot advance")
 Interact(f,guide,true);T.same(A.charPrefs,character);T.eq(guide.demo,nil)
 T.eq(guide.active,nil);T.eq(U.preview,nil);T.eq(U.guideSession,nil)
 T.eq(guide.View.target,nil);T.eq(guide.View.mode,nil);T.eq(guide.task,nil);T.eq(#guide.Bindings.records,0)
 T.eq(U.windowWidth,originalWidth);T.eq(U.windowHeight,originalHeight);T.eq(U.page,"find")
 T.eq(A.db.guide.completedVersion,guide.version);T.ok(A.db.guide.completed)
 T.eq(next(guide.events.events),nil);T.eq(handle:GetScript("OnUpdate"),nil)
 T.ok(Start(f,guide));T.eq(#guide.steps,15,"manual replay always includes the complete continuous tour");Finish(f,guide)
 local metadata=A.db.guide;A.db.guide=nil;T.same(A.db,account);A.db.guide=metadata
 T.eq(metadata.welcomeShown,true,"manual replay preserves the account's first-welcome state")
 T.same(A.charPrefs,character);T.same(G.db,groupDB)
 T.eq(realTitle:GetText(),"Existing real title");T.eq(realNote:GetText(),"Existing real note");T.eq(realSearch:GetText(),"Existing real query")
 for _,entry in ipairs(originals) do entry[1][entry[2]]=entry[3] end
 local function Run()
  T.ok(Start(f,guide));local provider=U.preview.provider
  local weak=setmetatable({provider},{__mode="v"});Finish(f,guide)
  T.eq(next(provider.subs),nil);T.eq(next(provider.views),nil);T.eq(#guide.Bindings.records,0)
  provider=nil;return weak
 end
 Run();local objects=#S.nodes
 local refs={Run(),Run(),Run(),Run()}
 T.eq(#S.nodes,objects,"warm tours reuse native pools")
 collectgarbage("collect") -- retention diagnostic; never a natural-memory claim
 for _,ref in ipairs(refs) do T.eq(ref[1],nil,"closed route releases provider graph") end
 T.eq(guide.steps,nil);T.eq(guide.task,nil)
 for _,region in pairs(guide.regions) do
  T.eq(region:IsShown(),false);T.eq(region:GetNumPoints(),0,"completed guide clears visual region anchors")
 end
 -- Native HookScript callbacks can open a tooltip after the primary script.
 Start(f,guide);To(f,guide,"sort")
 local heading=guide:Target();guide:ReleaseBindings();local enterHeading=heading:GetScript("OnEnter")
 local hookHeading=heading.HookScript;local hooks={}
 heading:SetScript("OnEnter",function() end)
 heading.HookScript=function(_,event,callback) hooks[event]=callback end
 U.Tooltip:BindText(heading,"Native post-script tooltip");heading.HookScript=hookHeading
 guide:UpdateStep();heading:Fire("OnEnter");T.eq(guide.View.avoidFrame,nil)
 hooks.OnEnter(heading);T.eq(U.Tooltip.text:IsShown(),false);Drain(f)
 T.eq(guide.View.avoidFrame,nil,"native post-script hover cannot cover the instruction or target")
 guide:Stop("later");heading:SetScript("OnEnter",enterHeading)
 hooks.OnEnter(heading);T.ok(U.Tooltip.text:IsShown(),"native plain tooltip is available again after leaving the guide")
 U.Tooltip:Hide()
 -- The Mythic+ checkbox path requires its separate confirmation button.
 Start(f,guide);Interact(f,guide);local page=U.pages.find
 local difficulty
 for _,button in ipairs(page.difficultyButtons) do if button.value==8 and button:IsShown() then difficulty=button;break end end
 T.ok(difficulty and difficulty.active,"opening the activity picker defaults to M+ without another click")
 T.eq(guide.activityChoiceGoal,2);T.eq(guide.phase,2);T.eq(guide:ActivityChoiceCount(),0)
 local choice=guide:Target();local other
 for _,row in ipairs(page.activities.rows) do if row~=choice and page.keystoneGroups[row.key] and row._hitVisible then other=row;break end end
 T.ok(other);page.activities.clip.mouseOver=true;Click(other.multiSelect);Drain(f)
 T.eq(guide.phase,3,"one dungeon keeps the guide in multi-selection")
 T.eq(guide:ActivityChoiceCount(),1);T.eq(guide:Target(),choice)
 Click(other.multiSelect);Drain(f);T.eq(guide.phase,2,"unchecking returns to the first selection")
 Click(choice.multiSelect);Drain(f);T.eq(guide.phase,3)
 Interact(f,guide);T.eq(guide.phase,4);T.eq(guide:Target(),page.pickerConfirm);Interact(f,guide)
 T.eq(Step(guide),"sidebar");guide:Stop("later")
 -- A header filter remains reachable without opening a modal over it.
 A:SetSetting("showImportantFilters",true);Start(f,guide);To(f,guide,"filters")
 T.eq(guide:Target(),U.pages.find.quickChoices.healerPresence.button)
 T.ok(not U.pages.find.filtersOpen)
 Interact(f,guide);T.eq(Step(guide),"details");guide:Stop("later")
 A:SetSetting("showImportantFilters",false)
 -- A real catalog group may lose its Mythic+ variant between opening and
 -- selecting it. The route follows the selected form activity, not its seed.
 Start(f,guide);To(f,guide,"createActivity");Interact(f,guide);page=U.pages.create
 local selectedGroup=page.pickerEntries[guide:Target().key].group
 local variants=selectedGroup.variants;selectedGroup.variants={G.Catalog:GetActivity(3)}
 Interact(f,guide);T.eq(page:FormData().activityID,3)
 for _,id in ipairs(guide.steps) do T.ok(id~="time","ordinary dungeon route omits unsupported run-time control") end
 Finish(f,guide);selectedGroup.variants=variants
 Start(f,guide);To(f,guide,"details");Interact(f,guide)
 U.Tooltip:Hide();Drain(f);T.eq(guide.phase,1,"hidden tooltip returns to the hover instruction")
 guide:Stop("later");T.eq(#guide.Bindings.records,0)
 Start(f,guide);U:HandleEscape();T.eq(guide.active,nil);T.eq(U.preview,nil);T.ok(U:IsShown())
 Start(f,guide);A:Open("notes");T.eq(guide.active,nil);T.eq(U.preview,nil);T.eq(U.page,"notes")
 A:Open("settings");Start(f,guide);To(f,guide,"createPage")
 U:Navigate("create");T.eq(guide.active,nil,"a direct page call cannot impersonate the teaching tab click")
 T.eq(U.preview,nil);T.eq(U.page,"create")
 A:Open("settings");Start(f,guide);guide.events:Fire("OnEvent","PLAYER_REGEN_DISABLED")
 T.eq(guide.active,nil);T.eq(U.preview,nil);T.eq(next(guide.events.events),nil)
 A:SetSetting("reduceMotion",false);Start(f,guide);T.ok(guide.task)
 U:Hide();T.eq(guide.active,nil);T.eq(guide.task,nil);A:Open("settings")
 T.eq(U.preview,nil);Drain(f);f.base.AdvanceClock(1);T.eq(guide.View.mode,nil)
 A:SetSetting("reduceMotion",true)
 Start(f,guide);To(f,guide,"createPage");A:SetSetting("reduceMotion",false)
 Interact(f,guide);T.eq(Step(guide),"createActivity")
 T.ok(guide.task and not guide.ready,"the next instruction waits for the native page motion")
 f.base.AdvanceClock(U.Theme.windowPageMotionDuration+.01)
 T.ok(guide.ready and guide.View.card:IsVisible(),"the creation instruction appears after page motion")
 guide:Stop("later");A:SetSetting("reduceMotion",true)
 Start(f,guide);local target=guide:Target();guide:ReleaseBindings();local native=target:GetScript("OnClick")
 target:SetScript("OnClick",function() error("injected native callback failure") end)
 guide:UpdateStep();local ok,err=pcall(Click,target);target:SetScript("OnClick",native)
 T.eq(ok,false);T.ok(tostring(err):find("injected native callback failure",1,true))
 T.eq(guide.active,nil);T.eq(U.preview,nil);T.eq(#guide.Bindings.records,0);T.eq(guide.task,nil)
 local enter=U.pages.find.Enter
 U.pages.find.Enter=function(self,...) enter(self,...);error("injected guide page failure") end
 ok,err=pcall(Start,f,guide);U.pages.find.Enter=enter
 T.eq(ok,false);T.ok(tostring(err):find("injected guide page failure",1,true))
 T.eq(guide.active,nil);T.eq(U.preview,nil);T.eq(U.guideSession,nil);T.eq(next(guide.events.events),nil)
 local categories=G.Catalog.GetCategories
 G.Catalog.GetCategories=function() return {} end
 T.eq(Start(f,guide),false);T.eq(guide.active,nil);T.eq(U.preview,nil)
 G.Catalog.GetCategories=function() error("injected directory read failure") end
 ok,err=pcall(Start,f,guide);G.Catalog.GetCategories=categories
 T.eq(ok,false);T.ok(tostring(err):find("injected directory read failure",1,true))
 T.eq(guide.active,nil);T.eq(U.guideSession,nil);T.eq(guide.task,nil)
end

-- A catalog with one Mythic+ dungeon must not wait for an unavailable second choice.
do
 local f=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=true})
 f.A:Open("settings");LoadGuide();local guide=f.A.Guide
 T.ok(Start(f,guide));Interact(f,guide)
 T.eq(guide.activityChoiceGoal,1);T.eq(guide.phase,2)
 Interact(f,guide);T.eq(guide.phase,4);T.eq(guide:Target(),f.U.pages.find.pickerConfirm)
 Interact(f,guide);T.eq(Step(guide),"sidebar");Finish(f,guide)
 T.eq(guide.active,nil);T.eq(f.U.preview,nil)
end

-- Native modal closure can synchronously refresh hover/layout before the
-- submit button's after-handler returns. A submitted application remains done.
do
 local f=Fixture("zhCN",nil,{reduceMotion=true})
 f.A:Open("settings");LoadGuide();local guide,U=f.A.Guide,f.U
 T.ok(Start(f,guide));To(f,guide,"apply")
 Interact(f,guide);Interact(f,guide);Interact(f,guide);T.eq(guide.phase,4)
 local submitted=guide.appliedID
 local release=U.Application.ReleaseApplication
 U.Application.ReleaseApplication=function(self,...)
  release(self,...)
  if guide.active and Step(guide)=="apply" and guide.phase==4 then guide:UpdateStep() end
 end
 Interact(f,guide)
 U.Application.ReleaseApplication=release
 T.ok(U.preview.provider.Applications:IsActive(submitted))
 T.eq(guide.phase,5,"closing the submitted modal must show cancellation instead of returning to double-click")
 T.eq(guide.appliedID,submitted,"modal closure retains the submitted application identity")
 T.eq(U.preview.provider.Applications:GetActiveCount(),1)
 Interact(f,guide);T.eq(Step(guide),"raidActivity");Finish(f,guide)
 T.eq(U.preview,nil)
end

-- The transparent role dialog also permits another valid role and early
-- submission. Follow the completed request rather than trapping the user.
do
 local f=Fixture("zhCN",nil,{reduceMotion=true})
 f.A:Open("settings");LoadGuide();local guide,U=f.A.Guide,f.U
 T.ok(Start(f,guide));To(f,guide,"apply");Interact(f,guide)
 local submitted=guide.appliedID;local modal=U.Application.applicationModal
 Click(modal.roles.DAMAGER);Click(modal.autoApply);Drain(f)
 T.eq(guide.phase,2,"another valid role can be selected before the highlighted healer")
 Click(modal.submit);Drain(f)
 T.eq(guide.phase,5,"a valid early submission proceeds to cancellation")
 T.eq(guide.appliedID,submitted);T.eq(U.preview.provider.Applications:GetActiveCount(),1)
 T.ok(U.Application:IsAutoApplyEnabled());T.ok(U.preview.provider.applicationPrefs.roles.DAMAGER)
 Interact(f,guide);T.eq(Step(guide),"raidActivity");Finish(f,guide)
 T.eq(U.preview,nil)
end

-- Teaching keeps one result as its target; crossing another row must not
-- move the outline or replace the open tooltip through delayed hover transit.
for _,step in ipairs({"details","raidDetails"}) do
 local f=Fixture("zhCN",nil,{reduceMotion=true})
 f.A:Open("settings");LoadGuide();local guide,U=f.A.Guide,f.U
 T.ok(Start(f,guide));To(f,guide,step)
 local list=U.pages.find.results;local target=guide:Target();local first=target:GetParent();local second
 for _,row in ipairs(list.rows) do if row~=first and row._hitVisible and row:IsShown() then second=row;break end end
 T.ok(second);list.clip.mouseOver=true
 second.mouseOver=true;second.tooltipArea.mouseOver=true;second.tooltipArea:Fire("OnEnter");Drain(f)
 T.eq(guide:Target(),target,"hovering another result cannot move the teaching outline")
 T.ok(not U.Tooltip.interactive or not U.Tooltip.interactive:IsShown(),"another result cannot open teaching details")
 T.ok(not second.hover:IsShown() or second.hover:GetAlpha()==0,"teaching suppresses competing full-row hover fills")
 second.mouseOver=false;second.tooltipArea.mouseOver=false;second.tooltipArea:Fire("OnLeave")
 Interact(f,guide);T.eq(U.Tooltip.owner,first)
 U.Tooltip:HoverOwner(second,function() return true end,function(row) U.Tooltip:ShowGroup(row,U:GetGroup():GetResult(row.key)) end)
 T.eq(U.Tooltip.hoverOwner,nil,"another result is not queued for delayed tooltip handoff")
 T.eq(U.Tooltip.owner,first)
 U.Tooltip:ShowGroup(second,U:GetGroup():GetResult(second.key))
 T.eq(U.Tooltip.owner,first,"a delayed show cannot replace the teaching owner")
 T.eq(guide:Target(),target)
 guide:Stop("later")
 T.eq(list.hoverFill,nil,"ordinary result hover setting returns after the guide")
 T.eq(guide.Adapter.resultList,nil,"the hover lease releases the result list")
end

-- Raid teaching always demonstrates Shift without changing the player's setting.
do
 local f=Fixture("zhCN",nil,{reduceMotion=true,raidMembers="always"})
 f.A:Open("settings");LoadGuide();local guide,U=f.A.Guide,f.U
 T.ok(Start(f,guide));To(f,guide,"raidDetails");Interact(f,guide)
 T.eq(U.Tooltip.record.categoryID,3);T.eq(#U.Tooltip.details.members,12)
 T.eq(U.Tooltip.expanded,false);T.eq(f.A:GetSetting("raidMembers"),"shift")
 U.Tooltip.interactive:Fire("OnEvent","MODIFIER_STATE_CHANGED","LALT",1);Drain(f)
 T.eq(guide.phase,2,"another modifier does not complete Shift teaching")
 guide.detailsArea.mouseOver=false;guide.detailsArea:Fire("OnLeave")
 U.Tooltip.interactive.mouseOver=false;U.Tooltip.interactive:Fire("OnLeave");U.Tooltip:UpdateHoverTransit(2);Drain(f)
 T.eq(Step(guide),"raidDetails");T.eq(guide.phase,1,"leaving before expansion returns to the hover instruction")
 Interact(f,guide);Interact(f,guide);T.eq(guide.phase,3)
 Interact(f,guide);T.eq(Step(guide),"createPage")
 T.eq(f.A:GetSetting("raidMembers"),"always","the original setting returns outside raid teaching")
 To(f,guide,"applicantDetails");local area=guide:Target();Interact(f,guide)
 T.eq(U.Tooltip.member,area:GetParent().member,"actual applicant hover opens that person's profile")
 T.eq(guide.View.avoidFrame,U.Tooltip.interactive)
 Finish(f,guide);T.eq(U.page,"find");T.eq(f.A:GetSetting("raidMembers"),"always")
end

-- A temporarily missing native raid category omits only its two teaching steps.
do
 local f=Fixture("enUS",nil,{reduceMotion=true})
 local categories=f.G.Catalog.GetCategories
 f.G.Catalog.GetCategories=function(self)
  local result={};for _,category in ipairs(categories(self)) do if category.id~=3 then result[#result+1]=category end end;return result
 end
 f.A:Open("settings");LoadGuide();local guide=f.A.Guide
 T.ok(Start(f,guide));T.eq(#guide.steps,13)
 for _,id in ipairs(guide.steps) do T.ok(id~="raidActivity" and id~="raidDetails") end
 Finish(f,guide);T.eq(f.U.page,"find")
end

-- The general fixture omits world positions. Supply measured rectangles here
-- to check the controller's exact region anchors at different window scales.
do
 local f=Fixture("zhCN",nil,{reduceMotion=true})
 f.A:Open("settings");LoadGuide();local guide,U=f.A.Guide,f.U
 T.ok(Start(f,guide));To(f,guide,"details")
 local page=U.pages.find;local rating
 for _,button in ipairs(page.resultsHeader.buttons) do if button.definition.key=="rating" then rating=button end end
 local function WorldRect(frame,left,top,width,height)
  frame.GetLeft=function(self) return left/self:GetEffectiveScale() end
  frame.GetTop=function(self) return top/self:GetEffectiveScale() end
  frame.GetWidth=function(self) return width/self:GetEffectiveScale() end
  frame.GetHeight=function(self) return height/self:GetEffectiveScale() end
 end
 for _,scale in ipairs({.75,1,1.4}) do
  U.frame:SetScale(scale)
  WorldRect(U.frame,200,920,1200,720)
  WorldRect(page.resultsHeader,350,810,1010,30)
  WorldRect(page.results,350,780,1020,540)
  WorldRect(rating,1080,810,100,30)
  local function Region(frame,x,y,width,height,label)
   local point,parent,relative,actualX,actualY=frame:GetPoint()
   T.eq(point,"TOPLEFT");T.eq(parent,U.frame);T.eq(relative,"TOPLEFT")
   T.near(actualX,x/scale,.001,label.." left")
   T.near(actualY,-y/scale,.001,label.." top")
   T.near(frame:GetWidth(),width/scale,.001,label.." width")
   T.near(frame:GetHeight(),height/scale,.001,label.." height")
  end
  Region(guide:ListRegion(),150,110,1020,570,"whole result list")
  Region(guide:ListRegion(rating),880,110,100,570,"rating column")
  WorldRect(U.navItems.create.icon,740,884,18,18)
  WorldRect(U.navItems.create.label,766,886,50,22)
  guide.steps[guide.index]="createPage"
  Region(guide:VisualTarget(U.navItems.create),540,34,76,22,"navigation icon and label")
  guide.steps[guide.index]="details"
 end
 guide:Stop("later")
end

-- Public scale and display changes need not resize the window. Supply native anchor/scale
-- coordinates only in these sessions so a card outside the window can be
-- checked against the screen after FitToScreen changes its effective scale.
for _,change in ipairs({"scale","display"}) do for _,welcome in ipairs({false,true}) do
 local f=Fixture("enUS",nil,{reduceMotion=true})
 local A,U=f.A,f.U;A:Open("settings")
 -- The UI fixture omits the public facade and Floating; no Floating action is
 -- invoked here, but load the real facade rather than duplicating Set's route.
 local floating=A.Floating;A.Floating=floating or {};dofile("addon/LycheeGroup/API.lua");A.Floating=floating
 T.ok(A.API.Configuration:Set({["layout.window.width"]=1200,["layout.window.height"]=720,["settings.uiScale"]=75}))
 local function Factor(point,axis)
  if axis=="x" then return point:find("LEFT") and 0 or point:find("RIGHT") and 1 or .5 end
  return point:find("BOTTOM") and 0 or point:find("TOP") and 1 or .5
 end
 local Coordinate
 Coordinate=function(node,point,axis)
  local scale=node:GetEffectiveScale();local size=(axis=="x" and node:GetWidth() or node:GetHeight())*scale
  if node==UIParent then return size*Factor(point,axis) end
  if node.allPoints then return Coordinate(node.allPoints,point,axis) end
  local p={node:GetPoint()};local relative,anchor,x,y
  if type(p[2])=="table" then relative,anchor,x,y=p[2],p[3],p[4] or 0,p[5] or 0
  else relative,anchor,x,y=node:GetParent(),p[1],p[2] or 0,p[3] or 0 end
  if not relative or not anchor then return size*Factor(point,axis) end
  return Coordinate(relative,anchor,axis)+(axis=="x" and x or y)*scale+(Factor(point,axis)-Factor(p[1],axis))*size
 end
 local function NativeCoordinates(node)
  node.GetLeft=function(self) return Coordinate(self,"LEFT","x")/self:GetEffectiveScale() end
  node.GetRight=function(self) return Coordinate(self,"RIGHT","x")/self:GetEffectiveScale() end
  node.GetTop=function(self) return Coordinate(self,"TOP","y")/self:GetEffectiveScale() end
  node.GetBottom=function(self) return Coordinate(self,"BOTTOM","y")/self:GetEffectiveScale() end
  return node
 end
 for _,node in ipairs(f.S.nodes) do NativeCoordinates(node) end
 local create=CreateFrame;CreateFrame=function(...) return NativeCoordinates(create(...)) end
 local fit=U.FitToScreen;local sentinel={}
 local taggedFit=function(...) fit(...);return sentinel,nil,false end;U.FitToScreen=taggedFit
 LoadGuide();local guide=A.Guide
 T.ok(guide:Open())
 if not welcome then T.ok(guide:Start());To(f,guide,"details") end
 local view=guide.View;local width,height=U.windowWidth,U.windowHeight;local index,phase=guide.index,guide.phase
 T.ok(view.card:IsVisible())
 T.eq(guide.events.events.DISPLAY_SIZE_CHANGED,true,"welcome and teaching observe display bounds only while active")
 local scale=U.frame:GetEffectiveScale()
 if change=="scale" then T.ok(A.API.Configuration:Set({["settings.uiScale"]=125}))
 else
  UIParent:SetWidth(1500)
  U.frame:Fire("OnEvent","DISPLAY_SIZE_CHANGED")
  if guide.events.events.DISPLAY_SIZE_CHANGED then guide.events:Fire("OnEvent","DISPLAY_SIZE_CHANGED") end
  T.eq(U.frame:GetEffectiveScale(),scale,"display bounds can change without changing effective scale")
 end
 Drain(f)
 T.eq(guide.active,true,"a display change preserves the active guide")
 T.eq(U.windowWidth,width);T.eq(U.windowHeight,height,"pure scaling does not send OnSizeChanged")
 local left,right=Coordinate(view.card,"LEFT","x"),Coordinate(view.card,"RIGHT","x")
 T.ok(left>=0 and right<=UIParent:GetWidth()*UIParent:GetEffectiveScale(),"public scale change keeps the guide card inside the screen")
 T.near(view.root:GetEffectiveScale(),U.frame:GetEffectiveScale(),.001,"standalone welcome follows the changed main-window scale")
 T.near(view.screen.left,-U.frame:GetLeft()+4,.001,"the guide refreshes screen bounds without a size event")
 T.near(view.screen.right,UIParent:GetWidth()*UIParent:GetEffectiveScale()/U.frame:GetEffectiveScale()-U.frame:GetLeft()-4,.001,"the guide refreshes the right screen bound")
 T.eq(guide.index,index);T.eq(guide.phase,phase,"scaling cannot complete the current teaching interaction")
 local first,second,third=U:FitToScreen()
 T.eq(first,sentinel);T.eq(second,nil);T.eq(third,false,"the scale lease preserves every original return value")
 local updates,layouts=0,0;local update,layout=guide.UpdateStep,view.Layout
 guide.UpdateStep=function(self,...) updates=updates+1;return update(self,...) end
 view.Layout=function(self,...) layouts=layouts+1;return layout(self,...) end
 for _=1,20 do U:FitToScreen() end
 -- Either native display observer can run first; a settled duplicate event
 -- must not cause another teaching or card layout pass.
 if guide.events.events.DISPLAY_SIZE_CHANGED then guide.events:Fire("OnEvent","DISPLAY_SIZE_CHANGED") end
 U.frame:Fire("OnEvent","DISPLAY_SIZE_CHANGED")
 T.eq(updates,0,"stable fits and duplicate display events do not refresh teaching")
 T.eq(layouts,0,"stable fits and duplicate display events do not lay out the card")
 guide.UpdateStep,view.Layout=update,layout
 guide:Stop("later");Drain(f)
 T.eq(U.FitToScreen,taggedFit,"ending the guide restores the exact FitToScreen method")
 T.eq(#guide.Adapter.leases,0);T.eq(#guide.Bindings.records,0);T.eq(guide.task,nil)
 T.eq(next(guide.events.events),nil,"ending the guide removes display and combat subscriptions")
 CreateFrame=create
end end
