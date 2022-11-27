local _, fPB = ...
local L = fPB.L

local db = {}
local UpdateAllNameplates = fPB.UpdateAllNameplates

local 	GetSpellInfo, tonumber, pairs, table_sort, table_insert =
		GetSpellInfo, tonumber, pairs, table.sort, table.insert
local	DISABLE = DISABLE
local chatColor = fPB.chatColor
local linkColor = fPB.linkColor



local tooltip = tooltip or CreateFrame("GameTooltip", "fPBScanSpellDescTooltip", UIParent, "GameTooltipTemplate")
tooltip:Show()
tooltip:SetOwner(UIParent, "ANCHOR_NONE")

local minIconSize = 10
local maxIconSize = 100
local minTextSize = 6
local maxTextSize = 30
local minInterval = 0
local maxInterval = 80

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
local function TextureString(spellId)
	if not tonumber(spellId) then
		return "\124TInterface\\Icons\\Inv_misc_questionmark:0\124t"
	else
		_,_,iconTexture = GetSpellInfo(spellId)
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
		a = tostring(Spells[a].scale or a)
		b = tostring(Spells[b].scale or b)
 		return a > b
	end
end

local function cmp_col1_col2(a, b)
	if (a and b) then
		local Spells = db.Spells
		a1 = tostring(Spells[a].scale or a)
		b1 = tostring(Spells[b].scale or b)
		a2 = tostring(Spells[a].name or a)
		b2 = tostring(Spells[b].name or b)
	 if a1 > b1 then return true end
	 if a1 < b1 then return false end
		 return a2 < b2
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
			name = L["Add new NPC to list"],
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
	for i = 1, #spellList do
		local s = spellList[i]
		local Spell = Spells[s]
		local name = Spell.name and Spell.name
		local spellId = Spell.spellId
		if Spell.show == 1 then
			color = "|cFF00FF00" --green
		elseif Spell.show == 3 then
			color = "|cFFFF0000" --red
		else
			color = "|cFFFFFF00" --yellow
		end
		if Spell.spellId then
			iconTexture = "\124T"..Spell.spellId ..":0\124t"
		else
			iconTexture = TextureString(spellId)
		end
		spellDesc = L["NPC ID"]


		local buildName = (Spell.scale or "1").." ".. iconTexture.." "..color..name
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
				durationSize = {
					order = 4,
					name = L["Duration font size"],
					type = "range",
					min = minTextSize,
					max = maxTextSize,
					step = 1,
				},
				durationCLEU = {
					order = 4.5,
					name = L["Duration"],
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
	for i = 1, #spellList do
		local s = spellList[i]
		local Spell = Spells[s]
		local name = Spell.name and Spell.name or (GetSpellInfo(s) and GetSpellInfo(s) or tostring(s))
		local spellId = Spell.spellId
		if Spell.show == 1 then
			color = "|cFF00FF00" --green
		elseif Spell.show == 3 then
			color = "|cFFFF0000" --red
		else
			color = "|cFFFFFF00" --yellow
		end

		iconTexture = TextureString(spellId)

		if tonumber(spellId) then
			tooltip:SetHyperlink("spell:"..spellId)
			local lines = tooltip:NumLines()
			if lines > 0 then
				spellDesc = _G["fPBScanSpellDescTooltipTextLeft"..lines]:GetText() or "??"
			end
		else
			spellDesc = L["No spell ID"]
		end

		local buildName
		if Spell.spellTypeSummon or Spell.spellTypeCastedAuras or Spell.spellTypeInterrupt then
			buildName = (Spell.scale or "1").." ".. iconTexture.." "..color..">>"..name.."<<"
		else
			buildName = (Spell.scale or "1").." ".. iconTexture.." "..color..name
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
				RedifEnemy = {
					order = 7,
					type = "toggle",
					name = L["Red if Enemy"],
					desc = L["Gives the icon a Red Hue indicating a Enemy Aura, Useful for SmokeBomb"],
				},
				break2 = {
					order = 10,
					type = "header",
					name = L["Spell Type if NOT Aura, Combat Log Events (Requires Timer Duration)"],
				},
				spellDisableAura = {
					order = 11,
					type = "toggle",
					name = L["Disable Aura"],
					desc = L["Disables the Aura Check, Only Checks the Combat Log"],
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
					name = L["Duration For Event"],
					type = "range",
					min = 1,
					max = 60,
					step = 1,
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
