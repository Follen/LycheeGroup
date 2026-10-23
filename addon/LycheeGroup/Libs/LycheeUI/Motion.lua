local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
local function curve(p) return p*(2-p) end
function Library.CreateMotion(UI)
-- 单一驱动;switches/alphas 记录进行中动画的终值,StopAll 据此落终态不留残影。
local T=UI.Theme
local presenceKey={}
local M = {jobs={}, jobIds={}, nextJobId=0, startTimes={}, stops={}, switches={}, alphas={}, alphaFinishes={}, colors={}, placements={},reveals={},rects={},selections={},waiting={},busy={},spins={},spinOwners={},tickBuffer={}}
local function Pixel(value,scale) return math.floor(value*scale+.5)/scale end
local function PlaceReveal(state,x,y,alpha)
 local region=state.region
 local scale=region:GetEffectiveScale()
 x,y=Pixel(x,scale),Pixel(y,scale)
 if state.x~=x or state.y~=y then
  region:SetPoint(state[1],state[2],state[3],x,y);state.x,state.y=x,y
 end
 if region:GetAlpha()~=alpha then region:SetAlpha(alpha) end
end
local function PlaceRect(state,x,y,width,height)
 local region=state.region
 local scale=region:GetEffectiveScale()
 x,y,width,height=Pixel(x,scale),Pixel(y,scale),Pixel(width,scale),Pixel(height,scale)
 if state.x~=x or state.y~=y then
  region:SetPoint("TOPLEFT",state.parent,"TOPLEFT",x,y);state.x,state.y=x,y
 end
 if state.width~=width or state.height~=height then
  region:SetSize(width,height);state.width,state.height=width,height
 end
end
local function PlaceSelection(state,alpha)
 local region=state.region
 if region:GetAlpha()~=alpha then region:SetAlpha(alpha) end
 if alpha==0 and not region._selMotion then region:Hide() end
end
local function RestoreWaiting(region,saved)
 region:SetSize(saved.width,saved.height);region:SetAlpha(saved.alpha)
 region:ClearAllPoints();if saved.point[1] then region:SetPoint(unpack(saved.point)) end
end
local function Drive(_, elapsed)
 M:Tick(elapsed,next(M.startTimes) and GetTimePreciseSec() or nil)
end
function M:Start(key, job, onStop)
 if not self.driver then self.driver=CreateFrame("Frame") end
 local previousStop=self.stops[key]
 self.jobs[key]=job
 self.stops[key]=onStop
 self.nextJobId=self.nextJobId+1;self.jobIds[key]=self.nextJobId
 self.startTimes[key]=GetTimePreciseSec()
 if not self.running then
  self.running=true;self.driver:SetScript("OnUpdate",Drive);self.driver:Show()
 end
 if previousStop then previousStop() end
end
function M:IsRunning(key) return self.jobs[key]~=nil end
function M:Stop(key,keepRect)
 local rect=not keepRect and self.rects[key]
 if rect then self:Stop(rect) end
 local onStop=self.stops[key]
 self.jobs[key]=nil;self.stops[key]=nil
 self.jobIds[key]=nil
 self.startTimes[key]=nil
 if key==presenceKey then self.presenceFinished=nil end
 if self.waiting[key] then RestoreWaiting(key,self.waiting[key]);self.waiting[key]=nil end
 if self.busy[key] then key:SetAlpha(self.busy[key]);self.busy[key]=nil end
 if self.spins[key] then key:SetRotation(0);self.spins[key]=nil end
 self.switches[key]=nil;self.alphas[key]=nil;self.alphaFinishes[key]=nil;self.colors[key]=nil;self.placements[key]=nil
 if self.running and not next(self.jobs) then
  self.running=false;self.driver:SetScript("OnUpdate",nil);self.driver:Hide()
 end
 if onStop then onStop() end
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
 local elapsed=0
 self:Start(texture,function(dt)
  if UI:IsReducedMotion() then self:Spin(texture,false);return true end
  local cycle=period or T.spinPeriod
  elapsed=(elapsed+dt)%cycle;texture:SetRotation(-2*math.pi*elapsed/cycle)
 end)
end

-- One owner moves and fades; child geometry and hit targets are not animated.
function M:Reveal(region,point,parent,relative,x,y,dx,dy,duration)
 duration=duration or T.revealDuration
 local state=self.reveals[region]
 if not state then
  state={region=region};self.reveals[region]=state
  state.step=function(dt)
   state.elapsed=math.min(state.duration,state.elapsed+dt)
   local p=curve(state.elapsed/state.duration)
   PlaceReveal(state,state.fromX+(state[4]-state.fromX)*p,state.fromY+(state[5]-state.fromY)*p,state.fromAlpha+(1-state.fromAlpha)*p)
   if state.elapsed==state.duration then self.placements[region]=nil;return true end
  end
 end
 local active=self.jobs[region]==state.step
 local currentPoint,currentParent,currentRelative,currentX,currentY=region:GetPoint()
 local sameAnchor=active and state[1]==point and state[2]==parent and state[3]==relative
  and currentPoint==point and currentParent==parent and currentRelative==relative and region:GetNumPoints()==1
 local relaid=false
 if sameAnchor then
  -- Reconcile caller layout at the public entry; ticks retain the pixel cache.
  local scale=region:GetEffectiveScale()
  currentX,currentY=Pixel(currentX,scale),Pixel(currentY,scale)
  relaid=state.x~=currentX or state.y~=currentY
  state.x,state.y=currentX,currentY
 end
 if sameAnchor and not relaid and state[4]==x and state[5]==y and duration~=0 and not UI:IsReducedMotion() then return end
 local fromX,fromY,fromAlpha=x+(dx or 0),y+(dy or 0),.35
 if sameAnchor then fromX,fromY,fromAlpha=state.x,state.y,region:GetAlpha() end
 self:Stop(region)
 state[1],state[2],state[3],state[4],state[5]=point,parent,relative,x,y
 if not sameAnchor then region:ClearAllPoints();state.x,state.y=nil,nil end
 if duration==0 or UI:IsReducedMotion() then PlaceReveal(state,x,y,1);return end
 state.fromX,state.fromY,state.fromAlpha=fromX,fromY,fromAlpha
 state.elapsed,state.duration=0,duration or T.revealDuration
 PlaceReveal(state,fromX,fromY,fromAlpha)
 self.placements[region]=state
 self.alphas[region]=1
 self:Start(region,state.step)
end
function M:FinishPlacement(region)
 local target=self.placements[region]
 if target then PlaceReveal(target,target[4],target[5],1) end
 self:Stop(region)
end
-- Passive highlight geometry owns a separate job key, so its opacity/color
-- transition can run on the same region without cancelling the movement.
function M:Rect(region,x,y,width,height,duration)
 duration=duration or T.revealDuration
 local state=self.rects[region]
 if not state then
  state={region=region};self.rects[region]=state
  state.step=function(dt)
   state.elapsed=math.min(state.duration,state.elapsed+dt)
   local p=curve(state.elapsed/state.duration)
   PlaceRect(state,state.fromX+(state.toX-state.fromX)*p,state.fromY+(state.toY-state.fromY)*p,state.fromWidth+(state.toWidth-state.fromWidth)*p,state.fromHeight+(state.toHeight-state.fromHeight)*p)
   return state.elapsed==state.duration
  end
 end
 local scale=region:GetEffectiveScale()
 local parent=region:GetParent()
 local point,anchor,relative,currentX,currentY=region:GetPoint()
 if state.parent~=parent or point~="TOPLEFT" or anchor~=parent or relative~="TOPLEFT" or region:GetNumPoints()~=1 then
  self:Stop(state);state.parent=parent;state.x,state.y,state.width,state.height=nil,nil,nil,nil
  region:ClearAllPoints()
 elseif state.x then
  -- Callers may re-layout a reusable region between transitions. Reconcile at
  -- the entry point; animation ticks still write only changed physical pixels.
  currentX,currentY=Pixel(currentX,scale),Pixel(currentY,scale)
  local currentWidth,currentHeight=Pixel(region:GetWidth(),scale),Pixel(region:GetHeight(),scale)
  if state.x~=currentX or state.y~=currentY or state.width~=currentWidth or state.height~=currentHeight then
   self:Stop(state);state.x,state.y,state.width,state.height=currentX,currentY,currentWidth,currentHeight
  end
 end
 x,y,width,height=Pixel(x,scale),Pixel(y,scale),Pixel(width,scale),Pixel(height,scale)
 local same=state.toX==x and state.toY==y and state.toWidth==width and state.toHeight==height
 if same and duration~=0 and not UI:IsReducedMotion() and (self.jobs[state] or (state.x==x and state.y==y and state.width==width and state.height==height)) then return end
 self:Stop(state)
 state.toX,state.toY,state.toWidth,state.toHeight=x,y,width,height
 if not state.x or duration==0 or UI:IsReducedMotion() or (state.x==x and state.y==y and state.width==width and state.height==height) then
  PlaceRect(state,x,y,width,height);return
 end
 state.fromX,state.fromY,state.fromWidth,state.fromHeight=state.x,state.y,state.width,state.height
 state.elapsed,state.duration=0,duration or T.revealDuration
 self:Start(state,state.step)
end
function M:FinishRect(region)
 local state=self.rects[region]
 if not state then return end
 PlaceRect(state,state.toX,state.toY,state.toWidth,state.toHeight);self:Stop(state)
end
function M:Busy(region,enabled)
 self:Stop(region)
 region:SetShown(enabled)
 if not enabled then return end
 self.busy[region]=region:GetAlpha()
 if UI:IsReducedMotion() then region:SetAlpha(1);return end
 local elapsed=0
 self:Start(region,function(dt)
  elapsed=(elapsed+dt)%T.busyPeriod
  region:SetAlpha(T.busyAlpha+(1-T.busyAlpha)*(.5+.5*math.sin(elapsed/T.busyPeriod*math.pi*2)))
 end)
end
-- Waiting changes only the supplied region while the caller enables it.
function M:Waiting(region,enabled)
 self:Stop(region);region:SetShown(enabled)
 if not enabled then return end
 local saved={width=region:GetWidth(),height=region:GetHeight(),alpha=region:GetAlpha(),point={region:GetPoint()}}
 self.waiting[region]=saved
 if UI:IsReducedMotion() then return end
 local elapsed,placed=0,false
 self:Start(region,function(dt)
  elapsed=(elapsed+dt)%T.waitingPeriod;local wave=.5-.5*math.cos(elapsed/T.waitingPeriod*math.pi*2)
  region:SetSize(saved.width*(1+T.waitingWidth*wave),saved.height*(1-T.waitingHeight*wave));region:SetAlpha(T.waitingAlpha+(1-T.waitingAlpha)*wave)
  if not placed then region:ClearAllPoints();placed=true end
  if saved.point[1] then region:SetPoint(saved.point[1],saved.point[2],saved.point[3],saved.point[4],saved.point[5]+wave*T.waitingOffset) end
 end)
end
function M:Count() local count=0;for _ in pairs(self.jobs) do count=count+1 end;return count end
local function RunTasks(snapshot,count,elapsed,now)
 for i=1,count,3 do
  local key,job,jobId=snapshot[i],snapshot[i+1],snapshot[i+2]
  snapshot[i],snapshot[i+1],snapshot[i+2]=nil,nil,nil
  if M.jobIds[key]==jobId then
   local started=M.startTimes[key];M.startTimes[key]=nil
   -- OnUpdate elapsed covers the entire frame, including work before a new
   -- task existed. Only its first driver tick needs this lifetime clamp.
   local dt=now and started and math.max(0,math.min(elapsed,now-started)) or elapsed
   local finished=job(dt)
   if finished and M.jobIds[key]==jobId then M:Stop(key,true) end
  end
 end
end
function M:Tick(elapsed,now)
 local nested=self.ticking
 local snapshot,count=nested and {} or self.tickBuffer,0
 for key,job in pairs(self.jobs) do
  count=count+3;snapshot[count-2],snapshot[count-1],snapshot[count]=key,job,self.jobIds[key]
 end
 self.ticking=true
 local ok,message=pcall(RunTasks,snapshot,count,elapsed,now)
 self.ticking=nested
 if not ok then
  for index=1,count do snapshot[index]=nil end
  error(message,0)
 end
end
function M:Alpha(region,target,duration,initial,finished)
 self:Stop(region,true)
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
 self.alphaFinishes[region]=finished
 self:Start(region,function(dt)
  elapsed=math.min(duration,elapsed+dt)
  region:SetAlpha(from+(target-from)*curve(elapsed/duration))
  if elapsed==duration then
   self.alphas[region]=nil
   self.alphaFinishes[region]=nil
   if finished then finished() end
   return true
  end
 end)
end
-- Surface transitions share the finite driver and reuse one color per transition.
function M:Color(panel,target,duration)
 if duration and not UI:IsReducedMotion() and self.colors[panel]==target then return end
 self:Stop(panel,true)
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
function M:Selection(region,selected,duration)
 duration=duration or T.selectionDuration
 local state=self.selections[region]
 if not state then
  state={region=region};self.selections[region]=state
  state.step=function(dt)
   state.elapsed=math.min(state.duration,state.elapsed+dt)
   local p=curve(state.elapsed/state.duration)
   PlaceSelection(state,state.from+(state.target-state.from)*p)
   return state.elapsed==state.duration
  end
 end
 if region._selMotion==selected and duration~=0 and not UI:IsReducedMotion() then return end
 local from=region:IsShown() and region:GetAlpha() or 0
 if selected and (not region:IsShown() or region._selMotion==nil) then from=0 end
 region._selMotion=selected
 self:Stop(region,true)
 state.target=selected and 1 or 0
 if selected then region:Show() end
 if duration==0 or UI:IsReducedMotion() or from==state.target then PlaceSelection(state,state.target);return end
 state.from,state.elapsed,state.duration=from,0,duration or T.selectionDuration
 PlaceSelection(state,from)
 self.alphas[region]=state.target
 self:Start(region,state.step)
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
  local offset=math.floor(-T.presenceOffset*(1-curve(p))*pixelScale+.5)/pixelScale
  local x,y=self.originX or 0,(self.originY or 0)+offset
  local u=T.presenceFadeDuration==0 and (p>0 and 1 or 0) or math.min(1,p*T.presenceDuration/T.presenceFadeDuration)
  -- Zero slope at both ends keeps the final visible frame close to transparent.
  local alpha=u*u*(3-2*u)
  if self.lastX~=x or self.lastY~=y then
   frame:SetPoint(self.anchorPoint or "CENTER",self.anchorRelative or UI.parent,self.anchorRelativePoint or "CENTER",x,y)
   self.lastX,self.lastY=x,y
  end
  if self.lastAlpha~=alpha then frame:SetAlpha(alpha);self.lastAlpha=alpha end
end
function M:StopPresence() self:Stop(presenceKey) end
function M:Presence(shown,finished)
 local target=shown and 1 or 0
 local phase=self.phase or 0
 self:StopPresence()
 self.presenceTarget,self.presenceFinished=shown,finished
 self:SetPresence(phase)
 if UI:IsReducedMotion() or T.presenceDuration==0 or phase==target then self:SetPresence(target);self.presenceFinished=nil;if finished then finished() end;return end
 local direction=shown and 1 or -1
 self:Start(presenceKey,function(dt)
  phase=math.max(0,math.min(1,phase+direction*dt/T.presenceDuration));self:SetPresence(phase)
  if phase==target then self.presenceFinished=nil;if finished then finished() end;return true end
 end)
end
-- 开关滑块:180ms 位置反馈;终值入册供 StopAll 落位。
function M:Switch(region,from,to)
 from=region._slideX or from
 self:Stop(region)
 if UI:IsReducedMotion() or T.switchDuration==0 then
  self.switches[region]=nil
  region:ClearAllPoints();region:SetPoint("LEFT",region:GetParent(),"LEFT",to,0);region._slideX=to
  return
 end
 local elapsed,placed=0,false
 self.switches[region]=to
 self:Start(region,function(dt)
  elapsed=math.min(T.switchDuration,elapsed+dt)
  region._slideX=from+(to-from)*curve(elapsed/T.switchDuration)
  if not placed then region:ClearAllPoints();placed=true end
  region:SetPoint("LEFT",region:GetParent(),"LEFT",region._slideX,0)
  if elapsed==T.switchDuration then self.switches[region]=nil;return true end
 end)
end
-- 停止全部活动动画,并把进行中的滑块与透明度直接置于终态。
function M:StopAll(keepPersistent)
 local callbacks
 for texture in pairs(self.spins) do if not keepPersistent then texture:SetRotation(0);self.spins[texture]=nil end end
 for region,saved in pairs(self.waiting) do RestoreWaiting(region,saved);if not keepPersistent then self.waiting[region]=nil end end
 for region,alpha in pairs(self.busy) do region:SetAlpha(alpha);if not keepPersistent then self.busy[region]=nil end end
 for region,target in pairs(self.placements) do PlaceReveal(target,target[4],target[5],1);self.placements[region]=nil end
 for _,state in pairs(self.rects) do if self.jobs[state] then PlaceRect(state,state.toX,state.toY,state.toWidth,state.toHeight) end end
 for region,state in pairs(self.selections) do if self.jobs[region]==state.step then PlaceSelection(state,state.target) end end
 for key in pairs(self.jobs) do
  if not keepPersistent or not (key==presenceKey or self.spins[key] or self.waiting[key] or self.busy[key] or self.alphaFinishes[key]) then
   local onStop=self.stops[key]
   if onStop then callbacks=callbacks or {};callbacks[#callbacks+1]=onStop end
   self.jobs[key]=nil;self.jobIds[key]=nil;self.startTimes[key]=nil;self.stops[key]=nil
  end
 end
 if not keepPersistent then self.presenceFinished=nil end
 if self.running and not next(self.jobs) then self.running=false;self.driver:SetScript("OnUpdate",nil);self.driver:Hide() end
 for region,to in pairs(self.switches) do
  region:ClearAllPoints();region:SetPoint("LEFT",region:GetParent(),"LEFT",to,0);region._slideX=to
 end
 for region,target in pairs(self.alphas) do if not keepPersistent or not self.alphaFinishes[region] then region:SetAlpha(target) end end
 for panel,target in pairs(self.colors) do panel:SetColor(target) end
 for region in pairs(self.switches) do self.switches[region]=nil end
 for region in pairs(self.alphas) do if not keepPersistent or not self.alphaFinishes[region] then self.alphas[region]=nil end end
 if not keepPersistent then for region in pairs(self.alphaFinishes) do self.alphaFinishes[region]=nil end end
 for panel in pairs(self.colors) do self.colors[panel]=nil end
 -- Detach and settle this batch before callbacks. A callback may start new
 -- work or re-enter StopAll without losing or repeating an old cleanup.
 if callbacks then
  local failed,message=false,nil
  for index=1,#callbacks do
   local callback=callbacks[index];callbacks[index]=nil
   local ok,err=pcall(callback)
   if not ok and not failed then failed,message=true,err end
  end
  if failed then error(message,0) end
 end
end

return M
end
