-- Independent entry: creating this button never loads a business or UI package.
local A = _G.LycheeGroup
local M = {}
A.Minimap = M

-- Quadrants: bottom-right, bottom-left, top-right, top-left. True is round.
local shapes = {
    ROUND = {true, true, true, true}, SQUARE = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

function M:UpdatePosition()
    if self.button:GetParent() ~= Minimap then return end
    local angle = math.rad(A.db.minimapAngle)
    local x, y = math.cos(angle), math.sin(angle)
    local quadrant = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local shape = shapes[GetMinimapShape and GetMinimapShape() or "ROUND"] or shapes.ROUND
    if not shape[quadrant] then
        local extent = math.max(math.abs(x), math.abs(y))
        x, y = x / extent, y / extent
    end
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + 6), y * (Minimap:GetHeight() / 2 + 6))
end

function M:Drag()
    local x, y = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    A.db.minimapAngle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX)) % 360
    self:UpdatePosition()
end

function M:StopDragging()
    self.dragging = nil
    self.button:SetScript("OnUpdate", nil)
end

function M:Initialize()
    if self.button then self:UpdateSettings(); return end
    local theme = LycheeUI.Theme
    local button = CreateFrame("Button", "LycheeGroupMinimapButton", Minimap)
    self.button = button
    button:SetSize(32, 32)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(theme.media .. "circle.tga")
    background:SetVertexColor(unpack(theme.surfaceLow))
    local icon = button:CreateTexture(nil, "ARTWORK")
    button.icon = icon
    icon:SetPoint("CENTER")
    icon:SetSize(24, 24)
    icon:SetTexture(theme.media .. "lychee-logo.tga")
    button:SetScript("OnEnter", function()
        background:SetVertexColor(unpack(theme.surfaceLowHover))
        if M.dragging then return end
        local zh = A:GetLocale() == "zhCN"
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine(A.L.brand)
        GameTooltip:AddLine(zh and "左键：打开／关闭荔枝组队" or "Left-click: toggle Lychee LFG", 1, 1, 1)
        GameTooltip:AddLine(zh and "右键：打开设置" or "Right-click: open settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        background:SetVertexColor(unpack(theme.surfaceLow))
        GameTooltip:Hide()
    end)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        M.suppressClick = nil
        if mouseButton == "LeftButton" then icon:SetAlpha(.75) end
    end)
    button:SetScript("OnMouseUp", function() icon:SetAlpha(1) end)
    button:SetScript("OnClick", function(_, mouseButton)
        if M.suppressClick then return end
        if mouseButton == "RightButton" then
            A:Open("settings", {section = "general"})
        elseif mouseButton == "LeftButton" then
            A:ToggleWindow()
        end
    end)
    button:SetScript("OnDragStart", function()
        M.dragging, M.suppressClick = true, true
        GameTooltip:Hide()
        button:SetScript("OnUpdate", function() M:Drag() end)
        M:Drag()
    end)
    button:SetScript("OnDragStop", function()
        if M.dragging then M:Drag() end
        M:StopDragging()
        icon:SetAlpha(1)
    end)
    button:SetScript("OnHide", function()
        M:StopDragging()
        icon:SetAlpha(1)
        background:SetVertexColor(unpack(theme.surfaceLow))
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end)
    self:UpdateSettings()
end

function M:UpdateSettings()
    if not self.button then return end
    self:UpdatePosition()
    self.button:SetShown(A.db.minimap == true)
end
