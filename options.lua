local _, fPB = ...
local L = fPB.L

local db = {}
local UpdateAllNameplates = fPB.UpdateAllNameplates

local 	GetSpellInfo, tonumber, pairs, table_sort, table_insert =
		GetSpellInfo, tonumber, pairs, table.sort, table.insert
local	DISABLE = DISABLE
local chatColor = fPB.chatColor
local linkColor = fPB.linkColor
local strfind = string.find

local tooltip = CreateFrame("GameTooltip", "fPBScanSpellDescTooltip", UIParent, "GameTooltipTemplate")
tooltip:Show()
tooltip:SetOwner(UIParent, "ANCHOR_NONE")


local minIconSize = 10
local maxIconSize = 100
local minTextSize = 6
local maxTextSize = 30
local minInterval = 0
local maxInterval = 80

local classIcons = {
    ["DEATHKNIGHT"] = 135771,
    ["DEMONHUNTER"] = 1260827,
    ["DRUID"] = 625999,
    ["EVOKER"] = 4574311,
    ["HUNTER"] = 626000,
    ["MAGE"] = 626001,
    ["MONK"] = 626002,
    ["PALADIN"] = 626003,
    ["PRIEST"] = 626004,
    ["ROGUE"] = 626005,
    ["SHAMAN"] = 626006,
    ["WARLOCK"] = 626007,
    ["WARRIOR"] = 626008,
}

local hexFontColors = {
	["Racials"] = "FF666666",
    ["PvP"] = "FFB9B9B9",
    ["PvE"] = "FF00FE44",
    ["logo"] = "ffff7a00",
}

local customIcons = {
    [L["Eating/Drinking"]] = 134062,
    ["?"] = 134400,
    ["Cogwheel"] = 136243,
	["Racials"] = 136187,
	["PvP"] = 132485,
	["PvE"] = 463447,
}

for class, val in pairs(RAID_CLASS_COLORS) do
	hexFontColors[class] = val.colorStr
end

local function GetIconString(icon, iconSize)
    local size = iconSize or 0
    local ltTexel = 0.08 * 256
    local rbTexel = 0.92 * 256

    if not icon then
        icon = customIcons["?"]
    end

    return format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", icon, size, size, ltTexel, rbTexel, ltTexel, rbTexel)
end

local function Colorize(text, color)
    if not text then return end
    local hexColor = hexFontColors[color] or hexFontColors["blizzardFont"]
    return "|c" .. hexColor .. text .. "|r"
end

local function CheckSort()
	local i = 1
	while db.sortMode[i] do
		if db.sortMode[i] ~= "disable" then
			return true
		end
		i = i+1
	end
	return false
end

local color
local iconTexture
local TextureStringCache = {}
local description
local function TextureString(spellId, IconId)
	if not tonumber(spellId) then
		return "\124TInterface\\Icons\\Inv_misc_questionmark:0\124t"
	else
		if IconId then 
			iconTexture = IconId
		else
			_,_,iconTexture =  GetSpellInfo(spellId)
		end
		if iconTexture then
			iconTexture = "\124T"..iconTexture..":0\124t"
			return iconTexture
		else
			return "\124TInterface\\Icons\\Inv_misc_questionmark:0\124t"
		end
	end
end

local function cmp_col1(a, b)
	if (a and b) then
		local Spells = db.Spells
		a = tostring(Spells[a].class or a)
		b = tostring(Spells[b].class or b)
 		return a < b
	end
end

local function cmp_col1_col2(a, b)
	if (a and b) then
		local Spells = db.Spells
		a1 = tostring(Spells[a].class or a)
		b1 = tostring(Spells[b].class or b)
		a2 = tostring(Spells[a].scale or a)
		b2 = tostring(Spells[b].scale or b)
	 if a1 < b1 then return true end
	 if a1 > b1 then return false end
		 return a2 > b2
	 end
end

local function cmp_col1_col2_col3(a, b)
	if (a and b ) then
		local Spells = db.Spells
		a1 = tostring(Spells[a].class or a)
		b1 = tostring(Spells[b].class or b)
		a2 = tostring(Spells[a].scale or a)
		b2 = tostring(Spells[b].scale or b)
		a3 = tostring(Spells[a].name or a)
		b3 = tostring(Spells[b].name or b)
	 if a1 < b1 then return true end
	 if a1 > b1 then return false end
	 if a2 > b2 then return true end
	 if a2 < b2 then return false end
		 return a3 < b3
	 end
end

local newNPCName

fPB.NPCTable = {
	name = L["Specific NPCs"],
	type = "group",
	childGroups = "tree",
	order = 1.1,
	args = {
		addSpell = {
			order = 1,
			type = "input",
			name = L["Add new NPC to list (All Changes May Require a Reload or for you to Spin your Camera"],
			desc = L["Enter NPC ID or name (case sensitive)\nand press OK"],
			set = function(info, value)
				if value then
					local npc = true
					local spellId = tonumber(value)
					newNPCName = value
					fPB.AddNewSpell(newNPCName, npc)
				end
			end,
			get = function(info)
				return newNPCName
			end,
		},
		blank = {
			order = 2,
			type = "description",
			name = "",
			width = "normal",
		},

		-- fills up with BuildSpellList()
	},
}




function fPB.BuildNPCList()
	local spellTable = fPB.NPCTable.args
	for item in pairs(spellTable) do
		if item ~= "addSpell" and item ~= "blank" and item ~= "showspellId" then
			spellTable[item] = nil
		end
	end
	local spellList = {}
	local Spells = db.Spells
	for spell in pairs(Spells) do
		if db.Spells[spell].spellTypeNPC then
			table_insert(spellList, spell)
		end
	end
	table_sort(spellList, cmp_col1)
	table_sort(spellList, cmp_col1_col2)
	table_sort(spellList, cmp_col1_col2_col3)
	for i = 1, #spellList do
		local s = spellList[i]
		local Spell = Spells[s]
		local name = Spell.name and Spell.name
		local spellId = Spell.spellId

		if Spell.DEATHKNIGHT then
			local hexColor = hexFontColors["DEATHKNIGHT"]
			color = "|c" .. hexColor
		elseif	Spell.DEMONHUNTER then
			local hexColor = hexFontColors["DEMONHUNTER"]
			color = "|c" .. hexColor
		elseif	Spell.DRUID then
			local hexColor = hexFontColors["DRUID"]
			color = "|c" .. hexColor
		elseif	Spell.EVOKER then
			local hexColor = hexFontColors["EVOKER"]
			color = "|c" .. hexColor
		elseif	Spell.HUNTER then
			local hexColor = hexFontColors["HUNTER"]
			color = "|c" .. hexColor
		elseif	Spell.MAGE then
			local hexColor = hexFontColors["MAGE"]
			color = "|c" .. hexColor
		elseif	Spell.MONK then
			local hexColor = hexFontColors["MONK"]
			color = "|c" .. hexColor
		elseif	Spell.PALADIN then
			local hexColor = hexFontColors["PALADIN"]
			color = "|c" .. hexColor
		elseif	Spell.PRIEST then
			local hexColor = hexFontColors["PRIEST"]
			color = "|c" .. hexColor
		elseif	Spell.ROGUE then
			local hexColor = hexFontColors["ROGUE"]
			color = "|c" .. hexColor
		elseif	Spell.SHAMAN then
			local hexColor = hexFontColors["SHAMAN"]
			color = "|c" .. hexColor
		elseif	Spell.WARLOCK then
			local hexColor = hexFontColors["WARLOCK"]
			color = "|c" .. hexColor
		elseif	Spell.WARRIOR then
			local hexColor = hexFontColors["WARRIOR"]
			color = "|c" .. hexColor
		elseif	Spell.Racials then
			local hexColor = hexFontColors["Racials"]
			color = "|c" .. hexColor
		elseif	Spell.PvP then
			local hexColor = hexFontColors["PvP"]
			color = "|c" .. hexColor
		elseif	Spell.PvE then
			local hexColor = hexFontColors["PvE"]
			color = "|c" .. hexColor
		else
			color = "|cFF00FF00" --green
		end

		if Spell.spellId then
			iconTexture = "\124T"..Spell.spellId ..":0\124t"
		else
			iconTexture = TextureString(spellId)
		end
		spellDesc = L["NPC ID"]

		local red
		local glw

		if Spell.RedifEnemy then
			local color = "|c" .."FF822323"
			red = color.."r"
		end
		if Spell.IconGlow then
			local color = "|c" .."FFEAD516"
			glw = color.."g"
		end


		local buildName = (Spell.scale or "1").." ".. iconTexture..(red or "")..(glw or "").." "..color..name

		buildName = buildName.."|r"


		spellTable[tostring(s)] = {
			name = buildName,
			desc = spellDesc,
			type = "group",
			order = 10 + i,
			get = function(info)
				local key = info[#info]
				local id = info[#info-1]
				return db.Spells[id][key]
			end,
			set = function(info, value)
				local key = info[#info]
				local id = info[#info-1]
				db.Spells[id][key] = value
				fPB.BuildNPCList()
				UpdateAllNameplates()
			end,
			args = {
				blank0 = {
					order = 1,
					type = "description",
					name = "All Changes May Require a Reload or for you to Spin your Camera",
				},
				scale = {
					order = 1,
					name = L["Icon scale"],
					desc = L["Icon scale (Setting Will Adjust Next Time NPC is Seen)"],
					type = "range",
					min = 0.1,
					max = 5,
					softMin = 0.5,
					softMax  = 3,
					step = 0.01,
					bigStep = 0.1,
				},
				durationSize = {
					order = 4,
					name = L["Duration font size"],
					desc = L["Duration font size (Setting Will Adjust Next Time NPC is Seen)"],
					type = "range",
					min = minTextSize,
					max = maxTextSize,
					step = 1,
				},
				durationCLEU = {
					order = 4.5,
					name = L["Duration uptime"],
					desc = L["Duration For NPC Spawn Timer Such as Infernals (Guardians & Minors) or 0 for NPC & Pets"],
					type = "range",
					min = 0,
					max = 60,
					step = 1,
				},
				spellId = {
					order = 5,
					type = "input",
					name = L["Icon ID"],
					get = function(info)
						return Spell.spellId and tostring(Spell.spellId) or L["No spell ID"]
					end,
					set = function(info, value)
						if value then
							local spellId = tonumber(value)
							db.Spells[s].spellId = spellId
							DEFAULT_CHAT_FRAME:AddMessage(chatColor..L[" Icon changed "].."|r"..(db.Spells[s].spellId  or "nil")..chatColor.." -> |r"..spellId)
							UpdateAllNameplates(true)
							fPB.BuildNPCList()
						end
					end,
				},
				blank = {
					order = 2,
					type = "description",
					name = "",
					width = "normal",
				},
				removeSpell = {
					order = 7,
					type = "execute",
					name = L["Remove spell"],
					confirm = true,
					func = function(info)
						fPB.RemoveSpell(s)
					end,
				},
				break2 = {
					order = 7.5,
					type = "header",
					name = L["Icon Settings"],
				},
				IconGlow= {
					order = 8,
					type = "toggle",
					name = L["Glow"],
					desc = L["Gives the icon a Glow"],
				},
				break3 = {
					order = 13,
					type = "header",
					name = L["Select if the NPC Belongs to a Class for Sorting"],
				},
				DEATHKNIGHT = {
					order = 14,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["DEATHKNIGHT"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"], "DEATHKNIGHT")),
					get = function(info)
						return Spell.DEATHKNIGHT
					end,
					set = function(info, value)
						if value then 
							Spell.class = "DEATHKNIGHT"
							Spell.DEATHKNIGHT = true
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
					
					end,
				},
				DEMONHUNTER = {
					order = 15,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["DEMONHUNTER"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["DEMONHUNTER"], "DEMONHUNTER")),
					get = function(info)
						return Spell.DEMONHUNTER
					end,
					set = function(info, value)
						if value then 
							Spell.class = "DEMONHUNTER"
							Spell.DEMONHUNTER = true
							Spell.DEATHKNIGHT = false

							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
					
					end,
				},
				DRUID = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["DRUID"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["DRUID"], "DRUID")),
					get = function(info)
						return Spell.DRUID
					end,
					set = function(info, value)
						if value then 
							Spell.class = "DRUID"
							Spell.DRUID = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				EVOKER = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["EVOKER"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["EVOKER"], "EVOKER")),
					get = function(info)
						return Spell.EVOKER
					end,
					set = function(info, value)
						if value then 
							Spell.class = "EVOKER"
							Spell.EVOKER = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				HUNTER = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["HUNTER"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["HUNTER"], "HUNTER")),
					get = function(info)
						return Spell.HUNTER
					end,
					set = function(info, value)
						if value then 
							Spell.class = "HUNTER"
							Spell.HUNTER = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				MAGE = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["MAGE"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["MAGE"], "MAGE")),
					get = function(info)
						return Spell.MAGE
					end,
					set = function(info, value)
						if value then 
							Spell.class = "MAGE"
							Spell.MAGE = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				MONK = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["MONK"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["MONK"], "MONK")),
					get = function(info)
						return Spell.MONK
					end,
					set = function(info, value)
						if value then 
							Spell.class = "MONK"
							Spell.MONK = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				PALADIN = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["PALADIN"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["PALADIN"], "PALADIN")),
					get = function(info)
						return Spell.PALADIN
					end,
					set = function(info, value)
						if value then 
							Spell.class = "PALADIN"
							Spell.PALADIN = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				PRIEST = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["PRIEST"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["PRIEST"], "PRIEST")),
					get = function(info)
						return Spell.PRIEST
					end,
					set = function(info, value)
						if value then 
							Spell.class = "PRIEST"
							Spell.PRIEST = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
					
					end,
				},
				ROGUE = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["ROGUE"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["ROGUE"], "ROGUE")),
					get = function(info)
						return Spell.ROGUE
					end,
					set = function(info, value)
						if value then 
							Spell.class = "ROGUE"
							Spell.ROGUE = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				SHAMAN = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["SHAMAN"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["SHAMAN"], "SHAMAN")),
					get = function(info)
						return Spell.SHAMAN
					end,
					set = function(info, value)
						if value then 
							Spell.class = "SHAMAN"
							Spell.SHAMAN = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				WARLOCK = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["WARLOCK"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["WARLOCK"], "WARLOCK")),
					get = function(info)
						return Spell.WARLOCK
					end,
					set = function(info, value)
						if value then 
							Spell.class = "WARLOCK"
							Spell.WARLOCK = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildNPCList()
						
					end,
				},
				WARRIOR = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["WARRIOR"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["WARRIOR"], "WARRIOR")),
					get = function(info)
						return Spell.WARRIOR
					end,
					set = function(info, value)
						if value then 
							Spell.class = "WARRIOR"
							Spell.WARRIOR = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							
							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildNPCList()
						
					end,
				},
				Racials = {
					order = 21,
					type = "toggle",
					name = format("%s %s",GetIconString(customIcons["Racials"], 15), Colorize("Racials", "Racials")),
					get = function(info)
						return Spell.Racials
					end,
					set = function(info, value)
						if value then 
							Spell.class = "xRacials"
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = true
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildNPCList()
						
					end,
				},
				PvP = {
					order = 22,
					type = "toggle",
					name = format("%s %s",GetIconString(customIcons["PvP"], 15), Colorize("PvP", "PvP")),
					get = function(info)
						return Spell.PvP
					end,
					set = function(info, value)
						if value then 
							Spell.class = "yPvP"
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = true
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildNPCList()
						
					end,
				},
				PvE = {
					order = 23,
					type = "toggle",
					name = format("%s %s",GetIconString(customIcons["PvE"], 15), Colorize("PvE", "PvE")),
					get = function(info)
						return Spell.PvE
					end,
					set = function(info, value)
						if value then 
							Spell.class = "zPvE"
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = true
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildNPCList()
						
					end,
				},
			},
		}
	end
end

local newSpellName

fPB.SpellsTable = {
	name = L["Specific Spells"],
	type = "group",
	childGroups = "tree",
	order = 1,
	args = {
		addSpell = {
			order = 1,
			type = "input",
			name = L["Add new spell to list"],
			desc = L["Enter spell ID or name (case sensitive)\nand press OK"],
			set = function(info, value)
				if value then
					local spellId = tonumber(value)
					if spellId then
						local spellName = GetSpellInfo(spellId)
						if spellName then
							newSpellName = spellName
							fPB.AddNewSpell(spellId)
						end
					else
						newSpellName = value
						fPB.AddNewSpell(newSpellName)
					end
				end
			end,
			get = function(info)
				return newSpellName
			end,
		},
		blank = {
			order = 2,
			type = "description",
			name = "",
			width = "normal",
		},

		-- fills up with BuildSpellList()
	},
}

function fPB.BuildSpellList()
	local spellTable = fPB.SpellsTable.args
	for item in pairs(spellTable) do
		if item ~= "addSpell" and item ~= "blank" and item ~= "showspellId" then
			spellTable[item] = nil
		end
	end
	local spellList = {}
	local Spells = db.Spells
	local Ignored = db.ignoredDefaultSpells
	for spell in pairs(Spells) do
		if not Ignored[spell] and not db.Spells[spell].spellTypeNPC then
			table_insert(spellList, spell)
		end
	end
	table_sort(spellList, cmp_col1)
	table_sort(spellList, cmp_col1_col2)
	table_sort(spellList, cmp_col1_col2_col3)
	for i = 1, #spellList do
		local s = spellList[i]
		local Spell = Spells[s]
		local name = Spell.name and Spell.name or (GetSpellInfo(s) and GetSpellInfo(s) or tostring(s))
		local spellId = Spell.spellId
		if Spell.show == 1 then
			if Spell.DEATHKNIGHT then
				local hexColor = hexFontColors["DEATHKNIGHT"]
				color = "|c" .. hexColor
			elseif	Spell.DEMONHUNTER then
				local hexColor = hexFontColors["DEMONHUNTER"]
				color = "|c" .. hexColor
			elseif	Spell.DRUID then
				local hexColor = hexFontColors["DRUID"]
				color = "|c" .. hexColor
			elseif	Spell.EVOKER then
				local hexColor = hexFontColors["EVOKER"]
				color = "|c" .. hexColor
			elseif	Spell.HUNTER then
				local hexColor = hexFontColors["HUNTER"]
				color = "|c" .. hexColor
			elseif	Spell.MAGE then
				local hexColor = hexFontColors["MAGE"]
				color = "|c" .. hexColor
			elseif	Spell.MONK then
				local hexColor = hexFontColors["MONK"]
				color = "|c" .. hexColor
			elseif	Spell.PALADIN then
				local hexColor = hexFontColors["PALADIN"]
				color = "|c" .. hexColor
			elseif	Spell.PRIEST then
				local hexColor = hexFontColors["PRIEST"]
				color = "|c" .. hexColor
			elseif	Spell.ROGUE then
				local hexColor = hexFontColors["ROGUE"]
				color = "|c" .. hexColor
			elseif	Spell.SHAMAN then
				local hexColor = hexFontColors["SHAMAN"]
				color = "|c" .. hexColor
			elseif	Spell.WARLOCK then
				local hexColor = hexFontColors["WARLOCK"]
				color = "|c" .. hexColor
			elseif	Spell.WARRIOR then
				local hexColor = hexFontColors["WARRIOR"]
				color = "|c" .. hexColor
			elseif	Spell.Racials then
				local hexColor = hexFontColors["Racials"]
				color = "|c" .. hexColor
			elseif	Spell.PvP then
				local hexColor = hexFontColors["PvP"]
				color = "|c" .. hexColor
			elseif	Spell.PvE then
				local hexColor = hexFontColors["PvE"]
				color = "|c" .. hexColor
			else
				color = "|cFF00FF00" --green
			end
		elseif Spell.show == 3 then
			color = "|cFFFF0000" --red
		else
			color = "|cFFFFFF00" --yellow
		end

		iconTexture = TextureString(spellId,Spell.IconId)

		--[[if tonumber(spellId) then
		local tooltipData =  C_TooltipInfo.GetHyperlink("spell:"..spellId)
			if tooltipData then 
				TooltipUtil.SurfaceArgs(tooltipData)
				if tooltipData.lines and tooltipData.lines[4] then 
				 	spellDesc = L[tooltipData.lines[4].leftText]
				else
					spellDesc = L["No spell ID"]
				end
			else
				spellDesc = L["No spell ID"]
			end
		end]]

		local lasttext
		if tonumber(spellId) then
			tooltip:SetHyperlink("spell:"..spellId)
			local mytext 
			local rightText
			for i = 1 , tooltip:NumLines() do
				mytext=_G["fPBScanSpellDescTooltipTextLeft"..i]; 
				rightText=_G["fPBScanSpellDescTooltipTextRight"..i]; 
				--print(mytext:GetText().." : "..(rightText:GetText() or "nil"))
				if strfind(mytext:GetText(), "SpellID") then 
					break 
				end
				lasttext = mytext
			end
			if lasttext then 
				local text = lasttext:GetText()
				spellDesc = text
			else
				spellDesc = L["No spell ID"]
			end
		end

		local red
		local glw
		local bff
		local debff

		if Spell.RedifEnemy then
			local color = "|c" .."FFFF0505"
			red = color.."r"
		end
		if Spell.IconGlow then
			local color = "|c" .."FFEAD516"
			glw = color.."g"
		end
		if Spell.showBuff then
			local color = "|c" .."FF00FF15"
			bff = color.."b"
		end
		if Spell.showDebuff then
			local color = "|c" .."FFFF0000"
			debff = color.."d"
		end


		local buildName
		if Spell.spellTypeSummon or Spell.spellTypeCastedAuras or Spell.spellTypeInterrupt then
			buildName = (Spell.scale or "1").." ".. iconTexture..(red or "")..(glw or "")..(bff or "")..(debff or "").." "..color..">"..name.."<"
		else
			buildName = (Spell.scale or "1").." ".. iconTexture..(red or "")..(glw or "")..(bff or "")..(debff or "").." "..color..name
		end



		buildName = buildName.."|r"
		spellTable[tostring(s)] = {
			name = buildName,
			desc = spellDesc,
			type = "group",
			order = 10 + i,
			get = function(info)
				local key = info[#info]
				local id = tonumber(info[#info-1]) or info[#info-1]
				return db.Spells[id][key]
			end,
			set = function(info, value)
				local key = info[#info]
				local id = tonumber(info[#info-1]) or info[#info-1]
				db.Spells[id][key] = value
				fPB.BuildSpellList()
				UpdateAllNameplates()
			end,
			args = {
				show = {
					order = 1,
					name = L["Show"],
					type = "select",
					style = "dropdown",
					values = {
						L["Always"],
						L["Only mine"],
						L["Never"],
						L["On ally only"],
						L["On enemy only"],
					},
				},
				scale = {
					order = 2,
					name = L["Icon scale"],
					type = "range",
					min = 0.1,
					max = 5,
					softMin = 0.5,
					softMax  = 3,
					step = 0.01,
					bigStep = 0.1,
				},
				stackSize = {
					order = 3,
					name = L["Stack font size"],
					type = "range",
					min = minTextSize,
					max = maxTextSize,
					step = 1,
				},
				durationSize = {
					order = 4,
					name = L["Duration font size"],
					type = "range",
					min = minTextSize,
					max = maxTextSize,
					step = 1,
				},
			spellId = {
					order = 5,
					type = "input",
					name = L["Spell ID"],
					get = function(info)
						return Spell.spellId and tostring(Spell.spellId) or L["No spell ID"]
					end,
					set = function(info, value)
						if value then
							local spellId = tonumber(value)
							if spellId then
								local spellName = GetSpellInfo(spellId)
								if spellName then
									if spellId ~= Spell.spellId and spellName == Spell.name then	-- correcting or adding the id
										fPB.ChangespellId(s, spellId)
									elseif spellId ~= Spell.spellId and spellName ~= Spell.name then
										DEFAULT_CHAT_FRAME:AddMessage(spellId..chatColor..L[" It is ID of completely different spell "]..linkColor.."|Hspell:"..spellId.."|h["..GetSpellInfo(spellId).."]|h"..chatColor..L[". You can add it by using top editbox."])
									end
								else
									DEFAULT_CHAT_FRAME:AddMessage(tostring(spellId)..chatColor..L[" Incorrect ID"])
								end
							else
								DEFAULT_CHAT_FRAME:AddMessage(tostring(spellId)..chatColor..L[" Incorrect ID"])
							end
						fPB.BuildSpellList()
						UpdateAllNameplates()
						end
					end,
				},
				removeSpell = {
					order = 6,
					type = "execute",
					name = L["Remove spell"],
					confirm = true,
					func = function(info)
						fPB.RemoveSpell(s)
					end,
				},
				checkID = {
					order = 6.5,
					type = "toggle",
					name = L["Check spell ID"],
					set = function(info, value)
						if value and not Spell.spellId then
							Spell.checkID = nil
							DEFAULT_CHAT_FRAME:AddMessage(tostring(spellId)..chatColor..L[" Incorrect ID"])
						else
							Spell.checkID = value
						end
						fPB.CacheSpells()
						UpdateAllNameplates()
					end,
				},

				break2 = {
					order = 7,
					type = "header",
					name = L["Icon Settings"],
				},
				showBuff = {
					order = 7.2,
					type = "toggle",
					name = L["Only Show if Buff"],
					desc = L["Only shows the icon if it is a buff"],
					get = function(info)
						return Spell.showBuff
					end,
					set = function(info, value)
						if value then 
							Spell.showDebuff = false
							Spell.showBuff = true
						else
							Spell.showBuff = false
						end
						fPB.BuildSpellList()
					end,
				},
				showDebuff = {
					order = 7.5,
					type = "toggle",
					name = L["Only Show if Debuff"],
					desc = L["Only shows the icon if it is a debuff"],
					get = function(info)
						return Spell.showDebuff
					end,
					set = function(info, value)
						if value then 
							Spell.showDebuff = true
							Spell.showBuff = false
						else
							Spell.showDebuff = false
						end
						fPB.BuildSpellList()
					end,
				},
				RedifEnemy = {
					order = 7.75,
					type = "toggle",
					name = L["Red if Enemy"],
					desc = L["Gives the icon a Red Hue indicating a Enemy Aura, Useful for SmokeBomb"],
				},
				IconGlow= {
					order = 8,
					type = "toggle",
					name = L["Glow"],
					desc = L["Gives the icon a Glow"],
				},
				IconId = {
					order = 8.5,
					type = "input",
					name = format("%s %s", iconTexture, "Icon ID"),
					get = function(info)
						return Spell.IconId and tostring(Spell.IconId) or L["No Icon ID"]
					end,
					set = function(info, value)
						if value then
							local IconId = tonumber(value)
							db.Spells[s].IconId = IconId
							UpdateAllNameplates(true)
							fPB.BuildSpellList()
						end
					end,
				},

				break4 = {
					order = 10,
					type = "header",
					name = L["Spell Type if NOT Aura, Combat Log Events (Requires Timer Duration)"],
				},
				spellDisableAura = {
					order = 11,
					type = "toggle",
					name = L["Disable Aura"],
					desc = L["Disables the Aura Check, Only Checks the Combat Log, this will Require Interrupt, Summoned or Casted Aura also be Enabled"],
				},
				spellTypeInterrupt = {
					order = 11,
					type = "toggle",
					name = L["Interrupt"],
					desc = L["Spell is an Interrupt"],
				},
				spellTypeSummon = {
					order = 11,
					type = "toggle",
					name = L["Summoned"],
					desc = L["Spells Such as Tremor Totem or Guardians"],
				},
				spellTypeCastedAuras = {
					order = 11.2,
					type = "toggle",
					name = L["Casted Aura"],
					desc = L["Spells Such as Fury of Elune"],
				},
				durationCLEU = {
					order = 12,
					name = L["Duration for event"],
					type = "range",
					min = 1,
					max = 60,
					step = 1,
				},
				break3 = {
					order = 13,
					type = "header",
					name = L["Select if the Spell Belongs to a Class for Sorting"],
				},
				DEATHKNIGHT = {
					order = 14,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["DEATHKNIGHT"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"], "DEATHKNIGHT")),
					get = function(info)
						return Spell.DEATHKNIGHT
					end,
					set = function(info, value)
						if value then 
							Spell.class = "DEATHKNIGHT"
							Spell.DEATHKNIGHT = true
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
					
					end,
				},
				DEMONHUNTER = {
					order = 15,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["DEMONHUNTER"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["DEMONHUNTER"], "DEMONHUNTER")),
					get = function(info)
						return Spell.DEMONHUNTER
					end,
					set = function(info, value)
						if value then 
							Spell.class = "DEMONHUNTER"
							Spell.DEMONHUNTER = true
							Spell.DEATHKNIGHT = false

							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
					
					end,
				},
				DRUID = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["DRUID"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["DRUID"], "DRUID")),
					get = function(info)
						return Spell.DRUID
					end,
					set = function(info, value)
						if value then 
							Spell.class = "DRUID"
							Spell.DRUID = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				EVOKER = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["EVOKER"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["EVOKER"], "EVOKER")),
					get = function(info)
						return Spell.EVOKER
					end,
					set = function(info, value)
						if value then 
							Spell.class = "EVOKER"
							Spell.EVOKER = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				HUNTER = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["HUNTER"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["HUNTER"], "HUNTER")),
					get = function(info)
						return Spell.HUNTER
					end,
					set = function(info, value)
						if value then 
							Spell.class = "HUNTER"
							Spell.HUNTER = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				MAGE = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["MAGE"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["MAGE"], "MAGE")),
					get = function(info)
						return Spell.MAGE
					end,
					set = function(info, value)
						if value then 
							Spell.class = "MAGE"
							Spell.MAGE = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				MONK = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["MONK"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["MONK"], "MONK")),
					get = function(info)
						return Spell.MONK
					end,
					set = function(info, value)
						if value then 
							Spell.class = "MONK"
							Spell.MONK = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				PALADIN = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["PALADIN"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["PALADIN"], "PALADIN")),
					get = function(info)
						return Spell.PALADIN
					end,
					set = function(info, value)
						if value then 
							Spell.class = "PALADIN"
							Spell.PALADIN = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				PRIEST = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["PRIEST"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["PRIEST"], "PRIEST")),
					get = function(info)
						return Spell.PRIEST
					end,
					set = function(info, value)
						if value then 
							Spell.class = "PRIEST"
							Spell.PRIEST = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
					
					end,
				},
				ROGUE = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["ROGUE"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["ROGUE"], "ROGUE")),
					get = function(info)
						return Spell.ROGUE
					end,
					set = function(info, value)
						if value then 
							Spell.class = "ROGUE"
							Spell.ROGUE = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				SHAMAN = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["SHAMAN"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["SHAMAN"], "SHAMAN")),
					get = function(info)
						return Spell.SHAMAN
					end,
					set = function(info, value)
						if value then 
							Spell.class = "SHAMAN"
							Spell.SHAMAN = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				WARLOCK = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["WARLOCK"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["WARLOCK"], "WARLOCK")),
					get = function(info)
						return Spell.WARLOCK
					end,
					set = function(info, value)
						if value then 
							Spell.class = "WARLOCK"
							Spell.WARLOCK = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
						end
						fPB.BuildSpellList()
						
					end,
				},
				WARRIOR = {
					order = 16,
					type = "toggle",
					name = format("%s %s", GetIconString(classIcons["WARRIOR"], 15), Colorize(LOCALIZED_CLASS_NAMES_MALE["WARRIOR"], "WARRIOR")),
					get = function(info)
						return Spell.WARRIOR
					end,
					set = function(info, value)
						if value then 
							Spell.class = "WARRIOR"
							Spell.WARRIOR = true
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							
							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildSpellList()
						
					end,
				},
				Racials = {
					order = 21,
					type = "toggle",
					name = format("%s %s",GetIconString(customIcons["Racials"], 15), Colorize("Racials", "Racials")),
					get = function(info)
						return Spell.Racials
					end,
					set = function(info, value)
						if value then 
							Spell.class = "xRacials"
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = true
							Spell.PvP = false
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildSpellList()
						
					end,
				},
				PvP = {
					order = 22,
					type = "toggle",
					name = format("%s %s",GetIconString(customIcons["PvP"], 15), Colorize("PvP", "PvP")),
					get = function(info)
						return Spell.PvP
					end,
					set = function(info, value)
						if value then 
							Spell.class = "yPvP"
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = true
							Spell.PvE = false
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildSpellList()
						
					end,
				},
				PvE = {
					order = 23,
					type = "toggle",
					name = format("%s %s",GetIconString(customIcons["PvE"], 15), Colorize("PvE", "PvE")),
					get = function(info)
						return Spell.PvE
					end,
					set = function(info, value)
						if value then 
							Spell.class = "zPvE"
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false

							Spell.Racials = false
							Spell.PvP = false
							Spell.PvE = true
						else
							Spell.DEATHKNIGHT = false
							Spell.DEMONHUNTER = false
							Spell.DRUID = false
							Spell.EVOKER = false
							Spell.HUNTER = false
							Spell.MAGE = false
							Spell.MONK = false
							Spell.PALADIN = false
							Spell.PRIEST = false
							Spell.ROGUE = false
							Spell.SHAMAN = false
							Spell.WARLOCK = false
							Spell.WARRIOR = false
							Spell.PvP = false
							Spell.Racials = false
							Spell.PvE = false
							
						end
						fPB.BuildSpellList()
						
					end,
				},
				
				
			},
		}
	end
end

function fPB.OptionsOnEnable()
	db = fPB.db.profile
	fPB.BuildSpellList()
	fPB.BuildNPCList()
end

function fPB.ToggleOptions()
	DEFAULT_CHAT_FRAME.editBox:SetText("/fpb")
	ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
end

fPB.OptionsOpen = {
	name = L["FlyPlateBuffs Options"],
	type = "group",
	args = {
		removeSpell = {
			order = 1,
			type = "execute",
			name = L["Open Menu"],
			--confirm = true,
			func = function(info)
				fPB.ToggleOptions()
			end,
		},
	},
}

fPB.MainOptionTable = {
	name = L["Display options"],
  --plugins = { profiles = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(fPB.db) } },
	type = "group",
	childGroups = "tab",
	get = function(info)
        return db[info[#info]]
    end,

	set = function(info, value)
        db[info[#info]] = value
		UpdateAllNameplates()
    end,

	args = {
		spells = fPB.SpellsTable,
		NPC = fPB.NPCTable,
		displayConditions = {
			order = 2,
			name = L["Display Conditions"],
			type = "group",
			args = {
				showDebuffs = {
					order = 1,
					type = "select",
					style = "dropdown",
					name = L["Show debuffs"],
					values = {
							L["All"],
							L["Mine + SpellList"],
							L["Only SpellList"],
							L["Only mine"],
							L["None"],
					},
				},
				showBuffs = {
					order = 2,
					type = "select",
					style = "dropdown",
					name = L["Show buffs"],
					values = {
							L["All"],
							L["Mine + SpellList"],
							L["Only SpellList"],
							L["Only mine"],
							L["None"],
					},
				},
				hidePermanent = {
					order = 4,
					type = "toggle",
					name = L["Hide permanent effects"],
					desc = L["Do not show effects without duration."],
				},
				blank2 = {
					order = 6,
					type = "description",
					name = "",
					width = "normal",
				},
				break2 = {
					order = 10,
					type = "header",
					name = L["Target types"],
				},
				showOnPlayers = {
					order = 11,
					type = "toggle",
					name = L["Players"],
					desc = L["Show on players"],
				},
				blank3 = {
					order = 12,
					type = "description",
					name = "",
					width = "normal",
				},
				showOnEnemy = {
					order = 13,
					type = "toggle",
					name = L["Enemies"],
					desc = L["Show on enemies"],
				},
				showOnPets = {
					order = 14,
					type = "toggle",
					name = L["Pets"],
					desc = L["Show on pets"],
				},
				blank4 = {
					order = 15,
					type = "description",
					name = "",
					width = "normal",
				},
				showOnFriend = {
					order = 16,
					type = "toggle",
					name = L["Allies"],
					desc = L["Show on allies"],
				},
				showOnNPC = {
					order = 17,
					type = "toggle",
					name = L["NPCs"],
					desc = L["Show on NPCs"],
				},
				blank5 = {
					order = 18,
					type = "description",
					name = "",
					width = "normal",
				},
				showOnNeutral = {
					order = 19,
					type = "toggle",
					name = L["Neutrals"],
					desc = L["Show on neutral characters"],
				},
			},
		},
		styleSettings = {
			order = 3,
			name = L["Style Settings"],
			type = "group",
			set = function(info, value)
				db[info[#info]] = value
				UpdateAllNameplates(true)
			end,
			args = {
				iconsSize = {
					order = 1,
					type = "header",
					name = L["Icons Size"],
				},
				baseWidth = {
					order = 2,
					type = "range",
					name = L["Base width"],
					min = minIconSize,
					max = maxIconSize,
					step = 1,
				},
				baseHeight = {
					order = 3,
					type = "range",
					name = L["Base height"],
					min = minIconSize,
					max = maxIconSize,
					step = 1,
				},
				myScale = {
					order = 4,
					type = "range",
					name = L["Larger self spells"],
					desc = L["Show self spells x% bigger."],
					min = 0,
					max = 1,
					step = 0.01, --CHRIS
					isPercent = true,
				},
				cropTexture = {
					order = 4.1,
					type = "toggle",
					name = L["Crop texture"],
					desc = L["Crop texture instead of stretching. You can see the difference on rectangular icons"],
				},
				headerDuration = {
					order = 5,
					type = "header",
					name = L["Duration"],
				},
				showDuration = {
					order = 6,
					type = "toggle",
					name = L["Show fPB Duration"],
					desc = L["Show remaining duration, this duration is seperate from OmniCC and Blizzards Countdown"],
				},
				showDecimals = {
					order = 7,
					type = "toggle",
					name = L["Show decimals"],
					desc = L["when less than 10 seconds"],
					disabled = function() return not db.showDuration end,
				},
				blank1 = {
					order = 8,
					type = "description",
					name = "",
					width = "normal",
				},
				durationPosition = {
					order = 9,
					type = "select",
					style = "dropdown",
					name = L["Duration position"],
					values = {
						L["Under Icon"],
						L["On Icon"],
						L["Above Icon"],					},
					disabled = function() return not db.showDuration end,
				},
				durationFont = {
					order = 10,
					type = "select",
					name = L["Font"],
					values = fPB.LSM:HashTable("font"),
					dialogControl = "LSM30_Font",
					get = function()
						return db.font
					end,
					set = function(info, value)
						db.font = value
						fPB.font = fPB.LSM:Fetch("font", value)
						UpdateAllNameplates(true)
					end,
				},
				durationSize = {
					order = 11,
					type = "range",
					name = L["Duration font size"],
					min = minTextSize,
					max = maxTextSize,
					step = 1,
					disabled = function() return not db.showDuration end,
				},
				colorSingle = {
					order = 13,
					type = "color",
					name = L["Select Time Color"],
					hidden = function() return db.colorTransition end,
					disabled = function() return not db.showDuration end,
					get = function(info)
						return db.colorSingle[1], db.colorSingle[2], db.colorSingle[3], 1
					end,
					set = function(info, r, g, b)
						db.colorSingle = {r, g, b}
					end,
				},
				blinkTimeleft = {
					order	= 14,
					name = L["Blink when close to expiring"],
					desc = L["Blink spell if below x% time left (only if it's below 60 seconds)"],
					type = "range",
					min		= 0,
					max		= 0.5,
					step	= 0.05,
					isPercent = true,
				},
				durationSizeX = {
					order = 14.5,
					type = "range",
					name = L["X Position"],
					min = -10,
					max = 10,
					step = .1,
				},
				durationSizeY = {
					order = 14.75,
					type = "range",
					name = L["Y Position"],
					min = -10,
					max = 10,
					step = .1,
				},
				colorTransition = {
					order = 14.8,
					type = "toggle",
					name = L["Enable color transition"],
					desc = L["Duration text will change its color based on time left"],
					disabled = function() return not db.showDuration end,
				},
				headerStack = {
					order = 15,
					type = "header",
					name = L["Stacks"],
				},
				stackPosition = {
					order = 16,
					type = "select",
					style = "dropdown",
					name = L["Stacks position"],
					values = {
						L["On Icon"],
						L["Under Icon"],
						L["Above Icon"],
					},
				},
				stackFont = {
					order = 17,
					type = "select",
					name = L["Font"],
					values = fPB.LSM:HashTable("font"),
					dialogControl = "LSM30_Font",
					get = function()
						return db.stackFont
					end,
					set = function(info, value)
						db.stackFont = value
						fPB.stackFont = fPB.LSM:Fetch("font", value)
						UpdateAllNameplates(true)
					end,
				},
				stackColor = {
					order = 18,
					type = "color",
					name = L["Select Stack Color"],
					get = function(info)
						return db.stackColor[1], db.stackColor[2], db.stackColor[3], 1
					end,
					set = function(info, r, g, b)
						db.stackColor = {r, g, b}
					end,
				},
				stackSize = {
					order = 19,
					type = "range",
					name = L["Stack font size"],
					min = minTextSize,
					max = maxTextSize,
					step = 1,
				},
				stackSizeX = {
					order = 19.25,
					type = "range",
					name = L["X Position"],
					min = -10,
					max = 10,
					step = .1,
				},
				stackSizeY = {
					order = 19.75,
					type = "range",
					name = L["Y Position"],
					min = -10,
					max = 10,
					step = .1,
				},
				stackOverride = {
					order = 19.8,
					type = "toggle",
					name = L["One Stack Size"],
					desc = L["Use the same stack font size for all icon sizes over scaling with Icon sizes or custom spell stack font size"],
					disabled = function() return db.stackSpecific end,
				},
				stackScale = {
					order = 19.9,
					type = "toggle",
					name = L["Scale Stack Size"],
					desc = L["Scales default stack font size with the scale of the Icon on all Icons"],
					disabled = function() return db.stackSpecific end,
				},
				stackSpecific = {
					order = 19.95,
					type = "toggle",
					name = L["Spell Specific Stack Size"],
					desc = L["Uses the Specific Spells stack font size options for Icons and if spell is not added will use the default font stack size above"],
				},
				headerOther = {
					order = 20,
					type = "header",
					name = L["Non-fPB duration options"],
				},
				showStdCooldown = {
					order = 21,
					type = "toggle",
					name = L["Enable OmniCC"],
					desc = L["If loaded Blizzard Count is not avialable but you can customize the look in OmniCC using fPB as the pattern for the elemnet UI to anything you like with OmniCC"],
					disabled = function() return not IsAddOnLoaded("OmniCC") end
				},
				blizzardCountdown = {
					order =22,
					type = "toggle",
					name = L["Enable Blizzard Countdown"],
					desc = L["Changes CVar \"countdownForCooldowns\""],
					width = "double",
					get = function(info)
						return db.blizzardCountdown or (GetCVar("countdownForCooldowns") == "1")
					end,
					set = function(info, value)
						if value then
							db.blizzardCountdown = true
							SetCVar("countdownForCooldowns", 1)
						else
							db.blizzardCountdown = false
							SetCVar("countdownForCooldowns", 0)
						end
					end,
					disabled = function() return IsAddOnLoaded("OmniCC") end
				},
				showStdSwipe = {
					order = 23,
					type = "toggle",
					name = L["Show DrawSwipe"],
					desc = L["Show the DrawSwipe on Icons, if using OmniCC this can be customized further, if it is not showing this most likely menas you have it disabled in OmniCC"],
				},
				headerBorder = {
					order = 24,
					type = "header",
					name = L["Border"],
				},
				borderStyle = {
					order = 24.1,
					type = "select",
					style = "dropdown",
					name = L["Border Style"],
					values = {
						L["Square"],
						"Blizzard",
						L["None"],
					},
				},
				colorizeBorder = {
					order = 25,
					type = "toggle",
					name = L["Color debuff border by type"],
					desc = L["If not checked - physical used for all debuff types"],
					width = "double",
					disabled = function() return db.borderStyle == 3 end,
				},
				colorsPhysical = {
					order = 25.1,
					type = "color",
					name = L["Physical"],
					get = function(info)
						return db.colorTypes.none[1], db.colorTypes.none[2], db.colorTypes.none[3], 1
					end,
					set = function(info, r, g, b)
						db.colorTypes.none = {r, g, b}
					end,
				},
				colorsMagic = {
					order = 25.2,
					type = "color",
					name = L["Magic"],
					get = function(info)
						return db.colorTypes.Magic[1], db.colorTypes.Magic[2], db.colorTypes.Magic[3], 1
					end,
					set = function(info, r, g, b)
						db.colorTypes.Magic = {r, g, b}
					end,
				},
				colorsCurse = {
					order = 25.3,
					type = "color",
					name = L["Curse"],
					get = function(info)
						return db.colorTypes.Curse[1], db.colorTypes.Curse[2], db.colorTypes.Curse[3], 1
					end,
					set = function(info, r, g, b)
						db.colorTypes.Curse = {r, g, b}
					end,
				},
				colorsDisease = {
					order = 25.4,
					type = "color",
					name = L["Disease"],
					get = function(info)
						return db.colorTypes.Disease[1], db.colorTypes.Disease[2], db.colorTypes.Disease[3], 1
					end,
					set = function(info, r, g, b)
						db.colorTypes.Disease = {r, g, b}
					end,
				},
				colorsPoison = {
					order = 25.5,
					type = "color",
					name = L["Poison"],
					get = function(info)
						return db.colorTypes.Poison[1], db.colorTypes.Poison[2], db.colorTypes.Poison[3], 1
					end,
					set = function(info, r, g, b)
						db.colorTypes.Poison = {r, g, b}
					end,
				},
				colorsBuff = {
					order = 25.6,
					type = "color",
					name = L["Buffs"],
					get = function(info)
						return db.colorTypes.Buff[1], db.colorTypes.Buff[2], db.colorTypes.Buff[3], 1
					end,
					set = function(info, r, g, b)
						db.colorTypes.Buff = {r, g, b}
					end,
				},
			},
		},
		positionSettings = {
			order = 4,
			name = L["Position Settings"],
			type = "group",
			args = {
				buffAnchorPoint = {
					order = 1,
					type = "select",
					style = "dropdown",
					name = L["Buff frame's Anchor point"],
					desc = L["It will be attached to the nameplate at this point"],
					values = {
						["BOTTOMLEFT"] = L["Left"],
						["BOTTOM"] = L["Center"],
						["BOTTOMRIGHT"] = L["Right"],
					},
				},
				plateAnchorPoint = {
					order = 2,
					type = "select",
					style = "dropdown",
					name = L["Nameplate's Anchor point"],
					desc = L["Buff frame will be anchored to this point of the nameplate"],
					values = {
						["TOPLEFT"] = L["Left"],
						["TOP"] = L["Center"],
						["TOPRIGHT"] = L["Right"],
					},
				},
				blank1 = {
					order = 3,
					type = "description",
					name = "",
					width = "normal",
				},
				xOffset = {
					order = 4,
					type = "range",
					name = L["Offset X"],
					desc = L["Horizontal offset of buff frame"],
					min = -256,
					max = 256,
					step = .1,
				},
				yOffset = {
					order = 5,
					type = "range",
					name = L["Offset Y"],
					desc = L["Vertical offset of buff frame"],
					min = -256,
					max = 256,
					step = .1,
				},
				blank2 = {
					order = 6,
					type = "description",
					name = "",
					width = "normal",
				},
				buffPerLine = {
					order = 7,
					type = "range",
					name = L["Icons per row"],
					desc = L["If more icons they will be moved to a new row"],
					min = 1,
					max = 20,
					step = 1,
				},
				numLines = {
					order = 8,
					type = "range",
					name = L["Max rows"],
					desc = L["Excess buffs will not be displayed"],
					min = 1,
					max = 10,
					step = 1,
				},
				blank3 = {
					order = 9,
					type = "description",
					name = "",
					width = "normal",
				},
				xInterval = {
					order = 10,
					type = "range",
					name = L["Interval X"],
					desc = L["Horizontal spacing between icons"],
					min = minInterval,
					max = maxInterval,
					step = .1,
				},
				yInterval = {
					order = 11,
					type = "range",
					name = L["Interval Y"],
					desc = L["Vertical spacing between icons"],
					min = minInterval,
					max = maxInterval,
					step = .1,
				},
				break1 = {
					order = 12,
					type = "header",
					name = "",
				},
				parentWorldFrame = {
					order = 13,
					type = "toggle",
					name = L["Always show icons with full opacity and size"],
					desc = L["Icons will not change on nontargeted nameplates.\n\n|cFFFF0000REALLY NOT RECOMMEND REQUIRES RELOAD UI|r\nWhen icons overlay there will be mess of textures, digits etc."],
					width = "full",
					set = function(info, value)
						db[info[#info]] = value
						for n, frame in ipairs(C_NamePlate.GetNamePlates()) do
							if frame.fPBiconsFrame and frame.fPBiconsFrame.iconsFrame then
								frame.fPBiconsFrame:SetParent(value and WorldFrame or frame)
							end
						end
					end,
				},
			},
		},
		sortSettings = {
			order = 5,
			name = L["Sorting"],
			type = "group",
			args = {
				disableSort = {
					order = 0.1,
					type = "toggle",
					name = L["Disable sorting"],
					width = "full",
					set = function(info, value)
						db[info[#info]] = value
						UpdateAllNameplates()
						if value == false and not CheckSort() then
							db.sortMode[1] = "my"
							db.sortMode[2] = "expiration"
						end
					end,
					},
				header = {
					order = 0.2,
					type = "header",
					name = L["Priority"],
				},
				sort1 = {
					order = 1,
					type = "select",
					style = "dropdown",
					disabled = function() return db.disableSort end,
					name = "",
					width = "double",
					values = {
						["type"] = L["Debuff > Buff"],
						["expiration"] = L["Remaining duration"],
						["my"] = L["My spell"],
						["scale"] = L["Icon scale (Importance)"],
						["disable"] = DISABLE,
					},
					set = function(info,val)
						db.sortMode[1] = val
						if not CheckSort() then
							db.disableSort = true
						end
						UpdateAllNameplates()
					end,
					get = function(info) return db.sortMode[1] end,
				},
				reverse1 = {
					order = 1.5,
					type = "toggle",
					disabled = function() return db.disableSort end,
					name = L["Reverse"],
					set = function(info,val) db.sortMode[1.5] = val;UpdateAllNameplates() end,
					get = function(info) return db.sortMode[1.5] end,
				},
				sort2 = {
					order = 2,
					type = "select",
					style = "dropdown",
					disabled = function() return db.disableSort end,
					name = "",
					width = "double",
					values = {
						["type"] = L["Debuff > Buff"],
						["expiration"] = L["Remaining duration"],
						["my"] = L["My spell"],
						["scale"] = L["Icon scale (Importance)"],
						["disable"] = DISABLE,
					},
					set = function(info,val)
						db.sortMode[2] = val
						if not CheckSort() then
							db.disableSort = true
						end
						UpdateAllNameplates()
					end,
					get = function(info) return db.sortMode[2] end,
				},
				reverse2 = {
					order = 2.5,
					type = "toggle",
					disabled = function() return db.disableSort end,
					name = L["Reverse"],
					set = function(info,val) db.sortMode[2.5] = val;UpdateAllNameplates() end,
					get = function(info) return db.sortMode[2.5] end,
				},
				sort3 = {
					order = 3,
					type = "select",
					style = "dropdown",
					disabled = function() return db.disableSort end,
					name = "",
					width = "double",
					values = {
						["type"] = L["Debuff > Buff"],
						["expiration"] = L["Remaining duration"],
						["my"] = L["My spell"],
						["scale"] = L["Icon scale (Importance)"],
						["disable"] = DISABLE,
					},
					set = function(info,val)
						db.sortMode[3] = val
						if not CheckSort() then
							db.disableSort = true
						end
						UpdateAllNameplates()
					end,
					get = function(info) return db.sortMode[3] end,
				},
				reverse3 = {
					order = 3.5,
					type = "toggle",
					disabled = function() return db.disableSort end,
					name = L["Reverse"],
					set = function(info,val) db.sortMode[3.5] = val;UpdateAllNameplates() end,
					get = function(info) return db.sortMode[3.5] end,
				},
				sort4 = {
					order = 4,
					type = "select",
					style = "dropdown",
					disabled = function() return db.disableSort end,
					name = "",
					width = "double",
					values = {
						["type"] = L["Debuff > Buff"],
						["expiration"] = L["Remaining duration"],
						["my"] = L["My spell"],
						["scale"] = L["Icon scale (Importance)"],
						["disable"] = DISABLE,
					},
					set = function(info,val)
						db.sortMode[4] = val
						if not CheckSort() then
							db.disableSort = true
						end
						UpdateAllNameplates()
					end,
					get = function(info) return db.sortMode[4] end,
				},
				reverse4 = {
					order = 4.5,
					type = "toggle",
					disabled = function() return db.disableSort end,
					name = L["Reverse"],
					set = function(info,val) db.sortMode[4.5] = val;UpdateAllNameplates() end,
					get = function(info) return db.sortMode[4.5] end,
				},
			},
		},
	},
}
