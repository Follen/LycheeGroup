-- Production Find controls consume per-leaf package defaults without pinning them.
local Fixture=dofile("tests/ui_fixture.lua")
local prefix="settings.find."
local function Key(category,field) return prefix.."categories."..category.."."..field end
local function Session(locale,prefs)
 local f=Fixture(locale,prefs,{reduceMotion=true});f.searches=0
 local search=f.G.Search.Search
 f.G.Search.Search=function(...) f.searches=f.searches+1;return search(...) end
 return f
end
local function UserFind(a)
 local values={}
 for key,value in pairs(a.charPrefs.uiConfig.user) do if key:sub(1,#prefix)==prefix then values[key]=value end end
 return values
end
local function Defaults(extra)
 local values={
  [prefix.."category"]="seasonDungeon",[Key("seasonDungeon","difficultyID")]=8,
  [Key("seasonDungeon","groupKeys")]={[20]=true},[Key("seasonDungeon","selected")]=true,
  [Key("seasonDungeon","minRating")]=100,[Key("seasonDungeon","maxRating")]=3000,
  [Key("seasonDungeon","minItemLevel")]=2,[Key("seasonDungeon","maxItemLevel")]=500,
  [Key("seasonDungeon","minMembers")]=2,[Key("seasonDungeon","maxMembers")]=4,
  [Key("seasonDungeon","tankPresence")]="missing",[Key("seasonDungeon","healerPresence")]="present",
  [Key("seasonDungeon","damagePresence")]="present",[Key("seasonDungeon","roleMatchAny")]=true,
  [Key("seasonDungeon","hideSameSpec")]=true,[Key("seasonDungeon","hideSameClassRole")]=true,
  [Key("seasonDungeon","hideZeroScore")]=true,[Key("seasonDungeon","requireBloodlust")]=true,
  [Key("seasonDungeon","social")]="friend",
  [Key("2","groupKey")]=20,[Key("2","difficultyID")]=8,[Key("2","selected")]=true,
  [Key("2","neededRole")]="HEALER",[Key("2","social")]="guild",
 }
 for key,value in pairs(extra or {}) do values[key]=value end
 return values
end

do
 local f=Session("enUS");local a,c=f.A,f.A.Configuration
 local schema=c:GetSchema();local count=0
 for path in pairs(schema) do if path:sub(1,#prefix)==prefix then count=count+1 end end
 T.eq(count,254,"eleven stable categories have 23 leaves plus initial category")
 T.eq(a.UI.frame,nil,"configuration schema does not build the UI or Catalog")
 for _,category in ipairs(a.FindPreferences.categories) do for _,field in ipairs(a.FindPreferences.fields) do
  local path=Key(category,field);T.eq(schema[path].default,false);T.eq(schema[path].storage,"character")
 end end
 for _,entry in ipairs({
  {"groupKey",0},{"groupKey",true},{"groupKey",.5},{"groupKeys",{["20"]=true}},
  {"groupKeys",{[20]="yes"}},{"tier","invalid"},{"difficultyID",1.5},{"selected",1},
  {"neededRole","ANY"},{"tankPresence","full"},{"social","caution"},{"sort","age"},
  {"minRating","2000"},{"minRating",0/0},{"maxRating",math.huge},{"maxMembers",0},{"maxMembers",1.2},
 }) do T.eq(c:Set({[Key("seasonDungeon",entry[1])]=entry[2]}),false,"invalid new API field is rejected atomically") end
 T.eq(c:Set({[prefix.."category"]="invalid"}),false)
 T.ok(c:Set({[Key("seasonDungeon","groupKeys")]={}}));T.same(c:Get(Key("seasonDungeon","groupKeys")),{})
 T.ok(c:Set({[Key("seasonDungeon","groupKey")]=false}));T.eq(c:Get(Key("seasonDungeon","groupKey")),false)
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Session(locale);local a,u,g=f.A,f.U,f.G;local c=a.Configuration
 local values=Defaults();T.ok(c:RegisterPreset("find.defaults",1,values,{storage="account",default=true}))
 a:Open("find");local p=u.pages.find;local searches=f.searches
 T.eq(g.filters.category,"seasonDungeon");T.eq(g.filters.difficultyID,8);T.same(g.filters.groupKeys,{[20]=true})
 for _,field in ipairs({"minRating","maxRating","minItemLevel","maxItemLevel","minMembers","maxMembers","tankPresence","healerPresence","damagePresence","hideZeroScore","hideSameSpec","hideSameClassRole","requireBloodlust","roleMatchAny"}) do
  T.eq(g.filters[field],values[Key("seasonDungeon",field)],locale.." package field "..field)
 end
 T.eq(g.filters.friends,true);T.eq(p.quickIdentity.active,true);T.eq(p.roleChoice:IsShown(),false)
 T.eq(p.filterFields.minRating.box:GetText(),"100");T.eq(g.filters.sort,"newest")
 for _=1,3 do p:UpdateFilters();p:SavePrefs();g:Notify("activities") end
 T.same(UserFind(a),{},"ordinary control sync and directory normalization never pin defaults")
 T.eq(f.searches,searches,"ordinary preference refresh does not search")
 T.ok(c:Set({[Key("seasonDungeon","hideSameSpec")]=false},{storage="character"}))
 local policyUsers=UserFind(a)
 p:SelectCategory("seasonDungeon")
 for _,button in ipairs(p.difficultyButtons) do if button.value==1 and button:IsShown() then button:Fire("OnClick","LeftButton");break end end
 T.eq(g.filters.difficultyID,1);T.eq(p.picker:IsShown(),true)
 a:SetSetting("rememberFilters",false);T.eq(g.filters.category,"seasonDungeon");T.eq(g.filters.difficultyID,1)
 T.eq(c:Get(Key("seasonDungeon","hideSameSpec")),true,"memory off resolves the different package default")
 T.eq(g.filters.hideSameSpec,nil,"the policy switch preserves the already edited live view")
 T.eq(a.charPrefs.uiConfig.user[Key("seasonDungeon","hideSameSpec")],false)
 T.eq(p.picker:IsShown(),true,"memory policy does not close a pending activity draft")
 a:SetSetting("rememberFilters",true);T.eq(g.filters.difficultyID,1);T.eq(f.searches,searches)
 T.same(UserFind(a),policyUsers,"memory policy does not pin current activity or filters")
 T.ok(c:Set({[Key("seasonDungeon","difficultyID")]=8,[Key("seasonDungeon","selected")]=true,[Key("seasonDungeon","groupKeys")]={}}))
 T.eq(g.filters.difficultyID,8);T.eq(p.picker:IsShown(),false,"explicit activity API writes replace the draft without searching")
 T.eq(f.searches,searches)
 T.ok(c:Reset({Key("seasonDungeon","difficultyID"),Key("seasonDungeon","selected"),Key("seasonDungeon","groupKeys")}))
 T.ok(c:Reset(Key("seasonDungeon","hideSameSpec"),{storage="character"}))
 p.hideZeroScore:Fire("OnClick","LeftButton")
 T.eq(c:Get(Key("seasonDungeon","hideZeroScore")),false,"a real clear stores an explicit false")
 T.eq(c:GetSource(Key("seasonDungeon","minRating")).kind,"preset","one field edit leaves other defaults inherited")
 values[Key("seasonDungeon","minRating")]=200;values[Key("seasonDungeon","hideZeroScore")]=true
 values[Key("seasonDungeon","social")]="guild"
 T.ok(c:RegisterPreset("find.defaults",2,values,{storage="account"}))
 T.eq(g.filters.minRating,200);T.eq(g.filters.hideZeroScore,nil);T.eq(g.filters.guild,true)
 T.eq(f.searches,searches,"package upgrade updates filters without starting a search")
 T.ok(c:Reset(Key("seasonDungeon","hideZeroScore"),{storage="character"}))
 T.eq(g.filters.hideZeroScore,true);T.eq(f.searches,searches)
 p.filterFields.minRating.box:UserType("")
 T.eq(c:Get(Key("seasonDungeon","minRating")),false);T.eq(g.filters.minRating,nil)
 T.eq(c:GetSource(Key("seasonDungeon","maxRating")).kind,"preset")
 -- Closing a draft keeps the confirmed choice; committing All is an explicit clear.
 p:SelectCategory("seasonDungeon")
 for _,row in ipairs(p.activities.rows) do if row.key==0 then row:Fire("OnMouseDown","LeftButton");row:Fire("OnClick","LeftButton");break end end
 T.same(c:Get(Key("seasonDungeon","groupKeys")),{},"All clears inherited group keys without a whole-category override")
 T.eq(c:Get(Key("seasonDungeon","groupKey")),false)
 T.eq(c:GetSource(Key("seasonDungeon","difficultyID")).kind,"preset","untouched difficulty continues to inherit")
 searches=f.searches
 T.ok(c:Set({[Key("seasonDungeon","minItemLevel")]=50,[Key("seasonDungeon","maxMembers")]=3}))
 T.eq(g.filters.minItemLevel,50);T.eq(g.filters.maxMembers,3);T.eq(f.searches,searches)
 local nativeCategory=g.Catalog:GetCategory("2")
 nativeCategory.activities={g.Catalog:GetActivity(2),g.Catalog:GetActivity(3)};nativeCategory.activitySet={[2]=true,[3]=true};g.Catalog.groups["2"]=nil
 p:SelectCategory("2");T.eq(g.filters.neededRole,"HEALER");T.eq(g.filters.guild,true)
 T.eq(c:GetSource(Key("2","neededRole")).kind,"preset")
 p:ClosePicker();p:SetFiltersOpen(true);f.Pick(p.roleChoice,false);T.eq(c:Get(Key("2","neededRole")),false)
 p:SelectCategory("seasonDungeon");T.eq(g.filters.minItemLevel,50);T.eq(g.filters.minRating,nil)
 local saved=UserFind(a)
 u:Hide(true);a:Open("find");T.same(UserFind(a),saved,"reentry does not materialize inherited fields")
 local account,character=a.db,a.charPrefs;u:Hide(true)
 f=Fixture(locale,character,account);f.A:Open("find")
 T.eq(f.G.filters.minRating,nil,"an explicit cleared field survives reload")
 T.eq(f.A.Configuration:GetSource(Key("seasonDungeon","maxRating")).kind,"preset","compatibility mirrors do not become users on reload")
 T.eq(f.G.filters.maxMembers,4,"session preferences expire at reload")
 f.U:Hide(true)

 -- Memory off hides historical choices, retains them, and allows session changes.
 local history={rememberFilters=false,find={category="seasonDungeon",categoryPrefs={seasonDungeon={hideSameSpec=true,selected=true,difficultyID=8}}}}
 f=Session(locale,history);a,u,g=f.A,f.U,f.G;c=a.Configuration
 T.ok(c:ApplyPreset("find.off",1,{[Key("seasonDungeon","hideSameSpec")]=false,[Key("seasonDungeon","selected")]=true,[Key("seasonDungeon","difficultyID")]=8},{storage="account"}))
 a:Open("find");p=u.pages.find;searches=f.searches
 T.eq(c:Get(Key("seasonDungeon","hideSameSpec")),false);T.eq(g.filters.hideSameSpec,nil)
 T.eq(a.charPrefs.uiConfig.user[Key("seasonDungeon","hideSameSpec")],true,"disabled memory preserves stored history")
 T.ok(c:Set({[Key("seasonDungeon","hideSameSpec")]=true}))
 T.eq(g.filters.hideSameSpec,true,"same-as-history session Set changes the effective off-memory projection")
 T.eq(c:GetSource(Key("seasonDungeon","hideSameSpec")).storage,"session")
 T.ok(c:Reset(Key("seasonDungeon","hideSameSpec")))
 T.eq(g.filters.hideSameSpec,nil,"session Reset returns to the package while memory is off")
 local before=UserFind(a);p:SetIdentityFilter("class")
 T.eq(g.filters.hideSameClass,true);T.same(UserFind(a),before,"UI edits with memory off are temporary")
 p:SelectCategory("seasonRaid");p:SelectCategory("seasonDungeon");T.eq(g.filters.hideSameClass,nil)
 a:SetSetting("rememberFilters",true);T.eq(g.filters.hideSameSpec,nil,"the memory policy switch preserves the current temporary view")
 p:SelectCategory("seasonRaid");p:SelectCategory("seasonDungeon");T.eq(g.filters.hideSameSpec,true)
 T.eq(f.searches,searches,"memory and source changes do not start native searches")
 u:Hide(true)

 -- Provider controls and configuration changes never write real user preferences.
 f=Session(locale);a,u,g=f.A,f.U,f.G;c=a.Configuration
 a:Open("find");local real=UserFind(a)
 T.ok(a:Preview("applications"));p=u.pages.find;local provider=u:GetGroup();local private=provider.prefs
 p:SetIdentityFilter("class");p:ClearFilters();p:CommitChoice();p:SavePrefs()
 T.same(UserFind(a),real);T.eq(provider.prefs,private)
 T.ok(c:Set({[Key("seasonDungeon","minRating")]=1234}))
 T.eq(u:GetGroup(),provider,"real API changes do not replace or refresh the private provider")
 u:StopPreview(true);a:Open("find");T.eq(g.filters.minRating,1234)
 u:Hide(true)
end

-- Core migration precedes UI construction; resets never import an old mirror again.
do
 local prefs={find={category="seasonDungeon",categoryPrefs={seasonDungeon={minRating="2000",maxRating="not a number",tankPresence="broken",groupKeys={[20]=true},selected=true,difficultyID=8}}}}
 local f=Session("enUS",prefs);local a,c=f.A,f.A.Configuration
 T.eq(c:Get(Key("seasonDungeon","minRating")),2000);T.eq(a.UI.frame,nil)
 T.eq(prefs.find.categoryPrefs.seasonDungeon.minRating,"2000","migration preserves the original legacy value before projection")
 T.eq(prefs.uiConfigRecovery[Key("seasonDungeon","tankPresence")].value,"broken")
 T.eq(prefs.uiConfigRecovery[Key("seasonDungeon","maxRating")].value,"not a number")
 T.ok(c:Reset(Key("seasonDungeon","minRating"),{storage="character"}))
 local account=a.db;f=Fixture("enUS",prefs,account);f.A:Open("find")
 T.eq(f.A.Configuration:Get(Key("seasonDungeon","minRating")),false,"Reset cannot resurrect an old legacy leaf")
 f.U:Hide(true)
end

-- The native directory can extend the stable category list without losing data.
do
 local f=Session("enUS");local a,u,g=f.A,f.U,f.G
 local categories=g.Catalog.GetCategories
 g.Catalog.GetCategories=function(self)
  local list=categories(self);if not self.auditCategory then self.auditCategory=true;list[#list+1]={key="77",id=77,name="Extra",icon="flag"} end;return list
 end
 a:Open("find");local p=u.pages.find;p:SelectCategory("77")
 T.ok(a.Configuration:GetSchema(Key("77","minRating"))[Key("77","minRating")])
 T.ok(a.Configuration:Set({[Key("77","minRating")]=77},{storage="character"}))
 T.ok(a.Configuration:RegisterPreset("find.extra",1,{[Key("77","social")]="guild"},{storage="account",default=true}))
 local account,prefs=a.db,a.charPrefs;u:Hide(true)
 f=Fixture("enUS",prefs,account)
 T.eq(f.A.Configuration:Get(Key("77","minRating")),77,"saved native leaves register before Bind validates users")
 T.eq(f.A.Configuration:Get(Key("77","social")),"guild","saved native package leaves register before package validation")
 T.eq(f.A.Configuration:GetSource(Key("77","social")).kind,"preset")
 f.A:Open("find");T.eq(f.G.filters.category,"seasonDungeon","an unavailable native category falls back safely")
 T.eq(f.A.Configuration:Get(prefix.."category"),"77","fallback does not replace the saved native selection")
 f.U:Hide(true)
end
