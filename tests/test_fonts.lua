local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,S=f.A,f.U,f.S
local originalLibStub,originalDamage,originalUnit,originalChat=LibStub,DAMAGE_TEXT_FONT,UNIT_NAME_FONT,ChatFontNormal
local sharedPath="Interface\\AddOns\\SharedFont\\Chinese.ttf"
DAMAGE_TEXT_FONT="Fonts\\Damage.ttf";UNIT_NAME_FONT=STANDARD_TEXT_FONT
ChatFontNormal=CreateFont("TestChatFont");ChatFontNormal:SetFont("Fonts\\Chat.ttf",14,"")
local media={List=function() return {"Shared Chinese","Default duplicate"} end,Fetch=function(_,_,name) return name=="Shared Chinese" and sharedPath or STANDARD_TEXT_FONT end}
LibStub=function(name,silent) T.eq(name,"LibSharedMedia-3.0");T.eq(silent,true);return media end

local unrelated=U.C.Text(UIParent,"Other addon",14)
unrelated:SetFont(STANDARD_TEXT_FONT,14,"")
dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua");A.Floating:UpdateSettings()
A:Open("find");A:Open("settings",{section="interface"})
local settings=U.pages.settings
local choices=A.Fonts:Choices()
T.eq(#choices,5,"bundled, game and shared fonts are deduplicated by path")
T.eq(settings.controls.font.widget.label:GetText(),"荔枝字体")
T.eq(U.Theme.font,A.Fonts:GetDefaultPath());T.eq(A.Floating.count:GetFont(),A.Fonts:GetDefaultPath(),"both contexts use the complete font for the selected UI language")
local title=settings.heading
local _,size,flags=title:GetFont()
local line=title:GetLineHeight()+title:GetSpacing()
-- Native widget trees may contain a FontString whose font has not been assigned.
local unset=U.frame:CreateFontString(nil,"OVERLAY")
unset.GetFont=function() return nil,-1,"" end
local unsetWrites=0
unset.SetFont=function() unsetWrites=unsetWrites+1;error("invalid font height") end
f.Pick(settings.controls.font.widget,sharedPath)
T.eq(unsetWrites,0,"font switching skips uninitialized native font regions")
T.eq(A.db.font,sharedPath,"the dropdown persists the selection")
T.eq(U.Theme.font,sharedPath);T.eq(A.Floating.context.Theme.font,sharedPath)
T.eq(title:GetFont(),sharedPath);T.eq(select(2,title:GetFont()),size);T.eq(select(3,title:GetFont()),flags)
T.near(title:GetLineHeight()+title:GetSpacing(),line,.0001,"changing typeface preserves the line box")
T.eq(A.Floating.count:GetFont(),sharedPath,"the existing floating window changes immediately")
T.eq(unrelated:GetFont(),STANDARD_TEXT_FONT,"foreign UI is not traversed")
T.eq(settings.controls.font.widget.label:GetText(),"Shared Chinese")
T.eq(U.C.Text(U.frame,"New widget",14):GetFont(),sharedPath,"newly built components inherit the selected font")
T.eq(LFGListFrame.SearchPanel.SearchBox:GetFont(),STANDARD_TEXT_FONT,"released native search input keeps its original font")
A:Open("find");T.eq(U.pages.find.search.box:GetFont(),sharedPath,"native input adopts the new font when borrowed again")
A:Open("settings",{section="interface"});T.eq(LFGListFrame.SearchPanel.SearchBox:GetFont(),STANDARD_TEXT_FONT,"native input restores its original font on release")
local saved=A.db
A.db=nil;A:LoadDB();T.eq(A.db,saved);T.eq(A.Fonts:GetPath(),sharedPath,"saved font survives database loading")
f.Pick(settings.controls.font.widget,"game")
T.eq(A.db.font,"game");T.eq(title:GetFont(),STANDARD_TEXT_FONT);T.eq(A.Floating.count:GetFont(),STANDARD_TEXT_FONT)
f.Pick(settings.controls.font.widget,"default")
T.eq(title:GetFont(),A.Fonts:GetDefaultPath());T.eq(settings.controls.font.widget.label:GetText(),"荔枝字体")
local check=A.Fonts.check;local setter=check.SetFont
check.SetFont=function(_,path,...) if path=="missing-font" then return false end;return setter(check,path,...) end
A:SetSetting("font","missing-font")
T.eq(A.db.font,"default","an uninstalled external font returns to LycheeFont")
T.eq(title:GetFont(),A.Fonts:GetDefaultPath())
check.SetFont=setter
LibStub=nil
T.eq(#A.Fonts:Choices(),4,"built-in font selection does not require SharedMedia")
LibStub,DAMAGE_TEXT_FONT,UNIT_NAME_FONT,ChatFontNormal=originalLibStub,originalDamage,originalUnit,originalChat

-- The selected UI language is fixed for the login, including later LoD modules.
for _,case in ipairs({{"zhCN","enUS","Settings","LycheeFont"},{"enUS","zhCN","设置","荔枝字体"}}) do
 local savedSettings={language=case[2]}
 local languageFixture=dofile("tests/ui_fixture.lua")(case[1],nil,savedSettings)
 local a,u=languageFixture.A,languageFixture.U
 a.db.reduceMotion=true;a:Open("settings",{section="interface"})
 local page=u.pages.settings
 T.eq(GetLocale(),case[1],"addon language never changes the game's locale")
 T.eq(a:GetLocale(),case[2]);T.eq(u.L.settings,case[3])
 T.eq(a.Fonts:GetPath(),"Interface\\AddOns\\LycheeGroup\\Media\\Fonts\\LycheeFont-"..case[2]..".ttf","the default file follows the addon language, including letters and digits")
 T.eq(page.heading:GetFont(),a.Fonts:GetPath())
 T.eq(page.controls.font.widget.label:GetText(),case[4]);T.eq(page.reloadLanguage:IsShown(),false)
 languageFixture.Pick(page.controls.language.widget,"auto")
 T.eq(savedSettings.language,"auto");T.eq(a:GetLocale(),case[2],"a pending language change cannot mix languages in this session")
 T.eq(page.reloadLanguage:IsShown(),true)
 local nativeUI=C_UI;local reloads=0
 _G.C_UI={Reload=function() reloads=reloads+1 end}
 page.reloadLanguage:Fire("OnClick");T.eq(reloads,1,"the visible apply button invokes native UI reload")
 _G.C_UI=nativeUI
 u:Hide(true)
 local reloaded=dofile("tests/ui_fixture.lua")(case[1],nil,savedSettings)
 reloaded.A:Open("settings",{section="interface"})
 T.eq(reloaded.A:GetLocale(),case[1],"the next session applies the saved game-language choice")
 T.eq(reloaded.A.Fonts:GetPath(),"Interface\\AddOns\\LycheeGroup\\Media\\Fonts\\LycheeFont-"..case[1]..".ttf","the default font changes with the language after reload")
 T.eq(reloaded.U.pages.settings.reloadLanguage:IsShown(),false)
 reloaded.U:Hide(true)
end
