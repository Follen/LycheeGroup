-- Pure URL cases run in an isolated environment; tooltip cases use the real
-- product components and the offline native UI substitute.
local Check=T or {}
if not Check.eq then function Check.eq(actual,expected,why) assert(actual==expected,(why or "")..": "..tostring(actual).." ~= "..tostring(expected)) end end
if not Check.ok then function Check.ok(value,why) assert(value,why) end end
if not Check.near then function Check.near(actual,expected,delta,why) assert(math.abs(actual-expected)<=delta,why) end end
do
 local secret=setmetatable({},{__tostring=function() error("secret must not be formatted") end})
 local env=setmetatable({},{__index=_G});env._G=env
 env.issecretvalue=function(value) return rawequal(value,secret) end
 env.LycheeGroup={UI={Members={}}}
 local identityReads=0
 function env.LycheeGroup.UI.Members:Identity(member)
  identityReads=identityReads+1
  if member.nameKey then return member.nameKey,member.nameKey:match("^([^%-]+)%-(.+)$") end
  return member.realm and member.name.."-"..member.realm or nil,member.name,member.realm
 end
 env.GetCurrentRegion=function() error("URL construction must not read native region") end
 env.GetNormalizedRealmName=function() error("URL construction must not guess local realm") end
 env.RaiderIO=setmetatable({},{__index=function() error("links must not query RaiderIO addon") end})
 for _,file in ipairs({"PlayerLinks.lua","RealmSlugs.lua"}) do setfenv(assert(loadfile("addon/LycheeGroup_UI/"..file)),env)() end
 local links=env.LycheeGroup.UI.PlayerLinks
 Check.eq(links.GetRaiderIOURL("灵魂复苏","chillwind-point",5,"zhCN"),"https://raider.io/cn/characters/cn/chillwind-point/%E7%81%B5%E9%AD%82%E5%A4%8D%E8%8B%8F")
 for region,slug in ipairs({"us","kr","eu","tw","cn"}) do
  Check.eq(links.GetRaiderIOURL("Player","Illidan",region,"enUS"),"https://raider.io/characters/"..slug.."/illidan/Player")
 end
 for _,alias in ipairs({"ChillwindPoint","Chillwind Point","chillwind-point","冰风岗"}) do Check.eq(links.GetRealmSlug(alias),"chillwind-point",alias) end
 Check.eq(links.GetRealmSlug("Aggra (Português)"),"aggra-português")
 Check.eq(links.GetRaiderIOURL("Éløra /?","Aggra (Português)",3,"enUS"),"https://raider.io/characters/eu/aggra-portugu%C3%AAs/%C3%89l%C3%B8ra%20%2F%3F")
 Check.eq(links.GetWCLURL("A B/C?","Realm/One",5),"https://cn.warcraftlogs.com/character/cn/Realm%2FOne/A%20B%2FC%3F")
 Check.eq(links.GetWCLURL("Player","Illidan",1),"https://www.warcraftlogs.com/character/us/Illidan/Player")
 for _,value in ipairs({"not-a-real-server-lhfs","",false,42,secret}) do Check.eq(links.GetRealmSlug(value),nil) end
 for _,value in ipairs({"",false,42,secret}) do
  Check.eq(links.GetRaiderIOURL(value,"Illidan",1,"enUS"),nil)
  Check.eq(links.GetRaiderIOURL("Player",value,1,"enUS"),nil)
  Check.eq(links.GetWCLURL(value,"Illidan",1),nil)
 end
 for _,value in ipairs({0,6,1.5,false,"us",secret}) do Check.eq(links.GetRaiderIOURL("Player","Illidan",value,"enUS"),nil);Check.eq(links.GetWCLURL("Player","Illidan",value),nil) end
 Check.eq(links.GetRaiderIOURL("Player","Illidan",1,secret),nil)
 Check.eq(links.GetRaiderIOURL(nil,"Illidan",1,"enUS"),nil)
 Check.eq(links.GetRaiderIOURL("Player",nil,1,"enUS"),nil)
 Check.eq(links.Identity(nil),nil)
 Check.eq(links.Identity({nameKey="Player"}),nil,"an incomplete key cannot acquire the local realm")
 Check.eq(links.Identity({nameKey="Player-   "}),nil,"blank realm in a key cannot acquire the local realm")
 Check.eq(links.Identity({name="Player",realm="   "}),nil,"blank explicit realm cannot acquire the local realm")
 local readsBeforeInvalid=identityReads
 for _,value in ipairs({"Player-","Player-   ","Player"," -Illidan","\t -Illidan", "-Illidan", " - "," ","\t"}) do
  for _,field in ipairs({"name","nameKey"}) do
   local key,clean,realm=links.Identity({[field]=value})
   Check.eq(key,nil);Check.eq(clean,nil);Check.eq(realm,nil,"incomplete identity components cannot acquire the local realm")
   Check.eq(links.GetRaiderIOURL(clean,realm,1,"enUS"),nil);Check.eq(links.GetWCLURL(clean,realm,1),nil)
  end
 end
 for _,member in ipairs({{name=" ",realm="Illidan"},{name=" -Away",realm="Illidan"},{name="Player-Illidan",realm="   "},{nameKey=" -Illidan",name="Valid",realm="Away"}}) do Check.eq(links.Identity(member),nil) end
 Check.eq(identityReads,readsBeforeInvalid,"invalid components never reach the resolver that could substitute the local realm")
 local resolver=env.LycheeGroup.UI.Members.Identity
 env.LycheeGroup.UI.Members.Identity=function() return "Player-Home","Player","Home" end
 Check.eq(links.Identity({name="Player",realm="Illidan"}),nil,"a resolver cannot substitute an unprovided realm")
 env.LycheeGroup.UI.Members.Identity=resolver
 for _,member in ipairs({{nameKey="Player-Illidan",name="",realm=""},{nameKey="Player-Illidan",name=secret,realm=secret}}) do
  local key,clean,realm=links.Identity(member)
  Check.eq(key,"Player-Illidan");Check.eq(clean,"Player");Check.eq(realm,"Illidan","complete nameKey takes priority over unused identity fields")
 end
 for _,field in ipairs({"name","realm","nameKey"}) do local member={name="Player",realm="Illidan"};member[field]=secret;Check.eq(links.Identity(member),nil) end
end

-- Enter through real applicant rows so activity profiles and hover routing are
-- covered as well as the link builder and roster details.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=f.A,f.U,f.G
 a:SetSetting("reduceMotion",true)
 local activities={
  [900]={categoryID=4,maxNumPlayers=5,isPvpActivity=true},
  [901]={categoryID=9,maxNumPlayers=40,isRatedPvpActivity=true},
  [902]={categoryID=6,maxNumPlayers=5},
  [903]={id=903,categoryID=3,mapID=631,difficultyID=3,maxNumPlayers=10,isCurrentRaidActivity=false},
  [904]={id=904,categoryID=3,mapID=409,difficultyID=9,maxNumPlayers=40,isCurrentRaidActivity=false},
  [905]={id=905,categoryID=3,mapID=631,difficultyID=6,maxNumPlayers=25,isCurrentRaidActivity=false},
 }
 local getActivity=g.Catalog.GetActivity
 g.Catalog.GetActivity=function(self,id) return activities[id] or getActivity(self,id) end
 local matches=g.Catalog.Matches
 g.Catalog.Matches=function(self,activity,category,...)
  if category=="seasonRaid" and activities[activity.id] then return false end
  return matches(self,activity,category,...)
 end
 local first={name="First-Illidan",nameKey="First-Illidan",class="MAGE",assignedRole="DAMAGER",applicantID=31,itemLevel=320,dungeonScore=2500,
  dungeonScores={mapScore=320,current={name="Current dungeon",level=12,timed=true},best={name="Best dungeon",level=13,timed=true}}}
 local second={name="Second-Illidan",nameKey="Second-Illidan",class="PRIEST",assignedRole="HEALER",applicantID=31,itemLevel=321}
 local app={id=31,status="applied",activityID=2,members={first,second}}
 g.applicants[31]=app;g.listing={activityID=2,name="Applicant links"}
 g.GetRoster=function() return app.members end
 a:Open("create")
 local page,tip=u.pages.create,u.Tooltip
 page.batchScroll.mouseOver=true
 local region=locale=="zhCN" and "cn" or "us"
 local prefix=locale=="zhCN" and "/cn" or ""
 local host=locale=="zhCN" and "cn" or "www"
 for _,activityID in ipairs({2,3,1,903,904,905,902,900,901,2}) do
  tip:Hide();app.activityID=activityID;g.listing.activityID=activityID;g:Notify("listing");g:Notify("applicants")
  local links=activityID~=900 and activityID~=901
  for index,member in ipairs(app.members) do
   tip:Hide()
   page.batchPool[1].people[index].tooltipArea:Fire("OnEnter")
   local view=tip.interactive
   Check.eq(tip.member,member,"applicant hover selects the actual member")
   Check.eq(view.wcl:IsShown(),links,"WCL follows the applicant activity")
   Check.eq(view.io:IsShown(),links,"Raider.IO follows the applicant activity")
   Check.eq(view.wcl:IsEnabled(),links);Check.eq(view.io:IsEnabled(),links)
   if links then
    local name=index==1 and "First" or "Second"
    view.io:Fire("OnClick")
    Check.eq(view.copyField.box:GetText(),"https://raider.io"..prefix.."/characters/"..region.."/illidan/"..name)
    view.wcl:Fire("OnClick")
    Check.eq(view.copyField.box:GetText(),"https://"..host..".warcraftlogs.com/character/"..region.."/Illidan/"..name)
    Check.eq(view.copyField.box:HasFocus(),true);Check.eq(tip.pinned,true)
    Check.ok(view.scroll:GetVerticalScroll()+view.scroll:GetHeight()+.01>=view.canvas:GetHeight(),"copy remains reachable below dungeon records")
   else
    tip:CopyPlayerLink("io");tip:CopyPlayerLink("wcl")
    Check.eq(view.copyField:IsShown(),false,"PvP cannot open a hidden link action")
    Check.eq(view.copyField.box:HasFocus(),false)
   end
  end
  if activityID==903 or activityID==904 or activityID==905 then
   tip:Hide();page.groupSummary:Fire("OnEnter")
   local view=tip.interactive
   Check.eq(view.memberButtons[1].member,first,"legacy raid roster tooltip keeps its actual members")
   view.memberButtons[1]:Fire("OnClick")
   Check.eq(tip.member,first,"legacy raid roster opens player details")
   Check.eq(view.wcl:IsShown(),true);Check.eq(view.io:IsShown(),true);Check.eq(view.note:IsShown(),true)
   view.wcl:Fire("OnClick")
   Check.eq(view.copyField.box:GetText(),"https://"..host..".warcraftlogs.com/character/"..region.."/Illidan/First")
   view.io:Fire("OnClick")
   Check.eq(view.copyField.box:GetText(),"https://raider.io"..prefix.."/characters/"..region.."/illidan/First")
  end
 end
 -- A source refresh may change the activity while a copy field has focus.
 app.activityID=900;g.listing.activityID=900;tip:RefreshApplicant()
 local view=tip.interactive
 Check.eq(view.io:IsShown(),false);Check.eq(view.wcl:IsShown(),false)
 Check.eq(view.copyField:IsShown(),false);Check.eq(view.copyField.box:HasFocus(),false)
 Check.eq(view.copyField.box:GetText(),"")
 tip:Hide();app.activityID=2;g.listing.activityID=2
 first.name,first.nameKey="Unknown",nil
 g:Notify("listing");g:Notify("applicants")
 page.batchPool[1].people[1].tooltipArea:Fire("OnEnter")
 Check.eq(view.io:IsShown(),true);Check.eq(view.wcl:IsShown(),true,"non-PvP actions remain discoverable without a complete identity")
 Check.eq(view.io:IsEnabled(),false);Check.eq(view.wcl:IsEnabled(),false)
 tip:CopyPlayerLink("wcl");Check.eq(view.copyField:IsShown(),false,"missing realm never creates a link to the local realm")
 u:Hide(true)
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale)
 local a,u,g=f.A,f.U,f.G;a:SetSetting("reduceMotion",true);a:Open("create")
 for _,value in ipairs({"Player-","Player-   ","Player"," -Illidan","\t -Illidan","-Illidan"," - "," ","\t"}) do
  for _,field in ipairs({"name","nameKey"}) do
   local key,clean,realm=u.PlayerLinks.Identity({[field]=value})
   Check.eq(key,nil);Check.eq(clean,nil);Check.eq(realm,nil,"the real identity resolver cannot fill a missing name or realm")
  end
 end
 for _,member in ipairs({{name="Player",realm="Illidan"},{name="Player-Illidan"},{name="Player-Illidan",realm=""},{nameKey="Player-Illidan",name="Other-Away",realm="Away"},{nameKey="Player-Illidan",name="",realm=""},{name=" \tPlayer \t",realm=" Ill idan \t"},{name=" \tPlayer - Illidan \t"},{nameKey=" \tPlayer - Illidan \t",name="Other-Away",realm="Away"},{name=" Player - Away ",realm=" Illidan "}}) do
  local key,clean,realm=u.PlayerLinks.Identity(member)
  Check.eq(key,"Player-Illidan");Check.eq(clean,"Player");Check.eq(realm,"Illidan","complete keys retain priority and explicit or embedded realms remain usable")
 end
 local tip=u.Tooltip
 local first={guid="Link-1",name="First-Illidan",nameKey="First-Illidan",class="MAGE",assignedRole="DAMAGER",itemLevel=320}
 local second={guid="Link-2",name="Second-Illidan",nameKey="Second-Illidan",class="PRIEST",assignedRole="HEALER",itemLevel=321}
 local members={first,second};g.GetRoster=function() return members end
 local oldRegion=GetCurrentRegion;local regionReads=0
 GetCurrentRegion=function() regionReads=regionReads+1;return 1 end
 for _,scale in ipairs({70,100,130}) do
  a:SetSetting("fontScale",scale)
  tip:ShowPlayer(u.frame,first,a.GroupPresentation.Member("roster"))
  local view=tip.interactive
  Check.eq(view.io:IsShown(),true);Check.eq(view.io:IsEnabled(),true)
  Check.eq(view.wcl:IsShown(),true);Check.eq(view.note:IsShown(),true)
  local x
  for _,button in ipairs({view.wcl,view.io,view.note}) do
   Check.near(button:GetWidth(),view.wcl:GetWidth(),.001,"three equal action widths")
   Check.ok(button:GetWidth()+.001>=u.C.MeasureTextWidth(button.label)+28,"complete action labels fit at "..locale.." "..scale)
   local _,_,_,left=button:GetPoint(1)
   if x then Check.near(left-x,8,.001,"action gap") end
   x=left+button:GetWidth()
  end
  Check.near(x,view.canvas:GetWidth(),.001,"actions span available width")
 end
 local view=tip.interactive
 local language=locale=="zhCN" and "/cn" or ""
 local box=view.copyField.box;local selections=0
 box.HighlightText=function() selections=selections+1 end
 for _,scale in ipairs({70,100,130}) do
  tip:Hide();a:SetSetting("fontScale",scale);tip:ShowPlayer(u.frame,first,a.GroupPresentation.Member("roster"))
  local height=view.canvas:GetHeight();local before=selections
  view.io:Fire("OnClick")
  Check.eq(u.activeModal,nil,"player links remain inside the detail tooltip")
  Check.eq(view:IsShown(),true);Check.eq(tip.member,first);Check.eq(tip.pinned,true)
  Check.eq(box:GetText(),"https://raider.io"..language.."/characters/us/illidan/First")
  Check.eq(box:HasFocus(),true);Check.eq(selections,before+1,"opening a link selects its entire text")
  Check.ok(view.canvas:GetHeight()>height,"the copy area extends the existing tooltip")
  local fieldPoint={view.copyField:GetPoint()}
  Check.near(-fieldPoint[#fieldPoint],height+12,.001,"copy field follows the existing actions")
  Check.eq(view.copyField:GetWidth(),view.canvas:GetWidth())
  Check.ok(view.scroll:GetVerticalScroll()+view.scroll:GetHeight()+.01>=view.canvas:GetHeight(),"the copy field remains visible when the tooltip must scroll")
  box:UserType("replacement");Check.ok(box:GetText():find("/First",1,true),"link text is read-only")
  view.wcl:Fire("OnClick")
  Check.eq(view.copyField.box,box,"platform switches reuse the same input")
  Check.eq(box:GetText(),"https://www.warcraftlogs.com/character/us/Illidan/First")
  local sameHeight=view.canvas:GetHeight();view.wcl:Fire("OnClick")
  Check.eq(view.canvas:GetHeight(),sameHeight,"repeated clicks do not add rows")
  local count=#f.S.nodes
  for i=1,8 do view.io:Fire("OnClick");view.wcl:Fire("OnClick") end
  Check.eq(#f.S.nodes,count,"warm platform switching creates no UI objects")
 end
 local fresh={guid=first.guid,name=first.name,nameKey=first.nameKey,class="MAGE",assignedRole="DAMAGER",itemLevel=333}
 members={second,fresh};tip:RefreshRoster(u.frame,members)
 Check.eq(tip.member,fresh,"refresh resolves the selected roster identity while copying")
 Check.eq(view.metrics[1].value:GetText(),"333");Check.eq(box:HasFocus(),true)
 Check.eq(box:GetText(),"https://www.warcraftlogs.com/character/us/Illidan/First")
 members={second};tip:RefreshRoster(u.frame,members)
 Check.eq(tip.member,nil,"a departed inline member closes the detail")
 Check.eq(box:HasFocus(),false);Check.eq(box:GetText(),"");Check.eq(view.copyField:IsShown(),false)
 tip:ShowRoster(u.frame,members)
 view.memberButtons[1]:Fire("OnClick")
 Check.eq(tip.pinned,true,"selecting a roster member pins the detail")
 view.io:Fire("OnClick")
 Check.eq(tip.member,second);Check.eq(view.back:IsShown(),true,"copy preserves group navigation")
 Check.eq(box:GetText(),"https://raider.io"..language.."/characters/us/illidan/Second","a reused button targets the current member")
 view.back:Fire("OnClick")
 Check.eq(tip.member,nil);Check.eq(box:HasFocus(),false);Check.eq(box:GetText(),"")
 Check.eq(view.copyField:IsShown(),false,"returning to the roster collapses the copy area")
 tip:Hide();tip:ShowPlayer(u.frame,second,a.GroupPresentation.Member("roster"));view.io:Fire("OnClick")
 box:Fire("OnEscapePressed");Check.eq(view:IsShown(),false);Check.eq(box:HasFocus(),false)
 second.dungeonScores={current={name=string.rep("Long dungeon name ",100),level=18,timed=true}}
 tip:ShowPlayer(u.frame,second,a.GroupPresentation.Member("roster"));view.wcl:Fire("OnClick")
 Check.ok(view.scroll:GetVerticalScroll()>0,"long details scroll down to the copy area")
 Check.near(view.scroll:GetVerticalScroll()+view.scroll:GetHeight(),view.canvas:GetHeight(),.01,"the complete copy area is reachable")
 tip:Hide();second.dungeonScores=nil
 tip:ShowPlayer(u.frame,{name="Unknown-not-a-real-server-lhfs",nameKey="Unknown-not-a-real-server-lhfs",class="MAGE"})
 Check.eq(view.io:IsShown(),true);Check.eq(view.io:IsEnabled(),false)
 view.io:Fire("OnClick");Check.eq(view.copyField:IsShown(),false,"unknown realm cannot expose a copy field")
 tip:Hide();u.preview=true;local before=regionReads
 tip:ShowPlayer(u.frame,second);view.io:Fire("OnClick");view.wcl:Fire("OnClick")
 Check.eq(regionReads,before,"preview links never read native region")
 Check.eq(view.copyField:IsShown(),false,"preview cannot expose a copy field")
 Check.eq(view.io:IsEnabled(),false)
 u.preview=nil;tip:Hide();tip:ResetInteractive(u.frame,512)
 Check.eq(view.io:IsShown(),false,"group/reset discards player actions")
 tip:ShowPlayer(u.frame,second,a.GroupPresentation.Member("roster"));view.wcl:Fire("OnClick");u:Hide(true)
 Check.eq(box:HasFocus(),false);Check.eq(box:GetText(),"");Check.eq(tip.copyKind,nil,"closing the window clears the inline copy")
 GetCurrentRegion=oldRegion;u:Hide(true)
end
