-- Recruitment form, applicant batches and the full current roster share native state.
local A=_G.LycheeGroup
local UI=A.UI
local T,L,C=UI.Theme,UI.L,UI.C
local ActivityLabel=A.ActivityLabels.Display
local MAIN=T.contentWidth-T.createRailWidth-T.createRailGap
local FORM=MAIN-T.createContentInset*2
local CONTENT=MAIN-T.createContentInset*2
local BATCH_WIDTH=CONTENT-C.listRightInset
local columns={
 name={x=12,width=224,align="LEFT"},role={x=242,width=68,align="CENTER"},
 faction={x=316,width=112,align="CENTER"},
 rating={x=432,width=72,align="CENTER"},mapScore={x=504,width=72,align="CENTER"},ilvl={x=588,width=48,align="CENTER"},
 comment={x=660,width=BATCH_WIDTH-768,align="LEFT"},actions={x=BATCH_WIDTH-96,width=84,align="CENTER"},
}
local applicantSorts={{value="newest",label=L.newest},{value="score",label=L.rating},{value="ilvl",label=L.itemLevel}}
local dungeonApplicantSorts={{value="newest",label=L.newest},{value="score",label=L.rating},{value="mapScore",label=""},{value="ilvl",label=L.itemLevel}}
local noRatingApplicantSorts={{value="newest",label=L.newest},{value="ilvl",label=L.itemLevel}}
local BATCH_MAX_HEIGHT=T.contentHeight-T.createBatchBottomReserve
local P={};UI.pages.create=P
local function HideMemberTooltip(row)
 if UI.Tooltip:IsOwned(row) then UI.Tooltip:Hide() end
end
local function MemberTooltipArea(row,clip)
 UI:BindTooltipArea(row,.25,function()
  return row:IsEnabled() and row.member and row._hitVisible~=false and clip:IsMouseOver()
 end,function() UI.Tooltip:ShowPlayer(row,row.member,row.memberContext) end)
end
local state={category="seasonDungeon",editing=false,sort="newest"}
local form={crossFaction=true}
local zh=A:GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
dungeonApplicantSorts[3].label=S("单本分","Dungeon")
local headerLabels={name=S("申请者","Applicant"),role=L.role,faction=S("阵营","Faction"),rating=L.rating,mapScore=S("单本分","Dungeon"),ilvl=L.itemLevel,comment=S("备注","Note"),actions=S("操作","Actions")}
local sortColumns={score="rating",mapScore="mapScore",ilvl="ilvl"}
local columnSorts={rating="score",mapScore="mapScore",ilvl="ilvl"}
local function ApplicantDefinitions(kind)
 local definitions={
  {key="name",width="createColumnNameWidth",min="createColumnNameMin",align="LEFT"},{key="role",width="createColumnRoleWidth",min="createColumnRoleMin",align="CENTER"},
  {key="faction",width="createColumnFactionWidth",min="createColumnFactionMin",align="CENTER"},
 }
 if kind~="none" then definitions[#definitions+1]={key="rating",width=kind=="dungeon" and "createColumnRatingDungeonWidth" or "createColumnRatingWidth",min="createColumnRatingMin",align="CENTER",sortable=true} end
 if kind=="dungeon" then
  local header=P.applicantTable
  local width=0
  if header then
   -- Native glyph rounding follows effective frame scale; measure beside the table.
   local measure=P.applicantTimeMeasure
   if not measure then measure=C.Text(header,"99:59/99:59",14,"muted");measure:SetWordWrap(false);measure:Hide();P.applicantTimeMeasure=measure end
   local batch=P.batchPool and P.batchPool[1]
   local label=batch and batch.people[1] and batch.people[1].mapScore or header.labels.mapScore
   if label then measure:SetFont(label:GetFont());measure:SetSpacing(label:GetSpacing() or 0) end
   width=math.ceil(measure:GetUnboundedStringWidth())+12
  end
  local minimum=math.max(T.createColumnMapScoreMin,width)
  definitions[#definitions+1]={key="mapScore",width=math.max(T.createColumnMapScoreWidth,minimum),min=minimum,align="CENTER",sortable=true}
 end
 definitions[#definitions+1]={key="ilvl",width=kind=="dungeon" and "createColumnIlvlDungeonWidth" or "createColumnIlvlWidth",min="createColumnIlvlMin",align="CENTER",sortable=true}
 local usedWidth=T.createColumnActionsWidth
 for _,definition in ipairs(definitions) do usedWidth=usedWidth+(type(definition.width)=="string" and T[definition.width] or definition.width) end
 definitions[#definitions+1]={key="comment",width=BATCH_WIDTH-usedWidth,min="createColumnCommentMin",align="LEFT"}
 definitions[#definitions+1]={key="actions",width="createColumnActionsWidth",min="createColumnActionsMin",align="CENTER"}
 for _,definition in ipairs(definitions) do definition.label=headerLabels[definition.key] end
 return definitions
end
local function ApplicantPadding(key)
 if key=="name" then return 12,2 elseif key=="comment" then return 12,6 elseif key=="actions" then return 6,12 end
 return 6,6
end
-- Measure unconstrained text: recycled labels may still carry the previous row width.
local function FitText(label)
 label:SetWordWrap(false);label:SetWidth(0)
 local width=math.ceil(label:GetStringWidth())+2;label:SetWidth(width);return width
end
local function ApplicantName(member)
 return member.nameKey or member.name and (member.name..(member.realm and "-"..member.realm or "")) or L.unknown
end
local function PlaystyleLabel(value)
 local e=Enum.LFGEntryGeneralPlaystyle
 if value==e.Learning then return GROUP_FINDER_GENERAL_PLAYSTYLE1 elseif value==e.FunRelaxed then return GROUP_FINDER_GENERAL_PLAYSTYLE2 elseif value==e.FunSerious then return GROUP_FINDER_GENERAL_PLAYSTYLE3 elseif value==e.Expert then return GROUP_FINDER_GENERAL_PLAYSTYLE4 end
 return ""
end
local roles={TANK=L.tank,HEALER=L.healer,DAMAGER=L.damage}
local roleOrder={"TANK","HEALER","DAMAGER"}
local function UpdateApplicantRoles(row,member,layout)
 local count=0
 for _,role in ipairs(roleOrder) do
  if UI:MemberHasRole(member,role) then count=count+1;UI:SetRoleIcon(row.roles[count],role) end
 end
 local left=layout.role.x+(layout.role.width-(count*T.createRoleIconSize+math.max(0,count-1)*T.createRoleIconGap))/2
 for i,icon in ipairs(row.roles) do icon:SetSize(T.createRoleIconSize,T.createRoleIconSize);icon:SetShown(i<=count);icon:ClearAllPoints();icon:SetPoint("LEFT",left+(i-1)*(T.createRoleIconSize+T.createRoleIconGap),0) end
end
local function LayoutApplicantFaction(row)
 local showRace=row.factionExpanded==true
 row.factionButton:SetWidth(showRace and columns.faction.width or T.createFactionButtonWidth)
 row.factionButton:ClearAllPoints();row.factionButton:SetPoint("LEFT",columns.faction.x+(columns.faction.width-row.factionButton:GetWidth())/2,0)
 row.faction:SetShown(not showRace and row.hasFaction==true);row.race:SetShown(showRace)
 UI:SetText(row.factionButton.label,not showRace and not row.hasFaction and "—" or "")
end
local function SetApplicantTarget(button,identity)
 if button.targetKey==identity then return end
 if button.pressedKey then button.pressCancelled=true end
 button.targetKey=identity
end
local function CaptureApplicantPress(button,mouse)
 button.pressedKey=button.targetKey or true;button.pressedMouse=mouse;button.pressCancelled=nil
end
-- Keep cancellation across reuse until this click or a new press consumes it.
local function ConsumeApplicantPress(button,mouse)
 local pressed=button.pressedKey~=nil
 local valid=button.targetKey~=nil and not button.pressCancelled and (not pressed or button.pressedKey==button.targetKey and button.pressedMouse==mouse)
 button.pressedKey,button.pressedMouse,button.pressCancelled=nil,nil,nil
 return valid,pressed
end
local function UpdateApplicantFaction(row,member,applicantID,identity)
 SetApplicantTarget(row.factionButton,identity)
 local key=member.nameKey or member.name
 if row.factionApplicantID~=applicantID or row.factionMemberKey~=key then row.factionExpanded=nil end
 row.factionApplicantID,row.factionMemberKey=applicantID,key
 row.hasFaction=UI:SetFactionIcon(row.faction,member)
 UI:SetText(row.race,member.raceName or "—")
 LayoutApplicantFaction(row)
end
local function ClearApplicantTime(row)
 row.mapScoreTime,row.mapScoreIdentity,row.mapScoreKey=nil,nil,nil
 if row.mapScoreButton then
  SetApplicantTarget(row.mapScoreButton,nil)
  if UI.Tooltip:IsOwned(row.mapScoreButton) then UI.Tooltip:Hide() end
 end
end
local function ApplicantTimeKey(applicantID,member,index)
 local memberID=UI.Members:ID(member)
 if memberID then return tostring(applicantID)..":"..memberID end
 -- Bare native names identify only this live applicant slot, never a saved player.
 if type(member.name)=="string" and member.name~="" then
  return tostring(applicantID)..":slot:"..tostring(member.applicantIndex or index)..":"..member.name
 end
end
local function ApplicantTime(row)
 return UI:GetGroup():GetApplicantTimeMargin(row.member)
end
local function DrawApplicantMapScore(row)
 if not row.mapScoreTime then UI:SetScore(row.mapScore,UI:GetGroup():GetApplicantMapScore(row.member),"map");return end
 local seconds,status,run=ApplicantTime(row)
 local text=seconds and UI:DungeonRunTimeText(run,true) or status=="none" and S("无记录","No run") or status=="unavailable" and S("无用时","No time") or S("未知","Unknown")
 UI:SetText(row.mapScore,text);UI:Color(row.mapScore,T.muted)
end
local function ApplicantTimeTooltip(row)
 if not row.mapScoreTime or not row.member or not row:IsEnabled() or row._hitVisible==false or not P.batchScroll:IsMouseOver() then return nil end
 local seconds,_,run=ApplicantTime(row)
 if not seconds or not run.level then return nil end
 return S("%d 层 %s","+%d %s"):format(run.level,UI:DungeonRunTimeText(run))
end
local function LayoutApplicantMapScore(row,layout)
 local cell=layout and layout.mapScore or row.applicantColumns and row.applicantColumns.mapScore or columns.mapScore
 local button=row.mapScoreButton;local point,relative,relativePoint,x,y=button:GetPoint()
 if button:GetNumPoints()~=1 or point~="LEFT" or relative~=row or relativePoint~="LEFT" or x~=cell.x or y~=0 then
  button:ClearAllPoints();button:SetPoint("LEFT",row,"LEFT",cell.x,0)
 end
 local height=row:GetHeight()
 if button:GetWidth()~=cell.width or button:GetHeight()~=height then button:SetSize(cell.width,height) end
 local shown=P.showApplicantMapScore==true
 if button:IsShown()~=shown then button:SetShown(shown) end
end
local function Shell(parent,w,h,x,y)
 local shell=C.Field(parent,w,h);shell:SetPoint("TOPLEFT",x,y);return shell
end
local function Minimum(app,key)
 local value
 for _,m in ipairs(app.members) do
  local current
  if key=="rating" then current=UI:MemberRating(m) elseif key=="mapScore" then current=UI:GetGroup():GetApplicantMapScore(m) else current=m[key] end
  if current==nil then return nil end
  value=math.min(value or current,current)
 end
 return value
end
local function RequirementGeometry(self)
 local large=UI.context.fontScale>1
 local inputTop=large and math.max(56,32+self.ilvlLabel:GetHeight(),32+self.scoreLabel:GetHeight(),32+self.styleLabel:GetHeight()) or 56
 return inputTop,math.max(112,inputTop+self.ilvl:GetHeight()+12)
end
function P:LayoutRequirements()
 local ilvlWidth=self.hasPlaystyle and (self.scoreKind and (FORM-32)/3.25 or (FORM-16)/2.25) or (self.scoreKind and (FORM-16)/2 or FORM)
 self.ilvl:SetWidth(ilvlWidth);self.score:SetWidth(ilvlWidth)
 local styleLeft=self.scoreKind and 2*(ilvlWidth+16) or ilvlWidth+16
 self.playstyle:SetWidth(math.max(1,FORM-styleLeft))
 local inputTop,optionTop=RequirementGeometry(self)
 local scoreX=self.ilvl:GetWidth()+16
 local styleX=self.scoreKind and 2*scoreX or scoreX
 self.ilvl:SetPoint("TOPLEFT",0,-inputTop)
 self.score:ClearAllPoints();self.score:SetPoint("TOPLEFT",scoreX,-inputTop)
 self.scoreLabel:ClearAllPoints();C.SetPoint(self.scoreLabel,"TOPLEFT",self.scoreLabel:GetParent(),"TOPLEFT",scoreX,"createScoreLabelTopleftY")
 self.playstyle:ClearAllPoints();self.playstyle:SetPoint("TOPLEFT",styleX,-inputTop)
 self.styleLabel:ClearAllPoints();C.SetPoint(self.styleLabel,"TOPLEFT",self.styleLabel:GetParent(),"TOPLEFT",styleX,"createStyleLabelTopleftY")
 for _,option in ipairs({self.private,self.crossFaction,self.autoAccept}) do
  option:SetHeight(T.createOptionHeight);option.label:ClearAllPoints();C.SetPoint(option.label,"LEFT",option.track,"RIGHT","createOptionLabelLeftX",0);option:SetWidth(52+FitText(option.label))

 end
 self.optionLayout.options.y=-optionTop;self.optionLayout.options.height=T.createOptionHeight;self.optionLayout:Layout()
 self.autoInviteHint:SetPoint("TOPLEFT",0,-optionTop-46)
 self.requirementsBottom=optionTop+46+self.autoInviteHint:GetStringHeight()
end
local function FontGeometry(self)
 local large=UI.context.fontScale>1
 local pickerTop=large and math.max(28,self.activityLabel:GetHeight()+4) or 28
 local contextTop=large and math.max(26,4+self.pickerName:GetHeight()) or 26
 local pickerHeight=large and math.max(52,contextTop+self.pickerContext:GetHeight()+4) or 52
 local titleTop=large and math.max(92,pickerTop+pickerHeight+12) or 92
 local titleInputTop=large and math.max(116,titleTop+self.titleLabel:GetHeight()) or 116
 local descriptionTop=large and math.max(172,titleInputTop+self.titleShell:GetHeight()+12) or 172
 local descriptionInputTop=large and math.max(196,descriptionTop+self.descriptionLabel:GetHeight()) or 196
 return pickerTop,contextTop,pickerHeight,titleTop,titleInputTop,descriptionTop,descriptionInputTop,math.max(356,56+descriptionInputTop+T.createDescriptionMinHeight+24)
end
local function LayoutFont(self,definitions)
 local pickerTop,contextTop,pickerHeight,titleTop,titleInputTop,descriptionTop,descriptionInputTop,minimumTop=FontGeometry(self)
 C.SetPoint(self.pickerContext,"TOPLEFT",self.pickerContext:GetParent(),"TOPLEFT","createPickerContextTopleftX",-contextTop)
 self.pickerTrigger:SetHeight(pickerHeight);self.pickerTrigger:SetPoint("TOPLEFT",0,-pickerTop)
 self.titleLabel:SetPoint("TOPLEFT",0,-titleTop);self.titleShell:SetPoint("TOPLEFT",0,-titleInputTop)
 self.descriptionLabel:SetPoint("TOPLEFT",0,-descriptionTop);self.descriptionShell:SetPoint("TOPLEFT",0,-descriptionInputTop)
 self.descriptionInputTop=descriptionInputTop
 self.minimumRequirementsTop=minimumTop
 self:LayoutRequirements()
 self:LayoutFormNotices()
 self.cancelListing:SetWidth(FitText(self.cancelListing.label)+34);self.editListing:SetWidth(FitText(self.editListing.label)+34)
 local summaryWidth=CONTENT-116-self.cancelListing:GetWidth()-8-self.editListing:GetWidth();self.sMeta:SetWidth(summaryWidth);self.sName:SetWidth(summaryWidth)
 C.SetPoint(self.sName,"TOPLEFT",self.sName:GetParent(),"TOPLEFT","createSNameTopleftX",-math.max(28,self.sMeta:GetHeight()))
 for _,item in ipairs(self.roleFilterItems) do local button=item.frame;C.SetLineHeight(button.label,20,true);item.height=math.max(30,button.label:GetHeight());item.width=FitText(button.label)+24+(button==self.roleFilters.ALL and 0 or 22) end
 self.roleFilterOptions.y=T.createButtonTopleftY
 local filterWidth=self.roleFilterLayout:Layout();self.roleFilterSurface:SetWidth(filterWidth+6)
 if self.pickerVariants then self:LayoutActivityChoice(self.pickerVariants) end
 if self.applicantTable then
  if definitions then self.applicantTable:SetColumns(definitions,BATCH_WIDTH) else self.applicantTable:Layout(BATCH_WIDTH) end
 end
 if self.appIDs then self:LayoutBatches() end
end
function P:LayoutFont()
 LayoutFont(self,ApplicantDefinitions(self.applicantTableKind))
UI:ApplyElementScope("create")
 end
function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 local surface=CreateFrame("Frame",nil,root);surface:SetSize(MAIN,T.contentHeight);surface:SetPoint("TOPLEFT");C.Panel(surface,"surfaceLow","createPanelRadius");self.surface=surface
 local f=CreateFrame("Frame",nil,surface);f:SetSize(FORM,T.contentHeight-48);C.SetPoint(f,"TOP",f:GetParent(),"TOP",0,"createFTopY");self.formFrame=f
 self.heading=C.Text(f,L.create,24);C.SetLineHeight(self.heading,32,true);self.heading:SetPoint("TOPLEFT")
 local desc=CreateFrame("Frame",nil,f);desc:SetSize(FORM,T.createDescHeight);C.SetPoint(desc,"TOPLEFT",desc:GetParent(),"TOPLEFT",0,"createDescTopleftY");self.desc=desc
 self.activityLabel=C.Text(desc,S("活动与难度","Activity and difficulty"),14);C.SetLineHeight(self.activityLabel,20,true);self.activityLabel:SetPoint("TOPLEFT")
 self.pickerTrigger=C.ChoiceTrigger(desc,T.createPickerTriggerWidth,function() P:TogglePicker() end,{height=52});self.pickerTrigger:SetWidth(T.createPickerTriggerWidth);self.pickerTrigger.label:Hide();C.SetPoint(self.pickerTrigger,"TOPLEFT",self.pickerTrigger:GetParent(),"TOPLEFT",0,"createPickerTriggerTopleftY")
 self.pickerIcon=C.Icon(self.pickerTrigger,T.createPickerIconWidth);C.Box(self.pickerIcon,{width="createPickerIconWidth",height="createPickerIconHeight"});C.SetPoint(self.pickerIcon,"LEFT",self.pickerIcon:GetParent(),"LEFT","createPickerIconLeftX",0)
 self.pickerName=C.Text(self.pickerTrigger,"",14,"text",T.createPickerNameWidth);self.pickerName:SetWidth(T.createPickerNameWidth);C.SetLineHeight(self.pickerName,20,true);C.SetPoint(self.pickerName,"TOPLEFT",self.pickerName:GetParent(),"TOPLEFT","createPickerNameTopleftX","createPickerNameTopleftY")
 self.pickerContext=C.Text(self.pickerTrigger,"",14,"muted",T.createPickerContextWidth);self.pickerContext:SetWidth(T.createPickerContextWidth);C.SetLineHeight(self.pickerContext,20,true);C.SetPoint(self.pickerContext,"TOPLEFT",self.pickerContext:GetParent(),"TOPLEFT","createPickerContextTopleftX","createPickerContextTopleftY")
 self.difficultyChoice=C.Choice(desc,FORM-352,function() return P:DifficultyItems() end,function(value) P:SelectDifficulty(value) end);self.difficultyChoice:SetHeight(T.createDifficultyChoiceHeight);C.SetPoint(self.difficultyChoice,"TOPLEFT",self.difficultyChoice:GetParent(),"TOPLEFT","createDifficultyChoiceTopleftX","createDifficultyChoiceTopleftY")
 self.difficultyGroup=CreateFrame("Frame",nil,desc);self.difficultyGroup:SetSize(FORM-352,T.createDifficultyGroupHeight);C.SetPoint(self.difficultyGroup,"TOPLEFT",self.difficultyGroup:GetParent(),"TOPLEFT","createDifficultyGroupTopleftX","createDifficultyGroupTopleftY");C.Panel(self.difficultyGroup,"panel","createPanelRadius2")
 self.difficultySelection=C.Selection(self.difficultyGroup)
 self.difficultyButtons={}
 for i=1,4 do self.difficultyButtons[i]=C.Button(self.difficultyGroup,"",T.createButtonWidth,function(button) P:SelectDifficulty(button.value) end,{variant="compact",selectionFill=false}) end
 self.difficultyFixedSurface=CreateFrame("Frame",nil,desc);C.Box(self.difficultyFixedSurface,{width="createDifficultyFixedSurfaceWidth",height="createDifficultyFixedSurfaceHeight"});C.Panel(self.difficultyFixedSurface,"field","createPanelRadius2")
 self.difficultyFixed=C.Text(self.difficultyFixedSurface,"",14,"muted");C.SetLineHeight(self.difficultyFixed,20,true);self.difficultyFixed:SetPoint("CENTER")
 self.favorite=C.IconButton(desc,nil,T.createFavoriteWidth,function() UI:GetGroup().Presets:ToggleFavorite(P:FormData()) end,{iconSize=24});C.Box(self.favorite,{width="createFavoriteWidth",height="createFavoriteHeight2"});C.SetPoint(self.favorite,"TOPRIGHT",self.favorite:GetParent(),"TOPRIGHT",0,"createFavoriteToprightY")
 self.favoriteIcon=self.favorite.icon
 self.titleLabel=C.Text(desc,L.title,14,"muted");C.SetLineHeight(self.titleLabel,20,true);C.SetPoint(self.titleLabel,"TOPLEFT",self.titleLabel:GetParent(),"TOPLEFT",0,"createTitleLabelTopleftY")
 self.titleShell=Shell(desc,FORM,44,0,-116)
 self.descriptionLabel=C.Text(desc,L.comment,14,"muted");C.SetLineHeight(self.descriptionLabel,20,true);C.SetPoint(self.descriptionLabel,"TOPLEFT",self.descriptionLabel:GetParent(),"TOPLEFT",0,"createDescriptionLabelTopleftY")
 self.descriptionShell=Shell(desc,FORM,T.createDescriptionMinHeight,0,-196)
 for _,shell in ipairs({self.titleShell,self.descriptionShell}) do
  shell:EnableMouse(true)
  shell:SetScript("OnEnter",function() P:EnsureCreationInput() end)
  shell:SetScript("OnMouseDown",function(field,button) if button=="LeftButton" and P:EnsureCreationInput() then field.box:SetFocus() end end)
 end
 local req=CreateFrame("Frame",nil,f);req:SetSize(FORM,T.createReqHeight);C.SetPoint(req,"TOPLEFT",req:GetParent(),"TOPLEFT",0,"createReqTopleftY");self.req=req
 self.requirementsLabel=C.Text(req,L.requirements,14);C.SetLineHeight(self.requirementsLabel,20,true);self.requirementsLabel:SetPoint("TOPLEFT")
 self.ilvlLabel=C.Text(req,L.minItemLevel,14,"muted");C.SetPoint(self.ilvlLabel,"TOPLEFT",self.ilvlLabel:GetParent(),"TOPLEFT",0,"createIlvlLabelTopleftY")
 self.ilvl=C.Number(req,T.createIlvlWidth,T.createIlvlHeight);self.ilvl:SetPlaceholder(L.any);C.Box(self.ilvl,{width="createIlvlWidth",height="createIlvlHeight"});C.SetPoint(self.ilvl,"TOPLEFT",self.ilvl:GetParent(),"TOPLEFT",0,"createIlvlTopleftY")
 self.scoreLabel=C.Text(req,L.minRating,14,"muted");C.SetPoint(self.scoreLabel,"TOPLEFT",self.scoreLabel:GetParent(),"TOPLEFT","createScoreLabelTopleftX","createScoreLabelTopleftY")
 self.score=C.Number(req,T.createScoreWidth,T.createScoreHeight);self.score:SetPlaceholder(L.any);C.Box(self.score,{width="createScoreWidth",height="createScoreHeight"});C.SetPoint(self.score,"TOPLEFT",self.score:GetParent(),"TOPLEFT","createScoreTopleftX","createScoreTopleftY")
 self.styleLabel=C.Text(req,L.playstyle,14,"muted");C.SetPoint(self.styleLabel,"TOPLEFT",self.styleLabel:GetParent(),"TOPLEFT","createStyleLabelTopleftX","createStyleLabelTopleftY")
 self.playstyle=C.Choice(req,FORM-424,function() return P:PlaystyleItems() end,function(value) form.generalPlaystyle=value;P:ValidateForm() end);self.playstyle:SetHeight(T.createPlaystyleHeight);C.SetPoint(self.playstyle,"TOPLEFT",self.playstyle:GetParent(),"TOPLEFT","createPlaystyleTopleftX","createPlaystyleTopleftY")
 self.private=C.Check(req,L.private,function() P:ValidateForm() end);C.SetPoint(self.private,"TOPLEFT",self.private:GetParent(),"TOPLEFT",0,"createPrivateTopleftY")
 self.crossFaction=C.Check(req,L.crossFaction,function(value) form.crossFaction=value;P:ValidateForm() end);C.SetPoint(self.crossFaction,"TOPLEFT",self.crossFaction:GetParent(),"TOPLEFT","createCrossFactionTopleftX","createCrossFactionTopleftY")
 self.autoAccept=C.Check(req,L.autoAccept,function() P:ValidateForm() end);C.SetPoint(self.autoAccept,"TOPLEFT",self.autoAccept:GetParent(),"TOPLEFT","createAutoAcceptTopleftX","createAutoAcceptTopleftY")
 self.optionLayout=C.Row(req,{{frame=self.private},{frame=self.crossFaction},{frame=self.autoAccept}},{width="content",height="createOptionHeight",gap=28,includeHidden=true})
 self.autoInviteHint=C.Text(req,S("自动邀请会开启游戏语言过滤。","Auto invite enables the game's language filter."),12,"muted",FORM);C.SetPoint(self.autoInviteHint,"TOPLEFT",self.autoInviteHint:GetParent(),"TOPLEFT",0,"createAutoInviteHintTopleftY")
 self.publish=C.Button(f,L.publish,T.createPublishWidth,function() P:Submit() end);self.publish:SetWidth(T.createPublishWidth);self.publish:SetPoint("BOTTOMRIGHT");self.publish:SetHeight(T.createPublishHeight);self.publish:SetPrimary(true)
 self.formCancel=C.Button(f,L.cancel,T.createFormCancelWidth,function() state.editing=false;UI.Native:ReleaseCreation();P:RefreshMode() end);self.formCancel:SetWidth(T.createFormCancelWidth);self.formCancel:SetHeight(T.createFormCancelHeight);C.SetPoint(self.formCancel,"RIGHT",self.publish,"LEFT","createFormCancelRightX",0)
 self.formNotice=C.Notice(f,FORM,function() P:SetFormError("") end);C.SetPoint(self.formNotice,"TOPLEFT",self.formNotice:GetParent(),"TOPLEFT",0,"createFormNoticeTopleftY");self.formError=self.formNotice.text
 self.correctionNotice=C.Notice(f,FORM,function() P:HideCorrectionNotice() end);C.SetPoint(self.correctionNotice,"TOPLEFT",self.correctionNotice:GetParent(),"TOPLEFT",0,"createCorrectionNoticeTopleftY")
 f:HookScript("OnHide",function() P:HideCorrectionNotice() end)
 for _,label in ipairs({self.ilvlLabel,self.scoreLabel,self.styleLabel}) do C.SetLineHeight(label,20,true) end
 self.ilvl.box:HookScript("OnTextChanged",function(_,userInput)
  if userInput then P:CorrectItemLevel() end
  P:ValidateForm()
 end);self.score.box:HookScript("OnTextChanged",function() P:ValidateForm() end)
 local manage=CreateFrame("Frame",nil,surface);manage:SetSize(CONTENT,T.contentHeight-48);C.SetPoint(manage,"TOPLEFT",manage:GetParent(),"TOPLEFT","createManageTopleftX","createManageTopleftY");self.manage=manage
 self.sIcon=C.Icon(manage,T.createSIconWidth);C.Box(self.sIcon,{width="createSIconWidth",height="createSIconHeight"});C.SetPoint(self.sIcon,"TOPLEFT",self.sIcon:GetParent(),"TOPLEFT",0,"createSIconTopleftY")
 self.sMeta=C.Text(manage,"",14,"muted",CONTENT-280);C.SetFont(self.sMeta,14);C.SetLineHeight(self.sMeta,20,true);C.SetPoint(self.sMeta,"TOPLEFT",self.sMeta:GetParent(),"TOPLEFT","createSMetaTopleftX",0);self.sMeta:SetMaxLines(1);self.sMeta:SetWordWrap(false)
 self.sName=C.Text(manage,"",18,"text",CONTENT-280);C.SetLineHeight(self.sName,24,true);C.SetPoint(self.sName,"TOPLEFT",self.sName:GetParent(),"TOPLEFT","createSNameTopleftX","createSNameTopleftY");self.sName:SetWordWrap(false)
 self.editListing=C.Button(manage,L.edit,nil,function()
  local allowed,err=UI:GetGroup():CanManageListing();if not allowed then P:SetManageError(err);return end
  state.editing=true;P:RefreshMode()
 end);C.SetPoint(self.editListing,"TOPRIGHT",self.editListing:GetParent(),"TOPRIGHT","createEditListingToprightX","createEditListingToprightY");self.editListing:SetHeight(T.createEditListingHeight)
 self.cancelListing=C.Button(manage,S("取消招募","End listing"),nil,function() local ok,err=UI:GetGroup():RemoveListing();P:SetManageError(not ok and (err or L.failed) or "") end);C.SetPoint(self.cancelListing,"TOPRIGHT",self.cancelListing:GetParent(),"TOPRIGHT",0,"createCancelListingToprightY");self.cancelListing:SetHeight(T.createCancelListingHeight)
 self.listingFavorite=C.IconButton(manage,nil,T.createListingFavoriteWidth,function()
  local group=UI:GetGroup();local listing=group:GetListing()
  if listing then group.Presets:ToggleFavorite(listing) end
 end,{iconSize=24});C.Box(self.listingFavorite,{width="createListingFavoriteWidth",height="createListingFavoriteHeight"});C.SetPoint(self.listingFavorite,"TOPRIGHT",self.listingFavorite:GetParent(),"TOPRIGHT",0,"createListingFavoriteToprightY")
 self.cancelListing:ClearAllPoints();C.SetPoint(self.cancelListing,"RIGHT",self.listingFavorite,"LEFT","createCancelListingRightX",0)
 self.editListing:ClearAllPoints();C.SetPoint(self.editListing,"RIGHT",self.cancelListing,"LEFT","createEditListingRightX",0)
 self.applicantsHeading=C.Text(manage,L.manageApplicants,18);C.SetLineHeight(self.applicantsHeading,24,true);C.SetPoint(self.applicantsHeading,"TOPLEFT",self.applicantsHeading:GetParent(),"TOPLEFT",0,"createApplicantsHeadingTopleftY")
 self.appCount=C.Text(manage,"",14,"muted");C.SetLineHeight(self.appCount,20,true);C.SetPoint(self.appCount,"TOPRIGHT",self.appCount:GetParent(),"TOPRIGHT",0,"createAppCountToprightY")
 self.roleFilters={}
 local filterSurface=CreateFrame("Frame",nil,manage);C.Box(filterSurface,{width="createFilterSurfaceWidth",height="createFilterSurfaceHeight"});C.SetPoint(filterSurface,"TOPLEFT",filterSurface:GetParent(),"TOPLEFT",0,"createFilterSurfaceTopleftY");C.Panel(filterSurface,"panel","createPanelRadius2");self.roleFilterSurface=filterSurface
 for i,key in ipairs({"ALL","TANK","HEALER","DAMAGER"}) do
  local b=C.Button(filterSurface,key=="ALL" and L.all or roles[key],nil,function()
   if key=="ALL" then state.roles=nil
   else
    state.roles=state.roles or {};state.roles[key]=not state.roles[key] or nil
    if not next(state.roles) or state.roles.TANK and state.roles.HEALER and state.roles.DAMAGER then state.roles=nil end
   end
   P:RefreshApplicants()
  end,{variant="compact"});C.SetPoint(b,"TOPLEFT",b:GetParent(),"TOPLEFT",3+(i-1)*88,"createBTopleftY");if key~="ALL" then local roleIcon=C.Icon(b,T.createRoleIconWidth);b.roleIcon=roleIcon;C.Box(roleIcon,{width="createRoleIconWidth",height="createRoleIconHeight"});C.SetPoint(roleIcon,"LEFT",roleIcon:GetParent(),"LEFT","createRoleIconLeftX",0);UI:SetRoleIcon(roleIcon,key);b.label:ClearAllPoints();C.SetPoint(b.label,"LEFT",roleIcon,"RIGHT","createBLabelLeftX",0) end;self.roleFilters[key]=b
 end
 self.roleFilterItems={};for _,key in ipairs({"ALL","TANK","HEALER","DAMAGER"}) do self.roleFilterItems[#self.roleFilterItems+1]={frame=self.roleFilters[key]} end
 self.roleFilterOptions={width="content",height="content",gap=4,x=3};self.roleFilterLayout=C.Row(filterSurface,self.roleFilterItems,self.roleFilterOptions)
 self.sortChoice=C.Choice(manage,T.createSortChoiceWidth,function() return P.hideApplicantRating and noRatingApplicantSorts or P.showApplicantMapScore and dungeonApplicantSorts or applicantSorts end,function(value)
  state.sort=value;state.descending=value~="newest";P.applicantTable:SetSort(sortColumns[value],state.descending,true);P:RefreshApplicants()
 end);self.sortChoice:SetWidth(T.createSortChoiceWidth);self.sortChoice:SetHeight(T.createSortChoiceHeight);C.SetPoint(self.sortChoice,"TOPRIGHT",self.sortChoice:GetParent(),"TOPRIGHT",0,"createSortChoiceToprightY");self.sortChoice:SetValue("newest",L.newest)
 self:LayoutFont()
 self.applicantTableKind="dungeon"
 self.applicantTable=C.TableHeader(manage,ApplicantDefinitions("dungeon"),{
  onLayout=function(header) P:LayoutApplicantColumns(header) end,
  onSort=function(key,descending) state.sort=columnSorts[key] or "newest";state.descending=descending;P:RefreshApplicants() end,
 })
 self.applicantHeaders=self.applicantTable.labels
 self.batchScroll=CreateFrame("ScrollFrame",nil,manage);self.batchScroll:SetPoint("TOPLEFT",0,-T.createBatchTop);self.batchScroll:SetSize(BATCH_WIDTH,BATCH_MAX_HEIGHT)
 self.batchBody=CreateFrame("Frame",nil,self.batchScroll);self.batchBody:SetWidth(BATCH_WIDTH);self.batchBody:SetHeight(1);self.batchScroll:SetScrollChild(self.batchBody)
 self.batchSlider=C.ScrollBar(manage);self.batchSlider:SetHeight(BATCH_MAX_HEIGHT);self.batchSlider:SetPoint("TOPRIGHT",0,-T.createBatchTop)
 self.batchSlider:SetScript("OnValueChanged",function(_,value) if not P.syncBatchScroll then P:SetBatchOffset(value,false) end end)
 self.batchScroll:EnableMouseWheel(true);self.batchScroll:SetScript("OnMouseWheel",function(s,d) P:SetBatchOffset((P.batchScrollTarget or s:GetVerticalScroll())-d*56,true) end)
 self.batchPool={}
 self.empty=C.Text(manage,L.noApplicants,17,"muted",CONTENT-48);self.empty:SetPoint("CENTER",self.batchScroll,"CENTER",0,0);self.empty:SetJustifyH("CENTER")
 self.manageNotice=C.Notice(manage,CONTENT,function() P:SetManageError("") end);C.SetPoint(self.manageNotice,"TOPLEFT",self.manageNotice:GetParent(),"TOPLEFT",0,"createManageNoticeTopleftY");self.dError=self.manageNotice.text
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(T.createRailWidth,T.contentHeight);rail:SetPoint("TOPRIGHT");self.rail=rail
 local favoritesCard=CreateFrame("Frame",nil,rail);C.Box(favoritesCard,{width="createFavoritesCardWidth",height="createFavoritesCardHeight"});favoritesCard:SetPoint("TOPLEFT");C.Panel(favoritesCard,"surfaceLow","createPanelRadius");self.favoritesCard=favoritesCard
 self.favoritesToggle=C.Button(favoritesCard,S("收藏","Favorites"),T.createFavoritesToggleWidth,function() P.favoritesExpanded=not P.favoritesExpanded;P:RefreshFavorites() end);self.favoritesToggle:SetWidth(T.createFavoritesToggleWidth);self.favoritesToggle:SetHeight(T.createFavoritesToggleHeight);C.SetPoint(self.favoritesToggle,"TOPLEFT",self.favoritesToggle:GetParent(),"TOPLEFT","createFavoritesToggleTopleftX","createFavoritesToggleTopleftY");C.SetFont(self.favoritesToggle.label,16);C.SetLineHeight(self.favoritesToggle.label,22,true);self.favoritesToggle.label:ClearAllPoints();C.SetPoint(self.favoritesToggle.label,"LEFT",self.favoritesToggle.label:GetParent(),"LEFT","createFavoritesToggleLabelLeftX",0)
 self.favoritesChevron=C.Icon(self.favoritesToggle,T.createFavoritesChevronWidth);self.favoritesChevron:SetWidth(T.createFavoritesChevronWidth);self.favoritesChevron:SetHeight(T.createFavoritesChevronHeight);self.favoritesChevron:SetVertexColor(unpack(T.muted));UI:SetMediaTexture(self.favoritesChevron,"chevron.tga");C.SetPoint(self.favoritesChevron,"RIGHT",self.favoritesChevron:GetParent(),"RIGHT","createFavoritesChevronRightX",0)
 local rosterCard=CreateFrame("Frame",nil,rail);rosterCard:SetSize(T.createRosterCardWidth,T.contentHeight-84);C.SetPoint(rosterCard,"TOPLEFT",rosterCard:GetParent(),"TOPLEFT",0,"createRosterCardTopleftY");C.Panel(rosterCard,"surfaceLow","createPanelRadius");self.rosterCard=rosterCard
 self.rosterTitle=C.Text(rosterCard,L.yourGroup,18,nil,nil,24);C.SetLineHeight(self.rosterTitle,24,true);C.SetPoint(self.rosterTitle,"TOPLEFT",self.rosterTitle:GetParent(),"TOPLEFT","createRosterTitleTopleftX","createRosterTitleTopleftY")
 self.rosterCount=C.Text(rosterCard,"",14,"muted");C.SetLineHeight(self.rosterCount,20,true);C.SetPoint(self.rosterCount,"LEFT",self.rosterTitle,"RIGHT","createRosterCountLeftX",0)
 local summary=CreateFrame("Frame",nil,rosterCard);C.Box(summary,{width="createSummaryWidth",height="createSummaryHeight"});C.SetPoint(summary,"TOPLEFT",summary:GetParent(),"TOPLEFT","createSummaryTopleftX","createSummaryTopleftY");self.groupSummary=summary
 summary.hover=C.Panel(summary,"createRosterHoverColor","createSummaryHoverRadius");summary.hover:Hide();summary.hover:SetAlpha(0)
 self.groupStrip=UI:CreateRoster(summary,18,5);self.groupStrip:SetHeight(T.createGroupStripHeight);C.SetPoint(self.groupStrip,"LEFT",self.groupStrip:GetParent(),"LEFT","createGroupStripLeftX",0)
 summary.hoverStyle=C.Style(summary,{recipe="hoverSurface",variant="roster",immediate=true,slots={root=summary,surface=summary.hover}})
 local function ClearSummaryHover() summary.hoverStyle:SetState("hover",false);UI.Motion:Stop(summary.hover);summary.hover:Hide();summary.hover:SetAlpha(0) end
 summary:SetScript("OnEnter",function() summary.hoverStyle:SetState("hover",true);summary.hover:Show();UI.Motion:Alpha(summary.hover,1,T.createRosterHoverDuration);UI.Tooltip:ShowRoster(summary,P.roster,nil,P.rosterContext) end)
 summary:SetScript("OnLeave",function() ClearSummaryHover();UI.Tooltip:LeaveOwner(summary) end)
 summary:SetScript("OnHide",function() ClearSummaryHover();HideMemberTooltip(summary) end)
 summary:EnableMouse(false);summary:EnableMouseMotion(true)
 self.applicantTable:Layout(BATCH_WIDTH)
 self:RefreshFavorites()
self:RegisterBuildElements()
 end
local function LayoutSize(self,width,height)
 self.layoutHeight=height
 MAIN=width-T.createRailWidth-T.createRailGap;CONTENT=MAIN-T.createContentInset*2;FORM=CONTENT;BATCH_WIDTH=CONTENT-C.listRightInset
 BATCH_MAX_HEIGHT=height-T.createBatchBottomReserve
 self.surface:SetSize(MAIN,height);self.formFrame:SetSize(FORM,height-48);self.manage:SetSize(CONTENT,height-48)
 self.desc:SetWidth(FORM);self.req:SetWidth(FORM);self.titleShell:SetWidth(FORM);self.descriptionShell:SetWidth(FORM)
 for _,notice in ipairs({self.formNotice,self.correctionNotice}) do
  notice:SetWidth(FORM)
  if notice:IsShown() then notice:SetMessage(notice.text:GetText()) end
 end
 self.autoInviteHint:SetWidth(FORM)
 local summaryWidth=CONTENT-116-self.cancelListing:GetWidth()-8-self.editListing:GetWidth()
 self.sMeta:SetWidth(summaryWidth);self.sName:SetWidth(summaryWidth)
 self.manageNotice:SetWidth(CONTENT);self.empty:SetWidth(CONTENT-48)
 self.batchScroll:SetWidth(BATCH_WIDTH);self.batchBody:SetWidth(BATCH_WIDTH)
 self.rail:SetHeight(height)
end
function P:LayoutSize(width,height)
 LayoutSize(self,width,height)
 self:LayoutRequirements();self:LayoutFormNotices()
 if self.pickerVariants then self:LayoutActivityChoice(self.pickerVariants) end
 self.applicantTable:SetColumns(ApplicantDefinitions(self.applicantTableKind),BATCH_WIDTH)
 self:LayoutRosterCard()
UI:ApplyElementScope("create")
 end
function P:ReflowMetrics(width,height)
 LayoutSize(self,width,height)
 self.formFrame:SetPoint("TOPLEFT",T.createContentInset,-T.createContentInset)
 self.manage:SetPoint("TOPLEFT",T.createContentInset,-T.createContentInset)
 self.rail:SetWidth(T.createRailWidth)
 LayoutFont(self,ApplicantDefinitions(self.applicantTableKind))
 if self.favoritesList then self.favoritesList.hoverColor="createFavoriteHoverColor" end
 self:RefreshFavorites()
UI:ApplyElementScope("create")
 end
function P:GetMinimumHeight()
 if not self.formFrame:IsShown() then return 0 end
 local offset=self.formNotice:IsShown() and self.formNotice:GetHeight()+12 or 0
 if self.correctionNotice:IsShown() then offset=offset+self.correctionNotice:GetHeight()+12 end
 local _,_,_,_,_,_,_,minimumTop=FontGeometry(self)
 local _,optionTop=RequirementGeometry(self)
 local requirementsBottom=optionTop+46+self.autoInviteHint:GetStringHeight()
 return minimumTop+offset+requirementsBottom+24+40+48+T.headerHeight+T.pageInset
end
function P:LayoutFormNotices()
 local offset=self.formNotice:IsShown() and self.formNotice:GetHeight()+12 or 0
 self.correctionNotice:ClearAllPoints();self.correctionNotice:SetPoint("TOPLEFT",0,-44-offset)
 if self.correctionNotice:IsShown() then offset=offset+self.correctionNotice:GetHeight()+12 end
 local minimumTop=self.minimumRequirementsTop or 356
 local extra=math.max(0,self.formFrame:GetHeight()-minimumTop-offset-self.requirementsBottom-24-40)
 self.requirementsTop=minimumTop+extra
 self.descriptionShell:SetHeight(T.createDescriptionMinHeight+extra)
 self.desc:SetHeight((self.descriptionInputTop or 196)+self.descriptionShell:GetHeight())
 self.desc:ClearAllPoints();self.desc:SetPoint("TOPLEFT",0,-56-offset)
 self.req:ClearAllPoints();self.req:SetPoint("TOPLEFT",0,-self.requirementsTop-offset)
end
function P:SetFormError(message)
 local wasShown=self.formNotice:IsShown()
 self.formNotice:SetMessage(message)
 if not wasShown and not self.formNotice:IsShown() then return end
 self:LayoutFormNotices()
 if UI.page=="create" then UI:RefreshWindowSize() end
end
function P:HideCorrectionNotice()
 if self.correctionTimer then self.correctionTimer:Cancel();self.correctionTimer=nil end
 self.correctionExpired=nil
 if not self.correctionNotice:IsShown() then return end
 self.correctionNotice:SetMessage("");self:LayoutFormNotices()
end
function P:ShowCorrectionNotice(message)
 if self.correctionTimer then self.correctionTimer:Cancel() end
 self.correctionExpired=nil
 self.correctionNotice:SetMessage(message);self:LayoutFormNotices()
 UI:RefreshWindowSize()
 self.correctionTimer=C_Timer.NewTimer(4,function()
  P.correctionTimer=nil
  if UI.hiding then P.correctionExpired=true else P:HideCorrectionNotice() end
 end)
end
function P:RefreshFavoriteState()
 local group=UI:GetGroup()
 local function Update(button,settings)
  local available=settings~=nil and settings.activityID~=nil
  button.selected=available and group.Presets:Find(settings)~=nil or false;button:SetAvailable(available)
  button.icon:SetTexture("Interface\\AddOns\\LycheeGroup_UI\\Media\\favorite-"..(button.selected and "on" or "off")..".tga")
 end
 Update(self.favorite,self:FormData());Update(self.listingFavorite,group:GetListing())
end
local function SetFavoriteTarget(button,entry)
 if button.targetKey==entry then return end
 if button.pressedKey then button.pressCancelled=true end
 button.targetKey=entry
end
function P:BuildFavorites()
 local body=CreateFrame("Frame",nil,self.favoritesCard);C.SetPoint(body,"TOPLEFT",body:GetParent(),"TOPLEFT","createBodyTopleftX","createBodyTopleftY");body:SetWidth(T.createBodyWidth);self.favoritesBody=body
 self.favoritesEmpty=C.Text(body,S("暂无收藏","No favorites yet"),13,"dim",T.createFavoritesEmptyWidth);self.favoritesEmpty:SetWidth(T.createFavoritesEmptyWidth);C.SetLineHeight(self.favoritesEmpty,20);self.favoritesEmpty:SetWordWrap(true);self.favoritesEmpty:SetPoint("TOPLEFT")
 local list=C.List(body,T.createListWidth,T.createFavoriteHeight*3,T.createFavoriteHeight);list:SetWidth(T.createListWidth);list:SetPoint("TOPLEFT");list.selectionFill=false;list.selectionMark=false;list.hoverColor="createFavoriteHoverColor";list.alternateRows=false;self.favoritesList=list
 list.favoriteLayouts={}
 list.measure=C.Text(list.canvas,"",12,"muted");C.SetLineHeight(list.measure,18);list.measure:SetWordWrap(true);list.measure:Hide()
 list:SetRowHeightResolver(function(entry) local layout=list.favoriteLayouts[entry];return layout and layout.height or T.createFavoriteHeight end)
 for _,row in ipairs(list.rows) do
  row:SetScript("OnClick",nil);row:SetScript("OnMouseDown",nil);row:SetScript("OnMouseUp",nil);row.hover:SetRadius(8)
  row.icon=C.GameIcon(row,T.createRowIconWidth);C.Box(row.icon,{width="createRowIconWidth",height="createRowIconHeight"});C.SetPoint(row.icon,"TOPLEFT",row.icon:GetParent(),"TOPLEFT","createRowIconTopleftX","createRowIconTopleftY")
  C.SetFont(row.title,14);C.SetLineHeight(row.title,20,true);row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","createRowTitleTopleftX","createRowTitleTopleftY")
  C.SetFont(row.meta,12);C.SetLineHeight(row.meta,18);row.meta:SetWordWrap(true);row.meta:SetJustifyV("TOP");row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","createRowMetaTopleftX","createRowMetaTopleftY")
  row.conditions=C.Text(row,"",12,"muted");C.SetLineHeight(row.conditions,18);row.conditions:SetWordWrap(true);row.conditions:SetJustifyV("TOP")
  row.unavailable=C.Text(row,"",12,"muted");C.SetLineHeight(row.unavailable,18,true);row.unavailable:SetWordWrap(false);C.SetPoint(row.unavailable,"BOTTOMLEFT",row.unavailable:GetParent(),"BOTTOMLEFT","createRowUnavailableBottomleftX","createRowUnavailableBottomleftY")
  local function Active() return row.key and row._hitVisible and list.clip:IsMouseOver() end
  row.create=C.Button(row,S("应用","Apply"),T.createRowCreateWidth,function(button) if Active() and button.targetKey==row.key then P:UsePreset(button.targetKey) end end);row.create:SetWidth(T.createRowCreateWidth);row.create:SetHeight(T.createRowCreateHeight);C.SetPoint(row.create,"BOTTOMRIGHT",row.create:GetParent(),"BOTTOMRIGHT","createRowCreateBottomrightX","createRowCreateBottomrightY");C.SetFont(row.create.label,12);C.SetLineHeight(row.create.label,18,true);row.create:SetSurfaceColors("secondaryContainer","refreshHover","surfaceHighest")
  row.remove=C.Button(row,"",T.createRowRemoveWidth,function(button) if Active() and button.targetKey==row.key then UI:GetGroup().Presets:Remove(button.targetKey) end end);row.remove:SetWidth(T.createRowRemoveWidth);row.remove:SetHeight(T.createRowRemoveHeight);C.SetPoint(row.remove,"TOPRIGHT",row.remove:GetParent(),"TOPRIGHT","createRowRemoveToprightX","createRowRemoveToprightY");row.remove.elementIcon=C.Glyph(row.remove,"close",T.createGlyphWidth,T.dim);row.remove.elementIcon:SetPoint("CENTER")
  row:HookScript("OnHide",function() SetFavoriteTarget(row.create,nil);SetFavoriteTarget(row.remove,nil) end)
 end
 self:RegisterBuildElements()
 end
local function RefreshFavorites(self)
 local bodyHeight=0
 self.favoritesChevron:SetRotation(self.favoritesExpanded and -math.pi/2 or 0)
 if self.favoritesExpanded then
  if not self.favoritesBody then self:BuildFavorites() end
  self.favoritesBody:Show()
  local group=UI:GetGroup();local canManage=group:CanManageListing();local recruiting=group:GetListing()~=nil;local canCreate=canManage and not recruiting
   local entries=group.Presets:Get();local list=self.favoritesList
   local layouts=list.favoriteLayouts;for _,layout in pairs(layouts) do layout.active=false end
   local measure=list.measure;measure:SetFont(list.rows[1].meta:GetFont());measure:SetSpacing(list.rows[1].meta:GetSpacing())
   local lineHeight=measure:GetLineHeight()+measure:GetSpacing()
   local function TextHeight(text,width)
    measure:SetWidth(width);measure:SetText(text)
    return math.max(lineHeight,measure:GetStringHeight())
   end
   local function Layout(gutter)
    local width=list:GetWidth()-gutter;local total=0
    -- Difficulty shares its first line with Apply; conditions use the width below.
    local metaWidth=math.max(1,width-T.createRowMetaTopleftX+T.createRowCreateBottomrightX-T.createRowCreateWidth-8)
    for _,entry in ipairs(entries) do
    local activity=group.Catalog:GetActivity(entry.activityID)
    local context=activity and group.Catalog:GetContextForActivity(entry.activityID)
    local activityGroup=context and group.Catalog:GetGroup(context,group.Catalog:GetGroupKey(context,activity))
    local difficulty=activity and activity.difficultyID and ActivityLabel(GetDifficultyInfo(activity.difficultyID))
    local summary={}
    if entry.requiredItemLevel and entry.requiredItemLevel>0 then summary[#summary+1]=S("装等 ","iLvl ")..entry.requiredItemLevel end
    local ratingKind=A.GroupPresentation.Activity(activity).requirementRatingKind;local score=ratingKind=="pvp" and entry.requiredPvpRating or ratingKind=="dungeon" and entry.requiredDungeonScore
    if score and score>0 then summary[#summary+1]=S("评分 ","Rating ")..score end
    local detail=difficulty or S("无条件要求","No requirements")
    local conditions=table.concat(summary," · ")
    local reason=recruiting and "" or not canManage and S("没有管理权限","No permission") or not activity and L.unavailable or ""
    local metaTop=-T.createRowMetaTopleftY;local metaHeight=TextHeight(detail,metaWidth)
    local createTop=metaTop+(lineHeight-T.createRowCreateHeight)/2
    local bottom=math.max(metaTop+metaHeight,createTop+T.createRowCreateHeight)
    local conditionsTop,conditionsHeight
    if conditions~="" then conditionsTop=bottom+6;conditionsHeight=TextHeight(conditions,width-24);bottom=conditionsTop+conditionsHeight end
    local reasonTop,reasonHeight
    if reason~="" then reasonTop=bottom+6;reasonHeight=TextHeight(reason,width-24);bottom=reasonTop+reasonHeight end
    local layout=layouts[entry] or {};layouts[entry]=layout;layout.active=true
    layout.activity,layout.title=activity,ActivityLabel(activityGroup and activityGroup.name or activity and activity.name) or L.unavailable
    layout.detail,layout.metaWidth,layout.metaHeight,layout.createTop=detail,metaWidth,metaHeight,createTop
    layout.conditions,layout.conditionsTop,layout.conditionsHeight=conditions,conditionsTop,conditionsHeight
    layout.reason,layout.reasonTop,layout.reasonHeight=reason,reasonTop,reasonHeight
    layout.height=math.max(T.createFavoriteHeight,math.ceil(bottom+T.createRowCreateBottomrightY));total=total+layout.height
    end
    return total
   end
   local maximum=T.createFavoriteHeight*3;local total=Layout(0);local gutter=total>maximum and C.listRightInset or 0
   if gutter>0 then total=Layout(gutter) end
   for entry,layout in pairs(layouts) do if not layout.active then layouts[entry]=nil end end
   measure:SetText("")
   bodyHeight=#entries>0 and math.min(maximum,total) or math.max(40,self.favoritesEmpty:GetStringHeight())
   self.favoritesEmpty:SetShown(#entries==0);list:SetShown(#entries>0);list:SetViewport(bodyHeight)
   if list.gutter~=gutter then list:SetGutter(gutter) end
   list:SetItems(entries,function(row,entry)
    local layout=layouts[entry];if not layout then return end
    SetFavoriteTarget(row.create,entry);SetFavoriteTarget(row.remove,entry)
    UI:SetActivityIcon(row.icon,layout.activity)
    UI:SetText(row.title,layout.title);row.title:SetWidth(row:GetWidth()-104)
    UI:SetText(row.meta,layout.detail);row.meta:SetWidth(layout.metaWidth);row.meta:SetHeight(layout.metaHeight)
    row.create:ClearAllPoints();row.create:SetPoint("TOPRIGHT",row,"TOPRIGHT",T.createRowCreateBottomrightX,-layout.createTop)
    row.create:SetAvailable(canCreate and layout.activity~=nil)
    UI:SetText(row.conditions,layout.conditions);row.conditions:SetShown(layout.conditions~="")
    if layout.conditionsTop then row.conditions:ClearAllPoints();row.conditions:SetPoint("TOPLEFT",row,"TOPLEFT",12,-layout.conditionsTop);row.conditions:SetWidth(row:GetWidth()-24);row.conditions:SetHeight(layout.conditionsHeight) end
    UI:SetText(row.unavailable,layout.reason);row.unavailable:SetShown(layout.reason~="")
    if layout.reasonTop then row.unavailable:ClearAllPoints();row.unavailable:SetPoint("TOPLEFT",row,"TOPLEFT",12,-layout.reasonTop);row.unavailable:SetWidth(row:GetWidth()-24);row.unavailable:SetHeight(layout.reasonHeight) end
   end)
  self.favoritesBody:SetHeight(bodyHeight)
 elseif self.favoritesBody then
  self.favoritesBody:Hide();self.favoritesList:Clear()
  for entry in pairs(self.favoritesList.favoriteLayouts) do self.favoritesList.favoriteLayouts[entry]=nil end
 end
 self.favoritesCard:SetHeight(self.favoritesExpanded and 80+bodyHeight or 68)
 self:RefreshFavoriteState()
end
function P:RefreshFavorites()
 RefreshFavorites(self)
 self:LayoutRosterCard()
end
function P:BuildRaidBuffs()
 local area=CreateFrame("Frame",nil,self.rosterCard);C.SetPoint(area,"TOPLEFT",area:GetParent(),"TOPLEFT","createAreaTopleftX","createAreaTopleftY");area:SetWidth(T.createAreaWidth);self.buffArea=area
 self.buffTitle=C.Text(area,S("缺少增益","Missing buffs"),14,"text",T.createBuffTitleWidth);self.buffTitle:SetWidth(T.createBuffTitleWidth);C.SetLineHeight(self.buffTitle,20,true);self.buffTitle:SetPoint("TOPLEFT")
 self.buffComplete=C.Text(area,S("主要增益齐全","All main buffs covered"),13,"good",T.createBuffCompleteWidth);self.buffComplete:SetWidth(T.createBuffCompleteWidth);C.SetLineHeight(self.buffComplete,20,true);C.SetPoint(self.buffComplete,"TOPLEFT",self.buffComplete:GetParent(),"TOPLEFT",0,"createBuffCompleteTopleftY")
 self.buffList=C.List(area,T.createBuffListWidth,T.createBuffListHeight,32);C.Box(self.buffList,{width="createBuffListWidth",height="createBuffListHeight"});C.SetPoint(self.buffList,"TOPLEFT",self.buffList:GetParent(),"TOPLEFT",0,"createBuffListTopleftY");self.buffList.selectionFill=false;self.buffList.selectionMark=false;self.buffList.hoverFill=false;self.buffList.alternateRows=false
 self.buffRows={}
 for _,row in ipairs(self.buffList.rows) do
  row.title:Hide();row.meta:Hide();row:SetScript("OnClick",nil);row:EnableMouse(false);row:EnableMouseMotion(false);row.cells={}
  for i=1,2 do
   local cell=CreateFrame("Frame",nil,row);cell:SetHeight(T.createCellHeight)
   cell.icon=C.Icon(cell,T.createCellIconWidth);C.Box(cell.icon,{width="createCellIconWidth",height="createCellIconHeight"});cell.icon:SetPoint("LEFT",0,0)
   cell.label=C.Text(cell,"",13,"muted");C.SetLineHeight(cell.label,20,true);C.SetPoint(cell.label,"LEFT",cell.label:GetParent(),"LEFT","createCellLabelLeftX",0);cell.label:SetWordWrap(false)
   row.cells[i]=cell
  end
 end
self:RegisterBuildElements()
 end
function P:BuildRosterList()
 local list=CreateFrame("Frame",nil,self.rosterCard);C.SetPoint(list,"TOPLEFT",list:GetParent(),"TOPLEFT","createListTopleftX","createListTopleftY");list:SetWidth(T.createListWidth);self.rosterList=list
 local clip=CreateFrame("ScrollFrame",nil,list);clip:SetPoint("TOPLEFT");clip:SetPoint("BOTTOMRIGHT");list.clip=clip;list.gutter=0
 local body=CreateFrame("Frame",nil,clip);body:SetWidth(list:GetWidth());body:SetHeight(1);clip:SetScrollChild(body);list.body=body;list.rows={}
 local slider=C.ScrollBar(list);slider:SetPoint("TOPRIGHT");slider:SetPoint("BOTTOMRIGHT");list.slider=slider
 slider:SetScript("OnValueChanged",function(_,value) if not list.syncing then P:SetRosterOffset(value) end end)
 list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",function(_,delta) P:SetRosterOffset(clip:GetVerticalScroll()-delta*48) end)
 list.empty=C.Text(body,L.rosterEmpty,13,"muted",body:GetWidth());C.SetLineHeight(list.empty,20);C.SetPoint(list.empty,"TOPLEFT",list.empty:GetParent(),"TOPLEFT","createListEmptyTopleftX","createListEmptyTopleftY")
self:RegisterBuildElements()
 end
function P:SetRosterOffset(offset)
 local list=self.rosterList;local height=list:GetHeight()
 offset=math.max(0,math.min(offset,math.max(0,list.body:GetHeight()-height)))
 list.clip:SetVerticalScroll(offset);list.syncing=true;list.slider:SetValue(offset);list.syncing=nil
 for _,row in ipairs(list.rows) do if row.member then
  local top=row.contentTop-offset;local rowHeight=row:GetHeight()
  local cropTop=math.min(rowHeight,math.max(0,-top));local cropBottom=math.min(rowHeight-cropTop,math.max(0,top+rowHeight-height))
  row:SetHitRectInsets(0,0,cropTop,cropBottom);row._hitVisible=cropTop+cropBottom<rowHeight
  row:EnableMouse(row._hitVisible);row.tooltipArea:EnableMouseMotion(row._hitVisible)
  if not row._hitVisible then HideMemberTooltip(row) end
 end end
end
function P:RefreshRosterList(gutter)
 if not self.rosterList then self:BuildRosterList() end
 local list=self.rosterList;list:Show();list.empty:SetShown(#self.roster==0)
 gutter=gutter or 0
 if list.gutter~=gutter then
  list.gutter=gutter;list.clip:SetPoint("BOTTOMRIGHT",-gutter,0)
  list.body:SetWidth(list:GetWidth()-gutter);list.empty:SetWidth(list.body:GetWidth())
 end
 for i=1,#self.roster do
  local row=list.rows[i]
  if not row then
   row=UI.Members:Create(list.body,function(button,key)
    if not button.member or button._hitVisible==false or not list.clip:IsMouseOver() then return end
    if key=="RightButton" then UI.Members:OpenMenu(button,button.member,function() UI.Tooltip:Hide() end)
    else UI.Tooltip:ShowPlayer(button,button.member,button.memberContext) end
   end)
   row:SetFeedbackColors("createRosterMemberHover","createRosterMemberPressed")
   UI:Element(row,"create.rosterMember","create",row,"create.rosterMember");MemberTooltipArea(row,list.clip);list.rows[i]=row
  end
 end
 -- A slot can be reused while the same person moves elsewhere in the roster.
 local tip=UI.Tooltip
 for i,member in ipairs(self.roster) do
  tip:RebindRosterOwner(UI.Members:ID(member),list.rows[i])
 end
 local top=0
 for i,member in ipairs(self.roster) do
  local row=list.rows[i]
  if row.member~=member then
   tip:HideRosterOwner(row,UI.Members:ID(member))
   UI:CloseMenuFor(row)
  end
  row.memberContext=A.GroupPresentation.Member("roster")
  UI.Members:BindRoster(row,member,list.body:GetWidth(),member.isLeader,true,12,8)
  row.contentTop=top;row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-top);top=top+row:GetHeight()+4
 end
 for i=#self.roster+1,#list.rows do local row=list.rows[i];HideMemberTooltip(row);UI:CloseMenuFor(row);row:Hide();row.member=nil;row.memberContext=nil;C.RekeyElement(row,nil) end
 list.body:SetHeight(#self.roster>0 and top-4 or 36)
 if gutter==0 then list.fullHeight=list.body:GetHeight() end
end
function P:ClearRosterList()
 if not self.rosterList then return end
 self.rosterList:Hide()
 for _,row in ipairs(self.rosterList.rows) do HideMemberTooltip(row);UI:CloseMenuFor(row);row:Hide();row.member=nil;row.memberContext=nil;C.RekeyElement(row,nil) end
end
function P:LayoutRosterCard()
 local top=self.favoritesCard:GetHeight()+16
 self.rosterCard:ClearAllPoints();self.rosterCard:SetPoint("TOPLEFT",0,-top)
 local height=112
 if self.rosterContext and self.rosterContext.rosterMode=="list" and self.rosterList then
  local list=self.rosterList;local available=math.max(44,(self.layoutHeight or T.contentHeight)-top-76)
  -- Decide from full-width text so wrapping in the narrower scroll area cannot keep an unnecessary gutter.
  local gutter=list.fullHeight>available and C.listRightInset or 0
  if list.gutter~=gutter then self:RefreshRosterList(gutter) end
  local viewport=math.min(list.body:GetHeight(),available)
  list:SetHeight(viewport);list.syncing=true;list.slider:SetMinMaxValues(0,math.max(0,list.body:GetHeight()-viewport));list.syncing=nil
  list.slider:SetShown(list.body:GetHeight()>viewport);self:SetRosterOffset(list.clip:GetVerticalScroll());height=76+viewport
 elseif self.buffReport then
  local rows=math.ceil(#self.buffReport.missing/2)
  local viewport=math.min(math.max(1,rows)*32,math.max(32,math.floor(((self.layoutHeight or T.contentHeight)-top-164)/32)*32))
  height=164+viewport;self.buffArea:SetHeight(height-132)
  self.buffList:SetViewport(viewport)
  local gutter=rows*32>viewport and C.listRightInset or 0
  if self.buffList.gutter~=gutter then self.buffList:SetGutter(gutter) end
 end
 self.rosterCard:SetHeight(height)
end
local function FinishRosterPresentation(self)
 self:LayoutRosterCard()
 if self.roster then UI.Tooltip:RefreshRoster(self.groupSummary,self.roster,self.rosterContext) end
end
local function RefreshRosterPresentation(self)
 if not self.roster then return end
 local group=UI:GetGroup();local listing=group:GetListing()
 local activityID=listing and listing.activityID or form.activityID
 local previous=self.rosterContext
 self.rosterContext=A.GroupPresentation.Activity(group.Catalog:GetActivity(activityID))
 if previous~=self.rosterContext then HideMemberTooltip(self.groupSummary) end
 local inline=self.rosterContext.rosterMode=="list"
 self.groupSummary:SetShown(not inline)
 if inline then self:RefreshRosterList() else self:ClearRosterList() end
 self.buffReport=group:GetRaidBuffs(activityID)
 if self.buffReport then
  if not self.buffArea then self:BuildRaidBuffs() end
  self.buffArea:Show()
  local report=self.buffReport
  UI:SetText(self.buffTitle,report.unknown>0 and S("待确认增益","Unconfirmed buffs") or S("缺少增益","Missing buffs"))
  self.buffComplete:SetShown(#report.missing==0);self.buffList:SetShown(#report.missing>0)
  wipe(self.buffRows);for i=1,#report.missing,2 do self.buffRows[#self.buffRows+1]=i end
  self.buffList:SetItems(self.buffRows,function(row,index)
   local width=(row:GetWidth()-8)/2
   for i,cell in ipairs(row.cells) do
    local definition=report.missing[index+i-1];cell:SetShown(definition~=nil)
    if definition then
     cell:ClearAllPoints();cell:SetPoint("LEFT",(i-1)*(width+8),0);cell:SetWidth(width);cell.label:SetWidth(width-22)
     UI:SetMemberIcon(cell.icon,definition)
     UI:SetText(cell.label,definition.key=="poisons" and report.counts.ROGUE==1 and S("毒药仅1人","1 rogue only") or zh and definition.cn or definition.en)
    end
   end
  end)
 elseif self.buffArea then
  self.buffArea:Hide();self.buffList:Clear()
 end
end
function P:RefreshRosterPresentation()
 if not self.roster then return end
 RefreshRosterPresentation(self)
 FinishRosterPresentation(self)
end
function P:UsePreset(entry)
 local group=UI:GetGroup();local allowed,reason=group:CanManageListing()
 if not allowed then self:ShowError(reason);return end
 if group:GetListing() then self:SetManageError(S("请先结束当前招募，再应用收藏条件。","End the current listing before applying saved settings."));return end
 local activity=group.Catalog:GetActivity(entry.activityID)
 if not activity then self:SetFormError(L.unavailable);return end
 if not self:EnsureCreationInput() then return end
 self.preparing=true;self.validationSubmitted=nil;self:ClosePicker();state.editing=false
 form.activityID=entry.activityID;state.category=group.Catalog:GetContextForActivity(entry.activityID,state.category) or tostring(activity.categoryID)
 state.group=group.Catalog:GetGroupKey(state.category,activity);state.tier=group.Catalog:GetActivityTier(activity)
 form.generalPlaystyle=entry.generalPlaystyle;form.crossFaction=entry.isCrossFactionListing==true
 form.presetActivityID=entry.activityID;form.playstyle,form.newPlayerFriendly,form.questID=entry.playstyle,entry.newPlayerFriendly,entry.questID
 self.ilvl.box:SetText(entry.requiredItemLevel and entry.requiredItemLevel>0 and tostring(entry.requiredItemLevel) or "")
 local ratingKind=A.GroupPresentation.Activity(activity).requirementRatingKind;local score=ratingKind=="pvp" and entry.requiredPvpRating or ratingKind=="dungeon" and entry.requiredDungeonScore
 self.score.box:SetText(score and score>0 and tostring(score) or "")
 self.private:SetValue(entry.privateGroup==true);self.crossFaction:SetValue(form.crossFaction);self.autoAccept:SetValue(entry.autoAccept==true)
 self:RefreshPicker();self.preparing=nil;self:ValidateForm()
 UI.Native.entry.Name:SetFocus()
end
function P:LayoutApplicantColumns(header)
 local previousNameWidth=columns.name.width
 local layout={rating=columns.rating,mapScore=columns.mapScore}
 for _,definition in ipairs(header.definitions) do
  local key=definition.key;local cell=header.columns[key];local before,after=ApplicantPadding(key)
  layout[key]={x=cell.x+before,width=math.max(1,cell.width-before-after),align=definition.align}
 end
 columns=layout;self.applicantColumns=layout
 if not self.batchPool then return end
 for _,batch in ipairs(self.batchPool) do
  batch:SetWidth(BATCH_WIDTH);batch.invite:SetPoint("LEFT",layout.actions.x,0);batch.decline:SetPoint("LEFT",layout.actions.x+44,0)
  batch.status:SetPoint("LEFT",layout.actions.x,0);batch.status:SetWidth(layout.actions.width)
  for _,row in ipairs(batch.people) do
   row:SetWidth(header.columns.actions.x);row.icon:SetPoint("LEFT",layout.name.x,0);row.title:SetPoint("LEFT",layout.name.x+44,0)
   for key,field in pairs({rating="score",mapScore="mapScore",ilvl="ilvl"}) do
    row[field]:SetPoint("LEFT",layout[key].x,0);row[field]:SetWidth(layout[key].width)
   end
   row.race:SetWidth(layout.faction.width);LayoutApplicantFaction(row)
   LayoutApplicantMapScore(row,layout)
   if row.member and self.showApplicantMapScore then DrawApplicantMapScore(row) end
   if row.member then UpdateApplicantRoles(row,row.member,layout) end
  end
 end
 if self.appIDs and previousNameWidth~=layout.name.width then self:LayoutBatches() else self:LayoutApplicantViewport() end
end
function P:LayoutApplicantViewport()
 local offset=self.manageNotice:IsShown() and self.manageNotice:GetHeight()+12 or 0
 self.applicantTable:ClearAllPoints();self.applicantTable:SetPoint("TOPLEFT",0,-167-offset)
 local headerHeight=0
 for key,label in pairs(self.applicantHeaders) do
  if label:IsShown() then headerHeight=math.max(headerHeight,label:GetHeight()) end
 end
 self.applicantTable:SetHeight(math.max(24,headerHeight))
 for _,button in ipairs(self.applicantTable.buttons) do button:SetHeight(self.applicantTable:GetHeight()) end
 for _,handle in ipairs(self.applicantTable.handles) do handle:SetHeight(self.applicantTable:GetHeight()) end
 local batchTop=math.max(T.createBatchTop,167+headerHeight+3)
 self.batchScroll:ClearAllPoints();self.batchScroll:SetPoint("TOPLEFT",0,-batchTop-offset)
 self.batchSlider:ClearAllPoints();self.batchSlider:SetPoint("TOPRIGHT",0,-batchTop-offset)
 local height=math.max(1,BATCH_MAX_HEIGHT-offset-(batchTop-T.createBatchTop))
 self.batchScroll:SetHeight(height);self.batchSlider:SetHeight(height)
 self.syncBatchScroll=true;self.batchSlider:SetMinMaxValues(0,math.max(0,self.batchBody:GetHeight()-height));self.syncBatchScroll=nil
 self.batchSlider:SetShown(self.batchBody:GetHeight()>height)
 self.boundAppIDs=nil;self:SetBatchOffset(self.batchScroll:GetVerticalScroll(),false)
end
function P:SetManageError(message)
 local wasShown=self.manageNotice:IsShown()
 self.manageNotice:SetMessage(message)
 if not wasShown and not self.manageNotice:IsShown() then return end
 self:LayoutApplicantViewport()
end
function P:ShowError(message)
 if self.formFrame:IsShown() then self:SetFormError(message) else self:SetManageError(message) end
end
function P:BuildBatch(parent)
 local f=CreateFrame("Frame",nil,parent);f:SetWidth(BATCH_WIDTH);f.bg=C.Panel(f,"rowAlternate","createFBgRadius")
 UI.drag:AddHandle(f)
 f.comment=C.Text(f,"",12,"muted",columns.comment.width);f.comment:SetPoint("TOPLEFT",columns.comment.x,-T.createMemberTop);f.comment:SetJustifyV("MIDDLE");f.comment:SetWordWrap(true);C.SetLineHeight(f.comment,18)
 f.status=C.Text(f,"",14,"muted",columns.actions.width);f.status:SetPoint("LEFT",columns.actions.x,0);f.status:SetJustifyH("CENTER");C.SetLineHeight(f.status,20)
 f.invite=C.IconButton(f,nil,T.createFInviteWidth,function(btn) P:ApplicantAction(btn,"Invite") end,{iconSize=24,variant="applicantInvite"});C.Box(f.invite,{width="createFInviteWidth",height="createFInviteHeight"});f.invite:SetPoint("LEFT",columns.actions.x,0)
 f.decline=C.IconButton(f,nil,T.createFDeclineWidth,function(btn) P:ApplicantAction(btn,"Decline") end,{iconSize=24,variant="applicantDecline"});C.Box(f.decline,{width="createFDeclineWidth",height="createFDeclineHeight"});f.decline:SetPoint("LEFT",columns.actions.x+44,0)
 f.invite.glyph=f.invite.icon;UI:SetMediaTexture(f.invite.glyph,"invite.tga")
 f.decline.glyph=f.decline.icon;UI:SetMediaTexture(f.decline.glyph,"decline.tga")
 f:EnableMouse(true);f.cardStyle=C.Style(f,{recipe="selectableSurface",immediate=true,slots={root=f,surface=f.bg}});f.cardStyle:Bind(f,{hover=true})
 for _,action in ipairs({f.invite,f.decline}) do
  action.feedbackStyle=action.styleController
 end
 f.people={};UI:Element(f,"create.applicantBatch","create",f,"create.applicantBatch")
 return f
end
function P:EnsureBatchMembers(f,count)
 for i=#f.people+1,count do
  local row=CreateFrame("Button",nil,f);row:SetSize(columns.actions.x,T.createMemberHeight);row:RegisterForClicks("LeftButtonUp","RightButtonUp")
  row.icon=C.Icon(row,T.createApplicantIconSize);C.Box(row.icon,{width="createApplicantIconSize",height="createApplicantIconSize"});row.icon:SetPoint("LEFT",columns.name.x,0)
  row.title=C.Text(row,"",14,"text",nil);row.title:SetPoint("LEFT",T.createApplicantTitleX,0);C.SetLineHeight(row.title,19);row.title:SetWordWrap(true)
  row.factionButton=C.Button(row,"",T.createRowFactionButtonWidth,function(action,button)
   if not row.member or not action.targetKey or not P.batchScroll:IsMouseOver() then return end
   if button=="RightButton" then P:OpenApplicantMenu(row);return end
   row.factionExpanded=not row.factionExpanded;LayoutApplicantFaction(row)
  end,{height=24,radius=6,textColor="muted"});row.factionButton:SetWidth(T.createRowFactionButtonWidth)
  row.factionButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
  row.faction=C.Icon(row.factionButton,T.createRowFactionWidth);C.Box(row.faction,{width="createRowFactionWidth",height="createRowFactionHeight"});row.faction:SetPoint("CENTER")
  row.race=C.Text(row.factionButton,"",14,"muted",columns.faction.width);row.race:SetPoint("CENTER");row.race:SetJustifyH("CENTER");C.SetLineHeight(row.race,20,true);row.race:SetWordWrap(false)
  LayoutApplicantFaction(row)
  row.marks=UI.Members:CreateMarks(row,true)
  row.role=C.Icon(row,T.createRoleIconSize)
  row.roles={row.role}
  for slot=2,3 do row.roles[slot]=C.Icon(row,T.createIconWidth) end
  row.ilvl=C.Text(row,"",14,"muted",columns.ilvl.width);row.ilvl:SetPoint("LEFT",columns.ilvl.x,0);row.ilvl:SetJustifyH(columns.ilvl.align);C.SetLineHeight(row.ilvl,20,true)
  row.score=C.Text(row,"",14,"muted",columns.rating.width);row.score:SetPoint("LEFT",columns.rating.x,0);row.score:SetJustifyH(columns.rating.align);C.SetLineHeight(row.score,20,true)
  row.mapScore=C.Text(row,"",14,"muted",columns.mapScore.width);row.mapScore:SetPoint("LEFT",columns.mapScore.x,0);row.mapScore:SetJustifyH(columns.mapScore.align);C.SetLineHeight(row.mapScore,20,true)
  row.mapScoreButton=CreateFrame("Button",nil,row);row.mapScoreButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
  row.mapScoreButton:SetScript("OnMouseDown",CaptureApplicantPress)
  row.mapScoreButton:SetScript("OnClick",function(button,key)
   local valid,pressed=ConsumeApplicantPress(button,key)
   if not valid or UI.hiding or not row.member or not P.showApplicantMapScore or not P.batchScroll:IsMouseOver() or row._hitVisible==false then return end
   if key=="RightButton" then if UI.Tooltip:IsOwned(button) then UI.Tooltip:Hide() end;P:OpenApplicantMenu(row);return end
   if key~="LeftButton" or not pressed then return end
   row.mapScoreTime=not row.mapScoreTime
   if row.mapScoreKey then
    if row.mapScoreTime then P.applicantTimeModes=P.applicantTimeModes or {};P.applicantTimeModes[row.mapScoreKey]=true
    elseif P.applicantTimeModes then P.applicantTimeModes[row.mapScoreKey]=nil;if not next(P.applicantTimeModes) then P.applicantTimeModes=nil end end
   end
   if UI.Tooltip:IsOwned(button) then UI.Tooltip:Hide() end
   DrawApplicantMapScore(row)
  end)
  row.mapScoreButton:SetScript("OnLeave",function(button) if button.pressedKey then button.pressCancelled=true end end)
  row.mapScoreButton:SetScript("OnHide",function(button) SetApplicantTarget(button,nil) end)
  UI.Tooltip:BindText(row.mapScoreButton,function() return ApplicantTimeTooltip(row) end)
  row:SetScript("OnMouseDown",CaptureApplicantPress)
  row:SetScript("OnLeave",function(r) if r.pressedKey then r.pressCancelled=true end;UI.Tooltip:LeaveOwner(r) end)
  row:SetScript("OnClick",function(r,button)
   local valid=ConsumeApplicantPress(r,button)
   if valid and button=="RightButton" and not UI.hiding and r.member and r._hitVisible~=false and P.batchScroll:IsMouseOver() then P:OpenApplicantMenu(r) end
  end)
  row:SetScript("OnHide",function(r) UI:CloseMenuFor(r);UI.Members:ClearMarks(r.marks);SetApplicantTarget(r,nil);SetApplicantTarget(r.factionButton,nil);r.factionExpanded=nil;LayoutApplicantFaction(r);ClearApplicantTime(r) end)
  -- Bind after the product scripts: SetScript replaces earlier style hooks.
  f.cardStyle:Bind(row,{hover=true})
  f.cardStyle:Bind(row.mapScoreButton,{hover=true})
  MemberTooltipArea(row,self.batchScroll)
  UI:Element(row,"create.applicantMember","create",row,"create.applicantMember");f.people[i]=row
 end
end
function P:OpenApplicantMenu(row)
 local member=row.member
 local fullName=member.nameKey or member.name
 local nameKey,class,specID=member.nameKey,member.class,member.specID
 UI:OpenMenu(row,{
  {value="whisper",label=S("密聊","Whisper"),disabled=UI.preview~=nil or not fullName},
  {value="copy",label=S("复制名称","Copy name"),disabled=not fullName},
  {value="block",label=S("荔枝笔记：拉黑玩家","Player Notes: Block player"),disabled=UI.preview~=nil or not nameKey},
 },function(action)
  if action=="whisper" and fullName and not UI.preview then ChatFrame_SendTell(fullName)
  elseif action=="copy" then UI:CopyText(S("玩家名称","Player name"),fullName,nil,nil,S("完整名称","Full name"))
  elseif action=="block" and not UI.preview then local _,name,realm=A:PlayerKey(nameKey);A:Open("notes",{add={name=name,realm=realm,type="caution",class=class,specID=specID}}) end
 end,{cursor=true})
end
function P:BuildPicker(parent)
 local popup=CreateFrame("Frame",nil,parent);C.Box(popup,{width="createPopupWidth",height="createPopupHeight"});C.SetPoint(popup,"TOPLEFT",self.pickerTrigger,"BOTTOMLEFT",0,"createPopupTopleftY");popup:SetFrameLevel(parent:GetFrameLevel()+30);C.Panel(popup,"surface","createPanelRadius3");popup:EnableMouse(true);popup:Hide();self.picker=popup
 self.pickerSearch=C.Edit(popup,T.createPickerSearchWidth,T.createPickerSearchHeight);C.Box(self.pickerSearch,{width="createPickerSearchWidth",height="createPickerSearchHeight"});C.SetPoint(self.pickerSearch,"TOPLEFT",self.pickerSearch:GetParent(),"TOPLEFT","createPickerSearchTopleftX","createPickerSearchTopleftY")
 self.pickerSearch.box:ClearAllPoints();C.SetPoint(self.pickerSearch.box,"TOPLEFT",self.pickerSearch.box:GetParent(),"TOPLEFT","createPickerSearchBoxTopleftX","createPickerSearchBoxTopleftY");C.SetPoint(self.pickerSearch.box,"BOTTOMRIGHT",self.pickerSearch.box:GetParent(),"BOTTOMRIGHT","createPickerSearchBoxBottomrightX","createPickerSearchBoxBottomrightY")
 self.pickerSearch.elementIcon=C.Glyph(self.pickerSearch,"search",T.createGlyphWidth2);self.pickerSearch.elementIcon:SetPoint("LEFT",12,0)
 self.pickerSearchHint=C.Text(self.pickerSearch,S("搜索全部活动","Search every activity"),14,"dim");C.SetLineHeight(self.pickerSearchHint,20,true);C.SetPoint(self.pickerSearchHint,"LEFT",self.pickerSearchHint:GetParent(),"LEFT","createPickerSearchHintLeftX",0)
 self.pickerClear=C.Button(self.pickerSearch,"",T.createPickerClearWidth,function() P.pickerSearch.box:SetText("");P.pickerSearch.box:SetFocus() end);self.pickerClear:SetWidth(T.createPickerClearWidth);self.pickerClear:SetHeight(T.createPickerClearHeight);C.SetPoint(self.pickerClear,"RIGHT",self.pickerClear:GetParent(),"RIGHT","createPickerClearRightX",0);self.pickerClear.elementIcon=C.Glyph(self.pickerClear,"close",T.createGlyphWidth3);self.pickerClear.elementIcon:SetPoint("CENTER");self.pickerClear:Hide()
 self.pickerSearch.box:HookScript("OnTextChanged",function(box) local filled=box:GetText()~="";P.pickerSearchHint:SetShown(not filled);P.pickerClear:SetShown(filled);box:ClearAllPoints();C.SetPoint(box,"TOPLEFT",box:GetParent(),"TOPLEFT","createBoxTopleftX","createBoxTopleftY");C.SetPoint(box,"BOTTOMRIGHT",box:GetParent(),"BOTTOMRIGHT",filled and -60 or -12,"createBoxBottomrightY");P:RefreshPickerRows() end)
 self.pickerCategories=C.List(popup,T.createPickerCategoriesWidth,T.createPickerCategoriesHeight,64,function(key) P.pickerCategory=key;P.pickerTier=nil;P:RefreshPickerRows() end);C.Box(self.pickerCategories,{width="createPickerCategoriesWidth",height="createPickerCategoriesHeight"});C.SetPoint(self.pickerCategories,"TOPLEFT",self.pickerCategories:GetParent(),"TOPLEFT","createPickerCategoriesTopleftX","createPickerCategoriesTopleftY")
 self.pickerCategories:SetGutter(0);self.pickerCategories.alternateRows=false
 for _,row in ipairs(self.pickerCategories.rows) do row:SetHeight(T.createRowHeight);row.selected:SetRadius(8);row.hover:SetRadius(8);row.alternate:SetRadius(8);row.symbol=C.Icon(row,T.createRowSymbolWidth);C.Box(row.symbol,{width="createRowSymbolWidth",height="createRowSymbolHeight"});C.SetPoint(row.symbol,"LEFT",row.symbol:GetParent(),"LEFT","createRowSymbolLeftX",0);C.SetFont(row.title,16);row.title:ClearAllPoints();C.SetPoint(row.title,"LEFT",row.title:GetParent(),"LEFT","createRowTitleLeftX",0);row.title:SetWidth(T.createRowTitleWidth);row.title:SetWordWrap(true);row.title:SetHeight(0);C.SetLineHeight(row.title,22);row.meta:Hide() end
 self.pickerCategories:SetStyle({selectionMotion=true,radius=8})
 self.pickerSurface=CreateFrame("Frame",nil,popup);C.Box(self.pickerSurface,{width="createPickerSurfaceWidth",height="createPickerSurfaceHeight"});C.SetPoint(self.pickerSurface,"TOPLEFT",self.pickerSurface:GetParent(),"TOPLEFT","createPickerSurfaceTopleftX","createPickerSurfaceTopleftY");C.Panel(self.pickerSurface,"surfaceLow","createPanelRadius4")
 self.tierChoice=C.Choice(self.pickerSurface,T.createTierChoiceWidth,function() return P:TierItems(P.pickerCategory) end,function(value) P.pickerTier=value or nil;P:RefreshPickerRows() end);self.tierChoice:SetWidth(T.createTierChoiceWidth);self.tierChoice:SetHeight(T.createTierChoiceHeight);C.SetPoint(self.tierChoice,"TOPLEFT",self.tierChoice:GetParent(),"TOPLEFT","createTierChoiceTopleftX","createTierChoiceTopleftY")
 self.pickerResults=C.List(self.pickerSurface,T.createPickerResultsWidth,T.createPickerResultsHeight,44,function(key) P:SelectPickerRow(key) end);C.Box(self.pickerResults,{width="createPickerResultsWidth",height="createPickerResultsHeight"});C.SetPoint(self.pickerResults,"TOPLEFT",self.pickerResults:GetParent(),"TOPLEFT","createPickerResultsTopleftX","createPickerResultsTopleftY")
 self.pickerResults.alternateRows=false
 for _,row in ipairs(self.pickerResults.rows) do row.selected:SetRadius(8);row.hover:SetRadius(8);row.alternate:SetRadius(8);row.icon=C.Icon(row,T.createRowIconWidth2);C.Box(row.icon,{width="createRowIconWidth2",height="createRowIconHeight2"});C.SetPoint(row.icon,"LEFT",row.icon:GetParent(),"LEFT","createRowIconLeftX",0);row.title:ClearAllPoints();C.SetPoint(row.title,"TOPLEFT",row.title:GetParent(),"TOPLEFT","createRowTitleTopleftX2","createRowTitleTopleftY2");row.title:SetWidth(T.createRowTitleWidth2);C.SetFont(row.title,16);C.SetLineHeight(row.title,22,true);row.meta:ClearAllPoints();C.SetPoint(row.meta,"TOPLEFT",row.meta:GetParent(),"TOPLEFT","createRowMetaTopleftX2","createRowMetaTopleftY2");row.meta:SetWidth(T.createRowMetaWidth) end
 self.pickerEmpty=C.Text(popup,S("没有匹配的活动","No matching activities"),14,"dim",T.createPickerEmptyWidth);self.pickerEmpty:SetWidth(T.createPickerEmptyWidth);C.SetPoint(self.pickerEmpty,"TOPLEFT",self.pickerEmpty:GetParent(),"TOPLEFT","createPickerEmptyTopleftX","createPickerEmptyTopleftY")
 popup:SetScript("OnEvent",function() if not popup:IsMouseOver() and not P.pickerTrigger:IsMouseOver() and not UI.context:IsMenuHovered(P.tierChoice) then P:ClosePicker() end end)
self:RegisterBuildElements()
 end
function P:TogglePicker()
 if not self.picker then self:BuildPicker(self.frame) end
 if self.picker:IsShown() then self:ClosePicker();return end
 self.pickerTrigger:SetExpanded(true)
 self.pickerCategory=state.category;self.pickerTier=state.tier;self.picker:Show();self.picker:RegisterEvent("GLOBAL_MOUSE_DOWN");self:RefreshPickerRows();self.pickerSearch.box:SetFocus()
 UI.Motion:Reveal(self.picker,"TOPLEFT",self.pickerTrigger,"BOTTOMLEFT",0,-T.createPickerMotionOffset,0,T.createPickerMotionOffset,T.createPickerMotionDuration)
end
function P:ClosePicker()
 if not self.picker then return end
 self.pickerTrigger:SetExpanded(false)
 UI.Motion:FinishPlacement(self.picker);self.picker:Hide();self.picker:UnregisterEvent("GLOBAL_MOUSE_DOWN");self.pickerSearch.box:ClearFocus();self.pickerSearch.box:SetText("");self.pickerEntries=nil;self.pickerResults:Clear();self.pickerCategories:Clear()
end
function P:RefreshPickerRows()
 if not self.picker:IsShown() then return end
 local catalog=UI:GetGroup().Catalog;local query=self.pickerSearch.box:GetText():match("^%s*(.-)%s*$"):lower();local searching=query~=""
 local cats,catMap={},{};for _,cat in ipairs(catalog:GetCategories()) do cats[#cats+1]=cat.key;catMap[cat.key]=cat end
 local tierItems,tierScopes=self:TierItems(self.pickerCategory)
 local selectedCategory=catMap[self.pickerCategory]
 local showTier=not searching and selectedCategory and not selectedCategory.season and tierScopes>1 and #tierItems>1
 if not showTier and not searching then self.pickerTier=nil end
 self.pickerCategories.selectedKey=self.pickerCategory;self.pickerCategories:SetShown(not searching);self.pickerCategories:SetItems(cats,function(row,key) UI:SetText(row.title,catMap[key].name);row.symbol:SetTexture(UI:CategoryIcon(catMap[key].icon));row.symbol:SetTexCoord(0,1,0,1);UI:SetText(row.meta,"") end)
 local tierNames={};for _,tier in ipairs(catalog:GetTiers()) do tierNames[tier.id]=tier.name end
 local entries,keys={},{}
 for _,cat in ipairs(catalog:GetCategories()) do
  if searching or cat.key==self.pickerCategory then
   for _,group in ipairs(catalog:GetGroups(cat.key)) do
    local context=cat.name..(group.tier and " · "..(tierNames[group.tier] or "") or "")
    if (searching and (group.name.." "..context):lower():find(query,1,true)) or (not searching and (not self.pickerTier or group.tier==self.pickerTier)) then
     local key=cat.key..":"..group.key
     entries[key]={category=cat.key,group=group,context=context};keys[#keys+1]=key
    end
   end
  end
 end
 self.pickerEntries=entries;self.pickerResults:SetWidth(searching and 600 or 412);self.pickerResults:SetGutter(C.listRightInset);self.pickerSurface:SetWidth(searching and 616 or 428);self.pickerSurface:ClearAllPoints();C.SetPoint(self.pickerSurface,"TOPLEFT",self.pickerSurface:GetParent(),"TOPLEFT",searching and 12 or 200,"createPickerSurfaceTopleftY")
 self.pickerResults:ClearAllPoints();C.SetPoint(self.pickerResults,"TOPLEFT",self.pickerResults:GetParent(),"TOPLEFT","createPickerResultsTopleftX",searching and -8 or -64);self.pickerResults:SetViewport(searching and 368 or 312)
 for _,row in ipairs(self.pickerResults.rows) do row:SetWidth((searching and 600 or 412)-C.listRightInset);row.title:SetWidth(searching and 534 or 334);row.meta:SetWidth(searching and 534 or 334) end
 self.pickerResults.selectedKey=nil
 for key,entry in pairs(entries) do if entry.category==state.category and entry.group.key==state.group then self.pickerResults.selectedKey=key;break end end
 self.pickerResults:SetItems(keys,function(row,key)
  local entry=entries[key];UI:SetActivityIcon(row.icon,entry.group.activity);UI:SetText(row.title,ActivityLabel(entry.group.name));UI:SetText(row.meta,entry.context)
  row.title:ClearAllPoints();C.SetPoint(row.title,"LEFT",row.title:GetParent(),"LEFT","createRowTitleLeftX2",0);row.title:SetWidth(searching and 382 or 334);C.SetLineHeight(row.title,22,true)
  row.meta:ClearAllPoints();C.SetPoint(row.meta,"RIGHT",row.meta:GetParent(),"RIGHT","createRowMetaRightX",0);row.meta:SetWidth(T.createRowMetaWidth2);C.SetLineHeight(row.meta,20,true);row.meta:SetJustifyH("RIGHT");row.meta:SetShown(searching)
 end)
 if not showTier then self.pickerResults:ClearAllPoints();C.SetPoint(self.pickerResults,"TOPLEFT",self.pickerResults:GetParent(),"TOPLEFT","createPickerResultsTopleftX","createPickerResultsTopleftY2");self.pickerResults:SetViewport(368) end
 self.pickerEmpty:SetShown(#keys==0);self.tierChoice:SetShown(showTier)
 local tierName=self.pickerTier and tierNames[self.pickerTier] or L.all;self.tierChoice:SetValue(self.pickerTier,tierName)
end
function P:SelectPickerRow(key)
 local entry=self.pickerEntries and self.pickerEntries[key];if not entry then return end
 state.category=entry.category;state.group=entry.group.key;state.tier=entry.group.tier;form.activityID=nil
 self:ClosePicker();self:RefreshPicker()
end
function P:TierItems(categoryKey)
 local used,scopes={},0
 for _,g in ipairs(UI:GetGroup().Catalog:GetGroups(categoryKey or state.category)) do local key=g.tier or false;if not used[key] then used[key]=true;scopes=scopes+1 end end
 local items={{value=false,label=L.all}};for _,tier in ipairs(UI:GetGroup().Catalog:GetTiers()) do if used[tier.id] then items[#items+1]={value=tier.id,label=tier.name} end end;return items,scopes
end
function P:ActivityItems()
 local items={};for _,g in ipairs(UI:GetGroup().Catalog:GetGroups(state.category)) do if not state.tier or g.tier==state.tier then items[#items+1]={value=g.key,label=ActivityLabel(g.name)} end end;return items
end
function P:DifficultyItems()
 local catalog=UI:GetGroup().Catalog;local group=catalog:GetGroup(state.category,state.group);local items={}
 if group and catalog:GetCategory(state.category).id~=121 then for _,act in ipairs(group.variants) do
  local label=act.difficultyID and act.difficultyID>0 and ActivityLabel(GetDifficultyInfo(act.difficultyID))
  if label then items[#items+1]={value=act.id,label=label} end
 end end;return items
end
function P:SelectDifficulty(activityID)
 -- Only a current difficulty control commits memory; prefill and fallback do not.
 for _,item in ipairs(self:DifficultyItems()) do if item.value==activityID then
  local group=UI:GetGroup();local activity=group.Catalog:GetActivity(activityID)
  form.activityID=activityID
  if group.Catalog:GetCategory(state.category).id==3 then group.prefs.creationRaidDifficultyID=activity.difficultyID end
  self:RefreshPicker();return
 end end
end
function P:LayoutActivityChoice(variants)
 local label=L.chooseActivity;for _,entry in ipairs(variants) do if entry.value==form.activityID then label=entry.label end end;self.difficultyChoice:SetValue(form.activityID,label)
 UI:SetText(self.difficultyFixed,label)
 local segmentWidth=6+math.max(0,#variants-1)*4
 for i,b in ipairs(self.difficultyButtons) do local entry=variants[i];if entry then UI:SetText(b.label,entry.label);b._desiredWidth=math.max(48,FitText(b.label)+20);segmentWidth=segmentWidth+b._desiredWidth end end
 local activityWidth=FORM-52
 local segments=#variants>1 and #variants<=4 and segmentWidth<=activityWidth-252
 local sideWidth=#variants==0 and 0 or #variants==1 and FitText(self.difficultyFixed)+28 or segments and segmentWidth or 200
 local triggerWidth=activityWidth-sideWidth-(sideWidth>0 and 12 or 0)
 self.pickerTrigger:SetWidth(triggerWidth);self.pickerName:SetWidth(triggerWidth-76);self.pickerContext:SetWidth(triggerWidth-76)
 self.difficultyGroup:SetWidth(sideWidth);self.difficultyGroup:ClearAllPoints();C.SetPoint(self.difficultyGroup,"LEFT",self.pickerTrigger,"RIGHT","createDifficultyGroupLeftX",0)
 self.difficultyChoice:SetWidth(sideWidth);self.difficultyChoice:ClearAllPoints();C.SetPoint(self.difficultyChoice,"LEFT",self.pickerTrigger,"RIGHT","createDifficultyChoiceLeftX",0)
 self.difficultyFixedSurface:ClearAllPoints();C.SetPoint(self.difficultyFixedSurface,"LEFT",self.pickerTrigger,"RIGHT","createDifficultyFixedSurfaceLeftX",0);self.difficultyFixedSurface:SetWidth(sideWidth);self.difficultyFixedSurface:SetShown(#variants==1)
 self.difficultyChoice:SetShown(#variants>1 and not segments);self.difficultyGroup:SetShown(segments);self.difficultyFixed:SetShown(#variants==1);UI:SetText(self.difficultyFixed,label)
 local x=3
 for i,b in ipairs(self.difficultyButtons) do
  local entry=variants[i];b:SetShown(entry~=nil and segments)
  if entry then
   b.value=entry.value;b:SetWidth(b._desiredWidth);b:ClearAllPoints();b:SetPoint("LEFT",x,0);b:SetActive(entry.value==form.activityID)
   if segments and b.active then self.difficultySelection:Select(x,-3,b:GetWidth(),b:GetHeight(),self.frame:IsVisible()) end
   x=x+b._desiredWidth+4
  end
 end
 if not segments then self.difficultySelection:Clear() end
end
function P:RefreshPicker()
 local cat=UI:GetGroup().Catalog:GetCategory(state.category)
 local groups=self:ActivityItems();if not state.group and groups[1] then state.group=groups[1].value end
 local group=UI:GetGroup().Catalog:GetGroup(state.category,state.group)
 UI:SetText(self.pickerName,ActivityLabel(group and group.name) or L.chooseActivity)
 local tierName;for _,tier in ipairs(UI:GetGroup().Catalog:GetTiers()) do if group and group.tier==tier.id then tierName=tier.name end end
 UI:SetText(self.pickerContext,cat and cat.season and S("本赛季","Current season") or tierName or cat and cat.name or "");UI:SetActivityIcon(self.pickerIcon,group and group.activity)
 -- Native activity selection remains independent of the optional difficulty UI.
 local activities=group and group.variants or {};local valid=false
 for _,activity in ipairs(activities) do if activity.id==form.activityID then valid=true;break end end
 if not valid then
  form.activityID=activities[1] and activities[1].id
  for _,activity in ipairs(activities) do
   if activity.isMythicPlusActivity then form.activityID=activity.id;break end
  end
  if cat and cat.id==3 then
   local difficultyID=UI:GetGroup().prefs.creationRaidDifficultyID
   for _,activity in ipairs(activities) do
    if type(difficultyID)=="number" and difficultyID>0 and activity.difficultyID==difficultyID then form.activityID=activity.id;break end
   end
  end
 end
 self.pickerVariants=self:DifficultyItems();self:LayoutActivityChoice(self.pickerVariants)
 local act=form.activityID and UI:GetGroup().Catalog:GetActivity(form.activityID)
 local categoryInfo=cat and C_LFGList.GetLfgCategoryInfo(cat.id)
 self.hasPlaystyle=categoryInfo and categoryInfo.showPlaystyleDropdown==true
 self.playstyle:SetShown(self.hasPlaystyle);self.styleLabel:SetShown(self.hasPlaystyle)
 local crossAllowed=categoryInfo and categoryInfo.allowCrossFaction and act and act.allowCrossFaction
 self.crossFaction:SetAvailable(crossAllowed==true);self.crossFaction:SetValue(crossAllowed==true and form.crossFaction~=false)
 self.scoreKind=A.GroupPresentation.Activity(act).requirementRatingKind
 self.score:SetShown(self.scoreKind~=nil);self.scoreLabel:SetShown(self.scoreKind~=nil)
 UI:SetText(self.ilvlLabel,A.GroupPresentation.Activity(act).kind=="pvp" and S("最低 PvP 装等","Minimum PvP item level") or L.minItemLevel)
 UI:SetText(self.scoreLabel,self.scoreKind=="pvp" and S("最低 PvP 评分","Minimum PvP rating") or L.minRating)
 self:LayoutRequirements()
 if not form.generalPlaystyle then local options=self:PlaystyleItems();form.generalPlaystyle=options[1] and options[1].value end
 self.playstyle:SetValue(form.generalPlaystyle,form.generalPlaystyle and PlaystyleLabel(form.generalPlaystyle) or L.choosePlaystyle)
 UI.Native:SelectActivity(form.activityID);self:ValidateForm();self:RefreshRosterPresentation()
end
function P:PlaystyleItems()
 local e=Enum.LFGEntryGeneralPlaystyle;local items={}
 for _,value in ipairs({e.Learning,e.FunRelaxed,e.FunSerious,e.Expert}) do items[#items+1]={value=value,label=PlaystyleLabel(value)} end;return items
end
function P:FormData()
 local data={activityID=form.activityID,requiredItemLevel=tonumber(self.ilvl.box:GetText()) or 0,requiredDungeonScore=self.scoreKind=="dungeon" and tonumber(self.score.box:GetText()) or 0,requiredPvpRating=self.scoreKind=="pvp" and tonumber(self.score.box:GetText()) or 0,isAutoAccept=self.autoAccept.value,isPrivateGroup=self.private.value,isCrossFactionListing=self.crossFaction.value,generalPlaystyle=self.hasPlaystyle and form.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None}
 if form.presetActivityID==form.activityID then data.playstyle,data.newPlayerFriendly,data.questID=form.playstyle,form.newPlayerFriendly,form.questID end
 return data
end
function P:CorrectItemLevel()
 local value=tonumber(self.ilvl.box:GetText())
 if not value or value<=0 or not form.activityID then return end
 local limit,pvp=UI.Native:GetCreationItemLevelLimit(form.activityID)
 if limit and value>limit then
  self.ilvl.box:SetText(tostring(limit))
  self:ShowCorrectionNotice((pvp and S("已将 PvP 装等要求调整为 %d（你的最高 PvP 装等）。","PvP item level requirement adjusted to %d (your highest PvP item level).")
   or S("已将装等要求调整为 %d（你的最高装等）。","Item level requirement adjusted to %d (your highest item level).")):format(limit))
 end
end
function P:OnCreationInputLost()
 self.publish:SetAvailable(false)
end
function P:ValidateForm(preserveSubmissionError)
 if self.preparing or UI.hiding or not self.formFrame:IsShown() then return end
 self.autoInviteHint:SetShown(self.autoAccept.value==true)
 if not preserveSubmissionError then state.submissionError=nil end
 self:RefreshFavoriteState()
 local ok,err=UI:GetGroup():CanManageListing()
 self.publish:SetAvailable(ok==true and not self.submitting)
 if ok and self.validationSubmitted then ok,err=UI.Native:ValidateCreation(self:FormData()) end
 self:SetFormError(err or state.submissionError or "")
end
function P:EnsureCreationInput()
 local allowed,reason=UI:GetGroup():CanManageListing()
 if not allowed then self.publish:SetAvailable(false);self:SetFormError(reason);return false end
 local native=UI.Native
 local reacquire=not UI.preview and (native.owner~=self or not native.titleInput:IsOwned() or not native.descriptionInput:IsOwned())
 local ok,err=UI.Native:AcquireCreation(self,self.titleShell,self.descriptionShell)
 if not ok then self.publish:SetAvailable(false);self:SetFormError(err);return false end
 if reacquire then UI.Native:SelectActivity(form.activityID) end
 self:ValidateForm()
 return true
end
function P:PrepareForm(editing)
 self.validationSubmitted=nil;state.submissionError=nil
 local allowed,reason=UI:GetGroup():CanManageListing()
 if not allowed then UI.Native:ReleaseCreation();self.publish:SetAvailable(false);self:SetFormError(reason);return false end
 self.preparing=true
 local ok,err=UI.Native:AcquireCreation(self,self.titleShell,self.descriptionShell)
 if not ok then self.preparing=nil;self.publish:SetAvailable(false);self:SetFormError(err);return false end
 if editing then
  form.presetActivityID=nil
  local l=UI:GetGroup():GetListing();form.activityID=l.activityID;local act=UI:GetGroup().Catalog:GetActivity(form.activityID)
  state.category=UI:GetGroup().Catalog:GetContextForActivity(form.activityID,state.category) or tostring(act.categoryID);state.group=UI:GetGroup().Catalog:GetGroupKey(state.category,act);state.tier=UI:GetGroup().Catalog:GetActivityTier(act)
  local itemLevel=l.requiredItemLevel or 0;local score=act.isRatedPvpActivity and l.requiredPvpRating or l.requiredDungeonScore or 0
  form.generalPlaystyle=l.generalPlaystyle;self.ilvl.box:SetText(itemLevel>0 and tostring(itemLevel) or "");self.score.box:SetText(score>0 and tostring(score) or "")
  form.crossFaction=l.isCrossFactionListing==true;self.private:SetValue(l.privateGroup);self.crossFaction:SetValue(form.crossFaction);self.autoAccept:SetValue(l.autoInvite==true or l.autoInvite==nil and l.autoAccept==true)
  if UI.preview then UI.Native:SetPreviewCreationText(l.name,l.comment) else C_LFGList.CopyActiveEntryInfoToCreationFields() end
 elseif not self.started then if UI.preview then UI.Native:SetPreviewCreationText("","") else C_LFGList.ClearCreationTextFields() end;self.started=true end
 self:RefreshPicker();self.preparing=nil;self:ValidateForm();return true
end
local function RefreshMode(self)
 local group=UI:GetGroup();local listing=group:GetListing();local canManage=group:CanManageListing()
 if state.hadListing and not listing and not self.submitting then form.crossFaction=true;self:RefreshPicker() end
 state.hadListing=listing~=nil
 if not listing or not canManage then state.editing=false end
 self.editListing:SetShown(listing~=nil and canManage);self.cancelListing:SetShown(listing~=nil and canManage)
 local editing=state.editing or not listing;self.formFrame:SetShown(editing);self.manage:SetShown(not editing);self.formCancel:SetShown(state.editing)
 group:SetApplicantView(self,not editing and self.unsub~=nil)
 if editing then
  UI:SetText(self.heading,state.editing and L.update or L.create);UI:SetText(self.publish.label,state.editing and L.update or L.publish)
  if not canManage then UI.Native:ReleaseCreation();self:ValidateForm(true)
  elseif UI.Native.owner~=self then self:PrepareForm(state.editing)
  else self:ValidateForm(true) end
 else
  UI.Native:ReleaseCreation();UI:SetText(self.sName,listing.name or L.currentListing)
  local act=UI:GetGroup().Catalog:GetActivity(listing.activityID);UI:SetActivityIcon(self.sIcon,act)
  local category=UI:GetGroup().Catalog:GetContextForActivity(listing.activityID,state.category)
  local group=category and UI:GetGroup().Catalog:GetGroup(category,UI:GetGroup().Catalog:GetGroupKey(category,act))
  local difficulty=act.difficultyID and act.difficultyID>0 and ActivityLabel(GetDifficultyInfo(act.difficultyID))
  UI:SetText(self.sMeta,(ActivityLabel(group and group.name or listing.activityName) or "")..(difficulty and " · "..difficulty or "").." · "..L.requiredItemLevel.." "..(listing.requiredItemLevel or 0))
 end
end
function P:RefreshMode()
 RefreshMode(self)
 RefreshRosterPresentation(self)
 RefreshFavorites(self)
 FinishRosterPresentation(self)
 UI:RefreshWindowSize()
UI:ApplyElementScope("create")
 end
function P:Submit()
 if self.submitting then return end
 local allowed,reason=UI:GetGroup():CanManageListing()
 if not allowed then self:ShowError(reason);return end
 self.validationSubmitted=true
 if not self:EnsureCreationInput() then return end
 self:CorrectItemLevel()
 local data=self:FormData();local valid,err=UI.Native:ValidateCreation(data);if not valid then self:SetFormError(err);return end
 self.submitting=true;self.publish:SetAvailable(false)
 local ok,reason;if state.editing then ok,reason=UI:GetGroup():Update(data) else ok,reason=UI:GetGroup():Publish(data) end
 local listingChanged=self.submissionListingChanged;self.submissionListingChanged=nil
 -- A failed cross-faction recreation may remove the listing. Consume that
 -- notification while the submission still owns the draft's current values.
 if not ok and listingChanged then self:RefreshMode();self:RefreshApplicants() end
 self.submitting=nil
 if ok then
  self.validationSubmitted=nil;state.editing=false;self:RefreshMode()
  if listingChanged then self:RefreshApplicants() end
 else self:ValidateForm();state.submissionError=reason or L.failed;self:SetFormError(state.submissionError) end
end
local function ApplicantMarkInputs(member)
 local flags=0
 if A:GetSetting("relations") then flags=(member.isBNetFriend and 1 or 0)+((member.isCharFriend or member.isFriend) and 2 or 0)+(member.isGuildMate and 4 or 0) end
 if A:GetSetting("noteMarks")~=false then
  local key=UI.Members:Identity(member);local note=UI:GetNote(key)
  if note then flags=flags+(note.type=="positive" and 8 or note.type=="neutral" and 16 or note.type=="caution" and 32 or 0) end
 end
 return flags
end
local function ApplicantLayoutMatches(layout,members)
 if not layout or #layout.names~=#members then return false end
 for index,member in ipairs(members) do
  local key=UI.Members:Identity(member);key=key or UI.Members:ID(member)
  if layout.names[index]~=ApplicantName(member) or layout.markInputs[index]~=ApplicantMarkInputs(member) or layout.memberKeys[index]~=key then return false end
 end
 return true
end
function P:LayoutBatches(ids)
 ids=ids or self.appIDs
 if not ids then return end
 -- Header layout may synchronously repaint after a missing applicant triggers
 -- RefreshApplicants. Keep the published IDs and geometry complete until then.
 local previousTops,previous=self.batchTops,self.batchLayouts
 local batchTops,batchLayouts
 if not previous or not previousTops or #previousTops~=#ids+1 then batchTops,batchLayouts={},{} end
 local measure=self.applicantMeasure
 local path,size,flags,spacing,line,scale
 if measure then path,size,flags=measure.text:GetFont();spacing=measure.text:GetSpacing();line=measure.text:GetLineHeight();scale=measure:GetEffectiveScale() end
 local width=columns.name.x+columns.name.width-T.createApplicantTitleX
 local top=0
 for index,id in ipairs(ids) do
  local app=UI:GetGroup():GetApplicant(id)
  if not app then self:RefreshApplicants();return end
  if not self.applicantMeasure then
   local holder=CreateFrame("Frame",nil,self.batchBody);holder:Hide()
   holder.text=C.Text(holder,"",14,"text");C.SetLineHeight(holder.text,19);holder.text:SetWordWrap(true)
   holder.marks=UI.Members:CreateMarks(holder)
   self.applicantMeasure=holder
  end
  if not measure then
   measure=self.applicantMeasure;path,size,flags=measure.text:GetFont();spacing=measure.text:GetSpacing();line=measure.text:GetLineHeight();scale=measure:GetEffectiveScale()
  end
  local prior=previous and previous[id];local layout=prior
  if not ApplicantLayoutMatches(layout,app.members) or layout.width~=width or layout.path~=path or layout.size~=size or layout.flags~=flags or layout.spacing~=spacing or layout.line~=line or layout.scale~=scale then
   layout={tops={},heights={},names={},markInputs={},memberKeys={},width=width,path=path,size=size,flags=flags,spacing=spacing,line=line,scale=scale};local memberTop=0
   for i,member in ipairs(app.members) do
    local marks=UI.Members:BindMarks(measure.marks,member)
    measure.text:SetWidth(width-(marks>0 and marks+6 or 0))
    local name=ApplicantName(member);UI:SetText(measure.text,name)
    local height=math.max(T.createMemberHeight,math.ceil(measure.text:GetStringHeight()))
    layout.tops[i],layout.heights[i]=memberTop,height
    layout.names[i],layout.markInputs[i]=name,ApplicantMarkInputs(member)
    local key=UI.Members:Identity(member);layout.memberKeys[i]=key or UI.Members:ID(member)
    memberTop=memberTop+height+T.createMemberStride-T.createMemberHeight
   end
   layout.height=math.max(T.createMemberStride,memberTop)+T.createBatchPadding
  end
  layout.source=app
  if not batchTops and (layout~=prior or layout.index~=index or previousTops[index]~=top) then
   batchTops,batchLayouts={},{}
   for prefix=1,index-1 do
    batchTops[prefix]=previousTops[prefix];local key=ids[prefix];batchLayouts[key]=previous[key]
   end
  end
  if batchTops then batchTops[index]=top;batchLayouts[id]=layout end
  top=top+layout.height
 end
 if self.applicantMeasure then UI.Members:ClearMarks(self.applicantMeasure.marks);UI:SetText(self.applicantMeasure.text,"") end
 if batchTops then
  batchTops[#ids+1]=top
  for index,id in ipairs(ids) do batchLayouts[id].index=index end
 else batchTops,batchLayouts=previousTops,previous end
 self.appIDs,self.batchTops,self.batchLayouts=ids,batchTops,batchLayouts
 self.batchBody:SetHeight(math.max(1,top));self:LayoutApplicantViewport()
end
function P:RefreshApplicants()
 if UI.hiding then return end
 UI.Motion:Stop(self.batchScroll);self.batchScrollTarget=nil
 local group=UI:GetGroup()
 local listing=group:GetListing();local activity=listing and group.Catalog:GetActivity(listing.activityID)
 self.applicantContext=A.GroupPresentation.Member("applicant",activity);self.hideApplicantRating=not self.applicantContext.showRating
 self.showApplicantMapScore=self.applicantContext.showDungeonRecords
 if not self.showApplicantMapScore then self.applicantTimeModes=nil end
 local timeModes=self.applicantTimeModes
 if timeModes then for key in pairs(timeModes) do timeModes[key]=false end end
 local kind=self.hideApplicantRating and "none" or self.showApplicantMapScore and "dungeon" or "rating"
 if kind~=self.applicantTableKind then self.applicantTableKind=kind;self.applicantTable:SetColumns(ApplicantDefinitions(kind)) end
 if self.hideApplicantRating and state.sort=="score" or not self.showApplicantMapScore and state.sort=="mapScore" then state.sort="newest";state.descending=false end
 local column=sortColumns[state.sort]
 if self.applicantTable.state.sortKey~=column or self.applicantTable.state.descending~=(state.descending==true) then self.applicantTable:SetSort(column,state.descending) end
 local label=state.sort=="score" and L.rating or state.sort=="mapScore" and headerLabels.mapScore or state.sort=="ilvl" and L.itemLevel or L.newest
 self.sortChoice:SetValue(state.sort,label)
 local sortKey=state.sort=="score" and "rating" or state.sort=="mapScore" and "mapScore" or state.sort=="ilvl" and "itemLevel"
 local values=sortKey and {}
 local ids={};for _,id in ipairs(group:GetApplicants()) do
  local app=group:GetApplicant(id);local match=not state.roles
  if timeModes then
   for index,member in ipairs(app.members) do
    local key=ApplicantTimeKey(id,member,index)
    if key and timeModes[key]~=nil then timeModes[key]=true end
   end
  end
  if not match then
   for _,member in ipairs(app.members) do
    for _,role in ipairs(roleOrder) do if state.roles[role] and UI:MemberHasRole(member,role) then match=true;break end end
    if match then break end
   end
  end
  if match then ids[#ids+1]=id;if sortKey then values[id]=Minimum(app,sortKey) end end
 end
 if timeModes then
  for key,present in pairs(timeModes) do if not present then timeModes[key]=nil end end
  if not next(timeModes) then self.applicantTimeModes=nil end
 end
 table.sort(ids,function(a,b)
  if sortKey and values[a]~=values[b] then
   if values[a]==nil then return false elseif values[b]==nil then return true end
   if state.descending then return values[a]>values[b] else return values[a]<values[b] end
  end
  local x,y=group:GetApplicant(a),group:GetApplicant(b)
  return x.displayOrderID==y.displayOrderID and a>b or x.displayOrderID<y.displayOrderID
 end)
 self:LayoutBatches(ids)
 self.empty:SetShown(#ids==0);UI:SetText(self.appCount,L.applicantCount:format(#ids))
 for key,b in pairs(self.roleFilters) do b:SetActive(key=="ALL" and not state.roles or state.roles and state.roles[key]==true or false) end
 UI.Tooltip:RefreshApplicant()
end
function P:SetBatchOffset(value,animate)
 UI:CloseMenu()
 local target=math.max(0,math.min(value,math.max(0,self.batchBody:GetHeight()-self.batchScroll:GetHeight())))
 UI.Motion:Stop(self.batchScroll);self.batchScrollTarget=target
 local function Apply(offset)
  P.batchScroll:SetVerticalScroll(offset);P.syncBatchScroll=true;P.batchSlider:SetValue(offset);P.syncBatchScroll=nil;P:RenderBatches()
 end
 local from=self.batchScroll:GetVerticalScroll()
 if not animate or A:GetSetting("reduceMotion") or T.createScrollDuration==0 or target==from then Apply(target);self.batchScrollTarget=nil;return end
 local elapsed=0
 UI.Motion:Start(self.batchScroll,function(dt)
  elapsed=math.min(T.createScrollDuration,elapsed+dt);local p=elapsed/T.createScrollDuration;p=1-(1-p)^3;Apply(from+(target-from)*p)
  if elapsed==T.createScrollDuration then P.batchScrollTarget=nil;return true end
 end)
end
function P:RenderBatches()
 local offset=self.batchScroll:GetVerticalScroll();local bound=0
 local layout=self.applicantColumns or columns
 local first,last
 local count=self.appIDs and #self.appIDs or 0
 local low,high=1,count
 while low<=high do
  local index=math.floor((low+high)/2)
  if self.batchTops[index+1]>=offset then first=index;high=index-1 else low=index+1 end
 end
 if first then
  last=first;local bottom=offset+self.batchScroll:GetHeight()
  while last<count and self.batchTops[last+1]<bottom do last=last+1 end
 end
 if self.boundAppIDs==self.appIDs and self.firstBatch==first and self.lastBatch==last then
  -- Member records change in place before the merged business notification.
  -- Check the already-bound inputs without rereading or remeasuring the list.
  for index=first or 1,last or 0 do
   local memberLayout=self.batchLayouts[self.appIDs[index]]
   if not ApplicantLayoutMatches(memberLayout,memberLayout.source.members) then self:LayoutBatches();return end
  end
  return
 end
 self.boundAppIDs,self.firstBatch,self.lastBatch=self.appIDs,first,last
 local canManage=UI:GetGroup():CanManageApplicants()
 for index=first or 1,last or 0 do
   local id=self.appIDs[index];local app=UI:GetGroup():GetApplicant(id);local top=self.batchTops[index];local height=self.batchTops[index+1]-top
   -- Native removal precedes the queued applicant notification; another repaint can arrive first.
   if not app then self:RefreshApplicants();return end
   if not ApplicantLayoutMatches(self.batchLayouts[id],app.members) then self:LayoutBatches();return end
   bound=bound+1;local f=self.batchPool[bound];if not f then f=self:BuildBatch(self.batchBody);self.batchPool[bound]=f end
   if f.appID~=id then for _,row in ipairs(f.people) do HideMemberTooltip(row) end end
   f:ClearAllPoints();f:SetPoint("TOPLEFT",0,-top);f:SetHeight(height);f:Show();C.RekeyElement(f,id);f.appID=id;f.alternate=index%2==0;f.cardStyle:SetState("selected",f.alternate)
   local sharedY=-T.createMemberTop
   local memberLayout=self.batchLayouts[id]
   f.invite:SetPoint("LEFT",layout.actions.x,0);f.decline:SetPoint("LEFT",layout.actions.x+44,0);f.status:SetPoint("LEFT",layout.actions.x,0);f.status:SetWidth(layout.actions.width)
   f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",layout.comment.x,sharedY);f.comment:SetWidth(layout.comment.width);f.comment:SetHeight(height-T.createMemberTop*2);UI:SetText(f.comment,app.comment or "")
   f.invite.targetKey=id;f.decline.targetKey=id
    local actionable=canManage and app.status=="applied" and not app.pendingStatus and not app.acting
   f.invite:SetShown(actionable);f.decline:SetShown(actionable)
   UI:SetText(f.status,app.acting and L.busy or (L.states[app.pendingStatus or app.status] or ""));f.status:SetShown(not actionable)
   self:EnsureBatchMembers(f,#app.members)
   for i,row in ipairs(f.people) do
    UI:CloseMenuFor(row)
    local m=app.members[i];if row.member~=m then HideMemberTooltip(row) end;row:SetShown(m~=nil);row.member=m
    if m then
     local timeKey=ApplicantTimeKey(id,m,i);local identity=timeKey or tostring(id)..":unknown:"..i
     if row.mapScoreIdentity~=identity then ClearApplicantTime(row) end
     row.mapScoreIdentity,row.mapScoreKey=identity,timeKey
     SetApplicantTarget(row,identity);SetApplicantTarget(row.mapScoreButton,self.showApplicantMapScore and identity or nil)
     row.mapScoreTime=timeKey and self.applicantTimeModes and self.applicantTimeModes[timeKey] or nil
     C.RekeyElement(row,identity);row.memberContext=self.applicantContext;row:SetWidth(self.applicantTable.columns.actions.x);row:SetHeight(memberLayout.heights[i]);row:ClearAllPoints();row:SetPoint("TOPLEFT",0,sharedY-memberLayout.tops[i]);row.icon:SetPoint("LEFT",layout.name.x,0);row.title:SetPoint("LEFT",layout.name.x+44,0);UI:SetMemberIcon(row.icon,m);UI:SetText(row.title,ApplicantName(m));row.title:SetTextColor(UI:ClassColor(m.class))
     UpdateApplicantFaction(row,m,id,identity)
     local marksWidth=UI.Members:BindMarks(row.marks,m)
     local available=columns.name.x+columns.name.width-T.createApplicantTitleX-(marksWidth>0 and marksWidth+6 or 0)
     row.title:SetWidth(math.min(available,FitText(row.title)));row.title:SetHeight(0);row.title:SetWordWrap(true)
     row.marks:ClearAllPoints();C.SetPoint(row.marks,"LEFT",row.title,"RIGHT","createRowMarksLeftX",0)
     UpdateApplicantRoles(row,m,layout);UI:SetText(row.ilvl,m.itemLevel and math.floor(m.itemLevel) or "—")
     if row.applicantColumns~=layout then
      row.applicantColumns=layout
      for key,field in pairs({rating="score",mapScore="mapScore",ilvl="ilvl"}) do row[field]:ClearAllPoints();row[field]:SetPoint("LEFT",layout[key].x,0);row[field]:SetWidth(layout[key].width) end
      row.race:SetWidth(layout.faction.width);row.score:SetShown(not self.hideApplicantRating);row.mapScore:SetShown(self.showApplicantMapScore)
     end
     if self.hideApplicantRating then UI:SetText(row.score,"") else UI:SetScore(row.score,UI:MemberRating(m)) end
     if self.showApplicantMapScore then
      DrawApplicantMapScore(row)
     else ClearApplicantTime(row);UI:SetText(row.mapScore,"") end
     LayoutApplicantMapScore(row)
    end
   end
 end
 for i=bound+1,#self.batchPool do local f=self.batchPool[i];f:Hide();f.appID=nil;for _,row in ipairs(f.people) do HideMemberTooltip(row);UI.Members:ClearMarks(row.marks);SetApplicantTarget(row,nil);SetApplicantTarget(row.factionButton,nil);ClearApplicantTime(row);row.member=nil;C.RekeyElement(row,nil) end;C.RekeyElement(f,nil) end
UI:ApplyElementScope("create")
 end
function P:ApplicantAction(btn,method)
 if not btn.targetKey then return end;local ok,err=UI:GetGroup()[method](UI:GetGroup(),btn.targetKey);self:SetManageError(ok==false and (err or L.failed) or "")
end
local function RefreshRoster(self)
 self.roster=UI:GetGroup():GetRoster()
 UI:SetText(self.rosterCount,S("%d 人","%d members"):format(#self.roster));self.groupStrip:Update(self.roster,UI:MemberCounts(self.roster),30)
 local compositionX=0
 for _,item in ipairs(self.groupStrip.counts) do local width=FitText(item.text);item.icon:ClearAllPoints();item.icon:SetPoint("LEFT",compositionX,0);item.text:ClearAllPoints();C.SetPoint(item.text,"LEFT",item.icon,"RIGHT","createItemTextLeftX",0);compositionX=compositionX+18+4+width+20 end
 self.groupStrip:SetWidth(compositionX-20);self.groupSummary:SetWidth(self.groupStrip:GetWidth()+24)
 RefreshRosterPresentation(self)
end
function P:RefreshRoster()
 RefreshRoster(self)
 FinishRosterPresentation(self)
UI:ApplyElementScope("create")
 end
function P:OnNotesChanged()
 if not self.frame or not self.frame:IsVisible() or UI.hiding then return end
 self:RefreshRoster();self:LayoutBatches()
 if not UI.Tooltip.sourceRoster then UI.Tooltip:RefreshRelations() end
end
function P:WatchNotes()
 UI:PrepareNotes()
 local wanted=not UI.preview and A:GetSetting("notesEnabled")==true and A.Notes~=nil
 if (self.notesUnsub~=nil)==wanted then return false end
 if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 if wanted then self.notesUnsub=A.Notes:Subscribe(function() P:OnNotesChanged() end) end
 return true
end
function P:ApplyTablePreferences()
 local tablePrefs=UI:GetTablePrefs("createApplicants");self.applicantTable:SetState(tablePrefs)
 state.sort=columnSorts[tablePrefs.sortKey] or "newest";state.descending=tablePrefs.descending==true
 self:RefreshApplicants()
end
function P:Enter(context)
 if self.correctionExpired then self:HideCorrectionNotice() end
 local tablePrefs=UI:GetTablePrefs("createApplicants");self.applicantTable:SetState(tablePrefs)
 state.sort=columnSorts[tablePrefs.sortKey] or "newest";state.descending=tablePrefs.descending==true
 local group=UI:GetGroup();group:Attach(self,"create");group:RefreshApplicants()
 if not self.unsub then self.unsub=group:Subscribe(function(kind)
  if kind=="listing" and P.submitting then P.submissionListingChanged=true;return end
  if UI.hiding then return end
  if kind=="listing" or kind=="permissions" then P:RefreshMode();P:RefreshApplicants() elseif kind=="applicants" or kind=="applicant" then P:RefreshApplicants() elseif kind=="roster" then P:RefreshRoster() elseif kind=="relations" then P:OnNotesChanged() elseif kind=="creationPresets" then P:RefreshFavorites() elseif kind=="activities" then if P.formFrame:IsShown() then P:RefreshPicker() else P:RefreshRosterPresentation() end end
 end) end
 self:WatchNotes()
 RefreshMode(self);RefreshRoster(self);RefreshFavorites(self);FinishRosterPresentation(self)
 UI:RefreshWindowSize()
 self:RefreshApplicants()
 if context and context.applicantID then for i,id in ipairs(self.appIDs) do if id==context.applicantID then self:SetBatchOffset(self.batchTops[i],false);break end end end
end
function P:Leave()
 self.applicantTimeModes=nil
 self.applicantTable:StopDrag(true)
 self:HideCorrectionNotice()
 UI:GetGroup():SetApplicantView(self,false)
 self.favoritesExpanded=false;RefreshFavorites(self)
 UI.Motion:Stop(self.batchScroll);self.batchScrollTarget=nil;self.batchSlider:Hide()
 if self.unsub then self.unsub();self.unsub=nil end;if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 self:ClosePicker();UI.Native:ReleaseCreation();UI:GetGroup():Detach(self);self:ClearRosterList();self.roster=nil;self.rosterContext=nil;self.buffReport=nil;if self.buffList then self.buffList:Clear();self.buffArea:Hide() end;self.appIDs=nil;self.batchTops=nil;self.batchLayouts=nil;self:RenderBatches();UI.Tooltip:Hide()
end

function P:BeginPreview(provider)
 self.liveState={state=state,form=form,started=self.started}
 if self.frame then
  self.liveState.inputs={ilvl=self.ilvl.box:GetText(),score=self.score.box:GetText(),private=self.private.value,cross=self.crossFaction.value,auto=self.autoAccept.value}
  self.preparing=true;self.ilvl.box:SetText("");self.score.box:SetText("");self.private:SetValue(false);self.crossFaction:SetValue(false);self.autoAccept:SetValue(false);self.preparing=nil
 end
 state={category=provider.category,group=provider.Catalog:GetGroupKey(provider.category,provider.activity),editing=false,sort="newest"};form={activityID=provider.activity.id,crossFaction=true};self.started=nil
end
function P:EndPreview()
 local saved=self.liveState;if not saved then return end
 state,form,self.started=saved.state,saved.form,saved.started;self.liveState=nil
 if self.frame then
  self.preparing=true
  local fields=saved.inputs
  self.ilvl.box:SetText(fields and fields.ilvl or "");self.score.box:SetText(fields and fields.score or "")
  self.private:SetValue(fields and fields.private or false);self.crossFaction:SetValue(fields and fields.cross or false);self.autoAccept:SetValue(fields and fields.auto or false)
  self.preparing=nil
 end
end




function P:RegisterBuildElements()
UI:ElementFields(self,"create","frame surface formFrame heading desc activityLabel pickerTrigger pickerIcon pickerName pickerContext difficultyChoice difficultyGroup difficultySelection difficultyFixedSurface difficultyFixed favorite titleLabel titleShell descriptionLabel descriptionShell req requirementsLabel ilvlLabel ilvl scoreLabel score styleLabel playstyle private crossFaction autoAccept autoInviteHint publish formCancel formNotice correctionNotice manage sIcon sMeta sName editListing cancelListing listingFavorite applicantsHeading appCount roleFilterSurface sortChoice applicantTable batchScroll batchBody batchSlider empty manageNotice rail favoritesCard favoritesToggle favoritesChevron favoritesBody favoritesEmpty rosterCard rosterTitle rosterCount groupSummary groupStrip buffArea buffTitle buffComplete picker pickerSearch pickerSearchHint pickerClear pickerSurface tierChoice pickerEmpty","create")
 UI:ElementList(self.favoritesList,"create.favoritesList","create","create.favoriteRow")
 UI:ElementList(self.buffList,"create.buffList","create","create.buff")
 UI:ElementList(self.pickerCategories,"create.pickerCategories","create","create.pickerCategory")
 UI:ElementList(self.pickerResults,"create.pickerResults","create","create.pickerActivity")
 for key,button in pairs(self.roleFilters or {}) do UI:Element(button,"create.roleFilter","create",button,"create.roleFilter",key) end
 for index,button in ipairs(self.difficultyButtons or {}) do UI:Element(button,"create.difficulty","create",button,"create.difficulty",button.value or index) end
 local roster=self.rosterList
 if roster then UI:Element(roster,"create.rosterList","create");UI:ElementFields(roster,"create.rosterList","clip body slider empty","create") end
end
