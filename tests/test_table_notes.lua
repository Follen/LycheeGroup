-- Focused table integration checks; run: lua tests/test_table_notes.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Near(a,b,message) Check(math.abs(a-b)<.001,message) end
local function Order(list,expected,message)
 Check(#list.ids==#expected,message.." count")
 for i,key in ipairs(expected) do Check(list.ids[i]==key,message.." item "..i) end
end
local function Click(header,key)
 for _,button in ipairs(header.buttons) do
  if button.definition.key==key then button:Fire("OnClick","LeftButton");return end
 end
 error("missing header "..key)
end
local function X(region) local point={region:GetPoint()};return point[#point-1] end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale)
 local A,U,G,S=f.A,f.U,f.G,f.S
 A:SetSetting("reduceMotion",true)
 A.Notes:Merge({
  {name="Fresh",server="Home",timestamp=300,reason="a complete reason across both columns",type="positive"},
  {name="Old",server="Home",timestamp=100,reason="old"},
  {name="Same",server="Home",timestamp=100,reason="same"},
  {name="Unknown",server="Home",timestamp=0,reason="unknown"},
 })
 local members={{name="Partner",realm="Away",class="WARRIOR",specID=71}}
 local runs={
  {id=1,mapName="Latest dungeon",level=12,startedAt=240,completedAt=300,members=members},
  {id=2,mapName="Old dungeon",level=5,startedAt=70,completedAt=100,members=members},
  {id=3,mapName="Middle dungeon",level=5,startedAt=170,completedAt=200,members=members},
  {id=4,mapName="Unknown dungeon",members=members},
 }
 G.GetHistory=function() return runs end
 A:Open("notes");local notes=U.pages.notes
 Order(notes.list,{"Fresh-Home","Old-Home","Same-Home","Unknown-Home"},"notes default newest first")
 Click(notes.noteHeader,"timestamp")
 Order(notes.list,{"Old-Home","Same-Home","Fresh-Home","Unknown-Home"},"notes ascending, stable ties and unknown last")
 Click(notes.noteHeader,"timestamp")
 Order(notes.list,{"Fresh-Home","Old-Home","Same-Home","Unknown-Home"},"notes descending")
 Check(notes.list.rows[1].reason:GetWidth()>notes.noteHeader.columns.player.width,"note reason still spans the two data columns")
 notes:SelectTab("history")
 Check(not notes.countText:IsShown(),"the player-note count is hidden on the history tab")
 Order(notes.historyList,{1,3,2,4},"history default completed time")
 Click(notes.historyHeader,"level");Order(notes.historyList,{2,3,1,4},"history level ascending")
 Click(notes.historyHeader,"level");Order(notes.historyList,{1,2,3,4},"history level descending")
 Click(notes.historyHeader,"duration");Order(notes.historyList,{2,3,1,4},"history duration ascending")
 Click(notes.historyHeader,"duration");Order(notes.historyList,{1,2,3,4},"history duration descending")
 Click(notes.historyHeader,"completed");Order(notes.historyList,{2,3,1,4},"history completed ascending")
 Click(notes.historyHeader,"completed");Order(notes.historyList,{1,3,2,4},"history completed descending")
 for i,run in ipairs(runs) do Check(run.id==i,"sorting never mutates the history source array") end
 Check(notes.historyList.rows[1].level:GetText()=="+12","history has a distinct numeric level cell")
 Check(notes.historyList.rows[1].duration:GetText()=="1:00","history has a distinct duration cell")
 notes:OpenRun(notes.historyList.ids[1]);local modal=notes.historyModal
 Check(modal.list.rows[1].title:GetText()=="Partner-Away","sorted history opens the matching original run")
 local oldMouse=IsMouseButtonDown;IsMouseButtonDown=function() return true end
 local function Drag(header,delta)
  local width=header.columns[header.buttons[1].definition.key].width
  header.handles[1]:Fire("OnMouseDown","LeftButton")
  S.cursorX=S.cursorX+delta*header:GetEffectiveScale();header:UpdateDrag()
  Check(math.abs(header.columns[header.buttons[1].definition.key].width-width)>.1,"drag updates the real page columns")
  header.handles[1]:Fire("OnMouseUp","LeftButton")
  Check(header.state.widths~=nil,"dragged proportions are saved")
 end
 Drag(modal.header,-30)
 local modalRow=modal.list.rows[1]
 Near(modalRow.title:GetWidth(),modal.header.columns.player.width-62,"history member width follows the header")
 Near(X(modalRow.action),modal.header.columns.actions.x+6,"history action follows its column")
 modal:Close();notes:SelectTab("all");Drag(notes.noteHeader,-24)
 Near(notes.list.rows[1].title:GetWidth(),notes.noteHeader.columns.player.width-56,"note name width follows the dragged header")
 local noteRatio=notes.noteHeader.state.widths.player
 notes:SelectTab("history");Drag(notes.historyHeader,-24)
 Near(notes.historyList.rows[1].title:GetWidth(),notes.historyHeader.columns.activity.width-66,"activity width follows the dragged header")
 notes.historyHeader:StartDrag(1);notes:SelectTab("all")
 Check(notes.historyHeader.drag==nil and notes.historyHeader:GetScript("OnUpdate")==nil,"switching tabs stops column dragging")
 A:Open("settings",{section="blocks"});local settings=U.pages.settings
 G.Results:BlockTitle("Blocked group","Blocked-Away")
 Check(settings.blocksList.rows[1].title:GetText()=="Blocked","the block list still uses real leader identities")
 Drag(settings.blocksHeader,-30)
 local blockRow=settings.blocksList.rows[1]
 Near(X(blockRow.meta),settings.blocksHeader.columns.realm.x+6,"blocked realm follows its header")
 for _,percent in ipairs({70,100,130}) do
  A:SetSetting("fontScale",percent)
  local columns=settings.blocksHeader.columns
  Check(X(blockRow.title)+blockRow.title:GetWidth()<=columns.realm.x,"blocked name stays before the realm column")
  Check(X(blockRow.meta)+blockRow.meta:GetWidth()<=columns.actions.x,"blocked realm stays before actions")
  Check(X(blockRow.remove)>=columns.actions.x,"blocked action stays within its column")
 end
 settings.blocksHeader:StartDrag(1);settings:SelectSection("general")
 Check(settings.blocksHeader.drag==nil and settings.blocksHeader:GetScript("OnUpdate")==nil,"leaving blocks stops column dragging")
 A:Open("notes");Near(notes.noteHeader.state.widths.player,noteRatio,"reopening keeps saved note widths")
 for _,percent in ipairs({70,100,130}) do
  A:SetSetting("fontScale",percent);U:SetWindowSize(1200,780)
  notes:SelectTab("history")
  local columns=notes.historyHeader.columns
  Check(columns.teammates.width>=147-.001,"five teammate icons retain their required column width")
  Check(columns.completed.x+columns.completed.width<=notes.historyList.rows[1]:GetWidth()-32+.001,"history columns leave the detail affordance clear")
  notes:OpenRun(1);modal=notes.historyModal
  Check(X(modal.list.rows[1].action)>=modal.header.columns.actions.x,"member actions remain in their column after font changes")
  modal:Close()
 end
 IsMouseButtonDown=oldMouse
 local saved=A.charPrefs
 U:Hide(true)
 local reloaded=dofile("tests/ui_fixture.lua")(locale,saved)
 reloaded.A:Open("notes")
 Near(reloaded.U.pages.notes.noteHeader.state.widths.player,noteRatio,"saved column proportions restore in a new session")
 Check(reloaded.U.pages.notes.noteHeader.state.sortKey=="timestamp" and reloaded.U.pages.notes.noteHeader.state.descending,"the saved numeric sort restores in a new session")
 reloaded.U:Hide(true)
end
print("Notes/settings tables: "..checks.." checks passed")
