-- Recruitment form, applicant batches and the full current roster share native state.
local A=_G.LycheeGroup
local UI=A.UI
local T,L,C=UI.Theme,UI.L,UI.C
local MAIN=T.contentWidth-288-16
local FORM=math.min(700,MAIN-48)
local CONTENT=MAIN-48
local BATCH_WIDTH=CONTENT-C.listRightInset
local columns={
 name={x=12,width=247,align="LEFT"},comment={x=275,width=135,align="LEFT"},
 role={x=422,width=66,align="LEFT"},ilvl={x=500,width=78,align="RIGHT"},
 rating={x=590,width=64,align="RIGHT"},actions={x=BATCH_WIDTH-84,width=84,align="CENTER"},
}
local MEMBER_HEIGHT,MEMBER_STRIDE=56,60
local BATCH_TOP,BATCH_MAX_HEIGHT=194,T.contentHeight-242
local P={};UI.pages.create=P
local function HideMemberTooltip(row)
 if UI.Tooltip:IsOwned(row) then UI.Tooltip:Hide() end
end
local function MemberTooltipArea(row,clip)
 local area=CreateFrame("Frame",nil,row);area:SetPoint("TOPLEFT");area:SetPoint("BOTTOMLEFT");area:SetWidth(row:GetWidth()*.25)
 row.tooltipArea=area
 row:HookScript("OnSizeChanged",function(_,width) area:SetWidth(width*.25) end)
 area:SetScript("OnEnter",function()
  if not row:IsEnabled() or not row.member or row._hitVisible==false or not clip:IsMouseOver() then return end
  local enter=row:GetScript("OnEnter");if enter then enter(row) end
  UI.Tooltip:ShowPlayer(row,row.member)
 end)
 area:SetScript("OnLeave",function()
  if not row:IsMouseOver() then local leave=row:GetScript("OnLeave");if leave then leave(row) end end
  UI.Tooltip:LeaveOwner(row)
 end)
 area:SetScript("OnHide",function() HideMemberTooltip(row) end)
 -- Retail enables clicks when hover scripts are assigned; narrow input last.
 area:EnableMouse(false);area:EnableMouseMotion(true)
end
local state={category="seasonDungeon",editing=false,sort="newest"}
local form={crossFaction=true}
local zh=GetLocale()=="zhCN"
local function S(cn,en) return zh and cn or en end
-- Measure unconstrained text: recycled labels may still carry the previous row width.
local function FitText(label)
 label:SetWordWrap(false);label:SetWidth(0)
 local width=math.ceil(label:GetStringWidth())+2;label:SetWidth(width);return width
end
local function PlaystyleLabel(value)
 local e=Enum.LFGEntryGeneralPlaystyle
 if value==e.Learning then return GROUP_FINDER_GENERAL_PLAYSTYLE1 elseif value==e.FunRelaxed then return GROUP_FINDER_GENERAL_PLAYSTYLE2 elseif value==e.FunSerious then return GROUP_FINDER_GENERAL_PLAYSTYLE3 elseif value==e.Expert then return GROUP_FINDER_GENERAL_PLAYSTYLE4 end
 return ""
end
local roles={TANK=L.tank,HEALER=L.healer,DAMAGER=L.damage}
local function Shell(parent,w,h,x,y)
 local shell=C.Field(parent,w,h);shell:SetPoint("TOPLEFT",x,y);return shell
end
local function Minimum(app,key)
 local value
 for _,m in ipairs(app.members) do
  local current
  if key=="rating" then current=UI:MemberRating(m) else current=m[key] end
  if current==nil then return -1 end
  value=math.min(value or current,current)
 end
 return value or -1
end
function P:Build(parent)
 local root=CreateFrame("Frame",nil,parent);root:SetAllPoints();self.frame=root
 local surface=CreateFrame("Frame",nil,root);surface:SetSize(MAIN,T.contentHeight);surface:SetPoint("TOPLEFT");C.Panel(surface,T.surfaceLow,24);self.surface=surface
 local f=CreateFrame("Frame",nil,surface);f:SetSize(FORM,T.contentHeight-48);f:SetPoint("TOP",0,-24);self.formFrame=f
 self.heading=C.Text(f,L.create,24);C.SetLineHeight(self.heading,32,true);self.heading:SetPoint("TOPLEFT")
 local desc=CreateFrame("Frame",nil,f);desc:SetSize(FORM,324);desc:SetPoint("TOPLEFT",0,-56);self.desc=desc
 self.activityLabel=C.Text(desc,S("活动与难度","Activity and difficulty"),14);C.SetLineHeight(self.activityLabel,20,true);self.activityLabel:SetPoint("TOPLEFT")
 self.pickerTrigger=C.Button(desc,"",340,function() P:TogglePicker() end);self.pickerTrigger.isChoice=true;self.pickerTrigger:SetHeight(52);self.pickerTrigger:SetPoint("TOPLEFT",0,-28);self.pickerTrigger.fill:SetRadius(4);self.pickerTrigger.hover:SetRadius(4);self.pickerTrigger.fill:SetColor(T.selectBackground);self.pickerTrigger.fill:Show()
 self.pickerIcon=C.Icon(self.pickerTrigger,28);self.pickerIcon:SetPoint("LEFT",12,0)
 self.pickerName=C.Text(self.pickerTrigger,"",14,T.text,260);C.SetLineHeight(self.pickerName,20,true);self.pickerName:SetPoint("TOPLEFT",52,-4)
 self.pickerContext=C.Text(self.pickerTrigger,"",14,T.muted,260);C.SetLineHeight(self.pickerContext,20,true);self.pickerContext:SetPoint("TOPLEFT",52,-26)
 C.Glyph(self.pickerTrigger,"chevron",12):SetPoint("RIGHT",-12,0)
 self.difficultyChoice=C.Choice(desc,FORM-352,function() return P:DifficultyItems() end,function(value) form.activityID=value;P:RefreshPicker() end);self.difficultyChoice:SetHeight(36);self.difficultyChoice:SetPoint("TOPLEFT",352,-32)
 self.difficultyGroup=CreateFrame("Frame",nil,desc);self.difficultyGroup:SetSize(FORM-352,36);self.difficultyGroup:SetPoint("TOPLEFT",352,-32);C.Panel(self.difficultyGroup,T.panel,8)
 self.difficultyButtons={}
 for i=1,4 do local b=C.Button(self.difficultyGroup,"",72,function(button) form.activityID=button.value;P:RefreshPicker() end);b:SetHeight(30);b:SetTextColors(T.muted,T.text,T.onSecondaryContainer);b.fill:SetRadius(8);b.hover:SetRadius(8);b.label:SetFont(T.font,13,"");C.SetLineHeight(b.label,20,true);self.difficultyButtons[i]=b end
 self.difficultyFixedSurface=CreateFrame("Frame",nil,desc);self.difficultyFixedSurface:SetSize(52,38);C.Panel(self.difficultyFixedSurface,T.field,8)
 self.difficultyFixed=C.Text(self.difficultyFixedSurface,"",14,T.muted);C.SetLineHeight(self.difficultyFixed,20,true);self.difficultyFixed:SetPoint("CENTER")
 self.titleLabel=C.Text(desc,L.title,14,T.muted);C.SetLineHeight(self.titleLabel,20,true);self.titleLabel:SetPoint("TOPLEFT",0,-92)
 self.titleShell=Shell(desc,FORM,44,0,-116)
 self.descriptionLabel=C.Text(desc,L.comment,14,T.muted);C.SetLineHeight(self.descriptionLabel,20,true);self.descriptionLabel:SetPoint("TOPLEFT",0,-172)
 self.descriptionShell=Shell(desc,FORM,80,0,-196)
 for _,shell in ipairs({self.titleShell,self.descriptionShell}) do
  shell:EnableMouse(true)
  shell:SetScript("OnEnter",function() P:EnsureCreationInput() end)
  shell:SetScript("OnMouseDown",function(field,button) if button=="LeftButton" and P:EnsureCreationInput() then field.box:SetFocus() end end)
 end
 local req=CreateFrame("Frame",nil,f);req:SetSize(FORM,188);req:SetPoint("TOPLEFT",0,-356);self.req=req
 self.requirementsLabel=C.Text(req,L.requirements,14);C.SetLineHeight(self.requirementsLabel,20,true);self.requirementsLabel:SetPoint("TOPLEFT")
 self.ilvlLabel=C.Text(req,L.minItemLevel,14,T.muted);self.ilvlLabel:SetPoint("TOPLEFT",0,-32)
 self.ilvl=C.Number(req,196,44);self.ilvl:SetPoint("TOPLEFT",0,-56)
 self.scoreLabel=C.Text(req,L.minRating,14,T.muted);self.scoreLabel:SetPoint("TOPLEFT",212,-32)
 self.score=C.Number(req,196,44);self.score:SetPoint("TOPLEFT",212,-56)
 self.styleLabel=C.Text(req,L.playstyle,14,T.muted);self.styleLabel:SetPoint("TOPLEFT",424,-32)
 self.playstyle=C.Choice(req,FORM-424,function() return P:PlaystyleItems() end,function(value) form.generalPlaystyle=value;P:ValidateForm() end);self.playstyle:SetHeight(44);self.playstyle:SetPoint("TOPLEFT",424,-56)
 self.private=C.Check(req,L.private,function() P:ValidateForm() end);self.private:SetPoint("TOPLEFT",0,-112)
 self.crossFaction=C.Check(req,L.crossFaction,function(value) form.crossFaction=value;P:ValidateForm() end);self.crossFaction:SetPoint("TOPLEFT",136,-112)
 self.autoAccept=C.Check(req,L.autoAccept,function() P:ValidateForm() end);self.autoAccept:SetPoint("TOPLEFT",258,-112)
 self.publish=C.Button(f,L.publish,120,function() P:Submit() end);self.publish:SetPoint("BOTTOMRIGHT");self.publish:SetHeight(40);self.publish:SetPrimary(true)
 self.formCancel=C.Button(f,L.cancel,120,function() state.editing=false;UI.Native:ReleaseCreation();P:RefreshMode() end);self.formCancel:SetHeight(40);self.formCancel:SetPoint("RIGHT",self.publish,"LEFT",-8,0)
 self.formNotice=C.Notice(f,FORM,function() P:SetFormError("") end);self.formNotice:SetPoint("TOPLEFT",0,-44);self.formError=self.formNotice.text
 local optionX=0
 for _,option in ipairs({self.private,self.crossFaction,self.autoAccept}) do
  option:SetHeight(40);option.label:ClearAllPoints();option.label:SetPoint("LEFT",option.track,"RIGHT",8,0);option:SetWidth(52+FitText(option.label))
  option:ClearAllPoints();option:SetPoint("TOPLEFT",optionX,-112);optionX=optionX+option:GetWidth()+28
 end
 for _,label in ipairs({self.ilvlLabel,self.scoreLabel,self.styleLabel}) do C.SetLineHeight(label,20,true) end
 self.ilvl.box:HookScript("OnTextChanged",function() P:ValidateForm() end);self.score.box:HookScript("OnTextChanged",function() P:ValidateForm() end)
 local manage=CreateFrame("Frame",nil,surface);manage:SetSize(CONTENT,T.contentHeight-48);manage:SetPoint("TOPLEFT",24,-24);self.manage=manage
 self.sIcon=C.Icon(manage,44);self.sIcon:SetPoint("TOPLEFT",0,-1)
 self.sMeta=C.Text(manage,"",14,T.muted,CONTENT-280);self.sMeta:SetFont(T.font,14,"");C.SetLineHeight(self.sMeta,20,true);self.sMeta:SetPoint("TOPLEFT",56,0);self.sMeta:SetMaxLines(1);self.sMeta:SetWordWrap(false)
 self.sName=C.Text(manage,"",18,T.text,CONTENT-280);C.SetLineHeight(self.sName,24,true);self.sName:SetPoint("TOPLEFT",56,-22);self.sName:SetWordWrap(false)
 self.editListing=C.Button(manage,L.edit,80,function()
  local allowed,err=UI:GetGroup():CanManageListing();if not allowed then P:SetManageError(err);return end
  state.editing=true;P:PrepareForm(true);P:RefreshMode()
 end);self.editListing:SetPoint("TOPRIGHT",-108,-3);self.editListing:SetHeight(40)
 self.cancelListing=C.Button(manage,S("取消招募","End listing"),100,function() local ok,err=UI:GetGroup():RemoveListing();P:SetManageError(not ok and (err or L.failed) or "") end);self.cancelListing:SetPoint("TOPRIGHT",0,-3);self.cancelListing:SetHeight(40)
 self.cancelListing:SetWidth(FitText(self.cancelListing.label)+34);self.editListing:SetWidth(FitText(self.editListing.label)+34)
 self.editListing:ClearAllPoints();self.editListing:SetPoint("RIGHT",self.cancelListing,"LEFT",-8,0)
 local summaryWidth=CONTENT-68-self.cancelListing:GetWidth()-8-self.editListing:GetWidth();self.sMeta:SetWidth(summaryWidth);self.sName:SetWidth(summaryWidth)
 self.applicantsHeading=C.Text(manage,L.manageApplicants,18);C.SetLineHeight(self.applicantsHeading,24,true);self.applicantsHeading:SetPoint("TOPLEFT",0,-70)
 self.appCount=C.Text(manage,"",14,T.muted);C.SetLineHeight(self.appCount,20,true);self.appCount:SetPoint("TOPRIGHT",0,-73)
 self.roleFilters={}
 local filterSurface=CreateFrame("Frame",nil,manage);filterSurface:SetSize(356,36);filterSurface:SetPoint("TOPLEFT",0,-114);C.Panel(filterSurface,T.panel,8);self.roleFilterSurface=filterSurface
 for i,key in ipairs({"ALL","TANK","HEALER","DAMAGER"}) do
  local b=C.Button(filterSurface,key=="ALL" and L.all or roles[key],84,function() state.role=key~="ALL" and key or nil;P:RefreshApplicants() end);b:SetHeight(30);b:SetTextColors(T.muted,T.text,T.onSecondaryContainer);b.fill:SetRadius(8);b.hover:SetRadius(8);b:SetPoint("TOPLEFT",3+(i-1)*88,-3);b.label:SetFont(T.font,13,"");if key~="ALL" then local roleIcon=C.Icon(b,16);roleIcon:SetPoint("LEFT",12,0);UI:SetRoleIcon(roleIcon,key);b.label:ClearAllPoints();b.label:SetPoint("LEFT",roleIcon,"RIGHT",6,0) end;self.roleFilters[key]=b
 end
 self.sortChoice=C.Choice(manage,144,{{value="newest",label=L.newest},{value="score",label=L.rating},{value="ilvl",label=L.itemLevel}},function(value) state.sort=value;P:RefreshApplicants() end);self.sortChoice:SetHeight(44);self.sortChoice:SetPoint("TOPRIGHT",0,-110);self.sortChoice:SetValue("newest",L.newest)
 local filterX=3
 for _,key in ipairs({"ALL","TANK","HEALER","DAMAGER"}) do local button=self.roleFilters[key];C.SetLineHeight(button.label,20,true);button:SetWidth(FitText(button.label)+24+(key~="ALL" and 22 or 0));button:ClearAllPoints();button:SetPoint("TOPLEFT",filterX,-3);filterX=filterX+button:GetWidth()+4 end
 filterSurface:SetWidth(filterX-1)
 self.applicantHeaders={}
 for _,h in ipairs({{"name",S("申请者 / 成员标记","Applicant / member markers")},{"comment",S("申请备注","Application note")},{"role",L.role},{"ilvl",L.itemLevel},{"rating",L.rating},{"actions",S("操作","Actions")}}) do
  local col=columns[h[1]];local label=C.Header(manage,h[2],col.x,-167,col.width);label:SetJustifyH(col.align);self.applicantHeaders[h[1]]=label
 end
 self.batchScroll=CreateFrame("ScrollFrame",nil,manage);self.batchScroll:SetPoint("TOPLEFT",0,-BATCH_TOP);self.batchScroll:SetSize(BATCH_WIDTH,BATCH_MAX_HEIGHT)
 self.batchBody=CreateFrame("Frame",nil,self.batchScroll);self.batchBody:SetWidth(BATCH_WIDTH);self.batchBody:SetHeight(1);self.batchScroll:SetScrollChild(self.batchBody)
 self.batchSlider=C.ScrollBar(manage);self.batchSlider:SetHeight(BATCH_MAX_HEIGHT);self.batchSlider:SetPoint("TOPRIGHT",0,-BATCH_TOP)
 self.batchSlider:SetScript("OnValueChanged",function(_,value) if not P.syncBatchScroll then P:SetBatchOffset(value,false) end end)
 self.batchScroll:EnableMouseWheel(true);self.batchScroll:SetScript("OnMouseWheel",function(s,d) P:SetBatchOffset((P.batchScrollTarget or s:GetVerticalScroll())-d*56,true) end)
 self.batchPool={}
 self.empty=C.Text(manage,L.noApplicants,17,T.muted,CONTENT-48);self.empty:SetPoint("CENTER",self.batchScroll,"CENTER",0,0);self.empty:SetJustifyH("CENTER")
 self.manageNotice=C.Notice(manage,CONTENT,function() P:SetManageError("") end);self.manageNotice:SetPoint("TOPLEFT",0,-162);self.dError=self.manageNotice.text
 local rail=CreateFrame("Frame",nil,root);rail:SetSize(288,T.contentHeight);rail:SetPoint("TOPRIGHT");C.Panel(rail,T.surfaceLow,24);self.rail=rail
 self.rosterTitle=C.Text(rail,L.yourGroup,18,nil,nil,24);C.SetLineHeight(self.rosterTitle,24,true);self.rosterTitle:SetPoint("TOPLEFT",20,-20)
 self.rosterCount=C.Text(rail,"",14,T.muted);C.SetLineHeight(self.rosterCount,20,true);self.rosterCount:SetPoint("LEFT",self.rosterTitle,"RIGHT",8,0)
 self.groupStrip=C.Roster(rail,18,5);self.groupStrip:SetHeight(18);self.groupStrip:SetPoint("TOPLEFT",20,-60)
 self.rosterList=C.List(rail,248,T.contentHeight-114,72);self.rosterList:SetPoint("TOPLEFT",20,-94)
 for _,row in ipairs(self.rosterList.rows) do
  row:SetScript("OnClick",nil)
  row.icon=C.Icon(row,32);row.icon:SetPoint("LEFT",12,0);row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",56,-12);C.SetLineHeight(row.title,T.listTitleLineHeight,true);row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",56,-40);C.SetLineHeight(row.meta,20,true);row.leaderTag=C.Icon(row,12);row.leaderTag:SetTexture(T.media.."leader.tga");row.leaderTag:SetPoint("TOPLEFT",56,-18);row.leaderTag:Hide();row.noteDot:SetPoint("RIGHT",-2,0)
  MemberTooltipArea(row,self.rosterList.clip)
 end
end
function P:SetFormError(message)
 self.formNotice:SetMessage(message)
 local offset=self.formNotice:IsShown() and self.formNotice:GetHeight()+12 or 0
 self.desc:ClearAllPoints();self.desc:SetPoint("TOPLEFT",0,-56-offset)
 self.req:ClearAllPoints();self.req:SetPoint("TOPLEFT",0,-356-offset)
end
function P:LayoutApplicantViewport()
 local offset=self.manageNotice:IsShown() and self.manageNotice:GetHeight()+12 or 0
 for key,label in pairs(self.applicantHeaders) do label:ClearAllPoints();label:SetPoint("TOPLEFT",columns[key].x,-167-offset) end
 self.batchScroll:ClearAllPoints();self.batchScroll:SetPoint("TOPLEFT",0,-BATCH_TOP-offset)
 self.batchSlider:ClearAllPoints();self.batchSlider:SetPoint("TOPRIGHT",0,-BATCH_TOP-offset)
 local height=math.max(1,BATCH_MAX_HEIGHT-offset)
 self.batchScroll:SetHeight(height);self.batchSlider:SetHeight(height)
 self.syncBatchScroll=true;self.batchSlider:SetMinMaxValues(0,math.max(0,self.batchBody:GetHeight()-height));self.syncBatchScroll=nil
 self.batchSlider:SetShown(self.batchBody:GetHeight()>height)
 self.boundAppIDs=nil;self:SetBatchOffset(self.batchScroll:GetVerticalScroll(),false)
end
function P:SetManageError(message)
 self.manageNotice:SetMessage(message);self:LayoutApplicantViewport()
end
function P:ShowError(message)
 if self.formFrame:IsShown() then self:SetFormError(message) else self:SetManageError(message) end
end
function P:BuildBatch(parent)
 local f=CreateFrame("Frame",nil,parent);f:SetWidth(BATCH_WIDTH);f.bg=C.Panel(f,T.rowAlternate,12)
 UI.drag:AddHandle(f)
 f.comment=C.Text(f,"",14,T.muted,columns.comment.width);f.comment:SetPoint("TOPLEFT",columns.comment.x,-12);f.comment:SetJustifyV("MIDDLE");C.SetLineHeight(f.comment,20)
 f.status=C.Text(f,"",14,T.muted,columns.actions.width);f.status:SetPoint("LEFT",columns.actions.x,0);f.status:SetJustifyH("CENTER");C.SetLineHeight(f.status,20)
 f.invite=C.Button(f,"",40,function(btn) P:ApplicantAction(btn,"Invite") end);f.invite:SetHeight(40);f.invite:SetPoint("LEFT",columns.actions.x,0)
 f.decline=C.Button(f,"",40,function(btn) P:ApplicantAction(btn,"Decline") end);f.decline:SetHeight(40);f.decline:SetPoint("LEFT",columns.actions.x+44,0)
 f.invite.glyph=C.Icon(f.invite,24);f.invite.glyph:SetTexture(T.media.."invite.tga");f.invite.glyph:SetPoint("CENTER")
 f.decline.glyph=C.Icon(f.decline,24);f.decline.glyph:SetTexture(T.media.."decline.tga");f.decline.glyph:SetPoint("CENTER")
 f:EnableMouse(true);f:SetScript("OnEnter",function(b) b.bg:SetColor(T.rowHover);b.bg:Show() end);f:SetScript("OnLeave",function(b) b.bg:SetColor(T.rowAlternate);b.bg:SetShown(b.alternate==true) end)
 for _,action in ipairs({f.invite,f.decline}) do
  local color=action==f.invite and T.good or T.accent;action.hoverColor={color[1],color[2],color[3],.12};action.pressedColor={color[1],color[2],color[3],.18}
 end
 f.people={}
 return f
end
function P:EnsureBatchMembers(f,count)
 for i=#f.people+1,count do
  local row=CreateFrame("Button",nil,f);row:SetSize(columns.actions.x,MEMBER_HEIGHT);row:RegisterForClicks("LeftButtonUp","RightButtonUp")
  row.icon=C.Icon(row,28);row.icon:SetPoint("LEFT",12,0)
  row.title=C.Text(row,"",T.listTitleSize,T.text,211);row.title:SetPoint("TOPLEFT",48,-4);C.SetLineHeight(row.title,T.listTitleLineHeight,true);row.title:SetWordWrap(false)
  row.meta=C.Text(row,"",14,T.dim,211);row.meta:SetPoint("TOPLEFT",48,-32);C.SetLineHeight(row.meta,20,true);row.meta:SetWordWrap(false)
  row.role=C.Icon(row,16);row.role:SetPoint("LEFT",columns.role.x,0)
  row.roleText=C.Text(row,"",14,T.muted,columns.role.width-22);row.roleText:SetPoint("LEFT",columns.role.x+22,0);C.SetLineHeight(row.roleText,20,true)
  row.ilvl=C.Text(row,"",14,T.muted,columns.ilvl.width);row.ilvl:SetPoint("LEFT",columns.ilvl.x,0);row.ilvl:SetJustifyH(columns.ilvl.align);C.SetLineHeight(row.ilvl,20,true)
  row.score=C.Text(row,"",14,T.muted,columns.rating.width);row.score:SetPoint("LEFT",columns.rating.x,0);row.score:SetJustifyH(columns.rating.align);C.SetLineHeight(row.score,20,true)
  row:SetScript("OnEnter",function(r) if r.member then r:GetParent().bg:SetColor(T.rowHover);r:GetParent().bg:Show() end end)
  row:SetScript("OnLeave",function(r) local batch=r:GetParent();batch.bg:SetColor(T.rowAlternate);batch.bg:SetShown(batch.alternate==true);UI.Tooltip:LeaveOwner(r) end)
  MemberTooltipArea(row,self.batchScroll)
  f.people[i]=row
 end
end
function P:BuildPicker(parent)
 local popup=CreateFrame("Frame",nil,parent);popup:SetSize(560,464);popup:SetPoint("TOPLEFT",self.pickerTrigger,"BOTTOMLEFT",0,-8);popup:SetFrameLevel(parent:GetFrameLevel()+30);C.Panel(popup,T.surface,12);popup:EnableMouse(true);popup:Hide();self.picker=popup
 self.pickerSearch=C.Edit(popup,536,44);self.pickerSearch:SetPoint("TOPLEFT",12,-12)
 self.pickerSearch.box:ClearAllPoints();self.pickerSearch.box:SetPoint("TOPLEFT",36,-4);self.pickerSearch.box:SetPoint("BOTTOMRIGHT",-12,4)
 C.Glyph(self.pickerSearch,"search",16):SetPoint("LEFT",12,0)
 self.pickerSearchHint=C.Text(self.pickerSearch,S("搜索全部活动","Search every activity"),14,T.dim);C.SetLineHeight(self.pickerSearchHint,20,true);self.pickerSearchHint:SetPoint("LEFT",36,0)
 self.pickerClear=C.Button(self.pickerSearch,"",40,function() P.pickerSearch.box:SetText("");P.pickerSearch.box:SetFocus() end);self.pickerClear:SetHeight(40);self.pickerClear:SetPoint("RIGHT",-12,0);C.Glyph(self.pickerClear,"close",20):SetPoint("CENTER");self.pickerClear:Hide()
 self.pickerSearch.box:HookScript("OnTextChanged",function(box) local filled=box:GetText()~="";P.pickerSearchHint:SetShown(not filled);P.pickerClear:SetShown(filled);box:ClearAllPoints();box:SetPoint("TOPLEFT",36,-4);box:SetPoint("BOTTOMRIGHT",filled and -60 or -12,4);P:RefreshPickerRows() end)
 self.pickerCategories=C.List(popup,148,368,48,function(key) P.pickerCategory=key;P.pickerTier=nil;P:RefreshPickerRows() end);self.pickerCategories:SetPoint("TOPLEFT",12,-76)
 self.pickerCategories:SetGutter(0);self.pickerCategories.alternateRows=false
 for _,row in ipairs(self.pickerCategories.rows) do row:SetHeight(44);row.selected:SetRadius(8);row.hover:SetRadius(8);row.alternate:SetRadius(8);row.symbol=C.Icon(row,18);row.symbol:SetPoint("LEFT",12,0);row.title:SetFont(T.font,16,"");row.title:ClearAllPoints();row.title:SetPoint("LEFT",38,0);row.title:SetWidth(98);row.title:SetWordWrap(true);row.title:SetHeight(0);C.SetLineHeight(row.title,22);row.meta:Hide() end
 self.pickerSurface=CreateFrame("Frame",nil,popup);self.pickerSurface:SetSize(376,384);self.pickerSurface:SetPoint("TOPLEFT",172,-68);C.Panel(self.pickerSurface,T.surfaceLow,16)
 self.tierChoice=C.Choice(self.pickerSurface,360,function() return P:TierItems(P.pickerCategory) end,function(value) P.pickerTier=value or nil;P:RefreshPickerRows() end);self.tierChoice:SetHeight(44);self.tierChoice:SetPoint("TOPLEFT",8,-8)
 self.pickerResults=C.List(self.pickerSurface,360,312,44,function(index) P:SelectPickerRow(index) end);self.pickerResults:SetPoint("TOPLEFT",8,-64)
 self.pickerResults.alternateRows=false
 for _,row in ipairs(self.pickerResults.rows) do row.selected:SetRadius(8);row.hover:SetRadius(8);row.alternate:SetRadius(8);row.icon=C.Icon(row,24);row.icon:SetPoint("LEFT",12,0);row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",48,-3);row.title:SetWidth(286);row.title:SetFont(T.font,16,"");C.SetLineHeight(row.title,22,true);row.meta:ClearAllPoints();row.meta:SetPoint("TOPLEFT",48,-25);row.meta:SetWidth(286) end
 self.pickerEmpty=C.Text(popup,S("没有匹配的活动","No matching activities"),14,T.dim,320);self.pickerEmpty:SetPoint("TOPLEFT",184,-180)
 popup:SetScript("OnEvent",function() if not popup:IsMouseOver() and not P.pickerTrigger:IsMouseOver() then P:ClosePicker() end end)
end
function P:TogglePicker()
 if not self.picker then self:BuildPicker(self.frame) end
 if self.picker:IsShown() then self:ClosePicker();return end
 self.pickerTrigger:SetExpanded(true)
 self.pickerCategory=state.category;self.pickerTier=state.tier;self.picker:Show();UI.Motion:Reveal(self.picker,"TOPLEFT",self.pickerTrigger,"BOTTOMLEFT",0,-8,0,4,.14);self.picker:RegisterEvent("GLOBAL_MOUSE_DOWN");self:RefreshPickerRows();self.pickerSearch.box:SetFocus()
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
 self.pickerCategories.selectedKey=self.pickerCategory;self.pickerCategories:SetShown(not searching);self.pickerCategories:SetItems(cats,function(row,key) UI:SetText(row.title,catMap[key].name);row.symbol:SetTexture(T.media..catMap[key].icon..".tga");row.symbol:SetTexCoord(0,1,0,1);UI:SetText(row.meta,"") end)
 local tierNames={};for _,tier in ipairs(catalog:GetTiers()) do tierNames[tier.id]=tier.name end
 local entries,indices={},{}
 for _,cat in ipairs(catalog:GetCategories()) do
  if searching or cat.key==self.pickerCategory then
   for _,group in ipairs(catalog:GetGroups(cat.key)) do
    local context=cat.name..(group.tier and " · "..(tierNames[group.tier] or "") or "")
    if (searching and (group.name.." "..context):lower():find(query,1,true)) or (not searching and (not self.pickerTier or group.tier==self.pickerTier)) then
     entries[#entries+1]={category=cat.key,group=group,context=context};indices[#indices+1]=#entries
    end
   end
  end
 end
 self.pickerEntries=entries;self.pickerResults:SetWidth(searching and 520 or 360);self.pickerResults:SetGutter(C.listRightInset);self.pickerSurface:SetWidth(searching and 536 or 376);self.pickerSurface:ClearAllPoints();self.pickerSurface:SetPoint("TOPLEFT",searching and 12 or 172,-68)
 self.pickerResults:ClearAllPoints();self.pickerResults:SetPoint("TOPLEFT",8,searching and -8 or -64);self.pickerResults:SetViewport(searching and 368 or 312)
 for _,row in ipairs(self.pickerResults.rows) do row:SetWidth((searching and 520 or 360)-C.listRightInset);row.title:SetWidth(searching and 446 or 286);row.meta:SetWidth(searching and 446 or 286) end
 self.pickerResults.selectedKey=nil
 for index,entry in ipairs(entries) do if entry.category==state.category and entry.group.key==state.group then self.pickerResults.selectedKey=index;break end end
 self.pickerResults:SetItems(indices,function(row,index)
  local entry=entries[index];UI:SetActivityIcon(row.icon,entry.group.activity);UI:SetText(row.title,entry.group.name);UI:SetText(row.meta,entry.context)
  row.title:ClearAllPoints();row.title:SetPoint("LEFT",48,0);row.title:SetWidth(searching and 302 or 282);C.SetLineHeight(row.title,22,true)
  row.meta:ClearAllPoints();row.meta:SetPoint("RIGHT",-12,0);row.meta:SetWidth(128);C.SetLineHeight(row.meta,20,true);row.meta:SetJustifyH("RIGHT");row.meta:SetShown(searching)
 end)
 if not showTier then self.pickerResults:ClearAllPoints();self.pickerResults:SetPoint("TOPLEFT",8,-8);self.pickerResults:SetViewport(368) end
 self.pickerEmpty:SetShown(#entries==0);self.tierChoice:SetShown(showTier)
 local tierName=self.pickerTier and tierNames[self.pickerTier] or L.all;self.tierChoice:SetValue(self.pickerTier,tierName)
end
function P:SelectPickerRow(index)
 local entry=self.pickerEntries[index];if not entry then return end
 state.category=entry.category;state.group=entry.group.key;state.tier=entry.group.tier;form.activityID=nil
 self:ClosePicker();self:RefreshPicker()
end
function P:TierItems(categoryKey)
 local used,scopes={},0
 for _,g in ipairs(UI:GetGroup().Catalog:GetGroups(categoryKey or state.category)) do local key=g.tier or false;if not used[key] then used[key]=true;scopes=scopes+1 end end
 local items={{value=false,label=L.all}};for _,tier in ipairs(UI:GetGroup().Catalog:GetTiers()) do if used[tier.id] then items[#items+1]={value=tier.id,label=tier.name} end end;return items,scopes
end
function P:ActivityItems()
 local items={};for _,g in ipairs(UI:GetGroup().Catalog:GetGroups(state.category)) do if not state.tier or g.tier==state.tier then items[#items+1]={value=g.key,label=g.name} end end;return items
end
function P:DifficultyItems()
 local catalog=UI:GetGroup().Catalog;local group=catalog:GetGroup(state.category,state.group);local items={}
 if group and catalog:GetCategory(state.category).id~=121 then for _,act in ipairs(group.variants) do
  local label=act.difficultyID and act.difficultyID>0 and GetDifficultyInfo(act.difficultyID)
  if label then items[#items+1]={value=act.id,label=label} end
 end end;return items
end
function P:RefreshPicker()
 local cat=UI:GetGroup().Catalog:GetCategory(state.category)
 local groups=self:ActivityItems();if not state.group and groups[1] then state.group=groups[1].value end
 local group=UI:GetGroup().Catalog:GetGroup(state.category,state.group)
 UI:SetText(self.pickerName,group and group.name or L.chooseActivity)
 local tierName;for _,tier in ipairs(UI:GetGroup().Catalog:GetTiers()) do if group and group.tier==tier.id then tierName=tier.name end end
 UI:SetText(self.pickerContext,cat and cat.season and S("本赛季","Current season") or tierName or cat and cat.name or "");UI:SetActivityIcon(self.pickerIcon,group and group.activity)
 -- Native activity selection remains independent of the optional difficulty UI.
 local activities=group and group.variants or {};local valid=false
 for _,activity in ipairs(activities) do if activity.id==form.activityID then valid=true;break end end
 if not valid then form.activityID=activities[1] and activities[1].id end
 local variants=self:DifficultyItems()
 local label=L.chooseActivity;for _,entry in ipairs(variants) do if entry.value==form.activityID then label=entry.label end end;self.difficultyChoice:SetValue(form.activityID,label)
 UI:SetText(self.difficultyFixed,label)
 local segmentWidth=6+math.max(0,#variants-1)*4
 for i,b in ipairs(self.difficultyButtons) do local entry=variants[i];if entry then UI:SetText(b.label,entry.label);b._desiredWidth=math.max(48,FitText(b.label)+20);segmentWidth=segmentWidth+b._desiredWidth end end
 local segments=#variants>1 and #variants<=4 and segmentWidth<=FORM-252
 local sideWidth=#variants==0 and 0 or #variants==1 and FitText(self.difficultyFixed)+28 or segments and segmentWidth or 200
 local triggerWidth=FORM-sideWidth-(sideWidth>0 and 12 or 0)
 self.pickerTrigger:SetWidth(triggerWidth);self.pickerName:SetWidth(triggerWidth-76);self.pickerContext:SetWidth(triggerWidth-76)
 self.difficultyGroup:SetWidth(sideWidth);self.difficultyGroup:ClearAllPoints();self.difficultyGroup:SetPoint("LEFT",self.pickerTrigger,"RIGHT",12,0)
 self.difficultyChoice:SetWidth(sideWidth);self.difficultyChoice:ClearAllPoints();self.difficultyChoice:SetPoint("LEFT",self.pickerTrigger,"RIGHT",12,0)
 self.difficultyFixedSurface:ClearAllPoints();self.difficultyFixedSurface:SetPoint("LEFT",self.pickerTrigger,"RIGHT",12,0);self.difficultyFixedSurface:SetWidth(sideWidth);self.difficultyFixedSurface:SetShown(#variants==1)
 self.difficultyChoice:SetShown(#variants>1 and not segments);self.difficultyGroup:SetShown(segments);self.difficultyFixed:SetShown(#variants==1);UI:SetText(self.difficultyFixed,label)
 local x=3
 for i,b in ipairs(self.difficultyButtons) do local entry=variants[i];b:SetShown(entry~=nil and segments);if entry then b.value=entry.value;b:SetWidth(b._desiredWidth);b:ClearAllPoints();b:SetPoint("LEFT",x,0);x=x+b._desiredWidth+4;b:SetActive(entry.value==form.activityID) end end
 local act=form.activityID and UI:GetGroup().Catalog:GetActivity(form.activityID);self.activity=act
 local categoryInfo=cat and C_LFGList.GetLfgCategoryInfo(cat.id)
 self.hasPlaystyle=categoryInfo and categoryInfo.showPlaystyleDropdown==true
 self.playstyle:SetShown(self.hasPlaystyle);self.styleLabel:SetShown(self.hasPlaystyle)
 local crossAllowed=categoryInfo and categoryInfo.allowCrossFaction and act and act.allowCrossFaction
 self.crossFaction:SetAvailable(crossAllowed==true);self.crossFaction:SetValue(crossAllowed==true and form.crossFaction~=false)
 self.scoreKind=act and (act.isMythicPlusActivity and "dungeon" or act.isRatedPvpActivity and "pvp" or nil)
 self.score:SetShown(self.scoreKind~=nil);self.scoreLabel:SetShown(self.scoreKind~=nil)
 UI:SetText(self.ilvlLabel,act and (act.isPvpActivity or act.isRatedPvpActivity) and S("最低 PvP 装等","Minimum PvP item level") or L.minItemLevel)
 UI:SetText(self.scoreLabel,self.scoreKind=="pvp" and S("最低 PvP 评分","Minimum PvP rating") or L.minRating)
 self.playstyle:ClearAllPoints();self.styleLabel:ClearAllPoints();local ilvlWidth=self.hasPlaystyle and (self.scoreKind and (FORM-32)/3.25 or (FORM-16)/2.25) or (self.scoreKind and (FORM-16)/2 or FORM)
 self.ilvl:SetWidth(ilvlWidth);self.score:SetWidth(ilvlWidth);self.score:ClearAllPoints();self.score:SetPoint("TOPLEFT",ilvlWidth+16,-56);self.scoreLabel:ClearAllPoints();self.scoreLabel:SetPoint("TOPLEFT",ilvlWidth+16,-32)
 local x=self.scoreKind and 2*(ilvlWidth+16) or ilvlWidth+16;self.playstyle:SetWidth(math.max(1,FORM-x));self.playstyle:SetPoint("TOPLEFT",x,-56);self.styleLabel:SetPoint("TOPLEFT",x,-32)
 if not form.generalPlaystyle then local options=self:PlaystyleItems();form.generalPlaystyle=options[1] and options[1].value end
 self.playstyle:SetValue(form.generalPlaystyle,form.generalPlaystyle and PlaystyleLabel(form.generalPlaystyle) or L.choosePlaystyle)
 UI.Native:SelectActivity(form.activityID);self:ValidateForm()
end
function P:PlaystyleItems()
 local e=Enum.LFGEntryGeneralPlaystyle;local items={}
 for _,value in ipairs({e.Learning,e.FunRelaxed,e.FunSerious,e.Expert}) do items[#items+1]={value=value,label=PlaystyleLabel(value)} end;return items
end
function P:FormData()
 return {activityID=form.activityID,requiredItemLevel=tonumber(self.ilvl.box:GetText()) or 0,requiredDungeonScore=self.scoreKind=="dungeon" and tonumber(self.score.box:GetText()) or 0,requiredPvpRating=self.scoreKind=="pvp" and tonumber(self.score.box:GetText()) or 0,isAutoAccept=self.autoAccept.value,isPrivateGroup=self.private.value,isCrossFactionListing=self.crossFaction.value,generalPlaystyle=self.hasPlaystyle and form.generalPlaystyle or Enum.LFGEntryGeneralPlaystyle.None}
end
function P:ValidateForm()
 if self.preparing or UI.hiding or not self.formFrame:IsShown() then return end
 local ok,err=UI:GetGroup():CanManageListing()
 self.publish:SetAvailable(ok==true and not self.submitting)
 if ok and self.validationSubmitted then ok,err=UI.Native:ValidateCreation(self:FormData()) end
 self:SetFormError(err or "")
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
 self.validationSubmitted=nil
 local allowed,reason=UI:GetGroup():CanManageListing()
 if not allowed then UI.Native:ReleaseCreation();self.publish:SetAvailable(false);self:SetFormError(reason);return end
 self.preparing=true
 local ok,err=UI.Native:AcquireCreation(self,self.titleShell,self.descriptionShell)
 if not ok then self.preparing=nil;self.publish:SetAvailable(false);self:SetFormError(err);return end
 if editing then
  local l=UI:GetGroup():GetListing();form.activityID=l.activityID;local act=UI:GetGroup().Catalog:GetActivity(form.activityID)
  state.category=UI:GetGroup().Catalog:GetContextForActivity(form.activityID,state.category) or tostring(act.categoryID);state.group=UI:GetGroup().Catalog:GetGroupKey(state.category,act);state.tier=UI:GetGroup().Catalog:GetActivityTier(act)
  local itemLevel=l.requiredItemLevel or 0;local score=act.isRatedPvpActivity and l.requiredPvpRating or l.requiredDungeonScore or 0
  form.generalPlaystyle=l.generalPlaystyle;self.ilvl.box:SetText(itemLevel>0 and tostring(itemLevel) or "");self.score.box:SetText(score>0 and tostring(score) or "")
  form.crossFaction=l.isCrossFactionListing==true;self.private:SetValue(l.privateGroup);self.crossFaction:SetValue(form.crossFaction);self.autoAccept:SetValue(l.autoAccept)
  if UI.preview then UI.Native:SetPreviewCreationText(l.name,l.comment) else C_LFGList.CopyActiveEntryInfoToCreationFields() end
 elseif not self.started then if UI.preview then UI.Native:SetPreviewCreationText("","") else C_LFGList.ClearCreationTextFields() end;self.started=true end
 self:RefreshPicker();self.preparing=nil;self:ValidateForm()
end
function P:RefreshMode()
 local group=UI:GetGroup();local listing=group:GetListing();local canManage=group:CanManageListing()
 if state.hadListing and not listing then form.crossFaction=true;self:RefreshPicker() end
 state.hadListing=listing~=nil
 if not listing or not canManage then state.editing=false end
 self.editListing:SetShown(listing~=nil and canManage);self.cancelListing:SetShown(listing~=nil and canManage)
 local editing=state.editing or not listing;self.rosterCount:ClearAllPoints();if editing then self.rosterCount:SetPoint("LEFT",self.rosterTitle,"RIGHT",8,0) else self.rosterCount:SetPoint("TOPRIGHT",-20,-23) end;self.formFrame:SetShown(editing);self.manage:SetShown(not editing);self.formCancel:SetShown(state.editing)
 if editing then
  UI:SetText(self.heading,state.editing and L.update or L.create);UI:SetText(self.publish.label,state.editing and L.update or L.publish)
  if not canManage then UI.Native:ReleaseCreation() elseif UI.Native.owner~=self then self:PrepareForm(false) end;self:ValidateForm()
 else
  UI.Native:ReleaseCreation();UI:SetText(self.sName,listing.name or L.currentListing)
  local act=UI:GetGroup().Catalog:GetActivity(listing.activityID);UI:SetActivityIcon(self.sIcon,act)
  local category=UI:GetGroup().Catalog:GetContextForActivity(listing.activityID,state.category)
  local group=category and UI:GetGroup().Catalog:GetGroup(category,UI:GetGroup().Catalog:GetGroupKey(category,act))
  local difficulty=act.difficultyID and act.difficultyID>0 and GetDifficultyInfo(act.difficultyID)
  UI:SetText(self.sMeta,(group and group.name or listing.activityName or "")..(difficulty and " · "..difficulty or "").." · "..L.requiredItemLevel.." "..(listing.requiredItemLevel or 0))
 end
end
function P:Submit()
 if self.submitting then return end
 local allowed,reason=UI:GetGroup():CanManageListing()
 if not allowed then self:ShowError(reason);return end
 self.validationSubmitted=true
 if not self:EnsureCreationInput() then return end
 local data=self:FormData();local valid,err=UI.Native:ValidateCreation(data);if not valid then self:SetFormError(err);return end
 self.submitting=true;self.publish:SetAvailable(false)
 local ok,reason;if state.editing then ok,reason=UI:GetGroup():Update(data) else ok,reason=UI:GetGroup():Publish(data) end
 self.submitting=nil
 if ok then self.validationSubmitted=nil;state.editing=false;self:RefreshMode()
 else self:ValidateForm();self:SetFormError(reason or L.failed) end
end
function P:RefreshApplicants()
 UI.Motion:Stop(self.batchScroll);self.batchScrollTarget=nil
 local tip=UI.Tooltip;local refreshMember=false
 local ids={};for _,id in ipairs(UI:GetGroup():GetApplicants()) do
  local app=UI:GetGroup():GetApplicant(id);local match=not state.role;for _,m in ipairs(app.members) do if m.assignedRole==state.role then match=true end;if m==tip.member then refreshMember=true end end
  if match then ids[#ids+1]=id end
 end
 table.sort(ids,function(a,b)
  local x,y=UI:GetGroup():GetApplicant(a),UI:GetGroup():GetApplicant(b)
  if state.sort~="newest" then local key=state.sort=="score" and "rating" or "itemLevel";local av,bv=Minimum(x,key),Minimum(y,key);if av~=bv then return av>bv end end
  return x.displayOrderID==y.displayOrderID and a>b or x.displayOrderID<y.displayOrderID
 end)
 self.appIDs=ids;self.batchTops={};local top=0;for i,id in ipairs(ids) do self.batchTops[i]=top;top=top+math.max(1,#UI:GetGroup():GetApplicant(id).members)*MEMBER_STRIDE+20 end
 self.batchTops[#ids+1]=top
 self.batchBody:SetHeight(math.max(1,top));self:LayoutApplicantViewport()
 self.empty:SetShown(#ids==0);UI:SetText(self.appCount,L.applicantCount:format(#ids))
 for key,b in pairs(self.roleFilters) do b:SetActive((state.role or "ALL")==key) end;self:RenderBatches()
 if refreshMember and tip.member then tip:RenderPlayer(tip.member,tip.pinned) end
end
function P:SetBatchOffset(value,animate)
 local target=math.max(0,math.min(value,math.max(0,self.batchBody:GetHeight()-self.batchScroll:GetHeight())))
 UI.Motion:Stop(self.batchScroll);self.batchScrollTarget=target
 local function Apply(offset)
  P.batchScroll:SetVerticalScroll(offset);P.syncBatchScroll=true;P.batchSlider:SetValue(offset);P.syncBatchScroll=nil;P:RenderBatches()
 end
 if not animate or A.db.reduceMotion then Apply(target);self.batchScrollTarget=nil;return end
 local from,elapsed=self.batchScroll:GetVerticalScroll(),0
 UI.Motion:Start(self.batchScroll,function(dt)
  elapsed=math.min(.14,elapsed+dt);local p=elapsed/.14;p=1-(1-p)^3;Apply(from+(target-from)*p)
  if elapsed==.14 then P.batchScrollTarget=nil;return true end
 end)
end
function P:RenderBatches()
 local offset=self.batchScroll:GetVerticalScroll();local bound=0
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
 if self.boundAppIDs==self.appIDs and self.firstBatch==first and self.lastBatch==last then return end
 self.boundAppIDs,self.firstBatch,self.lastBatch=self.appIDs,first,last
 local canManage=UI:GetGroup():CanManageApplicants()
 for index=first or 1,last or 0 do
   local id=self.appIDs[index];local app=UI:GetGroup():GetApplicant(id);local top=self.batchTops[index];local height=self.batchTops[index+1]-top
   bound=bound+1;local f=self.batchPool[bound];if not f then f=self:BuildBatch(self.batchBody);self.batchPool[bound]=f end
   if f.appID~=id then for _,row in ipairs(f.people) do HideMemberTooltip(row) end end
   f:ClearAllPoints();f:SetPoint("TOPLEFT",0,-top);f:SetHeight(height);f:Show();f.appID=id;f.alternate=index%2==0;f.bg:SetColor(T.rowAlternate);f.bg:SetShown(f.alternate)
   local sharedY=-12
   f.comment:ClearAllPoints();f.comment:SetPoint("TOPLEFT",columns.comment.x,sharedY);f.comment:SetHeight(math.max(40,height-22));UI:SetText(f.comment,app.comment or "")
   f.invite.targetKey=id;f.decline.targetKey=id
    local actionable=canManage and app.status=="applied" and not app.pendingStatus and not app.acting
   f.invite:SetShown(actionable);f.decline:SetShown(actionable)
   UI:SetText(f.status,app.acting and L.busy or (L.states[app.pendingStatus or app.status] or ""));f.status:SetShown(not actionable)
   self:EnsureBatchMembers(f,#app.members)
   for i,row in ipairs(f.people) do
    local m=app.members[i];if row.member~=m then HideMemberTooltip(row) end;row:SetShown(m~=nil);row.member=m
    if m then row:ClearAllPoints();row:SetPoint("TOPLEFT",0,sharedY-(i-1)*MEMBER_STRIDE);UI:SetMemberIcon(row.icon,m);UI:SetText(row.title,m.nameKey or m.name and (m.name..(m.realm and "-"..m.realm or "")) or L.unknown);row.title:SetTextColor(UI:ClassColor(m.class))
     local relation=A.db.relations and m.relationship and m.relationship~="" and m.relationship or "";local note=A.db.noteMarks~=false and UI:HasNote(m.nameKey);local metadata=relation..(note and (relation~="" and " · " or "")..S("有玩家记录","Player note") or "");UI:SetText(row.meta,metadata);row.meta:SetShown(metadata~="");row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",48,metadata~="" and -4 or -16)
     UI:SetRoleIcon(row.role,m.assignedRole);UI:SetText(row.roleText,roles[m.assignedRole] or L.unknown);UI:SetText(row.ilvl,m.itemLevel and math.floor(m.itemLevel) or "—");UI:SetScore(row.score,UI:MemberRating(m))
    end
   end
 end
 for i=bound+1,#self.batchPool do local f=self.batchPool[i];f:Hide();f.appID=nil;for _,row in ipairs(f.people) do HideMemberTooltip(row);row.member=nil end end
end
function P:ApplicantAction(btn,method)
 if not btn.targetKey then return end;local ok,err=UI:GetGroup()[method](UI:GetGroup(),btn.targetKey);self:SetManageError(ok==false and (err or L.failed) or "")
end
function P:RefreshRoster()
 self.roster=UI:GetGroup():GetRoster();local indices={};for i in ipairs(self.roster) do indices[#indices+1]=i end
 local order={TANK=1,HEALER=2,DAMAGER=3,NONE=4};table.sort(indices,function(a,b) local x,y=self.roster[a],self.roster[b];local av,bv=order[x.assignedRole] or 4,order[y.assignedRole] or 4;return av==bv and a<b or av<bv end)
 UI:SetText(self.rosterCount,L.count:format(#indices));self.groupStrip:Update(self.roster,UI:MemberCounts(self.roster),30)
 local compositionX=0
 for _,item in ipairs(self.groupStrip.counts) do local width=FitText(item.text);item.icon:ClearAllPoints();item.icon:SetPoint("LEFT",compositionX,0);item.text:ClearAllPoints();item.text:SetPoint("LEFT",item.icon,"RIGHT",4,0);compositionX=compositionX+18+4+width+20 end
 self.groupStrip:SetWidth(compositionX-20)
 self.rosterList:SetItems(indices,function(row,index)
  local m=P.roster[index];if row.member~=m then HideMemberTooltip(row) end;row.member=m;UI:SetMemberIcon(row.icon,m)
  local textX=m.isLeader and 74 or 56
  UI:SetText(row.title,m.nameKey or (m.name..(m.realm and "-"..m.realm or "")));row.title:SetTextColor(UI:ClassColor(m.class));row.title:SetWidth(row:GetWidth()-textX-12);row.title:ClearAllPoints();row.title:SetPoint("TOPLEFT",textX,-12);row.meta:SetWidth(row:GetWidth()-68)
  row.leaderTag:SetShown(m.isLeader==true)
  local class=m.localizedClass or m.class and LOCALIZED_CLASS_NAMES_MALE[m.class]
  local spec=UI:SpecName(m);UI:SetText(row.meta,(class or L.unknown).." · "..(spec or L.unknown))
  row.noteDot:SetShown(A.db.noteMarks~=false and UI:HasNote(m.nameKey) or false)
 end)
 local gutter=#indices*self.rosterList.rowHeight>self.rosterList:GetHeight() and C.listRightInset or 0
 if self.rosterList.gutter~=gutter then self.rosterList:SetGutter(gutter) end
end
function P:OnNotesChanged() self:RefreshRoster();self.boundAppIDs=nil;self:RenderBatches() end
function P:Enter(context)
 local group=UI:GetGroup();group:Attach(self,"create");group:RefreshApplicants()
 if not self.unsub then self.unsub=group:Subscribe(function(kind)
  if kind=="listing" or kind=="permissions" then P:RefreshMode();P:RefreshApplicants() elseif kind=="applicants" or kind=="applicant" then P:RefreshApplicants() elseif kind=="roster" then P:RefreshRoster() elseif kind=="activities" and P.formFrame:IsShown() then P:RefreshPicker() end
 end) end
 if A.Notes and not self.notesUnsub then self.notesUnsub=A.Notes:Subscribe(function() P:OnNotesChanged() end) end
 self:RefreshRoster();self:RefreshMode();self:RefreshApplicants()
 if context and context.applicantID then for i,id in ipairs(self.appIDs) do if id==context.applicantID then self:SetBatchOffset(self.batchTops[i],false);break end end end
end
function P:Leave()
 UI.Motion:Stop(self.batchScroll);self.batchScrollTarget=nil;self.batchSlider:Hide()
 if self.unsub then self.unsub();self.unsub=nil end;if self.notesUnsub then self.notesUnsub();self.notesUnsub=nil end
 self:ClosePicker();UI.Native:ReleaseCreation();UI:GetGroup():Detach(self);self.rosterList:Clear();self.roster=nil;self.appIDs=nil;self.batchTops=nil;self:RenderBatches();UI.Tooltip:Hide()
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
