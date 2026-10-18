-- A focused UI substitute: native identity, parenting, visibility and scripts,
-- not a claim about game rendering, security/taint or protected API permissions.
local S={nodes={}}
local N={};N.__index=N
local function Fire(self,event,...) local f=self.scripts[event];if f then f(self,...) end end
function S.New(kind,name,parent)
 local n=setmetatable({kind=kind,_objectType=kind,parent=parent,children={},shown=true,enabled=true,alpha=1,points={},scripts={},hooks={},events={},text="",w=0,h=0,font={"font",14,""}},N)
 S.nodes[#S.nodes+1]=n;if parent then parent.children[#parent.children+1]=n end
 if name then _G[name]=n end
 return n
end
function N:SetScript(k,v)
 self.scripts[k]=v
 if v and (k=="OnEnter" or k=="OnLeave") then self:EnableMouse(true) end
end
function N:GetScript(k) return self.scripts[k] end
function N:HookScript(k,v)
 local previous=self.scripts[k]
 self.scripts[k]=function(self,...) if previous then previous(self,...) end;v(self,...) end
end
function N:Fire(k,...) Fire(self,k,...) end
function N:RegisterEvent(k) self.events[k]=true end
function N:UnregisterEvent(k) self.events[k]=nil end
function N:GetParent() return self.parent end
function N:GetChildren() local children={};for _,child in ipairs(self.children) do if child._objectType~="Texture" and child._objectType~="MaskTexture" and child._objectType~="FontString" then children[#children+1]=child end end;return unpack(children) end
function N:SetParent(parent) if self.parent then for i,n in ipairs(self.parent.children) do if n==self then table.remove(self.parent.children,i);break end end end;self.parent=parent;parent.children[#parent.children+1]=self end
function N:Show() local was=self.shown;self.shown=true;if not was then Fire(self,"OnShow") end end
function N:Hide() local was=self.shown;self.shown=false;if was then Fire(self,"OnHide") end end
function N:IsShown() return self.shown end
function N:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function N:IsMouseOver() return self.mouseOver==true end
function N:SetShown(v) if v then self:Show() else self:Hide() end end
function N:SetSize(w,h) local changed=self.w~=w or self.h~=h;self.w=w;self.h=h;if changed then Fire(self,"OnSizeChanged",w,h) end end
function N:SetWidth(w) self:SetSize(w,self.h) end
function N:SetHeight(h) self:SetSize(self.w,h) end
function N:GetWidth() return self.w>0 and self.w or self.parent and self.parent:GetWidth() or 0 end
function N:GetHeight() return self.h>0 and self.h or self.parent and self.parent:GetHeight() or 0 end
function N:ClearAllPoints() self.points={};self.allPoints=nil end
function N:SetPoint(...) local p={...};for i,v in ipairs(self.points) do if v[1]==p[1] then self.points[i]=p;return end end;self.points[#self.points+1]=p end
function N:GetNumPoints() return #self.points end
function N:GetPoint(i) return unpack(self.points[i or 1] or {}) end
function N:SetAllPoints(parent) self.allPoints=parent or self.parent;self.points={} end
function N:GetRight() return self:GetWidth() end
function N:GetLeft() return 0 end
function N:GetBottom() return 0 end
function N:GetTop() return self:GetHeight() end
function N:IsMouseOver() return self.mouseOver==true end
function N:UnregisterAllEvents() self.events={} end
function N:SetScale(v) self.scale=v end
function N:GetScale() return self.scale or 1 end
function N:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
function N:SetAlpha(v) self.alpha=v;if self.kind=="Texture" then self.vertex=self.vertex or {1,1,1,1};self.vertex[4]=v end end
function N:GetAlpha() return self.alpha end
function N:SetFont(...) self.font={...};if self._objectType~="Font" then return true end end
function N:GetFont() return unpack(self.font) end
function N:GetLineHeight() assert(self._objectType=="FontString","GetLineHeight belongs to FontString");return (self.font[2] or 14)*1.2 end
function N:GetShadowOffset() return unpack(self.shadowOffset or {0,0}) end
function N:SetText(v) assert(not self.secureText,"addon SetText on protected text");self.text=tostring(v);Fire(self,"OnTextChanged",false) end
function N:UserType(v) self.text=v;Fire(self,"OnTextChanged",true) end
function N:GetText() return self.text end
function N:GetStringWidth()
 local width=0
 for ch in self.text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do width=width+(#ch>1 and 1 or .55)*(self.font[2] or 14) end
 return width
end
function N:GetStringHeight()
 local lines=0
 for line in (self.text.."\n"):gmatch("(.-)\n") do
  local count=0;for ch in line:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do count=count+(#ch>1 and 1 or .55) end
  lines=lines+math.max(1,self.wrap and math.ceil(count*(self.font[2] or 14)/math.max(1,self.w)) or 1)
 end
 if self.maxLines then lines=math.min(lines,self.maxLines) end
 return lines*((self.font[2] or 14)*1.2+(self.spacing or 0))
end
function N:SetSpacing(v) self.spacing=v end
function N:GetSpacing() return self.spacing or 0 end
function N:SetMaxLines(v) self.maxLines=v end
function N:SetTextColor(...) self.color={...} end
function N:GetTextColor() return unpack(self.color or {1,1,1,1}) end
function N:GetObjectType() return self._objectType end
function N:GetRegions() local regions={};for _,child in ipairs(self.children) do if child._objectType=="Texture" or child._objectType=="FontString" then regions[#regions+1]=child end end;return unpack(regions) end
function N:SetColorTexture(...) self.fill={...} end
function N:SetDrawLayer(layer,sublevel) self.layer=layer;self.sublevel=sublevel end
function N:GetDrawLayer() return self.layer,self.sublevel or 0 end
function N:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a or 1};self.alpha=a or 1 end
function N:SetRotation(radians) self.rotation=radians end
function N:SetTexture(v) self.texture=v;self.atlas=nil end
function N:GetTexture() return self.texture end
function N:SetAtlas(v) self.atlas=v;self.texture=nil end
function N:GetAtlas() return self.atlas end
function N:SetTexCoord(...) self.texCoords={...} end
function N:SetJustifyH(v) self.justify=v end
function N:SetJustifyV(v) self.justifyV=v end
function N:SetWordWrap(v) self.wrap=v end
function N:SetFrameLevel(v) self.level=v end
function N:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1 or 0) end
function N:SetEnabled(v) self.enabled=v end
function N:IsEnabled() return self.enabled end
function N:Enable() self:SetEnabled(true) end
function N:Disable() self:SetEnabled(false) end
function N:SetFocus() self.focus=true;Fire(self,"OnEditFocusGained") end
function N:ClearFocus() if self.focus then self.focus=false;Fire(self,"OnEditFocusLost") end end
function N:HasFocus() return self.focus==true end
function N:SetChecked(v) self.checked=v end
function N:GetChecked() return self.checked end
function N:SetValue(v) self.value=v;Fire(self,"OnValueChanged",v) end
function N:GetValue() return self.value or 0 end
function N:GetMinMaxValues() return self.min,self.max end
function N:SetMinMaxValues(a,b) self.min=a;self.max=b end
function N:GetVerticalScroll() return self.scroll or 0 end
function N:SetVerticalScroll(v) self.scroll=v end
function N:GetVerticalScrollRange() return 100 end
function N:SetScrollChild(v) self.scrollChild=v end
function N:CreateMaskTexture(name,layer) local mask=S.New("MaskTexture",name,self);mask.layer=layer;return mask end
function N:AddMaskTexture(mask) self.mask=mask end
function N:RemoveMaskTexture(mask) if self.mask==mask then self.mask=nil end end
function N:SetDesaturated(value) self.desaturated=value end
function N:CreateTexture(name,layer) local n=S.New("Texture",name,self);n.layer=layer;return n end
function N:CreateFontString(name,layer) local n=S.New("FontString",name,self);n.layer=layer;return n end
function N:SetBackdropColor(...) self.backdropColor={...} end
for _,k in ipairs({"SetMovable","RegisterForDrag","StartMoving","StopMovingOrSizing","SetMaxLetters","SetMultiLine","SetAutoFocus","SetBackdrop","SetBackdropBorderColor","SetCursorPosition","HighlightText","SetNumeric","SetTextInsets","RegisterForClicks","EnableMouse","EnableMouseWheel","EnableKeyboard","SetPropagateKeyboardInput","SetPropagateMouseClicks","SetPropagateMouseMotion","SetOrientation","SetValueStep","SetObeyStepOnDrag","SetThumbTexture","SetFrameStrata","SetClampedToScreen","SetHitRectInsets"}) do N[k]=function() end end
function N:SetShadowOffset(x,y) self.shadowOffset={x,y} end
function N:SetTextInsets(...) self.textInsets={...} end
function N:GetTextInsets() return unpack(self.textInsets or {0,0,0,0}) end

function N:SetFrameStrata(value) self.strata=value end
function N:GetFrameStrata() return self.strata or "MEDIUM" end
function N:EnableMouse(value) self.mouseEnabled=value;self.mouseMotionEnabled=value end
function N:EnableMouseMotion(value) self.mouseMotionEnabled=value end
function N:IsMouseEnabled() return self.mouseEnabled==true end
function N:EnableKeyboard(value) self.keyboardEnabled=value end
function N:SetPropagateKeyboardInput(value)
 assert(not InCombatLockdown(),"keyboard propagation is configured outside combat")
 self.keyboardPropagation=value
end
function N:SetPropagateMouseClicks(value)
 assert(not InCombatLockdown(),"mouse click propagation is protected in combat")
 self.mouseClickPropagation=value
end
function N:SetPropagateMouseMotion(value)
 assert(not InCombatLockdown(),"mouse motion propagation is protected in combat")
 self.mouseMotionPropagation=value
end
function S.Install()
 S.nodes={}
 _G.CreateFrame=S.New
 _G.CreateFont=function(name) return S.New("Font",name) end
 _G.UIParent=S.New("Frame");UIParent:SetSize(1920,1080)
 _G.UISpecialFrames={};_G.InCombatLockdown=function() return false end
 S.bindings={};S.bindingOrder={};S.bindingSaves={};S.bindingScope=1;S.bindingModifiers={}
 _G.C_KeyBindings={GetBindingContextForAction=function() return 0 end}
 _G.GetBindingKey=function(action)
  local keys={};for _,key in ipairs(S.bindingOrder) do if S.bindings[key]==action then keys[#keys+1]=key end end;return unpack(keys)
 end
 _G.GetBindingAction=function(key) return S.bindings[key] or "" end
 _G.GetBindingText=function(key) return key end
 _G.GetBindingName=function(action) return _G["BINDING_NAME_"..action] or action end
 _G.GetCurrentBindingSet=function() return S.bindingScope end
 _G.SetBinding=function(key,action)
  for i=#S.bindingOrder,1,-1 do if S.bindingOrder[i]==key then table.remove(S.bindingOrder,i) end end
  S.bindings[key]=action;if action then S.bindingOrder[#S.bindingOrder+1]=key end;return true
 end
 _G.SaveBindings=function(scope) S.bindingSaves[#S.bindingSaves+1]=scope end
 _G.GetConvertedKeyOrButton=function(key) return key=="SEMICOLON" and ";" or key end
 _G.IsKeyPressIgnoredForBinding=function(key) return key=="LCTRL" or key=="RCTRL" or key=="LALT" or key=="RALT" or key=="LSHIFT" or key=="RSHIFT" end
 _G.CreateKeyChordStringUsingMetaKeyState=function(key)
  local mods=S.bindingModifiers;return (mods.ctrl and "CTRL-" or "")..(mods.alt and "ALT-" or "")..(mods.shift and "SHIFT-" or "")..key
 end
 _G.STANDARD_TEXT_FONT="font"
 _G.LOCALIZED_CLASS_NAMES_MALE={WARRIOR="战士",PALADIN="圣骑士",PRIEST="牧师",MAGE="法师",DRUID="德鲁伊"}
 _G.GetTime=function() return 0 end
 S.preciseNow=0;_G.GetTimePreciseSec=function() return S.preciseNow end
 _G.CLASS_ICON_TCOORDS={WARRIOR={0,.25,0,.25},PALADIN={0,.25,.5,.75},MAGE={.25,.5,0,.25},PRIEST={.5,.75,.25,.5}}
 _G.GetSpecializationInfoByID=function(id) return id,"Specialization",nil,136096 end
 _G.C_Texture={GetAtlasInfo=function() return nil end}
 _G.C_EncounterJournal={GetInstanceForGameMap=function() return nil end}
 _G.GameTooltip=S.New("Tooltip",nil,UIParent)
 function GameTooltip:SetOwner(owner) self.owner=owner;self.lines={} end
 function GameTooltip:IsOwned(owner) return self.owner==owner end
 function GameTooltip:AddLine(...) self.lines[#self.lines+1]={...} end
 _G.date=os.date
 _G.Enum={LFGEntryGeneralPlaystyle={None=0,Learning=1,FunRelaxed=2,FunSerious=3,Expert=4},LFGEntryPlaystyle={None=0},LFGListFilter={CurrentSeason=64,NotCurrentSeason=128,Recommended=1,NotRecommended=2,PvE=4}}
 _G.GetGeneralPlaystyleString=nil
 _G.GROUP_FINDER_GENERAL_PLAYSTYLE1="Learning";_G.GROUP_FINDER_GENERAL_PLAYSTYLE2="Fun relaxed";_G.GROUP_FINDER_GENERAL_PLAYSTYLE3="Fun serious";_G.GROUP_FINDER_GENERAL_PLAYSTYLE4="Expert"
 _G.InputBoxInstructions_OnTextChanged=function() end
 _G.IsActivityLockedForCustomText=function() return false end
 _G.GetDifficultyInfo=function(id) return "Difficulty "..id end
 _G.GetAverageItemLevel=function() return 650,640,660 end
 _G.IsInRaid=function() return false end
 _G.IsShiftKeyDown=function() return false end
 S.cursorX,S.cursorY=960,540
 _G.GetCursorPosition=function() return S.cursorX,S.cursorY end
 _G.EJ_GetCurrentTier=function() return 1 end
 _G.EJ_GetNumTiers=function() return 1 end
 _G.EJ_GetTierInfo=function() return "Test expansion" end
 _G.EJ_SelectTier=function() end
 _G.EJ_GetInstanceByIndex=function() return nil end
 _G.bit={bor=function(a,b) return a+b end}
 _G.C_ChallengeMode={GetDungeonScoreRarityColor=function() return {r=.2,g=.7,b=.9,WrapTextInColorCode=function(_,text) return "|cff33b3e6"..text.."|r" end} end,GetKeystoneLevelRarityColor=function() return {r=1,g=.5,b=0} end}
 _G.C_AddOns={LoadAddOn=function() return true end,IsAddOnLoaded=function() return true end}
 _G.LFGListFrame=S.New("Frame",nil,UIParent)
 local searchPanel=S.New("Frame",nil,LFGListFrame);searchPanel:Hide();LFGListFrame.SearchPanel=searchPanel
 local searchBox=S.New("EditBox",nil,searchPanel);searchPanel.SearchBox=searchBox;searchBox.secureText=true
 searchBox:SetSize(319,18);searchBox:SetPoint("TOPLEFT",searchPanel,"TOPLEFT",4,-58);searchBox:SetTextInsets(2,3,1,2)
 searchBox.Instructions=searchBox:CreateFontString(nil,"OVERLAY");searchBox.Instructions:SetText("Native search instructions")
 searchBox.clearButton=S.New("Button",nil,searchBox)
 searchBox.nativeBackground=searchBox:CreateTexture(nil,"BACKGROUND");searchBox.nativeBackground:SetTexture(123);searchBox.nativeBackground:SetAllPoints()
 searchPanel.AutoCompleteFrame=S.New("Frame",nil,searchPanel)
 searchBox:SetScript("OnTextChanged",function(box) assert(box:GetParent()==searchPanel,"native SearchBox parent contract");box.Instructions:SetShown(box:GetText()=="") end)
 searchBox:SetScript("OnEditFocusGained",function(box) assert(box:GetParent()==searchPanel,"native search focus parent contract") end)
 local e=S.New("Frame",nil,LFGListFrame);LFGListFrame.EntryCreation=e
 e.Name=S.New("EditBox",nil,e);e.Name:SetSize(288,22);e.Name.secureText=true
 e.Description=S.New("ScrollFrame",nil,e);e.Description:SetSize(283,46)
 e.Description.EditBox=S.New("EditBox",nil,e.Description);e.Description.EditBox.secureText=true
 for _,key in ipairs({"ItemLevel","MythicPlusRating","PVPRating","PvpItemLevel"}) do e[key]=S.New("Frame",nil,e);e[key].EditBox=S.New("EditBox",nil,e[key]) end
 e.ListGroupButton=S.New("Button",nil,e)
 e.Name:SetScript("OnTextChanged",function(box) assert(box:GetParent()==e,"native Name parent contract") end)
 _G.LFGListEntryCreation_Select=function(entry,_,category,_,activity) entry.selectedCategory=category;entry.selectedActivity=activity end
 _G.LFGListEntryCreation_OnPlayStyleSelectedInternal=function(entry,value) entry.generalPlaystyle=value end
 _G.LFGListEntryCreation_UpdateValidState=function(entry)
  local err=entry.Name:GetText()=="" and "A group title is required" or entry.ItemLevel.warningText or entry.PvpItemLevel.warningText or entry.MythicPlusRating.warningText or entry.PVPRating.warningText
  entry.ListGroupButton.errorText=err;entry.ListGroupButton:SetEnabled(not err)
 end
 _G.LFGListRequirement_Validate=function(requirement,text)
  if requirement.validateFunc then requirement.warningText=requirement:validateFunc(text) end
  LFGListEntryCreation_UpdateValidState(requirement:GetParent())
 end
 _G.LFGListApplicationDialog=S.New("Frame",nil,UIParent);LFGListApplicationDialog:Hide()
 _G.LFGListApplicationDialog_Show=function(dialog,id) dialog.resultID=id;dialog:Show() end
 return S
end
return S
