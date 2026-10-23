local _, private = ...
local Library = private.LycheeUILoad
if not Library then return end

local empty={}
local defaultPadding={10,7,10,7}
local focusEvents={OnEditFocusGained=true,OnEditFocusLost=true,OnEnter=true,OnLeave=true,OnHide=true}
local focusOrder={"OnEditFocusGained","OnEditFocusLost","OnEnter","OnLeave","OnHide"}
local layoutEvents={"OnShow","OnSizeChanged"}
local decorationNames={"NineSlice","Backdrop","backdrop","Border","border","Background"}

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
 local saved={region=region}
 saved[1],saved[2],saved[3]=region:GetFont()
 saved[4],saved[5],saved[6],saved[7]=region:GetTextColor()
 saved[8],saved[9]=region:GetShadowOffset()
 return saved
end
local function ApplyText(saved,context,color)
 local region=saved.region
 region:SetFont(context.fontPath,context:GetFontSize("nativeFontSize"),"");region:SetTextColor(unpack(color));region:SetShadowOffset(0,0)
 -- Read actual values back: native setters may normalize size and color.
 saved[10],saved[11],saved[12]=region:GetFont()
 saved[13],saved[14],saved[15],saved[16]=region:GetTextColor()
 saved[17],saved[18]=region:GetShadowOffset()
end
local function RestoreText(saved,owned)
 local region=saved.region
 local path,size,flags=region:GetFont()
 if owned or path==saved[10] and size==saved[11] and flags==saved[12] then region:SetFont(saved[1],saved[2],saved[3]) end
 local r,g,b,a=region:GetTextColor()
 if owned or r==saved[13] and g==saved[14] and b==saved[15] and a==saved[16] then region:SetTextColor(saved[4],saved[5],saved[6],saved[7]) end
 local x,y=region:GetShadowOffset()
 if owned or x==saved[17] and y==saved[18] then region:SetShadowOffset(saved[8],saved[9]) end
end
local function SkinRegions(control,...)
 if select("#",...)~=4 then return false end
 local horizontal,vertical=0,0
 for index=1,4 do
  local region=select(index,...)
  if region:GetObjectType()~="Texture" or region:GetTexture()~=130871 then return false end
  local width,height=region:GetWidth(),region:GetHeight()
  if height<=1 and width>2 then horizontal=horizontal+1
  elseif width<=1 and height>2 then vertical=vertical+1 else return false end
 end
 return horizontal==2 and vertical==2
end
local function SkinBorder(frame,control)
 if frame:GetObjectType()~="Frame" or select("#",frame:GetChildren())~=0 then return false end
 if math.abs(frame:GetWidth()-control:GetWidth())>1 or math.abs(frame:GetHeight()-control:GetHeight())>1 then return false end
 return SkinRegions(control,frame:GetRegions())
end
local function ZeroColor(r,g,b,a) return r==0 and g==0 and b==0 and a==0 end
local function SameInsets(box,values)
 local left,right,top,bottom=box:GetTextInsets()
 return left==values[1] and right==values[2] and top==values[3] and bottom==values[4]
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
 if not self.art then self.art={};self.artShown={} end
 if self.art[region]==nil then self.art[region]=region:GetAlpha();self.artShown[region]=region:IsShown() end
 region:SetAlpha(0);region:Hide()
end
local function QuietRegions(lease,control,...)
 for index=1,select("#",...) do
  local region=select(index,...)
  -- Preserve engine cursor/selection art with no texture path or atlas.
  if region:GetObjectType()=="Texture" and not region._lycheeNativeArt then
   local wholeField=math.abs(region:GetWidth()-control:GetWidth())<1 and math.abs(region:GetHeight()-control:GetHeight())<1
   if region:GetTexture()~=nil or region:GetAtlas()~=nil or wholeField then lease:Quiet(region) end
  end
 end
end
local function QuietChildren(lease,control,...)
 for index=1,select("#",...) do local child=select(index,...);if SkinBorder(child,control) then lease:Quiet(child) end end
end
function Lease:QuietTextures(control)
 QuietRegions(self,control,control:GetRegions())
 for _,key in ipairs(decorationNames) do if control[key] then self:Quiet(control[key]) end end
 QuietChildren(self,control,control:GetChildren())
 if control.GetBackdrop and control:GetBackdrop() then
  self.backdrops=self.backdrops or {}
  if not self.backdrops[control] then
   local saved={};saved[1],saved[2],saved[3],saved[4]=control:GetBackdropColor();saved[5],saved[6],saved[7],saved[8]=control:GetBackdropBorderColor();self.backdrops[control]=saved
  end
  control:SetBackdropColor(0,0,0,0);control:SetBackdropBorderColor(0,0,0,0)
 end
end
local function Bind(lease,target,event,handler,withLease)
 local previous=target:GetScript(event)
 local wrapper=function(control,...)
  if not lease:IsOwned() then
   lease:Release()
   if previous then return previous(control,...) end
  elseif handler then
   if withLease then return handler(lease,event,control,previous,...) end
   return handler(control,previous,...)
  end
 end
 local scripts=lease.scripts;if not scripts then scripts={};lease.scripts=scripts end
 local index=lease.scriptCount*5;lease.scriptCount=lease.scriptCount+1
 scripts[index+1],scripts[index+2],scripts[index+3],scripts[index+4]=target,event,previous,wrapper
 target:SetScript(event,wrapper)
end
function Lease:Bind(target,event,handler) Bind(self,target,event,handler) end
function Lease:Release()
 if not self.active then return end
 local owned=self:IsOwned()
 if owned and self.box then
  self.box:ClearFocus()
  if not self.active then return end
  owned=self:IsOwned()
 end
 self.active=false;self.context.nativeControls[self]=nil
 local scripts=self.scripts or empty
 for index=1,self.scriptCount*5,5 do
  local target,event,previous,handler=scripts[index],scripts[index+1],scripts[index+2],scripts[index+3]
  if target:GetScript(event)==handler then
   target:SetScript(event,not self.box and previous or nil);scripts[index+4]=true
  end
 end
 if self.box then
  for i=#self.context.inputs,1,-1 do if self.context.inputs[i]==self.box then table.remove(self.context.inputs,i);break end end
 end
 if self.finish then self:finish(owned) end
 -- Remove our presentation after a handoff only where it is still unchanged.
 for region,alpha in pairs(self.art or empty) do
  if owned or region:GetAlpha()==0 then region:SetAlpha(alpha) end
  if owned or not region:IsShown() then region:SetShown(self.artShown[region]) end
 end
 for control,saved in pairs(self.backdrops or empty) do
  if owned or ZeroColor(control:GetBackdropColor()) then control:SetBackdropColor(saved[1],saved[2],saved[3],saved[4]) end
  if owned or ZeroColor(control:GetBackdropBorderColor()) then control:SetBackdropBorderColor(saved[5],saved[6],saved[7],saved[8]) end
 end
 if owned then
  RestoreLayout(self.region,self.layout)
 end
 if self.box then for index=1,self.scriptCount*5,5 do if scripts[index+4] then scripts[index]:SetScript(scripts[index+1],scripts[index+2]) end end end
 if not owned and self.options.onLost then self.options.onLost(self) end
 return owned
end
local function NewLease(context,region,parent,options)
 local lease=setmetatable({context=context,region=region,parent=parent,options=options or empty,active=true,
  layout=Snapshot(region),scriptCount=0},Lease)
 context.nativeControls[lease]=true
 if lease.options.restoreShown~=nil then lease.layout.shown=lease.options.restoreShown end
 return lease
end

local function CaptureTextStyles(into,...)
 for index=1,select("#",...) do local region=select(index,...);if region:GetObjectType()=="FontString" then into[#into+1]=TextStyle(region) end end
end
local function QuietParts(lease,...)
 for index=1,select("#",...) do local part=select(index,...);if not part then break end;lease:QuietTextures(part) end
end
local function DispatchInput(lease,event,input,previous,...)
 local callback=lease.inputScripts[event]
 if callback~=nil then if callback then return callback(input,...) end
 elseif previous then return previous(input,...) end
end
local function InputFocus(lease,event,input,previous,...)
 DispatchInput(lease,event,input,previous,...)
 if not lease:IsOwned() then lease:Release();return end
 if event=="OnHide" then
  input:ClearFocus()
  if not lease:IsOwned() then lease:Release();return end
  lease.shell:SetFocused(false)
 else lease.shell:SetFocused(input:HasFocus(),event=="OnEnter") end
 if event=="OnEditFocusGained" then lease:RefreshStyle() end
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
  options=options or empty
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
  CaptureTextStyles(textStyles,box:GetRegions())
  local scripts=options.scripts or empty
  lease.inputScripts=scripts
  for _,event in ipairs(focusOrder) do Bind(lease,box,event,InputFocus,true) end
  for event in pairs(scripts) do if not focusEvents[event] then Bind(lease,box,event,DispatchInput,true) end end
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
  for _,event in ipairs(layoutEvents) do
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
    QuietParts(self,track,thumb,bar.Back,bar.Forward)
    local skin=thumb._lycheeNativeScrollArt
    if not skin then
     skin=thumb:CreateTexture(nil,"ARTWORK");skin._lycheeNativeArt=true
     skin:SetWidth(T.scrollWidth);skin:SetPoint("TOP",thumb,"TOP");skin:SetPoint("BOTTOM",thumb,"BOTTOM")
     thumb._lycheeNativeScrollArt=skin
    end
    self.scrollArt=skin;skin:SetWidth(T.scrollWidth);skin:SetColorTexture(unpack(T.accent));skin:SetAlpha(1);skin:Show()
   end
   for _,region in ipairs(options.hide or empty) do self:Quiet(region) end
   -- Focus refresh is a native presentation boundary; retain an explicitly
   -- registered, still-owned input's element font/color after the native skin.
   C.ApplyElement(box)
  end
  function lease:finish(owned)
   if self.scrollArt then self.scrollArt:Hide() end
   RestoreText(font,owned)
   if owned or options.textInsets and SameInsets(box,options.textInsets) then box:SetTextInsets(unpack(insets)) end
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
  -- Reparenting invalidates native anchor dimensions until a later frame.
  -- Identify full-field fills and border strips while their original geometry
  -- is still resolved, then retain those snapshots through the move.
  lease:QuietTextures(container)
  if container~=box then lease:QuietTextures(box) end
  if not lease.active then return lease end
  if container:GetParent()~=lease.layout.parent or box:GetParent()~=originalBoxParent or options.owner and not options.owner:IsOwned() then lease:Release();return lease end
  container:SetParent(shell)
  if not lease:IsOwned() then lease:Release();return lease end
  container:ClearAllPoints()
  local pad=options.padding or defaultPadding
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
  options=options or empty
  local lease=NewLease(context,button,button:GetParent(),options)
  local label=button:GetFontString();local font=TextStyle(label)
  local text,alpha,buttonAlpha=button:GetText(),label:GetAlpha(),button:GetAlpha()
  lease:QuietTextures(button)
  if not lease:IsOwned() then lease:Release();return lease end
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
   if not self:IsOwned() then self:Release() end
  end
  lease:RefreshStyle()
  if not lease:IsOwned() then lease:Release();return lease end
  if options.text then button:SetText(options.text) end
  if not lease:IsOwned() then lease:Release();return lease end
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
