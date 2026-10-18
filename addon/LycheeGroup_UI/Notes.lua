-- 荔枝笔记页:名单、编辑、导入导出。
-- v4 固定侧栏、记录列表与编辑区，共用真实记录及历史服务。
local A = _G.LycheeGroup
local UI = A.UI
local T, L = UI.Theme, UI.L
local C = UI.C

local P = {}
UI.pages.notes = P

local WIDTH, HEIGHT = T.contentWidth, T.contentHeight
local RAIL, MAIN_X, PAD = 208, 224, 24
local LEFT = MAIN_X + PAD
local MAIN_WIDTH = WIDTH - MAIN_X
local BODY_WIDTH = MAIN_WIDTH - PAD * 2
local GAP = 20
local DRAWER_W = BODY_WIDTH - 326 - GAP
local EDITOR_X = LEFT + 326 + GAP
local WORK_TOP = 116
local LIST_WIDTH=326
local CARD_WIDTH=LIST_WIDTH-C.listRightInset
local CARD_INSET=12
local CARD_RIGHT_INSET=12
local zh=GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
local NOTE_TYPES={{key="positive",label=S("推荐","Recommended")},{key="neutral",label=S("中性","Neutral")},{key="caution",label=S("拉黑","Blocked")}}
local ROW_HEIGHT = 88
local LIST_HEIGHT = HEIGHT - WORK_TOP - 28 - PAD
local EDITOR_HEIGHT = math.min(556, HEIGHT - WORK_TOP - PAD)

local state = {
	search = "",
	editKey = nil,
	draft = nil, -- {name,realm,reason,unit} 或空表(手动添加)
	unsub = nil,
	revision = 0,
}

local function CancelPending()
	state.revision = state.revision + 1
	local cancel = state.cancel
	state.cancel = nil
	if cancel then cancel() end
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
 for kind,glyph in pairs(row.kindIcons) do glyph:SetShown(kind==r.type);if kind==r.type then glyph:ClearAllPoints();glyph:SetPoint("TOPRIGHT",-16-row.kind:GetStringWidth(),-14.5) end end
 UI:SetText(row.date,UI:DateText(r.timestamp))
 local metaWidth=math.min(104,math.max(64,row.date:GetStringWidth(),row.kind:GetStringWidth()+20));row.title:SetWidth(CARD_WIDTH-CARD_RIGHT_INSET-metaWidth-8-50);row.meta:SetWidth(CARD_WIDTH-CARD_RIGHT_INSET-metaWidth-8-50)
end

-- ---------------------------------------------------------------- 构建

function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(RAIL,HEIGHT);rail:SetPoint("TOPLEFT")
 self.tabs={}
 for i,entry in ipairs({{"all",S("全部记录","All notes")},{"positive",S("推荐","Recommended")},{"neutral",S("中性","Neutral")},{"caution",S("拉黑","Blocked")},{"history",L.history}}) do
  local button=C.Navigation(rail,entry[2],RAIL,function() P:SelectTab(entry[1]) end,nil,{height=60,radius=8});button:SetPoint("TOPLEFT",0,-12-(i-1)*64-(i==5 and 20 or 0));button.label:ClearAllPoints();button.label:SetPoint("LEFT",52,0);button.label:SetWidth(100);button.label:SetWordWrap(true);button.label:SetHeight(0);C.SetLineHeight(button.label,22)
  local glyph=entry[1]=="all" and "friend" or entry[1]=="positive" and "heart" or entry[1]=="caution" and "caution" or entry[1]=="history" and "history" or "book"
  button.glyph=C.Glyph(button,glyph,24);button.glyph:SetPoint("LEFT",16,0)
  button.icon=button.glyph
  button.count=C.Text(button,"",14,T.dim,32);button.count:SetPoint("RIGHT",-16,0);button.count:SetJustifyH("RIGHT");C.SetLineHeight(button.count,20,true);self.tabs[entry[1]]=button
 end
 local main=CreateFrame("Frame",nil,root);main:SetSize(MAIN_WIDTH,HEIGHT);main:SetPoint("TOPLEFT",MAIN_X,0);C.Panel(main,T.surfaceLow,24);self.main=main
 self.pageTitle=C.Text(main,L.notes,24);C.SetLineHeight(self.pageTitle,32,true);self.pageTitle:SetPoint("TOPLEFT",PAD,-PAD)
 self.toolbar=CreateFrame("Frame",nil,main);self.toolbar:SetSize(BODY_WIDTH,44);self.toolbar:SetPoint("TOPLEFT",PAD,-64)
 self.search=C.Edit(self.toolbar,CARD_WIDTH,44);self.search:SetPoint("LEFT")
 self.searchHint=C.Text(self.search,L.noteSearch,14,T.dim);self.searchHint:SetPoint("LEFT",12,0);C.SetLineHeight(self.searchHint,20,true)
 self.search.box:HookScript("OnTextChanged",function() P:OnSearchChanged() end)
 self.search.box:HookScript("OnEditFocusGained",function() P.searchHint:Hide() end)
 self.search.box:HookScript("OnEditFocusLost",function() P.searchHint:SetShown(P.search.box:GetText()=="") end)
 self.addButton=C.Button(self.toolbar,L.add,120,function() P:OpenAdd() end);self.addButton:SetPrimary(true);self.addButton:SetPoint("RIGHT");self.addButton.label:ClearAllPoints();self.addButton.label:SetPoint("CENTER",12,0);C.Glyph(self.addButton,"plus",16):SetPoint("CENTER",-self.addButton.label:GetStringWidth()/2-4,0)
 self.exportButton=C.Button(self.toolbar,L.export,72,function() P:DoExport() end);self.exportButton:SetWidth(self.exportButton.label:GetStringWidth()+34);self.exportButton:SetPoint("RIGHT",self.addButton,"LEFT",-8,0)
 self.importButton=C.Button(self.toolbar,L.import,72,function() P:OpenTransfer("import") end);self.importButton:SetWidth(self.importButton.label:GetStringWidth()+34);self.importButton:SetPoint("RIGHT",self.exportButton,"LEFT",-8,0)
 self.left=CreateFrame("Frame",nil,main);self.left:SetSize(LIST_WIDTH,HEIGHT-WORK_TOP-PAD);self.left:SetPoint("TOPLEFT",PAD,-WORK_TOP)
 self.listTitle=C.Text(self.left,S("玩家记录","Player notes"),14,T.muted);self.listTitle:SetPoint("TOPLEFT",CARD_INSET,0);C.SetLineHeight(self.listTitle,20,true)
 self.countText=C.Text(self.left,"",14,T.dim);self.countText:SetPoint("TOPRIGHT",-C.listRightInset-CARD_RIGHT_INSET,0);C.SetLineHeight(self.countText,20,true)
 self.list=C.List(self.left,LIST_WIDTH,LIST_HEIGHT,ROW_HEIGHT,function(key,button) P:OnSelect(key,button) end);self.list:SetPoint("TOPLEFT",0,-28);self.list.selectionMark=false
 for _,row in ipairs(self.list.rows) do
  local area=CreateFrame("Frame",nil,row);area:SetPoint("TOPLEFT");area:SetPoint("BOTTOMLEFT");area:SetWidth(row:GetWidth()*.25);row.tooltipArea=area
  row:HookScript("OnSizeChanged",function(_,width) area:SetWidth(width*.25) end)
  area:SetScript("OnEnter",function()
   if not row:IsEnabled() or not row.key or not row._hitVisible or not P.list.clip:IsMouseOver() then return end
   local enter=row:GetScript("OnEnter");if enter then enter(row) end
   if P.list.selectedKey~=row.key then UI.Tooltip:ShowNote(row,row.key) end
  end)
  area:SetScript("OnLeave",function()
   if not row:IsMouseOver() then local leave=row:GetScript("OnLeave");if leave then leave(row) end end
   UI.Tooltip:LeaveOwner(row)
  end)
  area:SetScript("OnHide",function() if UI.Tooltip:IsOwned(row) then UI.Tooltip:Hide() end end)
  area:EnableMouse(false);area:EnableMouseMotion(true)
  row.icon=C.Icon(row,30);row.icon:SetPoint("TOPLEFT",12,-15)
  row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",50,-8);row.title:SetWidth(CARD_WIDTH-CARD_RIGHT_INSET-104-8-50);row.title:SetFont(T.font,T.listTitleSize,"");C.SetLineHeight(row.title,T.listTitleLineHeight,true)
  row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",50,-36);row.meta:SetWidth(CARD_WIDTH-CARD_RIGHT_INSET-104-8-50)
  row.reason=C.Text(row,"",14,T.muted,CARD_WIDTH-50-CARD_RIGHT_INSET);row.reason:SetPoint("TOPLEFT",50,-60);row.reason:SetMaxLines(1);C.SetLineHeight(row.reason,20,true)
  row.kind=C.Text(row,"",14,T.muted,104);row.kind:SetPoint("TOPRIGHT",-12,-8);row.kind:SetJustifyH("RIGHT");C.SetLineHeight(row.kind,22,true)
  row.kindIcons={}
  for _,entry in ipairs(NOTE_TYPES) do local glyph=C.Glyph(row,entry.key=="positive" and "heart" or entry.key=="caution" and "caution" or "book",12,entry.key=="positive" and T.good or entry.key=="caution" and T.warning or T.muted);glyph:SetPoint("TOPRIGHT",-14-(zh and 26 or 68),-13);glyph:Hide();row.kindIcons[entry.key]=glyph end
  row.date=C.Text(row,"",14,T.dim,104);row.date:SetPoint("TOPRIGHT",-12,-36);row.date:SetJustifyH("RIGHT");C.SetLineHeight(row.date,20,true)
 end
 local empty=CreateFrame("Frame",nil,self.left);empty:SetSize(CARD_WIDTH,220);empty:SetPoint("TOPLEFT",self.list,"TOPLEFT");self.emptyState=empty
 self.emptyTitle=C.Text(empty,L.notesEmptyTitle,18,T.muted,CARD_WIDTH-24);C.SetLineHeight(self.emptyTitle,24,true);self.emptyTitle:SetPoint("CENTER");self.emptyTitle:SetJustifyH("CENTER")
 self.editorEmpty=C.Text(main,S("选择玩家查看记录","Select a player to view their note"),18,T.dim,DRAWER_W-32);C.SetLineHeight(self.editorEmpty,24,true);self.editorEmpty:SetPoint("CENTER",main,"TOPLEFT",EDITOR_X-MAIN_X+DRAWER_W/2,-WORK_TOP-(HEIGHT-WORK_TOP-PAD)/2);self.editorEmpty:SetJustifyH("CENTER")
 local editor=CreateFrame("Frame",nil,main);editor:SetSize(DRAWER_W,EDITOR_HEIGHT);editor:SetPoint("TOPLEFT",EDITOR_X-MAIN_X,-WORK_TOP);C.Panel(editor,T.container,20);self.editor=editor;editor:Hide()
 local inner=DRAWER_W-32;local half=(inner-12)/2
 self.eTitle=C.Text(editor,L.edit,18,T.text);self.eTitle:SetPoint("TOPLEFT",16,-24);C.SetLineHeight(self.eTitle,24,true)
 self.eClose=C.Button(editor,"",40,function() P:CloseEditor() end);C.Glyph(self.eClose,"close",20):SetPoint("CENTER");self.eClose:SetPoint("TOPRIGHT",-16,-16)
 self.eNameLabel=C.Text(editor,S("玩家","Player"),14,T.muted);self.eNameLabel:SetPoint("TOPLEFT",16,-68);C.SetLineHeight(self.eNameLabel,20,true)
 self.eName=C.Edit(editor,inner,44);self.eName:SetPoint("TOPLEFT",16,-92)
 self.eNameHint=C.Text(self.eName,L.notesIdentityHint,14,T.dim,inner-24);self.eNameHint:SetPoint("LEFT",12,0);C.SetLineHeight(self.eNameHint,20,true)
 self.eName.box:HookScript("OnTextChanged",function() P.eNameHint:SetShown(P.eName.box:GetText()=="") end)
 self.eAvatar=C.Icon(editor,40);self.eAvatar:SetPoint("TOPLEFT",16,-68)
 self.eIdentity=C.Text(editor,"",16,T.text,inner-52);self.eIdentity:SetPoint("TOPLEFT",68,-66);self.eIdentity:SetWordWrap(false);C.SetLineHeight(self.eIdentity,22,true)
 self.eRealm=C.Text(editor,"",14,T.muted,inner-52);self.eRealm:SetPoint("TOPLEFT",68,-90);C.SetLineHeight(self.eRealm,20,true)
 self.classLabel=C.Text(editor,S("职业","Class"),14,T.muted);self.classLabel:SetPoint("TOPLEFT",16,-148);C.SetLineHeight(self.classLabel,20,true)
 self.specLabel=C.Text(editor,S("专精","Specialization"),14,T.muted);self.specLabel:SetPoint("TOPLEFT",28+half,-148);C.SetLineHeight(self.specLabel,20,true)
 self.classChoice=C.Choice(editor,half,function() return P:ClassItems() end,function(value) state.identityEdited=true;state.legacyClassSpec=nil;state.recordClass=value or nil;state.recordSpec=nil;P:SyncSpec() end);self.classChoice:SetPoint("TOPLEFT",16,-172);self.classChoice:SetHeight(44)
 self.specChoice=C.Choice(editor,half,function() return P:SpecItems() end,function(value) state.identityEdited=true;state.legacyClassSpec=nil;state.recordSpec=value or nil;P:SyncSpec() end);self.specChoice:SetPoint("TOPLEFT",28+half,-172);self.specChoice:SetHeight(44)
 self.typeLabel=C.Text(editor,S("记录类型","Note type"),14,T.muted);C.SetLineHeight(self.typeLabel,20,true)
 self.typeSwitch=CreateFrame("Frame",nil,editor);self.typeSwitch:SetSize(inner,36);self.typeSwitch:SetPoint("TOPLEFT",16,-228);C.Panel(self.typeSwitch,T.surfaceLow,8)
 self.typeButtons={};for i,entry in ipairs(NOTE_TYPES) do local w=(inner-14)/3;local button=C.Button(self.typeSwitch,entry.label,w,function() state.recordType=entry.key;P:SyncSpec() end,{variant="compact",textColor=T.text});button:SetPoint("TOPLEFT",3+(i-1)*(w+4),-3);button.label:ClearAllPoints();button.label:SetPoint("CENTER",10,0);button.icon=C.Glyph(button,entry.key=="positive" and "heart" or entry.key=="caution" and "caution" or "book",14);button.icon:SetPoint("CENTER",-(button.label:GetStringWidth()+6)/2,0);self.typeButtons[entry.key]=button end
 self.eReasonLabel=C.Text(editor,L.reason,14,T.muted);self.eReasonLabel:SetPoint("TOPLEFT",16,-276);C.SetLineHeight(self.eReasonLabel,20,true)
 self.eReason=C.Edit(editor,inner,112,true);self.eReason:SetPoint("TOPLEFT",16,-300);self.eReason:SetPlaceholder(S("写下当时发生的事","Describe what happened"));C.SetLineHeight(self.eReason.box,20)
 self.eDate=C.Text(editor,"",14,T.dim,inner);self.eDate:SetPoint("TOPLEFT",16,-420);C.SetLineHeight(self.eDate,20,true)
 self.eStatus=C.Text(editor,"",14,T.muted,inner);self.eStatus:SetPoint("TOPLEFT",16,-448);self.eStatus:SetMaxLines(2);C.SetLineHeight(self.eStatus,20)
 self.eSave=C.Button(editor,L.save,88,function() P:Save() end);self.eSave:SetPrimary(true);self.eSave:SetPoint("BOTTOMRIGHT",-16,16)
 self.eCancel=C.Button(editor,L.cancel,72,function() P:CloseEditor() end);self.eCancel:SetPoint("RIGHT",self.eSave,"LEFT",-8,0)
 self.eDelete=C.Button(editor,S("删除记录","Delete note"),96,function() P:Delete() end);self.eDelete:SetWidth(math.max(96,math.ceil(self.eDelete.label:GetStringWidth())+32));self.eDelete:SetTextColors(T.muted,T.accent);self.eDelete:SetPoint("BOTTOMLEFT",16,16)
 self.historyFrame=CreateFrame("Frame",nil,main);self.historyFrame:SetSize(BODY_WIDTH,HEIGHT-76-PAD);self.historyFrame:SetPoint("TOPLEFT",PAD,-76);self.historyFrame:Hide()
 self.historyCaption=C.Text(self.historyFrame,S("当前角色完成的大秘境","Mythic+ runs completed by this character"),14,T.muted);self.historyCaption:SetPoint("TOPLEFT");C.SetLineHeight(self.historyCaption,20,true)
 local historyRowWidth=BODY_WIDTH-C.listRightInset;local activityColumn=(historyRowWidth-24-48-88-20)/2.1;local teammateX=12+activityColumn+16
 local activityHeading=C.Text(self.historyFrame,S("活动","Activity"),14,T.dim);C.SetLineHeight(activityHeading,20,true);activityHeading:SetPoint("TOPLEFT",13,-40)
 local teammateHeading=C.Text(self.historyFrame,S("队友","Teammates"),14,T.dim);C.SetLineHeight(teammateHeading,20,true);teammateHeading:SetPoint("TOPLEFT",teammateX,-40)
 local dateHeading=C.Text(self.historyFrame,S("完成时间","Completed"),14,T.dim,88);C.SetLineHeight(dateHeading,20,true);dateHeading:SetPoint("TOPRIGHT",-C.listRightInset-48,-40)
 self.historyList=C.List(self.historyFrame,BODY_WIDTH,HEIGHT-142-PAD,72,function(index) P:OpenRun(index) end);self.historyList:SetPoint("TOPLEFT",0,-66)
 for _,row in ipairs(self.historyList.rows) do
  row.icon=C.Icon(row,36);row.icon:SetPoint("LEFT",12,0)
  row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",60,-12);row.title:SetWidth(activityColumn-48);row.title:SetFont(T.font,T.listTitleSize,"");C.SetLineHeight(row.title,T.listTitleLineHeight,true)
  row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",60,-40);row.meta:SetWidth(activityColumn-48)
  row.roster=C.Roster(row,23,5);row.roster:SetPoint("TOPLEFT",teammateX,-24.5)
  row.date=C.Text(row,"",14,T.muted,88);row.date:SetPoint("RIGHT",-48,0);row.date:SetJustifyH("LEFT");C.SetLineHeight(row.date,20,true)
  C.Glyph(row,"chevron",16):SetPoint("RIGHT",-16,0)
 end
 self.historyEmpty=C.Text(self.historyFrame,L.historyEmpty,16,T.dim,BODY_WIDTH);self.historyEmpty:SetPoint("TOP",0,-140);self.historyEmpty:SetJustifyH("CENTER")
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
function P:SyncSpec()
 local className=L.unknown;for _,item in ipairs(self:ClassItems()) do if item.value==state.recordClass then className=item.label end end
 local specName=L.unknown;for _,item in ipairs(self:SpecItems()) do if item.value==state.recordSpec then specName=item.label end end
 self.classChoice:SetValue(state.recordClass,className);self.specChoice:SetValue(state.recordSpec,specName)
 self.specChoice:SetAvailable(state.recordClass~=nil)
 UI:SetMemberIcon(self.eAvatar,{class=state.recordClass,specID=state.recordSpec});self.eIdentity:SetTextColor(UI:ClassColor(state.recordClass))
 for key,b in pairs(self.typeButtons) do b:SetActive(key==state.recordType) end
 state.classSpec=state.recordClass and (className..(state.recordSpec and " · "..specName or "")) or state.legacyClassSpec or ""
end
function P:SetEditorStatus(text,kind)
 UI:SetText(self.eStatus,text)
 UI:Color(self.eStatus,kind=="error" and T.warning or kind=="success" and T.good or T.muted)
end
function P:SelectTab(tab,skipDefault)
 local changed=state.tab~=nil and state.tab~=tab
 UI.Motion:FinishPlacement(self.left);UI.Motion:FinishPlacement(self.historyFrame)
 state.tab=tab;local history=tab=="history"
 for key,button in pairs(self.tabs) do button:SetActive(key==tab);button.mark:SetShown(key==tab);UI:Color(button.label,key==tab and T.text or T.muted);button.glyph:SetSelected(key==tab) end
 self:CloseTransfer();self:CloseEditor(true);self.toolbar:SetShown(not history);self.left:SetShown(not history);self.historyFrame:SetShown(history);self.editorEmpty:SetShown(not history)
 UI:SetText(self.pageTitle,history and L.history or L.notes)
 self:RefreshCounts()
 if history then self:RefreshHistory() else self:RefreshList();local keys=self.list.ids;if not skipDefault and keys and keys[1] then self:OpenEdit(keys[1]) end end
 if changed then UI.Motion:Reveal(history and self.historyFrame or self.left,"TOPLEFT",self.main,"TOPLEFT",PAD,history and -76 or -WORK_TOP,4,0,.14) end
end
function P:RefreshHistory()
 local group,err=A:Ensure("Group");if not group then A:NoteMessage(err);return end
 self.runs=group:GetHistory();local indices={};for i in ipairs(self.runs) do indices[#indices+1]=i end
 self.historyList:SetItems(indices,function(row,index)
  local run=P.runs[index]
  local texture=run.mapChallengeModeID and select(4,C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID))
  if texture then UI.context:SetGameTexture(row.icon,texture) else UI:SetActivityIcon(row.icon,run.activity or run) end
  UI:SetText(row.title,run.mapName or L.unknown)
  local duration=run.completedAt and run.startedAt and math.max(0,run.completedAt-run.startedAt)
  UI:SetText(row.meta,"+"..(run.level or "?")..(duration and (" · "..math.floor(duration/60)..":"..("%02d"):format(duration%60)) or ""))
  row.roster:Update(run.members,nil,5);UI:SetText(row.date,UI:DateText(run.completedAt or run.startedAt))
 end);self.historyEmpty:SetShown(#indices==0)
end
function P:OpenRun(index)
 local run=self.runs[index];if not run then return end
 local modal=UI:OpenModal("history",L.history,560,536);self.historyModal=modal
 if not modal.built then
  modal.caption=C.Text(modal.content,"",14,T.muted,512);modal.caption:SetPoint("TOPLEFT");C.SetLineHeight(modal.caption,22,true)
  modal.list=C.List(modal.content,512,360,72,function(memberIndex)
   local member=P.historyRun.members[memberIndex];local key=A:PlayerKey(member.name,member.realm)
   modal:Close();P:SelectTab("all")
   if A.Notes:Find(key) then P:OpenEdit(key);P.list:Select(key,true) else P:OpenAdd({name=member.name,realm=member.realm,class=member.class,specID=member.specID}) end
  end);modal.list:SetPoint("TOPLEFT",0,-38)
  for _,row in ipairs(modal.list.rows) do
   row.icon=C.Icon(row,32);row.icon:SetPoint("LEFT",12,0)
   row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",56,-12);row.title:SetWidth(310);row.title:SetFont(T.font,T.listTitleSize,"");C.SetLineHeight(row.title,T.listTitleLineHeight,true)
   row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",56,-40);row.meta:SetWidth(310)
   row.action=C.Text(row,"",14,T.dim,110);row.action:SetPoint("RIGHT",-12,0);row.action:SetJustifyH("RIGHT");C.SetLineHeight(row.action,20,true)
  end
  modal.onClose=function() modal.list:Clear();P.historyRun=nil end;modal.built=true
 end
 self.historyRun=run
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

local function ShowEditorChrome(mode)
	-- mode: "edit" | "add" | "missing";缺失态只显示说明与取消,不呈现可编辑字段。
	local edit, add, missing = mode == "edit", mode == "add", mode == "missing"
	state.panel = mode
	P.editor:Show();P.editorEmpty:Hide()
	UI.Motion:Reveal(P.editor,"TOPLEFT",P.main,"TOPLEFT",EDITOR_X-MAIN_X,-WORK_TOP,12,0,.18)
 UI:SetText(P.eTitle,add and L.add or missing and L.viewNote or S("玩家记录","Player note"))
 P.eClose:SetShown(add or missing)
 P.eIdentity:SetShown(edit);P.eAvatar:SetShown(edit);P.eRealm:SetShown(edit);P.eDate:SetShown(edit)
 P.eNameLabel:SetShown(add);P.eName:SetShown(add)
 P.classLabel:SetShown(not missing);P.specLabel:SetShown(not missing);P.typeLabel:SetShown(not missing);P.typeSwitch:SetShown(not missing)
 local classTop=add and 148 or 120
 P.classLabel:ClearAllPoints();P.classLabel:SetPoint("TOPLEFT",16,-classTop)
 P.specLabel:ClearAllPoints();P.specLabel:SetPoint("TOPLEFT",28+(DRAWER_W-44)/2,-classTop)
 P.classChoice:ClearAllPoints();P.classChoice:SetPoint("TOPLEFT",16,-classTop-24)
 P.specChoice:ClearAllPoints();P.specChoice:SetPoint("TOPLEFT",28+(DRAWER_W-44)/2,-classTop-24)
 P.typeLabel:ClearAllPoints();P.typeLabel:SetPoint("TOPLEFT",16,-classTop-80)
 P.typeSwitch:ClearAllPoints();P.typeSwitch:SetPoint("TOPLEFT",16,-classTop-104)
 P.eReasonLabel:ClearAllPoints();P.eReasonLabel:SetPoint("TOPLEFT",16,-classTop-152)
 P.eReason:ClearAllPoints();P.eReason:SetPoint("TOPLEFT",16,-classTop-176)
 P.eDate:ClearAllPoints();P.eDate:SetPoint("TOPLEFT",16,-classTop-296)
 P.eReasonLabel:SetShown(not missing);P.eReason:SetShown(not missing);P.eSave:SetShown(not missing);P.eCancel:SetShown(not missing)
 P.eDelete:SetShown(edit);P.classChoice:SetShown(not missing);P.specChoice:SetShown(not missing);for _,button in pairs(P.typeButtons) do button:SetShown(not missing) end
 P.eStatus:ClearAllPoints();P.eStatus:SetPoint("TOPLEFT",P.editor,"TOPLEFT",16,missing and -76 or -444)
end

function P:OpenEdit(key)
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
	ShowEditorChrome("edit")
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
 state.legacyClassSpec=nil;state.recordClass,state.recordSpec,state.recordType=identity.class,identity.specID,draft and draft.type or A.db.defaultNote;self:SyncSpec()
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
 local modal=UI:OpenModal("notesTransfer",mode=="import" and S("导入记录","Import notes") or S("导出记录","Export notes"),560,456);self.transferModal=modal;self.transfer=modal.frame
 if modal.built then return end
 local parent=modal.content
 self.tHint=C.Text(parent,L.importHelp,14,T.muted,512);self.tHint:SetPoint("TOPLEFT");C.SetLineHeight(self.tHint,20,true)
 self.tLabel=C.Text(parent,S("记录文本","Record text"),14,T.muted);C.SetLineHeight(self.tLabel,20,true);self.tLabel:SetPoint("TOPLEFT",0,-40)
 self.tBox=C.Edit(parent,512,192,true,false,"modal");self.tBox:SetPoint("TOPLEFT",0,-68);C.SetLineHeight(self.tBox.box,22)
 self.tStatus=C.Text(parent,"",14,T.accent,512);self.tStatus:SetPoint("TOPLEFT",0,-272);C.SetLineHeight(self.tStatus,20,true)
 self.tImport=C.Button(parent,L.import,104,function() P:DoImport() end);self.tImport:SetPrimary(true);self.tImport:SetPoint("BOTTOMRIGHT")
 self.tExport=C.Button(parent,L.export,104,function() P:DoExport() end);self.tExport:SetPrimary(true);self.tExport:SetPoint("BOTTOMRIGHT")
 self.tSelect=C.Button(parent,L.selectAll,92,function() P.tBox.box:SetFocus();P.tBox.box:HighlightText() end);self.tSelect:SetPoint("BOTTOMLEFT")
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
	local records, err = UI.Transfer.Decode(self.tBox.box:GetText() or "")
	if not records then
		UI:SetText(self.tStatus, L.invalidData)
		return
	end
	local merged, invalid = notes:Merge(records)
	UI:SetText(self.tStatus, L.importResult:format(merged or 0, invalid))
end

-- ---------------------------------------------------------------- 页面生命周期

function P:Enter(context)
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
 UI.Motion:FinishPlacement(self.left);UI.Motion:FinishPlacement(self.historyFrame)
	if state.unsub then state.unsub(); state.unsub = nil end
	self:CloseTransfer()
	self:CloseEditor(true)
	self.list:Clear();self.historyList:Clear();self.runs=nil
 if self.historyModal then self.historyModal:Close() end
 if self.tBox then self.tBox.box:SetText("");UI:SetText(self.tStatus, "") end
	UI.Tooltip:Hide()
end
