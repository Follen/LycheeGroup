-- Real Floating/API state with a minimal standard LibDataBroker substitute.
local Fixture=dofile("tests/ui_fixture.lua")
local function Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function New(options)
 options=options or {}
 local f=Fixture(options.locale or "zhCN",nil,{reduceMotion=true,floating=options.floating~=false})
 f.ldb={objects={},creates=0};f.libraryReady=options.library~=false
 function f.ldb:GetDataObjectByName(name) return self.objects[name] end
 function f.ldb:NewDataObject(name,object)
  self.creates=self.creates+1;assert(not self.objects[name],"duplicate broker registration")
  self.objects[name]=object;return object
 end
 local metadata=C_AddOns.GetAddOnMetadata
 C_AddOns.GetAddOnMetadata=function(name,field)
  if name=="EllesmereUI" then return options.installed~=false and field=="Version" and "9.6.7" or nil end
  return metadata(name,field)
 end
 local function Library()
  return setmetatable({GetLibrary=function(_,name,silent)
   T.eq(name,"LibDataBroker-1.1");T.eq(silent,true,"missing optional libraries are queried silently")
   return f.libraryReady and f.ldb or nil
  end},{__call=function() return nil end})
 end
 if options.libstub~=false then _G.LibStub=Library() else _G.LibStub=nil end
 function f:LibraryReady() self.libraryReady=true;_G.LibStub=Library() end
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 f.F,f.API=f.A.Floating,f.A.API.Floating;f.F:Bind(f.G);f.F:UpdateSettings()
 local subscribe=f.API.Subscribe;f.subscriptions=0
 f.API.Subscribe=function(self,callback,options)
  f.subscriptions=f.subscriptions+1;T.eq(options and options.background,true,"broker explicitly requests state updates while the standalone entry is disabled")
  return subscribe(self,callback,options)
 end
 f.publicAttach=f.API.Attach
 f.API.Attach=function() error("broker must never attach to the Floating entry") end
 f.groupSubscriptions=Count(f.G.subs)
 local nodes=#f.S.nodes;dofile("addon/LycheeGroup/Adapters/DataBroker.lua")
 f.adapter=f.A.Adapters.DataBroker;f.events=f.S.nodes[nodes+1]
 T.eq(#f.S.nodes,nodes+1,"broker support creates only one event frame")
 T.eq(f.events:GetScript("OnUpdate"),nil)
 function f:Event(event,...)
  T.eq(self.events.events[event],true,"adapter event must be registered")
  self.events:Fire("OnEvent",event,...)
 end
 function f:Close()
  f.F:Dismiss()
  if self.adapter.unsubscribe then self.adapter.unsubscribe() end
  if self.U.frame then self.U:Hide(true) end
  self.A:SetSetting("floating",false)
 end
 return f
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,floating in ipairs({false,true}) do
  local f=New({locale=locale,floating=floating});local b=f.adapter
  local nodes=#f.S.nodes;f:Event("PLAYER_LOGIN");local object=b.object
  T.eq(object,f.ldb.objects["荔枝组队"]);T.eq(object.type,"data source")
  T.eq(object.icon,"Interface\\AddOns\\LycheeGroup\\Media\\lychee-logo.tga")
  T.eq(object.iconCoords[1],20/128);T.eq(object.iconCoords[2],106/128);T.eq(object.iconCoords[3],19/128);T.eq(object.iconCoords[4],105/128)
  T.eq(object.label,nil,"the host must not duplicate the plugin name beside broker text")
  T.eq(object.text,locale=="zhCN" and "荔枝组队" or "Lychee LFG")
  T.eq(f.events.events.PLAYER_LOGIN,nil);T.eq(f.events.events.ADDON_LOADED,nil)
  T.eq(f.U.frame,nil,"broker registration does not open or build the product window")
  T.eq(#f.S.nodes,nodes,"broker registration creates no visual controls")
  T.eq(Count(f.G.subs),f.groupSubscriptions,"Floating remains the only business subscriber")
  local host=f.F.host
  for _=1,12 do T.ok(b:Initialize()) end
  T.eq(b.object,object);T.eq(f.ldb.creates,1);T.eq(f.subscriptions,1)
  T.eq(#f.S.nodes,nodes);T.eq(f.F.host,host)
  f.G.apps={{id=1,status="applied",categoryID=2,name="Application",activityID=2}}
  f.G:Notify("applications")
  T.eq(object.text,locale=="zhCN" and "申请1个" or "Applied: 1","broker reads the actual public application summary even with the floating window disabled")
  T.eq(object.text,f.API:GetStatus().text);T.eq(f.API:GetStatus().count,1)
  f.A:SetSetting("floating",false)
  f.G.apps[2]={id=2,status="applied",categoryID=2,name="Second application",activityID=2};f.G:Notify("applications")
  T.eq(object.text,locale=="zhCN" and "申请2个" or "Applied: 2","the floating visibility setting never pauses broker state")
  T.eq(f.F.frame and f.F.frame:IsShown() or false,false)
  f.G.listing={activityID=1,name="Recruiting"};f.G.applicants={[7]={id=7,status="applied",members={{name="One-Away"},{name="Two-Away"}}}}
  f.G:Notify("listing");f.G:Notify("applicants")
  T.eq(object.text,locale=="zhCN" and "2人申请" or "2 applicants");T.eq(f.API:GetStatus().recruiting,true)
  T.eq(object.OnTooltipShow,nil,"hover uses the application panel rather than a separate text tooltip")
  T.eq(type(object.OnEnter),"function");T.eq(type(object.OnLeave),"function")
  f.G.applicants={};f.G:Notify("applicants")
  T.eq(object.text,locale=="zhCN" and "暂无申请" or "No applications")
  f.G.listing=nil;f.G.apps={};f.G:Notify("listing");f.G:Notify("applications")
  T.eq(object.text,locale=="zhCN" and "荔枝组队" or "Lychee LFG")
  T.eq(f.F.host,host);T.eq(#f.S.nodes,nodes,"state-only broker refreshes allocate no controls")
  b:Sync({text=""});T.eq(object.text,locale=="zhCN" and "荔枝组队" or "Lychee LFG","empty public text uses the localized name")
  T.eq(object.text:find("|T",1,true),nil,"text contains no embedded duplicate icon")
  object.OnClick(nil,"MiddleButton");T.eq(f.U.frame,nil)
  object.OnClick(nil,"LeftButton");T.ok(f.U:IsShown())
  object.OnClick(nil,"LeftButton");T.eq(f.U:IsShown(),false,"left click uses the real window toggle")
  object.OnClick(nil,"RightButton");T.ok(f.U:IsShown());T.eq(f.U.page,"settings")
  f:Close()
 end
end
do
 local f=New({library=false,libstub=false});local b=f.adapter;f:Event("PLAYER_LOGIN")
 T.eq(b.object,nil);T.eq(f.subscriptions,0);T.eq(f.events.events.ADDON_LOADED,true)
 f:Event("ADDON_LOADED","UnrelatedAddon");T.eq(b.object,nil)
 f:LibraryReady();f:Event("ADDON_LOADED","EllesmereUI")
 T.ok(b.object);T.eq(f.ldb.creates,1);T.eq(f.subscriptions,1);T.eq(f.events.events.ADDON_LOADED,nil)
 T.ok(b:Initialize());T.eq(f.ldb.creates,1);T.eq(f.subscriptions,1);f:Close()
end
do
 local f=New({library=false,installed=false});f:Event("PLAYER_LOGIN")
 T.eq(f.adapter.object,nil);T.eq(f.subscriptions,0);T.eq(next(f.events.events),nil,"an absent optional host leaves no event listener or polling")
 f:Close()
end
do
 local f=New({installed=false});f:Event("PLAYER_LOGIN")
 T.ok(f.adapter.object,"an existing standard broker library works without Ellesmere installed")
 T.eq(f.events.events.ADDON_LOADED,nil);f:Close()
end
do
 local f=New({floating=false,library=false,installed=false})
 local stop=f.API:Subscribe(function() end,{background=true})
 T.eq(f.F.backgroundStatusSubscribers,1)
 stop();T.eq(f.F.backgroundStatusSubscribers,0)
 stop();T.eq(f.F.backgroundStatusSubscribers,0,"releasing one background subscription twice never makes its count negative")
 local reads=0
 for _,name in ipairs({"GetApplications","GetApplicants","GetApplicant","GetListing"}) do
  local method=f.G[name];f.G[name]=function(self,...) reads=reads+1;return method(self,...) end
 end
 f.G.apps={{id=1,status="applied",categoryID=2,name="Unobserved",activityID=2}};f.G:Notify("applications")
 T.eq(reads,0,"a hidden floating entry stops reading business state after its last background consumer leaves")
 f:Close()
end

-- Broker hover opens the same interactive list independently of the standalone
-- entry. It never takes ownership of the display's icon, text or font.
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,floating in ipairs({false,true}) do
  local f=New({locale=locale,floating=floating});f:Event("PLAYER_LOGIN")
  local object=f.adapter.object;local F=f.F
  f.A:SetSetting("floatingCompatibility",false)
  local host=CreateFrame("Button",nil,UIParent);host:SetSize(92,30);host:SetPoint("TOPLEFT",UIParent,"TOPLEFT",300,-20);host:SetScale(1.45)
  local label=host:CreateFontString(nil,"OVERLAY");label:SetFont("Display.ttf",13,"OUTLINE");label:SetText("Display text")
  object.OnEnter(host)
  T.ok(F.panel:IsVisible(),"broker hover displays the application panel when standalone integration is disabled")
  T.eq(F.panel:GetParent(),UIParent);T.eq(F:GetAnchor(),host)
  T.eq(F.frame:IsShown(),floating,"hover preserves the standalone visibility preference")
  T.eq(F.host,nil,"popup anchoring does not attach or move the entry logo")
  T.eq(F.count,F.ownCount);T.eq(f.U.frame,nil,"hover does not construct the main window")
  T.eq(F.empty:GetText(),locale=="zhCN" and "暂无活动" or "No activity")
  T.near(F.panel:GetEffectiveScale(),f.A:GetSetting("floatingScale")/100*UIParent:GetEffectiveScale(),.001,"popup scale is independent of the broker block")
  f.G.apps={{id=31,status="applied",categoryID=2,name="Broker application",activityID=2,activityName="Test dungeon",expiresAt=GetTime()+90}}
  f.G:Notify("applications")
  T.eq(#F.entries,1);T.eq(F.entries[1].application.id,31)
  T.eq(F.rows[1].meta:GetText(),"Broker application","real Group updates refresh the external list")
  T.ok(F.rows[1].cancel:IsShown());T.ok(F.countdown)
  f.A:SetSetting("floating",false)
  T.ok(F.panel:IsVisible(),"hiding the entry does not dismiss the external list")
  T.eq(F.frame:IsShown(),false)
  local popupFontSize=select(2,F.rows[1].meta:GetFont())
  f.A:SetSetting("fontScale",130)
  T.near(select(2,F.rows[1].meta:GetFont()),popupFontSize*1.3,.01,"external popup text still belongs to the product font context")
  T.eq(label:GetFont(),"Display.ttf");T.eq(select(2,label:GetFont()),13);T.eq(label:GetText(),"Display text")
  object.OnLeave(host);F.panel.mouseOver=true;F.panel:Fire("OnEnter");f.base.AdvanceClock(.1)
  T.ok(F.panel:IsVisible(),"moving from the broker into its list keeps it open")
  F.panel.mouseOver=false;F.panel:Fire("OnLeave");f.base.AdvanceClock(.1)
  T.eq(F.panel:IsShown(),false);T.eq(F.countdown,nil)
  T.eq(F.popupOwner,nil);T.eq(F.popupAnchor,nil);T.eq(F.panel:GetParent(),F.frame)
  T.eq(F.panel:GetScript("OnUpdate"),nil)
  local nodes=#f.S.nodes;local hook=host:GetScript("OnHide")
  for _=1,12 do object.OnEnter(host);object.OnLeave(host);f.base.AdvanceClock(.1)end
  T.eq(#f.S.nodes,nodes,"repeated broker hover reuses the list and controls")
  T.eq(host:GetScript("OnHide"),hook,"the same display button gets one hide hook")
  local second=CreateFrame("Button",nil,UIParent);second:SetSize(120,30);second:SetPoint("TOPLEFT",UIParent,"TOPLEFT",700,-20)
  object.OnEnter(host);object.OnEnter(second);object.OnLeave(host);host:Hide();f.base.AdvanceClock(.1)
  T.ok(F.panel:IsVisible(),"late callbacks from another broker block cannot close this one")
  T.eq(F:GetAnchor(),second)
  second:Hide()
  T.eq(F.panel:IsShown(),false,"hiding the active display closes its list immediately")
  T.eq(F.popupOwner,nil);T.eq(F.countdown,nil);T.eq(F.entries,nil)
  f:Close()
 end
end

-- The panel itself drives animations, including when the entry frame is hidden.
do
 local f=New({floating=false});f:Event("PLAYER_LOGIN");f.A:SetSetting("reduceMotion",false)
 local F=f.F;local host=CreateFrame("Button",nil,UIParent);host:SetSize(100,30);host:SetPoint("TOPLEFT",UIParent,"TOPLEFT",300,-20)
 f.adapter.object.OnEnter(host)
 T.eq(F.frame:IsShown(),false);T.ok(F.panel:GetScript("OnUpdate"))
 for i=1,50 do if F.panel:GetScript("OnUpdate") then f.S.preciseNow=i*.02;F.panel:Fire("OnUpdate",.02)end end
 T.near(F.panel:GetAlpha(),1,.001);T.eq(F.panel:GetScript("OnUpdate"),nil,"external entrance animation completes and stops")
 f.adapter.object.OnLeave(host);f.base.AdvanceClock(.1)
 for i=51,100 do if F.panel:GetScript("OnUpdate") then f.S.preciseNow=i*.02;F.panel:Fire("OnUpdate",.02)end end
 T.eq(F.panel:IsShown(),false);T.eq(F.popupAnchor,nil);T.eq(F.panel:GetScript("OnUpdate"),nil)
 f:Close()
end

-- An attached entry retains its ownership while a broker temporarily owns the
-- popup. Neither a stale leave nor returning that entry may close this popup.
do
 local f=New();f:Event("PLAYER_LOGIN");local F=f.F;local API=f.API
 local owner={};local attached=CreateFrame("Button",nil,UIParent);attached:SetSize(100,30);attached:SetPoint("TOPLEFT",UIParent,"TOPLEFT",50,-20)
 local label=attached:CreateFontString(nil,"OVERLAY");label:SetFont("External.ttf",13,"OUTLINE");label:SetText("Original")
 local released=0
 T.ok(f.publicAttach(API,owner,attached,24,label,function()released=released+1 end))
 local broker=CreateFrame("Button",nil,UIParent);broker:SetSize(100,30);broker:SetPoint("TOPLEFT",UIParent,"TOPLEFT",400,-20)
 f.adapter.object.OnEnter(broker)
 T.eq(F.host,attached);T.eq(F:GetAnchor(),broker)
 T.eq(API:HidePopup(owner),false,"an attached entry's stale leave cannot close another owner's popup")
 T.ok(F.panel:IsVisible())
 T.ok(API:ShowPopup(owner));T.eq(F.popupOwner,nil);T.eq(F:GetAnchor(),attached)
 T.ok(F.panel:IsVisible(),"the original attached entry can reopen its own list")
 f.adapter.object.OnEnter(broker)
 T.ok(API:Detach(owner));T.eq(released,1);T.eq(F.host,nil)
 T.ok(F.panel:IsVisible(),"returning an attached entry preserves another owner's popup")
 T.eq(F:GetAnchor(),broker)
 f.adapter.object.OnLeave(broker);f.base.AdvanceClock(.1)
 T.eq(F.popupOwner,nil);T.eq(F.panel:IsShown(),false)
 f:Close()
end
