local ADDON, ns = ...
local Data = ns.Data

-- The rows the menu can show, in menu order. The options window lists them, and a bitmask remembers which are switched on.
ns.rows = {}
for _, g in ipairs(Data.spellGroups) do
	ns.rows[#ns.rows + 1] = { key = g.label, text = g.text or g.label, default = g.default ~= false }
end
ns.rows[#ns.rows + 1] = { key = "Use", text = "The healthstone, soulstone and sleeping bag you carry", default = true }
ns.rows[#ns.rows + 1] = { key = "Extra", text = "Extra spells (from the box below)", default = true }

local function defaultMask()
	local mask = 0
	for i, row in ipairs(ns.rows) do
		if row.default then mask = mask + 2 ^ (i - 1) end
	end
	return mask
end

local DEFAULTS = {
	hold = false,     -- false: the key toggles the menu. true: hold to show, release to hide.
	release = false,  -- with hold: on release, cast the spell the mouse is on (out of combat)
	close = true,     -- close the menu after casting
	cursor = true,    -- open at the mouse (otherwise near the middle of the screen)
	size = 36,        -- button size
	bg = 0.88,        -- background opacity
	alpha = 1,        -- opacity of the whole menu
	rows = defaultMask(),
	extra = "",       -- extra spell names, separated by commas
}
local DB = {}
for k, v in pairs(DEFAULTS) do DB[k] = v end
ns.DB, ns.DEFAULTS = DB, DEFAULTS

function ns.RowOn(key)
	for i, row in ipairs(ns.rows) do
		if row.key == key then return math.floor(DB.rows / 2 ^ (i - 1)) % 2 == 1 end
	end
	return true
end

function ns.SetRow(key, on)
	for i, row in ipairs(ns.rows) do
		if row.key == key and ns.RowOn(key) ~= on then
			DB.rows = DB.rows + (on and 1 or -1) * 2 ^ (i - 1)
			return
		end
	end
end

-- Listeners hear about every change: the menu redraws and the options window updates its controls.
local listeners = {}
function ns.OnChange(fn) listeners[#listeners + 1] = fn end
local function fire(key)
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, key)
		if not ok then print("LockMenu: " .. tostring(err)) end
	end
end

-- Persistence. The Forever beta writes saved variables at logout but never reads them back, so the settings are kept in an
-- account-wide macro, which the client saves and reloads itself, and in a custom setting as a second copy. Only settings that
-- differ from their default are stored, because a macro holds 255 characters.
local MACRO_NAME = "LockMenu data"
local MACRO_PREFIX = "#LockMenu settings, do not delete\n"
local CVAR = "LockMenucfg"
local FIELDS = {
	{ key = "hold", code = "h", kind = "bool" },
	{ key = "release", code = "l", kind = "bool" },
	{ key = "close", code = "c", kind = "bool" },
	{ key = "cursor", code = "m", kind = "bool" },
	{ key = "size", code = "s", kind = "num" },
	{ key = "bg", code = "b", kind = "num" },
	{ key = "alpha", code = "a", kind = "num" },
	{ key = "rows", code = "r", kind = "num" },
	{ key = "extra", code = "x", kind = "str" },
}

local restored, userChanged, macroPending, warnedLong = false, false, false, false

local function clean(text)
	return ((text or ""):gsub("[;=\r\n]", ""))
end

local function encode()
	local parts = {}
	for _, f in ipairs(FIELDS) do
		local v, d = DB[f.key], DEFAULTS[f.key]
		local text, default
		if f.kind == "bool" then
			text, default = (v and "1" or "0"), (d and "1" or "0")
		elseif f.kind == "num" then
			text, default = string.format("%.4g", v), string.format("%.4g", d)
		else
			text, default = clean(v), clean(d)
		end
		if text ~= default then parts[#parts + 1] = f.code .. "=" .. text end
	end
	local body = table.concat(parts, ";")
	if #MACRO_PREFIX + #body > 255 then
		if not warnedLong then
			warnedLong = true
			print("LockMenu: the settings are too long to save (probably the extra spells box), so part of them will be lost on the next restart")
		end
		body = body:sub(1, 255 - #MACRO_PREFIX)
	end
	return body
end

local function readMacro()
	if not (GetMacroIndexByName and GetMacroBody) then return nil end
	local ok, index = pcall(GetMacroIndexByName, MACRO_NAME)
	if not ok or not index or index == 0 then return nil end
	local ok2, body = pcall(GetMacroBody, index)
	if not ok2 or type(body) ~= "string" then return nil end
	local rest = body:gsub("^#[^\n]*\n", "")
	return (rest:match("^%s*(.-)%s*$"))
end

local function readCVar()
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local ok, value = pcall(get, CVAR)
	return ok and value or nil
end

local function writeMacro()
	macroPending = false
	if InCombatLockdown() or not (CreateMacro and EditMacro and GetMacroIndexByName) then return end
	local body = MACRO_PREFIX .. encode()
	local ok, index = pcall(GetMacroIndexByName, MACRO_NAME)
	if ok and index and index > 0 then
		pcall(EditMacro, index, nil, nil, body)
	else
		pcall(CreateMacro, MACRO_NAME, "INV_Misc_Note_01", body, false)
	end
end

local cvarRegistered = false
local function persist()
	if not cvarRegistered then
		local reg = (C_CVar and C_CVar.RegisterCVar) or RegisterCVar
		if reg then cvarRegistered = pcall(reg, CVAR, "") end
	end
	local set = (C_CVar and C_CVar.SetCVar) or SetCVar
	if set then pcall(set, CVAR, encode()) end
	if C_Timer and C_Timer.After then
		if not macroPending then
			macroPending = true
			C_Timer.After(1.5, writeMacro)
		end
	else
		writeMacro()
	end
end

local function persistSoon()
	userChanged = true
	persist()
	if C_Timer and C_Timer.After then
		C_Timer.After(2, persist)
		C_Timer.After(8, persist)
	end
end

-- Changes one setting, saves it and tells the listeners.
function ns.Set(key, value)
	DB[key] = value
	persistSoon()
	fire(key)
end

-- Changes the rows setting through SetRow, then saves and tells the listeners.
function ns.SetRowOn(key, on)
	ns.SetRow(key, on)
	persistSoon()
	fire("rows")
end

local function restore()
	if restored then return end
	local s = readMacro() or readCVar()
	if not s or s == "" then return end
	restored = true
	if userChanged then return end
	for part in s:gmatch("[^;]+") do
		local code, value = part:match("^(%a)=(.*)$")
		for _, f in ipairs(FIELDS) do
			if f.code == code then
				if f.kind == "bool" then
					DB[f.key] = value == "1"
				elseif f.kind == "num" then
					local n = tonumber(value)
					if n then DB[f.key] = n end
				else
					DB[f.key] = value
				end
			end
		end
	end
	DB.size = math.max(24, math.min(56, math.floor(DB.size + 0.5)))
	DB.bg = math.max(0, math.min(1, DB.bg))
	DB.alpha = math.max(0.2, math.min(1, DB.alpha))
	DB.rows = math.max(0, math.min(2 ^ #ns.rows - 1, math.floor(DB.rows)))
	fire("all")
end

local loader = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_MACROS" }) do
	pcall(loader.RegisterEvent, loader, e)
end
loader:SetScript("OnEvent", function()
	restore()
end)
