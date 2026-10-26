-- A bounded reusable spotlight. Only explicit controller notifications lay it out.
local A=_G.LycheeGroup
local Guide=assert(A.Guide)
local View={};Guide.View=View
local STEP_WIDTHS={320,420,240,180}
local function S(cn,en) return A:GetLocale()=="zhCN" and cn or en end
local function Clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function BlockScroll() end
local function SameMetrics(r)
 local c,t=A.UI.context,A.UI.Theme
 return r.path==c.fontPath and r.scale==c.fontScale and r.fd==t.fontSizeDelta and r.ld==t.lineHeightDelta
  and r.bf==t.bodyFontSize and r.bl==t.bodyLineHeight and r.cf==t.captionFontSize and r.cl==t.captionLineHeight
  and r.tf==t.buttonFontSize and r.tl==t.buttonLineHeight
end
local function SaveMetrics(r)
 local c,t=A.UI.context,A.UI.Theme
 r.path,r.scale,r.fd,r.ld=c.fontPath,c.fontScale,t.fontSizeDelta,t.lineHeightDelta
 r.bf,r.bl,r.cf,r.cl,r.tf,r.tl=t.bodyFontSize,t.bodyLineHeight,t.captionFontSize,t.captionLineHeight,t.buttonFontSize,t.buttonLineHeight
end
local function Rect(frame,x,y,w,h)
 local p=frame.guideRect;if not p then p={};frame.guideRect=p end
 if p.x~=x or p.y~=y then frame:ClearAllPoints();frame:SetPoint("TOPLEFT",frame:GetParent(),"TOPLEFT",x,-y);p.x,p.y=x,y end
 if p.width~=w or p.height~=h then frame:SetSize(w,h);p.width,p.height=w,h end
 frame:SetShown(w>0 and h>0)
end
local function ReadRect(frame,window,pad,r)
 r.valid=false;if not frame or not frame:IsVisible() then return end
 local l,t,wl,wt=frame:GetLeft(),frame:GetTop(),window:GetLeft(),window:GetTop()
 if not l or not t or not wl or not wt then return end
 local s=frame:GetEffectiveScale()/window:GetEffectiveScale()
 r.left,r.top=l*s-wl-pad,wt-t*s-pad
 r.right,r.bottom=r.left+frame:GetWidth()*s+pad*2,r.top+frame:GetHeight()*s+pad*2
 r.valid=r.right>r.left and r.bottom>r.top
end
local function Overlap(x,y,w,h,r) return r and r.valid and x<r.right and x+w>r.left and y<r.bottom and y+h>r.top end
local function Fits(x,y,w,h,b,t,a,c)
 return x>=b.left and y>=b.top and x+w<=b.right and y+h<=b.bottom and not Overlap(x,y,w,h,t) and not Overlap(x,y,w,h,a) and not Overlap(x,y,w,h,c)
end
local function Label(button,text)
 if button.label:GetText()==text then return false end
 button.label:SetText(text);return true
end
function View:Build()
 if self.root then return true end
 local UI=A.UI;if not UI or not UI.frame then return false end
 local C,T=UI.C,UI.Theme
 local root=CreateFrame("Frame",nil,UI.frame)
 root:Hide();root:SetAllPoints(UI.frame);root:SetFrameStrata("DIALOG");root:SetFrameLevel(UI.frame:GetFrameLevel()+120);root:EnableMouse(false)
 self.root=root;self.shades={};self.buttons={};self.buttonLayout={};self.measurement={};self.layoutMetrics={}
 self.geometry={};self.lastGeometry={};self.targetRect={};self.avoidRect={};self.contextRect={};self.revealRect={};self.screen={}
 self.candidateX={};self.candidateY={};self.cuts={};self.intervals={{},{}};self.contentRevision=0
 root:SetScript("OnHide",function() View:Hide() end)
 -- Two independently clickable holes need at most nine disjoint shade pieces.
 for i=1,9 do
  local f=CreateFrame("Frame",nil,root);f:SetFrameLevel(root:GetFrameLevel()+1);f:EnableMouse(true)
  f:EnableMouseWheel(true);f:SetScript("OnMouseWheel",BlockScroll);C.Fill(f,{0,0,0,.64});self.shades[i]=f
 end
 local highlight=CreateFrame("Frame",nil,root);highlight:SetFrameStrata("TOOLTIP");highlight:SetFrameLevel(root:GetFrameLevel()+2);highlight:EnableMouse(false)
 local edges={{"TOPLEFT","TOPRIGHT"},{"BOTTOMLEFT","BOTTOMRIGHT"},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}
 for i,points in ipairs(edges) do
  local line=highlight:CreateTexture(nil,"OVERLAY");line:SetColorTexture(unpack(T.brand));line:SetPoint(points[1]);line:SetPoint(points[2])
  if i<=2 then line:SetHeight(1.5) else line:SetWidth(1.5) end
 end
 self.highlight=highlight
 local card=CreateFrame("Frame",nil,root);card:SetFrameLevel(root:GetFrameLevel()+3);card:EnableMouse(true)
 card:EnableMouseWheel(true);card:SetScript("OnMouseWheel",BlockScroll);self.cardSurface=C.Panel(card,"raised","panelRadius");self.card=card
 self.arrow=C.Icon(card,12);self.arrow:SetTexture(T.media.."arrow.tga");self.arrow:SetVertexColor(unpack(T.brand));self.arrow:SetDrawLayer("OVERLAY");self.arrow:Hide()
 self.brandAnchor=CreateFrame("Frame",nil,card)
 self.brand=C.Icon(self.brandAnchor,112);self.brand:SetTexture(T.productMedia.."lychee-logo.tga");self.brand:SetPoint("CENTER",self.brandAnchor,"CENTER",0,0)
 self.brandMotion=A:CreateBrandMotion(UI.context,self.brand,self.brandAnchor,112);self.brandSize=112
 self.brandAnchor:SetScript("OnEnter",function()
  if View.mode=="intro" and View.card:IsVisible() then View.brandMotion:Play() end
 end)
 self.brandAnchor:SetScript("OnHide",function() View.brandMotion:Stop() end)
 self.brandAnchor:EnableMouse(false);self.brandAnchor:EnableMouseMotion(true)
 self.counter=C.Text(card,"","captionFontSize","muted",200,"captionLineHeight")
 self.body=C.Text(card,"","bodyFontSize","text",280,"bodyLineHeight");self.body:SetWordWrap(true);self.body:SetJustifyV("TOP")
 for i=1,3 do
  local index=i
  local b=C.Button(card,"",100,function()
   if index==1 and View.mode=="intro" then Guide:Start()
   elseif index==2 and View.mode=="step" then Guide:Stop("skipped")
   elseif index==3 and View.mode=="intro" then Guide:Stop("dismissed") end
  end,{variant=i==1 and "primary" or "text"})
  if i>=2 then b:SetLabelStyle("captionFontSize","captionLineHeight") end
  C.SetLineHeight(b.label,i>=2 and "captionLineHeight" or "buttonLineHeight",false);b.label:SetWordWrap(true)
  b.label:SetJustifyH("CENTER")
  b.hover:Hide();self.buttons[i]=b;self.buttonLayout[i]={}
 end
 self.buttons.start,self.buttons.skip,self.buttons.dismiss=self.buttons[1],self.buttons[2],self.buttons[3]
 return true
end
function View:MeasureCard(width)
 local cache=self.measurement
 local intro=self.mode=="intro"
 local limit=intro and self.screen.bottom-self.screen.top or false
 if cache.width==width and cache.revision==self.contentRevision and cache.compact==self.compact and cache.limit==limit and SameMetrics(cache) then return cache.height end
 local context=A.UI.context
 local padding=intro and math.min(40,width*.08) or self.compact and 12 or 20
 local inner=intro and math.min(560,width-padding*2) or math.max(1,width-padding*2)
 if intro then self.logoSize=math.min(112,width*.23,math.max(72,(limit-144)/2)) end
 local action=self.buttons[intro and 3 or 2];local sw=math.ceil(action.label:GetUnboundedStringWidth())+20
 if intro then sw=math.min(sw,math.max(80,width/2-self.logoSize*.54-32)) end
 action.label:SetWidth(sw-16);action.label:SetHeight(0)
 local sh=math.max(self.compact and 24 or 28,action.label:GetStringHeight()+(self.compact and 4 or 8))
 local item=self.buttonLayout[intro and 3 or 2]
 item.x,item.y,item.width,item.height=width-(intro and 28 or padding)-sw,intro and 20 or self.compact and 6 or 12,sw,sh
 if intro then
  self.logoTop=24
  self.bodyTop=self.logoTop+self.logoSize+20
 else self.bodyTop=math.max(self.compact and 32 or 48,sh+(self.compact and 14 or 22)) end
 self.bodyWidth=inner;self.bodyLeft=intro and (width-inner)/2 or padding
 self.body:SetWidth(inner);self.body:SetHeight(0)
 self.bodyHeight=math.max(context:GetLineHeight("bodyLineHeight"),self.body:GetStringHeight());self.body:SetHeight(self.bodyHeight)
 local height=self.bodyTop+self.bodyHeight+(self.compact and 12 or 24)
 if intro then
  local start=self.buttons.start
  local bw=math.min(inner,math.max(152,math.ceil(start.label:GetUnboundedStringWidth())+40))
  start.label:SetWidth(bw-24);start.label:SetHeight(0)
  local bh=math.max(42,start.label:GetStringHeight()+14)
  local bottom=24
  height=math.max(math.min(320,limit),self.bodyTop+self.bodyHeight+22+bh+bottom)
  local r=self.buttonLayout[1];r.x,r.y,r.width,r.height=(width-bw)/2,height-bottom-bh,bw,bh
 end
 cache.width,cache.height,cache.revision,cache.compact,cache.limit=width,height,self.contentRevision,self.compact,limit;SaveMetrics(cache);return height
end
function View:AttachRoot(parent)
 if self.root:GetParent()==parent then return end
 self.root:SetParent(parent)
 -- SetParent resets inherited strata and levels in the native frame tree.
 -- Restore the complete overlay order after switching the welcome's parent.
 local level=A.UI.frame:GetFrameLevel()+120
 self.root:SetFrameStrata("DIALOG");self.root:SetFrameLevel(level)
 for _,shade in ipairs(self.shades) do shade:SetFrameStrata("DIALOG");shade:SetFrameLevel(level+1) end
 self.card:SetFrameStrata("DIALOG");self.card:SetFrameLevel(level+3)
 self.highlight:SetFrameStrata("TOOLTIP");self.highlight:SetFrameLevel(level+2)
 self.layoutValid=false
end
function View:FindPlacement(w,h)
 local t,a,c,s=self.targetRect,self.avoidRect,self.contextRect,self.screen
 local previous=self.mode~="intro" and self.lastValid and self.lastWidth==w and Fits(self.lastX,self.lastY,w,h,s,t,a,c)
 local cx=t.valid and (t.left+t.right)/2 or A.UI.frame:GetWidth()/2
 local cy=t.valid and (t.top+t.bottom)/2 or A.UI.frame:GetHeight()/2-(self.mode=="intro" and 120 or 0)
 local function Score(x,y)
  local centerX,centerY=x+w/2-cx,y+h/2-cy
  if not t.valid then return centerX*centerX+centerY*centerY end
  local dx=math.max(t.left-x-w,x-t.right,0)
  local dy=math.max(t.top-y-h,y-t.bottom,0)
  return dx*dx+dy*dy+.035*(centerX*centerX+centerY*centerY)
 end
 local xs,ys=self.candidateX,self.candidateY
 xs[1],ys[1]=Clamp(cx-w/2,s.left,s.right-w),Clamp(cy-h/2,s.top,s.bottom-h)
 xs[2],xs[3],ys[2],ys[3]=s.left,s.right-w,s.top,s.bottom-h
 local count=3
 if t.valid then xs[4],xs[5],ys[4],ys[5]=t.right+14,t.left-w-14,t.bottom+14,t.top-h-14;count=5 end
 if a.valid then xs[count+1],xs[count+2],ys[count+1],ys[count+2]=a.right+14,a.left-w-14,a.bottom+14,a.top-h-14;count=count+2 end
 if c.valid then xs[count+1],xs[count+2],ys[count+1],ys[count+2]=c.right+14,c.left-w-14,c.bottom+14,c.top-h-14;count=count+2 end
 xs[count+1],xs[count+2],ys[count+1],ys[count+2]=A.UI.frame:GetWidth()+14,-w-14,A.UI.frame:GetHeight()+14,-h-14;count=count+2
 local bestX,bestY,bestScore
 for i=1,count do for j=1,count do
   local x,y=xs[i],ys[j]
   if Fits(x,y,w,h,s,t,a,c) then
    local score=Score(x,y)
    if not bestScore or score<bestScore then bestX,bestY,bestScore=x,y,score end
   end
 end end
 if previous then
  local score=Score(self.lastX,self.lastY)
  if not bestScore or score<=bestScore*1.12+100 then return self.lastX,self.lastY,score end
 end
 return bestX,bestY,bestScore
end
function View:PlaceArrow(x,y,w,h)
 local t=self.targetRect;if not t.valid then self.arrow:Hide();self.arrowSide=nil;return end
 local ax,ay,angle,side
 if x>=t.right then ax,ay=-12,Clamp((t.top+t.bottom)/2-y,24,h-24)-6;angle=0;side="left"
 elseif x+w<=t.left then ax,ay=w,Clamp((t.top+t.bottom)/2-y,24,h-24)-6;angle=math.pi;side="right"
 elseif y>=t.bottom then ax,ay=Clamp((t.left+t.right)/2-x,24,w-24)-6,-12;angle=-math.pi/2;side="top"
 else ax,ay=Clamp((t.left+t.right)/2-x,24,w-24)-6,h;angle=math.pi/2;side="bottom" end
 if self.arrowSide~=side then self.arrow:SetRotation(angle);self.arrowSide=side end
 Rect(self.arrow,ax,ay,12,12)
end
function View:LayoutMask(width,height)
 local target,reveal=self.targetRect,self.revealRect
 local t=target
 self.revealActive=reveal.valid and (not target.valid or reveal.left<=target.left and reveal.top<=target.top and reveal.right>=target.right and reveal.bottom>=target.bottom)
 if self.revealActive then t=reveal end
 self.maskHole=t.valid and t or nil
 local a,cuts=self.avoidRect,self.cuts;cuts[1],cuts[2]=0,height;local count=2
 if t.valid then count=count+2;cuts[count-1],cuts[count]=Clamp(t.top,0,height),Clamp(t.bottom,0,height) end
 if a.valid then count=count+2;cuts[count-1],cuts[count]=Clamp(a.top,0,height),Clamp(a.bottom,0,height) end
 for i=count+1,#cuts do cuts[i]=nil end;table.sort(cuts)
 local used=0
 for i=1,count-1 do
  local top,bottom=cuts[i],cuts[i+1]
  if bottom>top then
   local intervals=self.intervals;local n=0
   if t.valid and t.top<bottom and t.bottom>top then n=n+1;intervals[n].left,intervals[n].right=Clamp(t.left,0,width),Clamp(t.right,0,width) end
   if a.valid and a.top<bottom and a.bottom>top then n=n+1;intervals[n].left,intervals[n].right=Clamp(a.left,0,width),Clamp(a.right,0,width) end
   if n==2 and intervals[1].left>intervals[2].left then intervals[1],intervals[2]=intervals[2],intervals[1] end
   local left=0
   for j=1,n do local r=intervals[j];if r.left>left then used=used+1;Rect(self.shades[used],left,top,r.left-left,bottom-top) end;left=math.max(left,r.right) end
   if left<width then used=used+1;Rect(self.shades[used],left,top,width-left,bottom-top) end
  end
 end
 for i=used+1,#self.shades do self.shades[i]:Hide() end
 if target.valid then self.hole=target;Rect(self.highlight,target.left,target.top,target.right-target.left,target.bottom-target.top) else self.hole=nil;self.highlight:Hide() end
end
function View:RememberLayout(shown)
 for i=1,24 do self.lastGeometry[i]=self.geometry[i] end
 self.layoutValid=true;self.layoutRevision=self.contentRevision;self.suspended=not shown
 SaveMetrics(self.layoutMetrics)
end
function View:SuspendCard()
 self.card:Hide();self.arrow:Hide();self.brandMotion:Stop();self.lastValid=false
 self:RememberLayout(false)
 return false
end
function View:SyncBrand(play)
 if self.mode~="intro" or not self.card:IsVisible() or A.UI.context:IsReducedMotion() then
  if self.brandMotion:IsPlaying() then self.brandMotion:Stop() end
 elseif play then self.brandMotion:Play() end
end
function View:Layout()
 if not self.root or not self.mode then return false end
 if not SameMetrics(self.layoutMetrics) then
  local C=A.UI.C
  C.DefaultFont(self.body,"bodyFontSize");C.DefaultLineHeight(self.body,"bodyLineHeight",false)
  C.DefaultFont(self.counter,"captionFontSize");C.DefaultLineHeight(self.counter,"captionLineHeight",true)
  for i,button in ipairs(self.buttons) do
   C.DefaultFont(button.label,i==1 and "buttonFontSize" or "captionFontSize")
   C.DefaultLineHeight(button.label,i==1 and "buttonLineHeight" or "captionLineHeight",false)
  end
 end
 local window=A.UI.frame;if self.mode~="intro" and not window:IsVisible() then self:Hide();return false end
 if self.mode=="intro" then self.root:SetScale(window:GetEffectiveScale()/UIParent:GetEffectiveScale()) end
 local width,height=window:GetWidth(),window:GetHeight();local left,top=window:GetLeft(),window:GetTop()
 if not left or not top then return false end
 local scale=UIParent:GetEffectiveScale()/window:GetEffectiveScale();local s=self.screen
 s.left,s.top,s.right,s.bottom=-left+4,top-UIParent:GetHeight()*scale+4,UIParent:GetWidth()*scale-left-4,top-4
 ReadRect(self.target,window,6,self.targetRect);ReadRect(self.avoidFrame,window,8,self.avoidRect);ReadRect(self.contextFrame,window,8,self.contextRect);ReadRect(self.revealFrame,window,6,self.revealRect)
 local t,a,c,r,g=self.targetRect,self.avoidRect,self.contextRect,self.revealRect,self.geometry
 g[1],g[2],g[3],g[4],g[5],g[6]=width,height,s.left,s.top,s.right,s.bottom
 g[7],g[8],g[9],g[10]=t.valid and t.left or false,t.valid and t.top or false,t.valid and t.right or false,t.valid and t.bottom or false
 g[11],g[12],g[13],g[14]=a.valid and a.left or false,a.valid and a.top or false,a.valid and a.right or false,a.valid and a.bottom or false
 g[15],g[16]=A.UI.context:IsReducedMotion(),A.UI.Theme.brandDuration
 g[17],g[18],g[19],g[20]=c.valid and c.left or false,c.valid and c.top or false,c.valid and c.right or false,c.valid and c.bottom or false
 g[21],g[22],g[23],g[24]=r.valid and r.left or false,r.valid and r.top or false,r.valid and r.right or false,r.valid and r.bottom or false
 local same=self.layoutValid and self.layoutRevision==self.contentRevision and SameMetrics(self.layoutMetrics)
 if same then for i=1,24 do if g[i]~=self.lastGeometry[i] then same=false;break end end end
 if same then return not self.suspended end
 if self.mode=="intro" then
  for _,shade in ipairs(self.shades) do shade:Hide() end
  self.highlight:Hide();self.hole,self.maskHole=nil,nil
 else self:LayoutMask(width,height) end
 local wasSuspended=self.suspended
 local available=s.right-s.left
 if available<=80 then return self:SuspendCard() end
 local cw,ch,x,y
 if self.mode=="intro" then
  self.compact=false;cw=math.min(520,available);ch=self:MeasureCard(cw);x,y=self:FindPlacement(cw,ch)
 else
  local bestScore,bestCompact
  -- Rank every readable width together by distance to the highlighted control.
  -- Compact padding helps confined layouts; the narrowest width is a rescue.
  for stage=1,2 do
   for pass=1,2 do
    self.compact=pass==2
    for index=stage==2 and 4 or 1,stage==2 and 4 or 3 do
     local candidateWidth=math.min(STEP_WIDTHS[index],available)
     local candidateHeight=self:MeasureCard(candidateWidth)
     local px,py,score=self:FindPlacement(candidateWidth,candidateHeight)
     if px then
      score=score+(candidateWidth-320)^2*.04+(self.compact and 900 or 0)
      if not bestScore or score<bestScore then
       x,y,cw,ch,bestCompact,bestScore=px,py,candidateWidth,candidateHeight,self.compact,score
      end
     end
    end
   end
   if x then break end
  end
  if x then self.compact=bestCompact;ch=self:MeasureCard(cw) end
 end
 if not x then return self:SuspendCard() end
 Rect(self.card,x,y,cw,ch);self:PlaceArrow(x,y,cw,ch)
 self.lastX,self.lastY,self.lastWidth,self.lastValid=x,y,cw,true
 self.lastCompact=self.compact
 Rect(self.body,self.bodyLeft,self.bodyTop,self.bodyWidth,self.bodyHeight)
 if self.mode=="step" then
  Rect(self.counter,self.compact and 12 or 20,self.compact and 14 or 20,math.max(1,cw-self.buttonLayout[2].width-52),A.UI.context:GetLineHeight("captionLineHeight"))
  self.brandAnchor:Hide()
 else
  Rect(self.brandAnchor,(cw-self.logoSize)/2,self.logoTop,self.logoSize,self.logoSize)
  if self.brandSize~=self.logoSize then self.brandSize=self.logoSize;self.brandMotion:SetSize(self.logoSize) end
 end
 self.counter:SetShown(self.mode=="step")
 for i,b in ipairs(self.buttons) do
  if self.mode=="intro" and i~=2 or self.mode=="step" and i==2 then local r=self.buttonLayout[i];Rect(b,r.x,r.y,r.width,r.height) else b:Hide() end
 end
 self:RememberLayout(true);self:SyncBrand(wasSuspended)
 return true
end
function View:SetAvoidFrame(frame)
 self.avoidFrame=frame;if self.root and self.mode then return self:Layout() end;return true
end
function View:SetContextFrame(frame)
 self.contextFrame=frame;if self.root and self.mode then return self:Layout() end;return true
end
function View:SetRevealFrame(frame)
 self.revealFrame=frame;if self.root and self.mode then return self:Layout() end;return true
end
function View:ShowStep(target,text,index,total)
 if not self:Build() then return false end
 self:AttachRoot(A.UI.frame);self.root:SetScale(1)
 local body=text or "";local changed=self.mode~="step" or self.text~=body
 if self.mode~="step" then self.brandMotion:Stop();self.body:SetJustifyH("LEFT");self.cardSurface:SetColor(A.UI.Theme.raised) end
 if self.mode~="step" or self.index~=index or self.target~=target then self.lastValid=false;self.layoutValid=false end
 local counter=("%d / %d"):format(index,total)
 if self.counter:GetText()~=counter then self.counter:SetText(counter) end
 self.mode,self.target,self.text,self.index="step",target,body,index
 if changed then self.body:SetText(body);self.layoutValid=false end
 changed=Label(self.buttons.skip,S("跳过","Skip")) or changed
 if changed then self.contentRevision=self.contentRevision+1 end
 local shown=self:Layout();if self.mode and not self.root:IsShown() then self.root:Show() end;return shown
end
function View:ShowIntroduction(text)
 if not self:Build() then return false end
 self:AttachRoot(UIParent)
 local visible=self.mode=="intro" and self.card:IsVisible()
 local body=text or "";local changed=self.mode~="intro" or self.text~=body
 if self.mode~="intro" then self.lastValid=false;self.layoutValid=false;self.body:SetJustifyH("CENTER");self.cardSurface:SetColor(A.UI.Theme.surface) end
 self.mode,self.target,self.avoidFrame,self.contextFrame,self.revealFrame,self.text,self.index="intro",nil,nil,nil,nil,body,nil
 if self.counter:GetText()~="" then self.counter:SetText("") end;if changed then self.body:SetText(body) end
 changed=Label(self.buttons.start,S("开始引导","Start guide")) or changed
 changed=Label(self.buttons.dismiss,S("不再显示","Don't show again")) or changed
 if changed then self.contentRevision=self.contentRevision+1;self.layoutValid=false end
 local shown=self:Layout();if self.mode and not self.root:IsShown() then self.root:Show() end
 self:SyncBrand(shown and not visible);return shown
end
function View:Hide()
 self.target,self.avoidFrame,self.contextFrame,self.revealFrame,self.hole,self.maskHole,self.mode,self.text,self.index=nil,nil,nil,nil,nil,nil,nil,nil,nil
 if not self.root then return end
 self.brandMotion:Stop();self.root:Hide();self.arrow:Hide();self.arrowSide=nil;self.layoutValid,self.lastValid,self.suspended=false,false,nil;self.measurement.revision=nil
 self.targetRect.valid,self.avoidRect.valid,self.contextRect.valid,self.revealRect.valid=false,false,false,false;self.revealActive=false;self.body:SetText("");self.counter:SetText("")
end
