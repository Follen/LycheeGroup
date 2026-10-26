-- Public theme selection, defaults and the real Settings Choice menu.
local Fixture=dofile("tests/ui_fixture.lua")
local DEFAULT,FROSTED="lycheegroup.default","lycheegroup.frosted"
local function Definition(id,name,width,revision)
 return {schema=1,id=id,name=name,revision=revision or 1,appearance={main={tokens={width=width or 1440}}}}
end
local function Reload(f,locale) return Fixture(locale or "enUS",f.A.charPrefs,f.A.db) end
local function Entry(api,id,storage)
 for _,item in ipairs(api:List({includeBuiltins=true})) do
  if item.id==id and (not storage or item.storage==storage) then return item end
 end
 error("missing theme entry: "..id)
end
local function OpenSettings(f)
 f.A:SetSetting("reduceMotion",true);f.A:Open("settings",{section="interface"})
 local page=f.U.pages.settings
 T.ok(page.controls.theme,"Appearance settings expose the theme Choice")
 return page,page.controls.theme.widget
end
local function OpenMenu(f,choice)
 choice:Fire("OnClick","LeftButton")
 local menu=f.U.context:GetMenu()
 T.eq(menu.anchor,choice,"the theme control opens its real Choice menu")
 return menu
end
local function MenuItem(menu,id)
 for _,item in ipairs(menu.items) do if item.value==id then return item end end
 error("missing theme menu option: "..tostring(id))
end
local function Choose(f,choice,id)
 local menu=OpenMenu(f,choice)
 for _,row in ipairs(menu.list.rows) do
  if row.key and menu.items[row.key].value==id then
   row:Fire("OnMouseDown","LeftButton");row:Fire("OnMouseUp","LeftButton");row:Fire("OnClick","LeftButton")
   T.ok(not f.U.context:IsMenuOpen(),"selecting a theme closes the Choice menu")
   return
  end
 end
 error("missing visible theme menu row: "..tostring(id))
end

-- The opt-in catalog must leave the original startup source and visuals intact.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale);local a,api=f.A,f.A.API.Theme
 T.eq(api:GetStatus().current.id,false);T.eq(api:GetStatus().next.id,false)
 T.eq(api:GetStatus().reloadRequired,false);T.eq(#api:List(),0)
 for _,scope in ipairs({"main","floating"}) do
  local theme=a.Appearance:GetResolvedTheme(scope)
  local original=LycheeUI.ResolveTheme({},a.StyleDefaults[scope])
  for _,key in ipairs({"surface","surfaceLow","surfaceContainer","text","muted","dim","primary"}) do
   T.same(theme[key],original[key],"the default theme retains "..scope.."."..key)
  end
 end
 local list=api:List({includeBuiltins=true});T.eq(#list,2)
 for _,id in ipairs({DEFAULT,FROSTED}) do
  local item=Entry(api,id)
  T.eq(item.builtin,true);T.eq(item.effective,true)
  T.eq(type(item.name),"string");T.ok(item.name~="")
  T.eq(type(item.current),"boolean");T.eq(type(item.selected),"boolean");T.eq(type(item.isDefault),"boolean")
 end
 T.eq(Entry(api,DEFAULT).current,true);T.eq(Entry(api,DEFAULT).selected,true)
 T.eq(Entry(api,FROSTED).current,false);T.eq(Entry(api,FROSTED).selected,false)
 T.ok(api:Activate(DEFAULT));T.eq(api:GetStatus().next.id,false)
 local defaultStatus=api:GetStatus()
 T.ok(api:Activate(false));T.eq(api:GetStatus().next.id,false)
 T.same(api:GetStatus(),defaultStatus,"the default catalog ID and false have identical selection behavior")
 T.ok(api:Activate(FROSTED));T.eq(api:GetStatus().next.id,FROSTED)
 T.eq(api:GetStatus().current.id,false);T.eq(api:GetStatus().reloadRequired,true)
 T.eq(#api:List(),0,"selecting a built-in never registers an imported package")
 T.eq(Entry(api,FROSTED).selected,true);T.eq(Entry(api,FROSTED).current,false)
 for _,id in ipairs({DEFAULT,FROSTED}) do
  T.eq(api:Import(Definition(id,"Replacement")),false,"reserved built-in IDs cannot be replaced")
  T.eq(api:Remove(id),false,"built-ins cannot be removed")
 end
 T.eq(api:GetStatus().next.id,FROSTED)
 f=Reload(f,locale);api=f.A.API.Theme
 T.eq(api:GetStatus().current.id,FROSTED);T.eq(api:GetStatus().reloadRequired,false)
 T.eq(Entry(api,FROSTED).current,true);T.eq(Entry(api,FROSTED).selected,true)
 for _,scope in ipairs({"main","floating"}) do
  local theme=f.A.Appearance:GetResolvedTheme(scope)
  T.ok(theme.surface[4]>0 and theme.surface[4]<1,"glass surfaces are translucent in "..scope)
  for _,key in ipairs({"text","muted","dim","onPrimary","warning"}) do
   T.eq(theme[key][4],1,"glass keeps "..scope.."."..key.." fully opaque")
  end
 end
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 local page=f.U.pages.find
 T.eq(select(4,page.context:GetTextColor()),1,"native Find heading retains full text opacity")
 T.eq(page.frame:GetAlpha(),1);T.eq(page.surface:GetAlpha(),1,"transparency is not inherited from a faded page")
 f.U:Hide(true)
end

-- Names are metadata: visible, serializable and independent from startup visuals.
do
 local f=Fixture("enUS");local api=f.A.API.Theme
 local named=Definition("selection.named","First name",1460)
 T.ok(api:Import(named,{activate=true}))
 T.eq(Entry(api,named.id).name,"First name");T.eq(api:Export(named.id).name,"First name")
 named.name="Caller mutation"
 T.eq(Entry(api,named.id).name,"First name","imports own their name metadata")
 f=Reload(f);api=f.A.API.Theme
 local renamed=Definition("selection.named","Renamed",1460)
 T.ok(api:Import(renamed));T.eq(api:GetStatus().reloadRequired,false,"a metadata-only update needs no reload")
 T.eq(Entry(api,renamed.id).name,"Renamed");T.eq(api:Export(renamed.id).name,"Renamed")
 T.eq(api:Export().name,"Renamed","exporting the selected theme retains its name")
 local list=api:List();list[1].name="List mutation"
 T.eq(Entry(api,renamed.id).name,"Renamed","catalog results cannot mutate stored metadata")
 T.ok(api:Import(Definition("selection.legacy",nil,1470)))
 T.eq(Entry(api,"selection.legacy").name,"selection.legacy")
 T.eq(api:Export("selection.legacy").name,nil,"old definitions keep their optional name absent")
 for _,name in ipairs({"","   ",42,false,{}}) do
  local invalid=Definition("selection.invalid",name)
  T.eq(api:Import(invalid),false,"name must be a nonempty string when present")
 end
 T.eq(#api:List(),2,"failed name validation never registers a partial theme")
end

-- A shadowed package stays inspectable, while selection uses the character copy.
do
 local f=Fixture("enUS");local api=f.A.API.Theme
 T.ok(api:Import(Definition("selection.shadow","Account name",1430),{storage="account",default=true}))
 T.ok(api:Import(Definition("selection.shadow","Character name",1480,2),{storage="character"}))
 T.eq(#api:List(),2,"the compatibility catalog retains both persistent package copies")
 local account,character=Entry(api,"selection.shadow","account"),Entry(api,"selection.shadow","character")
 T.eq(account.effective,false);T.eq(account.selected,false);T.eq(account.name,"Account name")
 T.eq(character.effective,true);T.eq(character.selected,true);T.eq(character.name,"Character name")
 T.eq(character.isDefault,true);T.eq(account.isDefault,false)
 T.eq(api:GetStatus().next.storage,"character");T.eq(api:GetStatus().next.revision,2)
 T.eq(api:Export("selection.shadow").name,"Character name")
 T.eq(api:Export("selection.shadow",{storage="account"}).name,"Account name")
 T.ok(api:Remove("selection.shadow",{storage="character"}))
 T.eq(api:GetStatus().next.storage,"account");T.eq(api:GetStatus().next.revision,1)
 T.eq(Entry(api,"selection.shadow","account").effective,true)
end

-- Defaults never replace explicit player choices; false is a real choice.
do
 local f=Fixture("enUS");local api=f.A.API.Theme
 T.eq(api:GetStatus().default.id,false);T.eq(api:GetStatus().followingDefault,true)
 T.eq(api:GetStatus().defaultConfigured,false)
 for index,id in ipairs({"selection.account","selection.character","selection.explicit"}) do
  T.ok(api:Import(Definition(id,nil,1400+index*10)))
 end
 T.ok(api:SetDefault("selection.account",{storage="account"}))
 T.eq(api:GetStatus().default.id,"selection.account");T.eq(api:GetStatus().next.id,"selection.account")
 T.eq(api:GetStatus().defaultConfigured,true);T.eq(api:GetStatus().followingDefault,true)
 T.ok(api:SetDefault("selection.character",{storage="character"}))
 T.eq(api:GetStatus().default.id,"selection.character");T.eq(api:GetStatus().next.id,"selection.character")
 T.ok(api:Activate("selection.explicit",{storage="account"}))
 T.eq(api:GetStatus().next.id,"selection.explicit");T.eq(api:GetStatus().followingDefault,false)
 T.eq(api:GetStatus().default.id,"selection.character","status still explains the fallback default")
 T.ok(api:Activate(false,{storage="character"}))
 T.eq(api:GetStatus().next.id,false);T.eq(api:GetStatus().followingDefault,false)
 T.ok(api:SetDefault(FROSTED,{storage="character"}))
 T.eq(api:GetStatus().next.id,false,"third-party defaults cannot override an explicit built-in choice")
 T.ok(api:Import(Definition("selection.installed","Installed later",1490),{default=true,storage="character"}))
 T.eq(api:GetStatus().next.id,false,"installing a third-party default preserves an explicit player choice")
 T.eq(api:GetStatus().default.id,"selection.installed")
 T.ok(api:SetDefault(FROSTED,{storage="character"}))
 T.ok(api:UseDefault({storage="character"}))
 T.eq(f.A.charPrefs.uiConfig.theme.activePreset,nil)
 T.eq(api:GetStatus().next.id,"selection.explicit","clearing character selection reveals account selection")
 T.ok(api:UseDefault({storage="account"}))
 T.eq(f.A.db.uiConfig.theme.activePreset,nil)
 T.eq(api:GetStatus().next.id,FROSTED);T.eq(api:GetStatus().followingDefault,true)
 T.ok(api:SetDefault(nil,{storage="character"}))
 T.eq(api:GetStatus().next.id,"selection.account","clearing character default reveals account default")
 T.ok(api:SetDefault(false,{storage="character"}))
 T.eq(api:GetStatus().next.id,false);T.eq(api:GetStatus().default.id,false)
 T.eq(api:GetStatus().defaultConfigured,true,"false explicitly configures the built-in default")
 T.ok(api:SetDefault(nil,{storage="character"}));T.ok(api:SetDefault(nil,{storage="account"}))
 T.eq(api:GetStatus().next.id,false);T.eq(api:GetStatus().defaultConfigured,false)
 T.eq(api:GetStatus().reloadRequired,false,"returning to the original effective source cancels pending reload")
end

-- Atomic default registration preserves storage on error and obeys real reloads.
do
 local f=Fixture("enUS");local a,api=f.A,f.A.API.Theme
 local width=a.Appearance:GetResolvedTheme("main").width
 T.ok(api:Import(Definition("selection.default","Default package",width+90),{default=true,storage="character"}))
 T.eq(api:GetStatus().next.id,"selection.default");T.eq(api:GetStatus().default.id,"selection.default")
 T.eq(api:GetStatus().followingDefault,true);T.eq(api:GetStatus().reloadRequired,true)
 T.eq(a.charPrefs.uiConfig.theme.activePreset,nil,"setting a default never pins a player choice")
 T.eq(a.Appearance:GetResolvedTheme("main").width,width)
 a:SetSetting("reduceMotion",true);a:Open("settings",{section="interface"})
 T.eq(f.U.context.Theme.width,width,"a page first opened after setting a default still uses the boot source")
 local before=a.charPrefs.uiConfig.theme
 local invalid=Definition("selection.rejected","Rejected",width+150)
 invalid.appearance.main.tokens.unknownThemeToken=true
 T.eq(api:Import(invalid,{default=true,storage="character"}),false)
 T.eq(a.charPrefs.uiConfig.theme,before,"invalid default imports publish neither definition nor selection")
 T.eq(api:GetStatus().default.id,"selection.default");T.eq(#api:List(),1)
 T.eq(api:SetDefault("missing"),false);T.eq(api:SetDefault(42),false)
 T.eq(api:SetDefault(FROSTED,{storage="session"}),false)
 T.eq(api:UseDefault({storage="session"}),false)
 T.eq(api:Import(Definition("selection.rejected"),{default="yes"}),false)
 f=Reload(f);a,api=f.A,f.A.API.Theme
 T.eq(a.Appearance:GetResolvedTheme("main").width,width+90)
 T.eq(api:GetStatus().current.id,"selection.default");T.eq(api:GetStatus().reloadRequired,false)
 T.eq(api:GetStatus().followingDefault,true)
 T.ok(api:Import(Definition("selection.default","Default package",width+120,2),{storage="character"}))
 T.eq(api:GetStatus().reloadRequired,true,"updating a followed default waits for reload")
 T.eq(a.Appearance:GetResolvedTheme("main").width,width+90)
 f=Reload(f);T.eq(f.A.Appearance:GetResolvedTheme("main").width,width+120)
 T.eq(f.A.API.Theme:GetStatus().reloadRequired,false)
end

-- Account and character selections survive a new session in both UI languages.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale);local page,choice=OpenSettings(f)
 local defaultName=locale=="zhCN" and "默认主题" or "Default theme"
 local glassName=locale=="zhCN" and "透明毛玻璃" or "Frosted glass"
 T.eq(choice.label:GetText(),defaultName)
 local menu=OpenMenu(f,choice)
 T.eq(MenuItem(menu,DEFAULT).label,defaultName);T.eq(MenuItem(menu,FROSTED).label,glassName)
 f.U.context:CloseMenu()
 local current=f.U.context.Theme;local reloadButton=page.reloadLanguage
 Choose(f,choice,FROSTED)
 T.eq(choice.label:GetText(),glassName);T.eq(f.A.db.uiConfig.theme.activePreset,FROSTED)
 T.eq(f.A.charPrefs.uiConfig.theme.activePreset,nil,"new player selections default to account storage")
 T.eq(f.U.context.Theme,current);T.eq(f.A.API.Theme:GetStatus().current.id,false)
 T.eq(page.reloadLanguage,reloadButton);T.eq(reloadButton:IsVisible(),true)
 local nativeUI,reloads=C_UI,0;_G.C_UI={Reload=function() reloads=reloads+1 end}
 reloadButton:Fire("OnClick","LeftButton");_G.C_UI=nativeUI
 T.eq(reloads,1,"the theme selection reuses the existing reload action")
 f=Reload(f,locale);page,choice=OpenSettings(f)
 T.eq(choice.label:GetText(),glassName);T.eq(f.A.API.Theme:GetStatus().current.id,FROSTED)
 T.eq(page.reloadLanguage:IsShown(),false)
 Choose(f,choice,DEFAULT)
 T.eq(f.A.API.Theme:GetStatus().next.id,false);T.eq(choice.label:GetText(),defaultName)
 f=Reload(f,locale);page,choice=OpenSettings(f)
 T.eq(choice.label:GetText(),defaultName);T.eq(f.A.API.Theme:GetStatus().reloadRequired,false)
 T.ok(f.A.API.Theme:Activate(FROSTED,{storage="character"}))
 page:Sync();Choose(f,choice,DEFAULT)
 T.eq(f.A.charPrefs.uiConfig.theme.activePreset,false,"UI changes preserve an existing explicit character layer")
 T.eq(f.A.db.uiConfig.theme.activePreset,false,"character theme changes retain the account choice")
 f=Reload(f,locale);page,choice=OpenSettings(f)
 T.eq(choice.label:GetText(),defaultName);T.eq(f.A.API.Theme:GetStatus().current.id,false)
 f.U:Hide(true)
end

-- Following a character default does not imply a character-owned player choice.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale)
 T.ok(f.A.API.Theme:SetDefault(FROSTED,{storage="character"}))
 f=Reload(f,locale)
 local page,choice=OpenSettings(f);local api=f.A.API.Theme
 T.eq(api:GetStatus().current.id,FROSTED);T.eq(api:GetStatus().followingDefault,true)
 T.eq(f.A.db.uiConfig.theme.activePreset,nil);T.eq(f.A.charPrefs.uiConfig.theme.activePreset,nil)
 Choose(f,choice,DEFAULT)
 T.eq(f.A.db.uiConfig.theme.activePreset,false,"manual choice without an explicit layer is saved to the account")
 T.eq(f.A.charPrefs.uiConfig.theme.activePreset,nil,"a character default never captures the player's first explicit choice")
 T.eq(api:GetStatus().next.id,false,"the explicit account choice takes priority over the character default")
 T.eq(api:GetStatus().default.id,FROSTED);T.eq(api:GetStatus().followingDefault,false)
 T.eq(api:GetStatus().reloadRequired,true);T.eq(page.reloadLanguage:IsVisible(),true)
 f=Reload(f,locale)
 T.eq(f.A.API.Theme:GetStatus().current.id,false);T.eq(f.A.API.Theme:GetStatus().default.id,FROSTED)
 T.eq(f.A.API.Theme:GetStatus().followingDefault,false)
 f.U:Hide(true)
end

-- Damaged saved packages remain inspectable but are not selectable UI choices.
for _,locale in ipairs({"zhCN","enUS"}) do
 local malformed={
  ["selection.invalid.false"]=false,
  ["selection.invalid.schema"]={schema=2,id="selection.invalid.schema",revision=1,name="Wrong schema",values={}},
  ["selection.invalid.id"]={schema=1,id="selection.different.id",revision=1,name="Wrong ID",values={}},
 }
 local account={uiConfig={schema=2,user={},presets={},imported={},theme={presets=malformed,overrides={}}}}
 local f=Fixture(locale,nil,account);local api=f.A.API.Theme
 T.eq(#api:List(),3,"the public catalog retains damaged saved entries for inspection")
 for id in pairs(malformed) do
  local item=Entry(api,id,"account")
  T.eq(item.effective,false,"an invalid package cannot become an effective catalog option")
  T.eq(item.selected,false);T.eq(item.current,false)
 end
 local page,choice=OpenSettings(f)
 local menu=OpenMenu(f,choice)
 T.eq(#menu.items,2,"only the two valid built-ins are offered alongside malformed saved data")
 for _,item in ipairs(menu.items) do T.eq(malformed[item.value],nil,"damaged packages never appear in the theme Choice") end
 f.U.context:CloseMenu();Choose(f,choice,FROSTED)
 T.eq(api:GetStatus().next.id,FROSTED,"damaged unselected entries do not block a valid theme choice")
 T.same(f.A.db.uiConfig.theme.presets,malformed,"Settings inspection preserves the saved repair data")
 T.eq(f.A.db.uiConfig.theme.presets["selection.invalid.false"],false)
 T.eq(f.A.db.uiConfig.theme.presets["selection.invalid.schema"].schema,2)
 T.eq(f.A.db.uiConfig.theme.presets["selection.invalid.id"].id,"selection.different.id")
 T.eq(page.reloadLanguage:IsVisible(),true)
 f.U:Hide(true)
end

-- The live directory refreshes labels only while Settings owns its subscription.
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale);local page,choice=OpenSettings(f);local api=f.A.API.Theme
 T.ok(api:Import(Definition("selection.live","Published name")))
 T.ok(api:Import(Definition("selection.old")))
 local menu=OpenMenu(f,choice)
 T.eq(MenuItem(menu,"selection.live").label,"Published name")
 T.eq(MenuItem(menu,"selection.old").label,"selection.old")
 f.U.context:CloseMenu();Choose(f,choice,"selection.live")
 T.eq(choice.label:GetText(),"Published name")
 f=Reload(f,locale);page,choice=OpenSettings(f);api=f.A.API.Theme
 T.ok(api:Import(Definition("selection.live","Updated name")))
 T.eq(choice.label:GetText(),"Updated name","visible Settings reacts to directory metadata updates")
 T.eq(api:GetStatus().reloadRequired,false)
 f.A:Open("find")
 T.ok(api:Import(Definition("selection.live","While away")))
 T.eq(choice.label:GetText(),"Updated name","leaving Settings releases its directory subscription")
 f.A:Open("settings",{section="interface"})
 T.eq(choice.label:GetText(),"While away","re-entering Settings refreshes the current directory")
 T.ok(api:Remove("selection.live"))
 T.eq(choice.label:GetText(),locale=="zhCN" and "默认主题" or "Default theme")
 menu=OpenMenu(f,choice)
 for _,item in ipairs(menu.items) do T.ok(item.value~="selection.live","removed themes disappear from the next menu") end
 f.U:Hide(true)
end
