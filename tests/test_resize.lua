-- Directional window resizing, live row capacity and retained form contents.
local fixture=dofile("tests/ui_fixture.lua")
local f=fixture("zhCN")
local A,U,G,S=f.A,f.U,f.G,f.S
A:SetSetting("reduceMotion",true)
A:Open("find")
local handle=U.resizeHandle
local pressed=false
local previousMouse=IsMouseButtonDown
IsMouseButtonDown=function(button) return button=="LeftButton" and pressed end
-- The ordinary fixture has no screen-space anchor solver; use a fixed physical corner.
U.frame.GetLeft=function(frame) return 100/frame:GetEffectiveScale() end
U.frame.GetTop=function(frame) return 1000/frame:GetEffectiveScale() end
local function Begin()
 S.cursorX,S.cursorY=800,400;pressed=true
 handle:Fire("OnMouseDown","LeftButton")
end
local function Move(dx,dy)
 local scale=U.resizing.scale
 S.cursorX,S.cursorY=800+dx*scale,400-dy*scale
 handle:Fire("OnUpdate",.016)
end
local function Release()
 pressed=false;handle:Fire("OnMouseUp","LeftButton")
end

T.eq(handle.state,"normal")
T.eq(handle.icon:GetAlpha(),0,"the idle grip artwork is hidden while its hit target remains available")
T.eq(U.frame.clamped,false,"the window may be dragged past screen edges")
T.ok(handle.icon:GetTexture():find("resize%-grip%-lines%-normal.tga$")~=nil)
handle:Fire("OnEnter");T.eq(handle.state,"hover");T.eq(handle.icon:GetAlpha(),1)
handle:Fire("OnMouseDown","RightButton");T.eq(U.resizing,nil,"right-click does not resize")
local width,height=U.windowWidth,U.windowHeight
Begin();T.eq(handle.state,"pressed")
handle:Fire("OnLeave");T.eq(handle.state,"pressed","leaving the grip while held retains the pressed image")
Move(180,0)
T.near(U.windowWidth,width+180,.001);T.eq(U.windowHeight,height,"horizontal drag preserves height")
T.eq(A.charPrefs.windowSize,nil,"drag samples do not save preferences")
local anchor={U.frame:GetPoint()};T.eq(anchor[1],"TOPLEFT");T.eq(anchor[3],"BOTTOMLEFT")
T.near(anchor[4],100/U.frame:GetEffectiveScale(),.001);T.near(anchor[5],1000/U.frame:GetEffectiveScale(),.001)
Release();T.eq(handle.state,"normal");T.eq(handle:GetScript("OnUpdate"),nil)
T.eq(handle.icon:GetAlpha(),0,"releasing outside hides the grip artwork")
T.near(A.charPrefs.windowSize.width,width+180,.001)

width,height=U.windowWidth,U.windowHeight
Begin();Move(0,80);T.eq(U.windowWidth,width,"vertical drag preserves the fractional baseline width");T.eq(U.windowHeight,height+80)
handle:Fire("OnEnter");Release();T.eq(handle.state,"hover","release under the mouse restores the hover image")
width,height=U.windowWidth,U.windowHeight
Begin();Move(-80,-40);T.eq(U.windowWidth,width-80);T.eq(U.windowHeight,height-40);Release()
Begin();Move(-10000,-10000);T.eq(U.windowWidth,1200);T.eq(U.windowHeight,760,"both dimensions stop at the minimum")
pressed=false;handle:Fire("OnUpdate",.016)
T.eq(U.resizing,nil,"release outside the button is observed");T.eq(handle:GetScript("OnUpdate"),nil)
T.eq(U.frame:GetScale(),1,"resizing changes geometry without changing the global scale")
T.eq(A.db.uiScale,100);T.eq(A.db.fontScale,100)

-- A taller list must expose every newly visible row and reuse them next time.
local find=U.pages.find
local activity=G.Catalog:GetActivity(2)
local members={{name="Guest-Away",nameKey="Guest-Away",class="WARRIOR",assignedRole="TANK",dungeonScore=2450,itemLevel=270}}
for id=1,40 do
 G.records[id]={id=id,activity=activity,activityID=2,categoryID=2,name="Resize group "..id,
  leaderName="Guest-Away",leaderKey="Guest-Away",activityName=activity.name,numMembers=1,maxNumPlayers=5,
  age=id,leaderRating=2450,details={members=members,counts={TANK=1,HEALER=0,DAMAGER=0}}}
end
find:CommitChoice();find:DoSearch()
local oldPool=#find.results.rows
Begin();Move(200,200);Release()
T.eq(U.windowWidth,1400);T.eq(U.windowHeight,960)
T.ok(#find.results.rows>oldPool,"growing the viewport adds decorated result rows")
T.ok(find.results.capacity>=math.ceil(find.results:GetHeight()/find.results.rowHeight))
local lastVisible=find.results.rows[math.ceil(find.results:GetHeight()/find.results.rowHeight)]
T.ok(lastVisible.key and lastVisible.leader and lastVisible.tooltipArea,"the new bottom row has data and real interaction regions")
find.results:SetPixelOffset(100000,false)
local foundLast=false
for _,row in ipairs(find.results.rows) do if row.key==40 and row._hitVisible then foundLast=true end end
T.ok(foundLast,"the final result remains reachable after resizing")
local nodeCount=#S.nodes
Begin();Move(-200,-200);Release();Begin();Move(200,200);Release()
T.eq(#S.nodes,nodeCount,"repeating a resize reuses all native objects")
local savedWidth,savedHeight=U.windowWidth,U.windowHeight
U:Hide(true);A:Open("find")
T.eq(U.windowWidth,savedWidth);T.eq(U.windowHeight,savedHeight)
local modal=U:OpenModal("resize-test","Modal",480,260)
Begin();T.eq(U.resizing,nil,"a modal prevents resizing its window");pressed=false;modal:Close()
Begin();Move(-40,-40);U:Hide(true);pressed=false
T.eq(U.resizing,nil);T.eq(handle:GetScript("OnUpdate"),nil,"closing removes the only drag sampler")
local saved=A.charPrefs.windowSize
IsMouseButtonDown=previousMouse

-- Reload restores the character's dimensions, and other pages use the same bounds.
local restored=fixture("zhCN",{windowSize={width=saved.width,height=saved.height}})
A,U,G,S=restored.A,restored.U,restored.G,restored.S
A:SetSetting("reduceMotion",true);A:Open("create")
T.eq(U.windowWidth,saved.width);T.eq(U.windowHeight,saved.height)
local create=U.pages.create
LFGListFrame.EntryCreation.Name:UserType("Keep this title")
LFGListFrame.EntryCreation.Description.EditBox:UserType("Keep this description")
create.ilvl.box:UserType("250")
U:SetWindowSize(1200,760)
T.eq(LFGListFrame.EntryCreation.Name:GetText(),"Keep this title")
T.eq(LFGListFrame.EntryCreation.Description.EditBox:GetText(),"Keep this description")
T.eq(create.ilvl.box:GetText(),"250")
T.eq(create.surface:GetWidth()+create.rail:GetWidth()+16,U.content:GetWidth())
T.eq(create.manage:GetHeight(),U.content:GetHeight()-48)
local shortDescription=create.descriptionShell:GetHeight()
local _,shortMinimum=U:GetWindowMinimum()
U:SetWindowSize(1600,960)
T.eq(create.formFrame:GetWidth(),create.surface:GetWidth()-48,"the creation form uses the available panel width")
T.eq(create.titleShell:GetWidth(),create.formFrame:GetWidth())
T.eq(create.descriptionShell:GetWidth(),create.formFrame:GetWidth())
T.eq(create.descriptionShell:GetHeight(),shortDescription+200,"a taller window gives its extra space to the description")
-- Simulate the engine resolving the native container's two shell anchors.
local description=LFGListFrame.EntryCreation.Description
description:SetSize(create.descriptionShell:GetWidth()-20,create.descriptionShell:GetHeight()-14)
T.eq(description.EditBox:GetWidth(),create.descriptionShell:GetWidth()-36,"the native text wraps across the resized description field")
local _,tallMinimum=U:GetWindowMinimum()
T.eq(tallMinimum,shortMinimum,"expanded description space does not raise the minimum window height")
T.eq(LFGListFrame.EntryCreation.Description.EditBox:GetText(),"Keep this description")

-- Native fields can notify while their geometry is changing. Such callbacks
-- must never restore the saved dimensions between successive cursor samples.
do
 local grip=U.resizeHandle
 U.preferredWindowWidth,U.preferredWindowHeight=1600,960
 U.frame.GetLeft=function(frame) return 100/frame:GetEffectiveScale() end
 U.frame.GetTop=function(frame) return 1100/frame:GetEffectiveScale() end
 local mouse=IsMouseButtonDown
 IsMouseButtonDown=function() return true end
 S.cursorX,S.cursorY=1800,200;grip:Fire("OnMouseDown","LeftButton")
 local layout,layouts=create.LayoutSize,0
 create.LayoutSize=function(self,...) layouts=layouts+1;return layout(self,...) end
 S.cursorX,S.cursorY=1800-180*U.resizing.scale,200+80*U.resizing.scale
 grip:Fire("OnUpdate",.016)
 T.eq(U.windowWidth,1420);T.eq(U.windowHeight,880)
 for _,input in ipairs({LFGListFrame.EntryCreation.Name,LFGListFrame.EntryCreation.Description.EditBox,create.ilvl.box,create.score.box}) do
  input:Fire("OnTextChanged",false)
  T.eq(U.windowWidth,1420,"input callbacks retain the cursor's width")
  T.eq(U.windowHeight,880,"input callbacks retain the cursor's height")
 end
 G.manageListing=false;create:ValidateForm()
 T.ok(create.formNotice:IsShown())
 LFGListFrame.EntryCreation.Name:Fire("OnTextChanged",false)
 T.eq(U.windowWidth,1420);T.eq(U.windowHeight,880,"visible validation feedback also retains the drag size")
 G.manageListing=true;create:ValidateForm()
 T.eq(layouts,1,"one cursor sample performs one page layout even with native callbacks")
 create.LayoutSize=layout
 grip:Fire("OnMouseUp","LeftButton");IsMouseButtonDown=mouse
 T.eq(A.charPrefs.windowSize.width,1420);T.eq(A.charPrefs.windowSize.height,880)
 T.eq(LFGListFrame.EntryCreation.Name:GetText(),"Keep this title")
 T.eq(LFGListFrame.EntryCreation.Description.EditBox:GetText(),"Keep this description")
end
create:SetFormError("A form error with enough context to explain the problem.")
local minimumWidth,minimumHeight=U:GetWindowMinimum()
U:SetWindowSize(1,1)
T.eq(U.windowWidth,minimumWidth);T.eq(U.windowHeight,minimumHeight)
T.ok(create.formFrame:GetHeight()-40>=create.requirementsTop+create.formNotice:GetHeight()+12+create.requirementsBottom+24,"the minimum keeps the publish button below the form and notice")

A:Open("notes",{add={name="Draft",realm="Away"}})
local notes=U.pages.notes
notes.eReason.box:UserType("Preserve this unsaved note")
U:SetWindowSize(1200,760)
T.eq(notes.eReason.box:GetText(),"Preserve this unsaved note")
T.eq(notes.main:GetWidth()+224,U.content:GetWidth());T.eq(notes.historyList:GetWidth(),notes.main:GetWidth()-48)
local footerTop=notes.editor:GetHeight()-U.Theme.notesESaveBottomrightY-notes.eSave:GetHeight()
local point={notes.eReason:GetPoint()}
T.ok(-point[#point]+notes.eReason:GetHeight()+12<=footerTop,"the short editor keeps its reason input above the actions")
notes:SetEditorStatus("Draft validation message","error")
point={notes.eStatus:GetPoint()}
T.ok(-point[#point]+notes.eStatus:GetStringHeight()+12<=footerTop,"visible feedback leaves space for the bottom actions")
notes:SetEditorStatus("")
T.ok(notes.eReason:GetHeight()>=32)
U:SetWindowSize(1500,960)
T.eq(notes.eReason.box:GetText(),"Preserve this unsaved note")
T.eq(notes.main:GetWidth()+224,U.content:GetWidth())

A:Open("settings",{section="interface"});local settings=U.pages.settings
U:SetWindowSize(1200,760)
T.eq(settings.main:GetHeight(),U.content:GetHeight())
T.eq(settings.panels.interface:GetWidth(),settings.main:GetWidth()-60)
local range=settings.controls.uiScale
T.eq(range.frame:GetWidth(),settings.panels.interface:GetWidth())
A:SetSetting("fontScale",130)
minimumWidth,minimumHeight=U:GetWindowMinimum()
T.eq(minimumWidth,1266);T.eq(minimumHeight,832)
U:SetWindowSize(1,1);T.eq(U.windowWidth,minimumWidth);T.eq(U.windowHeight,minimumHeight)
UIParent:SetSize(1100,800);U.frame:Fire("OnEvent","DISPLAY_SIZE_CHANGED")
T.ok(U.frame:GetWidth()*U.frame:GetScale()<=1060.001 and U.frame:GetHeight()*U.frame:GetScale()<=760.001,"a smaller screen fits the minimum layout by scaling it")
U:Hide(true)
