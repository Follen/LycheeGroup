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
 captionFontSize=12,captionLineHeight=16,labelFontSize=14,labelLineHeight=20,
 bodyFontSize=16,bodyLineHeight=22,titleFontSize=18,titleLineHeight=24,headingFontSize=24,headingLineHeight=32,
 disabledAlpha=.38,iconIdleAlpha=.72,iconHoverAlpha=.9,iconIdleTint=.9,iconHoverTint=.98,
 actionHoverAlpha=.14,actionPressedAlpha=.22,
 feedbackDuration=.12,selectionDuration=.10,buttonSelectionDuration=.14,selectionMoveDuration=.16,
 revealDuration=.18,menuRevealDuration=.16,menuRevealOffset=8,scrollDuration=.14,switchDuration=.18,
 presenceDuration=.42,presenceFadeDuration=.10,presenceOffset=64,
 spinPeriod=.9,busyPeriod=.9,busyAlpha=.35,waitingPeriod=1.2,waitingAlpha=.65,
 waitingWidth=.035,waitingHeight=.025,waitingOffset=3,
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
 navigationInset=16,navigationIconTextInset=52,
 menuPadding=4,menuRowHeight=40,menuMaxHeight=400,menuMinWidth=216,menuFontSize=16,menuLineHeight=22,menuTextInset=12,menuIconInset=12,menuIconSize=20,menuSelectInset=32,menuIconTextInset=40,menuScreenInset=16,
 menuScreenReserve=48,menuPopupGap=8,menuCursorOffset=4,menuCheckInset=8,checkMarkWidth=16,checkMarkHeight=20,
 tooltipWidth=300,tooltipPadding=16,tooltipBottom=12,tooltipLineGap=4,tooltipOffset=8,tooltipFontSize=12,tooltipLineHeight=18,
 modalWidth=480,modalHeight=300,modalPadding=24,modalContentTop=80,modalTitleReserve=96,modalCloseSize=40,modalScrimAlpha=.48,modalScrim={0,0,0,.48},shadowExtent=24,
 noticeHeight=40,noticeRadius=12,noticeInset=12,noticeTextReserve=52,noticeVerticalPadding=16,noticeCloseSize=24,noticeCloseInset=8,
 nativeFontSize=14,nativeButtonMinWidth=96,nativeButtonPadding=40,nativeButtonHeight=40,nativeButtonRadius=20,
 surface=RGB("181818"),surfaceLow=RGB("242424"),surfaceContainer=RGB("2C2C2C"),
 surfaceHigh=RGB("343434"),
 primary=RGB("C84353"),onPrimary=RGB("FFFFFF"),
 primaryContainer=RGB("35282A"),onPrimaryContainer=RGB("F5F5F5"),
 secondaryContainer=RGB("444444"),onSecondaryContainer=RGB("F5F5F5"),
 outline=RGB("707070"),outlineVariant=RGB("484848"),
 text=RGB("F0F0F0"),muted=RGB("C4C4C4"),dim=RGB("A6A6A6"),brand=RGB("E87983"),
 good=RGB("A8D5BA"),warning=RGB("E6C48B"),blue=RGB("AAC7FF"),
 rowAlternate={1,1,1,3/255},rowHover={1,1,1,13/255},pressed={1,1,1,20/255},
 selectHover={0,0,0,.18},selectPressed={0,0,0,.26},
 transparent={0,0,0,0},disabled=RGB("777777"),
 floatingSurface={0,0,0,.60},
 font=STANDARD_TEXT_FONT,gap=16,
 railIconSize=24,selectionMarkHeight=18,
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
local TextStyles={
 caption={fontSize="captionFontSize",lineHeight="captionLineHeight"},label={fontSize="labelFontSize",lineHeight="labelLineHeight"},
 body={fontSize="bodyFontSize",lineHeight="bodyLineHeight"},title={fontSize="titleFontSize",lineHeight="titleLineHeight"},heading={fontSize="headingFontSize",lineHeight="headingLineHeight"},
}
local TypographyAliases={
 captionFontSize={role="caption",unit="font",representative="font12",aliases={"font12"}},
 labelFontSize={role="label",unit="font",representative="font14",aliases={"font14","font13","font15"}},
 bodyFontSize={role="body",unit="font",representative="font16",aliases={"font16"}},
 titleFontSize={role="title",unit="font",representative="font18",aliases={"font18","font17","font20"}},
 headingFontSize={role="heading",unit="font",representative="font24",aliases={"font24"}},
 captionLineHeight={role="caption",unit="line",representative="line16",aliases={"line16","line14"}},
 labelLineHeight={role="label",unit="line",representative="line20",aliases={"line20","line18","line19"}},
 bodyLineHeight={role="body",unit="line",representative="line22",aliases={"line22","line21"}},
 titleLineHeight={role="title",unit="line",representative="line24",aliases={"line24","line28"}},
 headingLineHeight={role="heading",unit="line",representative="line32",aliases={"line32"}},
}
local typography={bodySize="labelFontSize",metaSize="labelFontSize",titleSize="headingFontSize",headingSize="titleFontSize",compactSize="labelFontSize",compactLineHeight="labelLineHeight",
 listTitleSize="titleFontSize",listTitleLineHeight="titleLineHeight",listMetaSize="labelFontSize",listMetaLineHeight="labelLineHeight",buttonFontSize="labelFontSize",buttonLineHeight="labelLineHeight",
 navigationFontSize="bodyFontSize",navigationLineHeight="bodyLineHeight",menuFontSize="bodyFontSize",menuLineHeight="bodyLineHeight",tooltipFontSize="captionFontSize",tooltipLineHeight="captionLineHeight",nativeFontSize="labelFontSize"}
for canonical,group in pairs(TypographyAliases) do for _,alias in ipairs(group.aliases) do T[alias]=T[canonical] end end
for key,source in pairs(typography) do T[key]=T[source] end
Library.TextStyles,Library.TypographyAliases=TextStyles,TypographyAliases
local colorAliases={bg="surface",panel="surfaceContainer",field="surfaceHigh",fieldFocus="surfaceHigh",
 raised="surfaceHigh",hover="surfaceHighest",surfaceHover="rowHover",accent="primary",
 selected="secondaryContainer",border="outlineVariant",focusBorder="brand",notice="primaryContainer",
 noticeText="onPrimaryContainer",selectBackground="surface"}
local colorStates={
 surfaceHighest={"surfaceHigh","rowHover","white"},surfaceLowHover={"surfaceLow","rowHover","white"},surfaceLowPressed={"surfaceLow","pressed","white"},
 refreshHover={"secondaryContainer","rowHover","white"},secondaryPressed={"secondaryContainer","pressed","white"},
 primaryHover={"primary","rowHover","white"},primaryPressed={"primary","pressed","black"},
 positiveHover={"good","actionHoverAlpha","tint"},positivePressed={"good","actionPressedAlpha","tint"},
 negativeHover={"primary","actionHoverAlpha","tint"},negativePressed={"primary","actionPressedAlpha","tint"},
 floatingHover={"floatingSurface","rowHover","floating","actionHoverAlpha"},
}
local function StateColor(theme,source)
 local color,alpha=theme[source[1]],theme[source[2]]
 alpha=type(alpha)=="table" and alpha[4] or alpha
 if source[3]=="white" then return WhiteState(color,alpha)
 elseif source[3]=="floating" then local result=WhiteState(color,alpha);local baseAlpha=color[4] or 1;result[4]=baseAlpha+(1-baseAlpha)*theme[source[4]];return result
 elseif source[3]=="black" then return {color[1]*(1-alpha),color[2]*(1-alpha),color[3]*(1-alpha),color[4] or 1}
 else return {color[1],color[2],color[3],alpha} end
end
-- These are composited interaction results, never additional resting surfaces.
for key,source in pairs(colorStates) do T[key]=StateColor(T,source) end
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
 for canonical,group in pairs(TypographyAliases) do
  local value
  for _,source in ipairs({overrides or {},extraDefaults or {}}) do
   value=source[canonical]
   if value==nil then for _,alias in ipairs(group.aliases) do if source[alias]~=nil then value=source[alias];break end end end
   if value~=nil then break end
  end
  theme[canonical]=value or T[canonical]
  for _,alias in ipairs(group.aliases) do theme[alias]=theme[canonical] end
 end
 for key,source in pairs(typography) do if (not overrides or overrides[key]==nil) and (not extraDefaults or extraDefaults[key]==nil) then theme[key]=theme[source] end end
 if (not overrides or overrides.modalScrim==nil) and (not extraDefaults or extraDefaults.modalScrim==nil) and theme.modalScrimAlpha~=T.modalScrimAlpha then theme.modalScrim={0,0,0,theme.modalScrimAlpha} end
 local function State(key,source)
  if overrides and overrides[key]~=nil or extraDefaults and extraDefaults[key]~=nil then return end
  if theme[source[1]]~=T[source[1]] or theme[source[2]]~=T[source[2]] or source[4] and theme[source[4]]~=T[source[4]] then theme[key]=StateColor(theme,source) end
 end
 for key,source in pairs(colorStates) do State(key,source) end
 for key,source in pairs(colorAliases) do
  if (not overrides or overrides[key]==nil) and (not extraDefaults or extraDefaults[key]==nil) then theme[key]=theme[source] end
 end
 return theme
end
local function Kind(value) return type(value)=="table" and "color" or type(value) end
local function CopyArray(value) return value and {unpack(value)} or nil end
local paletteColors={surface=true,surfaceLow=true,surfaceContainer=true,surfaceHigh=true,secondaryContainer=true,outline=true,outlineVariant=true,transparent=true,floatingSurface=true}
local textColors={text=true,muted=true,dim=true,disabled=true,onPrimary=true,onPrimaryContainer=true,onSecondaryContainer=true}
local function Field(key,value,validation)
 local field=validation or {key=key,type=Kind(value),default=type(value)=="table" and CopyArray(value) or value}
 if validation then field.type=Kind(value);field.min,field.max,field.exclusiveMin,field.unit=nil,nil,nil,nil end
 if field.type=="number" then
  if key~="tableLineHeight" and (key:match("^font%d+$") or key:match("^line%d+$") or key:match("FontSize$") or key:match("LineHeight$") or key:match("Font$") or key:match("Line$") or key=="bodySize" or key=="metaSize" or key=="titleSize" or key=="headingSize" or key=="compactSize" or key=="listTitleSize" or key=="listMetaSize") then field.min=0;field.exclusiveMin=true;field.unit=(key:match("^line%d+$") or key:match("LineHeight$") or key:match("Line$")) and "line" or "font"
  elseif key:match("Alpha$") or key:match("Tint$") then field.min,field.max=0,1
  elseif not key:match("Delta$") and (key:match("[Ww]idth%d*$") or key:match("[Hh]eight%d*$") or key:match("[Rr]adius%d*$") or key:match("[Ss]ize%d*$") or key:match("[Ii]nset%d*$") or key:match("Padding%d*$") or key:match("Gap%d*$") or key:match("Extent%d*$") or key:match("Reserve%d*$") or key:match("Thickness%d*$")) then field.min=0
  elseif key:match("Period$") then field.min=0;field.exclusiveMin=true
  elseif key:match("Duration$") then field.min=0 end
  -- These heights are also row strides and divisors in virtualized lists.
  if key=="listRowHeight" or key=="menuRowHeight" then field.min=0;field.exclusiveMin=true end
 end
 if validation then return field end
 if field.type=="color" then
  field.group=paletteColors[key] and "palette" or textColors[key] and "text" or (colorStates[key] or key:match("Hover$") or key:match("Pressed$") or key=="rowAlternate" or key=="rowHover" or key=="pressed" or key=="modalScrim") and "state" or "semantic"
  field.aliasOf=colorAliases[key]
  if colorStates[key] then local source=colorStates[key];field.derivedFrom={source[1],source[2]};if source[4] then field.derivedFrom[3]=source[4] end;field.overlay=source[3] end
  if key=="modalScrim" then field.derivedFrom={"modalScrimAlpha"} end
  if field.aliasOf then local source=field.aliasOf;field.group=paletteColors[source] and "palette" or textColors[source] and "text" or (colorStates[source] or source=="rowHover") and "state" or "semantic" end
 end
 for canonical,group in pairs(TypographyAliases) do
  local matches=canonical==key
  if not matches then for _,alias in ipairs(group.aliases) do if alias==key then matches=true;break end end end
  if matches then field.role,field.canonical,field.representative=group.role,canonical,group.representative;field.aliases=CopyArray(group.aliases);if key~=canonical then field.aliasOf=canonical end;break end
 end
 if typography[key] then field.aliasOf=typography[key];field.independent=true end
 if key=="actionHoverAlpha" or key=="actionPressedAlpha" then field.group="state" end
 return field
end
function Library:GetThemeField(key,extraDefaults)
 local value=extraDefaults and extraDefaults[key];if value==nil then value=T[key] end
 if value==nil then return nil end
 return Field(key,value)
end
function Library.Context:GetThemeField(key) return Library:GetThemeField(key,self.themeDefaults) end
function Library:GetThemeSchema(extraDefaults)
 local schema={}
 for key,value in pairs(T) do schema[key]=Field(key,value) end
 for key,value in pairs(extraDefaults or {}) do schema[key]=Field(key,value) end
 return schema
end
function Library:GetTypographySchema(extraDefaults)
 local schema,result=self:GetThemeSchema(extraDefaults),{}
 for role,style in pairs(TextStyles) do result[role]={fontSize=schema[style.fontSize],lineHeight=schema[style.lineHeight]} end
 return result
end
function Library:GetColorSchema(extraDefaults)
 local result={}
 for key,field in pairs(self:GetThemeSchema(extraDefaults)) do if field.type=="color" then result[key]=field end end
 return result
end
function Library:ValidateTheme(values,extraDefaults)
 if type(values)~="table" then return false,"theme must be a table" end
 local field={}
 for key,value in pairs(values) do
  local default=extraDefaults and extraDefaults[key];if default==nil then default=T[key] end
  if default==nil then return false,"unknown theme token: "..tostring(key) end
  Field(key,default,field)
  if field.type=="color" then
   if type(value)~="table" or #value<3 or #value>4 then return false,"invalid color token: "..key end
   for i=1,#value do if type(value[i])~="number" or value[i]~=value[i] or value[i]<0 or value[i]>1 then return false,"invalid color channel: "..key end end
  elseif type(value)~=field.type or field.type=="number" and (value~=value or value==math.huge or value==-math.huge) then return false,"invalid "..field.type.." token: "..key
  elseif field.type=="number" and (field.min and (value<field.min or field.exclusiveMin and value==field.min) or field.max and value>field.max) then return false,"out-of-range token: "..key end
 end
 local resolved=self.ResolveTheme(values,extraDefaults)
 for key,value in pairs(resolved) do Field(key,value,field);if field.unit then
  local delta=field.unit=="font" and resolved.fontSizeDelta or resolved.lineHeightDelta
  if resolved[key]+delta<=0 then return false,"effective text size must be positive: "..key end
 end end
 return true,nil,resolved
end
