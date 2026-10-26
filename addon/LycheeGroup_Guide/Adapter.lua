-- The guide leases existing methods while active; all ownership stays here.
-- Loading this file neither reads the UI nor installs callbacks.
local A=_G.LycheeGroup
local Guide=A.Guide
local Adapter={leases={}};Guide.Adapter=Adapter
local roles={"TANK","HEALER","DAMAGER"}
local function Pack(...) return {n=select("#",...),...} end
local function CopyRoles(source)
 local copy={};for _,role in ipairs(roles) do if source and source[role]==true then copy[role]=true end end;return copy
end
local function LeaseResult(ok,...)
 if not ok then
  local err=...
  pcall(Guide.Stop,Guide,"interrupted")
  error(err,0)
 end
 return ...
end

function Adapter:Lease(owner,key,handler)
 local record={owner=owner,key=key,original=assert(owner[key]),handler=handler}
 record.wrapper=function(...)
  if not record.handler then return record.original(...) end
  return LeaseResult(pcall(record.handler,record.original,...))
 end
 self.leases[#self.leases+1]=record;owner[key]=record.wrapper
end

function Adapter:Detach()
 local tooltip=self.tooltip
 if tooltip then
  self.quietTooltip:Hide()
  if tooltip.text==self.quietTooltip then tooltip.text=self.previousTextTooltip end
  self.tooltip,self.previousTextTooltip=nil,nil
 end
 for index=#self.leases,1,-1 do
  local record=self.leases[index]
  if record.owner[record.key]==record.wrapper then record.owner[record.key]=record.original end
  -- A later wrapper may still call our proxy. It falls through to the original
  -- without retaining a session, owner or guide-specific handler.
  record.handler,record.owner,record.key,record.wrapper=nil,nil,nil,nil
  self.leases[index]=nil
 end
end

function Adapter:IsPreview(preview) return self.session~=nil and self.session==preview end
local function Provider()
 local preview=A.UI.preview
 return Adapter:IsPreview(preview) and preview.provider or nil
end
local function TeachingOwner(owner)
 if not Guide.ready or not Guide.steps then return false end
 local target=Guide:Target()
 return target and owner and owner.tooltipArea==target
end
function Adapter:QuietResultHover()
 local list=A.UI.pages.find.results
 if not list then return end
 self.resultList,self.resultHoverFill=list,list.hoverFill
 list.hoverFill=false
 for _,row in ipairs(list.rows) do
  local leave=row:GetScript("OnLeave");if leave then leave(row) end
 end
end
function Adapter:RestoreResultHover()
 local list=self.resultList
 if list and list.hoverFill==false then list.hoverFill=self.resultHoverFill end
 self.resultList,self.resultHoverFill=nil,nil
end
local function Prefs(provider)
 local prefs=provider.applicationPrefs
 if prefs.enabled==nil then prefs.enabled=provider.prefs.autoApply==true end
 return prefs
end
local function ValidRoles(provider,selected)
 if not selected or not next(selected) then return false end
 for _,role in ipairs(roles) do if selected[role] and not provider.player.roles[role] then return false end end
 return true
end
local function RefreshEntry(application)
 local modal=application.applicationModal
 if modal then
  local lease=application.previewApplication
  modal.autoApply:SetValue(application:IsAutoApplyEnabled() or lease and lease.enableOnSave==true)
 end
 if application.onPreferencesChanged then application.onPreferencesChanged() end
end
local function SaveEnabled(provider,enabled)
 Prefs(provider).enabled=enabled==true;provider.prefs.autoApply=enabled==true
end

function Adapter:CaptureGeometry()
 if self.geometry then return end
 local UI=A.UI
 self.geometry={width=UI.windowWidth,height=UI.windowHeight,preferredWidth=UI.preferredWindowWidth,preferredHeight=UI.preferredWindowHeight,point=Pack(UI.frame:GetPoint())}
end
function Adapter:RestoreGeometry()
 local geometry=self.geometry;if not geometry then return end
 self.geometry=nil
 local UI=A.UI
 UI.preferredWindowWidth,UI.preferredWindowHeight=geometry.preferredWidth,geometry.preferredHeight
 UI:SetWindowSize(geometry.width,geometry.height,true)
 UI.frame:ClearAllPoints();UI.frame:SetPoint(unpack(geometry.point,1,geometry.point.n))
 UI.Motion:CapturePosition()
end

function Adapter:Attach()
 if #self.leases>0 then return end
 local UI=A.UI
 local tooltip=UI.Tooltip
 tooltip:Hide()
 self.tooltip,self.previousTextTooltip=tooltip,tooltip.text
 -- BindText's existing native hooks resolve Tip.text at hover time. A single
 -- private, hidden tooltip lets those hooks finish without covering the tour.
 -- Restore the exact previous reference; never add permanent hooks to controls.
 if not self.quietTooltip then self.quietTooltip=UI.C.Tooltip(UI.frame,300) end
 tooltip.text=self.quietTooltip
 self:Lease(self.quietTooltip,"Show",function(original,owner,...)
  if not Guide.active then return original(owner,...) end
 end)
 for _,method in ipairs({"ShowGroup","ShowApplicants","ShowRoster","ShowPlayer","ShowNote"}) do
  local name=method
  self:Lease(tooltip,name,function(original,owner,anchor,...)
   local id=Guide.steps and Guide.steps[Guide.index]
   if not Guide.active or TeachingOwner(anchor) and (name=="ShowGroup" and (id=="details" or id=="raidDetails") or name=="ShowPlayer" and id=="applicantDetails") then
    return original(owner,anchor,...)
   end
  end)
 end
 self:Lease(tooltip,"HoverOwner",function(original,owner,anchor,...)
  if not Guide.active or TeachingOwner(anchor) then return original(owner,anchor,...) end
 end)
 self:Lease(A,"GetSetting",function(original,owner,key,...)
  if Guide.active and Guide.steps and Guide.steps[Guide.index]=="raidDetails" and key=="raidMembers" then return "shift" end
  return original(owner,key,...)
 end)
 self:Lease(_G.LycheeGroupEscapeHandler,"IsShown",function(original,...)
  if Guide.active and Guide.standalone and Guide.View.root and Guide.View.root:IsShown() then return true end
  return original(...)
 end)
 local function Navigate(original,owner,...)
  if Guide.active and not Guide.transition then Guide:Stop("interrupted","navigate") end
  return original(owner,...)
 end
 self:Lease(UI,"Show",Navigate)
 self:Lease(UI,"Navigate",function(original,owner,...)
  if Guide.active and not Guide.transition then
   local shown=owner:IsShown()
   Guide:Stop("interrupted","navigate")
   if shown and not owner:IsShown() then return owner:Show(...) end
  end
  return original(owner,...)
 end)
 self:Lease(UI,"Hide",function(original,owner,...)
  if Guide.active and not Guide.transition then
   local owned=Adapter:IsPreview(owner.preview)
   Guide:Stop("interrupted","hide")
   if owned then return end
  end
  return original(owner,...)
 end)
 self:Lease(UI,"HandleEscape",function(original,owner,...)
  if Guide.active and not Guide.transition then Guide:Stop("later");return true end
  return original(owner,...)
 end)
 self:Lease(UI,"ApplyFont",function(original,owner,...)
  local result=Pack(original(owner,...))
  if Guide.active then
   if Guide.steps then Guide:UpdateStep() else Guide.View:Layout() end
  end
  return unpack(result,1,result.n)
 end)
 local function AfterFit(...)
  Guide:RefreshViewport();return ...
 end
 self:Lease(UI,"FitToScreen",function(original,owner,...)
  -- Pure scale/bounds changes need not emit OnSizeChanged. Forward all return
  -- values through the post-fit check without another packed result table.
  return AfterFit(original(owner,...))
 end)
 self:Lease(UI,"StartPreview",Navigate)
 self:Lease(UI,"EndPreview",function(original,owner,...)
  if Guide.active and not Guide.transition and Adapter:IsPreview(owner.preview) then
   Guide:Stop("interrupted","previewEnd");return
  end
  local owned=Adapter:IsPreview(owner.preview)
  local result=Pack(original(owner,...))
  if owned then Adapter:RestoreGeometry() end
  return unpack(result,1,result.n)
 end)
 self:Lease(UI,"UpdatePreviewIndicator",function(original,owner,...)
  if Adapter:IsPreview(owner.preview) then
   if owner.previewExit then owner.previewExit:Hide() end
   return
  end
  return original(owner,...)
 end)
 self:Lease(A.Appearance,"SaveWindowSize",function(original,owner,...)
  if not Adapter.starting and not Provider() then return original(owner,...) end
 end)
 self:Lease(UI.Native,"GetCreationItemLevelLimit",function(original,owner,activityID,...)
  local provider=Provider();if not provider then return original(owner,activityID,...) end
  local activity=provider.Catalog:GetActivity(activityID)
  if activity then return math.floor(provider.player.itemLevel),activity.isPvpActivity==true end
 end)
 self:Lease(UI.Application,"RefreshApplicationRoles",function(original,owner,...)
  local provider=Provider();if not provider then return original(owner,...) end
  local lease=owner.previewApplication;if not lease then return end
  for _,role in ipairs(roles) do lease.available[role]=provider.player.roles[role]==true end
  if not lease.initialized then
   lease.initialized=true
   if not Prefs(provider).roles and lease.available[provider.player.role] then lease.roles[provider.player.role]=true end
  end
  local selected=false;local modal=owner.applicationModal
  for _,role in ipairs(roles) do
   if not lease.available[role] then lease.roles[role]=nil end
   if lease.roles[role] then selected=true end
   modal.roles[role]:SetAvailable(lease.available[role]);modal.roles[role]:SetActive(lease.roles[role]==true)
  end
  modal.submit:SetAvailable(selected)
  UI:SetText(modal.error,selected and "" or UI.L.applicationRoleUnavailable)
  owner:LayoutApplication();UI:ApplyElementScope("application")
 end)
 self:Lease(UI.Application,"SetAutoApply",function(original,owner,enabled,...)
  local provider=Provider();if not provider then return original(owner,enabled,...) end
  local lease=owner.previewApplication
  if enabled then
   if ValidRoles(provider,Prefs(provider).roles) then
    SaveEnabled(provider,true);if lease then lease.enableOnSave=nil end
   elseif lease then lease.enableOnSave=true
   else
    local ok,err=owner:OpenApplicationSettings(nil,true);RefreshEntry(owner);return ok,err
   end
  else
   if lease then lease.enableOnSave=nil end
   SaveEnabled(provider,false)
  end
  RefreshEntry(owner);return true
 end)
 self:Lease(UI.Application,"Apply",function(original,owner,resultID,manual,confirmedRoles,...)
  local provider=Provider();if not provider then return original(owner,resultID,manual,confirmedRoles,...) end
  if provider:GetListing() then return false,provider.L.recruiting end
  if provider.Applications:IsActive(resultID) then return false,provider.L.alreadyApplied end
  if provider.Applications:GetActiveCount()>=5 then owner:ReleaseApplication();UI:ShowApplicationLimit();return false,provider.L.applicationLimit end
  local prefs=Prefs(provider);local selected=confirmedRoles or prefs.roles
  if not confirmedRoles and (manual or not prefs.enabled or not selected) or not ValidRoles(provider,selected) then
   return owner:OpenApplicationSettings(resultID)
  end
  local lease=owner.previewApplication
  local ok,err=provider:Apply(resultID,{tank=selected.TANK==true,healer=selected.HEALER==true,damage=selected.DAMAGER==true},prefs.note or "")
  if ok then
   if confirmedRoles and not prefs.enabled then
    prefs.roles=CopyRoles(confirmedRoles)
    provider.prefs.applicationRoles={TANK=confirmedRoles.TANK==true,HEALER=confirmedRoles.HEALER==true,DAMAGER=confirmedRoles.DAMAGER==true}
    if lease and lease.enableOnSave then SaveEnabled(provider,true) end
    RefreshEntry(owner)
   end
   owner:ReleaseApplication()
  end
  return ok,err
 end)
end

function Adapter:Start(scenario,options)
 local provider,err=Guide:CreateProvider(scenario,options);if not provider then return false,err end
 local UI=A.UI
 local returnPage="find"
 self:CaptureGeometry()
 self.starting=true
 local hidden,hideError=pcall(UI.Hide,UI,true)
 self.starting=nil
 if not hidden then self:RestoreGeometry();error(hideError,0) end
 self.session={provider=provider,scenario=scenario,returnPage=returnPage}
 UI.preview=self.session
 UI.pages.find:BeginPreview(provider);UI.pages.create:BeginPreview(provider)
 UI:Show(scenario=="applications" and "find" or "create");UI:UpdatePreviewIndicator()
 self:QuietResultHover()
 return true
end

function Adapter:Finish(reopen,standalone)
 local UI=A.UI;local session=self.session
 local failure
 local function Attempt(callback)
  local ok,err=pcall(callback);if not ok and not failure then failure=err end
 end
 Attempt(function() self:RestoreResultHover() end)
 if session then
  Attempt(function() UI:Hide(true) end)
  -- The frame may already be hidden after a failed page entry.
  if UI.preview==session then Attempt(function() UI:EndPreview() end) end
  if failure then
   -- EndPreview stops motion before clearing the session. A failed stop must
   -- not leave mock data attached after the method leases have been removed.
   if UI.preview==session then
    Attempt(function() UI:CloseModal("guide-error") end)
    Attempt(function() UI.Native:ReleaseSearch() end)
    Attempt(function() UI.Native:ReleaseCreation() end)
    Attempt(function() UI.Application:ReleaseApplication() end)
   end
   for _,page in ipairs({UI.pages.find,UI.pages.create}) do
    if page.unsub then Attempt(page.unsub);page.unsub=nil end
    if page.notesUnsub then Attempt(page.notesUnsub);page.notesUnsub=nil end
    session.provider:Detach(page)
    Attempt(function() page:EndPreview() end)
   end
   if UI.preview==session then UI.preview=nil end
   Attempt(function() UI:UpdatePreviewIndicator() end)
   UI.finishHide,UI.hiding=nil,nil;UI.exitToken=(UI.exitToken or 0)+1
   Attempt(function() UI.frame:Hide() end)
  end
 end
 Attempt(function() self:RestoreGeometry() end)
 self.session,self.geometry,self.starting=nil,nil,nil
 self:Detach()
 if not failure and (session or standalone) and reopen then Attempt(function() A:Open("find") end) end
 if failure then error(failure,0) end
end
