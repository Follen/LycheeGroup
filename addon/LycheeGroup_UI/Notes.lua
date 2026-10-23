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
 list.rowHeight=height;list.capacity=math.min(list.poolCapacity-1,math.ceil(list:GetHeight()/height))
 list.canvas:SetHeight(list:GetHeight()+height*2)
 for i,row in ipairs(list.rows) do row:SetHeight(height);row:SetPoint("TOPLEFT",0,-(i-1)*height) end
 list:Refresh(true)
end
local function LayoutHistoryRows(list,x)
 local row=list.rows[1]
 local metaTop=math.max(44,12+row.title:GetHeight()+4)
 for _,item in ipairs(list.rows) do item.meta:SetPoint("TOPLEFT",x,-metaTop) end
 SizeRows(list,math.max(80,math.ceil(metaTop+row.meta:GetHeight()+12)))
end
local EDITOR_HEIGHT = math.min(T.notesEditorMaxHeight, HEIGHT - T.notesWorkTop - T.notesContentInset)

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

function P:LayoutNoteColumns(header)
 if not self.list then return end
 local player,date=header.columns.player,header.columns.timestamp
 for _,row in ipairs(self.list.rows) do
  row.icon:ClearAllPoints();C.SetPoint(row.icon,"TOPLEFT",row.icon:GetParent(),"TOPLEFT",player.x+12,"notesRowIconTopleftY")
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT",player.x+50,"notesRowTitleTopleftY");row.title:SetWidth(player.width-56)
  row.meta:SetWidth(player.width-56)
  row.kind:ClearAllPoints();C.SetPoint(row.kind,"TOPLEFT",row.kind:GetParent(),"TOPLEFT",date.x+6,"notesRowKindTopleftY");row.kind:SetWidth(date.width-12)
  row.date:SetWidth(date.width-12)
  row.reason:SetWidth(CARD_WIDTH-player.x-50-T.notesCardRightInset)
 end
 self:LayoutNoteRows()
end
function P:LayoutHistoryColumns(header)
 if not self.historyList then return end
 local col=header.columns
 for _,row in ipairs(self.historyList.rows) do
  row.icon:ClearAllPoints();row.icon:SetPoint("LEFT",col.activity.x+12,0)
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT",col.activity.x+60,"notesRowTitleTopleftY2");row.title:SetWidth(col.activity.width-66)
  row.meta:SetWidth(col.activity.width-66)
  row.level:ClearAllPoints();row.level:SetPoint("LEFT",col.level.x+6,0);row.level:SetWidth(col.level.width-12)
  row.duration:ClearAllPoints();row.duration:SetPoint("LEFT",col.duration.x+6,0);row.duration:SetWidth(col.duration.width-12)
  row.roster:ClearAllPoints();row.roster:SetPoint("LEFT",col.teammates.x+6,0)
  row.date:ClearAllPoints();row.date:SetPoint("LEFT",col.completed.x+6,0);row.date:SetWidth(col.completed.width-12)
 end
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
 UI:SetText(row.meta,identity.classSpec~="" and (identity.specID and identity.classSpec:gsub("%-"," · ",1) or identity.classSpec) or L.unknown)
 UI:SetText(row.reason,r.reason~="" and r.reason or L.noReason)
 local label;for _,entry in ipairs(NOTE_TYPES) do if r.type==entry.key then label=entry.label end end
 UI:SetText(row.kind,label);UI:Color(row.kind,r.type=="positive" and T.good or r.type=="caution" and T.warning or T.muted)
 local dateColumn=P.noteHeader.columns.timestamp
 for kind,glyph in pairs(row.kindIcons) do glyph:SetShown(kind==r.type);if kind==r.type then glyph:ClearAllPoints();C.SetPoint(glyph,"TOPLEFT",glyph:GetParent(),"TOPLEFT",dateColumn.x+dateColumn.width-22-row.kind:GetStringWidth(),"notesGlyphTopleftY") end end
 UI:SetText(row.date,UI:DateText(r.timestamp))
end

-- ---------------------------------------------------------------- 构建

function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(T.notesSidebarWidth,HEIGHT);rail:SetPoint("TOPLEFT");self.rail=rail
 self.tabs={};self.tabSelection=C.Selection(rail,{radius=8,mark=true})
 for i,entry in ipairs({{"all",S("全部记录","All notes")},{"positive",S("推荐","Positive")},{"neutral",S("中性","Neutral")},{"caution",S("拉黑","Blocked")},{"history",S("历史队友","History")}}) do
  local button=C.Button(rail,entry[2],T.notesSidebarWidth,function() P:SelectTab(entry[1]) end,{height=60,radius=8,fontSize="font16",lineHeight="line22",selectionFill=false});button:SetTextColors(T.muted,T.text,T.onSecondaryContainer);button:SetFrameLevel(self.tabSelection:GetFrameLevel()+1)
  button.order=i;button.tabY=-12-(i-1)*64-(i==5 and 20 or 0);button:SetPoint("TOPLEFT",0,button.tabY);button.label:ClearAllPoints();C.SetPoint(button.label,"LEFT",button.label:GetParent(),"LEFT","notesButtonLabelLeftX",0);C.ApplyStyle(button.label,{width="notesButtonLabelWidth"});button.label:SetWordWrap(false);C.SetLineHeight(button.label,"line22",true)
  local glyph=entry[1]=="all" and "friend" or entry[1]=="positive" and "heart" or entry[1]=="caution" and "caution" or entry[1]=="history" and "history" or "book"
  button.glyph=C.Glyph(button,glyph,T.notesButtonGlyphWidth);C.ApplyStyle(button.glyph,{width="notesButtonGlyphWidth",height="notesButtonGlyphHeight"});C.SetPoint(button.glyph,"LEFT",button.glyph:GetParent(),"LEFT","notesButtonGlyphLeftX",0)
  button.icon=button.glyph
  button.count=C.Text(button,"","font14","dim",T.notesButtonCountWidth);C.ApplyStyle(button.count,{width="notesButtonCountWidth"});C.SetPoint(button.count,"RIGHT",button.count:GetParent(),"RIGHT","notesButtonCountRightX",0);button.count:SetJustifyH("RIGHT");C.SetLineHeight(button.count,"line20",true);self.tabs[entry[1]]=button
 end
 local main=CreateFrame("Frame",nil,root);main:SetSize(MAIN_WIDTH,HEIGHT);main:SetPoint("TOPLEFT",T.notesMainX,0);C.Panel(main,"surfaceLow","notesPanelRadius");self.main=main
 self.pageTitle=C.Text(main,L.notes,"font24");C.SetLineHeight(self.pageTitle,"line32",true);self.pageTitle:SetPoint("TOPLEFT",T.notesContentInset,-T.notesContentInset)
 self.toolbar=CreateFrame("Frame",nil,main);self.toolbar:SetSize(BODY_WIDTH,T.notesToolbarHeight);C.SetPoint(self.toolbar,"TOPLEFT",self.toolbar:GetParent(),"TOPLEFT",T.notesContentInset,"notesToolbarTopleftY")
 self.search=C.Edit(self.toolbar,CARD_WIDTH,T.notesSearchHeight);C.ApplyStyle(self.search,{height="notesSearchHeight"});self.search:SetPoint("LEFT")
 self.searchHint=C.Text(self.search,L.noteSearch,"font14","dim");C.SetPoint(self.searchHint,"LEFT",self.searchHint:GetParent(),"LEFT","notesSearchHintLeftX",0);C.SetLineHeight(self.searchHint,"line20",true)
 self.search.box:HookScript("OnTextChanged",function() P:OnSearchChanged() end)
 self.search.box:HookScript("OnEditFocusGained",function() P.searchHint:Hide() end)
 self.search.box:HookScript("OnEditFocusLost",function() P.searchHint:SetShown(P.search.box:GetText()=="") end)
 self.addButton=C.Button(self.toolbar,L.add,T.notesAddButtonWidth,function() P:OpenAdd() end);C.ApplyStyle(self.addButton,{width="notesAddButtonWidth"});self.addButton:SetPrimary(true);self.addButton:SetPoint("RIGHT");self.addButton.label:ClearAllPoints();C.SetPoint(self.addButton.label,"LEFT",self.addButton.label:GetParent(),"LEFT","notesAddButtonLabelLeftX",0)
 self.addButton.icon=C.Glyph(self.addButton,"plus",T.notesAddButtonIconWidth);C.ApplyStyle(self.addButton.icon,{width="notesAddButtonIconWidth",height="notesAddButtonIconHeight"});C.SetPoint(self.addButton.icon,"LEFT",self.addButton.icon:GetParent(),"LEFT","notesAddButtonIconLeftX",0);self.addButton:SetWidth(math.ceil(self.addButton.label:GetStringWidth())+56)
 self.exportButton=C.Button(self.toolbar,L.export,T.notesExportButtonWidth,function() P:DoExport() end);C.ApplyStyle(self.exportButton,{width="notesExportButtonWidth"});self.exportButton:SetWidth(self.exportButton.label:GetStringWidth()+34);C.SetPoint(self.exportButton,"RIGHT",self.addButton,"LEFT","notesExportButtonRightX",0)
 self.importButton=C.Button(self.toolbar,L.import,T.notesImportButtonWidth,function() P:OpenTransfer("import") end);C.ApplyStyle(self.importButton,{width="notesImportButtonWidth"});self.importButton:SetWidth(self.importButton.label:GetStringWidth()+34);C.SetPoint(self.importButton,"RIGHT",self.exportButton,"LEFT","notesImportButtonRightX",0)
 self.left=CreateFrame("Frame",nil,main);self.left:SetSize(T.notesListWidth,HEIGHT-T.notesWorkTop-T.notesContentInset);self.left:SetPoint("TOPLEFT",T.notesContentInset,-T.notesWorkTop)
 self.noteHeader=C.TableHeader(self.left,{
  {key="player",label=S("玩家记录","Player notes"),width="notesColumnPlayerWidth264",min="notesColumnPlayerMin180"},
  {key="timestamp",label=S("类型 / 时间","Type / Date"),width="notesColumnTimestampWidth144",min="notesColumnTimestampMin132",align="RIGHT",sortable=true},
 },{onLayout=function(header) P:LayoutNoteColumns(header) end,onSort=function() P:RefreshList() end})
 self.noteHeader:SetPoint("TOPLEFT");self.listTitle=self.noteHeader.labels.player
 self.countText=C.Text(main,"","font14","dim");self.countText:SetPoint("TOPRIGHT",-T.notesContentInset,-T.notesContentInset-8);C.SetLineHeight(self.countText,"line20",true)
 self.list=C.List(self.left,T.notesListWidth,LIST_HEIGHT,T.notesRowHeight,function(key,button) P:OnSelect(key,button) end);C.SetPoint(self.list,"TOPLEFT",self.list:GetParent(),"TOPLEFT",0,"notesListTopleftY");self.list.selectionMark=false
 self.list:SetRowInitializer(function(row)
  UI:BindTooltipArea(row,.25,
   function(r) return r:IsEnabled() and r.key and r._hitVisible and P.list.clip:IsMouseOver() end,
   function(r) if P.list.selectedKey~=r.key then UI.Tooltip:ShowNote(r,r.key) end end)
  row.icon=C.Icon(row,T.notesRowIconWidth);C.ApplyStyle(row.icon,{width="notesRowIconWidth",height="notesRowIconHeight"});C.SetPoint(row.icon,"TOPLEFT",row.icon:GetParent(),"TOPLEFT","notesRowIconTopleftX","notesRowIconTopleftY")
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","notesRowTitleTopleftX","notesRowTitleTopleftY");row.title:SetWidth(CARD_WIDTH-T.notesCardRightInset-132-8-50);C.SetFont(row.title,"listTitleSize");C.SetLineHeight(row.title,"listTitleLineHeight",true)
  row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","notesRowMetaTopleftX","notesRowMetaTopleftY");row.meta:SetWidth(CARD_WIDTH-T.notesCardRightInset-132-8-50)
  row.reason=C.Text(row,"","font14","muted",CARD_WIDTH-50-T.notesCardRightInset);C.SetPoint(row.reason,"TOPLEFT",row.reason:GetParent(),"TOPLEFT","notesRowReasonTopleftX","notesRowReasonTopleftY");row.reason:SetMaxLines(1);C.SetLineHeight(row.reason,"line20",true)
  row.kind=C.Text(row,"","font14","muted",T.notesRowKindWidth);C.ApplyStyle(row.kind,{width="notesRowKindWidth"});C.SetPoint(row.kind,"TOPRIGHT",row.kind:GetParent(),"TOPRIGHT","notesRowKindToprightX","notesRowKindToprightY");row.kind:SetJustifyH("RIGHT");C.SetLineHeight(row.kind,"line22",true)
  row.kindIcons={}
  for _,entry in ipairs(NOTE_TYPES) do local glyph=C.Glyph(row,entry.key=="positive" and "heart" or entry.key=="caution" and "caution" or "book",T.notesGlyphWidth,entry.key=="positive" and T.good or entry.key=="caution" and T.warning or T.muted);C.ApplyStyle(glyph,{width="notesGlyphWidth",height="notesGlyphHeight"});C.SetPoint(glyph,"TOPRIGHT",glyph:GetParent(),"TOPRIGHT",-14-(zh and 26 or 68),"notesGlyphToprightY");glyph:Hide();row.kindIcons[entry.key]=glyph end
  row.date=C.Text(row,"","font14","dim",T.notesRowDateWidth);C.ApplyStyle(row.date,{width="notesRowDateWidth"});C.SetPoint(row.date,"TOPRIGHT",row.date:GetParent(),"TOPRIGHT","notesRowDateToprightX","notesRowDateToprightY");row.date:SetJustifyH("RIGHT");C.SetLineHeight(row.date,"line20",true)
  local metaTop=math.max(40,8+row.title:GetHeight()+4)
  C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","notesRowMetaTopleftX",-metaTop);C.SetPoint(row.date,"TOPRIGHT",row.date:GetParent(),"TOPRIGHT","notesRowDateToprightX",-metaTop)
  C.SetPoint(row.reason,"TOPLEFT",row.reason:GetParent(),"TOPLEFT","notesRowReasonTopleftX",-math.max(68,metaTop+row.meta:GetHeight()+4))
 end)
 local empty=CreateFrame("Frame",nil,self.left);empty:SetSize(CARD_WIDTH,T.notesEmptyHeight);empty:SetPoint("TOPLEFT",self.list,"TOPLEFT");self.emptyState=empty
 self.emptyTitle=C.Text(empty,L.notesEmptyTitle,"font18","muted",CARD_WIDTH-24);C.SetLineHeight(self.emptyTitle,"line24",true);self.emptyTitle:SetPoint("CENTER");self.emptyTitle:SetJustifyH("CENTER")
 self.editorEmpty=C.Text(main,S("选择玩家查看记录","Select a player to view their note"),"font18","dim",DRAWER_W-32);C.SetLineHeight(self.editorEmpty,"line24",true);self.editorEmpty:SetPoint("CENTER",main,"TOPLEFT",EDITOR_X-T.notesMainX+DRAWER_W/2,-T.notesWorkTop-(HEIGHT-T.notesWorkTop-T.notesContentInset)/2);self.editorEmpty:SetJustifyH("CENTER")
 local editor=CreateFrame("Frame",nil,main);editor:SetSize(DRAWER_W,EDITOR_HEIGHT);editor:SetPoint("TOPLEFT",EDITOR_X-T.notesMainX,-T.notesWorkTop);C.Panel(editor,T.container,"notesPanelRadius2");self.editor=editor;editor:Hide()
 local inner=DRAWER_W-32;local half=(inner-12)/2
 self.eTitle=C.Text(editor,L.edit,"font18","text");C.SetPoint(self.eTitle,"TOPLEFT",self.eTitle:GetParent(),"TOPLEFT","notesETitleTopleftX","notesETitleTopleftY");C.SetLineHeight(self.eTitle,"line24",true)
 self.eClose=C.Button(editor,"",T.notesECloseWidth,function() P:CloseEditor() end);C.ApplyStyle(self.eClose,{width="notesECloseWidth"});C.Glyph(self.eClose,"close",T.notesGlyphWidth2):SetPoint("CENTER");C.SetPoint(self.eClose,"TOPRIGHT",self.eClose:GetParent(),"TOPRIGHT","notesECloseToprightX","notesECloseToprightY")
 self.eNameLabel=C.Text(editor,S("玩家","Player"),"font14","muted");C.SetPoint(self.eNameLabel,"TOPLEFT",self.eNameLabel:GetParent(),"TOPLEFT","notesENameLabelTopleftX","notesENameLabelTopleftY");C.SetLineHeight(self.eNameLabel,"line20",true)
 self.eName=C.Edit(editor,inner,T.notesENameHeight);C.ApplyStyle(self.eName,{height="notesENameHeight"});C.SetPoint(self.eName,"TOPLEFT",self.eName:GetParent(),"TOPLEFT","notesENameTopleftX","notesENameTopleftY")
 self.eNameHint=C.Text(self.eName,L.notesIdentityHint,"font14","dim",inner-24);C.SetPoint(self.eNameHint,"LEFT",self.eNameHint:GetParent(),"LEFT","notesENameHintLeftX",0);C.SetLineHeight(self.eNameHint,"line20",true)
 self.eName.box:HookScript("OnTextChanged",function() DraftChanged();P.eNameHint:SetShown(P.eName.box:GetText()=="") end)
 self.eAvatar=C.Icon(editor,T.notesEAvatarWidth);C.ApplyStyle(self.eAvatar,{width="notesEAvatarWidth",height="notesEAvatarHeight"});C.SetPoint(self.eAvatar,"TOPLEFT",self.eAvatar:GetParent(),"TOPLEFT","notesEAvatarTopleftX","notesEAvatarTopleftY")
 self.eIdentity=C.Text(editor,"","font16","text",inner-52);C.SetPoint(self.eIdentity,"TOPLEFT",self.eIdentity:GetParent(),"TOPLEFT","notesEIdentityTopleftX","notesEIdentityTopleftY");self.eIdentity:SetWordWrap(false);C.SetLineHeight(self.eIdentity,"line22",true)
 self.eRealm=C.Text(editor,"","font14","muted",inner-52);C.SetPoint(self.eRealm,"TOPLEFT",self.eRealm:GetParent(),"TOPLEFT","notesERealmTopleftX","notesERealmTopleftY");C.SetLineHeight(self.eRealm,"line20",true)
 self.classLabel=C.Text(editor,S("职业","Class"),"font14","muted");C.SetPoint(self.classLabel,"TOPLEFT",self.classLabel:GetParent(),"TOPLEFT","notesClassLabelTopleftX","notesClassLabelTopleftY");C.SetLineHeight(self.classLabel,"line20",true)
 self.specLabel=C.Text(editor,S("专精","Specialization"),"font14","muted");C.SetPoint(self.specLabel,"TOPLEFT",self.specLabel:GetParent(),"TOPLEFT",28+half,"notesSpecLabelTopleftY");C.SetLineHeight(self.specLabel,"line20",true)
 self.classChoice=C.Choice(editor,half,function() return P:ClassItems() end,function(value) DraftChanged();state.identityEdited=true;state.legacyClassSpec=nil;state.recordClass=value or nil;state.recordSpec=nil;P:SyncSpec() end);C.SetPoint(self.classChoice,"TOPLEFT",self.classChoice:GetParent(),"TOPLEFT","notesClassChoiceTopleftX","notesClassChoiceTopleftY");C.ApplyStyle(self.classChoice,{height="notesClassChoiceHeight"})
 self.specChoice=C.Choice(editor,half,function() return P:SpecItems() end,function(value) DraftChanged();state.identityEdited=true;state.legacyClassSpec=nil;state.recordSpec=value or nil;P:SyncSpec() end);C.SetPoint(self.specChoice,"TOPLEFT",self.specChoice:GetParent(),"TOPLEFT",28+half,"notesSpecChoiceTopleftY");C.ApplyStyle(self.specChoice,{height="notesSpecChoiceHeight"})
 self.typeLabel=C.Text(editor,S("记录类型","Note type"),"font14","muted");C.SetLineHeight(self.typeLabel,"line20",true)
 self.typeSwitch=CreateFrame("Frame",nil,editor);self.typeSwitch:SetSize(inner,T.notesTypeSwitchHeight);C.SetPoint(self.typeSwitch,"TOPLEFT",self.typeSwitch:GetParent(),"TOPLEFT","notesTypeSwitchTopleftX","notesTypeSwitchTopleftY");C.Panel(self.typeSwitch,"surfaceLow","notesPanelRadius3")
 self.typeButtons={};for i,entry in ipairs(NOTE_TYPES) do local w=(inner-14)/3;local button=C.Button(self.typeSwitch,entry.label,w,function() DraftChanged();state.recordType=entry.key;P:SyncType() end,{variant="compact",textColor=T.text});C.SetPoint(button,"TOPLEFT",button:GetParent(),"TOPLEFT",3+(i-1)*(w+4),"notesButtonTopleftY");button.label:ClearAllPoints();C.SetPoint(button.label,"CENTER",button.label:GetParent(),"CENTER","notesButtonLabelCenterX",0);button.icon=C.Glyph(button,entry.key=="positive" and "heart" or entry.key=="caution" and "caution" or "book",T.notesButtonIconWidth);C.ApplyStyle(button.icon,{width="notesButtonIconWidth",height="notesButtonIconHeight"});button.icon:SetPoint("CENTER",-(button.label:GetStringWidth()+6)/2,0);self.typeButtons[entry.key]=button end
 self.eReasonLabel=C.Text(editor,L.reason,"font14","muted");C.SetPoint(self.eReasonLabel,"TOPLEFT",self.eReasonLabel:GetParent(),"TOPLEFT","notesEReasonLabelTopleftX","notesEReasonLabelTopleftY");C.SetLineHeight(self.eReasonLabel,"line20",true)
 self.eReason=C.Edit(editor,inner,T.notesEReasonHeight,true);C.ApplyStyle(self.eReason,{height="notesEReasonHeight"});C.SetPoint(self.eReason,"TOPLEFT",self.eReason:GetParent(),"TOPLEFT","notesEReasonTopleftX","notesEReasonTopleftY");self.eReason:SetPlaceholder(S("写下当时发生的事","Describe what happened"));C.SetLineHeight(self.eReason.box,"line20")
 self.eReason.box:HookScript("OnTextChanged",DraftChanged)
 self.eDate=C.Text(editor,"","font14","dim",inner);C.SetPoint(self.eDate,"TOPLEFT",self.eDate:GetParent(),"TOPLEFT","notesEDateTopleftX","notesEDateTopleftY");C.SetLineHeight(self.eDate,"line20",true)
 self.eStatus=C.Text(editor,"","font14","muted",inner);C.SetPoint(self.eStatus,"TOPLEFT",self.eStatus:GetParent(),"TOPLEFT","notesEStatusTopleftX","notesEStatusTopleftY");self.eStatus:SetMaxLines(2);C.SetLineHeight(self.eStatus,"line20")
 self.eSave=C.Button(editor,L.save,T.notesESaveWidth,function() P:Save() end);C.ApplyStyle(self.eSave,{width="notesESaveWidth"});self.eSave:SetPrimary(true);C.SetPoint(self.eSave,"BOTTOMRIGHT",self.eSave:GetParent(),"BOTTOMRIGHT","notesESaveBottomrightX","notesESaveBottomrightY")
 self.eCancel=C.Button(editor,L.cancel,T.notesECancelWidth,function() P:CloseEditor() end);C.ApplyStyle(self.eCancel,{width="notesECancelWidth"});C.SetPoint(self.eCancel,"RIGHT",self.eSave,"LEFT","notesECancelRightX",0)
 self.eDelete=C.Button(editor,S("删除记录","Delete note"),T.notesEDeleteWidth,function() P:Delete() end);C.ApplyStyle(self.eDelete,{width="notesEDeleteWidth"});self.eDelete:SetWidth(math.max(96,math.ceil(self.eDelete.label:GetStringWidth())+32));self.eDelete:SetTextColors(T.muted,T.accent);C.SetPoint(self.eDelete,"BOTTOMLEFT",self.eDelete:GetParent(),"BOTTOMLEFT","notesEDeleteBottomleftX","notesEDeleteBottomleftY")
 self.historyFrame=CreateFrame("Frame",nil,main);self.historyFrame:SetSize(BODY_WIDTH,HEIGHT-76-T.notesContentInset);C.SetPoint(self.historyFrame,"TOPLEFT",self.historyFrame:GetParent(),"TOPLEFT",T.notesContentInset,"notesHistoryFrameTopleftY");self.historyFrame:Hide()
 self.historyCaption=C.Text(self.historyFrame,S("当前角色完成的大秘境","Mythic+ runs completed by this character"),"font14","muted");self.historyCaption:SetPoint("TOPLEFT");C.SetLineHeight(self.historyCaption,"line20",true)
 self.historyHeader=C.TableHeader(self.historyFrame,{
  {key="activity",label=S("活动","Activity"),width="notesColumnActivityWidth260",min="notesColumnActivityMin180"},
  {key="level",label=S("层数","Level"),width="notesColumnLevelWidth76",min="notesColumnLevelMin64",align="CENTER",sortable=true},
  {key="duration",label=S("耗时","Duration"),width="notesColumnDurationWidth108",min="notesColumnDurationMin90",align="CENTER",sortable=true},
  {key="teammates",label=S("队友","Teammates"),width="notesColumnTeammatesWidth165",min="notesColumnTeammatesMin147"},
  {key="completed",label=S("完成时间","Completed"),width="notesColumnCompletedWidth172",min="notesColumnCompletedMin144",sortable=true},
 },{onLayout=function(header) P:LayoutHistoryColumns(header) end,onSort=function() P:RefreshHistory() end})
 C.SetPoint(self.historyHeader,"TOPLEFT",self.historyHeader:GetParent(),"TOPLEFT",0,"notesHistoryHeaderTopleftY");self.teammateHeading=self.historyHeader.labels.teammates
 self.historyList=C.List(self.historyFrame,BODY_WIDTH,HEIGHT-148-T.notesContentInset,80,function(index) P:OpenRun(index) end);C.SetPoint(self.historyList,"TOPLEFT",self.historyList:GetParent(),"TOPLEFT",0,"notesHistoryListTopleftY")
 self.historyList:SetRowInitializer(function(row)
  row.icon=C.Icon(row,T.notesRowIconWidth2);C.ApplyStyle(row.icon,{width="notesRowIconWidth2",height="notesRowIconHeight2"});C.SetPoint(row.icon,"LEFT",row.icon:GetParent(),"LEFT","notesRowIconLeftX",0)
  row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","notesRowTitleTopleftX2","notesRowTitleTopleftY2");C.SetFont(row.title,"listTitleSize");C.SetLineHeight(row.title,"listTitleLineHeight",true)
  row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","notesRowMetaTopleftX2","notesRowMetaTopleftY2");row.meta:Hide()
  row.level=C.Text(row,"","font14","muted");row.level:SetJustifyH("CENTER");C.SetLineHeight(row.level,"line20",true)
  row.duration=C.Text(row,"","font14","muted");row.duration:SetJustifyH("CENTER");C.SetLineHeight(row.duration,"line20",true)
  row.roster=C.Roster(row,23,5)
  row.date=C.Text(row,"","font14","muted",T.notesRowDateWidth2);C.ApplyStyle(row.date,{width="notesRowDateWidth2"});C.SetPoint(row.date,"RIGHT",row.date:GetParent(),"RIGHT","notesRowDateRightX",0);row.date:SetJustifyH("LEFT");C.SetLineHeight(row.date,"line20",true)
  C.Glyph(row,"chevron",T.notesGlyphWidth3):SetPoint("RIGHT",-16,0)
  C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","notesRowMetaTopleftX2",-math.max(44,12+row.title:GetHeight()+4))
 end)
 self.historyEmpty=C.Text(self.historyFrame,L.historyEmpty,"font16","dim",BODY_WIDTH);C.SetPoint(self.historyEmpty,"TOP",self.historyEmpty:GetParent(),"TOP",0,"notesHistoryEmptyTopY");self.historyEmpty:SetJustifyH("CENTER")
 self:LayoutRows()
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
 UI:Color(self.eStatus,kind=="error" and T.warning or kind=="success" and T.good or T.muted)
 self:LayoutEditor()
end
function P:SelectTab(tab,skipDefault)
 local previous=state.tab;local changed=previous~=nil and previous~=tab
 if changed then self.noteHeader:StopDrag(false);self.historyHeader:StopDrag(false) end
 local direction=previous and self.tabs[tab].order<self.tabs[previous].order and -1 or 1
 state.tab=tab;local history=tab=="history"
 for key,button in pairs(self.tabs) do button:SetActive(key==tab);UI:Color(button.label,key==tab and T.text or T.muted);button.glyph:SetSelected(key==tab) end
 local selected=self.tabs[tab];self.tabSelection:Select(0,selected.tabY,T.notesSidebarWidth,selected:GetHeight(),self.frame:IsVisible())
 self:CloseTransfer();if changed then self:CloseEditor(true) end
 UI.Motion:FinishPlacement(history and self.left or self.historyFrame)
 self.toolbar:SetShown(not history);self.left:SetShown(not history);self.historyFrame:SetShown(history);self.editorEmpty:SetShown(not history and state.panel==nil)
 self.countText:SetShown(not history)
 UI:SetText(self.pageTitle,history and L.history or L.notes)
 self:RefreshCounts()
 if history then self:RefreshHistory() else self:RefreshList();local keys=self.list.ids;if not skipDefault and keys and keys[1] and state.panel==nil then self:OpenEdit(keys[1]) end end
 if changed then UI.Motion:Reveal(history and self.historyFrame or self.left,"TOPLEFT",self.main,"TOPLEFT",T.notesContentInset,history and -76 or -T.notesWorkTop,direction*32,0,.18) end
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
  if texture then UI.context:SetGameTexture(row.icon,texture) else UI:SetActivityIcon(row.icon,run.activity or run) end
  UI:SetText(row.title,run.mapName or L.unknown)
  local duration=RunDuration(run)
  UI:SetText(row.level,run.level and "+"..run.level or "—")
  UI:SetText(row.duration,duration and (math.floor(duration/60)..":"..("%02d"):format(duration%60)) or "—")
  row.roster:Update(run.members,nil,5);UI:SetText(row.date,UI:DateText(run.completedAt or run.startedAt))
 end);self.historyEmpty:SetShown(#indices==0)
end
function P:OpenRun(index)
 local run=self.runs[index];if not run then return end
 local modal=UI:OpenModal("history",L.history,560,576);self.historyModal=modal
 if not modal.built then
  modal.caption=C.Text(modal.content,"","font14","muted",T.notesModalCaptionWidth);C.ApplyStyle(modal.caption,{width="notesModalCaptionWidth"});modal.caption:SetPoint("TOPLEFT");C.SetLineHeight(modal.caption,"line22",true)
  modal.header=C.TableHeader(modal.content,{
   {key="player",label=S("玩家","Player"),width="notesColumnPlayerWidth364",min="notesColumnPlayerMin220"},
   {key="actions",label=S("操作","Actions"),width="notesColumnActionsWidth136",min="notesColumnActionsMin124",align="RIGHT"},
  },{onLayout=function(header) P:LayoutHistoryMemberColumns(header) end})
  C.SetPoint(modal.header,"TOPLEFT",modal.header:GetParent(),"TOPLEFT",0,"notesModalHeaderTopleftY")
  modal.list=C.List(modal.content,T.notesModalListWidth,T.notesModalListHeight,80,function(memberIndex)
   local member=P.historyRun.members[memberIndex];local key=A:PlayerKey(member.name,member.realm)
   modal:Close();P:SelectTab("all")
   if A.Notes:Find(key) then P:OpenEdit(key);P.list:Select(key,true) else P:OpenAdd({name=member.name,realm=member.realm,class=member.class,specID=member.specID}) end
  end);C.ApplyStyle(modal.list,{width="notesModalListWidth",height="notesModalListHeight"});C.SetPoint(modal.list,"TOPLEFT",modal.list:GetParent(),"TOPLEFT",0,"notesModalListTopleftY")
  for _,row in ipairs(modal.list.rows) do
   row.icon=C.Icon(row,T.notesRowIconWidth3);C.ApplyStyle(row.icon,{width="notesRowIconWidth3",height="notesRowIconHeight3"});C.SetPoint(row.icon,"LEFT",row.icon:GetParent(),"LEFT","notesRowIconLeftX",0)
   row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","notesRowTitleTopleftX3","notesRowTitleTopleftY2");row.title:SetWidth(T.notesRowTitleWidth);C.SetFont(row.title,"listTitleSize");C.SetLineHeight(row.title,"listTitleLineHeight",true)
   row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","notesRowMetaTopleftX3","notesRowMetaTopleftY2");row.meta:SetWidth(T.notesRowMetaWidth)
   row.action=C.Text(row,"","font14","dim",T.notesRowActionWidth);C.ApplyStyle(row.action,{width="notesRowActionWidth"});C.SetPoint(row.action,"RIGHT",row.action:GetParent(),"RIGHT","notesRowActionRightX",0);row.action:SetJustifyH("RIGHT");C.SetLineHeight(row.action,"line20",true)
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
	UI:SetText(self.countText, S("%d 条记录","%d notes"):format(#keys))
	if state.editKey ~= nil then
		local found = false
		for _, k in ipairs(keys) do
			if k == state.editKey then found = true break end
		end
		if not found and not notes:Find(state.editKey) then P:ShowMissing() end
	end
end

function P:OnSearchChanged()
	state.search = self.search.box:GetText() or ""
	self.searchHint:SetShown(state.search == "" and not self.search.box:HasFocus())
	self:RefreshList()
end

function P:LayoutNoteRows()
 local row=self.list.rows[1]
 local player,date=self.noteHeader.columns.player,self.noteHeader.columns.timestamp
 local metaTop=math.max(40,8+row.title:GetHeight()+4)
 local reasonTop=math.max(68,metaTop+row.meta:GetHeight()+4)
 for _,item in ipairs(self.list.rows) do
  item.meta:ClearAllPoints();item.meta:SetPoint("TOPLEFT",player.x+50,-metaTop)
  item.date:ClearAllPoints();item.date:SetPoint("TOPLEFT",date.x+6,-metaTop)
  item.reason:ClearAllPoints();item.reason:SetPoint("TOPLEFT",player.x+50,-reasonTop)
 end
 SizeRows(self.list,math.max(T.notesRowHeight,math.ceil(reasonTop+row.reason:GetHeight()+8)))
end
function P:LayoutRows()
 self.noteHeader:Layout(CARD_WIDTH)
 self.historyHeader:Layout(BODY_WIDTH-C.listRightInset-32)
 if self.historyModal then self.historyModal.header:Layout(self.historyModal.list:GetWidth()-C.listRightInset) end
end
function P:LayoutFont()
 self.addButton:SetWidth(math.ceil(self.addButton.label:GetStringWidth())+56)
 self.importButton:SetWidth(math.ceil(self.importButton.label:GetStringWidth())+34)
 self.exportButton:SetWidth(math.ceil(self.exportButton.label:GetStringWidth())+34)
 self.eDelete:SetWidth(math.max(96,math.ceil(self.eDelete.label:GetStringWidth())+32))
 self:LayoutRows();self.list:Refresh()
 if self.tSelect then
  self.tSelect:SetWidth(math.max(128,math.ceil(self.tSelect.label:GetStringWidth())+32))
  self.tImport:SetWidth(math.max(104,math.ceil(self.tImport.label:GetStringWidth())+32))
  self.tExport:SetWidth(math.max(104,math.ceil(self.tExport.label:GetStringWidth())+32))
 end
end

function P:LayoutSize(width,height)
 WIDTH,HEIGHT=width,height
 LEFT=T.notesMainX+T.notesContentInset
 EDITOR_X=LEFT+T.notesListWidth+T.notesColumnGap;CARD_WIDTH=T.notesListWidth-C.listRightInset
 MAIN_WIDTH=WIDTH-T.notesMainX;BODY_WIDTH=MAIN_WIDTH-T.notesContentInset*2
 DRAWER_W=BODY_WIDTH-T.notesListWidth-T.notesColumnGap
 LIST_HEIGHT=HEIGHT-T.notesWorkTop-32-T.notesContentInset;EDITOR_HEIGHT=math.min(T.notesEditorMaxHeight,HEIGHT-T.notesWorkTop-T.notesContentInset)
 self.rail:SetHeight(HEIGHT);self.main:SetSize(MAIN_WIDTH,HEIGHT);self.toolbar:SetWidth(BODY_WIDTH)
 self.left:SetHeight(HEIGHT-T.notesWorkTop-T.notesContentInset);self.list:SetViewport(LIST_HEIGHT)
 self.editor:SetSize(DRAWER_W,EDITOR_HEIGHT);self.editorEmpty:SetWidth(DRAWER_W-32)
 self.editorEmpty:SetPoint("CENTER",self.main,"TOPLEFT",EDITOR_X-T.notesMainX+DRAWER_W/2,-T.notesWorkTop-(HEIGHT-T.notesWorkTop-T.notesContentInset)/2)
 local inner=DRAWER_W-32;local half=(inner-12)/2
 self.eName:SetWidth(inner);self.eNameHint:SetWidth(inner-24)
 self.eIdentity:SetWidth(inner-52);self.eRealm:SetWidth(inner-52)
 self.classChoice:SetWidth(half);self.specChoice:SetWidth(half);self.typeSwitch:SetWidth(inner)
 for i,entry in ipairs(NOTE_TYPES) do
  local button=self.typeButtons[entry.key];local w=(inner-14)/3
  button:SetWidth(w);C.SetPoint(button,"TOPLEFT",button:GetParent(),"TOPLEFT",3+(i-1)*(w+4),"notesButtonTopleftY")
 end
 self.eReason:SetWidth(inner);self.eDate:SetWidth(inner);self.eStatus:SetWidth(inner)
 self:LayoutEditor()
 self.historyFrame:SetSize(BODY_WIDTH,HEIGHT-76-T.notesContentInset);self.historyList:SetWidth(BODY_WIDTH)
 self.historyList:SetViewport(HEIGHT-148-T.notesContentInset);self.historyEmpty:SetWidth(BODY_WIDTH)
 self:LayoutRows()
end

function P:LayoutAppearance(width,height)
 self:LayoutSize(width,height)
 self.rail:SetWidth(T.notesSidebarWidth)
 self.main:SetPoint("TOPLEFT",T.notesMainX,0)
 self.left:SetWidth(T.notesListWidth);self.left:SetPoint("TOPLEFT",T.notesContentInset,-T.notesWorkTop)
 self.list:SetWidth(T.notesListWidth)
 self.editor:SetPoint("TOPLEFT",EDITOR_X-T.notesMainX,-T.notesWorkTop)
 self:LayoutFont()
end

function P:LayoutEditor()
 if not state.panel then return end
 local add,missing=state.panel=="add",state.panel=="missing"
 local classTop=add and 156 or 128
 C.SetPoint(self.classLabel,"TOPLEFT",self.classLabel:GetParent(),"TOPLEFT","notesClassLabelTopleftX",-classTop)
 self.specLabel:SetPoint("TOPLEFT",28+(DRAWER_W-44)/2,-classTop)
 C.SetPoint(self.classChoice,"TOPLEFT",self.classChoice:GetParent(),"TOPLEFT","notesClassChoiceTopleftX",-classTop-32)
 self.specChoice:SetPoint("TOPLEFT",28+(DRAWER_W-44)/2,-classTop-32)
 C.SetPoint(self.typeLabel,"TOPLEFT",self.typeLabel:GetParent(),"TOPLEFT","notesTypeLabelTopleftX",-classTop-92);C.SetPoint(self.typeSwitch,"TOPLEFT",self.typeSwitch:GetParent(),"TOPLEFT","notesTypeSwitchTopleftX",-classTop-124)
 C.SetPoint(self.eReasonLabel,"TOPLEFT",self.eReasonLabel:GetParent(),"TOPLEFT","notesEReasonLabelTopleftX",-classTop-172);C.SetPoint(self.eReason,"TOPLEFT",self.eReason:GetParent(),"TOPLEFT","notesEReasonTopleftX",-classTop-204)
 local statusHeight=math.max(24,self.eStatus:GetStringHeight())
 local reasonHeight=math.max(32,math.min(112,EDITOR_HEIGHT-64-classTop-204-(add and 12 or 48)-statusHeight))
 self.eReason:SetHeight(reasonHeight)
 C.SetPoint(self.eDate,"TOPLEFT",self.eDate:GetParent(),"TOPLEFT","notesEDateTopleftX",-classTop-204-reasonHeight-12)
 C.SetPoint(self.eStatus,"TOPLEFT",self.editor,"TOPLEFT","notesEStatusTopleftX",missing and -76 or -classTop-204-reasonHeight-(add and 12 or 48))
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
	if reveal~=false then UI.Motion:Reveal(P.editor,"TOPLEFT",P.main,"TOPLEFT",EDITOR_X-T.notesMainX,-T.notesWorkTop,12,0,.18) end
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
	ShowEditorChrome("edit",changed)
	UI:SetText(self.eIdentity,r.name);UI:SetText(self.eRealm,r.server);UI:SetText(self.eDate,S("记录于 ","Recorded ")..UI:DateText(r.timestamp))
	self.eReason.box:SetText(r.reason or "")
	UI:SetText(self.eStatus, "")
	SelectNote(key)
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
	ShowEditorChrome("add")
	UI:SetText(self.eIdentity,draft and draft.name or "");UI:SetText(self.eRealm,draft and draft.realm or "")
	self.eName.box:SetText(draft and draft.name and (draft.name..(draft.realm and "-"..draft.realm or "")) or "")
	self.eReason.box:SetText(draft and draft.reason or "")
	UI:SetText(self.eStatus, "")
	SelectNote(nil)
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
 self.tHint=C.Text(parent,L.importHelp,"font14","muted",T.notesTHintWidth);C.ApplyStyle(self.tHint,{width="notesTHintWidth"});self.tHint:SetPoint("TOPLEFT");self.tHint:SetWordWrap(true);C.SetLineHeight(self.tHint,"line20")
 self.tLabel=C.Text(parent,S("记录文本","Record text"),"font14","muted");C.SetLineHeight(self.tLabel,"line20",true);C.SetPoint(self.tLabel,"TOPLEFT",self.tHint,"BOTTOMLEFT",0,"notesTLabelTopleftY")
 self.tBox=C.Edit(parent,T.notesTBoxWidth,T.notesTBoxHeight,true,false,"modal");C.ApplyStyle(self.tBox,{width="notesTBoxWidth",height="notesTBoxHeight"});C.SetPoint(self.tBox,"TOPLEFT",self.tLabel,"BOTTOMLEFT",0,"notesTBoxTopleftY");C.SetLineHeight(self.tBox.box,"line22")
 self.tStatus=C.Text(parent,"","font14","accent",T.notesTStatusWidth);C.ApplyStyle(self.tStatus,{width="notesTStatusWidth"});C.SetPoint(self.tStatus,"TOPLEFT",self.tBox,"BOTTOMLEFT",0,"notesTStatusTopleftY");C.SetLineHeight(self.tStatus,"line20",true)
 self.tImport=C.Button(parent,L.import,T.notesTImportWidth,function() P:DoImport() end);C.ApplyStyle(self.tImport,{width="notesTImportWidth"});self.tImport:SetPrimary(true);self.tImport:SetPoint("BOTTOMRIGHT")
 self.tExport=C.Button(parent,L.export,T.notesTExportWidth,function() P:DoExport() end);C.ApplyStyle(self.tExport,{width="notesTExportWidth"});self.tExport:SetPrimary(true);self.tExport:SetPoint("BOTTOMRIGHT")
 self.tSelect=C.Button(parent,L.selectAll,T.notesTSelectWidth,function() P.tBox.box:SetFocus();P.tBox.box:HighlightText() end);C.ApplyStyle(self.tSelect,{width="notesTSelectWidth"});self.tSelect:SetPoint("BOTTOMLEFT")
 modal.onClose=function() P:CloseTransfer() end;modal.built=true
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
