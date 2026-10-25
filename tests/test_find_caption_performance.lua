-- Standalone: lua tests/test_find_caption_performance.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Fixture(locale)
 local f=dofile('tests/ui_fixture.lua')(locale,nil,{reduceMotion=true})
 f.U:Build();local p=f.U.pages.find;p:Build(f.U.content)
 local reads={0,0};local widths={0,0}
 for index,label in ipairs({p.autoJoin.label,p.applicationSettings.label}) do
  local get=label.GetUnboundedStringWidth
  label.GetUnboundedStringWidth=function(self,...)
   reads[index]=reads[index]+1
   return get(self,...)+widths[index]
  end
 end
 local function Reset() reads[1],reads[2]=0,0 end
 local function Settle()
  local callback=p.frame:GetScript('OnUpdate')
  if callback then callback(p.frame,.016) end
 end
 local function Correct(message)
  for index,label in ipairs({p.autoJoin.label,p.applicationSettings.label}) do
   local expected=math.ceil(label:GetUnboundedStringWidth())+2
   Check(label:GetWidth()==expected,message..' label '..index)
  end
 end
 return f,p,reads,widths,Reset,Settle,Correct
end
for _,locale in ipairs({'zhCN','enUS'}) do
 local f,p,reads,widths,reset,settle,correct=Fixture(locale)
 -- Model a nonzero native metric settling after hidden construction, then
 -- once more on the first displayed frame. Production native checks run separately.
 widths[1],widths[2]=13,17
 f.A:Open('find');correct('first-show metrics')
 widths[1],widths[2]=19,23
 settle();correct('displayed-frame settle')
 Check(p.frame:GetScript('OnUpdate')==nil,'settle driver stops after one frame')
 reset();for i=1,100 do f.G:Notify('results') end
 Check(reads[1]==0 and reads[2]==0,'stable result notifications reuse both caption measurements')
 for _,change in ipairs({function() f.A:SetSetting('fontScale',130) end,function() f.A:SetSetting('font','game') end}) do
  change();correct('changed font immediate metrics')
  widths[1],widths[2]=widths[1]+7,widths[2]+11
  settle();correct('changed font displayed-frame settle')
  Check(p.frame:GetScript('OnUpdate')==nil,'font settle has no continuing driver')
  reset();for i=1,100 do f.G:Notify('results') end
  Check(reads[1]==0 and reads[2]==0,'settled font metrics stay cached')
 end
 f.U:ApplyFont(f.A.Fonts:GetPath(),1)
 Check(p.frame:GetScript('OnUpdate')~=nil,'a visible font change schedules its settle')
 f.U:Hide(true)
 Check(p.frame:GetScript('OnUpdate')==nil,'leave cancels an unneeded settle')
 reset();for i=1,20 do f.G:Notify('results') end
 Check(reads[1]==0 and reads[2]==0,'closed pages do no caption work')
 f.A:Open('find');settle();correct('reopened metrics')
 f.A:Open('settings');f.U:ApplyFont(f.A.Fonts:GetPath(),1.3)
 Check(p.frame:GetScript('OnUpdate')==nil,'hidden font updates do not install a page driver')
 f.A:Open('find');settle();correct('font changed while hidden')
 f.U:Hide(true)
end
print('Find caption performance: '..checks..' checks passed')
