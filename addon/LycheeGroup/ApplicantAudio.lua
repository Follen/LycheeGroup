-- Applicant audio stays in the core so settings previews do not load Group.
local A=_G.LycheeGroup
local Audio={default="lychee-new-applicant.ogg"}
A.ApplicantAudio=Audio
local nativeFile=1067667
local options={
 {value="lychee-new-applicant.ogg",zh="新申请·自然女声",en="New applicant · Natural Chinese female"},
 {value="lychee-reminder.ogg",zh="荔枝提醒·温柔女声",en="Lychee reminder · Warm Chinese female"},
 {value="lychee-teammate.ogg",zh="队友申请·沉稳男声",en="Teammate · Chinese male"},
 {value="lychee-captain.ogg",zh="新队友·活泼女声",en="New teammate · Lively Chinese female"},
 {value="lychee-soft-chime.ogg",zh="轻柔双音",en="Soft chime"},
 {value="lychee-bright-chime.ogg",zh="明亮三音",en="Bright chime"},
 {value="native",zh="原生提示音",en="Native sound"},
 {value="",zh="关闭",en="Off"},
}
function Audio:Normalize(value)
 for _,option in ipairs(options) do if option.value==value then return value end end
 return self.default
end
-- Repair saved choices before Configuration captures legacy data or resolves a
-- preset. Retired files must not leave an unplayable value in an existing save.
function Audio:MigrateSettings(root)
 if root.applicantAlertSound~=nil then root.applicantAlertSound=self:Normalize(root.applicantAlertSound) end
 local config=root.uiConfig
 if type(config)~="table" then return end
 local key="settings.applicantAlertSound"
 local function Migrate(values)
  if type(values)=="table" and values[key]~=nil then values[key]=self:Normalize(values[key]) end
 end
 Migrate(config.user)
 if type(config.presets)=="table" then
  for _,preset in pairs(config.presets) do if type(preset)=="table" then Migrate(preset.values) end end
 end
end
function Audio:Values()
 local values={};for i,option in ipairs(options) do values[i]=option.value end;return values
end
function Audio:Choices()
 local choices={};local zh=A:GetLocale()=="zhCN"
 for i,option in ipairs(options) do choices[i]={value=option.value,label=zh and option.zh or option.en} end
 return choices
end
function Audio:Stop(previewOnly)
 if previewOnly and not self.preview then return end
 local handle=self.handle
 self.handle,self.preview=nil,nil
 if handle and StopSound then pcall(StopSound,handle) end
end
function Audio:ApplySetting()
 local mode=self:Normalize(A:GetSetting("applicantAlertSound"))
 if self.mode~=mode then self:Stop();self.mode=mode end
 -- The native eye also serves other queues. Mute only its applicant file.
 local native=mode=="native"
 if self.nativeEnabled~=native then
  local apply
  if native then apply=UnmuteSoundFile else apply=MuteSoundFile end
  if apply and pcall(apply,nativeFile) then self.nativeEnabled=native end
 end
 return mode
end
function Audio:Play(preview)
 local mode=self:ApplySetting()
 if mode=="" or mode=="native" and not preview then
  if preview then self:Stop() end
  return false
 end
 local path
 for _,option in ipairs(options) do
  if option.value==mode then
   path=mode=="native" and nativeFile or "Interface\\AddOns\\LycheeGroup\\Media\\Sounds\\"..mode
   break
  end
 end
 if not path or not PlaySoundFile then return false end
 self:Stop()
 local ok,played,handle=pcall(PlaySoundFile,path,"Master")
 if not ok or not played then return false end
 self.handle,self.preview=handle,preview==true
 return true
end
