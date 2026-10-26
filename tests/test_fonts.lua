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
T.eq(U.context.fontPath,A.Fonts:GetDefaultPath());T.eq(A.Floating.count:GetFont(),A.Fonts:GetDefaultPath(),"both contexts use the complete font for the selected UI language")
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
T.eq(U.context.fontPath,sharedPath);T.eq(A.Floating.context.fontPath,sharedPath)
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
T.eq(A.db.font,"missing-font","an unavailable selection retains its explicit saved ownership")
T.eq(title:GetFont(),A.Fonts:GetDefaultPath())
local fontNodes=#S.nodes
for _=1,20 do T.eq(A.Fonts:GetPath(),A.Fonts:GetDefaultPath()) end
T.eq(#S.nodes,fontNodes,"cached fallback reads do not create another font object")
check.SetFont=setter
LibStub=nil
T.eq(#A.Fonts:Choices(),4,"built-in font selection does not require SharedMedia")
LibStub,DAMAGE_TEXT_FONT,UNIT_NAME_FONT,ChatFontNormal=originalLibStub,originalDamage,originalUnit,originalChat

-- Font percentages apply to retained base styles, independently of window scale.
do
 local savedSettings={fontScale=100,uiScale=110,reduceMotion=true}
 local scaled=dofile("tests/ui_fixture.lua")("zhCN",nil,savedSettings)
 local a,u=scaled.A,scaled.U
 dofile("addon/LycheeGroup/Floating.lua");dofile("addon/LycheeGroup/API.lua");a.Floating:UpdateSettings()
 a:Open("settings",{section="interface"})
 local page=u.pages.settings
 local slider=page.controls.fontScale.widget
 local fontIndex,scaleIndex
 for index,row in ipairs(page.panels.interface.rows) do
  if row.frame==page.controls.font.frame then fontIndex=index end
  if row.frame==page.controls.fontScale.frame then scaleIndex=index end
 end
 T.ok(fontIndex and scaleIndex,"font and font size remain in Appearance settings")
 T.eq(scaleIndex,fontIndex+1,"font size follows the interface font")
 T.eq(slider.slider:GetMinMaxValues(),70);T.eq(select(2,slider.slider:GetMinMaxValues()),130)
 T.eq(slider.valueLabel:GetText(),"100%")
 T.near(slider.progress:GetWidth(),slider:GetWidth()/2,.001,"the font slider fills the left half at 100 percent")
 local titleBase=select(2,page.heading:GetFont())
 local floatBase=select(2,a.Floating.count:GetFont())
 local windowScale=u.frame:GetScale()
 local foreign=u.C.Text(UIParent,"Foreign font",14);foreign:SetFont(STANDARD_TEXT_FONT,14,"")
 u.Tooltip:BuildInteractive()
 local detail=u.Tooltip.interactive.title;local detailBase=select(2,detail:GetFont())
 slider.slider:SetValue(130)
 T.eq(a.db.fontScale,130);T.eq(slider.valueLabel:GetText(),"130%")
 T.near(slider.progress:GetWidth(),slider:GetWidth(),.001,"the font slider fills its track at the maximum")
 T.near(select(2,page.heading:GetFont()),titleBase*1.3,.0001)
 T.near(select(2,a.Floating.count:GetFont()),floatBase*1.3,.0001)
 T.near(select(2,detail:GetFont()),detailBase*1.3,.0001,"retained details inherit font scaling")
 T.eq(u.frame:GetScale(),windowScale,"font size does not change the main window scale")
 T.eq(select(2,foreign:GetFont()),14,"foreign text outside the product's roots is untouched")
 local fresh=u.C.Text(u.frame,"New text",14,nil,nil,20)
 T.near(select(2,fresh:GetFont()),17*1.3,.0001,"later text scales after the existing context font delta")
 T.near(fresh:GetLineHeight()+fresh:GetSpacing(),24*1.3,.0001)
 u.context:OpenMenu(page.controls.font.widget,{{value=1,label="字体菜单"}},function() end)
 local menu=u.context:GetMenu()
 T.near(select(2,menu.list.rows[1].title:GetFont()),19*1.3,.0001,"future or reused menu rows use the percentage")
 a:SetSetting("fontScale",70)
 T.eq(slider.progress:GetAlpha(),0,"the font slider clears its fill at the minimum")
 T.near(select(2,page.heading:GetFont()),titleBase*.7,.0001,"changing 130% to 70% starts from the original base")
 T.near(select(2,menu.list.rows[1].title:GetFont()),19*.7,.0001)
 u.C.SetFont(fresh,16);u.C.SetLineHeight(fresh,22)
 T.near(select(2,fresh:GetFont()),19*.7,.0001,"restyling reused labels scales their new base once")
 a:SetSetting("font","game")
 T.near(select(2,fresh:GetFont()),19*.7,.0001,"changing typeface retains the chosen percentage")
 a:SetSetting("fontScale",100);a:SetSetting("fontScale",130);a:SetSetting("fontScale",100)
 T.eq(select(2,page.heading:GetFont()),titleBase,"round trips return exactly to the base font")
 local native=LFGListFrame.SearchPanel.SearchBox
 local original={native:GetFont()}
 a:Open("find");a:SetSetting("fontScale",130)
 T.near(select(2,native:GetFont()),17*1.3,.0001,"an active native lease updates immediately")
 a:Open("settings",{section="interface"})
 T.same({native:GetFont()},original,"release restores the complete native font after scaling")
 a:Open("find")
 local host=CreateFrame("Frame",nil,UIParent);native:SetParent(host);native:SetFont("foreign-font",19,"")
 a:SetSetting("fontScale",70)
 T.eq(native:GetFont(),"foreign-font","font updates skip leases transferred to another host")
 a:Open("settings",{section="interface"})
 T.eq(native:GetFont(),"foreign-font","lost lease release preserves the new host's font")
 u:Hide(true)
 local reloaded=dofile("tests/ui_fixture.lua")("zhCN",nil,savedSettings)
 reloaded.A:Open("settings",{section="interface"})
 T.eq(reloaded.A.db.fontScale,70,"font percentage survives database loading")
 T.near(select(2,reloaded.U.pages.settings.heading:GetFont()),titleBase*.7,.0001,"a later UI context starts with the saved percentage")
 reloaded.A:SetSetting("fontScale",150);T.eq(reloaded.A.db.fontScale,130)
 reloaded.A:SetSetting("fontScale",40);T.eq(reloaded.A.db.fontScale,70)
 reloaded.U:Hide(true)
end

-- Resolving the current label must preserve the complete menu's path priority,
-- without rebuilding that menu for stable Settings refreshes.
do
 local f=dofile("tests/ui_fixture.lua")("enUS",nil,{reduceMotion=true})
 local a,u=f.A,f.U
 local oldLib,oldChat,oldUnit,oldDamage=LibStub,ChatFontNormal,UNIT_NAME_FONT,DAMAGE_TEXT_FONT
 local paths={"Fonts\\Alias.ttf","Fonts\\Shared.ttf","Fonts\\Alias.ttf",STANDARD_TEXT_FONT,a.Fonts:GetDefaultPath()}
 local names={"First alias","Shared name","Second alias","Game duplicate","Bundled duplicate"}
 ChatFontNormal=CreateFont();ChatFontNormal:SetFont("Fonts\\Chat.ttf",14,"")
 UNIT_NAME_FONT="Fonts\\Chat.ttf";DAMAGE_TEXT_FONT="Fonts\\Damage.ttf"
 local reads=0
 local media={List=function() reads=reads+1;return names end,Fetch=function(_,_,name) for i,n in ipairs(names) do if n==name then return paths[i] end end end}
 LibStub=function(name) if name=="LibSharedMedia-3.0" then return media end end
 local function Expected(value)
  for _,choice in ipairs(a.Fonts:Choices()) do if choice.value==value then return choice.label end end
 end
 for _,value in ipairs({"default","game","Fonts\\Chat.ttf","Fonts\\Damage.ttf","Fonts\\Alias.ttf","Fonts\\Shared.ttf",STANDARD_TEXT_FONT,a.Fonts:GetDefaultPath(),"Fonts\\Unlisted.ttf"}) do
  a:SetSetting("font",value)
  T.eq(a.Fonts:ChoiceLabel(value),Expected(value),"current font labels retain menu deduplication and priority")
 end
 T.eq(a.Fonts:ChoiceLabel(nil),nil);T.eq(a.Fonts:ChoiceLabel(false),nil)
 local check=a.Fonts.check;local set=check.SetFont
 check.SetFont=function(self,path,...) if path=="missing-font" then return false end;return set(self,path,...) end
 a:SetSetting("font","missing-font")
 T.eq(a.Fonts:ChoiceLabel("missing-font"),nil,"an unavailable unlisted saved value keeps the Choice's original fallback label")
 a:SetSetting("font","default");a:Open("settings",{section="interface"})
 local page=u.pages.settings;local choices=a.Fonts.Choices;local builds=0
 a.Fonts.Choices=function(self,...) builds=builds+1;return choices(self,...) end
 local widths=0
 for _,entry in pairs(page.controls) do
  local label=entry.widget.valueLabel
  if label then local width=label.GetStringWidth;label.GetStringWidth=function(self,...) widths=widths+1;return width(self,...) end end
 end
 page:Sync();widths,reads=0,0
 for _=1,20 do page:Sync() end
 T.eq(builds,0,"stable Settings refreshes do not build the font menu")
 T.eq(reads,0,"the bundled selection needs no SharedMedia directory read")
 T.eq(widths,0,"stable Settings refreshes do not remeasure percentage samples")
 names[1]="Renamed alias"
 page.controls.font.widget:Fire("OnClick","LeftButton")
 T.eq(builds,1,"opening the menu still builds its current complete directory")
 local menu=u.context:GetMenu();local found
 for _,entry in ipairs(menu.items) do if entry.value==paths[1] then found=entry.label end end
 T.eq(found,"Renamed alias","an alias change is visible without a retained font catalog")
 u:CloseMenu()
 local label=page.controls.fontScale.widget.valueLabel;local original=label.GetFont
 label:SetSpacing(label:GetSpacing()+1);page:Sync();T.ok(widths>0,"letter spacing invalidates percentage widths")
 widths=0;label:SetFont(label:GetFont());page:Sync();T.eq(widths,0,"the same font tuple retains its measured widths")
 label:SetFont("Fonts\\New.ttf",select(2,original(label)),"OUTLINE");page:Sync();T.ok(widths>0,"path and flags invalidate percentage widths")
 widths=0;u.frame:SetScale(u.frame:GetScale()*.9);page:Sync();T.ok(widths>0,"effective scale invalidates native text measurements")
 local oldScreen=GetPhysicalScreenSize;local physicalWidth=1920
 GetPhysicalScreenSize=function() return physicalWidth,1080 end
 page:Sync();widths=0;physicalWidth=2560;page:Sync();T.ok(widths>0,"physical resolution invalidates native text measurements")
 GetPhysicalScreenSize=oldScreen
 local getWidth=label.GetStringWidth
 label.GetStringWidth=function() return 0 end;label:SetSpacing(label:GetSpacing()+1);page:Sync()
 T.eq(page.controls.fontScale.widget.valueMetricsReady,false,"unready text metrics are not cached as final widths")
 label.GetStringWidth=getWidth;widths=0;page:Sync();T.ok(widths>0,"the next refresh retries initially unready text metrics")
 u:Hide(true)
 LibStub,ChatFontNormal,UNIT_NAME_FONT,DAMAGE_TEXT_FONT=oldLib,oldChat,oldUnit,oldDamage
end

-- The selected UI language is fixed for the login, including later LoD modules.
for _,case in ipairs({{"zhCN","enUS","Settings","LycheeFont"},{"enUS","zhCN","设置","荔枝字体"}}) do
 local savedSettings={language=case[2]}
 local languageFixture=dofile("tests/ui_fixture.lua")(case[1],nil,savedSettings)
 local a,u=languageFixture.A,languageFixture.U
 a:SetSetting("reduceMotion",true);a:Open("settings",{section="general"})
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
 reloaded.A:Open("settings",{section="general"})
 T.eq(reloaded.A:GetLocale(),case[1],"the next session applies the saved game-language choice")
 T.eq(reloaded.A.Fonts:GetPath(),"Interface\\AddOns\\LycheeGroup\\Media\\Fonts\\LycheeFont-"..case[1]..".ttf","the default font changes with the language after reload")
 T.eq(reloaded.U.pages.settings.reloadLanguage:IsShown(),false)
 reloaded.U:Hide(true)
end
