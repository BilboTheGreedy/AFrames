local _, ns = ...
local UI = ns.UI

local TEXTS = { "percent", "value", "deficit", "none" }
local AURAS = { 0.8, 1, 1.25, 1.5 }
local WIDTHS = {
	player = { 180, 200, 220, 240, 260 }, target = { 180, 200, 220, 240, 260 }, tot = { 90, 110, 130, 150 },
	pet = { 100, 120, 140, 160 }, focus = { 140, 170, 200, 220 }, party = { 140, 160, 176, 200, 220 },
	raid = { 60, 74, 88, 100 },
}
local HEIGHTS = {
	player = { 36, 46, 54, 62 }, target = { 36, 46, 54, 62 }, tot = { 22, 26, 32 }, pet = { 24, 28, 34 },
	focus = { 32, 38, 46 }, party = { 34, 40, 48 }, raid = { 30, 36, 44 },
}

local function cycle(list, current)
	for i, v in ipairs(list) do
		if v == current then return list[i % #list + 1] end
	end
	return list[1]
end

function ns.Options()
	local db = ns.db
	local U = db.units
	local function layout() ns.Apply() end
	local function look() ns.Each(ns.UpdateAll) end
	local list = {
		{ text = "Frames", title = true },
		{ text = "Move and resize frames", func = function() ACore.LayoutMode(true) end },
		UI.Check(U.player, "on", "Player", layout),
		UI.Check(U.target, "on", "Target", layout),
		UI.Check(U.tot, "on", "Target of target", layout),
		UI.Check(U.pet, "on", "Pet", layout),
	}
	if ns.HasFocus() then list[#list + 1] = UI.Check(U.focus, "on", "Focus", layout) end
	local more = {
		UI.Check(U.party, "on", "Party", layout),
		UI.Check(U.raid, "on", "Raid", layout),
		{
			text = "Hide the default frames", checked = db.hideBlizzard,
			func = function()
				db.hideBlizzard = not db.hideBlizzard
				ns.Apply()
			end,
		},
		{ text = "Player and target", title = true },
		UI.Check(U.player, "portrait", "Player portrait", look),
		UI.Check(U.player, "icons", "Resting, combat and PvP marks", look),
		UI.Check(U.player, "mana", "Druid mana bar while shapeshifted", look),
		UI.Check(U.target, "portrait", "Target portrait", look),
		UI.Check(U.target, "castbar", "Target cast bar (not used when ACast shows one)", look),
		UI.Check(U.target, "combo", "Combo points on the target", look),
		{ text = "Party and raid", title = true },
		UI.Check(U.party, "player", "Show me in the party", layout),
		UI.Check(U.party, "pets", "Party pets", layout),
		UI.Check(U.party, "horizontal", "Party side by side", layout),
		UI.Check(U.party, "raid", "Keep party frames in a raid", layout),
		UI.Check(U.raid, "forParty", "Use the raid grid for a party", layout),
		UI.Check(U.raid, "hideDefault", "Hide the default raid frames", layout),
		{ text = "Look", title = true },
		UI.Check(db, "classColor", "Class colours", look),
		UI.Check(db, "debuffs", "Debuffs", look),
		UI.Check(db, "buffs", "Buffs", look),
		UI.Check(db, "dispelMine", "Party and raid border only for debuffs I can remove", look),
		UI.Check(db, "threat", "Red border on aggro", look),
		UI.Check(db, "powerText", "Power text", layout),
		UI.Check(db, "range", "Fade when out of range", look),
		UI.Check(db, "tooltips", "Tooltips", look),
		{
			text = "Buff and debuff size: " .. math.floor((db.auraScale or 1) * 100 + 0.5) .. "%",
			func = function()
				db.auraScale = cycle(AURAS, db.auraScale or 1)
				ns.Each(ns.UpdateAuras)
			end,
		},
		{
			text = "Health text: " .. db.healthText,
			func = function()
				db.healthText = cycle(TEXTS, db.healthText)
				ns.Each(ns.UpdateHealth)
			end,
		},
		{ text = "Width and height (click to change)", title = true },
	}
	for _, e in ipairs(more) do list[#list + 1] = e end
	for _, key in ipairs(ns.KEYS) do
		if key ~= "focus" or ns.HasFocus() then
			local cfg = U[key]
			list[#list + 1] = {
				text = ns.TITLES[key] .. " width: " .. cfg.w,
				func = function()
					cfg.w = cycle(WIDTHS[key], cfg.w)
					ns.Apply()
				end,
			}
			list[#list + 1] = {
				text = ns.TITLES[key] .. " height: " .. cfg.h,
				func = function()
					cfg.h = cycle(HEIGHTS[key], cfg.h)
					ns.Apply()
				end,
			}
		end
	end
	list[#list + 1] = { text = "Click casting (" .. tostring(ns.playerClass) .. ", empty name clears)", title = true }
	local clicks = ns.Clicks()
	for i, c in ipairs(ns.CLICKS) do
		local spell = clicks[c[1] .. c[2]]
		list[#list + 1] = {
			text = c[3] .. ": " .. (spell or "not set"),
			func = function()
				UI.Prompt("Spell for " .. c[3]:lower(), spell or "", function(text) ns.SetClick(i, text) end)
			end,
		}
	end
	list[#list + 1] = { text = "Layout changes wait until you leave combat", title = true }
	return list
end
