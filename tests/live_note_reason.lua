-- Read the built note editor without changing its text or saved record.
local probe=...
local A=assert(LycheeGroup,"LycheeGroup is not loaded")
local UI=assert(A.UI,"UI is not loaded")
local page=assert(UI.pages.notes,"Notes page is not loaded")
assert(page.editor,"Open a player note once before this check")
local reason=page.eReason
local _,fontSize=reason.box:GetFont()
local report={
 visible=page.editor:IsVisible(),
 windowHeight=UI.windowHeight,editorHeight=page.editor:GetHeight(),
 fieldHeight=reason:GetHeight(),viewportHeight=reason.scroll:GetHeight(),
 lineHeight=UI.context:GetLineHeight(20),fontSize=fontSize,
 scroll=reason.scroll:GetVerticalScroll(),
 nativeTextHeight=reason.box:GetHeight(),
}
probe:Log(("visible=%s window=%.2f editor=%.2f field=%.2f viewport=%.2f line=%.2f font=%.2f scroll=%.2f"):format(
 tostring(report.visible),report.windowHeight,report.editorHeight,report.fieldHeight,report.viewportHeight,report.lineHeight,report.fontSize,report.scroll))
assert(report.viewportHeight+.01>=report.lineHeight,"note reason viewport clips a complete text line")
return report
