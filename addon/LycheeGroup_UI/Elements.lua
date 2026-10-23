-- Product identities reference existing visual objects; no parallel widget tree.
local UI=_G.LycheeGroup.UI
local C=UI.C
function UI:Element(target,id,scope,slots,template,key,stateOwner)
 if target then
  if not target.surface and target._lycheeVisuals then
   for _,visual in ipairs(target._lycheeVisuals) do if visual.SetColor then target.surface=visual;break end end
  end
  if id=="create.titleShell" or id=="create.descriptionShell" or id=="application.note" then
   slots={root=target,fill=target.fill,hover=target.hover,focus=target.focus}
  end
  if target.elementSlots then slots=target.elementSlots end
  if slots and target.surface then slots.surface=slots.surface or target.surface end
  local kind=target.GetObjectType and target:GetObjectType()
  stateOwner=stateOwner or ((kind=="Texture" or kind=="FontString" or target._lycheeTexture or id=="member.marks") and target:GetParent() or target)
  C.Element(target,id,{scope=scope,slots=slots or target,template=template,key=key,stateOwner=stateOwner})
 end
 return target
end
function UI:ElementFields(owner,prefix,names,scope,stateOwner)
 for field in names:gmatch("%S+") do
  local target=owner[field]
  if target then
   local kind=target.GetObjectType and target:GetObjectType()
   local visualOwner=stateOwner and (kind=="Texture" or kind=="FontString" or target._lycheeTexture) and stateOwner or nil
   self:Element(target,prefix.."."..field,scope,nil,nil,nil,visualOwner)
  end
 end
end
function UI:ElementList(list,id,scope,template)
 if not list then return end
 C.Element(list,id,{scope=scope,slots=list,rowTemplate=template or id..".row"})
end
-- Explicit business render/reflow endpoints reapply only fixed startup rules.
function UI:ApplyElementScope(scope)
 self.context:ApplyElements(scope)
end
