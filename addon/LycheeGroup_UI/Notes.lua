-- 荔枝笔记页:名单、编辑、导入导出。
-- v4 固定侧栏、记录列表与编辑区，共用真实记录及历史服务。
local A = _G.LycheeGroup
local UI = A.UI
local T, L = UI.Theme, UI.L
local C = UI.C

local P = {}
UI.pages.notes = P

local WIDTH, HEIGHT = T.contentWidth, T.contentHeight
local LEFT = T.notesMainX + T.notesContentInset
local MAIN_WIDTH = WIDTH - T.notesMainX
local BODY_WIDTH = MAIN_WIDTH - T.notesContentInset * 2
local DRAWER_W = BODY_WIDTH - T.notesListWidth - T.notesColumnGap
local EDITOR_X = LEFT + T.notesListWidth + T.notesColumnGap
local CARD_WIDTH=T.notesListWidth-C.listRightInset
local zh=A:GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
local NOTE_TYPES={{key="positive",label=S("推荐","Positive")},{key="neutral",label=S("中性","Neutral")},{key="caution",label=S("拉黑","Blocked")}}
local LIST_HEIGHT = HEIGHT - T.notesWorkTop - 32 - T.notesContentInset
local function SizeRows(list,height)
 list:SetRowHeight(height,height)
end
local function LayoutHistoryRows(list,x)
 local height=80
 for _,row in ipairs(list.rows) do
  local detail=row.meta:IsShown() and row.meta:GetText()~=""
  height=math.max(height,math.ceil(row.title:GetHeight()+(detail and row.meta:GetHeight()+4 or 0)+24))
 end
 SizeRows(list,height)
 for _,row in ipairs(list.rows) do
  local detail=row.meta:IsShown() and row.meta:GetText()~=""
  local top=(height-row.title:GetHeight()-(detail and row.meta:GetHeight()+4 or 0))/2
  row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",row,"TOPLEFT",x,-top)
  row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",row,"TOPLEFT",x,-top-row.title:GetHeight()-4)
 end
end
local EDITOR_HEIGHT = math.min(T.notesEditorMaxHeight,HEIGHT - T.notesEditorTop - T.notesContentInset-T.notesEditorBottomInset)

local state = {
	search = "",
	editKey = nil,
	draft = nil, -- {name,realm,reason,unit} 或空表(手动添加)
	unsub = nil,
	revision = 0,
}

local function SortNumbers(ids,value,descending)
 table.sort(ids,function(a,b)
  local av,bv=value(a),value(b)
  if av==bv then return a<b end
  if av==nil then return false end
  if bv==nil then return true end
  return descending and av>bv or not descending and av<bv
 end)
end
local function RunDuration(run)
 return run.completedAt and run.startedAt and math.max(0,run.completedAt-run.startedAt) or nil
end

local function LayoutNoteColumn(row,columns)
 local player,date=columns.player,columns.timestamp
  local reasonTop=math.max(T.notesRowReasonTop,-T.notesRowTitleTopleftY+row.title:GetHeight()+8)
  local iconTop=(-T.notesRowTitleTopleftY+reasonTop+row.reason:GetHeight()-row.icon:GetHeight())/2
  row.icon:ClearAllPoints();row.icon:SetPoint("TOPLEFT",player.x+12,-iconTop)
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT",player.x+50,"notesRowTitleTopleftY");row.title:SetWidth(player.width-56)
  row.meta:Hide()
  local detailWidth=math.max(0,date.width-6-T.notesRowDetailRightInset)
  row.kind:ClearAllPoints();row.kind:SetPoint("TOPLEFT",date.x+6,T.notesRowTitleTopleftY-(row.title:GetHeight()-row.kind:GetHeight())/2);row.kind:SetWidth(detailWidth)
  row.date:ClearAllPoints();row.date:SetPoint("TOPLEFT",date.x+6,-reasonTop-(row.reason:GetHeight()-row.date:GetHeight())/2);row.date:SetWidth(detailWidth)
  row.reason:ClearAllPoints();row.reason:SetPoint("TOPLEFT",player.x+50,-reasonTop);row.reason:SetWidth(player.width-56)
end
function P:LayoutNoteColumns(header)
 if not self.list then return end
 for _,row in ipairs(self.list.rows) do LayoutNoteColumn(row,header.columns) end
 self:LayoutNoteRows()
end
local function LayoutHistoryColumn(row,col)
  row.icon:ClearAllPoints();row.icon:SetPoint("LEFT",col.activity.x+12,0)
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT",col.activity.x+60,"notesRowTitleTopleftY2");row.title:SetWidth(col.activity.width-66)
  row.meta:SetWidth(col.activity.width-66)
  row.level:ClearAllPoints();row.level:SetPoint("LEFT",col.level.x+6,0);row.level:SetWidth(col.level.width-12)
  row.duration:ClearAllPoints();row.duration:SetPoint("LEFT",col.duration.x+6,0);row.duration:SetWidth(col.duration.width-12)
  row.roster:ClearAllPoints();row.roster:SetPoint("LEFT",col.teammates.x+6,0)
  row.date:ClearAllPoints();row.date:SetPoint("LEFT",col.completed.x+6,0);row.date:SetWidth(col.completed.width-12)
end
function P:LayoutHistoryColumns(header)
 if not self.historyList then return end
 local col=header.columns
 for _,row in ipairs(self.historyList.rows) do LayoutHistoryColumn(row,col) end
 LayoutHistoryRows(self.historyList,col.activity.x+60)
end
function P:LayoutHistoryMemberColumns(header)
 local modal=self.historyModal
 if not modal or not modal.list then return end
 local player,actions=header.columns.player,header.columns.actions
 for _,row in ipairs(modal.list.rows) do
  row.icon:ClearAllPoints();row.icon:SetPoint("LEFT",player.x+12,0)
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT",player.x+56,"notesRowTitleTopleftY2");row.title:SetWidth(player.width-62)
  row.meta:SetWidth(player.width-62)
  row.action:ClearAllPoints();row.action:SetPoint("LEFT",actions.x+6,0);row.action:SetWidth(actions.width-12)
 end
 LayoutHistoryRows(modal.list,player.x+56)
end

function P:BindTableStates()
 self.noteTableState=UI:GetTablePrefs("notesRecords")
 self.noteHeader:SetState(self.noteTableState)
 if UI.preview and not self.noteTableState.sortKey then self.noteHeader:SetSort("timestamp",true) end
 self.historyTableState=UI:GetTablePrefs("notesHistory")
 self.historyHeader:SetState(self.historyTableState)
 if UI.preview and not self.historyTableState.sortKey then self.historyHeader:SetSort("completed",true) end
 if self.historyModal then self.historyModal.header:SetState(UI:GetTablePrefs("notesHistoryMembers")) end
 self:LayoutRows()
end

local function CancelPending()
	state.revision = state.revision + 1
	local cancel = state.cancel
	state.cancel = nil
	if cancel then cancel() end
end
local function DraftChanged()
 if not state.cancel then return end
 CancelPending()
 P:SetEditorStatus("")
end

local function Subscribe()
	if state.unsub or not (A.Notes and A.Notes.Subscribe) then return end
	state.unsub = A.Notes:Subscribe(function(kind, key)
		if not P.frame or not P.frame:IsVisible() then return end
		P:RefreshCounts()
		if state.tab~="history" then
			if kind == "edit" and state.search == "" and (state.tab==nil or state.tab=="all") then
				P.list:RefreshKeys({key}, function(id, changed) return id == changed end)
			else
				P:RefreshList()
			end
		end
		local currentChanged = key == state.editKey
		if kind == "merge" then
			for _, changed in ipairs(key) do if changed == state.editKey then currentChanged = true; break end end
		end
		if state.editKey ~= nil and currentChanged then
			-- 当前编辑的记录被外部编辑或删除:编辑区跟随真实状态。
			if A.Notes:Find(state.editKey) then
				P:OpenEdit(state.editKey)
			else
				P:CloseEditor()
			end
		end
	end)
end

local function RenderNote(row,key)
 local r=A.Notes:Find(key);if not r then return end
 local identity=A.Notes.PlayerInfo.ResolveRecord(r)
 UI:SetMemberIcon(row.icon,identity);UI:SetText(row.title,r.name.."-"..r.server);row.title:SetTextColor(UI:ClassColor(identity.class))
 UI:SetText(row.meta,"");row.meta:Hide()
 UI:SetText(row.reason,r.reason~="" and r.reason or L.noReason)
 local label;for _,entry in ipairs(NOTE_TYPES) do if r.type==entry.key then label=entry.label end end
 UI:SetText(row.kind,label);UI:Color(row.kind,r.type=="positive" and "good" or r.type=="caution" and "warning" or "muted")
 for kind,glyph in pairs(row.kindIcons) do glyph:SetShown(kind==r.type);if kind==r.type then glyph:ClearAllPoints();glyph:SetPoint("RIGHT",row.kind,"RIGHT",-row.kind:GetStringWidth()-T.notesRowKindGap,0) end end
 UI:SetText(row.date,UI:DateText(r.timestamp))
end

-- ---------------------------------------------------------------- 构建

function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(T.notesSidebarWidth,HEIGHT);rail:SetPoint("TOPLEFT");self.rail=rail
 self.tabs={};self.tabSelection=C.Selection(rail,{radius=8,mark=true})
 for i,entry in ipairs({{"all",S("全部记录","All notes")},{"positive",S("推荐","Positive")},{"neutral",S("中性","Neutral")},{"caution",S("拉黑","Blocked")},{"history",S("历史队友","History")}}) do
  local button=C.Button(rail,entry[2],T.notesSidebarWidth,function() P:SelectTab(entry[1]) end,{height=60,radius=8,fontSize=16,lineHeight=22,selectionFill=false,recipe="navigationText"});button:SetTextColors("muted","text","onSecondaryContainer");button:SetFrameLevel(self.tabSelection:GetFrameLevel()+1)
  button.order=i;button.tabY=-12-(i-1)*64-(i==5 and 20 or 0);button:SetPoint("TOPLEFT",0,button.tabY);button.label:ClearAllPoints();C.SetPoint(button.label,"LEFT",button.label:GetParent(),"LEFT","notesButtonLabelLeftX",0);button.label:SetWidth(T.notesButtonLabelWidth);button.label:SetWordWrap(false);C.SetLineHeight(button.label,22,true)
  local glyph=entry[1]=="all" and "friend" or entry[1]=="positive" and "heart" or entry[1]=="caution" and "caution" or entry[1]=="history" and "history" or "book"
  button.glyph=UI:CreateGlyph(button,glyph,T.notesButtonGlyphWidth);C.Box(button.glyph,{width="notesButtonGlyphWidth",height="notesButtonGlyphHeight"});C.SetPoint(button.glyph,"LEFT",button.glyph:GetParent(),"LEFT","notesButtonGlyphLeftX",0)
  button.icon=button.glyph
  button.count=C.Text(button,"",14,"dim",T.notesButtonCountWidth);button.count:SetWidth(T.notesButtonCountWidth);C.SetPoint(button.count,"RIGHT",button.count:GetParent(),"RIGHT","notesButtonCountRightX",0);button.count:SetJustifyH("RIGHT");C.SetLineHeight(button.count,20,true);button.navigationStyle=button.styleController;button.navigationStyle:Bind(button,{hover=true});self.tabs[entry[1]]=button
 end
 local main=CreateFrame("Frame",nil,root);main:SetSize(MAIN_WIDTH,HEIGHT);main:SetPoint("TOPLEFT",T.notesMainX,0);C.Panel(main,"surfaceLow","notesPanelRadius");self.main=main
 self.pageTitle=C.Text(main,L.notes,24);C.SetLineHeight(self.pageTitle,32,true);self.pageTitle:SetPoint("TOPLEFT",T.notesContentInset,-T.notesContentInset)
 self.toolbar=CreateFrame("Frame",nil,main);self.toolbar:SetWidth(BODY_WIDTH);self.toolbar:SetHeight(T.notesToolbarHeight);C.SetPoint(self.toolbar,"TOPLEFT",self.toolbar:GetParent(),"TOPLEFT",T.notesContentInset,"notesToolbarTopleftY")
 self.search=C.Edit(self.toolbar,CARD_WIDTH,T.notesSearchHeight);self.search:SetHeight(T.notesSearchHeight);self.search:SetPoint("LEFT")
 self.searchHint=C.Text(self.search,L.noteSearch,14,"dim");C.SetPoint(self.searchHint,"LEFT",self.searchHint:GetParent(),"LEFT","notesSearchHintLeftX",0);C.SetLineHeight(self.searchHint,20,true)
 self.search.box:HookScript("OnTextChanged",function() P:OnSearchChanged() end)
 self.search.box:HookScript("OnEditFocusGained",function() P.searchHint:Hide() end)
 self.search.box:HookScript("OnEditFocusLost",function() P.searchHint:SetShown(P.search.box:GetText()=="") end)
 self.actions=CreateFrame("Frame",nil,main);self.actions:SetSize(DRAWER_W,T.notesToolbarHeight);self.actions:SetPoint("TOPRIGHT",-T.notesContentInset,-T.notesContentInset-(self.pageTitle:GetHeight()-T.notesToolbarHeight)/2)
 self.addButton=C.Button(self.actions,L.add,nil,function() P:OpenAdd() end);self.addButton:SetPrimary(true);self.addButton:SetPoint("RIGHT");self.addButton.label:ClearAllPoints();C.SetPoint(self.addButton.label,"LEFT",self.addButton.label:GetParent(),"LEFT","notesAddButtonLabelLeftX",0)
 self.addButton.icon=C.Glyph(self.addButton,"plus",T.notesAddButtonIconWidth);C.Box(self.addButton.icon,{width="notesAddButtonIconWidth",height="notesAddButtonIconHeight"});C.SetPoint(self.addButton.icon,"LEFT",self.addButton.icon:GetParent(),"LEFT","notesAddButtonIconLeftX",0);self.addButton:SetWidth(math.ceil(self.addButton.label:GetStringWidth())+56)
 self.exportButton=C.Button(self.actions,L.export,nil,function() P:DoExport() end);self.exportButton:SetWidth(self.exportButton.label:GetStringWidth()+28);C.SetPoint(self.exportButton,"RIGHT",self.addButton,"LEFT","notesExportButtonRightX",0)
 self.importButton=C.Button(self.actions,L.import,nil,function() P:OpenTransfer("import") end);self.importButton:SetWidth(self.importButton.label:GetStringWidth()+28);C.SetPoint(self.importButton,"RIGHT",self.exportButton,"LEFT","notesImportButtonRightX",0)
 self.toolbarActionOptions={anchor="TOPRIGHT",width="content",height="notesToolbarHeight",align="center"}
 self.toolbarActions=C.Row(self.actions,{{frame=self.importButton,gapAfter=-T.notesImportButtonRightX},{frame=self.exportButton,gapAfter=-T.notesExportButtonRightX},{frame=self.addButton}},self.toolbarActionOptions)
 self.left=CreateFrame("Frame",nil,main);self.left:SetSize(T.notesListWidth,HEIGHT-T.notesWorkTop-T.notesContentInset);self.left:SetPoint("TOPLEFT",T.notesContentInset,-T.notesWorkTop)
 self.noteHeader=C.TableHeader(self.left,{
  {key="player",label=S("玩家记录","Player notes"),width="notesColumnPlayerWidth264",min="notesColumnPlayerMin180"},
  {key="timestamp",label=S("类型 / 时间","Type / Date"),width="notesColumnTimestampWidth144",min="notesColumnTimestampMin132",align="RIGHT",sortable=true},
 },{onLayout=function(header) P:LayoutNoteColumns(header) end,onSort=function() P:RefreshList() end})
 self.noteHeader:SetPoint("TOPLEFT");self.listTitle=self.noteHeader.labels.player
 self.list=C.List(self.left,T.notesListWidth,0,T.notesRowHeight,function(key,button) P:OnSelect(key,button) end);C.SetPoint(self.list,"TOPLEFT",self.list:GetParent(),"TOPLEFT",0,"notesListTopleftY");self.list.selectionMark=false
 self.list:SetRowInitializer(function(row)
  UI:BindTooltipArea(row,.25,
   function(r) return r:IsEnabled() and r.key and r._hitVisible and P.list.clip:IsMouseOver() end,
   function(r) if P.list.selectedKey~=r.key then UI.Tooltip:ShowNote(r,r.key) end end)
  row.icon=C.Icon(row,T.notesRowIconWidth);C.Box(row.icon,{width="notesRowIconWidth",height="notesRowIconHeight"});C.SetPoint(row.icon,"TOPLEFT",row.icon:GetParent(),"TOPLEFT","notesRowIconTopleftX","notesRowIconTopleftY")
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","notesRowTitleTopleftX","notesRowTitleTopleftY");row.title:SetWidth(CARD_WIDTH-T.notesCardRightInset-132-8-50);C.SetFont(row.title,T.listTitleSize);C.SetLineHeight(row.title,T.listTitleLineHeight,true)
  row.meta:Hide()
  row.reason=C.Text(row,"",14,"muted",CARD_WIDTH-50-T.notesCardRightInset);C.SetPoint(row.reason,"TOPLEFT",row.reason:GetParent(),"TOPLEFT","notesRowReasonTopleftX","notesRowReasonTopleftY");row.reason:SetMaxLines(1);C.SetLineHeight(row.reason,20,true)
  row.kind=C.Text(row,"",T.notesDetailFontSize,"muted",T.notesRowKindWidth);row.kind:SetWidth(T.notesRowKindWidth);C.SetPoint(row.kind,"TOPRIGHT",row.kind:GetParent(),"TOPRIGHT","notesRowKindToprightX","notesRowKindToprightY");row.kind:SetJustifyH("RIGHT");C.SetLineHeight(row.kind,T.notesDetailLineHeight,true)
  row.kindIcons={}
  for _,entry in ipairs(NOTE_TYPES) do local neutral=entry.key=="neutral";local glyph=C.Glyph(row,entry.key=="positive" and "heart" or entry.key=="caution" and "caution" or "book",neutral and T.notesNeutralGlyphSize or T.notesGlyphWidth,entry.key=="positive" and T.good or entry.key=="caution" and T.warning or T.muted);C.Box(glyph,{width=neutral and "notesNeutralGlyphSize" or "notesGlyphWidth",height=neutral and "notesNeutralGlyphSize" or "notesGlyphHeight"});glyph:Hide();row.kindIcons[entry.key]=glyph end
  row.date=C.Text(row,"",T.notesDetailFontSize,"dim",T.notesRowDateWidth);row.date:SetWidth(T.notesRowDateWidth);C.SetPoint(row.date,"TOPRIGHT",row.date:GetParent(),"TOPRIGHT","notesRowDateToprightX","notesRowDateToprightY");row.date:SetJustifyH("RIGHT");C.SetLineHeight(row.date,T.notesDetailLineHeight,true)
  local columns=P.noteHeader.columns
  LayoutNoteColumn(row,columns)
 end)
 local empty=CreateFrame("Frame",nil,self.left);empty:SetWidth(CARD_WIDTH);empty:SetHeight(T.notesEmptyHeight);empty:SetPoint("TOPLEFT",self.list,"TOPLEFT");self.emptyState=empty
 self.emptyTitle=C.Text(empty,L.notesEmptyTitle,18,"muted",CARD_WIDTH-24);C.SetLineHeight(self.emptyTitle,24,true);self.emptyTitle:SetPoint("CENTER");self.emptyTitle:SetJustifyH("CENTER")
 self.editorEmpty=C.Text(main,S("选择玩家查看记录","Select a player to view their note"),18,"dim",DRAWER_W-32);C.SetLineHeight(self.editorEmpty,24,true);self.editorEmpty:SetPoint("CENTER",main,"TOPLEFT",EDITOR_X-T.notesMainX+DRAWER_W/2,-T.notesWorkTop-(HEIGHT-T.notesWorkTop-T.notesContentInset)/2);self.editorEmpty:SetJustifyH("CENTER")
 local editor=CreateFrame("Frame",nil,main);editor:SetSize(DRAWER_W,EDITOR_HEIGHT);editor:SetPoint("TOPLEFT",EDITOR_X-T.notesMainX,-T.notesEditorTop);C.Panel(editor,"panel","notesPanelRadius2");self.editor=editor;editor:Hide()
 local inner=DRAWER_W-48;local half=(inner-12)/2
 self.eTitle=C.Text(editor,L.edit,14,"muted");C.SetPoint(self.eTitle,"TOPLEFT",self.eTitle:GetParent(),"TOPLEFT","notesETitleTopleftX","notesETitleTopleftY");C.SetLineHeight(self.eTitle,20,true)
 self.eClose=C.Button(editor,"",T.notesECloseWidth,function() P:CloseEditor() end);self.eClose:SetWidth(T.notesECloseWidth);self.eClose.elementIcon=C.Glyph(self.eClose,"close",T.notesGlyphWidth2);self.eClose.elementIcon:SetPoint("CENTER");C.SetPoint(self.eClose,"TOPRIGHT",self.eClose:GetParent(),"TOPRIGHT","notesECloseToprightX","notesECloseToprightY")
 self.eNameLabel=C.Text(editor,S("玩家","Player"),14,"muted");C.SetPoint(self.eNameLabel,"TOPLEFT",self.eNameLabel:GetParent(),"TOPLEFT","notesENameLabelTopleftX","notesENameLabelTopleftY");C.SetLineHeight(self.eNameLabel,20,true)
 self.eName=C.Edit(editor,inner,T.notesENameHeight);self.eName:SetHeight(T.notesENameHeight);C.SetPoint(self.eName,"TOPLEFT",self.eName:GetParent(),"TOPLEFT","notesENameTopleftX","notesENameTopleftY")
 self.eNameHint=C.Text(self.eName,L.notesIdentityHint,14,"dim",inner-24);C.SetPoint(self.eNameHint,"LEFT",self.eNameHint:GetParent(),"LEFT","notesENameHintLeftX",0);C.SetLineHeight(self.eNameHint,20,true)
 self.eName.box:HookScript("OnTextChanged",function() DraftChanged();P.eNameHint:SetShown(P.eName.box:GetText()=="") end)
 self.eAvatar=C.Icon(editor,T.notesEAvatarWidth);C.Box(self.eAvatar,{width="notesEAvatarWidth",height="notesEAvatarHeight"});C.SetPoint(self.eAvatar,"TOPLEFT",self.eAvatar:GetParent(),"TOPLEFT","notesEAvatarTopleftX","notesEAvatarTopleftY")
 self.eIdentity=C.Text(editor,"",18,"text",inner-52);C.SetPoint(self.eIdentity,"TOPLEFT",self.eIdentity:GetParent(),"TOPLEFT","notesEIdentityTopleftX","notesEIdentityTopleftY");self.eIdentity:SetWordWrap(false);C.SetLineHeight(self.eIdentity,24,true)
 self.eRealm=C.Text(editor,"",14,"muted",inner-52);C.SetPoint(self.eRealm,"TOPLEFT",self.eRealm:GetParent(),"TOPLEFT","notesERealmTopleftX","notesERealmTopleftY");C.SetLineHeight(self.eRealm,20,true)
 self.classLabel=C.Text(editor,S("职业","Class"),14,"muted");C.SetPoint(self.classLabel,"TOPLEFT",self.classLabel:GetParent(),"TOPLEFT","notesClassLabelTopleftX","notesClassLabelTopleftY");C.SetLineHeight(self.classLabel,20,true)
 self.specLabel=C.Text(editor,S("专精","Specialization"),14,"muted");C.SetPoint(self.specLabel,"TOPLEFT",self.specLabel:GetParent(),"TOPLEFT",28+half,"notesSpecLabelTopleftY");C.SetLineHeight(self.specLabel,20,true)
 self.classChoice=C.Choice(editor,half,function() return P:ClassItems() end,function(value) DraftChanged();state.identityEdited=true;state.legacyClassSpec=nil;state.recordClass=value or nil;state.recordSpec=nil;P:SyncSpec() end);C.SetPoint(self.classChoice,"TOPLEFT",self.classChoice:GetParent(),"TOPLEFT","notesClassChoiceTopleftX","notesClassChoiceTopleftY");self.classChoice:SetHeight(T.notesClassChoiceHeight)
 self.specChoice=C.Choice(editor,half,function() return P:SpecItems() end,function(value) DraftChanged();state.identityEdited=true;state.legacyClassSpec=nil;state.recordSpec=value or nil;P:SyncSpec() end);C.SetPoint(self.specChoice,"TOPLEFT",self.specChoice:GetParent(),"TOPLEFT",28+half,"notesSpecChoiceTopleftY");self.specChoice:SetHeight(T.notesSpecChoiceHeight)
 self.typeLabel=C.Text(editor,S("记录类型","Note type"),14,"muted");C.SetLineHeight(self.typeLabel,20,true)
 self.typeSwitch=CreateFrame("Frame",nil,editor);self.typeSwitch:SetWidth(inner);self.typeSwitch:SetHeight(T.notesTypeSwitchHeight);C.SetPoint(self.typeSwitch,"TOPLEFT",self.typeSwitch:GetParent(),"TOPLEFT","notesTypeSwitchTopleftX","notesTypeSwitchTopleftY");C.Panel(self.typeSwitch,"surfaceLow","notesPanelRadius3")
 self.typeButtons={};for i,entry in ipairs(NOTE_TYPES) do local w=(inner-14)/3;local button=C.Button(self.typeSwitch,entry.label,w,function() DraftChanged();state.recordType=entry.key;P:SyncType() end,{variant="compact",textColor="text"});C.SetPoint(button,"TOPLEFT",button:GetParent(),"TOPLEFT",3+(i-1)*(w+4),"notesButtonTopleftY");button.label:ClearAllPoints();C.SetPoint(button.label,"CENTER",button.label:GetParent(),"CENTER","notesButtonLabelCenterX",0);button.icon=C.Glyph(button,entry.key=="positive" and "heart" or entry.key=="caution" and "caution" or "book",T.notesButtonIconWidth);C.Box(button.icon,{width="notesButtonIconWidth",height="notesButtonIconHeight"});button.icon:SetPoint("CENTER",-(button.label:GetStringWidth()+6)/2,0);self.typeButtons[entry.key]=button end
 self.eReasonLabel=C.Text(editor,L.reason,14,"muted");C.SetPoint(self.eReasonLabel,"TOPLEFT",self.eReasonLabel:GetParent(),"TOPLEFT","notesEReasonLabelTopleftX","notesEReasonLabelTopleftY");C.SetLineHeight(self.eReasonLabel,20,true)
 self.typeItems={};for _,entry in ipairs(NOTE_TYPES) do self.typeItems[#self.typeItems+1]={frame=self.typeButtons[entry.key],width="fill",height="fill"} end
 self.typeLayout=C.Row(self.typeSwitch,self.typeItems,{padding=3,gap=4})
 self.eReason=C.Edit(editor,inner,T.notesEReasonHeight,true);self.eReason:SetHeight(T.notesEReasonHeight);C.SetPoint(self.eReason,"TOPLEFT",self.eReason:GetParent(),"TOPLEFT","notesEReasonTopleftX","notesEReasonTopleftY");self.eReason:SetPlaceholder(S("写下当时发生的事","Describe what happened"));C.SetLineHeight(self.eReason.box,20)
 self.eReason.box:HookScript("OnTextChanged",DraftChanged)
 self.eDate=C.Text(editor,"",14,"dim",inner);C.SetPoint(self.eDate,"TOPLEFT",self.eDate:GetParent(),"TOPLEFT","notesEDateTopleftX","notesEDateTopleftY");C.SetLineHeight(self.eDate,20,true)
 self.eStatus=C.Text(editor,"",14,"muted",inner);C.SetPoint(self.eStatus,"TOPLEFT",self.eStatus:GetParent(),"TOPLEFT","notesEStatusTopleftX","notesEStatusTopleftY");self.eStatus:SetMaxLines(2);C.SetLineHeight(self.eStatus,20)
 self.eSave=C.Button(editor,L.save,T.notesESaveWidth,function() P:Save() end);self.eSave:SetWidth(T.notesESaveWidth);self.eSave:SetPrimary(true);C.SetPoint(self.eSave,"BOTTOMRIGHT",self.eSave:GetParent(),"BOTTOMRIGHT","notesESaveBottomrightX","notesESaveBottomrightY")
 self.eCancel=C.Button(editor,L.cancel,T.notesECancelWidth,function() P:CloseEditor() end);self.eCancel:SetWidth(T.notesECancelWidth);C.SetPoint(self.eCancel,"RIGHT",self.eSave,"LEFT","notesECancelRightX",0)
 self.eDelete=C.Button(editor,S("删除记录","Delete note"),nil,function() P:Delete() end);self.eDelete:SetWidth(math.max(96,math.ceil(self.eDelete.label:GetStringWidth())+32));self.eDelete:SetTextColors("muted","accent");C.SetPoint(self.eDelete,"BOTTOMLEFT",self.eDelete:GetParent(),"BOTTOMLEFT","notesEDeleteBottomleftX","notesEDeleteBottomleftY")
 self.historyFrame=CreateFrame("Frame",nil,main);self.historyFrame:SetSize(BODY_WIDTH,HEIGHT-76-T.notesContentInset);C.SetPoint(self.historyFrame,"TOPLEFT",self.historyFrame:GetParent(),"TOPLEFT",T.notesContentInset,"notesHistoryFrameTopleftY");self.historyFrame:Hide()
 self.historyCaption=C.Text(self.historyFrame,S("当前角色完成的大秘境","Mythic+ runs completed by this character"),14,"muted");self.historyCaption:SetPoint("TOPLEFT");C.SetLineHeight(self.historyCaption,20,true)
 self.historyHeader=C.TableHeader(self.historyFrame,{
  {key="activity",label=S("活动","Activity"),width="notesColumnActivityWidth260",min="notesColumnActivityMin180"},
  {key="level",label=S("层数","Level"),width="notesColumnLevelWidth76",min="notesColumnLevelMin64",align="CENTER",sortable=true},
  {key="duration",label=S("耗时","Duration"),width="notesColumnDurationWidth108",min="notesColumnDurationMin90",align="CENTER",sortable=true},
  {key="teammates",label=S("队友","Teammates"),width="notesColumnTeammatesWidth165",min="notesColumnTeammatesMin147"},
  {key="completed",label=S("完成时间","Completed"),width="notesColumnCompletedWidth172",min="notesColumnCompletedMin144",sortable=true},
 },{onLayout=function(header) P:LayoutHistoryColumns(header) end,onSort=function() P:RefreshHistory() end})
 C.SetPoint(self.historyHeader,"TOPLEFT",self.historyHeader:GetParent(),"TOPLEFT",0,"notesHistoryHeaderTopleftY")
 self.historyList=C.List(self.historyFrame,BODY_WIDTH,0,80,function(index) P:OpenRun(index) end);C.SetPoint(self.historyList,"TOPLEFT",self.historyList:GetParent(),"TOPLEFT",0,"notesHistoryListTopleftY")
 self.historyList:SetRowInitializer(function(row)
  row.icon=C.Icon(row,T.notesRowIconWidth2);C.Box(row.icon,{width="notesRowIconWidth2",height="notesRowIconHeight2"});C.SetPoint(row.icon,"LEFT",row.icon:GetParent(),"LEFT","notesRowIconLeftX",0)
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","notesRowTitleTopleftX2","notesRowTitleTopleftY2");C.SetFont(row.title,T.listTitleSize);C.SetLineHeight(row.title,T.listTitleLineHeight,true)
  row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","notesRowMetaTopleftX2","notesRowMetaTopleftY2");row.meta:Hide()
  row.level=C.Text(row,"",14,"muted");row.level:SetJustifyH("CENTER");C.SetLineHeight(row.level,20,true)
  row.duration=C.Text(row,"",14,"muted");row.duration:SetJustifyH("CENTER");C.SetLineHeight(row.duration,20,true)
  row.roster=UI:CreateRoster(row,23,5)
  row.date=C.Text(row,"",14,"muted",T.notesRowDateWidth2);row.date:SetWidth(T.notesRowDateWidth2);C.SetPoint(row.date,"RIGHT",row.date:GetParent(),"RIGHT","notesRowDateRightX",0);row.date:SetJustifyH("LEFT");C.SetLineHeight(row.date,20,true)
  row.chevron=C.Glyph(row,"chevron",T.notesGlyphWidth3);row.chevron:SetPoint("RIGHT",-16,0)
  LayoutHistoryColumn(row,P.historyHeader.columns)
  C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT",P.historyHeader.columns.activity.x+60,-math.max(44,12+row.title:GetHeight()+4))
 end)
 self.historyEmpty=C.Text(self.historyFrame,L.historyEmpty,16,"dim",BODY_WIDTH);C.SetPoint(self.historyEmpty,"TOP",self.historyEmpty:GetParent(),"TOP",0,"notesHistoryEmptyTopY");self.historyEmpty:SetJustifyH("CENTER")
 self:LayoutRows()
self:RegisterBuildElements()
 end
function P:ClassItems()
 local items={{value=false,label=L.unknown}};for id=1,GetNumClasses() do local name,token=GetClassInfo(id);if name then items[#items+1]={value=token,label=name} end end;return items
end
function P:SpecItems()
 local items={{value=false,label=L.unknown}};local classID
 for id=1,GetNumClasses() do local _,token=GetClassInfo(id);if token==state.recordClass then classID=id;break end end
 if classID then for index=1,C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do local id,name=GetSpecializationInfoForClassID(classID,index);if id then items[#items+1]={value=id,label=name} end end end
 return items
end
function P:SyncType()
 for key,b in pairs(self.typeButtons) do b:SetActive(key==state.recordType) end
end
function P:SyncSpec()
 local className,specName=L.unknown,L.unknown
 if state.recordClass then
  local classID,label=A.Specializations:Class(state.recordClass)
  if classID then
   className=label
   if state.recordSpec then local id,name=A.Specializations:Find(state.recordClass,state.recordSpec);if id then specName=name end end
  else
   -- A class token can be available before its localized label. Keep the
   -- existing specialization lookup for that incomplete directory response.
   for _,item in ipairs(self:SpecItems()) do if item.value==state.recordSpec then specName=item.label end end
  end
 end
 self.classChoice:SetValue(state.recordClass,className);self.specChoice:SetValue(state.recordSpec,specName)
 self.specChoice:SetAvailable(state.recordClass~=nil)
 UI:SetMemberIcon(self.eAvatar,{class=state.recordClass,specID=state.recordSpec});self.eIdentity:SetTextColor(UI:ClassColor(state.recordClass))
 self:SyncType()
 state.classSpec=state.recordClass and (className..(state.recordSpec and " · "..specName or "")) or state.legacyClassSpec or ""
end
function P:SetEditorStatus(text,kind)
 UI:SetText(self.eStatus,text)
 UI:Color(self.eStatus,kind=="error" and "warning" or kind=="success" and "good" or "muted")
 self:LayoutEditor()
end
function P:SelectTab(tab,skipDefault)
 local previous=state.tab;local changed=previous~=nil and previous~=tab
 if changed then self.noteHeader:StopDrag(false);self.historyHeader:StopDrag(false) end
 local direction=previous and self.tabs[tab].order<self.tabs[previous].order and -1 or 1
 state.tab=tab;local history=tab=="history"
 for key,button in pairs(self.tabs) do button:SetActive(key==tab);button.navigationStyle:SetState("selected",key==tab);button.glyph:SetSelected(key==tab) end
 local selected=self.tabs[tab];self.tabSelection:Select(0,selected.tabY,T.notesSidebarWidth,selected:GetHeight(),self.frame:IsVisible())
 self:CloseTransfer();if changed then self:CloseEditor(true) end
 UI.Motion:FinishPlacement(history and self.left or self.historyFrame)
 self.toolbar:SetShown(not history);self.actions:SetShown(not history);self.left:SetShown(not history);self.historyFrame:SetShown(history);self.editorEmpty:SetShown(not history and state.panel==nil)
 UI:SetText(self.pageTitle,history and L.history or L.notes)
 self:RefreshCounts()
 if history then self:RefreshHistory() else self:RefreshList();local keys=self.list.ids;if not skipDefault and keys and keys[1] and state.panel==nil then self:OpenEdit(keys[1]) end end
 if changed then UI.Motion:Reveal(history and self.historyFrame or self.left,"TOPLEFT",self.main,"TOPLEFT",T.notesContentInset,history and -76 or -T.notesWorkTop,direction*32,0,.18) end
UI:ApplyElementScope("notes")
 end
function P:RefreshHistory()
 local group,err=A:Ensure("Group");if not group then A:NoteMessage(err);return end
 self.runs=group:GetHistory();local indices={};for i in ipairs(self.runs) do indices[#indices+1]=i end
 local sorting=self.historyTableState
 if sorting and sorting.sortKey then
  SortNumbers(indices,function(index)
   local run=P.runs[index]
   if sorting.sortKey=="level" then return run.level end
   if sorting.sortKey=="duration" then return RunDuration(run) end
   local completed=run.completedAt or run.startedAt;return completed and completed>0 and completed or nil
  end,sorting.descending)
 end
 self.historyList:SetItems(indices,function(row,index)
  local run=P.runs[index]
  local texture=run.mapChallengeModeID and select(4,C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID))
  if texture then UI:SetGameTexture(row.icon,texture) else UI:SetActivityIcon(row.icon,run.activity or run) end
  UI:SetText(row.title,run.mapName or L.unknown)
  local duration=RunDuration(run)
  UI:SetText(row.level,run.level and "+"..run.level or "—")
  UI:SetText(row.duration,duration and (math.floor(duration/60)..":"..("%02d"):format(duration%60)) or "—")
  row.roster:Update(run.members,nil,5);UI:SetText(row.date,UI:DateText(run.completedAt or run.startedAt))
 end);LayoutHistoryRows(self.historyList,self.historyHeader.columns.activity.x+60);self.historyEmpty:SetShown(#indices==0)
UI:ApplyElementScope("notes")
 end
function P:OpenRun(index)
 local run=self.runs[index];if not run then return end
 local modal=UI:OpenModal("history",L.history,560,576);self.historyModal=modal
 if not modal.built then
  modal.caption=C.Text(modal.content,"",14,"muted",T.notesModalCaptionWidth);modal.caption:SetWidth(T.notesModalCaptionWidth);modal.caption:SetPoint("TOPLEFT");C.SetLineHeight(modal.caption,22,true)
  modal.header=C.TableHeader(modal.content,{
   {key="player",label=S("玩家","Player"),width="notesColumnPlayerWidth364",min="notesColumnPlayerMin220"},
   {key="actions",label=S("操作","Actions"),width="notesColumnActionsWidth136",min="notesColumnActionsMin124",align="RIGHT"},
  },{onLayout=function(header) P:LayoutHistoryMemberColumns(header) end})
  C.SetPoint(modal.header,"TOPLEFT",modal.header:GetParent(),"TOPLEFT",0,"notesModalHeaderTopleftY")
  modal.list=C.List(modal.content,T.notesModalListWidth,T.notesModalListHeight,80,function(memberIndex)
   local member=P.historyRun.members[memberIndex];local key=A:PlayerKey(member.name,member.realm)
   modal:Close();P:SelectTab("all")
   if A.Notes:Find(key) then P:OpenEdit(key);P.list:Select(key,true) else P:OpenAdd({name=member.name,realm=member.realm,class=member.class,specID=member.specID}) end
  end);C.Box(modal.list,{width="notesModalListWidth",height="notesModalListHeight"});C.SetPoint(modal.list,"TOPLEFT",modal.list:GetParent(),"TOPLEFT",0,"notesModalListTopleftY")
  for _,row in ipairs(modal.list.rows) do
   row.icon=C.Icon(row,T.notesRowIconWidth3);C.Box(row.icon,{width="notesRowIconWidth3",height="notesRowIconHeight3"});C.SetPoint(row.icon,"LEFT",row.icon:GetParent(),"LEFT","notesRowIconLeftX",0)
   row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","notesRowTitleTopleftX3","notesRowTitleTopleftY2");row.title:SetWidth(T.notesRowTitleWidth);C.SetFont(row.title,T.listTitleSize);C.SetLineHeight(row.title,T.listTitleLineHeight,true)
   row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","notesRowMetaTopleftX3","notesRowMetaTopleftY2");row.meta:SetWidth(T.notesRowMetaWidth)
   row.action=C.Text(row,"",14,"dim",T.notesRowActionWidth);row.action:SetWidth(T.notesRowActionWidth);C.SetPoint(row.action,"RIGHT",row.action:GetParent(),"RIGHT","notesRowActionRightX",0);row.action:SetJustifyH("RIGHT");C.SetLineHeight(row.action,20,true)
  end
  modal.onClose=function() modal.header:StopDrag(false);modal.list:Clear();P.historyRun=nil end;modal.built=true
 end
 self.historyRun=run
 modal.header:SetState(UI:GetTablePrefs("notesHistoryMembers"));modal.header:Layout(modal.list:GetWidth()-C.listRightInset)
 UI:SetText(modal.caption,(run.mapName or L.unknown).." · +"..(run.level or "?").." · "..UI:DateText(run.completedAt or run.startedAt))
 local ids={};for i in ipairs(run.members) do ids[#ids+1]=i end
 modal.list:SetItems(ids,function(row,i)
  local member=P.historyRun.members[i];local key=A:PlayerKey(member.name,member.realm)
  UI:SetMemberIcon(row.icon,member);UI:SetText(row.title,member.name.."-"..member.realm);row.title:SetTextColor(UI:ClassColor(member.class))
  UI:SetText(row.meta,UI:SpecName(member) or L.unknown);UI:SetText(row.action,A.Notes:Find(key) and L.viewNote or L.record)
 end)
 LayoutHistoryRows(modal.list,modal.header.columns.player.x+56)
self:RegisterBuildElements()
 UI:ApplyElementScope("notes")
 end

-- ---------------------------------------------------------------- 名单

function P:RefreshCounts()
	local counts={all=0,positive=0,neutral=0,caution=0}
 for _,record in pairs(A.Notes.db.records) do counts.all=counts.all+1;counts[record.type or "neutral"]=(counts[record.type or "neutral"] or 0)+1 end
 for key,button in pairs(self.tabs) do UI:SetText(button.count,key=="history" and (A.Group and A.Group.charDB and #A.Group.charDB.runs or "—") or counts[key]) end
end

function P:RefreshList()
	local notes = A.Notes
 local keys = (notes and notes.List and notes:List({ text = state.search, type = state.tab~="all" and state.tab~="history" and state.tab or nil })) or {}
 if self.noteTableState and self.noteTableState.sortKey=="timestamp" then
  SortNumbers(keys,function(key) local timestamp=notes:Find(key).timestamp;return timestamp and timestamp>0 and timestamp or nil end,self.noteTableState.descending)
 end
	self.list.selectedKey = state.editKey
	self.list:SetItems(keys, RenderNote)
	self.emptyState:SetShown(#keys == 0)
	UI:SetText(self.emptyTitle, state.search ~= "" and S("没有匹配的记录","No matching notes") or S("这里还没有记录","No records here yet"))
	if state.editKey ~= nil then
		local found = false
		for _, k in ipairs(keys) do
			if k == state.editKey then found = true break end
		end
		if not found and not notes:Find(state.editKey) then P:ShowMissing() end
	end
UI:ApplyElementScope("notes")
 end

function P:OnSearchChanged()
	state.search = self.search.box:GetText() or ""
	self.searchHint:SetShown(state.search == "" and not self.search.box:HasFocus())
	self:RefreshList()
end

function P:LayoutNoteRows()
 local row=self.list.rows[1]
 local reasonTop=math.max(T.notesRowReasonTop,-T.notesRowTitleTopleftY+row.title:GetHeight()+8)
 for _,item in ipairs(self.list.rows) do
  LayoutNoteColumn(item,self.noteHeader.columns)
 end
 local height=math.max(T.notesRowHeight,math.ceil(reasonTop+row.reason:GetHeight()+14))
 self.list:SetRowHeight(height,height)
end
function P:LayoutRows()
 self.noteHeader:Layout(CARD_WIDTH)
 self.historyHeader:Layout(BODY_WIDTH-C.listRightInset-32)
 if self.historyModal then self.historyModal.header:Layout(self.historyModal.list:GetWidth()-C.listRightInset) end
end
function P:LayoutFont()
 self.actions:SetPoint("TOPRIGHT",-T.notesContentInset,-T.notesContentInset-(self.pageTitle:GetHeight()-T.notesToolbarHeight)/2)
 self.addButton:SetWidth(math.ceil(self.addButton.label:GetStringWidth())+56)
 self.importButton:SetWidth(math.ceil(self.importButton.label:GetStringWidth())+28)
 self.exportButton:SetWidth(math.ceil(self.exportButton.label:GetStringWidth())+28)
 self.eDelete:SetWidth(math.max(96,math.ceil(C.MeasureText(self.eDelete.label))+32))
 self.toolbarActions.items[1].gapAfter=-T.notesImportButtonRightX;self.toolbarActions.items[2].gapAfter=-T.notesExportButtonRightX;self.toolbarActions:Layout()
 for _,button in pairs(self.typeButtons) do button.icon:SetPoint("CENTER",-(button.label:GetStringWidth()+6)/2,0) end
 self:LayoutRows();self.list:Refresh()
 if self.tSelect then
  self.tSelect:SetWidth(math.max(128,math.ceil(self.tSelect.label:GetStringWidth())+32))
  self.tImport:SetWidth(math.max(104,math.ceil(self.tImport.label:GetStringWidth())+32))
  self.tExport:SetWidth(math.max(104,math.ceil(self.tExport.label:GetStringWidth())+32))
 end
UI:ApplyElementScope("notes")
 end

local function LayoutSize(self,width,height)
 WIDTH,HEIGHT=width,height
 LEFT=T.notesMainX+T.notesContentInset
 EDITOR_X=LEFT+T.notesListWidth+T.notesColumnGap;CARD_WIDTH=T.notesListWidth-C.listRightInset
 MAIN_WIDTH=WIDTH-T.notesMainX;BODY_WIDTH=MAIN_WIDTH-T.notesContentInset*2
 DRAWER_W=BODY_WIDTH-T.notesListWidth-T.notesColumnGap
 LIST_HEIGHT=HEIGHT-T.notesWorkTop-32-T.notesContentInset;EDITOR_HEIGHT=math.min(T.notesEditorMaxHeight,HEIGHT-T.notesEditorTop-T.notesContentInset-T.notesEditorBottomInset)
 self.rail:SetHeight(HEIGHT);self.main:SetSize(MAIN_WIDTH,HEIGHT);self.toolbar:SetWidth(BODY_WIDTH)
 self.search:SetWidth(CARD_WIDTH);self.emptyState:SetWidth(CARD_WIDTH)
 self.actions:SetWidth(DRAWER_W);self.actions:SetPoint("TOPRIGHT",-T.notesContentInset,-T.notesContentInset-(self.pageTitle:GetHeight()-T.notesToolbarHeight)/2)
 self.toolbarActions:Layout()
 self.left:SetHeight(HEIGHT-T.notesWorkTop-T.notesContentInset);self.list:SetViewport(LIST_HEIGHT)
 self.editor:SetSize(DRAWER_W,EDITOR_HEIGHT);self.editorEmpty:SetWidth(DRAWER_W-32)
 self.editorEmpty:SetPoint("CENTER",self.main,"TOPLEFT",EDITOR_X-T.notesMainX+DRAWER_W/2,-T.notesWorkTop-(HEIGHT-T.notesWorkTop-T.notesContentInset)/2)
 local inner=DRAWER_W-48;local half=(inner-12)/2
 self.eName:SetWidth(inner);self.eNameHint:SetWidth(inner-24)
 self.eIdentity:SetWidth(inner-52);self.eRealm:SetWidth(inner-52)
 self.classChoice:SetWidth(half);self.specChoice:SetWidth(half);self.typeSwitch:SetWidth(inner)
 self.typeLayout:Layout()
 self.eReason:SetWidth(inner);self.eDate:SetWidth(inner);self.eStatus:SetWidth(inner)
 self:LayoutEditor()
 self.historyFrame:SetSize(BODY_WIDTH,HEIGHT-76-T.notesContentInset);self.historyList:SetWidth(BODY_WIDTH)
 self.historyList:SetViewport(HEIGHT-148-T.notesContentInset);self.historyEmpty:SetWidth(BODY_WIDTH)
end

function P:LayoutSize(width,height)
 LayoutSize(self,width,height)
 self:LayoutRows()
UI:ApplyElementScope("notes")
 end

function P:ReflowMetrics(width,height)
 LayoutSize(self,width,height)
 self.rail:SetWidth(T.notesSidebarWidth)
 for _,button in pairs(self.tabs) do button:SetWidth(T.notesSidebarWidth) end
 self.main:SetPoint("TOPLEFT",T.notesMainX,0)
 self.pageTitle:SetPoint("TOPLEFT",T.notesContentInset,-T.notesContentInset)
 C.SetPoint(self.toolbar,"TOPLEFT",self.main,"TOPLEFT",T.notesContentInset,"notesToolbarTopleftY")
 C.SetPoint(self.historyFrame,"TOPLEFT",self.main,"TOPLEFT",T.notesContentInset,"notesHistoryFrameTopleftY")
 self.left:SetWidth(T.notesListWidth);self.left:SetPoint("TOPLEFT",T.notesContentInset,-T.notesWorkTop)
 self.list:SetWidth(T.notesListWidth)
 self.editor:SetPoint("TOPLEFT",EDITOR_X-T.notesMainX,-T.notesEditorTop)
 self:LayoutFont()
UI:ApplyElementScope("notes")
 end

function P:LayoutEditor()
 if not state.panel then return end
 local add,missing=state.panel=="add",state.panel=="missing"
 local pad=24
 local identityHeight=math.max(self.eAvatar:GetHeight(),self.eIdentity:GetHeight()+self.eRealm:GetHeight()+4)
 local identityBlock=add and self.eNameLabel:GetHeight()+8+self.eName:GetHeight() or identityHeight
 local labelHeight=math.max(self.classLabel:GetHeight(),self.specLabel:GetHeight())
 local choiceHeight=math.max(self.classChoice:GetHeight(),self.specChoice:GetHeight())
 local switchHeight=math.max(T.notesTypeSwitchHeight,self.typeButtons.positive.label:GetHeight()+12)
 local statusText=self.eStatus:GetText()
 local statusHeight=statusText and statusText~="" and self.eStatus:GetStringHeight()+8 or 0
 local dateHeight=not add and self.eDate:GetHeight()+8 or 0
 local footerTop=EDITOR_HEIGHT-T.notesESaveBottomrightY-self.eSave:GetHeight()
 local fullReasonTop=pad+self.eTitle:GetHeight()+20+identityBlock+24+labelHeight+8+choiceHeight+24+self.typeLabel:GetHeight()+8+switchHeight+24+self.eReasonLabel:GetHeight()+8
 -- Preserve the normal spacing until the reason field reaches its minimum.
 -- Short windows then tighten only section gaps, keeping labels and actions apart.
 local tighten=math.min(16,math.max(0,(32-(footerTop-12-fullReasonTop-dateHeight-statusHeight))/4))
 local sectionGap,headingGap=24-tighten,20-tighten
 local identityTop=pad+self.eTitle:GetHeight()+headingGap
 self.eIdentity:ClearAllPoints();self.eIdentity:SetPoint("TOPLEFT",T.notesEIdentityTopleftX,-identityTop)
 self.eRealm:ClearAllPoints();self.eRealm:SetPoint("TOPLEFT",self.eIdentity,"BOTTOMLEFT",0,-4)
 self.eAvatar:ClearAllPoints();self.eAvatar:SetPoint("TOPLEFT",pad,-identityTop-(identityHeight-self.eAvatar:GetHeight())/2)
 self.eNameLabel:SetPoint("TOPLEFT",pad,-identityTop)
 self.eName:SetPoint("TOPLEFT",pad,-identityTop-self.eNameLabel:GetHeight()-8)
 local classTop=identityTop+identityBlock+sectionGap
 local classInputTop=classTop+labelHeight+8
 local half=(DRAWER_W-60)/2
 C.SetPoint(self.classLabel,"TOPLEFT",self.classLabel:GetParent(),"TOPLEFT","notesClassLabelTopleftX",-classTop)
 self.specLabel:SetPoint("TOPLEFT",pad+half+12,-classTop)
 C.SetPoint(self.classChoice,"TOPLEFT",self.classChoice:GetParent(),"TOPLEFT","notesClassChoiceTopleftX",-classInputTop)
 self.specChoice:SetPoint("TOPLEFT",pad+half+12,-classInputTop)
 local typeTop=classInputTop+choiceHeight+sectionGap
 local switchTop=typeTop+self.typeLabel:GetHeight()+8
 self.typeSwitch:SetHeight(switchHeight);self.typeLayout:Layout()
 C.SetPoint(self.typeLabel,"TOPLEFT",self.typeLabel:GetParent(),"TOPLEFT","notesTypeLabelTopleftX",-typeTop)
 C.SetPoint(self.typeSwitch,"TOPLEFT",self.typeSwitch:GetParent(),"TOPLEFT","notesTypeSwitchTopleftX",-switchTop)
 local reasonLabelTop=switchTop+switchHeight+sectionGap
 local reasonTop=reasonLabelTop+self.eReasonLabel:GetHeight()+8
 C.SetPoint(self.eReasonLabel,"TOPLEFT",self.eReasonLabel:GetParent(),"TOPLEFT","notesEReasonLabelTopleftX",-reasonLabelTop)
 C.SetPoint(self.eReason,"TOPLEFT",self.eReason:GetParent(),"TOPLEFT","notesEReasonTopleftX",-reasonTop)
 local reasonHeight=math.max(32,math.min(T.notesEReasonHeight,footerTop-12-reasonTop-dateHeight-statusHeight))
 self.eReason:SetHeight(reasonHeight)
 C.SetPoint(self.eDate,"TOPLEFT",self.eDate:GetParent(),"TOPLEFT","notesEDateTopleftX",-reasonTop-reasonHeight-8)
 C.SetPoint(self.eStatus,"TOPLEFT",self.editor,"TOPLEFT","notesEStatusTopleftX",missing and -76 or -reasonTop-reasonHeight-dateHeight-8)
end

function P:OnSelect(key, button)
	if button == "RightButton" then
		UI:OpenMenu(self.list, {
			{ label = L.edit, value = "edit" },
			{ label = L.delete, value = "delete" },
		}, function(value)
			if value == "edit" then
				P:OpenEdit(key)
			elseif value == "delete" then
				A.Notes:Remove(key)
			end
		end, { cursor = true })
		return
	end
	self:OpenEdit(key)
end

-- ---------------------------------------------------------------- 编辑区

local function SelectNote(key)
 if P.list.selectedKey==key then return end
 P.list.selectedKey=key;P.list:Refresh(true)
end

local function ShowEditorChrome(mode,reveal)
	-- mode: "edit" | "add" | "missing";缺失态只显示说明与取消,不呈现可编辑字段。
	local edit, add, missing = mode == "edit", mode == "add", mode == "missing"
	state.panel = mode
	P.editor:Show();P.editorEmpty:Hide()
	if reveal~=false then UI.Motion:Reveal(P.editor,"TOPLEFT",P.main,"TOPLEFT",EDITOR_X-T.notesMainX,-T.notesEditorTop,12,0,.18) end
 UI:SetText(P.eTitle,add and L.add or missing and L.viewNote or S("玩家记录","Player note"))
 P.eClose:SetShown(add or missing)
 P.eIdentity:SetShown(edit);P.eAvatar:SetShown(edit);P.eRealm:SetShown(edit);P.eDate:SetShown(edit)
 P.eNameLabel:SetShown(add);P.eName:SetShown(add)
 P.classLabel:SetShown(not missing);P.specLabel:SetShown(not missing);P.typeLabel:SetShown(not missing);P.typeSwitch:SetShown(not missing)
 P.eReasonLabel:SetShown(not missing);P.eReason:SetShown(not missing);P.eSave:SetShown(not missing);P.eCancel:SetShown(not missing)
 P.eDelete:SetShown(edit);P.classChoice:SetShown(not missing);P.specChoice:SetShown(not missing);for _,button in pairs(P.typeButtons) do button:SetShown(not missing) end
 P:LayoutEditor()
end

function P:OpenEdit(key)
	local changed=state.panel~="edit" or state.editKey~=key
	self:CloseTransfer()
	CancelPending()
	local r = A.Notes and A.Notes:Find(key)
	if not r then
		P:ShowMissing()
		return
	end
	state.editKey = key
 local identity=A.Notes.PlayerInfo.ResolveRecord(r)
 state.identityEdited=nil;state.identityKey=key;state.legacyClassSpec=r.classSpec
 state.recordClass,state.recordSpec,state.recordType=identity.class,identity.specID,r.type or "neutral";self:SyncSpec()
	state.draft = nil
	UI:SetText(self.eStatus, "")
	ShowEditorChrome("edit",changed)
	UI:SetText(self.eIdentity,r.name);UI:SetText(self.eRealm,r.server);UI:SetText(self.eDate,S("记录于 ","Recorded ")..UI:DateText(r.timestamp))
	self.eReason.box:SetText(r.reason or "")
	SelectNote(key)
UI:ApplyElementScope("notes")
 end

function P:OpenAdd(draft)
	self:CloseTransfer()
	CancelPending()
	state.editKey = nil
	state.draft = draft or {}
 state.identityEdited=draft and (draft.class~=nil or draft.specID~=nil) or nil
 state.identityKey=draft and A:PlayerKey(draft.name,draft.realm)
 local identity=draft or {}
 if draft and draft.unit and not state.identityEdited and A:UnitIdentity(draft.unit)==state.identityKey then
  local _,snapshot=A.Notes.PlayerInfo.Snapshot(draft.unit);identity=snapshot or identity
 end
 state.legacyClassSpec=nil;state.recordClass,state.recordSpec,state.recordType=identity.class,identity.specID,draft and draft.type or A:GetSetting("defaultNote");self:SyncSpec()
	UI:SetText(self.eStatus, "")
	ShowEditorChrome("add")
	UI:SetText(self.eIdentity,draft and draft.name or "");UI:SetText(self.eRealm,draft and draft.realm or "")
	self.eName.box:SetText(draft and draft.name and (draft.name..(draft.realm and "-"..draft.realm or "")) or "")
	self.eReason.box:SetText(draft and draft.reason or "")
	SelectNote(nil)
UI:ApplyElementScope("notes")
 end

-- 定位目标记录不存在:只显示缺失说明与取消,不呈现可编辑字段。
function P:ShowMissing()
	self:CloseTransfer()
	CancelPending()
	state.editKey = nil
	state.draft = nil
	ShowEditorChrome("missing")
	UI:SetText(self.eIdentity, "")
	UI:SetText(self.eRealm, "");UI:SetText(self.eDate, "")
	UI:SetText(self.eStatus, L.missingRecord)
	SelectNote(nil)
end

function P:CloseEditor(skipRefresh)
	CancelPending()
	state.panel = nil
	state.editKey = nil
	state.draft = nil
	UI.Motion:FinishPlacement(self.editor)
	self.editor:Hide();self.editorEmpty:SetShown(state.tab~="history")
	self.eReason.box:SetText("")
	self.eName.box:SetText("")
	UI:SetText(self.eStatus, "")
	if skipRefresh then self.list.selectedKey=nil else SelectNote(nil) end
end

function P:Save()
	if UI.hiding or state.cancel then return end
	local notes = A.Notes
	if not notes then return end
	local reason = self.eReason.box:GetText() or ""
	if state.editKey then
		local ok = notes:Edit(state.editKey, reason,{type=state.recordType,class=state.recordClass,specID=state.recordSpec,classSpec=state.classSpec})
		self:SetEditorStatus(ok and L.saved or L.missingRecord,ok and "success" or "error")
		return
	end
	local draft = state.draft
	if not draft then return end
	local name
	if self.eName:IsShown() then
		name = (self.eName.box:GetText() or ""):match("^%s*(.-)%s*$")
		if name == "" then
			self:SetEditorStatus(L.nameRequired,"error")
			return
		end
	else
		name = draft.name
	end
	local clean, realm = name, draft.realm
	local keyRealm=draft.realm;if self.eName:IsShown() then keyRealm=nil end
 local full, n, r = A:PlayerKey(name, keyRealm)
	if full then clean, realm = n, r end
	if full~=state.identityKey and not state.identityEdited then
		state.recordClass,state.recordSpec=nil,nil;self:SyncSpec()
	end
	-- 带 unit 的添加先经专精查询(同步缓存或一次检视),回调后再写入;
	-- 查询失败回调 nil,记录照常保存(专精留待定语义值)。
	local unit = draft.unit
	if unit and A:UnitIdentity(unit) ~= full then unit = nil end
	local revision = state.revision
	local function Commit(spec,identity)
		if state.revision ~= revision or state.draft ~= draft or UI.hiding then return end
		state.cancel = nil
		if identity and not state.identityEdited then
			state.recordClass=identity.class or state.recordClass
			state.recordSpec=identity.specID or state.recordSpec
			P:SyncSpec()
		end
		local ok, record = notes:Add(clean, realm, reason, nil, state.classSpec~="" and state.classSpec or spec or "",{type=state.recordType,class=state.recordClass,specID=state.recordSpec})
		if ok then
			state.draft = nil
			if type(record) == "table" and record.name and record.server then
				state.editKey = record.name .. "-" .. record.server
				P:OpenEdit(state.editKey)
				P.list:Select(state.editKey, true)
			else
				P:RefreshList()
			end
			P:SetEditorStatus(L.saved,"success")
		else
			P:SetEditorStatus(record and tostring(record) ~= "" and tostring(record) or L.failed,"error")
		end
	end
	if unit and notes.PlayerInfo and not state.identityEdited then
		self:SetEditorStatus(L.busy)
		local cancel = notes.PlayerInfo.Request(unit, Commit)
		if state.revision == revision and state.draft == draft then state.cancel = cancel end
	else
		Commit(nil)
	end
end

function P:Delete()
	if not state.editKey then return end
	local ok = A.Notes:Remove(state.editKey)
	if ok then A:NoteMessage(L.deleted) end
	P:CloseEditor()
end

-- ---------------------------------------------------------------- 导入导出

function P:BuildTransfer(mode)
 local modal=UI:OpenModal("notesTransfer",mode=="import" and S("导入记录","Import notes") or S("导出记录","Export notes"),560,512);self.transferModal=modal;self.transfer=modal.frame
 if modal.built then return end
 local parent=modal.content
 self.tHint=C.Text(parent,L.importHelp,14,"muted",T.notesTHintWidth);self.tHint:SetWidth(T.notesTHintWidth);self.tHint:SetPoint("TOPLEFT");self.tHint:SetWordWrap(true);C.SetLineHeight(self.tHint,20)
 self.tLabel=C.Text(parent,S("记录文本","Record text"),14,"muted");C.SetLineHeight(self.tLabel,20,true);C.SetPoint(self.tLabel,"TOPLEFT",self.tHint,"BOTTOMLEFT",0,"notesTLabelTopleftY")
 self.tBox=C.Edit(parent,T.notesTBoxWidth,T.notesTBoxHeight,true,false,"modal");C.Box(self.tBox,{width="notesTBoxWidth",height="notesTBoxHeight"});C.SetPoint(self.tBox,"TOPLEFT",self.tLabel,"BOTTOMLEFT",0,"notesTBoxTopleftY");C.SetLineHeight(self.tBox.box,22)
 self.tStatus=C.Text(parent,"",14,"accent",T.notesTStatusWidth);self.tStatus:SetWidth(T.notesTStatusWidth);C.SetPoint(self.tStatus,"TOPLEFT",self.tBox,"BOTTOMLEFT",0,"notesTStatusTopleftY");C.SetLineHeight(self.tStatus,20,true)
 self.tImport=C.Button(parent,L.import,T.notesTImportWidth,function() P:DoImport() end);self.tImport:SetWidth(T.notesTImportWidth);self.tImport:SetPrimary(true);self.tImport:SetPoint("BOTTOMRIGHT")
 self.tExport=C.Button(parent,L.export,T.notesTExportWidth,function() P:DoExport() end);self.tExport:SetWidth(T.notesTExportWidth);self.tExport:SetPrimary(true);self.tExport:SetPoint("BOTTOMRIGHT")
 self.tSelect=C.Button(parent,L.selectAll,T.notesTSelectWidth,function() P.tBox.box:SetFocus();P.tBox.box:HighlightText() end);self.tSelect:SetWidth(T.notesTSelectWidth);self.tSelect:SetPoint("BOTTOMLEFT")
 modal.onClose=function() P:CloseTransfer() end;modal.built=true
self:RegisterBuildElements()
 end

function P:OpenTransfer(mode)
	if state.panel == mode then
		self.tBox.box:SetFocus()
		return
	end
	self:CloseEditor()
 self:BuildTransfer(mode)
	state.panel = mode
	self.transfer:Show()
	self.editorEmpty:Hide();UI.Motion:Alpha(self.transfer,1,.18,0)
	self.transferModal:SetTitle(mode == "import" and S("导入记录","Import notes") or S("导出记录","Export notes"))
	UI:SetText(self.tHint, mode == "import" and L.importHelp or L.exportHelp)
	self.tImport:SetShown(mode == "import")
	self.tExport:SetShown(mode == "export")
	self.importButton:SetActive(mode == "import")
	self.exportButton:SetActive(mode == "export")
	self.tBox.box:SetText("")
	UI:SetText(self.tStatus, "")
	self.tBox.box:SetFocus()
	UI.Tooltip:Hide()
end

function P:CloseTransfer()
	if state.panel ~= "import" and state.panel ~= "export" then return end
	state.panel = nil
	UI.Motion:FinishPlacement(self.transfer)
 self.transferModal:Close();self.editorEmpty:SetShown(state.tab~="history")
	self.importButton:SetActive(false)
	self.exportButton:SetActive(false)
	self.tBox.box:SetText("")
	self.tBox.box:ClearFocus()
	UI:SetText(self.tStatus, "")
end

function P:DoExport()
	self:OpenTransfer("export")
	local notes = A.Notes
 local keys = (notes and notes.List and notes:List()) or {}
	local records = {}
	for _, key in ipairs(keys) do
		local r = notes:Find(key)
		if r then
			records[#records + 1] = {
				name = r.name, server = r.server, timestamp = r.timestamp,
				reason = r.reason, classSpec = r.classSpec,type=r.type,class=r.class,specID=r.specID,
			}
		end
	end
	if #records == 0 then
		UI:SetText(self.tStatus, L.empty)
		return
	end
	local ok, text = pcall(UI.Transfer.Encode, records)
	if not ok or type(text) ~= "string" or text == "" then
		UI:SetText(self.tStatus, L.failed)
		return
	end
	self.tBox.box:SetText(text)
	self.tBox.box:SetFocus()
	self.tBox.box:SetCursorPosition(0)
	self.tBox.box:HighlightText()
	UI:SetText(self.tStatus, L.count:format(#records))
end

function P:DoImport()
	local notes = A.Notes
	if not notes or not notes.Merge then return end
	local records = UI.Transfer.Decode(self.tBox.box:GetText() or "")
	if not records then
		UI:SetText(self.tStatus, L.invalidData)
		return
	end
	local merged, invalid = notes:Merge(records)
	UI:SetText(self.tStatus, L.importResult:format(merged or 0, invalid))
end

-- ---------------------------------------------------------------- 页面生命周期

function P:Enter(context)
 self:BindTableStates()
	Subscribe()
 self:SelectTab(context and "all" or state.tab or "all",context~=nil)
	self.searchHint:SetShown(state.search == "" and not self.search.box:HasFocus())
	if context then
		if context.playerKey then
			if A.Notes and A.Notes:Find(context.playerKey) then
				self:OpenEdit(context.playerKey)
				self.list:Select(context.playerKey, true)
			else
				self:ShowMissing()
			end
		elseif context.add then
			self:OpenAdd(context.add)
		end
	end
end

-- 隐藏退订、清编辑临时态与导出文本;搜索词保留。
function P:Leave()
 self.noteHeader:StopDrag(false);self.historyHeader:StopDrag(false)
 UI.Motion:FinishPlacement(self.left);UI.Motion:FinishPlacement(self.historyFrame)
 self.tabSelection:Clear()
	if state.unsub then state.unsub(); state.unsub = nil end
	self:CloseTransfer()
	self:CloseEditor(true)
	self.list:Clear();self.historyList:Clear();self.runs=nil
 if self.historyModal then self.historyModal:Close() end
 if self.tBox then self.tBox.box:SetText("");UI:SetText(self.tStatus, "") end
	UI.Tooltip:Hide()
end




function P:RegisterBuildElements()
UI:ElementFields(self,"notes","frame rail tabSelection main pageTitle toolbar actions search searchHint addButton exportButton importButton left noteHeader emptyState emptyTitle editorEmpty editor eTitle eClose eNameLabel eName eNameHint eAvatar eIdentity eRealm classLabel specLabel classChoice specChoice typeLabel typeSwitch eReasonLabel eReason eDate eStatus eSave eCancel eDelete historyFrame historyCaption historyHeader historyEmpty tHint tLabel tBox tStatus tImport tExport tSelect","notes")
 UI:ElementList(self.list,"notes.list","notes","notes.record")
 UI:ElementList(self.historyList,"notes.historyList","notes","notes.history")
 for key,button in pairs(self.tabs or {}) do UI:Element(button,"notes.navigation","notes",button,"notes.navigation",key) end
 for key,button in pairs(self.typeButtons or {}) do UI:Element(button,"notes.type","notes",button,"notes.type",key) end
 local modal=self.historyModal
 if modal then UI:ElementFields(modal,"notes.historyModal","caption header","notes");UI:ElementList(modal.list,"notes.historyModal.list","notes","notes.historyMember") end
end
