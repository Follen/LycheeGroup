-- Standalone: lua tests/test_guide_view.lua
-- Geometry and ownership checks use native substitutes, not hardware hit tests.
local Fixture=dofile("tests/ui_fixture.lua")
local checks=0
local function Check(value,message) checks=checks+1;assert(value,message) end
local function Near(actual,expected,message) Check(math.abs(actual-expected)<.001,message.." ("..tostring(actual).." / "..tostring(expected)..")") end
local function Inside(x,y,rect)
 return x>=rect.x and x<rect.x+rect.width and y>=rect.y and y<rect.y+rect.height
end
local function Overlap(a,b)
 return a.x<b.right and a.x+a.width>b.left and a.y<b.bottom and a.y+a.height>b.top
end
local function Target(window,x,y,width,height,scale,parent)
 local target=CreateFrame("Button",nil,parent or window);target:SetScale(scale or 1)
 local ratio=target:GetEffectiveScale()/window:GetEffectiveScale()
 target:SetSize(width/ratio,height/ratio)
 -- The focused fixture deliberately omits world-space coordinates. Supply
 -- coordinates only for this test target, in the same units WoW returns.
 function target:GetLeft() return (window:GetLeft()+x)/ratio end
 function target:GetTop() return (window:GetTop()-y)/ratio end
 return target
end
local function VerifyMask(view,width,height)
 if view.mode=="intro" then
  for _,shade in ipairs(view.shades) do Check(not shade:IsShown(),"standalone welcome leaves the game background clear") end
  return
 end
 local hole=view.maskHole
 for y=2,height-1,17 do for x=2,width-1,19 do
  local shaded=0
  for _,shade in ipairs(view.shades) do
   if shade:IsShown() and Inside(x,y,shade.guideRect) then shaded=shaded+1 end
  end
  local inHole=hole and x>=hole.left and x<hole.right and y>=hole.top and y<hole.bottom
  local tip=view.avoidRect
  inHole=inHole or tip.valid and x>=tip.left and x<tip.right and y>=tip.top and y<tip.bottom
  Check(shaded==(inHole and 0 or 1),"spotlight must cover every outside point exactly once")
 end end
end
local function ShadeCount(view,x,y)
 local count=0
 for _,shade in ipairs(view.shades) do if shade:IsShown() and Inside(x,y,shade.guideRect) then count=count+1 end end
 return count
end
local function VerifyCard(view,width,height)
 local rect=view.card.guideRect
 local screen=view.screen
 Check(rect.x>=screen.left and rect.y>=screen.top and rect.x+rect.width<=screen.right+.001 and rect.y+rect.height<=screen.bottom+.001,"card stays inside the effective screen bounds")
 if view.hole then Check(not Overlap(rect,view.hole),"card leaves the highlighted target visible") end
 if view.avoidRect.valid then Check(not Overlap(rect,view.avoidRect),"card leaves the complete player tooltip visible") end
 if view.contextRect.valid then Check(not Overlap(rect,view.contextRect),"card leaves the entire current picker or result area visible") end
 Check(view.arrow:IsShown()==(view.hole~=nil),"only target spotlights show the pointer")
 Check(view.body:GetHeight()+.001>=view.body:GetStringHeight(),"wrapped instructions fit their measured height")
 local _,bodySize=view.body:GetFont()
 Near(bodySize,LycheeGroup.UI.context:GetFontSize("bodyFontSize"),"responsive placement does not shrink instruction typography")
 for _,button in ipairs(view.buttons) do if button:IsShown() then
  local b=button.guideRect
  Check(b.y+b.height<=rect.height+.001,"footer buttons fit the card")
  Check(button.label:GetStringHeight()<=button:GetHeight()+.001,"wrapped button label fits")
  local label=button.label:GetText()
  Check(label~="Next" and label~="Back" and label~="Finish" and label~="下一步" and label~="上一步" and label~="完成","guide has no manual progression button")
 end end
end
local function Observe(view,nodes)
 local counts={measurements=0,writes=0};local saved={}
 local function Wrap(node,name,kind)
  local previous=node[name]
  saved[#saved+1]={node,name,previous}
  node[name]=function(self,...)
   counts[kind]=counts[kind]+1;return previous(self,...)
  end
 end
 for _,node in ipairs(nodes) do
  local parent=node
  while parent and parent~=view.root do parent=parent:GetParent() end
  if parent then
   for _,name in ipairs({"SetSize","SetWidth","SetHeight","SetPoint","ClearAllPoints","SetRotation"}) do Wrap(node,name,"writes") end
   if node:GetObjectType()=="FontString" then
    for _,name in ipairs({"GetStringHeight","GetStringWidth","GetUnboundedStringWidth"}) do Wrap(node,name,"measurements") end
   end
  end
 end
 return counts,function()
  for _,entry in ipairs(saved) do entry[1][entry[2]]=entry[3] end
 end
end
local function Stable(view,nodes)
 local count=#nodes
 local observed,restore=Observe(view,nodes)
 for _=1,20 do Check(view:Layout(),"stable layout remains valid") end
 Check(observed.measurements==0,"stable layout does not measure text again")
 Check(observed.writes==0,"stable layout does not rewrite native sizes, points or rotation")
 Check(#nodes==count,"stable layout does not allocate native objects")
 restore()
end

for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale);local A,U=f.A,f.U
 A:SetSetting("reduceMotion",true);A:Open("find")
 Check(A.Guide==nil,"an account that has seen the welcome does not automatically load the guide")
 Check(A.GuideEntry.hint==nil,"ordinary UI creates no separate invitation")
 local baselineTimers=f.base.PendingTimers()
 local calls={}
 A.Guide={
  Back=function() error("guide view must not call Back") end,
  Next=function() error("guide view must not call Next") end,
  Stop=function(_,reason) calls[#calls+1]=reason end,
  Start=function(_,...) Check(select("#",...)==0,"welcome starts one continuous guide without a route argument");calls[#calls+1]="start" end,
 }
 local before=#f.S.nodes
 local factory=A.CreateBrandMotion;local brandControllers=0
 A.CreateBrandMotion=function(self,...) brandControllers=brandControllers+1;return factory(self,...) end
 dofile("addon/LycheeGroup_Guide/View.lua")
 local view=A.Guide.View
 Check(#f.S.nodes==before and not view.root,"loading the guide view creates no native objects")
 view:Hide();Check(#f.S.nodes==before,"closing an unused guide stays cold")
 local target=Target(U.frame,100,100,180,44,.5)
 local originalLevel=target:GetFrameLevel()
 local originalParent=target:GetParent()
 Check(view:ShowStep(target,"Choose the activity to search for. Select a dungeon or another category.",1,4),"first step opens")
 Check(#view.shades==9 and #view.buttons==3,"one card, three actions and a fixed two-hole mask pool")
 Check(view.buttons.start==view.buttons[1] and view.buttons.skip==view.buttons[2] and view.buttons.dismiss==view.buttons[3],"stable named actions match their public indices")
 Check(not view.buttons.start:IsShown() and not view.buttons.dismiss:IsShown(),"steps only expose the skip action")
 Check(view.buttons.skip.guideRect.y<=16 and view.buttons.skip.guideRect.x>view.card:GetWidth()/2,"small skip stays in the top-right corner")
 Near(view.hole.left,94,"target left converts effective scale and adds padding")
 Near(view.hole.top,94,"target top converts effective scale and adds padding")
 Near(view.hole.right,286,"target right includes padding")
 Near(view.hole.bottom,150,"target bottom includes padding")
 Check(target:GetFrameLevel()==originalLevel and target:GetParent()==originalParent,"highlight does not move or elevate the target")
 Check(view.root.mouseEnabled==false and view.highlight.mouseEnabled==false,"the spotlight itself does not intercept the target")
 for _,shade in ipairs(view.shades) do Check(shade.mouseEnabled,"outside masks intercept mouse input") end
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight())
 Check(view.arrowSide~=nil,"step card points toward its target")
 Stable(view,f.S.nodes)
 local originalCardHeight=view.card:GetHeight()
 local observed,restore=Observe(view,f.S.nodes)
 U.context:SetFont(nil,1.3)
 observed.measurements,observed.writes=0,0
 Check(view:Layout(),"font changes invalidate the card measurement")
 Check(observed.measurements>0 and view.card:GetHeight()>originalCardHeight,"new font size remeasures and grows the card")
 restore();Stable(view,f.S.nodes)
 view.buttons.skip:Fire("OnClick","LeftButton")
 Check(calls[1]=="skipped","skip calls the controller without advancing the guide")
 for _,scale in ipairs({.7,1,1.3}) do
  U.context:SetFont(nil,scale)
  for _,position in ipairs({{12,12},{780,12},{12,510},{780,510},{470,240}}) do
   target=Target(U.frame,position[1],position[2],200,70)
   local withTarget=#f.S.nodes
   Check(view:ShowStep(target,"Select a group to inspect its members, requirements and description before applying.",3,4),"reused step opens")
   Check(#f.S.nodes==withTarget,"step changes reuse native guide objects")
   VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight())
  end
 end
 U.context:SetFont(nil,1)
 view:ShowStep(target,"Finished",4,4)
 Check(not view.buttons.start:IsShown() and view.buttons.skip:IsShown(),"the last step also advances only through production interactions")
 view:Hide()
 Check(not view.target and not view.avoidFrame and not view.hole and not view.mode and not view.root:IsShown(),"hide releases every temporary target reference")
 Check(view.body:GetText()=="" and view.counter:GetText()=="","hide clears step content")
 local beforeIntro=#f.S.nodes
 -- Native SetParent resets inherited strata/levels throughout this subtree.
 -- The general UI stub keeps explicit values; reproduce the observed client
 -- transition here so switching from standalone welcome cannot hide the mask.
 local nativeParent=view.root.SetParent
 view.root.SetParent=function(frame,parent)
  nativeParent(frame,parent)
  local function ReparentLayers(node,strata,level)
   node:SetFrameStrata(strata);node:SetFrameLevel(level)
   for _,child in ipairs({node:GetChildren()}) do ReparentLayers(child,strata,level+1) end
  end
  ReparentLayers(frame,parent:GetFrameStrata(),parent:GetFrameLevel()+1)
 end
 local welcome=locale=="zhCN" and "感谢您使用荔枝组队，我们创建了一个新手引导，来帮助你更好的使用它" or "Thank you for using Lychee LFG. We created this guide to help you use it."
 Check(view:ShowIntroduction(welcome),"welcome opens without a target")
 Check(view.card:GetFrameStrata()=="DIALOG","welcome card restores its layer after reparenting")
 Check(view.ShowRoutes==nil,"obsolete route-selection interface is removed")
 Check(#f.S.nodes==beforeIntro,"welcome reuses every native object from the first step")
 for _,button in ipairs(view.buttons) do button:Fire("OnEnter");button:Fire("OnLeave") end
 Check(#f.S.nodes==beforeIntro,"first hover on welcome buttons does not grow the native pool")
 Check(view.mode=="intro" and not view.target and not view.hole and not view.counter:IsShown(),"welcome has no spotlight or extra heading")
 Check(not view.arrow:IsShown(),"welcome hides the pointer")
 Check(view.card:GetWidth()==520 and view.card:GetHeight()>=320 and view.card:GetHeight()<=350,"welcome uses a compact landscape card")
 Check(view.body:GetText()==welcome,"welcome preserves the supplied wording exactly")
 Check(view.cardSurface.color==U.Theme.surface,"welcome uses the main window's deep surface color")
 Near(view.card.guideRect.x+view.card:GetWidth()/2,U.frame:GetWidth()/2,"welcome panel is centered horizontally")
 Near(view.card.guideRect.y+view.card:GetHeight()/2,U.frame:GetHeight()/2-120,"welcome panel is moved up by 120 UI pixels")
 local function Composition()
  local width=view.card:GetWidth();local logo=view.brandAnchor.guideRect;local body=view.body.guideRect
  local start,dismiss=view.buttons.start.guideRect,view.buttons.dismiss.guideRect
  Check(width==520 and view.card:GetHeight()>=320 and view.card:GetHeight()<=350,"both languages and all supported fonts keep the welcome compact")
  Near(logo.x+logo.width/2,width/2,"large logo is centered above the message")
  Check(logo.width==112 and logo.y+logo.height<body.y,"compact logo and welcome text have separate vertical space")
  Near(body.x+body.width/2,width/2,"welcome message is centered")
  Check(view.body.justify=="CENTER","welcome text uses centered alignment")
  Near(start.x+start.width/2,width/2,"the unique start action is centered at the bottom")
  Check(start.width>=152 and start.height>=42,"start keeps a comfortable compact action size")
  Check(view.buttons.start.label.justify=="CENTER","start label is actually centered inside its button")
  Check(start.y>body.y+body.height+20,"welcome keeps breathing space above the start action")
  Check(dismiss.y<=24 and dismiss.x>width/2,"small dont-show action remains top right")
  Check(dismiss.x>logo.x+logo.width,"top-right dismissal does not overlap the logo's layout box")
  Check(not view.buttons.skip:IsShown(),"welcome has no separate skip or route button")
  Near(view.brandAnchor:GetEffectiveScale(),U.frame:GetEffectiveScale(),"welcome logo inherits the main window's effective scale")
  Near(view.brand:GetWidth()*view.brand:GetEffectiveScale(),view.brandSize*U.frame:GetEffectiveScale(),"resting logo keeps its designed size at the current screen scale")
  local shadowX,shadowY=view.body:GetShadowOffset()
  Check(shadowX==0 and shadowY==0,"welcome text retains the existing shadow-free typography")
 end
 Composition()
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight())
 Stable(view,f.S.nodes)
 for _,fontScale in ipairs({.7,1,1.3}) do
  U.context:SetFont(nil,fontScale)
  local pool=#f.S.nodes
  Check(view:ShowIntroduction(welcome),"welcome fits the supported text scale")
  Check(#f.S.nodes==pool,"welcome text scaling reuses the original card and buttons")
  Composition();VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());Stable(view,f.S.nodes)
  for _,windowScale in ipairs({.75,1,1.4}) do
   U.frame:SetScale(windowScale)
   Check(view:Layout(),"actual welcome copy fits the effective window scale")
   Composition();VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());Stable(view,f.S.nodes)
  end
 end
 U.frame:SetScale(1);U.context:SetFont(nil,1)
 Check(view:Layout(),"welcome returns to the default text scale")
 view.buttons.start:Fire("OnClick","LeftButton");view.buttons.dismiss:Fire("OnClick","LeftButton")
 local n=#calls
 Check(calls[n-1]=="start" and calls[n]=="dismissed","welcome offers only one start and permanent dismissal")
 local detailTarget=Target(U.frame,100,100,180,44,.8)
 Check(view:ShowStep(detailTarget,"Inspect this player's details.",2,5),"detail instruction opens")
 Check(view.root:GetFrameStrata()=="DIALOG" and view.card:GetFrameStrata()=="DIALOG","teaching layers survive the standalone parent transition")
 Check(view.card:GetFrameLevel()>U.frame:GetFrameLevel()+100,"instruction stays above the host blocker and page controls")
 for _,shade in ipairs(view.shades) do
  Check(shade:GetFrameStrata()=="DIALOG" and shade:GetFrameLevel()>U.frame:GetFrameLevel()+100,"mask stays above ordinary page controls")
 end
 local previous=view.card.guideRect
 local playerTip=Target(U.frame,previous.x,previous.y,360,260,.8,UIParent)
 playerTip:EnableMouse(true)
 local clicks=0;local onClick=function() clicks=clicks+1 end
 playerTip:SetScript("OnMouseDown",onClick)
 Check(view:SetAvoidFrame(playerTip),"visible player tooltip updates the avoidance geometry")
 Check(view.avoidFrame==playerTip and playerTip:GetScript("OnMouseDown")==onClick,"view preserves the production tooltip and its input scripts")
 VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight())
 playerTip:Fire("OnMouseDown");Check(clicks==1,"production tooltip callback is preserved")
 Stable(view,f.S.nodes)
 local function Distance(rect,hole)
  local dx=math.max(hole.left-rect.x-rect.width,rect.x-hole.right,0)
  local dy=math.max(hole.top-rect.y-rect.height,rect.y-hole.bottom,0)
  return math.sqrt(dx*dx+dy*dy)
 end
 local placedDistance=Distance(view.card.guideRect,view.hole)
 Check(view:SetAvoidFrame(nil),"tooltip removal updates the spotlight")
 Check(Distance(view.card.guideRect,view.hole)<=placedDistance+.001,"tooltip removal can bring the instruction closer to the target")
 Stable(view,f.S.nodes)
 local moving=Target(U.frame,100,100,80,30)
 Check(view:ShowStep(moving,"Follow this control.",2,5),"moving target opens")
 local oldLeft,oldTop=moving.GetLeft,moving.GetTop
 function moving:GetLeft() return oldLeft(self)+500 end
 function moving:GetTop() return oldTop(self)-300 end
 Check(view:Layout() and Distance(view.card.guideRect,view.hole)<=20,"a formerly valid but now distant card moves beside its target")
 Stable(view,f.S.nodes)
 Check(view:ShowStep(detailTarget,"Inspect this player's details.",2,5),"detail target is restored")
 -- Disjoint x intervals with overlapping y ranges exercise all nine masks.
 playerTip=Target(U.frame,410,115,320,260,.8,UIParent)
 Check(view:SetAvoidFrame(playerTip),"separate tooltip remains clickable")
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight())
 local liveMasks=0;for _,shade in ipairs(view.shades) do if shade:IsShown() then liveMasks=liveMasks+1 end end
 Check(liveMasks==9,"two independent holes use the fixed mask pool without merging the intervening controls")
 -- A player-tooltip member control is a UIParent sibling beyond the main edge.
 local externalTip=Target(U.frame,U.frame:GetWidth()-30,200,360,260,.8,UIParent)
 local member=Target(U.frame,U.frame:GetWidth()+30,230,90,36,.8,UIParent)
 Check(view:ShowStep(member,"Click this member to inspect their details.",3,5),"external member target opens")
 Check(view:SetAvoidFrame(externalTip),"external tooltip is also an avoidance region")
 Check(view.hole.left>U.frame:GetWidth(),"external tooltip target is not clamped into the main window")
 Check(view.highlight:GetFrameStrata()=="TOOLTIP","external tooltip target keeps a visible noninteractive outline")
 VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight())
 Stable(view,f.S.nodes)
 view:SetAvoidFrame(nil)
 local function Outside(rect)
  return rect.x+rect.width<=0 or rect.y+rect.height<=0 or rect.x>=U.frame:GetWidth() or rect.y>=U.frame:GetHeight()
 end
 local picker=Target(U.frame,44,160,640,480)
 local pickerTarget=Target(U.frame,64,180,180,44)
 view:SetContextFrame(picker)
 Check(view:ShowStep(pickerTarget,"Choose a dungeon from this list.",4,8),"picker context opens")
 Check(view.contextFrame==picker and view.contextRect.valid,"picker context becomes a separate placement exclusion")
 Check(Distance(view.card.guideRect,view.hole)<100,"picker instruction stays close to its target while avoiding the entire picker")
 VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());Stable(view,f.S.nodes)
 local results=Target(U.frame,16,230,U.frame:GetWidth()-32,560)
 local sortTarget=Target(U.frame,420,198,90,32)
 view:SetContextFrame(results)
 Check(view:ShowStep(sortTarget,"Sort this column and inspect the results.",5,8),"sorting context opens")
 Check(Distance(view.card.guideRect,view.hole)<100,"sort instruction uses nearby free header space instead of a distant exterior position")
 VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());Stable(view,f.S.nodes)
 -- A reveal expands only the primary interaction hole. The outline and pointer
 -- remain attached to the specific header, while context still excludes cards.
 local reveal=Target(U.frame,16,190,U.frame:GetWidth()-32,600,.8,UIParent)
 local revealPool=#f.S.nodes
 Check(view:SetRevealFrame(reveal),"whole-list reveal opens")
 Check(view.revealFrame==reveal and view.revealActive and view.maskHole==view.revealRect,"visible containing reveal becomes the primary mask hole")
 Near(view.highlight:GetWidth(),sortTarget:GetWidth()+12,"whole-list reveal preserves the small target outline width")
 Near(view.highlight:GetHeight(),sortTarget:GetHeight()+12,"whole-list reveal preserves the small target outline height")
 Check(ShadeCount(view,100,350)==0 and ShadeCount(view,700,700)==0,"the whole operation table is clear and clickable")
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());Stable(view,f.S.nodes)
 local revealTip=Target(U.frame,760,50,220,100,.8,UIParent)
 local tooltipPool=#f.S.nodes
 Check(view:SetAvoidFrame(revealTip),"whole-list reveal coexists with a separately clickable tooltip")
 Check(view.avoidFrame==revealTip and view.avoidRect.valid and view.maskHole==view.revealRect,"tooltip remains the only second mask hole")
 Check(ShadeCount(view,800,100)==0 and ShadeCount(view,700,160)==1,"the tooltip remains clickable while the gap between both holes stays blocked")
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight())
 Check(#view.shades==9 and #f.S.nodes==tooltipPool and tooltipPool==revealPool+1,"reveal and tooltip reuse the fixed nine-mask pool")
 Check(view:SetAvoidFrame(nil),"extra tooltip can close while the table remains revealed")
 local column=Target(U.frame,420,198,90,592,.8,UIParent)
 Check(view:SetRevealFrame(column),"rating-column reveal opens")
 Check(ShadeCount(view,450,350)==0 and ShadeCount(view,250,350)==1,"rating-only sorting exposes one column rather than the whole table")
 Near(view.highlight:GetWidth(),102,"rating-only reveal keeps the original header outline")
 Near(view.highlight:GetHeight(),44,"rating-only reveal does not turn the outline into a tall column")
 local columnTop=column.GetTop
 column.GetTop=function(self) return columnTop(self)-.00006103515625 end
 Check(view:Layout() and view.revealActive,"native coordinate rounding does not disable the rating-column reveal")
 Check(ShadeCount(view,450,350)==0,"rating values remain clear after a subpixel boundary round trip")
 column.GetTop=function(self) return columnTop(self)-.02 end
 Check(view:Layout() and not view.revealActive,"a genuinely displaced reveal still falls back to the target")
 column.GetTop=columnTop;view:Layout()
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());Stable(view,f.S.nodes)
 local previousBottom=view.maskHole.bottom
 column:SetHeight(column:GetHeight()-80)
 Check(view:Layout() and view.maskHole.bottom<previousBottom,"reveal geometry invalidates the mask cache")
 Stable(view,f.S.nodes)
 column:Hide()
 Check(view:Layout() and not view.revealActive and view.maskHole==view.targetRect,"a hidden reveal falls back to the actual target")
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight())
 local unrelated=Target(U.frame,700,300,100,100)
 Check(view:SetRevealFrame(unrelated) and not view.revealActive and view.maskHole==view.targetRect,"a noncontaining reveal cannot open an unrelated third interaction region")
 Check(ShadeCount(view,750,350)==1,"unrelated reveal stays blocked")
 Check(view:SetRevealFrame(nil),"reveal can be released independently of the step")
 local oldContextRight=view.contextRect.right
 results:SetWidth(results:GetWidth()-120)
 Check(view:Layout() and view.contextRect.right<oldContextRight,"context dimensions participate in layout invalidation")
 VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight())
 view:SetContextFrame(nil)
 -- When the main window fills the viewport, use a free interior region without
 -- covering the operation area or turning it into another interactive hole.
 U.frame:SetSize(UIParent:GetWidth(),UIParent:GetHeight())
 local fullPicker=Target(U.frame,32,200,1400,700)
 local fullTarget=Target(U.frame,48,220,200,40)
 view:SetContextFrame(fullPicker)
 Check(view:ShowStep(fullTarget,"Choose one item.",6,8),"interior fallback can fit beside the entire picker")
 Check(not Outside(view.card.guideRect),"full-screen main window uses a valid interior fallback")
 VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight());VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight());Stable(view,f.S.nodes)
 local covered=0
 for _,shade in ipairs(view.shades) do if shade:IsShown() and Inside(80,350,shade.guideRect) then covered=covered+1 end end
 Check(covered==1,"context exclusion does not open a third interactive hole")
 local screen=view.screen
 local impossible=Target(U.frame,screen.left-20,screen.top-20,screen.right-screen.left+40,screen.bottom-screen.top+40)
 Check(view:SetContextFrame(impossible)==false,"an oversized context temporarily suspends the card")
 Check(view.contextFrame==impossible and view.target==fullTarget and view.mode=="step","context suspension retains the current operation")
 VerifyMask(view,U.frame:GetWidth(),U.frame:GetHeight())
 Check(view:SetContextFrame(fullPicker),"shrinking the context restores the current card without a new step")
 VerifyCard(view,U.frame:GetWidth(),U.frame:GetHeight())
 view:SetContextFrame(nil)
 -- Even when an exterior strip can fit a card, a nearer legal interior location
 -- takes precedence. Width choices are ranked together by target distance.
 local exteriorLeft,exteriorTop=U.frame.GetLeft,U.frame.GetTop
 U.frame:SetSize(1400,1000)
 function U.frame:GetLeft() return 260 end
 function U.frame:GetTop() return 1040 end
 local exteriorContext=Target(U.frame,16,200,1368,700)
 local exteriorTarget=Target(U.frame,600,180,100,32)
 view:SetContextFrame(exteriorContext)
 Check(view:ShowStep(exteriorTarget,"Sort this column.",7,8),"narrow exterior strip remains usable")
 Check(not Outside(view.card.guideRect) and Distance(view.card.guideRect,view.hole)<100,"a nearby interior placement takes precedence over the exterior strip")
 Near(view.card.guideRect.y+view.card.guideRect.height,view.hole.top-30,"the card above a target leaves sixteen extra pixels of vertical space")
 local liftedY=view.card.guideRect.y
 for _=1,4 do view.layoutValid=false;Check(view:Layout(),"explicit refresh preserves the lifted card") end
 Near(view.card.guideRect.y,liftedY,"repeated placement does not accumulate the upward offset")
 VerifyCard(view,1400,1000);Stable(view,f.S.nodes)
 view:SetContextFrame(nil)
 U.frame.GetLeft,U.frame.GetTop=exteriorLeft,exteriorTop
 U.frame:SetSize(640,640)
 local pointerLeft,pointerTop=U.frame.GetLeft,U.frame.GetTop
 function U.frame:GetLeft() return 640 end
 function U.frame:GetTop() return 850 end
 for _,case in ipairs({
  {16,16,80,608,"left",0},
  {520,16,80,608,"right",math.pi},
  {16,16,608,80,"top",-math.pi/2},
  {16,520,608,80,"bottom",math.pi/2},
 }) do
  local pointerTarget=Target(U.frame,case[1],case[2],case[3],case[4])
  Check(view:ShowStep(pointerTarget,"Point at this control.",2,4),"directional pointer step fits")
  local rect,hole=view.card.guideRect,view.hole
  local side=rect.x>=hole.right and "left" or rect.x+rect.width<=hole.left and "right" or rect.y>=hole.bottom and "top" or "bottom"
  local angle=side=="left" and 0 or side=="right" and math.pi or side=="top" and -math.pi/2 or math.pi/2
  Check(view.arrowSide==side,"pointer follows the free side chosen for the card")
  Near(view.arrow.rotation,angle,"pointer rotates toward its highlighted target")
  Check(view.arrow:GetTexture()==U.Theme.media.."arrow.tga","pointer reuses the existing shared asset")
  VerifyCard(view,640,640);Stable(view,f.S.nodes)
 end
 U.frame.GetLeft,U.frame.GetTop=pointerLeft,pointerTop
 -- The card can use a narrow side when neither vertical side has enough room.
 U.frame:SetSize(540,540)
 local narrow=Target(U.frame,218,16,300,500)
 Check(view:ShowStep(narrow,"This deliberately longer instruction wraps within the narrow side while keeping the highlighted content visible.",2,5),"narrow step fits")
 Check(view.hole~=nil,"limited main-window space preserves the target")
 Check(Distance(view.card.guideRect,view.hole)<=20,"tight layouts still keep the instruction adjacent to its control")
 VerifyCard(view,540,540);VerifyMask(view,540,540)
 Stable(view,f.S.nodes)
 U.frame:SetScale(.75)
 Check(view:Layout(),"window scale change can be laid out explicitly")
 VerifyCard(view,540,540)
 narrow:Hide()
 Check(view:Layout() and not view.hole,"hidden targets produce a centered card and a complete mask")
 VerifyCard(view,540,540)
 -- Move the main window to each screen edge, including unequal effective scales.
 local getLeft,getTop=U.frame.GetLeft,U.frame.GetTop
 local windowLeft,windowTop=0,500
 function U.frame:GetLeft() return windowLeft end
 function U.frame:GetTop() return windowTop end
 U.frame:SetSize(640,500)
 for _,fontScale in ipairs({.7,1,1.3}) do
  U.context:SetFont(nil,fontScale)
  for _,windowScale in ipairs({.6,1,1.4}) do
   U.frame:SetScale(windowScale)
   local screenWidth=UIParent:GetWidth()*UIParent:GetEffectiveScale()/U.frame:GetEffectiveScale()
   local screenHeight=UIParent:GetHeight()*UIParent:GetEffectiveScale()/U.frame:GetEffectiveScale()
   for edge=1,4 do
    windowLeft=(edge==2 or edge==4) and screenWidth-648 or 8
    windowTop=(edge<=2) and screenHeight-8 or 508
    local edgeTarget=Target(U.frame,edge%2==0 and 540 or 16,edge<=2 and 16 or 430,80,44,.75,UIParent)
    local pool=#f.S.nodes
    Check(view:ShowStep(edgeTarget,"Use this highlighted control to continue through the interface.",edge,4),"edge target has a nonoverlapping screen placement")
    Check(#f.S.nodes==pool,"scale and screen edge changes reuse all guide objects")
    VerifyCard(view,640,500);Stable(view,f.S.nodes)
   end
  end
 end
 U.frame.GetLeft,U.frame.GetTop=getLeft,getTop
 -- A tooltip can temporarily cover every possible card position. Do not lose
 -- the current step or hide the root: its target must remain recoverable.
 U.frame:SetScale(1);U.context:SetFont(nil,1.3)
 local recover=Target(U.frame,100,100,180,44)
 Check(view:ShowStep(recover,"Click the highlighted button.",5,8),"recovery scenario opens")
 local bounds=view.screen
 local full=Target(U.frame,bounds.left-20,bounds.top-20,bounds.right-bounds.left+40,bounds.bottom-bounds.top+40,1,UIParent)
 local pool=#f.S.nodes
 Check(view:SetAvoidFrame(full)==false,"fully occupied screen temporarily suspends only the card")
 Check(view.suspended and view.mode=="step" and view.target==recover and view.avoidFrame==full,"no-room layout preserves its step and avoidance references")
 Check(view.root:IsShown() and not view.card:IsShown() and not view.arrow:IsShown(),"spotlight survives a temporarily hidden card")
 local suspended,release=Observe(view,f.S.nodes)
 for _=1,20 do Check(view:Layout()==false,"stable no-room layout stays suspended") end
 Check(suspended.measurements==0 and suspended.writes==0 and #f.S.nodes==pool,"stable suspended layouts neither remeasure nor rewrite native geometry")
 release()
 Check(view:SetAvoidFrame(nil),"removing the obstruction restores the same card")
 Check(not view.suspended and view.target==recover and view.card:IsShown(),"card resumes without another ShowStep call")
 VerifyCard(view,640,500);Stable(view,f.S.nodes)
 -- Leave a short strip at the actual screen edge. Compact padding and a wider
 -- text measure can fit there while the original text size stays unchanged.
 bounds=view.screen
 local strip=Target(U.frame,bounds.left-20,bounds.top+108,bounds.right-bounds.left+40,bounds.bottom-bounds.top+40,1,UIParent)
 Check(view:SetAvoidFrame(strip),"compact card can use a small unobstructed screen strip")
 Check(view.compact,"crowded screen uses a compact card rather than shrinking the font")
 Check(view.card.guideRect.y+view.card:GetHeight()<=view.avoidRect.top+.001,"compact card fits outside the tooltip")
 VerifyCard(view,640,500);Stable(view,f.S.nodes)
 view:SetAvoidFrame(nil)
 -- The welcome uses the same finite product bounce as the ordinary main logo.
 view:Hide();U.context:SetFont(nil,1);A:SetSetting("reduceMotion",false)
 Check(view:ShowIntroduction(welcome),"animated welcome opens")
 local brand=view.brandMotion;local motion=U.context.Motion
 Check(brand:IsPlaying(),"welcome starts the finite lychee bounce")
 motion:Tick(.168)
 Check(math.abs(view.brand:GetWidth()-view.brandSize)>.01,"welcome logo uses the existing squash-and-lift trajectory")
 Near(view.brand:GetWidth(),view.brandSize*1.075,"brand motion uses its real anchor width during the first squash")
 Near(view.brand:GetHeight(),view.brandSize*.925,"brand motion uses its real anchor height during the first squash")
 local _,anchor,_,_,lift=view.brand:GetPoint()
 Check(anchor==view.brandAnchor,"brand trajectory remains anchored to its dedicated centered frame")
 local logoBottom=view.brandAnchor.guideRect.y+view.brandAnchor:GetHeight()/2-lift+view.brand:GetHeight()/2
 Check(logoBottom<view.body.guideRect.y,"bouncing logo stays above the actual welcome paragraph")
 motion:Tick(U.Theme.brandDuration+.1)
 Check(not brand:IsPlaying(),"welcome bounce settles without a permanent animation loop")
 Near(view.brand:GetWidth(),view.brandSize,"finished welcome bounce restores the logo width")
 local animatedPool=#f.S.nodes
 view.brandAnchor:Fire("OnEnter");Check(brand:IsPlaying(),"hover can replay the same finite bounce")
 Check(not view.brandAnchor:IsMouseEnabled(),"animated logo hover does not claim mouse clicks")
 Check(view:ShowStep(recover,"Click this control.",6,8),"welcome transitions into the continuous guide")
 Check(not brand:IsPlaying() and not view.brandAnchor:IsShown(),"step transition stops and hides the welcome logo")
 Check(view:ShowIntroduction(welcome),"welcome can reuse the existing brand controller")
 A:SetSetting("reduceMotion",true);view:Layout()
 Check(not brand:IsPlaying(),"reduced motion immediately stops the welcome bounce")
 Near(view.brand:GetWidth(),view.brandSize,"reduced motion keeps the static lychee pose")
 Check(#f.S.nodes==animatedPool and brandControllers==1 and view.brandMotion==brand,"welcome reuses one brand controller and all animated visual objects")
 Stable(view,f.S.nodes)
 A:SetSetting("reduceMotion",false);view:Hide()
 Check(view:ShowIntroduction(welcome) and brand:IsPlaying(),"reopened animated welcome can play again")
 view:Hide();Check(not brand:IsPlaying(),"hiding an actively bouncing welcome releases its animation job")
 Near(view.brand:GetWidth(),view.brandSize,"hiding restores the logo's static pose")
 A:SetSetting("reduceMotion",true)
 Check(view:ShowStep(recover,"Continue here.",7,8),"the same spotlight is reusable after animated welcome closure")
 Check(view:SetContextFrame(picker) and view.contextFrame==picker,"current context remains owned until the guide closes")
 local finalReveal=Target(U.frame,80,80,240,100)
 Check(view:SetRevealFrame(finalReveal) and view.revealFrame==finalReveal,"current reveal remains owned until closure")
 Check(view:ShowIntroduction(welcome) and not view.revealFrame and not view.revealRect.valid and not view.maskHole,"welcome releases every previous reveal reference")
 Check(view:ShowStep(recover,"Continue here.",7,8) and view:SetRevealFrame(finalReveal),"reveal can be reused after the welcome")
 -- Native parent hiding sends OnHide to the owned overlay. Calling Hide here
 -- checks that same callback without extending the fixture's visibility model.
 view.root:Hide()
 Check(view.target==nil and view.avoidFrame==nil and view.contextFrame==nil and view.revealFrame==nil and view.maskHole==nil and view.mode==nil,"overlay OnHide clears target, tooltip, context and reveal ownership")
 Check(f.base.PendingTimers()==baselineTimers,"guide opens, changes steps and closes without scheduling timers")
 for _,node in ipairs(f.S.nodes) do
  local parent=node
  while parent and parent~=view.root do parent=parent:GetParent() end
  if parent then
   Check(node:GetScript("OnUpdate")==nil,"guide owns no update loop")
   Check(next(node.events)==nil,"guide owns no event registrations")
  end
 end
 Check(view:Layout()==false,"closed layouts do no work")
 U.frame:Hide()
 Check(view:ShowStep(recover,"Hidden window",1,1)==false and not view.root:IsShown(),"a hidden parent cannot reactivate an empty spotlight")
 A.CreateBrandMotion=factory
end
print(("guide view checks passed: %d"):format(checks))
