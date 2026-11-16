local ADDON, ns = ...

local defaults = {
	hideBlizzard = true,
	classColor = true,
	healthText = "percent",
	debuffs = true,
	buffs = true,
	range = true,
	tooltips = true,
	window = {},
	party = { enabled = true, player = false, raid = false, horizontal = false, scale = 1, default = { "TOPLEFT", "TOPLEFT", 24, -190 } },
	player = { enabled = false, scale = 1, default = { "CENTER", "CENTER", -270, -150 } },
	target = { enabled = false, scale = 1, default = { "CENTER", "CENTER", 270, -150 } },
}

ACore.New(ADDON, ns, { db = "AFramesDB", defaults = defaults })

ns.unlocked = false
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

ACore.Register({
	name = "AFrames",
	title = "AFrames",
	slash = "/aframes",
	desc = "party, player and target frames",
	toggle = function() ns.ToggleOptions() end,
})

SLASH_AFRAMES1 = "/aframes"
SLASH_AFRAMES2 = "/af"
SlashCmdList["AFRAMES"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" then
		ns.ToggleOptions()
	elseif msg == "unlock" or msg == "move" then
		ns.SetUnlocked(true)
	elseif msg == "lock" then
		ns.SetUnlocked(false)
	elseif msg == "reset" then
		for _, key in ipairs({ "party", "player", "target" }) do
			ns.db[key].pos = nil
			ns.db[key].scale = 1
		end
		ns.Apply()
	else
		ns.Print("/aframes, /aframes unlock, /aframes lock, /aframes reset")
	end
end
