local ADDON, ns = ...

BINDING_HEADER_LOCKMENU = "LockMenu"
_G["BINDING_NAME_CLICK LockMenuKey:LeftButton"] = "Show the warlock menu (toggle or hold, see /lockmenu options)"

-- Only warlocks get a menu.
if select(2, UnitClass("player")) ~= "WARLOCK" then
	function LockMenu_Toggle() print("LockMenu: this addon is for warlocks") end
	SLASH_LOCKMENU1 = "/lockmenu"
	SlashCmdList["LOCKMENU"] = LockMenu_Toggle
	return
end

local Data, DB = ns.Data, ns.DB
local GAP, PAD, LABEL_W, HEADER_H = 4, 10, 66, 22

local menu, dirty = nil, true
local buttons, labels = {}, {}
local shardText
local holdToken = 0
local keyBtn, armRelease, clearRelease -- the key's secure button and the two functions that load a spell onto it (see below)

local function secret(v)
	return issecretvalue and issecretvalue(v) or false
end

-- Spell information by ID or by name, from whichever API this client has. Returns name, icon, spell ID.
local function spellInfo(idOrName)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, idOrName)
		if ok and type(info) == "table" and info.name then return info.name, info.iconID or info.originalIconID, info.spellID end
	end
	if GetSpellInfo then
		local ok, name, _, icon, _, _, _, id = pcall(GetSpellInfo, idOrName)
		if ok and name then return name, icon, id end
	end
end

-- Every spell name in the spellbook (highest spell ID kept per name). Returns the set, the names in book order, and whether
-- the book could be read at all.
local function scanSpellbook()
	local known, order, readable = {}, {}, false
	local function add(name, id)
		if type(name) ~= "string" or secret(name) then return end
		if known[name] == nil then
			known[name] = id or true
			order[#order + 1] = name
		elseif type(id) == "number" and (type(known[name]) ~= "number" or id > known[name]) then
			known[name] = id
		end
	end
	pcall(function()
		local SB = C_SpellBook
		local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
		if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemName and bank ~= nil then
			for line = 1, SB.GetNumSpellBookSkillLines() do
				local li = SB.GetSpellBookSkillLineInfo(line)
				if type(li) == "table" and li.itemIndexOffset and li.numSpellBookItems then
					readable = true
					for i = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
						local name = SB.GetSpellBookItemName(i, bank)
						local id, future = nil, false
						if SB.GetSpellBookItemInfo then
							local item = SB.GetSpellBookItemInfo(i, bank)
							if type(item) == "table" then
								id = item.spellID
								future = (Enum and Enum.SpellBookItemType and item.itemType == Enum.SpellBookItemType.FutureSpell) or false
							end
						end
						if not future then add(name, id) end
					end
				end
			end
		elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
			for tab = 1, GetNumSpellTabs() do
				local _, _, offset, count = GetSpellTabInfo(tab)
				readable = true
				for i = offset + 1, offset + count do
					add((GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")))
				end
			end
		end
	end)
	return known, order, readable and #order > 0
end

local function itemCount(id)
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, id)
		if ok and type(n) == "number" then return n end
	end
	if GetItemCount then
		local ok, n = pcall(GetItemCount, id)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

local function itemIcon(id)
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		if ok and icon then return icon end
	end
	if GetItemIcon then
		local ok, icon = pcall(GetItemIcon, id)
		if ok and icon then return icon end
	end
	return 134400
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local ok = false
	if self.kind == "spell" and self.spellID and GameTooltip.SetSpellByID then
		ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
	elseif self.kind == "item" and self.itemID and GameTooltip.SetItemByID then
		ok = pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
	end
	if not ok then GameTooltip:SetText(self.label or "?") end
	GameTooltip:Show()
end

local function newButton(index)
	local b = CreateFrame("Button", "LockMenuButton" .. index, menu, "SecureActionButtonTemplate")
	b:RegisterForClicks("LeftButtonUp")
	b:SetAttribute("useOnKeyDown", false)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.count:SetPoint("BOTTOMRIGHT", -2, 2)
	b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cooldown:SetAllPoints()
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.25)
	b:SetScript("OnEnter", function(self)
		showTooltip(self)
		if armRelease then armRelease(self) end
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
		if clearRelease then clearRelease() end
	end)
	-- After a cast the menu closes, if that is switched on. Hiding an ordinary frame is allowed in combat too.
	b:SetScript("PostClick", function() if menu and DB.close then menu:Hide() end end)
	return b
end

local function updateButtons()
	if shardText then shardText:SetText("Shards: " .. itemCount(Data.shardItem)) end
	for _, b in ipairs(buttons) do
		if b:IsShown() then
			if b.kind == "item" then
				local n = itemCount(b.itemID)
				b.count:SetText(n > 1 and n or "")
			elseif b.kind == "spell" then
				pcall(function()
					local start, duration
					if C_Spell and C_Spell.GetSpellCooldown then
						local info = C_Spell.GetSpellCooldown(b.spellID or b.spellName)
						if type(info) == "table" then start, duration = info.startTime, info.duration end
					elseif GetSpellCooldown then
						start, duration = GetSpellCooldown(b.spellName)
					end
					if start and duration then b.cooldown:SetCooldown(start, duration) end
				end)
			end
		end
	end
end

-- The two opacity settings. Changing a frame's opacity is allowed in combat.
local function applyLook()
	if not menu then return end
	menu:SetBackdropColor(0, 0, 0, DB.bg)
	menu:SetAlpha(DB.alpha)
end

-- The spells listed in the options box, plus any in Data.lua.
local function extraNames()
	local names = {}
	for _, n in ipairs(Data.extra or {}) do names[#names + 1] = n end
	for n in (DB.extra or ""):gmatch("[^,]+") do
		n = n:match("^%s*(.-)%s*$")
		if n ~= "" then names[#names + 1] = n end
	end
	return names
end

-- Works out what to show and lays it out. Out of combat only, because it changes the secure buttons.
local function rebuild()
	if InCombatLockdown() then
		dirty = true
		return
	end
	dirty = false
	local SIZE = DB.size

	local known, order, haveBook = scanSpellbook()
	local function isKnown(name)
		if haveBook then return known[name] ~= nil end
		return spellInfo(name) ~= nil
	end
	local used = {}
	local function spellEntry(name)
		if used[name] then return nil end
		used[name] = true
		local id = type(known[name]) == "number" and known[name] or nil
		local _, icon, sid = spellInfo(id or name)
		return { kind = "spell", name = name, spellID = id or sid, icon = icon or 134400 }
	end

	local rows = {}
	for _, g in ipairs(Data.spellGroups) do
		if ns.RowOn(g.label) then
			local entries = {}
			for _, name in ipairs(g.names or {}) do
				if isKnown(name) then
					local e = spellEntry(name)
					if e then entries[#entries + 1] = e end
				end
			end
			if haveBook and g.patterns then
				for _, name in ipairs(order) do
					if not (g.exclude and g.exclude[name]) then
						for _, pattern in ipairs(g.patterns) do
							if name:find(pattern) then
								local e = spellEntry(name)
								if e then entries[#entries + 1] = e end
								break
							end
						end
					end
				end
			end
			if #entries > 0 then rows[#rows + 1] = { label = g.label, entries = entries } end
		end
	end
	if ns.RowOn("Extra") then
		local entries = {}
		for _, name in ipairs(extraNames()) do
			if isKnown(name) then
				local e = spellEntry(name)
				if e then entries[#entries + 1] = e end
			end
		end
		if #entries > 0 then rows[#rows + 1] = { label = "Extra", entries = entries } end
	end
	if ns.RowOn("Use") then
		local carried = {}
		for _, family in ipairs(Data.useItems or {}) do
			for _, id in ipairs(family.ids) do
				if itemCount(id) > 0 then
					carried[#carried + 1] = { kind = "item", name = family.label, itemID = id, icon = itemIcon(id) }
					break
				end
			end
		end
		if #carried > 0 then rows[#rows + 1] = { label = "Use", entries = carried } end
	end

	-- Buttons and labels are reused. Whatever is left over is hidden.
	local n, widest = 0, 0
	for r, row in ipairs(rows) do
		local y = HEADER_H + PAD + (r - 1) * (SIZE + GAP)
		labels[r] = labels[r] or menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		labels[r]:ClearAllPoints()
		labels[r]:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -(y + SIZE / 2 - 5))
		labels[r]:SetText(row.label)
		labels[r]:Show()
		for c, e in ipairs(row.entries) do
			n = n + 1
			local b = buttons[n] or newButton(n)
			buttons[n] = b
			b:SetSize(SIZE, SIZE)
			b.kind, b.label = e.kind, e.name
			b.spellID, b.spellName, b.itemID = e.spellID, e.kind == "spell" and e.name or nil, e.itemID
			b.icon:SetTexture(e.icon)
			b.count:SetText("")
			pcall(b.cooldown.Clear, b.cooldown)
			if e.kind == "spell" then
				b:SetAttribute("type", "spell")
				b:SetAttribute("spell", e.name)
				b:SetAttribute("item", nil)
			else
				b:SetAttribute("type", "item")
				b:SetAttribute("item", "item:" .. e.itemID)
				b:SetAttribute("spell", nil)
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD + LABEL_W + (c - 1) * (SIZE + GAP), -y)
			b:Show()
		end
		if #row.entries > widest then widest = #row.entries end
	end
	for i = n + 1, #buttons do buttons[i]:Hide() end
	for i = #rows + 1, #labels do labels[i]:Hide() end

	if #rows == 0 then
		menu:SetSize(230, HEADER_H + PAD * 2 + 16)
	else
		menu:SetSize(PAD * 2 + LABEL_W + widest * (SIZE + GAP) - GAP, HEADER_H + PAD * 2 + #rows * (SIZE + GAP) - GAP)
	end
	menu.empty:SetShown(#rows == 0)
	updateButtons()
end

local function createMenu()
	menu = CreateFrame("Frame", "LockMenuFrame", UIParent, "BackdropTemplate")
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
	menu:SetBackdropBorderColor(0.45, 0.3, 0.65, 1)
	local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", PAD, -6)
	title:SetText("LockMenu")
	shardText = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	shardText:SetPoint("TOPRIGHT", -PAD, -8)
	menu.empty = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	menu.empty:SetPoint("TOPLEFT", PAD, -(HEADER_H + PAD))
	menu.empty:SetText("Nothing to show. Check /lockmenu options")
	menu.empty:Hide()
	menu:SetScript("OnShow", updateButtons)
	menu:Hide()
	table.insert(UISpecialFrames, "LockMenuFrame")
	applyLook()
end

-- Opens the menu. The menu itself is an ordinary frame, so it can be opened and closed in combat; what it shows is only
-- rebuilt out of combat, and it is only moved out of combat (in combat it opens where it was).
local function open()
	if not InCombatLockdown() then
		if dirty then rebuild() end
		menu:ClearAllPoints()
		if DB.cursor then
			local x, y = GetCursorPosition()
			local scale = UIParent:GetEffectiveScale()
			menu:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
		else
			menu:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
		end
	end
	menu:Show()
end

function LockMenu_Toggle()
	if not menu then return end
	if menu:IsShown() then menu:Hide() else open() end
end

-- The key is a secure button that the key binding clicks when the key goes down and again when it comes up. In toggle mode
-- only the press counts. In hold mode the press opens the menu and the release closes it. If a release is ever missed (the
-- game window lost focus), the menu closes by itself after 90 seconds.
--
-- Cast on release: while the menu is open, pointing at a spell copies that spell onto this button's attributes, and the
-- release click then casts it through the game's own secure code. (An addon cannot cast by itself, and the snippets other
-- addons use for this do not work in this client.) The attributes of a secure button can only be changed out of combat, so in
-- combat the release only closes the menu, and a spell has to be clicked.
keyBtn = CreateFrame("Button", "LockMenuKey", UIParent, "SecureActionButtonTemplate")
keyBtn:RegisterForClicks("AnyDown", "AnyUp")
keyBtn:SetAttribute("useOnKeyDown", false) -- a spell loaded on it is cast when the key comes up

clearRelease = function()
	if InCombatLockdown() then return end
	keyBtn:SetAttribute("type", nil)
	keyBtn:SetAttribute("spell", nil)
	keyBtn:SetAttribute("item", nil)
end

armRelease = function(b)
	if not (DB.hold and DB.release) or InCombatLockdown() then return end
	keyBtn:SetAttribute("type", b:GetAttribute("type"))
	keyBtn:SetAttribute("spell", b:GetAttribute("spell"))
	keyBtn:SetAttribute("item", b:GetAttribute("item"))
end

keyBtn:SetScript("PreClick", function(_, _, down)
	if DB.hold then
		if down then
			holdToken = holdToken + 1
			clearRelease()
			if not menu:IsShown() then open() end
			local token = holdToken
			if C_Timer and C_Timer.After then
				C_Timer.After(90, function()
					if holdToken == token and menu:IsShown() then menu:Hide() end
				end)
			end
		end
	elseif down then
		LockMenu_Toggle()
	end
end)

keyBtn:SetScript("PostClick", function(_, _, down)
	if DB.hold and not down then
		holdToken = holdToken + 1
		menu:Hide()
		clearRelease()
	end
end)

local function report()
	local _, order, haveBook = scanSpellbook()
	print("LockMenu: spellbook readable=" .. tostring(haveBook) .. ", spells found=" .. #order
		.. ", C_SpellBook=" .. tostring(C_SpellBook ~= nil) .. ", C_Spell=" .. tostring(C_Spell ~= nil))
	local shown = 0
	for _, b in ipairs(buttons) do
		if b:IsShown() then shown = shown + 1 end
	end
	print("LockMenu: " .. shown .. " buttons on the menu, mode " .. (DB.hold and "hold" or "toggle"))
	if haveBook then print("LockMenu: " .. table.concat(order, ", ")) end
end

createMenu()

ns.OnChange(function(key)
	if key == "bg" or key == "alpha" then
		applyLook()
	elseif key == "hold" or key == "close" or key == "cursor" or key == "release" then
		return
	else
		dirty = true
		if not InCombatLockdown() then rebuild() end
		applyLook()
	end
end)
ns.Rebuild = function() dirty = true rebuild() end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN" }) do
	pcall(events.RegisterEvent, events, e)
end
local pendingBags = false
events:SetScript("OnEvent", function(_, event)
	if event == "SPELL_UPDATE_COOLDOWN" then
		if menu:IsShown() then updateButtons() end
	elseif event == "BAG_UPDATE_DELAYED" then
		dirty = true
		if not pendingBags and C_Timer and C_Timer.After then
			pendingBags = true
			C_Timer.After(0.4, function()
				pendingBags = false
				if menu:IsShown() then rebuild() end
			end)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if dirty then rebuild() end
	else
		dirty = true
		if not InCombatLockdown() then rebuild() end
	end
end)

SLASH_LOCKMENU1 = "/lockmenu"
SLASH_LOCKMENU2 = "/lkm"
SlashCmdList["LOCKMENU"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "scan" or msg == "report" then
		rebuild()
		report()
	elseif msg == "rebuild" then
		rebuild()
		print("LockMenu: rebuilt")
	elseif msg == "options" or msg == "config" or msg == "settings" or msg == "opt" then
		if ns.OpenOptions then ns.OpenOptions() else print("LockMenu: the options window did not load") end
	else
		LockMenu_Toggle()
	end
end
