-- Loaded after the ordinary UI. All entry state belongs to GuideEntry.
local A=_G.LycheeGroup
local Entry=assert(A.GuideEntry)
local UI=assert(A.UI)
local function S(cn,en) return A:GetLocale()=="zhCN" and cn or en end
local function Pack(...) return {n=select("#",...),...} end
local function Restore(record)
 if not record or not record.active then return end
 record.active=false
 local owner,key=record.owner,record.key
 record.owner,record.key=nil,nil
 if owner[key]==record.wrapper then owner[key]=record.original end
 record.wrapper=nil
end
local function Start(control)
 if not control:IsEnabled() or UI.hiding or control.pressCancelled
  or control.pressedKey and control.pressedKey~=(control.targetKey or true) then
  control.pressedKey,control.pressCancelled=nil,nil;return
 end
 control.pressedKey=nil
 local ok,err=Entry:Open();if not ok then A:Print(err) end
end

function Entry:TryWelcome()
 if self:HasSeen() then self:ReleaseShow();return false end
 if self.autoAttempted or self.opening or UI.opening or UI.preview or UI.activeModal or UI.hiding
  or A.Guide and A.Guide.active or not UI:IsShown() or InCombatLockdown() then return false end
 self.autoAttempted=true
 self:ReleaseShow()
 local ran,opened,err=pcall(self.Open,self)
 if not ran then err=opened;opened=false end
 if not opened then A:Print(err) end
 return opened,err
end
function Entry:AddSettingsRow()
 if self.settingsRow then return true end
 local page=UI.pages.settings
 local panel=page.panels and page.panels.general
 if not panel then return false end
 local index=#(panel.rows or {})+1
 page:BuildRow(panel,{"guide",S("使用引导","Usage guide"),"","action"},index)
 local row=panel.rows[index]
 self.settingsRow,self.settingsButton=row,row.control
 UI:SetText(row.control.label,S("开始引导","Start guide"))
 -- This is our newly created action button; its reset-position action is never run.
 row.control:SetScript("OnClick",Start)
 page:LayoutRows()
 return true
end

function Entry:ReleaseShow()
 Restore(self.showInstall);self.showInstall=nil
end

function Entry:Install()
 if self.installed then return end
 self.installed=true
 local page=UI.pages.settings
 if not self:AddSettingsRow() then
  local record={owner=page,key="Build",original=page.Build,active=true}
  record.wrapper=function(owner,...)
   if not record.active then return record.original(owner,...) end
   local result=Pack(record.original(owner,...))
   Entry:AddSettingsRow();Restore(record);Entry.settingsInstall=nil
   return unpack(result,1,result.n)
  end
  self.settingsInstall=record;page.Build=record.wrapper
 end
 if self:HasSeen() then return end
 local record={owner=UI,key="Show",original=UI.Show,active=true}
 record.wrapper=function(owner,...)
  if not record.active then return record.original(owner,...) end
  local result=Pack(record.original(owner,...))
  Entry:TryWelcome()
  return unpack(result,1,result.n)
 end
 self.showInstall=record;UI.Show=record.wrapper
 if UI.frame and UI:IsShown() then self:TryWelcome() end
end

Entry:Install()
