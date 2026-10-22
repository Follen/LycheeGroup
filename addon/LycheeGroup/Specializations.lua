-- Stable client metadata shared by lightweight and full UI consumers.
-- Loading this file performs no native reads; incomplete results remain retryable.
local S={};_G.LycheeGroup.Specializations=S
local classes,byID,byClassName={},{},{}
local classesComplete=false
local function Remember(id,name,icon)
 if id and name and icon then
  local entry=byID[id]
  if not entry then entry={id=id,name=name,icon=icon};byID[id]=entry end
  return entry
 end
end
function S:Get(id)
 local entry=byID[id]
 if entry then return entry.name,entry.icon end
 local _,name,_,icon=GetSpecializationInfoByID(id)
 Remember(id,name,icon)
 return name,icon
end
function S:Player()
 local selected=C_SpecializationInfo.GetSpecialization()
 if not selected then return end
 local id,name,_,icon=C_SpecializationInfo.GetSpecializationInfo(selected)
 Remember(id,name,icon)
 return id,name,icon
end
function S:Class(token)
 local entry=classes[token]
 if not entry and not classesComplete then
  local count=GetNumClasses();local complete=count>0
  for index=1,count do
   local name,file,id=GetClassInfo(index)
   if name and file then classes[file]={id=id or index,name=name} else complete=false end
  end
  classesComplete=complete
  entry=classes[token]
 end
 if entry then return entry.id,entry.name end
end
function S:Find(token,nameOrID)
 local classID=self:Class(token)
 if not classID then return end
 local entries=byClassName[classID]
 if not entries then entries={};byClassName[classID]=entries end
 local entry=entries[nameOrID]
 if entry then return entry.id,entry.name,entry.icon end
 for index=1,C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
  local id,label,_,icon=GetSpecializationInfoForClassID(classID,index)
  Remember(id,label,icon)
  if id and label and icon then
   local found={id=id,name=label,icon=icon}
   entries[label]=found;entries[id]=found
  end
  if id==nameOrID or label==nameOrID then return id,label,icon end
 end
end
