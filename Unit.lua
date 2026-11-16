local _, ns = ...
local A = ACore
local UI = ns.UI
local C = UI.colors
local secret = A.IsSecret

local WHITE = "Interface\\Buttons\\WHITE8X8"

local POWER = {
	MANA = { 0.25, 0.45, 0.95 },
	RAGE = { 0.85, 0.2, 0.2 },
	ENERGY = { 1, 0.85, 0.2 },
	FOCUS = { 1, 0.55, 0.25 },
	RUNIC_POWER = { 0, 0.82, 1 },
}

local DISPEL = {
	Magic = { 0.2, 0.6, 1 },
	Curse = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison = { 0, 0.6, 0 },
}

local ROLE = {
	TANK = { "T", 0.4, 0.6, 1 },
	HEALER = { "H", 0.4, 1, 0.5 },
	DAMAGER = { "D", 1, 0.45, 0.4 },
}

ns.buttons = {}
ns.byUnit = {}

local function yes(v)
	if secret(v) then return false end
	return v and true or false
end

local function short(v)
	if secret(v) then
		if AbbreviateNumbers then return AbbreviateNumbers(v) end
		return v
	end
	if type(v) ~= "number" then return "" end
	return A.Short(v)
end

local dispelCurve
local function dispelColor(unit, data)
	local name = data.dispelName
	if not secret(name) then
		local c = name and DISPEL[name]
		if c then return c[1], c[2], c[3], 1 end
		return nil
	end
	if not (C_UnitAuras.GetAuraDispelTypeColor and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor and Enum and Enum.LuaCurveType) then
		return nil
	end
	if not dispelCurve then
		local ok, curve = pcall(function()
			local cv = C_CurveUtil.CreateColorCurve()
			cv:SetType(Enum.LuaCurveType.Step)
			cv:AddPoint(0, CreateColor(0, 0, 0, 0))
			cv:AddPoint(1, CreateColor(0.2, 0.6, 1, 1))
			cv:AddPoint(2, CreateColor(0.6, 0, 1, 1))
			cv:AddPoint(3, CreateColor(0.6, 0.4, 0, 1))
			cv:AddPoint(4, CreateColor(0, 0.6, 0, 1))
			return cv
		end)
		dispelCurve = ok and curve or false
	end
	if not dispelCurve then return nil end
	local ok, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, data.auraInstanceID, dispelCurve)
	if ok and color and color.GetRGBA then return color:GetRGBA() end
	return nil
end

ns.Yes = yes

local function auraIcon(b, size)
	local f = CreateFrame("Frame", nil, b.body)
	f:SetSize(size, size)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints(f)
	f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.edges = UI.Border(f, { 0, 0, 0, 1 })
	f.count = UI.Text(f, "NumberFontNormalSmall", "RIGHT")
	f.count:SetPoint("BOTTOMRIGHT", 2, -1)
	if b.timers then
		local ok, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
		if ok and cd then
			cd:SetAllPoints(f)
			if cd.SetReverse then cd:SetReverse(true) end
			f.cd = cd
		end
	end
	return f
end

local function setTimer(icon, unit, data)
	local cd = icon.cd
	if not cd then return end
	if C_UnitAuras.GetAuraDuration and cd.SetCooldownFromDurationObject and data.auraInstanceID then
		local ok, d = pcall(C_UnitAuras.GetAuraDuration, unit, data.auraInstanceID)
		if ok and d and pcall(cd.SetCooldownFromDurationObject, cd, d) then return end
	end
	local dur, exp = data.duration, data.expirationTime
	if not secret(dur) and not secret(exp) and type(dur) == "number" and type(exp) == "number" and dur > 0 then
		cd:SetCooldown(exp - dur, dur)
	elseif cd.Clear then
		cd:Clear()
	end
end

local function fillAuras(b, icons, filter, max, size, highlight, big)
	local unit = b.unit
	local shown = 0
	local first
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for i = 1, max do
			local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
			if not ok or not data then break end
			shown = shown + 1
			local icon = icons[shown]
			if not icon then
				icon = auraIcon(b, size)
				icons[shown] = icon
			end
			local own = data.isFromPlayerOrPlayerPet
			local s = size
			if big and not secret(own) and own then s = size + 6 end
			icon.size = s
			icon:SetSize(s, s)
			icon.tex:SetTexture(data.icon)
			if C_UnitAuras.GetAuraApplicationDisplayCount and data.auraInstanceID then
				local okc, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, data.auraInstanceID, 2, 99)
				if not okc then
					icon.count:SetText("")
				elseif secret(text) then
					icon.count:SetText(text)
				else
					icon.count:SetText(text or "")
				end
			else
				local n = data.applications
				if not secret(n) and type(n) == "number" and n > 1 then
					icon.count:SetText(n)
				else
					icon.count:SetText("")
				end
			end
			setTimer(icon, unit, data)
			local r, g, bl, a
			if highlight then r, g, bl, a = dispelColor(unit, data) end
			if r and not first then first = { r, g, bl, a or 1 } end
			for _, e in ipairs(icon.edges) do
				if r then
					e:SetColorTexture(r, g, bl, a or 1)
				else
					e:SetColorTexture(0, 0, 0, 1)
				end
			end
			icon:Show()
		end
	end
	for i = shown + 1, #icons do icons[i]:Hide() end
	return shown, first
end

local function placeAuras(b)
	local x, y, row = 0, 0, 0
	local width = b:GetWidth() or 200
	local function put(icon)
		local size = icon.size or 20
		icon:ClearAllPoints()
		if b.auraSide == "INSIDE" then
			icon:SetPoint("BOTTOMLEFT", b.body, "BOTTOMLEFT", 2 + x, 5)
		elseif b.auraSide == "RIGHT" then
			icon:SetPoint("TOPLEFT", b.body, "TOPRIGHT", 4 + x, y)
		else
			if x + size > width and x > 0 then
				x = 0
				y = y - row - 2
				row = 0
			end
			icon:SetPoint("TOPLEFT", b.body, "BOTTOMLEFT", x, y - 4 - (b.auraOffset or 0))
		end
		if size > row then row = size end
		x = x + size + 2
	end
	for _, icon in ipairs(b.debuffs) do
		if icon:IsShown() then put(icon) end
	end
	if b.auraSide == "RIGHT" then
		x, y = 0, -24
	elseif b.auraSide == "BELOW" and b.auraRows then
		if x > 0 then
			x = 0
			y = y - row - 2
			row = 0
		end
	elseif x > 0 then
		x = x + 6
	end
	for _, icon in ipairs(b.buffs) do
		if icon:IsShown() then put(icon) end
	end
end

function ns.UpdateAuras(b)
	local db = ns.db
	if b.style == "small" then return end
	local hostile = yes(UnitCanAttack and UnitCanAttack("player", b.unit))
	local nd, nb = b.maxDebuffs or 4, b.maxBuffs or 4
	if not db.debuffs then nd = 0 end
	if not db.buffs then nb = 0 end
	local dfilter, bfilter
	if b.allAuras then
		dfilter, bfilter = "HARMFUL", "HELPFUL"
	else
		dfilter = hostile and "HARMFUL|PLAYER" or "HARMFUL"
		bfilter = hostile and "HELPFUL" or "HELPFUL|PLAYER"
	end
	local _, color = fillAuras(b, b.debuffs, dfilter, nd, b.debuffSize or 22, not hostile, b.allAuras)
	fillAuras(b, b.buffs, bfilter, nb, b.buffSize or 16, false, false)
	placeAuras(b)
	if b.style == "raid" then
		b.dispel = color
		ns.UpdateTarget(b)
	end
end

local function barColor(unit)
	if not yes(UnitIsPlayer(unit)) and UnitIsTapDenied and yes(UnitIsTapDenied(unit)) then
		return 0.5, 0.5, 0.5
	end
	if ns.db.classColor and yes(UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		local c = not secret(class) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
		return 0.2, 0.75, 0.3
	end
	if yes(UnitIsPlayer(unit)) then return 0.2, 0.75, 0.3 end
	local reaction = UnitReaction and UnitReaction(unit, "player")
	if secret(reaction) or not reaction then return 0.2, 0.75, 0.3 end
	if reaction <= 3 then return 0.85, 0.25, 0.2 end
	if reaction == 4 then return 0.95, 0.8, 0.2 end
	return 0.2, 0.75, 0.3
end

function ns.UpdateHealth(b)
	local unit = b.unit
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	b.health:SetMinMaxValues(0, max)
	b.health:SetValue(hp)

	local state
	local connected = UnitIsConnected(unit)
	if not secret(connected) and connected == false then
		state = "Offline"
	elseif yes(UnitIsGhost and UnitIsGhost(unit)) then
		state = "Ghost"
	elseif yes(UnitIsDeadOrGhost(unit)) then
		state = "Dead"
	end

	local t = b.health.right
	local mode = ns.db.healthText
	if b.style ~= "full" and not state then mode = "none" end
	if state then
		t:SetText(state)
	elseif mode == "percent" then
		if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
			t:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
		elseif not secret(hp) and not secret(max) and max > 0 then
			t:SetFormattedText("%d%%", math.floor(hp / max * 100 + 0.5))
		else
			t:SetText("")
		end
	elseif mode == "value" then
		t:SetText(short(hp))
	elseif mode == "deficit" then
		local missing
		if UnitHealthMissing then
			missing = UnitHealthMissing(unit)
		elseif not secret(hp) and not secret(max) then
			missing = max - hp
		end
		if secret(missing) then
			t:SetFormattedText("-%s", short(missing))
		elseif missing and missing > 0 then
			t:SetText("-" .. short(missing))
		else
			t:SetText("")
		end
	else
		t:SetText("")
	end

	if state then
		b.health:SetColor(0.35, 0.35, 0.38)
		b.health.left:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	else
		b.health:SetColor(barColor(unit))
		local n = b.nameColor or C.text
		b.health.left:SetTextColor(n[1], n[2], n[3])
	end

	if UnitGetIncomingHeals and not state then
		local inc = UnitGetIncomingHeals(unit)
		b.pred:SetMinMaxValues(0, max)
		if secret(inc) then
			b.pred:SetValue(inc)
		else
			b.pred:SetValue(inc or 0)
		end
		b.pred:Show()
	else
		b.pred:Hide()
	end
end

function ns.UpdatePower(b)
	local unit = b.unit
	local _, token = UnitPowerType(unit)
	local c = not secret(token) and token and ((PowerBarColor and PowerBarColor[token]) or POWER[token])
	if c then
		b.power:SetColor(c.r or c[1], c.g or c[2], c.b or c[3])
	else
		b.power:SetColor(0.25, 0.45, 0.95)
	end
	b.power:SetMinMaxValues(0, UnitPowerMax(unit))
	b.power:SetValue(UnitPower(unit))
end

local TAGS = { elite = "+", rareelite = "R+", rare = "R", worldboss = "B" }

local function levelColor(level)
	if GetQuestDifficultyColor then
		local ok, c = pcall(GetQuestDifficultyColor, level)
		if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
	end
	local mine = UnitLevel("player")
	if secret(mine) or type(mine) ~= "number" then return C.dim[1], C.dim[2], C.dim[3] end
	local diff = level - mine
	if diff >= 5 then return 1, 0.1, 0.1 end
	if diff >= 3 then return 1, 0.5, 0.25 end
	if diff >= -2 then return 1, 0.82, 0 end
	if diff >= -8 then return 0.25, 0.75, 0.25 end
	return 0.6, 0.6, 0.6
end

function ns.UpdateName(b)
	local unit = b.unit
	b.health.left:SetText(UnitName(unit))
	if b.unit == "pet" and GetPetHappiness then
		local ok, mood = pcall(GetPetHappiness)
		if ok and not secret(mood) and type(mood) == "number" then
			if mood >= 3 then
				b.nameColor = { 0.4, 1, 0.4 }
			elseif mood == 2 then
				b.nameColor = { 1, 0.9, 0.3 }
			else
				b.nameColor = { 1, 0.35, 0.3 }
			end
		end
	end
	if not b.level then return end
	local level = UnitLevel(unit)
	local tag = ""
	if b.classify and UnitClassification then
		local kind = UnitClassification(unit)
		if not secret(kind) and kind then tag = TAGS[kind] or "" end
	end
	if secret(level) then
		b.level:SetText(level)
		b.level:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	elseif not level or level <= 0 then
		b.level:SetText("??" .. tag)
		b.level:SetTextColor(1, 0.1, 0.1)
	else
		b.level:SetText(level .. tag)
		if yes(UnitCanAttack and UnitCanAttack("player", unit)) then
			b.level:SetTextColor(levelColor(level))
		else
			b.level:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
		end
	end
end

function ns.UpdateIcons(b)
	local unit = b.unit
	b.leader:SetShown(yes(UnitIsGroupLeader and UnitIsGroupLeader(unit)))
	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	local r = not secret(role) and role and ROLE[role]
	if r then
		b.role:SetText(r[1])
		b.role:SetTextColor(r[2], r[3], r[4])
	else
		b.role:SetText("")
	end
	if b.ready then
		local status = GetReadyCheckStatus and GetReadyCheckStatus(unit)
		if secret(status) or not status then
			b.ready:Hide()
		else
			if status == "ready" then
				b.ready:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
			elseif status == "notready" then
				b.ready:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
			else
				b.ready:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
			end
			b.ready:Show()
		end
	end
	local index = GetRaidTargetIndex and GetRaidTargetIndex(unit)
	if not secret(index) and index and SetRaidTargetIconTexture then
		b.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		SetRaidTargetIconTexture(b.mark, index)
		b.mark:Show()
	else
		b.mark:Hide()
	end
end

function ns.UpdateTarget(b)
	local on = b.unit ~= "target" and yes(UnitIsUnit(b.unit, "target"))
	local c = on and C.accent or b.dispel or C.line
	for _, e in ipairs(b.edges) do
		e:SetColorTexture(c[1], c[2], c[3], 1)
	end
end

function ns.UpdateRange(b)
	if not b.ranged or not ns.db.range then
		b.body:SetAlpha(1)
		return
	end
	local inRange, checked = UnitInRange(b.unit)
	if secret(inRange) then
		if b.body.SetAlphaFromBoolean then b.body:SetAlphaFromBoolean(inRange, 1, 0.45) end
		return
	end
	if secret(checked) then return end
	local connected = UnitIsConnected(b.unit)
	if checked and not inRange and not (not secret(connected) and connected == false) then
		b.body:SetAlpha(0.45)
	else
		b.body:SetAlpha(1)
	end
end

function ns.UpdateAll(b)
	if not UnitExists(b.unit) then return end
	ns.UpdateName(b)
	ns.UpdateHealth(b)
	ns.UpdatePower(b)
	ns.UpdateIcons(b)
	ns.UpdateTarget(b)
	ns.UpdateAuras(b)
	ns.UpdateRange(b)
	if ns.UpdateExtras then ns.UpdateExtras(b) end
end

function ns.Each(fn, unit)
	if unit then
		if secret(unit) then return end
		local l = ns.byUnit[unit]
		if not l then return end
		for i = 1, #l do
			if l[i]:IsShown() then fn(l[i]) end
		end
		return
	end
	for _, b in ipairs(ns.buttons) do
		if b:IsShown() then fn(b) end
	end
end

function ns.Resize(b, width, height)
	b:SetSize(width, height)
	b.pred:SetWidth(width - 2)
	if b.onResize then b.onResize(b, width, height) end
end

function ns.CreateUnit(name, parent, unit, style, auraSide)
	local ok, b = pcall(CreateFrame, "Button", name, parent, "SecureUnitButtonTemplate")
	if not ok or not b then b = CreateFrame("Button", name, parent) end
	b.unit = unit
	b.style = style
	b.auraSide = auraSide
	b.ranged = unit:find("^party") ~= nil or unit:find("^raid") ~= nil
	b:SetSize(100, 30)
	b:SetAttribute("unit", unit)
	b:SetAttribute("*type1", "target")
	b:SetAttribute("*type2", "togglemenu")
	b:RegisterForClicks("AnyUp")

	local body = CreateFrame("Frame", nil, b)
	body:SetAllPoints(b)
	UI.Fill(body, C.bg)
	b.body = body
	b.edges = UI.Border(body)

	local power = UI.Bar(body, style == "full" and 6 or 3)
	power:SetPoint("BOTTOMLEFT", 1, 1)
	power:SetPoint("BOTTOMRIGHT", -1, 1)
	power.left:Hide()
	power.right:Hide()
	b.power = power

	local health = UI.Bar(body, 20)
	health:SetPoint("TOPLEFT", 1, -1)
	health:SetPoint("TOPRIGHT", -1, -1)
	health:SetPoint("BOTTOMLEFT", power, "TOPLEFT", 0, 1)
	if health.SetClipsChildren then health:SetClipsChildren(true) end
	b.health = health

	local pred = CreateFrame("StatusBar", nil, health)
	pred:SetStatusBarTexture(WHITE)
	pred:SetStatusBarColor(0.45, 1, 0.55, 0.4)
	local fill = health:GetStatusBarTexture()
	pred:SetPoint("TOPLEFT", fill or health, "TOPRIGHT")
	pred:SetPoint("BOTTOMLEFT", fill or health, "BOTTOMRIGHT")
	pred:SetWidth(98)
	pred:Hide()
	b.pred = pred

	local over = CreateFrame("Frame", nil, body)
	over:SetAllPoints(body)
	over:SetFrameLevel((body:GetFrameLevel() or 1) + 5)
	b.over = over

	health.left:SetParent(over)
	health.right:SetParent(over)
	health.left:ClearAllPoints()
	if style == "full" then
		b.level = UI.Text(over, "GameFontHighlightSmall", "LEFT", C.dim)
		b.level:SetPoint("LEFT", health, "LEFT", 5, 0)
		health.left:SetPoint("LEFT", b.level, "RIGHT", 4, 0)
	else
		health.left:SetPoint("LEFT", health, "LEFT", 4, 0)
	end
	health.left:SetPoint("RIGHT", health.right, "LEFT", -4, 0)

	b.leader = over:CreateTexture(nil, "OVERLAY")
	b.leader:SetSize(12, 12)
	b.leader:SetPoint("TOPLEFT", -3, 6)
	b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	b.leader:Hide()

	b.role = UI.Text(over, "GameFontHighlightSmall", "RIGHT")
	b.role:SetPoint("TOPRIGHT", -3, 6)

	b.mark = over:CreateTexture(nil, "OVERLAY")
	b.mark:SetSize(16, 16)
	b.mark:SetPoint("CENTER", over, "TOP", 0, 2)
	b.mark:Hide()

	if style == "raid" then
		b.ready = over:CreateTexture(nil, "OVERLAY")
		b.ready:SetSize(16, 16)
		b.ready:SetPoint("CENTER", over, "CENTER", 0, 0)
		b.ready:Hide()
		b.maxDebuffs, b.maxBuffs, b.debuffSize = 2, 0, 13
	end

	b.debuffs = {}
	b.buffs = {}

	b:SetScript("OnShow", function(self) ns.UpdateAll(self) end)
	b:SetScript("OnEnter", function(self)
		if not ns.db.tooltips then return end
		if GameTooltip_SetDefaultAnchor then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
		pcall(GameTooltip.SetUnit, GameTooltip, self.unit)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	ns.buttons[#ns.buttons + 1] = b
	ns.byUnit[unit] = ns.byUnit[unit] or {}
	table.insert(ns.byUnit[unit], b)
	return b
end

local function unitEvent(event, fn)
	ns:On(event, function(unit) ns.Each(fn, unit) end)
end

unitEvent("UNIT_HEALTH", ns.UpdateHealth)
unitEvent("UNIT_MAXHEALTH", ns.UpdateHealth)
unitEvent("UNIT_HEAL_PREDICTION", ns.UpdateHealth)
unitEvent("UNIT_CONNECTION", ns.UpdateAll)
unitEvent("UNIT_FLAGS", ns.UpdateHealth)
unitEvent("UNIT_POWER_UPDATE", ns.UpdatePower)
unitEvent("UNIT_MAXPOWER", ns.UpdatePower)
unitEvent("UNIT_DISPLAYPOWER", ns.UpdatePower)
unitEvent("UNIT_NAME_UPDATE", ns.UpdateName)
unitEvent("UNIT_LEVEL", ns.UpdateName)
unitEvent("UNIT_AURA", ns.UpdateAuras)

ns:On("GROUP_ROSTER_UPDATE", function() ns.Each(ns.UpdateAll) end)
ns:On("PLAYER_ENTERING_WORLD", function() ns.Each(ns.UpdateAll) end)
ns:On("PARTY_LEADER_CHANGED", function() ns.Each(ns.UpdateIcons) end)
ns:On("PLAYER_ROLES_ASSIGNED", function() ns.Each(ns.UpdateIcons) end)
ns:On("RAID_TARGET_UPDATE", function() ns.Each(ns.UpdateIcons) end)
ns:On("PLAYER_TARGET_CHANGED", function()
	ns.Each(ns.UpdateAll, "target")
	ns.Each(ns.UpdateAll, "targettarget")
	ns.Each(ns.UpdateTarget)
end)
ns:On("PLAYER_FOCUS_CHANGED", function() ns.Each(ns.UpdateAll, "focus") end)
ns:On("UNIT_PET", function() ns.Each(ns.UpdateAll) end)
ns:On("UNIT_HAPPINESS", function() ns.Each(ns.UpdateName, "pet") end)
ns:On("UNIT_CLASSIFICATION_CHANGED", function(unit) ns.Each(ns.UpdateName, unit) end)
ns:On("UNIT_FACTION", function(unit) ns.Each(ns.UpdateAll, unit) end)
ns:On("READY_CHECK", function() ns.Each(ns.UpdateIcons) end)
ns:On("READY_CHECK_CONFIRM", function() ns.Each(ns.UpdateIcons) end)
ns:On("READY_CHECK_FINISHED", function() ns.Each(ns.UpdateIcons) end)
