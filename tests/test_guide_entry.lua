-- Standalone: lua tests/test_guide_entry.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Equal(actual,expected,message) Check(actual==expected,message) end
local bootstrap="addon/LycheeGroup_Guide/Bootstrap.lua"
local entryFile="addon/LycheeGroup_Guide/Entry.lua"
local function LoadEntry(A) dofile(bootstrap);dofile(entryFile);return A.GuideEntry end

-- The main bootstrap registers a developer command without loading any UI/data.
do
 local oldSlash=function() end
 SlashCmdList={LYCHEEGROUP=oldSlash};local slash=SlashCmdList
 local modules={UI="LycheeGroup_UI",Group="LycheeGroup_Group"}
 local legacy=function() error("legacy OpenGuide must not be changed or used") end
 local calls={db=0,ui=0,load=0,open=0}
 local A={MODULES=modules,OpenGuide=legacy};_G.LycheeGroup=A
 function A:GetLocale() return "enUS" end
 function A:LoadDB() calls.db=calls.db+1;self.db=self.db or {} end
 function A:Ensure(module) Equal(module,"UI","manual entry loads only UI");calls.ui=calls.ui+1;return self.UI end
 function A:Print(message) self.message=message end
 A.UI={}
 local create,timers=CreateFrame,C_Timer
 CreateFrame=function() error("bootstrap allocated a frame") end
 C_Timer=setmetatable({},{__index=function() error("bootstrap read the scheduler") end})
 C_AddOns={LoadAddOn=function(name)
  Equal(name,"LycheeGroup_Guide","complete tour is demand-loaded");calls.load=calls.load+1
  A.Guide={Open=function(_,...) Equal(select("#",...),0,"welcome has no route argument");calls.open=calls.open+1;return true,"opened" end}
  return true
 end}
 dofile(bootstrap);CreateFrame,C_Timer=create,timers
 local E=A.GuideEntry
 Equal(calls.db,0,"bootstrap does not load saved variables");Equal(calls.ui,0,"bootstrap does not load UI");Equal(calls.load,0,"bootstrap does not load Guide")
 Equal(SlashCmdList,slash,"slash table is preserved");Equal(SlashCmdList.LYCHEEGROUP,oldSlash,"player command is preserved")
 Equal(SlashCmdList.LYCHEEGROUPGUIDE,nil,"no independent slash is registered")
 Equal(A.DevCommands.guide.usage,"/lg dev guide","manual guide belongs to developer commands")
 Equal(A.MODULES,modules,"module map is preserved");Equal(A.MODULES.Guide,nil,"Guide stays outside the ordinary module map");Equal(A.OpenGuide,legacy,"legacy method is untouched")
 Check(not E:HasSeen(),"cold account has not seen the welcome")
 Check(E:Open(),"manual welcome opens");Check(A.db.guide.welcomeShown and E:HasSeen(),"manual welcome consumes the account's first opportunity")
 A.DevCommands.guide.run("  ");Check(E:Open(),"manual welcome remains reusable")
 Equal(calls.load,1,"manual package loading is attempted once");Equal(calls.open,3,"manual action remains reusable")
 local before=calls.db;A.DevCommands.guide.run("invalid");Equal(calls.db,before,"invalid command does not load data or UI")
 Check(A.message:find("/lg dev guide",1,true),"invalid command prints usage")
 local sentinel={};A.Guide.Open=function() error(sentinel,0) end
 local ok,err=pcall(E.Open,E);Check(not ok and err==sentinel and not E.opening,"exceptions release the opening guard")
end

-- Failure remains one explicit LoD attempt and never marks an unseen account.
for _,throws in ipairs({false,true}) do
 local A={db={},GetLocale=function() return "enUS" end,LoadDB=function() end,Ensure=function() return {} end};_G.LycheeGroup=A
 local loads=0;C_AddOns={LoadAddOn=function() loads=loads+1;if throws then error("load crash",0) end;return false,"missing" end}
 dofile(bootstrap)
 local ran,ok,err=pcall(A.GuideEntry.Open,A.GuideEntry)
 Check(throws and not ran or not throws and ran and not ok and err=="missing","manual loader preserves failure semantics")
 A.GuideEntry:Open();Equal(loads,1,"manual load failure is not retried")
 Check(not A.GuideEntry:HasSeen() and not A.db.guide,"failed loading leaves account state unconsumed")
end

local MakeFixture=dofile("tests/ui_fixture.lua")
local function Fixture(locale,settings,saved)
 local f=MakeFixture(locale,nil,settings or {reduceMotion=true})
 local existing=f.A.GuideEntry
 if existing then
  existing:ReleaseShow()
  local record=existing.settingsInstall
  if record and record.active then
   record.active=false
   if record.owner[record.key]==record.wrapper then record.owner[record.key]=record.original end
   record.owner,record.key,record.wrapper=nil,nil,nil
  end
 end
 f.A.GuideEntry=nil;f.A.db.guide=saved or {}
 return f
end
local function MockGuide(A,options)
 options=options or {};local calls={loads=0,opens=0,starts=0}
 C_AddOns.LoadAddOn=function(name)
  Equal(name,"LycheeGroup_Guide","correct LoD package");calls.loads=calls.loads+1
  if options.failure then return false,"missing guide" end
  if options.throw then error("loader exception",0) end
  A.Guide={Open=function()
   calls.opens=calls.opens+1
   if options.refuse then return false,"welcome unavailable" end
   if not A.UI:IsShown() then A.UI:Show("find") end
   return true
  end,Start=function() calls.starts=calls.starts+1;error("automatic entry must not start a tour") end}
  return true
 end
 return calls
end

for _,locale in ipairs({"zhCN","enUS"}) do for _,fontScale in ipairs({70,100,130}) do
 local f=Fixture(locale,{reduceMotion=true,fontScale=fontScale});local A,U=f.A,f.U
 local calls=MockGuide(A);local originalShow,originalBuild,originalFont=U.Show,U.pages.settings.Build,U.ApplyFont
 local nodes,timers=#f.S.nodes,f.base.PendingTimers();local E=LoadEntry(A)
 Equal(#f.S.nodes,nodes,"entry installation creates no objects")
 Check(U.Show~=originalShow and U.pages.settings.Build~=originalBuild,"unseen account installs bounded Show and settings Build wrappers")
 A:Open("find")
 Equal(calls.loads,1,"first ordinary window loads Guide");Equal(calls.opens,1,"first ordinary window opens only the welcome");Equal(calls.starts,0,"first opening never starts a provider")
 Check(A.db.guide.welcomeShown and E:HasSeen(),"successful welcome is remembered per account")
 Equal(U.Show,originalShow,"successful automatic opening restores Show");Equal(E.showInstall,nil,"automatic opening releases its Show lease")
 Equal(U.ApplyFont,originalFont,"entry never leases font application")
 Check(not E.hint and not E.fontInstall and not E.Dismiss and not E.UpdateHint and not E.LayoutHint,"the obsolete invitation and its API are removed")
 Equal(U.guideSession,nil,"entry adds no UI tour state");Equal(U.NotifyGuide,nil,"entry adds no UI guide dispatcher")
 A:Open("find");Equal(calls.opens,1,"later ordinary windows never reopen the welcome")
 A:Open("settings");Equal(U.pages.settings.Build,originalBuild,"first settings construction restores Build")
 Check(E.settingsRow and E.settingsButton==E.settingsRow.control,"entry owns its appended settings action")
 local rows=#U.pages.settings.panels.general.rows;E:AddSettingsRow();Equal(#U.pages.settings.panels.general.rows,rows,"settings action is added once")
 Check(E.settingsButton.label:GetUnboundedStringWidth()<=E.settingsButton:GetWidth()+.001,"settings action fits both locales and supported font sizes")
 local button=E.settingsButton;local reset=A.Appearance.SaveFloatingPosition
 A.Appearance.SaveFloatingPosition=function() error("guide action called the old reset-position behavior") end
 button:SetEnabled(false);button:Fire("OnClick","LeftButton");Equal(calls.opens,1,"disabled button cannot open")
 button:SetEnabled(true);U.hiding=true;button:Fire("OnClick","LeftButton");U.hiding=nil;Equal(calls.opens,1,"hiding blocks entry")
 button.pressCancelled=true;button:Fire("OnClick","LeftButton");Equal(calls.opens,1,"cancelled press cannot open")
 button.pressedKey="different-target";button:Fire("OnClick","LeftButton");Equal(calls.opens,1,"rebound press cannot open")
 button:Fire("OnMouseDown","LeftButton");button:Fire("OnClick","LeftButton");Equal(calls.opens,2,"settings action can manually reopen the welcome")
 A.DevCommands.guide.run("");Equal(calls.opens,3,"developer command can manually reopen");Equal(calls.loads,1,"manual reuse does not reload the package")
 A.Appearance.SaveFloatingPosition=reset
 Equal(f.base.PendingTimers(),timers,"entry adds no timers");Equal(E.settingsInstall,nil,"settings installer releases ownership")
end end

-- Account metadata survives fresh UI/bootstrap instances (another character or reload).
do
 local saved={};local f=Fixture("enUS",nil,saved);local calls=MockGuide(f.A);LoadEntry(f.A);f.A:Open("find")
 Equal(calls.opens,1,"first character sees the welcome");Check(saved.welcomeShown,"state is written into the existing account table")
 local second=Fixture("zhCN",nil,saved);local nextCalls=MockGuide(second.A);local show=second.U.Show;local E=LoadEntry(second.A)
 second.A:Open("find");Equal(nextCalls.loads,0,"another character does not load Guide again");Equal(second.U.Show,show,"seen account does not install Show lease");Check(E:HasSeen(),"another character reads account-wide state")
end
for _,flag in ipairs({"welcomeShown","dismissed","completed"}) do
 local saved={[flag]=true,completedVersion=7};local f=Fixture("enUS",nil,saved);local calls=MockGuide(f.A)
 local E=LoadEntry(f.A);f.A:Open("find");Equal(calls.loads,0,"saved "..flag.." prevents automatic loading")
 Check(E:Open(),"saved state still permits manual reopening");Equal(saved.completedVersion,7,"manual entry preserves older completion metadata");Check(saved[flag],"manual entry preserves older opt-out/completion state")
end

-- Every blocked Show retains the opportunity until a later ordinary Show.
for _,condition in ipairs({"preview","combat","modal","hiding","opening","uiOpening"}) do
 local f=Fixture("enUS");local A,U=f.A,f.U;local calls=MockGuide(A)
 U:Show("find");dofile(bootstrap);local E=A.GuideEntry
 local combat=InCombatLockdown
 if condition=="preview" then U.preview={}
 elseif condition=="combat" then InCombatLockdown=function() return true end
 elseif condition=="modal" then U.activeModal={}
 elseif condition=="hiding" then U.hiding=true
 elseif condition=="opening" then E.opening=true
 else U.opening=true end
 dofile(entryFile)
 -- Exercise the installer around a successful ordinary Show without depending
 -- on native navigation's own modal/preview cleanup.
 local record=E.showInstall
 record.original=function() return "shown",nil,42 end
 local a,b,c=U:Show("find")
 Equal(a,"shown","Show return values survive automatic deferral");Equal(b,nil,"nil return slot survives");Equal(c,42,"trailing return slot survives")
 Equal(calls.loads,0,condition.." defers package loading");Check(not E:HasSeen() and E.showInstall==record and not E.autoAttempted,condition.." does not consume or release the first opportunity")
 U.preview,U.activeModal,U.hiding,U.opening,E.opening=nil,nil,nil,nil,nil;InCombatLockdown=combat
 U:Show("find");Equal(calls.opens,1,condition.." permits the next ordinary Show");Check(E:HasSeen() and not E.showInstall,condition.." eventually consumes the account opportunity")
end

-- Preview's real entry/exit path also delays the welcome until ordinary UI use.
do
 local f=Fixture("enUS");local calls=MockGuide(f.A);local E=LoadEntry(f.A)
 Check(f.U:StartPreview("applications"),"normal preview opens")
 Equal(calls.loads,0,"preview does not load Guide");Check(E.showInstall and not E:HasSeen(),"preview preserves pending Show ownership")
 f.U:StopPreview(true);f.A:Open("find");Equal(calls.opens,1,"ordinary Show after preview opens the welcome once")
end

-- Restoring an installer never overwrites an outside wrapper installed later.
do
 local f=Fixture("enUS");local calls=MockGuide(f.A);local E=LoadEntry(f.A);local inner=f.U.Show
 local count=0;local foreign=function(owner,...) count=count+1;return inner(owner,...) end
 f.U.Show=foreign;f.A:Open("find")
 Equal(f.U.Show,foreign,"foreign Show wrapper retains ownership");Equal(E.showInstall,nil,"foreign wrapper retains no active entry lease")
 f.A:Open("find");Equal(count,2,"inactive proxy still forwards to the original Show");Equal(calls.opens,1,"foreign retained proxy cannot reopen welcome")
 local page=f.U.pages.settings;local build=page.Build
 local foreignBuild=function(owner,...) return build(owner,...) end;page.Build=foreignBuild
 f.A:Open("settings");Equal(page.Build,foreignBuild,"foreign settings Build wrapper retains ownership");Equal(E.settingsInstall,nil,"settings lease is released through a foreign chain")
end

-- Already visible installation and manual first-use entry both consume once.
do
 local f=Fixture("zhCN",nil,{welcomeShown=true});f.A:Open("settings");f.A.db.guide={}
 local show,build=f.U.Show,f.U.pages.settings.Build;local calls=MockGuide(f.A);local E=LoadEntry(f.A)
 Equal(calls.opens,1,"entry installed onto a visible ordinary window opens immediately")
 Equal(f.U.Show,show,"visible installation leaves no Show wrapper");Equal(f.U.pages.settings.Build,build,"constructed settings leave no Build wrapper");Check(E.settingsRow,"constructed settings gain their own action")
end
do
 local f=Fixture("enUS");local calls=MockGuide(f.A);local show=f.U.Show;local E=LoadEntry(f.A)
 Check(E:Open(),"manual welcome before first Show opens")
 Equal(calls.opens,1,"manual internal Show does not recursively open a welcome");Equal(f.U.Show,show,"manual first entry restores pending Show")
 Check(E:HasSeen() and not E.showInstall,"manual first entry consumes automatic opportunity")
 f.A:Open("find");Equal(calls.opens,1,"ordinary opening after manual welcome stays quiet")
end

for _,kind in ipairs({"failure","throw","refuse"}) do
 local f=Fixture("enUS");local calls=MockGuide(f.A,{[kind]=true});local show=f.U.Show
 local messages={};f.A.Print=function(_,message) messages[#messages+1]=message end
 local E=LoadEntry(f.A);f.A:Open("find")
 Check(not E:HasSeen() and not f.A.db.guide.welcomeShown,"failed "..kind.." does not consume account state")
 Check(not E.showInstall and f.U.Show==show and not E.opening,"failed "..kind.." releases Show/opening ownership")
 Equal(#messages,1,"automatic "..kind.." displays one error")
 f.A:Open("find");Equal(calls.loads,1,"automatic "..kind.." does not retry in this session")
 if kind~="refuse" then E:Open();Equal(calls.loads,1,"manual action preserves the one-load-attempt contract after "..kind) end
end

-- Loading the real welcome must not resolve a directory activity, construct a
-- simulated provider, or start the tour. Those operations belong to Start.
do
 local f=Fixture("zhCN");local A,U=f.A,f.U;local loads=0
 C_AddOns.LoadAddOn=function(name)
  Equal(name,"LycheeGroup_Guide","real welcome loads the guide package");loads=loads+1
  for line in io.lines("addon/LycheeGroup_Guide/LycheeGroup_Guide.toc") do
   local file=line:match("^%s*(.-)%s*$")
   if file~="" and file:sub(1,1)~="#" then dofile("addon/LycheeGroup_Guide/"..file) end
  end
  A.Guide.ResolveActivity=function() error("welcome resolved an activity") end
  A.Guide.CreateProvider=function() error("welcome created a simulated provider") end
  A.Guide.Start=function() error("welcome started the tour") end
  return true
 end
 local E=LoadEntry(A);A:Open("settings")
 Equal(loads,1,"real first ordinary opening loads Guide once")
 Check(A.Guide.active and A.Guide.View.mode=="intro" and A.Guide.View.card:IsVisible(),"real first opening displays the existing welcome")
 Check(not A.Guide.steps and not A.Guide.Adapter.session and not U.preview,"real welcome owns no teaching steps or simulated session")
 Check(E:HasSeen() and A.db.guide.welcomeShown,"real welcome commits account metadata only after successful opening")
 A.Guide:Stop("later");A:Open("find")
 Check(not A.Guide.active and not E.showInstall and loads==1,"ordinary reopening after closing welcome stays quiet")
end
print(("guide entry checks passed: %d"):format(checks))
