-- Composite page refreshes finish one derived layout using current size/font.
local f=dofile('tests/ui_fixture.lua')('zhCN')
local A,U=f.A,f.U
A:SetSetting('reduceMotion',true)
for _,name in ipairs({'create','notes','settings'})do U:Show(name)end
local count=0
local function check(value,message) count=count+1;assert(value,message)end
local width,height=U.content:GetWidth(),U.content:GetHeight()
local function Calls(page,method,run)
 local original,n=page[method],0
 page[method]=function(self,...) n=n+1;return original(self,...)end
 run();page[method]=original
 return n
end
local notes,settings,create=U.pages.notes,U.pages.settings,U.pages.create
check(#notes.list.rows==2 and #notes.historyList.rows==2,'Empty Notes lists retain two spare rows and grow when records arrive')
check(Calls(notes,'LayoutRows',function()notes:ReflowMetrics(width,height)end)==1,'Notes composite measures rows once')
check(Calls(settings,'LayoutRows',function()settings:ReflowMetrics(width,height)end)==1,'Settings composite measures rows once')
check(Calls(create,'LayoutRequirements',function()create:ReflowMetrics(width,height)end)==1,'Create composite measures requirements once')
check(Calls(create,'LayoutActivityChoice',function()create:ReflowMetrics(width,height)end)==1,'Create composite measures activity choice once')
check(Calls(create,'LayoutApplicantColumns',function()create:ReflowMetrics(width,height)end)==1,'Create composite paints applicant columns once')
check(Calls(create,'LayoutRosterCard',function()create:ReflowMetrics(width,height)end)==1,'Create composite positions the roster card once')
for _,scale in ipairs({1.3,1})do
 U:ApplyFont(A.Fonts:GetPath(),scale)
 for _,page in ipairs({notes,settings,create})do
  page:ReflowMetrics(width,height)
 end
 check(notes.noteHeader:GetWidth()>0 and notes.editor:GetWidth()>0,'Notes current font/size produces usable header and editor geometry')
 check(settings.controls.font.widget:GetWidth()>0 and settings.controls.font.frame:GetHeight()>=settings.controls.font.frame.label:GetHeight(),'Settings current font fits its measured row')
 check(create.minimumRequirementsTop>=356 and create.descriptionShell:GetWidth()==create.titleShell:GetWidth(),'Create final form uses the current font and content width')
end
check(Calls(notes,'LayoutRows',function()notes:LayoutSize(width-100,height)end)==1,'Standalone Notes resize still measures rows')
check(Calls(settings,'LayoutRows',function()U:ApplyFont(A.Fonts:GetPath(),1.3)end)==1,'Font update synchronizes and measures Settings once')
check(Calls(create,'LayoutApplicantColumns',function()create:LayoutSize(width-100,height)end)==1,'Standalone Create resize updates applicant column definitions and widths once')
-- Exercise the public routes, including the common settings notification.
dofile('addon/LycheeGroup/Floating.lua');dofile('addon/LycheeGroup/API.lua')
local api=A.API.Configuration
check(Calls(settings,'Sync',function()
 assert(api:Set({['settings.fontScale']=130,['settings.language']='enUS',['settings.rememberFilters']=false}))
end)==1,'A mixed public font/settings batch synchronizes Settings once')
check(settings.controls.fontScale.widget.value==130 and settings.controls.language.widget.value=='enUS' and settings.controls.rememberFilters.widget.value==false,'The font batch synchronizes every final control value')
assert(api:Set({['settings.fontScale']=100,['settings.language']='auto',['settings.rememberFilters']=true}))
for _,name in ipairs({'find','create','notes','settings'})do assert(A:Open(name))end
local function Navigate()for _,name in ipairs({'find','create','notes','settings'})do assert(A:Open(name))end end
check(Calls(notes,'LayoutRows',Navigate)==1,'Public navigation measures Notes once after entering')
check(Calls(settings,'LayoutRows',Navigate)==1,'Public navigation synchronizes and measures Settings once')
check(Calls(create,'LayoutRosterCard',Navigate)==1,'Public navigation positions the final Create roster once')
settings:SelectSection('browse')
local toggle=settings.controls.relations.widget
local previousValue=toggle.value
check(Calls(settings,'Sync',function()toggle:Fire('OnClick','LeftButton')end)==1,'A real settings check click synchronizes the changed setting once')
check(toggle.value==not previousValue and A:GetSetting('relations')==toggle.value,'The settings check click commits its value and keeps its control current')
local masked=settings.controls.rememberFilters.widget
check(Calls(settings,'Sync',function()masked:Fire('OnClick','LeftButton')end)==1,'A session-masked settings click still restores the effective value once')
check(masked.value==true and A:GetSetting('rememberFilters')==true,'A higher-priority session setting remains the displayed effective value')
local previous=notes.editor:GetWidth()
assert(api:Set({['layout.window.width']=U.windowWidth-80}))
assert(A:Open('notes'))
check(notes.editor:GetWidth()~=previous,'Entering a retained page applies a changed window width')
check(notes.list.ids~=nil,'Entering a retained Notes page still refreshes its records')
assert(A:Open('create'))
check(create.unsub~=nil and create.roster~=nil,'Entering Create still attaches business updates and its current roster')
assert(A:Open('settings'))
check(create.unsub==nil and create.roster==nil,'Leaving Create still detaches business updates and releases the roster')
-- A font change can raise the window minimum and change every page's final size.
assert(api:Set({['settings.fontScale']=100,['layout.window.width']=1200,['layout.window.height']=760}))
assert(A:Open('settings'))
local beforeWidth,beforeHeight=U.windowWidth,U.windowHeight
local fontCalls={}
for page,method in pairs({notes='LayoutRows',settings='LayoutRows',create='LayoutRequirements'})do
 local owner=U.pages[page];local original=owner[method]
 fontCalls[page]={n=0,owner=owner,method=method,original=original}
 local sample=fontCalls[page]
 owner[method]=function(self,...)sample.n=sample.n+1;return original(self,...)end
end
assert(api:Set({['settings.fontScale']=130}))
for page,sample in pairs(fontCalls)do
 sample.owner[sample.method]=sample.original
 check(sample.n==1,'Font/window minimum change performs one final '..page..' layout')
end
check(U.windowWidth>beforeWidth and U.windowHeight>beforeHeight,'The font setting still grows a small window to its required minimum')
for _,name in ipairs({'find','create','notes','settings'})do
 local page=U.pages[name]
 check(page.enteredWidth==U.content:GetWidth() and page.enteredHeight==U.content:GetHeight(),'The completed font layout records current dimensions for '..name)
end
check(Calls(U,'LayoutWindow',Navigate)==0,'Navigation after font resizing reuses each page at its completed dimensions')
check(Calls(settings,'LayoutRows',function()assert(api:Set({['settings.fontScale']=100}))end)==1,'Restoring a smaller font and window measures Settings once')
assert(A:Open('notes'))
for _,mode in ipairs({'import','export'})do
 notes:OpenTransfer(mode)
 local modal,box=notes.transferModal,notes.tBox
 local hint=notes.tHint:GetText()
 box.box:SetText('transfer font round trip')
 U:SetText(notes.tStatus,'Transfer status')
 local function TransferGaps()
  for _,entry in ipairs({{notes.tLabel,notes.tHint,U.Theme.notesTLabelTopleftY},{notes.tBox,notes.tLabel,U.Theme.notesTBoxTopleftY},{notes.tStatus,notes.tBox,U.Theme.notesTStatusTopleftY}})do
   local point,relative,relativePoint,x,y=entry[1]:GetPoint()
   check(point=='TOPLEFT' and relative==entry[2] and relativePoint=='BOTTOMLEFT' and x==0 and y==entry[3],mode..' transfer retains its spacing below the preceding content')
  end
 end
 TransferGaps()
 for _,scale in ipairs({130,100})do
  assert(api:Set({['settings.fontScale']=scale}))
  TransferGaps()
  check(notes.tHint:GetText()==hint and box.box:GetText()=='transfer font round trip' and notes.tStatus:GetText()=='Transfer status',mode..' font changes preserve the active transfer text')
 end
 notes:CloseTransfer()
 check(not modal.frame:IsShown() and box.box:GetText()=='' and notes.tStatus:GetText()=='',mode..' transfer close releases the temporary text')
 notes:OpenTransfer(mode)
 check(notes.transferModal==modal and notes.tBox==box and modal.frame:IsShown(),mode..' transfer reopens the retained modal and input')
 TransferGaps()
 notes:CloseTransfer()
end
U:Hide(true)
print('Product metric layout: '..count..' checks passed')
