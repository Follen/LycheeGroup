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
function Library.ResolveTheme(overrides)
 local theme={}
 for key,value in pairs(T) do theme[key]=value end
 for key,value in pairs(overrides or {}) do theme[key]=value end
 local function State(key,base,layer)
  if overrides and overrides[key]~=nil then return end
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
  if not overrides or overrides[key]==nil then theme[key]=theme[source] end
 end
 return theme
end
