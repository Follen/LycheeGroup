-- Notification work is bounded by changed layout inputs, not the full member set.
local checks=0
local mode=arg and arg[1]
if mode~='create' and mode~='floating' and mode~='find' then mode=nil end
local function Check(value,message) checks=checks+1;assert(value,message) end
local function ApplicantGeometry(page)
 local values={}
 for index,id in ipairs(page.appIDs) do
  local layout=page.batchLayouts[id];values[#values+1]=id..':'..page.batchTops[index]..':'..layout.height
  for i,height in ipairs(layout.heights) do values[#values+1]=layout.tops[i]..':'..height end
 end
 return table.concat(values,'|')
end
local function FloatingGeometry(page)
 local values={}
 for index,entry in ipairs(page.entries) do
  values[#values+1]=tostring(page.entryTops[index])
  for _,field in ipairs({'height','nameWidth','nameHeight','metaWidth','metaText','itemLevelText','itemLevelWidth','scoreWidth','textHeight','textWidth','hideRating','padTop','footer','actions'}) do values[#values+1]=tostring(entry[field]) end
 end
 return table.concat(values,'|')
end
local function Member(id,index)
 return {name='Applicant'..id..'x'..index,nameKey='Applicant'..id..'x'..index..'-Home',class='WARRIOR',assignedRole='DAMAGER',itemLevel=250,rating=100,dungeonScore=100}
end
local function Fixture(locale,theme)
 local f=dofile('tests/ui_fixture.lua')(locale or 'enUS',nil,{reduceMotion=true},theme)
 f.G.listing={activityID=2,name='Layout costs'}
 for id=1,20 do
  local members={};for index=1,5 do members[index]=Member(id,index) end
  f.G.applicants[id]={id=id,status='applied',displayOrderID=id,members=members}
 end
 return f
end

if not mode or mode=='create' then
 for _,locale in ipairs({'zhCN','enUS'}) do
 local f=Fixture(locale,{schema=1,id='refresh-cost.'..locale,revision=1,appearance={main={elements={['member.marks']={instances={FirstIdentity={base={root={width=80}}},SecondIdentity={base={root={width=120}}}}}}}}})
 local a,u,g=f.A,f.U,f.G
 a:Open('create');local p=u.pages.create
 local reads=0;local read=p.applicantMeasure.text.GetStringHeight
 p.applicantMeasure.text.GetStringHeight=function(self,...) reads=reads+1;return read(self,...) end
 local first=p.batchLayouts[1]
 g.applicants[1].pendingStatus='invited';g:Notify('applicants')
 Check(reads==0,'status-only notifications do not remeasure unchanged names')
 Check(p.batchLayouts[1]==first,'unchanged batch geometry retains its layout')
 g.applicants[1].members[1].nameKey=string.rep('Long',40)..'-Home';g:Notify('applicants')
 Check(reads>0 and reads<=5,'an in-place name change measures only its batch')
 Check(p.batchLayouts[1].heights[1]>first.heights[1],'long names still expand their row')
 reads=0;g.applicants[2].members[1].isBNetFriend=true;g:Notify('applicants')
 Check(reads>0 and reads<=5,'a relationship marker change measures only its batch')
 reads=0;a.Notes:Add('Applicant3x1','Home','Marker',nil,nil,{type='caution'})
 Check(reads>0 and reads<=5,'a new note marker invalidates the affected batch')
 reads=0;a:SetSetting('relations',false)
 Check(reads>0 and reads<=5,'relationship preference changes only affected geometry')
 reads=0;u:ApplyFont(a.Fonts:GetPath(),1.3)
 Check(reads>=100,'font changes invalidate the complete current layout')
 reads=0;p:LayoutBatches();Check(reads==0,'settled font geometry is reused')
 local members=g.applicants[1].members;members[1],members[2]=members[2],members[1]
 g:Notify('applicants');Check(reads>0 and reads<=5,'member order changes only remeasure their batch')
 Check(p.batchLayouts[1].heights[2]>p.batchLayouts[1].heights[1],'wrapped heights follow reordered members')
 local markedWidths={};local bind=u.Members.BindMarks
 u.Members.BindMarks=function(self,frame,member)
  local width=bind(self,frame,member)
  if frame==p.applicantMeasure.marks and member.guid then markedWidths[member.guid]=frame:GetWidth() end
  return width
 end
 reads=0;local keyed=g.applicants[6].members[1];keyed.nameKey=nil;keyed.name='BareName';keyed.realm=nil;keyed.guid='FirstIdentity'
 g:Notify('applicants');Check(p.batchLayouts[6].memberKeys[1]=='FirstIdentity','bare names use their actual marker element identity')
 Check(markedWidths.FirstIdentity==80,'the first identity applies its fixed marker width rule')
 reads=0;keyed.guid='SecondIdentity';g:Notify('applicants')
 Check(reads>0 and reads<=5 and p.batchLayouts[6].memberKeys[1]=='SecondIdentity','equal names and marks still invalidate a changed per-key marker rule')
 Check(markedWidths.SecondIdentity==120,'the replacement identity applies its different marker width rule')
 u:ApplyFont(a.Fonts:GetPath(),1)
 reads=0;local header=p.applicantTable;local mouse=IsMouseButtonDown;IsMouseButtonDown=function() return true end
 header:StartDrag(1);f.S.cursorX=f.S.cursorX-30*header:GetEffectiveScale();header:UpdateDrag();header:StopDrag(true);IsMouseButtonDown=mouse
 Check(reads>=100,'changing the name-column width invalidates all current names')
 local replacement={id=4,status='applied',displayOrderID=4,members={}}
 for index,member in ipairs(g.applicants[4].members) do replacement.members[index]=member end
 g.applicants[4]=replacement;g:Notify('applicants')
 Check(p.batchLayouts[4].source==replacement,'equal geometry refreshes its current source identity')
 g.applicants[5]=nil;g:Notify('applicants');Check(p.batchLayouts[5]==nil,'removed batches leave no geometry cache')
 local geometry=ApplicantGeometry(p);p.batchLayouts=nil;p:LayoutBatches()
 Check(ApplicantGeometry(p)==geometry,'cached applicant geometry equals a fresh complete measurement after all input changes')
 u:Hide(true);Check(p.batchLayouts==nil and p.appIDs==nil,'closing releases active applicant layouts')
 end
end

if not mode or mode=='floating' then
 for _,locale in ipairs({'zhCN','enUS'}) do
 local f=Fixture(locale);local a,g=f.A,f.G
 RAID_CLASS_COLORS={WARRIOR={r=.8,g=.6,b=.4}}
 dofile('addon/LycheeGroup/Floating.lua');dofile('addon/LycheeGroup/API.lua')
 local p=a.Floating;p:Bind(g);p:UpdateSettings();p:ShowPanel()
 local reads,fonts=0,0;local read,font=p.measure.GetStringHeight,p.measure.SetFont
 p.measure.GetStringHeight=function(self,...) reads=reads+1;return read(self,...) end
 p.measure.SetFont=function(self,...) fonts=fonts+1;return font(self,...) end
 g:Notify('applicants');Check(reads==0 and fonts==0,'unchanged floating contents do no text measurement or font switching')
 g.applicants[1].members[1].itemLevel=251;g:Notify('applicants')
 Check(reads>0 and reads<=2 and fonts<=3,'one changed metric remeasures only its member')
 reads,fonts=0,0;g.applicants[2].members[1].nameKey=string.rep('Long',40)..'-Home';g:Notify('applicants')
 Check(reads>0 and reads<=2,'in-place floating names invalidate their member geometry')
 local index;for i,entry in ipairs(p.entries) do if entry.member==g.applicants[2].members[1] then index=i end end
 Check(index and p.entries[index].nameHeight>p.context:GetLineHeight('floatingMemberNameLine'),'wrapped floating names remain complete')
 reads,fonts=0,0;g.applicants[3].comment=string.rep('Comment ',30);g:Notify('applicants')
 Check(reads==1,'a batch comment only remeasures its footer')
 reads=0;p:ApplyFont(a.Fonts:GetPath(),1.3);Check(reads>=200,'floating font changes remeasure every current member')
 reads=0;p:ShowPanel();Check(reads==0,'settled floating font geometry is reused')
 local members=g.applicants[2].members;members[1],members[2]=members[2],members[1]
 g:Notify('applicants');Check(reads>0 and reads<=4,'member order only invalidates the changed slots')
 for _,change in ipairs({
  function(member) member.raceName=string.rep('Race ',30) end,
  function(member) member.factionGroup=1 end,
  function(member) member.specName=string.rep('Specialization ',10) end,
  function(member) member.ratingKind='pvp';member.rating=nil end,
 }) do
  reads,fonts=0,0;change(g.applicants[6].members[1]);g:Notify('applicants')
  Check(reads>0 and reads<=2 and fonts<=3,'changed metadata, faction and rating text invalidate only their member')
 end
 Check(p.measureLayouts[6].members[1].scoreText==(locale=='zhCN' and '未知分数' or 'Unknown'),'unknown PvP ratings do not fall back to a dungeon score')
 reads=0;g.CanManageApplicants=function() return false end;g:Notify('permissions')
 Check(reads==1,'permission changes remeasure the wider comment footer without measuring members')
 reads=0;g.applicants[3].comment=nil;g:Notify('applicants')
 Check(reads==0 and p.measureLayouts[3].comment==nil,'removing a comment releases its old cached text without measuring members')
 reads=0;g.listing.activityID=1;g:Notify('listing')
 Check(reads>=200,'changing to a no-rating activity invalidates every member width')
 g.applicants[4]=nil;g:Notify('applicants')
 Check(not p.measureLayouts[4],'removed floating batches are released')
 local geometry=FloatingGeometry(p);p.measureLayouts=nil;p:ShowPanel()
 Check(FloatingGeometry(p)==geometry,'cached floating geometry equals a fresh complete measurement after all input changes')
 p:Dismiss();Check(p.measureLayouts==nil,'hidden floating panels release measurement records')
 Check(p.measure:GetText()=='','measurement text does not retain an old player or comment')
 reads,fonts=0,0;g:Notify('applicants');Check(reads==0 and fonts==0,'hidden notifications do no display work')
 end
end

if not mode or mode=='find' then
 local f=dofile('tests/ui_fixture.lua')('enUS',nil,{reduceMotion=true})
 f.A:Open('find');local p=f.U.pages.find
 local layouts=0;local layout=p.LayoutFilters
 p.LayoutFilters=function(self,...) layouts=layouts+1;return layout(self,...) end
 p.filteredResultCount=123;p:UpdateFilterResultSummary()
 Check(layouts==0 and p.filterStatus:GetText():find('123',1,true)==nil,'hidden result summaries defer layout')
 p:CommitChoice();p.filteredResultCount=123;p:UpdateFilterResultSummary()
 Check(layouts==0 and p.filterStatus:GetText():find('123',1,true),'hidden summaries still receive current text')
 p:SetFiltersOpen(true);Check(layouts>0,'opening resolves deferred final geometry')
 layouts=0;p:UpdateFilterResultSummary();Check(layouts==0,'equal visible summary text avoids duplicate layout')
 p.filteredResultCount=124;p:UpdateFilterResultSummary();Check(layouts==1,'changed visible summaries retain their layout update')
 f.U:Hide(true)
 for _,locale in ipairs({'zhCN','enUS'}) do
  for _,choice in ipairs({{}, {groupKey=20,difficultyID=8}, {groupKeys={[20]=true},difficultyID=8}, {selected=true,difficultyID=8}}) do
   local f=dofile('tests/ui_fixture.lua')(locale,{rememberFilters=true,find={category='seasonDungeon',categoryPrefs={seasonDungeon=choice}}},{reduceMotion=true},{schema=1,id='picker.refresh.'..locale,revision=1,appearance={main={elements={['find.quickRole']={instances={tankPresence={base={root={width=160},label={fontSize=24}}}}}}}}})
   local p=f.U.pages.find
   p:ClosePicker();Check(not p.picker,'closing before a picker is built does not construct it')
   f.A:Open('find');p:SelectCategory('seasonDungeon');p:ClosePicker()
   local refreshes,bindings,renders=0,0,0
   local refresh,set=p.RefreshPicker,p.activities.SetItems
   function p:RefreshPicker(...) refreshes=refreshes+1;return refresh(self,...) end
   function p.activities:SetItems(ids,render,...)
    bindings=bindings+1
    return set(self,ids,function(...) renders=renders+1;return render(...) end,...)
   end
   local roleButton=p.quickChoices.tankPresence.button
   for i=1,20 do
    p:SetFiltersOpen(true)
    Check(roleButton:GetWidth()==160 and p.quickFilters:GetParent()==p.importantFilters,'filter opening applies the fixed role-button geometry without activity refreshes')
    p:SetFiltersOpen(false)
   end
   Check(refreshes==0 and bindings==0 and renders==0,'closed activity pickers do no work during repeated filter toggles')
   Check(not p.picker:IsShown(),'filter toggles keep the activity picker hidden')
   Check(f.G.filters.groupKey==choice.groupKey and f.G.filters.difficultyID==choice.difficultyID,'hidden toggles preserve the confirmed single selection and difficulty')
   Check((f.G.filters.groupKeys and f.G.filters.groupKeys[20])==(choice.groupKeys and choice.groupKeys[20]),'hidden toggles preserve a confirmed collection')
   -- A native hide can precede ClosePicker. The unconfirmed selection still
   -- has to be discarded even though the menu is already hidden.
   p:SelectCategory('seasonDungeon')
   local difficulty
   for _,button in ipairs(p.difficultyButtons) do if button:IsShown() and button.value==1 then difficulty=button;break end end
   Check(difficulty~=nil,'a normal difficulty remains available')
   difficulty:Fire('OnClick','LeftButton');p.picker:Hide();p:ClosePicker()
   if choice.difficultyID then
    Check(f.G.filters.difficultyID==choice.difficultyID,'closing an already hidden draft restores its confirmed difficulty')
    Check(f.G.filters.groupKey==choice.groupKey,'closing an already hidden draft restores its confirmed single group')
    Check((f.G.filters.groupKeys and f.G.filters.groupKeys[20])==(choice.groupKeys and choice.groupKeys[20]),'closing an already hidden draft restores its confirmed collection')
   else Check(not p.refresh:IsEnabled(),'discarding the initial unconfirmed choice still waits for a search selection') end
   p:SelectCategory('seasonDungeon');difficulty:Fire('OnClick','LeftButton')
   f.A:Open('notes');f.A:Open('find')
   Check(f.G.filters.difficultyID==choice.difficultyID,'leaving cancels an unconfirmed difficulty')
   p:SelectCategory('seasonDungeon');difficulty:Fire('OnClick','LeftButton');f.U:Hide(true);f.A:Open('find')
   Check(f.G.filters.difficultyID==choice.difficultyID,'closing cancels an unconfirmed difficulty')
   f.U:Hide(true)
  end
 end
 -- Font preferences update existing text immediately. A closed activity
 -- picker has no display work until its existing OnShow refresh runs.
 local function PickerProjection(page)
  local out={page.picker:GetWidth(),page.picker:GetHeight(),page.picker.title:GetText(),page.activities:GetWidth(),page.activities:GetHeight(),tostring(page.activities.selectedKey)}
  for _,id in ipairs(page.activities.ids or {}) do out[#out+1]=tostring(id) end
  for _,button in ipairs(page.difficultyButtons) do if button:IsShown() then
   out[#out+1]=table.concat({tostring(button.value),button.label:GetText(),button:GetWidth(),button:GetHeight(),tostring(button.active)},':')
  end end
  for _,row in ipairs(page.activities.rows) do if row.key then
   local path,size,flags=row.title:GetFont()
   out[#out+1]=table.concat({tostring(row.key),row.title:GetText(),path,size,flags,row.title:GetWidth(),row.title:GetHeight(),tostring(row.multiSelect.value)},':')
  end end
  return table.concat(out,'|')
 end
 for _,locale in ipairs({'zhCN','enUS'}) do
  local function New(scale,font)
   return dofile('tests/ui_fixture.lua')(locale,{rememberFilters=true,find={category='seasonDungeon',categoryPrefs={seasonDungeon={groupKeys={[20]=true},difficultyID=8,selected=true}}}},{reduceMotion=true,fontScale=scale,font=font})
  end
  local f=New(100);local a,u,g=f.A,f.U,f.G
  a:Open('find');local p=u.pages.find;p:SelectCategory('seasonDungeon');p:ClosePicker()
  local refreshes,bindings,renders=0,0,0
  local refresh,set=p.RefreshPicker,p.activities.SetItems
  function p:RefreshPicker(...) refreshes=refreshes+1;return refresh(self,...) end
  function p.activities:SetItems(ids,render,...)
   bindings=bindings+1
   return set(self,ids,function(...) renders=renders+1;return render(...) end,...)
  end
  for i=1,20 do a:SetSetting('fontScale',i%2==1 and 130 or 100) end
  p:LayoutFont()
  Check(refreshes==0 and bindings==0 and renders==0,'font changes keep a closed picker idle on the current Find page')
  a:Open('settings');refreshes,bindings,renders=0,0,0
  for i=1,20 do a:SetSetting('fontScale',i%2==1 and 130 or 100) end
  Check(refreshes==0 and bindings==0 and renders==0 and p.activities.ids==nil,'font changes behind Settings preserve the released activity list')
  u:Hide(true);refreshes,bindings,renders=0,0,0
  a:SetSetting('fontScale',130);p:LayoutFont()
  Check(refreshes==0 and bindings==0 and renders==0 and p.activities.ids==nil,'font changes behind a hidden window do no picker display work')
  a:Open('find');p:SelectCategory('seasonDungeon')
  a:SetSetting('reduceMotion',false);u:Hide();refreshes,bindings,renders=0,0,0
  a:SetSetting('fontScale',100);p:LayoutFont()
  Check(u.hiding and refreshes==0 and bindings==0 and renders==0,'font changes do no picker display work during window exit')
  u.Motion:Tick(2);a:SetSetting('reduceMotion',true)
  a:Open('find');p:SelectCategory('seasonDungeon');refreshes,bindings,renders=0,0,0
  a:SetSetting('fontScale',130)
  Check(refreshes==1 and bindings==1 and renders>0,'an open picker immediately reflows after a font preference change')
  refreshes=0;p:LayoutFont();Check(refreshes==1,'the explicit font layout endpoint also refreshes a visible picker')
  -- Ordinary activity and score updates retain their original visible path.
  refreshes=0;g:Notify('activities');Check(refreshes>0 and p.picker:IsVisible(),'visible catalog updates still refresh the open picker')
  g.SeasonScores={Begin=function(self,callback) self.callback=callback end,End=function(self) self.callback=nil end,GetRecord=function() return {level=18,score=360} end}
  p:RefreshPicker();refreshes=0;g.SeasonScores.callback()
  Check(refreshes==1 and p.pickerScoreService==g.SeasonScores,'visible season-score updates keep refreshing the picker')
  p:ClosePicker();a:Open('settings');a:SetSetting('fontScale',70);a:SetSetting('fontScale',130)
  refreshes,bindings,renders=0,0,0;a:SetSetting('font','game')
  Check(refreshes==0 and bindings==0 and renders==0,'changing the typeface also preserves a released hidden picker')
  a:Open('find');p:SelectCategory('seasonDungeon')
  -- Clear the optional scores in both compared sessions; ordinary menu
  -- geometry/selection must equal a menu first created at the final font.
  g.SeasonScores=nil;p:RefreshPicker()
  local projection=PickerProjection(p)
  Check(g.filters.difficultyID==8 and g.filters.groupKeys[20],'deferred font work preserves the confirmed activity selection')
  u:Hide(true)
  local fresh=New(130,'game');fresh.A:Open('find');fresh.U.pages.find:SelectCategory('seasonDungeon')
  Check(PickerProjection(fresh.U.pages.find)==projection,'reopening after hidden font changes equals fresh content, selection, fonts and geometry')
  fresh.U:Hide(true)
 end
end
print('UI refresh costs: '..checks..' checks passed')
