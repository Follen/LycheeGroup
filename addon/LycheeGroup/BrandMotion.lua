-- Product-owned Lychee logo trajectory, shared by the main window and reminder.
local A=_G.LycheeGroup
local function coefficients(x1,y1,x2,y2)
 local cx,cy=3*x1,3*y1
 local bx,by=3*(x2-x1)-cx,3*(y2-y1)-cy
 return {1-cx-bx,bx,cx,1-cy-by,by,cy}
end
local function bezier(u,c)
 if u<=0 then return 0 elseif u>=1 then return 1 end
 local ax,bx,cx,ay,by,cy=c[1],c[2],c[3],c[4],c[5],c[6]
 local t=u
 -- The fixed product curves have positive x slopes throughout their domain.
 for _=1,5 do
  t=t-(((ax*t+bx)*t+cx)*t-u)/((3*ax*t+2*bx)*t+cx)
 end
 return ((ay*t+by)*t+cy)*t
end
-- Segment end, X/Y scale, lift in original image units, scale/move Beziers.
local poses={
 {.168,1.075,.925,0,.42,0,.70,1,.42,0,.75,1},
 {.504,.960,1.045,7,.16,.6,.25,1,.16,.6,.25,1},
 {.840,1.035,.965,0,.30,0,.60,1,.42,0,.60,1},
 {1.092,.990,1.012,1,.16,.7,.30,1,.16,.7,.30,1},
 {1.386,1,1,0,.20,.7,.30,1,.20,.7,.30,1},
}
-- Compile once; every product controller shares these immutable curve records.
for index,pose in ipairs(poses) do
 local previous=poses[index-1]
 pose.start=previous and previous[1] or 0
 pose.inverseDuration=1/(pose[1]-pose.start)
 pose.x,pose.y,pose.offset=previous and previous[2] or 1,previous and previous[3] or 1,previous and previous[4] or 0
 pose.dx,pose.dy,pose.dOffset=pose[2]-pose.x,pose[3]-pose.y,pose[4]-pose.offset
 pose.scaleCurve=coefficients(pose[5],pose[6],pose[7],pose[8])
 if pose.dOffset~=0 then
  local same=pose[5]==pose[9] and pose[6]==pose[10] and pose[7]==pose[11] and pose[8]==pose[12]
  pose.moveCurve=same and pose.scaleCurve or coefficients(pose[9],pose[10],pose[11],pose[12])
 end
end
local Controller={};Controller.__index=Controller
function Controller:IsPlaying() return self.context.Motion:IsRunning(self) end
function Controller:Play()
 if self:IsPlaying() or self.context:IsReducedMotion() then return end
 if self.context.Theme.brandDuration==0 then self:Stop();return end
 self.elapsed,self.segment=0,1
 self.texture:ClearAllPoints();self.texture:SetPoint("CENTER",self.anchor,"CENTER",0,0)
 self.context.Motion:Start(self,self.step,self.reset)
end
function Controller:Stop()
 if self:IsPlaying() then self.context.Motion:Stop(self) else self.reset() end
end
function Controller:SetSize(size)
 self.size=size;self:Stop()
end
function A:CreateBrandMotion(context,texture,anchor,size)
 local controller=setmetatable({context=context,texture=texture,anchor=anchor,size=size},Controller)
 controller.reset=function()
  texture:SetSize(controller.size,controller.size);texture:ClearAllPoints();texture:SetPoint("CENTER",anchor,"CENTER",0,0)
 end
 controller.step=function(dt)
  controller.elapsed=controller.elapsed+dt*1.386/context.Theme.brandDuration
  if controller.elapsed>=1.386 then return true end
  while controller.elapsed>poses[controller.segment][1] do controller.segment=controller.segment+1 end
  local pose=poses[controller.segment]
  local u=(controller.elapsed-pose.start)*pose.inverseDuration
  local s=bezier(u,pose.scaleCurve)
  local m=pose.moveCurve and pose.moveCurve~=pose.scaleCurve and bezier(u,pose.moveCurve) or s
  local x,y=pose.x+pose.dx*s,pose.y+pose.dy*s
  texture:SetSize(controller.size*x,controller.size*y)
  -- The Lychee artwork's pivot is (64,103) in its original 128-square image.
  texture:SetPoint("CENTER",anchor,"CENTER",0,controller.size/128*(39*(y-1)+pose.offset+pose.dOffset*m))
  return false
 end
 return controller
end
