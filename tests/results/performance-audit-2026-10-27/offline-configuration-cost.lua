local Fixture=dofile('tests/ui_fixture.lua')
local function Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function Session(settings)
 return Fixture('enUS',nil,settings or {reduceMotion=true})
end
local function Memory(label,iterations,action)
 action(0);collectgarbage('collect');local before=collectgarbage('count');collectgarbage('stop')
 local start=os.clock();for i=1,iterations do action(i) end;local elapsed=os.clock()-start
 local allocated=collectgarbage('count')-before;collectgarbage('restart');collectgarbage('collect')
 print('MEM',label,iterations,allocated,allocated/iterations,collectgarbage('count')-before,elapsed*1000/iterations)
end
local function Profile(f)
 local a,c,u=f.A,f.A.Configuration,f.U;local counters={}
 local function Wrap(owner,key,label)
  local original=owner[key];owner[key]=function(self,...)
   counters[label]=(counters[label] or 0)+1;return original(self,...)
  end
 end
 Wrap(c,'Get','get');Wrap(c,'GetSource','source');Wrap(c,'GetSchema','schema');Wrap(c,'Set','set')
 Wrap(c,'Resolve','resolve');Wrap(c,'SelectedPreset','selectedPreset')
 Wrap(a,'ApplyConfigurationChanges','notify');Wrap(a.FindPreferences,'Category','category')
 Wrap(u.pages.find,'SavePrefs','savePrefs');Wrap(u.pages.find,'UpdateFilters','updateFilters')
 Wrap(u.pages.find,'RefreshPreferences','refreshPreferences');Wrap(u.pages.settings,'Sync','settingsSync')
 local original=c.Snapshot
 c.Snapshot=function(self,keys)
  counters.snapshot=(counters.snapshot or 0)+1
  counters.snapshotKeys=(counters.snapshotKeys or 0)+Count(keys or self.definitions)
  if not keys then counters.fullSnapshot=(counters.fullSnapshot or 0)+1 end
  return original(self,keys)
 end
 local function Reset() for key in pairs(counters) do counters[key]=nil end end
 local function Show(label)
  local parts={};for key,value in pairs(counters) do parts[#parts+1]=key..'='..value end;table.sort(parts)
  print('COUNT',label,table.concat(parts,','),'user='..Count(c.stores.character.user),'imported='..Count(c.stores.character.imported))
 end
 return Reset,Show
end
do
 local f=Session();local a,c=f.A,f.A.Configuration
 print('SIZE','schema',Count(c.definitions),'cold-imported',Count(c.stores.character.imported))
 local notify=a.ApplyConfigurationChanges;a.ApplyConfigurationChanges=function() end
 local writes={{['settings.defaultSort']='newest'},{['settings.defaultSort']='rating'}}
 Memory('cold-character-single-Set',200,function(i) c:Set(writes[i%2+1],{storage='character'}) end)
 a.ApplyConfigurationChanges=notify;a:Open('find')
 print('SIZE','schema',Count(c.definitions),'warm-imported',Count(c.stores.character.imported))
 a.ApplyConfigurationChanges=function() end
 Memory('warm-character-single-Set',200,function(i) c:Set(writes[i%2+1],{storage='character'}) end)
 Memory('warm-session-single-Set',200,function(i) c:Set(writes[i%2+1]) end)
 Memory('scalar-Get',10000,function() c:Get('settings.noteMarks') end)
 Memory('scalar-GetSource',1000,function() c:GetSource('settings.noteMarks') end)
 Memory('same-inactive-RegisterPreset',100,function() c:RegisterPreset('perf.inactive',1,writes[1],{storage='account'}) end)
 local big=c.stores.character.imported;c.stores.character.imported={}
 Memory('counterfactual-small-imported-single-Set',200,function(i) c:Set(writes[i%2+1],{storage='character'}) end)
 c.stores.character.imported=big
end
do
 local f=Session();local a,u,c=f.A,f.U,f.A.Configuration
 local reset,show=Profile(f);a:Open('find');local p=u.pages.find
 reset();for _=1,100 do p:UpdateFilters() end;show('stable-UpdateFilters-100')
 reset();for _=1,100 do p:SavePrefs() end;show('stable-SavePrefs-100')
 reset();for i=1,100 do c:Set({['settings.defaultSort']=i%2==0 and 'rating' or 'newest'},{storage='character'}) end;show('single-Set-100')
 reset();for _=1,20 do c:RegisterPreset('perf.inactive',1,{['settings.defaultSort']='newest'},{storage='account'}) end;show('inactive-package-replace-20')
 reset();for _=1,100 do a.FindPreferences:RegisterCategories(f.G.Catalog:GetCategories()) end;show('known-category-register-100')
 local fields={};for _,field in ipairs(a.FindPreferences.fields) do
  local key=a.FindPreferences:Key('seasonDungeon',field);local def=c.definitions[key]
  if def.type=='boolean' then fields[key]=true end
 end
 fields[a.FindPreferences:Key('seasonDungeon','roleMatchAny')]=true
 fields[a.FindPreferences:Key('seasonDungeon','hideSameClass')]=false
 reset();c:ApplyPreset('perf.active',1,fields,{storage='account'});show('active-package-many-leaves')
end
for _,built in ipairs({false,true}) do
 local f=Session();local a,u=f.A,f.U
 if built then a:Open('settings') end
 a:Open('find');local p=u.pages.find;p:SetFiltersOpen(true)
 local reset,show=Profile(f)
 reset();for i=1,50 do p.filterFields.minRating.box:UserType(i%2==0 and '100' or '101') end
 show(built and 'numeric-user-edits-50-settings-hidden' or 'numeric-user-edits-50-settings-unbuilt')
 Memory(built and 'numeric-user-edits-50-settings-hidden' or 'numeric-user-edits-50-settings-unbuilt',50,function(i)
  p.filterFields.minRating.box:UserType(i%2==0 and '100' or '101')
 end)
end
do
 local f=Session();local a,u=f.A,f.U;a:Open('find');local p=u.pages.find
 Memory('SavePrefs-only',500,function() p:SavePrefs() end)
 Memory('known-category-register',500,function() a.FindPreferences:RegisterCategories(f.G.Catalog:GetCategories()) end)
 local start=Count(a.Configuration.definitions)
 a.FindPreferences:RegisterCategories({{key='77'}})
 local once=Count(a.Configuration.definitions)
 for _=1,100 do a.FindPreferences:RegisterCategories({{key='77'}}) end
 print('GROWTH',start,once,Count(a.Configuration.definitions))
end
do
 local f=Session();local a,b=f.A,f.A.Bindings
 b:InitializeDefault()
 local writes,saves,sets=0,0,0
 local binding,save,set=SetBinding,SaveBindings,a.Configuration.Set
 SetBinding=function(...) writes=writes+1;return binding(...) end
 SaveBindings=function(...) saves=saves+1;return save(...) end
 a.Configuration.Set=function(...) sets=sets+1;return set(...) end
 Memory('stable-bindings-initialize',1000,function() b:InitializeDefault() end)
 print('BINDINGS',writes,saves,sets)
 SetBinding,SaveBindings= binding,save
end
