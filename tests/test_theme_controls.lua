-- Exercise the actual application modal, including its leased native note.
local Fixture=dofile("tests/ui_fixture.lua")
local function Composite(top,bottom)
 local alpha=top[4] or 1
 return {top[1]*alpha+bottom[1]*(1-alpha),top[2]*alpha+bottom[2]*(1-alpha),top[3]*alpha+bottom[3]*(1-alpha),1}
end
local function Luminance(color)
 local function Linear(value) return value<=.04045 and value/12.92 or ((value+.055)/1.055)^2.4 end
 return .2126*Linear(color[1])+.7152*Linear(color[2])+.0722*Linear(color[3])
end
local function Contrast(a,b)
 local x,y=Luminance(a),Luminance(b)
 return (math.max(x,y)+.05)/(math.min(x,y)+.05)
end
local function CheckUnchecked(modal,label)
 local background=Composite(modal.frame.surface.color,{0,0,0,1})
 local box=modal.autoApply.box
 local contrast=Contrast(Composite(box.fill.color,background),background)
 T.ok(box.fill:IsShown(),label..": unchecked solid fill is drawn")
 T.ok(contrast>=1.3 and contrast<=2.1,label..": unchecked fill stays distinct and subdued; contrast "..string.format("%.2f",contrast))
 T.eq(box.mark:IsShown(),false,label..": an unchecked box has no check mark")
 T.eq(box.outline,nil,label..": the checkbox uses a solid color difference without a border")
end
local function CheckFocus(note,modal,label)
 local background=Composite(modal.frame.surface.color,{0,0,0,1})
 T.ok(note.focused and note.inner and note.inner:IsShown(),label..": the focused inner surface is visible")
 T.ok(note.focus:IsShown(),label..": the focus outline is visible")
 local actual=Composite(note.inner.color,Composite(note.focus.color,background))
 local neutral=Composite(note.inner.color,background)
 local bleed=math.max(math.abs(actual[1]-neutral[1]),math.abs(actual[2]-neutral[2]),math.abs(actual[3]-neutral[3]))
 T.ok(bleed<=.01,label..": focus outline must not tint the field center; contamination "..string.format("%.3f",bleed))
 T.ok(Luminance(actual)<.08,label..": the note keeps a dark center while focused")
end
for _,id in ipairs({"lycheegroup.default","lycheegroup.frosted"}) do
 for _,locale in ipairs({"zhCN","enUS"}) do
 local f=Fixture(locale,{autoApply=false,applicationRoles={TANK=true}})
 if id~="lycheegroup.default" then
  assert(f.A.API.Theme:Activate(id))
  f=Fixture(locale,f.A.charPrefs,f.A.db)
 end
 f.A:SetSetting("reduceMotion",true);f.A:Open("find")
 local application=f.U.Application
 T.ok(application:OpenApplicationSettings())
 local modal=application.applicationModal
 local box=modal.autoApply.box
 local note=modal.note
 local label=id.."/"..locale
 CheckUnchecked(modal,label);CheckFocus(note,modal,label)
 local objects=#f.S.nodes
 for _=1,3 do
  modal.autoApply:Fire("OnClick","LeftButton")
  T.eq(box:GetChecked(),true);T.eq(box.mark:IsShown(),true)
  T.same(box.fill.color,f.U.context.Theme.primary,label..": a checked box retains the accent fill")
  modal.autoApply:Fire("OnClick","LeftButton")
  T.eq(box:GetChecked(),false);CheckUnchecked(modal,label)
  LFGListApplicationDialog.Description.EditBox:ClearFocus()
  T.eq(note.focus:IsShown(),false);T.eq(note.inner:IsShown(),false)
  T.eq(note.fill:IsShown(),true,label..": losing focus restores the resting field")
  f.U:CloseModal();T.ok(application:OpenApplicationSettings())
  T.eq(application.applicationModal,modal);T.eq(modal.autoApply.box,box)
  CheckUnchecked(modal,label);CheckFocus(note,modal,label)
 end
 T.eq(#f.S.nodes,objects,label..": toggling and reopening reuse all field and checkbox regions")
 f.U:CloseModal()
 dofile("addon/LycheeGroup/Entrypoints.lua");T.ok(f.A:Preview("applications"))
 T.ok(application:OpenApplicationSettings())
 CheckUnchecked(modal,label.."/preview");CheckFocus(modal.previewNote,modal,label.."/preview")
 modal.previewNote.box:ClearFocus()
 T.eq(modal.previewNote.focus:IsShown(),false)
 T.eq(f.A.charPrefs.autoApply,false,label..": visual checks retain the player's disabled preference")
 f.U:StopPreview(true)
 f.U:Hide(true)
 end
end
