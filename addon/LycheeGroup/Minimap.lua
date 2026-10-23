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
    local angle = math.rad(self.dragAngle or A:GetSetting("minimapAngle"))
    local x, y = math.cos(angle), math.sin(angle)
    local quadrant = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local shape = shapes[GetMinimapShape and GetMinimapShape() or "ROUND"] or shapes.ROUND
    if not shape[quadrant] then
        local extent = math.max(math.abs(x), math.abs(y))
        x, y = x / extent, y / extent
    end
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + self.theme.minimapOrbitInset), y * (Minimap:GetHeight() / 2 + self.theme.minimapOrbitInset))
end

function M:Drag()
    local x, y = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    self.dragAngle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX)) % 360
    self:UpdatePosition()
end

function M:StopDragging()
    self.dragging = nil
    self.button:SetScript("OnUpdate", nil)
    if self.dragAngle then
        local angle=self.dragAngle;self.dragAngle=nil
        A:SetSetting("minimapAngle",angle)
    end
end

function M:ApplyElements()
 if self.context then self.context:ApplyElements("minimap") end
end

function M:ApplyStartupTheme()
    if not self.button then return end
    local elements=A.Appearance:GetElements("main")
    local configured=elements["minimap.entry"] or elements["minimap.background"] or elements["minimap.icon"]
    if configured and not self.context then
        self.context=LycheeUI:CreateContext({themeDefaults=A.StyleDefaults.main,theme=A.Appearance:GetTheme("main"),elementDefaults=A.ElementDefaults.main,elements=elements,utilities=A.Appearance:GetUtilities("main")})
        local C=self.context.C
        C.Element(self.button,"minimap.entry",{scope="minimap",slots={root=self.button,background=self.background,icon=self.button.icon},stateOwner=self.button})
        C.Element(self.background,"minimap.background",{scope="minimap",stateOwner=self.button})
        C.Element(self.button.icon,"minimap.icon",{scope="minimap",stateOwner=self.button})
    end
    local theme=self.context and self.context.Theme or LycheeUI.ResolveTheme(A.Appearance:GetTheme("main"),A.StyleDefaults.main)
    self.theme=theme
    self.button:SetSize(theme.minimapButtonSize,theme.minimapButtonSize)
    self.button:SetFrameLevel(Minimap:GetFrameLevel()+theme.minimapFrameLevelOffset)
    self.button.icon:SetSize(theme.minimapIconSize,theme.minimapIconSize)
    self.background:SetTexture(theme.media.."circle.tga")
    self.background:SetVertexColor(unpack(self.inside and theme.surfaceLowHover or theme.surfaceLow))
    self.button.icon:SetTexture(theme.productMedia.."lychee-logo.tga")
    self:UpdatePosition();self:ApplyElements()
end

function M:Initialize()
    if self.button then self:UpdateSettings(); return end
    local button = CreateFrame("Button", "LycheeGroupMinimapButton", Minimap)
    self.button = button
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    local background = button:CreateTexture(nil, "BACKGROUND")
    self.background=background
    background:SetAllPoints()
    local icon = button:CreateTexture(nil, "ARTWORK")
    button.icon = icon
    icon:SetPoint("CENTER")
    button:SetScript("OnEnter", function()
        M.inside=true
        background:SetVertexColor(unpack(M.theme.surfaceLowHover));M:ApplyElements()
        if M.dragging then return end
        local zh = A:GetLocale() == "zhCN"
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine(A.L.brand)
        GameTooltip:AddLine(zh and "左键：打开／关闭荔枝组队" or "Left-click: toggle Lychee LFG", unpack(M.theme.minimapTooltipTextColor,1,3))
        GameTooltip:AddLine(zh and "右键：打开设置" or "Right-click: open settings", unpack(M.theme.minimapTooltipTextColor,1,3))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        M.inside=nil
        background:SetVertexColor(unpack(M.theme.surfaceLow));M:ApplyElements()
        GameTooltip:Hide()
    end)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        M.suppressClick = nil
        if mouseButton == "LeftButton" then icon:SetAlpha(M.theme.minimapPressedAlpha);M:ApplyElements() end
    end)
    button:SetScript("OnMouseUp", function() icon:SetAlpha(1);M:ApplyElements() end)
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
        M.inside=nil
        background:SetVertexColor(unpack(M.theme.surfaceLow));M:ApplyElements()
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end)
    self:ApplyStartupTheme()
    self:UpdateSettings()
end

function M:UpdateSettings()
    if not self.button then return end
    self:UpdatePosition()
    -- Collectors track the addon's intended visibility through Show/Hide hooks.
    if A:GetSetting("minimap") == true then self.button:Show() else self.button:Hide() end
end
