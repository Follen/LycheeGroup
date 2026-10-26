-- Real Settings menu: stable work, startup typography and pooled click identity.
local Fixture=dofile("tests/ui_fixture.lua")
local function Open(theme,locale)
 local f=Fixture(locale or "enUS",nil,{reduceMotion=true},theme)
 f.A:Open("settings",{section="general"})
 f.P=f.U.pages.settings;f.choice=f.P.controls.applicantAlertSound.widget
 f.A:SetSetting("applicantAlertSound","voice")
 f.choice:Fire("OnClick","LeftButton")
 f.U.context:GetMenu().list.clip.mouseOver=true
 return f,f.U.context:GetMenu()
end
local function Row(menu,value)
 for _,row in ipairs(menu.list.rows) do
  local entry=menu.items[row.key]
  if entry and entry.value==value then return row end
 end
end
do
 local f,menu=Open()
 local writes,shows=0,0
 for _,row in ipairs(menu.list.rows) do
  local setWidth=row.title.SetWidth
  row.title.SetWidth=function(self,...) writes=writes+1;return setWidth(self,...) end
  local button=row.applicantSoundPreview
  if button then
   local show=button.Show
   button.Show=function(self,...) shows=shows+1;return show(self,...) end
  end
 end
 local nodes=#f.S.nodes
 for _=1,100 do menu.list:Refresh(true) end
 T.eq(writes,0,"stable preview rows do not write the same text width")
 T.eq(shows,0,"stable preview rows do not repeatedly show buttons")
 T.eq(#f.S.nodes,nodes,"stable sound menu allocates no controls")
 T.eq(f.base.PendingTimers(),0)
 f.U:CloseMenu()
 f.P.controls.language.widget:Fire("OnClick","LeftButton")
 local sync,hide=f.P.SyncSoundMenuButtons,f.P.HideSoundMenuButtons
 local unrelated=0
 f.P.SyncSoundMenuButtons=function(self,...) unrelated=unrelated+1;return sync(self,...) end
 f.P.HideSoundMenuButtons=function(self,...) unrelated=unrelated+1;return hide(self,...) end
 for _=1,100 do menu.list:Refresh(true) end
 f.U:CloseMenu()
 T.eq(unrelated,0,"other menus skip preview synchronization and cleanup")
 f.U:Hide(true)
end
for _,locale in ipairs({"zhCN","enUS"}) do
 for _,height in ipairs({320,40}) do
  local theme={schema=1,id="sound.menu.font",revision=1,appearance={main={
   tokens={menuMaxHeight=height},elements={["menu.row"]={base={label={fontSize=48}}}},
  }}}
  local f,menu=Open(theme,locale)
  T.eq(f.A.RuntimeTheme.error,nil)
  for _,value in ipairs({"voice","native"}) do
   if height==40 then menu.list:SetPixelOffset(value=="voice" and 0 or menu.list.rowHeight,false) end
   local row=Row(menu,value)
   T.ok(row and row.applicantSoundPreview:IsShown(),"the visible sound has a preview")
   T.ok(row.title:GetStringWidth()<=row.title:GetWidth()+.01,"sound menu fits its actual startup font, including scrolling")
  end
  f.U:Hide(true)
 end
end
do
 local theme={schema=1,id="sound.menu.scroll",revision=1,appearance={main={tokens={menuMaxHeight=40}}}}
 local f,menu=Open(theme)
 local played={}
 f.G.Alerts={Preview=function(_,choice) played[#played+1]=choice end,StopPreview=function() end}
 local row=Row(menu,"voice");local button=row.applicantSoundPreview
 button:Fire("OnMouseDown","LeftButton")
 menu.list:SetPixelOffset(menu.list.rowHeight,false)
 T.eq(menu.items[row.key].value,"native","the test reuses the pressed physical row")
 button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(#played,0,"a recycled preview cannot complete the previous press")
 button:Fire("OnMouseDown","LeftButton");button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(played[1],"native","a fresh press previews the new row")
 T.eq(f.A:GetSetting("applicantAlertSound"),"voice","preview does not change the saved choice")
 -- Move the partially visible second row out of the hit area without rebinding it.
 menu.list:SetPixelOffset(menu.list.rowHeight/2,false)
 row=Row(menu,"native");button=row.applicantSoundPreview
 button:Fire("OnMouseDown","LeftButton")
 menu.list:SetPixelOffset(0,false)
 T.ok(not row:IsMouseEnabled(),"the row is clipped out of the full hit area")
 T.ok(not button:IsShown(),"a clipped row has no active preview button")
 menu.list:SetPixelOffset(menu.list.rowHeight/2,false)
 button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(#played,1,"leaving and returning to the hit area cancels the old press")
 menu.list.clip.mouseOver=false
 button:Fire("OnMouseDown","LeftButton");button:Fire("OnMouseUp","LeftButton");button:Fire("OnClick","LeftButton")
 T.eq(#played,1,"the hidden part of a clipped row cannot preview outside the viewport")
 f.U:Hide(true)
end
