local f=dofile("tests/ui_fixture.lua")("zhCN",nil,{reduceMotion=true})
local A,U=f.A,f.U
local writes={};local set=C_CVar.SetCVar
C_CVar.SetCVar=function(key,value) writes[#writes+1]={key,value};set(key,value) end
A:Open("settings",{section="notifications"})
local p=U.pages.settings
local volume=p.controls.channelVolume.widget
T.eq(p.heading:GetText(),"提示与声音")
T.eq(p.controls.applicantAlertSound.frame:GetParent(),p.panels.notifications)
T.eq(p.controls.reminders.frame:GetParent(),p.panels.notifications)
T.eq(volume.valueLabel:GetText(),"80%")
T.eq(#writes,0,"opening the page never overwrites game volumes")
T.ok(p.frame.events.CVAR_UPDATE)
for _,entry in ipairs({{"Master","Sound_MasterVolume",70},{"SFX","Sound_SFXVolume",50},{"Music","Sound_MusicVolume",30},{"Ambience","Sound_AmbienceVolume",40},{"Dialog","Sound_DialogVolume",80}}) do
 f.Pick(p.controls.soundChannel.widget,entry[1])
 T.eq(A:GetSetting("soundChannel"),entry[1])
 T.eq(volume.valueLabel:GetText(),entry[3].."%","switching reads each channel's existing volume")
 T.eq(#writes,0,"selecting a channel does not change any volume")
end
for _,value in ipairs({0,35,100}) do
 volume.slider:SetValue(value)
 T.eq(writes[#writes][1],"Sound_DialogVolume")
 T.eq(writes[#writes][2],value/100)
 T.eq(volume.valueLabel:GetText(),value.."%")
 T.eq(f.S.cvars.Sound_MasterVolume,"0.7","the selected channel is the only volume changed")
end
local count=#writes
f.S.cvars.Sound_DialogVolume="0.42"
p.frame:Fire("OnEvent","CVAR_UPDATE","sound_dialogvolume")
T.eq(volume.valueLabel:GetText(),"42%","native audio settings remain the source of truth")
T.eq(#writes,count,"CVar notifications do not write back")
A:SetSetting("soundChannel","Music")
T.eq(volume.valueLabel:GetText(),"30%","external preference changes refresh the selected channel")
T.eq(A.Configuration.definitions["settings.channelVolume"],nil,"channel volume is not duplicated in addon storage")
T.eq(A.db.uiConfig.user["settings.channelVolume"],nil)
p:SelectSection("general");T.eq(p.frame.events.CVAR_UPDATE,nil)
p:SelectSection("notifications");T.ok(p.frame.events.CVAR_UPDATE)
U:Hide(true);T.eq(p.frame.events.CVAR_UPDATE,nil,"closing stops the volume event subscription")

-- Pack defaults, user overrides and reload use the normal account preference.
local config=A.Configuration
T.ok(config:Reset("settings.soundChannel",{storage="account"}))
T.eq(A:GetSetting("soundChannel"),"Dialog")
T.ok(config:RegisterPreset("audio",1,{["settings.soundChannel"]="SFX"},{storage="account",default=true}))
T.eq(A:GetSetting("soundChannel"),"SFX")
T.ok(A:SetSetting("soundChannel","Master"))
T.ok(config:RegisterPreset("audio",2,{["settings.soundChannel"]="Music"},{storage="account",default=true}))
T.eq(A:GetSetting("soundChannel"),"Master")
A.db=nil;A.charPrefs=nil;A:LoadDB()
T.eq(A:GetSetting("soundChannel"),"Master","channel choice survives reload")
T.eq(A:SetSetting("soundChannel","Unknown"),false)
T.ok(config:Reset("settings.soundChannel",{storage="account"}))
T.eq(A:GetSetting("soundChannel"),"Music","reset restores the upgraded pack default")
T.eq(#writes,count,"loading configuration never changes game volume")
