-- Private native captions and the complete, isolated Find module. No business UI.
local probe,library,loadModule=...
local installed=LycheeUI
local product=LycheeGroup
if not library or not loadModule or not product or not product.StyleDefaults then return probe:Fail("dependencies_unavailable") end
if InCombatLockdown() then return probe:Fail("combat") end
assert(probe:Async(25))
local cases,originals={},{}
local driver
local report={sourceHash=library.auditSourceHash or "installed",revision=library.version,build=select(2,GetBuildInfo()),scope="private_native_captions",iterations=100,phases={}}
assert(probe:OnCleanup(function()
 if driver then driver:SetScript("OnUpdate",nil);driver:Hide() end
 for _,entry in ipairs(originals) do entry.label.GetUnboundedStringWidth=entry.method end
 for _,entry in ipairs(cases) do
  entry.page.frame:SetScript("OnUpdate",nil)
  entry.context:Hide();entry.parent:Hide()
 end
end))
assert(probe:Guard(function() return not InCombatLockdown() end,{"PLAYER_REGEN_DISABLED"},"combat_started"))
for _,locale in ipairs({"zhCN","enUS"}) do
 local parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(800,120);parent:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",-10000,-10000);parent:Hide()
 local context=library:CreateContext({parent=parent,reducedMotion=true,font="Interface\\AddOns\\LycheeGroup\\Media\\Fonts\\LycheeFont-"..locale..".ttf",fontScale=1,themeDefaults=product.StyleDefaults.main})
 local ui={Theme=context.Theme,C=context.C,Motion=context.Motion,L={},pages={}}
 local app={UI=ui,ActivityLabels={Display=function() end},GetLocale=function() return locale end}
 local environment=setmetatable({LycheeGroup=app},{__index=_G});environment._G=environment
 loadModule(environment)
 local page=ui.pages.find
 local entry={parent=parent,context=context,page=page,locale=locale,reads={0,0}}
 cases[#cases+1]=entry
 page.frame=CreateFrame("Frame",nil,parent);page.frame:SetAllPoints(parent)
 page.applicationPanel=CreateFrame("Frame",nil,page.frame);page.applicationPanel:SetAllPoints(page.frame)
 local C=context.C
 page.autoJoin=C.Check(page.applicationPanel,locale=="zhCN" and "自动进组" or "Auto join",function() end)
 C.SetFont(page.autoJoin.label,14);C.SetLineHeight(page.autoJoin.label,20,true);page.autoJoin:SetHeight(26)
 page.autoJoinOptions={width="content",height=26,align="center"}
 page.autoJoinLayout=C.Row(page.autoJoin,{{frame=page.autoJoin.label},{frame=page.autoJoin.track}},page.autoJoinOptions)
 page.autoApply=C.Check(page.applicationPanel,"",function() end);page.autoApply.label:Hide()
 page.autoApply:SetSize(context.Theme.findAutoApplyWidth,context.Theme.findAutoApplyHeight)
 page.applicationSettings=C.Button(page.applicationPanel,locale=="zhCN" and "申请设置" or "Preferences",context.Theme.findApplicationSettingsWidth,function() end)
 page.applicationSettings:SetHeight(context.Theme.findApplicationSettingsHeight)
 C.SetFont(page.applicationSettings.label,14);C.SetLineHeight(page.applicationSettings.label,20,true)
 page.applicationControlItems={{frame=page.applicationSettings},{frame=page.autoApply},{frame=page.autoJoin}}
 page.applicationControlOptions={anchor="TOPRIGHT",width="content",height=44,align="center",padding={0,0,0,0}}
 page.applicationControls=C.Row(page.applicationPanel,page.applicationControlItems,page.applicationControlOptions)
 -- Keep the real settle callback while limiting its consumers to this private row.
 page.LayoutQuickFilters=function(self) self:LayoutApplicationControls() end
 ui.RefreshWindowSize=function() end
 entry.labels={page.autoJoin.label,page.applicationSettings.label}
 for index,label in ipairs(entry.labels) do
  local method=label.GetUnboundedStringWidth
  originals[#originals+1]={label=label,method=method}
  label.GetUnboundedStringWidth=function(self,...)
   entry.reads[index]=entry.reads[index]+1
   return method(self,...)
  end
 end
 page:LayoutApplicationControls()
end
local caseIndex,phaseIndex,waiting,iterations=1,1,2,0
local phaseNames={"first_show","font_scale","font_path"}
local function Begin()
 local entry=cases[caseIndex];local page=entry.page
 if phaseIndex==1 then
  entry.parent:Show()
  if page.InvalidateApplicationControlMetrics then page:InvalidateApplicationControlMetrics() end
 elseif phaseIndex==2 then
  entry.context.C.InvalidateTextMetrics();entry.context:SetFont(nil,1.3)
 else
  entry.context.C.InvalidateTextMetrics();entry.context:SetFont(STANDARD_TEXT_FONT,1.3)
 end
 page:LayoutApplicationControls()
 if page.QueueApplicationControlSettle then page:QueueApplicationControlSettle() end
 waiting,iterations=2,0
end
Begin()
driver=CreateFrame("Frame")
driver:SetScript("OnUpdate",assert(probe:Callback(function()
 if probe:IsCancelled() then return end
 local entry=cases[caseIndex];local page=entry.page
 if waiting>0 then
  waiting=waiting-1
  if waiting==0 then entry.reads[1],entry.reads[2]=0,0 end
  return
 end
 for i=1,10 do page:LayoutApplicationControls() end
 iterations=iterations+10
 if iterations<100 then return end
 local output={locale=entry.locale,phase=phaseNames[phaseIndex],reads={entry.reads[1],entry.reads[2]},widths={},nativeWidths={},fontSizes={},settleStopped=page.frame:GetScript("OnUpdate")==nil}
 for index,label in ipairs(entry.labels) do
  local native=originals[(caseIndex-1)*2+index].method(label)
  output.widths[index]=label:GetWidth();output.nativeWidths[index]=native;output.fontSizes[index]=select(2,label:GetFont())
  if math.abs(label:GetWidth()-(math.ceil(native)+2))>.02 then return probe:Fail("caption_width_mismatch") end
 end
 if not output.settleStopped then return probe:Fail("settle_still_running") end
 report.phases[#report.phases+1]=output
 phaseIndex=phaseIndex+1
 if phaseIndex>3 then cases[caseIndex].parent:Hide();caseIndex=caseIndex+1;phaseIndex=1 end
 if caseIndex<=#cases then Begin();return end
 driver:SetScript("OnUpdate",nil);driver:Hide()
 local jobs=0
 for _,item in ipairs(cases) do item.context:Hide();item.parent:Hide();jobs=jobs+item.context.Motion:Count() end
 for _,item in ipairs(originals) do item.label.GetUnboundedStringWidth=item.method end
 report.cleanup={jobs=jobs,driverStopped=driver:GetScript("OnUpdate")==nil,installedLibraryUnchanged=LycheeUI==installed,installedProductUnchanged=LycheeGroup==product}
 if jobs~=0 then return probe:Fail("jobs_retained") end
 probe:Finish(report)
end)))
