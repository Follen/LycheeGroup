local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
Library.layoutModes={flex=true}
function Library.AttachLayouts(UI)
 local C=UI.C
 local empty={}
 UI.layouts={};UI.boxes=setmetatable({},{__mode="k"})
 local function Value(value) if type(value)~="string" then return value end;return UI:ResolveValue(value) end
 local function Padding(value,target)
  if type(value)~="table" then local n=Value(value or 0);return n,n,n,n end
  local context
  if target then
   context=C._FixedValueContext and C._FixedValueContext(target,"padding")
   if not context and target._lycheeBoxValues and target._lycheeBoxValues.padding==value then context=target._lycheeBoxContext end
  end
  if context and context~=UI then return context:ResolveValue(value.left or value[1] or 0),context:ResolveValue(value.top or value[2] or 0),context:ResolveValue(value.right or value[3] or 0),context:ResolveValue(value.bottom or value[4] or 0) end
  return Value(value.left or value[1] or 0),Value(value.top or value[2] or 0),Value(value.right or value[3] or 0),Value(value.bottom or value[4] or 0)
 end
 local measurements=setmetatable({},{__mode="k"})
 local measurementRevision=0
 local measure
 local function MeasureText(label,text,widthOnly,signature)
  local path,size,flags,spacing,wrap,current
  if signature then
   path,size,flags,spacing,wrap,current=signature.contentPath,signature.contentSize,signature.contentFlags,signature.contentSpacing,signature.contentWrap,signature.contentText
  else
   path,size,flags=label:GetFont();spacing=label:GetSpacing() or 0;wrap=label:CanWordWrap();current=label:GetText() or ""
  end
  local font=UI.fontStyles[label];local line=font and font.lineHeight;local single=font and font.singleLine
  local cached=measurements[label]
  if not cached then cached={values={},keys={},cursor=0,revision=0};measurements[label]=cached end
  if cached.invalidated~=measurementRevision or cached.path~=path or cached.size~=size or cached.flags~=flags or cached.spacing~=spacing or cached.line~=line or cached.single~=single or cached.wrap~=wrap then
   cached.path,cached.size,cached.flags,cached.spacing,cached.line,cached.single=path,size,flags,spacing,line,single
   cached.wrap=wrap
   cached.invalidated=measurementRevision;cached.revision=cached.revision+1
  end
  local candidate=text~=nil;text=text or current
  local record;if candidate then record=cached.values[text] else record=cached.current end
  if not record then
   if candidate then
    local index=cached.cursor%16+1;cached.cursor=index
    local previous=cached.keys[index];record=previous and cached.values[previous] or {}
    if previous then cached.values[previous]=nil end
    cached.keys[index],cached.values[text]=text,record
   else record={};cached.current=record end
  end
  if record.text~=text or record.revision~=cached.revision then
   record.text,record.revision=text,cached.revision
   record.naturalWidth,record.assignedWidth,record.height=nil,nil,nil
  end
  if record.naturalWidth==nil then
   if text==current then record.naturalWidth=label.GetUnboundedStringWidth and label:GetUnboundedStringWidth() or label:GetStringWidth()
   else
    if not measure then measure=UI.parent:CreateFontString(nil,"OVERLAY");measure:Hide() end
    measure:SetFont(path,size,flags);measure:SetSpacing(spacing);measure:SetWordWrap(false);measure:SetWidth(0);measure:SetText(text)
    record.naturalWidth=measure.GetUnboundedStringWidth and measure:GetUnboundedStringWidth() or measure:GetStringWidth()
   end
  end
  local naturalWidth=record.naturalWidth
  if naturalWidth==0 and text~="" then record.naturalWidth=nil end
  if widthOnly then return naturalWidth end
  local assigned=label:GetWidth()
  if record.assignedWidth~=assigned then
   record.assignedWidth=assigned
   if text==current then record.height=label:GetStringHeight()
   else
    if not measure then measure=UI.parent:CreateFontString(nil,"OVERLAY");measure:Hide() end
    measure:SetFont(path,size,flags);measure:SetSpacing(spacing);measure:SetText(text);measure:SetWidth(assigned);measure:SetWordWrap(wrap);record.height=measure:GetStringHeight()
   end
  end
  local height=record.height;if height==0 and text~="" then record.assignedWidth=nil end
  return naturalWidth,height
 end
 function C.InvalidateTextMetrics(label)
  if label then local cached=measurements[label];if cached then cached.invalidated=nil end
  else measurementRevision=measurementRevision+1 end
 end
 function C.MeasureText(label,text) return MeasureText(label,text,false) end
 function C.MeasureTextWidth(label,text) return MeasureText(label,text,true) end
 local defaultMeasureText=C.MeasureText
 local function Natural(frame,signature)
  if signature and C.MeasureText==defaultMeasureText then return MeasureText(frame,nil,false,signature) end
  if frame.GetStringWidth then return C.MeasureText(frame) end
  return frame:GetWidth(),frame:GetHeight()
 end
 -- Enhanced geometry is opt-in; the legacy controller below retains its r46
 -- semantics. All enhanced controllers in a context share these methods.
 local Flex={}
 local flexMeta={__index=Flex}
 local function ClearPreparedOwners(self)
  if not self.ownerSnapshots then return end
  for _,r in pairs(self.records) do r.ownerWidth,r.ownerHeight,r.ownerPoints,r.ownerPointField=nil,nil,nil,nil end
  self.boxOwnerWidth,self.boxOwnerHeight=nil,nil;self.ownerSnapshots=false
 end
 local axisKeys={"width","height","minWidth","maxWidth","minHeight","maxHeight","basis","grow","shrink","align","gapAfter","manageWidth","manageHeight","managePoints"}
 local projectionKeys={"width","height","minWidth","maxWidth","minHeight","maxHeight","basis","grow","shrink","align","gapAfter","manageWidth","manageHeight","managePoints","participate","reserve"}
 local inputKeys={"width","height","minWidth","maxWidth","minHeight","maxHeight","basis","grow","shrink","align","gapAfter","manageWidth","manageHeight","managePoints","hidden","reserve","participate"}
 local savedInputKeys,savedInputByKey={},{};for i,key in ipairs(inputKeys) do local saved="_input_"..key;savedInputKeys[i],savedInputByKey[key]=saved,saved end
 local function Field(target,key,fallback)
  if not target._lycheeFixedRecords and not (target._lycheeStyleController and target._lycheeStyleController._conditionDirty) then
   local box=target._lycheeBoxValues
   if key~="width" and key~="height" and box and box[key]~=nil then return box[key] end
   return fallback
  end
  if C.LayoutValue then return C.LayoutValue(target,key,fallback) end
  local value=C.FixedValue(target,key,nil)
  if value~=nil then return value end
  return fallback
 end
 local function Finite(value,name)
  if type(value)~="number" or value~=value or value==math.huge or value==-math.huge or value<0 then error("LycheeUI flex: invalid "..name,3) end
  return value
 end
 local function Dimension(value,available,name)
  if value==nil or value=="content" then return nil end
  if value=="fill" then if available==nil then error("LycheeUI flex: fill depends on content axis ("..name..")",3) end;return Finite(available,name) end
  if type(value)=="string" then
   local percent=value:match("^([%d%.]+)%%$")
   if percent then
    if available==nil then error("LycheeUI flex: percentage depends on content axis ("..name..")",3) end
    return Finite(tonumber(percent),name)*available/100
   end
   value=Value(value)
  end
  return Finite(value,name)
 end
 local function Scale(frame)
  local n=frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
  return n and n>0 and n<math.huge and n or 1
 end
 local function NativeSize(frame)
  if frame.GetSize then return frame:GetSize() end
  return frame:GetWidth(),frame:GetHeight()
 end
 local function Clamp(n,minimum,maximum) return math.max(minimum,math.min(maximum,n)) end
 local function Same(a,b) return math.abs(a-b)<=.0000001*math.max(1,math.abs(a),math.abs(b)) end
 local function Axis(vertical,a,b) if vertical then return a else return b end end
 local function PixelUnit(parentScale)
  if not GetPhysicalScreenSize then return end
  local _,height=GetPhysicalScreenSize()
  if type(height)=="number" and height>0 then return 768/height/parentScale end
 end
 -- Compare native observations to the last successful observation, rather
 -- than to the requested double. The client quantizes screen edges to floats.
 local function GeometryMatches(actual,desired,savedDesired,savedNative)
  return actual==desired or desired==savedDesired and actual==savedNative
 end
 local function WriteDimension(self,target,axis,value)
  local signals=target._lycheeLayoutSignals
  if not signals or #signals.entries==0 then
   if axis=="width" then return target:SetWidth(value) else return target:SetHeight(value) end
  end
  local priorTarget,priorAxis,priorValue,priorOther,priorTolerance=self._writeTarget,self._writeAxis,self._writeValue,self._writeOther,self._writeTolerance
  self._writeTarget,self._writeAxis,self._writeValue=target,axis,value
  self._writeOther=axis=="width" and target:GetHeight() or target:GetWidth()
  -- This bound is only for the synchronous OnSizeChanged handoff. Four
  -- float32 ULPs at the screen-coordinate extent cover edge cancellation and
  -- scale conversion. Stable geometry below uses exact successful readbacks.
  local extent=math.max(1,math.abs(value))
  if GetPhysicalScreenSize then
   local w,h=GetPhysicalScreenSize();if w and h and h>0 then extent=math.max(extent,w*768/h/Scale(target),768/Scale(target)) end
  elseif UIParent and UIParent.GetWidth then extent=math.max(extent,UIParent:GetWidth()*Scale(UIParent)/Scale(target),UIParent:GetHeight()*Scale(UIParent)/Scale(target)) end
  self._writeTolerance=extent/2097152
  local setter=axis=="width" and target.SetWidth or target.SetHeight
  local ok,message=pcall(setter,target,value)
  self._writeTarget,self._writeAxis,self._writeValue,self._writeOther,self._writeTolerance=priorTarget,priorAxis,priorValue,priorOther,priorTolerance
  if not ok then error(message,0) end
 end
 function C._IsLayoutWrite(target,owner,axis)
  if owner._writeTarget~=target or axis and owner._writeAxis~=axis then return false end
  local fields=target._lycheeLayoutFields
  if not fields or fields[owner._writeAxis]~=owner then return false end
  local w,h=target:GetWidth(),target:GetHeight()
  local actual=owner._writeAxis=="width" and w or h
  local other=owner._writeAxis=="width" and h or w
  return other==owner._writeOther and math.abs(actual-owner._writeValue)<=owner._writeTolerance
 end
 local function ClearOwner(self,frame)
  if frame._lycheeLayoutOwner==self then frame._lycheeLayoutOwner,frame._lycheeLayoutPlace=nil,nil end
  local fields=frame._lycheeLayoutFields
  if fields then for key,owner in pairs(fields) do if owner==self then fields[key]=nil end end;if not next(fields) then frame._lycheeLayoutFields=nil end end
 end
 local function AddInput(self,frame)
  local owners=frame._lycheeLayoutInputs
  if not owners then frame._lycheeLayoutInputs=self
  elseif owners~=self then
   if owners.mode=="flex" then frame._lycheeLayoutInputs={[owners]=true,[self]=true} else owners[self]=true end
  end
 end
 local function RemoveInput(self,frame)
  local owners=frame._lycheeLayoutInputs
  if owners==self then frame._lycheeLayoutInputs=nil
  elseif owners and not owners.mode then
   owners[self]=nil;local remaining=next(owners)
   if not remaining or next(owners,remaining)==nil then frame._lycheeLayoutInputs=remaining end
  end
 end
 function Flex:Invalidate(reason)
  if self.released then return self end
  self._metricsRetries=nil
  if self.prepared then ClearPreparedOwners(self) end
  self.generation=self.generation+1;self.prepared=false
  self.dirty=true;self.lastInvalidation=reason or "explicit"
  if self.options.track and UI._QueueLayout then UI:_QueueLayout(self,self.lastInvalidation) end
  return self
 end
 function Flex:SetItems(items)
  if self.released then return self end
  items=items or empty
  if items==self.items and #items==self.itemCount then
   local unchanged=true
   for index=1,#items do
    local entry=items[index];local frame=entry.frame or entry;local item=entry.frame and entry or empty;local r=self.records[frame]
    if item.participate~=false then
     if not r or r.itemIndex~=index or r.item~=item or r.hadRules or r.hadStyle or r.hadBox or frame._lycheeBoxValues or frame._lycheeFixedRecords or frame._lycheeStyleController then unchanged=false;break end
     if getmetatable(item)==nil then
      local count=0
      for key,value in pairs(item) do local saved=savedInputByKey[key];if saved then
       if r[saved]~=value then unchanged=false;break end
       count=count+1
      end end
      if count~=r.inputCount then unchanged=false end
     else
      for i=1,#inputKeys do if r[savedInputKeys[i]]~=item[inputKeys[i]] then unchanged=false;break end end
     end
     if not unchanged then break end
    elseif r then unchanged=false;break end
   end
   if unchanged then return self end
  end
  self.items=items;self.itemCount=#items;self.generation=self.generation+1
  for _,r in pairs(self.records) do r.present=false;r.item=nil end
  for index,entry in ipairs(self.items) do
   local frame=entry.frame or entry;local item=entry.frame and entry or empty
   if item.participate~=false then
    local r=self.records[frame];local fresh=not r
    if not r then r={frame=frame,nativeSize=frame.GetSize and true or false};self.records[frame]=r end
    AddInput(self,frame)
    r.present=true;r.item=item;r.itemIndex=index
    r.hadBox,r.hadRules,r.hadStyle=frame._lycheeBoxValues~=nil,frame._lycheeFixedRecords~=nil,frame._lycheeStyleController~=nil
    local count=0
    if fresh and getmetatable(item)==nil then
     for key,value in pairs(item) do local saved=savedInputByKey[key];if saved then r[saved]=value;count=count+1 end end
    else
     for i=1,#inputKeys do local value=item[inputKeys[i]];r[savedInputKeys[i]]=value;if value~=nil then count=count+1 end end
    end
    r.inputCount=count
   end
  end
  for frame,r in pairs(self.records) do if not r.present then ClearOwner(self,frame);RemoveInput(self,frame);self.records[frame]=nil end end
  for i=#self.active,1,-1 do self.active[i]=nil end
  if self.options.track and UI._TrackLayout then UI:_TrackLayout(self) end
  return self:Invalidate("items")
 end
 function Flex:SetOptions(values)
  if self.released then return self end
  local tracked=self.options.track
  for key,value in pairs(values) do self.options[key]=value end
  if self.options.track and not tracked and UI._TrackLayout then UI:_TrackLayout(self)
  elseif tracked and not self.options.track and UI._ForgetLayout then UI:_ForgetLayout(self) end
  self.generation=self.generation+1;return self:Invalidate("options")
 end
 local function CancelActivePass(self,reason)
  if not self.preparing and not self.committing then return end
  local previous=self.generation
  self:Invalidate(reason)
  -- A nested read must not adopt the active batch's partial native output as
  -- a new intrinsic input. Managed axes keep the already-read business input.
  for _,r in pairs(self.records) do if r.inputGeneration==previous then r.inputGeneration=self.generation end end
  self.failedInputGeneration=self.generation
 end
 local function Option(self,key,fallback)
  local value=Field(self.parent,key,self.options[key]);if value==nil then return fallback end;return value
 end
 local function ContentSignature(r,save)
  local f=r.frame
  if not r.contentMetrics then return true end
  local path,size,flags=f:GetFont();local spacing=f:GetSpacing() or 0;local wrap=f:CanWordWrap();local text=f:GetText() or ""
  if save then r.contentPath,r.contentSize,r.contentFlags,r.contentSpacing,r.contentWrap,r.contentText=path,size,flags,spacing,wrap,text;return true end
  return r.contentPath==path and r.contentSize==size and r.contentFlags==flags and r.contentSpacing==spacing and r.contentWrap==wrap and r.contentText==text
 end
 local function ReadFull(self,r,innerW,innerH,parentScale)
  local f,item=r.frame,r.item;local box=f._lycheeBoxValues or empty
  if not r.projected then for _,key in ipairs(axisKeys) do local value=item[key];if value==nil then value=box[key] end;r[key]=Field(f,key,value) end end
  r.nativeScale=Scale(f);r.scale=r.nativeScale/parentScale
  r.manageWidth=r.manageWidth~=false;r.manageHeight=r.manageHeight~=false;r.managePoints=r.managePoints~=false
  -- A setter may write and then throw. Until an explicit invalidation changes
  -- the input generation, that partial output is not a new intrinsic basis.
  local retry=self.failedInputGeneration==self.generation and r.inputGeneration==self.generation
  local inputW,inputH
  if retry then inputW= r.manageWidth and r.inputNativeW or f:GetWidth();inputH=r.manageHeight and r.inputNativeH or f:GetHeight()
  elseif r.nativeSize then inputW,inputH=f:GetSize() else inputW,inputH=f:GetWidth(),f:GetHeight() end
  r.inputNativeW,r.inputNativeH,r.inputGeneration=inputW,inputH,self.generation
  local nativeW,nativeH=inputW*r.scale,inputH*r.scale
  Finite(nativeW,"native width");Finite(nativeH,"native height")
  r.nativeW,r.nativeH=nativeW,nativeH
  local wref,href=r.width,r.height;r.widthRef,r.heightRef=wref,href
  r.contentMetrics=((wref=="content" and r.manageWidth) or (href=="content" and r.manageHeight)) and not not f.GetStringHeight
  ContentSignature(r,true)
  local naturalW,naturalH
  if (wref=="content" and r.manageWidth) or (href=="content" and r.manageHeight) then
   -- ContentSignature just read these inputs; no callback runs between that
   -- read and this immediate measurement. Later text-height reads remain live.
   naturalW,naturalH=Natural(f,r.contentMetrics and r or nil);naturalW,naturalH=naturalW*r.scale,naturalH*r.scale
   if r.contentMetrics and r.contentText~="" and (naturalW==0 or naturalH==0) then self.metricsPending=true end
  end
  r.minW=r.manageWidth and Dimension(r.minWidth,innerW,"minWidth") or 0;r.maxW=r.manageWidth and Dimension(r.maxWidth,innerW,"maxWidth") or math.huge
  r.minH=r.manageHeight and Dimension(r.minHeight,innerH,"minHeight") or 0;r.maxH=r.manageHeight and Dimension(r.maxHeight,innerH,"maxHeight") or math.huge
  r.maxW=math.max(r.minW,r.maxW);r.maxH=math.max(r.minH,r.maxH)
  local w=r.manageWidth and (wref=="content" and naturalW or wref=="fill" and 0 or Dimension(wref,innerW,"width") or nativeW) or nativeW
  local h=r.manageHeight and (href=="content" and naturalH or href=="fill" and 0 or Dimension(href,innerH,"height") or nativeH) or nativeH
  r.w=r.manageWidth and Clamp(w,r.minW,r.maxW) or w;r.h=r.manageHeight and Clamp(h,r.minH,r.maxH) or h
  local vertical=self.vertical;local mainRef=Axis(vertical,href,wref)
  r.manageMain=vertical and r.manageHeight or not vertical and r.manageWidth
  r.manageCross=vertical and r.manageWidth or not vertical and r.manageHeight
  if r.manageMain and mainRef=="fill" and Axis(vertical,innerH,innerW)==nil then error("LycheeUI flex: fill depends on content main axis",3) end
  if r.manageCross and Axis(vertical,wref,href)=="fill" and Axis(vertical,innerW,innerH)==nil then error("LycheeUI flex: fill depends on content cross axis",3) end
  r.min=vertical and r.minH or r.minW;r.max=vertical and r.maxH or r.maxW
  r.crossMin=vertical and r.minW or r.minH;r.crossMax=vertical and r.maxW or r.maxH
  r.base=r.manageMain and Dimension(r.basis,Axis(vertical,innerH,innerW),"basis") or (vertical and r.h or r.w)
  if not r.manageMain then r.base=vertical and nativeH or nativeW end
  r.size=r.manageMain and Clamp(r.base,r.min,r.max) or r.base
  r.cross=vertical and r.w or r.h;r.align=r.align or self.align
  r.grow=r.manageMain and Finite(Value(r.grow) or (mainRef=="fill" and 1 or 0),"grow") or 0
  r.shrinkFactor=r.manageMain and Finite(Value(r.shrink) or 0,"shrink") or 0;r.shrink=r.shrinkFactor*r.base
  r.gap=Finite(Value(r.gapAfter) or self.gap,"gapAfter")
 end
 local function Read(self,r,innerW,innerH,parentScale)
  local f,item=r.frame,r.item
  local projectedSimple=false
  if r.projected then
   r.hadRules=true
   local w,h=r.width,r.height
   projectedSimple=(w==nil or w=="fill" or type(w)=="number") and (h==nil or h=="fill" or type(h)=="number")
    and r.minWidth==nil and r.maxWidth==nil and r.minHeight==nil and r.maxHeight==nil and r.basis==nil
    and r.grow==nil and r.shrink==nil and r.align==nil and r.gapAfter==nil
    and r.manageWidth==nil and r.manageHeight==nil and r.managePoints==nil
   if not projectedSimple then return ReadFull(self,r,innerW,innerH,parentScale) end
   if type(w)=="number" then Finite(w,"width") end;if type(h)=="number" then Finite(h,"height") end
   r.widthRef,r.heightRef=w,h
   r.minW,r.minH,r.min,r.crossMin=0,0,0,0;r.maxW,r.maxH,r.max,r.crossMax=math.huge,math.huge,math.huge,math.huge
   r.manageWidth,r.manageHeight,r.managePoints,r.manageMain,r.manageCross=true,true,true,true,true
   r.contentMetrics=false;r.shrinkFactor,r.shrink=0,0
  elseif r.compiledGeneration~=self.generation then
   r.hadBox,r.hadRules,r.hadStyle=f._lycheeBoxValues~=nil,f._lycheeFixedRecords~=nil,f._lycheeStyleController~=nil
   local w,h=item.width,item.height
   r.simple=not f._lycheeBoxValues and not f._lycheeFixedRecords and not f._lycheeStyleController
    and (w==nil or w=="fill" or type(w)=="number") and (h==nil or h=="fill" or type(h)=="number")
    and item.minWidth==nil and item.maxWidth==nil and item.minHeight==nil and item.maxHeight==nil and item.basis==nil
    and item.grow==nil and item.shrink==nil and item.align==nil and item.gapAfter==nil
    and item.manageWidth==nil and item.manageHeight==nil and item.managePoints==nil
   if r.simple then
    if type(w)=="number" then Finite(w,"width") end;if type(h)=="number" then Finite(h,"height") end
    r.widthRef,r.heightRef=w,h;r.width,r.height=w,h
    r.minW,r.minH,r.min,r.crossMin=0,0,0,0;r.maxW,r.maxH,r.max,r.crossMax=math.huge,math.huge,math.huge,math.huge
    r.manageWidth,r.manageHeight,r.managePoints,r.manageMain,r.manageCross=true,true,true,true,true
    r.contentMetrics=false;r.shrinkFactor,r.shrink=0,0
   end
   r.compiledGeneration=self.generation
  end
  if not projectedSimple and not r.simple then return ReadFull(self,r,innerW,innerH,parentScale) end
  r.nativeScale=Scale(f);r.scale=r.nativeScale/parentScale
  local retry=self.failedInputGeneration==self.generation and r.inputGeneration==self.generation
  local w,h;if retry then w,h=r.inputNativeW,r.inputNativeH elseif r.nativeSize then w,h=f:GetSize() else w,h=f:GetWidth(),f:GetHeight() end
  r.inputNativeW,r.inputNativeH,r.inputGeneration=w,h,self.generation
  w,h=w*r.scale,h*r.scale
  if w<0 or w~=w or w==math.huge then Finite(w,"native width") end;if h<0 or h~=h or h==math.huge then Finite(h,"native height") end
  r.nativeW,r.nativeH=w,h
  local wr,hr=r.widthRef,r.heightRef
  if wr=="fill" then if not innerW then error("LycheeUI flex: fill depends on content width axis",3) end;w=0 elseif wr~=nil then w=wr end
  if hr=="fill" then if not innerH then error("LycheeUI flex: fill depends on content height axis",3) end;h=0 elseif hr~=nil then h=hr end
  r.w,r.h=w,h
  if self.vertical then r.base,r.size,r.cross=h,h,w;r.grow=hr=="fill" and 1 or 0
  else r.base,r.size,r.cross=w,w,h;r.grow=wr=="fill" and 1 or 0 end
  r.align,r.gap=self.align,self.gap
 end
 local function RulesDirty(target)
  local controller=target._lycheeStyleController
  if controller and (controller._conditionDirty or controller._conditionApplyNeeded) then return true end
  local records=target._lycheeFixedRecords
  if records then for record in pairs(records) do local owner=record.controller;if owner and (owner._conditionDirty or owner._conditionApplyNeeded) then return true end end end
  return false
 end
 local function Distribute(self,line,budget)
  local active=self.active;local gaps,total,growWeight,shrinkWeight=0,0,0,0
  for i=line.first,line.last do local r=active[i];r.frozen=false;total=total+r.size;growWeight=growWeight+r.grow;shrinkWeight=shrinkWeight+r.shrink;if i<line.last then gaps=gaps+r.gap end end
  if budget then
   -- Freeze all constrained proposals in one pass, then redistribute only the
   -- space actually consumed by those frozen items.
   local extra=budget-gaps-total;local growing=extra>0
   for iteration=1,line.last-line.first+2 do
    local weight=growing and growWeight or shrinkWeight
    if iteration>1 then
     weight=0;total=0
     for i=line.first,line.last do local r=active[i];total=total+r.size;if not r.frozen then weight=weight+(growing and r.grow or r.shrink) end end
    end
    extra=budget-gaps-total
    if weight==0 or math.abs(extra)<.0000001 then line.used=total+gaps;return end
    local frozen=false
    for i=line.first,line.last do
     local r=active[i];local w=growing and r.grow or r.shrink
     if not r.frozen and w>0 then
      local proposal=r.size+extra*w/weight;local bounded=Clamp(proposal,r.min,r.max)
      if bounded~=proposal then r.size=bounded;r.frozen=true;frozen=true end
     end
    end
    if not frozen then for i=line.first,line.last do local r=active[i];if not r.frozen then r.size=r.size+extra*(growing and r.grow or r.shrink)/weight end end;break end
   end
  end
  if budget then total=0;for i=line.first,line.last do total=total+active[i].size end end
  line.used=total+gaps
 end
 local function TextHeight(self,r,width)
  local f=r.frame
  local path,size,flags=f:GetFont();local spacing=f:GetSpacing() or 0;local wrap=f:CanWordWrap();local text=f:GetText() or ""
  if r.textWidth~=width or r.textScale~=r.scale or r.textPath~=path or r.textSize~=size or r.textFlags~=flags or r.textSpacing~=spacing or r.textWrap~=wrap or r.text~=text then
   if not measure then measure=UI.parent:CreateFontString(nil,"OVERLAY");measure:Hide() end
   measure:SetFont(path,size,flags);measure:SetSpacing(spacing);measure:SetWordWrap(wrap);measure:SetWidth(width/r.scale);measure:SetText(text)
   r.textHeight=Finite(measure:GetStringHeight()*r.scale,"text height");r.textScale=r.scale
   r.textWidth,r.textPath,r.textSize,r.textFlags,r.textSpacing,r.textWrap,r.text=width,path,size,flags,spacing,wrap,text
  end
  if r.textHeight==0 and text~="" then r.textWidth=nil;self.metricsPending=true end
  return r.textHeight
 end
 local function Prepare(self,availableW,availableH,measurement,resolvedWidth,resolvedHeight,round)
  local parent=self.parent;local parentW,parentH=NativeSize(parent);local ps=Scale(parent)
  local pixel=PixelUnit(ps)
  if not measurement and not self.dirty and self.parentW==parentW and self.parentH==parentH and self.parentScale==ps and self.pixelUnit==pixel and self.availableW==availableW and self.availableH==availableH and not RulesDirty(parent) then
   local stable=true
   if self.nativeSignature then
    -- This pass contains only included fixed/native items with managed points,
    -- native GetSize and no observed rule/text state. Keep every native read;
    -- the general path below also checks conditions, text and exclusions.
    local active=self.active
    for i=1,#active do local r=active[i];local frame=r.frame
     if frame:IsShown()~=r.shown or frame:GetEffectiveScale()~=r.nativeScale then stable=false;break end
     local w,h=frame:GetSize()
     if w~=r.nativeReadW or h~=r.nativeReadH then stable=false;break end
     local a,b,c,x,y=frame:GetPoint()
     if frame:GetNumPoints()~=1 or a~="TOPLEFT" or b~=parent or c~="TOPLEFT" or x~=r.nativeReadX or y~=r.nativeReadY then stable=false;break end
    end
   else for frame,r in pairs(self.records) do
    if frame:IsShown()~=r.shown or frame:GetEffectiveScale()~=r.nativeScale or (r.hadRules or r.hadStyle) and RulesDirty(frame) then stable=false;break end
    if r.included then
     local w,h;if r.nativeSize then w,h=frame:GetSize() else w,h=frame:GetWidth(),frame:GetHeight() end
     if w~=r.nativeReadW or h~=r.nativeReadH or r.contentMetrics and not ContentSignature(r,false) then stable=false;break end
     if r.managePoints then
      local a,b,c,x,y=frame:GetPoint()
      if frame:GetNumPoints()~=1 or a~="TOPLEFT" or b~=parent or c~="TOPLEFT" or x~=r.nativeReadX or y~=r.nativeReadY then stable=false;break end
     end
    end
   end end
   if stable then return false end
  end
  ClearPreparedOwners(self);self.ownerSnapshots=true
  self.dirty=true;self.prepared=false;self._notifyPending=false;self.metricsPending=false
  local vertical=Option(self,"direction",self.defaultVertical and "column" or "row")=="column";self.vertical=vertical
  local widthRef,heightRef=Option(self,"width"),Option(self,"height")
  self.boxContentWidth,self.boxContentHeight=widthRef=="content",heightRef=="content"
  local referenceW,referenceH=availableW or parentW,availableH or parentH
  if self.boxTarget then
   local fields=parent._lycheeLayoutFields
   self.boxOwnerWidth,self.boxOwnerHeight=fields and fields.width,fields and fields.height
   local manageW=Option(self,"manageWidth",true)~=false and (not self.boxOwnerWidth or self.boxOwnerWidth==self)
   local manageH=Option(self,"manageHeight",true)~=false and (not self.boxOwnerHeight or self.boxOwnerHeight==self)
   self.boxContentWidth,self.boxContentHeight=self.boxContentWidth and manageW,self.boxContentHeight and manageH
   self.boxWriteWidth,self.boxWriteHeight=manageW and widthRef~=nil,manageH and heightRef~=nil
   -- An outer layout or a manual axis supplies an already determined budget;
   -- the inner content solver may arrange children but does not resize it.
   if not manageW then widthRef=parentW end
   if not manageH then heightRef=parentH end
   local relative=parent:GetParent()
   if relative then
    local ratio=Scale(relative)/ps
    if manageW and type(widthRef)=="string" and widthRef~="content" then referenceW=relative:GetWidth()*ratio end
    if manageH and type(heightRef)=="string" and heightRef~="content" then referenceH=relative:GetHeight()*ratio end
   end
  end
  local width=widthRef=="content" and resolvedWidth or Dimension(widthRef or "fill",referenceW,"container width")
  local height=heightRef=="content" and resolvedHeight or Dimension(heightRef or "fill",referenceH,"container height")
  local minW=Dimension(Option(self,"minWidth"),availableW or parentW,"container minWidth") or 0
  local maxW=math.max(minW,Dimension(Option(self,"maxWidth"),availableW or parentW,"container maxWidth") or math.huge)
  local minH=Dimension(Option(self,"minHeight"),availableH or parentH,"container minHeight") or 0
  local maxH=math.max(minH,Dimension(Option(self,"maxHeight"),availableH or parentH,"container maxHeight") or math.huge)
  if width then width=Clamp(width,minW,maxW) end;if height then height=Clamp(height,minH,maxH) end
  local left,top,right,bottom=Padding(Option(self,"padding",parent._lycheeBoxValues and parent._lycheeBoxValues.padding),parent)
  Finite(left,"padding");Finite(top,"padding");Finite(right,"padding");Finite(bottom,"padding")
  local iw=width and math.max(0,width-left-right);local ih=height and math.max(0,height-top-bottom)
  local innerMain=Axis(vertical,ih,iw);local innerCross=Axis(vertical,iw,ih)
  self.align=Option(self,"align","start");self.justify=Option(self,"justify","start")
  self.gap=Finite(Value(Option(self,"gap",0)),"gap");local lineGap=Finite(Value(Option(self,"lineGap",self.gap)),"lineGap")
  local flowWrap=Option(self,"flowWrap",false)
  local includeHidden=Option(self,"includeHidden",false)
  local active=self.active;for i=#active,1,-1 do active[i]=nil end
  local nativeSignature=true
  for _,entry in ipairs(self.items) do
   local f=entry.frame or entry;local r=self.records[f]
   if r then local item=r.item
    r.hadBox,r.hadRules,r.hadStyle=f._lycheeBoxValues~=nil,f._lycheeFixedRecords~=nil,f._lycheeStyleController~=nil
    r.projected=r.hadRules and C._ReadLayoutValues~=nil or false
    local participate
    if r.projected then C._ReadLayoutValues(f,r,projectionKeys,item);participate=r.participate
    else participate=Field(f,"participate",item.participate) end
    r.shown=f:IsShown()
    if participate==false then r.included=false
    elseif not item.hidden and (includeHidden or r.shown) then r.included=true
    elseif r.projected then r.included=r.reserve==true
    else r.included=Field(f,"reserve",item.reserve)==true end
    if r.included then
     Read(self,r,iw,ih,ps)
     if not r.nativeSize or r.hadRules or r.hadStyle or r.contentMetrics or not r.managePoints then nativeSignature=false end
     local fields=f._lycheeLayoutFields
     r.ownerWidth,r.ownerHeight,r.ownerPoints,r.ownerPointField=fields and fields.width,fields and fields.height,f._lycheeLayoutOwner,fields and fields.points
     if vertical and r.heightRef=="content" and r.manageHeight and f.GetStringHeight then
      if not flowWrap and r.manageCross and innerCross and (r.widthRef=="fill" or r.align=="stretch") then r.cross=Clamp(innerCross,r.crossMin,r.crossMax) end
      local measureWidth=r.cross
      if flowWrap and innerCross and (r.widthRef=="fill" or r.align=="stretch") then measureWidth=(round or 0)>0 and r.wrapWidth or innerCross end
      local natural=TextHeight(self,r,measureWidth);r.h=Clamp(natural,r.minH,r.maxH);r.measuredContentHeight=r.h
      r.base=Dimension(r.basis,ih,"basis") or r.h;r.size=Clamp(r.base,r.min,r.max);r.shrink=r.shrinkFactor*r.base
     end
     active[#active+1]=r
    else nativeSignature=false;r.nativeScale=Scale(f);r.scale=r.nativeScale/ps end
   end
  end
  self.nativeSignature=nativeSignature
  local lines=self.lines;local count=1;local line=lines[1]
  if not line then line={};lines[1]=line end
  line.first,line.last,line.used=1,0,0
  if flowWrap then
   for i=1,#active do local r=active[i];local proposed=line.used+(line.last>=line.first and active[i-1].gap or 0)+r.size
    if innerMain and line.last>=line.first and proposed>innerMain then
     count=count+1;line=lines[count];if not line then line={};lines[count]=line end
     line.first,line.last,line.used=i,i,r.size
    else line.last=i;line.used=proposed end
   end
  else line.last=#active end
  self.lineCount=count;local used,maxMain,contentCross=0,0,0
  for li=1,count do
   line=lines[li];Distribute(self,line,innerMain);line.cross=0
   for i=line.first,line.last do local r=active[i]
    local crossRef=Axis(vertical,r.widthRef,r.heightRef)
    if r.manageCross and innerCross and (crossRef=="fill" or r.align=="stretch") and not flowWrap then r.cross=Clamp(innerCross,r.crossMin,r.crossMax) end
    if not vertical and r.heightRef=="content" and r.manageHeight and r.frame.GetStringHeight then
     r.cross=Clamp(TextHeight(self,r,r.size),r.crossMin,r.crossMax)
    end
    line.cross=math.max(line.cross,r.cross)
   end
   contentCross=contentCross+line.cross+(li<count and lineGap or 0)
   if not flowWrap and innerCross then line.cross=math.max(line.cross,innerCross) end
   line.naturalCross=line.cross;used=used+line.cross+(li<count and lineGap or 0);maxMain=math.max(maxMain,line.used)
  end
  -- Wrapped lines retain their intrinsic/minimum cross extents, then share
  -- only the remaining definite cross budget. Overflow never shrinks a line.
  local lineExtra=flowWrap and innerCross and math.max(0,innerCross-used)/count or 0
  used=0
  for li=1,count do line=lines[li];line.cross=line.cross+lineExtra;line.offset=used;used=used+line.cross+(li<count and lineGap or 0) end
  self.contentWidth=(vertical and contentCross or maxMain)+left+right
  self.contentHeight=(vertical and maxMain or contentCross)+top+bottom
  local bw=widthRef=="content" and Clamp(self.contentWidth,minW,maxW) or width
  local bh=heightRef=="content" and Clamp(self.contentHeight,minH,maxH) or height
  if (widthRef=="content" and width~=nil and not Same(width,bw) or widthRef=="content" and width==nil and not Same(self.contentWidth,bw)) or (heightRef=="content" and height~=nil and not Same(height,bh) or heightRef=="content" and height==nil and not Same(self.contentHeight,bh)) then
   if (round or 0)>=7 then error("LycheeUI flex: content constraints did not converge",3) end
   return Prepare(self,availableW,availableH,measurement,widthRef=="content" and bw or nil,heightRef=="content" and bh or nil,(round or 0)+1)
  end
  self.containerWidth,self.containerHeight=bw,bh
  self.overflowWidth=math.max(0,self.contentWidth-bw);self.overflowHeight=math.max(0,self.contentHeight-bh)
  self.overflow=self.overflowWidth>0 or self.overflowHeight>0
  local anchor=Option(self,"anchor","TOPLEFT");local ox=Value(Option(self,"x",0));local oy=-Value(Option(self,"y",0))
  if anchor:find("RIGHT") then ox=ox+parentW-bw elseif anchor=="CENTER" then ox=ox+(parentW-bw)/2 end
  if anchor:find("BOTTOM") then oy=oy+parentH-bh elseif anchor=="CENTER" then oy=oy+(parentH-bh)/2 end
  local wrapReflow=false;contentCross=0
  for li=1,count do
   line=lines[li];local extra=math.max(0,(innerMain or line.used)-line.used)
   local cursor=self.justify=="end" and extra or self.justify=="center" and extra/2 or 0
   local between=self.justify=="space-between" and line.last>line.first and extra/(line.last-line.first) or 0
   local n=line.last-line.first+1
   if self.justify=="space-around" and n>0 then between=extra/n;cursor=between/2
   elseif self.justify=="space-evenly" and n>0 then between=extra/(n+1);cursor=between end
   for i=line.first,line.last do local r=active[i]
    if r.manageCross and flowWrap and (r.align=="stretch" or Axis(vertical,r.widthRef,r.heightRef)=="fill") then r.cross=Clamp(line.cross,r.crossMin,r.crossMax) end
    if vertical and flowWrap and r.heightRef=="content" and r.manageHeight and r.frame.GetStringHeight then
     r.wrapWidth=r.cross
     local finalHeight=Clamp(TextHeight(self,r,r.cross),r.minH,r.maxH)
     if r.basis==nil and not Same(finalHeight,r.measuredContentHeight) then wrapReflow=true end
    end
    contentCross=math.max(contentCross,line.offset+r.cross)
    local space=line.cross-r.cross;local offset=r.align=="end" and space or r.align=="center" and space/2 or 0
    r.x=ox+left+(vertical and line.offset+offset or cursor);r.y=oy+top+(vertical and cursor or line.offset+offset)
    r.w=vertical and r.cross or r.size;r.h=vertical and r.size or r.cross
    if pixel then
     -- Keep the shared boundaries as integer pixel indices until their final
     -- conversion. Subtracting already converted doubles gives identical
     -- spans different low bits at different offsets, forcing native writes.
     local sx,sy=math.floor(r.x/pixel+.5),math.floor(r.y/pixel+.5)
     local ex,ey=math.floor((r.x+r.w)/pixel+.5),math.floor((r.y+r.h)/pixel+.5)
     r.w,r.h=math.max(0,ex-sx)*pixel,math.max(0,ey-sy)*pixel;r.x,r.y=sx*pixel,sy*pixel
    else r.w,r.h=math.max(0,r.w),math.max(0,r.h) end
    cursor=cursor+r.size+(i<line.last and r.gap+between or 0)
   end
  end
  if wrapReflow then
   if (round or 0)>=7 then error("LycheeUI flex: wrapped text did not converge",3) end
   return Prepare(self,availableW,availableH,measurement,resolvedWidth,resolvedHeight,(round or 0)+1)
  end
  -- Content bounds include the actual line offsets and final cross fill;
  -- unconsumed trailing alignment space is not reported as item content.
  self.contentWidth=(vertical and contentCross or maxMain)+left+right
  self.contentHeight=(vertical and maxMain or contentCross)+top+bottom
  self.overflowWidth=math.max(0,self.contentWidth-bw);self.overflowHeight=math.max(0,self.contentHeight-bh)
  self.overflow=self.overflowWidth>0 or self.overflowHeight>0
  self.preparedParentW,self.preparedParentH,self.preparedParentScale,self.preparedAvailableW,self.preparedAvailableH=parentW,parentH,ps,availableW,availableH
  self.preparedPixelUnit=pixel
  if self.metricsPending and not measurement then
   self._metricsRetries=(self._metricsRetries or 0)+1
   if self._metricsRetries>2 then error("LycheeUI flex: text metrics unavailable after two frame retries",3) end
   if self.options.track and UI._DeferLayout then UI:_DeferLayout(self,"text-metrics") end
   ClearPreparedOwners(self)
   return false
  end
  self._metricsRetries=nil
  self.prepared=true;self.preparedGeneration=self.generation;return true
 end
 function Flex:PrepareLayout(w,h)
  if self.released then return end
  CancelActivePass(self,"prepare-reentrant")
  local generation,preparing=self.generation,self.preparing;self.preparing=true
  local ok,result=pcall(Prepare,self,w,h,false);self.preparing=preparing
  if not ok then ClearPreparedOwners(self);self.prepared=false;self.dirty=true;self.lastError=result;error(result,0) end
  if self.generation~=generation then ClearPreparedOwners(self);self.prepared=false;self.dirty=true end
  return self.contentWidth,self.contentHeight
 end
 local function CompatiblePrevious(self,r,owner,previous)
  -- Only a completed current owner's exact native pair is transferable. No
  -- pending batch, changed parent/scale or failed retry supplies this shortcut.
  return owner~=self and not self.failedInputGeneration and owner.mode=="flex" and not owner.released and not owner.dirty and not owner.running and not owner.committing and not owner.prepared and not owner.failedInputGeneration and owner.parent==self.parent and owner.parentScale==self.preparedParentScale and previous~=r and previous.included and previous.nativeScale==r.nativeScale and previous.scale==r.scale
 end
 local function InheritedPair(self,r,owner,committed,native,desired,actual)
  local previous=owner.records and owner.records[r.frame]
  return previous and desired==previous[committed] and actual==previous[native] and CompatiblePrevious(self,r,owner,previous)
 end
 local function InheritedPoint(self,r,desiredX,desiredY,x,y)
  local owner=r.ownerPoints;local previous=owner and owner.records and owner.records[r.frame]
  return previous and desiredX==previous.committedX and desiredY==previous.committedY and x==previous.nativeReadX and y==previous.nativeReadY and CompatiblePrevious(self,r,owner,previous)
 end
 local function CommitRecord(self,r,generation)
  local f=r.frame;local fields=f._lycheeLayoutFields
  if r.manageWidth and (fields and fields.width)~=r.ownerWidth or r.manageHeight and (fields and fields.height)~=r.ownerHeight or r.managePoints and (f._lycheeLayoutOwner~=r.ownerPoints or (fields and fields.points)~=r.ownerPointField) then return false end
  if not fields then fields={};f._lycheeLayoutFields=fields end
  if r.managePoints and UI.Motion and UI.Motion.placements[f] then UI.Motion:FinishPlacement(f) end
  if self.released or self.generation~=generation or r.managePoints and f._lycheeLayoutOwner~=r.ownerPoints then return false end
  -- GetSize observes the same two native axes together. A width write can
  -- synchronously change height, so refresh both observations after it.
  local actualW,actualH
  if r.nativeSize then actualW,actualH=f:GetSize() else actualW,actualH=f:GetWidth(),f:GetHeight() end
  -- Native callbacks can replace the table or transfer only a later field.
  -- Each unclaimed field must still have its prepared owner before claiming it.
  fields=f._lycheeLayoutFields
  if r.manageWidth then
   if (fields and fields.width)~=r.ownerWidth then return false end
   if not fields then fields={};f._lycheeLayoutFields=fields end
   local desired=r.w/r.scale
   local matches=GeometryMatches(actualW,desired,r.committedW,r.nativeReadW)
   if not matches and r.ownerWidth and r.ownerWidth~=self then matches=InheritedPair(self,r,r.ownerWidth,"committedW","nativeReadW",desired,actualW) end
   fields.width=self
   if not matches then
    WriteDimension(self,f,"width",desired)
    if r.nativeSize then actualW,actualH=f:GetSize() else actualW,actualH=f:GetWidth(),f:GetHeight() end
   end
   fields=f._lycheeLayoutFields
   if self.released or not fields or fields.width~=self or self.generation~=generation then return false end
   r.pendingW,r.pendingReadW=desired,actualW
  else if fields and fields.width==self then fields.width=nil end;r.pendingW,r.pendingReadW=nil,actualW end
  if r.manageHeight then
   if (fields and fields.height)~=r.ownerHeight then return false end
   if not fields then fields={};f._lycheeLayoutFields=fields end
   local desired=r.h/r.scale
   local matches=GeometryMatches(actualH,desired,r.committedH,r.nativeReadH)
   if not matches and r.ownerHeight and r.ownerHeight~=self then matches=InheritedPair(self,r,r.ownerHeight,"committedH","nativeReadH",desired,actualH) end
   fields.height=self
   if not matches then WriteDimension(self,f,"height",desired);actualH=f:GetHeight() end
   fields=f._lycheeLayoutFields
   if self.released or not fields or fields.height~=self or self.generation~=generation then return false end
   r.pendingH,r.pendingReadH=desired,actualH
  else if fields and fields.height==self then fields.height=nil end;r.pendingH,r.pendingReadH=nil,actualH end
  if r.managePoints then
   if f._lycheeLayoutOwner~=r.ownerPoints or (fields and fields.points)~=r.ownerPointField then return false end
   if not fields then fields={};f._lycheeLayoutFields=fields end
   fields.points=self;f._lycheeLayoutOwner=self;f._lycheeLayoutPlace=nil
   local a,b,c,x,y=f:GetPoint()
   local desiredX,desiredY=r.x/r.scale,-r.y/r.scale
   local matches=f:GetNumPoints()==1 and a=="TOPLEFT" and b==self.parent and c=="TOPLEFT"
   if matches then
    matches=GeometryMatches(x,desiredX,r.committedX,r.nativeReadX) and GeometryMatches(y,desiredY,r.committedY,r.nativeReadY)
    if not matches and r.ownerPoints~=self and r.ownerPointField==r.ownerPoints then matches=InheritedPoint(self,r,desiredX,desiredY,x,y) end
   end
   if not matches then
    f:ClearAllPoints()
    fields=f._lycheeLayoutFields
    if self.released or not fields or fields.points~=self or f._lycheeLayoutOwner~=self or self.generation~=generation then return false end
    f:SetPoint("TOPLEFT",self.parent,"TOPLEFT",desiredX,desiredY)
    fields=f._lycheeLayoutFields
    if self.released or not fields or fields.points~=self or f._lycheeLayoutOwner~=self or self.generation~=generation then return false end
    a,b,c,x,y=f:GetPoint()
    -- Moving an edge can change native width/height readback through float
    -- cancellation, even when their requested dimensions did not change.
    if r.nativeSize then r.pendingReadW,r.pendingReadH=f:GetSize() else r.pendingReadW,r.pendingReadH=f:GetWidth(),f:GetHeight() end
   end
   r.pendingX,r.pendingY,r.pendingReadX,r.pendingReadY=desiredX,desiredY,x,y
  else
   if fields and fields.points==self then fields.points=nil;if f._lycheeLayoutOwner==self then f._lycheeLayoutOwner,f._lycheeLayoutPlace=nil,nil end end
   r.pendingX,r.pendingY,r.pendingReadX,r.pendingReadY=nil,nil,nil,nil
  end
  -- Publish the pending pair only if this record still owns every field it
  -- managed, including earlier fields transferred by a later native callback.
  fields=f._lycheeLayoutFields
  return not self.released and self.generation==generation and (not r.manageWidth or fields and fields.width==self) and (not r.manageHeight or fields and fields.height==self) and (not r.managePoints or fields and fields.points==self and f._lycheeLayoutOwner==self)
 end
 function Flex:NotifyLayout()
  if not self._notifyPending or self.released then return end
  self._notifyPending=false
  local callback=self.options.onLayout
  if callback then
   self.notifying=true
   local ok,message=pcall(callback,self,self.contentWidth,self.contentHeight)
   self.notifying=false
   if not ok then error(message,0) end
  end
 end
 local function BoxReady(self)
  local target=self.boxTarget;if not target then return true end
  if target._lycheeBoxLayout~=self or target._lycheeBoxContext~=UI then return false end
  local fields=target._lycheeLayoutFields
  return (not self.boxWriteWidth or (fields and fields.width)==self.boxOwnerWidth) and (not self.boxWriteHeight or (fields and fields.height)==self.boxOwnerHeight)
 end
 local function CommitBox(self,generation)
  local target=self.boxTarget
  if not BoxReady(self) then return false end
  local fields=target._lycheeLayoutFields
  if (self.boxWriteWidth or self.boxWriteHeight) and not fields then fields={};target._lycheeLayoutFields=fields end
  if self.boxWriteWidth then
   fields.width=self;self.boxOwnerWidth=self
   local actual=target:GetWidth()
   if not GeometryMatches(actual,self.containerWidth,self.boxCommittedW,self.boxNativeReadW) then WriteDimension(self,target,"width",self.containerWidth);actual=target:GetWidth() end
   fields=target._lycheeLayoutFields
   if not fields or fields.width~=self then return false end
   self.boxPendingW,self.boxPendingReadW=self.containerWidth,actual
   if not self.boxContentWidth then fields.width=nil;self.boxOwnerWidth=nil end
  elseif fields and fields.width==self then fields.width=nil end
  if self.released or self.generation~=generation then return false end
  if not BoxReady(self) then return false end
  fields=target._lycheeLayoutFields
  if self.boxWriteHeight then
   if not fields then fields={};target._lycheeLayoutFields=fields end
   fields.height=self;self.boxOwnerHeight=self
   local actual=target:GetHeight()
   if not GeometryMatches(actual,self.containerHeight,self.boxCommittedH,self.boxNativeReadH) then WriteDimension(self,target,"height",self.containerHeight);actual=target:GetHeight() end
   fields=target._lycheeLayoutFields
   if not fields or fields.height~=self then return false end
   self.boxPendingH,self.boxPendingReadH=self.containerHeight,actual
   if not self.boxContentHeight then fields.height=nil;self.boxOwnerHeight=nil end
  elseif fields and fields.height==self then fields.height=nil end
  if self.released or self.generation~=generation then return false end
  if fields and not next(fields) then target._lycheeLayoutFields=nil end
  self.preparedParentW,self.preparedParentH=NativeSize(target)
  return BoxReady(self)
 end
 local function CommitBatch(self,generation)
  for i=1,#self.active do
   if not CommitRecord(self,self.active[i],generation) or self.released then return false end
  end
  if self.boxTarget then return CommitBox(self,generation) end
  return true
 end
 function Flex:CommitLayout(deferNotify)
  if self.committing then return self.contentWidth,self.contentHeight end
  if self.released or not self.prepared then if not self.committing then ClearPreparedOwners(self) end;return self.contentWidth,self.contentHeight end
  local generation=self.preparedGeneration
  if self.generation~=self.preparedGeneration then ClearPreparedOwners(self);self.prepared=false;self.dirty=true;return self.contentWidth,self.contentHeight end
  if not BoxReady(self) then ClearPreparedOwners(self);self.prepared=false;self.dirty=true;return self.contentWidth,self.contentHeight end
  for _,r in pairs(self.records) do if not r.included then ClearOwner(self,r.frame) end end
  self.dirty=false;self.prepared=false;self._notifyPending=false
  self.committing=true;local ok,result=pcall(CommitBatch,self,generation);self.committing=false
  if not ok or not result or self.generation~=generation then
   ClearPreparedOwners(self);self.prepared=false;self.dirty=true
   if self.failedInputGeneration~=self.generation then self.failedInputGeneration=generation end
   if not ok then self.lastError=result;error(result,0) end
   return self.contentWidth,self.contentHeight
  end
  self.parentW,self.parentH,self.parentScale,self.availableW,self.availableH=self.preparedParentW,self.preparedParentH,self.preparedParentScale,self.preparedAvailableW,self.preparedAvailableH
  self.pixelUnit=self.preparedPixelUnit
  for _,r in ipairs(self.active) do
   r.committedW,r.committedH,r.nativeReadW,r.nativeReadH=r.pendingW,r.pendingH,r.pendingReadW,r.pendingReadH
   r.committedX,r.committedY,r.nativeReadX,r.nativeReadY=r.pendingX,r.pendingY,r.pendingReadX,r.pendingReadY
   r.ownerWidth,r.ownerHeight,r.ownerPoints,r.ownerPointField=nil,nil,nil,nil
  end
  self.boxOwnerWidth,self.boxOwnerHeight=nil,nil;self.ownerSnapshots=false
  if self.boxTarget then
   self.boxCommittedW,self.boxNativeReadW=self.boxPendingW,self.boxPendingReadW
   self.boxCommittedH,self.boxNativeReadH=self.boxPendingH,self.boxPendingReadH
  end
  self.lastError=nil;self.failedInputGeneration=nil
  self._notifyPending=true
  if not deferNotify then self:NotifyLayout() end
  return self.contentWidth,self.contentHeight
 end
 local function RunFlex(self,w,h)
  local generation=self.generation;self.preparing=true
  local ready=Prepare(self,w,h,false);self.preparing=false
  if self.generation~=generation then ClearPreparedOwners(self);self.prepared=false;self.dirty=true;return self.contentWidth,self.contentHeight end
  if not ready then return self.contentWidth,self.contentHeight end
  return self:CommitLayout()
 end
 function Flex:Layout(w,h)
  if self.released then return end
  if self.running or self.notifying or self.preparing or self.committing then
   if self.preparing or self.committing then CancelActivePass(self,"reentrant");return self end
   return self:Invalidate("reentrant")
  end
  self.running=true
  local ok,a,b=pcall(RunFlex,self,w,h)
  self.running=false
  if not ok then ClearPreparedOwners(self);self.preparing=false;self.prepared=false;self.dirty=true;self.lastError=a;error(a,0) end
  if not self.dirty and not self.released and UI._LayoutSettled then UI:_LayoutSettled(self) end
  return a,b
 end
 function Flex:Measure(w,h)
  if self.released then return end
  CancelActivePass(self,"measure-reentrant")
  local preparing=self.preparing;self.preparing=true
  local ok,result=pcall(Prepare,self,w,h,true);self.preparing=preparing;ClearPreparedOwners(self);self.prepared=false;self.dirty=true
  if not ok then self.lastError=result;error(result,0) end
  return self.contentWidth,self.contentHeight
 end
 function Flex:Release()
  if self.released then return end
  self.released=true
  ClearPreparedOwners(self)
  if UI._ForgetLayout then UI:_ForgetLayout(self) end
  for frame in pairs(self.records) do ClearOwner(self,frame);RemoveInput(self,frame) end
  RemoveInput(self,self.parent)
  if self.boxTarget then ClearOwner(self,self.boxTarget) end
  for i,value in ipairs(UI.layouts) do if value==self then table.remove(UI.layouts,i);break end end
  for key in pairs(self.records) do self.records[key]=nil end
  for i=#self.active,1,-1 do self.active[i]=nil end
  if self.boxTarget and self.boxTarget._lycheeBoxLayout==self then self.boxTarget._lycheeBoxLayout=nil end
  self.items,self.options=empty,empty;self.parent,self.boxTarget=nil,nil;self.prepared=false;self._notifyPending=false
 end
 local function CreateFlex(parent,items,options,vertical)
  local layout=setmetatable({context=UI,parent=parent,items=empty,options=options or {},defaultVertical=vertical,records={},active={},lines={},generation=0,dirty=true,mode="flex"},flexMeta)
  UI.layouts[#UI.layouts+1]=layout;layout:SetItems(items);AddInput(layout,parent)
  return layout
 end
 local function LegacyPreviousSizeMatches(frame,record,w,h,actualW,actualH)
  -- A new controller may reuse the physical region while its last placement
  -- owner still has the exact successful size request/readback pair.
  local owner=frame._lycheeLayoutOwner;local previous=owner and owner.records and owner.records[frame]
  return previous and previous~=record and GeometryMatches(actualW,w,previous.committedW,previous.nativeReadW) and GeometryMatches(actualH,h,previous.committedH,previous.nativeReadH)
 end
 local function Create(parent,items,options,vertical)
  if options and options.mode=="flex" then return CreateFlex(parent,items,options,vertical) end
  local layout={parent=parent,items=items or {},options=options or {},vertical=vertical,owned={},records={},active={}}
  UI.layouts[#UI.layouts+1]=layout
  function layout:SetItems(values) self.items=values;self.cached=false;return self end
  function layout:SetOptions(values) for key,value in pairs(values) do self.options[key]=value end;return self end
  function layout:Run(availableW,availableH,place)
   -- Measure reuses the active records, so its temporary item set cannot serve
   -- a previously cached placement on the next Layout call.
   if not place then self.cached=false end
   local o=self.options;local left,top,right,bottom=Padding(o.padding or parent._lycheeBoxValues and parent._lycheeBoxValues.padding,o.padding==nil and parent or nil)
   local parentW,parentH=NativeSize(parent)
   availableW,availableH=availableW or parentW,availableH or parentH
   local width,height
   if o.width~="content" then width=Value(o.width or availableW) end
   if o.height~="content" then height=Value(o.height or availableH) end
   if place and self.cached and self.cachedItems==self.items and self.itemCount==#self.items
    and self.parentW==parentW and self.parentH==parentH and self.width==width and self.height==height
    and self.left==left and self.top==top and self.right==right and self.bottom==bottom
    and self.align==o.align and self.justify==o.justify and self.anchor==o.anchor and self.x==o.x and self.y==o.y
    and self.gap==o.gap and self.includeHidden==o.includeHidden then
    local stable=true
    for i,entry in ipairs(self.items) do
     local frame=entry.frame or entry;local r=self.records[frame];local item=entry.frame and entry or empty;local box=frame._lycheeBoxValues or empty
     local included=not item.hidden and (o.includeHidden or frame:IsShown())
     local actualW,actualH;if included and r then if r.nativeSize then actualW,actualH=frame:GetSize() else actualW,actualH=frame:GetWidth(),frame:GetHeight() end end
     if not r or r.index~=i or r.entry~=entry or r.included~=included
      or r.iw~=item.width or r.ih~=item.height or r.iminW~=item.minWidth or r.imaxW~=item.maxWidth or r.iminH~=item.minHeight or r.imaxH~=item.maxHeight
      or r.igrow~=item.grow or r.ishrink~=item.shrink or r.ialign~=item.align or r.igap~=item.gapAfter
      or r.bminW~=box.minWidth or r.bmaxW~=box.maxWidth or r.bminH~=box.minHeight or r.bmaxH~=box.maxHeight or r.balign~=box.align
      or included and (frame._lycheeLayoutOwner~=self or actualW~=r.nativeReadW or actualH~=r.nativeReadH) then stable=false;break end
    end
    if stable then
     for _,record in ipairs(self.active) do record.place() end
     return self.contentWidth,self.contentHeight
    end
   end
   self.cached=false
   local cacheable=place
   local main,cross;if vertical then main,cross=height,width else main,cross=width,height end
   local padMain=vertical and top+bottom or left+right;local padCross=vertical and left+right or top+bottom
   local innerMain=main and math.max(0,main-padMain);local innerCross=cross and math.max(0,cross-padCross)
   local active,total,grow,shrink=self.active,0,0,0
   for i=#active,1,-1 do active[i]=nil end
   for index,entry in ipairs(self.items) do
    local frame=entry.frame or entry;local record=self.records[frame]
    if not record then
     record={frame=frame,nativeSize=frame.GetSize and true or false};self.records[frame]=record
     record.place=function()
      local point,relative,relativePoint,x,y=frame:GetPoint()
      local moved=false
      if frame:GetNumPoints()~=1 or point~="TOPLEFT" or relative~=parent or relativePoint~="TOPLEFT" or not (x==record.x or record.x==record.committedX and x==record.nativeReadX) or not (y==-record.y or -record.y==record.committedY and y==record.nativeReadY) then
       frame:ClearAllPoints();frame:SetPoint("TOPLEFT",parent,"TOPLEFT",record.x,-record.y)
       if frame._lycheeLayoutOwner~=layout or layout.released then return false end
       point,relative,relativePoint,x,y=frame:GetPoint();moved=true
       if record.nativeSize then record.nativeReadW,record.nativeReadH=frame:GetSize() else record.nativeReadW,record.nativeReadH=frame:GetWidth(),frame:GetHeight() end
      end
      record.committedX,record.committedY,record.nativeReadX,record.nativeReadY=record.x,-record.y,x,y
      return moved
     end
    end
    local item=entry.frame and entry or empty;record.item=item;record.index=index
    local included=not item.hidden and (o.includeHidden or frame:IsShown())
    if place then
     local box=frame._lycheeBoxValues or empty
     record.entry,record.included=entry,included
     record.iw,record.ih,record.iminW,record.imaxW,record.iminH,record.imaxH=item.width,item.height,item.minWidth,item.maxWidth,item.minHeight,item.maxHeight
     record.igrow,record.ishrink,record.ialign,record.igap=item.grow,item.shrink,item.align,item.gapAfter
     record.bminW,record.bmaxW,record.bminH,record.bmaxH,record.balign=box.minWidth,box.maxWidth,box.minHeight,box.maxHeight,box.align
    end
    if included then
     local w,h;if record.nativeSize then w,h=frame:GetSize() else w,h=frame:GetWidth(),frame:GetHeight() end;local wref,href=item.width,item.height
     if frame._lycheeFixedRecords then wref,href=C.FixedValue(frame,"width",wref),C.FixedValue(frame,"height",href) end
     local box=frame._lycheeBoxValues or empty
     local simple=box==empty and not frame._lycheeFixedRecords
      and (wref==nil or wref=="fill" or type(wref)=="number" and wref==wref)
      and (href==nil or href=="fill" or type(href)=="number" and href==href) and w==w and h==h
      and item.minWidth==nil and item.maxWidth==nil and item.minHeight==nil and item.maxHeight==nil
      and item.grow==nil and item.shrink==nil and item.align==nil
     if simple then
      if type(wref)=="number" then w=wref end;if type(href)=="number" then h=href end
      w,h=math.max(0,w),math.max(0,h)
      local align=o.align or "start";local cross,crossRef,mainRef
      if vertical then cross,crossRef,mainRef=w,wref,href else cross,crossRef,mainRef=h,href,wref end
      if innerCross and (crossRef=="fill" or align=="stretch") then cross=innerCross end
      local size=mainRef=="fill" and 0 or (vertical and h or w)
      record.size,record.cross,record.grow,record.shrink,record.align,record.gap=size,cross,mainRef=="fill" and 1 or 0,0,align,nil
      record.crossMin,record.crossMax,record.heightRef=0,math.huge,href;record.min,record.max=0,math.huge
     else
     if wref=="content" or href=="content" then cacheable=false;local naturalW,naturalH=Natural(frame);if wref=="content" then w=naturalW end;if href=="content" then h=naturalH end end
     if wref and wref~="content" and wref~="fill" then w=Value(wref) end
     if href and href~="content" and href~="fill" then h=Value(href) end
     w=math.max(Value(item.minWidth or box.minWidth or 0),math.min(Value(item.maxWidth or box.maxWidth or math.huge),w))
     h=math.max(Value(item.minHeight or box.minHeight or 0),math.min(Value(item.maxHeight or box.maxHeight or math.huge),h))
     local align=item.align or box.align or o.align or "start"
     local crossRef;if vertical then crossRef=wref else crossRef=href end
     local crossSize=vertical and w or h
     if innerCross and (crossRef=="fill" or align=="stretch") then crossSize=innerCross end
     local crossMin,crossMax
     if vertical then crossMin,crossMax=Value(item.minWidth or box.minWidth) or 0,Value(item.maxWidth or box.maxWidth) or math.huge
     else crossMin,crossMax=Value(item.minHeight or box.minHeight) or 0,Value(item.maxHeight or box.maxHeight) or math.huge end
     crossSize=math.max(crossMin,math.min(crossMax,crossSize))
     if vertical then
      w=crossSize
      if frame.GetStringHeight and href=="content" then local previous=frame:GetWidth();if not (previous==w or w==record.committedW and previous==record.nativeReadW) then frame:SetWidth(w) end;h=frame:GetStringHeight();if not place and frame:GetWidth()~=previous then frame:SetWidth(previous) end end
     else h=crossSize end
     local mainRef;if vertical then mainRef=href else mainRef=wref end;local weight=item.grow or (mainRef=="fill" and 1 or 0)
     local size=mainRef=="fill" and 0 or (vertical and h or w)
     record.size,record.cross,record.grow,record.shrink,record.align,record.gap=size,vertical and w or h,weight,item.shrink or 0,align,nil
     record.crossMin,record.crossMax,record.heightRef=crossMin,crossMax,href
     if vertical then record.min,record.max=Value(item.minHeight or box.minHeight) or 0,Value(item.maxHeight or box.maxHeight) or math.huge
     else record.min,record.max=Value(item.minWidth or box.minWidth) or 0,Value(item.maxWidth or box.maxWidth) or math.huge end
     end
     active[#active+1]=record;total=total+record.size;grow=grow+record.grow;shrink=shrink+record.shrink
    end
   end
   for i=1,#active-1 do local gap=Value(active[i].item.gapAfter or o.gap or 0);active[i].gap=gap;total=total+gap end
   local extra=innerMain and innerMain-total or 0
   for _,record in ipairs(active) do
    if extra>0 and grow>0 then record.size=record.size+extra*record.grow/grow
    elseif extra<0 and shrink>0 then record.size=record.size+extra*record.shrink/shrink end
    record.size=math.max(record.min,math.min(record.max,record.size))
   end
   local used,maxCross=0,0
   for _,record in ipairs(active) do
    if not vertical and record.frame.GetStringHeight and record.heightRef=="content" then
     local frame=record.frame;local previous=frame:GetWidth();if not (previous==record.size or record.size==record.committedW and previous==record.nativeReadW) then frame:SetWidth(record.size) end
     record.cross=frame:GetStringHeight()
     if not place and frame:GetWidth()~=previous then frame:SetWidth(previous) end
    end
    record.cross=math.max(record.crossMin,math.min(record.crossMax,record.cross))
    used=used+record.size+(record.gap or 0);maxCross=math.max(maxCross,record.cross)
   end
   local contentW=vertical and maxCross+padCross or used+padMain
   local contentH=vertical and used+padMain or maxCross+padCross
   local boxW,boxH=width or contentW,height or contentH
   if place then
    self.contentWidth,self.contentHeight=contentW,contentH
    local anchor=o.anchor or "TOPLEFT";local ox,oy=Value(o.x or 0),-Value(o.y or 0)
    if anchor:find("RIGHT") then ox=ox+parent:GetWidth()-boxW elseif anchor=="CENTER" then ox=ox+(parent:GetWidth()-boxW)/2 end
    if anchor:find("BOTTOM") then oy=oy+parent:GetHeight()-boxH elseif anchor=="CENTER" then oy=oy+(parent:GetHeight()-boxH)/2 end
    local remaining=math.max(0,(innerMain or used)-used);local cursor=o.justify=="end" and remaining or o.justify=="center" and remaining/2 or 0
    local between=o.justify=="space-between" and #active>1 and remaining/(#active-1) or 0
    local owned=self.owned
    for frame in pairs(owned) do owned[frame]=false end
    for _,record in ipairs(active) do
     local frame=record.frame;owned[frame]=true
     local crossSpace=(innerCross or maxCross)-record.cross
     local crossOffset=record.align=="end" and crossSpace or record.align=="center" and crossSpace/2 or 0
     local x=ox+left+(vertical and crossOffset or cursor)
     local y=oy+top+(vertical and cursor or crossOffset)
     local w,h=vertical and record.cross or record.size,vertical and record.size or record.cross
     local actualW,actualH;if record.nativeSize then actualW,actualH=frame:GetSize() else actualW,actualH=frame:GetWidth(),frame:GetHeight() end
     local matches=(actualW==w or w==record.committedW and actualW==record.nativeReadW) and (actualH==h or h==record.committedH and actualH==record.nativeReadH)
     if not matches and not LegacyPreviousSizeMatches(frame,record,w,h,actualW,actualH) then frame:SetSize(w,h);if record.nativeSize then actualW,actualH=frame:GetSize() else actualW,actualH=frame:GetWidth(),frame:GetHeight() end end
     frame._lycheeLayoutOwner=self
     record.x,record.y,record.placedW,record.placedH=x,y,w,h;frame._lycheeLayoutPlace=record.place
     local moved=frame._lycheeLayoutPlace()
     if frame._lycheeLayoutOwner==self and not self.released then
      if not moved then record.nativeReadW,record.nativeReadH=actualW,actualH end
      record.committedW,record.committedH=w,h
     end
     cursor=cursor+record.size+(record.gap or 0)+between
    end
    for frame,present in pairs(owned) do if not present then if frame._lycheeLayoutOwner==self then frame._lycheeLayoutOwner,frame._lycheeLayoutPlace=nil,nil end;owned[frame]=nil end end
   end
   -- Measurement has no placement ownership. Retain only its current records
   -- and any earlier placement that this controller must still relinquish.
   for frame,record in pairs(self.records) do
    local entry=self.items[record.index]
    if (not entry or (entry.frame or entry)~=frame) and (place or frame._lycheeLayoutOwner~=self) then self.records[frame]=nil end
   end
   if place then
    self.cached,self.cachedItems,self.itemCount=cacheable,self.items,#self.items
    self.parentW,self.parentH,self.width,self.height=parentW,parentH,width,height
    self.left,self.top,self.right,self.bottom=left,top,right,bottom
    self.align,self.justify,self.anchor,self.x,self.y,self.gap,self.includeHidden=o.align,o.justify,o.anchor,o.x,o.y,o.gap,o.includeHidden
   end
   return contentW,contentH
  end
  function layout:Measure(w,h) return self:Run(w,h,false) end
  function layout:Layout(w,h) return self:Run(w,h,true) end
  function layout:Release()
   if self.released then return end
   self.released=true
   for frame in pairs(self.owned) do if frame._lycheeLayoutOwner==self then frame._lycheeLayoutOwner,frame._lycheeLayoutPlace=nil,nil end end
   for i,value in ipairs(UI.layouts) do if value==self then table.remove(UI.layouts,i);break end end
   self.owned,self.records,self.active,self.items={},{},{},{}
   self.cachedItems,self.cached=nil,false
  end
  return layout
 end
 function C.Row(parent,items,options) return Create(parent,items,options,false) end
 function C.Column(parent,items,options) return Create(parent,items,options,true) end
 function C.RefreshLayouts()
  for target in pairs(UI.boxes) do target._lycheeBoxApply() end
  for _,layout in ipairs(UI.layouts) do if not layout.released then
   layout.cached=false;if layout.Invalidate then layout:Invalidate("refresh") end
   if not (layout.mode=="flex" and layout.options.track and not layout.parent:IsVisible()) then layout:Layout() end
  end end
 end
 local boxKeys={"minWidth","maxWidth","minHeight","maxHeight","padding","align","fit","direction","flowWrap","gap","lineGap","basis","grow","shrink","justify","participate","reserve","manageWidth","manageHeight","managePoints"}
 local boxLiteral={align=true,fit=true,padding=true,direction=true,justify=true,basis=true}
 local function BoxDimension(target,value,available,isLayout)
  if value=="content" then
   if isLayout then return nil end
   local w,h=Natural(target);return w,h
  end
  return Dimension(value,available,"Box dimension")
 end
 function C.Box(target,spec)
  local owner=target._lycheeBoxContext;local prior=target._lycheeBoxLayout
  if owner and owner~=UI or prior and prior.context and prior.context~=UI then error("Box belongs to another Context; ReleaseBox it before rebinding",2) end
  if target._lycheeBoxRules then C.ClearBoxRules(target) end
  if type(spec)~="table" then
   local n=Value(spec)
   if n then target:SetSize(n,n) end
   if target._lycheeBoxLayout then target._lycheeBoxLayout:Release();target._lycheeBoxLayout=nil end
   target._lycheeBoxValues,target._lycheeBoxApply,target._lycheeBoxContext=nil,nil,nil;UI.boxes[target]=nil
   C.ApplyElement(target);if C.InvalidateLayout then C.InvalidateLayout(target,"box") end;return target
  end
  local box=type(spec)=="table" and spec or {width=spec,height=spec}
  local values=target._lycheeBoxValues
  for _,key in ipairs(boxKeys) do
   if box[key]~=nil then values=values or {};values[key]=(boxLiteral[key] or type(box[key])=="string" and box[key]:find("%%")) and box[key] or Value(box[key])
   elseif values then values[key]=nil end
  end
  if values and not next(values) then values=nil end
  local hasMetadata=values~=nil
  target._lycheeBoxValues=values;values=values or empty
  target._lycheeBoxContext=(hasMetadata or box.classes or box.conditions or box.layout or box.content) and UI or nil
  local relative=target:GetParent();local ratio=relative and Scale(relative)/Scale(target) or 1
  local parentW,parentH=relative and relative:GetWidth()*ratio,relative and relative:GetHeight()*ratio
  -- Establish current native fallback values before fixed rules are applied.
  local widthSpec,heightSpec=box.width or box[1],box.height or box[2]
  local width=widthSpec~="content" and BoxDimension(target,widthSpec,parentW,false)
  if width then target:SetWidth(Clamp(width,Dimension(values.minWidth,parentW,"Box minWidth") or 0,Dimension(values.maxWidth,parentW,"Box maxWidth") or math.huge)) end
  local height=heightSpec~="content" and BoxDimension(target,heightSpec,parentH,false)
  if height then target:SetHeight(Clamp(height,Dimension(values.minHeight,parentH,"Box minHeight") or 0,Dimension(values.maxHeight,parentH,"Box maxHeight") or math.huge)) end
  if box.classes or box.conditions then C.RegisterBoxRules(target,box) else C.ApplyElement(target) end
  local direction=Field(target,"direction",Field(target,"layout",box.layout));local isLayout=direction=="row" or direction=="column"
  target._lycheeBoxContext=(hasMetadata or target._lycheeBoxRules or isLayout or box.content) and UI or nil
  widthSpec,heightSpec=Field(target,"width",widthSpec),Field(target,"height",heightSpec)
  width=BoxDimension(target,widthSpec,parentW,isLayout)
  if width then
   width=Clamp(width,Dimension(Field(target,"minWidth",values.minWidth),parentW,"Box minWidth") or 0,Dimension(Field(target,"maxWidth",values.maxWidth),parentW,"Box maxWidth") or math.huge)
   if target:GetWidth()~=width then target:SetWidth(width) end
  end
  if heightSpec=="content" and not isLayout then local _,h=Natural(target);height=h else height=BoxDimension(target,heightSpec,parentH,isLayout) end
  if height then
   height=Clamp(height,Dimension(Field(target,"minHeight",values.minHeight),parentH,"Box minHeight") or 0,Dimension(Field(target,"maxHeight",values.maxHeight),parentH,"Box maxHeight") or math.huge)
   if target:GetHeight()~=height then target:SetHeight(height) end
  end
  if C.InvalidateLayout then C.InvalidateLayout(target,"box") end
  if direction=="row" or direction=="column" then
   if target._lycheeBoxLayout then target._lycheeBoxLayout:Release() end
   local options={mode="flex"}
   for key,value in pairs(box) do if key~="width" and key~="height" and key~="items" and key~="layout" and key~="classes" and key~="conditions" then options[key]=value end end
   options.direction=direction
   if box.width=="content" then options.width="content" end
   if box.height=="content" then options.height="content" end
   local layout=Create(target,box.items,options,direction=="column");target._lycheeBoxLayout=layout;layout.boxTarget=target
   layout:Layout();return target,layout
  elseif target._lycheeBoxLayout then target._lycheeBoxLayout:Release();target._lycheeBoxLayout=nil end
  local content=box.content;local ratio=content and content:GetWidth()>0 and content:GetHeight()>0 and content:GetWidth()/content:GetHeight() or 1
  if not content then target._lycheeBoxApply=nil;UI.boxes[target]=nil;return target end
  target._lycheeBoxApply=function()
   local values=target._lycheeBoxValues or empty
   if content and values.fit and values.fit~="none" then
    local left,top,right,bottom=Padding(values.padding)
    local w,h=math.max(0,target:GetWidth()-left-right),math.max(0,target:GetHeight()-top-bottom)
    local fit=values.fit=="cover" and math.max(w/ratio,h) or math.min(w/ratio,h)
    if content:GetWidth()~=fit*ratio or content:GetHeight()~=fit then content:SetSize(fit*ratio,fit) end
    local a,b,c,x,y=content:GetPoint()
    local cx,cy=(left-right)/2,(bottom-top)/2
    if content:GetNumPoints()~=1 or a~="CENTER" or b~=target or c~="CENTER" or x~=cx or y~=cy then content:ClearAllPoints();content:SetPoint("CENTER",target,"CENTER",cx,cy) end
   end
  end
  UI.boxes[target]=true;target._lycheeBoxApply();return target
 end
end
