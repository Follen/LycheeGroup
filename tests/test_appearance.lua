-- Product appearance uses the ordinary retained UI fixture and configuration API.
local Fixture=dofile("tests/ui_fixture.lua")
local function Float(a)
 Load.addon("LycheeGroup","Floating.lua")
 Load.addon("LycheeGroup","API.lua")
 a.Floating:UpdateSettings()
 return a.Floating
end

-- Defaults preserve both contexts' typography, and querying/activating defaults is not a user edit.
do
 local f=Fixture("enUS");local a,u=f.A,f.U;local c=a.Configuration
 local floating=Float(a)
 a:SetSetting("reduceMotion",true);a:Open("settings")
 local api=a.API.Appearance
 T.eq(api.version,1);T.eq(a.API.Configuration.version,1)
 local main=api:Get("main");local small=api:Get("floating")
 T.eq(main.font,a.Fonts:GetDefaultPath());T.eq(small.font,a.Fonts:GetDefaultPath())
 T.eq(main.fontSizeDelta,3);T.eq(main.lineHeightDelta,4)
 T.eq(small.fontSizeDelta,0);T.eq(small.lineHeightDelta,0)
 local text=u.C.Text(u.frame,"Default main","font14","text")
 T.eq(select(2,text:GetFont()),17,"main context keeps its existing three-unit font increase")
 T.eq(select(2,floating.count:GetFont()),16,"floating count keeps its existing default size")
 T.same(main.text,LycheeUI.ResolveTheme({},a.StyleDefaults.main).text)
 T.eq(api:GetSchema("main").font,nil,"the common selected font has a single setting owner")
 T.eq(api:Get("missing"),nil);T.eq(api:Set("missing",{}),false)
 T.ok(c:ApplyPreset("defaults",1,{["theme.main.font14"]=14}))
 T.eq(c:GetSource("theme.main.font14").kind,"preset")
 T.eq(a.db.uiConfig.user["theme.main.font14"],nil)
 T.eq(select(2,text:GetFont()),17)
 T.eq(u.context:SetTheme(a.Appearance:GetTheme("main")),false,"an identical resolved theme does not restyle widgets")
 T.eq(a.db.uiConfig.user["theme.main.font14"],nil)
 T.ok(api:Set("main",{font14=14},{storage="account"}))
 T.eq(c:GetSource("theme.main.font14").kind,"user","an explicit same-value user edit still pins")
 T.eq(a.db.uiConfig.user["theme.main.font14"],14)
 T.ok(c:RegisterPreset("defaults",2,{["theme.main.font14"]=18}))
 T.eq(select(2,text:GetFont()),17,"preset updates cannot replace a pinned token")
 T.ok(api:Reset("main","font14",{storage="account"}))
 T.eq(select(2,text:GetFont()),21)
end

-- Existing widgets update in their selected scope, retain identities, and issue no game requests.
do
 local f=Fixture("zhCN");local a,u,g,s=f.A,f.U,f.G,f.S
 local floating=Float(a)
 a:SetSetting("reduceMotion",true);a:Open("find")
 local frame,page,header=u.frame,u.pages.find,u.pages.find.resultsHeader
 local mainText=u.C.Text(frame,"Retained main","font14","text")
 local floatText=floating.context.C.Text(floating.frame,"Retained floating","font14","text")
 local mainSize,floatSize=select(2,mainText:GetFont()),select(2,floatText:GetFont())
 local requests=0
 g.Search.Search=function() requests=requests+1 end
 g.Publish=function() requests=requests+1 end
 g.Update=function() requests=requests+1 end
 g.Apply=function() requests=requests+1 end
 local nodeCount=#s.nodes
 T.ok(a.API.Appearance:Set("main",{text={.1,.2,.3,1},font14=18}))
 T.near(select(2,mainText:GetFont()),mainSize+4,.001)
 T.same({mainText:GetTextColor()},{.1,.2,.3,1})
 T.eq(select(2,floatText:GetFont()),floatSize)
 T.eq(u.frame,frame);T.eq(u.pages.find,page);T.eq(page.resultsHeader,header)
 T.ok(a.API.Appearance:Set("floating",{text={.3,.4,.5,1},font14=19,floatingEntryHeight=50}))
 T.eq(select(2,floatText:GetFont()),19)
 T.same({floatText:GetTextColor()},{.3,.4,.5,1})
 T.eq(floating.frame:GetHeight(),50)
 T.eq(select(2,mainText:GetFont()),mainSize+4)
 T.eq(requests,0,"visual changes do not search, apply or publish")
 T.eq(#s.nodes,nodeCount,"restyling retained objects does not rebuild the UI")
 T.eq(a.db.uiConfig.user["theme.main.font14"],nil,"default appearance writes remain session-only")
 T.ok(a.API.Configuration:Set({["settings.fontScale"]=130}))
 T.near(select(2,mainText:GetFont()),(18+3)*1.3,.001)
 T.near(select(2,floatText:GetFont()),19*1.3,.001)
 T.eq(u.frame,frame);T.eq(floating.context.Theme.font,a.Fonts:GetPath())
 T.ok(a.API.Configuration:ApplyPreset("external",1,{["theme.main.primary"]={.2,.3,.4,1}}))
 T.same(u.Theme.primary,{.2,.3,.4,1})
 T.ok(a.API.Configuration:RegisterPreset("external",2,{["theme.main.primary"]={.4,.5,.6,1}}))
 T.same(u.Theme.primary,{.4,.5,.6,1})
 T.eq(u.frame,frame);T.eq(u.pages.find,page);T.eq(page.resultsHeader,header)
 T.eq(requests,0,"package upgrades update retained visuals without business requests")
end

-- Saved visual leaves migrate before defaults, retaining business preferences and arrays.
do
 local position={point="TOPLEFT",relativePoint="TOPLEFT",x=20,y=-30}
 local businessFilters={sort="rating",minMembers="2"}
 local preferences={windowSize={width=1400,height=900},find={railCollapsed=true,categoryPrefs={seasonDungeon=businessFilters}},
  tableLayouts={findResults={widths={title=.2,leader=.15},sortKey="rating",descending=true}}}
 local account={floatingPosition=position}
 local f=Fixture("enUS",preferences,account);local a,c=f.A,f.A.Configuration
 T.eq(c:Get("layout.window.width"),1400);T.eq(c:Get("layout.window.height"),900)
 T.same(c:Get("layout.floating.position"),position)
 T.eq(c:Get("layout.find.railCollapsed"),true)
 T.eq(c:Get("layout.tables.findResults.widths.title"),.2)
 T.eq(c:Get("layout.tables.findResults.sortKey"),"rating")
 T.eq(c:Get("layout.tables.findResults.descending"),true)
 T.eq(preferences.find.categoryPrefs.seasonDungeon,businessFilters,"business filter records keep their identity")
 T.eq(preferences.uiConfig.user["layout.window.width"],1400)
 T.eq(account.uiConfig.user["layout.floating.position"].x,20)
 T.eq(account.uiConfig.user["layout.window.width"],nil)
 local state=a.Appearance:GetTableState("findResults")
 T.eq(state.sortKey,"rating");T.eq(state.descending,true)
 T.ok(a.Appearance:SaveTableState({state=state},{widths={title=.25}}))
 T.eq(a.Appearance:GetTableState("findResults"),state,"a retained header keeps the same state object")
 T.eq(state.widths.title,.25);T.eq(preferences.tableLayouts.findResults.widths.title,.25)
 T.ok(c:ApplyPreset("visual",1,{["layout.window.width"]=1500,["layout.floating.position"]=false,["layout.tables.findResults.sortKey"]=false}))
 T.eq(c:Get("layout.window.width"),1400)
 T.eq(c:Get("layout.tables.findResults.sortKey"),"rating")
 T.ok(c:Reset({"layout.window.width","layout.tables.findResults.sortKey"},{storage="character"}))
 T.eq(c:Get("layout.window.width"),1500);T.eq(c:Get("layout.tables.findResults.sortKey"),false)
 T.eq(preferences.windowSize.width,nil);T.eq(preferences.tableLayouts.findResults.sortKey,nil)
 T.ok(c:Reset("layout.floating.position",{storage="account"}))
 T.eq(c:Get("layout.floating.position"),false)
 T.eq(preferences.find.categoryPrefs.seasonDungeon,businessFilters)
end

-- Session changes disappear on reload, account/character choices keep their own scope.
do
 local account,first,second={},{},{}
 local f=Fixture("enUS",first,account);local a,c=f.A,f.A.Configuration
 T.ok(a.API.Appearance:Set("main",{font14=16},{storage="account"}))
 T.ok(a.API.Appearance:Set("main",{font14=17},{storage="character"}))
 T.ok(a.API.Appearance:Set("main",{font14=18}))
 T.eq(c:Get("theme.main.font14"),18)
 T.eq(account.uiConfig.user["theme.main.font14"],16);T.eq(first.uiConfig.user["theme.main.font14"],17)
 f=Fixture("enUS",second,account);a,c=f.A,f.A.Configuration
 T.eq(c:Get("theme.main.font14"),16)
 T.ok(a.Appearance:SaveWindowSize(1440,920));T.eq(second.windowSize.width,1440)
 T.eq(first.windowSize,nil)
 f=Fixture("enUS",first,account);a,c=f.A,f.A.Configuration
 T.eq(c:Get("theme.main.font14"),17)
 T.eq(c:Get("layout.window.width"),nil)
 T.eq(c:GetSource("theme.main.font14").storage,"character")
end

-- Passive layout/opening never pins profile defaults; actual header edits do.
do
 local f=Fixture("enUS");local a,u,g,s=f.A,f.U,f.G,f.S;local c=a.Configuration
 a:SetSetting("reduceMotion",true)
 local widths={title=.28,leader=.15,members=.18,ilvl=.07,rating=.07,description=.17,age=.08}
 local values={["layout.tables.findResults.sortKey"]="rating",["layout.tables.findResults.descending"]=true,["layout.find.railCollapsed"]=true}
 for key,width in pairs(widths) do values["layout.tables.findResults.widths."..key]=width end
 T.ok(c:ApplyPreset("tables",1,values))
 local activity=g.Catalog:GetActivity(2)
 for id,rating in ipairs({100,300,200}) do
  g.records[id]={id=id,name="Configured table "..id,activity=activity,activityID=2,activityName=activity.name,categoryID=2,
   leaderName="Leader"..id.."-Away",leaderKey="Leader"..id.."-Away",leaderRating=rating,numMembers=3,maxNumPlayers=5,age=id}
 end
 a:Open("find");local page=u.pages.find;page:CommitChoice();page:DoSearch()
 local header=page.resultsHeader;local initialFrame=page.frame
 T.eq(header.state.sortKey,"rating");T.eq(header.state.descending,true)
 T.same(page.results.ids,{2,3,1})
 T.eq(page.rail:GetWidth(),u.Theme.findCollapsedSidebarWidth)
 page:LayoutSize(u.content:GetWidth(),u.content:GetHeight())
 a:Open("settings");a:Open("find")
 T.eq(a.charPrefs.uiConfig.user["layout.tables.findResults.widths.title"],nil)
 T.eq(a.charPrefs.uiConfig.user["layout.tables.findResults.sortKey"],nil)
 T.eq(a.charPrefs.uiConfig.user["layout.find.railCollapsed"],nil)
 T.eq(a.charPrefs.uiConfig.user["layout.window.width"],nil)
 local requests=0;g.Search.Search=function() requests=requests+1 end
 values["layout.tables.findResults.sortKey"]="age";values["layout.tables.findResults.descending"]=false
 values["layout.tables.findResults.widths.title"]=.32;values["layout.tables.findResults.widths.leader"]=.11
 T.ok(c:RegisterPreset("tables",2,values))
 T.eq(page.resultsHeader,header);T.eq(page.frame,initialFrame)
 T.eq(header.state.sortKey,"age");T.same(page.results.ids,{1,2,3})
 T.near(header.columns.title.width/header:GetWidth(),.32,.001,"a package immediately updates the retained table geometry")
 local oldMouse=IsMouseButtonDown;local pressed=true
 IsMouseButtonDown=function() return pressed end
 s.cursorX=400;header.handles[1]:Fire("OnMouseDown","LeftButton")
 s.cursorX=400+18*header:GetEffectiveScale();header:Fire("OnUpdate",.016)
 T.eq(a.charPrefs.uiConfig.user["layout.tables.findResults.widths.title"],nil,"drag samples remain temporary")
 pressed=false;header:Fire("OnUpdate",.016);IsMouseButtonDown=oldMouse
 local pinned=a.charPrefs.uiConfig.user["layout.tables.findResults.widths.title"]
 T.ok(pinned)
 for _,button in ipairs(header.buttons) do if button.definition.key=="rating" then button:Fire("OnClick","LeftButton");break end end
 T.eq(header.state.sortKey,"rating")
 values["layout.tables.findResults.widths.title"]=.28;values["layout.tables.findResults.widths.leader"]=.15
 values["layout.tables.findResults.sortKey"]="members"
 values["layout.find.railCollapsed"]=true
 T.ok(c:RegisterPreset("tables",3,values))
 T.near(header.columns.title.width/header:GetWidth(),pinned,.001,"a later package update preserves the user's committed drag")
 T.eq(header.state.sortKey,"rating","a user's header click keeps sorting ownership")
 T.eq(requests,0)
 page.sidebarToggle:Fire("OnClick")
 T.eq(c:Get("layout.find.railCollapsed"),false)
 T.eq(a.charPrefs.uiConfig.user["layout.find.railCollapsed"],false)
 T.ok(c:RegisterPreset("tables",4,values))
 T.eq(page.rail:GetWidth(),u.Theme.findSidebarWidth,"a user's sidebar click has priority over package defaults")
end

-- Sidebar package defaults are live until an actual click assigns user ownership.
do
 local f=Fixture("enUS");local a,u,g=f.A,f.U,f.G;local c=a.Configuration
 a:SetSetting("reduceMotion",true)
 T.ok(c:ApplyPreset("rail",1,{["layout.find.railCollapsed"]=true}))
 a:Open("find");local page=u.pages.find
 T.eq(page.rail:GetWidth(),u.Theme.findCollapsedSidebarWidth)
 local requests=0;g.Search.Search=function() requests=requests+1 end
 T.ok(c:RegisterPreset("rail",2,{["layout.find.railCollapsed"]=false}))
 T.eq(page.rail:GetWidth(),u.Theme.findSidebarWidth,"a package change expands the already open sidebar")
 T.ok(c:RegisterPreset("rail",3,{["layout.find.railCollapsed"]=true}))
 T.eq(page.rail:GetWidth(),u.Theme.findCollapsedSidebarWidth)
 page.sidebarToggle:Fire("OnClick")
 T.eq(c:Get("layout.find.railCollapsed"),false)
 T.ok(c:RegisterPreset("rail",4,{["layout.find.railCollapsed"]=true}))
 T.eq(page.rail:GetWidth(),u.Theme.findSidebarWidth)
 T.eq(a.charPrefs.uiConfig.user["layout.find.railCollapsed"],false)
 T.eq(requests,0)
end

-- Theme dimensions are defaults; only explicit user resizing fixes the window dimensions.
do
 local f=Fixture("enUS");local a,u=f.A,f.U
 a:SetSetting("reduceMotion",true);a:Open("settings")
 T.eq(a.Configuration:Get("layout.window.width"),nil)
 T.ok(a.API.Appearance:Set("main",{width=1450}))
 T.eq(u.windowWidth,1450,"a theme width change reaches a window with no explicit user size")
 T.eq(a.charPrefs.uiConfig.user["layout.window.width"],nil)
 T.ok(a.Appearance:SaveWindowSize(1500,920))
 T.eq(u.windowWidth,1500);T.eq(u.windowHeight,920)
 T.ok(a.API.Appearance:Set("main",{width=1600,height=960}))
 T.eq(u.windowWidth,1500);T.eq(u.windowHeight,920,"theme changes retain the user's resized dimensions")
end

-- A saved/profile anchor must survive later theme-binding refreshes.
do
 local f=Fixture("enUS");local a=f.A;local floating=Float(a)
 local position={point="BOTTOMRIGHT",relativePoint="BOTTOMRIGHT",x=-120,y=160}
 T.ok(a.Configuration:ApplyPreset("anchor",1,{["layout.floating.position"]=position}))
 local function CheckPosition()
  local point,relative,relativePoint,x,y=floating.frame:GetPoint()
  T.eq(point,position.point);T.eq(relative,UIParent);T.eq(relativePoint,position.relativePoint)
  T.eq(x,position.x);T.eq(y,position.y)
 end
 CheckPosition()
 T.ok(a.API.Appearance:Set("floating",{floatingFrameTopleftX=80,text={.2,.3,.4,1}}))
 CheckPosition()
 T.ok(a.Appearance:SaveFloatingPosition({point="TOP",relativePoint="TOP",x=30,y=-80}))
 position={point="TOP",relativePoint="TOP",x=30,y=-80}
 T.ok(a.Configuration:RegisterPreset("anchor",2,{["layout.floating.position"]={point="CENTER",relativePoint="CENTER",x=0,y=0}}))
 CheckPosition()
end

-- Cross-token validation checks the final theme before committing any setting or layer.
do
 local f=Fixture("enUS");local a,u=f.A,f.U;local c=a.Configuration
 a:SetSetting("reduceMotion",true);a:Open("settings")
 local root=a.db.uiConfig;local users,presets,imported=root.user,root.presets,root.imported
 local initial=u.Theme.font12;local initialDelta=u.Theme.fontSizeDelta
 local ok,err=a.API.Appearance:Set("main",{font12=1,fontSizeDelta=-2},{storage="account"})
 T.eq(ok,false);T.eq(type(err),"string")
 T.eq(a.db.uiConfig,root);T.eq(root.user,users);T.eq(root.presets,presets);T.eq(root.imported,imported)
 T.eq(u.Theme.font12,initial);T.eq(u.Theme.fontSizeDelta,initialDelta)
 T.eq(c:GetSource("theme.main.font12").kind,"default")
 T.eq(c:Set({["theme.main.font12"]=1,["theme.main.fontSizeDelta"]=-2,["settings.uiScale"]=110},{storage="account"}),false)
 T.eq(a.db.uiScale,100);T.eq(root.user["settings.uiScale"],nil)
 T.ok(c:RegisterPreset("invalid-theme",1,{["theme.main.font12"]=1,["theme.main.fontSizeDelta"]=-2},{storage="account"}))
 T.eq(c:ActivatePreset("invalid-theme",{storage="account"}),false)
 T.eq(root.activePreset,nil)
 T.ok(c:ApplyPreset("valid-theme",1,{["theme.main.font12"]=4,["theme.main.fontSizeDelta"]=-2},{storage="account"}))
 T.eq(u.Theme.font12,4);T.eq(u.Theme.fontSizeDelta,-2)
 T.eq(c:RegisterPreset("valid-theme",2,{["theme.main.font12"]=1,["theme.main.fontSizeDelta"]=-2},{storage="account"}),false)
 T.eq(c:ExportPreset("valid-theme").revision,1)
 T.ok(a.API.Appearance:Set("main",{font12=10},{storage="account"}))
 T.ok(c:ActivatePreset("invalid-theme",{storage="account"}))
 T.eq(a.API.Appearance:Reset("main","font12",{storage="account"}),false,"reset cannot expose an invalid preset combination")
 T.eq(root.user["theme.main.font12"],10);T.eq(u.Theme.font12,10)
end
