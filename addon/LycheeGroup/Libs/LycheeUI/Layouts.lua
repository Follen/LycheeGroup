local _,private=...
local Library=private.LycheeUILoad
if not Library then return end
function Library.AttachLayouts(UI)
 local C=UI.C
 local empty={}
 UI.layouts={};UI.boxes=setmetatable({},{__mode="k"})
 local function Value(value) return UI:ResolveValue(value) end
 local function Padding(value)
  if type(value)~="table" then local n=Value(value or 0);return n,n,n,n end
  return Value(value.left or value[1] or 0),Value(value.top or value[2] or 0),Value(value.right or value[3] or 0),Value(value.bottom or value[4] or 0)
 end
 local measurements=setmetatable({},{__mode="k"})
 local measurementRevision=0
 local measure
 local function MeasureText(label,text,widthOnly)
  local path,size,flags=label:GetFont();local spacing=label:GetSpacing() or 0
  local wrap=label:CanWordWrap()
  local font=UI.fontStyles[label];local line=font and font.lineHeight;local single=font and font.singleLine
  local cached=measurements[label]
  if not cached then cached={values={},keys={},cursor=0,revision=0};measurements[label]=cached end
  if cached.invalidated~=measurementRevision or cached.path~=path or cached.size~=size or cached.flags~=flags or cached.spacing~=spacing or cached.line~=line or cached.single~=single or cached.wrap~=wrap then
   cached.path,cached.size,cached.flags,cached.spacing,cached.line,cached.single=path,size,flags,spacing,line,single
   cached.wrap=wrap
   cached.invalidated=measurementRevision;cached.revision=cached.revision+1
  end
  local current=label:GetText() or "";local candidate=text~=nil;text=text or current
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
 local function Natural(frame)
  if frame.GetStringWidth then return C.MeasureText(frame) end
  return frame:GetWidth(),frame:GetHeight()
 end
 local function Create(parent,items,options,vertical)
  local layout={parent=parent,items=items or {},options=options or {},vertical=vertical,owned={},records={},active={}}
  UI.layouts[#UI.layouts+1]=layout
  function layout:SetItems(values) self.items=values;self.cached=false;return self end
  function layout:SetOptions(values) for key,value in pairs(values) do self.options[key]=value end;return self end
  function layout:Run(availableW,availableH,place)
   -- Measure reuses the active records, so its temporary item set cannot serve
   -- a previously cached placement on the next Layout call.
   if not place then self.cached=false end
   local o=self.options;local left,top,right,bottom=Padding(o.padding or parent._lycheeBoxValues and parent._lycheeBoxValues.padding)
   local parentW,parentH=parent:GetWidth(),parent:GetHeight()
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
     if not r or r.index~=i or r.entry~=entry or r.included~=included
      or r.iw~=item.width or r.ih~=item.height or r.iminW~=item.minWidth or r.imaxW~=item.maxWidth or r.iminH~=item.minHeight or r.imaxH~=item.maxHeight
      or r.igrow~=item.grow or r.ishrink~=item.shrink or r.ialign~=item.align or r.igap~=item.gapAfter
      or r.bminW~=box.minWidth or r.bmaxW~=box.maxWidth or r.bminH~=box.minHeight or r.bmaxH~=box.maxHeight or r.balign~=box.align
      or included and (frame._lycheeLayoutOwner~=self or frame:GetWidth()~=r.placedW or frame:GetHeight()~=r.placedH) then stable=false;break end
    end
    if stable then
     for _,record in ipairs(self.active) do record.place() end
     return self.contentWidth,self.contentHeight
    end
   end
   local cacheable=place
   local main,cross;if vertical then main,cross=height,width else main,cross=width,height end
   local padMain=vertical and top+bottom or left+right;local padCross=vertical and left+right or top+bottom
   local innerMain=main and math.max(0,main-padMain);local innerCross=cross and math.max(0,cross-padCross)
   local active,total,grow,shrink=self.active,0,0,0
   for i=#active,1,-1 do active[i]=nil end
   for index,entry in ipairs(self.items) do
    local frame=entry.frame or entry;local record=self.records[frame]
    if not record then
     record={frame=frame};self.records[frame]=record
     record.place=function()
      local point,relative,relativePoint,x,y=frame:GetPoint()
      if frame:GetNumPoints()~=1 or point~="TOPLEFT" or relative~=parent or relativePoint~="TOPLEFT" or x~=record.x or y~=-record.y then
       frame:ClearAllPoints();frame:SetPoint("TOPLEFT",parent,"TOPLEFT",record.x,-record.y)
      end
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
     local w,h=frame:GetWidth(),frame:GetHeight();local wref,href=C.FixedValue(frame,"width",item.width),C.FixedValue(frame,"height",item.height)
     if wref=="content" or href=="content" then cacheable=false;local naturalW,naturalH=Natural(frame);if wref=="content" then w=naturalW end;if href=="content" then h=naturalH end end
     if wref and wref~="content" and wref~="fill" then w=Value(wref) end
     if href and href~="content" and href~="fill" then h=Value(href) end
     local box=frame._lycheeBoxValues or empty
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
      if frame.GetStringHeight and href=="content" then local previous=frame:GetWidth();if previous~=w then frame:SetWidth(w) end;h=frame:GetStringHeight();if not place and frame:GetWidth()~=previous then frame:SetWidth(previous) end end
     else h=crossSize end
     local mainRef;if vertical then mainRef=href else mainRef=wref end;local weight=item.grow or (mainRef=="fill" and 1 or 0)
     local size=mainRef=="fill" and 0 or (vertical and h or w)
     record.size,record.cross,record.grow,record.shrink,record.align,record.gap=size,vertical and w or h,weight,item.shrink or 0,align,nil
     record.crossMin,record.crossMax,record.heightRef=crossMin,crossMax,href
     if vertical then record.min,record.max=Value(item.minHeight or box.minHeight) or 0,Value(item.maxHeight or box.maxHeight) or math.huge
     else record.min,record.max=Value(item.minWidth or box.minWidth) or 0,Value(item.maxWidth or box.maxWidth) or math.huge end
     active[#active+1]=record;total=total+size;grow=grow+weight;shrink=shrink+record.shrink
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
     local frame=record.frame;local previous=frame:GetWidth();if previous~=record.size then frame:SetWidth(record.size) end
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
     if frame:GetWidth()~=w or frame:GetHeight()~=h then frame:SetSize(w,h) end
     frame._lycheeLayoutOwner=self
     record.x,record.y,record.placedW,record.placedH=x,y,w,h;frame._lycheeLayoutPlace=record.place
     frame._lycheeLayoutPlace();cursor=cursor+record.size+(record.gap or 0)+between
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
  for _,layout in ipairs(UI.layouts) do if not layout.released then layout.cached=false;layout:Layout() end end
 end
 function C.Box(target,spec)
  local box=type(spec)=="table" and spec or {width=spec,height=spec}
  local values=target._lycheeBoxValues or {};target._lycheeBoxValues=values
  for _,key in ipairs({"minWidth","maxWidth","minHeight","maxHeight","padding","align","fit"}) do values[key]=(key=="align" or key=="fit") and box[key] or Value(box[key]) end
  local width,height=Value(box.width or box[1]),Value(box.height or box[2])
  if width then target:SetWidth(math.max(Value(values.minWidth or 0),math.min(Value(values.maxWidth or math.huge),width))) end
  if height then target:SetHeight(math.max(Value(values.minHeight or 0),math.min(Value(values.maxHeight or math.huge),height))) end
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
