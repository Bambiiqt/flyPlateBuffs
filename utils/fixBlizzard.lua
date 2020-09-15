local _, fPB = ...

function fPB.FixBlizzard()	--some fixes to blizzard nameplates behaviour

	db = fPB.db.profile

	if db.nameplateMaxDistance then
		SetCVar("nameplateMaxDistance",db.nameplateMaxDistance)
	end

	if db.nameplateInset then
		SetCVar("nameplateOtherTopInset", -1)
		SetCVar("nameplateOtherBottomInset", -1)
	end

	if db.blizzardCountdown then
		SetCVar("countdownForCooldowns", 1)
	end

	if db.disableFriendlyDebuffs then
		SetCVar("nameplateShowDebuffsOnFriendly", 0)
	end

	--fix nameplates without names
	if db.fixNames then
		-- for _, v1 in pairs({"Friendly", "Enemy"}) do
			-- for _, v2 in pairs({"displayNameWhenSelected", "displayNameByPlayerNameRules"}) do
				-- _G["DefaultCompactNamePlate"..v1.."FrameOptions"][v2] = false
			-- end
		-- end
		fPB.FixNames()
	end
end

local hooked
function fPB.FixNames()
	if hooked then return end

	hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
		--###
		if frame:IsForbidden() then return end --!!!

		-- local instance, type = IsInInstance()
		-- if instance and (type == "party" or type == "raid") and UnitIsFriend(frame.unit,"player") then return end
		--###
		if frame.name:IsShown() then return end
		if UnitIsUnit(frame.unit,"player") then return end

		frame.name:SetText(GetUnitName(frame.unit, true));  -- below almost copy of CompactUnitFrame_UpdateName
		if ( CompactUnitFrame_IsTapDenied(frame) ) then
			frame.name:SetVertexColor(0.5, 0.5, 0.5);
		elseif ( frame.optionTable.colorNameBySelection ) then
			if ( frame.optionTable.considerSelectionInCombatAsHostile and CompactUnitFrame_IsOnThreatListWithPlayer(frame.displayedUnit) ) then
				frame.name:SetVertexColor(1.0, 0.0, 0.0);
			else
				frame.name:SetVertexColor(UnitSelectionColor(frame.unit, frame.optionTable.colorNameWithExtendedColors));
			end
		end
		frame.name:Show();
	end)
	hooked = true
end
