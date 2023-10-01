local AddonName, fPB = ...
L = fPB.L

local	C_NamePlate_GetNamePlateForUnit, C_NamePlate_GetNamePlates, CreateFrame, UnitDebuff, UnitBuff, UnitName, UnitIsUnit, UnitIsPlayer, UnitPlayerControlled, UnitIsEnemy, UnitIsFriend, GetSpellInfo, table_sort, strmatch, format, wipe, pairs, GetTime, math_floor =
		C_NamePlate.GetNamePlateForUnit, C_NamePlate.GetNamePlates, CreateFrame, UnitDebuff, UnitBuff, UnitName, UnitIsUnit, UnitIsPlayer, UnitPlayerControlled, UnitIsEnemy, UnitIsFriend, GetSpellInfo, table.sort, strmatch, format, wipe, pairs, GetTime, math.floor

local defaultSpells1, defaultSpells2 = fPB.defaultSpells1, fPB.defaultSpells2

local LSM = LibStub("LibSharedMedia-3.0")
fPB.LSM = LSM
local MSQ, Group

local config = LibStub("AceConfig-3.0")
local dialog = LibStub("AceConfigDialog-3.0")

fPB.db = {}
local db

local tooltip = CreateFrame("GameTooltip", "fPBMouseoverTooltip", UIParent, "GameTooltipTemplate")

local fPBMainOptions
local fPBSpellsList
local fPBProfilesOptions

fPB.chatColor = "|cFFFFA500"
fPB.linkColor = "|cff71d5ff"
local chatColor = fPB.chatColor
local linkColor = fPB.linkColor

local cachedSpells = {}
local PlatesBuffs = {}
local Ctimer = C_Timer.After
local tblinsert = table.insert
local tremove = table.remove
local substring = string.sub
local strfind = string.find
local type = type
local bit_band = bit.band
local Interrupted = {}
local Earthen = { }
local Grounding = { }
local WarBanner = { }
local Barrier = { }
local SGrounds = { }
local SmokeBombAuras = { }

local DefaultSettings = {
	profile = {
		showDebuffs = 2,		-- 1 = all, 2 = mine + spellList, 3 = only spellList, 4 = only mine, 5 = none
		showBuffs = 3,			-- 1 = all, 2 = mine + spellList, 3 = only spellList, 4 = only mine, 5 = none
		showTooltip = false,
		hidePermanent = true,

		showOnPlayers = true,
		showOnPets = true,
		showOnNPC = true,

		showOnEnemy = true,
		showOnFriend = true,
		showOnNeutral = true,

		parentWorldFrame = false,

		baseWidth = 24,
		baseHeight = 24,
		myScale = 0.2,
		cropTexture = true,

		buffAnchorPoint = "BOTTOM",
		plateAnchorPoint = "TOP",

		xInterval = 4,
		yInterval = 12,

		xOffset = 0,
		yOffset = 4,

		buffPerLine = 6,
		numLines = 3,

		showStdCooldown = true,
		showStdSwipe = false,

		showDuration = true,
		showDecimals = true,
		durationPosition = 1, -- 1 - under, 2 - on icon, 3 - above icon
		font = "Friz Quadrata TT", --durationFont
		durationSize = 10,
		colorTransition = true,
		colorSingle = {1.0,1.0,1.0},

		stackPosition = 1,  -- 1 - on icon, 2 - under, 3 - above icon
		stackFont = "Friz Quadrata TT",
		stackSize = 10,
		stackColor = {1.0,1.0,1.0},
		stackSizeX = 0,
		stackSizeY = 0,
		stackScale = true,
		stackOverride = false,
		stackSpecific = false,

		blinkTimeleft = 0.2,

		borderStyle = 1,	-- 1 = \\texture\\border.tga, 2 = Blizzard, 3 = none
		colorizeBorder = true,
		colorTypes = {
			Magic 	= {0.20,0.60,1.00},
			Curse 	= {0.60,0.00,1.00},
			Disease = {0.60,0.40,0},
			Poison 	= {0.00,0.60,0},
			none 	= {0.80,0,   0},
			Buff 	= {0.00,1.00,0},
		},

		disableSort = false,
		sortMode = {
			"my", -- [1]
			"expiration", -- [2]
			"disable", -- [3]
			"disable", -- [4]
		},

		Spells = {},
		ignoredDefaultSpells = {},

		showspellId = false,
		blizzardCountdown,
	},
}

do --add default spells
	for i=1, #defaultSpells1 do
		local spellId = defaultSpells1[i]
		local name = GetSpellInfo(spellId)
		if name then
			DefaultSettings.profile.Spells[spellId] = {
				name = name,
				spellId = spellId,
				scale = 2,
				durationSize = 18,
				show = 1,	-- 1 = always, 2 = mine, 3 = never, 4 = on ally, 5 = on enemy
				stackSize = 18,
			}
		end
	end

	for i=1, #defaultSpells2 do
		local spellId = defaultSpells2[i]
		local name = GetSpellInfo(spellId)
		if name then
			DefaultSettings.profile.Spells[spellId] = {
				name = name,
				spellId = spellId,
				scale = 1.5,
				durationSize = 14,
				show = 1,	-- 1 = always, 2 = mine, 3 = never, 4 = on ally, 5 = on enemy
				stackSize = 14,
			}
		end
	end
end

local function ActionButton_SetupOverlayGlow(button)
	-- If we already have a SpellActivationAlert then just early return. We should already be setup
	if button.SpellActivationAlert then
		return;
	end

	button.SpellActivationAlert = CreateFrame("Frame", nil, button, "ActionBarButtonSpellActivationAlert");

	--Make the height/width available before the next frame:
	button.SpellActivationAlert:SetPoint("CENTER", button, "CENTER", 0, 0);
	button.SpellActivationAlert:Hide();
end

local function ActionButton_ShowOverlayGlow(button, scale)
	ActionButton_SetupOverlayGlow(button);
	button.SpellActivationAlert:SetSize(db.baseWidth * scale * 1.5, db.baseWidth * scale * 1.5);
	button.SpellActivationAlert:Show();
	button.SpellActivationAlert.ProcLoop:Play();
	button.SpellActivationAlert.ProcStartFlipbook:Hide()
end

local function ActionButton_HideOverlayGlow(button)
	if not button.SpellActivationAlert then
		return;
	end

 	button.SpellActivationAlert:Hide();

end


local hexFontColors = {
    ["logo"] = "ff36ffe7",
    ["accent"] = "ff9b6ef3",
    ["value"] = "ffffe981",
    ["blizzardFont"] = NORMAL_FONT_COLOR:GenerateHexColor(),
}

local function Colorize(text, color)
    if not text then return end
    local hexColor = hexFontColors[color] or hexFontColors["blizzardFont"]
    return "|c" .. hexColor .. text .. "|r"
end

local function Print(msg)
    print(Colorize("FlyPlateBuffs", "logo") .. ": " .. msg)
end

--timeIntervals
local minute, hour, day = 60, 3600, 86400
local aboutMinute, aboutHour, aboutDay = 59.5, 60 * 59.5, 3600 * 23.5

local function round(x) return floor(x + 0.5) end

local function FormatTime(seconds)
	if seconds < 10 and db.showDecimals then
		return "%.1f", seconds
	elseif seconds < aboutMinute then
		local seconds = round(seconds)
		return seconds ~= 0 and seconds or ""
	elseif seconds < aboutHour then
		return "%dm", round(seconds/minute)
	elseif seconds < aboutDay then
		return "%dh", round(seconds/hour)
	else
		return "%dd", round(seconds/day)
	end
end

local function GetColorByTime(current, max)
	if max == 0 then max = 1 end
	local percentage = (current/max)*100
	local red,green = 0,0
	if percentage >= 50 then
		--green to yellow
		green		= 1
		red			= ((100 - percentage) / 100) * 2
	else
		--yellow to red
		red	= 1
		green		= ((100 - (100 - percentage)) / 100) * 2
	end
	return red, green, 0
end

local function SortFunc(a,b)
	local i = 1
	while db.sortMode[i] do
		local mode, rev = db.sortMode[i],db.sortMode[i+0.5]
		if mode ~= "disable" and a[mode] ~= b[mode] then
			if mode == "my" and not rev then -- self first
				return (a.my and 1 or 0) > (b.my and 1 or 0)
			elseif mode == "my" and rev then
				return (a.my and 1 or 0) < (b.my and 1 or 0)
			elseif mode == "expiration" and not rev then
				return (a.expiration > 0 and a.expiration or 5000000) < (b.expiration > 0 and b.expiration or 5000000)
			elseif mode == "expiration" and rev then
				return (a.expiration > 0 and a.expiration or 5000000) > (b.expiration > 0 and b.expiration or 5000000)
			elseif (mode == "type" or mode == "scale") and not rev then
				return a[mode] > b[mode]
			else
				return a[mode] < b[mode]
			end
		end
		i = i+1
	end
end

local function DrawOnPlate(frame)

	if not (#frame.fPBiconsFrame.iconsFrame > 0) then return end

	local maxWidth = 0
	local sumHeight = 0

	local buffIcon = frame.fPBiconsFrame.iconsFrame

	local breaked = false
	for l = 1, db.numLines do
		if breaked then break end

		local lineWidth = 0
		local lineHeight = 0

		for k = 1, db.buffPerLine do

			local i = db.buffPerLine*(l-1)+k
			if not buffIcon[i] or not buffIcon[i]:IsShown() then breaked = true; break end
			buffIcon[i]:ClearAllPoints()
			if l == 1 and k == 1 then
				buffIcon[i]:SetPoint("BOTTOMLEFT", frame.fPBiconsFrame, "BOTTOMLEFT", 0, 0)
			elseif k == 1 then
				buffIcon[i]:SetPoint("BOTTOMLEFT", buffIcon[i-db.buffPerLine], "TOPLEFT", 0, db.yInterval)
			else
				buffIcon[i]:SetPoint("BOTTOMLEFT", buffIcon[i-1], "BOTTOMRIGHT", db.xInterval, 0)
			end

			lineWidth = lineWidth + buffIcon[i].width + db.xInterval
			lineHeight = (buffIcon[i].height > lineHeight) and buffIcon[i].height or lineHeight
		end
		maxWidth = max(maxWidth, lineWidth)
		sumHeight = sumHeight + lineHeight + db.yInterval
	end
	if #PlatesBuffs[frame] > db.numLines * db.buffPerLine then
		for i = db.numLines * db.buffPerLine + 1, #PlatesBuffs[frame] do
			buffIcon[i]:Hide()
		end
	end
	frame.fPBiconsFrame:SetWidth(maxWidth-db.xInterval)
	frame.fPBiconsFrame:SetHeight(sumHeight - db.yInterval)
	frame.fPBiconsFrame:ClearAllPoints()
	frame.fPBiconsFrame:SetPoint(db.buffAnchorPoint,frame,db.plateAnchorPoint,db.xOffset,db.yOffset)
	if MSQ then
		Group:ReSkin()
	end
end

local function AddBuff(frame, type, icon, stack, debufftype, duration, expiration, my, id, spellId, EnemyBuff, scale, durationSize, stackSize, icon_override, glow)
	if icon_override then icon = icon_override end
	if not PlatesBuffs[frame] then PlatesBuffs[frame] = {} end
	PlatesBuffs[frame][#PlatesBuffs[frame] + 1] = {
		type = type,
		icon = icon,
		stack = stack,
		debufftype = debufftype,
		duration = duration,
		expiration = expiration,
		scale = (my and tonumber(db.myScale) + 1 or 1) * (tonumber(scale) or 1),
		durationSize = durationSize,
		stackSize = stackSize,
		id = id,
		EnemyBuff = EnemyBuff,
		spellId = spellId,
		glow = glow
	}
end

local function FilterBuffs(isAlly, frame, type, name, icon, stack, debufftype, duration, expiration, caster, spellId, id, nameplateID)
	if type == "HARMFUL" and db.showDebuffs == 5 then return end
	if type == "HELPFUL" and db.showBuffs == 5 then return end

	local Spells = db.Spells
	local listedSpell
	local my = caster == "player"
	local cachedID = cachedSpells[name]
	local EnemyBuff


	if Spells[spellId] and not db.ignoredDefaultSpells[spellId] then
		listedSpell = Spells[spellId]
	elseif cachedID then
		if cachedID == "noid" then
			listedSpell = Spells[name]
		else
			listedSpell = Spells[cachedID]
		end
	end
	
	if (listedSpell and (listedSpell.showBuff or listedSpell.showDebuff) and type == "HARMFUL") and listedSpell.showBuff then return end
	if (listedSpell and (listedSpell.showBuff or listedSpell.showDebuff) and type == "HELPFUL") and listedSpell.showDebuff then return end

	if listedSpell and listedSpell.RedifEnemy and caster and UnitIsEnemy("player", caster) then --still returns true for an enemy currently under mindcontrol I can add your fix.
		EnemyBuff = true
	else
		EnemyBuff = nil
	end

	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	--CLEU Deuff Timer
	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------
	--SmokeBomb Check For Arena
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 212183 then -- Smoke Bomb
		if caster and SmokeBombAuras[UnitGUID(caster)] then
			duration = SmokeBombAuras[UnitGUID(caster)].duration --Add a check, i rogue bombs in stealth there is a source but the cleu doesnt regester a time
			expiration = SmokeBombAuras[UnitGUID(caster)].expiration
		end
	end

	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	--CLEU Buff Timer
	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------
	--Barrier Add Timer Check For Arena
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 81782 then -- Barrier
		if caster and Barrier[UnitGUID(caster)] then
			duration = Barrier[UnitGUID(caster)].duration
			expiration = Barrier[UnitGUID(caster)].expiration
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--SGrounds Add Timer Check For Arena
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 289655 then -- SGrounds
		if caster and SGrounds[UnitGUID(caster)] then
			duration = SGrounds[UnitGUID(caster)].duration
			expiration = SGrounds[UnitGUID(caster)].expiration
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	-- Earthen Totem (Totems Need a Spawn Time Check)
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 201633 then -- Earthen Totem (Totems Need a Spawn Time Check)
		if caster then
			local guid = UnitGUID(caster)
			local spawnTime
			local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)
			if unitType == "Creature" or unitType == "Vehicle" then
			local spawnEpoch = GetServerTime() - (GetServerTime() % 2^23)
			local spawnEpochOffset = bit.band(tonumber(string.sub(spawnUID, 5), 16), 0x7fffff)
			spawnTime = spawnEpoch + spawnEpochOffset
			--print("Earthen Buff Check at: "..spawnTime)
			end
	    if Earthen[spawnTime] then
			duration = Earthen[spawnTime].duration
			expiration = Earthen[spawnTime].expiration
			end
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	-- Grounding (Totems Need a Spawn Time Check)
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 8178 then -- Grounding (Totems Need a Spawn Time Check)
		if caster then
			local guid = UnitGUID(caster)
			local spawnTime
			local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)
			if unitType == "Creature" or unitType == "Vehicle" then
			local spawnEpoch = GetServerTime() - (GetServerTime() % 2^23)
			local spawnEpochOffset = bit.band(tonumber(string.sub(spawnUID, 5), 16), 0x7fffff)
			spawnTime = spawnEpoch + spawnEpochOffset
			--print("Grounding Buff Check at: "..spawnTime)
			end
			if Grounding[spawnTime] then
			duration = Grounding[spawnTime].duration
			expiration = Grounding[spawnTime].expiration
			end
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	-- WarBanner (Totems Need a Spawn Time Check)
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 236321 then -- WarBanner (Totems Need a Spawn Time Check)
		if caster then
			local guid = UnitGUID(caster)
			local spawnTime
			local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)
			if unitType == "Creature" or unitType == "Vehicle" then
			local spawnEpoch = GetServerTime() - (GetServerTime() % 2^23)
			local spawnEpochOffset = bit.band(tonumber(string.sub(spawnUID, 5), 16), 0x7fffff)
			spawnTime = spawnEpoch + spawnEpochOffset
			--print("WarBanner Buff Check at: "..spawnTime)
			end
			if WarBanner[spawnTime] then
				--print("Spawn: "..UnitName(caster))
				duration = WarBanner[spawnTime].duration
				expiration = WarBanner[spawnTime].expiration
			elseif WarBanner[guid] then
				--print("guid: "..UnitName(caster))
				duration = WarBanner[guid].duration 
				expiration = WarBanner[guid].expiration
			elseif WarBanner[1] then
				--print("1: "..UnitName(caster))
				duration = WarBanner[1].duration
				expiration = WarBanner[1].expiration
			end
		else
			--print("WarBanner Nocaster")
			duration = WarBanner[1].duration 
			expiration = WarBanner[1].expiration
		end
	end



	-----------------------------------------------------------------------------------------------------------------
	--Two Buff Conditions Icy Veins Stacks
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 12472 then
		for i = 1, 40 do
			local _, _, c, _, d, e, _, _, _, s = UnitAura(nameplateID, id, type)
			if not s then break end
			if s == 382148 then
				stack = c
			end
		end
	end



	-----------------------------------------------------------------------------------------------------------------
	--Buff Icon Changes
	-----------------------------------------------------------------------------------------------------------------


	if spellId == 363916 then --Obsidian Scales w/Mettles
		local tooltipData = C_TooltipInfo.GetUnitAura(nameplateID, id, type)
		TooltipUtil.SurfaceArgs(tooltipData)

		for _, line in ipairs(tooltipData.lines) do
			TooltipUtil.SurfaceArgs(line)
		end
	   --print("Unit Aura: ", tooltipData.lines[1].leftText)
	   --print("Aura Info: ", tooltipData.lines[2].leftText)
	    if strfind(tooltipData.lines[2].leftText, "Immune") then
			icon = 1526594
		end
	end

	if spellId == 358267 then --Hover/Unburdened Flight
        local tooltipData = C_TooltipInfo.GetUnitAura(nameplateID, id, type)
        TooltipUtil.SurfaceArgs(tooltipData)

        for _, line in ipairs(tooltipData.lines) do
            TooltipUtil.SurfaceArgs(line)
        end
       --print("Unit Aura: ", tooltipData.lines[1].leftText)
       --print("Aura Info: ", tooltipData.lines[2].leftText)
        if strfind(tooltipData.lines[2].leftText, "Immune") then
            icon = 1029587
        end
    end

	if spellId == 319504 then --Finds Hemotoxin for Shiv
		local tooltipData = C_TooltipInfo.GetUnitAura(nameplateID, id, type)
		TooltipUtil.SurfaceArgs(tooltipData)

		for _, line in ipairs(tooltipData.lines) do
			TooltipUtil.SurfaceArgs(line)
		end
	   --print("Unit Aura: ", tooltipData.lines[1].leftText)
	   --print("Aura Info: ", tooltipData.lines[2].leftText)
		if strfind(tooltipData.lines[2].leftText, "35") then
			icon = 3610996
		else
			return 
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--Count Changes
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 1714  then --Amplify Curse's Tongues
		local tooltipData = C_TooltipInfo.GetUnitAura(nameplateID, id, type)
		TooltipUtil.SurfaceArgs(tooltipData)

		for _, line in ipairs(tooltipData.lines) do
			TooltipUtil.SurfaceArgs(line)
		end
		--print("Unit Aura: ", tooltipData.lines[1].leftText)
		--print("Aura Info: ", tooltipData.lines[2].leftText)
		if not strfind(tooltipData.lines[2].leftText, "10") then
			stack = 20
		else
			
		end
	end
	if spellId == 702 then --Amplify Curse's Weakness
		local tooltipData = C_TooltipInfo.GetUnitAura(nameplateID, id, type)
		TooltipUtil.SurfaceArgs(tooltipData)

		for _, line in ipairs(tooltipData.lines) do
			TooltipUtil.SurfaceArgs(line)
		end
		--print("Unit Aura: ", tooltipData.lines[1].leftText)
		--print("Aura Info: ", tooltipData.lines[2].leftText)
		if strfind(tooltipData.lines[2].leftText, "100") then
			stack = 100
		else
			
		end
	end
	if spellId == 334275 then --Amplify Curse's Exhaustion
		local tooltipData = C_TooltipInfo.GetUnitAura(nameplateID, id, type)
		TooltipUtil.SurfaceArgs(tooltipData)

		for _, line in ipairs(tooltipData.lines) do
			TooltipUtil.SurfaceArgs(line)
		end
		--print("Unit Aura: ", tooltipData.lines[1].leftText)
		--print("Aura Info: ", tooltipData.lines[2].leftText)
		if strfind(tooltipData.lines[2].leftText, "70") then
			stack = 70
		else
			
		end
	end




	-- showDebuffs  1 = all, 2 = mine + spellList, 3 = only spellList, 4 = only mine, 5 = none
	-- listedSpell.show  -- 1 = always, 2 = mine, 3 = never, 4 = on ally, 5 = on enemy

	if not listedSpell then
		if db.hidePermanent and duration == 0 then
			return
		end
		if (type == "HARMFUL" and (db.showDebuffs == 1 or ((db.showDebuffs == 2 or db.showDebuffs == 4) and my)))
		or (type == "HELPFUL"   and (db.showBuffs   == 1 or ((db.showBuffs   == 2 or db.showBuffs   == 4) and my))) then
			AddBuff(frame, type, icon, stack, debufftype, duration, expiration, my, id, spellId, EnemyBuff, nil, nil, nil, nil, nil)
			return
		else
			return
		end
	else --listedSpell
		if (type == "HARMFUL" and (db.showDebuffs == 4 and not my))
		or (type == "HELPFUL" and (db.showBuffs == 4 and not my)) then
			return
		end
		if((listedSpell.show == 1)
		or(listedSpell.show == 2 and my)
		or(listedSpell.show == 4 and isAlly)
		or(listedSpell.show == 5 and not isAlly)) and not listedSpell.spellDisableAura then
			AddBuff(frame, type, icon, stack, debufftype, duration, expiration, my, id, spellId, EnemyBuff, listedSpell.scale, listedSpell.durationSize, listedSpell.stackSize, listedSpell.IconId, listedSpell.IconGlow)
			return
		end
	end
end

local function ScanUnitBuffs(nameplateID, frame)

	if PlatesBuffs[frame] then
		wipe(PlatesBuffs[frame])
	end
	local isAlly = UnitIsFriend(nameplateID,"player")
	local id = 1
	while UnitDebuff(nameplateID,id) do
		local name, icon, stack, debufftype, duration, expiration, caster, _, _, spellId = UnitDebuff(nameplateID, id)
		FilterBuffs(isAlly, frame, "HARMFUL", name, icon, stack, debufftype, duration, expiration, caster, spellId, id, nameplateID)
		id = id + 1
	end

	id = 1
	while UnitBuff(nameplateID,id) do
		local name, icon, stack, debufftype, duration, expiration, caster, _, _, spellId = UnitBuff(nameplateID, id)
		FilterBuffs(isAlly, frame, "HELPFUL", name, icon, stack, debufftype, duration, expiration, caster, spellId, id, nameplateID)
		id = id + 1
	end
end

local function FilterUnits(nameplateID)

	-- filter units
	if UnitIsUnit(nameplateID,"player") then return true end
	if UnitIsPlayer(nameplateID) and not db.showOnPlayers then return true end
	if UnitPlayerControlled(nameplateID) and not UnitIsPlayer(nameplateID) and not db.showOnPets then return true end
	if not UnitPlayerControlled(nameplateID) and not UnitIsPlayer(nameplateID) and not db.showOnNPC then return true end
	if UnitIsEnemy(nameplateID,"player") and not db.showOnEnemy then return true end
	if UnitIsFriend(nameplateID,"player") and not db.showOnFriend then return true end
	if not UnitIsFriend(nameplateID,"player") and not UnitIsEnemy(nameplateID,"player") and not db.showOnNeutral then return true end

	return false
end

local total = 0
local function iconOnUpdate(self, elapsed)
	total = total + elapsed
	if total > 0 then
		total = 0
		if self.expiration and self.expiration > 0 then
			local timeLeft = self.expiration - GetTime()
			if timeLeft < 0 then
				-- local frame = self:GetParent():GetParent()
				-- self:Hide()
				-- UpdateUnitAuras(frame.namePlateUnitToken)
				return
			end
			if db.showDuration then
				self.durationtext:SetFormattedText(FormatTime(timeLeft))
				if db.colorTransition then
					self.durationtext:SetTextColor(GetColorByTime(timeLeft,self.duration))
				end
				if db.durationPosition == 1 or db.durationPosition == 3 then
					self.durationBg:SetWidth(self.durationtext:GetStringWidth())
					self.durationBg:SetHeight(self.durationtext:GetStringHeight())
				end
			end
			if (timeLeft / (self.duration + 0.01) ) < db.blinkTimeleft and timeLeft < 60 then --buff only has 20% timeleft and is less then 60 seconds.
				local f = GetTime() % 1
				if f > 0.5 then
					f = 1 - f
				end
				f = math.floor((f * 3) * 100)/100
				if f < 1 then
				self:SetAlpha(f)
				end
			end
		end
	end
end
local function GetTexCoordFromSize(frame,size,size2)
	local arg = size/size2
	local abj
	if arg > 1 then
		abj = 1/size*((size-size2)/2)

		frame:SetTexCoord(0 ,1,(0+abj),(1-abj))
	elseif arg < 1 then
		abj = 1/size2*((size2-size)/2)

		frame:SetTexCoord((0+abj),(1-abj),0,1)
	else
		frame:SetTexCoord(0, 1, 0, 1)
	end
end

local function UpdateBuffIcon(self, buff)
	self:EnableMouse(false)
	self:SetAlpha(1)
	self.stacktext:Hide()
	self.border:Hide()
	self.cooldown:Hide()
	self.durationtext:Hide()
	self.durationBg:Hide()

	self:SetWidth(self.width)
	self:SetHeight(self.height)


	self.texture:SetTexture(self.icon)
	if db.cropTexture then
		GetTexCoordFromSize(self.texture,self.width,self.height)
	else
		self.texture:SetTexCoord(0, 1, 0, 1)
	end

	-----------------------------------------------------------------------------------------------------------------
	----Destaurate Icon if RedifEnemy
	-----------------------------------------------------------------------------------------------------------------

	if self.EnemyBuff then --Smokebob Hue
		self.texture:SetDesaturated(1) --Destaurate Icon
		self.texture:SetVertexColor(1, .25, 0);
	else
		self.texture:SetDesaturated(nil) --Destaurate Icon
		self.texture:SetVertexColor(1, 1, 1);
	end


	if db.borderStyle ~= 3 then
		local color
		if self.type == "HELPFUL" then
			color = db.colorTypes.Buff
		else
			if db.colorizeBorder then
				color = self.debufftype and db.colorTypes[self.debufftype] or db.colorTypes.none
			else
				color = db.colorTypes.none
			end
		end
		self.border:SetVertexColor(color[1], color[2], color[3])
		self.border:Show()
	end

	if (db.showStdCooldown or db.showStdSwipe or db.blizzardCountdown) and self.expiration > 0 then
		local start, duration = self.cooldown:GetCooldownTimes()
		if (start ~= (self.expiration - self.duration)) or duration ~= self.durationthen then
			self.cooldown:SetCooldown(self.expiration - self.duration, self.duration)
		end
	end

	if db.showDuration and self.expiration > 0 then
		if db.durationPosition == 1 or db.durationPosition == 3 then
			self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "NORMAL")
			self.durationBg:Show()
		elseif (self.durationSize and self.durationSize >= 1) or (db.durationSize and db.durationSize >= 1) then
			self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "OUTLINE")
		end
		self.durationtext:Show()
	end

	if self.stack > 1 and type(tostring(self.stack)) == "string" then
		local text = tostring(self.stack)
		if db.stackSpecific and (self.stackSize and self.stackSize > 1) then
			self.stacktext:SetFont(fPB.stackFont, (self.stackSize), "OUTLINE")
			self.stacktext:SetText(text)
		elseif db.stackOverride then
			self.stacktext:SetFont(fPB.stackFont, (db.stackSize), "OUTLINE")
			self.stacktext:SetText(text)
		elseif db.stackScale then
			self.stacktext:SetFont(fPB.stackFont, (db.stackSize*self.scale), "OUTLINE")
			self.stacktext:SetText(text)
		else
			self.stacktext:SetFont(fPB.stackFont, (db.stackSize), "OUTLINE")
			self.stacktext:SetText(text)
		end

		self.stacktext:Show()
	end
end

local function UpdateBuffIconOptions(self, buff)
	self.texture:SetAllPoints(self)

	self.border:SetAllPoints(self)
	if db.borderStyle == 1 then
		self.border:SetTexture("Interface\\Addons\\flyPlateBuffs\\texture\\border.tga")
		self.border:SetTexCoord(0.08,0.08, 0.08,0.92, 0.92,0.08, 0.92,0.92)		--хз почему отображает не на всю иконку по дефолту, цифры подбором
	elseif db.borderStyle == 2 then
		self.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		self.border:SetTexCoord(0.296875,0.5703125,0,0.515625)		-- if "Interface\\Buttons\\UI-Debuff-Overlays"
	end
	if db.showStdSwipe then
		self.cooldown:SetDrawSwipe(true)
		self.cooldown:SetSwipeColor(0, 0, 0, 0.6)
	else
		self.cooldown:SetDrawSwipe(false)
	end

	if db.showStdCooldown and IsAddOnLoaded("OmniCC") then
		self.cooldown:SetScript("OnUpdate", nil)
		if self.cooldown._occ_display then self.cooldown._occ_display:Show() end
	elseif IsAddOnLoaded("OmniCC") then
		self.cooldown:SetScript("OnUpdate", function() if self.cooldown._occ_display and self.cooldown._occ_display:IsShown() then self.cooldown._occ_display:Hide() end end) --Hides OmniCC
	end

	if db.blizzardCountdown and not IsAddOnLoaded("OmniCC") then
		self.cooldown:SetHideCountdownNumbers(false)
	elseif IsAddOnLoaded("OmniCC") then
		self.cooldown:SetHideCountdownNumbers(true)
	else
		self.cooldown:SetHideCountdownNumbers(true) --Hides Blizzard
	end

	if db.showDuration then
		self.durationtext:ClearAllPoints()
		self.durationBg:ClearAllPoints()
		if db.durationPosition == 1 then
			-- under icon
			self.durationtext:SetPoint("TOP", self, "BOTTOM", db.durationSizeX, db.durationSizeY)
			self.durationBg:SetPoint("CENTER", self.durationtext)
		elseif db.durationPosition == 3 then
			-- above icon
			self.durationtext:SetPoint("BOTTOM", self, "TOP", db.durationSizeX, db.durationSizeY)
			self.durationBg:SetPoint("CENTER", self.durationtext)
		else
			-- on icon
			self.durationtext:SetPoint("CENTER", self, "CENTER", db.durationSizeX, db.durationSizeY)
		end
		if not colorTransition then
			self.durationtext:SetTextColor(db.colorSingle[1],db.colorSingle[2],db.colorSingle[3],1)
		end
	end

	self.stacktext:SetTextColor(db.stackColor[1],db.stackColor[2],db.stackColor[3],1)
	self.stacktext:ClearAllPoints()
	if db.stackPosition == 1 then
		-- on icon
		self.stacktext:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", db.stackSizeX*buff.scale, db.stackSizeY*buff.scale)
	elseif db.stackPosition == 2 then
		-- under icon
		self.stacktext:SetPoint("TOP", self, "BOTTOM", db.stackSizeX*buff.scale, db.stackSizeY*buff.scale)
	else
		-- above icon
		self.stacktext:SetPoint("BOTTOM", self, "TOP", db.stackSizeX*buff.scale, db.stackSizeY*buff.scale)
	end

end

local function iconOnHide(self)
	self.stacktext:Hide()
	self.border:Hide()
	self.cooldown:Hide()
	self.durationtext:Hide()
	self.durationBg:Hide()
end

local function CreateBuffIcon(frame,i,nameplateID)
	frame.fPBiconsFrame.iconsFrame[i] = CreateFrame("Button")
	frame.fPBiconsFrame.iconsFrame[i]:SetParent(frame.fPBiconsFrame)
	local buffIcon = frame.fPBiconsFrame.iconsFrame[i]
	local buff = PlatesBuffs[frame][i]

	buffIcon.texture = buffIcon:CreateTexture(nil, "BACKGROUND")

	buffIcon.border = buffIcon:CreateTexture(nil,"BORDER")

	buffIcon.cooldown = CreateFrame("Cooldown", "fPBCooldown"..nameplateID..i, buffIcon, "CooldownFrameTemplate")
	buffIcon.cooldown:SetReverse(true)
	buffIcon.cooldown:SetDrawEdge(false)

	buffIcon.durationtext = buffIcon:CreateFontString(nil, "ARTWORK")

	buffIcon.durationBg = buffIcon:CreateTexture(nil,"BORDER")
	buffIcon.durationBg:SetColorTexture(0,0,0,.75)

	buffIcon.stacktext = buffIcon:CreateFontString(nil, "ARTWORK")

	UpdateBuffIconOptions(buffIcon, buff)

	buffIcon.stacktext:Hide()
	buffIcon.border:Hide()
	buffIcon.cooldown:Hide()
	buffIcon.durationtext:Hide()
	buffIcon.durationBg:Hide()

	buffIcon:SetScript("OnHide", iconOnHide)
	buffIcon:SetScript("OnUpdate", iconOnUpdate)

	if MSQ then
		Group:AddButton(buffIcon,{
			Icon = buffIcon.texture,
			Cooldown = buffIcon.cooldown,
			Normal = buffIcon.border,
			Count = false,
			Duration = false,
			FloatingBG = false,
			Flash = false,
			Pushed = false,
			Disabled = false,
			Checked = false,
			Border = false,
			AutoCastable = false,
			Highlight = false,
			HotKey = false,
			Name = false,
			AutoCast = false,
		})
	end
end

local function UpdateUnitAuras(nameplateID,updateOptions)

	local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)
	if frame then
		frame.TPFrame  = _G["ThreatPlatesFrame" .. frame:GetName()]
		frame.unitFrame   = _G[frame:GetName().."PlaterUnitFrame"]
		if frame.TPFrame then frame = frame.TPFrame end
		if frame.unitFrame then frame = frame.unitFrame end
	end

	if not frame then return end 	-- modifying friendly nameplates is restricted in instances since 7.2
	if FilterUnits(nameplateID) then
		if frame.fPBiconsFrame then
			frame.fPBiconsFrame:Hide()
		end
		return
	end

	ScanUnitBuffs(nameplateID, frame)
	-----------------------------------------------------------------------------------------------------------------
	--ADDS CLEU FOUND BUFFS
	-----------------------------------------------------------------------------------------------------------------
	if not PlatesBuffs[frame] then
		if Interrupted[UnitGUID(nameplateID)] then
			for i = 1, #Interrupted[UnitGUID(nameplateID)] do
				if not PlatesBuffs[frame] then PlatesBuffs[frame] = {} end
				PlatesBuffs[frame][i] = Interrupted[UnitGUID(nameplateID)][i]
			end
		end
	else
		if Interrupted[UnitGUID(nameplateID)]  then
			for i = 1, #Interrupted[UnitGUID(nameplateID)] do
				PlatesBuffs[frame][#PlatesBuffs[frame] + 1] = Interrupted[UnitGUID(nameplateID)][i]
			end
	  end
	end
	-----------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------
	if not PlatesBuffs[frame] then
		if frame.fPBiconsFrame then
			frame.fPBiconsFrame:Hide()
		end
		return
	end
	if not db.disableSort then
		table_sort(PlatesBuffs[frame],SortFunc)
	end

	if not frame.fPBiconsFrame then
		-- if parent == frame then it will change scale and alpha with nameplates
		-- otherwise use UIParent, but this causes mess of icon/border textures
		frame.fPBiconsFrame = CreateFrame("Frame")
		local parent = db.parentWorldFrame and WorldFrame
		if not parent then
			parent = frame.TPFrame -- for ThreatPlates
		end
		if not parent then
			parent = frame.unitFrame -- for Plater
		end
		if not parent then
			parent = frame
		end
		anchor = "ThreatPlatesFrame"..nameplateID -- for ThreatPlates
		anchor = nameplateID.."PlaterUnitFrame" -- for Plater
		frame.fPBiconsFrame:SetParent(parent)
	end
	if not frame.fPBiconsFrame.iconsFrame then
		frame.fPBiconsFrame.iconsFrame = {}
	end


 	for i = 1, #PlatesBuffs[frame] do
		if not frame.fPBiconsFrame.iconsFrame[i] then
			CreateBuffIcon(frame,i,nameplateID)
		end

		local buff = PlatesBuffs[frame][i]
		local buffIcon = frame.fPBiconsFrame.iconsFrame[i]
		buffIcon.type = buff.type
		buffIcon.icon = buff.icon
		buffIcon.stack = buff.stack
		buffIcon.debufftype = buff.debufftype
		buffIcon.duration = buff.duration
		buffIcon.expiration = buff.expiration
		buffIcon.id = buff.id
		buffIcon.durationSize = buff.durationSize
		buffIcon.stackSize = buff.stackSize
		buffIcon.width = db.baseWidth * buff.scale
		buffIcon.height = db.baseHeight * buff.scale
		buffIcon.EnemyBuff = buff.EnemyBuff
		buffIcon.spellId = buff.spellId
		buffIcon.scale = buff.scale
		buffIcon.glow = buff.glow

		if updateOptions then
			UpdateBuffIconOptions(buffIcon, buff)
		end
		UpdateBuffIcon(buffIcon, buff)

		-------------------------------------------------------------------------------------------------------------------
		--Glow
		-------------------------------------------------------------------------------------------------------------------
		if buffIcon.glow then -- or buffIcon.spellId == 377362) then --Ultimate Sac Glow
			ActionButton_ShowOverlayGlow(buffIcon, buff.scale)
		else
			ActionButton_HideOverlayGlow(buffIcon)
		end

		buffIcon:Show()
	end
	frame.fPBiconsFrame:Show()

	if #frame.fPBiconsFrame.iconsFrame > #PlatesBuffs[frame] then
		for i = #PlatesBuffs[frame]+1, #frame.fPBiconsFrame.iconsFrame do
			if frame.fPBiconsFrame.iconsFrame[i] then
				frame.fPBiconsFrame.iconsFrame[i]:Hide()
				ActionButton_HideOverlayGlow(frame.fPBiconsFrame.iconsFrame[i])
			end
		end
	end

	DrawOnPlate(frame)
end

local creatureId = {

	[27829] = {25 , 132182}, --Ebon Gargoyle

	[1964] = {10, 132129}, --Treant
	[103822] = {10, 132129}, --Treant
	[54983] = {15, 132129}, --Grove Guardians

	[510] = {45, 135862}, --Water Elemental
	[31216] = {40, 135994}, --Mirrorr Image

	[19668] = {15, 136199}, --Shadowfiend
	[62982] = {15, 136214}, --Minbender
	[101398] = {12, 537021}, --Psyfiend

	[95072] = {60, 136024}, --Greater Earth Elemntal
	[61056] = {60, 136024}, --Primal Earth Elemntal
	[95061] = {30, 135790}, --Greater Fire Elemntal
	[61029] = {30, 135790}, --Primal Fire Elemntal
	[77942] = {30, 2065626}, --Greater Storm Elemntal
	[77936] = {30, 2065626}, --Primal Storm Elemntal
	[29264] = {15, 237577}, --Spirit Wolf
	[100820] = {15, 237577}, --Spirit Wolf
	['Spirit Wolf'] = {15, 237577}, --Spirit Wolf

	["Infernal"] = {30, 136219}, --Infernal
	[135002] = {15, 2065628}, --Demonic Tyrant
	[196111] = {10, 236423}, --Pit Lord
	[179193] = {15, 1718002}, --Fel Obelisk

--Pets--
	[26125] = {0, 237511}, --Raise Ghoul
	[1863] = {0, 136220}, --Succubas
	[185317] = {0, 136220}, --Inncubas
	[417] = {0, 136217}, --Fel hunter
	[416] = {0, 136218}, --Imp
	[1860] = {0, 136221}, --Voidwalker
	[58965] = {0, 136216}, --Grimoire: Felguard
	[12752] = {0, 136216}, --Grimoire: Felguard
	[17252] = {0, 136216}, --Grimoire: Felguard

}

function fPB.UpdateAllNameplates(updateOptions)
	for i, p in ipairs(C_NamePlate_GetNamePlates()) do
		local unit = p.namePlateUnitToken
		if not unit then --try ElvUI
			unit = p.unitFrame and p.unitFrame.unit
		end
		if unit then
			UpdateUnitAuras(unit,updateOptions)
		end
	end
end
local UpdateAllNameplates = fPB.UpdateAllNameplates

local function Nameplate_Added(...)
	local nameplateID = ...
	local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)
	local guid = UnitGUID(nameplateID)

	--disable blizzard Auras on nameplates
	local Blizzardframe = frame.UnitFrame
	if not frame or Blizzardframe:IsForbidden() then return end
	Blizzardframe.BuffFrame:ClearAllPoints()
	Blizzardframe.BuffFrame:SetAlpha(0)

	local unitType, _, _, _, _, ID, spawnUID = strsplit("-", guid)
	if unitType == "Creature" or unitType == "Vehicle" or unitType == "Pet" then --and UnitIsEnemy("player" , nameplateID) then --or unitType == "Pet"  then
		local spawnEpoch = GetServerTime() - (GetServerTime() % 2^23)
		local spawnEpochOffset = bit_band(tonumber(substring(spawnUID, 5), 16), 0x7fffff)
		local spawnTime = spawnEpoch + spawnEpochOffset
		local nameCreature = UnitName(nameplateID)
		local type,  debufftype
		if UnitIsEnemy("player" , nameplateID) then 
			type = "HARMFUL"
			debufftype = "none"
		else
			type = "HELPFUL"
			debufftype = "Buff"
		end
		local duration, expiration, icon, scale, tracked, seen, glow
		local stack = 0
		-- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
		--if unitType == "Creature" or unitType == "Vehicle" then scale = 1.3 elseif unitType =="Pet" then scale = 1.1 end
		local durationSize 
		local stackSize 
		local id = 1 --Need to figure this out
		local upTime = tonumber((GetServerTime() % 2^23) - (spawnTime % 2^23))
		--print(nameCreature.." "..unitType..":"..ID.." alive for: "..((GetServerTime() % 2^23) - (spawnTime % 2^23)))

		local Spells = db.Spells
		local listedSpell


		if Spells[ID] and not db.ignoredDefaultSpells[ID] then
			listedSpell = Spells[ID]
		elseif Spells[nameCreature] and not db.ignoredDefaultSpells[ID] then
			listedSpell = Spells[nameCreature]
		end

		if listedSpell and listedSpell.spellTypeNPC then
			scale = listedSpell.scale  or 1
			durationSize = listedSpell.durationSize or 13
			stackSize = listedSpell.stackSize or 10
			icon = listedSpell.spellId or 134400
			duration = listedSpell.durationCLEU or 0
			glow = listedSpell.IconGlow
		else 
			
		end

		if icon then
			expiration = GetTime() + (duration - upTime)
			if not Interrupted[guid] then
				Interrupted[guid] = {}
			end
			if Interrupted[guid] then
				for k, v in pairs(Interrupted[guid]) do
					if v.ID then
						seen = true
						break
					end
				end
			end
			if not seen then
				if duration == 0 then --Permanent
					expiration = 0;	duration = 0
				end
				--print(nameCreature.." "..unitType..":"..ID.." alive for: "..upTime)
				local tablespot = #Interrupted[guid] + 1
				tblinsert (Interrupted[guid], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype,duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, glow = glow, ["ID"] = ID})
				if duration ~= 0 and duration - (GetServerTime() - spawnTime) > 0 then
					Ctimer(duration - (GetServerTime() - spawnTime) , function()
						if Interrupted[guid] then
							Interrupted[guid][tablespot] = nil
							UpdateAllNameplates()
						end
					end)
				else
					frame.fPBtimer = C_Timer.NewTicker(1, function()
						local unitToken = UnitTokenFromGUID(guid)
						if not unitToken then
							if Interrupted[guid] then
								Interrupted[guid][tablespot] = nil
								UpdateAllNameplates()
							end
							frame.fPBtimer:Cancel()
						end
					end)
				end
			end
		end
	end
	UpdateUnitAuras(nameplateID)
end

local function Nameplate_Removed(...)
	local nameplateID = ...
	local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)

	if frame.fPBiconsFrame then
		frame.fPBiconsFrame:Hide()
	end
	if PlatesBuffs[frame] then
		PlatesBuffs[frame] = nil
	end
end

local function FixSpells()
	for spell,s in pairs(db.Spells) do
		if not s.name then
			local name
			local spellId = tonumber(spell) and tonumber(spell) or spell.spellId
			if spellId then
				name = GetSpellInfo(spellId)
			else
				name = tostring(spell)
			end
			db.Spells[spell].name = name
		end
	end
end

function fPB.CacheSpells() -- spells filtered by names, not checking id
	cachedSpells = {}
	for spell,s in pairs(db.Spells) do
		if not s.checkID and not db.ignoredDefaultSpells[spell] and s.name then
			if s.spellId then
				cachedSpells[s.name] = s.spellId
			else
				cachedSpells[s.name] = "noid"
			end
		end
	end
end
local CacheSpells = fPB.CacheSpells

function fPB.AddNewSpell(spell, npc)
	local defaultSpell, name
	if db.ignoredDefaultSpells[spell] then
		db.ignoredDefaultSpells[spell] = nil
		defaultSpell = true
	end
	local spellId = tonumber(spell)
	if db.Spells[spell] and not defaultSpell then
		if spellId then
			DEFAULT_CHAT_FRAME:AddMessage(chatColor..L["Spell with this ID is already in the list. Its name is "]..linkColor.."|Hspell:"..spellId.."|h["..GetSpellInfo(spellId).."]|h|r")
			return
		else
			DEFAULT_CHAT_FRAME:AddMessage(spell..chatColor..L[" already in the list."].."|r")
			return
		end
	end

	if not npc then
		name = GetSpellInfo(spellId)
	end
	if spellId and name then
		if not db.Spells[spellId] then
			db.Spells[spellId] = {
				show = 1,
				name = name,
				spellId = spellId,
				scale = 1,
				stackSize = db.stackSize,
				durationSize = db.durationSize,
			}
		end
	elseif npc then
		print("fPB Added NPC: "..spell)
		db.Spells[spell] = {
			show = 1,
			name = spell,
			scale = 1,
			stackSize = db.stackSize,
			durationSize = db.durationSize,
			spellTypeNPC = true,
		}
	else
		db.Spells[spell] = {
			show = 1,
			name = spell,
			scale = 1,
			stackSize = db.stackSize,
			durationSize = db.durationSize,
		}
	end
	CacheSpells()
	if not npc then
		fPB.BuildSpellList()
	else
		fPB.BuildNPCList()
	end
	UpdateAllNameplates(true)
end
function fPB.RemoveSpell(spell)
	if DefaultSettings.profile.Spells[spell] then
		db.ignoredDefaultSpells[spell] = true
	end
	db.Spells[spell] = nil
	CacheSpells()
	fPB.BuildSpellList()
	fPB.BuildNPCList()
	UpdateAllNameplates(true)
end
function fPB.ChangespellId(oldID, newID, npc)
	if db.Spells[newID] then
		DEFAULT_CHAT_FRAME:AddMessage(chatColor..L["Spell with this ID is already in the list. Its name is "]..linkColor.."|Hspell:"..newID.."|h["..GetSpellInfo(newID).."]|h|r")
		return
	end
	db.Spells[newID] = {}
	for k,v in pairs(db.Spells[oldID]) do
		db.Spells[newID][k] = v
		db.Spells[newID].spellId = newID
	end
	fPB.RemoveSpell(oldID)
	DEFAULT_CHAT_FRAME:AddMessage(GetSpellInfo(newID)..chatColor..L[" ID changed "].."|r"..(tonumber(oldID) or "nil")..chatColor.." -> |r"..newID)
	UpdateAllNameplates(true)
	fPB.BuildSpellList()
end

local function ConvertDBto2()
	local temp
	for _,p in pairs(flyPlateBuffsDB.profiles) do
		if p.Spells then
			temp = {}
			for n,s in pairs(p.Spells) do
				local spellId = s.spellId
				if not spellId then
					for i=1, #defaultSpells1 do
						if n == GetSpellInfo(defaultSpells1[i]) then
							spellId = defaultSpells1[i]
							break
						end
					end
				end
				if not spellId then
					for i=1, #defaultSpells2 do
						if n == GetSpellInfo(defaultSpells2[i]) then
							spellId = defaultSpells2[i]
							break
						end
					end
				end
				local spell = spellId and spellId or n
				if spell then
					temp[spell] = {}
					for k,v in pairs(s) do
						temp[spell][k] = v
					end
					temp[spell].name = GetSpellInfo(spellId) and GetSpellInfo(spellId) or n
				end
			end
			p.Spells = temp
			temp = nil
		end
		if p.ignoredDefaultSpells then
			temp = {}
			for n,v in pairs(p.ignoredDefaultSpells) do
				local spellId
				for i=1, #defaultSpells1 do
					if n == GetSpellInfo(defaultSpells1[i]) then
						spellId = defaultSpells1[i]
						break
					end
				end
				if not spellId then
					for i=1, #defaultSpells2 do
						if n == GetSpellInfo(defaultSpells2[i]) then
							spellId = defaultSpells2[i]
							break
						end
					end
				end
				if spellId then
					temp[spellId] = true
				end
			end
			p.ignoredDefaultSpells = temp
			temp = nil
		end
	end
	flyPlateBuffsDB.version = 2
end
function fPB.OnProfileChanged()
	db = fPB.db.profile
	fPB.OptionsOnEnable()
	UpdateAllNameplates(true)
end
local function Initialize()
	if flyPlateBuffsDB and (not flyPlateBuffsDB.version or flyPlateBuffsDB.version < 2) then
		ConvertDBto2()
	end

	fPB.db = LibStub("AceDB-3.0"):New("flyPlateBuffsDB", DefaultSettings, true)
	fPB.db.RegisterCallback(fPB, "OnProfileChanged", "OnProfileChanged")
	fPB.db.RegisterCallback(fPB, "OnProfileCopied", "OnProfileChanged")
	fPB.db.RegisterCallback(fPB, "OnProfileReset", "OnProfileChanged")

	db = fPB.db.profile
	fPB.font = fPB.LSM:Fetch("font", db.font)
	fPB.stackFont = fPB.LSM:Fetch("font", db.stackFont)
	FixSpells()
	CacheSpells()

	config:RegisterOptionsTable(AddonName, fPB.MainOptionTable)
	config:RegisterOptionsTable(AddonName.." Options", fPB.OptionsOpen)
	fPBMainOptions = dialog:AddToBlizOptions(AddonName.." Options", AddonName)

	config:RegisterOptionsTable(AddonName.." Spells", fPB.SpellsTable)
	--fPBSpellsList = dialog:AddToBlizOptions(AddonName.." Spells", L["Specific spells"], AddonName)

	config:RegisterOptionsTable(AddonName.." Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(fPB.db))
	fPBProfilesOptions = dialog:AddToBlizOptions(AddonName.." Profiles", L["Profiles"], AddonName)

	SLASH_FLYPLATEBUFFS1, SLASH_FLYPLATEBUFFS2 = "/fpb", "/pb"
	function SlashCmdList.FLYPLATEBUFFS(msg, editBox)
		--InterfaceOptionsFrame_OpenToCategory(fPBMainOptions)
		--InterfaceOptionsFrame_OpenToCategory(fPBSpellsList)
		--InterfaceOptionsFrame_OpenToCategory(fPBMainOptions)
		dialog:Open(AddonName)
	end
end

function fPB.RegisterCombat()
	fPB.Events:RegisterEvent("PLAYER_REGEN_DISABLED")
	fPB.Events:RegisterEvent("PLAYER_REGEN_ENABLED")
end
function fPB.UnregisterCombat()
	fPB.Events:UnregisterEvent("PLAYER_REGEN_DISABLED")
	fPB.Events:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

fPB.Events = CreateFrame("Frame")
fPB.Events:RegisterEvent("ADDON_LOADED")
fPB.Events:RegisterEvent("PLAYER_LOGIN")

fPB.Events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" and (...) == AddonName then
		Initialize()
	elseif event == "PLAYER_LOGIN" then
		fPB.OptionsOnEnable()
		Print(format("Type %s or %s to open the options panel.", Colorize("/fPB", "accent"), Colorize("/pb", "accent")))
		if db.blizzardCountdown then
			SetCVar("countdownForCooldowns", 1)
		end
		MSQ = LibStub("Masque", true)
		if MSQ then
			Group = MSQ:Group(AddonName)
			MSQ:Register(AddonName, function(addon, group, skinId, gloss, backdrop, colors, disabled)
				if disabled then
					UpdateAllNameplates(true)
				end
			end)
		end

		fPB.Events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		fPB.Events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		fPB.Events:RegisterEvent("UNIT_AURA")
		fPB.Events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	elseif event == "PLAYER_REGEN_DISABLED" then
		fPB.Events:RegisterEvent("UNIT_AURA")
		UpdateAllNameplates()
	elseif event == "PLAYER_REGEN_ENABLED" then
		fPB.Events:UnregisterEvent("UNIT_AURA")
		UpdateAllNameplates()
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		Nameplate_Added(...)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		Nameplate_Removed(...)
	elseif event == "UNIT_AURA" then
		if strmatch((...),"nameplate%d+") then
			UpdateUnitAuras(...)
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		fPB:CLEU()
	end
end)

local interruptsIds = {
	[47528]  = 3,		-- Mind Freeze (Death Knight)
	[91802]  = 2,		-- Shambling Rush (Death Knight)
	[91807] =  2,  		-- Shambling Rush
	[183752] = 3,		-- Disrupt (Demon Hunter)
	[93985]  = 3,		-- Skull Bash
	[97547]  = 5,		-- Solar Beam (Druid Balance)
	[351338] = 4,		-- Quell (Evoker)
	[147362] = 3,		-- Countershot (Hunter)
	[187707] = 3,		-- Muzzle (Hunter)
	[2139]   = 5,		-- Counterspell (Mage)
	[116705] = 3,		-- Spear Hand Strike (Monk)
	[96231]  = 3,		-- Rebuke (Paladin)
	[231665] = 3,		-- Avengers Shield (Paladin)
	[217824] = 4,		-- Shield of Virtue (Protec Paladin)
	[1766]   = 3,		-- Kick (Rogue)
	[57994]  = 2,		-- Wind Shear (Shaman)
	[19647]  = 5,		-- Spell Lock (felhunter) (Warlock)
	[132409] = 5,		-- Spell Lock (command demon) (Warlock)
	[115781] = 5,		-- Optical Blast (Warlock)
	[212619] = 5,		-- Call Felhunter (Warlock)
	[347008] = 3,		-- Axe Toss(felguard) (Warlock)(4 for PVE, 3 for PVP)
	[6552]   = 3,		-- Pummel (Warrior)

	--[11972] =  3,  		--Shield Bash (testing Purposes in Northern barrens)

}

local castedAuraIds = {
	[202770] = 8, --Fury of Elune
	[202359] = 6, --Astral Communion
}

-- Function to check if pvp talents are active for the player
local function ArePvpTalentsActive()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "pvp" or instanceType == "arena") then
        return true
    elseif inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario") then
        return false
    else
        local talents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
        for _, pvptalent in pairs(talents) do
            local spellID = select(6, GetPvpTalentInfoByID(pvptalent))
            if IsPlayerSpell(spellID) then
                return true
            end
        end
    end
end

local function interruptDuration(destGUID, duration)
	local unit
	for i, p in ipairs(C_NamePlate_GetNamePlates()) do
		unit = p.namePlateUnitToken
		if (destGUID == UnitGUID(unit)) then
			break
		end
	end
	local duration3 = duration
	if (unit ~= nil) then
		local duration3 = duration
		local shamTranquilAirBuff = false
		local _, destClass = GetPlayerInfoByGUID(destGUID)
		for i = 1, 120 do
			local _, _, _, _, _, _, _, _, _, auxSpellId = UnitAura(unit, i, "HELPFUL")
			if not auxSpellId then break end
			if (destClass == "DRUID") then
				if auxSpellId == 234084 then	-- Moon and Stars (Druid) [Interrupted Mechanic Duration -70% (stacks)]
					duration = duration * 0.5
				end
			end
			if auxSpellId == 317920 then		-- Concentration Aura (Paladin) [Interrupted Mechanic Duration -30% (stacks)]
				duration = duration * 0.7
			elseif auxSpellId == 383020 then	-- Tranquil Air (Shaman) [Interrupted Mechanic Duration -50% (doesn't stack)]
				shamTranquilAirBuff = true
			end
		end
		for i = 1, 120 do
			local _, _, _, _, _, _, _, _, _, auxSpellId = UnitAura(unit, i, "HARMFUL")
			if not auxSpellId then break end
			if auxSpellId == 372048 then	-- Oppressing Roar (Evoker) [Interrupted Mechanic Duration +30%/+50% (PvP/PvE) (stacks)]
				if ArePvpTalentsActive() then
					duration = duration * 1.3
					duration3 = duration3 * 1.3
				else
					duration = duration * 1.5
					duration3 = duration3 * 1.5
				end
			end
		end
		if (shamTranquilAirBuff) then
			duration3 = duration3 * 0.5
			if (duration3 < duration) then
				duration = duration3
			end
		end
	end
	return duration
end


local function ObjectDNE(guid) --Used for Infrnals and Ele
	local tooltipData =  C_TooltipInfo.GetHyperlink('unit:' .. guid or '')
	TooltipUtil.SurfaceArgs(tooltipData)

	for _, line in ipairs(tooltipData.lines) do
		TooltipUtil.SurfaceArgs(line)
	end

	if #tooltipData.lines == 1 then -- Fel Obelisk
		return "Despawned"
	end

	for i = 1, #tooltipData.lines do 
 		local text = tooltipData.lines[i].leftText
		 if text and (type(text == "string")) then
			--print(i.." "..text)
			if strfind(text, "Level ??") or strfind(text, "Corpse") then 
				return "Despawned"
			end
		end
	end
end


function fPB:CLEU()
	local _, event, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellId, _, _, _, _, spellSchool = CombatLogGetCurrentEventInfo()
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	--CLEU Deuff Timer
	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-----------------------------------------------------------------------------------------------------------------
	--SmokeBomb Check
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_CAST_SUCCESS") and (spellId == 212182 or spellId == 359053)) then
		if (sourceGUID ~= nil) then
			local duration = 5
			local expiration = GetTime() + duration
			if (SmokeBombAuras[sourceGUID] == nil) then
				SmokeBombAuras[sourceGUID] = {}
			end
			SmokeBombAuras[sourceGUID] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + 1, function()	-- execute in some close next frame to accurate use of UnitAura function
				SmokeBombAuras[sourceGUID] = nil
				UpdateAllNameplates()
			end)
		end
	end
		
	--------------------------------------------------------------------------------------------------------------------------------------------------------------
	--CLEU Buff Timer
	--------------------------------------------------------------------------------------------------------------------------------------------------------------

	-----------------------------------------------------------------------------------------------------------------
	--Barrier Check
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_CAST_SUCCESS") and (spellId == 62618)) then
		if (sourceGUID ~= nil) then
			local duration = 10
			local expiration = GetTime() + duration
			if (Barrier[sourceGUID] == nil) then
				Barrier[sourceGUID] = {}
			end
			Barrier[sourceGUID] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + 1, function()	-- execute iKn some close next frame to accurate use of UnitAura function
				Barrier[sourceGUID] = nil
			end)
			Ctimer(.2, function()	-- execute a second timer to ensure it catches
				UpdateAllNameplates()
			end)
		end
		UpdateAllNameplates()
	end

	-----------------------------------------------------------------------------------------------------------------
	--SGrounds Check
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_CAST_SUCCESS") and (spellId == 34861)) then
		if (sourceGUID ~= nil) then
			local duration = 5
			local expiration = GetTime() + duration
			if (SGrounds[sourceGUID] == nil) then
				SGrounds[sourceGUID] = {}
			end
			SGrounds[sourceGUID] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + 1, function()	-- execute iKn some close next frame to accurate use of UnitAura function
				SGrounds[sourceGUID] = nil
			end)
			Ctimer(.2, function()	-- execute a second timer to ensure it catches
				UpdateAllNameplates()
			end)
		end
		UpdateAllNameplates()
	end

	-----------------------------------------------------------------------------------------------------------------
	--Earthen Check (Totems Need a Spawn Time Check)
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_SUMMON") or (event == "SPELL_CREATE")) and (spellId == 198838) then
		if (destGUID ~= nil) then
			local duration = 18 --Totemic Focus Makes it 18
			local guid = destGUID
			local spawnTime
			local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)
			if unitType == "Creature" or unitType == "Vehicle" then
			local spawnEpoch = GetServerTime() - (GetServerTime() % 2^23)
			local spawnEpochOffset = bit.band(tonumber(string.sub(spawnUID, 5), 16), 0x7fffff)
			spawnTime = spawnEpoch + spawnEpochOffset
			--print("Earthen Totem Spawned at: "..spawnTime)
			end
			local expiration = GetTime() + duration
			if (Earthen[spawnTime] == nil) then --source becomes the totem ><
				Earthen[spawnTime] = {}
			end
			Earthen[spawnTime] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + .2, function()	-- execute in some close next frame to accurate use of UnitAura function
			Earthen[spawnTime] = nil
			end)
			Ctimer(.2, function()	-- execute a second timer to ensure it catches
				UpdateAllNameplates()
			end)
		end
		UpdateAllNameplates()
	end

	-----------------------------------------------------------------------------------------------------------------
	--Grounding Check (Totems Need a Spawn Time Check)
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_SUMMON") or (event == "SPELL_CREATE")) and (spellId == 204336) then
		if (destGUID ~= nil) then
			local duration = 3
			local guid = destGUID
			local spawnTime
			local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)
			if unitType == "Creature" or unitType == "Vehicle" then
			local spawnEpoch = GetServerTime() - (GetServerTime() % 2^23)
			local spawnEpochOffset = bit.band(tonumber(string.sub(spawnUID, 5), 16), 0x7fffff)
			spawnTime = spawnEpoch + spawnEpochOffset
			--print("Grounding Totem Spawned at: "..spawnTime)
			end
			local expiration = GetTime() + duration
			if (Grounding[spawnTime] == nil) then --source becomes the totem ><
				Grounding[spawnTime] = {}
			end
			Grounding[spawnTime] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + .2, function()	-- execute in some close next frame to accurate use of UnitAura function
			Grounding[spawnTime] = nil
			end)
			Ctimer(.2, function()	-- execute a second timer to ensure it catches
				UpdateAllNameplates()
			end)
		end
		UpdateAllNameplates()
	end

	-----------------------------------------------------------------------------------------------------------------
	--WarBanner Check (Totems Need a Spawn Time Check)
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_SUMMON") or (event == "SPELL_CREATE")) and (spellId == 236320) then
		if (destGUID ~= nil) then
			local duration = 15
			local expiration = GetTime() + duration
			if (WarBanner[destGUID] == nil) then
				WarBanner[destGUID] = {}
			end
			WarBanner[destGUID] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + 1, function()	-- execute in some close next frame to accurate use of UnitAura function
				WarBanner[destGUID] = nil
				UpdateAllNameplates()
			end)
		end
		if (destGUID ~= nil) then
			local duration = 15
			local expiration = GetTime() + duration
			if (WarBanner[1] == nil) then
				WarBanner[1] = {}
			end
			WarBanner[1] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + 1, function()	-- execute in some close next frame to accurate use of UnitAura function
				WarBanner[1] = nil
				UpdateAllNameplates()
			end)
		end
		if (destGUID ~= nil) then
			local duration = 15
			local guid = destGUID
			local spawnTime
			local unitType, _, _, _, _, _, spawnUID = strsplit("-", guid)
			if unitType == "Creature" or unitType == "Vehicle" then
			local spawnEpoch = GetServerTime() - (GetServerTime() % 2^23)
			local spawnEpochOffset = bit.band(tonumber(string.sub(spawnUID, 5), 16), 0x7fffff)
			spawnTime = spawnEpoch + spawnEpochOffset
			--print("WarBanner Totem Spawned at: "..spawnTime)
			end
			local expiration = GetTime() + duration
			if (WarBanner[spawnTime] == nil) then --source becomes the totem ><
				WarBanner[spawnTime] = {}
			end
			WarBanner[spawnTime] = { ["duration"] = duration, ["expiration"] = expiration }
			Ctimer(duration + .2, function()	-- execute in some close next frame to accurate use of UnitAura function
				WarBanner[spawnTime] = nil
			end)
			Ctimer(.2, function()	-- execute a second timer to ensure it catches
				UpdateAllNameplates()
			end)
		end
		UpdateAllNameplates()
	end

	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	local Spells = db.Spells
	local name = GetSpellInfo(spellId)
	local cachedID = cachedSpells[name]
	local listedSpell

	if Spells[spellId] and not db.ignoredDefaultSpells[spellId] then
		listedSpell = Spells[spellId]
	elseif cachedID then
		if cachedID == "noid" then
			listedSpell = Spells[name]
		else
			listedSpell = Spells[cachedID]
		end
	end

	local isAlly, EnemyBuff

	-----------------------------------------------------------------------------------------------------------------
	--Summoned Spells Check
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_SUMMON") or (event == "SPELL_CREATE"))  then --Summoned CDs
	--print(sourceName.." "..spellId.." Summoned "..substring(destGUID, -7).." fPB")
		if listedSpell and listedSpell.spellTypeSummon then
			if sourceGUID and (bit_band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) then isAlly = false else isAlly = true end
			local guid = destGUID
			local duration = listedSpell.durationCLEU or 1
			local type = "HELPFUL"
			local namePrint, _, icon = GetSpellInfo(spellId)
			if listedSpell.IconId then icon = listedSpell.IconId end
			if listedSpell.RedifEnemy and not isAlly then EnemyBuff = true end

			local my = sourceGUID == UnitGUID("player")
			local stack = 0
			local debufftype = "Buff" -- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
			local expiration = GetTime() + duration
			local scale = listedSpell.scale
			local durationSize = listedSpell.durationSize
			local stackSize = listedSpell.stackSize
			local glow = listedSpell.IconGlow
			local id = 1 --Need to figure this out
			if not Interrupted[sourceGUID] then
				Interrupted[sourceGUID] = {}
			end
			if(listedSpell.show == 1)
			or(listedSpell.show == 2 and my)
			or(listedSpell.show == 4 and isAlly)
			or(listedSpell.show == 5 and not isAlly) then
				--print(sourceName.." Summoned "..namePrint.." "..substring(destGUID, -7).." for "..duration.." fPB")
				local tablespot = #Interrupted[sourceGUID] + 1
				tblinsert (Interrupted[sourceGUID], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype,	duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, EnemyBuff = EnemyBuff, sourceGUID = sourceGUID, glow = glow, ["destGUID"] = destGUID, ["sourceName"] = sourceName, ["namePrint"] = namePrint, ["expiration"] = expiration, ["spellId"] = spellId})
				UpdateAllNameplates()
				local ticker = 1
				Ctimer(duration, function()
					if Interrupted[sourceGUID] then
						for k, v in pairs(Interrupted[sourceGUID]) do
							if v.spellId == spellId then
								--print(v.sourceName.." Timed Out "..v.namePrint.." "..substring(v.destGUID, -7).." left w/ "..string.format("%.2f", v.expiration-GetTime()).." fPB C_Timer")
								Interrupted[sourceGUID][k] = nil
								UpdateAllNameplates()
							end
						end
					end
				end)
				local iteration, check
				iteration = duration * 10 + 5; check = .1
				self.ticker = C_Timer.NewTicker(check, function()
					local name = GetSpellInfo(spellId)
					if Interrupted[sourceGUID] then
						for k, v in pairs(Interrupted[sourceGUID]) do
							if v.destGUID and v.spellId ~= 394243 and v.spellId ~= 387979 and v.spellId ~= 394235 then --Dimensional Rift Hack
								if substring(v.destGUID, -5) == substring(guid, -5) then --string.sub is to help witj Mirror Images bug
									if ObjectDNE(v.destGUID, ticker, v.namePrint, v.sourceName) then
										--print(v.sourceName.." "..ObjectDNE(v.destGUID, ticker, v.namePrint, v.sourceName).." "..v.namePrint.." "..substring(v.destGUID, -7).." left w/ "..string.format("%.2f", v.expiration-GetTime()).." fPB C_Ticker")
										Interrupted[sourceGUID][k] = nil
										UpdateAllNameplates()
										self.ticker:Cancel()
										break
									end
								end
							end
						end
					end
					ticker = ticker + 1
				end, iteration)
			end
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--Casted  CDs w/o Aura (fury of Elune)
	-----------------------------------------------------------------------------------------------------------------
	if (event == "SPELL_CAST_SUCCESS") then 
		if listedSpell and listedSpell.spellTypeCastedAuras then
			if sourceGUID and (bit_band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) then isAlly = false else isAlly = true end
			local duration = listedSpell.durationCLEU or 1
			local type = "HELPFUL"
			local namePrint, _, icon = GetSpellInfo(spellId)
			if listedSpell.IconId then icon = listedSpell.IconId end
			if listedSpell.RedifEnemy and not isAlly then EnemyBuff = true end
			--print(sourceName.." Casted "..namePrint.." "..substring(destGUID, -7).." for "..duration.." fPB")
			local my = sourceGUID == UnitGUID("player")
			local stack = 0
			local debufftype = "Buff" -- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
			local expiration = GetTime() + duration
			local scale = listedSpell.scale
			local durationSize = listedSpell.durationSize
			local stackSize = listedSpell.stackSize
			local glow = listedSpell.IconGlow
			local id = 1 --Need to figure this out
			if not Interrupted[sourceGUID] then
				Interrupted[sourceGUID] = {}
			end
			if(listedSpell.show == 1)
			or(listedSpell.show == 2 and my)
			or(listedSpell.show == 4 and isAlly)
			or(listedSpell.show == 5 and not isAlly) then
				local tablespot = #Interrupted[sourceGUID] + 1
				tblinsert (Interrupted[sourceGUID], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype,	duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, EnemyBuff = EnemyBuff, sourceGUID = sourceGUID, glow = glow, ["destGUID"] = destGUID, ["sourceName"] = sourceName, ["namePrint"] = namePrint, ["expiration"] = expiration, ["spellId"] = spellId})
				UpdateAllNameplates()
				Ctimer(duration, function()
					if Interrupted[sourceGUID] then
						for k, v in pairs(Interrupted[sourceGUID]) do
							if v.spellId == spellId then
								--print(v.sourceName.." Timed Out "..v.namePrint.." "..substring(v.destGUID, -7).." left w/ "..string.format("%.2f", v.expiration-GetTime()).." fPB C_Timer")
								Interrupted[sourceGUID][k] = nil
								UpdateAllNameplates()
							end
						end
					end
				end)
			end
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--Channeled Kicks
	-----------------------------------------------------------------------------------------------------------------
	if (destGUID ~= nil) then --Channeled Kicks
		if (event == "SPELL_CAST_SUCCESS") and not (event == "SPELL_INTERRUPT") then
			if listedSpell and listedSpell.spellTypeInterrupt then
				local isFriendly
				if destGUID and (bit_band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) then isAlly = false else isAlly = true end
				if sourceGUID and (bit_band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) then isFriendly = false else isFriendly = true end
				local unit
				for i = 1,  #C_NamePlate_GetNamePlates() do --Issue arrises if nameplates are not shown, you will not be able to capture the kick for channel
					if (destGUID == UnitGUID("nameplate"..i)) then
						unit = "nameplate"..i
						break
					end
				end
				for i = 1, 3 do
					if (destGUID == UnitGUID("arena"..i)) then
						unit = "arena"..i
						break
					end
				end
				if unit and (select(7, UnitChannelInfo(unit)) == false) then
					local duration = listedSpell.durationCLEU or 1
					if (duration ~= nil) then
						duration = interruptDuration(destGUID, duration) or duration
					end
					local namePrint, _, icon = GetSpellInfo(spellId)
					if listedSpell.IconId then icon = listedSpell.IconId end
					if listedSpell.RedifEnemy and not isFriendly then EnemyBuff = true end
					--print(sourceName.." Casted "..namePrint.." "..substring(destGUID, -7).." for "..duration.." fPB")
					local my = sourceGUID == UnitGUID("player")
					local stack = 0
					local debufftype = "none"  -- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
					local expiration = GetTime() + duration
					local scale = listedSpell.scale
					local durationSize = listedSpell.durationSize
					local stackSize = listedSpell.stackSize
					local glow = listedSpell.IconGlow
					local id = 1 --Need to figure this out
					if not Interrupted[destGUID] then
						Interrupted[destGUID] = {}
					end
					if(listedSpell.show == 1)
						or(listedSpell.show == 2 and my)
						or(listedSpell.show == 4 and isAlly)
						or(listedSpell.show == 5 and not isAlly) then
						local tablespot = #Interrupted[destGUID] + 1
						local sourceGUID_Kick = true
						for k, v in pairs(Interrupted[destGUID]) do
							if v.icon == icon and v.sourceGUID == sourceGUID and ((expiration - v.expiration) < 1) then
								--print("Regular Kick Spell Exists, kick used within: "..(expiration - v.expiration))
								sourceGUID_Kick = nil -- the source already used his kick within a GCD on this destGUID
								break
							end
						end
						if sourceGUID_Kick then
							--print(sourceName.." kicked "..(select(1, UnitChannelInfo(unit))).." channel cast w/ "..name.. " from "..destName)
							tblinsert (Interrupted[destGUID], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype, duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, EnemyBuff = EnemyBuff, sourceGUID = sourceGUID, glow = glow,  ["destGUID"] = destGUID, ["sourceName"] = sourceName, ["namePrint"] = namePrint, ["expiration"] = expiration, ["spellId"] = spellId})
							Ctimer(duration, function()
								if Interrupted[destGUID] then
									Interrupted[destGUID][tablespot] = nil
									UpdateAllNameplates()
								end
							end)
						end
					end
				end
			end
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--Regular Casted Kicks
	-----------------------------------------------------------------------------------------------------------------
	if (destGUID ~= nil) then --Regular Casted Kicks
		if (event == "SPELL_INTERRUPT") then
			if listedSpell and listedSpell.spellTypeInterrupt then
				local isFriendly
				if destGUID and (bit_band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) then isAlly = false else isAlly = true end
				if sourceGUID and (bit_band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE) then isFriendly = false else isFriendly = true end
				local unit
				for i = 1,  #C_NamePlate_GetNamePlates() do --Issue arrises if nameplates are not shown, you will not be able to capture the kick for channel
					if (destGUID == UnitGUID("nameplate"..i)) then
						unit = "nameplate"..i
						break
					end
				end
				for i = 1, 3 do
					if (destGUID == UnitGUID("arena"..i)) then
						unit = "arena"..i
						break
					end
				end
				local duration = listedSpell.durationCLEU or 1
				if (duration ~= nil) then
					duration = interruptDuration(destGUID, duration) or duration
				end
				local namePrint, _, icon = GetSpellInfo(spellId)
				if listedSpell.IconId then icon = listedSpell.IconId end
				if listedSpell.RedifEnemy and not isFriendly then EnemyBuff = true end
				--print(sourceName.." Casted "..namePrint.." "..substring(destGUID, -7).." for "..duration.." fPB")
				local my = sourceGUID == UnitGUID("player")
				local stack = 0
				local debufftype = "none"  -- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
				local expiration = GetTime() + duration
				local scale = listedSpell.scale
				local durationSize = listedSpell.durationSize
				local stackSize = listedSpell.stackSize
				local glow = listedSpell.IconGlow
				local id = 1 --Need to figure this out
				if not Interrupted[destGUID] then
					Interrupted[destGUID] = {}
				end
				if(listedSpell.show == 1)
					or(listedSpell.show == 2 and my)
					or(listedSpell.show == 4 and isAlly)
					or(listedSpell.show == 5 and not isAlly) then
					local tablespot = #Interrupted[destGUID] + 1
					local sourceGUID_Kick = true
					for k, v in pairs(Interrupted[destGUID]) do
						if v.icon == icon and v.sourceGUID == sourceGUID and ((expiration - v.expiration) < 1) then
							--print("Casted Kick Fired but Did Not Execute within: "..(expiration - v.expiration).." of Channel Kick Firing")
							sourceGUID_Kick = nil -- the source already used his kick within a GCD on this destGUID
							break
						end
					end
					if sourceGUID_Kick then
						--print(sourceName.." kicked cast w/ "..name.. " from "..destName)
						tblinsert (Interrupted[destGUID], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype, duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, EnemyBuff = EnemyBuff, sourceGUID = sourceGUID, glow = glow, ["destGUID"] = destGUID, ["sourceName"] = sourceName, ["namePrint"] = namePrint, ["expiration"] = expiration, ["spellId"] = spellId})
						UpdateAllNameplates()
						Ctimer(duration, function()
							if Interrupted[destGUID] then
								Interrupted[destGUID][tablespot] = nil
								UpdateAllNameplates()
							end
						end)
					end
				end
			end
		end
	end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------
	--Reset Cold Snap (Resets Block/Barrier/Nova/CoC)
	-----------------------------------------------------------------------------------------------------------------
	if ((sourceGUID ~= nil) and (event == "SPELL_CAST_SUCCESS") and (spellId == 235219)) then --Reset Cold Snap (Resets Block/Barrier/Nova/CoC)
		local needUpdateUnitAura = false
		if (Interrupted[sourceGUID] ~= nil) then
			for k, v in pairs(Interrupted[sourceGUID]) do
				if v.spellSchool then
					if v.spellSchool == 16 then
						needUpdateUnitAura = true
						Interrupted[sourceGUID][k] = nil
					end
				end
			end
		end
		if needUpdateUnitAura then
			UpdateAllNameplates()
		end
	end

	if (((event == "UNIT_DIED") or (event == "UNIT_DESTROYED") or (event == "UNIT_DISSIPATES")) and (select(2, GetPlayerInfoByGUID(destGUID)) ~= "HUNTER")) then
			if (Interrupted[destGUID] ~= nil) then
				Interrupted[destGUID]= nil
				UpdateAllNameplates()
		end
	end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end
