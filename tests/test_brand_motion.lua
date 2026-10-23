-- Product logo trajectory through the generic task driver; no game is contacted.
local base=dofile("tests/stubs.lua");base.Install({locale="enUS",realm="Home"})
local S=dofile("tests/ui_stubs.lua");S.Install()
_G.LycheeUI=nil
local private={}
for _,file in ipairs({"Core.lua","Theme.lua","Motion.lua","Styles.lua","Components.lua","Layouts.lua","Elements.lua","Native.lua","Menu.lua"}) do assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/"..file))("LycheeGroup",private) end
_G.LycheeGroup={};dofile("addon/LycheeGroup/BrandMotion.lua")
local A=LycheeGroup
local reduced=false
local context=LycheeUI:CreateContext({themeDefaults={brandDuration=1.386},reducedMotion=function() return reduced end})
local M=context.Motion
local anchor=CreateFrame("Frame",nil,UIParent)
local logo=anchor:CreateTexture(nil,"ARTWORK");logo:SetSize(44,44);logo:SetPoint("CENTER",anchor,"CENTER",0,0)
local brand=A:CreateBrandMotion(context,logo,anchor,44)
local function Rest(size,message)
 T.eq(logo:GetWidth(),size,message);T.eq(logo:GetHeight(),size)
 local point,parent,relative,x,y=logo:GetPoint()
 T.eq(point,"CENTER");T.eq(parent,anchor);T.eq(relative,"CENTER");T.eq(x,0);T.eq(y,0)
 T.eq(brand:IsPlaying(),false)
end
T.eq(context.logo,nil);T.eq(context.logoButton,nil)
T.eq(M.Brand,nil,"the shared driver exposes no product Brand method")
brand:Play();M:Tick(.7);T.eq(M:Count(),1,"brand uses one finite generic task")
brand:Play();T.near(brand.elapsed,.7,.000001,"playing again cannot restart the current cycle")
M:Tick(.8);Rest(44,"brand settles after crossing its 1.386 second endpoint")
T.eq(M:Count(),0);T.eq(M.driver:GetScript("OnUpdate"),nil)
do
 local original=logo.ClearAllPoints;local clears=0
 logo.ClearAllPoints=function(self) clears=clears+1;original(self) end
 brand:Play();local setup=clears
 for _=1,138 do M:Tick(.01) end
 T.eq(clears,setup,"brand updates its existing anchor without detaching it each frame")
 M:Tick(.01);logo.ClearAllPoints=original;Rest(44)
end
do
 -- Independent bisection checks every millisecond of all five design segments.
 local poses={{.168,1.075,.925,0,.42,0,.70,1,.42,0,.75,1},{.504,.960,1.045,7,.16,.6,.25,1,.16,.6,.25,1},{.840,1.035,.965,0,.30,0,.60,1,.42,0,.60,1},{1.092,.990,1.012,1,.16,.7,.30,1,.16,.7,.30,1},{1.386,1,1,0,.20,.7,.30,1,.20,.7,.30,1}}
 local function reference(u,x1,y1,x2,y2)
  if u<=0 then return 0 elseif u>=1 then return 1 end
  local lo,hi,t=0,1,u
  for _=1,24 do
   local x=3*(1-t)^2*t*x1+3*(1-t)*t*t*x2+t^3
   if x<u then lo=t else hi=t end;t=(lo+hi)/2
  end
  return 3*(1-t)^2*t*y1+3*(1-t)*t*t*y2+t^3
 end
 local second=anchor:CreateTexture(nil,"ARTWORK");second:SetSize(38,38);second:SetPoint("CENTER",anchor,"CENTER",0,0)
 local floating=A:CreateBrandMotion(context,second,anchor,38)
 local elapsed,segment,maxError=0,1,0
 brand:Play();floating:Play();T.eq(M:Count(),2,"two product owners coexist in the same generic driver")
 for _=1,1385 do
  elapsed=elapsed+.001;M:Tick(.001)
  while elapsed>poses[segment][1] do segment=segment+1 end
  local pose,previous=poses[segment],poses[segment-1] or {0,1,1,0}
  local u=(elapsed-previous[1])/(pose[1]-previous[1])
  local s=reference(u,pose[5],pose[6],pose[7],pose[8])
  local m=reference(u,pose[9],pose[10],pose[11],pose[12])
  local x,y=previous[2]+(pose[2]-previous[2])*s,previous[3]+(pose[3]-previous[3])*s
  for _,entry in ipairs({{logo,44},{second,38}}) do
   local texture,size=entry[1],entry[2]
   local offset=size/128*(39*(y-1)+previous[4]+(pose[4]-previous[4])*m)
   maxError=math.max(maxError,math.abs(texture:GetWidth()-size*x),math.abs(texture:GetHeight()-size*y),math.abs(select(5,texture:GetPoint())-offset))
  end
 end
 T.ok(maxError<.00001,"main and floating scales preserve all five original scale and pivot trajectories")
 M:Tick(.002);Rest(44);T.eq(second:GetWidth(),38);T.eq(floating:IsPlaying(),false);T.eq(M:Count(),0)
end
brand:Play();M:Tick(.168);brand:Stop();Rest(44,"explicit cancellation restores the resting pose")
logo:SetSize(99,99);brand:Stop();Rest(44,"stopping an idle controller also restores its static pose")
brand:Play();M:Tick(.2);M:StopAll();Rest(44,"generic StopAll invokes the product task's reset")
brand:Play();M:Tick(.2);brand:SetSize(34);Rest(34,"changing host size cancels and restores at the new size")
brand:SetSize(38);Rest(38)
reduced=true;brand:Play();T.eq(M:Count(),0,"reduced motion starts no brand task");Rest(38)
reduced=false;context.Theme.brandDuration=0;brand:Play();Rest(38,"zero duration immediately retains the resting pose")
context.Theme.brandDuration=2.772;brand:Play();M:Tick(.336)
T.near(logo:GetWidth(),38*1.075,.000001,"the product duration still scales the original trajectory")
brand:Stop();context.Theme.brandDuration=1.386
S.preciseNow=100.056;brand:Play();S.preciseNow=100.057;M.driver:Fire("OnUpdate",.057)
T.ok(logo:GetWidth()>38 and logo:GetWidth()<38.02,"a cold 57ms frame advances only the brand task's actual 1ms lifetime")
T.near(brand.elapsed,.001,.000001)
S.preciseNow=100.064;M.driver:Fire("OnUpdate",.007);T.near(brand.elapsed,.008,.000001,"later ticks retain the full elapsed frame time")
brand:Stop();Rest(38);T.eq(M:Count(),0);T.eq(M.driver:GetScript("OnUpdate"),nil)
