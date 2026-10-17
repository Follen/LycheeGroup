local base = dofile("tests/stubs.lua")
base.Install({locale = "zhCN", realm = "Home"})
local stub = dofile("tests/ui_stubs.lua")
stub.Install()
_G.LycheeUI = nil
local private = {}
for _, file in ipairs({"Core.lua", "Theme.lua"}) do
    assert(loadfile("addon/LycheeGroup/Libs/LycheeUI/" .. file))("LycheeGroup", private)
end
_G.LycheeGroup, _G.LycheeGroupDB = nil, nil
for _, file in ipairs({"Locale.lua", "Core.lua", "Minimap.lua"}) do
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
M:Initialize()
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
T.eq(openedPage, "settings"); T.eq(openedContext.section, "interface")

local function Position()
    return select(4, button:GetPoint())
end
stub.cursorX, stub.cursorY = 300, 450 -- local offset (100, 100), effective scale 1.5
button:Fire("OnMouseDown", "LeftButton")
button:Fire("OnDragStart")
T.ok(button:GetScript("OnUpdate"))
T.near(A.db.minimapAngle, 45, .001, "dragging uses the minimap's effective scale")
local x, y = Position()
T.near(x, 76 / math.sqrt(2), .001); T.near(y, x, .001)
shape = "SQUARE"
button:Fire("OnUpdate", .016)
x, y = Position()
T.near(x, 76, .001); T.near(y, 76, .001, "square minimaps use their actual outer edge")
button:Fire("OnDragStop")
T.eq(button:GetScript("OnUpdate"), nil)
openedPage = nil
button:Fire("OnClick", "LeftButton")
T.eq(openedPage, nil, "releasing a drag cannot open the main window")
button:Fire("OnMouseDown", "LeftButton")
button:Fire("OnMouseUp", "LeftButton")
button:Fire("OnClick", "LeftButton")
T.eq(openedPage, "find", "a fresh click works after a drag")

shape = "CORNER-TOPLEFT"
A.db.minimapAngle = 135
M:UpdateSettings()
x, y = Position()
T.near(x, -76 / math.sqrt(2), .001); T.near(y, -x, .001)
A.db.minimapAngle = 45
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
local collector=stub.New("Frame",nil,UIParent)
button:SetParent(collector);button:ClearAllPoints();button:SetPoint("CENTER",collector,"CENTER",12,18)
M:UpdatePosition()
local _,parent,_,collectedX,collectedY=button:GetPoint()
T.eq(parent,collector);T.eq(collectedX,12);T.eq(collectedY,18,"a minimap collector owns the collected button layout")
_G.GetMinimapShape = nil
