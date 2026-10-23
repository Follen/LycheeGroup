local _, private = ...
local Library = private.LycheeUILoad
if not Library then return end

-- Registered controls keep their native identity and text. This module only
-- borrows layout, presentation and explicitly selected scripts.
local function Snapshot(region)
 local saved={parent=region:GetParent(),width=region:GetWidth(),height=region:GetHeight(),shown=region:IsShown(),
  level=region:GetFrameLevel(),strata=region:GetFrameStrata(),points={}}
 for i=1,region:GetNumPoints() do saved.points[i]={region:GetPoint(i)} end
 return saved
end
local function RestoreLayout(region,saved)
 region:Hide();region:SetParent(saved.parent);region:ClearAllPoints();region:SetSize(saved.width,saved.height)
 for _,point in ipairs(saved.points) do region:SetPoint(unpack(point)) end
 region:SetFrameStrata(saved.strata);region:SetFrameLevel(saved.level)
 region:SetShown(saved.shown)
end
local function TextStyle(region)
 return {region=region,font={region:GetFont()},color={region:GetTextColor()},shadow={region:GetShadowOffset()}}
end
local function Same(a,b)
 if #a~=#b then return false end
 for i,value in ipairs(a) do if value~=b[i] then return false end end
 return true
end
local function ApplyText(saved,context,color)
 local region=saved.region
 local theme=context.Theme
 region:SetFont(theme.font,context:GetFontSize("nativeFontSize"),"");region:SetTextColor(unpack(color));region:SetShadowOffset(0,0)
 -- Native setters may normalize font sizes and store colors as floats. The
 -- actual applied values identify our presentation during a foreign handoff.
 saved.applied={font={region:GetFont()},color={region:GetTextColor()},shadow={region:GetShadowOffset()}}
end
local function RestoreText(saved,owned)
 local region=saved.region
 local applied=saved.applied
 if owned or applied and Same({region:GetFont()},applied.font) then region:SetFont(unpack(saved.font)) end
 if owned or applied and Same({region:GetTextColor()},applied.color) then region:SetTextColor(unpack(saved.color)) end
 if owned or applied and Same({region:GetShadowOffset()},applied.shadow) then region:SetShadowOffset(unpack(saved.shadow)) end
end
local function SkinBorder(frame,control)
 if frame:GetObjectType()~="Frame" or select("#",frame:GetChildren())~=0 then return false end
 if math.abs(frame:GetWidth()-control:GetWidth())>1 or math.abs(frame:GetHeight()-control:GetHeight())>1 then return false end
 local regions={frame:GetRegions()};if #regions~=4 then return false end
 local horizontal,vertical=0,0
 for _,region in ipairs(regions) do
  if region:GetObjectType()~="Texture" or region:GetTexture()~=130871 then return false end
  local width,height=region:GetWidth(),region:GetHeight()
  if height<=1 and width>2 then horizontal=horizontal+1
  elseif width<=1 and height>2 then vertical=vertical+1 else return false end
 end
 return horizontal==2 and vertical==2
end

local Lease={};Lease.__index=Lease
local function Forward(control,previous,...)
 if previous then return previous(control,...) end
end
function Lease:IsOwned()
 return self.active and self.region:GetParent()==self.parent
  and (not self.box or self.box:GetParent()==self.boxParent)
  and (not self.options.owner or self.options.owner:IsOwned())
end
function Lease:Quiet(region)
 if not self.art[region] then self.art[region]={shown=region:IsShown(),alpha=region:GetAlpha()} end
 region:SetAlpha(0);region:Hide()
end
function Lease:QuietTextures(control)
 for _,region in ipairs({control:GetRegions()}) do
  -- Preserve engine cursors and selection, which have no texture path/atlas.
  if region:GetObjectType()=="Texture" and not region._lycheeNativeArt then
   local wholeField=math.abs(region:GetWidth()-control:GetWidth())<1 and math.abs(region:GetHeight()-control:GetHeight())<1
   if region:GetTexture()~=nil or region:GetAtlas()~=nil or wholeField then self:Quiet(region) end
  end
 end
 for _,key in ipairs({"NineSlice","Backdrop","backdrop","Border","border","Background"}) do
  if control[key] then self:Quiet(control[key]) end
 end
 for _,child in ipairs({control:GetChildren()}) do if SkinBorder(child,control) then self:Quiet(child) end end
 if control.GetBackdrop and control:GetBackdrop() then
  if not self.backdrops[control] then self.backdrops[control]={color={control:GetBackdropColor()},border={control:GetBackdropBorderColor()}} end
  control:SetBackdropColor(0,0,0,0);control:SetBackdropBorderColor(0,0,0,0)
 end
end
function Lease:Bind(target,event,handler)
 local previous=target:GetScript(event)
 local item={target=target,event=event,previous=previous}
 item.handler=function(control,...)
  if not self:IsOwned() then
   self:Release()
   if previous then return previous(control,...) end
  elseif handler then return handler(control,previous,...) end
 end
 self.scripts[#self.scripts+1]=item;target:SetScript(event,item.handler)
end
function Lease:Release()
 if not self.active then return end
 local owned=self:IsOwned()
 if owned and self.box then
  self.box:ClearFocus()
  if not self.active then return end
  owned=self:IsOwned()
 end
 self.active=false;self.context.nativeControls[self]=nil
 local restoreScripts={}
 for _,item in ipairs(self.scripts) do
  if item.target:GetScript(item.event)==item.handler then
   if self.box then item.target:SetScript(item.event,nil) else item.target:SetScript(item.event,item.previous) end
   restoreScripts[#restoreScripts+1]=item
  end
 end
 if self.box then
  for i=#self.context.inputs,1,-1 do if self.context.inputs[i]==self.box then table.remove(self.context.inputs,i);break end end
 end
 if self.finish then self:finish(owned) end
 -- Remove our presentation after a handoff only where it is still unchanged.
 for region,saved in pairs(self.art) do
  if owned or region:GetAlpha()==0 then region:SetAlpha(saved.alpha) end
  if owned or not region:IsShown() then region:SetShown(saved.shown) end
 end
 for control,saved in pairs(self.backdrops) do
  if owned or Same({control:GetBackdropColor()},{0,0,0,0}) then control:SetBackdropColor(unpack(saved.color)) end
  if owned or Same({control:GetBackdropBorderColor()},{0,0,0,0}) then control:SetBackdropBorderColor(unpack(saved.border)) end
 end
 if owned then
  RestoreLayout(self.region,self.layout)
 end
 if self.box then for _,item in ipairs(restoreScripts) do item.target:SetScript(item.event,item.previous) end end
 if not owned and self.options.onLost then self.options.onLost(self) end
 return owned
end
local function NewLease(context,region,parent,options)
 local lease=setmetatable({context=context,region=region,parent=parent,options=options or {},active=true,
  layout=Snapshot(region),scripts={},art={},backdrops={}},Lease)
 context.nativeControls[lease]=true
 if lease.options.restoreShown~=nil then lease.layout.shown=lease.options.restoreShown end
 return lease
end

function Library.AttachNative(context)
 local C,T,M=context.C,context.Theme,context.Motion
 context.nativeControls={};context.nativeButtonArt={}

 function C.NativeFrame(region,parent,options)
  local lease=NewLease(context,region,parent,options)
  region:SetParent(parent)
  return lease
 end

 function C.NativeInput(shell,box,options)
  options=options or {}
  local container=options.container or box
  local lease=NewLease(context,container,shell,options)
  local originalBoxParent=box:GetParent()
  lease.box,lease.shell=box,shell
  lease.boxParent=container==box and shell or box:GetParent()
  local font=TextStyle(box);local insets={box:GetTextInsets()};local width=box:GetWidth()
  local instructions=container~=box and box.Instructions
  local instructionWidth=instructions and instructions:GetWidth()
  local appliedInstructionWidth
  local ordinary=shell.box;local ordinaryShown=ordinary and ordinary:IsShown()
  local textStyles={}
  for _,region in ipairs({box:GetRegions()}) do if region:GetObjectType()=="FontString" then textStyles[#textStyles+1]=TextStyle(region) end end
  local scripts=options.scripts or {}
  local function Dispatch(event,input,previous,...)
   local callback=scripts[event]
   if callback~=nil then if callback then return callback(input,...) end
   elseif previous then return previous(input,...) end
  end
  local focus={OnEditFocusGained=true,OnEditFocusLost=true,OnEnter=true,OnLeave=true,OnHide=true}
  for event in pairs(focus) do
   local name=event
   lease:Bind(box,name,function(input,previous,...)
    Dispatch(name,input,previous,...)
    if not lease:IsOwned() then lease:Release();return end
    if name=="OnHide" then
     input:ClearFocus()
     if not lease:IsOwned() then lease:Release();return end
     shell:SetFocused(false)
    else shell:SetFocused(input:HasFocus(),name=="OnEnter") end
    if name=="OnEditFocusGained" then lease:RefreshStyle() end
   end)
  end
  for event in pairs(scripts) do
   if not focus[event] then
    local name=event
    lease:Bind(box,name,function(input,previous,...) return Dispatch(name,input,previous,...) end)
   end
  end
  -- Other browsers reparent and lay out these same fields when their pages
  -- open. Return our presentation on that layout event, before the next key
  -- or focus event; no polling or permanent method hook is needed.
  local function ResizeContent(control,previous,...)
   Forward(control,previous,...)
   if not lease:IsOwned() then lease:Release();return end
   -- The native template sizes its EditBox only on load. A borrowed viewport
   -- can resize later, so keep its text and instructions at the current width.
   box:SetWidth(shell:GetWidth()-(options.contentInset or 36))
   if not lease:IsOwned() then lease:Release();return end
   if instructions then
    instructions:SetWidth(box:GetWidth());appliedInstructionWidth=instructions:GetWidth()
   end
  end
  for _,event in ipairs({"OnShow","OnSizeChanged"}) do
   if container~=box or scripts[event]==nil then
    lease:Bind(container,event,container~=box and event=="OnSizeChanged" and ResizeContent or Forward)
   end
  end
  function lease:RefreshStyle()
   if not self:IsOwned() then return end
   ApplyText(font,context,T.text)
   if options.textInsets then box:SetTextInsets(unpack(options.textInsets)) end
   for _,saved in ipairs(textStyles) do
    ApplyText(saved,context,saved.region==box.Instructions and T.muted or T.text)
   end
   if instructions then
    instructions:SetWidth(box:GetWidth())
    appliedInstructionWidth=instructions:GetWidth()
   end
   self:QuietTextures(container);if container~=box then self:QuietTextures(box) end
   -- InputScrollFrameTemplate uses a MinimalScrollBar EventFrame. Keep its
   -- native range, percentage, thumb sizing and input scripts; replace art only.
   local bar=container.ScrollBar
   if bar and bar.Track and bar.Track.Thumb then
    local track,thumb=bar.Track,bar.Track.Thumb
    for _,part in ipairs({track,thumb,bar.Back,bar.Forward}) do self:QuietTextures(part) end
    local skin=thumb._lycheeNativeScrollArt
    if not skin then
     skin=thumb:CreateTexture(nil,"ARTWORK");skin._lycheeNativeArt=true
     skin:SetWidth(T.scrollWidth);skin:SetPoint("TOP",thumb,"TOP");skin:SetPoint("BOTTOM",thumb,"BOTTOM")
     thumb._lycheeNativeScrollArt=skin
    end
    self.scrollArt=skin;skin:SetWidth(T.scrollWidth);skin:SetColorTexture(unpack(T.accent));skin:SetAlpha(1);skin:Show()
   end
   for _,region in ipairs(options.hide or {}) do self:Quiet(region) end
  end
  function lease:finish(owned)
   if self.scrollArt then self.scrollArt:Hide() end
   RestoreText(font,owned)
   if owned or options.textInsets and Same({box:GetTextInsets()},options.textInsets) then box:SetTextInsets(unpack(insets)) end
   if container~=box and (owned or box:GetWidth()==shell:GetWidth()-(options.contentInset or 36)) then box:SetWidth(width) end
   if instructions and (owned or instructions:GetWidth()==appliedInstructionWidth) then instructions:SetWidth(instructionWidth) end
   for _,saved in ipairs(textStyles) do RestoreText(saved,owned) end
   if shell.box==box then shell.box=ordinary;if ordinary then ordinary:SetShown(ordinaryShown) end end
   shell:SetFocused(false)
  end
  if ordinary and ordinary~=box then
   ordinary:ClearFocus();if not lease.active then return lease end
   if container:GetParent()~=lease.layout.parent or box:GetParent()~=originalBoxParent or options.owner and not options.owner:IsOwned() then lease:Release();return lease end
  end
  shell.box=box
  if ordinary and ordinary~=box then
   ordinary:Hide();if not lease.active then return lease end
   if container:GetParent()~=lease.layout.parent or box:GetParent()~=originalBoxParent or options.owner and not options.owner:IsOwned() then lease:Release();return lease end
  end
  container:SetParent(shell)
  if not lease:IsOwned() then lease:Release();return lease end
  container:ClearAllPoints()
  local pad=options.padding or {10,7,10,7}
  container:SetPoint("TOPLEFT",shell,"TOPLEFT",pad[1],-pad[2]);container:SetPoint("BOTTOMRIGHT",shell,"BOTTOMRIGHT",-pad[3],pad[4])
  if not lease:IsOwned() then lease:Release();return lease end
  container:SetSize(shell:GetWidth()-pad[1]-pad[3],shell:GetHeight()-pad[2]-pad[4])
  if not lease:IsOwned() then lease:Release();return lease end
  if container~=box then
   box:SetWidth(shell:GetWidth()-(options.contentInset or 36))
   if not lease:IsOwned() then lease:Release();return lease end
  end
  context.inputs[#context.inputs+1]=box
  container:Show()
  if not lease:IsOwned() then lease:Release();return lease end
  lease:RefreshStyle();shell:SetFocused(box:HasFocus())
  return lease
 end

 -- Style a real native button without replacing or invoking its OnClick.
 function C.NativeButton(button,options)
  options=options or {}
  local lease=NewLease(context,button,button:GetParent(),options)
  local label=button:GetFontString();local font=TextStyle(label)
  local text,alpha,buttonAlpha=button:GetText(),label:GetAlpha(),button:GetAlpha()
  lease:QuietTextures(button)
  local fill=context.nativeButtonArt[button]
  if not fill then
   fill=C.Panel(button,"accent","nativeButtonRadius");context.nativeButtonArt[button]=fill
   for _,region in ipairs(fill.regions) do region._lycheeNativeArt=true end
  end
  lease.fill=fill;fill:SetColor(T.accent);fill:SetAlpha(1);fill:Show()
  function lease:finish(owned)
   M:Stop(fill);fill:Hide()
   RestoreText(font,owned)
   if owned then label:SetAlpha(alpha) end
   if owned or button:GetAlpha()==(button:IsEnabled() and 1 or T.disabledAlpha) then button:SetAlpha(buttonAlpha) end
   if owned or options.text and button:GetText()==options.text then button:SetText(text) end
  end
  local inside,pressed
  function lease:RefreshStyle()
   if self:IsOwned() then ApplyText(font,context,T.onPrimary);fill:SetRadius(T.nativeButtonRadius);fill:SetColor(button:IsEnabled() and (pressed and T.primaryPressed or inside and T.primaryHover) or T.primary);button:SetAlpha(button:IsEnabled() and 1 or T.disabledAlpha);button:SetSize(math.max(options.minWidth or T.nativeButtonMinWidth,label:GetStringWidth()+T.nativeButtonPadding),T.nativeButtonHeight) end
  end
  lease:RefreshStyle()
  if options.text then button:SetText(options.text) end
  button:SetSize(math.max(options.minWidth or T.nativeButtonMinWidth,label:GetStringWidth()+T.nativeButtonPadding),T.nativeButtonHeight)
  if not lease:IsOwned() then lease:Release();return lease end
  local function Surface(immediate)
   if not lease:IsOwned() then lease:Release();return end
   local enabled=button:IsEnabled()
   button:SetAlpha(enabled and 1 or T.disabledAlpha)
   M:Color(fill,enabled and (pressed and T.primaryPressed or inside and T.primaryHover) or T.primary,not immediate and T.feedbackDuration or nil)
  end
  lease:Bind(button,"OnEnter",function(b,previous,...) if previous then previous(b,...) end;inside=true;Surface() end)
  lease:Bind(button,"OnLeave",function(b,previous,...) if previous then previous(b,...) end;inside=nil;pressed=nil;Surface() end)
  lease:Bind(button,"OnMouseDown",function(b,previous,...) if previous then previous(b,...) end;pressed=b:IsEnabled();Surface() end)
  lease:Bind(button,"OnMouseUp",function(b,previous,...) if previous then previous(b,...) end;pressed=nil;Surface() end)
  lease:Bind(button,"OnEnable",function(b,previous,...) if previous then previous(b,...) end;Surface(true) end)
  lease:Bind(button,"OnDisable",function(b,previous,...) if previous then previous(b,...) end;pressed=nil;Surface(true) end)
  Surface(true)
  button:Show()
  if not lease:IsOwned() then lease:Release() end
  return lease
 end
end

function Library.Context:ReleaseNativeControls()
 -- Release dependants before the frame that hosts them.
 local pending={};for lease in pairs(self.nativeControls) do pending[#pending+1]=lease end
 local function release(lease)
  for _,child in ipairs(pending) do if child.active and child.options.owner==lease then release(child) end end
  lease:Release()
 end
 for _,lease in ipairs(pending) do if lease.active then release(lease) end end
end
