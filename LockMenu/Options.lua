local ADDON, ns = ...

if select(2, UnitClass("player")) ~= "WARLOCK" then return end

local DB = ns.DB
local panel
local syncs = {}

local function syncAll()
	for _, fn in ipairs(syncs) do fn() end
end

local function heading(y, text)
	local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetText(text)
	local line = panel:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, 0.15)
	line:SetPoint("TOPLEFT", 16, y - 17)
	line:SetPoint("TOPRIGHT", -16, y - 17)
	line:SetHeight(1)
end

local function check(y, text, get, set)
	local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 12, y)
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	fs:SetWidth(330)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	syncs[#syncs + 1] = function() cb:SetChecked(get() and true or false) end
end

local function slider(y, text, key, minV, maxV, stepV, fmt)
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOPLEFT", 16, y)
	title:SetText(text)
	local s = CreateFrame("Slider", nil, panel)
	s:SetPoint("TOPLEFT", 16, y - 20)
	s:SetSize(220, 16)
	s:SetOrientation("HORIZONTAL")
	s:SetMinMaxValues(minV, maxV)
	local bar = s:CreateTexture(nil, "BACKGROUND")
	bar:SetColorTexture(1, 1, 1, 0.25)
	bar:SetPoint("LEFT", s, "LEFT", 0, 0)
	bar:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	bar:SetHeight(4)
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local thumb = s:GetThumbTexture()
	if thumb then thumb:SetSize(16, 24) end
	local readout = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	readout:SetPoint("LEFT", s, "RIGHT", 12, 0)
	s:SetScript("OnValueChanged", function(self, val)
		-- Only a drag by the mouse counts, not the value being set when the window opens.
		-- The mouse can drift off the thin bar while you drag, so the check is generous.
		local okOver, over = pcall(self.IsMouseOver, self, 80, -80, -80, 80)
		local dragging = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and (over or (not okOver and self:IsMouseOver()))
		if not dragging then return end
		val = math.floor(val / stepV + 0.5) * stepV
		readout:SetText(string.format(fmt, val))
		if DB[key] ~= val then ns.Set(key, val) end
	end)
	syncs[#syncs + 1] = function()
		local v = DB[key]
		if v == nil then v = minV end
		s:SetValue(v)
		readout:SetText(string.format(fmt, v))
	end
end

local function build()
	panel = CreateFrame("Frame", "LockMenuOptions", UIParent, "BackdropTemplate")
	panel:SetSize(400, 690)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("DIALOG")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
	panel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	panel:SetBackdropBorderColor(0.45, 0.3, 0.65, 1)
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("LockMenu")
	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	heading(-40, "The key")
	check(-62, "Hold the key to show the menu, and release it to hide it (otherwise the key opens and closes it)",
		function() return DB.hold end, function(v) ns.Set("hold", v) end)
	check(-98, "With hold: on release, cast the spell the mouse is on (out of combat only)",
		function() return DB.release end, function(v) ns.Set("release", v) end)
	check(-134, "Close the menu after casting a spell", function() return DB.close end, function(v) ns.Set("close", v) end)
	check(-160, "Open the menu at the mouse (otherwise near the middle of the screen)",
		function() return DB.cursor end, function(v) ns.Set("cursor", v) end)

	heading(-202, "What the menu shows")
	local y = -224
	for _, row in ipairs(ns.rows) do
		check(y, row.text, function() return ns.RowOn(row.key) end, function(v) ns.SetRowOn(row.key, v) end)
		y = y - 26
	end

	heading(y - 12, "Look")
	slider(y - 38, "Button size", "size", 24, 56, 2, "%.0f")
	slider(y - 82, "Background opacity", "bg", 0, 1, 0.05, "%.2f")
	slider(y - 126, "Menu opacity (icons too)", "alpha", 0.2, 1, 0.05, "%.2f")

	local ey = y - 176
	heading(ey, "Extra spells")
	local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", 16, ey - 24)
	note:SetText("Exact spell names, separated by commas. They appear in an Extra row.")
	local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	box:SetSize(340, 22)
	box:SetPoint("TOPLEFT", 26, ey - 48)
	box:SetAutoFocus(false)
	box:SetMaxLetters(160)
	local function commit(self)
		local v = (self:GetText() or ""):gsub("[;=\r\n]", "")
		v = v:match("^%s*(.-)%s*$")
		if v ~= (DB.extra or "") then ns.Set("extra", v) end
	end
	box:SetScript("OnEnterPressed", function(self) commit(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusLost", commit)
	box:SetScript("OnEscapePressed", function(self) self:SetText(DB.extra or "") self:ClearFocus() end)
	syncs[#syncs + 1] = function() box:SetText(DB.extra or "") end

	local saved = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	saved:SetPoint("BOTTOM", 0, 10)
	saved:SetText("Changes are saved as you make them")

	panel:SetScript("OnShow", syncAll)
	panel:Hide()
	table.insert(UISpecialFrames, "LockMenuOptions")
end

function ns.OpenOptions()
	if not panel then build() end
	if panel:IsShown() then
		panel:Hide()
	else
		panel:Show()
	end
end

-- After the saved settings are read back at login, the window (if it was built) shows them.
ns.OnChange(function(key)
	if key == "all" and panel then syncAll() end
end)
