-- Effective layout defaults stay separate from UI-only projections and drags.
local Fixture=dofile("tests/ui_fixture.lua")
local cases={
 {id="findResults",column="title",page="find"},
 {id="findRaidResults",column="title",page="find"},
 {id="findApplications",column="title",page="find"},
 {id="createApplicants",column="name",page="create"},
 {id="notesRecords",column="player",page="notes"},
 {id="notesHistory",column="activity",page="notes"},
 {id="notesHistoryMembers",column="player",page="notes"},
 {id="blockedLeaders",column="name",page="settings"},
}
local function Header(f,case)
 local a,u=f.A,f.U
 if case.page=="create" then f.G.listing={activityID=2,name="Audit listing",comment=""} end
 a:Open(case.page)
 if case.id=="findRaidResults" then u.pages.find:SelectCategory("seasonRaid");u.pages.find:ClosePicker();return u.pages.find.resultsHeader end
 if case.id=="findResults" then return u.pages.find.resultsHeader end
 if case.id=="findApplications" then return u.pages.find.applicationHeader end
 if case.id=="createApplicants" then return u.pages.create.applicantTable end
 if case.id=="notesRecords" then return u.pages.notes.noteHeader end
 if case.id=="notesHistory" then u.pages.notes:SelectTab("history");return u.pages.notes.historyHeader end
 if case.id=="notesHistoryMembers" then u.pages.notes:OpenRun({members={}});return u.pages.notes.historyModal.header end
 u.pages.settings:SelectSection("blocks");return u.pages.settings.blocksHeader
end
local function LayoutKey(case) return "layout.tables."..case.id..".widths."..case.column end
local function Theme(case)
 return {schema=1,id="layout.defaults.audit",revision=1,layout={tables={[case.id]={widths={[case.column]=.6}}}}}
end
local function ResetPositionButton(f)
 f.A:Open("settings");local page=f.U.pages.settings;page:SelectSection("floating")
 for _,row in ipairs(page.panels.floating.rows) do if row.action then return row.action end end
 error("missing floating position reset action")
end

for _,locale in ipairs({"zhCN","enUS"}) do
 for _,case in ipairs(cases) do
  local f=Fixture(locale,nil,{reduceMotion=true},Theme(case));local a,u=f.A,f.U;local config=a.Configuration
  local key=LayoutKey(case);local h=Header(f,case);local label=locale.." "..case.id
  T.eq(h.state,a.Appearance:GetTableState(case.id),label.." uses the effective state")
  T.eq(h.state.widths[case.column],.6);T.eq(config:GetSource(key).kind,"theme")
  local original=h.columns[case.column].width
  -- A repeated reset has no effective Configuration change to notify consumers.
  for _=1,2 do h:ResetWidths();T.eq(h.state.widths[case.column],.6,label.." same-value theme reset");T.near(h.columns[case.column].width,original,.001) end
  T.eq(a.charPrefs.uiConfig.user[key],nil,label.." reset does not pin a default")
  T.ok(config:ApplyPreset("layout.defaults.audit",1,{[key]=.6},{storage="account"}))
  h:ResetWidths();T.eq(h.state.widths[case.column],.6,label.." same-value preset reset")
  T.ok(config:Set({[key]=.6},{storage="character"}))
  h:ResetWidths();T.eq(h.state.widths[case.column],.6,label.." equal user override resets to preset")
  T.eq(a.charPrefs.uiConfig.user[key],nil)
  T.ok(config:Set({[key]=.2},{storage="character"}))
  T.ok(config:RegisterPreset("layout.defaults.audit",2,{[key]=.7},{storage="account"}))
  T.eq(config:Get(key),.2,label.." package upgrade preserves the user override")
  T.eq(h.state.widths[case.column],.2)
  h:ResetWidths();T.eq(h.state.widths[case.column],.7,label.." reset reveals upgraded package")
  T.eq(config:GetSource(key).kind,"preset")
  T.ok(config:Set({[key]=.5},{storage="account"}))
  T.ok(config:Set({[key]=.5},{storage="character"}))
  h:ResetWidths();T.eq(h.state.widths[case.column],.5,label.." same-value reset reveals account user width")
  T.eq(config:GetSource(key).storage,"account")
  T.ok(config:Reset(key,{storage="account"}));T.eq(h.state.widths[case.column],.7)
  a:Open(case.page=="settings" and "notes" or "settings");h=Header(f,case)
  T.eq(h.state.widths[case.column],.7,label.." reentry retains effective package width")
  -- An external change cancels unfinished geometry before installing new state.
  local mouse=IsMouseButtonDown;IsMouseButtonDown=function() return true end
  h:StartDrag(1);f.S.cursorX=f.S.cursorX+23*h:GetEffectiveScale();h:UpdateDrag()
  T.ok(h.drag,label.." real drag is active")
  T.ok(config:Set({[key]=.4},{storage="character"}))
  T.eq(h.drag,nil,label.." API update cancels the old drag")
  T.eq(h:GetScript("OnUpdate"),nil)
  T.eq(h.state.widths[case.column],.4,label.." stale drag cannot replace the new projection")
  T.eq(config:Get(key),.4);T.eq(a.charPrefs.uiConfig.user[key],.4)
  local after=h.columns[case.column].width;h:Layout(h.layoutWidth)
  T.near(h.columns[case.column].width,after,.001,label.." the new geometry is stable")
  h:StartDrag(1);f.S.cursorX=f.S.cursorX+17*h:GetEffectiveScale();h:UpdateDrag()
  T.ok(config:Reset(key,{storage="character"}))
  T.eq(h.drag,nil);T.eq(h.state.widths[case.column],.7,label.." external reset also cancels old drag")
  h:StartDrag(1);f.S.cursorX=f.S.cursorX+13*h:GetEffectiveScale();h:UpdateDrag()
  T.ok(config:RegisterPreset("layout.defaults.audit",3,{[key]=.65},{storage="account"}))
  T.eq(h.drag,nil);T.eq(h.state.widths[case.column],.65,label.." package upgrade cancels old drag")
  IsMouseButtonDown=mouse;u:Hide(true)
 end

 local f=Fixture(locale,nil,{reduceMotion=true});local a,u,g=f.A,f.U,f.G;local config=a.Configuration
 local sortKey="layout.tables.createApplicants.sortKey";local direction="layout.tables.createApplicants.descending"
 local values={[sortKey]="mapScore",[direction]=true}
 T.ok(config:ApplyPreset("layout.sort.audit",1,values,{storage="account"}))
 local function Member(name,score) return {name=name,nameKey=name.."-Home",class="MAGE",assignedRole="DAMAGER",dungeonScores={mapScore=score},rating=score,itemLevel=score} end
 g.applicants={
  [1]={id=1,status="applied",displayOrderID=1,members={Member("One",100)}},
  [2]={id=2,status="applied",displayOrderID=2,members={Member("Two",200)}},
 }
 a:Open("create");local p=u.pages.create;local canonical=a.Appearance:GetTableState("createApplicants")
 T.eq(p.sortChoice.value,"newest");T.eq(canonical.sortKey,"mapScore","unsupported context retains canonical sort")
 T.eq(canonical.descending,true)
 g.listing={activityID=2,name="Keystone",comment=""};g:Notify("listing")
 T.eq(p.sortChoice.value,"mapScore");T.same(p.appIDs,{2,1},"supported context restores the package sort")
 T.eq(p.applicantTable.state,canonical)
 g.listing.activityID=1;g:Notify("listing")
 T.eq(p.sortChoice.value,"newest");T.eq(canonical.sortKey,"mapScore")
 a:Open("settings");g.listing.activityID=2;a:Open("create")
 T.eq(p.sortChoice.value,"mapScore");T.same(p.appIDs,{2,1})
 T.ok(config:Set({[sortKey]="ilvl",[direction]=false},{storage="character"}))
 T.ok(config:RegisterPreset("layout.sort.audit",2,{[sortKey]="rating",[direction]=true},{storage="account"}))
 T.eq(config:Get(sortKey),"ilvl");T.eq(p.sortChoice.value,"ilvl");T.same(p.appIDs,{1,2})
 g.listing.activityID=1;g:Notify("listing");T.eq(p.sortChoice.value,"ilvl")
 T.ok(config:Reset({sortKey,direction},{storage="character"}))
 T.eq(p.sortChoice.value,"newest");T.eq(canonical.sortKey,"rating")
 g.listing.activityID=2;g:Notify("listing")
 T.eq(p.sortChoice.value,"score");T.same(p.appIDs,{2,1})
 T.eq(a.charPrefs.uiConfig.user[sortKey],nil);T.eq(a.charPrefs.uiConfig.user[direction],nil)
 u:Hide(true)

 -- Window/rail/entry preferences share the same defaults/user/reset ordering.
 local position={point="CENTER",relativePoint="CENTER",x=15,y=20}
 local definition={schema=1,id="layout.viewport.audit",revision=1,layout={
  window={width=1400,height=900},find={railCollapsed=false},floating={position=position},
 }}
 f=Fixture(locale,nil,{reduceMotion=true},definition);a,u,g=f.A,f.U,f.G;config=a.Configuration
 a:Open("find")
 T.eq(u.preferredWindowWidth,1400);T.eq(u.preferredWindowHeight,900)
 T.eq(u.windowWidth,1400);T.eq(u.windowHeight,900)
 T.eq(u.pages.find.rail:GetWidth(),u.Theme.findSidebarWidth)
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua");local floating=a.Floating
 floating:Bind(g);floating:UpdateSettings()
 local function CheckPosition(expected,message)
  local point,relative,relativePoint,x,y=floating.frame:GetPoint()
  T.eq(point,expected.point,message);T.eq(relative,UIParent);T.eq(relativePoint,expected.relativePoint)
  T.eq(x,expected.x);T.eq(y,expected.y)
 end
 CheckPosition(position,"startup theme position")
 for key in pairs(config:GetSchema()) do if key:match("^layout%.") then
  T.eq(a.charPrefs.uiConfig.user[key],nil,"page construction does not pin layout defaults")
  T.eq(a.db.uiConfig.user[key],nil)
 end end
 local preset={
  ["layout.window.width"]=1450,["layout.window.height"]=920,["layout.find.railCollapsed"]=true,
  ["layout.floating.position"]={point="TOPLEFT",relativePoint="TOPLEFT",x=30,y=-40},
 }
 T.ok(config:ApplyPreset("layout.viewport.audit",1,preset,{storage="account"}))
 T.eq(u.windowWidth,1450);T.eq(u.windowHeight,920)
 T.eq(u.pages.find.rail:GetWidth(),u.Theme.findCollapsedSidebarWidth);CheckPosition(preset["layout.floating.position"],"live preset position")
 T.ok(a.Appearance:SaveWindowSize(1350,850));u.pages.find:SetSidebarCollapsed(false,false)
 floating.button:Fire("OnDragStart")
 floating.frame:ClearAllPoints();floating.frame:SetPoint("CENTER",UIParent,"CENTER",45,55)
 floating.button:Fire("OnDragStop")
 local saved={point="CENTER",relativePoint="CENTER",x=45,y=55}
 T.same(config:Get("layout.floating.position"),saved,"actual entry drag writes user position")
 preset["layout.window.width"],preset["layout.window.height"]=1500,950
 preset["layout.floating.position"].x=60
 T.ok(config:RegisterPreset("layout.viewport.audit",2,preset,{storage="account"}))
 T.eq(u.windowWidth,1350);T.eq(u.windowHeight,850);CheckPosition(saved,"user position survives package upgrade")
 T.eq(u.pages.find.rail:GetWidth(),u.Theme.findSidebarWidth)
 T.ok(config:Reset({"layout.window.width","layout.window.height","layout.find.railCollapsed"},{storage="character"}))
 local reset=ResetPositionButton(f);reset:Fire("OnClick","LeftButton")
 T.eq(a.db.uiConfig.user["layout.floating.position"],nil,"the reset button clears user position instead of pinning false")
 T.eq(config:GetSource("layout.floating.position").kind,"preset")
 T.eq(u.windowWidth,1500);T.eq(u.windowHeight,950)
 CheckPosition(preset["layout.floating.position"],"position reset reveals upgraded package")
 T.ok(config:Set({["layout.floating.position"]=false},{storage="account"}))
 T.eq(config:Get("layout.floating.position"),false,"false remains an explicit automatic-position preference")
 T.eq(config:GetSource("layout.floating.position").kind,"user")
 reset:Fire("OnClick","LeftButton");CheckPosition(preset["layout.floating.position"],"reset removes an explicit automatic-position override")
 T.ok(config:ActivatePreset(false,{storage="account"}));CheckPosition(position,"without a package the reset inherits the startup theme position")
 a:Open("notes");a:Open("find")
 T.eq(u.windowWidth,1400);T.eq(u.pages.find.rail:GetWidth(),u.Theme.findSidebarWidth)
 u:Hide(true)
 f=Fixture(locale,nil,{reduceMotion=true});a,u=f.A,f.U
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua");floating=a.Floating
 floating:Bind(f.G);floating:UpdateSettings()
 T.ok(a.Appearance:SaveFloatingPosition(position));reset=ResetPositionButton(f);reset:Fire("OnClick","LeftButton")
 T.eq(a.Configuration:Get("layout.floating.position"),false)
 T.eq(a.Configuration:GetSource("layout.floating.position").kind,"default")
 CheckPosition({point="TOPLEFT",relativePoint="TOPLEFT",x=floating.context.Theme.floatingFrameTopleftX,y=floating.context.Theme.floatingFrameTopleftY},"no package/theme position uses the built-in anchor")
 u:Hide(true)
end
