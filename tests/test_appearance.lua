-- Read-only authoring and current-startup appearance data.
local Fixture=dofile("tests/ui_fixture.lua")
local function Theme(id,appearance) return {schema=1,id=id,revision=1,appearance=appearance} end

do
 local f=Fixture("enUS");local a=f.A;local api=a.API.Appearance
 T.eq(api.version,2)
 for _,name in ipairs({"Set","Reset","SetElement","SetElements","ResetElement","ResetElements","SetUtilities","ResetUtilities","GetElement","GetElementInfo"}) do T.eq(api[name],nil) end
 T.eq(api:GetSchema("missing"),nil);T.eq(api:Get("missing"),nil)
 local schema=api:GetSchema("main")
 T.eq(schema.font,nil);T.eq(schema.labelFontSize.role,"label")
 local original=schema.labelFontSize.aliases[1];schema.labelFontSize.aliases[1]="changed"
 T.eq(api:GetSchema("main").labelFontSize.aliases[1],original)
 local colors=api:GetColors("main");local red=colors.primary[1];colors.primary[1]=0
 T.eq(api:GetColors("main").primary[1],red)
 local styles=api:GetStyleSchema("main");T.eq(type(styles["button.base.root.height"].types),"table")
 styles["button.base.root.height"].types[1]="changed"
 T.eq(api:GetStyleSchema("main")["button.base.root.height"].types[1],"number")
 local field=api:GetElementSchema("main","settings.row",{"settings.row.base.label.alpha"})
 T.eq(field["settings.row.base.label.alpha"].max,1)
 T.eq(a.UI.frame,nil);T.eq(next(a.db.uiConfig.user),nil)
end

-- Defaults remain an editable template, independent of current/user values.
do
 local f=Fixture("enUS");local api=f.A.API.Theme
 local defaults=api:GetDefaults();T.eq(defaults.schema,1);T.eq(defaults.settings.fontScale,100)
 T.eq(defaults.appearance.main.tokens.memberNameFont,f.A.StyleDefaults.main.memberNameFont)
 local original=defaults.appearance.main.tokens.labelFontSize
 defaults.appearance.main.tokens.labelFontSize=999
 T.eq(api:GetDefaults().appearance.main.tokens.labelFontSize,original)
 T.eq(#api:List(),0);T.eq(api:GetStatus().reloadRequired,false)
end

-- Keyed declarations retain typed keys and are applied only to their real bind.
do
 local definition=Theme("appearance.rules",{main={utilities={emphasis={base={label={color="warning"}}}},elements={
  ["settings.row"]={classes="emphasis",base={label={alpha=.8}},instances={
   [7]={base={label={alpha=.4}}},["7"]={base={label={alpha=.6}}},["玩家.A%角色"]={base={label={fontSize=19}}},
  }},
 }}})
 local f=Fixture("enUS",nil,nil,definition);local api=f.A.API.Appearance
 T.eq(api:GetElementRules("main","settings.row",7).base.label.alpha,.4)
 T.eq(api:GetElementRules("main","settings.row","7").base.label.alpha,.6)
 T.eq(api:GetElementRules("main","settings.row","玩家.A%角色").base.label.fontSize,19)
 T.eq(api:GetElementRules("main","settings.row","other").base.label.alpha,.8)
 local rules=api:GetElements("main");rules["settings.row"].base.label.alpha=0
 T.eq(api:GetElementRules("main","settings.row","other").base.label.alpha,.8)
 T.eq(api:GetUtilities("main").emphasis.base.label.color,"warning")
end

-- Typography aliases and old media compatibility are resolved at startup.
do
 local definition=Theme("appearance.aliases",{main={tokens={font14=17,media="LegacyAssets/"}},floating={tokens={media="GenericAssets/",productMedia="ProductAssets/"}}})
 local f=Fixture("enUS",nil,nil,definition);local api=f.A.API.Appearance
 T.eq(api:GetTypography("main").label.fontSize,17)
 T.eq(api:Get("main").memberNameFont,f.A.StyleDefaults.main.memberNameFont)
 T.eq(api:Get("main").productMedia,"LegacyAssets/")
 T.eq(api:Get("floating").productMedia,"ProductAssets/")
 T.eq(api:Get("floating").media,"GenericAssets/")
end
