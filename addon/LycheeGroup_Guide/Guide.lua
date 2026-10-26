-- One continuous tour owns a private player/provider graph and a reusable spotlight.
-- Package loading performs no client reads and creates no native objects or jobs.
local A=_G.LycheeGroup
local Guide={version=4}
A.Guide=Guide
local function S(cn,en) return A:GetLocale()=="zhCN" and cn or en end
local sequence={"activity","sidebar","filters","details","sort","apply","raidActivity","raidDetails","createPage","createActivity","publish","applicantDetails","faction","time","resize"}
local demoPlayer={class="SHAMAN",specID=264,role="HEALER",itemLevel=280,roles={TANK=false,HEALER=true,DAMAGER=true}}
local function Metadata()
 local data=type(A.db.guide)=="table" and A.db.guide or {}
 A.db.guide=data
 return data
end
local function FirstRow(list,key,excludeAll)
 for _,row in ipairs(list and list.rows or {}) do
  if row.key and (not key or row.key==key) and (not excludeAll or row.key~=0) and row._hitVisible and row:IsShown() then return row end
 end
end
local function HeaderButton(header,key)
 for _,button in ipairs(header and header.buttons or {}) do if button.definition.key==key then return button end end
end
local function ApplicantRow(page)
 for _,batch in ipairs(page.batchPool or {}) do
  if batch.appID and batch:IsShown() then
   for _,row in ipairs(batch.people) do if row.member and row._hitVisible~=false and row:IsShown() then return row end end
  end
 end
end

function Guide:Bind()
 local UI=A.UI
 self.active=true
 A.GuideEntry:ReleaseShow()
 self.Adapter:Attach()
 if not self.events then
  self.events=CreateFrame("Frame")
  self.events:SetScript("OnEvent",function() Guide:Stop("interrupted") end)
 end
 self.events:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function Guide:Open()
 if InCombatLockdown() then return false,S("战斗结束后可以开始引导。","Start the guide after combat ends.") end
 if self.active then self:Stop("interrupted") end
 local UI=A.UI
 if not UI:IsShown() then UI:Show("settings") end
 self:Bind()
 UI:CloseMenu();UI:CloseModal("guide");UI.Tooltip:Hide()
 self.Adapter:CaptureGeometry()
 self.transition=true;self.Adapter.starting=true;UI:Hide(true);self.Adapter.starting=nil;self.transition=nil
 self.standalone=true
 self.View:ShowIntroduction(S("感谢您使用荔枝组队，我们创建了一个新手引导，来帮助你更好的使用它","Thank you for using Lychee LFG. We created this guide to help you use it."))
 return true
end

function Guide:Start()
 if InCombatLockdown() then self:Stop("interrupted");return false end
 local UI=A.UI
 self.standalone=nil
 if self.ownsPreview then self:Stop("interrupted","navigate") end
 if not self.active then self:Bind() end
 local group,err=A:Ensure("Group")
 if not group then self:Stop("later");A:Print(err);return false,err end
 local resolved,activity,category=pcall(self.ResolveActivity,self,group.Catalog)
 if not resolved then self:Stop("interrupted");error(activity,0) end
 if not activity then self:Stop("later");A:Print(category);return false,category end
 self.dungeonActivity,self.dungeonCategory=activity,category
 local raidOK,raid,raidCategory=pcall(self.ResolveRaid,self,group.Catalog)
 if not raidOK then self:Stop("interrupted");error(raid,0) end
 self.raidActivity,self.raidCategory=raid,raidCategory
 local steps={}
 for _,id in ipairs(sequence) do
  if (id~="time" or activity.isMythicPlusActivity) and (id~="raidActivity" and id~="raidDetails" or self.raidActivity) then steps[#steps+1]=id end
 end
 self.page,self.steps,self.index,self.phase="find",steps,1,1
 self.transition,self.ownsPreview=true,true
 local success,ok,reason=pcall(self.Adapter.Start,self.Adapter,"applications",
  {catalog=group.Catalog,activity=activity,category=category,player=demoPlayer})
 self.transition=nil
 if not success then self:Stop("interrupted");error(ok,0) end
 if not ok then self:Stop("later");A:Print(reason);return false,reason end
 self.standalone=nil
 UI.preview.provider.applicationPrefs.roles={}
 self.View:Hide()
 local delay=A:GetSetting("reduceMotion") and 0 or math.max(UI.Theme.windowPageMotionDuration,UI.Theme.windowOpenDuration or .42)
 self:Present(delay)
 return true
end

function Guide:CancelTask()
 if self.task then self.task:Cancel();self.task=nil end
end

function Guide:Present(delay)
 self:CancelTask();self.ready=nil
 if not self.active or not self.steps then return end
 if delay and delay>0 then
  self.task=C_Timer.NewTimer(delay,function()
   Guide.task=nil
   if Guide.active and Guide.steps then Guide:Present() end
  end)
  return
 end
 local UI=A.UI
 if not self.ownsPreview or not self.Adapter:IsPreview(UI.preview) then self:Stop("interrupted");return end
 self.preparing=true
 local ok,err=pcall(self.PrepareStep,self)
 self.preparing=nil
 if not ok then self:Stop("interrupted");error(err,0) end
 self.ready=true
 self:UpdateStep()
end

function Guide:PrepareStep()
 local UI=A.UI;local page=UI.pages[self.page];local id=self.steps[self.index]
 self:ReleaseBindings()
 self.detailsArea,self.detailsLeaving=nil,nil
 UI:StopWindowResize();UI:StopTableDrags();UI:CloseMenu();UI:CloseModal("guide-step");UI.Tooltip:Hide()
 self.phase=1;self.pendingAdvance=nil
 self.activityChoiceGoal=nil
 if page.ClosePicker then page:ClosePicker() end
 if page.FinishSidebar then page:FinishSidebar() end
 if self.page=="find" then
  page:SetFiltersOpen(false)
  if id=="activity" then page:SetSidebarCollapsed(false,false,false)
  elseif id=="details" or id=="apply" or id=="raidActivity" or id=="raidDetails" then page:ClearFilters();page:ClearSearch() end
  if id=="createPage" then UI.preview.provider:BindActivity(self.dungeonActivity,self.dungeonCategory) end
 elseif id=="createActivity" then
  UI.Native:SetPreviewCreationText(S("一起限时，轻松打","A relaxed timed run"),S("熟悉路线，等大家准备好再出发。","Know the route; start when everyone is ready."))
 end
end

function Guide:PrepareActivityPicker()
 local UI=A.UI;local page=UI.pages.find;local activity=UI.preview.provider.activity
 if activity.isMythicPlusActivity then
  for _,button in ipairs(page.difficultyButtons or {}) do
   if button:IsShown() and button.value==activity.difficultyID then
    local click=button:GetScript("OnClick");if click then click(button,"LeftButton") end
    break
   end
  end
 end
 local count=0;for _ in pairs(page.keystoneGroups or {}) do count=count+1 end
 self.activityChoiceGoal=count>0 and math.min(2,count) or nil
 UI.Motion:FinishPlacement(page.picker)
end

function Guide:ActivityChoiceCount()
 local count=0
 for key in pairs(A.UI.pages.find.draftGroupKeys or {}) do
  if A.UI.pages.find.keystoneGroups[key] then count=count+1 end
 end
 return count
end

function Guide:RoleFilterTarget()
 local page=A.UI.pages.find
 local choice=page.quickChoices and page.quickChoices.healerPresence
 if choice and choice.button:IsVisible() then return choice.button end
end

local function Bounds(frame)
 if not frame or not frame:IsVisible() then return end
 local window=A.UI.frame;local scale=frame:GetEffectiveScale()/window:GetEffectiveScale()
 local left,top=frame:GetLeft(),frame:GetTop();if not left or not top then return end
 left,top=left*scale-window:GetLeft(),window:GetTop()-top*scale
 return left,top,left+frame:GetWidth()*scale,top+frame:GetHeight()*scale
end
function Guide:Region(key,left,top,right,bottom)
 self.regions=self.regions or {}
 local frame=self.regions[key]
 if not left or right<=left or bottom<=top then if frame then frame:Hide() end;return end
 if not frame then frame=CreateFrame("Frame",nil,A.UI.frame);frame:EnableMouse(false);self.regions[key]=frame end
 if frame.left~=left or frame.top~=top then
  frame:ClearAllPoints();frame:SetPoint("TOPLEFT",A.UI.frame,"TOPLEFT",left,-top);frame.left,frame.top=left,top
 end
 if frame.width~=right-left or frame.height~=bottom-top then
  frame:SetSize(right-left,bottom-top);frame.width,frame.height=right-left,bottom-top
 end
 frame:Show();return frame
end
function Guide:ListRegion(column)
 local page=A.UI.pages[self.page]
 local header=self.page=="find" and page.resultsHeader or page.applicantTable
 local list=self.page=="find" and page.results or page.batchScroll
 local left,top,right=Bounds(column or header);local x,_,r,bottom=Bounds(list)
 if not left or not x then return end
 if not column then left,right=math.min(left,x),math.max(right,r) end
 return self:Region("list",left,top,right,bottom)
end
function Guide:VisualTarget(target)
 if self.steps[self.index]~="createPage" or not target then return target end
 local left,top,right,bottom=Bounds(target.icon)
 local x,y,r,b=Bounds(target.label)
 if not left or not x then return target end
 return self:Region("navigation",math.min(left,x),math.min(top,y),math.max(right,r),math.max(bottom,b)) or target
end
function Guide:RevealFrame()
 local id,phase=self.steps[self.index],self.phase;local page=A.UI.pages[self.page]
 if id=="activity" and (phase==2 or phase==3) and self.activityChoiceGoal then return page.activities end
 if id=="details" or id=="raidDetails" or id=="applicantDetails" or id=="apply" and phase==1 then return self:ListRegion() end
 if id=="sort" then return self:ListRegion(HeaderButton(page.resultsHeader,"rating")) end
 if id=="faction" or id=="time" then return self:ListRegion() end
end

function Guide:Target()
 local UI=A.UI;local page=UI.pages[self.page];local id=self.steps[self.index];local phase=self.phase
 if id=="raidActivity" then
  if phase==1 then return FirstRow(page.seasonCategories,self.raidCategory) or FirstRow(page.categories,self.raidCategory) end
  return FirstRow(page.activities,A.UI.preview.provider.Catalog:GetGroupKey(self.raidCategory,self.raidActivity))
 elseif id=="activity" then
   if phase==1 or not page.picker or not page.picker:IsShown() then
    local key=UI.preview.provider.category
    return FirstRow(page.seasonCategories,key) or FirstRow(page.categories,key)
   elseif phase==4 and page.pickerConfirm:IsShown() then return page.pickerConfirm
   elseif self.activityChoiceGoal then
    for _,row in ipairs(page.activities.rows) do
     if row._hitVisible and row:IsShown() and page.keystoneGroups[row.key] and not page.draftGroupKeys[row.key] then return row end
    end
   end
   return FirstRow(page.activities,nil,true)
 elseif id=="createPage" then return UI.navItems.create
 elseif id=="createActivity" then
  if phase==1 or not page.picker or not page.picker:IsShown() then return page.pickerTrigger end
  return FirstRow(page.pickerResults)
 elseif id=="sidebar" then return page.sidebarToggle
 elseif id=="filters" then
  if phase==1 or not page.filtersOpen then return page.quickPlacement=="header" and self:RoleFilterTarget() or page.filterToggle end
  return phase==2 and self:RoleFilterTarget() or page.filterDone
 elseif id=="details" or id=="raidDetails" or id=="applicantDetails" then
  if phase>=2 and self.detailsArea then return self.detailsArea end
  if id=="applicantDetails" then local row=ApplicantRow(page);return row and row.tooltipArea end
  local row=FirstRow(page.results)
  return row and row.tooltipArea
 elseif id=="sort" then
  return HeaderButton(page.resultsHeader,"rating")
 elseif id=="apply" then
  local modal=UI.Application.applicationModal
  if phase==2 and modal and modal.frame:IsShown() then return modal.roles.HEALER
  elseif phase==3 and modal and modal.frame:IsShown() then return modal.autoApply
  elseif phase==4 and modal and modal.frame:IsShown() then return modal.submit
  elseif phase==5 then local row=FirstRow(page.appList,self.appliedID);return row and row.cancel end
  return FirstRow(page.results)
 elseif id=="publish" then return page.publish
 elseif id=="resize" then return UI.resizeHandle
 else
  local row=ApplicantRow(page)
  if row then return id=="faction" and row.factionButton or row.mapScoreButton end
 end
end

function Guide:Instruction()
 local id,phase=self.steps[self.index],self.phase
 if id=="raidActivity" then
  return phase==1 and S("点击团队副本分类，看看团本队伍。","Click the raid category to explore raid groups.")
   or S("点击一个团队副本，查看队伍。","Click a raid to view its groups.")
 elseif id=="raidDetails" then
  if phase==1 then return S("移到团本队伍左侧，查看队伍概览和首领进度。","Hover over the left side of a raid group to see its overview and boss progress.") end
  if phase==2 then return S("鼠标保持在队伍或详情上，按 Shift 展开成员名单。","Keep the pointer over the group or tooltip and press Shift to expand the member list.") end
  return S("成员名单已展开。看完后，把鼠标移到空白处继续。","The member list is expanded. Move the pointer to an empty area when you're done.")
 elseif id=="applicantDetails" then
  return phase==1 and S("移到申请者姓名处，查看个人资料、装备和副本成绩。","Hover over an applicant's name to view their profile, equipment and dungeon results.")
   or S("看完个人资料后，把鼠标移到空白处继续。","Move the pointer to an empty area after reading the profile.")
 elseif id=="activity" then
   if phase==1 then return S("点击左侧地下城分类，选择要去的副本。","Click the dungeon category on the left to choose where to go.") end
   if phase==2 then return self.activityChoiceGoal and S("先勾选一个想去的大秘境。","Select one Mythic+ dungeon you want to run.") or S("点击一个想去的副本。","Click a dungeon you want to run.") end
   if phase==3 then return S("再勾选一个副本，同时搜索多个大秘境。","Select another dungeon to search several Mythic+ dungeons together.") end
   return S("点击“搜索所选副本”，查看队伍。","Click Search selected dungeons to view groups.")
 elseif id=="createPage" then return S("点击“建队”，试试发布队伍和查看申请者。","Click Create to try listing a group and viewing applicants.")
 elseif id=="createActivity" then
  return phase==1 and S("点击这里，选择要招募的副本。","Click here to choose a dungeon for your group.")
   or S("点击一个副本，返回招募表单。","Click a dungeon to return to the listing form.")
 elseif id=="sidebar" then
  return phase==1 and S("点击左下角，收起侧栏。","Click the bottom-left button to collapse the sidebar.")
   or S("再点一次，展开侧栏。","Click again to expand the sidebar.")
 elseif id=="filters" then
  local page=A.UI.pages.find
  if phase==1 and page.quickPlacement~="header" then return S("点击“筛选”，设置队伍条件。","Click Filters to set group requirements.") end
  if phase<3 and self:RoleFilterTarget() then return S("点击治疗职责，将“不限”切换为“缺少”。","Click the Healer condition to change Any to Lacks.") end
  return S("点击“完成”，查看筛选后的队伍。","Click Done to view the filtered groups.")
 elseif id=="details" then
  if phase==1 then return S("移到队伍左侧，查看队长、成员和备注。","Hover over the left side of a group to see its leader, members and note.") end
  return S("看完后，把鼠标移到空白处，继续下一步。","When you're done, move the pointer to an empty area to continue.")
 elseif id=="sort" then
  return phase==1 and S("点击表头，按这一列排序。","Click the column heading to sort the list.")
   or S("再点一次，切换升降序。","Click again to reverse the order.")
 elseif id=="apply" then
  if phase==1 then return S("双击这支队伍，打开申请。","Double-click this group to apply.") end
  if phase==2 then return S("点击治疗，选择报名职责。","Click Healer to select your role.") end
  if phase==3 then return S("打开“自动申请”。保存职责后，下次双击队伍就会直接申请。","Turn on Auto apply. After saving your role, double-clicking a group will apply immediately.") end
  if phase==4 then return S("点击“申请”，保存职责并提交申请。","Click Apply to save your role and send the application.") end
  return S("申请显示在“我的申请”。点击取消按钮，撤回这条申请。","Your request appears in My applications. Click its cancel button to withdraw it.")
 elseif id=="publish" then return S("点击“发布队伍”，查看申请者。","Click Publish group to view applicants.")
 elseif id=="faction" then
  return phase==1 and S("点击阵营图标，查看种族。","Click the faction icon to see the applicant's race.")
   or S("再点一次，切回阵营。","Click again to return to the faction.")
 elseif id=="time" then
  return phase==1 and S("点击单本分，查看实际用时与副本限时。","Click the dungeon score to see the run time and dungeon time limit.")
   or S("再点一次，切回单本分。","Click again to return to the dungeon score.")
 elseif id=="resize" then return S("拖动右下角改变窗口大小，松开鼠标后继续。","Drag the bottom-right corner to resize, then release the mouse.")
 end
end

function Guide:UpdateStep()
 if not self.ready or self.preparing or self.pendingAdvance or not self.active then return end
 self:RecoverPhase()
 local UI=A.UI;local text=self:Instruction()
 local target=self:Target()
 local avoid=self:AvoidFrame()
 local context=self:ContextFrame()
 local reveal=self:RevealFrame()
 self.View:SetRevealFrame(reveal)
 self.View:SetContextFrame(context)
 self.View:SetAvoidFrame(avoid)
 self.View:ShowStep(self:VisualTarget(target),text,self.index,#self.steps)
 self:BindStep(target,avoid,context)
end

function Guide:SetPhase(phase)
 self.phase=phase
 self:UpdateStep()
end

function Guide:UseCreationActivity(activity)
 local timeIndex,factionIndex
 for i,id in ipairs(self.steps) do
  if id=="time" then timeIndex=i elseif id=="faction" then factionIndex=i end
 end
 if activity.isMythicPlusActivity and not timeIndex then table.insert(self.steps,factionIndex+1,"time")
 elseif not activity.isMythicPlusActivity and timeIndex then table.remove(self.steps,timeIndex) end
end

-- Advance after the control's current callback unwinds. There is at most one
-- cancellable task; refreshes and programmatic setters cannot complete a step.
function Guide:QueueAdvance()
 if self.pendingAdvance then return end
 self:CancelTask();self.pendingAdvance=true;self.ready=nil
 self.task=C_Timer.NewTimer(0,function()
  Guide.task=nil;Guide.pendingAdvance=nil
  if not Guide.active or not Guide.steps then return end
  if Guide.index==#Guide.steps then
   local data=Metadata();data.completedVersion=Guide.version;data.completed=true;Guide:Stop("complete")
  else
   local changingPage=Guide.steps[Guide.index]=="createPage"
   Guide.index=Guide.index+1
   if changingPage and not A:GetSetting("reduceMotion") then
    Guide.View:Hide();Guide:Present(A.UI.Theme.windowPageMotionDuration)
   else Guide:Present() end
  end
 end)
end

function Guide:Stop(reason,source)
 if not self.active then return end
 local standalone=self.standalone;self.standalone=nil
 self.active,self.ownsPreview=nil,nil
 self:ReleaseBindings()
 self.detailsArea,self.detailsLeaving=nil,nil
 self:CancelTask();self.events:UnregisterAllEvents();self.View:Hide()
 for _,frame in pairs(self.regions or {}) do
  frame:Hide();frame:ClearAllPoints();frame.left,frame.top,frame.width,frame.height=nil,nil,nil,nil
 end
 self.page,self.steps,self.index,self.phase=nil,nil,nil,nil
 self.preparing,self.transition,self.ready,self.pendingAdvance,self.appliedID=nil,nil,nil,nil,nil
 self.activityChoiceGoal=nil
 self.raidActivity,self.raidCategory,self.dungeonActivity,self.dungeonCategory=nil,nil,nil,nil
 if reason=="skipped" or reason=="dismissed" then Metadata().dismissed=true end
 self.Adapter:Finish(source~="hide" and source~="navigate" and source~="previewEnd",standalone)
end
