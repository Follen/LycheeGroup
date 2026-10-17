local f=dofile("tests/ui_fixture.lua")("zhCN")
local A,U,S=f.A,f.U,f.S
local originalLibStub,originalDamage,originalUnit,originalChat=LibStub,DAMAGE_TEXT_FONT,UNIT_NAME_FONT,ChatFontNormal
local sharedPath="Interface\\AddOns\\SharedFont\\Chinese.ttf"
DAMAGE_TEXT_FONT="Fonts\\Damage.ttf";UNIT_NAME_FONT=STANDARD_TEXT_FONT
ChatFontNormal=CreateFont("TestChatFont");ChatFontNormal:SetFont("Fonts\\Chat.ttf",14,"")
local media={List=function() return {"Shared Chinese","Default duplicate"} end,Fetch=function(_,_,name) return name=="Shared Chinese" and sharedPath or STANDARD_TEXT_FONT end}
LibStub=function(name,silent) T.eq(name,"LibSharedMedia-3.0");T.eq(silent,true);return media end

local unrelated=U.C.Text(UIParent,"Other addon",14)
dofile("addon/LycheeGroup/Floating.lua");A.Floating:UpdateSettings()
A:Open("find");A:Open("settings",{section="interface"})
local settings=U.pages.settings
local choices=A.Fonts:Choices()
T.eq(#choices,4,"game and shared fonts are deduplicated by path")
T.eq(settings.controls.font.widget.label:GetText(),"游戏默认")
local title=settings.heading
local _,size,flags=title:GetFont()
local line=title:GetLineHeight()+title:GetSpacing()
f.Pick(settings.controls.font.widget,sharedPath)
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
f.Pick(settings.controls.font.widget,"default")
T.eq(A.db.font,"default");T.eq(title:GetFont(),STANDARD_TEXT_FONT);T.eq(A.Floating.count:GetFont(),STANDARD_TEXT_FONT)
local check=A.Fonts.check;local setter=check.SetFont
check.SetFont=function(_,path,...) if path=="missing-font" then return false end;return setter(check,path,...) end
A:SetSetting("font","missing-font")
T.eq(A.db.font,"default","an uninstalled external font returns to the game font")
T.eq(title:GetFont(),STANDARD_TEXT_FONT)
check.SetFont=setter
LibStub=nil
T.eq(#A.Fonts:Choices(),3,"built-in font selection does not require SharedMedia")
LibStub,DAMAGE_TEXT_FONT,UNIT_NAME_FONT,ChatFontNormal=originalLibStub,originalDamage,originalUnit,originalChat
