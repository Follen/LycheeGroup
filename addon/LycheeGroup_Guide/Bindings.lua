-- Primary native scripts are leased only for the active teaching phase.
local Guide=assert(_G.LycheeGroup.Guide)
local Bindings={records={}}
Guide.Bindings=Bindings

local function SetPrimary(control,event,script)
 -- Retail enables clicks when an enter/leave script is assigned. Preserve the
 -- current flags around each assignment, including the final restoration.
 local clicks=type(control.IsMouseEnabled)=="function" and control:IsMouseEnabled()
 local motion=type(control.IsMouseMotionEnabled)=="function" and control:IsMouseMotionEnabled()
 control:SetScript(event,script)
 if type(control.IsMouseEnabled)=="function" and type(control.EnableMouse)=="function" and control:IsMouseEnabled()~=clicks then control:EnableMouse(clicks) end
 if type(control.IsMouseMotionEnabled)=="function" and type(control.EnableMouseMotion)=="function" and control:IsMouseMotionEnabled()~=motion then control:EnableMouseMotion(motion) end
end

local function Interrupted(owner,err)
 if owner then pcall(owner.Stop,owner,"interrupted") end
 error(err,0)
end

local function Dispatch(record,control,...)
 local owner=record.owner
 if record.before then
  local ok,err=pcall(record.before,control,...)
  if not ok then Interrupted(owner,err) end
 end
 local original=record.original
 if original then
  local ok,err=pcall(original,control,...)
  if not ok then Interrupted(owner,err) end
 end
 -- The original callback may finish the phase or stop the entire guide.
 local handler=record.handler
 if handler then
  local ok,err=pcall(handler,control,...)
  if not ok then Interrupted(owner,err) end
 end
end

function Bindings:Bind(control,event,handler,before)
 assert(control and type(control.GetScript)=="function" and type(control.SetScript)=="function","a native script control is required")
 assert(type(event)=="string" and event~="","a script event is required")
 assert(type(handler)=="function","a teaching handler is required")
 local original=control:GetScript(event)
 local records,index=self.records
 for i,record in ipairs(records) do
  if record.control==control and record.event==event then
   if original==record.wrapper then record.handler,record.before=handler,before;return record.wrapper end
   -- An external script may retain this old wrapper in its own callback chain.
   -- Keep its original function usable while releasing all teaching ownership.
   record.handler,record.before,record.owner,record.control,record.event,record.wrapper=nil,nil,nil,nil,nil,nil
   index=i;break
  end
 end
 local record={control=control,event=event,original=original,handler=handler,before=before,owner=Guide}
 local function wrapper(nativeControl,...) Dispatch(record,nativeControl,...) end
 record.wrapper=wrapper
 records[index or #records+1]=record
 SetPrimary(control,event,wrapper)
 return wrapper
end

function Bindings:Clear()
 local records=self.records
 self.records={}
 -- Disable the whole phase before restoring any script: restoration itself
 -- can reenter Clear or invoke another control through an external wrapper.
 for _,record in ipairs(records) do record.handler,record.before,record.owner=nil,nil,nil end
 for _,record in ipairs(records) do
  local control,event,wrapper=record.control,record.event,record.wrapper
  record.control,record.event,record.wrapper=nil,nil,nil
  if control and control:GetScript(event)==wrapper then SetPrimary(control,event,record.original) end
 end
end
