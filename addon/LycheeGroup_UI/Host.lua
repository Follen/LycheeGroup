-- 统一外壳:主窗、品牌、导航、下拉菜单、页面路由与退场失效。
-- 首次 Show 才建窗;页面 Frame 首次进入创建并复用;退场保留当前画面,落幕后释放页面。
local A = _G.LycheeGroup
local UI = A.UI
local T, L = UI.Theme, UI.L
local M, C = UI.Motion, UI.C

local PAGE_ORDER = {find=1,create=2,notes=3,settings=4}

function UI:Initialize()
	-- 按需加载合同:此处不建窗口、不注册事件。
end

function UI:GetGroup() return self.preview and self.preview.provider or A.Group end
function UI:GetGroupSetting(key)
 if self.preview then return self.preview.provider.settings[key] end
 return A:GetSetting(key)
end
function UI:SetGroupSetting(key,value)
 if self.preview then self.preview.provider.settings[key]=value else A:SetSetting(key,value) end
end

function UI:PrepareNotes()
 if self.preview or not A:GetSetting("notesEnabled") or not A.db.notesHasRecords or A.Notes then return end
 local notes,err=A:Ensure("Notes")
 if not notes then A:NoteMessage(A.L.loadFailed:format(tostring(err))) end
end

function UI:GetNote(key)
 if self.preview or not A:GetSetting("notesEnabled") or not key or not A.Notes then return nil end
 return A.Notes:Find(key)
end
function UI:HasNote(key)
 return self:GetNote(key)~=nil
end

function UI:OnNotesReady()
 if self.preview or self.hiding or not self:IsShown() then return end
 local page=self.page and self.pages[self.page]
 if page and page.WatchNotes and page.frame:IsVisible() then
  if page:WatchNotes() then page:OnNotesChanged() end
 end
end

function UI:OnSettingChanged(key)
	if key=="showImportantFilters" then
		if self.pages.find.frame then self.pages.find:RefreshFilterPlacement() end
		return
	end
	if key=="memberIconShape" or key=="memberClassBorder" or key=="memberLeaderMark" or key=="memberIconScale" then
		if self.pages.find.frame then self.pages.find:RefreshMemberStyle() end
		return
	end
	if key == "language" then
		if self.pages.settings.frame then self.pages.settings:Sync() end
		return
	end
	if key == "uiScale" then
		if self.frame then self:FitToScreen() end
		return
	end
	if key ~= "notesEnabled" then return end
	UI.Tooltip:Hide()
	self:OnNotesReady()
end

function UI:LayoutHeader()
 local x,changed=0,false
 for _,key in ipairs({"find","create","notes"}) do
  local button=self.navItems[key]
  local width=button.label:GetStringWidth()+38
  if button:GetWidth()~=width then button:SetWidth(width);changed=true end
  if button.navX~=x then
   button:ClearAllPoints();button:SetPoint("TOPLEFT",button:GetParent(),"TOPLEFT",x,0)
   button.navX=x;changed=true
  end
  x=x+button:GetWidth()+T.navGap
 end
 local nav=self.navItems.find:GetParent()
 if nav:GetWidth()~=x-T.navGap then nav:SetWidth(x-T.navGap) end
 local settings=self.settingsButton
 local width=settings.label:GetStringWidth()+52
 if settings:GetWidth()~=width then settings:SetWidth(width);changed=true end
 if changed then self._nav=nil;self:UpdateNav() end
end

local function FinishHeaderLayout(frame)
 frame:SetScript("OnUpdate",nil)
 UI:LayoutHeader()
end

function UI:RefreshHeaderLayout()
 self:LayoutHeader()
 -- Font metrics may settle after hidden construction or a typeface change.
 if self.frame:IsShown() then self.frame:SetScript("OnUpdate",FinishHeaderLayout) end
end

function UI:ApplyFont(path,scale)
 self:StopWindowResize()
 self:StopTableDrags()
 self.context:SetFont(path,scale)
 if not self.frame then return end
 self:CloseMenu();self.Tooltip:Hide()
 self:RefreshHeaderLayout()
 self.pages.find:LayoutFont()
 local create=self.pages.create
 if create.frame then create:LayoutFont() end
 local notes=self.pages.notes
 if notes.frame then notes:LayoutFont() end
 local settings=self.pages.settings
 if settings.frame then settings:LayoutRows();settings:Sync() end
 if self.Application.applicationModal and self.Application.applicationModal.frame:IsShown() then self.Application:LayoutApplication() end
 self:FitToScreen()
end

-- Theme changes reuse all built pages and preserve their business/input state.
function UI:OnAppearanceChanged()
 if not self.frame then return end
 self:StopWindowResize()
 self:LoadWindowSize()
 self:FitToScreen()
 local logo=self.logo:GetParent()
 logo:SetSize(T.logoSize,T.logoSize);self.logo:SetSize(T.logoSize,T.logoSize)
 logo:SetPoint("TOPLEFT",self.frame,"TOPLEFT",T.pageInset+8,-(T.headerHeight-T.logoSize)/2)
 self.closeButton:SetPoint("TOPRIGHT",self.frame,"TOPRIGHT",-T.pageInset,-(T.headerHeight-self.closeButton:GetHeight())/2)
 local nav=self.navItems.find:GetParent()
 nav:SetHeight(T.headerHeight);nav:SetPoint("TOPLEFT",self.frame,"TOPLEFT",T.pageInset+T.sidebarWidth+T.contentGap+T.mainInset,0)
 for _,button in pairs(self.navItems) do button:SetHeight(T.headerHeight) end
 self.underline:SetColorTexture(unpack(T.accent))
 self.content:SetPoint("TOPLEFT",self.frame,"TOPLEFT",T.pageInset,-T.headerHeight)
 self.content:SetPoint("BOTTOMRIGHT",self.frame,"BOTTOMRIGHT",-T.pageInset,T.pageInset)
 self:LayoutWindow()
 local width,height=self.content:GetWidth(),self.content:GetHeight()
 for _,name in ipairs({"find","create","notes","settings"}) do
  local page=self.pages[name]
  if page.frame then page:LayoutAppearance(width,height) end
 end
 self:RefreshHeaderLayout()
 if self.Application.applicationModal and self.Application.applicationModal.frame:IsShown() then self.Application:LayoutApplication() end
 self.Tooltip:OnAppearanceChanged()
end

function UI:FitToScreen()
	self:StopWindowResize()
	local scale = math.min(1, (UIParent:GetWidth() - 40) / T.width, (UIParent:GetHeight() - 40) / T.height) * A:GetSetting("uiScale") / 100
	local minWidth,minHeight=self:GetWindowMinimum()
	scale=math.min(scale,(UIParent:GetWidth()-40)/minWidth,(UIParent:GetHeight()-40)/minHeight)
	local changed=self.frame:GetScale()~=scale
	if changed then self.frame:SetScale(scale) end
	self:SetWindowSize(self.preferredWindowWidth,self.preferredWindowHeight)
	if not changed then return end
	self:CloseMenu()
	local tooltip = self.Tooltip
	if tooltip.interactive and tooltip.interactive:IsShown() then tooltip:Place(tooltip.interactive.canvas:GetHeight()) end
end

-- ---------------------------------------------------------------- 共用格式化

function UI:ClassColor(class)
	local colors = RAID_CLASS_COLORS
	local c = class and colors and colors[class]
	if c then return c.r, c.g, c.b end
	return unpack(T.text)
end

function UI:DateText(ts)
	if type(ts) ~= "number" or ts <= 0 then return L.unknown end
	return date("%y/%m/%d", ts)
end

function UI:AgeText(seconds)
	if type(seconds) ~= "number" or seconds <= 0 then return "" end
	local minutes = math.floor(seconds / 60)
	if minutes < 1 then return L.ageNow end
	if minutes < 60 then return L.ageMin:format(minutes) end
	local hours = math.floor(minutes / 60)
	if hours < 24 then return L.ageHour:format(hours) end
	return L.ageDay:format(math.floor(hours / 24))
end

-- Shared visual services; page-specific state stays here.
function UI:OpenMenu(anchor,items,onPick,options)
 self.Tooltip:Hide()
 return self.context:OpenMenu(anchor,items,onPick,options)
end
function UI:CloseMenuFor(anchor) return self.context:CloseMenuFor(anchor) end
function UI:CloseMenu() return self.context:CloseMenu() end
function UI:HandleEscape()
 local page=self.pages[self.page]
 if page and page.CancelBindingCapture and page:CancelBindingCapture() then return end
 if self.activeModal then self:CloseModal()
 elseif self.Tooltip.pinned then self.Tooltip:Hide()
 elseif self.context:IsMenuOpen() then self:CloseMenu()
 else
  if page and page.picker and page.picker:IsShown() then page:ClosePicker()
  elseif page and page.filtersOpen then page:SetFiltersOpen(false)
  else self:Hide() end
 end
end
function UI:CloseModal(reason)
 if self.activeModal then self.activeModal:Close(reason) end
end
function UI:OpenModal(key,title,width,height)
 self:StopTableDrags()
 self.modals=self.modals or {}
 local modal=self.modals[key]
 if self.activeModal and self.activeModal~=modal then self:CloseModal("replace") end
 if not modal then
  modal={}
  local frame=C.Modal(self.frame,width,height,title,function() modal:Close() end)
  modal.frame,modal.content,modal.close=frame,frame.content,frame.close
  function modal:SetTitle(value) UI:SetText(self.frame.title,value) end
  function modal:Close(reason)
   if not self.frame:IsShown() then return end
   self.closeReason=reason
   self.frame:Hide()
  end
  frame:HookScript("OnHide",function()
   if UI.activeModal==modal then UI.activeModal=nil end
   local reason=modal.closeReason;modal.closeReason=nil
   if modal.onClose then modal.onClose(reason) end
  end)
  self.modals[key]=modal
 end
 self:CloseMenu();UI.Tooltip:Hide()
 modal:SetTitle(title);modal.frame:SetSize(width,height)
 self.activeModal=modal;modal.frame:Show();M:Alpha(modal.frame,1,T.windowModalFadeDuration,T.windowModalFadeDelay)
 return modal
end

-- ---------------------------------------------------------------- 主窗构建

local function BuildNavButton(nav, page, x)
	local b = CreateFrame("Button", nil, nav)
	b:SetHeight(T.headerHeight)
	local label = C.Text(b, L[page],"font14")
	C.SetLineHeight(label,"line21",true)
	C.SetPoint(label,"LEFT",label:GetParent(),"LEFT","hostLabelLeftX",0)
	b:SetWidth(label:GetStringWidth() + 38)
	b:SetPoint("TOPLEFT", nav, "TOPLEFT", x, 0)
	b.navX=x
	b.label = label
	local icon=C.Glyph(b,page=="find" and "search" or page=="create" and "plus" or "book",T.hostIconWidth);C.ApplyStyle(icon,{width="hostIconWidth",height="hostIconHeight"})
	C.SetPoint(icon,"LEFT",icon:GetParent(),"LEFT","hostIconLeftX",0)
	b.icon=icon
	-- 当前页暖白、其余次要灰;悬停只变前景,不移动下划线。
	b:SetScript("OnEnter", function(self) UI:Color(self.label, T.text);self.icon:SetSelected(self.active,true) end)
	b:SetScript("OnLeave", function(self) UI:Color(self.label, self.active and T.text or T.muted);self.icon:SetSelected(self.active) end)
	b:SetScript("OnClick", function() A:Open(page) end)
	return b
end

function UI:Build()
	self:LoadWindowSize()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(T.width,T.height)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	frame:SetAlpha(0)
	frame:Hide()
	C.Shadow(frame,T.windowRadius)
	C.Panel(frame,"surface", T.windowRadius)
	self.frame = frame
	self.drag=C.Draggable(frame,{onStart=function()
		if UI.activeModal then return false end
		UI:StopWindowResize()
		UI:CloseMenu();UI.Tooltip:Hide()
		local page=UI.pages[UI.page];if page and page.ClosePicker then page:ClosePicker() end
	end})
	frame:SetClampedToScreen(false)
	self:FitToScreen()

	-- 72-unit header, with navigation aligned to the main content at x264.
	local logo = CreateFrame("Button", nil, frame)
	logo:SetSize(T.logoSize,T.logoSize)
	logo:SetPoint("TOPLEFT", frame, "TOPLEFT", T.pageInset+8, -(T.headerHeight-T.logoSize)/2)
	self.drag:AddHandle(logo)
	local texture = logo:CreateTexture(nil, "ARTWORK")
	texture:SetTexture(T.media .. "lychee-logo.tga")
	texture:SetSize(T.logoSize,T.logoSize)
	texture:SetPoint("CENTER", logo, "CENTER", 0, 0)
	self.logo = texture
	self.context:SetWindow(frame,texture,logo)
	-- 空闲时鼠标进入可重播;播放中经过不重启、不叠加。
	logo:SetScript("OnEnter", function() M:Brand() end)

	local title = C.Text(frame, UI.brandText,"font20");self.brandTitle=title
	C.SetLineHeight(title,"line28",true)
	C.SetPoint(title,"LEFT",logo,"RIGHT","hostTitleLeftX",0)

	local close = C.IconButton(frame,"close",T.hostCloseWidth,function() UI:Hide() end,{hoverColor=T.primaryContainer,pressedColor=T.primaryContainer});C.ApplyStyle(close,{width="hostCloseWidth",height="hostCloseHeight"})
	self.closeButton=close
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -T.pageInset, -(T.headerHeight-40)/2)
	local settings = C.Button(frame, L.settings, nil, function()
		A:Open(UI.page=="settings" and (UI.settingsReturnPage or A:GetDefaultPage()) or "settings")
	end)
	settings:SetSize(settings.label:GetStringWidth()+52,40)
	settings.label:ClearAllPoints();C.SetPoint(settings.label,"LEFT",settings.label:GetParent(),"LEFT","hostSettingsLabelLeftX",0)
	settings.icon=C.Glyph(settings,"settings",T.hostSettingsIconWidth);C.ApplyStyle(settings.icon,{width="hostSettingsIconWidth",height="hostSettingsIconHeight"});C.SetPoint(settings.icon,"LEFT",settings.icon:GetParent(),"LEFT","hostSettingsIconLeftX",0)
	self.settingsButton=settings
	settings:SetTextColors(T.muted,T.text,T.onSecondaryContainer)
	C.SetPoint(settings,"TOPRIGHT",close,"TOPLEFT","hostSettingsToprightX",0)

	-- 导航行:红色下划线跟随当前页,长度随文字。
	local nav = CreateFrame("Frame", nil, frame)
	nav:SetHeight(T.headerHeight)
	nav:SetPoint("TOPLEFT", frame, "TOPLEFT", T.pageInset+T.sidebarWidth+T.contentGap+T.mainInset, 0)
	local underline = nav:CreateTexture(nil, "ARTWORK")
	underline:SetColorTexture(unpack(T.accent))
	C.ApplyStyle(underline,{height="hostUnderlineHeight"})
	self.navItems = {}
	local x = 0
	for _, page in ipairs({ "find", "create", "notes" }) do
		local b = BuildNavButton(nav, page, x)
		self.navItems[page] = b
		x = x + b:GetWidth() + T.navGap
	end
	nav:SetWidth(x-T.navGap)
	self.underline = underline
	nav:HookScript("OnHide",function() M:FinishRect(underline) end)

	-- 内容区容器:页面在此创建并复用。
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", frame, "TOPLEFT", T.pageInset, -T.headerHeight)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -T.pageInset, T.pageInset)
	self.content = content
	-- One transparent shield revokes all mouse input while the visible shell exits.
	local blocker = CreateFrame("Button", nil, frame)
	blocker:SetAllPoints(frame)
	blocker:SetFrameLevel(frame:GetFrameLevel() + 100)
	blocker:EnableMouse(true)
	blocker:EnableMouseWheel(true)
	blocker:Hide()
	self.blocker = blocker
	self:BuildResizeHandle()
	self:LayoutWindow()
 -- CloseSpecialWindows asks only IsShown/Hide. Route that request through
 -- our layered close handling, preserving cleanup and the exit animation.
 _G.LycheeGroupEscapeHandler={
  IsShown=function() return frame:IsShown() end,
  Hide=function() UI:HandleEscape() end,
 }
 table.insert(UISpecialFrames,"LycheeGroupEscapeHandler")
 frame:HookScript("OnMouseDown",function() if UI.Tooltip.pinned then UI.Tooltip:Hide() end end)
	frame:HookScript("OnHide",function() UI:StopWindowResize();frame:SetScript("OnUpdate",nil) end)

	frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "DISPLAY_SIZE_CHANGED" and UI.frame:IsShown() then
			UI:FitToScreen()
		end
	end)
end

function UI:UpdateNav()
	local page = self.page or "find"
	self.settingsButton:SetActive(page=="settings")
	local item = self.navItems[page]
	if self._nav == page then return end
	self._nav = page
	for key, btn in pairs(self.navItems) do
		btn.active = (key == page)
		UI:Color(btn.label, btn.active and T.text or T.muted)
		btn.icon:SetSelected(btn.active)
	end
	local animate=self.underline:IsShown()
	self.underline:SetShown(item~=nil)
	if not item then M:FinishRect(self.underline);return end
	local label = item.label
	local u = self.underline
	M:Rect(u,item.navX+34,-(T.headerHeight+label:GetHeight())/2-5,label:GetStringWidth(),3,animate and T.windowNavMotionDuration or 0)
end

-- ---------------------------------------------------------------- 路由

-- UI:Show(page, context):未建窗先建;页面 180ms 过渡;开窗播放品牌动作一次。
function UI:Show(page, context)
	if not self.frame then self:Build() else self:FitToScreen() end
	local wasHidden = self.hiding or not self.frame:IsShown()
	-- 快速重开:递增令牌使旧退场回调失效,旧回调不能关新窗。
	self.exitToken = (self.exitToken or 0) + 1
	self.finishHide = nil
	self.hiding = nil
	self.blocker:Hide()
	self.frame:Show()
	if wasHidden then self:RefreshHeaderLayout() end
	self:Navigate(page or "find", context)
	if wasHidden then
		M:Presence(true)
		M:Brand()
	end
end

function UI:Navigate(page, context)
 self:StopWindowResize()
 self:StopTableDrags()
 if self.preview and page~="find" and page~="create" then self:StopPreview(false);self:Show(page,context);return end
	if A.Floating then A.Floating:Dismiss() end
	if not self.pages[page] then page = "find" end
	local previous=self.page
	if page=="settings" and (previous=="find" or previous=="create" or previous=="notes") then
		self.settingsReturnPage=previous
	end
	if self.page == page then
		local p = self.pages[page]
		if p.Enter then p:Enter(context) end
		return
	end
	self:CloseMenu()
	self:CloseModal("navigate")
	UI.Tooltip:Hide()
	if self.page then
		local old = self.pages[self.page]
		if old then
			if old.Leave then old:Leave() end
			if old.frame then M:FinishPlacement(old.frame);old.frame:Hide() end
		end
	end
	self.page = page
	local p = self.pages[page]
	if not p.frame then p:Build(self.content) end
	p.frame:Show()
	self:LayoutWindow()
	p.frame:ClearAllPoints();p.frame:SetPoint("TOPLEFT",self.content,"TOPLEFT",0,0)
	self:UpdateNav()
	p:Enter(context)
	self:FitToScreen()
	local direction=previous and PAGE_ORDER[page]<PAGE_ORDER[previous] and -1 or 1
	M:Reveal(p.frame,"TOPLEFT",self.content,"TOPLEFT",0,0,direction*(previous and T.windowPageMotionOffset or T.windowFirstPageMotionOffset),0,T.windowPageMotionDuration)
end

-- UI:Hide(immediate):立即阻止输入,整页随 Presence 退场,隐藏后才清内容和页面订阅。
function UI:Hide(immediate)
	if A.Floating then A.Floating:Dismiss() end
	local frame = self.frame
	if not frame or not frame:IsShown() or (self.hiding and not immediate) then return end
	self.drag:Stop()
	self:StopWindowResize()
	self:StopTableDrags()
	self.hiding = true
	self.blocker:Show()
	local token = (self.exitToken or 0) + 1
	self.exitToken = token
	local closingPage = self.page and self.pages[self.page]
	if closingPage and closingPage.CancelBindingCapture then closingPage:CancelBindingCapture(true) end
	self:CloseMenu()
	self:CloseModal("hide")
	UI.Tooltip:Hide()
	if self.copyDialog then self.copyDialog:Hide() end
	for _, input in ipairs(self.inputs or {}) do input:ClearFocus() end
	if self.Native then self.Native:ClearFocus() end
	self.Application:ClearFocus()
	local function done()
		if UI.exitToken ~= token then return end
		UI.finishHide = nil
		UI.frame:Hide()
		M:StopBrand()
		if closingPage then
			if closingPage.Leave then closingPage:Leave() end
			if closingPage.frame then M:FinishPlacement(closingPage.frame) end
		end
		if UI.preview then UI:EndPreview() end
		UI.hiding = nil
	end
	self.finishHide = done
	if immediate or A:GetSetting("reduceMotion") then
		M:StopAll()
		M:SetPresence(0)
		done()
	else
		M:Presence(false, done)
	end
end

function UI:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

-- UI:SetReducedMotion(bool):停止全部动画并落终态(窗 alpha/位置、滑块位置)。
function UI:SetReducedMotion(reduced)
	M:StopAll()
	self:CloseMenu()
	local frame = self.frame
	if not frame then return end
	if self.hiding then
		M:SetPresence(0)
		self.finishHide()
	elseif frame:IsShown() then
		M:SetPresence(1)
	end
end
