-- Offline SeUI entry lifecycle against the real Floating API and controller.
local Fixture=dofile("tests/ui_fixture.lua")
local function New(options)
 options=options or {}
 _G.SeUIRaidMarkerBar=nil;_G.LycheeGroupSEUIEntry=nil;_G.RurutiaSuite=nil
 local f=Fixture(options.locale or "zhCN",nil,{reduceMotion=true,floating=options.floating~=false,floatingCompatibility=options.compatibility~=false})
 f.loaded=options.loaded~=false
 local metadata=C_AddOns.GetAddOnMetadata
 C_AddOns.IsAddOnLoaded=function(name) return name=="SeUI" and f.loaded or name~="SeUI" end
 C_AddOns.GetAddOnMetadata=function(name,field)
  if name=="SeUI" then return options.installed~=false and field=="Version" and "1.8" or nil end
  return metadata(name,field)
 end
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua")
 f.F=f.A.Floating;f.API=f.A.API.Floating
 f.F:Bind(f.G);f.F:UpdateSettings()
 function f:Bar(hidden,noSkull)
  local bar=CreateFrame("Frame","SeUIRaidMarkerBar",UIParent)
  bar:SetSize(256,30);bar:SetPoint("BOTTOM",UIParent,"BOTTOM",0,30);bar:SetScale(.8);bar:SetFrameStrata("HIGH");bar:SetFrameLevel(20)
  self.bar,self.markers=bar,{}
  for index=1,noSkull and 7 or 8 do
   local marker=CreateFrame("Button",nil,bar);marker:SetSize(28,28);marker:SetPoint("LEFT",bar,"LEFT",(index-1)*30,0)
   marker.attributes={type="raidtarget",marker1=index,marker2=0}
   function marker:GetAttribute(key) return self.attributes[key] end
   marker:SetScript("OnClick",function() self.markerClicks=(self.markerClicks or 0)+1 end)
   marker:SetScript("OnMouseDown",function() end)
   -- An integration may anchor beside secure controls, but cannot rewrite them.
   marker.SetAttribute=function() error("adapter wrote a protected marker attribute") end
   self.markers[index]=marker
  end
  if hidden then bar:Hide() end
  return bar,self.markers[8]
 end
 function f:Adapter()
  local count=#self.S.nodes
  dofile("addon/LycheeGroup/Adapters/SEUI.lua")
  self.adapter=self.A.Adapters.SEUI;self.events=self.S.nodes[count+1]
  T.eq(#self.S.nodes,count+1,"loading SeUI support creates only its event frame")
  T.eq(self.events.events.PLAYER_LOGIN,true)
  return self.adapter
 end
 function f:Event(event,...)
  T.eq(self.events.events[event],true,"the adapter must subscribe before receiving "..event)
  self.events:Fire("OnEvent",event,...)
 end
 function f:Close()
  if self.adapter then self.adapter:Release() end
  if self.U.frame then self.U:Hide(true) end
  self.A:SetSetting("floating",false)
  _G.SeUIRaidMarkerBar=nil;_G.LycheeGroupSEUIEntry=nil
 end
 return f
end

-- The three independent switches are all required, including when a bar exists.
for _,loaded in ipairs({false,true}) do
 for _,floating in ipairs({false,true}) do
  for _,compatibility in ipairs({false,true}) do
   local f=New({loaded=loaded,floating=floating,compatibility=compatibility})
   f:Bar();local s=f:Adapter();f:Event("PLAYER_LOGIN")
   local allowed=loaded and floating and compatibility
   T.eq(s.attached==true,allowed,"SeUI requires loaded addon, floating entry and compatibility together")
   T.eq(s.host~=nil,allowed,"a disabled initial integration allocates no host or label")
   T.eq(f.F.host~=nil,allowed)
   T.eq(f.events:GetScript("OnUpdate"),nil,"initialization is event-driven")
   f:Close()
  end
 end
end

-- An optional addon can arrive later; bar creation may lag PLAYER_LOGIN too.
do
 local f=New({loaded=false});local s=f:Adapter()
 f:Event("PLAYER_LOGIN");T.eq(f.events.events.PLAYER_LOGIN,nil);T.eq(f.events.events.ADDON_LOADED,true)
 f:Event("ADDON_LOADED","UnrelatedAddon");T.eq(s.host,nil)
 f.loaded=true;f:Event("ADDON_LOADED","SeUI")
 T.eq(f.events.events.ADDON_LOADED,nil);T.eq(f.events.events.PLAYER_ENTERING_WORLD,true);T.eq(s.host,nil)
 f:Event("PLAYER_ENTERING_WORLD");T.eq(s.host,nil);T.eq(f.events.events.PLAYER_ENTERING_WORLD,true,"a still-missing bar is retried on the next entering-world event")
 local nodes=#f.S.nodes;f:Bar();nodes=#f.S.nodes
 f:Event("PLAYER_ENTERING_WORLD")
 T.ok(s.attached);T.eq(f.events.events.PLAYER_ENTERING_WORLD,nil)
 T.eq(#f.S.nodes,nodes+2,"a ready integration adds one host button and one label, reusing existing floating visuals")
 T.eq(f.events.events.UI_SCALE_CHANGED,true);T.eq(f.events.events.DISPLAY_SIZE_CHANGED,true)
 f:Close()
end
do
 local f=New({loaded=false,installed=false});local s=f:Adapter();f:Event("PLAYER_LOGIN")
 T.eq(f.events.events.ADDON_LOADED,nil,"an absent optional addon leaves no addon-load listener")
 T.eq(s.host,nil);f:Close()
end
do
 local f=New();f:Bar(true);local s=f:Adapter();f:Event("PLAYER_LOGIN")
 T.eq(s.host,nil,"an initially hidden marker bar builds no entry")
 f.bar:Show();T.ok(s.attached)
 f:Close()
end
do
 local f=New();f:Bar(false,true);local s=f:Adapter();f:Event("PLAYER_LOGIN")
 T.eq(s.host,nil,"a bar with no skull never anchors to another marker")
 local skull=CreateFrame("Button",nil,f.bar);skull:SetSize(28,28)
 function skull:GetAttribute(key) return key=="marker1" and 8 or nil end
 f.bar:SetWidth(260);T.eq(s.skull,skull);T.ok(s.attached,"the existing bar hook discovers a subsequently built skull")
 f:Close()
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=New({locale=locale});local a,u,g,F,api=f.A,f.U,f.G,f.F,f.API
 local bar,skull=f:Bar()
 local snapshots={}
 for index,marker in ipairs(f.markers) do snapshots[index]={parent=marker:GetParent(),point={marker:GetPoint()},attributes={type=marker.attributes.type,marker1=marker.attributes.marker1,marker2=marker.attributes.marker2},click=marker:GetScript("OnClick"),down=marker:GetScript("OnMouseDown")} end
 local logo,popup=F.logoTexture,F.panel
 local subscribe=api.Subscribe;local subscriptions=0
 api.Subscribe=function(self,...) subscriptions=subscriptions+1;return subscribe(self,...) end
 local s=f:Adapter();local nodes=#f.S.nodes;f:Event("PLAYER_LOGIN")
 local host,label=s.host,s.label
 T.ok(s.attached);T.eq(#f.S.nodes,nodes+2,"attachment adds no duplicate logo, popup or marker")
 T.eq(host:GetParent(),UIParent,"the custom button remains outside the protected marker hierarchy")
 T.eq(F.frame:GetParent(),host);T.eq(F.host,host);T.eq(F.count,label)
 T.eq(F.logoTexture,logo);T.eq(F.panel,popup);T.eq(F.button:IsShown(),false)
 T.eq(s.skull,skull,"marker1=8 is located even when it is not the first child")
 local point={host:GetPoint()}
 T.same(point,{"RIGHT",skull,"LEFT",-8,0},"the entry hugs the skull's left edge")
 T.eq(s.logoSize,34);T.eq(F.logoAnchor:GetWidth(),34)
 T.eq(select(2,label:GetFont()),18);T.eq(select(3,label:GetFont()),"OUTLINE");T.eq(select(1,label:GetFont()),STANDARD_TEXT_FONT)
 T.eq(label.justify,"RIGHT");T.eq(label.wrap,false)
 T.eq(host:GetWidth(),34+4+math.ceil(label:GetUnboundedStringWidth()),"status text and logo determine the entry's compact width")
 T.eq(host:GetHeight(),34);T.eq(host:GetFrameStrata(),bar:GetFrameStrata());T.eq(host:GetFrameLevel(),bar:GetFrameLevel()+1)
 T.eq(bar:GetScale(),.8)
 T.near(host:GetEffectiveScale(),UIParent:GetEffectiveScale(),.000001,"the entry keeps its UIParent size beside a smaller marker bar")
 bar:SetScale(1.4);T.eq(host:GetScale(),1,"a larger marker bar does not enlarge the entry")
 T.near(host:GetEffectiveScale(),UIParent:GetEffectiveScale(),.000001)
 -- Real client regression: the bar has its own .65 scale below UIParent .64.
 bar:SetScale(.65);UIParent:SetScale(.64);f:Event("UI_SCALE_CHANGED")
 T.eq(host:GetScale(),1,"the marker bar's extra .65 scale is excluded from the entry")
 T.near(bar:GetEffectiveScale(),.64*.65,.000001)
 T.near(host:GetEffectiveScale(),.64,.000001,"the host follows only the real UIParent scale")
 T.near(logo:GetWidth()*logo:GetEffectiveScale(),34*.64,.000001,"the logo keeps the Rurutia-sized 34-unit canvas instead of shrinking by .65")
 T.near(select(2,label:GetFont())*label:GetEffectiveScale(),18*.64,.000001,"the outlined text keeps 18 UI units instead of shrinking by .65")
 UIParent:SetScale(1.25);f:Event("UI_SCALE_CHANGED")
 T.near(host:GetEffectiveScale(),UIParent:GetEffectiveScale(),.000001,"the entry still follows changes to UIParent scale")
 bar:SetPoint("BOTTOM",UIParent,"BOTTOM",50,70);T.eq(select(2,host:GetPoint()),skull)
 f:Event("DISPLAY_SIZE_CHANGED");T.eq(s.host,host)

 -- Use the actual window toggle rather than replacing it with an Open-only stub.
 T.eq(u.frame,nil)
 host:Fire("OnClick","RightButton");T.eq(u.frame,nil)
 host:Fire("OnClick","LeftButton");T.ok(u:IsShown());T.eq(u.page,"find")
 host:Fire("OnClick","LeftButton");T.eq(u:IsShown(),false,"the integrated entry closes the open main window")
 a:Open("notes");host:Fire("OnClick","LeftButton");T.eq(u:IsShown(),false,"toggle closes any active main page")

 g.apps={{id=1,status="applied",categoryID=2,name="One application",activityID=2}}
 g:Notify("applications")
 local status=api:GetStatus();T.eq(status.count,1);T.eq(label:GetText(),locale=="zhCN" and "申请1个" or "Applied: 1")
 local shortWidth=host:GetWidth()
 for id=2,12 do g.apps[id]={id=id,status="applied",categoryID=2,name="Application "..id,activityID=2} end
 g:Notify("applications");T.eq(api:GetStatus().count,12);T.eq(label:GetText(),locale=="zhCN" and "申请12个" or "Applied: 12")
 T.ok(host:GetWidth()>shortWidth,"a wider status updates host bounds immediately")
 T.eq(host:GetWidth(),34+4+math.ceil(label:GetUnboundedStringWidth()))
 g.listing={activityID=2,name="Recruiting fixture"}
 g.applicants={[20]={id=20,status="applied",members={{name="One",class="MAGE"},{name="Two",class="PRIEST"}}},[21]={id=21,status="applied",acting=true,members={{name="Pending"}}}}
 g:Notify("listing")
 T.eq(api:GetStatus().count,2);T.eq(api:GetStatus().recruiting,true)
 T.eq(label:GetText(),locale=="zhCN" and "2人申请" or "2 applicants","recruitment counts people and excludes an acting batch")
 T.eq(host:GetWidth(),34+4+math.ceil(label:GetUnboundedStringWidth()))
 g.listing=nil;g.applicants={}
 g.apps={};g:Notify("applications");T.eq(api:GetStatus().count,0);T.eq(label:GetText(),locale=="zhCN" and "荔枝组队" or "Lychee LFG")
 for _,percent in ipairs({70,130,100}) do
  a:SetSetting("fontScale",percent)
  T.eq(select(2,label:GetFont()),18);T.eq(select(3,label:GetFont()),"OUTLINE","product font scaling preserves the external entry's outlined font")
 end
 host.mouseOver=true;host:Fire("OnEnter");T.ok(popup:IsShown());T.eq(F:GetAnchor(),host)
 T.eq(F.popupBounds[1],bar,"the popup avoids the marker bar")
 host.mouseOver=false;host:Fire("OnLeave");T.ok(F.hideTask)
 f.base.AdvanceClock(.07);F:Tick(.3);T.eq(popup:IsShown(),false)
 local highWater=#f.S.nodes
 for _=1,8 do host.mouseOver=true;host:Fire("OnEnter");F:Dismiss();host.mouseOver=false end
 T.eq(#f.S.nodes,highWater,"repeated hover reuses the unique logo, popup and empty card")
 T.eq(F.logoTexture,logo);T.eq(F.panel,popup)

 local reads=0;local originals={}
 for _,name in ipairs({"GetListing","GetApplications","GetApplicants","GetApplicant"}) do
  local method=g[name];originals[name]=method
  g[name]=function(self,...) reads=reads+1;return method(self,...) end
 end
 local active=g.Applications.GetActiveCount
 g.Applications.GetActiveCount=function(self,...) reads=reads+1;return active(self,...) end
 highWater=#f.S.nodes
 for _=1,30 do s:Sync();s:Initialize() end
 T.eq(reads,0,"unchanged entry syncs do not reread applications, applicants or listing state")
 T.eq(#f.S.nodes,highWater,"repeated syncs have fixed frame cost")
 T.eq(subscriptions,1,"repeated initialization retains exactly one status subscription")
 for name,method in pairs(originals) do g[name]=method end;g.Applications.GetActiveCount=active
 T.eq(host:GetScript("OnUpdate"),nil);T.eq(f.events:GetScript("OnUpdate"),nil);T.eq(bar:GetScript("OnUpdate"),nil)

 T.ok(api:Detach(s));T.eq(s.attached,nil);T.eq(F.host,nil);T.eq(host:IsShown(),false);T.eq(host:GetNumPoints(),0)
 F:PublishStatus();T.eq(s.attached,nil,"an unchanged publish after explicit detach leaves no stale attachment")
 s:Sync();T.ok(s.attached);T.eq(F.host,host)
 -- Detach itself refreshes status. Changing the source without notifying forces
 -- that publish to reenter the adapter while the marker bar is already hidden.
 host.mouseOver=true;host:Fire("OnEnter");T.ok(popup:IsShown())
 g.apps={{id=500,status="applied",categoryID=2,name="During detach",activityID=2}}
 bar:Hide();T.eq(s.attached,nil);T.eq(F.host,nil);T.eq(F.frame:GetParent(),UIParent);T.ok(F.button:IsShown());T.eq(host:IsShown(),false);T.eq(host:GetNumPoints(),0)
 T.eq(popup:IsShown(),false,"hiding the marker bar dismisses its shared popup before restoring standalone")
 T.eq(F.count,F.ownCount);host.mouseOver=false
 T.eq(api:GetStatus().count,1,"nested detach publishes the current status without reattaching to a hidden bar")
 bar:Show();T.eq(s.host,host);T.ok(s.attached)
 for _,key in ipairs({"floatingCompatibility","floating"}) do
  a:SetSetting(key,false);T.eq(s.attached,nil);T.eq(F.host,nil);T.eq(host:IsShown(),false)
  T.eq(F.frame:GetParent(),UIParent);T.ok(F.button:IsShown())
  T.eq(F.frame:IsShown(),key~="floating","compatibility restores standalone entry; floating=false hides it")
  a:SetSetting(key,true);T.eq(s.host,host);T.ok(s.attached);T.eq(F.logoTexture,logo);T.eq(F.panel,popup)
 end
 f.loaded=false;s:Sync();T.eq(F.host,nil);T.ok(F.button:IsShown());T.ok(F.frame:IsShown())
 f.loaded=true;s:Sync();T.eq(s.host,host);T.ok(s.attached)
 for index,marker in ipairs(f.markers) do
  local saved=snapshots[index]
  T.eq(marker:GetParent(),saved.parent);T.same({marker:GetPoint()},saved.point);T.same(marker.attributes,saved.attributes)
  T.eq(marker:GetScript("OnClick"),saved.click);T.eq(marker:GetScript("OnMouseDown"),saved.down)
 end
 f:Close()
end
