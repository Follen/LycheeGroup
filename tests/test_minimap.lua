local base = dofile("tests/stubs.lua")
base.Install({locale = "zhCN", realm = "Home"})
local stub = dofile("tests/ui_stubs.lua")
stub.Install()
_G.LycheeUI = nil
local private = {}
for _, file in ipairs({"Core.lua", "Theme.lua", "Motion.lua", "Styles.lua", "Components.lua", "Layouts.lua", "Responsive.lua", "Elements.lua", "Native.lua", "Menu.lua"}) do
    assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/" .. file))("LycheeGroup", private)
end
_G.LycheeGroup, _G.LycheeGroupDB = nil, nil
for _, file in ipairs({"Locale.lua", "Theme/Defaults.lua", "Theme/Elements.lua", "Theme/FindElements.lua", "Core.lua", "Configuration.lua", "Appearance.lua", "Theme/Import.lua", "Minimap.lua"}) do
    dofile("addon/LycheeGroup/" .. file)
end
local A = LycheeGroup
A:LoadDB()
T.eq(A.db.minimap, true, "the independent minimap entry is enabled by default")
Minimap = stub.New("Frame", nil, UIParent)
Minimap:SetSize(140, 140)
Minimap:SetScale(.75)
UIParent:SetScale(2)
Minimap.GetCenter = function() return 100, 200 end
local shape = "ROUND"
_G.GetMinimapShape = function() return shape end
local originalEnsure = A.Ensure
A.Ensure = function() error("a minimap entry must not preload packages") end
local M = A.Minimap
local startupTheme=A.Appearance:GetResolvedTheme("main")
local startupSnapshot=A.Configuration:CopyValue(startupTheme)
local resolveTheme,extraResolutions=LycheeUI.ResolveTheme,0
LycheeUI.ResolveTheme=function(...)
    extraResolutions=extraResolutions+1
    return resolveTheme(...)
end
M:Initialize()
LycheeUI.ResolveTheme=resolveTheme
T.eq(extraResolutions,0,"the default minimap reuses the already resolved startup theme")
T.eq(M.theme,startupTheme,"the default entry retains the immutable startup source")
T.eq(A.Group, nil); T.eq(A.Notes, nil); T.eq(A.UI, nil)
T.eq(M.button:IsShown(), true)
T.eq(M.button:GetScript("OnUpdate"), nil, "the idle entry has no update driver")
local originalButton = M.button
M:Initialize()
T.eq(M.button, originalButton, "initialization reuses the same entry")
A.Ensure = originalEnsure

local openedPage, openedContext
A.Open = function(_, page, context) openedPage, openedContext = page, context end
local button = M.button
button:Fire("OnClick", "LeftButton")
T.eq(openedPage, "find")
A.UI = stub.New("Frame")
button:Fire("OnClick", "LeftButton")
T.eq(A.UI:IsShown(), false, "a second left click closes the main window")
button:Fire("OnClick", "RightButton")
T.eq(openedPage, "settings"); T.eq(openedContext.section, "general")
local toggle, toggles = A.ToggleWindow, 0
A.ToggleWindow = function() toggles = toggles + 1 end
button:Fire("OnClick", "LeftButton"); T.eq(toggles, 1, "minimap delegates the transition decision to the common toggle")
A.ToggleWindow = toggle

local function Position()
    return select(4, button:GetPoint())
end
stub.cursorX, stub.cursorY = 300, 450 -- local offset (100, 100), effective scale 1.5
button:Fire("OnMouseDown", "LeftButton")
button:Fire("OnDragStart")
T.ok(button:GetScript("OnUpdate"))
T.near(M.dragAngle, 45, .001, "dragging uses the minimap's effective scale")
T.eq(A.db.minimapAngle,225,"drag samples keep the saved preference unchanged")
local x, y = Position()
T.near(x, 76 / math.sqrt(2), .001); T.near(y, x, .001)
shape = "SQUARE"
button:Fire("OnUpdate", .016)
x, y = Position()
T.near(x, 76, .001); T.near(y, 76, .001, "square minimaps use their actual outer edge")
button:Fire("OnDragStop")
T.eq(button:GetScript("OnUpdate"), nil)
T.near(A.db.minimapAngle,45,.001,"releasing the drag persists its final angle once")
openedPage = nil
button:Fire("OnClick", "LeftButton")
T.eq(openedPage, nil, "releasing a drag cannot open the main window")
button:Fire("OnMouseDown", "LeftButton")
button:Fire("OnMouseUp", "LeftButton")
button:Fire("OnClick", "LeftButton")
T.eq(openedPage, "find", "a fresh click works after a drag")

shape = "CORNER-TOPLEFT"
A:SetSetting("minimapAngle",135)
M:UpdateSettings()
x, y = Position()
T.near(x, -76 / math.sqrt(2), .001); T.near(y, -x, .001)
A:SetSetting("minimapAngle",45)
M:UpdateSettings()
x, y = Position()
T.near(x, 76, .001); T.near(y, 76, .001, "mixed shapes keep only their declared round corners")

button:Fire("OnEnter")
T.eq(GameTooltip:IsShown(), true)
button:Fire("OnDragStart")
A:SetSetting("minimap", false)
T.eq(button:IsShown(), false, "the setting hides the separate entry immediately")
T.eq(GameTooltip:IsShown(), false)
T.eq(button:GetScript("OnUpdate"), nil, "hiding during a drag detaches its driver")
T.eq(M.dragging, nil)
local savedAngle = A.db.minimapAngle
A:SetSetting("minimap", true)
T.eq(button:IsShown(), true)
T.eq(A.db.minimapAngle, savedAngle, "showing again preserves the saved position")
T.eq(button:GetScript("OnUpdate"), nil)
do
 -- Native SetShown changes visibility without dispatching Lua Show/Hide hooks.
 -- Collectors use those public method hooks to track an addon's wanted state.
 local setShown,show,hide=button.SetShown,button.Show,button.Hide
 local wanted
 button.SetShown=function(self,value) if value then show(self) else hide(self) end end
 button.Show=function(self) wanted=true;return show(self) end
 button.Hide=function(self) wanted=false;return hide(self) end
 A:SetSetting("minimap",false)
 T.eq(wanted,false,"disabling the minimap entry notifies a collector's Hide hook")
 A:SetSetting("minimap",true)
 T.eq(wanted,true,"enabling the minimap entry notifies a collector's Show hook")
 button.SetShown,button.Show,button.Hide=setShown,show,hide
end
local collector=stub.New("Frame",nil,UIParent)
button:SetParent(collector);button:ClearAllPoints();button:SetPoint("CENTER",collector,"CENTER",12,18)
M:UpdatePosition()
local _,parent,_,collectedX,collectedY=button:GetPoint()
T.eq(parent,collector);T.eq(collectedX,12);T.eq(collectedY,18,"a minimap collector owns the collected button layout")
_G.GetMinimapShape = nil
T.same(startupTheme,startupSnapshot,"minimap construction and interactions do not change the shared startup theme")

-- A fixed startup minimap declaration is applied at its creation boundary.
T.eq(M.context,nil,"the default minimap entry retains no full UI Context")
T.eq(A.API.Appearance.SetElements,nil,"live minimap appearance mutation is not exposed")
local themed=dofile("tests/ui_fixture.lua")("enUS",nil,nil,{schema=1,id="fixture.minimap",revision=1,appearance={main={elements={
 ["minimap.entry"]={base={root={width=46,height=46},icon={alpha=.5}}},
}}}})
dofile("addon/LycheeGroup/Minimap.lua")
local entry=themed.A.Minimap;entry:Initialize()
T.ok(entry.context,"a startup minimap override creates its single fixed Context")
T.eq(entry.theme,entry.context.Theme,"configured minimap elements use their own Context theme")
T.ok(entry.theme~=themed.A.Appearance:GetResolvedTheme("main"))
T.eq(entry.button:GetWidth(),46);T.eq(entry.button.icon:GetAlpha(),.5)
entry.button:Fire("OnEnter")
T.eq(entry.button:GetWidth(),46,"hover preserves startup entry geometry")
T.eq(entry.button.icon:GetAlpha(),.5,"hover preserves the startup icon override")
local pending={schema=1,id="fixture.minimap",revision=2,appearance={main={elements={
 ["minimap.entry"]={base={root={width=52,height=52},icon={alpha=.7}}},
}}}}
T.ok(themed.A.API.Theme:Import(pending,{activate=true}))
entry:ApplyStartupTheme()
T.eq(entry.button:GetWidth(),46,"a pending import does not change the current minimap Context")
T.eq(entry.button.icon:GetAlpha(),.5)
local reloaded=dofile("tests/ui_fixture.lua")("enUS",nil,nil,pending)
dofile("addon/LycheeGroup/Minimap.lua")
reloaded.A.Minimap:Initialize()
T.eq(reloaded.A.Minimap.button:GetWidth(),52,"the next session applies the selected minimap declaration")
T.eq(reloaded.A.Minimap.button.icon:GetAlpha(),.7)
