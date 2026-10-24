-- Native-frame rendering checks with explicitly synthetic applicant records.
-- No application, invite, decline, listing or hardware input is submitted.
local probe=...
local A=assert(LycheeGroup)
assert(not InCombatLockdown(),"combat")
local initial=A.UI
assert(not initial or not initial.preview and not initial.activeModal,"existing_preview_or_modal")
local original={shown=initial and initial:IsShown(),page=initial and initial.page,returnPage=initial and initial.settingsReturnPage}
local originalPages={}
if initial then for key,page in pairs(initial.pages)do originalPages[key]=page.frame and page.frame:IsShown() or false end end
local U,F,row,timer,cleaned,glyphParent,glyphStyle
local out={scope="native Frame construction, explicit style SetState and local Preview rendering; synthetic applicant data; no hardware dispatch",checks=0,times={}}
local function Check(value,message)out.checks=out.checks+1;assert(value,message)end
local function Color(texture,expected)
 local r,g,b,a=texture:GetVertexColor()
 return math.abs(r-expected[1])<1/255+.00001 and math.abs(g-expected[2])<1/255+.00001 and math.abs(b-expected[3])<1/255+.00001 and math.abs(a-(expected[4] or 1))<1/255+.00001
end
local function Clean()
 if cleaned then return end
 if timer then timer:Cancel()end
 if glyphStyle then glyphStyle:Release();glyphStyle=nil end
 if glyphParent then glyphParent:Hide();glyphParent:SetParent(nil);glyphParent=nil end
 if row then row.cancelGlyphStyle:SetState("hover",false);row:Hide()end
 if U then
  U.Tooltip:Hide();U:CloseMenu()
  if U.preview then if U.frame then U:StopPreview(false)else U:EndPreview()end end
  if U.frame then
   if original.shown then assert(A:Open(original.page or "find"))else
    U:Hide(true)
    for key,page in pairs(U.pages)do if page.frame then page.frame:SetShown(originalPages[key]==true)end end
    U.page=original.page;U:UpdateNav()
   end
   U.settingsReturnPage=original.returnPage
  end
 end
 cleaned=true
end
assert(probe:OnCleanup(Clean))
assert(probe:Async(20))
assert(A:Ensure("Group"));assert(A:Ensure("UI"));U=A.UI;F=A.Floating
out.libraryRevision=LycheeUI.version
Check(out.libraryRevision==36,"repaired_library_not_loaded")
Check(not A.Group:GetListing() and A.Group.Applications:GetActiveCount()==0,"active_business_requires_read_only_scene")
assert(probe:Guard(function()
 return not InCombatLockdown() and not C_LFGList.HasActiveEntryInfo() and not A.Group:GetListing() and A.Group.Applications:GetActiveCount()==0
end,{"PLAYER_REGEN_DISABLED","PLAYER_LEAVING_WORLD","LFG_LIST_ACTIVE_ENTRY_UPDATE","LFG_LIST_APPLICATION_STATUS_UPDATED"},"scene_changed"))
F:Build()
for _,candidate in ipairs(F.rows)do if candidate.kind=="application" and not candidate:IsShown() then row=candidate;break end end
row=row or F:CreateRow("application")
Check(row:GetObjectType()=="Button" and row.GetVertexColor==nil,"native_frame_has_no_texture_color_method")
local icon=row.cancel.elementIcon
Check(icon:GetObjectType()=="Frame" and icon:GetParent()==row.cancel,"public_cancel_icon_keeps_frame_and_parent")
Check(icon.GetVertexColor==nil and icon.texture:GetObjectType()=="Texture","glyph_uses_native_texture_color")
Check(Color(icon.texture,F.context.Theme.dim),"cancel_default_color")
row.cancelGlyphStyle:SetState("hover",true);Check(Color(icon.texture,F.context.Theme.brand),"cancel_hover_color")
row.cancelGlyphStyle:SetState("hover",false);Check(Color(icon.texture,F.context.Theme.dim),"cancel_leave_color")
local C=F.context.C
glyphParent=CreateFrame("Frame",nil,UIParent);glyphParent:SetSize(160,60);glyphParent:SetPoint("CENTER")
local glyph=C.Glyph(glyphParent,"close",16,{.12,.23,.34,1})
glyphStyle=C.Style(glyph,{style={root={width=19,height=15,color="good",points={{"CENTER","$parent","CENTER",3,-2}}}},states={hover={root={color="brand"}}},immediate=true})
local point,relative,relativePoint,x,y=glyph:GetPoint()
Check(point=="CENTER" and relative==glyphParent and relativePoint=="CENTER" and math.abs(x-3)<.01 and math.abs(y+2)<.01,"glyph_parent_anchor_preserved")
Check(math.abs(glyph:GetWidth()-19)<.01 and math.abs(glyph:GetHeight()-15)<.01,"glyph_frame_custom_dimensions")
Check(math.abs(glyph.texture:GetWidth()-19)<.01 and math.abs(glyph.texture:GetHeight()-15)<.01,"glyph_native_texture_follows_frame_dimensions")
local gx,gy=glyph:GetCenter();local px,py=glyphParent:GetCenter()
Check(math.abs(gx-px-3)<.01 and math.abs(gy-py+2)<.01,"glyph_actual_parent_center_offset")
Check(Color(glyph.texture,F.context.Theme.good),"glyph_custom_base_color")
glyphStyle:SetState("hover",true);Check(Color(glyph.texture,F.context.Theme.brand),"glyph_custom_hover_color")
glyphStyle:SetState("hover",false);Check(Color(glyph.texture,F.context.Theme.good),"glyph_custom_leave_color")
out.glyph={width=glyph.texture:GetWidth(),height=glyph.texture:GetHeight(),offsetX=gx-px,offsetY=gy-py,frameSlot=true}
glyphStyle:Release();glyphStyle=nil
Check(Color(glyph.texture,{.12,.23,.34,1}),"glyph_release_restores_original_color")
Check(math.abs(glyph:GetWidth()-16)<.01 and math.abs(glyph:GetHeight()-16)<.01,"glyph_release_restores_original_dimensions")
glyphParent:Hide();glyphParent:SetParent(nil);glyphParent=nil
out.floatingPoolRows=#F.rows
assert(U:StartPreview("applicants"))
timer=C_Timer.NewTimer(.5,assert(probe:Callback(function()
 local P=U.pages.create;local person
 for _,batch in ipairs(P.batchPool)do if batch:IsShown()then for _,candidate in ipairs(batch.people)do
  if candidate:IsShown() and candidate.member and candidate.mapScoreKey then person=candidate;break end
 end end;if person then break end end
 Check(person~=nil,"preview_applicant_missing")
 local key=person.mapScoreKey
 P.applicantTimeModes={[key]=true}
 local run=assert(person.member.dungeonScores.current)
 local cases={
  {1747000,"29:07","dungeonTimeGreen",true},
  {1746000,"29:06","dungeonTimeBlue",true},
  {1710000,"28:30","dungeonTimePurple",true},
  {1620000,"27:00","dungeonTimeOrange",true},
  {1801000,"30:01","dungeonTimeOvertime",true},
 }
 for _,case in ipairs(cases)do
  run.durationMs,run.timeLimitSeconds,run.timed=case[1],1800,case[4]
  P:RefreshApplicants()
  Check(person.mapScoreTime==true,"preview_time_mode")
  local expected=U:Hex(U.Theme[case[3]])..case[2].."|r/30:00"
  Check(person.mapScore:GetText()==expected,"preview_time_color:"..case[3])
  Check(person.mapScore:GetUnboundedStringWidth()<=person.mapScore:GetWidth()+1,"native_time_text_fits")
  out.times[#out.times+1]={token=case[3],text=person.mapScore:GetText(),width=person.mapScore:GetWidth(),textWidth=person.mapScore:GetUnboundedStringWidth()}
 end
 U.Tooltip:ShowPlayer(person,person.member,person.memberContext)
 local tip=U.Tooltip.interactive
 Check(tip.dungeonRows[1].status:GetText()==person.mapScore:GetText(),"tooltip_and_list_time_agree")
 Check(tip.dungeonRows[2].status:GetText():find("/30:00",1,true)~=nil,"best_run_keeps_own_limit")
 out.bestRun=tip.dungeonRows[2].status:GetText()
 Clean()
 Check(not U.preview and not U.Tooltip.owner,"preview_cleanup")
 out.resourcesReleased=cleaned
 probe:Finish(out)
end)))
