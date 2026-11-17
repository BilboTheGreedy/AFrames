local ADDON, ns = ...

local defaults = {
	hideBlizzard = true,
	classColor = true,
	healthText = "percent",
	debuffs = true,
	buffs = true,
	range = true,
	tooltips = true,
	threat = true,
	powerText = false,
	dispelMine = false,
	auraScale = 1,
	clicks = {},
	units = {
		player = { on = true, w = 220, h = 46, portrait = false, icons = true, mana = true, scale = 1 },
		target = { on = true, w = 220, h = 46, portrait = false, castbar = true, combo = true, auras = true, scale = 1 },
		tot = { on = true, w = 110, h = 26, scale = 1 },
		pet = { on = true, w = 120, h = 28, scale = 1 },
		focus = { on = true, w = 170, h = 38, scale = 1 },
		party = { on = true, player = false, raid = false, horizontal = false, pets = false, w = 176, h = 40, scale = 1 },
		raid = { on = true, forParty = false, hideDefault = true, w = 74, h = 36, scale = 1 },
	},
}

ns.POS = {
	player = { "CENTER", "CENTER", -270, -170 },
	target = { "CENTER", "CENTER", 270, -170 },
	tot = { "CENTER", "CENTER", 440, -180 },
	pet = { "CENTER", "CENTER", -320, -226 },
	focus = { "CENTER", "CENTER", -460, -40 },
	party = { "TOPLEFT", "TOPLEFT", 24, -190 },
	raid = { "TOPLEFT", "TOPLEFT", 24, -160 },
}

ns.KEYS = { "player", "target", "tot", "pet", "focus", "party", "raid" }
ns.TITLES = {
	player = "Player", target = "Target", tot = "Target of target", pet = "Pet", focus = "Focus",
	party = "Party", raid = "Raid",
}

ACore.New(ADDON, ns, { db = "AFramesDB", defaults = defaults, profile = true })

ns.queue = {}

function ns.InCombat()
	return InCombatLockdown and InCombatLockdown() and true or false
end

function ns.Safe(key, fn)
	if ns.InCombat() then
		ns.queue[key] = fn
		return false
	end
	fn()
	return true
end

ns:On("PLAYER_REGEN_ENABLED", function()
	local q = ns.queue
	ns.queue = {}
	for _, fn in pairs(q) do fn() end
end)

function ns.HasACast()
	local sv = ACastDB
	if sv == nil then
		local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
		if not loaded then return false end
		local ok, v = pcall(loaded, "ACast")
		return ok and v and true or false
	end
	local prof = type(sv) == "table" and type(sv.profiles) == "table" and sv.profiles[ACore.Profile()]
	if type(prof) == "table" and type(prof.target) == "table" and prof.target.show == false then return false end
	return true
end

ns.CLICKS = {
	{ "shift-", 1, "Shift + left click" }, { "ctrl-", 1, "Ctrl + left click" }, { "alt-", 1, "Alt + left click" },
	{ "shift-", 2, "Shift + right click" }, { "ctrl-", 2, "Ctrl + right click" }, { "alt-", 2, "Alt + right click" },
	{ "", 3, "Middle click" },
}

function ns.Clicks()
	local all = ns.db.clicks
	local class = ns.playerClass or "?"
	if type(all[class]) ~= "table" then all[class] = {} end
	return all[class]
end

function ns.SetClick(index, spell)
	local c = ns.CLICKS[index]
	if not c then return end
	spell = tostring(spell or ""):gsub("^%s+", ""):gsub("%s+$", "")
	ns.Clicks()[c[1] .. c[2]] = spell ~= "" and spell or nil
	ns.Apply()
end

function ns.ToggleOptions()
	if ACore.OpenPanel then
		ACore.OpenPanel("AFrames")
	else
		ns.UI.Menu(UIParent, ns.Options())
	end
end

ACore.Register({
	name = "AFrames",
	title = "AFrames",
	slash = "/aframes",
	desc = "player, target, pet, focus, party and raid frames",
	toggle = function() ns.ToggleOptions() end,
	options = function() return ns.Options() end,
})

SLASH_AFRAMES1 = "/aframes"
SLASH_AFRAMES2 = "/af"
SlashCmdList["AFRAMES"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" then
		ns.ToggleOptions()
	elseif msg == "unlock" or msg == "move" then
		if not ACore.LayoutMode(true) then ns.Print("cannot move frames in combat") end
	elseif msg == "auras" then
		ns.AuraReport("target")
	elseif msg == "lock" then
		ACore.LayoutMode(false)
	elseif msg == "reset" then
		for _, key in ipairs(ns.KEYS) do
			ns.db.units[key].pos = nil
			ns.db.units[key].scale = 1
		end
		ns.Apply()
	else
		ns.Print("/aframes, /aframes unlock, /aframes lock, /aframes reset, /aframes auras")
	end
end
