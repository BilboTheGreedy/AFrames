local _, ns = ...
local UI = ns.UI
local C = UI.colors
local secret = ACore.IsSecret
local yes = ns.Yes

local function portrait(b, side)
	local f = CreateFrame("Frame", nil, b.body)
	UI.Fill(f, C.bg)
	UI.Border(f)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetPoint("TOPLEFT", 1, -1)
	f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
	f.side = side
	f:Hide()
	b.portrait = f
end

local function placePortrait(b, height)
	local f = b.portrait
	if not f then return end
	f:ClearAllPoints()
	f:SetSize(height, height)
	if f.side == "LEFT" then
		f:SetPoint("TOPRIGHT", b.body, "TOPLEFT", -3, 0)
	else
		f:SetPoint("TOPLEFT", b.body, "TOPRIGHT", 3, 0)
	end
end

local function updatePortrait(b)
	local f = b.portrait
	if not f then return end
	local cfg = ns.db.units[b.key]
	if not cfg or not cfg.portrait then
		f:Hide()
		return
	end
	if SetPortraitTexture then pcall(SetPortraitTexture, f.tex, b.unit) end
	f:Show()
end

local function statusIcons(b)
	local over = b.over
	b.rest = UI.Text(over, "GameFontHighlightSmall", "LEFT", { 0.6, 0.8, 1 })
	b.rest:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 24, -5)
	b.rest:SetText("zZ")
	b.rest:Hide()
	b.fight = over:CreateTexture(nil, "OVERLAY")
	b.fight:SetSize(14, 14)
	b.fight:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 24, -6)
	b.fight:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	b.fight:SetTexCoord(0.5, 1, 0, 0.49)
	b.fight:Hide()
	b.pvp = UI.Text(over, "GameFontHighlightSmall", "RIGHT", { 1, 0.4, 0.3 })
	b.pvp:SetPoint("BOTTOMRIGHT", over, "TOPRIGHT", -16, -5)
	b.pvp:SetText("PvP")
	b.pvp:Hide()
end

local function updateStatus(b)
	if not b.rest then return end
	local cfg = ns.db.units.player
	if not cfg.icons then
		b.rest:Hide()
		b.fight:Hide()
		b.pvp:Hide()
		return
	end
	local fighting = yes(UnitAffectingCombat and UnitAffectingCombat("player"))
	b.fight:SetShown(fighting)
	b.rest:SetShown(not fighting and yes(IsResting and IsResting()))
	b.pvp:SetShown(yes(UnitIsPVP and UnitIsPVP("player")))
end

local function combo(b)
	local bar = CreateFrame("StatusBar", nil, b.over)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(1, 0.75, 0.2, 1)
	bar:SetMinMaxValues(0, 5)
	bar:SetValue(0)
	bar:SetHeight(5)
	bar:SetPoint("BOTTOMLEFT", b.body, "TOPLEFT", 0, 2)
	bar:SetPoint("BOTTOMRIGHT", b.body, "TOPRIGHT", 0, 2)
	UI.Fill(bar, { 0, 0, 0, 0.6 })
	bar.marks = {}
	for i = 1, 4 do
		local t = UI.Tex(bar, "OVERLAY", { 0, 0, 0, 1 })
		t:SetWidth(1)
		bar.marks[i] = t
	end
	bar:Hide()
	b.combo = bar
end

local function placeCombo(b, width)
	local bar = b.combo
	if not bar then return end
	for i, t in ipairs(bar.marks) do
		t:ClearAllPoints()
		t:SetPoint("TOP", bar, "TOPLEFT", width * i / 5, 0)
		t:SetPoint("BOTTOM", bar, "BOTTOMLEFT", width * i / 5, 0)
	end
end

local function updateCombo(b)
	local bar = b.combo
	if not bar then return end
	local class = ns.playerClass
	if not ns.db.units.target.combo or (class ~= "ROGUE" and class ~= "DRUID") or not UnitExists("target") then
		bar:Hide()
		return
	end
	local points
	if GetComboPoints then
		points = GetComboPoints("player", "target")
	elseif UnitPower then
		points = UnitPower("player", 4)
	end
	if secret(points) then
		bar:SetValue(points)
		bar:Show()
	elseif type(points) == "number" and points > 0 then
		bar:SetValue(points)
		bar:Show()
	else
		bar:Hide()
	end
end

local function castBar(b)
	local bar = UI.Bar(b.body, 14)
	bar:SetPoint("TOPLEFT", b.body, "BOTTOMLEFT", 15, -3)
	bar:SetPoint("TOPRIGHT", b.body, "BOTTOMRIGHT", 0, -3)
	bar.icon = bar:CreateTexture(nil, "ARTWORK")
	bar.icon:SetSize(14, 14)
	bar.icon:SetPoint("RIGHT", bar, "LEFT", -1, 0)
	bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	bar.shield = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	bar.shield:SetAllPoints(bar:GetStatusBarTexture() or bar)
	bar.shield:SetColorTexture(0.6, 0.6, 0.65, 1)
	bar.shield:SetAlpha(0)
	bar:Hide()
	bar:SetScript("OnUpdate", function(self)
		local a = self.active
		if not a then return end
		local now = GetTime and GetTime() or 0
		if now >= a[2] then
			self.active = nil
			self:Hide()
			b.auraOffset = 0
			ns.UpdateAuras(b)
			return
		end
		if a[3] then
			self:SetValue(a[2] - now)
		else
			self:SetValue(now - a[1])
		end
		self.right:SetFormattedText("%.1f", a[2] - now)
	end)
	b.cast = bar
end

local function updateCast(b)
	local bar = b.cast
	if not bar then return end
	local was = bar:IsShown()
	local function done()
		bar.active = nil
		bar:Hide()
		b.auraOffset = 0
		if was then ns.UpdateAuras(b) end
	end
	if not ns.db.units.target.castbar or ns.HasACast() or not UnitExists(b.unit) then return done() end
	local name, tex, s, e, shield, _
	local channel = false
	if UnitCastingInfo then
		name, _, tex, s, e, _, _, shield = UnitCastingInfo(b.unit)
	end
	if not secret(name) and not name and UnitChannelInfo then
		name, _, tex, s, e, _, shield = UnitChannelInfo(b.unit)
		channel = true
	end
	if not secret(name) and not name then return done() end
	bar.left:SetText(name)
	bar.icon:SetTexture(tex)
	bar:SetColor(C.accent[1], C.accent[2], C.accent[3], 0.85)
	local grey = bar.shield
	if not secret(shield) then
		grey:SetAlpha(shield and 1 or 0)
	elseif not (grey.SetAlphaFromBoolean and pcall(grey.SetAlphaFromBoolean, grey, shield, 1, 0)) then
		grey:SetAlpha(0)
	end
	if secret(s) or secret(e) or type(s) ~= "number" or type(e) ~= "number" then
		bar.active = nil
		local set = false
		local fn = channel and UnitChannelDuration or UnitCastingDuration
		if fn and bar.SetTimerDuration then
			local ok, d = pcall(fn, b.unit)
			if ok and d then
				local dir = Enum and Enum.StatusBarTimerDirection
				local smooth = Enum and Enum.StatusBarInterpolation
				if dir and smooth then
					set = pcall(bar.SetTimerDuration, bar, d, smooth.Immediate, channel and dir.RemainingTime or dir.ElapsedTime)
				end
				if not set then set = pcall(bar.SetTimerDuration, bar, d) end
			end
		end
		if not set then
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
		end
		bar.right:SetText("")
	else
		bar.active = { s / 1000, e / 1000, channel }
		bar:SetMinMaxValues(0, math.max(0.01, (e - s) / 1000))
	end
	bar:Show()
	b.auraOffset = 18
	if not was then ns.UpdateAuras(b) end
end

local function manaBar(b)
	local bar = CreateFrame("StatusBar", nil, b.over)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetStatusBarColor(0.25, 0.45, 0.95, 1)
	bar:SetHeight(3)
	bar:SetPoint("BOTTOMLEFT", b.power, "TOPLEFT", 0, 1)
	bar:SetPoint("BOTTOMRIGHT", b.power, "TOPRIGHT", 0, 1)
	UI.Fill(bar, { 0, 0, 0, 0.6 })
	bar:Hide()
	b.mana = bar
end

local function updateMana(b)
	local bar = b.mana
	if not bar then return end
	local _, token = UnitPowerType("player")
	if ns.playerClass ~= "DRUID" or not ns.db.units.player.mana or secret(token) or token == "MANA" then
		bar:Hide()
		return
	end
	bar:SetMinMaxValues(0, UnitPowerMax("player", 0))
	bar:SetValue(UnitPower("player", 0))
	bar:Show()
end

function ns.Decorate(b, key)
	b.key = key
	if key == "player" then
		portrait(b, "LEFT")
		statusIcons(b)
		manaBar(b)
	elseif key == "target" then
		portrait(b, "RIGHT")
		combo(b)
		castBar(b)
		b.classify = true
		b.allAuras = true
		b.auraRows = true
		b.timers = true
		b.maxDebuffs, b.maxBuffs, b.debuffSize, b.buffSize = 16, 16, 20, 18
	elseif key == "focus" then
		b.classify = true
		b.timers = true
		b.maxDebuffs, b.maxBuffs = 6, 0
	end
	b.onResize = function(self, width, height)
		placePortrait(self, height)
		placeCombo(self, width)
	end
end

function ns.UpdateExtras(b)
	if not b.key then return end
	updatePortrait(b)
	updateStatus(b)
	updateCombo(b)
	updateCast(b)
	updateMana(b)
end

local function player(fn)
	return function() ns.Each(fn, "player") end
end
ns:On("PLAYER_UPDATE_RESTING", player(updateStatus))
ns:On("PLAYER_REGEN_DISABLED", player(updateStatus))
ns:On("PLAYER_REGEN_ENABLED", player(updateStatus))
ns:On("UNIT_PORTRAIT_UPDATE", function(unit) ns.Each(updatePortrait, unit) end)
ns:On("UNIT_MODEL_CHANGED", function(unit) ns.Each(updatePortrait, unit) end)
ns:On("UNIT_COMBO_POINTS", function() ns.Each(updateCombo, "target") end)
ns:On("UNIT_POWER_UPDATE", function(unit)
	if not secret(unit) and unit == "player" then
		ns.Each(updateCombo, "target")
		ns.Each(updateMana, "player")
	end
end)
ns:On("UNIT_DISPLAYPOWER", function(unit)
	if not secret(unit) and unit == "player" then ns.Each(updateMana, "player") end
end)
ns:On("UNIT_MAXPOWER", function(unit)
	if not secret(unit) and unit == "player" then ns.Each(updateMana, "player") end
end)
for _, e in ipairs({
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}) do
	ns:On(e, function(unit) ns.Each(updateCast, unit) end)
end
