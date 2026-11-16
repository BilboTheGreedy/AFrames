local _, ns = ...
local UI = ns.UI

local GAP = 8
local RGAP = 2
local NAMES = {
	player = "AFramesPlayer", target = "AFramesTarget", tot = "AFramesTargetTarget", pet = "AFramesPet",
	focus = "AFramesFocus", party = "AFramesParty", raid = "AFramesRaid",
}
local SINGLE = {
	player = { unit = "player", style = "full", cond = "show" },
	target = { unit = "target", style = "full", cond = "[@target,exists] show; hide" },
	tot = { unit = "targettarget", style = "small", cond = "[@targettarget,exists] show; hide" },
	pet = { unit = "pet", style = "small", cond = "[@pet,exists] show; hide" },
	focus = { unit = "focus", style = "full", cond = "[@focus,exists] show; hide" },
}

local holders = {}
local singles = {}
local party, pets, raid, raidParty = {}, {}, {}, {}
local built = false

ns.holders = holders
ns.raid = raid

function ns.HasFocus()
	return FocusFrame ~= nil or FocusUnit ~= nil
end

local function drive(b, cond)
	if UnregisterStateDriver then UnregisterStateDriver(b, "visibility") end
	if not cond then
		b:Hide()
	elseif RegisterStateDriver then
		RegisterStateDriver(b, "visibility", cond)
	else
		b:Show()
	end
end

local function holder(key)
	local cfg = ns.db.units[key]
	local f = CreateFrame("Frame", NAMES[key], UIParent)
	f:SetSize(100, 30)
	UI.Movable(f, cfg)
	if ACore.RegisterMover then
		ACore.RegisterMover(f, cfg, nil, nil, function() return ns.db.units[key].on end)
		ACore.NameMover(f, "AFrames " .. ns.TITLES[key])
	end
	holders[key] = f
	return f
end

local function build()
	if built then return end
	built = true
	for _, key in ipairs({ "player", "target", "tot", "pet", "focus" }) do
		if key ~= "focus" or ns.HasFocus() then
			local def = SINGLE[key]
			local h = holder(key)
			local b = ns.CreateUnit(NAMES[key] .. "Unit", h, def.unit, def.style, "BELOW")
			b:SetPoint("TOPLEFT")
			b.poll = key == "tot"
			ns.Decorate(b, key)
			singles[key] = b
		end
	end
	ns.playerFrame, ns.targetFrame = singles.player, singles.target

	local p = holder("party")
	party[1] = ns.CreateUnit("AFramesPartyPlayer", p, "player", "full", "RIGHT")
	for i = 1, 4 do
		party[i + 1] = ns.CreateUnit("AFramesParty" .. i, p, "party" .. i, "full", "RIGHT")
		pets[i] = ns.CreateUnit("AFramesPartyPet" .. i, p, "partypet" .. i, "small", "BELOW")
	end

	local r = holder("raid")
	for i = 1, 40 do
		raid[i] = ns.CreateUnit("AFramesRaid" .. i, r, "raid" .. i, "raid", "INSIDE")
	end
	raidParty[1] = ns.CreateUnit("AFramesRaidParty0", r, "player", "raid", "INSIDE")
	for i = 1, 4 do
		raidParty[i + 1] = ns.CreateUnit("AFramesRaidParty" .. i, r, "party" .. i, "raid", "INSIDE")
	end
end

local hidden
local banished = {}

local function banish(name, hide)
	local f = _G[name]
	if not f then return end
	if hide then
		if banished[name] then return end
		if not hidden then
			hidden = CreateFrame("Frame")
			hidden:Hide()
		end
		local parent = f.GetParent and f:GetParent()
		banished[name] = parent or UIParent
		pcall(f.SetParent, f, hidden)
	elseif banished[name] then
		pcall(f.SetParent, f, banished[name])
		banished[name] = nil
	end
end

local BLIZZARD = {
	player = { "PlayerFrame" },
	target = { "TargetFrame", "ComboFrame" },
	focus = { "FocusFrame" },
	pet = { "PetFrame" },
	party = { "PartyFrame", "CompactPartyFrame", "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" },
	raid = { "CompactRaidFrameManager", "CompactRaidFrameContainer" },
}

local function blizzard()
	local db = ns.db
	local U = db.units
	for key, names in pairs(BLIZZARD) do
		local want = db.hideBlizzard and U[key].on
		if key == "raid" then want = want and U.raid.hideDefault end
		if key == "party" then want = db.hideBlizzard and (U.party.on or U.raid.forParty) end
		if key == "focus" and not singles.focus then want = false end
		for _, name in ipairs(names) do banish(name, want and true or false) end
	end
end

function ns.BlizzardHidden()
	return next(banished) ~= nil
end

function ns.Banished(name)
	return banished[name] ~= nil
end

local function raidSlots()
	local slots = {}
	local counts = {}
	for i = 1, 40 do
		local group
		if GetRaidRosterInfo then
			local ok, _, _, sub = pcall(GetRaidRosterInfo, i)
			if ok and not ACore.IsSecret(sub) and type(sub) == "number" and sub >= 1 and sub <= 8 then group = sub end
		end
		if not group then group = math.floor((i - 1) / 5) + 1 end
		local n = counts[group] or 0
		if n >= 5 then
			for g = 1, 8 do
				if (counts[g] or 0) < 5 then
					group = g
					n = counts[g] or 0
					break
				end
			end
		end
		counts[group] = n + 1
		slots[i] = { group, n }
	end
	return slots
end

local function layoutRaid()
	local U = ns.db.units
	local cfg = U.raid
	local w, h = cfg.w, cfg.h
	local r = holders.raid
	local slots = raidSlots()
	for i, b in ipairs(raid) do
		local s = slots[i]
		ns.Resize(b, w, h)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", r, "TOPLEFT", (s[1] - 1) * (w + RGAP), -s[2] * (h + RGAP))
		drive(b, cfg.on and ("[@raid" .. i .. ",exists] show; hide") or nil)
	end
	for i, b in ipairs(raidParty) do
		ns.Resize(b, w, h)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -(i - 1) * (h + RGAP))
		if not cfg.forParty then
			drive(b, nil)
		elseif i == 1 then
			drive(b, "[group:raid] hide; [group:party] show; hide")
		else
			drive(b, "[group:raid] hide; [@party" .. (i - 1) .. ",exists] show; hide")
		end
	end
	r:SetSize(8 * w + 7 * RGAP, 5 * h + 4 * RGAP)
end

local function apply()
	build()
	local db = ns.db
	local U = db.units
	for key, b in pairs(singles) do
		local cfg = U[key]
		ns.Resize(b, cfg.w, cfg.h)
		holders[key]:SetSize(cfg.w, cfg.h)
		drive(b, cfg.on and SINGLE[key].cond or nil)
	end

	local pdb = U.party
	local p = holders.party
	local pw, ph = pdb.w, pdb.h
	local inRaid = pdb.raid and "" or "[group:raid] hide; "
	local on = pdb.on and not U.raid.forParty
	local slot = 0
	for i, b in ipairs(party) do
		local show = on and (i > 1 or pdb.player)
		b.auraSide = pdb.horizontal and "BELOW" or "RIGHT"
		ns.Resize(b, pw, ph)
		b:ClearAllPoints()
		local pet = pets[i - 1]
		if show then
			if pdb.horizontal then
				b:SetPoint("TOPLEFT", p, "TOPLEFT", slot * (pw + GAP), 0)
			else
				b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -slot * (ph + GAP + (pdb.pets and 16 or 0)))
			end
			slot = slot + 1
			if i == 1 then
				drive(b, inRaid .. "[group] show; hide")
			else
				drive(b, inRaid .. "[@party" .. (i - 1) .. ",exists] show; hide")
			end
		else
			b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
			drive(b, nil)
		end
		if pet then
			ns.Resize(pet, math.floor(pw * 0.6), 14)
			pet:ClearAllPoints()
			pet:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
			drive(pet, show and pdb.pets and (inRaid .. "[@partypet" .. (i - 1) .. ",exists] show; hide") or nil)
		end
	end
	local n = math.max(1, slot)
	if pdb.horizontal then
		p:SetSize(n * pw + (n - 1) * GAP, ph)
	else
		p:SetSize(pw, n * ph + (n - 1) * GAP)
	end

	layoutRaid()
	for _, f in pairs(holders) do f:Restore() end
	blizzard()
	ns.Each(ns.UpdateAll)
end

function ns.Apply()
	if not ns.db then return false end
	return ns.Safe("apply", apply)
end

ns:Listen("LOGIN", function() ns.Apply() end)

ns:On("GROUP_ROSTER_UPDATE", function()
	if built and ns.db.units.raid.on then ns.Safe("raid", layoutRaid) end
end)

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + (dt or 0)
	if elapsed < 0.3 then return end
	elapsed = 0
	ns.Each(ns.UpdateRange)
	for _, b in ipairs(ns.buttons) do
		if b.poll and b:IsShown() then ns.UpdateAll(b) end
	end
end)
ns.ticker = ticker
