-- Author      : John Rubin - "Mistra50"
-- Create Date : 8/8/2012 9:03:35 PM
-- Mistra's D3Orbs - rewrite of the previous oUF_D3Orbs_LightWeight
-- The orbs originally appeared in the RothUI by "Zork" and permissive use of all assets and code was given by the original author. 
-- The code in this addon has small chunks of the original still within, but the majority has been rewritten to be free of any external API by John Rubin, aka "Mistra"
-- Code was abandoned a long time ago in roughly 2012, RawCard helped restore it for Classic.  
-- I ported RawCard's Classic version for Retail. -Speedlock

--Copyright (C) 2012 John Rubin

--Standard DBAD License.  A mix of MIT and please get my permission before you copy this code license.

--Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

--The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--The above copyright holder is notified of the intent of redistribution prior to the release of said redistribution.

--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- Version detection and compatibility layer
local _, _, _, tocVersion = GetBuildInfo()
RC32_TOC_VERSION = tocVersion or 0

-- Expansion detection
RC32_IS_VANILLA = RC32_TOC_VERSION < 20000
RC32_IS_TBC = RC32_TOC_VERSION >= 20000 and RC32_TOC_VERSION < 30000
RC32_IS_WRATH = RC32_TOC_VERSION >= 30000 and RC32_TOC_VERSION < 40000
RC32_IS_CATA = RC32_TOC_VERSION >= 40000 and RC32_TOC_VERSION < 50000
RC32_IS_MOP = RC32_TOC_VERSION >= 50000 and RC32_TOC_VERSION < 60000
RC32_IS_MOP_OR_LATER = RC32_TOC_VERSION >= 50000
RC32_IS_CATA_OR_LATER = RC32_TOC_VERSION >= 40000

local function rc32CanUseValue(value)
	if issecretvalue and issecretvalue(value) then
		if canaccessvalue then
			return canaccessvalue(value)
		end
		return false
	end
	return true
end

local function rc32SafeNumber(value, fallback)
	if not rc32CanUseValue(value) then
		return fallback
	end
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		local num = tonumber(value)
		if num then
			return num
		end
	end
	local ok, num = pcall(tonumber, value)
	if ok and num then
		return num
	end
	return fallback
end

-- Power type constants - MoP uses numbers, earlier versions use strings
RC32_POWER_MANA = RC32_IS_MOP_OR_LATER and 0 or "MANA"
RC32_POWER_RAGE = RC32_IS_MOP_OR_LATER and 1 or "RAGE"
RC32_POWER_FOCUS = RC32_IS_MOP_OR_LATER and 2 or "FOCUS"
RC32_POWER_ENERGY = RC32_IS_MOP_OR_LATER and 3 or "ENERGY"
RC32_POWER_RUNIC_POWER = RC32_IS_MOP_OR_LATER and 6 or "RUNIC_POWER"
RC32_POWER_SOUL_SHARDS = RC32_IS_CATA_OR_LATER and (RC32_IS_MOP_OR_LATER and 7 or "SOUL_SHARDS") or nil
RC32_POWER_HOLY_POWER = RC32_IS_CATA_OR_LATER and (RC32_IS_MOP_OR_LATER and 9 or "HOLY_POWER") or nil
RC32_POWER_CHI = RC32_IS_MOP_OR_LATER and 12 or nil
RC32_POWER_SHADOW_ORBS = RC32_IS_CATA_OR_LATER and (RC32_IS_MOP_OR_LATER and 13 or "SHADOW_ORBS") or nil
RC32_POWER_BURNING_EMBERS = RC32_IS_MOP_OR_LATER and 14 or nil
RC32_POWER_DEMONIC_FURY = RC32_IS_MOP_OR_LATER and 15 or nil

-- Safe UnitPower wrapper that handles version differences
function RC32_UnitPower(unit, powerType)
	if powerType == nil then
		return rc32SafeNumber(UnitPower(unit), 0)
	end
	-- For pre-MoP, if we got a number, don't pass it
	if not RC32_IS_MOP_OR_LATER and type(powerType) == "number" then
		return rc32SafeNumber(UnitPower(unit), 0)
	end
	return rc32SafeNumber(UnitPower(unit, powerType), 0)
end

function RC32_UnitPowerMax(unit, powerType)
	if powerType == nil then
		return rc32SafeNumber(UnitPowerMax(unit), 0)
	end
	-- For pre-MoP, if we got a number, don't pass it
	if not RC32_IS_MOP_OR_LATER and type(powerType) == "number" then
		return rc32SafeNumber(UnitPowerMax(unit), 0)
	end
	return rc32SafeNumber(UnitPowerMax(unit, powerType), 0)
end

-- Combo point wrapper for retail/classic API differences
local function RC32_GetComboPoints()
	if GetComboPoints then
		local points = GetComboPoints("player", "target")
		if points then
			return points
		end
	end
	if Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
		return UnitPower("player", Enum.PowerType.ComboPoints) or 0
	end
	return 0
end

-- Safe RegisterUnitWatch wrappers (retail may not expose the global funcs)
function RC32_RegisterUnitWatch(frame)
	if RegisterUnitWatch then
		RegisterUnitWatch(frame)
	elseif frame and frame.RegisterUnitWatch then
		frame:RegisterUnitWatch()
	end
end

function RC32_UnregisterUnitWatch(frame)
	if UnregisterUnitWatch then
		UnregisterUnitWatch(frame)
	elseif frame and frame.UnregisterUnitWatch then
		frame:UnregisterUnitWatch()
	end
end

-- Check if a class exists in this version
function RC32_ClassExists(className)
	if className == "Monk" then
		return RC32_IS_MOP_OR_LATER
	elseif className == "Death Knight" then
		return RC32_TOC_VERSION >= 30000 -- Wrath+
	end
	return true
end

-- Check if a power type is supported
function RC32_PowerTypeSupported(powerType)
	if powerType == RC32_POWER_HOLY_POWER or powerType == RC32_POWER_SOUL_SHARDS or powerType == RC32_POWER_SHADOW_ORBS then
		return RC32_IS_CATA_OR_LATER
	elseif powerType == RC32_POWER_CHI or powerType == RC32_POWER_BURNING_EMBERS or powerType == RC32_POWER_DEMONIC_FURY then
		return RC32_IS_MOP_OR_LATER
	end
	return true
end

--register the addon message prefix
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
	C_ChatInfo.RegisterAddonMessagePrefix("RC32")
end

--variable setup
RC32localizedDisplayName, RC32className, RC32classNumber = UnitClass("player")
local charClassNumber = 0
local playerInVehicle --bool for detecting whether or not a player is in a vehicle
local defaultOrbSize = 150
local orbFillingTexture = "MDO_orb_filling8.tga"
local fillRotationTexture = "orb_fillRotation"
local images = "Interface\\AddOns\\RCDiabloOrbs\\images\\"
local fonts = "Interface\\Addons\\RCDiabloOrbs\\fonts\\"
healthOrb = nil 
manaOrb = nil
local vehicleInUse

--smooth animation variables
local lastHealthValue, newHealthValue

--color preset definitions per class and assignment
orbClassColors = {
	[0] = {health = {r = 0.78, g = 0.61, b = 0.43, a= 1}, mana = {r = 0.8, g = 0, b = 0, a= 1}, animation = "SPELLS\\WhiteRadiationFog.m2", name = "Warrior"}, --warrior preset

	[1] = {health = {r = 0.96, g = 0.55, b = 0.73, a = 1},mana = {r = 0.0, g = 0.44, b = 0.87, a = 1}, animation = "SPELLS\\WhiteRadiationFog.m2", name = "Paladin"}, --paladin preset

	[2] = {health = {r = 0.67, g = 0.83, b = 0.45, a = 1},mana = {r = 1.1, g = 0.5, b = 0.25, a = 1}, animation = "SPELLS\\WhiteRadiationFog.m2", name = "Hunter"}, --hunter preset

	[3] = {health = {r = 1.00, g = 0.96, b = 0.41, a = 1},mana = {r = 1.00, g = 0.96, b = 0.41, a = 1}, animation = "SPELLS\\WhiteRadiationFog.m2", name = "Rogue"}, --rogue preset

	[4] = {health = {r = 1.00, g = 1.00, b = 1.00, a = 1},mana = {r = 0.0, g = 0.44, b = 0.87, a = 1}, animation = "SPELLS\\WhiteRadiationFog.m2", name = "Priest"}, --priest preset

	[5] = {health = {r = 0.77, g = 0.12, b = 0.23, a = 1},mana = {r = 0.35, g = 0.9, b = 0.9, a = 1}, animation = "SPELLS\\WhiteRadiationFog.m2", name = "Death Knight"}, --death knight preset

	[6] = {health = {r = 0.0, g = 0.44, b = 0.87, a = 1},mana = {r = 0.0, g = 0.44, b = 0.87, a = 1}, animation = "SPELLS\\WhiteRadiationFog.m2", name = "Shaman"}, -- shaman preset

	[7] = {health = {r = 0.41, g = 0.80, b = 0.94, a = 1},mana = {r = 0.0, g = 0.44, b = 0.87, a = 1},  animation = "SPELLS\\WhiteRadiationFog.m2", name = "Mage"}, --mage preset

	[8] = {health = {r = 0.58, g = 0.51, b = 0.79, a = 1},mana = {r = 0.0, g = 0.44, b = 0.87, a = 1},  animation = "SPELLS\\WhiteRadiationFog.m2", name = "Warlock"}, --warlock preset

	[9] = {health = {r = 0.33, g = 0.54, b = 0.52, a = 1},mana = {r = 1.00, g = 1.00, b = 1.00, a = 1},  animation = "SPELLS\\GreenRadiationFog.m2", name = "Monk"}, --monk preset

	[10] = {health = {r = 1.00, g = 0.49, b = 0.04, a = 1},mana = {r = 0.0, g = 0.44, b = 0.87, a = 1},  animation = "SPELLS\\WhiteRadiationFog.m2", name = "Druid"} --druid preset
}

local fontChoices = {
	[0] = "Interface\\AddOns\\RCDiabloOrbs\\fonts\\Of Wildflowers and Wings.ttf",
	[1] = "FONTS\\FRIZQT__.ttf"  
}


local function getClassColor()
	if RC32classNumber then
		RC32className = RC32localizedDisplayName
		return RC32classNumber - 1
	else
		local num = table.getn(orbClassColors)
		for i=0,num,1 do
			if orbClassColors[i].name == UnitClass("player") then
				RC32className = UnitClass("player")
				return i 
			end
		end
		print("Did not find the class.  "..UnitClass("player"))
		return 0
	end
end
charClassNumber = getClassColor()

--load preset RC32CharacterData default in the event existing data cannot be recovered
local Hr,Hg,Hb,Ha = orbClassColors[charClassNumber].health.r, orbClassColors[charClassNumber].health.g, orbClassColors[charClassNumber].health.b, orbClassColors[charClassNumber].health.a
local Mr,Mg,Mb,Ma = orbClassColors[charClassNumber].mana.r, orbClassColors[charClassNumber].mana.g, orbClassColors[charClassNumber].mana.b, orbClassColors[charClassNumber].mana.a

local defaultsTable = {
	--health orb vars
	healthOrb = {scale = 1,textures = {fill = "MDO_orb_filling2.tga", rotation = "orb_rotation_bubbles"}, orbColor = {r = Hr, g = Hg, b = Hb, a= Ha}, galaxy = {r = Hr, g = Hg, b = Hb, a= Ha}, font1 = {r=1,g=1,b=1,a=1,show = true}, font2 = {r=1,g=1,b=1,a=1,show = true}, formatting = {truncated = true, commaSeparated = false}},

	--mana orb vars
	manaOrb = {scale = 1, textures = {fill = "MDO_orb_filling2.tga", rotation = "orb_rotation_bubbles"}, orbColor = {r = Mr, g = Mg, b = Mb, a = Ma},galaxy = {r = Mr, g = Mg, b = Mb, a = Ma}, font1 = {r=1,g=1,b=1,a=1,show = true}, font2 = {r=1,g=1,b=1,a=1,show = true}, formatting = {truncated = true, commaSeparated = false}},
	
	--pet orb vars
	petOrb = {scale = 1, enabled = true, showValue = false, showPercentage = true, healthOrb = {r=Hr,g=Hg,b=Hb,a=Ha}, manaOrb={r=Mr,g=Mg,b=Mb,a=Ma}},
	
	--orb fonts
	font = fontChoices[1],
	
	values = {formatted=true},
	
	artwork = {show = true},
	
	powerFrame = {show = true, rotation = 270, maxStackSound = 12},

	combat = {enabled = true, orbColor = {r = 0.8, g = 0, b = 0, a = 1}, galaxy = {r = 0.8, g = 0, b = 0, a = 1}, font1 = {r=1,g=1,b=1,a=1}, font2 = {r=1,g=1,b=1,a=1}},

	druidColors = {
		cat = {orbColor = {r = 1.00, g = 0.96, b = 0.41, a = 1}, galaxy = {r = 1.00, g = 0.96, b = 0.41, a = 1}, font1 = {r=1,g=1,b=1,a=1}, font2 = {r=1,g=1,b=1,a=1}},
		bear = {orbColor = {r = 0.8, g = 0, b = 0, a= 1}, galaxy = {r = 0.8, g = 0, b = 0, a= 1}, font1 = {r=1,g=1,b=1,a=1}, font2 = {r=1,g=1,b=1,a=1}},
		moonkin = {orbColor = {r = 0.0, g = 0.44, b = 0.87, a = 1}, galaxy = {r = 0.0, g = 0.44, b = 0.87, a = 1}, font1 = {r=1,g=1,b=1,a=1}, font2 = {r=1,g=1,b=1,a=1}}, 
		tree = {orbColor = {r = 0.0, g = 0.44, b = 0.87, a = 1}, galaxy = {r = 0.0, g = 0.44, b = 0.87, a = 1}, font1 = {r=1,g=1,b=1,a=1}, font2 = {r=1,g=1,b=1,a=1}}
	},

	defaultPlayerFrame = {show = false}
}

-- Sound options for max stack notification
RC32_MaxStackSounds = {
	{name = "None", id = 0},
	{name = "Power Up", id = 12889},
	{name = "Level Up", id = 888},
	{name = "Ready Check", id = 8960},
	{name = "Raid Warning", id = 8959},
	{name = "PvP Flag", id = 8174},
	{name = "Quest Complete", id = 878},
	{name = "Loot Coin", id = 120},
	{name = "Horn", id = 8457},
	{name = "War Horn", id = 11466},
	{name = "Ding", id = 6674},
	{name = "Bell", id = 5274},
	{name = "Gong", id = 6595},
	{name = "Alarm", id = 8046},
	{name = "Chime", id = 3332},
	{name = "Fanfare", id = 8455},
	{name = "Auction Open", id = 5274},
	{name = "Map Ping", id = 8458},
	{name = "Tell Message", id = 3081},
	{name = "Friend Online", id = 4620},
	{name = "Achievement", id = 12891},
	{name = "Boss Emote", id = 11965},
	{name = "PvP Victory", id = 8454},
	{name = "Humm", id = 6678},
}

local defaultTextures = {
	healthOrb = {fill = "MDO_orb_filling2.tga", rotation = "orb_rotation_bubbles"},
	manaOrb = {fill = "MDO_orb_filling2.tga", rotation = "orb_rotation_bubbles"}
}

RC32FillTextureChoices = {
	[0] = images.. "MDO_orb_filling1.tga",
	[1] = images.. "MDO_orb_filling2.tga",
	[2] = images.. "MDO_orb_filling3.tga",
	[3] = images.. "MDO_orb_filling4.tga",
	[4] = images.. "MDO_orb_filling5.tga",
	[5] = images.. "MDO_orb_filling6.tga",
	[6] = images.. "MDO_orb_filling7.tga",
}

RC32RotationTextureChoices = {
	[0] = images.. "orb_rotation_galaxy",
	[1] = images.. "orb_rotation_bubbles",
	[2] = images.. "orb_rotation_iris"
}

-- Track selected texture indices from dropdowns
RC32SelectedFillIndex = nil
RC32SelectedRotationIndex = nil

-- Texture file names (without path) for saving
RC32FillTextureNames = {
	[0] = "MDO_orb_filling1.tga",
	[1] = "MDO_orb_filling2.tga",
	[2] = "MDO_orb_filling3.tga",
	[3] = "MDO_orb_filling4.tga",
	[4] = "MDO_orb_filling5.tga",
	[5] = "MDO_orb_filling6.tga",
	[6] = "MDO_orb_filling7.tga",
}

RC32RotationTextureNames = {
	[0] = "orb_rotation_galaxy",
	[1] = "orb_rotation_bubbles",
	[2] = "orb_rotation_iris"
}

----------------------------------------------------------Main Data Table for each character -----------------------------------------------------------------
RC32CharacterData = defaultsTable
RC32Textures = defaultTextures
---------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Store original PlayerFrame position for restoration
local playerFrameOriginalPoint = nil

function handlePlayerFrame(show)
	if show then
		-- Restore PlayerFrame visibility
		PlayerFrame:SetScript("OnEvent", PlayerFrame_OnEvent)
		PlayerFrame:SetAlpha(1)
		PlayerFrame:EnableMouse(true)
		-- Restore original position if we saved it
		if playerFrameOriginalPoint then
			PlayerFrame:ClearAllPoints()
			PlayerFrame:SetPoint(unpack(playerFrameOriginalPoint))
		end
	else
		-- Hide PlayerFrame without using protected Hide() function
		-- Save original position first
		if not playerFrameOriginalPoint then
			local point, relativeTo, relativePoint, xOfs, yOfs = PlayerFrame:GetPoint(1)
			if point then
				playerFrameOriginalPoint = {point, relativeTo, relativePoint, xOfs, yOfs}
			end
		end
		PlayerFrame:SetScript("OnEvent", nil)
		PlayerFrame:SetAlpha(0)
		PlayerFrame:EnableMouse(false)
		-- Move off-screen to prevent any interaction
		PlayerFrame:ClearAllPoints()
		PlayerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, 9999)
	end
end

--hide the player frame by default... we have a pet orb now, so people shouldn't be asking for it anymore.... maybe
--handlePlayerFrame(RC32CharacterData.defaultPlayerFrame.show)


--function to make any frame object movable
local function makeFrameMovable(frame,button)
	local btnString = "LeftButton"
	if button then
		btnString = button
	end

	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag(btnString)
	frame:SetScript("OnDragStart", function(self) 
		if IsShiftKeyDown() then
			self:StartMoving()
		end
	 end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
end

local function valueFormat(val,petOverride)
	if not rc32CanUseValue(val) then
		return string.format("%s", val or "")
	end
	local newVal = val
	if RC32CharacterData.values.formatted == true then
		if val > 1000000 then
			newVal = (floor((val/1000000)*10)/10) .."m"
		elseif val > 99999 then
			newVal = (floor((val/1000)*10)/10) .."k"
		end
	end
	if petOverride then
		if val > 10000 then
			newVal = (floor((val/1000)*10)/10).."k"
		end
	end
	return newVal
end

local previousHealthValue = 0
local lastSafeHealth = 1
local lastSafeMaxHealth = 1
local lastSafePower = 1
local lastSafeMaxPower = 1
local lastSafeHealthPercent = nil
local lastSafePowerPercent = nil
local RC32_GALAXY_ALPHA_MULTIPLIER = 0.5
local function monitorHealth(orb)
	local rawMaxHealth = orb.rawMaxHealth or orb.maxHealth
	local rawCurrentHealth = orb.rawCurrentHealth or orb.currentHealth
	if not rc32CanUseValue(rawCurrentHealth) or not rc32CanUseValue(rawMaxHealth) then
		if orb.fillingBar then
			orb.filling:Hide()
			orb.fillingBar:Show()
			orb.fillingBar:SetMinMaxValues(0, rawMaxHealth or 1)
			orb.fillingBar:SetValue(rawCurrentHealth or 0)
		end
		orb.galaxy1:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy2:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy3:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.font1:SetText(string.format("%s", rawCurrentHealth or ""))
		orb.font2:SetText("")
		return
	end
	local maxHealth = rc32SafeNumber(rawMaxHealth, 1)
	if maxHealth == 0 then maxHealth = 1 end
	local currentHealth = rc32SafeNumber(rawCurrentHealth, 1)
	previousHealthValue = rc32SafeNumber(previousHealthValue, currentHealth)
	local isDead = orb.isDead
	local healthPercentage = currentHealth/maxHealth
	local inverseHealthPercentage = math.abs(healthPercentage - 1)

	local step = 0
	local onePercentHealth = maxHealth / 100

	local newValue = previousHealthValue
	if previousHealthValue < currentHealth then
		step = 1
		if previousHealthValue + (onePercentHealth * step) > currentHealth then
			newValue = currentHealth
		else
			newValue = previousHealthValue + (onePercentHealth * step)
		end
	elseif previousHealthValue > currentHealth then
		step = -1
		if previousHealthValue + (onePercentHealth * step) < currentHealth then
			newValue = currentHealth
		else
			newValue = previousHealthValue + (onePercentHealth * step)
		end
	end
	previousHealthValue = newValue

	local targetTexHeight = (previousHealthValue/maxHealth * orb.filling:GetWidth())
	if targetTexHeight < 1 then targetTexHeight = 1 end
	local newDisplayPercentage = previousHealthValue/maxHealth
	if newDisplayPercentage > 1 then
		newDisplayPercentage = 1
		targetTexHeight = orb.filling:GetWidth()
	end
	local string1 = math.floor(newDisplayPercentage*100)
	if tonumber(string1) == nil then string1 = 0 end
	orb.font1:SetText(string1)

	local string = valueFormat(currentHealth)
	orb.font2:SetText(string)

	if isDead then
		orb.font2:SetText("DEAD :'(")
	end

	if orb.fillingBar then orb.fillingBar:Hide() end
	orb.filling:Show()
	orb.filling:SetHeight(targetTexHeight)
	orb.filling:SetTexCoord(0,1,math.abs(newDisplayPercentage - 1),1)
	orb.galaxy1:SetAlpha(newDisplayPercentage * RC32_GALAXY_ALPHA_MULTIPLIER)
	orb.galaxy2:SetAlpha(newDisplayPercentage * RC32_GALAXY_ALPHA_MULTIPLIER)
	orb.galaxy3:SetAlpha(newDisplayPercentage * RC32_GALAXY_ALPHA_MULTIPLIER)
end

local previousPowerValue = 0
local function monitorPower(orb)
	local rawMaxPower = orb.rawMaxPower or orb.maxPower
	local rawCurrentPower = orb.rawCurrentPower or orb.currentPower
	if not rc32CanUseValue(rawCurrentPower) or not rc32CanUseValue(rawMaxPower) then
		if orb.fillingBar then
			orb.filling:Hide()
			orb.fillingBar:Show()
			orb.fillingBar:SetMinMaxValues(0, rawMaxPower or 1)
			orb.fillingBar:SetValue(rawCurrentPower or 0)
		end
		orb.galaxy1:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy2:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy3:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.font1:SetText(string.format("%s", rawCurrentPower or ""))
		orb.font2:SetText("")
		return
	end
	local maxPower = rc32SafeNumber(rawMaxPower, 1)
	if maxPower == 0 then maxPower = 1 end
	local currentPower = rc32SafeNumber(rawCurrentPower, 1)
	previousPowerValue = rc32SafeNumber(previousPowerValue, currentPower)
	local isDead = orb.isDead
	local powerPercentage = currentPower/maxPower
	local inversePowerPercentage = math.abs(powerPercentage - 1)

	local step = 0
	local fillPercentage = 100
	local onePercentPower = maxPower / fillPercentage

	local newValue = previousPowerValue
	if previousPowerValue < currentPower then
		step = 1
		if previousPowerValue + (onePercentPower * step) > currentPower then
			newValue = currentPower
		else
			newValue = previousPowerValue + (onePercentPower * step)
		end
	elseif previousPowerValue > currentPower then
		step = -1
		if previousPowerValue + (onePercentPower * step) < currentPower then
			newValue = currentPower
		else
			newValue = previousPowerValue + (onePercentPower * step)
		end
	end
	previousPowerValue = newValue

	local targetTexHeight = (previousPowerValue/maxPower * orb.filling:GetWidth())
	if targetTexHeight < 1 then targetTexHeight = 1 end
	local newDisplayPercentage = previousPowerValue / maxPower
	if newDisplayPercentage > 1 then
		newDisplayPercentage = 1
		targetTexHeight = orb.filling:GetWidth()
	end
	local string1 = math.floor(newDisplayPercentage*100)
	if tonumber(string1) == nil then string1 = 0 end
	orb.font1:SetText(string1)

	local string = valueFormat(currentPower)
	orb.font2:SetText(string)

	if isDead then
		orb.font2:SetText("DEAD :'(")
	end

	if orb.fillingBar then orb.fillingBar:Hide() end
	orb.filling:Show()
	orb.filling:SetHeight(targetTexHeight)
	orb.filling:SetTexCoord(0,1,math.abs(newDisplayPercentage-1),1)
	orb.galaxy1:SetAlpha(newDisplayPercentage * RC32_GALAXY_ALPHA_MULTIPLIER)
	orb.galaxy2:SetAlpha(newDisplayPercentage * RC32_GALAXY_ALPHA_MULTIPLIER)
	orb.galaxy3:SetAlpha(newDisplayPercentage * RC32_GALAXY_ALPHA_MULTIPLIER)
end

local previousPetHealth = 0
local lastSafePetHealth = 0
local lastSafePetMaxHealth = 1
local lastSafePetPower = 0
local lastSafePetMaxPower = 1
local lastSafePetHealthPercent = nil
local lastSafePetPowerPercent = nil
local function PetHealthUpdate(orb)
	local rawMaxHealth = orb.rawPetMaxHealth or orb.petMaxHealth
	local rawCurrentHealth = orb.rawPetCurrentHealth or orb.petCurrentHealth
	if not rc32CanUseValue(rawCurrentHealth) or not rc32CanUseValue(rawMaxHealth) then
		if orb.filling1Bar then
			orb.filling1:Hide()
			orb.filling1Bar:Show()
			orb.filling1Bar:SetMinMaxValues(0, rawMaxHealth or 1)
			orb.filling1Bar:SetValue(rawCurrentHealth or 0)
		end
		orb.galaxy1:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy2:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy3:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.font1:SetText(string.format("%s", rawCurrentHealth or ""))
		orb.font3:SetText("")
		return
	end
	local maxHealth = rc32SafeNumber(rawMaxHealth, 1)
	if maxHealth == 0 then maxHealth = 1 end
	local currentHealth = rc32SafeNumber(rawCurrentHealth, 0)
	previousPetHealth = rc32SafeNumber(previousPetHealth, currentHealth)
	local healthPercentage = currentHealth/maxHealth
	local inverseHealthPercentage = math.abs(healthPercentage - 1)

	local step = 0
	local onePercentHealth = maxHealth / 100

	local newValue = previousPetHealth
	if previousPetHealth < currentHealth then
		step = 1
		if previousPetHealth + (onePercentHealth * step) > currentHealth then
			newValue = currentHealth
		else
			newValue = previousPetHealth + (onePercentHealth * step)
		end
	elseif previousPetHealth > currentHealth then
		step = -1
		if previousPetHealth + (onePercentHealth * step) < currentHealth then
			newValue = currentHealth
		else
			newValue = previousPetHealth + (onePercentHealth * step)
		end
	end
	previousPetHealth = newValue

	local targetTexHeight = (previousPetHealth/maxHealth * (85 * orb:GetScale()))
	if targetTexHeight < 1 then targetTexHeight = 1 end
	local newDisplayPercentage = previousPetHealth/maxHealth
	if newDisplayPercentage > 1 then
		newDisplayPercentage = 0
		targetTexHeight = 1
	end
	local string1 = math.floor(newDisplayPercentage*100)
	if tonumber(string1) == nil then string1 = 0 end
	orb.font1:SetText(string1)
	
	local string = valueFormat(currentHealth,true)
	orb.font3:SetText(string)

	if orb.filling1Bar then orb.filling1Bar:Hide() end
	orb.filling1:Show()
	orb.filling1:SetHeight(targetTexHeight)
	orb.filling1:SetTexCoord(0,1,math.abs(newDisplayPercentage - 1),1)
	orb.galaxy1:SetAlpha(newDisplayPercentage * 0.2)
	orb.galaxy2:SetAlpha(newDisplayPercentage * 0.2)
	orb.galaxy3:SetAlpha(newDisplayPercentage * 0.2)
end

local previousPetPower = 0
local function PetPowerUpdate(orb)
	local rawMaxPower = orb.rawPetMaxPower or orb.petMaxPower
	local rawCurrentPower = orb.rawPetCurrentPower or orb.petCurrentPower
	if not rc32CanUseValue(rawCurrentPower) or not rc32CanUseValue(rawMaxPower) then
		if orb.filling2Bar then
			orb.filling2:Hide()
			orb.filling2Bar:Show()
			orb.filling2Bar:SetMinMaxValues(0, rawMaxPower or 1)
			orb.filling2Bar:SetValue(rawCurrentPower or 0)
		end
		orb.galaxy1:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy2:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.galaxy3:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
		orb.font2:SetText(string.format("%s", rawCurrentPower or ""))
		orb.font4:SetText("")
		return
	end
	local maxPower = rc32SafeNumber(rawMaxPower, 1)
	if maxPower == 0 then maxPower = 1 end
	local currentPower = rc32SafeNumber(rawCurrentPower, 0)
	previousPetPower = rc32SafeNumber(previousPetPower, currentPower)
	local powerPercentage = currentPower/maxPower
	local inversePowerPercentage = math.abs(powerPercentage - 1)

	local step = 0
	local fillPercentage = 100
	local onePercentPower = maxPower / fillPercentage

	local newValue = previousPetPower
	if previousPetPower < currentPower then
		step = 1
		if previousPetPower + (onePercentPower * step) > currentPower then
			newValue = currentPower
		else
			newValue = previousPetPower + (onePercentPower * step)
		end
	elseif previousPetPower > currentPower then
		step = -1
		if previousPetPower + (onePercentPower * step) < currentPower then
			newValue = currentPower
		else
			newValue = previousPetPower + (onePercentPower * step)
		end
	end
	previousPetPower = newValue

	local targetTexHeight = (previousPetPower/maxPower * (85 * orb:GetScale()))
	if targetTexHeight < 1 then targetTexHeight = 1 end
	local newDisplayPercentage = previousPetPower / maxPower
	if newDisplayPercentage > 1 then
		newDisplayPercentage = 0
		targetTexHeight = 1
	end
	local string1 = math.floor(newDisplayPercentage*100)
	if tonumber(string1) == nil then string1 = 0 end
	orb.font2:SetText(string1)
	
	local string = valueFormat(currentPower,true)
	orb.font4:SetText(string)	

	if orb.filling2Bar then orb.filling2Bar:Hide() end
	orb.filling2:Show()
	orb.filling2:SetHeight(targetTexHeight)
	orb.filling2:SetTexCoord(0,1,math.abs(newDisplayPercentage-1),1)
end

local function updatePetValues(orb)
	PetHealthUpdate(orb)
	PetPowerUpdate(orb)
end

local function CreateGalaxy(orb, file, duration,size,x,y)
	local galaxy = CreateFrame("Frame",nil,orb)
	galaxy:SetHeight(size)
	galaxy:SetWidth(size)
	galaxy:SetPoint("Center",x,y)
	galaxy:SetFrameLevel(4)

	local galTex = galaxy:CreateTexture()
	galTex:SetAllPoints(galaxy)
	galTex:SetTexture(file)
	galTex:SetBlendMode("ADD")
	galTex:SetAlpha(RC32_GALAXY_ALPHA_MULTIPLIER)
	galaxy.texture = galTex
	
	local animGroup = galaxy:CreateAnimationGroup()
	galaxy.animGroup = animGroup

	local anim1 = galaxy.animGroup:CreateAnimation("Rotation")
	anim1:SetDegrees(360)
	anim1:SetDuration(duration)
	galaxy.animGroup.anim1 = anim1

	animGroup:Play()
	animGroup:SetLooping("REPEAT")
	
	return galaxy
end 

local function CreateGlow(orb)
	local glow = CreateFrame("PlayerModel",nil, orb)
	glow:SetFrameStrata("BACKGROUND")
	glow:SetFrameLevel(5)
	glow:SetAllPoints(orb)
	local function safeSetModel(modelPath)
		if not modelPath or modelPath == "" then
			return false
		end
		if C_ModelInfo and C_ModelInfo.GetModelFileIDFromPath then
			local fileId = C_ModelInfo.GetModelFileIDFromPath(modelPath)
			if not fileId or fileId == 0 then
				return false
			end
		end
		return pcall(glow.SetModel, glow, modelPath)
	end

	if not safeSetModel(orbClassColors[charClassNumber].animation) then
		glow:Hide()
	end
	glow:SetAlpha(1)
	glow:SetScript("OnShow",function()
		if not safeSetModel(orbClassColors[charClassNumber].animation) then
			glow:Hide()
			return
		end
		glow:SetModelScale(1)
		glow:SetPosition(0,0,0)
	end)
	orb.glow = glow
end

local function menu()
	ToggleDropDownMenu(1, nil,"PlayerFrameDropDown", "cursor", 0, 0)
end

--orb creation experiment
local function CreateOrb(parent,name,size,fillTexture,galaxyTexture,offsetX,offsetY,relativePoint,monitorFunc)
	local orb
	orb = CreateFrame("Frame",name,UIParent)
	orb:SetHeight(size)
	orb:SetWidth(size)
	orb:SetFrameStrata("LOW")
	orb.bg = orb:CreateTexture(nil,"OVERLAY")
	orb.bg:SetTexture(images .. "orb_gloss3.tga")
	orb.bg:SetAllPoints(orb)
	orb.filling = orb:CreateTexture(nil,"BACKGROUND")
	orb.filling:SetTexture(images..fillTexture)
	orb.filling:SetPoint("BOTTOMLEFT",3,3)
	orb.filling:SetWidth(defaultOrbSize - 6)
	orb.filling:SetHeight(defaultOrbSize - 6)
	orb.filling:SetAlpha(1)
	orb.fillingBar = CreateFrame("StatusBar", nil, orb)
	orb.fillingBar:SetPoint("BOTTOMLEFT",3,3)
	orb.fillingBar:SetSize(defaultOrbSize - 6, defaultOrbSize - 6)
	orb.fillingBar:SetOrientation("VERTICAL")
	orb.fillingBar:SetStatusBarTexture(images..fillTexture)
	orb.fillingBar:SetMinMaxValues(0, 1)
	orb.fillingBar:SetValue(1)
	orb.fillingBar:Hide()
	orb.fillingBarText = orb.fillingBar:CreateFontString(nil, "OVERLAY")
	orb.fillingBarText:SetFont(RC32CharacterData.font,28,"THINOUTLINE")
	orb.fillingBarText:SetPoint("CENTER",0,15)
	local orbGlossHolder = CreateFrame("Frame",nil,orb)
	orbGlossHolder:SetAllPoints(orb)
	orbGlossHolder:SetFrameStrata("BACKGROUND")
	local orbGlossOverlay = orbGlossHolder:CreateTexture(nil,"BACKGROUND")
	orbGlossOverlay:SetTexture(images .. "orb_gloss3.tga")
	orbGlossOverlay:SetAllPoints(orbGlossHolder)
	local newRand = math.random(20,50)
	orb.galaxy1 = CreateGalaxy(orb, images..galaxyTexture.."1.tga",newRand,defaultOrbSize-5,0,0)
	newRand = math.random(30,70)
	orb.galaxy2 = CreateGalaxy(orb,images..galaxyTexture.."2.tga", newRand,defaultOrbSize-5,0,0)
	newRand = math.random(18,27)
	orb.galaxy3 = CreateGalaxy(orb,images..galaxyTexture.."3.tga", newRand,defaultOrbSize-5,0,0)
	orb.updateFrame = CreateFrame("Frame", nil, UIParent)
	orb.updateFrame:SetScript("OnUpdate", function()
		if monitorFunc then
			monitorFunc(orb)
		end
	end)
	orb.fontHolder = CreateFrame("FRAME",nil,orb)
	orb.fontHolder:SetFrameStrata("MEDIUM")
	orb.fontHolder:SetAllPoints(orb)
	orb.font1 = orb.fontHolder:CreateFontString(nil, "OVERLAY")
	orb.font1:SetFont(RC32CharacterData.font,28,"THINOUTLINE")
	orb.font1:SetPoint("CENTER",0,15)
	orb.font2 = orb.fontHolder:CreateFontString(nil,"OVERLAY")
	orb.font2:SetFont(RC32CharacterData.font,16,"THINOUTLINE")
	orb.font2:SetPoint("CENTER",0,-5)
	
	--position defaults
	orb:ClearAllPoints()
	orb:SetPoint(relativePoint,nil,relativePoint,offsetX,offsetY)
	
	--show the orb
	orb:Show()

	--fill the orb with colors! WOO!
	orb.filling:SetVertexColor(1,1,1,1)
	orb.currentHealth = 1
	orb.maxHealth = 1
	orb.currentPower = 1
	orb.maxPower = 1
	orb.isDead = false

	--secure click overlay for targeting/menu
	orb.secure = CreateFrame("Button", name.."Secure", orb, "SecureActionButtonTemplate")
	orb.secure:SetAllPoints(orb)
	orb.secure:RegisterForClicks("AnyUp")
	orb.secure:SetAttribute("type1","target")
	orb.secure:SetAttribute("type2","togglemenu")
	orb.secure:SetAttribute("unit","player")
	orb.secure.menu = function(self) ToggleDropDownMenu(1, 1, PlayerFrameDropDown, "cursor", 0 ,0) end
	orb.tooltip = CreateFrame("GameTooltip","PlayerTooltip",nil,"GameToolTipTemplate")
	orb.secure:SetScript("OnEnter", function()
		GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
		GameTooltip:SetUnit("player")
		GameTooltip:Show()
	end)
	orb.secure:SetScript("OnLeave",function()
		GameTooltip:Hide()
	end)


	--place setup the appropriate character events on the health orb
	return orb
end

local function CreatePetOrb(parent,name,size,offsetX,offsetY,monitorFunc)
	local orb
	orb = CreateFrame("Frame",name,parent)
	orb:SetHeight(size)
	orb:SetWidth(size)
	orb:SetFrameStrata("BACKGROUND")
	orb.bg = orb:CreateTexture(nil,"OVERLAY")
	orb.bg:SetTexture(images .. "orb_gloss3.tga")
	orb.bg:SetAllPoints(orb)
	orb.filling1 = orb:CreateTexture(nil,"BACKGROUND")
	orb.filling1:SetTexture(images.."petFilling_health.tga")
	orb.filling1:SetPoint("BOTTOMLEFT",3,0)
	orb.filling1:SetWidth(size / 2 - 3)
	orb.filling1:SetHeight(size - 6)
	orb.filling1:SetAlpha(1)
	orb.filling1Bar = CreateFrame("StatusBar", nil, orb)
	orb.filling1Bar:SetPoint("BOTTOMLEFT",3,0)
	orb.filling1Bar:SetSize(size / 2 - 3, size - 6)
	orb.filling1Bar:SetOrientation("VERTICAL")
	orb.filling1Bar:SetStatusBarTexture(images.."petFilling_health.tga")
	orb.filling1Bar:SetMinMaxValues(0, 1)
	orb.filling1Bar:SetValue(1)
	orb.filling1Bar:Hide()
	orb.filling1BarText = orb.filling1Bar:CreateFontString(nil, "OVERLAY")
	orb.filling1BarText:SetFont(RC32CharacterData.font,14,"THINOUTLINE")
	orb.filling1BarText:SetPoint("CENTER",-20,5)
	orb.filling2 = orb:CreateTexture(nil,"BACKGROUND")
	orb.filling2:SetTexture(images.."petFilling_power.tga")
	orb.filling2:SetPoint("BOTTOMRIGHT",-3,0)
	orb.filling2:SetWidth(size / 2 - 3)
	orb.filling2:SetHeight(size - 6)
	orb.filling2:SetAlpha(1)
	orb.filling2Bar = CreateFrame("StatusBar", nil, orb)
	orb.filling2Bar:SetPoint("BOTTOMRIGHT",-3,0)
	orb.filling2Bar:SetSize(size / 2 - 3, size - 6)
	orb.filling2Bar:SetOrientation("VERTICAL")
	orb.filling2Bar:SetStatusBarTexture(images.."petFilling_power.tga")
	orb.filling2Bar:SetMinMaxValues(0, 1)
	orb.filling2Bar:SetValue(1)
	orb.filling2Bar:Hide()
	orb.filling2BarText = orb.filling2Bar:CreateFontString(nil, "OVERLAY")
	orb.filling2BarText:SetFont(RC32CharacterData.font,14,"THINOUTLINE")
	orb.filling2BarText:SetPoint("CENTER",20,5)
	local orbGlossHolder = CreateFrame("Frame",nil,orb)
	orbGlossHolder:SetAllPoints(orb)
	orbGlossHolder:SetFrameStrata("LOW")
	local orbGlossOverlay = orbGlossHolder:CreateTexture(nil,"BACKGROUND")
	orbGlossOverlay:SetTexture(images .. "orb_gloss3.tga")
	orbGlossOverlay:SetAllPoints(orbGlossHolder)
	
	orb.divider = CreateFrame("Frame",nil,orb)
	orb.divider.texture = orb.divider:CreateTexture(nil,"OVERLAY")
	orb.divider.texture:SetTexture(images.."middleBar.tga")
	orb.divider:SetAllPoints(true)
	orb.divider.texture:SetAllPoints(true)
	orb.galaxy1 = CreateGalaxy(orb, RC32RotationTextureChoices[1].."1.tga",36,size-8,0,0)
	orb.galaxy2 = CreateGalaxy(orb, RC32RotationTextureChoices[1].."2.tga", 22,size-8,0,0)
	orb.galaxy3 = CreateGalaxy(orb, RC32RotationTextureChoices[1].."3.tga", 29,size-8,0,0)
	orb.galaxy1:SetAlpha(0.3)
	orb.galaxy2:SetAlpha(0.3)
	orb.galaxy3:SetAlpha(0.3)
	-- Don't create glow for pet orb - the PlayerModel can cause white box issues
	-- CreateGlow(orb)
	
	orb.fontHolder = CreateFrame("FRAME",nil,orb)
	orb.fontHolder:SetFrameStrata("MEDIUM")
	orb.fontHolder:SetAllPoints(orb)
	orb.font1 = orb.fontHolder:CreateFontString(nil, "OVERLAY")
	orb.font1:SetFont(RC32CharacterData.font,14,"THINOUTLINE")
	orb.font1:SetPoint("CENTER",-20,5)
	orb.font1:SetText("100")
	orb.font2 = orb.fontHolder:CreateFontString(nil,"OVERLAY")
	orb.font2:SetFont(RC32CharacterData.font,14,"THINOUTLINE")
	orb.font2:SetPoint("CENTER",20,5)
	orb.font2:SetText("100")
	orb.font3 = orb.fontHolder:CreateFontString(nil, "OVERLAY")
	orb.font3:SetFont(RC32CharacterData.font,9,"THINOUTLINE")
	orb.font3:SetPoint("CENTER",-20,-8)
	orb.font3:SetText("100")
	orb.font4 = orb.fontHolder:CreateFontString(nil,"OVERLAY")
	orb.font4:SetFont(RC32CharacterData.font,9,"THINOUTLINE")
	orb.font4:SetPoint("CENTER",20,-8)
	orb.font4:SetText("100")
	
	orb.updateFrame = CreateFrame("Frame", nil, UIParent)
	orb.updateFrame:SetScript("OnUpdate", function()
		updatePetValues(orb)
	end)
	
	--position defaults
	orb:ClearAllPoints()
	orb:SetPoint("CENTER",offsetX,offsetY)
	
	--show the orb
	orb:Show()

	--fill the orb with colors! WOO!
	local r, g, b, a = healthOrb.filling:GetVertexColor()
	orb.filling1:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
	r, g, b, a = manaOrb.filling:GetVertexColor()
	orb.filling2:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
	orb.petCurrentHealth = 0
	orb.petMaxHealth = 1
	orb.petCurrentPower = 0
	orb.petMaxPower = 1
	
	orb.secure = CreateFrame("Button", name.."Secure", orb, "SecureActionButtonTemplate")
	orb.secure:SetAllPoints(orb)
	orb.secure:RegisterForClicks("AnyUp")
	orb.secure:SetAttribute("type1","target")
	orb.secure:SetAttribute("type2","menu")
	orb.secure:SetAttribute("unit","pet")
	orb.secure.menu = function(self) ToggleDropDownMenu(1, 1, PetFrameDropDown, "cursor", 0 ,0) end
	orb.tooltip = CreateFrame("GameTooltip","PetToolTip",nil,"GameToolTipTemplate")
	orb.secure:SetScript("OnEnter", function()
		GameTooltip_SetDefaultAnchor(GameTooltip,UIParent)
		GameTooltip:SetUnit("pet")
		GameTooltip:Show()
	end)
	orb.secure:SetScript("OnLeave",function()
		GameTooltip:Hide()
	end)

	RC32_RegisterUnitWatch(orb.secure)
	orb.secure:SetScript("OnShow", function() orb:Show() end)
	orb.secure:SetScript("OnHide", function() orb:Hide() end)

	--place setup the appropriate character events on the health orb
	return orb
end

local function CreateXMLOrb(parent,name,size,fillTexture,galaxyTexture)
	local orb
	orb = CreateFrame("Button",name,parent,nil)
	orb:SetHeight(size)
	orb:SetWidth(size)
	orb:SetFrameStrata("HIGH")
	orb.bg = orb:CreateTexture(nil,"OVERLAY")
	orb.bg:SetTexture(images .. "orb_gloss3.tga")
	orb.bg:SetAllPoints(orb)
	orb.filling = orb:CreateTexture(nil,"BACKGROUND")
	orb.filling:SetTexture(images..fillTexture)
	orb.filling:SetPoint("BOTTOMLEFT",3,3)
	orb.filling:SetWidth(size - 6)
	orb.filling:SetHeight(size-6)
	orb.filling:SetAlpha(1)
	local orbGlossHolder = CreateFrame("Frame",nil,orb)
	orbGlossHolder:SetAllPoints(orb)
	orbGlossHolder:SetFrameStrata("LOW")
	local orbGlossOverlay = orbGlossHolder:CreateTexture(nil,"BACKGROUND")
	orbGlossOverlay:SetTexture(images .. "orb_gloss3.tga")
	orbGlossOverlay:SetAllPoints(orbGlossHolder)
	local newRand = math.random(20,50)
	orb.galaxy1 = CreateGalaxy(orb, images..galaxyTexture.."1.tga",newRand,size-3,0,0)
	newRand = math.random(30,70)
	orb.galaxy2 = CreateGalaxy(orb,images..galaxyTexture.."2.tga", newRand,size-3,0,0)
	newRand = math.random(18,27)
	orb.galaxy3 = CreateGalaxy(orb,images..galaxyTexture.."3.tga", newRand,size-3,0,0)
	
	CreateGlow(orb)
	orb.fontHolder = CreateFrame("FRAME",nil,orb)
	orb.fontHolder:SetFrameStrata("HIGH")
	orb.fontHolder:SetAllPoints(orb)
	orb.font1 = orb.fontHolder:CreateFontString(nil, "OVERLAY")
	orb.font1:SetFont(RC32CharacterData.font,28,"THINOUTLINE")
	orb.font1:SetText("100")
	orb.font1:SetPoint("CENTER",0,15)
	orb.font2 = orb.fontHolder:CreateFontString(nil,"OVERLAY")
	orb.font2:SetFont(RC32CharacterData.font,16,"THINOUTLINE")
	orb.font2:SetText("100000")
	orb.font2:SetPoint("CENTER",0,-5)
	
	--position defaults
	orb:ClearAllPoints()
	orb:SetAllPoints(xmlOrbDisplayFrame2)
	
	--show the orb
	orb:Show()

	--fill the orb with colors! WOO!
	orb.filling:SetVertexColor(1,1,1,1)
	return orb
end

local function addArtwork(file,orb,name,offsetX,offsetY,height,width)
	local art = CreateFrame("Frame","RC32"..name,orb)
	art:SetPoint("CENTER",offsetX,offsetY)
	art:SetHeight(height)
	art:SetWidth(width)
	art:SetFrameStrata("MEDIUM")
	art.texture = art:CreateTexture(nil,"OVERLAY")
	art.texture:SetTexture(file)
	art.texture:SetAllPoints(art)
	return art
end

function RC32SetGlobalScale(val)
	val = val/100
	healthOrb:SetScale(val)
	RC32CharacterData.healthOrb.scale = val
	manaOrb:SetScale(val)
	RC32CharacterData.manaOrb.scale = val
end

function RC32SetOrbScale(orbType, val)
	val = val/100
	if orbType == "health" then
		healthOrb:SetScale(val)
		RC32CharacterData.healthOrb.scale = val
	elseif orbType == "mana" then
		manaOrb:SetScale(val)
		RC32CharacterData.manaOrb.scale = val
	elseif orbType == "pet" then
		petOrb:SetScale(val)
		RC32CharacterData.petOrb.scale = val
	end
end

function RC32SetPowerTrackerRotation(degrees)
	if segmentedPowerTracker then
		segmentedPowerTracker:SetRotation(degrees)
		-- Save to account-wide data so all characters share the same position
		if not RC32AccountData then RC32AccountData = {} end
		RC32AccountData.powerTrackerRotation = degrees
	end
end

function RC32SetPowerTrackerScale(val)
	if segmentedPowerTracker then
		segmentedPowerTracker:SetScale(val / 100)
		-- Save to account-wide data so all characters share the same scale
		if not RC32AccountData then RC32AccountData = {} end
		RC32AccountData.powerTrackerScale = val
	end
end

-- Initialize the max stack sound dropdown
function RC32_InitMaxStackSoundDropdown()
	local dropdown = RC32MaxStackSoundDropdown
	if not dropdown then return end
	
	UIDropDownMenu_SetWidth(dropdown, 100)
	UIDropDownMenu_SetButtonWidth(dropdown, 124)
	
	local selectedIndex = RC32CharacterData.powerFrame.maxStackSound or 1
	UIDropDownMenu_SetText(dropdown, RC32_MaxStackSounds[selectedIndex].name)
	
	UIDropDownMenu_Initialize(dropdown, function(self, level)
		for i, sound in ipairs(RC32_MaxStackSounds) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = sound.name
			info.value = i
			info.func = function(self)
				RC32CharacterData.powerFrame.maxStackSound = self.value
				UIDropDownMenu_SetText(dropdown, RC32_MaxStackSounds[self.value].name)
				-- Play preview sound on Master channel for louder volume
				if RC32_MaxStackSounds[self.value].id > 0 then
					PlaySound(RC32_MaxStackSounds[self.value].id, "Master")
				end
			end
			info.checked = (i == (RC32CharacterData.powerFrame.maxStackSound or 1))
			UIDropDownMenu_AddButton(info, level)
		end
	end)
end

-- Menu Background options
RC32_MenuBackgrounds = {
	[1] = {name = "Chicken", file = "CHICKEN_backdrop.tga"},
	[2] = {name = "Sindragosa", file = "Sindragosa.tga"},
	[3] = {name = "Lich King", file = "Lich_King.tga"},
	[4] = {name = "Lich King 2", file = "Lich_King_2.tga"},
	[5] = {name = "Illidan", file = "Illidan.tga"},
	[6] = {name = "Deathwing", file = "Deathwing.tga"},
	[7] = {name = "Alliance", file = "Alliance.tga"},
	[8] = {name = "Horde", file = "Horde.tga"},
}

function RC32_InitMenuBackgroundDropdown()
	local dropdown = RC32MenuBackgroundDropdown
	if not dropdown then return end
	
	UIDropDownMenu_SetWidth(dropdown, 120)
	UIDropDownMenu_SetButtonWidth(dropdown, 144)
	
	local selectedIndex = RC32AccountData and RC32AccountData.menuBackground or 1
	UIDropDownMenu_SetText(dropdown, RC32_MenuBackgrounds[selectedIndex].name)
	
	UIDropDownMenu_Initialize(dropdown, function(self, level)
		for i, bg in ipairs(RC32_MenuBackgrounds) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = bg.name
			info.value = i
			info.func = function(self)
				if not RC32AccountData then RC32AccountData = {} end
				RC32AccountData.menuBackground = self.value
				UIDropDownMenu_SetText(dropdown, RC32_MenuBackgrounds[self.value].name)
				RC32_SetMenuBackground(self.value)
			end
			info.checked = (i == (RC32AccountData and RC32AccountData.menuBackground or 1))
			UIDropDownMenu_AddButton(info, level)
		end
	end)
end

function RC32_SetMenuBackground(index)
	local bg = RC32_MenuBackgrounds[index]
	if bg and RC32GUIBackground then
		RC32GUIBackground:SetTexture("Interface\\AddOns\\RCDiabloOrbs\\images\\"..bg.file)
	end
	-- Set border color based on background
	-- Chicken = white, Sindragosa/Lich King/Lich King 2 = purple, Illidan = yellow, Deathwing = red, Alliance = blue, Horde = red
	local borderColors = {
		[1] = {r = 1, g = 1, b = 1},           -- Chicken = white
		[2] = {r = 0.8, g = 0.3, b = 1},       -- Sindragosa = purple
		[3] = {r = 0.8, g = 0.3, b = 1},       -- Lich King = purple
		[4] = {r = 0.8, g = 0.3, b = 1},       -- Lich King 2 = purple
		[5] = {r = 1, g = 1, b = 0.3},         -- Illidan = yellow
		[6] = {r = 1, g = 0.3, b = 0.3},       -- Deathwing = red
		[7] = {r = 0.3, g = 0.5, b = 1},       -- Alliance = blue
		[8] = {r = 1, g = 0.3, b = 0.3},       -- Horde = red
	}
	local color = borderColors[index] or {r = 1, g = 1, b = 1}
	RC32_SetBorderColor(color.r, color.g, color.b)
end

function RC32MonitorPowers(frame)
	local powerType
	powerFrame.text:SetPoint("CENTER",-1,0)
	if RC32className == "Warlock" then
		if not RC32_IS_CATA_OR_LATER then
			-- Pre-Cata warlocks don't have these resource types
			frame.backDrop:Hide()
			frame.text:Hide()
			return
		end
		local maxResource = 0
		local usable, nomana = IsUsableSpell("Metamorphosis")
		if usable or (not usable and nomana) then
			powerType = RC32_IS_MOP_OR_LATER and 15 or nil
			maxResource = 1000
		end
		usable, nomana = IsUsableSpell("Chaos Bolt")
		if usable or (not usable and nomana) then
			powerType = RC32_IS_MOP_OR_LATER and 14 or nil
			maxResource = 3
		end
		usable, nomana = IsUsableSpell("Soulburn")
		if usable or (not usable and nomana) then
			powerType = RC32_POWER_SOUL_SHARDS
			maxResource = 3
		end
		if not powerType then
			frame.backDrop:Hide()
			frame.text:Hide()
			return
		end
		local numShards = RC32_UnitPower("player",powerType)
		if RC32_IS_MOP_OR_LATER and powerType == 14 then
			numShards = (RC32_UnitPower("player",powerType,true)/10)
		end
		if numShards > 0 then
			if not frame.backDrop:IsVisible() then
				frame.backDrop:Show()
				frame.text:Show()
			end
		else
			if frame.backDrop:IsVisible() then
				frame.backDrop:Hide()
				frame.text:Hide()
			end
		end
		if numShards > 999 then
			powerFrame.text:SetFont(RC32CharacterData.font,15,"THINOUTLINE")
		elseif numShards > 99 then
			powerFrame.text:SetFont(RC32CharacterData.font,18,"THINOUTLINE")
		elseif numShards > 9 then
			powerFrame.text:SetFont(RC32CharacterData.font,24,"THINOUTLINE")
		else
			powerFrame.text:SetFont(RC32CharacterData.font,26,"THINOUTLINE")
		end
		frame.text:SetText(numShards)
		if numShards > 1 then
			powerFrame.text:SetPoint("CENTER",1,0)
		else
			powerFrame.text:SetPoint("CENTER",0,0)
		end
		if numShards >= maxResource then
			powerFrame.fontHolder.animGroup:Play()
		else
			powerFrame.fontHolder.animGroup:Stop()
		end
	elseif RC32className == "Paladin" then
		if not RC32_IS_CATA_OR_LATER or not RC32_POWER_HOLY_POWER then
			frame.backDrop:Hide()
			frame.text:Hide()
			return
		end
		powerType = RC32_POWER_HOLY_POWER
		local numHolyPower = RC32_UnitPower("player",powerType)
		if numHolyPower > 0 then
			if not frame.backDrop:IsVisible() then
				frame.backDrop:Show()
				frame.text:Show()
			end
		else
			if frame.backDrop:IsVisible() then
				frame.backDrop:Hide()
				frame.text:Hide()
			end
		end
		frame.text:SetText(numHolyPower)
		if numHolyPower > 1 then
			powerFrame.text:SetPoint("CENTER",1,0)
		end
		if numHolyPower >=3 then
			powerFrame.fontHolder.animGroup:Play()
		else
			powerFrame.fontHolder.animGroup:Stop()
		end
	elseif RC32className == "Monk" then
		if not RC32_IS_MOP_OR_LATER or not RC32_POWER_CHI then
			frame.backDrop:Hide()
			frame.text:Hide()
			return
		end
		powerType = RC32_POWER_CHI
		local numHolyPower = RC32_UnitPower("player",powerType)
		if numHolyPower > 0 then
			if not frame.backDrop:IsVisible() then
				frame.backDrop:Show()
				frame.text:Show()
			end
		else
			if frame.backDrop:IsVisible() then
				frame.backDrop:Hide()
				frame.text:Hide()
			end
		end
		frame.text:SetText(numHolyPower)
		if numHolyPower > 1 then
			powerFrame.text:SetPoint("CENTER",1,0)
		end
		if numHolyPower >=4 then
			powerFrame.fontHolder.animGroup:Play()
		else
			powerFrame.fontHolder.animGroup:Stop()
		end
	elseif RC32className == "Priest" then
		if not RC32_IS_CATA_OR_LATER or not RC32_POWER_SHADOW_ORBS then
			frame.backDrop:Hide()
			frame.text:Hide()
			return
		end
		powerType = RC32_POWER_SHADOW_ORBS
		local numHolyPower = RC32_UnitPower("player",powerType)
		if numHolyPower > 0 then
			if not frame.backDrop:IsVisible() then
				frame.backDrop:Show()
				frame.text:Show()
			end
		else
			if frame.backDrop:IsVisible() then
				frame.backDrop:Hide()
				frame.text:Hide()
			end
		end
		frame.text:SetText(numHolyPower)
		if numHolyPower > 1 then
			powerFrame.text:SetPoint("CENTER",1,0)
		end
		if numHolyPower >=3 then
			powerFrame.fontHolder.animGroup:Play()
		else
			powerFrame.fontHolder.animGroup:Stop()
		end
	elseif RC32className == "Rogue" or RC32className == "Druid" then
		local comboPoints = RC32_GetComboPoints()
		if comboPoints > 0 then
			if not frame.backDrop:IsVisible() then
				frame.backDrop:Show()
				frame.text:Show()
			end
		else
			if frame.backDrop:IsVisible() then
				frame.backDrop:Hide()
				frame.text:Hide()
			end
		end
		frame.text:SetText(comboPoints)
		if comboPoints > 1 then
			powerFrame.text:SetPoint("CENTER",1,0)
		end
		if comboPoints >=5 then
			powerFrame.fontHolder.animGroup:Play()
		else
			powerFrame.fontHolder.animGroup:Stop()
		end
	elseif RC32className == "Mage" then
		--turns out there is no way to track the ice shards for Mage.  Stubbed for now.
	end

end

-- Segmented Power Tracker using curved arc segments
segmentedPowerTracker = nil  -- Global so XML can access it
local function CreateSegmentedPowerTracker(parentOrb, numSegments, orbSize)
	-- Create container frame, same size as the ring overlay
	local trackerSize = orbSize + 40
	local tracker = CreateFrame("Frame", "RC32SegmentedPowerTracker", parentOrb)
	tracker:SetSize(trackerSize, trackerSize)
	tracker:SetPoint("CENTER", parentOrb, "CENTER", 0, 0)
	tracker:SetFrameLevel(parentOrb:GetFrameLevel() + 1)
	
	tracker.segments = {}
	tracker.backdropSegments = {}
	tracker.numSegments = numSegments
	tracker.baseRotation = 0
	
	-- Get colors with fallback defaults
	local r, g, b = 1, 1, 1
	if RC32CharacterData and RC32CharacterData.healthOrb and RC32CharacterData.healthOrb.orbColor then
		r = RC32CharacterData.healthOrb.orbColor.r or 1
		g = RC32CharacterData.healthOrb.orbColor.g or 1
		b = RC32CharacterData.healthOrb.orbColor.b or 1
	end
	
	-- We have 4 ember segment textures, each covering ~22.5 degrees
	-- For classes with 3, 4, or 5 segments, we map them appropriately
	-- Texture 1 = leftmost (10 o'clock area), Texture 4 = rightmost (2 o'clock area)
	
	-- Create backdrop segments (grey, always visible)
	for i = 1, numSegments do
		local backdrop = tracker:CreateTexture(nil, "BACKGROUND")
		backdrop:SetSize(trackerSize, trackerSize)
		backdrop:SetPoint("CENTER", tracker, "CENTER", 0, 0)
		-- Use modulo to cycle through available textures if more than 4 segments
		local texIndex = ((i - 1) % 4) + 1
		backdrop:SetTexture("Interface\\AddOns\\RCDiabloOrbs\\images\\ember_segment_"..texIndex..".tga")
		backdrop:SetVertexColor(0.3, 0.3, 0.3, 0.6)  -- Grey, semi-transparent
		backdrop:Show()  -- Always visible
		tracker.backdropSegments[i] = backdrop
	end
	
	-- Create arc-shaped segments
	for i = 1, numSegments do
		local segment = tracker:CreateTexture(nil, "ARTWORK")
		segment:SetSize(trackerSize, trackerSize)
		segment:SetPoint("CENTER", tracker, "CENTER", 0, 0)
		-- Use modulo to cycle through available textures if more than 4 segments
		local texIndex = ((i - 1) % 4) + 1
		segment:SetTexture("Interface\\AddOns\\RCDiabloOrbs\\images\\ember_segment_"..texIndex..".tga")
		-- Use the health orb's class color
		segment:SetVertexColor(r, g, b, 1)
		segment:Hide()  -- Start hidden
		tracker.segments[i] = segment
	end
	
	-- Track previous power for sound trigger
	tracker.previousPower = 0
	
	-- Update function - Fill segments based on power
	tracker.UpdateSegments = function(self, currentPower)
		for i = 1, self.numSegments do
			if i <= currentPower then
				self.segments[i]:Show()
			else
				self.segments[i]:Hide()
			end
		end
		
		-- Play sound when reaching max stacks (and wasn't already at max)
		if currentPower >= self.numSegments and self.previousPower < self.numSegments then
			local soundIndex = RC32CharacterData.powerFrame.maxStackSound or 1
			local soundId = RC32_MaxStackSounds[soundIndex] and RC32_MaxStackSounds[soundIndex].id or 0
			if soundId > 0 then
				PlaySound(soundId, "Master")
			end
		end
		self.previousPower = currentPower
	end
	
	-- Update colors function (accepts optional r,g,b or uses class color)
	tracker.UpdateColors = function(self, r, g, b)
		local cr, cg, cb = r, g, b
		if not r then
			-- Use class color
			local currentClassNumber = getClassColor()
			local classColor = orbClassColors[currentClassNumber].health
			cr = classColor.r or 1
			cg = classColor.g or 1
			cb = classColor.b or 1
		end
		for i = 1, self.numSegments do
			self.segments[i]:SetVertexColor(cr, cg, cb, 1)
		end
	end
	
	-- Set rotation (in degrees, clockwise) - rotates entire tracker around the orb
	-- This rotates each texture by the same amount, causing the whole arc to spin around
	tracker.SetRotation = function(self, degrees)
		self.baseRotation = degrees
		-- WoW's SetRotation uses radians, positive = counter-clockwise
		-- So we negate to make positive degrees = clockwise
		local radians = -math.rad(degrees)
		for i = 1, self.numSegments do
			self.segments[i]:SetRotation(radians)
			self.backdropSegments[i]:SetRotation(radians)
		end
	end
	
	tracker:Show()
	return tracker
end

-- Segmented power tracker monitor function
function RC32MonitorSegmentedPowers(frame)
	if not RC32CharacterData.powerFrame or not RC32CharacterData.powerFrame.show then
		return
	end
	
	local powerType
	local numPower = 0
	
	if RC32className == "Warlock" then
		if RC32_IS_CATA_OR_LATER then
			powerType = UnitPowerType("player")
			if powerType == 0 then
				if RC32_IS_MOP_OR_LATER and RC32_UnitPowerMax("player", 14) > 0 then
					powerType = 14  -- Burning Embers
				elseif RC32_IS_MOP_OR_LATER and RC32_UnitPowerMax("player", 11) > 0 then
					powerType = 11  -- Demonic Fury
				else
					powerType = RC32_POWER_SOUL_SHARDS
				end
			end
			numPower = RC32_UnitPower("player", powerType)
		end
	elseif RC32className == "Paladin" then
		if RC32_IS_CATA_OR_LATER and RC32_POWER_HOLY_POWER then
			powerType = RC32_POWER_HOLY_POWER
			numPower = RC32_UnitPower("player", powerType)
		end
	elseif RC32className == "Monk" then
		if RC32_IS_MOP_OR_LATER and RC32_POWER_CHI then
			powerType = RC32_POWER_CHI
			numPower = RC32_UnitPower("player", powerType)
		end
	elseif RC32className == "Rogue" or RC32className == "Druid" then
		numPower = RC32_GetComboPoints()
		segmentedPowerTracker:UpdateSegments(numPower)
		return
	elseif RC32className == "Priest" then
		if RC32_IS_CATA_OR_LATER and RC32_POWER_SHADOW_ORBS then
			powerType = RC32_POWER_SHADOW_ORBS
			numPower = RC32_UnitPower("player", powerType)
		end
	elseif RC32className == "Shaman" then
		if RC32_IS_MOP_OR_LATER then
			powerType = 11  -- Maelstrom
			numPower = RC32_UnitPower("player", powerType)
		end
	end
	
	segmentedPowerTracker:UpdateSegments(numPower)
end

local function createPowerFrame(file,orb,name,offsetX,offsetY,height,width)
	local powerFrame = CreateFrame("Frame","RC32"..name,orb)
	powerFrame:SetFrameStrata("BACKGROUND")
	powerFrame:SetPoint("CENTER",offsetX,offsetY)
	powerFrame:SetHeight(height)
	powerFrame:SetWidth(width)
	
	--gradient backdrop
	powerFrame.backDrop = CreateFrame("Frame","RC32"..name.."Backdrop",powerFrame)
	powerFrame.backDrop:SetAllPoints(true)
	powerFrame.backDrop.backTexture = powerFrame.backDrop:CreateTexture(nil,"BACKGROUND")
	powerFrame.backDrop.backTexture:SetTexture(images.."d32_powerFrame_backdrop.tga")
	powerFrame.backDrop.backTexture:SetAllPoints(powerFrame)
	
	--shadowed frame, colorizable
	powerFrame.texture = powerFrame.backDrop:CreateTexture(nil,"OVERLAY")
	powerFrame.texture:SetTexture(file)
	local orbColor = RC32CharacterData and RC32CharacterData.healthOrb and RC32CharacterData.healthOrb.orbColor
	if orbColor then
		powerFrame.texture:SetVertexColor(orbColor.r or 1, orbColor.g or 1, orbColor.b or 1, orbColor.a or 1)
	else
		powerFrame.texture:SetVertexColor(1, 1, 1, 1)
	end
	powerFrame.texture:SetAllPoints(true)
	
	--fontholder frame for animations
	powerFrame.fontHolder = CreateFrame("Frame",nil,powerFrame)
	powerFrame.fontHolder:SetFrameStrata("LOW")
	powerFrame.fontHolder:SetAllPoints(true)
	
	--text
	powerFrame.text = powerFrame.fontHolder:CreateFontString(nil,"OVERLAY")
	local fontPath = (RC32CharacterData and RC32CharacterData.font) or "Fonts\\FRIZQT__.TTF"
	powerFrame.text:SetFont(fontPath,29,"THINOUTLINE")
	powerFrame.text:SetPoint("CENTER",0,1)
	if orbColor then
		powerFrame.text:SetTextColor(orbColor.r or 1, orbColor.g or 1, orbColor.b or 1, orbColor.a or 1)
	else
		powerFrame.text:SetTextColor(1, 1, 1, 1)
	end
	powerFrame.text:SetText("1")
	
	local animGroup = powerFrame.fontHolder:CreateAnimationGroup()
	powerFrame.fontHolder.animGroup = animGroup
	
	local anim1 = powerFrame.fontHolder.animGroup:CreateAnimation("Alpha")
	anim1:SetFromAlpha(1)
	anim1:SetToAlpha(0)
	anim1:SetOrder(1)
	anim1:SetDuration(.7)
	powerFrame.fontHolder.anim1 = anim1
	
	local anim2 = powerFrame.fontHolder.animGroup:CreateAnimation("Alpha")
	anim2:SetFromAlpha(0)
	anim2:SetToAlpha(1)
	anim2:SetOrder(2)
	anim2:SetDuration(.7)
	powerFrame.fontHolder.anim2 = anim2
	
	animGroup:SetLooping("REPEAT")
	
	
	--updates and wh
	powerFrame:SetScript("OnUpdate",RC32MonitorPowers)
	powerFrame:Show()
	
	return powerFrame
end


function checkPetFontPlacement()
	if RC32CharacterData.petOrb.showValue and RC32CharacterData.petOrb.showPercentage then
		petOrb.font3:SetPoint("CENTER",-20,-8)
		petOrb.font4:SetPoint("CENTER",20,-8)
		petOrb.font1:SetPoint("CENTER",-20,5)
		petOrb.font2:SetPoint("CENTER",20,5)
		petOrb.font3:SetFont(RC32CharacterData.font,9,"THINOUTLINE")
		petOrb.font4:SetFont(RC32CharacterData.font,9,"THINOUTLINE")
	elseif RC32CharacterData.petOrb.showValue and not RC32CharacterData.petOrb.showPercentage then
		petOrb.font3:SetPoint("CENTER",-20,0)
		petOrb.font4:SetPoint("CENTER",20,0)
		petOrb.font3:SetFont(RC32CharacterData.font,11 * petOrb:GetScale(),"THINOUTLINE")
		petOrb.font4:SetFont(RC32CharacterData.font,11 * petOrb:GetScale(),"THINOUTLINE")
	elseif not RC32CharacterData.petOrb.showValue and RC32CharacterData.petOrb.showPercentage then
		petOrb.font1:SetPoint("CENTER",-20,0)
		petOrb.font2:SetPoint("CENTER",20,0)
	end
end

function setOrbFontPlacement(orb,orbData)
	orb.font1:Show()
	orb.font2:Show()
	if orbData.font1.show and orbData.font2.show then
		orb.font1:SetFont(RC32CharacterData.font,28,"THINOUTLINE")
		orb.font2:SetFont(RC32CharacterData.font,16,"THINOUTLINE")
		orb.font1:SetPoint("CENTER",0,15)
		orb.font2:SetPoint("CENTER",0,-5)
	elseif orbData.font1.show and not orbData.font2.show then
		orb.font1:SetFont(RC32CharacterData.font,28,"THINOUTLINE")
		orb.font1:SetPoint("CENTER",0,0)
		orb.font2:Hide()
	elseif orbData.font2.show and not orbData.font1.show then
		orb.font2:SetFont(RC32CharacterData.font,25,"THINOUTLINE")
		orb.font2:SetPoint("CENTER",0,0)
		orb.font1:Hide()
	else
		orb.font1:Hide()
		orb.font2:Hide()
	end
end

function checkXMLOrbFontPlacement()
	xmlOrbDisplayFrame2.orb.font1:Show()
	xmlOrbDisplayFrame2.orb.font2:Show()
	if RC32OrbPercentageCheckBox:GetChecked() and RC32OrbValueCheckBox:GetChecked() then
		xmlOrbDisplayFrame2.orb.font1:SetFont(RC32CharacterData.font,28,"THINOUTLINE")
		xmlOrbDisplayFrame2.orb.font2:SetFont(RC32CharacterData.font,16,"THINOUTLINE")
		xmlOrbDisplayFrame2.orb.font1:SetPoint("CENTER",0,15)
		xmlOrbDisplayFrame2.orb.font2:SetPoint("CENTER",0,-5)
	elseif RC32OrbPercentageCheckBox:GetChecked() and not RC32OrbValueCheckBox:GetChecked() then
		xmlOrbDisplayFrame2.orb.font1:SetFont(RC32CharacterData.font,32,"THINOUTLINE")
		xmlOrbDisplayFrame2.orb.font1:SetPoint("CENTER",0,0)
		xmlOrbDisplayFrame2.orb.font2:Hide()
	elseif RC32OrbValueCheckBox:GetChecked() and not RC32OrbPercentageCheckBox:GetChecked() then
		xmlOrbDisplayFrame2.orb.font2:SetFont(RC32CharacterData.font,32,"THINOUTLINE")
		xmlOrbDisplayFrame2.orb.font2:SetPoint("CENTER",0,0)
		xmlOrbDisplayFrame2.orb.font1:Hide()
	else
		xmlOrbDisplayFrame2.orb.font1:Hide()
		xmlOrbDisplayFrame2.orb.font2:Hide()
	end
end

function resetXMLTextBoxes()
	RC32OrbPercentageCheckBox:SetChecked(CommitButton.orbData.font1.show)
	RC32OrbValueCheckBox:SetChecked(CommitButton.orbData.font2.show)
end

local function checkDefaultsFromMemory()
	if not RC32CharacterData.healthOrb then RC32CharacterData.healthOrb = defaultsTable.healthOrb end
	if not RC32CharacterData.healthOrb.textures then RC32CharacterData.healthOrb.textures = defaultTextures.healthOrb end
	if not RC32CharacterData.healthOrb.textures.fill then RC32CharacterData.healthOrb.textures.fill = defaultTextures.healthOrb.fill end
	if not RC32CharacterData.healthOrb.textures.rotation then RC32CharacterData.healthOrb.textures.rotation = defaultTextures.healthOrb.rotation end
	if RC32CharacterData.healthOrb.font1.show == nil then RC32CharacterData.healthOrb.font1.show = defaultsTable.healthOrb.font1.show end
	if RC32CharacterData.healthOrb.font2.show == nil then RC32CharacterData.healthOrb.font2.show = defaultsTable.healthOrb.font2.show end
	if not RC32CharacterData.healthOrb.formatting then RC32CharacterData.healthOrb.formatting = defaultsTable.healthOrb.formatting end
	if not RC32CharacterData.manaOrb then RC32CharacterData.manaOrb = defaultsTable.manaOrb end
	if not RC32CharacterData.manaOrb.textures then RC32CharacterData.manaOrb.textures = defaultTextures.manaOrb end
	if not RC32CharacterData.manaOrb.textures.fill then RC32CharacterData.manaOrb.textures.fill = defaultTextures.manaOrb.fill end
	if not RC32CharacterData.manaOrb.textures.rotation then RC32CharacterData.manaOrb.textures.rotation = defaultTextures.manaOrb.rotation end
	if RC32CharacterData.manaOrb.font1.show == nil then RC32CharacterData.manaOrb.font1.show = defaultsTable.manaOrb.font1.show end
	if RC32CharacterData.manaOrb.font2.show == nil then RC32CharacterData.manaOrb.font2.show = defaultsTable.manaOrb.font2.show end
	if not RC32CharacterData.manaOrb.formatting then RC32CharacterData.manaOrb.formatting = defaultsTable.manaOrb.formatting end
	if not RC32CharacterData.druidColors then RC32CharacterData.druidColors = defaultsTable.druidColors end
	if not RC32CharacterData.combat then RC32CharacterData.combat = defaultsTable.combat end
	if not RC32CharacterData.combat.galaxy then RC32CharacterData.combat.galaxy = defaultsTable.combat.galaxy end
	if not RC32CharacterData.values then RC32CharacterData.values = defaultsTable.values  end
	if not RC32CharacterData.artwork then RC32CharacterData.artwork = defaultsTable.artwork end
	if not RC32CharacterData.font then RC32CharacterData.font = defaultsTable.font end
	if not RC32CharacterData.petOrb then RC32CharacterData.petOrb = defaultsTable.petOrb end
	if not RC32CharacterData.petOrb.scale then RC32CharacterData.petOrb.scale = defaultsTable.petOrb.scale end
	if not RC32CharacterData.powerFrame then RC32CharacterData.powerFrame = defaultsTable.powerFrame end
	if RC32CharacterData.powerFrame.maxStackSound == nil then RC32CharacterData.powerFrame.maxStackSound = defaultsTable.powerFrame.maxStackSound end
	if not RC32CharacterData.defaultPlayerFrame then RC32CharacterData.defaultPlayerFrame = defaultsTable.defaultPlayerFrame end
	
	-- Validate/repair color tables (fix any missing r, g, b, a components)
	local function validateColorTable(colorTable, defaultColor)
		if not colorTable then return defaultColor end
		colorTable.r = colorTable.r or (defaultColor and defaultColor.r) or 1
		colorTable.g = colorTable.g or (defaultColor and defaultColor.g) or 1
		colorTable.b = colorTable.b or (defaultColor and defaultColor.b) or 1
		colorTable.a = colorTable.a or (defaultColor and defaultColor.a) or 1
		return colorTable
	end
	
	-- Repair health orb colors
	RC32CharacterData.healthOrb.orbColor = validateColorTable(RC32CharacterData.healthOrb.orbColor, defaultsTable.healthOrb.orbColor)
	RC32CharacterData.healthOrb.galaxy = validateColorTable(RC32CharacterData.healthOrb.galaxy, defaultsTable.healthOrb.galaxy)
	RC32CharacterData.healthOrb.font1 = validateColorTable(RC32CharacterData.healthOrb.font1, defaultsTable.healthOrb.font1)
	RC32CharacterData.healthOrb.font2 = validateColorTable(RC32CharacterData.healthOrb.font2, defaultsTable.healthOrb.font2)
	
	-- Repair mana orb colors
	RC32CharacterData.manaOrb.orbColor = validateColorTable(RC32CharacterData.manaOrb.orbColor, defaultsTable.manaOrb.orbColor)
	RC32CharacterData.manaOrb.galaxy = validateColorTable(RC32CharacterData.manaOrb.galaxy, defaultsTable.manaOrb.galaxy)
	RC32CharacterData.manaOrb.font1 = validateColorTable(RC32CharacterData.manaOrb.font1, defaultsTable.manaOrb.font1)
	RC32CharacterData.manaOrb.font2 = validateColorTable(RC32CharacterData.manaOrb.font2, defaultsTable.manaOrb.font2)
	
	-- Repair combat colors
	if RC32CharacterData.combat then
		RC32CharacterData.combat.orbColor = validateColorTable(RC32CharacterData.combat.orbColor, defaultsTable.combat.orbColor)
		RC32CharacterData.combat.galaxy = validateColorTable(RC32CharacterData.combat.galaxy, defaultsTable.combat.galaxy)
		RC32CharacterData.combat.font1 = validateColorTable(RC32CharacterData.combat.font1, defaultsTable.combat.font1)
		RC32CharacterData.combat.font2 = validateColorTable(RC32CharacterData.combat.font2, defaultsTable.combat.font2)
	end
	
	-- Initialize account-wide data for power tracker rotation
	if not RC32AccountData then RC32AccountData = {} end
	if RC32AccountData.powerTrackerRotation == nil then RC32AccountData.powerTrackerRotation = 270 end
	if RC32AccountData.powerTrackerScale == nil then RC32AccountData.powerTrackerScale = 100 end
	
	
	if TruncatedValuesCheckButton then TruncatedValuesCheckButton:SetChecked(RC32CharacterData.values.formatted) end
	if ShowArtworkCheckButton then ShowArtworkCheckButton:SetChecked(RC32CharacterData.artwork.show) end
	if UsePetOrbCheckButton then UsePetOrbCheckButton:SetChecked(RC32CharacterData.petOrb.enabled) end
	if TrackCombatCheckButton then TrackCombatCheckButton:SetChecked(RC32CharacterData.combat.enabled) end
	if ShowPetOrbPercentagesCheckButton then ShowPetOrbPercentagesCheckButton:SetChecked(RC32CharacterData.petOrb.showPercentage) end
	if ShowPetOrbValuesCheckButton then ShowPetOrbValuesCheckButton:SetChecked(RC32CharacterData.petOrb.showValue) end
	if UsePowerTrackerCheckButton then UsePowerTrackerCheckButton:SetChecked(RC32CharacterData.powerFrame.show) end
	if ShowBlizzPlayerFrameCheckButton then ShowBlizzPlayerFrameCheckButton:SetChecked(RC32CharacterData.defaultPlayerFrame.show) end
		
	if not RC32CharacterData.petOrb.showValue then
		petOrb.font3:Hide()
		petOrb.font4:Hide()
	end
	if not RC32CharacterData.petOrb.showPercentage then
		petOrb.font1:Hide()
		petOrb.font2:Hide()
	end
	checkPetFontPlacement()
	
	if not RC32CharacterData.petOrb.enabled then
		if petOrb.secure then
			RC32_UnregisterUnitWatch(petOrb.secure)
			petOrb.secure:Hide()
		end
		petOrb:Hide()
	end
	if not RC32CharacterData.artwork.show then
		angelFrame:Hide()
		demonFrame:Hide()
	end
	
	-- Handle segmented power tracker visibility
	if segmentedPowerTracker then
		if not RC32CharacterData.powerFrame.show then
			segmentedPowerTracker:SetScript("OnUpdate", nil)
			segmentedPowerTracker:Hide()
		else
			segmentedPowerTracker:SetScript("OnUpdate", RC32MonitorSegmentedPowers)
			segmentedPowerTracker:Show()
		end
	end
	
	-- Legacy powerFrame handling (if still exists)
	if powerFrame then
		if not RC32CharacterData.powerFrame.show then
			powerFrame:SetScript("OnUpdate",nil)
			powerFrame:Hide()
		end
	end
end

-- Helper function to safely get color values with fallbacks
local function safeColor(colorTable, defaultR, defaultG, defaultB, defaultA)
	if not colorTable then return defaultR or 1, defaultG or 1, defaultB or 1, defaultA or 1 end
	return colorTable.r or defaultR or 1, colorTable.g or defaultG or 1, colorTable.b or defaultB or 1, colorTable.a or defaultA or 1
end

local function setStatusBarColor(bar, r, g, b, a)
	if not bar or not bar.SetStatusBarColor then
		return
	end
	bar:SetStatusBarColor(r or 1, g or 1, b or 1, a or 1)
end

local function updateColorsFromMemory()
	--health orb fill, galaxy and font colors - USE SAVED COLORS
	local r,g,b,a = safeColor(RC32CharacterData.healthOrb.orbColor)
	healthOrb.filling:SetVertexColor(r,g,b,a)
	setStatusBarColor(healthOrb.fillingBar, r, g, b, a)
	r,g,b,a = safeColor(RC32CharacterData.healthOrb.galaxy)
	healthOrb.galaxy1.texture:SetVertexColor(r,g,b,a)
	healthOrb.galaxy2.texture:SetVertexColor(r,g,b,a)
	healthOrb.galaxy3.texture:SetVertexColor(r,g,b,a)
	r,g,b,a = safeColor(RC32CharacterData.healthOrb.font1)
	healthOrb.font1:SetTextColor(r,g,b,a)
	r,g,b,a = safeColor(RC32CharacterData.healthOrb.font2)
	healthOrb.font2:SetTextColor(r,g,b,a)
	healthOrb:SetScale(RC32CharacterData.healthOrb.scale or 1)

	--mana orb fill, galaxy and font colors
	r,g,b,a = safeColor(RC32CharacterData.manaOrb.orbColor)
	manaOrb.filling:SetVertexColor(r,g,b,a)
	setStatusBarColor(manaOrb.fillingBar, r, g, b, a)
	r,g,b,a = safeColor(RC32CharacterData.manaOrb.galaxy)
	manaOrb.galaxy1.texture:SetVertexColor(r,g,b,a)
	manaOrb.galaxy2.texture:SetVertexColor(r,g,b,a)
	manaOrb.galaxy3.texture:SetVertexColor(r,g,b,a)
	r,g,b,a = safeColor(RC32CharacterData.manaOrb.font1)
	manaOrb.font1:SetTextColor(r,g,b,a)
	r,g,b,a = safeColor(RC32CharacterData.manaOrb.font2)
	manaOrb.font2:SetTextColor(r,g,b,a)
	manaOrb:SetScale(RC32CharacterData.manaOrb.scale or 1)
	
	local pr, pg, pb, pa = healthOrb.filling:GetVertexColor()
	petOrb.filling1:SetVertexColor(pr or 1, pg or 1, pb or 1, pa or 1)
	setStatusBarColor(petOrb.filling1Bar, pr or 1, pg or 1, pb or 1, pa or 1)
	pr, pg, pb, pa = manaOrb.filling:GetVertexColor()
	petOrb.filling2:SetVertexColor(pr or 1, pg or 1, pb or 1, pa or 1)
	setStatusBarColor(petOrb.filling2Bar, pr or 1, pg or 1, pb or 1, pa or 1)
	petOrb.font1:SetTextColor(healthOrb.font1:GetTextColor())
	petOrb.font2:SetTextColor(manaOrb.font1:GetTextColor())
	petOrb.font3:SetTextColor(healthOrb.font2:GetTextColor())
	petOrb.font4:SetTextColor(manaOrb.font2:GetTextColor())
	petOrb:SetScale(RC32CharacterData.petOrb.scale)
	
	-- Update power tracker to class color and apply saved settings
	if segmentedPowerTracker then
		segmentedPowerTracker:UpdateColors()
		-- Apply saved rotation from account-wide data
		local savedRotation = RC32AccountData and RC32AccountData.powerTrackerRotation or 270
		segmentedPowerTracker:SetRotation(savedRotation)
		-- Apply saved scale from account-wide data
		local savedScale = RC32AccountData and RC32AccountData.powerTrackerScale or 75
		segmentedPowerTracker:SetScale(savedScale / 100)
	end
	
	-- Initialize scale sliders with saved values (inverted for vertical sliders)
	if RC32HealthScaleSlider then
		RC32HealthScaleSlider:SetValue(225 - (RC32CharacterData.healthOrb.scale) * 100)
		if RC32HealthScaleValue then
			RC32HealthScaleValue:SetText(math.floor((RC32CharacterData.healthOrb.scale) * 100) .. "%")
		end
	end
	if RC32ManaScaleSlider then
		RC32ManaScaleSlider:SetValue(225 - (RC32CharacterData.manaOrb.scale) * 100)
		if RC32ManaScaleValue then
			RC32ManaScaleValue:SetText(math.floor((RC32CharacterData.manaOrb.scale) * 100) .. "%")
		end
	end
	if RC32PetScaleSlider then
		RC32PetScaleSlider:SetValue(225 - (RC32CharacterData.petOrb.scale) * 100)
		if RC32PetScaleValue then
			RC32PetScaleValue:SetText(math.floor((RC32CharacterData.petOrb.scale) * 100) .. "%")
		end
	end
	-- Initialize power tracker rotation slider (convert from actual rotation to slider value)
	if RC32PowerTrackerRotationSlider then
		local savedRotation = RC32AccountData and RC32AccountData.powerTrackerRotation or 270
		-- Convert rotation back to slider value: slider = rotation - 270 (wrapped)
		local sliderVal = savedRotation - 270
		if sliderVal < 0 then sliderVal = sliderVal + 360 end
		RC32PowerTrackerRotationSlider:SetValue(sliderVal)
		if RC32RotateValue then
			RC32RotateValue:SetText(sliderVal .. "°")
		end
	end
	-- Initialize power tracker scale slider
	if RC32PowerTrackerScaleSlider then
		local savedScale = RC32AccountData and RC32AccountData.powerTrackerScale or 100
		RC32PowerTrackerScaleSlider:SetValue(225 - savedScale)
		if RC32PowerTrackerScaleValue then
			RC32PowerTrackerScaleValue:SetText(savedScale .. "%")
		end
	end

	setOrbFontPlacement(healthOrb,RC32CharacterData.healthOrb)
	setOrbFontPlacement(manaOrb,RC32CharacterData.manaOrb)
end

function RC32UpdateOrbColor(orb,orbColor,galaxyColor,font1Color,font2Color)
	local r, g, b, a = safeColor(orbColor)
	orb.filling:SetVertexColor(r, g, b, a)
	setStatusBarColor(orb.fillingBar, r, g, b, a)
	r, g, b, a = safeColor(galaxyColor)
	orb.galaxy1.texture:SetVertexColor(r, g, b, a)
	orb.galaxy2.texture:SetVertexColor(r, g, b, a)
	orb.galaxy3.texture:SetVertexColor(r, g, b, a)
	r, g, b, a = safeColor(font1Color)
	orb.font1:SetTextColor(r, g, b, a)
	r, g, b, a = safeColor(font2Color)
	orb.font2:SetTextColor(r, g, b, a)
end 

local function TryNewColors(restore)
	local r, g, b = ColorPickerFrame:GetColorRGB()
	local a = OpacitySliderFrame:GetValue()

	if restore then
		r,g,b,a = unpack(restore)
	end

	if ColorPickerFrame.elementToChange == "Filling" then
		xmlOrbDisplayFrame2.orb.filling:SetVertexColor(r,g,b,a)
	elseif ColorPickerFrame.elementToChange == "Swirl" then
		xmlOrbDisplayFrame2.orb.galaxy1.texture:SetVertexColor(r,g,b,a)
		xmlOrbDisplayFrame2.orb.galaxy2.texture:SetVertexColor(r,g,b,a)
		xmlOrbDisplayFrame2.orb.galaxy3.texture:SetVertexColor(r,g,b,a)
	elseif ColorPickerFrame.elementToChange == "Font1" then
		xmlOrbDisplayFrame2.orb.font1:SetTextColor(r,g,b,a)
	elseif ColorPickerFrame.elementToChange == "Font2" then
		xmlOrbDisplayFrame2.orb.font2:SetTextColor(r,g,b,a) 
	end
end

function TryNewTextures(fillTexture,swirlTexture)
	if fillTexture then
		xmlOrbDisplayFrame2.orb.filling:SetTexture(fillTexture)
	end
	if swirlTexture then
		xmlOrbDisplayFrame2.orb.galaxy1.texture:SetTexture(swirlTexture.."1.tga")
		xmlOrbDisplayFrame2.orb.galaxy2.texture:SetTexture(swirlTexture.."2.tga")
		xmlOrbDisplayFrame2.orb.galaxy3.texture:SetTexture(swirlTexture.."3.tga")
	end
end

local function checkShapeShiftInfo()
		local form = GetShapeshiftForm()
		local druidFormTable = RC32CharacterData.manaOrb
		local changeOcurred = true
		if form == 1 then
			druidFormTable = RC32CharacterData.druidColors.bear
			previousPowerValue = RC32_UnitPower("player", RC32_POWER_RAGE)
		elseif form == 3 then
			druidFormTable = RC32CharacterData.druidColors.cat
			previousPowerValue = RC32_UnitPower("player", RC32_POWER_ENERGY)
		elseif form == 5 then
			changeOcurred = false
		elseif form == 0 then
			druidFormTable = RC32CharacterData.manaOrb
			previousPowerValue = RC32_UnitPower("player", RC32_POWER_MANA)
		end
		RC32UpdateOrbColor(manaOrb,druidFormTable.orbColor,druidFormTable.galaxy,druidFormTable.font1,druidFormTable.font2)
end

-- Border Color Functions
function RC32_SetBorderColor(r, g, b)
	-- Try multiple ways to access the border texture
	local border = _G["RC32GUIBorder"]
	if border and border.SetVertexColor then
		border:SetVertexColor(r, g, b)
	end
end

local function UpdateOrbTextures()
	-- Ensure textures exist with fallback defaults
	local healthFill = (RC32CharacterData.healthOrb.textures and RC32CharacterData.healthOrb.textures.fill) or defaultTextures.healthOrb.fill
	local healthRotation = (RC32CharacterData.healthOrb.textures and RC32CharacterData.healthOrb.textures.rotation) or defaultTextures.healthOrb.rotation
	local manaFill = (RC32CharacterData.manaOrb.textures and RC32CharacterData.manaOrb.textures.fill) or defaultTextures.manaOrb.fill
	local manaRotation = (RC32CharacterData.manaOrb.textures and RC32CharacterData.manaOrb.textures.rotation) or defaultTextures.manaOrb.rotation
	
	healthOrb.filling:SetTexture(images..healthFill)
	healthOrb.galaxy1.texture:SetTexture(images..healthRotation.."1.tga")
	healthOrb.galaxy2.texture:SetTexture(images..healthRotation.."2.tga")
	healthOrb.galaxy3.texture:SetTexture(images..healthRotation.."3.tga")
	
	manaOrb.filling:SetTexture(images..manaFill)
	manaOrb.galaxy1.texture:SetTexture(images..manaRotation.."1.tga")
	manaOrb.galaxy2.texture:SetTexture(images..manaRotation.."2.tga")
	manaOrb.galaxy3.texture:SetTexture(images..manaRotation.."3.tga")
end

function shouldEnabledCheckboxBeChecked()
	if CommitButton and RC32OrbEnabledCheckbox then
		RC32OrbEnabledCheckbox:SetChecked(CommitButton.orbData.enabled)
	end
end

function RC32ApplyChanges()
	local activeElement = CommitButton.activeElement
	local r,g,b,a = xmlOrbDisplayFrame2.orb.filling:GetVertexColor()
	local fillColors = {r=0,g=0,b=0,a=0}
	fillColors.r, fillColors.g, fillColors.b, fillColors.a = r,g,b,a
	activeElement.orbColor.r, activeElement.orbColor.g, activeElement.orbColor.b, activeElement.orbColor.a = r,g,b,a

	local galaxyColors = {r=0,g=0,b=0,a=0}
	r,g,b,a = xmlOrbDisplayFrame2.orb.galaxy1.texture:GetVertexColor()
	galaxyColors.r, galaxyColors.g, galaxyColors.b, galaxyColors.a = r,g,b,a
	activeElement.galaxy.r, activeElement.galaxy.g, activeElement.galaxy.b, activeElement.galaxy.a = r,g,b,a
	
	local font1Color = {r=0,g=0,b=0,a=0}
	r,g,b,a = xmlOrbDisplayFrame2.orb.font1:GetTextColor()
	font1Color.r,font1Color.g,font1Color.b,font1Color.a = r,g,b,a
	activeElement.font1.r, activeElement.font1.g, activeElement.font1.b, activeElement.font1.a = r,g,b,a
	
	local font2Color = {r=0,g=0,b=0,a=0}
	r,g,b,a = xmlOrbDisplayFrame2.orb.font2:GetTextColor()
	font2Color.r,font2Color.g,font2Color.b,font2Color.a = r,g,b,a
	activeElement.font2.r, activeElement.font2.g, activeElement.font2.b, activeElement.font2.a = r,g,b,a
	
	-- Update the actual orb being edited with its saved colors
	RC32UpdateOrbColor(CommitButton.orb, activeElement.orbColor, activeElement.galaxy, activeElement.font1, activeElement.font2)
	
	-- Use stored texture indices from dropdown selections
	if RC32SelectedFillIndex ~= nil then
		CommitButton.textureElement.fill = RC32FillTextureNames[RC32SelectedFillIndex]
	end
	if RC32SelectedRotationIndex ~= nil then
		CommitButton.textureElement.rotation = RC32RotationTextureNames[RC32SelectedRotationIndex]
	end
	UpdateOrbTextures()

	if RC32OrbPercentageCheckBox:GetChecked() then
		CommitButton.orbData.font1.show = true
	else
		CommitButton.orbData.font1.show = false
	end

	if RC32OrbValueCheckBox:GetChecked() then
		CommitButton.orbData.font2.show = true
	else
		CommitButton.orbData.font2.show = false
	end

	setOrbFontPlacement(CommitButton.orb,CommitButton.orbData)
	
	--set pet fill colors to that of the fill colors of the health/mana orbs
	local pr, pg, pb, pa = healthOrb.filling:GetVertexColor()
	petOrb.filling1:SetVertexColor(pr or 1, pg or 1, pb or 1, pa or 1)
	setStatusBarColor(petOrb.filling1Bar, pr or 1, pg or 1, pb or 1, pa or 1)
	pr, pg, pb, pa = manaOrb.filling:GetVertexColor()
	petOrb.filling2:SetVertexColor(pr or 1, pg or 1, pb or 1, pa or 1)
	setStatusBarColor(petOrb.filling2Bar, pr or 1, pg or 1, pb or 1, pa or 1)
	petOrb.font1:SetTextColor(healthOrb.font1:GetTextColor())
	petOrb.font2:SetTextColor(manaOrb.font1:GetTextColor())
	petOrb.font3:SetTextColor(healthOrb.font2:GetTextColor())
	petOrb.font4:SetTextColor(manaOrb.font2:GetTextColor())
end

function RC32ColorPicker(xmlElement)
	local r,g,b,a
	if xmlElement == "Filling" then
		r,g,b,a = xmlOrbDisplayFrame2.orb.filling:GetVertexColor()
	elseif xmlElement == "Swirl" then
		r,g,b,a = xmlOrbDisplayFrame2.orb.galaxy1.texture:GetVertexColor()
	elseif xmlElement == "Font1" then
		r,g,b,a = xmlOrbDisplayFrame2.orb.font1:GetTextColor()
	elseif xmlElement == "Font2" then
		r,g,b,a = xmlOrbDisplayFrame2.orb.font2:GetTextColor()
	end
	
	ColorPickerFrame.elementToChange = xmlElement
	ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = TryNewColors,TryNewColors,TryNewColors
	ColorPickerFrame:SetColorRGB(r,g,b,a)
	ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a
	ColorPickerFrame.previousValues = {r,g,b,a}
	makeFrameMovable(ColorPickerFrame,"RightButton")
	ColorPickerFrame:EnableKeyboard(false)
	ColorPickerFrame:Show()
end

function RC32ResetToClassColors()
	-- Get the class colors based on which orb is being edited
	local classColor
	local isHealthOrb = (CommitButton.orb == healthOrb)
	
	if isHealthOrb then
		classColor = orbClassColors[charClassNumber].health
	else
		classColor = orbClassColors[charClassNumber].mana
	end
	
	-- Update the preview orb with class colors
	xmlOrbDisplayFrame2.orb.filling:SetVertexColor(classColor.r, classColor.g, classColor.b, classColor.a)
	xmlOrbDisplayFrame2.orb.galaxy1.texture:SetVertexColor(classColor.r, classColor.g, classColor.b, classColor.a)
	xmlOrbDisplayFrame2.orb.galaxy2.texture:SetVertexColor(classColor.r, classColor.g, classColor.b, classColor.a)
	xmlOrbDisplayFrame2.orb.galaxy3.texture:SetVertexColor(classColor.r, classColor.g, classColor.b, classColor.a)
	xmlOrbDisplayFrame2.orb.font1:SetTextColor(1, 1, 1, 1)
	xmlOrbDisplayFrame2.orb.font2:SetTextColor(1, 1, 1, 1)
end

function UpdateXMLTextures(orb)
	xmlOrbDisplayFrame2.orb.filling:SetTexture(orb.filling:GetTexture())
	xmlOrbDisplayFrame2.orb.galaxy1.texture:SetTexture(orb.galaxy1.texture:GetTexture())
	xmlOrbDisplayFrame2.orb.galaxy2.texture:SetTexture(orb.galaxy2.texture:GetTexture())
	xmlOrbDisplayFrame2.orb.galaxy3.texture:SetTexture(orb.galaxy3.texture:GetTexture())
	
	-- Reset selected texture indices when opening config
	RC32SelectedFillIndex = nil
	RC32SelectedRotationIndex = nil
	
	UIDropDownMenu_SetText(FillTexturesDropDown,"Choose one...")
	UIDropDownMenu_SetText(RotationTexturesDropDown,"Choose one...")
end

function UpdateXMLColors(orbColor,galaxyColor,font1,font2)
	xmlOrbDisplayFrame2.orb.filling:SetVertexColor(orbColor.r,orbColor.g,orbColor.b,orbColor.a)
	xmlOrbDisplayFrame2.orb.galaxy1.texture:SetVertexColor(galaxyColor.r,galaxyColor.g,galaxyColor.b,galaxyColor.a)
	xmlOrbDisplayFrame2.orb.galaxy2.texture:SetVertexColor(galaxyColor.r,galaxyColor.g,galaxyColor.b,galaxyColor.a)
	xmlOrbDisplayFrame2.orb.galaxy3.texture:SetVertexColor(galaxyColor.r,galaxyColor.g,galaxyColor.b,galaxyColor.a)
	xmlOrbDisplayFrame2.orb.font1:SetTextColor(font1.r,font1.g,font1.b,font1.a)
	xmlOrbDisplayFrame2.orb.font2:SetTextColor(font2.r,font2.g,font2.b,font2.a)
end

function UpdateXMLText(orb)
	xmlOrbDisplayFrame2.orb.font1:SetText(orb.font1:GetText())
	xmlOrbDisplayFrame2.orb.font2:SetText(orb.font2:GetText())
end

function FillXMLTemplate(frame)
	frame.orb = CreateXMLOrb(xmlOrbDisplayFrame2,"RC32_XMLOrb",150,defaultTextures.healthOrb.fill,defaultTextures.healthOrb.rotation)
	frame.orb.galaxy1.texture:SetAlpha(0.5)
	frame.orb.galaxy2.texture:SetAlpha(0.5)
	frame.orb.galaxy3.texture:SetAlpha(0.5)
	frame:SetScale(1.5)
end

------Health Orb Options Dropdown Stuff------
function CheckHealthOrbOptionValuesAgainstUIState()
	local selectedId = UIDropDownMenu_GetSelectedID(HealthOrbOptionsDropDown);
	if selectedId == 2 then
		CommitButton.activeElement = RC32CharacterData.combat
	elseif selectedId == 1 then
		CommitButton.activeElement = RC32CharacterData.healthOrb
		CommitButton.newActiveElement = RC32CharacterData.healthOrb
	end

	UpdateXMLColors(
		CommitButton.activeElement.orbColor,
		CommitButton.activeElement.galaxy,
		CommitButton.activeElement.font1,
		CommitButton.activeElement.font2)
end

function InitializeHealthOrbOptionsDropDown()
	CommitButton.activeElement = RC32CharacterData.healthOrb
	local fillOptions = {
	"Default",
	"Combat"
	}

	function HealthOrbOptionsDropDown:OnClick(value)
		UIDropDownMenu_SetSelectedID(HealthOrbOptionsDropDown,self:GetID())
		CheckHealthOrbOptionValuesAgainstUIState();
	end

	local function initMen(self, level)
		local stuff = UIDropDownMenu_CreateInfo()
		for k,v in pairs(fillOptions) do
		stuff = {}
		stuff.text = v
		stuff.value = v
		stuff.func = HealthOrbOptionsDropDown.OnClick
		UIDropDownMenu_AddButton(stuff, level)
		end
	end
	UIDropDownMenu_Initialize(HealthOrbOptionsDropDown, initMen)
	UIDropDownMenu_SetSelectedID(HealthOrbOptionsDropDown, 1)
	UIDropDownMenu_JustifyText(HealthOrbOptionsDropDown, "LEFT")
end

-------Mana Orb Options Dropdown Stuff-------
function CheckManaOrbOptionValuesAgainstUIState()
	local selectedId = UIDropDownMenu_GetSelectedID(ManaOrbOptionsDropDown);
	if selectedId == 3 then
		CommitButton.activeElement = RC32CharacterData.druidColors.cat
	elseif selectedId == 2 then
		CommitButton.activeElement = RC32CharacterData.druidColors.bear
	elseif selectedId == 1 then
		CommitButton.activeElement = RC32CharacterData.manaOrb
	end
	UpdateXMLColors(
		CommitButton.activeElement.orbColor,
		CommitButton.activeElement.galaxy,
		CommitButton.activeElement.font1,
		CommitButton.activeElement.font2)
end

function InitializeManaOrbOptionsDropDown()
	CommitButton.activeElement = RC32CharacterData.manaOrb
	local fillOptions2 = {
		"Default"
	}

	if RC32className == "Druid" then
		fillOptions2 = {
			"Default",
			"Bear",
			"Cat"
		}
	end

	function ManaOrbOptionsDropDown:OnClick(value)
		UIDropDownMenu_SetSelectedID(ManaOrbOptionsDropDown,self:GetID())
		CheckManaOrbOptionValuesAgainstUIState();
	end

	local function initMen(self, level)
	local stuff = UIDropDownMenu_CreateInfo()
	for k,v in pairs(fillOptions2) do
			stuff = {}
			stuff.text = v
			stuff.value = v
			stuff.func = ManaOrbOptionsDropDown.OnClick
			UIDropDownMenu_AddButton(stuff, level)
		end
	end
	UIDropDownMenu_Initialize(ManaOrbOptionsDropDown, initMen)
	UIDropDownMenu_SetSelectedID(ManaOrbOptionsDropDown, 1)
	UIDropDownMenu_JustifyText(ManaOrbOptionsDropDown, "LEFT")
end

--alloc the orbs and assign them to the health/mana orb variables, make them both movable from the get-go for testing
healthOrb = CreateOrb(nil,"RC32_HealthOrb",defaultOrbSize,defaultTextures.healthOrb.fill,defaultTextures.healthOrb.rotation,-250,0,"BOTTOM",monitorHealth)
manaOrb = CreateOrb(nil,"RC32_ManaOrb",defaultOrbSize,defaultTextures.manaOrb.fill,defaultTextures.manaOrb.rotation,250,0,"BOTTOM",monitorPower)
petOrb = CreatePetOrb(healthOrb,"RC32_PetOrb",87,-95,70,nil)
healthOrbSecure = healthOrb.secure
manaOrbSecure = manaOrb.secure
petOrbSecure = petOrb.secure
powerFrame = nil

-- Define segment counts per class (MoP 5.4.8)
-- Some classes/power types only exist in certain expansions
local classPowerSegments = {
	["Rogue"] = 5,      -- Combo Points (max 5) - all versions
	["Druid"] = 5,      -- Combo Points in cat form (max 5) - all versions
}

-- Add expansion-specific classes/power types
if RC32_IS_CATA_OR_LATER then
	classPowerSegments["Paladin"] = 3    -- Holy Power (max 3)
	classPowerSegments["Warlock"] = 4    -- Soul Shards (max 4)
	classPowerSegments["Priest"] = 3     -- Shadow Orbs (max 3)
end

if RC32_IS_MOP_OR_LATER then
	classPowerSegments["Monk"] = 4       -- Chi (max 4, can be 5 with talent)
	classPowerSegments["Shaman"] = 5     -- Maelstrom Weapon stacks (max 5)
end

-- Create segmented power tracker for supported classes
local numSegments = classPowerSegments[RC32className]
if numSegments then
	segmentedPowerTracker = CreateSegmentedPowerTracker(healthOrb, numSegments, defaultOrbSize)
	segmentedPowerTracker:SetScript("OnUpdate", RC32MonitorSegmentedPowers)
	-- Show the checkbox and rotation slider for classes that have power tracker
	if UsePowerTrackerCheckButton then
		UsePowerTrackerCheckButton:Show()
	end
	if RC32PowerTrackerRotationSlider then
		RC32PowerTrackerRotationSlider:Show()
	end
	if RC32PowerTrackerRotationSliderBackdrop then
		RC32PowerTrackerRotationSliderBackdrop:Show()
	end
	if RC32PowerTrackerResetButton then
		RC32PowerTrackerResetButton:Show()
	end
	if RC32PowerTrackerScaleSlider then
		RC32PowerTrackerScaleSlider:Show()
	end
	if RC32PowerTrackerScaleSliderBackdrop then
		RC32PowerTrackerScaleSliderBackdrop:Show()
	end
	if RC32PowerTrackerScaleResetButton then
		RC32PowerTrackerScaleResetButton:Show()
	end
	if RC32MaxStackSoundDropdown then
		RC32MaxStackSoundDropdown:Show()
	end
	if RC32MaxStackSoundLabelFrame then
		RC32MaxStackSoundLabelFrame:Show()
	end
else
	-- Hide the checkbox and rotation slider for classes that don't have power tracker
	if UsePowerTrackerCheckButton then
		UsePowerTrackerCheckButton:Hide()
	end
	if RC32PowerTrackerRotationSlider then
		RC32PowerTrackerRotationSlider:Hide()
	end
	if RC32PowerTrackerRotationSliderBackdrop then
		RC32PowerTrackerRotationSliderBackdrop:Hide()
	end
	if RC32PowerTrackerResetButton then
		RC32PowerTrackerResetButton:Hide()
	end
	if RC32PowerTrackerScaleSlider then
		RC32PowerTrackerScaleSlider:Hide()
	end
	if RC32PowerTrackerScaleSliderBackdrop then
		RC32PowerTrackerScaleSliderBackdrop:Hide()
	end
	if RC32PowerTrackerScaleResetButton then
		RC32PowerTrackerScaleResetButton:Hide()
	end
	if RC32MaxStackSoundDropdown then
		RC32MaxStackSoundDropdown:Hide()
	end
	if RC32MaxStackSoundLabelFrame then
		RC32MaxStackSoundLabelFrame:Hide()
	end
end
angelFrame = addArtwork(images.."d3_angel2test.tga",manaOrb,"AngelFrame",70,5,160,160)
demonFrame = addArtwork(images.."d3_demon2test.tga",healthOrb,"DemonFrame",-90,5,160,160)
makeFrameMovable(healthOrb)
makeFrameMovable(manaOrb)
makeFrameMovable(petOrb)

local function RC32_UpdatePlayerVitals()
	local unit = (vehicleInUse == 1) and "vehicle" or "player"
	local rawHealth = UnitHealth(unit)
	local rawMaxHealth = UnitHealthMax(unit)
	local rawPower = UnitPower(unit)
	local rawMaxPower = UnitPowerMax(unit)
	healthOrb.rawCurrentHealth = rawHealth
	healthOrb.rawMaxHealth = rawMaxHealth
	manaOrb.rawCurrentPower = rawPower
	manaOrb.rawMaxPower = rawMaxPower

	local prevHealth = lastSafeHealth
	local prevMaxHealth = lastSafeMaxHealth
	local prevPower = lastSafePower
	local prevMaxPower = lastSafeMaxPower

	local safeHealth = rc32SafeNumber(rawHealth, prevHealth)
	local safeMaxHealth = rc32SafeNumber(rawMaxHealth, prevMaxHealth)
	local safePower = rc32SafeNumber(rawPower, prevPower)
	local safeMaxPower = rc32SafeNumber(rawMaxPower, prevMaxPower)

	if rc32CanUseValue(rawHealth) then lastSafeHealth = safeHealth end
	if rc32CanUseValue(rawMaxHealth) then lastSafeMaxHealth = safeMaxHealth end
	if rc32CanUseValue(rawPower) then lastSafePower = safePower end
	if rc32CanUseValue(rawMaxPower) then lastSafeMaxPower = safeMaxPower end
	if rc32CanUseValue(rawHealth) and rc32CanUseValue(rawMaxHealth) and safeMaxHealth > 0 then
		lastSafeHealthPercent = math.floor((safeHealth / safeMaxHealth) * 100)
	end
	if rc32CanUseValue(rawPower) and rc32CanUseValue(rawMaxPower) and safeMaxPower > 0 then
		lastSafePowerPercent = math.floor((safePower / safeMaxPower) * 100)
	end

	healthOrb.currentHealth = safeHealth
	healthOrb.maxHealth = safeMaxHealth
	manaOrb.currentPower = safePower
	manaOrb.maxPower = safeMaxPower
	healthOrb.isDead = UnitIsDeadOrGhost(unit) or false
	manaOrb.isDead = healthOrb.isDead
	if not previousHealthValue or rc32SafeNumber(previousHealthValue, 0) == 0 then
		previousHealthValue = healthOrb.currentHealth
	end
	if not previousPowerValue or rc32SafeNumber(previousPowerValue, 0) == 0 then
		previousPowerValue = manaOrb.currentPower
	end
end

local function RC32_UpdatePetVitals()
	local unit = "pet"
	local rawHealth = UnitHealth(unit)
	local rawMaxHealth = UnitHealthMax(unit)
	local rawPower = UnitPower(unit)
	local rawMaxPower = UnitPowerMax(unit)
	petOrb.rawPetCurrentHealth = rawHealth
	petOrb.rawPetMaxHealth = rawMaxHealth
	petOrb.rawPetCurrentPower = rawPower
	petOrb.rawPetMaxPower = rawMaxPower

	local prevHealth = lastSafePetHealth
	local prevMaxHealth = lastSafePetMaxHealth
	local prevPower = lastSafePetPower
	local prevMaxPower = lastSafePetMaxPower

	local safeHealth = rc32SafeNumber(rawHealth, prevHealth)
	local safeMaxHealth = rc32SafeNumber(rawMaxHealth, prevMaxHealth)
	local safePower = rc32SafeNumber(rawPower, prevPower)
	local safeMaxPower = rc32SafeNumber(rawMaxPower, prevMaxPower)

	if rc32CanUseValue(rawHealth) then lastSafePetHealth = safeHealth end
	if rc32CanUseValue(rawMaxHealth) then lastSafePetMaxHealth = safeMaxHealth end
	if rc32CanUseValue(rawPower) then lastSafePetPower = safePower end
	if rc32CanUseValue(rawMaxPower) then lastSafePetMaxPower = safeMaxPower end
	if rc32CanUseValue(rawHealth) and rc32CanUseValue(rawMaxHealth) and safeMaxHealth > 0 then
		lastSafePetHealthPercent = math.floor((safeHealth / safeMaxHealth) * 100)
	end
	if rc32CanUseValue(rawPower) and rc32CanUseValue(rawMaxPower) and safeMaxPower > 0 then
		lastSafePetPowerPercent = math.floor((safePower / safeMaxPower) * 100)
	end

	petOrb.petCurrentHealth = safeHealth
	petOrb.petMaxHealth = safeMaxHealth
	petOrb.petCurrentPower = safePower
	petOrb.petMaxPower = safeMaxPower
	if not previousPetHealth or rc32SafeNumber(previousPetHealth, 0) == 0 then
		previousPetHealth = petOrb.petCurrentHealth
	end
	if not previousPetPower or rc32SafeNumber(previousPetPower, 0) == 0 then
		previousPetPower = petOrb.petCurrentPower
	end
end

local statusFrame = CreateFrame("Frame")
statusFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
statusFrame:RegisterEvent("UNIT_HEALTH")
statusFrame:RegisterEvent("UNIT_MAXHEALTH")
statusFrame:RegisterEvent("UNIT_POWER_UPDATE")
statusFrame:RegisterEvent("UNIT_MAXPOWER")
statusFrame:RegisterEvent("UNIT_DISPLAYPOWER")
statusFrame:RegisterEvent("UNIT_FLAGS")
statusFrame:RegisterEvent("UNIT_PET")
statusFrame:SetScript("OnEvent", function(self, event, unit)
	if event == "UNIT_PET" or unit == "pet" then
		RC32_UpdatePetVitals()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" or unit == "player" or unit == "vehicle" then
		RC32_UpdatePlayerVitals()
	end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UNIT_PET")
if RC32className == "Druid" then
	eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
end

local flagHide_PetFrame = false
function eventFrame:OnEvent(event,arg1)
	if event == "ADDON_LOADED" then
		checkDefaultsFromMemory()
		handlePlayerFrame(RC32CharacterData.defaultPlayerFrame.show)
		updateColorsFromMemory()
		UpdateOrbTextures()
		RC32_UpdatePlayerVitals()
		RC32_UpdatePetVitals()
		-- Health orb color is already set by updateColorsFromMemory() using class color
		local colorTable
		if RC32className == "Druid" then
			checkShapeShiftInfo()
		else
			RC32UpdateOrbColor(manaOrb,RC32CharacterData.manaOrb.orbColor,RC32CharacterData.manaOrb.galaxy,RC32CharacterData.manaOrb.font1,RC32CharacterData.manaOrb.font2)
		end
		-- Load saved menu background (also sets border color)
		if RC32AccountData and RC32AccountData.menuBackground then
			RC32_SetMenuBackground(RC32AccountData.menuBackground)
		else
			RC32_SetMenuBackground(1) -- Default to Chicken with white border
		end
		RC32GUI:Hide()
	elseif event == "VARIABLES_LOADED" then
		RC32MiniMapButtonPosition_LoadFromDefaults()
	elseif event == "UNIT_ENTERED_VEHICLE" then
		if arg1 == "player" then
			vehicleInUse = 1
			previousPowerValue = 0
			previousHealthValue = 0
			RC32_UpdatePlayerVitals()
		end
	elseif event == "UNIT_EXITED_VEHICLE" then
		if arg1 == "player" then
			vehicleInUse = 0
			previousHealthValue = 0
			previousPowerValue = 0
			RC32_UpdatePlayerVitals()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if RC32CharacterData.combat.enabled then
			RC32UpdateOrbColor(healthOrb,RC32CharacterData.combat.orbColor,RC32CharacterData.combat.galaxy,RC32CharacterData.combat.font1,RC32CharacterData.combat.font2)
			local cr, cg, cb, ca = safeColor(RC32CharacterData.combat.orbColor)
			petOrb.filling1:SetVertexColor(cr, cg, cb, ca)
			-- Power tracker stays class color (no change)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if RC32CharacterData.combat.enabled then
			-- Use saved color for health orb when out of combat
			RC32UpdateOrbColor(healthOrb, RC32CharacterData.healthOrb.orbColor, RC32CharacterData.healthOrb.galaxy, RC32CharacterData.healthOrb.font1, RC32CharacterData.healthOrb.font2)
			local hr, hg, hb, ha = safeColor(RC32CharacterData.healthOrb.orbColor)
			petOrb.filling1:SetVertexColor(hr, hg, hb, ha)
			-- Power tracker stays class color (no change needed)
		end
	elseif event == "UPDATE_SHAPESHIFT_FORM" then
		checkShapeShiftInfo()
	elseif event == "UNIT_PET" then
		local name,realm = UnitName("pet")
		if not name then
			if petOrb.updateFrame then
				petOrb.updateFrame:SetScript("OnUpdate", nil)
			end
			if petOrb.secure then
				petOrb.secure:Hide()
			end
		else
			if petOrb.updateFrame then
				petOrb.updateFrame:SetScript("OnUpdate", function()
					updatePetValues(petOrb)
				end)
			end
			if petOrb.secure then
				petOrb.secure:Show()
			end
			previousPetHealth = 0
			previousPetPower = 0
			RC32_UpdatePetVitals()
		end
	end
end

eventFrame:SetScript("OnEvent",eventFrame.OnEvent)

--slash command method	
local function CommandFunc(cmd)
	if cmd == "disable" then
		if healthOrb.updateFrame then healthOrb.updateFrame:SetScript("OnUpdate", nil) end
		if manaOrb.updateFrame then manaOrb.updateFrame:SetScript("OnUpdate", nil) end
		healthOrb:Hide()
		manaOrb:Hide()
	elseif cmd == "enable" then
		if healthOrb.updateFrame then
			healthOrb.updateFrame:SetScript("OnUpdate", function() monitorHealth(healthOrb) end)
		end
		if manaOrb.updateFrame then
			manaOrb.updateFrame:SetScript("OnUpdate", function() monitorPower(manaOrb) end)
		end
		healthOrb:Show()
		manaOrb:Show()
	elseif cmd == "help" then
		
	else
		Handle_RC32GUI()
	end
end

--setup the slash command stuff, hide the GUI
SlashCmdList["RCM"] = CommandFunc;
SLASH_RCM1 = "/rcm";
