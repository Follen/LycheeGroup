local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
local function RGB(hex,alpha)
 return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,alpha or 1}
end
local function WhiteState(color,alpha)
 return {color[1]+(1-color[1])*alpha,color[2]+(1-color[2])*alpha,color[3]+(1-color[3])*alpha,1}
end
local T={
 font12=12,font13=13,font14=14,font15=15,font16=16,font17=17,font18=18,font20=20,font24=24,
 line14=14,line16=16,line18=18,line19=19,line20=20,line21=21,line22=22,line24=24,line28=28,line32=32,
 disabledAlpha=.38,iconIdleAlpha=.72,iconHoverAlpha=.9,iconIdleTint=.9,iconHoverTint=.98,
 feedbackDuration=.12,selectionDuration=.10,buttonSelectionDuration=.14,selectionMoveDuration=.16,
 revealDuration=.18,menuRevealDuration=.16,menuRevealOffset=8,scrollDuration=.14,switchDuration=.18,
 presenceDuration=.42,presenceFadeDuration=.10,presenceOffset=64,
 spinPeriod=.9,busyPeriod=.9,busyAlpha=.35,waitingPeriod=1.2,waitingAlpha=.65,
 waitingWidth=.035,waitingHeight=.025,waitingOffset=3,brandDuration=1.386,
 buttonWidth=100,buttonFontSize=14,buttonLineHeight=20,
 iconButtonSize=20,checkboxSize=32,checkboxBoxSize=18,checkboxRadius=5,
 switchKnobSize=16,switchActiveKnobSize=20,switchInset=5,switchActiveX=21,switchLabelX=56,switchRadius=13,
 scrollbarThumbHeight=28,selectionRadius=8,selectionMarkWidth=3,selectionMarkInset=4,
 listRowHeight=64,listRadius=12,listTextInset=12,listTextTop=8,listTextReserve=48,listDotSize=6,
 tableHeight=24,tablePadding=6,tableHandleWidth=10,tableLineHeight=10,tableLineWidth=1,tableActiveLineWidth=2,tableIdleAlpha=.22,tableHoverAlpha=.7,
 searchRadius=24,fieldRing=1,editInset=12,editVerticalInset=4,editMultilineInset=10,editScrollStep=28,
 choiceInset=14,choiceReserve=46,choiceArrowWidth=5,choiceArrowThickness=1.5,choiceArrowOuter=20,choiceArrowInner=16,
 sliderHeight=40,sliderHitHeight=24,sliderTrackHeight=4,sliderTrackRadius=2,sliderThumbWidth=8,sliderThumbHeight=12,
 segmentPadding=3,segmentGap=4,segmentRadius=8,segmentTextInset=6,
 navigationHeight=48,navigationRadius=24,navigationFontSize=16,navigationLineHeight=22,
 navigationInset=16,navigationIconTextInset=52,roleButtonIconSize=20,roleButtonInset=16,roleButtonGap=8,roleButtonReserve=60,
 menuPadding=4,menuRowHeight=40,menuMaxHeight=400,menuMinWidth=216,menuFontSize=16,menuLineHeight=22,menuTextInset=12,menuIconInset=12,menuIconSize=20,menuSelectInset=32,menuIconTextInset=40,menuScreenInset=16,
 menuScreenReserve=48,menuPopupGap=8,menuCursorOffset=4,menuCheckInset=8,checkMarkWidth=16,checkMarkHeight=20,
 tooltipWidth=300,tooltipPadding=16,tooltipBottom=12,tooltipLineGap=4,tooltipOffset=8,tooltipFontSize=12,tooltipLineHeight=18,
 modalWidth=480,modalHeight=300,modalPadding=24,modalContentTop=80,modalTitleReserve=96,modalCloseSize=40,modalScrimAlpha=.48,modalScrim={0,0,0,.48},shadowExtent=24,
 noticeHeight=40,noticeRadius=12,noticeInset=12,noticeTextReserve=52,noticeVerticalPadding=16,noticeCloseSize=24,noticeCloseInset=8,
 nativeFontSize=14,nativeButtonMinWidth=96,nativeButtonPadding=40,nativeButtonHeight=40,nativeButtonRadius=20,
 rosterSize=23,rosterGap=5,rosterRoleSize=10,rosterCountIconSize=18,rosterCountStride=44,rosterCountTextWidth=22,rosterCountGap=3,
 surface=RGB("181818"),surfaceLow=RGB("242424"),surfaceContainer=RGB("2C2C2C"),
 surfaceHigh=RGB("343434"),
 primary=RGB("C84353"),primaryHover=RGB("C84B59"),primaryPressed=RGB("AD3745"),onPrimary=RGB("FFFFFF"),
 primaryContainer=RGB("35282A"),onPrimaryContainer=RGB("F5F5F5"),
 secondaryContainer=RGB("444444"),onSecondaryContainer=RGB("F5F5F5"),
 outline=RGB("707070"),outlineVariant=RGB("484848"),
 text=RGB("F0F0F0"),muted=RGB("C4C4C4"),dim=RGB("A6A6A6"),brand=RGB("E87983"),
 good=RGB("A8D5BA"),warning=RGB("E6C48B"),blue=RGB("AAC7FF"),
 rowAlternate={1,1,1,3/255},rowHover={1,1,1,13/255},pressed={1,1,1,20/255},
 selectHover={0,0,0,.18},selectPressed={0,0,0,.26},
 transparent={0,0,0,0},disabled=RGB("777777"),
 floatingSurface={0,0,0,.60},floatingHover={.04,.04,.04,.66},
 positiveHover={.47,.8,.69,.14},positivePressed={.47,.8,.69,.22},
 negativeHover={.94,.35,.4,.14},negativePressed={.94,.35,.4,.22},
 font=STANDARD_TEXT_FONT,width=1160,height=840,headerHeight=72,
 contentWidth=1128,contentHeight=752,logoSize=44,pageInset=16,mainInset=24,
 sidebarWidth=208,gap=16,contentGap=16,navGap=32,
 railRowHeight=48,railFontSize=14,railIconSize=24,selectionMarkHeight=18,
 buttonHeight=40,fieldHeight=44,fieldRadius=4,buttonRadius=20,
 panelRadius=24,windowRadius=28,menuRadius=12,tooltipRadius=16,
 segmentHeight=36,segmentItemHeight=30,switchWidth=44,switchHeight=26,
 compactHeight=30,compactRadius=8,compactSize=13,compactLineHeight=20,floatingRadius=16,
 scrollWidth=6,scrollGap=12,iconCrop=.06,iconRadius=.22,
 bodySize=14,metaSize=14,titleSize=24,headingSize=18,
 fontSizeDelta=0,lineHeightDelta=0,
 listTitleSize=18,listTitleLineHeight=24,listMetaSize=14,listMetaLineHeight=20,
 media=Library.media,
}
-- These are composited interaction results, never additional resting surfaces.
T.surfaceHighest=WhiteState(T.surfaceHigh,T.rowHover[4])
T.surfaceLowHover=WhiteState(T.surfaceLow,T.rowHover[4])
T.surfaceLowPressed=WhiteState(T.surfaceLow,T.pressed[4])
T.refreshHover=WhiteState(T.secondaryContainer,T.rowHover[4])
T.secondaryPressed=WhiteState(T.secondaryContainer,T.pressed[4])
T.bg=T.surface;T.panel=T.surfaceContainer;T.field=T.surfaceHigh;T.fieldFocus=T.surfaceHigh
T.raised=T.surfaceHigh;T.hover=T.surfaceHighest;T.surfaceHover=T.rowHover
T.accent=T.primary;T.selected=T.secondaryContainer;T.border=T.outlineVariant
T.focusBorder=T.brand;T.notice=T.primaryContainer;T.noticeText=T.onPrimaryContainer
T.selectBackground=T.surface
Library.Theme=T
Library.RGB=RGB
-- Resolve once per context. Explicit tokens win over aliases and derived states.
function Library.ResolveTheme(overrides,extraDefaults)
 local theme={}
 for key,value in pairs(T) do theme[key]=value end
 for key,value in pairs(extraDefaults or {}) do theme[key]=value end
 for key,value in pairs(overrides or {}) do theme[key]=value end
 for key,value in pairs(theme) do if type(value)=="table" and #value==3 then theme[key]={value[1],value[2],value[3],1} end end
 local typography={bodySize="font14",metaSize="font14",titleSize="font24",headingSize="font18",compactSize="font13",compactLineHeight="line20",
  listTitleSize="font18",listTitleLineHeight="line24",listMetaSize="font14",listMetaLineHeight="line20",buttonFontSize="font14",buttonLineHeight="line20",
  navigationFontSize="font16",navigationLineHeight="line22",menuFontSize="font16",menuLineHeight="line22",tooltipFontSize="font12",tooltipLineHeight="line18",nativeFontSize="font14"}
 for key,source in pairs(typography) do if (not overrides or overrides[key]==nil) and (not extraDefaults or extraDefaults[key]==nil) then theme[key]=theme[source] end end
 if (not overrides or overrides.modalScrim==nil) and (not extraDefaults or extraDefaults.modalScrim==nil) and theme.modalScrimAlpha~=T.modalScrimAlpha then theme.modalScrim={0,0,0,theme.modalScrimAlpha} end
 local function State(key,base,layer)
  if overrides and overrides[key]~=nil or extraDefaults and extraDefaults[key]~=nil then return end
  if theme[base]~=T[base] or theme[layer]~=T[layer] then theme[key]=WhiteState(theme[base],theme[layer][4]) end
 end
 State("surfaceHighest","surfaceHigh","rowHover")
 State("surfaceLowHover","surfaceLow","rowHover")
 State("surfaceLowPressed","surfaceLow","pressed")
 State("refreshHover","secondaryContainer","rowHover")
 State("secondaryPressed","secondaryContainer","pressed")
 local aliases={bg="surface",panel="surfaceContainer",field="surfaceHigh",fieldFocus="surfaceHigh",
  raised="surfaceHigh",hover="surfaceHighest",surfaceHover="rowHover",accent="primary",
  selected="secondaryContainer",border="outlineVariant",focusBorder="brand",notice="primaryContainer",
  noticeText="onPrimaryContainer",selectBackground="surface"}
 for key,source in pairs(aliases) do
  if (not overrides or overrides[key]==nil) and (not extraDefaults or extraDefaults[key]==nil) then theme[key]=theme[source] end
 end
 return theme
end
local function Kind(value) return type(value)=="table" and "color" or type(value) end
local function Field(key,value)
 local field={type=Kind(value),default=value}
 if field.type=="number" then
  if key:match("^font%d+$") or key:match("^line%d+$") or key:match("FontSize$") or key:match("LineHeight$") or key=="bodySize" or key=="metaSize" or key=="titleSize" or key=="headingSize" or key=="compactSize" or key=="listTitleSize" or key=="listMetaSize" then field.min=0;field.exclusiveMin=true;field.unit=key:lower():find("line") and "line" or "font"
  elseif key:match("Alpha$") or key:match("Tint$") then field.min,field.max=0,1
  elseif T[key]~=nil and not key:match("Delta$") and (key:match("[Ww]idth$") or key:match("[Hh]eight$") or key:match("[Rr]adius$") or key:match("[Ss]ize$") or key:match("[Ii]nset$") or key:match("Padding$") or key:match("Gap$") or key:match("Extent$") or key:match("Reserve$") or key:match("Thickness$")) then field.min=0
  elseif key:match("Period$") then field.min=0;field.exclusiveMin=true
  elseif key:match("Duration$") then field.min=0 end
 end
 return field
end
function Library:GetThemeSchema(extraDefaults)
 local schema={}
 for key,value in pairs(T) do schema[key]=Field(key,value) end
 for key,value in pairs(extraDefaults or {}) do schema[key]=Field(key,value) end
 return schema
end
function Library:ValidateTheme(values,extraDefaults)
 if type(values)~="table" then return false,"theme must be a table" end
 local schema=self:GetThemeSchema(extraDefaults)
 for key,value in pairs(values) do
  local field=schema[key]
  if not field then return false,"unknown theme token: "..tostring(key) end
  if field.type=="color" then
   if type(value)~="table" or #value<3 or #value>4 then return false,"invalid color token: "..key end
   for i=1,#value do if type(value[i])~="number" or value[i]~=value[i] or value[i]<0 or value[i]>1 then return false,"invalid color channel: "..key end end
  elseif type(value)~=field.type or field.type=="number" and (value~=value or value==math.huge or value==-math.huge) then return false,"invalid "..field.type.." token: "..key
  elseif field.type=="number" and (field.min and (value<field.min or field.exclusiveMin and value==field.min) or field.max and value>field.max) then return false,"out-of-range token: "..key end
 end
 local resolved=self.ResolveTheme(values,extraDefaults)
 for key,field in pairs(schema) do if field.unit then
  local delta=field.unit=="font" and resolved.fontSizeDelta or resolved.lineHeightDelta
  if resolved[key]+delta<=0 then return false,"effective text size must be positive: "..key end
 end end
 return true
end
