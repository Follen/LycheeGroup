-- Live page lifecycles driven through real History/Search/Results modules.
-- Native APIs and frames remain offline substitutes.
local function Fixture()
 local f=dofile("tests/ui_fixture.lua")("enUS")
 local a,g=f.A,f.G
 -- Reuse Group's actual subscriber dispatcher while retaining focused native
 -- API substitutes and the UI fixture's other business services.
 dofile("addon/LycheeGroup_Group/Group.lua")
 local dispatcher=a.Group;a.Group=g
 g.Notify=dispatcher.Notify
 local subscribe=dispatcher.Subscribe
 f.subscriptions=0;f.subscriptionCalls=0
 function g:Subscribe(callback)
  f.subscriptions=f.subscriptions+1;f.subscriptionCalls=f.subscriptionCalls+1
  local release=subscribe(self,callback);local active=true
  return function() if active then active=false;f.subscriptions=f.subscriptions-1;release() end end
 end
 g.Game={frame=CreateFrame("Frame"),EnableRunTracking=function(self) self.runTracking=true end,DisableRunTracking=function(self) self.runTracking=nil end,RefreshSubscriptions=function() end}
 g.Roster={GetUnitSpec=function() return 71 end}
 g.charDB={runs={}}
 dofile("addon/LycheeGroup_Group/History.lua")
 g.GetHistory=dispatcher.GetHistory
 C_ChallengeMode.IsChallengeModeActive=function() return true end
 C_ChallengeMode.GetActiveChallengeMapID=function() return 456 end
 C_ChallengeMode.GetMapUIInfo=function() return "History dungeon",nil,nil,12345 end
 C_ChallengeMode.GetActiveKeystoneInfo=function() return 12 end
 f.base.SetUnit("player",{name="Recorder",realm="Home",class="WARRIOR",guid="Player-1"})
 return f
end
local function Complete(g)
 g.History:OnStart();g.History:OnCompleted()
end

-- Already-loaded history updates both its navigation count and visible rows.
do
 local f=Fixture();local a,u,g=f.A,f.U,f.G
 a:SetSetting("reduceMotion",true);a:Open("notes")
 local page=u.pages.notes
 page:SelectTab("history")
 local counts,rows=0,0
 local refreshCounts,refreshHistory=page.RefreshCounts,page.RefreshHistory
 function page:RefreshCounts() counts=counts+1;return refreshCounts(self) end
 function page:RefreshHistory() rows=rows+1;return refreshHistory(self) end
 Complete(g)
 T.eq(#g.charDB.runs,1,"real History completion appends the run")
 T.eq(page.tabs.history.count:GetText(),"1","History notifications refresh the visible navigation count")
 T.eq(#page.historyList.ids,1,"completion refreshes the active history list without switching tabs")
 T.eq(page.historyList.rows[1].title:GetText(),"History dungeon")
 local calls=f.subscriptionCalls
 a:Open("notes");a:Open("notes")
 T.eq(f.subscriptionCalls,calls,"repeated entry reuses its Group subscription")
 page:SelectTab("all");counts=0;rows=0
 Complete(g)
 T.eq(page.tabs.history.count:GetText(),"2","ordinary notes retain an updated count")
 T.ok(counts>0);T.eq(rows,0,"history rows are not drawn behind another notes category")
 page:SelectTab("history");a:SetSetting("reduceMotion",false)
 u:Hide();T.ok(u.hiding);T.ok(u.frame:IsShown())
 counts=0;rows=0;Complete(g)
 T.eq(counts,0,"closing animation does not draw a new history count")
 T.eq(rows,0,"closing animation does not replace history rows")
 a:Open("notes")
 T.eq(#page.historyList.ids,3,"interrupted close rereads current completed history")
 T.eq(page.tabs.history.count:GetText(),"3")
 u:Hide(true);T.eq(f.subscriptions,0,"leaving Notes releases its Group listener")
 counts=0;rows=0;Complete(g)
 T.eq(counts,0);T.eq(rows,0,"hidden history notifications do not render")
 a:Open("notes");T.eq(#page.historyList.ids,4)
 a:Open("settings");T.eq(f.subscriptions,0,"navigation releases the Notes listener")
end

-- A completion prepends to GetHistory while a pooled row may still be pressed.
do
 local f=Fixture();local a,u,g=f.A,f.U,f.G
 a:SetSetting("reduceMotion",true);Complete(g)
 local old=g.charDB.runs[1]
 a:Open("notes");local page=u.pages.notes;page:SelectTab("history")
 local row=page.historyList.rows[1]
 row:Fire("OnMouseDown","LeftButton")
 Complete(g)
 row:Fire("OnClick","LeftButton")
 T.eq(page.historyRun,nil,"completion cannot replace the run selected by an existing mouse press")
 local newest=g.charDB.runs[2]
 row:Fire("OnMouseDown","LeftButton");row:Fire("OnClick","LeftButton")
 T.eq(page.historyRun,newest,"a fresh press opens the newly completed run")
 page.historyModal:Close()
 local moved=page.historyList.rows[2]
 moved:Fire("OnMouseDown","LeftButton");moved:Fire("OnClick","LeftButton")
 T.eq(page.historyRun,old,"the older run still opens after moving down")
 page.historyModal:Close()
 for _,button in ipairs(page.historyHeader.buttons) do if button.definition.key=="level" then button:Fire("OnClick","LeftButton");break end end
 T.eq(page.historyList.ids[1],newest,"equal-level history retains the source order")
 T.eq(page.historyList.ids[2],old)
 page:RefreshHistory();T.eq(page.historyList.ids[1],newest,"repeated sorting keeps equal values stable")
 row:Fire("OnMouseDown","LeftButton");u:Hide(true);a:Open("notes")
 row:Fire("OnClick","LeftButton")
 T.eq(page.historyRun,nil,"closing and reusing the same pool cancels its previous press")
 row:Fire("OnMouseDown","LeftButton");row:Fire("OnClick","LeftButton")
 T.eq(page.historyRun,newest,"reopened history accepts a fresh press")
 u:Hide(true)
end

-- Core's real Ensure boundary joins a Notes page after an unrelated business
-- command loads Group; ordinary notes entry must never trigger that load.
for _,loadAt in ipairs({"external","closing","history"}) do
 local closing=loadAt=="closing"
 local f=Fixture();local a,u,g=f.A,f.U,f.G
 a.Group=nil
 local fixtureEnsure=a.Ensure
 dofile("addon/LycheeGroup/Core.lua")
 local ensure=a.Ensure
 function a:Ensure(module) if module=="Group" then return ensure(self,module) end;return fixtureEnsure(self,module) end
 local loaded,load=C_AddOns.IsAddOnLoaded,C_AddOns.LoadAddOn
 local loads=0
 C_AddOns.IsAddOnLoaded=function(name) if name=="LycheeGroup_Group" then return a.Group~=nil,a.Group~=nil end;return loaded(name) end
 C_AddOns.LoadAddOn=function(name) if name=="LycheeGroup_Group" then loads=loads+1;a.Group=g;return true end;return load(name) end
 dofile("addon/LycheeGroup/Entrypoints.lua")
 a:SetSetting("reduceMotion",true);a:Open("notes");local page=u.pages.notes
 T.eq(loads,0,"notes counters do not eagerly load Group")
 T.eq(page.tabs.history.count:GetText(),"—")
 if closing then a:SetSetting("reduceMotion",false);u:Hide() end
 local counts,rows=0,0;local refreshCounts,refreshHistory=page.RefreshCounts,page.RefreshHistory
 function page:RefreshCounts() counts=counts+1;return refreshCounts(self) end
 function page:RefreshHistory() rows=rows+1;return refreshHistory(self) end
 if loadAt=="history" then page:SelectTab("history") else a:Ensure("Group") end
 T.eq(loads,1)
 if loadAt=="history" then
  T.eq(page.tabs.history.count:GetText(),"0","first history entry shows its newly loaded storage count")
  T.eq(f.subscriptions,1,"first history load subscribes once despite the readiness refresh")
 end
 Complete(g)
 if closing then
  T.eq(counts,0);T.eq(rows,0,"module readiness while closing does not render Notes")
  a:Open("notes")
 end
 T.eq(page.tabs.history.count:GetText(),"1","real module readiness joins a visible notes counter")
 local calls=f.subscriptionCalls;a:Ensure("Group")
 T.eq(f.subscriptionCalls,calls,"an already-ready Group does not repeat its handoff")
 page:SelectTab("history");T.eq(#page.historyList.ids,1)
 Complete(g);T.eq(#page.historyList.ids,2)
 u:Hide(true);T.eq(f.subscriptions,0)
 C_AddOns.IsAddOnLoaded,C_AddOns.LoadAddOn=loaded,load
end

-- Search can finish after its page has yielded native input to Settings.
-- Actual FailSearch -> BeginSearch -> Group Notify must preserve the exit frame.
do
 local f=Fixture();local a,u,g=f.A,f.U,f.G
 a:SetSetting("reduceMotion",true)
 dofile("addon/LycheeGroup_Group/Search.lua")
 dofile("addon/LycheeGroup_Group/Results.lua")
 C_LFGList.GetLanguageSearchFilter=function() return {} end
 C_LFGList.Search=function() end
 function g:HasViews() return next(self.views)~=nil end
 a:Open("find")
 T.eq(g.Search:Search("seasonDungeon",2,"native"),true)
 T.eq(g.Search.state,"searching")
 a:Open("settings",{section="blocks"});local page=u.pages.settings
 g.Results:BlockTitle("Blocked group","Blocked-Home")
 T.eq(#page.blocksList.ids,1)
 local refresh,renders=page.RefreshBlocks,0
 function page:RefreshBlocks() renders=renders+1;return refresh(self) end
 a:SetSetting("reduceMotion",false);u:Hide();T.ok(u.hiding);T.ok(u.frame:IsShown())
 renders=0;g.Search:OnSearchFailed("timeout")
 T.eq(g.Search.state,"idle","the real in-flight search completes after Find leaves")
 T.eq(renders,0,"real search failure does not redraw the closing block list")
 g.Results:BlockTitle("New blocked group","Latest-Home")
 T.eq(renders,0,"block changes during close preserve the frame")
 a:Open("settings",{section="blocks"})
 T.eq(#page.blocksList.ids,2,"reopen synchronizes the current saved leaders")
 T.eq(f.subscriptions,1)
 a:Open("settings",{section="blocks"});T.eq(f.subscriptions,1)
 page:SelectSection("general");T.eq(f.subscriptions,0)
 renders=0;g.Results:BlockTitle("Elsewhere","Elsewhere-Home")
 T.eq(renders,0,"leaving blocks releases its result listener")
 page:SelectSection("blocks");T.eq(#page.blocksList.ids,3)
 u:Hide(true);T.eq(f.subscriptions,0)
end
