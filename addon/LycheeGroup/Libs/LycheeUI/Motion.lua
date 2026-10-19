local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
local function curve(p) return p*(2-p) end
local function coefficients(x1,y1,x2,y2)
 local cx,cy=3*x1,3*y1
 local bx,by=3*(x2-x1)-cx,3*(y2-y1)-cy
 return {1-cx-bx,bx,cx,1-cy-by,by,cy}
end
local function bezier(u,c)
 if u<=0 then return 0 elseif u>=1 then return 1 end
 local ax,bx,cx,ay,by,cy=c[1],c[2],c[3],c[4],c[5],c[6]
 local t=u
 -- These fixed brand curves have positive x slopes. Five Newton steps cover
 -- their full domain; no per-frame powers, search tables or fallback solver.
 for _=1,5 do
  t=t-(((ax*t+bx)*t+cx)*t-u)/((3*ax*t+2*bx)*t+cx)
 end
 return ((ay*t+by)*t+cy)*t
end
-- 品牌五段(与 Desgin §7、主 Lychee brandPoses 一致):段末时间、X/Y 缩放、上移(原图单位)、缩放与位移 bezier。
local poses={
 {.168,1.075,.925,0,.42,0,.70,1,.42,0,.75,1},
 {.504,.960,1.045,7,.16,.6,.25,1,.16,.6,.25,1},
 {.840,1.035,.965,0,.30,0,.60,1,.42,0,.60,1},
 {1.092,.990,1.012,1,.16,.7,.30,1,.16,.7,.30,1},
 {1.386,1,1,0,.20,.7,.30,1,.20,.7,.30,1},
}
-- Immutable curve data is compiled once and shared by all window contexts.
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
function Library.CreateMotion(UI)
-- 单一驱动;switches/alphas 记录进行中动画的终值,StopAll 据此落终态不留残影。
local M = {jobs={}, jobIds={}, nextJobId=0, startTimes={}, switches={}, alphas={}, colors={}, placements={},waiting={},busy={},spins={},spinOwners={},tickBuffer={}}
local function RestoreWaiting(region,saved)
 region:SetSize(saved.width,saved.height);region:SetAlpha(saved.alpha)
 region:ClearAllPoints();if saved.point[1] then region:SetPoint(unpack(saved.point)) end
end
local function Drive(_, elapsed)
 M:Tick(elapsed,next(M.startTimes) and GetTimePreciseSec() or nil)
end
function M:Start(key, job)
 if not self.driver then self.driver=CreateFrame("Frame") end
 self.jobs[key]=job
 self.nextJobId=self.nextJobId+1;self.jobIds[key]=self.nextJobId
 self.startTimes[key]=GetTimePreciseSec()
 if not self.running then
  self.running=true;self.driver:SetScript("OnUpdate",Drive);self.driver:Show()
 end
end
function M:Stop(key)
 self.jobs[key]=nil
 self.jobIds[key]=nil
 self.startTimes[key]=nil
 if self.waiting[key] then RestoreWaiting(key,self.waiting[key]);self.waiting[key]=nil end
 if self.busy[key] then key:SetAlpha(self.busy[key]);self.busy[key]=nil end
 if self.spins[key] then key:SetRotation(0);self.spins[key]=nil end
 self.switches[key]=nil;self.alphas[key]=nil;self.colors[key]=nil;self.placements[key]=nil
 if self.running and not next(self.jobs) then
  self.running=false;self.driver:SetScript("OnUpdate",nil);self.driver:Hide()
 end
end

-- refresh-spin: 900ms linear clockwise, only while the caller is busy.
function M:Spin(region,enabled,period)
 local texture=region._lycheeTexture or region
 if not enabled or UI:IsReducedMotion() then self:Stop(texture);texture:SetRotation(0);return end
 if self.spins[texture] then return end
 self:Stop(texture);self.spins[texture]=true
 if not self.spinOwners[texture] then
  local owner=region._lycheeTexture and region or region:GetParent()
  owner:HookScript("OnHide",function() self:Spin(texture,false) end)
  self.spinOwners[texture]=true
 end
 local elapsed=0;period=period or .9
 self:Start(texture,function(dt)
  if UI:IsReducedMotion() then self:Spin(texture,false);return true end
  elapsed=(elapsed+dt)%period;texture:SetRotation(-2*math.pi*elapsed/period)
 end)
end

-- One owner moves and fades; child geometry and hit targets are not animated.
function M:Reveal(region,point,parent,relative,x,y,dx,dy,duration)
 self:FinishPlacement(region)
 local placement={point,parent,relative,x,y}
 self.placements[region]=placement
 region:ClearAllPoints()
 if duration==0 or UI:IsReducedMotion() then region:SetPoint(point,parent,relative,x,y);region:SetAlpha(1);self.placements[region]=nil;return end
 region:SetPoint(point,parent,relative,x+(dx or 0),y+(dy or 0));region:SetAlpha(.35)
 local elapsed=0
 self.alphas[region]=1
 self:Start(region,function(dt)
  elapsed=math.min(duration or .18,elapsed+dt)
  local p=curve(elapsed/(duration or .18))
  region:SetPoint(point,parent,relative,x+(dx or 0)*(1-p),y+(dy or 0)*(1-p))
  region:SetAlpha(.35+.65*p)
  if p==1 then self.placements[region]=nil;return true end
 end)
end
function M:FinishPlacement(region)
 local target=self.placements[region]
 if target then region:ClearAllPoints();region:SetPoint(unpack(target));region:SetAlpha(1);self.placements[region]=nil end
 self:Stop(region)
end
function M:Busy(region,enabled)
 self:Stop(region)
 region:SetShown(enabled)
 if not enabled then return end
 self.busy[region]=region:GetAlpha()
 if UI:IsReducedMotion() then region:SetAlpha(1);return end
 local elapsed=0
 self:Start(region,function(dt)
  elapsed=(elapsed+dt)%.9
  region:SetAlpha(.35+.65*(.5+.5*math.sin(elapsed/.9*math.pi*2)))
 end)
end
-- Waiting is local to the lychee texture and lives only for an active search.
function M:Waiting(region,enabled)
 self:Stop(region);region:SetShown(enabled)
 if not enabled then return end
 local saved={width=region:GetWidth(),height=region:GetHeight(),alpha=region:GetAlpha(),point={region:GetPoint()}}
 self.waiting[region]=saved
 if UI:IsReducedMotion() then return end
 local elapsed,placed=0,false
 self:Start(region,function(dt)
  elapsed=(elapsed+dt)%1.2;local wave=.5-.5*math.cos(elapsed/1.2*math.pi*2)
  region:SetSize(saved.width*(1+.035*wave),saved.height*(1-.025*wave));region:SetAlpha(.65+.35*wave)
  if not placed then region:ClearAllPoints();placed=true end
  if saved.point[1] then region:SetPoint(saved.point[1],saved.point[2],saved.point[3],saved.point[4],saved.point[5]+wave*3) end
 end)
end
function M:Count() local count=0;for _ in pairs(self.jobs) do count=count+1 end;return count end
function M:Tick(elapsed,now)
 local snapshot,count=self.tickBuffer,0
 for key,job in pairs(self.jobs) do
  count=count+3;snapshot[count-2],snapshot[count-1],snapshot[count]=key,job,self.jobIds[key]
 end
 for i=1,count,3 do
  local key,job,jobId=snapshot[i],snapshot[i+1],snapshot[i+2]
  snapshot[i],snapshot[i+1],snapshot[i+2]=nil,nil,nil
  if self.jobIds[key]==jobId then
   local started=self.startTimes[key];self.startTimes[key]=nil
   -- OnUpdate elapsed covers the entire frame, including work before a new
   -- task existed. Only its first driver tick needs this lifetime clamp.
   local dt=now and started and math.max(0,math.min(elapsed,now-started)) or elapsed
   local finished=job(dt)
   if finished and self.jobIds[key]==jobId then self:Stop(key) end
  end
 end
end
function M:Alpha(region,target,duration,initial,finished)
 self:Stop(region)
 local from=initial or region:GetAlpha()
 if duration==0 or UI:IsReducedMotion() or from==target then
  self.alphas[region]=nil
  region:SetAlpha(target)
  if finished then finished() end
  return
 end
 local elapsed=0
 region:SetAlpha(from)
 self.alphas[region]=target
 self:Start(region,function(dt)
  elapsed=math.min(duration,elapsed+dt)
  region:SetAlpha(from+(target-from)*curve(elapsed/duration))
  if elapsed==duration then
   self.alphas[region]=nil
   if finished then finished() end
   return true
  end
 end)
end
-- Surface transitions share the finite driver and reuse one color per transition.
function M:Color(panel,target,duration)
 if duration and not UI:IsReducedMotion() and self.colors[panel]==target then return end
 self:Stop(panel)
 local from=panel.color
 if UI:IsReducedMotion() or not duration or from==target then panel:SetColor(target);return end
 local elapsed,value=0,{}
 self.colors[panel]=target
 self:Start(panel,function(dt)
  elapsed=math.min(duration,elapsed+dt)
  if elapsed==duration then panel:SetColor(target);self.colors[panel]=nil;return true end
  local p=curve(elapsed/duration)
  for i=1,4 do value[i]=(from[i] or 1)+((target[i] or 1)-(from[i] or 1))*p end
  panel:SetColor(value)
 end)
end
-- 选择反馈:100ms 局部过渡;取消后彻底隐藏,不留半透明残影。
function M:Selection(region,selected)
 if region._selMotion==selected then return end
 region._selMotion=selected
 if selected then
  region:Show()
  self:Alpha(region,1,.10,0)
 else
  self:Alpha(region,0,.10,nil,function() if region._selMotion~=true then region:Hide() end end)
 end
end
-- 主窗轨迹:420ms、终点下方 64 进入;前 100ms 完成透明渐入;关闭精确倒放,中途反向从当前相位连续继续。
function M:CapturePosition()
 self.anchorPoint,self.anchorRelative,self.anchorRelativePoint,self.originX,self.originY=UI.frame:GetPoint()
 self.lastX,self.lastY=nil,nil
end
function M:SetPresence(p)
 local frame=UI.frame
  self.phase=p
  local pixelScale=frame:GetEffectiveScale()
  local offset=math.floor(-64*(1-curve(p))*pixelScale+.5)/pixelScale
  local x,y=self.originX or 0,(self.originY or 0)+offset
  local u=math.min(1,p*.42/.10)
  -- Zero slope at both ends keeps the final visible frame close to transparent.
  local alpha=u*u*(3-2*u)
  if self.lastX~=x or self.lastY~=y then
   frame:SetPoint(self.anchorPoint or "CENTER",self.anchorRelative or UI.parent,self.anchorRelativePoint or "CENTER",x,y)
   self.lastX,self.lastY=x,y
  end
  if self.lastAlpha~=alpha then frame:SetAlpha(alpha);self.lastAlpha=alpha end
end
function M:Presence(shown,finished)
 local target=shown and 1 or 0
 local phase=self.phase or 0
 self:Stop("presence")
 self:SetPresence(phase)
 if UI:IsReducedMotion() or phase==target then self:SetPresence(target);if finished then finished() end;return end
 local direction=shown and 1 or -1
 self:Start("presence",function(dt)
  phase=math.max(0,math.min(1,phase+direction*dt/.42));self:SetPresence(phase)
  if phase==target then if finished then finished() end;return true end
 end)
end
function M:StopBrand()
 self:Stop("brand")
 if UI.logo then local size=UI.Theme.logoSize;UI.logo:SetSize(size,size);UI.logo:ClearAllPoints();UI.logo:SetPoint("CENTER",UI.logoButton,"CENTER",0,0) end
end
-- 变换只作用于图标自身(枢轴 64,103,原图 128),不移动父容器、命中区或标题。
function M:Brand()
 if self.jobs.brand or UI:IsReducedMotion() then return end
 local elapsed,segment=0,1
 local logo=UI.logo
 logo:ClearAllPoints();logo:SetPoint("CENTER",UI.logoButton,"CENTER",0,0)
 self:Start("brand",function(dt)
  elapsed=elapsed+dt
  if elapsed>=1.386 then self:StopBrand();return true end
  while elapsed>poses[segment][1] do segment=segment+1 end
  local pose=poses[segment]
  local u=(elapsed-pose.start)*pose.inverseDuration
  local s=bezier(u,pose.scaleCurve)
  local m=pose.moveCurve and pose.moveCurve~=pose.scaleCurve and bezier(u,pose.moveCurve) or s
  local x,y=pose.x+pose.dx*s,pose.y+pose.dy*s
  local size=UI.Theme.logoSize
  logo:SetSize(size*x,size*y)
  logo:SetPoint("CENTER",UI.logoButton,"CENTER",0,size/128*(39*(y-1)+pose.offset+pose.dOffset*m))
  return false
 end)
end
-- 开关滑块:180ms 位置反馈;终值入册供 StopAll 落位。
function M:Switch(region,from,to)
 from=region._slideX or from
 self:Stop(region)
 if UI:IsReducedMotion() then
  self.switches[region]=nil
  region:ClearAllPoints();region:SetPoint("LEFT",region:GetParent(),"LEFT",to,0);region._slideX=to
  return
 end
 local elapsed,placed=0,false
 self.switches[region]=to
 self:Start(region,function(dt)
  elapsed=math.min(.18,elapsed+dt)
  region._slideX=from+(to-from)*curve(elapsed/.18)
  if not placed then region:ClearAllPoints();placed=true end
  region:SetPoint("LEFT",region:GetParent(),"LEFT",region._slideX,0)
  if elapsed==.18 then self.switches[region]=nil;return true end
 end)
end
-- 停止全部活动动画,并把进行中的滑块与透明度直接置于终态。
function M:StopAll()
 for texture in pairs(self.spins) do texture:SetRotation(0);self.spins[texture]=nil end
 for region,saved in pairs(self.waiting) do RestoreWaiting(region,saved);self.waiting[region]=nil end
 for region,alpha in pairs(self.busy) do region:SetAlpha(alpha);self.busy[region]=nil end
 for region,target in pairs(self.placements) do region:ClearAllPoints();region:SetPoint(unpack(target));region:SetAlpha(1);self.placements[region]=nil end
 for key in pairs(self.jobs) do self.jobs[key]=nil;self.jobIds[key]=nil;self.startTimes[key]=nil end
 if self.running then self.running=false;self.driver:SetScript("OnUpdate",nil);self.driver:Hide() end
 for region,to in pairs(self.switches) do
  region:ClearAllPoints();region:SetPoint("LEFT",region:GetParent(),"LEFT",to,0);region._slideX=to
 end
 for region,target in pairs(self.alphas) do region:SetAlpha(target) end
 for panel,target in pairs(self.colors) do panel:SetColor(target) end
 for region in pairs(self.switches) do self.switches[region]=nil end
 for region in pairs(self.alphas) do self.alphas[region]=nil end
 for panel in pairs(self.colors) do self.colors[panel]=nil end
 self:StopBrand()
end

return M
end
