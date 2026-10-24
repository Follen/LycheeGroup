-- Notes workspace and history alignment; run: lua tests/test_notes_layout.lua
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Near(a,b,message) Check(math.abs(a-b)<.001,message) end
local function Position(region,root)
 if region==root then return 0,0 end
 local p={region:GetPoint()};local relative,anchor,x,y
 if type(p[2])=="table" then relative,anchor,x,y=p[2],p[3],p[4] or 0,p[5] or 0
 else relative,anchor,x,y=region:GetParent(),p[1],p[2] or 0,p[3] or 0 end
 local function Part(point,first,last) return point:find(first) and 0 or point:find(last) and 1 or .5 end
 local px,py=Position(relative,root)
 return px+relative:GetWidth()*Part(anchor,"LEFT","RIGHT")+x-region:GetWidth()*Part(p[1],"LEFT","RIGHT"),py+relative:GetHeight()*Part(anchor,"TOP","BOTTOM")-y-region:GetHeight()*Part(p[1],"TOP","BOTTOM")
end
for _,locale in ipairs({"zhCN","enUS"}) do
 local f=dofile("tests/ui_fixture.lua")(locale,nil,{reduceMotion=true})
 local A,U,G=f.A,f.U,f.G
 A.Notes:Merge({{name="Player",server="Home",class="WARRIOR",specID=71,type="positive",reason="A complete player note",timestamp=100}})
 G.GetHistory=function() return {{mapName="Dungeon activity",level=12,startedAt=10,completedAt=100,members={{name="Partner",realm="Away",class="WARRIOR",specID=71}}}} end
 A:Open("notes");local P=U.pages.notes
 for _,percent in ipairs({70,100,130}) do
  A:SetSetting("fontScale",percent)
  U:SetWindowSize(1,1)
  P:SelectTab("history")
  local row=P.historyList.rows[1]
  local _,titleY=Position(row.title,row);local _,iconY=Position(row.icon,row)
  Near(titleY+row.title:GetHeight()/2,iconY+row.icon:GetHeight()/2,"single-line history activity title and icon share a center")
  local dateX,dateY=Position(row.date,row)
  Near(dateY+row.date:GetHeight()/2,row:GetHeight()/2,"completed date shares the row center")
  U:SetText(row.meta,"Activity details");row.meta:Show();P:LayoutHistoryColumns(P.historyHeader)
  local _,metaY=Position(row.meta,row);_,titleY=Position(row.title,row);_,iconY=Position(row.icon,row)
  Near((titleY+metaY+row.meta:GetHeight())/2,iconY+row.icon:GetHeight()/2,"two-line history activity block and icon share a center")
  Check(metaY>=titleY+row.title:GetHeight()+3,"history subtitle clears the activity title")
  local nextX,nextY=Position(row.date,row);Near(dateX,nextX,"activity subtitle does not shift completed column");Near(nextY+row.date:GetHeight()/2,row:GetHeight()/2,"activity subtitle preserves date centering")
  row.meta:Hide();P:LayoutHistoryColumns(P.historyHeader)
  P:SelectTab("all")
  local actionX,actionY=Position(P.actions,P.main);local editorX,editorY=Position(P.editor,P.main)
  local _,titleY=Position(P.pageTitle,P.main)
  Check(P.countText==nil and not U.context.elementDefaults["notes.countText"],"the removed total has no visible object or catalog entry")
  Check(P.tabs.all.count:GetText()~="","sidebar category counts remain available")
  Near(actionX,editorX,"header actions align with the editor column")
  Near(P.actions:GetWidth(),P.editor:GetWidth(),"header actions use the editor column width")
  Near(actionY+P.actions:GetHeight()/2,titleY+P.pageTitle:GetHeight()/2,"header actions and page title share a vertical center")
  Near(editorY+P.editor:GetHeight(),P.main:GetHeight()-U.Theme.notesContentInset-U.Theme.notesEditorBottomInset,"the editor keeps its shortened height")
  local _,listY=Position(P.list,P.main)
  Near(listY+P.list:GetHeight(),P.main:GetHeight()-U.Theme.notesContentInset,"record list uses its complete column height")
  local previousRight
  for _,button in ipairs({P.importButton,P.exportButton,P.addButton}) do
   local x,y=Position(button,P.actions)
   Check(x>=0 and x+button:GetWidth()<=P.actions:GetWidth()+.001,("record tool fits the page header (%s %d: %.2f + %.2f <= %.2f)"):format(locale,percent,x,button:GetWidth(),P.actions:GetWidth()))
   Check(not previousRight or x>=previousRight+7.999,"record tools do not overlap")
   Near(y+button:GetHeight()/2,P.actions:GetHeight()/2,"record tools share the header center")
   previousRight=x+button:GetWidth()
  end
  Near(previousRight,P.actions:GetWidth(),"record tools align to the right boundary")
  local note=P.list.rows[1]
  local titleX,titleTop=Position(note.title,note);local _,reasonTop=Position(note.reason,note)
  Check(not note.meta:IsShown() and note.meta:GetText()=="","record list omits class and specialization")
  Check(reasonTop>=titleTop+note.title:GetHeight()+8,"record name and reason have a clear gap")
  local kindX,kindY=Position(note.kind,note);local dateX,dateY=Position(note.date,note)
  Near(kindX+note.kind:GetWidth(),note:GetWidth()-24,"record type keeps a 24-unit right inset")
  Near(dateX+note.date:GetWidth(),note:GetWidth()-24,"record date keeps a 24-unit right inset")
  Near(dateY+note.date:GetHeight()/2,reasonTop+note.reason:GetHeight()/2,"record date aligns with the reason line")
  local glyph=note.kindIcons.positive;local glyphX=Position(glyph,note)
  Check(kindX+note.kind:GetWidth()-note.kind:GetStringWidth()-glyphX-glyph:GetWidth()>=7.999,"record type icon clears its label by eight units")
  Check(note.kindIcons.neutral:GetWidth()>note.kindIcons.positive:GetWidth(),"neutral artwork is larger to balance its lighter drawing")
  for _,kind in ipairs({"neutral","caution","positive"}) do
   Check(A.Notes:Edit("Player-Home","A complete player note",{type=kind}),"the current record can change its displayed type")
   local glyph=note.kindIcons[kind];local x,y=Position(glyph,note)
   local textX,textY=Position(note.kind,note)
   Near(textX+note.kind:GetWidth()-note.kind:GetStringWidth()-x-glyph:GetWidth(),8,"each type icon has the same gap after rendering and font changes")
   Near(y+glyph:GetHeight()/2,textY+note.kind:GetHeight()/2,"each type icon is vertically centered on its label")
  end
  if percent==100 then Near(P.list.rowHeight,92,"normal-size records use the two-line row height") end
  Check(reasonTop+note.reason:GetHeight()+12<=note:GetHeight()+.001,"record keeps bottom padding at every font size")
  Near(P.list.rowHeight,note:GetHeight(),"record rows retain the continuous list surface")
  P:OpenEdit("Player-Home")
  local _,reasonY=Position(P.eReason,P.editor);local _,saveY=Position(P.eSave,P.editor)
  Check(reasonY+P.eReason:GetHeight()+16<=saveY,"editor reason clears the action row")
  Check(P.eIdentity:GetHeight()>P.eRealm:GetHeight(),"editor identity leads its secondary text")
  for _,mode in ipairs({"edit","add"}) do
   if mode=="add" then P:OpenAdd() end
   P:SetEditorStatus("A validation message\nAdditional validation detail","error")
   local _,statusY=Position(P.eStatus,P.editor);local _,buttonY=Position(P.eSave,P.editor)
   Check(statusY+P.eStatus:GetHeight()+12<=buttonY+.001,("%s status clears footer (%s %d: %.2f+%.2f+12 <= %.2f)"):format(mode,locale,percent,statusY,P.eStatus:GetHeight(),buttonY))
   local _,reasonTop=Position(P.eReason,P.editor)
   if mode=="edit" then
    local _,dateTop=Position(P.eDate,P.editor)
    Check(dateTop>=reasonTop+P.eReason:GetHeight()+7.999,"recorded date clears the shortened reason input")
    Check(statusY>=dateTop+P.eDate:GetHeight()+7.999,"validation feedback clears the recorded date")
   else Check(statusY>=reasonTop+P.eReason:GetHeight()+7.999,"new-note feedback clears the shortened reason input") end
   for _,pair in ipairs({{P.classLabel,P.classChoice},{P.typeLabel,P.typeSwitch},{P.eReasonLabel,P.eReason}}) do
    local _,labelY=Position(pair[1],P.editor);local _,fieldY=Position(pair[2],P.editor)
    Check(fieldY>=labelY+pair[1]:GetHeight()+7.999,mode.." field follows its measured label")
   end
   P:SetEditorStatus("")
  end
 end
 local records={};for index=1,30 do records[index]={name="Entry"..index,server="Home",class="WARRIOR",type="neutral",reason="A pooled note",timestamp=index} end
 A.Notes:Merge(records);P:SelectTab("all");P.list:SetPixelOffset(100000,false)
 for _,row in ipairs(P.list.rows) do if row.key then
  local _,titleY=Position(row.title,row);local _,reasonY=Position(row.reason,row)
  Check(not row.meta:IsShown() and row.meta:GetText()=="" and reasonY>=titleY+row.title:GetHeight()+8,"reused and newly created rows keep the same two-line layout")
 end end
 P:SelectTab("history");P:OpenRun(P.historyList.ids[1])
 local member=P.historyModal.list.rows[1]
 local _,titleY=Position(member.title,member);local _,metaY=Position(member.meta,member);local _,iconY=Position(member.icon,member)
 Near((titleY+metaY+member.meta:GetHeight())/2,iconY+member.icon:GetHeight()/2,"history member identity remains centered as a pair")
 P.historyModal:Close();U:Hide(true)
end
print("Notes workspace: "..checks.." checks passed")
