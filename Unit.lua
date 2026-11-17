local _, ns = ...
local A = ACore
local UI = ns.UI
local C = UI.colors
local secret = A.IsSecret

local WHITE = "Interface\\Buttons\\WHITE8X8"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

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
		if AbbreviateNumbers then
			local ok, text = pcall(AbbreviateNumbers, v)
			if ok then return text end
		end
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
	if not (C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor and data.auraInstanceID and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor and Enum and Enum.LuaCurveType) then
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
ns.Short = short

local logged = {}
local function note(what, err)
	local msg = what .. ": " .. tostring(err)
	if logged[msg] then return end
	logged[msg] = true
	if ABug and ABug.Log then pcall(ABug.Log, "caught", "AFrames: " .. msg) end
end
ns.Note = note

local SCAN = 40

local function own(data)
	local mine = data.isFromPlayerOrPlayerPet
	if not secret(mine) and mine then return true end
	local src = data.sourceUnit
	if not secret(src) and (src == "player" or src == "pet" or src == "vehicle") then return true end
	return false
end

local function readable(data)
	if type(data) ~= "table" or secret(data) then return false end
	if issecrettable then
		local ok, hidden = pcall(issecrettable, data)
		if ok and hidden then return false end
	end
	return true
end

local function byIndex(unit, filter, max, out, mine)
	local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not fn then return end
	for i = 1, mine and SCAN or max do
		local data = fn(unit, i, filter)
		if data == nil then return end
		if readable(data) and (not mine or own(data)) then out[#out + 1] = data end
		if #out >= max then return end
	end
end

local function byList(unit, filter, max, out, mine)
	local fn = C_UnitAuras and C_UnitAuras.GetUnitAuras
	if not fn then return end
	local list = fn(unit, filter, not mine and max or nil)
	if not readable(list) then return end
	for i = 1, #list do
		if #out >= max then return end
		local data = list[i]
		if readable(data) and (not mine or own(data)) then out[#out + 1] = data end
	end
end

local function slots(unit, max, out, _, ...)
	for i = 1, select("#", ...) do
		if #out >= max then return end
		local data = C_UnitAuras.GetAuraDataBySlot(unit, (select(i, ...)))
		if readable(data) then out[#out + 1] = data end
	end
end

local function bySlots(unit, filter, max, out)
	if not (C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot) then return end
	slots(unit, max, out, C_UnitAuras.GetAuraSlots(unit, filter, max))
end

local function byEach(unit, filter, max, out)
	if not (AuraUtil and AuraUtil.ForEachAura) then return end
	AuraUtil.ForEachAura(unit, filter, max, function(data)
		if readable(data) then out[#out + 1] = data end
		return #out >= max
	end, true)
end

local function byOld(unit, filter, max, out)
	local fn = UnitBuff
	if filter:find("HARMFUL") then fn = UnitDebuff end
	if not fn then fn = UnitAura end
	if not fn then return end
	for i = 1, max do
		local name, icon, count, kind, duration, expires, source = fn(unit, i, filter)
		if not secret(name) and not name then return end
		out[#out + 1] = {
			name = name, icon = icon, applications = count, dispelName = kind, duration = duration,
			expirationTime = expires, sourceUnit = source,
		}
	end
end

local METHODS = {
	{ "GetUnitAuras", byList }, { "GetAuraDataByIndex", byIndex }, { "GetAuraSlots", bySlots },
	{ "ForEachAura", byEach }, { "UnitAura", byOld },
}

local function gather(i, unit, filter, max, out, mine)
	local m = METHODS[i]
	local ok, err = pcall(m[2], unit, filter, max, out, mine)
	if not ok then note(m[1] .. " " .. filter, err) end
	return #out > 0
end

function ns.Auras(unit, filter, max)
	local out = {}
	if not max or max <= 0 then return out end
	if gather(1, unit, filter, max, out) then return out end
	if gather(2, unit, filter, max, out) then
		note("auras read through " .. METHODS[2][1], filter)
		return out
	end
	local base = filter:match("^(%u+)|PLAYER$")
	if base then
		for i = 1, 2 do
			if gather(i, unit, base, max, out, true) then
				note("own auras read through " .. METHODS[i][1], filter)
				return out
			end
		end
	end
	for i = 3, #METHODS do
		if gather(i, unit, filter, max, out) then
			note("auras read through " .. METHODS[i][1], filter)
			return out
		end
	end
	return out
end

function ns.AuraReport(unit)
	unit = unit or "target"
	local lines = { "auras on " .. unit .. ", combat " .. tostring(InCombatLockdown and InCombatLockdown() and true or false) }
	for _, filter in ipairs({ "HARMFUL", "HARMFUL|PLAYER" }) do
		for _, m in ipairs(METHODS) do
			local out = {}
			local ok, err = pcall(m[2], unit, filter, SCAN, out)
			local line = filter .. " " .. m[1] .. ": " .. (ok and #out or ("error " .. tostring(err)))
			local d = out[1]
			if d then
				line = line .. ", icon secret " .. tostring(secret(d.icon)) .. ", id secret " .. tostring(secret(d.auraInstanceID))
			end
			lines[#lines + 1] = line
		end
	end
	for _, line in ipairs(lines) do ns.Print(line) end
	if ABug and ABug.Log then pcall(ABug.Log, "caught", "AFrames: " .. table.concat(lines, "; ")) end
	return lines
end

local function auraIcon(b, size)
	local f = CreateFrame("Frame", nil, b.body)
	f:SetSize(size, size)
	UI.Fill(f, { 0, 0, 0, 1 })
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
		else
			note("Cooldown", cd)
		end
	end
	return f
end

local function setTimer(icon, unit, data)
	local cd = icon.cd
	if not cd then return end
	if C_UnitAuras and C_UnitAuras.GetAuraDuration and cd.SetCooldownFromDurationObject and data.auraInstanceID then
		local ok, d = pcall(C_UnitAuras.GetAuraDuration, unit, data.auraInstanceID)
		if not ok then
			note("GetAuraDuration", d)
		elseif d then
			local set, err = pcall(cd.SetCooldownFromDurationObject, cd, d)
			if set then return end
			note("SetCooldownFromDurationObject", err)
		end
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
	local list = ns.Auras(unit, filter, max)
	local first
	for shown = 1, #list do
		local data = list[shown]
		local icon = icons[shown]
		if not icon then
			icon = auraIcon(b, size)
			icons[shown] = icon
		end
		local s = size
		if big and own(data) then s = size + 6 end
		icon.size = s
		icon:SetSize(s, s)
		local drawn, why = pcall(icon.tex.SetTexture, icon.tex, data.icon)
		if not drawn then
			note("SetTexture", why)
			icon.tex:SetTexture(QUESTION)
		end
		local id = data.auraInstanceID
		if C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount and id then
			local okc, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, 2, 99)
			if not okc then
				note("GetAuraApplicationDisplayCount", text)
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
			if not r or not pcall(e.SetColorTexture, e, r, g, bl, a or 1) then
				e:SetColorTexture(0, 0, 0, 1)
			end
		end
		icon:Show()
	end
	for i = #list + 1, #icons do icons[i]:Hide() end
	return #list, first
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
	local k = db.auraScale or 1
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
	local mineOnly = db.dispelMine and b.ranged
	local _, color = fillAuras(b, b.debuffs, dfilter, nd, math.floor((b.debuffSize or 22) * k + 0.5), not hostile and not mineOnly, b.allAuras)
	fillAuras(b, b.buffs, bfilter, nb, math.floor((b.buffSize or 16) * k + 0.5), false, false)
	placeAuras(b)
	if b.ranged then
		if mineOnly and not hostile and nd > 0 then
			local first = ns.Auras(b.unit, "HARMFUL|RAID", 1)[1]
			if first then
				local r, g, bl, a = dispelColor(b.unit, first)
				color = r and { r, g, bl, a or 1 } or DISPEL.Magic
			end
		end
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
	local cur, max = UnitPower(unit), UnitPowerMax(unit)
	b.power:SetMinMaxValues(0, max)
	b.power:SetValue(cur)
	local t = b.ptext
	if not t then return end
	if not ns.db.powerText or (not secret(max) and (type(max) ~= "number" or max <= 0)) then
		t:SetText("")
	else
		t:SetText(short(cur))
	end
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
	if b.unit == "pet" then b.nameColor = nil end
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

local function looter()
	local fn = (C_PartyInfo and C_PartyInfo.GetLootMethod) or GetLootMethod
	if not fn then return nil end
	local ok, method, pid, rid = pcall(fn)
	if not ok or secret(method) or secret(pid) or secret(rid) or method == nil then return nil end
	local master = Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter
	if method ~= "master" and method ~= master then return nil end
	if type(rid) == "number" then return "raid" .. rid end
	if pid == 0 then return "player" end
	if type(pid) == "number" then return "party" .. pid end
	return nil
end

function ns.UpdateIcons(b)
	local unit = b.unit
	b.leader:SetShown(yes(UnitIsGroupLeader and UnitIsGroupLeader(unit)))
	local who = looter()
	b.loot:SetShown(who ~= nil and yes(UnitIsUnit(unit, who)))
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
	local c = on and C.accent or b.dispel or b.threat or C.line
	for _, e in ipairs(b.edges) do
		if not pcall(e.SetColorTexture, e, c[1], c[2], c[3], 1) then
			e:SetColorTexture(C.line[1], C.line[2], C.line[3], 1)
		end
	end
end

local AGGRO = { 1, 0.2, 0.15 }

function ns.UpdateThreat(b)
	local status
	if b.aggro and ns.db.threat and UnitThreatSituation then
		local ok, v = pcall(UnitThreatSituation, b.unit)
		if ok and not secret(v) and type(v) == "number" then status = v end
	end
	b.threat = status and status >= 2 and AGGRO or nil
	ns.UpdateTarget(b)
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
	ns.UpdateThreat(b)
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
	if b.ptext then
		b.health.right:ClearAllPoints()
		b.health.right:SetPoint("RIGHT", b.health, "RIGHT", -5, ns.db.powerText and 6 or 0)
	end
	if b.onResize then b.onResize(b, width, height) end
end

function ns.CreateUnit(name, parent, unit, style, auraSide)
	local ok, b = pcall(CreateFrame, "Button", name, parent, "SecureUnitButtonTemplate")
	if not ok or not b then b = CreateFrame("Button", name, parent) end
	b.unit = unit
	b.style = style
	b.auraSide = auraSide
	b.ranged = unit:find("^party") ~= nil or unit:find("^raid") ~= nil
	b.aggro = b.ranged or unit == "player" or unit == "pet"
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
		b.ptext = UI.Text(over, "GameFontHighlightSmall", "RIGHT", C.dim)
		b.ptext:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -5, 3)
	else
		health.left:SetPoint("LEFT", health, "LEFT", 4, 0)
	end
	health.left:SetPoint("RIGHT", health.right, "LEFT", -4, 0)

	b.leader = over:CreateTexture(nil, "OVERLAY")
	b.leader:SetSize(12, 12)
	b.leader:SetPoint("TOPLEFT", -3, 6)
	b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
	b.leader:Hide()

	b.loot = over:CreateTexture(nil, "OVERLAY")
	b.loot:SetSize(11, 11)
	b.loot:SetPoint("TOPLEFT", 9, 6)
	b.loot:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
	b.loot:Hide()

	b.hover = over:CreateTexture(nil, "ARTWORK")
	b.hover:SetAllPoints(body)
	b.hover:SetColorTexture(1, 1, 1, 0.08)
	b.hover:Hide()

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
		self.hover:Show()
		if not ns.db.tooltips then return end
		if GameTooltip_SetDefaultAnchor then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
		pcall(GameTooltip.SetUnit, GameTooltip, self.unit)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function(self)
		self.hover:Hide()
		GameTooltip:Hide()
	end)

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
unitEvent("UNIT_THREAT_SITUATION_UPDATE", ns.UpdateThreat)

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
ns:On("UNIT_HAPPINESS", function()
	ns.Each(ns.UpdateName, "pet")
	ns.Each(ns.UpdateHealth, "pet")
end)
ns:On("PARTY_LOOT_METHOD_CHANGED", function() ns.Each(ns.UpdateIcons) end)
ns:On("PLAYER_REGEN_ENABLED", function() ns.Each(ns.UpdateAuras) end)
ns:On("UNIT_CLASSIFICATION_CHANGED", function(unit) ns.Each(ns.UpdateName, unit) end)
ns:On("UNIT_FACTION", function(unit) ns.Each(ns.UpdateAll, unit) end)
ns:On("READY_CHECK", function() ns.Each(ns.UpdateIcons) end)
ns:On("READY_CHECK_CONFIRM", function() ns.Each(ns.UpdateIcons) end)
ns:On("READY_CHECK_FINISHED", function() ns.Each(ns.UpdateIcons) end)
