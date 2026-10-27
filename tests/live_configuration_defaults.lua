-- Read-only product smoke check plus private native style ownership objects.
-- No player preferences, listings, applications, pages or bindings are changed.
local probe=...
local A=assert(_G.LycheeGroup,"product_not_loaded")
local library=assert(_G.LycheeUI,"library_not_loaded")
assert(library.version>=10001,"requires_icon_ownership_fix")
assert(A.RuntimeTheme and not A.RuntimeTheme.error,"startup_theme_failed")
assert(not InCombatLockdown(),"requires_out_of_combat")
local api=assert(A.API and A.API.Configuration,"configuration_api_missing")
for _,method in ipairs({"RegisterPreset","SetDefaultPreset","UseDefaultPreset","GetPresetStatus"}) do assert(type(api[method])=="function","missing_"..method) end
local keys={"settings.toggleBinding","settings.autoApply","settings.applicationRoles","settings.creationRaidDifficultyID","settings.find.category","settings.find.categories.seasonDungeon.minRating","settings.find.categories.seasonDungeon.requireBloodlust","layout.floating.position"}
for _,id in ipairs({"findResults","findRaidResults","findApplications","createApplicants","notesRecords","notesHistory","notesHistoryMembers","blockedLeaders"}) do keys[#keys+1]="layout.tables."..id..".sortKey" end
local schema=api:GetSchema(keys)
for _,key in ipairs(keys) do assert(schema[key],"missing_schema_"..key) end
local builtins=0
for _,entry in ipairs(A.API.Theme:List({includeBuiltins=true})) do
 assert(entry.id~="lycheegroup.white","removed_white_theme_remains")
 if entry.builtin then builtins=builtins+1 end
end
assert(builtins==2,"unexpected_builtin_count")
local parent,ctx,glyphStyle,labelStyle,textureColorStyle,textureAlphaStyle,motionCtx,motionStyle
assert(probe:OnCleanup(function()
 if glyphStyle then glyphStyle:Release() end
 if labelStyle then labelStyle:Release() end
 if textureColorStyle then textureColorStyle:Release() end
 if textureAlphaStyle then textureAlphaStyle:Release() end
 if motionStyle then motionStyle:Release() end
 if motionCtx then motionCtx.Motion:StopAll();motionCtx:Hide() end
 if ctx then ctx:Hide() end
 if parent then parent:Hide() end
end))
parent=CreateFrame("Frame",nil,UIParent);parent:SetSize(100,60);parent:Hide()
ctx=library:CreateContext({parent=parent,reducedMotion=true})
local C=ctx.C
local color={.17,.38,.61,1}
local glyph=C.Glyph(parent,"book",20)
glyphStyle=C.Style(glyph,{style={root={color=color}}})
local function Near(a,b) return math.abs(a-b)<.005 end
for _,state in ipairs({{true,false},{false,true},{false,false}}) do
 glyph:SetSelected(state[1],state[2])
 local r,g,b=glyph.texture:GetVertexColor()
 assert(Near(r,color[1]) and Near(g,color[2]) and Near(b,color[3]),"native_glyph_color_overwritten")
 assert(glyph.texture:IsDesaturated()==not state[1],"undeclared_grayscale_stopped")
end
glyphStyle:Release();glyphStyle=nil
local r,g,b=glyph.texture:GetVertexColor()
assert(Near(r,ctx.Theme.iconIdleTint) and Near(g,ctx.Theme.iconIdleTint) and Near(b,ctx.Theme.iconIdleTint),"native_release_fallback_failed")
assert(Near(glyph.texture:GetAlpha(),ctx.Theme.iconIdleAlpha) and glyph.texture:IsDesaturated(),"native_release_feedback_changed")
textureColorStyle=C.Style(glyph.texture,{style={root={color=color}},states={selected={root={color={.61,.38,.17,1}}}}})
textureAlphaStyle=C.Style(CreateFrame("Frame",nil,parent),{slots={image=glyph.texture},style={image={alpha=.35}}})
glyph:SetSelected(false,false)
textureColorStyle:SetState("selected",true)
assert(Near(glyph.texture:GetAlpha(),.35),"native_color_state_overwrote_alpha_owner")
textureColorStyle:Release();textureColorStyle=nil
assert(Near(glyph.texture:GetAlpha(),.35),"native_color_release_overwrote_alpha_owner")
textureAlphaStyle:Release();textureAlphaStyle=nil
assert(Near(glyph.texture:GetAlpha(),ctx.Theme.iconIdleAlpha),"native_alpha_owner_release_failed")
local button=C.Button(parent,"Ownership",80)
labelStyle=C.Style(button.label,{style={root={color=color}}})
button:SetActive(true);button:SetActive(false)
r,g,b=button.label:GetTextColor()
assert(Near(r,color[1]) and Near(g,color[2]) and Near(b,color[3]),"native_child_label_overwritten")
motionCtx=library:CreateContext({parent=parent,reducedMotion=false})
local animated=motionCtx.C.Glyph(parent,"book",20)
local baseColor,hoverColor={.2,.3,.4,1},{.8,.7,.6,1}
motionStyle=motionCtx.C.Style(animated,{style={root={color=baseColor}},states={hover={root={color=hoverColor}}},duration=.2})
motionStyle:SetState("hover",true);motionCtx.Motion:Tick(.05)
r=animated.texture:GetVertexColor()
assert(r>baseColor[1]+.005 and r<hoverColor[1]-.005,"native_glyph_color_did_not_animate")
motionStyle:SetState("hover",false);motionCtx.Motion:Tick(0)
assert(Near(animated.texture:GetVertexColor(),r),"native_glyph_retarget_jumped")
motionCtx.Motion:Tick(.3)
r,g,b=animated.texture:GetVertexColor()
assert(Near(r,baseColor[1]) and Near(g,baseColor[2]) and Near(b,baseColor[3]),"native_glyph_motion_did_not_finish")
return {library=library.versionString,schemaLeaves=#keys,builtinThemes=builtins,whiteRemoved=true,nativeGlyphStates=3,nativeRelease=true,nativeTextureAlphaOwnership=true,nativeChildOwnership=true,nativeGlyphColorMotion=true,theme=A.API.Theme:GetStatus().current.id,preferences=A.API.Configuration:GetPresetStatus(),productVersion=C_AddOns.GetAddOnMetadata("LycheeGroup","Version")}
