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
local Barrier = { }
local SmokeBombAuras = { }

local DefaultSettings = {
	profile = {
		showDebuffs = 2,		-- 1 = all, 2 = mine + spellList, 3 = only spellList, 4 = only mine, 5 = none
		showBuffs = 3,			-- 1 = all, 2 = mine + spellList, 3 = only spellList, 4 = only mine, 5 = none
		showTooltip = false,
		hidePermanent = true,
		notHideOnPersonalResource = true,

		showOnPlayers = true,
		showOnPets = true,
		showOnNPC = true,

		showOnEnemy = true,
		showOnFriend = true,
		showOnNeutral = true,

		showOnlyInCombat = false,
		showUnitInCombat = false,

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

		nameplateMaxDistance,
		nameplateInset,
		disableFriendlyDebuffs,
		blizzardCountdown,
		fixNames,
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

local function AddBuff(frame, type, icon, stack, debufftype, duration, expiration, my, id, scale, durationSize, stackSize, EnemySmokeBomb)
	if not PlatesBuffs[frame] then PlatesBuffs[frame] = {} end
	PlatesBuffs[frame][#PlatesBuffs[frame] + 1] = {
		type = type,
		icon = icon,
		stack = stack,
		debufftype = debufftype,
		duration = duration,
		expiration = expiration,
		scale = (my and db.myScale + 1 or 1) * (scale or 1),
		durationSize = durationSize,
		stackSize = stackSize,
		id = id,
		EnemySmokeBomb = EnemySmokeBomb,
	}

end

local function FilterBuffs(isAlly, frame, type, name, icon, stack, debufftype, duration, expiration, caster, spellId, id)
	if type == "HARMFUL" and db.showDebuffs == 5 then return end
	if type == "HELPFUL" and db.showBuffs == 5 then return end

	local Spells = db.Spells
	local listedSpell
	local my = caster == "player"
	local cachedID = cachedSpells[name]

	if spellId == 325216 then --Hide Bonedust Brew Debuff
		if type == "HARMFUL" and not my then return end
	end

	if spellId == 319952 then --Hide Bonedust Brew Debuff
		if type == "HARMFUL" and not my then return end
	end


	if Spells[spellId] and not db.ignoredDefaultSpells[spellId] then
		listedSpell = Spells[spellId]
	elseif cachedID then
		if cachedID == "noid" then
			listedSpell = Spells[name]
		else
			listedSpell = Spells[cachedID]
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--Icon Changes
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 45524 then --Chains of Ice Dk
		--icon = 463560
		--icon = 236922
		icon = 236925
	end

	if spellId == 317589 then --Mirros of Toremnt, Tormenting Backlash (Venthyr Mage) to Frost Jaw
		icon = 538562
	end

	if spellId == 334693 then --Abosolute Zero Frost Dk Legendary Stun
		icon = 517161
	end

	if spellId == 115196 then --Shiv
		icon = 135428
	end

	if spellId == 199845 then --Psyflay
		icon = 537021
	end

	if spellId == 317929 then --Aura Mastery Cast Immune Pally
		icon = 135863
	end

	if spellId == 329543 then --Divine Ascension
		icon = 2103871
	end

	if spellId == 328530 then --Divine Ascension
		icon = 2103871
	end

	if spellId == 199545 then --Steed of Glory Hack
		icon = 135890
	end

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
	--SmokeBomb Check For Arena
	-----------------------------------------------------------------------------------------------------------------
	local EnemySmokeBomb
	if spellId == 212183 then -- Smoke Bomb
		if caster and SmokeBombAuras[UnitGUID(caster)] then
			if UnitIsEnemy("player", caster) then --still returns true for an enemy currently under mindcontrol I can add your fix.
				duration = SmokeBombAuras[UnitGUID(caster)].duration --Add a check, i rogue bombs in stealth there is a source but the cleu doesnt regester a time
				expiration = SmokeBombAuras[UnitGUID(caster)].expiration
				EnemySmokeBomb = true
			elseif not UnitIsEnemy("player", caster) then --Add a check, i rogue bombs in stealth there is a source but the cleu doesnt regester a time
				print(caster)
				duration = SmokeBombAuras[UnitGUID(caster)].duration --Add a check, i rogue bombs in stealth there is a source but the cleu doesnt regester a time
				expiration = SmokeBombAuras[UnitGUID(caster)].expiration
				EnemySmokeBomb = false
			else
				EnemySmokeBomb = false
			end
		end
	end

	-----------------------------------------------------------------------------------------------------------------
	--Barrier Add Timer Check For Arena
	-----------------------------------------------------------------------------------------------------------------
	if spellId == 81782 then -- Barrier
		if caster and Barrier[UnitGUID(caster)] then
			duration = Barrier[UnitGUID(caster)].duration
			expiration = Barrier[UnitGUID(caster)].expiration
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
			AddBuff(frame, type, icon, stack, debufftype, duration, expiration, my, id)
			return
		else
			return
		end
	else --listedSpell
		if (type == "HARMFUL" and (db.showDebuffs == 4 and not my))
		or (type == "HELPFUL" and (db.showBuffs == 4 and not my)) then
			return
		end
		if(listedSpell.show == 1)
		or(listedSpell.show == 2 and my)
		or(listedSpell.show == 4 and isAlly)
		or(listedSpell.show == 5 and not isAlly) then
			AddBuff(frame, type, icon, stack, debufftype, duration, expiration, my, id, listedSpell.scale, listedSpell.durationSize, listedSpell.stackSize, EnemySmokeBomb )
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
		FilterBuffs(isAlly, frame, "HARMFUL", name, icon, stack, debufftype, duration, expiration, caster, spellId, id)
		id = id + 1
	end

	id = 1
	while UnitBuff(nameplateID,id) do
		local name, icon, stack, debufftype, duration, expiration, caster, _, _, spellId = UnitBuff(nameplateID, id)
		FilterBuffs(isAlly, frame, "HELPFUL", name, icon, stack, debufftype, duration, expiration, caster, spellId, id)
		id = id + 1
	end
end

local function FilterUnits(nameplateID)

	if db.showOnlyInCombat and not UnitAffectingCombat("player") then return true end -- InCombatLockdown()
	if db.showUnitInCombat and not UnitAffectingCombat(nameplateID) then return true end

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
				self:SetAlpha(f * 3)
			end
			--if self:IsMouseOver() and db.showTooltip and tooltip:IsShown() then
			--tooltip:SetUnitAura(self:GetParent():GetParent().namePlateUnitToken, self.id, self.type)
		  --end
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
local function UpdateBuffIcon(self)

	self:SetAlpha(1)
	self.stacktext:Hide()
	self.border:Hide()
	self.cooldown:Hide()
	self.durationtext:Hide()
	self.durationBg:Hide()
	self.stackBg:Hide()

	self:SetWidth(self.width)
	self:SetHeight(self.height)


	self.texture:SetTexture(self.icon)
	if db.cropTexture then
		GetTexCoordFromSize(self.texture,self.width,self.height)
	else
		self.texture:SetTexCoord(0, 1, 0, 1)
	end

	if self.EnemySmokeBomb then
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

	if (db.showStdCooldown or db.showStdSwipe) and self.expiration > 0 then
		local start, duration = self.cooldown:GetCooldownTimes()
		if (start ~= (self.expiration - self.duration)) or duration ~= self.durationthen then
			self.cooldown:SetCooldown(self.expiration - self.duration, self.duration)
		end
	end

	if db.showDuration and self.expiration > 0 then
		if db.durationPosition == 1 or db.durationPosition == 3 then
			self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "NORMAL")
			self.durationBg:Show()
		else
			self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "OUTLINE")
		end
		self.durationtext:Show()
	end
	if self.stack > 1 then
		self.stacktext:SetText(tostring(self.stack))
		if db.stackPosition == 2 or db.stackPosition == 3 then
			self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "OUTLINE")
			--self.stackBg:SetWidth(self.stacktext:GetStringWidth())
			--self.stackBg:SetHeight(self.stacktext:GetStringHeight())
			--self.stackBg:Show()
		else
			self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "OUTLINE")
		end
		self.stacktext:Show()
	end
end
local function UpdateBuffIconOptions(self)
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
	if db.showStdCooldown then
		self.cooldown:SetHideCountdownNumbers(false)
	else
		self.cooldown:SetHideCountdownNumbers(true)
	end

	if db.showDuration then
		self.durationtext:ClearAllPoints()
		self.durationBg:ClearAllPoints()
		if db.durationPosition == 1 then
			-- under icon
			self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "NORMAL")
			self.durationtext:SetPoint("TOP", self, "BOTTOM", 0, -1)
			self.durationBg:SetPoint("CENTER", self.durationtext)
		elseif db.durationPosition == 3 then
			-- above icon
			self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "NORMAL")
			self.durationtext:SetPoint("BOTTOM", self, "TOP", 0, 1)
			self.durationBg:SetPoint("CENTER", self.durationtext)
		else
			-- on icon
			self.durationtext:SetFont(fPB.font, (self.durationSize or db.durationSize), "OUTLINE")
			self.durationtext:SetPoint("CENTER", self, "CENTER", 0, 0)
		end
		if not colorTransition then
			self.durationtext:SetTextColor(db.colorSingle[1],db.colorSingle[2],db.colorSingle[3],1)
		end
	end

	self.stacktext:ClearAllPoints()
	self.stackBg:ClearAllPoints()
	self.stacktext:SetTextColor(db.stackColor[1],db.stackColor[2],db.stackColor[3],1)
	if db.stackPosition == 1 then
		-- on icon
		self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "OUTLINE")
		self.stacktext:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -1, 3)
	elseif db.stackPosition == 2 then
		-- under icon
		self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "NORMAL")
		self.stacktext:SetPoint("TOP", self, "BOTTOM", 0, -1)
		self.stackBg:SetPoint("CENTER", self.stacktext)
	else
		-- above icon
		self.stacktext:SetFont(fPB.stackFont, (self.stackSize or db.stackSize), "OUTLINE") --Change to OUTLINE
		self.stacktext:SetPoint("BOTTOM", self, "TOP", 7, -7)  --CHRIS
		self.stackBg:SetPoint("CENTER", self.stacktext)
	end

	if db.showTooltip then
		self:SetScript("OnEnter", function(self)
			tooltip:SetOwner(self, "ANCHOR_LEFT")
			tooltip:SetUnitAura(self:GetParent():GetParent().namePlateUnitToken, self.id, self.type)
		end)
		self:SetScript("OnLeave", function() tooltip:Hide() end)
	else
		self:EnableMouse(false)
	end

end
local function iconOnHide(self)
	self.stacktext:Hide()
	self.border:Hide()
	self.cooldown:Hide()
	self.durationtext:Hide()
	self.durationBg:Hide()
	self.stackBg:Hide()
end
local function CreateBuffIcon(frame,i)
	frame.fPBiconsFrame.iconsFrame[i] = CreateFrame("Button")
	frame.fPBiconsFrame.iconsFrame[i]:SetParent(frame.fPBiconsFrame)
	local buffIcon = frame.fPBiconsFrame.iconsFrame[i]

	buffIcon.texture = buffIcon:CreateTexture(nil, "BACKGROUND")

	buffIcon.border = buffIcon:CreateTexture(nil,"BORDER")

	buffIcon.cooldown = CreateFrame("Cooldown", nil, buffIcon, "CooldownFrameTemplate")
	buffIcon.cooldown:SetReverse(true)
	buffIcon.cooldown:SetDrawEdge(false)

	buffIcon.durationtext = buffIcon:CreateFontString(nil, "ARTWORK")

	buffIcon.durationBg = buffIcon:CreateTexture(nil,"BORDER")
	buffIcon.durationBg:SetColorTexture(0,0,0,.75)

	buffIcon.stacktext = buffIcon:CreateFontString(nil, "ARTWORK")

	buffIcon.stackBg = buffIcon:CreateTexture(nil,"BORDER")
	buffIcon.stackBg:SetColorTexture(0,0,0,.35) --CHRIS

	UpdateBuffIconOptions(buffIcon)

	buffIcon.stacktext:Hide()
	buffIcon.border:Hide()
	buffIcon.cooldown:Hide()
	buffIcon.durationtext:Hide()
	buffIcon.durationBg:Hide()
	buffIcon.stackBg:Hide()

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
	--local number = string.match(nameplateID, "%d+")
	--local TPAnchor = _G["ThreatPlatesFrameNamePlate"..number]

	local frame = C_NamePlate_GetNamePlateForUnit(nameplateID)
	if frame then
		if frame.TPFrame then frame = frame.TPFrame end
	end

	if not frame then return end 	-- modifying friendly nameplates is restricted in instances since 7.2
	if FilterUnits(nameplateID) then
		if frame.fPBiconsFrame then
			frame.fPBiconsFrame:Hide()
		end
		return
	end

	ScanUnitBuffs(nameplateID, frame)
--CHRIS ADDED INTERRUPTS
--------------------------------------------------------------------------------------
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
-----------------------------------------------------------------------------------------
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
			parent = frame.unitFrame -- for ElvUI
		end
		if not parent then
			parent = frame.TPFrame -- for ThreatPlates
		end
		if not parent then
			parent = frame
		end
		anchor = "ThreatPlatesFrame"..nameplateID
		frame.fPBiconsFrame:SetParent(parent)
	end
	if not frame.fPBiconsFrame.iconsFrame then
		frame.fPBiconsFrame.iconsFrame = {}
	end


	 	for i = 1, #PlatesBuffs[frame] do
		if not frame.fPBiconsFrame.iconsFrame[i] then
			CreateBuffIcon(frame,i)
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
		buffIcon.EnemySmokeBomb = buff.EnemySmokeBomb

		if updateOptions then
			UpdateBuffIconOptions(buffIcon)
		end
		UpdateBuffIcon(buffIcon)
		buffIcon:Show()
	end
	frame.fPBiconsFrame:Show()

	if #frame.fPBiconsFrame.iconsFrame > #PlatesBuffs[frame] then
		for i = #PlatesBuffs[frame]+1, #frame.fPBiconsFrame.iconsFrame do
			if frame.fPBiconsFrame.iconsFrame[i] then
				frame.fPBiconsFrame.iconsFrame[i]:Hide()
			end
		end
	end

	DrawOnPlate(frame)
end

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
		if frame.UnitFrame and frame.UnitFrame.BuffFrame then
		if db.notHideOnPersonalResource and UnitIsUnit(nameplateID,"player") then
			frame.UnitFrame.BuffFrame:SetAlpha(1)
		else
			frame.UnitFrame.BuffFrame:SetAlpha(0)	--Hide terrible standart debuff frame
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

function fPB.AddNewSpell(spell)
	local defaultSpell
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
	local name = GetSpellInfo(spellId)
	print("fPB Added Spell Name: "..name)
	print("fPB Added SpellId: "..spellId)
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
	fPB.BuildSpellList()
	UpdateAllNameplates(true)
end
function fPB.RemoveSpell(spell)
	if DefaultSettings.profile.Spells[spell] then
		db.ignoredDefaultSpells[spell] = true
	end
	db.Spells[spell] = nil
	CacheSpells()
	fPB.BuildSpellList()
	UpdateAllNameplates(true)
end
function fPB.ChangespellId(oldID, newID)
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
	fPBMainOptions = dialog:AddToBlizOptions(AddonName, AddonName)

	config:RegisterOptionsTable(AddonName.." Spells", fPB.SpellsTable)
	fPBSpellsList = dialog:AddToBlizOptions(AddonName.." Spells", L["Specific spells"], AddonName)

	config:RegisterOptionsTable(AddonName.." Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(fPB.db))
	fPBProfilesOptions = dialog:AddToBlizOptions(AddonName.." Profiles", L["Profiles"], AddonName)

	SLASH_FLYPLATEBUFFS1, SLASH_FLYPLATEBUFFS2 = "/fpb", "/pb"
	function SlashCmdList.FLYPLATEBUFFS(msg, editBox)
		InterfaceOptionsFrame_OpenToCategory(fPBMainOptions)
		InterfaceOptionsFrame_OpenToCategory(fPBSpellsList)
		InterfaceOptionsFrame_OpenToCategory(fPBMainOptions)
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
		fPB.FixBlizzard()
		if db.showspellId then fPB.showspellId() end
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


		if db.showOnlyInCombat then
			fPB.RegisterCombat()
		else
			fPB.Events:RegisterEvent("UNIT_AURA")
			fPB.Events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
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
	[1766]   = 5,		-- Kick (Rogue)
	[2139]   = 6,		-- Counterspell (Mage)
	[6552]   = 4,		-- Pummel (Warrior)
	[13491]  = 5,		-- Pummel (Iron Knuckles Item)
	[19647]  = 6,		-- Spell Lock (felhunter) (Warlock)
	[29443]  = 10,		-- Counterspell (Clutch of Foresight)
	[47528]  = 3,		-- Mind Freeze (Death Knight)
	[57994]  = 3,		-- Wind Shear (Shaman)
	[91802]  = 2,		-- Shambling Rush (Death Knight)
	[96231]  = 4,		-- Rebuke (Paladin)
	[93985]  = 4,		-- Skull Bash (Druid Feral)
	[97547]  = 5,		-- Solar Beam (Druid Balance)
	[115781] = 6,		-- Optical Blast (Warlock)
	[116705] = 4,		-- Spear Hand Strike (Monk)
	[132409] = 6,		-- Spell Lock (command demon) (Warlock)
	[147362] = 3,		-- Countershot (Hunter)
	[183752] = 3,		-- Consume Magic (Demon Hunter)
	[187707] = 3,		-- Muzzle (Hunter)
	[212619] = 6,		-- Call Felhunter (Warlock)
	[217824] = 4,		-- Shield of Virtue (Protec Paladin)
	[231665] = 3,		-- Avengers Shield (Paladin)

}

local castedAuraIds = {
	[188616] = 60, --Shaman Earth Ele "Greater Earth Elemental", has sourceGUID [summonid]
	[118323] = 60, --Shaman Primal Earth Ele "Primal Earth Elemental", has sourceGUID [summonid]
	[188592] = 60, --Shaman Fire Ele "Fire Elemental", has sourceGUID [summonid]
	[118291] = 60, --Shaman Primal Fire Ele "Primal Fire Earth Elemental", has sourceGUID [summonid]
	[157299] = 30, --Storm Ele , has sourceGUID [summonid]
	--[205636]= 10, --Druid Trees "Treant", has sourceGUID (spellId and Summons are different) [spellbookid]
	[248280] = 10, --Druid Trees "Treant", has sourceGUID (spellId and Summons are different) [summonid]
	[288853] = 25, --Dk Raise Abomination "Abomination" same Id has sourceGUID
	[123904] = 24,--WW Xuen Pet Summmon "Xuen" same Id has sourceGUID
	[34433] = 15, --Disc Pet Summmon Sfiend "Shadowfiend" same Id has sourceGUID
	[123040] = 12,  --Disc Pet Summmon Bender "Mindbender" same Id has sourceGUID
	[111685] = 30, --Warlock Infernals,  has sourceGUID (spellId and Summons are different) [spellbookid]
	[205180] = 20, --Warlock Darkglare
	[265187] = 15, --Demonic Tyrant
	[8143] = 10, --Tremor Totem ***ONLY WORKS FOR THE CASTER
	[321686] = 40, --Mirror Image
	[353601] = 15, --Fel Obelisk

}


local function Split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

local tip = CreateFrame('GameTooltip', 'ObjectExistsTooltip', nil, 'GameTooltipTemplate')
local function ObjectExists(guid, ticker, name, sourceName) --Used for Infrnals and Ele
  tip:SetOwner(WorldFrame, 'ANCHOR_NONE')
  tip:SetHyperlink('unit:' .. guid or '')
	local text1 = ObjectExistsTooltipTextLeft1
	local text2 = ObjectExistsTooltipTextLeft2
	local text3 = ObjectExistsTooltipTextLeft3
	if strfind(tostring(sourceName), "-") then
		local sourceNameTable = Split(sourceName, "-")
		sourceName = sourceNameTable[1]
	end
	if (text1 and (type(text1:GetText()) == "string")) then
		if strmatch(text1:GetText(), "Corpse") then
			--print(text1:GetText().." text1")
			return "Corpse"
		end
	end
	if (text2 and (type(text2:GetText()) == "string")) then
		if strmatch(text2:GetText(), "Corpse") then
			--print(text2:GetText().." text 2")
			return "Corpse"
		end
	end
	if (text3 and (type(text3:GetText()) == "string")) then
		if strmatch(text3:GetText(), "Corpse") then
			--print(text3:GetText().." text3")
			return "Corpse"
		end
	end
	if (text1 and (type(text1:GetText()) == "string")) then
		if strfind(text1:GetText(), tostring(sourceName)) then
			--print(text1:GetText().." text1")
			return false
		end
	end
	if (text2 and (type(text2:GetText()) == "string")) then
		if strfind(text2:GetText(), tostring(sourceName)) then
			--print(text2:GetText().." text 2")
			return false
		end
	end
	if (text3 and (type(text3:GetText()) == "string")) then
		if strfind(text3:GetText(), tostring(sourceName)) then
			--print(text3:GetText().." text3")
			return false
		end
	end
	return "Despawned"
end


function fPB:CLEU()
		local _, event, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellId, _, _, _, _, spellSchool = CombatLogGetCurrentEventInfo()
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------------------------------
	--Earthen Check (Totems Need a Spawn Time Check)
	-----------------------------------------------------------------------------------------------------------------
	if ((event == "SPELL_SUMMON") or (event == "SPELL_CREATE")) and (spellId == 198838) then
		if (destGUID ~= nil) then
			local duration = 15
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
			Ctimer(duration + 1, function()	-- execute in some close next frame to accurate use of UnitAura function
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
				Ctimer(duration + 1, function()	-- execute in some close next frame to accurate use of UnitAura function
				Grounding[spawnTime] = nil
				end)
				Ctimer(.2, function()	-- execute a second timer to ensure it catches
				UpdateAllNameplates()
				end)
				end
			UpdateAllNameplates()
			end

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
			UpdateAllNameplates()
			end

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
			--Summoned Spells Check
			-----------------------------------------------------------------------------------------------------------------

		if (event == "SPELL_SUMMON") or (event == "SPELL_CREATE") then --Summoned CDs
			--local namePrint, _, icon = GetSpellInfo(spellId)
			--print(sourceName.." Summoned "..spellId.." "..namePrint.." "..substring(destGUID, -7).." fPB")
			if castedAuraIds[spellId] then
				local guid = destGUID
				local duration = castedAuraIds[spellId]
				local type = "HARMFUL"
				local namePrint, _, icon = GetSpellInfo(spellId)

				if spellId == 321686 then --Mirror Image Icon Change
					icon = 135994
				end
				if spellId == 157299 then
					icon = 2065626
				end

				--print(sourceName.." Summoned "..namePrint.." "..substring(destGUID, -7).." for "..duration.." fPB")

				local stack = 0
				local debufftype = "none" -- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
				local expiration = GetTime() + duration
				local scale = 1.3
				local durationSize = 0
				local stackSize = 0
				local id = 1 --Need to figure this out
				if not Interrupted[sourceGUID] then
					Interrupted[sourceGUID] = {}
				end
				local tablespot = #Interrupted[sourceGUID] + 1
				tblinsert (Interrupted[sourceGUID], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype,	duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, sourceGUID = sourceGUID,  ["destGUID"] = destGUID, ["sourceName"] = sourceName, ["namePrint"] = namePrint, ["expiration"] = expiration, ["spellId"] = spellId})
				UpdateAllNameplates()
				local ticker = 1
				Ctimer(duration, function()
					if Interrupted[sourceGUID] then
						for k, v in pairs(Interrupted[sourceGUID]) do
							if v.spellId == spellId then
								print(v.sourceName.." Timed Out "..v.namePrint.." "..substring(v.destGUID, -7).." left w/ "..string.format("%.2f", v.expiration-GetTime()).." fPB C_Timer")
								Interrupted[sourceGUID][k] = nil
								UpdateAllNameplates()
							end
						end
					end
				end)
				self.ticker = C_Timer.NewTicker(.25, function()
					local name = GetSpellInfo(spellId)
					if Interrupted[sourceGUID] then
						for k, v in pairs(Interrupted[sourceGUID]) do
							if v.destGUID then
                if substring(v.destGUID, -5) == substring(guid, -5) then --string.sub is to help witj Mirror Images bug
                  if ObjectExists(v.destGUID, ticker, v.namePrint, v.sourceName) then
	                  print(v.sourceName.." "..ObjectExists(v.destGUID, ticker, v.namePrint, v.sourceName).." "..v.namePrint.." "..substring(v.destGUID, -7).." left w/ "..string.format("%.2f", v.expiration-GetTime()).." fPB C_Ticker")
                		Interrupted[sourceGUID][k] = nil
										UpdateAllNameplates()
                    --self.ticker:Cancel()
										break
                  end
                end
							end
						end
					end
					ticker = ticker + 1
				end, duration * 4 + 5)
			end
		end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		 if (destGUID ~= nil) then --Channeled Kicks
			if (event == "SPELL_CAST_SUCCESS") and not (event == "SPELL_INTERRUPT") then
				if interruptsIds[spellId] then
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
						if unit then
						 --print(unit.." C_Covenants is: "..C_Covenants.GetActiveCovenantID(unit))
					  end

					 if unit and (select(7, UnitChannelInfo(unit)) == false) then
						local duration = interruptsIds[spellId]
					  local type = "HARMFUL"
	 					local _, _, icon = GetSpellInfo(spellId)
	 					local stack = 0
	 					local debufftype = "none" -- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
	 					local expiration = GetTime() + duration
	 					local scale = 1.5
	 					local durationSize = 0
	 					local stackSize = 0
	 					local id = 1 --Need to figure this out
	 					if not Interrupted[destGUID] then
	 						Interrupted[destGUID] = {}
	 					end
						local tablespot = #Interrupted[destGUID] + 1
						local sourceGUID_Kick = true
						for k, v in pairs(Interrupted[destGUID]) do
							if v.icon == icon and v.sourceGUID == sourceGUID and ((expiration - v.expiration) < 1) then
								print("Regular Kick Spell Exists, kick used within: "..(expiration - v.expiration))
								sourceGUID_Kick = nil -- the source already used his kick within a GCD on this destGUID
								break
							end
						end
						if sourceGUID_Kick then
							print(sourceName.." Kicked CHANNEL w/"..spellId.. " from "..destName)
							tblinsert (Interrupted[destGUID], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype,	duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, sourceGUID = sourceGUID})
							UpdateAllNameplates()
							Ctimer(interruptsIds[spellId], function()
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
		if (destGUID ~= nil) then --Regular Casted Kicks
			if (event == "SPELL_INTERRUPT") then
				if interruptsIds[spellId] then
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
					if unit then
					 --print(unit.." C_Covenants is: "..C_Covenants.GetActiveCovenantID(unit))
					end

					local duration = interruptsIds[spellId]
					local type = "HARMFUL"
					local _, _, icon = GetSpellInfo(spellId)
					local stack = 0
					local debufftype = "none" -- Magic = {0.20,0.60,1.00},	Curse = {0.60,0.00,1.00} Disease = {0.60,0.40,0}, Poison= {0.00,0.60,0}, none = {0.80,0,   0}, Buff = {0.00,1.00,0},
					local expiration = GetTime() + duration
					local scale = 1.5
					local durationSize = 0
					local stackSize = 0
					local id = 1 --Need to figure this out
					if not Interrupted[destGUID] then
						Interrupted[destGUID] = {}
					end
					local tablespot = #Interrupted[destGUID] + 1
					local sourceGUID_Kick = true
					for k, v in pairs(Interrupted[destGUID]) do
						if v.icon == icon and v.sourceGUID == sourceGUID and ((expiration - v.expiration) < 1) then
							print("Channeled Kick Spell Exists, kick used within: "..(expiration - v.expiration))
							sourceGUID_Kick = nil -- the source already used his kick within a GCD on this destGUID
							break
						end
					end
					if sourceGUID_Kick then
						print(sourceName.." Kicked CAST w/"..spellId.. " from "..destName)
						tblinsert (Interrupted[destGUID], tablespot, { type = type, icon = icon, stack = stack, debufftype = debufftype,	duration = duration, expiration = expiration, scale = scale, durationSize = durationSize, stackSize = stackSize, id = id, sourceGUID = sourceGUID})
						UpdateAllNameplates()
						Ctimer(interruptsIds[spellId], function()
							if Interrupted[destGUID] then
								Interrupted[destGUID][tablespot] = nil
								UpdateAllNameplates()
							end
					 	end)
					end
				end
			end
		end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		if ((sourceGUID ~= nil) and (event == "SPELL_CAST_SUCCESS") and (spellId == 235219)) then --coldsnap reset
			if (Interrupted[SourceGUID] ~= nil) then
				Interrupted[SourceGUID]= nil
				UpdateAllNameplates()
			end
		end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		if (((event == "UNIT_DIED") or (event == "UNIT_DESTROYED") or (event == "UNIT_DISSIPATES")) and (select(2, GetPlayerInfoByGUID(destGUID)) ~= "HUNTER")) then
				if (Interrupted[destGUID] ~= nil) then
					Interrupted[destGUID]= nil
					UpdateAllNameplates()
			end
		end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
end
