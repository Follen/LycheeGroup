-- Real Find controller and Applications native-status updates; no client contact.
-- Run: lua tests/test_application_notice_layout.lua
local checks,failures=0,0
local function check(value,message)
 checks=checks+1
 if not value then failures=failures+1;print("[FAIL] "..message) end
end
local function near(a,b,message) check(math.abs(a-b)<.001,message..(" (actual %.3f, expected %.3f)"):format(a,b)) end
local function top(region) local point={region:GetPoint()};return -(point[#point] or 0) end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,percent in ipairs({70,100,130}) do
  local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true,fontScale=percent,autoJoin=false})
  local a,u,g=f.A,f.U,f.G
  local native={}
  -- Five active native applications leave one ordinary search result.
  for id=1,6 do
   g.records[id]={id=id,name="Fixture group "..id,leaderName="Leader-Home",leaderKey="Leader-Home",partyGUID="fixture-party-"..id,
    activity=g.Catalog:GetActivity(2),activityID=2,activityName="Dungeon activity",categoryID=2,numMembers=3,maxNumPlayers=5,
    details={members={},counts={TANK=1,HEALER=1,DAMAGER=1}}}
   if id<=5 then native[id]="applied" end
  end
  C_LFGList.GetApplications=function() return {1,2,3,4,5} end
  C_LFGList.GetApplicationInfo=function(id) return id,native[id],nil,600 end
  g.Game={RefreshApplicationSubscriptions=function() end}
  function g.Results:Capture(id) return g.records[id] end
  function g.Results:InvalidateView() end
  function g:HasViews() return true end
  dofile("addon/LycheeGroup_Group/Applications.lua")
  function g:GetApplications() return self.Applications:GetApplications() end
  function g:GetApplication(id) return self.Applications:GetApplication(id) end
  g.Applications:SyncAll()
  a:Open("find");local p=u.pages.find;p:CommitChoice();p:DoSearch()
  local tag=locale.."/"..percent;local currentPercent=percent
  local function rows(phase)
   local ordinary
   for _,row in ipairs(p.results.rows) do if row.key==6 then ordinary=row;break end end
   check(ordinary~=nil,tag.."/"..phase..": the ordinary result disappeared")
   if ordinary then
    near(ordinary:GetHeight(),53,tag.."/"..phase..": the notice/native update stretches an ordinary result row")
    near(select(2,ordinary.title:GetFont()),19*currentPercent/100,tag.."/"..phase..": result text changes size")
    near(ordinary.title:GetLineHeight()+ordinary.title:GetSpacing(),26*currentPercent/100,tag.."/"..phase..": result text changes line height")
   end
   near(p.appList.rowHeight,44,tag.."/"..phase..": the notice changes application row height")
  end
  rows("before notice")
  p:ShowApplicationLimit();u.Motion:FinishPlacement(p.limitNotice)
  check(g.Applications:GetActiveCount()==5 and p.limitNotice:IsShown(),tag..": the actual five-application path is not exercised")
  near(top(p.limitNotice),124+(p.appsHeight or 0)+(p.quickFilterHeight or 0),tag..": notice reveal starts below its application-adjacent layout position")
  rows("full notice")
  -- A cancellation also frees a slot but has no rejection footer.
  native[1]="cancelled";g.Applications:OnStatusUpdated(1,"cancelled","applied")
  check(g.Applications:GetActiveCount()==4 and p.limitText:GetText()==(locale=="zhCN" and "已有空余名额，可以继续申请。" or "A slot is available. You can continue your application."),tag..": native cancellation does not produce the available-slot notice")
  rows("slot after cancellation")
  native[1]="applied";g.Applications:OnStatusUpdated(1,"applied","cancelled")
  p:ShowApplicationLimit()
  -- A refusal reaches the same green notice and adds one marked result at the end.
  native[1]="declined";g.Applications:OnStatusUpdated(1,"declined","applied")
  check(g.Applications:GetActiveCount()==4 and p.limitNotice:IsShown(),tag..": native refusal does not leave the available-slot notice visible")
  print(("[TRACE] %s native active=%d ordinary row=%g list stride=%g notice=%s"):format(tag,g.Applications:GetActiveCount(),p.results.rows[1]:GetHeight(),p.results.rowHeight,p.limitText:GetText()))
  rows("slot after refusal")
  u:ApplyElementScope("find");rows("available notice after fixed-style application")
  p.limitNotice.close:Fire("OnClick","LeftButton")
  check(not p.limitNotice:IsShown(),tag..": dismiss leaves the notice shown")
  rows("dismissed notice")
  u:ApplyElementScope("find");p:RefreshResults();rows("dismissed notice after refresh and style")
  local rejected
  for _,row in ipairs(p.results.rows) do if row.key==1 then rejected=row;break end end
  check(rejected~=nil and rejected.declined:IsShown() and rejected.declined:GetText()~="",tag..": compact ordinary rows lose the actual rejection information")
  if rejected then near(rejected:GetHeight(),53+p.resultFooterHeight,tag..": only the rejected row appends its footer to the compact body") end
  local function boundRows(phase)
   local list=p.results
   for _,row in ipairs(list.rows) do
    if row.key then
     local marked=g.Applications:GetDeclinedAt(g.records[row.key].partyGUID)~=nil
     local footer=marked and p.resultFooterHeight or 0
     near(row:GetHeight(),list.rowHeight+footer,tag.."/"..phase..": mixed rows do not use individual body/footer heights")
     near(row.resultContentOffset,footer/2,tag.."/"..phase..": a recycled result retains another row's body offset")
     check(row.declined:IsShown()==marked,tag.."/"..phase..": row reuse leaves the wrong rejection label")
     if marked then
      local footerTop=row:GetHeight()-u.Theme.findResultBottomInset-row.declined:GetHeight()
      local bodyBottom=row:GetHeight()/2-row.resultContentOffset+math.max(row.title:GetHeight(),row.meta:GetHeight(),row.description:GetHeight())/2
      check(row.declined:GetHeight()+.001>=row.declined:GetStringHeight(),tag.."/"..phase..": rejection text is vertically clipped")
      check(bodyBottom+u.Theme.findResultTextGap<=footerTop+.001,tag.."/"..phase..": rejection footer overlaps the main row text")
     end
    end
   end
  end
  -- Mix many ordinary rows with two refused applications to exercise recycling.
  for id=7,46 do
   g.records[id]={id=id,name="Fixture group "..id,leaderName="Leader-Home",leaderKey="Leader-Home",partyGUID="fixture-party-"..id,
    activity=g.Catalog:GetActivity(2),activityID=2,activityName="Dungeon activity",categoryID=2,numMembers=3,maxNumPlayers=5}
  end
  native[2]="declined";g.Applications:OnStatusUpdated(2,"declined","applied")
  check(#p.results.ids>40 and #p.results.rows<#p.results.ids,tag..": mixed rows abandon the visible pool")
  local function scroll(phase)
   local list=p.results
   list:SetPixelOffset(0,false);boundRows(phase.." top")
   list:SetPixelOffset(100000,false);boundRows(phase.." bottom")
   local found=false
   for _,row in ipairs(list.rows) do if row.key==2 and row._hitVisible then found=true end end
   check(found,tag.."/"..phase..": final rejection cannot be reached")
   local minimum,maximum=list.slider:GetMinMaxValues()
   near(maximum,list.contentHeight-list:GetHeight(),tag.."/"..phase..": variable-height scrolling has the wrong end")
   local expected=0
   for index,id in ipairs(list.ids) do
    near(list.geometryOffsets[index],expected,tag.."/"..phase..": mixed row geometry has a gap or overlap")
    expected=expected+list.rowHeight+(g.Applications:GetDeclinedAt(g.records[id].partyGUID)~=nil and p.resultFooterHeight or 0)
   end
   near(list.contentHeight,expected,tag.."/"..phase..": rejection footers change unrelated row space")
   list:SetPixelOffset(0,false);rows(phase.." recycled normal row")
  end
  for _,value in ipairs({70,130,100,percent}) do
   currentPercent=value;a:SetSetting("fontScale",value);u:SetWindowSize(1,1)
   scroll("live font "..value)
   p:ShowApplicationLimit();u.Motion:FinishPlacement(p.limitNotice)
   near(u.Motion.reveals[p.limitNotice][5],-p.noticeTop,tag..": live-font notice reveal targets a different final layout position")
   local scale=p.limitNotice:GetEffectiveScale()
   near(top(p.limitNotice),-math.floor(-p.noticeTop*scale+.5)/scale,tag..": live-font notice reveal does not finish on its layout pixel")
   u:ApplyElementScope("find");scroll("live font with available notice "..value)
   p.limitNotice.close:Fire("OnClick","LeftButton");scroll("live font after dismiss "..value)
  end
  local nodes=#f.S.nodes
  for _=1,8 do
   p:ShowApplicationLimit();p.results:SetPixelOffset(100000,false)
   p.limitNotice.close:Fire("OnClick","LeftButton");p.results:SetPixelOffset(0,false)
   u:ApplyElementScope("find")
  end
  check(#f.S.nodes==nodes,tag..": warm notice/scroll/style cycles allocate more native objects")
  if percent==100 then
   local driver=u.Motion.driver;local animationNodes=#f.S.nodes
   a:SetSetting("reduceMotion",false)
   p:ShowApplicationLimit();u.Motion:Tick(.20)
   near(u.Motion.reveals[p.limitNotice][5],-p.noticeTop,tag..": animated notice uses the old offset")
   rows("animated available notice")
   p.limitNotice.close:Fire("OnClick","LeftButton")
   check(not p.limitNotice:IsShown() and not u.Motion.placements[p.limitNotice],tag..": dismiss leaves an active notice placement")
   rows("dismissed animated notice")
   -- Reduced-motion fixtures have never needed the library's lazy animation driver.
   near(#f.S.nodes-animationNodes,driver and 0 or 1,tag..": the first animation allocates more than its single driver")
   check(u.Motion.driver==(driver or f.S.nodes[animationNodes+1]) and u.Motion.driver:GetObjectType()=="Frame",tag..": first-use allocation is not the shared animation driver")
   print(("[TRACE] %s first animation native objects +%d; source=Motion.Start lazy driver Frame"):format(tag,#f.S.nodes-animationNodes))
   local warmNodes=#f.S.nodes;driver=u.Motion.driver
   for _=1,8 do
    p:ShowApplicationLimit();u.Motion:Tick(.20)
    p.results:SetPixelOffset(100000,false)
    p.limitNotice.close:Fire("OnClick","LeftButton");p.results:SetPixelOffset(0,false)
    u:ApplyElementScope("find")
    check(#f.S.nodes==warmNodes and u.Motion.driver==driver,tag..": warmed animated notice/scroll cycles keep allocating native objects")
   end
  end
  u:Hide(true)
 end
end
print(("Application notice layout: %d checks, %d failures"):format(checks,failures))
assert(failures==0,"application notice layout regression")
