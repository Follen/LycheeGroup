-- Selected PR filters share their real UI state and preview matching path.
local Fixture=dofile("tests/ui_fixture.lua")
local function Click(button,mouse) button:Fire("OnClick",mouse or "LeftButton") end
local function Top(region) local point={region:GetPoint()};return -point[#point] end
local function Left(region) local point={region:GetPoint()};return point[#point-1] or 0 end
local function Role(page,key,value)
 local button=page.quickChoices[key].button;Click(button,"RightButton")
 if value then Click(button);if value=="present" then Click(button) end end
 return button
end
local function CheckFooter(page,locale,count)
 T.eq(page.filteredResultCount,count,"the popup summary tracks the visible filtered result IDs")
 T.eq(#page.results.ids,count)
 T.eq(page.filterStatus:GetText(),(locale=="zhCN" and "%d 项条件 · %d 支队伍" or "%d filters · %d groups"):format(page.filterCount,count),"condition and result counts update together")
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale);local a,u,g=f.A,f.U,f.G
 f.base.SetUnit("player",{name="Player",realm="Home",class="WARRIOR",classID=1})
 a:SetSetting("reduceMotion",true);a:Open("find")
 local p=u.pages.find
 p:SetSidebarCollapsed(false,false)
 p:SelectCategory("seasonDungeon");p:CommitChoice()
 T.eq(a:GetSetting("showImportantFilters"),false)
 T.eq(p.quickFilters:GetParent(),p.importantFilters)
 T.ok(not p.quickFilters:IsVisible());T.eq(p.quickPlacement,"popup");T.eq(p.quickFilterHeight,0)
 T.near(p.search:GetWidth(),p.main:GetWidth()-60,.01,"search always fills the main search row")
 T.eq(p.search:GetHeight(),48)
 p:SetFiltersOpen(true);T.ok(p.importantFilters:IsShown());T.ok(p.filterPanel:GetWidth()>=u.Theme.findFilterWideWidth)
 T.eq(p.importantFilters:GetWidth(),p.filterViewport:GetWidth())
 local damage=p.quickChoices.damagePresence.button
 T.eq(damage.label:GetText(),locale=="zhCN" and "不限" or "Any")
 Click(damage);T.eq(damage.label:GetText(),locale=="zhCN" and "缺少" or "Lacks")
 Click(damage);T.eq(damage.label:GetText(),locale=="zhCN" and "已齐" or "Full")
 Click(damage,"RightButton")
 Role(p,"tankPresence","present");Role(p,"healerPresence","present")
 Click(damage);Click(damage)
 T.eq(g.filters.damagePresence,nil,"AND skips the impossible third present condition")
 T.ok(damage:IsEnabled(),"the role button still permits missing and reset under the AND constraint")
 Click(p.quickLogic);Role(p,"damagePresence","present")
 T.eq(g.filters.damagePresence,"present");T.ok(p.filtersOpen,"direct choices stay open")
 CheckFooter(p,locale,0)
 local calls,searches=0,0;local setFilters,search=g.SetFilters,g.Search.Search
 g.SetFilters=function(self,...) calls=calls+1;return setFilters(self,...) end
 g.Search.Search=function(self,...) searches=searches+1;return search(self,...) end
 local filters={};for key,value in pairs(g.filters) do filters[key]=value end
 a:SetSetting("showImportantFilters",true)
 T.same(g.filters,filters,"moving important filters preserves every active condition")
 T.eq(calls,0,"presentation settings do not apply filters again");T.eq(searches,0,"presentation settings do not search")
 T.ok(p.quickFilters:IsShown());T.ok(not p.importantFilters:IsShown());T.eq(p.filterPanel:GetWidth(),460)
 a:SetSetting("showImportantFilters",false)
 T.same(g.filters,filters);T.eq(calls,0);T.eq(searches,0)
 T.ok(p.importantFilters:IsShown());T.eq(p.quickFilters:GetParent(),p.importantFilters);T.eq(p.quickPlacement,"popup");T.eq(p.quickFilterHeight,0)
 Click(p.quickLogic);T.eq(g.filters.damagePresence,nil,"returning to AND clears the third present condition")
 Click(p.quickIdentity);Click(p.quickIdentity);T.eq(g.filters.hideSameSpec,true);T.eq(g.filters.hideSameClass,nil)
 Click(p.filterDone);p:SetFiltersOpen(true);T.eq(g.filters.hideSameSpec,true,"Done retains direct choices")
 Click(p.filterScrim);p:SetFiltersOpen(true);T.eq(g.filters.tankPresence,"present","outside closure retains choices")
 Click(p.clearFilters);T.eq(g.filters.tankPresence,nil);T.eq(g.filters.hideSameSpec,nil);T.eq(g.filters.roleMatchAny,nil)
 a:SetSetting("showImportantFilters",true);g.SetFilters,g.Search.Search=setFilters,search;p:SetFiltersOpen(false)
 local quickPoint={p.quickFilters:GetPoint()};T.eq(quickPoint[1],"RIGHT");T.eq(quickPoint[2],p.applicationSettings);T.eq(quickPoint[3],"LEFT");T.eq(quickPoint[4],-12);T.eq(quickPoint[5],0)
 local clearPoint={p.searchClear:GetPoint()};T.eq(clearPoint[2],p.searchModeToggle,"clear stays within the search field")
 local input=p.search.box;local inputWidth=input:GetWidth()
 T.near(inputWidth,p.search:GetWidth()-52-p.searchInputRight,.01);T.eq(input:GetHeight(),40)
 p:SelectCategory("seasonRaid");p:CommitChoice()
 T.ok(not p.quickFilters:IsShown());T.near(input:GetWidth(),inputWidth,.01,"categories do not change the full-width search field")
 p:SelectCategory("seasonDungeon");p:CommitChoice()
 T.eq(p.search.box,input);T.ok(u.Native.searchLease:IsOwned())
 T.near(input:GetWidth(),inputWidth,.01)
 local lease=u.Native.searchLease
 p:SetSidebarCollapsed(true,false);T.ok(input:GetWidth()>inputWidth)
 T.eq(p.quickFilterHeight,0)
 T.ok(Left(p.quickLogic)+p.quickLogic:GetWidth()<=p.quickFilters:GetWidth()+.01,"the last control stays inside the header strip")
 local getWidth=p.quickLogic.GetWidth
 p.quickLogic.GetWidth=function(self) return getWidth(self)+.0001 end
 local quickHeight=p.quickFilterHeight;p:LayoutQuickFilters();T.eq(p.quickFilterHeight,quickHeight,"native size rounding must not wrap a row that fits")
 p.quickLogic.GetWidth=getWidth;p:LayoutQuickFilters()
 p:SetSidebarCollapsed(false,false);T.eq(u.Native.searchLease,lease,"resizing preserves the native input lease")
 T.near(input:GetWidth(),inputWidth,.01)
 local nativeOwner={};GameTooltip:SetOwner(nativeOwner);GameTooltip:SetText("Native tooltip");GameTooltip:Show()
 local textTip
 for _,button in ipairs({p.searchModeToggle,p.quickChoices.tankPresence.button,p.quickChoices.healerPresence.button,p.quickChoices.damagePresence.button,p.quickIdentity,p.quickLogic}) do
  button:Fire("OnEnter")
  local tip=u.Tooltip.text;textTip=textTip or tip
  T.eq(tip,textTip,"all six control hints reuse one Lychee text tooltip")
  T.ok(u.Tooltip:IsOwned(button));T.ok(tip:IsOwned(button));T.eq(tip:GetParent(),u.frame)
  T.eq(tip.count,1);T.ok(tip.lines[1]:GetText()~="")
  T.ok(tip:GetWidth()<=300,"long hints keep the existing wrapping limit")
  T.ok(tip:GetWidth()<=tip.lines[1]:GetUnboundedStringWidth()+34,"short hints shrink to their text and side padding")
  T.eq(tip.lines[1]:GetWidth(),tip:GetWidth()-32)
  T.eq(GameTooltip.owner,nativeOwner);T.eq(GameTooltip:GetText(),"Native tooltip","control hints leave the native tooltip alone")
  button:Fire("OnLeave");T.ok(not tip:IsShown());T.eq(u.Tooltip.owner,nil)
 end
 p.searchModeToggle:Fire("OnEnter");p.searchModeToggle:Hide();T.ok(not textTip:IsShown(),"hiding the owner closes its text hint");p.searchModeToggle:Show()
 p.searchModeToggle:Fire("OnEnter");u:Hide(true);T.ok(not textTip:IsShown(),"window closure clears control hints");a:Open("find")
 GameTooltip:Hide()
 p:SetFiltersOpen(true)
 local scale=u.frame:GetScale()
 T.ok(p.filterScrim:IsShown());T.eq(p.filterPanel:GetWidth(),460)
 T.eq(p.filterWords,nil,"keyword UI is outside the selected scope")
 T.eq(p.memberLimit,5)
 T.eq(p.fMinMembers,p.filterFields.minMembers);T.eq(p.fMembers,p.filterFields.maxMembers,"member bounds use the validated numeric-field path")
 T.eq(p.fMinMembers.placeholder:GetText(),locale=="zhCN" and "最少 1" or "Min 1")
 T.eq(p.fMembers.placeholder:GetText(),locale=="zhCN" and "最多 5" or "Max 5")
 p.fMinMembers.box:UserType("1");p.fMembers.box:UserType("5")
 T.eq(g.filters.minMembers,1);T.eq(g.filters.maxMembers,5,"party size accepts its inclusive endpoints")
 Click(p.filterDone);T.ok(not p.filtersOpen,"Done accepts a valid member range");p:SetFiltersOpen(true)
 for _,invalid in ipairs({"100","0","6"}) do
  p.fMembers.box:UserType(invalid)
  T.eq(g.filters.minMembers,1);T.eq(g.filters.maxMembers,5,"an out-of-capacity party bound preserves the last valid range")
  T.ok(p.filterError:IsShown());Click(p.filterDone);T.ok(p.filtersOpen,"invalid member input cannot close through Done")
  T.eq(a.charPrefs.find.categoryPrefs.seasonDungeon.maxMembers,5,"invalid drafts never replace the saved numeric limit")
  p:SetFiltersOpen(false);p:SetFiltersOpen(true)
  T.eq(p.fMembers.box:GetText(),"5","reopening discards the invalid member draft")
 end
 p.fMinMembers.box:UserType("4");p.fMembers.box:UserType("3")
 T.eq(g.filters.minMembers,4);T.eq(g.filters.maxMembers,5,"an inverted member range preserves both valid bounds")
 Click(p.filterDone);T.ok(p.filtersOpen)
 p:SetFiltersOpen(false);p:SetFiltersOpen(true)
 T.eq(p.fMinMembers.box:GetText(),"4");T.eq(p.fMembers.box:GetText(),"5")
 p.fMinMembers.box:UserType("1.5");T.eq(g.filters.minMembers,4,"member bounds require integers")
 p.fMinMembers.box:UserType("");p.fMembers.box:UserType("")
 T.eq(g.filters.minMembers,nil);T.eq(g.filters.maxMembers,nil,"blank member bounds remain unrestricted")
 p.filterFields.minRating.box:UserType("2200")
 p.filterFields.maxRating.box:UserType("3000")
 p.filterFields.minItemLevel.box:UserType("260")
 p.filterFields.maxItemLevel.box:UserType("280")
 T.eq(g.filters.minRating,2200);T.eq(g.filters.maxRating,3000)
 T.eq(g.filters.minItemLevel,260);T.eq(g.filters.maxItemLevel,280)
 T.eq(p.filterCount,2,"each lower/upper pair counts as one filter")
 p.filterFields.maxRating.box:UserType("2100")
 T.eq(g.filters.maxRating,3000,"an inverted range preserves the last valid conditions")
 T.ok(p.filterError:IsShown())
 Click(p.filterDone);T.ok(p.filtersOpen,"Done leaves an invalid draft open for correction")
 p:SetFiltersOpen(false);p:SetFiltersOpen(true)
 T.eq(p.filterFields.maxRating.box:GetText(),"3000","reopening restores the valid saved range")
 p.filterFields.minRating.box:UserType("-1");T.eq(g.filters.minRating,2200)
 p.filterFields.minRating.box:UserType("2.5");T.eq(g.filters.minRating,2200)
 p.filterFields.minRating.box:UserType("2200")
 Click(p.quickChoices.tankPresence.button);T.eq(g.filters.tankPresence,"missing")
 Click(p.quickChoices.healerPresence.button);T.eq(g.filters.healerPresence,"missing")
 Click(p.quickChoices.healerPresence.button);T.eq(g.filters.healerPresence,"present")
 Click(p.quickLogic);T.eq(g.filters.roleMatchAny,true)
 T.ok(p.quickIdentityFunnel:IsShown());T.ok(not p.quickIdentityIcon:IsShown())
 T.eq(p.quickIdentityFunnel:GetTexture(),"Interface\\AddOns\\LycheeGroup_UI\\Media\\filter-any.tga","Any uses the restored generated neutral icon")
 Click(p.quickIdentity);T.eq(g.filters.hideSameClass,true);T.eq(g.filters.hideSameSpec,nil)
 T.ok(p.quickIdentityIcon:IsShown());T.ok(not p.quickIdentityFunnel:IsShown())
 local identityWidth=p.quickIdentity:GetWidth()
 T.ok(identityWidth>=p.quickIdentity.label:GetStringWidth()+40)
 Click(p.quickIdentity);T.eq(g.filters.hideSameSpec,true);T.eq(g.filters.hideSameClass,nil)
 T.eq(p.quickIdentity:GetWidth(),identityWidth,"cycling identity modes keeps the button width")
 local saved=a.charPrefs.find.categoryPrefs.seasonDungeon
 T.eq(saved.minRating,2200);T.eq(saved.maxItemLevel,280);T.eq(saved.roleMatchAny,true)
 p:SelectCategory("seasonRaid")
 T.eq(g.filters.minRating,nil);T.eq(g.filters.roleMatchAny,nil);T.ok(not p.quickFilters:IsShown())
 p:SelectCategory("seasonDungeon")
 T.eq(g.filters.minRating,2200);T.eq(g.filters.maxItemLevel,280);T.eq(g.filters.roleMatchAny,true)
 T.eq(g.filters.tankPresence,"missing");T.ok(p.quickIdentity.active);T.eq(g.filters.hideSameSpec,true)
 Click(p.quickChoices.tankPresence.button,"RightButton");T.eq(g.filters.tankPresence,nil)
 Click(p.quickIdentity);T.eq(g.filters.hideSameSpec,nil);T.eq(g.filters.hideSameClass,nil)
 Click(p.quickIdentity);T.eq(g.filters.hideSameClass,true)
 p:SelectCategory("seasonRaid");T.eq(g.filters.hideSameClass,nil)
 p:SelectCategory("seasonDungeon");T.eq(g.filters.hideSameClass,true,"same-class filtering is restored for its category")
 p:RestoreCategory({hideSameClass=true,hideSameSpec=true});p:UpdateFilters()
 T.eq(g.filters.hideSameClass,true);T.eq(g.filters.hideSameSpec,nil,"legacy dual flags migrate to same-class mode")
 Click(p.quickIdentity,"RightButton");T.eq(g.filters.hideSameClass,nil);T.eq(g.filters.hideSameSpec,nil)
 T.ok(p.quickIdentityFunnel:IsShown())
 p:ClearFilters()
 for _,key in ipairs({"minRating","maxRating","minItemLevel","maxItemLevel","tankPresence","healerPresence","damagePresence","roleMatchAny","hideSameSpec","hideSameClass"}) do T.eq(g.filters[key],nil) end
 T.eq(p.filterFields.minRating.box:GetText(),"");T.eq(p.filterCount,0)
 p:SetFiltersOpen(false);T.ok(not p.filterScrim:IsShown());T.eq(u.frame:GetScale(),scale)

 -- Geometry responds to the existing minimum window and large fonts.
 a:SetSetting("fontScale",130);u:SetWindowSize(1,1);p:SetFiltersOpen(true)
 a:SetSetting("showImportantFilters",false)
 T.ok(p.filterPanel:GetWidth()>=u.Theme.findFilterWideWidth,"the popup expands when the compact text styles need more width")
 T.eq(p.importantFilters:GetWidth(),p.filterViewport:GetWidth())
 T.ok(p.filterPanel:GetWidth()<=u.frame:GetWidth()-40,"the expanded popup keeps both window margins")
 T.ok(p.importantFilters:IsShown())
 T.ok(Top(p.filterPanel)+p.filterPanel:GetHeight()<=u.frame:GetHeight()-20,locale.." default compact popup fits the minimum window at 130 percent")
 for _,entry in pairs(p.quickChoices) do
  local button=entry.button
  T.ok(button.label:GetStringWidth()<=button.label:GetWidth(),locale.." compact role fits its full text at the minimum window")
 end
 Role(p,"damagePresence","present")
 local damage=p.quickChoices.damagePresence.button
 T.eq(damage.label:GetText(),locale=="zhCN" and "已齐" or "Full")
 a:SetSetting("showImportantFilters",true)
 T.ok(Top(p.filterPanel)+p.filterPanel:GetHeight()<=u.frame:GetHeight()-20,locale.." filter overlay stays inside the resized main window")
 T.ok(Top(p.filterFooter)+Top(p.filterDone)+p.filterDone:GetHeight()<=p.filterPanel:GetHeight()-20)
 for _,pair in ipairs({{"minRating","maxRating"},{"minItemLevel","maxItemLevel"}}) do
  local low,high=p.filterFields[pair[1]],p.filterFields[pair[2]]
  T.eq(low:GetParent(),high:GetParent(),"range bounds share one input group")
  T.eq(Top(low),Top(high));T.ok(Left(low)+low:GetWidth()<=Left(high))
  T.ok(Left(high)+high:GetWidth()<=high:GetParent():GetWidth())
 end
 T.eq(p.quickFilters:GetParent(),p.applicationPanel,"important filters belong to the application area")
 T.near(p.search:GetWidth(),p.main:GetWidth()-60,.01,"search keeps the entire available row")
 for _,button in ipairs({p.quickChoices.tankPresence.button,p.quickChoices.healerPresence.button,p.quickChoices.damagePresence.button,p.quickIdentity,p.quickLogic}) do
  T.ok(Left(button)>=0 and Left(button)+button:GetWidth()<=p.quickFilters:GetWidth(),"each filter stays within the right area")
 end
 T.ok(p.quickIdentity:GetWidth()>=p.quickIdentity.label:GetStringWidth()+40,"large-font labels keep their icon padding")
 T.eq(p.search:GetHeight(),48,"wrapping right-side filters does not enlarge the search capsule")
 local strip={p.quickFilters:GetPoint()};T.eq(strip[1],"RIGHT");T.eq(strip[2],p.applicationSettings);T.eq(strip[3],"LEFT");T.eq(strip[4],-12);T.eq(strip[5],0)
 T.eq(Top(p.applicationPanel),68);T.eq(p.quickFilterHeight,0)
 T.eq(p.applicationPanel:GetHeight(),44+(p.appsHeight or 0),"header filters do not add an application row")
 T.eq(Top(p.applicationHeader),40)
 T.eq(Top(p.appList),44+p.applicationHeader:GetHeight())
 T.ok(p.search.box:GetWidth()>=160,"the search field retains typing space at the minimum window")
 T.eq(p.search.box,input);T.eq(p.search.box:GetHeight(),40)
 local inputCorner={input:GetPoint(2)};T.eq(inputCorner[5],4,"native input stays within the search capsule")
 local panelScale=u.frame:GetScale();Click(p.filterScrim);T.ok(not p.filtersOpen);T.eq(u.frame:GetScale(),panelScale)

 -- The provider uses the same numeric/role predicates as the live result service.
 a:SetSetting("fontScale",100)
 u:StartPreview("applications");local preview=u.preview.provider
 p=u.pages.find;p:CommitChoice();preview.apps={}
 for index,id in ipairs(preview.recordIDs) do
  local record=preview.records[id]
  record.requiredItemLevel=100+index*10;record.leaderRating=index*1000
  if index==6 then record.leaderRating=nil end
 end
 p:RefreshApplications();p:ClearFilters()
 p.filterFields.minRating.box:UserType("3000");p.filterFields.maxRating.box:UserType("3000")
 p.filterFields.minItemLevel.box:UserType("130");p.filterFields.maxItemLevel.box:UserType("130")
 T.same(preview:GetResults(),{-9003},"inclusive rating and item-level bounds select the exact matching record")
 CheckFooter(p,locale,1)
 p.filterFields.minRating.box:UserType("4000")
 T.same(preview:GetResults(),{-9003},"invalid preview input also preserves the active range")
 p:ClearFilters();p.filterFields.maxRating.box:UserType("6000")
 T.eq(#preview:GetResults(),5,"an unknown rating is excluded even below a high maximum")
 CheckFooter(p,locale,5)
 p:ClearFilters()
 for index,id in ipairs(preview.recordIDs) do preview.records[id].details.counts={TANK=index==1 and 0 or 1,HEALER=index==2 and 0 or 1,DAMAGER=2} end
 Click(p.quickChoices.tankPresence.button);Click(p.quickChoices.healerPresence.button)
 T.same(preview:GetResults(),{},"AND needs both missing roles")
 CheckFooter(p,locale,0)
 Click(p.quickLogic)
 local ids=preview:GetResults();table.sort(ids);T.same(ids,{-9002,-9001},"OR accepts either missing role")
 CheckFooter(p,locale,2)
 local playerClass=select(2,UnitClass("player"))
 for index,id in ipairs(preview.recordIDs) do
  preview.records[id].details.members={{class=index==1 and playerClass or "OTHER",assignedRole="HEALER"}}
 end
 Click(p.quickIdentity)
 T.same(preview:GetResults(),{-9002},"same-class exclusion applies independently of the T/H/D OR combination")
 T.eq(a.charPrefs.find.categoryPrefs.seasonDungeon.hideSameClass,nil,"preview class filtering never writes real character preferences")
 Click(p.quickIdentity,"RightButton");ids=preview:GetResults();table.sort(ids);T.same(ids,{-9002,-9001})
 T.eq(a.charPrefs.find.categoryPrefs.seasonDungeon.minRating,nil,"preview filters never write real character preferences")
 u:StopPreview();u:Hide(true)
 T.eq(p.resultsHeader:GetScript("OnUpdate"),nil)
end

-- Capacity follows the real catalog, picker selections and validated UI fields.
do
 local f=Fixture("enUS");local a,u,g=f.A,f.U,f.G;a:SetSetting("reduceMotion",true);a:Open("find")
 local p=u.pages.find
 local function Activity(key)
  if not p.picker:IsShown() then p:SelectCategory(g.filters.category) end
  for _,row in ipairs(p.activities.rows) do if row.key==key and row:IsVisible() then Click(row);return end end
  error("missing activity group "..tostring(key))
 end
 local function Difficulty(value)
  if not p.picker:IsShown() then p:SelectCategory(g.filters.category) end
  for _,button in ipairs(p.difficultyButtons) do if button.value==value and button:IsShown() then Click(button);return end end
  error("missing difficulty "..tostring(value))
 end
 p:SelectCategory("seasonRaid");p:CommitChoice();p:SetFiltersOpen(true)
 T.eq(p.memberLimit,30);T.eq(p.fMembers.placeholder:GetText(),"Max 30")
 p.fMinMembers.box:UserType("20");p.fMembers.box:UserType("30")
 T.eq(g.filters.minMembers,20);T.eq(g.filters.maxMembers,30,"the fixture's real raid activity accepts a 20-to-30 range")
 p.fMembers.box:UserType("31");T.eq(g.filters.maxMembers,30)
 Click(p.filterDone);T.ok(p.filtersOpen,"raid bounds above capacity cannot be confirmed")
 p:SetFiltersOpen(false);p:SetFiltersOpen(true);T.eq(p.fMembers.box:GetText(),"30")
 p:SetFiltersOpen(false)

 local getInfo,getActivities,getCategories=C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities,C_LFGList.GetAvailableCategories
 local dungeon={};for key,value in pairs(getInfo(2)) do dungeon[key]=value end;dungeon.maxNumPlayers=20
 local extra={
  [2]=dungeon,
  [11]={id=11,categoryID=3,mapID=110,fullName="Twenty-player raid",groupFinderActivityGroupID=10,difficultyID=16,maxNumPlayers=20,orderIndex=2},
  [12]={id=12,categoryID=3,mapID=110,fullName="Forty-player raid",groupFinderActivityGroupID=11,difficultyID=9,maxNumPlayers=40,orderIndex=3},
  [21]={id=21,categoryID=2,fullName="Second capacity fixture",groupFinderActivityGroupID=21,difficultyID=8,isMythicPlusActivity=true,maxNumPlayers=40,orderIndex=3},
  [41]={id=41,categoryID=4,fullName="Zero-capacity arena",groupFinderActivityGroupID=41,maxNumPlayers=0,orderIndex=1},
  [91]={id=91,categoryID=9,fullName="Zero-capacity rated battleground",groupFinderActivityGroupID=91,maxNumPlayers=0,orderIndex=1},
 }
 C_LFGList.GetActivityInfoTable=function(id) return extra[id] or getInfo(id) end
 C_LFGList.GetAvailableActivities=function(category,...)
  if category==3 then return {1,11,12} elseif category==2 then return {2,3,21}
  elseif category==4 then return {41} elseif category==9 then return {91} end
  return getActivities(category,...)
 end
 C_LFGList.GetAvailableCategories=function() return {2,3,4,9} end
 g.Catalog:Invalidate();g:Notify("activities")
 T.eq(p.memberLimit,40,"all matching raid variants use the largest advertised capacity")
 p:SelectCategory("seasonRaid");Difficulty(16)
 T.eq(p.memberLimit,20);T.eq(g.filters.minMembers,20);T.eq(g.filters.maxMembers,20,"a smaller difficulty clamps both active bounds")
 T.eq(p.fMinMembers.box:GetText(),"20");T.eq(p.fMembers.box:GetText(),"20")
 T.eq(a.charPrefs.find.categoryPrefs.seasonRaid.maxMembers,20,"capacity changes save valid clamped bounds")
 Activity(11);T.eq(p.memberLimit,40,"selecting a different activity group uses that group's capacity")
 Activity(0);Difficulty(14);T.eq(p.memberLimit,30,"difficulty filtering excludes larger variants of the same category")

 -- Deliberately different advertised capacities exercise the actual keystone
 -- multi-select path without replacing Catalog:Matches or the Find controller.
 p:SelectCategory("seasonDungeon");Difficulty(8);Activity(20);Activity(21);Click(p.pickerConfirm)
 T.eq(p.memberLimit,40);T.same(g.filters.groupKeys,{[20]=true,[21]=true},"capacity uses the confirmed multiple-group selection")
 p:SetFiltersOpen(true);p.fMembers.box:UserType("30");T.eq(g.filters.maxMembers,30);p:SetFiltersOpen(false)
 p:SelectCategory("seasonDungeon");Activity(21);Click(p.pickerConfirm)
 T.same(g.filters.groupKeys,{[20]=true});T.eq(p.memberLimit,20,"an unselected larger group cannot raise the member limit")
 T.eq(g.filters.maxMembers,20);T.eq(p.fMembers.box:GetText(),"20","reducing a multi-selection clamps its saved range")
 p:SelectCategory("9");T.eq(p.memberLimit,10,"native zero-capacity rated battlegrounds use their real ten-player bracket")
 T.eq(p.fMembers.placeholder:GetText(),"Max 10")
 p:SelectCategory("4");T.eq(p.memberLimit,40,"other native zero-capacity activities use MAX_RAID_MEMBERS")
 T.eq(p.fMembers.placeholder:GetText(),"Max 40")
 C_LFGList.GetActivityInfoTable,C_LFGList.GetAvailableActivities,C_LFGList.GetAvailableCategories=getInfo,getActivities,getCategories
 u:Hide(true)
end

-- Old saved drafts are normalized once, then persisted as valid numeric bounds.
do
 local prefs={find={category="seasonDungeon",categoryPrefs={seasonDungeon={selected=true,difficultyID=8,minMembers=100,maxMembers=0}}}}
 local f=Fixture("enUS",prefs);local a,u,g=f.A,f.U,f.G;a:SetSetting("reduceMotion",true);a:Open("find")
 local p=u.pages.find;local saved=a.charPrefs.find.categoryPrefs.seasonDungeon
 T.eq(g.filters.minMembers,1);T.eq(g.filters.maxMembers,5,"restoring old bounds clamps and orders them against current capacity")
 T.eq(p.fMinMembers.box:GetText(),"1");T.eq(p.fMembers.box:GetText(),"5")
 T.eq(saved.minMembers,1);T.eq(saved.maxMembers,5,"only valid normalized numbers remain in character preferences")
 u:Hide(true)
end
