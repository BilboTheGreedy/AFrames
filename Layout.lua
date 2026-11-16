local _, ns = ...
local UI = ns.UI
local C = UI.colors

local PW, PH = 176, 40
local UW, UH = 220, 46
local GAP = 8
local AURAS = 26

local holders = {}
local party = {}
local built = false

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

local function holder(key, label)
	local f = CreateFrame("Frame", "AFrames" .. label, UIParent)
	f:SetSize(UW, UH)
	UI.Movable(f, ns.db[key])
	local handle = CreateFrame("Frame", nil, f)
	handle:SetAllPoints(f)
	handle:SetFrameStrata("DIALOG")
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	UI.Fill(handle, { C.accent[1], C.accent[2], C.accent[3], 0.22 })
	UI.Border(handle, C.accent)
	handle.label = UI.Text(handle, "GameFontNormal", "CENTER", C.accent)
	handle.label:SetPoint("CENTER")
	handle.label:SetText(label .. " - drag to move")
	handle:SetScript("OnDragStart", function()
		if ns.InCombat() then return end
		f.dragging = true
		f:StartDrag()
	end)
	handle:SetScript("OnDragStop", function()
		if not f.dragging then return end
		f.dragging = false
		f:StopDrag()
	end)
	handle:Hide()
	f.handle = handle
	holders[key] = f
	return f
end

local function build()
	if built then return end
	built = true
	local p = holder("party", "Party")
	party[1] = ns.CreateUnit("AFramesPartyPlayer", p, "player", PW, PH, "RIGHT")
	for i = 1, 4 do
		party[i + 1] = ns.CreateUnit("AFramesParty" .. i, p, "party" .. i, PW, PH, "RIGHT")
	end
	local pl = holder("player", "Player")
	ns.playerFrame = ns.CreateUnit("AFramesPlayerUnit", pl, "player", UW, UH, "BELOW")
	ns.playerFrame:SetPoint("TOPLEFT")
	local tg = holder("target", "Target")
	ns.targetFrame = ns.CreateUnit("AFramesTargetUnit", tg, "target", UW, UH, "BELOW")
	ns.targetFrame:SetPoint("TOPLEFT")
end

local hidden
local banished = {}
local function banish(name, keepEvents)
	local f = _G[name]
	if not f or banished[name] then return end
	banished[name] = true
	if not hidden then
		hidden = CreateFrame("Frame")
		hidden:Hide()
	end
	if not keepEvents then pcall(f.UnregisterAllEvents, f) end
	pcall(f.Hide, f)
	pcall(f.SetParent, f, hidden)
end

local function hideBlizzard()
	local db = ns.db
	if not db.hideBlizzard then return end
	if db.party.enabled then
		banish("PartyFrame")
		banish("CompactPartyFrame")
		for i = 1, 4 do banish("PartyMemberFrame" .. i) end
	end
	if db.player.enabled then banish("PlayerFrame", true) end
	if db.target.enabled then banish("TargetFrame") end
end

function ns.BlizzardHidden()
	return next(banished) ~= nil
end

local function apply()
	build()
	local db = ns.db
	local pdb = db.party
	local p = holders.party
	local raid = pdb.raid and "" or "[group:raid] hide; "
	local slot = 0
	for i, b in ipairs(party) do
		local on = pdb.enabled and (i > 1 or pdb.player)
		b.auraSide = pdb.horizontal and "BELOW" or "RIGHT"
		b:ClearAllPoints()
		if on then
			if pdb.horizontal then
				b:SetPoint("TOPLEFT", p, "TOPLEFT", slot * (PW + GAP), 0)
			else
				b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -slot * (PH + GAP))
			end
			slot = slot + 1
			if i == 1 then
				drive(b, raid .. "[group] show; hide")
			else
				drive(b, raid .. "[@party" .. (i - 1) .. ",exists] show; hide")
			end
		else
			b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
			drive(b, nil)
		end
	end
	local n = math.max(1, slot)
	if pdb.horizontal then
		p:SetSize(n * PW + (n - 1) * GAP, PH)
	else
		p:SetSize(PW, n * PH + (n - 1) * GAP)
	end
	drive(ns.playerFrame, db.player.enabled and "show" or nil)
	drive(ns.targetFrame, db.target.enabled and "[@target,exists] show; hide" or nil)
	for key, f in pairs(holders) do
		f:Restore()
		f.handle:SetShown(ns.unlocked and db[key].enabled)
	end
	hideBlizzard()
	ns.Each(ns.UpdateAll)
end

function ns.Apply()
	if not ns.db then return false end
	return ns.Safe("apply", apply)
end

function ns.SetUnlocked(on)
	if on and ns.InCombat() then
		ns.Print("cannot move frames in combat")
		return
	end
	ns.unlocked = on and true or false
	for key, f in pairs(holders) do
		if f.dragging then
			f.dragging = false
			f:StopDrag()
		end
		f.handle:SetShown(ns.unlocked and ns.db[key].enabled)
	end
	if ns.unlocked then ns.Print("drag the highlighted boxes, then /aframes lock") end
	ns:Fire("CHANGED")
end

ns:Listen("LOGIN", function() ns.Apply() end)

ns:On("PLAYER_REGEN_DISABLED", function()
	if ns.unlocked then ns.SetUnlocked(false) end
end)

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + (dt or 0)
	if elapsed < 0.3 then return end
	elapsed = 0
	ns.Each(ns.UpdateRange)
end)
ns.ticker = ticker
