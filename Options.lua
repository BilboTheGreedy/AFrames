local _, ns = ...
local UI = ns.UI
local C = UI.colors

local frame
local TEXTS = { "percent", "value", "deficit", "none" }
local SCALES = { 0.8, 0.9, 1, 1.1, 1.2, 1.35 }

local function cycle(list, current)
	for i, v in ipairs(list) do
		if v == current or (type(v) == "number" and math.abs(v - (current or 1)) < 0.01) then
			return list[i % #list + 1]
		end
	end
	return list[1]
end

local function entries()
	local db = ns.db
	local function flag(text, t, key, layout)
		return {
			text = text, checked = t[key],
			func = function()
				t[key] = not t[key]
				if layout then ns.Apply() else ns.Each(ns.UpdateAll) end
			end,
		}
	end
	local list = {
		{ text = "Frames", title = true },
		{ text = "Unlock to move", checked = ns.unlocked, func = function() ns.SetUnlocked(not ns.unlocked) end },
		flag("Party frames", db.party, "enabled", true),
		flag("Show me in the party", db.party, "player", true),
		flag("Keep party frames in a raid", db.party, "raid", true),
		flag("Party side by side", db.party, "horizontal", true),
		flag("Player frame", db.player, "enabled", true),
		flag("Target frame", db.target, "enabled", true),
		{
			text = "Hide the default frames", checked = db.hideBlizzard,
			func = function()
				db.hideBlizzard = not db.hideBlizzard
				if db.hideBlizzard then
					ns.Apply()
				elseif ns.BlizzardHidden() then
					ns.Print("/reload to bring the default frames back")
				end
			end,
		},
		{ text = "Look", title = true },
		flag("Class colours", db, "classColor"),
		flag("Debuffs", db, "debuffs"),
		flag("My buffs", db, "buffs"),
		flag("Fade when out of range", db, "range"),
		flag("Tooltips", db, "tooltips"),
		{
			text = "Health text", value = db.healthText,
			func = function()
				db.healthText = cycle(TEXTS, db.healthText)
				ns.Each(ns.UpdateHealth)
			end,
		},
		{
			text = "Size", value = math.floor((db.party.scale or 1) * 100 + 0.5) .. "%",
			func = function()
				local s = cycle(SCALES, db.party.scale)
				db.party.scale, db.player.scale, db.target.scale = s, s, s
				ns.Apply()
			end,
		},
	}
	return list
end

local function createRow(list)
	local row = CreateFrame("Button", nil, list)
	row.hl = UI.Fill(row, C.hover, "HIGHLIGHT")
	row.check = UI.Text(row, "GameFontHighlightSmall", "CENTER", C.accent)
	row.check:SetPoint("LEFT", 8, 0)
	row.check:SetWidth(12)
	row.value = UI.Text(row, "GameFontHighlightSmall", "RIGHT", C.accent)
	row.value:SetPoint("RIGHT", -8, 0)
	row.label = UI.Text(row, "GameFontHighlightSmall")
	row.label:SetPoint("LEFT", 26, 0)
	row:SetScript("OnClick", function(self)
		local e = self.data
		if not e or e.title or not e.func then return end
		e.func()
		ns.RefreshOptions()
	end)
	return row
end

local function updateRow(row, e)
	row.label:SetText(e.text)
	row.check:SetText(e.checked and "+" or "")
	row.value:SetText(e.value or "")
	local c = e.title and C.dim or C.text
	row.label:SetTextColor(c[1], c[2], c[3])
	row.label:ClearAllPoints()
	row.label:SetPoint("LEFT", e.title and 10 or 26, 0)
	row.hl:SetShown(not e.title)
end

function ns.RefreshOptions()
	if not frame or not frame:IsShown() then return end
	frame.list:SetData(entries(), true)
end

local function build()
	frame = UI.Window("AFramesOptions", "AFrames", 290, 34 + 18 * 22 + 30, ns.db.window)
	local list = UI.List(frame.body, 22, createRow, updateRow)
	list:SetPoint("TOPLEFT", 0, -4)
	list:SetPoint("BOTTOMRIGHT", 0, 26)
	frame.list = list
	local hint = UI.Text(frame.body, "GameFontDisableSmall", "LEFT", C.dim)
	hint:SetPoint("BOTTOMLEFT", 10, 8)
	hint:SetText("Layout changes wait until you leave combat")
end

function ns.ToggleOptions()
	if not frame then build() end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		ns.RefreshOptions()
	end
end

ns:Listen("CHANGED", function() ns.RefreshOptions() end)
